--!nonstrict
-- WeaponUI (ModuleScript) -> StarterPlayer/StarterPlayerScripts/Client/WeaponUI
-- Weapons inventory (3D previews + forged ore effects), Armor inventory,
-- the forge reveal, 2x Power shop (3^n Robux -> 2^n power) and the
-- play-time Rewards ladder.

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

-- Ore effects on a weapon, strongest first: { {Id, Points, Def} }
local function effectList(effects)
	local out = {}
	for id, pts in pairs(effects or {}) do
		local def = Config.Effects[id]
		if def then
			table.insert(out, { Id = id, Points = pts, Def = def })
		end
	end
	table.sort(out, function(a, b)
		if a.Points ~= b.Points then
			return a.Points > b.Points
		end
		return a.Id < b.Id
	end)
	return out
end
WeaponUI.EffectList = effectList

local function effectRich(effects): string
	local lines = {}
	for _, e in ipairs(effectList(effects)) do
		table.insert(lines, string.format('<font color="#%s">%s</font>', e.Def.Color:ToHex(), Config.EffectText(e.Id, e.Points)))
	end
	return table.concat(lines, "\n")
end
WeaponUI.EffectRich = effectRich

local function sortedWeapons(d)
	local list = {}
	for uid, rec in pairs(d.Weapons or {}) do
		local def = Config.WeaponById[rec.W]
		if def then
			table.insert(list, { Uid = uid, Def = def, Rarity = rarityOf(rec.R), Effects = rec.E })
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
		if def.Recipe then
			table.insert(lines, 1, '<font color="#ff64b9">Unique recipe weapon</font>')
		end
		local fx = effectRich(entry.Effects)
		if fx ~= "" then
			table.insert(lines, fx)
		else
			table.insert(lines, '<font color="#8a86a0">No ore effects (forge one at the Soul Forge!)</font>')
		end
		local info = UITheme.Label(detail, { Text = table.concat(lines, "\n"), Rich = true, Size = UDim2.new(1, -16, 0, 176), Position = UDim2.fromOffset(8, 192), XAlign = Enum.TextXAlignment.Left, MaxText = 15, StrokeThickness = 1 })
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
			local e = {}
			for id, pts in pairs(rec.E or {}) do
				table.insert(e, id .. pts)
			end
			table.sort(e)
			table.insert(parts, uid .. rec.W .. rec.R .. table.concat(e))
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
				UITheme.Label(card, { Text = "EQUIPPED", Size = UDim2.new(0.6, 0, 0, 16), Position = UDim2.fromOffset(5, 55), XAlign = Enum.TextXAlignment.Left, Color = C.Green, MaxText = 13 })
			end
			-- one dot per ore effect
			for k, e in ipairs(effectList(entry.Effects)) do
				if k > 4 then
					break
				end
				local dot = H.Frame(card, { Color = e.Def.Color, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -10 - (k - 1) * 13, 1, -10), AnchorPoint = Vector2.new(1, 1), Corner = 5 })
				dot.Name = "Effect"
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
-- ARMOR PANEL (rare drops: defense + one bonus stat)
---------------------------------------------------------------------
local function buildArmor()
	local p = H.MakePanel("Armor", "ARMOR", Vector2.new(760, 480), C.Cyan)
	local listFrame = H.Scroller(p.Body, { Size = UDim2.new(1, -290, 1, -30) })
	H.List(listFrame, 6)
	local detail = H.Frame(p.Body, { Color = C.Row, Size = UDim2.new(0, 280, 1, -30), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Corner = 10, Stroke = 1 })
	local foot = UITheme.Label(p.Body, { Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1), Color = C.Sub, MaxText = 15 })
	local selected = nil
	local lastD = nil

	local function armorEntries(d)
		local out = {}
		for uid, rec in pairs(d.Armors or {}) do
			local def = Config.ArmorById[rec.A]
			if def then
				table.insert(out, { Uid = uid, Def = def, Rarity = rarityOf(rec.R) })
			end
		end
		table.sort(out, function(a, b)
			if a.Uid == d.EquippedArmor then
				return true
			elseif b.Uid == d.EquippedArmor then
				return false
			end
			if a.Rarity.Index ~= b.Rarity.Index then
				return a.Rarity.Index > b.Rarity.Index
			end
			return a.Def.Name < b.Def.Name
		end)
		return out
	end

	local function showDetail(entry)
		H.Clear(detail)
		if not entry then
			local t = UITheme.Label(detail, { Text = "No armor yet.\n\nArmor is a rare drop from Path enemies, elites, bosses and the Boss Rush.", Size = UDim2.new(1, -20, 0, 160), Position = UDim2.fromOffset(10, 20), Color = C.Sub, MaxText = 17 })
			t.TextWrapped = true
			return
		end
		local def, r = entry.Def, entry.Rarity
		local swatch = H.Frame(detail, { Color = def.Color, Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), Corner = 12, Stroke = 3 })
		local st = swatch:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = r.Color
		end
		local trim = H.Frame(swatch, { Color = def.Trim, Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 3 })
		trim.Name = "Trim"
		UITheme.Label(detail, { Text = def.Name, Title = true, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 106), Color = r.Color, MaxText = 24 })
		UITheme.Label(detail, { Text = rarityLabel(r) .. " armor", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 136), Color = C.Sub, MaxText = 15 })
		local defense = Config.ArmorDefense[math.min(r.Index, #Config.ArmorDefense)] or 0
		local info = UITheme.Label(detail, {
			Text = string.format('<font color="#8fd3ff">-%d%% damage taken</font>\n<font color="#78ff9c">%s</font>', math.floor(defense * 100 + 0.5), Config.ArmorBonusText(def.Bonus, r.Index)),
			Rich = true,
			Size = UDim2.new(1, -16, 0, 70),
			Position = UDim2.fromOffset(8, 164),
			MaxText = 17,
		})
		info.TextWrapped = true
		local equipped = lastD and lastD.EquippedArmor == entry.Uid
		UITheme.Button(detail, { Text = equipped and "UNEQUIP" or "EQUIP", Color = equipped and "Blue" or "Green", Size = UDim2.new(0.5, -12, 0, 50), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), OnClick = function()
			request("EquipArmor", entry.Uid)
		end })
		UITheme.Button(detail, { Text = "SCRAP " .. Format.Abbrev(r.Scrap), Color = "Red", Size = UDim2.new(0.5, -12, 0, 50), Position = UDim2.new(1, -8, 1, -8), AnchorPoint = Vector2.new(1, 1), MaxText = 18, OnClick = function()
			request("ScrapArmor", entry.Uid)
		end })
	end

	p.Refresh = function(d)
		lastD = d
		local parts = { d.EquippedArmor or "" }
		for uid, rec in pairs(d.Armors or {}) do
			table.insert(parts, uid .. rec.A .. rec.R)
		end
		table.sort(parts)
		local sig = table.concat(parts, ",")
		if p.Sig == sig then
			return
		end
		p.Sig = sig
		H.Clear(listFrame)
		local entries = armorEntries(d)
		local keep = nil
		for i, entry in ipairs(entries) do
			local r = entry.Rarity
			local row = H.Row(listFrame, 58, i)
			H.Accent(row, r.Color)
			local sw = H.Frame(row, { Color = entry.Def.Color, Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(20, 12), Corner = 6, Stroke = 2 })
			sw.Name = "Swatch"
			UITheme.Label(row, { Text = entry.Def.Name, Title = true, Size = UDim2.new(1, -150, 0, 24), Position = UDim2.fromOffset(64, 6), XAlign = Enum.TextXAlignment.Left, Color = r.Color, MaxText = 19 })
			UITheme.Label(row, { Text = rarityLabel(r) .. "  -  " .. Config.ArmorBonusText(entry.Def.Bonus, r.Index), Size = UDim2.new(1, -150, 0, 18), Position = UDim2.fromOffset(64, 32), XAlign = Enum.TextXAlignment.Left, Color = C.Sub, MaxText = 14 })
			if entry.Uid == d.EquippedArmor then
				UITheme.Label(row, { Text = "WORN", Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Green, MaxText = 16 })
			end
			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Size = UDim2.fromScale(1, 1)
			btn.Parent = row
			btn.Activated:Connect(function()
				SFX.Play("UIClick")
				selected = entry.Uid
				showDetail(entry)
			end)
			if entry.Uid == selected then
				keep = entry
			end
		end
		if not keep then
			keep = entries[1]
			selected = keep and keep.Uid or nil
		end
		showDetail(keep)
		foot.Text = string.format("%d / %d armor pieces  -  total defense caps at %d%%", #entries, Config.MaxArmors, math.floor(Config.Balance.DefenseCap * 100))
	end
end

function WeaponUI.Reveal(weaponId: string, rarityId: string, title: string?, effects: { [string]: number }?)
	local def = Config.WeaponById[weaponId]
	local r = rarityOf(rarityId)
	if not def then
		return
	end
	UI.Close()
	local fly = UI.FlyGui()
	local overlay = H.Frame(fly, { Color = Color3.new(0, 0, 0), Transparency = 1, ZIndex = 60 })
	H.Tween(overlay, 0.3, { BackgroundTransparency = 0.35 })
	local card = H.Frame(overlay, { Color = C.Bg, Size = UDim2.fromOffset(540, 440), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Corner = 22, Stroke = 5, ZIndex = 61 })
	local sc = Instance.new("UIScale")
	local cam = workspace.CurrentCamera
	sc.Scale = math.clamp(math.min(cam.ViewportSize.X / 1400, cam.ViewportSize.Y / 820), 0.55, 1.1)
	sc.Parent = card
	UITheme.Label(card, { Text = title or "OPENING...", Title = true, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 10), Color = C.Sub, ZIndex = 62, MaxText = 26 })
	local nameLabel = UITheme.Label(card, { Text = "", Title = true, Size = UDim2.new(1, -20, 0, 56), Position = UDim2.fromOffset(10, 230), ZIndex = 62, MaxText = 48, StrokeThickness = 4 })
	local rarityText = UITheme.Label(card, { Text = "", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 290), ZIndex = 62, MaxText = 24 })
	local fxLabel = UITheme.Label(card, { Text = "", Rich = true, Size = UDim2.new(1, -40, 0, 96), Position = UDim2.fromOffset(20, 326), ZIndex = 62, MaxText = 17, StrokeThickness = 1 })
	fxLabel.TextWrapped = true
	fxLabel.TextYAlignment = Enum.TextYAlignment.Top
	local stroke = card:FindFirstChildOfClass("UIStroke")
	task.spawn(function()
		local steps = 24
		for i = 1, steps do
			local rr = Config.WeaponRarities[math.random(1, 4)]
			local pool = Config.WeaponsByRarity[rr.Id]
			local w = pool and #pool > 0 and pool[math.random(1, #pool)] or def
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
		rarityText.Text = rarityLabel(r) .. " " .. def.Class .. (def.Recipe and "  -  UNIQUE" or "")
		rarityText.TextColor3 = r.Color
		fxLabel.Text = effectRich(effects)
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
		UI.Notify("Forged " .. rarityLabel(r) .. " " .. def.Name .. "! Equip it from Weapons.", r.Color)
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
	buildArmor()
	buildPower()
	buildRewards()
end

return WeaponUI
