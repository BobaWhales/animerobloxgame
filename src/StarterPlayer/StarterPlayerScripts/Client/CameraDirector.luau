--!nonstrict
-- CameraDirector (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/CameraDirector
-- Dynamic camera framing. When you walk near a point of interest (parts
-- tagged "POI" with a FrameRadius > 0: the Forge, altar, statue, portals,
-- tower...) or fight a boss (tagged "CameraFocus"), the camera eases a
-- little toward the landmark so both you and it sit in frame, pulls back a
-- couple of studs and tightens the FOV slightly. It is applied as an offset
-- on top of the normal camera (see VFX.CameraModifier), so it never fights
-- your own camera control, and it switches off in first person, in menus
-- and while the world map is open.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local CameraDirector = {}
CameraDirector.Enabled = true
CameraDirector.Blocked = nil :: (() -> boolean)?

local player = Players.LocalPlayer
local CAM = Config.Camera
local weight = 0
local focusPos: Vector3? = nil
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function candidates()
	local list = CollectionService:GetTagged("POI")
	for _, p in ipairs(CollectionService:GetTagged("CameraFocus")) do
		table.insert(list, p)
	end
	return list
end

-- Best landmark near the player: closest one inside its own radius.
local function pick(rootPos: Vector3): (Vector3?, number)
	local best, bestScore = nil, 0
	for _, part in ipairs(candidates()) do
		if part:IsA("BasePart") and part.Parent then
			local radius = part:GetAttribute("FrameRadius") or 0
			if radius > 0 then
				local d = (Vector3.new(part.Position.X, rootPos.Y, part.Position.Z) - rootPos).Magnitude
				if d < radius and d > 4 then
					-- full strength in the middle of the zone, easing to 0 at the edge
					local score = math.clamp((radius - d) / (radius * 0.45), 0, 1)
					if score > bestScore then
						best, bestScore = part.Position, score
					end
				end
			end
		end
	end
	return best, bestScore
end

local function modifier(cf: CFrame, dt: number): CFrame
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	local target = 0
	local poi = nil
	if CameraDirector.Enabled and root and head and cam and cam.CameraType == Enum.CameraType.Custom then
		local firstPerson = (cf.Position - head.Position).Magnitude < 2
		local blocked = CameraDirector.Blocked and CameraDirector.Blocked()
		if not firstPerson and not blocked then
			local p, score = pick(root.Position)
			if p then
				poi = p
				target = score
			end
		end
	end
	weight += (target - weight) * math.min(1, dt * 1.6)
	if poi then
		focusPos = poi
	end
	if weight < 0.002 or not focusPos or not root then
		VFX.SetFovOffset("Framing", 0)
		return cf
	end
	VFX.SetFovOffset("Framing", CAM.FramingFov * weight)

	-- lean the view toward the midpoint of you and the landmark
	local subject = root.Position + Vector3.new(0, 2, 0)
	local mid = subject:Lerp(focusPos, 0.5)
	local look = cf.LookVector
	local toMid = mid - cf.Position
	if toMid.Magnitude < 1 then
		return cf
	end
	toMid = toMid.Unit
	local facing = look:Dot(toMid)
	if facing < 0.2 then
		return cf -- landmark is behind the camera: leave the shot alone
	end
	local w = CAM.FramingWeight * weight * math.clamp((facing - 0.2) / 0.5, 0, 1)
	local newLook = look:Lerp(toMid, w).Unit

	-- pull back a little, but never through walls
	local pull = CAM.FramingPullBack * weight
	local pos = cf.Position
	if pull > 0.05 then
		rayParams.FilterDescendantsInstances = { char :: Instance }
		local back = -newLook * pull
		local hit = workspace:Raycast(pos, back, rayParams)
		pos += hit and back * math.max(0, (hit.Distance - 0.5) / pull) or back
	end
	return CFrame.lookAt(pos, pos + newLook, cf.UpVector)
end

function CameraDirector.Init()
	VFX.CameraModifier = modifier
end

return CameraDirector
