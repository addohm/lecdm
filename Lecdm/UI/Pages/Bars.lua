-- Lecdm: the Icon bars tab. A dropdown picks the icon bar (its last entry makes a new one, in a
-- popup); everything below is about the bar picked: its name and look, deleting it, and its
-- spells (a checklist of Blizzard's list and the spellbook, order, when each shows). Creating
-- and renaming are kept apart on purpose: the owner found two look-alike controls side by side
-- confusing. The spell rows are rebuilt on each refresh (UI.Stack Reset/Add/Done), so an open
-- checklist stays open while you tick.
local _, ns = ...
local UI = ns.UI
local Bars = ns.Bars

local selected -- the bar shown on the tab (its id)

local function Current()
	local bar = selected and Bars.Get(selected)
	if not bar then
		bar = ns.db.bars.list[1]
		selected = bar and bar.id
	end
	return bar
end

-- A field of the bar shown: get and set (the set rebuilds the bars).
local function Field(key)
	return function()
		local bar = Current()
		return bar and bar[key]
	end, function(v)
		local bar = Current()
		if bar then
			bar[key] = v
			ns.Refresh()
		end
	end
end

local function Numbers(from, to, by)
	local list = {}
	for v = from, to, by do list[#list + 1] = { v, tostring(v) } end
	return list
end

StaticPopupDialogs.LECDM_BARS = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data) data() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function Confirm(text, action)
	StaticPopup_Show("LECDM_BARS", text, nil, action)
end

-- An entry (a spell, an equipment slot, a bag item) as icon and name; grey, with the reason,
-- while it can't show.
local function EntryText(key, size)
	local text = "|T" .. Bars.EntryIcon(key) .. ":" .. size .. ":" .. size .. "|t " .. Bars.EntryName(key)
	if not Bars.EntryKnown(key) then text = "|cff999999" .. text .. " (" .. Bars.Missing(key) .. ")|r" end
	return text
end

-- In the checklist, a spell on another icon bar says which: ticking it moves it here.
local function MenuText(key, bar)
	local text = EntryText(key, 16)
	local other = Bars.BarOf(key)
	if other and other ~= bar then text = text .. " |cff999999(on " .. other.name .. ")|r" end
	return text
end

-- The checklist: Blizzard's two sections, the spellbook's lines (spells with a cooldown that
-- Blizzard's list doesn't have), equipped slots (the trinkets, and gear with a use effect) and
-- usable items in the bags. Ticking puts an entry on the bar shown (from any other).
local function BuildMenu(_, root)
	local bar = Current()
	if not bar then return end
	local function Checks(title, ids)
		if #ids == 0 then return end
		local sub = root:CreateButton(title)
		for _, id in ipairs(ids) do
			local item = sub:CreateCheckbox(MenuText(id, bar),
				function() return Bars.BarOf(id) == bar end,
				function() Bars.SetOnBar(bar, id, Bars.BarOf(id) ~= bar) end)
			item:SetTooltip(function(tooltip)
				local other = Bars.BarOf(id)
				GameTooltip_SetTitle(tooltip, Bars.EntryName(id))
				if other and other ~= bar then
					GameTooltip_AddNormalLine(tooltip, "On the icon bar " .. other.name .. ": ticking it moves it here.")
				end
			end)
		end
	end
	local listed = {}
	for _, def in ipairs({ { "Blizzard's Essential", 0 }, { "Blizzard's Utility", 1 } }) do
		local ids = {}
		for _, e in ipairs(ns.Catalogue.Spells({ [def[2]] = true }, true)) do
			ids[#ids + 1] = e.spellID
			listed[e.name] = true
		end
		Checks(def[1], ids)
	end
	for _, line in ipairs(Bars.Spellbook()) do
		local ids = {}
		for _, id in ipairs(line.spells) do
			if not listed[Bars.SpellName(id)] then ids[#ids + 1] = id end
		end
		Checks("Spellbook: " .. tostring(line.name), ids)
	end
	Checks("Equipped (trinkets, on-use gear)", Bars.Equipped())
	local best = {}
	for i in ipairs(Bars.BEST) do best[i] = "best:" .. i end
	Checks("Best in your bags (one icon: the best you carry)", best)
	Checks("In your bags (potions, healthstones ...)", Bars.BagItems())
	root:CreateDivider()
	root:CreateButton("An empty space", function() Bars.AddSpace(bar) end)
	root:CreateButton("A spell or item by its ID...", function()
		StaticPopup_Show("LECDM_ADD_ID", nil, nil, { bar = bar })
	end)
end

StaticPopupDialogs.LECDM_ADD_ID = {
	text = "A spell's ID (6673) or an item's (item:13446), from a database site or a tooltip addon:",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 24,
	OnShow = function(dialog)
		local box = dialog:GetEditBox()
		box:SetText("")
		box:SetFocus()
	end,
	OnAccept = function(dialog, data)
		local text = dialog:GetEditBox():GetText() or ""
		if not Bars.AddByID(data.bar, text) then ns.Print("no spell or item '" .. text .. "' in this game.") end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		if dialog and dialog.GetButton1 then dialog:GetButton1():Click() end
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- A dropdown the size and place of the window's buttons (UI.OptionButton: 150 x 24, 30 px into
-- the control column), so the column lines up.
local function Dropdown(row, generator)
	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	dropdown:SetPoint("LEFT", 330, 0)
	dropdown:SetSize(150, 24)
	dropdown:SetupMenu(generator)
	return dropdown
end

local function ChecklistRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Add or remove spells")
	local dropdown = Dropdown(row, BuildMenu)
	row.dropdown = dropdown
	row.Sync = function()
		local bar = Current()
		local n = bar and #bar.spells or 0
		dropdown:SetText(n == 1 and "1 spell" or (n .. " spells"))
	end
	return row
end

local function SmallButton(row, texture, x, tip, onClick)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(22, 22)
	b:SetPoint("LEFT", x, 0)
	b:SetNormalTexture(texture .. "-Up")
	b:SetPushedTexture(texture .. "-Down")
	b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	b:SetScript("OnClick", onClick)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(tip)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

-- The popup for a spell's own icon: a spell ID ("spell:..."), an item ID ("item:...") or an icon's
-- file ID; empty: its own again.
local function IconOf(text)
	text = strtrim(text or "")
	local kind, id = text:match("^(%a+):(%d+)$")
	id = tonumber(id or text)
	if not id then return nil end
	if kind == "spell" then
		local ok, icon = pcall(C_Spell.GetSpellTexture, id)
		return ok and not ns.IsSecret(icon) and icon or nil
	elseif kind == "item" then
		local ok, icon = pcall(C_Item.GetItemIconByID, id)
		return ok and not ns.IsSecret(icon) and icon or nil
	end
	return id
end

StaticPopupDialogs.LECDM_ICON = {
	text = "Its icon: a spell (spell:6673), an item (item:13446) or an icon's file ID (132333). Empty: its own.",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 24,
	OnShow = function(dialog)
		local box = dialog:GetEditBox()
		box:SetText("")
		box:SetFocus()
	end,
	OnAccept = function(dialog, data)
		local text = dialog:GetEditBox():GetText() or ""
		if strtrim(text) == "" then
			Bars.SetLook(data.bar, data.key, "icon", nil)
			return
		end
		local icon = IconOf(text)
		if icon then Bars.SetLook(data.bar, data.key, "icon", icon) else ns.Print("no icon found for '" .. text .. "'.") end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		if dialog and dialog.GetButton1 then dialog:GetButton1():Click() end
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- The ⚙ menu's entries for a spell on the icon bar shown: its look, its buff on it, its stance
-- or form, a talent.
local function Conditions(root, key)
	local bar = Current()
	if not (bar and key) then return end
	if tostring(key):find("^best:") then
		local order = root:CreateButton("Which first (the first you carry shows)")
		for i, itemID in ipairs(Bars.BestOrder(bar, key)) do
			local item = order:CreateButton(i .. ". " .. Bars.EntryName("item:" .. itemID))
			item:CreateButton("Move up", function() Bars.MoveBest(bar, key, i, -1) end)
			item:CreateButton("Move down", function() Bars.MoveBest(bar, key, i, 1) end)
		end
	end
	root:CreateTitle("Its look")
	local function LookMenu(label, field, list)
		local sub = root:CreateButton(label)
		sub:CreateRadio("As the bar's (" .. ns.Alerts.Label(list, bar[field]) .. ")",
			function() return Bars.Own(bar, key)[field] == nil end, function() Bars.SetLook(bar, key, field, nil) end)
		for _, v in ipairs(list) do
			sub:CreateRadio(v[2], function() return Bars.Own(bar, key)[field] == v[1] end,
				function() Bars.SetLook(bar, key, field, v[1]) end)
		end
	end
	LookMenu("Border", "border", Bars.BORDERS)
	LookMenu("Border colour", "borderColor", Bars.BORDER_COLORS)
	root:CreateButton("Icon..." .. (Bars.Own(bar, key).icon and " (its own)" or ""), function()
		StaticPopup_Show("LECDM_ICON", nil, nil, { bar = bar, key = key })
	end)
	if type(key) == "number" then
		local active = root:CreateButton("While its buff is up")
		active:CreateRadio("Show the cooldown", function() return not (bar.active and bar.active[key]) end,
			function() Bars.SetActive(bar, key, false) end)
		active:CreateRadio("Show the buff on it (its time, stacks, glow)", function() return bar.active and bar.active[key] == true end,
			function() Bars.SetActive(bar, key, true) end)
	end
	root:CreateTitle("When it shows")
	local sub = root:CreateButton("In a stance or form")
	local function Radio(text, value)
		sub:CreateRadio(text, function() return (bar.forms and bar.forms[key]) == value end,
			function() Bars.SetForm(bar, key, value) end)
	end
	Radio("Any (always)", nil)
	local forms = Bars.Forms()
	for _, f in ipairs(forms) do
		Radio("Only in " .. f[2], "in:" .. f[1])
		Radio("Not in " .. f[2], "out:" .. f[1])
	end
	if #forms > 0 then
		Radio("Only in no stance or form", "in:0")
		Radio("Only in a stance or form", "out:0")
	end

	local talents = root:CreateButton("With a talent")
	local function Is(value) return function() return (bar.talents and bar.talents[key]) == value end end
	local function Set(value) return function() Bars.SetTalent(bar, key, value) end end
	talents:CreateRadio("Any (always)", Is(nil), Set(nil))
	local t = ns.Talents.Read()
	if not t.known then
		talents:CreateTitle("The game didn't list your talents")
		return
	end
	local trees, order = {}, {}
	for _, e in ipairs(t.list) do
		if not trees[e[3]] then
			trees[e[3]] = talents:CreateButton(e[3])
			order[#order + 1] = e[3]
		end
		local sub2 = trees[e[3]]:CreateButton(e[2] .. (t.taken[e[1]] and " |cff40ff40(taken)|r" or ""))
		sub2:CreateRadio("Only with it", Is("with:" .. e[1]), Set("with:" .. e[1]))
		sub2:CreateRadio("Only without it", Is("without:" .. e[1]), Set("without:" .. e[1]))
	end
end

-- A spell on the bar: its icon and name, when it shows, and up / down / remove.
local function SpellRow(parent)
	local row
	local function get()
		local bar = Current()
		return bar and row.key and (bar.show[row.key] or "always") or "always"
	end
	local function set(v)
		local bar = Current()
		if bar and row.key then
			bar.show[row.key] = v ~= "always" and v or nil
			ns.Refresh()
		end
	end
	row = UI.OptionSelect(parent, "", Bars.SHOW, get, set, {
		controlX = 260, boxWidth = 130,
		tooltip = function()
			return { row.key and Bars.EntryName(row.key) or "",
				"Always: the icon is always there. Only when ready: hidden while it's on cooldown. Only on cooldown: hidden while it's ready. A hidden icon's place closes up." }
		end,
		sync = function(r)
			local own = r.key and ns.Alerts.HasOwn("spells", r.key) and " |cff999999(own alerts)|r" or ""
			r.label:SetText(r.key and (EntryText(r.key, 20) .. own) or "")
		end,
	})
	local x = row.right + 4
	SmallButton(row, "Interface\\Buttons\\Arrow-Up", x, "Move up", function()
		local bar = Current()
		if bar then Bars.MoveSpell(bar, row.index, -1) end
	end)
	SmallButton(row, "Interface\\Buttons\\Arrow-Down", x + 24, "Move down", function()
		local bar = Current()
		if bar then Bars.MoveSpell(bar, row.index, 1) end
	end)
	SmallButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass", x + 52, "Take it off this icon bar", function()
		local bar = Current()
		if bar and row.key then Bars.SetOnBar(bar, row.key, false) end
	end)
	row.gear = ns.AlertsGear(row, x + 80, "spells", function() return row.key end,
		function() return row.key and Bars.EntryName(row.key) end,
		function(root) Conditions(root, row.key) end)
	return row
end

-- The popup for a new icon bar: a name box, OK and Cancel. An empty name gets a numbered one.
StaticPopupDialogs.LECDM_NEW_BAR = {
	text = "Name the new icon bar:",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 32,
	OnShow = function(dialog)
		local box = dialog:GetEditBox()
		box:SetText("")
		box:SetFocus()
	end,
	OnAccept = function(dialog)
		local name = strtrim(dialog:GetEditBox():GetText() or "")
		if name == "" then name = "Icon bar " .. (#ns.db.bars.list + 1) end
		selected = Bars.NewBar(name).id
		ns.Refresh()
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		if dialog and dialog.GetButton1 then dialog:GetButton1():Click() end
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- The icon bar dropdown: one entry per bar, then "New icon bar..." (the popup).
local function BuildBarMenu(_, root)
	for _, bar in ipairs(ns.db.bars.list) do
		root:CreateRadio(bar.name,
			function() return Current() == bar end,
			function()
				selected = bar.id
				ns.Window.Refresh()
			end)
	end
	root:CreateDivider()
	root:CreateButton("New icon bar...", function() StaticPopup_Show("LECDM_NEW_BAR") end)
end

local function BarPickerRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Icon bar")
	local dropdown = Dropdown(row, BuildBarMenu)
	row.dropdown = dropdown
	row.Sync = function()
		local bar = Current()
		dropdown:SetText(bar and bar.name or "None: make one")
	end
	return row
end

ns.Window.Page({
	id = "bars",
	label = "Icon bars",
	order = 2,
	note = "Your cooldowns in icon bars you lay out. Pick an icon bar (or make one) at the top; everything below is about that bar. Unlock to drag the bars into place.",
	fill = function(stack, panel)
		local p = { spellRows = {} }
		-- One local pair per field: a call returning two values only passes both when it's last.
		local sizeGet, sizeSet = Field("size")
		local gapGet, gapSet = Field("gap")
		local growGet, growSet = Field("grow")
		local vertGet, vertSet = Field("vertical")
		local perGet, perSet = Field("perRow")
		local gcdGet, gcdSet = Field("gcd")
		local emptyGet, emptySet = Field("emptyItems")
		local borderGet, borderSet = Field("border")
		local bcolGet, bcolSet = Field("borderColor")
		local zoomGet, zoomSet = Field("zoom")
		local cdGet, cdSet = Field("countdown")
		local keyGet, keySet = Field("keybind")
		local tipGet, tipSet = Field("tooltip")
		local greyGet, greySet = Field("grey")
		local cdaGet, cdaSet = Field("cdAlpha")
		local zeroGet, zeroSet = Field("zeroCharges")
		local swGet, swSet = Field("swipe")
		local swcGet, swcSet = Field("swipeColor")
		local edgeGet, edgeSet = Field("edge")
		local actGet, actSet = Field("activeColor")
		local thGet, thSet = Field("threshold")
		local thcGet, thcSet = Field("thresholdColor")
		local thdGet, thdSet = Field("thresholdDecimals")
		local redGet, redSet = Field("red")
		local darkGet, darkSet = Field("dark")
		local showGet, showSet = Field("showWhen")
		local alphaGet, alphaSet = Field("alpha")
		local oocGet, oocSet = Field("oocAlpha")
		local V = ns.Visibility
		panel.parts = p
		p.picker = BarPickerRow(stack.inner)
		p.top = {
			p.picker,

			UI.OptionHeading(stack.inner, "This icon bar"),
			UI.OptionEdit(stack.inner, "Name (press Enter to keep it)",
				function() local bar = Current() return bar and bar.name or "" end,
				function(text)
					local bar = Current()
					text = strtrim(text or "")
					if bar and text ~= "" then
						bar.name = text
						ns.Refresh()
					end
				end),
			UI.OptionSelect(stack.inner, "Icon size", Numbers(24, 64, 4), sizeGet, sizeSet),
			UI.OptionSelect(stack.inner, "Space between icons", Numbers(0, 12, 1), gapGet, gapSet),
			UI.OptionSelect(stack.inner, "Grow from", Bars.GROW, growGet, growSet,
				{ tooltip = { "Grow from", "Where the icons start, so that edge stays put as icons hide and show. Vertical bars: left is the top, right the bottom." } }),
			UI.OptionCheck(stack.inner, "Vertical", vertGet, vertSet),
			UI.OptionSelect(stack.inner, "Icons per row", Numbers(1, 20, 1), perGet, perSet,
				{ tooltip = { "Icons per row", "More start a new row (a new column, on a vertical bar)." } }),
			UI.OptionCheck(stack.inner, "Show the GCD sweep", gcdGet, gcdSet,
				{ "GCD sweep", "A short sweep on every icon after a spell that triggers the global cooldown." }),
			UI.OptionSelect(stack.inner, "Items you have none of", { { "hide", "Hide them" }, { "grey", "Show them greyed" } },
				emptyGet, emptySet,
				{ tooltip = { "Items you have none of", "A potion or healthstone on this bar when your bags have none: hidden (its place closes up), or shown greyed with a 0." } }),
			UI.OptionHeading(stack.inner, "Its look"),
			UI.OptionSelect(stack.inner, "Border", Bars.BORDERS, borderGet, borderSet),
			UI.OptionSelect(stack.inner, "Border colour", Bars.BORDER_COLORS, bcolGet, bcolSet),
			UI.OptionSelect(stack.inner, "Icon zoom", Bars.ZOOMS, zoomGet, zoomSet,
				{ tooltip = { "Icon zoom", "How much of the icon's own edge is cut off." } }),
			UI.OptionSelect(stack.inner, "Swipe", Bars.SWIPES, swGet, swSet),
			UI.OptionSelect(stack.inner, "Swipe colour", Bars.SWIPE_COLORS, swcGet, swcSet),
			UI.OptionCheck(stack.inner, "Bright edge on the swipe", edgeGet, edgeSet),
			UI.OptionSelect(stack.inner, "Swipe colour while its buff is up", Bars.SWIPE_COLORS, actGet, actSet,
				{ tooltip = { "While its buff is up", "For spells whose ⚙ says to show their buff on them (Death Wish, Shield Block): the buff's time left as a swipe in this colour." } }),
			UI.OptionSelect(stack.inner, "Countdown text", Bars.TEXT_SIZES, cdGet, cdSet,
				{ tooltip = { "Countdown text", "The cooldown's time left on the icon (the game draws it; its own setting, Show Numbers for Cooldowns, must be on)." } }),
			UI.OptionSelect(stack.inner, "Countdown: near the end, under", Bars.THRESHOLDS, thGet, thSet,
				{ tooltip = { "Near the end", "Under this time the countdown can change colour, or show a decimal (8.7)." } }),
			UI.OptionSelect(stack.inner, "...its colour then", Bars.THRESHOLD_COLORS, thcGet, thcSet),
			UI.OptionCheck(stack.inner, "...a decimal then (with no colour)", thdGet, thdSet,
				{ "A decimal", "The game's countdown shows a decimal under that time; it can't colour its numbers, so the decimal shows when the colour is None." }),
			UI.OptionCheck(stack.inner, "Keybind text", keyGet, keySet,
				{ "Keybind text", "The key of the first action button on screen holding the spell or item, from any bar addon." }),
			UI.OptionSelect(stack.inner, "Tooltip on hover", Bars.TOOLTIPS, tipGet, tipSet,
				{ tooltip = { "Tooltip on hover", "The game's tooltip for the spell or item when your mouse is over its icon. Off lets clicks through to the world." } }),
			UI.OptionCheck(stack.inner, "Grey while on cooldown", greyGet, greySet),
			UI.OptionSelect(stack.inner, "Opacity while on cooldown", ns.Alerts.ALPHAS, cdaGet, cdaSet),
			UI.OptionCheck(stack.inner, "Show 0 charges", zeroGet, zeroSet,
				{ "Show 0 charges", "For spells with charges: the count stays on the icon at 0 (out of combat it can be hidden then; in combat the game shows the count, and Lecdm can't read it)." }),
			UI.OptionCheck(stack.inner, "Red while your target is out of range", redGet, redSet),
			UI.OptionCheck(stack.inner, "Dark while you can't use it", darkGet, darkSet),
			UI.OptionHeading(stack.inner, "When it shows"),
			UI.OptionSelect(stack.inner, "Show it", V.SHOW, showGet, showSet),
			UI.OptionSelect(stack.inner, "Opacity", V.ALPHAS, alphaGet, alphaSet),
			UI.OptionSelect(stack.inner, "Out of combat", V.OOC, oocGet, oocSet,
				{ tooltip = { "Out of combat", "Its opacity out of combat, as a share of the opacity above: fade it, or hide it, while you're not fighting." } }),
			UI.OptionButton(stack.inner, "", "Delete this icon bar", function()
				local bar = Current()
				if not bar then return end
				Confirm("Delete the icon bar " .. bar.name .. "? Its spells go back to the checklist.", function()
					Bars.Delete(bar.id)
					selected = nil
					ns.Window.Refresh()
				end)
			end),

			UI.OptionHeading(stack.inner, "Its spells"),
			ChecklistRow(stack.inner),
		}
		p.empty = UI.OptionText(stack.inner, "No spells on this icon bar yet: tick some in the list above.", 24)
		p.none = UI.OptionText(stack.inner, "There are no icon bars: pick \"New icon bar...\" in the dropdown above, or Start over below.", 24)
		p.bottom = {
			UI.OptionText(stack.inner, "Grey here: a spell not learned yet, a slot with nothing usable in it, an item you have none of. They appear on the bar when they can.", 24),
			UI.OptionHeading(stack.inner, "All icon bars"),
			UI.OptionButton(stack.inner, "Move the icon bars", function()
				return Bars.IsUnlocked() and "Lock" or "Unlock"
			end, function() Bars.SetUnlocked(not Bars.IsUnlocked()) end,
				{ "Move the icon bars", "Unlocked, each icon bar shows its name and can be dragged. /lecdm move does the same." }),
			UI.OptionCheck(stack.inner, "Hide Blizzard's Essential and Utility icons",
				function() return ns.db.bars.hideBlizzard end,
				function(v)
					ns.db.bars.hideBlizzard = v
					ns.Refresh()
				end,
				{ "Blizzard's icons", "Lecdm's icon bars replace them: they're made invisible but keep running, so Lecdm still hears them. Blizzard's buff icons and bars aren't touched." }),
			UI.OptionButton(stack.inner, "Every icon bar", "Start over", function()
				Confirm("Replace every icon bar with the two filled from Blizzard's list, as on a new profile?", function()
					Bars.StartOver()
					selected = nil
					ns.Window.Refresh()
				end)
			end, { "Start over", "Every icon bar back to the two Lecdm makes at first: your Essential and Utility spells from Blizzard's list." }),
		}
	end,
	refresh = function(panel)
		local p, stack = panel.parts, panel.stack
		stack:Reset()
		local bar = Current()
		if bar then
			for _, row in ipairs(p.top) do stack:Add(row) end
			for i, id in ipairs(bar.spells) do
				local row = p.spellRows[i]
				if not row then
					row = SpellRow(stack.inner)
					p.spellRows[i] = row
				end
				row.index, row.key = i, id
				stack:Add(row)
			end
			if #bar.spells == 0 then stack:Add(p.empty) end
		else
			stack:Add(p.picker)
			stack:Add(p.none)
		end
		for _, row in ipairs(p.bottom) do stack:Add(row) end
		stack:Done()
		stack:Sync()
	end,
})
