-- Lecdm: /lecdm check. For the spells in Blizzard's Essential and Utility sections, what an addon
-- can read right now. Run it in combat (a macro works) to see what goes SECRET there. It prints
-- and logs one line per spell; nothing is compared unless it isn't secret.
local _, ns = ...

local C = {}
ns.Check = C

local MAX = 12

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
			Call(C_Spell.IsSpellUsable, id), Call(C_Spell.IsSpellInRange, id), Field(charges, "currentCharges"),
			Call(C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed, id)), true)
	end
	if #spells > MAX then ns.Print("(first " .. MAX .. " of " .. #spells .. " spells)") end
	if #spells == 0 then ns.Print("no learned spells in Blizzard's Essential or Utility sections.") end
end
