--!nonstrict
-- Hud (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/Hud
-- Ability hotbar (LMB / Q / E / R / C) with cooldown sweeps and key labels
-- that follow the input device, HP + stamina bars, play-time reward timer,
-- daily streak and the 2x damage boost timer.

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
local UI, Abilities
local H
local slots = {}
local hpFill, hpText, stFill, stText, stBar
local ptTitle, ptTimer, ptFill, ptStreak, boostLabel
local C = UITheme.Colors

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
			s.Cost.Text = skill and (math.floor(skill.Stamina * Config.Balance.StaminaCostMult) .. " ST") or ""
		elseif s.Def.Slot == "Q" then
			s.Cost.Text = math.floor(Config.Balance.DashStamina * Config.Balance.StaminaCostMult) .. " ST"
		elseif s.Def.Slot == "LMB" then
			local def = Config.WeaponById[player:GetAttribute("WeaponId") or Config.StarterWeapon]
			s.Name.Text = def and def.Name or "Attack"
		end
	end
end

function Hud.FlashStamina()
	if stBar then
		stBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		H.Tween(stBar, 0.4, { BackgroundColor3 = Color3.fromRGB(20, 16, 30) })
	end
end

function Hud.Tick()
	local t = os.clock()
	for _, s in ipairs(slots) do
		local slot = s.Def.Slot
		local ends = Abilities.CooldownEnds[slot] or 0
		local len = math.max(0.01, Abilities.CooldownLength[slot] or 1)
		local left = ends - t
		if slot == "C" and UI.Data then
			left = (UI.Data.OverdriveEnd or 0) - workspace:GetServerTimeNow()
			len = 180
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
	-- HP / stamina
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MaxHealth > 0 then
		local f = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		hpFill.Size = UDim2.fromScale(f, 1)
		hpText.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
	end
	local st = player:GetAttribute("Stamina") or Config.Balance.MaxStamina
	stFill.Size = UDim2.fromScale(math.clamp(st / Config.Balance.MaxStamina, 0, 1), 1)
	stText.Text = "Stamina " .. math.floor(st)

	-- play-time ladder
	local session = player:GetAttribute("SessionTime") or 0
	local nextReward = nil
	local prevMinutes = 0
	for _, r in ipairs(Config.PlaytimeRewards) do
		if session < r.Minutes * 60 then
			nextReward = r
			break
		end
		prevMinutes = r.Minutes
	end
	if nextReward then
		local remaining = nextReward.Minutes * 60 - session
		ptTitle.Text = "Next: " .. nextReward.Name
		ptTimer.Text = Format.Time(remaining)
		ptFill.Size = UDim2.fromScale(math.clamp((session - prevMinutes * 60) / ((nextReward.Minutes - prevMinutes) * 60), 0, 1), 1)
	else
		ptTitle.Text = "All play-time rewards claimed!"
		ptTimer.Text = Format.Time(session)
		ptFill.Size = UDim2.fromScale(1, 1)
	end
	local d = UI.Data
	if d then
		local bonus = math.min(d.Streak * Config.Daily.CoinBonusPerDay, Config.Daily.MaxCoinBonus)
		ptStreak.Text = string.format("Day %d streak  (+%d%% Coins)", d.Streak, math.floor(bonus * 100 + 0.5))
		local boostLeft = (d.BoostEnds or 0) - workspace:GetServerTimeNow()
		boostLabel.Visible = boostLeft > 0
		if boostLeft > 0 then
			boostLabel.Text = "2x DAMAGE  " .. Format.Time(boostLeft)
		end
	end
end

local function buildSlot(parent, def, order: number)
	local f = H.Frame(parent, { Color = Color3.fromRGB(20, 16, 34), Transparency = 0.1, Size = UDim2.fromOffset(88, 88), Order = order, Corner = 14, Stroke = 3 })
	local stroke = f:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = def.Color
	end
	UITheme.Gradient(f, Color3.new(1, 1, 1), Color3.fromRGB(150, 140, 190), 90)
	local key = UITheme.Label(f, { Text = "", Title = true, Size = UDim2.fromOffset(40, 22), Position = UDim2.fromOffset(4, 2), XAlign = Enum.TextXAlignment.Left, Color = def.Color, MaxText = 18 })
	local name = UITheme.Label(f, { Text = def.Name, Size = UDim2.new(1, -8, 0, 28), Position = UDim2.new(0, 4, 0.5, -10), MaxText = 15 })
	name.TextWrapped = true
	local cost = UITheme.Label(f, { Text = "", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -20), Color = Color3.fromRGB(120, 220, 255), MaxText = 13, StrokeThickness = 1 })
	local shade = H.Frame(f, { Color = Color3.new(0, 0, 0), Transparency = 0.35, Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), Corner = 14, ZIndex = 3 })
	local timer = UITheme.Label(f, { Text = "", Title = true, Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.25), ZIndex = 4, MaxText = 34 })
	timer.Visible = false
	-- tap / click the slot to use it (handy on touch screens)
	local btn = Instance.new("TextButton")
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Size = UDim2.fromScale(1, 1)
	btn.ZIndex = 5
	btn.Parent = f
	btn.Activated:Connect(function()
		Abilities.Press(def.Slot)
	end)
	table.insert(slots, { Def = def, Frame = f, Key = key, Name = name, Cost = cost, Shade = shade, Timer = timer })
end

function Hud.Init(ui, abilities)
	UI, Abilities = ui, abilities
	H = UI.Helpers
	local root = UI.Root()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	-- hotbar + bars (bottom centre)
	local bottom = H.Frame(root, { Transparency = 1, Size = UDim2.fromOffset(540, 160), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1) })
	bottom.Name = "Hotbar"
	local bars = H.Frame(bottom, { Transparency = 1, Size = UDim2.new(1, 0, 0, 58) })
	local hpBar = H.Frame(bars, { Color = Color3.fromRGB(20, 16, 30), Size = UDim2.new(1, 0, 0, 26), Corner = 13, Stroke = 2 })
	hpFill = H.Frame(hpBar, { Color = Color3.fromRGB(90, 230, 110), Size = UDim2.fromScale(1, 1), Corner = 13 })
	UITheme.Gradient(hpFill, Color3.new(1, 1, 1), Color3.fromRGB(140, 180, 140), 90)
	hpText = UITheme.Label(hpBar, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 17 })
	stBar = H.Frame(bars, { Color = Color3.fromRGB(20, 16, 30), Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 32), Corner = 11, Stroke = 2 })
	stFill = H.Frame(stBar, { Color = Color3.fromRGB(80, 190, 255), Size = UDim2.fromScale(1, 1), Corner = 11 })
	UITheme.Gradient(stFill, Color3.new(1, 1, 1), Color3.fromRGB(120, 150, 200), 90)
	stText = UITheme.Label(stBar, { Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 3, MaxText = 15 })

	local row = H.Frame(bottom, { Transparency = 1, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1) })
	H.List(row, 10, true)
	for i, def in ipairs(SLOTS) do
		buildSlot(row, def, i)
	end

	-- play-time widget (bottom left)
	local pt = H.Frame(root, { Color = Color3.fromRGB(18, 14, 32), Transparency = 0.1, Size = UDim2.fromOffset(310, 104), Position = UDim2.new(0, 14, 1, -14), AnchorPoint = Vector2.new(0, 1), Corner = 14, Stroke = 2 })
	pt.Name = "Playtime"
	UITheme.Label(pt, { Text = "PLAY-TIME REWARDS", Title = true, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 6), XAlign = Enum.TextXAlignment.Left, Color = C.Gold, MaxText = 18 })
	ptTimer = UITheme.Label(pt, { Text = "0:00", Title = true, Size = UDim2.fromOffset(80, 22), Position = UDim2.new(1, -10, 0, 6), AnchorPoint = Vector2.new(1, 0), XAlign = Enum.TextXAlignment.Right, MaxText = 20 })
	ptTitle = UITheme.Label(pt, { Text = "", Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 30), XAlign = Enum.TextXAlignment.Left, MaxText = 15 })
	local ptBar = H.Frame(pt, { Color = Color3.fromRGB(35, 28, 55), Size = UDim2.new(1, -20, 0, 12), Position = UDim2.fromOffset(10, 54), Corner = 6 })
	ptFill = H.Frame(ptBar, { Color = C.Gold, Size = UDim2.fromScale(0, 1), Corner = 6 })
	ptStreak = UITheme.Label(pt, { Text = "", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 74), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(150, 230, 255), MaxText = 14 })
	local open = Instance.new("TextButton")
	open.BackgroundTransparency = 1
	open.Text = ""
	open.Size = UDim2.fromScale(1, 1)
	open.Parent = pt
	open.Activated:Connect(function()
		UI.Toggle("Rewards")
	end)

	boostLabel = UITheme.Label(root, { Text = "", Title = true, Size = UDim2.fromOffset(320, 30), Position = UDim2.new(0.5, 0, 1, -182), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(255, 120, 90), MaxText = 24, StrokeThickness = 3 })
	boostLabel.Visible = false

	refreshKeys()
	UserInputService.LastInputTypeChanged:Connect(refreshKeys)
	player:GetAttributeChangedSignal("WeaponId"):Connect(Hud.RefreshSkillNames)
	Hud.RefreshSkillNames()
end

return Hud
