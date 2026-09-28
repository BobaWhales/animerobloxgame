--!nonstrict
-- Leaderboards (ModuleScript) -> ServerScriptService/Server/Leaderboards
-- Four global boards at spawn (Config.Leaderboards), backed by
-- OrderedDataStores. Exponential stats (Power) are stored as log10 * 1000
-- so even astronomically large values fit in an integer key.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local Leaderboards = {}

local RANK_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(220, 228, 240), Color3.fromRGB(255, 160, 90) }
local names = {}

local function valueOf(key: string, data): number
	if key == "Power" then
		return data.Power
	elseif key == "Stage" then
		return data.BestFloor or 0
	elseif key == "Prestige" then
		-- ascensions dominate, then rebirths
		return data.Ascensions * 100000 + data.Rebirths
	elseif key == "Kills" then
		return data.Kills
	end
	return 0
end

local function encode(lb, v: number): number
	if lb.Log then
		return math.floor(math.log10(math.max(1, v)) * 1000)
	end
	return math.floor(v)
end

local function display(lb, stored: number): string
	if lb.Log then
		return Format.Abbrev(10 ^ (stored / 1000))
	elseif lb.Key == "Stage" then
		return "Floor " .. stored
	elseif lb.Key == "Prestige" then
		local asc = math.floor(stored / 100000)
		local reb = stored % 100000
		return (asc > 0 and (asc .. " Asc  ") or "") .. reb .. " Reb"
	end
	return Format.Abbrev(stored)
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local n = ok and result or ("User " .. userId)
	names[userId] = n
	return n
end

local function row(parent: Instance, rank: number, name: string, value: string)
	local f = Instance.new("Frame")
	f.Name = "Row" .. rank
	f.LayoutOrder = rank
	f.Size = UDim2.fromScale(1, 0.092)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = rank % 2 == 0 and 0.96 or 0.92
	f.BorderSizePixel = 0
	f.Parent = parent
	local color = RANK_COLORS[rank] or Color3.new(1, 1, 1)
	for i, spec in ipairs({ { tostring(rank), 0, 0.12, Enum.TextXAlignment.Center }, { name, 0.13, 0.52, Enum.TextXAlignment.Left }, { value, 0.66, 0.33, Enum.TextXAlignment.Right } }) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(spec[2], 0.08)
		t.Size = UDim2.fromScale(spec[3], 0.84)
		t.Font = i == 1 and Config.Fonts.Display or Config.Fonts.Body
		t.TextScaled = true
		t.TextXAlignment = spec[4]
		t.Text = spec[1]
		t.TextColor3 = i == 3 and color:Lerp(Color3.new(1, 1, 1), 0.3) or color
		t.Parent = f
	end
end

local function render(rows: Instance, lb, entries)
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if #entries == 0 then
		row(rows, 1, "No one yet - be first!", "")
		return
	end
	for rank, e in ipairs(entries) do
		row(rows, rank, e.Name, display(lb, e.Value))
	end
end

function Leaderboards.Init(map)
	local boards = map.Leaderboards or {}
	task.spawn(function()
		local stores = {}
		for _, lb in ipairs(Config.Leaderboards) do
			local ok, store = pcall(function()
				return DataStoreService:GetOrderedDataStore(lb.Store)
			end)
			stores[lb.Key] = ok and store or nil
		end
		while true do
			for _, lb in ipairs(Config.Leaderboards) do
				local store = stores[lb.Key]
				local rows = boards[lb.Key]
				if store and rows then
					for _, player in ipairs(Players:GetPlayers()) do
						local data = DataService.Get(player)
						if data then
							pcall(function()
								store:SetAsync(tostring(player.UserId), encode(lb, valueOf(lb.Key, data)))
							end)
						end
					end
					local ok, pages = pcall(function()
						return store:GetSortedAsync(false, 10)
					end)
					local entries = {}
					if ok and pages then
						for _, entry in ipairs(pages:GetCurrentPage()) do
							local userId = tonumber(entry.key)
							if userId then
								table.insert(entries, { Name = nameOf(userId), Value = entry.value })
							end
						end
					else
						-- DataStores unavailable (Studio without API access): show this server
						for _, player in ipairs(Players:GetPlayers()) do
							local data = DataService.Get(player)
							if data then
								table.insert(entries, { Name = player.DisplayName, Value = encode(lb, valueOf(lb.Key, data)) })
							end
						end
						table.sort(entries, function(a, b)
							return a.Value > b.Value
						end)
					end
					render(rows, lb, entries)
				elseif rows then
					render(rows, lb, {})
				end
			end
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return Leaderboards
