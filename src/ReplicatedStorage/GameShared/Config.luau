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
	{ Zone = 1, PowerReq = 0, Enemy = "Slime Delinquent", HP = 25, Count = 5, Coins = 2, Color = Color3.fromRGB(120, 230, 120), Drops = { RiftPebble = 90, ChakraCopper = 10 } },
	{ Zone = 1, PowerReq = 60, Enemy = "Hall Monitor Oni", HP = 90, Count = 5, Coins = 5, Color = Color3.fromRGB(230, 90, 90), Drops = { RiftPebble = 70, ChakraCopper = 27, SpiritSilver = 3 } },
	{ Zone = 1, PowerReq = 250, Enemy = "Club Captain Golem", HP = 350, Count = 5, Coins = 12, Color = Color3.fromRGB(160, 140, 120), Drops = { RiftPebble = 50, ChakraCopper = 38, SpiritSilver = 11, KiCrystal = 1 } },
	{ Zone = 1, PowerReq = 900, Enemy = "Rooftop Ronin", HP = 1400, Count = 5, Coins = 30, Color = Color3.fromRGB(90, 110, 220), Drops = { ChakraCopper = 55, SpiritSilver = 35, KiCrystal = 9, SakuraGold = 1 } },
	{ Zone = 1, PowerReq = 2500, Enemy = "Student Council Tyrant", HP = 60000, Count = 1, Boss = true, Coins = 600, Color = Color3.fromRGB(200, 60, 255), Drops = { SpiritSilver = 50, KiCrystal = 35, SakuraGold = 13, VoidMythril = 2 } },

	{ Zone = 2, PowerReq = 6000, Enemy = "Scrap Drone", HP = 20000, Count = 5, Coins = 60, Color = Color3.fromRGB(255, 170, 60), Drops = { SpiritSilver = 60, KiCrystal = 32, SakuraGold = 7, VoidMythril = 1 } },
	{ Zone = 2, PowerReq = 15000, Enemy = "Dockside Mech-Grunt", HP = 90000, Count = 5, Coins = 140, Color = Color3.fromRGB(120, 200, 255), Drops = { SpiritSilver = 45, KiCrystal = 40, SakuraGold = 13, VoidMythril = 2 } },
	{ Zone = 2, PowerReq = 40000, Enemy = "Neon Ninja Unit", HP = 400000, Count = 5, Coins = 350, Color = Color3.fromRGB(255, 60, 200), Drops = { KiCrystal = 60, SakuraGold = 34, VoidMythril = 6 } },
	{ Zone = 2, PowerReq = 100000, Enemy = "Plasma Warden", HP = 2000000, Count = 5, Coins = 900, Color = Color3.fromRGB(0, 255, 180), Drops = { KiCrystal = 45, SakuraGold = 42, VoidMythril = 12, RiftCore = 1 } },
	{ Zone = 2, PowerReq = 250000, Enemy = "Mecha Admiral Kaizer", HP = 60000000, Count = 1, Boss = true, Coins = 12000, Color = Color3.fromRGB(255, 40, 60), Drops = { SakuraGold = 55, VoidMythril = 38, RiftCore = 7 } },
}
for i, stage in ipairs(Config.Stages) do
	stage.Index = i
end
Config.StagesPerZone = 5

-- Dungeon hall layout (shared by MapBuilder and the world map).
Config.DungeonLayout = {
	Origins = { [1] = Vector3.new(0, 0, -1400), [2] = Vector3.new(700, 0, -1400) },
	StartLen = 60,
	RoomLen = 100,
	RoomWidth = 80,
}

-- World map fog of war: regions you have walked into (saved per player).
Config.ExploreKeys = { Hub = true, Train = true, Portals = true, Tower = true }
for i in ipairs(Config.Stages) do
	Config.ExploreKeys["S" .. i] = true
end
for _, zone in ipairs(Config.Zones) do
	Config.ExploreKeys["Z" .. zone.Id] = true
end

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

---------------------------------------------------------------------
-- PROXIMITY PROMPTS (custom-styled; see Client/PromptUI)
---------------------------------------------------------------------
Config.Prompt = {
	MaxActivationDistance = 10,
	-- Line-of-sight is off by default because several prompts live on parts
	-- that sit inside other geometry (the lava inside the cauldron rim).
	RequiresLineOfSight = false,
}

---------------------------------------------------------------------
-- CLEAN SCREEN: world text + contextual HUD
---------------------------------------------------------------------
-- World labels (station names, portal names, pad multipliers...) are fully
-- transparent until you walk close. Distances are in studs
-- (1 m is about 3.6 studs, so 10 studs is about 2.8 m).
Config.WorldText = {
	ShowDistance = 10, -- fully visible inside this distance
	FadeBand = 5, -- starts fading in this many studs further out
	VerticalSlack = 8, -- labels high above a part still count as "near"
	FontScale = 0.55, -- 45% smaller than the old labels
	NametagRadius = 26, -- other players' name tags use a wider radius
}

-- How long each contextual HUD group stays up after its trigger (seconds).
Config.Hud = {
	CombatLinger = 5, -- hotbar + vitals after your last attack / hit
	DamageLinger = 4, -- vitals after your HP changes
	StaminaLinger = 2.5, -- vitals after stamina use
	ResourceLinger = 3.5, -- a resource pill after its value changes
	LowHealth = 0.3, -- vitals stay up (plus a red vignette) below this HP
	PlaytimeHeadsUp = 45, -- show the play-time timer this many seconds before a reward
}

---------------------------------------------------------------------
-- MOVEMENT + CAMERA FEEL
---------------------------------------------------------------------
Config.Sprint = {
	SpeedMult = 1.4, -- Left Shift / L3
	FovBoost = 9, -- soft FOV widening while sprinting
}
Config.Camera = {
	FramingWeight = 0.22, -- how strongly the camera leans toward a nearby point of interest
	FramingPullBack = 2.5, -- extra studs of distance near points of interest
	FramingFov = -3, -- slight tighten near points of interest
}

---------------------------------------------------------------------
-- GRAPHICS  (Lighting.Technology = Future is set in the place file; Roblox
-- does not let scripts change it. See SETUP.md.)
---------------------------------------------------------------------
Config.Graphics = {
	Atmosphere = { Density = 0.35, Haze = 2.5, Offset = 0.15, Glare = 0.6, Color = Color3.fromRGB(225, 205, 255), Decay = Color3.fromRGB(120, 105, 175) },
	Bloom = { Threshold = 0.75, Size = 28, Intensity = 0.5 },
	ColorCorrection = { Contrast = 0.18, Saturation = 0.25, Brightness = 0.02 },
	SunRays = { Intensity = 0.2, Spread = 0.8 },
	-- Depth of field used while a menu / shop / dialogue is open (client-side)
	MenuDepthOfField = { FarIntensity = 0.75, FocusDistance = 6, InFocusRadius = 8, NearIntensity = 0.4 },
	-- Optional custom PBR MaterialVariants. Fill in texture ids from the
	-- Creator Store to override a base material everywhere in the map.
	MaterialVariants = {
		-- Slate = { ColorMap = "rbxassetid://0", NormalMap = "rbxassetid://0", RoughnessMap = "rbxassetid://0", MetalnessMap = "rbxassetid://0" },
	},
}

---------------------------------------------------------------------
-- GLOBAL CLASS BALANCE (the "nerf pass")
---------------------------------------------------------------------
Config.Balance = {
	CooldownMult = 1.25, -- every skill cooldown +25% (spec: +15% to +30%)
	StaminaCostMult = 1.3, -- every ability costs +30% stamina
	MaxStamina = 100,
	StaminaRegen = 12, -- per second
	StaminaRegenDelay = 1.1, -- seconds after spending before regen starts
	DashDistanceSpeed = 70, -- dash velocity
	DashDuration = 0.16,
	DashCooldown = 1.4,
	DashStamina = 18,
	DashIFrames = 0.18, -- shortened dodge invulnerability
	MaxStun = 1.2, -- hard cap on any stun / ragdoll (enemies and players)
	PlayerStunCap = 0.5,
	DamageMultCap = 40, -- hard cap on combined gameplay damage multipliers
	CritMultCap = 2.5,
	AttackSpeedCap = 0.25, -- max bonus attack speed from all sources
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
-- WEAPON CLASSES (basic attack = LMB)
---------------------------------------------------------------------
-- Kind: Melee uses a cone in front of you. Ranged fires server projectiles.
Config.WeaponClasses = {
	Katana = { Kind = "Melee", Range = 10, Arc = 0.2, Interval = 0.42, Combo = { 1.0, 1.1, 1.5 }, Base = 1.0, Ultimate = "ThousandCuts" },
	Greatsword = { Kind = "Melee", Range = 12.5, Arc = 0.05, Interval = 0.62, Combo = { 1.25, 1.25, 1.45, 2.2 }, Base = 1.1, Ultimate = "Earthsplitter" },
	Pistols = { Kind = "Ranged", Range = 95, Interval = 0.3, Combo = { 0.55, 0.55 }, Base = 1.0, Speed = 260, Radius = 1.6, Projectile = "Ray", Ultimate = "BulletStorm" },
	Glove = { Kind = "Melee", Range = 8, Arc = 0.3, Interval = 0.34, Combo = { 0.8, 0.8, 1.35 }, Base = 0.95, Ultimate = "HundredFists" },
	FingerGun = { Kind = "Ranged", Range = 85, Interval = 0.4, Combo = { 0.75 }, Base = 1.0, Speed = 210, Radius = 2, Projectile = "Orb", Ultimate = "SpiritRain" },
	Scythe = { Kind = "Melee", Range = 13.5, Arc = -0.35, Interval = 0.55, Combo = { 1.1, 1.1, 1.7 }, Base = 1.05, Ultimate = "DeathSpiral" },
}

---------------------------------------------------------------------
-- SKILLS (E = weapon skill, R = class ultimate). Cooldown / Stamina are the
-- BASE values; Config.Balance multipliers are applied on top.
---------------------------------------------------------------------
-- Types: Cone, Nova, Projectile, Barrage, DashStrike, ChargeLunge, Zone, Rain
Config.Skills = {
	-- generic class skills
	IaidoDash = { Name = "Iaido Dash", Type = "DashStrike", Cooldown = 5, Stamina = 25, Damage = 2.5, Distance = 24, Width = 6, Color = Color3.fromRGB(200, 230, 255) },
	GroundCleave = { Name = "Ground Cleave", Type = "Cone", Cooldown = 6, Stamina = 28, Damage = 2.8, Range = 15, Arc = -0.1, Knockback = 45, Color = Color3.fromRGB(255, 190, 120) },
	BurstFire = { Name = "Burst Fire", Type = "Barrage", Cooldown = 5.5, Stamina = 25, Damage = 0.7, Count = 6, Duration = 0.45, Spread = 6, Speed = 280, Range = 95, Radius = 1.6, Projectile = "Ray", Color = Color3.fromRGB(255, 220, 120) },
	ChakraPalm = { Name = "Chakra Palm", Type = "DashStrike", Cooldown = 5, Stamina = 25, Damage = 2.6, Distance = 14, Width = 6, Knockback = 60, Color = Color3.fromRGB(120, 200, 255) },
	ChargedShot = { Name = "Charged Shot", Type = "Projectile", Charge = 1.2, Cooldown = 6, Stamina = 28, Damage = 2.4, ChargeBonus = 1.5, Speed = 180, Range = 100, Radius = 3.5, Pierce = true, Projectile = "Orb", Size = 2.5, Color = Color3.fromRGB(120, 230, 255) },
	Reap = { Name = "Reap", Type = "Nova", Cooldown = 6.5, Stamina = 28, Damage = 2.2, Radius = 16, Pull = true, Color = Color3.fromRGB(150, 90, 220) },

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

	-- class ultimates (R)
	ThousandCuts = { Name = "Thousand Cuts", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 0.9, Hits = 6, Interval = 0.12, Radius = 14, Color = Color3.fromRGB(230, 240, 255) },
	Earthsplitter = { Name = "Earthsplitter", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 6, Radius = 20, Knockback = 80, Stun = 0.8, Color = Color3.fromRGB(255, 160, 80) },
	BulletStorm = { Name = "Bullet Storm", Type = "Barrage", Cooldown = 16, Stamina = 55, Damage = 0.5, Count = 36, Duration = 1.2, Spread = 360, Speed = 220, Range = 60, Radius = 2, Projectile = "Ray", Color = Color3.fromRGB(255, 230, 120) },
	HundredFists = { Name = "Hundred Fists", Type = "Cone", Cooldown = 15, Stamina = 55, Damage = 0.55, Hits = 10, Interval = 0.08, Range = 11, Arc = 0.2, Color = Color3.fromRGB(255, 200, 120) },
	SpiritRain = { Name = "Spirit Rain", Type = "Rain", Cooldown = 16, Stamina = 55, Damage = 1.4, Hits = 10, Interval = 0.12, Radius = 16, Range = 60, Color = Color3.fromRGB(100, 220, 255) },
	DeathSpiral = { Name = "Death Spiral", Type = "Nova", Cooldown = 16, Stamina = 55, Damage = 0.8, Hits = 8, Interval = 0.15, Radius = 16, Pull = true, Color = Color3.fromRGB(160, 80, 255) },
}

---------------------------------------------------------------------
-- WEAPONS  (names of iconic weapons live here - rename freely)
---------------------------------------------------------------------
-- Rarity is the tier the weapon drops in. Passive is only used on
-- Legendary+ weapons. Mythic weapons get an aura + signature skill (E).
Config.Weapons = {
	-- Common
	{ Id = "TrainingKatana", Name = "Training Katana", Class = "Katana", Rarity = "Common", Skill = "IaidoDash", Blade = Color3.fromRGB(200, 205, 215), Accent = Color3.fromRGB(120, 90, 60) },
	{ Id = "RustyGreatsword", Name = "Rusty Greatsword", Class = "Greatsword", Rarity = "Common", Skill = "GroundCleave", Blade = Color3.fromRGB(150, 110, 90), Accent = Color3.fromRGB(90, 70, 60) },
	{ Id = "CapPistols", Name = "Cap Pistols", Class = "Pistols", Rarity = "Common", Skill = "BurstFire", Blade = Color3.fromRGB(90, 90, 100), Accent = Color3.fromRGB(200, 180, 120) },
	{ Id = "WrappedFists", Name = "Wrapped Fists", Class = "Glove", Rarity = "Common", Skill = "ChakraPalm", Blade = Color3.fromRGB(230, 220, 200), Accent = Color3.fromRGB(180, 160, 130) },
	{ Id = "FarmScythe", Name = "Farm Scythe", Class = "Scythe", Rarity = "Common", Skill = "Reap", Blade = Color3.fromRGB(180, 180, 190), Accent = Color3.fromRGB(120, 85, 55) },
	-- Uncommon
	{ Id = "SteelKatana", Name = "Steel Katana", Class = "Katana", Rarity = "Uncommon", Skill = "IaidoDash", Blade = Color3.fromRGB(220, 225, 235), Accent = Color3.fromRGB(60, 60, 70) },
	{ Id = "IronCleaver", Name = "Iron Cleaver", Class = "Greatsword", Rarity = "Uncommon", Skill = "GroundCleave", Blade = Color3.fromRGB(170, 175, 185), Accent = Color3.fromRGB(70, 70, 80) },
	{ Id = "TwinRevolvers", Name = "Twin Revolvers", Class = "Pistols", Rarity = "Uncommon", Skill = "BurstFire", Blade = Color3.fromRGB(60, 60, 70), Accent = Color3.fromRGB(190, 150, 90) },
	{ Id = "IronKnuckles", Name = "Iron Knuckles", Class = "Glove", Rarity = "Uncommon", Skill = "ChakraPalm", Blade = Color3.fromRGB(150, 155, 165), Accent = Color3.fromRGB(90, 90, 100) },
	{ Id = "ReaperSickle", Name = "Reaper's Sickle", Class = "Scythe", Rarity = "Uncommon", Skill = "Reap", Blade = Color3.fromRGB(200, 200, 215), Accent = Color3.fromRGB(50, 40, 50) },
	-- Rare
	{ Id = "CrimsonKatana", Name = "Crimson Katana", Class = "Katana", Rarity = "Rare", Skill = "IaidoDash", Blade = Color3.fromRGB(230, 90, 90), Accent = Color3.fromRGB(40, 20, 25), Glow = Color3.fromRGB(255, 80, 80) },
	{ Id = "StoneBuster", Name = "Stone Buster", Class = "Greatsword", Rarity = "Rare", Skill = "GroundCleave", Blade = Color3.fromRGB(140, 130, 120), Accent = Color3.fromRGB(255, 170, 60), Glow = Color3.fromRGB(255, 170, 60) },
	{ Id = "PlasmaPistols", Name = "Plasma Pistols", Class = "Pistols", Rarity = "Rare", Skill = "BurstFire", Blade = Color3.fromRGB(40, 45, 60), Accent = Color3.fromRGB(0, 230, 255), Glow = Color3.fromRGB(0, 230, 255) },
	{ Id = "ChakraGloves", Name = "Chakra Gloves", Class = "Glove", Rarity = "Rare", Skill = "ChakraPalm", Blade = Color3.fromRGB(40, 60, 110), Accent = Color3.fromRGB(110, 200, 255), Glow = Color3.fromRGB(110, 200, 255) },
	{ Id = "SpiritFinger", Name = "Spirit Finger", Class = "FingerGun", Rarity = "Rare", Skill = "ChargedShot", Blade = Color3.fromRGB(120, 230, 255), Accent = Color3.fromRGB(120, 230, 255), Glow = Color3.fromRGB(120, 230, 255) },
	{ Id = "MoonScythe", Name = "Moon Scythe", Class = "Scythe", Rarity = "Rare", Skill = "Reap", Blade = Color3.fromRGB(200, 220, 255), Accent = Color3.fromRGB(40, 40, 70), Glow = Color3.fromRGB(170, 200, 255) },
	-- Epic
	{ Id = "Shusui", Name = "Shusui", Class = "Katana", Rarity = "Epic", Skill = "BlackBladeRush", Blade = Color3.fromRGB(25, 20, 25), Accent = Color3.fromRGB(150, 20, 30), Glow = Color3.fromRGB(255, 60, 80) },
	{ Id = "SpiritGun", Name = "Spirit Gun", Class = "FingerGun", Rarity = "Epic", Skill = "SpiritGun", Blade = Color3.fromRGB(80, 220, 255), Accent = Color3.fromRGB(80, 220, 255), Glow = Color3.fromRGB(80, 220, 255) },
	{ Id = "StormCleaver", Name = "Storm Cleaver", Class = "Greatsword", Rarity = "Epic", Skill = "StormCleave", Blade = Color3.fromRGB(190, 225, 255), Accent = Color3.fromRGB(60, 80, 140), Glow = Color3.fromRGB(120, 220, 255) },
	{ Id = "VoidReaper", Name = "Void Reaper", Class = "Scythe", Rarity = "Epic", Skill = "VoidHarvest", Blade = Color3.fromRGB(40, 20, 60), Accent = Color3.fromRGB(150, 60, 255), Glow = Color3.fromRGB(150, 60, 255) },
	-- Legendary (1 unique passive each)
	{ Id = "Enma", Name = "Enma", Class = "Katana", Rarity = "Legendary", Skill = "HellDragon", Blade = Color3.fromRGB(235, 230, 245), Accent = Color3.fromRGB(90, 30, 140), Glow = Color3.fromRGB(190, 80, 255), Passive = { Id = "Hellfire", Name = "Hellfire Edge", Desc = "20% chance on hit to burn (3 ticks of 30% damage)." } },
	{ Id = "Rasengan", Name = "Rasengan", Class = "Glove", Rarity = "Legendary", Skill = "Rasengan", Blade = Color3.fromRGB(40, 70, 140), Accent = Color3.fromRGB(110, 200, 255), Glow = Color3.fromRGB(110, 200, 255), Passive = { Id = "ChakraFlow", Name = "Chakra Flow", Desc = "All abilities cost 20% less stamina." } },
	{ Id = "DimensionalScythe", Name = "Dimensional Scythe", Class = "Scythe", Rarity = "Legendary", Skill = "DimensionalRift", Blade = Color3.fromRGB(20, 10, 40), Accent = Color3.fromRGB(170, 60, 255), Glow = Color3.fromRGB(200, 100, 255), Passive = { Id = "RiftHunger", Name = "Rift Hunger", Desc = "Kills restore 12 stamina." } },
	-- Mythic / Celestial (aura + signature skill)
	{ Id = "Zangetsu", Name = "Zangetsu", Class = "Greatsword", Rarity = "Mythic", Skill = "GetsugaTensho", Blade = Color3.fromRGB(25, 25, 30), Accent = Color3.fromRGB(230, 230, 240), Glow = Color3.fromRGB(80, 170, 255), Passive = { Id = "Released", Name = "Released Spirit", Desc = "+15% attack speed and Getsuga cooldown -20%." } },
	{ Id = "StarrkGuns", Name = "Starrk's Guns", Class = "Pistols", Rarity = "Mythic", Skill = "CeroMetralleta", Blade = Color3.fromRGB(220, 225, 235), Accent = Color3.fromRGB(90, 180, 255), Glow = Color3.fromRGB(90, 180, 255), Passive = { Id = "LoneWolf", Name = "Lone Wolf", Desc = "Basic shots pierce one extra enemy." } },
}
Config.WeaponById = {}
Config.WeaponsByRarity = {}
for _, w in ipairs(Config.Weapons) do
	Config.WeaponById[w.Id] = w
	Config.WeaponsByRarity[w.Rarity] = Config.WeaponsByRarity[w.Rarity] or {}
	table.insert(Config.WeaponsByRarity[w.Rarity], w)
end
Config.StarterWeapon = "TrainingKatana"

-- Enemy weapon drops (rolled with the rarity table above, luck applies)
Config.WeaponDropChance = { Normal = 0.02, Elite = 0.15, Boss = 0.35, Tower = 0.2 }

---------------------------------------------------------------------
-- CHESTS / GACHA
---------------------------------------------------------------------
Config.Chests = {
	{ Id = "Basic", Name = "Weapon Chest", MinRarity = "Common", CoinCost = 2500, Color = Color3.fromRGB(200, 170, 120) },
	{ Id = "Uncommon", Name = "Uncommon Chest", MinRarity = "Uncommon", Key = "Uncommon", Color = Color3.fromRGB(85, 225, 110) },
	{ Id = "RareScroll", Name = "Rare+ Spin Scroll", MinRarity = "Rare", Key = "RareScroll", Color = Color3.fromRGB(70, 160, 255) },
	{ Id = "Legendary", Name = "Legendary Chest", MinRarity = "Legendary", Key = "Legendary", Color = Color3.fromRGB(255, 195, 45) },
}
Config.ChestById = {}
for _, c in ipairs(Config.Chests) do
	Config.ChestById[c.Id] = c
end
Config.KeyNames = { Uncommon = "Uncommon Chest Key", RareScroll = "Rare+ Spin Scroll", Legendary = "Legendary Chest Key" }

---------------------------------------------------------------------
-- PLAY-TIME REWARDS + DAILY STREAK
---------------------------------------------------------------------
Config.PlaytimeRewards = {
	{ Minutes = 5, Name = "100 Coins + Health Potion", Coins = 100, Potions = 1 },
	{ Minutes = 15, Name = "Uncommon Chest Key", Keys = { Uncommon = 1 } },
	{ Minutes = 30, Name = "2x Damage Boost (15 min)", DamageBoost = 15 * 60 },
	{ Minutes = 60, Name = "Rare+ Weapon Spin Scroll", Keys = { RareScroll = 1 } },
	{ Minutes = 120, Name = "Playtime Aura + Legendary Chest Key", Aura = "Playtime", Keys = { Legendary = 1 } },
}
Config.Daily = {
	BaseCoins = 150, -- * streak day (capped)
	MaxScaleDays = 7,
	CoinBonusPerDay = 0.05, -- +5% coins per streak day...
	MaxCoinBonus = 0.5, -- ...up to +50%
	WeeklyKey = "RareScroll", -- every 7th day in a row
}
Config.Potion = { Heal = 0.4, Cooldown = 15 }

---------------------------------------------------------------------
-- 2x POWER PURCHASES  (cost 3^n Robux, multiplier 2^n)
---------------------------------------------------------------------
-- Create one Developer Product per tier in the Creator Hub with the price
-- shown and paste its id here. Tier n costs 3^n Robux and sets your power
-- multiplier to 2^n. The power multiplier is applied AFTER the gameplay cap.
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
-- ENEMY LOOKS + ANIMATIONS
---------------------------------------------------------------------
-- Optional catalog ids: HairAccessory / HatAccessory are comma-separated
-- accessory ids, Shirt / Pants are clothing ids. Leave 0/"" to use the
-- built-in procedural anime hair + colored outfit.
-- Silhouette = the big readable shape that identifies the enemy type from
-- far away. Core = the glowing focal colour (eyes + chest core); the core
-- dims and flickers as the enemy loses HP, so no head health bar is needed.
-- Tiers inside a zone: stage 3+ adds armour plating, stage 4+ glowing runes,
-- bosses get everything. Elites swap to a dark-gold palette.
Config.EnemyLooks = {
	[1] = { Hair = "Spiky", HairColor = Color3.fromRGB(255, 200, 60), Skin = Color3.fromRGB(255, 220, 190), Shirt = Color3.fromRGB(40, 40, 60), Pants = Color3.fromRGB(30, 30, 40), Extra = "Headband", Silhouette = "Brawler", Core = Color3.fromRGB(120, 255, 150) },
	[2] = { Hair = "Long", HairColor = Color3.fromRGB(220, 40, 60), Skin = Color3.fromRGB(240, 200, 170), Shirt = Color3.fromRGB(230, 230, 235), Pants = Color3.fromRGB(40, 40, 50), Extra = "Horns", Silhouette = "Oni", Core = Color3.fromRGB(255, 70, 70) },
	[3] = { Hair = "Spiky", HairColor = Color3.fromRGB(90, 60, 40), Skin = Color3.fromRGB(200, 160, 120), Shirt = Color3.fromRGB(200, 120, 40), Pants = Color3.fromRGB(70, 60, 50), Extra = "Headband", Silhouette = "Golem", Core = Color3.fromRGB(255, 170, 60) },
	[4] = { Hair = "Bun", HairColor = Color3.fromRGB(30, 30, 40), Skin = Color3.fromRGB(250, 215, 185), Shirt = Color3.fromRGB(60, 80, 160), Pants = Color3.fromRGB(30, 30, 50), Extra = "Mask", Silhouette = "Ronin", Core = Color3.fromRGB(110, 150, 255) },
	[5] = { Hair = "Long", HairColor = Color3.fromRGB(240, 240, 250), Skin = Color3.fromRGB(245, 215, 195), Shirt = Color3.fromRGB(120, 40, 180), Pants = Color3.fromRGB(30, 20, 40), Extra = "Crown", Silhouette = "Tyrant", Core = Color3.fromRGB(210, 90, 255) },
	[6] = { Hair = "Spiky", HairColor = Color3.fromRGB(0, 230, 255), Skin = Color3.fromRGB(230, 200, 180), Shirt = Color3.fromRGB(40, 45, 60), Pants = Color3.fromRGB(25, 25, 35), Extra = "Visor", Silhouette = "Drone", Core = Color3.fromRGB(255, 170, 60) },
	[7] = { Hair = "Bun", HairColor = Color3.fromRGB(255, 120, 200), Skin = Color3.fromRGB(240, 210, 190), Shirt = Color3.fromRGB(60, 60, 80), Pants = Color3.fromRGB(30, 30, 40), Extra = "Visor", Silhouette = "Mech", Core = Color3.fromRGB(120, 200, 255) },
	[8] = { Hair = "Spiky", HairColor = Color3.fromRGB(40, 40, 50), Skin = Color3.fromRGB(220, 190, 170), Shirt = Color3.fromRGB(20, 20, 25), Pants = Color3.fromRGB(20, 20, 25), Extra = "Mask", Silhouette = "Shinobi", Core = Color3.fromRGB(255, 60, 200) },
	[9] = { Hair = "Long", HairColor = Color3.fromRGB(0, 255, 180), Skin = Color3.fromRGB(235, 205, 185), Shirt = Color3.fromRGB(30, 60, 60), Pants = Color3.fromRGB(20, 30, 30), Extra = "Visor", Silhouette = "Warden", Core = Color3.fromRGB(0, 255, 180) },
	[10] = { Hair = "Spiky", HairColor = Color3.fromRGB(255, 60, 60), Skin = Color3.fromRGB(245, 215, 195), Shirt = Color3.fromRGB(150, 20, 30), Pants = Color3.fromRGB(30, 20, 20), Extra = "Crown", Silhouette = "Admiral", Core = Color3.fromRGB(255, 50, 70) },
}
Config.EliteLook = {
	Palette = Color3.fromRGB(38, 32, 28), -- clothes are pulled toward this dark tone
	Trim = Color3.fromRGB(255, 205, 80), -- plating, runes, eyes and core
}
Config.EnemyCatalog = {
	-- [stageIndex] = { HairAccessory = "", HatAccessory = "", Shirt = 0, Pants = 0, Face = 0 },
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
	-- Basic attack rhythm: anticipation (lean back, eyes flare) -> strike ->
	-- recovery (slumped, core dim). Enemies take extra damage while recovering.
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
