--!nonstrict
-- Forge (ModuleScript) -> ServerScriptService/Server/Forge
-- Weapon crafting (replaces the old weapon chests). Put 1-3 ores from your
-- bag into the Forge (plus an optional catalyst) to forge a weapon:
--   * ore effects are stamped onto the weapon (Config.Effects)
--   * the effects decide the weapon type (ForgeRules.ClassOdds)
--   * rarer ores / catalysts raise the rarity
--   * exact recipes (Config.Recipes) forge unique iconic weapons
-- Forging also grants Forge levels (the old "+1 Forge" progression).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local ForgeRules = require(Shared:WaitForChild("ForgeRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))
local Weapons = require(script.Parent:WaitForChild("Weapons"))

local Forge = {}
local rng = Random.new()
local RED = Color3.fromRGB(255, 110, 90)

local function pickClass(analysis): string
	local total = 0
	for _, w in pairs(analysis.ClassWeights) do
		total += w
	end
	local roll = rng:NextNumber() * total
	for cls, w in pairs(analysis.ClassWeights) do
		roll -= w
		if roll <= 0 then
			return cls
		end
	end
	return "Katana"
end

-- payload = { Ores = { oreId, oreId, oreId }, Catalyst = key? }
function Forge.Craft(player: Player, payload)
	local data = DataService.Get(player)
	if not data or type(payload) ~= "table" or type(payload.Ores) ~= "table" then
		return
	end
	-- validate ores (and that the bag really holds them)
	local ores = {}
	local need = {}
	for i = 1, math.min(#payload.Ores, Config.Forge.Slots) do
		local id = payload.Ores[i]
		if type(id) ~= "string" or not Config.OreById[id] then
			return
		end
		table.insert(ores, id)
		need[id] = (need[id] or 0) + 1
	end
	if #ores == 0 then
		Net.Notify(player, "Put at least one ore in the Forge.", RED, "Error")
		return
	end
	for id, n in pairs(need) do
		if (data.Backpack[id] or 0) < n then
			Net.Notify(player, "You don't have enough " .. Config.OreById[id].Name .. ".", RED, "Error")
			return
		end
	end
	local catalyst = payload.Catalyst
	if catalyst ~= nil then
		if type(catalyst) ~= "string" or not Config.Catalysts[catalyst] then
			return
		end
		if (data.Keys[catalyst] or 0) <= 0 then
			Net.Notify(player, "You don't have a " .. Config.Catalysts[catalyst].Name .. ".", RED, "Error")
			return
		end
	end

	local analysis = ForgeRules.Analyze(ores)
	local cost = ForgeRules.Cost(analysis, Stats.PrestigeMult(data, "Coins"))
	if data.Coins < cost then
		Net.Notify(player, "Forging this needs " .. cost .. " Coins.", RED, "Error")
		return
	end

	-- spend
	data.Coins -= cost
	for id, n in pairs(need) do
		data.Backpack[id] -= n
		if data.Backpack[id] <= 0 then
			data.Backpack[id] = nil
		end
	end
	if catalyst then
		data.Keys[catalyst] -= 1
	end

	-- rarity
	local minIndex = analysis.MinRarityIndex
	if catalyst then
		minIndex = math.max(minIndex, Config.WeaponRarityById[Config.Catalysts[catalyst].MinRarity].Index)
	end
	local luck = Stats.Luck(player) * analysis.Luck
	local rarityId = Weapons.RollRarity(Config.WeaponRarities[minIndex].Id, luck)
	local rarityIndex = Config.WeaponRarityById[rarityId].Index

	-- weapon
	local def
	local recipe = analysis.Recipe
	if recipe then
		def = Config.WeaponById[recipe.Weapon]
		local base = Config.WeaponRarityById[def.Rarity].Index
		if rarityIndex < base then
			rarityIndex = base
			rarityId = def.Rarity
		end
	else
		def = ForgeRules.PickWeapon(pickClass(analysis), rarityIndex, rng)
	end

	local uid = Weapons.Add(player, def.Id, rarityId, analysis.Effects)
	local firstTime = false
	if recipe and not data.Recipes[recipe.Key] then
		data.Recipes[recipe.Key] = true
		firstTime = true
	end

	-- the "+1 Forge" progression lives on: forging raises your Forge level
	local before = data.Blade
	local gained = math.max(1, math.floor(analysis.Blade * Stats.ForgeMult(player)))
	data.Blade += gained
	local _, tierBefore = Config.GetBladeTier(before)
	local tier, tierAfter = Config.GetBladeTier(data.Blade)
	Weapons.Refresh(player)
	DataService.MarkDirty(player)

	Net.FX(player, "ForgeResult", {
		Uid = uid,
		Weapon = def.Id,
		Rarity = rarityId,
		Effects = analysis.Effects,
		Recipe = recipe and recipe.Index or nil,
		FirstRecipe = firstTime,
		Gained = gained,
		From = before,
		To = data.Blade,
		TierUp = tierAfter > tierBefore and tierAfter or nil,
		TierName = tier.Name,
	})
	Net.FXAll("ForgeBurst", { Player = player, Color = Config.WeaponRarityById[rarityId].Color })
	if recipe and firstTime then
		Net.FXAll("Notify", { Text = player.DisplayName .. " forged the legendary " .. def.Name .. "!", Color = Config.WeaponRarityById[rarityId].Color, Sound = "RarePickup" })
	end
end

return Forge
