--!nonstrict
-- ProcAnim (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/ProcAnim
-- Procedural combat animation (no uploaded animation assets needed).
-- Every swing is a short keyframed pose sequence played on the R15 joints
-- (shoulders, elbows, waist, neck) on top of the normal Roblox animations:
--   * PreAnimation resets the joints we drive, the Animator writes its own
--     pose, then PreSimulation multiplies our offset on top - so walking
--     and running still blend underneath the attack.
--   * Shapes: horizontal slashes both ways, overhead chops, thrusts, jabs,
--     spins, aimed shots, casts and ultimate slams, picked per weapon type
--     and combo step (Katana: right-left-overhead, Spear: thrust-thrust-
--     spin, Gloves: jab-cross-hook...).
--   * Runs for your character and for other players (from their Attack /
--     Skill events) and for enemies (their strike / wind-up events), so
--     everyone sees the same motion.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameShared"):WaitForChild("Config"))

local ProcAnim = {}

-- joint key -> R15 Motor6D name
local JOINTS = {
	RS = "RightShoulder",
	LS = "LeftShoulder",
	RE = "RightElbow",
	LE = "LeftElbow",
	W = "Waist",
	N = "Neck",
}

-- Poses: joint -> { rx, ry, rz } in degrees, in the joint's own frame.
-- Shoulder: +rx raises the arm forward, +rz swings it out to the right.
-- Waist: +ry turns the chest left, -rx leans forward.
local SHAPES = {
	SlashR = {
		{ T = 0.3, P = { RS = { 95, -15, 80 }, RE = { 25, 0, 0 }, W = { 0, -32, 0 }, LS = { 25, 0, -25 }, N = { 0, 15, 0 } } },
		{ T = 0.55, P = { RS = { 88, 25, -38 }, RE = { 4, 0, 0 }, W = { -6, 38, 0 }, LS = { 15, 0, -10 }, N = { 0, -12, 0 } } },
		{ T = 0.8, P = { RS = { 62, 20, -46 }, RE = { 10, 0, 0 }, W = { -4, 28, 0 } } },
	},
	SlashL = {
		{ T = 0.3, P = { RS = { 82, 20, -42 }, RE = { 30, 0, 0 }, W = { 0, 30, 0 }, LS = { 20, 0, -30 }, N = { 0, -10, 0 } } },
		{ T = 0.55, P = { RS = { 96, -18, 78 }, RE = { 3, 0, 0 }, W = { -6, -36, 0 }, LS = { 10, 0, -20 }, N = { 0, 14, 0 } } },
		{ T = 0.8, P = { RS = { 70, -10, 70 }, RE = { 8, 0, 0 }, W = { -3, -24, 0 } } },
	},
	Overhead = {
		{ T = 0.35, P = { RS = { 172, 0, 12 }, LS = { 168, 0, -14 }, RE = { 35, 0, 0 }, LE = { 35, 0, 0 }, W = { 14, 0, 0 }, N = { 10, 0, 0 } } },
		{ T = 0.6, P = { RS = { 38, 0, -6 }, LS = { 36, 0, 8 }, RE = { 5, 0, 0 }, LE = { 5, 0, 0 }, W = { -24, 0, 0 }, N = { -12, 0, 0 } } },
		{ T = 0.85, P = { RS = { 30, 0, 0 }, LS = { 30, 0, 0 }, W = { -16, 0, 0 } } },
	},
	Thrust = {
		{ T = 0.3, P = { RS = { 55, 0, 14 }, RE = { 85, 0, 0 }, W = { 4, -28, 0 }, LS = { 50, 0, -18 }, LE = { 60, 0, 0 } } },
		{ T = 0.5, P = { RS = { 92, 0, 0 }, RE = { 0, 0, 0 }, W = { -12, 22, 0 }, LS = { 70, 0, -10 }, LE = { 20, 0, 0 } } },
		{ T = 0.8, P = { RS = { 80, 0, 0 }, RE = { 8, 0, 0 }, W = { -8, 14, 0 } } },
	},
	JabR = {
		{ T = 0.25, P = { RS = { 40, 0, 10 }, RE = { 115, 0, 0 }, W = { 0, -18, 0 }, LS = { 55, 0, -10 }, LE = { 110, 0, 0 } } },
		{ T = 0.45, P = { RS = { 92, 0, -8 }, RE = { 0, 0, 0 }, W = { -6, 26, 0 }, LS = { 50, 0, -10 }, LE = { 115, 0, 0 } } },
	},
	JabL = {
		{ T = 0.25, P = { LS = { 40, 0, -10 }, LE = { 115, 0, 0 }, W = { 0, 18, 0 }, RS = { 55, 0, 10 }, RE = { 110, 0, 0 } } },
		{ T = 0.45, P = { LS = { 92, 0, 8 }, LE = { 0, 0, 0 }, W = { -6, -26, 0 }, RS = { 50, 0, 10 }, RE = { 115, 0, 0 } } },
	},
	Spin = {
		{ T = 0.2, P = { RS = { 90, 0, 80 }, LS = { 30, 0, -40 }, W = { 0, -60, 0 } } },
		{ T = 0.7, P = { RS = { 90, 0, 80 }, LS = { 30, 0, -40 }, W = { 0, 300, 0 } } },
		{ T = 0.9, P = { RS = { 70, 0, 50 }, W = { 0, 360, 0 } } },
	},
	Aim = {
		{ T = 0.15, P = { RS = { 92, 0, 0 }, RE = { 0, 0, 0 }, LS = { 70, 0, 20 }, LE = { 30, 0, 0 }, W = { 0, -12, 0 }, N = { 0, 10, 0 } } },
		{ T = 0.35, P = { RS = { 104, 0, 0 }, RE = { 12, 0, 0 }, LS = { 70, 0, 20 }, LE = { 30, 0, 0 }, W = { 6, -12, 0 }, N = { 0, 10, 0 } } },
		{ T = 0.75, P = { RS = { 90, 0, 0 }, LS = { 60, 0, 15 }, W = { 0, -8, 0 } } },
	},
	Cast = {
		{ T = 0.35, P = { RS = { 60, 0, 30 }, LS = { 60, 0, -30 }, RE = { 70, 0, 0 }, LE = { 70, 0, 0 }, W = { 12, 0, 0 } } },
		{ T = 0.6, P = { RS = { 100, 0, 8 }, LS = { 100, 0, -8 }, RE = { 0, 0, 0 }, LE = { 0, 0, 0 }, W = { -16, 0, 0 } } },
		{ T = 0.85, P = { RS = { 92, 0, 6 }, LS = { 92, 0, -6 }, W = { -10, 0, 0 } } },
	},
	Ultimate = {
		{ T = 0.35, P = { RS = { 175, 0, 25 }, LS = { 175, 0, -25 }, W = { 22, 0, 0 }, N = { 20, 0, 0 } } },
		{ T = 0.55, P = { RS = { 180, 0, 20 }, LS = { 180, 0, -20 }, W = { 26, 0, 0 }, N = { 25, 0, 0 } } },
		{ T = 0.75, P = { RS = { 40, 0, 10 }, LS = { 40, 0, -10 }, W = { -30, 0, 0 }, N = { -15, 0, 0 } } },
	},
	Dash = {
		{ T = 0.3, P = { RS = { -45, 0, 20 }, LS = { -45, 0, -20 }, W = { -28, 0, 0 }, N = { 15, 0, 0 } } },
		{ T = 0.75, P = { RS = { -35, 0, 15 }, LS = { -35, 0, -15 }, W = { -20, 0, 0 } } },
	},
	-- enemies
	Windup = {
		{ T = 0.5, P = { RS = { 150, 0, 40 }, RE = { 60, 0, 0 }, W = { 18, -25, 0 }, LS = { 40, 0, -40 } } },
		{ T = 1, P = { RS = { 160, 0, 45 }, RE = { 70, 0, 0 }, W = { 20, -28, 0 }, LS = { 45, 0, -45 } } },
	},
}

-- combo shapes per weapon class
local COMBOS = {
	Katana = { "SlashR", "SlashL", "Overhead" },
	Greatsword = { "SlashR", "SlashL", "SlashR", "Overhead" },
	Scythe = { "SlashR", "SlashL", "Spin" },
	Glove = { "JabR", "JabL", "JabR" },
	Claws = { "SlashR", "SlashL", "JabR", "SlashL" },
	Daggers = { "SlashR", "SlashL", "SlashR", "SlashL" },
	Spear = { "Thrust", "Thrust", "Spin" },
	Hammer = { "Overhead", "SlashR", "Overhead" },
	Chain = { "SlashR", "Spin" },
	Fan = { "SlashL", "SlashR", "Spin" },
	Pistols = { "Aim" },
	FingerGun = { "Aim" },
	Bow = { "Aim" },
	Cannon = { "Aim" },
	Staff = { "Cast", "Aim" },
	Kunai = { "Aim", "JabR" },
}

local active: { [Model]: any } = {}

local function motors(model: Model)
	local out = {}
	for key, name in pairs(JOINTS) do
		local m = model:FindFirstChild(name, true)
		if m and m:IsA("Motor6D") then
			out[key] = m
		end
	end
	return out
end

local function ease(t: number): number
	return 1 - (1 - t) ^ 3
end

local ZERO = { 0, 0, 0 }
local function angles(pose, key)
	return (pose and pose[key]) or ZERO
end

-- wrap to (-180, 180] so a finished spin does not unwind backwards
local function wrap(a: number): number
	return ((a + 180) % 360) - 180
end
local function wrapped(p)
	return { wrap(p[1]), wrap(p[2]), wrap(p[3]) }
end

-- Plays a shape on a character / enemy model. speed scales the duration.
function ProcAnim.Play(model: Model?, shapeName: string, duration: number?, scale: number?)
	if not model or not model.Parent then
		return
	end
	local shape = SHAPES[shapeName]
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not shape or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local m = motors(model)
	if not m.RS then
		return
	end
	-- the previous clip's current pose is the starting point (smooth chains)
	local prev = active[model]
	local startPose = prev and prev.Current or {}
	active[model] = {
		Motors = m,
		Shape = shape,
		Start = os.clock(),
		Duration = duration or 0.45,
		Scale = scale or 1,
		From = startPose,
		Current = startPose,
	}
end

-- Weapon basic attack for a class + combo step (1-based).
function ProcAnim.Attack(model: Model?, class: string?, combo: number?)
	local list = COMBOS[class or ""] or COMBOS.Katana
	local shape = list[((combo or 1) - 1) % #list + 1]
	local cls = Config.WeaponClasses[class or ""]
	local interval = cls and cls.Interval or 0.45
	ProcAnim.Play(model, shape, math.clamp(interval * 1.15, 0.3, 0.75))
end

-- Enemy weapon look -> the class whose swings it borrows.
local ENEMY_CLASS = { Katana = "Katana", Kunai = "Daggers", Blades = "Daggers", Staff = "Staff", Scythe = "Scythe", Club = "Hammer", Fists = "Glove", Gun = "Pistols", Bow = "Bow", Fan = "Fan" }
function ProcAnim.EnemyStrike(model: Model?)
	if not model then
		return
	end
	local arch = Config.EnemyArchetypes[model:GetAttribute("Archetype") or ""]
	local class = ENEMY_CLASS[arch and arch.Weapon or "Fists"] or "Glove"
	ProcAnim.Attack(model, class, math.random(1, 3))
end

function ProcAnim.Skill(model: Model?, class: string?, slot: string?)
	if slot == "R" then
		ProcAnim.Play(model, "Ultimate", 0.8)
		return
	end
	local cls = Config.WeaponClasses[class or ""]
	if cls and cls.Kind == "Ranged" then
		ProcAnim.Play(model, "Cast", 0.55)
	else
		local list = COMBOS[class or ""] or COMBOS.Katana
		ProcAnim.Play(model, list[#list], 0.55)
	end
end

local function sample(clip, now: number)
	local u = (now - clip.Start) / clip.Duration
	if u >= 1 then
		return nil
	end
	local keys = clip.Shape
	-- find the segment
	local prevT, prevPose, first = 0, clip.From, true
	for _, k in ipairs(keys) do
		if u <= k.T then
			local a = ease((u - prevT) / math.max(1e-3, k.T - prevT))
			local out = {}
			for key in pairs(JOINTS) do
				local p0, p1 = angles(prevPose, key), angles(k.P, key)
				if first then
					p0 = wrapped(p0)
				end
				out[key] = { p0[1] + (p1[1] - p0[1]) * a, p0[2] + (p1[2] - p0[2]) * a, p0[3] + (p1[3] - p0[3]) * a }
			end
			return out
		end
		prevT, prevPose, first = k.T, k.P, false
	end
	-- tail: ease back to rest
	local a = ease((u - prevT) / math.max(1e-3, 1 - prevT))
	local out = {}
	for key in pairs(JOINTS) do
		local p0 = wrapped(angles(prevPose, key))
		out[key] = { p0[1] * (1 - a), p0[2] * (1 - a), p0[3] * (1 - a) }
	end
	return out
end

-- Flash the equipped weapon's swing trail (WeaponModels adds "SwingTrail").
function ProcAnim.TrailBurst(model: Model?, duration: number)
	if not model then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Trail") and d.Name == "SwingTrail" then
			d.Enabled = true
			local token = (d:GetAttribute("Burst") or 0) + 1
			d:SetAttribute("Burst", token)
			task.delay(duration, function()
				if d.Parent and d:GetAttribute("Burst") == token then
					d.Enabled = false
				end
			end)
		end
	end
end

function ProcAnim.Init()
	-- 1) before the Animator: clear what we added last frame
	RunService.PreAnimation:Connect(function()
		for model, clip in pairs(active) do
			if not model.Parent then
				active[model] = nil
			else
				for _, motor in pairs(clip.Motors) do
					if motor.Parent then
						motor.Transform = CFrame.identity
					end
				end
			end
		end
	end)
	-- 2) after the Animator: layer our pose on top
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for model, clip in pairs(active) do
			local pose = sample(clip, now)
			if not pose then
				active[model] = nil
			else
				clip.Current = pose
				local s = clip.Scale
				for key, motor in pairs(clip.Motors) do
					local a = pose[key]
					if a and motor.Parent then
						motor.Transform = motor.Transform * CFrame.Angles(math.rad(a[1] * s), math.rad(a[2] * s), math.rad(a[3] * s))
					end
				end
			end
		end
	end)
end

return ProcAnim
