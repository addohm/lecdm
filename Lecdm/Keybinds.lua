-- Lecdm: keybind text for icon bar icons. Out of combat, every frame is walked (EnumerateFrames)
-- for action buttons from any bar addon: a Button or CheckButton holding an action slot (the
-- `action` field, the "action" attribute, or `_state_action` for paging buttons). Each button's
-- key is its own hotkey text (what the bar shows), else its click binding. Which spell or item a
-- slot holds is read again whenever slots, pages or bindings change, in combat too (reading only:
-- no field or script is set on any button). A spell shows the key of the first button on screen
-- holding it.
local _, ns = ...

local K = {}
ns.Keybinds = K

local buttons = {}  -- action buttons found at the last scan
local byName = {}   -- spell name / "item:ID" -> key text
local buttonsOf = {} -- spell name / "item:ID" -> the visible buttons holding it
local scanPending = true

local function Number(v)
	if type(v) == "number" and not ns.IsSecret(v) and v > 0 then return v end
end

local function Text(v)
	if type(v) == "string" and v ~= "" and not ns.IsSecret(v) then return v end
end

local function Slot(button)
	local slot = Number(button._state_action) or Number(button.action)
	if slot then return slot end
	local ok, attr = pcall(button.GetAttribute, button, "action")
	return ok and Number(attr) or nil
end

local function IsActionButton(f)
	local ok, yes = pcall(function()
		if f:IsForbidden() then return false end
		if not (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) then return false end
		return Slot(f) ~= nil
	end)
	return ok and yes
end

-- Short key text: "SHIFT-1" -> "S1", "CTRL-MOUSEWHEELUP" -> "CMwU".
function K.Short(key)
	key = Text(key)
	if not key then return nil end
	key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"):gsub("META%-", "M")
	key = key:gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD"):gsub("BUTTON", "M")
	key = key:gsub("NUMPAD", "N"):gsub("SPACE", "Sp")
	return key
end

local function KeyOf(button)
	local hotkey = button.HotKey or button.hotKey
	if type(hotkey) == "table" and hotkey.GetText then
		local ok, text = pcall(hotkey.GetText, hotkey)
		text = ok and Text(text)
		-- An unbound button shows the range dot.
		if text and text ~= RANGE_INDICATOR and text ~= "●" then return text end
	end
	local name = Text(button:GetName())
	if name then
		local ok, key = pcall(GetBindingKey, "CLICK " .. name .. ":LeftButton")
		if ok then return K.Short(key) end
	end
end

-- Walks every frame for action buttons (out of combat).
function K.Scan()
	if InCombatLockdown() then
		scanPending = true
		return
	end
	scanPending = false
	wipe(buttons)
	local f = EnumerateFrames and EnumerateFrames()
	while f do
		if IsActionButton(f) then buttons[#buttons + 1] = f end
		f = EnumerateFrames(f)
	end
	K.Read()
end

-- What each button holds now, and its key.
function K.Read()
	wipe(byName)
	wipe(buttonsOf)
	for _, button in ipairs(buttons) do
		local okShown, visible = pcall(button.IsVisible, button)
		if okShown and visible then
			local slot = Slot(button)
			local ok, kind, id, sub = pcall(GetActionInfo, slot)
			if ok and not (ns.IsSecret(kind) or ns.IsSecret(id) or ns.IsSecret(sub)) then
				local name
				if kind == "spell" or (kind == "macro" and sub == "spell") then
					local okName, n = pcall(C_Spell.GetSpellName, id)
					name = okName and Text(n)
				elseif kind == "item" and Number(id) then
					name = "item:" .. id
				end
				if name and not byName[name] then byName[name] = KeyOf(button) end
				if name then
					buttonsOf[name] = buttonsOf[name] or {}
					table.insert(buttonsOf[name], button)
				end
			end
		end
	end
	if ns.Bars and ns.Bars.ShowKeys then ns.Bars.ShowKeys() end
	if ns.Swing and ns.Swing.ButtonsChanged then ns.Swing.ButtonsChanged() end
	if ns.ButtonGlows and ns.ButtonGlows.ButtonsChanged then ns.ButtonGlows.ButtonsChanged() end
end

-- Every spell (by name) and "item:ID" on a visible action button now, sorted.
function K.Names()
	local list = {}
	for name in pairs(buttonsOf) do list[#list + 1] = name end
	table.sort(list)
	return list
end

-- The visible action buttons holding a spell (by name) or "item:ID" now.
function K.Buttons(name)
	return name and buttonsOf[name] or {}
end

-- The key text for an icon bar entry (by its name, or "item:ID"), or nil.
function K.For(name)
	return name and byName[name]
end

-- A scan waits a frame, so a burst of binding updates (at login) is one scan.
local queued = false
local function QueueScan()
	if queued then return end
	queued = true
	C_Timer.After(0, function()
		queued = false
		K.Scan()
	end)
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED",
	"ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORM" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
	if not ns.db then return end
	if event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_BINDINGS" or (event == "PLAYER_REGEN_ENABLED" and scanPending) then
		QueueScan()
	else
		K.Read()
	end
end)
