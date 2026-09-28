--!nonstrict
-- PromptUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/PromptUI
-- Custom ProximityPrompt UI (prompts use Style = Custom so Roblox draws
-- nothing). Each prompt gets an AlwaysOnTop BillboardGui with a CanvasGroup
-- that fades in on PromptShown and out on PromptHidden. The key cap follows
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

local function build(prompt: ProximityPrompt)
	local bb = Instance.new("BillboardGui")
	bb.Name = "CustomPrompt"
	bb.AlwaysOnTop = true
	bb.Active = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(300, 78)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.Adornee = adorneeFor(prompt)
	bb.ResetOnSpawn = false
	bb.Parent = player:WaitForChild("PlayerGui")

	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.GroupTransparency = 1
	group.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = 0.8
	scale.Parent = group

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -8, 1, -8)
	panel.BackgroundColor3 = Color3.fromRGB(18, 14, 32)
	panel.BackgroundTransparency = 0.15
	panel.Parent = group
	UITheme.Corner(panel, 16)
	UITheme.Stroke(panel, 2.5, Color3.fromRGB(190, 150, 255), true)
	UITheme.Gradient(panel, Color3.new(1, 1, 1), Color3.fromRGB(160, 150, 200), 90)

	local key = Instance.new("TextButton")
	key.Name = "Key"
	key.AutoButtonColor = false
	key.Size = UDim2.fromOffset(56, 56)
	key.Position = UDim2.fromOffset(8, 7)
	key.BackgroundColor3 = Color3.fromRGB(245, 240, 255)
	key.Font = UITheme.TitleFont
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(30, 20, 50)
	key.Text = ""
	key.Parent = panel
	UITheme.Corner(key, 12)
	UITheme.Stroke(key, 3, Color3.fromRGB(30, 20, 50), true)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = key

	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 8, 1, -4)
	fill.Size = UDim2.fromOffset(0, 4)
	fill.BackgroundColor3 = Color3.fromRGB(255, 210, 90)
	fill.BorderSizePixel = 0
	fill.Parent = panel

	UITheme.Label(panel, { Text = prompt.ActionText, Title = true, Size = UDim2.new(1, -80, 0, 32), Position = UDim2.fromOffset(74, 6), XAlign = Enum.TextXAlignment.Left, MaxText = 28 })
	UITheme.Label(panel, { Text = prompt.ObjectText, Size = UDim2.new(1, -80, 0, 22), Position = UDim2.fromOffset(74, 40), XAlign = Enum.TextXAlignment.Left, Color = Color3.fromRGB(200, 190, 230), MaxText = 18 })

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

	local entry = { Gui = bb, Group = group, Scale = scale, Key = key, Fill = fill, Panel = panel }
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
	TweenService:Create(entry.Group, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	TweenService:Create(entry.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
			entry.Fill.Size = UDim2.fromOffset(0, 4)
			TweenService:Create(entry.Fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -16, 0, 4) }):Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local entry = shown[prompt]
		if entry then
			TweenService:Create(entry.Fill, TweenInfo.new(0.15), { Size = UDim2.fromOffset(0, 4) }):Play()
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
