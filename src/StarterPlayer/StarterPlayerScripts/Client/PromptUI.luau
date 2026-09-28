--!nonstrict
-- PromptUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/PromptUI
-- Custom ProximityPrompt UI (prompts use Style = Custom so Roblox draws
-- nothing). Each prompt gets a small AlwaysOnTop BillboardGui (key cap +
-- text on a soft glow, no background box) in a CanvasGroup that fades in on
-- PromptShown and out on PromptHidden. The key cap follows
-- the player's current input device (keyboard / controller / touch), touch
-- users can tap the cap, and Triggered fires a RemoteEvent to the server.

local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local UITheme = require(Shared:WaitForChild("UITheme"))
local SFX = require(Shared:WaitForChild("SFX"))

local PromptUI = {}

local player = Players.LocalPlayer
local shown = {} -- [prompt] = { Gui, Group, Key, Fill, Button }

local GAMEPAD_NAMES = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	DPadUp = "D-Up",
	DPadDown = "D-Down",
	DPadLeft = "D-Left",
	DPadRight = "D-Right",
}

local function deviceType(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	if last.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Keyboard"
end
PromptUI.DeviceType = deviceType

local function keyText(prompt: ProximityPrompt, device: string): string
	if device == "Touch" then
		return "TAP"
	elseif device == "Gamepad" then
		return GAMEPAD_NAMES[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	end
	local k = prompt.KeyboardKeyCode
	local s = UserInputService:GetStringForKeyCode(k)
	return (s ~= nil and s ~= "") and s:upper() or k.Name
end

local function adorneeFor(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return parent
	end
	if parent and parent:IsA("Model") then
		return parent.PrimaryPart
	end
	return nil
end

-- Text with a light drop shadow (no heavy outline, no background box).
local function softText(parent: Instance, text: string, font: Enum.Font, color: Color3, pos: UDim2, size: UDim2, transparency: number)
	local shadow = Instance.new("TextLabel")
	shadow.BackgroundTransparency = 1
	shadow.Position = pos + UDim2.fromOffset(0, 1.5)
	shadow.Size = size
	shadow.Font = font
	shadow.TextScaled = true
	shadow.TextXAlignment = Enum.TextXAlignment.Left
	shadow.Text = text
	shadow.TextColor3 = Color3.fromRGB(6, 4, 14)
	shadow.TextTransparency = 0.5
	shadow.Parent = parent
	local t = shadow:Clone()
	t.Position = pos
	t.TextColor3 = color
	t.TextTransparency = transparency
	t.Parent = parent
	return t
end

-- Minimal prompt: a small key cap + action text on a soft glow. About 45%
-- smaller than the old boxed panel.
local function build(prompt: ProximityPrompt)
	local bb = Instance.new("BillboardGui")
	bb.Name = "CustomPrompt"
	bb.AlwaysOnTop = true
	bb.Active = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(190, 40)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.Adornee = adorneeFor(prompt)
	bb.ResetOnSpawn = false
	bb.Parent = player:WaitForChild("PlayerGui")

	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = group

	-- soft glow streak behind the text
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0, 0.5)
	glow.Position = UDim2.new(0, 10, 0.5, 0)
	glow.Size = UDim2.new(1, -10, 0.9, 0)
	glow.BackgroundColor3 = Color3.fromRGB(150, 120, 255)
	glow.BorderSizePixel = 0
	glow.Parent = group
	UITheme.Corner(glow, 20)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.6, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow

	local key = Instance.new("TextButton")
	key.Name = "Key"
	key.AutoButtonColor = false
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Size = UDim2.fromOffset(28, 28)
	key.Position = UDim2.new(0, 2, 0.5, 0)
	key.BackgroundColor3 = Color3.fromRGB(245, 242, 255)
	key.BackgroundTransparency = 0.1
	key.Font = Enum.Font.BuilderSansExtraBold
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(24, 18, 40)
	key.Text = ""
	key.Parent = group
	UITheme.Corner(key, 7)
	local ks = Instance.new("UIStroke")
	ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ks.Thickness = 1
	ks.Color = Color3.new(1, 1, 1)
	ks.Transparency = 0.3
	ks.Parent = key
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = key

	-- thin hold-progress line under the key cap
	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0, 0)
	fill.Position = UDim2.new(0, 2, 0.5, 16)
	fill.Size = UDim2.fromOffset(0, 2)
	fill.BackgroundColor3 = Color3.fromRGB(255, 215, 110)
	fill.BorderSizePixel = 0
	fill.Parent = group

	softText(group, prompt.ActionText, Enum.Font.BuilderSansBold, Color3.new(1, 1, 1), UDim2.fromOffset(38, 3), UDim2.new(1, -40, 0, 20), 0)
	softText(group, prompt.ObjectText, Enum.Font.BuilderSansMedium, Color3.fromRGB(215, 208, 240), UDim2.fromOffset(38, 23), UDim2.new(1, -40, 0, 13), 0.2)

	-- touch: tap the key cap to trigger
	key.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	key.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	local entry = { Gui = bb, Group = group, Scale = scale, Key = key, Fill = fill }
	return entry
end

local function refreshKey(prompt: ProximityPrompt, entry)
	local device = deviceType()
	entry.Key.Text = keyText(prompt, device)
end

local function show(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	local entry = shown[prompt]
	if entry and entry.Hiding then
		entry.Gui:Destroy()
		entry = nil
	end
	if not entry then
		entry = build(prompt)
		shown[prompt] = entry
	end
	refreshKey(prompt, entry)
	TweenService:Create(entry.Group, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	TweenService:Create(entry.Scale, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { Scale = 1 }):Play()
	SFX.Play("PromptShow")
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if not entry then
		return
	end
	entry.Hiding = true
	local tw = TweenService:Create(entry.Group, TweenInfo.new(0.18), { GroupTransparency = 1 })
	TweenService:Create(entry.Scale, TweenInfo.new(0.18), { Scale = 0.85 }):Play()
	tw:Play()
	tw.Completed:Once(function()
		if shown[prompt] == entry and entry.Hiding then
			shown[prompt] = nil
			entry.Gui:Destroy()
		end
	end)
end

function PromptUI.Init(interactRemote: RemoteEvent)
	ProximityPromptService.PromptShown:Connect(function(prompt)
		show(prompt)
	end)
	ProximityPromptService.PromptHidden:Connect(hide)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local entry = shown[prompt]
		if entry and prompt.HoldDuration > 0 then
			entry.Fill.Size = UDim2.fromOffset(0, 2)
			TweenService:Create(entry.Fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(28, 2) }):Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local entry = shown[prompt]
		if entry then
			TweenService:Create(entry.Fill, TweenInfo.new(0.15), { Size = UDim2.fromOffset(0, 2) }):Play()
		end
	end)

	-- Triggered -> server-authoritative interaction
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or prompt:GetAttribute("Action") == nil then
			return
		end
		SFX.Play("PromptTrigger")
		local entry = shown[prompt]
		if entry then
			entry.Scale.Scale = 0.9
			TweenService:Create(entry.Scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		interactRemote:FireServer(prompt)
	end)

	-- keep key caps in sync with the device the player is using
	UserInputService.LastInputTypeChanged:Connect(function()
		for prompt, entry in pairs(shown) do
			refreshKey(prompt, entry)
		end
	end)
end

return PromptUI
