# +1 Loot for Anime: Setup Guide

A Roblox Luau anime action game: slay anime-avatar enemies, loot ore and weapons, forge, roll gacha chests, and fight with iconic anime weapons. The map, enemies and weapons are all built by code, so there are no models to import. There is **no VIP zone and no PvP arena**.

---

## Option A: open the ready-made place (easiest)

1. Download `build/PlusOneLootForAnime.rbxlx` and open it in Studio (**File → Open from File**).
2. It already has **Lighting.Technology = Future**, the **2022 PBR materials** and **Shift Lock off** (Shift is sprint).
3. Do the **UIPackPlus** step below, then press **Play**.

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
    ├── Format              (ModuleScript)
    ├── SFX                 (ModuleScript)
    ├── UITheme             (ModuleScript)
    ├── VFX                 (ModuleScript)
    └── WeaponModels        (ModuleScript)

ServerScriptService
└── Server                  (Script)       <- init.server.luau
    ├── Actions  Combat  Cosmetics  DataService  EnemyService
    ├── Loot  MapBuilder  Monetization  Net  Playtime  Projectiles
    └── Stats  TowerService  Util  Weapons          (all ModuleScripts)

StarterPlayer
└── StarterPlayerScripts
    └── Client              (LocalScript)  <- init.client.luau
        ├── Abilities  CameraDirector  Drops  EnemyFX  Hud  Movement
        └── PromptUI  UI  WeaponUI  WorldMap  WorldText      (all ModuleScripts)
```

**Three settings to set by hand when copy-pasting** (the place file already has them):
1. **Lighting → Technology = Future** (Explorer → Lighting → Properties). Scripts can't change this.
2. **MaterialService → Use2022Materials = true** (the modern PBR material set). Scripts can't change this either.
3. **StarterPlayer → EnableMouseLockOption = false**, so Left Shift sprints instead of toggling Shift Lock.

Also delete your old map, VIP room, PvP arena and old scripts first.

---

## UIPackPlus

1. Drag `UIPackPlus.rbxm` into Studio.
2. Move it into **ReplicatedStorage** and name it **`UIPackPlus`**.
3. Press Play. The Output window lists every image it found. If something picks the wrong image, put the right image's name first in its list in `GameShared/UITheme → UITheme.Templates`.

---

## Controls

| Action | Keyboard / mouse | Controller | Mobile |
|---|---|---|---|
| Basic attack / combo (hold) | **LMB** | RT | Attack button |
| Dash (short i-frames) | **Q** | B | Dash button |
| Weapon skill (hold for charge skills) | **E** | X | Skill button |
| Ultimate | **R** | Y | Ult button |
| Overdrive transformation | **C** | LB | OD button |
| Health potion | H | – | – |
| Sprint (hold) | **Left Shift** | L3 | – |
| Interact (custom prompts) | **F** | D-pad Up | Tap the prompt |
| Menu drawer | **G** | D-pad Down | ≡ button (top left) |
| World map | **M** | D-pad Right | Drawer → Map |

Prompts use **F** instead of E because E is the weapon skill. You can also tap or click the hotbar slots.

Inside the world map: drag, WASD or the left stick pans; the mouse wheel, pinch, Q/E or LB/RB zooms; B or M closes.

---

## What's in the spec, and where it lives

**1. Custom proximity prompts** (`Client/PromptUI`, `MapBuilder`, `Actions`)
- Every prompt uses `Style = Custom`, `MaxActivationDistance = 10`, and `RequiresLineOfSight` from `Config.Prompt`.
  - Line of sight is **off** by default because the forge prompt sits inside the cauldron rim.
- The client draws an AlwaysOnTop BillboardGui with a CanvasGroup that fades in on `PromptShown` and out on `PromptHidden`, using TweenService.
- The key label follows your current device (Keyboard / Controller / Touch) and updates live. Touch players tap the key.
- `Triggered` fires `Remotes.Interact`. The server checks the prompt, the distance and the action before doing anything.

**2. Graphics** (`MapBuilder.buildLighting`, `Config.Graphics`)
- Technology Future (set in the place file).
- Atmosphere: Density 0.35, Haze 2.5, tinted colors.
- Bloom: Threshold 0.75, Size 28, Intensity 0.5.
- ColorCorrection: Contrast 0.18, Saturation 0.25.
- SunRays: Intensity 0.2, Spread 0.8.
- Depth of field blurs the world whenever a menu or the shop is open.
- Shadow-casting lights at the forge, altar, statue, portals, lanterns, tower and chest shrine.
- Ambient particles: floating energy motes and falling cherry blossoms in the hub, fireflies in Zone 1, dark aura trails in Zone 2.
- Optional custom PBR `MaterialVariant`s: paste texture IDs in `Config.Graphics.MaterialVariants`.

**3. Anime weapons and combat** (`Config.Weapons / Skills / WeaponClasses`, `Combat`, `Projectiles`, `WeaponModels`)

| Weapon | Class | Tier | E skill |
|---|---|---|---|
| Starrk's Guns | Dual pistols | Mythic | **Cero Metralleta**: 26-shot cone barrage. Basic attacks fire server-raycast energy rays. |
| Zangetsu | Greatsword | Mythic | **Getsuga Tensho**: piercing crescent wave. Basic attack is a 4-hit heavy combo. |
| Rasengan | Glove | Legendary | Hold to charge an orb, then lunge. Heavy knockback, 5 damage ticks, and a ragdoll on the NPC. |
| Enma | Katana | Legendary | Hell Dragon |
| Shusui | Katana | Epic | Black Blade Rush |
| Spirit Gun | Finger pistol | Epic | Charged piercing blast |
| Dimensional Scythe | Scythe | Legendary | Dimensional Rift: a vortex that pulls enemies in |

- There are 25 weapons in total across 6 classes. Each class has its own **R** ultimate.
- **Balance nerfs** live in `Config.Balance`:
  - Every cooldown is **+25%**.
  - Stamina costs are **+30%**.
  - Dash i-frames are cut to **0.18s**.
  - Stuns are capped at **1.2s** on enemies and **0.5s** on players.
  - Crits are capped at **2.5x**.
  - All gameplay damage multipliers combined are **hard-capped at 40x**.

**4. Rarity and loot** (`Config.WeaponRarities`, `Weapons`)

| Rarity | Drop rate | Bonus |
|---|---|---|
| Common | 50% | +5% damage |
| Uncommon | 30% | +15% |
| Rare | 13% | +35%, +5% attack speed |
| Epic | 5% | +75%, particle trail |
| Legendary | 1.8% | +150%, unique passive |
| Mythic / Celestial | 0.2% | +300%, aura, signature skill |

- Rolls use `Random.new()` weighted tables on the server, for both enemy drops and gacha chests.
- Chest types: the coin **Weapon Chest**, plus **Uncommon**, **Rare+ Scroll** and **Legendary** chests that use keys.
- The chest shrine is in the hub, and the **Chests** menu works anywhere.

**5. Play-time rewards and streaks** (`Playtime`, `Hud`)
- The server counts session time every second. A small timer in the bottom-left appears shortly before each reward, and the Rewards menu shows the whole ladder.

| Session time | Reward |
|---|---|
| 5 min | 100 Coins + Health Potion |
| 15 min | Uncommon Chest Key |
| 30 min | 2x Damage for 15 minutes |
| 60 min | Rare+ Spin Scroll |
| 120 min | Exclusive Playtime Aura + Legendary Chest Key |

- The daily streak, total play time and last login day are saved in the DataStore.
- Each streak day adds +5% Coins (up to +50%) and pays out more Coins each day. Every 7th day in a row also gives a Rare+ Scroll.

**6. Anime avatar enemies** (`EnemyService`)
- Each enemy is an R15 rig built from a `HumanoidDescription`, with procedural anime hair and accessories (spiky, long or bun hair; headband, horns, mask, crown or visor).
  - Add real catalog hair, accessory, Shirt and Pants IDs in `Config.EnemyCatalog`.
  - If the R15 rig can't be built, a hand-built R6 rig is used instead.
- Animations (Idle, Walk, Run, BasicAttack, SpecialWindup, SpecialRelease) are preloaded into an `Animator`. The defaults are Roblox's own animations; swap in yours via `Config.EnemyAnims`.
- `PathfindingService` handles chasing. A state machine runs special attacks:
  1. Check the cooldown and distance.
  2. Play the wind-up animation plus a red ground telegraph (a circle for boss slams, a line for lunges).
  3. Release. Damage lands on the animation's **"Hit" keyframe or marker** (`KeyframeReached` / `GetMarkerReachedSignal`). Roblox's default animations have no "Hit" marker, so a timed fallback is used until you upload your own.
- There are no head health bars; see **Enemy redesign** below for how health is shown now.

**7. 2x Power purchases** (`Monetization`, `WeaponUI` Power panel)
- Tier *n* costs **3ⁿ Robux** (3, 9, 27, 81…) and sets your damage multiplier to **2ⁿ**.
- Create one Developer Product per tier at the matching price and paste the IDs into `Config.PowerTiers` (8 tiers, up to 6,561 Robux).
- `ProcessReceipt` checks the product against the player's next tier, then sets `PowerTier`, saves, and returns `PurchaseGranted`.
  - If a player somehow buys a higher tier, they jump to that tier.
  - If they buy a tier they already own, it's converted to Coins, so no Robux is ever lost.
- The Power multiplier is applied **after** the 40x gameplay cap.
- The shop shows the current multiplier, the next one, and the exact Robux price.

---

## Clean screen, map, enemies and atmosphere

**1. UI de-cluttering and world text** (`Client/Hud`, `Client/UI`, `Client/WorldText`, `Client/PromptUI`, `Config.Hud`, `Config.WorldText`)
- Nothing sits on screen permanently. Each HUD group fades in only when it matters, then fades out:

| Element | Shows when | Hides after |
|---|---|---|
| Slim HP + stamina bars (with a trailing damage "chip") | You take damage, heal, use stamina or a potion, or are in combat | `DamageLinger` / `StaminaLinger` (4 s / 2.5 s) |
| Compact hotbar (LMB / Q / E / R / C) | You attack, are hit, an enemy is in aggro range, or a cooldown is running | `CombatLinger` (5 s) |
| Resource pills (Power, Coins, Bag…) | That value changes; only the pills that changed appear | `ResourceLinger` (3.5 s) |
| Play-time timer | 45 s before a reward, and when one is granted | 6 s |
| Boss bar | You are near a living boss | when you leave |

- Below 30% HP the bars stay up and the screen edges get a soft pulsing red vignette.
- The old left and right button columns are gone: one small **≡** button (or **G**) opens a menu drawer. Opening it "peeks" every HUD element at once.
- **World labels** (station names, portals, pad multipliers, gates, player name tags) start at **0% opacity**. They fade in, rise slightly and scale up when you are within **10 studs (about 2.8 m)**, with a 5-stud fade band.
  - Distance is measured to the closest point of the labelled object, so big landmarks work.
  - Labels are **45% smaller**, drawn with a light drop shadow on a soft glow streak instead of heavy outlines or boxes.
  - Your own name tag never shows. Hidden labels are disabled, so they cost nothing to render.
- Prompts are now a small key cap with text on a soft glow, about 45% smaller, with no panel box.

**2. World map** (`Client/WorldMap`, M key)
- **Style:** a dark holographic grid with topographic contour rings, glowing region outlines, a slow scanline shimmer and a soft vignette.
- **Layered depth:** stars, grid, contours, terrain and two cloud layers sit at different depths, so panning gives subtle parallax. Panning has inertia.
- **Fog of war:** areas you haven't walked into yet (train grounds, portal gate, tower, each dungeon stage) sit under drifting cloud banks labelled "UNCHARTED". The clouds dissolve the moment you explore an area. Exploration is saved per player (`Explored` in the save data). Future zones stay fogged as "Coming soon".
- **Waypoints:** small colour-coded geometric symbols:
  - gold diamond = service
  - purple square = power
  - cyan ring = travel
  - outlined square = stage (grey while locked)
  - pulsing red diamond = boss
- Hover or tap a symbol and it expands into a callout with its description, lock status or distance, plus:
  - **Track:** places a small world marker with the distance, which clears when you arrive.
  - **Travel:** teleports you. The server still enforces the Fast Travel pass.
- Landmarks come from parts the server tags `POI` (see `MapBuilder.poi`), so new landmarks appear on the map automatically.

**3. Enemy redesign** (`EnemyService`, `Client/EnemyFX`, `Config.EnemyLooks`, `Config.EliteLook`, `Config.EnemyAI`)
- **Silhouettes:** each enemy type has a distinct, readable shape instead of detail noise:

| Enemy | Silhouette |
|---|---|
| Slime Delinquent | Brawler pauldrons and wrapped fists |
| Hall Monitor Oni | Great horns and a spined back |
| Club Captain Golem | Boulder shoulders and fists |
| Rooftop Ronin | Wide straw hat and scarf |
| Student Council Tyrant | Cape, collar and shoulder spikes |
| Scrap Drone | Neon halo and antenna |
| Mech-Grunt | Plated shoulders and thruster pack |
| Neon Ninja Unit | Flowing scarf tails |
| Plasma Warden | Shoulder pylons |
| Mecha Admiral Kaizer | Cape and epaulettes |

- All enemies use flat, clean materials. The face decal is replaced by **glowing eyes**, and each has a glowing **chest core**.
- **No head health bars:**
  - The core dims toward embers and flickers as HP drops.
  - A hair-thin line appears for 2 s only over enemies *you* hit.
  - Bosses get the slim top-of-screen bar.
- **Anticipation and recovery.** Every attack follows the same readable rhythm:
  1. **Anticipation:** the enemy leans back, its eyes flare white with a glint, and its core burns hot.
  2. **Strike:** it snaps forward.
  3. **Recovery:** it slumps with dim eyes and core. During recovery it takes **+25% damage** (an "EXPOSED" pop). This window is longer after special attacks.
  - Timings are in `Config.EnemyAI.Anticipation / Recovery / SpecialRecovery`.
- **Variant tiers:**
  - Stage 3+ of each zone adds armour plating.
  - Stage 4+ adds glowing runes.
  - Bosses get everything.
  - **Elites** switch to a dark-gold palette with gold eyes, core, plates and runes, a gold crest and a thin gold outline.

**4. Atmosphere, audio and camera** (`MapBuilder`, `SFX`, `VFX`, `Client/Movement`, `Client/CameraDirector`)
- **Lighting:**
  - A lower golden-hour sun gives longer shadows. There are volumetric clouds and slightly crisper shadow softness.
  - The dungeons have shadow-casting wall sconces, and lanterns and flames gently flicker.
- **Particles:** rolling ground fog around the plaza, train grounds, tower and dungeon halls; dust motes drifting in the light; lazy embers off the forge, the tower and the Neon Mecha Docks.
- **Audio:**
  - Impacts are layered (a bright transient, a body thump, a crunch and a tail). Each weapon family sounds different: blades "shing", heavy weapons thud, guns and energy fizz.
  - UI clicks are crisp "key press" ticks.
  - Roblox's looping run sound is replaced by real one-shot footsteps timed to your stride. They change with the floor (grass, stone, wood, metal, soft), nearby players get them too, and bosses stomp.
- **Camera:**
  - Heavy impacts (slams, Rasengan, crits, boss kills) add a low-frequency rumble on top of the normal shake.
  - Sprinting smoothly widens the FOV.
  - Near points of interest (the forge, altar, statue, portals, tower) and during boss fights, the camera eases toward the landmark, pulls back slightly and tightens the FOV so both you and it are framed.
  - All camera effects are removed again before Roblox's camera updates, so they never drift or fight your own camera control. Framing turns off in first person, in menus and on the map.

**Kept from before:** hub map laid out like +1 Loot To Forge, ore → Forge levels, races, Overdrive, rebirth, the Infinite Tower, the Index, codes, gamepasses, layered SFX and anime VFX.

---

## Things to fill in (`GameShared/Config`)

| What | Where |
|---|---|
| Power tier product IDs (3, 9, 27… Robux) | `Config.PowerTiers[n].Id` |
| Gamepass / other product IDs | `Config.GamePasses`, `Config.Products` |
| Enemy catalog hair / clothes (optional) | `Config.EnemyCatalog` |
| Custom enemy / player animations (optional) | `Config.EnemyAnims`, `Config.PlayerAnims` |
| PBR texture maps (optional) | `Config.Graphics.MaterialVariants` |
| Music (optional) | `Config.Music` |
| Rename weapons | `Config.Weapons` (`Name` field) |
| World-text fade distance / size | `Config.WorldText` |
| How long HUD pop-ups stay | `Config.Hud` |
| Sprint speed / FOV, camera framing strength | `Config.Sprint`, `Config.Camera` |
| Enemy silhouettes / glow colours | `Config.EnemyLooks` (`Silhouette`, `Core`), `Config.EliteLook` |

**Saving in Studio:** turn on *Game Settings → Security → Enable Studio Access to API Services*.

**Heads-up on names:** Zangetsu, Starrk, Getsuga Tensho, Cero Metralleta, Rasengan, Enma, Shusui and Spirit Gun belong to existing anime (Bleach, Naruto, One Piece, Yu Yu Hakusho). Plenty of Roblox games use names like these, but they can draw takedown requests. Every name is one field in `Config.Weapons` / `Config.Skills` if you ever need to rename them.
