--!nonstrict
-- Client (LocalScript) -> StarterPlayer/StarterPlayerScripts/Client
-- Put the "UI" and "Drops" ModuleScripts INSIDE this LocalScript.
-- Handles input, server FX events, world VFX/SFX, gates, pads and zones.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local VFX = require(Shared:WaitForChild("VFX"))
local SFX = require(Shared:WaitForChild("SFX"))

local UI = require(script:WaitForChild("UI"))
local Drops = require(script:WaitForChild("Drops"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwingRemote = Remotes:WaitForChild("Swing") :: RemoteEvent
local RequestRemote = Remotes:WaitForChild("Request") :: RemoteEvent
local SyncRemote = Remotes:WaitForChild("Sync") :: RemoteEvent
local FXRemote = Remotes:WaitForChild("FX") :: RemoteEvent

local function request(action: string, arg: any?)
	RequestRemote:FireServer(action, arg)
end

VFX.Init()
SFX.Init()
UI.Init(request)
Drops.Init(request)

local data = nil
local currentStage = 0
local currentZone = 0
local lastSwing = 0
local swingFlip = false

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function charOf(p: Player?): Model?
	return p and p.Character
end

local function bladeColor(): Color3
	local tier = Config.GetBladeTier(data and data.Blade or 0)
	return tier.Edge or Color3.fromRGB(230, 240, 255)
end

---------------------------------------------------------------------
-- SWORD INPUT (instant local feedback; server validates hits)
---------------------------------------------------------------------
local function onSwing()
	local t = os.clock()
	if t - lastSwing < Config.SwingCooldown * 0.85 then
		return
	end
	lastSwing = t
	SwingRemote:FireServer()
	local root = myRoot()
	if not root then
		return
	end
	swingFlip = not swingFlip
	local _, tierIndex = Config.GetBladeTier(data and data.Blade or 0)
	VFX.Slash(root.CFrame * CFrame.new(0, 0.6, 0), bladeColor(), 1 + tierIndex * 0.06, swingFlip)
	SFX.Play("Swing", { Pitch = swingFlip and 1 or 1.08 })
	VFX.Shake(0.03)
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or not tool:GetAttribute("IsBlade") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(onSwing)
	tool.Equipped:Connect(function()
		SFX.Play("Equip")
	end)
end

local function onCharacter(char: Model)
	Drops.ClearAll()
	for _, c in ipairs(char:GetChildren()) do
		hookTool(c)
	end
	char.ChildAdded:Connect(hookTool)
	local bp = player:WaitForChild("Backpack")
	for _, c in ipairs(bp:GetChildren()) do
		hookTool(c)
	end
	bp.ChildAdded:Connect(hookTool)
	currentStage = -1
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

---------------------------------------------------------------------
-- GATES (opened locally when you meet the Power requirement)
---------------------------------------------------------------------
local function refreshGate(gate: BasePart)
	if not data then
		return
	end
	local stageIndex = gate:GetAttribute("Stage")
	local stage = stageIndex and Config.Stages[stageIndex]
	if not stage then
		return
	end
	local zone = Config.Zones[stage.Zone]
	local open = data.Power >= stage.PowerReq and data.Blade >= (zone.BladeReq or 0)
	if gate:GetAttribute("Open") == open then
		return
	end
	gate:SetAttribute("Open", open)
	gate.CanCollide = not open
	gate.Transparency = open and 0.85 or 0.1
	local label = gate:FindFirstChild("GateLabel")
	local title = label and label:FindFirstChild("Title")
	if title then
		(title :: TextLabel).Text = open and ("STAGE " .. stageIndex .. " - OPEN") or ("LOCKED - " .. Format.Abbrev(stage.PowerReq) .. " Power")
	end
	if open and stage.PowerReq > 0 and gate:GetAttribute("Seen") then
		UI.Notify("Stage " .. stageIndex .. " unlocked!", zone.Accent)
		SFX.Play("Stage")
	end
	gate:SetAttribute("Seen", true)
end

local function refreshGates()
	for _, g in ipairs(CollectionService:GetTagged("StageGate")) do
		refreshGate(g)
	end
end
CollectionService:GetInstanceAddedSignal("StageGate"):Connect(function(g)
	refreshGate(g)
end)

---------------------------------------------------------------------
-- SYNC
---------------------------------------------------------------------
SyncRemote.OnClientEvent:Connect(function(snapshot)
	local old = data
	data = snapshot
	UI.Update(snapshot)
	refreshGates()
	if old and snapshot.Blade > old.Blade then
		UI.Bump("Blade")
	end
end)

---------------------------------------------------------------------
-- FX EVENTS FROM THE SERVER
---------------------------------------------------------------------
local FX = {}

FX.Swing = function(p)
	local char = charOf(p.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if p.Player ~= player then
		VFX.Slash(root.CFrame * CFrame.new(0, 0.6, 0), p.Color, 1, math.random() < 0.5)
		SFX.Play("Swing", { At = root.Position, Volume = 0.6 })
	end
	if p.Heavy then
		local ground = root.Position - Vector3.new(0, 2.8, 0)
		VFX.Ring(ground, Color3.fromRGB(80, 220, 255), 18, 0.45)
		VFX.ShardRing(ground + Vector3.new(0, 1, 0), Color3.fromRGB(120, 230, 255), 18, 16, 0.45)
		VFX.Emit(root.Position, "Sparks", 30, Color3.fromRGB(80, 220, 255))
		VFX.Emit(root.Position, "Glow", 1, Color3.fromRGB(80, 220, 255))
		SFX.Play("AoE", { At = root.Position })
		if p.Player == player then
			VFX.Shake(0.25)
		end
	end
end

FX.Hit = function(p)
	local color = p.Color or Color3.new(1, 1, 1)
	VFX.HitSpark(p.Pos, color, p.Crit)
	if p.Model then
		VFX.EnemyHitFlash(p.Model)
	end
	if p.By == player then
		VFX.DamageNumber(p.Pos + Vector3.new(0, 1.5, 0), p.Amount, p.Crit)
		SFX.Play(p.Crit and "Crit" or "Hit", { At = p.Pos })
		VFX.Shake(p.Crit and 0.16 or 0.05)
	end
end

FX.Kill = function(p)
	if p.Model then
		VFX.EnemyDeath(p.Model, p.Color or Color3.new(1, 1, 1), p.Big)
	elseif p.Pos then
		VFX.Explosion(p.Pos, p.Color or Color3.new(1, 1, 1), p.Big and 2.5 or 1)
	end
	if p.Big then
		SFX.Play("BossKill")
		local root = myRoot()
		if root and (root.Position - p.Pos).Magnitude < 150 then
			VFX.ImpactFrame(p.Color, 1.4)
			VFX.TitleCard("BOSS DEFEATED!", nil, Color3.fromRGB(255, 215, 80), 1.6)
		end
	elseif p.Elite then
		SFX.Play("EliteKill", { At = p.Pos })
		if p.By == player then
			VFX.ImpactFrame(Color3.fromRGB(255, 210, 80), 0.7)
		end
	else
		SFX.Play("Kill", { At = p.Pos })
		if p.By == player then
			VFX.Shake(0.12)
		end
	end
end

FX.Reward = function(p)
	UI.FlyToHud("Coins", p.Pos, Config.Rarity.Legendary.Color, 3)
	VFX.TextPop(p.Pos + Vector3.new(0, 3, 0), "+" .. Format.Abbrev(p.Coins) .. " Coins", Color3.fromRGB(255, 215, 70), 0.8)
	task.delay(0.5, SFX.Play, "Coins", { Volume = 0.5 })
end

FX.Drop = function(p)
	Drops.Spawn(p)
end

FX.Collected = function(p)
	Drops.Collected(p.Id)
end

FX.CollectFail = function(p)
	Drops.Fail(p.Id, p.Full)
end

local lastPowerPop = 0
FX.Power = function(p)
	local root = myRoot()
	if not root then
		return
	end
	UI.Bump("Power")
	if os.clock() - lastPowerPop > 0.12 then
		lastPowerPop = os.clock()
		VFX.TextPop(root.Position + Vector3.new(math.random() * 2 - 1, 2, 0), "+" .. Format.Abbrev(p.Amount) .. " Power", Color3.fromRGB(120, 255, 170), p.Pad and 0.9 or 0.7)
	end
	if p.Pad then
		VFX.Emit(root.Position - Vector3.new(0, 2.5, 0), "Rise", p.Auto and 4 or 8, Config.TrainPads[p.Pad].Color)
	end
	if not p.Auto then
		SFX.Play("PowerGain", { Volume = 0.8 })
	end
end

FX.Forge = function(p)
	UI.Bump("Blade")
	local char = player.Character
	if p.TierUp then
		SFX.Play("ForgeTierUp")
		VFX.ImpactFrame(bladeColor(), 1.3)
		VFX.TitleCard("NEW BLADE TIER!", p.TierName .. " Blade  (+" .. Format.Abbrev(p.To) .. ")", bladeColor(), 2.2)
		if char then
			VFX.Transform(char, bladeColor(), false)
		end
	else
		SFX.Play(p.Auto and "Milestone" or "Forge")
		if not p.Auto then
			VFX.TitleCard("+" .. Format.Abbrev(p.Gained) .. " BLADE", "Blade +" .. Format.Abbrev(p.From) .. "  ->  +" .. Format.Abbrev(p.To), Color3.fromRGB(255, 160, 60), 1.3)
		end
		if p.Milestone and char then
			VFX.LevelBurst(char, bladeColor())
		end
	end
end

FX.ForgeBurst = function(p)
	local map = workspace:FindFirstChild("GeneratedMap")
	local lava = map and map:FindFirstChild("Lava", true)
	if not lava then
		return
	end
	local pos = lava.Position
	local color = Color3.fromRGB(255, 140, 40)
	VFX.Pillar(pos, color, 40, 5, 0.9)
	VFX.Emit(pos + Vector3.new(0, 1, 0), "Sparks", 40, color)
	VFX.Emit(pos + Vector3.new(0, 1, 0), "Embers", 30, color)
	VFX.Emit(pos + Vector3.new(0, 1, 0), "Smoke", 10, Color3.fromRGB(90, 80, 90))
	VFX.Ring(pos, color, 16, 0.5)
	VFX.Light(pos, color, 40, 6, 0.8)
	if p.Player == player then
		VFX.Shake(0.35)
		VFX.FOVPunch(-6)
	else
		SFX.Play("Forge", { At = pos, Volume = 0.5 })
	end
end

FX.Sell = function(p)
	SFX.Play("Sell")
	UI.FlyToHud("Coins", nil, Color3.fromRGB(255, 210, 60), 8)
	UI.Notify(p.Text, Color3.fromRGB(255, 215, 70))
end

FX.Rebirth = function(p)
	local char = charOf(p.Player)
	if not char then
		return
	end
	local gold = Color3.fromRGB(255, 215, 80)
	if p.Player == player then
		SFX.Play("Rebirth")
		VFX.Transform(char, gold, true)
		task.delay(0.6, function()
			VFX.TitleCard("REBIRTH " .. p.Rebirths .. "!", "Power gain, Coins and Damage boosted forever", gold, 2.4)
		end)
	else
		VFX.Transform(char, gold, false)
	end
end

FX.RaceRoll = function(p)
	UI.RaceRoll(p.Race, p.Tier, p.Initial)
end

FX.Transform = function(p)
	local char = charOf(p.Player)
	if not char then
		return
	end
	local isLocal = p.Player == player
	local titles = { Overdrive = "OVERDRIVE!", Zenkai = "ZENKAI BOOST!", Awaken = "AWAKENED!" }
	VFX.Transform(char, p.Color, isLocal, titles[p.Kind])
	local root = char:FindFirstChild("HumanoidRootPart")
	local sound = p.Kind == "Zenkai" and "Zenkai" or (p.Kind == "Awaken" and "RaceRevealLegend" or "Overdrive")
	if isLocal then
		if p.Kind ~= "Awaken" then
			SFX.Play(sound)
		end
	elseif root then
		SFX.Play(sound, { At = root.Position, Volume = 0.7 })
	end
end

FX.Notify = function(p)
	UI.Notify(p.Text, p.Color)
	if p.Sound then
		SFX.Play(p.Sound)
	end
end

FX.Discover = function(p)
	local ore = Config.OreById[p.Ore]
	if not ore then
		return
	end
	SFX.Play("Discover")
	VFX.TitleCard("NEW ORE DISCOVERED!", ore.Name .. "  (+" .. Format.Abbrev(p.Reward) .. " Coins)", ore.Color, 2)
	UI.FlyToHud("Coins", nil, Color3.fromRGB(255, 210, 60), 6)
end

FX.BossSpawn = function(p)
	if currentZone ~= p.Zone then
		return
	end
	SFX.Play("BossSpawn")
	VFX.Shake(0.5)
	VFX.TitleCard("BOSS APPEARED!", p.Name, Color3.fromRGB(255, 70, 90), 2)
end

FX.Telegraph = function(p)
	VFX.Telegraph(p.Pos, p.Radius, p.Time)
	SFX.Play("Telegraph", { At = p.Pos })
end

FX.Slam = function(p)
	VFX.Explosion(p.Pos + Vector3.new(0, 1, 0), p.Color or Color3.fromRGB(255, 90, 60), 1.4)
	SFX.Play("BossSlam", { At = p.Pos })
	local root = myRoot()
	if root and (root.Position - p.Pos).Magnitude < 60 then
		VFX.Shake(0.45)
	end
end

FX.EnemySwipe = function(p)
	local cf = CFrame.lookAt(p.Pos, Vector3.new(p.Target.X, p.Pos.Y, p.Target.Z))
	VFX.Slash(cf, Color3.fromRGB(255, 70, 70), 0.6, math.random() < 0.5)
	SFX.Play("Swing", { At = p.Pos, Pitch = 0.7, Volume = 0.5 })
end

FX.Hurt = function(p)
	SFX.Play("Hurt")
	VFX.ScreenFlash(Color3.fromRGB(255, 30, 40), 0.55, 0.35)
	VFX.Shake(0.22)
end

FX.Dodge = function()
	local root = myRoot()
	if root then
		VFX.TextPop(root.Position + Vector3.new(0, 3, 0), "DODGE!", Color3.fromRGB(140, 160, 255), 1)
		SFX.Play("UIHover", { Pitch = 0.8, Volume = 2 })
	end
end

FX.PlotArmor = function()
	SFX.Play("PlotArmor")
	VFX.ImpactFrame(Color3.fromRGB(255, 215, 80), 1)
	VFX.TitleCard("PLOT ARMOR!", "Main Characters don't go down that easy", Color3.fromRGB(255, 215, 80), 1.8)
end

FX.Tower = function(p)
	if p.State == "Floor" then
		UI.Tower("Floor", p.Floor, 0)
		UI.Banner("FLOOR " .. p.Floor, "Get ready...", p.Color)
		SFX.Play("TowerStart")
		SFX.PlayMusic(Config.Music.Tower)
	elseif p.State == "Start" then
		UI.Tower("Start", p.Floor, p.EndsAt)
		VFX.TitleCard("FIGHT!", "Beat the Guardian in " .. Config.Tower.TimeLimit .. "s", p.Color, 1)
	elseif p.State == "Win" then
		UI.Tower("Win", p.Floor, 0)
		SFX.Play("TowerWin")
		VFX.TitleCard("FLOOR " .. p.Floor .. " CLEARED!", p.Text, Color3.fromRGB(120, 255, 170), 2)
		UI.FlyToHud("Coins", nil, Color3.fromRGB(255, 210, 60), 8)
	elseif p.State == "Lose" then
		SFX.Play("TowerLose")
		VFX.TitleCard("DEFEATED", "You reached floor " .. p.Floor, Color3.fromRGB(255, 90, 90), 2)
		task.delay(2, UI.Tower, nil)
	else
		UI.Tower(nil)
	end
end

FX.OpenPanel = function(p)
	UI.Open(p.Name, p.Mode)
	SFX.Play("UIOpen")
end

FX.Teleported = function(p)
	SFX.Play("Teleport")
	VFX.ScreenFlash(Color3.fromRGB(230, 220, 255), 0.1, 0.5)
	VFX.FOVPunch(12)
	currentStage = -1
	if p.Where then
		UI.Banner(p.Where, nil, Color3.fromRGB(220, 200, 255))
	end
end

FX.Purchase = function(p)
	SFX.Play("Purchase")
	VFX.ScreenFlash(Color3.fromRGB(120, 255, 150), 0.6, 0.4)
	UI.Notify("Got " .. (p.Text and p.Text ~= "" and p.Text or p.Name) .. "!", Color3.fromRGB(120, 255, 150))
end

FX.Upgraded = function(p)
	local char = player.Character
	UI.Notify(Config.Upgrades[p.Key].Name .. " upgraded to level " .. p.Level .. "!", Color3.fromRGB(120, 200, 255))
	if char then
		VFX.LevelBurst(char, Color3.fromRGB(120, 200, 255))
	end
end

FXRemote.OnClientEvent:Connect(function(kind, payload)
	local fn = FX[kind]
	if fn then
		local ok, err = pcall(fn, payload or {})
		if not ok then
			warn("[FX] " .. tostring(kind) .. ": " .. tostring(err))
		end
	end
end)

Drops.OnPickup = function(oreId, pos)
	UI.Bump("Backpack")
	local ore = Config.OreById[oreId]
	if ore and ore.Order >= 3 then
		VFX.TextPop(pos + Vector3.new(0, 3, 0), "+1 " .. ore.Name, ore.Color, 0.8)
	end
end

---------------------------------------------------------------------
-- WORLD: spinning props, pads, rooms / zone lighting & music
---------------------------------------------------------------------
local spinners = {}
local function addSpinner(inst: Instance)
	local pivot = if inst:IsA("Model") then inst:GetPivot() elseif inst:IsA("BasePart") then inst.CFrame else nil
	if pivot then
		spinners[inst] = { Base = pivot, Angle = 0, Phase = math.random() * 6 }
	end
end
for _, inst in ipairs(CollectionService:GetTagged("Spin")) do
	addSpinner(inst)
end
CollectionService:GetInstanceAddedSignal("Spin"):Connect(addSpinner)
CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(inst)
	spinners[inst] = nil
end)

local gameColor = Lighting:FindFirstChild("GameColor") :: ColorCorrectionEffect?
local function setZoneLook(zoneId: number)
	local zone = Config.Zones[zoneId]
	local tint = zone and zone.Tint or Color3.fromRGB(255, 250, 255)
	gameColor = gameColor or Lighting:FindFirstChild("GameColor") :: ColorCorrectionEffect?
	if gameColor then
		TweenService:Create(gameColor, TweenInfo.new(1.5), { TintColor = tint }):Play()
	end
	local music = zoneId == 0 and Config.Music.Hub or Config.Music["Zone" .. zoneId]
	SFX.PlayMusic(music)
end

local function pointInPart(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local accum = 0
RunService.RenderStepped:Connect(function(dt)
	UI.Tick()
	local root = myRoot()
	Drops.Step(dt, root)

	local t = os.clock()
	for inst, s in pairs(spinners) do
		if inst.Parent then
			s.Angle += math.rad(inst:GetAttribute("SpinSpeed") or 30) * dt
			local bob = inst:GetAttribute("Bob") or 0
			local rot = inst:GetAttribute("SpinAxis") == "Z" and CFrame.Angles(0, 0, s.Angle) or CFrame.Angles(0, s.Angle, 0)
			local cf = s.Base * CFrame.new(0, math.sin(t * 1.6 + s.Phase) * bob, 0) * rot
			if inst:IsA("Model") then
				inst:PivotTo(cf)
			else
				(inst :: BasePart).CFrame = cf
			end
		else
			spinners[inst] = nil
		end
	end

	accum += dt
	if accum < 0.25 or not root or not data then
		return
	end
	accum = 0

	-- training pad indicator
	local padMult, padLocked = nil, false
	for _, pad in ipairs(CollectionService:GetTagged("TrainPad")) do
		local p = pad :: BasePart
		local flat = Vector3.new(root.Position.X - p.Position.X, 0, root.Position.Z - p.Position.Z)
		if flat.Magnitude <= Config.TrainPadRadius and math.abs(root.Position.Y - p.Position.Y) < 7 then
			padMult = p:GetAttribute("Mult")
			padLocked = data.Power < (p:GetAttribute("PowerReq") or 0) or data.Rebirths < (p:GetAttribute("RebirthReq") or 0)
			break
		end
	end
	UI.SetPad(padMult, padLocked)

	-- which stage room are we in?
	local stageNow, zoneNow = 0, 0
	for _, room in ipairs(CollectionService:GetTagged("StageRoom")) do
		if pointInPart(room :: BasePart, root.Position) then
			stageNow = room:GetAttribute("Stage") or 0
			zoneNow = room:GetAttribute("Zone") or 0
			break
		end
	end
	if stageNow == 0 then
		-- start area of a dungeon still counts as that zone
		if root.Position.Z < -900 then
			zoneNow = root.Position.X > 350 and 2 or 1
		end
	end
	if zoneNow ~= currentZone then
		currentZone = zoneNow
		setZoneLook(zoneNow)
	end
	if stageNow ~= currentStage then
		local prev = currentStage
		currentStage = stageNow
		if stageNow > 0 and prev >= 0 then
			local stage = Config.Stages[stageNow]
			local zone = Config.Zones[stage.Zone]
			UI.Banner("STAGE " .. stageNow, (stage.Boss and "BOSS: " or "") .. stage.Enemy, zone.Accent)
			SFX.Play("Stage")
		end
	end
end)

task.spawn(function()
	for _ = 1, 10 do
		request("Ready")
		task.wait(2)
		if data then
			break
		end
	end
end)
print("[" .. Config.GameName .. "] client ready")
