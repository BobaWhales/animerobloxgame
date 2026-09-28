--!nonstrict
-- ForgeUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/ForgeUI
-- The Soul Forge panel (weapon crafting). Pick 1-3 ores from your bag and an
-- optional catalyst; the preview (GameShared/ForgeRules, same maths as the
-- server) shows the effects the weapon will carry, the weapon-type odds, the
-- minimum rarity, the coin fee and whether you hit a unique recipe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("GameShared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local UITheme = require(Shared:WaitForChild("UITheme"))
local ForgeRules = require(Shared:WaitForChild("ForgeRules"))
local SFX = require(Shared:WaitForChild("SFX"))

local ForgeUI = {}
local UI, H
local request: (string, any?) -> () = function() end
local C = UITheme.Colors
local FORGE = Color3.fromRGB(255, 140, 60)

local slots: { string } = {}
local catalyst: string? = nil
local showBook = false
local panel = nil

local function used(oreId: string): number
	local n = 0
	for _, id in ipairs(slots) do
		if id == oreId then
			n += 1
		end
	end
	return n
end

local function coinScale(d): number
	return Config.Rebirth.CoinMult ^ (d.Rebirths or 0) * Config.Ascension.CoinMult ^ (d.Ascensions or 0)
end

function ForgeUI.Clear()
	table.clear(slots)
	catalyst = nil
	if panel then
		panel.Sig = nil
		if UI.Data and panel.Frame.Visible then
			panel.Refresh(UI.Data)
		end
	end
end

local function build()
	local p = H.MakePanel("Forge", "SOUL FORGE", Vector2.new(860, 540), FORGE)
	panel = p

	-- left: ore bag picker
	local left = H.Frame(p.Body, { Transparency = 1, Size = UDim2.new(0, 300, 1, 0) })
	UITheme.Label(left, { Text = "YOUR ORE  (click to add)", Size = UDim2.new(1, 0, 0, 20), Color = C.Sub, MaxText = 15, XAlign = Enum.TextXAlignment.Left })
	local oreGrid = H.Scroller(left, { Size = UDim2.new(1, 0, 1, -26), Position = UDim2.fromOffset(0, 26) })
	local og = Instance.new("UIGridLayout")
	og.CellSize = UDim2.fromOffset(88, 88)
	og.CellPadding = UDim2.fromOffset(6, 6)
	og.SortOrder = Enum.SortOrder.LayoutOrder
	og.Parent = oreGrid

	-- centre: slots + catalysts + forge button
	local mid = H.Frame(p.Body, { Transparency = 1, Size = UDim2.new(0, 250, 1, 0), Position = UDim2.fromOffset(312, 0) })
	UITheme.Label(mid, { Text = "CRUCIBLE", Size = UDim2.new(1, 0, 0, 20), Color = C.Sub, MaxText = 15 })
	local slotRow = H.Frame(mid, { Transparency = 1, Size = UDim2.new(1, 0, 0, 84), Position = UDim2.fromOffset(0, 26) })
	H.List(slotRow, 8, true)
	local slotFrames = {}
	for i = 1, Config.Forge.Slots do
		local sf = H.Frame(slotRow, { Color = Color3.fromRGB(14, 12, 22), Size = UDim2.fromOffset(76, 76), Order = i, Corner = 10 })
		local st = UITheme.Stroke(sf, 2, FORGE, true)
		st.Transparency = 0.5
		local gem = H.Frame(sf, { Name = "Gem", Color = C.Line, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2 })
		gem.Rotation = 45
		local lbl = UITheme.Label(sf, { Text = "empty", Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 1, -20), Color = C.Sub, MaxText = 12, StrokeThickness = 1 })
		lbl.Name = "Label"
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.Parent = sf
		btn.Activated:Connect(function()
			if slots[i] then
				table.remove(slots, i)
				SFX.Play("UIClose")
				p.Sig = nil
				p.Refresh(UI.Data)
			end
		end)
		slotFrames[i] = { Frame = sf, Gem = gem, Label = lbl, Stroke = st }
	end

	UITheme.Label(mid, { Text = "CATALYST  (optional)", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 118), Color = C.Sub, MaxText = 14 })
	local catRow = H.Frame(mid, { Transparency = 1, Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 140) })
	H.List(catRow, 6)
	local catButtons = {}
	for i, key in ipairs(Config.CatalystOrder) do
		local cat = Config.Catalysts[key]
		local b = H.Frame(catRow, { Color = C.Row, Size = UDim2.new(1, 0, 0, 34), Order = i, Corner = 8 })
		local st = UITheme.Stroke(b, 1.5, cat.Color, true)
		st.Transparency = 0.6
		H.Accent(b, cat.Color)
		local lbl = UITheme.Label(b, { Text = cat.Name, Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(16, 4), XAlign = Enum.TextXAlignment.Left, Color = cat.Color, MaxText = 15 })
		lbl.Name = "Label"
		local click = Instance.new("TextButton")
		click.BackgroundTransparency = 1
		click.Text = ""
		click.Size = UDim2.fromScale(1, 1)
		click.Parent = b
		click.Activated:Connect(function()
			local d = UI.Data
			if not d then
				return
			end
			if catalyst == key then
				catalyst = nil
			elseif (d.Keys[key] or 0) > 0 then
				catalyst = key
			else
				UI.Notify("You have no " .. cat.Name .. ". Earn them from play-time rewards, bosses and the Boss Rush.", C.Red)
				return
			end
			SFX.Play("UIClick")
			p.Sig = nil
			p.Refresh(d)
		end)
		catButtons[key] = { Frame = b, Stroke = st, Label = lbl }
	end

	UITheme.Button(mid, { Text = "FORGE", Color = "Red", Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 1, -44), AnchorPoint = Vector2.new(0, 1), MaxText = 32, Sound = "Forge", OnClick = function()
		if #slots == 0 then
			UI.Notify("Add at least one ore to the crucible.", C.Red)
			return
		end
		request("Forge", { Ores = table.clone(slots), Catalyst = catalyst })
	end })
	local costLabel = UITheme.Label(mid, { Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -18), Color = C.Gold, MaxText = 16 })

	-- right: preview / recipe book
	local right = H.Frame(p.Body, { Color = C.Row, Size = UDim2.new(1, -574, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Corner = 10, Stroke = 1 })
	local tabs = H.Frame(right, { Transparency = 1, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 8) })
	H.List(tabs, 6, true)
	local previewPage = H.Frame(right, { Transparency = 1, Size = UDim2.new(1, -16, 1, -54), Position = UDim2.fromOffset(8, 48) })
	local bookPage = H.Scroller(right, { Size = UDim2.new(1, -8, 1, -54), Position = UDim2.fromOffset(4, 48) })
	H.List(bookPage, 6)
	UITheme.Button(tabs, { Text = "PREVIEW", Color = "Blue", Size = UDim2.new(0.5, -3, 1, 0), Order = 1, MaxText = 16, OnClick = function()
		showBook = false
		p.Sig = nil
		p.Refresh(UI.Data)
	end })
	UITheme.Button(tabs, { Text = "RECIPES", Color = "Purple", Size = UDim2.new(0.5, -3, 1, 0), Order = 2, MaxText = 16, OnClick = function()
		showBook = true
		p.Sig = nil
		p.Refresh(UI.Data)
	end })
	local previewText = UITheme.Label(previewPage, { Text = "", Rich = true, Size = UDim2.fromScale(1, 1), XAlign = Enum.TextXAlignment.Left, MaxText = 16, StrokeThickness = 1 })
	previewText.TextWrapped = true
	previewText.TextYAlignment = Enum.TextYAlignment.Top

	local function oreCell(parent, ore, count: number, order: number)
		local cell = H.Frame(parent, { Color = C.Row, Order = order, Corner = 10 })
		local rarity = Config.Rarity[ore.Rarity]
		local st = UITheme.Stroke(cell, 1.5, rarity.Color, true)
		st.Transparency = 0.35
		local gem = H.Frame(cell, { Color = ore.Color, Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0.5, 0, 0, 24), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = 2 })
		gem.Rotation = 45
		UITheme.Label(cell, { Text = ore.Name, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 44), Color = ore.Color, MaxText = 12, StrokeThickness = 1 })
		local eff = Config.Effects[ore.Effect]
		UITheme.Label(cell, { Text = (eff and eff.Name or "") .. "  x" .. count, Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 62), Color = C.Sub, MaxText = 11, StrokeThickness = 1 })
		local click = Instance.new("TextButton")
		click.BackgroundTransparency = 1
		click.Text = ""
		click.Size = UDim2.fromScale(1, 1)
		click.Parent = cell
		click.Activated:Connect(function()
			if #slots >= Config.Forge.Slots then
				UI.Notify("The crucible holds " .. Config.Forge.Slots .. " ores. Click a slot to remove one.", C.Red)
				return
			end
			local d = UI.Data
			if d and used(ore.Id) < (d.Backpack[ore.Id] or 0) then
				table.insert(slots, ore.Id)
				SFX.Play("UIClick")
				p.Sig = nil
				p.Refresh(d)
			end
		end)
	end

	local function previewRich(d): string
		if #slots == 0 then
			return '<font color="#b0aacd">Drop ores in the crucible.\n\n- Each ore stamps its effect on the weapon (duplicates stack).\n- Effects decide the weapon type.\n- Rarer ores raise the rarity.\n- Exact 3-ore recipes forge unique weapons.</font>'
		end
		local a = ForgeRules.Analyze(slots)
		if not a then
			return ""
		end
		local lines = {}
		if a.Recipe then
			local w = Config.WeaponById[a.Recipe.Weapon]
			table.insert(lines, string.format('<font color="#ff64b9"><b>UNIQUE RECIPE: %s</b></font>', w and w.Name or a.Recipe.Weapon))
		else
			local odds = ForgeRules.ClassOdds(a)
			local parts = {}
			for k, o in ipairs(odds) do
				if k > 4 then
					break
				end
				table.insert(parts, string.format("%s %d%%", o.Class, math.floor(o.Chance * 100 + 0.5)))
			end
			table.insert(lines, '<font color="#8fd3ff">Type:</font> ' .. table.concat(parts, ", "))
		end
		local minIndex = a.MinRarityIndex
		if catalyst then
			minIndex = math.max(minIndex, Config.WeaponRarityById[Config.Catalysts[catalyst].MinRarity].Index)
		end
		local minR = Config.WeaponRarities[minIndex]
		table.insert(lines, string.format('<font color="#%s">Rarity: %s or better</font>  (luck x%s)', minR.Color:ToHex(), minR.Label or minR.Id, string.format("%.1f", a.Luck)))
		table.insert(lines, "")
		table.insert(lines, '<font color="#ffc35a">EFFECTS</font>')
		for _, id in ipairs(Config.EffectOrder) do
			local pts = a.Effects[id]
			if pts then
				table.insert(lines, string.format('<font color="#%s">%s</font>', Config.Effects[id].Color:ToHex(), Config.EffectText(id, pts)))
			end
		end
		table.insert(lines, "")
		table.insert(lines, string.format('<font color="#ffaa5a">+%s Forge levels</font>', Format.Abbrev(math.max(1, math.floor(a.Blade * (d.Derived.ForgeMult or 1))))))
		return table.concat(lines, "\n")
	end

	p.Refresh = function(d)
		if not d then
			return
		end
		-- drop slots the bag no longer covers
		for i = #slots, 1, -1 do
			local id = slots[i]
			if used(id) > (d.Backpack[id] or 0) then
				table.remove(slots, i)
			end
		end
		if catalyst and (d.Keys[catalyst] or 0) <= 0 then
			catalyst = nil
		end
		local sigParts = { table.concat(slots, "+"), catalyst or "", showBook and "B" or "P", d.Coins >= 0 and math.floor(math.log10(d.Coins + 1) * 10) or 0 }
		for _, ore in ipairs(Config.Ores) do
			table.insert(sigParts, d.Backpack[ore.Id] or 0)
		end
		for _, key in ipairs(Config.CatalystOrder) do
			table.insert(sigParts, d.Keys[key] or 0)
		end
		for key in pairs(d.Recipes or {}) do
			table.insert(sigParts, key)
		end
		local sig = table.concat(sigParts, ",")
		if p.Sig == sig then
			return
		end
		p.Sig = sig

		-- ore grid
		H.Clear(oreGrid)
		local any = false
		for i, ore in ipairs(Config.Ores) do
			local left = (d.Backpack[ore.Id] or 0) - used(ore.Id)
			if left > 0 then
				any = true
				oreCell(oreGrid, ore, left, i)
			end
		end
		if not any then
			local t = UITheme.Label(oreGrid, { Text = "No ore left. Clear Path stages to find more!", Size = UDim2.fromOffset(280, 60), Color = C.Sub, MaxText = 15 })
			t.TextWrapped = true
		end

		-- slots
		for i, sf in ipairs(slotFrames) do
			local ore = slots[i] and Config.OreById[slots[i]]
			sf.Gem.BackgroundColor3 = ore and ore.Color or C.Line
			sf.Label.Text = ore and ore.Name or "empty"
			sf.Label.TextColor3 = ore and ore.Color or C.Sub
			sf.Stroke.Transparency = ore and 0.05 or 0.5
		end

		-- catalysts
		for key, cb in pairs(catButtons) do
			local have = d.Keys[key] or 0
			cb.Label.Text = Config.Catalysts[key].Name .. "  x" .. have .. (catalyst == key and "  (ON)" or "")
			cb.Stroke.Transparency = catalyst == key and 0 or 0.6
			cb.Frame.BackgroundTransparency = have > 0 and 0 or 0.5
		end

		-- cost
		local a = #slots > 0 and ForgeRules.Analyze(slots) or nil
		if a then
			local cost = ForgeRules.Cost(a, coinScale(d))
			costLabel.Text = "Fee: " .. Format.Abbrev(cost) .. " Coins"
			costLabel.TextColor3 = d.Coins >= cost and C.Gold or C.Red
		else
			costLabel.Text = ""
		end

		-- right side
		previewPage.Visible = not showBook
		bookPage.Visible = showBook
		if showBook then
			H.Clear(bookPage)
			for i, r in ipairs(Config.Recipes) do
				local known = d.Recipes and d.Recipes[r.Key]
				local w = Config.WeaponById[r.Weapon]
				local rarity = w and Config.WeaponRarityById[w.Rarity]
				local row = H.Row(bookPage, 52, i)
				H.Accent(row, rarity and rarity.Color or C.Line)
				UITheme.Label(row, { Text = known and (w and w.Name or r.Weapon) or "???", Title = true, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(16, 4), XAlign = Enum.TextXAlignment.Left, Color = known and (rarity and rarity.Color or C.Text) or C.Sub, MaxText = 17 })
				local sub
				if known then
					local names = {}
					for _, id in ipairs(r.Ores) do
						table.insert(names, Config.OreById[id] and Config.OreById[id].Name or id)
					end
					sub = table.concat(names, " + ")
				else
					sub = "Hint: " .. r.Hint
				end
				UITheme.Label(row, { Text = sub, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(16, 28), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 13 })
			end
		else
			previewText.Text = previewRich(d)
		end
	end
end

function ForgeUI.Init(ui, requestFn)
	UI = ui
	H = UI.Helpers
	request = requestFn
	build()
end

return ForgeUI
