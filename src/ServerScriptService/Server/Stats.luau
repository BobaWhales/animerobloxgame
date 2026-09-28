--!nonstrict
-- Stats (ModuleScript) -> ServerScriptService/Server/Stats
-- All formulas: damage, power gain, luck, coins, backpack, race rolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local Stats = {}

local function now()
	return workspace:GetServerTimeNow()
end
Stats.Now = now

function Stats.HasPass(player: Player, key: string): boolean
	local s = DataService.Session(player)
	return s ~= nil and s.Passes[key] == true
end

function Stats.Race(data)
	return Config.RaceById[data.Race] or Config.RaceById.Pirate
end

function Stats.Tier(data)
	return Config.RaceTierById[data.RaceTier] or Config.RaceTiers[1]
end

local function allStats(data): number
	local race = Stats.Race(data)
	return race.AllStats or 1
end

function Stats.OverdriveActive(player: Player): boolean
	local s = DataService.Session(player)
	return s ~= nil and s.OverdriveEnd > now()
end

function Stats.ZenkaiActive(player: Player): boolean
	local s = DataService.Session(player)
	return s ~= nil and s.ZenkaiEnd > now()
end

---------------------------------------------------------------------
-- GLOBAL EVENTS (admin abuse: 2x luck, 3x coins...)
---------------------------------------------------------------------
Stats.ActiveEvents = {} :: { [string]: { EndsAt: number, Mult: number } }

function Stats.EventMult(key: string): number
	local e = Stats.ActiveEvents[key]
	if e and e.EndsAt > now() then
		return e.Mult
	end
	return 1
end

---------------------------------------------------------------------
-- WEAPON + ARMOR
---------------------------------------------------------------------
-- Returns weaponDef, rarityDef, record (or starter defaults).
function Stats.Weapon(player: Player)
	local data = DataService.Get(player)
	local rec = data and data.Weapons[data.Equipped]
	local def = rec and Config.WeaponById[rec.W] or Config.WeaponById[Config.StarterWeapon]
	local rarity = rec and Config.WeaponRarityById[rec.R] or Config.WeaponRarities[1]
	return def, rarity, rec
end

-- Real value of an ore effect on the equipped weapon (0 if none).
function Stats.Effect(player: Player, effectId: string): number
	local _, _, rec = Stats.Weapon(player)
	local pts = rec and rec.E and rec.E[effectId]
	return pts and Config.EffectValue(effectId, pts) or 0
end

function Stats.HasPassive(player: Player, passiveId: string): boolean
	local def, rarity = Stats.Weapon(player)
	return rarity.Passive == true and def.Passive ~= nil and def.Passive.Id == passiveId
end

function Stats.Armor(player: Player)
	local data = DataService.Get(player)
	local rec = data and data.Armors[data.EquippedArmor]
	if not rec then
		return nil, nil, nil
	end
	return Config.ArmorById[rec.A], Config.WeaponRarityById[rec.R] or Config.WeaponRarities[1], rec
end

function Stats.ArmorBonus(player: Player, bonus: string): number
	local def, rarity = Stats.Armor(player)
	if def and rarity and def.Bonus == bonus then
		return Config.ArmorBonusValue(bonus, rarity.Index)
	end
	return 0
end

-- Damage reduction from armour (capped).
function Stats.Defense(player: Player): number
	local def, rarity = Stats.Armor(player)
	if not def or not rarity then
		return 0
	end
	local d = Config.ArmorDefense[rarity.Index] or 0
	d += Stats.ArmorBonus(player, "Guard")
	return math.min(d, Config.Balance.DefenseCap)
end

function Stats.AttackSpeed(player: Player): number
	local _, rarity = Stats.Weapon(player)
	local bonus = (rarity.AttackSpeed or 0) + Stats.Effect(player, "Haste")
	if Stats.HasPassive(player, "Released") then
		bonus += 0.15
	end
	if Stats.OverdriveActive(player) then
		bonus += 0.1
	end
	return math.min(bonus, Config.Balance.AttackSpeedCap)
end

function Stats.BoostActive(player: Player): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.BoostEnds > now()
end

function Stats.PowerTierMult(player: Player): number
	local data = DataService.Get(player)
	return Config.PowerTierMult(data and data.PowerTier or 0)
end

---------------------------------------------------------------------
-- DAMAGE
---------------------------------------------------------------------
-- Gameplay multipliers (race, skin, runes, buffs) are multiplied together
-- and HARD CAPPED at Config.Balance.DamageMultCap. The exponential growth
-- comes from Power (rebirths / ascensions / pads), which is not capped.
function Stats.GameplayMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local mult = (race.Damage or 1) * Stats.Tier(data).Damage
	mult *= 1 + data.Runes * Config.BossRush.RuneDamageBonus
	if Stats.OverdriveActive(player) then
		mult *= Config.Overdrive.Damage
	end
	if Stats.BoostActive(player) then
		mult *= 2
	end
	if race.Zenkai then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.MaxHealth > 0 then
			local missing = 1 - math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			mult *= 1 + missing
		end
		if Stats.ZenkaiActive(player) then
			mult *= 2
		end
	end
	return math.min(mult, Config.Balance.DamageMultCap)
end

-- Base hit damage for the equipped weapon (skill coefficients multiply this).
function Stats.Damage(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local def, rarity = Stats.Weapon(player)
	local class = Config.WeaponClasses[def.Class]
	local base = (Config.BaseDamage + data.Blade) * (1 + data.Power / Config.PowerDamageDivisor)
	base *= (class and class.Base or 1) * (1 + rarity.Damage) * (1 + Stats.Effect(player, "Heavy"))
	return base * Stats.GameplayMult(player) * Stats.PowerTierMult(player)
end

function Stats.CritChance(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local race = Stats.Race(data)
	local c = (Config.BaseCritChance + (race.Crit or 0)) * allStats(data) + Stats.Effect(player, "Crit")
	if Stats.HasPassive(player, "Moonlit") then
		c += 0.1
	end
	return math.min(0.6, c)
end

function Stats.CritMult(): number
	return math.min(Config.CritMultiplier, Config.Balance.CritMultCap)
end

function Stats.StaminaCost(player: Player, base: number): number
	local cost = base * Config.Balance.StaminaCostMult
	if Stats.HasPassive(player, "ChakraFlow") then
		cost *= 0.8
	end
	cost *= 1 - Stats.Effect(player, "Ki")
	cost *= 1 - Stats.ArmorBonus(player, "Stamina")
	return cost
end

function Stats.Cooldown(player: Player, skillId: string, base: number): number
	local cd = base * Config.Balance.CooldownMult
	if skillId == "GetsugaTensho" and Stats.HasPassive(player, "Released") then
		cd *= 0.8
	end
	if Stats.HasPassive(player, "Wisdom") then
		cd *= 0.85
	end
	cd *= 1 - Stats.Effect(player, "Chrono")
	return cd
end

---------------------------------------------------------------------
-- POWER / LUCK / COINS / BACKPACK / FORGE / SPEED  (exponential)
---------------------------------------------------------------------
function Stats.PrestigeMult(data, kind: string): number
	if kind == "Power" then
		return Config.Rebirth.PowerMult ^ data.Rebirths * Config.Ascension.PowerMult ^ data.Ascensions
	end
	return Config.Rebirth.CoinMult ^ data.Rebirths * Config.Ascension.CoinMult ^ data.Ascensions
end

function Stats.PowerMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local mult = Stats.PrestigeMult(data, "Power") * (1 + data.Upgrades.Training * Config.Upgrades.Training.Per)
	mult *= (race.Power or 1) * allStats(data)
	if Stats.HasPass(player, "DoubleTraining") then
		mult *= 2
	end
	if Stats.OverdriveActive(player) then
		mult *= Config.Overdrive.Power
	end
	mult *= 1 + Stats.ArmorBonus(player, "Power")
	return mult * Stats.EventMult("Power")
end

function Stats.Luck(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local luck = (1 + data.Upgrades.Luck * Config.Upgrades.Luck.Per) * (race.Luck or 1) * allStats(data)
	if Stats.HasPass(player, "DoubleLuck") then
		luck *= 2
	end
	luck *= (1 + Stats.Effect(player, "Greed")) * (1 + Stats.ArmorBonus(player, "Luck"))
	return luck * Stats.EventMult("Luck")
end

function Stats.CoinMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local mult = Stats.PrestigeMult(data, "Coins") * (race.Coins or 1) * allStats(data)
	if Stats.HasPass(player, "DoubleCoins") then
		mult *= 2
	end
	mult *= 1 + math.min(data.Streak * Config.Daily.CoinBonusPerDay, Config.Daily.MaxCoinBonus)
	mult *= 1 + Stats.Effect(player, "Fortune")
	-- Pirate crew aura: +10% if another Pirate is nearby
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				local od = DataService.Get(other)
				local oc = other.Character
				local orr = oc and oc:FindFirstChild("HumanoidRootPart")
				if od and od.Race == "Pirate" and orr and (orr.Position - root.Position).Magnitude < 30 then
					mult *= 1.1
					break
				end
			end
		end
	end
	return mult * Stats.EventMult("Coins")
end

function Stats.BackpackMax(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return Config.BaseBackpack
	end
	local cap = Config.BaseBackpack + data.Upgrades.Backpack * Config.Upgrades.Backpack.Per
	if Stats.HasPass(player, "ExtraBackpack") then
		cap = math.floor(cap * 1.5)
	end
	return cap
end

function Stats.BackpackCount(data): number
	local n = 0
	for _, c in pairs(data.Backpack) do
		n += c
	end
	return n
end

function Stats.ForgeMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	return (race.Forge or 1) * allStats(data)
end

function Stats.WalkSpeed(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 16
	end
	local race = Stats.Race(data)
	local speed = 16 * (race.Speed or 1) * math.min(allStats(data), 1.1)
	if Stats.OverdriveActive(player) then
		speed *= Config.Overdrive.Speed
	end
	if Stats.HasPassive(player, "Tailwind") then
		speed *= 1.15
	end
	speed *= 1 + Stats.ArmorBonus(player, "Speed")
	return speed
end

function Stats.OverdriveDuration(player: Player): number
	local data = DataService.Get(player)
	local d = Config.Overdrive.Duration
	if data then
		d *= Stats.Race(data).OverdriveDuration or 1
	end
	if Stats.HasPass(player, "DoubleOverdrive") then
		d *= 2
	end
	return d
end

function Stats.RebirthReq(data): number
	return Config.RebirthReq(data.Rebirths, data.Ascensions)
end

function Stats.UpgradeCost(key: string, level: number): number?
	if not Config.Upgrades[key] then
		return nil
	end
	return Config.UpgradeCost(key, level)
end

-- (ascensions, rebirths) compared in order, so pads stay unlocked after an
-- ascension resets your rebirth count.
function Stats.PadUnlocked(data, pad): boolean
	local a = data.Ascensions or 0
	if a ~= (pad.Ascensions or 0) then
		return a > (pad.Ascensions or 0)
	end
	return data.Rebirths >= (pad.Rebirths or 0)
end

-- A stage is open once the one before it is cleared.
function Stats.StageUnlocked(data, stageIndex: number): boolean
	return Config.Stages[stageIndex] ~= nil and data.Stage >= stageIndex - 1
end

---------------------------------------------------------------------
-- RACE ROLL (weighted; luck only nudges the Main Character tail)
---------------------------------------------------------------------
local function weightedPick(list, weightFn)
	local total = 0
	for _, item in ipairs(list) do
		total += weightFn(item)
	end
	local r = math.random() * total
	for _, item in ipairs(list) do
		r -= weightFn(item)
		if r <= 0 then
			return item
		end
	end
	return list[#list]
end
Stats.WeightedPick = weightedPick

function Stats.RollRace(player: Player)
	local data = DataService.Get(player)
	local mcBoost = 1
	if Stats.HasPass(player, "DoubleLuck") then
		mcBoost *= 1.5
	end
	if Stats.HasPass(player, "MCPity") then
		mcBoost *= 1.5
	end
	if data then
		mcBoost *= 1 + math.min(data.Upgrades.Luck * 0.01, 0.5)
	end
	local race = weightedPick(Config.Races, function(r)
		return if r.Id == "MainCharacter" then r.Weight * mcBoost else r.Weight
	end)
	local tier = weightedPick(Config.RaceTiers, function(t)
		return t.Weight
	end)
	return race.Id, tier.Id
end

---------------------------------------------------------------------
-- SNAPSHOT sent to the client
---------------------------------------------------------------------
function Stats.EventList()
	local list = {}
	for key, e in pairs(Stats.ActiveEvents) do
		if e.EndsAt > now() then
			list[key] = { EndsAt = e.EndsAt, Mult = e.Mult }
		end
	end
	return list
end

function Stats.Snapshot(player: Player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s then
		return nil
	end
	local costs = {}
	for key in pairs(Config.Upgrades) do
		costs[key] = Stats.UpgradeCost(key, data.Upgrades[key]) or -1
	end
	local tower = s.Tower
	return {
		Power = data.Power,
		Coins = data.Coins,
		Blade = data.Blade,
		Rebirths = data.Rebirths,
		Runes = data.Runes,
		Backpack = data.Backpack,
		BackpackCount = Stats.BackpackCount(data),
		BackpackMax = Stats.BackpackMax(player),
		Upgrades = data.Upgrades,
		UpgradeCosts = costs,
		Race = data.Race,
		RaceTier = data.RaceTier,
		Rerolls = data.Rerolls,
		Overdrive = data.Overdrive,
		OverdriveEnd = s.OverdriveEnd,
		ZenkaiEnd = s.ZenkaiEnd,
		Index = data.Index,
		Kills = data.Kills,
		TowerBest = data.TowerBest,
		Codes = data.Codes,
		StarterPack = data.StarterPack,
		Passes = s.Passes,
		Settings = data.Settings,
		RebirthReq = Stats.RebirthReq(data),
		Tower = tower and { Floor = tower.Floor, EndsAt = tower.EndsAt, Active = tower.Active } or nil,
		Weapons = data.Weapons,
		Equipped = data.Equipped,
		Keys = data.Keys,
		Potions = data.Potions,
		BoostEnds = data.BoostEnds,
		PowerTier = data.PowerTier,
		Streak = data.Streak,
		TotalPlaytime = data.TotalPlaytime,
		Cosmetics = data.Cosmetics,
		Explored = data.Explored,
		PlaytimeClaimed = s.PlaytimeClaimed,
		Stage = data.Stage,
		StageKills = data.StageKills,
		Ascensions = data.Ascensions,
		AscendReq = Config.AscendReq(data.Ascensions),
		Armors = data.Armors,
		EquippedArmor = data.EquippedArmor,
		Recipes = data.Recipes,
		Events = Stats.EventList(),
		IsAdmin = player:GetAttribute("IsAdmin") == true,
		Derived = {
			Defense = Stats.Defense(player),
			PowerMult = Stats.PowerTierMult(player),
			GameplayMult = Stats.GameplayMult(player),
			AttackSpeed = Stats.AttackSpeed(player),
			Damage = Stats.Damage(player),
			PowerPerSwing = Config.ClickPower * Stats.PowerMult(player),
			Luck = Stats.Luck(player),
			CoinMult = Stats.CoinMult(player),
			Crit = Stats.CritChance(player),
			ForgeMult = Stats.ForgeMult(player),
		},
	}
end

return Stats
