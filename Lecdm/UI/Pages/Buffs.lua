-- Lecdm: the Buffs tab. Laid out like the Icon bars tab: a dropdown picks the buff group (its
-- last entry makes a new one, in a popup); everything below is about the group picked: its name,
-- how it shows (icons or timer bars) and its look, Delete, then its buffs (a checklist of
-- Blizzard's list and the buffs on you now, and an ordered row per buff).
local _, ns = ...
local UI = ns.UI
local Auras = ns.Auras

local selected -- the group shown (its id)

local function Current()
	local group = selected and Auras.Get(selected)
	if not group then
		group = ns.db.buffs.list[1]
		selected = group and group.id
	end
	return group
end

local function Field(key)
	return function()
		local group = Current()
		return group and group[key]
	end, function(v)
		local group = Current()
		if group then
			group[key] = v
			ns.Refresh()
		end
	end
end

local function Numbers(from, to, by)
	local list = {}
	for v = from, to, by do list[#list + 1] = { v, tostring(v) } end
	return list
end

local GROW = { { "CENTER", "Centre" }, { "LEFT", "Left / top" }, { "RIGHT", "Right / bottom" } }

StaticPopupDialogs.LECDM_BUFFS = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data) data() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function Confirm(text, action)
	StaticPopup_Show("LECDM_BUFFS", text, nil, action)
end

StaticPopupDialogs.LECDM_NEW_BUFFS = {
	text = "Name the new buff group:",
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
		if name == "" then name = "Buff group " .. (#ns.db.buffs.list + 1) end
		selected = Auras.NewGroup(name).id
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

local function BuffText(name, size, icon)
	return "|T" .. (icon or Auras.Icon(name)) .. ":" .. size .. ":" .. size .. "|t " .. name
end

local function MenuText(name, group, icon, known)
	local text = BuffText(name, 16, icon)
	if known == false then text = "|cff999999" .. text .. " (not learned)|r" end
	local other = Auras.GroupOf(name)
	if other and other ~= group then text = text .. " |cff999999(in " .. other.name .. ")|r" end
	return text
end

-- The checklist: your buffs from Blizzard's list, and the buffs on you now (out of combat).
local function BuildMenu(_, root)
	local group = Current()
	if not group then return end
	local function Check(sub, name, icon, known, spellID)
		sub:CreateCheckbox(MenuText(name, group, icon, known),
			function() return Auras.GroupOf(name) == group end,
			function()
				local on = Auras.GroupOf(name) ~= group
				if on and spellID then Auras.Learn(name, spellID) end
				Auras.SetInGroup(group, name, on)
			end)
	end
	local blizzard = Auras.BlizzardBuffs()
	if #blizzard > 0 then
		local sub = root:CreateButton("Yours, from Blizzard's list")
		for _, e in ipairs(blizzard) do Check(sub, e.name, nil, e.known and true or false) end
	end
	local sub = root:CreateButton("On you now (anyone's)")
	if InCombatLockdown() then
		sub:CreateTitle("Out of combat only")
	else
		local now = Auras.ReadBuffs()
		if #now == 0 then sub:CreateTitle("No buffs on you that the game lets an addon read here") end
		for _, b in ipairs(now) do Check(sub, b.name, b.icon, nil, b.spellID) end
	end
end

local function Dropdown(row, generator)
	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	dropdown:SetPoint("LEFT", 330, 0)
	dropdown:SetSize(150, 24)
	dropdown:SetupMenu(generator)
	return dropdown
end

local function BuildGroupMenu(_, root)
	for _, group in ipairs(ns.db.buffs.list) do
		root:CreateRadio(group.name,
			function() return Current() == group end,
			function()
				selected = group.id
				ns.Window.Refresh()
			end)
	end
	root:CreateDivider()
	root:CreateButton("New buff group...", function() StaticPopup_Show("LECDM_NEW_BUFFS") end)
end

local function PickerRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Buff group")
	row.dropdown = Dropdown(row, BuildGroupMenu)
	row.Sync = function()
		local group = Current()
		row.dropdown:SetText(group and group.name or "None: make one")
	end
	return row
end

local function ChecklistRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Add or remove buffs")
	row.dropdown = Dropdown(row, BuildMenu)
	row.Sync = function()
		local group = Current()
		local n = group and #group.entries or 0
		row.dropdown:SetText(n == 1 and "1 buff" or (n .. " buffs"))
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

-- A buff in the group: its icon and name, then up / down / remove.
local function BuffRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(32)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetWidth(300)
	row.label:SetJustifyH("LEFT")
	SmallButton(row, "Interface\\Buttons\\Arrow-Up", 334, "Move up", function()
		local group = Current()
		if group then Auras.MoveEntry(group, row.index, -1) end
	end)
	SmallButton(row, "Interface\\Buttons\\Arrow-Down", 358, "Move down", function()
		local group = Current()
		if group then Auras.MoveEntry(group, row.index, 1) end
	end)
	SmallButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass", 386, "Take it out of this buff group", function()
		local group = Current()
		if group and row.name then Auras.SetInGroup(group, row.name, false) end
	end)
	row.Sync = function() row.label:SetText(row.name and BuffText(row.name, 20) or "") end
	return row
end

ns.Window.Page({
	id = "buffs",
	label = "Buffs",
	order = 3,
	note = "Buffs on you, from anyone, while they're up: as icons or timer bars. Pick a buff group (or make one) at the top; everything below is about that group. Changes made in combat apply when it ends.",
	fill = function(stack, panel)
		local p = { buffRows = {} }
		panel.parts = p
		local styleGet, styleSet = Field("style")
		local sizeGet, sizeSet = Field("size")
		local widthGet, widthSet = Field("barWidth")
		local gapGet, gapSet = Field("gap")
		local growGet, growSet = Field("grow")
		local vertGet, vertSet = Field("vertical")
		local perGet, perSet = Field("perRow")
		p.picker = PickerRow(stack.inner)
		p.head = UI.OptionHeading(stack.inner, "This buff group")
		p.name = UI.OptionEdit(stack.inner, "Name (press Enter to keep it)",
			function() local group = Current() return group and group.name or "" end,
			function(text)
				local group = Current()
				text = strtrim(text or "")
				if group and text ~= "" then
					group.name = text
					ns.Refresh()
				end
			end)
		p.style = UI.OptionSelect(stack.inner, "Show as", Auras.STYLES, styleGet, styleSet,
			{ tooltip = { "Show as", "Icons: a row of icons with a swipe and the time left. Timer bars: the icon, then a bar draining to the right with the buff's name and the time left." } })
		p.iconSize = UI.OptionSelect(stack.inner, "Icon size", Numbers(20, 64, 4), sizeGet, sizeSet)
		p.barHeight = UI.OptionSelect(stack.inner, "Bar height", Numbers(12, 40, 2), sizeGet, sizeSet)
		p.barWidth = UI.OptionSelect(stack.inner, "Bar width", Numbers(100, 400, 20), widthGet, widthSet)
		p.gap = UI.OptionSelect(stack.inner, "Space between", Numbers(0, 12, 1), gapGet, gapSet)
		p.grow = UI.OptionSelect(stack.inner, "Grow from", GROW, growGet, growSet,
			{ tooltip = { "Grow from", "Where the buffs start, so that edge stays put as buffs come and go. Vertical groups and timer bars: left is the top, right the bottom." } })
		p.vertical = UI.OptionCheck(stack.inner, "Vertical", vertGet, vertSet)
		p.perRow = UI.OptionSelect(stack.inner, "Icons per row", Numbers(1, 20, 1), perGet, perSet)
		p.delete = UI.OptionButton(stack.inner, "", "Delete this buff group", function()
			local group = Current()
			if not group then return end
			Confirm("Delete the buff group " .. group.name .. "? Its buffs go back to the checklist.", function()
				Auras.Delete(group.id)
				selected = nil
				ns.Window.Refresh()
			end)
		end)
		p.buffsHead = UI.OptionHeading(stack.inner, "Its buffs")
		p.checklist = ChecklistRow(stack.inner)
		p.empty = UI.OptionText(stack.inner, "No buffs in this group yet: tick some in the list above.", 24)
		p.none = UI.OptionText(stack.inner, "There are no buff groups: pick \"New buff group...\" in the dropdown above, or Start over below.", 24)
		p.bottom = {
			UI.OptionText(stack.inner, "A buff shows while it's on you, whoever cast it. Lecdm learns every rank of a buff the first time it sees it on you out of combat.", 32),
			UI.OptionHeading(stack.inner, "All buff groups"),
			UI.OptionButton(stack.inner, "Move the buff groups", function()
				return ns.Bars.IsUnlocked() and "Lock" or "Unlock"
			end, function() ns.Bars.SetUnlocked(not ns.Bars.IsUnlocked()) end,
				{ "Move", "Unlocked, every icon bar and buff group shows its name and can be dragged. /lecdm move does the same." }),
			UI.OptionButton(stack.inner, "Every buff group", "Start over", function()
				Confirm("Replace every buff group with one filled from Blizzard's list, as on a new profile?", function()
					Auras.StartOver()
					selected = nil
					ns.Window.Refresh()
				end)
			end),
		}
	end,
	refresh = function(panel)
		local p, stack = panel.parts, panel.stack
		stack:Reset()
		stack:Add(p.picker)
		local group = Current()
		if group then
			local bars = group.style == "bars"
			for _, row in ipairs({ p.head, p.name, p.style }) do stack:Add(row) end
			if bars then
				stack:Add(p.barHeight)
				stack:Add(p.barWidth)
			else
				stack:Add(p.iconSize)
			end
			stack:Add(p.gap)
			stack:Add(p.grow)
			if not bars then
				stack:Add(p.vertical)
				stack:Add(p.perRow)
			end
			stack:Add(p.delete)
			stack:Add(p.buffsHead)
			stack:Add(p.checklist)
			for i, name in ipairs(group.entries) do
				local row = p.buffRows[i]
				if not row then
					row = BuffRow(stack.inner)
					p.buffRows[i] = row
				end
				row.index, row.name = i, name
				stack:Add(row)
			end
			if #group.entries == 0 then stack:Add(p.empty) end
		else
			stack:Add(p.none)
		end
		for _, row in ipairs(p.bottom) do stack:Add(row) end
		stack:Done()
		stack:Sync()
	end,
})
