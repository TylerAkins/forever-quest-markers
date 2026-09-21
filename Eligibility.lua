local ADDON_NAME, ns = ...

local function Call(apiTable, name, ...)
    local fn = apiTable and apiTable[name]
    if type(fn) == "function" then
        return fn(...)
    end
end

local completedLookup
local completedLookupReady = false

function ns.InvalidateCompletionCache()
    completedLookup = nil
    completedLookupReady = false
end

local function CompletedLookup()
    if completedLookupReady then
        return completedLookup
    end
    completedLookupReady = true
    local lookup = {}
    if GetQuestsCompleted then
        local ok, completed = pcall(GetQuestsCompleted)
        if ok and type(completed) == "table" then
            for key, value in pairs(completed) do
                if type(value) == "number" then
                    lookup[value] = true
                elseif value then
                    local id = tonumber(key)
                    if id then
                        lookup[id] = true
                    end
                end
            end
        end
    end
    local ids = Call(C_QuestLog, "GetAllCompletedQuestIDs")
    if type(ids) == "table" then
        for key, value in pairs(ids) do
            if type(value) == "number" then
                lookup[value] = true
            elseif value and type(key) == "number" then
                lookup[key] = true
            elseif value then
                local id = tonumber(key)
                if id then
                    lookup[id] = true
                end
            end
        end
    end
    completedLookup = lookup
    return lookup
end

function ns.IsQuestFlaggedCompleted(questID)
    if not questID then
        return false
    end
    if Call(C_QuestLog, "IsQuestFlaggedCompleted", questID) then
        return true
    end
    if Call(C_QuestLog, "IsQuestFlaggedCompletedOnAccount", questID) then
        return true
    end
    if IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) then
        return true
    end
    -- Some Forever builds leave object-started quests (the Ravaged Caravan
    -- crate) out of C_QuestLog but still return them from GetQuestsCompleted
    -- or GetAllCompletedQuestIDs.
    local lookup = CompletedLookup()
    if lookup and lookup[questID] then
        return true
    end
    return false
end

function ns.HasQuestCompletionAPI()
    return (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted)
        or (C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount)
        or (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs)
        or IsQuestFlaggedCompleted
        or GetQuestsCompleted
        or false
end

function ns.HasQuestGiver(data)
    if not data then
        return false
    end
    if data.qg then
        return true
    end
    if data.qgs and data.qgs[1] then
        return true
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

local titleCache = {}
local npcNameCache = {}
local requestedTitles = {}
local requestedLevels = {}
local npcTip

local function RememberTitle(questID, title)
    if questID and type(title) == "string" and title ~= "" then
        titleCache[questID] = title
        return title
    end
    return nil
end

local function ReadQuestTitle(questID)
    local title = Call(C_QuestLog, "GetTitleForQuestID", questID)
    if RememberTitle(questID, title) then
        return titleCache[questID]
    end
    title = Call(C_QuestLog, "GetQuestInfo", questID)
    if type(title) == "string" then
        return RememberTitle(questID, title)
    end
    if type(title) == "table" then
        return RememberTitle(questID, title.title)
    end
    return nil
end

function ns.RequestQuestTitle(questID)
    if not questID or requestedTitles[questID] or titleCache[questID] then
        return
    end
    requestedTitles[questID] = true
    Call(C_QuestLog, "RequestLoadQuestByID", questID)
end

function ns.GetQuestTitle(questID)
    if not questID then
        return nil
    end
    if titleCache[questID] then
        return titleCache[questID]
    end
    local title = ReadQuestTitle(questID)
    if title then
        return title
    end
    ns.RequestQuestTitle(questID)
    return nil
end

-- Suggested quest level (tracker [9]), not ATT minLevel. Forever exposes this
-- for unaccepted IDs via C_QuestLog.GetQuestDifficultyLevel.
function ns.GetQuestDifficultyLevel(questID)
    if not questID then
        return nil
    end
    local level = Call(C_QuestLog, "GetQuestDifficultyLevel", questID)
    if type(level) == "number" and level > 0 then
        return level
    end
    if not requestedLevels[questID] then
        requestedLevels[questID] = true
        Call(C_QuestLog, "RequestLoadQuestByID", questID)
    end
    return nil
end

function ns.GetQuestDifficultyRGB(level)
    if type(level) ~= "number" then
        return 1, 0.82, 0
    end
    if GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)
        if type(color) == "table" and color.r then
            return color.r, color.g, color.b
        end
    end
    return 1, 0.82, 0
end

function ns.OnQuestDataLoad(questID)
    if not questID then
        return
    end
    requestedTitles[questID] = nil
    requestedLevels[questID] = nil
    ReadQuestTitle(questID)
    if ns.MapPins and ns.MapPins.OnTitleLoaded then
        ns.MapPins:OnTitleLoaded(questID)
    end
    if ns.NPCTooltips then ns.NPCTooltips:Refresh() end
end

local function CacheNPCName(npcID, name)
    if npcID and type(name) == "string" and name ~= "" and name ~= "Unknown" then
        npcNameCache[npcID] = name
        return name
    end
    return nil
end

local function NPCNameFromTooltipInfo(npcID)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
        return nil
    end
    local ok, info = pcall(C_TooltipInfo.GetHyperlink, "unit:Creature-0-0-0-0-" .. npcID .. "-0000000000")
    if not ok or type(info) ~= "table" then
        return nil
    end
    local lines = info.lines
    local first = lines and lines[1]
    local text = first and (first.leftText or first.LeftText)
    return CacheNPCName(npcID, text)
end

local function EnsureNPCTooltip()
    if npcTip then
        return npcTip
    end
    local ok, tip = pcall(CreateFrame, "GameTooltip", "ForeverQuestPinsNpcTip", UIParent, "GameTooltipTemplate")
    if not ok then
        return nil
    end
    npcTip = tip
    npcTip:SetOwner(UIParent, "ANCHOR_NONE")
    return npcTip
end

local function NPCNameFromScanner(npcID)
    local tip = EnsureNPCTooltip()
    if not tip or not tip.SetHyperlink then
        return nil
    end
    tip:ClearLines()
    local ok = pcall(tip.SetHyperlink, tip, "unit:Creature-0-0-0-0-" .. npcID .. "-0000000000")
    if not ok then
        return nil
    end
    local fontString = _G["ForeverQuestPinsNpcTipTextLeft1"]
    local text = fontString and fontString.GetText and fontString:GetText()
    return CacheNPCName(npcID, text)
end

function ns.GetNPCName(npcID)
    if not npcID then
        return nil
    end
    if npcNameCache[npcID] then
        return npcNameCache[npcID]
    end
    return NPCNameFromTooltipInfo(npcID) or NPCNameFromScanner(npcID)
end

function ns.PrefetchQuestInfo(questID, data)
    ns.GetQuestTitle(questID)
    ns.GetQuestDifficultyLevel(questID)
    ns.RequestQuestTitle(questID)
    local qg = data and (data.qg or (data.qgs and data.qgs[1]))
    if qg then
        ns.GetNPCName(qg)
    end
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

function ns.IsEventActive(eventID)
    if not eventID then
        return false
    end
    if C_Calendar and C_Calendar.IsEventActive then
        local ok, active = pcall(C_Calendar.IsEventActive, eventID)
        if ok and active then
            return true
        end
    end
    if IsHolidayActive then
        local ok, active = pcall(IsHolidayActive, eventID)
        if ok and active then
            return true
        end
    end
    return false
end

-- ATT: sourceQuests is AND unless sourceQuestNumRequired is set.
-- sourceQuestNumRequired = 1 means any one prerequisite (OR).
-- sourceQuestNumRequired = 0 means no prerequisite is required.
--
-- Object-started prereqs (no quest-giver NPC) often never flag completed on
-- Forever. The Ravaged Caravan crate (751) is the gate for Morin Cloudstalker's
-- The Venture Co. (764) and Supervisor Fizsprocket (765). If that source is
-- not in the log and its own source quests are met, treat it as satisfied.
local SourceSatisfied, SourceQuestsMet, CountCompleted

CountCompleted = function(questIDs)
    local count = 0
    for i = 1, #questIDs do
        if SourceSatisfied(questIDs[i]) then
            count = count + 1
        end
    end
    return count
end

SourceSatisfied = function(questID)
    if ns.IsQuestFlaggedCompleted(questID) then
        return true
    end
    local data = ns.Quests and ns.Quests[questID]
    -- Breadcrumbs are skippable. Kaltunk's "Your Place in the World" (4641)
    -- must not hide Gornek's Cutting Teeth (788).
    if data and data.isBreadcrumb then
        return true
    end
    if not data or ns.HasQuestGiver(data) then
        return false
    end
    if ns.IsOnQuest(questID) then
        return false
    end
    local sources = data.sourceQuests
    if not sources or #sources == 0 then
        return false
    end
    local ok = SourceQuestsMet(data)
    return ok
end

SourceQuestsMet = function(data)
    local sourceQuests = data.sourceQuests
    if not sourceQuests or #sourceQuests == 0 then
        return true, "no-prereq"
    end
    if not ns.HasQuestCompletionAPI() then
        return true, "prereq-unknown"
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

function ns.IsSourceSatisfied(questID)
    return SourceSatisfied(questID)
end

ns.offeredQuestIDs = ns.offeredQuestIDs or {}
ns.lastOffer = nil

function ns.IsOffered(questID)
    return questID and ns.offeredQuestIDs[questID] and true or false
end

function ns.SetLastOfferNPC(qg, mapID, x, y)
    ns.lastOffer = { qg = qg, mapID = mapID, x = x, y = y }
end

function ns.NoteOfferedQuest(questID)
    questID = tonumber(questID)
    if not questID then
        return
    end
    ns.offeredQuestIDs[questID] = true
    if ns.Quests and ns.Quests[questID] then
        return
    end
    local offer = ns.lastOffer
    if not offer or not offer.mapID or not offer.x or not offer.y then
        return
    end
    ns.Quests = ns.Quests or {}
    ns.ByMap = ns.ByMap or {}
    ns.Quests[questID] = {
        mapID = offer.mapID,
        x = offer.x,
        y = offer.y,
        qg = offer.qg,
    }
    local list = ns.ByMap[offer.mapID]
    if not list then
        list = {}
        ns.ByMap[offer.mapID] = list
    end
    list[#list + 1] = questID
    if ns.NPCTooltips then ns.NPCTooltips:InvalidateIndex() end
end

function ns.CaptureOfferContext()
    local guid = UnitGUID and (UnitGUID("npc") or UnitGUID("questnpc") or UnitGUID("target"))
    local qg
    if type(guid) == "string" then
        qg = tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID and ns.GetViewedMapID then
        mapID = ns.GetViewedMapID()
    end
    local x, y
    if mapID and C_Map and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        if ok and pos then
            if pos.GetXY then
                x, y = pos:GetXY()
            else
                x, y = pos.x, pos.y
            end
        end
    end
    if x and y and x <= 1 and y <= 1 then
        x, y = x * 100, y * 100
    end
    ns.SetLastOfferNPC(qg, mapID, x, y)
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
    if data.repeatable and not ns.GetOption("showRepeatable") then
        return false, "repeatable"
    end
    if ns.IsOffered and ns.IsOffered(questID) then
        return true, "npc-offered"
    end

    if (data.isYearly or data.event) and not ns.GetOption("showSeasonal") then
        if not ns.IsEventActive(data.event) then
            return false, "seasonal"
        end
    end

    if ns.IsWarEffortQuest and ns.IsWarEffortQuest(questID, data) and not ns.GetOption("showWarEffort") then
        return false, "war-effort"
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
