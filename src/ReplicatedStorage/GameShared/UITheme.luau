--!nonstrict
-- UITheme (ModuleScript) -> ReplicatedStorage/GameShared/UITheme
--
-- Skins every panel / button / icon with the images from UIPackPlus.
--   1. Insert UIPackPlus.rbxm into Studio (drag the file into the viewport).
--   2. Move the inserted object into ReplicatedStorage and name it "UIPackPlus".
--   3. Press Play. The Output window prints every image name found in the
--      pack. If a role below doesn't pick the image you want, put that
--      image's exact name at the FRONT of the role's list.
-- Without the pack, a clean built-in anime style is used instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local SFX = require(script.Parent:WaitForChild("SFX"))

local UITheme = {}

UITheme.PackNames = { "UIPackPlus", "UI Pack Plus", "UIPack", "UI Pack" }

-- Role -> candidate image names inside the pack (case-insensitive).
-- Exact matches win; otherwise the first image whose name CONTAINS a
-- candidate is used.
UITheme.Templates = {
	Panel = { "Panel", "Frame", "Window", "Background", "Menu", "Container", "Box" },
	Header = { "Header", "TitleBar", "Title", "Banner", "Ribbon" },
	Button = { "GreenButton", "Button_Green", "ButtonGreen", "Button", "Btn" },
	ButtonBlue = { "BlueButton", "Button_Blue", "ButtonBlue" },
	ButtonRed = { "RedButton", "Button_Red", "ButtonRed" },
	ButtonGold = { "YellowButton", "OrangeButton", "GoldButton", "Button_Yellow", "Button_Orange" },
	ButtonPurple = { "PurpleButton", "Button_Purple", "PinkButton" },
	Close = { "CloseButton", "Close", "Exit", "XButton", "X" },
	Slot = { "Slot", "Card", "Item", "Tile", "Cell" },
	Bar = { "Bar", "Pill", "Counter", "StatFrame", "Stat" },
	ProgressBack = { "ProgressBar", "BarBackground", "BarBg", "Progress" },
	Icon_Coins = { "Coin", "Coins", "Gold", "Money", "Cash" },
	Icon_Power = { "Power", "Strength", "Fist", "Muscle", "Lightning", "Energy" },
	Icon_Blade = { "Sword", "Weapon", "Blade", "Katana", "Attack" },
	Icon_Rebirth = { "Rebirth", "Star", "Prestige", "Crown" },
	Icon_Backpack = { "Backpack", "Bag", "Inventory", "Chest" },
	Icon_Shop = { "Shop", "Cart", "Store", "Robux" },
	Icon_Index = { "Index", "Book", "Collection", "Quest" },
	Icon_Race = { "Race", "DNA", "Dice", "Character", "Profile" },
	Icon_Teleport = { "Teleport", "Map", "World", "Portal" },
	Icon_Upgrades = { "Upgrade", "Arrow", "Up", "Level" },
	Icon_Overdrive = { "Potion", "Boost", "Flask", "Fire" },
	Icon_Settings = { "Settings", "Gear", "Cog", "Options" },
	Icon_Gem = { "Gem", "Diamond", "Crystal", "Ore" },
	Icon_Rune = { "Rune", "Magic", "Scroll" },
	Icon_Home = { "Home", "House", "Hub" },
	Icon_Tower = { "Tower", "Castle", "Trophy" },
}

UITheme.Colors = {
	Bg = Color3.fromRGB(24, 20, 40),
	Bg2 = Color3.fromRGB(44, 34, 74),
	Stroke = Color3.fromRGB(10, 8, 18),
	Text = Color3.new(1, 1, 1),
	Sub = Color3.fromRGB(200, 195, 225),
	Green = Color3.fromRGB(80, 220, 110),
	Blue = Color3.fromRGB(70, 160, 255),
	Red = Color3.fromRGB(255, 80, 95),
	Gold = Color3.fromRGB(255, 195, 50),
	Purple = Color3.fromRGB(170, 90, 255),
	Pink = Color3.fromRGB(255, 110, 190),
}
UITheme.TitleFont = Enum.Font.LuckiestGuy
UITheme.BodyFont = Enum.Font.FredokaOne

-- Emoji fallbacks when the pack has no icon for a role.
local ICON_TEXT = {
	Icon_Coins = "💰",
	Icon_Power = "💪",
	Icon_Blade = "⚔️",
	Icon_Rebirth = "🌟",
	Icon_Backpack = "🎒",
	Icon_Shop = "🛒",
	Icon_Index = "📖",
	Icon_Race = "🧬",
	Icon_Teleport = "🌀",
	Icon_Upgrades = "⬆️",
	Icon_Overdrive = "🔥",
	Icon_Settings = "⚙️",
	Icon_Gem = "💎",
	Icon_Rune = "🔮",
	Icon_Home = "🏠",
	Icon_Tower = "🗼",
}

local pack: Instance? = nil
local images: { [string]: ImageLabel | ImageButton } = {}
local imageNames: { string } = {}
local cache: { [string]: any } = {}

local function findPack(): Instance?
	for _, parent in ipairs({ ReplicatedStorage, StarterGui }) do
		for _, name in ipairs(UITheme.PackNames) do
			local p = parent:FindFirstChild(name)
			if p then
				return p
			end
		end
	end
	for _, c in ipairs(ReplicatedStorage:GetChildren()) do
		if c.Name:lower():find("uipack") then
			return c
		end
	end
	return nil
end

function UITheme.Init()
	pack = findPack()
	if not pack then
		print("[UITheme] UIPackPlus not found in ReplicatedStorage - using built-in style.")
		return
	end
	for _, d in ipairs(pack:GetDescendants()) do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
			local key = d.Name:lower()
			if not images[key] then
				images[key] = d
				table.insert(imageNames, d.Name)
			end
		end
	end
	table.sort(imageNames)
	print(("[UITheme] UIPackPlus found with %d images: %s"):format(#imageNames, table.concat(imageNames, ", ")))
end

function UITheme.HasPack(): boolean
	return pack ~= nil and #imageNames > 0
end

-- Returns the source image instance for a role (or nil).
function UITheme.Find(role: string)
	if cache[role] ~= nil then
		return cache[role] or nil
	end
	local candidates = UITheme.Templates[role]
	local found = nil
	if candidates and pack then
		for _, name in ipairs(candidates) do
			local img = images[name:lower()]
			if img then
				found = img
				break
			end
		end
		if not found then
			for _, name in ipairs(candidates) do
				local lower = name:lower()
				if #lower >= 3 then
					for _, n in ipairs(imageNames) do
						if n:lower():find(lower, 1, true) then
							found = images[n:lower()]
							break
						end
					end
				end
				if found then
					break
				end
			end
		end
	end
	cache[role] = found or false
	return found
end

-- Copy the image look (9-slice etc.) from a pack image onto ours.
local function applySkin(target: any, src)
	target.Image = src.Image
	target.ImageColor3 = src.ImageColor3
	target.ImageTransparency = src.ImageTransparency
	target.ScaleType = src.ScaleType
	target.SliceCenter = src.SliceCenter
	target.SliceScale = src.SliceScale
	target.ImageRectOffset = src.ImageRectOffset
	target.ImageRectSize = src.ImageRectSize
	target.ResampleMode = src.ResampleMode
	target.BackgroundTransparency = 1
end

---------------------------------------------------------------------
-- small builders
---------------------------------------------------------------------
function UITheme.Corner(inst: GuiObject, px: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 14)
	c.Parent = inst
	return c
end

function UITheme.Stroke(inst: GuiObject, thickness: number?, color: Color3?, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2.5
	s.Color = color or UITheme.Colors.Stroke
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = inst
	return s
end

function UITheme.Gradient(inst: GuiObject, a: Color3, b: Color3, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = inst
	return g
end

function UITheme.Label(parent: Instance, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.Title and UITheme.TitleFont or UITheme.BodyFont
	t.TextScaled = props.TextScaled ~= false
	t.TextColor3 = props.Color or UITheme.Colors.Text
	t.Text = props.Text or ""
	t.Size = props.Size or UDim2.fromScale(1, 1)
	t.Position = props.Position or UDim2.new()
	t.AnchorPoint = props.AnchorPoint or Vector2.zero
	t.TextXAlignment = props.XAlign or Enum.TextXAlignment.Center
	t.RichText = props.Rich == true
	t.ZIndex = props.ZIndex or 1
	t.LayoutOrder = props.Order or 0
	if props.TextSize then
		t.TextSize = props.TextSize
	end
	t.Name = props.Name or "Label"
	t.Parent = parent
	if props.Stroke ~= false then
		UITheme.Stroke(t, props.StrokeThickness or 2)
	end
	local cons = Instance.new("UITextSizeConstraint")
	cons.MaxTextSize = props.MaxText or 40
	cons.Parent = t
	return t
end

-- Icon: pack image if available, emoji otherwise.
function UITheme.Icon(parent: Instance, role: string, size: UDim2, pos: UDim2?, anchor: Vector2?)
	local src = UITheme.Find(role)
	local icon
	if src then
		icon = Instance.new("ImageLabel")
		applySkin(icon, src)
		icon.ScaleType = Enum.ScaleType.Fit
	else
		icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Text = ICON_TEXT[role] or "✦"
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
	end
	icon.Name = "Icon"
	icon.Size = size
	icon.Position = pos or UDim2.new()
	icon.AnchorPoint = anchor or Vector2.zero
	icon.Parent = parent
	return icon
end

-- Panel container. Returns (frame, content).
function UITheme.Panel(parent: Instance, props)
	local src = UITheme.Find(props.Role or "Panel")
	local frame
	if src then
		frame = Instance.new("ImageLabel")
		applySkin(frame, src)
	else
		frame = Instance.new("Frame")
		frame.BackgroundColor3 = UITheme.Colors.Bg
		UITheme.Corner(frame, 18)
		UITheme.Stroke(frame, 4, UITheme.Colors.Stroke, true)
		UITheme.Gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 200), 90)
		frame.BackgroundColor3 = UITheme.Colors.Bg2
	end
	frame.Name = props.Name or "Panel"
	frame.Size = props.Size
	frame.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	frame.ZIndex = props.ZIndex or 1
	frame.Parent = parent

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = frame
	local pad = Instance.new("UIPadding")
	local p = props.Padding or 14
	pad.PaddingTop = UDim.new(0, p)
	pad.PaddingBottom = UDim.new(0, p)
	pad.PaddingLeft = UDim.new(0, p)
	pad.PaddingRight = UDim.new(0, p)
	pad.Parent = content
	return frame, content
end

local COLOR_ROLE = {
	Green = "Button",
	Blue = "ButtonBlue",
	Red = "ButtonRed",
	Gold = "ButtonGold",
	Purple = "ButtonPurple",
}

-- Animated button with hover / press feedback and UI sounds.
function UITheme.Button(parent: Instance, props)
	local colorName = props.Color or "Green"
	local src = UITheme.Find(COLOR_ROLE[colorName] or "Button") or UITheme.Find("Button")
	local btn
	if src then
		btn = Instance.new("ImageButton")
		applySkin(btn, src)
		btn.AutoButtonColor = false
	else
		btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		local base = UITheme.Colors[colorName] or UITheme.Colors.Green
		btn.BackgroundColor3 = base
		UITheme.Corner(btn, props.Corner or 12)
		UITheme.Stroke(btn, 3, UITheme.Colors.Stroke, true)
		UITheme.Gradient(btn, Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175), 90)
		-- glossy top shine
		local shine = Instance.new("Frame")
		shine.Name = "Shine"
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BackgroundTransparency = 0.75
		shine.Size = UDim2.new(1, -10, 0.35, 0)
		shine.Position = UDim2.fromOffset(5, 4)
		shine.BorderSizePixel = 0
		UITheme.Corner(shine, 8)
		shine.Parent = btn
	end
	btn.Name = props.Name or "Button"
	btn.Size = props.Size or UDim2.fromOffset(160, 50)
	btn.Position = props.Position or UDim2.new()
	btn.AnchorPoint = props.AnchorPoint or Vector2.zero
	btn.LayoutOrder = props.Order or 0
	btn.ZIndex = props.ZIndex or 1
	btn.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = btn

	if props.Icon then
		UITheme.Icon(btn, props.Icon, UDim2.fromScale(props.Text and 0.62 or 0.8, props.Text and 0.62 or 0.8), UDim2.fromScale(0.5, props.Text and 0.4 or 0.5), Vector2.new(0.5, 0.5))
	end
	if props.Text then
		local label = UITheme.Label(btn, {
			Text = props.Text,
			Title = props.TitleFont ~= false,
			Size = props.Icon and UDim2.fromScale(1, 0.34) or UDim2.new(1, -12, 1, -8),
			Position = props.Icon and UDim2.fromScale(0, 0.68) or UDim2.fromOffset(6, 4),
			MaxText = props.MaxText or 28,
			ZIndex = btn.ZIndex + 1,
		})
		label.Name = "Text"
	end

	local hoverTween = TweenInfo.new(0.12, Enum.EasingStyle.Back)
	btn.MouseEnter:Connect(function()
		TweenService:Create(scale, hoverTween, { Scale = 1.06 }):Play()
		SFX.Play("UIHover")
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, hoverTween, { Scale = 1 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.92 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		TweenService:Create(scale, hoverTween, { Scale = 1.06 }):Play()
	end)
	if props.OnClick then
		btn.Activated:Connect(function()
			SFX.Play(props.Sound or "UIClick")
			props.OnClick()
		end)
	end
	return btn
end

function UITheme.SetButtonText(btn: GuiObject, text: string)
	local t = btn:FindFirstChild("Text")
	if t then
		(t :: TextLabel).Text = text
	end
end

return UITheme
