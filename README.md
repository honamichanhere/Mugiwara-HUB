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

Supported games: **Evade** (accessories, avatar morph). Every other game gets the **Universal** movement module.

## Folder structure

```
Main.lua                 Entry point: auth, window, tab loader, game detector
Universal.lua            Fallback module for games without their own module
Tabs/                    UI tabs (Home, Lighting, Camera, MovementInjector)
Manager/                 Logic behind the tabs (Movement, Camera, Lighting, Reflection)
Games/<Game>/Init.lua    One folder per supported game
```

Every file is loaded through `getgenv().MugiwaraImport("<path>")`, defined in `Main.lua`.
The base URL lives in one place (`BASE_URL` in `Main.lua`).

## Adding a game

1. Create `Games/<Game>/Init.lua` that returns `function(Window, isPremiumUser, WindUI) ... end`.
2. Add its PlaceIds and path to `SupportedGames` in `Main.lua`.

## Release tip

`BASE_URL` points to `refs/heads/main`, so every push to `main` goes live for all users right away.
For a stable release, replace `refs/heads/main` with a commit hash.
