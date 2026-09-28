--!nonstrict
-- ForgeRules (ModuleScript) -> ReplicatedStorage/GameShared/ForgeRules
-- Shared forge maths so the Forge panel can preview exactly what the server
-- will do. Combine 1-3 ores:
--   * every ore adds its effect points (duplicates stack) -> weapon effects
--   * each effect votes for the weapon types it likes -> weapon class odds
--   * rarer ores raise the minimum rarity and add luck
--   * an exact 3-ore combination from Config.Recipes forges a unique weapon

local Config = require(script.Parent:WaitForChild("Config"))

local ForgeRules = {}

function ForgeRules.Analyze(ores: { string })
	local effects = {}
	local classWeights = {}
	local blade, points, raritySum = 0, 0, 0
	local n = 0
	for _, id in ipairs(ores) do
		local ore = Config.OreById[id]
		if ore then
			n += 1
			effects[ore.Effect] = (effects[ore.Effect] or 0) + ore.Points
			local e = Config.Effects[ore.Effect]
			for _, cls in ipairs(e.Classes) do
				classWeights[cls] = (classWeights[cls] or 0) + ore.Points
			end
			blade += ore.Forge
			points += ore.Points
			raritySum += ore.RarityIndex
		end
	end
	if n == 0 then
		return nil
	end
	local avg = raritySum / n
	local recipe = nil
	if n == Config.Forge.Slots then
		recipe = Config.RecipeByKey[Config.RecipeKey(ores)]
	end
	return {
		Count = n,
		Effects = effects,
		ClassWeights = classWeights,
		Blade = blade,
		Points = points,
		AvgRarity = avg,
		-- three Epic ores guarantee at least Rare, three Mythic ores Legendary...
		MinRarityIndex = math.clamp(math.floor(avg) - 1, 1, #Config.WeaponRarities),
		Luck = avg ^ 1.4 * (0.6 + 0.2 * n),
		Recipe = recipe,
	}
end

-- Coin fee for a forge (scaled by the player's coin multiplier so it stays
-- meaningful as the economy grows).
function ForgeRules.Cost(analysis, coinScale: number): number
	return math.floor(analysis.Points * Config.Forge.CoinCostPerOrePoint * math.max(1, coinScale))
end

-- Class odds as a sorted list { {Class, Chance} }.
function ForgeRules.ClassOdds(analysis)
	local total = 0
	for _, w in pairs(analysis.ClassWeights) do
		total += w
	end
	local list = {}
	for cls, w in pairs(analysis.ClassWeights) do
		table.insert(list, { Class = cls, Chance = w / total })
	end
	table.sort(list, function(a, b)
		return a.Chance > b.Chance
	end)
	return list
end

-- Best generic weapon of a class at or below a rarity index.
function ForgeRules.PickWeapon(class: string, rarityIndex: number, rng: Random?)
	local pool = Config.WeaponsByClass[class]
	if not pool or #pool == 0 then
		return Config.WeaponById[Config.StarterWeapon]
	end
	local bestIndex = 0
	for _, w in ipairs(pool) do
		local ri = Config.WeaponRarityById[w.Rarity].Index
		if ri <= rarityIndex and ri > bestIndex then
			bestIndex = ri
		end
	end
	local candidates = {}
	for _, w in ipairs(pool) do
		local ri = Config.WeaponRarityById[w.Rarity].Index
		if ri == bestIndex or (bestIndex == 0 and ri == Config.WeaponRarityById[pool[1].Rarity].Index) then
			table.insert(candidates, w)
		end
	end
	if #candidates == 0 then
		return pool[1]
	end
	local r = rng or Random.new()
	return candidates[r:NextInteger(1, #candidates)]
end

return ForgeRules
