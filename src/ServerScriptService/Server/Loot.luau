--!nonstrict
-- Loot (ModuleScript) -> ServerScriptService/Server/Loot
-- Ore rolls, drops, pickup, backpack, forging and selling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Sword = require(script.Parent:WaitForChild("Sword"))

local Loot = {}

-- Roll one ore from a weight table. Luck multiplies rarer ores' weights.
function Loot.RollOre(drops: { [string]: number }, luck: number, minOrder: number?): string
	local total = 0
	local entries = {}
	for oreId, weight in pairs(drops) do
		local ore = Config.OreById[oreId]
		if ore and (not minOrder or ore.Order >= minOrder) then
			local w = weight * luck ^ ((ore.Order - 1) * 0.5)
			total += w
			table.insert(entries, { oreId, w })
		end
	end
	if #entries == 0 then
		-- nothing matched the minimum rarity: give the rarest ore in the table
		local best, bestOrder = "RiftPebble", 0
		for oreId in pairs(drops) do
			local ore = Config.OreById[oreId]
			if ore and ore.Order > bestOrder then
				best, bestOrder = oreId, ore.Order
			end
		end
		return best
	end
	local r = math.random() * total
	for _, e in ipairs(entries) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

---------------------------------------------------------------------
-- INDEX (first-time discovery rewards)
---------------------------------------------------------------------
local function discover(player: Player, data, oreId: string)
	if data.Index[oreId] then
		return
	end
	data.Index[oreId] = true
	local ore = Config.OreById[oreId]
	local reward = Config.IndexReward[ore.Rarity] or 0
	data.Coins += reward
	Net.FX(player, "Discover", { Ore = oreId, Reward = reward })
end

---------------------------------------------------------------------
-- ADD ORE (backpack / auto-forge)
---------------------------------------------------------------------
function Loot.Forge(player: Player, oreId: string?, silent: boolean?): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local gained = 0
	local used = {}
	local mult = Stats.ForgeMult(player)
	for id, count in pairs(data.Backpack) do
		if count > 0 and (oreId == nil or oreId == id) then
			local ore = Config.OreById[id]
			if ore then
				gained += ore.Forge * count
				used[id] = count
			end
			data.Backpack[id] = nil
		end
	end
	if gained <= 0 then
		return 0
	end
	gained = math.max(1, math.floor(gained * mult))
	local before = data.Blade
	data.Blade += gained
	local _, tierBefore = Config.GetBladeTier(before)
	local tier, tierAfter = Config.GetBladeTier(data.Blade)
	Sword.Refresh(player, data.Blade)
	DataService.MarkDirty(player)
	if not silent then
		Net.FX(player, "Forge", {
			Gained = gained,
			From = before,
			To = data.Blade,
			Ores = used,
			TierUp = tierAfter > tierBefore and tierAfter or nil,
			TierName = tier.Name,
			Milestone = math.floor(data.Blade / 10) > math.floor(before / 10),
		})
		Net.FXAll("ForgeBurst", { Player = player })
	end
	return gained
end

function Loot.AddOre(player: Player, oreId: string, count: number): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	count = count or 1
	discover(player, data, oreId)
	if Stats.HasPass(player, "AutoForge") then
		local ore = Config.OreById[oreId]
		local before = data.Blade
		local gained = math.max(1, math.floor(ore.Forge * count * Stats.ForgeMult(player)))
		data.Blade += gained
		local _, tb = Config.GetBladeTier(before)
		local tier, ta = Config.GetBladeTier(data.Blade)
		Sword.Refresh(player, data.Blade)
		if ta > tb or math.floor(data.Blade / 10) > math.floor(before / 10) then
			Net.FX(player, "Forge", { Gained = gained, From = before, To = data.Blade, Ores = { [oreId] = count }, TierUp = ta > tb and ta or nil, TierName = tier.Name, Milestone = true, Auto = true })
		end
		DataService.MarkDirty(player)
		return true
	end
	local max = Stats.BackpackMax(player)
	local have = Stats.BackpackCount(data)
	if have >= max then
		return false
	end
	data.Backpack[oreId] = (data.Backpack[oreId] or 0) + math.min(count, max - have)
	DataService.MarkDirty(player)
	return true
end

---------------------------------------------------------------------
-- DROPS (rendered on the owner's client, validated here)
---------------------------------------------------------------------
function Loot.Drop(player: Player, oreId: string, pos: Vector3)
	local s = DataService.Session(player)
	if not s then
		return
	end
	if Stats.HasPass(player, "AutoCollect") then
		local ok = Loot.AddOre(player, oreId, 1)
		Net.FX(player, "Drop", { Ore = oreId, Pos = pos, Auto = ok })
		if ok then
			return
		end
		Loot.NotifyFull(player)
	end
	s.NextDropId += 1
	local id = s.NextDropId
	s.Drops[id] = { Ore = oreId, Pos = pos, Expire = os.clock() + Config.DropLifetime }
	Net.FX(player, "Drop", { Id = id, Ore = oreId, Pos = pos })
end

function Loot.NotifyFull(player: Player)
	local s = DataService.Session(player)
	if s and os.clock() - s.LastFullNotify > 3 then
		s.LastFullNotify = os.clock()
		Net.Notify(player, "Backpack full! Forge or Sell your ore in the Hub.", Color3.fromRGB(255, 120, 90), "Error")
	end
end

function Loot.Collect(player: Player, id: number)
	local s = DataService.Session(player)
	if not s or type(id) ~= "number" then
		return
	end
	local drop = s.Drops[id]
	if not drop then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - drop.Pos).Magnitude > Config.PickupRadius + 14 then
		Net.FX(player, "CollectFail", { Id = id })
		return
	end
	if Loot.AddOre(player, drop.Ore, 1) then
		s.Drops[id] = nil
		Net.FX(player, "Collected", { Id = id, Ore = drop.Ore })
	else
		Loot.NotifyFull(player)
		Net.FX(player, "CollectFail", { Id = id, Full = true })
	end
end

function Loot.CleanupDrops(player: Player)
	local s = DataService.Session(player)
	if not s then
		return
	end
	local t = os.clock()
	for id, d in pairs(s.Drops) do
		if d.Expire < t then
			s.Drops[id] = nil
		end
	end
end

---------------------------------------------------------------------
-- SELL
---------------------------------------------------------------------
function Loot.Sell(player: Player, oreId: string?): number
	local data = DataService.Get(player)
	if not data then
		return 0
	end
	local coins = 0
	for id, count in pairs(data.Backpack) do
		if oreId == nil or oreId == id then
			local ore = Config.OreById[id]
			if ore then
				coins += ore.Sell * count
			end
			data.Backpack[id] = nil
		end
	end
	if coins <= 0 then
		return 0
	end
	coins = math.floor(coins * Stats.CoinMult(player))
	data.Coins += coins
	DataService.MarkDirty(player)
	Net.FX(player, "Sell", { Coins = coins, Text = "+" .. Format.Abbrev(coins) .. " Coins" })
	return coins
end

return Loot
