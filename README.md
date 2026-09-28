# +1 Loot for Anime

A Roblox (Luau) anime dungeon crawler built on the *+1 Loot To Forge* loop.

**The core loop**
- **The Dungeon:** endless floors across 8 anime zones, with a boss every 5 floors.
  - Enemies spawn only when you walk into a room.
  - Dying or going home restarts the run, but checkpoints (every 25 floors) let you skip ahead.
- **The Soul Forge:** turn 22 ores into weapons across 16 weapon classes. Ore effects carry over, and secret recipes forge iconic weapons. New weapons auto-equip.

**Progression**
- **Skill Mastery** for each weapon type.
- Exponential Rebirths and Ascensions.
- Armor drops, the Boss Rush and leaderboards.
- An admin panel.

**Look and feel**
- Chibi anime-figure enemies, 72 of them, built by code.
- Procedural combat animations.
- Arena-style swords with swing trails.
- A compact UI in Fredoka One, with tiny pop-ups.
- A quieter, compressed sound mix.

**Getting started**
- **Play right away:** open `build/PlusOneLootForAnime.rbxlx` in Roblox Studio.
- **Copy and paste into your own place:** all scripts are in `src/`. [SETUP.md](SETUP.md) shows where each one goes, plus controls, admin setup and config.
- **Rojo users:** `rojo build default.project.json -o game.rbxlx` or `rojo serve`.
