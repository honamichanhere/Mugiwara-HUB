# Release bundler

Turns this repo's ~40 separate module files into 1-3 files for a public "release" repo, so the
hub can stay closed-source here while the loader stays plain GitHub raw. See the chat for the full
reasoning; this file is just the how-to.

## Checklist, every time you publish a release

1. `node release/build.mjs --repo=<owner>/<release-repo-name> --obfuscate`
   **`--repo` is not optional** if your release repo's name is anything other than
   `honamichanhere/Mugiwara-HUB`. `Main.lua`'s own `BASE_URL` (which it uses to fetch `Core.lua`
   and the game bundles, and to reload/queue itself) is hardcoded in the source to that name;
   leaving `--repo` out means `Main.lua` loads fine from wherever you actually put it, but then
   404s trying to fetch everything else from the wrong repo. (This bit the first real release —
   see `OLD_BASE_URL_LINE` in `build.mjs` for how it's patched.)
2. `node release/verify.mjs` — confirms the clean bundle before you bother obfuscating it.
3. Upload every file from `release/dist/obfuscated/` to your release repo, overwriting the old
   ones.
4. Build your own loader URL and **check it character by character** before testing —
   `hhttps://` (an extra `h`) looks like `https://` at a glance and fails with a vague
   `HttpGet`/`Can't parse JSON` error that has nothing to do with the hub itself.
5. Test the loader in a real executor before telling anyone it's ready. Nothing in `verify.mjs`
   proves the hub still works after Prometheus has rewritten it — only an actual run does.

## Why bundle at all

Today `getgenv().MugiwaraImport(path)` does one `HttpGet` per module — about 40 per execute (more
in Evade). Bundling moves that to 1-3 requests without changing *when* any module runs: each
module's source is wrapped as `getgenv().MugiwaraLoaders["path"] = function(...) <source> end` and
only executed the first time something imports that path, exactly like today. Nothing about the
hub's behaviour changes; only how its own source travels from GitHub to the executor changes.

## Two modes

```bash
node release/build.mjs                  # mode=grouped (default)
node release/build.mjs --mode=single     # mode=single
```

**`grouped`** (default) — one bundle per "group": `Core.lua` (everything in `Manager/`, `Tabs/`,
`Universal.lua` — always needed) and one bundle per supported game, e.g. `Evade.lua`
(`Games/Evade/*.lua` — only fetched if the player is actually in that game). `Main.lua` stays a
separate, thin file (the loadstring() entry point); it fetches `Core.lua` once at the top, then
fetches a game bundle the first time something imports a path under its prefix.
- Universal-game player: `Main.lua` + `Core.lua` = 2 requests, ~284 KB raw.
- Evade player: `Main.lua` + `Core.lua` + `Evade.lua` = 3 requests, ~484 KB raw (Evade's 200 KB
  only loads for Evade players).
- A new supported game gets its own bundle automatically — the discovery step scans
  `Games/<Game>/` and nothing else needs editing.

**`single`** — everything (Core + every game) is inlined directly into one `Main.lua`. 1 request,
~483 KB raw, always — a non-Evade player downloads Evade's code too, just never runs it (still
only a few hundred KB of plain text, cheap to parse; the actual avatar/animation logic never
executes unless that game's `Init.lua` is actually called).

Pick `grouped` unless you want the absolute minimum number of requests regardless of game and
don't mind every player fetching code for games they're not in. The numbers above are this
session's real measurement of the current repo, not an estimate — run the build again any time the
codebase changes to get fresh ones (`node release/build.mjs` prints the byte size of every file it
writes).

## Verifying a build

```bash
node release/verify.mjs
```

Checks (details and why each one matters are in the comments at the top of `verify.mjs`):
1. every output file is syntactically valid Lua (fengari, no Lua install needed)
2. every module on disk ends up in exactly one bundle — none missing, none duplicated
3. loading a bundle (not importing a module from it) has zero side effects — proves no module's
   top-level code leaked outside its `function(...) ... end` wrapper
4. two real, representative modules (`Manager/Risk.lua`, `Manager/Keybinds.lua`) are actually
   called through the bundle and their output is checked against what they're known to do

This proves the *bundling transform* didn't corrupt anything. It does **not** replace testing the
actual hub in a real game, and it does **not** check anything after obfuscation — run it on the
clean bundle, then obfuscate, then test the obfuscated file in a real executor separately.

## Obfuscating

```bash
node release/build.mjs --obfuscate --repo=<owner>/<release-repo>   # see the checklist above
node release/build.mjs --obfuscate=Strong --repo=<owner>/<release-repo>
node release/build.mjs --obfuscate --lua="D:\Downloads\Lua\lua5.1.exe"
node release/build.mjs --obfuscate --prometheus="D:\Document\Prometheus"
node release/build.mjs --obfuscate --no-luau        # target plain Lua 5.1 instead of LuaU
```

Runs every file in `release/dist/` through your local Prometheus install and writes the result to
`release/dist/obfuscated/`. This calls `<lua> cli.lua --preset <preset> --LuaU <input>` with the
Prometheus folder as the working directory — the same invocation proven to work on this machine
(`"D:\Downloads\Lua\lua5.1.exe" cli.lua --preset Medium --LuaU <file>` run from inside
`D:\Document\Prometheus`). It does **not** call the `prometheus-lua` wrapper script directly —
that file has no `.exe`/shebang handling on Windows, so Node's `execFileSync` can't launch it and
fails with `ENOENT` even though the file exists. Defaults: `--lua` = `D:\Downloads\Lua\lua5.1.exe`,
`--prometheus` = `D:\Document\Prometheus` (the folder, not the wrapper script).

**Known Prometheus bug, worked around automatically:** its `Vmify` step can crash with
`attempt to index local 'a' (a nil value)` on some bundled files — hit on this repo's `Core.lua`,
not on `Evade.lua` despite it being the bigger file, so it is about the specific content, not
simple file size. Confirmed by testing every module file individually through Prometheus (all
passed alone) and by testing smaller combinations (some passed, some didn't) — this is a Prometheus
limitation, not a sign of broken Lua in any of this repo's own files. When a preset fails, the
build script automatically retries the SAME preset with only its `Vmify` step removed (string
encryption, anti-tamper, constant array and wrap-in-function still apply) and says so in the
output; if that retry also fails, it reports the real error instead of hiding it. Measured on this
repo: `Core.lua` 260 KB -> 476 KB (1.79x, used the no-Vmify fallback), `Evade.lua` 200 KB -> 835 KB
(4.07x, full preset worked), `Main.lua` 24 KB -> 100 KB (4.05x, full preset worked).

Presets, from `Prometheus/src/presets.lua` (not just the docs — read directly from the source, in
case the docs ever drift):

| Preset | Steps | Notes |
| --- | --- | --- |
| `Minify` | none (renaming only) | smallest/fastest, no real protection, never hits the Vmify bug |
| `Weak` | Vmify, ConstantArray, WrapInFunction | light, no string encryption |
| `Medium` | EncryptStrings, AntiTamper, Vmify, ConstantArray, NumbersToExpressions, WrapInFunction | good default |
| `Strong` | Vmify twice, EncryptStrings, AntiTamper, ConstantArray, NumbersToExpressions, WrapInFunction | heaviest, biggest file, slowest to load |

Start with `Medium` and actually load the result in-game in your usual executors (Delta, Xeno,
Solara, ...) before deciding whether `Strong` is worth its extra size and parse time — `Strong`
runs `Vmify` twice, so it is more likely to hit the same bug (the automatic fallback still applies,
it would just drop both `Vmify` steps). The growth factors above (1.8x-4.1x) are this session's own
measurement of this repo's actual bundles, not an estimate — re-run `--obfuscate` any time the
codebase changes for fresh numbers; `Weak`/`Minify` grow far less but protect far less too.

## What this does and does not do

- Builds and verifies **locally only**. It never touches git, never creates or pushes to any
  repo, and `release/dist/` is gitignored on purpose — review the output yourself before pushing
  it anywhere.
- `Main.lua`'s own orchestration code (UI creation, premium key flow, loading screen, game
  detection) is untouched; the only change is the small block that resolves
  `getgenv().MugiwaraImport(path)` (see `OLD_IMPORT_BLOCK` in `build.mjs` — the patch fails loudly
  instead of silently if that block ever changes shape).
- Does not touch the Mugiwara UI library fetch (`Mugiwara-UI/.../dist/main.lua`) or the Panda Auth
  library fetch — those stay external, exactly as today.
- Does not gate anything by premium status. Free and premium code both end up in the same bundles,
  obfuscated or not — obfuscation only makes the *source* harder to read, it does not stop a
  non-premium user from reading premium code paths if they bother to deobfuscate or trace it at
  runtime. If you want premium logic to be genuinely unavailable to non-payers (not just harder to
  read), that needs a server that only serves it after checking a key — a different project from
  this bundler.
