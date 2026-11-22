local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Enhances Blizzard's QuestObjectiveTracker in place. The quest blocks,
-- menus, item buttons, timers, and animations remain Blizzard's; this file
-- only adds zone header blocks and a view order.

local SORT_ORDER = ns.TrackerSortOrder or { "blizzard", "distance", "level", "title" }
local FILTER_ORDER = ns.TrackerFilterOrder or { "all", "current", "instance" }
local SORT_LABELS = ns.TrackerSortLabels or {
    blizzard = L["Blizzard order"],
    distance = L["Distance"],
    level = L["Level"],
    title = L["Title"],
}
local FILTER_LABELS = ns.TrackerFilterLabels or {
    all = L["All tracked quests"],
    current = L["Current zone only"],
    instance = L["Instance quests"],
}

local registered = false
local ApplyTrackerEnhancement, RestoreTrackerEnhancement
local zoneChainCache
local distanceCache = {}
local annotationCache = {}
local lastZoneMapID
local pendingLayout = false
local ticker
local tickerToken = 0
local lastSignature

local function InCombat()
    if InCombatLockdown then
        local ok, value = pcall(InCombatLockdown)
        if ok then
            return value and true or false
        end
    end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

-- Super-tracking refreshes Blizzard map pins on the call stack. The client
-- blocks that in combat, encounters, challenge modes, and PvP matches and
-- blames the addon, so selection waits until the restriction clears.
local function AddOnActionsRestricted()
    if InCombat() then
        return true
    end
    local restricted = C_RestrictedActions
    local kinds = Enum and Enum.AddOnRestrictionType
    if type(restricted) ~= "table"
        or type(restricted.IsAddOnRestrictionActive) ~= "function"
        or type(kinds) ~= "table" then
        return false
    end
    for _, name in ipairs({ "Combat", "Encounter", "ChallengeMode", "PvPMatch" }) do
        local kind = kinds[name]
        if kind ~= nil then
            local ok, active = pcall(restricted.IsAddOnRestrictionActive, kind)
            if ok and active then
                return true
            end
        end
    end
    return false
end

ns.AddOnActionsRestricted = AddOnActionsRestricted

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

-- Returns the quest log header the game already shows this quest under.
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
    -- Match MapPins.lua's fallbacks so the continent never joins the chain.
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
            ns.NotifyTrackerOptionsChanged()
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
    ns.NotifyTrackerOptionsChanged()
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
    local canGroup = ns.CanGroupTrackerQuests()
    if not canGroup then
        return infos
    end
    local sort = ns.GetOption("trackerSort")
    if sort == "distance"
        and (not C_QuestLog or type(C_QuestLog.GetDistanceSqToQuest) ~= "function") then
        return infos
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

local function ToggleZoneHeader(block)
    if not block.zoneName then
        return
    end
    local before = ns.IsZoneCollapsed(block.zoneName)
    local ok = ns.SetZoneCollapsed(block.zoneName, not before)
    local after = ns.IsZoneCollapsed(block.zoneName)
    if ns.GetOption("debug") then
        print(("|cffffd100Forever Quest Pins:|r %s ok=%s before=%s after=%s key=%s"):format(
            block.zoneName, tostring(ok), tostring(before), tostring(after),
            tostring(CharacterKey())))
    end
    ns.NotifyTrackerOptionsChanged()
end

local function EnsureCollapseButton(block)
    if block.zoneCollapseButton then
        return block.zoneCollapseButton
    end
    local ok, button = pcall(CreateFrame, "Button", nil, block, "ObjectiveTrackerModuleMinimizeButtonTemplate")
    if not ok then
        button = CreateFrame("Button", nil, block)
        button:SetSize(16, 16)
        local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("CENTER")
        button.zoneLabel = label
    end
    button:SetPoint("RIGHT", block, "RIGHT", 0, 0)
    button:SetScript("OnClick", function()
        ToggleZoneHeader(block)
    end)
    block.zoneCollapseButton = button
    return button
end

local function UpdateCollapseButton(block, collapsed)
    local button = EnsureCollapseButton(block)
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" and InputUtil.IsGamepadUIEnabled() then
        button:Hide()
        return
    end
    button:Show()
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if normal and normal.SetAtlas then
        normal:SetAtlas(collapsed and "ui-questtrackerbutton-secondary-expand"
            or "ui-questtrackerbutton-secondary-collapse", true)
    end
    if pushed and pushed.SetAtlas then
        pushed:SetAtlas(collapsed and "ui-questtrackerbutton-secondary-expand-pressed"
            or "ui-questtrackerbutton-secondary-collapse-pressed", true)
    end
    if button.zoneLabel then
        button.zoneLabel:SetText(collapsed and "+" or "-")
    end
end

function ns.AddZoneHeader(module, zone)
    local block = module:GetBlock("zone:" .. zone, "ObjectiveTrackerBlockTemplate")
    -- In combat the client can hand back a blocked value instead of a block.
    -- Indexing it raises "indexed assignment on local 'block'"; fall back to
    -- Blizzard's flat list for this pass instead.
    if type(block) ~= "table" then
        return false
    end
    block.zoneName = zone
    block.smartNavigationIgnored = true
    block.offsetX = 0
    if module.AnchorBlock then
        module:AnchorBlock(block)
    end
    block.rightEdgeOffset = -20
    if ObjectiveTrackerHeaderFont and block.HeaderText and block.HeaderText.SetFontObject then
        block.HeaderText:SetFontObject(ObjectiveTrackerHeaderFont)
    end
    if block.HeaderButton then
        block.HeaderButton.smartNavigationIgnored = true
        block.HeaderButton:SetScript("OnClick", function()
            ToggleZoneHeader(block)
        end)
        block.HeaderButton:SetScript("OnEnter", nil)
        block.HeaderButton:SetScript("OnLeave", nil)
        block.HeaderButton:EnableMouse(true)
        block.HeaderButton:Show()
    end
    block:EnableMouse(true)
    block:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            ToggleZoneHeader(self)
        end
    end)
    block:SetHeader(zone)
    local headerColor = OBJECTIVE_TRACKER_COLOR
        and (OBJECTIVE_TRACKER_COLOR["HeaderHighlight"] or OBJECTIVE_TRACKER_COLOR["Normal"])
    if headerColor and block.HeaderText then
        block.HeaderText:SetTextColor(headerColor.r, headerColor.g, headerColor.b)
        block.HeaderText.colorStyle = headerColor
        if block.HeaderText.SetShadowColor then
            block.HeaderText:SetShadowColor(0, 0, 0, 0.9)
            block.HeaderText:SetShadowOffset(1, -1)
        end
    end
    if type(block.height) ~= "number" or block.height < 18 then
        block.height = 18
    end
    UpdateCollapseButton(block, ns.IsZoneCollapsed(zone))
    return module:LayoutBlock(block)
end

function ns.EnumEnhancedQuestWatchData(module, func)
    local infos = module:BuildQuestWatchInfos()
    if #infos > 0 and infos[1].zoneName == nil then
        -- Grouping was unavailable, so keep Blizzard's flat enumeration.
        for i = 1, #infos do
            if not func(module, infos[i].quest) then
                return true
            end
        end
        return true
    end
    local currentZone
    for i = 1, #infos do
        local info = infos[i]
        local zone = info.zoneName or L["Other"]
        if zone ~= currentZone then
            currentZone = zone
            if not ns.AddZoneHeader(module, zone) then
                -- The client refused a block (it hands back a blocked value in
                -- combat). Tell the caller so it can use Blizzard's flat list.
                return false
            end
        end
        if not ns.IsZoneCollapsed(zone) then
            if not func(module, info.quest) then
                return true
            end
        end
    end
    return true
end

local function IsZoneHeaderBlock(block)
    return block.zoneName ~= nil
        or (type(block.id) == "string" and block.id:sub(1, 5) == "zone:")
end

local function FirstQuestBlock(module)
    local block = module and module.firstBlock
    local guard = 0
    while block and guard < 200 do
        if not IsZoneHeaderBlock(block) then
            return block
        end
        block = block.nextBlock
        guard = guard + 1
    end
    return nil
end

ns.FirstQuestBlock = FirstQuestBlock

local function WithFirstQuestBlock(fn)
    return function(self, ...)
        if not ns.GetOption("enhanceQuestTracker") then
            return fn(self, ...)
        end
        local module = QuestObjectiveTracker
        if not module then
            return fn(self, ...)
        end
        local realFirst = module.firstBlock
        local firstQuest = FirstQuestBlock(module)
        if realFirst and realFirst ~= firstQuest then
            module.firstBlock = firstQuest
            local ok, err = pcall(fn, self, ...)
            module.firstBlock = realFirst
            if not ok then
                error(err, 0)
            end
            return
        end
        return fn(self, ...)
    end
end

local function TargetFirstQuestBlock(fn)
    return function(self, ...)
        if not ns.GetOption("enhanceQuestTracker") then
            return fn(self, ...)
        end
        local module = QuestObjectiveTracker
        if not module then
            return fn(self, ...)
        end
        local realFirst = module.firstBlock
        local firstQuest = FirstQuestBlock(module)
        if realFirst and realFirst ~= firstQuest then
            module.firstBlock = firstQuest
            local ok, err = pcall(fn, self, ...)
            module.firstBlock = realFirst
            if not ok then
                error(err, 0)
            end
            if not firstQuest and SmartNavigation and SmartNavigation.SetTargetButtonForFrame then
                SmartNavigation:SetTargetButtonForFrame(self, module.Header)
            end
            return
        end
        return fn(self, ...)
    end
end

function ns.OpenTrackerMenu(owner)
    if not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then
        return false
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("FOREVER_QUEST_PINS_TRACKER")
        root:CreateTitle(L["Quest tracker"])
        if MenuUtil and type(MenuUtil.CreateCheckbox) == "function" then
            root:Insert(MenuUtil.CreateCheckbox(
                L["Enhance quest tracker"],
                function() return ns.GetOption("enhanceQuestTracker") end,
                function() ns.SetOption("enhanceQuestTracker", not ns.GetOption("enhanceQuestTracker")) end
            ))
        else
            root:CreateCheckbox(
                L["Enhance quest tracker"],
                function() return ns.GetOption("enhanceQuestTracker") end,
                function() ns.SetOption("enhanceQuestTracker", not ns.GetOption("enhanceQuestTracker")) end
            )
        end
        if MenuUtil and type(MenuUtil.CreateCheckbox) == "function" then
            root:Insert(MenuUtil.CreateCheckbox(
                L["Select nearest quest"],
                function() return ns.GetOption("selectNearestQuest") end,
                function() ns.SetOption("selectNearestQuest", not ns.GetOption("selectNearestQuest")) end
            ))
        else
            root:CreateCheckbox(
                L["Select nearest quest"],
                function() return ns.GetOption("selectNearestQuest") end,
                function() ns.SetOption("selectNearestQuest", not ns.GetOption("selectNearestQuest")) end
            )
        end
        root:CreateDivider()
        root:CreateTitle(L["Sort quests"])
        for i = 1, #SORT_ORDER do
            local value = SORT_ORDER[i]
            root:CreateRadio(SORT_LABELS[value],
                function() return ns.GetOption("trackerSort") == value end,
                function() ns.SetOption("trackerSort", value) end,
                value)
        end
        root:CreateDivider()
        root:CreateTitle(L["Show quests"])
        for i = 1, #FILTER_ORDER do
            local value = FILTER_ORDER[i]
            root:CreateRadio(FILTER_LABELS[value],
                function() return ns.GetOption("trackerFilter") == value end,
                function() ns.SetOption("trackerFilter", value) end,
                value)
        end
    end)
    return true
end

local function TrackerShown()
    local frame = ObjectiveTrackerFrame
    local module = QuestObjectiveTracker
    if not frame or not module then
        return false
    end
    if frame.IsShown and not frame:IsShown() then
        return false
    end
    if frame.IsCollapsed and frame:IsCollapsed() then
        return false
    end
    if module.IsCollapsed and module:IsCollapsed() then
        return false
    end
    if module.HasContents and not module:HasContents() then
        return false
    end
    return true
end

local function StopTicker()
    tickerToken = tickerToken + 1
    if ticker and ticker.Cancel then
        ticker:Cancel()
    end
    ticker = nil
end

local function OnTicker()
    if not TrackerShown() or InCombat() then
        StopTicker()
        return
    end
    local signature = ns.TrackerOrderSignature()
    if signature and signature ~= lastSignature then
        lastSignature = signature
        if QuestObjectiveTracker and QuestObjectiveTracker.MarkDirty then
            QuestObjectiveTracker:MarkDirty()
        end
    end
end

function ns.TrackerOrderSignature()
    local tracker = QuestObjectiveTracker
    if not tracker or type(tracker.BuildQuestWatchInfos) ~= "function" then
        return nil
    end
    local ok, infos = pcall(tracker.BuildQuestWatchInfos, tracker)
    if not ok or type(infos) ~= "table" then
        return nil
    end
    local ids = {}
    for i = 1, #infos do
        local quest = infos[i].quest
        local questID = quest and quest.GetID and quest:GetID()
        ids[i] = tostring(questID or "?")
    end
    return table.concat(ids, ",")
end

function ns.SelectNearestQuest()
    if AddOnActionsRestricted() then
        return false
    end
    local tracker = QuestObjectiveTracker
    if not tracker or type(tracker.BuildQuestWatchInfos) ~= "function" then
        return false
    end
    if not C_SuperTrack or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function" then
        return false
    end
    local ok, infos = pcall(tracker.BuildQuestWatchInfos, tracker)
    if not ok or type(infos) ~= "table" then
        return false
    end
    local bestID, bestDistance
    for i = 1, #infos do
        local quest = infos[i].quest
        local questID = quest and quest.GetID and quest:GetID()
        if type(questID) == "number" then
            local distance, onContinent = QuestDistance(questID)
            if KnownNumber(distance) and onContinent ~= false then
                if not bestDistance or distance < bestDistance then
                    bestID, bestDistance = questID, distance
                end
            end
        end
    end
    if not bestID then
        return false
    end
    if type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and C_SuperTrack.GetSuperTrackedQuestID() == bestID then
        return true
    end
    return pcall(C_SuperTrack.SetSuperTrackedQuestID, bestID) == true
end

local nearestTicker
local nearestTickerToken = 0

local function StopNearestTicker()
    nearestTickerToken = nearestTickerToken + 1
    if nearestTicker and nearestTicker.Cancel then
        nearestTicker:Cancel()
    end
    nearestTicker = nil
end

local function OnNearestTick()
    if not ns.GetOption("selectNearestQuest") or AddOnActionsRestricted() then
        StopNearestTicker()
        return
    end
    ns.SelectNearestQuest()
end

function ns.UpdateNearestQuestTicker()
    local wants = ns.GetOption("selectNearestQuest")
        and not AddOnActionsRestricted()
        and C_SuperTrack
        and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
    if not wants then
        StopNearestTicker()
        return
    end
    if nearestTicker then
        return
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        nearestTicker = C_Timer.NewTicker(5, OnNearestTick)
    elseif C_Timer and type(C_Timer.After) == "function" then
        nearestTicker = {}
        local token = nearestTickerToken
        local function Loop()
            if token ~= nearestTickerToken then
                return
            end
            OnNearestTick()
            if token == nearestTickerToken then
                C_Timer.After(5, Loop)
            end
        end
        C_Timer.After(5, Loop)
    end
end

function ns.UpdateTrackerTicker()
    local wants = ns.GetOption("enhanceQuestTracker")
        and ns.GetOption("trackerSort") == "distance"
        and C_QuestLog and type(C_QuestLog.GetDistanceSqToQuest) == "function"
        and TrackerShown()
        and not InCombat()
    if not wants then
        StopTicker()
        return
    end
    if ticker then
        return
    end
    lastSignature = ns.TrackerOrderSignature()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        ticker = C_Timer.NewTicker(5, OnTicker)
    elseif C_Timer and type(C_Timer.After) == "function" then
        ticker = {}
        local token = tickerToken
        local function Loop()
            if token ~= tickerToken then
                return
            end
            OnTicker()
            if token == tickerToken then
                C_Timer.After(5, Loop)
            end
        end
        C_Timer.After(5, Loop)
    end
end

function ns.NotifyTrackerOptionsChanged()
    ns.UpdateTrackerTicker()
    ns.UpdateNearestQuestTicker()
    if InCombat() then
        pendingLayout = true
        ns.RefreshTrackerEnhancement()
        return
    end
    pendingLayout = false
    ns.RefreshTrackerEnhancement()
    local tracker = QuestObjectiveTracker
    if tracker and tracker.MarkDirty then
        tracker:MarkDirty()
    end
end

local function HookTrackerHeader(tracker)
    local header = tracker.Header
    if not header or not header.EnableMouse then
        return
    end
    header:EnableMouse(true)
    local function OnMouseUp(_, button)
        if button == "RightButton" then
            ns.OpenTrackerMenu(header)
        end
    end
    if header.GetScript and header:GetScript("OnMouseUp") then
        header:HookScript("OnMouseUp", OnMouseUp)
    else
        header:SetScript("OnMouseUp", OnMouseUp)
    end
end

local originalBuildQuestWatchInfos
local originalEnumQuestWatchData
local originalSetTrackerTargetButton
local originalSelectFirstButton
local originalUpdateSmartNavigationOverrides
local enhancedBuildQuestWatchInfos
local enhancedEnumQuestWatchData
local enhancedSetTrackerTargetButton
local enhancedSelectFirstButton
local enhancedUpdateSmartNavigationOverrides
local enhancementActive = false

ApplyTrackerEnhancement = function()
    if not registered or enhancementActive or InCombat() then
        return
    end
    local tracker = QuestObjectiveTracker
    local frame = ObjectiveTrackerFrame
    if not tracker or not frame then
        return
    end
    tracker.BuildQuestWatchInfos = enhancedBuildQuestWatchInfos
    tracker.EnumQuestWatchData = enhancedEnumQuestWatchData
    if enhancedSetTrackerTargetButton then
        frame.SetTrackerTargetButton = enhancedSetTrackerTargetButton
    end
    if enhancedSelectFirstButton then
        frame.SelectFirstButton = enhancedSelectFirstButton
    end
    if enhancedUpdateSmartNavigationOverrides then
        frame.UpdateSmartNavigationOverrides = enhancedUpdateSmartNavigationOverrides
    end
    enhancementActive = true
end

RestoreTrackerEnhancement = function()
    if not registered or not enhancementActive then
        return
    end
    local tracker = QuestObjectiveTracker
    local frame = ObjectiveTrackerFrame
    if tracker then
        tracker.BuildQuestWatchInfos = originalBuildQuestWatchInfos
        tracker.EnumQuestWatchData = originalEnumQuestWatchData
    end
    if frame then
        if originalSetTrackerTargetButton then
            frame.SetTrackerTargetButton = originalSetTrackerTargetButton
        end
        if originalSelectFirstButton then
            frame.SelectFirstButton = originalSelectFirstButton
        end
        if originalUpdateSmartNavigationOverrides then
            frame.UpdateSmartNavigationOverrides = originalUpdateSmartNavigationOverrides
        end
    end
    enhancementActive = false
end

-- The tracker layout runs inside Blizzard's execution. Our replacement methods
-- are addon code, so calling them taints the rest of the layout, and in combat
-- the scenario tracker then cannot read secret aura data. Keep the originals in
-- place while in combat and re-apply the enhancement after combat.
function ns.RefreshTrackerEnhancement()
    if ns.GetOption("enhanceQuestTracker") and not InCombat() then
        ApplyTrackerEnhancement()
    else
        RestoreTrackerEnhancement()
    end
end

function ns.TryRegisterQuestTracker()
    if registered then
        ns.UpdateTrackerTicker()
        return true
    end
    local tracker = QuestObjectiveTracker
    local frame = ObjectiveTrackerFrame
    if not tracker
        or type(tracker.BuildQuestWatchInfos) ~= "function"
        or type(tracker.EnumQuestWatchData) ~= "function"
        or not frame then
        return false
    end
    originalBuildQuestWatchInfos = tracker.BuildQuestWatchInfos
    originalEnumQuestWatchData = tracker.EnumQuestWatchData
    enhancedBuildQuestWatchInfos = function(self, ...)
        local infos = originalBuildQuestWatchInfos(self, ...)
        if not ns.GetOption("enhanceQuestTracker") then
            return infos
        end
        local ok, enhanced = pcall(ns.EnhanceQuestWatchInfos, self, infos)
        if not ok or type(enhanced) ~= "table" then
            return infos
        end
        return enhanced
    end
    enhancedEnumQuestWatchData = function(self, func)
        if not ns.GetOption("enhanceQuestTracker") then
            return originalEnumQuestWatchData(self, func)
        end
        local ok, enhanced = pcall(ns.EnumEnhancedQuestWatchData, self, func)
        if not ok or enhanced == false then
            return originalEnumQuestWatchData(self, func)
        end
    end
    if type(frame.SetTrackerTargetButton) == "function" then
        originalSetTrackerTargetButton = frame.SetTrackerTargetButton
        enhancedSetTrackerTargetButton = TargetFirstQuestBlock(originalSetTrackerTargetButton)
    end
    if type(frame.SelectFirstButton) == "function" then
        originalSelectFirstButton = frame.SelectFirstButton
        enhancedSelectFirstButton = WithFirstQuestBlock(originalSelectFirstButton)
    end
    if type(frame.UpdateSmartNavigationOverrides) == "function" then
        originalUpdateSmartNavigationOverrides = frame.UpdateSmartNavigationOverrides
        enhancedUpdateSmartNavigationOverrides = WithFirstQuestBlock(originalUpdateSmartNavigationOverrides)
    end
    HookTrackerHeader(tracker)
    if tracker.HookScript then
        tracker:HookScript("OnShow", function()
            ns.UpdateTrackerTicker()
            ns.UpdateNearestQuestTicker()
        end)
        tracker:HookScript("OnHide", function()
            StopTicker()
            StopNearestTicker()
        end)
    end
    registered = true
    ns.RefreshTrackerEnhancement()
    ns.UpdateTrackerTicker()
    ns.UpdateNearestQuestTicker()
    return true
end

local eventFrame
if CreateFrame then
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", function(_, event)
        if not registered then
            return
        end
        if event == "ZONE_CHANGED" then
            ns.OnTrackerZoneChanged(false)
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
            ns.OnTrackerZoneChanged(true)
        elseif event == "PLAYER_REGEN_DISABLED" then
            ns.RefreshTrackerEnhancement()
            StopTicker()
            StopNearestTicker()
        elseif event == "PLAYER_REGEN_ENABLED" then
            ns.RefreshTrackerEnhancement()
            ns.UpdateTrackerTicker()
            ns.UpdateNearestQuestTicker()
            pendingLayout = false
            local tracker = QuestObjectiveTracker
            if tracker and tracker.MarkDirty then
                tracker:MarkDirty()
            end
        end
    end)
end
