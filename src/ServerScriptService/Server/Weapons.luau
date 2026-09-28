--!nonstrict
-- Weapons (ModuleScript) -> ServerScriptService/Server/Weapons
-- Weapon inventory, weighted rarity rolls (Random.new), equip + welding the
-- weapon model to the character's hands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Net = require(script.Parent:WaitForChild("Net"))

local Weapons = {}
local rng = Random.new()

local function count(t): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- Weighted rarity roll. minRarity filters out lower tiers (chests / keys);
-- luck (>= 1) shifts weight toward rarer tiers.
function Weapons.RollRarity(minRarity: string?, luck: number?): string
	local minIndex = minRarity and Config.WeaponRarityById[minRarity].Index or 1
	luck = math.max(1, luck or 1)
	local total = 0
	local weights = {}
	for _, r in ipairs(Config.WeaponRarities) do
		if r.Index >= minIndex then
			local w = r.Chance * luck ^ ((r.Index - 1) * 0.35)
			weights[r.Id] = w
			total += w
		end
	end
	local roll = rng:NextNumber() * total
	for _, r in ipairs(Config.WeaponRarities) do
		local w = weights[r.Id]
		if w then
			roll -= w
			if roll <= 0 then
				return r.Id
			end
		end
	end
	return Config.WeaponRarities[#Config.WeaponRarities].Id
end

function Weapons.Roll(minRarity: string?, luck: number?): (string, string)
	local rarity = Weapons.RollRarity(minRarity, luck)
	local pool = Config.WeaponsByRarity[rarity]
	if not pool or #pool == 0 then
		return Config.StarterWeapon, "Common"
	end
	local w = pool[rng:NextInteger(1, #pool)]
	return w.Id, rarity
end

-- Adds a weapon. If the inventory is full it is scrapped for coins.
function Weapons.Add(player: Player, weaponId: string, rarityId: string): string?
	local data = DataService.Get(player)
	if not data or not Config.WeaponById[weaponId] then
		return nil
	end
	if count(data.Weapons) >= Config.MaxWeapons then
		local scrap = Config.WeaponRarityById[rarityId].Scrap
		data.Coins += scrap
		Net.Notify(player, "Weapon inventory full - auto-scrapped for " .. scrap .. " Coins.", Color3.fromRGB(255, 170, 90), "Error")
		DataService.MarkDirty(player)
		return nil
	end
	local uid = "w" .. data.NextWeaponId
	data.NextWeaponId += 1
	data.Weapons[uid] = { W = weaponId, R = rarityId }
	DataService.MarkDirty(player)
	return uid
end

function Weapons.EnsureStarter(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if next(data.Weapons) == nil then
		data.Equipped = Weapons.Add(player, Config.StarterWeapon, "Common") or ""
	end
	if not data.Weapons[data.Equipped] then
		data.Equipped = next(data.Weapons) or ""
	end
end

-- Rebuilds the weapon on the character and publishes attributes the client
-- uses to bind abilities.
function Weapons.Refresh(player: Player)
	local data = DataService.Get(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not data or not char or not hum or hum.Health <= 0 then
		return
	end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Model") and c.Name:sub(1, 15) == "EquippedWeapon_" then
			c:Destroy()
		end
	end
	local rec = data.Weapons[data.Equipped]
	local def = rec and Config.WeaponById[rec.W] or Config.WeaponById[Config.StarterWeapon]
	local rarityId = rec and rec.R or "Common"
	local built = WeaponModels.Build(def.Id, rarityId, data.Blade)
	WeaponModels.AttachToCharacter(char, built)
	local class = Config.WeaponClasses[def.Class]
	player:SetAttribute("WeaponId", def.Id)
	player:SetAttribute("WeaponClass", def.Class)
	player:SetAttribute("WeaponRarity", rarityId)
	player:SetAttribute("WeaponSkill", def.Skill)
	player:SetAttribute("WeaponUltimate", class and class.Ultimate or "")
end

function Weapons.Equip(player: Player, uid: string)
	local data = DataService.Get(player)
	if not data or type(uid) ~= "string" or not data.Weapons[uid] then
		return
	end
	data.Equipped = uid
	Weapons.Refresh(player)
	DataService.MarkDirty(player)
	local rec = data.Weapons[uid]
	Net.FX(player, "Equipped", { Weapon = rec.W, Rarity = rec.R })
end

function Weapons.Scrap(player: Player, uid: string)
	local data = DataService.Get(player)
	if not data or type(uid) ~= "string" then
		return
	end
	local rec = data.Weapons[uid]
	if not rec then
		return
	end
	if uid == data.Equipped then
		Net.Notify(player, "Unequip that weapon before scrapping it.", Color3.fromRGB(255, 120, 90), "Error")
		return
	end
	local scrap = Config.WeaponRarityById[rec.R].Scrap
	data.Weapons[uid] = nil
	data.Coins += scrap
	Net.Notify(player, "Scrapped " .. Config.WeaponById[rec.W].Name .. " for " .. scrap .. " Coins.", Color3.fromRGB(255, 215, 70), "Sell")
	DataService.MarkDirty(player)
end

return Weapons
