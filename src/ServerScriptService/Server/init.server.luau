--!nonstrict
-- Server (Script) -> ServerScriptService/Server
-- Entry point. All the ModuleScripts listed in SETUP.md go INSIDE this Script.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local Net = require(script:WaitForChild("Net"))
local DataService = require(script:WaitForChild("DataService"))
local Stats = require(script:WaitForChild("Stats"))
local MapBuilder = require(script:WaitForChild("MapBuilder"))
local Weapons = require(script:WaitForChild("Weapons"))
local Playtime = require(script:WaitForChild("Playtime"))
local Cosmetics = require(script:WaitForChild("Cosmetics"))
local Loot = require(script:WaitForChild("Loot"))
local EnemyService = require(script:WaitForChild("EnemyService"))
local TowerService = require(script:WaitForChild("TowerService"))
local Combat = require(script:WaitForChild("Combat"))
local Monetization = require(script:WaitForChild("Monetization"))
local Actions = require(script:WaitForChild("Actions"))
local Util = require(script:WaitForChild("Util"))

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------
local map = MapBuilder.Build()
task.spawn(EnemyService.Init, map) -- builds enemy rigs (yields), players can join meanwhile
TowerService.Init(map)
Combat.Init(map)
Actions.Init(map)


---------------------------------------------------------------------
-- PORTALS
---------------------------------------------------------------------
-- Prompts use Style = Custom. The client draws them (Client/PromptUI) and
-- fires Remotes.Interact on Triggered; Actions validates and runs them.

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function portalDebounce(player: Player): boolean
	local s = DataService.Session(player)
	if not s or os.clock() - s.LastPortal < 2 then
		return false
	end
	s.LastPortal = os.clock()
	return true
end

for zoneId, portal in pairs(map.Portals) do
	local zone = Config.Zones[zoneId]
	if not zone.ComingSoon then
		portal.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or not portalDebounce(player) then
				return
			end
			local data = DataService.Get(player)
			if not data then
				return
			end
			if data.Blade < (zone.BladeReq or 0) then
				Net.Notify(player, zone.Name .. " needs Blade +" .. zone.BladeReq .. ". Forge more ore!", Color3.fromRGB(255, 110, 90), "Error")
				return
			end
			local dungeon = map.Dungeons[zoneId]
			if dungeon then
				Util.Teleport(player, dungeon.StartCFrame, zone.Name)
			end
		end)
	end
end

for _, ret in ipairs(CollectionService:GetTagged("ReturnPortal")) do
	ret.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and portalDebounce(player) then
			Util.Teleport(player, map.HubCFrame, "Hub")
		end
	end)
end

---------------------------------------------------------------------
-- SYNC + LEADERSTATS
---------------------------------------------------------------------
local function setStat(player: Player, name: string, value: string)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	if v then
		(v :: StringValue).Value = value
	end
end

DataService.OnFlush = function(player: Player)
	local snap = Stats.Snapshot(player)
	if snap then
		Net.Sync:FireClient(player, snap)
		setStat(player, "Power", Format.Abbrev(snap.Power))
		setStat(player, "Forge", "+" .. Format.Abbrev(snap.Blade))
		setStat(player, "Rebirths", Format.Abbrev(snap.Rebirths))
	end
end

Monetization.OnPassesChanged = function(player: Player)
	Cosmetics.Apply(player)
	Actions.ApplyCharacter(player)
end

Playtime.OnCosmeticsChanged = function(player: Player)
	Cosmetics.Apply(player)
end

EnemyService.OnZenkai = function(player: Player)
	Cosmetics.RefreshTransform(player)
end

---------------------------------------------------------------------
-- PLAYERS
---------------------------------------------------------------------
local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return
	end
	while player.Parent and not DataService.IsLoaded(player) do
		task.wait(0.2)
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	task.wait(0.1)
	Weapons.EnsureStarter(player)
	Weapons.Refresh(player)
	Cosmetics.Apply(player)
	Actions.ApplyCharacter(player)
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Power", "Forge", "Rebirths" }) do
		local v = Instance.new("StringValue")
		v.Name = name
		v.Value = "0"
		v.Parent = ls
	end
	ls.Parent = player

	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)

	DataService.Load(player)
	Monetization.LoadPasses(player)
	Weapons.EnsureStarter(player)
	Playtime.OnJoin(player)
	player:SetAttribute("Stamina", Config.Balance.MaxStamina)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	DataService.MarkDirty(player)
	Actions.InitialRoll(player, 5)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	TowerService.PlayerRemoving(player)
	Actions.PlayerRemoving(player)
	DataService.Release(player)
end)

---------------------------------------------------------------------
-- BUFF TIMERS + DROP CLEANUP
---------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local s = DataService.Session(player)
			if s then
				local active = Stats.OverdriveActive(player) or Stats.ZenkaiActive(player)
				if active ~= (s.TransformShown == true) then
					s.TransformShown = active
					Cosmetics.RefreshTransform(player)
					Actions.ApplyCharacter(player)
					DataService.MarkDirty(player)
				end
				Loot.CleanupDrops(player)
			end
		end
	end
end)

---------------------------------------------------------------------
-- GLOBAL LEADERBOARD (Top Blade levels)
---------------------------------------------------------------------
task.spawn(function()
	local ok, board = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)
	if not ok then
		map.LeaderboardText.Text = "Leaderboard needs\nStudio API access"
		return
	end
	local names = {}
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.Get(player)
			if data then
				pcall(function()
					board:SetAsync(tostring(player.UserId), math.floor(data.Blade))
				end)
			end
		end
		local success, pages = pcall(function()
			return board:GetSortedAsync(false, 10)
		end)
		if success and pages then
			local lines = {}
			for rank, entry in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(entry.key)
				local name = userId and names[userId]
				if userId and not name then
					local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
					name = okName and result or ("User " .. entry.key)
					names[userId] = name
				end
				local color = rank == 1 and "#ffd75a" or (rank == 2 and "#dfe6f0" or (rank == 3 and "#ff9e5a" or "#ffffff"))
				table.insert(lines, string.format('<font color="%s">%d. %s</font>  +%s', color, rank, name or "?", Format.Abbrev(entry.value)))
			end
			map.LeaderboardText.Text = #lines > 0 and table.concat(lines, "\n") or "No blades forged yet!"
		else
			map.LeaderboardText.Text = "Leaderboard unavailable\n(enable Studio API access)"
		end
		task.wait(90)
	end
end)

print(("[%s] server ready"):format(Config.GameName))
