--!nonstrict
-- Admin (ModuleScript) -> ServerScriptService/Server/Admin
-- Admin panel backend. Every command is re-checked on the server
-- (Admin.IsAdmin), so the client panel is only a remote control.
-- Admins: the place owner, anyone in Studio, Config.Admins.UserIds, or a
-- group rank >= Config.Admins.MinRank.
--
-- Player commands (target = you, a player, or "All"):
--   give Coins / Power / Rebirths / Ascensions / Rerolls / Overdrive /
--   Catalysts / Ores / a Weapon / an Armor, unlock stages, heal, god mode,
--   speed boost, teleport to / bring, reset data.
-- "Admin abuse" (whole server):
--   2x Luck / 3x Coins / 5x Power / 2x Drops events, Ore Rain, Coin Rain,
--   Boss Invasion at spawn, Everyone Overdrive, Kill All, announcements.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local Util = require(script.Parent:WaitForChild("Util"))

local Admin = {}
Admin.OnApplyCharacter = nil :: ((Player) -> ())?
Admin.OnCosmetics = nil :: ((Player) -> ())?

local map = nil
local GOLD = Color3.fromRGB(255, 215, 90)
local calls = {}
local groupCache: { [number]: { [number]: number } } = {} -- [userId] = { [groupId] = rank }

-- Group ranks are fetched once per player (web call) and cached.
local function rankIn(player: Player, groupId: number): number
	local ranks = groupCache[player.UserId]
	if not ranks then
		ranks = {}
		local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
		if ok and type(groups) == "table" then
			for _, g in ipairs(groups) do
				ranks[g.Id] = g.Rank
			end
			groupCache[player.UserId] = ranks
		end
	end
	return ranks[groupId] or 0
end

function Admin.IsAdmin(player: Player): boolean
	local A = Config.Admins
	if A.StudioIsAdmin and RunService:IsStudio() then
		return true
	end
	if A.OwnerIsAdmin then
		if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			return true
		end
		if game.CreatorType == Enum.CreatorType.Group then
			if rankIn(player, game.CreatorId) == 255 then
				return true
			end
		end
	end
	if table.find(A.UserIds, player.UserId) then
		return true
	end
	if A.GroupId and A.GroupId ~= 0 then
		if rankIn(player, A.GroupId) >= A.MinRank then
			return true
		end
	end
	return false
end

local function targets(admin: Player, target): { Player }
	if target == "All" then
		return Players:GetPlayers()
	end
	if type(target) == "number" then
		local p = Players:GetPlayerByUserId(target)
		return p and { p } or {}
	end
	return { admin }
end

local function num(v, default: number, max: number?): number
	local n = tonumber(v) or default
	if n ~= n or n == math.huge then
		n = default
	end
	return math.clamp(n, 0, max or 1e300)
end

local function changed(p: Player)
	DataService.MarkDirty(p)
end

---------------------------------------------------------------------
-- PLAYER COMMANDS
---------------------------------------------------------------------
local cmd = {}

cmd.GiveCoins = function(_, p, args)
	local data = DataService.Get(p)
	data.Coins += num(args.Amount, 1000)
	changed(p)
end

cmd.GivePower = function(_, p, args)
	local data = DataService.Get(p)
	data.Power += num(args.Amount, 1000)
	changed(p)
end

cmd.GiveRebirths = function(_, p, args)
	local data = DataService.Get(p)
	data.Rebirths += math.floor(num(args.Amount, 1, 1e6))
	data.Rebirths = math.max(0, data.Rebirths)
	changed(p)
	if Admin.OnCosmetics then
		Admin.OnCosmetics(p)
	end
end

cmd.GiveAscensions = function(_, p, args)
	local data = DataService.Get(p)
	data.Ascensions += math.floor(num(args.Amount, 1, 1000))
	changed(p)
	if Admin.OnCosmetics then
		Admin.OnCosmetics(p)
	end
end

cmd.GiveRerolls = function(_, p, args)
	local data = DataService.Get(p)
	data.Rerolls += math.floor(num(args.Amount, 5, 1e6))
	changed(p)
end

cmd.GiveOverdrive = function(_, p, args)
	local data = DataService.Get(p)
	data.Overdrive += math.floor(num(args.Amount, 3, 1e6))
	changed(p)
end

cmd.GiveCatalysts = function(_, p, args)
	local data = DataService.Get(p)
	local n = math.floor(num(args.Amount, 1, 1e5))
	for _, key in ipairs(Config.CatalystOrder) do
		data.Keys[key] = (data.Keys[key] or 0) + n
	end
	changed(p)
end

cmd.GiveOre = function(_, p, args)
	local data = DataService.Get(p)
	local ore = type(args.Ore) == "string" and Config.OreById[args.Ore]
	if not ore then
		return
	end
	-- admin ore bypasses the bag limit
	data.Backpack[ore.Id] = (data.Backpack[ore.Id] or 0) + math.floor(num(args.Amount, 10, 1e6))
	data.Index[ore.Id] = true
	changed(p)
end

cmd.GiveAllOres = function(_, p, args)
	local data = DataService.Get(p)
	local n = math.floor(num(args.Amount, 3, 1e5))
	for _, ore in ipairs(Config.Ores) do
		data.Backpack[ore.Id] = (data.Backpack[ore.Id] or 0) + n
		data.Index[ore.Id] = true
	end
	changed(p)
end

cmd.GiveWeapon = function(_, p, args)
	local def = type(args.Weapon) == "string" and Config.WeaponById[args.Weapon]
	local rarity = type(args.Rarity) == "string" and Config.WeaponRarityById[args.Rarity]
	if not def or not rarity then
		return
	end
	-- a strong, clean effect roll so admin weapons feel special
	local effects = {}
	if type(args.Effect) == "string" and Config.Effects[args.Effect] then
		effects[args.Effect] = 30
	end
	local uid = Weapons.Add(p, def.Id, rarity.Id, effects)
	if uid then
		Net.FX(p, "ForgeResult", { Uid = uid, Weapon = def.Id, Rarity = rarity.Id, Effects = effects, Gained = 0, From = 0, To = 0, Admin = true })
	end
end

cmd.GiveArmor = function(_, p, args)
	local def = type(args.Armor) == "string" and Config.ArmorById[args.Armor]
	local rarity = type(args.Rarity) == "string" and Config.WeaponRarityById[args.Rarity]
	if not def or not rarity then
		return
	end
	if Weapons.AddArmor(p, def.Id, rarity.Id) then
		Net.FX(p, "ArmorDrop", { Armor = def.Id, Rarity = rarity.Id })
	end
end

cmd.SetStage = function(_, p, args)
	local data = DataService.Get(p)
	data.Stage = math.clamp(math.floor(num(args.Amount, #Config.Stages)), 0, #Config.Stages)
	data.StageKills = 0
	changed(p)
end

cmd.Heal = function(_, p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth
	end
end

cmd.God = function(_, p)
	local s = DataService.Session(p)
	if s then
		s.God = not s.God
		p:SetAttribute("God", s.God)
		Net.Notify(p, "God mode " .. (s.God and "ON" or "OFF"), GOLD)
	end
end

cmd.Speed = function(_, p)
	local s = DataService.Session(p)
	if s then
		s.AdminSpeed = not s.AdminSpeed
		if Admin.OnApplyCharacter then
			Admin.OnApplyCharacter(p)
		end
		Net.Notify(p, "Speed boost " .. (s.AdminSpeed and "ON" or "OFF"), GOLD)
	end
end

cmd.GoTo = function(admin, p)
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and p ~= admin then
		Util.Teleport(admin, root.CFrame * CFrame.new(0, 0, 5), p.DisplayName)
	end
end

cmd.Bring = function(admin, p)
	local char = admin.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and p ~= admin then
		Util.Teleport(p, root.CFrame * CFrame.new(0, 0, -5), "Summoned by an admin")
	end
end

cmd.ResetData = function(_, p)
	local data = DataService.Get(p)
	for _, key in ipairs({ "Power", "Coins", "Blade", "Rebirths", "Ascensions", "Runes", "Stage", "StageKills", "Kills", "TowerBest" }) do
		data[key] = 0
	end
	data.Backpack = {}
	changed(p)
	Net.Notify(p, "Your progress was reset by an admin.", Color3.fromRGB(255, 120, 90), "Error")
end

---------------------------------------------------------------------
-- ADMIN ABUSE (server-wide)
---------------------------------------------------------------------
local global = {}

local function syncAll()
	for _, p in ipairs(Players:GetPlayers()) do
		DataService.MarkDirty(p)
	end
end

global.StartEvent = function(_, args)
	local key = args.Event
	local ev = type(key) == "string" and Config.Events[key]
	if not ev then
		return
	end
	local duration = math.clamp(num(args.Amount, ev.Duration / 60) * 60, 30, 6 * 3600)
	Stats.ActiveEvents[key] = { EndsAt = Stats.Now() + duration, Mult = ev.Mult }
	Net.FXAll("Event", { Key = key, Name = ev.Name, Color = ev.Color, EndsAt = Stats.Now() + duration })
	syncAll()
end

global.StopEvents = function()
	table.clear(Stats.ActiveEvents)
	Net.FXAll("Notify", { Text = "All server events ended.", Color = GOLD })
	syncAll()
end

global.Announce = function(admin, args)
	local text = type(args.Text) == "string" and args.Text:sub(1, 80) or ""
	if text == "" then
		return
	end
	-- run through Roblox text filtering before broadcasting
	local ok, filtered = pcall(function()
		local result = game:GetService("TextService"):FilterStringAsync(text, admin.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	Net.FXAll("Announce", { Text = ok and filtered or "###", From = admin.DisplayName })
end

global.OreRain = function()
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(p)
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if data and root then
			local stage = Config.Stages[math.clamp(data.Stage + 1, 1, #Config.Stages)]
			for _ = 1, 12 do
				local a = math.random() * math.pi * 2
				local r = 4 + math.random() * 10
				Loot.Drop(p, Loot.RollOre(stage.Drops, Stats.Luck(p) * 2), root.Position + Vector3.new(math.cos(a) * r, -1.5, math.sin(a) * r))
			end
		end
	end
	Net.FXAll("AdminAbuse", { Kind = "OreRain" })
end

global.CoinRain = function()
	for _, p in ipairs(Players:GetPlayers()) do
		local data = DataService.Get(p)
		if data then
			local coins = math.floor(2000 * Stats.CoinMult(p) * (1 + data.Stage))
			data.Coins += coins
			Net.FX(p, "Reward", { Coins = coins, Pos = (p.Character and p.Character:GetPivot().Position) or Vector3.zero })
			DataService.MarkDirty(p)
		end
	end
	Net.FXAll("AdminAbuse", { Kind = "CoinRain" })
end

global.EveryoneOverdrive = function()
	for _, p in ipairs(Players:GetPlayers()) do
		local s = DataService.Session(p)
		local data = DataService.Get(p)
		if s and data then
			s.OverdriveEnd = Stats.Now() + Stats.OverdriveDuration(p)
			Net.FXAll("Transform", { Player = p, Kind = "Overdrive", Color = Stats.Race(data).Color })
			if Admin.OnApplyCharacter then
				Admin.OnApplyCharacter(p)
			end
			DataService.MarkDirty(p)
		end
	end
end

global.KillAll = function(admin)
	EnemyService.KillAll(admin)
end

global.BossInvasion = function()
	-- scale HP to the strongest player online so it is a real server fight
	local best = 1
	for _, p in ipairs(Players:GetPlayers()) do
		best = math.max(best, Stats.Damage(p))
	end
	local bossStages = {}
	for i, st in ipairs(Config.Stages) do
		if st.Boss then
			table.insert(bossStages, i)
		end
	end
	local stageIndex = bossStages[math.random(1, #bossStages)]
	local stage = Config.Stages[stageIndex]
	local R = Config.World.PlazaRadius
	local boss
	boss = EnemyService.Create({
		Label = "INVASION: " .. stage.Enemy,
		LookIndex = stageIndex,
		Color = Color3.fromRGB(255, 60, 80),
		Scale = 3.4,
		HP = best * 400 * math.max(1, #Players:GetPlayers()),
		Boss = true,
		Position = Vector3.new(0, 1.6, -8),
		Min = Vector3.new(-R + 8, 1.6, -R + 8),
		Max = Vector3.new(R - 8, 1.6, R - 8),
		Speed = 14,
		HitPercent = 0.05,
		OnDeath = function()
			for p in pairs(boss and boss.Damagers or {}) do
				local data = DataService.Get(p)
				if data and p.Parent then
					local coins = math.floor(10000 * Stats.CoinMult(p) * (1 + data.Stage))
					data.Coins += coins
					data.Keys.RareScroll = (data.Keys.RareScroll or 0) + 1
					if math.random() < 0.3 then
						data.Keys.Legendary = (data.Keys.Legendary or 0) + 1
					end
					EnemyService.GearDrop(p, 1)
					Net.FX(p, "Reward", { Coins = coins, Pos = Vector3.new(0, 4, -8) })
					DataService.MarkDirty(p)
				end
			end
			Net.FXAll("Notify", { Text = "The invasion was defeated! Everyone who helped got loot.", Color = GOLD, Sound = "BossKill" })
		end,
	})
	Net.FXAll("BossSpawn", { Name = "INVASION: " .. stage.Enemy, Stage = stageIndex, Zone = 0, Pos = Vector3.new(0, 4, -8), Color = stage.Color, Global = true })
end

---------------------------------------------------------------------
local function handle(admin: Player, action, args)
	if type(action) ~= "string" then
		return
	end
	if not Admin.IsAdmin(admin) then
		warn("[Admin] rejected command from non-admin " .. admin.Name)
		return
	end
	-- light rate limit so a stuck button can't flood the server
	local t = os.clock()
	local list = calls[admin] or {}
	calls[admin] = list
	while list[1] and t - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list >= 12 then
		return
	end
	table.insert(list, t)
	args = type(args) == "table" and args or {}

	if cmd[action] then
		for _, p in ipairs(targets(admin, args.Target)) do
			if DataService.Get(p) then
				cmd[action](admin, p, args)
			end
		end
	elseif global[action] then
		global[action](admin, args)
	else
		return
	end
	print(("[Admin] %s ran %s"):format(admin.Name, action))
end

function Admin.PlayerAdded(player: Player)
	task.spawn(function()
		player:SetAttribute("IsAdmin", Admin.IsAdmin(player))
		DataService.MarkDirty(player)
	end)
end

function Admin.Init(m)
	map = m
	Net.Admin.OnServerEvent:Connect(function(player, action, args)
		local ok, err = pcall(handle, player, action, args)
		if not ok then
			warn("[Admin] " .. tostring(action) .. " failed: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		calls[p] = nil
		groupCache[p.UserId] = nil
	end)
	local _ = map
end

return Admin
