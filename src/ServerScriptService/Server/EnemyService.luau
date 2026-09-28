--!nonstrict
-- EnemyService (ModuleScript) -> ServerScriptService/Server/EnemyService
-- Chibi anime enemies for the Dungeon and the Boss Rush:
--   * Built by code from Config.EnemyArchetypes (big head, big anime eyes,
--     bold hair, outfit, gear and a weapon) on an R15 rig, so the default
--     Roblox animations still work. Optional catalog dressing via
--     Config.EnemyModelStyle = "Catalog".
--   * Enemies are spawned on demand by DungeonService (only when you walk
--     into a room) and TowerService; each belongs to one player.
--   * Animator with preloaded Idle / Walk / Run / BasicAttack /
--     SpecialWindup / SpecialRelease tracks.
--   * PathfindingService chasing + AI state machine for special attacks:
--     cooldown/proximity check -> wind-up anim + ground telegraph ->
--     release; damage lands on the animation's "Hit" keyframe/marker
--     (AnimationTrack.KeyframeReached) with a timed fallback.
--   * Attack rhythm: anticipation (lean back) -> strike -> recovery
--     (slumped, takes extra damage). Poses are sent as model attributes and
--     animated on each client (Client/EnemyFX).

local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))

local EnemyService = {}
EnemyService.Active = {} :: { any }
EnemyService.OnZenkai = nil :: ((Player) -> ())?
EnemyService.OnKill = nil :: ((Player, any) -> ())?
EnemyService.OnReward = nil :: ((Player, any) -> ())? -- per damager (mastery...)

local map = nil
local templates = {}
local animCache = {}
local AI = Config.EnemyAI
local B = Config.Balance

---------------------------------------------------------------------
-- RIG BUILDING  (chibi anime figures, built entirely by code)
---------------------------------------------------------------------
local function weldTo(anchor: BasePart, p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = p
	w.Parent = p
	p.Parent = anchor.Parent
end

-- Welded decoration on any body part (flat, clean materials).
local function piece(body: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = material ~= Enum.Material.Neon
	p.CFrame = body.CFrame * offset
	weldTo(body, p)
	return p
end

local function bodyPart(model: Model, r15: string, r6: string): BasePart?
	return (model:FindFirstChild(r15) or model:FindFirstChild(r6)) :: any
end

local function has(list, item: string): boolean
	return list ~= nil and table.find(list, item) ~= nil
end

local HEAD_SCALE = 1.55 -- chibi proportions: big head on a small body
local DARK = Color3.fromRGB(28, 24, 32)
local WHITE = Color3.fromRGB(250, 250, 252)

-- Blow the head up and re-seat it on the neck.
local function chibify(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	head.Size *= HEAD_SCALE
	if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
		mesh.Scale *= HEAD_SCALE
	end
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Attachment") then
			d.Position *= HEAD_SCALE
		elseif d:IsA("Decal") then
			d:Destroy() -- replaced by anime eyes
		end
	end
	local neck = model:FindFirstChild("Neck", true) :: Motor6D?
	if neck and neck:IsA("Motor6D") then
		neck.C1 = CFrame.new(neck.C1.Position * HEAD_SCALE) * neck.C1.Rotation
	end
end

-- Big anime eyes, angry brows, a small mouth.
local function buildFace(head: BasePart, look)
	local hs = head.Size
	local u = math.min(hs.X, hs.Y, hs.Z)
	local covered = has(look.Gear, "Mask") or has(look.Gear, "HollowMask") or has(look.Gear, "Blindfold")
	if not covered then
		for _, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * hs.X * 0.19, -hs.Y * 0.04, -hs.Z * 0.43)
			local white = piece(head, "EyeWhite", Vector3.new(u * 0.25, u * 0.33, u * 0.1), base, WHITE, Enum.PartType.Ball)
			white.CastShadow = false
			piece(head, "Iris", Vector3.new(u * 0.19, u * 0.26, u * 0.1), base * CFrame.new(side * -u * 0.015, -u * 0.02, -u * 0.02), look.Eye or DARK, Enum.PartType.Ball).CastShadow = false
			piece(head, "Pupil", Vector3.new(u * 0.09, u * 0.13, u * 0.1), base * CFrame.new(side * -u * 0.015, -u * 0.03, -u * 0.035), DARK, Enum.PartType.Ball).CastShadow = false
			local shine = piece(head, "Shine", Vector3.new(u * 0.06, u * 0.06, u * 0.04), base * CFrame.new(side * u * 0.03, u * 0.07, -u * 0.05), WHITE, Enum.PartType.Ball, Enum.Material.Neon)
			shine.CastShadow = false
			-- angled brow = angry anime glare
			piece(head, "Brow", Vector3.new(u * 0.26, u * 0.05, u * 0.05), CFrame.new(side * hs.X * 0.19, hs.Y * 0.15, -hs.Z * 0.46) * CFrame.Angles(0, 0, math.rad(side * 16)), look.HairColor or DARK).CastShadow = false
		end
		if has(look.Gear, "Eyepatch") then
			piece(head, "Eyepatch", Vector3.new(u * 0.3, u * 0.36, u * 0.06), CFrame.new(hs.X * 0.19, -hs.Y * 0.04, -hs.Z * 0.48), DARK, Enum.PartType.Ball)
			piece(head, "Strap", Vector3.new(hs.X * 1.04, u * 0.05, hs.Z * 1.04), CFrame.new(0, hs.Y * 0.06, 0) * CFrame.Angles(0, 0, math.rad(-14)), DARK)
		end
		if has(look.Gear, "Scouter") then
			piece(head, "Scouter", Vector3.new(u * 0.3, u * 0.24, u * 0.05), CFrame.new(-hs.X * 0.21, -hs.Y * 0.02, -hs.Z * 0.5), Color3.fromRGB(80, 255, 120), nil, Enum.Material.Neon).Transparency = 0.35
			piece(head, "ScouterArm", Vector3.new(u * 0.08, u * 0.3, u * 0.3), CFrame.new(-hs.X * 0.5, -hs.Y * 0.02, -hs.Z * 0.2), Color3.fromRGB(220, 220, 225))
		end
		if has(look.Gear, "Glasses") then
			for _, side in ipairs({ -1, 1 }) do
				local g = piece(head, "Glasses", Vector3.new(u * 0.04, u * 0.3, u * 0.3), CFrame.new(side * hs.X * 0.19, -hs.Y * 0.04, -hs.Z * 0.5) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 220, 255), Enum.PartType.Cylinder, Enum.Material.Glass)
				g.Transparency = 0.55
			end
		end
	end
	piece(head, "Mouth", Vector3.new(u * 0.14, u * 0.035, u * 0.04), CFrame.new(0, -hs.Y * 0.27, -hs.Z * 0.45), Color3.fromRGB(90, 40, 50)).CastShadow = false
	if has(look.Gear, "Marks") then
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				piece(head, "Mark", Vector3.new(u * 0.16, u * 0.03, u * 0.03), CFrame.new(side * hs.X * 0.33, -hs.Y * (0.12 + k * 0.07), -hs.Z * 0.4) * CFrame.Angles(0, side * math.rad(25), 0), look.Trim or DARK).CastShadow = false
			end
		end
	end
end

local function hair(head: BasePart, look)
	local hs = head.Size
	local u = math.min(hs.X, hs.Y, hs.Z)
	local c = look.HairColor or DARK
	local style = look.Hair or "Short"
	local function hp(name, size, offset, shape)
		return piece(head, name, size, offset, c, shape)
	end
	if style == "Bald" then
		return
	end
	-- cap that follows the skull
	hp("HairCap", Vector3.new(hs.X * 1.08, hs.Y * 0.72, hs.Z * 1.1), CFrame.new(0, hs.Y * 0.26, u * 0.05), Enum.PartType.Ball)
	if style == "Spiky" then
		for i = 1, 9 do
			local a = (i / 9) * math.pi * 2
			local tilt = CFrame.Angles(math.rad(42) * math.cos(a), 0, math.rad(42) * math.sin(a))
			hp("Spike", Vector3.new(u * 0.3, u * 0.9, u * 0.3), CFrame.new(math.sin(a) * u * 0.36, hs.Y * 0.52, math.cos(a) * u * 0.32 + u * 0.1) * tilt)
		end
		for i = -2, 2 do
			hp("Bang", Vector3.new(u * 0.2, u * 0.46, u * 0.14), CFrame.new(i * u * 0.2, hs.Y * 0.3, -hs.Z * 0.44) * CFrame.Angles(math.rad(-22), 0, math.rad(i * 12)))
		end
	elseif style == "Messy" then
		for i = 1, 12 do
			local a = (i / 12) * math.pi * 2
			hp("Tuft", Vector3.new(u * 0.34, u * 0.5, u * 0.34), CFrame.new(math.cos(a) * u * 0.42, hs.Y * (0.34 + (i % 3) * 0.06), math.sin(a) * u * 0.42) * CFrame.Angles(math.rad(20) * math.sin(a), a, math.rad(30) * math.cos(a)))
		end
		for i = -1, 1 do
			hp("Bang", Vector3.new(u * 0.26, u * 0.4, u * 0.14), CFrame.new(i * u * 0.26, hs.Y * 0.26, -hs.Z * 0.44) * CFrame.Angles(math.rad(-18), 0, math.rad(i * 20)))
		end
	elseif style == "Short" then
		hp("Fringe", Vector3.new(hs.X * 1.02, u * 0.24, u * 0.18), CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.44) * CFrame.Angles(math.rad(-12), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			hp("Side", Vector3.new(u * 0.14, hs.Y * 0.45, u * 0.5), CFrame.new(side * hs.X * 0.5, hs.Y * 0.05, 0))
		end
	elseif style == "Long" or style == "Ponytail" or style == "Twin" or style == "Bun" then
		hp("Fringe", Vector3.new(hs.X * 1.02, u * 0.28, u * 0.18), CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.44) * CFrame.Angles(math.rad(-14), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			hp("SideLock", Vector3.new(u * 0.2, hs.Y * (style == "Long" and 1.05 or 0.6), u * 0.34), CFrame.new(side * hs.X * 0.5, -hs.Y * (style == "Long" and 0.25 or 0.05), -u * 0.1))
		end
		if style == "Long" then
			hp("BackHair", Vector3.new(hs.X * 1.02, hs.Y * 1.6, u * 0.36), CFrame.new(0, -hs.Y * 0.22, hs.Z * 0.48))
		elseif style == "Ponytail" then
			hp("Tie", Vector3.one * u * 0.3, CFrame.new(0, hs.Y * 0.28, hs.Z * 0.5), Enum.PartType.Ball)
			hp("Tail", Vector3.new(u * 0.38, hs.Y * 1.3, u * 0.38), CFrame.new(0, -hs.Y * 0.2, hs.Z * 0.66) * CFrame.Angles(math.rad(15), 0, 0))
		elseif style == "Twin" then
			for _, side in ipairs({ -1, 1 }) do
				hp("TwinTail", Vector3.new(u * 0.34, hs.Y * 1.2, u * 0.34), CFrame.new(side * hs.X * 0.62, -hs.Y * 0.2, hs.Z * 0.2) * CFrame.Angles(0, 0, math.rad(side * 12)))
			end
		else
			hp("Bun", Vector3.one * u * 0.56, CFrame.new(0, hs.Y * 0.56, hs.Z * 0.3), Enum.PartType.Ball)
		end
	end
end

local function headGear(head: BasePart, look)
	local hs = head.Size
	local u = math.min(hs.X, hs.Y, hs.Z)
	local g = look.Gear or {}
	local trim = look.Trim or WHITE
	if has(g, "Headband") then
		piece(head, "Headband", Vector3.new(hs.X * 1.08, u * 0.16, hs.Z * 1.08), CFrame.new(0, hs.Y * 0.2, 0), Color3.fromRGB(34, 44, 90))
		piece(head, "Plate", Vector3.new(u * 0.46, u * 0.22, u * 0.06), CFrame.new(0, hs.Y * 0.2, -hs.Z * 0.55), Color3.fromRGB(205, 210, 220), nil, Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			piece(head, "BandTail", Vector3.new(u * 0.12, u * 0.5, u * 0.05), CFrame.new(side * u * 0.12, hs.Y * 0.05, hs.Z * 0.56) * CFrame.Angles(math.rad(25), 0, math.rad(side * 20)), Color3.fromRGB(34, 44, 90))
		end
	end
	if has(g, "Bandana") then
		piece(head, "Bandana", Vector3.new(hs.X * 1.1, u * 0.3, hs.Z * 1.1), CFrame.new(0, hs.Y * 0.3, 0), trim)
		piece(head, "Knot", Vector3.one * u * 0.24, CFrame.new(u * 0.2, hs.Y * 0.2, hs.Z * 0.55), trim, Enum.PartType.Ball)
	end
	if has(g, "Horns") then
		for _, side in ipairs({ -1, 1 }) do
			piece(head, "Horn", Vector3.new(u * 0.2, u * 0.75, u * 0.2), CFrame.new(side * hs.X * 0.33, hs.Y * 0.62, -hs.Z * 0.05) * CFrame.Angles(math.rad(-10), 0, math.rad(-side * 22)), Color3.fromRGB(240, 232, 218))
		end
	end
	if has(g, "Mask") then
		piece(head, "Mask", Vector3.new(hs.X * 0.98, hs.Y * 0.72, u * 0.12), CFrame.new(0, -hs.Y * 0.06, -hs.Z * 0.48), trim)
		for _, side in ipairs({ -1, 1 }) do
			piece(head, "EyeSlit", Vector3.new(u * 0.22, u * 0.05, u * 0.04), CFrame.new(side * hs.X * 0.2, hs.Y * 0.02, -hs.Z * 0.55) * CFrame.Angles(0, 0, math.rad(side * 12)), look.Eye or Color3.fromRGB(255, 60, 60), nil, Enum.Material.Neon)
		end
	end
	if has(g, "HollowMask") then
		piece(head, "HollowMask", Vector3.new(hs.X * 1.0, hs.Y * 0.8, u * 0.14), CFrame.new(0, -hs.Y * 0.04, -hs.Z * 0.48), WHITE)
		for _, side in ipairs({ -1, 1 }) do
			piece(head, "EyeHole", Vector3.new(u * 0.22, u * 0.18, u * 0.05), CFrame.new(side * hs.X * 0.2, hs.Y * 0.02, -hs.Z * 0.56), DARK, Enum.PartType.Ball)
			piece(head, "Stripe", Vector3.new(u * 0.05, hs.Y * 0.55, u * 0.03), CFrame.new(side * hs.X * 0.36, -hs.Y * 0.05, -hs.Z * 0.555), Color3.fromRGB(190, 30, 40))
		end
		piece(head, "Teeth", Vector3.new(u * 0.46, u * 0.08, u * 0.04), CFrame.new(0, -hs.Y * 0.3, -hs.Z * 0.56), DARK)
	end
	if has(g, "Blindfold") then
		piece(head, "Blindfold", Vector3.new(hs.X * 1.08, u * 0.24, hs.Z * 1.08), CFrame.new(0, -hs.Y * 0.02, 0), DARK)
	end
	if has(g, "Hood") then
		piece(head, "Hood", Vector3.new(hs.X * 1.22, hs.Y * 1.05, hs.Z * 1.2), CFrame.new(0, hs.Y * 0.14, u * 0.14), look.Top or DARK, Enum.PartType.Ball)
	end
	if has(g, "Crown") then
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			piece(head, "Crown", Vector3.new(u * 0.14, u * 0.4, u * 0.14), CFrame.new(math.cos(a) * u * 0.42, hs.Y * 0.72, math.sin(a) * u * 0.42), Color3.fromRGB(255, 205, 60), nil, Enum.Material.Neon)
		end
	end
	if has(g, "Halo") then
		piece(head, "Halo", Vector3.new(u * 0.08, u * 1.1, u * 1.1), CFrame.new(0, hs.Y * 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 240, 150), Enum.PartType.Cylinder, Enum.Material.Neon).Transparency = 0.2
	end
	if has(g, "Cap") then
		piece(head, "Cap", Vector3.new(u * 0.5, hs.X * 1.08, hs.X * 1.08), CFrame.new(0, hs.Y * 0.46, 0) * CFrame.Angles(0, 0, math.rad(90)), trim, Enum.PartType.Cylinder)
		piece(head, "Visor", Vector3.new(hs.X * 0.8, u * 0.06, u * 0.5), CFrame.new(0, hs.Y * 0.3, -hs.Z * 0.6), DARK)
	end
	if has(g, "StrawHat") or has(g, "CowboyHat") then
		local col = has(g, "StrawHat") and Color3.fromRGB(230, 200, 110) or Color3.fromRGB(150, 90, 50)
		piece(head, "HatBrim", Vector3.new(u * 0.1, u * 2.6, u * 2.6), CFrame.new(0, hs.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.PartType.Cylinder)
		piece(head, "HatCrown", Vector3.new(u * 0.6, u * 1.25, u * 1.25), CFrame.new(0, hs.Y * 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.PartType.Cylinder)
		piece(head, "HatBand", Vector3.new(u * 0.14, u * 1.28, u * 1.28), CFrame.new(0, hs.Y * 0.56, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 40, 40), Enum.PartType.Cylinder)
	end
	if has(g, "Antenna") then
		for _, side in ipairs({ -1, 1 }) do
			local a = piece(head, "Antenna", Vector3.new(u * 0.07, u * 0.7, u * 0.07), CFrame.new(side * u * 0.22, hs.Y * 0.72, -u * 0.05) * CFrame.Angles(0, 0, math.rad(-side * 15)), look.Skin or DARK)
			piece(a, "AntennaTip", Vector3.one * u * 0.14, CFrame.new(0, u * 0.36, 0), look.Skin or DARK, Enum.PartType.Ball)
		end
	end
end

local function outfit(model: Model, look)
	local up = bodyPart(model, "UpperTorso", "Torso")
	local low = bodyPart(model, "LowerTorso", "Torso")
	if not up then
		return
	end
	local ts = up.Size
	local u = ts.X / 2
	local top, bottom, trim = look.Top or DARK, look.Bottom or DARK, look.Trim or WHITE
	local kind = look.Outfit or "Vest"
	local g = look.Gear or {}
	local function belt(color)
		if low then
			piece(low, "Belt", Vector3.new(low.Size.X * 1.08, u * 0.22, low.Size.Z * 1.1), CFrame.new(0, low.Size.Y * 0.3, 0), color)
		end
	end
	local function skirt(color, len)
		if low then
			piece(low, "Skirt", Vector3.new(low.Size.X * 1.18, len, low.Size.Z * 1.25), CFrame.new(0, -len / 2 + low.Size.Y * 0.2, 0), color)
		end
	end
	if kind == "Vest" then
		piece(up, "Vest", Vector3.new(ts.X * 1.08, ts.Y * 0.95, ts.Z * 1.15), CFrame.new(0, -ts.Y * 0.02, 0), top)
		piece(up, "Collar", Vector3.new(ts.X * 0.9, u * 0.22, ts.Z * 1.2), CFrame.new(0, ts.Y * 0.46, 0), trim)
		belt(trim)
	elseif kind == "Robe" or kind == "Gi" then
		for _, side in ipairs({ -1, 1 }) do
			piece(up, "Lapel", Vector3.new(u * 0.26, ts.Y * 0.9, u * 0.05), CFrame.new(side * u * 0.2, ts.Y * 0.02, -ts.Z * 0.52) * CFrame.Angles(0, 0, math.rad(side * 24)), trim)
		end
		belt(kind == "Gi" and DARK or trim)
		if kind == "Robe" then
			skirt(bottom, u * 1.9)
		end
	elseif kind == "Coat" or kind == "Cloak" then
		piece(up, "CoatBack", Vector3.new(ts.X * 1.12, ts.Y * 2.3, u * 0.12), CFrame.new(0, -ts.Y * 0.62, ts.Z * 0.56), top)
		for _, side in ipairs({ -1, 1 }) do
			piece(up, "CoatFront", Vector3.new(u * 0.5, ts.Y * 2.1, u * 0.1), CFrame.new(side * u * 0.55, -ts.Y * 0.55, -ts.Z * 0.56), top)
		end
		piece(up, "HighCollar", Vector3.new(ts.X * 1.05, u * 0.5, ts.Z * 1.3), CFrame.new(0, ts.Y * 0.52, 0.05), kind == "Cloak" and top or trim)
		if kind == "Cloak" then
			for i = 1, 3 do
				piece(up, "CloudMark", Vector3.new(u * 0.08, u * 0.34, u * 0.5), CFrame.new(-ts.X * 0.58, -ts.Y * (i * 0.45), 0) * CFrame.Angles(0, 0, 0), trim, Enum.PartType.Ball)
			end
		end
	elseif kind == "Armor" then
		piece(up, "ChestPlate", Vector3.new(ts.X * 1.1, ts.Y * 0.7, ts.Z * 1.2), CFrame.new(0, ts.Y * 0.1, 0), trim, nil, Enum.Material.Metal).Reflectance = 0.1
		belt(DARK)
	elseif kind == "Uniform" then
		piece(up, "Jacket", Vector3.new(ts.X * 1.06, ts.Y * 0.7, ts.Z * 1.12), CFrame.new(0, ts.Y * 0.14, 0), top)
		piece(up, "Collar", Vector3.new(ts.X * 0.7, u * 0.2, ts.Z * 1.16), CFrame.new(0, ts.Y * 0.48, 0), trim)
		for _, side in ipairs({ -1, 1 }) do
			piece(up, "Strap", Vector3.new(u * 0.1, ts.Y * 1.02, ts.Z * 1.16), CFrame.new(side * u * 0.42, 0, 0), DARK)
		end
		belt(DARK)
	end
	-- back / neck gear
	if has(g, "Scarf") then
		piece(up, "Scarf", Vector3.new(ts.X * 0.95, u * 0.36, ts.Z * 1.3), CFrame.new(0, ts.Y * 0.52, 0), trim)
		piece(up, "ScarfTail", Vector3.new(u * 0.3, ts.Y * 1.3, u * 0.06), CFrame.new(u * 0.35, -ts.Y * 0.1, ts.Z * 0.6) * CFrame.Angles(math.rad(22), 0, math.rad(10)), trim)
	end
	if has(g, "Cape") or has(g, "Haori") then
		local col = has(g, "Haori") and WHITE or trim
		piece(up, "Cape", Vector3.new(ts.X * 1.2, ts.Y * 2.4, u * 0.08), CFrame.new(0, -ts.Y * 0.68, ts.Z * 0.62) * CFrame.Angles(math.rad(6), 0, 0), col)
		if has(g, "Haori") then
			for _, side in ipairs({ -1, 1 }) do
				piece(up, "HaoriFront", Vector3.new(u * 0.3, ts.Y * 2.2, u * 0.06), CFrame.new(side * u * 0.78, -ts.Y * 0.6, -ts.Z * 0.6), col)
			end
		end
	end
	if has(g, "Gourd") then
		local tan = Color3.fromRGB(205, 170, 120)
		local gr = piece(up, "Gourd", Vector3.one * u * 1.6, CFrame.new(0, -ts.Y * 0.1, ts.Z * 0.5 + u * 0.7), tan, Enum.PartType.Ball)
		piece(gr, "GourdTop", Vector3.one * u * 1.0, CFrame.new(-u * 0.3, u * 1.0, 0), tan, Enum.PartType.Ball)
		piece(up, "GourdStrap", Vector3.new(u * 0.14, ts.Y * 1.3, ts.Z * 1.2), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(40)), Color3.fromRGB(120, 60, 40))
	end
	if has(g, "Wings") then
		for _, side in ipairs({ -1, 1 }) do
			local w = piece(up, "Wing", Vector3.new(u * 0.1, ts.Y * 1.5, u * 1.4), CFrame.new(side * u * 0.9, ts.Y * 0.3, ts.Z * 0.5 + u * 0.4) * CFrame.Angles(math.rad(-20), side * math.rad(35), side * math.rad(-30)), trim)
			w.Transparency = 0.1
		end
	end
	if has(g, "Tails") and low then
		local col = look.Aura or trim
		for i = 1, 5 do
			local a = math.rad((i - 3) * 22)
			local t1 = piece(low, "Tail", Vector3.new(u * 0.45, u * 1.4, u * 0.45), CFrame.new(math.sin(a) * u * 0.6, 0, low.Size.Z * 0.5 + u * 0.4) * CFrame.Angles(math.rad(55), 0, a), col, Enum.PartType.Ball)
			t1.Material = Enum.Material.Neon
			t1.Transparency = 0.25
		end
	end
end

local function weapon(model: Model, look)
	local rh = bodyPart(model, "RightHand", "Right Arm")
	local lh = bodyPart(model, "LeftHand", "Left Arm")
	if not rh then
		return
	end
	local u = rh.Size.X
	local steel = Color3.fromRGB(215, 222, 235)
	local grip = CFrame.new(0, -rh.Size.Y * 0.4, 0)
	local kind = look.Weapon or "Fists"
	local accent = look.Trim or WHITE
	local glow = look.Aura or look.Eye or accent
	local function blade(hand: BasePart, len: number, width: number)
		piece(hand, "Handle", Vector3.new(u * 0.3, u * 1.2, u * 0.3), grip, DARK)
		piece(hand, "Guard", Vector3.new(u * 1.0, u * 0.14, u * 0.5), grip * CFrame.new(0, 0, -u * 0.7) * CFrame.Angles(math.rad(90), 0, 0), accent)
		local b = piece(hand, "Blade", Vector3.new(width, u * 0.12, len), grip * CFrame.new(0, 0, -u * 0.7 - len / 2), steel, nil, Enum.Material.Metal)
		b.Reflectance = 0.2
		piece(hand, "Edge", Vector3.new(width * 0.3, u * 0.13, len * 0.96), grip * CFrame.new(width * 0.4, 0, -u * 0.7 - len / 2), glow, nil, Enum.Material.Neon)
	end
	if kind == "Katana" then
		blade(rh, u * 4.2, u * 0.35)
	elseif kind == "Kunai" then
		blade(rh, u * 1.3, u * 0.4)
	elseif kind == "Blades" then
		blade(rh, u * 2.2, u * 0.34)
		if lh then
			blade(lh, u * 2.2, u * 0.34)
		end
	elseif kind == "Staff" or kind == "Scythe" then
		local pole = piece(rh, "Pole", Vector3.new(u * 0.25, u * 6, u * 0.25), grip * CFrame.new(0, u * 1.2, 0), Color3.fromRGB(90, 60, 40))
		if kind == "Staff" then
			piece(pole, "Orb", Vector3.one * u * 0.9, CFrame.new(0, u * 3.1, 0), glow, Enum.PartType.Ball, Enum.Material.Neon)
		else
			piece(pole, "ScytheBlade", Vector3.new(u * 0.12, u * 0.5, u * 3.2), CFrame.new(0, u * 2.9, -u * 1.4), steel, nil, Enum.Material.Metal)
		end
	elseif kind == "Club" then
		local club = piece(rh, "Club", Vector3.new(u * 0.9, u * 3.2, u * 0.9), grip * CFrame.new(0, 0, -u * 1.7) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(110, 80, 60))
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2
			piece(club, "Spike", Vector3.one * u * 0.3, CFrame.new(math.cos(a) * u * 0.45, u * 1.1, math.sin(a) * u * 0.45), steel)
		end
	elseif kind == "Gun" then
		piece(rh, "Gun", Vector3.new(u * 0.4, u * 0.55, u * 1.3), grip * CFrame.new(0, 0, -u * 0.5), DARK, nil, Enum.Material.Metal)
	elseif kind == "Bow" then
		for k = -2, 2 do
			piece(lh or rh, "Bow", Vector3.new(u * 0.16, u * 0.9, u * 0.16), CFrame.new(0, -u * 0.4 + k * u * 0.75, -u * 0.3 - math.abs(k) * -u * 0.12) * CFrame.Angles(math.rad(-k * 14), 0, 0), accent)
		end
	elseif kind == "Fan" then
		piece(rh, "Fan", Vector3.new(u * 0.1, u * 2.6, u * 2.6), grip * CFrame.new(0, u * 0.6, -u * 0.6) * CFrame.Angles(0, math.rad(90), 0), accent, Enum.PartType.Cylinder)
	else -- Fists: wrapped hands
		for _, hnd in ipairs({ rh, lh }) do
			if hnd then
				piece(hnd, "Wrap", Vector3.new(hnd.Size.X * 1.12, hnd.Size.Y * 0.6, hnd.Size.Z * 1.12), CFrame.new(0, hnd.Size.Y * 0.1, 0), accent)
			end
		end
	end
end

-- Chibi anime figure for an archetype (R15 from a HumanoidDescription).
local function buildChibi(look, desc: HumanoidDescription?): Model
	local skin = look.Skin or Color3.fromRGB(245, 208, 178)
	local sleeves = look.Outfit ~= "Vest" and look.Outfit ~= "Bare"
	desc = desc or Instance.new("HumanoidDescription")
	local d = desc :: HumanoidDescription
	d.HeadColor = skin
	d.TorsoColor = look.Outfit == "Bare" and skin or (look.Top or skin)
	d.LeftArmColor = sleeves and (look.Top or skin) or skin
	d.RightArmColor = d.LeftArmColor
	d.LeftLegColor = look.Outfit == "Bare" and skin or (look.Bottom or skin)
	d.RightLegColor = d.LeftLegColor
	d.HeightScale = 0.85
	d.WidthScale = 1
	d.DepthScale = 1
	d.HeadScale = 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil :: any
	end
	for _, x in ipairs(model:GetDescendants()) do
		if x:IsA("Script") or x:IsA("LocalScript") then
			x:Destroy()
		elseif x:IsA("BasePart") and x.Name ~= "HumanoidRootPart" then
			x.Material = Enum.Material.SmoothPlastic
			x.Reflectance = 0
			if x.Name == "LeftHand" or x.Name == "RightHand" then
				x.Color = skin
			end
		end
	end
	chibify(model)
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		buildFace(head, look)
		hair(head, look)
		headGear(head, look)
	end
	outfit(model, look)
	weapon(model, look)
	return model
end

-- Optional: dress the rig from the catalog (Config.EnemyModelStyle = "Catalog").
local catalogCache = {}
local function catalogIds(keyword: string?, assetType: Enum.AvatarAssetType): { number }
	if not keyword or keyword == "" then
		return {}
	end
	local key = keyword .. "|" .. assetType.Name
	if catalogCache[key] then
		return catalogCache[key]
	end
	local ids = {}
	pcall(function()
		local params = CatalogSearchParams.new()
		params.SearchKeyword = keyword
		params.AssetTypes = { assetType }
		params.IncludeOffSale = true
		params.Limit = 30
		for _, item in ipairs(AvatarEditorService:SearchCatalogAsync(params):GetCurrentPage()) do
			local id = type(item) == "table" and tonumber(item.Id)
			if id then
				table.insert(ids, id)
			end
		end
	end)
	catalogCache[key] = ids
	return ids
end

local function catalogDescription(lookId: string): HumanoidDescription?
	local userId = Config.EnemyAvatarUserIds[lookId]
	if userId then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		end)
		if ok and desc then
			return desc
		end
	end
	local kw = Config.EnemyAvatarKeywords[lookId]
	if not kw then
		return nil
	end
	local desc = Instance.new("HumanoidDescription")
	local hairIds = catalogIds(kw.Hair, Enum.AvatarAssetType.HairAccessory)
	if #hairIds > 0 then
		desc.HairAccessory = tostring(hairIds[1])
	end
	local hatIds = catalogIds(kw.Hat, Enum.AvatarAssetType.Hat)
	if #hatIds > 0 then
		desc.HatAccessory = tostring(hatIds[1])
	end
	local shirts = catalogIds(kw.Shirt, Enum.AvatarAssetType.Shirt)
	if #shirts > 0 then
		desc.Shirt = shirts[1]
	end
	local pants = catalogIds(kw.Pants, Enum.AvatarAssetType.Pants)
	if #pants > 0 then
		desc.Pants = pants[1]
	end
	return desc
end

local FALLBACK_LOOK = { Skin = Color3.fromRGB(245, 208, 178), Hair = "Spiky", HairColor = DARK, Eye = Color3.fromRGB(255, 60, 60), Top = Color3.fromRGB(60, 60, 80), Bottom = DARK, Outfit = "Vest", Gear = { "Headband" }, Weapon = "Kunai" }

-- Hand-built R6 rig (last-resort fallback if R15 creation fails).
local function buildR6(look): Model
	local m = Instance.new("Model")
	local function p(name, size, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = m
		return part
	end
	local root = p("HumanoidRootPart", Vector3.new(2, 2, 1), look.Top)
	root.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), look.Top)
	local head = p("Head", Vector3.new(2, 1, 1) * 1.5, look.Skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local la = p("Left Arm", Vector3.new(1, 2, 1), look.Skin)
	local ra = p("Right Arm", Vector3.new(1, 2, 1), look.Skin)
	local ll = p("Left Leg", Vector3.new(1, 2, 1), look.Bottom)
	local rl = p("Right Leg", Vector3.new(1, 2, 1), look.Bottom)
	local function motor(name, p0, p1, c0, c1)
		local mo = Instance.new("Motor6D")
		mo.Name = name
		mo.Part0 = p0
		mo.Part1 = p1
		mo.C0 = c0
		mo.C1 = c1
		mo.Parent = p0
	end
	local rj = CFrame.Angles(math.rad(-90), 0, math.rad(180))
	motor("RootJoint", root, torso, rj, rj)
	motor("Neck", torso, head, CFrame.new(0, 1, 0) * rj, CFrame.new(0, -0.75, 0) * rj)
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0) * CFrame.Angles(0, math.rad(90), 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, math.rad(-90), 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.Parent = m
	m.PrimaryPart = root
	root.CFrame = CFrame.new(0, 3, 0)
	torso.CFrame = root.CFrame
	head.CFrame = root.CFrame * CFrame.new(0, 1.75, 0)
	ra.CFrame = root.CFrame * CFrame.new(1.5, 0, 0)
	la.CFrame = root.CFrame * CFrame.new(-1.5, 0, 0)
	rl.CFrame = root.CFrame * CFrame.new(0.5, -2, 0)
	ll.CFrame = root.CFrame * CFrame.new(-0.5, -2, 0)
	buildFace(head, look)
	hair(head, look)
	headGear(head, look)
	return m
end

local function buildTemplate(lookId: string): Model
	local look = Config.EnemyArchetypes[lookId] or FALLBACK_LOOK
	local model = nil
	if Config.EnemyModelStyle == "Catalog" then
		local desc = catalogDescription(lookId)
		if desc then
			local ok, m = pcall(function()
				return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
			end)
			if ok and m then
				model = m
				chibify(model)
			end
		end
	end
	model = model or buildChibi(look)
	if not model then
		warn("[Enemies] R15 rig build failed for " .. tostring(lookId) .. ", using R6 fallback")
		model = buildR6(look)
	end
	model:SetAttribute("CoreColor", look.Aura or look.Eye or Color3.fromRGB(255, 80, 80))
	model:SetAttribute("Archetype", lookId)
	return model
end

---------------------------------------------------------------------
-- ANIMATION
---------------------------------------------------------------------
local function animation(id: string): Animation
	local a = animCache[id]
	if not a then
		a = Instance.new("Animation")
		a.AnimationId = id
		animCache[id] = a
	end
	return a
end

local function loadTracks(hum: Humanoid)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local set = hum.RigType == Enum.HumanoidRigType.R15 and Config.EnemyAnims.R15 or Config.EnemyAnims.R6
	local tracks = {}
	for key, id in pairs(set) do
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation(id))
		end)
		if ok and track then
			tracks[key] = track
			if key == "Idle" or key == "Walk" or key == "Run" then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Core
			else
				track.Priority = Enum.AnimationPriority.Action
			end
		end
	end
	return tracks
end

-- Waits for a "Hit" keyframe / marker on the track, or the fallback time.
local function waitForHit(track: AnimationTrack?, fallback: number)
	local done = Instance.new("BindableEvent")
	local fired = false
	local function fire()
		if not fired then
			fired = true
			done:Fire()
		end
	end
	local conns = {}
	if track then
		table.insert(conns, track.KeyframeReached:Connect(function(name)
			if name == "Hit" then
				fire()
			end
		end))
		table.insert(conns, track:GetMarkerReachedSignal("Hit"):Connect(fire))
	end
	task.delay(fallback, fire)
	if not fired then
		done.Event:Wait()
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	done:Destroy()
end

---------------------------------------------------------------------
-- POSES (animated on each client by Client/EnemyFX)
---------------------------------------------------------------------
-- Anticipate / Strike / Recover / Windup / Stagger / Idle
local function setPose(e, pose: string, duration: number?)
	e.PoseId = (e.PoseId or 0) + 1
	e.Model:SetAttribute("Pose", pose)
	e.Model:SetAttribute("PoseDur", duration or 0)
	e.Model:SetAttribute("PoseId", e.PoseId)
end

-- Elite variant: clothes pulled toward a dark tone, every glowing accent,
-- plate and rune switched to gold.
local GLOW_PARTS = { Iris = true, Edge = true, Orb = true, EyeSlit = true, Halo = true, Crown = true, Tail = true }
local ARMOR_PARTS = { ChestPlate = true, Plate = true, Guard = true, Belt = true }
local function applyElitePalette(model: Model)
	local E = Config.EliteLook
	for _, d in ipairs(model:GetDescendants()) do
		local name = d.Name
		if d:IsA("PointLight") then
			if name == "CoreLight" then
				d.Color = E.Trim
			end
		elseif d:IsA("BasePart") and name ~= "HumanoidRootPart" then
			if GLOW_PARTS[name] then
				d.Color = E.Trim
			elseif ARMOR_PARTS[name] then
				d.Color = E.Trim:Lerp(Color3.new(0, 0, 0), 0.35)
				d.Reflectance = 0.25
			elseif name ~= "Head" and name:find("Hand") == nil and name ~= "EyeWhite" and name ~= "Shine" and name ~= "Pupil" then
				d.Color = d.Color:Lerp(E.Palette, 0.55)
			end
		end
	end
	model:SetAttribute("CoreColor", E.Trim)
	-- gold crest above the brow
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		local crest = piece(head, "Crest", Vector3.new(0.12, head.Size.Y * 0.35, head.Size.Z * 0.1), CFrame.new(0, head.Size.Y * 0.42, -head.Size.Z * 0.46) * CFrame.Angles(0, 0, math.rad(45)), E.Trim, nil, Enum.Material.Neon)
		crest.CastShadow = false
	end
end

---------------------------------------------------------------------
-- SPAWNING
---------------------------------------------------------------------
local function randomPoint(minV: Vector3, maxV: Vector3): Vector3
	return Vector3.new(math.random() * (maxV.X - minV.X) + minV.X, minV.Y, math.random() * (maxV.Z - minV.Z) + minV.Z)
end

local function tierKey(e): string
	return e.Boss and "Boss" or (e.Elite and "Elite" or "Normal")
end

local building = {}
local function templateFor(lookId: string): Model
	while building[lookId] do
		task.wait(0.1)
	end
	local template = templates[lookId]
	if not template then
		building[lookId] = true
		template = buildTemplate(lookId)
		templates[lookId] = template
		building[lookId] = nil
	end
	return template
end
EnemyService.Prebuild = function(lookId: string)
	task.spawn(templateFor, lookId)
end

function EnemyService.Create(opts)
	local template = templateFor(opts.Look or "RogueGenin")
	local model = template:Clone()
	model.Name = opts.Label
	if opts.Elite then
		applyElitePalette(model)
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	if opts.Scale and opts.Scale ~= 1 then
		pcall(function()
			model:ScaleTo(opts.Scale)
		end)
	end
	hum.WalkSpeed = opts.Speed or 12
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, st in ipairs({ Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated }) do
		hum:SetStateEnabled(st, false)
	end
	local rootY = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + root.Size.Y / 2) or 3 * (opts.Scale or 1)
	model:PivotTo(CFrame.new(opts.Position.X, opts.Position.Y + rootY + 0.3, opts.Position.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	local color = opts.Color or Color3.new(1, 1, 1)
	if opts.Boss then
		local aura = Instance.new("Attachment")
		aura.Parent = root
		local em = VFX.MakeEmitter("Aura", color, aura, 18)
		em.Size = VFX.NS(0, 1.6 * (opts.Scale or 1), 0.5, 2.4 * (opts.Scale or 1), 1, 0)
		em.Transparency = VFX.NS(0, 0.55, 0.6, 0.75, 1, 1)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 30
		l.Brightness = 2
		l.Shadows = true
		l.Parent = root
		-- the camera gently frames bosses you are fighting
		root:SetAttribute("FrameRadius", 70)
		CollectionService:AddTag(root, "CameraFocus")
	end
	if opts.Elite then
		-- thin gold outline only (no fill) so the silhouette stays readable
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = Color3.fromRGB(255, 215, 110)
		h.OutlineTransparency = 0.45
		h.Parent = model
	end
	model:SetAttribute("Boss", opts.Boss == true)
	model:SetAttribute("Elite", opts.Elite == true)
	model:SetAttribute("HP", 1)
	CollectionService:AddTag(model, "Enemy")

	model.Parent = map.Enemies
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local enemy = {
		Model = model,
		Root = root,
		Head = head,
		Humanoid = hum,
		HP = opts.HP,
		MaxHP = opts.HP,
		Name = opts.Label,
		Color = color,
		Boss = opts.Boss,
		Elite = opts.Elite,
		FloorData = opts.Floor,
		OnKilled = opts.OnKilled,
		Owner = opts.Owner,
		Min = opts.Min,
		Max = opts.Max,
		Home = opts.Position,
		Damagers = {},
		Dead = false,
		OnDeath = opts.OnDeath,
		Scale = opts.Scale or 1,
		Radius = 1.6 * (opts.Scale or 1),
		HitPercent = opts.HitPercent or Config.EnemyHitPercent,
		State = "Idle",
		LastBasic = 0,
		NextSpecial = os.clock() + 2 + math.random() * 3,
		NextWander = 0,
		StunnedUntil = 0,
		LastDamaged = -100,
		NextPath = 0,
		RecoverUntil = 0,
		PoseId = 0,
		BaseSpeed = opts.Speed or 12,
		SlowUntil = 0,
	}
	enemy.Tracks = loadTracks(hum)
	if enemy.Tracks.Idle then
		enemy.Tracks.Idle:Play()
	end
	hum.Running:Connect(function(speed)
		local run, idle = enemy.Tracks.Run, enemy.Tracks.Idle
		if speed > 1 then
			if run and not run.IsPlaying then
				run:Play(0.15)
				if idle then
					idle:Stop(0.15)
				end
			end
		else
			if idle and not idle.IsPlaying then
				idle:Play(0.2)
				if run then
					run:Stop(0.2)
				end
			end
		end
	end)
	table.insert(EnemyService.Active, enemy)
	return enemy
end

---------------------------------------------------------------------
-- QUERIES
---------------------------------------------------------------------
function EnemyService.CanDamage(player: Player, e): boolean
	return not e.Dead and (not e.Owner or e.Owner == player)
end

function EnemyService.InSphere(pos: Vector3, radius: number)
	local out = {}
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead and (e.Root.Position - pos).Magnitude - e.Radius <= radius then
			table.insert(out, e)
		end
	end
	return out
end

function EnemyService.InCone(pos: Vector3, dir: Vector3, range: number, arcDot: number)
	local out = {}
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead then
			local offset = e.Root.Position - pos
			local flatV = Vector3.new(offset.X, 0, offset.Z)
			local dist = flatV.Magnitude
			if dist - e.Radius <= range and math.abs(offset.Y) < 10 * e.Scale then
				if dist < 3 * e.Scale or flatV.Unit:Dot(dir) > arcDot then
					table.insert(out, e)
				end
			end
		end
	end
	return out
end

function EnemyService.InSegment(a: Vector3, b: Vector3, radius: number)
	local out = {}
	local ab = b - a
	local len2 = ab:Dot(ab)
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead then
			local p = e.Root.Position
			local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
			local closest = a + ab * t
			if (p - closest).Magnitude <= radius + e.Radius + 1 then
				table.insert(out, e)
			end
		end
	end
	return out
end

---------------------------------------------------------------------
-- STATUS EFFECTS (all stun-like effects are capped by Balance.MaxStun)
---------------------------------------------------------------------
function EnemyService.Stun(e, duration: number)
	if e.Dead then
		return
	end
	duration = math.min(duration, B.MaxStun) * (e.Boss and 0.3 or 1)
	e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + duration)
	e.Humanoid:MoveTo(e.Root.Position)
	if duration >= 0.25 then
		setPose(e, "Stagger", duration)
	end
end

-- Frost: half speed for a moment; chilled enemies take +25% damage.
function EnemyService.Slow(e, duration: number)
	if e.Dead then
		return
	end
	local fresh = os.clock() >= e.SlowUntil
	e.SlowUntil = math.max(e.SlowUntil, os.clock() + duration)
	e.Humanoid.WalkSpeed = e.BaseSpeed * 0.5
	e.Model:SetAttribute("Chilled", true)
	if fresh then
		task.spawn(function()
			while not e.Dead and os.clock() < e.SlowUntil do
				task.wait(0.2)
			end
			if not e.Dead and e.Humanoid.Parent then
				e.Humanoid.WalkSpeed = e.BaseSpeed
				e.Model:SetAttribute("Chilled", nil)
			end
		end)
	end
end

function EnemyService.Knockback(e, dir: Vector3, force: number)
	if e.Dead then
		return
	end
	local f = force * (e.Boss and 0.2 or 1)
	e.Root.AssemblyLinearVelocity = dir * f + Vector3.new(0, f * 0.3, 0)
	EnemyService.Stun(e, 0.3)
end

function EnemyService.Pull(e, point: Vector3, strength: number)
	if e.Dead or e.Boss then
		return
	end
	local off = Vector3.new(point.X - e.Root.Position.X, 0, point.Z - e.Root.Position.Z)
	if off.Magnitude > 3 then
		e.Root.AssemblyLinearVelocity = off.Unit * strength
		EnemyService.Stun(e, 0.25)
	end
end

function EnemyService.Ragdoll(e, duration: number, force: boolean?)
	if (e.Dead and not force) or e.Ragdolled then
		return
	end
	if e.Boss and not force then
		EnemyService.Stun(e, duration)
		return
	end
	duration = math.min(duration, B.MaxStun)
	e.Ragdolled = true
	e.StunnedUntil = math.max(e.StunnedUntil, os.clock() + duration)
	local restore = {}
	for _, motor in ipairs(e.Model:GetDescendants()) do
		if motor:IsA("Motor6D") and motor.Name ~= "Root" and motor.Name ~= "RootJoint" and motor.Part0 and motor.Part1 then
			local a0 = Instance.new("Attachment")
			a0.CFrame = motor.C0
			a0.Parent = motor.Part0
			local a1 = Instance.new("Attachment")
			a1.CFrame = motor.C1
			a1.Parent = motor.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = 60
			bs.TwistLimitsEnabled = true
			bs.Parent = motor.Part0
			motor.Enabled = false
			table.insert(restore, { motor, a0, a1, bs, motor.Part1.CanCollide })
			motor.Part1.CanCollide = true
		end
	end
	e.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	task.delay(duration, function()
		for _, r in ipairs(restore) do
			local motor, a0, a1, bs, collide = r[1], r[2], r[3], r[4], r[5]
			if motor.Parent then
				motor.Enabled = true
				if motor.Part1 then
					motor.Part1.CanCollide = collide
				end
			end
			a0:Destroy()
			a1:Destroy()
			bs:Destroy()
		end
		e.Ragdolled = false
		if not e.Dead and e.Humanoid.Parent then
			e.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

---------------------------------------------------------------------
-- PLAYER DAMAGE (race passives: dodge, plot armor, zenkai; stun cap)
---------------------------------------------------------------------
function EnemyService.HitPlayer(player: Player, fraction: number, attackerPos: Vector3?, stun: number?, attacker)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not hum or hum.Health <= 0 or not data or not s then
		return
	end
	if s.God then
		return
	end
	local now = Stats.Now()
	if s.InvulnUntil > now then
		Net.FX(player, "Dodge", {})
		return
	end
	-- armour: dodge chance, then damage reduction, then thorns
	if math.random() < Stats.ArmorBonus(player, "Dodge") then
		Net.FX(player, "Dodge", {})
		return
	end
	local race = Stats.Race(data)
	local dmg = hum.MaxHealth * fraction * (1 - Stats.Defense(player))
	local thorns = Stats.ArmorBonus(player, "Thorns")
	if thorns > 0 and attacker and not attacker.Dead then
		EnemyService.Damage(attacker, player, Stats.Damage(player) * thorns, false)
	end
	local newHealth = hum.Health - dmg
	if newHealth <= 0 and race.PlotArmor and math.random() < race.PlotArmor then
		newHealth = 1
		s.InvulnUntil = now + Config.PlotArmorIFrames
		Net.FX(player, "PlotArmor", {})
	end
	hum.Health = math.max(0, newHealth)
	if stun and stun > 0 then
		s.StunnedUntil = os.clock() + math.min(stun, B.PlayerStunCap)
	end
	Net.FX(player, "Hurt", { Amount = dmg, From = attackerPos, Stun = stun and math.min(stun, B.PlayerStunCap) or nil })
	if race.Zenkai and hum.Health > 0 and hum.Health / hum.MaxHealth < Config.ZenkaiThreshold and now >= s.ZenkaiReady then
		s.ZenkaiEnd = now + Config.ZenkaiDuration
		s.ZenkaiReady = now + Config.ZenkaiCooldown
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.3)
		Net.FXAll("Transform", { Player = player, Kind = "Zenkai", Color = Color3.fromRGB(255, 225, 60) })
		if EnemyService.OnZenkai then
			EnemyService.OnZenkai(player)
		end
		DataService.MarkDirty(player)
	end
end

---------------------------------------------------------------------
-- DAMAGE / DEATH / REWARDS
---------------------------------------------------------------------
-- Armour is the rare gear drop (weapons come from the Forge).
local function gearDrop(player: Player, chance: number)
	if math.random() >= chance * Stats.EventMult("Drops") then
		return
	end
	local armorId, rarityId = Weapons.RollArmor(Stats.Luck(player))
	if Weapons.AddArmor(player, armorId, rarityId) then
		Net.FX(player, "ArmorDrop", { Armor = armorId, Rarity = rarityId })
	end
end

local function reward(player: Player, enemy)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s then
		return
	end
	local stage = enemy.FloorData
	if not stage then
		return
	end
	local mult = enemy.Elite and Config.EliteDropMult or 1
	local coins = math.floor(stage.Coins * mult * Stats.CoinMult(player))
	data.Coins += coins
	data.Kills += 1
	if EnemyService.OnReward then
		EnemyService.OnReward(player, enemy)
	end
	local luck = Stats.Luck(player) * (enemy.Elite and 2 or 1)
	local count
	if enemy.Boss then
		count = Config.BossOreDrops
	elseif enemy.Elite then
		count = 3
	else
		count = (math.random() < 0.25) and 2 or 1
	end
	count = math.floor(count * Stats.EventMult("Drops"))
	local pos = enemy.Root.Position
	for i = 1, count do
		local minOrder = (enemy.Boss and i == 1) and 4 or nil
		local oreId = Loot.RollOre(stage.Drops, luck, minOrder)
		local off = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4) * (enemy.Boss and 2 or 1)
		Loot.Drop(player, oreId, Vector3.new(pos.X + off.X, enemy.Home.Y + 1.2, pos.Z + off.Z))
	end
	if enemy.Boss and math.random() < Config.BossRerollChance then
		data.Rerolls += 1
		Net.Notify(player, "The boss dropped a Race Reroll!", Color3.fromRGB(200, 150, 255), "RarePickup")
	end
	gearDrop(player, enemy.Boss and Config.ArmorDropChance.Boss or (enemy.Elite and Config.ArmorDropChance.Elite or Config.ArmorDropChance.Normal))
	if enemy.Boss and math.random() < 0.35 then
		data.Keys.RareScroll = (data.Keys.RareScroll or 0) + 1
		Net.Notify(player, "The boss dropped a Rare+ Catalyst!", Color3.fromRGB(70, 160, 255), "RarePickup")
	end
	if Stats.Race(data).Id == "Ninja" then
		s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + Config.NinjaDodgeTime)
	end
	Net.FX(player, "Reward", { Coins = coins, Pos = pos })
	DataService.MarkDirty(player)
end
EnemyService.GearDrop = gearDrop

function EnemyService.Kill(enemy, killer: Player?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemy.Humanoid.WalkSpeed = 0
	enemy.Model:SetAttribute("HP", 0)
	Net.FXAll("Kill", { Model = enemy.Model, Color = enemy.Color, Big = enemy.Boss, Elite = enemy.Elite, Pos = enemy.Root.Position, By = killer })
	if killer and EnemyService.OnKill then
		task.spawn(EnemyService.OnKill, killer, enemy)
	end
	if enemy.OnDeath then
		task.spawn(enemy.OnDeath, killer)
	else
		for player in pairs(enemy.Damagers) do
			if player.Parent then
				reward(player, enemy)
			end
		end
	end
	if enemy.OnKilled then
		task.spawn(enemy.OnKilled, killer)
	end
	EnemyService.Ragdoll(enemy, 1, true)
	task.delay(0.9, function()
		local idx = table.find(EnemyService.Active, enemy)
		if idx then
			table.remove(EnemyService.Active, idx)
		end
		enemy.Model:Destroy()
	end)
end

function EnemyService.Damage(enemy, player: Player, amount: number, crit: boolean?)
	if enemy.Dead or (enemy.Owner and enemy.Owner ~= player) then
		return
	end
	-- punish window: enemies recovering from an attack take extra damage
	local exposed = os.clock() < enemy.RecoverUntil
	if exposed then
		amount *= AI.RecoverDamageMult
	end
	if os.clock() < (enemy.SlowUntil or 0) then
		amount *= 1.25
	end
	amount = math.max(1, math.floor(amount))
	enemy.HP -= amount
	enemy.Damagers[player] = true
	enemy.LastDamaged = os.clock()
	enemy.Model:SetAttribute("HP", math.clamp(enemy.HP / enemy.MaxHP, 0, 1))
	Net.FXAll("Hit", { Pos = enemy.Root.Position + Vector3.new(0, enemy.Scale, 0), Amount = amount, Crit = crit, Model = enemy.Model, Color = enemy.Color, By = player, Exposed = exposed, Boss = enemy.Boss })
	if enemy.HP <= 0 then
		EnemyService.Kill(enemy, player)
	end
end

function EnemyService.DoT(e, player: Player, perTick: number, count: number, interval: number, color: Color3?)
	task.spawn(function()
		for _ = 1, count do
			task.wait(interval)
			if e.Dead then
				return
			end
			EnemyService.Damage(e, player, perTick, false)
			if color then
				Net.FXAll("Impact", { Pos = e.Root.Position, Color = color, Radius = 3, Kind = "Burn" })
			end
		end
	end)
end

---------------------------------------------------------------------
-- AI
---------------------------------------------------------------------
local function playerRoots()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			table.insert(list, { Player = p, Root = r })
		end
	end
	return list
end

local function inBounds(e, pos: Vector3, pad: number): boolean
	return pos.X >= e.Min.X - pad and pos.X <= e.Max.X + pad and pos.Z >= e.Min.Z - pad and pos.Z <= e.Max.Z + pad and math.abs(pos.Y - e.Home.Y) < 40
end

local function clampToBounds(e, pos: Vector3): Vector3
	return Vector3.new(math.clamp(pos.X, e.Min.X, e.Max.X), pos.Y, math.clamp(pos.Z, e.Min.Z, e.Max.Z))
end

local function face(e, pos: Vector3)
	local from = e.Root.Position
	local look = Vector3.new(pos.X, from.Y, pos.Z)
	if (look - from).Magnitude > 0.1 then
		e.Root.CFrame = CFrame.lookAt(from, look)
	end
end

local function moveToward(e, goal: Vector3)
	goal = clampToBounds(e, goal)
	local t = os.clock()
	local dist = (goal - e.Root.Position).Magnitude
	if dist < 16 then
		e.Waypoints = nil
		e.Humanoid:MoveTo(goal)
		return
	end
	if t >= e.NextPath and not e.Computing then
		e.NextPath = t + AI.PathRecompute
		e.Computing = true
		task.spawn(function()
			e.Path = e.Path or PathfindingService:CreatePath({ AgentRadius = 2 * e.Scale, AgentHeight = 5 * e.Scale, AgentCanJump = false })
			local ok = pcall(function()
				e.Path:ComputeAsync(e.Root.Position, goal)
			end)
			if ok and e.Path.Status == Enum.PathStatus.Success then
				e.Waypoints = e.Path:GetWaypoints()
				e.WpIndex = 2
			else
				e.Waypoints = nil
			end
			e.Computing = false
		end)
	end
	local wps = e.Waypoints
	if wps and e.WpIndex and e.WpIndex <= #wps then
		local wp = wps[e.WpIndex].Position
		local flatD = Vector3.new(wp.X - e.Root.Position.X, 0, wp.Z - e.Root.Position.Z).Magnitude
		if flatD < 3 then
			e.WpIndex += 1
		end
		e.Humanoid:MoveTo(wp)
	else
		e.Humanoid:MoveTo(goal)
	end
end

-- Basic attack: anticipation (slow wind-up, lean back, eyes flare) ->
-- strike (animation snaps forward, damage on the "Hit" marker) ->
-- recovery (slumped, core dim, takes extra damage).
local function basicAttack(e, target)
	local tier = tierKey(e)
	local antic = AI.Anticipation[tier]
	local recover = AI.Recovery[tier]
	e.State = "Attack"
	e.LastBasic = os.clock()
	e.Humanoid:MoveTo(e.Root.Position)
	face(e, target.Root.Position)
	local track = e.Tracks.BasicAttack
	if track then
		track:Play(0.1)
		track:AdjustSpeed(0.25) -- slow "coil" during anticipation
	end
	setPose(e, "Anticipate", antic)
	task.spawn(function()
		task.wait(antic)
		if e.Dead or e.Ragdolled or os.clock() < e.StunnedUntil then
			if track then
				track:Stop(0.15)
			end
			e.State = "Chase"
			return
		end
		face(e, target.Root.Position)
		if track then
			track:AdjustSpeed(1.5) -- snap into the strike
		end
		setPose(e, "Strike", 0.15)
		Net.FXAll("EnemySwipe", { Pos = e.Root.Position, Target = target.Root.Position, Color = e.Color, Model = e.Model })
		waitForHit(track, Config.EnemyAnims.BasicHitTime / 1.5)
		if not e.Dead and not e.Ragdolled and os.clock() >= e.StunnedUntil and target.Root.Parent then
			local reach = Config.EnemyAttackRange + e.Radius
			if (target.Root.Position - e.Root.Position).Magnitude <= reach * 1.2 then
				EnemyService.HitPlayer(target.Player, e.HitPercent, e.Root.Position, nil, e)
			end
		end
		if e.Dead then
			return
		end
		-- recovery: a readable, punishable opening
		e.RecoverUntil = os.clock() + recover
		setPose(e, "Recover", recover)
		task.wait(recover)
		if e.State == "Attack" then
			e.State = "Chase"
			setPose(e, "Idle", 0.3)
		end
	end)
end

-- Special attack state machine: wind-up (telegraph) -> release (hit sync).
local function specialAttack(e, target)
	local tier = tierKey(e)
	e.State = "Windup"
	e.NextSpecial = os.clock() + AI.SpecialCooldown[tier] + AI.SpecialRecovery[tier]
	e.Humanoid:MoveTo(e.Root.Position)
	face(e, target.Root.Position)
	local windup = AI.Windup[tier]
	local kind = e.Boss and "Slam" or "Lunge"
	local start = e.Root.Position
	local dir = Vector3.new(target.Root.Position.X - start.X, 0, target.Root.Position.Z - start.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or e.Root.CFrame.LookVector
	local ground = Vector3.new(start.X, e.Home.Y + 0.2, start.Z)
	local slamAt = Vector3.new(target.Root.Position.X, e.Home.Y + 0.2, target.Root.Position.Z)
	local lungeLen = 16 * math.max(1, e.Scale * 0.7)
	local radius = e.Boss and Config.BossSlamRadius or 5
	local wind = e.Tracks.SpecialWindup
	if wind then
		wind:Play(0.1)
		wind:AdjustSpeed(math.clamp(wind.Length / windup, 0.5, 2))
	end
	setPose(e, "Windup", windup)
	Net.FXAll("EnemyWindup", {
		Model = e.Model,
		Kind = kind,
		Pos = kind == "Slam" and slamAt or ground,
		Dir = dir,
		Length = lungeLen,
		Radius = radius,
		Time = windup,
		Color = e.Color,
	})
	task.spawn(function()
		task.wait(windup)
		if wind then
			wind:Stop(0.1)
		end
		if e.Dead or e.Ragdolled or os.clock() < e.StunnedUntil then
			e.State = "Chase"
			return
		end
		local release = e.Tracks.SpecialRelease
		if release then
			release:Play(0.05)
		end
		setPose(e, "Strike", 0.2)
		if kind == "Lunge" then
			e.Root.AssemblyLinearVelocity = dir * 70 + Vector3.new(0, 5, 0)
		end
		waitForHit(release, Config.EnemyAnims.SpecialHitTime)
		if e.Dead then
			return
		end
		local pct = AI.SpecialPercent[tier]
		if kind == "Slam" then
			Net.FXAll("Slam", { Pos = slamAt, Radius = radius, Color = e.Color })
			for _, pr in ipairs(playerRoots()) do
				local d = Vector3.new(pr.Root.Position.X - slamAt.X, 0, pr.Root.Position.Z - slamAt.Z).Magnitude
				if d <= radius and (not e.Owner or e.Owner == pr.Player) then
					EnemyService.HitPlayer(pr.Player, pct, slamAt, 0.6, e)
				end
			end
		else
			local finish = start + dir * lungeLen
			Net.FXAll("EnemyLunge", { From = start, To = finish, Color = e.Color })
			for _, pr in ipairs(playerRoots()) do
				local p = pr.Root.Position
				local ab = finish - start
				local tt = math.clamp((p - start):Dot(ab) / ab:Dot(ab), 0, 1)
				if (p - (start + ab * tt)).Magnitude <= 4.5 and (not e.Owner or e.Owner == pr.Player) then
					EnemyService.HitPlayer(pr.Player, pct, start, 0.3, e)
				end
			end
		end
		-- long recovery after a special: the big punish window
		local recover = AI.SpecialRecovery[tier]
		e.State = "Recover"
		e.RecoverUntil = os.clock() + recover
		setPose(e, "Recover", recover)
		task.wait(recover)
		if e.State == "Recover" then
			e.State = "Chase"
			setPose(e, "Idle", 0.3)
		end
	end)
end

local function stepAI()
	local roots = playerRoots()
	local t = os.clock()
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead and e.Root.Parent and not e.Ragdolled and t >= e.StunnedUntil and e.State ~= "Windup" and e.State ~= "Attack" and e.State ~= "Recover" then
			local epos = e.Root.Position
			local target, targetDist = nil, math.huge
			local nearest = math.huge
			for _, pr in ipairs(roots) do
				local d = (pr.Root.Position - epos).Magnitude
				nearest = math.min(nearest, d)
				if (not e.Owner or e.Owner == pr.Player) and d < Config.EnemyAggroRange * (e.Boss and 1.6 or 1) and d < targetDist and inBounds(e, pr.Root.Position, 6) then
					target, targetDist = pr, d
				end
			end
			if nearest < 220 then
				if target then
					e.State = "Chase"
					local tier = tierKey(e)
					local reach = Config.EnemyAttackRange + e.Radius
					if t >= e.NextSpecial and targetDist <= AI.SpecialRange[tier] then
						specialAttack(e, target)
					elseif targetDist <= reach and t - e.LastBasic >= Config.EnemyAttackCooldown then
						basicAttack(e, target)
					elseif targetDist > reach * 0.8 then
						moveToward(e, target.Root.Position)
					else
						e.Humanoid:MoveTo(epos)
						face(e, target.Root.Position)
					end
				else
					e.State = "Idle"
					if t >= e.NextWander then
						e.NextWander = t + 2 + math.random() * 3
						e.Humanoid:MoveTo(e.Boss and e.Home or randomPoint(e.Min, e.Max))
					end
				end
			end
		end
	end
end

-- Clears every living enemy (admin). Owned enemies credit their owner.
function EnemyService.KillAll(byPlayer: Player?)
	for _, e in ipairs(table.clone(EnemyService.Active)) do
		if not e.Dead then
			EnemyService.Kill(e, e.Owner or byPlayer)
		end
	end
end

-- Removes an enemy without rewards (run ended, room reset...).
function EnemyService.Despawn(e)
	if e.Dead then
		return
	end
	e.Dead = true
	local idx = table.find(EnemyService.Active, e)
	if idx then
		table.remove(EnemyService.Active, idx)
	end
	if e.Model then
		e.Model:Destroy()
	end
end

function EnemyService.Init(m)
	map = m
	-- pre-build the first zone's rigs so the first rooms spawn instantly
	task.spawn(function()
		local z = Config.Zones[1]
		for _, id in ipairs(z.Enemies) do
			templateFor(id)
		end
		templateFor(z.Bosses[1])
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(stepAI)
			if not ok then
				warn("[Enemy AI]", err)
			end
		end
	end)
end

return EnemyService
