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
-- DAMAGE
---------------------------------------------------------------------
function Stats.DamageMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local mult = (race.Damage or 1) * Stats.Tier(data).Damage
	mult *= 1 + data.Rebirths * Config.RebirthDamageBonus
	mult *= 1 + data.Runes * Config.Tower.RuneDamageBonus
	if Stats.OverdriveActive(player) then
		mult *= Config.Overdrive.Damage
	end
	if race.Zenkai then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.MaxHealth > 0 then
			local missing = 1 - math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			mult *= 1 + missing -- up to 2x at 0 HP
		end
		if Stats.ZenkaiActive(player) then
			mult *= 2
		end
	end
	return mult
end

function Stats.Damage(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local base = (Config.BaseDamage + data.Blade) * (1 + data.Power / Config.PowerDamageDivisor)
	return base * Stats.DamageMult(player)
end

function Stats.CritChance(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local race = Stats.Race(data)
	return math.min(0.75, (Config.BaseCritChance + (race.Crit or 0)) * allStats(data))
end

---------------------------------------------------------------------
-- POWER / LUCK / COINS / BACKPACK / FORGE / SPEED
---------------------------------------------------------------------
function Stats.PowerMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local per = Stats.HasPass(player, "DoubleTraining") and 0.2 or 0.1
	local mult = (1 + data.Rebirths * Config.RebirthPowerBonus) * (1 + data.Upgrades.Training * per)
	mult *= (race.Power or 1) * allStats(data)
	if Stats.OverdriveActive(player) then
		mult *= Config.Overdrive.Power
	end
	return mult
end

function Stats.Luck(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local luck = (1 + data.Upgrades.Luck * 0.05) * (race.Luck or 1) * allStats(data)
	if Stats.HasPass(player, "DoubleLuck") then
		luck *= 2
	end
	return luck
end

function Stats.CoinMult(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return 1
	end
	local race = Stats.Race(data)
	local mult = (1 + data.Rebirths * Config.RebirthCoinBonus) * (race.Coins or 1) * allStats(data)
	if Stats.HasPass(player, "DoubleCoins") then
		mult *= 2
	end
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
	return mult
end

function Stats.BackpackMax(player: Player): number
	local data = DataService.Get(player)
	if not data then
		return Config.BaseBackpack
	end
	local cap = Config.BaseBackpack + data.Upgrades.Backpack * 10
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
	return math.floor(Config.RebirthBasePower * Config.RebirthPowerGrowth ^ data.Rebirths)
end

function Stats.UpgradeCost(key: string, level: number): number?
	local u = Config.Upgrades[key]
	if not u or level >= u.Max then
		return nil
	end
	return math.floor(u.Base * u.Growth ^ level)
end

function Stats.PadUnlocked(data, pad): boolean
	return data.Power >= pad.Power and data.Rebirths >= pad.Rebirths
end

function Stats.StageUnlocked(data, stageIndex: number): boolean
	local stage = Config.Stages[stageIndex]
	if not stage then
		return false
	end
	local zone = Config.Zones[stage.Zone]
	return data.Power >= stage.PowerReq and data.Blade >= (zone.BladeReq or 0)
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
		Derived = {
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
