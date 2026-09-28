--!nonstrict
-- Projectiles (ModuleScript) -> ServerScriptService/Server/Projectiles
-- Server-authoritative projectiles: stepped every Heartbeat, raycast against
-- map geometry, swept-sphere hit tests against enemies. Clients only draw
-- them (FX "Proj" / "ProjEnd").

local RunService = game:GetService("RunService")

local Net = require(script.Parent:WaitForChild("Net"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local Projectiles = {}

local active = {}
local nextId = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.RespectCanCollide = true

function Projectiles.SetWorld(blockers: { Instance })
	rayParams.FilterDescendantsInstances = blockers
end

--[[ opts:
	Owner: Player, Origin: Vector3, Dir: Vector3, Speed, Range, Radius,
	Pierce: boolean | number (extra enemies), Kind: string, Color: Color3,
	Size: number?, Explode: number? (radius), OnHit: (enemy, pos) -> ()
	OnExplode: (pos, radius) -> ()
]]
function Projectiles.Fire(opts)
	nextId += 1
	local p = {
		Id = nextId,
		Owner = opts.Owner,
		Pos = opts.Origin,
		Dir = opts.Dir.Unit,
		Speed = opts.Speed,
		Range = opts.Range,
		Radius = opts.Radius or 2,
		Pierce = opts.Pierce,
		Traveled = 0,
		Hit = {},
		Hits = 0,
		OnHit = opts.OnHit,
		OnExplode = opts.OnExplode,
		Explode = opts.Explode,
	}
	active[p.Id] = p
	Net.FXAll("Proj", { Id = p.Id, Kind = opts.Kind or "Ray", Pos = p.Pos, Dir = p.Dir, Speed = p.Speed, Range = p.Range, Color = opts.Color, Size = opts.Size })
	return p.Id
end

local function finish(p, pos: Vector3, hit: boolean)
	active[p.Id] = nil
	if p.Explode and p.OnExplode then
		p.OnExplode(pos, p.Explode)
	end
	Net.FXAll("ProjEnd", { Id = p.Id, Pos = pos, Hit = hit, Explode = p.Explode })
end

local function maxHits(p): number
	if p.Pierce == true then
		return math.huge
	elseif type(p.Pierce) == "number" then
		return 1 + p.Pierce
	end
	return 1
end

RunService.Heartbeat:Connect(function(dt)
	for _, p in pairs(active) do
		local step = math.min(p.Speed * dt, p.Range - p.Traveled)
		local from = p.Pos
		local to = from + p.Dir * step
		local wall = workspace:Raycast(from, p.Dir * step, rayParams)
		if wall then
			to = wall.Position
		end
		local done = false
		for _, e in ipairs(EnemyService.InSegment(from, to, p.Radius)) do
			if not p.Hit[e] then
				p.Hit[e] = true
				p.Hits += 1
				if p.OnHit then
					local ok, err = pcall(p.OnHit, e, e.Root.Position)
					if not ok then
						warn("[Projectile]", err)
					end
				end
				if p.Hits >= maxHits(p) then
					finish(p, e.Root.Position, true)
					done = true
					break
				end
			end
		end
		if not done then
			p.Pos = to
			p.Traveled += step
			if wall then
				finish(p, to, true)
			elseif p.Traveled >= p.Range - 0.01 then
				finish(p, to, false)
			end
		end
	end
end)

return Projectiles
