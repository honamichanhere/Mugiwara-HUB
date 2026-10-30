# Mugiwara HUB

Roblox script hub by Honami, built on [Mugiwara UI](https://github.com/honamichanhere/Mugiwara-UI) with key validation through Panda Auth.

## Features

| Tab | What it has |
| --- | --- |
| Premium Access | Key activation and premium purchase info |
| Home | Player and server info, links, credits |
| Lighting | Presets (share them with a code), skybox picker with preview pictures, atmosphere, bloom, blur, color correction, depth of field, sun rays, volumetric clouds, hide sun |
| Camera | Free camera, spectate, FOV and zoom lock, stabilizers |
| Main (per game) | Character movement (speed, jump, fly, noclip), plus game-specific modules |
| Misc | Global utilities: Anti-AFK, Auto Rejoin, Rejoin, Server Hop, Join by Job ID, rebindable keyboard shortcuts, Hide GUI, Unload Hub |
| Chat | Live chat with everyone running the hub (needs the chat server address in `Main.lua`) |
| UI Config (Appearance) | Theme picker, theme creator, wallpaper, UI scale, background blur. Saved in `MugiwaraHubConfig/UISettings.json`; nothing to do with the game |

**Accessory + Korless** (premium; Universal and Evade): one shared module, `Manager/VisualAccessories.lua`, with one shared UI
builder, `Tabs/VisualAvatarUI.lua`. Only the list of rigs differs: Universal changes `LocalPlayer.Character`, Evade changes
every rig named after you in `Workspace.Rigs` (`Games/Evade/VisualAccessories.lua` plugs in `Games/Evade/Rigs.lua`). Each UI part
is built once per session (a second attempt is skipped with a warning), and Main.lua loads either a game module or
Universal, never both. Korblox Right Leg works like the Korless-Visual script: on R15 it swaps the mesh and texture of the leg parts in place (no
part or joint is replaced), copying them from a cache model built from your avatar, and puts back the look the leg had
before; R6 swaps the leg part. Korblox Left Leg uses the same code with its own cache model whose left leg is the
"Korblox Deathspeaker Left Leg" asset (139607673) in the left slot; the cache that serves the right leg is never used for
the left one (it made the left leg come out as black shards on R15). The caches are built in the background after the
section is created for premium users (like the Korless-Visual script does at start) and, if needed, the first time a
Korblox toggle is used, so free users never trigger it.

**Lighting presets** (Lighting tab, premium): the Load Presets list shows your own saved presets first, then Default and the
built-in ones; loading a preset also selects its skybox in the Sky Box picker, and **Delete Preset** removes a saved one (after a
confirmation; Default and built-in presets cannot be deleted). **Share Preset** copies a code (`MWL1:...`, a few hundred characters) of the preset picked in Load Presets;
**Load Preset via Code** applies a code from someone else and saves it to your list under a free name (never over one of
yours). Codes carry the lighting values and the sky (texture ids); everything in a code is checked before use (types,
slider ranges, only asset ids or Roblox's own rbxasset:// textures). The Sky Box picker is a grid with the Roblox store
thumbnail of each sky, fetched in the background (needs `request`, `writefile` and `getcustomasset`; without them the
tiles show an icon).

**Free camera look** (Camera tab, premium): turn with the mouse (hold Right-Click) or the Arrow Keys. Mouse turning uses the same
base as Roblox's own camera (0.5 degrees per pixel, vertical 0.77x) times the Camera Sensitivity from your Roblox settings, read
live (**Match Roblox Sensitivity**, on by default); switch it off to use the **Mouse Sensitivity** slider instead (1 = Roblox
default). The Arrow Keys turn 40 degrees per second (deliberately slower than Roblox's 120, which was too fast even at the lowest multiplier) and ignore the mouse sensitivity. **Horizontal Speed
(Left / Right)** and **Vertical Speed (Up / Down)** are separate multipliers (0.1x to 5x) that apply to both the mouse and the
Arrow Keys.

Supported games: **Evade** (accessories, avatar morph, Halloween Ticket Farm with NextBot avoidance and a 0 to 20 second **Teleport Delay** between ticket teleports; escaping a NextBot is never delayed). Every other game gets the **Universal** module: character movement plus the premium **Accessory** and **Korless** sections (the same ones Evade has, applied to your normal R6 / R15 character).

## Folder structure

```
Main.lua                 Entry point: auth, window, tab loader, game detector
Universal.lua            Fallback module for games without their own module
Tabs/                    UI tabs (Home, Lighting, Camera, Misc, Chat, UIConfig, MovementInjector, VisualAvatarUI, ShortcutsUI)
Manager/                 Logic behind the tabs (Movement, VisualAccessories, Camera, Lighting, Reflection (script kept, not wired to the UI for now), Server, Keybinds, Shortcuts, Cursor, Risk, HideGui, UIExtras, UISettings)
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

1. Create `Games/<Game>/Init.lua` that returns `function(Window, isPremiumUser, MugiwaraUI) ... end`.
2. Add its PlaceIds and path to `SupportedGames` in `Main.lua`.
3. Register a teardown for anything the game module creates.

## UI library

The hub uses [Mugiwara UI](https://github.com/honamichanhere/Mugiwara-UI) for the key card, the loading screen, the window and every element. `Main.lua` loads it from a **pinned tag** (`UI_VERSION`), so a later push to the library cannot break the hub; change that tag to upgrade.

Icons follow the theme accent. Only premium things are coloured (`IconColor`, gold like the premium titles): the Premium Access tab, the Premium Features sections and the activation controls.

`Manager/UIExtras.lua` adds a few things the library does not have, from the hub side: the "Premium Only" text on locked elements (`LockedTitle`), a thumbnail beside a Paragraph (`Image` + `ImageSize`), coloured Tab and Section titles (`<font color=...>`), an icon in the Section header (`Icon` + `IconColor`), `SetValue` / `SetColor`, and open / close callbacks for the window.

## Conventions

- All UI text, notifications and identifiers are in English.
- Code comments may be in Indonesian.
- The version number lives in one place: `VERSION` at the top of `Main.lua`.

## Keyboard shortcuts

Shortcuts are **off by default** (Misc > Keyboard Shortcuts > Enable Keyboard Shortcuts). The section holds:

- **Show / Hide Hub** (`K` by default): always there, you can only change its key. Saved in `MugiwaraHub/Keybinds.json`.
- **Your own shortcuts** (`Add Shortcut`, up to 20, saved in `MugiwaraHub/Shortcuts.json`). Each one is a small
  section with a **Name**, a **Type** (Toggle, Slider or Button, the only kinds you can bind), the **Feature** it runs,
  what to do (**When pressed**: Toggle / Turn On / Turn Off for a toggle, a **Value** for a slider, nothing for a
  button), the **Key** and **Delete Shortcut**. The Feature list holds every switch, slider or button of the hub,
  named `Title - Tab > Section`, and it grows by itself when other tabs finish building. A shortcut for a feature that
  is not in this game stays saved and just says it is not available. Premium features stay locked for free users.

How it works: `Manager/UIExtras.lua` records every Toggle, Slider and Button as it is created
(`Window._MugiwaraControls`; elements made with `NoShortcut = true` are skipped, destroyed ones are dropped), so a
feature needs no shortcut code of its own. `Manager/Shortcuts.lua` holds the data and runs a shortcut by setting the
real UI element (so the callback runs and the on-screen control stays in sync); `Tabs/ShortcutsUI.lua` is the UI.
A single-row element that holds name, type, feature, value, key and delete together would need a new element in
Mugiwara UI; for now each shortcut is one collapsible section.

`getgenv().MugiwaraImport` caches modules per session, so a module imported by several tabs is
always the same instance.

## Evade VIP commands

`Games/Evade/VIPCommands.lua` sends VIP commands exactly like the in-game VIP menu does:
`ReplicatedStorage.Events.Admin.VIPCommand:FireServer("!timer 1")`.
It only runs commands the game marks as `VIPMenuAccessible` and needs the `VIPCommandsAccess`
attribute (server owners). Commands that disable rewards are NOT blocked; the user decides.
The command list is read from the game's own `ReplicatedStorage.Shared.Admin.Commands.Commands`
module.

## Evade AFK Farm and Auto Commands

Evade Main tab order: Premium Features, Halloween Ticket Farm, Auto Commands, Visual Carry, Character Movement. All
sections start collapsed, except Premium Activation. Premium Features is split into six sections of its
own: **Auto Farm** (AFK Farm), **Accessory**, **Korless** (Headless Head, Korblox legs), **Avatar Changer**,
**Visual Emotes** and **Visual Unusual**.

- **AFK Farm** (premium, inside Premium Features): builds a small 50x50 studs park (grass, cobblestone
  paths and plaza, fountain, four trees with flowers, street lamps, two benches, hedges plus invisible
  walls; client-side Parts) at the saved coordinates (`x, y, z`), then teleports the character to the
  plaza. The build takes a few seconds and the character is not moved until it is finished, so it never
  falls. **Sit / Stand** (button) walks to the nearest bench and sits; the benches never seat you on
  their own. If the game deletes or refreshes the park it is rebuilt at once while the farm is on;
  turning the farm off removes it. With no coordinates saved it uses the spot where it was turned on.
  No Fly needed (Fly is only a fallback if the park cannot be built).
- **Visual Emotes** (premium, `Games/Evade/VisualEmotes.lua`, `EmotePreview.lua`, `VisualEmotesUI.lua`): swaps how two
  emotes look and play, on your screen only. The logic is the one from the Visual-Emotes repo: the contents
  of each emote are cached, then exchanged between a **Base Emote** and a **Target Emote**; after a swap the
  button turns into **Revert** when the same pair is picked again, and **Revert All** restores everything.
  The emote list comes from the game's own item Registry (category "Emotes", with a built-in path list as a
  fallback). Each side is a category dropdown (the game's own headers, one whole list per header, never split in pages) plus a grid of
  pictures. Evade has no emote images: its menu tiles are ViewportFrames, so `EmotePreview` rebuilds the same thing
  itself (the game's own rig from `Assets.Items`, the emote's animation frozen at 0.5 s, its prop model attached;
  it never `require`s the game's service modules, which can hang from an executor) and hands a still model to
  Mugiwara UI's grid (`Viewport` items). Viewports are expensive (each one redraws its model every frame), so:
  - the **pose** of every animation is computed once by really playing it in a hidden frame and saved to
    `MugiwaraHub/EmotePoses.json` (keyed by animation id, so swapped emotes use their partner's pose); from then on a
    model is built from the stored joint data instantly, with no animation and no waiting;
  - opening the section starts a one-time background collection of the poses of all emotes (slow and gentle, 3 hidden
    hosts at most); later sessions skip it;
  - the baked models are still and stripped (no joints, attachments, particles, trails, beams, lights, scripts);
  - only the **open** grid holds viewports (one viewport per tile of the chosen category, so a very big category costs more while its grid is open); a closed grid shows plain icons.

  A swapped emote is rebuilt so its picture follows the swap. The Base list hides the Target and vice versa;
  Rockin Stride <> Kickback and Zombie Stride <> Classic Dance can only be swapped with each other (whatever the
  category); an emote that is already swapped must be reverted before it can be swapped again. Everything is
  restored when the hub is unloaded.
- **Visual Carry** (free, `Games/Evade/VisualCarry.lua` + `VisualCarryUI.lua`): the same swap as Visual Emotes, for carry
  animations. Carries are the modules in the folders named `CarryAnimations` (spread over BaseItems and many
  ItemPacks, also in sub-folders such as DailyShop / Battlepass); their contents (the `Carry` and `Carried`
  animations, the `Classic` R6 folder, the `Character` prop model) are exchanged between a **Base Carry** and a
  **Target Carry**, with **Swap / Revert** and **Revert All**. The list comes from the game's Registry (category
  `CarryAnimations`, with a folder scan as fallback) and is grouped by the game's own headers. Like Visual Emotes it
  is a category dropdown plus a picture grid with still previews, built by the same code
  (`Games/Evade/VisualGridUI.lua`, `EmotePreview.lua`, `VisualSwap.lua`). A carry preview follows the game's
  `CarryPair`: two mannequins (carrier and carried) are placed where the carry's `Character` model puts them, posed
  by the `Carry` / `Carried` animations, with the `CarryModel` props attached. Poses are cached in
  `MugiwaraHub/EmotePoses.json` too. Everything is restored when the hub is unloaded.
- **Visual Unusual** (premium, `Games/Evade/VisualUnusual.lua` + `VisualUnusualUI.lua`): wears the game's Unusual effects
  (particles, beams, lights, parts and welds) on your own character, on your screen only. Unlike emotes and carries
  nothing is swapped: effects are **added**, any number can be stacked, and each can be taken off again. Selecting an
  effect in the grid applies it at once and selecting it again removes it; **Remove All** clears everything and a status
  line lists what is applied. How it works (copied from the game's `RigService.AddCosmetics`):
  - an Unusual is a cosmetic module with `CosmeticInfo.Unusual = true` (about 240, spread over many ItemPacks and
    BaseItems; the list comes from the Registry category "Cosmetics", with a scan of `Items` as fallback; the RELICS
    auras, which hang on a boombox, are left out);
  - its contents are two models, `Character` (R15) and `CharacterClassic` (R6), whose parts stand in for body parts
    (Head, UpperTorso, LeftFoot, HumanoidRootPart...). One Unusual can be a single effect on the head or a package spread
    over head, arms and legs: whatever sits on a stand-in is moved onto the body part of the same name, welds
    are re-pointed at the real parts, and added parts are made massless, non-colliding and unanchored;
  - every Unusual is first copied into memory (`Capture`, in the background after the section is built) and applied from
    that copy, so the game's own folders are never touched;
  - the visible character is the rig in `Workspace.Rigs[YourName]`, not `Player.Character`; the parts meant for
    `HumanoidRootPart` go on the character's root (the rig has none). When the game rebuilds the rig (new round, avatar
    change) the applied effects are put back within half a second. The grid shows each effect's icon from the game
    (no viewports, so it is cheap), one list per game header, never split in pages.
  Everything is removed when the hub is unloaded.
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
