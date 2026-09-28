# +1 Loot for Anime: Setup Guide

A Roblox Luau anime simulator in the style of +1 Loot To Forge:
- Fight down a 30-stage **Path**, loot ore, and forge it into weapons whose ore effects carry over.
- Grow your Power exponentially with Rebirths and Ascensions.
- Take on the **Boss Rush**, and climb the leaderboards.

The map, enemies, weapons, armor and VFX are all built by code, so there are no models to import.

---

## Option A: open the ready-made place (easiest)

1. Download `build/PlusOneLootForAnime.rbxlx` and open it in Studio (**File → Open from File**).
2. It already has **Lighting.Technology = Future**, the **2022 PBR materials** and **Shift Lock off** (Shift is sprint).
3. Do the **UIPackPlus** step below (optional), then press **Play**.

To move everything into your own place, open both places and copy these three objects across in the Explorer (right-click → Copy, then right-click the service → Paste Into):
- `GameShared` → ReplicatedStorage
- `Server` → ServerScriptService
- `Client` → StarterPlayerScripts

## Option B: copy and paste file by file

Create these objects with **these exact names and types**, then paste each file's contents in. Each file's first lines also say where it goes.

```
ReplicatedStorage
└── GameShared              (Folder)
    ├── Config              (ModuleScript)
    ├── ForgeRules          (ModuleScript)   NEW
    ├── Format              (ModuleScript)
    ├── SFX                 (ModuleScript)
    ├── UITheme             (ModuleScript)
    ├── VFX                 (ModuleScript)
    └── WeaponModels        (ModuleScript)

ServerScriptService
└── Server                  (Script)       <- init.server.luau
    ├── Actions  Admin  Combat  Cosmetics  DataService  EnemyService
    ├── Forge  Leaderboards  Loot  MapBuilder  Monetization  Net
    └── Playtime  Projectiles  Stats  TowerService  Util  Weapons   (all ModuleScripts)

StarterPlayer
└── StarterPlayerScripts
    └── Client              (LocalScript)  <- init.client.luau
        ├── Abilities  AdminUI  CameraDirector  Drops  EnemyFX  ForgeUI
        └── Hud  Movement  PromptUI  UI  WeaponUI  WorldMap  WorldText   (all ModuleScripts)
```

`Admin`, `Forge`, `Leaderboards`, `ForgeRules`, `ForgeUI` and `AdminUI` are new in this version.

The `ReplicatedStorage.VFX` folder is **created by the server** the first time it runs (see **VFX hierarchy** below), so you don't make it by hand.

**Three settings to set by hand when copy-pasting** (the place file already has them):
1. **Lighting → Technology = Future**
2. **MaterialService → Use2022Materials = true**
3. **StarterPlayer → EnableMouseLockOption = false** (Left Shift sprints)

This version uses a new save key (`PlusOneLootAnime_v2`), so everyone starts fresh on the new progression.

---

## UIPackPlus (optional)

1. Drag `UIPackPlus.rbxm` into Studio.
2. Move it into **ReplicatedStorage** and name it **`UIPackPlus`**.
3. Press Play. The Output window lists every image it found.
   - If something picks the wrong image, put the right image's name first in its list in `GameShared/UITheme → UITheme.Templates`.

Without the pack, the built-in "ink & neon" style is used: dark panels, slanted accent tabs, and chunky simulator buttons with a lip.

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
| Interact / **pick up ore** | **F** | D-pad Up | Tap the prompt |
| Menu drawer | **G** | D-pad Down | ≡ button (top left) |
| World map | **M** | D-pad Right | Drawer → Map |
| Home (back to spawn, also leaves the Boss Rush) | **B** | – | **HOME** button (top centre) |
| Admin panel (admins only) | **P** | – | Drawer → Admin |

---

## What changed (all 22 requests)

**1. VFX hierarchy** (`GameShared/VFX`: `VFX.BuildLibrary`, `VFX.Categories`)
- On start the server builds an editable library:
  ```
  ReplicatedStorage.VFX
    Combat   (Sparks, Stars, Glow, Core, Shock, Shards)
    Elements (Fire, Embers, Smoke, Frost, Lightning, Poison, Void, Holy, Wind, Blood)
    Auras    (Aura, Vortex, Rise)
    Ambient  (Fog, Dust, FloatEmbers, Petals)
  ```
- Each entry is a `ParticleEmitter` template. Every effect in the game clones it and re-tints it at runtime.
- To restyle an effect, edit its emitter (texture, size, speed…) or drop in your own emitter with the same name. The server only creates templates that are missing, so your edits are kept.
- The `Tint` attribute controls recolouring:
  - `Gradient`: keeps the colour ramp.
  - `Solid`: one colour.
  - `None`: never re-tinted.
- A `README` StringValue in the folder explains the same thing inside Studio.

**2. "G for menus" hint** (`Client/UI`)
- Small text next to the ≡ button at the top left.
- It hides while the drawer or any menu is open.

**3. The map is revamped** (`Server/MapBuilder`, `Config.World`)
- Compact spawn plaza. It has:
  - the **Soul Forge** in the middle
  - the Merchant (sell) and Upgrades stalls
  - the Race Altar
  - the Sword of Ascension (Rebirth / Ascend)
  - the Ore Index board
  - four leaderboard boards
- **Training Grounds** island to the west.
- **Boss Rush** island to the east.
- **The Path** heads north through a torii gate.
- The world map (`Client/WorldMap`) was re-laid-out to match. The Path is drawn compressed, with zone names, a stage number per room and a route line.

**4. Admin panel** (`Server/Admin`, `Client/AdminUI`)
- Open it with **P** or the **Admin** tile in the drawer.
- **Player tab:** + Coins / Power / Rebirths / Ascensions / Rerolls / Overdrive / Catalysts / every ore, unlock stages, heal, god mode, speed x3, go to, bring, and reset data (click twice).
  - Target yourself, **Everyone**, or any player.
  - The amount box takes numbers like `5000`, `2.5m`, `3qd` or `1e40`.
- **Items tab:** give any ore; any weapon (pick a rarity and a maxed ore effect); any armor.
- **Server tab ("admin abuse"):**
  - **2x Luck, 3x Coins, 5x Power, 2x Ore Drops** events. The amount sets the duration in minutes. Active events show as timed chips at the top of everyone's screen.
  - **Ore Rain**, **Coin Rain**, **Boss Invasion** at spawn (rewards everyone who helps), **Everyone Overdrive**, **Kill All Enemies**.
  - **Announcements**, filtered through TextService.
- Every command is checked again on the server and rate-limited.
- **Who is an admin** (`Config.Admins`):
  - the place owner (or rank 255 in the owning group)
  - anyone in Studio
  - `UserIds = { ... }`
  - `GroupId` + `MinRank`

**5. Fighting is a Path, not portals** (`Config.Stages`, `EnemyService`, `MapBuilder.buildPath`)
- 30 stages in a row across 6 zones:
  1. Verdant Academy Ruins
  2. Neon Mecha Docks
  3. Sakura Underworld
  4. Starlit Battlefront
  5. Frostfang Peaks
  6. The Rift Throne
- **KO 8 enemies to clear a stage.** The force-field gate to the next stage then opens for you.
  - The gate label shows your live count ("CLEAR STAGE 3  5/8").
  - A tracker under HOME shows the stage you're standing in and its progress.
- **Every 5th stage is a boss arena.** Defeat the boss to move on.
- Stages only spawn enemies while a player is near, so 30 stages stay cheap to run.
- The Fast Travel pass jumps you straight to any stage you've unlocked.

**6. Armor, a rarer drop** (`Config.Armors`, `Weapons.AddArmor`, `WeaponModels.AttachArmor`, `WeaponUI` Armor panel)
- Drop chance by source: normal enemies 0.4%, elites 4%, bosses 12%, Boss Rush 8%.
- Eight sets, each with a bonus stat, and each worn visibly on your character with a glow by rarity:

| Set | Bonus stat |
|---|---|
| Training Gi | Speed |
| Shinobi Vest | Dodge |
| Samurai O-Yoroi | Extra defense |
| Mecha Frame | Stamina |
| Oni Hide | Thorns |
| Shinigami Robe | Lifesteal |
| Saiyan Battle Armor | Power gain |
| Celestial Aegis | Luck |

- Defense by rarity: 5% / 9% / 14% / 20% / 28% / 38%, capped at 75% total.

**7. More unique fonts** (`Config.Fonts`)
- **Bangers**: titles, numbers and buttons (manga sound-effect look).
- **Sarpanch**: labels and key caps.
- **Oswald**: body text.
- Change all three in one place.

**8. A little darker** (`Config.Graphics`)
- Later dusk sun, lower exposure and ambient light, heavier haze and a slightly darker colour grade.

**9. Leaderboards** (`Server/Leaderboards`, `Config.Leaderboards`)
- Four boards at spawn: **Top Power**, **Furthest Stage**, **Top Rebirths** (ranked by ascensions first, then rebirths) and **Top Slayers**.
- They use OrderedDataStores, refreshed every 60 s. Power is stored as a log so it never overflows.
- Without API access, the boards show the players in the current server.
- The player list shows Power / Stage / Rebirths.

**10. Boss Rush replaces the Infinity Tower** (`TowerService`, `Config.BossRush`)
- Unlocks after clearing stage 5. Enter at the island gate.
- Wave after wave of Path bosses, 45 s per boss:
  - Every 5th wave sends **two bosses**.
  - Every 10th wave pays a catalyst.
- Each boss gives Coins, Runes (permanent +2% damage each), ore and a chance at armor.
- **HOME** leaves the run.

**11. Training pads are gated by Rebirths / Ascensions** (`Config.TrainPads`)

| Pad | x1 | x3 | x10 | x40 | x150 | x1,000 | x8,000 | x75,000 | x1,000,000 |
|---|---|---|---|---|---|---|---|---|---|
| Needs | – | 1 Rebirth | 3 Rebirths | 6 Rebirths | 10 Rebirths | 1 Ascension | 2 Ascensions | 4 Ascensions | 7 Ascensions |

**12. More Roblox-simulator style** (`Client/UI`)
- Always-visible currency stack on the left: Power, Coins, Ore Bag and Rebirths.
  - The Rebirths chip shows "% to rebirth" and "REBIRTH READY!".
  - Click a chip to open its menu.
- Forge level and Damage chips pop in when they change.
- Chunky buttons, big number pops, and coins that fly into the HUD.

**13. More exponential** (`Config.PathCurve`, `Config.Rebirth`, `Config.Ascension`)
- Stage HP grows ×1.9 per stage and Coins ×1.75 per stage. Stage 30's boss has about 109B HP.
- Each **Rebirth** multiplies Power gain by ×1.65 and Coins by ×1.3. Both compound.
  - It costs 1K Power at first, ×3.2 per rebirth.
- Each **Ascension** multiplies Power by ×8 and Coins by ×4, and gives rerolls and a Legendary Catalyst.
  - It needs 10 Rebirths, then +5 per ascension.
  - It resets rebirths and makes future rebirths ×25 pricier.
- Numbers abbreviate all the way to 10^93, then switch to scientific notation.

**14. Consistent, unique UI** (`GameShared/UITheme`, `UI.MakePanel`)
- Every menu uses one template:
  - a dark ink panel
  - a slanted accent tab with the title
  - a thin accent rule
  - a square close button
- Rows use the same dark style with a coloured rarity or accent bar on the left.

**15. Infinite upgrade levels** (`Config.UpgradeCost`)
- There's no max level. Price = `Base + Step × level` up to level 50, then that price × `Growth^(level − 50)`.

| Upgrade | Growth after level 50 |
|---|---|
| Ore Bag | ×1.12 per level |
| Luck | ×1.13 per level |
| Training | ×1.14 per level |

**16. The ore bag starts at 3 ores** (`Config.BaseBackpack`)
- Each Ore Bag level adds +1 slot.

**17. Interact to pick up ore** (`Client/Drops`)
- Dropped ore shows an **F – Pick up** prompt. One press grabs every ore within reach.
- The Auto-Collect gamepass still skips the prompt. The Auto-Forge pass became **Auto-Sell**.

**18. Catalog avatar enemies** (`EnemyService.catalogDescription`, `Config.EnemyAvatars`)
- Each stage's enemy is built from the **Avatar Editor catalog**. The server searches `AvatarEditorService:SearchCatalogAsync` with themed keywords (hair, hat, shirt, pants per stage), builds a `HumanoidDescription`, and spawns it with `Players:CreateHumanoidModelFromDescriptionAsync`.
- Results are cached.
- You can pin exact items per stage in `Config.EnemyCatalogOverrides`, or copy a real avatar with `Config.EnemyAvatarUserIds[stage] = userId`.
- If the catalog can't be reached (for example Studio without API access), the procedural anime look is used instead.

**19. Forging replaces weapon chests** (`Server/Forge`, `GameShared/ForgeRules`, `Client/ForgeUI`)
- At the **Soul Forge** (or drawer → Forge while standing near it), put 1–3 ores in the crucible and, optionally, a catalyst. A coin fee applies.
- The preview uses the same maths as the server. It shows:
  - the ore effects the weapon will get
  - the weapon-type odds
  - the minimum rarity
  - the fee
  - Forge levels gained. The old "+1 Forge" progression lives on: forging raises your Forge level.
- **17 unique recipes** forge iconic weapons from exact 3-ore mixes. Examples:

| Weapon | Ores |
|---|---|
| Rasengan | Chakra Copper + Gale Opal + Ki Crystal |
| Zangetsu | Void Mythril + Sun Iron ×2 |
| Raijin Kunai | Storm Quartz ×2 + Echo Glass |

- Undiscovered recipes show a hint in the **Recipes** tab. The first discovery is announced to the server.
- Catalysts (Uncommon / Rare+ / Legendary) set a minimum rarity. They come from play-time rewards, bosses, the Boss Rush and ascending.

**20. Ores apply effects to weapons** (`Config.Effects`, `Combat.hit`)
- 21 effects, each stamped on the weapon by its ore. Duplicate ores stack.

| Group | Effects |
|---|---|
| Damage and procs | Heavy, Burn, Frost (slow + bonus damage), Shock (chain lightning), Poison, Bleed (on crits), Pierce, Echo (double hit), Crit, Radiant (splash), Void (execute) |
| Speed, cost and sustain | Haste, Ki Flow (cheaper skills), Chrono (shorter cooldowns), Lifesteal |
| Push | Gale (knockback) |
| Economy | Fortune (coins), Greed (luck) |
| Scaling and kill rewards | Titan (bonus damage vs bosses), Soul (Power per kill), Holy (heal on kill) |

- Each effect has a per-point value and a cap.
- Weapons show their effects as coloured dots, list them in the detail pane, and glow with the strongest effect's particles.
- The Index lists every ore's effect.

**21. More ores and weapon types**
- **22 ores** (from 7): 3 Common, 4 Uncommon, 4 Rare, 4 Epic, 3 Legendary, 2 Mythic and 2 Rift-forged.
- **16 weapon classes** (from 6). New: Spear, Daggers, Hammer, Bow, Staff, Chain, Claws, Fan, Kunai and Hand Cannon.
  - Each has its own model, attack style (multi-shot, explosive, knockback, reach), skills and an ultimate.
- **65 weapons.**
- Which class you forge depends on the ore effects (for example, Burn leans Katana/Staff, Frost leans Spear/Bow).

**22. Less clutter, plus a HOME button**
- The map keeps only the stations you use, with fewer props.
- A **HOME** button sits at the top centre (key **B**) and teleports you to spawn from anywhere. In the Boss Rush it also ends the run.

---

## Things to fill in (`GameShared/Config`)

| What | Where |
|---|---|
| Admins (besides you, the owner) | `Config.Admins.UserIds`, `GroupId`, `MinRank` |
| Event multipliers / durations | `Config.Events` |
| Power tier product IDs (3, 9, 27… Robux) | `Config.PowerTiers[n].Id` |
| Gamepass / other product IDs | `Config.GamePasses`, `Config.Products` |
| Enemy catalog keywords / exact items / avatar user IDs | `Config.EnemyAvatars`, `Config.EnemyCatalogOverrides`, `Config.EnemyAvatarUserIds` |
| Forge recipes | `Config.Recipes` |
| Ores and their effects | `Config.Ores`, `Config.Effects` |
| Stage curve (HP, coins, kills to clear) | `Config.PathCurve` |
| Rebirth / Ascension maths | `Config.Rebirth`, `Config.Ascension` |
| Upgrade prices | `Config.Upgrades`, `Config.UpgradeLinearUntil` |
| Fonts | `Config.Fonts` |
| Darkness / colour grade | `Config.Graphics` |
| Music (optional) | `Config.Music` (`Hub`, `Path`, `BossRush`) |
| Custom animations (optional) | `Config.EnemyAnims`, `Config.PlayerAnims` |

**Saving and leaderboards in Studio:** turn on *Game Settings → Security → Enable Studio Access to API Services*. The catalog enemies need this too.

**Heads-up on names:** Zangetsu, Starrk, Getsuga Tensho, Cero, Rasengan, Enma, Shusui, Spirit Gun and similar names belong to existing anime. Plenty of Roblox games use names like these, but they can draw takedown requests. Every name is one field in `Config.Weapons` / `Config.Skills` if you ever need to rename them.
