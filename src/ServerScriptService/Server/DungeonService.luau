--!nonstrict
-- DungeonService (ModuleScript) -> ServerScriptService/Server/DungeonService
-- +1 Loot To Forge style dungeon runs.
--   * Enter at the lobby gate and pick a start floor (floor 1 or an unlocked
--     checkpoint: reach floor 50 to start at 25, floor 75 to start at 50...).
--   * Every player gets a private run far below the lobby, built 5 floors
--     at a time: an entry hall, four rooms and a boss room.
--   * Enemies only spawn when you walk into a room. Clear the room to open
--     the door to the next floor; beat the boss to take the stairs down.
--   * Dying or pressing HOME ends the run: you go back to the lobby and the
--     next run starts from floor 1 (or a checkpoint) again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Util = require(script.Parent:WaitForChild("Util"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local DungeonService = {}
local D = Config.Dungeon
local runs: { [Player]: any } = {}
local slots: { [number]: Player } = {}
local root: Folder = nil
local RED = Color3.fromRGB(255, 110, 90)

---------------------------------------------------------------------
-- tiny part builder
---------------------------------------------------------------------
local function P(parent: Instance, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function label(part: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(400, 100)
	sg.LightInfluence = 0
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Config.Fonts.Display
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = sg
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(10, 8, 16)
	st.Parent = t
	return t
end

---------------------------------------------------------------------
-- zone decor (a few readable props per room, themed per anime zone)
---------------------------------------------------------------------
local function tree(parent, pos: Vector3, trunk: Color3, leaves: Color3, h: number)
	P(parent, { Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = trunk, Material = Enum.Material.Wood })
	for k = 0, 2 do
		P(parent, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * (10 - k * 2.4), CFrame = CFrame.new(pos + Vector3.new((k - 1) * 1.6, h + k * 2.6, (k % 2) * 1.5)), Color = leaves:Lerp(Color3.new(1, 1, 1), k * 0.06), Material = Enum.Material.Grass, CanCollide = false })
	end
end

local function lantern(parent, pos: Vector3, color: Color3)
	P(parent, { Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color = Color3.fromRGB(50, 40, 40), Material = Enum.Material.Wood })
	local l = P(parent, { Name = "Lantern", Size = Vector3.new(1.8, 2.2, 1.8), CFrame = CFrame.new(pos + Vector3.new(0, 7.8, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false })
	local pl = Instance.new("PointLight")
	pl.Color = color
	pl.Range = 18
	pl.Brightness = 1.3
	pl.Parent = l
end

local function decorate(parent, theme: string, zone, center: Vector3, halfW: number, len: number, rng: Random)
	local sides = { -1, 1 }
	local zs = { -len * 0.3, 0, len * 0.3 }
	if theme == "Forest" then
		for _, s in ipairs(sides) do
			for _, dz in ipairs(zs) do
				tree(parent, center + Vector3.new(s * (halfW - 5), 0, dz + rng:NextNumber(-6, 6)), Color3.fromRGB(96, 70, 48), zone.Accent:Lerp(Color3.fromRGB(60, 140, 60), 0.7), rng:NextNumber(9, 14))
			end
		end
	elseif theme == "Soul" then
		for _, s in ipairs(sides) do
			for _, dz in ipairs(zs) do
				P(parent, { Name = "Pillar", Size = Vector3.new(4, 26, 4), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 4), 13, dz)), Color = zone.Wall, Material = Enum.Material.Marble })
				lantern(parent, center + Vector3.new(s * (halfW - 9), 0, dz + 8), zone.Accent)
			end
		end
	elseif theme == "Walls" then
		for _, s in ipairs(sides) do
			P(parent, { Name = "GreatWall", Size = Vector3.new(6, 40, len), CFrame = CFrame.new(center + Vector3.new(s * (halfW + 2), 20, 0)), Color = zone.Wall, Material = Enum.Material.Cobblestone })
			for _ = 1, 3 do
				P(parent, { Name = "Rubble", Size = Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(2, 5), rng:NextNumber(3, 7)), CFrame = CFrame.new(center + Vector3.new(s * rng:NextNumber(halfW * 0.5, halfW - 6), 1.5, rng:NextNumber(-len / 2 + 8, len / 2 - 8))) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = zone.Wall:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Slate })
			end
		end
	elseif theme == "Shrine" then
		for _, dz in ipairs({ -len * 0.25, len * 0.25 }) do
			local red = Color3.fromRGB(200, 40, 50)
			for _, s in ipairs(sides) do
				P(parent, { Name = "ToriiPost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 1.6, 1.6), CFrame = CFrame.new(center + Vector3.new(s * 9, 8, dz)) * CFrame.Angles(0, 0, math.rad(90)), Color = red })
			end
			P(parent, { Name = "ToriiTop", Size = Vector3.new(24, 1.4, 2), CFrame = CFrame.new(center + Vector3.new(0, 16.4, dz)), Color = Color3.fromRGB(30, 24, 28) })
			P(parent, { Name = "ToriiBeam", Size = Vector3.new(21, 1, 1.4), CFrame = CFrame.new(center + Vector3.new(0, 13.6, dz)), Color = red })
		end
		for _, s in ipairs(sides) do
			for _, dz in ipairs(zs) do
				lantern(parent, center + Vector3.new(s * (halfW - 5), 0, dz), Color3.fromRGB(255, 150, 80))
				P(parent, { Name = "Wisteria", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 7, 5), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 3), 20, dz + 10)), Color = Color3.fromRGB(190, 140, 255), Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false })
			end
		end
	elseif theme == "Academy" then
		for _, dz in ipairs(zs) do
			local ring = P(parent, { Name = "CurseSigil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 14, 14), CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-10, 10), 0.15, dz)) * CFrame.Angles(0, 0, math.rad(90)), Color = zone.Accent, Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false })
			ring.CastShadow = false
		end
		for _, s in ipairs(sides) do
			for _, dz in ipairs(zs) do
				P(parent, { Name = "Desk", Size = Vector3.new(5, 2.6, 3), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 7), 1.3, dz)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color = Color3.fromRGB(120, 90, 60), Material = Enum.Material.Wood })
			end
		end
	elseif theme == "Cove" then
		for _, s in ipairs(sides) do
			P(parent, { Name = "Sea", Size = Vector3.new(14, 0.4, len), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 7), 0.25, 0)), Color = Color3.fromRGB(40, 150, 210), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
			for _, dz in ipairs({ -len * 0.25, len * 0.2 }) do
				local base = center + Vector3.new(s * (halfW - 16), 0, dz)
				P(parent, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 3, 3), CFrame = CFrame.new(base + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood })
				tree(parent, base + Vector3.new(s * 6, 0, 8), Color3.fromRGB(150, 110, 70), Color3.fromRGB(70, 170, 80), 13)
			end
		end
	elseif theme == "City" then
		for _, s in ipairs(sides) do
			for _, dz in ipairs(zs) do
				P(parent, { Name = "ACUnit", Size = Vector3.new(6, 4, 5), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 6), 2, dz)), Color = Color3.fromRGB(150, 155, 165), Material = Enum.Material.DiamondPlate })
			end
			local sign = P(parent, { Name = "NeonSign", Size = Vector3.new(0.5, 5, 16), CFrame = CFrame.new(center + Vector3.new(s * (halfW - 0.5), 14, 0)), Color = zone.Accent, Material = Enum.Material.Neon })
			sign.CastShadow = false
		end
	elseif theme == "Wastes" then
		for _ = 1, 6 do
			local s = rng:NextNumber() < 0.5 and -1 or 1
			P(parent, { Name = "Boulder", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(5, 10), CFrame = CFrame.new(center + Vector3.new(s * rng:NextNumber(halfW * 0.45, halfW - 5), 1, rng:NextNumber(-len / 2 + 8, len / 2 - 8))), Color = zone.Wall, Material = Enum.Material.Rock })
		end
		for _, dz in ipairs({ -len * 0.2, len * 0.25 }) do
			local c = P(parent, { Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 12, 12), CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-12, 12), 0.12, dz)) * CFrame.Angles(0, 0, math.rad(90)), Color = zone.Floor:Lerp(Color3.new(0, 0, 0), 0.35), CanCollide = false })
			c.CastShadow = false
		end
	end
end

local FLOOR_MATERIAL = { Forest = Enum.Material.Grass, Soul = Enum.Material.Marble, Walls = Enum.Material.Sand, Shrine = Enum.Material.WoodPlanks, Academy = Enum.Material.Slate, Cove = Enum.Material.Sand, City = Enum.Material.Concrete, Wastes = Enum.Material.Ground }
local WALL_MATERIAL = { Forest = Enum.Material.Wood, Soul = Enum.Material.Marble, Walls = Enum.Material.Cobblestone, Shrine = Enum.Material.Wood, Academy = Enum.Material.Brick, Cove = Enum.Material.WoodPlanks, City = Enum.Material.Concrete, Wastes = Enum.Material.Rock }

---------------------------------------------------------------------
-- building a 5-floor segment
---------------------------------------------------------------------
local function door(parent, z: number, origin: Vector3, zone, text: string, boss: boolean)
	local W = D.RoomWidth
	local frameColor = zone.Wall:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, s in ipairs({ -1, 1 }) do
		P(parent, { Name = "DoorPost", Size = Vector3.new(4, 26, 4), CFrame = CFrame.new(origin + Vector3.new(s * 9, 13, z)), Color = frameColor, Material = WALL_MATERIAL[zone.Theme] or Enum.Material.Slate })
		P(parent, { Name = "DoorWall", Size = Vector3.new((W / 2 - 11), 26, 3), CFrame = CFrame.new(origin + Vector3.new(s * (11 + (W / 2 - 11) / 2), 13, z)), Color = zone.Wall, Material = WALL_MATERIAL[zone.Theme] or Enum.Material.Slate })
	end
	local lintel = P(parent, { Name = "Lintel", Size = Vector3.new(22, 4, 4), CFrame = CFrame.new(origin + Vector3.new(0, 24, z)), Color = frameColor, Material = WALL_MATERIAL[zone.Theme] or Enum.Material.Slate })
	label(lintel, text, boss and Color3.fromRGB(255, 90, 100) or Color3.fromRGB(255, 240, 210), Enum.NormalId.Back)
	local gate = P(parent, { Name = "Gate", Size = Vector3.new(14, 22, 1), CFrame = CFrame.new(origin + Vector3.new(0, 11, z)), Color = boss and Color3.fromRGB(255, 60, 80) or zone.Accent, Material = Enum.Material.ForceField, Transparency = 0.1 })
	return gate
end

local function openGate(gate: BasePart?, player: Player?)
	if gate and gate.Parent then
		gate.CanCollide = false
		gate.Transparency = 1
		if player then
			Net.FX(player, "GateOpen", { Pos = gate.Position, Color = gate.Color })
		end
	end
end

local function buildSegment(run, fromFloor: number)
	if run.Segment then
		run.Segment:Destroy()
	end
	local seg = Instance.new("Model")
	seg.Name = "Segment_" .. fromFloor
	seg.Parent = run.Folder
	run.Segment = seg
	run.Rooms = {}
	local O = run.Origin
	local W = D.RoomWidth
	local segEnd = math.ceil(fromFloor / D.BossEvery) * D.BossEvery
	local first = Config.Floor(fromFloor)
	local zone = first.ZoneData
	local rng = Random.new(fromFloor * 131 + run.Slot)

	-- entry hall
	local hallLen = D.HallLen
	P(seg, { Name = "HallFloor", Size = Vector3.new(W, 2, hallLen), CFrame = CFrame.new(O + Vector3.new(0, -1, -hallLen / 2)), Color = zone.Floor:Lerp(Color3.new(0, 0, 0), 0.15), Material = FLOOR_MATERIAL[zone.Theme] or Enum.Material.Slate })
	P(seg, { Name = "BackWall", Size = Vector3.new(W, 30, 3), CFrame = CFrame.new(O + Vector3.new(0, 15, 1.5)), Color = zone.Wall, Material = WALL_MATERIAL[zone.Theme] or Enum.Material.Slate })
	for _, s in ipairs({ -1, 1 }) do
		P(seg, { Name = "HallWall", Size = Vector3.new(3, 30, hallLen), CFrame = CFrame.new(O + Vector3.new(s * (W / 2 + 1.5), 15, -hallLen / 2)), Color = zone.Wall, Material = WALL_MATERIAL[zone.Theme] or Enum.Material.Slate })
		lantern(seg, O + Vector3.new(s * (W / 2 - 4), 0, -hallLen / 2), zone.Accent)
	end
	local sign = P(seg, { Name = "ZoneSign", Size = Vector3.new(30, 6, 1), CFrame = CFrame.new(O + Vector3.new(0, 20, 0)), Color = Color3.fromRGB(14, 12, 20) })
	label(sign, zone.Name:upper() .. (first.Cycle > 0 and "  (NIGHTMARE)" or ""), zone.Accent, Enum.NormalId.Front)
	run.SpawnCF = CFrame.new(O + Vector3.new(0, 4, -10)) * CFrame.Angles(0, 0, 0)

	local z = -hallLen
	for f = fromFloor, segEnd do
		local fd = Config.Floor(f)
		local fz = fd.ZoneData
		local len = fd.Boss and D.BossRoomLen or D.RoomLen
		local zStart, zEnd = z, z - len
		local center = O + Vector3.new(0, 0, (zStart + zEnd) / 2)
		local gate = door(seg, zStart, O, fz, (fd.Boss and "BOSS FLOOR " or "FLOOR ") .. f, fd.Boss)
		P(seg, { Name = "RoomFloor", Size = Vector3.new(W, 2, len), CFrame = CFrame.new(center + Vector3.new(0, -1, 0)), Color = fd.Boss and fz.Floor:Lerp(Color3.fromRGB(60, 10, 20), 0.35) or fz.Floor, Material = FLOOR_MATERIAL[fz.Theme] or Enum.Material.Slate })
		for _, s in ipairs({ -1, 1 }) do
			P(seg, { Name = "RoomWall", Size = Vector3.new(3, 30, len), CFrame = CFrame.new(center + Vector3.new(s * (W / 2 + 1.5), 15, 0)), Color = fz.Wall, Material = WALL_MATERIAL[fz.Theme] or Enum.Material.Slate })
		end
		decorate(seg, fz.Theme, fz, center, W / 2, len, rng)
		if fd.Boss then
			local ring = P(seg, { Name = "BossRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 44, 44), CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 60, 80), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
			ring.CastShadow = false
		end
		-- spawn area keeps a margin from the walls and the door you came in
		local min = center + Vector3.new(-W / 2 + 7, 0, -len / 2 + 6)
		local max = center + Vector3.new(W / 2 - 7, 0, len / 2 - 14)
		run.Rooms[f] = { Floor = f, Data = fd, ZStart = zStart, ZEnd = zEnd, Center = center, Min = min, Max = max, Gate = gate, State = "Waiting", Enemies = {}, Alive = 0 }
		if f == fromFloor then
			openGate(gate) -- the hall leads straight into the first room
		end
		z = zEnd
	end
	-- end wall with the stairs down (revealed when the boss falls)
	local lastZone = Config.Floor(segEnd).ZoneData
	P(seg, { Name = "EndWall", Size = Vector3.new(W, 30, 3), CFrame = CFrame.new(O + Vector3.new(0, 15, z - 1.5)), Color = lastZone.Wall, Material = WALL_MATERIAL[lastZone.Theme] or Enum.Material.Slate })
	local stairs = P(seg, { Name = "Stairs", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 16, 16), CFrame = CFrame.new(O + Vector3.new(0, 0.3, z + 12)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Transparency = 1, CanCollide = false, CanTouch = false })
	run.Stairs = stairs
	run.SegEnd = segEnd
end

---------------------------------------------------------------------
-- floors, spawns, clears
---------------------------------------------------------------------
local function runInfo(run)
	local room = run.Rooms[run.Floor]
	local fd = Config.Floor(run.Floor)
	return {
		Floor = run.Floor,
		Start = run.StartFloor,
		Kills = room and (room.Kills or 0) or 0,
		Need = fd.Kills,
		Boss = fd.Boss,
		Zone = fd.Zone,
		Enemy = fd.Enemy,
		State = room and room.State or "Waiting",
	}
end

local function sync(run)
	local s = DataService.Session(run.Player)
	if s then
		s.Run = runInfo(run)
	end
	DataService.MarkDirty(run.Player)
end

local function reachFloor(run, f: number)
	local data = DataService.Get(run.Player)
	if data and f > (data.BestFloor or 0) then
		data.BestFloor = f
	end
end

local onRoomCleared

local function spawnRoom(run, room)
	room.State = "Fighting"
	room.Kills = 0
	local player = run.Player
	local fd = room.Data
	reachFloor(run, room.Floor)
	Net.FX(player, "FloorStart", { Floor = room.Floor, Boss = fd.Boss, Name = fd.Enemy, Zone = fd.Zone, Color = fd.Color })
	local count = fd.Count
	room.Alive = count
	for i = 1, count do
		task.spawn(function()
			if not run.Active then
				return
			end
			local lookId = fd.Boss and fd.Look or ((fd.MixLook and i % 2 == 0) and fd.MixLook or fd.Look)
			local arch = Config.EnemyArchetypes[lookId] or {}
			local elite = not fd.Boss and math.random() < Config.EliteChance
			local size = arch.Size or 1
			local scale = fd.Boss and math.min(3.4, 1.9 * size) or (elite and 1.25 * size or size)
			local pos = fd.Boss and room.Center + Vector3.new(0, 0, -8) or Vector3.new(math.random() * (room.Max.X - room.Min.X) + room.Min.X, room.Min.Y, math.random() * (room.Max.Z - room.Min.Z) + room.Min.Z)
			Net.FX(player, "EnemySpawn", { Pos = pos + Vector3.new(0, 1, 0), Color = arch.Aura or fd.Color, Boss = fd.Boss })
			task.wait(0.35 + i * 0.08)
			if not run.Active or room.State ~= "Fighting" then
				return
			end
			local ok, enemy = pcall(EnemyService.Create, {
				Label = (elite and "ELITE " or "") .. ((fd.Cycle > 0 and "Nightmare " or "") .. (arch.Name or fd.Enemy)),
				Look = lookId,
				Color = arch.Aura or fd.Color,
				Scale = scale,
				HP = fd.HP * (elite and Config.EliteHPMult or 1),
				Boss = fd.Boss,
				Elite = elite,
				Floor = fd,
				Owner = player,
				Position = pos,
				Min = room.Min,
				Max = room.Max,
				Speed = fd.Boss and 13 or (elite and 15 or 12.5),
				HitPercent = Config.EnemyHitPercent * (fd.Boss and 1.2 or 1) + math.min(room.Floor, 200) * 0.0002,
				OnKilled = function()
					room.Kills = (room.Kills or 0) + 1
					room.Alive -= 1
					if run.Active and room.Alive <= 0 and room.State == "Fighting" then
						onRoomCleared(run, room)
					else
						sync(run)
					end
				end,
			})
			if not ok then
				-- never leave a room un-clearable because one rig failed to build
				warn("[Dungeon] enemy spawn failed:", enemy)
				room.Alive -= 1
				if run.Active and room.Alive <= 0 and room.State == "Fighting" then
					onRoomCleared(run, room)
				end
				return
			end
			if not run.Active or room.State ~= "Fighting" then
				EnemyService.Despawn(enemy)
				return
			end
			table.insert(room.Enemies, enemy)
			if fd.Boss then
				Net.FX(player, "BossSpawn", { Name = arch.Name or fd.Enemy, Floor = room.Floor, Pos = pos, Color = arch.Aura or fd.Color, Global = true })
			end
		end)
	end
	-- pre-build the next floor's rigs while this room is fought
	local nf = Config.Floor(room.Floor + 1)
	EnemyService.Prebuild(nf.Look)
	if nf.MixLook then
		EnemyService.Prebuild(nf.MixLook)
	end
	sync(run)
end

onRoomCleared = function(run, room)
	room.State = "Cleared"
	local player = run.Player
	local nextFloor = room.Floor + 1
	run.Floor = nextFloor
	run.Cleared += 1
	local nextRoom = run.Rooms[nextFloor]
	if nextRoom then
		openGate(nextRoom.Gate, player)
	else
		-- boss down: reveal the stairs to the next segment
		local stairs = run.Stairs
		if stairs then
			stairs.Transparency = 0.15
			stairs.CanTouch = true
			VFX.MakeEmitter("Rise", Color3.fromRGB(120, 220, 255), stairs, 20)
			stairs.Touched:Connect(function(hit)
				local model = hit:FindFirstAncestorOfClass("Model")
				if run.Active and model and model == player.Character and not run.Descending then
					run.Descending = true
					Net.FX(player, "Descend", { Floor = nextFloor })
					task.wait(0.35)
					if run.Active then
						buildSegment(run, nextFloor)
						Util.Teleport(player, run.SpawnCF, "Floor " .. nextFloor)
					end
					run.Descending = false
					sync(run)
				end
			end)
		end
	end
	reachFloor(run, nextFloor)
	Net.FX(player, "FloorCleared", { Floor = room.Floor, Boss = room.Data.Boss, Next = nextFloor })
	sync(run)
end

---------------------------------------------------------------------
-- runs
---------------------------------------------------------------------
function DungeonService.InRun(player: Player): boolean
	return runs[player] ~= nil
end

function DungeonService.Get(player: Player)
	return runs[player]
end

local function freeSlot(): number?
	for i = 1, D.RunSlots do
		if not slots[i] then
			return i
		end
	end
	return nil
end

function DungeonService.End(player: Player, reason: string)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	run.Active = false
	slots[run.Slot] = nil
	for _, room in pairs(run.Rooms or {}) do
		for _, e in ipairs(room.Enemies) do
			EnemyService.Despawn(e)
		end
	end
	if run.Folder then
		run.Folder:Destroy()
	end
	local s = DataService.Session(player)
	if s then
		s.Run = nil
	end
	local data = DataService.Get(player)
	if data and player.Parent then
		local best = data.BestFloor or 0
		Net.FX(player, "RunEnded", {
			Reason = reason,
			Reached = run.Floor,
			Start = run.StartFloor,
			Cleared = run.Cleared,
			Best = best,
			Coins = math.max(0, data.Coins - run.CoinsAtStart),
			Checkpoints = Config.Checkpoints(best, Stats.HasPass(player, "FastTravel")),
		})
		DataService.MarkDirty(player)
	end
end

function DungeonService.Start(player: Player, startFloor)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not s or not hum or hum.Health <= 0 then
		return
	end
	if s.Tower then
		Net.Notify(player, "Leave the Boss Rush first.", RED, "Error")
		return
	end
	startFloor = tonumber(startFloor) or 1
	local allowed = Config.Checkpoints(data.BestFloor or 0, Stats.HasPass(player, "FastTravel"))
	if not table.find(allowed, startFloor) then
		Net.Notify(player, "That checkpoint is locked. Reach floor " .. (startFloor + D.CheckpointEvery) .. " to start there.", RED, "Error")
		return
	end
	if runs[player] then
		DungeonService.End(player, "Restart")
	end
	local slot = freeSlot()
	if not slot then
		Net.Notify(player, "The dungeon is full right now, try again in a moment.", RED, "Error")
		return
	end
	slots[slot] = player
	local folder = Instance.new("Folder")
	folder.Name = "Run_" .. player.UserId
	folder.Parent = root
	local run: any = {
		Player = player,
		Slot = slot,
		Origin = D.SlotOrigin + Vector3.new(slot * D.SlotSpacing, 0, 0),
		Folder = folder,
		Floor = startFloor,
		StartFloor = startFloor,
		Cleared = 0,
		CoinsAtStart = data.Coins,
		Active = true,
		Rooms = {},
	}
	runs[player] = run
	buildSegment(run, startFloor)
	Util.Teleport(player, run.SpawnCF, "Floor " .. startFloor)
	Net.FX(player, "RunStarted", { Floor = startFloor, Zone = Config.Floor(startFloor).Zone })
	sync(run)
end

-- Hooked to every character: dying ends the run.
function DungeonService.CharacterAdded(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			if runs[player] then
				DungeonService.End(player, "Died")
			end
		end)
	end
end

function DungeonService.PlayerRemoving(player: Player)
	DungeonService.End(player, "Left")
end

function DungeonService.Init()
	root = Instance.new("Folder")
	root.Name = "DungeonRuns"
	root.Parent = workspace
	-- room triggers: enemies only spawn once you walk into the room
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, run in pairs(runs) do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if run.Active and hrp then
					local rel = hrp.Position - run.Origin
					local room = run.Rooms[run.Floor]
					if room and room.State == "Waiting" and rel.Z < room.ZStart - D.SpawnRange and rel.Z > room.ZEnd and math.abs(rel.X) < D.RoomWidth / 2 then
						spawnRoom(run, room)
					end
					-- fell off the map: back to the start of the segment
					if rel.Y < -80 then
						hrp.CFrame = run.SpawnCF
					end
				end
			end
		end
	end)
end

return DungeonService
