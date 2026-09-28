--!nonstrict
-- EnemyFX (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/EnemyFX
-- Client-side life for enemies (all visual, nothing gameplay-relevant):
--   * Poses from the server's "Pose" attribute, blended on the waist joint:
--       Anticipate / Windup  lean back, eyes flare white, core burns hot
--       Strike               snap forward
--       Recover              slump forward, eyes and core go dim (the
--                            punish window: hits here deal extra damage)
--       Stagger / Flinch     quick recoil
--   * Health read without a head bar: the chest core dims toward embers and
--     starts to flicker as HP drops.
--   * A hair-thin health line appears for 2 s only on enemies YOU hit.
--   * Bosses get a slim top-of-screen bar only while you are near them.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local EnemyFX = {}

local player = Players.LocalPlayer
local UI
local tracked = {} -- [Model] = state
local bossBar, bossName, bossFill, bossChip
local bossShown = 0
local lastBoss = nil

-- lean targets in degrees (+ = lean back)
local POSES = {
	Idle = { Lean = 0, Speed = 6 },
	Anticipate = { Lean = 14, Speed = 5, Flare = true },
	Windup = { Lean = 20, Speed = 3.5, Flare = true },
	Strike = { Lean = -24, Speed = 28 },
	Recover = { Lean = -12, Speed = 7, Dim = true },
	Stagger = { Lean = 18, Speed = 24 },
	Flinch = { Lean = 7, Speed = 30 },
}

local EMBER = Color3.fromRGB(45, 12, 10)

local function setup(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local waist = model:FindFirstChild("Waist", true)
	local r6 = false
	if not (waist and waist:IsA("Motor6D")) then
		waist = model:FindFirstChild("RootJoint", true)
		r6 = true
	end
	local eyes = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Eye" then
			table.insert(eyes, d)
		end
	end
	local core = model:FindFirstChild("Core", true)
	if not core and not model:GetAttribute("FXRetry") then
		-- parts may still be replicating; try once more shortly
		model:SetAttribute("FXRetry", true)
		task.delay(1, setup, model)
		return
	end
	local state = {
		Model = model,
		Waist = (waist and waist:IsA("Motor6D")) and waist or nil,
		BaseC0 = (waist and waist:IsA("Motor6D")) and waist.C0 or nil,
		R6 = r6,
		Eyes = eyes,
		Core = core,
		Light = core and core:FindFirstChild("CoreLight"),
		CoreColor = model:GetAttribute("CoreColor") or (core and core.Color) or Color3.new(1, 0.3, 0.3),
		Lean = 0,
		Pose = "Idle",
		PoseEnds = 0,
		Flicker = 0,
		Sliver = nil,
		SliverUntil = 0,
	}
	tracked[model] = state
	model:GetAttributeChangedSignal("PoseId"):Connect(function()
		local pose = model:GetAttribute("Pose") or "Idle"
		local dur = model:GetAttribute("PoseDur") or 0
		state.Pose = POSES[pose] and pose or "Idle"
		state.PoseEnds = os.clock() + math.max(dur, 0.12)
		if POSES[state.Pose].Flare then
			local head = model:FindFirstChild("Head")
			if head then
				-- anime "glint" on the eyes: the tell that an attack is coming
				VFX.Emit((head :: BasePart).Position + (head :: BasePart).CFrame.LookVector * 0.7, "Stars", 2, Color3.new(1, 1, 1))
			end
		elseif state.Pose == "Recover" and core then
			VFX.Emit((core :: BasePart).Position, "Smoke", 2, Color3.fromRGB(200, 200, 210))
		end
	end)
end

local function sliverFor(state)
	if state.Sliver then
		return state.Sliver
	end
	local head = state.Model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "HPSliver"
	bb.Size = UDim2.fromOffset(64, 3)
	bb.StudsOffset = Vector3.new(0, (head :: BasePart).Size.Y + 1.1, 0)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Enabled = false
	bb.Parent = player:WaitForChild("PlayerGui")
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.6
	bg.BorderSizePixel = 0
	bg.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = state.CoreColor
	fill.BorderSizePixel = 0
	fill.Parent = bg
	state.Sliver = bb
	return bb
end

-- Called from the client's FX "Hit" handler.
function EnemyFX.OnHit(model: Model?, byLocal: boolean)
	local state = model and tracked[model]
	if not state then
		return
	end
	if state.Pose == "Idle" or os.clock() > state.PoseEnds then
		state.Pose = "Flinch"
		state.PoseEnds = os.clock() + 0.1
	end
	if byLocal and not state.Model:GetAttribute("Boss") then
		local bb = sliverFor(state)
		if bb then
			state.SliverUntil = os.clock() + 2
			bb.Enabled = true
		end
	end
end

local function applyLean(state, deg: number)
	if not state.Waist or not state.BaseC0 or not state.Waist.Parent then
		return
	end
	local a = math.rad(deg) * (state.R6 and -1 or 1)
	state.Waist.C0 = state.BaseC0 * CFrame.Angles(a, 0, 0)
end

local function stepEnemy(state, dt: number, t: number)
	local model = state.Model
	local hp = model:GetAttribute("HP") or 1
	-- pose blending
	local pose = state.Pose
	if t > state.PoseEnds and pose ~= "Idle" then
		pose = "Idle"
		state.Pose = "Idle"
	end
	local P = POSES[pose]
	state.Lean += (P.Lean - state.Lean) * math.min(1, dt * P.Speed)
	applyLean(state, state.Lean)

	-- core + eyes: the health read and the attack tell
	local base = state.CoreColor
	local coreColor = base:Lerp(EMBER, (1 - hp) * 0.75)
	local lightB = 0.35 + 1.3 * hp
	local eyeT = 0
	local eyeColor = base
	if P.Flare then
		local k = 0.6 + 0.4 * math.sin(t * 30)
		coreColor = coreColor:Lerp(Color3.new(1, 1, 1), 0.55 * k)
		eyeColor = base:Lerp(Color3.new(1, 1, 1), 0.7)
		lightB = 3.2
	elseif P.Dim then
		coreColor = coreColor:Lerp(EMBER, 0.6)
		eyeT = 0.55
		lightB = 0.15
	end
	if hp < 0.3 and hp > 0 then
		-- failing core flickers
		state.Flicker -= dt
		if state.Flicker <= 0 then
			state.Flicker = 0.05 + math.random() * 0.25
			state.FlickerOn = math.random() < 0.35
		end
		if state.FlickerOn then
			coreColor = coreColor:Lerp(EMBER, 0.7)
			lightB *= 0.2
		end
	end
	if state.Core and state.Core.Parent then
		state.Core.Color = coreColor
	end
	if state.Light then
		state.Light.Brightness = lightB
	end
	for _, eye in ipairs(state.Eyes) do
		eye.Color = eyeColor
		eye.Transparency = eyeT
	end

	-- thin hp line (only after you hit it)
	if state.Sliver then
		if t < state.SliverUntil and hp > 0 then
			local fill = state.Sliver:FindFirstChild("Fill", true)
			if fill then
				(fill :: Frame).Size = UDim2.fromScale(hp, 1)
			end
		elseif state.Sliver.Enabled then
			state.Sliver.Enabled = false
		end
	end
end

local function buildBossBar()
	local root = UI.Root()
	local H = UI.Helpers
	bossBar = Instance.new("CanvasGroup")
	bossBar.Name = "BossBar"
	bossBar.BackgroundTransparency = 1
	bossBar.GroupTransparency = 1
	bossBar.Visible = false
	bossBar.Size = UDim2.fromOffset(420, 34)
	bossBar.AnchorPoint = Vector2.new(0.5, 0)
	bossBar.Position = UDim2.new(0.5, 0, 0, 150)
	bossBar.Parent = root
	bossName = H.Text(bossBar, { Text = "", Font = Config.Fonts.Display, Size = UDim2.new(1, 0, 0, 16), Color = Color3.fromRGB(255, 200, 210) })
	local bg = H.Frame(bossBar, { Color = Color3.fromRGB(10, 6, 14), Transparency = 0.4, Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 22), Corner = 3 })
	bossChip = H.Frame(bg, { Color = Color3.new(1, 1, 1), Transparency = 0.3, Size = UDim2.fromScale(1, 1), Corner = 3 })
	bossFill = H.Frame(bg, { Color = Color3.fromRGB(255, 70, 100), Size = UDim2.fromScale(1, 1), Corner = 3, ZIndex = 2 })
end

function EnemyFX.Step(dt: number)
	local t = os.clock()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local nearestBoss, bossDist = nil, 110
	for model, state in pairs(tracked) do
		if not model.Parent then
			if state.Sliver then
				state.Sliver:Destroy()
			end
			tracked[model] = nil
			continue
		end
		local r = model:FindFirstChild("HumanoidRootPart")
		local near = root and r and ((r :: BasePart).Position - root.Position).Magnitude or math.huge
		-- only animate enemies you can actually see nearby
		if near < 160 then
			stepEnemy(state, dt, t)
		end
		if model:GetAttribute("Boss") and near < bossDist and (model:GetAttribute("HP") or 0) > 0 then
			nearestBoss, bossDist = model, near
		end
	end

	-- boss bar (contextual)
	if bossBar then
		if nearestBoss then
			local hp = nearestBoss:GetAttribute("HP") or 1
			if nearestBoss ~= lastBoss then
				lastBoss = nearestBoss
				bossName.Text = nearestBoss.Name:upper()
				bossChip.Size = UDim2.fromScale(hp, 1)
			end
			bossFill.Size = UDim2.fromScale(hp, 1)
			local chip = bossChip.Size.X.Scale
			bossChip.Size = UDim2.fromScale(chip + (hp - chip) * math.min(1, dt * 2.5), 1)
			bossShown = math.min(1, bossShown + dt * 4)
		else
			bossShown = math.max(0, bossShown - dt * 2)
		end
		bossBar.GroupTransparency = 1 - bossShown
		bossBar.Visible = bossShown > 0.01
	end
end

function EnemyFX.Init(ui)
	UI = ui
	for _, m in ipairs(CollectionService:GetTagged("Enemy")) do
		setup(m)
	end
	CollectionService:GetInstanceAddedSignal("Enemy"):Connect(setup)
	buildBossBar()
end

return EnemyFX
