local ADDON_NAME, ns = ...

ns.AutoQuests = ns.AutoQuests or {}
local AutoQuests = ns.AutoQuests

local function Debug(message)
    if ns.GetOption("debug") then
        print("|cffffd100Forever Quest Pins auto:|r " .. tostring(message))
    end
end

local function PCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, result = pcall(fn, ...)
    return ok and result ~= false, result
end

local function ShouldSkip()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function GossipSelectAvailable(info, index)
    local questID = info and (info.questID or info.questId)
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
        if questID then
            return PCall(C_GossipInfo.SelectAvailableQuest, questID)
        end
        return PCall(C_GossipInfo.SelectAvailableQuest, index)
    end
    if SelectGossipAvailableQuest then
        return PCall(SelectGossipAvailableQuest, index)
    end
    return false
end

local function GossipSelectActive(info, index)
    local questID = info and (info.questID or info.questId)
    if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
        if questID then
            return PCall(C_GossipInfo.SelectActiveQuest, questID)
        end
        return PCall(C_GossipInfo.SelectActiveQuest, index)
    end
    if SelectGossipActiveQuest then
        return PCall(SelectGossipActiveQuest, index)
    end
    return false
end

local function IsCompleteInfo(info)
    if type(info) ~= "table" then
        return false
    end
    return info.isComplete or info.complete or info.IsComplete or false
end

local function IsIgnoredInfo(info)
    if type(info) ~= "table" then
        return false
    end
    return info.isIgnored or info.ignored or false
end

local function GossipAvailableList()
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local list = C_GossipInfo.GetAvailableQuests()
        if type(list) == "table" then
            return list
        end
    end
    return nil
end

local function GossipActiveList()
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        local list = C_GossipInfo.GetActiveQuests()
        if type(list) == "table" then
            return list
        end
    end
    return nil
end

local function ClassicActiveIsComplete(index)
    if not GetGossipActiveQuests then
        return nil
    end
    local data = { GetGossipActiveQuests() }
    if #data == 0 then
        return nil
    end
    local stride = 6
    if #data % 6 ~= 0 then
        if #data % 4 == 0 then
            stride = 4
        elseif #data % 5 == 0 then
            stride = 5
        else
            return nil
        end
    end
    local complete = data[(index - 1) * stride + 4]
    if complete == nil then
        return nil
    end
    return complete and true or false
end

local function TryTurnInGossip()
    if not ns.GetOption("autoTurnIn") then
        return false
    end
    local list = GossipActiveList()
    if list then
        for i = 1, #list do
            local info = list[i]
            if IsCompleteInfo(info) and not IsIgnoredInfo(info) then
                Debug("gossip turn-in " .. tostring(info.questID or info.title or i))
                return GossipSelectActive(info, i)
            end
        end
        return false
    end
    local count = GetNumGossipActiveQuests and GetNumGossipActiveQuests() or 0
    for i = 1, count do
        local complete = ClassicActiveIsComplete(i)
        if complete == true then
            Debug("gossip turn-in #" .. tostring(i))
            return GossipSelectActive(nil, i)
        end
    end
    return false
end

local function TryAcceptGossip()
    if not ns.GetOption("autoAccept") then
        return false
    end
    local list = GossipAvailableList()
    if list then
        for i = 1, #list do
            local info = list[i]
            if not IsIgnoredInfo(info) then
                Debug("gossip accept " .. tostring(info.questID or info.title or i))
                return GossipSelectAvailable(info, i)
            end
        end
        return false
    end
    local count = GetNumGossipAvailableQuests and GetNumGossipAvailableQuests() or 0
    if count > 0 and SelectGossipAvailableQuest then
        Debug("gossip accept #1")
        return PCall(SelectGossipAvailableQuest, 1)
    end
    return false
end

local function TryTurnInGreeting()
    if not ns.GetOption("autoTurnIn") then
        return false
    end
    local count = GetNumActiveQuests and GetNumActiveQuests() or 0
    for i = 1, count do
        local title, complete = GetActiveTitle(i)
        if complete then
            Debug("greeting turn-in " .. tostring(title or i))
            if SelectActiveQuest then
                return PCall(SelectActiveQuest, i)
            end
        end
    end
    return false
end

local function TryAcceptGreeting()
    if not ns.GetOption("autoAccept") then
        return false
    end
    local count = GetNumAvailableQuests and GetNumAvailableQuests() or 0
    if count > 0 and SelectAvailableQuest then
        Debug("greeting accept #1")
        return PCall(SelectAvailableQuest, 1)
    end
    return false
end

local function TryAcceptDetail()
    if not ns.GetOption("autoAccept") then
        return false
    end
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        return false
    end
    if AcceptQuest then
        Debug("AcceptQuest")
        return PCall(AcceptQuest)
    end
    return false
end

local function TryCompleteProgress()
    if not ns.GetOption("autoTurnIn") then
        return false
    end
    if IsQuestCompletable and not IsQuestCompletable() then
        return false
    end
    if CompleteQuest then
        Debug("CompleteQuest")
        return PCall(CompleteQuest)
    end
    return false
end

local function TryChooseReward()
    if not ns.GetOption("autoTurnIn") then
        return false
    end
    local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if choices > 1 then
        Debug("skip reward: " .. tostring(choices) .. " choices")
        return false
    end
    if not GetQuestReward then
        return false
    end
    Debug("GetQuestReward")
    if choices == 1 then
        return PCall(GetQuestReward, 1)
    end
    local ok = PCall(GetQuestReward)
    if ok then
        return true
    end
    return PCall(GetQuestReward, 1)
end

local function TryConfirmAccept()
    if not ns.GetOption("autoAccept") then
        return false
    end
    if ConfirmAcceptQuest then
        Debug("ConfirmAcceptQuest")
        return PCall(ConfirmAcceptQuest)
    end
    return false
end

local function Defer(label, fn)
    local function run()
        if ShouldSkip() then
            return
        end
        local ok, err = pcall(fn)
        if not ok then
            Debug(label .. " error: " .. tostring(err))
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
        return
    end
    run()
end

function AutoQuests:OnGossipShow()
    Defer("gossip", function()
        if TryTurnInGossip() then
            return
        end
        TryAcceptGossip()
    end)
end

function AutoQuests:OnQuestGreeting()
    Defer("greeting", function()
        if TryTurnInGreeting() then
            return
        end
        TryAcceptGreeting()
    end)
end

function AutoQuests:OnQuestDetail()
    Defer("detail", function()
        TryAcceptDetail()
    end)
end

function AutoQuests:OnQuestProgress()
    Defer("progress", function()
        TryCompleteProgress()
    end)
end

function AutoQuests:OnQuestComplete()
    Defer("complete", function()
        TryChooseReward()
    end)
end

function AutoQuests:OnQuestAcceptConfirm()
    Defer("confirm", function()
        TryConfirmAccept()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        AutoQuests:OnGossipShow()
        return
    end
    if event == "QUEST_GREETING" then
        AutoQuests:OnQuestGreeting()
        return
    end
    if event == "QUEST_DETAIL" then
        AutoQuests:OnQuestDetail()
        return
    end
    if event == "QUEST_PROGRESS" then
        AutoQuests:OnQuestProgress()
        return
    end
    if event == "QUEST_COMPLETE" then
        AutoQuests:OnQuestComplete()
        return
    end
    if event == "QUEST_ACCEPT_CONFIRM" then
        AutoQuests:OnQuestAcceptConfirm()
        return
    end
end)

local WATCHED_EVENTS = {
    "GOSSIP_SHOW",
    "QUEST_GREETING",
    "QUEST_DETAIL",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "QUEST_ACCEPT_CONFIRM",
}

for i = 1, #WATCHED_EVENTS do
    pcall(eventFrame.RegisterEvent, eventFrame, WATCHED_EVENTS[i])
end
