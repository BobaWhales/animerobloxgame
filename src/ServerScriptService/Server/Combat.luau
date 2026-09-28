--!nonstrict
-- Combat (ModuleScript) -> ServerScriptService/Server/Combat
-- Server-authoritative abilities bound on the client with ContextActionService:
--   LMB  basic attack / combo (also trains Power)
--   Q    dash (short i-frames)
--   E    weapon skill (signature skill on iconic weapons)
--   R    class ultimate
--   C    Overdrive (handled in Actions)
-- Stamina, cooldowns (with the global nerf multipliers), stun caps and
-- damage caps are all enforced here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local Projectiles = require(script.Parent:WaitForChild("Projectiles"))

local Combat = {}
local map = nil
local B = Config.Balance

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include
wallParams.RespectCanCollide = true

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function rootOf(player: Player): BasePart?
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then
		return nil
	end
	return c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function readAim(payload, root: BasePart): Vector3
	local aim = type(payload) == "table" and payload.Aim
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 2 then
		-- horizontal: projectiles fly at chest height and never dive into the floor
		return flat(aim)
	end
	return flat(root.CFrame.LookVector)
end

local function limitByWalls(from: Vector3, dir: Vector3, dist: number): number
	local hit = workspace:Raycast(from, dir * dist, wallParams)
	if hit then
		return math.max(0, (hit.Position - from).Magnitude - 2)
	end
	return dist
end

function Combat.PadAt(player: Player)
	local root = rootOf(player)
	if not root or not map then
		return nil, nil
	end
	local pos = root.Position
	for _, pad in ipairs(map.TrainPads) do
		local d = Vector3.new(pos.X - pad.Position.X, 0, pos.Z - pad.Position.Z).Magnitude
		if d <= Config.TrainPadRadius and math.abs(pos.Y - pad.Position.Y) < 7 then
			return pad.Index, pad.Config
		end
	end
	return nil, nil
end

local function padReqText(pad): string
	if pad.Rebirths > 0 then
		return pad.Rebirths .. " Rebirth" .. (pad.Rebirths > 1 and "s" or "")
	end
	return Format.Abbrev(pad.Power) .. " Power"
end

local function spendStamina(player: Player, s, cost: number): boolean
	if s.Stamina < cost then
		Net.FX(player, "NoStamina", {})
		return false
	end
	s.Stamina -= cost
	s.LastStaminaSpend = os.clock()
	player:SetAttribute("Stamina", math.floor(s.Stamina))
	return true
end

-- One damage instance with crits, race passives and weapon passives.
local function hit(player: Player, e, coef: number, opts): boolean
	if e.Dead or not EnemyService.CanDamage(player, e) then
		return false
	end
	local data = DataService.Get(player)
	local race = Stats.Race(data)
	local dmg = Stats.Damage(player) * coef * (0.92 + math.random() * 0.16)
	local crit = math.random() < Stats.CritChance(player)
	if crit then
		dmg *= Stats.CritMult()
	end
	if race.FirstHit and e.HP >= e.MaxHP then
		dmg *= race.FirstHit
		crit = true
	end
	EnemyService.Damage(e, player, dmg, crit)
	if opts then
		if opts.Knockback and opts.From then
			EnemyService.Knockback(e, flat(e.Root.Position - opts.From), opts.Knockback)
		end
		if opts.Stun then
			EnemyService.Stun(e, opts.Stun)
		end
		if opts.Pull then
			EnemyService.Pull(e, opts.Pull, 40)
		end
		if opts.Ragdoll then
			EnemyService.Ragdoll(e, opts.Ragdoll)
		end
		if opts.Ticks then
			EnemyService.DoT(e, player, Stats.Damage(player) * opts.Ticks.Damage, opts.Ticks.Count, opts.Ticks.Interval)
		end
	end
	if (opts and opts.Burn or Stats.HasPassive(player, "Hellfire")) and math.random() < 0.2 then
		EnemyService.DoT(e, player, Stats.Damage(player) * 0.3, 3, 0.4, Color3.fromRGB(190, 80, 255))
	end
	return true
end

local function notifyBlocked(player: Player, s, e)
	local t = os.clock()
	if e.StageIndex and t - (s.LastBlockedNotify or 0) > 3 then
		s.LastBlockedNotify = t
		local stage = Config.Stages[e.StageIndex]
		Net.Notify(player, "Too weak! Stage " .. e.StageIndex .. " needs " .. Format.Abbrev(stage.PowerReq) .. " Power.", Color3.fromRGB(255, 120, 90), "Error")
	end
end

local function hitList(player: Player, s, list, coef: number, opts)
	for _, e in ipairs(list) do
		if not hit(player, e, coef, opts) and not e.Dead then
			notifyBlocked(player, s, e)
		end
	end
end

---------------------------------------------------------------------
-- BASIC ATTACK (LMB)
---------------------------------------------------------------------
local function train(player: Player, data)
	local padIndex, pad = Combat.PadAt(player)
	local mult = 1
	if pad and Stats.PadUnlocked(data, pad) then
		mult = pad.Mult
	else
		padIndex = nil
	end
	local gain = Config.ClickPower * mult * Stats.PowerMult(player)
	data.Power += gain
	Net.FX(player, "Power", { Amount = gain, Pad = padIndex })
end

local function basicAttack(player: Player, payload)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local root = rootOf(player)
	if not data or not s or not root or os.clock() < s.StunnedUntil then
		return
	end
	local def, rarity = Stats.Weapon(player)
	local class = Config.WeaponClasses[def.Class]
	local interval = class.Interval / (1 + Stats.AttackSpeed(player))
	local t = os.clock()
	if t - s.LastAttack < interval * 0.8 then
		return
	end
	if t - s.LastAttack > interval * 2.5 then
		s.Combo = 0
	end
	s.LastAttack = t
	s.Combo = s.Combo % #class.Combo + 1
	s.SwingCount += 1
	local coef = class.Combo[s.Combo]
	local aim = readAim(payload, root)

	train(player, data)

	if class.Kind == "Ranged" then
		local origin = root.Position + Vector3.new(0, 1.2, 0) + aim * 2
		local pierce = Stats.HasPassive(player, "LoneWolf") and 1 or nil
		Projectiles.Fire({
			Owner = player,
			Origin = origin,
			Dir = aim,
			Speed = class.Speed,
			Range = class.Range,
			Radius = class.Radius,
			Pierce = pierce,
			Kind = class.Projectile,
			Color = def.Glow or rarity.Color,
			Size = 1.2,
			OnHit = function(e)
				if not hit(player, e, coef) then
					notifyBlocked(player, s, e)
				end
			end,
		})
	else
		local dir = flat(aim)
		hitList(player, s, EnemyService.InCone(root.Position, dir, class.Range, class.Arc), coef, nil)
	end

	-- Sorcerer race: every Nth swing is an elemental AoE
	local race = Stats.Race(data)
	local heavy = race.AoEEvery ~= nil and s.SwingCount % race.AoEEvery == 0
	if heavy then
		hitList(player, s, EnemyService.InSphere(root.Position, 18), 1.5, nil)
	end

	Net.FXAll("Attack", { Player = player, Class = def.Class, Combo = s.Combo, Dir = aim, Color = def.Glow or rarity.Color, Heavy = heavy })
	DataService.MarkDirty(player)
end

---------------------------------------------------------------------
-- DASH (Q)
---------------------------------------------------------------------
local function dash(player: Player, payload)
	local s = DataService.Session(player)
	local root = rootOf(player)
	if not s or not root then
		return
	end
	local t = os.clock()
	if (s.Cooldowns.Q or 0) > t + 0.1 then
		return
	end
	if not spendStamina(player, s, Stats.StaminaCost(player, B.DashStamina)) then
		return
	end
	s.Cooldowns.Q = t + B.DashCooldown * B.CooldownMult
	s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + B.DashIFrames)
	Net.FX(player, "Cooldown", { Slot = "Q", Duration = B.DashCooldown * B.CooldownMult })
	Net.FXAll("Dash", { Player = player, Dir = readAim(payload, root) })
end

---------------------------------------------------------------------
-- SKILLS (E / R)
---------------------------------------------------------------------
local executors = {}

executors.Cone = function(player, s, skill, root, aim)
	local dir = flat(aim)
	local hits = skill.Hits or 1
	task.spawn(function()
		for i = 1, hits do
			if i > 1 then
				task.wait(skill.Interval or 0.1)
			end
			local r = rootOf(player)
			if not r then
				return
			end
			hitList(player, s, EnemyService.InCone(r.Position, dir, skill.Range, skill.Arc or 0), skill.Damage, { Knockback = skill.Knockback, From = r.Position, Stun = skill.Stun })
		end
	end)
end

executors.Nova = function(player, s, skill, root)
	local hits = skill.Hits or 1
	task.spawn(function()
		for i = 1, hits do
			if i > 1 then
				task.wait(skill.Interval or 0.12)
			end
			local r = rootOf(player)
			if not r then
				return
			end
			hitList(player, s, EnemyService.InSphere(r.Position, skill.Radius), skill.Damage, {
				Knockback = skill.Knockback,
				From = r.Position,
				Stun = skill.Stun,
				Pull = skill.Pull and r.Position or nil,
			})
		end
	end)
end

local function fireSkillProjectile(player, s, skill, origin: Vector3, dir: Vector3, coef: number, size: number?)
	Projectiles.Fire({
		Owner = player,
		Origin = origin,
		Dir = dir,
		Speed = skill.Speed,
		Range = skill.Range,
		Radius = skill.Radius,
		Pierce = skill.Pierce,
		Kind = skill.Projectile,
		Color = skill.Color,
		Size = size or skill.Size,
		Explode = skill.Explode,
		OnHit = function(e)
			if not hit(player, e, coef, { Knockback = skill.Knockback, From = origin }) then
				notifyBlocked(player, s, e)
			end
		end,
		OnExplode = function(pos, radius)
			hitList(player, s, EnemyService.InSphere(pos, radius), coef * 0.5, { Knockback = 40, From = pos })
		end,
	})
end

executors.Projectile = function(player, s, skill, root, aim, charge)
	local frac = skill.Charge and math.clamp((charge or 0) / skill.Charge, 0, 1) or 0
	local coef = skill.Damage * (1 + (skill.ChargeBonus or 0) * frac)
	local size = (skill.Size or 1.5) * (1 + frac * 0.6)
	fireSkillProjectile(player, s, skill, root.Position + Vector3.new(0, 1.2, 0) + aim * 2.5, aim, coef, size)
end

executors.Barrage = function(player, s, skill, _root, aim)
	local count = skill.Count
	local gap = skill.Duration / count
	task.spawn(function()
		for i = 1, count do
			local r = rootOf(player)
			if not r then
				return
			end
			local dir
			if skill.Spread >= 360 then
				local a = (i / count) * math.pi * 2 * 3
				dir = Vector3.new(math.cos(a), 0, math.sin(a))
			else
				local yaw = math.rad((math.random() - 0.5) * skill.Spread)
				local pitch = math.rad((math.random() - 0.5) * skill.Spread * 0.25)
				dir = (CFrame.lookAt(Vector3.zero, aim) * CFrame.Angles(pitch, yaw, 0)).LookVector
			end
			fireSkillProjectile(player, s, skill, r.Position + Vector3.new(0, 1.2, 0) + dir * 2, dir, skill.Damage)
			task.wait(gap)
		end
	end)
end

executors.DashStrike = function(player, s, skill, root, aim)
	local dir = flat(aim)
	local start = root.Position
	local dist = limitByWalls(start, dir, skill.Distance)
	local finish = start + dir * dist
	s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + 0.15)
	task.delay(0.08, function()
		hitList(player, s, EnemyService.InSegment(start, finish, skill.Width / 2), skill.Damage, { Knockback = skill.Knockback, From = start, Burn = skill.Burn })
	end)
	return { Finish = finish }
end

executors.ChargeLunge = function(player, s, skill, root, aim, charge)
	local dir = flat(aim)
	local start = root.Position
	local dist = limitByWalls(start, dir, skill.Distance)
	local finish = start + dir * dist
	local frac = math.clamp((charge or 0) / skill.Charge, 0, 1)
	local coef = skill.Damage * (1 + (skill.ChargeBonus or 0) * frac)
	s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + 0.2)
	task.delay(0.12, function()
		local targets = EnemyService.InSegment(start, finish, skill.Width / 2)
		local first = nil
		local best = math.huge
		for _, e in ipairs(targets) do
			local d = (e.Root.Position - start).Magnitude
			if d < best and EnemyService.CanDamage(player, e) then
				first, best = e, d
			end
		end
		if not first then
			return
		end
		local impact = first.Root.Position
		hit(player, first, coef, { Knockback = skill.Knockback * (0.6 + frac * 0.4), From = start, Ragdoll = skill.Ragdoll, Ticks = skill.Ticks })
		for _, e in ipairs(EnemyService.InSphere(impact, 9)) do
			if e ~= first then
				hit(player, e, coef * 0.4, { Knockback = 50, From = impact })
			end
		end
		Net.FXAll("Impact", { Pos = impact, Color = skill.Color, Radius = 12, Kind = "Rasengan" })
	end)
	return { Finish = finish }
end

local function targetPoint(root: BasePart, aim: Vector3, payload, range: number): Vector3
	local tp = type(payload) == "table" and payload.Target
	if typeof(tp) == "Vector3" and (tp - root.Position).Magnitude <= range + 5 then
		return Vector3.new(tp.X, root.Position.Y - 2.5, tp.Z)
	end
	local p = root.Position + flat(aim) * range * 0.6
	return Vector3.new(p.X, root.Position.Y - 2.5, p.Z)
end

executors.Zone = function(player, s, skill, root, aim, _charge, payload)
	local center = targetPoint(root, aim, payload, skill.Range)
	task.spawn(function()
		for _ = 1, skill.Ticks do
			hitList(player, s, EnemyService.InSphere(center, skill.Radius), skill.Damage, { Pull = center })
			task.wait(skill.Interval)
		end
	end)
	return { Target = center, Duration = skill.Ticks * skill.Interval }
end

executors.Rain = function(player, s, skill, root, aim, _charge, payload)
	local center = targetPoint(root, aim, payload, skill.Range)
	task.spawn(function()
		for _ = 1, skill.Hits do
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * skill.Radius
			local pt = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			Net.FXAll("Impact", { Pos = pt, Color = skill.Color, Radius = 7, Kind = "Rain" })
			hitList(player, s, EnemyService.InSphere(pt, 7), skill.Damage, nil)
			task.wait(skill.Interval)
		end
	end)
	return { Target = center }
end

local function castSkill(player: Player, slot: string, payload, charge: number?)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local root = rootOf(player)
	if not data or not s or not root or os.clock() < s.StunnedUntil then
		return
	end
	local def = Stats.Weapon(player)
	local class = Config.WeaponClasses[def.Class]
	local skillId = slot == "E" and def.Skill or class.Ultimate
	local skill = Config.Skills[skillId]
	local exec = skill and executors[skill.Type]
	if not exec then
		return
	end
	local t = os.clock()
	if (s.Cooldowns[slot] or 0) > t + 0.1 then
		Net.FX(player, "AbilityFail", { Slot = slot })
		return
	end
	if not spendStamina(player, s, Stats.StaminaCost(player, skill.Stamina)) then
		return
	end
	local cd = Stats.Cooldown(player, skillId, skill.Cooldown)
	s.Cooldowns[slot] = t + cd
	Net.FX(player, "Cooldown", { Slot = slot, Duration = cd })

	local aim = readAim(payload, root)
	local extra = exec(player, s, skill, root, aim, charge, payload) or {}
	Net.FXAll("Skill", {
		Player = player,
		Skill = skillId,
		Slot = slot,
		Pos = root.Position,
		Dir = aim,
		Charge = charge,
		Finish = extra.Finish,
		Target = extra.Target,
		Duration = extra.Duration,
	})
end

---------------------------------------------------------------------
-- POTION
---------------------------------------------------------------------
local function potion(player: Player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not s or not hum or hum.Health <= 0 then
		return
	end
	if data.Potions <= 0 then
		Net.Notify(player, "No Health Potions. Earn them from play-time rewards!", Color3.fromRGB(255, 120, 90), "Error")
		return
	end
	if os.clock() - s.LastPotion < Config.Potion.Cooldown then
		return
	end
	s.LastPotion = os.clock()
	data.Potions -= 1
	hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * Config.Potion.Heal)
	Net.FX(player, "Potion", { Cooldown = Config.Potion.Cooldown })
	DataService.MarkDirty(player)
end

---------------------------------------------------------------------
local function onAbility(player: Player, action, payload)
	if type(action) ~= "string" then
		return
	end
	local s = DataService.Session(player)
	if not s then
		return
	end
	if action == "Attack" then
		basicAttack(player, payload)
	elseif action == "Dash" then
		dash(player, payload)
	elseif action == "Skill" or action == "Ultimate" then
		local slot = action == "Skill" and "E" or "R"
		local def = Stats.Weapon(player)
		local skillId = slot == "E" and def.Skill or Config.WeaponClasses[def.Class].Ultimate
		local skill = Config.Skills[skillId]
		if skill and not skill.Charge then
			castSkill(player, slot, payload, nil)
		end
	elseif action == "ChargeBegin" then
		local slot = type(payload) == "table" and payload.Slot
		if slot == "E" or slot == "R" then
			s.Charge[slot] = os.clock()
			Net.FXAll("Charge", { Player = player, Slot = slot })
		end
	elseif action == "ChargeRelease" then
		local slot = type(payload) == "table" and payload.Slot
		if (slot == "E" or slot == "R") and s.Charge[slot] then
			local held = os.clock() - s.Charge[slot]
			s.Charge[slot] = nil
			castSkill(player, slot, payload, held)
		end
	elseif action == "Potion" then
		potion(player)
	end
end

function Combat.Init(m)
	map = m
	wallParams.FilterDescendantsInstances = { map.Root, map.TowerArenas }
	Projectiles.SetWorld({ map.Root, map.TowerArenas })
	Net.Ability.OnServerEvent:Connect(function(player, action, payload)
		local ok, err = pcall(onAbility, player, action, payload)
		if not ok then
			warn("[Ability]", err)
		end
	end)

	EnemyService.OnKill = function(player: Player)
		if Stats.HasPassive(player, "RiftHunger") then
			local s = DataService.Session(player)
			if s then
				s.Stamina = math.min(B.MaxStamina, s.Stamina + 12)
				player:SetAttribute("Stamina", math.floor(s.Stamina))
			end
		end
	end

	-- stamina regen
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local t = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local s = DataService.Session(player)
				if s and s.Stamina < B.MaxStamina and t - s.LastStaminaSpend >= B.StaminaRegenDelay then
					s.Stamina = math.min(B.MaxStamina, s.Stamina + B.StaminaRegen * dt)
					local shown = math.floor(s.Stamina)
					if player:GetAttribute("Stamina") ~= shown then
						player:SetAttribute("Stamina", shown)
					end
				end
			end
		end
	end)

	-- auto-training while standing on a pad
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				local s = DataService.Session(player)
				if data and s then
					local padIndex, pad = Combat.PadAt(player)
					if pad then
						if Stats.PadUnlocked(data, pad) then
							local gain = Config.AutoTrainPerSecond * pad.Mult * Stats.PowerMult(player)
							data.Power += gain
							Net.FX(player, "Power", { Amount = gain, Pad = padIndex, Auto = true })
							DataService.MarkDirty(player)
						elseif s.Pad ~= padIndex then
							Net.Notify(player, "This pad needs " .. padReqText(pad) .. ".", Color3.fromRGB(255, 120, 90), "Error")
						end
					end
					s.Pad = padIndex or 0
				end
			end
		end
	end)
end

return Combat
