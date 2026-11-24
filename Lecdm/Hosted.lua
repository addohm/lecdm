-- Lecdm: Blizzard's icons and timer bars. Lecdm shows only what the player sets up (the owner,
-- 2026-11-21: "no need to see them, ever"), so by default Blizzard's two buff viewers (Tracked
-- Buffs: icons, Tracked Bars: timer bars) are hidden; they keep running, so Lecdm still hears
-- their announcements. For anyone who wants their debuffs on the target (only Blizzard's own
-- icons can time them), each viewer has a place on the Buffs tab. Its mode:
--   "take":  Blizzard's icons sit in Lecdm's place, laid out Lecdm's way (spacing, grow from,
--            vertical, per row), in Blizzard's order, the gaps of hidden ones closed;
--   "hide":  the default: the viewer is made invisible (it keeps running, so the listener still
--            hears it);
--   "leave": Blizzard's own place and layout.
-- Which auras, and their order, are picked in Blizzard's /cdm (the owner's choice, 2026-11-21);
-- their size is Edit Mode's. Lecdm re-places the icons after each of Blizzard's layouts
-- (RefreshLayout, Layout) and whenever one shows or hides (UpdateShownState): hooks only, never
-- a call into Blizzard's code (confirmed in game in the open world and a dungeon: the host test).
-- Timer bars taken in can wear Lecdm's look (bars.look "lecdm", the default): Lecdm's own bar
-- over each of Blizzard's, in Lecdm's place, copying what Blizzard shows each time it updates it
-- (hooks on its Refresh methods: the fill, the time, the name, the icon, the stacks; secret in
-- combat, handed on as they are), and Blizzard's viewer made invisible as in "hide" mode.
local _, ns = ...

local H = {}
ns.Hosted = H

H.KINDS = {
	{ key = "icons", global = "BuffIconCooldownViewer", name = "Blizzard's icons" },
	{ key = "bars", global = "BuffBarCooldownViewer", name = "Blizzard's timer bars" },
}
H.MODES = { { "take", "Take them into Lecdm" }, { "hide", "Hide them" }, { "leave", "Leave them as Blizzard has them" } }

local places = {}  -- kind key -> our frame
local hooked = {}  -- viewer -> true
local hookedItems = setmetatable({}, { __mode = "k" })
local placing = false

local function Number(v, fallback)
	if type(v) == "number" and not ns.IsSecret(v) then return v end
	return fallback
end
local overlays = setmetatable({}, { __mode = "k" }) -- Blizzard's bar item -> Lecdm's bar over it

-- Whether Blizzard's timer bars wear Lecdm's look now.
function H.LecdmLook()
	local s = ns.db and ns.db.buffs.blizzard.bars
	return s and ns.Enabled() and s.mode == "take" and s.look ~= "blizzard"
end

local function Call(item, method)
	local fn = item[method]
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, item)
	return ok and result or nil
end

local function CopyText(from, to)
	if not from then return end
	local ok, text = pcall(from.GetText, from)
	if ok then pcall(to.SetText, to, text) end
end

-- What Blizzard's bar shows now, onto Lecdm's.
function H.Copy(item)
	local o = overlays[item]
	if not (o and o.on) then return end
	local bar = Call(item, "GetBarFrame")
	if bar then
		local ok, low, high = pcall(bar.GetMinMaxValues, bar)
		if ok then pcall(o.bar.SetMinMaxValues, o.bar, low, high) end
		local okV, value = pcall(bar.GetValue, bar)
		if okV then pcall(o.bar.SetValue, o.bar, value) end
	end
	CopyText(Call(item, "GetDurationFontString"), o.time)
	CopyText(Call(item, "GetNameFontString"), o.name)
	CopyText(Call(item, "GetApplicationsFontString"), o.count)
	local icon = Call(item, "GetIconTexture")
	if icon then
		local ok, texture = pcall(icon.GetTexture, icon)
		if ok then pcall(o.icon.SetTexture, o.icon, texture) end
	end
end

local function Overlay(item, place)
	local o = overlays[item]
	if o then return o end
	o = CreateFrame("Frame", nil, place)
	o.edge = o:CreateTexture(nil, "BACKGROUND")
	o.icon = o:CreateTexture(nil, "ARTWORK")
	o.bar = CreateFrame("StatusBar", nil, o)
	o.barBg = o.bar:CreateTexture(nil, "BACKGROUND")
	o.barBg:SetAllPoints()
	o.top = CreateFrame("Frame", nil, o.bar)
	o.top:SetAllPoints()
	o.top:SetFrameLevel(o.bar:GetFrameLevel() + 2)
	o.name = o.top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	o.name:SetJustifyH("LEFT")
	o.time = o.top:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	o.count = o:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	overlays[item] = o
	for _, method in ipairs({ "RefreshCooldownInfo", "RefreshName", "RefreshApplications", "RefreshSpellTexture" }) do
		if type(item[method]) == "function" then hooksecurefunc(item, method, function(self) H.Copy(self) end) end
	end
	return o
end

-- Lecdm's look on an overlay (the place's settings): the icon at the left (or none), the bar,
-- its texture, colour, background, spark, gradient, the text's font.
local function StyleOverlay(o, s, item)
	o:ClearAllPoints()
	o:SetAllPoints(item)
	local h = Number(item:GetHeight(), 20)
	local iconW = s.barIcon ~= false and h or 0
	o.edge:ClearAllPoints()
	o.edge:SetPoint("TOPLEFT", -1, 1)
	o.edge:SetPoint("BOTTOMRIGHT", 1, -1)
	o.edge:SetColorTexture(0, 0, 0, 1)
	o.icon:ClearAllPoints()
	o.icon:SetPoint("TOPLEFT")
	o.icon:SetSize(math.max(iconW, 1), h)
	o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	o.icon:SetShown(iconW > 0)
	o.bar:ClearAllPoints()
	o.bar:SetPoint("TOPLEFT", o, "TOPLEFT", iconW > 0 and (iconW + 1) or 0, 0)
	o.bar:SetPoint("BOTTOMRIGHT")
	local r, g, b = ns.Bars.BarRGB(s.barColor)
	o.bar:SetStatusBarTexture(ns.Bars.BarFile(s.barTexture))
	o.bar:SetStatusBarColor(r, g, b)
	o.barBg:SetColorTexture(0, 0, 0, s.barBg or 0.6)
	ns.Bars.BarExtras(o, o.bar, s, r, g, b, h)
	o.name:ClearAllPoints()
	o.name:SetPoint("LEFT", o.bar, "LEFT", 4, 0)
	o.name:SetPoint("RIGHT", o.bar, "RIGHT", -40, 0)
	o.time:ClearAllPoints()
	o.time:SetPoint("RIGHT", o.bar, "RIGHT", -4, 0)
	o.count:ClearAllPoints()
	o.count:SetPoint("BOTTOMRIGHT", o.icon, "BOTTOMRIGHT", -1, 1)
	ns.Bars.SetFont(o.name, s.fontFace, s.fontOutline, "small", "GameFontHighlightSmall")
	ns.Bars.SetFont(o.time, s.fontFace, s.fontOutline, "normal", "NumberFontNormal")
	ns.Bars.SetFont(o.count, s.fontFace, s.fontOutline, "small", "NumberFontNormalSmall")
end

-- After a layout: an overlay over each of Blizzard's bars shown, none over the rest.
local function PlaceOverlays(items, place, s)
	local want = {}
	if H.LecdmLook() then
		for _, item in ipairs(items) do
			local o = Overlay(item, place)
			StyleOverlay(o, s, item)
			o.on = true
			o:Show()
			want[o] = true
			H.Copy(item)
		end
	end
	for _, o in pairs(overlays) do
		if not want[o] then
			o.on = false
			o:Hide()
		end
	end
end

function H.Kind(key)
	for _, kind in ipairs(H.KINDS) do
		if kind.key == key then return kind end
	end
end

function H.Settings(key)
	return ns.db.buffs.blizzard[key]
end

local function Place(key)
	local frame = places[key]
	if frame then return frame end
	frame = CreateFrame("Frame", nil, UIParent)
	frame.kindKey = key
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		H.Settings(self.kindKey).pos = { point, relPoint, x, y }
	end)
	frame.shade = frame:CreateTexture(nil, "BACKGROUND")
	frame.shade:SetPoint("TOPLEFT", -4, 4)
	frame.shade:SetPoint("BOTTOMRIGHT", 4, -4)
	frame.shade:SetColorTexture(0.3, 0.75, 0.95, 0.3)
	frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
	places[key] = frame
	return frame
end

local DEFAULT_POS = { icons = { "CENTER", "CENTER", -230, -120 }, bars = { "CENTER", "CENTER", 230, -120 } }


local function Index(item)
	return Number(item.layoutIndex, 0)
end

-- Shown, if the game says so plainly; a secret answer counts as shown (no gap is closed then).
local function Shown(item)
	local ok, shown = pcall(item.IsShown, item)
	if not ok or ns.IsSecret(shown) then return true end
	return shown
end

-- Lays Blizzard's icons of one viewer out in Lecdm's place. Offsets are worked out in the
-- place's units, then given in each icon's own (Blizzard scales its icons by Edit Mode's size).
local function Layout(kind)
	local s = H.Settings(kind.key)
	local viewer = _G[kind.global]
	if placing or not viewer or not ns.Enabled() or s.mode ~= "take" then
		if kind.key == "bars" and not placing then PlaceOverlays({}, nil, s) end
		return
	end
	placing = true
	local frame = Place(kind.key)
	local items = {}
	for _, item in ipairs(ns.Listen.ActiveItems(viewer)) do
		if Shown(item) then items[#items + 1] = item end
	end
	table.sort(items, function(a, b) return Index(a) < Index(b) end)
	local hostScale = Number(frame:GetEffectiveScale(), 1)
	local bars = kind.key == "bars"
	local vertical = bars or s.vertical
	-- Timer bars: one column (all in the first line), from the top or the bottom.
	local per = bars and math.max(1, #items) or math.max(1, s.perRow)
	local w, h = 40, 40
	for _, item in ipairs(items) do
		local scale = Number(item:GetEffectiveScale(), 1) / hostScale
		w = math.max(1, Number(item:GetWidth(), 40) * scale)
		h = math.max(1, Number(item:GetHeight(), 40) * scale)
		break
	end
	local n = #items
	local lines = math.ceil(n / per)
	for k, item in ipairs(items) do
		local line, pos = math.floor((k - 1) / per), (k - 1) % per
		local count = (line == lines - 1) and (n - line * per) or per
		local x, y, point
		if vertical then
			local stepY, stepX = h + s.gap, w + s.gap
			if s.grow == "RIGHT" then
				point, x, y = "BOTTOMLEFT", line * stepX, pos * stepY
			elseif s.grow == "LEFT" or bars then
				point, x, y = "TOPLEFT", line * stepX, -pos * stepY
			else
				point, x, y = "LEFT", line * stepX, -(pos - (count - 1) / 2) * stepY
			end
		else
			local step = w + s.gap
			if s.grow == "LEFT" then
				point, x, y = "TOPLEFT", pos * step, -line * (h + s.gap)
			elseif s.grow == "RIGHT" then
				point, x, y = "TOPRIGHT", -pos * step, -line * (h + s.gap)
			else
				point, x, y = "TOP", (pos - (count - 1) / 2) * step, -line * (h + s.gap)
			end
		end
		local scale = Number(item:GetEffectiveScale(), 1) / hostScale
		pcall(function()
			item:ClearAllPoints()
			item:SetPoint(point, frame, point, x / scale, y / scale)
		end)
	end
	-- The place's size: its whole area, for the shade and the drag while unlocked.
	local across = math.max(1, math.min(math.max(n, 1), per))
	local width = vertical and (math.max(1, lines) * (w + s.gap) - s.gap) or (across * (w + s.gap) - s.gap)
	local height = vertical and (across * (h + s.gap) - s.gap) or (math.max(1, lines) * (h + s.gap) - s.gap)
	if bars then width, height = w, math.max(1, n) * (h + s.gap) - s.gap end
	frame:SetSize(math.max(width, 40), math.max(height, 20))
	if bars then PlaceOverlays(items, frame, s) end
	placing = false
end

local function LayoutKind(key)
	local kind = H.Kind(key)
	if kind then Layout(kind) end
end

local function HookItem(item, key)
	if hookedItems[item] or type(item) ~= "table" or type(item.UpdateShownState) ~= "function" then return end
	hookedItems[item] = true
	hooksecurefunc(item, "UpdateShownState", function() LayoutKind(key) end)
end

-- Hooks the viewers once: their layouts, and each icon's showing and hiding.
function H.Setup()
	for _, kind in ipairs(H.KINDS) do
		local viewer = _G[kind.global]
		if viewer and not hooked[viewer] then
			hooked[viewer] = true
			for _, method in ipairs({ "RefreshLayout", "Layout" }) do
				if type(viewer[method]) == "function" then
					hooksecurefunc(viewer, method, function() Layout(kind) end)
				end
			end
			if type(viewer.OnAcquireItemFrame) == "function" then
				hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, item) HookItem(item, kind.key) end)
			end
		end
		if viewer then
			for _, item in ipairs(ns.Listen.ActiveItems(viewer)) do HookItem(item, kind.key) end
		end
	end
end

-- Sets both places up for the profile in use (at login, and whenever settings or the profile
-- change). Leaving a place: Blizzard puts its icons back at its next layout.
function H.Build()
	if not ns.db then return end
	-- Profiles from before "hide" was the default (0.9.0-alpha took them in) switch once.
	local buffs = ns.db.buffs
	if not buffs.hiddenByDefault then
		buffs.hiddenByDefault = true
		buffs.blizzard.icons.mode, buffs.blizzard.bars.mode = "hide", "hide"
	end
	H.Setup()
	local unlocked = ns.Bars.IsUnlocked()
	for _, kind in ipairs(H.KINDS) do
		local s = H.Settings(kind.key)
		local frame = Place(kind.key)
		local take = ns.Enabled() and s.mode == "take"
		if take then
			local pos = s.pos or DEFAULT_POS[kind.key]
			frame:ClearAllPoints()
			frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
			frame.label:SetText(kind.name)
			frame.shade:SetShown(unlocked)
			frame.label:SetShown(unlocked)
			frame:EnableMouse(unlocked)
			frame:Show()
			Layout(kind)
		else
			frame:Hide()
		end
	end
	H.ApplyAlpha()
end

-- In "take" mode, the viewer's opacity follows the place's visibility (Visibility.lua): Blizzard's
-- icons are the viewer's children, so that's the only way to fade them. Untouched while the
-- settings are the defaults.
local touched = {}
function H.ApplyAlpha()
	if not ns.db then return end
	for _, kind in ipairs(H.KINDS) do
		local s = H.Settings(kind.key)
		local viewer = _G[kind.global]
		if kind.key == "bars" and H.LecdmLook() then
			-- Lecdm's bars are on Lecdm's place: they fade with it; the viewer is invisible.
			if places.bars then places.bars:SetAlpha(ns.Visibility.Alpha(s)) end
		elseif viewer and ns.Enabled() and s.mode == "take" then
			local alpha = ns.Visibility.Alpha(s)
			if alpha ~= 1 or touched[viewer] then
				pcall(viewer.SetAlpha, viewer, alpha)
				touched[viewer] = alpha ~= 1 or nil
			end
		end
	end
end

-- For B.ApplyBlizzard: a viewer is made invisible only in "hide" mode.
function H.WantsHidden(global)
	for _, kind in ipairs(H.KINDS) do
		if kind.global == global then
			-- Timer bars wearing Lecdm's look: Blizzard's own are invisible under Lecdm's.
			if kind.key == "bars" and H.LecdmLook() then return true end
			return H.Settings(kind.key).mode == "hide"
		end
	end
	return false
end

-- Opens Blizzard's Cooldown Manager settings (out of combat), where the auras are picked.
function H.OpenBlizzard()
	if InCombatLockdown() then
		ns.Print("not in combat: try again after the fight.")
		return
	end
	if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer") end
	local settings = _G.CooldownViewerSettings
	if not (settings and pcall(settings.TogglePanel, settings)) then
		ns.Print("couldn't open Blizzard's Cooldown Manager: type /cdm.")
	end
end
