# Mugiwara HUB

Roblox script hub by Honami, built on [WindUI](https://github.com/Footagesus/WindUI) with key validation through Panda Auth.

## Features

| Tab | What it has |
| --- | --- |
| Premium Access | Key activation and premium purchase info |
| Home | Player and server info, links, credits |
| Lighting | Presets, skybox, atmosphere, bloom, blur, color correction, depth of field, sun rays, reflection effect |
| Camera | Free camera, spectate, FOV and zoom lock, stabilizers |
| Main (per game) | Character movement (speed, jump, fly, noclip), plus game-specific modules |
| Misc | Global utilities: Anti-AFK, Auto Rejoin, Rejoin, Server Hop, Join by Job ID, rebindable keyboard shortcuts, Unload Hub |

Supported games: **Evade** (accessories, avatar morph). Every other game gets the **Universal** movement module.

## Folder structure

```
Main.lua                 Entry point: auth, window, tab loader, game detector
Universal.lua            Fallback module for games without their own module
Tabs/                    UI tabs (Home, Lighting, Camera, Misc, MovementInjector)
Manager/                 Logic behind the tabs (Movement, Camera, Lighting, Reflection, Server, Keybinds)
Games/<Game>/Init.lua    One folder per supported game
```

Every file is loaded through `getgenv().MugiwaraImport("<path>")`, defined in `Main.lua`.

## Branches

| Branch | Purpose |
| --- | --- |
| `main` | Stable. This is what every user runs. |
| `dev` | Single testing branch. Overwrite it for each new feature, then merge into `main` once tested. |

`BASE_URL` is built from `getgenv().MugiwaraBranch` (default `main`), so the code is identical on both
branches and nothing has to be edited before merging. To test `dev`, run:

```lua
getgenv().MugiwaraBranch = "dev"
loadstring(game:HttpGet("https://raw.githubusercontent.com/honamichanhere/Mugiwara-HUB/dev/Main.lua"))()
```

For a pinned release, set `MugiwaraBranch` to a commit hash.

## Re-execution safety

Every module that creates connections, loops or instances registers a teardown function:

```lua
getgenv().MugiwaraRegisterCleanup(function()
    -- disconnect, destroy, restore
end)
```

When `Main.lua` runs again (re-execute, or the automatic reload after activating a premium key) all
registered teardowns run first, in reverse order. Nothing from the previous session stacks on the new one.
New modules must register a teardown if they create anything that outlives a function call.

## Local data

Saved premium key, lighting presets and the copied skybox live in the executor workspace folder
`MugiwaraHub/`. Data from the old `HonamiHub/` folder is copied over automatically on first run.

## Adding a game

1. Create `Games/<Game>/Init.lua` that returns `function(Window, isPremiumUser, WindUI) ... end`.
2. Add its PlaceIds and path to `SupportedGames` in `Main.lua`.
3. Register a teardown for anything the game module creates.

## Conventions

- All UI text, notifications and identifiers are in English.
- Code comments may be in Indonesian.
- The version number lives in one place: `VERSION` at the top of `Main.lua`.

## Keyboard shortcuts

Shortcuts are **off by default** (Misc > Keyboard Shortcuts > Enable Keyboard Shortcuts). Defaults, all rebindable and saved in `MugiwaraHub/Keybinds.json`:

| Action | Key |
| --- | --- |
| Show / Hide Hub | `K` |
| Fly | `Y` |
| Noclip | `N` |
| Speed Hack | `Z` |
| Infinite Jump | `J` |
| Free Camera (premium) | `P` |
| Panic: Unload Hub | `End` |

`getgenv().MugiwaraImport` caches modules per session, so a module imported by several tabs is
always the same instance. Toggle shortcuts flip the real UI toggle (through `Module.UI`) so the
on-screen switch stays in sync.
