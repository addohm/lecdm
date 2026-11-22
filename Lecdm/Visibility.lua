-- Lecdm: when an icon bar, buff group or Blizzard place shows. Each has `showWhen` ("always",
-- "combat": only in combat, "target": in combat or while you have a target), `alpha` (its
-- opacity) and `oocAlpha` (out of combat, a fraction of that). Shown or not is opacity only: our
-- frames and the aura containers in them are never hidden in combat, so nothing protected moves.
-- Conditions on top: `showIf` (a set: shown only when all, or any with `showMatch` "any", hold)
-- and `hideIf` (hidden while any holds). One the game won't tell counts as not holding.
local _, ns = ...

local V = {}
ns.Visibility = V

V.SHOW = { { "always", "Always" }, { "combat", "Only in combat" }, { "target", "In combat, or with a target" } }
V.ALPHAS = { { 1, "100%" }, { 0.8, "80%" }, { 0.6, "60%" }, { 0.4, "40%" }, { 0.2, "20%" } }
V.OOC = { { 1, "The same" }, { 0.6, "60%" }, { 0.3, "30%" }, { 0, "Hidden" } }

local function HasTarget()
	local ok, exists = pcall(UnitExists, "target")
	if not ok or ns.IsSecret(exists) then return true end
	return exists and true or false
end

-- The conditions, by key: { label, test } (test: true, false, or nil when the game won't say).
local function Plain(ok, v)
	if not ok or ns.IsSecret(v) then return nil end
	return v and true or false
end
local function Instance(kind)
	local ok, inside, what = pcall(IsInInstance)
	if not ok or ns.IsSecret(inside) or ns.IsSecret(what) then return nil end
	if kind then return inside and what == kind or false end
	return inside and true or false
end
V.CONDITIONS = {
	{ "solo", "Solo", function() return Plain(pcall(IsInGroup)) == false end },
	{ "party", "In a party", function()
		local inGroup, inRaid = Plain(pcall(IsInGroup)), Plain(pcall(IsInRaid))
		if inGroup == nil or inRaid == nil then return nil end
		return inGroup and not inRaid
	end },
	{ "raid", "In a raid group", function() return Plain(pcall(IsInRaid)) end },
	{ "instance", "In an instance", function() return Instance() end },
	{ "dungeon", "In a dungeon", function() return Instance("party") end },
	{ "raidInstance", "In a raid", function() return Instance("raid") end },
	{ "pvp", "In a battleground or arena", function()
		local bg, arena = Instance("pvp"), Instance("arena")
		if bg == nil then return nil end
		return bg or arena or false
	end },
	{ "mounted", "Mounted", function() return Plain(pcall(IsMounted)) end },
	{ "resting", "Resting (in an inn or city)", function() return Plain(pcall(IsResting)) end },
	{ "vehicle", "In a vehicle", function() return Plain(pcall(UnitInVehicle, "player")) end },
	{ "enemy", "With an enemy target", function()
		local exists = Plain(pcall(UnitExists, "target"))
		if not exists then return exists end
		return Plain(pcall(UnitCanAttack, "player", "target"))
	end },
	{ "combat", "In combat", function() return InCombatLockdown() or Plain(pcall(UnitAffectingCombat, "player")) or false end },
}
local TESTS = {}
for _, c in ipairs(V.CONDITIONS) do TESTS[c[1]] = c[3] end
V.MATCH = { { "all", "All of them" }, { "any", "Any of them" } }

-- Whether the conditions let a thing show now.
function V.Allowed(cfg)
	for key in pairs(cfg.hideIf or {}) do
		if TESTS[key] and TESTS[key]() == true then return false end
	end
	local any, all, some = false, true, false
	for key in pairs(cfg.showIf or {}) do
		if TESTS[key] then
			some = true
			local yes = TESTS[key]() == true
			any = any or yes
			all = all and yes
		end
	end
	if not some then return true end
	if cfg.showMatch == "any" then return any end
	return all
end

-- The opacity a thing with these settings has now.
function V.Alpha(cfg)
	if not V.Allowed(cfg) then return 0 end
	local combat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player") == true)
	local show = cfg.showWhen or "always"
	if show == "combat" and not combat then return 0 end
	if show == "target" and not combat and not HasTarget() then return 0 end
	local alpha = cfg.alpha or 1
	if not combat then alpha = alpha * (cfg.oocAlpha or 1) end
	return alpha
end

-- Everything again (combat, target changes).
function V.Apply()
	if not ns.db then return end
	if ns.Bars and ns.Bars.ApplyAlpha then ns.Bars.ApplyAlpha() end
	if ns.Auras and ns.Auras.ApplyAlpha then ns.Auras.ApplyAlpha() end
	if ns.Hosted and ns.Hosted.ApplyAlpha then ns.Hosted.ApplyAlpha() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
	"PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_FLAGS" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, unit)
	if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "UNIT_FLAGS") and unit ~= "player" then return end
	V.Apply()
end)
