local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

local MAX_QUEUE = 5
local PADDING = 28
local BUTTON_HEIGHT = 24
local BUTTON_GAP = 8
local BUTTON_MIN_WIDTH = 120
local BUTTON_MAX_WIDTH = 240
local MIN_FRAME_WIDTH = 440
local MIN_FRAME_HEIGHT = 220

ns.Breadcrumbs = {}

local suppressed = {}
local queue = {}
local visible
local panel
local dismissing = false

local ShowNext, Dismiss, HandleAbandon, HandleWaypoint

local function Report(message)
    print("|cff33ff99Forever Quest Pins:|r " .. tostring(message))
end

local function Gold(text)
    return "|cffffd100" .. tostring(text) .. "|r"
end

local function QuestTitle(questID, data)
    local title = ns.GetQuestTitle and ns.GetQuestTitle(questID)
    if not title then
        title = data and data.title
    end
    if not title then
        title = L["Quest "] .. tostring(questID)
    end
    return title
end

-- Display filters intentionally do not apply here. A trivial, PvP, or seasonal
-- breadcrumb is still worth warning about; only restrictions that mean this
-- character cannot accept it are checked.
local function PlayerMatches(data)
    if data.faction then
        local faction = ns.GetPlayerFaction and ns.GetPlayerFaction()
        if faction and faction ~= data.faction then
            return false
        end
    end
    local races = data.races
    if races and #races > 0 then
        local raceID = ns.GetPlayerRaceID and ns.GetPlayerRaceID()
        if raceID then
            local match = false
            for i = 1, #races do
                if races[i] == raceID then
                    match = true
                    break
                end
            end
            if not match then
                return false
            end
        end
    end
    local classes = data.classes
    if classes and #classes > 0 then
        local classID = ns.GetPlayerClassID and ns.GetPlayerClassID()
        if classID then
            local match = false
            for i = 1, #classes do
                if classes[i] == classID then
                    match = true
                    break
                end
            end
            if not match then
                return false
            end
        end
    end
    if data.requireSkill and ns.HasRequiredSkill and not ns.HasRequiredSkill(data.requireSkill) then
        return false
    end
    if data.minLevel and (UnitLevel("player") or 1) < data.minLevel then
        return false
    end
    return true
end

local function IsAvailableBreadcrumb(questID)
    local data = ns.Quests and ns.Quests[questID]
    if not data or not data.isBreadcrumb then
        return false
    end
    if ns.IsQuestFlaggedCompleted(questID) then
        return false
    end
    if ns.IsOnQuest(questID) then
        return false
    end
    if ns.IsQuestHidden and ns.IsQuestHidden(questID) then
        return false
    end
    if ns.ExcludedQuests and ns.ExcludedQuests[questID] then
        return false
    end
    local alts = data.altQuests
    if alts then
        for i = 1, #alts do
            local altID = alts[i]
            if altID ~= questID
                and (ns.IsQuestFlaggedCompleted(altID) or ns.IsOnQuest(altID)) then
                return false
            end
        end
    end
    return PlayerMatches(data)
end

-- sourceQuestSingle is an OR list. When the player took a non-breadcrumb
-- route, the breadcrumb did not gate this quest and warning about it is noise.
-- sourceQuestGroup is an AND list, so its breadcrumbs stay candidates.
local function SingleRouteSatisfied(followUpQuestID, followUp)
    local single = followUp.sourceQuestSingle
    if not single or #single == 0 then
        return false
    end
    if followUp.sourceQuestNumRequired and followUp.sourceQuestNumRequired > 1 then
        return false
    end
    for i = 1, #single do
        local source = single[i]
        local data = ns.Quests and ns.Quests[source]
        if source ~= followUpQuestID and not (data and data.isBreadcrumb)
            and (ns.IsQuestFlaggedCompleted(source) or ns.IsOnQuest(source)) then
            return true
        end
    end
    return false
end

function ns.Breadcrumbs.CollectCandidates(followUpQuestID)
    local followUp = ns.Quests and ns.Quests[followUpQuestID]
    local candidates = {}
    if not followUp then
        return candidates
    end
    local seen = {}
    local function AddList(list)
        if not list then
            return
        end
        for i = 1, #list do
            local candidate = list[i]
            if candidate and not seen[candidate] then
                seen[candidate] = true
                if IsAvailableBreadcrumb(candidate) then
                    candidates[#candidates + 1] = candidate
                end
            end
        end
    end
    if not SingleRouteSatisfied(followUpQuestID, followUp) then
        AddList(followUp.sourceQuestSingle)
    end
    AddList(followUp.sourceQuestGroup)
    return candidates
end

local function BestCandidate(candidates)
    if #candidates == 0 then
        return nil
    end
    local playerMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if playerMapID then
        for i = 1, #candidates do
            local data = ns.Quests[candidates[i]]
            if data and data.mapID == playerMapID then
                return candidates[i], data
            end
        end
    end
    local first = candidates[1]
    return first, ns.Quests[first]
end

function ns.Breadcrumbs.FindSkippedBreadcrumb(followUpQuestID)
    return BestCandidate(ns.Breadcrumbs.CollectCandidates(followUpQuestID))
end

local function DropFollowUp(followUpQuestID)
    local kept = {}
    for i = 1, #queue do
        if queue[i].followUp ~= followUpQuestID then
            kept[#kept + 1] = queue[i]
        end
    end
    queue = kept
end

local function MeasureButton(button)
    local width = button.GetTextWidth and button:GetTextWidth() or 0
    if not width or width <= 0 then
        local text = button.GetFontString and button:GetFontString()
        width = text and text.GetStringWidth and text:GetStringWidth() or 0
    end
    return math.max(BUTTON_MIN_WIDTH, math.min(BUTTON_MAX_WIDTH, width + 40))
end

local function Layout()
    if not panel then
        return
    end
    local waypointWidth = MeasureButton(panel.waypointButton)
    local ignoreWidth = MeasureButton(panel.ignoreButton)
    local abandonWidth = MeasureButton(panel.abandonButton)
    panel.waypointButton:SetWidth(waypointWidth)
    panel.ignoreButton:SetWidth(ignoreWidth)
    panel.abandonButton:SetWidth(abandonWidth)

    local width = math.max(MIN_FRAME_WIDTH, waypointWidth + BUTTON_GAP + ignoreWidth + PADDING * 2)
    panel:SetWidth(width)
    panel.body:SetWidth(width - PADDING * 2)
    panel.zone:SetWidth(width - PADDING * 2)
    panel.status:SetWidth(width - PADDING * 2)

    local y = -24
    panel.title:ClearAllPoints()
    panel.title:SetPoint("TOPLEFT", PADDING, y)
    y = y - (panel.title:GetStringHeight() or 16) - 14
    panel.body:ClearAllPoints()
    panel.body:SetPoint("TOPLEFT", PADDING, y)
    y = y - (panel.body:GetStringHeight() or 32)
    if panel.zone:IsShown() then
        y = y - 6
        panel.zone:ClearAllPoints()
        panel.zone:SetPoint("TOPLEFT", PADDING, y)
        y = y - (panel.zone:GetStringHeight() or 12)
    end
    y = y - 8
    panel.status:ClearAllPoints()
    panel.status:SetPoint("TOPLEFT", PADDING, y)
    y = y - math.max(14, panel.status:GetStringHeight() or 0)

    local dividerY = y - 14
    panel.divider:ClearAllPoints()
    panel.divider:SetPoint("TOPLEFT", PADDING, dividerY)
    panel.divider:SetPoint("TOPRIGHT", -PADDING, dividerY)

    local abandonTop = dividerY - 12
    panel.abandonButton:ClearAllPoints()
    panel.abandonButton:SetPoint("TOPLEFT", PADDING, abandonTop)
    local bottomTop = abandonTop - BUTTON_HEIGHT - 10
    panel.ignoreButton:ClearAllPoints()
    panel.ignoreButton:SetPoint("TOPRIGHT", -(PADDING + waypointWidth + BUTTON_GAP), bottomTop)
    panel.waypointButton:ClearAllPoints()
    panel.waypointButton:SetPoint("TOPRIGHT", -PADDING, bottomTop)

    panel:SetHeight(math.max(MIN_FRAME_HEIGHT, -bottomTop + BUTTON_HEIGHT + 24))
end

local function SetStatus(message)
    if not panel then
        return
    end
    panel.status:SetText(message or "")
    Layout()
end

local function UpdateActions(entry)
    if not panel then
        return
    end
    if entry.preview then
        local reason = L["Preview only. Accept a quest that skips its breadcrumb to use this action."]
        panel.waypointButton.disabledReason = reason
        panel.waypointButton:SetEnabled(false)
        panel.abandonButton.disabledReason = reason
        panel.abandonButton:SetEnabled(false)
        return
    end
    local data = entry.data or (ns.Quests and ns.Quests[entry.breadcrumb])
    local canTrack, trackMessage = ns.CanTrackQuest(entry.breadcrumb, data)
    if canTrack then
        panel.waypointButton.disabledReason = nil
    else
        panel.waypointButton.disabledReason = trackMessage or L["No waypoint is available for this quest."]
    end
    panel.waypointButton:SetEnabled(canTrack and true or false)

    local onQuest = ns.IsOnQuest(entry.followUp)
    local abandonReason
    if not onQuest then
        abandonReason = L["This quest is no longer in your log."]
    elseif ns.IsQuestReadyForTurnIn(entry.followUp) then
        abandonReason = L["This quest is ready to turn in. Abandon it from the quest log instead."]
    end
    panel.abandonButton.disabledReason = abandonReason
    panel.abandonButton:SetEnabled((onQuest and abandonReason == nil) and true or false)
end

local function RenderNotice(entry)
    local breadcrumbData = entry.data or (ns.Quests and ns.Quests[entry.breadcrumb])
    local followUpTitle = QuestTitle(entry.followUp, ns.Quests and ns.Quests[entry.followUp])
    local breadcrumbTitle = QuestTitle(entry.breadcrumb, breadcrumbData)
    panel.body:SetText((L["You accepted %s without completing its breadcrumb quest %s."]):format(
        Gold(followUpTitle),
        Gold(breadcrumbTitle)
    ))

    local mapID = breadcrumbData and breadcrumbData.mapID
    local mapInfo = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if mapInfo and type(mapInfo.name) == "string" and mapInfo.name ~= "" then
        panel.zone:SetText((L["The breadcrumb starts in %s."]):format(mapInfo.name))
        panel.zone:Show()
    else
        panel.zone:SetText("")
        panel.zone:Hide()
    end

    panel.status:SetText("")
    UpdateActions(entry)
    Layout()
end

local function EnsurePanel()
    if panel then
        return panel
    end
    panel = CreateFrame("Frame", "ForeverQuestPinsBreadcrumb", UIParent, "BackdropTemplate")
    panel:SetSize(MIN_FRAME_WIDTH, MIN_FRAME_HEIGHT)
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

    panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetText(L["Breadcrumb Quest Skipped"])

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() Dismiss(true) end)

    panel.body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.body:SetJustifyH("LEFT")
    panel.body:SetSpacing(3)

    panel.zone = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    panel.zone:SetJustifyH("LEFT")
    panel.zone:Hide()

    panel.status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.status:SetJustifyH("LEFT")
    panel.status:SetText("")

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetHeight(1)
    panel.divider:SetColorTexture(1, 0.82, 0, 0.25)

    local function MakeButton(label, handler)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(BUTTON_MIN_WIDTH, BUTTON_HEIGHT)
        button:SetText(label)
        button:SetScript("OnClick", handler)
        if button.SetMotionScriptsWhileDisabled then
            button:SetMotionScriptsWhileDisabled(true)
        end
        button:SetScript("OnEnter", function(self)
            if not self.disabledReason or not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self:GetText() or "", 1, 0.82, 0)
            GameTooltip:AddLine(self.disabledReason, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        return button
    end

    panel.abandonButton = MakeButton(L["Abandon Quest"], function() HandleAbandon() end)
    panel.ignoreButton = MakeButton(L["Ignore"], function() Dismiss(true) end)
    panel.waypointButton = MakeButton(L["Set Waypoint"], function() HandleWaypoint() end)

    panel:SetScript("OnShow", Layout)
    panel:SetScript("OnHide", function()
        if visible and not dismissing then
            Dismiss(true)
        end
    end)

    if UISpecialFrames and type(UISpecialFrames) == "table" then
        local name = "ForeverQuestPinsBreadcrumb"
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
    return panel
end

ShowNext = function()
    if visible then
        return
    end
    local enabled = ns.GetOption("warnSkippedBreadcrumb")
    while #queue > 0 do
        local entry = table.remove(queue, 1)
        if entry.preview or enabled then
            if entry.preview or not suppressed[entry.followUp] then
                visible = entry
                EnsurePanel()
                RenderNotice(entry)
                panel:Show()
                if panel.Raise then
                    panel:Raise()
                end
                return
            end
        end
    end
end

Dismiss = function(asIgnore)
    if dismissing then
        return
    end
    local entry = visible
    if not entry then
        ShowNext()
        return
    end
    dismissing = true
    visible = nil
    if asIgnore and not entry.preview then
        suppressed[entry.followUp] = true
        DropFollowUp(entry.followUp)
    end
    if panel then
        panel:Hide()
    end
    dismissing = false
    ShowNext()
end

local function Enqueue(entry)
    if not entry.preview and not ns.GetOption("warnSkippedBreadcrumb") then
        return
    end
    if not entry.preview and suppressed[entry.followUp] then
        return
    end
    if visible and visible.breadcrumb == entry.breadcrumb then
        if not visible.preview or entry.preview then
            return
        end
        visible = entry
        RenderNotice(entry)
        return
    end
    for i = 1, #queue do
        if queue[i].breadcrumb == entry.breadcrumb then
            if not queue[i].preview or entry.preview then
                return
            end
            queue[i] = entry
            return
        end
    end
    if #queue >= MAX_QUEUE then
        if ns.GetOption("debug") then
            Report((L["Skipped breadcrumb notice for %s: the dialog queue is full."]):format(
                QuestTitle(entry.followUp)
            ))
        end
        return
    end
    queue[#queue + 1] = entry
    ShowNext()
end

function ns.Breadcrumbs.HandleAccepted(questID)
    if not questID or not ns.GetOption("warnSkippedBreadcrumb") then
        return
    end
    if suppressed[questID] then
        return
    end
    local candidates = ns.Breadcrumbs.CollectCandidates(questID)
    if ns.GetOption("debug") then
        Report((L["Quest %d skipped breadcrumbs: %s"]):format(
            questID,
            #candidates > 0 and table.concat(candidates, ", ") or L["none"]
        ))
    end
    if #candidates == 0 then
        return
    end
    local breadcrumbID, data = BestCandidate(candidates)
    Enqueue({ followUp = questID, breadcrumb = breadcrumbID, data = data })
end

local function BreadcrumbMatches(entryBreadcrumb, questID)
    if entryBreadcrumb == questID then
        return true
    end
    local data = ns.Quests and ns.Quests[entryBreadcrumb]
    local alts = data and data.altQuests
    if alts then
        for i = 1, #alts do
            if alts[i] == questID then
                return true
            end
        end
    end
    return false
end

local function ClearBreadcrumb(questID)
    local kept = {}
    for i = 1, #queue do
        if not BreadcrumbMatches(queue[i].breadcrumb, questID) then
            kept[#kept + 1] = queue[i]
        end
    end
    queue = kept
    if visible and BreadcrumbMatches(visible.breadcrumb, questID) then
        Dismiss(false)
    end
end

function ns.Breadcrumbs.OnQuestAccepted(questID)
    if not questID then
        return
    end
    -- Picking up the named breadcrumb satisfies the warning even when the
    -- dialog or a queued notice is still open.
    ClearBreadcrumb(questID)
    if not ns.GetOption("warnSkippedBreadcrumb") then
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            ns.Breadcrumbs.HandleAccepted(questID)
        end)
    else
        ns.Breadcrumbs.HandleAccepted(questID)
    end
end

function ns.Breadcrumbs.OnQuestEnded(questID)
    if not questID then
        return
    end
    local kept = {}
    for i = 1, #queue do
        local entry = queue[i]
        if entry.followUp ~= questID and not BreadcrumbMatches(entry.breadcrumb, questID) then
            kept[#kept + 1] = entry
        end
    end
    queue = kept
    if visible and (visible.followUp == questID or BreadcrumbMatches(visible.breadcrumb, questID)) then
        Dismiss(false)
    end
end

function ns.Breadcrumbs.ShowPreview()
    local breadcrumbID = 4736
    local data = ns.Quests and ns.Quests[breadcrumbID]
    if not data then
        data = { mapID = 1455, title = "In Search of Menara Voidrender" }
    end
    Enqueue({
        followUp = 1796,
        breadcrumb = breadcrumbID,
        data = data,
        preview = true,
    })
end

local function ClientQuestInLog(questID)
    if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questID)
        if ok and onQuest ~= nil then
            return onQuest and true or false
        end
    end
    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and index ~= nil then
            return index > 0
        end
    end
    if type(GetQuestLogIndexByID) == "function" then
        local ok, index = pcall(GetQuestLogIndexByID, questID)
        if ok and index ~= nil then
            return index > 0
        end
    end
    return nil
end

local function TryAbandonOnce(questID)
    if C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function"
        and type(C_QuestLog.SetAbandonQuest) == "function"
        and type(C_QuestLog.AbandonQuest) == "function" then
        local ok = pcall(function()
            C_QuestLog.SetSelectedQuest(questID)
            C_QuestLog.SetAbandonQuest()
            C_QuestLog.AbandonQuest()
        end)
        if ok then
            return true
        end
    end
    if type(SelectQuestLogEntry) == "function" and type(AbandonQuest) == "function" then
        local index
        if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local ok, value = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
            if ok then index = value end
        elseif type(GetQuestLogIndexByID) == "function" then
            local ok, value = pcall(GetQuestLogIndexByID, questID)
            if ok then index = value end
        end
        if index and index > 0 then
            local ok = pcall(function()
                SelectQuestLogEntry(index)
                if type(SetAbandonQuest) == "function" then
                    SetAbandonQuest()
                end
                AbandonQuest()
            end)
            if ok then
                return true
            end
        end
    end
    return false
end

--- Abandons one quest and verifies with the client quest log.
-- The session log overrides in Eligibility.lua report a fresh accept before the
-- client updates, so this check reads the client API directly.
function ns.Breadcrumbs.AbandonQuest(questID)
    if not TryAbandonOnce(questID) then
        return false
    end
    local inLog = ClientQuestInLog(questID)
    -- A client without any quest-log query still reports an abandon error when
    -- it fails, so a clean call is the only available evidence there.
    return inLog ~= true
end

HandleWaypoint = function()
    local entry = visible
    if not entry or entry.preview then
        return
    end
    local data = entry.data or (ns.Quests and ns.Quests[entry.breadcrumb])
    local ok, message = ns.TrackQuest(entry.breadcrumb, data, true)
    if not ok then
        if visible == entry then
            SetStatus(message or L["Could not create a waypoint for this quest."])
        end
        return
    end
    if visible == entry then
        Dismiss(false)
    end
end

HandleAbandon = function()
    local entry = visible
    if not entry or entry.preview then
        return
    end
    if not ns.IsOnQuest(entry.followUp) then
        SetStatus(L["This quest is no longer in your log."])
        UpdateActions(entry)
        return
    end
    if ns.IsQuestReadyForTurnIn(entry.followUp) then
        SetStatus(L["This quest is ready to turn in. Abandon it from the quest log instead."])
        UpdateActions(entry)
        return
    end
    panel.abandonButton:SetEnabled(false)

    local function Finish()
        DropFollowUp(entry.followUp)
        local title = QuestTitle(entry.followUp, ns.Quests and ns.Quests[entry.followUp])
        if visible == entry then
            Dismiss(false)
        end
        Report((L["Abandoned %s."]):format(title))
    end

    local ok = ns.Breadcrumbs.AbandonQuest(entry.followUp)
    if ok then
        Finish()
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if visible ~= entry then
                -- QUEST_REMOVED may already have closed the notice after a
                -- successful abandon the client did not report in time.
                if ClientQuestInLog(entry.followUp) == false then
                    Report((L["Abandoned %s."]):format(
                        QuestTitle(entry.followUp, ns.Quests and ns.Quests[entry.followUp])
                    ))
                end
                return
            end
            if ns.Breadcrumbs.AbandonQuest(entry.followUp) then
                Finish()
            else
                SetStatus(L["Could not abandon this quest."])
                UpdateActions(entry)
            end
        end)
        return
    end
    SetStatus(L["Could not abandon this quest."])
    UpdateActions(entry)
end
