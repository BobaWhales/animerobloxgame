--!nonstrict
-- MapBuilder (ModuleScript) -> ServerScriptService/Server/MapBuilder
-- Builds the whole world in code, laid out like +1 Loot To Forge:
--   Hub (spawn plaza) with the Forge cauldron, Sell stall, Upgrade stall,
--   Rebirth statue, Race altar, Index board and Leaderboard.
--   Train area (multiplier pads) to the west.
--   Dungeon portals to the north -> linear stage-by-stage dungeons.
--   Infinite Tower to the east.
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
local buildChestShrine, buildAmbient

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

local function billboard(adornee: Instance, title: string, sub: string?, color: Color3, height: number, scale)
	scale = scale or 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(320 * scale, (sub and 110 or 70) * scale)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Parent = adornee
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(15, 10, 25)
	st.Parent = t
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(WHITE, color)
	g.Rotation = 90
	g.Parent = t
	if sub then
		local s = Instance.new("TextLabel")
		s.Name = "Sub"
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.62)
		s.Size = UDim2.fromScale(1, 0.38)
		s.Font = Enum.Font.FredokaOne
		s.TextScaled = true
		s.Text = sub
		s.TextColor3 = WHITE
		s.Parent = bb
		local ss = Instance.new("UIStroke")
		ss.Thickness = 2
		ss.Color = Color3.fromRGB(15, 10, 25)
		ss.Parent = s
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
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(80, 75, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 165)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.05
	Lighting.GeographicLatitude = 30

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
	light(lamp, color :: Color3, 18, 1.4, true)
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
-- HUB
---------------------------------------------------------------------
local function buildHub(map)
	local hub = folder("Hub", root)
	local rng = Random.new(7)

	P(hub, { Name = "Ground", Size = Vector3.new(900, 4, 900), CFrame = CFrame.new(0, -2, 0), Color = Color3.fromRGB(105, 175, 95), Material = Enum.Material.Grass })

	-- Plaza rings
	disc(hub, Vector3.new(0, 0.15, 0), 120, 0.3, Color3.fromRGB(215, 205, 190), Enum.Material.Slate, "Plaza")
	disc(hub, Vector3.new(0, 0.2, 0), 104, 0.3, Color3.fromRGB(235, 225, 215), Enum.Material.Marble, "PlazaInner")
	disc(hub, Vector3.new(0, 0.25, 0), 60, 0.3, Color3.fromRGB(245, 200, 215), Enum.Material.Marble, "PlazaCore")
	local ringNeon = disc(hub, Vector3.new(0, 0.27, 0), 62, 0.25, Color3.fromRGB(255, 120, 190), Enum.Material.Neon, "PlazaGlow")
	ringNeon.Transparency = 0.4

	-- Paths
	local path = Color3.fromRGB(190, 180, 165)
	P(hub, { Name = "PathTrain", Size = Vector3.new(50, 0.3, 14), CFrame = CFrame.new(-80, 0.15, 0), Color = path, Material = Enum.Material.Cobblestone })
	P(hub, { Name = "PathPortals", Size = Vector3.new(14, 0.3, 50), CFrame = CFrame.new(0, 0.15, -82), Color = path, Material = Enum.Material.Cobblestone })
	P(hub, { Name = "PathTower", Size = Vector3.new(80, 0.3, 14), CFrame = CFrame.new(95, 0.15, 0), Color = path, Material = Enum.Material.Cobblestone })

	-- Spawn
	local spawn = P(hub, { ClassName = "SpawnLocation", Name = "Spawn", Size = Vector3.new(10, 0.6, 10), CFrame = CFrame.new(0, 0.5, 26), Color = Color3.fromRGB(255, 150, 200), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = true })
	spawn.Duration = 0
	spawn.Neutral = true
	emitter(spawn, "Rise", Color3.fromRGB(255, 170, 220), 6)
	map.HubCFrame = CFrame.new(0, 4, 22)

	---------------- FORGE (center) ----------------
	local forgeModel = Instance.new("Model")
	forgeModel.Name = "Forge"
	local fpos = Vector3.new(0, 0, -30)
	disc(forgeModel, fpos + Vector3.new(0, 0.6, 0), 28, 1.2, Color3.fromRGB(70, 65, 75), Enum.Material.Slate, "ForgeBase")
	disc(forgeModel, fpos + Vector3.new(0, 1.3, 0), 24, 0.3, Color3.fromRGB(255, 110, 30), Enum.Material.Neon, "ForgeGlowRing").Transparency = 0.5
	for i = 1, 3 do
		local a = i * (math.pi * 2 / 3)
		P(forgeModel, { Name = "Leg", Size = Vector3.new(1.4, 3, 1.4), CFrame = CFrame.new(fpos + Vector3.new(math.cos(a) * 4.6, 2.7, math.sin(a) * 4.6)), Color = Color3.fromRGB(35, 30, 35), Material = Enum.Material.Metal })
	end
	local pot = P(forgeModel, { Name = "Cauldron", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 13, 13), CFrame = CFrame.new(fpos + Vector3.new(0, 6.5, 0)) * FLAT, Color = Color3.fromRGB(40, 35, 45), Material = Enum.Material.Metal })
	P(forgeModel, { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(14, 9, 14), CFrame = CFrame.new(fpos + Vector3.new(0, 5.5, 0)), Color = Color3.fromRGB(40, 35, 45), Material = Enum.Material.Metal })
	disc(forgeModel, fpos + Vector3.new(0, 9.6, 0), 14.4, 0.9, Color3.fromRGB(60, 55, 65), Enum.Material.Metal, "Rim")
	local lava = disc(forgeModel, fpos + Vector3.new(0, 9.7, 0), 12, 0.6, Color3.fromRGB(255, 120, 30), Enum.Material.Neon, "Lava")
	light(lava, Color3.fromRGB(255, 140, 50), 34, 3, true)
	emitter(lava, "Embers", Color3.fromRGB(255, 150, 60), 14, Vector3.new(0, 0.5, 0))
	emitter(lava, "Fire", Color3.fromRGB(255, 120, 30), 10, Vector3.new(0, 0.5, 0))
	local _, fireAtt = emitter(forgeModel.PrimaryPart or pot, "Fire", Color3.fromRGB(255, 90, 20), 22)
	fireAtt.WorldPosition = fpos + Vector3.new(0, 1.8, 0)
	loopSound(lava, "rbxasset://sounds/action_swim.mp3", 0.5, 0.35)
	-- chimney hood
	P(forgeModel, { Name = "Chimney", Size = Vector3.new(7, 26, 7), CFrame = CFrame.new(fpos + Vector3.new(0, 13, -12)), Color = Color3.fromRGB(120, 70, 60), Material = Enum.Material.Brick })
	local chimTop = P(forgeModel, { Name = "ChimneyTop", Size = Vector3.new(8.5, 1.5, 8.5), CFrame = CFrame.new(fpos + Vector3.new(0, 26.5, -12)), Color = Color3.fromRGB(60, 50, 55), Material = Enum.Material.Slate })
	emitter(chimTop, "Smoke", Color3.fromRGB(120, 115, 125), 4, Vector3.new(0, 1, 0))
	-- anvil
	P(forgeModel, { Name = "AnvilBase", Size = Vector3.new(2, 2.4, 2), CFrame = CFrame.new(fpos + Vector3.new(10, 2.4, 5)), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
	P(forgeModel, { Name = "AnvilTop", Size = Vector3.new(4.5, 1.2, 2.2), CFrame = CFrame.new(fpos + Vector3.new(10, 4.2, 5)), Color = Color3.fromRGB(70, 70, 85), Material = Enum.Material.Metal })
	billboard(lava, "FORGE", "Smelt ore -> +1 Forge level", Color3.fromRGB(255, 160, 60), 9)
	local forgePrompt = prompt(lava, "Forge Ore", "Forge Cauldron", "ForgePrompt", "Forge")
	forgeModel.Parent = hub
	map.Forge = lava
	map.ForgePrompt = forgePrompt

	---------------- SELL + UPGRADES ----------------
	local _, sellCounter = stall(hub, CFrame.new(-40, 0, -20) * CFrame.Angles(0, math.rad(35), 0), Color3.fromRGB(255, 200, 60), "SELL", "Ore -> Coins")
	map.Sell = sellCounter
	map.SellPrompt = prompt(sellCounter, "Sell Ore", "Merchant", "SellPrompt", "Sell")
	local _, upCounter = stall(hub, CFrame.new(40, 0, -20) * CFrame.Angles(0, math.rad(-35), 0), Color3.fromRGB(80, 170, 255), "UPGRADES", "Backpack / Luck / Training")
	map.Upgrades = upCounter
	map.UpgradePrompt = prompt(upCounter, "Open Upgrades", "Trainer", "UpgradePrompt", "Upgrades")

	---------------- RACE ALTAR ----------------
	local altar = Instance.new("Model")
	altar.Name = "RaceAltar"
	local apos = Vector3.new(-42, 0, 22)
	disc(altar, apos + Vector3.new(0, 0.6, 0), 20, 1.2, Color3.fromRGB(60, 55, 90), Enum.Material.Slate, "AltarBase")
	disc(altar, apos + Vector3.new(0, 1.25, 0), 16, 0.2, Color3.fromRGB(140, 110, 255), Enum.Material.Neon, "AltarGlow").Transparency = 0.3
	local orb = P(altar, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 4, CFrame = CFrame.new(apos + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(200, 170, 255), Material = Enum.Material.Neon, CanCollide = false })
	spin(orb, 0, 0.8)
	light(orb, Color3.fromRGB(170, 130, 255), 26, 2.5, true)
	emitter(orb, "Vortex", Color3.fromRGB(170, 120, 255), 3)
	emitter(orb, "Stars", Color3.fromRGB(200, 170, 255), 4)
	P(altar, { Name = "Pedestal", Size = Vector3.new(3, 4, 3), CFrame = CFrame.new(apos + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(80, 70, 110), Material = Enum.Material.Marble })
	for i, race in ipairs(Config.Races) do
		local a = (i / #Config.Races) * math.pi * 2
		local crystal = P(altar, { Name = "Crystal_" .. race.Id, Size = Vector3.new(1.2, 3, 1.2), CFrame = CFrame.new(apos + Vector3.new(math.cos(a) * 7, 5, math.sin(a) * 7)) * CFrame.Angles(0, a, math.rad(45)), Color = race.Color, Material = Enum.Material.Neon, CanCollide = false })
		spin(crystal, 60, 0.6)
	end
	billboard(orb, "RACE ALTAR", "Roll your bloodline", Color3.fromRGB(190, 150, 255), 5)
	map.RacePrompt = prompt(orb, "Roll Race", "Race Altar", "RacePrompt", "Race")
	map.RacePrompt.MaxActivationDistance = 12
	altar.Parent = hub

	---------------- REBIRTH STATUE (giant sword in stone) ----------------
	local statue = Instance.new("Model")
	statue.Name = "RebirthStatue"
	local spos = Vector3.new(42, 0, 22)
	P(statue, { Name = "Rock", Size = Vector3.new(12, 5, 12), CFrame = CFrame.new(spos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(20), 0), Color = Color3.fromRGB(120, 115, 130), Material = Enum.Material.Rock })
	P(statue, { Name = "Rock2", Size = Vector3.new(8, 3, 9), CFrame = CFrame.new(spos + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, math.rad(55), 0), Color = Color3.fromRGB(105, 100, 115), Material = Enum.Material.Rock })
	local blade = P(statue, { Name = "Blade", Size = Vector3.new(1.4, 20, 4), CFrame = CFrame.new(spos + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(6)), Color = Color3.fromRGB(220, 230, 245), Material = Enum.Material.Metal })
	P(statue, { Name = "Edge", Size = Vector3.new(0.6, 20, 0.5), CFrame = blade.CFrame * CFrame.new(0, 0, 2.1), Color = Color3.fromRGB(255, 215, 90), Material = Enum.Material.Neon, CanCollide = false })
	P(statue, { Name = "Guard", Size = Vector3.new(2, 1.6, 10), CFrame = blade.CFrame * CFrame.new(0, 10.6, 0), Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.Metal })
	P(statue, { Name = "Hilt", Size = Vector3.new(1.4, 6, 1.4), CFrame = blade.CFrame * CFrame.new(0, 14.2, 0), Color = Color3.fromRGB(80, 30, 40), Material = Enum.Material.Fabric })
	local pommel = P(statue, { Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = blade.CFrame * CFrame.new(0, 17.6, 0), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Neon })
	light(pommel, Color3.fromRGB(255, 210, 90), 30, 2, true)
	emitter(blade, "Rise", Color3.fromRGB(255, 220, 110), 5)
	billboard(pommel, "REBIRTH", "Reset Power for permanent boosts", Color3.fromRGB(255, 215, 90), 4)
	local holder = P(statue, { Name = "PromptHolder", Size = Vector3.one, Transparency = 1, CanCollide = false, CFrame = CFrame.new(spos + Vector3.new(0, 4, 0)) })
	map.RebirthPrompt = prompt(holder, "Rebirth", "Sword of Ascension", "RebirthPrompt", "Rebirth")
	statue.Parent = hub

	---------------- INDEX + LEADERBOARD ----------------
	local function board(pos: Vector3, title: string, color: Color3)
		local b = P(hub, { Name = title .. "Board", Size = Vector3.new(18, 12, 1), CFrame = CFrame.lookAt(pos + Vector3.new(0, 8, 0), Vector3.new(0, 8, 0)), Color = Color3.fromRGB(40, 35, 50), Material = Enum.Material.Wood })
		for _, x in ipairs({ -8, 8 }) do
			P(hub, { Name = "BoardPost", Size = Vector3.new(1, 14, 1), CFrame = b.CFrame * CFrame.new(x, -1, 0.8), Color = Color3.fromRGB(90, 60, 45), Material = Enum.Material.Wood })
		end
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = b
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
		bg.Parent = sg
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromRGB(40, 30, 70), Color3.fromRGB(15, 12, 25))
		grad.Rotation = 90
		grad.Parent = bg
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0.16, 0)
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = title
		t.TextColor3 = color
		t.Parent = bg
		local list = Instance.new("TextLabel")
		list.Name = "Body"
		list.BackgroundTransparency = 1
		list.Position = UDim2.fromScale(0.05, 0.18)
		list.Size = UDim2.fromScale(0.9, 0.8)
		list.Font = Enum.Font.FredokaOne
		list.TextScaled = true
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = WHITE
		list.RichText = true
		list.Text = ""
		list.Parent = bg
		return b, list
	end
	local indexBoard, indexBody = board(Vector3.new(-20, 0, 52), "ORE INDEX", Color3.fromRGB(120, 220, 255))
	local lines = {}
	for _, ore in ipairs(Config.Ores) do
		table.insert(lines, string.format('<font color="#%s">%s</font>  (%s)', ore.Color:ToHex(), ore.Name, Config.Rarity[ore.Rarity].Label))
	end
	indexBody.Text = table.concat(lines, "\n")
	map.IndexPrompt = prompt(indexBoard, "Open Index", "Ore Index", "IndexPrompt", "Index")
	local _, lbBody = board(Vector3.new(20, 0, 52), "TOP BLADES", Color3.fromRGB(255, 210, 80))
	lbBody.Text = "Loading..."
	map.LeaderboardText = lbBody

	---------------- TREES / LANTERNS / SKY RIFT ----------------
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + 0.2
		local r = 72 + rng:NextNumber(-4, 8)
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		-- keep the paths clear
		if math.abs(pos.Z) > 12 or pos.X > -60 and pos.X < 60 then
			if not (math.abs(pos.X) < 12 and pos.Z < 0) then
				cherryTree(hub, pos, rng:NextNumber(0.9, 1.3), rng)
			end
		end
	end
	for _, pos in ipairs({ Vector3.new(-62, 0, 9), Vector3.new(-62, 0, -9), Vector3.new(-9, 0, -62), Vector3.new(9, 0, -62), Vector3.new(62, 0, 9), Vector3.new(62, 0, -9), Vector3.new(-9, 0, -100), Vector3.new(9, 0, -100) }) do
		lantern(hub, pos)
	end
	torii(hub, CFrame.new(-92, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 14, 16)
	torii(hub, CFrame.new(0, 0, -95), 14, 16)

	local rift = Instance.new("Model")
	rift.Name = "SkyRift"
	local center = Vector3.new(0, 150, -260)
	local segs = 28
	local ringHolder = P(rift, { Name = "RiftCore", Size = Vector3.one, Transparency = 1, CanCollide = false, CFrame = CFrame.new(center) })
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		P(rift, { Name = "Seg", Size = Vector3.new(3, 10, 3), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, a) * CFrame.new(0, 45, 0), Color = (i % 2 == 0) and Color3.fromRGB(0, 255, 225) or Color3.fromRGB(190, 90, 255), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	end
	emitter(ringHolder, "Vortex", Color3.fromRGB(140, 90, 255), 2).Size = VFX.NS(0, 40, 1, 80)
	rift.PrimaryPart = ringHolder
	spin(rift, 8)
	rift:SetAttribute("SpinAxis", "Z")
	rift.Parent = hub
end

---------------------------------------------------------------------
-- TRAIN AREA
---------------------------------------------------------------------
local function buildTrain(map)
	local train = folder("TrainArea", root)
	local count = #Config.TrainPads
	local startX = -110
	local spacing = 24
	local endX = startX - (count - 1) * spacing
	local centerX = (startX + endX) / 2
	P(train, { Name = "Platform", Size = Vector3.new(math.abs(endX - startX) + 40, 1, 56), CFrame = CFrame.new(centerX, 0.4, 0), Color = Color3.fromRGB(175, 165, 180), Material = Enum.Material.Slate })
	P(train, { Name = "Trim", Size = Vector3.new(math.abs(endX - startX) + 42, 0.6, 58), CFrame = CFrame.new(centerX, 0.2, 0), Color = Color3.fromRGB(255, 130, 190), Material = Enum.Material.Neon, Transparency = 0.3 })
	local sign = P(train, { Name = "Sign", Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = CFrame.new(startX + 12, 0, -22) })
	billboard(sign, "TRAIN AREA", "Swing or stand on a pad to gain Power", Color3.fromRGB(120, 255, 170), 10, 1.2)
	map.TrainCFrame = CFrame.new(startX + 8, 4, 0) * CFrame.Angles(0, math.rad(90), 0)

	map.TrainPads = {}
	for i, pad in ipairs(Config.TrainPads) do
		local pos = Vector3.new(startX - (i - 1) * spacing, 1, 0)
		local base = disc(train, pos, Config.TrainPadRadius * 2 + 1.2, 0.3, Color3.fromRGB(40, 35, 50), Enum.Material.Metal, "PadBase")
		local glow = disc(train, pos + Vector3.new(0, 0.15, 0), Config.TrainPadRadius * 2, 0.25, pad.Color, Enum.Material.Neon, "Pad")
		glow.Transparency = 0.35
		glow:SetAttribute("PadIndex", i)
		glow:SetAttribute("Mult", pad.Mult)
		glow:SetAttribute("PowerReq", pad.Power)
		glow:SetAttribute("RebirthReq", pad.Rebirths)
		CollectionService:AddTag(glow, "TrainPad")
		emitter(glow, "Rise", pad.Color, 3 + i)
		light(glow, pad.Color, 16, 1.2)
		local req = "Free"
		if pad.Rebirths > 0 then
			req = pad.Rebirths .. " Rebirth" .. (pad.Rebirths > 1 and "s" or "")
		elseif pad.Power > 0 then
			req = Format.Abbrev(pad.Power) .. " Power"
		end
		billboard(base, "x" .. Format.Abbrev(pad.Mult), req, pad.Color, 7, 0.7)
		-- training dummy behind each pad
		local dpos = pos + Vector3.new(0, 0, -16)
		P(train, { Name = "DummyPost", Size = Vector3.new(0.8, 6, 0.8), CFrame = CFrame.new(dpos + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood })
		P(train, { Name = "Dummy", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.6, 2.6), CFrame = CFrame.new(dpos + Vector3.new(0, 5, 0)) * FLAT, Color = Color3.fromRGB(210, 180, 130), Material = Enum.Material.Fabric })
		P(train, { Name = "DummyHead", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(dpos + Vector3.new(0, 7.8, 0)), Color = Color3.fromRGB(210, 180, 130), Material = Enum.Material.Fabric })
		table.insert(map.TrainPads, { Part = glow, Config = pad, Index = i, Position = pos })
	end
end

---------------------------------------------------------------------
-- PORTALS
---------------------------------------------------------------------
local function buildPortals(map)
	local portals = folder("Portals", root)
	map.Portals = {}
	for i, zone in ipairs(Config.Zones) do
		local x = -64 + (i - 1) * 32
		local base = CFrame.new(x, 0, -118)
		local accent = zone.Accent or WHITE
		local stone = Color3.fromRGB(70, 65, 85)
		P(portals, { Name = "Step", Size = Vector3.new(22, 1, 10), CFrame = base * CFrame.new(0, 0.5, 0), Color = stone, Material = Enum.Material.Slate })
		for _, side in ipairs({ -1, 1 }) do
			P(portals, { Name = "Pillar", Size = Vector3.new(2.6, 18, 2.6), CFrame = base * CFrame.new(side * 8.5, 9.5, 0), Color = stone, Material = Enum.Material.Slate })
			P(portals, { Name = "PillarGlow", Size = Vector3.new(0.5, 16, 2.7), CFrame = base * CFrame.new(side * 7.1, 9.5, 0), Color = accent, Material = Enum.Material.Neon })
		end
		P(portals, { Name = "Lintel", Size = Vector3.new(22, 2.4, 3.2), CFrame = base * CFrame.new(0, 19.4, 0), Color = stone, Material = Enum.Material.Slate })
		local surface = P(portals, {
			Name = "Portal_" .. zone.Id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 14.5, 14.5),
			CFrame = base * CFrame.new(0, 9.5, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color = zone.ComingSoon and Color3.fromRGB(90, 90, 100) or accent,
			Material = Enum.Material.Neon,
			Transparency = zone.ComingSoon and 0.6 or 0.25,
			CanCollide = zone.ComingSoon == true,
		})
		surface:SetAttribute("Zone", zone.Id)
		if not zone.ComingSoon then
			emitter(surface, "Vortex", accent, 3).Size = VFX.NS(0, 8, 1, 14)
			emitter(surface, "Sparks", accent, 8).Speed = NumberRange.new(4, 10)
			light(surface, accent, 26, 2.5, true)
			loopSound(surface, "rbxasset://sounds/action_swim.mp3", 0.25, 0.22)
		end
		local sub
		if zone.ComingSoon then
			sub = "COMING SOON"
		elseif zone.BladeReq > 0 then
			sub = "Requires Blade +" .. zone.BladeReq
		else
			sub = "Stages 1-" .. Config.StagesPerZone
		end
		billboard(surface, zone.Name, sub, accent, 12, 0.85)
		map.Portals[zone.Id] = surface
	end
end

---------------------------------------------------------------------
-- TOWER
---------------------------------------------------------------------
local function buildTower(map)
	local tower = folder("Tower", root)
	local c = Vector3.new(160, 0, 0)
	local purple = Color3.fromRGB(90, 60, 140)
	disc(tower, c + Vector3.new(0, 1, 0), 40, 2, Color3.fromRGB(70, 65, 85), Enum.Material.Slate, "TowerBase")
	P(tower, { Name = "TowerBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(120, 26, 26), CFrame = CFrame.new(c + Vector3.new(0, 62, 0)) * FLAT, Color = purple, Material = Enum.Material.Brick })
	for h = 16, 112, 16 do
		disc(tower, c + Vector3.new(0, h, 0), 27.4, 0.8, Color3.fromRGB(200, 120, 255), Enum.Material.Neon, "TowerRing")
	end
	P(tower, { Name = "TowerCap", Shape = Enum.PartType.Ball, Size = Vector3.new(30, 16, 30), CFrame = CFrame.new(c + Vector3.new(0, 122, 0)), Color = Color3.fromRGB(60, 40, 100), Material = Enum.Material.Slate })
	local crystal = P(tower, { Name = "TowerCrystal", Size = Vector3.new(6, 12, 6), CFrame = CFrame.new(c + Vector3.new(0, 140, 0)) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(220, 150, 255), Material = Enum.Material.Neon, CanCollide = false })
	spin(crystal, 40, 2)
	light(crystal, Color3.fromRGB(210, 140, 255), 60, 3, true)
	emitter(crystal, "Stars", Color3.fromRGB(220, 160, 255), 5)
	local door = P(tower, { Name = "TowerDoor", Size = Vector3.new(1, 14, 9), CFrame = CFrame.new(c + Vector3.new(-13.2, 9, 0)), Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon, Transparency = 0.2 })
	emitter(door, "Vortex", Color3.fromRGB(180, 110, 255), 2)
	billboard(door, "INFINITE TOWER", "Beat the Guardian before time runs out", Color3.fromRGB(220, 160, 255), 12, 1.1)
	local pp = prompt(door, "Enter Tower", "Infinite Tower", "TowerPrompt", "Tower")
	pp.HoldDuration = 0.4
	map.TowerPrompt = pp
	map.TowerCFrame = CFrame.new(c + Vector3.new(-22, 4, 0)) * CFrame.Angles(0, math.rad(90), 0)
end

---------------------------------------------------------------------
-- DUNGEONS (one linear hall per zone, stage rooms behind power gates)
---------------------------------------------------------------------
local ROOM_LEN = 100
local ROOM_W = 80
local START_LEN = 60
local WALL_H = 26
local DOOR_W = 24
local DOOR_H = 18

local ZONE_ORIGINS = {
	[1] = Vector3.new(0, 0, -1400),
	[2] = Vector3.new(700, 0, -1400),
}

local function decorateRoom(parent, zone, center: Vector3, rng: Random)
	if zone.Style == "Creature" then
		-- ruined academy: broken pillars, desks, vines, a cherry tree
		for _ = 1, 6 do
			local x = rng:NextNumber(-32, 32)
			local z = rng:NextNumber(-40, 40)
			if math.abs(x) > 10 then
				local h = rng:NextNumber(5, 16)
				P(parent, { Name = "RuinPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3.2, 3.2), CFrame = CFrame.new(center + Vector3.new(x, h / 2, z)) * FLAT, Color = zone.Wall, Material = Enum.Material.Marble })
			end
		end
		for _ = 1, 4 do
			local x = rng:NextNumber(-30, 30)
			local z = rng:NextNumber(-38, 38)
			P(parent, { Name = "Desk", Size = Vector3.new(4, 0.4, 2.4), CFrame = CFrame.new(center + Vector3.new(x, 2.4, z)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood, CanCollide = false })
		end
		cherryTree(parent, center + Vector3.new(rng:NextNumber(-30, -24), 0, rng:NextNumber(-30, 30)), 1, rng)
		for _ = 1, 3 do
			local g = P(parent, { Name = "Crystal", Size = Vector3.new(1.4, 3.5, 1.4), CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-34, 34), 1.5, rng:NextNumber(-44, 44))) * CFrame.Angles(0.3, rng:NextNumber(0, 3), 0.4), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
			light(g, zone.Accent, 12, 1)
		end
	else
		-- neon mecha docks: containers, floor strips, crane beams
		local colors = { Color3.fromRGB(220, 70, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(230, 170, 50) }
		for _ = 1, 5 do
			local x = rng:NextNumber(-30, 30)
			local z = rng:NextNumber(-38, 38)
			if math.abs(x) > 12 then
				local crate = P(parent, { Name = "Container", Size = Vector3.new(8, 7, 16), CFrame = CFrame.new(center + Vector3.new(x, 3.5, z)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color = colors[rng:NextInteger(1, 3)], Material = Enum.Material.CorrodedMetal })
				P(parent, { Name = "Stripe", Size = Vector3.new(8.1, 0.4, 16.1), CFrame = crate.CFrame * CFrame.new(0, 2, 0), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			P(parent, { Name = "FloorStrip", Size = Vector3.new(0.6, 0.2, ROOM_LEN - 4), CFrame = CFrame.new(center + Vector3.new(side * (ROOM_W / 2 - 4), 0.1, 0)), Color = side < 0 and zone.Accent or Color3.fromRGB(255, 60, 200), Material = Enum.Material.Neon, CanCollide = false })
		end
		local beam = P(parent, { Name = "CraneBeam", Size = Vector3.new(ROOM_W, 2, 2), CFrame = CFrame.new(center + Vector3.new(0, WALL_H + 2, rng:NextNumber(-20, 20))), Color = Color3.fromRGB(230, 170, 50), Material = Enum.Material.DiamondPlate })
		light(beam, zone.Accent, 30, 1.5, true)
	end
end

local function buildDungeon(map, zone)
	local origin = ZONE_ORIGINS[zone.Id]
	if not origin then
		return
	end
	local df = folder("Dungeon_" .. zone.Id, root)
	local stageCount = Config.StagesPerZone
	local firstStage = (zone.Id - 1) * stageCount + 1
	local totalLen = START_LEN + ROOM_LEN * stageCount
	local zCenter = origin.Z + START_LEN / 2 - totalLen / 2
	local rng = Random.new(zone.Id * 1000)

	P(df, { Name = "Floor", Size = Vector3.new(ROOM_W, 2, totalLen), CFrame = CFrame.new(origin.X, -1, zCenter), Color = zone.Floor, Material = zone.Style == "Creature" and Enum.Material.Grass or Enum.Material.DiamondPlate })
	for _, side in ipairs({ -1, 1 }) do
		P(df, { Name = "SideWall", Size = Vector3.new(4, WALL_H, totalLen), CFrame = CFrame.new(origin.X + side * (ROOM_W / 2 + 2), WALL_H / 2, zCenter), Color = zone.Wall, Material = zone.Style == "Creature" and Enum.Material.Brick or Enum.Material.Metal })
		P(df, { Name = "WallTrim", Size = Vector3.new(4.2, 0.8, totalLen), CFrame = CFrame.new(origin.X + side * (ROOM_W / 2 + 2), WALL_H, zCenter), Color = zone.Accent, Material = Enum.Material.Neon })
	end
	P(df, { Name = "BackWall", Size = Vector3.new(ROOM_W + 8, WALL_H, 4), CFrame = CFrame.new(origin.X, WALL_H / 2, origin.Z + START_LEN / 2 + 2), Color = zone.Wall, Material = Enum.Material.Slate })
	P(df, { Name = "EndWall", Size = Vector3.new(ROOM_W + 8, WALL_H, 4), CFrame = CFrame.new(origin.X, WALL_H / 2, origin.Z + START_LEN / 2 - totalLen - 2), Color = zone.Wall, Material = Enum.Material.Slate })

	-- start area: return portal + title
	local ret = P(df, { Name = "ReturnPortal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12, 12), CFrame = CFrame.new(origin + Vector3.new(0, 7, START_LEN / 2 - 3)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 150, 210), Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
	emitter(ret, "Vortex", Color3.fromRGB(255, 150, 210), 2).Size = VFX.NS(0, 6, 1, 10)
	billboard(ret, "RETURN TO HUB", nil, Color3.fromRGB(255, 170, 220), 9, 0.7)
	CollectionService:AddTag(ret, "ReturnPortal")
	local titleHolder = P(df, { Name = "ZoneTitle", Size = Vector3.one, Transparency = 1, CanCollide = false, CFrame = CFrame.new(origin + Vector3.new(0, 16, 0)) })
	billboard(titleHolder, zone.Name, "Zone " .. zone.Id, zone.Accent, 0, 1.3)

	local dungeon = { Zone = zone, Origin = origin, StartCFrame = CFrame.new(origin + Vector3.new(0, 4, 18)), Stages = {} }

	for i = 1, stageCount do
		local stageIndex = firstStage + i - 1
		local stage = Config.Stages[stageIndex]
		local gateZ = origin.Z + START_LEN / 2 - START_LEN - (i - 1) * ROOM_LEN
		local center = Vector3.new(origin.X, 0, gateZ - ROOM_LEN / 2)

		-- cross wall with doorway
		local segW = (ROOM_W - DOOR_W) / 2
		for _, side in ipairs({ -1, 1 }) do
			P(df, { Name = "CrossWall", Size = Vector3.new(segW, WALL_H, 3), CFrame = CFrame.new(origin.X + side * (DOOR_W / 2 + segW / 2), WALL_H / 2, gateZ), Color = zone.Wall, Material = Enum.Material.Slate })
		end
		local lintel = P(df, { Name = "Lintel", Size = Vector3.new(DOOR_W, WALL_H - DOOR_H, 3), CFrame = CFrame.new(origin.X, DOOR_H + (WALL_H - DOOR_H) / 2, gateZ), Color = zone.Wall, Material = Enum.Material.Slate })
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local sg = Instance.new("SurfaceGui")
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 30
			sg.LightInfluence = 0
			sg.Parent = lintel
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.LuckiestGuy
			t.TextScaled = true
			t.RichText = true
			t.Text = string.format('STAGE %d<br/><font size="30" color="#ffffff">%s</font>', stageIndex, stage.Boss and ("BOSS: " .. stage.Enemy) or stage.Enemy)
			t.TextColor3 = zone.Accent
			t.Parent = sg
		end

		local gate = P(df, { Name = "Gate_" .. stageIndex, Size = Vector3.new(DOOR_W, DOOR_H, 1.4), CFrame = CFrame.new(origin.X, DOOR_H / 2, gateZ), Color = stage.Boss and Color3.fromRGB(255, 60, 80) or zone.Accent, Material = Enum.Material.ForceField, Transparency = 0.1, CanCollide = true })
		gate:SetAttribute("Stage", stageIndex)
		gate:SetAttribute("PowerReq", stage.PowerReq)
		CollectionService:AddTag(gate, "StageGate")
		billboard(gate, stage.PowerReq > 0 and ("LOCKED - " .. Format.Abbrev(stage.PowerReq) .. " Power") or "OPEN", nil, Color3.fromRGB(255, 240, 200), 0, 0.8).Name = "GateLabel"

		-- room trigger volume (client uses it for stage banners / lighting)
		local room = P(df, { Name = "Room_" .. stageIndex, Size = Vector3.new(ROOM_W, WALL_H, ROOM_LEN), CFrame = CFrame.new(center + Vector3.new(0, WALL_H / 2, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		room:SetAttribute("Stage", stageIndex)
		room:SetAttribute("Zone", zone.Id)
		CollectionService:AddTag(room, "StageRoom")

		decorateRoom(df, zone, center, rng)
		if stage.Boss then
			local arena = disc(df, center + Vector3.new(0, 0.1, 0), 50, 0.2, Color3.fromRGB(255, 60, 80), Enum.Material.Neon, "BossArena")
			arena.Transparency = 0.7
			arena.CanCollide = false
		end

		dungeon.Stages[stageIndex] = {
			Stage = stage,
			Center = center,
			SpawnMin = center + Vector3.new(-ROOM_W / 2 + 10, 0, -ROOM_LEN / 2 + 12),
			SpawnMax = center + Vector3.new(ROOM_W / 2 - 10, 0, ROOM_LEN / 2 - 12),
			Entry = CFrame.new(Vector3.new(origin.X, 4, gateZ - 8)) * CFrame.Angles(0, 0, 0),
			Gate = gate,
			Room = room,
		}
	end
	map.Dungeons[zone.Id] = dungeon
end

---------------------------------------------------------------------
-- WEAPON CHEST SHRINE (hub)
---------------------------------------------------------------------
buildChestShrine = function(map)
	local shrine = Instance.new("Model")
	shrine.Name = "ChestShrine"
	local c = Vector3.new(0, 0, 58)
	local gold = Color3.fromRGB(255, 200, 70)
	disc(shrine, c + Vector3.new(0, 0.6, 0), 16, 1.2, Color3.fromRGB(60, 45, 70), Enum.Material.Marble, "ShrineBase")
	disc(shrine, c + Vector3.new(0, 1.25, 0), 13, 0.15, gold, Enum.Material.Neon, "ShrineGlow").Transparency = 0.4
	local base = P(shrine, { Name = "ChestBase", Size = Vector3.new(7, 3.2, 4.5), CFrame = CFrame.new(c + Vector3.new(0, 2.9, 0)), Color = Color3.fromRGB(120, 60, 40), Material = Enum.Material.WoodPlanks })
	P(shrine, { Name = "ChestLid", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 4.5, 4.5), CFrame = CFrame.new(c + Vector3.new(0, 4.5, 0)), Color = Color3.fromRGB(135, 70, 45), Material = Enum.Material.WoodPlanks })
	for _, x in ipairs({ -3.2, 0, 3.2 }) do
		P(shrine, { Name = "Band", Size = Vector3.new(0.4, 3.3, 4.6), CFrame = CFrame.new(c + Vector3.new(x, 2.9, 0)), Color = gold, Material = Enum.Material.Metal })
	end
	local lock = P(shrine, { Name = "Lock", Size = Vector3.new(1, 1.2, 0.4), CFrame = CFrame.new(c + Vector3.new(0, 3.6, -2.35)), Color = gold, Material = Enum.Material.Neon })
	local crack = P(shrine, { Name = "Crack", Size = Vector3.new(6.6, 0.15, 4.4), CFrame = CFrame.new(c + Vector3.new(0, 4.5, 0)), Color = gold, Material = Enum.Material.Neon })
	light(crack, gold, 22, 2.5, true)
	emitter(crack, "Stars", gold, 6, Vector3.new(0, 1, 0))
	for i, r in ipairs(Config.WeaponRarities) do
		local a = (i / #Config.WeaponRarities) * math.pi * 2
		local gem = P(shrine, { Name = "Gem_" .. r.Id, Size = Vector3.new(0.9, 1.6, 0.9), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 6, 8, math.sin(a) * 6)) * CFrame.Angles(0, a, math.rad(45)), Color = r.Color, Material = Enum.Material.Neon, CanCollide = false })
		spin(gem, 70, 0.5)
	end
	billboard(lock, "WEAPON CHESTS", "Keys, scrolls and gacha spins", gold, 7, 1)
	map.ChestPrompt = prompt(base, "Open Chests", "Weapon Shrine", "ChestPrompt", "Chests")
	shrine.Parent = root:FindFirstChild("Hub") or root
end

---------------------------------------------------------------------
-- AMBIENT PARTICLES (energy motes, cherry blossoms, dark aura trails)
---------------------------------------------------------------------
buildAmbient = function(map)
	local amb = folder("Ambient", root)
	local motes = ambientVolume(amb, CFrame.new(0, 10, -10), Vector3.new(180, 16, 180), "Rise", Color3.fromRGB(180, 220, 255), 14)
	motes.Speed = NumberRange.new(0.5, 1.5)
	motes.Lifetime = NumberRange.new(3, 5)
	motes.Size = VFX.NS(0, 0, 0.2, 0.25, 0.8, 0.25, 1, 0)
	local petals = ambientVolume(amb, CFrame.new(0, 45, 0), Vector3.new(220, 4, 220), "Petals", Color3.fromRGB(255, 170, 210), 20)
	petals.Lifetime = NumberRange.new(8, 12)
	petals.Acceleration = Vector3.new(1.5, -3, 0.8)
	petals.Size = VFX.NS(0, 0.35, 1, 0.25)
	for zoneId, dungeon in pairs(map.Dungeons) do
		local o = dungeon.Origin
		local len = 60 + 100 * Config.StagesPerZone
		local cf = CFrame.new(o.X, 3, o.Z + 30 - len / 2)
		if zoneId == 2 then
			local dark = ambientVolume(amb, cf, Vector3.new(76, 2, len), "Aura", Color3.fromRGB(110, 40, 180), 30)
			dark.Transparency = VFX.NS(0, 0.7, 0.5, 0.8, 1, 1)
			dark.Speed = NumberRange.new(1, 3)
			dark.Lifetime = NumberRange.new(1.5, 2.5)
			dark.LockedToPart = false
		else
			local flies = ambientVolume(amb, cf + Vector3.new(0, 5, 0), Vector3.new(76, 10, len), "Stars", Color3.fromRGB(170, 255, 140), 18)
			flies.Speed = NumberRange.new(0.2, 1)
			flies.Lifetime = NumberRange.new(2, 4)
			flies.Size = VFX.NS(0, 0, 0.5, 0.35, 1, 0)
		end
	end
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
	local map = { Root = root, Dungeons = {} }
	buildHub(map)
	buildTrain(map)
	buildPortals(map)
	buildTower(map)
	buildChestShrine(map)
	for _, zone in ipairs(Config.Zones) do
		if not zone.ComingSoon then
			buildDungeon(map, zone)
		end
	end
	buildAmbient(map)
	applyMaterialVariants(root)

	local arenas = folder("TowerArenas", workspace)
	map.TowerArenas = arenas
	local enemies = folder("Enemies", workspace)
	map.Enemies = enemies
	return map
end

return MapBuilder
