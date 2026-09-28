--!nonstrict
-- AdminUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/AdminUI
-- "Admin abuse" panel (P key or the Admin tile in the menu). Only shown to
-- admins, and every button is re-checked on the server (Server/Admin), so
-- this is just a remote control.
--   PLAYER : currencies, prestige, stage unlocks, heal / god / speed, goto / bring
--   ITEMS  : any ore, any weapon (rarity + a maxed ore effect), any armor
--   SERVER : 2x Luck / 3x Coins / 5x Power / 2x Drops events, ore + coin rain,
--            boss invasion at spawn, everyone Overdrive, kill all, announcements

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local SFX = require(Shared:WaitForChild("SFX"))

local AdminUI = {}
local UI, H
local C = UITheme.Colors
local RED = Color3.fromRGB(255, 70, 95)
local remote: RemoteEvent? = nil

local target: any = nil -- nil = me, "All", or a UserId
local amountBox: TextBox
local pick = { Ore = Config.Ores[1].Id, Weapon = Config.Weapons[1].Id, Rarity = 1, Effect = 0, Armor = Config.Armors[1].Id }

local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qd = 1e15, qn = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33 }

-- "250", "1.5m", "3qd", "1e40" -> number
local function parseAmount(): number?
	local text = (amountBox and amountBox.Text or ""):lower():gsub("%s", ""):gsub(",", "")
	if text == "" then
		return nil
	end
	local n = tonumber(text)
	if n then
		return n
	end
	local num, suf = text:match("^([%d%.]+)(%a+)$")
	if num and SUFFIX[suf] and tonumber(num) then
		return tonumber(num) * SUFFIX[suf]
	end
	return nil
end

local function fire(action: string, args)
	if not remote then
		return
	end
	args = args or {}
	args.Target = target
	if args.Amount == nil then
		args.Amount = parseAmount()
	end
	remote:FireServer(action, args)
end

local function grid(parent, cell: Vector2)
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

-- A "< value >" picker. getText(i) -> text, color.
local function cycler(parent, pos: UDim2, width: number, count: number, get: () -> number, set: (number) -> (), getText: (number) -> (string, Color3?))
	local f = H.Frame(parent, { Color = Color3.fromRGB(14, 12, 22), Size = UDim2.fromOffset(width, 34), Position = pos, Corner = 8, Stroke = 1 })
	local label = UITheme.Label(f, { Text = "", Size = UDim2.new(1, -72, 1, -6), Position = UDim2.fromOffset(36, 3), MaxText = 15 })
	local function refresh()
		local t, col = getText(get())
		label.Text = t
		label.TextColor3 = col or C.Text
	end
	for side = -1, 1, 2 do
		UITheme.Button(f, { Text = side < 0 and "<" or ">", Color = "Blue", Size = UDim2.fromOffset(30, 30), Position = side < 0 and UDim2.fromOffset(2, 2) or UDim2.new(1, -32, 0, 2), MaxText = 18, Corner = 6, OnClick = function()
			local i = get() + side
			if i < 0 then
				i = count
			elseif i > count then
				i = 0
			end
			set(i)
			refresh()
		end })
	end
	refresh()
	return refresh
end

local function build()
	local p = H.MakePanel("Admin", "ADMIN ABUSE", Vector2.new(900, 560), RED)

	-- target + amount bar
	local bar = H.Frame(p.Body, { Color = C.Row, Size = UDim2.new(1, 0, 0, 48), Corner = 8, Stroke = 1 })
	UITheme.Label(bar, { Text = "TARGET", Size = UDim2.fromOffset(70, 20), Position = UDim2.fromOffset(10, 14), Color = C.Sub, MaxText = 14, XAlign = Enum.TextXAlignment.Left })
	local chips = H.Frame(bar, { Transparency = 1, Size = UDim2.new(1, -360, 1, -12), Position = UDim2.fromOffset(78, 6) })
	local chipList = H.List(chips, 6, true, Enum.HorizontalAlignment.Left)
	chipList.VerticalAlignment = Enum.VerticalAlignment.Center
	UITheme.Label(bar, { Text = "AMOUNT", Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -270, 0, 14), Color = C.Sub, MaxText = 14 })
	amountBox = Instance.new("TextBox")
	amountBox.Size = UDim2.fromOffset(190, 34)
	amountBox.Position = UDim2.new(1, -198, 0, 7)
	amountBox.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
	amountBox.TextColor3 = Color3.new(1, 1, 1)
	amountBox.PlaceholderText = "e.g. 1000, 5m, 2qd"
	amountBox.PlaceholderColor3 = C.Sub
	amountBox.Font = UITheme.BodyFont
	amountBox.TextScaled = true
	amountBox.ClearTextOnFocus = false
	amountBox.Text = ""
	amountBox.Parent = bar
	UITheme.Corner(amountBox, 8)
	UITheme.Stroke(amountBox, 1.5, RED, true)

	local chipButtons = {}
	local function refreshChips()
		H.Clear(chips)
		table.clear(chipButtons)
		local options = { { Label = "ME", Value = nil }, { Label = "EVERYONE", Value = "All" } }
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= Players.LocalPlayer then
				table.insert(options, { Label = plr.DisplayName, Value = plr.UserId })
			end
		end
		for i, o in ipairs(options) do
			local on = target == o.Value
			local b = UITheme.Button(chips, { Text = o.Label, Color = on and "Red" or "Blue", Size = UDim2.fromOffset(math.clamp(#o.Label * 11 + 24, 60, 150), 32), Order = i, MaxText = 15, Corner = 6, OnClick = function()
				target = o.Value
				refreshChips()
			end })
			chipButtons[i] = b
		end
	end
	refreshChips()
	Players.PlayerAdded:Connect(refreshChips)
	Players.PlayerRemoving:Connect(function(plr)
		if target == plr.UserId then
			target = nil
		end
		task.defer(refreshChips)
	end)

	-- tabs
	local tabs = H.Frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 56) })
	H.List(tabs, 8, true, Enum.HorizontalAlignment.Left)
	local pages = {}
	local function page(name: string)
		local pg = H.Frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 1, -102), Position = UDim2.fromOffset(0, 102) })
		pg.Name = name
		pg.Visible = false
		pages[name] = pg
		return pg
	end
	local function show(name)
		for n, pg in pairs(pages) do
			pg.Visible = n == name
		end
	end
	for i, name in ipairs({ "PLAYER", "ITEMS", "SERVER" }) do
		UITheme.Button(tabs, { Text = name, Color = i == 1 and "Blue" or (i == 2 and "Purple" or "Red"), Size = UDim2.fromOffset(150, 36), Order = i, MaxText = 18, Corner = 8, OnClick = function()
			show(name)
		end })
	end

	-- PLAYER
	local pl = page("PLAYER")
	grid(pl, Vector2.new(170, 50))
	local playerCmds = {
		{ "+ Coins", "GiveCoins", "Gold" },
		{ "+ Power", "GivePower", "Green" },
		{ "+ Rebirths", "GiveRebirths", "Gold" },
		{ "+ Ascensions", "GiveAscensions", "Purple" },
		{ "+ Race Rerolls", "GiveRerolls", "Purple" },
		{ "+ Overdrive", "GiveOverdrive", "Red" },
		{ "+ Catalysts", "GiveCatalysts", "Blue" },
		{ "+ Every Ore", "GiveAllOres", "Blue" },
		{ "Set Deepest Floor", "SetFloor", "Green" },
		{ "Heal", "Heal", "Green" },
		{ "God Mode", "God", "Gold" },
		{ "Speed x3", "Speed", "Blue" },
		{ "Go To", "GoTo", "Blue" },
		{ "Bring", "Bring", "Purple" },
	}
	for i, c in ipairs(playerCmds) do
		UITheme.Button(pl, { Text = c[1], Color = c[3], Order = i, MaxText = 18, Corner = 8, OnClick = function()
			fire(c[2])
		end })
	end
	local armed = 0
	local reset = UITheme.Button(pl, { Text = "Reset Data", Color = "Red", Order = 99, MaxText = 18, Corner = 8, OnClick = nil })
	reset.Activated:Connect(function()
		if os.clock() - armed < 3 then
			armed = 0
			UITheme.SetButtonText(reset, "Reset Data")
			fire("ResetData")
		else
			armed = os.clock()
			UITheme.SetButtonText(reset, "CLICK AGAIN")
			SFX.Play("Error")
			task.delay(3, function()
				UITheme.SetButtonText(reset, "Reset Data")
			end)
		end
	end)

	-- ITEMS
	local it = page("ITEMS")
	local function column(x: number, w: number, title: string)
		local col = H.Frame(it, { Color = C.Row, Size = UDim2.new(0, w, 1, 0), Position = UDim2.fromOffset(x, 0), Corner = 8, Stroke = 1 })
		UITheme.Label(col, { Text = title, Title = true, Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), XAlign = Enum.TextXAlignment.Left, MaxText = 18 })
		return col
	end
	local function pickList(col, items, key: string, textOf, colorOf, height: number)
		local sc = H.Scroller(col, { Size = UDim2.new(1, -8, 0, height), Position = UDim2.fromOffset(4, 34) })
		H.List(sc, 3)
		local rows = {}
		local function paint()
			for id, r in pairs(rows) do
				local st = r:FindFirstChildOfClass("UIStroke")
				if st then
					st.Transparency = pick[key] == id and 0 or 0.8
				end
			end
		end
		for i, item in ipairs(items) do
			local r = H.Frame(sc, { Color = Color3.fromRGB(14, 12, 22), Size = UDim2.new(1, 0, 0, 24), Order = i, Corner = 5, Stroke = 1 })
			local st = r:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = colorOf(item)
			end
			UITheme.Label(r, { Text = textOf(item), Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(6, 2), XAlign = Enum.TextXAlignment.Left, Color = colorOf(item), MaxText = 14, StrokeThickness = 1 })
			local b = Instance.new("TextButton")
			b.BackgroundTransparency = 1
			b.Text = ""
			b.Size = UDim2.fromScale(1, 1)
			b.Parent = r
			b.Activated:Connect(function()
				pick[key] = item.Id
				SFX.Play("UIClick")
				paint()
			end)
			rows[item.Id] = r
		end
		paint()
	end

	-- ores
	local oc = column(0, 250, "ORES")
	pickList(oc, Config.Ores, "Ore", function(o)
		return o.Name .. "  (" .. o.Rarity .. ")"
	end, function(o)
		return o.Color
	end, 300)
	UITheme.Button(oc, { Text = "GIVE ORE", Color = "Blue", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), MaxText = 18, Corner = 8, OnClick = function()
		fire("GiveOre", { Ore = pick.Ore })
	end })

	-- weapons
	local wc = column(258, 360, "WEAPONS")
	pickList(wc, Config.Weapons, "Weapon", function(w)
		return w.Name .. "  -  " .. w.Class .. (w.Recipe and "  *" or "")
	end, function(w)
		local r = Config.WeaponRarityById[w.Rarity]
		return r and r.Color or C.Text
	end, 220)
	cycler(wc, UDim2.fromOffset(8, 262), 344, #Config.WeaponRarities - 1, function()
		return pick.Rarity - 1
	end, function(i)
		pick.Rarity = i + 1
	end, function(i)
		local r = Config.WeaponRarities[i + 1]
		return "Rarity: " .. (r.Label or r.Id), r.Color
	end)
	cycler(wc, UDim2.fromOffset(8, 302), 344, #Config.EffectOrder, function()
		return pick.Effect
	end, function(i)
		pick.Effect = i
	end, function(i)
		if i == 0 then
			return "Effect: none", C.Sub
		end
		local e = Config.Effects[Config.EffectOrder[i]]
		return "Effect: " .. e.Name .. " (maxed)", e.Color
	end)
	UITheme.Button(wc, { Text = "GIVE WEAPON", Color = "Purple", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), MaxText = 18, Corner = 8, OnClick = function()
		fire("GiveWeapon", { Weapon = pick.Weapon, Rarity = Config.WeaponRarities[pick.Rarity].Id, Effect = pick.Effect > 0 and Config.EffectOrder[pick.Effect] or nil })
	end })

	-- armor
	local ac = column(626, 246, "ARMOR")
	pickList(ac, Config.Armors, "Armor", function(a)
		return a.Name
	end, function(a)
		return a.Trim
	end, 220)
	UITheme.Label(ac, { Text = "(uses the weapon rarity picker)", Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 262), Color = C.Sub, MaxText = 13 })
	UITheme.Button(ac, { Text = "GIVE ARMOR", Color = "Blue", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), MaxText = 18, Corner = 8, OnClick = function()
		fire("GiveArmor", { Armor = pick.Armor, Rarity = Config.WeaponRarities[math.min(pick.Rarity, #Config.ArmorDefense)].Id })
	end })

	-- SERVER
	local sv = page("SERVER")
	UITheme.Label(sv, { Text = "EVENTS (amount = minutes, default 10)", Size = UDim2.new(1, 0, 0, 20), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	local evRow = H.Frame(sv, { Transparency = 1, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 24) })
	grid(evRow, Vector2.new(168, 50))
	local order = 0
	for key, e in pairs(Config.Events) do
		order += 1
		local b = UITheme.Button(evRow, { Text = e.Name, Color = "Gold", Order = order, MaxText = 18, Corner = 8, OnClick = function()
			fire("StartEvent", { Event = key })
		end })
		b.BackgroundColor3 = e.Color
	end
	UITheme.Button(evRow, { Text = "Stop Events", Color = "Red", Order = 99, MaxText = 18, Corner = 8, OnClick = function()
		fire("StopEvents")
	end })

	UITheme.Label(sv, { Text = "ADMIN ABUSE", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 90), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	local abRow = H.Frame(sv, { Transparency = 1, Size = UDim2.new(1, 0, 0, 112), Position = UDim2.fromOffset(0, 114) })
	grid(abRow, Vector2.new(168, 50))
	local abuse = {
		{ "Ore Rain", "OreRain", "Blue" },
		{ "Coin Rain", "CoinRain", "Gold" },
		{ "Boss Invasion", "BossInvasion", "Red" },
		{ "Everyone Overdrive", "EveryoneOverdrive", "Purple" },
		{ "Kill All Enemies", "KillAll", "Red" },
	}
	for i, a in ipairs(abuse) do
		UITheme.Button(abRow, { Text = a[1], Color = a[3], Order = i, MaxText = 17, Corner = 8, OnClick = function()
			fire(a[2])
		end })
	end

	UITheme.Label(sv, { Text = "ANNOUNCE", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 236), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	local msg = Instance.new("TextBox")
	msg.Size = UDim2.new(1, -190, 0, 48)
	msg.Position = UDim2.fromOffset(0, 260)
	msg.BackgroundColor3 = Color3.fromRGB(14, 12, 22)
	msg.TextColor3 = Color3.new(1, 1, 1)
	msg.PlaceholderText = "Message for the whole server (filtered)..."
	msg.PlaceholderColor3 = C.Sub
	msg.Font = UITheme.BodyFont
	msg.TextScaled = true
	msg.ClearTextOnFocus = false
	msg.Text = ""
	msg.Parent = sv
	UITheme.Corner(msg, 8)
	UITheme.Stroke(msg, 1.5, RED, true)
	UITheme.Button(sv, { Text = "ANNOUNCE", Color = "Red", Size = UDim2.fromOffset(176, 48), Position = UDim2.new(1, 0, 0, 260), AnchorPoint = Vector2.new(1, 0), MaxText = 20, Corner = 8, OnClick = function()
		if msg.Text ~= "" then
			fire("Announce", { Text = msg.Text })
			msg.Text = ""
		end
	end })

	show("PLAYER")
	p.Refresh = function(d)
		if not d.IsAdmin then
			UI.Close()
		end
	end
end

function AdminUI.Init(ui)
	UI = ui
	H = UI.Helpers
	task.spawn(function()
		remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin") :: RemoteEvent
	end)
	build()
end

return AdminUI
