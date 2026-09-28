--!nonstrict
-- EnemyService (ModuleScript) -> ServerScriptService/Server/EnemyService
-- Chibi monsters (Zone 1) and mechs (Zone 2) built from parts, with simple
-- chase/attack AI, boss ground-slams, rare golden Elites and ore drops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local VFX = require(Shared:WaitForChild("VFX"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))

local EnemyService = {}
EnemyService.Active = {} :: { any }
EnemyService.OnZenkai = nil :: ((Player) -> ())?

local map = nil

---------------------------------------------------------------------
-- MODEL BUILDING
---------------------------------------------------------------------
local function part(model: Model, root: BasePart, props, offset: CFrame): BasePart
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = model
	return p
end

local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function buildModel(opts)
	local s = opts.Scale
	local color = opts.Color
	local model = Instance.new("Model")
	model.Name = opts.Name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.6, 2.6, 2.6) * s
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = false
	root.CFrame = CFrame.new(opts.Position)
	root.Parent = model
	model.PrimaryPart = root

	local white = Color3.new(1, 1, 1)
	local black = Color3.fromRGB(20, 15, 25)

	if opts.Style == "Mech" then
		local metal = darker(color, 0.55)
		part(model, root, { Name = "Body", Size = Vector3.new(3, 2.6, 2.4) * s, Color = metal, Material = Enum.Material.Metal }, CFrame.new(0, 0.1 * s, 0))
		part(model, root, { Name = "Chest", Size = Vector3.new(2.2, 1.2, 0.3) * s, Color = color, Material = Enum.Material.Metal }, CFrame.new(0, -0.3 * s, -1.2 * s))
		part(model, root, { Name = "Visor", Size = Vector3.new(2.4, 0.45, 0.2) * s, Color = color, Material = Enum.Material.Neon }, CFrame.new(0, 0.6 * s, -1.25 * s))
		for _, side in ipairs({ -1, 1 }) do
			part(model, root, { Name = "Shoulder", Size = Vector3.new(0.9, 1.2, 1.6) * s, Color = color, Material = Enum.Material.Metal }, CFrame.new(side * 1.9 * s, 0.4 * s, 0))
			part(model, root, { Name = "Leg", Size = Vector3.new(0.7, 1, 0.9) * s, Color = metal, Material = Enum.Material.Metal }, CFrame.new(side * 0.8 * s, -1.2 * s, 0))
		end
		part(model, root, { Name = "Antenna", Size = Vector3.new(0.12, 1.2, 0.12) * s, Color = metal }, CFrame.new(0.8 * s, 1.9 * s, 0.3 * s))
		part(model, root, { Name = "AntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35 * s, Color = color, Material = Enum.Material.Neon }, CFrame.new(0.8 * s, 2.55 * s, 0.3 * s))
		local thruster = part(model, root, { Name = "Thruster", Size = Vector3.new(1.4, 0.6, 0.2) * s, Color = color, Material = Enum.Material.Neon }, CFrame.new(0, -0.2 * s, 1.25 * s))
		VFX.MakeEmitter("Fire", color, thruster, 8).Size = VFX.NS(0, 0.4 * s, 1, 0)
	else
		part(model, root, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.1 * s, Color = color }, CFrame.new(0, 0, 0))
		part(model, root, { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.one * 2 * s, Color = color:Lerp(white, 0.45) }, CFrame.new(0, -0.35 * s, -0.75 * s))
		for _, side in ipairs({ -1, 1 }) do
			part(model, root, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.85 * s, Color = white }, CFrame.new(side * 0.55 * s, 0.45 * s, -1.2 * s))
			part(model, root, { Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45 * s, Color = black }, CFrame.new(side * 0.55 * s, 0.42 * s, -1.55 * s))
			part(model, root, { Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.15 * s, Color = white, Material = Enum.Material.Neon }, CFrame.new(side * 0.47 * s, 0.55 * s, -1.72 * s))
			part(model, root, { Name = "Horn", Size = Vector3.new(0.35, 1.1, 0.35) * s, Color = darker(color, 0.4) }, CFrame.new(side * 0.8 * s, 1.55 * s, -0.1 * s) * CFrame.Angles(0, 0, math.rad(-side * 22)))
			part(model, root, { Name = "Foot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.6, 1.1) * s, Color = darker(color, 0.7) }, CFrame.new(side * 0.75 * s, -1.4 * s, -0.2 * s))
			part(model, root, { Name = "Blush", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.2, 0.2) * s, Color = Color3.fromRGB(255, 130, 160), Transparency = 0.2 }, CFrame.new(side * 0.95 * s, 0.05 * s, -1.3 * s))
		end
		part(model, root, { Name = "Mouth", Size = Vector3.new(0.6, 0.12, 0.1) * s, Color = black }, CFrame.new(0, -0.05 * s, -1.52 * s))
	end

	if opts.Boss then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			part(model, root, { Name = "Crown", Size = Vector3.new(0.3, 0.8, 0.3) * s, Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon }, CFrame.new(math.cos(a) * 0.6 * s, 1.85 * s, math.sin(a) * 0.6 * s))
		end
		local aura = Instance.new("Attachment")
		aura.Parent = root
		VFX.MakeEmitter("Aura", color, aura, 25).Size = VFX.NS(0, 2 * s, 0.5, 3 * s, 1, 0)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 30
		l.Brightness = 2
		l.Parent = root
	end
	if opts.Elite then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 200, 50)
		h.FillTransparency = 0.7
		h.OutlineColor = Color3.fromRGB(255, 230, 120)
		h.Parent = model
		local aura = Instance.new("Attachment")
		aura.Parent = root
		VFX.MakeEmitter("Aura", Color3.fromRGB(255, 200, 60), aura, 18)
		VFX.MakeEmitter("Stars", Color3.fromRGB(255, 220, 90), aura, 4)
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = 0.35 * s
	hum.WalkSpeed = opts.Speed or 10
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, st in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Dead }) do
		hum:SetStateEnabled(st, false)
	end
	hum.Parent = model

	-- overhead name + HP bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "HealthGui"
	bb.Size = UDim2.fromOffset(opts.Boss and 260 or 150, opts.Boss and 58 or 42)
	bb.StudsOffset = Vector3.new(0, 2.2 * s + 1.2, 0)
	bb.MaxDistance = opts.Boss and 200 or 90
	bb.LightInfluence = 0
	bb.Parent = root
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.5)
	name.Font = Enum.Font.LuckiestGuy
	name.TextScaled = true
	name.Text = opts.Label
	name.TextColor3 = opts.Elite and Color3.fromRGB(255, 215, 70) or (opts.Boss and Color3.fromRGB(255, 90, 110) or white)
	name.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Thickness = 2
	ns.Parent = name
	local barBg = Instance.new("Frame")
	barBg.Name = "Bar"
	barBg.Position = UDim2.fromScale(0, 0.55)
	barBg.Size = UDim2.fromScale(1, 0.4)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	barBg.BorderSizePixel = 0
	barBg.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = barBg
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Color = Color3.fromRGB(10, 8, 12)
	bs.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = fill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 190, 80))
	grad.Parent = fill
	local hpText = Instance.new("TextLabel")
	hpText.Name = "HP"
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.FredokaOne
	hpText.TextScaled = true
	hpText.TextColor3 = white
	hpText.Text = Format.Abbrev(opts.HP)
	hpText.ZIndex = 2
	hpText.Parent = barBg
	local hs = Instance.new("UIStroke")
	hs.Thickness = 1.5
	hs.Parent = hpText

	return model, root, hum, fill, hpText
end

---------------------------------------------------------------------
-- SPAWNING
---------------------------------------------------------------------
local function randomPoint(minV: Vector3, maxV: Vector3): Vector3
	return Vector3.new(math.random() * (maxV.X - minV.X) + minV.X, 0, math.random() * (maxV.Z - minV.Z) + minV.Z)
end

function EnemyService.Create(opts)
	local model, root, hum, fill, hpText = buildModel(opts)
	local y = hum.HipHeight + root.Size.Y / 2 + 0.3
	model:PivotTo(CFrame.new(opts.Position.X, opts.Position.Y + y, opts.Position.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	model.Parent = map.Enemies
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local enemy = {
		Model = model,
		Root = root,
		Humanoid = hum,
		Fill = fill,
		HPText = hpText,
		HP = opts.HP,
		MaxHP = opts.HP,
		Name = opts.Label,
		Color = opts.Color,
		Boss = opts.Boss,
		Elite = opts.Elite,
		StageIndex = opts.StageIndex,
		Owner = opts.Owner,
		Min = opts.Min,
		Max = opts.Max,
		Home = opts.Position,
		Damagers = {},
		LastAttack = 0,
		LastSlam = os.clock(),
		NextWander = 0,
		Dead = false,
		OnDeath = opts.OnDeath,
		Scale = opts.Scale,
		HitPercent = opts.HitPercent or Config.EnemyHitPercent,
	}
	table.insert(EnemyService.Active, enemy)
	return enemy
end

local function spawnForStage(stageIndex: number, announce: boolean?)
	local stage = Config.Stages[stageIndex]
	local zone = Config.Zones[stage.Zone]
	local info = map.Dungeons[stage.Zone] and map.Dungeons[stage.Zone].Stages[stageIndex]
	if not info then
		return
	end
	local elite = not stage.Boss and math.random() < Config.EliteChance
	local scale = stage.Boss and 3.2 or (elite and 1.35 or 1 + (stageIndex % Config.StagesPerZone) * 0.08)
	local pos = stage.Boss and info.Center or randomPoint(info.SpawnMin, info.SpawnMax)
	local enemy = EnemyService.Create({
		Name = stage.Enemy,
		Label = (elite and "ELITE " or "") .. stage.Enemy,
		Style = zone.Style,
		Color = stage.Color,
		Scale = scale,
		HP = stage.HP * (elite and Config.EliteHPMult or 1),
		Boss = stage.Boss,
		Elite = elite,
		StageIndex = stageIndex,
		Position = pos,
		Min = info.SpawnMin,
		Max = info.SpawnMax,
		Speed = stage.Boss and 11 or (elite and 13 or 10),
	})
	if stage.Boss and announce then
		Net.FXAll("BossSpawn", { Name = stage.Enemy, Stage = stageIndex, Zone = stage.Zone, Pos = pos, Color = stage.Color })
	end
	return enemy
end

---------------------------------------------------------------------
-- PLAYER DAMAGE (race passives: dodge, plot armor, zenkai)
---------------------------------------------------------------------
function EnemyService.HitPlayer(player: Player, fraction: number, attackerPos: Vector3?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not hum or hum.Health <= 0 or not data or not s then
		return
	end
	local now = Stats.Now()
	if s.InvulnUntil > now then
		Net.FX(player, "Dodge", {})
		return
	end
	local race = Stats.Race(data)
	local dmg = hum.MaxHealth * fraction
	local newHealth = hum.Health - dmg
	if newHealth <= 0 and race.PlotArmor and math.random() < race.PlotArmor then
		newHealth = 1
		s.InvulnUntil = now + 1.5
		Net.FX(player, "PlotArmor", {})
	end
	hum.Health = math.max(0, newHealth)
	Net.FX(player, "Hurt", { Amount = dmg, From = attackerPos })
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
-- ENEMY DAMAGE / DEATH / REWARDS
---------------------------------------------------------------------
local function reward(player: Player, enemy)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s then
		return
	end
	local stage = Config.Stages[enemy.StageIndex]
	if not stage then
		return
	end
	local mult = enemy.Elite and Config.EliteDropMult or 1
	local coins = math.floor(stage.Coins * mult * Stats.CoinMult(player))
	data.Coins += coins
	data.Kills += 1
	local luck = Stats.Luck(player) * (enemy.Elite and 2 or 1)
	local count
	if enemy.Boss then
		count = Config.BossOreDrops
	elseif enemy.Elite then
		count = 3
	else
		count = (math.random() < 0.25) and 2 or 1
	end
	local pos = enemy.Root.Position
	for i = 1, count do
		local minOrder = (enemy.Boss and i == 1) and 4 or nil -- boss: one guaranteed Epic+
		local oreId = Loot.RollOre(stage.Drops, luck, minOrder)
		local off = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4) * (enemy.Boss and 2 or 1)
		Loot.Drop(player, oreId, Vector3.new(pos.X + off.X, 1.2, pos.Z + off.Z))
	end
	if enemy.Boss and math.random() < Config.BossRerollChance then
		data.Rerolls += 1
		Net.Notify(player, "The boss dropped a Race Reroll!", Color3.fromRGB(200, 150, 255), "RarePickup")
	end
	if Stats.Race(data).Id == "Ninja" then
		s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + Config.NinjaDodgeTime)
	end
	Net.FX(player, "Reward", { Coins = coins, Pos = pos })
	DataService.MarkDirty(player)
end

function EnemyService.Kill(enemy, killer: Player?)
	if enemy.Dead then
		return
	end
	enemy.Dead = true
	enemy.Humanoid.WalkSpeed = 0
	Net.FXAll("Kill", { Model = enemy.Model, Color = enemy.Color, Big = enemy.Boss, Elite = enemy.Elite, Pos = enemy.Root.Position, By = killer })
	if enemy.OnDeath then
		task.spawn(enemy.OnDeath, killer)
	else
		for player in pairs(enemy.Damagers) do
			if player.Parent then
				reward(player, enemy)
			end
		end
	end
	task.delay(0.6, function()
		local idx = table.find(EnemyService.Active, enemy)
		if idx then
			table.remove(EnemyService.Active, idx)
		end
		enemy.Model:Destroy()
	end)
	if enemy.StageIndex and not enemy.Owner then
		local stage = Config.Stages[enemy.StageIndex]
		task.delay(stage.Boss and Config.BossRespawn or Config.EnemyRespawn, spawnForStage, enemy.StageIndex, true)
	end
end

function EnemyService.Damage(enemy, player: Player, amount: number, crit: boolean?)
	if enemy.Dead then
		return
	end
	if enemy.Owner and enemy.Owner ~= player then
		return
	end
	amount = math.max(1, math.floor(amount))
	enemy.HP -= amount
	enemy.Damagers[player] = true
	local frac = math.clamp(enemy.HP / enemy.MaxHP, 0, 1)
	enemy.Fill.Size = UDim2.fromScale(frac, 1)
	enemy.HPText.Text = Format.Abbrev(math.max(0, enemy.HP))
	Net.FXAll("Hit", { Pos = enemy.Root.Position, Amount = amount, Crit = crit, Model = enemy.Model, Color = enemy.Color, By = player })
	if enemy.HP <= 0 then
		EnemyService.Kill(enemy, player)
	end
end

function EnemyService.InRange(pos: Vector3, look: Vector3?, range: number)
	local out = {}
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead then
			local offset = e.Root.Position - pos
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local reach = range + 1.3 * e.Scale
			local dist = flat.Magnitude
			if dist <= reach and math.abs(offset.Y) < 10 * e.Scale then
				if not look or dist < 3 * e.Scale or flat.Unit:Dot(look) > -0.15 then
					table.insert(out, e)
				end
			end
		end
	end
	return out
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

local function bossSlam(e, center: Vector3)
	local radius = Config.BossSlamRadius
	local ground = Vector3.new(center.X, e.Home.Y + 0.2, center.Z)
	Net.FXAll("Telegraph", { Pos = ground, Radius = radius, Time = 1.1 })
	task.delay(1.1, function()
		if e.Dead then
			return
		end
		Net.FXAll("Slam", { Pos = ground, Radius = radius, Color = e.Color })
		for _, pr in ipairs(playerRoots()) do
			local d = Vector3.new(pr.Root.Position.X - ground.X, 0, pr.Root.Position.Z - ground.Z).Magnitude
			if d <= radius and (not e.Owner or e.Owner == pr.Player) then
				EnemyService.HitPlayer(pr.Player, Config.BossSlamPercent, ground)
			end
		end
	end)
end

local function stepAI()
	local roots = playerRoots()
	local t = os.clock()
	for _, e in ipairs(EnemyService.Active) do
		if not e.Dead and e.Root.Parent then
			local epos = e.Root.Position
			local target, targetDist = nil, math.huge
			local anyNear = false
			for _, pr in ipairs(roots) do
				local d = (pr.Root.Position - epos).Magnitude
				if d < 220 then
					anyNear = true
				end
				if (not e.Owner or e.Owner == pr.Player) and d < Config.EnemyAggroRange * (e.Boss and 1.6 or 1) and d < targetDist and inBounds(e, pr.Root.Position, 6) then
					target, targetDist = pr, d
				end
			end
			if anyNear then
				if target then
					local reach = Config.EnemyAttackRange + 1.3 * e.Scale
					if targetDist > reach * 0.8 then
						e.Humanoid:MoveTo(clampToBounds(e, target.Root.Position))
					else
						e.Humanoid:MoveTo(epos)
					end
					if targetDist <= reach and t - e.LastAttack >= Config.EnemyAttackCooldown then
						e.LastAttack = t
						Net.FXAll("EnemySwipe", { Pos = epos, Target = target.Root.Position, Color = e.Color })
						EnemyService.HitPlayer(target.Player, e.HitPercent, epos)
					end
					if e.Boss and t - e.LastSlam >= Config.BossSlamEvery and targetDist < 28 then
						e.LastSlam = t
						bossSlam(e, target.Root.Position)
					end
				elseif t >= e.NextWander then
					e.NextWander = t + 2 + math.random() * 3
					if e.Boss then
						e.Humanoid:MoveTo(e.Home)
					else
						e.Humanoid:MoveTo(randomPoint(e.Min, e.Max) + Vector3.new(0, e.Home.Y, 0))
					end
				end
			end
		end
	end
end

function EnemyService.Init(m)
	map = m
	for stageIndex, stage in ipairs(Config.Stages) do
		if map.Dungeons[stage.Zone] then
			for _ = 1, stage.Count do
				spawnForStage(stageIndex, false)
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(stepAI)
			if not ok then
				warn("[Enemy AI]", err)
			end
		end
	end)
end

return EnemyService
