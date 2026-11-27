local ADDON_NAME, ns = ...
local L = ns.L or setmetatable({}, { __index = function(_, key) return key end })

ns.QuestRoute = ns.QuestRoute or {}

-- A small, always-re-evaluated route through one zone or dungeon.
-- Quest prerequisites and the journal give us the required order and start
-- locations. Objective and turn-in locations come from the client once a
-- quest is in the log, so the modal follows the tracker instead of guessing.

local FRAME_WIDTH = 440
local FRAME_HEIGHT = 260
local PADDING = 24

local frame
local currentKind
local currentTarget
local currentLabel
local steps = {}
local totalSteps = 0
local completedSteps = 0
local skipped = {}
local autoPinnedKey
local pendingPinKey
local refreshToken = 0

local ACTION_LABELS = {
    accept = L["Accept"],
    complete = L["Complete"],
    turnin = L["Turn in"],
}

local ACTION_COLORS = {
    accept = { 1.00, 0.82, 0.00 },
    complete = { 0.35, 0.95, 0.45 },
    turnin = { 0.25, 0.75, 1.00 },
}

local function MapName(mapID)
    if mapID and C_Map and type(C_Map.GetMapInfo) == "function" then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name then
            return info.name
        end
    end
    return L["Unknown zone"]
end

local function HasPoint(mapID, x, y)
    return type(mapID) == "number" and mapID > 0
        and type(x) == "number" and type(y) == "number"
end

local function NormalizeXY(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil, nil
    end
    if x <= 1 and y <= 1 then
        return x * 100, y * 100
    end
    return x, y
end

local function QuestWaypoint(questID)
    if C_QuestLog and type(C_QuestLog.GetNextWaypoint) == "function" then
        local mapID, x, y = C_QuestLog.GetNextWaypoint(questID)
        if HasPoint(mapID, x, y) then
            return mapID, NormalizeXY(x, y)
        end
    end
    return nil
end

local function StepAction(node)
    if ns.IsOnQuest(node.id) then
        if ns.IsQuestReadyForTurnIn(node.id) then
            return "turnin"
        end
        return "complete"
    end
    return "accept"
end

local ACTION_PRIORITY = {
    turnin = 1,
    complete = 2,
    accept = 3,
}

local function NodePriority(node)
    if node.action == "accept" and node.acceptable == false then
        return ACTION_PRIORITY.accept + 1
    end
    return ACTION_PRIORITY[node.action] or 4
end

local function StepLocation(node, action)
    if action ~= "accept" then
        return QuestWaypoint(node.id)
    end
    if node.mapID then
        return node.mapID, node.x, node.y
    end
    return nil
end

local function SetLocationMapName(panel, action, mapID, x, y)
    local prefix
    if action == "accept" then
        prefix = L["Start: "]
    elseif action == "turnin" then
        prefix = L["Turn in: "]
    else
        prefix = L["Objective: "]
    end
    panel.location:SetText(string.format("%s%s (%.1f, %.1f)", prefix, MapName(mapID), x, y))
end

local function BuildOrder(nodes, orderList, skipSet)
    local active = {}
    local activeCount = 0
    for i = 1, #orderList do
        local questID = orderList[i]
        if not ns.IsQuestFlaggedCompleted(questID) and not (skipSet and skipSet[questID]) then
            active[questID] = true
            activeCount = activeCount + 1
        end
    end

    local indegree = {}
    for questID in pairs(active) do
        indegree[questID] = 0
    end
    for questID in pairs(active) do
        local node = nodes[questID]
        for prereqID in pairs(node.prereqs) do
            if active[prereqID] then
                indegree[questID] = indegree[questID] + 1
            end
        end
    end

    local result = {}
    local used = {}
    while #result < activeCount do
        local bestID, best
        for questID in pairs(active) do
            if not used[questID] and indegree[questID] == 0 then
                local node = nodes[questID]
                if not best then
                    bestID, best = questID, node
                else
                    local priority = NodePriority(node)
                    local bestPriority = NodePriority(best)
                    if priority < bestPriority
                        or (priority == bestPriority and node.depth < best.depth)
                        or (priority == bestPriority and node.depth == best.depth
                            and node.order < best.order) then
                        bestID, best = questID, node
                    end
                end
            end
        end
        if not bestID then
            break
        end
        used[bestID] = true
        result[#result + 1] = best
        for questID in pairs(active) do
            if not used[questID] and nodes[questID].prereqs[bestID] then
                indegree[questID] = indegree[questID] - 1
            end
        end
    end

    -- A bad chain must not hide the rest of the route. Keep the leftovers in a
    -- stable order so the player can still work through them.
    if #result < activeCount then
        local remaining = {}
        for questID in pairs(active) do
            if not used[questID] then
                remaining[#remaining + 1] = nodes[questID]
            end
        end
        table.sort(remaining, function(a, b)
            if a.depth ~= b.depth then
                return a.depth < b.depth
            end
            return a.order < b.order
        end)
        for i = 1, #remaining do
            result[#result + 1] = remaining[i]
        end
    end

    return result
end

local function AddNode(nodes, orderList, quest, depth, prereqID)
    local questID = quest and quest.id
    if type(questID) ~= "number" then
        return nil
    end
    local data = ns.Quests and ns.Quests[questID]
    if not ns.PlayerMatches(data, quest.faction) then
        return nil
    end

    local node = nodes[questID]
    if not node then
        local mapID = quest.mapID or (data and data.mapID)
        local x = quest.x or (data and data.x)
        local y = quest.y or (data and data.y)
        if not HasPoint(mapID, x, y) then
            mapID, x, y = nil, nil, nil
        end
        node = {
            id = questID,
            title = quest.name or (data and data.title)
                or (ns.GetQuestTitle and ns.GetQuestTitle(questID, true))
                or tostring(questID),
            data = data,
            mapID = mapID,
            x = x,
            y = y,
            depth = depth,
            order = #orderList + 1,
            prereqs = {},
        }
        nodes[questID] = node
        orderList[#orderList + 1] = questID
    elseif depth < node.depth then
        node.depth = depth
    end

    if prereqID and prereqID ~= questID then
        node.prereqs[prereqID] = true
    end
    node.action = StepAction(node)
    node.acceptable = node.action ~= "accept"
        or not node.data
        or not ns.IsQuestAcceptable
        or ns.IsQuestAcceptable(node.id, node.data)
    return node
end

local function BuildDungeon(dungeonName, skipSet)
    local dungeon = ns.DungeonChains
        and ns.DungeonChains.dungeons
        and ns.DungeonChains.dungeons[dungeonName]
    if not dungeon then
        return { steps = {}, total = 0, completed = 0 }
    end

    local nodes, orderList = {}, {}
    for _, quest in ipairs(dungeon.quests or {}) do
        local chain = quest.chain or {}
        local previousID
        for i = 1, #chain do
            local node = AddNode(nodes, orderList, chain[i], i, previousID)
            if node then
                previousID = node.id
            end
        end
        AddNode(nodes, orderList, quest, #chain + 1, previousID)
    end

    local total = #orderList
    local completed = 0
    for i = 1, total do
        if ns.IsQuestFlaggedCompleted(orderList[i]) then
            completed = completed + 1
        end
    end

    local ordered = BuildOrder(nodes, orderList, skipSet)
    for i = 1, #ordered do
        local node = ordered[i]
        node.action = StepAction(node)
        node.locationMapID, node.locationX, node.locationY = StepLocation(node, node.action)
    end

    return { steps = ordered, total = total, completed = completed }
end

local function ZonePrereqs(questID, data, nodes)
    local prereqs = {}
    if not data then
        return prereqs
    end
    local function add(prereqID)
        if type(prereqID) ~= "number" or prereqID == questID or not nodes[prereqID] then
            return
        end
        local prereqData = ns.Quests and ns.Quests[prereqID]
        if prereqData and prereqData.isBreadcrumb then
            return
        end
        if not ns.IsQuestFlaggedCompleted(prereqID) then
            prereqs[prereqID] = true
        end
    end

    for _, prereqID in ipairs(data.sourceQuestGroup or {}) do
        add(prereqID)
    end
    local single = data.sourceQuestSingle or {}
    if #single > 0 and (data.sourceQuestNumRequired or 1) >= #single then
        for i = 1, #single do
            add(single[i])
        end
    end
    local legacy = data.sourceQuests or {}
    if #legacy > 0 and (data.sourceQuestNumRequired or 1) >= #legacy then
        for i = 1, #legacy do
            add(legacy[i])
        end
    end
    return prereqs
end

local function ComputeZoneDepths(nodes, orderList)
    local function Depth(questID, visiting)
        local node = nodes[questID]
        if not node then
            return 0
        end
        if node.zoneDepth then
            return node.zoneDepth
        end
        if visiting[questID] then
            return 1
        end
        visiting[questID] = true
        local depth = 1
        for prereqID in pairs(node.prereqs) do
            local value = Depth(prereqID, visiting) + 1
            if value > depth then
                depth = value
            end
        end
        visiting[questID] = nil
        node.zoneDepth = depth
        return depth
    end

    for i = 1, #orderList do
        local node = nodes[orderList[i]]
        node.depth = Depth(node.id, {})
    end
end

local function BuildZone(mapID, skipSet)
    if type(mapID) ~= "number" then
        return { steps = {}, total = 0, completed = 0 }
    end
    local zoneIDs = ns.QuestFinder
        and ns.QuestFinder.ZoneQuestIDs
        and ns.QuestFinder.ZoneQuestIDs(mapID)
        or {}
    local ids = {}
    for i = 1, #zoneIDs do
        ids[i] = zoneIDs[i]
    end
    table.sort(ids, function(a, b)
        local da = ns.Quests and ns.Quests[a]
        local db = ns.Quests and ns.Quests[b]
        local la = (da and da.minLevel) or 0
        local lb = (db and db.minLevel) or 0
        if la ~= lb then
            return la < lb
        end
        local ta = (da and da.title) or ""
        local tb = (db and db.title) or ""
        if ta ~= tb then
            return ta < tb
        end
        return a < b
    end)

    local nodes, orderList = {}, {}
    for i = 1, #ids do
        local questID = ids[i]
        local data = ns.Quests and ns.Quests[questID]
        if data then
            AddNode(nodes, orderList, {
                id = questID,
                name = data.title,
                mapID = data.mapID,
                x = data.x,
                y = data.y,
            }, 1, nil)
        end
    end
    for i = 1, #orderList do
        local questID = orderList[i]
        local data = ns.Quests and ns.Quests[questID]
        nodes[questID].prereqs = ZonePrereqs(questID, data, nodes)
    end
    ComputeZoneDepths(nodes, orderList)

    local total = #orderList
    local completed = 0
    for i = 1, total do
        if ns.IsQuestFlaggedCompleted(orderList[i]) then
            completed = completed + 1
        end
    end

    local ordered = BuildOrder(nodes, orderList, skipSet)
    for i = 1, #ordered do
        local node = ordered[i]
        node.action = StepAction(node)
        node.locationMapID, node.locationX, node.locationY = StepLocation(node, node.action)
    end

    return { steps = ordered, total = total, completed = completed }
end

local function BuildCurrent(skipSet)
    if currentKind == "zone" then
        return BuildZone(currentTarget, skipSet)
    end
    return BuildDungeon(currentTarget, skipSet)
end

local function StepKey(step)
    return tostring(currentKind) .. ":" .. tostring(currentTarget) .. ":"
        .. tostring(step.id) .. ":" .. step.action
end

local function TrackStep(step, report)
    if not step then
        return
    end
    if ns.AddOnActionsRestricted and ns.AddOnActionsRestricted() then
        pendingPinKey = StepKey(step)
        return
    end
    pendingPinKey = nil
    if step.action == "accept" and not step.mapID then
        if ns.ClearWaypoint then
            ns.ClearWaypoint()
        end
        if report and frame and frame.hint then
            if currentKind == "dungeon" then
                frame.hint:SetText(string.format(
                    L["No world start location. Check inside %s."], currentLabel))
            else
                frame.hint:SetText(L["This quest has no world start location."])
            end
        end
        return
    end
    if ns.TrackQuest then
        local ok, message = ns.TrackQuest(step.id, step.data, true)
        if not ok and report and message and frame and frame.hint then
            frame.hint:SetText(message)
        end
    end
end

local function SavePosition(panel)
    local centerX, centerY = panel:GetCenter()
    local uiX, uiY = UIParent:GetCenter()
    local scale = UIParent:GetEffectiveScale() or 1
    if not centerX or not centerY or not uiX or not uiY then
        return
    end
    local x = math.floor(((centerX - uiX) / scale) + 0.5)
    local y = math.floor(((centerY - uiY) / scale) + 0.5)
    if ns.db then
        ns.db.dungeonRouteX = x
        ns.db.dungeonRouteY = y
    end
end

local function SavedPosition()
    if type(ns.db) ~= "table" then
        return 0, 0
    end
    return ns.db.dungeonRouteX or 0, ns.db.dungeonRouteY or 0
end

local function Render()
    if not frame then
        return
    end
    local step = steps[1]
    local action = frame.action
    local panel = frame
    panel.hint:SetText(L["Re-evaluates after each quest."])

    if step then
        local label = ACTION_LABELS[step.action] or step.action
        local color = ACTION_COLORS[step.action] or { 1, 1, 1 }
        if step.action == "accept" and step.acceptable == false then
            label = L["Unavailable"]
            color = { 0.85, 0.45, 0.45 }
        end
        action:SetText(label)
        action:SetTextColor(color[1], color[2], color[3])
        panel.quest:SetText(step.title)
        panel.quest:SetTextColor(1, 0.82, 0)
        if step.locationMapID then
            SetLocationMapName(panel, step.action, step.locationMapID,
                step.locationX, step.locationY)
        elseif step.action == "accept" then
            if currentKind == "dungeon" then
                panel.location:SetText(string.format(
                    L["No world start location. Check inside %s."], currentLabel))
            else
                panel.location:SetText(L["No world start location."])
            end
        else
            panel.location:SetText(
                L["Follow the quest tracker for the objective or turn-in."])
        end
        panel.pin:SetEnabled(true)
        panel.skip:SetEnabled(true)
    else
        action:SetText(L["Route complete"])
        action:SetTextColor(0.35, 0.95, 0.45)
        panel.quest:SetText(L["No remaining steps."])
        panel.quest:SetTextColor(0.8, 0.8, 0.8)
        panel.location:SetText("")
        panel.pin:SetEnabled(false)
        panel.skip:SetEnabled(false)
    end

    panel.progress:SetMinMaxValues(0, math.max(totalSteps, 1))
    panel.progress:SetValue(completedSteps)
    local unit = totalSteps == 1 and L["quest"] or L["quests"]
    panel.progress.label:SetText(("%d / %d %s"):format(completedSteps, totalSteps, unit))
    panel.progress:SetShown(totalSteps > 0)
    panel.reset:SetEnabled(next(skipped) ~= nil)
end

local function Refresh(force)
    if not frame or not frame:IsShown() or not currentKind then
        return
    end
    local route = BuildCurrent(skipped)
    steps = route.steps
    totalSteps = route.total
    completedSteps = route.completed
    Render()

    local step = steps[1]
    if step then
        local key = StepKey(step)
        if force or key ~= autoPinnedKey then
            autoPinnedKey = key
            TrackStep(step, false)
        end
    else
        autoPinnedKey = nil
    end
end

local function ScheduleRefresh()
    if not frame or not frame:IsShown() then
        return
    end
    refreshToken = refreshToken + 1
    local token = refreshToken
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0.25, function()
            if token == refreshToken then
                Refresh(false)
            end
        end)
    else
        Refresh(false)
    end
end

local function EnsureFrame()
    if frame then
        return frame
    end
    local panel = CreateFrame("Frame", "ForeverQuestPinsQuestRoute", UIParent, "BackdropTemplate")
    panel:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    local savedX, savedY = SavedPosition()
    local finder = _G and _G["ForeverQuestPinsQuestFinder"]
    if type(ns.db) == "table" and ns.db.dungeonRouteX ~= nil then
        panel:SetPoint("CENTER", UIParent, "CENTER", savedX, savedY)
    elseif finder and finder:IsShown() then
        panel:SetPoint("TOPLEFT", finder, "TOPRIGHT", 16, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropColor(0.055, 0.045, 0.035, 1)
    panel:SetBackdropBorderColor(0.8, 0.61, 0.3, 1)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PADDING, -22)
    title:SetText("|cffffd100Dungeon|r |cff65b9ffRoute|r")
    panel.title = title

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    panel.subtitle = subtitle

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function()
        panel:Hide()
    end)

    local drag = CreateFrame("Frame", nil, panel)
    drag:SetPoint("TOPLEFT", 14, -14)
    drag:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, 0)
    drag:SetHeight(48)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePosition(panel)
    end)

    local action = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    action:SetPoint("TOPLEFT", PADDING, -82)
    panel.action = action

    local quest = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    quest:SetPoint("TOPLEFT", PADDING, -110)
    quest:SetPoint("TOPRIGHT", -PADDING, -110)
    quest:SetJustifyH("LEFT")
    quest:SetWordWrap(false)
    panel.quest = quest

    local location = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    location:SetPoint("TOPLEFT", PADDING, -138)
    location:SetPoint("TOPRIGHT", -PADDING, -138)
    location:SetJustifyH("LEFT")
    location:SetTextColor(0.72, 0.72, 0.72)
    panel.location = location

    local progress = CreateFrame("StatusBar", nil, panel, "BackdropTemplate")
    progress:SetPoint("TOPLEFT", PADDING, -168)
    progress:SetPoint("TOPRIGHT", -PADDING, -168)
    progress:SetHeight(14)
    progress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    progress:SetStatusBarColor(0.72, 0.53, 0.20)
    progress:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    progress:SetBackdropColor(0, 0, 0, 0.65)
    progress:SetBackdropBorderColor(0.8, 0.61, 0.3, 0.55)
    progress:SetMinMaxValues(0, 1)
    progress:SetValue(0)
    progress.label = progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progress.label:SetPoint("CENTER", progress, "CENTER", 0, 0)
    progress.label:SetJustifyH("CENTER")
    progress.label:SetShadowColor(0, 0, 0, 0.85)
    progress.label:SetShadowOffset(1, -1)
    panel.progress = progress

    local pin = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    pin:SetSize(100, 24)
    pin:SetPoint("BOTTOMLEFT", PADDING, 20)
    pin:SetText(L["Pin"])
    pin:SetScript("OnClick", function()
        local step = steps[1]
        if step then
            autoPinnedKey = nil
            TrackStep(step, true)
        end
    end)
    pin:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Pin"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Sets the next waypoint for the current route step."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    panel.pin = pin

    local skip = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    skip:SetSize(100, 24)
    skip:SetPoint("LEFT", pin, "RIGHT", 8, 0)
    skip:SetText(L["Skip"])
    skip:SetScript("OnClick", function()
        local step = steps[1]
        if not step then
            return
        end
        skipped[step.id] = true
        autoPinnedKey = nil
        Refresh(true)
    end)
    skip:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Skip"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Leaves this step out until you reset the route."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    skip:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    panel.skip = skip

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(100, 24)
    reset:SetPoint("LEFT", skip, "RIGHT", 8, 0)
    reset:SetText(L["Reset"])
    reset:SetScript("OnClick", function()
        skipped = {}
        autoPinnedKey = nil
        Refresh(true)
    end)
    reset:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Reset"], 1, 0.82, 0)
        GameTooltip:AddLine(L["Brings skipped steps back into the route."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    panel.reset = reset

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMRIGHT", -PADDING, 52)
    hint:SetJustifyH("RIGHT")
    hint:SetText(L["Re-evaluates after each quest."])
    hint:SetTextColor(0.55, 0.55, 0.55)
    panel.hint = hint

    panel:Hide()
    if UISpecialFrames and type(UISpecialFrames) == "table" then
        local name = "ForeverQuestPinsQuestRoute"
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
    frame = panel
    return panel
end

local function ShowRoute(kind, target, label)
    if not label then
        return false
    end
    currentKind = kind
    currentTarget = target
    currentLabel = label
    skipped = {}
    autoPinnedKey = nil
    EnsureFrame()
    frame.title:SetText(kind == "dungeon"
        and "|cffffd100Dungeon|r |cff65b9ffRoute|r"
        or "|cffffd100Zone|r |cff65b9ffRoute|r")
    frame.subtitle:SetText(label)
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
    Refresh(true)
    return true
end

function ns.QuestRoute.ShowDungeon(dungeonName)
    local dungeon = ns.DungeonChains
        and ns.DungeonChains.dungeons
        and ns.DungeonChains.dungeons[dungeonName]
    if not dungeon then
        return false
    end
    return ShowRoute("dungeon", dungeonName, dungeonName)
end

function ns.QuestRoute.ShowZone(mapID)
    if type(mapID) ~= "number" then
        return false
    end
    local zoneIDs = ns.QuestFinder
        and ns.QuestFinder.ZoneQuestIDs
        and ns.QuestFinder.ZoneQuestIDs(mapID)
        or {}
    if #zoneIDs == 0 then
        return false
    end
    return ShowRoute("zone", mapID, MapName(mapID))
end

function ns.QuestRoute.Show(dungeonName)
    return ns.QuestRoute.ShowDungeon(dungeonName)
end

function ns.QuestRoute.Hide()
    if frame then
        frame:Hide()
    end
end

function ns.QuestRoute.IsShown()
    return frame and frame:IsShown() or false
end

function ns.QuestRoute.Current()
    return steps[1]
end

ns.QuestRoute.Build = BuildDungeon
ns.QuestRoute.BuildDungeon = BuildDungeon
ns.QuestRoute.BuildZone = BuildZone

if type(CreateFrame) == "function" then
    local events = CreateFrame("Frame")
    local watched = {
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "QUEST_LOG_UPDATE",
        "PLAYER_REGEN_ENABLED",
    }
    for i = 1, #watched do
        pcall(events.RegisterEvent, events, watched[i])
    end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingPinKey then
                pendingPinKey = nil
                Refresh(true)
            end
            return
        end
        ScheduleRefresh()
    end)
end
