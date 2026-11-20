-- Lecdm: test icons. Lecdm's own icons for the learned spells in Blizzard's Essential and
-- Utility sections, to see whether an addon's own icon works in combat:
--  * the swipe and countdown come from C_Spell.GetSpellCooldownDuration, drawn by the game
--    (Cooldown:SetCooldownFromDurationObject);
--  * the icon goes grey while the spell is on a real cooldown (isActive and not isOnGCD, which
--    Blizzard's docs mark never secret), and dark while it can't be cast (IsSpellUsable).
-- Plain frames, no mouse (except while being moved), not protected, so they can be made and
-- updated in combat.
local _, ns = ...

local I = {}
ns.Icons = I

local SIZE, GAP, MAX = 36, 4, 12
local anchor
local buttons = {}
local moving = false
local reported = false

local function Anchor()
	if anchor then return anchor end
	anchor = CreateFrame("Frame", nil, UIParent)
	anchor:SetSize(SIZE, SIZE)
	local pos = LecdmDB.pos
	if pos then
		anchor:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
	else
		anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
	end
	anchor:SetMovable(true)
	anchor:RegisterForDrag("LeftButton")
	anchor:SetScript("OnDragStart", anchor.StartMoving)
	anchor:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, _, x, y = self:GetPoint()
		LecdmDB.pos = { point, x, y }
	end)
	anchor.shade = anchor:CreateTexture(nil, "BACKGROUND")
	anchor.shade:SetPoint("TOPLEFT", -4, 4)
	anchor.shade:SetColorTexture(0.3, 0.75, 0.95, 0.35)
	anchor.shade:Hide()
	return anchor
end

local function Button(i)
	local b = buttons[i]
	if b then return b end
	b = CreateFrame("Frame", nil, Anchor())
	b:SetSize(SIZE, SIZE)
	b:SetPoint("LEFT", anchor, "LEFT", (i - 1) * (SIZE + GAP), 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	b.cd:SetHideCountdownNumbers(false)
	buttons[i] = b
	return b
end

local function Update(b)
	local id = b.spellID
	local onCooldown = false
	local ok, info = pcall(C_Spell.GetSpellCooldown, id)
	if ok and type(info) == "table" and not ns.IsSecret(info.isActive) and not ns.IsSecret(info.isOnGCD) then
		onCooldown = info.isActive and not info.isOnGCD
	end
	b.icon:SetDesaturated(onCooldown and true or false)

	local okDur, dur = pcall(C_Spell.GetSpellCooldownDuration, id)
	if okDur and (ns.IsSecret(dur) or dur) then
		local okSet, err = pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)
		if not okSet and not reported then
			reported = true
			ns.Log("test icons: the game refused the duration object (shown once): " .. tostring(err), true)
		end
	else
		b.cd:Clear()
	end

	local okUse, usable = pcall(C_Spell.IsSpellUsable, id)
	if okUse and not ns.IsSecret(usable) then
		local v = usable and 1 or 0.4
		b.icon:SetVertexColor(v, v, v)
	end
end

local function UpdateAll()
	for _, b in ipairs(buttons) do
		if b:IsShown() then Update(b) end
	end
end

function I.Build()
	for _, b in ipairs(buttons) do b:Hide() end
	if not LecdmDB.icons then
		if anchor then anchor:Hide() end
		return
	end
	local spells = ns.Catalogue.Spells({ [0] = true, [1] = true })
	Anchor():Show()
	anchor:SetWidth(math.max(1, math.min(#spells, MAX)) * (SIZE + GAP) - GAP)
	for i = 1, math.min(#spells, MAX) do
		local b = Button(i)
		b.spellID = spells[i].spellID
		local okTex, texture = pcall(C_Spell.GetSpellTexture, b.spellID)
		b.icon:SetTexture(okTex and texture or 134400)
		b:Show()
		Update(b)
	end
end

function I.Toggle()
	LecdmDB.icons = not LecdmDB.icons
	I.Build()
	ns.Print("test icons " .. (LecdmDB.icons and "on" or "off"))
end

function I.Move()
	if InCombatLockdown() then
		ns.Print("not in combat: try again after the fight.")
		return
	end
	moving = not moving
	Anchor():EnableMouse(moving)
	anchor.shade:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 4, -4)
	anchor.shade:SetShown(moving)
	ns.Print(moving and "drag the test icons, then /lecdm move again to lock them." or "test icons locked.")
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_USABLE",
	"ACTIONBAR_UPDATE_USABLE", "PLAYER_TARGET_CHANGED" }) do
	events:RegisterEvent(e)
end
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
events:SetScript("OnEvent", function(_, event)
	if event == "SPELLS_CHANGED" or event == "COOLDOWN_VIEWER_DATA_LOADED" then
		ns.Catalogue.Build()
		if LecdmDB then I.Build() end
	else
		UpdateAll()
	end
end)
