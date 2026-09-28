# +1 Loot for Anime: Setup Guide

A Roblox Luau anime action game: slay anime-avatar enemies, loot ore and weapons, forge, roll gacha chests, and fight with iconic anime weapons. The map, enemies and weapons are all built by code, so there are no models to import. There is **no VIP zone and no PvP arena**.

---

## Option A: open the ready-made place (easiest)

1. Download `build/PlusOneLootForAnime.rbxlx` and open it in Studio (**File → Open from File**).
2. It already has **Lighting.Technology = Future** and the **2022 PBR materials** turned on.
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
        └── Abilities  Drops  Hud  PromptUI  UI  WeaponUI   (all ModuleScripts)
```

**Two settings scripts can't change.** Roblox locks these, so set them by hand when copy-pasting:
1. **Lighting → Technology = Future** (Explorer → Lighting → Properties).
2. **MaterialService → Use2022Materials = true** (the modern PBR material set).

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
| Interact (custom prompts) | **F** | D-pad Up | Tap the prompt |

Prompts use **F** instead of E because E is the weapon skill. You can also tap or click the hotbar slots.

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
- The server counts session time every second. A timer widget in the bottom-left shows progress to the next reward.

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
- Health bars sit over the head and only show when an enemy was recently damaged or a player is in aggro range.

**7. 2x Power purchases** (`Monetization`, `WeaponUI` Power panel)
- Tier *n* costs **3ⁿ Robux** (3, 9, 27, 81…) and sets your damage multiplier to **2ⁿ**.
- Create one Developer Product per tier at the matching price and paste the IDs into `Config.PowerTiers` (8 tiers, up to 6,561 Robux).
- `ProcessReceipt` checks the product against the player's next tier, then sets `PowerTier`, saves, and returns `PurchaseGranted`.
  - If a player somehow buys a higher tier, they jump to that tier.
  - If they buy a tier they already own, it's converted to Coins, so no Robux is ever lost.
- The Power multiplier is applied **after** the 40x gameplay cap.
- The shop shows the current multiplier, the next one, and the exact Robux price.

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

**Saving in Studio:** turn on *Game Settings → Security → Enable Studio Access to API Services*.

**Heads-up on names:** Zangetsu, Starrk, Getsuga Tensho, Cero Metralleta, Rasengan, Enma, Shusui and Spirit Gun belong to existing anime (Bleach, Naruto, One Piece, Yu Yu Hakusho). Plenty of Roblox games use names like these, but they can draw takedown requests. Every name is one field in `Config.Weapons` / `Config.Skills` if you ever need to rename them.
