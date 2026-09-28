--!nonstrict
-- Monetization (ModuleScript) -> ServerScriptService/Server/Monetization
-- Gamepasses, developer products (ProcessReceipt) and code rewards.
-- Put your real IDs in Config.GamePasses / Config.Products.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Net = require(script.Parent:WaitForChild("Net"))

local Monetization = {}
Monetization.OnPassesChanged = nil :: ((Player) -> ())?

local passKeyById = {}
for key, pass in pairs(Config.GamePasses) do
	if pass.Id and pass.Id ~= 0 then
		passKeyById[pass.Id] = key
	end
end
-- 2x power tiers: product id -> tier number n (price 3^n, multiplier 2^n)
local powerTierById = {}
for n, tier in ipairs(Config.PowerTiers) do
	if tier.Id and tier.Id ~= 0 then
		powerTierById[tier.Id] = n
	end
end

local productKeyById = {}
for key, prod in pairs(Config.Products) do
	if prod.Id and prod.Id ~= 0 then
		productKeyById[prod.Id] = key
	end
end

function Monetization.LoadPasses(player: Player)
	local s = DataService.Session(player)
	if not s then
		return
	end
	for key, pass in pairs(Config.GamePasses) do
		if Config.StudioOwnsAllPasses and RunService:IsStudio() then
			s.Passes[key] = true
		elseif pass.Id and pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				s.Passes[key] = true
			end
		end
	end
end

-- Coins / Rerolls / Overdrive grant used by products and codes.
function Monetization.Grant(player: Player, grants): string
	local data = DataService.Get(player)
	if not data then
		return ""
	end
	local parts = {}
	if grants.Coins then
		local amount = grants.Coins
		if grants.ScaleWithRebirth then
			amount *= 1 + data.Rebirths
		end
		data.Coins += amount
		table.insert(parts, Format.Abbrev(amount) .. " Coins")
	end
	if grants.Rerolls then
		data.Rerolls += grants.Rerolls
		table.insert(parts, grants.Rerolls .. " Rerolls")
	end
	if grants.Overdrive then
		data.Overdrive += grants.Overdrive
		table.insert(parts, grants.Overdrive .. " Overdrive")
	end
	DataService.MarkDirty(player)
	return table.concat(parts, " + ")
end

function Monetization.PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass then
		return
	end
	if not pass.Id or pass.Id == 0 then
		Net.Notify(player, pass.Name .. " isn't set up yet (add its ID in Config).", Color3.fromRGB(255, 170, 90), "Error")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
end

function Monetization.PromptProduct(player: Player, key: string)
	local prod = Config.Products[key]
	local data = DataService.Get(player)
	if not prod or not data then
		return
	end
	if prod.OneTime and data.StarterPack then
		Net.Notify(player, "You already bought the Starter Pack!", Color3.fromRGB(255, 170, 90), "Error")
		return
	end
	if not prod.Id or prod.Id == 0 then
		Net.Notify(player, prod.Name .. " isn't set up yet (add its ID in Config).", Color3.fromRGB(255, 170, 90), "Error")
		return
	end
	MarketplaceService:PromptProductPurchase(player, prod.Id)
end

-- Prompts the NEXT power tier only (n = PowerTier + 1).
function Monetization.PromptPowerTier(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local n = data.PowerTier + 1
	local tier = Config.PowerTiers[n]
	if not tier then
		Net.Notify(player, "You own every Power tier!", Color3.fromRGB(255, 215, 80), "Error")
		return
	end
	if not tier.Id or tier.Id == 0 then
		Net.Notify(player, "Power tier " .. n .. " isn't set up yet (add its product ID in Config.PowerTiers).", Color3.fromRGB(255, 170, 90), "Error")
		return
	end
	MarketplaceService:PromptProductPurchase(player, tier.Id)
end

local function grantPowerTier(player: Player, data, n: number): string
	local expected = data.PowerTier + 1
	if n >= expected then
		-- normal case (n == expected). If a higher tier was bought (paid more),
		-- jump straight to it so no Robux is ever wasted.
		data.PowerTier = n
		Net.FX(player, "PowerTier", { Tier = n, Mult = Config.PowerTierMult(n) })
		return "Power x" .. Format.Abbrev(Config.PowerTierMult(n))
	end
	-- stale purchase of a tier the player already owns: compensate with coins
	local coins = 1000 * Config.PowerTierPrice(n) * (1 + data.Rebirths)
	data.Coins += coins
	Net.Notify(player, "You already had Power tier " .. n .. " - converted to " .. Format.Abbrev(coins) .. " Coins.", Color3.fromRGB(255, 215, 80), "Purchase")
	return Format.Abbrev(coins) .. " Coins"
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local key = passKeyById[passId]
	local s = DataService.Session(player)
	if key and s then
		s.Passes[key] = true
		Net.FX(player, "Purchase", { Name = Config.GamePasses[key].Name })
		DataService.MarkDirty(player)
		if Monetization.OnPassesChanged then
			Monetization.OnPassesChanged(player)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- dedupe (receipts can be delivered more than once)
	for _, id in ipairs(data.Receipts) do
		if id == receipt.PurchaseId then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	-- 2x power tier purchase
	local tierN = powerTierById[receipt.ProductId]
	if tierN then
		local text = grantPowerTier(player, data, tierN)
		table.insert(data.Receipts, receipt.PurchaseId)
		while #data.Receipts > 50 do
			table.remove(data.Receipts, 1)
		end
		DataService.MarkDirty(player)
		DataService.Save(player)
		Net.FX(player, "Purchase", { Name = "Power Tier " .. tierN, Text = text })
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local key = productKeyById[receipt.ProductId]
	local prod = key and Config.Products[key]
	if not prod then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local text = Monetization.Grant(player, prod)
	if prod.OneTime then
		data.StarterPack = true
	end
	table.insert(data.Receipts, receipt.PurchaseId)
	while #data.Receipts > 50 do
		table.remove(data.Receipts, 1)
	end
	DataService.Save(player)
	Net.FX(player, "Purchase", { Name = prod.Name, Text = text })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Monetization
