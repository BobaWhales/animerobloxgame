--!nonstrict
-- DataService (ModuleScript) -> ServerScriptService/Server/DataService
-- DataStore-backed player profiles + per-session runtime state.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("Config"))

local DataService = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable (enable Studio API access to save):", result)
	end
end

local DEFAULT = {
	Version = 1,
	Power = 0,
	Coins = 0,
	Blade = 0,
	Rebirths = 0,
	Runes = 0,
	Backpack = {}, -- [oreId] = count
	Upgrades = { Backpack = 0, Luck = 0, Training = 0 },
	Race = "",
	RaceTier = "",
	Rerolls = Config.StartingRerolls,
	Overdrive = Config.Overdrive.StartingPotions,
	Index = {}, -- [oreId] = true
	Kills = 0,
	TowerBest = 0, -- best Boss Rush wave
	-- the Path
	Stage = 0, -- highest stage cleared
	StageKills = 0, -- kills toward clearing the next stage
	Ascensions = 0,
	Codes = {}, -- [CODE] = true
	StarterPack = false,
	Receipts = {}, -- recent purchase ids (dedupe)
	Settings = { Music = true, SFX = true },
	-- weapons / loot
	Weapons = {}, -- ["w1"] = { W = weaponId, R = rarityId, E = { [effectId] = points } }
	NextWeaponId = 1,
	Equipped = "",
	Armors = {}, -- ["a1"] = { A = armorId, R = rarityId }
	NextArmorId = 1,
	EquippedArmor = "",
	Recipes = {}, -- [recipeKey] = true once discovered
	Keys = { Uncommon = 0, RareScroll = 0, Legendary = 0 },
	Potions = 1,
	BoostEnds = 0, -- 2x damage boost end (server time)
	PowerTier = 0, -- purchased 2x power tiers (multiplier = 2^PowerTier)
	-- retention
	TotalPlaytime = 0,
	LastLoginDay = 0,
	Streak = 0,
	Cosmetics = { PlaytimeAura = false },
	Explored = { Hub = true }, -- world map fog of war
}

local profiles: { [Player]: any } = {}
local sessions: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}

DataService.OnFlush = nil :: ((Player) -> ())?

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = if type(v) == "table" then deepCopy(v) else v
	end
	return out
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then deepCopy(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" then
			reconcile(data[k], v)
		end
	end
end

local function newSession()
	return {
		LastSwing = 0,
		SwingCount = 0,
		OverdriveEnd = 0,
		ZenkaiEnd = 0,
		ZenkaiReady = 0,
		InvulnUntil = 0,
		Passes = {},
		Drops = {},
		NextDropId = 0,
		Tower = nil,
		LastFullNotify = 0,
		Pad = 0,
		Loaded = false,
		-- combat
		Stamina = Config.Balance.MaxStamina,
		LastStaminaSpend = 0,
		Cooldowns = {},
		Charge = {},
		LastAttack = 0,
		Combo = 0,
		LastPotion = 0,
		StunnedUntil = 0,
		-- retention
		SessionTime = 0,
		PlaytimeClaimed = {},
	}
end

function DataService.Load(player: Player)
	sessions[player] = newSession()
	local data = nil
	local success = store == nil -- no store (Studio without API) -> play with fresh data
	if store then
		for attempt = 1, 4 do
			local ok, result = pcall(function()
				return store:GetAsync("Player_" .. player.UserId)
			end)
			if ok then
				data = result
				success = true
				break
			end
			warn(("[Data] load attempt %d failed for %s: %s"):format(attempt, player.Name, tostring(result)))
			task.wait(attempt * 1.5)
		end
	end
	if type(data) ~= "table" then
		data = deepCopy(DEFAULT)
	end
	reconcile(data, DEFAULT)
	profiles[player] = data
	canSave[player] = success and store ~= nil
	sessions[player].Loaded = true
	if not success then
		warn("[Data] could not load " .. player.Name .. " - progress will NOT be saved this session to protect old data")
	end
	return data
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync("Player_" .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn("[Data] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Session(player: Player)
	return sessions[player]
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.MarkDirty(player: Player)
	dirty[player] = true
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	sessions[player] = nil
	canSave[player] = nil
	dirty[player] = nil
end

function DataService.All()
	return profiles
end

-- Flush dirty profiles to their clients once per frame (batches many changes).
RunService.Heartbeat:Connect(function()
	for player in pairs(dirty) do
		dirty[player] = nil
		if player.Parent and profiles[player] and DataService.OnFlush then
			DataService.OnFlush(player)
		end
	end
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(120)
		for player in pairs(profiles) do
			task.spawn(DataService.Save, player)
		end
	end
end)

game:BindToClose(function()
	local threads = 0
	for _, player in ipairs(Players:GetPlayers()) do
		threads += 1
		task.spawn(function()
			DataService.Save(player)
			threads -= 1
		end)
	end
	local start = os.clock()
	while threads > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return DataService
