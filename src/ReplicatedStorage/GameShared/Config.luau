--!nonstrict
-- Config (ModuleScript) -> ReplicatedStorage/GameShared/Config
-- Every tunable number in the game lives here.

local Config = {}

Config.GameName = "+1 Loot for Anime"
Config.DataStoreName = "PlusOneLootAnime_v2"

-- Set to true while testing in Studio to act as if you own every gamepass.
Config.StudioOwnsAllPasses = false

---------------------------------------------------------------------
-- ADMINS  (admin panel: P key or the drawer's "Admin" button)
---------------------------------------------------------------------
-- The place owner is always an admin (and everyone is, in Studio).
-- Add extra Roblox UserIds here, or a group + minimum rank.
Config.Admins = {
	UserIds = {}, -- e.g. { 12345678 }
	GroupId = 0,
	MinRank = 254,
	OwnerIsAdmin = true,
	StudioIsAdmin = true,
}

-- Global "admin abuse" events (multipliers apply to everyone in the server).
Config.Events = {
	Luck = { Name = "2x LUCK", Color = Color3.fromRGB(120, 255, 170), Mult = 2, Duration = 600 },
	Coins = { Name = "3x COINS", Color = Color3.fromRGB(255, 210, 70), Mult = 3, Duration = 600 },
	Power = { Name = "5x POWER", Color = Color3.fromRGB(255, 110, 110), Mult = 5, Duration = 600 },
	Drops = { Name = "2x ORE DROPS", Color = Color3.fromRGB(120, 200, 255), Mult = 2, Duration = 600 },
}

---------------------------------------------------------------------
-- FONTS  (one place to restyle every label in the game)
---------------------------------------------------------------------
Config.Fonts = {
	Display = Enum.Font.Bangers, -- titles, big numbers, buttons (manga sound-effect look)
	Heading = Enum.Font.Sarpanch, -- small caps / labels / key caps
	Body = Enum.Font.Oswald, -- readable body text
}

---------------------------------------------------------------------
-- RARITIES (ores)
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
-- ORE EFFECTS  (what an ore does to a weapon you forge with it)
---------------------------------------------------------------------
-- Every ore carries one effect worth some "points". Forging adds up the
-- points of each effect in the recipe; Config.EffectValue turns points into
-- the real number (capped at Max). Classes = the weapon types this effect
-- pulls a random forge toward.
Config.Effects = {
	Heavy = { Name = "Heavy", Color = Color3.fromRGB(200, 190, 180), Per = 0.06, Max = 1.5, Pct = true, Desc = "+%s damage", VFX = "Shards", Classes = { "Greatsword", "Hammer" } },
	Burn = { Name = "Burn", Color = Color3.fromRGB(255, 120, 40), Per = 0.04, Max = 0.6, Pct = true, Desc = "%s chance to set enemies ablaze", VFX = "Fire", Classes = { "Katana", "Staff" } },
	Frost = { Name = "Frost", Color = Color3.fromRGB(150, 220, 255), Per = 0.04, Max = 0.6, Pct = true, Desc = "%s chance to chill (slowed enemies take +25%%)", VFX = "Frost", Classes = { "Spear", "Bow" } },
	Ki = { Name = "Ki Flow", Color = Color3.fromRGB(240, 150, 90), Per = 0.03, Max = 0.4, Pct = true, Desc = "-%s ability stamina cost", VFX = "Rise", Classes = { "Glove", "Claws" } },
	Shock = { Name = "Shock", Color = Color3.fromRGB(255, 240, 90), Per = 0.04, Max = 0.6, Pct = true, Desc = "%s chance to chain lightning", VFX = "Lightning", Classes = { "Chain", "Staff" } },
	Poison = { Name = "Poison", Color = Color3.fromRGB(120, 230, 90), Per = 0.05, Max = 0.8, Pct = true, Desc = "%s chance to poison (stacks)", VFX = "Poison", Classes = { "Daggers", "Kunai" } },
	Gale = { Name = "Gale", Color = Color3.fromRGB(160, 255, 220), Per = 6, Max = 70, Pct = false, Desc = "+%s knockback", VFX = "Wind", Classes = { "Fan", "Bow" } },
	Pierce = { Name = "Pierce", Color = Color3.fromRGB(200, 220, 255), Per = 0.04, Max = 0.5, Pct = true, Desc = "+%s reach, shots pierce", VFX = "Sparks", Classes = { "Spear", "Pistols", "Bow" } },
	Bleed = { Name = "Bleed", Color = Color3.fromRGB(220, 30, 50), Per = 0.1, Max = 1.5, Pct = true, Desc = "Crits bleed for %s damage", VFX = "Blood", Classes = { "Scythe", "Claws", "Daggers" } },
	Fortune = { Name = "Fortune", Color = Color3.fromRGB(255, 200, 70), Per = 0.06, Max = 2, Pct = true, Desc = "+%s Coins from kills", VFX = "Stars", Classes = { "Pistols", "Kunai" } },
	Echo = { Name = "Echo", Color = Color3.fromRGB(200, 170, 255), Per = 0.03, Max = 0.4, Pct = true, Desc = "%s chance to strike twice", VFX = "Glow", Classes = { "Daggers", "Katana" } },
	Haste = { Name = "Haste", Color = Color3.fromRGB(90, 240, 255), Per = 0.025, Max = 0.35, Pct = true, Desc = "+%s attack speed", VFX = "Wind", Classes = { "Daggers", "Claws" } },
	Lifesteal = { Name = "Lifesteal", Color = Color3.fromRGB(255, 150, 190), Per = 0.004, Max = 0.04, Pct = true, Desc = "Heal %s of max HP per hit", VFX = "Blood", Classes = { "Scythe", "Katana" } },
	Crit = { Name = "Keen", Color = Color3.fromRGB(255, 80, 80), Per = 0.02, Max = 0.3, Pct = true, Desc = "+%s crit chance", VFX = "Sparks", Classes = { "Katana", "Daggers" } },
	Radiant = { Name = "Radiant", Color = Color3.fromRGB(255, 240, 150), Per = 0.05, Max = 0.8, Pct = true, Desc = "Hits splash %s damage around", VFX = "Holy", Classes = { "Cannon", "Staff", "FingerGun" } },
	Greed = { Name = "Greed", Color = Color3.fromRGB(255, 170, 210), Per = 0.04, Max = 1, Pct = true, Desc = "+%s ore luck", VFX = "Stars", Classes = { "Kunai", "Fan" } },
	Titan = { Name = "Titan", Color = Color3.fromRGB(235, 225, 200), Per = 0.08, Max = 2, Pct = true, Desc = "+%s damage to bosses", VFX = "Shards", Classes = { "Hammer", "Greatsword", "Cannon" } },
	Chrono = { Name = "Chrono", Color = Color3.fromRGB(255, 190, 90), Per = 0.02, Max = 0.3, Pct = true, Desc = "-%s skill cooldowns", VFX = "Vortex", Classes = { "Staff", "FingerGun" } },
	Void = { Name = "Void", Color = Color3.fromRGB(160, 70, 255), Per = 0.008, Max = 0.15, Pct = true, Desc = "Executes enemies under %s HP", VFX = "Void", Classes = { "Scythe", "FingerGun" } },
	Soul = { Name = "Soul Harvest", Color = Color3.fromRGB(80, 255, 220), Per = 0.5, Max = 20, Pct = false, Desc = "Kills give %sx a swing of Power", VFX = "Rise", Classes = { "Glove", "Scythe" } },
	Holy = { Name = "Holy", Color = Color3.fromRGB(255, 255, 220), Per = 0.02, Max = 0.3, Pct = true, Desc = "Heal %s of max HP on kill", VFX = "Holy", Classes = { "Spear", "Staff" } },
}
Config.EffectOrder = { "Heavy", "Burn", "Frost", "Ki", "Shock", "Poison", "Gale", "Pierce", "Bleed", "Fortune", "Echo", "Haste", "Lifesteal", "Crit", "Radiant", "Greed", "Titan", "Chrono", "Void", "Soul", "Holy" }

function Config.EffectValue(effectId: string, points: number): number
	local e = Config.Effects[effectId]
	if not e or not points then
		return 0
	end
	return math.min(e.Max, points * e.Per)
end

function Config.EffectText(effectId: string, points: number): string
	local e = Config.Effects[effectId]
	if not e then
		return ""
	end
	local v = Config.EffectValue(effectId, points)
	local s = e.Pct and (string.format("%g", math.floor(v * 1000 + 0.5) / 10) .. "%") or string.format("%g", math.floor(v * 10 + 0.5) / 10)
	return e.Name .. ": " .. string.format(e.Desc, s)
end

---------------------------------------------------------------------
-- ORES  (Forge = Forge levels gained when used, Sell = coins, Points = effect strength)
---------------------------------------------------------------------
local ORE_POINTS = { Common = 2, Uncommon = 3, Rare = 5, Epic = 8, Legendary = 12, Mythic = 18, Rift = 26 }
local ORE_FORGE = { Common = 1, Uncommon = 3, Rare = 8, Epic = 30, Legendary = 120, Mythic = 400, Rift = 1500 }
local ORE_SELL = { Common = 3, Uncommon = 10, Rare = 40, Epic = 180, Legendary = 900, Mythic = 5000, Rift = 30000 }
Config.Ores = {
	{ Id = "RiftPebble", Name = "Rift Pebble", Rarity = "Common", Effect = "Heavy", Color = Color3.fromRGB(170, 170, 180) },
	{ Id = "CinderStone", Name = "Cinder Stone", Rarity = "Common", Effect = "Burn", Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "FrostDew", Name = "Frost Dew", Rarity = "Common", Effect = "Frost", Color = Color3.fromRGB(170, 225, 255) },
	{ Id = "ChakraCopper", Name = "Chakra Copper", Rarity = "Uncommon", Effect = "Ki", Color = Color3.fromRGB(230, 140, 80) },
	{ Id = "StormQuartz", Name = "Storm Quartz", Rarity = "Uncommon", Effect = "Shock", Color = Color3.fromRGB(255, 235, 110) },
	{ Id = "VenomJade", Name = "Venom Jade", Rarity = "Uncommon", Effect = "Poison", Color = Color3.fromRGB(110, 220, 100) },
	{ Id = "GaleOpal", Name = "Gale Opal", Rarity = "Uncommon", Effect = "Gale", Color = Color3.fromRGB(170, 255, 225) },
	{ Id = "SpiritSilver", Name = "Spirit Silver", Rarity = "Rare", Effect = "Pierce", Color = Color3.fromRGB(190, 215, 255) },
	{ Id = "BloodRuby", Name = "Blood Ruby", Rarity = "Rare", Effect = "Bleed", Color = Color3.fromRGB(220, 30, 60) },
	{ Id = "LuckyTopaz", Name = "Lucky Topaz", Rarity = "Rare", Effect = "Fortune", Color = Color3.fromRGB(255, 190, 60) },
	{ Id = "EchoGlass", Name = "Echo Glass", Rarity = "Rare", Effect = "Echo", Color = Color3.fromRGB(205, 175, 255) },
	{ Id = "KiCrystal", Name = "Ki Crystal", Rarity = "Epic", Effect = "Haste", Color = Color3.fromRGB(80, 235, 255) },
	{ Id = "MoonPearl", Name = "Moon Pearl", Rarity = "Epic", Effect = "Lifesteal", Color = Color3.fromRGB(255, 220, 240) },
	{ Id = "DragonScale", Name = "Dragon Scale", Rarity = "Epic", Effect = "Crit", Color = Color3.fromRGB(230, 50, 50) },
	{ Id = "SunIron", Name = "Sun Iron", Rarity = "Epic", Effect = "Heavy", Color = Color3.fromRGB(255, 220, 110) },
	{ Id = "SakuraGold", Name = "Sakura Gold", Rarity = "Legendary", Effect = "Greed", Color = Color3.fromRGB(255, 170, 200) },
	{ Id = "TitanBone", Name = "Titan Bone", Rarity = "Legendary", Effect = "Titan", Color = Color3.fromRGB(240, 230, 205) },
	{ Id = "ChronoAmber", Name = "Chrono Amber", Rarity = "Legendary", Effect = "Chrono", Color = Color3.fromRGB(255, 170, 40) },
	{ Id = "VoidMythril", Name = "Void Mythril", Rarity = "Mythic", Effect = "Void", Color = Color3.fromRGB(150, 60, 255) },
	{ Id = "Soulstone", Name = "Soulstone", Rarity = "Mythic", Effect = "Soul", Color = Color3.fromRGB(60, 255, 210) },
	{ Id = "RiftCore", Name = "Rift-forged Core", Rarity = "Rift", Effect = "Radiant", Color = Color3.fromRGB(0, 255, 225) },
	{ Id = "CelestialStar", Name = "Celestial Star", Rarity = "Rift", Effect = "Holy", Color = Color3.fromRGB(255, 255, 230) },
}
Config.OreById = {}
for i, ore in ipairs(Config.Ores) do
	ore.Order = i
	ore.RarityIndex = Config.Rarity[ore.Rarity].Index
	ore.Points = ORE_POINTS[ore.Rarity]
	ore.Forge = ORE_FORGE[ore.Rarity]
	ore.Sell = ORE_SELL[ore.Rarity]
	Config.OreById[ore.Id] = ore
end

-- Coins rewarded the first time an ore is added to your Index.
Config.IndexReward = { Common = 25, Uncommon = 150, Rare = 800, Epic = 5000, Legendary = 40000, Mythic = 300000, Rift = 3000000 }

---------------------------------------------------------------------
-- THE PATH  (stages in a line; kill enough enemies to open the next gate,
-- a boss guards every 5th stage)
---------------------------------------------------------------------
Config.Zones = {
	{ Id = 1, Name = "Verdant Academy Ruins", Floor = Color3.fromRGB(58, 72, 52), Wall = Color3.fromRGB(96, 92, 86), Accent = Color3.fromRGB(120, 255, 150), Tint = Color3.fromRGB(225, 245, 225) },
	{ Id = 2, Name = "Neon Mecha Docks", Floor = Color3.fromRGB(26, 28, 40), Wall = Color3.fromRGB(44, 48, 68), Accent = Color3.fromRGB(0, 230, 255), Tint = Color3.fromRGB(215, 230, 255) },
	{ Id = 3, Name = "Sakura Underworld", Floor = Color3.fromRGB(56, 34, 46), Wall = Color3.fromRGB(80, 48, 62), Accent = Color3.fromRGB(255, 120, 190), Tint = Color3.fromRGB(255, 225, 240) },
	{ Id = 4, Name = "Starlit Battlefront", Floor = Color3.fromRGB(30, 26, 52), Wall = Color3.fromRGB(52, 44, 84), Accent = Color3.fromRGB(150, 120, 255), Tint = Color3.fromRGB(225, 220, 255) },
	{ Id = 5, Name = "Frostfang Peaks", Floor = Color3.fromRGB(72, 86, 100), Wall = Color3.fromRGB(110, 128, 146), Accent = Color3.fromRGB(150, 225, 255), Tint = Color3.fromRGB(225, 240, 255) },
	{ Id = 6, Name = "The Rift Throne", Floor = Color3.fromRGB(22, 18, 26), Wall = Color3.fromRGB(40, 30, 44), Accent = Color3.fromRGB(0, 255, 225), Tint = Color3.fromRGB(230, 220, 235) },
}
Config.StagesPerZone = 5

local STAGE_NAMES = {
	{ "Slime Delinquent", "Hall Monitor Oni", "Club Captain Golem", "Rooftop Ronin", "Student Council Tyrant" },
	{ "Scrap Drone", "Dockside Mech-Grunt", "Neon Ninja Unit", "Plasma Warden", "Mecha Admiral Kaizer" },
	{ "Lantern Wisp", "Kitsune Trickster", "Blossom Samurai", "Petal Witch", "Sakura Demon Queen" },
	{ "Star Cadet", "Comet Knight", "Nebula Sniper", "Void Paladin", "General Starfall" },
	{ "Frost Yeti", "Ice Monk", "Blizzard Ronin", "Glacier Titan", "Frost Emperor Yuki" },
	{ "Rift Stalker", "Chaos Acolyte", "Abyss Knight", "Rift Warlord", "The Rift King" },
}

-- Exponential curves. Stage i: HP = 30 * 1.9^(i-1), Coins = 3 * 1.75^(i-1).
Config.PathCurve = {
	BaseHP = 30,
	HPGrowth = 1.9,
	BaseCoins = 3,
	CoinGrowth = 1.75,
	BossHPMult = 30,
	BossCoinMult = 20,
	KillsToAdvance = 8,
	SpawnCount = 6,
}

-- Which ores a stage can drop: the newest ore is always the rarest drop.
local function stageDrops(i: number, boss: boolean)
	local maxOrder = math.min(#Config.Ores, 2 + math.ceil(i * 0.7) + (boss and 1 or 0))
	local drops = {}
	for o = math.max(1, maxOrder - 7), maxOrder do
		drops[Config.Ores[o].Id] = 100 * 0.6 ^ (maxOrder - o)
	end
	return drops
end

Config.Stages = {}
for z, names in ipairs(STAGE_NAMES) do
	for k, enemy in ipairs(names) do
		local i = (z - 1) * Config.StagesPerZone + k
		local boss = k == Config.StagesPerZone
		local C = Config.PathCurve
		local hp = C.BaseHP * C.HPGrowth ^ (i - 1)
		local coins = C.BaseCoins * C.CoinGrowth ^ (i - 1)
		table.insert(Config.Stages, {
			Index = i,
			Zone = z,
			Enemy = enemy,
			Boss = boss,
			HP = boss and hp * C.BossHPMult or hp,
			Coins = math.floor(boss and coins * C.BossCoinMult or coins),
			Count = boss and 1 or C.SpawnCount,
			Kills = boss and 1 or C.KillsToAdvance,
			Color = Config.Zones[z].Accent:Lerp(Color3.fromHSV(((i * 0.137) % 1), 0.6, 1), 0.45),
			Drops = stageDrops(i, boss),
		})
	end
end

-- Path geometry (shared by MapBuilder, the world map and the client).
Config.World = {
	PlazaRadius = 72,
	PathStartZ = -120, -- the first gate
	PathWidth = 72,
	StageLen = 90,
	BossLen = 130,
	TrainCenter = Vector3.new(-200, 0, 0),
	BossRushCenter = Vector3.new(200, 0, 0),
}

-- Returns zStart (gate side), zEnd, center for stage i.
function Config.StageBounds(i: number): (number, number, Vector3)
	local W = Config.World
	local z = W.PathStartZ
	for k = 1, i - 1 do
		z -= Config.Stages[k].Boss and W.BossLen or W.StageLen
	end
	local len = Config.Stages[i].Boss and W.BossLen or W.StageLen
	return z, z - len, Vector3.new(0, 0, z - len / 2)
end

-- World map fog of war: regions you have walked into (saved per player).
Config.ExploreKeys = { Hub = true, Train = true, BossRush = true }
for i in ipairs(Config.Stages) do
	Config.ExploreKeys["S" .. i] = true
end
for _, zone in ipairs(Config.Zones) do
	Config.ExploreKeys["Z" .. zone.Id] = true
end

Config.EnemyRespawn = 2.5 -- seconds (normal enemies)
Config.BossRespawn = 25 -- seconds
Config.StageSleepTime = 30 -- despawn a stage's enemies after this long with nobody near
Config.EliteChance = 0.04 -- rare golden "Elite" spawn
Config.EliteHPMult = 5
Config.EliteDropMult = 3
Config.BossOreDrops = 6
Config.BossRerollChance = 0.05
Config.EnemyAggroRange = 38
Config.EnemyAttackRange = 6.5
Config.EnemyAttackCooldown = 1.6
Config.EnemyHitPercent = 0.06 -- % of player max HP per hit
Config.BossSlamPercent = 0.22
Config.BossSlamRadius = 18

---------------------------------------------------------------------
-- COMBAT
---------------------------------------------------------------------
Config.BaseDamage = 5
Config.PowerDamageDivisor = 100 -- damage *= 1 + Power / this
Config.BaseCritChance = 0.05
Config.CritMultiplier = 2
Config.PickupRadius = 12 -- ores are picked up with the F prompt within this range
Config.DropLifetime = 90

---------------------------------------------------------------------
-- TRAINING GROUNDS  (multiplier pads unlock with Rebirths / Ascensions)
---------------------------------------------------------------------
Config.TrainPads = {
	{ Mult = 1, Rebirths = 0, Ascensions = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Mult = 3, Rebirths = 1, Ascensions = 0, Color = Color3.fromRGB(90, 230, 120) },
	{ Mult = 10, Rebirths = 3, Ascensions = 0, Color = Color3.fromRGB(70, 165, 255) },
	{ Mult = 40, Rebirths = 6, Ascensions = 0, Color = Color3.fromRGB(185, 95, 255) },
	{ Mult = 150, Rebirths = 10, Ascensions = 0, Color = Color3.fromRGB(255, 195, 45) },
	{ Mult = 1000, Rebirths = 0, Ascensions = 1, Color = Color3.fromRGB(255, 110, 70) },
	{ Mult = 8000, Rebirths = 0, Ascensions = 2, Color = Color3.fromRGB(255, 70, 125) },
	{ Mult = 75000, Rebirths = 0, Ascensions = 4, Color = Color3.fromRGB(0, 255, 225) },
	{ Mult = 1e6, Rebirths = 0, Ascensions = 7, Color = Color3.fromRGB(255, 255, 255) },
}
Config.TrainPadRadius = 8
Config.AutoTrainPerSecond = 1 -- * pad multiplier, while standing on a pad
Config.ClickPower = 1 -- * pad multiplier, per swing

---------------------------------------------------------------------
-- COIN UPGRADES  (infinite levels: linear price up to level 50, then exponential)
---------------------------------------------------------------------
Config.Upgrades = {
	Backpack = { Name = "Ore Bag", Desc = "+1 ore slot", Base = 25, Step = 15, Growth = 1.12, Per = 1 },
	Luck = { Name = "Luck", Desc = "+4% rare ore luck", Base = 60, Step = 30, Growth = 1.13, Per = 0.04 },
	Training = { Name = "Training", Desc = "+15% Power per swing", Base = 40, Step = 25, Growth = 1.14, Per = 0.15 },
}
Config.UpgradeOrder = { "Backpack", "Luck", "Training" }
Config.UpgradeLinearUntil = 50
Config.BaseBackpack = 3

function Config.UpgradeCost(key: string, level: number): number
	local u = Config.Upgrades[key]
	local L = Config.UpgradeLinearUntil
	if level < L then
		return math.floor(u.Base + u.Step * level)
	end
	return math.floor((u.Base + u.Step * L) * u.Growth ^ (level - L))
end

---------------------------------------------------------------------
-- REBIRTH + ASCENSION  (both multiply, so progress compounds)
---------------------------------------------------------------------
Config.Rebirth = {
	BasePower = 1000,
	PowerGrowth = 3.2, -- each rebirth costs 3.2x more Power
	AscensionCostMult = 25, -- each ascension makes rebirths 25x pricier
	PowerMult = 1.65, -- x1.65 Power gain per rebirth (compounding)
	CoinMult = 1.3, -- x1.3 Coins per rebirth
	RerollReward = 1,
}
Config.Ascension = {
	BaseRebirths = 10, -- rebirths needed for the first ascension
	RebirthStep = 5, -- +5 more for each ascension after that
	PowerMult = 8, -- x8 Power gain per ascension
	CoinMult = 4, -- x4 Coins per ascension
	Rerolls = 3,
	Catalyst = "Legendary", -- bonus forge catalyst per ascension
}
Config.AscensionAuras = { -- cosmetic aura by rebirth count (plus a ring per ascension)
	{ Rebirths = 1, Color = Color3.fromRGB(120, 200, 255) },
	{ Rebirths = 5, Color = Color3.fromRGB(185, 95, 255) },
	{ Rebirths = 15, Color = Color3.fromRGB(255, 195, 45) },
	{ Rebirths = 40, Color = Color3.fromRGB(255, 70, 125) },
	{ Rebirths = 100, Color = Color3.fromRGB(0, 255, 225) },
}

function Config.RebirthReq(rebirths: number, ascensions: number): number
	local R = Config.Rebirth
	return math.floor(R.BasePower * R.PowerGrowth ^ rebirths * R.AscensionCostMult ^ ascensions)
end

function Config.AscendReq(ascensions: number): number
	return Config.Ascension.BaseRebirths + Config.Ascension.RebirthStep * ascensions
end

---------------------------------------------------------------------
-- FORGE LEVEL VISUAL TIERS
---------------------------------------------------------------------
Config.BladeTiers = {
	{ Level = 0, Name = "Plain Steel", Blade = Color3.fromRGB(200, 205, 215), Edge = nil },
	{ Level = 10, Name = "Engraved", Blade = Color3.fromRGB(215, 220, 230), Edge = Color3.fromRGB(255, 215, 120) },
	{ Level = 50, Name = "Glowing", Blade = Color3.fromRGB(190, 230, 255), Edge = Color3.fromRGB(80, 200, 255) },
	{ Level = 250, Name = "Elemental", Blade = Color3.fromRGB(255, 180, 120), Edge = Color3.fromRGB(255, 120, 30) },
	{ Level = 1000, Name = "Spirit", Blade = Color3.fromRGB(200, 160, 255), Edge = Color3.fromRGB(170, 80, 255) },
	{ Level = 5000, Name = "Awakened", Blade = Color3.fromRGB(255, 190, 220), Edge = Color3.fromRGB(255, 90, 170) },
	{ Level = 25000, Name = "Radiant", Blade = Color3.fromRGB(255, 240, 170), Edge = Color3.fromRGB(255, 200, 40) },
	{ Level = 100000, Name = "Celestial", Blade = Color3.fromRGB(230, 245, 255), Edge = Color3.fromRGB(150, 220, 255) },
	{ Level = 1000000, Name = "Rift", Blade = Color3.fromRGB(30, 40, 50), Edge = Color3.fromRGB(0, 255, 225) },
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
-- BOSS RUSH  (endless bosses back to back; each boss adds a timer)
---------------------------------------------------------------------
Config.BossRush = {
	StageReq = 5, -- clear stage 5 (the first boss) to enter
	TimePerBoss = 45,
	BaseHP = 2500,
	HPGrowth = 1.55,
	CoinBase = 80,
	CoinGrowth = 1.45,
	RunesPerBoss = 1,
	RuneDamageBonus = 0.02, -- each rune = +2% damage, permanent
	Break = 2.5, -- seconds between bosses
	DoubleEvery = 5, -- every 5th wave spawns two bosses
	CatalystEvery = 10, -- every 10th wave also drops a Rare+ catalyst
}

---------------------------------------------------------------------
-- MONETIZATION  (put your real IDs in!  0 = not set up yet)
---------------------------------------------------------------------
Config.GamePasses = {
	DoubleCoins = { Id = 0, Name = "2x Coins", Desc = "Doubles all Coin earnings." },
	DoubleLuck = { Id = 0, Name = "2x Luck", Desc = "Doubles rare ore odds and nudges rare race odds." },
	AutoSell = { Id = 0, Name = "Auto-Sell", Desc = "When your ore bag is full, new ore sells instantly." },
	AutoCollect = { Id = 0, Name = "Auto-Collect", Desc = "Ore flies straight into your bag (no pickup needed)." },
	ExtraBackpack = { Id = 0, Name = "Bigger Bag", Desc = "+50% ore bag capacity." },
	DoubleOverdrive = { Id = 0, Name = "2x Overdrive", Desc = "Transformations last twice as long." },
	FastTravel = { Id = 0, Name = "Fast Travel", Desc = "Teleport to any stage you have reached." },
	ChromaTrail = { Id = 0, Name = "Chroma Trail", Desc = "Rainbow trail while you move. Pure flex." },
	MCPity = { Id = 0, Name = "Main Character Boost", Desc = "Slightly raises Main Character odds (never guaranteed)." },
	DoubleTraining = { Id = 0, Name = "2x Training", Desc = "Doubles Power from every swing." },
}
Config.GamePassOrder = { "DoubleCoins", "DoubleLuck", "AutoSell", "AutoCollect", "ExtraBackpack", "DoubleOverdrive", "FastTravel", "ChromaTrail", "MCPity", "DoubleTraining" }

Config.Products = {
	StarterPack = { Id = 0, Name = "Starter Pack", Desc = "5K Coins + 3 Rerolls + 2 Overdrive (one time)", Coins = 5000, Rerolls = 3, Overdrive = 2, OneTime = true },
	Reroll5 = { Id = 0, Name = "5 Race Rerolls", Rerolls = 5 },
	Reroll10 = { Id = 0, Name = "10 Race Rerolls", Rerolls = 10 },
	Reroll25 = { Id = 0, Name = "25 Race Rerolls", Rerolls = 25 },
	Overdrive3 = { Id = 0, Name = "3 Overdrive Potions", Overdrive = 3 },
	Overdrive10 = { Id = 0, Name = "10 Overdrive Potions", Overdrive = 10 },
	CoinsS = { Id = 0, Name = "Coin Pouch S", Coins = 1000, ScaleWithRebirth = true },
	CoinsM = { Id = 0, Name = "Coin Pouch M", Coins = 12000, ScaleWithRebirth = true },
	CoinsL = { Id = 0, Name = "Coin Pouch L", Coins = 150000, ScaleWithRebirth = true },
	CoinsXL = { Id = 0, Name = "Coin Pouch XL", Coins = 2000000, ScaleWithRebirth = true },
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
	Path = 0,
	BossRush = 0,
}
-- Override any sound source with your own asset, e.g. Slash = "rbxassetid://123".
Config.SoundOverrides = {}

---------------------------------------------------------------------
-- PROXIMITY PROMPTS (custom-styled; see Client/PromptUI)
---------------------------------------------------------------------
Config.Prompt = {
	MaxActivationDistance = 10,
	-- Line-of-sight is off by default because several prompts live on parts
	-- that sit inside other geometry.
	RequiresLineOfSight = false,
}

---------------------------------------------------------------------
-- CLEAN SCREEN: world text + contextual HUD
---------------------------------------------------------------------
Config.WorldText = {
	ShowDistance = 10, -- fully visible inside this distance (studs)
	FadeBand = 5, -- starts fading in this many studs further out
	VerticalSlack = 8, -- labels high above a part still count as "near"
	FontScale = 0.55,
	NametagRadius = 26,
}

Config.Hud = {
	CombatLinger = 5,
	DamageLinger = 4,
	StaminaLinger = 2.5,
	ResourceLinger = 3.5,
	LowHealth = 0.3,
	PlaytimeHeadsUp = 45,
}

---------------------------------------------------------------------
-- MOVEMENT + CAMERA FEEL
---------------------------------------------------------------------
Config.Sprint = {
	SpeedMult = 1.4, -- Left Shift / L3
	FovBoost = 9,
}
Config.Camera = {
	FramingWeight = 0.22,
	FramingPullBack = 2.5,
	FramingFov = -3,
}

---------------------------------------------------------------------
-- GRAPHICS  (Lighting.Technology = Future is set in the place file)
---------------------------------------------------------------------
-- A little darker than before: late-dusk sun, lower exposure, deeper
-- ambient. Brighten by raising ClockTime toward 15 / Exposure toward 0.
Config.Graphics = {
	ClockTime = 17.45,
	Brightness = 2.1,
	Exposure = -0.25,
	Ambient = Color3.fromRGB(54, 48, 72),
	OutdoorAmbient = Color3.fromRGB(92, 82, 118),
	Atmosphere = { Density = 0.38, Haze = 2.6, Offset = 0.12, Glare = 0.5, Color = Color3.fromRGB(170, 150, 205), Decay = Color3.fromRGB(80, 64, 120) },
	Bloom = { Threshold = 0.75, Size = 28, Intensity = 0.55 },
	ColorCorrection = { Contrast = 0.22, Saturation = 0.2, Brightness = -0.04 },
	SunRays = { Intensity = 0.16, Spread = 0.8 },
	MenuDepthOfField = { FarIntensity = 0.75, FocusDistance = 6, InFocusRadius = 8, NearIntensity = 0.4 },
	MaterialVariants = {
		-- Slate = { ColorMap = "rbxassetid://0", NormalMap = "rbxassetid://0", RoughnessMap = "rbxassetid://0", MetalnessMap = "rbxassetid://0" },
	},
}

---------------------------------------------------------------------
-- GLOBAL CLASS BALANCE (the "nerf pass")
---------------------------------------------------------------------
Config.Balance = {
	CooldownMult = 1.25,
	StaminaCostMult = 1.3,
	MaxStamina = 100,
	StaminaRegen = 12,
	StaminaRegenDelay = 1.1,
	DashDistanceSpeed = 70,
	DashDuration = 0.16,
	DashCooldown = 1.4,
	DashStamina = 18,
	DashIFrames = 0.18,
	MaxStun = 1.2,
	PlayerStunCap = 0.5,
	DamageMultCap = 40, -- hard cap on combined gameplay damage multipliers
	CritMultCap = 2.5,
	AttackSpeedCap = 0.5,
	DefenseCap = 0.75, -- armour damage reduction cap
}
Config.NinjaDodgeTime = 0.6
Config.PlotArmorIFrames = 0.8

---------------------------------------------------------------------
-- WEAPON RARITY
---------------------------------------------------------------------
Config.WeaponRarities = {
	{ Id = "Common", Color = Color3.fromRGB(165, 170, 180), Chance = 50, Damage = 0.05, AttackSpeed = 0, Scrap = 25 },
	{ Id = "Uncommon", Color = Color3.fromRGB(85, 225, 110), Chance = 30, Damage = 0.15, AttackSpeed = 0, Scrap = 75 },
	{ Id = "Rare", Color = Color3.fromRGB(70, 160, 255), Chance = 13, Damage = 0.35, AttackSpeed = 0.05, Scrap = 300 },
	{ Id = "Epic", Color = Color3.fromRGB(175, 90, 255), Chance = 5, Damage = 0.75, AttackSpeed = 0.05, Trail = true, Scrap = 1200 },
	{ Id = "Legendary", Color = Color3.fromRGB(255, 195, 45), Chance = 1.8, Damage = 1.5, AttackSpeed = 0.05, Trail = true, Passive = true, Scrap = 6000 },
	{ Id = "Mythic", Label = "Mythic / Celestial", Color = Color3.fromRGB(255, 50, 70), Chance = 0.2, Damage = 3.0, AttackSpeed = 0.05, Trail = true, Passive = true, Aura = true, Signature = true, Rainbow = true, Scrap = 30000 },
}
Config.WeaponRarityById = {}
for i, r in ipairs(Config.WeaponRarities) do
	r.Index = i
	Config.WeaponRarityById[r.Id] = r
end
Config.MaxWeapons = 60

---------------------------------------------------------------------
-- WEAPON CLASSES (basic attack = LMB)  -- 16 types
---------------------------------------------------------------------
-- Kind: Melee uses a cone in front of you. Ranged fires server projectiles
-- (Multi = projectiles per shot, Explode = blast radius).
Config.WeaponClasses = {
	Katana = { Kind = "Melee", Range = 10, Arc = 0.2, Interval = 0.42, Combo = { 1.0, 1.1, 1.5 }, Base = 1.0, Ultimate = "ThousandCuts" },
	Greatsword = { Kind = "Melee", Range = 12.5, Arc = 0.05, Interval = 0.62, Combo = { 1.25, 1.25, 1.45, 2.2 }, Base = 1.1, Ultimate = "Earthsplitter" },
	Pistols = { Kind = "Ranged", Range = 95, Interval = 0.3, Combo = { 0.55, 0.55 }, Base = 1.0, Speed = 260, Radius = 1.6, Projectile = "Ray", Ultimate = "BulletStorm" },
	Glove = { Kind = "Melee", Range = 8, Arc = 0.3, Interval = 0.34, Combo = { 0.8, 0.8, 1.35 }, Base = 0.95, Ultimate = "HundredFists" },
	FingerGun = { Kind = "Ranged", Range = 85, Interval = 0.4, Combo = { 0.75 }, Base = 1.0, Speed = 210, Radius = 2, Projectile = "Orb", Ultimate = "SpiritRain" },
	Scythe = { Kind = "Melee", Range = 13.5, Arc = -0.35, Interval = 0.55, Combo = { 1.1, 1.1, 1.7 }, Base = 1.05, Ultimate = "DeathSpiral" },
	Spear = { Kind = "Melee", Range = 15, Arc = 0.6, Interval = 0.5, Combo = { 1.0, 1.1, 1.6 }, Base = 1.05, Ultimate = "DragonGate" },
	Daggers = { Kind = "Melee", Range = 7.5, Arc = 0.1, Interval = 0.24, Combo = { 0.6, 0.6, 0.6, 1.2 }, Base = 0.9, Ultimate = "ThousandCuts" },
	Hammer = { Kind = "Melee", Range = 11, Arc = -0.2, Interval = 0.8, Combo = { 1.6, 1.6, 2.6 }, Base = 1.15, Knockback = 30, Ultimate = "Earthsplitter" },
	Bow = { Kind = "Ranged", Range = 120, Interval = 0.55, Combo = { 1.1, 1.1, 1.8 }, Base = 1.0, Speed = 250, Radius = 1.5, Projectile = "Arrow", Ultimate = "ArrowStorm" },
	Staff = { Kind = "Ranged", Range = 80, Interval = 0.6, Combo = { 1.2 }, Base = 1.05, Speed = 150, Radius = 3, Projectile = "Orb", Explode = 7, Ultimate = "SpiritRain" },
	Chain = { Kind = "Melee", Range = 16, Arc = -0.1, Interval = 0.5, Combo = { 0.9, 0.9, 1.4 }, Base = 1.0, Ultimate = "DeathSpiral" },
	Claws = { Kind = "Melee", Range = 8, Arc = 0.15, Interval = 0.28, Combo = { 0.7, 0.7, 0.7, 1.3 }, Base = 0.95, Ultimate = "HundredFists" },
	Fan = { Kind = "Melee", Range = 15, Arc = -0.5, Interval = 0.55, Combo = { 0.9, 1.0, 1.4 }, Base = 0.95, Knockback = 25, Ultimate = "TyphoonDance" },
	Kunai = { Kind = "Ranged", Range = 90, Interval = 0.34, Combo = { 0.45 }, Base = 0.95, Speed = 230, Radius = 1.4, Projectile = "Kunai", Multi = 3, Ultimate = "BulletStorm" },
	Cannon = { Kind = "Ranged", Range = 100, Interval = 0.9, Combo = { 2.2 }, Base = 1.1, Speed = 160, Radius = 3.5, Projectile = "Cero", Explode = 10, Ultimate = "OrbitalStrike" },
}
Config.ClassOrder = { "Katana", "Greatsword", "Pistols", "Glove", "FingerGun", "Scythe", "Spear", "Daggers", "Hammer", "Bow", "Staff", "Chain", "Claws", "Fan", "Kunai", "Cannon" }

---------------------------------------------------------------------
-- SKILLS (E = weapon skill, R = class ultimate). Cooldown / Stamina are the
-- BASE values; Config.Balance multipliers are applied on top.
---------------------------------------------------------------------
-- Types: Cone, Nova, Projectile, Barrage, DashStrike, ChargeLunge, Zone, Rain
Config.Skills = {
	-- class skills
	IaidoDash = { Name = "Iaido Dash", Type = "DashStrike", Cooldown = 5, Stamina = 25, Damage = 2.5, Distance = 24, Width = 6, Color = Color3.fromRGB(200, 230, 255) },
	GroundCleave = { Name = "Ground Cleave", Type = "Cone", Cooldown = 6, Stamina = 28, Damage = 2.8, Range = 15, Arc = -0.1, Knockback = 45, Color = Color3.fromRGB(255, 190, 120) },
	BurstFire = { Name = "Burst Fire", Type = "Barrage", Cooldown = 5.5, Stamina = 25, Damage = 0.7, Count = 6, Duration = 0.45, Spread = 6, Speed = 280, Range = 95, Radius = 1.6, Projectile = "Ray", Color = Color3.fromRGB(255, 220, 120) },
	ChakraPalm = { Name = "Chakra Palm", Type = "DashStrike", Cooldown = 5, Stamina = 25, Damage = 2.6, Distance = 14, Width = 6, Knockback = 60, Color = Color3.fromRGB(120, 200, 255) },
	ChargedShot = { Name = "Charged Shot", Type = "Projectile", Charge = 1.2, Cooldown = 6, Stamina = 28, Damage = 2.4, ChargeBonus = 1.5, Speed = 180, Range = 100, Radius = 3.5, Pierce = true, Projectile = "Orb", Size = 2.5, Color = Color3.fromRGB(120, 230, 255) },
	Reap = { Name = "Reap", Type = "Nova", Cooldown = 6.5, Stamina = 28, Damage = 2.2, Radius = 16, Pull = true, Color = Color3.fromRGB(150, 90, 220) },
	DragonPierce = { Name = "Dragon Pierce", Type = "DashStrike", Cooldown = 5.5, Stamina = 26, Damage = 3.0, Distance = 28, Width = 5, Color = Color3.fromRGB(140, 220, 255) },
	ShadowFlurry = { Name = "Shadow Flurry", Type = "Cone", Cooldown = 5, Stamina = 24, Damage = 0.8, Hits = 5, Interval = 0.07, Range = 9, Arc = 0, Color = Color3.fromRGB(190, 120, 255) },
	QuakeSmash = { Name = "Quake Smash", Type = "Nova", Cooldown = 7, Stamina = 30, Damage = 3.5, Radius = 17, Stun = 0.6, Knockback = 50, Color = Color3.fromRGB(255, 200, 120) },
	PiercingArrow = { Name = "Piercing Arrow", Type = "Projectile", Charge = 1.0, Cooldown = 6, Stamina = 26, Damage = 3, ChargeBonus = 1.5, Speed = 300, Range = 160, Radius = 3, Pierce = true, Projectile = "Arrow", Size = 3, Color = Color3.fromRGB(180, 255, 220) },
	MeteorCall = { Name = "Meteor Call", Type = "Rain", Cooldown = 7, Stamina = 30, Damage = 1.6, Hits = 5, Interval = 0.18, Radius = 12, Range = 60, Color = Color3.fromRGB(255, 150, 70) },
	SerpentLash = { Name = "Serpent Lash", Type = "Cone", Cooldown = 5.5, Stamina = 26, Damage = 2.8, Range = 22, Arc = -0.3, PullIn = true, Color = Color3.fromRGB(255, 240, 120) },
	BeastRend = { Name = "Beast Rend", Type = "DashStrike", Cooldown = 5, Stamina = 25, Damage = 2.8, Distance = 18, Width = 6, Color = Color3.fromRGB(255, 120, 80) },
	GaleWall = { Name = "Gale Wall", Type = "Cone", Cooldown = 6, Stamina = 26, Damage = 2.2, Range = 20, Arc = -0.4, Knockback = 90, Color = Color3.fromRGB(170, 255, 220) },
	KunaiFan = { Name = "Kunai Fan", Type = "Barrage", Cooldown = 5.5, Stamina = 26, Damage = 0.6, Count = 12, Duration = 0.35, Spread = 70, Speed = 240, Range = 90, Radius = 1.6, Projectile = "Kunai", Color = Color3.fromRGB(230, 230, 255) },
	MegaBuster = { Name = "Mega Buster", Type = "Projectile", Charge = 1.6, Cooldown = 8, Stamina = 36, Damage = 5, ChargeBonus = 2, Speed = 170, Range = 120, Radius = 5, Pierce = true, Explode = 16, Projectile = "Cero", Size = 5, Color = Color3.fromRGB(120, 255, 255) },

	-- signature / iconic skills
	GetsugaTensho = { Name = "Getsuga Tensho", Type = "Projectile", Cooldown = 7, Stamina = 35, Damage = 4.2, Speed = 130, Range = 130, Radius = 7, Pierce = true, Projectile = "Crescent", Size = 14, Color = Color3.fromRGB(80, 170, 255) },
	CeroMetralleta = { Name = "Cero Metralleta", Type = "Barrage", Cooldown = 9, Stamina = 40, Damage = 0.6, Count = 26, Duration = 1.3, Spread = 35, Speed = 230, Range = 100, Radius = 2.4, Projectile = "Cero", Color = Color3.fromRGB(90, 180, 255) },
	Rasengan = { Name = "Rasengan", Type = "ChargeLunge", Charge = 1.5, Cooldown = 10, Stamina = 40, Damage = 3.2, ChargeBonus = 2, Distance = 20, Width = 6, Knockback = 110, Ragdoll = 1.2, Ticks = { Count = 5, Interval = 0.2, Damage = 0.4 }, Color = Color3.fromRGB(110, 200, 255) },
	HellDragon = { Name = "Hell Dragon", Type = "DashStrike", Cooldown = 6.5, Stamina = 32, Damage = 3.6, Distance = 30, Width = 9, Burn = true, Color = Color3.fromRGB(190, 80, 255) },
	BlackBladeRush = { Name = "Black Blade Rush", Type = "DashStrike", Cooldown = 6, Stamina = 30, Damage = 3.2, Distance = 26, Width = 7, Color = Color3.fromRGB(255, 70, 90) },
	SpiritGun = { Name = "Spirit Gun", Type = "Projectile", Charge = 1.4, Cooldown = 8, Stamina = 38, Damage = 5, ChargeBonus = 1.5, Speed = 200, Range = 140, Radius = 5, Pierce = true, Explode = 12, Projectile = "Orb", Size = 4.5, Color = Color3.fromRGB(80, 220, 255) },
	DimensionalRift = { Name = "Dimensional Rift", Type = "Zone", Cooldown = 10, Stamina = 40, Damage = 0.55, Ticks = 8, Interval = 0.35, Radius = 14, Range = 45, Pull = true, Color = Color3.fromRGB(170, 60, 255) },
	VoidHarvest = { Name = "Void Harvest", Type = "Nova", Cooldown = 7, Stamina = 32, Damage = 3, Radius = 18, Pull = true, Color = Color3.fromRGB(120, 40, 200) },
	StormCleave = { Name = "Storm Cleave", Type = "Cone", Cooldown = 6.5, Stamina = 32, Damage = 3.4, Range = 18, Arc = -0.2, Knockback = 60, Color = Color3.fromRGB(120, 220, 255) },
	HeavenlyLance = { Name = "Heavenly Lance", Type = "DashStrike", Cooldown = 6.5, Stamina = 32, Damage = 4, Distance = 36, Width = 8, Burn = true, Color = Color3.fromRGB(255, 230, 140) },
	TwinMoonDance = { Name = "Twin Moon Dance", Type = "Nova", Cooldown = 7, Stamina = 30, Damage = 0.9, Hits = 6, Interval = 0.1, Radius = 12, Color = Color3.fromRGB(220, 220, 255) },
	OniKingSlam = { Name = "Oni King Slam", Type = "Nova", Cooldown = 8, Stamina = 36, Damage = 6, Radius = 22, Stun = 0.9, Knockback = 80, Color = Color3.fromRGB(255, 90, 60) },
	LunarVolley = { Name = "Lunar Volley", Type = "Barrage", Cooldown = 7, Stamina = 32, Damage = 1.1, Count = 9, Duration = 0.6, Spread = 25, Speed = 280, Range = 140, Radius = 2, Projectile = "Arrow", Color = Color3.fromRGB(210, 230, 255) },
	SageJudgement = { Name = "Sage's Judgement", Type = "Zone", Cooldown = 9, Stamina = 38, Damage = 0.8, Ticks = 8, Interval = 0.3, Radius = 15, Range = 60, Color = Color3.fromRGB(255, 220, 120) },
	JudgmentChain = { Name = "Judgment Chain", Type = "Cone", Cooldown = 7, Stamina = 32, Damage = 1.2, Hits = 4, Interval = 0.12, Range = 24, Arc = -0.2, PullIn = true, Stun = 0.5, Color = Color3.fromRGB(255, 240, 140) },
	NineTailsRush = { Name = "Nine-Tails Rush", Type = "ChargeLunge", Charge = 1.2, Cooldown = 9, Stamina = 38, Damage = 4, ChargeBonus = 1.5, Distance = 26, Width = 8, Knockback = 90, Ragdoll = 1, Color = Color3.fromRGB(255, 140, 50) },
	GreatWindScythe = { Name = "Great Wind Scythe", Type = "Projectile", Cooldown = 7, Stamina = 32, Damage = 3.8, Speed = 120, Range = 110, Radius = 9, Pierce = true, Projectile = "Crescent", Size = 16, Color = Color3.fromRGB(180, 255, 230) },
	FlyingThunderGod = { Name = "Flying Thunder God", Type = "DashStrike", Cooldown = 5, Stamina = 28, Damage = 3.8, Distance = 40, Width = 7, Color = Color3.fromRGB(255, 240, 100) },
	PsychoBlast = { Name = "Psycho Blast", Type = "Projectile", Charge = 1.4, Cooldown = 8, Stamina = 38, Damage = 6, ChargeBonus = 2, Speed = 190, Range = 150, Radius = 6, Pierce = true, Explode = 20, Projectile = "Cero", Size = 6, Color = Color3.fromRGB(255, 120, 255) },

	-- class ultimates (R)
	ThousandCuts = { Name = "Thousand Cuts", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 0.9, Hits = 6, Interval = 0.12, Radius = 14, Color = Color3.fromRGB(230, 240, 255) },
	Earthsplitter = { Name = "Earthsplitter", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 6, Radius = 20, Knockback = 80, Stun = 0.8, Color = Color3.fromRGB(255, 160, 80) },
	BulletStorm = { Name = "Bullet Storm", Type = "Barrage", Cooldown = 16, Stamina = 55, Damage = 0.5, Count = 36, Duration = 1.2, Spread = 360, Speed = 220, Range = 60, Radius = 2, Projectile = "Ray", Color = Color3.fromRGB(255, 230, 120) },
	HundredFists = { Name = "Hundred Fists", Type = "Cone", Cooldown = 15, Stamina = 55, Damage = 0.55, Hits = 10, Interval = 0.08, Range = 11, Arc = 0.2, Color = Color3.fromRGB(255, 200, 120) },
	SpiritRain = { Name = "Spirit Rain", Type = "Rain", Cooldown = 16, Stamina = 55, Damage = 1.4, Hits = 10, Interval = 0.12, Radius = 16, Range = 60, Color = Color3.fromRGB(100, 220, 255) },
	DeathSpiral = { Name = "Death Spiral", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 0.8, Hits = 8, Interval = 0.15, Radius = 16, Pull = true, Color = Color3.fromRGB(160, 80, 255) },
	DragonGate = { Name = "Dragon Gate", Type = "DashStrike", Cooldown = 15, Stamina = 55, Damage = 6.5, Distance = 42, Width = 12, Knockback = 70, Color = Color3.fromRGB(120, 200, 255) },
	ArrowStorm = { Name = "Arrow Storm", Type = "Rain", Cooldown = 16, Stamina = 55, Damage = 1.2, Hits = 16, Interval = 0.08, Radius = 18, Range = 90, Color = Color3.fromRGB(190, 255, 210) },
	TyphoonDance = { Name = "Typhoon Dance", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 0.9, Hits = 6, Interval = 0.15, Radius = 18, Pull = true, Color = Color3.fromRGB(170, 255, 230) },
	OrbitalStrike = { Name = "Orbital Strike", Type = "Rain", Cooldown = 18, Stamina = 60, Damage = 3.2, Hits = 6, Interval = 0.2, Radius = 14, Range = 80, Color = Color3.fromRGB(120, 255, 255) },
}

---------------------------------------------------------------------
-- WEAPONS  (names of iconic weapons live here - rename freely)
---------------------------------------------------------------------
-- Rarity = the tier this weapon usually forges at. Recipe = only obtainable
-- from its unique ore combination (see Config.Recipes).
local W = {}
local function weapon(t)
	table.insert(W, t)
end
local c = Color3.fromRGB
-- Katana
weapon({ Id = "TrainingKatana", Name = "Training Katana", Class = "Katana", Rarity = "Common", Skill = "IaidoDash", Blade = c(200, 205, 215), Accent = c(120, 90, 60) })
weapon({ Id = "SteelKatana", Name = "Steel Katana", Class = "Katana", Rarity = "Uncommon", Skill = "IaidoDash", Blade = c(220, 225, 235), Accent = c(60, 60, 70) })
weapon({ Id = "CrimsonKatana", Name = "Crimson Katana", Class = "Katana", Rarity = "Rare", Skill = "IaidoDash", Blade = c(230, 90, 90), Accent = c(40, 20, 25), Glow = c(255, 80, 80) })
weapon({ Id = "Shusui", Name = "Shusui", Class = "Katana", Rarity = "Epic", Skill = "BlackBladeRush", Blade = c(25, 20, 25), Accent = c(150, 20, 30), Glow = c(255, 60, 80), Recipe = true })
weapon({ Id = "Enma", Name = "Enma", Class = "Katana", Rarity = "Legendary", Skill = "HellDragon", Blade = c(235, 230, 245), Accent = c(90, 30, 140), Glow = c(190, 80, 255), Recipe = true, Passive = { Id = "Hellfire", Name = "Hellfire Edge", Desc = "20% chance on hit to burn (3 ticks of 30% damage)." } })
-- Greatsword
weapon({ Id = "RustyGreatsword", Name = "Rusty Greatsword", Class = "Greatsword", Rarity = "Common", Skill = "GroundCleave", Blade = c(150, 110, 90), Accent = c(90, 70, 60) })
weapon({ Id = "IronCleaver", Name = "Iron Cleaver", Class = "Greatsword", Rarity = "Uncommon", Skill = "GroundCleave", Blade = c(170, 175, 185), Accent = c(70, 70, 80) })
weapon({ Id = "StoneBuster", Name = "Stone Buster", Class = "Greatsword", Rarity = "Rare", Skill = "GroundCleave", Blade = c(140, 130, 120), Accent = c(255, 170, 60), Glow = c(255, 170, 60) })
weapon({ Id = "StormCleaver", Name = "Storm Cleaver", Class = "Greatsword", Rarity = "Epic", Skill = "StormCleave", Blade = c(190, 225, 255), Accent = c(60, 80, 140), Glow = c(120, 220, 255) })
weapon({ Id = "Zangetsu", Name = "Zangetsu", Class = "Greatsword", Rarity = "Mythic", Skill = "GetsugaTensho", Blade = c(25, 25, 30), Accent = c(230, 230, 240), Glow = c(80, 170, 255), Recipe = true, Passive = { Id = "Released", Name = "Released Spirit", Desc = "+15% attack speed and Getsuga cooldown -20%." } })
-- Pistols
weapon({ Id = "CapPistols", Name = "Cap Pistols", Class = "Pistols", Rarity = "Common", Skill = "BurstFire", Blade = c(90, 90, 100), Accent = c(200, 180, 120) })
weapon({ Id = "TwinRevolvers", Name = "Twin Revolvers", Class = "Pistols", Rarity = "Uncommon", Skill = "BurstFire", Blade = c(60, 60, 70), Accent = c(190, 150, 90) })
weapon({ Id = "PlasmaPistols", Name = "Plasma Pistols", Class = "Pistols", Rarity = "Rare", Skill = "BurstFire", Blade = c(40, 45, 60), Accent = c(0, 230, 255), Glow = c(0, 230, 255) })
weapon({ Id = "StarrkGuns", Name = "Starrk's Guns", Class = "Pistols", Rarity = "Mythic", Skill = "CeroMetralleta", Blade = c(220, 225, 235), Accent = c(90, 180, 255), Glow = c(90, 180, 255), Recipe = true, Passive = { Id = "LoneWolf", Name = "Lone Wolf", Desc = "Basic shots pierce one extra enemy." } })
-- Glove
weapon({ Id = "WrappedFists", Name = "Wrapped Fists", Class = "Glove", Rarity = "Common", Skill = "ChakraPalm", Blade = c(230, 220, 200), Accent = c(180, 160, 130) })
weapon({ Id = "IronKnuckles", Name = "Iron Knuckles", Class = "Glove", Rarity = "Uncommon", Skill = "ChakraPalm", Blade = c(150, 155, 165), Accent = c(90, 90, 100) })
weapon({ Id = "ChakraGloves", Name = "Chakra Gloves", Class = "Glove", Rarity = "Rare", Skill = "ChakraPalm", Blade = c(40, 60, 110), Accent = c(110, 200, 255), Glow = c(110, 200, 255) })
weapon({ Id = "Rasengan", Name = "Rasengan", Class = "Glove", Rarity = "Legendary", Skill = "Rasengan", Blade = c(40, 70, 140), Accent = c(110, 200, 255), Glow = c(110, 200, 255), Recipe = true, Passive = { Id = "ChakraFlow", Name = "Chakra Flow", Desc = "All abilities cost 20% less stamina." } })
-- Finger gun
weapon({ Id = "SpiritFinger", Name = "Spirit Finger", Class = "FingerGun", Rarity = "Rare", Skill = "ChargedShot", Blade = c(120, 230, 255), Accent = c(120, 230, 255), Glow = c(120, 230, 255) })
weapon({ Id = "SpiritGun", Name = "Spirit Gun", Class = "FingerGun", Rarity = "Epic", Skill = "SpiritGun", Blade = c(80, 220, 255), Accent = c(80, 220, 255), Glow = c(80, 220, 255), Recipe = true })
-- Scythe
weapon({ Id = "FarmScythe", Name = "Farm Scythe", Class = "Scythe", Rarity = "Common", Skill = "Reap", Blade = c(180, 180, 190), Accent = c(120, 85, 55) })
weapon({ Id = "ReaperSickle", Name = "Reaper's Sickle", Class = "Scythe", Rarity = "Uncommon", Skill = "Reap", Blade = c(200, 200, 215), Accent = c(50, 40, 50) })
weapon({ Id = "MoonScythe", Name = "Moon Scythe", Class = "Scythe", Rarity = "Rare", Skill = "Reap", Blade = c(200, 220, 255), Accent = c(40, 40, 70), Glow = c(170, 200, 255) })
weapon({ Id = "VoidReaper", Name = "Void Reaper", Class = "Scythe", Rarity = "Epic", Skill = "VoidHarvest", Blade = c(40, 20, 60), Accent = c(150, 60, 255), Glow = c(150, 60, 255) })
weapon({ Id = "DimensionalScythe", Name = "Dimensional Scythe", Class = "Scythe", Rarity = "Legendary", Skill = "DimensionalRift", Blade = c(20, 10, 40), Accent = c(170, 60, 255), Glow = c(200, 100, 255), Recipe = true, Passive = { Id = "RiftHunger", Name = "Rift Hunger", Desc = "Kills restore 12 stamina." } })
-- Spear
weapon({ Id = "BambooSpear", Name = "Bamboo Spear", Class = "Spear", Rarity = "Common", Skill = "DragonPierce", Blade = c(210, 215, 220), Accent = c(150, 170, 90) })
weapon({ Id = "JadeGlaive", Name = "Jade Glaive", Class = "Spear", Rarity = "Rare", Skill = "DragonPierce", Blade = c(120, 230, 170), Accent = c(40, 70, 50), Glow = c(120, 255, 180) })
weapon({ Id = "FrostfangHalberd", Name = "Frostfang Halberd", Class = "Spear", Rarity = "Epic", Skill = "DragonPierce", Blade = c(190, 235, 255), Accent = c(50, 70, 110), Glow = c(150, 225, 255) })
weapon({ Id = "DragonLance", Name = "Dragon Lance", Class = "Spear", Rarity = "Legendary", Skill = "HeavenlyLance", Blade = c(255, 225, 150), Accent = c(150, 30, 30), Glow = c(255, 200, 90), Recipe = true, Passive = { Id = "DragonBlood", Name = "Dragon Blood", Desc = "Dash skills leave a burning trail." } })
-- Daggers
weapon({ Id = "TwinShivs", Name = "Twin Shivs", Class = "Daggers", Rarity = "Common", Skill = "ShadowFlurry", Blade = c(190, 195, 205), Accent = c(70, 60, 60) })
weapon({ Id = "ViperFangs", Name = "Viper Fangs", Class = "Daggers", Rarity = "Rare", Skill = "ShadowFlurry", Blade = c(130, 220, 110), Accent = c(30, 50, 30), Glow = c(130, 255, 110) })
weapon({ Id = "NightshadeKris", Name = "Nightshade Kris", Class = "Daggers", Rarity = "Epic", Skill = "ShadowFlurry", Blade = c(80, 40, 120), Accent = c(20, 15, 30), Glow = c(190, 110, 255) })
weapon({ Id = "TwinMoons", Name = "Silent Twin Moons", Class = "Daggers", Rarity = "Legendary", Skill = "TwinMoonDance", Blade = c(230, 230, 250), Accent = c(40, 40, 70), Glow = c(210, 220, 255), Recipe = true, Passive = { Id = "Moonlit", Name = "Moonlit", Desc = "+10% crit chance." } })
-- Hammer
weapon({ Id = "StoneMaul", Name = "Stone Maul", Class = "Hammer", Rarity = "Common", Skill = "QuakeSmash", Blade = c(140, 135, 130), Accent = c(110, 80, 55) })
weapon({ Id = "ThunderGavel", Name = "Thunder Gavel", Class = "Hammer", Rarity = "Rare", Skill = "QuakeSmash", Blade = c(170, 180, 200), Accent = c(60, 60, 80), Glow = c(255, 240, 110) })
weapon({ Id = "TitanBreaker", Name = "Titan Breaker", Class = "Hammer", Rarity = "Epic", Skill = "QuakeSmash", Blade = c(90, 80, 75), Accent = c(200, 150, 60), Glow = c(255, 170, 70) })
weapon({ Id = "OniKanabo", Name = "Kanabo of the Oni King", Class = "Hammer", Rarity = "Mythic", Skill = "OniKingSlam", Blade = c(40, 25, 25), Accent = c(200, 40, 40), Glow = c(255, 80, 50), Recipe = true, Passive = { Id = "OniWrath", Name = "Oni Wrath", Desc = "+30% damage to bosses." } })
-- Bow
weapon({ Id = "HunterBow", Name = "Hunter's Bow", Class = "Bow", Rarity = "Common", Skill = "PiercingArrow", Blade = c(150, 110, 70), Accent = c(220, 220, 220) })
weapon({ Id = "GaleLongbow", Name = "Gale Longbow", Class = "Bow", Rarity = "Rare", Skill = "PiercingArrow", Blade = c(110, 170, 140), Accent = c(230, 240, 235), Glow = c(170, 255, 220) })
weapon({ Id = "StarshotBow", Name = "Starshot Bow", Class = "Bow", Rarity = "Epic", Skill = "PiercingArrow", Blade = c(70, 60, 120), Accent = c(230, 220, 255), Glow = c(190, 170, 255) })
weapon({ Id = "MoonYumi", Name = "Yumi of the Moon", Class = "Bow", Rarity = "Legendary", Skill = "LunarVolley", Blade = c(240, 240, 250), Accent = c(60, 70, 110), Glow = c(210, 230, 255), Recipe = true, Passive = { Id = "Moonlit", Name = "Moonlit", Desc = "+10% crit chance." } })
-- Staff
weapon({ Id = "OakStaff", Name = "Oak Staff", Class = "Staff", Rarity = "Common", Skill = "MeteorCall", Blade = c(120, 90, 60), Accent = c(120, 200, 120) })
weapon({ Id = "EmberRod", Name = "Ember Rod", Class = "Staff", Rarity = "Rare", Skill = "MeteorCall", Blade = c(70, 40, 30), Accent = c(255, 120, 40), Glow = c(255, 140, 60) })
weapon({ Id = "ArcaneScepter", Name = "Arcane Scepter", Class = "Staff", Rarity = "Epic", Skill = "MeteorCall", Blade = c(60, 50, 110), Accent = c(200, 170, 255), Glow = c(170, 130, 255) })
weapon({ Id = "SageStaff", Name = "Staff of the Sage King", Class = "Staff", Rarity = "Legendary", Skill = "SageJudgement", Blade = c(240, 230, 200), Accent = c(255, 200, 80), Glow = c(255, 230, 130), Recipe = true, Passive = { Id = "Wisdom", Name = "Wisdom", Desc = "-15% skill cooldowns." } })
-- Chain
weapon({ Id = "IronChain", Name = "Iron Chain", Class = "Chain", Rarity = "Common", Skill = "SerpentLash", Blade = c(150, 150, 160), Accent = c(90, 70, 60) })
weapon({ Id = "SerpentWhip", Name = "Serpent Whip", Class = "Chain", Rarity = "Rare", Skill = "SerpentLash", Blade = c(90, 160, 80), Accent = c(40, 60, 30), Glow = c(150, 255, 120) })
weapon({ Id = "Hellchain", Name = "Hellchain", Class = "Chain", Rarity = "Epic", Skill = "SerpentLash", Blade = c(60, 30, 30), Accent = c(255, 90, 40), Glow = c(255, 110, 50) })
weapon({ Id = "JudgmentChains", Name = "Chains of Judgment", Class = "Chain", Rarity = "Legendary", Skill = "JudgmentChain", Blade = c(240, 220, 150), Accent = c(90, 70, 40), Glow = c(255, 235, 140), Recipe = true, Passive = { Id = "Binding", Name = "Binding", Desc = "Hits have a 15% chance to stun." } })
-- Claws
weapon({ Id = "BoneClaws", Name = "Bone Claws", Class = "Claws", Rarity = "Common", Skill = "BeastRend", Blade = c(235, 225, 205), Accent = c(120, 90, 70) })
weapon({ Id = "TigerTalons", Name = "Tiger Talons", Class = "Claws", Rarity = "Rare", Skill = "BeastRend", Blade = c(255, 170, 60), Accent = c(40, 30, 20), Glow = c(255, 180, 70) })
weapon({ Id = "BeastKingClaws", Name = "Beast King Claws", Class = "Claws", Rarity = "Epic", Skill = "BeastRend", Blade = c(200, 60, 60), Accent = c(40, 20, 20), Glow = c(255, 80, 80) })
weapon({ Id = "NineTailsClaws", Name = "Nine-Tails Claws", Class = "Claws", Rarity = "Mythic", Skill = "NineTailsRush", Blade = c(255, 140, 50), Accent = c(60, 20, 10), Glow = c(255, 150, 60), Recipe = true, Passive = { Id = "Chakra9", Name = "Tailed Beast", Desc = "Kills restore 10 stamina and heal 5% HP." } })
-- Fan
weapon({ Id = "PaperFan", Name = "Paper Fan", Class = "Fan", Rarity = "Common", Skill = "GaleWall", Blade = c(240, 235, 220), Accent = c(180, 60, 60) })
weapon({ Id = "WindFan", Name = "Wind Fan", Class = "Fan", Rarity = "Rare", Skill = "GaleWall", Blade = c(170, 240, 220), Accent = c(40, 90, 80), Glow = c(170, 255, 230) })
weapon({ Id = "TempestFan", Name = "Tempest War Fan", Class = "Fan", Rarity = "Epic", Skill = "GaleWall", Blade = c(90, 110, 160), Accent = c(230, 230, 255), Glow = c(150, 190, 255) })
weapon({ Id = "GreatWindFan", Name = "Great Wind Fan", Class = "Fan", Rarity = "Legendary", Skill = "GreatWindScythe", Blade = c(240, 240, 235), Accent = c(150, 40, 60), Glow = c(190, 255, 230), Recipe = true, Passive = { Id = "Tailwind", Name = "Tailwind", Desc = "+15% move speed." } })
-- Kunai
weapon({ Id = "RustyKunai", Name = "Rusty Kunai", Class = "Kunai", Rarity = "Common", Skill = "KunaiFan", Blade = c(130, 120, 110), Accent = c(60, 50, 50) })
weapon({ Id = "FlashKunai", Name = "Flash Kunai", Class = "Kunai", Rarity = "Rare", Skill = "KunaiFan", Blade = c(220, 230, 240), Accent = c(40, 40, 60), Glow = c(200, 230, 255) })
weapon({ Id = "ThunderKunai", Name = "Thunder Kunai", Class = "Kunai", Rarity = "Epic", Skill = "KunaiFan", Blade = c(255, 240, 120), Accent = c(40, 40, 50), Glow = c(255, 240, 100) })
weapon({ Id = "RaijinKunai", Name = "Flying Raijin Kunai", Class = "Kunai", Rarity = "Legendary", Skill = "FlyingThunderGod", Blade = c(230, 230, 240), Accent = c(40, 40, 50), Glow = c(255, 240, 110), Recipe = true, Passive = { Id = "Raijin", Name = "Raijin", Desc = "Dash cooldown -40%." } })
-- Cannon
weapon({ Id = "ScrapBlaster", Name = "Scrap Blaster", Class = "Cannon", Rarity = "Common", Skill = "MegaBuster", Blade = c(110, 110, 115), Accent = c(200, 140, 60) })
weapon({ Id = "PlasmaArm", Name = "Plasma Arm", Class = "Cannon", Rarity = "Rare", Skill = "MegaBuster", Blade = c(60, 70, 90), Accent = c(0, 230, 255), Glow = c(0, 230, 255) })
weapon({ Id = "BusterCannon", Name = "Buster Cannon", Class = "Cannon", Rarity = "Epic", Skill = "MegaBuster", Blade = c(40, 110, 200), Accent = c(230, 230, 240), Glow = c(120, 220, 255) })
weapon({ Id = "PsychoGun", Name = "Psycho Gun", Class = "Cannon", Rarity = "Mythic", Skill = "PsychoBlast", Blade = c(200, 200, 210), Accent = c(255, 90, 200), Glow = c(255, 120, 255), Recipe = true, Passive = { Id = "Psycho", Name = "Psycho Energy", Desc = "Blasts are 50% larger." } })

Config.Weapons = W
Config.WeaponById = {}
Config.WeaponsByRarity = {}
Config.WeaponsByClass = {}
for _, w in ipairs(Config.Weapons) do
	Config.WeaponById[w.Id] = w
	if not w.Recipe then
		Config.WeaponsByRarity[w.Rarity] = Config.WeaponsByRarity[w.Rarity] or {}
		table.insert(Config.WeaponsByRarity[w.Rarity], w)
		Config.WeaponsByClass[w.Class] = Config.WeaponsByClass[w.Class] or {}
		table.insert(Config.WeaponsByClass[w.Class], w)
	end
end
Config.StarterWeapon = "TrainingKatana"

---------------------------------------------------------------------
-- FORGE  (the only way to get weapons: combine up to 3 ores)
---------------------------------------------------------------------
-- Any mix works: the ores' effects decide the weapon type and are stamped
-- onto the weapon. Exact combinations below forge a unique iconic weapon.
Config.Forge = {
	Slots = 3,
	CoinCostPerOrePoint = 4, -- coins per effect point in the recipe (x rebirth scale)
}
Config.Recipes = {
	{ Weapon = "Shusui", Ores = { "BloodRuby", "DragonScale", "RiftPebble" }, Hint = "Blood, dragon and stone" },
	{ Weapon = "Enma", Ores = { "CinderStone", "DragonScale", "VoidMythril" }, Hint = "Flame, fang and the void" },
	{ Weapon = "Zangetsu", Ores = { "VoidMythril", "SunIron", "SunIron" }, Hint = "Two suns eclipsed by the void" },
	{ Weapon = "StarrkGuns", Ores = { "Soulstone", "SpiritSilver", "LuckyTopaz" }, Hint = "A lonely soul, silver and luck" },
	{ Weapon = "Rasengan", Ores = { "ChakraCopper", "GaleOpal", "KiCrystal" }, Hint = "Chakra spun by the wind" },
	{ Weapon = "SpiritGun", Ores = { "SpiritSilver", "KiCrystal", "StormQuartz" }, Hint = "Spirit, ki and lightning" },
	{ Weapon = "DimensionalScythe", Ores = { "VoidMythril", "EchoGlass", "BloodRuby" }, Hint = "The void echoes with blood" },
	{ Weapon = "DragonLance", Ores = { "DragonScale", "FrostDew", "SunIron" }, Hint = "A dragon between frost and sun" },
	{ Weapon = "TwinMoons", Ores = { "MoonPearl", "MoonPearl", "VenomJade" }, Hint = "Two moons, one venom" },
	{ Weapon = "OniKanabo", Ores = { "TitanBone", "TitanBone", "CinderStone" }, Hint = "Titan bones in fire" },
	{ Weapon = "MoonYumi", Ores = { "MoonPearl", "GaleOpal", "SpiritSilver" }, Hint = "Moonlight on the wind" },
	{ Weapon = "SageStaff", Ores = { "ChronoAmber", "SunIron", "StormQuartz" }, Hint = "Time, sun and storm" },
	{ Weapon = "JudgmentChains", Ores = { "StormQuartz", "BloodRuby", "ChronoAmber" }, Hint = "Storm, blood and time" },
	{ Weapon = "NineTailsClaws", Ores = { "Soulstone", "CinderStone", "DragonScale" }, Hint = "A burning beast's soul" },
	{ Weapon = "GreatWindFan", Ores = { "GaleOpal", "GaleOpal", "SakuraGold" }, Hint = "Twin gales over gold petals" },
	{ Weapon = "RaijinKunai", Ores = { "StormQuartz", "StormQuartz", "EchoGlass" }, Hint = "Thunder that echoes twice" },
	{ Weapon = "PsychoGun", Ores = { "RiftCore", "SunIron", "KiCrystal" }, Hint = "A rift core fed by sun and ki" },
}
-- key = sorted ore ids joined with "+"
function Config.RecipeKey(ores: { string }): string
	local list = table.clone(ores)
	table.sort(list)
	return table.concat(list, "+")
end
Config.RecipeByKey = {}
for i, r in ipairs(Config.Recipes) do
	r.Index = i
	r.Key = Config.RecipeKey(r.Ores)
	Config.RecipeByKey[r.Key] = r
end

-- Catalysts (from play-time rewards, dailies, bosses) guarantee a minimum rarity.
Config.Catalysts = {
	Uncommon = { Name = "Uncommon Catalyst", MinRarity = "Uncommon", Color = Color3.fromRGB(85, 225, 110) },
	RareScroll = { Name = "Rare+ Catalyst", MinRarity = "Rare", Color = Color3.fromRGB(70, 160, 255) },
	Legendary = { Name = "Legendary Catalyst", MinRarity = "Legendary", Color = Color3.fromRGB(255, 195, 45) },
}
Config.CatalystOrder = { "Uncommon", "RareScroll", "Legendary" }
Config.KeyNames = { Uncommon = "Uncommon Catalyst", RareScroll = "Rare+ Catalyst", Legendary = "Legendary Catalyst" }

---------------------------------------------------------------------
-- ARMOR  (rare drops from enemies; defense + one bonus stat)
---------------------------------------------------------------------
Config.Armors = {
	{ Id = "TrainingGi", Name = "Training Gi", Style = "Gi", Color = c(230, 225, 210), Trim = c(200, 60, 50), Bonus = "Speed" },
	{ Id = "ShinobiVest", Name = "Shinobi Flak Vest", Style = "Vest", Color = c(60, 80, 70), Trim = c(40, 40, 50), Bonus = "Dodge" },
	{ Id = "SamuraiYoroi", Name = "Samurai O-Yoroi", Style = "Samurai", Color = c(150, 30, 35), Trim = c(230, 190, 90), Bonus = "Guard" },
	{ Id = "MechaFrame", Name = "Mecha Frame", Style = "Mech", Color = c(70, 80, 100), Trim = c(0, 230, 255), Bonus = "Stamina" },
	{ Id = "OniHide", Name = "Oni Hide", Style = "Oni", Color = c(110, 40, 40), Trim = c(240, 230, 210), Bonus = "Thorns" },
	{ Id = "ShinigamiRobe", Name = "Shinigami Robe", Style = "Robe", Color = c(25, 25, 30), Trim = c(240, 240, 250), Bonus = "Lifesteal" },
	{ Id = "BattleArmor", Name = "Saiyan Battle Armor", Style = "Saiyan", Color = c(235, 235, 240), Trim = c(60, 80, 140), Bonus = "Power" },
	{ Id = "CelestialAegis", Name = "Celestial Aegis", Style = "Aegis", Color = c(240, 235, 210), Trim = c(120, 220, 255), Bonus = "Luck" },
}
Config.ArmorById = {}
for _, a in ipairs(Config.Armors) do
	Config.ArmorById[a.Id] = a
end
-- Per-rarity armour numbers (index = rarity index 1..6)
Config.ArmorDefense = { 0.05, 0.09, 0.14, 0.2, 0.28, 0.38 }
Config.ArmorBonus = {
	Speed = { Per = 0.04, Text = "+%d%% move speed" },
	Dodge = { Per = 0.025, Text = "%d%% chance to dodge hits" },
	Guard = { Per = 0.02, Text = "+%d%% extra defense" },
	Stamina = { Per = 0.05, Text = "-%d%% ability stamina cost" },
	Thorns = { Per = 0.25, Text = "Reflect %d%% of your damage at attackers" },
	Lifesteal = { Per = 0.003, Text = "Heal %.1f%% HP per hit", Raw = true },
	Power = { Per = 0.1, Text = "+%d%% Power gain" },
	Luck = { Per = 0.06, Text = "+%d%% ore luck" },
}
Config.ArmorDropChance = { Normal = 0.004, Elite = 0.04, Boss = 0.12, BossRush = 0.08 }
Config.MaxArmors = 40

function Config.ArmorBonusValue(bonus: string, rarityIndex: number): number
	local b = Config.ArmorBonus[bonus]
	return b and b.Per * rarityIndex or 0
end

function Config.ArmorBonusText(bonus: string, rarityIndex: number): string
	local b = Config.ArmorBonus[bonus]
	if not b then
		return ""
	end
	local v = Config.ArmorBonusValue(bonus, rarityIndex)
	if b.Raw then
		return string.format(b.Text, v * 100)
	end
	return string.format(b.Text, math.floor(v * 100 + 0.5))
end

---------------------------------------------------------------------
-- PLAY-TIME REWARDS + DAILY STREAK
---------------------------------------------------------------------
Config.PlaytimeRewards = {
	{ Minutes = 5, Name = "100 Coins + Health Potion", Coins = 100, Potions = 1 },
	{ Minutes = 15, Name = "Uncommon Catalyst", Keys = { Uncommon = 1 } },
	{ Minutes = 30, Name = "2x Damage Boost (15 min)", DamageBoost = 15 * 60 },
	{ Minutes = 60, Name = "Rare+ Catalyst", Keys = { RareScroll = 1 } },
	{ Minutes = 120, Name = "Playtime Aura + Legendary Catalyst", Aura = "Playtime", Keys = { Legendary = 1 } },
}
Config.Daily = {
	BaseCoins = 150,
	MaxScaleDays = 7,
	CoinBonusPerDay = 0.05,
	MaxCoinBonus = 0.5,
	WeeklyKey = "RareScroll",
}
Config.Potion = { Heal = 0.4, Cooldown = 15 }

---------------------------------------------------------------------
-- 2x POWER PURCHASES  (cost 3^n Robux, multiplier 2^n)
---------------------------------------------------------------------
Config.PowerTiers = {
	{ Id = 0, Price = 3 },
	{ Id = 0, Price = 9 },
	{ Id = 0, Price = 27 },
	{ Id = 0, Price = 81 },
	{ Id = 0, Price = 243 },
	{ Id = 0, Price = 729 },
	{ Id = 0, Price = 2187 },
	{ Id = 0, Price = 6561 },
}
function Config.PowerTierPrice(n: number): number
	return 3 ^ n
end
function Config.PowerTierMult(n: number): number
	return 2 ^ n
end

---------------------------------------------------------------------
-- LEADERBOARDS  (physical boards at spawn; OrderedDataStore)
---------------------------------------------------------------------
-- Log = true stores log10 of the value so huge exponential numbers fit.
Config.Leaderboards = {
	{ Key = "Power", Title = "TOP POWER", Store = "PlusOneAnime_LB_Power_v2", Log = true, Color = Color3.fromRGB(120, 255, 170) },
	{ Key = "Stage", Title = "FURTHEST STAGE", Store = "PlusOneAnime_LB_Stage_v2", Color = Color3.fromRGB(255, 200, 90) },
	{ Key = "Prestige", Title = "TOP REBIRTHS", Store = "PlusOneAnime_LB_Prestige_v2", Color = Color3.fromRGB(210, 150, 255) },
	{ Key = "Kills", Title = "TOP SLAYERS", Store = "PlusOneAnime_LB_Kills_v2", Color = Color3.fromRGB(255, 110, 120) },
}
Config.LeaderboardRefresh = 60

---------------------------------------------------------------------
-- ENEMY AVATARS  (built from the Roblox catalog, like Catalog Avatar Creator)
---------------------------------------------------------------------
-- Each stage searches the catalog for these keywords and dresses the enemy
-- in real items (hair, hat/mask, shirt, pants). Results are cached. If the
-- catalog can't be reached, the procedural anime look below is used.
-- Put exact asset ids in Config.EnemyCatalogOverrides[stage] to pin items.
local AVATAR_THEMES = {
	{ Hair = { "anime spiky hair", "red long hair", "brown messy hair", "black bun hair", "white long hair" }, Hat = { "headband", "oni horns", "", "samurai mask", "crown" }, Shirt = { "school uniform", "gakuran", "hoodie", "blazer", "student council" }, Pants = { "black pants", "school pants", "jeans", "hakama", "white pants" } },
	{ Hair = { "cyber hair", "neon hair", "buzz cut", "white hair", "red spiky hair" }, Hat = { "goggles", "visor", "ninja mask", "cyber mask", "admiral hat" }, Shirt = { "tech jacket", "mech suit", "ninja suit", "armor", "captain coat" }, Pants = { "cargo pants", "tech pants", "black pants", "armor pants", "white pants" } },
	{ Hair = { "pink hair", "fox ears", "samurai ponytail", "witch hair", "long white hair" }, Hat = { "lantern", "kitsune mask", "straw hat", "witch hat", "demon horns" }, Shirt = { "kimono", "yukata", "samurai", "witch robe", "demon queen" }, Pants = { "kimono pants", "hakama", "samurai pants", "black skirt", "red pants" } },
	{ Hair = { "blue hair", "knight hair", "slicked hair", "silver hair", "general hair" }, Hat = { "space helmet", "knight helmet", "beret", "halo", "military cap" }, Shirt = { "space suit", "knight armor", "sniper", "paladin", "military uniform" }, Pants = { "space pants", "armor pants", "cargo pants", "white pants", "military pants" } },
	{ Hair = { "white fluffy hair", "bald", "ice blue hair", "frost hair", "silver long hair" }, Hat = { "fur hat", "monk", "snow goggles", "ice crown", "frost crown" }, Shirt = { "winter coat", "monk robe", "ronin", "ice armor", "emperor" }, Pants = { "snow pants", "monk pants", "hakama", "armor pants", "white pants" } },
	{ Hair = { "black hair", "chaos hair", "dark knight", "demon hair", "black long hair" }, Hat = { "hood", "cult mask", "dark helmet", "demon horns", "dark crown" }, Shirt = { "dark cloak", "cultist robe", "dark knight", "demon armor", "king robe" }, Pants = { "black pants", "robe pants", "armor pants", "demon pants", "royal pants" } },
}
Config.EnemyAvatars = {}
for i, stage in ipairs(Config.Stages) do
	local theme = AVATAR_THEMES[stage.Zone] or AVATAR_THEMES[1]
	local k = ((i - 1) % Config.StagesPerZone) + 1
	Config.EnemyAvatars[i] = {
		Hair = theme.Hair[k],
		Hat = theme.Hat[k],
		Shirt = theme.Shirt[k],
		Pants = theme.Pants[k],
		Skin = Color3.fromHSV(0.07, 0.18 + (i % 4) * 0.05, 0.95 - (i % 3) * 0.1),
	}
end
Config.EnemyCatalogOverrides = {
	-- [stageIndex] = { HairAccessory = "123,456", HatAccessory = "", FaceAccessory = "", Shirt = 0, Pants = 0, Face = 0 },
}
-- Copy a real player's avatar instead (optional): [stageIndex] = userId
Config.EnemyAvatarUserIds = {}

-- Procedural fallback looks (used if the catalog is unavailable).
Config.EnemyLooks = {
	[1] = { Hair = "Spiky", HairColor = c(255, 200, 60), Skin = c(255, 220, 190), Shirt = c(40, 40, 60), Pants = c(30, 30, 40), Extra = "Headband", Silhouette = "Brawler", Core = c(120, 255, 150) },
	[2] = { Hair = "Long", HairColor = c(220, 40, 60), Skin = c(240, 200, 170), Shirt = c(230, 230, 235), Pants = c(40, 40, 50), Extra = "Horns", Silhouette = "Oni", Core = c(255, 70, 70) },
	[3] = { Hair = "Spiky", HairColor = c(90, 60, 40), Skin = c(200, 160, 120), Shirt = c(200, 120, 40), Pants = c(70, 60, 50), Extra = "Headband", Silhouette = "Golem", Core = c(255, 170, 60) },
	[4] = { Hair = "Bun", HairColor = c(30, 30, 40), Skin = c(250, 215, 185), Shirt = c(60, 80, 160), Pants = c(30, 30, 50), Extra = "Mask", Silhouette = "Ronin", Core = c(110, 150, 255) },
	[5] = { Hair = "Long", HairColor = c(240, 240, 250), Skin = c(245, 215, 195), Shirt = c(120, 40, 180), Pants = c(30, 20, 40), Extra = "Crown", Silhouette = "Tyrant", Core = c(210, 90, 255) },
	[6] = { Hair = "Spiky", HairColor = c(0, 230, 255), Skin = c(230, 200, 180), Shirt = c(40, 45, 60), Pants = c(25, 25, 35), Extra = "Visor", Silhouette = "Drone", Core = c(255, 170, 60) },
	[7] = { Hair = "Bun", HairColor = c(255, 120, 200), Skin = c(240, 210, 190), Shirt = c(60, 60, 80), Pants = c(30, 30, 40), Extra = "Visor", Silhouette = "Mech", Core = c(120, 200, 255) },
	[8] = { Hair = "Spiky", HairColor = c(40, 40, 50), Skin = c(220, 190, 170), Shirt = c(20, 20, 25), Pants = c(20, 20, 25), Extra = "Mask", Silhouette = "Shinobi", Core = c(255, 60, 200) },
	[9] = { Hair = "Long", HairColor = c(0, 255, 180), Skin = c(235, 205, 185), Shirt = c(30, 60, 60), Pants = c(20, 30, 30), Extra = "Visor", Silhouette = "Warden", Core = c(0, 255, 180) },
	[10] = { Hair = "Spiky", HairColor = c(255, 60, 60), Skin = c(245, 215, 195), Shirt = c(150, 20, 30), Pants = c(30, 20, 20), Extra = "Crown", Silhouette = "Admiral", Core = c(255, 50, 70) },
}
Config.EliteLook = {
	Palette = c(38, 32, 28),
	Trim = c(255, 205, 80),
}

-- Roblox-owned default animations (work in any game). Replace with your own
-- uploads; if your attack animations have a keyframe or marker named "Hit",
-- enemy damage is synced to it (otherwise HitTime below is used).
Config.EnemyAnims = {
	R15 = {
		Idle = "rbxassetid://507766666",
		Walk = "rbxassetid://507777826",
		Run = "rbxassetid://507767714",
		BasicAttack = "rbxassetid://522635514",
		SpecialWindup = "rbxassetid://507770677",
		SpecialRelease = "rbxassetid://522638767",
	},
	R6 = {
		Idle = "rbxassetid://180435571",
		Walk = "rbxassetid://180426354",
		Run = "rbxassetid://180426354",
		BasicAttack = "rbxassetid://129967390",
		SpecialWindup = "rbxassetid://180435571",
		SpecialRelease = "rbxassetid://129967478",
	},
	BasicHitTime = 0.3,
	SpecialHitTime = 0.25,
}
Config.EnemyAI = {
	PathRecompute = 1.2,
	SpecialCooldown = { Normal = 9, Elite = 7, Boss = 5 },
	SpecialRange = { Normal = 12, Elite = 14, Boss = 26 },
	Windup = { Normal = 0.9, Elite = 0.8, Boss = 1.1 },
	SpecialPercent = { Normal = 0.12, Elite = 0.15, Boss = 0.22 },
	Anticipation = { Normal = 0.4, Elite = 0.32, Boss = 0.5 },
	Recovery = { Normal = 0.6, Elite = 0.45, Boss = 0.9 },
	SpecialRecovery = { Normal = 1.0, Elite = 0.8, Boss = 1.4 },
	RecoverDamageMult = 1.25,
}

-- Player animations (client, played on your own character)
Config.PlayerAnims = {
	R15 = { Slash = "rbxassetid://522635514", Lunge = "rbxassetid://522638767", Hold = "rbxassetid://507768375", Charge = "rbxassetid://507770677", Point = "rbxassetid://507770453" },
	R6 = { Slash = "rbxassetid://129967390", Lunge = "rbxassetid://129967478", Hold = "rbxassetid://182393478", Charge = "rbxassetid://129967478", Point = "rbxassetid://128853357" },
}

return Config
