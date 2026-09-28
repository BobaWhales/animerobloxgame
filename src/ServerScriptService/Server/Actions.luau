--!nonstrict
-- Actions (ModuleScript) -> ServerScriptService/Server/Actions
-- Handles every client request (forge, sell, upgrade, rebirth, race reroll,
-- overdrive, codes, teleports, shop, tower) with server-side validation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local Cosmetics = require(script.Parent:WaitForChild("Cosmetics"))
local Monetization = require(script.Parent:WaitForChild("Monetization"))
local TowerService = require(script.Parent:WaitForChild("TowerService"))
local Util = require(script.Parent:WaitForChild("Util"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))

local Actions = {}
local map = nil

local RED = Color3.fromRGB(255, 110, 90)

local function near(player: Player, part: BasePart?, dist: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root ~= nil and part ~= nil and (root.Position - part.Position).Magnitude <= dist
end

function Actions.ApplyCharacter(player: Player)
	local data = DataService.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not hum then
		return
	end
	hum.WalkSpeed = Stats.WalkSpeed(player)
end

---------------------------------------------------------------------
local handlers = {}

handlers.Collect = function(player, id)
	Loot.Collect(player, id)
end

handlers.Forge = function(player, oreId)
	if not near(player, map.Forge, 32) then
		Net.Notify(player, "Bring your ore to the Forge cauldron in the Hub!", RED, "Error")
		return
	end
	if type(oreId) ~= "string" then
		oreId = nil
	end
	if Loot.Forge(player, oreId) <= 0 then
		Net.Notify(player, "No ore to forge. Go slay monsters in the Dungeon!", RED, "Error")
	end
end

handlers.Sell = function(player, oreId)
	if not near(player, map.Sell, 30) then
		Net.Notify(player, "Visit the Sell stall in the Hub to sell ore.", RED, "Error")
		return
	end
	if type(oreId) ~= "string" then
		oreId = nil
	end
	if Loot.Sell(player, oreId) <= 0 then
		Net.Notify(player, "Nothing to sell.", RED, "Error")
	end
end

handlers.Upgrade = function(player, key)
	local data = DataService.Get(player)
	if type(key) ~= "string" or not Config.Upgrades[key] then
		return
	end
	local level = data.Upgrades[key]
	local cost = Stats.UpgradeCost(key, level)
	if not cost then
		Net.Notify(player, Config.Upgrades[key].Name .. " is maxed!", RED, "Error")
		return
	end
	if data.Coins < cost then
		Net.Notify(player, "Not enough Coins (" .. Format.Abbrev(cost) .. " needed).", RED, "Error")
		return
	end
	data.Coins -= cost
	data.Upgrades[key] = level + 1
	Net.FX(player, "Upgraded", { Key = key, Level = level + 1 })
	DataService.MarkDirty(player)
end

handlers.Rebirth = function(player)
	local data = DataService.Get(player)
	local req = Stats.RebirthReq(data)
	if data.Power < req then
		Net.Notify(player, "You need " .. Format.Abbrev(req) .. " Power to Rebirth.", RED, "Error")
		return
	end
	local keep = Stats.Race(data).Id == "Isekai" and math.floor(data.Power * 0.1) or 0
	data.Rebirths += 1
	data.Power = keep
	data.Coins = 0
	data.Rerolls += Config.RebirthRerollReward
	TowerService.Leave(player)
	Util.Teleport(player, map.HubCFrame, "Hub")
	Net.FXAll("Rebirth", { Player = player, Rebirths = data.Rebirths })
	Cosmetics.Apply(player)
	DataService.MarkDirty(player)
end

function Actions.RollRace(player: Player, initial: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not initial then
		if data.Rerolls <= 0 then
			Net.Notify(player, "No Race Rerolls left! Get more from bosses, rebirths, codes or the Shop.", RED, "Error")
			return
		end
		data.Rerolls -= 1
	end
	local raceId, tierId = Stats.RollRace(player)
	data.Race = raceId
	data.RaceTier = tierId
	Net.FX(player, "RaceRoll", { Race = raceId, Tier = tierId, Initial = initial })
	-- let the slot-machine animation finish before auras appear
	task.delay(2.6, function()
		if player.Parent then
			Cosmetics.Apply(player)
			Actions.ApplyCharacter(player)
			if raceId == "MainCharacter" or tierId == "Mythic" then
				Net.FXAll("Transform", { Player = player, Kind = "Awaken", Color = Config.RaceById[raceId].Color })
			end
		end
	end)
	DataService.MarkDirty(player)
end

handlers.Reroll = function(player)
	Actions.RollRace(player, false)
end

handlers.Overdrive = function(player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if Stats.OverdriveActive(player) then
		Net.Notify(player, "Overdrive is already active!", RED, "Error")
		return
	end
	if data.Overdrive <= 0 then
		Net.Notify(player, "No Overdrive potions. Get them from codes or the Shop.", RED, "Error")
		return
	end
	data.Overdrive -= 1
	local duration = Stats.OverdriveDuration(player)
	s.OverdriveEnd = Stats.Now() + duration
	Net.FXAll("Transform", { Player = player, Kind = "Overdrive", Color = Stats.Race(data).Color })
	Cosmetics.RefreshTransform(player)
	Actions.ApplyCharacter(player)
	DataService.MarkDirty(player)
end

handlers.Redeem = function(player, code)
	local data = DataService.Get(player)
	if type(code) ~= "string" or #code > 40 then
		return
	end
	code = string.upper((code:gsub("%s", "")))
	local grants = Config.Codes[code]
	if not grants then
		Net.Notify(player, "Invalid code.", RED, "Error")
		return
	end
	if data.Codes[code] then
		Net.Notify(player, "You already redeemed that code.", RED, "Error")
		return
	end
	data.Codes[code] = true
	local text = Monetization.Grant(player, grants)
	Net.FX(player, "Purchase", { Name = "Code " .. code, Text = text })
	DataService.MarkDirty(player)
end

handlers.Teleport = function(player, dest)
	local data = DataService.Get(player)
	if type(dest) ~= "string" then
		return
	end
	if TowerService.InTower(player) then
		Net.Notify(player, "Leave the Tower first.", RED, "Error")
		return
	end
	if dest == "Hub" then
		Util.Teleport(player, map.HubCFrame, "Hub")
		return
	end
	if not Stats.HasPass(player, "FastTravel") then
		Net.Notify(player, "Fast Travel gamepass needed. Use the portals in the Hub for free!", RED, "Error")
		return
	end
	if dest == "Train" then
		Util.Teleport(player, map.TrainCFrame, "Train Area")
	elseif dest == "Tower" then
		Util.Teleport(player, map.TowerCFrame, "Tower")
	elseif dest:sub(1, 6) == "Stage_" then
		local idx = tonumber(dest:sub(7))
		local stage = idx and Config.Stages[idx]
		if not stage then
			return
		end
		if not Stats.StageUnlocked(data, idx) then
			Net.Notify(player, "Stage " .. idx .. " is locked.", RED, "Error")
			return
		end
		local dungeon = map.Dungeons[stage.Zone]
		local info = dungeon and dungeon.Stages[idx]
		if info then
			Util.Teleport(player, info.Entry, "Stage " .. idx)
		end
	end
end

handlers.BuyPass = function(player, key)
	if type(key) == "string" then
		Monetization.PromptPass(player, key)
	end
end

handlers.BuyProduct = function(player, key)
	if type(key) == "string" then
		Monetization.PromptProduct(player, key)
	end
end

handlers.TowerStart = function(player)
	TowerService.Start(player)
end

handlers.TowerLeave = function(player)
	TowerService.Leave(player)
end

handlers.Settings = function(player, settings)
	local data = DataService.Get(player)
	if type(settings) ~= "table" then
		return
	end
	data.Settings.Music = settings.Music == true
	data.Settings.SFX = settings.SFX == true
end

-- First-time players get a free race roll once their client is ready.
function Actions.InitialRoll(player: Player, delay: number)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s or data.Race ~= "" or s.InitialRoll then
		return
	end
	s.InitialRoll = true
	task.delay(delay, function()
		if player.Parent and DataService.Get(player) then
			Actions.RollRace(player, true)
		end
	end)
end

handlers.Ready = function(player)
	DataService.MarkDirty(player)
	Actions.InitialRoll(player, 1.5)
end

---------------------------------------------------------------------
-- WEAPONS / CHESTS / POWER
---------------------------------------------------------------------
handlers.Equip = function(player, uid)
	Weapons.Equip(player, uid)
	Cosmetics.Apply(player)
end

handlers.Scrap = function(player, uid)
	Weapons.Scrap(player, uid)
end

function Actions.ChestCost(data, chest): number
	return math.floor((chest.CoinCost or 0) * (1 + data.Rebirths))
end

handlers.OpenChest = function(player, chestId)
	local data = DataService.Get(player)
	local chest = type(chestId) == "string" and Config.ChestById[chestId]
	if not chest then
		return
	end
	if chest.Key then
		if (data.Keys[chest.Key] or 0) <= 0 then
			Net.Notify(player, "You need a " .. Config.KeyNames[chest.Key] .. ". Earn them from play-time rewards!", RED, "Error")
			return
		end
		data.Keys[chest.Key] -= 1
	else
		local cost = Actions.ChestCost(data, chest)
		if data.Coins < cost then
			Net.Notify(player, "Not enough Coins (" .. Format.Abbrev(cost) .. " needed).", RED, "Error")
			return
		end
		data.Coins -= cost
	end
	local weaponId, rarityId = Weapons.Roll(chest.MinRarity, 1)
	local uid = Weapons.Add(player, weaponId, rarityId)
	Net.FX(player, "ChestResult", { Chest = chest.Id, Weapon = weaponId, Rarity = rarityId, Uid = uid })
	DataService.MarkDirty(player)
end

handlers.BuyPower = function(player)
	Monetization.PromptPowerTier(player)
end

---------------------------------------------------------------------
-- CUSTOM PROXIMITY PROMPTS (client fires Interact after Triggered)
---------------------------------------------------------------------
local PANEL_FOR = { Upgrades = "Upgrades", Race = "Race", Rebirth = "Rebirth", Index = "Index", Chests = "Chests" }

handlers.Interact = function(player, prompt)
	if typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return
	end
	if not prompt:IsDescendantOf(map.Root) then
		return
	end
	local parent = prompt.Parent
	local pos = parent and (parent:IsA("BasePart") and parent.Position or (parent:IsA("Attachment") and parent.WorldPosition))
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not pos or not root or (root.Position - pos).Magnitude > prompt.MaxActivationDistance + 6 then
		return
	end
	local action = prompt:GetAttribute("Action")
	if action == "Forge" then
		handlers.Forge(player, nil)
	elseif action == "Sell" then
		Net.FX(player, "OpenPanel", { Name = "Backpack", Mode = "Sell" })
	elseif action == "Tower" then
		TowerService.Start(player)
	elseif PANEL_FOR[action] then
		Net.FX(player, "OpenPanel", { Name = PANEL_FOR[action] })
	end
end

---------------------------------------------------------------------
local lastRequests: { [Player]: { number } } = {}

function Actions.Handle(player: Player, action, arg)
	if type(action) ~= "string" or not DataService.Get(player) then
		return
	end
	-- simple rate limit: 25 requests per second
	local t = os.clock()
	local list = lastRequests[player]
	if not list then
		list = {}
		lastRequests[player] = list
	end
	while list[1] and t - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list >= 25 then
		return
	end
	table.insert(list, t)

	local fn = handlers[action]
	if fn then
		local ok, err = pcall(fn, player, arg)
		if not ok then
			warn("[Actions] " .. action .. " failed: " .. tostring(err))
		end
	end
end

function Actions.PlayerRemoving(player: Player)
	lastRequests[player] = nil
end

function Actions.Init(m)
	map = m
	Net.Request.OnServerEvent:Connect(Actions.Handle)
	Net.Interact.OnServerEvent:Connect(function(player, prompt)
		Actions.Handle(player, "Interact", prompt)
	end)
end

return Actions
