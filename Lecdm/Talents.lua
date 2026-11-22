-- Lecdm: your talents, for an icon bar spell's "only with (or without) a talent" condition.
-- Forever's talents are one trait tree for the class, with a group per talent tree (Arms, Fury,
-- Protection); a node with a rank bought is a talent taken. Read when first needed and again
-- after a talent change; nothing here is read in a way the game could refuse silently: every
-- value is checked, and anything unreadable means "don't know", so conditions let spells show.
local _, ns = ...

local T = {}
ns.Talents = T

local cache -- { list = { { nodeID, name, tree } ... }, taken = { [nodeID] = true }, known = bool }

local function Number(v)
	if type(v) == "number" and not ns.IsSecret(v) then return v end
end

local function Text(v)
	if type(v) == "string" and v ~= "" and not ns.IsSecret(v) then return v end
end

local function Read()
	local result = { list = {}, taken = {}, known = false }
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
		and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then
		return result
	end
	local configID = Number(C_ClassTalents.GetActiveConfigID())
	local info = configID and C_Traits.GetConfigInfo(configID)
	local treeID = info and info.treeIDs and Number(info.treeIDs[1])
	if not treeID then return result end
	local trees = {}
	if C_Traits.GetGroupDisplayInfoByTreeID then
		for _, g in ipairs(C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}) do
			if Number(g.groupID) then trees[g.groupID] = Text(g.displayName) end
		end
	end
	for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
		local node = Number(nodeID) and C_Traits.GetNodeInfo(configID, nodeID)
		local entryID = node and node.entryIDs and Number(node.entryIDs[1])
		local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
		local def = entry and Number(entry.definitionID) and C_Traits.GetDefinitionInfo(entry.definitionID)
		local spellID = def and Number(def.spellID)
		local name = def and (Text(def.overrideName) or (spellID and ns.Bars.SpellName(spellID)))
		if name and node.isVisible ~= false then
			local group = node.groupIDs and Number(node.groupIDs[1])
			result.list[#result.list + 1] = { nodeID, name, group and trees[group] or "Talents" }
			if (Number(node.ranksPurchased) or Number(node.activeRank) or 0) > 0 then result.taken[nodeID] = true end
		end
	end
	result.known = #result.list > 0
	return result
end

-- The talents (by tree, then name) and the ones taken; known is false where the game didn't say.
function T.Read()
	if not cache then
		local ok, result = pcall(Read)
		cache = ok and result or { list = {}, taken = {}, known = false }
		table.sort(cache.list, function(a, b)
			if a[3] ~= b[3] then return a[3] < b[3] end
			return a[2] < b[2]
		end)
	end
	return cache
end

-- Whether a talent is taken: true, false, or nil (the game didn't say).
function T.Taken(nodeID)
	local t = T.Read()
	if not t.known then return nil end
	return t.taken[nodeID] == true
end

function T.Name(nodeID)
	for _, e in ipairs(T.Read().list) do
		if e[1] == nodeID then return e[2] end
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "SPELLS_CHANGED" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function()
	cache = nil
	if ns.db and ns.Bars then ns.Bars.UpdateAll() end
end)
