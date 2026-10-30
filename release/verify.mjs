#!/usr/bin/env node
// Checks release/dist/ (produced by release/build.mjs) before it is obfuscated or published.
// Uses fengari (a pure-JS Lua VM, already a dependency of Mugiwara UI's own test suite) so this
// runs without installing a Lua interpreter.
//
//   1. every output file is syntactically valid Lua
//   2. the bundles contain exactly the modules on disk, no duplicates, none missing
//   3. loading a bundle (NOT importing a module from it) has zero side effects: with no Roblox
//      globals defined at all, Core.lua/Evade.lua must still load and run cleanly, because every
//      module body is wrapped in a function and none of them should execute yet. If this fails,
//      something in the bundle is running at bundle-load time instead of at import time.
//   4. a couple of dependency-light modules are actually called (through the same
//      getgenv().MugiwaraLoaders[path]() path Main.lua uses) and their shape is sanity-checked
//
// This does NOT replace testing the hub in a real game, or in a real executor after obfuscation:
// it only proves the bundling transform itself (wrap each module's source in a function, patch
// Main.lua's loader) did not corrupt anything.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const RELEASE_DIR = dirname(fileURLToPath(import.meta.url));
const ROOT = dirname(RELEASE_DIR);
const DIST_DIR = join(RELEASE_DIR, "dist");

// reuse the fengari install already vendored for Mugiwara UI's own tests
const MUI_CANDIDATES = [
	join(ROOT, "..", "Mugiwara UI"),
	"C:/Users/ichin/AppData/Local/Temp/claude/D--Document-Roblox-Script-Mugiwara-HUB-Local/73ba8814-bac4-4e57-8612-e0484d517efe/scratchpad/mui",
];
let fengari;
for (const candidate of MUI_CANDIDATES) {
	const pkg = join(candidate, "package.json");
	if (existsSync(pkg)) {
		try {
			fengari = createRequire(pkg)("fengari");
			break;
		} catch {
			/* try next candidate */
		}
	}
}
if (!fengari) {
	console.error("Could not find a fengari install (checked: " + MUI_CANDIDATES.join(", ") + ").");
	console.error("Run `npm install` in one of those folders, or edit MUI_CANDIDATES in this script.");
	process.exit(1);
}
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

let failures = 0;
function fail(message) {
	failures++;
	console.log("FAIL: " + message);
}
function ok(message) {
	console.log("ok   " + message);
}

// ---------- helpers ----------
function runLua(label, code) {
	const L = lauxlib.luaL_newstate();
	lualib.luaL_openlibs(L);
	const loadStatus = lauxlib.luaL_loadbuffer(L, to_luastring(code), null, to_luastring("=" + label));
	if (loadStatus !== lua.LUA_OK) {
		return { ok: false, error: "syntax error: " + to_jsstring(lua.lua_tostring(L, -1)) };
	}
	const callStatus = lua.lua_pcall(L, 0, 0, 0);
	if (callStatus !== lua.LUA_OK) {
		return { ok: false, error: "runtime error: " + to_jsstring(lua.lua_tostring(L, -1)) };
	}
	return { ok: true };
}

function scanLuaFiles(dir) {
	const out = [];
	for (const name of readdirSync(dir)) {
		const full = join(dir, name);
		const st = statSync(full);
		if (st.isDirectory()) out.push(...scanLuaFiles(full));
		else if (name.endsWith(".lua")) out.push(full);
	}
	return out;
}
function toRepoPath(absolute) {
	return relative(ROOT, absolute).split(sep).join("/");
}

if (!existsSync(DIST_DIR)) {
	console.error("release/dist not found — run `node release/build.mjs` first.");
	process.exit(1);
}

// ---------- 1. syntax ----------
console.log("== syntax ==");
const outputs = readdirSync(DIST_DIR).filter((f) => f.endsWith(".lua"));
if (outputs.length === 0) fail("no .lua files in release/dist");
for (const file of outputs) {
	const source = readFileSync(join(DIST_DIR, file), "utf8");
	const result = runLua(file + " (syntax only)", "if false then\n" + source + "\nend"); // parse without running
	// the above still fully parses the body (it's inside an `if false then`), which is enough
	// to catch mismatched end/function/string errors without needing any Roblox globals.
	if (result.ok || result.error.startsWith("runtime error")) {
		ok(file + " parses");
	} else {
		fail(file + ": " + result.error);
	}
}

// ---------- 2. manifest completeness ----------
console.log("\n== manifest ==");
const SCAN_ROOTS = ["Manager", "Tabs", "Games"];
const EXTRA_FILES = ["Universal.lua"];
const expectedPaths = new Set();
for (const root of SCAN_ROOTS) {
	const dir = join(ROOT, root);
	if (existsSync(dir)) for (const f of scanLuaFiles(dir)) expectedPaths.add(toRepoPath(f));
}
for (const f of EXTRA_FILES) if (existsSync(join(ROOT, f))) expectedPaths.add(f);

// mode=grouped produces separate Core.lua/Evade.lua/... files; mode=single inlines everything
// into Main.lua itself and produces no other file. Scan whichever files actually carry
// "MugiwaraLoaders[...] = function" entries, so both modes are checked the same way.
const bundleFiles = outputs.filter((f) => readFileSync(join(DIST_DIR, f), "utf8").includes('MugiwaraLoaders["'));
const singleFileMode = bundleFiles.length === 1 && bundleFiles[0] === "Main.lua";
console.log(singleFileMode ? "(mode=single: checking Main.lua as the one bundle)" : "(mode=grouped: checking " + bundleFiles.join(", ") + ")");

const foundPaths = new Map(); // path -> [bundle file, ...] (should end up length 1 each)
for (const file of bundleFiles) {
	const source = readFileSync(join(DIST_DIR, file), "utf8");
	const matches = source.matchAll(/MugiwaraLoaders\["([^"]+)"\]\s*=\s*function\(\.\.\.\)/g);
	for (const m of matches) {
		const path = m[1];
		if (!foundPaths.has(path)) foundPaths.set(path, []);
		foundPaths.get(path).push(file);
	}
}

const missing = [...expectedPaths].filter((p) => !foundPaths.has(p));
const unexpected = [...foundPaths.keys()].filter((p) => !expectedPaths.has(p));
const duplicated = [...foundPaths.entries()].filter(([, files]) => files.length > 1);

if (missing.length) fail("on disk but missing from every bundle: " + missing.join(", "));
else ok("every module on disk (" + expectedPaths.size + ") is in a bundle");
if (unexpected.length) fail("bundled but not found on disk (stale?): " + unexpected.join(", "));
if (duplicated.length) fail("bundled more than once: " + duplicated.map(([p, f]) => p + " in " + f.join(" and ")).join("; "));
else if (!missing.length) ok("no module is bundled twice");

// ---------- 3. loading a bundle has no side effects ----------
console.log("\n== bundle load has zero side effects ==");
if (singleFileMode) {
	console.log("(skipped in mode=single: Main.lua itself has real top-level side effects by design — UI/key screen/HttpGet — unrelated to bundling, so this check only makes sense for a bundle file that holds ONLY wrapped modules)");
}
for (const file of singleFileMode ? [] : bundleFiles) {
	const source = readFileSync(join(DIST_DIR, file), "utf8");
	const code = `
local store = {}
getgenv = function() return store end
` + source + `
local count = 0
for _ in pairs(store.MugiwaraLoaders or {}) do count = count + 1 end
assert(count > 0, "MugiwaraLoaders ended up empty")
`;
	const result = runLua(file + " (load, no Roblox globals)", code);
	if (result.ok) {
		ok(file + " loads cleanly with NO Roblox globals defined (nothing ran eagerly)");
	} else {
		fail(file + " is not inert at load time: " + result.error + " — a module's top-level code may be running outside its function wrapper");
	}
}

// ---------- 4. a couple of modules actually work when called ----------
console.log("\n== spot check: calling real modules through the bundle ==");
if (singleFileMode) {
	console.log("(skipped in mode=single: isolating one module's call from Main.lua's own top-level flow is not practical here; mode=grouped exercises this instead)");
}
function callModule(bundleFile, path, stubs, assertions) {
	const source = readFileSync(join(DIST_DIR, bundleFile), "utf8");
	const code = `
local store = {}
getgenv = function() return store end
${stubs || ""}
${source}
local loader = store.MugiwaraLoaders["${path}"]
assert(loader, "loader missing for ${path}")
local ok, mod = pcall(loader)
assert(ok, "module errored: " .. tostring(mod))
${assertions}
`;
	return runLua(path + " (call)", code);
}

let result = singleFileMode
	? null
	: callModule(
			"Core.lua",
			"Manager/Risk.lua",
			"",
			`
assert(type(mod.Features) == "table", "Risk.Features missing")
assert(mod.Features.Fly and mod.Features.Fly.Name == "Fly", "Risk.Features.Fly wrong shape")
`
	  );
if (result) {
	if (result.ok) ok("Manager/Risk.lua returns its feature table unchanged");
	else fail("Manager/Risk.lua: " + result.error);
}

result = singleFileMode
	? null
	: callModule(
	"Core.lua",
	"Manager/Keybinds.lua",
	`
Enum = { KeyCode = setmetatable({}, { __index = function(_, k) return { Name = k } end }) } -- bare-bones stand-in, real Enum is a Roblox global
game = { GetService = function() return { JSONEncode = function() return "{}" end, JSONDecode = function() return {} end } end }
`,
	`
assert(type(mod.IsValidKey) == "function" and type(mod.Set) == "function", "Keybinds API missing")
assert(mod.IsValidKey("K") == true, "a string key name should be valid with the Enum stand-in")
assert(mod.IsValidKey(42) == false, "a non-string is never a valid key")
assert(mod.GetEnabled() == false, "shortcuts should default to OFF")
`
);
if (result) {
	if (result.ok) ok("Manager/Keybinds.lua behaves the same wrapped as it does standalone");
	else fail("Manager/Keybinds.lua: " + result.error);
}

// ---------- 5. Main.lua still points BASE_URL at itself for reload / teleport queue ----------
console.log("\n== Main.lua sanity ==");
const mainSource = readFileSync(join(DIST_DIR, "Main.lua"), "utf8");
if (mainSource.includes('BASE_URL .. "Main.lua"') || mainSource.includes("BASE_URL .. 'Main.lua'")) {
	ok("self-reload / teleport-queue string still uses BASE_URL + Main.lua");
} else {
	fail("could not find the BASE_URL .. \"Main.lua\" self-reload string in dist/Main.lua");
}
const leftoverPerModuleFetch = /HttpGet\(BASE_URL\s*\.\.\s*path\)/.test(mainSource);
if (leftoverPerModuleFetch) fail("dist/Main.lua still fetches BASE_URL .. path per module (old behavior, should be gone)");
else ok("no more per-module HttpGet in dist/Main.lua (only per-group, via FetchGroup)");

// ---------- summary ----------
console.log("\n" + (failures === 0 ? "ALL CHECKS PASSED" : failures + " check(s) FAILED"));
process.exit(failures === 0 ? 0 : 1);
