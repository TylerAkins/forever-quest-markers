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
-- The quest item button's normal texture is 42px on a 26px button, so it
-- overhangs the block by 8px. The scroll child clips at its own edge, so keep
-- that much room above and right of the content for the overhang.
local CONTENT_TOP_PADDING = 8
local CONTENT_RIGHT_PADDING = 8
local DEFAULT_BOTTOM_INSET = 15
local SCROLL_LEFT_INSET = 0
-- Keep tracked professions at the bottom of the tracker without letting them
-- take more than half of the viewport from the quest list.
local PROFESSIONS_MAX_SHARE = 0.5

local function BottomViewportInset()
    local value = tonumber(ns.GetOption("trackerBottomInset"))
    if not value or value ~= value then
        return DEFAULT_BOTTOM_INSET
    end
    return math.max(0, math.min(60, value))
end

local function ModuleSpacing()
    local value = ObjectiveTrackerFrame and ObjectiveTrackerFrame.moduleSpacing
    if type(value) ~= "number" then
        return 10
    end
    return math.max(0, value)
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
local standaloneFrame

local function CopyFrameLayout(target, source)
    if not source then
        return
    end
    local point, relativeTo, relativePoint, x, y
    if source.GetPoint then
        point, relativeTo, relativePoint, x, y = source:GetPoint(1)
    end
    if point then
        target:ClearAllPoints()
        target:SetPoint(point, relativeTo or UIParent, relativePoint or point, x or 0, y or 0)
    else
        target:ClearAllPoints()
        target:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    end
    local sourceHeight = source.editModeHeight
    if not sourceHeight and source.GetHeight then
        sourceHeight = source:GetHeight()
    end
    local sourceWidth = source.GetWidth and source:GetWidth() or 0
    target:SetSize(math.max(sourceWidth or 0, 200), math.max(sourceHeight or 0, 300))
    if source.GetScale and target.SetScale then
        target:SetScale(source:GetScale())
    end
    if source.GetAlpha and target.SetAlpha then
        target:SetAlpha(source:GetAlpha())
    end
    if source.GetFrameStrata and target.SetFrameStrata then
        target:SetFrameStrata(source:GetFrameStrata())
    end
    if source.GetFrameLevel and target.SetFrameLevel then
        target:SetFrameLevel((source:GetFrameLevel() or 0) + 1)
    end
    if source.GetClampedToScreen and target.SetClampedToScreen then
        target:SetClampedToScreen(source:GetClampedToScreen())
    end
    target:SetMovable(true)
    target:SetResizable(true)
    target:SetUserPlaced(true)
    target:SetDontSavePosition(false)
end

-- The standalone frame is not part of Edit Mode. Read the tracker's current
-- viewport height so the height slider still controls how much it shows.
local function SourceTrackerHeight()
    local source = ObjectiveTrackerFrame
    if not source then
        return nil
    end
    local height = source.GetHeight and source:GetHeight()
    local editHeight = source.editModeHeight
    if type(editHeight) == "number" and editHeight > 0
        and (type(height) ~= "number" or editHeight > height) then
        height = editHeight
    end
    if type(height) == "number" and height > 0 then
        return height
    end
    return nil
end

local function CreateStandaloneContainer()
    if standaloneFrame then
        return standaloneFrame
    end
    local frame = CreateFrame("Frame", "FQPStandaloneTracker", UIParent)
    CopyFrameLayout(frame, ObjectiveTrackerFrame)
    frame.module = nil
    frame.professionsModule = nil
    frame.dirty = false
    -- The frame fills the source tracker's height. The modules scroll inside
    -- it, using the same height as its viewport.
    frame.availableHeight = frame:GetHeight()
    local sourceHeight = SourceTrackerHeight()

    function frame:MarkDirty()
        if self.dirty then
            return
        end
        self.dirty = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if self.dirty then
                    self:Update()
                end
            end)
        else
            self:Update()
        end
    end

    function frame:GetAvailableHeight()
        return SourceTrackerHeight() or self.availableHeight or self:GetHeight()
    end

    function frame:IsCollapsed()
        return false
    end

    function frame:SetCollapsed()
    end

    function frame:ToggleCollapsed()
    end

    function frame:ForceExpand()
        self:MarkDirty()
    end

    function frame:OnAdded()
        self:MarkDirty()
    end

    function frame:Init()
    end

    function frame:AddModule(module)
        self.module = module
        module:SetContainer(self)
        self:MarkDirty()
    end

    function frame:SetProfessionsModule(professions)
        self.professionsModule = professions
        if professions and professions.SetContainer then
            professions:SetContainer(self)
        end
        self:MarkDirty()
    end

    function frame:ClearProfessionsModule()
        self.professionsModule = nil
        self:MarkDirty()
    end

    function frame:RemoveModule(module)
        if self.module == module then
            self.module = nil
        elseif self.professionsModule == module then
            self.professionsModule = nil
        end
        self:MarkDirty()
    end

    function frame:HasAnyModule()
        return self.module ~= nil or self.professionsModule ~= nil
    end

    function frame:HasAnyModules()
        return self.module ~= nil or self.professionsModule ~= nil
    end

    function frame:ForEachModule(fn)
        if self.module then
            fn(self.module)
        end
        if self.professionsModule then
            fn(self.professionsModule)
        end
    end

    function frame:SetBackgroundAlpha(alpha)
    end

    function frame:Update()
        self.dirty = false
        local quest = self.module
        local professions = self.professionsModule
        if not quest and not professions then
            self:Hide()
            return
        end

        local width = self:GetWidth()
        local available = self:GetAvailableHeight()
        local bottomInset = BottomViewportInset()
        local spacing = ModuleSpacing()
        local contentHeight = math.max(0, available - bottomInset)
        local professionsHeight = 0

        if professions then
            professions:SetWidth(width)
            if professions.Header and professions.Header.SetWidth and width > 1 then
                professions.Header:SetWidth(width)
            end
            local maxProfessions = contentHeight
            if quest then
                local questHeaderHeight = quest.headerHeight or 0
                maxProfessions = math.min(
                    math.max(0, contentHeight - questHeaderHeight - spacing),
                    math.floor(contentHeight * PROFESSIONS_MAX_SHARE))
            end
            professions:Update(maxProfessions, true)
            if professions:IsShown() then
                professionsHeight = professions:GetHeight() or 0
            end
        end

        if quest then
            quest:SetWidth(width)
            if professionsHeight > 0 then
                quest.bottomInset = 0
                quest:Update(math.max(0, contentHeight - professionsHeight - spacing), true)
            else
                quest.bottomInset = nil
                quest:Update(available, true)
            end
        end

        if professions and professions:IsShown() then
            professions:ClearAllPoints()
            if quest and quest:IsShown() then
                professions:SetPoint("TOPLEFT", quest, "BOTTOMLEFT", 0, -spacing)
                professions:SetPoint("TOPRIGHT", quest, "BOTTOMRIGHT", 0, -spacing)
            else
                professions:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
                professions:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
            end
        end

        self:SetHeight(available)
        self:SetShown((quest and quest:IsShown()) or (professions and professions:IsShown()) or false)
    end

    -- Edit Mode changes the source frame's height without an event our tracker
    -- listens to. Poll it cheaply and relayout when it changes.
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.heightCheck = (self.heightCheck or 0) + elapsed
        if self.heightCheck < 0.25 then
            return
        end
        self.heightCheck = 0
        local height = SourceTrackerHeight()
        if height and height ~= sourceHeight then
            sourceHeight = height
            self:MarkDirty()
        end
    end)

    standaloneFrame = frame
    return frame
end

local function ProfessionsModule()
    local tracker = _G.ProfessionsRecipeTracker
    if type(tracker) ~= "table" then
        return nil
    end
    return tracker
end

local function MoveProfessionsModule(container)
    local professions = ProfessionsModule()
    if not professions or not container then
        return false
    end
    local current = ObjectiveTrackerManager
        and ObjectiveTrackerManager.GetContainerForModule
        and ObjectiveTrackerManager:GetContainerForModule(professions)
    if current == container then
        return true
    end
    if not ObjectiveTrackerFrame or type(ObjectiveTrackerFrame.RemoveModule) ~= "function" then
        return false
    end
    if current ~= ObjectiveTrackerFrame
        and not (ObjectiveTrackerFrame.HasModule
            and ObjectiveTrackerFrame:HasModule(professions)) then
        return false
    end
    ObjectiveTrackerFrame:RemoveModule(professions)
    if ObjectiveTrackerManager and ObjectiveTrackerManager.moduleToContainerMap then
        ObjectiveTrackerManager.moduleToContainerMap[professions] = container
    end
    container:SetProfessionsModule(professions)
    return true
end

local function RestoreProfessionsModule()
    local container = standaloneFrame
    local professions = container and container.professionsModule
    if not professions then
        return false
    end
    container:ClearProfessionsModule()
    if ObjectiveTrackerManager and ObjectiveTrackerManager.moduleToContainerMap then
        ObjectiveTrackerManager.moduleToContainerMap[professions] = ObjectiveTrackerFrame
    end
    if ObjectiveTrackerFrame and type(ObjectiveTrackerFrame.AddModule) == "function" then
        ObjectiveTrackerFrame:AddModule(professions)
    end
    return true
end

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
    p(("quest click=%s"):format(ns.trackerClickSecured or "blizzard handler"))
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
    local moduleEvents = module.events
    if type(moduleEvents) == "table" and #moduleEvents > 0 then
        local parts = {}
        for i = 1, #moduleEvents do
            local event = moduleEvents[i]
            local isRegistered = module.IsEventRegistered and module:IsEventRegistered(event) or "?"
            parts[#parts + 1] = event .. "=" .. tostring(isRegistered)
        end
        p("events: " .. table.concat(parts, ", "))
    else
        p("events: none")
    end
    if ns.SpokenBridgeStatus then
        local status = ns.SpokenBridgeStatus()
        p(("spoken=%s voiceover=%s spokenUI=%s bridgeModule=%s bridgeHooked=%s bridgeButtons=%s bridgeShown=%s"):format(
            tostring(status.spoken),
            tostring(status.voiceOver),
            tostring(status.ui),
            tostring(status.module),
            tostring(status.hooked),
            tostring(status.buttons),
            tostring(status.shown)))
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
    -- The header button's OnClick calls the block's OnHeaderClick. Blizzard's
    -- version forwards to the module's OnBlockHeaderClick, which opens the
    -- quest details. A zone header has no quest, so it owns its click here
    -- and the module leaves Blizzard's quest handler in the secure path.
    block.OnHeaderClick = function(clicked, button)
        if button == "LeftButton" then
            self:ToggleZoneCollapse(clicked)
        end
    end
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

-- Quest blocks and this module are addon-created frames. Calling Blizzard's
-- click handler from one opens the quest log in addon execution, which leaves
-- the quest log layout tainted; the next in-combat map open is then refused.
-- A secure delegate (or a secure call) runs Blizzard's handler as secure code,
-- so the quest log refresh stays untouched.
local function SecureQuestClickHandler(handler)
    if type(handler) ~= "function" then
        return nil
    end
    if type(CreateSecureDelegate) == "function" then
        local ok, delegate = pcall(CreateSecureDelegate, handler)
        if ok and type(delegate) == "function" then
            return delegate, "delegate"
        end
        if type(securecallfunction) == "function" then
            ok, delegate = pcall(securecallfunction, CreateSecureDelegate, handler)
            if ok and type(delegate) == "function" then
                return delegate, "delegate"
            end
        end
    end
    if type(securecallfunction) == "function" then
        return function(self, block, button)
            return securecallfunction(handler, self, block, button)
        end, "secure call"
    end
    return nil
end

local function BuildTrackerMixin()
    local mixin = CreateFromMixins(QuestObjectiveTrackerMixin)
    -- Blizzard draws the quest POI icon just left of the block text. Inside a
    -- scroll frame that overhang would be clipped, so indent quest blocks enough
    -- to keep the visible icon inside the content.
    mixin.blockOffsetX = 30
    local secureClick, clickMode = SecureQuestClickHandler(QuestObjectiveTrackerMixin.OnBlockHeaderClick)
    if secureClick then
        mixin.OnBlockHeaderClick = secureClick
    end
    ns.trackerClickSecured = clickMode

    function mixin:BuildQuestWatchInfos()
        local infos = QuestObjectiveTrackerMixin.BuildQuestWatchInfos(self)
        -- A turned-in quest can linger in the watch list for a frame or more.
        -- Keep only quests that are still in the quest log so the tracker
        -- drops them as soon as the client reports the turn-in.
        if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local inLog = {}
            for i = 1, #infos do
                local quest = infos[i].quest
                local questID = quest and quest.GetID and quest:GetID()
                if type(questID) == "number" then
                    local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
                    if type(logIndex) == "number" and logIndex > 0 then
                        inLog[#inLog + 1] = infos[i]
                    end
                end
            end
            infos = inLog
        end
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
        content:SetPoint("TOPLEFT", scroll, "TOPLEFT", SCROLL_LEFT_INSET, -CONTENT_TOP_PADDING)
        local contentWidth = (scroll:GetWidth() or 0) - SCROLL_LEFT_INSET - CONTENT_RIGHT_PADDING
        if contentWidth <= 1 then
            contentWidth = (self:GetWidth() or 0) - SCROLL_LEFT_INSET - CONTENT_RIGHT_PADDING
        end
        if contentWidth <= 1 and self.Header then
            contentWidth = (self.Header:GetWidth() or 0) - SCROLL_LEFT_INSET - CONTENT_RIGHT_PADDING
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
        local bottomInset = self.bottomInset
        if bottomInset == nil then
            bottomInset = BottomViewportInset()
        end
        local viewport = math.max(0, available - headerHeight - bottomInset)
        if self:IsCollapsed() then
            viewport = 0
        end
        self.contentsHeight = headerHeight + viewport
        scroll:SetHeight(math.max(viewport, 1))
        scroll:SetShown(viewport > 0)
        content:SetHeight(math.max(contentHeight + CONTENT_BOTTOM_PADDING + CONTENT_TOP_PADDING, viewport, 1))
        scroll:UpdateScrollChildRect()
        local range = scroll:GetVerticalScrollRange() or 0
        local offset = scroll:GetVerticalScroll() or 0
        if offset > range then
            scroll:SetVerticalScroll(range)
        end
    end

    function mixin:LayoutContents()
        if self.Header and self.Header.SetWidth then
            local width = self:GetWidth() or 0
            if width > 1 then
                self.Header:SetWidth(width)
            end
        end
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
        -- Quest blocks span the whole row. Keep their wheel and hover
        -- handling, but let the header, item, and POI buttons own clicks.
        -- Otherwise a reused block can sit above the quest item button and
        -- swallow the click that uses the item. Zone headers and auto-quest
        -- popups keep their row click for the collapse and popup handlers.
        -- This runs on every layout so a pooled block that changes roles gets
        -- the right click behavior.
        if block.SetMouseClickEnabled then
            local keepRowClick = block.zoneName ~= nil
                or block.template == "AutoQuestPopUpBlockTemplate"
            block:SetMouseClickEnabled(keepRowClick)
        end
        -- The quest row and its header button can sit above the item and POI
        -- buttons after a block is reused. Raise the interactive controls so
        -- clicks reach them instead of the row. These frames are ours, so the
        -- level change is safe in combat as well.
        if block.GetFrameLevel then
            local base = block:GetFrameLevel() or 0
            if block.HeaderButton and block.HeaderButton.SetFrameLevel then
                block.HeaderButton:SetFrameLevel(base + 1)
            end
            for _, child in ipairs({ block.ItemButton, block.poiButton, block.zoneCollapseButton }) do
                if child and child.SetFrameLevel then
                    child:SetFrameLevel(base + 2)
                end
            end
        end
        -- Cached blocks skip UpdateSingle, so their item button can keep a
        -- stale quest log index after the log reorders. Refresh it here so a
        -- later click uses the current index.
        if block.ItemButton and block.ItemButton.SetUp and type(block.id) == "number"
            and C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
            local logIndex = C_QuestLog.GetLogIndexForQuestID(block.id)
            if type(logIndex) == "number" and logIndex > 0 then
                block.ItemButton:SetUp(logIndex)
            end
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

    -- Quest blocks use Blizzard's OnBlockHeaderClick through a secure delegate
    -- from BuildTrackerMixin. An addon-defined click handler would taint the
    -- quest log and map, so the delegate keeps the Blizzard code secure.
    -- Zone headers own their click in AddZoneHeader instead.
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
    local container = CreateStandaloneContainer()
    local ok, frame = pcall(CreateFrame, "Frame", MODULE_NAME, container, "ObjectiveTrackerModuleTemplate")
    if not ok or not frame or not frame.Header then
        return nil
    end
    Mixin(frame, trackerMixin)
    -- Blizzard's GetContextMenuParent asks the manager which container owns the
    -- module. Register the standalone container so the quest context menu is
    -- created from Blizzard's own handler instead of an addon override.
    if ObjectiveTrackerManager.moduleToContainerMap then
        ObjectiveTrackerManager.moduleToContainerMap[frame] = container
    end
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
    local container = frame:GetParent()
    if frame.Header.RegisterForDrag then
        frame.Header:RegisterForDrag("LeftButton")
        frame.Header:SetScript("OnDragStart", function()
            if container and container.StartMoving then
                container:StartMoving()
            end
        end)
        frame.Header:SetScript("OnDragStop", function()
            if container and container.StopMovingOrSizing then
                container:StopMovingOrSizing()
            end
        end)
    end
    HookTrackerMenu(frame.Header)
    if ns.InstallSpokenTrackerBridge then
        ns.InstallSpokenTrackerBridge(frame)
    end
    return frame
end

-- The quest module's events table normally comes from Blizzard's
-- QuestObjectiveTrackerMixin. Keep a local copy so a missing or empty table
-- cannot leave the tracker without quest update events.
local DEFAULT_MODULE_EVENTS = {
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "QUEST_AUTOCOMPLETE",
    "SUPER_TRACKING_CHANGED",
    "QUEST_TURNED_IN",
    "QUEST_POI_UPDATE",
    "SUPER_TRACKING_PATH_UPDATED",
}

local function ModuleEvents()
    if type(module.events) == "table" and #module.events > 0 then
        return module.events
    end
    return DEFAULT_MODULE_EVENTS
end

local function RegisterModuleEvents()
    local events = ModuleEvents()
    for i = 1, #events do
        module:RegisterEvent(events[i])
    end
end

local function UnregisterModuleEvents()
    local events = ModuleEvents()
    for i = 1, #events do
        module:UnregisterEvent(events[i])
    end
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
    local container = CreateStandaloneContainer()
    container:AddModule(module)
    MoveProfessionsModule(container)
    container:Show()
    -- SetContainer only registers events on the module's first container. The
    -- standalone container is created after the module and may not be that
    -- first container, so register explicitly whenever the module is active.
    RegisterModuleEvents()
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
    if standaloneFrame then
        RestoreProfessionsModule()
        standaloneFrame:RemoveModule(module)
        standaloneFrame:Hide()
    end
    module:Hide()
    UnregisterModuleEvents()
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

function ns.GetTrackerContextMenuParent()
    return standaloneFrame
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
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("QUEST_REMOVED")
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
    if event == "QUEST_ACCEPTED" or event == "QUEST_LOG_UPDATE"
        or event == "QUEST_WATCH_LIST_CHANGED" or event == "QUEST_REMOVED" then
        if active and module and module.MarkDirty then
            module:MarkDirty()
        end
        return
    end
    if event == "QUEST_TURNED_IN" then
        -- The module's own handler plays the turn-in animation and removes
        -- the block when it finishes. Only force a refresh when that handler
        -- is missing.
        if active and module and module.MarkDirty then
            local handled = module.IsEventRegistered
                and module:IsEventRegistered("QUEST_TURNED_IN")
            if not handled then
                module:MarkDirty()
            end
        end
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
