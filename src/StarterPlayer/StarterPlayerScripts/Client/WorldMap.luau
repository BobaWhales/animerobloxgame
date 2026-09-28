--!nonstrict
-- WorldMap (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/WorldMap
-- Full-screen stylized world map (M / D-pad right / drawer "Map").
--   * Look: dark holographic grid + topo contour lines + glowing region
--     outlines, a slow scanline shimmer and soft vignette.
--   * Layered depth: stars, grid, contours, terrain and two cloud layers
--     sit at different depths, so dragging the map gives subtle parallax.
--   * Fog of war: regions you have not walked into yet are hidden under
--     drifting cloud banks that dissolve the moment you explore them
--     (saved per player via the "Explore" request).
--   * Minimal waypoints: small colour-coded geometric symbols
--     (diamond = service, square = power, ring = travel, red diamond =
--     boss, outlined square = stage) that expand into a detailed callout on
--     hover / tap, with Track (world marker) and Travel buttons.
-- Controls: drag / WASD / left stick to pan, wheel / pinch / Q-E / LB-RB to
-- zoom, M or B to close.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local SFX = require(Shared:WaitForChild("SFX"))

local WorldMap = {}
WorldMap.IsOpen = false

local player = Players.LocalPlayer
local UI
local request: (string, any?) -> () = function() end
local data = nil

---------------------------------------------------------------------
-- LAYOUT (map units; 1 unit = 1 px at zoom 1)
---------------------------------------------------------------------
local OW = 2 -- map units per stud in the overworld
local DS = 0.75 -- map units per stud inside dungeon islands
local L = Config.DungeonLayout
local HALL_LEN = L.StartLen + L.RoomLen * Config.StagesPerZone
local ISLANDS = {
	[1] = { X = -330, Bottom = -330 },
	[2] = { X = 330, Bottom = -330 },
}
local SOON = {
	[3] = Vector2.new(-360, -960),
	[4] = Vector2.new(0, -1020),
	[5] = Vector2.new(360, -960),
}
local BOUNDS_MIN = Vector2.new(-700, -1180)
local BOUNDS_MAX = Vector2.new(620, 260)
local TOWER_WORLD = Vector3.new(160, 0, 0)

local COL = {
	Bg = Color3.fromRGB(5, 8, 17),
	Grid = Color3.fromRGB(0, 190, 255),
	Land = Color3.fromRGB(16, 26, 48),
	Land2 = Color3.fromRGB(24, 38, 68),
	Edge = Color3.fromRGB(90, 205, 255),
	Text = Color3.fromRGB(210, 235, 255),
	Fog = Color3.fromRGB(150, 170, 205),
	Service = Color3.fromRGB(255, 205, 80),
	Power = Color3.fromRGB(190, 130, 255),
	Travel = Color3.fromRGB(80, 225, 255),
	Danger = Color3.fromRGB(255, 70, 90),
	Stage = Color3.fromRGB(150, 255, 170),
	Locked = Color3.fromRGB(120, 125, 145),
	Player = Color3.new(1, 1, 1),
}
local KIND_LABEL = { Service = "SERVICE", Power = "POWER", Travel = "TRAVEL", Danger = "BOSS", Stage = "STAGE" }

local gui: ScreenGui
local viewport: Frame
local overlay: Frame
local cover: Frame
local callout: CanvasGroup
local CO: { [string]: any } = {} -- callout parts: Title, Kind, Desc, Status, Track, TrackLabel, Travel, Accent, Icon
local layers: { [string]: any } = {} -- [name] = { Frame, Scale, F }
local regions = {} -- [key] = { Rect, Fog = { Frame... }, Explored, Label }
local icons = {} -- list of icon records
local explored = {} -- [key] = true (local mirror)
local pan = Vector2.zero
local zoom = 1
local velocity = Vector2.zero
local dragging = false
local dragLast: Vector2? = nil
local dragTime = 0
local keyPan = Vector2.zero
local stick = Vector2.zero
local pinchStart = 1
local hovered = nil
local selected = nil
local playerMarker: Frame
local trackedMarker: Frame
local tracked = nil -- { Pos, Name, Map }
local worldMarker: BillboardGui? = nil
local worldAnchor: Attachment? = nil
local fogTime = 0
local exploreTimer = 0
local scanGrad: UIGradient

---------------------------------------------------------------------
-- small builders
---------------------------------------------------------------------
local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Parent = parent
	return f
end

local function corner(f: GuiObject, r: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = f
end

local function stroke(f: GuiObject, color: Color3, thickness: number, transparency: number)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.Parent = f
	return s
end

local function circle(parent: Instance, cx: number, cy: number, r: number, color: Color3, transparency: number): Frame
	local f = frame(parent, cx - r, cy - r, r * 2, r * 2, color, transparency)
	corner(f, UDim.new(0.5, 0))
	return f
end

local function dotted(parent: Instance, a: Vector2, b: Vector2, spacing: number, size: number, color: Color3, transparency: number)
	local d = b - a
	local n = math.floor(d.Magnitude / spacing)
	for i = 0, n do
		local p = a + d * (i / math.max(1, n))
		local dot = frame(parent, p.X - size / 2, p.Y - size / 2, size, size, color, transparency)
		corner(dot, UDim.new(0.5, 0))
	end
end

local function text(parent: Instance, x: number, y: number, str: string, size: number, color: Color3, font: Enum.Font?, anchor: Vector2?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.fromOffset(0, 0)
	t.Position = UDim2.fromOffset(x, y)
	t.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	t.Font = font or Enum.Font.BuilderSansBold
	t.TextSize = size
	t.Text = str
	t.TextColor3 = color
	t.Parent = parent
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Transparency = 0.5
	s.Parent = t
	return t
end

---------------------------------------------------------------------
-- COORDINATES
---------------------------------------------------------------------
local function dungeonAt(pos: Vector3): (number?, number)
	for zoneId, o in pairs(L.Origins) do
		local depth = (o.Z + L.StartLen / 2) - pos.Z
		if math.abs(pos.X - o.X) < L.RoomWidth / 2 + 12 and depth > -12 and depth < HALL_LEN + 12 then
			return zoneId, depth
		end
	end
	return nil, 0
end

local function worldToMap(pos: Vector3): Vector2
	local zoneId, depth = dungeonAt(pos)
	if zoneId and ISLANDS[zoneId] then
		local o = L.Origins[zoneId]
		local isl = ISLANDS[zoneId]
		return Vector2.new(isl.X + (pos.X - o.X) * DS, isl.Bottom - depth * DS)
	end
	if pos.X > 2000 then
		-- private tower arenas live far away; show them at the tower
		return Vector2.new(TOWER_WORLD.X * OW, TOWER_WORLD.Z * OW)
	end
	return Vector2.new(pos.X * OW, pos.Z * OW)
end

local function roomRect(zoneId: number, i: number)
	local isl = ISLANDS[zoneId]
	local w = L.RoomWidth * DS
	local startH = L.StartLen * DS
	local roomH = L.RoomLen * DS
	local top = isl.Bottom - startH - i * roomH
	return { isl.X - w / 2, top, w, roomH }
end

local function startRect(zoneId: number)
	local isl = ISLANDS[zoneId]
	local w = L.RoomWidth * DS
	local h = L.StartLen * DS
	return { isl.X - w / 2, isl.Bottom - h, w, h }
end

local function stageWorldCenter(stageIndex: number): Vector3?
	local stage = Config.Stages[stageIndex]
	local o = stage and L.Origins[stage.Zone]
	if not o then
		return nil
	end
	local i = stageIndex - (stage.Zone - 1) * Config.StagesPerZone
	local gateZ = o.Z + L.StartLen / 2 - L.StartLen - (i - 1) * L.RoomLen
	return Vector3.new(o.X, 3, gateZ - L.RoomLen / 2)
end

local function trainRange(): (number, number)
	local startX = -110
	local endX = startX - (#Config.TrainPads - 1) * 24
	return endX - 20, startX + 20
end

---------------------------------------------------------------------
-- FOG OF WAR
---------------------------------------------------------------------
local fogRng = Random.new(42)

-- Soft cloud puff: two stacked circles (a pale core inside a softer rim).
local function puff(parent: Instance, cx: number, cy: number, r: number)
	local holder = frame(parent, cx, cy, 0, 0, COL.Fog, 1)
	for k, mul in ipairs({ 1, 0.6 }) do
		local c = circle(holder, 0, 0, r * mul, COL.Fog:Lerp(Color3.new(1, 1, 1), (k - 1) * 0.15), 0.62 - (k - 1) * 0.08)
		c.Name = "Puff"
	end
	return holder
end

local function addFog(key: string, rect, label: string?, permanent: boolean?)
	local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
	local banks = {}
	for li, layerName in ipairs({ "FogLow", "FogHigh" }) do
		local layer = layers[layerName].Frame
		local bank = frame(layer, 0, 0, 0, 0, COL.Fog, 1)
		bank.Name = "Fog_" .. key
		local step = li == 1 and 34 or 50
		local pad = li == 1 and 10 or 22
		local yy = y - pad
		while yy <= y + h + pad do
			local xx = x - pad
			while xx <= x + w + pad do
				local r = fogRng:NextNumber(26, 44) * (li == 1 and 1 or 0.85)
				puff(bank, xx + fogRng:NextNumber(-8, 8), yy + fogRng:NextNumber(-8, 8), r)
				xx += step
			end
			yy += step
		end
		table.insert(banks, { Frame = bank, Phase = fogRng:NextNumber(0, 6.28), Layer = li })
	end
	local lbl = nil
	if label then
		lbl = text(layers.FogHigh.Frame, x + w / 2, y + h / 2, label, 13, Color3.fromRGB(235, 240, 255), Enum.Font.BuilderSansBold)
		lbl.TextTransparency = 0.15
		lbl.ZIndex = 5
	end
	regions[key] = { Rect = rect, Fog = banks, Label = lbl, Explored = false, Permanent = permanent }
end

local function dissolve(key: string, instant: boolean?)
	local r = regions[key]
	if not r or r.Explored or r.Permanent then
		return
	end
	r.Explored = true
	for _, bank in ipairs(r.Fog) do
		for _, d in ipairs(bank.Frame:GetDescendants()) do
			if d:IsA("Frame") and d.Name == "Puff" then
				if instant then
					d.BackgroundTransparency = 1
				else
					tween(d, 1.6 + math.random() * 0.8, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
				end
			end
		end
	end
	if r.Label then
		if instant then
			r.Label.Visible = false
		else
			tween(r.Label, 0.8, { TextTransparency = 1 })
		end
	end
end

local function isExplored(region: string?): boolean
	if not region or region == "Hub" then
		return true
	end
	return explored[region] == true
end

---------------------------------------------------------------------
-- STATIC ART
---------------------------------------------------------------------
local function drawBackground()
	-- deep star field (farthest layer)
	local stars = layers.Stars.Frame
	local rng = Random.new(7)
	for _ = 1, 140 do
		local s = rng:NextNumber(1.5, 4)
		local d = circle(stars, rng:NextNumber(-3200, 3200), rng:NextNumber(-3800, 2400), s, Color3.fromRGB(150, 200, 255), rng:NextNumber(0.35, 0.85))
		d.Name = "Star"
	end
	-- holographic grid
	local grid = layers.Grid.Frame
	for i = -36, 36 do
		local major = i % 4 == 0
		local v = frame(grid, i * 100, -3600, major and 2 or 1, 7200, COL.Grid, major and 0.82 or 0.92)
		v.AnchorPoint = Vector2.new(0.5, 0)
		local h = frame(grid, -3600, i * 100, 7200, major and 2 or 1, COL.Grid, major and 0.82 or 0.92)
		h.AnchorPoint = Vector2.new(0, 0.5)
	end
	-- topo contour rings (blueprint flavour)
	local topo = layers.Topo.Frame
	local function rings(cx, cy, from, to, stepR, t)
		for r = from, to, stepR do
			local c = circle(topo, cx, cy, r, COL.Edge, 1)
			stroke(c, COL.Edge, 1, t + (r - from) / (to - from + 1) * 0.08)
		end
	end
	rings(0, 0, 150, 520, 46, 0.84)
	rings(ISLANDS[1].X, (ISLANDS[1].Bottom - HALL_LEN * DS / 2), 260, 420, 55, 0.88)
	rings(ISLANDS[2].X, (ISLANDS[2].Bottom - HALL_LEN * DS / 2), 260, 420, 55, 0.88)
end

local function region(parent, rect, fill: Color3, edge: Color3, r: number?)
	local f = frame(parent, rect[1], rect[2], rect[3], rect[4], fill, 0.15)
	corner(f, UDim.new(0, r or 8))
	stroke(f, edge, 1.5, 0.35)
	return f
end

local function drawWorld()
	local w = layers.World.Frame

	-- hub plaza
	local plaza = circle(w, 0, 0, 60 * OW + 40, COL.Land, 0.1)
	stroke(plaza, COL.Edge, 1.5, 0.3)
	local core = circle(w, 0, 0, 30 * OW, COL.Land2, 0.1)
	stroke(core, Color3.fromRGB(255, 130, 200), 1, 0.45)
	text(w, 0, 60 * OW + 58, "HUB", 13, COL.Text, Enum.Font.BuilderSansExtraBold).TextTransparency = 0.2

	-- paths
	local path = Color3.fromRGB(40, 60, 100)
	frame(w, -105 * OW, -7 * OW, 50 * OW, 14 * OW, path, 0.2)
	frame(w, -7 * OW, -107 * OW, 14 * OW, 50 * OW, path, 0.2)
	frame(w, 55 * OW, -7 * OW, 80 * OW, 14 * OW, path, 0.2)

	-- train grounds
	local minX, maxX = trainRange()
	local train = { minX * OW, -28 * OW, (maxX - minX) * OW, 56 * OW }
	region(w, train, COL.Land, Color3.fromRGB(150, 255, 190))
	for i, pad in ipairs(Config.TrainPads) do
		local x = (-110 - (i - 1) * 24) * OW
		local c = circle(w, x, 0, Config.TrainPadRadius * OW * 0.8, pad.Color, 0.55)
		stroke(c, pad.Color, 1, 0.2)
	end
	text(w, train[1] + train[3] / 2, train[2] + train[4] + 16, "TRAIN GROUNDS", 12, COL.Text, Enum.Font.BuilderSansExtraBold).TextTransparency = 0.25

	-- portal gate
	local portalRect = { -80 * OW, -130 * OW, 160 * OW, 28 * OW }
	region(w, portalRect, COL.Land, COL.Travel)
	text(w, 0, portalRect[2] - 14, "PORTAL GATE", 12, COL.Text, Enum.Font.BuilderSansExtraBold).TextTransparency = 0.25

	-- tower
	local tower = circle(w, TOWER_WORLD.X * OW, 0, 22 * OW, COL.Land2, 0.1)
	stroke(tower, COL.Power, 1.5, 0.3)
	text(w, TOWER_WORLD.X * OW, 22 * OW + 16, "INFINITE TOWER", 12, COL.Text, Enum.Font.BuilderSansExtraBold).TextTransparency = 0.25

	-- dungeon islands + portal links
	for zoneId, isl in pairs(ISLANDS) do
		local zone = Config.Zones[zoneId]
		local accent = zone and zone.Accent or COL.Edge
		local portalX = (-64 + (zoneId - 1) * 32) * OW
		dotted(w, Vector2.new(portalX, -130 * OW), Vector2.new(isl.X, isl.Bottom + 6), 14, 3, accent, 0.35)
		local sr = startRect(zoneId)
		region(w, sr, COL.Land, accent, 6)
		for i = 1, Config.StagesPerZone do
			local rr = roomRect(zoneId, i)
			local stageIndex = (zoneId - 1) * Config.StagesPerZone + i
			local boss = Config.Stages[stageIndex] and Config.Stages[stageIndex].Boss
			region(w, rr, boss and Color3.fromRGB(40, 16, 30) or COL.Land, boss and COL.Danger or accent, 4)
		end
		text(w, isl.X, isl.Bottom - HALL_LEN * DS - 20, zone and zone.Name:upper() or "", 13, accent, Enum.Font.BuilderSansExtraBold)
	end

	-- future zones (always fogged)
	for zoneId, c in pairs(SOON) do
		local zone = Config.Zones[zoneId]
		local accent = zone and zone.Accent or COL.Edge
		for k, off in ipairs({ Vector2.new(-40, 10), Vector2.new(30, -10), Vector2.new(0, 30) }) do
			local blob = circle(w, c.X + off.X, c.Y + off.Y, 70 - k * 8, COL.Land, 0.2)
			stroke(blob, accent, 1, 0.5)
		end
		addFog("Soon" .. zoneId, { c.X - 110, c.Y - 90, 220, 190 }, (zone and zone.Name or "???") .. "\nCOMING SOON", true)
	end

	-- fog over everything that can be explored
	addFog("Train", { train[1] - 20, train[2] - 30, train[3] + 40, train[4] + 70 }, "UNCHARTED")
	addFog("Portals", { portalRect[1] - 20, portalRect[2] - 34, portalRect[3] + 40, portalRect[4] + 50 }, "UNCHARTED")
	addFog("Tower", { TOWER_WORLD.X * OW - 60, -60, 120, 150 }, "UNCHARTED")
	for zoneId in pairs(ISLANDS) do
		local sr = startRect(zoneId)
		addFog("Z" .. zoneId, { sr[1] - 14, sr[2], sr[3] + 28, sr[4] + 14 }, nil)
		for i = 1, Config.StagesPerZone do
			local rr = roomRect(zoneId, i)
			local stageIndex = (zoneId - 1) * Config.StagesPerZone + i
			addFog("S" .. stageIndex, { rr[1] - 14, rr[2], rr[3] + 28, rr[4] }, i == Config.StagesPerZone and "?" or nil)
		end
	end
end

---------------------------------------------------------------------
-- ICONS + CALLOUT
---------------------------------------------------------------------
local function stageStatus(stageIndex: number): (boolean, string)
	local stage = Config.Stages[stageIndex]
	if not stage or not data then
		return false, ""
	end
	local zone = Config.Zones[stage.Zone]
	local okPower = data.Power >= stage.PowerReq
	local okBlade = data.Blade >= (zone.BladeReq or 0)
	if okPower and okBlade then
		return true, "Unlocked"
	elseif not okBlade then
		return false, "Needs Blade +" .. Format.Abbrev(zone.BladeReq)
	end
	return false, "Needs " .. Format.Abbrev(stage.PowerReq) .. " Power"
end

local function shapeFor(kind: string, color: Color3, parent: Instance)
	local holder = Instance.new("Frame")
	holder.Name = "Shape"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(18, 18)
	holder.Parent = parent
	local sc = Instance.new("UIScale")
	sc.Parent = holder
	local main
	if kind == "Service" then
		main = frame(holder, 3, 3, 12, 12, color, 0)
		main.Rotation = 45
		stroke(main, Color3.new(1, 1, 1), 1, 0.4)
	elseif kind == "Power" then
		main = frame(holder, 4, 4, 10, 10, color, 0)
		corner(main, UDim.new(0, 2))
		stroke(main, Color3.new(1, 1, 1), 1, 0.4)
	elseif kind == "Travel" then
		main = frame(holder, 2, 2, 14, 14, color, 1)
		corner(main, UDim.new(0.5, 0))
		stroke(main, color, 2, 0)
		local dot = frame(holder, 7, 7, 4, 4, color, 0)
		corner(dot, UDim.new(0.5, 0))
	elseif kind == "Danger" then
		main = frame(holder, 2, 2, 14, 14, color, 0.7)
		main.Rotation = 45
		stroke(main, color, 2, 0)
		local dot = frame(holder, 7, 7, 4, 4, Color3.new(1, 1, 1), 0)
		dot.Rotation = 45
	else -- Stage
		main = frame(holder, 3, 3, 12, 12, color, 0.85)
		corner(main, UDim.new(0, 2))
		stroke(main, color, 1.5, 0)
	end
	main.Name = "Main"
	return holder, sc
end

local hideCallout

local function showCallout(icon)
	CO.Title.Text = icon.Name
	CO.Kind.Text = KIND_LABEL[icon.Kind] or string.upper(icon.Kind)
	CO.Kind.TextColor3 = icon.Color
	CO.Desc.Text = icon.Desc or ""
	local statusText, statusColor = "", COL.Text
	if icon.Stage then
		local ok, st = stageStatus(icon.Stage)
		statusText, statusColor = st, ok and Color3.fromRGB(130, 255, 160) or Color3.fromRGB(255, 120, 120)
	elseif icon.WorldPos then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			statusText = math.floor((root.Position - icon.WorldPos).Magnitude) .. " studs away"
		end
	end
	CO.Status.Text = statusText
	CO.Status.TextColor3 = statusColor
	CO.Travel.Visible = icon.Travel ~= nil
	CO.Track.Visible = icon.WorldPos ~= nil
	CO.TrackLabel.Text = (tracked and tracked.Icon == icon) and "UNTRACK" or "TRACK"
	CO.Accent.BackgroundColor3 = icon.Color
	local wasHidden = not callout.Visible or CO.Icon == nil
	callout.Visible = true
	CO.Icon = icon
	if wasHidden then
		CO.Scale.Scale = 0.92
		tween(CO.Scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Quart)
	end
	tween(callout, 0.15, { GroupTransparency = 0 })
end

hideCallout = function()
	if callout.Visible then
		tween(callout, 0.12, { GroupTransparency = 1 }).Completed:Once(function()
			if not (hovered or selected) then
				callout.Visible = false
				CO.Icon = nil
			end
		end)
	end
end

local function setEmphasis(icon, on: boolean)
	if icon then
		tween(icon.Scale, 0.16, { Scale = on and 1.45 or 1 }, Enum.EasingStyle.Back)
	end
end

local function addIcon(opts)
	local b = Instance.new("TextButton")
	b.Name = "Icon_" .. opts.Name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundTransparency = 1
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(28, 28)
	b.ZIndex = 4
	b.Parent = overlay
	local shape, sc = shapeFor(opts.Kind, opts.Color, b)
	local icon = {
		Button = b,
		Shape = shape,
		Scale = sc,
		Map = opts.Map,
		Kind = opts.Kind,
		Name = opts.Name,
		Desc = opts.Desc,
		Region = opts.Region,
		Travel = opts.Travel,
		WorldPos = opts.WorldPos,
		Color = opts.Color,
		Stage = opts.Stage,
	}
	b.MouseEnter:Connect(function()
		hovered = icon
		setEmphasis(icon, true)
		showCallout(icon)
		SFX.Play("UIHover")
	end)
	b.MouseLeave:Connect(function()
		if hovered == icon then
			hovered = nil
		end
		if selected ~= icon then
			setEmphasis(icon, false)
		end
		if selected then
			showCallout(selected)
		else
			hideCallout()
		end
	end)
	b.Activated:Connect(function()
		SFX.Play("UIClick")
		if selected == icon then
			selected = nil
			setEmphasis(icon, false)
			hideCallout()
		else
			if selected then
				setEmphasis(selected, false)
			end
			selected = icon
			setEmphasis(icon, true)
			showCallout(icon)
		end
	end)
	table.insert(icons, icon)
	return icon
end

local function recolorStages()
	for _, icon in ipairs(icons) do
		if icon.Stage then
			local ok = stageStatus(icon.Stage)
			local stage = Config.Stages[icon.Stage]
			local zone = Config.Zones[stage.Zone]
			local col = stage.Boss and COL.Danger or (ok and (zone.Accent or COL.Stage) or COL.Locked)
			icon.Color = col
			for _, d in ipairs(icon.Shape:GetDescendants()) do
				if d:IsA("Frame") and d.Name == "Main" then
					d.BackgroundColor3 = col
				elseif d:IsA("UIStroke") and d.Parent and d.Parent.Name == "Main" then
					d.Color = col
				end
			end
		end
	end
end

local function buildIcons()
	-- landmarks tagged by the server (MapBuilder.poi)
	local function fromPoi(part: Instance)
		if not part:IsA("BasePart") then
			return
		end
		local kind = part:GetAttribute("POIKind")
		if not kind or kind == "Danger" then
			return -- boss arenas are drawn from the stage list below
		end
		addIcon({
			Name = part:GetAttribute("POIName") or part.Name,
			Kind = kind,
			Desc = part:GetAttribute("POIDesc"),
			Region = part:GetAttribute("Region"),
			Travel = part:GetAttribute("Travel"),
			WorldPos = part.Position,
			Map = worldToMap(part.Position),
			Color = COL[kind] or COL.Edge,
		})
	end
	for _, part in ipairs(CollectionService:GetTagged("POI")) do
		fromPoi(part)
	end
	CollectionService:GetInstanceAddedSignal("POI"):Connect(fromPoi)
	-- dungeon stages
	for stageIndex, stage in ipairs(Config.Stages) do
		local wp = stageWorldCenter(stageIndex)
		if wp then
			addIcon({
				Name = (stage.Boss and "BOSS: " or "Stage " .. stageIndex .. ": ") .. stage.Enemy,
				Kind = stage.Boss and "Danger" or "Stage",
				Desc = stage.Boss and ("Stage " .. stageIndex .. " boss. Drops rare ore and weapons.") or ("Drops: " .. Format.Abbrev(stage.Coins) .. " Coins + ore per kill."),
				Region = "S" .. stageIndex,
				Travel = "Stage_" .. stageIndex,
				WorldPos = wp,
				Map = worldToMap(wp),
				Color = COL.Stage,
				Stage = stageIndex,
			})
		end
	end
	recolorStages()
end

local function buildCallout(parent: Instance)
	local c = Instance.new("CanvasGroup")
	c.Name = "Callout"
	c.BackgroundColor3 = Color3.fromRGB(8, 12, 24)
	c.BackgroundTransparency = 0.12
	c.GroupTransparency = 1
	c.Visible = false
	c.Size = UDim2.fromOffset(236, 132)
	c.ZIndex = 20
	c.Parent = parent
	corner(c, UDim.new(0, 10))
	stroke(c, COL.Edge, 1, 0.55)
	local sc = Instance.new("UIScale")
	sc.Parent = c
	CO.Scale = sc
	local accent = frame(c, 0, 0, 3, 132, COL.Edge, 0)
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 3, 1, 0)
	CO.Accent = accent
	local function lbl(name, y, h, font, color, size)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(14, y)
		t.Size = UDim2.new(1, -24, 0, h)
		t.Font = font
		t.TextSize = size
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.TextColor3 = color
		t.ZIndex = 21
		t.Parent = c
		return t
	end
	CO.Kind = lbl("Kind", 9, 12, Enum.Font.BuilderSansBold, COL.Edge, 11)
	CO.Title = lbl("Title", 22, 20, Enum.Font.BuilderSansExtraBold, Color3.new(1, 1, 1), 17)
	CO.Desc = lbl("Desc", 44, 32, Enum.Font.BuilderSansMedium, COL.Text, 13)
	CO.Status = lbl("Status", 76, 14, Enum.Font.BuilderSansBold, COL.Text, 12)
	local function btn(name, label, x, color, onClick)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AutoButtonColor = false
		b.Text = ""
		b.Position = UDim2.fromOffset(x, 98)
		b.Size = UDim2.fromOffset(100, 24)
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0.8
		b.ZIndex = 22
		b.Parent = c
		corner(b, UDim.new(0, 6))
		local st = stroke(b, color, 1, 0.3)
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.BuilderSansBold
		t.TextSize = 12
		t.Text = label
		t.TextColor3 = Color3.new(1, 1, 1)
		t.ZIndex = 23
		t.Parent = b
		b.MouseEnter:Connect(function()
			tween(b, 0.1, { BackgroundTransparency = 0.55 })
			tween(st, 0.1, { Transparency = 0 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.1, { BackgroundTransparency = 0.8 })
			tween(st, 0.1, { Transparency = 0.3 })
		end)
		b.Activated:Connect(function()
			SFX.Play("UIClick")
			onClick()
		end)
		return b, t
	end
	CO.Track, CO.TrackLabel = btn("Track", "TRACK", 14, COL.Edge, function()
		local icon = CO.Icon
		if icon then
			WorldMap.Track(if tracked and tracked.Icon == icon then nil else icon)
			showCallout(icon)
		end
	end)
	CO.Travel = btn("Travel", "TRAVEL", 122, COL.Service, function()
		local icon = CO.Icon
		if icon and icon.Travel then
			request("Teleport", icon.Travel)
			WorldMap.Close()
		end
	end)
	return c
end

---------------------------------------------------------------------
-- TRACKING (optional world marker; nothing shows until you pick a target)
---------------------------------------------------------------------
function WorldMap.Track(icon)
	if worldMarker then
		worldMarker:Destroy()
		worldMarker = nil
	end
	if worldAnchor then
		worldAnchor:Destroy()
		worldAnchor = nil
	end
	tracked = nil
	trackedMarker.Visible = false
	if not icon or not icon.WorldPos then
		return
	end
	tracked = { Icon = icon, Pos = icon.WorldPos, Map = icon.Map }
	trackedMarker.Visible = true
	local a = Instance.new("Attachment")
	a.WorldPosition = icon.WorldPos + Vector3.new(0, 6, 0)
	a.Parent = workspace.Terrain
	worldAnchor = a
	local bb = Instance.new("BillboardGui")
	bb.Name = "TrackedWaypoint"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(120, 34)
	bb.Adornee = a
	bb.ResetOnSpawn = false
	bb.Parent = player:WaitForChild("PlayerGui")
	local d = frame(bb, 54, 2, 10, 10, icon.Color, 0.1)
	d.Rotation = 45
	stroke(d, Color3.new(1, 1, 1), 1, 0.3)
	local t = Instance.new("TextLabel")
	t.Name = "Dist"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(0, 16)
	t.Size = UDim2.new(1, 0, 0, 14)
	t.Font = Enum.Font.BuilderSansBold
	t.TextSize = 12
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = ""
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 1
	st.Transparency = 0.5
	st.Parent = t
	worldMarker = bb
	SFX.Play("PromptTrigger")
end

---------------------------------------------------------------------
-- VIEW
---------------------------------------------------------------------
local function clampPan()
	pan = Vector2.new(math.clamp(pan.X, BOUNDS_MIN.X, BOUNDS_MAX.X), math.clamp(pan.Y, BOUNDS_MIN.Y, BOUNDS_MAX.Y))
end

local function toScreen(m: Vector2): Vector2
	local size = viewport.AbsoluteSize
	return size / 2 + (m - pan) * zoom
end

local function layout()
	for _, layer in pairs(layers) do
		layer.Frame.Position = UDim2.new(0.5, -pan.X * zoom * layer.F, 0.5, -pan.Y * zoom * layer.F)
		layer.Scale.Scale = zoom * layer.F
	end
	for _, icon in ipairs(icons) do
		local p = toScreen(icon.Map)
		icon.Button.Position = UDim2.fromOffset(p.X, p.Y)
		local visible = isExplored(icon.Region)
		icon.Button.Visible = visible
	end
	if tracked then
		local p = toScreen(tracked.Map)
		trackedMarker.Position = UDim2.fromOffset(p.X, p.Y)
	end
	local c = callout
	if c.Visible and CO.Icon then
		local p = toScreen(CO.Icon.Map)
		local size = viewport.AbsoluteSize
		local x = p.X + 20
		if x + c.AbsoluteSize.X > size.X - 10 then
			x = p.X - 20 - c.AbsoluteSize.X
		end
		local y = math.clamp(p.Y - 30, 70, size.Y - c.AbsoluteSize.Y - 10)
		c.Position = UDim2.fromOffset(x, y)
	end
end

local function setZoom(z: number, around: Vector2?)
	z = math.clamp(z, 0.45, 2.4)
	if around then
		local size = viewport.AbsoluteSize
		local m = pan + (around - size / 2) / zoom
		zoom = z
		pan = m - (around - size / 2) / zoom
	else
		zoom = z
	end
	clampPan()
end

local function centerOnPlayer()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		pan = worldToMap(root.Position)
		clampPan()
	end
end

---------------------------------------------------------------------
-- INPUT (bound only while the map is open)
---------------------------------------------------------------------
local held = {}
local PAN_KEYS = {
	[Enum.KeyCode.W] = Vector2.new(0, -1),
	[Enum.KeyCode.Up] = Vector2.new(0, -1),
	[Enum.KeyCode.S] = Vector2.new(0, 1),
	[Enum.KeyCode.Down] = Vector2.new(0, 1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
}

local function onMapInput(_, state, input)
	local key = input.KeyCode
	if PAN_KEYS[key] then
		if state == Enum.UserInputState.Begin then
			held[key] = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			held[key] = nil
		end
	elseif key == Enum.KeyCode.Thumbstick1 then
		local v = Vector2.new(input.Position.X, -input.Position.Y)
		stick = v.Magnitude > 0.15 and v or Vector2.zero
	elseif state == Enum.UserInputState.Begin then
		if key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonR1 then
			setZoom(zoom * 1.25)
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			setZoom(zoom / 1.25)
		elseif key == Enum.KeyCode.ButtonB then
			WorldMap.Close()
		end
	end
	return Enum.ContextActionResult.Sink
end

local SINK = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.C, Enum.KeyCode.F, Enum.KeyCode.H,
	Enum.KeyCode.Space, Enum.KeyCode.LeftShift,
	Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonB,
	Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2,
	Enum.KeyCode.ButtonL3, Enum.KeyCode.DPadUp,
	Enum.UserInputType.MouseButton1,
}

---------------------------------------------------------------------
-- OPEN / CLOSE
---------------------------------------------------------------------
function WorldMap.Open()
	if WorldMap.IsOpen then
		return
	end
	WorldMap.IsOpen = true
	if UI then
		UI.Close()
		UI.ToggleDrawer(false)
		UI.SetMenuFocus(true)
	end
	held = {}
	stick = Vector2.zero
	velocity = Vector2.zero
	centerOnPlayer()
	gui.Enabled = true
	cover.BackgroundTransparency = 0
	tween(cover, 0.45, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	zoom = 0.7
	local tw = Instance.new("NumberValue")
	tw.Value = 0.7
	tw.Changed:Connect(function(v)
		zoom = v
	end)
	tween(tw, 0.55, { Value = 1 }, Enum.EasingStyle.Quart).Completed:Once(function()
		tw:Destroy()
	end)
	layout()
	ContextActionService:BindActionAtPriority("WorldMapInput", onMapInput, false, 3000, table.unpack(SINK))
	SFX.Play("UIOpen")
end

function WorldMap.Close()
	if not WorldMap.IsOpen then
		return
	end
	WorldMap.IsOpen = false
	ContextActionService:UnbindAction("WorldMapInput")
	if UI then
		UI.SetMenuFocus(false)
	end
	if selected then
		setEmphasis(selected, false)
	end
	selected, hovered = nil, nil
	callout.Visible = false
	callout.GroupTransparency = 1
	CO.Icon = nil
	tween(cover, 0.2, { BackgroundTransparency = 0 }).Completed:Once(function()
		if not WorldMap.IsOpen then
			gui.Enabled = false
		end
	end)
	SFX.Play("UIClose")
end

function WorldMap.Toggle()
	if WorldMap.IsOpen then
		WorldMap.Close()
	else
		WorldMap.Open()
	end
end

---------------------------------------------------------------------
-- EXPLORATION
---------------------------------------------------------------------
local function markExplored(key: string, announce: boolean)
	if explored[key] then
		return
	end
	explored[key] = true
	dissolve(key, not announce)
	if announce then
		request("Explore", key)
		if UI then
			local r = regions[key]
			local name = key
			if key:sub(1, 1) == "S" then
				local st = Config.Stages[tonumber(key:sub(2)) or 0]
				name = st and ("Stage " .. key:sub(2) .. ": " .. st.Enemy) or key
			elseif key:sub(1, 1) == "Z" then
				local z = Config.Zones[tonumber(key:sub(2)) or 0]
				name = z and z.Name or key
			elseif key == "Train" then
				name = "Train Grounds"
			elseif key == "Portals" then
				name = "Portal Gate"
			elseif key == "Tower" then
				name = "Infinite Tower"
			end
			if r then
				UI.Notify("Map updated: " .. name, Color3.fromRGB(120, 220, 255))
			end
		end
	end
end

local function currentRegions(pos: Vector3): { string }
	local out = {}
	local zoneId, depth = dungeonAt(pos)
	if zoneId then
		table.insert(out, "Z" .. zoneId)
		local i = math.floor((depth - L.StartLen) / L.RoomLen) + 1
		if depth > L.StartLen and i >= 1 and i <= Config.StagesPerZone then
			table.insert(out, "S" .. ((zoneId - 1) * Config.StagesPerZone + i))
		end
		return out
	end
	if pos.X > 2000 then
		table.insert(out, "Tower")
		return out
	end
	local minX, maxX = trainRange()
	if pos.X < -95 and pos.X > minX - 20 and math.abs(pos.Z) < 45 then
		table.insert(out, "Train")
	end
	if pos.Z < -100 and pos.Z > -145 and math.abs(pos.X) < 95 then
		table.insert(out, "Portals")
	end
	if (Vector3.new(pos.X, 0, pos.Z) - TOWER_WORLD).Magnitude < 45 then
		table.insert(out, "Tower")
	end
	local _ = maxX
	return out
end

---------------------------------------------------------------------
-- PER-FRAME
---------------------------------------------------------------------
function WorldMap.Step(dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")

	exploreTimer -= dt
	if exploreTimer <= 0 and root and data then
		exploreTimer = 0.5
		for _, key in ipairs(currentRegions(root.Position)) do
			markExplored(key, true)
		end
	end

	-- tracked waypoint distance / arrival
	if tracked and worldMarker and root then
		local dist = (root.Position - tracked.Pos).Magnitude
		local label = worldMarker:FindFirstChild("Dist")
		if label then
			(label :: TextLabel).Text = math.floor(dist) .. " studs"
		end
		if dist < 14 then
			SFX.Play("Discover")
			if UI then
				UI.Notify("Arrived: " .. tracked.Icon.Name, Color3.fromRGB(120, 220, 255))
			end
			WorldMap.Track(nil)
		end
	end

	if not WorldMap.IsOpen then
		return
	end

	-- pan: keys / stick / inertia
	keyPan = Vector2.zero
	for key in pairs(held) do
		keyPan += PAN_KEYS[key] or Vector2.zero
	end
	local input = keyPan + stick
	if input.Magnitude > 0 then
		pan += input.Unit * math.min(1, input.Magnitude) * 620 * dt / zoom
		velocity = Vector2.zero
	elseif not dragging and velocity.Magnitude > 1 then
		pan += velocity * dt
		velocity *= math.max(0, 1 - dt * 6)
	end
	clampPan()

	-- drifting clouds + holo shimmer
	fogTime += dt
	for _, r in pairs(regions) do
		for _, bank in ipairs(r.Fog) do
			local amp = bank.Layer == 1 and 5 or 9
			bank.Frame.Position = UDim2.fromOffset(math.sin(fogTime * 0.25 + bank.Phase) * amp, math.cos(fogTime * 0.18 + bank.Phase) * amp * 0.6)
		end
	end
	scanGrad.Offset = Vector2.new(0, ((fogTime * 0.12) % 2) - 1)

	-- player marker
	if root then
		local p = toScreen(worldToMap(root.Position))
		playerMarker.Position = UDim2.fromOffset(p.X, p.Y)
		local look = root.CFrame.LookVector
		local arrow = playerMarker:FindFirstChild("Arrow")
		if arrow then
			(arrow :: Frame).Rotation = math.deg(math.atan2(look.X, -look.Z))
		end
		local ring = playerMarker:FindFirstChild("Pulse") :: Frame?
		if ring then
			local k = (fogTime % 1.6) / 1.6
			ring.Size = UDim2.fromOffset(12 + k * 34, 12 + k * 34)
			local st = ring:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = 0.2 + k * 0.8
			end
		end
	end
	-- pulse boss icons
	for _, icon in ipairs(icons) do
		if icon.Kind == "Danger" and icon ~= selected and icon ~= hovered then
			icon.Scale.Scale = 1 + math.sin(fogTime * 3) * 0.08
		end
	end
	layout()
end

function WorldMap.Update(snapshot)
	data = snapshot
	if snapshot.Explored then
		for key, v in pairs(snapshot.Explored) do
			if v and not explored[key] then
				markExplored(key, false)
			end
		end
	end
	recolorStages()
end

---------------------------------------------------------------------
-- INIT
---------------------------------------------------------------------
local function makeLayer(name: string, f: number, z: number)
	local fr = Instance.new("Frame")
	fr.Name = name
	fr.BackgroundTransparency = 1
	fr.Size = UDim2.fromOffset(0, 0)
	fr.ZIndex = z
	fr.Parent = viewport
	local sc = Instance.new("UIScale")
	sc.Parent = fr
	layers[name] = { Frame = fr, Scale = sc, F = f }
	return fr
end

local function legendChip(parent: Instance, x: number, kind: string, label: string)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(x, 0)
	holder.Size = UDim2.fromOffset(90, 22)
	holder.Parent = parent
	local s = shapeFor(kind, COL[kind], holder)
	s.Position = UDim2.fromOffset(10, 11)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(24, 0)
	t.Size = UDim2.new(1, -24, 1, 0)
	t.Font = Enum.Font.BuilderSansMedium
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = COL.Text
	t.Text = label
	t.Parent = holder
end

local function roundButton(parent: Instance, label: string, pos: UDim2, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(10, 16, 30)
	b.BackgroundTransparency = 0.2
	b.Size = UDim2.fromOffset(36, 36)
	b.Position = pos
	b.AnchorPoint = Vector2.new(1, 1)
	b.Font = Enum.Font.BuilderSansExtraBold
	b.TextSize = label:len() > 1 and 12 or 20
	b.TextColor3 = COL.Text
	b.Text = label
	b.ZIndex = 30
	b.Parent = parent
	corner(b, UDim.new(0.5, 0))
	local st = stroke(b, COL.Edge, 1, 0.5)
	b.MouseEnter:Connect(function()
		tween(st, 0.1, { Transparency = 0 })
		SFX.Play("UIHover")
	end)
	b.MouseLeave:Connect(function()
		tween(st, 0.1, { Transparency = 0.5 })
	end)
	b.Activated:Connect(function()
		SFX.Play("UIClick")
		onClick()
	end)
	return b
end

function WorldMap.Init(ui, requestFn)
	UI = ui
	request = requestFn
	gui = Instance.new("ScreenGui")
	gui.Name = "WorldMap"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	viewport = Instance.new("Frame")
	viewport.Name = "Viewport"
	viewport.BackgroundColor3 = COL.Bg
	viewport.BorderSizePixel = 0
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ClipsDescendants = true
	viewport.Active = true
	viewport.Parent = gui

	makeLayer("Stars", 0.3, 1)
	makeLayer("Grid", 0.6, 2)
	makeLayer("Topo", 0.85, 3)
	makeLayer("World", 1, 4)
	makeLayer("FogLow", 1, 6)
	makeLayer("FogHigh", 1.12, 7)

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 10
	overlay.Parent = viewport

	drawBackground()
	drawWorld()

	-- holo scanline shimmer + vignette
	local scan = frame(viewport, 0, 0, 0, 0, COL.Grid, 0.93)
	scan.Size = UDim2.fromScale(1, 1)
	scan.ZIndex = 9
	scan.Active = false
	scanGrad = Instance.new("UIGradient")
	scanGrad.Rotation = 90
	scanGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	scanGrad.Parent = scan
	for i, spec in ipairs({ { 90, UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0) }, { 270, UDim2.fromScale(1, 0.25), UDim2.fromScale(0, 0.75) }, { 0, UDim2.fromScale(0.2, 1), UDim2.fromScale(0, 0) }, { 180, UDim2.fromScale(0.2, 1), UDim2.fromScale(0.8, 0) } }) do
		local v = frame(viewport, 0, 0, 0, 0, Color3.new(0, 0, 0), 0)
		v.Name = "Vignette" .. i
		v.Size = spec[2]
		v.Position = spec[3]
		v.ZIndex = 11
		local g = Instance.new("UIGradient")
		g.Rotation = spec[1]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = v
	end

	-- player + tracked markers (unscaled, above the fog)
	playerMarker = Instance.new("Frame")
	playerMarker.Name = "PlayerMarker"
	playerMarker.BackgroundTransparency = 1
	playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	playerMarker.Size = UDim2.fromOffset(24, 24)
	playerMarker.ZIndex = 15
	playerMarker.Parent = overlay
	local pulse = circle(playerMarker, 12, 12, 6, COL.Player, 1)
	pulse.Name = "Pulse"
	pulse.AnchorPoint = Vector2.new(0.5, 0.5)
	pulse.Position = UDim2.fromScale(0.5, 0.5)
	stroke(pulse, COL.Player, 1.5, 0.3)
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(24, 24)
	arrow.Parent = playerMarker
	for _, side in ipairs({ -1, 1 }) do
		local bar = frame(arrow, 12 + side * 4, 12, 3, 13, COL.Player, 0)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Rotation = -side * 32 -- tops meet in the middle: a "^" chevron
		corner(bar, UDim.new(0.5, 0))
	end
	local dot = circle(arrow, 12, 14, 2.5, COL.Player, 0)
	dot.Name = "Dot"

	trackedMarker = Instance.new("Frame")
	trackedMarker.Name = "Tracked"
	trackedMarker.BackgroundTransparency = 1
	trackedMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	trackedMarker.Size = UDim2.fromOffset(30, 30)
	trackedMarker.Visible = false
	trackedMarker.ZIndex = 14
	trackedMarker.Parent = overlay
	local tr = circle(trackedMarker, 15, 15, 14, Color3.new(1, 1, 1), 1)
	stroke(tr, Color3.new(1, 1, 1), 1.5, 0.2)

	callout = buildCallout(overlay)
	buildIcons()

	-- header + legend + buttons
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(28, 22)
	header.Size = UDim2.fromOffset(500, 50)
	header.ZIndex = 30
	header.Parent = gui
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 26)
	title.Font = Enum.Font.BuilderSansExtraBold
	title.TextSize = 24
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = "WORLD MAP"
	title.Parent = header
	local hint = title:Clone()
	hint.Position = UDim2.fromOffset(0, 28)
	hint.Size = UDim2.new(1, 0, 0, 16)
	hint.Font = Enum.Font.BuilderSansMedium
	hint.TextSize = 13
	hint.TextColor3 = COL.Text
	hint.TextTransparency = 0.25
	hint.Text = "Drag / WASD to pan  ·  Scroll / Q-E to zoom  ·  Click a marker for details  ·  M to close"
	hint.Parent = header

	local legend = Instance.new("Frame")
	legend.BackgroundTransparency = 1
	legend.Position = UDim2.new(0, 28, 1, -44)
	legend.Size = UDim2.fromOffset(520, 22)
	legend.ZIndex = 30
	legend.Parent = gui
	legendChip(legend, 0, "Service", "Service")
	legendChip(legend, 90, "Power", "Power")
	legendChip(legend, 170, "Travel", "Travel")
	legendChip(legend, 250, "Stage", "Stage")
	legendChip(legend, 330, "Danger", "Boss")

	roundButton(gui, "X", UDim2.new(1, -24, 0, 60), WorldMap.Close)
	roundButton(gui, "+", UDim2.new(1, -24, 1, -110), function()
		setZoom(zoom * 1.25)
	end)
	roundButton(gui, "-", UDim2.new(1, -24, 1, -68), function()
		setZoom(zoom / 1.25)
	end)
	roundButton(gui, "ME", UDim2.new(1, -24, 1, -26), function()
		centerOnPlayer()
		velocity = Vector2.zero
	end)

	cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.BackgroundColor3 = Color3.new(0, 0, 0)
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 1)
	cover.ZIndex = 50
	cover.Active = false
	cover.Parent = gui

	-- drag to pan (with inertia), wheel / pinch to zoom
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragLast = Vector2.new(input.Position.X, input.Position.Y)
			dragTime = os.clock()
			velocity = Vector2.zero
			if selected then
				setEmphasis(selected, false)
				selected = nil
				hideCallout()
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not WorldMap.IsOpen then
			return
		end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local now = os.clock()
			if dragLast then
				local delta = p - dragLast
				pan -= delta / zoom
				velocity = -delta / zoom / math.max(now - dragTime, 1 / 240)
				clampPan()
			end
			dragLast = p
			dragTime = now
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local m = UserInputService:GetMouseLocation()
			setZoom(zoom * (input.Position.Z > 0 and 1.15 or 1 / 1.15), m - viewport.AbsolutePosition)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			dragLast = nil
			if os.clock() - dragTime > 0.08 then
				velocity = Vector2.zero -- released after holding still: no fling
			elseif velocity.Magnitude > 2400 then
				velocity = velocity.Unit * 2400
			end
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state)
		if not WorldMap.IsOpen then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchStart = zoom
			dragging = false
		elseif state == Enum.UserInputState.Change then
			setZoom(pinchStart * scale)
		end
	end)

	layout()
end

return WorldMap
