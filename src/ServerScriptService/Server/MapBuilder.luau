--!nonstrict
-- MapBuilder (ModuleScript) -> ServerScriptService/Server/MapBuilder
-- Builds the whole world in code, simulator style (and a little darker):
--   Spawn Plaza   Soul Forge, Sell + Upgrade stalls, Race altar, Rebirth /
--                 Ascension statue, Ore Index and four leaderboards.
--   West island   Training Grounds (multiplier pads gated by rebirths /
--                 ascensions).
--   East island   Boss Rush arena.
--   North         THE PATH: one long road of stages like +1 Loot To Forge.
--                 Kill enough enemies to open the next gate; a boss guards
--                 every 5th stage; the theme changes every zone.
-- There is NO VIP room and NO PvP arena.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))
local Format = require(Shared:WaitForChild("Format"))

local MapBuilder = {}

local WHITE = Color3.new(1, 1, 1)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y (flat disc)

local root: Folder

local function P(parent: Instance, props): Part
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p :: any
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function disc(parent, pos: Vector3, diameter: number, thickness: number, color: Color3, material: Enum.Material?, name: string?)
	return P(parent, {
		Name = name or "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = CFrame.new(pos) * FLAT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- Minimal world label. Starts at 0% opacity (the "Fade" CanvasGroup) and is
-- faded in by Client/WorldText only when a player walks close. No boxes:
-- the text sits on a soft glow streak with a light drop shadow.
-- radius (optional) widens the proximity zone for very large landmarks.
local function textLine(parent: Instance, name: string, text: string, color: Color3, font: Enum.Font, pos: UDim2, size: UDim2, z: number)
	local shadow = Instance.new("TextLabel")
	shadow.Name = name .. "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Position = pos + UDim2.fromOffset(0, 2)
	shadow.Size = size
	shadow.Font = font
	shadow.TextScaled = true
	shadow.Text = text
	shadow.TextColor3 = Color3.fromRGB(8, 6, 16)
	shadow.TextTransparency = 0.45
	shadow.ZIndex = z
	shadow.Parent = parent
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.Font = font
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.ZIndex = z + 1
	t.Parent = parent
	-- keep the shadow in sync if the text is changed later (gate labels)
	t:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = t.Text
	end)
	local glow = Instance.new("UIStroke")
	glow.Thickness = 1.2
	glow.Color = color
	glow.Transparency = 0.6
	glow.Parent = t
	return t
end

local function billboard(adornee: Instance, title: string, sub: string?, color: Color3, height: number, scale, radius: number?)
	scale = (scale or 1) * Config.WorldText.FontScale
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(320 * scale, (sub and 100 or 62) * scale)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.MaxDistance = 150
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.ClipsDescendants = false
	if radius then
		bb:SetAttribute("Radius", radius)
	end
	CollectionService:AddTag(bb, "WorldLabel")
	bb.Parent = adornee

	local fade = Instance.new("CanvasGroup")
	fade.Name = "Fade"
	fade.BackgroundTransparency = 1
	fade.Size = UDim2.fromScale(1, 1)
	fade.GroupTransparency = 1 -- 0% opacity until the player is near
	fade.Parent = bb

	-- soft glow streak behind the title (no hard edges, no box)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, sub and 0.34 or 0.5)
	glow.Size = UDim2.fromScale(1, sub and 0.5 or 0.8)
	glow.BackgroundColor3 = color
	glow.BorderSizePixel = 0
	glow.Parent = fade
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow

	local titleH = sub and 0.6 or 1
	textLine(fade, "Title", title, color:Lerp(WHITE, 0.25), Config.Fonts.Display, UDim2.fromScale(0, 0), UDim2.fromScale(1, titleH), 2)
	if sub then
		local rule = Instance.new("Frame")
		rule.Name = "Rule"
		rule.AnchorPoint = Vector2.new(0.5, 0)
		rule.Position = UDim2.fromScale(0.5, 0.63)
		rule.Size = UDim2.new(0.4, 0, 0, 1)
		rule.BackgroundColor3 = color
		rule.BorderSizePixel = 0
		rule.Parent = fade
		local rg = Instance.new("UIGradient")
		rg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		rg.Parent = rule
		textLine(fade, "Sub", sub, Color3.fromRGB(235, 232, 245), Config.Fonts.Body, UDim2.fromScale(0.05, 0.68), UDim2.fromScale(0.9, 0.3), 2)
	end
	return bb
end

-- Custom-styled prompt (drawn by Client/PromptUI). "key" is the server
-- action run when the client reports the prompt was triggered.
local function prompt(parent: Instance, action: string, object: string, name: string, key: string): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.Prompt.MaxActivationDistance
	pp.RequiresLineOfSight = Config.Prompt.RequiresLineOfSight
	pp.Style = Enum.ProximityPromptStyle.Custom
	-- F / D-pad up, because E / X are the weapon-skill binds
	pp.KeyboardKeyCode = Enum.KeyCode.F
	pp.GamepadKeyCode = Enum.KeyCode.DPadUp
	pp:SetAttribute("Action", key)
	pp.Parent = parent
	return pp
end

-- Point of interest: drawn on the world map (Client/WorldMap) and gently
-- framed by the camera when you walk near it (Client/CameraDirector).
-- kind = "Service" | "Power" | "Travel" | "Danger". opts.Frame = framing
-- radius in studs (0 = no camera framing), opts.Travel = teleport id.
local function poi(part: BasePart, name: string, kind: string, desc: string, region: string, opts)
	opts = opts or {}
	part:SetAttribute("POIName", name)
	part:SetAttribute("POIKind", kind)
	part:SetAttribute("POIDesc", desc)
	part:SetAttribute("Region", region)
	part:SetAttribute("FrameRadius", opts.Frame or 22)
	if opts.Travel then
		part:SetAttribute("Travel", opts.Travel)
	end
	CollectionService:AddTag(part, "POI")
end

local function emitter(parent: Instance, preset: string, color: Color3, rate: number, offset: Vector3?)
	local a = Instance.new("Attachment")
	a.Position = offset or Vector3.zero
	a.Parent = parent
	local e = VFX.MakeEmitter(preset, color, a, rate)
	return e, a
end

local function light(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

local function loopSound(parent: Instance, id: string, volume: number, pitch: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = 80
	s.Parent = parent
	s.Playing = true
	return s
end

local function spin(inst: Instance, speed: number, bob: number?)
	inst:SetAttribute("SpinSpeed", speed)
	if bob then
		inst:SetAttribute("Bob", bob)
	end
	CollectionService:AddTag(inst, "Spin")
end

---------------------------------------------------------------------
-- LIGHTING (bright anime look: bloom, saturation, sun rays)
---------------------------------------------------------------------
local function buildLighting()
	local G = Config.Graphics
	-- Technology can't be set from scripts (Roblox security); the place file
	-- ships with Future. This pcall just makes the intent explicit.
	pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	-- late dusk: long shadows, a little darker overall (Config.Graphics)
	Lighting.ClockTime = G.ClockTime
	Lighting.Brightness = G.Brightness
	Lighting.Ambient = G.Ambient
	Lighting.OutdoorAmbient = G.OutdoorAmbient
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.18
	Lighting.ExposureCompensation = G.Exposure
	Lighting.GeographicLatitude = 35

	-- soft volumetric clouds for depth on the horizon
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(200, 185, 215)
	clouds.Parent = workspace.Terrain

	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") then
			c:Destroy()
		end
	end
	local atm = Instance.new("Atmosphere")
	atm.Density = G.Atmosphere.Density
	atm.Offset = G.Atmosphere.Offset
	atm.Color = G.Atmosphere.Color
	atm.Decay = G.Atmosphere.Decay
	atm.Glare = G.Atmosphere.Glare
	atm.Haze = G.Atmosphere.Haze
	atm.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Threshold = G.Bloom.Threshold
	bloom.Size = G.Bloom.Size
	bloom.Intensity = G.Bloom.Intensity
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GameColor"
	cc.Contrast = G.ColorCorrection.Contrast
	cc.Saturation = G.ColorCorrection.Saturation
	cc.Brightness = G.ColorCorrection.Brightness
	cc.TintColor = Color3.fromRGB(255, 250, 255)
	cc.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = G.SunRays.Intensity
	rays.Spread = G.SunRays.Spread
	rays.Parent = Lighting
end

-- Optional PBR MaterialVariants from Config.Graphics.MaterialVariants.
local function applyMaterialVariants(folderRoot: Instance)
	local variants = {}
	for matName, maps in pairs(Config.Graphics.MaterialVariants) do
		local base = (Enum.Material :: any)[matName]
		if base and maps.ColorMap and maps.ColorMap ~= "rbxassetid://0" then
			local name = "Anime_" .. matName
			local mv = MaterialService:FindFirstChild(name) or Instance.new("MaterialVariant")
			mv.Name = name
			mv.BaseMaterial = base
			mv.ColorMap = maps.ColorMap
			mv.NormalMap = maps.NormalMap or ""
			mv.RoughnessMap = maps.RoughnessMap or ""
			mv.MetalnessMap = maps.MetalnessMap or ""
			mv.Parent = MaterialService
			variants[base] = name
		end
	end
	if next(variants) == nil then
		return
	end
	for _, d in ipairs(folderRoot:GetDescendants()) do
		if d:IsA("BasePart") and variants[d.Material] then
			d.MaterialVariant = variants[d.Material]
		end
	end
end

-- Big invisible volumes that emit ambient particles.
local function ambientVolume(parent: Instance, cf: CFrame, size: Vector3, preset: string, color: Color3, rate: number)
	local vol = P(parent, { Name = "AmbientFX", Size = size, CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
	local e = VFX.MakeEmitter(preset, color, vol, rate)
	e.Shape = Enum.ParticleEmitterShape.Box
	return e
end

---------------------------------------------------------------------
-- DECOR PIECES
---------------------------------------------------------------------
local function cherryTree(parent, pos: Vector3, scale: number, rng: Random)
	local m = Instance.new("Model")
	m.Name = "CherryTree"
	local trunkH = 10 * scale
	P(m, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(trunkH, 1.8 * scale, 1.8 * scale), CFrame = CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * FLAT, Color = Color3.fromRGB(95, 60, 55), Material = Enum.Material.Wood })
	local pinks = { Color3.fromRGB(255, 170, 205), Color3.fromRGB(255, 195, 220), Color3.fromRGB(250, 145, 190) }
	local top = pos + Vector3.new(0, trunkH, 0)
	local canopy
	for i = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-0.5, 2.5), rng:NextNumber(-3, 3)) * scale
		local s = rng:NextNumber(7, 10) * scale
		canopy = P(m, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * s, CFrame = CFrame.new(top + off), Color = pinks[(i % 3) + 1], Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = true })
	end
	if canopy then
		emitter(canopy, "Petals", Color3.fromRGB(255, 170, 210), 1.2)
	end
	m.Parent = parent
	return m
end

local function lantern(parent, pos: Vector3, color: Color3?)
	color = color or Color3.fromRGB(255, 190, 110)
	P(parent, { Name = "LanternPost", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)), Color = Color3.fromRGB(60, 40, 40), Material = Enum.Material.Wood })
	P(parent, { Name = "LanternArm", Size = Vector3.new(0.4, 0.4, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 7.8, 0.9)), Color = Color3.fromRGB(60, 40, 40), Material = Enum.Material.Wood })
	local lamp = P(parent, { Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 6.8, 1.8)), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	local l = light(lamp, color :: Color3, 18, 1.4, true)
	CollectionService:AddTag(l, "Flicker")
	return lamp
end

local function torii(parent, cf: CFrame, width: number, height: number)
	local red = Color3.fromRGB(215, 45, 45)
	local black = Color3.fromRGB(30, 25, 30)
	for _, side in ipairs({ -1, 1 }) do
		P(parent, { Name = "ToriiPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.8, 1.8), CFrame = cf * CFrame.new(side * width / 2, height / 2, 0) * FLAT, Color = red, Material = Enum.Material.SmoothPlastic })
	end
	P(parent, { Name = "ToriiTop", Size = Vector3.new(width + 6, 1.4, 2.2), CFrame = cf * CFrame.new(0, height + 0.7, 0), Color = black })
	P(parent, { Name = "ToriiBeam", Size = Vector3.new(width + 4, 1.2, 1.6), CFrame = cf * CFrame.new(0, height - 2.2, 0), Color = red })
	P(parent, { Name = "ToriiBeam2", Size = Vector3.new(width + 2, 1, 1.4), CFrame = cf * CFrame.new(0, height - 0.4, 0), Color = red })
end

local function stall(parent, cf: CFrame, color: Color3, title: string, sub: string)
	local m = Instance.new("Model")
	m.Name = title .. "Stall"
	local wood = Color3.fromRGB(140, 95, 60)
	P(m, { Name = "Floor", Size = Vector3.new(16, 0.6, 12), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.WoodPlanks })
	local counter = P(m, { Name = "Counter", Size = Vector3.new(12, 3.4, 2.6), CFrame = cf * CFrame.new(0, 2.3, 3), Color = wood, Material = Enum.Material.WoodPlanks })
	P(m, { Name = "CounterTop", Size = Vector3.new(12.6, 0.4, 3.2), CFrame = cf * CFrame.new(0, 4.1, 3), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
	for _, x in ipairs({ -7, 7 }) do
		for _, z in ipairs({ -5, 4.5 }) do
			P(m, { Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = cf * CFrame.new(x, 5, z), Color = wood, Material = Enum.Material.Wood })
		end
	end
	-- striped awning
	for i = 0, 7 do
		local c = (i % 2 == 0) and color or WHITE
		P(m, { Name = "Awning", Size = Vector3.new(1.95, 0.4, 12), CFrame = cf * CFrame.new(-7 + i * 2 + 1, 10.4, 0) * CFrame.Angles(math.rad(-12), 0, 0), Color = c })
	end
	-- crates of glowing ore
	for i, ore in ipairs({ Config.Ores[1], Config.Ores[3], Config.Ores[4] }) do
		local crate = P(m, { Name = "Crate", Size = Vector3.new(2.6, 2, 2.6), CFrame = cf * CFrame.new(-6 + i * 3, 1.6, -3.5), Color = Color3.fromRGB(120, 85, 55), Material = Enum.Material.WoodPlanks })
		for j = 1, 3 do
			P(m, { Name = "Ore", Size = Vector3.one * 0.8, CFrame = crate.CFrame * CFrame.new((j - 2) * 0.7, 1.2, (j % 2) * 0.4) * CFrame.Angles(0.4 * j, 0.7 * j, 0.2), Color = ore.Color, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	billboard(counter, title, sub, color, 10.5, 0.9)
	m.Parent = parent
	return m, counter
end

---------------------------------------------------------------------
-- SPAWN PLAZA
---------------------------------------------------------------------
local STONE = Color3.fromRGB(62, 58, 72)
local STONE_DARK = Color3.fromRGB(42, 39, 52)
local TRIM = Color3.fromRGB(255, 120, 190)
local W = Config.World

local function bridge(parent, from: Vector3, to: Vector3, width: number, color: Color3)
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to)
	P(parent, { Name = "Bridge", Size = Vector3.new(width, 1.2, len), CFrame = cf * CFrame.new(0, -0.1, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	for _, side in ipairs({ -1, 1 }) do
		P(parent, { Name = "Rail", Size = Vector3.new(0.6, 1.6, len), CFrame = cf * CFrame.new(side * (width / 2 - 0.3), 1, 0), Color = STONE, Material = Enum.Material.Slate })
		P(parent, { Name = "RailGlow", Size = Vector3.new(0.2, 0.2, len), CFrame = cf * CFrame.new(side * (width / 2 - 0.3), 1.9, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	end
end

local function board(parent, cf: CFrame, title: string, color: Color3)
	local b = P(parent, { Name = title .. "Board", Size = Vector3.new(16, 20, 1), CFrame = cf * CFrame.new(0, 11, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	P(parent, { Name = "BoardFrame", Size = Vector3.new(16.8, 20.8, 0.8), CFrame = b.CFrame * CFrame.new(0, 0, 0.2), Color = color, Material = Enum.Material.Neon, CanCollide = false }).Transparency = 0.6
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Board"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = b
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
	bg.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.75), Color3.fromRGB(10, 8, 16))
	grad.Rotation = 90
	grad.Parent = bg
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.05, 0.02)
	t.Size = UDim2.fromScale(0.9, 0.11)
	t.Font = Config.Fonts.Display
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.Parent = bg
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromScale(0.05, 0.15)
	rows.Size = UDim2.fromScale(0.9, 0.83)
	rows.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.008, 0)
	layout.Parent = rows
	return b, rows
end

local function buildPlaza(map)
	local hub = folder("Plaza", root)
	local rng = Random.new(7)

	-- dark meadow below everything (walkable, so nobody falls forever)
	P(hub, { Name = "Ground", Size = Vector3.new(1400, 4, 1400), CFrame = CFrame.new(0, -3, -300), Color = Color3.fromRGB(34, 44, 36), Material = Enum.Material.Grass })

	local R = W.PlazaRadius
	disc(hub, Vector3.new(0, 0.5, 0), R * 2, 2, STONE, Enum.Material.Slate, "Plaza")
	disc(hub, Vector3.new(0, 1.55, 0), R * 2 - 10, 0.2, Color3.fromRGB(78, 74, 90), Enum.Material.Slate, "PlazaInner")
	disc(hub, Vector3.new(0, 1.6, 0), R * 2 - 9, 0.12, TRIM, Enum.Material.Neon, "PlazaGlow").Transparency = 0.55
	disc(hub, Vector3.new(0, 1.7, 0), 26, 0.12, Color3.fromRGB(95, 88, 115), Enum.Material.Marble, "Emblem")
	disc(hub, Vector3.new(0, 1.75, 0), 22, 0.1, TRIM, Enum.Material.Neon, "EmblemGlow").Transparency = 0.7

	-- spawn
	local spawn = P(hub, { ClassName = "SpawnLocation", Name = "Spawn", Size = Vector3.new(10, 0.4, 10), CFrame = CFrame.new(0, 1.8, 34), Color = TRIM, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = true })
	spawn.Duration = 0
	spawn.Neutral = true
	emitter(spawn, "Rise", TRIM, 5)
	map.HubCFrame = CFrame.new(0, 5, 30)
	poi(spawn, "Spawn", "Travel", "Where every adventure starts.", "Hub", { Frame = 0, Travel = "Hub" })

	---------------- SOUL FORGE (north centre) ----------------
	local forge = Instance.new("Model")
	forge.Name = "SoulForge"
	local fpos = Vector3.new(0, 1.6, -34)
	disc(forge, fpos + Vector3.new(0, 0.6, 0), 30, 1.2, STONE_DARK, Enum.Material.Slate, "ForgeBase")
	disc(forge, fpos + Vector3.new(0, 1.25, 0), 26, 0.2, Color3.fromRGB(255, 110, 30), Enum.Material.Neon, "ForgeRing").Transparency = 0.55
	P(forge, { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(14, 10, 14), CFrame = CFrame.new(fpos + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(34, 30, 38), Material = Enum.Material.Metal })
	disc(forge, fpos + Vector3.new(0, 10.3, 0), 14.4, 0.9, Color3.fromRGB(58, 52, 62), Enum.Material.Metal, "Rim")
	local lava = disc(forge, fpos + Vector3.new(0, 10.4, 0), 12, 0.6, Color3.fromRGB(255, 120, 30), Enum.Material.Neon, "Lava")
	light(lava, Color3.fromRGB(255, 130, 50), 38, 3.2, true)
	emitter(lava, "Embers", Color3.fromRGB(255, 150, 60), 14, Vector3.new(0, 0.5, 0))
	emitter(lava, "Fire", Color3.fromRGB(255, 120, 30), 10, Vector3.new(0, 0.5, 0))
	loopSound(lava, "rbxasset://sounds/action_swim.mp3", 0.45, 0.35)
	-- anvils where weapons take shape
	for _, side in ipairs({ -1, 1 }) do
		local ax = fpos + Vector3.new(side * 11, 0, 4)
		P(forge, { Name = "AnvilBase", Size = Vector3.new(2, 2.6, 2), CFrame = CFrame.new(ax + Vector3.new(0, 2.5, 0)), Color = Color3.fromRGB(48, 48, 58), Material = Enum.Material.Metal })
		P(forge, { Name = "AnvilTop", Size = Vector3.new(4.6, 1.2, 2.2), CFrame = CFrame.new(ax + Vector3.new(0, 4.4, 0)), Color = Color3.fromRGB(70, 70, 86), Material = Enum.Material.Metal })
		local glowBar = P(forge, { Name = "Ingot", Size = Vector3.new(2.4, 0.3, 0.6), CFrame = CFrame.new(ax + Vector3.new(0, 5.15, 0)), Color = Color3.fromRGB(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false })
		emitter(glowBar, "Sparks", Color3.fromRGB(255, 170, 70), 2)
	end
	P(forge, { Name = "Chimney", Size = Vector3.new(7, 30, 7), CFrame = CFrame.new(fpos + Vector3.new(0, 15, -13)), Color = Color3.fromRGB(70, 44, 42), Material = Enum.Material.Brick })
	local chimTop = P(forge, { Name = "ChimneyTop", Size = Vector3.new(8.5, 1.5, 8.5), CFrame = CFrame.new(fpos + Vector3.new(0, 30.5, -13)), Color = STONE_DARK, Material = Enum.Material.Slate })
	emitter(chimTop, "Smoke", Color3.fromRGB(90, 85, 95), 4, Vector3.new(0, 1, 0))
	billboard(lava, "SOUL FORGE", "Combine ores into weapons", Color3.fromRGB(255, 160, 60), 9)
	map.ForgePrompt = prompt(lava, "Forge Weapons", "Soul Forge", "ForgePrompt", "Forge")
	map.ForgePrompt.MaxActivationDistance = 14
	forge.Parent = hub
	map.Forge = lava
	poi(lava, "Soul Forge", "Service", "Combine 1-3 ores into a weapon. Ore effects carry over; secret combos forge iconic weapons.", "Hub", { Frame = 28, Travel = "Hub" })

	---------------- SELL + UPGRADES ----------------
	local _, sellCounter = stall(hub, CFrame.new(-44, 1.6, -4) * CFrame.Angles(0, math.rad(70), 0), Color3.fromRGB(255, 200, 60), "SELL", "Ore -> Coins")
	map.Sell = sellCounter
	map.SellPrompt = prompt(sellCounter, "Sell Ore", "Merchant", "SellPrompt", "Sell")
	poi(sellCounter, "Merchant", "Service", "Sell ore for Coins.", "Hub", { Frame = 20, Travel = "Hub" })
	local _, upCounter = stall(hub, CFrame.new(44, 1.6, -4) * CFrame.Angles(0, math.rad(-70), 0), Color3.fromRGB(80, 170, 255), "UPGRADES", "Bag / Luck / Training")
	map.UpgradePrompt = prompt(upCounter, "Open Upgrades", "Trainer", "UpgradePrompt", "Upgrades")
	poi(upCounter, "Upgrades", "Service", "Infinite Bag, Luck and Training upgrades.", "Hub", { Frame = 20, Travel = "Hub" })

	---------------- RACE ALTAR (north-west) ----------------
	local altar = Instance.new("Model")
	altar.Name = "RaceAltar"
	local apos = Vector3.new(-40, 1.6, -38)
	disc(altar, apos + Vector3.new(0, 0.6, 0), 18, 1.2, STONE_DARK, Enum.Material.Slate, "AltarBase")
	disc(altar, apos + Vector3.new(0, 1.25, 0), 14, 0.2, Color3.fromRGB(140, 110, 255), Enum.Material.Neon, "AltarGlow").Transparency = 0.4
	local orb = P(altar, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.6, CFrame = CFrame.new(apos + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(190, 160, 255), Material = Enum.Material.Neon, CanCollide = false })
	spin(orb, 0, 0.8)
	light(orb, Color3.fromRGB(160, 120, 255), 24, 2.4, true)
	emitter(orb, "Vortex", Color3.fromRGB(170, 120, 255), 3)
	P(altar, { Name = "Pedestal", Size = Vector3.new(3, 4, 3), CFrame = CFrame.new(apos + Vector3.new(0, 3, 0)), Color = STONE, Material = Enum.Material.Marble })
	billboard(orb, "RACE ALTAR", "Roll your bloodline", Color3.fromRGB(190, 150, 255), 5)
	map.RacePrompt = prompt(orb, "Roll Race", "Race Altar", "RacePrompt", "Race")
	map.RacePrompt.MaxActivationDistance = 12
	altar.Parent = hub
	poi(orb, "Race Altar", "Power", "Roll your anime bloodline.", "Hub", { Frame = 22, Travel = "Hub" })

	---------------- REBIRTH / ASCENSION STATUE (north-east) ----------------
	local statue = Instance.new("Model")
	statue.Name = "AscensionStatue"
	local spos = Vector3.new(40, 1.6, -38)
	P(statue, { Name = "Rock", Size = Vector3.new(11, 4, 11), CFrame = CFrame.new(spos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(20), 0), Color = STONE_DARK, Material = Enum.Material.Rock })
	local blade = P(statue, { Name = "Blade", Size = Vector3.new(1.3, 18, 3.6), CFrame = CFrame.new(spos + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(6)), Color = Color3.fromRGB(200, 210, 230), Material = Enum.Material.Metal })
	P(statue, { Name = "Edge", Size = Vector3.new(0.55, 18, 0.45), CFrame = blade.CFrame * CFrame.new(0, 0, 1.9), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Neon, CanCollide = false })
	P(statue, { Name = "Guard", Size = Vector3.new(1.9, 1.5, 9), CFrame = blade.CFrame * CFrame.new(0, 9.6, 0), Color = Color3.fromRGB(230, 180, 60), Material = Enum.Material.Metal })
	local pommel = P(statue, { Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = blade.CFrame * CFrame.new(0, 13, 0), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Neon })
	light(pommel, Color3.fromRGB(255, 200, 90), 28, 2, true)
	emitter(blade, "Rise", Color3.fromRGB(255, 220, 110), 4)
	billboard(pommel, "REBIRTH", "Rebirth & Ascend for huge multipliers", Color3.fromRGB(255, 215, 90), 4)
	local holder = P(statue, { Name = "PromptHolder", Size = Vector3.one, Transparency = 1, CanCollide = false, CFrame = CFrame.new(spos + Vector3.new(0, 4, 0)) })
	map.RebirthPrompt = prompt(holder, "Rebirth / Ascend", "Sword of Ascension", "RebirthPrompt", "Rebirth")
	statue.Parent = hub
	poi(holder, "Sword of Ascension", "Power", "Rebirth for x1.65 Power each, Ascend for x8.", "Hub", { Frame = 24, Travel = "Hub" })

	---------------- ORE INDEX ----------------
	local indexBoard, indexRows = board(hub, CFrame.lookAt(Vector3.new(-62, 1.6, 26), Vector3.new(0, 1.6, 10)), "ORE INDEX", Color3.fromRGB(120, 220, 255))
	local lines = {}
	for _, ore in ipairs(Config.Ores) do
		table.insert(lines, string.format('<font color="#%s">%s</font> <font color="#aaaaaa">%s</font>', ore.Color:ToHex(), ore.Name, Config.Effects[ore.Effect].Name))
	end
	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Font = Config.Fonts.Body
	body.TextScaled = true
	body.RichText = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.new(1, 1, 1)
	body.Text = table.concat(lines, "\n")
	body.Parent = indexRows
	map.IndexPrompt = prompt(indexBoard, "Open Index", "Ore Index", "IndexPrompt", "Index")
	poi(indexBoard, "Ore Index", "Service", "Every ore and its weapon effect.", "Hub", { Frame = 0, Travel = "Hub" })

	---------------- LEADERBOARDS (south arc) ----------------
	map.Leaderboards = {}
	for i, lb in ipairs(Config.Leaderboards) do
		local x = -45 + (i - 1) * 30
		local _, rows = board(hub, CFrame.lookAt(Vector3.new(x, 1.6, 60), Vector3.new(x * 0.6, 1.6, 0)), lb.Title, lb.Color)
		map.Leaderboards[lb.Key] = rows
	end

	---------------- light decor (kept sparse) ----------------
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + 0.4
		local pos = Vector3.new(math.cos(a) * (R + 22), -1, math.sin(a) * (R + 22))
		if math.abs(pos.X) > 30 and math.abs(pos.Z) > 20 then
			cherryTree(hub, pos, rng:NextNumber(1, 1.3), rng)
		end
	end
	for _, pos in ipairs({ Vector3.new(-9, 1.6, -64), Vector3.new(9, 1.6, -64), Vector3.new(-64, 1.6, 9), Vector3.new(-64, 1.6, -9), Vector3.new(64, 1.6, 9), Vector3.new(64, 1.6, -9) }) do
		lantern(hub, pos)
	end
end

---------------------------------------------------------------------
-- TRAINING GROUNDS (west island)
---------------------------------------------------------------------
local function buildTrain(map)
	local train = folder("TrainingGrounds", root)
	local c = W.TrainCenter
	bridge(train, Vector3.new(-W.PlazaRadius + 2, 1.2, 0), Vector3.new(c.X + 60, 1.2, 0), 16, Color3.fromRGB(120, 255, 170))
	disc(train, c + Vector3.new(0, 0.5, 0), 124, 2, STONE, Enum.Material.Slate, "Island")
	disc(train, c + Vector3.new(0, 1.6, 0), 118, 0.12, Color3.fromRGB(120, 255, 170), Enum.Material.Neon, "IslandGlow").Transparency = 0.6
	local sign = P(train, { Name = "Sign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = CFrame.new(c + Vector3.new(50, 1.6, 0)) })
	billboard(sign, "TRAINING GROUNDS", "Pads unlock with Rebirths & Ascensions", Color3.fromRGB(120, 255, 170), 10, 1.2, 18)
	map.TrainCFrame = CFrame.new(c + Vector3.new(44, 5, 0)) * CFrame.Angles(0, math.rad(90), 0)
	poi(sign, "Training Grounds", "Power", "Stand on a pad or swing to gain Power. Bigger pads unlock with Rebirths and Ascensions.", "Train", { Frame = 0, Travel = "Train" })

	map.TrainPads = {}
	local count = #Config.TrainPads
	for i, pad in ipairs(Config.TrainPads) do
		-- pads sweep in an arc from the bridge side around the island
		local a = math.rad(-150 + (i - 1) * (300 / (count - 1)))
		local pos = c + Vector3.new(-math.cos(a) * 36, 1.7, math.sin(a) * 36)
		local base = disc(train, pos, Config.TrainPadRadius * 2 + 1.6, 0.3, STONE_DARK, Enum.Material.Metal, "PadBase")
		local glow = disc(train, pos + Vector3.new(0, 0.15, 0), Config.TrainPadRadius * 2, 0.25, pad.Color, Enum.Material.Neon, "Pad")
		glow.Transparency = 0.4
		glow:SetAttribute("PadIndex", i)
		glow:SetAttribute("Mult", pad.Mult)
		glow:SetAttribute("RebirthReq", pad.Rebirths)
		glow:SetAttribute("AscensionReq", pad.Ascensions)
		CollectionService:AddTag(glow, "TrainPad")
		emitter(glow, "Rise", pad.Color, 2 + i)
		light(glow, pad.Color, 16, 1.1)
		local req = "Free"
		if pad.Ascensions > 0 then
			req = pad.Ascensions .. " Ascension" .. (pad.Ascensions > 1 and "s" or "")
		elseif pad.Rebirths > 0 then
			req = pad.Rebirths .. " Rebirth" .. (pad.Rebirths > 1 and "s" or "")
		end
		billboard(base, "x" .. Format.Abbrev(pad.Mult), req, pad.Color, 6, 0.7)
		table.insert(map.TrainPads, { Part = glow, Config = pad, Index = i, Position = pos })
	end
end

---------------------------------------------------------------------
-- BOSS RUSH ARENA (east island)
---------------------------------------------------------------------
local function buildBossRush(map)
	local br = folder("BossRush", root)
	local c = W.BossRushCenter
	local purple = Color3.fromRGB(200, 110, 255)
	bridge(br, Vector3.new(W.PlazaRadius - 2, 1.2, 0), Vector3.new(c.X - 50, 1.2, 0), 16, purple)
	disc(br, c + Vector3.new(0, 0.5, 0), 104, 2, STONE_DARK, Enum.Material.Slate, "Island")
	disc(br, c + Vector3.new(0, 1.6, 0), 60, 0.12, purple, Enum.Material.Neon, "Glyph").Transparency = 0.7
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)
		if math.cos(a) > -0.85 then
			P(br, { Name = "Pillar", Size = Vector3.new(3, 18, 3), CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)), Color = STONE, Material = Enum.Material.Slate })
			local flame = P(br, { Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(pos + Vector3.new(0, 19.6, 0)), Color = purple, Material = Enum.Material.Neon, CanCollide = false })
			emitter(flame, "Fire", purple, 8)
			if i % 3 == 0 then
				CollectionService:AddTag(light(flame, purple, 22, 1.4, true), "Flicker")
			end
		end
	end
	local gate = P(br, { Name = "RushGate", Size = Vector3.new(1, 16, 12), CFrame = CFrame.new(c + Vector3.new(0, 9.6, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = purple, Material = Enum.Material.ForceField, Transparency = 0.1, CanCollide = false })
	emitter(gate, "Vortex", purple, 2)
	light(gate, purple, 30, 2, true)
	billboard(gate, "BOSS RUSH", "Endless bosses. How far can you go?", Color3.fromRGB(220, 160, 255), 11, 1.1, 16)
	local pp = prompt(gate, "Enter Boss Rush", "Boss Rush", "TowerPrompt", "Tower")
	pp.HoldDuration = 0.4
	map.TowerPrompt = pp
	map.TowerCFrame = CFrame.new(c + Vector3.new(-30, 5, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	poi(gate, "Boss Rush", "Danger", "Fight bosses back to back. Opens after stage " .. Config.BossRush.StageReq .. ".", "BossRush", { Frame = 30, Travel = "Tower" })
end

---------------------------------------------------------------------
-- THE PATH (north)
---------------------------------------------------------------------
local WALL_H = 7

local function stageDecor(parent, zone, stageIndex: number, center: Vector3, len: number, rng: Random)
	local half = W.PathWidth / 2
	-- two or three simple props per stage, on the edges (keeps the road clear)
	for _ = 1, 3 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local x = side * rng:NextNumber(half - 12, half - 5)
		local z = center.Z + rng:NextNumber(-len / 2 + 10, len / 2 - 10)
		if zone.Id == 1 then
			local h = rng:NextNumber(6, 14)
			P(parent, { Name = "RuinPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3, 3), CFrame = CFrame.new(x, h / 2, z) * FLAT, Color = zone.Wall, Material = Enum.Material.Marble })
		elseif zone.Id == 2 then
			local crate = P(parent, { Name = "Container", Size = Vector3.new(7, 6, 12), CFrame = CFrame.new(x, 3, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Color = Color3.fromRGB(60, 70, 90), Material = Enum.Material.CorrodedMetal })
			P(parent, { Name = "Stripe", Size = Vector3.new(7.1, 0.3, 12.1), CFrame = crate.CFrame * CFrame.new(0, 1.8, 0), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
		elseif zone.Id == 3 then
			cherryTree(parent, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.2), rng)
		elseif zone.Id == 4 then
			local shard = P(parent, { Name = "StarShard", Size = Vector3.new(2, rng:NextNumber(5, 10), 2), CFrame = CFrame.new(x, 4, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
			shard.Transparency = 0.2
		elseif zone.Id == 5 then
			P(parent, { Name = "IceSpire", Size = Vector3.new(3, rng:NextNumber(7, 14), 3), CFrame = CFrame.new(x, 4, z) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(180, 220, 245), Material = Enum.Material.Glacier })
		else
			local obelisk = P(parent, { Name = "Obelisk", Size = Vector3.new(2.5, rng:NextNumber(8, 14), 2.5), CFrame = CFrame.new(x, 5, z), Color = zone.Wall, Material = Enum.Material.Basalt })
			P(parent, { Name = "Rune", Size = Vector3.new(2.6, 0.4, 2.6), CFrame = obelisk.CFrame * CFrame.new(0, 2, 0), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
		end
	end
	local _ = stageIndex
end

local function gateArch(parent, z: number, zone, stage, stageIndex: number)
	local half = W.PathWidth / 2
	local h = stage.Boss and 30 or 22
	for _, side in ipairs({ -1, 1 }) do
		P(parent, { Name = "ArchPillar", Size = Vector3.new(4, h, 4), CFrame = CFrame.new(side * (half - 2), h / 2, z), Color = zone.Wall, Material = Enum.Material.Slate })
		P(parent, { Name = "ArchGlow", Size = Vector3.new(0.4, h - 2, 4.2), CFrame = CFrame.new(side * (half - 4.2), h / 2, z), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
	end
	local lintel = P(parent, { Name = "Lintel", Size = Vector3.new(W.PathWidth, 5, 4), CFrame = CFrame.new(0, h + 2.5, z), Color = zone.Wall, Material = Enum.Material.Slate })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0
		sg.Parent = lintel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Config.Fonts.Display
		t.TextScaled = true
		t.RichText = true
		t.Text = string.format('STAGE %d  <font color="#ffffff">%s</font>', stageIndex, stage.Boss and ("BOSS: " .. stage.Enemy) or stage.Enemy)
		t.TextColor3 = stage.Boss and Color3.fromRGB(255, 90, 110) or zone.Accent
		t.Parent = sg
	end
	-- the gate itself (opened per player on their own client)
	local gate = P(parent, { Name = "Gate_" .. stageIndex, Size = Vector3.new(W.PathWidth - 8, h, 1.2), CFrame = CFrame.new(0, h / 2, z), Color = stage.Boss and Color3.fromRGB(255, 60, 80) or zone.Accent, Material = Enum.Material.ForceField, Transparency = 0.15, CanCollide = true })
	gate:SetAttribute("Stage", stageIndex)
	CollectionService:AddTag(gate, "StageGate")
	billboard(gate, stageIndex == 1 and "OPEN" or ("CLEAR STAGE " .. (stageIndex - 1)), nil, Color3.fromRGB(255, 240, 200), 0, 0.8, 14).Name = "GateLabel"
	return gate
end

local function buildPath(map)
	local path = folder("ThePath", root)
	map.Path = { Stages = {} }
	-- bridge from the plaza to the first gate
	bridge(path, Vector3.new(0, 1.2, -W.PlazaRadius + 2), Vector3.new(0, 1.2, W.PathStartZ + 2), 22, TRIM)
	torii(path, CFrame.new(0, 1.2, -W.PlazaRadius - 6), 26, 20) -- the path entrance
	local half = W.PathWidth / 2
	for i, stage in ipairs(Config.Stages) do
		local zone = Config.Zones[stage.Zone]
		local zStart, zEnd, center = Config.StageBounds(i)
		local len = zStart - zEnd
		local stageFolder = folder("Stage_" .. i, path)
		local rng = Random.new(i * 97)
		P(stageFolder, { Name = "Floor", Size = Vector3.new(W.PathWidth, 2, len), CFrame = CFrame.new(0, -1 + 1.6, center.Z), Color = zone.Floor, Material = zone.Id == 5 and Enum.Material.Snow or (zone.Id == 2 and Enum.Material.DiamondPlate or Enum.Material.Slate) })
		for _, side in ipairs({ -1, 1 }) do
			P(stageFolder, { Name = "Wall", Size = Vector3.new(3, WALL_H, len), CFrame = CFrame.new(side * (half + 1.5), WALL_H / 2, center.Z), Color = zone.Wall, Material = Enum.Material.Slate })
			P(stageFolder, { Name = "WallTrim", Size = Vector3.new(3.2, 0.4, len), CFrame = CFrame.new(side * (half + 1.5), WALL_H, center.Z), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
			-- invisible upper wall keeps players on the road
			P(stageFolder, { Name = "Barrier", Size = Vector3.new(2, 40, len), CFrame = CFrame.new(side * (half + 1.5), WALL_H + 20, center.Z), Transparency = 1 })
		end
		-- sconces with flickering, shadow-casting light
		for z = zStart - 20, zEnd + 10, -40 do
			for _, side in ipairs({ -1, 1 }) do
				local flame = P(stageFolder, { Name = "Sconce", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(side * (half - 0.2), WALL_H + 1.4, z), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
				CollectionService:AddTag(light(flame, zone.Accent, 24, 1.2, side == 1), "Flicker")
			end
		end
		local gate = gateArch(stageFolder, zStart, zone, stage, i)
		if stage.Boss then
			local arena = disc(stageFolder, center + Vector3.new(0, 1.62, 0), 60, 0.1, Color3.fromRGB(255, 60, 80), Enum.Material.Neon, "BossArena")
			arena.Transparency = 0.75
			arena.CanCollide = false
			poi(arena, "BOSS: " .. stage.Enemy, "Danger", "Stage " .. i .. " boss.", "S" .. i, { Frame = 0, Travel = "Stage_" .. i })
		end
		if (i - 1) % Config.StagesPerZone == 0 then
			local titleHolder = P(stageFolder, { Name = "ZoneTitle", Size = Vector3.one, Transparency = 1, CanCollide = false, CFrame = CFrame.new(0, 12, zStart - 14) })
			billboard(titleHolder, zone.Name, "Zone " .. zone.Id, zone.Accent, 0, 1.3, 30)
		end
		stageDecor(stageFolder, zone, i, center, len, rng)

		local room = P(stageFolder, { Name = "Room_" .. i, Size = Vector3.new(W.PathWidth, 30, len), CFrame = CFrame.new(0, 15, center.Z), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		room:SetAttribute("Stage", i)
		room:SetAttribute("Zone", stage.Zone)
		CollectionService:AddTag(room, "StageRoom")

		map.Path.Stages[i] = {
			Stage = stage,
			Center = center + Vector3.new(0, 1.6, 0),
			SpawnMin = Vector3.new(-half + 8, 1.6, zEnd + 8),
			SpawnMax = Vector3.new(half - 8, 1.6, zStart - 14),
			Entry = CFrame.new(0, 5, zStart - 8),
			Gate = gate,
			Room = room,
		}
	end
	-- end wall
	local _, lastEnd = Config.StageBounds(#Config.Stages)
	P(path, { Name = "EndWall", Size = Vector3.new(W.PathWidth + 6, 40, 4), CFrame = CFrame.new(0, 20, lastEnd - 2), Color = STONE_DARK, Material = Enum.Material.Slate })
end

---------------------------------------------------------------------
-- AMBIENT PARTICLES (fog, dust, embers, petals) - one volume per area
---------------------------------------------------------------------
local function buildAmbient(map)
	local amb = folder("Ambient", root)
	ambientVolume(amb, CFrame.new(0, 3, 0), Vector3.new(150, 2, 150), "Fog", Color3.fromRGB(190, 180, 215), 5)
	ambientVolume(amb, CFrame.new(0, 10, 0), Vector3.new(150, 16, 150), "Dust", Color3.fromRGB(255, 235, 210), 10)
	ambientVolume(amb, CFrame.new(0, 6, -34), Vector3.new(34, 6, 34), "FloatEmbers", Color3.fromRGB(255, 150, 60), 5)
	local petals = ambientVolume(amb, CFrame.new(0, 45, 0), Vector3.new(200, 4, 200), "Petals", Color3.fromRGB(255, 160, 205), 10)
	petals.Lifetime = NumberRange.new(8, 12)
	petals.Acceleration = Vector3.new(1.5, -3, 0.8)
	ambientVolume(amb, CFrame.new(W.TrainCenter + Vector3.new(0, 3, 0)), Vector3.new(110, 2, 110), "Fog", Color3.fromRGB(180, 220, 190), 3)
	ambientVolume(amb, CFrame.new(W.BossRushCenter + Vector3.new(0, 6, 0)), Vector3.new(90, 8, 90), "FloatEmbers", Color3.fromRGB(200, 120, 255), 5)
	for _, zone in ipairs(Config.Zones) do
		local first = (zone.Id - 1) * Config.StagesPerZone + 1
		local last = first + Config.StagesPerZone - 1
		local zStart = Config.StageBounds(first)
		local _, zEnd = Config.StageBounds(last)
		local len = zStart - zEnd
		local cf = CFrame.new(0, 3, (zStart + zEnd) / 2)
		ambientVolume(amb, cf, Vector3.new(W.PathWidth - 4, 2, len), "Fog", zone.Tint:Lerp(zone.Accent, 0.2), 12)
		ambientVolume(amb, cf + Vector3.new(0, 7, 0), Vector3.new(W.PathWidth - 4, 12, len), "Dust", zone.Accent:Lerp(Color3.new(1, 1, 1), 0.5), 12)
		local special = ({ "Petals", "FloatEmbers", "Petals", "Stars", "Frost", "Void" })[zone.Id]
		local e = ambientVolume(amb, cf + Vector3.new(0, 10, 0), Vector3.new(W.PathWidth - 4, 16, len), special, zone.Accent, 10)
		e.Lifetime = NumberRange.new(3, 6)
		e.Speed = NumberRange.new(0.5, 2)
	end
	local _ = map
end

---------------------------------------------------------------------
function MapBuilder.Build()
	local old = workspace:FindFirstChild("GeneratedMap")
	if old then
		old:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "GeneratedMap"
	root.Parent = workspace

	buildLighting()
	local map = { Root = root }
	buildPlaza(map)
	buildTrain(map)
	buildBossRush(map)
	buildPath(map)
	buildAmbient(map)
	applyMaterialVariants(root)

	local arenas = folder("TowerArenas", workspace)
	map.TowerArenas = arenas
	local enemies = folder("Enemies", workspace)
	map.Enemies = enemies
	return map
end

return MapBuilder
