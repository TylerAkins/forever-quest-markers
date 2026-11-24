local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Pure data for the optional quest tracker: quest-log zone headers, the
-- current-zone chain, distance, and the sort/filter view. Tracker.lua owns the
-- Blizzard tracker module and calls this file.

local zoneChainCache
local lastZoneMapID
local distanceCache = {}
local annotationCache = {}

local function InCombat()
    if InCombatLockdown then
        local ok, value = pcall(InCombatLockdown)
        if ok then
            return value and true or false
        end
    end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

local function CharacterKey()
    return ns.CharacterKey and ns.CharacterKey()
end

local function CollapseBucket(create)
    local db = ns.db
    local key = CharacterKey()
    if type(db) ~= "table" or not key then
        return nil
    end
    local all = db.trackerCollapsedZones
    if type(all) ~= "table" then
        if not create then
            return nil
        end
        all = {}
        db.trackerCollapsedZones = all
    end
    local bucket = all[key]
    if type(bucket) ~= "table" then
        if not create then
            return nil
        end
        bucket = {}
        all[key] = bucket
    end
    return bucket
end

function ns.IsZoneCollapsed(zone)
    local bucket = CollapseBucket(false)
    return bucket ~= nil and type(zone) == "string" and bucket[zone] == true
end

function ns.SetZoneCollapsed(zone, collapsed)
    if type(zone) ~= "string" or zone == "" then
        return false
    end
    local bucket = CollapseBucket(true)
    if not bucket then
        return false
    end
    if collapsed then
        bucket[zone] = true
    else
        bucket[zone] = nil
    end
    return true
end

function ns.ToggleZoneCollapsed(zone)
    return ns.SetZoneCollapsed(zone, not ns.IsZoneCollapsed(zone))
end

local function NearestHeaderTitle(startIndex)
    if not C_QuestLog or type(C_QuestLog.GetInfo) ~= "function" then
        return nil
    end
    local index = tonumber(startIndex)
    if not index then
        return nil
    end
    local guard = 0
    while index >= 1 and guard < 500 do
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if not ok or not info then
            return nil
        end
        if info.isHeader then
            local title = info.title
            if type(title) == "string" and title ~= "" then
                return title
            end
            return nil
        end
        index = index - 1
        guard = guard + 1
    end
    return nil
end

-- Returns the quest-log header the game already shows this quest under.
function ns.QuestHeaderTitle(questID)
    if not C_QuestLog or type(C_QuestLog.GetInfo) ~= "function" then
        return nil
    end
    if type(C_QuestLog.GetHeaderIndexForQuest) == "function" then
        local ok, index = pcall(C_QuestLog.GetHeaderIndexForQuest, questID)
        if ok and index then
            local okInfo, info = pcall(C_QuestLog.GetInfo, index)
            if okInfo and info then
                if info.isHeader then
                    local title = info.title
                    if type(title) == "string" and title ~= "" then
                        return title
                    end
                else
                    local title = NearestHeaderTitle(index)
                    if title then
                        return title
                    end
                end
            end
        end
    end
    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and index then
            return NearestHeaderTitle(index - 1)
        end
    end
    return nil
end

local function MapChainNames(mapID)
    local names = {}
    if not C_Map or type(C_Map.GetMapInfo) ~= "function" then
        return names
    end
    local types = Enum and Enum.UIMapType
    local continentType = types and types.Continent or 2
    local worldType = types and types.World or 1
    local seen = {}
    local depth = 0
    while mapID and not seen[mapID] and depth < 20 do
        seen[mapID] = true
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if not ok or not info then
            break
        end
        if info.mapType == continentType or info.mapType == worldType then
            break
        end
        if type(info.name) == "string" and info.name ~= "" then
            names[info.name] = true
        end
        mapID = info.parentMapID
        depth = depth + 1
    end
    return names
end

function ns.CurrentZoneNames()
    if zoneChainCache then
        return zoneChainCache
    end
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return nil
    end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok or not mapID then
        return nil
    end
    lastZoneMapID = mapID
    zoneChainCache = MapChainNames(mapID)
    return zoneChainCache
end

function ns.InvalidateZoneChain()
    zoneChainCache = nil
    if not InCombat() then
        distanceCache = {}
        annotationCache = {}
    end
end

function ns.CanGroupTrackerQuests()
    return C_QuestLog ~= nil
        and type(C_QuestLog.GetInfo) == "function"
        and type(C_QuestLog.GetHeaderIndexForQuest) == "function"
end

function ns.OnTrackerZoneChanged(force)
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        if force then
            ns.InvalidateZoneChain()
            if ns.MarkTrackerDirty then
                ns.MarkTrackerDirty(true)
            end
        end
        return
    end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then
        return
    end
    if not force and mapID == lastZoneMapID then
        return
    end
    lastZoneMapID = mapID
    ns.InvalidateZoneChain()
    if ns.MarkTrackerDirty then
        ns.MarkTrackerDirty(true)
    end
end

local function QuestDistance(questID)
    if type(questID) ~= "number" then
        return nil, nil
    end
    if InCombat() then
        local cached = distanceCache[questID]
        return cached and cached.distanceSq, cached and cached.onContinent
    end
    if not C_QuestLog or type(C_QuestLog.GetDistanceSqToQuest) ~= "function" then
        return nil, nil
    end
    local ok, distanceSq, onContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
    if not ok then
        return nil, nil
    end
    distanceCache[questID] = { distanceSq = distanceSq, onContinent = onContinent }
    return distanceSq, onContinent
end

local function QuestMatchesZone(info, zoneChain)
    if not zoneChain then
        return false
    end
    if info.zoneName and zoneChain[info.zoneName] then
        return true
    end
    if not C_QuestLog or type(C_QuestLog.GetNextWaypoint) ~= "function" then
        return false
    end
    local ok, mapID = pcall(C_QuestLog.GetNextWaypoint, info.questID)
    if not ok or not mapID then
        return false
    end
    local names = MapChainNames(mapID)
    for name in pairs(names) do
        if zoneChain[name] then
            return true
        end
    end
    return false
end

local function TrackerFilterMatch(entry, filter)
    if filter == "current" then
        return entry.isCurrentZone == true
    end
    if filter == "instance" then
        return entry.isInstance == true
    end
    if filter == "completed" then
        return entry.isComplete == true
    end
    return true
end

local function QuestIsComplete(quest)
    if not quest or type(quest.IsComplete) ~= "function" then
        return false
    end
    local ok, value = pcall(quest.IsComplete, quest)
    return ok and value == true
end

local function KnownNumber(value)
    return type(value) == "number" and value == value
end

local function CompareBlizzard(a, b)
    return a.order < b.order
end

local function CompareDistance(a, b)
    local aKnown = KnownNumber(a.distanceSq) and a.onContinent ~= false
    local bKnown = KnownNumber(b.distanceSq) and b.onContinent ~= false
    if aKnown ~= bKnown then
        return aKnown
    end
    if aKnown and bKnown and a.distanceSq ~= b.distanceSq then
        return a.distanceSq < b.distanceSq
    end
    return a.order < b.order
end

local function CompareLevel(a, b)
    local aKnown = KnownNumber(a.level)
    local bKnown = KnownNumber(b.level)
    if aKnown ~= bKnown then
        return aKnown
    end
    if aKnown and bKnown and a.level ~= b.level then
        return a.level < b.level
    end
    if a.title ~= b.title then
        return a.title < b.title
    end
    return a.order < b.order
end

local function CompareTitle(a, b)
    if a.title ~= b.title then
        return a.title < b.title
    end
    return a.order < b.order
end

local COMPARATORS = {
    blizzard = CompareBlizzard,
    distance = CompareDistance,
    level = CompareLevel,
    title = CompareTitle,
}

local function GroupSortValue(entry, sort)
    if sort == "distance" then
        if KnownNumber(entry.distanceSq) and entry.onContinent ~= false then
            return entry.distanceSq
        end
        return nil
    end
    if sort == "level" then
        if KnownNumber(entry.level) then
            return entry.level
        end
        return nil
    end
    if sort == "title" then
        return entry.title
    end
    return entry.order
end

function ns.SortTrackerInfos(entries, sort)
    sort = COMPARATORS[sort] and sort or "blizzard"
    local groups = {}
    local groupOrder = {}
    for i = 1, #entries do
        local entry = entries[i]
        local group = groups[entry.zoneName]
        if not group then
            group = { name = entry.zoneName, entries = {}, isCurrent = false }
            groups[entry.zoneName] = group
            groupOrder[#groupOrder + 1] = group
        end
        group.entries[#group.entries + 1] = entry
        if entry.isCurrentZone then
            group.isCurrent = true
        end
    end
    local comparator = COMPARATORS[sort]
    for i = 1, #groupOrder do
        table.sort(groupOrder[i].entries, comparator)
    end
    table.sort(groupOrder, function(a, b)
        if a.isCurrent ~= b.isCurrent then
            return a.isCurrent
        end
        local aKey = GroupSortValue(a.entries[1], sort)
        local bKey = GroupSortValue(b.entries[1], sort)
        if sort == "title" then
            if aKey ~= bKey then
                return aKey < bKey
            end
        else
            local aKnown = aKey ~= nil
            local bKnown = bKey ~= nil
            if aKnown ~= bKnown then
                return aKnown
            end
            if aKnown and aKey ~= bKey then
                return aKey < bKey
            end
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.entries[1].order < b.entries[1].order
    end)
    local result = {}
    for i = 1, #groupOrder do
        local groupEntries = groupOrder[i].entries
        for j = 1, #groupEntries do
            result[#result + 1] = groupEntries[j]
        end
    end
    return result
end

function ns.EnhanceQuestWatchInfos(tracker, infos)
    if type(infos) ~= "table" or #infos == 0 then
        return infos
    end
    if not ns.CanGroupTrackerQuests() then
        return infos
    end
    local sort = ns.GetOption("trackerSort")
    if sort == "distance"
        and (not C_QuestLog or type(C_QuestLog.GetDistanceSqToQuest) ~= "function") then
        sort = "blizzard"
    end
    local filter = ns.GetOption("trackerFilter")
    local zoneChain = ns.CurrentZoneNames()
    local inCombat = InCombat()
    local annotated = {}
    for i = 1, #infos do
        local info = infos[i]
        local quest = info.quest
        local questID = quest and quest.GetID and quest:GetID()
        if type(questID) == "number" then
            local entry
            local cached = inCombat and annotationCache[questID]
            if cached then
                entry = {
                    quest = quest,
                    index = info.index or i,
                    order = i,
                    questID = questID,
                    zoneName = cached.zoneName,
                    isInstance = cached.isInstance,
                    isComplete = cached.isComplete,
                    level = cached.level,
                    title = cached.title,
                    distanceSq = cached.distanceSq,
                    onContinent = cached.onContinent,
                    isCurrentZone = cached.isCurrentZone,
                }
            else
                local title = quest.title
                if inCombat then
                    -- A quest first seen in combat has no cached annotation.
                    -- Keep it under Other without touching restricted query APIs.
                    entry = {
                        quest = quest,
                        index = info.index or i,
                        order = i,
                        questID = questID,
                        zoneName = L["Other"],
                        isInstance = false,
                        isComplete = QuestIsComplete(quest),
                        level = nil,
                        title = type(title) == "string" and title or tostring(questID),
                        distanceSq = nil,
                        onContinent = nil,
                        isCurrentZone = false,
                    }
                else
                    local distanceSq, onContinent = QuestDistance(questID)
                    if type(title) ~= "string" and C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
                        title = C_QuestLog.GetTitleForQuestID(questID)
                    end
                    local level = quest.level
                    if not KnownNumber(level) and C_QuestLog and type(C_QuestLog.GetQuestDifficultyLevel) == "function" then
                        local ok, value = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
                        if ok then
                            level = value
                        end
                    end
                    if not KnownNumber(level) or level <= 0 then
                        level = nil
                    end
                    local isInstance = false
                    if ns.IsInstanceQuest then
                        local ok, value = pcall(ns.IsInstanceQuest, questID, ns.Quests and ns.Quests[questID])
                        if ok then
                            isInstance = value and true or false
                        end
                    end
                    entry = {
                        quest = quest,
                        index = info.index or i,
                        order = i,
                        questID = questID,
                        zoneName = ns.QuestHeaderTitle(questID) or L["Other"],
                        isInstance = isInstance,
                        isComplete = QuestIsComplete(quest),
                        level = level,
                        title = type(title) == "string" and title or tostring(questID),
                        distanceSq = distanceSq,
                        onContinent = onContinent,
                    }
                    entry.isCurrentZone = QuestMatchesZone(entry, zoneChain)
                    annotationCache[questID] = {
                        zoneName = entry.zoneName,
                        isInstance = entry.isInstance,
                        isComplete = entry.isComplete,
                        level = entry.level,
                        title = entry.title,
                        distanceSq = entry.distanceSq,
                        onContinent = entry.onContinent,
                        isCurrentZone = entry.isCurrentZone,
                    }
                end
            end
            if TrackerFilterMatch(entry, filter) then
                annotated[#annotated + 1] = entry
            end
        end
    end
    return ns.SortTrackerInfos(annotated, sort)
end
