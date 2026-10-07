local ADDON_NAME, ns = ...

ns.NPCTooltips = {}
local Tooltips = ns.NPCTooltips
local starters
local initialized = false

local function NpcIDFromUnit(unit)
    if not unit then
        return nil
    end
    if UnitGUID then
        return ns.NpcIDFromGUID(UnitGUID(unit))
    end
    return nil
end

local function IndexStarter(index, npcID, questID)
    if not npcID then
        return
    end
    index[npcID] = index[npcID] or {}
    index[npcID][questID] = true
end

function Tooltips:InvalidateStarterIndex()
    starters = nil
end

local function BuildStarterIndex()
    if starters then
        return
    end
    starters = {}
    for questID, data in pairs(ns.Quests or {}) do
        IndexStarter(starters, data.qg, questID)
        for _, npcID in ipairs(data.qgs or {}) do
            IndexStarter(starters, npcID, questID)
        end
    end
end

local function QuestLine(questID)
    local title = ns.GetQuestTitle(questID) or ("Quest %d (title unavailable)"):format(questID)
    local level = ns.GetQuestDifficultyLevel and ns.GetQuestDifficultyLevel(questID)
    if level then
        return ("[%d] %s"):format(level, title), level
    end
    return title, nil
end

function Tooltips:GetAcceptRows(npcID)
    BuildStarterIndex()
    local bucket = starters[npcID]
    if not bucket then
        return {}
    end
    local rows = {}
    for questID in pairs(bucket) do
        local data = ns.Quests and ns.Quests[questID]
        if ns.NpcOffersQuestAccept(npcID, questID, data) then
            if ns.PrefetchQuestInfo then
                ns.PrefetchQuestInfo(questID, data)
            end
            local available = ns.IsQuestAvailable(questID, data)
            if available then
                local text, level = QuestLine(questID)
                rows[#rows + 1] = {
                    id = questID,
                    text = text,
                    level = level,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.level ~= b.level then
            return (a.level or math.huge) < (b.level or math.huge)
        end
        return a.id < b.id
    end)
    return rows
end

local function AddQuestLine(tooltip, row)
    local r, g, b = 1, 0.82, 0
    if ns.GetQuestDifficultyRGB and row.level then
        r, g, b = ns.GetQuestDifficultyRGB(row.level)
    end
    tooltip:AddLine("! " .. row.text, r, g, b, true)
end

function Tooltips:AppendAcceptRows(tooltip, unit)
    if tooltip ~= GameTooltip or not ns.GetOption("showNPCTooltips") then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    if IsInInstance and IsInInstance() then
        return
    end
    if not unit and tooltip.GetUnit then
        _, unit = tooltip:GetUnit()
    end
    local npcID = NpcIDFromUnit(unit)
    if not npcID or tooltip.fqpQuestRows then
        return
    end
    local accepts = self:GetAcceptRows(npcID)
    if #accepts == 0 then
        return
    end
    tooltip.fqpQuestRows = true
    for _, row in ipairs(accepts) do
        AddQuestLine(tooltip, row)
    end
    tooltip:Show()
end

function Tooltips:Initialize()
    if initialized or not GameTooltip then
        return
    end
    initialized = true
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
        tooltip.fqpQuestRows = nil
    end)
    local function OnUnitTooltip(tooltip)
        self:AppendAcceptRows(tooltip)
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if tooltip == GameTooltip then
                OnUnitTooltip(tooltip)
            end
        end)
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", OnUnitTooltip)
    else
        hooksecurefunc(GameTooltip, "SetUnit", function(tooltip)
            OnUnitTooltip(tooltip)
        end)
    end
end
