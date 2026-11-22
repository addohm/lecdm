-- Lecdm: import and export. A profile, an icon bar or a buff group as text to share:
-- "Lecdm1:<kind>:<data>", the data in Lecdm's own plain format (tables of strings, numbers and
-- true/false), read back by a parser here: pasted text is never run as code.
local _, ns = ...

local T = {}
ns.Transfer = T

local PREFIX = "Lecdm1:"
local MAX_DEPTH = 24

-- Writing -----------------------------------------------------------------------------------

local function Quote(s)
	return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
end

local function Write(v, out, depth)
	local kind = type(v)
	if kind == "string" then
		out[#out + 1] = Quote(v)
	elseif kind == "number" then
		out[#out + 1] = (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.10g", v)
	elseif kind == "boolean" then
		out[#out + 1] = v and "t" or "f"
	elseif kind == "table" then
		if depth > MAX_DEPTH then error("too deep") end
		out[#out + 1] = "{"
		local keys = {}
		for k in pairs(v) do
			if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			local value = v[k]
			local vk = type(value)
			if vk == "string" or vk == "number" or vk == "boolean" or vk == "table" then
				Write(k, out, depth + 1)
				out[#out + 1] = "="
				Write(value, out, depth + 1)
				out[#out + 1] = ";"
			end
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "f"
	end
end

function T.Serialize(v)
	local out = {}
	Write(v, out, 0)
	return table.concat(out)
end

-- Reading -----------------------------------------------------------------------------------

-- Reads one value at position i; returns it and the next position, or errors.
local function Read(s, i, depth)
	if depth > MAX_DEPTH then error("too deep") end
	local c = s:sub(i, i)
	if c == '"' then
		local out, j = {}, i + 1
		while true do
			local ch = s:sub(j, j)
			if ch == "" then error("an unfinished text") end
			if ch == "\\" then
				local nx = s:sub(j + 1, j + 1)
				out[#out + 1] = nx == "n" and "\n" or nx
				j = j + 2
			elseif ch == '"' then
				return table.concat(out), j + 1
			else
				out[#out + 1] = ch
				j = j + 1
			end
		end
	elseif c == "t" then
		return true, i + 1
	elseif c == "f" then
		return false, i + 1
	elseif c == "{" then
		local t, j = {}, i + 1
		while s:sub(j, j) ~= "}" do
			if s:sub(j, j) == "" then error("an unfinished table") end
			local k
			k, j = Read(s, j, depth + 1)
			if type(k) ~= "string" and type(k) ~= "number" then error("a bad key") end
			if s:sub(j, j) ~= "=" then error("a missing =") end
			local v
			v, j = Read(s, j + 1, depth + 1)
			if s:sub(j, j) ~= ";" then error("a missing ;") end
			t[k] = v
			j = j + 1
		end
		return t, j + 1
	else
		local num = s:match("^%-?%d+%.?%d*[eE]?[%-+]?%d*", i)
		if num and num ~= "" and tonumber(num) then return tonumber(num), i + #num end
		error("something unexpected at " .. i)
	end
end

function T.Parse(s)
	local ok, v, j = pcall(Read, s, 1, 0)
	if not ok then return nil, tostring(v):gsub("^.-:%d+: ", "") end
	if j ~= #s + 1 then return nil, "something after the end" end
	return v
end

-- Export and import ---------------------------------------------------------------------------

-- kind: "profile", "bar" or "group".
function T.Export(kind, data)
	return PREFIX .. kind .. ":" .. T.Serialize(data)
end

-- Returns kind, data; or nil and why.
function T.Decode(text)
	text = strtrim(text or ""):gsub("%s+", "")
	local kind, body = text:match("^Lecdm1:(%a+):(.+)$")
	if not kind then return nil, "that isn't Lecdm's text (it starts \"Lecdm1:\")." end
	if kind ~= "profile" and kind ~= "bar" and kind ~= "group" then return nil, "Lecdm doesn't know a \"" .. kind .. "\"." end
	local data, err = T.Parse(body)
	if type(data) ~= "table" then return nil, "it's damaged: " .. tostring(err or "not a table") .. "." end
	return kind, data
end

-- A pasted icon bar or buff group joins this profile (a new id; its spells or buffs move to it
-- from any other); a pasted profile becomes a new profile under `name`, which this character
-- then uses. Returns true, or nil and why.
function T.Apply(kind, data, name)
	if kind == "bar" then
		if type(data.spells) ~= "table" then return nil, "that bar has no spells list." end
		local bars = ns.db.bars
		bars.nextID = (bars.nextID or 1) + 1
		data.id, data.pos, data.anchorTo, data.overflowTo = "bar" .. bars.nextID, nil, nil, nil
		data.show = type(data.show) == "table" and data.show or {}
		for _, key in ipairs(data.spells) do
			local other, i = ns.Bars.BarOf(key)
			if other then table.remove(other.spells, i) end
		end
		ns.Bars.FillLook(data)
		table.insert(bars.list, data)
		ns.Refresh()
		return true, data
	elseif kind == "group" then
		if type(data.entries) ~= "table" then return nil, "that group has no buffs list." end
		local buffs = ns.db.buffs
		buffs.nextID = (buffs.nextID or 1) + 1
		data.id, data.pos, data.anchorTo = "buffs" .. buffs.nextID, nil, nil
		for _, entry in ipairs(data.entries) do
			local other, i = ns.Auras.GroupOf(entry)
			if other then table.remove(other.entries, i) end
		end
		ns.Auras.FillLook(data)
		table.insert(buffs.list, data)
		ns.Refresh()
		return true, data
	elseif kind == "profile" then
		name = strtrim(name or "")
		if name == "" then return nil, "a profile needs a name." end
		if LecdmDB.profiles[name] then return nil, "there's already a profile called " .. name .. "." end
		LecdmDB.profiles[name] = data
		return ns.Profiles.Switch(name)
	end
	return nil, "Lecdm doesn't know that."
end

-- The window: export shows the text selected (Ctrl+C); import takes pasted text.
local window
local function Window()
	if window then return window end
	window = CreateFrame("Frame", "LecdmTransfer", UIParent, "BackdropTemplate")
	window:SetSize(560, 300)
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
	tinsert(UISpecialFrames, "LecdmTransfer")
	window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.title:SetPoint("TOPLEFT", 14, -12)
	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)
	local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -36)
	scroll:SetPoint("BOTTOMRIGHT", -32, 44)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetWidth(500)
	box:SetScript("OnEscapePressed", function() window:Hide() end)
	scroll:SetScrollChild(box)
	window.box = box
	window.import = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	window.import:SetSize(120, 24)
	window.import:SetPoint("BOTTOMRIGHT", -14, 12)
	window.import:SetText("Import")
	return window
end

function T.ShowExport(title, text)
	local w = Window()
	w.title:SetText(title .. ": Ctrl+C copies it (it's selected)")
	w.box:SetText(text)
	w.import:Hide()
	w:Show()
	w.box:SetFocus()
	w.box:HighlightText()
end

StaticPopupDialogs.LECDM_IMPORT_NAME = {
	text = "Name the imported profile:",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 32,
	OnShow = function(dialog)
		local box = dialog:GetEditBox()
		box:SetText("")
		box:SetFocus()
	end,
	OnAccept = function(dialog, data)
		local ok, err = T.Apply("profile", data, dialog:GetEditBox():GetText())
		if ok then
			ns.Print("profile imported.")
			if window then window:Hide() end
		else
			ns.Print(err)
		end
		if ns.Window then ns.Window.Refresh() end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		if dialog and dialog.GetButton1 then dialog:GetButton1():Click() end
	end,
	EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Paste a profile, an icon bar or a buff group (whichever it is) and press Import.
function T.ShowImport()
	local w = Window()
	w.title:SetText("Paste Lecdm's text here (Ctrl+V), then Import")
	w.box:SetText("")
	w.import:Show()
	w.import:SetScript("OnClick", function()
		local kind, data = T.Decode(w.box:GetText())
		if not kind then
			ns.Print(data)
			return
		end
		if kind == "profile" then
			StaticPopup_Show("LECDM_IMPORT_NAME", nil, nil, data)
			return
		end
		local ok, result = T.Apply(kind, data)
		if ok then
			ns.Print((kind == "bar" and "icon bar " or "buff group ") .. tostring(result.name) .. " imported.")
			w:Hide()
		else
			ns.Print(result)
		end
		if ns.Window then ns.Window.Refresh() end
	end)
	w:Show()
	w.box:SetFocus()
end
