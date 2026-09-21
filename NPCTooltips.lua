local ADDON_NAME, ns = ...

ns.NPCTooltips = {}
local Tooltips = ns.NPCTooltips
local starters
local initialized, rebuilding, probeArmed = false, false, false

local function Print(message)
    print("|cffffd100Forever Quest Pins:|r " .. tostring(message))
end

local function NPCID(unit)
    local guid = unit and UnitGUID and UnitGUID(unit)
    if type(guid) == "string" then
        local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)-")
            or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)-")
        return tonumber(id)
    end
end

local function Index(index, npcID, questID)
    if not npcID then return end
    index[npcID] = index[npcID] or {}
    index[npcID][questID] = true
end

function Tooltips:InvalidateIndex()
    starters = nil
end

local function BuildIndex()
    if starters then return end
    starters = {}
    for questID, data in pairs(ns.Quests or {}) do
        Index(starters, data.qg, questID)
        for _, npcID in ipairs(data.qgs or {}) do
            Index(starters, npcID, questID)
        end
    end
end

function Tooltips:GetRows(npcID)
    BuildIndex()
    local rows = {}
    for questID in pairs(starters[npcID] or {}) do
        local data = ns.Quests[questID]
        if ns.IsQuestAvailable(questID, data) then
            local title = ns.GetQuestTitle(questID)
            if title then
                rows[#rows + 1] = {
                    id = questID,
                    title = title,
                    level = ns.GetQuestDifficultyLevel(questID),
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.level ~= b.level then
            return (a.level or math.huge) < (b.level or math.huge)
        end
        return a.id < b.id
    end)
    return rows
end

function Tooltips:Show(tooltip)
    if tooltip ~= GameTooltip or not ns.GetOption("showNPCTooltips") then return end
    local _, unit = tooltip:GetUnit()
    local npcID = NPCID(unit)
    if not npcID or tooltip.fqpQuestRows then return end
    local rows = self:GetRows(npcID)
    if #rows == 0 then return end
    tooltip.fqpQuestRows = true
    for _, row in ipairs(rows) do
        local title = row.level and ("[%d] %s"):format(row.level, row.title) or row.title
        tooltip:AddLine("! " .. title, 1, 0.82, 0, true)
    end
    tooltip:Show()
end

local function SafeValue(value)
    if type(value) == "table" then return "<table>" end
    local ok, text = pcall(tostring, value)
    return ok and text or "<unreadable>"
end

local function SortedKeys(value)
    local keys = {}
    local ok = pcall(function()
        for key in pairs(value or {}) do
            keys[#keys + 1] = key
        end
    end)
    if not ok then return keys end
    table.sort(keys, function(a, b) return SafeValue(a) < SafeValue(b) end)
    return keys
end

local function Fields(value)
    local fields = {}
    for _, key in ipairs(SortedKeys(value)) do
        local ok, fieldValue = pcall(function() return value[key] end)
        fields[#fields + 1] = SafeValue(key) .. "=" .. (ok and SafeValue(fieldValue) or "<unreadable>")
    end
    return table.concat(fields, ", ")
end

local function PrintNested(label, value)
    if type(value) ~= "table" then return end
    for _, key in ipairs(SortedKeys(value)) do
        local ok, nested = pcall(function() return value[key] end)
        if ok and type(nested) == "table" then
            print(("    %s[%s]: %s"):format(label, SafeValue(key), Fields(nested)))
        end
    end
end

function Tooltips:ArmProbe()
    probeArmed = true
    Print("Hover probe armed. Move the cursor onto an NPC; the next unit tooltip will be reported once.")
end

function Tooltips:Probe(tooltip, tooltipData)
    if not probeArmed or tooltip ~= GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    local npcID = NPCID(unit)
    if not npcID then return end
    probeArmed = false

    if not tooltipData and C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if ok then tooltipData = data end
    end

    local related = "unavailable"
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        local ok, result = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok then related = SafeValue(result) end
    end

    Print(("Hover probe NPC %d, unit=%s, relatedToActiveQuest=%s"):format(
        npcID, tostring(unit), related
    ))
    if type(tooltipData) ~= "table" then
        print("  No structured unit tooltip data was returned.")
        return
    end
    print("  tooltip: " .. Fields(tooltipData))
    local lines = tooltipData.lines
    if type(lines) ~= "table" then
        print("  No structured tooltip lines were returned.")
        return
    end
    local count = 0
    local ok = pcall(function()
        for index, line in ipairs(lines) do
            count = count + 1
            print(("  line %d: %s"):format(index, Fields(line)))
            PrintNested("args", line.args)
        end
    end)
    if not ok then
        print("  Structured tooltip lines could not be read safely.")
    elseif count == 0 then
        print("  No structured tooltip lines were returned.")
    end
end

function Tooltips:Refresh()
    local tooltip = GameTooltip
    if rebuilding or not tooltip or not tooltip:IsShown() then return end
    local _, unit = tooltip:GetUnit()
    if not NPCID(unit) then return end
    rebuilding = true
    tooltip:ClearLines()
    tooltip:SetUnit(unit)
    rebuilding = false
end

function Tooltips:Initialize()
    if initialized or not GameTooltip then return end
    initialized = true
    GameTooltip:HookScript("OnTooltipCleared", function(tooltip) tooltip.fqpQuestRows = nil end)
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, tooltipData)
            self:Probe(tooltip, tooltipData)
            self:Show(tooltip)
        end)
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            self:Probe(tooltip)
            self:Show(tooltip)
        end)
    else
        hooksecurefunc(GameTooltip, "SetUnit", function(tooltip)
            self:Probe(tooltip)
            self:Show(tooltip)
        end)
    end
end
