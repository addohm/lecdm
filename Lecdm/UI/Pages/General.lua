-- Lecdm: the General tab: turning Lecdm on and off, the minimap button, the login reminder, the
-- class-coloured window, resetting everything, and the commands.
local _, ns = ...
local UI = ns.UI

local GOLD = "|cffffd100"

ns.Window.Page({
	id = "general",
	label = "General",
	order = 1,
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "Getting started"))
		stack:Add(UI.OptionText(stack.inner,
			"Lecdm makes Blizzard's Cooldown Manager better and simpler to manage: your cooldowns, buffs and procs, "
			.. "laid out and styled your way from this window, with sounds and glows that work in combat.\n"
			.. GOLD .. "Icon bars|r: start here. Your cooldowns in icon bars you lay out; two are made for you from Blizzard's list.\n"
			.. GOLD .. "Buffs|r: your buffs from anyone, as icons or timer bars, and Blizzard's own for your debuffs on the target. "
			.. GOLD .. "Alerts|r: sounds and glows.\n"
			.. "|cffff8040An alpha:|r please report what's wrong or missing. " .. GOLD .. "Diagnostics|r helps.\n"
			.. GOLD .. "Profiles|r: separate setups, switched by hand or by your talents or group role.", 112))

		stack:Add(UI.OptionHeading(stack.inner, "General"))
		stack:Add(UI.OptionCheck(stack.inner, "Enable Lecdm",
			function() return ns.Enabled() end,
			function(v) ns.SetEnabled(v) end,
			{ "Enable Lecdm", "Turns everything Lecdm shows and plays off without disabling the addon. The minimap button greys out while it's off." }))
		stack:Add(UI.OptionCheck(stack.inner, "Show the minimap button",
			function() return not ns.db.minimap.hide end,
			function(v) ns.Minimap.SetShown(v) end))
		stack:Add(UI.OptionCheck(stack.inner, "Show a reminder in chat when you log in",
			function() return ns.db.loginMessage end,
			function(v) ns.db.loginMessage = v end,
			{ "Login reminder", "A line in chat each time you log in, saying how to open the options." }))

		stack:Add(UI.OptionHeading(stack.inner, "Appearance"))
		stack:Add(UI.OptionCheck(stack.inner, "Use my class colour for this window",
			function() return ns.db.classColour end,
			function(v)
				ns.db.classColour = v
				ns.Refresh()
			end,
			{ "Class colour", "The window's edge, its rules and the selected tab take your class colour instead of gold. Text keeps its own colours." }))

		stack:Add(UI.OptionHeading(stack.inner, "Troubleshooting"))
		stack:Add(UI.OptionButton(stack.inner, "Every setting, in every profile", "Reset all settings", ns.ResetAll,
			{ "Reset all settings", "Puts Lecdm back as it was when you installed it: every profile and every character's choices. You're asked first, and the interface reloads." }))

		stack:Add(UI.OptionHeading(stack.inner, "Chat commands"))
		stack:Add(UI.OptionText(stack.inner,
			GOLD .. "/lecdm|r opens or closes this window (" .. GOLD .. "/lcdm|r for short).\n"
			.. GOLD .. "/lecdm general|r, " .. GOLD .. "bars|r (icon bars), " .. GOLD .. "buffs|r, " .. GOLD .. "alerts|r, "
			.. GOLD .. "diagnostics|r, " .. GOLD .. "profiles|r open a tab.\n"
			.. GOLD .. "/lecdm minimap|r shows or hides the minimap button; " .. GOLD .. "/lecdm on|r and " .. GOLD .. "off|r turn Lecdm on or off.\n"
			.. GOLD .. "/lecdm help|r lists them all.", 80))

		stack:Add(UI.OptionHeading(stack.inner, "About"))
		stack:Add(UI.OptionText(stack.inner, function()
			return "Lecdm " .. ns.Version() .. ". By addohm, for WoW: Forever."
		end, 28))
	end,
	defaults = function()
		local d = ns.DEFAULTS
		ns.db.enabled, ns.db.loginMessage, ns.db.classColour = d.enabled, d.loginMessage, d.classColour
		ns.db.minimap.hide = d.minimap.hide
	end,
})
