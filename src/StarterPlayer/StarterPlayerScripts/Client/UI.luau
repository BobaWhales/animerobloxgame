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
local pills = {}
local panels = {}
local current = nil
local dim: Frame
local toastHolder: Frame
local padLabel: TextLabel
local zoneBanner: Frame
local towerHud: Frame
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
	t.Font = props.Font or Enum.Font.BuilderSansBold
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

-- Resource pills are hidden by default and fade in for a few seconds when
-- their value changes (or while the menu drawer / a panel is open).
local function makePill(parent, key: string, role: string, color: Color3, order: number)
	local holder = Instance.new("CanvasGroup")
	holder.Name = key
	holder.BackgroundTransparency = 1
	holder.GroupTransparency = 1
	holder.Visible = false
	holder.Size = UDim2.fromOffset(150, 40)
	holder.LayoutOrder = order
	holder.Parent = parent
	local f
	local src = UITheme.Find("Bar")
	if src then
		f = Instance.new("ImageLabel")
		f.Image = src.Image
		f.ScaleType = src.ScaleType
		f.SliceCenter = src.SliceCenter
		f.SliceScale = src.SliceScale
		f.ImageRectOffset = src.ImageRectOffset
		f.ImageRectSize = src.ImageRectSize
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = holder
	else
		f = frame(holder, { Color = Color3.fromRGB(10, 8, 22), Transparency = 0.4, Corner = 20 })
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 1
		st.Color = color
		st.Transparency = 0.55
		st.Parent = f
	end
	f.Name = "Pill"
	UITheme.Icon(f, role, UDim2.fromOffset(26, 26), UDim2.fromOffset(8, 7))
	local value = softLabel(f, { Name = "Value", Text = "0", Size = UDim2.new(1, -46, 0, 19), Position = UDim2.fromOffset(40, 3), XAlign = Enum.TextXAlignment.Left })
	local sub = softLabel(f, { Name = "Sub", Text = "", Font = Enum.Font.BuilderSansMedium, Size = UDim2.new(1, -46, 0, 13), Position = UDim2.fromOffset(40, 23), XAlign = Enum.TextXAlignment.Left, Color = color })
	local sc = Instance.new("UIScale")
	sc.Parent = f
	pills[key] = { Holder = holder, Frame = f, Value = value, Sub = sub, Scale = sc, Color = color, Until = 0, Alpha = 0 }
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
	local holder = frame(toastHolder, { Transparency = 1, Size = UDim2.fromOffset(340, 36) })
	local toast = frame(holder, { Color = Color3.fromRGB(8, 6, 18), Transparency = 0.45, Size = UDim2.fromScale(1, 1), Corner = 10 })
	toast.Position = UDim2.fromOffset(360, 0)
	local bar = frame(toast, { Color = color, Size = UDim2.new(0, 3, 1, -14), Position = UDim2.fromOffset(8, 7), Corner = 2 })
	bar.Name = "Bar"
	softLabel(toast, { Text = text, Size = UDim2.new(1, -30, 1, -14), Position = UDim2.fromOffset(20, 7), XAlign = Enum.TextXAlignment.Left, Color = color:Lerp(Color3.new(1, 1, 1), 0.35), MaxText = 16 })
	tween(toast, 0.35, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
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
			tween(toast, 0.35, { Position = UDim2.fromOffset(360, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(holder, 0.4)
		end
	end)
end

---------------------------------------------------------------------
-- PANEL FRAMEWORK
---------------------------------------------------------------------
local function makePanel(name: string, title: string, size: Vector2, accent: Color3)
	local panelFrame, content = UITheme.Panel(root, { Name = name, Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 5 })
	panelFrame.Visible = false
	local sc = Instance.new("UIScale")
	sc.Parent = panelFrame

	local header = frame(panelFrame, { Color = accent, Size = UDim2.new(0.6, 0, 0, 54), Position = UDim2.new(0.5, 0, 0, -22), AnchorPoint = Vector2.new(0.5, 0), Corner = 16, Stroke = 4 })
	header.Name = "Header"
	UITheme.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)
	UITheme.Label(header, { Text = title, Title = true, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), MaxText = 34, StrokeThickness = 3 })

	UITheme.Button(panelFrame, {
		Name = "Close",
		Text = "X",
		Color = "Red",
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, 10, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		MaxText = 30,
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

	local panel = { Frame = panelFrame, Body = body, Scale = sc, Mode = nil, Sig = nil, Refresh = nil }
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
	local f = frame(parent, { Color = color or Color3.fromRGB(34, 28, 56), Transparency = 0.1, Size = UDim2.new(1, 0, 0, height), Order = order, Corner = 12, Stroke = 2 })
	UITheme.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(190, 185, 210), 90)
	return f
end

---------------------------------------------------------------------
-- PANELS
---------------------------------------------------------------------
local function buildUpgrades()
	local p = makePanel("Upgrades", "UPGRADES", Vector2.new(640, 430), C.Blue)
	local holder = frame(p.Body, { Transparency = 1 })
	list(holder, 10)
	local rows = {}
	local order = { "Backpack", "Luck", "Training" }
	local icons = { Backpack = "Icon_Backpack", Luck = "Icon_Gem", Training = "Icon_Power" }
	for i, key in ipairs(order) do
		local cfg = Config.Upgrades[key]
		local r = rowFrame(holder, 104, i)
		UITheme.Icon(r, icons[key], UDim2.fromOffset(64, 64), UDim2.fromOffset(16, 20))
		UITheme.Label(r, { Text = cfg.Name, Title = true, Size = UDim2.new(0.45, 0, 0, 34), Position = UDim2.fromOffset(96, 10), XAlign = Enum.TextXAlignment.Left, MaxText = 30 })
		local lvl = UITheme.Label(r, { Text = "", Size = UDim2.new(0.45, 0, 0, 24), Position = UDim2.fromOffset(96, 44), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 20 })
		local val = UITheme.Label(r, { Text = "", Size = UDim2.new(0.45, 0, 0, 22), Position = UDim2.fromOffset(96, 70), XAlign = Enum.TextXAlignment.Left, Color = C.Green, MaxText = 18, Rich = true })
		local btn = UITheme.Button(r, {
			Text = "Buy",
			Color = "Gold",
			Size = UDim2.fromOffset(170, 64),
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
		local extra = d.Passes and d.Passes.DoubleTraining
		for key, r in pairs(rows) do
			local lvl = d.Upgrades[key]
			local cost = d.UpgradeCosts[key]
			r.Level.Text = "Level " .. lvl .. " / " .. Config.Upgrades[key].Max
			if key == "Backpack" then
				r.Value.Text = string.format("Capacity: <b>%s</b> -> %s", Format.Abbrev(d.BackpackMax), Format.Abbrev(d.BackpackMax + 10))
			elseif key == "Luck" then
				r.Value.Text = string.format("Luck: <b>x%.2f</b> -> x%.2f", 1 + lvl * 0.05, 1 + (lvl + 1) * 0.05)
			else
				local per = extra and 20 or 10
				r.Value.Text = string.format("Power gain: <b>+%d%%</b> -> +%d%%", lvl * per, (lvl + 1) * per)
			end
			UITheme.SetButtonText(r.Button, cost and cost >= 0 and (Format.Abbrev(cost) .. " Coins") or "MAXED")
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
	local p = makePanel("Backpack", "BACKPACK", Vector2.new(640, 470), C.Gold)
	local items = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -96) })
	list(items, 6)
	local footer = frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 0, 86), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1) })
	local capBg = frame(footer, { Color = Color3.fromRGB(20, 16, 30), Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.fromOffset(0, 8), Corner = 15, Stroke = 2 })
	local capFill = frame(capBg, { Color = C.Gold, Size = UDim2.fromScale(0, 1), Corner = 15 })
	UITheme.Gradient(capFill, Color3.new(1, 1, 1), Color3.fromRGB(200, 150, 60), 90)
	local capText = UITheme.Label(capBg, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 18 })
	local hint = UITheme.Label(footer, { Text = "", Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.fromOffset(0, 44), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	hint.TextWrapped = true
	local actionBtn = UITheme.Button(footer, {
		Text = "SELL ALL",
		Color = "Gold",
		Size = UDim2.fromOffset(250, 76),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		MaxText = 28,
		OnClick = function()
			if p.Mode == "Sell" then
				request("Sell")
			else
				request("Forge")
			end
		end,
	})
	p.Refresh = function(d)
		local mode = p.Mode or "View"
		local sigParts = { mode, d.BackpackMax, math.floor(d.Derived.CoinMult * 100), math.floor(d.Derived.ForgeMult * 100) }
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
				local r = rowFrame(items, 62, i)
				local gem = frame(r, { Color = ore.Color, Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(16, 15), Stroke = 2 })
				gem.Rotation = 45
				UITheme.Label(r, { Text = ore.Name, Title = true, Size = UDim2.fromOffset(220, 28), Position = UDim2.fromOffset(62, 6), XAlign = Enum.TextXAlignment.Left, Color = ore.Color, MaxText = 22 })
				UITheme.Label(r, { Text = Config.Rarity[ore.Rarity].Label .. "  x" .. Format.Commas(count), Size = UDim2.fromOffset(220, 22), Position = UDim2.fromOffset(62, 34), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 16 })
				local valueText = mode == "Sell" and ("+" .. Format.Abbrev(ore.Sell * count * d.Derived.CoinMult) .. " Coins") or ("+" .. Format.Abbrev(ore.Forge * count * d.Derived.ForgeMult) .. " Blade")
				UITheme.Label(r, { Text = valueText, Size = UDim2.fromOffset(160, 30), Position = UDim2.new(1, -150, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = mode == "Sell" and C.Gold or Color3.fromRGB(255, 160, 80), MaxText = 20 })
				if mode ~= "View" then
					UITheme.Button(r, {
						Text = mode == "Sell" and "Sell" or "Forge",
						Color = mode == "Sell" and "Gold" or "Red",
						Size = UDim2.fromOffset(110, 46),
						Position = UDim2.new(1, -10, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						OnClick = function()
							request(mode == "Sell" and "Sell" or "Forge", ore.Id)
						end,
					})
				end
			end
		end
		if not any then
			local r = rowFrame(items, 60, 1)
			UITheme.Label(r, { Text = "Your backpack is empty. Slay monsters in the Dungeon to loot ore!", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Color = C.Sub, MaxText = 18 })
		end
		capFill.Size = UDim2.fromScale(math.clamp(d.BackpackCount / math.max(1, d.BackpackMax), 0, 1), 1)
		capText.Text = Format.Abbrev(d.BackpackCount) .. " / " .. Format.Abbrev(d.BackpackMax)
		actionBtn.Visible = mode ~= "View"
		UITheme.SetButtonText(actionBtn, mode == "Sell" and "SELL ALL" or "FORGE ALL")
		hint.Text = mode == "Sell" and "Tip: keep rare ore for the Forge!" or (mode == "Forge" and "Every ore forged = +Blade levels" or "Forge at the cauldron, sell at the stall.")
	end
end

local function buildIndex()
	local p = makePanel("Index", "ORE INDEX", Vector2.new(680, 470), Color3.fromRGB(80, 200, 255))
	local grid = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -40) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(148, 170)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = grid
	local footer = UITheme.Label(p.Body, { Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Gold, MaxText = 20 })
	p.Refresh = function(d)
		local sigParts = {}
		for _, ore in ipairs(Config.Ores) do
			table.insert(sigParts, d.Index[ore.Id] and "1" or "0")
		end
		local sig = table.concat(sigParts)
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		clearList(grid)
		local found = 0
		for i, ore in ipairs(Config.Ores) do
			local known = d.Index[ore.Id] == true
			if known then
				found += 1
			end
			local card = frame(grid, { Color = known and Color3.fromRGB(40, 32, 66) or Color3.fromRGB(22, 20, 30), Order = i, Corner = 14, Stroke = 3 })
			local st = card:FindFirstChildOfClass("UIStroke")
			if st and known then
				st.Color = ore.Color
			end
			local gem = frame(card, { Color = known and ore.Color or Color3.fromRGB(50, 50, 60), Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2 })
			gem.Rotation = 45
			if known then
				local shine = frame(gem, { Color = Color3.new(1, 1, 1), Transparency = 0.5, Size = UDim2.fromScale(0.35, 0.35), Position = UDim2.fromScale(0.15, 0.15) })
				shine.Name = "Shine"
			end
			UITheme.Label(card, { Text = known and ore.Name or "???", Title = true, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 78), Color = known and ore.Color or C.Sub, MaxText = 20 })
			UITheme.Label(card, { Text = Config.Rarity[ore.Rarity].Label, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 104), Color = C.Sub, MaxText = 15 })
			UITheme.Label(card, { Text = known and ("Forge +" .. ore.Forge .. " | Sell " .. ore.Sell) or ("Reward: " .. Format.Abbrev(Config.IndexReward[ore.Rarity]) .. " Coins"), Size = UDim2.new(1, -10, 0, 34), Position = UDim2.fromOffset(5, 128), Color = known and C.Text or C.Gold, MaxText = 14 })
		end
		footer.Text = string.format("Discovered %d / %d ores  -  new discoveries pay Coins!", found, #Config.Ores)
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
	local p = makePanel("Teleport", "TELEPORT", Vector2.new(640, 470), Color3.fromRGB(80, 220, 255))
	UITheme.Label(p.Body, { Text = "Hub is free. Everything else needs the Fast Travel pass (or walk through the portals!).", Size = UDim2.new(1, 0, 0, 28), Color = C.Sub, MaxText = 16 })
	local grid = scroller(p.Body, { Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(190, 64)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.Parent = grid
	p.Refresh = function(d)
		local unlockedCount = 0
		for _, stage in ipairs(Config.Stages) do
			local zone = Config.Zones[stage.Zone]
			if d.Power >= stage.PowerReq and d.Blade >= (zone.BladeReq or 0) then
				unlockedCount += 1
			end
		end
		if p.Sig == unlockedCount then
			return
		end
		p.Sig = unlockedCount
		clearList(grid)
		local function add(order, text, dest, color, locked)
			UITheme.Button(grid, { Text = locked and (text .. " [LOCKED]") or text, Color = locked and "Red" or color, Order = order, MaxText = 20, Sound = "Teleport", OnClick = function()
				request("Teleport", dest)
				UI.Close()
			end })
		end
		add(1, "Hub", "Hub", "Green")
		add(2, "Train Area", "Train", "Blue")
		add(3, "Tower", "Tower", "Purple")
		for i, stage in ipairs(Config.Stages) do
			local zone = Config.Zones[stage.Zone]
			local unlocked = d.Power >= stage.PowerReq and d.Blade >= (zone.BladeReq or 0)
			add(10 + i, "Stage " .. i .. (stage.Boss and " (Boss)" or ""), "Stage_" .. i, "Gold", not unlocked)
		end
	end
end

local function buildRebirth()
	local p = makePanel("Rebirth", "REBIRTH", Vector2.new(600, 440), C.Gold)
	local info = rowFrame(p.Body, 250, 0, Color3.fromRGB(44, 34, 30))
	local count = UITheme.Label(info, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 8), Color = C.Gold, MaxText = 36 })
	local barBg = frame(info, { Color = Color3.fromRGB(20, 16, 30), Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 60), Corner = 17, Stroke = 2 })
	local barFill = frame(barBg, { Color = C.Gold, Size = UDim2.fromScale(0, 1), Corner = 17 })
	UITheme.Gradient(barFill, Color3.new(1, 1, 1), Color3.fromRGB(220, 140, 40), 90)
	local barText = UITheme.Label(barBg, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 20 })
	local rewards = UITheme.Label(info, { Text = "", Rich = true, Size = UDim2.new(1, -30, 0, 140), Position = UDim2.fromOffset(15, 102), XAlign = Enum.TextXAlignment.Left, MaxText = 18 })
	rewards.TextWrapped = true
	UITheme.Button(p.Body, { Text = "REBIRTH", Color = "Gold", Size = UDim2.fromOffset(260, 70), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), MaxText = 32, OnClick = function()
		request("Rebirth")
		UI.Close()
	end })
	p.Refresh = function(d)
		count.Text = "Rebirths: " .. Format.Abbrev(d.Rebirths)
		barFill.Size = UDim2.fromScale(math.clamp(d.Power / math.max(1, d.RebirthReq), 0, 1), 1)
		barText.Text = Format.Abbrev(d.Power) .. " / " .. Format.Abbrev(d.RebirthReq) .. " Power"
		rewards.Text = table.concat({
			'<font color="#78ff9c">+100% Power gain</font>, <font color="#ffd75a">+25% Coins</font>, <font color="#ff8a8a">+10% Damage</font> (permanent)',
			'<font color="#c8a0ff">+1 Race Reroll</font> and a stronger Ascension aura',
			'<font color="#ff7a7a">Resets Power and Coins.</font> Keeps Blade level, ore, race and runes.',
		}, "\n")
	end
end

local function buildSettings()
	local p = makePanel("Settings", "SETTINGS", Vector2.new(480, 330), Color3.fromRGB(150, 150, 170))
	local holder = frame(p.Body, { Transparency = 1 })
	list(holder, 12)
	local state = { Music = true, SFX = true }
	local buttons = {}
	local function apply()
		SFX.SetMusicVolume(state.Music and 0.45 or 0)
		SFX.SetSFXVolume(state.SFX and 0.9 or 0)
		for key, btn in pairs(buttons) do
			UITheme.SetButtonText(btn, key .. ": " .. (state[key] and "ON" or "OFF"))
		end
	end
	for i, key in ipairs({ "Music", "SFX" }) do
		buttons[key] = UITheme.Button(holder, { Text = key, Color = "Blue", Size = UDim2.fromOffset(320, 64), Order = i, OnClick = function()
			state[key] = not state[key]
			apply()
			request("Settings", state)
		end })
	end
	UITheme.Label(holder, { Text = Config.GameName, Title = true, Size = UDim2.fromOffset(320, 30), Order = 9, Color = C.Pink, MaxText = 22 })
	p.Refresh = function(d)
		if d.Settings then
			state.Music = d.Settings.Music ~= false
			state.SFX = d.Settings.SFX ~= false
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
	padLabel.Text = locked and ("x" .. Format.Abbrev(mult) .. "  PAD LOCKED") or ("x" .. Format.Abbrev(mult) .. "  TRAINING")
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

function UI.Tower(state: string?, floor: number?, endsAt: number?)
	if not state then
		towerHud.Visible = false
		return
	end
	towerHud.Visible = true
	towerHud:SetAttribute("EndsAt", endsAt or 0)
	towerHud:SetAttribute("Floor", floor or 1)
	local title = towerHud:FindFirstChild("Title") :: TextLabel
	title.Text = "TOWER FLOOR " .. tostring(floor or 1)
end

---------------------------------------------------------------------
-- UPDATE
---------------------------------------------------------------------
function UI.Update(d)
	local first = UI.Data == nil
	UI.Data = d
	local tier = Config.GetBladeTier(d.Blade)
	animateNumber("Power", pills.Power.Value, d.Power, Format.Abbrev)
	pills.Power.Sub.Text = "+" .. Format.Abbrev(d.Derived.PowerPerSwing) .. " / swing"
	animateNumber("Blade", pills.Blade.Value, d.Blade, function(v)
		return "+" .. Format.Abbrev(math.floor(v))
	end)
	pills.Blade.Sub.Text = tier.Name
	pills.Blade.Sub.TextColor3 = tier.Edge or C.Sub
	animateNumber("Coins", pills.Coins.Value, d.Coins, Format.Abbrev)
	pills.Coins.Sub.Text = "x" .. string.format("%.2f", d.Derived.CoinMult)
	pills.Backpack.Value.Text = Format.Abbrev(d.BackpackCount) .. "/" .. Format.Abbrev(d.BackpackMax)
	local full = d.BackpackCount >= d.BackpackMax
	pills.Backpack.Sub.Text = full and "FULL" or "Ore"
	pills.Backpack.Sub.TextColor3 = full and C.Red or pills.Backpack.Color
	pills.Rebirths.Value.Text = Format.Abbrev(d.Rebirths)
	pills.Rebirths.Sub.Text = math.floor(math.clamp(d.Power / math.max(1, d.RebirthReq), 0, 1) * 100) .. "% to next"
	pills.Damage.Value.Text = Format.Abbrev(d.Derived.Damage)
	pills.Damage.Sub.Text = "Runes: " .. d.Runes

	-- contextual: only the resources that changed fade in
	local now = { Power = d.Power, Blade = d.Blade, Coins = d.Coins, Backpack = d.BackpackCount, Rebirths = d.Rebirths, Damage = d.Derived.Damage }
	for key, v in pairs(now) do
		if not first and prevValues[key] ~= nil and prevValues[key] ~= v then
			UI.Reveal(key)
		end
		prevValues[key] = v
	end
	if full then
		UI.Reveal("Backpack", 1)
	end

	if current and current.Refresh then
		current.Refresh(d)
	end
	if first and UI.ApplySettings then
		UI.ApplySettings(d)
	end
end

-- Called every frame by the client (timers + contextual fades).
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
	local t = os.clock()
	local peek = drawerOpen or current ~= nil
	for _, p in pairs(pills) do
		local target = (peek or t < p.Until) and 1 or 0
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
		drawer.Position = UDim2.new(0, -10, 0, drawer.Position.Y.Offset)
	end
	tween(drawer, 0.28, { GroupTransparency = open and 0 or 1, Position = UDim2.new(0, open and 18 or -10, 0, drawer.Position.Y.Offset) }, Enum.EasingStyle.Quart).Completed:Once(function()
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

	-- resource ticker (top centre). Pills are invisible until a value
	-- changes; hidden pills collapse so the visible ones stay centred.
	local top = frame(root, { Transparency = 1, Size = UDim2.new(1, -320, 0, 40), Position = UDim2.new(0.5, 0, 0, inset.Y + 10), AnchorPoint = Vector2.new(0.5, 0) })
	top.Name = "Resources"
	list(top, 8, true)
	makePill(top, "Power", "Icon_Power", Color3.fromRGB(120, 255, 170), 1)
	makePill(top, "Blade", "Icon_Blade", Color3.fromRGB(255, 170, 80), 2)
	makePill(top, "Damage", "Icon_Rune", Color3.fromRGB(255, 110, 120), 3)
	makePill(top, "Coins", "Icon_Coins", C.Gold, 4)
	makePill(top, "Backpack", "Icon_Backpack", Color3.fromRGB(120, 200, 255), 5)
	makePill(top, "Rebirths", "Icon_Rebirth", Color3.fromRGB(210, 150, 255), 6)

	-- single small menu button; everything else lives in the drawer
	local menuBtn = Instance.new("TextButton")
	menuBtn.Name = "MenuButton"
	menuBtn.AutoButtonColor = false
	menuBtn.Text = ""
	menuBtn.Size = UDim2.fromOffset(40, 40)
	menuBtn.Position = UDim2.fromOffset(18, inset.Y + 10)
	menuBtn.BackgroundColor3 = Color3.fromRGB(10, 8, 22)
	menuBtn.BackgroundTransparency = 0.45
	menuBtn.Parent = root
	UITheme.Corner(menuBtn, 20)
	local mbStroke = Instance.new("UIStroke")
	mbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mbStroke.Thickness = 1
	mbStroke.Color = Color3.fromRGB(200, 180, 255)
	mbStroke.Transparency = 0.6
	mbStroke.Parent = menuBtn
	for k = -1, 1 do
		local line = frame(menuBtn, { Color = Color3.new(1, 1, 1), Transparency = 0.1, Size = UDim2.fromOffset(k == 0 and 12 or 16, 2), Position = UDim2.new(0.5, 0, 0.5, k * 5), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 1 })
		line.Name = "Line"
	end
	menuBtn.MouseEnter:Connect(function()
		tween(mbStroke, 0.15, { Transparency = 0.1 })
		SFX.Play("UIHover")
	end)
	menuBtn.MouseLeave:Connect(function()
		tween(mbStroke, 0.15, { Transparency = 0.6 })
	end)
	menuBtn.Activated:Connect(function()
		UI.ToggleDrawer()
	end)

	-- menu drawer (slides out under the menu button)
	drawer = Instance.new("CanvasGroup")
	drawer.Name = "Drawer"
	drawer.BackgroundColor3 = Color3.fromRGB(8, 6, 18)
	drawer.BackgroundTransparency = 0.3
	drawer.GroupTransparency = 1
	drawer.Visible = false
	drawer.Size = UDim2.fromOffset(188, 440)
	drawer.Position = UDim2.new(0, -10, 0, inset.Y + 60)
	drawer.ZIndex = 3
	drawer.Parent = root
	UITheme.Corner(drawer, 16)
	local dStroke = Instance.new("UIStroke")
	dStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dStroke.Thickness = 1
	dStroke.Color = Color3.fromRGB(200, 180, 255)
	dStroke.Transparency = 0.7
	dStroke.Parent = drawer
	softLabel(drawer, { Text = "MENU  [G]     MAP  [M]", Font = Enum.Font.BuilderSansMedium, Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(10, 10), Color = C.Sub, Transparency = 0.2 })
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
		b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		b.BackgroundTransparency = 0.94
		b.LayoutOrder = order
		b.Parent = grid
		UITheme.Corner(b, 10)
		local st = Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 1
		st.Color = color
		st.Transparency = 0.75
		st.Parent = b
		UITheme.Icon(b, icon, UDim2.fromOffset(20, 20), UDim2.new(0.5, 0, 0, 5), Vector2.new(0.5, 0))
		softLabel(b, { Text = label, Font = Enum.Font.BuilderSansMedium, Size = UDim2.new(1, -8, 0, 13), Position = UDim2.new(0, 4, 1, -18), Color = Color3.new(1, 1, 1) })
		b.MouseEnter:Connect(function()
			tween(st, 0.12, { Transparency = 0.2 })
			tween(b, 0.12, { BackgroundTransparency = 0.86 })
			SFX.Play("UIHover")
		end)
		b.MouseLeave:Connect(function()
			tween(st, 0.12, { Transparency = 0.75 })
			tween(b, 0.12, { BackgroundTransparency = 0.94 })
		end)
		b.Activated:Connect(function()
			SFX.Play("UIClick")
			UI.ToggleDrawer(false)
			onClick()
		end)
		return b
	end
	drawerButton("Weapons", "Icon_Blade", C.Purple, 1, function() UI.Toggle("Weapons") end)
	drawerButton("Map", "Icon_Teleport", Color3.fromRGB(80, 220, 255), 2, function()
		if UI.ToggleMap then
			UI.ToggleMap()
		end
	end)
	drawerButton("Shop", "Icon_Shop", C.Green, 3, function() UI.Toggle("Shop") end)
	drawerButton("Upgrades", "Icon_Upgrades", C.Blue, 4, function() UI.Toggle("Upgrades") end)
	drawerButton("Race", "Icon_Race", C.Purple, 5, function() UI.Toggle("Race") end)
	drawerButton("Bag", "Icon_Backpack", C.Gold, 6, function() UI.Toggle("Backpack", "View") end)
	drawerButton("Chests", "Icon_Gem", C.Gold, 7, function() UI.Toggle("Chests") end)
	drawerButton("Power", "Icon_Power", C.Red, 8, function() UI.Toggle("Power") end)
	drawerButton("Rewards", "Icon_Tower", C.Green, 9, function() UI.Toggle("Rewards") end)
	drawerButton("Index", "Icon_Index", C.Blue, 10, function() UI.Toggle("Index") end)
	drawerButton("Travel", "Icon_Teleport", C.Green, 11, function() UI.Toggle("Teleport") end)
	drawerButton("Hub", "Icon_Home", C.Blue, 12, function()
		SFX.Play("Teleport")
		request("Teleport", "Hub")
	end)
	drawerButton("Rebirth", "Icon_Rebirth", C.Gold, 13, function() UI.Toggle("Rebirth") end)
	drawerButton("Settings", "Icon_Settings", C.Sub, 14, function() UI.Toggle("Settings") end)

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
		end
	end)

	-- pad indicator (only while standing on a training pad)
	padLabel = softLabel(root, { Text = "", Font = Enum.Font.BuilderSansExtraBold, Size = UDim2.fromOffset(300, 24), Position = UDim2.new(0.5, 0, 0, inset.Y + 60), AnchorPoint = Vector2.new(0.5, 0), MaxText = 22 })
	padLabel.Visible = false

	-- zone banner (fades in and out on arrival)
	zoneBanner = frame(root, { Transparency = 1, Size = UDim2.fromOffset(560, 70), Position = UDim2.new(0.5, 0, 0, 170), AnchorPoint = Vector2.new(0.5, 0) })
	zoneBanner.Name = "ZoneBanner"
	zoneBanner.Visible = false
	softLabel(zoneBanner, { Name = "Title", Text = "", Font = Enum.Font.BuilderSansExtraBold, Size = UDim2.new(1, 0, 0, 40), MaxText = 38 })
	softLabel(zoneBanner, { Name = "Sub", Text = "", Font = Enum.Font.BuilderSansMedium, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 44), MaxText = 18, Color = C.Sub })

	-- tower hud (only inside the tower)
	towerHud = frame(root, { Color = Color3.fromRGB(10, 8, 22), Transparency = 0.4, Size = UDim2.fromOffset(300, 64), Position = UDim2.fromOffset(18, inset.Y + 60), Corner = 14 })
	towerHud.Name = "TowerHud"
	towerHud.Visible = false
	softLabel(towerHud, { Name = "Title", Text = "TOWER", Font = Enum.Font.BuilderSansMedium, Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(14, 8), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(220, 160, 255) })
	softLabel(towerHud, { Name = "Timer", Text = "--:--", Font = Enum.Font.BuilderSansExtraBold, Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.fromOffset(14, 28), XAlign = Enum.TextXAlignment.Left })
	UITheme.Button(towerHud, { Text = "LEAVE", Color = "Red", Size = UDim2.fromOffset(96, 40), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 20, OnClick = function()
		request("TowerLeave")
	end })

	-- notifications
	toastHolder = frame(root, { Transparency = 1, Size = UDim2.fromOffset(340, 300), Position = UDim2.new(1, -16, 0, inset.Y + 60), AnchorPoint = Vector2.new(1, 0) })
	toastHolder.Name = "Toasts"
	local tl = list(toastHolder, 6)
	tl.VerticalAlignment = Enum.VerticalAlignment.Top
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastHolder.ClipsDescendants = false

	buildUpgrades()
	buildRace()
	buildBackpack()
	buildIndex()
	buildShop()
	buildTeleport()
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
