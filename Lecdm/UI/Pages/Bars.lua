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
	Checks("In your bags (potions, healthstones ...)", Bars.BagItems())
end

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
		sync = function(r) r.label:SetText(r.key and EntryText(r.key, 20) or "") end,
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
