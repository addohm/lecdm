-- Lecdm: the tabs the roadmap hasn't reached yet (ROADMAP.md, "Next"). Each one moves to a file of
-- its own when its step lands.
local _, ns = ...
local UI = ns.UI

local function Soon(id, label, order, text)
	ns.Window.Page({
		id = id,
		label = label,
		order = order,
		fill = function(stack)
			stack:Add(UI.OptionText(stack.inner, "|cffff8040Not built yet.|r " .. text, 60))
		end,
	})
end

Soon("bars", "Bars", 2, "Your cooldown bars: as many as you like, your spells in any order, each with its own look and behaviour (hide when ready, grey on cooldown, glow when ready), and trinkets, racials, potions and healthstones.")
Soon("buffs", "Buffs", 3, "Your buffs and procs, buffs from others (Fortitude, Battle Shout, world buffs), what's missing, and your DoTs and HoTs on your target.")
Soon("alerts", "Alerts", 4, "Sounds and glows when a spell is ready, a buff is applied or drops, a charge comes back: set per spell, in combat too.")
