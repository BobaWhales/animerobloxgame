--!nonstrict
-- Sword (ModuleScript) -> ServerScriptService/Server/Sword
-- Builds the player's Blade tool. The blade model changes at every visual
-- tier (Plain Steel -> Engraved -> Glowing -> ... -> Final Release) and the
-- "+N" level counter is etched on both faces of the blade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local Sword = {}

local PARTICLE_PRESET = {
	Fire = "Fire",
	Spark = "Stars",
	Petal = "Petals",
	Star = "Stars",
	Vortex = "Vortex",
}

local function part(parent: Instance, props): BasePart
	local p = Instance.new(props.ClassName or "Part")
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p :: any
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function levelLabel(bladePart: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LevelEtch"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 0
	sg.Parent = bladePart
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = sg
end

local function build(level: number): Tool
	local tier, tierIndex = Config.GetBladeTier(level)
	local len = tier.Length
	local edgeColor = tier.Edge or Color3.fromRGB(235, 240, 250)

	local tool = Instance.new("Tool")
	tool.Name = "Blade +" .. level
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = tier.Name .. " Blade"
	tool:SetAttribute("IsBlade", true)
	tool:SetAttribute("Tier", tierIndex)
	tool:SetAttribute("Level", level)
	-- classic sword grip: blade points out along the handle's +Z
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool.GripPos = Vector3.new(0, 0, 0)

	local handle = part(tool, {
		Name = "Handle",
		Size = Vector3.new(0.34, 0.34, 1.4),
		Color = tierIndex >= 9 and Color3.fromRGB(20, 15, 20) or Color3.fromRGB(70, 30, 40),
		Material = Enum.Material.Fabric,
	})
	local hcf = handle.CFrame

	local function attach(props, offset: CFrame)
		local p = part(tool, props)
		p.CFrame = hcf * offset
		weld(handle, p)
		return p
	end

	-- pommel + guard
	attach({ Name = "Pommel", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = tier.Edge or Color3.fromRGB(180, 150, 90), Material = tier.Edge and Enum.Material.Neon or Enum.Material.Metal }, CFrame.new(0, 0, -0.8))
	local guardColor = tierIndex >= 2 and Color3.fromRGB(255, 205, 90) or Color3.fromRGB(120, 120, 130)
	attach({ Name = "Guard", Size = Vector3.new(0.4, 1.3 + tierIndex * 0.12, 0.3), Color = guardColor, Material = Enum.Material.Metal }, CFrame.new(0, 0, 0.82))
	if tierIndex >= 4 then
		attach({ Name = "GuardGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.36, Color = edgeColor, Material = Enum.Material.Neon }, CFrame.new(0.14, 0, 0.82))
	end

	-- blade body
	local bladeZ = 0.97 + len / 2
	local blade = attach({ Name = "Blade", Size = Vector3.new(0.12, 0.5 + tierIndex * 0.03, len), Color = tier.Blade, Material = tierIndex >= 9 and Enum.Material.Glass or Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 0, bladeZ))
	local w = blade.Size.Y
	-- tip (diamond)
	attach({ Name = "Tip", Size = Vector3.new(0.12, w * 0.707, w * 0.707), Color = tier.Blade, Material = blade.Material }, CFrame.new(0, 0, 0.97 + len) * CFrame.Angles(math.rad(45), 0, 0))
	-- glowing edge(s)
	if tier.Edge then
		attach({ Name = "Edge", Size = Vector3.new(0.14, 0.08, len * 0.97), Color = edgeColor, Material = Enum.Material.Neon }, CFrame.new(0, w / 2, bladeZ))
		if tierIndex >= 3 then
			attach({ Name = "Edge2", Size = Vector3.new(0.14, 0.08, len * 0.97), Color = edgeColor, Material = Enum.Material.Neon }, CFrame.new(0, -w / 2, bladeZ))
		end
		if tierIndex >= 5 then
			attach({ Name = "Fuller", Size = Vector3.new(0.13, 0.08, len * 0.7), Color = edgeColor, Material = Enum.Material.Neon, Transparency = 0.2 }, CFrame.new(0, 0, bladeZ - len * 0.1))
		end
	end
	if tierIndex >= 8 then
		-- floating spirit shards orbiting the blade
		for i = 1, 3 do
			attach({ Name = "Shard", Size = Vector3.new(0.1, 0.25, 0.6), Color = edgeColor, Material = Enum.Material.Neon }, CFrame.new(0, (i - 2) * 0.55, bladeZ + (i - 2) * len * 0.3) * CFrame.new(0, w * 1.1 * (i % 2 == 0 and 1 or -1), 0))
		end
	end

	levelLabel(blade, Enum.NormalId.Right, "+" .. level, edgeColor)
	levelLabel(blade, Enum.NormalId.Left, "+" .. level, edgeColor)

	if tier.Light then
		local l = Instance.new("PointLight")
		l.Color = edgeColor
		l.Range = 8 + tierIndex
		l.Brightness = 1.5
		l.Parent = blade
	end
	if tier.Particles then
		local e = VFX.MakeEmitter(PARTICLE_PRESET[tier.Particles] or "Stars", edgeColor, blade, 6 + tierIndex)
		if tier.Particles == "Vortex" then
			e.Size = VFX.NS(0, 0.6, 1, 1.4)
		elseif tier.Particles == "Fire" then
			e.Size = VFX.NS(0, 0.5, 1, 0)
			e.Speed = NumberRange.new(0.5, 1.5)
		end
	end

	-- swing trail
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBase"
	a0.Position = Vector3.new(0, 0, -len / 2 + 0.2)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTip"
	a1.Position = Vector3.new(0, 0, len / 2 + 0.3)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), edgeColor)
	trail.Transparency = VFX.NS(0, 0.1, 1, 1)
	trail.WidthScale = VFX.NS(0, 1, 1, 0.2)
	trail.Lifetime = 0.16 + tierIndex * 0.01
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.MinLength = 0.05
	trail.Enabled = false
	trail.Parent = blade

	return tool
end

local function findTool(player: Player): Tool?
	local char = player.Character
	if char then
		for _, t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("IsBlade") then
				return t
			end
		end
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("IsBlade") then
				return t
			end
		end
	end
	return nil
end
Sword.Find = findTool

-- Give / update the blade. Rebuilds only when the visual tier changes.
function Sword.Refresh(player: Player, level: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local _, tierIndex = Config.GetBladeTier(level)
	local existing = findTool(player)
	if existing and existing:GetAttribute("Tier") == tierIndex then
		existing.Name = "Blade +" .. level
		existing:SetAttribute("Level", level)
		local blade = existing:FindFirstChild("Blade")
		if blade then
			for _, sg in ipairs(blade:GetChildren()) do
				if sg:IsA("SurfaceGui") and sg.Name == "LevelEtch" then
					local t = sg:FindFirstChild("Text")
					if t then
						(t :: TextLabel).Text = "+" .. level
					end
				end
			end
		end
		return
	end
	local wasEquipped = existing ~= nil and existing.Parent == char
	if existing then
		existing:Destroy()
	end
	local tool = build(level)
	tool.Parent = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	if wasEquipped or not existing then
		hum:EquipTool(tool)
	end
end

function Sword.SetTrail(player: Player, on: boolean)
	local tool = findTool(player)
	local blade = tool and tool:FindFirstChild("Blade")
	local trail = blade and blade:FindFirstChild("SwingTrail")
	if trail then
		(trail :: Trail).Enabled = on
	end
end

function Sword.PlaySlashAnim(player: Player)
	local tool = findTool(player)
	if not tool or tool.Parent ~= player.Character then
		return
	end
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
end

return Sword
