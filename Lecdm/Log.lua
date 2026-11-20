-- Lecdm: the log. Each line has the time and "[combat]" / "[instance]" when they apply. Lines go
-- to LecdmDB.log (saved at /reload or logout), some to chat as well, and /lecdm log shows them
-- in a window, selected, ready for Ctrl+C.
local _, ns = ...

local MAX = 500

function ns.Log(text, toChat)
	local line = date("%H:%M:%S") .. " " .. ns.Where() .. text
	local log = LecdmDB.log
	table.insert(log, line)
	while #log > MAX do table.remove(log, 1) end
	if toChat then ns.Print(line) end
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
		window:SetBackdropBorderColor(0.3, 0.75, 0.95, 1)
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
