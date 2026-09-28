# +1 Loot for Anime: Setup Guide

A Roblox Luau anime dungeon crawler in the style of +1 Loot To Forge:
- Run an endless **Dungeon** floor by floor, with a boss every 5 floors.
- Dying or going home starts the run over, but checkpoints let you skip ahead.
- Loot ore and forge it into weapons whose ore effects carry over.
- Grow exponentially with Rebirths and Ascensions, and level up your **Skill Mastery**.

The lobby, the dungeon, the chibi anime enemies, the weapons, armor, animations and VFX are all built by code. There are no models or animations to import.

---

## Option A: open the ready-made place (easiest)

1. Download `build/PlusOneLootForAnime.rbxlx` and open it in Studio (**File → Open from File**).
2. It already has **Lighting.Technology = Future**, the **2022 PBR materials** and **Shift Lock off** (Shift is sprint).
3. Do the **UIPackPlus** step below (optional), then press **Play**.

To move everything into your own place, copy these three objects across in the Explorer (right-click → Copy, then right-click the service → Paste Into):
- `GameShared` → ReplicatedStorage
- `Server` → ServerScriptService
- `Client` → StarterPlayerScripts

## Option B: copy and paste file by file

Create these objects with **these exact names and types**, then paste each file's contents in. Each file's first lines also say where it goes.

```
ReplicatedStorage
└── GameShared              (Folder)
    ├── Config  ForgeRules  Format  SFX  UITheme  VFX  WeaponModels   (ModuleScripts)

ServerScriptService
└── Server                  (Script)       <- init.server.luau
    ├── Actions  Admin  Combat  Cosmetics  DataService  DungeonService
    ├── EnemyService  Forge  Leaderboards  Loot  MapBuilder  Monetization
    └── Net  Playtime  Projectiles  Stats  TowerService  Util  Weapons   (all ModuleScripts)

StarterPlayer
└── StarterPlayerScripts
    └── Client              (LocalScript)  <- init.client.luau
        ├── Abilities  AdminUI  CameraDirector  Drops  EnemyFX  ForgeUI  Hud
        └── Movement  ProcAnim  PromptUI  UI  WeaponUI  WorldMap  WorldText   (all ModuleScripts)
```

`DungeonService` (server) and `ProcAnim` (client) are new in this version.

The server creates the `ReplicatedStorage.VFX` folder the first time it runs, so you don't make it by hand.

**Three settings to set by hand when copy-pasting** (the place file already has them):
1. **Lighting → Technology = Future**
2. **MaterialService → Use2022Materials = true**
3. **StarterPlayer → EnableMouseLockOption = false** (Left Shift sprints)

Saves keep using `PlusOneLootAnime_v2`:
- Coins, weapons, armor and prestige carry over.
- Old "stage" progress becomes your **deepest floor**, so earned checkpoints unlock right away.
- Ores already in the Index stay unlocked.

---

## UIPackPlus (optional)

1. Drag `UIPackPlus.rbxm` into Studio.
2. Move it into **ReplicatedStorage** and name it **`UIPackPlus`**.
3. Press Play.
   - The Output window lists every image it found.
   - If something picks the wrong image, put the right image's name first in its list in `GameShared/UITheme → UITheme.Templates`.

---

## Controls

| Action | Keyboard / mouse | Controller | Mobile |
|---|---|---|---|
| Basic attack / combo (hold) | **LMB** | RT | Attack button |
| Dash (short i-frames) | **Q** | B | Dash button |
| Weapon skill (hold for charge skills) | **E** | X | Skill button |
| Ultimate | **R** | Y | Ult button |
| Overdrive transformation | **C** | LB | OD button |
| Health potion | **H** | – | – |
| Sprint (hold) | **Left Shift** | L3 | – |
| Interact / pick up ore (grabs everything in reach) | **F** | D-pad Up | Tap the prompt |
| Menu drawer | **G** | D-pad Down | ≡ button (top left) |
| World map | **M** | D-pad Right | Drawer → Map |
| Home (back to spawn; ends a dungeon run or Boss Rush) | **B** | – | **HOME** button (top centre) |
| Admin panel (admins only) | **P** | – | Drawer → Admin |

---

## How a run works

1. Walk north from spawn, through the torii, to **the Dungeon gate**, and press **F**.
2. Pick a start floor:
   - **Floor 1** is always available.
   - A checkpoint unlocks 25 floors after it: reach floor 50 to start at 25, floor 75 to start at 50, and so on.
   - The **Fast Travel** gamepass gives checkpoints every 10 floors instead.
3. Each player gets a **private run**, built 5 floors at a time: an entry hall, four rooms and a boss room.
4. **Enemies only spawn when you walk into a room.** Clear every enemy to open the door to the next floor.
5. Beat the boss (floors 5, 10, 15…) to reveal the **stairs down** to the next 5 floors.
6. **Dying or pressing HOME ends the run.** You're back in the lobby with a small summary card (floor reached, coins earned, where you can start next).

Floors never end:
- 8 anime zones of 25 floors each: Hidden Leaf Forest, Soul Reaper Gates, Titan Wall Ruins, Demon Moon Mountain, Cursed Academy, Grand Line Cove, Hero City Rooftops, Saiyan Wastes.
- After floor 200 the zones repeat as **Nightmare** tiers.
- Enemy HP grows ×1.22 per floor and coins ×1.17 per floor.
- A new ore joins the drop table every 5 floors.

---

## What changed in this update

1. **Enemies only spawn in range.** Rooms stay empty until you walk in (`Config.Dungeon.SpawnRange`). Enemies belong to your run and are removed when it ends.
2. **Font:** every label uses **Fredoka One** (`Config.Fonts`).
3. **+1 Loot To Forge structure:**
   - The lobby (Soul Forge in the middle, shops, altar, rebirth statue, leaderboards) sits between the Dungeon gate to the north, Training to the west and the Boss Rush to the east.
   - The fixed 30-stage Path is gone.
   - This is an original recreation of the layout and loop. No assets were copied from that game.
4. **Anime Dice-style enemies** (`EnemyService`, `Config.EnemyArchetypes`):
   - 72 original chibi anime figures: big head, big anime eyes with shine and angry brows, bold hair (spiky, long, messy, ponytail, twin tails…).
   - Each has an outfit (vest, robe, coat, armor, gi, uniform, cloak) and gear: headbands, hollow masks, horns, hoods, haori, gourds, straw and cowboy hats, blindfolds, scouters, wings, tails.
   - Each holds a weapon.
   - Every zone has 4 regular enemies and 5 bosses. Titans and bosses are scaled up.
   - These are made by code in that style, not taken from Anime Dice.
   - `Config.EnemyModelStyle = "Catalog"` still lets you dress them from the Roblox catalog instead.
5. **Skill Mastery** (`Config.Mastery`, drawer → Mastery):
   - Each weapon type levels up from E/R skill use (4/10 xp) and kills (1, elites 6, bosses 30).
   - **+3% skill damage per level** and up to −30% cooldown.
   - Milestones:

| Level | Title | Bonus |
|---|---|---|
| 10 | Adept | +15% skill range and area |
| 25 | Expert | −20% skill stamina |
| 50 | Master | −15% cooldowns |
| 100 | Grandmaster | ×1.5 skill damage and gold skill VFX |

6. **Auto-equip on craft:** a freshly forged weapon goes straight into your hands. You can turn this off in Settings.
7. **Quality of life:**
   - F picks up every ore in reach.
   - Forge: **Repeat last** and **Auto-fill** (rarest ores first).
   - Weapons: **scrap all Common** or **Common + Uncommon** in one go (click twice to confirm; recipe weapons are always kept).
   - Settings toggles: Music, SFX, Auto-equip, Screen shake, Damage numbers.
   - A floor tracker shows the floor, zone and KOs, plus an end-of-run summary.
   - The world map is a clean lobby map.
8. **Very small pop-ups:**
   - Announcements are a slim chip that replaces the previous one instead of stacking.
   - Toasts are thin one-liners.
   - Damage numbers and floating text are about half size.
   - Floor banners are compact.
9. **Better, quieter sound:**
   - Master SFX is lower (0.55), music is 0.3.
   - A bus compressor and soft high cut smooth the mix.
   - Harsh distortion and peaks are toned down.
   - Every cue is rate-limited, so bursts of hits and pickups don't pile up.
10. **Anime theme throughout:** anime-parody zones, enemies, bosses and weapons.
11. **The Ore Index is a menu button, and every ore starts locked:**
    - Locked cards hint which floor the ore drops from.
    - Picking an ore up marks it **found**.
    - Click the glowing card to **unlock** it, reveal its effect and claim the coins.
    - The spoiler board in the lobby is gone.
12. **Simpler left UI:** three compact pills (Power, Coins, Ore bag) with tiny **REBIRTH!** / **FULL** badges. Click a pill to open its menu.
13. **Dungeon runs with checkpoints:** see *How a run works* above.
14. **Animations and models:**
    - **Procedural combat animation** (`Client/ProcAnim`): keyframed swings on the R15 joints, layered over the normal walk and run.
      - Each weapon type has its own combo: Katana right-left-overhead, Spear thrust-thrust-spin, Gloves jab-cross, guns aim and recoil, and more.
      - Skills cast, ultimates raise then slam, and dashes lean.
      - Enemies swing their weapons and wind up before specials. Other players see your swings too.
    - **Swords in an arena-battler style** (inspired by Blade Ball, no assets copied):
      - Tapered wedge tips, a glowing core stripe, bright edge highlights, winged or spiked guards, gem pommels and wrapped grips.
      - Every weapon has a **SwingTrail** that flashes on each swing.
      - The slash effect is a crisp crescent with a trailing echo crescent and sparks.

---

## Systems kept from earlier versions

- **Soul Forge crafting:**
  - 22 ores, 21 ore effects, 16 weapon classes and 65 weapons.
  - 17 secret recipes.
  - Catalysts for a minimum rarity.
- **Armor:** rare drops with a visible set, defense and a bonus stat.
- **Boss Rush:** unlocks after the floor 5 boss.
- **Training pads** gated by Rebirths / Ascensions.
- **Upgrades:** infinite levels, linear price to 50 then exponential. The ore bag starts at 3.
- **Leaderboards:** Power, Deepest Floor, Rebirths and Slayers.
- **Admin panel:**
  - Give items and currency.
  - **Set Deepest Floor**.
  - Server events and "admin abuse".
- **Other:**
  - The editable **VFX hierarchy**.
  - Races, Overdrive, play-time rewards, the shop, codes and 2x Power purchases.

---

## Things to fill in (`GameShared/Config`)

| What | Where |
|---|---|
| Admins (besides you, the owner) | `Config.Admins` |
| Dungeon pacing (room size, spawn range, HP / coin growth, checkpoint spacing) | `Config.Dungeon` |
| Zones, their enemies and bosses | `Config.Zones`, `Config.EnemyArchetypes` |
| Skill mastery numbers | `Config.Mastery` |
| Fonts | `Config.Fonts` |
| Power tier / gamepass / product IDs | `Config.PowerTiers`, `Config.GamePasses`, `Config.Products` |
| Music (optional) | `Config.Music` (`Hub`, `Dungeon`, `BossRush`) |
| Your own sounds (optional) | `Config.SoundOverrides` |

**Saving and leaderboards in Studio:** turn on *Game Settings → Security → Enable Studio Access to API Services*.

**Heads-up on names:**
- The zone, enemy and weapon names are anime parodies.
- Plenty of Roblox games do this, but exact names from existing anime can draw takedown requests.
- Every name is one field in `Config` if you ever need to rename them.
