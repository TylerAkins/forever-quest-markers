local ADDON_NAME, ns = ...

-- One addon table, shared across files via the WoW addon environment (`...`).
ForeverQuestPins = ns

local eventFrame = CreateFrame("Frame")
local pending = false
local accum = 0
local REFRESH_GAP = 0.15
local questTrackerCollapsedBeforeCombat

local function GetObjectiveTrackerFrame()
    return ObjectiveTrackerFrame
end

function ns.ApplyQuestTrackerCombatHide(enteringCombat)
    if not ns.GetOption("hideQuestTrackerInCombat") then
        return
    end
    local frame = GetObjectiveTrackerFrame()
    if not frame or not frame.SetCollapsed then
        return
    end
    if enteringCombat then
        if questTrackerCollapsedBeforeCombat == nil then
            questTrackerCollapsedBeforeCombat = frame.IsCollapsed and frame:IsCollapsed() or false
        end
        frame:SetCollapsed(true)
    elseif questTrackerCollapsedBeforeCombat ~= nil then
        frame:SetCollapsed(questTrackerCollapsedBeforeCombat)
        questTrackerCollapsedBeforeCombat = nil
    end
end

function ns.SyncQuestTrackerCombatVisibility()
    if not ns.GetOption("hideQuestTrackerInCombat") then
        if questTrackerCollapsedBeforeCombat ~= nil then
            local frame = GetObjectiveTrackerFrame()
            if frame and frame.SetCollapsed then
                frame:SetCollapsed(questTrackerCollapsedBeforeCombat)
            end
            questTrackerCollapsedBeforeCombat = nil
        end
        return
    end
    if UnitAffectingCombat("player") then
        ns.ApplyQuestTrackerCombatHide(true)
    else
        ns.ApplyQuestTrackerCombatHide(false)
    end
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

function ns.RefreshNow(reason)
    pending = false
    accum = 0
    if ns.InvalidateCompletionCache then
        ns.InvalidateCompletionCache()
    end
    if ns.InvalidateProfessionCache then
        ns.InvalidateProfessionCache()
    end
    if ns.UpdateWaypoint then ns.UpdateWaypoint() end
    if ns.MapPins then
        ns.MapPins:Refresh(reason or "manual")
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == "Blizzard_WorldMap" then
            if ns.TryRegisterWorldMapDropdown then
                ns.TryRegisterWorldMapDropdown()
            end
            return
        end
        if loaded ~= ADDON_NAME then
            return
        end
        ns.InitSettings()
        ns.RegisterSlash()
        ns.TryRegisterSettings()
        if ns.TryRegisterWorldMapDropdown then
            ns.TryRegisterWorldMapDropdown()
        end
        if ns.MapPins then
            ns.MapPins:HookMap()
        end
        return
    end
    if event == "QUEST_DATA_LOAD" or event == "QUEST_DATA_LOAD_RESULT" then
        local questID, success = ...
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
        ns.TryRegisterSettings()
        if ns.TryRegisterWorldMapDropdown then
            ns.TryRegisterWorldMapDropdown()
        end
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
        if ns.TryRegisterWorldMapDropdown then
            ns.TryRegisterWorldMapDropdown()
        end
        if ns.SyncSettingsCheckboxes then
            ns.SyncSettingsCheckboxes()
        end
        ns.RequestRefresh(event)
        return
    end
    if event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        if ns.OnWaypointQuestEnded then ns.OnWaypointQuestEnded(...) end
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
