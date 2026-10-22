# Mugiwara HUB

Roblox script hub by Honami, built on [WindUI](https://github.com/Footagesus/WindUI) with key validation through Panda Auth.

## Features

| Tab | What it has |
| --- | --- |
| Premium Access | Key activation and premium purchase info |
| Home | Player and server info, links, credits |
| Lighting | Presets, skybox, atmosphere, bloom, blur, color correction, depth of field, sun rays, volumetric clouds, hide sun |
| Camera | Free camera, spectate, FOV and zoom lock, stabilizers |
| Main (per game) | Character movement (speed, jump, fly, noclip), plus game-specific modules |
| Misc | Global utilities: Anti-AFK, Auto Rejoin, Rejoin, Server Hop, Join by Job ID, rebindable keyboard shortcuts, Unload Hub |

Supported games: **Evade** (accessories, avatar morph, Halloween Ticket Farm with NextBot avoidance). Every other game gets the **Universal** movement module.

## Folder structure

```
Main.lua                 Entry point: auth, window, tab loader, game detector
Universal.lua            Fallback module for games without their own module
Tabs/                    UI tabs (Home, Lighting, Camera, Misc, MovementInjector)
Manager/                 Logic behind the tabs (Movement, Camera, Lighting, Reflection (script kept, not wired to the UI for now), Server, Keybinds, Cursor, Risk)
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

## Evade VIP commands

`Games/Evade/VIPCommands.lua` sends VIP commands exactly like the in-game VIP menu does:
`ReplicatedStorage.Events.Admin.VIPCommand:FireServer("!timer 1")`.
It only runs commands the game marks as `VIPMenuAccessible` and needs the `VIPCommandsAccess`
attribute (server owners). Commands that disable rewards are NOT blocked; the user decides.
The command list is read from the game's own `ReplicatedStorage.Shared.Admin.Commands.Commands`
module.

## Evade AFK Farm and Auto Commands

Evade Main tab order: Premium Features (AFK Farm on top, then the visual features), Halloween Ticket
Farm, Auto Commands, Character Movement. All sections start collapsed, except Premium Activation.

- **AFK Farm** (premium, inside Premium Features): parks the character at saved coordinates (`x, y, z`)
  and keeps Fly on so it hovers there. With no coordinates saved it holds the spot where it was turned on.
- **Auto Commands** (free) > **Auto Execute**: any number of events (up to 10, "Create New Event"), each
  `Command > Trigger > Delay`. Triggers: Character Died, Character Spawned, Intermission, Round Start,
  Round End, Vote. The round triggers come from `ReplicatedStorage.Events.UpdateServerStateRegistry`, which
  sends `("RoundStatus", n)`: 0 = no round (waiting / round over), 1 = intermission, 2 = round running.
  They fire only when the status changes (the first value seen after joining is just the baseline), and
  Round End fires on any change to 0. Vote fires when `("Voting", true)` arrives on the same event. The section
  starts with a notice: it only works with VIP Commands access or as owner of the Private Server / Community.
  After the trigger fires the hub waits the delay, then sends the
  command through `VIPCommands`.
- Events and coordinates are saved in `MugiwaraHub/AfkFarm.json`; the toggles always start OFF.

`VIPCommands` matches asset arguments (special rounds, maps, tools, NPCs...) against the same folder
the VIP menu lists (`commandStringParents`), ignoring case and spaces, so `!specialround Plushie Hell`
is sent with the real instance name. If nothing matches it reports close names instead of sending.

If the executor cannot `require` the game's command module, `VIPCommands` falls back to
the built-in copy inside `Games/Evade/VIPCommands.lua` (`BuildStaticList`) with the command definitions (names, argument
layout, `VIPMenuAccessible`, `VIPCommandDisablesRewards`, asset folders). Commands from the
modules that have not been decompiled yet (Admin, Fun, Camera, Data, Developer, Announcements)
need to be added to that list.

## Free cursor

`Manager/Cursor.lua` frees the mouse while the hub window is open. Shift lock (Roblox's or a game's
own, like Evade's) locks the mouse to the screen centre through `UserInputService.MouseBehavior`,
which makes the UI unclickable. On open the previous `MouseBehavior`/`MouseIconEnabled`/`MouseIcon`
are recorded and overridden every frame (render priority after the game's camera scripts). If the
game writes a new value while the hub is open (for example shift lock toggled), the record is
updated, so on close the game's latest state is restored.
Hooked in `Main.lua` with
`Window:OnOpen` and `Window:OnClose`; can be turned off with Misc > Hub > Free Cursor When Open.
Misc > Hub > Lock Cursor releases the free-cursor override and locks the mouse to the centre
immediately; it is free again the next time the window is opened.

## Risk markers

`Manager/Risk.lua` lists the features that are easy for the game (Evade) to detect because position, speed
and remote calls are checked server-side: Speed Hack, Tween Speed, Jump Power, Infinite Jump, Fly, Noclip,
AFK Farm, Auto Execute (Auto Commands), Auto Farm Tickets and Avoid NextBots. Their description starts with
`[HIGH RISK]` and turning one ON shows a warning notification with the reason. Nothing is blocked; it only
marks and warns. Visual features (Lighting, Korless, camera, ...) only change the client's view and are not marked.
