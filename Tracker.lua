local _, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Our own quest module inside Blizzard's ObjectiveTrackerFrame. It uses
-- Blizzard's quest block, item button, POI button, animation, and Edit Mode
-- code, then adds zone headers and a scroll viewport. Blizzard's tracker and
-- gamepad methods are never replaced.

local SORT_ORDER = ns.TrackerSortOrder or { "blizzard", "distance", "level", "title" }
local FILTER_ORDER = ns.TrackerFilterOrder or { "all", "current", "instance", "completed" }
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
    completed = L["Completed quests only"],
}

local MODULE_NAME = "FQPQuestObjectiveTracker"
local SCROLL_STEP = 36
local CONTENT_BOTTOM_PADDING = 8
local DEFAULT_BOTTOM_INSET = 15
local SCROLL_LEFT_INSET = 0

local function BottomViewportInset()
    local value = tonumber(ns.GetOption("trackerBottomInset"))
    if not value or value ~= value then
        return DEFAULT_BOTTOM_INSET
    end
    return math.max(0, math.min(60, value))
end

local trackerMixin
local module
local registered = false
local active = false
local pendingApply = false
local ticker
local nearestTicker
local tickerToken = 0
local nearestTickerToken = 0
local lastSignature
local gamepadRegistered = false
local eventFrame
local registerRetries = 0
local blizzardEventsSuspended = false
local moduleEventsSuspended = false

local function InCombat()
    if InCombatLockdown then
        local ok, value = pcall(InCombatLockdown)
        if ok then
            return value and true or false
        end
    end
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

local function GamepadUIEnabled()
    return InputUtil
        and type(InputUtil.IsGamepadUIEnabled) == "function"
        and InputUtil.IsGamepadUIEnabled() == true
end

local function Restricted()
    if ns.AddOnActionsRestricted then
        return ns.AddOnActionsRestricted()
    end
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
            local ok, isActive = pcall(restricted.IsAddOnRestrictionActive, kind)
            if ok and isActive then
                return true
            end
        end
    end
    return false
end

local function TemplateExists(name)
    if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function" then
        return false
    end
    local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
    return ok and info ~= nil
end

local function CanUseQuestTracker()
    return ObjectiveTrackerFrame ~= nil
        and QuestObjectiveTracker ~= nil
        and type(QuestObjectiveTrackerMixin) == "table"
        and type(ObjectiveTrackerModuleMixin) == "table"
        and type(ObjectiveTrackerManager) == "table"
        and type(ObjectiveTrackerManager.SetModuleContainer) == "function"
        and type(ObjectiveTrackerManager.GetContainerForModule) == "function"
        and type(ObjectiveTrackerFrame.AddModule) == "function"
        and type(ObjectiveTrackerFrame.RemoveModule) == "function"
        and type(CreateFromMixins) == "function"
        and type(Mixin) == "function"
        and TemplateExists("ObjectiveTrackerModuleTemplate")
        and TemplateExists("ObjectiveTrackerBlockTemplate")
        and TemplateExists("ObjectiveTrackerModuleMinimizeButtonTemplate")
        and TemplateExists("ObjectiveTrackerQuestPOIBlockTemplate")
        and TemplateExists("QuestObjectiveItemButtonTemplate")
        and TemplateExists("QuestObjectiveFindGroupButtonTemplate")
        and TemplateExists("ObjectiveTrackerPOIButtonTemplate")
        and TemplateExists("AutoQuestPopUpBlockTemplate")
        and type(C_QuestLog) == "table"
        and type(C_QuestLog.GetNumQuestWatches) == "function"
        and type(C_QuestLog.GetQuestIDForQuestWatchIndex) == "function"
        and type(QuestCache) == "table"
        and QuestObjectiveTracker.uiOrder ~= nil
        and ObjectiveTrackerManager:GetContainerForModule(QuestObjectiveTracker) == ObjectiveTrackerFrame
end

local function ResetTrackerScroll()
    if module and module.ScrollFrame and module.ScrollFrame.SetVerticalScroll then
        module.ScrollFrame:SetVerticalScroll(0)
    end
end

local function TrackerShown()
    local frame = ObjectiveTrackerFrame
    local tracker = active and module
    if not frame or not tracker then
        return false
    end
    if frame.IsShown and not frame:IsShown() then
        return false
    end
    if frame.IsCollapsed and frame:IsCollapsed() then
        return false
    end
    if tracker.IsCollapsed and tracker:IsCollapsed() then
        return false
    end
    if tracker.HasContents and not tracker:HasContents() then
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

local function StopNearestTicker()
    nearestTickerToken = nearestTickerToken + 1
    if nearestTicker and nearestTicker.Cancel then
        nearestTicker:Cancel()
    end
    nearestTicker = nil
end

local OnTicker
local OnNearestTick

local function StartDistanceTicker()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        return C_Timer.NewTicker(5, OnTicker)
    end
    if C_Timer and type(C_Timer.After) == "function" then
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
        return {}
    end
    return nil
end

local function StartNearestTicker()
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        return C_Timer.NewTicker(5, OnNearestTick)
    end
    if C_Timer and type(C_Timer.After) == "function" then
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
        return {}
    end
    return nil
end

function ns.TrackerOrderSignature()
    local tracker = active and module
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

function OnTicker()
    if InCombat() then
        StopTicker()
        return
    end
    if not TrackerShown() then
        return
    end
    local signature = ns.TrackerOrderSignature()
    if signature and signature ~= lastSignature then
        lastSignature = signature
        if module and module.MarkDirty then
            module:MarkDirty()
        end
    end
end

function ns.UpdateTrackerTicker()
    local wants = registered
        and active
        and ns.GetOption("enhanceQuestTracker")
        and ns.GetOption("trackerSort") == "distance"
        and not GamepadUIEnabled()
        and not InCombat()
        and C_QuestLog
        and type(C_QuestLog.GetDistanceSqToQuest) == "function"
    if not wants then
        StopTicker()
        return
    end
    if ticker then
        return
    end
    lastSignature = ns.TrackerOrderSignature()
    ticker = StartDistanceTicker()
end

function ns.SelectNearestQuest()
    if GamepadUIEnabled() or Restricted() then
        return false
    end
    local tracker = (active and module) or QuestObjectiveTracker
    if not tracker or type(QuestObjectiveTrackerMixin) ~= "table"
        or type(QuestObjectiveTrackerMixin.BuildQuestWatchInfos) ~= "function" then
        return false
    end
    if not C_SuperTrack or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function" then
        return false
    end
    -- The beta module applies the active tracker filter. With the beta off,
    -- nearest selection still uses every watched quest.
    local builder = QuestObjectiveTrackerMixin.BuildQuestWatchInfos
    if active and module and type(module.BuildQuestWatchInfos) == "function" then
        builder = module.BuildQuestWatchInfos
        tracker = module
    end
    local ok, infos = pcall(builder, tracker)
    if not ok or type(infos) ~= "table" then
        return false
    end
    local bestID, bestDistance
    for i = 1, #infos do
        local quest = infos[i].quest
        local questID = quest and quest.GetID and quest:GetID()
        if type(questID) == "number" then
            local distance, onContinent
            if C_QuestLog and type(C_QuestLog.GetDistanceSqToQuest) == "function" then
                local okDistance, value, continent = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
                if okDistance then
                    distance, onContinent = value, continent
                end
            end
            if type(distance) == "number" and distance == distance and onContinent ~= false then
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

function OnNearestTick()
    if not ns.GetOption("selectNearestQuest") or Restricted() then
        StopNearestTicker()
        return
    end
    ns.SelectNearestQuest()
end

function ns.UpdateNearestQuestTicker()
    local wants = registered
        and ns.GetOption("selectNearestQuest")
        and not GamepadUIEnabled()
        and not Restricted()
        and C_SuperTrack
        and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
    if not wants then
        StopNearestTicker()
        return
    end
    if nearestTicker then
        return
    end
    nearestTicker = StartNearestTicker()
end

local function UpdateCollapseButton(block)
    local button = block.zoneCollapseButton
    if not button then
        return
    end
    if GamepadUIEnabled() then
        button:Hide()
        return
    end
    button:Show()
    local collapsed = ns.IsZoneCollapsed(block.zoneName)
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

function ns.OpenTrackerMenu(owner)
    if GamepadUIEnabled() or not MenuUtil or type(MenuUtil.CreateContextMenu) ~= "function" then
        return false
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetTag("FOREVER_QUEST_PINS_TRACKER")
        root:CreateTitle(L["Quest tracker"] .. " (BETA)")
        if type(MenuUtil.CreateCheckbox) == "function" then
            root:Insert(MenuUtil.CreateCheckbox(
                L["Enhance quest tracker"] .. " (BETA)",
                function() return ns.GetOption("enhanceQuestTracker") end,
                function()
                    ns.SetOption("enhanceQuestTracker", not ns.GetOption("enhanceQuestTracker"))
                end
            ))
            root:Insert(MenuUtil.CreateCheckbox(
                L["Select nearest quest"],
                function() return ns.GetOption("selectNearestQuest") end,
                function()
                    ns.SetOption("selectNearestQuest", not ns.GetOption("selectNearestQuest"))
                end
            ))
        else
            root:CreateCheckbox(
                L["Enhance quest tracker"] .. " (BETA)",
                function() return ns.GetOption("enhanceQuestTracker") end,
                function()
                    ns.SetOption("enhanceQuestTracker", not ns.GetOption("enhanceQuestTracker"))
                end
            )
            root:CreateCheckbox(
                L["Select nearest quest"],
                function() return ns.GetOption("selectNearestQuest") end,
                function()
                    ns.SetOption("selectNearestQuest", not ns.GetOption("selectNearestQuest"))
                end
            )
        end
        if ns.GetOption("enhanceQuestTracker") and not GamepadUIEnabled() then
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
        end
    end)
    return true
end

function ns.MarkTrackerDirty(resetScroll)
    if resetScroll then
        ResetTrackerScroll()
    end
    if active and module and module.MarkDirty then
        module:MarkDirty()
    end
end

function ns.PrintTrackerDebug()
    local function p(message)
        print("|cffffd100Forever Quest Pins:|r " .. tostring(message))
    end
    p(("beta=%s registered=%s active=%s module=%s"):format(
        tostring(ns.GetOption("enhanceQuestTracker")),
        tostring(registered),
        tostring(active),
        tostring(module ~= nil)))
    p(("filter=%s sort=%s nearest=%s"):format(
        tostring(ns.GetOption("trackerFilter")),
        tostring(ns.GetOption("trackerSort")),
        tostring(ns.GetOption("selectNearestQuest"))))
    if not module then
        return
    end
    local frame = ObjectiveTrackerFrame
    if frame then
        local inModules = frame.HasModule and frame:HasModule(module) or false
        local defaultPosition = frame.IsInDefaultPosition and frame:IsInDefaultPosition() or "?"
        p(("frame shown=%s collapsed=%s height=%s default=%s editHeight=%s top=%s bottom=%s; module inModules=%s shown=%s collapsed=%s hasContents=%s contentsHeight=%s availableHeight=%s"):format(
            tostring(frame:IsShown()),
            tostring(frame.IsCollapsed and frame:IsCollapsed()),
            tostring(frame:GetHeight()),
            tostring(defaultPosition),
            tostring(frame.editModeHeight),
            tostring(frame:GetTop()),
            tostring(frame:GetBottom()),
            tostring(inModules),
            tostring(module:IsShown()),
            tostring(module.IsCollapsed and module:IsCollapsed()),
            tostring(module:HasContents()),
            tostring(module.contentsHeight),
            tostring(module.availableHeight)))
    end
    local scroll = module.ScrollFrame
    if scroll then
        p(("scroll shown=%s width=%s height=%s range=%s offset=%s top=%s bottom=%s; content shown=%s width=%s height=%s; screen=%s"):format(
            tostring(scroll:IsShown()),
            tostring(scroll:GetWidth()),
            tostring(scroll:GetHeight()),
            tostring(scroll:GetVerticalScrollRange()),
            tostring(scroll:GetVerticalScroll()),
            tostring(scroll:GetTop()),
            tostring(scroll:GetBottom()),
            tostring(module.ContentsFrame:IsShown()),
            tostring(module.ContentsFrame:GetWidth()),
            tostring(module.ContentsFrame:GetHeight()),
            tostring(UIParent and UIParent:GetHeight())))
    end
    local watched = C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetNumQuestWatches() or "?"
    local ok, infos = pcall(module.BuildQuestWatchInfos, module)
    if not ok or type(infos) ~= "table" then
        p("BuildQuestWatchInfos failed: " .. tostring(infos))
        return
    end
    p(("watched=%s entries=%s"):format(tostring(watched), tostring(#infos)))
    for i = 1, math.min(#infos, 5) do
        local entry = infos[i]
        p(("  %s zone=%s title=%s complete=%s"):format(
            tostring(entry.questID),
            tostring(entry.zoneName),
            tostring(entry.title),
            tostring(entry.isComplete)))
    end
end

local function HookTrackerMenu(header)
    if not header or header.fqpMenuHooked then
        return
    end
    header.fqpMenuHooked = true
    header:EnableMouse(true)
    header:HookScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.OpenTrackerMenu(header)
        end
    end)
end

function ns.NotifyTrackerOptionsChanged(key)
    if key == "trackerSort" or key == "trackerFilter" then
        ResetTrackerScroll()
    end
    ns.ApplyTrackerState()
    ns.UpdateTrackerTicker()
    ns.UpdateNearestQuestTicker()
    if active and module then
        module:MarkDirty()
    end
end

local function AddZoneHeader(self, zone)
    local block = self:GetBlock("zone:" .. zone, "ObjectiveTrackerBlockTemplate")
    if type(block) ~= "table" then
        return false
    end
    block.zoneName = zone
    block.smartNavigationIgnored = true
    block.offsetX = 7
    self:AnchorBlock(block)
    block.rightEdgeOffset = -20
    if ObjectiveTrackerHeaderFont and block.HeaderText and block.HeaderText.SetFontObject then
        block.HeaderText:SetFontObject(ObjectiveTrackerHeaderFont)
    end
    if block.HeaderButton then
        block.HeaderButton.smartNavigationIgnored = true
        block.HeaderButton:EnableMouse(true)
        block.HeaderButton:Show()
    end
    block:EnableMouse(true)
    block:SetScript("OnMouseUp", function(clicked, button)
        if button == "LeftButton" then
            self:ToggleZoneCollapse(clicked)
        end
    end)
    block:SetHeader(zone)
    local headerColor = OBJECTIVE_TRACKER_COLOR
        and (OBJECTIVE_TRACKER_COLOR.HeaderHighlight or OBJECTIVE_TRACKER_COLOR.Header)
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
    if not block.zoneCollapseButton then
        local ok, button = pcall(CreateFrame, "Button", nil, block, "ObjectiveTrackerModuleMinimizeButtonTemplate")
        if not ok or not button then
            button = CreateFrame("Button", nil, block)
            button:SetSize(16, 16)
            local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("CENTER")
            button.zoneLabel = label
        end
        button:SetPoint("RIGHT", block, "RIGHT", 0, 0)
        button:SetScript("OnClick", function()
            self:ToggleZoneCollapse(block)
        end)
        block.zoneCollapseButton = button
    end
    UpdateCollapseButton(block)
    return self:LayoutBlock(block)
end

local function BuildTrackerMixin()
    local mixin = CreateFromMixins(QuestObjectiveTrackerMixin)
    -- Blizzard draws the quest POI icon just left of the block text. Inside a
    -- scroll frame that overhang would be clipped, so indent quest blocks enough
    -- to keep the visible icon inside the content.
    mixin.blockOffsetX = 30

    function mixin:BuildQuestWatchInfos()
        local infos = QuestObjectiveTrackerMixin.BuildQuestWatchInfos(self)
        return ns.EnhanceQuestWatchInfos(self, infos)
    end

    function mixin:EnumQuestWatchData(func)
        local infos = self:BuildQuestWatchInfos()
        if type(infos) ~= "table" or #infos == 0 then
            local filter = ns.GetOption("trackerFilter")
            if filter and filter ~= "all" then
                self:AddFilterEmptyBlock()
            end
            return
        end
        if infos[1].zoneName == nil then
            for i = 1, #infos do
                if not func(self, infos[i].quest) then
                    return
                end
            end
            return
        end
        local currentZone
        for i = 1, #infos do
            local info = infos[i]
            local zone = info.zoneName or L["Other"]
            if zone ~= currentZone then
                currentZone = zone
                if not AddZoneHeader(self, zone) then
                    -- The client can refuse a block during a restricted state.
                    -- Keep the remaining quests visible in a flat list.
                    for j = i, #infos do
                        local remaining = infos[j]
                        local remainingZone = remaining.zoneName or L["Other"]
                        if not ns.IsZoneCollapsed(remainingZone) then
                            if not func(self, remaining.quest) then
                                return
                            end
                        end
                    end
                    return
                end
            end
            if not ns.IsZoneCollapsed(zone) then
                if not func(self, info.quest) then
                    return
                end
            end
        end
    end

    function mixin:CanFitBlock()
        return true
    end

    function mixin:AddFilterEmptyBlock()
        local block = self:GetBlock("fqp-filter-empty", "ObjectiveTrackerBlockTemplate")
        if type(block) ~= "table" then
            return
        end
        block.zoneName = nil
        block.smartNavigationIgnored = true
        block.offsetX = 7
        self:AnchorBlock(block)
        block.rightEdgeOffset = 0
        if block.HeaderText and block.HeaderText.SetPoint then
            block.HeaderText:SetPoint("RIGHT", 0, 0)
        end
        if block.zoneCollapseButton then
            block.zoneCollapseButton:Hide()
        end
        if block.HeaderButton then
            block.HeaderButton:Hide()
            block.HeaderButton:EnableMouse(false)
        end
        block:SetScript("OnMouseUp", nil)
        if ObjectiveTrackerLineFont and block.HeaderText and block.HeaderText.SetFontObject then
            block.HeaderText:SetFontObject(ObjectiveTrackerLineFont)
        end
        block.HeaderText:SetText(L["No tracked quests match this filter."])
        block.HeaderText:SetTextColor(0.6, 0.6, 0.6)
        if block.HeaderText.SetMaxLines then
            block.HeaderText:SetMaxLines(0)
        end
        block.height = math.max(block.HeaderText:GetHeight() or 0, 18)
        self:LayoutBlock(block)
    end

    -- The normal fast path skips relayout when the module is complete and its
    -- capped height fits. Edit Mode can grow the viewport without changing the
    -- content, so always re-layout when the container asks.
    function mixin:IsComplete()
        return false
    end

    function mixin:UpdateScrollContentSize()
        local scroll = self.ScrollFrame
        local content = self.ContentsFrame
        if not scroll or not content then
            return
        end
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", scroll, "TOPLEFT", SCROLL_LEFT_INSET, 0)
        local contentWidth = (scroll:GetWidth() or 0) - SCROLL_LEFT_INSET
        if contentWidth <= 1 then
            contentWidth = (self:GetWidth() or 0) - SCROLL_LEFT_INSET
        end
        if contentWidth <= 1 and self.Header then
            contentWidth = (self.Header:GetWidth() or 0) - SCROLL_LEFT_INSET
        end
        content:SetWidth(math.max(contentWidth, 1))
    end

    function mixin:UpdateScrollViewport()
        local scroll = self.ScrollFrame
        local content = self.ContentsFrame
        if not scroll or not content then
            return
        end
        self:UpdateScrollContentSize()
        local headerHeight = self.headerHeight or 0
        local fullHeight = self.contentsHeight or headerHeight
        local contentHeight = math.max(0, fullHeight - headerHeight)
        local available = self.availableHeight or 0
        local viewport = math.min(contentHeight, math.max(0, available - headerHeight - BottomViewportInset()))
        self.contentsHeight = headerHeight + viewport
        scroll:SetHeight(math.max(viewport, 1))
        scroll:SetShown(viewport > 0)
        content:SetHeight(math.max(contentHeight + CONTENT_BOTTOM_PADDING, viewport, 1))
        scroll:UpdateScrollChildRect()
        local range = scroll:GetVerticalScrollRange() or 0
        local offset = scroll:GetVerticalScroll() or 0
        if offset > range then
            scroll:SetVerticalScroll(range)
        end
    end

    function mixin:LayoutContents()
        self:UpdateScrollContentSize()
        QuestObjectiveTrackerMixin.LayoutContents(self)
        self:UpdateScrollViewport()
    end

    function mixin:Scroll(delta)
        local scroll = self.ScrollFrame
        if not scroll then
            return
        end
        local range = scroll:GetVerticalScrollRange() or 0
        if range <= 0 then
            return
        end
        local offset = scroll:GetVerticalScroll() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(range, offset - delta * SCROLL_STEP)))
    end

    function mixin:EnableBlockWheel(block)
        if not block.EnableMouseWheel then
            return
        end
        if not block.fqpWheel then
            block.fqpWheel = true
            block:EnableMouse(true)
            block:EnableMouseWheel(true)
            block:SetScript("OnMouseWheel", function(_, delta)
                self:Scroll(delta)
            end)
        end
        for _, child in ipairs({ block.HeaderButton, block.ItemButton, block.poiButton, block.zoneCollapseButton }) do
            if child and child.EnableMouseWheel and not child.fqpWheel then
                child.fqpWheel = true
                child:EnableMouseWheel(true)
                if child.HookScript then
                    child:HookScript("OnMouseWheel", function(_, delta)
                        self:Scroll(delta)
                    end)
                else
                    child:SetScript("OnMouseWheel", function(_, delta)
                        self:Scroll(delta)
                    end)
                end
            end
        end
    end

    function mixin:LayoutBlock(block)
        local placed = ObjectiveTrackerModuleMixin.LayoutBlock(self, block)
        if placed then
            self:EnableBlockWheel(block)
            if block.poiButton then
                -- The glow is wider than the scroll content. Keep the icon
                -- itself whole and use the stock indent instead of clipping it.
                block.poiButton.shouldShowGlow = false
                if block.poiButton.Glow then
                    block.poiButton.Glow:Hide()
                end
            end
        end
        return placed
    end

    function mixin:AnchorBlock(block)
        -- Auto-quest popups use a negative offset to overhang the old module.
        -- Inside the scroll child that overhang is clipped, so keep them inside.
        if block.offsetX and block.offsetX < 0 then
            block.offsetX = 0
        end
        return ObjectiveTrackerModuleMixin.AnchorBlock(self, block)
    end

    function mixin:ToggleZoneCollapse(block)
        if not block or not block.zoneName then
            return
        end
        ns.ToggleZoneCollapsed(block.zoneName)
        UpdateCollapseButton(block)
        self:MarkDirty()
    end

    function mixin:OnBlockHeaderClick(block, mouseButton)
        if block.zoneName then
            if mouseButton == "LeftButton" then
                self:ToggleZoneCollapse(block)
            end
            return
        end
        QuestObjectiveTrackerMixin.OnBlockHeaderClick(self, block, mouseButton)
    end

    function mixin:OnBlockHeaderEnter(block)
        if block.zoneName then
            GameTooltip:SetOwner(block, "ANCHOR_RIGHT")
            GameTooltip:SetText(block.zoneName, 1, 0.82, 0)
            GameTooltip:Show()
            return
        end
        QuestObjectiveTrackerMixin.OnBlockHeaderEnter(self, block)
    end

    function mixin:OnBlockHeaderLeave(block)
        if block.zoneName then
            GameTooltip:Hide()
            return
        end
        QuestObjectiveTrackerMixin.OnBlockHeaderLeave(self, block)
    end

    function mixin:SetCollapsed(collapsed)
        ObjectiveTrackerModuleMixin.SetCollapsed(self, collapsed)
        if self.ScrollFrame then
            if collapsed then
                self.ScrollFrame:Hide()
                self.ScrollFrame:SetVerticalScroll(0)
            elseif self.ScrollFrame.GetHeight and (self.ScrollFrame:GetHeight() or 0) > 1 then
                self.ScrollFrame:Show()
            end
        end
    end

    return mixin
end

local function CreateModule()
    if not CanUseQuestTracker() then
        return nil
    end
    if not trackerMixin then
        trackerMixin = BuildTrackerMixin()
    end
    if not trackerMixin then
        return nil
    end
    local ok, frame = pcall(CreateFrame, "Frame", MODULE_NAME, ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
    if not ok or not frame or not frame.Header then
        return nil
    end
    Mixin(frame, trackerMixin)
    frame:SetHeader(TRACKER_HEADER_QUESTS or "Quests")
    frame:EnableMouse(true)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, 0)
    scroll:SetPoint("TOPRIGHT", frame.Header, "BOTTOMRIGHT", 0, 0)
    scroll:SetHeight(1)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        frame:Scroll(delta)
    end)
    frame.ScrollFrame = scroll

    local content = frame.ContentsFrame
    content:ClearAllPoints()
    content:SetParent(scroll)
    scroll:SetScrollChild(content)
    content:SetPoint("TOPLEFT", scroll, "TOPLEFT", SCROLL_LEFT_INSET, 0)
    content:SetSize(1, 1)
    content:EnableMouse(true)
    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(_, delta)
        frame:Scroll(delta)
    end)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame:Scroll(delta)
    end)
    frame.Header:EnableMouse(true)
    frame.Header:EnableMouseWheel(true)
    frame.Header:HookScript("OnMouseWheel", function(_, delta)
        frame:Scroll(delta)
    end)
    HookTrackerMenu(frame.Header)
    return frame
end

local function AddTrackerModule()
    if active then
        return true
    end
    if not module then
        module = CreateModule()
    end
    if not module then
        return false
    end
    module.uiOrder = (QuestObjectiveTracker and QuestObjectiveTracker.uiOrder) or 4
    ObjectiveTrackerFrame:RemoveModule(QuestObjectiveTracker)
    if QuestObjectiveTracker.Hide then
        QuestObjectiveTracker:Hide()
    end
    if not blizzardEventsSuspended and type(QuestObjectiveTracker.events) == "table" then
        blizzardEventsSuspended = true
        for i = 1, #QuestObjectiveTracker.events do
            QuestObjectiveTracker:UnregisterEvent(QuestObjectiveTracker.events[i])
        end
    end
    ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
    if moduleEventsSuspended and type(module.events) == "table" then
        moduleEventsSuspended = false
        for i = 1, #module.events do
            module:RegisterEvent(module.events[i])
        end
    end
    if ns.HookQuestLinkModule then
        ns.HookQuestLinkModule(module)
    end
    module:MarkDirty()
    active = true
    pendingApply = false
    ns.UpdateTrackerTicker()
    ns.UpdateNearestQuestTicker()
    return true
end

local function RemoveTrackerModule()
    if not active or not module then
        return
    end
    ObjectiveTrackerFrame:RemoveModule(module)
    module:Hide()
    if not moduleEventsSuspended and type(module.events) == "table" then
        moduleEventsSuspended = true
        for i = 1, #module.events do
            module:UnregisterEvent(module.events[i])
        end
    end
    ObjectiveTrackerManager:SetModuleContainer(QuestObjectiveTracker, ObjectiveTrackerFrame)
    if blizzardEventsSuspended and type(QuestObjectiveTracker.events) == "table" then
        blizzardEventsSuspended = false
        for i = 1, #QuestObjectiveTracker.events do
            QuestObjectiveTracker:RegisterEvent(QuestObjectiveTracker.events[i])
        end
    end
    if QuestObjectiveTracker.MarkDirty then
        QuestObjectiveTracker:MarkDirty()
    end
    active = false
    pendingApply = false
    StopTicker()
    StopNearestTicker()
    ResetTrackerScroll()
end

function ns.ApplyTrackerState(forceDisable)
    local wanted = ns.GetOption("enhanceQuestTracker")
        and not GamepadUIEnabled()
        and CanUseQuestTracker()
    if wanted and not active then
        if InCombat() then
            pendingApply = true
            return false
        end
        return AddTrackerModule()
    end
    if not wanted and active then
        if InCombat() and not forceDisable then
            pendingApply = true
            return false
        end
        RemoveTrackerModule()
        return true
    end
    if wanted and active and module then
        module:MarkDirty()
    end
    pendingApply = false
    return true
end

local function RegisterGamepadCallbacks()
    if gamepadRegistered or not InputUtil
        or type(InputUtil.RegisterForInterfaceTransitions) ~= "function" then
        return
    end
    gamepadRegistered = true
    InputUtil.RegisterForInterfaceTransitions(eventFrame, nil)
    if type(InputUtil.RegisterGamepadInit) == "function" then
        InputUtil.RegisterGamepadInit(eventFrame, function()
            ns.ApplyTrackerState(true)
            if ns.SyncSettingsCheckboxes then
                ns.SyncSettingsCheckboxes()
            end
        end)
    end
    if type(InputUtil.RegisterGamepadUninit) == "function" then
        InputUtil.RegisterGamepadUninit(eventFrame, function()
            ns.ApplyTrackerState()
            ns.UpdateTrackerTicker()
            ns.UpdateNearestQuestTicker()
            if ns.SyncSettingsCheckboxes then
                ns.SyncSettingsCheckboxes()
            end
        end)
    end
end

function ns.TryRegisterQuestTracker()
    if registered then
        ns.ApplyTrackerState()
        return true
    end
    if not CanUseQuestTracker() then
        registerRetries = registerRetries + 1
        if registerRetries <= 20 and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(1, function()
                ns.TryRegisterQuestTracker()
            end)
        end
        return false
    end
    if not trackerMixin then
        trackerMixin = BuildTrackerMixin()
    end
    if not trackerMixin then
        return false
    end
    if not module then
        module = CreateModule()
    end
    if not module then
        return false
    end
    registered = true
    registerRetries = 0
    RegisterGamepadCallbacks()
    ns.ApplyTrackerState()
    ns.UpdateTrackerTicker()
    ns.UpdateNearestQuestTicker()
    return true
end

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == "Blizzard_ObjectiveTracker" then
            ns.TryRegisterQuestTracker()
        end
        return
    end
    if not registered then
        return
    end
    if event == "ZONE_CHANGED" then
        ns.OnTrackerZoneChanged(false)
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        ns.OnTrackerZoneChanged(true)
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        StopTicker()
        StopNearestTicker()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            ns.ApplyTrackerState()
        end
        ns.UpdateTrackerTicker()
        ns.UpdateNearestQuestTicker()
        if active and module then
            module:MarkDirty()
        end
    end
end)
