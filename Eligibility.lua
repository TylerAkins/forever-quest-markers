local ADDON_NAME, ns = ...

local function Call(apiTable, name, ...)
    local fn = apiTable and apiTable[name]
    if type(fn) == "function" then
        return fn(...)
    end
end

function ns.IsQuestFlaggedCompleted(questID)
    if not questID then
        return false
    end
    local flagged = Call(C_QuestLog, "IsQuestFlaggedCompleted", questID)
    if flagged ~= nil then
        return flagged and true or false
    end
    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID) and true or false
    end
    return false
end

function ns.IsOnQuest(questID)
    if not questID then
        return false
    end
    local onQuest = Call(C_QuestLog, "IsOnQuest", questID)
    if onQuest ~= nil then
        return onQuest and true or false
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        return index and index > 0 or false
    end
    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(questID)
        return index and index > 0 or false
    end
    return false
end

function ns.GetQuestTitle(questID)
    if not questID then
        return nil
    end
    local title = Call(C_QuestLog, "GetTitleForQuestID", questID)
    if title and title ~= "" then
        return title
    end
    title = Call(C_QuestLog, "GetQuestInfo", questID)
    if type(title) == "string" and title ~= "" then
        return title
    end
    if type(title) == "table" and title.title then
        return title.title
    end
    return nil
end

function ns.GetPlayerRaceID()
    local _, _, raceID = UnitRace("player")
    return raceID
end

function ns.GetPlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

function ns.GetPlayerFaction()
    return UnitFactionGroup("player")
end

local function CountCompleted(questIDs)
    local count = 0
    for i = 1, #questIDs do
        if ns.IsQuestFlaggedCompleted(questIDs[i]) then
            count = count + 1
        end
    end
    return count
end

-- ATT: sourceQuests is AND unless sourceQuestNumRequired is set.
-- sourceQuestNumRequired = 1 means any one prerequisite (OR).
-- sourceQuestNumRequired = 0 means no prerequisite is required.
local function SourceQuestsMet(data)
    local sourceQuests = data.sourceQuests
    if not sourceQuests or #sourceQuests == 0 then
        return true, "no-prereq"
    end
    local required = data.sourceQuestNumRequired
    local completed = CountCompleted(sourceQuests)
    if required == 0 then
        return true, "prereq-none-required"
    end
    if required == nil then
        if completed < #sourceQuests then
            return false, "prereq-and"
        end
        return true, "prereq-and"
    end
    if completed < required then
        return false, "prereq-count"
    end
    return true, "prereq-count"
end

local function IsTrivial(data)
    local minLevel = data.minLevel
    if not minLevel then
        return false, false
    end
    local playerLevel = UnitLevel("player") or 1
    if GetQuestGreenRange then
        local greenRange = GetQuestGreenRange()
        if type(greenRange) == "number" then
            return (playerLevel - minLevel) > greenRange, true
        end
    end
    -- No reliable trivial API on this client. Do not hide the pin.
    return false, false
end

--- Conservative availability check. Unknown restrictions keep the pin visible.
-- @return available boolean
-- @return reason string
function ns.IsQuestAvailable(questID, data)
    if not questID or not data then
        return false, "bad-data"
    end
    if ns.IsQuestFlaggedCompleted(questID) then
        return false, "completed"
    end
    if ns.IsOnQuest(questID) then
        return false, "in-log"
    end

    local altQuests = data.altQuests
    if altQuests then
        for i = 1, #altQuests do
            local altID = altQuests[i]
            if altID ~= questID and ns.IsQuestFlaggedCompleted(altID) then
                return false, "alt-completed"
            end
        end
    end

    local prereqOk, prereqReason = SourceQuestsMet(data)
    if not prereqOk then
        return false, prereqReason
    end

    local faction = data.faction
    if faction then
        local playerFaction = ns.GetPlayerFaction()
        if playerFaction and playerFaction ~= faction then
            return false, "faction"
        end
    end

    local races = data.races
    if races and #races > 0 then
        local raceID = ns.GetPlayerRaceID()
        if raceID then
            local match = false
            for i = 1, #races do
                if races[i] == raceID then
                    match = true
                    break
                end
            end
            if not match then
                return false, "race"
            end
        end
    end

    local classes = data.classes
    if classes and #classes > 0 then
        local classID = ns.GetPlayerClassID()
        if classID then
            local match = false
            for i = 1, #classes do
                if classes[i] == classID then
                    match = true
                    break
                end
            end
            if not match then
                return false, "class"
            end
        end
    end

    local minLevel = data.minLevel
    local playerLevel = UnitLevel("player") or 1
    if minLevel and playerLevel < minLevel then
        return false, "low-level"
    end

    if not ns.GetOption("showTrivial") then
        local trivial, reliable = IsTrivial(data)
        if reliable and trivial then
            return false, "trivial"
        end
    end

    return true, prereqReason or "ok"
end
