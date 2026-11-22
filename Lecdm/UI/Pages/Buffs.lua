-- Lecdm: the Buffs tab. Laid out like the Icon bars tab: a dropdown picks the buff group (its
-- last entry makes a new one, in a popup); everything below is about the group picked: its name,
-- how it shows (icons or timer bars) and its look, Delete, then its buffs (a checklist of
-- Blizzard's list and the buffs on you now, and an ordered row per buff). The dropdown also has
-- Blizzard's own icons and timer bars (Hosted.lua): take them into Lecdm, hide or leave them.
local _, ns = ...
local UI = ns.UI
local Auras = ns.Auras

local selected -- the group shown (its id), or "blizz:icons" / "blizz:bars"

-- The Blizzard place shown, if one is.
local function CurrentKind()
	local key = selected and selected:match("^blizz:(%a+)$")
	return key and ns.Hosted.Kind(key)
end

local function Current()
	if CurrentKind() then return nil end
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
	for _, kind in ipairs(ns.Hosted.KINDS) do
		root:CreateRadio(kind.name .. " (picked in /cdm)",
			function() return selected == "blizz:" .. kind.key end,
			function()
				selected = "blizz:" .. kind.key
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
		local kind, group = CurrentKind(), Current()
		row.dropdown:SetText(kind and kind.name or group and group.name or "None: make one")
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

-- A buff in the group: its icon and name, how it shows, then up / down / remove and its ⚙.
local function BuffRow(parent)
	local row
	local function get()
		local group = Current()
		return group and row.name and Auras.Mode(group, row.name) or "up"
	end
	local function set(v)
		local group = Current()
		if group and row.name then Auras.SetMode(group, row.name, v) end
	end
	row = UI.OptionSelect(parent, "", Auras.MODES, get, set, {
		controlX = 260, boxWidth = 130,
		tooltip = function()
			return { row.name or "", "While it's up: it shows while it's on you, and the others close up. Keep up: a fixed place, with a copy of it and the missing glow while it's down. Only while missing: a fixed place showing only the copy. How they look (grey or faded while up; full colour, grey or red while missing) is on the Alerts tab, or the buff's ⚙." }
		end,
		sync = function(r)
			local own = r.name and ns.Alerts.HasOwn("buffs", r.name) and " |cff999999(own alerts)|r" or ""
			r.label:SetText(r.name and (BuffText(r.name, 20) .. own) or "")
		end,
	})
	local x = row.right + 4
	SmallButton(row, "Interface\\Buttons\\Arrow-Up", x, "Move up", function()
		local group = Current()
		if group then Auras.MoveEntry(group, row.index, -1) end
	end)
	SmallButton(row, "Interface\\Buttons\\Arrow-Down", x + 24, "Move down", function()
		local group = Current()
		if group then Auras.MoveEntry(group, row.index, 1) end
	end)
	SmallButton(row, "Interface\\Buttons\\UI-GroupLoot-Pass", x + 52, "Take it out of this buff group", function()
		local group = Current()
		if group and row.name then Auras.SetInGroup(group, row.name, false) end
	end)
	ns.AlertsGear(row, x + 80, "buffs", function() return row.name end, function() return row.name end)
	return row
end

-- A setting of the Blizzard place shown.
local function BlizzField(key)
	return function()
		local kind = CurrentKind()
		return kind and ns.Hosted.Settings(kind.key)[key]
	end, function(v)
		local kind = CurrentKind()
		if kind then
			ns.Hosted.Settings(kind.key)[key] = v
			ns.Refresh()
		end
	end
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
		local V, Bars = ns.Visibility, ns.Bars
		local function Row(kind, label, list, key, tip)
			local get, set = Field(key)
			if kind == "check" then return UI.OptionCheck(stack.inner, label, get, set, tip) end
			return UI.OptionSelect(stack.inner, label, list, get, set, tip and { tooltip = tip } or nil)
		end
		p.lookHead = UI.OptionHeading(stack.inner, "Its look")
		p.border = Row("select", "Border", Bars.BORDERS, "border")
		p.borderColor = Row("select", "Border colour", Bars.BORDER_COLORS, "borderColor")
		p.zoom = Row("select", "Icon zoom", Bars.ZOOMS, "zoom")
		p.timeText = Row("select", "Time text", Bars.TEXT_SIZES, "timeText")
		p.barTexture = Row("select", "Bar texture", Auras.TEXTURES, "barTexture")
		p.barColor = Row("select", "Bar colour", Auras.BAR_COLORS, "barColor")
		p.barBg = Row("select", "Bar background", Auras.BG, "barBg")
		p.barIcon = Row("check", "Icon at the left", nil, "barIcon")
		p.barName = Row("check", "The buff's name", nil, "barName")
		p.barTime = Row("check", "The time left", nil, "barTime")
		p.showHead = UI.OptionHeading(stack.inner, "When it shows")
		p.showWhen = Row("select", "Show it", V.SHOW, "showWhen")
		p.alpha = Row("select", "Opacity", V.ALPHAS, "alpha")
		p.ooc = Row("select", "Out of combat", V.OOC, "oocAlpha",
			{ "Out of combat", "Its opacity out of combat, as a share of the opacity above: fade it, or hide it, while you're not fighting." })
		p.picker = PickerRow(stack.inner)
		local modeGet, modeSet = BlizzField("mode")
		local bGapGet, bGapSet = BlizzField("gap")
		local bGrowGet, bGrowSet = BlizzField("grow")
		local bVertGet, bVertSet = BlizzField("vertical")
		local bPerGet, bPerSet = BlizzField("perRow")
		p.blizzHead = UI.OptionHeading(stack.inner, "Blizzard's own")
		p.blizzMode = UI.OptionSelect(stack.inner, "What happens to them", ns.Hosted.MODES, modeGet, modeSet,
			{ boxWidth = 190, tooltip = { "Blizzard's icons and timer bars", "Take them into Lecdm: they sit in Lecdm's place, laid out your way, gaps closed. Hide them: invisible (they keep running, so Lecdm still hears them). Leave them: where and how Blizzard shows them." } })
		p.blizzGap = UI.OptionSelect(stack.inner, "Space between", Numbers(0, 12, 1), bGapGet, bGapSet)
		p.blizzGrow = UI.OptionSelect(stack.inner, "Grow from", GROW, bGrowGet, bGrowSet)
		p.blizzVertical = UI.OptionCheck(stack.inner, "Vertical", bVertGet, bVertSet)
		p.blizzPerRow = UI.OptionSelect(stack.inner, "Icons per row", Numbers(1, 20, 1), bPerGet, bPerSet)
		local bShowGet, bShowSet = BlizzField("showWhen")
		local bAlphaGet, bAlphaSet = BlizzField("alpha")
		local bOocGet, bOocSet = BlizzField("oocAlpha")
		p.blizzShow = UI.OptionSelect(stack.inner, "Show them", ns.Visibility.SHOW, bShowGet, bShowSet)
		p.blizzAlpha = UI.OptionSelect(stack.inner, "Opacity", ns.Visibility.ALPHAS, bAlphaGet, bAlphaSet)
		p.blizzOoc = UI.OptionSelect(stack.inner, "Out of combat", ns.Visibility.OOC, bOocGet, bOocSet)
		p.blizzNote = UI.OptionText(stack.inner, function()
			local kind = CurrentKind()
			local section = kind and kind.key == "bars" and "Tracked Bars" or "Tracked Buffs"
			return "Which buffs and debuffs show here, and their order: Blizzard's Cooldown Manager (/cdm), its Buffs tab, "
				.. section .. ". Your debuffs on the target (Sunder Armor, Thunder Clap ...) can only be timed by Blizzard, so they're picked there. Their size: Edit Mode."
		end, 44)
		p.blizzOpen = UI.OptionButton(stack.inner, "", "Open /cdm", function() ns.Hosted.OpenBlizzard() end)
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
		local kind, group = CurrentKind(), Current()
		if kind then
			stack:Add(p.blizzHead)
			stack:Add(p.blizzMode)
			if ns.Hosted.Settings(kind.key).mode == "take" then
				stack:Add(p.blizzGap)
				stack:Add(p.blizzGrow)
				if kind.key == "icons" then
					stack:Add(p.blizzVertical)
					stack:Add(p.blizzPerRow)
				end
				stack:Add(p.blizzShow)
				stack:Add(p.blizzAlpha)
				stack:Add(p.blizzOoc)
			end
			stack:Add(p.blizzNote)
			stack:Add(p.blizzOpen)
		elseif group then
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
			stack:Add(p.lookHead)
			stack:Add(p.border)
			stack:Add(p.borderColor)
			stack:Add(p.zoom)
			if bars then
				for _, row in ipairs({ p.barTexture, p.barColor, p.barBg, p.barIcon, p.barName, p.barTime }) do stack:Add(row) end
			end
			stack:Add(p.timeText)
			stack:Add(p.showHead)
			stack:Add(p.showWhen)
			stack:Add(p.alpha)
			stack:Add(p.ooc)
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
