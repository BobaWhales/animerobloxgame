--!nonstrict
-- Combat (ModuleScript) -> ServerScriptService/Server/Combat
-- Server-authoritative abilities bound on the client with ContextActionService:
--   LMB  basic attack / combo (also trains Power)
--   Q    dash (short i-frames)
--   E    weapon skill (signature skill on iconic weapons)
--   R    class ultimate
--   C    Overdrive (handled in Actions)
-- Stamina, cooldowns (with the global nerf multipliers), stun caps and
-- damage caps are all enforced here, and so are the ore effects forged into
-- the equipped weapon (burn, frost, shock, poison, bleed, lifesteal, echo,
-- radiant splash, void execute, titan, gale...).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))

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
	if (pad.Ascensions or 0) > 0 then
		return pad.Ascensions .. " Ascension" .. (pad.Ascensions > 1 and "s" or "")
	end
	return pad.Rebirths .. " Rebirth" .. (pad.Rebirths > 1 and "s" or "")
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

local function proc(e, effectId: string)
	Net.FXAll("Proc", { Pos = e.Root.Position + Vector3.new(0, e.Scale, 0), Effect = effectId })
end

local function heal(player: Player, fraction: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and fraction > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * fraction)
	end
end

-- One damage instance with crits, race passives, weapon passives and the
-- weapon's ore effects. opts.NoProc stops effects re-triggering on splashes.
local function hit(player: Player, e, coef: number, opts): boolean
	if e.Dead or not EnemyService.CanDamage(player, e) then
		return false
	end
	local data = DataService.Get(player)
	local race = Stats.Race(data)
	local E = function(id)
		return Stats.Effect(player, id)
	end
	local dmg = Stats.Damage(player) * coef * (0.92 + math.random() * 0.16)
	local crit = math.random() < Stats.CritChance(player)
	if crit then
		dmg *= Stats.CritMult()
	end
	if race.FirstHit and e.HP >= e.MaxHP then
		dmg *= race.FirstHit
		crit = true
	end
	if e.Boss then
		dmg *= 1 + E("Titan")
		if Stats.HasPassive(player, "OniWrath") then
			dmg *= 1.3
		end
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
	if opts and opts.NoProc then
		return true
	end

	-- ore effects ------------------------------------------------------
	local base = Stats.Damage(player)
	if math.random() < E("Burn") then
		EnemyService.DoT(e, player, base * 0.3, 3, 0.4, Color3.fromRGB(255, 120, 40))
	end
	if math.random() < E("Frost") then
		EnemyService.Slow(e, 1.5)
		proc(e, "Frost")
	end
	if math.random() < E("Poison") then
		EnemyService.DoT(e, player, base * 0.15, 4, 0.5, Color3.fromRGB(120, 230, 90))
	end
	local bleed = E("Bleed")
	if crit and bleed > 0 then
		EnemyService.DoT(e, player, dmg * bleed / 3, 3, 0.35, Color3.fromRGB(220, 30, 50))
	end
	if math.random() < E("Shock") then
		local best, bestD = nil, 16
		for _, other in ipairs(EnemyService.InSphere(e.Root.Position, 16)) do
			local d = (other.Root.Position - e.Root.Position).Magnitude
			if other ~= e and d < bestD and EnemyService.CanDamage(player, other) then
				best, bestD = other, d
			end
		end
		if best then
			Net.FXAll("Chain", { From = e.Root.Position, To = best.Root.Position, Color = Config.Effects.Shock.Color })
			hit(player, best, coef * 0.5, { NoProc = true })
		end
	end
	local radiant = E("Radiant")
	if radiant > 0 then
		for _, other in ipairs(EnemyService.InSphere(e.Root.Position, 8)) do
			if other ~= e then
				hit(player, other, coef * radiant, { NoProc = true })
			end
		end
		proc(e, "Radiant")
	end
	if math.random() < E("Echo") and not e.Dead then
		task.delay(0.12, function()
			if not e.Dead then
				hit(player, e, coef, { NoProc = true })
				proc(e, "Echo")
			end
		end)
	end
	if Stats.HasPassive(player, "Binding") and math.random() < 0.15 then
		EnemyService.Stun(e, 0.4)
	end
	heal(player, E("Lifesteal") + Stats.ArmorBonus(player, "Lifesteal"))
	local void = E("Void")
	if void > 0 and not e.Dead and not e.Boss and e.HP / e.MaxHP < void then
		proc(e, "Void")
		EnemyService.Damage(e, player, e.HP + 1, true)
	end
	return true
end

local function notifyBlocked(player: Player, s, e)
	local t = os.clock()
	if e.Owner and e.Owner ~= player and t - (s.LastBlockedNotify or 0) > 3 then
		s.LastBlockedNotify = t
		Net.Notify(player, "That enemy belongs to someone else's fight.", Color3.fromRGB(255, 120, 90), "Error")
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

	local pierceBonus = Stats.Effect(player, "Pierce")
	if class.Kind == "Ranged" then
		local origin = root.Position + Vector3.new(0, 1.2, 0) + aim * 2
		local pierce = (Stats.HasPassive(player, "LoneWolf") and 1 or 0) + math.floor(pierceBonus * 10)
		local explode = class.Explode and class.Explode * (Stats.HasPassive(player, "Psycho") and 1.5 or 1) or nil
		local shots = class.Multi or 1
		for k = 1, shots do
			local yaw = shots > 1 and math.rad((k - (shots + 1) / 2) * 10) or 0
			local dir = (CFrame.lookAt(Vector3.zero, aim) * CFrame.Angles(0, yaw, 0)).LookVector
			Projectiles.Fire({
				Owner = player,
				Origin = origin,
				Dir = dir,
				Speed = class.Speed,
				Range = class.Range,
				Radius = class.Radius,
				Pierce = pierce > 0 and pierce or nil,
				Kind = class.Projectile,
				Color = def.Glow or rarity.Color,
				Size = 1.2,
				Explode = explode,
				OnHit = function(e)
					if not hit(player, e, coef) then
						notifyBlocked(player, s, e)
					end
				end,
				OnExplode = explode and function(pos, radius)
					hitList(player, s, EnemyService.InSphere(pos, radius), coef * 0.5, { NoProc = true })
				end or nil,
			})
		end
	else
		local dir = flat(aim)
		local kb = (class.Knockback or 0) + Stats.Effect(player, "Gale")
		hitList(player, s, EnemyService.InCone(root.Position, dir, class.Range * (1 + pierceBonus), class.Arc), coef, kb > 0 and { Knockback = kb, From = root.Position } or nil)
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
	local dashCd = B.DashCooldown * B.CooldownMult * (Stats.HasPassive(player, "Raijin") and 0.6 or 1)
	s.Cooldowns.Q = t + dashCd
	s.InvulnUntil = math.max(s.InvulnUntil, Stats.Now() + B.DashIFrames)
	Net.FX(player, "Cooldown", { Slot = "Q", Duration = dashCd })
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
			hitList(player, s, EnemyService.InCone(r.Position, dir, skill.Range, skill.Arc or 0), skill.Damage, { Knockback = skill.Knockback, From = r.Position, Stun = skill.Stun, Pull = skill.PullIn and r.Position or nil })
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
		Explode = skill.Explode and skill.Explode * (Stats.HasPassive(player, "Psycho") and 1.5 or 1) or nil,
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
		hitList(player, s, EnemyService.InSegment(start, finish, skill.Width / 2), skill.Damage, { Knockback = skill.Knockback, From = start, Burn = skill.Burn or Stats.HasPassive(player, "DragonBlood") })
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
	-- skill mastery: more damage, Adept+ = bigger area, Expert+ = cheaper
	local mastery = Stats.MasteryLevel(player, def.Class)
	local M = Config.Mastery
	local staminaCost = Stats.StaminaCost(player, skill.Stamina) * (mastery >= M.Milestones[2].Level and 0.8 or 1)
	if not spendStamina(player, s, staminaCost) then
		return
	end
	skill = table.clone(skill)
	skill.Damage = (skill.Damage or 1) * Stats.MasteryDamage(mastery)
	if mastery >= M.Milestones[1].Level then
		for _, key in ipairs({ "Range", "Radius", "Width", "Distance" }) do
			if type(skill[key]) == "number" then
				skill[key] *= 1.15
			end
		end
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
		Mastery = mastery,
	})
	Combat.GrantMastery(player, M.SkillXP[slot] or 0, def.Class)
end

-- Adds skill-mastery xp to a weapon class (default: the equipped one).
function Combat.GrantMastery(player: Player, xp: number, class: string?)
	local data = DataService.Get(player)
	if not data or xp <= 0 then
		return
	end
	class = class or Stats.Weapon(player).Class
	data.Mastery = data.Mastery or {}
	local before = Config.MasteryLevel(data.Mastery[class] or 0)
	data.Mastery[class] = (data.Mastery[class] or 0) + xp
	local after = Config.MasteryLevel(data.Mastery[class])
	if after > before then
		local milestone = nil
		for _, m in ipairs(Config.Mastery.Milestones) do
			if before < m.Level and after >= m.Level then
				milestone = m
			end
		end
		Net.FX(player, "MasteryUp", { Class = class, Level = after, Milestone = milestone and milestone.Name or nil, Desc = milestone and milestone.Desc or nil })
	end
	DataService.MarkDirty(player)
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
		local s = DataService.Session(player)
		local data = DataService.Get(player)
		local stamina = 0
		if Stats.HasPassive(player, "RiftHunger") then
			stamina += 12
		end
		if Stats.HasPassive(player, "Chakra9") then
			stamina += 10
			heal(player, 0.05)
		end
		if s and stamina > 0 then
			s.Stamina = math.min(B.MaxStamina, s.Stamina + stamina)
			player:SetAttribute("Stamina", math.floor(s.Stamina))
		end
		-- ore effects on kill
		heal(player, Stats.Effect(player, "Holy"))
		local soul = Stats.Effect(player, "Soul")
		if soul > 0 and data then
			local gain = Config.ClickPower * Stats.PowerMult(player) * soul
			data.Power += gain
			Net.FX(player, "Power", { Amount = gain })
			DataService.MarkDirty(player)
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
