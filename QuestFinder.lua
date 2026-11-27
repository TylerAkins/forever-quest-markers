local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Quest Finder is a Blizzard-dialog-styled window with three views:
-- breadcrumbs, quests available in a zone, and dungeon quests with their
-- required pre-quest chains. Every quest row sets a Blizzard map pin through
-- ns.TrackQuest, so it uses the player's configured waypoint provider.

local FRAME_WIDTH = 780
local FRAME_HEIGHT = 580
local PADDING = 24
local TAB_HEIGHT = 28
local TAB_WIDTH = 150
local ROW_HEIGHT = 44
local HEADER_HEIGHT = 38
local MAX_ALL_ZONE_ROWS = 800

local DUNGEON_R, DUNGEON_G, DUNGEON_B = 1.00, 0.32, 0.08
local REPEATABLE_R, REPEATABLE_G, REPEATABLE_B = 0.12, 0.72, 1.00
local PROFESSION_R, PROFESSION_G, PROFESSION_B = 0.90, 0.55, 0.30

local frame
local tabs = {}
local activeTab = 1
local rows = {}
local zoneList
local zoneSelection = "current"
local dungeonSelection
local searchText = ""
local searchRefreshToken = 0
local progressToken = 0
local RefreshRows
local SelectDungeon
local ScheduleSearchRefresh

local mapInfoCache = {}

local function MapInfo(mapID)
    if not mapID or not C_Map or type(C_Map.GetMapInfo) ~= "function" then
        return nil
    end
    local cached = mapInfoCache[mapID]
    if cached then
        return cached
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if ok and info then
        mapInfoCache[mapID] = info
        return info
    end
    return nil
end

local function MapName(mapID)
    local info = MapInfo(mapID)
    if info and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end
    return L["Unknown zone"]
end

local function IsDungeonMap(mapID)
    local info = MapInfo(mapID)
    return info ~= nil and info.mapType == 4
end

local function CurrentMapID()
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            return mapID
        end
    end
    return nil
end

local function IsZoneMap(mapID)
    local info = MapInfo(mapID)
    if not info then
        return false
    end
    local mapType = info.mapType
    -- Zone, dungeon, and micro maps have quest pins. World and continent maps
    -- are projections of those zones, so they do not need their own entry.
    return mapType == nil or mapType >= 3
end

local zoneRanges

local function BuildZoneRanges()
    local ranges = {}
    for _, data in pairs(ns.Quests or {}) do
        local level = data.minLevel
        if type(level) == "number" and level > 0 then
            local seen = {}
            local function add(mapID)
                if type(mapID) ~= "number" or seen[mapID] then
                    return
                end
                seen[mapID] = true
                local range = ranges[mapID]
                if not range then
                    ranges[mapID] = { min = level, max = level }
                else
                    if level < range.min then range.min = level end
                    if level > range.max then range.max = level end
                end
            end
            add(data.mapID)
            for _, coord in ipairs(data.coords or {}) do
                add(coord[3])
            end
        end
    end
    return ranges
end

local function ZoneLevelRange(mapID)
    if type(mapID) ~= "number" then
        return nil
    end
    local leatrix = ns.ZoneLevels and ns.ZoneLevels[mapID]
    if leatrix ~= nil then
        if leatrix and leatrix.min and leatrix.max then
            return { min = leatrix.min, max = leatrix.max }
        end
        return nil
    end
    if not zoneRanges then
        zoneRanges = BuildZoneRanges()
    end
    return zoneRanges[mapID]
end

local function FormatRange(range)
    if not range then
        return nil
    end
    if range.min == range.max then
        return tostring(range.min)
    end
    return range.min .. "-" .. range.max
end

local function AddMap(mapID, seen, list)
    if type(mapID) ~= "number" or seen[mapID] or not IsZoneMap(mapID) then
        return
    end
    seen[mapID] = true
    local info = MapInfo(mapID)
    list[#list + 1] = {
        id = mapID,
        name = MapName(mapID),
        mapType = info and info.mapType,
        levelRange = FormatRange(ZoneLevelRange(mapID)),
    }
end

local function BuildZoneList()
    local seen = {}
    local list = {}
    AddMap(CurrentMapID(), seen, list)
    for mapID in pairs(ns.ByMap or {}) do
        AddMap(mapID, seen, list)
    end
    for _, data in pairs(ns.Quests or {}) do
        AddMap(data.mapID, seen, list)
        if data.coords then
            for i = 1, #data.coords do
                AddMap(data.coords[i][3], seen, list)
            end
        end
    end
    local dungeons = ns.DungeonChains and ns.DungeonChains.dungeons or {}
    for _, dungeon in pairs(dungeons) do
        for _, quest in ipairs(dungeon.quests or {}) do
            AddMap(quest.mapID, seen, list)
            for _, step in ipairs(quest.chain or {}) do
                AddMap(step.mapID, seen, list)
            end
        end
    end
    table.sort(list, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)
    return list
end

local function QuestLocations(questID, data)
    local list = {}
    local seen = {}
    local function add(mapID, x, y)
        if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
            return
        end
        local key = mapID .. ":" .. x .. ":" .. y
        if seen[key] then
            return
        end
        seen[key] = true
        list[#list + 1] = { mapID = mapID, x = x, y = y }
    end
    if data then
        add(data.mapID, data.x, data.y)
        if data.coords then
            for i = 1, #data.coords do
                local coord = data.coords[i]
                add(coord[3], coord[1], coord[2])
            end
        end
    end
    return list
end

local function LocationExplored(location)
    if not location or ns.GetOption("showUnexplored") then
        return true
    end
    return ns.IsMapPositionExplored(location.mapID, location.x, location.y)
end

-- The finder lists thousands of quests at once. Do not ask the client to load
-- a difficulty record for every one of them; use the database minimum level
-- and the same category and prerequisite filters.
local function IsFinderAvailable(questID, data)
    return ns.IsQuestAvailable(questID, data, { skipLevelRequest = true })
end

local followUpsBySource

local function BuildFollowUps()
    local index = {}
    local function add(source, followUp)
        local list = index[source]
        if not list then
            list = {}
            index[source] = list
        end
        list[#list + 1] = followUp
    end
    for questID, data in pairs(ns.Quests or {}) do
        for _, source in ipairs(data.sourceQuestSingle or {}) do
            add(source, questID)
        end
        for _, source in ipairs(data.sourceQuestGroup or {}) do
            add(source, questID)
        end
    end
    return index
end

local function FollowUpsFor(questID)
    if not followUpsBySource then
        followUpsBySource = BuildFollowUps()
    end
    return followUpsBySource[questID] or {}
end

local function FollowUpSatisfied(questID)
    local followUps = FollowUpsFor(questID)
    for i = 1, #followUps do
        local followUp = followUps[i]
        if ns.IsQuestFlaggedCompleted(followUp) or ns.IsOnQuest(followUp) then
            return true
        end
    end
    return false
end

local function TargetMapIDs(questID)
    local maps = {}
    local seen = {}
    local function add(mapID)
        if type(mapID) ~= "number" or seen[mapID] then
            return
        end
        seen[mapID] = true
        maps[#maps + 1] = mapID
    end
    local override = ns.BreadcrumbTargets and ns.BreadcrumbTargets[questID]
    if type(override) == "number" then
        add(override)
    elseif type(override) == "table" then
        for i = 1, #override do
            add(override[i])
        end
    end
    local followUps = FollowUpsFor(questID)
    for i = 1, #followUps do
        local data = ns.Quests and ns.Quests[followUps[i]]
        if data then
            add(data.mapID)
            for _, coord in ipairs(data.coords or {}) do
                add(coord[3])
            end
        end
    end
    return maps
end

local function TargetZoneNames(questID)
    local maps = TargetMapIDs(questID)
    local names = {}
    local seen = {}
    for i = 1, #maps do
        local name = MapName(maps[i])
        if name and name ~= L["Unknown zone"] and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

local function StartZoneNames(locations)
    local names = {}
    local seen = {}
    for i = 1, #locations do
        local name = MapName(locations[i].mapID)
        if name and name ~= L["Unknown zone"] and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

local function PickLocation(locations, mapID)
    if not locations or #locations == 0 then
        return nil
    end
    if type(mapID) == "number" then
        for i = 1, #locations do
            if locations[i].mapID == mapID then
                return locations[i]
            end
        end
    end
    local current = CurrentMapID()
    if current then
        for i = 1, #locations do
            if locations[i].mapID == current then
                return locations[i]
            end
        end
    end
    return locations[1]
end

local function QuestLevel(questID, data)
    if C_QuestLog and type(C_QuestLog.GetQuestDifficultyLevel) == "function" then
        local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if ok and type(level) == "number" and level > 0 then
            return level
        end
    end
    return data and data.minLevel
end

local function ColorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor((r or 1) * 255),
        math.floor((g or 1) * 255),
        math.floor((b or 1) * 255),
        tostring(text))
end

local UNAVAILABLE_REASONS = {
    ["prereq-and"] = L["Requires another quest first."],
    ["prereq-count"] = L["Requires another quest first."],
    ["prereq-single"] = L["Requires another quest first."],
    ["low-level"] = L["Requires a higher level."],
    ["faction"] = L["Not available to your faction."],
    ["class"] = L["Not available to your class."],
    ["profession"] = L["Requires a profession."],
    ["trivial"] = L["Too low level for your character."],
    ["high-level"] = L["Above your configured level range."],
    ["category-hidden"] = L["Hidden by the current map filters."],
    ["alt-completed"] = L["Another version of this quest was completed."],
    ["user-hidden"] = L["Hidden with Shift-click."],
    ["excluded"] = L["Excluded from quest pins."],
    ["book"] = L["Book quests are hidden."],
    ["repeatable"] = L["Repeatable quest pins are hidden."],
    ["seasonal"] = L["Seasonal quest pins are hidden."],
    ["war-effort"] = L["War effort quest pins are hidden."],
    ["war-effort-unconfirmed"] = L["The war effort phase is not confirmed."],
    ["event-unknown"] = L["The event window is unknown."],
}

local function UnavailableReason(reason)
    return UNAVAILABLE_REASONS[reason] or L["Not available yet."]
end

local function QuestStatus(questID, data, checkAvailable)
    if ns.IsQuestFlaggedCompleted and ns.IsQuestFlaggedCompleted(questID) then
        return L["Complete"], 0.55, 0.55, 0.55
    end
    if ns.IsOnQuest and ns.IsOnQuest(questID) then
        return L["In log"], 0.35, 0.95, 0.45
    end
    if not data and not (ns.Quests and ns.Quests[questID]) then
        return L["Unknown"], 0.65, 0.65, 0.65
    end
    if checkAvailable and data then
        local available, reason = ns.IsQuestAcceptable(questID, data)
        if not available then
            return L["Unavailable"], 0.80, 0.55, 0.55, reason
        end
    end
    return L["Available"], 1, 1, 1
end

local function QuestTagParts(questID, data)
    local parts = {}
    if ns.IsInstanceQuest and ns.IsInstanceQuest(questID, data) then
        parts[#parts + 1] = { L["Dungeon"], DUNGEON_R, DUNGEON_G, DUNGEON_B }
    end
    if data and data.repeatable then
        parts[#parts + 1] = { L["Repeatable"], REPEATABLE_R, REPEATABLE_G, REPEATABLE_B }
    end
    if data and data.requireSkill then
        parts[#parts + 1] = { L["Profession"], PROFESSION_R, PROFESSION_G, PROFESSION_B }
    end
    if data and data.classes and #data.classes > 0 then
        parts[#parts + 1] = { L["Class"], 0.85, 0.75, 1.00 }
    end
    if ns.IsPvPQuest and ns.IsPvPQuest(questID, data) then
        parts[#parts + 1] = { L["PvP"], 1.00, 0.25, 0.25 }
    end
    if data and data.isBreadcrumb then
        parts[#parts + 1] = { L["Breadcrumb"], 0.95, 0.85, 0.45 }
    end
    if data and (data.isYearly or data.event) then
        parts[#parts + 1] = { L["Seasonal"], 0.55, 0.90, 0.55 }
    end
    if ns.IsBookQuest and ns.IsBookQuest(questID) then
        parts[#parts + 1] = { L["Book"], 0.80, 0.65, 0.45 }
    end
    if data and data.faction and data.faction ~= "Both" then
        parts[#parts + 1] = { data.faction, 0.75, 0.75, 0.75 }
    end
    return parts
end

local function TagText(parts)
    local text = {}
    for i = 1, #parts do
        local part = parts[i]
        text[#text + 1] = string.format("|cff%02x%02x%02x%s|r",
            math.floor(part[2] * 255), math.floor(part[3] * 255), math.floor(part[4] * 255),
            tostring(part[1]))
    end
    return table.concat(text, " |cff6b6b6b·|r ")
end

local function ChainText(questID)
    local chains = ns.DungeonChains
        and ns.DungeonChains.quests
        and ns.DungeonChains.quests[questID]
        and ns.DungeonChains.quests[questID].chains
    if not chains or #chains == 0 then
        return nil
    end
    local parts = {}
    for i = 1, #chains do
        local chain = chains[i]
        local text = string.format(L["Chain #%d of %d"], chain.index, chain.total)
        if chain.dungeon then
            text = text .. " |cff9d9d9d(" .. chain.dungeon .. ")|r"
        end
        parts[#parts + 1] = text
    end
    return table.concat(parts, "  ")
end

local function SetStatus(message, isError)
    if not frame or not frame.status then
        return
    end
    frame.status:SetText(message or "")
    if isError then
        frame.status:SetTextColor(1, 0.35, 0.35)
    else
        frame.status:SetTextColor(0.65, 0.65, 0.65)
    end
end

local function SetPinAt(entry, location)
    local data = {
        mapID = location.mapID,
        x = location.x,
        y = location.y,
        title = entry.title,
    }
    local ok, message = ns.TrackQuest(entry.questID, data, true)
    if ok then
        SetStatus((L["Map pin set for %s."]):format(entry.title or tostring(entry.questID)))
    else
        SetStatus(message or L["Could not create a map pin for this quest."], true)
    end
end

local function UniqueLocationsByMap(locations)
    local choices = {}
    local seen = {}
    for i = 1, #locations do
        local location = locations[i]
        if not seen[location.mapID] then
            seen[location.mapID] = true
            choices[#choices + 1] = location
        end
    end
    local current = CurrentMapID()
    table.sort(choices, function(a, b)
        if a.mapID == current then
            return true
        end
        if b.mapID == current then
            return false
        end
        return MapName(a.mapID) < MapName(b.mapID)
    end)
    return choices
end

local function SetPin(entry, owner)
    if not entry or not entry.questID then
        return
    end
    if entry.insideDungeon then
        SetStatus((L["%s starts inside the dungeon, so a map pin is not available."]):format(
            entry.title or tostring(entry.questID)), true)
        return
    end
    local locations = entry.locations
    if not locations or #locations == 0 then
        locations = entry.location and { entry.location } or {}
    end
    if #locations == 0 then
        SetStatus((L["No map location is available for %s."]):format(entry.title or tostring(entry.questID)), true)
        return
    end
    local choices = UniqueLocationsByMap(locations)
    if #choices > 1 and owner and MenuUtil
        and type(MenuUtil.CreateContextMenu) == "function" then
        local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
            root:CreateTitle(entry.title or "")
            for i = 1, #choices do
                local location = choices[i]
                root:CreateButton(string.format(L["Set pin: %s"], MapName(location.mapID)), function()
                    SetPinAt(entry, location)
                end)
            end
        end)
        if ok then
            return
        end
    end
    SetPinAt(entry, entry.location or choices[1])
end

local function ScrollBy(delta)
    local scroll = frame and frame.scroll
    if not scroll then
        return
    end
    local range = scroll:GetVerticalScrollRange() or 0
    local value = (scroll:GetVerticalScroll() or 0) - delta * 36
    scroll:SetVerticalScroll(math.max(0, math.min(range, value)))
end

local function SetRowText(row, entry)
    local title = entry.title or ""
    local indent = entry.indent or 0
    row.title:ClearAllPoints()
    row.subtitle:ClearAllPoints()
    row.title:SetText(title)
    row.subtitle:SetText(entry.subtitle or "")
    row.bg:SetColorTexture(entry.bgR or 0, entry.bgG or 0, entry.bgB or 0, entry.bgA or 0)
    if entry.kind == "header" then
        row.title:SetTextColor(entry.r or 1, entry.g or 0.82, entry.b or 0)
        row.title:SetPoint("TOPLEFT", 12, -5)
        row.title:SetPoint("TOPRIGHT", -12, -5)
        row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -1)
        row.subtitle:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -1)
    else
        row.title:SetPoint("TOPLEFT", 12 + indent, -7)
        row.title:SetPoint("TOPRIGHT", -12, -7)
        row.subtitle:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
        row.subtitle:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -2)
        local r, g, b = ns.GetQuestDifficultyRGB(entry.level)
        if entry.kind == "dungeon" then
            r, g, b = DUNGEON_R, DUNGEON_G, DUNGEON_B
        end
        row.title:SetTextColor(r or 1, g or 0.82, b or 0)
    end
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, frame.scrollChild, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouse(true)
    row:EnableMouseWheel(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row.subtitle = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.subtitle:SetJustifyH("LEFT")
    row.subtitle:SetWordWrap(false)

    row.hover = row:CreateTexture(nil, "HIGHLIGHT")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.06)

    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if not entry then
            return
        end
        if entry.kind == "header" then
            if entry.dungeon then
                SelectDungeon(entry.dungeon)
            end
            return
        end
        if entry.kind == "quest" then
            SetPin(entry, self)
        end
    end)
    row:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(delta)
    end)
    row:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry or not GameTooltip then
            return
        end
        if entry.kind == "header" and not entry.dungeon then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.title or "", 1, 0.82, 0)
        if entry.subtitle and entry.subtitle ~= "" then
            GameTooltip:AddLine(entry.subtitle, 1, 1, 1, true)
        end
        if entry.tooltip then
            GameTooltip:AddLine(entry.tooltip, 1, 1, 1, true)
        end
        if entry.kind == "header" then
            if entry.dungeon then
                GameTooltip:AddLine(L["Click to show this dungeon's full quest list and chains."], 0.8, 0.8, 0.8, true)
            end
        elseif entry.insideDungeon then
            -- The reason is already in entry.tooltip.
        elseif entry.multiLocation then
            GameTooltip:AddLine(L["Click to choose a start zone."], 0.8, 0.8, 0.8)
        elseif entry.location then
            GameTooltip:AddLine(L["Click to set a Blizzard map pin."], 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine(L["No map location is available for this quest."], 0.8, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    rows[index] = row
    return row
end

local function HideRowsFrom(count)
    for i = count + 1, #rows do
        rows[i]:Hide()
    end
end

local function AddEntry(entries, entry)
    entries[#entries + 1] = entry
end

local function ZoneNamesForMaps(maps)
    local names = {}
    local seen = {}
    for i = 1, #maps do
        local name = MapName(maps[i])
        if name and name ~= L["Unknown zone"] and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

local function BreadcrumbEntries(mapID)
    local groups = {}
    for questID, data in pairs(ns.Quests or {}) do
        if data.isBreadcrumb
            and not ns.IsQuestFlaggedCompleted(questID)
            and not ns.IsOnQuest(questID)
            and not (ns.IsQuestHidden and ns.IsQuestHidden(questID)) then
            local altActive = false
            for _, altID in ipairs(data.altQuests or {}) do
                if altID ~= questID and ns.IsOnQuest(altID) then
                    altActive = true
                    break
                end
            end
            if not altActive and not FollowUpSatisfied(questID) and IsFinderAvailable(questID, data) then
                local locations = QuestLocations(questID, data)
                local startLocations = {}
                for i = 1, #locations do
                    if LocationExplored(locations[i]) then
                        startLocations[#startLocations + 1] = locations[i]
                    end
                end
                local targetMaps = TargetMapIDs(questID)
                local matchesStart, matchesTarget
                if mapID == nil then
                    matchesStart = #startLocations > 0
                    matchesTarget = #targetMaps > 0
                else
                    for i = 1, #startLocations do
                        if startLocations[i].mapID == mapID then
                            matchesStart = true
                            break
                        end
                    end
                    for i = 1, #targetMaps do
                        if targetMaps[i] == mapID then
                            matchesTarget = true
                            break
                        end
                    end
                end
                if matchesStart or matchesTarget then
                    local sortedTargets = {}
                    for i = 1, #targetMaps do
                        sortedTargets[i] = targetMaps[i]
                    end
                    table.sort(sortedTargets)
                    local targetKey = table.concat(sortedTargets, ",")
                    local title = data.title or ns.GetQuestTitle(questID) or tostring(questID)
                    local key = title .. "|" .. targetKey
                    local group = groups[key]
                    if not group then
                        group = {
                            title = title,
                            questID = questID,
                            questIDs = {},
                            level = QuestLevel(questID, data),
                            data = data,
                            startLocations = {},
                            startSeen = {},
                            targetMaps = {},
                            targetSeen = {},
                        }
                        groups[key] = group
                    end
                    group.questIDs[#group.questIDs + 1] = questID
                    if not group.level then
                        group.level = QuestLevel(questID, data)
                    end
                    for i = 1, #startLocations do
                        local location = startLocations[i]
                        local locationKey = location.mapID .. ":" .. location.x .. ":" .. location.y
                        if not group.startSeen[locationKey] then
                            group.startSeen[locationKey] = true
                            group.startLocations[#group.startLocations + 1] = location
                        end
                    end
                    for i = 1, #targetMaps do
                        local target = targetMaps[i]
                        if not group.targetSeen[target] then
                            group.targetSeen[target] = true
                            group.targetMaps[#group.targetMaps + 1] = target
                        end
                    end
                end
            end
        end
    end

    local entries = {}
    for _, group in pairs(groups) do
        local location = PickLocation(group.startLocations, mapID)
        local insideDungeon = false
        for i = 1, #group.startLocations do
            if IsDungeonMap(group.startLocations[i].mapID) then
                insideDungeon = true
                break
            end
        end
        local parts = QuestTagParts(group.questID, group.data)
        local startNames = StartZoneNames(group.startLocations)
        local subtitle = #startNames > 0 and table.concat(startNames, ", ") or L["No start map"]
        if #group.startLocations > 1 then
            subtitle = subtitle .. " |cff9d9d9d(" .. (#group.startLocations) .. " " .. L["locations"] .. ")|r"
        end
        if group.level then
            subtitle = "[" .. group.level .. "] " .. subtitle
        end
        if #parts > 0 then
            subtitle = subtitle .. "  " .. TagText(parts)
        end
        local targetNames = ZoneNamesForMaps(group.targetMaps)
        local visibleTargets = {}
        local startNameSet = {}
        for i = 1, #startNames do
            startNameSet[startNames[i]] = true
        end
        for i = 1, #targetNames do
            if not startNameSet[targetNames[i]] then
                visibleTargets[#visibleTargets + 1] = targetNames[i]
            end
        end
        if #visibleTargets > 0 then
            subtitle = subtitle .. "  |cff9d9d9d"
                .. string.format(L["Leads to %s"], table.concat(visibleTargets, ", ")) .. "|r"
        end
        if insideDungeon then
            subtitle = subtitle .. "  |cff9d9d9d" .. L["In dungeon"] .. "|r"
        end
        local tooltipParts = {}
        local chain = ChainText(group.questID)
        if chain then
            tooltipParts[#tooltipParts + 1] = chain
        end
        if #targetNames > 0 then
            tooltipParts[#tooltipParts + 1] = string.format(L["Leads to %s."],
                table.concat(targetNames, ", "))
        end
        if insideDungeon then
            tooltipParts[#tooltipParts + 1] =
                L["This quest starts inside the dungeon, so a map pin is not available."]
        end
        entries[#entries + 1] = {
            kind = "quest",
            questID = group.questID,
            questIDs = group.questIDs,
            title = group.title,
            subtitle = subtitle,
            level = group.level,
            location = location,
            locations = group.startLocations,
            multiLocation = #UniqueLocationsByMap(group.startLocations) > 1,
            insideDungeon = insideDungeon,
            tooltip = #tooltipParts > 0 and table.concat(tooltipParts, "\n") or nil,
        }
    end
    table.sort(entries, function(a, b)
        if a.title == b.title then
            return a.questID < b.questID
        end
        return a.title < b.title
    end)
    return entries
end
local function AvailableEntries(mapID)
    local entries = {}
    local scanned = 0
    for questID, data in pairs(ns.Quests or {}) do
        if IsFinderAvailable(questID, data) then
            local locations = QuestLocations(questID, data)
            local usable = {}
            for i = 1, #locations do
                local location = locations[i]
                if (mapID == nil or location.mapID == mapID) and LocationExplored(location) then
                    usable[#usable + 1] = location
                end
            end
            if #usable > 0 then
                local location = PickLocation(usable, mapID)
                local insideDungeon = IsDungeonMap(location.mapID)
                local level = QuestLevel(questID, data)
                local parts = QuestTagParts(questID, data)
                local subtitle = MapName(location.mapID)
                if level then
                    subtitle = "[" .. level .. "] " .. subtitle
                end
                if #parts > 0 then
                    subtitle = subtitle .. "  " .. TagText(parts)
                end
                local chain = ChainText(questID)
                if chain then
                    subtitle = subtitle .. "  " .. chain
                end
                if insideDungeon then
                    subtitle = subtitle .. "  |cff9d9d9d" .. L["In dungeon"] .. "|r"
                end
                AddEntry(entries, {
                    kind = "quest",
                    questID = questID,
                    title = data.title or ns.GetQuestTitle(questID) or tostring(questID),
                    subtitle = subtitle,
                    level = level,
                    location = location,
                    locations = usable,
                    multiLocation = #UniqueLocationsByMap(usable) > 1,
                    insideDungeon = insideDungeon,
                    tooltip = insideDungeon
                        and L["This quest starts inside the dungeon, so a map pin is not available."]
                        or nil,
                })
                scanned = scanned + 1
                if mapID == nil and scanned >= MAX_ALL_ZONE_ROWS then
                    break
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        local aLevel = a.level or 999
        local bLevel = b.level or 999
        if aLevel ~= bLevel then
            return aLevel < bLevel
        end
        if a.title == b.title then
            return a.questID < b.questID
        end
        return a.title < b.title
    end)
    return entries
end

local function IsDungeonQuestAvailable(questID, data, quest)
    if data then
        return ns.IsQuestAcceptable(questID, data)
    end
    if ns.IsQuestFlaggedCompleted and ns.IsQuestFlaggedCompleted(questID) then
        return false
    end
    if ns.IsOnQuest and ns.IsOnQuest(questID) then
        return false
    end
    return true
end

-- The full dungeon view keeps quests that are locked behind progression, but
-- opposite-faction, wrong-race, and wrong-class steps are never relevant.
local function PlayerMatches(data, faction)
    faction = (data and data.faction) or faction
    if faction and faction ~= "Both" then
        local playerFaction = ns.GetPlayerFaction and ns.GetPlayerFaction()
        if playerFaction and playerFaction ~= faction then
            return false
        end
    end
    if not data then
        return true
    end
    if data.races and #data.races > 0 and ns.GetPlayerRaceID then
        local raceID = ns.GetPlayerRaceID()
        if raceID then
            local match = false
            for i = 1, #data.races do
                if data.races[i] == raceID then
                    match = true
                    break
                end
            end
            if not match then
                return false
            end
        end
    end
    if data.classes and #data.classes > 0 and ns.GetPlayerClassID then
        local classID = ns.GetPlayerClassID()
        if classID then
            local match = false
            for i = 1, #data.classes do
                if data.classes[i] == classID then
                    match = true
                    break
                end
            end
            if not match then
                return false
            end
        end
    end
    return true
end

local function DungeonNamesForQuest(questID)
    local info = ns.DungeonChains
        and ns.DungeonChains.quests
        and ns.DungeonChains.quests[questID]
    return info and info.dungeons
end

local function StartsInsideDungeon(questID, location)
    if location and IsDungeonMap(location.mapID) then
        return true
    end
    if location then
        return false
    end
    local dungeons = DungeonNamesForQuest(questID)
    return dungeons ~= nil and #dungeons > 0
end

local zoneQuestIndex

local function BuildZoneQuestIndex()
    local index = {}
    for questID, data in pairs(ns.Quests or {}) do
        local include = not data.repeatable
            and not data.isMonthly
            and not data.isYearly
            and not data.event
            and not data.requireSkill
        if include and PlayerMatches(data, nil) then
            local seen = {}
            local function addMap(mapID)
                if type(mapID) ~= "number" or seen[mapID] then
                    return
                end
                seen[mapID] = true
                local list = index[mapID]
                if not list then
                    list = {}
                    index[mapID] = list
                end
                list[#list + 1] = questID
            end
            if type(data.zone) == "number" and data.zone > 0 then
                -- Questie's assigned quest zone is authoritative for Loremaster
                -- counting, even when the quest has no start coordinates.
                addMap(data.zone)
            else
                addMap(data.mapID)
                for _, coord in ipairs(data.coords or {}) do
                    addMap(coord[3])
                end
            end
        end
    end
    return index
end

local function ZoneQuestProgress(mapID)
    if type(mapID) ~= "number" then
        return nil
    end
    if not zoneQuestIndex then
        zoneQuestIndex = BuildZoneQuestIndex()
    end
    local questIDs = zoneQuestIndex[mapID]
    if not questIDs or #questIDs == 0 then
        return nil
    end
    local completed = 0
    for i = 1, #questIDs do
        if ns.IsQuestFlaggedCompleted(questIDs[i]) then
            completed = completed + 1
        end
    end
    return { completed = completed, total = #questIDs }
end

local function ZoneProgress(mapID)
    return ZoneQuestProgress(mapID)
end

local function AddDungeonQuestRows(entries, dungeon, quest, includeChains, includeUnavailable)
    local questID = quest.id
    local data = ns.Quests and ns.Quests[questID]
    if not PlayerMatches(data, quest.faction) then
        return
    end
    if not includeUnavailable and not IsDungeonQuestAvailable(questID, data, quest) then
        return
    end
    local visibleChain = {}
    for _, step in ipairs(quest.chain or {}) do
        local stepData = ns.Quests and ns.Quests[step.id]
        if PlayerMatches(stepData, step.faction or quest.faction) then
            visibleChain[#visibleChain + 1] = { step = step, data = stepData }
        end
    end
    local locations = QuestLocations(questID, data)
    if #locations == 0 and quest.mapID then
        locations[1] = { mapID = quest.mapID, x = quest.x, y = quest.y }
    end
    local location = PickLocation(locations, CurrentMapID())
    local insideDungeon = StartsInsideDungeon(questID, location)
    local level = quest.level or QuestLevel(questID, data)
    local status, statusR, statusG, statusB, statusReason = QuestStatus(questID, data, includeUnavailable)
    local total = #visibleChain + 1
    local subtitle = ColorText(status, statusR, statusG, statusB)
    if level then
        subtitle = "[" .. level .. "] " .. subtitle
    end
    if location then
        subtitle = subtitle .. "  |cff9d9d9d" .. MapName(location.mapID) .. "|r"
    end
    if quest.faction and quest.faction ~= "Both" then
        subtitle = subtitle .. "  |cff9d9d9d" .. quest.faction .. "|r"
    end
    if #visibleChain > 0 then
        subtitle = subtitle .. "  |cff9d9d9d"
            .. string.format(L["%d pre-quests"], #visibleChain) .. "|r"
    end
    if insideDungeon then
        subtitle = subtitle .. "  |cff9d9d9d" .. L["In dungeon"] .. "|r"
    end
    local tooltip = insideDungeon
        and L["This quest starts inside the dungeon, so a map pin is not available."]
        or (statusReason and UnavailableReason(statusReason))
        or (#visibleChain > 0
            and string.format(L["Dungeon chain step %d of %d."], total, total)
            or L["Dungeon quest."])
    AddEntry(entries, {
        kind = "quest",
        questID = questID,
        title = quest.name or tostring(questID),
        subtitle = subtitle,
        level = level,
        location = location,
        insideDungeon = insideDungeon,
        tooltip = tooltip,
    })
    if not includeChains then
        return
    end
    for index, item in ipairs(visibleChain) do
        local step = item.step
        local stepData = item.data
        local stepID = step.id
        local stepLocations = QuestLocations(stepID, stepData)
        if #stepLocations == 0 and step.mapID then
            stepLocations[1] = { mapID = step.mapID, x = step.x, y = step.y }
        end
        local stepLocation = PickLocation(stepLocations, CurrentMapID())
        local stepInsideDungeon = step.startsInDungeon
            or (stepLocation and IsDungeonMap(stepLocation.mapID))
            or (not stepLocation and step.needsDungeon)
        local stepLevel = step.level or QuestLevel(stepID, stepData)
        local stepStatus, stepR, stepG, stepB, stepReason = QuestStatus(stepID, stepData, includeUnavailable)
        local stepSubtitle = string.format(L["Chain #%d of %d"], index, total)
        stepSubtitle = stepSubtitle .. "  " .. ColorText(stepStatus, stepR, stepG, stepB)
        if stepLevel then
            stepSubtitle = stepSubtitle .. "  [" .. stepLevel .. "]"
        end
        if stepLocation then
            stepSubtitle = stepSubtitle .. "  |cff9d9d9d" .. MapName(stepLocation.mapID) .. "|r"
        end
        if stepInsideDungeon then
            stepSubtitle = stepSubtitle .. "  |cff9d9d9d" .. L["In dungeon"] .. "|r"
        end
        local stepTooltip = stepInsideDungeon
            and L["This quest starts inside the dungeon, so a map pin is not available."]
            or (stepReason and UnavailableReason(stepReason))
            or string.format(L["Required pre-quest %d of %d for %s."], index, total, quest.name or "")
        AddEntry(entries, {
            kind = "quest",
            questID = stepID,
            title = step.name or tostring(stepID),
            subtitle = stepSubtitle,
            level = stepLevel,
            location = stepLocation,
            insideDungeon = stepInsideDungeon,
            indent = 18,
            tooltip = stepTooltip,
        })
    end
end
local function DungeonHeader(dungeonName, dungeon, availableCount)
    local total = #(dungeon.quests or {})
    local subtitle
    if availableCount and availableCount ~= total then
        subtitle = availableCount .. " " .. L["available"] .. "  |cff6b6b6b·|r  "
            .. total .. " " .. (total == 1 and L["quest"] or L["quests"])
    else
        subtitle = total .. " " .. (total == 1 and L["quest"] or L["quests"])
    end
    if dungeon.level then
        subtitle = string.format(L["Level %s"], dungeon.level) .. "  |cff6b6b6b·|r  " .. subtitle
    end
    return {
        kind = "header",
        dungeon = dungeonName,
        title = dungeonName,
        subtitle = subtitle,
        r = DUNGEON_R, g = DUNGEON_G, b = DUNGEON_B,
        bgR = DUNGEON_R, bgG = DUNGEON_G, bgB = DUNGEON_B, bgA = 0.08,
    }
end

local function AllDungeonEntries()
    local entries = {}
    local dungeons = ns.DungeonChains and ns.DungeonChains.dungeons or {}
    local order = ns.DungeonChains and ns.DungeonChains.order or {}
    for i = 1, #order do
        local name = order[i]
        local dungeon = dungeons[name]
        if dungeon then
            local questEntries = {}
            for _, quest in ipairs(dungeon.quests or {}) do
                AddDungeonQuestRows(questEntries, dungeon, quest, false, false)
            end
            if #questEntries > 0 then
                AddEntry(entries, DungeonHeader(name, dungeon, #questEntries))
                for j = 1, #questEntries do
                    entries[#entries + 1] = questEntries[j]
                end
            end
        end
    end
    return entries
end

local function DungeonQuestEntries(dungeonName)
    local dungeon = ns.DungeonChains
        and ns.DungeonChains.dungeons
        and ns.DungeonChains.dungeons[dungeonName]
    if not dungeon then
        return {}
    end
    local entries = {}
    AddEntry(entries, DungeonHeader(dungeonName, dungeon))
    for _, quest in ipairs(dungeon.quests or {}) do
        AddDungeonQuestRows(entries, dungeon, quest, true, true)
    end
    return entries
end
local function CurrentZoneID()
    if zoneSelection == "all" then
        return nil
    end
    if type(zoneSelection) == "number" then
        return zoneSelection
    end
    return CurrentMapID()
end

local function BuildEntries()
    if activeTab == 1 then
        return BreadcrumbEntries(CurrentZoneID())
    end
    if activeTab == 2 then
        return AvailableEntries(CurrentZoneID())
    end
    if dungeonSelection and dungeonSelection ~= "all" then
        return DungeonQuestEntries(dungeonSelection)
    end
    return AllDungeonEntries()
end

local function UpdateCount(entries)
    local quests = 0
    for i = 1, #entries do
        if entries[i].kind == "quest" then
            quests = quests + 1
        end
    end
    if frame and frame.count then
        frame.count:SetText(quests .. " " .. (quests == 1 and L["quest"] or L["quests"]))
    end
end

local function ZoneHeaderEntry()
    local zone = CurrentZoneID()
    local title = zone and MapName(zone) or L["All zones"]
    local range = zone and FormatRange(ZoneLevelRange(zone))
    return {
        kind = "header",
        title = title,
        subtitle = range and string.format(L["Level %s"], range) or L["All levels"],
        r = 1, g = 0.82, b = 0,
    }
end

local function EmptyEntry()
    local zone = CurrentZoneID()
    local zoneName = zone and MapName(zone) or nil
    if activeTab == 1 then
        return {
            kind = "header",
            title = zoneName and string.format(L["No breadcrumbs in %s."], zoneName) or L["No breadcrumbs match these filters."],
            subtitle = L["Choose another zone or check Map pins settings."],
            r = 0.7, g = 0.7, b = 0.7,
        }
    end
    if activeTab == 2 then
        return {
            kind = "header",
            title = zoneName and string.format(L["No available quests in %s."], zoneName) or L["No available quests match these filters."],
            subtitle = L["Choose another zone or check Map pins settings."],
            r = 0.7, g = 0.7, b = 0.7,
        }
    end
    return {
        kind = "header",
        title = L["No available dungeon quests."],
        subtitle = L["Check the Dungeon chains database or choose another dungeon."],
        r = 0.7, g = 0.7, b = 0.7,
    }
end

local function FilterEntries(entries, query)
    if not query or query == "" then
        return entries
    end
    local needle = query:lower()
    local result = {}
    local header
    local headerMatch = false
    local group = {}
    local matched = {}
    local function flush()
        if header then
            if headerMatch then
                result[#result + 1] = header
                for i = 1, #group do
                    result[#result + 1] = group[i]
                end
            elseif #matched > 0 then
                result[#result + 1] = header
                for i = 1, #matched do
                    result[#result + 1] = matched[i]
                end
            end
        else
            for i = 1, #matched do
                result[#result + 1] = matched[i]
            end
        end
        header = nil
        headerMatch = false
        group = {}
        matched = {}
    end
    for i = 1, #entries do
        local entry = entries[i]
        if entry.kind == "header" then
            flush()
            header = entry
            headerMatch = entry.title
                and entry.title:lower():find(needle, 1, true) ~= nil
        else
            local text = ((entry.title or "") .. " "
                .. (entry.subtitle or "") .. " "
                .. (entry.tooltip or "")):lower()
            group[#group + 1] = entry
            if text:find(needle, 1, true) then
                matched[#matched + 1] = entry
            end
        end
    end
    flush()
    return result
end

local function UpdateZoneProgress()
    if not frame or not frame.progressBar then
        return
    end
    local bar = frame.progressBar
    if activeTab ~= 2 then
        bar:Hide()
        return
    end
    local mapID = CurrentZoneID()
    if not mapID then
        bar:Hide()
        return
    end
    local progress = ZoneProgress(mapID)
    if not progress or not progress.total or progress.total <= 0 then
        bar:Hide()
        return
    end
    bar:SetMinMaxValues(0, progress.total)
    bar:SetValue(progress.completed)
    local percent = math.floor((progress.completed / progress.total) * 100 + 0.5)
    bar.label:SetText(string.format("%s %d / %d (%d%%)",
        L["Loremaster"], progress.completed, progress.total, percent))
    bar.tooltip = string.format(
        L["Loremaster progress for %s. %d of %d quests completed. Counts quests assigned to the zone that match your faction, race, and class. Repeatable, monthly, seasonal, and profession quests are excluded."],
        MapName(mapID), progress.completed, progress.total)
    bar:Show()
end

local function RenderRows()
    if not frame then
        return
    end
    local entries = FilterEntries(BuildEntries(), searchText)
    local hasQuest = false
    for i = 1, #entries do
        if entries[i].kind == "quest" then
            hasQuest = true
            break
        end
    end
    if not hasQuest then
        entries = { EmptyEntry() }
    elseif activeTab ~= 3 then
        table.insert(entries, 1, ZoneHeaderEntry())
    end
    local y = 0
    for i = 1, #entries do
        local entry = entries[i]
        local row = rows[i] or CreateRow(i)
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        if entry.kind == "header" then
            row:SetHeight(HEADER_HEIGHT)
            y = y + HEADER_HEIGHT + 4
        else
            row:SetHeight(ROW_HEIGHT)
            y = y + ROW_HEIGHT + 2
        end
        SetRowText(row, entry)
        row:Show()
    end
    HideRowsFrom(#entries)
    frame.scrollChild:SetHeight(math.max(y, 1))
    frame.scroll:SetVerticalScroll(0)
    UpdateCount(entries)
    UpdateZoneProgress()

    if frame.zoneControl then
        frame.zoneControl:SetShown(activeTab ~= 3)
    end
    if frame.dungeonControl then
        frame.dungeonControl:SetShown(activeTab == 3)
    end
    if frame.zoneCaption then
        frame.zoneCaption:SetText(activeTab == 3 and L["Dungeon"] or L["Zone"])
    end
end

RefreshRows = function()
    local ok, err = pcall(RenderRows)
    if not ok then
        SetStatus(L["Quest Finder error: "] .. tostring(err), true)
        if ns.GetOption("debug") then
            print("|cffffd100Forever Quest Pins:|r Quest Finder: " .. tostring(err))
        end
    end
end

ScheduleSearchRefresh = function()
    searchRefreshToken = searchRefreshToken + 1
    local token = searchRefreshToken
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.12, function()
            if token == searchRefreshToken then
                RefreshRows()
            end
        end)
    else
        RefreshRows()
    end
end

local function ZoneLabel(mapID)
    local name = MapName(mapID)
    local range = FormatRange(ZoneLevelRange(mapID))
    if range then
        return name .. " (" .. range .. ")"
    end
    return name
end

local function DungeonLabel(name)
    local dungeon = ns.DungeonChains
        and ns.DungeonChains.dungeons
        and ns.DungeonChains.dungeons[name]
    if dungeon and dungeon.level then
        return name .. " (" .. dungeon.level .. ")"
    end
    return name
end

local function UpdateZoneText()
    local dropdown = frame and frame.zoneDropdown
    if not dropdown then
        return
    end
    if type(zoneSelection) == "number" then
        dropdown:SetDefaultText(ZoneLabel(zoneSelection))
    elseif zoneSelection == "all" then
        dropdown:SetDefaultText(L["All zones"])
    else
        local current = CurrentMapID()
        if current then
            dropdown:SetDefaultText(L["Current zone"] .. ": " .. ZoneLabel(current))
        else
            dropdown:SetDefaultText(L["Current zone"])
        end
    end
    dropdown:GenerateMenu()
end

local function UpdateDungeonText()
    local dropdown = frame and frame.dungeonDropdown
    if not dropdown then
        return
    end
    dropdown:SetDefaultText(dungeonSelection and DungeonLabel(dungeonSelection) or L["All dungeons"])
    dropdown:GenerateMenu()
end

local function SelectZone(value)
    zoneSelection = value
    UpdateZoneText()
    RefreshRows()
end

SelectDungeon = function(value)
    dungeonSelection = value
    UpdateDungeonText()
    RefreshRows()
end
local function CreateDropdown(parent, width, buildMenu)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(width, 26)
    dropdown:SetupMenu(function(_, root)
        buildMenu(root)
    end)
    return dropdown
end

local function ShowTab(index)
    activeTab = index
    for i = 1, #tabs do
        local tab = tabs[i]
        local selected = i == index
        if PanelTemplates_SelectTab and PanelTemplates_DeselectTab then
            pcall(selected and PanelTemplates_SelectTab or PanelTemplates_DeselectTab, tab)
        else
            if tab.SetButtonState then
                pcall(tab.SetButtonState, tab, selected and "PUSHED" or "NORMAL", true)
            end
            local text = tab:GetFontString()
            if text then
                if selected then
                    text:SetTextColor(1, 0.82, 0)
                else
                    text:SetTextColor(0.9, 0.9, 0.9)
                end
            end
        end
    end
    RefreshRows()
end

local function SavedPosition()
    local db = ns.db
    if type(db) ~= "table" then
        return 0, 0
    end
    return tonumber(db.questFinderX) or 0, tonumber(db.questFinderY) or 0
end

local function SavePosition(panel)
    local centerX, centerY = panel:GetCenter()
    local uiX, uiY = UIParent:GetCenter()
    local scale = UIParent:GetEffectiveScale() or 1
    if not centerX or not centerY or not uiX or not uiY then
        return
    end
    local x = math.floor(((centerX - uiX) / scale) + 0.5)
    local y = math.floor(((centerY - uiY) / scale) + 0.5)
    if ns.SetOption then
        ns.SetOption("questFinderX", x)
        ns.SetOption("questFinderY", y)
    elseif type(ns.db) == "table" then
        ns.db.questFinderX = x
        ns.db.questFinderY = y
    end
end

local function EnsureFrame()
    if frame then
        return frame
    end
    local panel = CreateFrame("Frame", "ForeverQuestPinsQuestFinder", UIParent, "BackdropTemplate")
    panel:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    local savedX, savedY = SavedPosition()
    panel:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropBorderColor(0.8, 0.61, 0.3, 1)
    local background = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", 12, -12)
    background:SetPoint("BOTTOMRIGHT", -12, 12)
    background:SetColorTexture(0.055, 0.045, 0.035, 1)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PADDING, -22)
    title:SetText("|cffffd100Quest|r |cff65b9ffFinder|r")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetText(L["Find breadcrumbs, available quests, and dungeon chains."])

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() panel:Hide() end)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 14, -14)
    drag:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
    drag:SetHeight(48)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePosition(panel)
    end)
    panel.dragHandle = drag

    local tabNames = { L["Breadcrumbs"], L["Available quests"], L["Dungeon quests"] }
    for i = 1, #tabNames do
        local created, tab = pcall(CreateFrame, "Button", "ForeverQuestPinsQuestFinderTab" .. i, panel, "PanelTabButtonTemplate")
        if not created or not tab then
            tab = CreateFrame("Button", "ForeverQuestPinsQuestFinderTab" .. i, panel, "UIPanelButtonTemplate")
            tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
        end
        tab:SetPoint("TOPLEFT", PADDING + (i - 1) * (TAB_WIDTH + 4), -68)
        if tab.UnregisterAllEvents then
            tab:UnregisterAllEvents()
        end
        if tab.Text then
            tab.Text:SetText(tabNames[i])
        else
            tab:SetText(tabNames[i])
        end
        tab:SetScript("OnLoad", nil)
        tab:SetScript("OnShow", nil)
        tab:SetScript("OnClick", function() ShowTab(i) end)
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, tab, 0, TAB_WIDTH)
        end
        if not tab:GetWidth() or tab:GetWidth() < 1 then
            tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
        end
        tabs[i] = tab
    end

    local zoneCaption = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    zoneCaption:SetPoint("TOPLEFT", PADDING, -112)
    zoneCaption:SetText(L["Zone"])
    panel.zoneCaption = zoneCaption

    panel.zoneControl = CreateFrame("Frame", nil, panel)
    panel.zoneControl:SetPoint("TOPLEFT", PADDING, -126)
    panel.zoneControl:SetSize(320, 28)
    panel.zoneDropdown = CreateDropdown(panel.zoneControl, 260, function(root)
        root:CreateRadio(L["Current zone"], function() return zoneSelection == "current" end,
            function() SelectZone("current") end, "current")
        root:CreateRadio(L["All zones"], function() return zoneSelection == "all" end,
            function() SelectZone("all") end, "all")
        for i = 1, #(zoneList or {}) do
            local zone = zoneList[i]
            local label = zone.levelRange and (zone.name .. " (" .. zone.levelRange .. ")") or zone.name
            root:CreateRadio(label, function() return zoneSelection == zone.id end,
                function() SelectZone(zone.id) end, zone.id)
        end
    end)
    panel.zoneDropdown:SetPoint("TOPLEFT", panel.zoneControl, "TOPLEFT", 0, 0)

    panel.dungeonControl = CreateFrame("Frame", nil, panel)
    panel.dungeonControl:SetPoint("TOPLEFT", PADDING, -126)
    panel.dungeonControl:SetSize(320, 28)
    panel.dungeonDropdown = CreateDropdown(panel.dungeonControl, 260, function(root)
        root:CreateRadio(L["All dungeons"], function() return dungeonSelection == nil end,
            function() SelectDungeon(nil) end, "all")
        for _, name in ipairs((ns.DungeonChains and ns.DungeonChains.order) or {}) do
            root:CreateRadio(DungeonLabel(name), function() return dungeonSelection == name end,
                function() SelectDungeon(name) end, name)
        end
    end)
    panel.dungeonDropdown:SetPoint("TOPLEFT", panel.dungeonControl, "TOPLEFT", 0, 0)

    panel.count = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.count:SetPoint("TOPRIGHT", -PADDING, -132)
    panel.count:SetJustifyH("RIGHT")

    local searchCreated, search = pcall(CreateFrame, "EditBox",
        "ForeverQuestPinsQuestFinderSearch", panel, "SearchBoxTemplate")
    if not searchCreated or not search then
        search = CreateFrame("EditBox", "ForeverQuestPinsQuestFinderSearch", panel, "InputBoxTemplate")
    end
    search:SetSize(230, 26)
    search:SetPoint("TOPLEFT", PADDING + 280, -126)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnTextChanged", function(self)
        if type(SearchBoxTemplate_OnTextChanged) == "function" then
            SearchBoxTemplate_OnTextChanged(self)
        end
        searchText = self:GetText() or ""
        ScheduleSearchRefresh()
    end)
    panel.search = search

    local progress = CreateFrame("StatusBar", nil, panel, "BackdropTemplate")
    progress:SetPoint("TOPLEFT", PADDING, -156)
    progress:SetSize(260, 14)
    progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    progress:SetStatusBarColor(0.30, 0.62, 0.35)
    progress:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    progress:SetBackdropColor(0, 0, 0, 0.65)
    progress:SetBackdropBorderColor(0.8, 0.61, 0.3, 0.55)
    progress:SetMinMaxValues(0, 1)
    progress:SetValue(0)
    progress.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progress.label:SetPoint("CENTER", progress, "CENTER", 0, 0)
    progress.label:SetJustifyH("CENTER")
    progress.label:SetShadowColor(0, 0, 0, 0.85)
    progress.label:SetShadowOffset(1, -1)
    progress.label:SetWordWrap(false)
    progress:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.tooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label:GetText() or "", 1, 0.82, 0)
        GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    progress:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    progress:Hide()
    panel.progressBar = progress

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PADDING, -176)
    scroll:SetPoint("BOTTOMRIGHT", -44, 54)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    panel.scroll = scroll

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(FRAME_WIDTH - PADDING - 52)
    scrollChild:SetHeight(1)
    scroll:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("BOTTOMLEFT", PADDING, 44)
    divider:SetPoint("BOTTOMRIGHT", -PADDING, 44)
    divider:SetHeight(1)
    divider:SetColorTexture(1, 0.82, 0, 0.25)

    panel.status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.status:SetPoint("BOTTOMLEFT", PADDING, 20)
    panel.status:SetPoint("BOTTOMRIGHT", -PADDING, 20)
    panel.status:SetJustifyH("LEFT")
    panel.status:SetText(L["Click a quest to set a Blizzard map pin."])
    panel.status:SetTextColor(0.65, 0.65, 0.65)

    panel:SetScript("OnShow", function()
        zoneList = BuildZoneList()
        UpdateZoneText()
        UpdateDungeonText()
        ShowTab(activeTab)
    end)
    panel:Hide()

    if UISpecialFrames and type(UISpecialFrames) == "table" then
        local name = "ForeverQuestPinsQuestFinder"
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == name then
                found = true
                break
            end
        end
        if not found then
            table.insert(UISpecialFrames, name)
        end
    end

    frame = panel
    return panel
end

function ns.ShowQuestFinder()
    EnsureFrame()
    if frame then
        local wasShown = frame:IsShown()
        frame:Show()
        if frame.Raise then
            frame:Raise()
        end
        if wasShown then
            RefreshRows()
        end
    end
end

function ns.ToggleQuestFinder()
    EnsureFrame()
    if not frame then
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        if frame.Raise then
            frame:Raise()
        end
    end
end

-- Exposed for the Lua runtime tests and for other addon modules that need the
-- same quest lists without opening the window.
ns.QuestFinder = {
    BuildZoneList = BuildZoneList,
    BreadcrumbEntries = BreadcrumbEntries,
    AvailableEntries = AvailableEntries,
    AllDungeonEntries = AllDungeonEntries,
    DungeonQuestEntries = DungeonQuestEntries,
    QuestLocations = QuestLocations,
    FilterEntries = FilterEntries,
    ZoneProgress = ZoneProgress,
    ZoneQuestProgress = ZoneQuestProgress,
    ResetPosition = function()
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER")
        end
        if ns.SetOption then
            ns.SetOption("questFinderX", 0)
            ns.SetOption("questFinderY", 0)
        end
    end,
}

function ns.QuestFinder.Debug()
    local zone = CurrentZoneID()
    local zoneName = zone and MapName(zone) or L["All zones"]
    print("|cffffd100Forever Quest Pins:|r Quest Finder")
    print(("  zone=%s mapID=%s"):format(zoneName, tostring(zone)))
    print(("  breadcrumbs=%d available=%d dungeonRows=%d"):format(
        #BreadcrumbEntries(zone),
        #AvailableEntries(zone),
        #AllDungeonEntries()))
    print(("  filters: enabled=%s showTrivial=%s showDungeon=%s showUnexplored=%s"):format(
        tostring(ns.GetOption("enabled")),
        tostring(ns.GetOption("showTrivial")),
        tostring(ns.GetOption("showDungeon")),
        tostring(ns.GetOption("showUnexplored"))))
end

if type(CreateFrame) == "function" then
    local progressEvents = CreateFrame("Frame")
    progressEvents:RegisterEvent("QUEST_TURNED_IN")
    progressEvents:RegisterEvent("QUEST_ACCEPTED")
    progressEvents:RegisterEvent("QUEST_REMOVED")
    progressEvents:SetScript("OnEvent", function()
        if not frame or not frame:IsShown() then
            return
        end
        progressToken = progressToken + 1
        local token = progressToken
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.5, function()
                if token == progressToken and frame and frame:IsShown() then
                    RefreshRows()
                end
            end)
        else
            RefreshRows()
        end
    end)
end
