local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.defaults = {
    enabled = true,
    showTrivial = true,
    showSeasonal = false,
    debug = false,
}

local function CopyDefaults(src, dest)
    dest = dest or {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            dest[key] = CopyDefaults(value, dest[key])
        elseif dest[key] == nil then
            dest[key] = value
        end
    end
    return dest
end

function ns.GetSettings()
    return ForeverQuestPinsDB_Settings
end

function ns.GetOption(key)
    local settings = ForeverQuestPinsDB_Settings
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return ns.defaults[key]
end

function ns.SetOption(key, value)
    if not ForeverQuestPinsDB_Settings then
        ForeverQuestPinsDB_Settings = CopyDefaults(ns.defaults)
    end
    ForeverQuestPinsDB_Settings[key] = value
    if ns.RequestRefresh then
        ns.RequestRefresh("settings")
    end
end

function ns.InitSettings()
    ForeverQuestPinsDB_Settings = CopyDefaults(ns.defaults, ForeverQuestPinsDB_Settings)
    return ForeverQuestPinsDB_Settings
end

local function Print(message)
    print("|cffffd100Forever Quest Pins:|r " .. tostring(message))
end

local function ToggleFlag(key, label)
    local value = not ns.GetOption(key)
    ns.SetOption(key, value)
    Print(label .. ": " .. (value and "on" or "off"))
    return value
end

function ns.SlashCommand(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if msg == "" or msg == "help" then
        Print("Commands:")
        print("  /fqp on       Enable quest-start pins")
        print("  /fqp off      Disable quest-start pins")
        print("  /fqp trivial  Toggle low-level/trivial pins")
        print("  /fqp seasonal Toggle holiday/seasonal pins (off by default)")
        print("  /fqp debug    Toggle debug tooltips and chat diagnostics")
        print("  /fqp refresh  Rebuild pins on the current map")
        print("  /fqp stats    Print database and pin counts")
        print("  /fqp apis     Print which Forever map/quest APIs are present")
        return
    end

    if msg == "on" then
        ns.SetOption("enabled", true)
        Print("Pins enabled.")
        return
    end
    if msg == "off" then
        ns.SetOption("enabled", false)
        Print("Pins disabled.")
        if ns.MapPins then
            ns.MapPins:Clear()
        end
        return
    end
    if msg == "debug" then
        ToggleFlag("debug", "Debug")
        return
    end
    if msg == "trivial" then
        ToggleFlag("showTrivial", "Show trivial quests")
        return
    end
    if msg == "seasonal" then
        ToggleFlag("showSeasonal", "Show seasonal/holiday pins")
        return
    end
    if msg == "refresh" then
        if ns.RefreshNow then
            ns.RefreshNow("slash")
        end
        Print("Refreshed.")
        return
    end
    if msg == "stats" then
        ns.PrintStats()
        return
    end
    if msg == "apis" then
        ns.PrintAPIProbe()
        return
    end

    Print("Unknown command. Type /fqp help")
end

function ns.PrintStats()
    local meta = ns.Metadata or {}
    local quests = ns.Quests or {}
    local byMap = ns.ByMap or {}
    local count = 0
    for _ in pairs(quests) do
        count = count + 1
    end
    local maps = 0
    for _ in pairs(byMap) do
        maps = maps + 1
    end
    Print(("ATT %s | %d quests | %d maps"):format(tostring(meta.attCommit or "?"), count, maps))
    if ns.MapPins and ns.MapPins.GetStatus then
        local status = ns.MapPins:GetStatus()
        print(("  viewed map %s | painted %s | mode %s"):format(
            tostring(status.viewedMap),
            tostring(status.count),
            tostring(status.mode)
        ))
        if status.lastError then
            print("  last error: " .. tostring(status.lastError))
        end
        if status.icon then
            print("  pin icon: " .. tostring(status.icon))
        end
    end
end

function ns.PrintAPIProbe()
    local function has(value)
        return value and "yes" or "no"
    end
    Print("API probe (verify these on Interface 16001):")
    print("  C_QuestLog.IsQuestFlaggedCompleted: " .. has(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted))
    print("  HasQuestCompletionAPI: " .. has(ns.HasQuestCompletionAPI and ns.HasQuestCompletionAPI()))
    print("  C_QuestLog.IsOnQuest: " .. has(C_QuestLog and C_QuestLog.IsOnQuest))
    print("  C_QuestLog.GetTitleForQuestID: " .. has(C_QuestLog and C_QuestLog.GetTitleForQuestID))
    print("  C_Map.GetMapRectOnMap: " .. has(C_Map and C_Map.GetMapRectOnMap))
    print("  C_Map.GetMapChildrenInfo: " .. has(C_Map and C_Map.GetMapChildrenInfo))
    print("  WorldMapFrame.AddDataProvider: " .. has(WorldMapFrame and WorldMapFrame.AddDataProvider))
    print("  MapCanvasDataProviderMixin: " .. has(MapCanvasDataProviderMixin))
    print("  MapCanvasPinMixin: " .. has(MapCanvasPinMixin))
    print("  Settings API: " .. has(Settings and Settings.RegisterAddOnCategory))
    print("  GetQuestGreenRange: " .. has(GetQuestGreenRange))
    print("  C_Texture.GetAtlasInfo: " .. has(C_Texture and C_Texture.GetAtlasInfo))
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal")
    print("  QuestNormal atlas: " .. has(atlas))
    if ns.MapPins and ns.MapPins.GetStatus then
        print("  pin icon: " .. tostring(ns.MapPins:GetStatus().icon or "not painted yet"))
    end
    local mapID = ns.GetViewedMapID and ns.GetViewedMapID()
    print("  viewed mapID: " .. tostring(mapID))
    local _, raceFile, raceID = UnitRace("player")
    local _, classFile, classID = UnitClass("player")
    print(("  player race=%s id=%s class=%s id=%s faction=%s level=%s"):format(
        tostring(raceFile),
        tostring(raceID),
        tostring(classFile),
        tostring(classID),
        tostring(UnitFactionGroup("player")),
        tostring(UnitLevel("player"))
    ))
end

function ns.RegisterSlash()
    SLASH_FOREVERQUESTPINS1 = "/fqp"
    SLASH_FOREVERQUESTPINS2 = "/foreverquestpins"
    SlashCmdList.FOREVERQUESTPINS = function(msg)
        ns.SlashCommand(msg)
    end
end

function ns.TryRegisterSettings()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        return false
    end
    if ns.settingsRegistered then
        return true
    end

    local panel = CreateFrame("Frame")
    panel.name = "Forever Quest Pins"
    panel:SetScript("OnShow", function(self)
        if self.built then
            return
        end
        self.built = true
        local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Forever Quest Pins")
        local help = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        help:SetWidth(500)
        help:SetJustifyH("LEFT")
        help:SetText("Yellow ! markers on the world map for quests you can accept but have not already taken. Use /fqp for commands.")
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Forever Quest Pins")
    if category then
        Settings.RegisterAddOnCategory(category)
        ns.settingsRegistered = true
        return true
    end
    return false
end
