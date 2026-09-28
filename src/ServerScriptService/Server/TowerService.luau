--!nonstrict
-- TowerService (ModuleScript) -> ServerScriptService/Server/TowerService
-- Infinite Tower: a private arena per player. Beat the floor Guardian
-- before the timer runs out to earn Coins, Runes (+2% dmg each) and ore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local Util = require(script.Parent:WaitForChild("Util"))

local TowerService = {}

local map = nil
local usedSlots = {}
local ARENA_R = 34

local function allocSlot(): number
	local i = 1
	while usedSlots[i] do
		i += 1
	end
	usedSlots[i] = true
	return i
end

local function buildArena(slot: number)
	local center = Vector3.new(3000 + slot * 300, 300, 0)
	local m = Instance.new("Model")
	m.Name = "Arena_" .. slot
	local function P(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in pairs(props) do
			(p :: any)[k] = v
		end
		p.Parent = m
		return p
	end
	local flat = CFrame.Angles(0, 0, math.rad(90))
	P({ Name = "Floor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, ARENA_R * 2 + 6, ARENA_R * 2 + 6), CFrame = CFrame.new(center - Vector3.new(0, 1, 0)) * flat, Color = Color3.fromRGB(45, 35, 70), Material = Enum.Material.Slate })
	P({ Name = "Glyph", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, ARENA_R * 1.4, ARENA_R * 1.4), CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)) * flat, Color = Color3.fromRGB(190, 110, 255), Material = Enum.Material.Neon, Transparency = 0.75, CanCollide = false })
	P({ Name = "Edge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, ARENA_R * 2 + 6.4, ARENA_R * 2 + 6.4), CFrame = CFrame.new(center - Vector3.new(0, 0.3, 0)) * flat, Color = Color3.fromRGB(210, 130, 255), Material = Enum.Material.Neon })
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * (ARENA_R + 1), 0, math.sin(a) * (ARENA_R + 1))
		P({ Name = "Pillar", Size = Vector3.new(3, 22, 3), CFrame = CFrame.new(pos + Vector3.new(0, 11, 0)), Color = Color3.fromRGB(70, 55, 100), Material = Enum.Material.Marble })
		local c = P({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(pos + Vector3.new(0, 23, 0)), Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon, CanCollide = false })
		VFX.MakeEmitter("Fire", Color3.fromRGB(190, 110, 255), c, 12)
	end
	-- invisible wall so nobody falls off
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * (ARENA_R + 3), 10, math.sin(a) * (ARENA_R + 3))
		P({ Name = "Barrier", Size = Vector3.new(15, 24, 1), CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), Transparency = 1 })
	end
	m.Parent = map.TowerArenas
	return m, center
end

local function oreTable(floor: number)
	if floor < 5 then
		return Config.Stages[3].Drops
	elseif floor < 10 then
		return Config.Stages[4].Drops
	elseif floor < 20 then
		return Config.Stages[7].Drops
	end
	return Config.Stages[9].Drops
end

local function floorColor(floor: number): Color3
	return Color3.fromHSV((floor * 0.13) % 1, 0.7, 1)
end

local function cleanup(player: Player, run)
	if run.Guardian and not run.Guardian.Dead then
		run.Guardian.Dead = true
		local idx = table.find(EnemyService.Active, run.Guardian)
		if idx then
			table.remove(EnemyService.Active, idx)
		end
		run.Guardian.Model:Destroy()
	end
	if run.Arena then
		run.Arena:Destroy()
	end
	usedSlots[run.Slot] = nil
	local s = DataService.Session(player)
	if s and s.Tower == run then
		s.Tower = nil
		DataService.MarkDirty(player)
	end
end

local function finish(player: Player, run, state: string)
	if not run.Active then
		return
	end
	run.Active = false
	Net.FX(player, "Tower", { State = state, Floor = run.Floor })
	task.delay(state == "Leave" and 0.2 or 2.2, function()
		if player.Parent and player.Character and map then
			Util.Teleport(player, map.TowerCFrame, "Tower")
		end
		cleanup(player, run)
	end)
end

local startFloor

local function onWin(player: Player, run)
	local data = DataService.Get(player)
	if not data or not run.Active then
		return
	end
	local floor = run.Floor
	local coins = math.floor(Config.Tower.CoinBase * floor ^ 1.6 * Stats.CoinMult(player))
	data.Coins += coins
	data.Runes += Config.Tower.RunesPerFloor
	data.TowerBest = math.max(data.TowerBest, floor)
	local drops = oreTable(floor)
	local luck = Stats.Luck(player)
	for i = 1, 2 + math.floor(floor / 5) do
		local oreId = (floor % 25 == 0 and i == 1) and "RiftCore" or Loot.RollOre(drops, luck)
		local a = math.random() * math.pi * 2
		Loot.Drop(player, oreId, run.Center + Vector3.new(math.cos(a) * 6, 1.2, math.sin(a) * 6))
	end
	DataService.MarkDirty(player)
	Net.FX(player, "Tower", { State = "Win", Floor = floor, Coins = coins, Runes = Config.Tower.RunesPerFloor, Text = "+" .. Format.Abbrev(coins) .. " Coins  +" .. Config.Tower.RunesPerFloor .. " Rune" })
	run.Paused = true
	task.delay(4, function()
		if run.Active and player.Parent then
			run.Floor += 1
			startFloor(player, run)
		end
	end)
end

startFloor = function(player: Player, run)
	local floor = run.Floor
	local hp = Config.Tower.BaseHP * Config.Tower.HPGrowth ^ (floor - 1)
	local color = floorColor(floor)
	run.Paused = true
	Net.FX(player, "Tower", { State = "Floor", Floor = floor, Color = color })
	task.delay(1.5, function()
		if not run.Active or not player.Parent then
			return
		end
		run.Guardian = EnemyService.Create({
			Name = "Guardian",
			Label = "FLOOR " .. floor .. " GUARDIAN",
			Style = (floor % 2 == 0) and "Mech" or "Creature",
			Color = color,
			Scale = 2.2,
			HP = hp,
			Boss = true,
			Owner = player,
			Position = run.Center + Vector3.new(0, 0, -14),
			Min = run.Center - Vector3.new(ARENA_R - 4, 0, ARENA_R - 4),
			Max = run.Center + Vector3.new(ARENA_R - 4, 0, ARENA_R - 4),
			Speed = 12 + math.min(floor, 20) * 0.3,
			HitPercent = 0.08,
			OnDeath = function()
				onWin(player, run)
			end,
		})
		run.EndsAt = Stats.Now() + Config.Tower.TimeLimit
		run.Paused = false
		DataService.MarkDirty(player)
		Net.FX(player, "Tower", { State = "Start", Floor = floor, EndsAt = run.EndsAt, Color = color })
	end)
end

function TowerService.Start(player: Player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not s or not hum or hum.Health <= 0 then
		return
	end
	if s.Tower then
		return
	end
	if data.Power < Config.Tower.PowerReq then
		Net.Notify(player, "The Tower needs " .. Format.Abbrev(Config.Tower.PowerReq) .. " Power. Train first!", Color3.fromRGB(255, 120, 90), "Error")
		return
	end
	local slot = allocSlot()
	local arena, center = buildArena(slot)
	local run = {
		Slot = slot,
		Arena = arena,
		Center = center,
		Floor = math.max(1, data.TowerBest - 2),
		Active = true,
		Paused = true,
		EndsAt = 0,
	}
	s.Tower = run
	Util.Teleport(player, CFrame.new(center + Vector3.new(0, 4, 20)), "Tower")
	startFloor(player, run)

	task.spawn(function()
		while run.Active do
			task.wait(0.25)
			if not player.Parent then
				run.Active = false
				cleanup(player, run)
				return
			end
			local c = player.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then
				finish(player, run, "Lose")
			elseif not run.Paused and Stats.Now() > run.EndsAt then
				finish(player, run, "Lose")
			end
		end
	end)
end

function TowerService.Leave(player: Player)
	local s = DataService.Session(player)
	if s and s.Tower then
		finish(player, s.Tower, "Leave")
	end
end

function TowerService.InTower(player: Player): boolean
	local s = DataService.Session(player)
	return s ~= nil and s.Tower ~= nil
end

function TowerService.PlayerRemoving(player: Player)
	local s = DataService.Session(player)
	if s and s.Tower then
		s.Tower.Active = false
		cleanup(player, s.Tower)
	end
end

function TowerService.Init(m)
	map = m
end

return TowerService
