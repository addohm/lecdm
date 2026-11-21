-- Lecdm: when an icon bar, buff group or Blizzard place shows. Each has `showWhen` ("always",
-- "combat": only in combat, "target": in combat or while you have a target), `alpha` (its
-- opacity) and `oocAlpha` (out of combat, a fraction of that). Shown or not is opacity only: our
-- frames and the aura containers in them are never hidden in combat, so nothing protected moves.
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

-- The opacity a thing with these settings has now.
function V.Alpha(cfg)
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
events:SetScript("OnEvent", function() V.Apply() end)
