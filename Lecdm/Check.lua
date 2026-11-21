-- Lecdm: /lecdm check and /lecdm status. For the spells in Blizzard's Essential and Utility sections, what an addon
-- can read right now. Run it in combat (a macro works) to see what goes SECRET there. It prints
-- and logs one line per spell; nothing is compared unless it isn't secret.
local _, ns = ...

local C = {}
ns.Check = C

local MAX = 40

local function Field(t, key)
	if type(t) ~= "table" then return "none" end
	return ns.Show(t[key])
end

local function Call(fn, ...)
	if not fn then return "missing" end
	local ok, a = pcall(fn, ...)
	if not ok then return "error" end
	return ns.Show(a)
end

local function Duration(spellID)
	if not C_Spell.GetSpellCooldownDuration then return "missing" end
	local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spellID)
	if not ok then return "error" end
	if dur == nil then return "none" end
	return ns.IsSecret(dur) and "SECRET object" or "object"
end

local function Usable(spellID)
	local ok, usable, noPower = pcall(C_Spell.IsSpellUsable, spellID)
	if not ok then return "error" end
	return ns.Show(usable) .. " (no power " .. ns.Show(noPower) .. ")"
end

-- A trinket slot: the item, its cooldown (start, duration, enabled) both ways the game offers.
local function Trinket(slot)
	local okID, itemID = pcall(GetInventoryItemID, "player", slot)
	if not okID then return "slot " .. slot .. ": error" end
	if ns.IsSecret(itemID) then return "slot " .. slot .. ": SECRET item" end
	if not itemID then return "slot " .. slot .. ": empty" end
	local okName, name = pcall(C_Item.GetItemNameByID, itemID)
	local okCD, start, duration, enabled = pcall(GetInventoryItemCooldown, "player", slot)
	local okItem, iStart, iDuration = pcall(C_Item.GetItemCooldown, itemID)
	return string.format("slot %d %s: slot cooldown start %s, duration %s, enabled %s; item cooldown start %s, duration %s",
		slot, okName and ns.Show(name) or tostring(itemID),
		okCD and ns.Show(start) or "error", okCD and ns.Show(duration) or "error", okCD and ns.Show(enabled) or "error",
		okItem and ns.Show(iStart) or "error", okItem and ns.Show(iDuration) or "error")
end

function C.Run()
	ns.Log(string.format("check: cooldowns secret now %s, auras secret now %s",
		Call(C_Secrets and C_Secrets.ShouldCooldownsBeSecret), Call(C_Secrets and C_Secrets.ShouldAurasBeSecret)), true)
	local spells = ns.Catalogue.Spells({ [0] = true, [1] = true })
	if #spells == 0 then
		ns.Catalogue.Build()
		spells = ns.Catalogue.Spells({ [0] = true, [1] = true })
	end
	for i = 1, math.min(#spells, MAX) do
		local e = spells[i]
		local id = e.spellID
		local okCD, cd = pcall(C_Spell.GetSpellCooldown, id)
		if not okCD then cd = nil end
		local okCh, charges = pcall(C_Spell.GetSpellCharges, id)
		if not okCh then charges = nil end
		ns.Log(string.format("%s: on cooldown %s, GCD %s, start %s, duration object %s, usable %s, in range %s, charges %s, proc %s",
			e.name, Field(cd, "isActive"), Field(cd, "isOnGCD"), Field(cd, "startTime"), Duration(id),
			Usable(id), Call(C_Spell.IsSpellInRange, id), Field(charges, "currentCharges"),
			Call(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed, id)))
	end
	for _, slot in ipairs({ 13, 14 }) do ns.Log("trinket " .. Trinket(slot)) end
	ns.Print("check: " .. math.min(#spells, MAX) .. " spells and the trinket slots logged (/lecdm log to see them).")
	if #spells > MAX then ns.Print("(first " .. MAX .. " of " .. #spells .. " spells)") end
	if #spells == 0 then ns.Print("no learned spells in Blizzard's Essential or Utility sections.") end
end

-- /lecdm status: Blizzard's Cooldown Manager, its list, its viewers, what's being listened to.
function C.Status()
	ns.Print(ns.Version(true) .. ", test build 1")
	local okAvail, available, reason = pcall(C_CooldownViewer.IsCooldownViewerAvailable)
	if okAvail then
		local text = available and "available" or "not available"
		if reason and reason ~= "" then text = text .. " (" .. ns.Show(reason) .. ")" end
		ns.Print("Blizzard's Cooldown Manager: " .. text .. ", setting cooldownViewerEnabled = "
			.. ns.Show(C_CVar.GetCVar("cooldownViewerEnabled")))
	else
		ns.Print("Blizzard's Cooldown Manager: couldn't ask (" .. tostring(available) .. ")")
	end
	local _, class = UnitClass("player")
	local okSpec, spec = pcall(C_SpecializationInfo.GetSpecialization)
	ns.Print("class " .. tostring(class) .. ", spec " .. (okSpec and ns.Show(spec) or "error")
		.. ", profile " .. ns.Profiles.Current())
	ns.Catalogue.PrintCounts()
	ns.Listen.PrintStatus()
	ns.Print(#LecdmDB.log .. " lines in the log (/lecdm log to copy it)")
end
