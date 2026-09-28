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
		t.Font = Enum.Font.LuckiestGuy
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

-- Build a weapon. Returns { Main = Model, Off = Model?, Effect = BasePart }
function WeaponModels.Build(weaponId: string, rarityId: string?, forgeLevel: number?)
	local w = Config.WeaponById[weaponId] or Config.WeaponById[Config.StarterWeapon]
	local rarity = Config.WeaponRarityById[rarityId or w.Rarity] or Config.WeaponRarities[1]
	local glow = w.Glow or (rarity.Index >= 3 and rarity.Color) or nil
	local builder = builders[w.Class] or builders.Katana
	local main, effect, off = builder(w, glow)
	dress(main, effect, w, rarity, glow or rarity.Color)
	if off then
		local offEffect = off:FindFirstChild("Glove") or off:FindFirstChild("Barrel")
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
		local isGlove = model:FindFirstChild("Glove") ~= nil or model:FindFirstChild("Fingertip") ~= nil
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

return WeaponModels
