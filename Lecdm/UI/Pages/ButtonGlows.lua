-- Lecdm: the Button glows tab: glows on your action buttons (any bar addon's), by rule. Each
-- rule is a row: the spell, when it glows; its ⚙ menu sets the condition and the glow.
local _, ns = ...
local UI = ns.UI
local G = ns.ButtonGlows

local GOLD = "|cffffd100"

local function SpellIcon(name)
	local itemID = tostring(name):match("^item:(%d+)$")
	if itemID then
		local ok, icon = pcall(C_Item.GetItemIconByID, tonumber(itemID))
		return ok and icon or 134400
	end
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	return ok and type(info) == "table" and info.iconID or 134400
end

local function Label(name)
	local itemID = tostring(name):match("^item:(%d+)$")
	if itemID and ns.Bars then return ns.Bars.EntryName(name) end
	return tostring(name)
end

-- What a rule says, in words.
local function Describe(rule)
	local text = ns.Alerts.Label(G.WHEN, rule.when)
	if rule.when == "buffUp" or rule.when == "buffMissing" or rule.when == "stacks" then
		text = text .. ": " .. (rule.buff or "|cffff6060(pick a buff)|r")
		if rule.when == "stacks" then text = text .. ", " .. ns.Alerts.Label(ns.Auras.STACK_OPS, rule.op):lower() .. " " .. tostring(rule.count) end
	elseif G.Kind(rule) == "health" then
		text = text .. " " .. tostring(rule.pct) .. "%"
	elseif rule.when == "swing" then
		text = text .. ": " .. tostring(rule.seconds) .. " s before it"
	end
	if rule.combat then text = text .. ", in combat" end
	return text
end

StaticPopupDialogs.LECDM_GLOW_SPELL = {
	text = "A spell's name as it shows on your action button (Execute), or an item (item:13446):",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 48,
	OnShow = function(dialog)
		local box = dialog:GetEditBox()
		box:SetText("")
		box:SetFocus()
	end,
	OnAccept = function(dialog, data)
		local text = strtrim(dialog:GetEditBox():GetText() or "")
		if text ~= "" then data.done(text) end
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

-- The new-rule picker: the spells and items on your action buttons, or one by name.
local function BuildNewMenu(_, root)
	for _, name in ipairs(ns.Keybinds.Names()) do
		root:CreateButton("|T" .. SpellIcon(name) .. ":16:16|t " .. Label(name), function()
			G.New(name)
			ns.Window.Refresh()
		end)
	end
	if #ns.Keybinds.Names() == 0 then root:CreateTitle("No spells on your action buttons yet") end
	root:CreateDivider()
	root:CreateButton("By name...", function()
		StaticPopup_Show("LECDM_GLOW_SPELL", nil, nil, { done = function(text)
			G.New(text)
			ns.Window.Refresh()
		end })
	end)
end

-- A rule's ⚙ menu.
local function RuleMenu(rule, root)
	root:CreateTitle(Label(rule.spell))
	local function Radio(sub, list, field)
		for _, v in ipairs(list) do
			sub:CreateRadio(v[2], function() return rule[field] == v[1] end, function()
				G.Set(rule, field, v[1])
				ns.Window.Refresh()
			end)
		end
	end
	Radio(root:CreateButton("When it glows"), G.WHEN, "when")
	if G.Kind(rule) == "aura" then
		local buffs = root:CreateButton("The buff")
		local seen = {}
		for _, group in ipairs(ns.db.buffs.list) do
			for _, name in ipairs(group.entries) do
				if not seen[name] then
					seen[name] = true
					buffs:CreateRadio(name, function() return rule.buff == name end, function()
						G.Set(rule, "buff", name)
						ns.Window.Refresh()
					end)
				end
			end
		end
		buffs:CreateButton("Another, by name...", function()
			StaticPopup_Show("LECDM_GLOW_SPELL", nil, nil, { done = function(text)
				G.Set(rule, "buff", text)
				ns.Window.Refresh()
			end })
		end)
		if rule.when == "stacks" then
			Radio(root:CreateButton("...when the stacks are"), ns.Auras.STACK_OPS, "op")
			Radio(root:CreateButton("...this many"), ns.Auras.STACK_COUNTS, "count")
		end
	elseif G.Kind(rule) == "health" then
		Radio(root:CreateButton("The health"), G.PCTS, "pct")
	elseif rule.when == "swing" then
		Radio(root:CreateButton("How long before the swing"), G.SECONDS, "seconds")
	end
	Radio(root:CreateButton("Only in combat"), { { true, "Yes" }, { false, "No" } }, "combat")
	Radio(root:CreateButton("Glow"), ns.Glow.STYLES, "glow")
	Radio(root:CreateButton("Glow colour"), ns.Glow.COLORS, "color")
end

local function RuleRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(32)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetPoint("RIGHT", -70, 0)
	row.label:SetJustifyH("LEFT")
	row.gear = CreateFrame("Button", nil, row)
	row.gear:SetSize(20, 20)
	row.gear:SetPoint("RIGHT", -40, 0)
	row.gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	row.gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	row.gear:SetScript("OnClick", function(self)
		local rule = G.Rules()[row.index]
		if rule then MenuUtil.CreateContextMenu(self, function(_, root) RuleMenu(rule, root) end) end
	end)
	row.remove = CreateFrame("Button", nil, row)
	row.remove:SetSize(22, 22)
	row.remove:SetPoint("RIGHT", -12, 0)
	row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	row.remove:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	row.remove:SetScript("OnClick", function()
		G.Delete(row.index)
		ns.Window.Refresh()
	end)
	row.Sync = function()
		local rule = G.Rules()[row.index]
		row.label:SetText(rule and ("|T" .. SpellIcon(rule.spell) .. ":20:20|t " .. GOLD .. Label(rule.spell) .. "|r glows " .. Describe(rule):lower()) or "")
	end
	return row
end

local function NewRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("A new glow")
	row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	row.dropdown:SetPoint("LEFT", 330, 0)
	row.dropdown:SetSize(150, 24)
	row.dropdown:SetupMenu(BuildNewMenu)
	row.Sync = function() row.dropdown:SetText("For...") end
	return row
end

ns.Window.Page({
	id = "buttons",
	label = "Button glows",
	order = 4.5,
	note = "Glows on your action buttons, any bar addon's: pick a spell on them, then when it glows (its ⚙): while it's usable, while a buff is up or missing, at a number of stacks, while the target's or your health is under or over a mark, late in a swing.",
	fill = function(stack, panel)
		local p = { rows = {} }
		panel.parts = p
		p.head = UI.OptionHeading(stack.inner, "Glows on your action buttons")
		p.new = NewRow(stack.inner)
		p.empty = UI.OptionText(stack.inner, "None yet: pick a spell in \"A new glow\".", 24)
		p.note = UI.OptionText(stack.inner,
			"The glow is Lecdm's, laid over the button. Glows that follow a buff are set out of combat: a change in a fight, or a button changing in one, waits for its end.", 40)
	end,
	refresh = function(panel)
		local p, stack = panel.parts, panel.stack
		stack:Reset()
		stack:Add(p.head)
		stack:Add(p.new)
		for i in ipairs(G.Rules()) do
			local row = p.rows[i]
			if not row then
				row = RuleRow(stack.inner)
				p.rows[i] = row
			end
			row.index = i
			stack:Add(row)
		end
		if #G.Rules() == 0 then stack:Add(p.empty) end
		stack:Add(p.note)
		stack:Done()
		stack:Sync()
	end,
})
