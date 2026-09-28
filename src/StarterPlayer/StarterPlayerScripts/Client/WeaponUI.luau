--!nonstrict
-- WeaponUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/WeaponUI
-- Weapons inventory (3D previews), Chests + gacha reveal, 2x Power shop
-- (3^n Robux -> 2^n power) and the play-time Rewards ladder.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))
local SFX = require(Shared:WaitForChild("SFX"))
local VFX = require(Shared:WaitForChild("VFX"))

local WeaponUI = {}
local UI, H
local request: (string, any?) -> () = function() end
local C = UITheme.Colors
local player = Players.LocalPlayer

local function rarityOf(id: string)
	return Config.WeaponRarityById[id] or Config.WeaponRarities[1]
end

local function rarityLabel(r): string
	return r.Label or r.Id
end

-- Spinning 3D weapon preview in a ViewportFrame. Returns a cleanup function.
local function preview(parent: GuiObject, weaponId: string, rarityId: string, size: UDim2, pos: UDim2?)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = size
	vp.Position = pos or UDim2.new()
	vp.Ambient = Color3.fromRGB(190, 185, 210)
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-1, -1.2, -0.8)
	vp.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local built = WeaponModels.Build(weaponId, rarityId)
	built.Main.Parent = world
	if built.Off then
		built.Off:Destroy()
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local cf, sz = built.Main:GetBoundingBox()
	local center = cf.Position
	local dist = math.max(sz.X, sz.Y, sz.Z) * 1.7 + 1
	local start = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - start) * 0.9
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(a) * dist, dist * 0.25, math.sin(a) * dist), center)
	end)
	return function()
		conn:Disconnect()
		vp:Destroy()
	end
end
WeaponUI.Preview = preview

local function sortedWeapons(d)
	local list = {}
	for uid, rec in pairs(d.Weapons or {}) do
		local def = Config.WeaponById[rec.W]
		if def then
			table.insert(list, { Uid = uid, Def = def, Rarity = rarityOf(rec.R) })
		end
	end
	table.sort(list, function(a, b)
		if a.Uid == d.Equipped then
			return true
		elseif b.Uid == d.Equipped then
			return false
		end
		if a.Rarity.Index ~= b.Rarity.Index then
			return a.Rarity.Index > b.Rarity.Index
		end
		return a.Def.Name < b.Def.Name
	end)
	return list
end

---------------------------------------------------------------------
-- WEAPONS PANEL
---------------------------------------------------------------------
local function buildWeapons()
	local p = H.MakePanel("Weapons", "WEAPONS", Vector2.new(820, 500), C.Purple)
	local grid = H.Scroller(p.Body, { Size = UDim2.new(1, -300, 1, 0) })
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(150, 78)
	g.CellPadding = UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = grid
	local detail = H.Frame(p.Body, { Color = Color3.fromRGB(26, 20, 44), Size = UDim2.new(0, 288, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Corner = 14, Stroke = 2 })
	local selected = nil
	local cleanupPreview = nil
	local lastD = nil

	local function showDetail(entry)
		H.Clear(detail)
		if cleanupPreview then
			cleanupPreview()
			cleanupPreview = nil
		end
		if not entry then
			UITheme.Label(detail, { Text = "Select a weapon", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 20), Color = C.Sub, MaxText = 18 })
			return
		end
		local def, r = entry.Def, entry.Rarity
		local class = Config.WeaponClasses[def.Class]
		cleanupPreview = preview(detail, def.Id, r.Id, UDim2.new(1, -16, 0, 130), UDim2.fromOffset(8, 6))
		UITheme.Label(detail, { Text = def.Name, Title = true, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 138), Color = r.Color, MaxText = 26 })
		UITheme.Label(detail, { Text = rarityLabel(r) .. "  |  " .. def.Class, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 168), Color = C.Sub, MaxText = 15 })
		local skill = Config.Skills[def.Skill]
		local ult = Config.Skills[class.Ultimate]
		local lines = {
			string.format('<font color="#78ff9c">+%d%% Base Damage</font>%s', math.floor(r.Damage * 100 + 0.5), (r.AttackSpeed or 0) > 0 and string.format('  <font color="#8fd3ff">+%d%% Atk Speed</font>', math.floor(r.AttackSpeed * 100)) or ""),
			string.format('<font color="#ffc35a">E</font> %s   <font color="#ff6a8a">R</font> %s', skill and skill.Name or "-", ult and ult.Name or "-"),
		}
		if r.Passive and def.Passive then
			table.insert(lines, string.format('<font color="#ffd75a">Passive: %s</font> - %s', def.Passive.Name, def.Passive.Desc))
		end
		if r.Aura then
			table.insert(lines, '<font color="#ff5a6e">Celestial aura + signature skill</font>')
		elseif r.Trail then
			table.insert(lines, '<font color="#c78cff">Custom particle trail</font>')
		end
		local info = UITheme.Label(detail, { Text = table.concat(lines, "\n"), Rich = true, Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 192), XAlign = Enum.TextXAlignment.Left, MaxText = 15, StrokeThickness = 1 })
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextWrapped = true
		local equipped = lastD and lastD.Equipped == entry.Uid
		UITheme.Button(detail, { Text = equipped and "EQUIPPED" or "EQUIP", Color = equipped and "Blue" or "Green", Size = UDim2.new(0.5, -12, 0, 50), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), OnClick = function()
			request("Equip", entry.Uid)
		end })
		UITheme.Button(detail, { Text = "SCRAP " .. Format.Abbrev(r.Scrap), Color = "Red", Size = UDim2.new(0.5, -12, 0, 50), Position = UDim2.new(1, -8, 1, -8), AnchorPoint = Vector2.new(1, 1), MaxText = 18, OnClick = function()
			request("Scrap", entry.Uid)
		end })
	end

	p.Refresh = function(d)
		lastD = d
		local parts = { d.Equipped or "" }
		for uid, rec in pairs(d.Weapons or {}) do
			table.insert(parts, uid .. rec.W .. rec.R)
		end
		table.sort(parts)
		local sig = table.concat(parts, ",")
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		H.Clear(grid)
		local list = sortedWeapons(d)
		local stillThere = nil
		for i, entry in ipairs(list) do
			local r = entry.Rarity
			local card = H.Frame(grid, { Color = Color3.fromRGB(34, 28, 56), Order = i, Corner = 12, Stroke = 3 })
			local st = card:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = r.Color
			end
			UITheme.Gradient(card, Color3.new(1, 1, 1), r.Color:Lerp(Color3.new(0, 0, 0), 0.4), 90)
			UITheme.Label(card, { Text = entry.Def.Name, Title = true, Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 6), Color = r.Color, MaxText = 20 })
			UITheme.Label(card, { Text = rarityLabel(r) .. " " .. entry.Def.Class, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 34), Color = C.Text, MaxText = 13 })
			if entry.Uid == d.Equipped then
				UITheme.Label(card, { Text = "EQUIPPED", Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 55), Color = C.Green, MaxText = 13 })
			end
			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Size = UDim2.fromScale(1, 1)
			btn.Parent = card
			btn.Activated:Connect(function()
				SFX.Play("UIClick")
				selected = entry.Uid
				showDetail(entry)
			end)
			if entry.Uid == selected then
				stillThere = entry
			end
		end
		if not stillThere then
			stillThere = list[1]
			selected = stillThere and stillThere.Uid or nil
		end
		showDetail(stillThere)
	end
end

---------------------------------------------------------------------
-- CHESTS PANEL + REVEAL
---------------------------------------------------------------------
local function buildChests()
	local p = H.MakePanel("Chests", "WEAPON CHESTS", Vector2.new(700, 470), C.Gold)
	local holder = H.Scroller(p.Body, { Size = UDim2.new(1, 0, 1, -40) })
	H.List(holder, 8)
	local rows = {}
	for i, chest in ipairs(Config.Chests) do
		local r = H.Row(holder, 84, i)
		H.Frame(r, { Color = chest.Color, Size = UDim2.fromOffset(10, 64), Position = UDim2.fromOffset(10, 10), Corner = 5 })
		UITheme.Label(r, { Text = chest.Name, Title = true, Size = UDim2.new(0.55, 0, 0, 32), Position = UDim2.fromOffset(30, 8), XAlign = Enum.TextXAlignment.Left, Color = chest.Color, MaxText = 26 })
		local sub = UITheme.Label(r, { Text = "", Size = UDim2.new(0.55, 0, 0, 22), Position = UDim2.fromOffset(30, 44), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 16 })
		local btn = UITheme.Button(r, { Text = "OPEN", Color = "Gold", Size = UDim2.fromOffset(200, 60), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), MaxText = 22, Sound = "ChestOpen", OnClick = function()
			request("OpenChest", chest.Id)
		end })
		rows[chest.Id] = { Sub = sub, Button = btn }
	end
	local odds = {}
	for _, r in ipairs(Config.WeaponRarities) do
		table.insert(odds, string.format('<font color="%s">%s %s</font>', H.Hex(r.Color), r.Id, Format.Percent(r.Chance)))
	end
	UITheme.Label(p.Body, { Text = "Drop rates: " .. table.concat(odds, "  "), Rich = true, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), MaxText = 15 })
	p.Refresh = function(d)
		for _, chest in ipairs(Config.Chests) do
			local row = rows[chest.Id]
			local minR = rarityOf(chest.MinRarity)
			if chest.Key then
				local have = d.Keys and d.Keys[chest.Key] or 0
				row.Sub.Text = string.format("Guaranteed %s+  |  You have %d", rarityLabel(minR), have)
				UITheme.SetButtonText(row.Button, "USE KEY")
			else
				local cost = math.floor(chest.CoinCost * (1 + d.Rebirths))
				row.Sub.Text = "Any rarity  |  " .. Format.Abbrev(cost) .. " Coins"
				UITheme.SetButtonText(row.Button, "OPEN " .. Format.Abbrev(cost))
			end
		end
	end
end

function WeaponUI.Reveal(weaponId: string, rarityId: string, title: string?)
	local def = Config.WeaponById[weaponId]
	local r = rarityOf(rarityId)
	if not def then
		return
	end
	UI.Close()
	local fly = UI.FlyGui()
	local overlay = H.Frame(fly, { Color = Color3.new(0, 0, 0), Transparency = 1, ZIndex = 60 })
	H.Tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
	local card = H.Frame(overlay, { Color = Color3.fromRGB(26, 20, 44), Size = UDim2.fromOffset(520, 360), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 22, Stroke = 5, ZIndex = 61 })
	local sc = Instance.new("UIScale")
	local cam = workspace.CurrentCamera
	sc.Scale = math.clamp(math.min(cam.ViewportSize.X / 1400, cam.ViewportSize.Y / 820), 0.55, 1.1)
	sc.Parent = card
	UITheme.Label(card, { Text = title or "OPENING...", Title = true, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 10), Color = C.Sub, ZIndex = 62, MaxText = 26 })
	local nameLabel = UITheme.Label(card, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 56), Position = UDim2.fromOffset(10, 230), ZIndex = 62, MaxText = 48, StrokeThickness = 4 })
	local rarityText = UITheme.Label(card, { Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 290), ZIndex = 62, MaxText = 24 })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	task.spawn(function()
		local steps = 24
		for i = 1, steps do
			local rr = Config.WeaponRarities[math.random(1, 4)]
			local pool = Config.WeaponsByRarity[rr.Id]
			local w = pool[math.random(1, #pool)]
			nameLabel.Text = w.Name
			nameLabel.TextColor3 = rr.Color
			if stroke then
				stroke.Color = rr.Color
			end
			SFX.Play("ChestTick", { Pitch = 0.8 + i / steps })
			task.wait(0.03 + (i / steps) ^ 3 * 0.2)
		end
		nameLabel.Text = def.Name
		nameLabel.TextColor3 = r.Color
		rarityText.Text = rarityLabel(r) .. " " .. def.Class
		rarityText.TextColor3 = r.Color
		if stroke then
			stroke.Color = r.Color
		end
		local cleanup = preview(card, def.Id, r.Id, UDim2.new(1, -40, 0, 180), UDim2.fromOffset(20, 48))
		for _, d in ipairs(card:GetChildren()) do
			if d:IsA("ViewportFrame") then
				d.ZIndex = 62
			end
		end
		if r.Index >= 5 then
			SFX.Play("RaceRevealLegend")
			VFX.ImpactFrame(r.Color, 1.4)
			VFX.TitleCard(def.Name:upper() .. "!", rarityLabel(r) .. " weapon", r.Color, 2.2)
		elseif r.Index >= 4 then
			SFX.Play("RaceReveal")
			VFX.ImpactFrame(r.Color, 0.9)
		else
			SFX.Play("RaceReveal", { Volume = 0.7 })
			VFX.ScreenFlash(r.Color, 0.5, 0.4)
		end
		task.wait(r.Index >= 5 and 2.6 or 1.8)
		H.Tween(overlay, 0.3, { BackgroundTransparency = 1 })
		H.Tween(sc, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		cleanup()
		overlay:Destroy()
		UI.Notify("Got " .. rarityLabel(r) .. " " .. def.Name .. "! Equip it from Weapons.", r.Color)
	end)
end

---------------------------------------------------------------------
-- POWER PANEL (3^n Robux -> 2^n damage)
---------------------------------------------------------------------
local function buildPower()
	local p = H.MakePanel("Power", "2x POWER", Vector2.new(560, 430), C.Red)
	local box = H.Row(p.Body, 250, 0, Color3.fromRGB(50, 24, 34))
	local cur = UITheme.Label(box, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 12), Color = C.Gold, MaxText = 42 })
	local nxt = UITheme.Label(box, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 70), Color = Color3.fromRGB(120, 255, 170), MaxText = 34 })
	local price = UITheme.Label(box, { Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 118), MaxText = 24 })
	local note = UITheme.Label(box, { Text = "Each tier doubles ALL your damage (applied after the gameplay damage cap). Tiers cost 3, 9, 27, 81... Robux.", Size = UDim2.new(1, -20, 0, 80), Position = UDim2.fromOffset(10, 158), Color = C.Sub, MaxText = 16 })
	note.TextWrapped = true
	local buy = UITheme.Button(p.Body, { Text = "BUY", Color = "Red", Size = UDim2.fromOffset(300, 74), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), MaxText = 30, Sound = "Purchase", OnClick = function()
		request("BuyPower")
	end })
	p.Refresh = function(d)
		local n = d.PowerTier or 0
		cur.Text = "Current: x" .. Format.Abbrev(Config.PowerTierMult(n)) .. " Power"
		if Config.PowerTiers[n + 1] then
			nxt.Text = "Next: x" .. Format.Abbrev(Config.PowerTierMult(n + 1))
			price.Text = "Tier " .. (n + 1) .. " price: " .. Format.Commas(Config.PowerTierPrice(n + 1)) .. " Robux"
			UITheme.SetButtonText(buy, "BUY x2  (R$ " .. Format.Commas(Config.PowerTierPrice(n + 1)) .. ")")
		else
			nxt.Text = "MAX TIER REACHED"
			price.Text = ""
			UITheme.SetButtonText(buy, "MAXED")
		end
	end
end

---------------------------------------------------------------------
-- REWARDS PANEL (play-time ladder + streak)
---------------------------------------------------------------------
local function buildRewards()
	local p = H.MakePanel("Rewards", "PLAY-TIME REWARDS", Vector2.new(620, 470), C.Green)
	local holder = H.Frame(p.Body, { Transparency = 1, Size = UDim2.new(1, 0, 1, -70) })
	H.List(holder, 8)
	local rows = {}
	for i, reward in ipairs(Config.PlaytimeRewards) do
		local r = H.Row(holder, 56, i)
		UITheme.Label(r, { Text = reward.Minutes .. " min", Title = true, Size = UDim2.fromOffset(90, 40), Position = UDim2.fromOffset(10, 8), Color = C.Gold, MaxText = 24 })
		UITheme.Label(r, { Text = reward.Name, Size = UDim2.new(1, -250, 0, 40), Position = UDim2.fromOffset(104, 8), XAlign = Enum.TextXAlignment.Left, MaxText = 18 })
		rows[i] = UITheme.Label(r, { Text = "", Title = true, Size = UDim2.fromOffset(130, 40), Position = UDim2.new(1, -10, 0, 8), AnchorPoint = Vector2.new(1, 0), MaxText = 20 })
	end
	local foot = UITheme.Label(p.Body, { Text = "", Rich = true, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), MaxText = 16 })
	foot.TextWrapped = true
	p.Refresh = function(d)
		local session = player:GetAttribute("SessionTime") or 0
		for i, reward in ipairs(Config.PlaytimeRewards) do
			local claimed = d.PlaytimeClaimed and d.PlaytimeClaimed[i]
			if claimed then
				rows[i].Text = "CLAIMED"
				rows[i].TextColor3 = C.Green
			else
				rows[i].Text = Format.Time(reward.Minutes * 60 - session)
				rows[i].TextColor3 = C.Text
			end
		end
		foot.Text = string.format('Daily streak: <font color="#8fd3ff">%d day(s)</font> (log in every day for bigger bonuses)   Total play time: <font color="#ffd75a">%s</font>', d.Streak or 0, Format.Time(d.TotalPlaytime or 0))
	end
end

function WeaponUI.Tick()
	local panel = UI.Panel("Rewards")
	if panel and panel.Frame.Visible and UI.Data and panel.Refresh then
		panel.Refresh(UI.Data)
	end
end

function WeaponUI.Init(ui, requestFn)
	UI = ui
	H = UI.Helpers
	request = requestFn
	buildWeapons()
	buildChests()
	buildPower()
	buildRewards()
end

return WeaponUI
