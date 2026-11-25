local _, ns = ...

-- Spoken's quest module dresses the client's quest modules for its Play
-- button. Our standalone tracker has a different global name, so attach the
-- same button to its blocks when Spoken and Spoken_Quests are loaded.

local MODULE_NAME = "FQPQuestObjectiveTracker"
local BOX = "QuestLog-icon-ticksquare"
local SIZE = 14

local trackerModule
local hooked
local callbacksRegistered
local updateHooked
local buttons = {}

local function SpokenParts()
    local spoken = rawget(_G, "Spoken")
    local voiceOver = rawget(_G, "VoiceOver")
    local ui = voiceOver and voiceOver.QuestOverlayUI
    local utils = voiceOver and voiceOver.Utils
    if type(spoken) ~= "table" or type(ui) ~= "table" or type(utils) ~= "table"
        or type(spoken.DressBoxButton) ~= "function"
        or type(utils.CreateDetachedFrame) ~= "function" then
        return nil
    end
    return spoken, voiceOver, ui, utils
end

local function Report(err)
    if ns.GetOption and ns.GetOption("debug") then
        print("|cffffd100Forever Quest Pins:|r Spoken tracker button: " .. tostring(err))
    end
end

local function Place(block, button)
    local header = block.HeaderText
    button:ClearAllPoints()
    if header and header.GetRight then
        -- Sit just left of the title's reserved edge, on the title line. The
        -- item button owns the right edge, so this avoids the next zone header.
        button:SetPoint("RIGHT", header, "RIGHT", -2, 0)
        return
    end
    local edge = block.rightEdgeFrame
    if type(edge) == "table" and edge.IsShown and edge:IsShown() then
        button:SetPoint("RIGHT", edge, "LEFT", -2, 0)
    else
        button:SetPoint("TOPRIGHT", block, "TOPRIGHT", 0, 0)
    end
end

local function Dress(block)
    local spoken, voiceOver, ui, utils = SpokenParts()
    if not spoken or not ui or not utils then
        return
    end
    local questID = block.id
    local button = buttons[block]
    if type(questID) ~= "number" or not ui:ShowsTrackerButton(questID) then
        if button then button:Hide() end
        return
    end
    if not button then
        button = utils:CreateDetachedFrame("Button", nil, block)
        button:SetSize(SIZE, SIZE)
        button:SetHitRectInsets(1, 1, 1, 1)
        local ok, err = pcall(spoken.DressBoxButton, spoken, button)
        if ok then
            ok, err = pcall(button.SetBox, button, BOX, SIZE, SIZE)
        end
        if not ok then
            button:Hide()
            Report(err)
            return
        end
        button.setPlayState = ui.FollowQueue
        -- The tracker sits over the world, so the box needs its own dark backing.
        local back = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        back:SetPoint("TOPLEFT", 1, -1)
        back:SetPoint("BOTTOMRIGHT", -1, 1)
        back:SetColorTexture(0, 0, 0, 0.6)
        button:SetFrameLevel(block:GetFrameLevel() + 3)
        buttons[block] = button
    end
    Place(block, button)
    if button.questID ~= questID then
        button.soundData = nil
    end
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID
        and C_QuestLog.GetTitleForQuestID(questID) or ""
    ui:BindPlayButton(button, questID, title, "the objective tracker's Play button")
    button:Show()
    ui:SetPlayButtonState(button)
end

local function SafelyDress(block)
    local ok, err = pcall(Dress, block)
    if not ok then
        Report(err)
    end
end

local function Sweep()
    if not trackerModule then
        return
    end
    local blocks = trackerModule.usedBlocks
    if type(blocks) ~= "table" then
        return
    end
    for _, byTemplate in pairs(blocks) do
        if type(byTemplate) == "table" then
            for _, block in pairs(byTemplate) do
                if type(block) == "table" and block.id then
                    SafelyDress(block)
                end
            end
        end
    end
end

local function RegisterCallbacks()
    local spoken = SpokenParts()
    if not spoken or callbacksRegistered or type(spoken.RegisterCallback) ~= "function" then
        return
    end
    callbacksRegistered = true
    pcall(spoken.RegisterCallback, spoken, "VOICE_PACKS_LOADED", Sweep)
    pcall(spoken.RegisterCallback, spoken, "PART_SWITCHED", function(key)
        if key == "quests" then
            Sweep()
        end
    end)
end

local function HookUpdate()
    local _, _, ui = SpokenParts()
    if not ui or updateHooked or type(ui.UpdateTrackerButtons) ~= "function" then
        return
    end
    updateHooked = true
    hooksecurefunc(ui, "UpdateTrackerButtons", Sweep)
end

local function Install()
    if not trackerModule then
        trackerModule = rawget(_G, MODULE_NAME)
    end
    if type(trackerModule) ~= "table" or type(trackerModule.AddBlock) ~= "function" then
        return false
    end
    if not hooked then
        hooked = true
        hooksecurefunc(trackerModule, "AddBlock", function(_, block)
            SafelyDress(block)
        end)
    end
    RegisterCallbacks()
    HookUpdate()
    Sweep()
    return true
end

function ns.InstallSpokenTrackerBridge(module)
    if type(module) == "table" then
        trackerModule = module
    end
    Install()
end

function ns.SpokenBridgeStatus()
    local spoken, voiceOver, ui = SpokenParts()
    local count, shown = 0, 0
    for _, button in pairs(buttons) do
        count = count + 1
        if button.IsShown and button:IsShown() then
            shown = shown + 1
        end
    end
    return {
        spoken = spoken ~= nil,
        voiceOver = voiceOver ~= nil,
        ui = ui ~= nil,
        module = trackerModule ~= nil,
        hooked = hooked == true,
        buttons = count,
        shown = shown,
    }
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "PLAYER_LOGIN" or addon == "Spoken" or addon == "Spoken_Quests" then
        ns.InstallSpokenTrackerBridge()
    end
end)
