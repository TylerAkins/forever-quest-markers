local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local pages = {
    { title = "Map pins", options = {
        { "enabled", "Show quest start pins" },
        { "showWorldMapPins", "Show quest pins on world and continent maps" },
        { "showUnexplored", "Show quests in unexplored areas" },
        { "showRepeatable", "Show repeatable quest pins" },
        { "showSeasonal", "Show seasonal / holiday quest pins" },
        { "showWarEffort", "Show AQ war effort pins" },
        { "showTrivial", "Show low-level quests" },
    } },
    { title = "Quest categories", options = {
        { "showNormal", "Show normal quest start pins" },
        { "showClass", "Show class quest pins" },
        { "showDungeon", "Show dungeon / raid quest pins" },
        { "showPvP", "Show PvP quest pins" },
        { "showProfession", "Show profession quest pins" },
        { "showWarEffortAlways", "Always show AQ war effort pins" },
        { "showBooks", "Show collectible book quest pins" },
    } },
    { title = "Navigation", options = {
        { "enablePinTracking", "Click pins to track quest starts" },
        { "trackOnWorldMaps", "Track from world and continent maps" },
        { "showNPCTooltips", "Show quests on NPC tooltips" },
        { "showNameplateIcons", "Show quest icons on nameplates" },
        { "showSpawnClusters", "Show spawn clusters" },
        { "highlightNewQuests", "Show tint for quests new in WoW Forever" },
        { "sparkleQuestItems", "Show quest item sparkles" },
    } },
    { title = "Quest tracker", options = {
        { "enhanceQuestTracker", L["Enhance quest tracker"] .. " (BETA)" },
        { "selectNearestQuest", "Select nearest quest" },
    } },
    { title = "Quest automation", options = {
        { "autoAccept", "Auto-accept quests" },
        { "autoAcceptRangeEnabled", "Limit auto-accept quest level" },
        { "autoAcceptSkipGrey", "Don't auto-accept grey quests" },
        { "autoTurnIn", "Auto-turn in quests" },
        { "hideQuestTrackerInCombat", "Hide quest tracker in combat" },
        { "warnSkippedBreadcrumb", "Warn on skipped breadcrumbs" },
    } },
}

local frame
local function Complete()
    ns.SaveWelcomeState(true)
    frame:Hide()
end

local function MakeButton(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("BOTTOMLEFT", x, y)
    button:SetText(L[label])
    button:SetScript("OnClick", callback)
    return button
end

local function CreateSetup()
    local panel = CreateFrame("Frame", "ForeverQuestPinsSetup", UIParent, "BackdropTemplate")
    panel:SetSize(500, 400)
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
    title:SetPoint("TOPLEFT", 30, -26)
    title:SetText("|cffffd100Forever|r |cff65b9ffQuest Pins|r")
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 30, -65)
    local progress = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    progress:SetPoint("TOPRIGHT", -30, -67)
    local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
    help:SetWidth(440)
    help:SetJustifyH("LEFT")
    local checks = {}
    local levelRange
    local function UpdateOffsetEnabled()
        levelRange:SetActive(panel.pending.autoAccept and panel.pending.autoAcceptRangeEnabled)
        for _, box in ipairs(checks) do
            if box.key == "autoAcceptSkipGrey" or box.key == "autoAcceptRangeEnabled" then
                local enabled = panel.pending.autoAccept and true or false
                box:SetEnabled(enabled)
                box.Text:SetAlpha(enabled and 1 or 0.5)
            end
        end
    end
    for i = 1, 7 do
        local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        box:SetSize(26, 26)
        box:SetPoint("TOPLEFT", 28, -135 - (i - 1) * 31)
        if not box.Text then
            box.Text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            box.Text:SetPoint("LEFT", box, "RIGHT", 4, 1)
        end
        box.Text:SetWidth(410)
        box.Text:SetJustifyH("LEFT")
        box:SetScript("OnClick", function(self)
            if self.disabledForGamepad then
                return
            end
            panel.pending[self.key] = not not self:GetChecked()
            if self.key == "autoAccept" or self.key == "autoAcceptRangeEnabled" then
                UpdateOffsetEnabled()
            end
        end)
        checks[i] = box
    end
    levelRange = ns.CreateLevelRangeSlider(panel, function()
        return math.min(panel.pending.autoAcceptMinLevelOffset, panel.pending.autoAcceptLevelOffset),
            panel.pending.autoAcceptLevelOffset
    end, function(lowValue, highValue)
        panel.pending.autoAcceptMinLevelOffset = lowValue
        panel.pending.autoAcceptLevelOffset = highValue
    end)
    levelRange:SetPoint("TOPLEFT", 50, -200)
    local back, nextButton
    local function Render()
        local page = panel.page
        local guided = page > 0
        local gamepad = InputUtil
            and type(InputUtil.IsGamepadUIEnabled) == "function"
            and InputUtil.IsGamepadUIEnabled()
        local trackerPage = guided and pages[page].title == "Quest tracker"
        panel:SetHeight(guided and (page == #pages and 450 or 400) or 200)
        progress:SetText(guided and (page .. " / " .. #pages) or "")
        heading:SetText(guided and L[pages[page].title] or L["Choose your options"])
        help:SetText(guided and (trackerPage and gamepad
                and L["The quest tracker is unavailable in gamepad UI."]
                or L["Choose what works for you. You can change these later in the addon options."])
            or L["Set up quest pins, use the defaults, or keep your current settings."])
        for i, box in ipairs(checks) do
            local option = guided and pages[page].options[i]
            if option then
                box:ClearAllPoints()
                local lastPage = page == #pages
                -- The Navigation page has seven options. Tighten the rows so the
                -- last one clears the buttons.
                local compact = #pages[page].options >= 7
                local firstY = lastPage and -120 or (compact and -128 or -135)
                local spacing = (lastPage or compact) and 30 or 31
                local extra = lastPage and i >= 3 and 74 or 0
                box:SetPoint("TOPLEFT", 28, firstY - (i - 1) * spacing - extra)
                box.key = option[1]
                local disabled = trackerPage and gamepad and true or false
                box.disabledForGamepad = disabled
                box:SetEnabled(not disabled)
                box.Text:SetAlpha(disabled and 0.5 or 1)
                box.Text:SetText(L[option[2]])
                box:SetChecked(panel.pending[box.key])
                box:Show()
            else
                box:Hide()
            end
        end
        levelRange:SetShown(page == #pages)
        if page == #pages then
            levelRange:ApplySaved()
            UpdateOffsetEnabled()
        end
        panel.keep:SetShown(not guided)
        panel.defaults:SetShown(not guided)
        panel.guide:SetShown(not guided)
        back:SetShown(guided)
        nextButton:SetShown(guided)
        nextButton:SetText(L[page == #pages and "Apply" or "Next"])
    end
    panel.keep = MakeButton(panel, "Use Current Settings", 25, 30, 140, Complete)
    panel.defaults = MakeButton(panel, "Use Defaults", 180, 30, 140, function()
        ns.WipeSettings()
        if ns.SyncQuestTrackerCombatVisibility then ns.SyncQuestTrackerCombatVisibility() end
        if ns.RequestRefresh then ns.RequestRefresh("settings") end
        Complete()
    end)
    panel.guide = MakeButton(panel, "Choose Options", 335, 30, 140, function()
        panel.page = 1
        Render()
    end)
    back = MakeButton(panel, "Back", 25, 30, 140, function()
        panel.page = panel.page - 1
        Render()
    end)
    nextButton = MakeButton(panel, "Next", 335, 30, 140, function()
        if panel.page < #pages then
            panel.page = panel.page + 1
            Render()
            return
        end
        for key, value in pairs(panel.pending) do
            if value ~= panel.original[key] then
                local gamepad = InputUtil
                    and type(InputUtil.IsGamepadUIEnabled) == "function"
                    and InputUtil.IsGamepadUIEnabled()
                if not (gamepad and (key == "enhanceQuestTracker" or key == "selectNearestQuest")) then
                    ns.SetOption(key, value)
                end
            end
        end
        Complete()
    end)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", Complete)
    panel.Begin = function(self)
        self.page, self.pending, self.original = 0, {}, {}
        for _, page in ipairs(pages) do
            for _, option in ipairs(page.options) do
                local value = not not ns.GetOption(option[1])
                self.pending[option[1]], self.original[option[1]] = value, value
            end
        end
        for _, key in ipairs({ "autoAcceptLevelOffset", "autoAcceptMinLevelOffset" }) do
            self.pending[key] = ns.GetOption(key)
            self.original[key] = self.pending[key]
        end
        Render()
        self:Show()
    end
    panel:Hide()
    return panel
end

function ns.ShowSetup()
    if not frame then frame = CreateSetup() end
    frame:Begin()
end

local function VersionNumber(version)
    if type(version) ~= "string" then return 0 end
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return 0 end
    return tonumber(major) * 100000000 + tonumber(minor) * 10000 + tonumber(patch)
end

function ns.StartWelcome()
    local news = ns.WhatsNew
    if news and VersionNumber(news.version) > VersionNumber(ns.db._newsVersion) then
        print("|cffffd100Forever Quest Pins:|r What is new in " .. news.version .. ":")
        for _, line in ipairs(news.lines) do print("  - " .. line) end
        ns.SaveWelcomeState(false, news.version)
    end
    if not ns.db._setupComplete then ns.ShowSetup() end
end
