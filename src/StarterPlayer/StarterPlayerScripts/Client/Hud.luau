--!nonstrict
-- Hud (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/Hud
-- Clean-screen HUD. Nothing here is permanently on screen; every group is a
-- CanvasGroup that fades in only when it matters and fades out after
-- Config.Hud.*Linger seconds:
--   Vitals   slim HP + stamina bars (with a trailing damage chip), boost /
--            Overdrive tags. Shows on damage, healing, stamina use, combat,
--            potions, and stays while HP is low (plus a soft red vignette).
--   Hotbar   compact LMB / Q / E / R / C slots with cooldown sweeps. Shows
--            in combat, while a cooldown runs, or right after equipping.
--   Playtime next play-time reward timer. Shows shortly before a reward,
--            when one is granted, and while the menu drawer is open.
-- Opening the menu drawer (G) "peeks" every group.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UITheme = require(Shared:WaitForChild("UITheme"))

local Hud = {}

local player = Players.LocalPlayer
local HC = Config.Hud
local UI, Abilities
local H
local slots = {}
local groups = {} -- [name] = { Frame, Until, Alpha }
local hpFill, hpChip, hpText, stFill, stBar, tagText
local ptTitle, ptTimer, ptFill
local vignette = {}
local lastHealth = nil
local lastStamina = nil
local lastRewardIndex = 0
local enemyCheck = 0

local FONT = Enum.Font.BuilderSansBold
local FONT_LIGHT = Enum.Font.BuilderSansMedium

local SLOTS = {
	{ Slot = "LMB", Name = "Attack", Keys = { Keyboard = "LMB", Gamepad = "RT", Touch = "" }, Color = Color3.fromRGB(230, 230, 240) },
	{ Slot = "Q", Name = "Dash", Keys = { Keyboard = "Q", Gamepad = "B", Touch = "" }, Color = Color3.fromRGB(120, 200, 255) },
	{ Slot = "E", Name = "Skill", Keys = { Keyboard = "E", Gamepad = "X", Touch = "" }, Color = Color3.fromRGB(255, 190, 90) },
	{ Slot = "R", Name = "Ultimate", Keys = { Keyboard = "R", Gamepad = "Y", Touch = "" }, Color = Color3.fromRGB(255, 90, 120) },
	{ Slot = "C", Name = "Overdrive", Keys = { Keyboard = "C", Gamepad = "LB", Touch = "" }, Color = Color3.fromRGB(255, 140, 60) },
}

local function device(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif last.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	end
	return "Keyboard"
end

-- Small text with a light drop shadow instead of a heavy outline.
local function text(parent: Instance, props)
	local t = Instance.new("TextLabel")
	t.Name = props.Name or "Text"
	t.BackgroundTransparency = 1
	t.Font = props.Font or FONT
	t.TextScaled = true
	t.Text = props.Text or ""
	t.TextColor3 = props.Color or Color3.new(1, 1, 1)
	t.TextTransparency = props.Transparency or 0
	t.Size = props.Size
	t.Position = props.Position or UDim2.new()
	t.AnchorPoint = props.AnchorPoint or Vector2.zero
	t.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	t.ZIndex = props.ZIndex or 2
	t.Parent = parent
	local st = Instance.new("UIStroke")
	st.Thickness = 1
	st.Color = Color3.fromRGB(6, 4, 14)
	st.Transparency = 0.55
	st.Parent = t
	return t
end

local function group(name: string, props): CanvasGroup
	local g = Instance.new("CanvasGroup")
	g.Name = name
	g.BackgroundTransparency = 1
	g.GroupTransparency = 1
	g.Visible = false
	g.Size = props.Size
	g.Position = props.Position
	g.AnchorPoint = props.AnchorPoint or Vector2.zero
	g.Parent = props.Parent
	groups[name] = { Frame = g, Until = 0, Alpha = 0 }
	return g
end

-- Keep a group on screen for at least `seconds` from now.
function Hud.Ping(name: string, seconds: number)
	local g = groups[name]
	if g then
		g.Until = math.max(g.Until, os.clock() + seconds)
	end
end

-- Entering / staying in combat: vitals + hotbar.
function Hud.Combat()
	Hud.Ping("Vitals", HC.CombatLinger)
	Hud.Ping("Hotbar", HC.CombatLinger)
end

local function refreshKeys()
	local d = device()
	for _, s in ipairs(slots) do
		s.Key.Text = s.Def.Keys[d] or ""
		s.Key.Visible = s.Key.Text ~= ""
	end
end

function Hud.RefreshSkillNames()
	for _, s in ipairs(slots) do
		if s.Def.Slot == "E" or s.Def.Slot == "R" then
			local _, skill = Abilities.SkillFor(s.Def.Slot)
			s.Name.Text = skill and skill.Name or s.Def.Name
		elseif s.Def.Slot == "LMB" then
			local def = Config.WeaponById[player:GetAttribute("WeaponId") or Config.StarterWeapon]
			s.Name.Text = def and def.Name or "Attack"
		end
	end
	Hud.Ping("Hotbar", 3)
end

function Hud.FlashStamina()
	Hud.Ping("Vitals", HC.StaminaLinger + 1)
	if stBar then
		stBar.BackgroundColor3 = Color3.fromRGB(220, 50, 60)
		stBar.BackgroundTransparency = 0.2
		H.Tween(stBar, 0.5, { BackgroundColor3 = Color3.fromRGB(10, 8, 20), BackgroundTransparency = 0.55 })
	end
end

-- Called when the player takes damage (server FX "Hurt").
function Hud.Hurt()
	Hud.Ping("Vitals", HC.DamageLinger)
	Hud.Combat()
end

local function nextReward(session: number)
	local prevMinutes = 0
	for i, r in ipairs(Config.PlaytimeRewards) do
		if session < r.Minutes * 60 then
			return r, prevMinutes, i
		end
		prevMinutes = r.Minutes
	end
	return nil, prevMinutes, #Config.PlaytimeRewards + 1
end

local function anyCooldown(t: number): boolean
	for _, slot in ipairs({ "Q", "E", "R" }) do
		if (Abilities.CooldownEnds[slot] or 0) > t then
			return true
		end
	end
	return false
end

local function enemyNear(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Enemies")
	if not root or not folder then
		return false
	end
	local range = Config.EnemyAggroRange
	for _, m in ipairs(folder:GetChildren()) do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude < range * (m:GetAttribute("Boss") and 2 or 1) then
			return true
		end
	end
	return false
end

function Hud.Tick(dt: number)
	local t = os.clock()
	local d = UI.Data
	local peek = UI.IsPeeking()

	-- context triggers ----------------------------------------------------
	enemyCheck -= dt
	if enemyCheck <= 0 then
		enemyCheck = 0.25
		if enemyNear() then
			Hud.Combat()
		end
	end
	if anyCooldown(t) then
		Hud.Ping("Hotbar", 0.6)
	end

	-- hotbar cooldowns ----------------------------------------------------
	for _, s in ipairs(slots) do
		local slot = s.Def.Slot
		local ends = Abilities.CooldownEnds[slot] or 0
		local len = math.max(0.01, Abilities.CooldownLength[slot] or 1)
		local left = ends - t
		if slot == "C" and d then
			left = (d.OverdriveEnd or 0) - workspace:GetServerTimeNow()
			len = 180
			s.Badge.Text = "x" .. tostring(d.Overdrive or 0)
		end
		if left > 0 then
			s.Shade.Size = UDim2.fromScale(1, math.clamp(left / len, 0, 1))
			s.Timer.Text = left >= 10 and tostring(math.floor(left)) or string.format("%.1f", left)
			s.Timer.Visible = slot ~= "LMB"
		else
			s.Shade.Size = UDim2.fromScale(1, 0)
			s.Timer.Visible = false
		end
	end

	-- vitals --------------------------------------------------------------
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hpFrac = 1
	if hum and hum.MaxHealth > 0 then
		hpFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		if lastHealth and math.abs(hum.Health - lastHealth) > 0.5 then
			if hum.Health < lastHealth then
				Hud.Ping("Vitals", HC.DamageLinger)
				-- the chip holds, then drains toward the new value
				task.delay(0.35, function()
					if hpChip then
						H.Tween(hpChip, 0.45, { Size = UDim2.fromScale(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 1) })
					end
				end)
			else
				Hud.Ping("Vitals", 2)
				hpChip.Size = UDim2.fromScale(hpFrac, 1)
			end
		end
		lastHealth = hum.Health
		hpFill.Size = UDim2.fromScale(hpFrac, 1)
		hpText.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
		if hpFrac < HC.LowHealth and hum.Health > 0 then
			Hud.Ping("Vitals", 0.5)
		end
	end
	local maxSt = Config.Balance.MaxStamina
	local st = player:GetAttribute("Stamina") or maxSt
	if lastStamina and st < lastStamina - 0.5 then
		Hud.Ping("Vitals", HC.StaminaLinger)
	elseif st < maxSt - 0.5 then
		Hud.Ping("Vitals", 0.6)
	end
	lastStamina = st
	stFill.Size = UDim2.fromScale(math.clamp(st / maxSt, 0, 1), 1)

	-- low-health vignette (soft red edges that pulse)
	local low = hum and hum.Health > 0 and hpFrac < HC.LowHealth
	local vt = 1
	if low then
		vt = 0.35 + 0.2 * math.sin(t * 5) + hpFrac
	end
	for _, v in ipairs(vignette) do
		v.BackgroundTransparency = vt
	end

	-- boost / overdrive tags
	local tags = {}
	if d then
		local now = workspace:GetServerTimeNow()
		local boostLeft = (d.BoostEnds or 0) - now
		if boostLeft > 0 then
			table.insert(tags, '<font color="#ff8a6a">2x DAMAGE ' .. Format.Time(boostLeft) .. "</font>")
		end
		local odLeft = (d.OverdriveEnd or 0) - now
		if odLeft > 0 then
			table.insert(tags, '<font color="#ffb45a">OVERDRIVE ' .. Format.Time(odLeft) .. "</font>")
		end
		if (d.ZenkaiEnd or 0) > now then
			table.insert(tags, '<font color="#ffe15a">ZENKAI</font>')
		end
	end
	tagText.Text = table.concat(tags, "   ")

	-- play-time ladder ----------------------------------------------------
	local session = player:GetAttribute("SessionTime") or 0
	local reward, prevMinutes, index = nextReward(session)
	if reward then
		local remaining = reward.Minutes * 60 - session
		ptTitle.Text = "Next: " .. reward.Name
		ptTimer.Text = Format.Time(remaining)
		ptFill.Size = UDim2.fromScale(math.clamp((session - prevMinutes * 60) / ((reward.Minutes - prevMinutes) * 60), 0, 1), 1)
		if remaining <= HC.PlaytimeHeadsUp then
			Hud.Ping("Playtime", 1)
		end
	else
		ptTitle.Text = "All play-time rewards claimed"
		ptTimer.Text = Format.Time(session)
		ptFill.Size = UDim2.fromScale(1, 1)
	end
	if index ~= lastRewardIndex then
		if lastRewardIndex ~= 0 then
			Hud.Ping("Playtime", 6)
		end
		lastRewardIndex = index
	end

	-- fade every group toward its target ----------------------------------
	for _, g in pairs(groups) do
		local target = (peek or t < g.Until) and 1 or 0
		local speed = target > g.Alpha and 9 or 3.5
		g.Alpha += (target - g.Alpha) * math.min(1, dt * speed)
		if math.abs(target - g.Alpha) < 0.01 then
			g.Alpha = target
		end
		g.Frame.GroupTransparency = 1 - g.Alpha
		g.Frame.Visible = g.Alpha > 0.01
	end
end

local function buildSlot(parent, def, order: number)
	local f = H.Frame(parent, { Color = Color3.fromRGB(10, 8, 22), Transparency = 0.35, Size = UDim2.fromOffset(54, 54), Order = order, Corner = 12 })
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1
	stroke.Color = def.Color
	stroke.Transparency = 0.45
	stroke.Parent = f
	local accent = H.Frame(f, { Color = def.Color, Size = UDim2.new(0.5, 0, 0, 2), Position = UDim2.new(0.25, 0, 1, -4), Corner = 1 })
	accent.Name = "Accent"
	local key = text(f, { Text = "", Size = UDim2.fromOffset(26, 13), Position = UDim2.fromOffset(5, 4), XAlign = Enum.TextXAlignment.Left, Color = def.Color })
	local name = text(f, { Text = def.Name, Font = FONT_LIGHT, Size = UDim2.new(1, -8, 0, 12), Position = UDim2.new(0, 4, 1, -20), Transparency = 0.1 })
	local shade = H.Frame(f, { Color = Color3.new(0, 0, 0), Transparency = 0.45, Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), Corner = 12, ZIndex = 3 })
	local timer = text(f, { Text = "", Size = UDim2.fromScale(1, 0.42), Position = UDim2.fromScale(0, 0.24), ZIndex = 4 })
	timer.Visible = false
	local badge = text(f, { Text = "", Font = FONT_LIGHT, Size = UDim2.fromOffset(22, 12), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, Color = def.Color })
	badge.Visible = def.Slot == "C"
	-- tap / click the slot to use it
	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Size = UDim2.fromScale(1, 1)
	btn.ZIndex = 5
	btn.Parent = f
	btn.Activated:Connect(function()
		Abilities.Press(def.Slot)
	end)
	table.insert(slots, { Def = def, Frame = f, Key = key, Name = name, Shade = shade, Timer = timer, Badge = badge })
end

local function edge(root: Instance, size: UDim2, pos: UDim2, anchor: Vector2, rotation: number)
	local f = Instance.new("Frame")
	f.Name = "Vignette"
	f.BackgroundColor3 = Color3.fromRGB(200, 20, 40)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor
	f.ZIndex = 0
	f.Active = false
	f.Parent = root
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	table.insert(vignette, f)
end

function Hud.Init(ui, abilities)
	UI, Abilities = ui, abilities
	H = UI.Helpers
	local root = UI.Root()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	-- low-health vignette (4 soft edges)
	local fx = UI.FlyGui()
	edge(fx, UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), Vector2.zero, 90)
	edge(fx, UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 1), Vector2.new(0, 1), 270)
	edge(fx, UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), Vector2.zero, 0)
	edge(fx, UDim2.fromScale(0.16, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180)

	-- hotbar (bottom centre, combat only)
	local hotbar = group("Hotbar", { Parent = root, Size = UDim2.fromOffset(5 * 54 + 4 * 8, 56), Position = UDim2.new(0.5, 0, 1, -18), AnchorPoint = Vector2.new(0.5, 1) })
	H.List(hotbar, 8, true)
	for i, def in ipairs(SLOTS) do
		buildSlot(hotbar, def, i)
	end

	-- vitals (slim bars above the hotbar)
	local vitals = group("Vitals", { Parent = root, Size = UDim2.fromOffset(320, 44), Position = UDim2.new(0.5, 0, 1, -82), AnchorPoint = Vector2.new(0.5, 1) })
	tagText = text(vitals, { Text = "", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 0) })
	tagText.RichText = true
	local hpBar = H.Frame(vitals, { Color = Color3.fromRGB(10, 8, 20), Transparency = 0.45, Size = UDim2.new(1, -70, 0, 7), Position = UDim2.fromOffset(0, 22), Corner = 4 })
	hpChip = H.Frame(hpBar, { Color = Color3.fromRGB(255, 240, 240), Transparency = 0.25, Size = UDim2.fromScale(1, 1), Corner = 4 })
	hpFill = H.Frame(hpBar, { Color = Color3.fromRGB(110, 235, 130), Size = UDim2.fromScale(1, 1), Corner = 4, ZIndex = 2 })
	UITheme.Gradient(hpFill, Color3.fromRGB(150, 255, 170), Color3.fromRGB(70, 200, 110), 0)
	hpText = text(vitals, { Text = "", Font = FONT_LIGHT, Size = UDim2.fromOffset(64, 12), Position = UDim2.new(1, 0, 0, 20), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, Transparency = 0.15 })
	stBar = H.Frame(vitals, { Color = Color3.fromRGB(10, 8, 20), Transparency = 0.55, Size = UDim2.new(1, -70, 0, 3), Position = UDim2.fromOffset(0, 34), Corner = 2 })
	stFill = H.Frame(stBar, { Color = Color3.fromRGB(110, 200, 255), Size = UDim2.fromScale(1, 1), Corner = 2 })

	-- play-time timer (bottom left, only near a reward)
	local pt = group("Playtime", { Parent = root, Size = UDim2.fromOffset(250, 50), Position = UDim2.new(0, 18, 1, -18), AnchorPoint = Vector2.new(0, 1) })
	ptTitle = text(pt, { Text = "", Font = FONT_LIGHT, Size = UDim2.new(1, -70, 0, 15), Position = UDim2.fromOffset(0, 6), XAlign = Enum.TextXAlignment.Left })
	ptTimer = text(pt, { Text = "", Size = UDim2.fromOffset(68, 17), Position = UDim2.new(1, 0, 0, 5), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, Color = UITheme.Colors.Gold })
	local ptBar = H.Frame(pt, { Color = Color3.fromRGB(10, 8, 20), Transparency = 0.5, Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromOffset(0, 28), Corner = 2 })
	ptFill = H.Frame(ptBar, { Color = UITheme.Colors.Gold, Size = UDim2.fromScale(0, 1), Corner = 2 })
	local open = Instance.new("TextButton")
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = pt
	open.Activated:Connect(function()
		UI.Toggle("Rewards")
	end)

	refreshKeys()
	UserInputService.LastInputTypeChanged:Connect(refreshKeys)
	player:GetAttributeChangedSignal("WeaponId"):Connect(Hud.RefreshSkillNames)
	Hud.RefreshSkillNames()
	-- introduce the play-time timer once so new players know it exists
	Hud.Ping("Playtime", 8)
end

return Hud
