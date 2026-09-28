--!nonstrict
-- WeaponModels (ModuleScript) -> ReplicatedStorage/GameShared/WeaponModels
-- Builds every weapon from parts (no uploads needed). Rarity adds glow,
-- trails (Epic+), light + sparkles (Legendary+) and an aura (Mythic).
-- Models are built with the blade along +Y of the "Grip" part.

local Config = require(script.Parent:WaitForChild("Config"))
local VFX = require(script.Parent:WaitForChild("VFX"))

local WeaponModels = {}

local WHITE = Color3.new(1, 1, 1)

local function newModel(name: string): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.3, 0.3, 0.3)
	grip.Transparency = 1
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.CFrame = CFrame.new()
	grip.Parent = m
	m.PrimaryPart = grip
	return m, grip
end

local function part(m: Model, grip: BasePart, props, cf: CFrame): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Metal
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.CFrame = grip.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = grip
	w.Part1 = p
	w.Parent = p
	p.Parent = m
	return p
end

local function attach(parent: BasePart, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

local function etch(blade: BasePart, text: string, color: Color3)
	for _, face in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Etch"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 90
		sg.LightInfluence = 0
		sg.Parent = blade
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Config.Fonts.Display
		t.TextScaled = true
		t.Rotation = 0
		t.Text = text
		t.TextColor3 = color
		t.Parent = sg
	end
end

---------------------------------------------------------------------
-- CLASS BUILDERS  (return model, primary effect part, glow color)
---------------------------------------------------------------------
local builders = {}

builders.Katana = function(w, glow)
	local m, grip = newModel(w.Name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.24, 1.2, 0.24), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new(0, 0, 0))
	part(m, grip, { Name = "Pommel", Size = Vector3.new(0.28, 0.12, 0.28), Color = Color3.fromRGB(200, 170, 90) }, CFrame.new(0, -0.66, 0))
	part(m, grip, { Name = "Tsuba", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.62, 0.62), Color = Color3.fromRGB(40, 35, 30) }, CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local len = 4 + (w.Rarity == "Legendary" and 0.4 or 0)
	local blade = part(m, grip, { Name = "Blade", Size = Vector3.new(0.07, len, 0.26), Color = w.Blade, Reflectance = 0.2 }, CFrame.new(0, 0.7 + len / 2, 0))
	part(m, grip, { Name = "Tip", Size = Vector3.new(0.07, 0.19, 0.19), Color = w.Blade }, CFrame.new(0, 0.7 + len, 0.04) * CFrame.Angles(math.rad(45), 0, 0))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.08, len * 0.96, 0.05), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 0.7 + len / 2, 0.13))
	end
	attach(blade, "TrailA", Vector3.new(0, -len / 2 + 0.2, 0))
	attach(blade, "TrailB", Vector3.new(0, len / 2, 0))
	return m, blade
end

builders.Greatsword = function(w, glow)
	local m, grip = newModel(w.Name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.34, 1.7, 0.34), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new(0, 0, 0))
	part(m, grip, { Name = "Guard", Size = Vector3.new(0.45, 0.35, 1.5), Color = Color3.fromRGB(60, 55, 60) }, CFrame.new(0, 0.95, 0))
	local len = 5.6
	local blade = part(m, grip, { Name = "Blade", Size = Vector3.new(0.2, len, 1.35), Color = w.Blade, Reflectance = 0.1 }, CFrame.new(0, 1.1 + len / 2, 0.1))
	part(m, grip, { Name = "Tip", Size = Vector3.new(0.2, 0.95, 0.95), Color = w.Blade }, CFrame.new(0, 1.1 + len, 0.1) * CFrame.Angles(math.rad(45), 0, 0))
	part(m, grip, { Name = "Spine", Size = Vector3.new(0.22, len * 0.97, 0.12), Color = w.Accent }, CFrame.new(0, 1.1 + len / 2, -0.55))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.22, len * 0.97, 0.08), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 1.1 + len / 2, 0.78))
	end
	if w.Id == "Zangetsu" then
		-- cloth wrap + chain at the pommel
		for i = 1, 4 do
			part(m, grip, { Name = "Chain", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22, Color = Color3.fromRGB(200, 200, 210) }, CFrame.new(0, -0.9 - i * 0.22, 0.05 * i))
		end
		part(m, grip, { Name = "Wrap", Size = Vector3.new(0.36, 1.2, 0.36), Color = WHITE, Material = Enum.Material.Fabric }, CFrame.new(0, 0.1, 0))
	end
	attach(blade, "TrailA", Vector3.new(0, -len / 2 + 0.3, 0))
	attach(blade, "TrailB", Vector3.new(0, len / 2, 0))
	return m, blade
end

local function pistol(w, glow, name)
	local m, grip = newModel(name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.28, 0.75, 0.42), Color = w.Accent }, CFrame.new(0, 0, -0.1) * CFrame.Angles(math.rad(-15), 0, 0))
	local barrel = part(m, grip, { Name = "Barrel", Size = Vector3.new(0.32, 1.7, 0.42), Color = w.Blade }, CFrame.new(0, 0.9, 0.12))
	part(m, grip, { Name = "Muzzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 0.3, 0.3), Color = Color3.fromRGB(30, 30, 35) }, CFrame.new(0, 1.8, 0.12) * CFrame.Angles(0, 0, math.rad(90)))
	if glow then
		part(m, grip, { Name = "Glow", Size = Vector3.new(0.34, 1.2, 0.08), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 0.9, 0.35))
	end
	attach(barrel, "Muzzle", Vector3.new(0, 0.95, 0))
	attach(barrel, "TrailA", Vector3.new(0, -0.6, 0))
	attach(barrel, "TrailB", Vector3.new(0, 0.9, 0))
	return m, barrel
end

builders.Pistols = function(w, glow)
	local main, eff = pistol(w, glow, w.Name)
	local off = pistol(w, glow, w.Name .. " (Off-hand)")
	return main, eff, off
end

local function glove(w, glow, name)
	local m, grip = newModel(name)
	local body = part(m, grip, { Name = "Glove", Size = Vector3.new(0.75, 0.55, 0.75), Color = w.Blade, Material = Enum.Material.Fabric }, CFrame.new())
	part(m, grip, { Name = "Cuff", Size = Vector3.new(0.85, 0.25, 0.85), Color = w.Accent }, CFrame.new(0, 0.35, 0))
	if glow then
		part(m, grip, { Name = "Knuckles", Size = Vector3.new(0.8, 0.12, 0.3), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, -0.15, -0.36))
	end
	attach(body, "TrailA", Vector3.new(0, 0.2, 0))
	attach(body, "TrailB", Vector3.new(0, -0.3, 0))
	return m, body
end

builders.Glove = function(w, glow)
	local main, eff = glove(w, glow, w.Name)
	local off = glove(w, glow, w.Name .. " (Off-hand)")
	return main, eff, off
end

builders.FingerGun = function(w, glow)
	local m, grip = newModel(w.Name)
	local tip = part(m, grip, { Name = "Fingertip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Color = glow or w.Blade, Material = Enum.Material.Neon }, CFrame.new(0, -0.45, 0))
	part(m, grip, { Name = "Ring", Size = Vector3.new(0.5, 0.12, 0.5), Color = w.Accent, Material = Enum.Material.Neon, Transparency = 0.3 }, CFrame.new(0, 0.1, 0))
	attach(tip, "Muzzle", Vector3.zero)
	attach(tip, "TrailA", Vector3.new(0, 0.15, 0))
	attach(tip, "TrailB", Vector3.new(0, -0.15, 0))
	return m, tip
end

builders.Scythe = function(w, glow)
	local m, grip = newModel(w.Name)
	local pole = part(m, grip, { Name = "Pole", Size = Vector3.new(0.2, 7, 0.2), Color = w.Accent, Material = Enum.Material.Wood }, CFrame.new(0, 2.3, 0))
	part(m, grip, { Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, Color = glow or w.Blade, Material = glow and Enum.Material.Neon or Enum.Material.Metal }, CFrame.new(0, -1.25, 0))
	-- curved blade built from rotated segments
	local seg = 6
	local lastBlade = pole
	for i = 1, seg do
		local t = i / seg
		local ang = math.rad(10 + t * 55)
		local cf = CFrame.new(0, 5.6 + math.sin(ang) * 0.6, -0.1 - t * 2.9) * CFrame.Angles(-ang * 0.6, 0, 0)
		lastBlade = part(m, grip, { Name = "Blade", Size = Vector3.new(0.08, 0.55 - t * 0.35, 0.62), Color = w.Blade, Reflectance = 0.15 }, cf)
		if glow then
			part(m, grip, { Name = "Edge", Size = Vector3.new(0.09, 0.06, 0.62), Color = glow, Material = Enum.Material.Neon }, cf * CFrame.new(0, -(0.55 - t * 0.35) / 2, 0))
		end
	end
	attach(pole, "TrailA", Vector3.new(0, 2.8, 0))
	attach(lastBlade, "TrailB", Vector3.zero)
	return m, pole
end

---------------------------------------------------------------------
-- NEW CLASSES
---------------------------------------------------------------------
builders.Spear = function(w, glow)
	local m, grip = newModel(w.Name)
	local pole = part(m, grip, { Name = "Pole", Size = Vector3.new(0.18, 7.2, 0.18), Color = w.Accent, Material = Enum.Material.Wood }, CFrame.new(0, 2.2, 0))
	part(m, grip, { Name = "Butt", Size = Vector3.new(0.24, 0.3, 0.24), Color = w.Blade }, CFrame.new(0, -1.45, 0))
	part(m, grip, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.32, 0.32), Color = Color3.fromRGB(200, 170, 90) }, CFrame.new(0, 5.85, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local head = part(m, grip, { Name = "Blade", Size = Vector3.new(0.08, 1.5, 0.42), Color = w.Blade, Reflectance = 0.2 }, CFrame.new(0, 6.7, 0))
	part(m, grip, { Name = "Tip", Size = Vector3.new(0.08, 0.3, 0.3), Color = w.Blade }, CFrame.new(0, 7.45, 0) * CFrame.Angles(math.rad(45), 0, 0))
	part(m, grip, { Name = "Tassel", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.32, Color = glow or Color3.fromRGB(200, 40, 40), Material = Enum.Material.Fabric }, CFrame.new(0, 5.55, 0.12))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.09, 1.4, 0.06), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 6.7, 0.21))
	end
	attach(pole, "TrailA", Vector3.new(0, 2.6, 0))
	attach(head, "TrailB", Vector3.new(0, 0.7, 0))
	return m, head
end

local function dagger(w, glow, name)
	local m, grip = newModel(name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.2, 0.62, 0.2), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new())
	part(m, grip, { Name = "Guard", Size = Vector3.new(0.14, 0.12, 0.62), Color = Color3.fromRGB(60, 55, 60) }, CFrame.new(0, 0.36, 0))
	local blade = part(m, grip, { Name = "Blade", Size = Vector3.new(0.06, 1.35, 0.22), Color = w.Blade, Reflectance = 0.2 }, CFrame.new(0, 1.1, 0))
	part(m, grip, { Name = "Tip", Size = Vector3.new(0.06, 0.16, 0.16), Color = w.Blade }, CFrame.new(0, 1.78, 0.03) * CFrame.Angles(math.rad(45), 0, 0))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.07, 1.25, 0.04), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 1.1, 0.11))
	end
	attach(blade, "TrailA", Vector3.new(0, -0.55, 0))
	attach(blade, "TrailB", Vector3.new(0, 0.65, 0))
	return m, blade
end

builders.Daggers = function(w, glow)
	local main, eff = dagger(w, glow, w.Name)
	local off, offEff = dagger(w, glow, w.Name .. " (Off-hand)")
	return main, eff, off, offEff
end

builders.Hammer = function(w, glow)
	local m, grip = newModel(w.Name)
	local handle = part(m, grip, { Name = "Handle", Size = Vector3.new(0.26, 3.6, 0.26), Color = w.Accent, Material = Enum.Material.Wood }, CFrame.new(0, 1.1, 0))
	local head = part(m, grip, { Name = "Head", Size = Vector3.new(1.25, 1.25, 2.2), Color = w.Blade }, CFrame.new(0, 3.2, 0))
	for _, z in ipairs({ -1.12, 1.12 }) do
		part(m, grip, { Name = "Face", Size = Vector3.new(1.35, 1.35, 0.18), Color = w.Blade:Lerp(Color3.new(0, 0, 0), 0.25) }, CFrame.new(0, 3.2, z))
	end
	part(m, grip, { Name = "Band", Size = Vector3.new(1.3, 0.22, 2.25), Color = glow or w.Accent, Material = glow and Enum.Material.Neon or Enum.Material.Metal }, CFrame.new(0, 3.2, 0))
	attach(handle, "TrailA", Vector3.new(0, 1.2, 0))
	attach(head, "TrailB", Vector3.new(0, 0.6, 0))
	return m, head
end

builders.Bow = function(w, glow)
	local m, grip = newModel(w.Name)
	local handle = part(m, grip, { Name = "Handle", Size = Vector3.new(0.22, 0.7, 0.26), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new())
	local limbs = {}
	for _, dir in ipairs({ 1, -1 }) do
		local prev = Vector3.new(0, dir * 0.3, 0)
		for i = 1, 5 do
			local t = i / 5
			local nextP = Vector3.new(0, dir * (0.3 + t * 2.3), 0.9 * t * t)
			local mid = (prev + nextP) / 2
			local len = (nextP - prev).Magnitude
			local cf = CFrame.lookAt(mid, nextP) * CFrame.Angles(math.rad(90), 0, 0)
			limbs[#limbs + 1] = part(m, grip, { Name = "Limb", Size = Vector3.new(0.14, len + 0.05, 0.2 - t * 0.06), Color = w.Blade, Material = Enum.Material.Wood }, cf)
			prev = nextP
		end
	end
	local str = part(m, grip, { Name = "String", Size = Vector3.new(0.03, 5.2, 0.03), Color = glow or Color3.fromRGB(240, 240, 240), Material = glow and Enum.Material.Neon or Enum.Material.Fabric }, CFrame.new(0, 0, 0.9))
	attach(handle, "Muzzle", Vector3.new(0, 0, -0.6))
	attach(str, "TrailA", Vector3.new(0, 2.4, 0))
	attach(str, "TrailB", Vector3.new(0, -2.4, 0))
	return m, handle
end

builders.Staff = function(w, glow)
	local m, grip = newModel(w.Name)
	local pole = part(m, grip, { Name = "Pole", Size = Vector3.new(0.2, 6.2, 0.2), Color = w.Blade, Material = Enum.Material.Wood }, CFrame.new(0, 1.8, 0))
	part(m, grip, { Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.18, 0.9, 0.9), Color = w.Accent, Material = Enum.Material.Metal }, CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local orb = part(m, grip, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.75, Color = glow or w.Accent, Material = Enum.Material.Neon }, CFrame.new(0, 5.5, 0))
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		part(m, grip, { Name = "Prong", Size = Vector3.new(0.08, 0.6, 0.08), Color = w.Accent }, CFrame.new(math.cos(a) * 0.35, 5.45, math.sin(a) * 0.35) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4))
	end
	attach(orb, "Muzzle", Vector3.zero)
	attach(pole, "TrailA", Vector3.new(0, 2.8, 0))
	attach(orb, "TrailB", Vector3.new(0, 0.3, 0))
	return m, orb
end

builders.Chain = function(w, glow)
	local m, grip = newModel(w.Name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.24, 0.8, 0.24), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new())
	local last
	for i = 1, 9 do
		last = part(m, grip, { Name = "Link", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.34, 0.34), Color = w.Blade, Reflectance = 0.15 }, CFrame.new(0, 0.45 + i * 0.36, math.sin(i * 0.5) * 0.18) * CFrame.Angles(0, i % 2 == 0 and math.rad(90) or 0, math.rad(90)))
	end
	local tip = part(m, grip, { Name = "Blade", Size = Vector3.new(0.08, 0.7, 0.4), Color = w.Blade, Reflectance = 0.2 }, CFrame.new(0, 4.1, 0.1))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.09, 0.6, 0.06), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 4.1, 0.3))
	end
	attach(last, "TrailA", Vector3.zero)
	attach(tip, "TrailB", Vector3.new(0, 0.3, 0))
	return m, tip
end

local function claw(w, glow, name)
	local m, grip = newModel(name)
	local body = part(m, grip, { Name = "Glove", Size = Vector3.new(0.72, 0.5, 0.72), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new())
	for i = -1, 1 do
		part(m, grip, { Name = "Claw", Size = Vector3.new(0.06, 0.9, 0.12), Color = w.Blade, Reflectance = 0.2 }, CFrame.new(i * 0.2, -0.55, -0.2) * CFrame.Angles(math.rad(-25), 0, 0))
		if glow then
			part(m, grip, { Name = "ClawGlow", Size = Vector3.new(0.07, 0.8, 0.03), Color = glow, Material = Enum.Material.Neon }, CFrame.new(i * 0.2, -0.55, -0.26) * CFrame.Angles(math.rad(-25), 0, 0))
		end
	end
	m:SetAttribute("HandMount", true)
	attach(body, "TrailA", Vector3.new(0, 0.1, 0))
	attach(body, "TrailB", Vector3.new(0, -0.9, -0.3))
	return m, body
end

builders.Claws = function(w, glow)
	local main, eff = claw(w, glow, w.Name)
	local off, offEff = claw(w, glow, w.Name .. " (Off-hand)")
	return main, eff, off, offEff
end

builders.Fan = function(w, glow)
	local m, grip = newModel(w.Name)
	local handle = part(m, grip, { Name = "Handle", Size = Vector3.new(0.18, 0.9, 0.18), Color = w.Accent }, CFrame.new())
	local lastRib
	for i = 0, 8 do
		local a = math.rad(-60 + i * 15)
		local cf = CFrame.new(0, 0.4, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.2, 0)
		part(m, grip, { Name = "Rib", Size = Vector3.new(0.05, 2.4, 0.06), Color = w.Accent }, cf)
		lastRib = part(m, grip, { Name = "Leaf", Size = Vector3.new(0.03, 2.2, 0.36), Color = i % 2 == 0 and w.Blade or w.Blade:Lerp(Color3.new(1, 1, 1), 0.2), Material = Enum.Material.Fabric }, cf * CFrame.new(0, 0.1, 0.0))
	end
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.04, 0.12, 2.7), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 2.95, 0))
	end
	attach(handle, "TrailA", Vector3.new(0, 0.4, 0))
	attach(lastRib, "TrailB", Vector3.new(0, 1.1, 0))
	return m, handle
end

builders.Kunai = function(w, glow)
	local m, grip = newModel(w.Name)
	part(m, grip, { Name = "Handle", Size = Vector3.new(0.14, 0.55, 0.14), Color = w.Accent, Material = Enum.Material.Fabric }, CFrame.new())
	part(m, grip, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.34, 0.34), Color = w.Blade }, CFrame.new(0, -0.42, 0) * CFrame.Angles(0, math.rad(90), 0))
	local blade = part(m, grip, { Name = "Blade", Size = Vector3.new(0.05, 0.85, 0.3), Color = w.Blade, Reflectance = 0.25 }, CFrame.new(0, 0.7, 0))
	part(m, grip, { Name = "Tip", Size = Vector3.new(0.05, 0.22, 0.22), Color = w.Blade }, CFrame.new(0, 1.12, 0) * CFrame.Angles(math.rad(45), 0, 0))
	if glow then
		part(m, grip, { Name = "Edge", Size = Vector3.new(0.06, 0.75, 0.05), Color = glow, Material = Enum.Material.Neon }, CFrame.new(0, 0.7, 0.14))
	end
	attach(blade, "Muzzle", Vector3.new(0, 0.5, 0))
	attach(blade, "TrailA", Vector3.new(0, -0.4, 0))
	attach(blade, "TrailB", Vector3.new(0, 0.45, 0))
	return m, blade
end

builders.Cannon = function(w, glow)
	local m, grip = newModel(w.Name)
	local body = part(m, grip, { Name = "Glove", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.95, 0.95), Color = w.Blade }, CFrame.new(0, -0.45, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, grip, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.15, 1.15), Color = w.Accent }, CFrame.new(0, -1.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, grip, { Name = "Bore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.27, 0.6, 0.6), Color = glow or Color3.fromRGB(30, 30, 35), Material = glow and Enum.Material.Neon or Enum.Material.Metal }, CFrame.new(0, -1.34, 0) * CFrame.Angles(0, 0, math.rad(90)))
	part(m, grip, { Name = "Fin", Size = Vector3.new(0.12, 1.1, 0.5), Color = w.Accent }, CFrame.new(0, -0.3, 0.55))
	m:SetAttribute("HandMount", true)
	attach(body, "Muzzle", Vector3.new(-1.0, 0, 0))
	attach(body, "TrailA", Vector3.new(0.6, 0, 0))
	attach(body, "TrailB", Vector3.new(-0.9, 0, 0))
	return m, body
end

---------------------------------------------------------------------
-- rarity dressing
---------------------------------------------------------------------
local function dress(m: Model, effectPart: BasePart, w, rarity, glow: Color3)
	if not m then
		return
	end
	local a0 = m:FindFirstChild("TrailA", true)
	local a1 = m:FindFirstChild("TrailB", true)
	if rarity.Trail and a0 and a1 then
		local tr = Instance.new("Trail")
		tr.Name = "RarityTrail"
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.25
		tr.MinLength = 0.05
		tr.LightEmission = 1
		tr.LightInfluence = 0
		tr.FaceCamera = true
		tr.Transparency = VFX.NS(0, 0.15, 1, 1)
		tr.WidthScale = VFX.NS(0, 1, 1, 0.1)
		if rarity.Rainbow then
			tr.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
			})
		else
			tr.Color = ColorSequence.new(WHITE, glow)
		end
		tr.Parent = effectPart
	end
	if rarity.Index >= 5 then
		local l = Instance.new("PointLight")
		l.Color = glow
		l.Range = 9
		l.Brightness = 1.6
		l.Shadows = false
		l.Parent = effectPart
		VFX.MakeEmitter("Stars", glow, effectPart, 4)
	end
	if rarity.Aura then
		local e = VFX.MakeEmitter("Aura", glow, effectPart, 14)
		e.Size = VFX.NS(0, 0.5, 0.5, 0.9, 1, 0)
		e.Speed = NumberRange.new(1, 3)
	end
end

-- Ore effects forged into the weapon show as element particles on it.
function WeaponModels.ApplyEffects(built, effects)
	if not effects or not built or not built.Effect then
		return
	end
	-- strongest effect gets the particle, second strongest tints a light
	local best, second = nil, nil
	for id, pts in pairs(effects) do
		if Config.Effects[id] then
			if not best or pts > effects[best] then
				second = best
				best = id
			elseif not second or pts > effects[second] then
				second = id
			end
		end
	end
	if best then
		local e = Config.Effects[best]
		local em = VFX.MakeEmitter(e.VFX or "Sparks", e.Color, built.Effect, 3 + math.min(10, effects[best] / 3))
		em.Name = "OreEffect"
		em.LockedToPart = true
	end
	if second then
		local l = Instance.new("PointLight")
		l.Name = "OreEffectLight"
		l.Color = Config.Effects[second].Color
		l.Range = 6
		l.Brightness = 1
		l.Parent = built.Effect
	end
end

-- Build a weapon. Returns { Main = Model, Off = Model?, Effect = BasePart }
function WeaponModels.Build(weaponId: string, rarityId: string?, forgeLevel: number?)
	local w = Config.WeaponById[weaponId] or Config.WeaponById[Config.StarterWeapon]
	local rarity = Config.WeaponRarityById[rarityId or w.Rarity] or Config.WeaponRarities[1]
	local glow = w.Glow or (rarity.Index >= 3 and rarity.Color) or nil
	local builder = builders[w.Class] or builders.Katana
	local main, effect, off, offEffect = builder(w, glow)
	dress(main, effect, w, rarity, glow or rarity.Color)
	if off then
		offEffect = offEffect or off:FindFirstChild("Glove") or off:FindFirstChild("Barrel")
		if offEffect then
			dress(off, offEffect, w, rarity, glow or rarity.Color)
		end
	end
	if forgeLevel and forgeLevel > 0 then
		local blade = main:FindFirstChild("Blade")
		if blade and (w.Class == "Katana" or w.Class == "Greatsword") then
			etch(blade, "+" .. forgeLevel, glow or Color3.fromRGB(255, 220, 140))
		end
	end
	main:SetAttribute("WeaponId", w.Id)
	return { Main = main, Off = off, Effect = effect, Glow = glow or rarity.Color }
end

-- Weld a built weapon to a character's hands (R15 or R6).
function WeaponModels.AttachToCharacter(character: Model, built)
	local function hand(side: string): BasePart?
		return (character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")) :: any
	end
	local function weldTo(model: Model?, side: string)
		if not model then
			return
		end
		local h = hand(side)
		if not h then
			model:Destroy()
			return
		end
		local grip = model.PrimaryPart :: BasePart
		local gripAtt = h:FindFirstChild(side .. "GripAttachment") :: Attachment?
		local isGlove = model:GetAttribute("HandMount") == true or model:FindFirstChild("Glove") ~= nil or model:FindFirstChild("Fingertip") ~= nil
		local c0
		if isGlove then
			c0 = CFrame.new(0, h.Name:find("Arm") and -0.8 or 0, 0)
		elseif gripAtt then
			c0 = gripAtt.CFrame
		else
			c0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(-90), 0, 0)
		end
		model:PivotTo(h.CFrame * c0)
		local weld = Instance.new("Weld")
		weld.Name = "WeaponWeld"
		weld.Part0 = h
		weld.Part1 = grip
		weld.C0 = c0
		weld.C1 = CFrame.new()
		weld.Parent = grip
		model.Name = "EquippedWeapon_" .. side
		model.Parent = character
	end
	weldTo(built.Main, "Right")
	weldTo(built.Off, "Left")
end

---------------------------------------------------------------------
-- ARMOR (welded onto the character's body parts, R15 or R6)
---------------------------------------------------------------------
local function bodyPart(char: Model, r15: string, r6: string): BasePart?
	return (char:FindFirstChild(r15) or char:FindFirstChild(r6)) :: any
end

local function armorPiece(folder: Instance, body: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
	p.Parent = folder
	return p
end

function WeaponModels.RemoveArmor(char: Model)
	local old = char:FindFirstChild("EquippedArmor")
	if old then
		old:Destroy()
	end
end

-- Builds the armour set on a character. rarityId controls trim glow.
function WeaponModels.AttachArmor(char: Model, armorId: string, rarityId: string)
	WeaponModels.RemoveArmor(char)
	local a = Config.ArmorById[armorId]
	local r = Config.WeaponRarityById[rarityId] or Config.WeaponRarities[1]
	local torso = bodyPart(char, "UpperTorso", "Torso")
	local lower = bodyPart(char, "LowerTorso", "Torso")
	local lArm = bodyPart(char, "LeftUpperArm", "Left Arm")
	local rArm = bodyPart(char, "RightUpperArm", "Right Arm")
	local head = char:FindFirstChild("Head") :: BasePart?
	if not a or not torso or not lArm or not rArm then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "EquippedArmor"
	folder.Parent = char
	local ts = torso.Size
	local base, trim = a.Color, a.Trim
	local glowing = r.Index >= 4
	local trimMat = glowing and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local u = ts.X / 2

	-- chest + back plates (every set)
	local chest = armorPiece(folder, torso, "ChestPlate", Vector3.new(ts.X * 0.95, ts.Y * 0.75, 0.16), CFrame.new(0, ts.Y * 0.08, -ts.Z / 2 - 0.05), base, Enum.Material.SmoothPlastic)
	chest.Reflectance = 0.08
	armorPiece(folder, torso, "BackPlate", Vector3.new(ts.X * 0.9, ts.Y * 0.7, 0.14), CFrame.new(0, ts.Y * 0.08, ts.Z / 2 + 0.05), base)
	armorPiece(folder, torso, "ChestTrim", Vector3.new(ts.X * 0.96, 0.08, 0.18), CFrame.new(0, ts.Y * 0.44, -ts.Z / 2 - 0.05), trim, trimMat)
	if lower then
		armorPiece(folder, lower, "Belt", Vector3.new(lower.Size.X * 1.06, 0.25, lower.Size.Z * 1.08), CFrame.new(0, lower.Size.Y * 0.2, 0), trim, trimMat)
	end

	local style = a.Style
	for _, pair in ipairs({ { lArm, -1 }, { rArm, 1 } }) do
		local arm, side = pair[1], pair[2]
		local top = CFrame.new(side * 0.05, arm.Size.Y * 0.38, 0)
		if style == "Samurai" then
			armorPiece(folder, arm, "Sode", Vector3.new(0.16, u * 1.1, u * 1.2), top * CFrame.new(side * 0.35, -0.2, 0) * CFrame.Angles(0, 0, math.rad(side * 18)), base)
			armorPiece(folder, arm, "SodeTrim", Vector3.new(0.18, 0.08, u * 1.22), top * CFrame.new(side * 0.35, -0.72, 0) * CFrame.Angles(0, 0, math.rad(side * 18)), trim, trimMat)
		elseif style == "Mech" then
			local box = armorPiece(folder, arm, "ShoulderBox", Vector3.new(u * 1.1, u * 0.6, u * 1.15), top * CFrame.new(side * 0.1, 0.1, 0), base, Enum.Material.Metal)
			armorPiece(folder, arm, "ShoulderGlow", Vector3.new(u * 1.12, 0.06, u * 1.17), top * CFrame.new(side * 0.1, -0.1, 0), trim, Enum.Material.Neon)
			local _ = box
		elseif style == "Oni" then
			armorPiece(folder, arm, "Spike", Vector3.new(0.18, u * 0.9, 0.18), top * CFrame.new(side * 0.2, 0.45, 0) * CFrame.Angles(0, 0, math.rad(-side * 25)), trim)
			armorPiece(folder, arm, "Pad", Vector3.new(u, u * 0.5, u), top, base, nil, Enum.PartType.Ball)
		elseif style == "Saiyan" then
			armorPiece(folder, arm, "Flap", Vector3.new(u * 1.05, 0.14, u * 1.1), top * CFrame.new(side * 0.25, 0.1, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), base)
			armorPiece(folder, arm, "FlapTrim", Vector3.new(u * 1.06, 0.06, u * 1.12), top * CFrame.new(side * 0.25, 0.02, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), trim, trimMat)
		elseif style == "Aegis" then
			armorPiece(folder, arm, "Pauldron", Vector3.new(u * 1.25, u * 0.7, u * 1.2), top * CFrame.new(side * 0.12, 0.05, 0), base, Enum.Material.SmoothPlastic, Enum.PartType.Ball).Reflectance = 0.2
			armorPiece(folder, arm, "Gem", Vector3.one * 0.26, top * CFrame.new(side * 0.4, 0.15, -0.25), trim, Enum.Material.Neon, Enum.PartType.Ball)
		elseif style == "Robe" then
			armorPiece(folder, arm, "Sleeve", Vector3.new(arm.Size.X * 1.3, arm.Size.Y * 0.9, arm.Size.Z * 1.3), CFrame.new(0, -0.05, 0), base, Enum.Material.Fabric)
		elseif style == "Vest" then
			armorPiece(folder, arm, "Strap", Vector3.new(arm.Size.X * 1.08, 0.2, arm.Size.Z * 1.08), CFrame.new(0, arm.Size.Y * 0.1, 0), trim)
		else -- Gi
			armorPiece(folder, arm, "Wrap", Vector3.new(arm.Size.X * 1.05, arm.Size.Y * 0.35, arm.Size.Z * 1.05), CFrame.new(0, -arm.Size.Y * 0.3, 0), trim, Enum.Material.Fabric)
		end
	end

	-- signature piece per style
	if style == "Robe" or style == "Gi" then
		armorPiece(folder, torso, "CoatTail", Vector3.new(ts.X * 1.05, ts.Y * 1.9, 0.08), CFrame.new(0, -ts.Y * 0.9, ts.Z / 2 + 0.12) * CFrame.Angles(math.rad(6), 0, 0), base, Enum.Material.Fabric)
	elseif style == "Vest" then
		for i = -1, 1 do
			armorPiece(folder, torso, "Pouch", Vector3.new(0.3, 0.36, 0.14), CFrame.new(i * 0.4, -ts.Y * 0.2, -ts.Z / 2 - 0.14), trim)
		end
	elseif style == "Samurai" and head then
		armorPiece(folder, head, "Kuwagata", Vector3.new(0.08, 0.9, 0.3), CFrame.new(-0.25, head.Size.Y * 0.62, -head.Size.Z * 0.4) * CFrame.Angles(0, 0, math.rad(25)), trim, trimMat)
		armorPiece(folder, head, "Kuwagata", Vector3.new(0.08, 0.9, 0.3), CFrame.new(0.25, head.Size.Y * 0.62, -head.Size.Z * 0.4) * CFrame.Angles(0, 0, math.rad(-25)), trim, trimMat)
	elseif style == "Aegis" and head then
		local halo = armorPiece(folder, head, "Halo", Vector3.new(0.08, head.Size.X * 1.4, head.Size.X * 1.4), CFrame.new(0, head.Size.Y * 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), trim, Enum.Material.Neon, Enum.PartType.Cylinder)
		halo.Transparency = 0.35
	elseif style == "Mech" then
		armorPiece(folder, torso, "Reactor", Vector3.one * 0.4, CFrame.new(0, ts.Y * 0.1, -ts.Z / 2 - 0.16), trim, Enum.Material.Neon, Enum.PartType.Ball)
	elseif style == "Oni" then
		armorPiece(folder, torso, "Fur", Vector3.new(ts.X * 1.2, 0.35, ts.Z * 1.3), CFrame.new(0, ts.Y * 0.5, 0), trim, Enum.Material.Fabric)
	end

	-- rarity dressing
	if r.Index >= 5 then
		VFX.MakeEmitter("Holy", r.Color, chest, 3)
	end
	if r.Index >= 4 then
		local l = Instance.new("PointLight")
		l.Color = trim
		l.Range = 7
		l.Brightness = 0.8
		l.Parent = chest
	end
	return folder
end

return WeaponModels
