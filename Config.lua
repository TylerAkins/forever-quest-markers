local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.defaults = {
    enabled = true,
    showNPCTooltips = true,
    showTrivial = false,
    showRepeatable = true,
    showSeasonal = false,
    showWarEffort = false,
    autoAccept = false,
    autoAcceptRangeEnabled = false,
    autoAcceptLevelOffset = 1,
    autoTurnIn = false,
    debug = false,
}

local optionChecks = {}
local MIRROR_CVAR = "ForeverQuestPinsSettings"

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

local function MirrorReady()
    return C_CVar
        and type(C_CVar.GetCVar) == "function"
        and type(C_CVar.SetCVar) == "function"
        and type(C_CVar.RegisterCVar) == "function"
end

local function ReadMirror()
    if not MirrorReady() then
        return nil
    end
    local ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    if not ok or text == nil then
        pcall(C_CVar.RegisterCVar, MIRROR_CVAR, "")
        ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    end
    if not ok then
        return nil
    end
    return text
end

local function DecodeMirror()
    local text = ReadMirror()
    ns.settingsMirror = text
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local mirror = {}
    local offset = tonumber(text:match("autoAcceptLevelOffset=([%-]?%d+)"))
    if offset and offset >= -5 and offset <= 5 then
        mirror.autoAcceptLevelOffset = offset
    end
    mirror._revision = tonumber(text:match("revision=(%d+)")) or 0
    for key, raw in text:gmatch("([%w_]+)=([01])") do
        if type(ns.defaults[key]) == "boolean" then
            mirror[key] = raw == "1"
        end
    end
    return mirror
end

local function HasOptions(db)
    if type(db) ~= "table" then
        return false
    end
    for key in pairs(ns.defaults) do
        if db[key] ~= nil then
            return true
        end
    end
    return false
end

local function Revision(db)
    local revision = type(db) == "table" and tonumber(db._revision) or nil
    if not revision or revision < 0 then
        return 0
    end
    return math.floor(revision)
end

local function CopySettings(src, dest, revision)
    if type(src) ~= "table" or type(dest) ~= "table" then
        return
    end
    for key in pairs(ns.defaults) do
        if src[key] ~= nil then
            if type(ns.defaults[key]) == "number" then
                local value = tonumber(src[key])
                dest[key] = value and value == value and math.max(-5, math.min(5, math.floor(value))) or ns.defaults[key]
            else
                dest[key] = src[key] and true or false
            end
        else
            dest[key] = ns.defaults[key]
        end
    end
    dest._revision = revision or Revision(src)
end

local function ChooseSettings(account, character, legacyAccount, legacyCharacter, mirror)
    local candidates = { account, character, legacyAccount, legacyCharacter, mirror }
    local newest
    local newestRevision = 0
    for i = 1, #candidates do
        local candidate = candidates[i]
        local revision = Revision(candidate)
        if HasOptions(candidate) and revision > newestRevision then
            newest = candidate
            newestRevision = revision
        end
    end
    if newest then
        return newest, newestRevision
    end
    -- One-time migration for stores written before revisions existed. The
    -- canonical account table wins when populated, followed by its character
    -- copy, the legacy stores, and finally the best-effort CVar mirror.
    for i = 1, #candidates do
        if HasOptions(candidates[i]) then
            return candidates[i], 1
        end
    end
    return account, 1
end

local function SaveMirror(db)
    db = db or ns.db
    if not db or not MirrorReady() then
        return
    end
    local keys = {}
    for key, value in pairs(ns.defaults) do
        if type(value) == "boolean" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local parts = { "revision=" .. tostring(Revision(db)) }
    parts[#parts + 1] = "autoAcceptLevelOffset=" .. tostring(db.autoAcceptLevelOffset or 1)
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = key .. "=" .. (db[key] and "1" or "0")
    end
    local text = table.concat(parts, ";")
    if pcall(C_CVar.SetCVar, MIRROR_CVAR, text) then
        ns.settingsMirror = text
    end
end

function ns.InitSettings()
    if ns.db then
        return ns.db
    end

    -- Keep the older beta stores declared so existing installs migrate without
    -- loss. Renaming stores does not fix Forever's SavedVariables loader bug.
    if type(ForeverQuestPinsDB) ~= "table" then
        ForeverQuestPinsDB = {}
    end
    if type(ForeverQuestPinsCharDB) ~= "table" then
        ForeverQuestPinsCharDB = {}
    end
    if type(ForeverQuestPinsDB_Settings) ~= "table" then
        ForeverQuestPinsDB_Settings = {}
    end
    if type(ForeverQuestPinsCharacterSettings) ~= "table" then
        ForeverQuestPinsCharacterSettings = {}
    end
    local account = ForeverQuestPinsDB
    local character = ForeverQuestPinsCharDB
    local legacyAccount = ForeverQuestPinsDB_Settings
    local legacyCharacter = ForeverQuestPinsCharacterSettings
    local source, revision = ChooseSettings(
        account,
        character,
        legacyAccount,
        legacyCharacter,
        DecodeMirror()
    )

    CopySettings(source, account, revision)
    CopyDefaults(ns.defaults, account)
    account._revision = revision
    CopySettings(account, character, revision)
    CopySettings(account, legacyAccount, revision)
    CopySettings(account, legacyCharacter, revision)
    ns.db = account
    ns.settingsSource = source == account and "account"
        or (source == character and "character"
        or (source == legacyAccount and "legacy-account"
        or (source == legacyCharacter and "legacy-character" or "cvar")))
    SaveMirror(account)
    return account
end

local function SyncSettings()
    local db = ns.db or ns.InitSettings()
    CopySettings(db, ForeverQuestPinsDB, Revision(db))
    CopySettings(db, ForeverQuestPinsCharDB, Revision(db))
    CopySettings(db, ForeverQuestPinsDB_Settings, Revision(db))
    CopySettings(db, ForeverQuestPinsCharacterSettings, Revision(db))
    SaveMirror(db)
    return db
end

function ns.FlushSettings()
    return SyncSettings()
end

function ns.WipeSettings()
    local db = ns.InitSettings()
    for key, value in pairs(ns.defaults) do
        db[key] = value
    end
    db._revision = Revision(db) + 1
    SyncSettings()
    if ns.SyncSettingsCheckboxes then
        ns.SyncSettingsCheckboxes()
    end
end

function ns.GetSettings()
    return ns.db
end

function ns.GetOption(key)
    local settings = ns.db
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return ns.defaults[key]
end

function ns.SetOption(key, value)
    if type(ns.defaults[key]) == "number" then
        value = tonumber(value)
        if not value or value ~= value then
            return
        end
        value = math.max(-5, math.min(5, math.floor(value + 0.5)))
    else
        value = value and true or false
    end
    local db = ns.db or ns.InitSettings()
    db[key] = value
    db._revision = Revision(db) + 1
    SyncSettings()
    if key == "enabled" and not value and ns.MapPins then
        ns.MapPins:Clear()
    end
    if ns.SyncSettingsCheckboxes then ns.SyncSettingsCheckboxes() end
    if ns.RequestRefresh then
        ns.RequestRefresh("settings")
    end
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
        print("  /fqp trivial  Toggle low-level/trivial pins (off by default)")
        print("  /fqp repeatable Toggle repeatable quest pins (on by default)")
        print("  /fqp seasonal Toggle holiday/seasonal pins (off by default)")
        print("  /fqp wareffort Toggle AQ war effort pins in capitals (off by default)")
        print("  /fqp accept   Toggle auto-accept quests")
        print("  /fqp turnin   Toggle auto-turn in quests")
        print("  /fqp debug    Toggle debug tooltips and chat diagnostics")
        print("  /fqp refresh  Rebuild pins on the current map")
        print("  /fqp stats    Print database and pin counts")
        print("  /fqp settings Print saved option values (debug)")
        print("  /fqp wipe     Reset options (only needed after an older broken beta)")
        print("  /fqp apis     Print which Forever map/quest APIs are present")
        print("  /fqp why <id> Show why a quest is pinned or hidden")
        print("  /fqp available List quests that should pin on this map")
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
    if msg == "repeatable" then
        ToggleFlag("showRepeatable", "Show repeatable quests")
        return
    end
    if msg == "seasonal" then
        ToggleFlag("showSeasonal", "Show seasonal/holiday pins")
        return
    end
    if msg == "wareffort" or msg == "war" then
        ToggleFlag("showWarEffort", "Show AQ war effort pins")
        return
    end
    if msg == "accept" then
        ToggleFlag("autoAccept", "Auto-accept quests")
        return
    end
    if msg == "turnin" then
        ToggleFlag("autoTurnIn", "Auto-turn in quests")
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
    if msg == "settings" then
        ns.PrintSettingsDebug()
        return
    end
    if msg == "wipe" then
        ns.WipeSettings()
        Print("In-memory options reset to defaults.")
        Print("Only needed if you used a 0.1.10–0.1.16 beta that left empty SavedVariables.")
        Print("Close the game completely, then delete:")
        print("  WTF\\Account\\<account>\\SavedVariables\\ForeverQuestPins.lua")
        print("  WTF\\Account\\<account>\\<realm>\\<char>\\SavedVariables\\ForeverQuestPins.lua")
        print("  (and the .bak next to each)")
        Print("Then start the client. New installs do not need this.")
        return
    end
    if msg == "apis" then
        ns.PrintAPIProbe()
        return
    end

    if msg == "hoverprobe" then
        if ns.NPCTooltips then
            ns.NPCTooltips:ArmProbe()
        else
            Print("NPC tooltip module is unavailable.")
        end
        return
    end

    if msg == "available" then
        ns.PrintAvailableOnMap()
        return
    end

    local whyID = msg:match("^why%s+(%d+)$")
    if whyID then
        ns.PrintQuestWhy(tonumber(whyID))
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
    Print(("%s | %d quests | %d attunements | %d maps"):format(
        tostring(meta.source or meta.attCommit or "?"),
        count,
        tonumber(meta.attunementCount) or 0,
        maps
    ))
    Print(("  auto-accept %s | auto-turn-in %s"):format(
        ns.GetOption("autoAccept") and "on" or "off",
        ns.GetOption("autoTurnIn") and "on" or "off"
    ))
    if ns.settingsMode then
        print("  options UI: " .. tostring(ns.settingsMode))
    end
    if ns.MapPins and ns.MapPins.GetStatus then
        local status = ns.MapPins:GetStatus()
        print(("  viewed map %s | painted %s | mode %s | parent %s"):format(
            tostring(status.viewedMap),
            tostring(status.count),
            tostring(status.mode),
            tostring(status.parent or "?")
        ))
        if status.lastError then
            print("  last error: " .. tostring(status.lastError))
        end
        if status.icon then
            print("  pin icon: " .. tostring(status.icon))
        end
    end
end

function ns.PrintSettingsDebug()
    ns.InitSettings()
    local account = ForeverQuestPinsDB
    local character = ForeverQuestPinsCharDB
    Print("SavedVariables ForeverQuestPinsDB:")
    print(("  db=%s account=%s character=%s sameAsGlobal=%s mirror=%s source=%s"):format(
        tostring(ns.db ~= nil),
        tostring(type(account) == "table"),
        tostring(type(character) == "table"),
        tostring(ns.db ~= nil and ns.db == ForeverQuestPinsDB),
        tostring(ns.settingsMirror ~= nil and ns.settingsMirror ~= ""),
        tostring(ns.settingsSource or "?")
    ))
    print(("  revisions: account=%s character=%s"):format(
        tostring(Revision(account)),
        tostring(Revision(character))
    ))
    print("  Account, character, and CVar settings are synchronized; the newest revision wins.")
    for _, key in ipairs({
        "enabled",
        "showNPCTooltips",
        "showTrivial",
        "showRepeatable",
        "showSeasonal",
        "showWarEffort",
        "autoAccept",
        "autoAcceptRangeEnabled",
        "autoAcceptLevelOffset",
        "autoTurnIn",
        "debug",
    }) do
        local raw = account and account[key]
        local effective = ns.GetOption(key)
        print(("  %s raw=%s effective=%s"):format(
            key,
            raw == nil and "nil" or tostring(raw),
            tostring(effective)
        ))
    end
    if ns.settingsMode then
        print("  options UI: " .. tostring(ns.settingsMode))
    end
end

function ns.PrintQuestWhy(questID)
    if ns.InvalidateCompletionCache then
        ns.InvalidateCompletionCache()
    end
    if not questID then
        Print("Usage: /fqp why <questID>")
        return
    end
    local data = ns.Quests and ns.Quests[questID]
    if not data then
        Print("Quest " .. tostring(questID) .. " is not in the quest-start database.")
        return
    end
    local title = ns.GetQuestTitle and ns.GetQuestTitle(questID)
    local available, reason = ns.IsQuestAvailable(questID, data)
    Print(("Quest %s%s: %s (%s)"):format(
        tostring(questID),
        title and (" " .. title) or "",
        available and "would pin" or "hidden",
        tostring(reason)
    ))
    print(("  completed=%s in-log=%s"):format(
        tostring(not not ns.IsQuestFlaggedCompleted(questID)),
        tostring(not not ns.IsOnQuest(questID))
    ))
    local qg = data.qg or (data.qgs and data.qgs[1])
    print(("  map %s @ %.1f, %.1f qg=%s faction=%s minLevel=%s"):format(
        tostring(data.mapID),
        data.x or 0,
        data.y or 0,
        tostring(qg or "object"),
        tostring(data.faction or "-"),
        tostring(data.minLevel or "-")
    ))
    local viewedMapID = ns.GetViewedMapID and ns.GetViewedMapID()
    if available and ns.ProjectToViewedMap and viewedMapID then
        local nx, ny = ns.ProjectToViewedMap(data.mapID, data.x, data.y, viewedMapID)
        if nx and ny then
            print(("  would paint on map %s at %.1f, %.1f"):format(tostring(viewedMapID), nx * 100, ny * 100))
        else
            print("  would pin but coords do not project onto the viewed map")
        end
    end
    if ns.MapPins and ns.MapPins.GetStatus then
        local status = ns.MapPins:GetStatus()
        local painted = status.paintedIDs and status.paintedIDs[questID]
        print("  painted last refresh: " .. (painted and "yes" or "no"))
        print("  map mode " .. tostring(status.mode) .. " parent " .. tostring(status.parent or "?") .. " icon " .. tostring(status.icon or "?"))
    end
    local sources = data.sourceQuests
    if not sources or #sources == 0 then
        print("  sourceQuests: none")
        return
    end
    for i = 1, #sources do
        local srcID = sources[i]
        local src = ns.Quests and ns.Quests[srcID]
        print(("  source %s: flagged=%s in-log=%s object=%s treated-complete=%s"):format(
            tostring(srcID),
            tostring(not not ns.IsQuestFlaggedCompleted(srcID)),
            tostring(not not ns.IsOnQuest(srcID)),
            tostring((src and not ns.HasQuestGiver(src)) or false),
            tostring(not not ns.IsSourceSatisfied(srcID))
        ))
    end
end

function ns.PrintAvailableOnMap()
    local viewedMapID = ns.GetViewedMapID and ns.GetViewedMapID()
    if not viewedMapID then
        Print("No viewed map. Open the world map first.")
        return
    end
    if ns.InvalidateCompletionCache then
        ns.InvalidateCompletionCache()
    end
    local byMap = ns.ByMap or {}
    local quests = ns.Quests or {}
    local seen = {}
    local count = 0
    Print("Would pin on map " .. tostring(viewedMapID) .. ":")
    local function consider(questID)
        if not questID or seen[questID] then
            return
        end
        seen[questID] = true
        local data = quests[questID]
        if not data then
            return
        end
        local available, reason = ns.IsQuestAvailable(questID, data)
        if not available then
            return
        end
        if ns.ProjectToViewedMap then
            local nx = ns.ProjectToViewedMap(data.mapID, data.x, data.y, viewedMapID)
            if not nx then
                return
            end
        elseif data.mapID ~= viewedMapID then
            return
        end
        count = count + 1
        local title = ns.GetQuestTitle and ns.GetQuestTitle(questID)
        print(("  %s %s @ %.1f, %.1f (%s)"):format(
            tostring(questID),
            title or "",
            data.x or 0,
            data.y or 0,
            tostring(reason)
        ))
    end
    local list = byMap[viewedMapID]
    if list then
        for i = 1, #list do
            consider(list[i])
        end
    end
    for mapID, ids in pairs(byMap) do
        if mapID ~= viewedMapID then
            for i = 1, #ids do
                consider(ids[i])
            end
        end
    end
    if ns.offeredQuestIDs then
        for questID in pairs(ns.offeredQuestIDs) do
            consider(questID)
        end
    end
    print("  count " .. tostring(count))
end

function ns.PrintAPIProbe()
    local function has(value)
        return value and "yes" or "no"
    end
    Print("API probe (verify these on Interface 16001):")
    print("  C_QuestLog.IsQuestFlaggedCompleted: " .. has(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted))
    print("  C_QuestLog.GetAllCompletedQuestIDs: " .. has(C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs))
    print("  GetQuestsCompleted: " .. has(GetQuestsCompleted))
    print("  HasQuestCompletionAPI: " .. has(ns.HasQuestCompletionAPI and ns.HasQuestCompletionAPI()))
    print("  C_QuestLog.IsOnQuest: " .. has(C_QuestLog and C_QuestLog.IsOnQuest))
    print("  C_QuestLog.GetTitleForQuestID: " .. has(C_QuestLog and C_QuestLog.GetTitleForQuestID))
    print("  C_QuestLog.GetQuestDifficultyLevel: " .. has(C_QuestLog and C_QuestLog.GetQuestDifficultyLevel))
    print("  C_QuestLog.RequestLoadQuestByID: " .. has(C_QuestLog and C_QuestLog.RequestLoadQuestByID))
    print("  C_QuestLog.UnitIsRelatedToActiveQuest: " .. has(C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest))
    print("  C_TooltipInfo.GetUnit: " .. has(C_TooltipInfo and C_TooltipInfo.GetUnit))
    print("  C_TooltipInfo.GetHyperlink: " .. has(C_TooltipInfo and C_TooltipInfo.GetHyperlink))
    print("  C_Map.GetMapRectOnMap: " .. has(C_Map and C_Map.GetMapRectOnMap))
    print("  C_Map.GetMapChildrenInfo: " .. has(C_Map and C_Map.GetMapChildrenInfo))
    print("  WorldMapFrame.AddDataProvider: " .. has(WorldMapFrame and WorldMapFrame.AddDataProvider))
    print("  WorldMapFrame.SetPinPosition: " .. has(WorldMapFrame and WorldMapFrame.SetPinPosition))
    print("  WorldMapFrame.EnumeratePinsByTemplate: " .. has(WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate))
    print("  MapCanvasDataProviderMixin: " .. has(MapCanvasDataProviderMixin))
    print("  MapCanvasPinMixin: " .. has(MapCanvasPinMixin))
    print("  Settings API: " .. has(Settings and Settings.RegisterAddOnCategory))
    print("  GetQuestGreenRange: " .. has(GetQuestGreenRange))
    print("  C_GossipInfo.GetAvailableQuests: " .. has(C_GossipInfo and C_GossipInfo.GetAvailableQuests))
    print("  C_GossipInfo.GetActiveQuests: " .. has(C_GossipInfo and C_GossipInfo.GetActiveQuests))
    print("  AcceptQuest: " .. has(AcceptQuest))
    print("  GetQuestReward: " .. has(GetQuestReward))
    print("  C_Texture.GetAtlasInfo: " .. has(C_Texture and C_Texture.GetAtlasInfo))
    local atlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestNormal")
    print("  QuestNormal atlas: " .. has(atlas))
    local repeatableAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("QuestDaily")
    print("  QuestDaily atlas: " .. has(repeatableAtlas))
    if ns.MapPins and ns.MapPins.GetStatus then
        local status = ns.MapPins:GetStatus()
        print("  pin icon: " .. tostring(status.icon or "not painted yet"))
        print("  pin parent: " .. tostring(status.parent or "not painted yet"))
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

local function CreateOptionCheckbox(parent, optionKey, label, tooltip)
    local box
    local ok, created = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if ok then
        box = created
    else
        box = CreateFrame("CheckButton", nil, parent)
        box:SetSize(26, 26)
    end
    local text = box.Text
    if not text then
        text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", box, "RIGHT", 4, 1)
        box.Text = text
    end
    text:SetText(label)
    box.optionKey = optionKey
    local applying = false
    box:SetScript("OnClick", function(self)
        if applying then
            return
        end
        -- Do not trust GetChecked here: some templates have not flipped yet.
        local value = not ns.GetOption(optionKey)
        ns.SetOption(optionKey, value)
        applying = true
        self:SetChecked(value)
        applying = false
        if optionKey == "enabled" and not value and ns.MapPins then
            ns.MapPins:Clear()
        end
    end)
    box.ApplySaved = function(self)
        local script = self:GetScript("OnClick")
        self:SetScript("OnClick", nil)
        applying = true
        self:SetChecked(not not ns.GetOption(optionKey))
        applying = false
        self:SetScript("OnClick", script)
    end
    box:SetScript("OnShow", function(self)
        self:ApplySaved()
    end)
    if tooltip then
        box:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    box:ApplySaved()
    optionChecks[#optionChecks + 1] = box
    return box
end

function ns.SyncSettingsCheckboxes()
    for i = 1, #optionChecks do
        local box = optionChecks[i]
        if box and box.ApplySaved then
            box:ApplySaved()
        end
    end
end

function ns.TryRegisterSettings()
    if ns.settingsRegistered then
        return true
    end
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        return false
    end

    local panel = CreateFrame("Frame")
    panel.name = "Forever Quest Pins"
    panel:SetScript("OnShow", function(self)
        if not self.built then
            self.built = true
            local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOPLEFT", 16, -16)
            title:SetText("Forever Quest Pins")
            local help = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
            help:SetWidth(500)
            help:SetJustifyH("LEFT")
            help:SetText("Yellow ! markers for normal quests, blue ! markers for repeatable quests, purple ! markers for PvP quests, and red-orange ! markers for dungeon/raid quests and attunement chains. Hold Shift while talking to an NPC to skip auto accept / turn-in once.")

            local pins = CreateOptionCheckbox(
                self,
                "enabled",
                "Show quest-start pins",
                "Start markers on the world map for unaccepted quests."
            )
            pins:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -4, -16)

            local trivial = CreateOptionCheckbox(
                self,
                "showTrivial",
                "Show trivial / low-level pins",
                "Only hides trivial pins when GetQuestGreenRange exists."
            )
            trivial:SetPoint("TOPLEFT", pins, "BOTTOMLEFT", 0, -4)

            local repeatable = CreateOptionCheckbox(
                self,
                "showRepeatable",
                "Show repeatable quest pins",
                "Blue start markers for repeatable quests."
            )
            repeatable:SetPoint("TOPLEFT", trivial, "BOTTOMLEFT", 0, -4)

            local seasonal = CreateOptionCheckbox(
                self,
                "showSeasonal",
                "Show seasonal / holiday pins",
                "Lunar Festival elders, Darkmoon Faire, and other event quests."
            )
            seasonal:SetPoint("TOPLEFT", repeatable, "BOTTOMLEFT", 0, -4)

            local warEffort = CreateOptionCheckbox(
                self,
                "showWarEffort",
                "Show AQ war effort pins",
                "Commodity turn-ins at Orgrimmar / Ironforge (Senior Sergeants, signets, \"Needs Your Help\")."
            )
            warEffort:SetPoint("TOPLEFT", seasonal, "BOTTOMLEFT", 0, -4)

            local npcTooltips = CreateOptionCheckbox(self, "showNPCTooltips",
                "Show NPC quest tooltips", "Show recommended quest levels for available quest starts, and for quests in your log that turn in to the NPC. Independent of map-pin visibility.")
            npcTooltips:SetPoint("TOPLEFT", warEffort, "BOTTOMLEFT", 0, -4)

            local accept = CreateOptionCheckbox(
                self,
                "autoAccept",
                "Auto-accept quests",
                "Accept quests automatically when you talk to an NPC. Hold Shift to skip."
            )
            accept:SetPoint("TOPLEFT", npcTooltips, "BOTTOMLEFT", 0, -4)

            local range = CreateOptionCheckbox(self, "autoAcceptRangeEnabled",
                "Limit auto-accept quest level", "Only auto-accept quests at or below your level plus the offset. Unknown quest levels are left for manual acceptance.")
            range:SetPoint("TOPLEFT", accept, "BOTTOMLEFT", 0, -4)
            local slider = CreateFrame("Slider", nil, self, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", range, "BOTTOMLEFT", 8, -24)
            slider:SetSize(260, 16)
            slider:SetMinMaxValues(-5, 5)
            slider:SetValueStep(1)
            local label = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("BOTTOM", slider, "TOP", 0, 4)
            slider.ApplySaved = function(control)
                control.syncing = true
                local offset = ns.GetOption("autoAcceptLevelOffset")
                control:SetValue(offset)
                label:SetText(("Auto Accept quest Range: %+d levels"):format(offset))
                control:EnableMouse(ns.GetOption("autoAccept") and ns.GetOption("autoAcceptRangeEnabled"))
                control:SetAlpha(ns.GetOption("autoAcceptRangeEnabled") and 1 or 0.5)
                control.syncing = false
            end
            slider:SetScript("OnValueChanged", function(control, value)
                if control.syncing then return end
                ns.SetOption("autoAcceptLevelOffset", value)
                control:ApplySaved()
            end)
            optionChecks[#optionChecks + 1] = slider

            local turnin = CreateOptionCheckbox(
                self,
                "autoTurnIn",
                "Auto-turn in quests",
                "Turn in completed quests automatically. Does not pick when there are multiple rewards. Hold Shift to skip."
            )
            turnin:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -8, -16)

            local debugBox = CreateOptionCheckbox(
                self,
                "debug",
                "Debug tooltips",
                "Show quest IDs, NPC IDs, map coordinates, and pin-parent diagnostics on hover."
            )
            debugBox:SetPoint("TOPLEFT", turnin, "BOTTOMLEFT", 0, -4)

            local slash = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            slash:SetPoint("TOPLEFT", debugBox, "BOTTOMLEFT", 8, -12)
            slash:SetText("Slash commands: /fqp  /fqp repeatable  /fqp accept  /fqp turnin  /fqp debug  /fqp why <id>")
        end
        ns.SyncSettingsCheckboxes()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Forever Quest Pins")
    if category then
        Settings.RegisterAddOnCategory(category)
        ns.settingsRegistered = true
        ns.settingsMode = "canvas"
        return true
    end
    return false
end
