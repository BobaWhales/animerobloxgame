--!nonstrict
-- Actions (ModuleScript) -> ServerScriptService/Server/Actions
-- Handles every client request (forge, sell, upgrade, rebirth, race reroll,
-- overdrive, codes, teleports, shop, dungeon, boss rush, index) with
-- server-side validation.

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
local Forge = require(script.Parent:WaitForChild("Forge"))
local DungeonService = require(script.Parent:WaitForChild("DungeonService"))

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
	local s = DataService.Session(player)
	hum.WalkSpeed = Stats.WalkSpeed(player) * (s and s.AdminSpeed and 3 or 1)
end

---------------------------------------------------------------------
local handlers = {}

handlers.Collect = function(player, id)
	Loot.Collect(player, id)
end

-- payload = { Ores = {...}, Catalyst = key? }  (see Forge.luau)
handlers.Forge = function(player, payload)
	if not near(player, map.Forge, 40) then
		Net.Notify(player, "Stand next to the Soul Forge at spawn to forge weapons.", RED, "Error")
		return
	end
	Forge.Craft(player, payload)
end

handlers.Sell = function(player, oreId)
	if not near(player, map.Sell, 30) then
		Net.Notify(player, "Visit the Sell stall at spawn to sell ore.", RED, "Error")
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
	data.Rerolls += Config.Rebirth.RerollReward
	TowerService.Leave(player)
	Util.Teleport(player, map.HubCFrame, "Spawn")
	Net.FXAll("Rebirth", { Player = player, Rebirths = data.Rebirths })
	Cosmetics.Apply(player)
	DataService.MarkDirty(player)
end

-- Ascension: needs Config.AscendReq rebirths. Resets rebirths, Power and
-- Coins for a huge permanent multiplier (x8 Power, x4 Coins each).
handlers.Ascend = function(player)
	local data = DataService.Get(player)
	local req = Config.AscendReq(data.Ascensions)
	if data.Rebirths < req then
		Net.Notify(player, "Ascending needs " .. req .. " Rebirths.", RED, "Error")
		return
	end
	data.Ascensions += 1
	data.Rebirths = 0
	data.Power = 0
	data.Coins = 0
	data.Rerolls += Config.Ascension.Rerolls
	local cat = Config.Ascension.Catalyst
	data.Keys[cat] = (data.Keys[cat] or 0) + 1
	TowerService.Leave(player)
	Util.Teleport(player, map.HubCFrame, "Spawn")
	Net.FXAll("Ascend", { Player = player, Ascensions = data.Ascensions })
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
	if type(dest) ~= "string" then
		return
	end
	if TowerService.InTower(player) then
		-- the HOME button also works as "leave Boss Rush"
		if dest == "Hub" then
			TowerService.Leave(player)
		else
			Net.Notify(player, "Leave the Boss Rush first.", RED, "Error")
		end
		return
	end
	-- leaving the dungeon ends the run (back to floor 1 / a checkpoint)
	if DungeonService.InRun(player) then
		DungeonService.End(player, dest == "Hub" and "Home" or "Left")
	end
	if dest == "Hub" then
		Util.Teleport(player, map.HubCFrame, "Spawn")
	elseif dest == "Train" then
		Util.Teleport(player, map.TrainCFrame, "Training Grounds")
	elseif dest == "Tower" then
		Util.Teleport(player, map.TowerCFrame, "Boss Rush")
	elseif dest == "Dungeon" then
		Util.Teleport(player, map.DungeonCFrame, "The Dungeon")
	end
end

-- Start a dungeon run at floor 1 or an unlocked checkpoint.
handlers.DungeonStart = function(player, floor)
	if not near(player, map.DungeonPrompt and map.DungeonPrompt.Parent, 40) and not DungeonService.InRun(player) then
		Net.Notify(player, "Go to the Dungeon gate (north of spawn) to start a run.", RED, "Error")
		return
	end
	DungeonService.Start(player, floor)
end

handlers.UnlockIndex = function(player, oreId)
	Loot.UnlockIndex(player, oreId)
end

handlers.ScrapBulk = function(player, maxRarity)
	Weapons.ScrapBulk(player, tonumber(maxRarity) or 2)
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
	for _, key in ipairs({ "Music", "SFX", "AutoEquip", "Shake", "DamageNumbers" }) do
		if settings[key] ~= nil then
			data.Settings[key] = settings[key] == true
		end
	end
	DataService.MarkDirty(player)
end

-- World map fog of war (cosmetic). Only known region keys are accepted.
handlers.Explore = function(player, key)
	local data = DataService.Get(player)
	if type(key) ~= "string" or not Config.ExploreKeys[key] or data.Explored[key] then
		return
	end
	data.Explored[key] = true
	DataService.MarkDirty(player)
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

handlers.EquipArmor = function(player, uid)
	Weapons.EquipArmor(player, uid)
	Actions.ApplyCharacter(player)
end

handlers.ScrapArmor = function(player, uid)
	Weapons.ScrapArmor(player, uid)
end

handlers.BuyPower = function(player)
	Monetization.PromptPowerTier(player)
end

---------------------------------------------------------------------
-- CUSTOM PROXIMITY PROMPTS (client fires Interact after Triggered)
---------------------------------------------------------------------
local PANEL_FOR = { Upgrades = "Upgrades", Race = "Race", Rebirth = "Rebirth", Index = "Index", Forge = "Forge", Dungeon = "Dungeon" }

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
	if action == "Sell" then
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
