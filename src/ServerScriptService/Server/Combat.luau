--!nonstrict
-- Combat (ModuleScript) -> ServerScriptService/Server/Combat
-- Server-validated sword swings (cleave hits, crits, race passives) and
-- Power training (every swing trains; standing on a pad auto-trains).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Sword = require(script.Parent:WaitForChild("Sword"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))

local Combat = {}
local map = nil

function Combat.PadAt(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
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

function Combat.Swing(player: Player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not s or not root or not hum or hum.Health <= 0 then
		return
	end
	local tool = Sword.Find(player)
	if not tool or tool.Parent ~= char then
		return
	end
	local t = os.clock()
	local race = Stats.Race(data)
	local cd = Config.SwingCooldown * (race.Id == "Ninja" and 0.85 or 1) * (Stats.OverdriveActive(player) and 0.8 or 1)
	if t - s.LastSwing < cd * 0.8 then
		return
	end
	s.LastSwing = t
	s.SwingCount += 1

	-- training
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

	Sword.PlaySlashAnim(player)
	Sword.SetTrail(player, true)
	task.delay(0.28, Sword.SetTrail, player, false)

	-- hits
	local heavy = race.AoEEvery ~= nil and s.SwingCount % race.AoEEvery == 0
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = if look.Magnitude > 0 then look.Unit else Vector3.new(0, 0, -1)
	local targets = heavy and EnemyService.InRange(root.Position, nil, 18) or EnemyService.InRange(root.Position, look, Config.SwingRange)
	local baseDmg = Stats.Damage(player)
	local critChance = Stats.CritChance(player)
	local blockedStage = nil
	for _, e in ipairs(targets) do
		if e.StageIndex and not Stats.StageUnlocked(data, e.StageIndex) then
			blockedStage = e.StageIndex
		else
			local dmg = baseDmg * (heavy and 1.5 or 1) * (0.9 + math.random() * 0.2)
			local crit = math.random() < critChance
			if crit then
				dmg *= Config.CritMultiplier
			end
			if race.FirstHit and e.HP >= e.MaxHP then
				dmg *= race.FirstHit
				crit = true
			end
			EnemyService.Damage(e, player, dmg, crit)
		end
	end
	if blockedStage and t - (s.LastBlockedNotify or 0) > 3 then
		s.LastBlockedNotify = t
		local stage = Config.Stages[blockedStage]
		Net.Notify(player, "Too weak! Stage " .. blockedStage .. " needs " .. Format.Abbrev(stage.PowerReq) .. " Power.", Color3.fromRGB(255, 120, 90), "Error")
	end

	local tier = Config.GetBladeTier(data.Blade)
	Net.FXAll("Swing", { Player = player, Heavy = heavy, Color = tier.Edge or Color3.fromRGB(230, 240, 255), Tier = tier.Level })
	DataService.MarkDirty(player)
end

function Combat.Init(m)
	map = m
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
