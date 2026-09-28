--!nonstrict
-- Server (Script) -> ServerScriptService/Server
-- Entry point. All the ModuleScripts listed in SETUP.md go INSIDE this Script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local VFX = require(Shared:WaitForChild("VFX"))

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
local Admin = require(script:WaitForChild("Admin"))
local Leaderboards = require(script:WaitForChild("Leaderboards"))

---------------------------------------------------------------------
-- WORLD
---------------------------------------------------------------------
VFX.BuildLibrary() -- ReplicatedStorage.VFX: the editable effect hierarchy
local map = MapBuilder.Build()
task.spawn(EnemyService.Init, map) -- builds enemy rigs (yields), players can join meanwhile
TowerService.Init(map)
Combat.Init(map)
Actions.Init(map)
Admin.Init(map)
Leaderboards.Init(map)

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
		setStat(player, "Stage", tostring(snap.Stage))
		setStat(player, "Rebirths", (snap.Ascensions > 0 and ("A" .. snap.Ascensions .. " ") or "") .. Format.Abbrev(snap.Rebirths))
	end
end

Monetization.OnPassesChanged = function(player: Player)
	Cosmetics.Apply(player)
	Actions.ApplyCharacter(player)
end

Playtime.OnCosmeticsChanged = function(player: Player)
	Cosmetics.Apply(player)
end

Admin.OnApplyCharacter = function(player: Player)
	Actions.ApplyCharacter(player)
end

Admin.OnCosmetics = function(player: Player)
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
	Weapons.RefreshArmor(player)
	Cosmetics.Apply(player)
	Actions.ApplyCharacter(player)
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Power", "Stage", "Rebirths" }) do
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
	Admin.PlayerAdded(player)
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

print(("[%s] server ready"):format(Config.GameName))
