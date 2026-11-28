local _, ns = ...

-- Use the special item on the quest the tracker currently highlights. The
-- client owns cooldown, range, and usability checks, so this only resolves the
-- selected quest to its log index and hands the index to the same API the
-- tracker's item button uses.

local function SuperTrackedQuestID()
    if not C_SuperTrack or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return nil
    end
    local ok, questID = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if ok and type(questID) == "number" and questID > 0 then
        return questID
    end
    return nil
end

local function SelectedLogQuestID()
    if C_QuestLog and type(C_QuestLog.GetSelectedQuest) == "function" then
        local ok, value = pcall(C_QuestLog.GetSelectedQuest)
        if ok and type(value) == "number" and value > 0 then
            -- Modern clients return the quest ID here; older builds return the
            -- log index. A value that resolves as a log index is an index.
            if type(C_QuestLog.GetQuestIDForLogIndex) == "function" then
                local okQuest, questID = pcall(C_QuestLog.GetQuestIDForLogIndex, value)
                if okQuest and type(questID) == "number" and questID > 0 then
                    return questID
                end
            end
            return value
        end
    end
    if type(GetQuestLogSelection) == "function" then
        local ok, index = pcall(GetQuestLogSelection)
        if not ok or type(index) ~= "number" or index <= 0 then
            return nil
        end
        if C_QuestLog and type(C_QuestLog.GetQuestIDForLogIndex) == "function" then
            local okQuest, questID = pcall(C_QuestLog.GetQuestIDForLogIndex, index)
            if okQuest and type(questID) == "number" and questID > 0 then
                return questID
            end
        end
        if type(GetQuestLogTitle) == "function" then
            local okTitle, _, _, _, _, _, _, _, questID = pcall(GetQuestLogTitle, index)
            if okTitle and type(questID) == "number" and questID > 0 then
                return questID
            end
        end
    end
    return nil
end

local function SelectedQuestID()
    return SuperTrackedQuestID() or SelectedLogQuestID()
end

--- Use the special item on the selected tracked quest. Returns true when the
-- client accepted the use request; a missing quest or item is a quiet false.
function ns.UseTrackedQuestItem()
    if not C_QuestLog or type(C_QuestLog.GetLogIndexForQuestID) ~= "function" then
        return false
    end
    local questID = SelectedQuestID()
    if not questID then
        return false
    end
    local okIndex, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not okIndex or type(index) ~= "number" or index <= 0 then
        return false
    end
    if type(GetQuestLogSpecialItemInfo) ~= "function"
        or type(UseQuestLogSpecialItem) ~= "function" then
        return false
    end
    local okInfo, itemID, _, _, _, isUsable = pcall(GetQuestLogSpecialItemInfo, index)
    if not okInfo or not itemID or isUsable == false then
        return false
    end
    return pcall(UseQuestLogSpecialItem, index) == true
end

-- Bindings.xml calls this global.
function ForeverQuestPins_UseTrackedQuestItem()
    if ns.UseTrackedQuestItem then
        ns.UseTrackedQuestItem()
    end
end
