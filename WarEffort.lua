local ADDON_NAME, ns = ...

-- Classic Ahn'Qiraj opening "war effort" commodity turn-ins at faction capitals
-- (Senior Sergeants, signet hand-ins, "Needs Your Help" banner quests). Pins stack
-- heavily in Orgrimmar / Ironforge; players can hide them without losing other starts.
local WAR_EFFORT_NPCS = {
    [15383] = true,
    [15431] = true,
    [15432] = true,
    [15434] = true,
    [15437] = true,
    [15445] = true,
    [15446] = true,
    [15448] = true,
    [15450] = true,
    [15451] = true,
    [15452] = true,
    [15453] = true,
    [15455] = true,
    [15456] = true,
    [15457] = true,
    [15459] = true,
    [15460] = true,
    [15469] = true,
    [15477] = true,
    [15508] = true,
    [15512] = true,
    [15515] = true,
    [15522] = true,
    [15525] = true,
    [15528] = true,
    [15529] = true,
    [15532] = true,
    [15533] = true,
    [15534] = true,
    [15535] = true,
    [15704] = true,
    [15707] = true,
}

local function NpcIsWarEffort(npcID)
    return npcID ~= nil and WAR_EFFORT_NPCS[npcID] == true
end

function ns.IsWarEffortQuest(questID, data)
    if not questID or not data then
        return false
    end
    if data.isWarEffort then
        return true
    end
    if questID >= 8780 and questID <= 8789 then
        return true
    end
    if NpcIsWarEffort(data.qg) then
        return true
    end
    local qgs = data.qgs
    if qgs then
        for i = 1, #qgs do
            if NpcIsWarEffort(qgs[i]) then
                return true
            end
        end
    end
    return false
end
