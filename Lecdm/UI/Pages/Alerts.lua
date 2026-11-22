-- Lecdm: the Alerts tab (the defaults for every spell and buff) and the ⚙ menu a spell's or
-- buff's row has on the Icon bars and Buffs tabs (its own choices, "Default (...)" first).
local _, ns = ...
local UI = ns.UI
local Alerts = ns.Alerts

local YESNO = { { true, "Yes" }, { false, "No" } }

-- The settings of each kind: field, label, choices, and a heading starting a part of the list.
local FIELDS = {
	spells = {
		{ "ready", "Sound when it's ready", Alerts.SOUNDS },
		{ "screen", "Its name on screen with its sounds", YESNO },
		{ "readyGlow", "Glow while it's ready", ns.Glow.STYLES },
		{ "procGlow", "Glow while the game highlights it (a proc)", ns.Glow.STYLES },
		{ "cdGlow", "Glow while it's on cooldown", ns.Glow.STYLES },
		{ "fullGlow", "Glow at full charges (spells with charges)", ns.Glow.STYLES },
		{ "fullSound", "Sound when it's back to full charges", Alerts.SOUNDS },
		{ "activeGlow", "Glow while its buff is up (shown on it)", ns.Glow.STYLES },
		{ "glowColor", "Glow colour", ns.Glow.COLORS },
	},
	buffs = {
		{ "applied", "Sound when it's applied", Alerts.SOUNDS },
		{ "removed", "Sound when it drops", Alerts.SOUNDS },
		{ "screen", "Its name on screen with its sounds", YESNO },
		{ "runningOut", "Sound as it runs out (at the warning time)", Alerts.SOUNDS },
		{ "combatMissing", "Sound going into combat without it (keep-up buffs)", Alerts.SOUNDS },
		{ "combatChat", "Say in chat which ones are missing then", YESNO },
		{ "upGlow", "Glow while it's up", ns.Glow.STYLES },
		{ "warn", "Warning time: the time turns red under", Alerts.WARNS },
		{ "warnGlow", "Warning glow (icons, at that time)", ns.Glow.STYLES },
		{ "stackGlow", "Glow at a number of stacks", ns.Glow.STYLES },
		{ "stackOp", "...when the stacks are", ns.Auras.STACK_OPS },
		{ "stackCount", "...this many", ns.Auras.STACK_COUNTS },
		{ "glowColor", "Glow colour", ns.Glow.COLORS },
		{ "upGrey", "Grey while it's up", YESNO, "Buff groups: how a buff looks" },
		{ "upAlpha", "Opacity while it's up", Alerts.UP_ALPHAS },
		{ "reveal", "Back to full colour as it fades", YESNO },
		{ "warnRed", "The time turns red as it fades", YESNO },
		{ "missingLook", "Look while it's missing (keep-up buffs)", ns.Auras.MISSING_LOOKS },
		{ "missingAlpha", "Opacity while it's missing", Alerts.ALPHAS },
		{ "missingGlow", "Glow while it's missing", ns.Glow.STYLES },
		{ "missingColor", "Missing glow colour", ns.Glow.COLORS },
	},
	blizzard = {
		{ "applied", "Sound when it's applied", Alerts.SOUNDS },
		{ "removed", "Sound when it drops", Alerts.SOUNDS },
		{ "screen", "Its name on screen with its sounds", YESNO },
		{ "deaths", "Also when your target dies", YESNO },
	},
}
ns.ALERT_FIELDS = FIELDS

-- A spell's or buff's own choices, as a menu: a submenu per setting, "Default (...)" first;
-- extra(root): the row's own entries after them (an icon bar's conditions).
function ns.AlertsMenu(category, key, words, root, extra)
	root:CreateTitle(words or tostring(key))
	for _, f in ipairs(FIELDS[category]) do
		local field, label, list = f[1], f[2], f[3]
		if f[4] then root:CreateDivider() end
		local sub = root:CreateButton(label)
		local default = ns.db.alerts.defaults[category][field]
		if list == Alerts.SOUNDS then Alerts.AddBlizzardSounds() end
		sub:CreateRadio("Default (" .. Alerts.Label(list, default) .. ")",
			function()
				local own = ns.db.alerts[category][key]
				return not (own and own[field] ~= nil)
			end,
			function() Alerts.Set(category, key, field, nil) end)
		local function Radio(menu, value, text)
			menu:CreateRadio(text,
				function()
					local own = ns.db.alerts[category][key]
					return own ~= nil and own[field] == value
				end,
				function()
					Alerts.Set(category, key, field, value)
					if list == Alerts.SOUNDS then Alerts.Play(value, words) end
				end)
		end
		local plain = list == Alerts.SOUNDS and Alerts.BASE_SOUNDS or #list
		for i = 1, plain do Radio(sub, list[i][1], list[i][2]) end
		if list == Alerts.SOUNDS then
			for _, group in ipairs(Alerts.SOUND_GROUPS) do
				local g = sub:CreateButton(group[1])
				for _, v in ipairs(group[2]) do Radio(g, v[1], v[2]) end
			end
		end
	end
	if extra then
		root:CreateDivider()
		extra(root)
	end
end

-- The ⚙ button for a row: its spell's or buff's own alerts.
function ns.AlertsGear(row, x, category, getKey, getWords, extra)
	local gear = CreateFrame("Button", nil, row)
	gear:SetSize(20, 20)
	gear:SetPoint("LEFT", x, 0)
	gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	gear:SetScript("OnClick", function(self)
		local key = getKey()
		if key == nil then return end
		MenuUtil.CreateContextMenu(self, function(_, root) ns.AlertsMenu(category, key, getWords(), root, extra) end)
	end)
	gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Alerts for " .. tostring(getWords()))
		GameTooltip:AddLine("Its own sounds, glows and looks; anything left on Default follows the Alerts tab.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", GameTooltip_Hide)
	return gear
end

-- A glow row's sample: an icon showing the glow picked, in its colour.
local SAMPLE_ICON = { spells = 132337, buffs = 132333 } -- Charge, Battle Shout
local function Sample(row, category, field)
	local f = CreateFrame("Frame", nil, row)
	f:SetSize(22, 22)
	f:SetPoint("LEFT", row.right + 10, 0)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetTexture(SAMPLE_ICON[category])
	f.glow = CreateFrame("Frame", nil, f)
	f.glow:SetAllPoints()
	f.glow:SetFrameLevel(f:GetFrameLevel() + 2)
	row.sample = f
	local sync = row.Sync
	row.Sync = function(...)
		sync(...)
		local d = ns.db.alerts.defaults[category]
		ns.Glow.Show(f.glow, d[field], d[field == "missingGlow" and "missingColor" or "glowColor"], 22)
	end
end

-- A sound default's row: a dropdown (the game's sounds, then Blizzard's Cooldown Manager's by
-- group) and a Test button.
function ns.SoundPicker(parent, label, get, set)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetPoint("RIGHT", row, "LEFT", 320, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetText(label)
	row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	row.dropdown:SetPoint("LEFT", 330, 0)
	row.dropdown:SetSize(170, 24)
	local function Pick(value)
		set(value)
		Alerts.Play(value, "Battle Shout")
		ns.Refresh()
		row.Sync()
	end
	row.dropdown:SetupMenu(function(_, root)
		Alerts.AddBlizzardSounds()
		local function Radio(menu, value, text)
			menu:CreateRadio(text, function() return get() == value end, function() Pick(value) end)
		end
		for i = 1, Alerts.BASE_SOUNDS do Radio(root, Alerts.SOUNDS[i][1], Alerts.SOUNDS[i][2]) end
		for _, group in ipairs(Alerts.SOUND_GROUPS) do
			local g = root:CreateButton(group[1])
			for _, v in ipairs(group[2]) do Radio(g, v[1], v[2]) end
		end
	end)
	local test = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	test:SetSize(54, 22)
	test:SetPoint("LEFT", row.dropdown, "RIGHT", 6, 0)
	test:SetText("Test")
	test:SetScript("OnClick", function() Alerts.Play(get(), "Battle Shout") end)
	row.Sync = function()
		Alerts.AddBlizzardSounds()
		row.dropdown:SetText(Alerts.Label(Alerts.SOUNDS, get()))
	end
	return row
end

local function SoundRow(parent, category, field, label)
	return ns.SoundPicker(parent, label,
		function() return ns.db.alerts.defaults[category][field] end,
		function(v) ns.db.alerts.defaults[category][field] = v end)
end

-- A default's row: a picker, for sounds a dropdown and a Test button, for glows a sample.
local function DefaultRow(parent, category, f)
	local field, label, list = f[1], f[2], f[3]
	if list == Alerts.SOUNDS then return SoundRow(parent, category, field, label) end
	local row = UI.OptionSelect(parent, label, list,
		function() return ns.db.alerts.defaults[category][field] end,
		function(v)
			ns.db.alerts.defaults[category][field] = v
			ns.Refresh()
		end,
		{ boxWidth = 170 })
	if list == Alerts.SOUNDS then
		local test = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		test:SetSize(54, 22)
		test:SetPoint("LEFT", row.right + 4, 0)
		test:SetText("Test")
		test:SetScript("OnClick", function() Alerts.Play(ns.db.alerts.defaults[category][field], "Battle Shout") end)
	elseif list == ns.Glow.STYLES then
		Sample(row, category, field)
	end
	return row
end

ns.Window.Page({
	id = "alerts",
	label = "Alerts",
	order = 4,
	note = "The sounds, glows and looks every spell and buff gets, unless it has its own: the ⚙ next to it on the Icon bars and Buffs tabs. \"Say it\" speaks the spell's name.",
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "Icon bars: your cooldowns"))
		for _, f in ipairs(FIELDS.spells) do stack:Add(DefaultRow(stack.inner, "spells", f)) end
		stack:Add(UI.OptionText(stack.inner, "Ready: when it comes off cooldown (not the GCD). Glow while it's ready: also only while you can cast it.", 28))

		stack:Add(UI.OptionHeading(stack.inner, "Buff groups: buffs on you"))
		for _, f in ipairs(FIELDS.buffs) do
			if f[4] then
				stack:Add(UI.OptionText(stack.inner,
					"In combat the game tells an addon when a buff comes or goes only for buffs Blizzard's Cooldown Manager also tracks (/cdm, Buffs tab): track them there for in-combat sounds. Out of combat Lecdm sees every buff on you. Running out: in combat from its time when the fight started, or from your own cast; quiet in combat when someone else in your group could have recast it (your class). The warning glow and the timing from your cast need the buff's full duration, learned the first time Lecdm sees it on you out of combat.", 70))
				stack:Add(UI.OptionHeading(stack.inner, f[4]))
			end
			stack:Add(DefaultRow(stack.inner, "buffs", f))
		end
		stack:Add(UI.OptionText(stack.inner,
			"Grey or faded while it's up, so a missing one stands out: icons come back to full strength at the warning time (once Lecdm knows the buff's duration), in combat too; timer bars stay as they are. Glows always show at full strength. While it's missing: what a keep-up buff's place shows (set the buff to Keep up on the Buffs tab).", 56))

		stack:Add(UI.OptionHeading(stack.inner, "Every glow"))
		local function PixelRow(label, field, list)
			return UI.OptionSelect(stack.inner, label, list,
				function() return ns.db.alerts.pixel[field] end,
				function(v)
					ns.db.alerts.pixel[field] = v
					ns.Refresh()
				end)
		end
		stack:Add(PixelRow("Pixel glow: dashes", "lines", ns.Glow.PIXEL_LINES))
		stack:Add(PixelRow("Pixel glow: thickness", "thickness", ns.Glow.PIXEL_THICKNESS))
		stack:Add(PixelRow("Pixel glow: speed", "speed", ns.Glow.PIXEL_SPEEDS))
		stack:Add(UI.OptionCheck(stack.inner, "Glows only in combat",
			function() return ns.db.alerts.combatOnly end,
			function(v)
				ns.db.alerts.combatOnly = v
				ns.Refresh()
			end,
			{ "Only in combat", "Icon bars' glows and the missing glow show only in combat. (Glows on the game's own buff buttons can't be switched as a fight starts: they stay as set.)" }))

		stack:Add(UI.OptionHeading(stack.inner, "Blizzard's icons and timer bars"))
		for _, f in ipairs(FIELDS.blizzard) do stack:Add(DefaultRow(stack.inner, "blizzard", f)) end
		stack:Add(UI.OptionText(stack.inner, "Your debuffs on the target among them. When a mob dies every debuff on it goes at once: Lecdm stays quiet then, unless \"Also when your target dies\".", 40))
	end,
	defaults = function()
		ns.db.alerts.defaults = ns.DeepCopy(ns.DEFAULTS.alerts.defaults)
		ns.db.alerts.pixel = ns.DeepCopy(ns.DEFAULTS.alerts.pixel)
		ns.db.alerts.combatOnly = ns.DEFAULTS.alerts.combatOnly
	end,
})
