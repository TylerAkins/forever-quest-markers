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
local RefreshRows
local SelectDungeon

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

local function QuestStatus(questID, data)
    if ns.IsQuestFlaggedCompleted and ns.IsQuestFlaggedCompleted(questID) then
        return L["Complete"], 0.55, 0.55, 0.55
    end
    if ns.IsOnQuest and ns.IsOnQuest(questID) then
        return L["In log"], 0.35, 0.95, 0.45
    end
    if not data and not (ns.Quests and ns.Quests[questID]) then
        return L["Unknown"], 0.65, 0.65, 0.65
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

local function SetPin(entry)
    if not entry or not entry.questID then
        return
    end
    local location = entry.location
    if not location then
        SetStatus((L["No map location is available for %s."]):format(entry.title or tostring(entry.questID)), true)
        return
    end
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
            SetPin(entry)
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
                GameTooltip:AddLine(L["Click to show this dungeon's full chains."], 0.8, 0.8, 0.8, true)
            end
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

local function BreadcrumbEntries(mapID)
    local entries = {}
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
            if not altActive and IsFinderAvailable(questID, data) then
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
                    local level = QuestLevel(questID, data)
                    local parts = QuestTagParts(questID, data)
                    local subtitle = MapName(location.mapID)
                    if #usable > 1 then
                        subtitle = subtitle .. " |cff9d9d9d(" .. (#usable) .. " " .. L["locations"] .. ")|r"
                    end
                    if level then
                        subtitle = "[" .. level .. "] " .. subtitle
                    end
                    if #parts > 0 then
                        subtitle = subtitle .. "  " .. TagText(parts)
                    end
                    AddEntry(entries, {
                        kind = "quest",
                        questID = questID,
                        title = data.title or ns.GetQuestTitle(questID) or tostring(questID),
                        subtitle = subtitle,
                        level = level,
                        location = location,
                        tooltip = ChainText(questID),
                    })
                end
            end
        end
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
                AddEntry(entries, {
                    kind = "quest",
                    questID = questID,
                    title = data.title or ns.GetQuestTitle(questID) or tostring(questID),
                    subtitle = subtitle,
                    level = level,
                    location = location,
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

local function AddDungeonQuestRows(entries, dungeon, quest, includeChains)
    local questID = quest.id
    local data = ns.Quests and ns.Quests[questID]
    local locations = QuestLocations(questID, data)
    if #locations == 0 and quest.mapID then
        locations[1] = { mapID = quest.mapID, x = quest.x, y = quest.y }
    end
    local location = PickLocation(locations, CurrentMapID())
    local level = quest.level or QuestLevel(questID, data)
    local status = QuestStatus(questID, data)
    local total = #(quest.chain or {}) + 1
    local subtitle = status
    if level then
        subtitle = "[" .. level .. "] " .. subtitle
    end
    if location then
        subtitle = subtitle .. "  |cff9d9d9d" .. MapName(location.mapID) .. "|r"
    end
    if quest.faction and quest.faction ~= "Both" then
        subtitle = subtitle .. "  |cff9d9d9d" .. quest.faction .. "|r"
    end
    if #(quest.chain or {}) > 0 then
        subtitle = subtitle .. "  |cff9d9d9d" .. string.format(L["%d pre-quests"], #quest.chain) .. "|r"
    end
    AddEntry(entries, {
        kind = "quest",
        questID = questID,
        title = quest.name or tostring(questID),
        subtitle = subtitle,
        level = level,
        location = location,
        tooltip = #(quest.chain or {}) > 0
            and string.format(L["Dungeon chain step %d of %d."], total, total)
            or L["Dungeon quest."],
    })
    if not includeChains then
        return
    end
    for index, step in ipairs(quest.chain or {}) do
        local stepID = step.id
        local stepData = ns.Quests and ns.Quests[stepID]
        local stepLocations = QuestLocations(stepID, stepData)
        if #stepLocations == 0 and step.mapID then
            stepLocations[1] = { mapID = step.mapID, x = step.x, y = step.y }
        end
        local stepLocation = PickLocation(stepLocations, CurrentMapID())
        local stepLevel = step.level or QuestLevel(stepID, stepData)
        local stepStatus = QuestStatus(stepID, stepData)
        local stepSubtitle = string.format(L["Chain #%d of %d"], index, total)
        stepSubtitle = stepSubtitle .. "  |cff9d9d9d" .. stepStatus .. "|r"
        if stepLevel then
            stepSubtitle = stepSubtitle .. "  [" .. stepLevel .. "]"
        end
        if stepLocation then
            stepSubtitle = stepSubtitle .. "  |cff9d9d9d" .. MapName(stepLocation.mapID) .. "|r"
        end
        if step.startsInDungeon then
            stepSubtitle = stepSubtitle .. "  |cff9d9d9d" .. L["starts in dungeon"] .. "|r"
        end
        AddEntry(entries, {
            kind = "quest",
            questID = stepID,
            title = step.name or tostring(stepID),
            subtitle = stepSubtitle,
            level = stepLevel,
            location = stepLocation,
            indent = 18,
            tooltip = string.format(L["Required pre-quest %d of %d for %s."], index, total, quest.name or ""),
        })
    end
end

local function DungeonHeader(dungeonName, dungeon)
    local count = #(dungeon.quests or {})
    local subtitle = count .. " " .. (count == 1 and L["quest"] or L["quests"])
    if dungeon.level then
        subtitle = "[" .. dungeon.level .. "] " .. subtitle
    end
    return {
        kind = "header",
        dungeon = dungeonName,
        title = dungeonName,
        subtitle = subtitle,
        r = DUNGEON_R, g = DUNGEON_G, b = DUNGEON_B,
        bgR = DUNGEON_R, bgG = DUNGEON_G, bgB = DUNGEON_B, bgA = 0.08,
        tooltip = L["Click to show this dungeon's full chains."],
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
            AddEntry(entries, DungeonHeader(name, dungeon))
            for _, quest in ipairs(dungeon.quests or {}) do
                AddDungeonQuestRows(entries, dungeon, quest, false)
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
        AddDungeonQuestRows(entries, dungeon, quest, true)
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

local function EmptyEntry()
    local zone = CurrentZoneID()
    local zoneName = zone and MapName(zone) or L["All zones"]
    if activeTab == 1 then
        return {
            kind = "header",
            title = string.format(L["No breadcrumbs in %s."], zoneName),
            subtitle = L["Choose another zone or check Map pins settings."],
            r = 0.7, g = 0.7, b = 0.7,
        }
    end
    if activeTab == 2 then
        return {
            kind = "header",
            title = string.format(L["No available quests in %s."], zoneName),
            subtitle = L["Choose another zone or check Map pins settings."],
            r = 0.7, g = 0.7, b = 0.7,
        }
    end
    return {
        kind = "header",
        title = L["No dungeon quests are available."],
        subtitle = L["Check the Dungeon chains database."],
        r = 0.7, g = 0.7, b = 0.7,
    }
end

local function RenderRows()
    if not frame then
        return
    end
    local entries = BuildEntries()
    if #entries == 0 then
        entries[1] = EmptyEntry()
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

local function UpdateZoneText()
    local dropdown = frame and frame.zoneDropdown
    if not dropdown then
        return
    end
    if type(zoneSelection) == "number" then
        dropdown:SetDefaultText(MapName(zoneSelection))
    elseif zoneSelection == "all" then
        dropdown:SetDefaultText(L["All zones"])
    else
        local current = CurrentMapID()
        if current then
            dropdown:SetDefaultText(L["Current zone"] .. ": " .. MapName(current))
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
    dropdown:SetDefaultText(dungeonSelection or L["All dungeons"])
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

local function EnsureFrame()
    if frame then
        return frame
    end
    local panel = CreateFrame("Frame", "ForeverQuestPinsQuestFinder", UIParent, "BackdropTemplate")
    panel:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
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

    local tabNames = { L["Breadcrumbs"], L["Available quests"], L["Dungeon quests"] }
    for i = 1, #tabNames do
        local tab = CreateFrame("Button", "ForeverQuestPinsQuestFinderTab" .. i, panel, "CharacterFrameTabButtonTemplate")
        tab:SetPoint("TOPLEFT", PADDING + (i - 1) * (TAB_WIDTH + 4), -68)
        tab:SetText(tabNames[i])
        tab:SetScript("OnLoad", nil)
        tab:SetScript("OnShow", nil)
        tab:SetScript("OnClick", function() ShowTab(i) end)
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, tab, 0, TAB_WIDTH)
        else
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
            root:CreateRadio(zone.name, function() return zoneSelection == zone.id end,
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
            root:CreateRadio(name, function() return dungeonSelection == name end,
                function() SelectDungeon(name) end, name)
        end
    end)
    panel.dungeonDropdown:SetPoint("TOPLEFT", panel.dungeonControl, "TOPLEFT", 0, 0)

    panel.count = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.count:SetPoint("TOPRIGHT", -PADDING, -132)
    panel.count:SetJustifyH("RIGHT")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PADDING, -160)
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
}
