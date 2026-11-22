-- Lecdm: a spell's right-click menu on the Icon bars tab (tick boxes and choices in three parts:
-- ready, on cooldown, when the game highlights it), and three samples of the spell picked drawn
-- with its look. Built from ns.MenuKit (BuffMenu.lua).
local _, ns = ...
local Bars = ns.Bars

-- A setting of a spell's own look on its bar (grey, cdAlpha...): the bar's unless it has its own.
local function Look(bar, key, field)
	return function()
		local v = Bars.Own(bar, key)[field]
		if v == nil then v = bar[field] end
		return v
	end, function(v)
		if v == bar[field] then v = nil end
		Bars.SetLook(bar, key, field, v)
	end
end

function ns.SpellMenu(bar, key, root)
	local K = ns.MenuKit
	local words = Bars.EntryName(key)
	local function F(field) return K.Field("spells", key, field) end
	root:CreateTitle(words)

	root:CreateTitle("Ready")
	local rg, rs = F("ready")
	K.Sound(root, "Sound as it's ready", rg, rs, words)
	local gs, ss = F("readyGlow")
	local gc, sc = F("glowColor")
	K.Glow(root, "Glow while it's ready", gs, ss, gc, sc)

	root:CreateDivider()
	root:CreateTitle("On cooldown")
	K.Check(root, "Grey", Look(bar, key, "grey"))
	K.Choice(root, "Opacity", ns.Alerts.ALPHAS, Look(bar, key, "cdAlpha"))
	local cs, css = F("cdGlow")
	K.Glow(root, "Glow", cs, css, gc, sc)

	root:CreateDivider()
	root:CreateTitle("When the game highlights it (a proc)")
	local ps, pss = F("procGlow")
	K.Glow(root, "Glow", ps, pss, gc, sc)

	root:CreateDivider()
	K.Choice(root, "Show it", Bars.SHOW, function() return bar.show[key] or "always" end, function(v)
		bar.show[key] = v ~= "always" and v or nil
		ns.Refresh()
	end)
	K.Check(root, "Its name on screen with its sounds", F("screen"))
	local more = root:CreateButton("More")
	local fs, fss = F("fullGlow")
	K.Glow(more, "Glow at full charges", fs, fss, gc, sc)
	local fg, fset = F("fullSound")
	K.Sound(more, "Sound back to full charges", fg, fset, words)
	local as, ass = F("activeGlow")
	K.Glow(more, "Glow while its buff is up (shown on it)", as, ass, gc, sc)
	if ns.SpellConditions then ns.SpellConditions(more, key) end

	root:CreateDivider()
	root:CreateButton("Use these for every spell", function() K.MakeDefault("spells", key) end)
	root:CreateButton("Back to the defaults", function() K.Clear("spells", key) end)
	root:CreateButton("Take it off this bar", function() Bars.SetOnBar(bar, key, false) end)
end

-- Samples ---------------------------------------------------------------------------------------

local SAMPLE = 40

local function Sample(parent, label)
	local s = CreateFrame("Button", nil, parent)
	s:SetSize(SAMPLE, SAMPLE)
	s.edge = s:CreateTexture(nil, "BACKGROUND")
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetAllPoints()
	s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
	s.cd:SetAllPoints()
	s.cd:SetHideCountdownNumbers(true)
	s.top = CreateFrame("Frame", nil, s)
	s.top:SetAllPoints()
	s.top:SetFrameLevel(s.cd:GetFrameLevel() + 3)
	s.time = s.top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	s.time:SetPoint("CENTER")
	s.glow = CreateFrame("Frame", nil, s)
	s.glow:SetAllPoints()
	s.glow:SetFrameLevel(s.cd:GetFrameLevel() + 2)
	s.label = s:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	s.label:SetPoint("TOP", s, "BOTTOM", 0, -4)
	s.label:SetText(label)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return s
end

function ns.MenuKit.DrawSpell(s, bar, key, state)
	local own = Bars.Own(bar, key)
	local z = bar.zoom or 0.08
	local n = own.border or bar.border or 1
	local er, eg, eb = Bars.BorderRGB(own.borderColor or bar.borderColor)
	s.icon:SetTexture(own.icon or Bars.EntryIcon(key))
	s.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	s.edge:ClearAllPoints()
	s.edge:SetPoint("TOPLEFT", -n, n)
	s.edge:SetPoint("BOTTOMRIGHT", n, -n)
	s.edge:SetColorTexture(er, eg, eb, n > 0 and 1 or 0)
	Bars.Shape(s, s.icon, s.cd, s.edge, s.top, bar.style ~= "bars" and bar.shape or "square", n, er, eg, eb)
	local glow, color = "none", ns.Alerts.Get("spells", key, "glowColor")
	s.time:SetText("")
	if state == "cooldown" then
		local grey = own.grey
		if grey == nil then grey = bar.grey end
		s.icon:SetDesaturated(grey and true or false)
		s:SetAlpha(own.cdAlpha or bar.cdAlpha or 1)
		s.cd:SetDrawSwipe(bar.swipe ~= "off")
		s.cd:SetReverse(bar.swipe == "reverse")
		s.cd:SetSwipeColor(Bars.SwipeRGBA(bar.swipeColor))
		s.cd:SetCooldown(GetTime() - 10, 40)
		if Bars.FONTS[bar.countdown] then s.time:SetText("30") end
		glow = ns.Alerts.Get("spells", key, "cdGlow")
	else
		s.icon:SetDesaturated(false)
		s:SetAlpha(1)
		s.cd:Clear()
		glow = ns.Alerts.Get("spells", key, state == "proc" and "procGlow" or "readyGlow")
	end
	ns.Glow.Show(s.glow, glow or "none", color, SAMPLE)
end

-- The three samples of the spell picked (getBar, getPicked: the bar shown, the key picked).
function ns.SpellSamplesRow(parent, getBar, getPicked)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(SAMPLE + 40)
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.title:SetPoint("TOPLEFT", 16, -2)
	row.samples = {}
	for i, def in ipairs({ { "ready", "Ready" }, { "cooldown", "On cooldown" }, { "proc", "Proc" } }) do
		local s = Sample(row, def[2])
		s:SetPoint("TOPLEFT", 330 + (i - 1) * 76, -4)
		s.state = def[1]
		s:SetScript("OnClick", function(self)
			local bar, key = getBar(), getPicked()
			if bar and key then
				MenuUtil.CreateContextMenu(self, function(_, root) ns.SpellMenu(bar, key, root) end)
			end
		end)
		row.samples[i] = s
	end
	row.Sync = function()
		local bar, key = getBar(), getPicked()
		row.title:SetText(key and (Bars.EntryName(key) .. "\n|cffbbbbbbright-click it for its settings|r") or "")
		for _, s in ipairs(row.samples) do
			s:SetShown(key ~= nil)
			if bar and key then ns.MenuKit.DrawSpell(s, bar, key, s.state) end
		end
	end
	return row
end
