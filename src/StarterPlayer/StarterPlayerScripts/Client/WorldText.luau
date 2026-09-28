--!nonstrict
-- WorldText (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/WorldText
-- Proximity-based world text. Every BillboardGui tagged "WorldLabel" is
-- built by the server at 0% opacity (a "Fade" CanvasGroup). This module
-- measures the distance from your character to the label's part (closest
-- point on the part, so big landmarks work too) and smoothly fades the text
-- in inside Config.WorldText.ShowDistance, with a small rise + scale-in.
-- Labels that are fully hidden are disabled so they cost nothing to render.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))

local WorldText = {}

local player = Players.LocalPlayer
local W = Config.WorldText
local labels = {} -- [BillboardGui] = { Fade, Scale, Alpha, BaseOffset }

local function track(bb: Instance)
	if not bb:IsA("BillboardGui") or labels[bb] then
		return
	end
	local fade = bb:WaitForChild("Fade", 5)
	if not fade or not fade:IsA("CanvasGroup") then
		return
	end
	local scale = fade:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = fade
	fade.GroupTransparency = 1
	bb.Enabled = false
	labels[bb] = { Fade = fade, Scale = scale, Alpha = 0, BaseOffset = bb.StudsOffset }
end

local function untrack(bb: Instance)
	labels[bb] = nil
end

-- Distance from a point to the closest point on a part's box. Height above
-- or below the part is relaxed by VerticalSlack so tall signs still count.
local function distanceTo(part: BasePart, pos: Vector3): number
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	local dx = math.max(math.abs(rel.X) - half.X, 0)
	local dy = math.max(math.abs(rel.Y) - half.Y - W.VerticalSlack, 0)
	local dz = math.max(math.abs(rel.Z) - half.Z, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function adorneeOf(bb: BillboardGui): BasePart?
	local a = bb.Adornee or bb.Parent
	if a and a:IsA("BasePart") then
		return a
	elseif a and a:IsA("Model") then
		return a.PrimaryPart
	end
	return nil
end

function WorldText.Step(dt: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position
	local k = math.min(1, dt * 7)
	for bb, entry in pairs(labels) do
		if not bb.Parent then
			labels[bb] = nil
			continue
		end
		local target = 0
		local part = adorneeOf(bb)
		if pos and part then
			-- your own name tag never shows (it is clutter for you)
			if char and bb:IsDescendantOf(char) then
				target = 0
			else
				local show = bb:GetAttribute("Radius") or W.ShowDistance
				local d = distanceTo(part, pos)
				target = math.clamp((show + W.FadeBand - d) / W.FadeBand, 0, 1)
			end
		end
		local a = entry.Alpha + (target - entry.Alpha) * k
		if math.abs(a - target) < 0.01 then
			a = target
		end
		if a ~= entry.Alpha then
			entry.Alpha = a
			local eased = a * a * (3 - 2 * a) -- smoothstep
			entry.Fade.GroupTransparency = 1 - eased
			entry.Scale.Scale = 0.9 + 0.1 * eased
			bb.StudsOffset = entry.BaseOffset + Vector3.new(0, (eased - 1) * 0.4, 0)
		end
		local enabled = a > 0.001
		if bb.Enabled ~= enabled then
			bb.Enabled = enabled
		end
	end
end

function WorldText.Init()
	for _, bb in ipairs(CollectionService:GetTagged("WorldLabel")) do
		task.spawn(track, bb)
	end
	CollectionService:GetInstanceAddedSignal("WorldLabel"):Connect(function(bb)
		task.spawn(track, bb)
	end)
	CollectionService:GetInstanceRemovedSignal("WorldLabel"):Connect(untrack)
end

-- Updates a label's text (and its drop shadow).
function WorldText.SetText(bb: Instance, name: string, text: string)
	local t = bb:FindFirstChild(name, true)
	local s = bb:FindFirstChild(name .. "Shadow", true)
	if t and t:IsA("TextLabel") then
		t.Text = text
	end
	if s and s:IsA("TextLabel") then
		s.Text = text
	end
end

return WorldText
