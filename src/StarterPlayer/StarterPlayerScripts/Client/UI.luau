--!nonstrict
-- UI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/UI
-- HUD, menus, race roll, notifications. Styled through UITheme (UIPackPlus).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local SFX = require(Shared:WaitForChild("SFX"))
local VFX = require(Shared:WaitForChild("VFX"))

local player = Players.LocalPlayer
local C = UITheme.Colors

local UI = {}
UI.Data = nil
UI.ApplySettings = nil :: ((any) -> ())?
UI.ToggleMap = nil :: (() -> ())?
local request: (string, any?) -> () = function() end

local screen: ScreenGui
local root: Frame
local uiScale: UIScale
local flyGui: ScreenGui
local pills: { [string]: any } = {}
local panels = {}
local current = nil
local dim: Frame
local toastHolder: Frame
local padLabel: TextLabel
local zoneBanner: Frame
local towerHud: Frame
local stageHud: Frame
local eventRow: Frame
local menuHint: TextLabel
local adminButton: GuiObject
local DRAWER_X = 204
local drawer: CanvasGroup
local drawerOpen = false
local numberValues = {}
local prevValues = {}

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.Color or C.Bg
	f.BackgroundTransparency = props.Transparency or 0
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Position = props.Position or UDim2.new()
	f.AnchorPoint = props.AnchorPoint or Vector2.zero
	f.LayoutOrder = props.Order or 0
	f.ZIndex = props.ZIndex or 1
	f.Name = props.Name or "Frame"
	f.Parent = parent
	if props.Corner then
		UITheme.Corner(f, props.Corner)
	end
	if props.Stroke then
		UITheme.Stroke(f, props.Stroke, nil, true)
	end
	return f
end

local function list(parent, padding, horizontal, align)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 8)
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

local function scroller(parent, props)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = props.Size or UDim2.fromScale(1, 1)
	s.Position = props.Position or UDim2.new()
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = Color3.fromRGB(200, 180, 255)
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = s
	return s
end

local function clearList(container: Instance)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

-- Count-up animation for HUD numbers.
local function animateNumber(key: string, label: TextLabel, target: number, fmt: (number) -> string)
	local nv = numberValues[key]
	if not nv then
		nv = Instance.new("NumberValue")
		nv.Value = target
		numberValues[key] = nv
		nv.Changed:Connect(function(v)
			label.Text = fmt(v)
		end)
		label.Text = fmt(target)
		return
	end
	if math.abs(nv.Value - target) < 0.5 then
		nv.Value = target
		label.Text = fmt(target)
		return
	end
	tween(nv, 0.45, { Value = target }, Enum.EasingStyle.Quart)
end

---------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------
-- Minimal text with a light drop shadow (used across the clean-screen HUD).
local function softLabel(parent: Instance, props)
	local t = Instance.new("TextLabel")
	t.Name = props.Name or "Label"
	t.BackgroundTransparency = 1
	t.Font = props.Font or Config.Fonts.Heading
	t.TextScaled = true
	t.Text = props.Text or ""
	t.TextColor3 = props.Color or C.Text
	t.TextTransparency = props.Transparency or 0
	t.Size = props.Size or UDim2.fromScale(1, 1)
	t.Position = props.Position or UDim2.new()
	t.AnchorPoint = props.AnchorPoint or Vector2.zero
	t.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	t.RichText = props.Rich == true
	t.ZIndex = props.ZIndex or 1
	t.LayoutOrder = props.Order or 0
	t.Parent = parent
	local st = Instance.new("UIStroke")
	st.Thickness = props.StrokeThickness or 1
	st.Color = Color3.fromRGB(6, 4, 14)
	st.Transparency = 0.5
	st.Parent = t
	if props.MaxText then
		local cons = Instance.new("UITextSizeConstraint")
		cons.MaxTextSize = props.MaxText
		cons.Parent = t
	end
	return t
end

-- Compact currency pills (left). Pinned pills are always shown; a small
-- badge on the right flags "REBIRTH!" / "FULL". Clicking opens the menu.
local function makePill(parent, key: string, role: string, color: Color3, order: number, pinned: boolean?, panelName: string?)
	local holder = Instance.new("CanvasGroup")
	holder.Name = key
	holder.BackgroundTransparency = 1
	holder.GroupTransparency = pinned and 0 or 1
	holder.Visible = pinned == true
	holder.Size = UDim2.fromOffset(138, 30)
	holder.LayoutOrder = order
	holder.Parent = parent
	local f = frame(holder, { Color = Color3.fromRGB(10, 8, 18), Transparency = 0.3, Corner = 15 })
	f.Name = "Pill"
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Thickness = 1.2
	st.Color = color
	st.Transparency = 0.5
	st.Parent = f
	UITheme.Icon(f, role, UDim2.fromOffset(20, 20), UDim2.fromOffset(6, 5))
	local value = softLabel(f, { Name = "Value", Text = "0", Font = Config.Fonts.Display, Size = UDim2.new(1, -38, 0, 20), Position = UDim2.fromOffset(31, 5), XAlign = Enum.TextXAlignment.Left, MaxText = 18 })
	local sub = softLabel(f, { Name = "Sub", Text = "", Font = Config.Fonts.Display, Size = UDim2.fromOffset(52, 12), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), XAlign = Enum.TextXAlignment.Right, Color = C.Gold, MaxText = 11 })
	sub.Visible = false
	local sc = Instance.new("UIScale")
	sc.Parent = f
	if panelName then
		local click = Instance.new("TextButton")
		click.Name = "Click"
		click.BackgroundTransparency = 1
		click.Text = ""
		click.Size = UDim2.fromScale(1, 1)
		click.ZIndex = 5
		click.Parent = holder
		click.Activated:Connect(function()
			SFX.Play("UIClick")
			UI.Toggle(panelName)
		end)
	end
	pills[key] = { Holder = holder, Frame = f, Value = value, Sub = sub, Scale = sc, Color = color, Until = 0, Alpha = pinned and 1 or 0, Pinned = pinned == true }
end

-- Show a resource pill for a few seconds.
function UI.Reveal(key: string, seconds: number?)
	local p = pills[key]
	if p then
		p.Until = math.max(p.Until, os.clock() + (seconds or Config.Hud.ResourceLinger))
		if not p.Holder.Visible then
			p.Holder.Visible = true
		end
	end
end

function UI.Bump(key: string)
	local p = pills[key]
	if not p then
		return
	end
	UI.Reveal(key)
	p.Scale.Scale = 1.12
	tween(p.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function UI.PillScreenPos(key: string): Vector2?
	local p = pills[key]
	if not p then
		return nil
	end
	return p.Holder.AbsolutePosition + Vector2.new(21, p.Holder.AbsoluteSize.Y / 2)
end

-- Little icons that fly from a world position into a HUD pill. The pill is
-- revealed first; the target is read after the burst so the layout has
-- already placed the (previously hidden) pill.
function UI.FlyToHud(key: string, worldPos: Vector3?, color: Color3, count)
	local cam = workspace.CurrentCamera
	if not pills[key] or not cam then
		return
	end
	UI.Reveal(key, Config.Hud.ResourceLinger + 1)
	local start
	if worldPos then
		local v, onScreen = cam:WorldToViewportPoint(worldPos)
		if not onScreen then
			return
		end
		start = Vector2.new(v.X, v.Y)
	else
		start = cam.ViewportSize / 2
	end
	count = math.clamp(count or 5, 1, 10)
	for i = 1, count do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.Rotation = 45
		dot.Position = UDim2.fromOffset(start.X, start.Y)
		dot.ZIndex = 40
		dot.Parent = flyGui
		local glow = Instance.new("UIStroke")
		glow.Thickness = 1.5
		glow.Color = Color3.new(1, 1, 1)
		glow.Transparency = 0.3
		glow.Parent = dot
		local burst = start + Vector2.new(math.random(-60, 60), math.random(-60, 25))
		local delay = (i - 1) * 0.035
		task.delay(delay, function()
			tween(dot, 0.22, { Position = UDim2.fromOffset(burst.X, burst.Y), Rotation = 225 }, Enum.EasingStyle.Quad)
			task.delay(0.24, function()
				local target = UI.PillScreenPos(key) or burst
				tween(dot, 0.35, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(6, 6) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.35, function()
					dot:Destroy()
					UI.Bump(key)
				end)
			end)
		end)
	end
end

---------------------------------------------------------------------
-- NOTIFICATIONS
---------------------------------------------------------------------
function UI.Notify(text: string, colorArg: Color3?)
	local color: Color3 = colorArg or Color3.fromRGB(255, 255, 255)
	local holder = frame(toastHolder, { Transparency = 1, Size = UDim2.fromOffset(240, 22) })
	local toast = frame(holder, { Color = Color3.fromRGB(8, 6, 18), Transparency = 0.45, Size = UDim2.fromScale(1, 1), Corner = 6 })
	toast.Position = UDim2.fromOffset(260, 0)
	local bar = frame(toast, { Color = color, Size = UDim2.new(0, 2, 1, -8), Position = UDim2.fromOffset(5, 4), Corner = 1 })
	bar.Name = "Bar"
	softLabel(toast, { Text = text, Size = UDim2.new(1, -18, 1, -6), Position = UDim2.fromOffset(12, 3), XAlign = Enum.TextXAlignment.Left, Color = color:Lerp(Color3.new(1, 1, 1), 0.35), MaxText = 12 })
	tween(toast, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
	local kids = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 4 then
		kids[1]:Destroy()
	end
	task.delay(3, function()
		if toast.Parent then
			tween(toast, 0.3, { Position = UDim2.fromOffset(260, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(holder, 0.4)
		end
	end)
end

---------------------------------------------------------------------
-- PANEL FRAMEWORK
---------------------------------------------------------------------
local function makePanel(name: string, title: string, size: Vector2, accent: Color3)
	local panelFrame, content = UITheme.Panel(root, { Name = name, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 5, Accent = accent })
	panelFrame.Visible = false
	local sc = Instance.new("UIScale")
	sc.Parent = panelFrame

	-- consistent header: a slanted accent tab riding the top-left edge, a thin
	-- accent rule across the top, and a square close button
	local tabWidth = math.clamp(#title * 19 + 56, 150, size.X - 90)
	local header = frame(panelFrame, { Color = accent, Size = UDim2.fromOffset(tabWidth, 46), Position = UDim2.fromOffset(20, -20), Corner = 8, Stroke = 2 })
	header.Name = "Header"
	header.Rotation = -2
	UITheme.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165), 90)
	local notch = frame(header, { Color = Color3.fromRGB(10, 8, 18), Transparency = 0.2, Size = UDim2.fromOffset(6, 26), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Corner = 2 })
	notch.Name = "Notch"
	UITheme.Label(header, { Text = title, Title = true, Size = UDim2.new(1, -40, 1, -8), Position = UDim2.fromOffset(28, 4), XAlign = Enum.TextXAlignment.Left, MaxText = 32, StrokeThickness = 2.5 })
	local rule = frame(panelFrame, { Color = accent, Transparency = 0.25, Size = UDim2.new(1, -tabWidth - 60, 0, 2), Position = UDim2.fromOffset(tabWidth + 30, 12) })
	rule.Name = "Rule"

	UITheme.Button(panelFrame, {
		Name = "Close",
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(1, 8, 0, -12),
		AnchorPoint = Vector2.new(1, 0),
		MaxText = 26,
		Corner = 8,
		Sound = "UIClose",
		OnClick = function()
			UI.Close()
		end,
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 40)
	body.Size = UDim2.new(1, 0, 1, -40)
	body.Parent = content

	local panel = { Frame = panelFrame, Body = body, Scale = sc, Mode = nil, Sig = nil, Refresh = nil, Accent = accent }
	panels[name] = panel
	return panel
end

-- Depth of field blur behind menus / shop / dialogue.
local dof: DepthOfFieldEffect? = nil
function UI.SetMenuFocus(on: boolean)
	local cfg = Config.Graphics.MenuDepthOfField
	if not dof then
		local d = Instance.new("DepthOfFieldEffect")
		d.Name = "MenuFocus"
		d.FarIntensity = 0
		d.NearIntensity = 0
		d.FocusDistance = cfg.FocusDistance
		d.InFocusRadius = cfg.InFocusRadius
		d.Parent = game:GetService("Lighting")
		dof = d
	end
	tween(dof, 0.3, { FarIntensity = on and cfg.FarIntensity or 0, NearIntensity = on and cfg.NearIntensity or 0 })
end

function UI.Open(name: string, mode: string?)
	local panel = panels[name]
	if not panel then
		return
	end
	if current and current ~= panel then
		current.Frame.Visible = false
	end
	panel.Mode = mode
	panel.Sig = nil
	current = panel
	panel.Frame.Visible = true
	panel.Scale.Scale = 0.6
	tween(panel.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	dim.Visible = true
	tween(dim, 0.25, { BackgroundTransparency = 0.55 })
	UI.SetMenuFocus(true)
	if panel.Refresh and UI.Data then
		panel.Refresh(UI.Data)
	end
end

function UI.Toggle(name: string, mode: string?)
	if current == panels[name] and current and current.Frame.Visible then
		UI.Close()
	else
		UI.Open(name, mode)
	end
end

function UI.Close()
	local panel = current
	current = nil
	if panel then
		local tw = tween(panel.Scale, 0.15, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Once(function()
			if current ~= panel then
				panel.Frame.Visible = false
			end
		end)
	end
	UI.SetMenuFocus(false)
	tween(dim, 0.2, { BackgroundTransparency = 1 }).Completed:Once(function()
		if not current then
			dim.Visible = false
		end
	end)
end

local function rowFrame(parent, height: number, order: number, color: Color3?)
	local f = frame(parent, { Color = color or C.Row, Size = UDim2.new(1, 0, 0, height), Order = order, Corner = 10 })
	local st = UITheme.Stroke(f, 1, C.Line, true)
	st.Transparency = 0.35
	UITheme.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(200, 196, 215), 90)
	return f
end

-- Thin coloured bar on the left edge of a row (rarity / accent marker).
local function accentBar(row: GuiObject, color: Color3)
	local b = frame(row, { Color = color, Size = UDim2.new(0, 4, 1, -14), Position = UDim2.fromOffset(6, 7), Corner = 2 })
	b.Name = "Accent"
	return b
end

---------------------------------------------------------------------
-- PANELS
---------------------------------------------------------------------
local function buildUpgrades()
	local p = makePanel("Upgrades", "UPGRADES", Vector2.new(660, 450), C.Blue)
	UITheme.Label(p.Body, { Text = "Levels never cap. Prices climb linearly to level " .. Config.UpgradeLinearUntil .. ", then grow exponentially.", Size = UDim2.new(1, 0, 0, 22), Color = C.Sub, MaxText = 15 })
	local holder = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30) })
	list(holder, 10)
	local rows = {}
	local icons = { Backpack = "Icon_Backpack", Luck = "Icon_Gem", Training = "Icon_Power" }
	local colors = { Backpack = C.Gold, Luck = C.Green, Training = C.Red }
	for i, key in ipairs(Config.UpgradeOrder) do
		local cfg = Config.Upgrades[key]
		local r = rowFrame(holder, 108, i)
		accentBar(r, colors[key])
		UITheme.Icon(r, icons[key], UDim2.fromOffset(60, 60), UDim2.fromOffset(20, 24))
		UITheme.Label(r, { Text = cfg.Name, Title = true, Size = UDim2.new(0.45, 0, 0, 32), Position = UDim2.fromOffset(94, 8), XAlign = Enum.TextXAlignment.Left, MaxText = 28 })
		local lvl = UITheme.Label(r, { Text = "", Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(94, 42), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 17, Rich = true })
		local val = UITheme.Label(r, { Text = "", Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(94, 70), XAlign = Enum.TextXAlignment.Left, Color = C.Green, MaxText = 17, Rich = true })
		local btn = UITheme.Button(r, {
			Text = "Buy",
			Color = "Gold",
			Size = UDim2.fromOffset(180, 62),
			Position = UDim2.new(1, -16, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Sound = "Purchase",
			OnClick = function()
				request("Upgrade", key)
			end,
		})
		rows[key] = { Level = lvl, Value = val, Button = btn }
	end
	p.Refresh = function(d)
		for key, r in pairs(rows) do
			local u = Config.Upgrades[key]
			local lvl = d.Upgrades[key] or 0
			local cost = d.UpgradeCosts[key]
			local expo = lvl >= Config.UpgradeLinearUntil
			r.Level.Text = "Level <b>" .. Format.Commas(lvl) .. "</b>  " .. (expo and '<font color="#ff64b9">EXPONENTIAL</font>' or ("linear until " .. Config.UpgradeLinearUntil))
			if key == "Backpack" then
				r.Value.Text = string.format("Ore bag: <b>%s</b> -> %s", Format.Abbrev(d.BackpackMax), Format.Abbrev(d.BackpackMax + u.Per))
			else
				local now = math.floor(lvl * u.Per * 100 + 0.5)
				local nxt = math.floor((lvl + 1) * u.Per * 100 + 0.5)
				r.Value.Text = string.format("%s: <b>+%s%%</b> -> +%s%%", key == "Luck" and "Luck" or "Power gain", Format.Abbrev(now), Format.Abbrev(nxt))
			end
			UITheme.SetButtonText(r.Button, cost and cost >= 0 and (Format.Abbrev(cost) .. " Coins") or "...")
		end
	end
end

local function buildRace()
	local p = makePanel("Race", "RACE", Vector2.new(680, 470), C.Purple)
	local top = rowFrame(p.Body, 150, 0, Color3.fromRGB(40, 30, 70))
	local raceName = UITheme.Label(top, { Text = "???", Title = true, Size = UDim2.new(0.62, 0, 0, 52), Position = UDim2.fromOffset(18, 10), XAlign = Enum.TextXAlignment.Left, MaxText = 44, StrokeThickness = 3 })
	local tierName = UITheme.Label(top, { Text = "", Size = UDim2.new(0.62, 0, 0, 26), Position = UDim2.fromOffset(18, 62), XAlign = Enum.TextXAlignment.Left, MaxText = 22 })
	local desc = UITheme.Label(top, { Text = "", Size = UDim2.new(0.62, 0, 0, 52), Position = UDim2.fromOffset(18, 90), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 18 })
	desc.TextWrapped = true
	local rerolls = UITheme.Label(top, { Text = "", Size = UDim2.fromOffset(200, 26), Position = UDim2.new(1, -18, 0, 16), AnchorPoint = Vector2.new(1, 0), Color = C.Gold, MaxText = 22 })
	UITheme.Button(top, {
		Text = "ROLL RACE",
		Color = "Purple",
		Size = UDim2.fromOffset(200, 70),
		Position = UDim2.new(1, -18, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		MaxText = 26,
		OnClick = function()
			request("Reroll")
		end,
	})
	local odds = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -160), Position = UDim2.fromOffset(0, 160) })
	list(odds, 6)
	for i, race in ipairs(Config.Races) do
		local r = rowFrame(odds, 44, i)
		local sw = frame(r, { Color = race.Color, Size = UDim2.fromOffset(10, 30), Position = UDim2.fromOffset(10, 7), Corner = 4 })
		sw.Name = "Swatch"
		UITheme.Label(r, { Text = race.Name, Title = true, Size = UDim2.fromOffset(170, 30), Position = UDim2.fromOffset(28, 7), XAlign = Enum.TextXAlignment.Left, Color = race.Color, MaxText = 22 })
		UITheme.Label(r, { Text = Format.Percent(race.Weight), Size = UDim2.fromOffset(70, 30), Position = UDim2.fromOffset(196, 7), Color = C.Gold, MaxText = 20 })
		local d = UITheme.Label(r, { Text = race.Desc, Size = UDim2.new(1, -290, 1, -8), Position = UDim2.fromOffset(276, 4), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 14, StrokeThickness = 1 })
		d.TextWrapped = true
	end
	local tierRow = rowFrame(odds, 40, 99, Color3.fromRGB(30, 26, 44))
	local parts = {}
	for _, t in ipairs(Config.RaceTiers) do
		table.insert(parts, string.format('<font color="%s">%s %s</font>', hex(t.Color), t.Label or t.Id, Format.Percent(t.Weight)))
	end
	UITheme.Label(tierRow, { Text = "Skin tiers: " .. table.concat(parts, "  "), Rich = true, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), MaxText = 16 })
	p.Refresh = function(d)
		local race = Config.RaceById[d.Race]
		local tier = Config.RaceTierById[d.RaceTier]
		raceName.Text = race and race.Name or "Unrolled"
		raceName.TextColor3 = race and race.Color or C.Text
		tierName.Text = tier and ((tier.Label or tier.Id) .. " skin") or ""
		tierName.TextColor3 = tier and tier.Color or C.Sub
		desc.Text = race and race.Desc or "Roll to awaken your bloodline!"
		rerolls.Text = "Rerolls: " .. d.Rerolls
	end
end

local function buildBackpack()
	local p = makePanel("Backpack", "ORE BAG", Vector2.new(660, 480), C.Gold)
	local items = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -96) })
	list(items, 6)
	local footer = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 0, 86), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1) })
	local capBg = frame(footer, { Color = Color3.fromRGB(12, 10, 20), Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.fromOffset(0, 8), Corner = 8, Stroke = 2 })
	local capFill = frame(capBg, { Color = C.Gold, Size = UDim2.fromScale(0, 1), Corner = 8 })
	UITheme.Gradient(capFill, Color3.new(1, 1, 1), Color3.fromRGB(200, 150, 60), 90)
	local capText = UITheme.Label(capBg, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 18 })
	local hint = UITheme.Label(footer, { Text = "", Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.fromOffset(0, 44), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	hint.TextWrapped = true
	local actionBtn = UITheme.Button(footer, {
		Text = "SELL ALL",
		Color = "Gold",
		Size = UDim2.fromOffset(250, 72),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		MaxText = 28,
		OnClick = function()
			request("Sell")
		end,
	})
	p.Refresh = function(d)
		local mode = p.Mode == "Sell" and "Sell" or "View"
		local sigParts = { mode, d.BackpackMax, math.floor(d.Derived.CoinMult * 100) }
		for _, ore in ipairs(Config.Ores) do
			table.insert(sigParts, d.Backpack[ore.Id] or 0)
		end
		local sig = table.concat(sigParts, ",")
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		clearList(items)
		local any = false
		for i, ore in ipairs(Config.Ores) do
			local count = d.Backpack[ore.Id] or 0
			if count > 0 then
				any = true
				local r = rowFrame(items, 64, i)
				accentBar(r, Config.Rarity[ore.Rarity].Color)
				local gem = frame(r, { Color = ore.Color, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(34, 32), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2 })
				gem.Rotation = 45
				UITheme.Label(r, { Text = ore.Name .. "  x" .. Format.Commas(count), Title = true, Size = UDim2.fromOffset(260, 26), Position = UDim2.fromOffset(62, 6), XAlign = Enum.TextXAlignment.Left, Color = ore.Color, MaxText = 22 })
				local eff = Config.Effects[ore.Effect]
				UITheme.Label(r, { Text = Config.Rarity[ore.Rarity].Label .. "  -  forges " .. Config.EffectText(ore.Effect, ore.Points), Size = UDim2.new(1, -250, 0, 22), Position = UDim2.fromOffset(62, 34), XAlign = Enum.TextXAlignment.Left, Color = eff and eff.Color or C.Sub, MaxText = 15 })
				if mode == "Sell" then
					UITheme.Label(r, { Text = "+" .. Format.Abbrev(ore.Sell * count * d.Derived.CoinMult), Size = UDim2.fromOffset(90, 30), Position = UDim2.new(1, -130, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Gold, MaxText = 20 })
					UITheme.Button(r, {
						Text = "Sell",
						Color = "Gold",
						Size = UDim2.fromOffset(110, 46),
						Position = UDim2.new(1, -10, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						OnClick = function()
							request("Sell", ore.Id)
						end,
					})
				end
			end
		end
		if not any then
			local r = rowFrame(items, 60, 1)
			UITheme.Label(r, { Text = "Your bag is empty. Fight down the Path and press F on dropped ore to pick it up!", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Color = C.Sub, MaxText = 17 })
		end
		capFill.Size = UDim2.fromScale(math.clamp(d.BackpackCount / math.max(1, d.BackpackMax), 0, 1), 1)
		capText.Text = Format.Abbrev(d.BackpackCount) .. " / " .. Format.Abbrev(d.BackpackMax) .. " ores"
		actionBtn.Visible = mode == "Sell"
		hint.Text = mode == "Sell" and "Keep rare ore for the Soul Forge - every ore stamps an effect on your weapon!" or "Forge ore into weapons at the Soul Forge, sell it at the stall. Upgrade the bag for more slots."
	end
end

-- Ore Index: every ore starts LOCKED. Picking one up marks it FOUND; click
-- the glowing card to unlock it, reveal its effect and claim the coins.
local function firstFloorFor(ore): number
	return math.max(1, 5 * (ore.Order - 3) + 1)
end

local function buildIndex()
	local p = makePanel("Index", "ORE INDEX", Vector2.new(720, 500), C.Cyan)
	local grid = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -34) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(160, 150)
	g.CellPadding = UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = grid
	local footer = UITheme.Label(p.Body, { Text = "", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Gold, MaxText = 16 })
	p.Refresh = function(d)
		local sigParts = {}
		for _, ore in ipairs(Config.Ores) do
			table.insert(sigParts, d.Index[ore.Id] and "U" or ((d.IndexFound or {})[ore.Id] and "F" or "L"))
		end
		local sig = table.concat(sigParts)
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		clearList(grid)
		local unlocked, waiting = 0, 0
		for i, ore in ipairs(Config.Ores) do
			local known = d.Index[ore.Id] == true
			local found = not known and (d.IndexFound or {})[ore.Id] == true
			if known then
				unlocked += 1
			elseif found then
				waiting += 1
			end
			local rarity = Config.Rarity[ore.Rarity]
			local eff = Config.Effects[ore.Effect]
			local card = frame(grid, { Color = known and C.Row or Color3.fromRGB(14, 12, 20), Order = i, Corner = 10 })
			local st = UITheme.Stroke(card, (known or found) and 2 or 1, (known or found) and rarity.Color or C.Line, true)
			st.Transparency = (known or found) and 0.1 or 0.6
			local gem = frame(card, { Color = known and ore.Color or (found and rarity.Color or Color3.fromRGB(40, 38, 50)), Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2 })
			gem.Rotation = 45
			if found then
				gem.BackgroundTransparency = 0.4
				local q = UITheme.Label(card, { Text = "?", Title = true, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0.5), MaxText = 24 })
				q.ZIndex = 3
			end
			if known then
				UITheme.Label(card, { Text = ore.Name, Title = true, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 56), Color = ore.Color, MaxText = 17 })
				UITheme.Label(card, { Text = rarity.Label, Size = UDim2.new(1, -10, 0, 15), Position = UDim2.fromOffset(5, 76), Color = rarity.Color, MaxText = 13 })
				local t = UITheme.Label(card, { Text = Config.EffectText(ore.Effect, ore.Points), Size = UDim2.new(1, -12, 0, 50), Position = UDim2.fromOffset(6, 94), Color = eff and eff.Color or C.Text, MaxText = 12, StrokeThickness = 1 })
				t.TextWrapped = true
			elseif found then
				UITheme.Label(card, { Text = "NEW ORE FOUND!", Title = true, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 58), Color = rarity.Color, MaxText = 15 })
				local btn = UITheme.Button(card, { Text = "UNLOCK +" .. Format.Abbrev(Config.IndexReward[ore.Rarity]), Color = "Gold", Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), MaxText = 15, Corner = 8, Sound = "Discover", OnClick = function()
					request("UnlockIndex", ore.Id)
				end })
				local pulse = btn:FindFirstChildOfClass("UIScale")
				if pulse then
					task.spawn(function()
						while btn.Parent do
							tween(pulse, 0.5, { Scale = 1.05 })
							task.wait(0.5)
							tween(pulse, 0.5, { Scale = 1 })
							task.wait(0.5)
						end
					end)
				end
			else
				UITheme.Label(card, { Text = "LOCKED", Title = true, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 58), Color = C.Sub, MaxText = 16 })
				UITheme.Label(card, { Text = rarity.Label .. " ore", Size = UDim2.new(1, -10, 0, 15), Position = UDim2.fromOffset(5, 80), Color = rarity.Color, MaxText = 13 })
				local hint = UITheme.Label(card, { Text = "Drops from floor " .. firstFloorFor(ore) .. "+", Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 100), Color = C.Sub, MaxText = 12 })
				hint.TextWrapped = true
			end
		end
		footer.Text = string.format("Unlocked %d / %d ores%s", unlocked, #Config.Ores, waiting > 0 and ("  -  " .. waiting .. " waiting to be unlocked!") or "")
	end
end

local function buildShop()
	local p = makePanel("Shop", "SHOP", Vector2.new(720, 500), C.Green)
	local tabs = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 0, 48) })
	list(tabs, 10, true)
	local pages = {}
	local function showTab(name)
		for n, page in pairs(pages) do
			page.Visible = n == name
		end
	end
	for i, name in ipairs({ "Passes", "Items", "Codes" }) do
		UITheme.Button(tabs, { Text = name, Color = i == 1 and "Green" or (i == 2 and "Blue" or "Purple"), Size = UDim2.fromOffset(150, 44), Order = i, OnClick = function()
			showTab(name)
		end })
		local page = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 56) })
		page.Visible = i == 1
		pages[name] = page
	end
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(210, 150)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = pages.Passes
	local passButtons = {}
	for i, key in ipairs(Config.GamePassOrder) do
		local pass = Config.GamePasses[key]
		local card = frame(pages.Passes, { Color = Color3.fromRGB(36, 30, 60), Order = i, Corner = 14, Stroke = 3 })
		UITheme.Label(card, { Text = pass.Name, Title = true, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 6), Color = C.Gold, MaxText = 22 })
		local d = UITheme.Label(card, { Text = pass.Desc, Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 38), Color = C.Sub, MaxText = 15, StrokeThickness = 1 })
		d.TextWrapped = true
		passButtons[key] = UITheme.Button(card, { Text = "Buy", Color = "Green", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), OnClick = function()
			request("BuyPass", key)
		end })
	end
	local g2 = g:Clone()
	g2.Parent = pages.Items
	for i, key in ipairs(Config.ProductOrder) do
		local prod = Config.Products[key]
		local card = frame(pages.Items, { Color = Color3.fromRGB(30, 36, 64), Order = i, Corner = 14, Stroke = 3 })
		UITheme.Label(card, { Text = prod.Name, Title = true, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.fromOffset(6, 6), Color = C.Blue, MaxText = 22 })
		local contents = {}
		if prod.Coins then
			table.insert(contents, Format.Abbrev(prod.Coins) .. " Coins" .. (prod.ScaleWithRebirth and " (x rebirths)" or ""))
		end
		if prod.Rerolls then
			table.insert(contents, prod.Rerolls .. " Race Rerolls")
		end
		if prod.Overdrive then
			table.insert(contents, prod.Overdrive .. " Overdrive")
		end
		local d = UITheme.Label(card, { Text = table.concat(contents, "\n"), Size = UDim2.new(1, -16, 0, 54), Position = UDim2.fromOffset(8, 38), Color = C.Sub, MaxText = 15, StrokeThickness = 1 })
		d.TextWrapped = true
		UITheme.Button(card, { Text = "Buy", Color = "Blue", Size = UDim2.new(1, -24, 0, 44), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), OnClick = function()
			request("BuyProduct", key)
		end })
	end
	-- codes
	local codeRow = rowFrame(pages.Codes, 140, 1)
	UITheme.Label(codeRow, { Text = "Enter a code for free rewards!", Title = true, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), MaxText = 26 })
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.62, 0, 0, 54)
	box.Position = UDim2.fromOffset(14, 62)
	box.BackgroundColor3 = Color3.fromRGB(16, 12, 26)
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = "Type code here..."
	box.PlaceholderColor3 = C.Sub
	box.Font = UITheme.BodyFont
	box.TextScaled = true
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = codeRow
	UITheme.Corner(box, 10)
	UITheme.Stroke(box, 2, nil, true)
	UITheme.Button(codeRow, { Text = "REDEEM", Color = "Purple", Size = UDim2.new(0.33, -20, 0, 54), Position = UDim2.new(1, -14, 0, 62), AnchorPoint = Vector2.new(1, 0), OnClick = function()
		request("Redeem", box.Text)
		box.Text = ""
	end })
	list(pages.Codes, 8)
	p.Refresh = function(d)
		for key, btn in pairs(passButtons) do
			local owned = d.Passes[key] == true
			UITheme.SetButtonText(btn, owned and "OWNED" or "Buy")
		end
	end
end

local function buildTeleport()
	local p = makePanel("Teleport", "TRAVEL", Vector2.new(560, 330), C.Cyan)
	UITheme.Label(p.Body, { Text = "Travelling ends a dungeon run.", Size = UDim2.new(1, 0, 0, 22), Color = C.Sub, MaxText = 15 })
	local grid = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 1, -30), Position = UDim2.fromOffset(0, 30) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(240, 64)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = grid
	for i, d in ipairs({ { "Spawn", "Hub", "Green" }, { "Dungeon Gate", "Dungeon", "Purple" }, { "Training", "Train", "Blue" }, { "Boss Rush", "Tower", "Red" } }) do
		UITheme.Button(grid, { Text = d[1], Color = d[3], Order = i, MaxText = 22, Sound = "Teleport", OnClick = function()
			request("Teleport", d[2])
			UI.Close()
		end })
	end
end

-- Dungeon: pick a start floor (floor 1 or an unlocked checkpoint).
local function buildDungeon()
	local p = makePanel("Dungeon", "THE DUNGEON", Vector2.new(640, 470), C.Purple)
	local info = rowFrame(p.Body, 96, 0)
	accentBar(info, C.Purple)
	local best = UITheme.Label(info, { Text = "", Title = true, Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(18, 8), XAlign = Enum.TextXAlignment.Left, Color = C.Purple, MaxText = 26 })
	local rules = UITheme.Label(info, { Text = "", Rich = true, Size = UDim2.new(1, -30, 0, 50), Position = UDim2.fromOffset(18, 40), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 14 })
	rules.TextWrapped = true
	rules.TextYAlignment = Enum.TextYAlignment.Top
	UITheme.Label(p.Body, { Text = "START FROM", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 104), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	local grid = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -196), Position = UDim2.fromOffset(0, 126) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(190, 58)
	g.CellPadding = UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = grid
	local footer = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1) })
	local runLabel = UITheme.Label(footer, { Text = "", Size = UDim2.new(0.6, 0, 1, 0), XAlign = Enum.TextXAlignment.Left, Color = C.Gold, MaxText = 17 })
	local actionBtn = UITheme.Button(footer, { Text = "GO TO GATE", Color = "Blue", Size = UDim2.fromOffset(220, 54), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 20, OnClick = function()
		local d = UI.Data
		if d and d.Run then
			request("Teleport", "Hub")
		else
			request("Teleport", "Dungeon")
		end
		UI.Close()
	end })
	p.Refresh = function(d)
		local D = Config.Dungeon
		local bestFloor = d.BestFloor or 0
		best.Text = "DEEPEST FLOOR: " .. bestFloor
		local cps = d.Checkpoints or { 1 }
		local last = cps[#cps]
		local lockedCp = last == 1 and D.CheckpointEvery or last + D.CheckpointEvery
		rules.Text = string.format('Clear each room to open the next door. <font color="#ff5a6e">Boss every %d floors.</font> Dying or going HOME ends the run.\nNext checkpoint: <font color="#ffc432">start at floor %d</font> once you reach floor %d.', D.BossEvery, lockedCp, lockedCp + D.CheckpointEvery)
		local sig = table.concat(d.Checkpoints or { 1 }, ",") .. (d.Run and ("R" .. d.Run.Floor) or "")
		if d.Run then
			runLabel.Text = "In a run: floor " .. d.Run.Floor .. " (started at " .. d.Run.Start .. ")"
			UITheme.SetButtonText(actionBtn, "END RUN (HOME)")
		else
			runLabel.Text = ""
			UITheme.SetButtonText(actionBtn, "GO TO GATE")
		end
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		clearList(grid)
		for i, f in ipairs(cps) do
			UITheme.Button(grid, { Text = "FLOOR " .. f, Color = f == 1 and "Green" or "Purple", Order = i, MaxText = 20, Sound = "Teleport", OnClick = function()
				request("DungeonStart", f)
				UI.Close()
			end })
		end
		-- the next locked checkpoint, as a teaser
		UITheme.Button(grid, { Text = "FLOOR " .. lockedCp .. " (reach " .. (lockedCp + D.CheckpointEvery) .. ")", Color = "Red", Order = 999, MaxText = 15, OnClick = function()
			UI.Notify("Reach floor " .. (lockedCp + D.CheckpointEvery) .. " to unlock this checkpoint.", C.Red)
		end })
	end
end

-- Skill mastery per weapon type.
local function buildMastery()
	local p = makePanel("Mastery", "SKILL MASTERY", Vector2.new(680, 500), C.Gold)
	local legend = rowFrame(p.Body, 64, 0)
	accentBar(legend, C.Gold)
	local parts = {}
	for _, m in ipairs(Config.Mastery.Milestones) do
		table.insert(parts, string.format('<font color="#ffc432">Lv %d %s</font>: %s', m.Level, m.Name, m.Desc))
	end
	local lt = UITheme.Label(legend, { Text = "Use E / R skills and get kills with a weapon type to level it. +3% skill damage per level.\n" .. table.concat(parts, "   "), Rich = true, Size = UDim2.new(1, -30, 1, -10), Position = UDim2.fromOffset(18, 5), XAlign = Enum.TextXAlignment.Left, MaxText = 13, StrokeThickness = 1 })
	lt.TextWrapped = true
	local listFrame = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -72), Position = UDim2.fromOffset(0, 72) })
	list(listFrame, 5)
	p.Refresh = function(d)
		local cur = player:GetAttribute("WeaponClass")
		local sigParts = { tostring(cur) }
		for _, cls in ipairs(Config.ClassOrder) do
			table.insert(sigParts, math.floor((d.Mastery or {})[cls] or 0))
		end
		local sig = table.concat(sigParts, ",")
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		clearList(listFrame)
		for i, cls in ipairs(Config.ClassOrder) do
			local xp = (d.Mastery or {})[cls] or 0
			local level, into, need = Config.MasteryLevel(xp)
			local r = rowFrame(listFrame, 44, (cls == cur) and 0 or i, cls == cur and Color3.fromRGB(44, 38, 20) or nil)
			accentBar(r, cls == cur and C.Gold or C.Line)
			UITheme.Label(r, { Text = cls .. (cls == cur and "  (equipped)" or ""), Title = true, Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(18, 4), XAlign = Enum.TextXAlignment.Left, Color = cls == cur and C.Gold or C.Text, MaxText = 17 })
			local title = "Novice"
			for _, m in ipairs(Config.Mastery.Milestones) do
				if level >= m.Level then
					title = m.Name
				end
			end
			UITheme.Label(r, { Text = "Lv " .. level .. "  " .. title, Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(18, 25), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 13 })
			local barBg = frame(r, { Color = Color3.fromRGB(12, 10, 20), Size = UDim2.new(1, -250, 0, 14), Position = UDim2.new(0, 230, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Corner = 7 })
			local fill = frame(barBg, { Color = C.Gold, Size = UDim2.fromScale(need > 0 and math.clamp(into / need, 0, 1) or 1, 1), Corner = 7 })
			fill.Name = "Fill"
			UITheme.Label(barBg, { Text = need > 0 and (Format.Abbrev(into) .. " / " .. Format.Abbrev(need) .. " xp") or "MAX", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 11, StrokeThickness = 1 })
		end
	end
end

local function buildRebirth()
	local p = makePanel("Rebirth", "REBIRTH & ASCEND", Vector2.new(660, 520), C.Gold)
	local function card(order: number, color: Color3, y: number)
		local r = rowFrame(p.Body, 222, order)
		r.Position = UDim2.fromOffset(0, y)
		accentBar(r, color)
		local title = UITheme.Label(r, { Text = "", Title = true, Size = UDim2.new(1, -250, 0, 38), Position = UDim2.fromOffset(20, 8), XAlign = Enum.TextXAlignment.Left, Color = color, MaxText = 32 })
		local barBg = frame(r, { Color = Color3.fromRGB(12, 10, 20), Size = UDim2.new(1, -250, 0, 28), Position = UDim2.fromOffset(20, 52), Corner = 8, Stroke = 2 })
		local fill = frame(barBg, { Color = color, Size = UDim2.fromScale(0, 1), Corner = 8 })
		UITheme.Gradient(fill, Color3.new(1, 1, 1), color:Lerp(Color3.new(0, 0, 0), 0.35), 90)
		local barText = UITheme.Label(barBg, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 17 })
		local info = UITheme.Label(r, { Text = "", Rich = true, Size = UDim2.new(1, -250, 0, 120), Position = UDim2.fromOffset(20, 90), XAlign = Enum.TextXAlignment.Left, MaxText = 16 })
		info.TextWrapped = true
		info.TextYAlignment = Enum.TextYAlignment.Top
		return r, title, fill, barText, info
	end
	local reb, rebTitle, rebFill, rebBar, rebInfo = card(1, C.Gold, 0)
	local rebBtn = UITheme.Button(reb, { Text = "REBIRTH", Color = "Gold", Size = UDim2.fromOffset(200, 72), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 30, OnClick = function()
		request("Rebirth")
	end })
	local asc, ascTitle, ascFill, ascBar, ascInfo = card(2, C.Pink, 234)
	local ascBtn = UITheme.Button(asc, { Text = "ASCEND", Color = "Purple", Size = UDim2.fromOffset(200, 72), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 30, OnClick = function()
		request("Ascend")
	end })
	p.Refresh = function(d)
		local R, A = Config.Rebirth, Config.Ascension
		local powerNow = R.PowerMult ^ d.Rebirths * A.PowerMult ^ d.Ascensions
		local coinsNow = R.CoinMult ^ d.Rebirths * A.CoinMult ^ d.Ascensions
		rebTitle.Text = "REBIRTH  #" .. Format.Abbrev(d.Rebirths + 1)
		local rp = math.clamp(d.Power / math.max(1, d.RebirthReq), 0, 1)
		rebFill.Size = UDim2.fromScale(rp, 1)
		rebBar.Text = Format.Abbrev(d.Power) .. " / " .. Format.Abbrev(d.RebirthReq) .. " Power"
		rebInfo.Text = string.format(
			'<font color="#78ff9c">Power x%s</font> (x%s -> x%s)\n<font color="#ffd75a">Coins x%s</font> (x%s -> x%s)\n+%d Race Reroll\n<font color="#ff7a7a">Resets Power and Coins.</font>',
			tostring(R.PowerMult), Format.Abbrev(powerNow), Format.Abbrev(powerNow * R.PowerMult),
			tostring(R.CoinMult), Format.Abbrev(coinsNow), Format.Abbrev(coinsNow * R.CoinMult),
			R.RerollReward
		)
		UITheme.SetButtonText(rebBtn, rp >= 1 and "REBIRTH!" or (math.floor(rp * 100) .. "%"))
		ascTitle.Text = "ASCENSION  " .. (d.Ascensions > 0 and ("#" .. (d.Ascensions + 1)) or "I")
		local ap = math.clamp(d.Rebirths / math.max(1, d.AscendReq), 0, 1)
		ascFill.Size = UDim2.fromScale(ap, 1)
		ascBar.Text = d.Rebirths .. " / " .. d.AscendReq .. " Rebirths"
		ascInfo.Text = string.format(
			'<font color="#78ff9c">Power x%s</font>  <font color="#ffd75a">Coins x%s</font> (forever)\n+%d Rerolls, +1 %s\nUnlocks higher Training pads\n<font color="#ff7a7a">Resets Rebirths, Power and Coins.</font>',
			tostring(A.PowerMult), tostring(A.CoinMult), A.Rerolls, Config.KeyNames[A.Catalyst] or "Catalyst"
		)
		UITheme.SetButtonText(ascBtn, ap >= 1 and "ASCEND!" or (math.floor(ap * 100) .. "%"))
	end
end

local function buildSettings()
	local p = makePanel("Settings", "SETTINGS", Vector2.new(480, 440), Color3.fromRGB(150, 150, 170))
	local holder = frame(p.Body, { Transparency = 1 })
	list(holder, 10)
	local KEYS = { { "Music", "Music" }, { "SFX", "Sound effects" }, { "AutoEquip", "Auto-equip forged weapons" }, { "Shake", "Screen shake" }, { "DamageNumbers", "Damage numbers" } }
	local state = { Music = true, SFX = true, AutoEquip = true, Shake = true, DamageNumbers = true }
	local buttons = {}
	local function apply()
		SFX.SetMusicVolume(state.Music and 0.3 or 0)
		SFX.SetSFXVolume(state.SFX and 0.55 or 0)
		VFX.Settings.Shake = state.Shake
		VFX.Settings.DamageNumbers = state.DamageNumbers
		for _, k in ipairs(KEYS) do
			local btn = buttons[k[1]]
			UITheme.SetButtonText(btn, k[2] .. ": " .. (state[k[1]] and "ON" or "OFF"))
		end
	end
	for i, k in ipairs(KEYS) do
		buttons[k[1]] = UITheme.Button(holder, { Text = k[2], Color = "Blue", Size = UDim2.fromOffset(380, 52), Order = i, MaxText = 20, OnClick = function()
			state[k[1]] = not state[k[1]]
			apply()
			request("Settings", state)
		end })
	end
	UITheme.Label(holder, { Text = Config.GameName, Title = true, Size = UDim2.fromOffset(320, 26), Order = 99, Color = C.Pink, MaxText = 20 })
	p.Refresh = function(d)
		if d.Settings then
			for _, k in ipairs(KEYS) do
				state[k[1]] = d.Settings[k[1]] ~= false
			end
		end
		apply()
	end
	UI.ApplySettings = function(d)
		p.Refresh(d)
	end
end

---------------------------------------------------------------------
-- RACE ROLL (slot machine)
---------------------------------------------------------------------
function UI.RaceRoll(raceId: string, tierId: string, initial: boolean?)
	local race = Config.RaceById[raceId]
	local tier = Config.RaceTierById[tierId]
	if not race or not tier then
		return
	end
	UI.Close()
	local overlay = frame(flyGui, { Color = Color3.new(0, 0, 0), Transparency = 1, ZIndex = 60 })
	tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
	local card = frame(overlay, { Color = Color3.fromRGB(26, 20, 44), Size = UDim2.fromOffset(520, 240), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 22, Stroke = 5, ZIndex = 61 })
	local sc = Instance.new("UIScale")
	sc.Scale = math.clamp(math.min(workspace.CurrentCamera.ViewportSize.X / 1400, workspace.CurrentCamera.ViewportSize.Y / 820), 0.55, 1.1)
	sc.Parent = card
	UITheme.Label(card, { Text = initial and "AWAKENING YOUR BLOODLINE..." or "ROLLING RACE...", Title = true, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 12), Color = C.Sub, ZIndex = 62, MaxText = 28 })
	local nameLabel = UITheme.Label(card, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 90), Position = UDim2.fromOffset(10, 64), ZIndex = 62, MaxText = 70, StrokeThickness = 4 })
	local tierLabel = UITheme.Label(card, { Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 160), ZIndex = 62, MaxText = 28 })
	local stroke = card:FindFirstChildOfClass("UIStroke")

	task.spawn(function()
		local steps = 26
		for i = 1, steps do
			local r = Config.Races[math.random(1, #Config.Races)]
			nameLabel.Text = r.Name
			nameLabel.TextColor3 = r.Color
			if stroke then
				stroke.Color = r.Color
			end
			SFX.Play("RaceTick", { Pitch = 0.8 + i / steps })
			task.wait(0.03 + (i / steps) ^ 3 * 0.22)
		end
		nameLabel.Text = race.Name
		nameLabel.TextColor3 = race.Color
		tierLabel.Text = (tier.Label or tier.Id) .. " skin"
		tierLabel.TextColor3 = tier.Color
		if stroke then
			stroke.Color = race.Color
		end
		local s2 = Instance.new("UIScale")
		s2.Scale = 1.5
		s2.Parent = nameLabel
		tween(s2, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		local legendary = race.Weight <= 7 or tier.Id == "Legendary" or tier.Id == "Mythic"
		if legendary then
			SFX.Play("RaceRevealLegend")
			VFX.ImpactFrame(race.Color, 1.3)
			VFX.TitleCard(race.Name:upper() .. "!", (tier.Label or tier.Id) .. " skin  -  " .. Format.Percent(race.Weight) .. " chance", race.Color, 2)
		else
			SFX.Play("RaceReveal")
			VFX.ScreenFlash(race.Color, 0.4, 0.4)
		end
		task.wait(legendary and 2.4 or 1.6)
		tween(overlay, 0.3, { BackgroundTransparency = 1 })
		tween(sc, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		overlay:Destroy()
		UI.Notify("You are a " .. (tier.Label or tier.Id) .. " " .. race.Name .. "!", race.Color)
	end)
end

---------------------------------------------------------------------
-- STATUS WIDGETS
---------------------------------------------------------------------
function UI.SetPad(mult: number?, locked: boolean?)
	if not mult then
		padLabel.Visible = false
		return
	end
	padLabel.Visible = true
	padLabel.Text = locked and ("x" .. Format.Abbrev(mult) .. "  LOCKED - REBIRTH / ASCEND TO USE") or ("x" .. Format.Abbrev(mult) .. "  TRAINING")
	padLabel.TextColor3 = locked and C.Red or C.Green
end

local bannerToken = 0
function UI.Banner(title: string, sub: string?, color: Color3?)
	bannerToken += 1
	local my = bannerToken
	local t = zoneBanner:FindFirstChild("Title") :: TextLabel
	local s = zoneBanner:FindFirstChild("Sub") :: TextLabel
	t.Text = title
	t.TextColor3 = color or C.Text
	s.Text = sub or ""
	zoneBanner.Visible = true
	zoneBanner.Position = UDim2.new(0.5, 0, 0, 150)
	t.TextTransparency = 1
	s.TextTransparency = 1
	tween(t, 0.4, { TextTransparency = 0 })
	tween(s, 0.4, { TextTransparency = 0 })
	tween(zoneBanner, 0.5, { Position = UDim2.new(0.5, 0, 0, 170) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if bannerToken == my then
			tween(t, 0.5, { TextTransparency = 1 })
			tween(s, 0.5, { TextTransparency = 1 }).Completed:Once(function()
				if bannerToken == my then
					zoneBanner.Visible = false
				end
			end)
		end
	end)
end

function UI.Tower(state: string?, wave: number?, endsAt: number?)
	if not state then
		towerHud.Visible = false
		return
	end
	towerHud.Visible = true
	towerHud:SetAttribute("EndsAt", endsAt or 0)
	towerHud:SetAttribute("Floor", wave or 1)
	local title = towerHud:FindFirstChild("Title") :: TextLabel
	title.Text = "BOSS RUSH  -  WAVE " .. tostring(wave or 1)
end

local function refreshStageHud(d)
	local run = d and d.Run
	if not run or towerHud.Visible then
		stageHud.Visible = false
		return
	end
	stageHud.Visible = true
	local fd = Config.Floor(run.Floor)
	local zone = fd.ZoneData
	local title = stageHud:FindFirstChild("Title") :: TextLabel
	local count = stageHud:FindFirstChild("Count") :: TextLabel
	local fill = (stageHud:FindFirstChild("Bar") :: Frame):FindFirstChild("Fill") :: Frame
	title.Text = (fd.Boss and "BOSS FLOOR " or "FLOOR ") .. run.Floor .. "  " .. zone.Name:upper()
	title.TextColor3 = fd.Boss and C.Red or zone.Accent
	fill.BackgroundColor3 = fd.Boss and C.Red or zone.Accent
	if run.State == "Fighting" then
		local kills = math.min(run.Kills or 0, run.Need)
		count.Text = fd.Boss and "SLAY THE BOSS" or (kills .. " / " .. run.Need .. " KOs")
		count.TextColor3 = C.Gold
		fill.Size = UDim2.fromScale(math.clamp(kills / math.max(1, run.Need), 0, 1), 1)
	else
		count.Text = "ENTER THE ROOM"
		count.TextColor3 = C.Sub
		fill.Size = UDim2.fromScale(0, 1)
	end
end

-- Small end-of-run card (death / HOME).
function UI.RunSummary(p)
	local fly = flyGui
	local card = frame(fly, { Color = Color3.fromRGB(10, 8, 18), Transparency = 0.15, Size = UDim2.fromOffset(300, 118), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0), Corner = 10, ZIndex = 50 })
	local st = UITheme.Stroke(card, 1.5, p.Reason == "Died" and C.Red or C.Purple, true)
	st.Transparency = 0.2
	local reason = p.Reason == "Died" and "YOU FELL" or (p.Reason == "Home" and "RUN ENDED" or "RUN OVER")
	softLabel(card, { Text = reason, Font = Config.Fonts.Display, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6), Color = p.Reason == "Died" and C.Red or C.Purple, MaxText = 22, ZIndex = 51 })
	softLabel(card, { Text = string.format("Reached floor %d  -  cleared %d  -  +%s coins", p.Reached or 1, p.Cleared or 0, Format.Abbrev(p.Coins or 0)), Font = Config.Fonts.Body, Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 34), MaxText = 14, ZIndex = 51 })
	local cps = p.Checkpoints or { 1 }
	softLabel(card, { Text = "Deepest: " .. (p.Best or 0) .. "  -  next run can start at floor " .. cps[#cps], Font = Config.Fonts.Body, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 54), Color = C.Sub, MaxText = 13, ZIndex = 51 })
	UITheme.Button(card, { Text = "BACK TO THE GATE", Color = "Purple", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), MaxText = 16, Corner = 8, ZIndex = 52, OnClick = function()
		request("Teleport", "Dungeon")
		card:Destroy()
	end })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.7
	sc.Parent = card
	tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(7, function()
		if card.Parent then
			tween(sc, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(card, 0.25)
		end
	end)
end

local eventSig = ""
local function refreshEvents(d)
	local keys = {}
	for key in pairs(d.Events or {}) do
		table.insert(keys, key)
	end
	table.sort(keys)
	local sig = table.concat(keys, ",")
	if sig == eventSig then
		return
	end
	eventSig = sig
	clearList(eventRow)
	for i, key in ipairs(keys) do
		local e = Config.Events[key]
		if e then
			local chip = frame(eventRow, { Name = key, Color = e.Color, Transparency = 0.1, Size = UDim2.fromOffset(150, 24), Order = i, Corner = 6, Stroke = 1.5 })
			UITheme.Gradient(chip, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)
			softLabel(chip, { Name = "Label", Text = e.Name, Font = Config.Fonts.Display, Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), MaxText = 17 })
		end
	end
end

---------------------------------------------------------------------
-- UPDATE
---------------------------------------------------------------------
function UI.Update(d)
	local first = UI.Data == nil
	UI.Data = d
	animateNumber("Power", pills.Power.Value, d.Power, Format.Abbrev)
	local ready = d.Power >= d.RebirthReq
	pills.Power.Sub.Text = "REBIRTH!"
	pills.Power.Sub.Visible = ready
	animateNumber("Coins", pills.Coins.Value, d.Coins, Format.Abbrev)
	pills.Backpack.Value.Text = Format.Abbrev(d.BackpackCount) .. "/" .. Format.Abbrev(d.BackpackMax)
	local full = d.BackpackCount >= d.BackpackMax
	pills.Backpack.Sub.Text = "FULL"
	pills.Backpack.Sub.TextColor3 = C.Red
	pills.Backpack.Sub.Visible = full
	adminButton.Visible = d.IsAdmin == true

	local now = { Power = d.Power, Coins = d.Coins, Backpack = d.BackpackCount }
	for key, v in pairs(now) do
		if not first and prevValues[key] ~= nil and prevValues[key] ~= v then
			UI.Reveal(key)
		end
		prevValues[key] = v
	end
	refreshEvents(d)

	if current and current.Refresh then
		current.Refresh(d)
	end
	if first and UI.ApplySettings then
		UI.ApplySettings(d)
	end
end

-- Called every frame by the client (timers + contextual fades).
local stageTick = 0
function UI.Tick(dt: number)
	local now = workspace:GetServerTimeNow()
	if towerHud.Visible then
		local endsAt = towerHud:GetAttribute("EndsAt") or 0
		local timer = towerHud:FindFirstChild("Timer") :: TextLabel
		local left = endsAt - now
		if endsAt > 0 and left > 0 then
			timer.Text = Format.Time(left)
			timer.TextColor3 = left < 8 and C.Red or C.Text
		else
			timer.Text = "--:--"
		end
	end
	stageTick += dt
	if stageTick > 0.2 then
		stageTick = 0
		refreshStageHud(UI.Data)
		local events = UI.Data and UI.Data.Events or {}
		for _, chip in ipairs(eventRow:GetChildren()) do
			local e = events[chip.Name]
			local label = chip:FindFirstChild("Label") :: TextLabel?
			if e and label then
				label.Text = Config.Events[chip.Name].Name .. "  " .. Format.Time(math.max(0, e.EndsAt - now))
			end
		end
	end
	local menuOpen = drawerOpen or current ~= nil
	menuHint.Visible = not menuOpen
	local t = os.clock()
	for _, p in pairs(pills) do
		local target = (p.Pinned or menuOpen or t < p.Until) and 1 or 0
		local speed = target > p.Alpha and 9 or 3
		p.Alpha += (target - p.Alpha) * math.min(1, dt * speed)
		if math.abs(target - p.Alpha) < 0.01 then
			p.Alpha = target
		end
		p.Holder.GroupTransparency = 1 - p.Alpha
		p.Holder.Visible = p.Alpha > 0.01
	end
end

-- True while the menu drawer is open: every contextual HUD group shows.
function UI.IsPeeking(): boolean
	return drawerOpen
end

function UI.IsPanelOpen(): boolean
	return current ~= nil
end

function UI.ToggleDrawer(force: boolean?)
	local open = if force == nil then not drawerOpen else force
	if open == drawerOpen then
		return
	end
	drawerOpen = open
	SFX.Play(open and "UIOpen" or "UIClose")
	if open then
		drawer.Visible = true
		drawer.Position = UDim2.new(0, DRAWER_X - 28, 0, drawer.Position.Y.Offset)
	end
	tween(drawer, 0.28, { GroupTransparency = open and 0 or 1, Position = UDim2.new(0, open and DRAWER_X or DRAWER_X - 28, 0, drawer.Position.Y.Offset) }, Enum.EasingStyle.Quart).Completed:Once(function()
		if not drawerOpen then
			drawer.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- INIT
---------------------------------------------------------------------
function UI.Init(requestFn)
	request = requestFn
	UITheme.Init()
	local pg = player:WaitForChild("PlayerGui")

	screen = Instance.new("ScreenGui")
	screen.Name = "GameUI"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = pg

	flyGui = Instance.new("ScreenGui")
	flyGui.Name = "GameUIFx"
	flyGui.ResetOnSpawn = false
	flyGui.IgnoreGuiInset = true
	flyGui.DisplayOrder = 40
	flyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	flyGui.Parent = pg

	root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Parent = screen
	uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	local inset = GuiService:GetGuiInset()
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1400, 820)
		local s = math.clamp(math.min(vp.X / 1400, vp.Y / 820), 0.5, 1.15)
		uiScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	dim = frame(root, { Color = Color3.new(0, 0, 0), Transparency = 1, ZIndex = 4 })
	dim.Name = "Dim"
	dim.Visible = false
	dim.Size = UDim2.fromScale(3, 3)
	dim.Position = UDim2.fromScale(-1, -1)
	dim.Active = true
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UI.Close()
		end
	end)

	-- compact currency stack (left): Power, Coins and the ore bag only.
	-- Clicking a pill opens the matching menu.
	local stack = frame(root, { Transparency = 1, Size = UDim2.fromOffset(140, 110), Position = UDim2.new(0, 16, 0.5, -10), AnchorPoint = Vector2.new(0, 0.5) })
	stack.Name = "Resources"
	local sl = list(stack, 5, false, Enum.HorizontalAlignment.Left)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center
	makePill(stack, "Power", "Icon_Power", Color3.fromRGB(120, 255, 170), 1, true, "Rebirth")
	makePill(stack, "Coins", "Icon_Coins", C.Gold, 2, true, "Upgrades")
	makePill(stack, "Backpack", "Icon_Backpack", Color3.fromRGB(120, 200, 255), 3, true, "Backpack")

	-- single small menu button; everything else lives in the drawer
	local menuBtn = Instance.new("TextButton")
	menuBtn.Name = "MenuButton"
	menuBtn.AutoButtonColor = false
	menuBtn.Text = ""
	menuBtn.Size = UDim2.fromOffset(40, 40)
	menuBtn.Position = UDim2.fromOffset(18, inset.Y + 10)
	menuBtn.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
	menuBtn.BackgroundTransparency = 0.35
	menuBtn.Parent = root
	UITheme.Corner(menuBtn, 10)
	local mbStroke = Instance.new("UIStroke")
	mbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mbStroke.Thickness = 1.5
	mbStroke.Color = C.Cyan
	mbStroke.Transparency = 0.55
	mbStroke.Parent = menuBtn
	for k = -1, 1 do
		local line = frame(menuBtn, { Color = Color3.new(1, 1, 1), Transparency = 0.1, Size = UDim2.fromOffset(k == 0 and 12 or 16, 2), Position = UDim2.new(0.5, 0, 0.5, k * 5), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 1 })
		line.Name = "Line"
	end
	menuBtn.MouseEnter:Connect(function()
		tween(mbStroke, 0.15, { Transparency = 0.05 })
		SFX.Play("UIHover")
	end)
	menuBtn.MouseLeave:Connect(function()
		tween(mbStroke, 0.15, { Transparency = 0.55 })
	end)
	menuBtn.Activated:Connect(function()
		UI.ToggleDrawer()
	end)

	-- "G for menus" hint: small text on the left, hidden while a menu is open
	menuHint = softLabel(root, { Name = "MenuHint", Text = "G for menus", Font = Config.Fonts.Body, Size = UDim2.fromOffset(110, 16), Position = UDim2.fromOffset(66, inset.Y + 22), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 15 })

	-- HOME: top centre, always one click back to spawn (also leaves the Boss Rush)
	local homeBtn = UITheme.Button(root, {
		Name = "Home",
		Text = "HOME",
		Color = "Blue",
		Size = UDim2.fromOffset(112, 38),
		Position = UDim2.new(0.5, 0, 0, inset.Y + 8),
		AnchorPoint = Vector2.new(0.5, 0),
		MaxText = 22,
		Corner = 8,
		Sound = "Teleport",
		OnClick = function()
			request("Teleport", "Hub")
		end,
	})
	homeBtn.ZIndex = 2

	-- floor tracker (under HOME, only during a dungeon run)
	stageHud = frame(root, { Color = Color3.fromRGB(10, 8, 18), Transparency = 0.3, Size = UDim2.fromOffset(330, 50), Position = UDim2.new(0.5, 0, 0, inset.Y + 54), AnchorPoint = Vector2.new(0.5, 0), Corner = 8 })
	stageHud.Name = "FloorTracker"
	stageHud.Visible = false
	local shStroke = UITheme.Stroke(stageHud, 1, C.Line, true)
	shStroke.Transparency = 0.3
	softLabel(stageHud, { Name = "Title", Text = "", Font = Config.Fonts.Display, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 4), XAlign = Enum.TextXAlignment.Left, MaxText = 22 })
	softLabel(stageHud, { Name = "Count", Text = "", Font = Config.Fonts.Heading, Size = UDim2.new(0.4, 0, 0, 20), Position = UDim2.new(1, -10, 0, 5), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, MaxText = 18, Color = C.Gold })
	local shBar = frame(stageHud, { Name = "Bar", Color = Color3.fromRGB(30, 26, 44), Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 32), Corner = 4 })
	local shFill = frame(shBar, { Name = "Fill", Color = C.Green, Size = UDim2.fromScale(0, 1), Corner = 4 })
	UITheme.Gradient(shFill, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)

	-- global event chips (admin abuse events), top right of HOME
	eventRow = frame(root, { Transparency = 1, Size = UDim2.fromOffset(420, 26), Position = UDim2.new(0.5, 70, 0, inset.Y + 14), AnchorPoint = Vector2.new(0, 0) })
	eventRow.Name = "Events"
	list(eventRow, 6, true, Enum.HorizontalAlignment.Left)

	-- menu drawer (slides out next to the menu button)
	drawer = Instance.new("CanvasGroup")
	drawer.Name = "Drawer"
	drawer.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
	drawer.BackgroundTransparency = 0.2
	drawer.GroupTransparency = 1
	drawer.Visible = false
	drawer.Size = UDim2.fromOffset(188, 540)
	drawer.Position = UDim2.new(0, DRAWER_X - 28, 0, inset.Y + 60)
	drawer.ZIndex = 3
	drawer.Parent = root
	UITheme.Corner(drawer, 12)
	local dStroke = Instance.new("UIStroke")
	dStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dStroke.Thickness = 1.5
	dStroke.Color = C.Cyan
	dStroke.Transparency = 0.6
	dStroke.Parent = drawer
	softLabel(drawer, { Text = "MENU [G]   MAP [M]   HOME [B]", Font = Config.Fonts.Body, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 10), Color = C.Sub, Transparency = 0.2 })
	local grid = frame(drawer, { Transparency = 1, Size = UDim2.new(1, -16, 1, -36), Position = UDim2.fromOffset(8, 30) })
	grid.Name = "Grid"
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(82, 50)
	gl.CellPadding = UDim2.fromOffset(6, 6)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local function drawerButton(label: string, icon: string, color: Color3, order: number, onClick)
		local b = Instance.new("TextButton")
		b.Name = label
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = color
		b.BackgroundTransparency = 0.9
		b.LayoutOrder = order
		b.Parent = grid
		UITheme.Corner(b, 8)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 1
		st.Color = color
		st.Transparency = 0.6
		st.Parent = b
		local tick = frame(b, { Color = color, Size = UDim2.new(0, 3, 0, 16), Position = UDim2.fromOffset(4, 6), Corner = 1 })
		tick.Name = "Tick"
		UITheme.Icon(b, icon, UDim2.fromOffset(20, 20), UDim2.new(0.5, 0, 0, 5), Vector2.new(0.5, 0))
		softLabel(b, { Text = label, Font = Config.Fonts.Heading, Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 1, -19), Color = Color3.new(1, 1, 1) })
		b.MouseEnter:Connect(function()
			tween(st, 0.12, { Transparency = 0.1 })
			tween(b, 0.12, { BackgroundTransparency = 0.75 })
			SFX.Play("UIHover")
		end)
		b.MouseLeave:Connect(function()
			tween(st, 0.12, { Transparency = 0.6 })
			tween(b, 0.12, { BackgroundTransparency = 0.9 })
		end)
		b.Activated:Connect(function()
			SFX.Play("UIClick")
			UI.ToggleDrawer(false)
			onClick()
		end)
		return b
	end
	drawerButton("Dungeon", "Icon_Tower", C.Purple, 0, function() UI.Toggle("Dungeon") end)
	drawerButton("Weapons", "Icon_Blade", C.Purple, 1, function() UI.Toggle("Weapons") end)
	drawerButton("Forge", "Icon_Blade", Color3.fromRGB(255, 140, 60), 2, function() UI.Toggle("Forge") end)
	drawerButton("Armor", "Icon_Rune", C.Cyan, 3, function() UI.Toggle("Armor") end)
	drawerButton("Map", "Icon_Teleport", C.Cyan, 4, function()
		if UI.ToggleMap then
			UI.ToggleMap()
		end
	end)
	drawerButton("Bag", "Icon_Backpack", C.Gold, 5, function() UI.Toggle("Backpack", "View") end)
	drawerButton("Upgrades", "Icon_Upgrades", C.Blue, 6, function() UI.Toggle("Upgrades") end)
	drawerButton("Rebirth", "Icon_Rebirth", C.Gold, 7, function() UI.Toggle("Rebirth") end)
	drawerButton("Race", "Icon_Race", C.Purple, 8, function() UI.Toggle("Race") end)
	drawerButton("Mastery", "Icon_Power", C.Gold, 8, function() UI.Toggle("Mastery") end)
	drawerButton("Index", "Icon_Index", C.Blue, 9, function() UI.Toggle("Index") end)
	drawerButton("Travel", "Icon_Teleport", C.Green, 10, function() UI.Toggle("Teleport") end)
	drawerButton("Shop", "Icon_Shop", C.Green, 11, function() UI.Toggle("Shop") end)
	drawerButton("Power", "Icon_Power", C.Red, 12, function() UI.Toggle("Power") end)
	drawerButton("Rewards", "Icon_Tower", C.Green, 13, function() UI.Toggle("Rewards") end)
	drawerButton("Settings", "Icon_Settings", C.Sub, 14, function() UI.Toggle("Settings") end)
	adminButton = drawerButton("Admin", "Icon_Settings", C.Red, 15, function() UI.Toggle("Admin") end)
	adminButton.Visible = false

	-- keyboard / gamepad shortcuts
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.DPadDown then
			UI.ToggleDrawer()
		elseif input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.DPadRight then
			if UI.ToggleMap then
				UI.ToggleMap()
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			request("Teleport", "Hub")
		elseif input.KeyCode == Enum.KeyCode.P and UI.Data and UI.Data.IsAdmin then
			UI.Toggle("Admin")
		end
	end)

	-- pad indicator (only while standing on a training pad)
	padLabel = softLabel(root, { Text = "", Font = Config.Fonts.Display, Size = UDim2.fromOffset(300, 24), Position = UDim2.new(0.5, 0, 0, inset.Y + 112), AnchorPoint = Vector2.new(0.5, 0), MaxText = 22 })
	padLabel.Visible = false

	-- zone banner (fades in and out on arrival)
	zoneBanner = frame(root, { Transparency = 1, Size = UDim2.fromOffset(320, 40), Position = UDim2.new(0.5, 0, 0, 170), AnchorPoint = Vector2.new(0.5, 0) })
	zoneBanner.Name = "ZoneBanner"
	zoneBanner.Visible = false
	softLabel(zoneBanner, { Name = "Title", Text = "", Font = Config.Fonts.Display, Size = UDim2.new(1, 0, 0, 22), MaxText = 22 })
	softLabel(zoneBanner, { Name = "Sub", Text = "", Font = Config.Fonts.Body, Size = UDim2.new(1, 0, 0, 13), Position = UDim2.fromOffset(0, 24), MaxText = 13, Color = C.Sub })

	-- boss rush hud (only during a run)
	towerHud = frame(root, { Color = Color3.fromRGB(10, 8, 18), Transparency = 0.3, Size = UDim2.fromOffset(330, 64), Position = UDim2.new(0.5, 0, 0, inset.Y + 54), AnchorPoint = Vector2.new(0.5, 0), Corner = 8 })
	towerHud.Name = "TowerHud"
	towerHud.Visible = false
	softLabel(towerHud, { Name = "Title", Text = "BOSS RUSH", Font = Config.Fonts.Body, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(14, 8), XAlign = Enum.TextXAlignment.Left, Color = C.Pink })
	softLabel(towerHud, { Name = "Timer", Text = "--:--", Font = Config.Fonts.Display, Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.fromOffset(14, 28), XAlign = Enum.TextXAlignment.Left })
	UITheme.Button(towerHud, { Text = "LEAVE", Color = "Red", Size = UDim2.fromOffset(96, 40), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 20, OnClick = function()
		request("TowerLeave")
	end })

	-- notifications
	toastHolder = frame(root, { Transparency = 1, Size = UDim2.fromOffset(240, 160), Position = UDim2.new(1, -12, 0, inset.Y + 56), AnchorPoint = Vector2.new(1, 0) })
	toastHolder.Name = "Toasts"
	local tl = list(toastHolder, 3)
	tl.VerticalAlignment = Enum.VerticalAlignment.Top
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastHolder.ClipsDescendants = false

	buildUpgrades()
	buildRace()
	buildBackpack()
	buildIndex()
	buildShop()
	buildTeleport()
	buildDungeon()
	buildMastery()
	buildRebirth()
	buildSettings()
end

-- Helpers for the other client UI modules (Hud, WeaponUI).
UI.Helpers = {
	Frame = frame,
	List = list,
	Scroller = scroller,
	Clear = clearList,
	Tween = tween,
	Row = rowFrame,
	Accent = accentBar,
	MakePanel = makePanel,
	Hex = hex,
	Text = softLabel,
}
function UI.Root()
	return root
end
function UI.FlyGui()
	return flyGui
end
function UI.Panel(name: string)
	return panels[name]
end

return UI
