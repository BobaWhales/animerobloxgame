--!nonstrict
-- Movement (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/Movement
-- Sprint + footsteps.
--   * Hold Left Shift (or click the left stick, L3) to sprint: +40% speed
--     and a soft, smoothed FOV widening.
--   * Footsteps: Roblox's looping default run sound is muted and replaced
--     by one-shot steps timed to distance travelled, with a different
--     layered sound per floor material (grass, stone, wood, metal, soft).
--     Nearby players get footsteps too; bosses stomp.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))
local SFX = require(Shared:WaitForChild("SFX"))

local Movement = {}
Movement.Sprinting = false

local player = Players.LocalPlayer
local S = Config.Sprint
local wantSprint = false
local baseSpeed: number? = nil
local settingSpeed = false
local walkers = {} -- [Model] = { Dist, Last, Foot }
local floorRay = RaycastParams.new()
floorRay.FilterType = Enum.RaycastFilterType.Exclude

local STEP_FOR = {
	[Enum.Material.Grass] = "StepGrass",
	[Enum.Material.LeafyGrass] = "StepGrass",
	[Enum.Material.Ground] = "StepGrass",
	[Enum.Material.Mud] = "StepGrass",
	[Enum.Material.Sand] = "StepSoft",
	[Enum.Material.Snow] = "StepSoft",
	[Enum.Material.Fabric] = "StepSoft",
	[Enum.Material.Wood] = "StepWood",
	[Enum.Material.WoodPlanks] = "StepWood",
	[Enum.Material.Metal] = "StepMetal",
	[Enum.Material.DiamondPlate] = "StepMetal",
	[Enum.Material.CorrodedMetal] = "StepMetal",
	[Enum.Material.Foil] = "StepMetal",
	[Enum.Material.ForceField] = "StepMetal",
}

local function humanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function applySpeed()
	local hum = humanoid()
	if not hum then
		return
	end
	baseSpeed = baseSpeed or hum.WalkSpeed
	settingSpeed = true
	hum.WalkSpeed = Movement.Sprinting and baseSpeed * S.SpeedMult or baseSpeed
	settingSpeed = false
end

local function onSprint(_, state)
	if state == Enum.UserInputState.Begin then
		wantSprint = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		wantSprint = false
	end
	return Enum.ContextActionResult.Pass
end

-- Mute the default looping run sound on a character (we play real steps).
local function muteDefaultRun(char: Model)
	task.spawn(function()
		local root = char:WaitForChild("HumanoidRootPart", 10)
		local running = root and root:WaitForChild("Running", 10)
		if running and running:IsA("Sound") then
			running.Volume = 0
		end
	end)
end

local function onCharacter(char: Model)
	baseSpeed = nil
	Movement.Sprinting = false
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		baseSpeed = hum.WalkSpeed
		-- the server can change WalkSpeed (races, Overdrive): respect it
		hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if not settingSpeed then
				-- a new base speed from the server; re-apply sprint on top of it
				baseSpeed = hum.WalkSpeed
				if Movement.Sprinting then
					task.defer(applySpeed)
				end
			end
		end)
	end
	muteDefaultRun(char)
end

local function stepFor(model: Model, hum: Humanoid?, root: BasePart, dt: number, heavy: boolean)
	local w = walkers[model]
	if not w then
		w = { Dist = 0, Last = root.Position, Foot = 1 }
		walkers[model] = w
	end
	local pos = root.Position
	local moved = Vector3.new(pos.X - w.Last.X, 0, pos.Z - w.Last.Z).Magnitude
	w.Last = pos
	local isLocal = model == player.Character
	-- FloorMaterial is only reliable for your own character
	local grounded = not isLocal or (hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air)
	if not grounded or moved > 20 then
		w.Dist = 0
		return
	end
	w.Dist += moved
	local speed = moved / math.max(dt, 1 / 240)
	local stride = heavy and 7 or (speed > 20 and 6.2 or 4.8)
	if w.Dist >= stride then
		w.Dist = 0
		w.Foot = -w.Foot
		local mat = Enum.Material.Slate
		if isLocal and hum then
			mat = hum.FloorMaterial
		else
			floorRay.FilterDescendantsInstances = { model }
			local hit = workspace:Raycast(pos, Vector3.new(0, heavy and -14 or -6, 0), floorRay)
			if not hit then
				return -- airborne
			end
			mat = hit.Material
		end
		local cue = heavy and "StepHeavy" or (STEP_FOR[mat] or "StepStone")
		local foot = pos - Vector3.new(0, heavy and 5 or 2.6, 0) + root.CFrame.RightVector * 0.5 * w.Foot
		SFX.Play(cue, { At = foot, Volume = isLocal and 0.9 or 0.6, Pitch = (w.Foot > 0 and 1.03 or 0.97) * (speed > 20 and 1.05 or 1) })
		if heavy then
			local me = player.Character
			local myRoot = me and me:FindFirstChild("HumanoidRootPart")
			if myRoot and (myRoot.Position - pos).Magnitude < 45 then
				VFX.Rumble(0.12)
			end
		end
	end
end

function Movement.Step(dt: number)
	-- sprint state
	local hum = humanoid()
	if hum then
		local sprint = wantSprint and hum.MoveDirection.Magnitude > 0.1 and hum.Health > 0
		if sprint ~= Movement.Sprinting then
			Movement.Sprinting = sprint
			applySpeed()
		end
	end
	VFX.SetFovOffset("Sprint", Movement.Sprinting and S.FovBoost or 0)

	-- footsteps for you + nearby players
	local me = player.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart")
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (p == player or (myRoot and (r.Position - myRoot.Position).Magnitude < 60)) then
			stepFor(c, h, r, dt, false)
		end
	end
	-- boss stomps
	for _, m in ipairs(CollectionService:GetTagged("Enemy")) do
		if m:GetAttribute("Boss") and (m:GetAttribute("HP") or 0) > 0 then
			local r = m:FindFirstChild("HumanoidRootPart")
			if r and myRoot and (r.Position - myRoot.Position).Magnitude < 90 then
				stepFor(m, nil, r, dt, true)
			end
		end
	end
	for model in pairs(walkers) do
		if not model.Parent then
			walkers[model] = nil
		end
	end
end

function Movement.Init()
	ContextActionService:BindAction("AnimeSprint", onSprint, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			p.CharacterAdded:Connect(muteDefaultRun)
			if p.Character then
				muteDefaultRun(p.Character)
			end
		end
	end
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(muteDefaultRun)
	end)
end

return Movement
