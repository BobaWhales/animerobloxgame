# +1 Loot for Anime

A Roblox (Luau) anime simulator built on the *+1 Loot to Forge* loop. The main pieces:
- **The Path:** fight down 30 stages. KO enemies to open each gate, and a boss guards every 5th stage.
- **The Soul Forge:** loot 22 ores and forge them into 16 weapon classes. Each ore stamps its effect on the weapon, and secret 3-ore recipes forge iconic weapons.
- **Armor:** rare drops that you wear visibly.
- **Prestige:** exponential Rebirths and Ascensions, with training pads gated behind them.
- **Boss Rush:** fight bosses back to back.
- **Leaderboards** at spawn.
- **Admin panel:** server events like 2x Luck or Coin Rain, plus give-anything tools.

It also has catalog-avatar enemies, an editable VFX library (`ReplicatedStorage.VFX`), a simulator-style HUD with a HOME button, and a holographic world map with fog of war.

- **Play right away:** open `build/PlusOneLootForAnime.rbxlx` in Roblox Studio.
- **Copy and paste into your own place:** all scripts are in `src/`. [SETUP.md](SETUP.md) shows where each one goes, plus controls, admin setup and config.
- **UI (optional):** put `UIPackPlus` in ReplicatedStorage and it skins the UI.

Rojo users: `rojo build default.project.json -o game.rbxlx` or `rojo serve`.
