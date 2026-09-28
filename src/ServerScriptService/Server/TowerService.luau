--!nonstrict
-- TowerService (ModuleScript) -> ServerScriptService/Server/TowerService
-- BOSS RUSH: a private arena per player. Bosses come back to back (two at
-- once every 5th wave); beat each wave before its timer runs out. Every wave
-- pays Coins, Runes (+2% dmg each) and ore, with armour + catalyst chances.
-- Your best wave is saved (TowerBest).

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

local BR = Config.BossRush
local BOSS_STAGES = {}
for i, stage in ipairs(Config.Stages) do
	if stage.Boss then
		table.insert(BOSS_STAGES, i)
	end
end

local function oreTable(wave: number)
	local stageIndex = math.clamp(BR.StageReq + wave, 1, #Config.Stages)
	return Config.Stages[stageIndex].Drops
end

local function waveColor(wave: number): Color3
	return Color3.fromHSV((wave * 0.13) % 1, 0.7, 1)
end

local function cleanup(player: Player, run)
	for _, boss in ipairs(run.Bosses or {}) do
		if not boss.Dead then
			boss.Dead = true
			local idx = table.find(EnemyService.Active, boss)
			if idx then
				table.remove(EnemyService.Active, idx)
			end
			boss.Model:Destroy()
		end
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
	Net.FX(player, "Tower", { State = state, Floor = run.Wave, Best = (DataService.Get(player) or {}).TowerBest })
	task.delay(state == "Leave" and 0.2 or 2.2, function()
		if player.Parent and player.Character and map then
			Util.Teleport(player, map.TowerCFrame, "Boss Rush")
		end
		cleanup(player, run)
	end)
end

local startWave

local function onWaveCleared(player: Player, run)
	local data = DataService.Get(player)
	if not data or not run.Active then
		return
	end
	local wave = run.Wave
	local coins = math.floor(BR.CoinBase * BR.CoinGrowth ^ (wave - 1) * Stats.CoinMult(player))
	data.Coins += coins
	data.Runes += BR.RunesPerBoss * #run.Bosses
	data.TowerBest = math.max(data.TowerBest, wave)
	local drops = oreTable(wave)
	local luck = Stats.Luck(player)
	for _ = 1, 2 + math.floor(wave / 4) do
		local a = math.random() * math.pi * 2
		Loot.Drop(player, Loot.RollOre(drops, luck), run.Center + Vector3.new(math.cos(a) * 6, 1.2, math.sin(a) * 6))
	end
	EnemyService.GearDrop(player, Config.ArmorDropChance.BossRush)
	local extra = ""
	if wave % BR.CatalystEvery == 0 then
		data.Keys.RareScroll = (data.Keys.RareScroll or 0) + 1
		extra = "  +1 Rare+ Catalyst"
	end
	DataService.MarkDirty(player)
	Net.FX(player, "Tower", { State = "Win", Floor = wave, Coins = coins, Text = "+" .. Format.Abbrev(coins) .. " Coins  +" .. (BR.RunesPerBoss * #run.Bosses) .. " Rune" .. extra })
	run.Paused = true
	task.delay(BR.Break, function()
		if run.Active and player.Parent then
			run.Wave += 1
			startWave(player, run)
		end
	end)
end

startWave = function(player: Player, run)
	local wave = run.Wave
	local count = (wave % BR.DoubleEvery == 0) and 2 or 1
	local hp = BR.BaseHP * BR.HPGrowth ^ (wave - 1) / math.sqrt(count)
	local color = waveColor(wave)
	run.Paused = true
	run.Bosses = {}
	run.Alive = count
	Net.FX(player, "Tower", { State = "Floor", Floor = wave, Color = color, Double = count > 1 })
	task.delay(1.2, function()
		if not run.Active or not player.Parent then
			return
		end
		for k = 1, count do
			local stageIndex = BOSS_STAGES[((wave + k - 2) % #BOSS_STAGES) + 1]
			local stage = Config.Stages[stageIndex]
			local boss = EnemyService.Create({
				Label = "WAVE " .. wave .. ": " .. stage.Enemy,
				LookIndex = stageIndex,
				Color = color,
				Scale = 2.2,
				HP = hp,
				Boss = true,
				Owner = player,
				Position = run.Center + Vector3.new((k - (count + 1) / 2) * 16, 0, -14),
				Min = run.Center - Vector3.new(ARENA_R - 4, 0, ARENA_R - 4),
				Max = run.Center + Vector3.new(ARENA_R - 4, 0, ARENA_R - 4),
				Speed = 12 + math.min(wave, 25) * 0.3,
				HitPercent = 0.06 + math.min(wave, 30) * 0.002,
				OnDeath = function()
					run.Alive -= 1
					if run.Alive <= 0 then
						onWaveCleared(player, run)
					end
				end,
			})
			table.insert(run.Bosses, boss)
		end
		run.EndsAt = Stats.Now() + BR.TimePerBoss * count
		run.Paused = false
		DataService.MarkDirty(player)
		Net.FX(player, "Tower", { State = "Start", Floor = wave, EndsAt = run.EndsAt, Color = color })
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
	if data.Stage < BR.StageReq then
		Net.Notify(player, "Boss Rush opens after you clear stage " .. BR.StageReq .. " on the Path.", Color3.fromRGB(255, 120, 90), "Error")
		return
	end
	local slot = allocSlot()
	local arena, center = buildArena(slot)
	local run = {
		Slot = slot,
		Arena = arena,
		Center = center,
		Wave = 1,
		Bosses = {},
		Alive = 0,
		Active = true,
		Paused = true,
		EndsAt = 0,
	}
	s.Tower = run
	Util.Teleport(player, CFrame.new(center + Vector3.new(0, 4, 20)), "Boss Rush")
	startWave(player, run)

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
