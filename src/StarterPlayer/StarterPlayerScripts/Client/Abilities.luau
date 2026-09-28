--!nonstrict
-- Abilities (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/Abilities
-- Combat input through ContextActionService:
--   LMB / RT / touch button   basic attack (hold to keep attacking)
--   Q   / B                   dash (short i-frames)
--   E   / X                   weapon skill (hold for charge skills)
--   R   / Y                   ultimate
--   C   / LB                  Overdrive transformation
--   H                         health potion
-- The client plays animations + instant feedback; the server validates
-- stamina, cooldowns and hits.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))
local SFX = require(Shared:WaitForChild("SFX"))
local ProcAnim = require(script.Parent:WaitForChild("ProcAnim"))

local Abilities = {}
-- classes aimed with an outstretched arm, and classes without the two-hand
-- sword-hold idle pose
local POINT = { FingerGun = true, Bow = true, Cannon = true, Staff = true, Kunai = true }
local NO_HOLD = { Glove = true, FingerGun = true, Claws = true, Cannon = true, Kunai = true }
Abilities.CooldownEnds = { LMB = 0, Q = 0, E = 0, R = 0, C = 0 }
Abilities.CooldownLength = { LMB = 1, Q = 1, E = 1, R = 1, C = 1 }
Abilities.OnFeedback = nil :: ((string) -> ())? -- "NoStamina", ...

local player = Players.LocalPlayer
local remote: RemoteEvent
local request: (string, any?) -> ()
local tracks: { [string]: AnimationTrack } = {}
local attackHeld = false
local lastAttack = 0
local combo = 0
local charging = nil -- { Slot, Orb, Start }
local B = Config.Balance

local SWING_SOUND = {
	Katana = "Swing", Greatsword = "HeavySwing", Scythe = "ScytheSwing", Glove = "Punch", Pistols = "GunShot", FingerGun = "SpiritShot",
	Spear = "Swing", Daggers = "Swing", Hammer = "HeavySwing", Bow = "Swing", Staff = "SpiritShot", Chain = "ScytheSwing",
	Claws = "Swing", Fan = "Swing", Kunai = "Swing", Cannon = "GunShot",
}

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function character()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil, nil, nil
	end
	return c, hum, root :: BasePart
end

local function weapon()
	local id = player:GetAttribute("WeaponId") or Config.StarterWeapon
	local def = Config.WeaponById[id] or Config.WeaponById[Config.StarterWeapon]
	local rarity = Config.WeaponRarityById[player:GetAttribute("WeaponRarity") or "Common"] or Config.WeaponRarities[1]
	return def, Config.WeaponClasses[def.Class], rarity
end

function Abilities.SkillFor(slot: string)
	local def, class = weapon()
	local id = slot == "E" and def.Skill or class.Ultimate
	return id, Config.Skills[id]
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Aim direction + target point (mouse on PC, camera direction otherwise).
local function aim(): (Vector3, Vector3)
	local c, _, root = character()
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return Vector3.new(0, 0, -1), Vector3.zero
	end
	local origin = root.Position + Vector3.new(0, 1.2, 0)
	local target
	local last = UserInputService:GetLastInputType()
	if UserInputService.MouseEnabled and (last == Enum.UserInputType.MouseButton1 or last == Enum.UserInputType.MouseMovement or last == Enum.UserInputType.Keyboard or last == Enum.UserInputType.MouseButton2 or last == Enum.UserInputType.MouseWheel) then
		local m = UserInputService:GetMouseLocation()
		local ray = cam:ViewportPointToRay(m.X, m.Y)
		local ignore = { c }
		local fx = workspace:FindFirstChild("ClientFX")
		if fx then
			table.insert(ignore, fx)
		end
		rayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
		target = hit and hit.Position or (ray.Origin + ray.Direction * 400)
	else
		target = origin + flat(cam.CFrame.LookVector) * 40
	end
	local dir = target - origin
	if dir.Magnitude < 0.1 then
		dir = root.CFrame.LookVector
	end
	return dir.Unit, target
end

local function faceTowards(dir: Vector3)
	local _, _, root = character()
	if root then
		local f = flat(dir)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + f)
	end
end

local function stamina(): number
	return player:GetAttribute("Stamina") or B.MaxStamina
end

local function staminaCost(base: number): number
	local def, _, rarity = weapon()
	local cost = base * B.StaminaCostMult
	if rarity.Passive and def.Passive and def.Passive.Id == "ChakraFlow" then
		cost *= 0.8
	end
	return cost
end

local function play(name: string, speed: number?)
	local t = tracks[name]
	if t then
		t:Play(0.05)
		if speed then
			t:AdjustSpeed(speed)
		end
	end
	return t
end

-- R15: procedural combat animation (Client/ProcAnim); R6 falls back to tracks.
local function isR15(): boolean
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.RigType == Enum.HumanoidRigType.R15
end

local function rightHand(): BasePart?
	local c = player.Character
	return c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")) :: any
end

local function muzzlePosition(dir: Vector3): Vector3
	local c = player.Character
	local w = c and c:FindFirstChild("EquippedWeapon_Right")
	local m = w and w:FindFirstChild("Muzzle", true)
	if m and m:IsA("Attachment") then
		return m.WorldPosition
	end
	local _, _, root = character()
	return root and (root.Position + Vector3.new(0, 1.2, 0) + dir * 2) or Vector3.zero
end

local function feedback(kind: string)
	if Abilities.OnFeedback then
		Abilities.OnFeedback(kind)
	end
end

---------------------------------------------------------------------
-- ANIMATIONS
---------------------------------------------------------------------
local function loadTracks(char: Model)
	tracks = {}
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local animator = hum:WaitForChild("Animator", 10) :: Animator?
	if not animator then
		return
	end
	local set = hum.RigType == Enum.HumanoidRigType.R15 and Config.PlayerAnims.R15 or Config.PlayerAnims.R6
	for name, id in pairs(set) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok and t then
			t.Priority = name == "Hold" and Enum.AnimationPriority.Action or Enum.AnimationPriority.Action4
			if name == "Hold" or name == "Charge" then
				t.Looped = true
			end
			tracks[name] = t
		end
	end
	Abilities.RefreshHold()
end

function Abilities.RefreshHold()
	local def = weapon()
	local wantsHold = not NO_HOLD[def.Class]
	local t = tracks.Hold
	if not t then
		return
	end
	if wantsHold and not t.IsPlaying then
		t:Play(0.2)
	elseif not wantsHold and t.IsPlaying then
		t:Stop(0.2)
	end
end

---------------------------------------------------------------------
-- BASIC ATTACK
---------------------------------------------------------------------
local function tryAttack()
	local c, _, root = character()
	if not c or charging then
		return
	end
	local def, class, rarity = weapon()
	local as = rarity.AttackSpeed or 0
	local interval = class.Interval / (1 + as)
	local t = os.clock()
	if t - lastAttack < interval then
		return
	end
	if t - lastAttack > interval * 2.5 then
		combo = 0
	end
	lastAttack = t
	combo = combo % #class.Combo + 1
	Abilities.CooldownEnds.LMB = t + interval
	Abilities.CooldownLength.LMB = interval

	local dir, _ = aim()
	faceTowards(dir)
	remote:FireServer("Attack", { Aim = dir })
	feedback("Action")

	local color = def.Glow or rarity.Color
	if isR15() then
		ProcAnim.Attack(player.Character, def.Class, combo)
		ProcAnim.TrailBurst(player.Character, 0.3)
	end
	if class.Kind == "Ranged" then
		if not isR15() then
			play(POINT[def.Class] and "Point" or "Slash", 1.6)
		end
		VFX.Muzzle(muzzlePosition(dir), dir, color)
	else
		local big = combo == #class.Combo
		if not isR15() then
			play(big and "Lunge" or "Slash", 1 + (1 - class.Interval) * 0.6)
		end
		local scale = class.Range / 9 * (big and 1.25 or 1)
		VFX.Slash(root.CFrame * CFrame.new(0, 0.6, 0), color, scale, combo % 2 == 0)
		if big then
			VFX.Shake(0.08)
		end
	end
	SFX.Play(SWING_SOUND[def.Class] or "Swing", { Pitch = 0.95 + math.random() * 0.1 })
	VFX.Shake(0.02)
end

---------------------------------------------------------------------
-- DASH
---------------------------------------------------------------------
local function doDash(dir: Vector3, speed: number, duration: number)
	local c, _, root = character()
	if not c then
		return
	end
	local att = Instance.new("Attachment")
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = flat(dir) * speed
	lv.Parent = root
	Debris:AddItem(lv, duration)
	Debris:AddItem(att, duration)
	local def, _, rarity = weapon()
	local color = def.Glow or rarity.Color
	VFX.Afterimage(c, color)
	task.delay(duration * 0.5, function()
		if c.Parent then
			VFX.Afterimage(c, color)
		end
	end)
end

local function tryDash()
	local c, hum, root = character()
	if not c then
		return
	end
	local t = os.clock()
	if t < Abilities.CooldownEnds.Q then
		return
	end
	if stamina() < staminaCost(B.DashStamina) then
		SFX.Play("NoStamina")
		feedback("NoStamina")
		return
	end
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	Abilities.CooldownEnds.Q = t + B.DashCooldown * B.CooldownMult
	Abilities.CooldownLength.Q = B.DashCooldown * B.CooldownMult
	remote:FireServer("Dash", { Aim = flat(dir) })
	feedback("Action")
	doDash(dir, B.DashDistanceSpeed, B.DashDuration)
	ProcAnim.Play(player.Character, "Dash", 0.35)
	SFX.Play("Dash")
	VFX.FOVPunch(6)
end

---------------------------------------------------------------------
-- SKILLS
---------------------------------------------------------------------
local function canCast(slot: string, skill): boolean
	if os.clock() < Abilities.CooldownEnds[slot] then
		SFX.Play("Error", { Volume = 0.5 })
		return false
	end
	if stamina() < staminaCost(skill.Stamina) then
		SFX.Play("NoStamina")
		feedback("NoStamina")
		return false
	end
	return true
end

-- local movement for dash-type skills (server does the damage)
local function skillMovement(skill, dir: Vector3, charge: number?)
	if isR15() then
		local def = weapon()
		local ult = Config.Skills[Config.WeaponClasses[def.Class].Ultimate] == skill
		ProcAnim.Skill(player.Character, def.Class, ult and "R" or "E")
		ProcAnim.TrailBurst(player.Character, 0.45)
		if skill.Type == "DashStrike" or skill.Type == "ChargeLunge" then
			local dur = 0.22
			doDash(dir, skill.Distance / dur, dur)
		end
		return
	end
	if skill.Type == "DashStrike" or skill.Type == "ChargeLunge" then
		local dur = 0.22
		doDash(dir, skill.Distance / dur, dur)
		play("Lunge", 1.4)
	elseif skill.Type == "Projectile" or skill.Type == "Barrage" then
		play(POINT[weapon().Class] and "Point" or "Lunge", 1.2)
	else
		play("Lunge", 1)
	end
end

local function castInstant(slot: string)
	local skillId, skill = Abilities.SkillFor(slot)
	if not skill or not canCast(slot, skill) then
		return
	end
	local dir, target = aim()
	faceTowards(dir)
	remote:FireServer(slot == "E" and "Skill" or "Ultimate", { Aim = dir, Target = target })
	feedback("Action")
	skillMovement(skill, dir)
	-- optimistic cooldown (server sends the exact value back)
	local cd = skill.Cooldown * B.CooldownMult
	Abilities.CooldownEnds[slot] = os.clock() + cd
	Abilities.CooldownLength[slot] = cd
	local _ = skillId
end

local function beginCharge(slot: string)
	local _, skill = Abilities.SkillFor(slot)
	if not skill or not canCast(slot, skill) then
		return
	end
	local hand = rightHand()
	local orb = hand and VFX.ChargeOrb(hand, Vector3.new(0, -0.9, 0), skill.Color, skill.Type == "ChargeLunge" and 2.6 or 1.8, skill.Charge)
	charging = { Slot = slot, Orb = orb, Start = os.clock() }
	remote:FireServer("ChargeBegin", { Slot = slot })
	feedback("Action")
	play("Charge")
	SFX.Play("ChargeUp")
end

local function releaseCharge(slot: string)
	if not charging or charging.Slot ~= slot then
		return
	end
	local _, skill = Abilities.SkillFor(slot)
	local held = math.min(os.clock() - charging.Start, skill and skill.Charge or 1)
	if charging.Orb then
		charging.Orb.Destroy()
	end
	if tracks.Charge then
		tracks.Charge:Stop(0.1)
	end
	charging = nil
	if not skill then
		return
	end
	local dir, target = aim()
	faceTowards(dir)
	remote:FireServer("ChargeRelease", { Slot = slot, Aim = dir, Target = target })
	skillMovement(skill, dir, held)
	local cd = skill.Cooldown * B.CooldownMult
	Abilities.CooldownEnds[slot] = os.clock() + cd
	Abilities.CooldownLength[slot] = cd
end

---------------------------------------------------------------------
-- CAS handlers
---------------------------------------------------------------------
local function onAttack(_, state)
	if state == Enum.UserInputState.Begin then
		attackHeld = true
		task.spawn(function()
			while attackHeld do
				tryAttack()
				task.wait(0.05)
			end
		end)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		attackHeld = false
	end
	return Enum.ContextActionResult.Pass
end

local function onDash(_, state)
	if state == Enum.UserInputState.Begin then
		tryDash()
	end
	return Enum.ContextActionResult.Sink
end

local function skillHandler(slot: string)
	return function(_, state)
		local _, skill = Abilities.SkillFor(slot)
		if not skill then
			return Enum.ContextActionResult.Sink
		end
		if skill.Charge then
			if state == Enum.UserInputState.Begin then
				beginCharge(slot)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				releaseCharge(slot)
			end
		elseif state == Enum.UserInputState.Begin then
			castInstant(slot)
		end
		return Enum.ContextActionResult.Sink
	end
end

local function onOverdrive(_, state)
	if state == Enum.UserInputState.Begin then
		request("Overdrive")
	end
	return Enum.ContextActionResult.Sink
end

local function onPotion(_, state)
	if state == Enum.UserInputState.Begin then
		remote:FireServer("Potion")
		feedback("Action")
	end
	return Enum.ContextActionResult.Sink
end

function Abilities.SetCooldown(slot: string, duration: number)
	Abilities.CooldownEnds[slot] = os.clock() + duration
	Abilities.CooldownLength[slot] = duration
end

function Abilities.Press(slot: string)
	if slot == "Q" then
		tryDash()
	elseif slot == "E" or slot == "R" then
		local _, skill = Abilities.SkillFor(slot)
		if skill and skill.Charge then
			beginCharge(slot)
			task.delay(skill.Charge, releaseCharge, slot)
		else
			castInstant(slot)
		end
	elseif slot == "C" then
		request("Overdrive")
	elseif slot == "LMB" then
		tryAttack()
	end
end

function Abilities.Init(abilityRemote: RemoteEvent, requestFn)
	remote = abilityRemote
	request = requestFn
	ContextActionService:BindAction("AnimeAttack", onAttack, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("AnimeDash", onDash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("AnimeSkill", skillHandler("E"), true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("AnimeUltimate", skillHandler("R"), true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("AnimeOverdrive", onOverdrive, true, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)
	ContextActionService:BindAction("AnimePotion", onPotion, false, Enum.KeyCode.H)
	ContextActionService:SetTitle("AnimeAttack", "Attack")
	ContextActionService:SetTitle("AnimeDash", "Dash")
	ContextActionService:SetTitle("AnimeSkill", "Skill")
	ContextActionService:SetTitle("AnimeUltimate", "Ult")
	ContextActionService:SetTitle("AnimeOverdrive", "OD")
	for i, name in ipairs({ "AnimeAttack", "AnimeDash", "AnimeSkill", "AnimeUltimate", "AnimeOverdrive" }) do
		local positions = { UDim2.new(1, -95, 1, -170), UDim2.new(1, -170, 1, -95), UDim2.new(1, -175, 1, -175), UDim2.new(1, -250, 1, -110), UDim2.new(1, -100, 1, -250) }
		ContextActionService:SetPosition(name, positions[i])
	end

	player.CharacterAdded:Connect(function(c)
		attackHeld = false
		charging = nil
		task.spawn(loadTracks, c)
	end)
	if player.Character then
		task.spawn(loadTracks, player.Character)
	end
	player:GetAttributeChangedSignal("WeaponId"):Connect(Abilities.RefreshHold)
end

return Abilities
