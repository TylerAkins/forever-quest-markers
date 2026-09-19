local ADDON_NAME, ns = ...

-- One addon table, shared across files via the WoW addon environment (`...`).
ForeverQuestPins = ns

local eventFrame = CreateFrame("Frame")
local pending = false
local accum = 0
local REFRESH_GAP = 0.15

local WATCHED_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "QUEST_LOG_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "PLAYER_LEVEL_UP",
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
    if ns.MapPins then
        ns.MapPins:Refresh(reason or "manual")
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then
            return
        end
        ns.InitSettings()
        ns.RegisterSlash()
        ns.TryRegisterSettings()
        if ns.MapPins then
            ns.MapPins:HookMap()
        end
        return
    end
    if event == "QUEST_DATA_LOAD" then
        local questID = ...
        if ns.OnQuestDataLoad then
            ns.OnQuestDataLoad(questID)
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        if ns.MapPins then
            ns.MapPins:HookMap()
        end
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

if WorldMapFrame then
    -- WorldMapFrame exists at load on some clients; hook immediately too.
    if ns.MapPins then
        ns.MapPins:HookMap()
    end
end
