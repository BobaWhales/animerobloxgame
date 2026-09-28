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
	Display = Enum.Font.FredokaOne, -- titles, big numbers, buttons
	Heading = Enum.Font.FredokaOne, -- small labels / key caps
	Body = Enum.Font.FredokaOne, -- body text
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
-- THE DUNGEON  (+1 Loot To Forge style runs)
-- Enter from the lobby and fight floor after floor: clear a room to open
-- the next door, a boss guards every 5th floor. Dying or going HOME sends
-- you back to the lobby and the run starts over, but checkpoints let you
-- skip ahead: reach floor 50 to start at 25, floor 75 to start at 50...
-- Floors never end; zones cycle with a "Nightmare" tier after floor 200.
---------------------------------------------------------------------
local cc = Color3.fromRGB
Config.Dungeon = {
	FloorsPerZone = 25,
	BossEvery = 5,
	CheckpointEvery = 25, -- a checkpoint at floor N unlocks once you reach N + CheckpointEvery
	FastTravelEvery = 10, -- Fast Travel gamepass: checkpoints every 10 floors (still one step behind)
	RoomWidth = 64,
	RoomLen = 78,
	BossRoomLen = 110,
	HallLen = 34, -- entry hall at the start of each 5-floor segment
	SpawnRange = 10, -- enemies spawn once you walk this far into a room
	BaseHP = 30,
	HPGrowth = 1.22, -- per floor
	BaseCoins = 3,
	CoinGrowth = 1.17, -- per floor
	BossHPMult = 14,
	BossCoinMult = 15,
	BaseCount = 4, -- enemies per room (grows slowly)
	MaxCount = 8,
	RunSlots = 24,
	SlotSpacing = 900,
	SlotOrigin = Vector3.new(-8000, 600, 0),
}

-- Anime-themed zones (parody names), 25 floors each.
Config.Zones = {
	{
		Id = 1, Name = "Hidden Leaf Forest", Theme = "Forest",
		Floor = cc(58, 74, 46), Wall = cc(92, 72, 52), Accent = cc(120, 255, 150), Tint = cc(225, 245, 225),
		Enemies = { "RogueGenin", "SoundNinja", "PuppetNinja", "MaskedAnbu" },
		Bosses = { "SandGourd", "SnakeSage", "RedCloudRogue", "ShadowAvenger", "NineTailsHost" },
	},
	{
		Id = 2, Name = "Soul Reaper Gates", Theme = "Soul",
		Floor = cc(40, 38, 46), Wall = cc(210, 205, 196), Accent = cc(120, 200, 255), Tint = cc(225, 232, 255),
		Enemies = { "Hollow", "RogueReaper", "Arrancar", "QuincyArcher" },
		Bosses = { "SixthEspada", "BellCaptain", "HollowfiedReaper", "FrostCaptain", "HollowKing" },
	},
	{
		Id = 3, Name = "Titan Wall Ruins", Theme = "Walls",
		Floor = cc(96, 86, 72), Wall = cc(150, 140, 122), Accent = cc(255, 170, 90), Tint = cc(255, 238, 220),
		Enemies = { "RogueScout", "PureTitan", "AbnormalTitan", "GarrisonGunner" },
		Bosses = { "JawTitan", "FemaleTitan", "ArmoredTitan", "BeastTitan", "ColossalTitan" },
	},
	{
		Id = 4, Name = "Demon Moon Mountain", Theme = "Shrine",
		Floor = cc(44, 30, 40), Wall = cc(70, 40, 50), Accent = cc(255, 90, 120), Tint = cc(255, 222, 232),
		Enemies = { "LesserDemon", "SpiderDemon", "DrumDemon", "SwampDemon" },
		Bosses = { "LowerMoon", "IceFanDemon", "MoonSister", "CrescentWarrior", "DemonKing" },
	},
	{
		Id = 5, Name = "Cursed Academy", Theme = "Academy",
		Floor = cc(30, 30, 44), Wall = cc(62, 58, 84), Accent = cc(180, 110, 255), Tint = cc(232, 222, 255),
		Enemies = { "CursedSpirit", "CursedStudent", "CurseUser", "FingerBearer" },
		Bosses = { "PatchworkCurse", "VolcanoCurse", "ForestCurse", "BlindfoldRogue", "KingOfCurses" },
	},
	{
		Id = 6, Name = "Grand Line Cove", Theme = "Cove",
		Floor = cc(160, 140, 100), Wall = cc(90, 64, 44), Accent = cc(80, 200, 255), Tint = cc(235, 245, 255),
		Enemies = { "MarineGrunt", "PirateBrawler", "Fishman", "PirateSwordsman" },
		Bosses = { "ViceAdmiral", "FlameCommander", "FeatherWarlord", "MagmaAdmiral", "SeaEmperor" },
	},
	{
		Id = 7, Name = "Hero City Rooftops", Theme = "City",
		Floor = cc(52, 54, 62), Wall = cc(78, 82, 96), Accent = cc(255, 220, 60), Tint = cc(240, 240, 255),
		Enemies = { "VillainThug", "BrainBeast", "HeroHunter", "LeagueGoon" },
		Bosses = { "WarpMist", "HandMaskVillain", "MonsterCaptain", "DeepSeaKing", "SymbolOfVillainy" },
	},
	{
		Id = 8, Name = "Saiyan Wastes", Theme = "Wastes",
		Floor = cc(120, 96, 70), Wall = cc(150, 110, 80), Accent = cc(255, 225, 60), Tint = cc(255, 240, 215),
		Enemies = { "SproutWarrior", "TyrantSoldier", "RogueAndroid", "RogueNamekian" },
		Bosses = { "ForceCaptain", "AndroidQueen", "BioAndroid", "PinkMajin", "GalacticTyrant" },
	},
}
Config.StagesPerZone = Config.Dungeon.FloorsPerZone

-- Which ores a floor can drop: a new ore every 5 floors, the newest is rarest.
local function floorDrops(f: number, boss: boolean)
	local maxOrder = math.min(#Config.Ores, 2 + math.ceil(f / 5) + (boss and 1 or 0))
	local drops = {}
	for o = math.max(1, maxOrder - 7), maxOrder do
		drops[Config.Ores[o].Id] = 100 * 0.6 ^ (maxOrder - o)
	end
	return drops
end

-- Floor data (generated on demand and cached). Floors are endless.
local floorCache = {}
function Config.Floor(f: number)
	f = math.max(1, math.floor(f))
	local cached = floorCache[f]
	if cached then
		return cached
	end
	local D = Config.Dungeon
	local cycle = math.floor((f - 1) / (D.FloorsPerZone * #Config.Zones)) -- 0 = normal, 1+ = nightmare
	local zi = math.floor((f - 1) / D.FloorsPerZone) % #Config.Zones + 1
	local zone = Config.Zones[zi]
	local inZone = (f - 1) % D.FloorsPerZone + 1 -- 1..25
	local boss = f % D.BossEvery == 0
	local look, name
	if boss then
		look = zone.Bosses[math.clamp(inZone // D.BossEvery, 1, #zone.Bosses)]
	else
		look = zone.Enemies[math.floor((inZone - 1) / 6) % #zone.Enemies + 1]
	end
	local second = zone.Enemies[(math.floor((inZone - 1) / 6) + 1) % #zone.Enemies + 1]
	name = (Config.EnemyArchetypes[look] and Config.EnemyArchetypes[look].Name) or look
	if cycle > 0 then
		name = (cycle == 1 and "Nightmare " or ("Nightmare " .. (cycle + 1) .. " ")) .. name
	end
	local hp = D.BaseHP * D.HPGrowth ^ (f - 1)
	local coins = D.BaseCoins * D.CoinGrowth ^ (f - 1)
	local data = {
		Index = f,
		Zone = zi,
		ZoneData = zone,
		Cycle = cycle,
		InZone = inZone,
		Boss = boss,
		Look = look,
		MixLook = not boss and inZone > 3 and second or nil, -- later floors mix two enemy types
		Enemy = name,
		HP = boss and hp * D.BossHPMult or hp,
		Coins = math.floor(boss and coins * D.BossCoinMult or coins),
		Count = boss and 1 or math.min(D.MaxCount, D.BaseCount + math.floor(f / 12)),
		Color = zone.Accent:Lerp(Color3.fromHSV(((f * 0.137) % 1), 0.6, 1), 0.35),
		Drops = floorDrops(f, boss),
		ZoneStart = f - inZone + 1,
	}
	data.Kills = data.Count
	floorCache[f] = data
	return data
end

-- Checkpoints you may start a run from (always includes floor 1).
function Config.Checkpoints(bestFloor: number, fastTravel: boolean?): { number }
	local D = Config.Dungeon
	local list = { 1 }
	local step = fastTravel and D.FastTravelEvery or D.CheckpointEvery
	local cp = step
	while cp + D.CheckpointEvery <= (bestFloor or 0) or (fastTravel and cp + step <= (bestFloor or 0)) do
		table.insert(list, cp)
		cp += step
	end
	return list
end

-- Lobby layout (shared by MapBuilder, the world map and the client).
Config.World = {
	PlazaRadius = 70,
	DungeonGate = Vector3.new(0, 0, -110), -- the dungeon entrance north of spawn
	TrainCenter = Vector3.new(-190, 0, 0),
	BossRushCenter = Vector3.new(190, 0, 0),
}

-- World map fog of war: regions you have walked into (saved per player).
Config.ExploreKeys = { Hub = true, Train = true, BossRush = true, Dungeon = true }

Config.EnemyRespawn = 2.5 -- (boss rush only; dungeon rooms spawn one wave)
Config.EliteChance = 0.05 -- rare golden "Elite" spawn
Config.EliteHPMult = 5
Config.EliteDropMult = 3
Config.BossOreDrops = 6
Config.BossRerollChance = 0.05
Config.EnemyAggroRange = 44
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
-- SKILL MASTERY  (per weapon type; using E / R skills and getting kills
-- with a weapon type levels it up)
---------------------------------------------------------------------
Config.Mastery = {
	MaxLevel = 100,
	XPBase = 6, -- xp for level L -> L+1 = XPBase * (L+1)^XPPow
	XPPow = 1.5,
	SkillXP = { E = 4, R = 10 },
	KillXP = 1,
	EliteKillXP = 6,
	BossKillXP = 30,
	DamagePerLevel = 0.03, -- +3% skill damage per level
	CooldownPerLevel = 0.003, -- -0.3% skill cooldown per level
	Milestones = {
		{ Level = 10, Name = "Adept", Desc = "+15% skill range and area" },
		{ Level = 25, Name = "Expert", Desc = "-20% skill stamina cost" },
		{ Level = 50, Name = "Master", Desc = "-15% skill cooldowns" },
		{ Level = 100, Name = "Grandmaster", Desc = "x1.5 skill damage, golden skill VFX" },
	},
}

-- level, xp into the level, xp needed for the next level
function Config.MasteryLevel(xp: number): (number, number, number)
	local M = Config.Mastery
	local level = 0
	xp = math.max(0, xp or 0)
	while level < M.MaxLevel do
		local need = math.floor(M.XPBase * (level + 1) ^ M.XPPow)
		if xp < need then
			return level, xp, need
		end
		xp -= need
		level += 1
	end
	return M.MaxLevel, 0, 0
end

function Config.MasteryHas(level: number, milestoneLevel: number): boolean
	return (level or 0) >= milestoneLevel
end

---------------------------------------------------------------------
-- BOSS RUSH  (endless bosses back to back; each boss adds a timer)
---------------------------------------------------------------------
Config.BossRush = {
	StageReq = 5, -- beat the floor 5 boss to enter
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
	FastTravel = { Id = 0, Name = "Fast Travel", Desc = "Dungeon checkpoints every 10 floors instead of 25." },
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
	Dungeon = 0,
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
	{ Key = "Stage", Title = "DEEPEST FLOOR", Store = "PlusOneAnime_LB_Floor_v3", Color = Color3.fromRGB(255, 200, 90) },
	{ Key = "Prestige", Title = "TOP REBIRTHS", Store = "PlusOneAnime_LB_Prestige_v2", Color = Color3.fromRGB(210, 150, 255) },
	{ Key = "Kills", Title = "TOP SLAYERS", Store = "PlusOneAnime_LB_Kills_v2", Color = Color3.fromRGB(255, 110, 120) },
}
Config.LeaderboardRefresh = 60

---------------------------------------------------------------------
-- ENEMY ARCHETYPES  (chibi anime figures: big heads, big eyes, bold hair)
---------------------------------------------------------------------
-- Every enemy is built by code from one of these looks (no catalog needed):
--   Skin, Hair (Spiky / Long / Bun / Short / Messy / Ponytail / Twin / Bald),
--   HairColor, Eye (iris colour), Top / Bottom / Trim colours,
--   Outfit (Vest / Robe / Coat / Armor / Gi / Uniform / Cloak / Bare),
--   Gear (Headband, Mask, HollowMask, Horns, Hood, Scarf, Cape, Haori,
--   Eyepatch, Crown, Gourd, Glasses, Cap, Bandana, StrawHat, CowboyHat,
--   Blindfold, Antenna, Wings, Tails, Scouter, Halo, Marks),
--   Weapon (Katana, Kunai, Blades, Staff, Scythe, Club, Fists, Gun, Bow, Fan),
--   Size (1 = normal, titans are bigger), Aura (bosses glow in this colour).
local SKIN = { Light = c(255, 224, 196), Fair = c(245, 208, 178), Tan = c(214, 164, 120), Dark = c(140, 96, 70), Pale = c(236, 236, 240), Grey = c(150, 150, 160) }
Config.EnemyArchetypes = {
	-- 1 Hidden Leaf Forest
	RogueGenin = { Name = "Rogue Genin", Skin = SKIN.Light, Hair = "Spiky", HairColor = c(70, 50, 36), Eye = c(90, 60, 40), Top = c(66, 84, 60), Bottom = c(40, 44, 52), Trim = c(180, 190, 200), Outfit = "Vest", Gear = { "Headband" }, Weapon = "Kunai" },
	SoundNinja = { Name = "Sound Ninja", Skin = SKIN.Fair, Hair = "Long", HairColor = c(170, 170, 180), Eye = c(120, 90, 200), Top = c(214, 204, 184), Bottom = c(60, 50, 70), Trim = c(110, 80, 160), Outfit = "Gi", Gear = { "Headband", "Scarf" }, Weapon = "Fists" },
	PuppetNinja = { Name = "Puppet Ninja", Skin = SKIN.Tan, Hair = "Short", HairColor = c(40, 36, 40), Eye = c(160, 60, 60), Top = c(36, 36, 46), Bottom = c(30, 30, 38), Trim = c(160, 40, 50), Outfit = "Cloak", Gear = { "Hood", "Marks" }, Weapon = "Blades" },
	MaskedAnbu = { Name = "Masked Anbu", Skin = SKIN.Fair, Hair = "Short", HairColor = c(160, 160, 170), Eye = c(200, 50, 50), Top = c(42, 42, 50), Bottom = c(38, 38, 46), Trim = c(210, 210, 220), Outfit = "Armor", Gear = { "Mask" }, Weapon = "Katana" },
	SandGourd = { Name = "Sand Gourd Host", Skin = SKIN.Fair, Hair = "Messy", HairColor = c(200, 50, 40), Eye = c(90, 200, 160), Top = c(120, 40, 40), Bottom = c(80, 30, 30), Trim = c(210, 180, 120), Outfit = "Coat", Gear = { "Gourd", "Marks" }, Weapon = "Fists", Aura = c(230, 190, 110) },
	SnakeSage = { Name = "Snake Sage", Skin = SKIN.Pale, Hair = "Long", HairColor = c(30, 30, 36), Eye = c(240, 210, 60), Top = c(230, 225, 215), Bottom = c(110, 80, 150), Trim = c(120, 80, 170), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Katana", Aura = c(150, 90, 220) },
	RedCloudRogue = { Name = "Red Cloud Rogue", Skin = SKIN.Fair, Hair = "Long", HairColor = c(26, 26, 32), Eye = c(230, 30, 40), Top = c(24, 22, 28), Bottom = c(24, 22, 28), Trim = c(210, 40, 50), Outfit = "Cloak", Gear = { "Headband" }, Weapon = "Kunai", Aura = c(230, 40, 60) },
	ShadowAvenger = { Name = "Shadow Avenger", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(30, 32, 50), Eye = c(230, 30, 40), Top = c(215, 215, 220), Bottom = c(40, 40, 60), Trim = c(120, 90, 200), Outfit = "Robe", Gear = {}, Weapon = "Katana", Aura = c(140, 110, 255) },
	NineTailsHost = { Name = "Nine-Tails Host", Skin = SKIN.Light, Hair = "Spiky", HairColor = c(255, 210, 60), Eye = c(255, 120, 30), Top = c(255, 140, 40), Bottom = c(255, 140, 40), Trim = c(30, 30, 50), Outfit = "Gi", Gear = { "Headband", "Tails", "Marks" }, Weapon = "Fists", Aura = c(255, 130, 40), Size = 1.1 },
	-- 2 Soul Reaper Gates
	Hollow = { Name = "Hollow", Skin = c(30, 30, 36), Hair = "Bald", HairColor = c(30, 30, 36), Eye = c(255, 220, 60), Top = c(30, 30, 36), Bottom = c(30, 30, 36), Trim = c(240, 240, 240), Outfit = "Bare", Gear = { "HollowMask", "Horns" }, Weapon = "Fists" },
	RogueReaper = { Name = "Rogue Soul Reaper", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(40, 40, 46), Eye = c(80, 140, 220), Top = c(26, 26, 30), Bottom = c(26, 26, 30), Trim = c(240, 240, 240), Outfit = "Robe", Gear = {}, Weapon = "Katana" },
	Arrancar = { Name = "Arrancar", Skin = SKIN.Pale, Hair = "Spiky", HairColor = c(60, 200, 190), Eye = c(60, 200, 190), Top = c(240, 240, 242), Bottom = c(240, 240, 242), Trim = c(30, 30, 36), Outfit = "Coat", Gear = { "HollowMask" }, Weapon = "Katana" },
	QuincyArcher = { Name = "Quincy Archer", Skin = SKIN.Fair, Hair = "Short", HairColor = c(36, 40, 60), Eye = c(80, 120, 220), Top = c(245, 245, 250), Bottom = c(245, 245, 250), Trim = c(70, 110, 220), Outfit = "Uniform", Gear = { "Glasses" }, Weapon = "Bow" },
	SixthEspada = { Name = "Sixth Espada", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(60, 200, 220), Eye = c(60, 200, 220), Top = c(240, 240, 242), Bottom = c(240, 240, 242), Trim = c(30, 30, 36), Outfit = "Coat", Gear = { "HollowMask" }, Weapon = "Katana", Aura = c(60, 200, 220) },
	BellCaptain = { Name = "Bell-Haired Captain", Skin = SKIN.Tan, Hair = "Spiky", HairColor = c(26, 26, 30), Eye = c(240, 200, 60), Top = c(26, 26, 30), Bottom = c(26, 26, 30), Trim = c(240, 240, 240), Outfit = "Robe", Gear = { "Haori", "Eyepatch" }, Weapon = "Katana", Aura = c(255, 220, 60), Size = 1.25 },
	HollowfiedReaper = { Name = "Hollowfied Reaper", Skin = SKIN.Light, Hair = "Spiky", HairColor = c(255, 140, 40), Eye = c(255, 220, 60), Top = c(26, 26, 30), Bottom = c(26, 26, 30), Trim = c(200, 40, 40), Outfit = "Robe", Gear = { "HollowMask", "Horns" }, Weapon = "Katana", Aura = c(200, 30, 40) },
	FrostCaptain = { Name = "Frost Captain", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(235, 240, 250), Eye = c(80, 220, 180), Top = c(26, 26, 30), Bottom = c(26, 26, 30), Trim = c(120, 220, 255), Outfit = "Robe", Gear = { "Haori", "Scarf" }, Weapon = "Katana", Aura = c(150, 225, 255) },
	HollowKing = { Name = "The Hollow King", Skin = SKIN.Pale, Hair = "Long", HairColor = c(245, 245, 250), Eye = c(255, 220, 60), Top = c(240, 240, 242), Bottom = c(240, 240, 242), Trim = c(160, 120, 255), Outfit = "Coat", Gear = { "Crown", "Wings" }, Weapon = "Katana", Aura = c(170, 120, 255), Size = 1.2 },
	-- 3 Titan Wall Ruins
	RogueScout = { Name = "Rogue Scout", Skin = SKIN.Fair, Hair = "Short", HairColor = c(90, 60, 40), Eye = c(60, 140, 90), Top = c(170, 130, 90), Bottom = c(230, 225, 210), Trim = c(40, 90, 60), Outfit = "Uniform", Gear = { "Cape" }, Weapon = "Blades" },
	PureTitan = { Name = "Pure Titan", Skin = c(222, 170, 140), Hair = "Short", HairColor = c(80, 60, 40), Eye = c(40, 40, 40), Top = c(222, 170, 140), Bottom = c(222, 170, 140), Trim = c(180, 120, 100), Outfit = "Bare", Gear = {}, Weapon = "Fists", Size = 1.6 },
	AbnormalTitan = { Name = "Abnormal Titan", Skin = c(212, 160, 132), Hair = "Long", HairColor = c(60, 44, 36), Eye = c(40, 40, 40), Top = c(212, 160, 132), Bottom = c(212, 160, 132), Trim = c(170, 110, 90), Outfit = "Bare", Gear = {}, Weapon = "Fists", Size = 1.5 },
	GarrisonGunner = { Name = "Garrison Gunner", Skin = SKIN.Tan, Hair = "Short", HairColor = c(50, 40, 36), Eye = c(80, 60, 40), Top = c(160, 120, 80), Bottom = c(220, 215, 200), Trim = c(170, 40, 50), Outfit = "Uniform", Gear = { "Cap" }, Weapon = "Gun" },
	JawTitan = { Name = "Jaw Titan", Skin = c(200, 150, 120), Hair = "Messy", HairColor = c(40, 34, 30), Eye = c(40, 40, 40), Top = c(200, 150, 120), Bottom = c(200, 150, 120), Trim = c(230, 230, 220), Outfit = "Armor", Gear = {}, Weapon = "Fists", Aura = c(255, 150, 90), Size = 1.5 },
	FemaleTitan = { Name = "Female Titan", Skin = c(214, 160, 150), Hair = "Short", HairColor = c(240, 220, 150), Eye = c(80, 140, 220), Top = c(214, 160, 150), Bottom = c(214, 160, 150), Trim = c(170, 100, 100), Outfit = "Bare", Gear = { "Marks" }, Weapon = "Fists", Aura = c(255, 170, 150), Size = 1.8 },
	ArmoredTitan = { Name = "Armored Titan", Skin = c(190, 150, 120), Hair = "Short", HairColor = c(230, 210, 160), Eye = c(240, 220, 120), Top = c(230, 210, 170), Bottom = c(190, 150, 120), Trim = c(240, 230, 200), Outfit = "Armor", Gear = {}, Weapon = "Fists", Aura = c(255, 220, 140), Size = 1.9 },
	BeastTitan = { Name = "Beast Titan", Skin = c(160, 120, 90), Hair = "Messy", HairColor = c(120, 90, 60), Eye = c(60, 60, 60), Top = c(120, 90, 60), Bottom = c(120, 90, 60), Trim = c(90, 70, 50), Outfit = "Bare", Gear = {}, Weapon = "Club", Aura = c(200, 150, 90), Size = 2 },
	ColossalTitan = { Name = "Colossal Titan", Skin = c(190, 70, 60), Hair = "Bald", HairColor = c(190, 70, 60), Eye = c(255, 240, 200), Top = c(190, 70, 60), Bottom = c(190, 70, 60), Trim = c(240, 220, 200), Outfit = "Bare", Gear = { "Marks" }, Weapon = "Fists", Aura = c(255, 110, 60), Size = 2.4 },
	-- 4 Demon Moon Mountain
	LesserDemon = { Name = "Lesser Demon", Skin = c(206, 180, 176), Hair = "Messy", HairColor = c(40, 30, 36), Eye = c(255, 60, 90), Top = c(70, 60, 80), Bottom = c(50, 44, 56), Trim = c(160, 40, 60), Outfit = "Robe", Gear = { "Horns", "Marks" }, Weapon = "Fists" },
	SpiderDemon = { Name = "Spider Demon", Skin = SKIN.Pale, Hair = "Long", HairColor = c(245, 245, 250), Eye = c(255, 60, 60), Top = c(245, 245, 250), Bottom = c(245, 245, 250), Trim = c(200, 40, 50), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Fists" },
	DrumDemon = { Name = "Drum Demon", Skin = c(200, 170, 150), Hair = "Messy", HairColor = c(120, 90, 60), Eye = c(255, 180, 60), Top = c(90, 60, 50), Bottom = c(90, 60, 50), Trim = c(200, 160, 90), Outfit = "Gi", Gear = { "Horns" }, Weapon = "Club" },
	SwampDemon = { Name = "Swamp Demon", Skin = c(170, 190, 160), Hair = "Short", HairColor = c(50, 70, 50), Eye = c(200, 255, 120), Top = c(50, 70, 56), Bottom = c(40, 50, 44), Trim = c(120, 160, 90), Outfit = "Cloak", Gear = { "Hood", "Horns" }, Weapon = "Fists" },
	LowerMoon = { Name = "Lower Moon Demon", Skin = SKIN.Pale, Hair = "Long", HairColor = c(30, 30, 40), Eye = c(200, 60, 255), Top = c(40, 36, 60), Bottom = c(40, 36, 60), Trim = c(200, 60, 255), Outfit = "Coat", Gear = { "Horns", "Marks" }, Weapon = "Fists", Aura = c(200, 60, 255) },
	IceFanDemon = { Name = "Ice Fan Demon", Skin = SKIN.Pale, Hair = "Messy", HairColor = c(235, 235, 245), Eye = c(160, 120, 255), Top = c(60, 50, 70), Bottom = c(40, 36, 48), Trim = c(150, 220, 255), Outfit = "Coat", Gear = { "Marks" }, Weapon = "Fan", Aura = c(150, 220, 255) },
	MoonSister = { Name = "Upper Moon Sister", Skin = SKIN.Fair, Hair = "Twin", HairColor = c(30, 30, 40), Eye = c(120, 255, 180), Top = c(170, 40, 90), Bottom = c(60, 30, 50), Trim = c(120, 255, 180), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Blades", Aura = c(120, 255, 180) },
	CrescentWarrior = { Name = "Crescent Moon Warrior", Skin = c(220, 190, 180), Hair = "Ponytail", HairColor = c(40, 30, 50), Eye = c(255, 60, 60), Top = c(80, 40, 110), Bottom = c(40, 30, 50), Trim = c(255, 200, 80), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Katana", Aura = c(160, 60, 255), Size = 1.15 },
	DemonKing = { Name = "Crimson Demon King", Skin = SKIN.Pale, Hair = "Messy", HairColor = c(26, 26, 30), Eye = c(255, 40, 60), Top = c(245, 245, 250), Bottom = c(30, 30, 36), Trim = c(200, 20, 40), Outfit = "Coat", Gear = { "CowboyHat" }, Weapon = "Blades", Aura = c(220, 20, 50), Size = 1.2 },
	-- 5 Cursed Academy
	CursedSpirit = { Name = "Cursed Spirit", Skin = c(120, 130, 140), Hair = "Bald", HairColor = c(120, 130, 140), Eye = c(255, 240, 90), Top = c(90, 100, 110), Bottom = c(90, 100, 110), Trim = c(60, 60, 70), Outfit = "Bare", Gear = { "Marks", "Horns" }, Weapon = "Fists" },
	CursedStudent = { Name = "Cursed Student", Skin = SKIN.Light, Hair = "Spiky", HairColor = c(255, 140, 170), Eye = c(120, 80, 60), Top = c(30, 36, 60), Bottom = c(30, 36, 60), Trim = c(220, 200, 90), Outfit = "Uniform", Gear = {}, Weapon = "Fists" },
	CurseUser = { Name = "Curse User", Skin = SKIN.Fair, Hair = "Bun", HairColor = c(26, 26, 30), Eye = c(120, 60, 60), Top = c(200, 190, 170), Bottom = c(40, 40, 46), Trim = c(160, 60, 60), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Staff" },
	FingerBearer = { Name = "Finger Bearer", Skin = c(90, 90, 100), Hair = "Bald", HairColor = c(90, 90, 100), Eye = c(255, 60, 60), Top = c(70, 70, 80), Bottom = c(70, 70, 80), Trim = c(200, 60, 60), Outfit = "Bare", Gear = { "Marks", "Horns" }, Weapon = "Fists", Size = 1.35 },
	PatchworkCurse = { Name = "Patchwork Curse", Skin = c(200, 205, 215), Hair = "Long", HairColor = c(90, 110, 140), Eye = c(120, 180, 255), Top = c(90, 100, 120), Bottom = c(60, 64, 80), Trim = c(200, 60, 80), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Fists", Aura = c(120, 170, 255) },
	VolcanoCurse = { Name = "Volcano Curse", Skin = c(210, 190, 170), Hair = "Bald", HairColor = c(90, 60, 50), Eye = c(255, 150, 40), Top = c(120, 50, 40), Bottom = c(80, 40, 36), Trim = c(255, 120, 40), Outfit = "Robe", Gear = { "Horns" }, Weapon = "Fists", Aura = c(255, 110, 40) },
	ForestCurse = { Name = "Forest Curse", Skin = c(220, 214, 200), Hair = "Bald", HairColor = c(60, 90, 50), Eye = c(120, 255, 120), Top = c(230, 225, 210), Bottom = c(70, 60, 50), Trim = c(90, 150, 70), Outfit = "Cloak", Gear = { "Horns", "Marks" }, Weapon = "Staff", Aura = c(120, 255, 120) },
	BlindfoldRogue = { Name = "Blindfold Rogue", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(245, 245, 250), Eye = c(120, 220, 255), Top = c(24, 26, 36), Bottom = c(24, 26, 36), Trim = c(120, 220, 255), Outfit = "Uniform", Gear = { "Blindfold" }, Weapon = "Fists", Aura = c(120, 220, 255), Size = 1.1 },
	KingOfCurses = { Name = "King of Curses", Skin = SKIN.Light, Hair = "Spiky", HairColor = c(255, 150, 170), Eye = c(255, 40, 60), Top = c(245, 240, 235), Bottom = c(245, 240, 235), Trim = c(40, 30, 30), Outfit = "Robe", Gear = { "Marks" }, Weapon = "Fists", Aura = c(255, 40, 60), Size = 1.2 },
	-- 6 Grand Line Cove
	MarineGrunt = { Name = "Marine Grunt", Skin = SKIN.Light, Hair = "Short", HairColor = c(60, 44, 36), Eye = c(60, 90, 160), Top = c(245, 245, 250), Bottom = c(60, 90, 160), Trim = c(60, 90, 160), Outfit = "Uniform", Gear = { "Cap" }, Weapon = "Gun" },
	PirateBrawler = { Name = "Pirate Brawler", Skin = SKIN.Tan, Hair = "Messy", HairColor = c(50, 36, 30), Eye = c(80, 60, 40), Top = c(200, 70, 60), Bottom = c(60, 70, 110), Trim = c(240, 210, 90), Outfit = "Vest", Gear = { "Bandana" }, Weapon = "Club" },
	Fishman = { Name = "Fishman", Skin = c(90, 150, 200), Hair = "Short", HairColor = c(40, 60, 90), Eye = c(255, 220, 60), Top = c(240, 200, 80), Bottom = c(60, 60, 80), Trim = c(60, 110, 160), Outfit = "Vest", Gear = {}, Weapon = "Fists" },
	PirateSwordsman = { Name = "Pirate Swordsman", Skin = SKIN.Tan, Hair = "Short", HairColor = c(90, 200, 110), Eye = c(40, 40, 40), Top = c(245, 245, 245), Bottom = c(40, 60, 50), Trim = c(40, 120, 70), Outfit = "Vest", Gear = { "Bandana" }, Weapon = "Katana" },
	ViceAdmiral = { Name = "Vice Admiral", Skin = SKIN.Fair, Hair = "Short", HairColor = c(200, 200, 205), Eye = c(60, 90, 160), Top = c(245, 245, 250), Bottom = c(245, 245, 250), Trim = c(60, 90, 160), Outfit = "Coat", Gear = { "Cap" }, Weapon = "Fists", Aura = c(120, 170, 255), Size = 1.2 },
	FlameCommander = { Name = "Flame Fist Commander", Skin = SKIN.Tan, Hair = "Messy", HairColor = c(30, 26, 26), Eye = c(40, 30, 30), Top = SKIN.Tan, Bottom = c(40, 40, 50), Trim = c(255, 120, 40), Outfit = "Bare", Gear = { "CowboyHat" }, Weapon = "Fists", Aura = c(255, 120, 40) },
	FeatherWarlord = { Name = "Feather Warlord", Skin = SKIN.Tan, Hair = "Short", HairColor = c(240, 210, 90), Eye = c(255, 80, 180), Top = c(255, 110, 180), Bottom = c(240, 230, 220), Trim = c(255, 110, 180), Outfit = "Coat", Gear = { "Glasses", "Wings" }, Weapon = "Fists", Aura = c(255, 110, 180), Size = 1.3 },
	MagmaAdmiral = { Name = "Magma Admiral", Skin = SKIN.Tan, Hair = "Short", HairColor = c(40, 36, 36), Eye = c(255, 90, 40), Top = c(160, 30, 40), Bottom = c(40, 36, 36), Trim = c(245, 245, 250), Outfit = "Coat", Gear = { "Cap" }, Weapon = "Fists", Aura = c(255, 80, 30), Size = 1.3 },
	SeaEmperor = { Name = "Emperor of the Sea", Skin = SKIN.Tan, Hair = "Short", HairColor = c(245, 245, 250), Eye = c(60, 60, 60), Top = c(245, 245, 250), Bottom = c(90, 60, 50), Trim = c(240, 200, 80), Outfit = "Coat", Gear = { "Bandana" }, Weapon = "Club", Aura = c(255, 220, 90), Size = 1.6 },
	-- 7 Hero City Rooftops
	VillainThug = { Name = "Villain Thug", Skin = SKIN.Fair, Hair = "Messy", HairColor = c(90, 90, 100), Eye = c(200, 60, 60), Top = c(40, 40, 50), Bottom = c(30, 30, 40), Trim = c(200, 60, 60), Outfit = "Coat", Gear = { "Mask" }, Weapon = "Club" },
	BrainBeast = { Name = "Brain Beast", Skin = c(30, 30, 36), Hair = "Bald", HairColor = c(220, 140, 160), Eye = c(255, 240, 200), Top = c(30, 30, 36), Bottom = c(30, 30, 36), Trim = c(220, 140, 160), Outfit = "Bare", Gear = { "Crown" }, Weapon = "Fists", Size = 1.4 },
	HeroHunter = { Name = "Hero Hunter", Skin = SKIN.Fair, Hair = "Messy", HairColor = c(26, 26, 30), Eye = c(255, 60, 60), Top = c(80, 30, 36), Bottom = c(40, 30, 36), Trim = c(200, 40, 50), Outfit = "Armor", Gear = { "Scarf", "Bandana" }, Weapon = "Blades" },
	LeagueGoon = { Name = "League Goon", Skin = SKIN.Fair, Hair = "Short", HairColor = c(90, 60, 50), Eye = c(120, 200, 255), Top = c(60, 66, 80), Bottom = c(30, 30, 40), Trim = c(120, 200, 255), Outfit = "Cloak", Gear = { "Hood" }, Weapon = "Gun" },
	WarpMist = { Name = "Warp Mist", Skin = c(50, 30, 80), Hair = "Messy", HairColor = c(90, 40, 140), Eye = c(255, 230, 90), Top = c(30, 30, 36), Bottom = c(30, 30, 36), Trim = c(160, 90, 255), Outfit = "Coat", Gear = {}, Weapon = "Fists", Aura = c(150, 70, 255) },
	HandMaskVillain = { Name = "Hand-Mask Villain", Skin = SKIN.Pale, Hair = "Long", HairColor = c(170, 190, 210), Eye = c(255, 40, 60), Top = c(30, 30, 36), Bottom = c(30, 30, 36), Trim = c(200, 40, 50), Outfit = "Coat", Gear = { "Mask" }, Weapon = "Fists", Aura = c(200, 40, 60) },
	MonsterCaptain = { Name = "Monster Captain", Skin = c(230, 220, 200), Hair = "Spiky", HairColor = c(26, 26, 30), Eye = c(255, 200, 40), Top = c(40, 40, 46), Bottom = c(40, 40, 46), Trim = c(255, 200, 40), Outfit = "Armor", Gear = { "Horns" }, Weapon = "Fists", Aura = c(255, 200, 40), Size = 1.3 },
	DeepSeaKing = { Name = "Deep Sea King", Skin = c(70, 120, 90), Hair = "Bald", HairColor = c(70, 120, 90), Eye = c(255, 240, 200), Top = c(70, 120, 90), Bottom = c(70, 120, 90), Trim = c(240, 240, 230), Outfit = "Bare", Gear = { "Crown" }, Weapon = "Fists", Aura = c(90, 220, 170), Size = 1.8 },
	SymbolOfVillainy = { Name = "Symbol of Villainy", Skin = SKIN.Fair, Hair = "Short", HairColor = c(245, 245, 250), Eye = c(255, 60, 60), Top = c(24, 24, 28), Bottom = c(24, 24, 28), Trim = c(200, 30, 40), Outfit = "Coat", Gear = { "Mask" }, Weapon = "Fists", Aura = c(200, 30, 40), Size = 1.4 },
	-- 8 Saiyan Wastes
	SproutWarrior = { Name = "Sprout Warrior", Skin = c(90, 180, 80), Hair = "Bald", HairColor = c(90, 180, 80), Eye = c(255, 60, 60), Top = c(90, 180, 80), Bottom = c(90, 180, 80), Trim = c(60, 120, 50), Outfit = "Bare", Gear = { "Antenna" }, Weapon = "Fists", Size = 0.9 },
	TyrantSoldier = { Name = "Tyrant Soldier", Skin = SKIN.Fair, Hair = "Spiky", HairColor = c(40, 36, 36), Eye = c(40, 40, 40), Top = c(245, 245, 245), Bottom = c(40, 60, 120), Trim = c(210, 170, 70), Outfit = "Armor", Gear = { "Scouter" }, Weapon = "Fists" },
	RogueAndroid = { Name = "Rogue Android", Skin = SKIN.Light, Hair = "Short", HairColor = c(245, 225, 140), Eye = c(80, 170, 255), Top = c(40, 70, 130), Bottom = c(40, 40, 50), Trim = c(245, 245, 250), Outfit = "Vest", Gear = { "Scarf" }, Weapon = "Fists" },
	RogueNamekian = { Name = "Rogue Namekian", Skin = c(110, 190, 90), Hair = "Bald", HairColor = c(110, 190, 90), Eye = c(40, 40, 40), Top = c(110, 60, 150), Bottom = c(110, 60, 150), Trim = c(245, 245, 250), Outfit = "Gi", Gear = { "Antenna", "Cape" }, Weapon = "Fists" },
	ForceCaptain = { Name = "Force Captain", Skin = c(150, 90, 190), Hair = "Short", HairColor = c(40, 30, 40), Eye = c(40, 40, 40), Top = c(245, 245, 245), Bottom = c(40, 40, 50), Trim = c(210, 170, 70), Outfit = "Armor", Gear = { "Horns", "Scouter" }, Weapon = "Fists", Aura = c(180, 100, 255) },
	AndroidQueen = { Name = "Android Queen", Skin = SKIN.Light, Hair = "Short", HairColor = c(250, 225, 120), Eye = c(80, 170, 255), Top = c(40, 70, 130), Bottom = c(40, 40, 50), Trim = c(245, 245, 250), Outfit = "Vest", Gear = {}, Weapon = "Fists", Aura = c(80, 170, 255) },
	BioAndroid = { Name = "Perfect Bio-Android", Skin = c(100, 170, 90), Hair = "Bald", HairColor = c(30, 30, 30), Eye = c(200, 60, 200), Top = c(130, 190, 110), Bottom = c(40, 40, 40), Trim = c(40, 40, 40), Outfit = "Armor", Gear = { "Wings", "Crown" }, Weapon = "Fists", Aura = c(160, 255, 120), Size = 1.2 },
	PinkMajin = { Name = "Pink Majin", Skin = c(255, 160, 190), Hair = "Bald", HairColor = c(255, 160, 190), Eye = c(40, 40, 40), Top = c(255, 160, 190), Bottom = c(245, 245, 250), Trim = c(120, 50, 150), Outfit = "Bare", Gear = { "Antenna", "Cape" }, Weapon = "Fists", Aura = c(255, 120, 190), Size = 1.3 },
	GalacticTyrant = { Name = "Galactic Tyrant", Skin = c(245, 245, 250), Hair = "Bald", HairColor = c(160, 60, 190), Eye = c(255, 40, 60), Top = c(245, 245, 250), Bottom = c(245, 245, 250), Trim = c(160, 60, 190), Outfit = "Bare", Gear = { "Horns", "Tails" }, Weapon = "Fists", Aura = c(200, 60, 255), Size = 1.2 },
}
for id, a in pairs(Config.EnemyArchetypes) do
	a.Id = id
end
-- Build style: "Chibi" (code-built anime figures) or "Catalog" (dress the
-- rig from the Roblox catalog with Config.EnemyAvatarKeywords, falling back
-- to Chibi when the catalog is unavailable).
Config.EnemyModelStyle = "Chibi"
Config.EnemyAvatarKeywords = {} -- [archetypeId] = { Hair = "...", Hat = "...", Shirt = "...", Pants = "..." }
Config.EnemyAvatarUserIds = {} -- [archetypeId] = userId (copy a real avatar)

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
