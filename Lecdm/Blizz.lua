-- Lecdm: /lecdm blizz hide | show. A test only: sets Blizzard's four cooldown viewers to alpha 0
-- (invisible, but still shown, so the Cooldown Manager keeps running), or back to what they had.
-- It answers two questions for the plan: does the listener still hear changes while the viewers
-- are invisible, and does Blizzard put their alpha back by itself (each time it does, the log
-- says so; Lecdm doesn't fight it). It's not set again at login.
local _, ns = ...

local B = {}
ns.Blizz = B

local hidden = false
local setting = false
local saved = {}  -- viewer -> alpha before hiding
local hooked = {} -- viewer -> true

local function Viewers()
	local list = {}
	for _, v in ipairs(ns.Listen.VIEWERS) do
		local viewer = _G[v.global]
		if viewer then table.insert(list, { frame = viewer, name = v.name }) end
	end
	return list
end

local function Watch(viewer, name)
	if hooked[viewer] then return end
	hooked[viewer] = true
	hooksecurefunc(viewer, "SetAlpha", function(_, alpha)
		if hidden and not setting then
			ns.Log("Blizzard set the " .. name .. " viewer's alpha to " .. ns.Show(alpha), true)
		end
	end)
end

local function SetAlpha(viewer, alpha)
	setting = true
	pcall(viewer.SetAlpha, viewer, alpha)
	setting = false
end

function B.IsHidden()
	return hidden
end

function B.Set(what)
	local list = Viewers()
	if #list == 0 then
		ns.Print("Blizzard's viewers aren't there (is the Cooldown Manager on?).")
		return
	end
	if what == "hide" then
		for _, v in ipairs(list) do
			Watch(v.frame, v.name)
			if not hidden then
				local alpha = v.frame:GetAlpha()
				saved[v.frame] = not ns.IsSecret(alpha) and alpha or 1
			end
			SetAlpha(v.frame, 0)
		end
		hidden = true
		ns.Log("Blizzard's viewers set invisible (test)", true)
	elseif what == "show" then
		for _, v in ipairs(list) do SetAlpha(v.frame, saved[v.frame] or 1) end
		hidden = false
		ns.Log("Blizzard's viewers back to their own alpha", true)
	else
		ns.Print("/lecdm blizz hide, or /lecdm blizz show")
		return
	end
	if ns.Window then ns.Window.Refresh() end
end

-- /lecdm host on | off. A test of placing Blizzard's own buff icons and bars (the Buffs and Bars
-- viewers: buffs on you, your debuffs on the target) in a row Lecdm controls, under the middle
-- of the screen. Only Blizzard can time those auras in combat, so the question is whether its icons can
-- live in Lecdm's bars: they're re-placed after each of Blizzard's layouts (RefreshLayout, Layout),
-- counted, and any refusal or blocked action is logged. Those two viewers get their own alpha
-- back (they must be seen); Essential and Utility stay as they are. Off: /reload puts Blizzard's
-- icons back where Blizzard wants them (Lecdm never calls Blizzard's layout itself).
local HOSTED = { BuffIconCooldownViewer = "Buffs", BuffBarCooldownViewer = "Bars" }
local hosting = false
local host
local hostHooked = {}
local placing = false
local placeCount, combatCount = {}, {}
local refusedShown = false

local function HostFrame()
	if host then return host end
	host = CreateFrame("Frame", nil, UIParent)
	host:SetSize(200, 40)
	host:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
	host.bg = host:CreateTexture(nil, "BACKGROUND")
	host.bg:SetAllPoints()
	host.bg:SetColorTexture(0.3, 0.75, 0.95, 0.15)
	return host
end

local function Index(item)
	local i = item.layoutIndex
	if ns.IsSecret(i) or type(i) ~= "number" then return 0 end
	return i
end

local function Place(viewer, name)
	if not hosting or placing then return end
	placing = true
	local items = ns.Listen.ActiveItems(viewer)
	table.sort(items, function(a, b) return Index(a) < Index(b) end)
	local x, y = 0, name == "Bars" and -46 or 0
	for _, item in ipairs(items) do
		local ok, err = pcall(function()
			item:ClearAllPoints()
			item:SetPoint("TOPLEFT", host, "TOPLEFT", name == "Bars" and 0 or x, y)
		end)
		if not ok and not refusedShown then
			refusedShown = true
			ns.Log("host test: the game refused placing a Blizzard icon (shown once): " .. tostring(err), true)
		end
		local okW, w = pcall(item.GetWidth, item)
		local okH, h = pcall(item.GetHeight, item)
		w = (okW and not ns.IsSecret(w) and w) or 40
		h = (okH and not ns.IsSecret(h) and h) or 30
		if name == "Bars" then y = y - h - 2 else x = x + w + 4 end
	end
	placeCount[name] = (placeCount[name] or 0) + 1
	if InCombatLockdown() then combatCount[name] = (combatCount[name] or 0) + 1 end
	placing = false
end

function B.Host(what)
	if what == "on" then
		HostFrame():Show()
		hosting = true
		for global, name in pairs(HOSTED) do
			local viewer = _G[global]
			if viewer then
				if hidden then SetAlpha(viewer, saved[viewer] or 1) end
				if not hostHooked[viewer] then
					hostHooked[viewer] = true
					for _, method in ipairs({ "RefreshLayout", "Layout" }) do
						if type(viewer[method]) == "function" then
							hooksecurefunc(viewer, method, function() Place(viewer, name) end)
						end
					end
				end
				Place(viewer, name)
			end
		end
		ns.Log("host test on: Blizzard's buff icons and bars should now sit in the faint blue row", true)
	elseif what == "off" then
		hosting = false
		if host then host:Hide() end
		ns.Log("host test off: /reload puts Blizzard's icons back where Blizzard wants them", true)
	else
		ns.Print("/lecdm host on, or /lecdm host off")
		return
	end
	if ns.Window then ns.Window.Refresh() end
end

function B.IsHosting()
	return hosting
end

function B.PrintStatus()
	if not (hosting or next(placeCount)) then return end
	local parts = {}
	for _, name in ipairs({ "Buffs", "Bars" }) do
		table.insert(parts, string.format("%s placed %d times (%d in combat)", name, placeCount[name] or 0, combatCount[name] or 0))
	end
	ns.Print("host test " .. (hosting and "on" or "off") .. ": " .. table.concat(parts, ", "))
end
