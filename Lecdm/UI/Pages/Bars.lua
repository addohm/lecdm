-- Lecdm: the Bars tab. Pick a bar (or make one), set its look, tick its spells in a checklist
-- (Blizzard's list and the spellbook), order them, and choose when each shows. The list of
-- spell rows is rebuilt on each refresh (UI.Stack Reset/Add/Done), so an open checklist stays
-- open while you tick.
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

local function SpellText(spellID, size)
	local text = "|T" .. Bars.SpellIcon(spellID) .. ":" .. size .. ":" .. size .. "|t " .. Bars.SpellName(spellID)
	if not Bars.Known(spellID) then text = "|cff999999" .. text .. " (not learned)|r" end
	return text
end

-- The checklist: Blizzard's two sections, then the spellbook's lines (spells with a cooldown
-- that Blizzard's list doesn't have). Ticking puts a spell on the bar shown (from any other).
local function BuildMenu(_, root)
	local bar = Current()
	if not bar then return end
	local function Checks(title, ids)
		if #ids == 0 then return end
		local sub = root:CreateButton(title)
		for _, id in ipairs(ids) do
			local item = sub:CreateCheckbox(SpellText(id, 16),
				function() return Bars.BarOf(id) == bar end,
				function() Bars.SetOnBar(bar, id, Bars.BarOf(id) ~= bar) end)
			item:SetTooltip(function(tooltip)
				local other = Bars.BarOf(id)
				GameTooltip_SetTitle(tooltip, Bars.SpellName(id))
				if other and other ~= bar then
					GameTooltip_AddNormalLine(tooltip, "On " .. other.name .. ": ticking it moves it here.")
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
end

local function ChecklistRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Add or remove spells")
	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	dropdown:SetPoint("LEFT", 300, 0)
	dropdown:SetupMenu(BuildMenu)
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
		return bar and row.spellID and (bar.show[row.spellID] or "always") or "always"
	end
	local function set(v)
		local bar = Current()
		if bar and row.spellID then
			bar.show[row.spellID] = v ~= "always" and v or nil
			ns.Refresh()
		end
	end
	row = UI.OptionSelect(parent, "", Bars.SHOW, get, set, {
		controlX = 260, boxWidth = 130,
		tooltip = function()
			return { row.spellID and Bars.SpellName(row.spellID) or "",
				"Always: the icon is always there. Only when ready: hidden while it's on cooldown. Only on cooldown: hidden while it's ready. A hidden icon's place closes up." }
		end,
		sync = function(r) r.label:SetText(r.spellID and SpellText(r.spellID, 20) or "") end,
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
	SmallButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass", x + 52, "Take it off this bar", function()
		local bar = Current()
		if bar and row.spellID then Bars.SetOnBar(bar, row.spellID, false) end
	end)
	return row
end

local function BarChoices()
	local list = {}
	for _, bar in ipairs(ns.db.bars.list) do list[#list + 1] = { bar.id, bar.name } end
	return list
end

ns.Window.Page({
	id = "bars",
	label = "Bars",
	order = 2,
	note = "Your cooldowns in bars you lay out. Pick a bar, tick its spells, and choose when each one shows. Unlock to drag the bars into place.",
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
		p.top = {
			UI.OptionHeading(stack.inner, "Your bars"),
			UI.OptionSelect(stack.inner, "Bar", BarChoices,
				function() local bar = Current() return bar and bar.id end,
				function(id)
					selected = id
					ns.Window.Refresh()
				end),
			UI.OptionEdit(stack.inner, "New bar (type a name, press Enter)",
				function() return "" end,
				function(text)
					text = strtrim(text or "")
					if text == "" then return end
					selected = Bars.NewBar(text).id
					ns.Refresh()
					return true
				end,
				{ "New bar", "An empty bar under the others; tick its spells below." }),
			UI.OptionEdit(stack.inner, "Rename this bar (press Enter)",
				function() local bar = Current() return bar and bar.name or "" end,
				function(text)
					local bar = Current()
					text = strtrim(text or "")
					if bar and text ~= "" then
						bar.name = text
						ns.Refresh()
					end
				end),
			UI.OptionButton(stack.inner, "", "Delete this bar", function()
				local bar = Current()
				if not bar then return end
				Confirm("Delete the bar " .. bar.name .. "? Its spells go back to the checklist.", function()
					Bars.Delete(bar.id)
					selected = nil
					ns.Window.Refresh()
				end)
			end),

			UI.OptionHeading(stack.inner, "This bar's look"),
			UI.OptionSelect(stack.inner, "Icon size", Numbers(24, 64, 4), sizeGet, sizeSet),
			UI.OptionSelect(stack.inner, "Space between icons", Numbers(0, 12, 1), gapGet, gapSet),
			UI.OptionSelect(stack.inner, "Grow from", Bars.GROW, growGet, growSet,
				{ tooltip = { "Grow from", "Where the icons start, so that edge stays put as icons hide and show. Vertical bars: left is the top, right the bottom." } }),
			UI.OptionCheck(stack.inner, "Vertical", vertGet, vertSet),
			UI.OptionSelect(stack.inner, "Icons per row", Numbers(1, 20, 1), perGet, perSet,
				{ tooltip = { "Icons per row", "More start a new row (a new column, on a vertical bar)." } }),
			UI.OptionCheck(stack.inner, "Show the GCD sweep", gcdGet, gcdSet,
				{ "GCD sweep", "A short sweep on every icon after a spell that triggers the global cooldown." }),

			UI.OptionHeading(stack.inner, "This bar's spells"),
			ChecklistRow(stack.inner),
		}
		p.empty = UI.OptionText(stack.inner, "No spells on this bar yet: tick some in the list above.", 24)
		p.bottom = {
			UI.OptionText(stack.inner, "Spells you haven't learned yet show grey here and appear on the bar once you learn them.", 24),
			UI.OptionHeading(stack.inner, "All bars"),
			UI.OptionButton(stack.inner, "Move the bars", function()
				return Bars.IsUnlocked() and "Lock" or "Unlock"
			end, function() Bars.SetUnlocked(not Bars.IsUnlocked()) end,
				{ "Move the bars", "Unlocked, each bar shows its name and can be dragged. /lecdm move does the same." }),
			UI.OptionCheck(stack.inner, "Hide Blizzard's Essential and Utility icons",
				function() return ns.db.bars.hideBlizzard end,
				function(v)
					ns.db.bars.hideBlizzard = v
					ns.Refresh()
				end,
				{ "Blizzard's icons", "Lecdm's bars replace them: they're made invisible but keep running, so Lecdm still hears them. Blizzard's buff icons and bars aren't touched." }),
			UI.OptionButton(stack.inner, "Every bar", "Start over", function()
				Confirm("Replace every bar with the two filled from Blizzard's list, as on a new profile?", function()
					Bars.StartOver()
					selected = nil
					ns.Window.Refresh()
				end)
			end, { "Start over", "Every bar back to the two Lecdm makes at first: your Essential and Utility spells from Blizzard's list." }),
		}
	end,
	refresh = function(panel)
		local p, stack = panel.parts, panel.stack
		stack:Reset()
		for _, row in ipairs(p.top) do stack:Add(row) end
		local bar = Current()
		local spells = bar and bar.spells or {}
		for i, id in ipairs(spells) do
			local row = p.spellRows[i]
			if not row then
				row = SpellRow(stack.inner)
				p.spellRows[i] = row
			end
			row.index, row.spellID = i, id
			stack:Add(row)
		end
		if #spells == 0 then stack:Add(p.empty) end
		for _, row in ipairs(p.bottom) do stack:Add(row) end
		stack:Done()
		stack:Sync()
	end,
})
