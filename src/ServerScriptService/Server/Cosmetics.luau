--!nonstrict
-- Cosmetics (ModuleScript) -> ServerScriptService/Server/Cosmetics
-- Overhead name tag (race + title), race / ascension auras, the Overdrive
-- transformation aura and the Chroma Trail gamepass. Server-side so every
-- player can see them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))

local Cosmetics = {}

local TIER_RATE = { Common = 0, Rare = 0, Epic = 6, Legendary = 10, Mythic = 16 }

local function clear(root: Instance, prefix: string)
	for _, c in ipairs(root:GetChildren()) do
		if c.Name:sub(1, #prefix) == prefix then
			c:Destroy()
		end
	end
end

local function attachment(root: BasePart, name: string, pos: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos or Vector3.zero
	a.Parent = root
	return a
end

local function nametag(player: Player, char: Model, data)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("Nametag")
	if old then
		old:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local race = Stats.Race(data)
	local tier = Stats.Tier(data)
	local isMC = race.Id == "MainCharacter"

	-- Minimal name tag: 45% smaller, soft shadow instead of a heavy outline,
	-- faded in by Client/WorldText only when you are near the player.
	local S = Config.WorldText.FontScale
	local bb = Instance.new("BillboardGui")
	bb.Name = "Nametag"
	bb.Size = UDim2.fromOffset(240 * S, (isMC and 84 or 62) * S)
	bb.StudsOffset = Vector3.new(0, isMC and 3 or 2.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb:SetAttribute("Radius", Config.WorldText.NametagRadius)
	CollectionService:AddTag(bb, "WorldLabel")
	bb.Parent = head
	local fade = Instance.new("CanvasGroup")
	fade.Name = "Fade"
	fade.BackgroundTransparency = 1
	fade.Size = UDim2.fromScale(1, 1)
	fade.GroupTransparency = 1
	fade.Parent = bb
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = fade

	local function line(text: string, color: Color3, h: number, font: Enum.Font, order: number)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, h * S)
		t.Font = font
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		t.LayoutOrder = order
		t.Parent = fade
		local st = Instance.new("UIStroke")
		st.Thickness = 1
		st.Color = Color3.fromRGB(10, 8, 18)
		st.Transparency = 0.45
		st.Parent = t
		return t
	end
	if isMC then
		local title = line("MAIN CHARACTER", Color3.fromRGB(255, 220, 90), 20, Config.Fonts.Display, 0)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 160)),
		})
		g.Parent = title
	end
	line(player.DisplayName, Color3.new(1, 1, 1), 28, Config.Fonts.Heading, 1)
	if data.Race ~= "" then
		local tierLabel = tier.Label or tier.Id
		line(string.format("%s %s%s", tierLabel, race.Name, data.Rebirths > 0 and ("  |  R" .. data.Rebirths) or ""), tier.Id == "Common" and race.Color or tier.Color, 20, Config.Fonts.Body, 2)
	end
end

function Cosmetics.Apply(player: Player)
	local data = DataService.Get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	nametag(player, char, data)
	clear(root, "Cos_")

	local race = Stats.Race(data)
	local tier = Stats.Tier(data)
	local isMC = race.Id == "MainCharacter"

	-- race aura (Epic+ skins, and always for Main Character)
	local rate = TIER_RATE[tier.Id] or 0
	if isMC then
		rate = math.max(rate, 18)
	end
	if data.Race ~= "" and rate > 0 then
		local a = attachment(root, "Cos_RaceAura", Vector3.new(0, -1.5, 0))
		local color = isMC and Color3.fromRGB(255, 205, 60) or tier.Color
		local e = VFX.MakeEmitter("Aura", color, a, rate)
		e.Transparency = VFX.NS(0, 0.6, 0.6, 0.7, 1, 1)
		if tier.Id == "Mythic" or isMC then
			VFX.MakeEmitter("Stars", color, a, 3)
		end
	end

	-- ascension aura from rebirths
	local asc = nil
	for _, a in ipairs(Config.AscensionAuras) do
		if data.Rebirths >= a.Rebirths then
			asc = a
		end
	end
	if asc then
		local a = attachment(root, "Cos_Ascension", Vector3.new(0, -2.8, 0))
		local e = VFX.MakeEmitter("Rise", asc.Color, a, 5)
		e.Shape = Enum.ParticleEmitterShape.Cylinder
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Size = VFX.NS(0, 0.35, 1, 0)
	end

	-- chroma trail gamepass
	if Stats.HasPass(player, "ChromaTrail") then
		local a0 = attachment(root, "Cos_Trail0", Vector3.new(0, 1, 0))
		local a1 = attachment(root, "Cos_Trail1", Vector3.new(0, -1.6, 0))
		local tr = Instance.new("Trail")
		tr.Name = "Cos_ChromaTrail"
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.6
		tr.LightEmission = 1
		tr.Transparency = VFX.NS(0, 0.2, 1, 1)
		tr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 90)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 120)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(140, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
		})
		tr.Parent = root
	end

	-- exclusive play-time aura (120 minute reward)
	if data.Cosmetics and data.Cosmetics.PlaytimeAura then
		local a = attachment(root, "Cos_Playtime", Vector3.new(0, -2.6, 0))
		for i, c in ipairs({ Color3.fromRGB(255, 90, 160), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 220, 90) }) do
			local e = VFX.MakeEmitter("Rise", c, a, 3)
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.Size = VFX.NS(0, 0.3 + i * 0.05, 1, 0)
		end
	end

	-- Mythic / Celestial weapon aura
	local def, rarity = Stats.Weapon(player)
	if rarity.Aura then
		local a = attachment(root, "Cos_Mythic", Vector3.new(0, -1.2, 0))
		local color = def.Glow or rarity.Color
		local e = VFX.MakeEmitter("Aura", color, a, 22)
		e.Transparency = VFX.NS(0, 0.5, 0.6, 0.6, 1, 1)
		VFX.MakeEmitter("Sparks", color, a, 6).Speed = NumberRange.new(3, 8)
	end

	Cosmetics.RefreshTransform(player)
end

-- Overdrive / Zenkai transformation aura (on while the buff is active).
function Cosmetics.RefreshTransform(player: Player)
	local data = DataService.Get(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	clear(root, "Cos_Transform")
	local overdrive = Stats.OverdriveActive(player)
	local zenkai = Stats.ZenkaiActive(player)
	if not overdrive and not zenkai then
		return
	end
	local color = zenkai and Color3.fromRGB(255, 225, 60) or Stats.Race(data).Color
	local a = attachment(root, "Cos_Transform", Vector3.new(0, -1, 0))
	local e = VFX.MakeEmitter("Aura", color, a, 45)
	e.Size = VFX.NS(0, 1.8, 0.5, 3, 1, 0)
	VFX.MakeEmitter("Sparks", color, a, 10).Speed = NumberRange.new(6, 14)
	local l = Instance.new("PointLight")
	l.Name = "Cos_TransformLight"
	l.Color = color
	l.Range = 16
	l.Brightness = 2
	l.Parent = root
end

return Cosmetics
