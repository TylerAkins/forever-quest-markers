local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.defaults = {
    enabled = true,
    showTrivial = true,
    showSeasonal = false,
    autoAccept = false,
    autoTurnIn = false,
    debug = false,
}

local SV_NAME = "ForeverQuestPinsDB_Settings"
local sessionScratch = nil
local optionChecks = {}

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

local function ReadSaved()
    local fromGlobal = _G[SV_NAME]
    if type(fromGlobal) == "table" then
        return fromGlobal
    end
    if type(ForeverQuestPinsDB_Settings) == "table" then
        return ForeverQuestPinsDB_Settings
    end
    return nil
end

local function PublishSaved(sv)
    ForeverQuestPinsDB_Settings = sv
    _G[SV_NAME] = sv
end

-- Forever can inject SavedVariables after our Lua files run. Do not assign
-- `ForeverQuestPinsDB_Settings = {}` at file load: that table is not written
-- to WTF on /reload. Merge session changes once the real table exists.
function ns.EnsureSettingsDB(create)
    local live = ReadSaved()
    if live then
        if sessionScratch then
            for key, value in pairs(sessionScratch) do
                live[key] = value
            end
            sessionScratch = nil
        end
        CopyDefaults(ns.defaults, live)
        PublishSaved(live)
        return live
    end
    if not create or not ns.allowCreateSettings then
        return nil
    end
    live = CopyDefaults(ns.defaults, {})
    if sessionScratch then
        for key, value in pairs(sessionScratch) do
            live[key] = value
        end
        sessionScratch = nil
    end
    PublishSaved(live)
    return live
end

function ns.HydrateSettings()
    return ns.EnsureSettingsDB(false)
end

function ns.InitSettings()
    return ns.EnsureSettingsDB(true)
end

function ns.GetSettings()
    return ReadSaved() or sessionScratch
end

function ns.GetOption(key)
    local settings = ns.EnsureSettingsDB(false) or sessionScratch
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return ns.defaults[key]
end

function ns.SetOption(key, value)
    value = value and true or false
    local live = ns.EnsureSettingsDB(false)
    if live then
        live[key] = value
        PublishSaved(live)
    else
        sessionScratch = sessionScratch or CopyDefaults(ns.defaults, {})
        sessionScratch[key] = value
    end
    if key == "enabled" and not value and ns.MapPins then
        ns.MapPins:Clear()
    end
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
        print("  /fqp trivial  Toggle low-level/trivial pins")
        print("  /fqp seasonal Toggle holiday/seasonal pins (off by default)")
        print("  /fqp accept   Toggle auto-accept quests")
        print("  /fqp turnin   Toggle auto-turn in quests")
        print("  /fqp debug    Toggle debug tooltips and chat diagnostics")
        print("  /fqp refresh  Rebuild pins on the current map")
        print("  /fqp stats    Print database and pin counts")
        print("  /fqp settings Print saved option values (debug)")
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
    if msg == "seasonal" then
        ToggleFlag("showSeasonal", "Show seasonal/holiday pins")
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
    if msg == "apis" then
        ns.PrintAPIProbe()
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
    Print(("ATT %s | %d quests | %d maps"):format(tostring(meta.attCommit or "?"), count, maps))
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
    local sv = ReadSaved()
    local scratch = sessionScratch ~= nil
    Print("SavedVariables ForeverQuestPinsDB_Settings:")
    print(("  bound=%s scratch=%s sameAsGlobal=%s"):format(
        sv ~= nil,
        scratch,
        tostring(sv ~= nil and sv == _G[SV_NAME])
    ))
    for _, key in ipairs({
        "enabled",
        "showTrivial",
        "showSeasonal",
        "autoAccept",
        "autoTurnIn",
        "debug",
    }) do
        local raw = sv and sv[key]
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
        Print("Quest " .. tostring(questID) .. " is not in the ATT start database.")
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

local OPTION_SPECS = {
    {
        key = "enabled",
        name = "Show quest-start pins",
        tooltip = "Yellow start markers on the world map for unaccepted quests.",
    },
    {
        key = "showTrivial",
        name = "Show trivial / low-level pins",
        tooltip = "Only hides trivial pins when GetQuestGreenRange exists.",
    },
    {
        key = "showSeasonal",
        name = "Show seasonal / holiday pins",
        tooltip = "Lunar Festival elders, Darkmoon Faire, and other event quests.",
    },
    {
        key = "autoAccept",
        name = "Auto-accept quests",
        tooltip = "Accept quests automatically when you talk to an NPC. Hold Shift to skip.",
    },
    {
        key = "autoTurnIn",
        name = "Auto-turn in quests",
        tooltip = "Turn in completed quests automatically. Does not pick when there are multiple rewards. Hold Shift to skip.",
    },
    {
        key = "debug",
        name = "Debug tooltips",
        tooltip = "Show quest IDs, NPC IDs, map coordinates, and pin-parent diagnostics on hover.",
    },
}

local function BoolVarType()
    if Settings and Settings.VarType and Settings.VarType.Boolean then
        return Settings.VarType.Boolean
    end
    return "boolean"
end

local function RegisterNativeSettings()
    if not Settings.RegisterVerticalLayoutCategory then
        return false
    end
    local category = Settings.RegisterVerticalLayoutCategory("Forever Quest Pins")
    if not category then
        return false
    end
    local registered = 0
    local mode = nil
    for i = 1, #OPTION_SPECS do
        local spec = OPTION_SPECS[i]
        local variable = ADDON_NAME .. "_" .. spec.key
        local setting
        if Settings.RegisterProxySetting then
            local ok, result = pcall(
                Settings.RegisterProxySetting,
                category,
                variable,
                type(ns.defaults[spec.key]),
                spec.name,
                ns.defaults[spec.key],
                function()
                    return ns.GetOption(spec.key)
                end,
                function(value)
                    ns.SetOption(spec.key, value)
                end
            )
            if ok and result then
                setting = result
                mode = mode or "proxy"
            end
        end
        if not setting and Settings.RegisterAddOnSetting then
            local ok, result = pcall(
                Settings.RegisterAddOnSetting,
                category,
                variable,
                spec.key,
                ForeverQuestPinsDB_Settings,
                BoolVarType(),
                spec.name,
                ns.defaults[spec.key]
            )
            if ok and result then
                setting = result
                mode = mode or "savedvars"
            end
        end
        if setting then
            registered = registered + 1
            if not pcall(Settings.CreateCheckbox, category, setting, spec.tooltip) then
                pcall(Settings.CreateCheckBox, category, setting, spec.tooltip)
            end
        end
    end
    if registered == 0 then
        return false
    end
    if Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(category)
    end
    ns.settingsMode = mode or "native"
    return true
end

function ns.TryRegisterSettings()
    if ns.settingsRegistered then
        return true
    end
    if not Settings then
        return false
    end
    local db = ns.EnsureSettingsDB(false) or ns.EnsureSettingsDB(true)
    if not db then
        return false
    end
    if RegisterNativeSettings() then
        ns.settingsRegistered = true
        return true
    end
    if not Settings.RegisterCanvasLayoutCategory then
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
            help:SetText("Yellow ! markers on the world map for quests you can accept but have not already taken. Hold Shift while talking to an NPC to skip auto accept / turn-in once.")

            local pins = CreateOptionCheckbox(
                self,
                "enabled",
                "Show quest-start pins",
                "Yellow start markers on the world map for unaccepted quests."
            )
            pins:SetPoint("TOPLEFT", help, "BOTTOMLEFT", -4, -16)

            local trivial = CreateOptionCheckbox(
                self,
                "showTrivial",
                "Show trivial / low-level pins",
                "Only hides trivial pins when GetQuestGreenRange exists."
            )
            trivial:SetPoint("TOPLEFT", pins, "BOTTOMLEFT", 0, -4)

            local seasonal = CreateOptionCheckbox(
                self,
                "showSeasonal",
                "Show seasonal / holiday pins",
                "Lunar Festival elders, Darkmoon Faire, and other event quests."
            )
            seasonal:SetPoint("TOPLEFT", trivial, "BOTTOMLEFT", 0, -4)

            local accept = CreateOptionCheckbox(
                self,
                "autoAccept",
                "Auto-accept quests",
                "Accept quests automatically when you talk to an NPC. Hold Shift to skip."
            )
            accept:SetPoint("TOPLEFT", seasonal, "BOTTOMLEFT", 0, -4)

            local turnin = CreateOptionCheckbox(
                self,
                "autoTurnIn",
                "Auto-turn in quests",
                "Turn in completed quests automatically. Does not pick when there are multiple rewards. Hold Shift to skip."
            )
            turnin:SetPoint("TOPLEFT", accept, "BOTTOMLEFT", 0, -4)

            local debugBox = CreateOptionCheckbox(
                self,
                "debug",
                "Debug tooltips",
                "Show quest IDs, NPC IDs, map coordinates, and pin-parent diagnostics on hover."
            )
            debugBox:SetPoint("TOPLEFT", turnin, "BOTTOMLEFT", 0, -4)

            local slash = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            slash:SetPoint("TOPLEFT", debugBox, "BOTTOMLEFT", 8, -12)
            slash:SetText("Slash commands: /fqp  /fqp accept  /fqp turnin  /fqp debug  /fqp why <id>")
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
