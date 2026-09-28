--!nonstrict
-- Client (LocalScript) -> StarterPlayer/StarterPlayerScripts/Client
-- Put the UI, Hud, WeaponUI, Abilities, PromptUI, Drops, WorldText,
-- WorldMap, EnemyFX, CameraDirector and Movement ModuleScripts INSIDE this
-- LocalScript. Handles server FX events, world VFX/SFX, gates, pads and
-- zones.

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
local Abilities = require(script:WaitForChild("Abilities"))
local Hud = require(script:WaitForChild("Hud"))
local WeaponUI = require(script:WaitForChild("WeaponUI"))
local PromptUI = require(script:WaitForChild("PromptUI"))
local WorldText = require(script:WaitForChild("WorldText"))
local WorldMap = require(script:WaitForChild("WorldMap"))
local EnemyFX = require(script:WaitForChild("EnemyFX"))
local CameraDirector = require(script:WaitForChild("CameraDirector"))
local Movement = require(script:WaitForChild("Movement"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AbilityRemote = Remotes:WaitForChild("Ability") :: RemoteEvent
local InteractRemote = Remotes:WaitForChild("Interact") :: RemoteEvent
local RequestRemote = Remotes:WaitForChild("Request") :: RemoteEvent
local SyncRemote = Remotes:WaitForChild("Sync") :: RemoteEvent
local FXRemote = Remotes:WaitForChild("FX") :: RemoteEvent

local function request(action: string, arg: any?)
	RequestRemote:FireServer(action, arg)
end

VFX.Init()
SFX.Init()
UI.Init(request)
WeaponUI.Init(UI, request)
Abilities.Init(AbilityRemote, request)
Hud.Init(UI, Abilities)
PromptUI.Init(InteractRemote)
Drops.Init(request)
WorldText.Init()
WorldMap.Init(UI, request)
UI.ToggleMap = WorldMap.Toggle
EnemyFX.Init(UI)
CameraDirector.Init()
CameraDirector.Blocked = function()
	return WorldMap.IsOpen or UI.IsPanelOpen()
end
Movement.Init()

Abilities.OnFeedback = function(kind)
	if kind == "NoStamina" then
		Hud.FlashStamina()
	elseif kind == "Action" then
		Hud.Combat()
	end
end

local data = nil
local currentStage = 0
local currentZone = 0

local function myRoot(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function charOf(p: Player?): Model?
	return p and p.Character
end

local function weaponColor(who: Player?): Color3
	local p: Player = who or player
	local def = Config.WeaponById[p:GetAttribute("WeaponId") or Config.StarterWeapon]
	local r = Config.WeaponRarityById[p:GetAttribute("WeaponRarity") or "Common"]
	return (def and def.Glow) or (r and r.Color) or Color3.fromRGB(230, 240, 255)
end

local function bladeColor(): Color3
	return weaponColor(player)
end

player.CharacterAdded:Connect(function()
	Drops.ClearAll()
	currentStage = -1
end)

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
	if label then
		WorldText.SetText(label, "Title", open and ("STAGE " .. stageIndex .. " - OPEN") or ("LOCKED - " .. Format.Abbrev(stage.PowerReq) .. " Power"))
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
	WorldMap.Update(snapshot)
	refreshGates()
	if old and snapshot.Blade > old.Blade then
		UI.Bump("Blade")
	end
end)

---------------------------------------------------------------------
-- FX EVENTS FROM THE SERVER
---------------------------------------------------------------------
local FX = {}

local SWING_SOUND = { Katana = "Swing", Greatsword = "HeavySwing", Scythe = "ScytheSwing", Glove = "Punch", Pistols = "GunShot", FingerGun = "SpiritShot" }

-- Basic attacks of OTHER players (yours are drawn instantly by Abilities).
FX.Attack = function(p)
	local char = charOf(p.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if p.Player ~= player then
		local class = Config.WeaponClasses[p.Class]
		if class and class.Kind == "Melee" then
			VFX.Slash(root.CFrame * CFrame.new(0, 0.6, 0), p.Color, class.Range / 9, p.Combo % 2 == 0)
		elseif p.Dir then
			VFX.Muzzle(root.Position + Vector3.new(0, 1.2, 0) + p.Dir * 2, p.Dir, p.Color)
		end
		SFX.Play(SWING_SOUND[p.Class] or "Swing", { At = root.Position, Volume = 0.6 })
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

-- impact sound family per weapon class
local HIT_SOUND = { Katana = "HitBlade", Scythe = "HitBlade", Greatsword = "HitBlunt", Glove = "HitBlunt", Pistols = "HitEnergy", FingerGun = "HitEnergy" }
local lastExposedPop = 0

FX.Hit = function(p)
	local color = p.Color or Color3.new(1, 1, 1)
	VFX.HitSpark(p.Pos, color, p.Crit)
	if p.Model then
		VFX.EnemyHitFlash(p.Model)
	end
	EnemyFX.OnHit(p.Model, p.By == player)
	if p.By == player then
		Hud.Combat()
		VFX.DamageNumber(p.Pos + Vector3.new(0, 1.5, 0), p.Amount, p.Crit)
		local cls = player:GetAttribute("WeaponClass")
		SFX.Play(p.Crit and "Crit" or (HIT_SOUND[cls] or "Hit"), { At = p.Pos })
		if p.Crit then
			VFX.Shake(0.12)
			VFX.Rumble(0.12)
		else
			VFX.Shake(0.04)
		end
		-- punish window feedback (enemy was recovering from its attack)
		if p.Exposed and os.clock() - lastExposedPop > 0.8 then
			lastExposedPop = os.clock()
			VFX.TextPop(p.Pos + Vector3.new(0, 3, 0), "EXPOSED", Color3.fromRGB(255, 225, 120), 0.8)
			SFX.Play("Exposed", { At = p.Pos })
		end
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
			VFX.Rumble(0.6)
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
		VFX.Shake(0.25)
		VFX.Rumble(0.55)
	end
end

FX.EnemySwipe = function(p)
	local cf = CFrame.lookAt(p.Pos, Vector3.new(p.Target.X, p.Pos.Y, p.Target.Z))
	VFX.Slash(cf, Color3.fromRGB(255, 70, 70), 0.6, math.random() < 0.5)
	SFX.Play("Swing", { At = p.Pos, Pitch = 0.7, Volume = 0.5 })
end

FX.Hurt = function(p)
	SFX.Play("Hurt")
	Hud.Hurt()
	VFX.ScreenFlash(Color3.fromRGB(255, 30, 40), 0.7, 0.3)
	VFX.Shake(0.18)
	if p.Stun then
		VFX.Rumble(0.25)
	end
end

FX.Dodge = function()
	local root = myRoot()
	Hud.Combat()
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

---------------------------------------------------------------------
-- ABILITIES / PROJECTILES
---------------------------------------------------------------------
local SKILL_SOUND = {
	GetsugaTensho = "Getsuga",
	CeroMetralleta = "BigBlast",
	SpiritGun = "BigBlast",
	ChargedShot = "BigBlast",
	DimensionalRift = "Vortex",
	Reap = "Vortex",
	VoidHarvest = "Vortex",
	HellDragon = "Getsuga",
	BlackBladeRush = "HeavySwing",
	IaidoDash = "HeavySwing",
	ChakraPalm = "Punch",
	GroundCleave = "BossSlam",
	StormCleave = "BossSlam",
	BurstFire = "GunShot",
}

FX.Dash = function(p)
	if p.Player == player then
		return
	end
	local char = charOf(p.Player)
	if char then
		VFX.Afterimage(char, weaponColor(p.Player))
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			SFX.Play("Dash", { At = root.Position, Volume = 0.6 })
		end
	end
end

FX.Charge = function(p)
	if p.Player == player then
		return
	end
	local char = charOf(p.Player)
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if hand then
		local def = Config.WeaponById[p.Player:GetAttribute("WeaponId") or ""]
		local skill = def and Config.Skills[p.Slot == "E" and def.Skill or ""]
		local orb = VFX.ChargeOrb(hand, Vector3.new(0, -0.9, 0), skill and skill.Color or weaponColor(p.Player), 2.2, skill and skill.Charge or 1.5)
		task.delay(skill and skill.Charge or 1.5, orb.Destroy)
	end
end

FX.Skill = function(p)
	local skill = Config.Skills[p.Skill]
	if not skill then
		return
	end
	local char = charOf(p.Player)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local isLocal = p.Player == player
	local pos = root and root.Position or p.Pos
	local color = skill.Color
	local dir = p.Dir or Vector3.new(0, 0, -1)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	flatDir = flatDir.Magnitude > 0.01 and flatDir.Unit or Vector3.new(0, 0, -1)

	if skill.Type == "Cone" then
		local hits = skill.Hits or 1
		task.spawn(function()
			for i = 1, hits do
				local r = char and char:FindFirstChild("HumanoidRootPart")
				local o = r and r.Position or pos
				VFX.ConeSwipe(CFrame.lookAt(o, o + flatDir) * CFrame.new(0, 0.6, 0), skill.Range, color)
				if i < hits then
					task.wait(skill.Interval or 0.1)
				end
			end
		end)
	elseif skill.Type == "Nova" then
		local hits = skill.Hits or 1
		task.spawn(function()
			for i = 1, hits do
				local r = char and char:FindFirstChild("HumanoidRootPart")
				VFX.Nova(r and r.Position or pos, skill.Radius, color)
				if skill.Pull then
					VFX.Zone((r and r.Position or pos) - Vector3.new(0, 2.8, 0), skill.Radius * 0.6, 0.5, color)
				end
				if i < hits then
					task.wait(skill.Interval or 0.12)
				end
			end
		end)
	elseif skill.Type == "DashStrike" or skill.Type == "ChargeLunge" then
		if p.Finish then
			task.delay(0.05, function()
				VFX.Streak(p.Pos, p.Finish, color, skill.Width * 0.3)
				VFX.Slash(CFrame.lookAt(p.Finish, p.Finish + flatDir), color, 1.6, math.random() < 0.5)
			end)
		end
		if char and not isLocal then
			VFX.Afterimage(char, color)
		end
	elseif skill.Type == "Zone" and p.Target then
		VFX.Zone(p.Target, skill.Radius, p.Duration or 2.5, color)
	elseif skill.Type == "Rain" and p.Target then
		VFX.Ring(p.Target, color, skill.Radius, 0.6)
	end

	SFX.Play(p.Slot == "R" and "Ultimate" or (SKILL_SOUND[p.Skill] or "HeavySwing"), { At = not isLocal and pos or nil })
	if isLocal then
		local def = Config.WeaponById[player:GetAttribute("WeaponId") or ""]
		local rarity = Config.WeaponRarityById[player:GetAttribute("WeaponRarity") or "Common"]
		-- anime call-out for ultimates and signature skills
		if p.Slot == "R" or (rarity and rarity.Index >= 5) then
			VFX.ImpactFrame(color, p.Slot == "R" and 1.2 or 0.8)
			VFX.TitleCard(skill.Name:upper() .. "!", def and def.Name or nil, color, 1.1)
		else
			VFX.Shake(0.2)
			if root then
				VFX.TextPop(root.Position + Vector3.new(0, 3, 0), skill.Name, color, 1.1)
			end
		end
	end
end

local lastProjSound = 0
FX.Proj = function(p)
	VFX.StartProjectile(p.Id, p.Kind, p.Pos, p.Dir, p.Speed, p.Range, p.Color or Color3.new(1, 1, 1), p.Size)
	local t = os.clock()
	if t - lastProjSound > 0.06 then
		lastProjSound = t
		local cue = p.Kind == "Cero" and "CeroShot" or (p.Kind == "Orb" and "SpiritShot" or (p.Kind == "Ray" and "GunShot" or nil))
		if cue then
			SFX.Play(cue, { At = p.Pos, Volume = 0.7 })
		end
	end
end

FX.ProjEnd = function(p)
	VFX.EndProjectile(p.Id, p.Pos, p.Hit, p.Explode)
	if p.Explode then
		SFX.Play("BigBlast", { At = p.Pos })
	end
end

FX.Impact = function(p)
	local color = p.Color or Color3.new(1, 1, 1)
	if p.Kind == "Rasengan" then
		VFX.Explosion(p.Pos, color, 1.3)
		VFX.Zone(p.Pos - Vector3.new(0, 2.5, 0), p.Radius or 10, 0.4, color)
		VFX.ShardRing(p.Pos, color, 22, 20, 0.5)
		SFX.Play("RasenganHit", { At = p.Pos })
		local root = myRoot()
		if root and (root.Position - p.Pos).Magnitude < 60 then
			VFX.Shake(0.25)
			VFX.Rumble(0.45)
		end
	elseif p.Kind == "Rain" then
		VFX.Pillar(p.Pos - Vector3.new(0, 1, 0), color, 40, 2.5, 0.5)
		VFX.Emit(p.Pos, "Sparks", 14, color)
		VFX.Ring(p.Pos, color, p.Radius or 7, 0.35)
		SFX.Play("Hit", { At = p.Pos, Volume = 0.6 })
	elseif p.Kind == "Burn" then
		VFX.Emit(p.Pos, "Fire", 6, color)
	else
		VFX.Explosion(p.Pos, color, 0.8)
	end
end

FX.Cooldown = function(p)
	Abilities.SetCooldown(p.Slot, p.Duration)
end

FX.AbilityFail = function()
	SFX.Play("Error", { Volume = 0.4 })
end

FX.NoStamina = function()
	SFX.Play("NoStamina")
	Hud.FlashStamina()
end

FX.Potion = function()
	SFX.Play("Potion")
	Hud.Ping("Vitals", 3)
	local char = player.Character
	if char then
		VFX.LevelBurst(char, Color3.fromRGB(120, 255, 140))
	end
end

---------------------------------------------------------------------
-- ENEMY TELEGRAPHS
---------------------------------------------------------------------
FX.EnemyWindup = function(p)
	if p.Kind == "Slam" then
		VFX.Telegraph(p.Pos, p.Radius, p.Time)
	else
		VFX.TelegraphLine(p.Pos, p.Dir, p.Length, 9, p.Time)
	end
	local model = p.Model
	local head = model and model:FindFirstChild("Head")
	if head then
		VFX.Emit(head.Position, "Glow", 1, Color3.fromRGB(255, 60, 60))
		VFX.Emit(head.Position, "Rise", 12, p.Color or Color3.fromRGB(255, 80, 80))
	end
	SFX.Play("EnemyWindup", { At = p.Pos })
end

FX.EnemyLunge = function(p)
	VFX.Streak(p.From, p.To, Color3.fromRGB(255, 70, 70), 2)
	SFX.Play("HeavySwing", { At = p.From, Pitch = 0.8 })
end

---------------------------------------------------------------------
-- LOOT / RETENTION / MONETIZATION
---------------------------------------------------------------------
FX.Equipped = function(p)
	SFX.Play("Equip")
	local def = Config.WeaponById[p.Weapon]
	local r = Config.WeaponRarityById[p.Rarity]
	if def and r then
		UI.Notify("Equipped " .. def.Name .. " (" .. (r.Label or r.Id) .. ")", r.Color)
	end
	local char = player.Character
	if char then
		VFX.LevelBurst(char, r and r.Color or Color3.new(1, 1, 1))
	end
end

FX.WeaponDrop = function(p)
	local r = Config.WeaponRarityById[p.Rarity]
	if r and r.Index >= 4 then
		WeaponUI.Reveal(p.Weapon, p.Rarity, "WEAPON DROP!")
	else
		local def = Config.WeaponById[p.Weapon]
		SFX.Play("RarePickup")
		UI.Notify("Weapon drop: " .. (r and (r.Label or r.Id) or "") .. " " .. (def and def.Name or "?"), r and r.Color or nil)
	end
end

FX.ChestResult = function(p)
	WeaponUI.Reveal(p.Weapon, p.Rarity, Config.ChestById[p.Chest] and Config.ChestById[p.Chest].Name:upper() or "CHEST")
end

FX.PlaytimeReward = function(p)
	SFX.Play("PlaytimeReward")
	Hud.Ping("Playtime", 6)
	VFX.TitleCard("PLAY-TIME REWARD!", p.Minutes .. " min: " .. p.Name, Color3.fromRGB(255, 215, 80), 2)
	UI.FlyToHud("Coins", nil, Color3.fromRGB(255, 210, 60), 6)
end

FX.Daily = function(p)
	SFX.Play("PlaytimeReward")
	VFX.TitleCard("DAY " .. p.Streak .. " STREAK!", p.Text .. "  |  +" .. math.floor((p.Bonus or 0) * 100 + 0.5) .. "% Coins", Color3.fromRGB(120, 220, 255), 2.4)
end

FX.PowerTier = function(p)
	SFX.Play("PowerUp")
	VFX.ImpactFrame(Color3.fromRGB(255, 80, 80), 1.4)
	VFX.TitleCard("POWER x" .. Format.Abbrev(p.Mult) .. "!", "Tier " .. p.Tier .. " unlocked", Color3.fromRGB(255, 90, 90), 2.2)
	local char = player.Character
	if char then
		VFX.Transform(char, Color3.fromRGB(255, 80, 80), false)
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

-- gently flickering flames / lanterns (lights tagged "Flicker")
local flickers = {}
local function addFlicker(l: Instance)
	if l:IsA("Light") then
		flickers[l] = { Base = l.Brightness, Seed = math.random() * 100 }
	end
end
for _, l in ipairs(CollectionService:GetTagged("Flicker")) do
	addFlicker(l)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(addFlicker)

local accum = 0
RunService.RenderStepped:Connect(function(dt)
	UI.Tick(dt)
	Hud.Tick(dt)
	WorldText.Step(dt)
	WorldMap.Step(dt)
	EnemyFX.Step(dt)
	Movement.Step(dt)
	local root = myRoot()
	Drops.Step(dt, root)

	local now = os.clock()
	for l, f in pairs(flickers) do
		if l.Parent then
			local lp = l.Parent :: any
			if root and lp:IsA("BasePart") and (lp.Position - root.Position).Magnitude < 120 then
				l.Brightness = f.Base * (0.86 + 0.14 * math.noise(now * 3.1, f.Seed) + 0.08 * math.sin(now * 11 + f.Seed))
			end
		else
			flickers[l] = nil
		end
	end

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
	WeaponUI.Tick()

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
