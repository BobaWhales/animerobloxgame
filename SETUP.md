# +1 Loot for Anime: Setup Guide

A Roblox Luau game based on the *+1 Loot to Forge* loop: slay monsters, loot ore, forge it into a stronger blade, push deeper, roll your Race.

The whole map (hub, train area, portals, dungeons and tower) is built by code when the server starts, so there are no models to import. There is **no VIP zone and no PvP arena**.

---

## Option A: open the ready-made place (easiest)

1. Download `build/PlusOneLootForAnime.rbxlx`.
2. Double-click it (or in Studio: **File → Open from File**).
3. Do the **UIPackPlus** step below, then press **Play**.

## Option B: copy and paste into your own place

Create these objects in Studio **with these exact names and types**, then paste each file's contents into the matching script.

> Before pasting, **delete your old map, VIP room and PvP arena** from Workspace, plus any old game scripts. The new map is built in code.

```
ReplicatedStorage
└── GameShared                (Folder)
    ├── Config                (ModuleScript)  <- src/ReplicatedStorage/GameShared/Config.luau
    ├── Format                (ModuleScript)  <- .../Format.luau
    ├── SFX                   (ModuleScript)  <- .../SFX.luau
    ├── UITheme               (ModuleScript)  <- .../UITheme.luau
    └── VFX                   (ModuleScript)  <- .../VFX.luau

ServerScriptService
└── Server                    (Script)        <- src/ServerScriptService/Server/init.server.luau
    ├── Actions               (ModuleScript)  <- .../Actions.luau
    ├── Combat                (ModuleScript)
    ├── Cosmetics             (ModuleScript)
    ├── DataService           (ModuleScript)
    ├── EnemyService          (ModuleScript)
    ├── Loot                  (ModuleScript)
    ├── MapBuilder            (ModuleScript)
    ├── Monetization          (ModuleScript)
    ├── Net                   (ModuleScript)
    ├── Stats                 (ModuleScript)
    ├── Sword                 (ModuleScript)
    ├── TowerService          (ModuleScript)
    └── Util                  (ModuleScript)

StarterPlayer
└── StarterPlayerScripts
    └── Client                (LocalScript)   <- src/StarterPlayer/StarterPlayerScripts/Client/init.client.luau
        ├── Drops             (ModuleScript)  <- .../Drops.luau
        └── UI                (ModuleScript)  <- .../UI.luau
```

The ModuleScripts under `Server` go **inside** the `Server` Script, and `Drops` and `UI` go **inside** the `Client` LocalScript.

Each file's first lines also say where it goes.

---

## Using UIPackPlus for the UI

1. Drag `UIPackPlus.rbxm` into the Studio viewport. It gets inserted into Workspace.
2. Move the inserted object into **ReplicatedStorage** and rename it **`UIPackPlus`**.
3. Press Play and open the **Output** window. It prints a line like this:
   `[UITheme] UIPackPlus found with 42 images: BlueButton, Close, Coin, Frame, ...`
4. Every panel, button, stat bar and icon is skinned automatically by matching image names (Panel/Frame/Window, GreenButton/Button, Close, Coin, Sword, Gem, and so on).
   If a role picks the wrong image, open `GameShared/UITheme` and put the exact image name **first** in that role's list inside `UITheme.Templates`. For example:
   ```lua
   Button = { "MyGreenBtn", "GreenButton", "Button" },
   Icon_Coins = { "CoinIcon", "Coin" },
   ```
If the pack isn't found, a built-in anime style is used, so the game still works.

---

## Things to fill in

All of these live in **`GameShared/Config`**.

| What | Where |
|---|---|
| Gamepass IDs | `Config.GamePasses.*.Id` (0 = not set up; the Shop shows a notice) |
| Developer product IDs | `Config.Products.*.Id` |
| Codes | `Config.Codes` (RELEASE, PLUSONE, ANIMEFORGE, MAINCHARACTER included) |
| Music (optional) | `Config.Music` (paste audio IDs from the Creator Store) |
| Replace any sound effect | `Config.SoundOverrides` (for example `Swing = "rbxassetid://123"`) |
| Test every gamepass in Studio | `Config.StudioOwnsAllPasses = true` |

**Saving:** to test DataStores in Studio, turn on *Game Settings → Security → Enable Studio Access to API Services*. Without it the game still runs, but progress isn't saved.

---

## What's in the game

**Map (laid out like +1 Loot To Forge)**
- **Hub / spawn plaza:** Forge cauldron in the centre, Sell stall, Upgrades stall, Rebirth statue (a giant sword in stone), Race Altar, Ore Index board and a global Top Blades leaderboard. Cherry trees, lanterns, torii gates and a spinning Rift in the sky.
- **Train Area (west):** 7 multiplier pads (x1 → x1500). Each swing trains Power, and standing on a pad auto-trains.
- **Dungeon portals (north):** Verdant Academy Ruins (stages 1-5) and Neon Mecha Docks (stages 6-10, needs Blade +100). Sakura Underworld, Starlit Battlefront and The Rift Throne are teased as *Coming Soon*.
- **Dungeons:** linear halls with a Power gate per stage and a boss on stages 5 and 10.
- **Infinite Tower (east):** a private arena where you must beat the floor Guardian before a 30-second timer runs out. Rewards are Coins, ore and Runes (+2% damage each).

**Systems**
- **Ore → Forge → +Blade:** 7 ores from Common to Rift-forged. Rare ores forge in big chunks (+25, +100, +1000). The blade model upgrades at 10 visual tiers, and its "+N" level is etched on the blade.
- **Races:** Pirate 32%, Ninja 27%, Assassin 18%, Sorcerer 12%, Isekai 7%, Saiyan 3.9% and Main Character 0.1%. Each has a working passive (crit, first-strike, AoE every 5th swing, Zenkai, Plot Armor, and so on) plus a 5-tier skin roll.
- **Overdrive:** a transformation buff (+100% damage, +30% speed, +50% Power) with a full transformation sequence.
- **Other systems:** Backpack / Luck / Training upgrades, Rebirth (Ascension auras), Ore Index rewards, golden Elite spawns and boss ground-slams with telegraphs.
- **Monetization:** gamepasses, developer products with receipt de-duplication, and codes.

**VFX:** curved slash arcs, sword trails, hit sparks and crit bursts, pop-up damage numbers, white hit-flash on enemies, shattering death bursts, shockwave rings, light pillars, impact frames, speed lines, camera shake, FOV punch, anime title cards, loot beams on rare drops, and ore and coin icons that fly into the HUD.

**SFX:** about 40 layered sound cues (slash, hit, crit, kill, boss kill, ore pickup by rarity, forge, tier-up, sell, rebirth, race roll ticks and reveal, Overdrive "power chord", boss slam, tower win and lose, and UI sounds). They use sounds built into Roblox, so nothing needs uploading. Classic sword sounds fall back automatically if they're unavailable.

---

## Controls
- **Click / tap**: swing your blade (trains Power and hits enemies).
- **E** at the Forge cauldron: smelt all your ore into Blade levels.
- **E** at the other stalls: Sell / Upgrades / Rebirth / Race / Index.
- Left menu: Shop, Upgrade, Race, Index, Bag, Travel, Rebirth, Settings.
- Right side: **HUB** (free teleport home) and **OVERDRIVE**.
