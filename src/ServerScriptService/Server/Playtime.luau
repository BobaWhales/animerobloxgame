--!nonstrict
-- Playtime (ModuleScript) -> ServerScriptService/Server/Playtime
-- Session time tracker (server, 1s loop), play-time reward ladder, total
-- playtime and the daily login streak (all saved in the DataStore profile).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Stats = require(script.Parent:WaitForChild("Stats"))
local Net = require(script.Parent:WaitForChild("Net"))

local Playtime = {}
Playtime.OnCosmeticsChanged = nil :: ((Player) -> ())?

local function grant(player: Player, reward)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if reward.Coins then
		data.Coins += reward.Coins
	end
	if reward.Potions then
		data.Potions += reward.Potions
	end
	if reward.Keys then
		for key, n in pairs(reward.Keys) do
			data.Keys[key] = (data.Keys[key] or 0) + n
		end
	end
	if reward.DamageBoost then
		local now = Stats.Now()
		data.BoostEnds = math.max(data.BoostEnds, now) + reward.DamageBoost
	end
	if reward.Aura == "Playtime" and not data.Cosmetics.PlaytimeAura then
		data.Cosmetics.PlaytimeAura = true
		if Playtime.OnCosmeticsChanged then
			Playtime.OnCosmeticsChanged(player)
		end
	end
	DataService.MarkDirty(player)
end
Playtime.Grant = grant

-- Called once after the profile loads.
function Playtime.OnJoin(player: Player)
	local data = DataService.Get(player)
	local s = DataService.Session(player)
	if not data or not s then
		return
	end
	s.SessionTime = 0
	s.PlaytimeClaimed = {}
	for i = 1, #Config.PlaytimeRewards do
		s.PlaytimeClaimed[i] = false
	end
	player:SetAttribute("SessionTime", 0)

	-- daily streak (UTC days)
	local today = math.floor(os.time() / 86400)
	if data.LastLoginDay ~= today then
		if data.LastLoginDay == today - 1 then
			data.Streak += 1
		else
			data.Streak = 1
		end
		data.LastLoginDay = today
		local days = math.min(data.Streak, Config.Daily.MaxScaleDays)
		local coins = Config.Daily.BaseCoins * days * (1 + data.Rebirths)
		data.Coins += coins
		local text = Format.Abbrev(coins) .. " Coins"
		if data.Streak % 7 == 0 then
			data.Keys[Config.Daily.WeeklyKey] = (data.Keys[Config.Daily.WeeklyKey] or 0) + 1
			text ..= " + " .. Config.KeyNames[Config.Daily.WeeklyKey]
		end
		DataService.MarkDirty(player)
		task.delay(6, function()
			if player.Parent then
				local bonus = math.min(data.Streak * Config.Daily.CoinBonusPerDay, Config.Daily.MaxCoinBonus)
				Net.FX(player, "Daily", { Streak = data.Streak, Text = text, Bonus = bonus })
			end
		end)
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.Get(player)
			local s = DataService.Session(player)
			if data and s and s.PlaytimeClaimed then
				s.SessionTime += 1
				data.TotalPlaytime += 1
				player:SetAttribute("SessionTime", s.SessionTime)
				for i, reward in ipairs(Config.PlaytimeRewards) do
					if not s.PlaytimeClaimed[i] and s.SessionTime >= reward.Minutes * 60 then
						s.PlaytimeClaimed[i] = true
						grant(player, reward)
						Net.FX(player, "PlaytimeReward", { Index = i, Name = reward.Name, Minutes = reward.Minutes })
					end
				end
			end
		end
	end
end)

return Playtime
