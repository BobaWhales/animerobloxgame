--!nonstrict
-- Config (ModuleScript) -> ReplicatedStorage/GameShared/Config
-- Every tunable number in the game lives here.

local Config = {}

Config.GameName = "+1 Loot for Anime"
Config.DataStoreName = "PlusOneLootAnime_v1"
Config.LeaderboardStoreName = "PlusOneLootAnime_BladeBoard_v1"

-- Set to true while testing in Studio to act as if you own every gamepass.
Config.StudioOwnsAllPasses = false

---------------------------------------------------------------------
-- RARITIES
---------------------------------------------------------------------
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Rift" }
Config.Rarity = {
	Common = { Index = 1, Color = Color3.fromRGB(205, 210, 220), Label = "Common" },
	Uncommon = { Index = 2, Color = Color3.fromRGB(90, 230, 120), Label = "Uncommon" },
	Rare = { Index = 3, Color = Color3.fromRGB(70, 165, 255), Label = "Rare" },
	Epic = { Index = 4, Color = Color3.fromRGB(185, 95, 255), Label = "Epic" },
	Legendary = { Index = 5, Color = Color3.fromRGB(255, 195, 45), Label = "Legendary" },
	Mythic = { Index = 6, Color = Color3.fromRGB(255, 70, 125), Label = "Mythic" },
	Rift = { Index = 7, Color = Color3.fromRGB(0, 255, 225), Label = "Rift-forged" },
}

---------------------------------------------------------------------
-- ORES  (Forge = blade levels gained per ore, Sell = coins per ore)
---------------------------------------------------------------------
Config.Ores = {
	{ Id = "RiftPebble", Name = "Rift Pebble", Rarity = "Common", Forge = 1, Sell = 2 },
	{ Id = "ChakraCopper", Name = "Chakra Copper", Rarity = "Uncommon", Forge = 2, Sell = 6 },
	{ Id = "SpiritSilver", Name = "Spirit Silver", Rarity = "Rare", Forge = 5, Sell = 20 },
	{ Id = "KiCrystal", Name = "Ki Crystal", Rarity = "Epic", Forge = 25, Sell = 90 },
	{ Id = "SakuraGold", Name = "Sakura Gold", Rarity = "Legendary", Forge = 100, Sell = 400 },
	{ Id = "VoidMythril", Name = "Void Mythril", Rarity = "Mythic", Forge = 250, Sell = 1200 },
	{ Id = "RiftCore", Name = "Rift-forged Core", Rarity = "Rift", Forge = 1000, Sell = 5000 },
}
Config.OreById = {}
for i, ore in ipairs(Config.Ores) do
	ore.Order = i
	ore.Color = Config.Rarity[ore.Rarity].Color
	Config.OreById[ore.Id] = ore
end

-- Coins rewarded the first time an ore is added to your Index.
Config.IndexReward = { Common = 25, Uncommon = 100, Rare = 400, Epic = 2000, Legendary = 10000, Mythic = 50000, Rift = 250000 }

---------------------------------------------------------------------
-- ZONES + DUNGEON STAGES
---------------------------------------------------------------------
Config.Zones = {
	{
		Id = 1,
		Name = "Verdant Academy Ruins",
		BladeReq = 0,
		Style = "Creature",
		Floor = Color3.fromRGB(120, 150, 95),
		Wall = Color3.fromRGB(190, 180, 160),
		Accent = Color3.fromRGB(120, 255, 150),
		Tint = Color3.fromRGB(235, 255, 235),
	},
	{
		Id = 2,
		Name = "Neon Mecha Docks",
		BladeReq = 100,
		Style = "Mech",
		Floor = Color3.fromRGB(35, 38, 55),
		Wall = Color3.fromRGB(55, 60, 85),
		Accent = Color3.fromRGB(0, 240, 255),
		Tint = Color3.fromRGB(225, 235, 255),
	},
	{ Id = 3, Name = "Sakura Underworld", ComingSoon = true, Accent = Color3.fromRGB(255, 120, 190) },
	{ Id = 4, Name = "Starlit Battlefront", ComingSoon = true, Accent = Color3.fromRGB(140, 120, 255) },
	{ Id = 5, Name = "The Rift Throne", ComingSoon = true, Accent = Color3.fromRGB(0, 255, 225) },
}

-- Drops = weights per ore id (Luck pushes weight toward rarer ores).
Config.Stages = {
	{ Zone = 1, PowerReq = 0, Enemy = "Slime Delinquent", HP = 25, Count = 7, Coins = 2, Color = Color3.fromRGB(120, 230, 120), Drops = { RiftPebble = 90, ChakraCopper = 10 } },
	{ Zone = 1, PowerReq = 60, Enemy = "Hall Monitor Oni", HP = 90, Count = 7, Coins = 5, Color = Color3.fromRGB(230, 90, 90), Drops = { RiftPebble = 70, ChakraCopper = 27, SpiritSilver = 3 } },
	{ Zone = 1, PowerReq = 250, Enemy = "Club Captain Golem", HP = 350, Count = 6, Coins = 12, Color = Color3.fromRGB(160, 140, 120), Drops = { RiftPebble = 50, ChakraCopper = 38, SpiritSilver = 11, KiCrystal = 1 } },
	{ Zone = 1, PowerReq = 900, Enemy = "Rooftop Ronin", HP = 1400, Count = 6, Coins = 30, Color = Color3.fromRGB(90, 110, 220), Drops = { ChakraCopper = 55, SpiritSilver = 35, KiCrystal = 9, SakuraGold = 1 } },
	{ Zone = 1, PowerReq = 2500, Enemy = "Student Council Tyrant", HP = 60000, Count = 1, Boss = true, Coins = 600, Color = Color3.fromRGB(200, 60, 255), Drops = { SpiritSilver = 50, KiCrystal = 35, SakuraGold = 13, VoidMythril = 2 } },

	{ Zone = 2, PowerReq = 6000, Enemy = "Scrap Drone", HP = 20000, Count = 7, Coins = 60, Color = Color3.fromRGB(255, 170, 60), Drops = { SpiritSilver = 60, KiCrystal = 32, SakuraGold = 7, VoidMythril = 1 } },
	{ Zone = 2, PowerReq = 15000, Enemy = "Dockside Mech-Grunt", HP = 90000, Count = 7, Coins = 140, Color = Color3.fromRGB(120, 200, 255), Drops = { SpiritSilver = 45, KiCrystal = 40, SakuraGold = 13, VoidMythril = 2 } },
	{ Zone = 2, PowerReq = 40000, Enemy = "Neon Ninja Unit", HP = 400000, Count = 6, Coins = 350, Color = Color3.fromRGB(255, 60, 200), Drops = { KiCrystal = 60, SakuraGold = 34, VoidMythril = 6 } },
	{ Zone = 2, PowerReq = 100000, Enemy = "Plasma Warden", HP = 2000000, Count = 6, Coins = 900, Color = Color3.fromRGB(0, 255, 180), Drops = { KiCrystal = 45, SakuraGold = 42, VoidMythril = 12, RiftCore = 1 } },
	{ Zone = 2, PowerReq = 250000, Enemy = "Mecha Admiral Kaizer", HP = 60000000, Count = 1, Boss = true, Coins = 12000, Color = Color3.fromRGB(255, 40, 60), Drops = { SakuraGold = 55, VoidMythril = 38, RiftCore = 7 } },
}
for i, stage in ipairs(Config.Stages) do
	stage.Index = i
end
Config.StagesPerZone = 5

Config.EnemyRespawn = 3 -- seconds (normal enemies)
Config.BossRespawn = 45 -- seconds
Config.EliteChance = 0.03 -- rare golden "Elite" spawn
Config.EliteHPMult = 5
Config.EliteDropMult = 3
Config.BossOreDrops = 8
Config.BossRerollChance = 0.05
Config.EnemyAggroRange = 38
Config.EnemyAttackRange = 6.5
Config.EnemyAttackCooldown = 1.6
Config.EnemyHitPercent = 0.06 -- % of player max HP per hit
Config.BossSlamPercent = 0.22
Config.BossSlamRadius = 18
Config.BossSlamEvery = 5

---------------------------------------------------------------------
-- COMBAT
---------------------------------------------------------------------
Config.SwingCooldown = 0.32
Config.SwingRange = 11
Config.BaseDamage = 5
Config.PowerDamageDivisor = 100 -- damage *= 1 + Power / this
Config.BaseCritChance = 0.05
Config.CritMultiplier = 2
Config.PickupRadius = 14
Config.DropLifetime = 60

---------------------------------------------------------------------
-- TRAINING (the Train area pads, like the base game's multiplier zones)
---------------------------------------------------------------------
Config.TrainPads = {
	{ Mult = 1, Power = 0, Rebirths = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Mult = 3, Power = 100, Rebirths = 0, Color = Color3.fromRGB(90, 230, 120) },
	{ Mult = 10, Power = 1000, Rebirths = 0, Color = Color3.fromRGB(70, 165, 255) },
	{ Mult = 30, Power = 0, Rebirths = 1, Color = Color3.fromRGB(185, 95, 255) },
	{ Mult = 100, Power = 0, Rebirths = 3, Color = Color3.fromRGB(255, 195, 45) },
	{ Mult = 400, Power = 0, Rebirths = 8, Color = Color3.fromRGB(255, 70, 125) },
	{ Mult = 1500, Power = 0, Rebirths = 20, Color = Color3.fromRGB(0, 255, 225) },
}
Config.TrainPadRadius = 9
Config.AutoTrainPerSecond = 1 -- * pad multiplier, while standing on a pad
Config.ClickPower = 1 -- * pad multiplier, per sword swing

---------------------------------------------------------------------
-- COIN UPGRADES  (Backpack / Luck / Training)
---------------------------------------------------------------------
Config.Upgrades = {
	Backpack = { Name = "Backpack", Desc = "+10 ore capacity", Base = 50, Growth = 1.35, Max = 198 },
	Luck = { Name = "Luck", Desc = "+0.05x rare ore luck", Base = 100, Growth = 1.28, Max = 480 },
	Training = { Name = "Training", Desc = "+10% Power per swing", Base = 75, Growth = 1.3, Max = 300 },
}
Config.BaseBackpack = 20

---------------------------------------------------------------------
-- REBIRTH (Ascension)
---------------------------------------------------------------------
Config.RebirthBasePower = 5000
Config.RebirthPowerGrowth = 4
Config.RebirthPowerBonus = 1 -- +100% power gain per rebirth
Config.RebirthCoinBonus = 0.25
Config.RebirthDamageBonus = 0.1
Config.RebirthRerollReward = 1
Config.AscensionAuras = { -- cosmetic aura by rebirth count
	{ Rebirths = 1, Color = Color3.fromRGB(120, 200, 255) },
	{ Rebirths = 5, Color = Color3.fromRGB(185, 95, 255) },
	{ Rebirths = 15, Color = Color3.fromRGB(255, 195, 45) },
	{ Rebirths = 40, Color = Color3.fromRGB(255, 70, 125) },
	{ Rebirths = 100, Color = Color3.fromRGB(0, 255, 225) },
}

---------------------------------------------------------------------
-- BLADE VISUAL TIERS
---------------------------------------------------------------------
Config.BladeTiers = {
	{ Level = 0, Name = "Plain Steel", Blade = Color3.fromRGB(200, 205, 215), Edge = nil, Length = 3.2 },
	{ Level = 10, Name = "Engraved", Blade = Color3.fromRGB(215, 220, 230), Edge = Color3.fromRGB(255, 215, 120), Length = 3.5 },
	{ Level = 25, Name = "Glowing", Blade = Color3.fromRGB(190, 230, 255), Edge = Color3.fromRGB(80, 200, 255), Length = 3.8, Light = true },
	{ Level = 50, Name = "Elemental", Blade = Color3.fromRGB(255, 180, 120), Edge = Color3.fromRGB(255, 120, 30), Length = 4.1, Light = true, Particles = "Fire" },
	{ Level = 100, Name = "Spirit", Blade = Color3.fromRGB(200, 160, 255), Edge = Color3.fromRGB(170, 80, 255), Length = 4.4, Light = true, Particles = "Spark" },
	{ Level = 250, Name = "Awakened", Blade = Color3.fromRGB(255, 190, 220), Edge = Color3.fromRGB(255, 90, 170), Length = 4.8, Light = true, Particles = "Petal" },
	{ Level = 500, Name = "Radiant", Blade = Color3.fromRGB(255, 240, 170), Edge = Color3.fromRGB(255, 200, 40), Length = 5.2, Light = true, Particles = "Spark" },
	{ Level = 1000, Name = "Celestial", Blade = Color3.fromRGB(230, 245, 255), Edge = Color3.fromRGB(150, 220, 255), Length = 5.6, Light = true, Particles = "Star" },
	{ Level = 2500, Name = "Rift", Blade = Color3.fromRGB(30, 40, 50), Edge = Color3.fromRGB(0, 255, 225), Length = 6, Light = true, Particles = "Vortex" },
	{ Level = 5000, Name = "Final Release", Blade = Color3.fromRGB(20, 10, 15), Edge = Color3.fromRGB(255, 40, 60), Length = 6.6, Light = true, Particles = "Fire" },
}

function Config.GetBladeTier(level: number)
	local tier, index = Config.BladeTiers[1], 1
	for i, t in ipairs(Config.BladeTiers) do
		if level >= t.Level then
			tier, index = t, i
		end
	end
	return tier, index
end

---------------------------------------------------------------------
-- RACES (bloodlines)
---------------------------------------------------------------------
Config.Races = {
	{ Id = "Pirate", Name = "Pirate", Weight = 32, Color = Color3.fromRGB(255, 170, 60), Desc = "Treasure Sense: +25% Luck, +30% Coins. Nearby allies get +10% Coins.", Damage = 1, Luck = 1.25, Coins = 1.3 },
	{ Id = "Ninja", Name = "Ninja", Weight = 27, Color = Color3.fromRGB(110, 120, 255), Desc = "+20% speed, +15% crit chance, dodge window after every kill.", Damage = 1.05, Speed = 1.2, Crit = 0.15 },
	{ Id = "Assassin", Name = "Assassin", Weight = 18, Color = Color3.fromRGB(170, 60, 80), Desc = "First strike on a fresh enemy deals 3x damage.", Damage = 1.05, FirstHit = 3 },
	{ Id = "Sorcerer", Name = "Sorcerer", Weight = 12, Color = Color3.fromRGB(80, 220, 255), Desc = "Every 5th swing unleashes an elemental AoE. Overdrive lasts 30% longer.", Damage = 1.1, AoEEvery = 5, OverdriveDuration = 1.3 },
	{ Id = "Isekai", Name = "Isekai", Weight = 7, Color = Color3.fromRGB(120, 255, 170), Desc = "Cheat code: +50% Power gain, +25% Forge value, keep 10% Power on rebirth.", Damage = 1.1, Power = 1.5, Forge = 1.25 },
	{ Id = "Saiyan", Name = "Saiyan", Weight = 3.9, Color = Color3.fromRGB(255, 225, 60), Desc = "Damage rises as HP drops. Survive a near-death hit for a Zenkai Boost (+100% dmg).", Damage = 1.35, Zenkai = true },
	{ Id = "MainCharacter", Name = "Main Character", Weight = 0.1, Color = Color3.fromRGB(255, 215, 90), Desc = "+15% to EVERY stat, golden aura, exclusive title and Plot Armor.", Damage = 1.5, AllStats = 1.15, PlotArmor = 0.1 },
}
Config.RaceById = {}
for _, r in ipairs(Config.Races) do
	Config.RaceById[r.Id] = r
end

-- Cosmetic skin tier rolled independently on top of the race.
Config.RaceTiers = {
	{ Id = "Common", Weight = 60, Damage = 1, Color = Color3.fromRGB(205, 210, 220) },
	{ Id = "Rare", Weight = 25, Damage = 1.03, Color = Color3.fromRGB(70, 165, 255) },
	{ Id = "Epic", Weight = 10, Damage = 1.06, Color = Color3.fromRGB(185, 95, 255) },
	{ Id = "Legendary", Weight = 4, Damage = 1.1, Color = Color3.fromRGB(255, 195, 45) },
	{ Id = "Mythic", Weight = 1, Damage = 1.2, Color = Color3.fromRGB(255, 70, 125), Label = "Awakened" },
}
Config.RaceTierById = {}
for _, t in ipairs(Config.RaceTiers) do
	Config.RaceTierById[t.Id] = t
end

Config.StartingRerolls = 3
Config.ZenkaiThreshold = 0.2
Config.ZenkaiDuration = 8
Config.ZenkaiCooldown = 30
Config.NinjaDodgeTime = 1.5

---------------------------------------------------------------------
-- OVERDRIVE (transformation buff)
---------------------------------------------------------------------
Config.Overdrive = {
	Duration = 180,
	Damage = 2,
	Speed = 1.3,
	Power = 1.5,
	StartingPotions = 1,
}

---------------------------------------------------------------------
-- TOWER (timed personal trial: beat the Guardian before the clock runs out)
---------------------------------------------------------------------
Config.Tower = {
	PowerReq = 300,
	TimeLimit = 30,
	BaseHP = 600,
	HPGrowth = 1.9,
	CoinBase = 40,
	RunesPerFloor = 1,
	RuneDamageBonus = 0.02, -- each rune = +2% damage, permanent
}

---------------------------------------------------------------------
-- MONETIZATION  (put your real IDs in!  0 = not set up yet)
---------------------------------------------------------------------
Config.GamePasses = {
	DoubleCoins = { Id = 0, Name = "2x Coins", Desc = "Doubles all Coin earnings." },
	DoubleLuck = { Id = 0, Name = "2x Luck", Desc = "Doubles rare ore odds and nudges rare race odds." },
	AutoForge = { Id = 0, Name = "Auto-Forge", Desc = "Ore is smelted the moment you pick it up." },
	AutoCollect = { Id = 0, Name = "Auto-Collect", Desc = "Ore flies straight into your backpack." },
	ExtraBackpack = { Id = 0, Name = "Extra Backpack", Desc = "+50% backpack capacity." },
	DoubleOverdrive = { Id = 0, Name = "2x Overdrive", Desc = "Transformations last twice as long." },
	FastTravel = { Id = 0, Name = "Fast Travel", Desc = "Teleport to any unlocked stage, the Tower and the Train area." },
	ChromaTrail = { Id = 0, Name = "Chroma Trail", Desc = "Rainbow trail while you move. Pure flex." },
	MCPity = { Id = 0, Name = "Main Character Boost", Desc = "Slightly raises Main Character odds (never guaranteed)." },
	DoubleTraining = { Id = 0, Name = "2x Training", Desc = "Training upgrades give double the Power bonus." },
}
Config.GamePassOrder = { "DoubleCoins", "DoubleLuck", "AutoForge", "AutoCollect", "ExtraBackpack", "DoubleOverdrive", "FastTravel", "ChromaTrail", "MCPity", "DoubleTraining" }

Config.Products = {
	StarterPack = { Id = 0, Name = "Starter Pack", Desc = "5K Coins + 3 Rerolls + 2 Overdrive (one time)", Coins = 5000, Rerolls = 3, Overdrive = 2, OneTime = true },
	Reroll5 = { Id = 0, Name = "5 Race Rerolls", Rerolls = 5 },
	Reroll10 = { Id = 0, Name = "10 Race Rerolls", Rerolls = 10 },
	Reroll25 = { Id = 0, Name = "25 Race Rerolls", Rerolls = 25 },
	Overdrive3 = { Id = 0, Name = "3 Overdrive Potions", Overdrive = 3 },
	Overdrive10 = { Id = 0, Name = "10 Overdrive Potions", Overdrive = 10 },
	CoinsS = { Id = 0, Name = "Coin Chest S", Coins = 1000, ScaleWithRebirth = true },
	CoinsM = { Id = 0, Name = "Coin Chest M", Coins = 12000, ScaleWithRebirth = true },
	CoinsL = { Id = 0, Name = "Coin Chest L", Coins = 150000, ScaleWithRebirth = true },
	CoinsXL = { Id = 0, Name = "Coin Chest XL", Coins = 2000000, ScaleWithRebirth = true },
}
Config.ProductOrder = { "StarterPack", "Reroll5", "Reroll10", "Reroll25", "Overdrive3", "Overdrive10", "CoinsS", "CoinsM", "CoinsL", "CoinsXL" }

Config.Codes = {
	RELEASE = { Coins = 250, Rerolls = 2 },
	PLUSONE = { Overdrive = 1 },
	ANIMEFORGE = { Coins = 1000, Rerolls = 1 },
	MAINCHARACTER = { Rerolls = 3 },
}

---------------------------------------------------------------------
-- AUDIO  (optional: paste your own Creator Store audio ids here)
---------------------------------------------------------------------
-- Leave 0 for no music. Any id you put here plays as a looping track.
Config.Music = {
	Hub = 0,
	Zone1 = 0,
	Zone2 = 0,
	Tower = 0,
}
-- Override any sound effect with your own asset, e.g. Swing = "rbxassetid://123".
Config.SoundOverrides = {}

return Config
