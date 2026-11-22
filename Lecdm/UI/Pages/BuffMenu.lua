-- Lecdm: a buff's right-click menu (tick boxes and choices in three parts: while it's up, fading,
-- while it's missing), the preview of a buff group's buffs, and three samples of the buff picked,
-- drawn with its look. The menu kit (ns.MenuKit) is shared with the icon bars' menu.
local _, ns = ...
local Auras = ns.Auras

local K = {}
ns.MenuKit = K

-- A radio that leaves the menu open (so the samples can be watched as choices change).
local function Radio(menu, text, isSelected, setSelected)
	local r = menu:CreateRadio(text, isSelected, setSelected)
	if r and r.SetResponse and MenuResponse then r:SetResponse(MenuResponse.Refresh) end
	return r
end
K.Radio = Radio

-- A setting with a getter and a setter: get() / set(value).
function K.Check(menu, text, get, set)
	return menu:CreateCheckbox(text, function() return get() == true end, function() set(not get()) end)
end

function K.Choice(menu, label, list, get, set)
	local sub = menu:CreateButton(label .. ": " .. ns.Alerts.Label(list, get()))
	for _, v in ipairs(list) do
		Radio(sub, v[2], function() return get() == v[1] end, function() set(v[1]) end)
	end
	return sub
end

-- A glow: its style, and its colour in a submenu at the end.
function K.Glow(menu, label, getStyle, setStyle, getColor, setColor)
	local sub = menu:CreateButton(label .. ": " .. ns.Alerts.Label(ns.Glow.STYLES, getStyle()))
	for _, v in ipairs(ns.Glow.STYLES) do
		Radio(sub, v[2], function() return getStyle() == v[1] end, function() setStyle(v[1]) end)
	end
	if getColor then K.Choice(sub, "Colour", ns.Glow.COLORS, getColor, setColor) end
	return sub
end

-- A sound: the game's, then Blizzard's Cooldown Manager's by group; picking one plays it.
function K.Sound(menu, label, get, set, words)
	local A = ns.Alerts
	A.AddBlizzardSounds()
	local sub = menu:CreateButton(label .. ": " .. A.Label(A.SOUNDS, get()))
	local function Pick(value)
		set(value)
		A.Play(value, words)
	end
	for i = 1, A.BASE_SOUNDS do
		local v = A.SOUNDS[i]
		Radio(sub, v[2], function() return get() == v[1] end, function() Pick(v[1]) end)
	end
	for _, group in ipairs(A.SOUND_GROUPS) do
		local g = sub:CreateButton(group[1])
		for _, v in ipairs(group[2]) do
			Radio(g, v[2], function() return get() == v[1] end, function() Pick(v[1]) end)
		end
	end
	return sub
end

-- A spell's or buff's alert setting: get the effective value, set its own (nil when it's the
-- default's).
function K.Field(category, key, field)
	local A = ns.Alerts
	return function() return A.Get(category, key, field) end, function(v)
		if v == ns.db.alerts.defaults[category][field] then v = nil end
		A.Set(category, key, field, v)
	end
end

-- "Use these for every buff": its own settings become the defaults (and it has none of its own).
function K.MakeDefault(category, key)
	local own = ns.db.alerts[category][key]
	if not own then return end
	for field, value in pairs(own) do ns.db.alerts.defaults[category][field] = value end
	ns.db.alerts[category][key] = nil
	ns.Refresh()
end

function K.Clear(category, key)
	ns.db.alerts[category][key] = nil
	ns.Refresh()
end

-- The buff menu -------------------------------------------------------------------------------

function ns.BuffMenu(group, name, root)
	local function F(field) return K.Field("buffs", name, field) end
	root:CreateTitle(name)

	root:CreateTitle("While it's up")
	K.Check(root, "Grey", F("upGrey"))
	K.Choice(root, "Opacity", ns.Alerts.UP_ALPHAS, F("upAlpha"))
	local gs, ss = F("upGlow")
	local gc, sc = F("glowColor")
	K.Glow(root, "Glow", gs, ss, gc, sc)
	local ag, as = F("applied")
	K.Sound(root, "Sound as it comes", ag, as, name)

	root:CreateDivider()
	root:CreateTitle("Fading")
	K.Choice(root, "From", ns.Alerts.WARNS, F("warn"))
	K.Check(root, "Back to full colour", F("reveal"))
	K.Check(root, "The time turns red", F("warnRed"))
	local ws, wss = F("warnGlow")
	K.Glow(root, "Glow", ws, wss, gc, sc)
	local rg, rs = F("runningOut")
	K.Sound(root, "Sound", rg, rs, name)

	root:CreateDivider()
	root:CreateTitle("While it's missing")
	K.Check(root, "Show it while it's missing", function() return Auras.Mode(group, name) ~= "up" end, function(v)
		Auras.SetMode(group, name, v and "keep" or "up")
	end)
	K.Choice(root, "Looks", Auras.MISSING_LOOKS, F("missingLook"))
	K.Choice(root, "Opacity", ns.Alerts.ALPHAS, F("missingAlpha"))
	local ms, mss = F("missingGlow")
	local mc, msc = F("missingColor")
	K.Glow(root, "Glow", ms, mss, mc, msc)
	local dg, ds = F("removed")
	K.Sound(root, "Sound as it drops", dg, ds, name)
	local cg, cs = F("combatMissing")
	K.Sound(root, "Sound entering combat without it", cg, cs, name)
	K.Check(root, "Say so in chat then", F("combatChat"))

	root:CreateDivider()
	K.Check(root, "Its name on screen with its sounds", F("screen"))
	local more = root:CreateButton("More")
	local sg, ssg = F("stackGlow")
	K.Glow(more, "Glow at a number of stacks", sg, ssg, gc, sc)
	K.Choice(more, "...when the stacks are", Auras.STACK_OPS, F("stackOp"))
	K.Choice(more, "...this many", Auras.STACK_COUNTS, F("stackCount"))
	K.Choice(more, "How it shows", Auras.MODES, function() return Auras.Mode(group, name) end,
		function(v) Auras.SetMode(group, name, v) end)
	if ns.BuffLooks then ns.BuffLooks(more, name) end

	root:CreateDivider()
	root:CreateButton("Use these for every buff", function() K.MakeDefault("buffs", name) end)
	root:CreateButton("Back to the defaults", function() K.Clear("buffs", name) end)
	root:CreateButton("Take it out of this group", function() Auras.SetInGroup(group, name, false) end)
end

-- Samples -------------------------------------------------------------------------------------

local SAMPLE = 40

local function Sample(parent, label)
	local s = CreateFrame("Button", nil, parent)
	s:SetSize(SAMPLE, SAMPLE)
	s.edge = s:CreateTexture(nil, "BACKGROUND")
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetAllPoints()
	s.top = CreateFrame("Frame", nil, s)
	s.top:SetAllPoints()
	s.top:SetFrameLevel(s:GetFrameLevel() + 4)
	s.time = s.top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	s.time:SetPoint("BOTTOM", 0, 1)
	s.note = s.top:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	s.note:SetPoint("CENTER")
	s.glow = CreateFrame("Frame", nil, s)
	s.glow:SetAllPoints()
	s.glow:SetFrameLevel(s:GetFrameLevel() + 2)
	s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	s.label:SetPoint("TOP", s, "BOTTOM", 0, -4)
	s.label:SetText(label)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return s
end

local TIME_RGB = { white = { 1, 1, 1 }, gold = { 1, 0.82, 0 }, yellow = { 1, 1, 0.3 }, green = { 0.4, 1, 0.4 }, blue = { 0.45, 0.75, 1 } }

-- Draws a sample of a buff in a state ("up", "fading", "missing") with its look now.
function K.DrawBuff(s, group, name, state)
	local function Get(field) return ns.Alerts.Get("buffs", name, field) end
	local own = Auras.Own(group, name)
	local z = group.zoom or 0.08
	local n = own.border or group.border or 1
	local er, eg, eb = ns.Bars.BorderRGB(own.borderColor or group.borderColor)
	s.icon:SetTexture(Auras.Icon(name))
	s.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	s.icon:SetVertexColor(1, 1, 1)
	s.icon:Show()
	s.edge:ClearAllPoints()
	s.edge:SetPoint("TOPLEFT", -n, n)
	s.edge:SetPoint("BOTTOMRIGHT", n, -n)
	s.edge:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
	s.note:SetText("")
	local trgb = TIME_RGB[own.timeColor or "white"] or TIME_RGB.white
	s.time:SetTextColor(trgb[1], trgb[2], trgb[3])
	local alpha, grey = Get("upAlpha") or 1, Get("upGrey") and true or false
	local warn = ns.Alerts.Warn(name)
	local glow, color = "none", Get("glowColor")
	if state == "up" then
		s.icon:SetDesaturated(grey)
		s:SetAlpha(alpha > 0 and alpha or 0.15)
		if alpha == 0 then s.note:SetText("hidden") end
		s.time:SetText("2m")
		glow = Get("upGlow")
	elseif state == "fading" then
		local back = (alpha < 1 or grey) and Get("reveal") ~= false and warn > 0
		s.icon:SetDesaturated(grey and not back)
		s:SetAlpha(back and 1 or (alpha > 0 and alpha or 0.15))
		s.time:SetText(warn > 0 and tostring(math.max(1, math.min(warn - 1, 4))) or "4")
		if warn > 0 and Get("warnRed") ~= false then s.time:SetTextColor(1, 0.25, 0.25) end
		if warn == 0 then s.note:SetText("no warning") end
		glow = Get("warnGlow") ~= "none" and Get("warnGlow") or Get("upGlow")
	else
		s.time:SetText("")
		if Auras.Mode(group, name) == "up" then
			s.icon:Hide()
			s:SetAlpha(1)
			s.edge:SetColorTexture(0.3, 0.3, 0.3, 0.6)
			s.note:SetText("not shown")
		else
			local look = Get("missingLook") or "red"
			local malpha = Get("missingAlpha") or 1
			s.icon:SetDesaturated(look ~= "normal")
			if look == "red" then
				s.icon:SetVertexColor(1, 0.4, 0.4)
				s.edge:SetColorTexture(0.7, 0, 0, 1)
				s:SetAlpha(0.85 * malpha)
			else
				s:SetAlpha(malpha)
			end
			glow, color = Get("missingGlow"), Get("missingColor")
		end
	end
	if group.shape and group.shape ~= "square" then
		ns.Bars.Shape(s, s.icon, nil, s.edge, s.top, group.shape, n, er, eg, eb)
	else
		ns.Bars.Shape(s, s.icon, nil, s.edge, s.top, "square", n, er, eg, eb)
	end
	ns.Glow.Show(s.glow, glow or "none", color, SAMPLE)
end

-- The three samples of the buff picked, and what to do with them.
function ns.BuffSamplesRow(parent, getGroup, getPicked)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(SAMPLE + 40)
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.title:SetPoint("TOPLEFT", 16, -2)
	row.samples = {}
	for i, def in ipairs({ { "up", "While up" }, { "fading", "Fading" }, { "missing", "Missing" } }) do
		local s = Sample(row, def[2])
		s:SetPoint("TOPLEFT", 330 + (i - 1) * 70, -4)
		s.state = def[1]
		s:SetScript("OnClick", function(self)
			local group, name = getGroup(), getPicked()
			if group and name then
				MenuUtil.CreateContextMenu(self, function(_, root) ns.BuffMenu(group, name, root) end)
			end
		end)
		row.samples[i] = s
	end
	row.Sync = function()
		local group, name = getGroup(), getPicked()
		row.title:SetText(name and (name .. "\n|cffbbbbbbright-click it for its settings|r") or "")
		for _, s in ipairs(row.samples) do
			s:SetShown(name ~= nil)
			if group and name then K.DrawBuff(s, group, name, s.state) end
		end
	end
	return row
end

-- The preview: a group's buffs as icons in their order. Click one for its samples; right-click
-- for its menu; drag one onto another to move it there.
local PREVIEW = 30
function ns.BuffPreviewRow(parent, getGroup, getPicked, setPicked)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(PREVIEW + 12)
	row.icons = {}
	local ghost = CreateFrame("Frame", nil, UIParent)
	ghost:SetSize(PREVIEW, PREVIEW)
	ghost:SetFrameStrata("TOOLTIP")
	ghost.tex = ghost:CreateTexture(nil, "ARTWORK")
	ghost.tex:SetAllPoints()
	ghost:SetAlpha(0.8)
	ghost:Hide()
	ghost:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end)
	local function Icon(i)
		local icon = row.icons[i]
		if icon then return icon end
		icon = CreateFrame("Button", nil, row)
		icon:SetSize(PREVIEW, PREVIEW)
		icon.pick = icon:CreateTexture(nil, "BACKGROUND")
		icon.pick:SetPoint("TOPLEFT", -2, 2)
		icon.pick:SetPoint("BOTTOMRIGHT", 2, -2)
		icon.pick:SetColorTexture(1, 0.82, 0, 1)
		icon.tex = icon:CreateTexture(nil, "ARTWORK")
		icon.tex:SetAllPoints()
		icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		icon:RegisterForDrag("LeftButton")
		icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		icon:SetScript("OnDragStart", function(self)
			row.dragging = self.index
			ghost.tex:SetTexture(self.tex:GetTexture())
			ghost:Show()
		end)
		icon:SetScript("OnDragStop", function()
			ghost:Hide()
			local from = row.dragging
			row.dragging = nil
			local group = getGroup()
			if not (from and group) then return end
			for j, other in ipairs(row.icons) do
				if other:IsShown() and MouseIsOver(other) and j ~= from then
					Auras.MoveTo(group, from, j)
					return
				end
			end
		end)
		icon:SetScript("OnClick", function(self, button)
			local group = getGroup()
			if not (group and self.name) then return end
			if button == "RightButton" then
				local name = self.name
				MenuUtil.CreateContextMenu(self, function(_, root) ns.BuffMenu(group, name, root) end)
			else
				setPicked(self.name)
			end
		end)
		icon:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.name or "")
			GameTooltip:AddLine("Click: its samples. Right-click: its settings. Drag it onto another to move it.", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		icon:SetScript("OnLeave", GameTooltip_Hide)
		row.icons[i] = icon
		return icon
	end
	function row:Fill(group)
		local width = row:GetWidth()
		if not width or width < 100 then width = 500 end
		local per = math.max(1, math.floor((width - 32) / (PREVIEW + 6)))
		local picked = getPicked()
		for i, name in ipairs(group.entries) do
			local icon = Icon(i)
			icon.index, icon.name = i, name
			icon.tex:SetTexture(Auras.Icon(name))
			icon.pick:SetShown(name == picked)
			local line, pos = math.floor((i - 1) / per), (i - 1) % per
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", 16 + pos * (PREVIEW + 6), -(6 + line * (PREVIEW + 6)))
			icon:Show()
		end
		for i = #group.entries + 1, #row.icons do row.icons[i]:Hide() end
		row:SetHeight(12 + math.max(1, math.ceil(#group.entries / per)) * (PREVIEW + 6))
	end
	row.Sync = function() end
	return row
end
