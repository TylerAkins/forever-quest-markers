local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

-- Forever has one native switch for the loot sparkle. It draws the sparkle on
-- quest items and on quest givers alike, and a graphics preset can turn it back
-- off. The player's outline CVars are never read or written here.
local CVAR = "outlineModeShowLootEffectWhenDisabled"
ns.SPARKLE_CVAR = CVAR

local GRAPHICS_CVARS = { graphicsquality = true, raidgraphicsquality = true }
local LOGIN_RETRY_SECONDS = 5
local GRAPHICS_RETRY_SECONDS = 1

local applying = false
local warnedOff = false
local pendingApply = false
local scheduledApply = false

local function Print(message)
    print("|cffffd100Forever Quest Pins:|r " .. tostring(message))
end

local function CVarAPI()
    if C_CVar
        and type(C_CVar.GetCVar) == "function"
        and type(C_CVar.SetCVar) == "function" then
        return C_CVar
    end
    return nil
end

local function ReadCVar()
    local api = CVarAPI()
    if not api then
        return nil
    end
    local ok, value = pcall(api.GetCVar, CVAR)
    if not ok then
        return nil
    end
    return value
end

local function WriteCVar(value)
    local api = CVarAPI()
    if not api then
        return false
    end
    -- The guard keeps the addon's own write from scheduling another apply.
    applying = true
    local ok = pcall(api.SetCVar, CVAR, value)
    applying = false
    return ok
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

local function ScheduleApply(delay)
    if scheduledApply or not (C_Timer and C_Timer.After) then
        return
    end
    scheduledApply = true
    C_Timer.After(delay, function()
        scheduledApply = false
        ns.ApplySparkleSetting()
    end)
end

function ns.ApplySparkleSetting()
    if not CVarAPI() then
        return false
    end
    if InCombat() then
        pendingApply = true
        return false
    end
    pendingApply = false
    local current = ReadCVar()
    if current == nil then
        return false
    end
    if ns.GetOption("sparkleQuestItems") then
        warnedOff = false
        if current == "1" then
            return true
        end
        return WriteCVar("1")
    end
    if current ~= "1" then
        return true
    end
    if not WriteCVar("0") then
        return false
    end
    -- The client keeps drawing sparkles until the game restarts, so warn once
    -- per off period instead of on every login and settings refresh.
    if not warnedOff then
        warnedOff = true
        Print(L["Quest item sparkles are off. Restart the game to remove them; /reload is not enough."])
    end
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
if frame.RegisterEvent then
    pcall(frame.RegisterEvent, frame, "CVAR_UPDATE")
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == ADDON_NAME and ns.InitSettings then
            ns.InitSettings()
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        ns.ApplySparkleSetting()
        ScheduleApply(LOGIN_RETRY_SECONDS)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            ns.ApplySparkleSetting()
        end
        return
    end
    if event == "CVAR_UPDATE" then
        local name = ...
        if applying then
            return
        end
        if GRAPHICS_CVARS[(tostring(name or "")):lower()] then
            ScheduleApply(GRAPHICS_RETRY_SECONDS)
        end
    end
end)
