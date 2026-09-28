--!nonstrict
-- VFX (ModuleScript) -> ReplicatedStorage/GameShared/VFX
-- Anime-style effects: curved slash arcs, hit sparks, shockwaves, light
-- pillars, impact frames, speed lines, title cards, camera shake, FOV punch.
-- MakeEmitter() is also used by the server for auras / map decoration.
-- Only uses built-in Roblox particle textures, so nothing needs uploading.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Format = require(script.Parent:WaitForChild("Format"))

local VFX = {}

local TEX = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	Shock = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Core = "rbxasset://textures/particles/explosion01_core_main.dds",
	Implode = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Square = "rbxasset://textures/particles/SquareParticle.png",
}
VFX.Textures = TEX

local WHITE = Color3.new(1, 1, 1)

local function NS(...): NumberSequence
	local args = { ... }
	if #args == 1 then
		return NumberSequence.new(args[1])
	end
	local kps = {}
	for i = 1, #args, 2 do
		table.insert(kps, NumberSequenceKeypoint.new(args[i], args[i + 1]))
	end
	return NumberSequence.new(kps)
end
VFX.NS = NS

local function CS(a: Color3, b: Color3?): ColorSequence
	return ColorSequence.new(a, b or a)
end

---------------------------------------------------------------------
-- PARTICLE PRESETS
---------------------------------------------------------------------
local PRESETS = {
	Sparks = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Square
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 0.35, 1, 0)
		e.Squash = NS(-2.5)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Lifetime = NumberRange.new(0.2, 0.45)
		e.Speed = NumberRange.new(30, 60)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 7
		e.Acceleration = Vector3.new(0, -35, 0)
		e.LightEmission = 1
		e.Brightness = 4
	end,
	Stars = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Sparkle
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 0.4, 0.3, 1.4, 1, 0)
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Speed = NumberRange.new(8, 22)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 4
		e.RotSpeed = NumberRange.new(-180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 1
		e.Brightness = 3
	end,
	Glow = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Glow
		e.Color = CS(c)
		e.Size = NS(0, 2, 0.2, 7, 1, 9)
		e.Transparency = NS(0, 0.1, 1, 1)
		e.Lifetime = NumberRange.new(0.25, 0.35)
		e.Speed = NumberRange.new(0)
		e.LightEmission = 1
		e.Brightness = 3
		e.ZOffset = 1
	end,
	Core = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Core
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 3, 1, 12)
		e.Transparency = NS(0, 0, 1, 1)
		e.Lifetime = NumberRange.new(0.35, 0.5)
		e.Speed = NumberRange.new(0)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 1
		e.Brightness = 2
	end,
	Shock = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Shock
		e.Color = CS(c)
		e.Size = NS(0, 1, 1, 22)
		e.Transparency = NS(0, 0, 1, 1)
		e.Lifetime = NumberRange.new(0.45)
		e.Speed = NumberRange.new(0)
		e.LightEmission = 1
		e.Brightness = 3
	end,
	Smoke = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Smoke
		e.Color = CS(c)
		e.Size = NS(0, 2, 1, 7)
		e.Transparency = NS(0, 0.4, 1, 1)
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(4, 12)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 3
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.LightInfluence = 0.4
	end,
	Fire = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Fire
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 1.2, 1, 0)
		e.Transparency = NS(0, 0.2, 1, 1)
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Acceleration = Vector3.new(0, 8, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = 1
		e.Brightness = 2
	end,
	Embers = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.FireSparks
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 0.25, 1, 0)
		e.Lifetime = NumberRange.new(1, 2)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.LightEmission = 1
		e.Brightness = 3
	end,
	Shards = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Square
		e.Color = CS(c)
		e.Size = NS(0, 0.5, 1, 0)
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(18, 34)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-400, 400)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Drag = 2
		e.LightEmission = 0.6
		e.Brightness = 2
	end,
	Petals = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Square
		e.Color = CS(c, Color3.fromRGB(255, 220, 235))
		e.Size = NS(0, 0.25, 1, 0.15)
		e.Squash = NS(0.5)
		e.Lifetime = NumberRange.new(2, 4)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Acceleration = Vector3.new(1, -2, 0.5)
		e.LightEmission = 0.3
	end,
	Rise = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Sparkle
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 0.5, 1, 0)
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(4, 9)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(15, 15)
		e.LightEmission = 1
		e.Brightness = 3
	end,
	Aura = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Fire
		e.Color = CS(WHITE, c)
		e.Size = NS(0, 1.2, 0.5, 2.2, 1, 0)
		e.Transparency = NS(0, 0.4, 0.6, 0.6, 1, 1)
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.Speed = NumberRange.new(4, 7)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(0, 6, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 1
		e.Brightness = 2
		e.LockedToPart = false
	end,
	Vortex = function(e: ParticleEmitter, c: Color3)
		e.Texture = TEX.Vortex
		e.Color = CS(c)
		e.Size = NS(0, 2, 1, 4)
		e.Transparency = NS(0, 0.3, 1, 1)
		e.Lifetime = NumberRange.new(0.8, 1.2)
		e.Speed = NumberRange.new(0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(90, 180)
		e.LightEmission = 1
		e.LockedToPart = true
	end,
}
VFX.Presets = PRESETS

-- Create an emitter from a preset. Rate defaults to 0 (use :Emit()).
function VFX.MakeEmitter(preset: string, color: Color3, parent: Instance, rate: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = rate or 0
	e.LightInfluence = 0
	local fn = PRESETS[preset] or PRESETS.Sparks
	fn(e, color or WHITE)
	e.Parent = parent
	return e
end

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local fxFolder: Folder? = nil
local function folder(): Instance
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	local f = workspace:FindFirstChild("ClientFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientFX"
		f.Parent = workspace
	end
	fxFolder = f
	return f
end

local function fxPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = folder()
	return p
end
VFX.FxPart = fxPart

local function tween(inst: Instance, t: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
VFX.Tween = tween

-- Burst a preset at a world position.
function VFX.Emit(pos: Vector3, preset: string, count: number, color: Color3?)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local e = VFX.MakeEmitter(preset, color or WHITE, a)
	e:Emit(count)
	local maxLife = e.Lifetime.Max
	Debris:AddItem(a, maxLife + 0.5)
end

function VFX.Light(pos: Vector3, color: Color3, range: number, brightness: number, t: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = a
	tween(l, t, { Brightness = 0 })
	Debris:AddItem(a, t + 0.1)
end

-- Expanding neon ball flash.
function VFX.Flash(pos: Vector3, color: Color3, size: number, t)
	t = t or 0.25
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * (size * 0.3), CFrame = CFrame.new(pos), Color = color, Transparency = 0.05 })
	tween(p, t, { Size = Vector3.one * size, Transparency = 1 })
	Debris:AddItem(p, t + 0.05)
end

-- Flat expanding shockwave disc.
function VFX.Ring(pos: Vector3, color: Color3, radius: number, t, height)
	t = t or 0.45
	local p = fxPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height or 0.25, 1, 1),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = 0.15,
	})
	tween(p, t, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(p, t + 0.05)
end

-- Ring of shards flying outward (reads as a crisp anime shockwave).
function VFX.ShardRing(pos: Vector3, color: Color3, radius: number, count, t)
	count = count or 18
	t = t or 0.5
	for i = 1, count do
		local ang = (i / count) * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local start = CFrame.lookAt(pos + dir * 1.5, pos + dir * 3)
		local p = fxPart({ Size = Vector3.new(0.25, 0.25, 2.2), CFrame = start, Color = color })
		tween(p, t, { CFrame = CFrame.lookAt(pos + dir * radius, pos + dir * (radius + 1)), Size = Vector3.new(0.05, 0.05, 0.6), Transparency = 1 }, Enum.EasingStyle.Quart)
		Debris:AddItem(p, t + 0.05)
	end
end

-- Vertical pillar of light.
function VFX.Pillar(pos: Vector3, color: Color3, height: number, radius: number, t)
	t = t or 0.9
	local base = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 0.4, radius * 0.4), CFrame = base, Color = color, Transparency = 0.1 })
	local core = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 0.15, radius * 0.15), CFrame = base, Color = WHITE, Transparency = 0 })
	tween(p, t * 0.25, { Size = Vector3.new(height, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	task.delay(t * 0.3, function()
		tween(p, t * 0.7, { Size = Vector3.new(height * 1.1, 0.1, 0.1), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(core, t * 0.7, { Size = Vector3.new(height * 1.1, 0.05, 0.05), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	Debris:AddItem(p, t + 0.1)
	Debris:AddItem(core, t + 0.1)
end

---------------------------------------------------------------------
-- SLASH ARC (two curved beams -> crescent that sweeps and fades)
---------------------------------------------------------------------
local function arcAttachment(holder: BasePart, radius: number, angle: number): Attachment
	local p = Vector3.new(math.sin(angle) * radius, 0, -math.cos(angle) * radius)
	local tangent = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local a = Instance.new("Attachment")
	a.CFrame = CFrame.fromMatrix(p, tangent, Vector3.yAxis)
	a.Parent = holder
	return a
end

function VFX.Slash(origin: CFrame, color: Color3, scale, flip: boolean?)
	scale = scale or 1
	local radius = 6 * scale
	local half = math.rad(75)
	local roll = math.rad(math.random(-30, 30))
	local cf = origin * CFrame.Angles(0, 0, roll)
	if flip then
		cf = cf * CFrame.Angles(0, 0, math.pi)
	end
	local holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = cf * CFrame.Angles(0, math.rad(35), 0) })

	local a0 = arcAttachment(holder, radius, -half)
	local am = arcAttachment(holder, radius, 0)
	local a1 = arcAttachment(holder, radius, half)
	local ctrl = (4 / 3) * math.tan(half / 4) * radius

	local beams = {}
	local function mk(att0, att1, w0, w1, col, bright)
		local b = Instance.new("Beam")
		b.Attachment0 = att0
		b.Attachment1 = att1
		b.CurveSize0 = ctrl
		b.CurveSize1 = ctrl
		b.Width0 = w0
		b.Width1 = w1
		b.Segments = 24
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = bright
		b.Color = col
		b.Transparency = NS(0)
		b.Parent = holder
		table.insert(beams, b)
	end
	local w = 2.2 * scale
	mk(a0, am, 0.05, w, ColorSequence.new(color, WHITE), 4)
	mk(am, a1, w, 0.05, ColorSequence.new(WHITE, color), 4)
	mk(a0, am, 0.02, w * 0.35, CS(WHITE), 6)
	mk(am, a1, w * 0.35, 0.02, CS(WHITE), 6)

	local start = os.clock()
	local life = 0.24
	local startCF = holder.CFrame
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - start) / life
		if t >= 1 then
			conn:Disconnect()
			holder:Destroy()
			return
		end
		local ease = 1 - (1 - t) ^ 3
		holder.CFrame = startCF * CFrame.Angles(0, -math.rad(70) * ease, 0)
		local tr = NS(0, math.min(1, t * 1.6), 1, math.min(1, t * 0.6 + 0.2))
		for _, b in ipairs(beams) do
			b.Transparency = tr
		end
	end)
end

---------------------------------------------------------------------
-- HITS / DAMAGE NUMBERS / ENEMY FEEDBACK
---------------------------------------------------------------------
function VFX.HitSpark(pos: Vector3, color: Color3, crit: boolean?)
	VFX.Emit(pos, "Sparks", crit and 26 or 12, color)
	VFX.Flash(pos, crit and Color3.fromRGB(255, 230, 120) or WHITE, crit and 6 or 3.2, crit and 0.22 or 0.15)
	if crit then
		VFX.Emit(pos, "Stars", 8, Color3.fromRGB(255, 220, 80))
		VFX.Emit(pos, "Glow", 1, Color3.fromRGB(255, 200, 80))
		VFX.Light(pos, Color3.fromRGB(255, 210, 120), 16, 4, 0.25)
	end
end

function VFX.DamageNumber(pos: Vector3, amount: number, crit: boolean?, color: Color3?)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(crit and 220 or 160, crit and 70 or 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.StudsOffset = Vector3.new((math.random() - 0.5) * 3, 1.5, 0)
	bb.Adornee = a
	bb.Parent = a
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = (crit and "CRIT " or "") .. Format.Abbrev(amount)
	label.TextColor3 = color or (crit and Color3.fromRGB(255, 215, 60) or WHITE)
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = crit and 3 or 2
	stroke.Color = crit and Color3.fromRGB(120, 30, 0) or Color3.fromRGB(20, 20, 30)
	stroke.Parent = label
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 200))
	grad.Rotation = 90
	grad.Parent = label
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = label
	tween(sc, 0.12, { Scale = crit and 1.35 or 1.1 }, Enum.EasingStyle.Back)
	task.delay(0.12, function()
		tween(sc, 0.15, { Scale = 1 })
	end)
	tween(bb, 0.9, { StudsOffset = bb.StudsOffset + Vector3.new(0, crit and 5 or 4, 0) }, Enum.EasingStyle.Quart)
	task.delay(0.5, function()
		tween(label, 0.4, { TextTransparency = 1 })
		tween(stroke, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(a, 1)
end

-- Floating text (e.g. "+12 Power", "BACKPACK FULL").
function VFX.TextPop(pos: Vector3, text: string, color: Color3, size)
	size = size or 1
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240 * size, 44 * size)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 100
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Adornee = a
	bb.Parent = a
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(15, 15, 25)
	stroke.Parent = label
	tween(bb, 1, { StudsOffset = Vector3.new(0, 5, 0) }, Enum.EasingStyle.Quart)
	task.delay(0.6, function()
		tween(label, 0.4, { TextTransparency = 1 })
		tween(stroke, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(a, 1.1)
end

function VFX.EnemyHitFlash(model: Model)
	if not model or not model.Parent then
		return
	end
	local existing = model:FindFirstChild("HitFlash")
	if existing then
		existing:Destroy()
	end
	local h = Instance.new("Highlight")
	h.Name = "HitFlash"
	h.FillColor = WHITE
	h.OutlineColor = WHITE
	h.FillTransparency = 0.05
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	tween(h, 0.18, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(h, 0.2)
end

function VFX.EnemyDeath(model: Model, color: Color3, big: boolean?)
	if not model or not model.Parent then
		return
	end
	local pos = model:GetPivot().Position
	local h = Instance.new("Highlight")
	h.FillColor = WHITE
	h.OutlineColor = color
	h.FillTransparency = 0
	h.Adornee = model
	h.Parent = model
	tween(h, 0.5, { FillTransparency = 1, OutlineTransparency = 1 })
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			tween(d, 0.45, { Transparency = 1 })
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
	local scale = big and 2.5 or 1
	VFX.Emit(pos, "Shards", big and 40 or 16, color)
	VFX.Emit(pos, "Sparks", big and 40 or 18, color)
	VFX.Emit(pos, "Smoke", big and 14 or 5, Color3.fromRGB(220, 220, 230))
	VFX.Flash(pos, color, 7 * scale, 0.3)
	VFX.Ring(pos - Vector3.new(0, 1.5 * scale, 0), color, 10 * scale, 0.45)
	VFX.Light(pos, color, 20 * scale, 5, 0.4)
	if big then
		VFX.Emit(pos, "Core", 3, color)
		VFX.ShardRing(pos, color, 30, 24, 0.7)
		VFX.Pillar(pos - Vector3.new(0, 4, 0), color, 60, 8, 1.2)
	end
end

-- Red ground telegraph that fills up before a boss slam.
function VFX.Telegraph(pos: Vector3, radius: number, t: number)
	local flat = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	local outline = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = flat, Color = Color3.fromRGB(255, 40, 40), Transparency = 0.6 })
	local fill = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.5, 0.5), CFrame = flat, Color = Color3.fromRGB(255, 80, 40), Transparency = 0.35 })
	tween(fill, t, { Size = Vector3.new(0.15, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		outline:Destroy()
		fill:Destroy()
		VFX.Ring(pos, Color3.fromRGB(255, 120, 60), radius * 1.2, 0.4, 0.8)
		VFX.Emit(pos + Vector3.new(0, 1, 0), "Smoke", 18, Color3.fromRGB(180, 150, 130))
		VFX.Emit(pos + Vector3.new(0, 1, 0), "Shards", 20, Color3.fromRGB(140, 110, 90))
	end)
end

function VFX.Explosion(pos: Vector3, color: Color3, scale)
	scale = scale or 1
	VFX.Flash(pos, WHITE, 8 * scale, 0.2)
	VFX.Flash(pos, color, 14 * scale, 0.45)
	VFX.Emit(pos, "Core", 2, color)
	VFX.Emit(pos, "Sparks", math.floor(30 * scale), color)
	VFX.Emit(pos, "Smoke", math.floor(10 * scale), Color3.fromRGB(200, 200, 210))
	VFX.Ring(pos, color, 16 * scale, 0.5)
	VFX.Light(pos, color, 30 * scale, 6, 0.5)
end

---------------------------------------------------------------------
-- SCREEN FX (local player only; call VFX.Init() on the client first)
---------------------------------------------------------------------
local screenGui: ScreenGui? = nil
local shakeTrauma = 0
local fovPunch = 0
local baseFov = 70

function VFX.Init()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "ScreenFX"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 50
	sg.Parent = player:WaitForChild("PlayerGui")
	screenGui = sg

	RunService:BindToRenderStep("VFXCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		if shakeTrauma > 0 then
			local s = shakeTrauma * shakeTrauma
			local t = os.clock() * 40
			local rx = (math.noise(t, 0.3) * 2) * s * 0.035
			local ry = (math.noise(0.7, t) * 2) * s * 0.035
			local rz = (math.noise(t, t * 0.5) * 2) * s * 0.02
			cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
			shakeTrauma = math.max(0, shakeTrauma - dt * 1.8)
		end
		fovPunch = fovPunch + (0 - fovPunch) * math.min(1, dt * 8)
		cam.FieldOfView = baseFov + fovPunch
	end)
end

function VFX.SetBaseFov(f: number)
	baseFov = f
end

function VFX.Shake(amount: number)
	shakeTrauma = math.min(1, shakeTrauma + amount)
end

function VFX.FOVPunch(amount: number)
	fovPunch = amount
end

function VFX.ScreenFlash(color: Color3, startTransparency: number?, t: number?)
	if not screenGui then
		return
	end
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = startTransparency or 0.2
	f.BorderSizePixel = 0
	f.ZIndex = 20
	f.Parent = screenGui
	tween(f, t or 0.4, { BackgroundTransparency = 1 })
	Debris:AddItem(f, (t or 0.4) + 0.05)
end

-- Radial anime speed lines around the screen edge.
function VFX.SpeedLines(duration: number, color: Color3?)
	if not screenGui then
		return
	end
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 18
	holder.Parent = screenGui
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local diag = vp.Magnitude / 2
	local stopAt = os.clock() + duration
	task.spawn(function()
		while os.clock() < stopAt and holder.Parent do
			for _ = 1, 6 do
				local ang = math.random() * math.pi * 2
				local dir = Vector2.new(math.cos(ang), math.sin(ang))
				local len = diag * (0.25 + math.random() * 0.25)
				local startDist = diag * (0.75 + math.random() * 0.2)
				local line = Instance.new("Frame")
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.BorderSizePixel = 0
				line.BackgroundColor3 = color or WHITE
				line.BackgroundTransparency = 0.15
				line.Size = UDim2.fromOffset(len, math.random(2, 5))
				line.Rotation = math.deg(ang)
				local p = vp / 2 + dir * startDist
				line.Position = UDim2.fromOffset(p.X, p.Y)
				line.ZIndex = 18
				line.Parent = holder
				local endP = vp / 2 + dir * (startDist - diag * 0.3)
				tween(line, 0.25, { Position = UDim2.fromOffset(endP.X, endP.Y), BackgroundTransparency = 1, Size = UDim2.fromOffset(len * 0.4, 1) }, Enum.EasingStyle.Linear)
				Debris:AddItem(line, 0.3)
			end
			task.wait(0.03)
		end
		task.wait(0.3)
		holder:Destroy()
	end)
end

-- "Impact frame": a split-second high-contrast frame + speed lines + shake.
function VFX.ImpactFrame(color: Color3?, strength)
	strength = strength or 1
	if not screenGui then
		return
	end
	local dark = Instance.new("Frame")
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0.25
	dark.BorderSizePixel = 0
	dark.ZIndex = 19
	dark.Parent = screenGui
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Contrast = 1.2
	cc.Saturation = -1
	cc.Brightness = 0.1
	cc.Parent = workspace.CurrentCamera
	task.delay(0.07, function()
		dark:Destroy()
		cc:Destroy()
		VFX.ScreenFlash(color or WHITE, 0.1, 0.35)
	end)
	VFX.SpeedLines(0.35 * strength, color)
	VFX.Shake(0.55 * strength)
	VFX.FOVPunch(-8 * strength)
end

-- Big dramatic banner ("OVERDRIVE!", "NEW TIER", race reveals...).
function VFX.TitleCard(title: string, subtitle: string?, color, duration)
	if not screenGui then
		return
	end
	color = color or Color3.fromRGB(255, 200, 60)
	duration = duration or 1.6
	local band = Instance.new("Frame")
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(-0.6, 0.38)
	band.Size = UDim2.new(1.4, 0, 0, 120)
	band.Rotation = -4
	band.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
	band.BackgroundTransparency = 0.1
	band.BorderSizePixel = 0
	band.ZIndex = 30
	band.Parent = screenGui
	local grad = Instance.new("UIGradient")
	grad.Transparency = NS(0, 1, 0.2, 0.1, 0.8, 0.1, 1, 1)
	grad.Parent = band
	for _, y in ipairs({ 0, 1 }) do
		local stripe = Instance.new("Frame")
		stripe.AnchorPoint = Vector2.new(0, y)
		stripe.Position = UDim2.fromScale(0, y)
		stripe.Size = UDim2.new(1, 0, 0, 6)
		stripe.BackgroundColor3 = color
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 31
		stripe.Parent = band
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, subtitle and 0.42 or 0.5)
	t.Size = UDim2.new(0.6, 0, 0, 72)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.ZIndex = 32
	t.Parent = band
	local st = Instance.new("UIStroke")
	st.Thickness = 4
	st.Color = Color3.new(0, 0, 0)
	st.Parent = t
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(WHITE, color)
	tg.Rotation = 90
	tg.Parent = t
	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.AnchorPoint = Vector2.new(0.5, 0)
		s.Position = UDim2.fromScale(0.5, 0.72)
		s.Size = UDim2.new(0.6, 0, 0, 26)
		s.Font = Enum.Font.FredokaOne
		s.TextScaled = true
		s.Text = subtitle
		s.TextColor3 = WHITE
		s.ZIndex = 32
		s.Parent = band
	end
	tween(band, 0.28, { Position = UDim2.fromScale(0.5, 0.38) }, Enum.EasingStyle.Back)
	local sc = Instance.new("UIScale")
	sc.Scale = 1.4
	sc.Parent = t
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(duration, function()
		tween(band, 0.25, { Position = UDim2.fromScale(1.6, 0.38) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(band, 0.3)
	end)
end

---------------------------------------------------------------------
-- COMPOSITE MOMENTS
---------------------------------------------------------------------
-- Transformation (Overdrive / Zenkai). isLocal = true for the owner's screen FX.
function VFX.Transform(character: Model, color: Color3, isLocal: boolean, title: string?)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pos = root.Position
	local ground = pos - Vector3.new(0, 3, 0)
	VFX.Emit(pos, "Glow", 2, color)
	task.delay(0.15, function()
		VFX.Pillar(ground, color, 70, 7, 1.1)
		VFX.Ring(ground, color, 22, 0.6, 0.5)
		VFX.ShardRing(ground + Vector3.new(0, 1, 0), color, 26, 22, 0.6)
		VFX.Emit(pos, "Sparks", 50, color)
		VFX.Emit(pos, "Stars", 20, color)
		VFX.Emit(ground, "Smoke", 16, Color3.fromRGB(230, 230, 240))
		VFX.Light(pos, color, 40, 8, 1)
	end)
	if isLocal then
		VFX.FOVPunch(14)
		VFX.Shake(0.5)
		VFX.ScreenFlash(color, 0.15, 0.6)
		task.delay(0.15, function()
			VFX.ImpactFrame(color, 1.2)
			if title then
				VFX.TitleCard(title, nil, color, 1.4)
			end
		end)
	end
end

function VFX.LevelBurst(character: Model, color: Color3)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local ground = root.Position - Vector3.new(0, 3, 0)
	VFX.Ring(ground, color, 12, 0.5)
	VFX.Emit(root.Position, "Rise", 30, color)
	VFX.Emit(root.Position, "Stars", 12, color)
	VFX.Light(root.Position, color, 20, 4, 0.6)
end

---------------------------------------------------------------------
-- COMBAT EFFECTS (projectiles, charge orbs, zones, dashes)
---------------------------------------------------------------------
local projectiles = {}
local projConn: RBXScriptConnection? = nil

local function crescent(holder: BasePart, width: number, color: Color3)
	local half = math.rad(70)
	local radius = width * 0.55
	local a0 = arcAttachment(holder, radius, -half)
	local am = arcAttachment(holder, radius, 0)
	local a1 = arcAttachment(holder, radius, half)
	local ctrl = (4 / 3) * math.tan(half / 4) * radius
	local function mk(att0, att1, w0, w1, col, bright)
		local b = Instance.new("Beam")
		b.Attachment0 = att0
		b.Attachment1 = att1
		b.CurveSize0 = ctrl
		b.CurveSize1 = ctrl
		b.Width0 = w0
		b.Width1 = w1
		b.Segments = 20
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = bright
		b.Color = col
		b.Parent = holder
	end
	mk(a0, am, 0.1, width * 0.28, ColorSequence.new(color, WHITE), 5)
	mk(am, a1, width * 0.28, 0.1, ColorSequence.new(WHITE, color), 5)
	mk(a0, am, 0.05, width * 0.12, CS(WHITE), 8)
	mk(am, a1, width * 0.12, 0.05, CS(WHITE), 8)
end

local function makeProjectileVisual(kind: string, color: Color3, size: number)
	local holder
	if kind == "Orb" or kind == "Cero" then
		local s = kind == "Cero" and 1.1 or size
		holder = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * s, Color = color })
		local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.55, Color = WHITE })
		core.Name = "Core"
		core.Parent = holder
		local g = VFX.MakeEmitter("Glow", color, holder, 14)
		g.Lifetime = NumberRange.new(0.15)
		g.Size = NS(0, s * 1.6, 1, s * 2.2)
		VFX.MakeEmitter("Sparks", color, holder, 20).Speed = NumberRange.new(3, 8)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 10 + s * 3
		l.Brightness = 3
		l.Parent = holder
	elseif kind == "Crescent" then
		holder = fxPart({ Size = Vector3.one * 0.2, Transparency = 1 })
		crescent(holder, size, color)
		VFX.MakeEmitter("Sparks", color, holder, 60).Speed = NumberRange.new(4, 12)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 24
		l.Brightness = 4
		l.Parent = holder
	else -- Ray / bullet
		holder = fxPart({ Size = Vector3.new(0.22, 0.22, 3.5), Color = color })
		local core = fxPart({ Size = Vector3.new(0.1, 0.1, 3.6), Color = WHITE })
		core.Name = "Core"
		core.Parent = holder
	end
	-- trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = holder
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = kind == "Crescent" and 0.3 or 0.12
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(WHITE, color)
	tr.Transparency = NS(0, 0.2, 1, 1)
	tr.WidthScale = NS(0, kind == "Crescent" and size or 1, 1, 0)
	tr.Parent = holder
	return holder
end

local function stepProjectiles(dt)
	for id, p in pairs(projectiles) do
		p.Traveled += p.Speed * dt
		local pos = p.Origin + p.Dir * math.min(p.Traveled, p.Range)
		local cf = CFrame.lookAt(pos, pos + p.Dir)
		p.Holder.CFrame = cf
		local core = p.Holder:FindFirstChild("Core")
		if core then
			(core :: BasePart).CFrame = cf
		end
		if p.Traveled >= p.Range then
			VFX.EndProjectile(id, pos, false)
		end
	end
	if next(projectiles) == nil and projConn then
		projConn:Disconnect()
		projConn = nil
	end
end

function VFX.StartProjectile(id, kind: string, origin: Vector3, dir: Vector3, speed: number, range: number, color: Color3, size: number?)
	local holder = makeProjectileVisual(kind, color, size or 1.5)
	projectiles[id] = { Holder = holder, Origin = origin, Dir = dir.Unit, Speed = speed, Range = range, Traveled = 0, Color = color, Kind = kind }
	holder.CFrame = CFrame.lookAt(origin, origin + dir)
	if not projConn then
		projConn = RunService.RenderStepped:Connect(stepProjectiles)
	end
end

function VFX.EndProjectile(id, pos: Vector3?, hit: boolean?, explode: number?)
	local p = projectiles[id]
	if not p then
		return
	end
	projectiles[id] = nil
	local at = pos or p.Holder.Position
	p.Holder.Transparency = 1
	for _, d in ipairs(p.Holder:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
		elseif d:IsA("Beam") then
			d.Enabled = false
		elseif d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	Debris:AddItem(p.Holder, 0.6)
	if hit or explode then
		VFX.Flash(at, p.Color, explode and explode * 0.8 or (p.Kind == "Crescent" and 8 or 3), 0.2)
		VFX.Emit(at, "Sparks", explode and 40 or 10, p.Color)
		if explode then
			VFX.Explosion(at, p.Color, explode / 10)
		end
	end
end

function VFX.Muzzle(pos: Vector3, dir: Vector3, color: Color3)
	local p = fxPart({ Size = Vector3.new(0.6, 0.6, 1.4), CFrame = CFrame.lookAt(pos, pos + dir), Color = WHITE })
	tween(p, 0.08, { Size = Vector3.new(0.1, 0.1, 2.2), Transparency = 1 })
	Debris:AddItem(p, 0.1)
	VFX.Emit(pos, "Sparks", 5, color)
	VFX.Light(pos, color, 8, 3, 0.08)
end

-- A spinning energy orb that follows a part (Rasengan / charged shots).
function VFX.ChargeOrb(follow: BasePart, offset: Vector3, color: Color3, maxSize: number, chargeTime: number)
	local orb = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = color, Transparency = 0.25 })
	local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.15, Color = WHITE })
	local rings = {}
	for i = 1, 3 do
		local r = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.4, 0.4), Color = color, Transparency = 0.3 })
		rings[i] = r
	end
	local e = VFX.MakeEmitter("Vortex", color, orb, 6)
	e.Size = NS(0, 1, 1, 2)
	local sp = VFX.MakeEmitter("Sparks", color, orb, 30)
	sp.Speed = NumberRange.new(2, 6)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 12
	l.Brightness = 3
	l.Parent = orb
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not follow.Parent then
			return
		end
		local t = os.clock() - start
		local k = math.clamp(t / chargeTime, 0, 1)
		local s = 0.4 + (maxSize - 0.4) * k
		local cf = follow.CFrame * CFrame.new(offset)
		orb.Size = Vector3.one * s
		orb.CFrame = cf
		core.Size = Vector3.one * s * 0.5
		core.CFrame = cf
		for i, r in ipairs(rings) do
			r.Size = Vector3.new(0.05, s * 1.25, s * 1.25)
			r.CFrame = cf * CFrame.Angles(t * (6 + i * 2), t * (4 + i), i)
		end
	end)
	return {
		Destroy = function()
			conn:Disconnect()
			orb:Destroy()
			core:Destroy()
			for _, r in ipairs(rings) do
				r:Destroy()
			end
		end,
		Position = function()
			return orb.Position
		end,
	}
end

-- Swirling vortex zone (Dimensional Rift, Reap pulls).
function VFX.Zone(pos: Vector3, radius: number, duration: number, color: Color3)
	local flat = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.5, 0.5), CFrame = flat, Color = color, Transparency = 0.35 })
	local inner = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.3, 0.3), CFrame = flat, Color = Color3.new(0, 0, 0), Transparency = 0.1, Material = Enum.Material.SmoothPlastic })
	tween(disc, 0.3, { Size = Vector3.new(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	tween(inner, 0.3, { Size = Vector3.new(0.25, radius * 1.2, radius * 1.2) }, Enum.EasingStyle.Back)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos + Vector3.new(0, 1, 0)
	a.Parent = workspace.Terrain
	local v = VFX.MakeEmitter("Vortex", color, a, 8)
	v.Size = NS(0, radius * 0.8, 1, radius * 1.6)
	v.LockedToPart = false
	local sp = VFX.MakeEmitter("Rise", color, a, 40)
	sp.Shape = Enum.ParticleEmitterShape.Cylinder
	sp.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		disc.CFrame = flat * CFrame.Angles(t * 4, 0, 0)
		inner.CFrame = flat * CFrame.Angles(-t * 6, 0, 0)
	end)
	task.delay(duration, function()
		conn:Disconnect()
		v.Enabled = false
		sp.Enabled = false
		tween(disc, 0.3, { Size = Vector3.new(0.2, 0.1, 0.1), Transparency = 1 })
		tween(inner, 0.3, { Size = Vector3.new(0.2, 0.1, 0.1), Transparency = 1 })
		Debris:AddItem(disc, 0.35)
		Debris:AddItem(inner, 0.35)
		Debris:AddItem(a, 2)
		VFX.Flash(pos, color, radius, 0.3)
	end)
end

-- Neon afterimage of a character (dashes).
function VFX.Afterimage(character: Model, color: Color3)
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			local g = fxPart({ Size = d.Size, CFrame = d.CFrame, Color = color, Transparency = 0.45 })
			tween(g, 0.35, { Transparency = 1 })
			Debris:AddItem(g, 0.4)
		end
	end
end

-- Big frontal swipe used by cone skills.
function VFX.ConeSwipe(origin: CFrame, range: number, color: Color3)
	VFX.Slash(origin, color, range / 7, math.random() < 0.5)
	VFX.Slash(origin * CFrame.Angles(0, 0, math.rad(20)), WHITE, range / 8, true)
	local front = origin.Position + origin.LookVector * range * 0.6
	VFX.Emit(front, "Sparks", 20, color)
	VFX.Ring(front - Vector3.new(0, 2.5, 0), color, range * 0.6, 0.35)
end

function VFX.Nova(pos: Vector3, radius: number, color: Color3)
	VFX.Ring(pos - Vector3.new(0, 2.5, 0), color, radius, 0.4)
	VFX.ShardRing(pos - Vector3.new(0, 2, 0), color, radius, 18, 0.4)
	VFX.Emit(pos, "Sparks", 24, color)
	VFX.Flash(pos, color, radius * 0.5, 0.2)
end

-- Rectangular ground telegraph for lunges / line attacks.
function VFX.TelegraphLine(pos: Vector3, dir: Vector3, length: number, width: number, t: number)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	flatDir = flatDir.Magnitude > 0 and flatDir.Unit or Vector3.new(0, 0, -1)
	local center = pos + flatDir * (length / 2)
	local cf = CFrame.lookAt(center, center + flatDir)
	local outline = fxPart({ Size = Vector3.new(width, 0.1, length), CFrame = cf, Color = Color3.fromRGB(255, 40, 40), Transparency = 0.6 })
	local fill = fxPart({ Size = Vector3.new(width, 0.15, 0.2), CFrame = CFrame.lookAt(pos, pos + flatDir) * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(255, 90, 40), Transparency = 0.35 })
	tween(fill, t, { Size = Vector3.new(width, 0.15, length), CFrame = cf }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		outline:Destroy()
		fill:Destroy()
	end)
end

-- Straight energy streak between two points (dash strikes, lunges).
function VFX.Streak(from: Vector3, to: Vector3, color: Color3, width: number?)
	local d = (to - from).Magnitude
	if d < 0.5 then
		return
	end
	local w = width or 1.2
	local p = fxPart({ Size = Vector3.new(w, w * 0.4, d), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color, Transparency = 0.1 })
	local core = fxPart({ Size = Vector3.new(w * 0.35, w * 0.2, d), CFrame = p.CFrame, Color = WHITE })
	tween(p, 0.3, { Size = Vector3.new(0.05, 0.05, d), Transparency = 1 })
	tween(core, 0.3, { Size = Vector3.new(0.02, 0.02, d), Transparency = 1 })
	Debris:AddItem(p, 0.35)
	Debris:AddItem(core, 0.35)
end

return VFX
