-- Lecdm: the log. Each line has the time and "[combat]" / "[instance]" when they apply. Lines go
-- to LecdmDB.log (account-wide, saved at /reload or logout), and /lecdm log shows them in a
-- window, selected, ready for Ctrl+C. Some are the diagnostics' lines in chat too: they go
-- where the Diagnostics tab says (ns.db.test.chat: "main", a chat tab's name, or "off"). Replies
-- to the player's commands and real errors use ns.Print, always the main chat window.
local _, ns = ...

local MAX = 500

function ns.Log(text, toChat)
	local log = LecdmDB and LecdmDB.log
	if not log then return end
	local line = date("%H:%M:%S") .. " " .. ns.Where() .. text
	table.insert(log, line)
	while #log > MAX do table.remove(log, 1) end
	if toChat then ns.Debug(line) end
end

-- The chat tabs, by name (for the Diagnostics tab's choice).
function ns.ChatTabs()
	local list = {}
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		local ok, name, _, _, _, _, _, shown, _, docked = pcall(GetChatWindowInfo, i)
		if ok and type(name) == "string" and name ~= "" and (shown or docked) then
			list[#list + 1] = { name = name, frame = _G["ChatFrame" .. i] }
		end
	end
	return list
end

-- A diagnostics line: to the main chat window, a chat tab by name (the main window if it's
-- gone), or nowhere (the log has it).
function ns.Debug(line)
	local where = ns.db and ns.db.test.chat or "main"
	if where == "off" then return end
	if where ~= "main" then
		for _, tab in ipairs(ns.ChatTabs()) do
			if tab.name == where and tab.frame then
				tab.frame:AddMessage("|cff4fc3f7Lecdm|r: " .. line)
				return
			end
		end
	end
	ns.Print(line)
end

local W = {}
ns.LogWindow = W

local window
function W.Show()
	if not window then
		window = CreateFrame("Frame", "LecdmLog", UIParent, "BackdropTemplate")
		window:SetSize(640, 380)
		window:SetPoint("CENTER")
		window:SetFrameStrata("DIALOG")
		window:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		window:SetBackdropColor(0.05, 0.06, 0.09, 0.96)
		window:SetBackdropBorderColor(ns.Theme.Edge())
		window:EnableMouse(true)
		window:SetMovable(true)
		window:RegisterForDrag("LeftButton")
		window:SetScript("OnDragStart", window.StartMoving)
		window:SetScript("OnDragStop", window.StopMovingOrSizing)
		tinsert(UISpecialFrames, "LecdmLog")

		local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 14, -12)
		title:SetText("Lecdm log: Ctrl+C copies it (it's selected)")
		local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)

		local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 14, -36)
		scroll:SetPoint("BOTTOMRIGHT", -32, 14)
		local box = CreateFrame("EditBox", nil, scroll)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetFontObject(ChatFontNormal)
		box:SetWidth(580)
		box:SetScript("OnEscapePressed", function() window:Hide() end)
		scroll:SetScrollChild(box)
		window.box = box
	end
	local log = LecdmDB.log
	local text = #log > 0 and table.concat(log, "\n") or "Nothing logged yet."
	window.box:SetText("Lecdm " .. ns.Version() .. "\n" .. text)
	window:Show()
	window.box:SetFocus()
	window.box:HighlightText()
end

function W.Clear()
	LecdmDB.log = {}
	ns.Print("log cleared.")
end
