#!/usr/bin/env node
// Release bundler for Mugiwara HUB.
//
// Combines every Manager/*.lua + Tabs/*.lua + Universal.lua into one "Core" bundle, and every
// Games/<Game>/*.lua into its own bundle ("Evade", etc.), then patches Main.lua so
// getgenv().MugiwaraImport(path) resolves modules from those bundles instead of fetching one
// HTTP request per file. Main.lua itself stays a separate file (it is the loadstring() entry
// point); the bundles are extra files fetched once each.
//
// Why bundles instead of one per-module fetch: the hub currently does ~40 HttpGet calls per
// execute for its own code (one per module). Each is a round trip. Bundling cuts that to 1 (Core,
// always) + 1 per game actually played (Evade, only when the player is in Evade) + Main.lua
// itself = at most 3 requests instead of ~40, without changing when any module actually runs
// (each module is still a closure that only executes the first time something imports it).
//
// How a module ends up safe to bundle: every module file is a normal Lua chunk ("local X = {}
// ... return X"). A chunk's body is valid as a function body too (a chunk IS an implicit vararg
// function), so each module's source is wrapped verbatim as
//   getgenv().MugiwaraLoaders["Manager/Camera.lua"] = function(...) <source> end
// and the loader only executes it the first time that path is imported, caching the result in
// getgenv().MugiwaraModules exactly like today. No module's own source is touched or re-indented:
// what you see on GitHub inside the function wrapper is byte-for-byte what is in this repo (before
// obfuscation).
//
// Usage:
//   node release/build.mjs                       bundle (grouped mode), no obfuscation
//   node release/build.mjs --mode=single          bundle everything straight into Main.lua
//   node release/build.mjs --obfuscate            also run Prometheus (preset Medium, --LuaU)
//   node release/build.mjs --obfuscate=Strong     ...with a specific preset (see Prometheus docs)
//   node release/build.mjs --lua=<path>           lua5.1.exe/luajit.exe (default D:\Downloads\Lua\lua5.1.exe)
//   node release/build.mjs --prometheus=<path>    your Prometheus folder (default D:\Document\Prometheus)
//   node release/build.mjs --no-luau              target plain Lua 5.1 instead of --LuaU
//   node release/build.mjs --repo=<owner>/<name>  where Main.lua fetches Core.lua/game bundles
//                                                  from — MUST be the repo you upload release/dist
//                                                  to, default honamichanhere/Mugiwara-HUB. Get
//                                                  this wrong and Main.lua loads fine (you fetched
//                                                  it from wherever you put it) but then 404s
//                                                  trying to fetch Core.lua from the OLD repo.
//
// Output goes to release/dist/ (gitignored): the clean bundles/Main.lua, and, with --obfuscate,
// an release/dist/obfuscated/ copy of each file run through Prometheus. Nothing here publishes,
// pushes or touches any git remote — it only writes local files for you to review and push
// yourself to whichever repo you use for releases.

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, rmSync, existsSync } from "node:fs";
import { join, dirname, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const RELEASE_DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = dirname(RELEASE_DIR); // repo root (release/ sits directly under it)
const DIST_DIR = join(RELEASE_DIR, "dist");

const args = process.argv.slice(2);
function flag(name) {
	const prefix = "--" + name;
	for (const arg of args) {
		if (arg === prefix) return true;
		if (arg.startsWith(prefix + "=")) return arg.slice(prefix.length + 1);
	}
	return false;
}

const MODE = flag("mode") || "grouped"; // "grouped" | "single"
if (MODE !== "grouped" && MODE !== "single") {
	console.error("--mode must be 'grouped' or 'single', got: " + MODE);
	process.exit(1);
}
const OBFUSCATE = flag("obfuscate"); // false | true | "<preset name>"
// Matches the command that is actually proven to work on this machine:
//   cd /d "D:\Document\Prometheus"
//   "D:\Downloads\Lua\lua5.1.exe" cli.lua --preset Medium --LuaU "<input>"
// (the "prometheus-lua" wrapper script is a POSIX shell script; Windows cannot run it directly,
// which is why calling it straight from Node fails with ENOENT — so this calls lua5.1.exe on
// cli.lua instead, exactly like the command above, with the Prometheus folder as the working
// directory so cli.lua's own `require("src.cli")` resolves.)
const LUA_EXE = flag("lua") || join("D:", "Downloads", "Lua", "lua5.1.exe");
const PROMETHEUS_DIR = flag("prometheus") || join("D:", "Document", "Prometheus");
const LUAU_TARGET = flag("no-luau") ? false : true; // --no-luau to target plain Lua 5.1 instead

// Main.lua fetches its own other files (Core.lua, a game bundle, and itself again on reload/
// teleport) from BASE_URL, which is hardcoded in Main.lua's source as
// "https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/<branch>/". That only works
// when you host the release at that exact repo. Point it at wherever you actually upload the
// release build with --repo=<owner>/<repo-name> — if you forget this, Main.lua loads fine (it's
// the first file fetched, from whatever URL you used yourself) but then fails to find Core.lua/
// the game bundle, because it goes looking for them back at the OLD repo instead of the one you
// put them in.
const REPO = flag("repo") || "honamichanhere/Mugiwara-HUB";

// ---------- 1. discover every module file on disk ----------
// Scanned by folder, not by grepping MugiwaraImport("...") calls: a few call sites pass a
// variable instead of a literal path (Main.lua's game-module / global-tab loops), so scanning
// the filesystem is the only way that can't silently miss a file. Manager/Reflection.lua is a
// known example: not imported anywhere right now ("kept, not wired to the UI"), still bundled so
// it is available the moment something imports it.
const SCAN_ROOTS = ["Manager", "Tabs", "Games"];
const EXTRA_FILES = ["Universal.lua"]; // single files outside the scanned folders

function scanLuaFiles(dir) {
	const out = [];
	for (const name of readdirSync(dir)) {
		const full = join(dir, name);
		const st = statSync(full);
		if (st.isDirectory()) {
			out.push(...scanLuaFiles(full));
		} else if (name.endsWith(".lua")) {
			out.push(full);
		}
	}
	return out;
}

function toRepoPath(absolute) {
	return relative(ROOT, absolute).split(sep).join("/");
}

const modulePaths = [];
for (const root of SCAN_ROOTS) {
	const dir = join(ROOT, root);
	if (existsSync(dir)) modulePaths.push(...scanLuaFiles(dir).map(toRepoPath));
}
for (const file of EXTRA_FILES) {
	if (existsSync(join(ROOT, file))) modulePaths.push(file);
}
modulePaths.sort();

if (modulePaths.length === 0) {
	console.error("No module files found under " + SCAN_ROOTS.join(", ") + " — wrong ROOT? (" + ROOT + ")");
	process.exit(1);
}

// ---------- 2. group assignment ----------
// "Games/<Game>/..." -> group "<Game>" (its own bundle, fetched only when that game is played).
// Everything else (Manager/*, Tabs/*, Universal.lua) -> group "Core" (always fetched up front:
// the global tabs, Misc/Chat/UIConfig and the Universal fallback all live here).
function groupOf(repoPath) {
	const match = repoPath.match(/^Games\/([^/]+)\//);
	return match ? match[1] : "Core";
}

const groups = new Map(); // group name -> [repoPath, ...]
for (const path of modulePaths) {
	const group = groupOf(path);
	if (!groups.has(group)) groups.set(group, []);
	groups.get(group).push(path);
}

console.log("Main.lua will fetch Core.lua/game bundles from: https://raw.githubusercontent.com/" + REPO + "/<branch>/");
console.log("(wrong repo? pass --repo=<owner>/<name> — it must match wherever you upload release/dist to)\n");
console.log("Discovered " + modulePaths.length + " module(s) in " + groups.size + " group(s):");
for (const [group, paths] of groups) {
	console.log("  " + group + " (" + paths.length + " files, " + bundleFile(group) + ")");
}

function bundleFile(group) {
	return group + ".lua";
}

// ---------- 3. generate one bundle per group ----------
function readSource(repoPath) {
	let source = readFileSync(join(ROOT, repoPath), "utf8");
	// normalize to \n while bundling; the final file is re-written with \r\n once at the end to
	// match the rest of the repo (git is configured to normalize CRLF on checkout here).
	return source.replace(/\r\n/g, "\n");
}

function buildBundle(group, paths) {
	const parts = [
		"-- GENERATED by release/build.mjs from: " + paths.join(", "),
		"-- Do not edit this file by hand; edit the source files above and rebuild.",
		"getgenv().MugiwaraLoaders = getgenv().MugiwaraLoaders or {}",
		"",
	];
	for (const path of paths) {
		parts.push("-- ===== " + path + " =====");
		parts.push('getgenv().MugiwaraLoaders["' + path + '"] = function(...)');
		parts.push(readSource(path));
		parts.push("end");
		parts.push("");
	}
	return parts.join("\n");
}

const bundles = new Map(); // group -> source text
for (const [group, paths] of groups) {
	bundles.set(group, buildBundle(group, paths));
}

// ---------- 4. patch Main.lua's module loader ----------
// This is the ONLY change made to Main.lua; everything else in the file (UI creation, premium
// key flow, loader screen, game detection...) is untouched. The exact text below is copied
// verbatim from the current Main.lua — if a future edit to that block changes this text, the
// replace below fails loudly instead of silently bundling a stale/wrong loader.
const OLD_IMPORT_BLOCK = `env.MugiwaraImport = function(path)
    local cached = env.MugiwaraModules[path]
    if cached ~= nil then return cached end

    local ok, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. path))()
    end)
    if not ok then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    env.MugiwaraModules[path] = result
    return result
end`;

function buildNewImportBlock() {
	if (MODE === "single") {
		return `env.MugiwaraImport = function(path)
    local cached = env.MugiwaraModules[path]
    if cached ~= nil then return cached end

    local loader = env.MugiwaraLoaders and env.MugiwaraLoaders[path]
    if not loader then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": module not bundled")
        return nil
    end

    local ok, result = pcall(loader)
    if not ok then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    env.MugiwaraModules[path] = result
    return result
end`;
	}

	// grouped mode: Core is fetched right here (several modules are imported before the first
	// game-specific one), every other group is fetched lazily the first time one of its paths
	// is requested.
	const otherGroups = [...groups.keys()].filter((g) => g !== "Core");
	const prefixLines = otherGroups
		.map((g) => `    { Prefix = "Games/${g}/", File = "${bundleFile(g)}" },`)
		.join("\n");

	return `-- RELEASE BUILD (release/build.mjs, mode=grouped): modul hub sendiri tidak lagi diambil satu
-- per satu. "Core.lua" (Manager/Tabs/Universal) diambil sekali di sini; grup lain diambil begitu
-- path pertamanya diminta. File grup itu sendiri yang mengisi env.MugiwaraLoaders.
env.MugiwaraLoaders = env.MugiwaraLoaders or {}
local fetchedGroups = {}
local GROUP_PREFIXES = {
${prefixLines}
}

local function FetchGroup(file)
    if fetchedGroups[file] then return end
    fetchedGroups[file] = true
    local ok, err = pcall(function()
        loadstring(game:HttpGet(BASE_URL .. file))()
    end)
    if not ok then warn("[Mugiwara HUB] Failed to load " .. file .. ": " .. tostring(err)) end
end

FetchGroup("Core.lua")

env.MugiwaraImport = function(path)
    local cached = env.MugiwaraModules[path]
    if cached ~= nil then return cached end

    if not env.MugiwaraLoaders[path] then
        for _, group in ipairs(GROUP_PREFIXES) do
            if string.sub(path, 1, #group.Prefix) == group.Prefix then
                FetchGroup(group.File)
                break
            end
        end
    end

    local loader = env.MugiwaraLoaders[path]
    if not loader then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": module not found in any bundle")
        return nil
    end

    local ok, result = pcall(loader)
    if not ok then
        warn("[Mugiwara HUB] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end

    env.MugiwaraModules[path] = result
    return result
end`;
}

const OLD_BASE_URL_LINE = `local BASE_URL = "https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/" .. BRANCH .. "/"`;

function patchMainLua() {
	let source = readFileSync(join(ROOT, "Main.lua"), "utf8").replace(/\r\n/g, "\n");

	const baseUrlHits = source.split(OLD_BASE_URL_LINE).length - 1;
	if (baseUrlHits !== 1) {
		throw new Error(
			"Main.lua's BASE_URL line " +
				(baseUrlHits === 0 ? "was not found" : "matched " + baseUrlHits + " times (expected 1)") +
				" — Main.lua changed since release/build.mjs was written. Update OLD_BASE_URL_LINE to match, then rebuild."
		);
	}
	source = source.replace(
		OLD_BASE_URL_LINE,
		`local BASE_URL = "https://raw.githubusercontent.com/${REPO}/" .. BRANCH .. "/"`
	);

	const occurrences = source.split(OLD_IMPORT_BLOCK).length - 1;
	if (occurrences !== 1) {
		throw new Error(
			"Main.lua's MugiwaraImport block " +
				(occurrences === 0 ? "was not found" : "matched " + occurrences + " times (expected 1)") +
				" — Main.lua changed since release/build.mjs was written. Update OLD_IMPORT_BLOCK to match, then rebuild."
		);
	}
	source = source.replace(OLD_IMPORT_BLOCK, buildNewImportBlock());

	if (MODE === "single") {
		// everything core+games is inlined directly above the (now trivial) import function, so
		// Main.lua alone contains the whole hub; no Core.lua/Evade.lua files are produced. Each
		// bundle repeats "getgenv().MugiwaraLoaders = getgenv().MugiwaraLoaders or {}", which is
		// harmless to run more than once (it is a no-op after the first time).
		const allLoaders = [...groups.keys()].sort().map((g) => bundles.get(g)).join("\n");
		const marker = "env.MugiwaraImport = function(path)";
		const index = source.indexOf(marker);
		source = source.slice(0, index) + allLoaders + "\n" + source.slice(index);
	}

	return source;
}

// ---------- 5. write output ----------
rmSync(DIST_DIR, { recursive: true, force: true });
mkdirSync(DIST_DIR, { recursive: true });

function writeLua(relPath, content) {
	writeFileSync(join(DIST_DIR, relPath), content.replace(/\n/g, "\r\n"), "utf8");
}

const patchedMain = patchMainLua();
writeLua("Main.lua", patchedMain);
console.log("\nWrote dist/Main.lua (" + patchedMain.length + " bytes)");

if (MODE === "grouped") {
	for (const [group, source] of bundles) {
		const file = bundleFile(group);
		writeLua(file, source);
		console.log("Wrote dist/" + file + " (" + source.length + " bytes)");
	}
} else {
	console.log("(mode=single: everything is inlined into Main.lua above, no separate bundle files)");
}

// ---------- 6. optional: run Prometheus on every output file ----------
// Prometheus's own CLI (`src/cli.lua`) writes its output NEXT TO the input file by default
// (input.lua -> input.obfuscated.lua, see Prometheus/doc/guides/cli-usage.md), so each file is
// obfuscated in place inside release/dist/ and the result is then moved into
// release/dist/obfuscated/ with its original name, instead of relying on Prometheus's own --out
// (not part of the proven working invocation, so this script does not depend on it).
//
// Copied from Prometheus/src/presets.lua (keep this in sync if presets.lua ever changes there).
// LuaVersion in each preset is overridden to "LuaU" below, to match --LuaU on the CLI.
const PROMETHEUS_PRESETS = {
	Weak: [
		{ Name: "Vmify", Settings: {} },
		{ Name: "ConstantArray", Settings: { Threshold: 1, StringsOnly: true } },
		{ Name: "WrapInFunction", Settings: {} },
	],
	Medium: [
		{ Name: "EncryptStrings", Settings: {} },
		{ Name: "AntiTamper", Settings: { UseDebug: false } },
		{ Name: "Vmify", Settings: {} },
		{ Name: "ConstantArray", Settings: { Threshold: 1, StringsOnly: true, Shuffle: true, Rotate: true, LocalWrapperThreshold: 0 } },
		{ Name: "NumbersToExpressions", Settings: {} },
		{ Name: "WrapInFunction", Settings: {} },
	],
	Strong: [
		{ Name: "Vmify", Settings: {} },
		{ Name: "EncryptStrings", Settings: {} },
		{ Name: "AntiTamper", Settings: { UseDebug: false } },
		{ Name: "Vmify", Settings: {} },
		{ Name: "ConstantArray", Settings: { Threshold: 1, StringsOnly: true, Shuffle: true, Rotate: true, LocalWrapperThreshold: 0 } },
		{ Name: "NumbersToExpressions", Settings: { NumberRepresentationMutation: true } },
		{ Name: "WrapInFunction", Settings: {} },
	],
};

function luaLiteral(value) {
	if (typeof value === "boolean" || typeof value === "number") return String(value);
	return JSON.stringify(String(value)); // good enough: our setting values are plain identifiers/numbers
}

function writePrometheusConfig(path, steps) {
	const stepLines = steps
		.map((step) => {
			const settingLines = Object.entries(step.Settings)
				.map(([k, v]) => `\t\t\t${k} = ${luaLiteral(v)},`)
				.join("\n");
			return `\t\t{ Name = "${step.Name}", Settings = {\n${settingLines}\n\t\t} },`;
		})
		.join("\n");
	writeFileSync(
		path,
		`return {\n\tLuaVersion = "LuaU",\n\tPrettyPrint = false,\n\tVarNamePrefix = "",\n\tNameGenerator = "MangledShuffled",\n\tSeed = 0,\n\tSteps = {\n${stepLines}\n\t},\n}\n`
	);
}

if (OBFUSCATE) {
	const presetName = typeof OBFUSCATE === "string" ? OBFUSCATE : "Medium";
	const presetSteps = PROMETHEUS_PRESETS[presetName];
	if (!presetSteps) {
		console.error("\nUnknown preset '" + presetName + "'. Known presets: " + Object.keys(PROMETHEUS_PRESETS).join(", ") + " (or Minify, which needs no config).");
	}
	const obfDir = join(DIST_DIR, "obfuscated");
	mkdirSync(obfDir, { recursive: true });

	if (!existsSync(LUA_EXE)) {
		console.error("\nLua interpreter not found at " + LUA_EXE + " (pass --lua=<path to lua5.1.exe/luajit.exe>). Skipping obfuscation.");
	} else if (!existsSync(join(PROMETHEUS_DIR, "cli.lua"))) {
		console.error("\ncli.lua not found under " + PROMETHEUS_DIR + " (pass --prometheus=<path to your Prometheus folder>). Skipping obfuscation.");
	} else if (presetSteps) {
		// Known Prometheus bug hit while building this script: its "Vmify" step can crash with
		// "attempt to index local 'a' (a nil value)" on some combined/bundled files (not a problem
		// with any one module on its own — confirmed by testing each module file individually, and
		// by testing this repo's Core.lua bundle, which hits it, right next to Evade.lua, which does
		// not, despite being bigger). If the chosen preset fails, this retries once with the exact
		// same preset minus every "Vmify" step (everything else — string encryption, anti-tamper,
		// constant array, wrap in function — still applies), and says so clearly either way.
		const fallbackPath = join(obfDir, "_fallback.config.lua");
		const outputs = readdirSync(DIST_DIR).filter((f) => f.endsWith(".lua"));
		for (const file of outputs) {
			const input = join(DIST_DIR, file);
			const strayOutput = join(DIST_DIR, file.replace(/\.lua$/, ".obfuscated.lua"));
			const finalOutput = join(obfDir, file);

			function runPrometheus(args, label) {
				console.log("\nObfuscating " + file + " (" + label + ")...");
				execFileSync(LUA_EXE, args, { cwd: PROMETHEUS_DIR, stdio: "inherit" });
				if (!existsSync(strayOutput)) {
					throw new Error("Prometheus did not produce " + strayOutput + " (expected input.lua -> input.obfuscated.lua)");
				}
			}

			try {
				const args = ["cli.lua", "--preset", presetName];
				if (LUAU_TARGET) args.push("--LuaU");
				args.push(input);
				try {
					runPrometheus(args, "preset " + presetName + (LUAU_TARGET ? ", --LuaU" : ""));
				} catch (firstErr) {
					const withoutVmify = presetSteps.filter((s) => s.Name !== "Vmify");
					if (withoutVmify.length === presetSteps.length) throw firstErr; // preset had no Vmify step to drop; not the known bug
					console.error("  preset " + presetName + " failed on " + file + " — retrying without its Vmify step (the usual cause when a large bundled file crashes Prometheus; if this retry fails too, it is something else)...");
					writePrometheusConfig(fallbackPath, withoutVmify);
					runPrometheus(["cli.lua", "--config", fallbackPath, input], presetName + " minus Vmify");
				}

				const before = statSync(input).size;
				const after = statSync(strayOutput).size;
				writeFileSync(finalOutput, readFileSync(strayOutput));
				rmSync(strayOutput);
				console.log("  " + file + ": " + before + " -> " + after + " bytes (" + (after / before).toFixed(2) + "x) -> " + finalOutput);
			} catch (err) {
				console.error("  Prometheus failed on " + file + " even without Vmify: " + err.message);
			}
		}
		rmSync(fallbackPath, { force: true });
	}
}

console.log("\nDone. Output in " + DIST_DIR + " (not committed, not pushed anywhere).");
