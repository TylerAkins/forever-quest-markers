local ADDON_NAME, ns = ...

-- One addon table, shared across files via the WoW addon environment (`...`).
ForeverQuestPins = ns

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

local eventFrame = CreateFrame("Frame")
local pending = false
local accum = 0
local taintScanned = false
local REFRESH_GAP = 0.15
local hiddenQuestTracker
local questTrackerAlphaBeforeCombat

function ns.ApplyQuestTrackerCombatHide(enteringCombat)
    if enteringCombat and ns.GetOption("hideQuestTrackerInCombat") then
        local frame = ObjectiveTrackerFrame
        if not frame or not frame.GetAlpha or not frame.SetAlpha then
            return
        end
        if not hiddenQuestTracker then
            hiddenQuestTracker = frame
            questTrackerAlphaBeforeCombat = frame:GetAlpha()
        end
        -- SetCollapsed runs Blizzard layout code and can taint secret aura reads.
        -- Alpha leaves the tracker collapse and anchor state untouched.
        hiddenQuestTracker:SetAlpha(0)
    elseif hiddenQuestTracker then
        hiddenQuestTracker:SetAlpha(questTrackerAlphaBeforeCombat)
        hiddenQuestTracker = nil
        questTrackerAlphaBeforeCombat = nil
    end
end

function ns.SyncQuestTrackerCombatVisibility()
    ns.ApplyQuestTrackerCombatHide(UnitAffectingCombat("player"))
end

local WATCHED_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_LOGOUT",
    "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "PLAYER_LEVEL_UP",
    "SKILL_LINES_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "ADDON_ACTION_BLOCKED",
}

function ns.RequestRefresh(reason)
    ns.pendingReason = reason or ns.pendingReason
    if pending then
        return
    end
    pending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(REFRESH_GAP, function()
            if pending then
                ns.RefreshNow(ns.pendingReason)
            end
        end)
    end
end

-- Map layout refreshes must not rebuild completion / profession tables. The
-- The quest database is large enough that invalidating those on every
-- map-show or map-changed causes heavy memory churn.
local function ShouldInvalidateQuestState(reason)
    reason = reason or "manual"
    return reason ~= "map-show"
        and reason ~= "map-show-layout"
        and reason ~= "map-changed"
        and reason ~= "map-display"
        and reason ~= "canvas-zero"
        and reason ~= "quest-hidden"
end

function ns.RefreshNow(reason)
    pending = false
    accum = 0
    reason = reason or "manual"
    if ShouldInvalidateQuestState(reason) then
        if ns.InvalidateCompletionCache then
            ns.InvalidateCompletionCache()
        end
        if ns.InvalidateProfessionCache then
            ns.InvalidateProfessionCache()
        end
    end
    if ns.UpdateWaypoint then ns.UpdateWaypoint() end
    if ns.MapPins then
        ns.MapPins:Refresh(reason)
    end
    -- Hiding a quest changes nameplate eligibility without invalidating caches.
    if ns.Nameplates and (ShouldInvalidateQuestState(reason) or reason == "quest-hidden") then
        ns.Nameplates:RefreshAll()
    end
    -- NPC starter/finisher indexes are rebuilt lazily and already invalidated
    -- when NoteOfferedQuest mutates ns.Quests. Do not drop them on map refresh.
end

-- Classic: QUEST_ACCEPTED(questLogIndex, questID). Some clients pass questID only.
local function QuestIDFromEvent(event, ...)
    local first, second = ...
    if event == "QUEST_ACCEPTED" then
        if type(second) == "number" and second > 0 then
            return second
        end
        if type(first) == "number" and first > 0 then
            return first
        end
        return nil
    end
    if type(first) == "number" and first > 0 then
        return first
    end
    return nil
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_ACTION_BLOCKED" then
        local blockedAddon = ...
        if blockedAddon == ADDON_NAME and ns.RunTaintScan and not taintScanned then
            -- The block names us but every frame in its stack is Blizzard code.
            -- Capture what those frames hold before the session moves on; the
            -- taint stays until something rewrites it. Once per session is
            -- enough and keeps a combat map from printing the report repeatedly.
            taintScanned = true
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if ns.RunTaintScan then
                        ns.RunTaintScan()
                    end
                end)
            end
        end
        return
    end
    if event == "ADDON_LOADED" then
        local loaded = ...
        ns.TryRegisterQuestLinks()
        if loaded ~= ADDON_NAME then
            return
        end
        ns.InitSettings()
        ns.RegisterSlash()
        ns.TryRegisterSettings()
        if ns.MapPins then
            ns.MapPins:HookMap()
        end
        if ns.NPCTooltips and ns.NPCTooltips.Initialize then
            ns.NPCTooltips:Initialize()
        end
        return
    end
    if event == "QUEST_DATA_LOAD" or event == "QUEST_DATA_LOAD_RESULT" then
        local questID, success = ...
        if ns.InvalidateInstanceQuestCache then
            ns.InvalidateInstanceQuestCache(questID)
        end
        if ns.InvalidatePvPQuestCache then
            ns.InvalidatePvPQuestCache(questID)
        end
        if success == false then
            if ns.OnQuestDataLoadFailed then ns.OnQuestDataLoadFailed(questID) end
            return
        end
        if ns.OnQuestDataLoad then
            ns.OnQuestDataLoad(questID)
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        if ns.StartWelcome then ns.StartWelcome() end
        ns.TryRegisterQuestLinks()
        ns.TryRegisterSettings()
        if ns.SyncSettingsCheckboxes then
            ns.SyncSettingsCheckboxes()
        end
        if ns.MapPins then
            ns.MapPins:HookMap()
        end
        ns.RequestRefresh(event)
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        ns.TryRegisterSettings()
        if ns.SyncSettingsCheckboxes then
            ns.SyncSettingsCheckboxes()
        end
        ns.RequestRefresh(event)
        return
    end
    if event == "QUEST_ACCEPTED" then
        local questID = QuestIDFromEvent(event, ...)
        if questID and ns.InvalidateInstanceQuestCache then
            ns.InvalidateInstanceQuestCache(questID)
        end
        if questID and ns.InvalidatePvPQuestCache then
            ns.InvalidatePvPQuestCache(questID)
        end
        if questID and ns.NoteQuestAccepted then
            ns.NoteQuestAccepted(questID)
        end
        if questID and ns.Breadcrumbs and ns.Breadcrumbs.OnQuestAccepted then
            ns.Breadcrumbs.OnQuestAccepted(questID)
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = QuestIDFromEvent(event, ...)
        if questID and ns.InvalidateInstanceQuestCache then
            ns.InvalidateInstanceQuestCache(questID)
        end
        if questID and ns.InvalidatePvPQuestCache then
            ns.InvalidatePvPQuestCache(questID)
        end
        if questID and ns.NoteQuestCompleted then
            ns.NoteQuestCompleted(questID)
        end
        if questID and ns.Breadcrumbs and ns.Breadcrumbs.OnQuestEnded then
            ns.Breadcrumbs.OnQuestEnded(questID)
        end
        if ns.OnWaypointQuestEnded then
            ns.OnWaypointQuestEnded(questID)
        end
    elseif event == "QUEST_REMOVED" then
        local questID = QuestIDFromEvent(event, ...)
        if questID and ns.InvalidateInstanceQuestCache then
            ns.InvalidateInstanceQuestCache(questID)
        end
        if questID and ns.InvalidatePvPQuestCache then
            ns.InvalidatePvPQuestCache(questID)
        end
        if questID and ns.NoteQuestRemoved then
            ns.NoteQuestRemoved(questID)
        end
        if questID and ns.Breadcrumbs and ns.Breadcrumbs.OnQuestEnded then
            ns.Breadcrumbs.OnQuestEnded(questID)
        end
        if ns.OnWaypointQuestEnded then
            ns.OnWaypointQuestEnded(questID)
        end
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if ns.Nameplates then
            ns.Nameplates:UpdateUnit(unit)
        end
        return
    end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if ns.Nameplates then
            ns.Nameplates:ReleaseUnit(unit)
        end
        return
    end
    if event == "PLAYER_LOGOUT" then
        if ns.FlushSettings then
            ns.FlushSettings()
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        ns.ApplyQuestTrackerCombatHide(true)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        ns.ApplyQuestTrackerCombatHide(false)
        ns.RequestRefresh(event)
        return
    end
    ns.RequestRefresh(event)
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not pending or (C_Timer and C_Timer.After) then
        return
    end
    accum = accum + elapsed
    if accum >= REFRESH_GAP then
        ns.RefreshNow(ns.pendingReason)
    end
end)

for i = 1, #WATCHED_EVENTS do
    eventFrame:RegisterEvent(WATCHED_EVENTS[i])
end
-- Not present on every Forever build; ignore if the client rejects it.
pcall(eventFrame.RegisterEvent, eventFrame, "QUEST_DATA_LOAD")
pcall(eventFrame.RegisterEvent, eventFrame, "QUEST_DATA_LOAD_RESULT")

if WorldMapFrame then
    -- WorldMapFrame exists at load on some clients; hook immediately too.
    if ns.MapPins then
        ns.MapPins:HookMap()
    end
end

pcall(eventFrame.RegisterEvent, eventFrame, "QUEST_POI_UPDATE")
