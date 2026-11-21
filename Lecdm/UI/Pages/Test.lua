-- Lecdm: the Test build tab: test build 1's settings and tools, the same as its chat commands.
local _, ns = ...
local UI = ns.UI

-- Where the test build's debug lines go: the main chat window, a chat tab by name (make one with
-- a right-click on a chat tab, "Create New Window"), or nowhere (the log keeps them).
local function Where()
	local where = ns.db.test.chat
	if where == "main" then return "Main chat window" end
	if where == "off" then return "Nowhere (the log only)" end
	return where
end

local function BuildChatMenu(_, root)
	local function Radio(text, value)
		root:CreateRadio(text, function() return ns.db.test.chat == value end, function()
			ns.db.test.chat = value
			ns.Window.Refresh()
		end)
	end
	Radio("Main chat window", "main")
	for _, tab in ipairs(ns.ChatTabs()) do
		if tab.frame ~= DEFAULT_CHAT_FRAME then Radio(tab.name, tab.name) end
	end
	Radio("Nowhere (the log only)", "off")
end

local function ChatRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(36)
	row:EnableMouse(true)
	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", 16, 0)
	row.label:SetText("Show them in")
	row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1FilterDropdownTemplate")
	row.dropdown:SetPoint("LEFT", 330, 0)
	row.dropdown:SetSize(150, 24)
	row.dropdown:SetupMenu(BuildChatMenu)
	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Test messages")
		GameTooltip:AddLine("The test build's debug lines (applied, removed, procs, checks). For a tab of their own, right-click a chat tab, Create New Window, name it (Lecdm, say), and pick it here. Replies to your commands and errors stay in the main chat.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.Sync = function() row.dropdown:SetText(Where()) end
	return row
end

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

		stack:Add(UI.OptionHeading(stack.inner, "Test messages"))
		stack:Add(ChatRow(stack.inner))

		stack:Add(UI.OptionHeading(stack.inner, "Tools"))
		stack:Add(UI.OptionButton(stack.inner, "Blizzard's cooldown viewers", function()
			return ns.Blizz.IsHidden() and "Bring them back" or "Make invisible"
		end, function() ns.Blizz.Set(ns.Blizz.IsHidden() and "show" or "hide") end,
			{ "Invisible viewers", "A test: are changes still heard while Blizzard's viewers are invisible? Not kept after /reload." }))
		stack:Add(UI.OptionButton(stack.inner, "Status, in chat", "Show", function() ns.Check.Status() end))
		stack:Add(UI.OptionButton(stack.inner, "Blizzard's list, in chat", "Show", function() ns.Catalogue.PrintAll() end))
		stack:Add(UI.OptionButton(stack.inner, "What's readable now, in chat", "Check", function() ns.Check.Run() end,
			{ "Check", "Best in combat: make a macro with /lecdm check." }))
		stack:Add(UI.OptionButton(stack.inner, "The log", "Open", function() ns.LogWindow.Show() end))
		stack:Add(UI.OptionButton(stack.inner, "", "Clear the log", function() ns.LogWindow.Clear() end))
	end,
	defaults = function()
		ns.db.test.sound = ns.DEFAULTS.test.sound
		ns.db.test.chat = ns.DEFAULTS.test.chat
	end,
})
