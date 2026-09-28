--!nonstrict
-- EnemyService (ModuleScript) -> ServerScriptService/Server/EnemyService
-- Anime avatar enemies:
--   * R15 rigs built from a HumanoidDescription (optional catalog hair /
--     accessories / Shirt / Pants ids from Config.EnemyCatalog) plus
--     procedural anime hair; falls back to a hand-built R6 rig if needed.
--   * Animator with preloaded Idle / Walk / Run / BasicAttack /
--     SpecialWindup / SpecialRelease tracks.
--   * PathfindingService chasing + AI state machine for special attacks:
--     cooldown/proximity check -> wind-up anim + ground telegraph ->
--     release; damage lands on the animation's "Hit" keyframe/marker
--     (AnimationTrack.KeyframeReached) with a timed fallback.
--   * Head health bar that only shows when damaged or when players are near.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))

local EnemyService = {}
EnemyService.Active = {} :: { any }
EnemyService.OnZenkai = nil :: ((Player) -> ())?
EnemyService.OnKill = nil :: ((Player, any) -> ())?

local map = nil
local templates = {}
local animCache = {}
local AI = Config.EnemyAI
local B = Config.Balance

---------------------------------------------------------------------
-- RIG BUILDING
---------------------------------------------------------------------
local function weldTo(head: BasePart, p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = p
	w.Parent = p
	p.Parent = head.Parent
end

local function hairPart(head: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = head.CFrame * offset
	weldTo(head, p)
	return p
end

-- Procedural anime hair + accessories (used when no catalog hair is set).
local function decorate(model: Model, look)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local hs = head.Size
	local u = math.min(hs.X, hs.Y, hs.Z) -- unit size of the head
	local c = look.HairColor
	-- hair cap
	hairPart(head, "HairCap", Vector3.new(hs.X * 1.1, hs.Y * 0.75, hs.Z * 1.12), CFrame.new(0, hs.Y * 0.28, u * 0.06), c, Enum.PartType.Ball)
	if look.Hair == "Spiky" then
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			local tilt = CFrame.Angles(math.rad(35) * math.cos(a), 0, math.rad(35) * math.sin(a))
			hairPart(head, "Spike", Vector3.new(u * 0.32, u * 0.95, u * 0.32), CFrame.new(math.sin(a) * u * 0.35, hs.Y * 0.55, math.cos(a) * u * 0.3 + u * 0.1) * tilt, c)
		end
		for i = -1, 1 do
			hairPart(head, "Bang", Vector3.new(u * 0.3, u * 0.55, u * 0.2), CFrame.new(i * u * 0.3, hs.Y * 0.28, -hs.Z * 0.45) * CFrame.Angles(math.rad(-20), 0, math.rad(i * 15)), c)
		end
	elseif look.Hair == "Long" then
		hairPart(head, "BackHair", Vector3.new(hs.X * 1.05, hs.Y * 1.7, u * 0.35), CFrame.new(0, -hs.Y * 0.25, hs.Z * 0.5), c)
		for _, side in ipairs({ -1, 1 }) do
			hairPart(head, "SideHair", Vector3.new(u * 0.22, hs.Y * 1.1, u * 0.5), CFrame.new(side * hs.X * 0.52, -hs.Y * 0.1, 0), c)
		end
		hairPart(head, "Fringe", Vector3.new(hs.X * 1.02, u * 0.3, u * 0.2), CFrame.new(0, hs.Y * 0.32, -hs.Z * 0.45) * CFrame.Angles(math.rad(-15), 0, 0), c)
	elseif look.Hair == "Bun" then
		hairPart(head, "Bun", Vector3.one * u * 0.6, CFrame.new(0, hs.Y * 0.55, hs.Z * 0.35), c, Enum.PartType.Ball)
		hairPart(head, "Fringe", Vector3.new(hs.X * 1.02, u * 0.3, u * 0.2), CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.45) * CFrame.Angles(math.rad(-15), 0, 0), c)
	end
	if look.Extra == "Headband" then
		hairPart(head, "Headband", Vector3.new(hs.X * 1.08, u * 0.18, hs.Z * 1.08), CFrame.new(0, hs.Y * 0.15, 0), Color3.fromRGB(40, 50, 90))
		hairPart(head, "Plate", Vector3.new(u * 0.5, u * 0.25, u * 0.06), CFrame.new(0, hs.Y * 0.15, -hs.Z * 0.56), Color3.fromRGB(200, 205, 215), nil, Enum.Material.Metal)
	elseif look.Extra == "Horns" then
		for _, side in ipairs({ -1, 1 }) do
			hairPart(head, "Horn", Vector3.new(u * 0.2, u * 0.7, u * 0.2), CFrame.new(side * hs.X * 0.35, hs.Y * 0.7, 0) * CFrame.Angles(0, 0, math.rad(-side * 20)), Color3.fromRGB(240, 230, 220))
		end
	elseif look.Extra == "Mask" then
		hairPart(head, "Mask", Vector3.new(hs.X * 1.02, hs.Y * 0.4, u * 0.1), CFrame.new(0, -hs.Y * 0.22, -hs.Z * 0.5), Color3.fromRGB(25, 25, 30))
	elseif look.Extra == "Crown" then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			hairPart(head, "Crown", Vector3.new(u * 0.15, u * 0.4, u * 0.15), CFrame.new(math.cos(a) * u * 0.4, hs.Y * 0.85, math.sin(a) * u * 0.4), Color3.fromRGB(255, 205, 60), nil, Enum.Material.Neon)
		end
	elseif look.Extra == "Visor" then
		hairPart(head, "Visor", Vector3.new(hs.X * 1.05, u * 0.22, u * 0.1), CFrame.new(0, hs.Y * 0.05, -hs.Z * 0.52), look.HairColor, nil, Enum.Material.Neon)
	end
end

-- Hand-built classic R6 rig (fallback if the R15 description fails).
local function buildR6(look): Model
	local m = Instance.new("Model")
	local function p(name, size, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = m
		return part
	end
	local root = p("HumanoidRootPart", Vector3.new(2, 2, 1), look.Shirt)
	root.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), look.Shirt)
	local head = p("Head", Vector3.new(2, 1, 1), look.Skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local la = p("Left Arm", Vector3.new(1, 2, 1), look.Skin)
	local ra = p("Right Arm", Vector3.new(1, 2, 1), look.Skin)
	local ll = p("Left Leg", Vector3.new(1, 2, 1), look.Pants)
	local rl = p("Right Leg", Vector3.new(1, 2, 1), look.Pants)
	local function motor(name, p0, p1, c0, c1)
		local mo = Instance.new("Motor6D")
		mo.Name = name
		mo.Part0 = p0
		mo.Part1 = p1
		mo.C0 = c0
		mo.C1 = c1
		mo.Parent = p0
	end
	local rj = CFrame.Angles(math.rad(-90), 0, math.rad(180))
	motor("RootJoint", root, torso, rj, rj)
	motor("Neck", torso, head, CFrame.new(0, 1, 0) * rj, CFrame.new(0, -0.5, 0) * rj)
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, math.rad(-90), 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = m
	m.PrimaryPart = root
	root.CFrame = CFrame.new(0, 3, 0)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.5, 0)
	ra.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	la.CFrame = root.CFrame * CFrame.new(-1.5, 0, 0)
	rl.CFrame = root.CFrame * CFrame.new(0.5, -2, 0)
	ll.CFrame = root.CFrame * CFrame.new(-0.5, -2, 0)
	return m
end

local function buildTemplate(index: number): Model
	local look = Config.EnemyLooks[index] or Config.EnemyLooks[1]
	local catalog = Config.EnemyCatalog[index]
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = look.Skin
	desc.TorsoColor = look.Shirt
	desc.LeftArmColor = look.Shirt
	desc.RightArmColor = look.Shirt
	desc.LeftLegColor = look.Pants
	desc.RightLegColor = look.Pants
	local catalogHair = false
	if catalog then
		if catalog.HairAccessory and catalog.HairAccessory ~= "" then
			desc.HairAccessory = catalog.HairAccessory
			catalogHair = true
		end
		if catalog.HatAccessory and catalog.HatAccessory ~= "" then
			desc.HatAccessory = catalog.HatAccessory
		end
		if catalog.Shirt and catalog.Shirt ~= 0 then
			desc.Shirt = catalog.Shirt
		end
		if catalog.Pants and catalog.Pants ~= 0 then
			desc.Pants = catalog.Pants
		end
		if catalog.Face and catalog.Face ~= 0 then
			desc.Face = catalog.Face
		end
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Enemies] R15 rig build failed, using R6 fallback:", model)
		model = buildR6(look)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") and (d.Name == "LeftHand" or d.Name == "RightHand") then
			d.Color = look.Skin
		end
	end
	if not catalogHair then
		decorate(model, look)
	end
	return model
end

---------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------
local function animation(id: string): Animation
	local a = animCache[id]
	if not a then
		a = Instance.new("Animation")
		a.AnimationId = id
		animCache[id] = a
	end
	return a
end

local function loadTracks(hum: Humanoid)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local set = hum.RigType == Enum.HumanoidRigType.R15 and Config.EnemyAnims.R15 or Config.EnemyAnims.R6
	local tracks = {}
	for key, id in pairs(set) do
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation(id))
		end)
		if ok and track then
			tracks[key] = track
			if key == "Idle" or key == "Walk" or key == "Run" then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Core
			else
				track.Priority = Enum.AnimationPriority.Action
			end
		end
	end
	return tracks
end

-- Waits for a "Hit" keyframe / marker on the track, or the fallback time.
local function waitForHit(track: AnimationTrack?, fallback: number)
	local done = Instance.new("BindableEvent")
	local fired = false
	local function fire()
		if not fired then
			fired = true
			done:Fire()
		end
	end
	local conns = {}
	if track then
		table.insert(conns, track.KeyframeReached:Connect(function(name)
			if name == "Hit" then
				fire()
			end
		end))
		table.insert(conns, track:GetMarkerReachedSignal("Hit"):Connect(fire))
	end
	task.delay(fallback, fire)
	if not fired then
		done.Event:Wait()
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	done:Destroy()
end

---------------------------------------------------------------------
-- HEALTH BAR
---------------------------------------------------------------------
local function healthBar(e)
	local head = e.Head
	local bb = Instance.new("BillboardGui")
	bb.Name = "HealthGui"
	bb.Size = UDim2.fromOffset(e.Boss and 260 or 150, e.Boss and 58 or 42)
	bb.StudsOffset = Vector3.new(0, head.Size.Y * 1.3 + 0.8, 0)
	bb.MaxDistance = e.Boss and 200 or 90
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Enabled = e.Boss == true
	bb.Parent = head
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.Text = e.Name
	name.TextColor3 = e.Elite and Color3.fromRGB(255, 215, 70) or (e.Boss and Color3.fromRGB(255, 90, 110) or Color3.new(1, 1, 1))
	name.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2
	ns.Parent = name
	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromScale(0, 0.55)
	barBg.Size = UDim2.fromScale(1, 0.4)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = barBg
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Color = Color3.fromRGB(10, 8, 12)
	bs.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = fill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 190, 80))
	grad.Parent = fill
	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.Text = Format.Abbrev(e.HP)
	hpText.ZIndex = 2
	hpText.Parent = barBg
	local hs = Instance.new("UIStroke")
	hs.Thickness = 1.5
	hs.Parent = hpText
	e.Bar, e.Fill, e.HPText = bb, fill, hpText
end

---------------------------------------------------------------------
-- SPAWNING
---------------------------------------------------------------------
local function randomPoint(minV: Vector3, maxV: Vector3): Vector3
	return Vector3.new(math.random() * (maxV.X - minV.X) + minV.X, 0, math.random() * (maxV.Z - minV.Z) + minV.Z)
end

local function tierKey(e): string
	return e.Boss and "Boss" or (e.Elite and "Elite" or "Normal")
end

function EnemyService.Create(opts)
	local lookIndex = opts.LookIndex or 1
	local template = templates[lookIndex]
	if not template then
		template = buildTemplate(lookIndex)
		templates[lookIndex] = template
	end
	local model = template:Clone()
	model.Name = opts.Label
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	if opts.Scale and opts.Scale ~= 1 then
		pcall(function()
			model:ScaleTo(opts.Scale)
		end)
	end
	hum.WalkSpeed = opts.Speed or 12
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, st in ipairs({ Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated }) do
		hum:SetStateEnabled(st, false)
	end
	local rootY = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + root.Size.Y / 2) or 3 * (opts.Scale or 1)
	model:PivotTo(CFrame.new(opts.Position.X, opts.Position.Y + rootY + 0.3, opts.Position.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	local color = opts.Color or Color3.new(1, 1, 1)
	if opts.Boss then
		local aura = Instance.new("Attachment")
		aura.Parent = root
		VFX.MakeEmitter("Aura", color, aura, 25).Size = VFX.NS(0, 2 * (opts.Scale or 1), 0.5, 3 * (opts.Scale or 1), 1, 0)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 30
		l.Brightness = 2
		l.Shadows = true
		l.Parent = root
	end
	if opts.Elite then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 200, 50)
		h.FillTransparency = 0.75
		h.OutlineColor = Color3.fromRGB(255, 230, 120)
		h.Parent = model
		local aura = Instance.new("Attachment")
		aura.Parent = root
		VFX.MakeEmitter("Aura", Color3.fromRGB(255, 200, 60), aura, 16)
	end

	model.Parent = map.Enemies
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local enemy = {
		Model = model,
		Root = root,
		Head = head,
		Humanoid = hum,
		HP = opts.HP,
		MaxHP = opts.HP,
		Name = opts.Label,
		Color = color,
		Boss = opts.Boss,
		Elite = opts.Elite,
		StageIndex = opts.StageIndex,
		Owner = opts.Owner,
		Min = opts.Min,
		Max = opts.Max,
		Home = opts.Position,
		Damagers = {},
		Dead = false,
		OnDeath = opts.OnDeath,
		Scale = opts.Scale or 1,
		Radius = 1.6 * (opts.Scale or 1),
		HitPercent = opts.HitPercent or Config.EnemyHitPercent,
		State = "Idle",
		LastBasic = 0,
		NextSpecial = os.clock() + 2 + math.random() * 3,
		NextWander = 0,
		StunnedUntil = 0,
		LastDamaged = -100,
		NextPath = 0,
	}
	healthBar(enemy)
	enemy.Tracks = loadTracks(hum)
	if enemy.Tracks.Idle then
		enemy.Tracks.Idle:Play()
	end
	hum.Running:Connect(function(speed)
		local run, idle = enemy.Tracks.Run, enemy.Tracks.Idle
		if speed > 1 then
			if run and not run.IsPlaying then
				run:Play(0.15)
				if idle then
					idle:Stop(0.15)
				end
			end
		else
			if idle and not idle.IsPlaying then
				idle:Play(0.2)
				if run then
					run:Stop(0.2)
				end
			end
		end
	end)
	table.insert(EnemyService.Active, enemy)
	return enemy
end

local function spawnForStage(stageIndex: number, announce: boolean?)
	local stage = Config.Stages[stageIndex]
	local info = map.Dungeons[stage.Zone] and map.Dungeons[stage.Zone].Stages[stageIndex]
	if not info then
		return
	end
	local elite = not stage.Boss and math.random() < Config.EliteChance
	local scale = stage.Boss and 2.6 or (elite and 1.3 or 1)
	local pos = stage.Boss and info.Center or randomPoint(info.SpawnMin, info.SpawnMax)
	local enemy = EnemyService.Create({
		Label = (elite and "ELITE " or "") .. stage.Enemy,
		LookIndex = stageIndex,
		Color = stage.Color,
		Scale = scale,
		HP = stage.HP * (elite and Config.EliteHPMult or 1),
		Boss = stage.Boss,
		Elite = elite,
		StageIndex = stageIndex,
		Position = pos,
		Min = info.SpawnMin,
		Max = info.SpawnMax,
		Speed = stage.Boss and 13 or (elite and 15 or 12),
	})
	if stage.Boss and announce then
		Net.FXAll("BossSpawn", { Name = stage.Enemy, Stage = stageIndex, Zone = stage.Zone, Pos = pos, Color = stage.Color })
	end
	return enemy
end

---------------------------------------------------------------------
-- QUERIES
---------------------------------------------------------------------
function EnemyService.CanDamage(player: Player, e): boolean
	if e.Dead or (e.Owner and e.Owner ~= player) then
		return false
	end
	if e.StageIndex then
		local data = DataService.Get(player)
		return data ~= nil and Stats.StageUnlocked(data, e.StageIndex)
	end
	return true
end

function EnemyService.InSphere(pos: Vector3, radius: number)
	local out = {}
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead and (e.Root.Position - pos).Magnitude - e.Radius <= radius then
			table.insert(out, e)
		end
	end
	return out
end

function EnemyService.InCone(pos: Vector3, dir: Vector3, range: number, arcDot: number)
	local out = {}
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead then
			local offset = e.Root.Position - pos
			local flatV = Vector3.new(offset.X, 0, offset.Z)
			local dist = flatV.Magnitude
			if dist - e.Radius <= range and math.abs(offset.Y) < 10 * e.Scale then
				if dist < 3 * e.Scale or flatV.Unit:Dot(dir) > arcDot then
					table.insert(out, e)
				end
			end
		end
	end
	return out
end

function EnemyService.InSegment(a: Vector3, b: Vector3, radius: number)
	local out = {}
	local ab = b - a
	local len2 = ab:Dot(ab)
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead then
			local p = e.Root.Position
			local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
			local closest = a + ab * t
			if (p - closest).Magnitude <= radius + e.Radius + 1 then
				table.insert(out, e)
			end
		end
	end
	return out
end

---------------------------------------------------------------------
-- STATUS EFFECTS (all stun-like effects are capped by Balance.MaxStun)
---------------------------------------------------------------------
function EnemyService.Stun(e, duration: number)
	if e.Dead then
		return
	end
	duration = math.min(duration, B.MaxStun) * (e.Boss and 0.3 or 1)
	e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + duration)
	e.Humanoid:MoveTo(e.Root.Position)
end

function EnemyService.Knockback(e, dir: Vector3, force: number)
	if e.Dead then
		return
	end
	local f = force * (e.Boss and 0.2 or 1)
	e.Root.AssemblyLinearVelocity = dir * f + Vector3.new(0, f * 0.3, 0)
	EnemyService.Stun(e, 0.3)
end

function EnemyService.Pull(e, point: Vector3, strength: number)
	if e.Dead or e.Boss then
		return
	end
	local off = Vector3.new(point.X - e.Root.Position.X, 0, point.Z - e.Root.Position.Z)
	if off.Magnitude > 3 then
		e.Root.AssemblyLinearVelocity = off.Unit * strength
		EnemyService.Stun(e, 0.25)
	end
end

function EnemyService.Ragdoll(e, duration: number, force: boolean?)
	if (e.Dead and not force) or e.Ragdolled then
		return
	end
	if e.Boss and not force then
		EnemyService.Stun(e, duration)
		return
	end
	duration = math.min(duration, B.MaxStun)
	e.Ragdolled = true
	e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + duration)
	local restore = {}
	for _, motor in ipairs(e.Model:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Name ~= "RootJoint" and motor.Part0 and motor.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 60
			bs.TwistLimitsEnabled = true
			bs.Parent = motor.Part0
			motor.Enabled = false
			table.insert(restore, { motor, a0, a1, bs, motor.Part1.CanCollide })
			motor.Part1.CanCollide = true
		end
	end
	e.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	task.delay(duration, function()
		for _, r in ipairs(restore) do
			local motor, a0, a1, bs, collide = r[1], r[2], r[3], r[4], r[5]
			if motor.Parent then
				motor.Enabled = true
				if motor.Part1 then
					motor.Part1.CanCollide = collide
				end
			end
			a0:Destroy()
			a1:Destroy()
			bs:Destroy()
		end
		e.Ragdolled = false
		if not e.Dead and e.Humanoid.Parent then
			e.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

---------------------------------------------------------------------
-- PLAYER DAMAGE (race passives: dodge, plot armor, zenkai; stun cap)
---------------------------------------------------------------------
function EnemyService.HitPlayer(player: Player, fraction: number, attackerPos: Vector3?, stun: number?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not hum or hum.Health <= 0 or not data or not s then
		return
	end
	local now = Stats.Now()
	if s.InvulnUntil > now then
		Net.FX(player, "Dodge", {})
		return
	end
	local race = Stats.Race(data)
	local dmg = hum.MaxHealth * fraction
	local newHealth = hum.Health - dmg
	if newHealth <= 0 and race.PlotArmor and math.random() < race.PlotArmor then
		newHealth = 1
		s.InvulnUntil = now + Config.PlotArmorIFrames
		Net.FX(player, "PlotArmor", {})
	end
	hum.Health = math.max(0, newHealth)
	if stun and stun > 0 then
		s.StunnedUntil = os.clock() + math.min(stun, B.PlayerStunCap)
	end
	Net.FX(player, "Hurt", { Amount = dmg, From = attackerPos, Stun = stun and math.min(stun, B.PlayerStunCap) or nil })
	if race.Zenkai and hum.Health > 0 and hum.Health / hum.MaxHealth < Config.ZenkaiThreshold and now >= s.ZenkaiReady then
		s.ZenkaiEnd = now + Config.ZenkaiDuration
		s.ZenkaiReady = now + Config.ZenkaiCooldown
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.3)
		Net.FXAll("Transform", { Player = player, Kind = "Zenkai", Color = Color3.fromRGB(255, 225, 60) })
		if EnemyService.OnZenkai then
			EnemyService.OnZenkai(player)
		end
		DataService.MarkDirty(player)
	end
end

---------------------------------------------------------------------
-- DAMAGE / DEATH / REWARDS
---------------------------------------------------------------------
local function weaponDrop(player: Player, chance: number)
	if math.random() >= chance then
		return
	end
	local weaponId, rarityId = Weapons.Roll(nil, Stats.Luck(player))
	if Weapons.Add(player, weaponId, rarityId) then
		Net.FX(player, "WeaponDrop", { Weapon = weaponId, Rarity = rarityId })
	end
end

local function reward(player: Player, enemy)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s then
		return
	end
	local stage = Config.Stages[enemy.StageIndex]
	if not stage then
		return
	end
	local mult = enemy.Elite and Config.EliteDropMult or 1
	local coins = math.floor(stage.Coins * mult * Stats.CoinMult(player))
	data.Coins += coins
	data.Kills += 1
	local luck = Stats.Luck(player) * (enemy.Elite and 2 or 1)
	local count
	if enemy.Boss then
		count = Config.BossOreDrops
	elseif enemy.Elite then
		count = 3
	else
		count = (math.random() < 0.25) and 2 or 1
	end
	local pos = enemy.Root.Position
	for i = 1, count do
		local minOrder = (enemy.Boss and i == 1) and 4 or nil
		local oreId = Loot.RollOre(stage.Drops, luck, minOrder)
		local off = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4) * (enemy.Boss and 2 or 1)
		Loot.Drop(player, oreId, Vector3.new(pos.X + off.X, enemy.Home.Y + 1.2, pos.Z + off.Z))
	end
	if enemy.Boss and math.random() < Config.BossRerollChance then
		data.Rerolls += 1
		Net.Notify(player, "The boss dropped a Race Reroll!", Color3.fromRGB(200, 150, 255), "RarePickup")
	end
	weaponDrop(player, enemy.Boss and Config.WeaponDropChance.Boss or (enemy.Elite and Config.WeaponDropChance.Elite or Config.WeaponDropChance.Normal))
	if Stats.Race(data).Id == "Ninja" then
		s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + Config.NinjaDodgeTime)
	end
	Net.FX(player, "Reward", { Coins = coins, Pos = pos })
	DataService.MarkDirty(player)
end
EnemyService.WeaponDrop = weaponDrop

function EnemyService.Kill(enemy, killer: Player?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemy.Humanoid.WalkSpeed = 0
	enemy.Bar.Enabled = false
	Net.FXAll("Kill", { Model = enemy.Model, Color = enemy.Color, Big = enemy.Boss, Elite = enemy.Elite, Pos = enemy.Root.Position, By = killer })
	if killer and EnemyService.OnKill then
		task.spawn(EnemyService.OnKill, killer, enemy)
	end
	if enemy.OnDeath then
		task.spawn(enemy.OnDeath, killer)
	else
		for player in pairs(enemy.Damagers) do
			if player.Parent then
				reward(player, enemy)
			end
		end
	end
	EnemyService.Ragdoll(enemy, 1, true)
	task.delay(0.9, function()
		local idx = table.find(EnemyService.Active, enemy)
		if idx then
			table.remove(EnemyService.Active, idx)
		end
		enemy.Model:Destroy()
	end)
	if enemy.StageIndex and not enemy.Owner then
		local stage = Config.Stages[enemy.StageIndex]
		task.delay(stage.Boss and Config.BossRespawn or Config.EnemyRespawn, spawnForStage, enemy.StageIndex, true)
	end
end

function EnemyService.Damage(enemy, player: Player, amount: number, crit: boolean?)
	if enemy.Dead or (enemy.Owner and enemy.Owner ~= player) then
		return
	end
	amount = math.max(1, math.floor(amount))
	enemy.HP -= amount
	enemy.Damagers[player] = true
	enemy.LastDamaged = os.clock()
	enemy.Bar.Enabled = true
	enemy.Fill.Size = UDim2.fromScale(math.clamp(enemy.HP / enemy.MaxHP, 0, 1), 1)
	enemy.HPText.Text = Format.Abbrev(math.max(0, enemy.HP))
	Net.FXAll("Hit", { Pos = enemy.Root.Position + Vector3.new(0, enemy.Scale, 0), Amount = amount, Crit = crit, Model = enemy.Model, Color = enemy.Color, By = player })
	if enemy.HP <= 0 then
		EnemyService.Kill(enemy, player)
	end
end

function EnemyService.DoT(e, player: Player, perTick: number, count: number, interval: number, color: Color3?)
	task.spawn(function()
		for _ = 1, count do
			task.wait(interval)
			if e.Dead then
				return
			end
			EnemyService.Damage(e, player, perTick, false)
			if color then
				Net.FXAll("Impact", { Pos = e.Root.Position, Color = color, Radius = 3, Kind = "Burn" })
			end
		end
	end)
end

---------------------------------------------------------------------
-- AI
---------------------------------------------------------------------
local function playerRoots()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			table.insert(list, { Player = p, Root = r })
		end
	end
	return list
end

local function inBounds(e, pos: Vector3, pad: number): boolean
	return pos.X >= e.Min.X - pad and pos.X <= e.Max.X + pad and pos.Z >= e.Min.Z - pad and pos.Z <= e.Max.Z + pad and math.abs(pos.Y - e.Home.Y) < 40
end

local function clampToBounds(e, pos: Vector3): Vector3
	return Vector3.new(math.clamp(pos.X, e.Min.X, e.Max.X), pos.Y, math.clamp(pos.Z, e.Min.Z, e.Max.Z))
end

local function face(e, pos: Vector3)
	local from = e.Root.Position
	local look = Vector3.new(pos.X, from.Y, pos.Z)
	if (look - from).Magnitude > 0.1 then
		e.Root.CFrame = CFrame.lookAt(from, look)
	end
end

local function moveToward(e, goal: Vector3)
	goal = clampToBounds(e, goal)
	local t = os.clock()
	local dist = (goal - e.Root.Position).Magnitude
	if dist < 16 then
		e.Waypoints = nil
		e.Humanoid:MoveTo(goal)
		return
	end
	if t >= e.NextPath and not e.Computing then
		e.NextPath = t + AI.PathRecompute
		e.Computing = true
		task.spawn(function()
			e.Path = e.Path or PathfindingService:CreatePath({ AgentRadius = 2 * e.Scale, AgentHeight = 5 * e.Scale, AgentCanJump = false })
			local ok = pcall(function()
				e.Path:ComputeAsync(e.Root.Position, goal)
			end)
			if ok and e.Path.Status == Enum.PathStatus.Success then
				e.Waypoints = e.Path:GetWaypoints()
				e.WpIndex = 2
			else
				e.Waypoints = nil
			end
			e.Computing = false
		end)
	end
	local wps = e.Waypoints
	if wps and e.WpIndex and e.WpIndex <= #wps then
		local wp = wps[e.WpIndex].Position
		local flatD = Vector3.new(wp.X - e.Root.Position.X, 0, wp.Z - e.Root.Position.Z).Magnitude
		if flatD < 3 then
			e.WpIndex += 1
		end
		e.Humanoid:MoveTo(wp)
	else
		e.Humanoid:MoveTo(goal)
	end
end

local function basicAttack(e, target)
	e.State = "Attack"
	e.LastBasic = os.clock()
	e.Humanoid:MoveTo(e.Root.Position)
	face(e, target.Root.Position)
	local track = e.Tracks.BasicAttack
	if track then
		track:Play(0.05)
	end
	Net.FXAll("EnemySwipe", { Pos = e.Root.Position, Target = target.Root.Position, Color = e.Color })
	task.spawn(function()
		waitForHit(track, Config.EnemyAnims.BasicHitTime)
		if not e.Dead and not e.Ragdolled and os.clock() >= e.StunnedUntil and target.Root.Parent then
			local reach = Config.EnemyAttackRange + e.Radius
			if (target.Root.Position - e.Root.Position).Magnitude <= reach * 1.2 then
				EnemyService.HitPlayer(target.Player, e.HitPercent, e.Root.Position)
			end
		end
		task.wait(0.25)
		if e.State == "Attack" then
			e.State = "Chase"
		end
	end)
end

-- Special attack state machine: wind-up (telegraph) -> release (hit sync).
local function specialAttack(e, target)
	local tier = tierKey(e)
	e.State = "Windup"
	e.NextSpecial = os.clock() + AI.SpecialCooldown[tier]
	e.Humanoid:MoveTo(e.Root.Position)
	face(e, target.Root.Position)
	local windup = AI.Windup[tier]
	local kind = e.Boss and "Slam" or "Lunge"
	local start = e.Root.Position
	local dir = Vector3.new(target.Root.Position.X - start.X, 0, target.Root.Position.Z - start.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or e.Root.CFrame.LookVector
	local ground = Vector3.new(start.X, e.Home.Y + 0.2, start.Z)
	local slamAt = Vector3.new(target.Root.Position.X, e.Home.Y + 0.2, target.Root.Position.Z)
	local lungeLen = 16 * math.max(1, e.Scale * 0.7)
	local radius = e.Boss and Config.BossSlamRadius or 5
	local wind = e.Tracks.SpecialWindup
	if wind then
		wind:Play(0.1)
		wind:AdjustSpeed(math.clamp(wind.Length / windup, 0.5, 2))
	end
	Net.FXAll("EnemyWindup", {
		Model = e.Model,
		Kind = kind,
		Pos = kind == "Slam" and slamAt or ground,
		Dir = dir,
		Length = lungeLen,
		Radius = radius,
		Time = windup,
		Color = e.Color,
	})
	task.spawn(function()
		task.wait(windup)
		if wind then
			wind:Stop(0.1)
		end
		if e.Dead or e.Ragdolled or os.clock() < e.StunnedUntil then
			e.State = "Chase"
			return
		end
		local release = e.Tracks.SpecialRelease
		if release then
			release:Play(0.05)
		end
		if kind == "Lunge" then
			e.Root.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 5, 0)
		end
		waitForHit(release, Config.EnemyAnims.SpecialHitTime)
		if e.Dead then
			return
		end
		local pct = AI.SpecialPercent[tier]
		if kind == "Slam" then
			Net.FXAll("Slam", { Pos = slamAt, Radius = radius, Color = e.Color })
			for _, pr in ipairs(playerRoots()) do
				local d = Vector3.new(pr.Root.Position.X - slamAt.X, 0, pr.Root.Position.Z - slamAt.Z).Magnitude
				if d <= radius and (not e.Owner or e.Owner == pr.Player) then
					EnemyService.HitPlayer(pr.Player, pct, slamAt, 0.6)
				end
			end
		else
			local finish = start + dir * lungeLen
			Net.FXAll("EnemyLunge", { From = start, To = finish, Color = e.Color })
			for _, pr in ipairs(playerRoots()) do
				local p = pr.Root.Position
				local ab = finish - start
				local tt = math.clamp((p - start):Dot(ab) / ab:Dot(ab), 0, 1)
				if (p - (start + ab * tt)).Magnitude <= 4.5 and (not e.Owner or e.Owner == pr.Player) then
					EnemyService.HitPlayer(pr.Player, pct, start, 0.3)
				end
			end
		end
		task.wait(0.5)
		e.State = "Chase"
	end)
end

local function stepAI()
	local roots = playerRoots()
	local t = os.clock()
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead and e.Root.Parent and not e.Ragdolled and t >= e.StunnedUntil and e.State ~= "Windup" and e.State ~= "Attack" then
			local epos = e.Root.Position
			local target, targetDist = nil, math.huge
			local nearest = math.huge
			for _, pr in ipairs(roots) do
				local d = (pr.Root.Position - epos).Magnitude
				nearest = math.min(nearest, d)
				if (not e.Owner or e.Owner == pr.Player) and d < Config.EnemyAggroRange * (e.Boss and 1.6 or 1) and d < targetDist and inBounds(e, pr.Root.Position, 6) then
					target, targetDist = pr, d
				end
			end
			-- health bar only while recently damaged or players are in aggro range
			local showBar = e.Boss or (t - e.LastDamaged < AI.HealthBarShowTime) or nearest < Config.EnemyAggroRange
			if e.Bar.Enabled ~= showBar then
				e.Bar.Enabled = showBar
			end
			if nearest < 220 then
				if target then
					e.State = "Chase"
					local tier = tierKey(e)
					local reach = Config.EnemyAttackRange + e.Radius
					if t >= e.NextSpecial and targetDist <= AI.SpecialRange[tier] then
						specialAttack(e, target)
					elseif targetDist <= reach and t - e.LastBasic >= Config.EnemyAttackCooldown then
						basicAttack(e, target)
					elseif targetDist > reach * 0.8 then
						moveToward(e, target.Root.Position)
					else
						e.Humanoid:MoveTo(epos)
						face(e, target.Root.Position)
					end
				else
					e.State = "Idle"
					if t >= e.NextWander then
						e.NextWander = t + 2 + math.random() * 3
						e.Humanoid:MoveTo(e.Boss and e.Home or (randomPoint(e.Min, e.Max) + Vector3.new(0, e.Home.Y, 0)))
					end
				end
			end
		end
	end
end

function EnemyService.Init(m)
	map = m
	-- build one rig template per look (yields while the rigs load)
	for i in pairs(Config.EnemyLooks) do
		templates[i] = buildTemplate(i)
	end
	for stageIndex, stage in ipairs(Config.Stages) do
		if map.Dungeons[stage.Zone] then
			for _ = 1, stage.Count do
				spawnForStage(stageIndex, false)
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(stepAI)
			if not ok then
				warn("[Enemy AI]", err)
			end
		end
	end)
end

return EnemyService
