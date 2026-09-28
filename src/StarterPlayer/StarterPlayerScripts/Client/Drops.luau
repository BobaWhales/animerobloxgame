--!nonstrict
-- Drops (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/Drops
-- Client-rendered ore drops: pop out of the enemy, bob and glow (loot beams
-- for Epic+). Walk up and press F (the interact prompt) to pick them up -
-- one press grabs every ore within reach. Server-validated; the Auto-Collect
-- gamepass skips the prompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))
local SFX = require(Shared:WaitForChild("SFX"))

local Drops = {}
Drops.OnPickup = nil :: ((string, Vector3) -> ())?

local items = {}
local request: (string, any?) -> () = function() end

-- Pick up every idle drop within reach of the player.
local function collectNearby(root: BasePart?)
	if not root then
		return
	end
	local t = os.clock()
	for _, it in ipairs(items) do
		if it.State == "Idle" and it.Id and (root.Position - it.Gem.Position).Magnitude <= Config.PickupRadius + 2 then
			it.State = "Pending"
			it.NextTry = t + 1.5
			request("Collect", it.Id)
		end
	end
end

local function addPrompt(it)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "PickupPrompt"
	pp.ActionText = "Pick up"
	pp.ObjectText = it.Ore.Name
	pp.HoldDuration = 0
	pp.MaxActivationDistance = Config.PickupRadius
	pp.RequiresLineOfSight = false
	pp.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	pp.Style = Enum.ProximityPromptStyle.Custom -- drawn by Client/PromptUI
	pp.KeyboardKeyCode = Enum.KeyCode.F
	pp.GamepadKeyCode = Enum.KeyCode.DPadUp
	pp.Parent = it.Gem
	pp.Triggered:Connect(function()
		local char = Players.LocalPlayer.Character
		collectNearby(char and char:FindFirstChild("HumanoidRootPart") :: BasePart?)
	end)
	it.Prompt = pp
end

local function makeGem(ore)
	local order = ore.Order
	local size = 0.8 + order * 0.12
	local gem = VFX.FxPart({ Size = Vector3.one * size, Color = ore.Color, Transparency = 0 })
	gem.Name = "OreDrop"
	gem.Material = Enum.Material.Neon
	local l = Instance.new("PointLight")
	l.Color = ore.Color
	l.Range = 6 + order * 1.5
	l.Brightness = 1.2
	l.Parent = gem
	if order >= 3 then
		VFX.MakeEmitter("Stars", ore.Color, gem, 2 + order)
	end
	local beamHolder = nil
	if order >= 4 then
		beamHolder = VFX.FxPart({ Size = Vector3.one * 0.1, Transparency = 1 })
		local a0 = Instance.new("Attachment")
		a0.Parent = beamHolder
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 10 + order * 3, 0)
		a1.Parent = beamHolder
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Width0 = 1.4 + order * 0.2
		b.Width1 = 0.2
		b.FaceCamera = true
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = 3
		b.Color = ColorSequence.new(Color3.new(1, 1, 1), ore.Color)
		b.Transparency = VFX.NS(0, 0.2, 1, 1)
		b.Parent = beamHolder
		if order >= 5 then
			-- small, crisp label for rare drops (soft shadow, no heavy outline)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(110, 17)
			bb.StudsOffset = Vector3.new(0, 2.2, 0)
			bb.AlwaysOnTop = true
			bb.MaxDistance = 60
			bb.LightInfluence = 0
			bb.Adornee = gem
			bb.Parent = gem
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Config.Fonts.Heading
			t.TextScaled = true
			t.Text = ore.Name
			t.TextColor3 = ore.Color:Lerp(Color3.new(1, 1, 1), 0.2)
			t.Parent = bb
			local st = Instance.new("UIStroke")
			st.Thickness = 1
			st.Transparency = 0.45
			st.Parent = t
		end
	end
	return gem, beamHolder
end

function Drops.Init(requestFn)
	request = requestFn
end

-- payload = {Id?, Ore, Pos, Auto?}
function Drops.Spawn(payload)
	local ore = Config.OreById[payload.Ore]
	if not ore then
		return
	end
	local gem, beamHolder = makeGem(ore)
	local from = payload.Pos + Vector3.new(0, 2.5, 0)
	local ang = math.random() * math.pi * 2
	local land = Vector3.new(payload.Pos.X + math.cos(ang) * 2.5, payload.Pos.Y, payload.Pos.Z + math.sin(ang) * 2.5)
	gem.CFrame = CFrame.new(from)
	if beamHolder then
		beamHolder.CFrame = CFrame.new(land)
	end
	local item = {
		Gem = gem,
		Beam = beamHolder,
		Ore = ore,
		Id = payload.Id,
		State = "Pop",
		T = 0,
		From = from,
		Land = land,
		NextTry = 0,
		Expire = os.clock() + Config.DropLifetime,
		Auto = payload.Auto,
		Spin = math.random() * 6,
	}
	if ore.Order >= 4 then
		VFX.Flash(from, ore.Color, 5, 0.3)
		SFX.Play("RarePickup", { At = from, Volume = 0.5, Pitch = 0.8 })
	end
	table.insert(items, item)
end

local function find(id)
	for _, it in ipairs(items) do
		if it.Id == id then
			return it
		end
	end
	return nil
end

function Drops.Collected(id)
	local it = find(id)
	if it then
		it.State = "Fly"
		it.T = 0
		it.FlyFrom = it.Gem.Position
	end
end

function Drops.Fail(id, full: boolean?)
	local it = find(id)
	if it then
		it.State = "Idle"
		it.NextTry = os.clock() + (full and 3 or 1.5)
	end
end

local function destroy(it)
	it.Gem:Destroy()
	if it.Beam then
		it.Beam:Destroy()
	end
end

function Drops.Step(dt: number, root: BasePart?)
	local t = os.clock()
	for i = #items, 1, -1 do
		local it = items[i]
		it.T += dt
		it.Spin += dt * 2.5
		local remove = false
		if it.State == "Pop" then
			local a = math.min(1, it.T / 0.45)
			local pos = it.From:Lerp(it.Land, a) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
			it.Gem.CFrame = CFrame.new(pos) * CFrame.Angles(it.Spin, it.Spin * 0.7, 0)
			if a >= 1 then
				it.State = it.Auto and "Fly" or "Idle"
				it.T = 0
				it.FlyFrom = it.Gem.Position
				VFX.Emit(it.Land, "Sparks", 6, it.Ore.Color)
				if not it.Auto and it.Id then
					addPrompt(it)
				end
			end
		elseif it.State == "Idle" or it.State == "Pending" then
			local pos = it.Land + Vector3.new(0, 0.9 + math.sin(t * 3 + it.Spin) * 0.35, 0)
			it.Gem.CFrame = CFrame.new(pos) * CFrame.Angles(0.6, it.Spin, 0.6)
			if it.Beam then
				it.Beam.CFrame = CFrame.new(it.Land)
			end
			if it.Prompt then
				it.Prompt.Enabled = it.State == "Idle" and t >= it.NextTry
			end
			if it.State == "Pending" and t >= it.NextTry then
				it.State = "Idle"
			end
			if t > it.Expire then
				remove = true
			end
		elseif it.State == "Fly" then
			if it.Prompt then
				it.Prompt:Destroy()
				it.Prompt = nil
			end
			if it.Beam then
				it.Beam:Destroy()
				it.Beam = nil
			end
			local target = root and root.Position or it.FlyFrom
			local a = math.min(1, it.T / 0.28)
			local ease = a * a
			local pos = it.FlyFrom:Lerp(target, ease) + Vector3.new(0, math.sin(a * math.pi) * 2.5, 0)
			it.Gem.CFrame = CFrame.new(pos) * CFrame.Angles(it.Spin * 3, it.Spin * 3, 0)
			it.Gem.Size = Vector3.one * math.max(0.2, (0.8 + it.Ore.Order * 0.12) * (1 - a * 0.6))
			if a >= 1 then
				remove = true
				VFX.Emit(target, "Stars", 4 + it.Ore.Order, it.Ore.Color)
				if it.Ore.Order >= 4 then
					SFX.Play("RarePickup", { Pitch = 0.9 + it.Ore.Order * 0.05 })
				else
					SFX.Play("OrePickup", { Pitch = 0.85 + it.Ore.Order * 0.12 })
				end
				if Drops.OnPickup then
					Drops.OnPickup(it.Ore.Id, target)
				end
			end
		end
		if remove then
			destroy(it)
			table.remove(items, i)
		end
	end
end

function Drops.ClearAll()
	for _, it in ipairs(items) do
		destroy(it)
	end
	table.clear(items)
end

return Drops
