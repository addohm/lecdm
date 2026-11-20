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
	end
end
