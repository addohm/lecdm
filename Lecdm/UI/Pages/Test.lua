-- Lecdm: the Test build tab: test build 1's settings and tools, the same as its chat commands.
local _, ns = ...
local UI = ns.UI

ns.Window.Page({
	id = "test",
	label = "Test build",
	order = 5,
	note = "Test build 1 checks in game what Lecdm will rely on. TESTING.md (in the addon's GitHub repo) has what to try; then open the log and paste it.",
	fill = function(stack)
		stack:Add(UI.OptionHeading(stack.inner, "Listening"))
		stack:Add(UI.OptionText(stack.inner,
			"Lecdm listens to Blizzard's Cooldown Manager: when it notices a tracked buff applied or removed, or a spell "
			.. "going on cooldown, the log says so (buffs in chat too). It only listens; it changes nothing there.", 44))
		stack:Add(UI.OptionCheck(stack.inner, "Raid warning when a tracked buff drops",
			function() return ns.db.test.sound end,
			function(v) ns.db.test.sound = v end,
			{ "Raid warning", "Played the moment Blizzard's Cooldown Manager says a buff it tracks was removed. Does it match the icon, in combat too?" }))

		stack:Add(UI.OptionHeading(stack.inner, "Tools"))
		stack:Add(UI.OptionButton(stack.inner, "Blizzard's cooldown viewers", function()
			return ns.Blizz.IsHidden() and "Bring them back" or "Make invisible"
		end, function() ns.Blizz.Set(ns.Blizz.IsHidden() and "show" or "hide") end,
			{ "Invisible viewers", "A test: are changes still heard while Blizzard's viewers are invisible? Not kept after /reload." }))
		stack:Add(UI.OptionButton(stack.inner, "Blizzard's buff icons in a Lecdm row", function()
			return ns.Blizz.IsHosting() and "Stop (then /reload)" or "Start"
		end, function() ns.Blizz.Host(ns.Blizz.IsHosting() and "off" or "on") end,
			{ "Host test", "Places Blizzard's own buff icons and bars (buffs on you, your debuffs on the target) in a row under the middle of the screen, and keeps them there after each of Blizzard's layouts. Do they stay put, in combat too?" }))
		stack:Add(UI.OptionButton(stack.inner, "Status, in chat", "Show", function() ns.Check.Status() end))
		stack:Add(UI.OptionButton(stack.inner, "Blizzard's list, in chat", "Show", function() ns.Catalogue.PrintAll() end))
		stack:Add(UI.OptionButton(stack.inner, "What's readable now, in chat", "Check", function() ns.Check.Run() end,
			{ "Check", "Best in combat: make a macro with /lecdm check." }))
		stack:Add(UI.OptionButton(stack.inner, "The log", "Open", function() ns.LogWindow.Show() end))
		stack:Add(UI.OptionButton(stack.inner, "", "Clear the log", function() ns.LogWindow.Clear() end))
	end,
	defaults = function()
		ns.db.test.sound = ns.DEFAULTS.test.sound
	end,
})
