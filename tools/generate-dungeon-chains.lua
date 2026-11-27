-- Regenerate Database/DungeonChains.lua from a ForeverDungeonJournal install.
--
-- Usage:
--   luajit tools/generate-dungeon-chains.lua <ForeverDungeonJournal path> [output]
--
-- The journal's data files are loaded in the same order the addon uses, with a
-- stub namespace, so the generated table follows the installed journal version
-- without copying UI code into this addon.

local fdjPath = assert(arg[1], "ForeverDungeonJournal path is required")
local outputPath = arg[2] or "Database/DungeonChains.lua"
if fdjPath:sub(-1) ~= "/" then
    fdjPath = fdjPath .. "/"
end

local FDJ = {
    Constants = {
        ALBA_FAIRMOON_LOCATION = "Alba Fairmoon, Sentinel Hill inn, Westfall",
    },
}
-- QuestUpdates.lua also carries required chains and start maps, and it touches
-- many journal-only tables that this generator does not need. Create empty
-- tables on demand and give its event-frame setup a harmless stub.
setmetatable(FDJ, {
    __index = function(target, key)
        local value = {}
        rawset(target, key, value)
        return value
    end,
})
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

local function Run(relative)
    local path = fdjPath .. relative
    local chunk = assert(loadfile(path))
    chunk("ForeverDungeonJournal", FDJ)
end

Run("Data/Dungeons.lua")
Run("Data/QuestChains.lua")
Run("Data/QuestUpdates.lua")

local function ReadVersion()
    local file = assert(io.open(fdjPath .. "ForeverDungeonJournal.toc", "r"))
    local version = "unknown"
    for line in file:lines() do
        local value = line:match("^## Version:%s*(.+)$")
        if value then
            version = value:gsub("%s+$", "")
            break
        end
    end
    file:close()
    return version
end

local function Quote(value)
    return string.format("%q", tostring(value))
end

local function Number(value)
    return string.format("%.2f", value)
end

local function Coord(map)
    if type(map) ~= "table"
        or type(map.mapID) ~= "number"
        or type(map.x) ~= "number"
        or type(map.y) ~= "number" then
        return nil
    end
    return string.format("mapID = %d, x = %s, y = %s",
        map.mapID, Number(map.x * 100), Number(map.y * 100))
end

local function StartMap(questID)
    local details = FDJ.QUEST_PREREQ_DETAILS and FDJ.QUEST_PREREQ_DETAILS[questID]
    if details and details.map then
        return details.map
    end
    return FDJ.QUEST_START_MAPS and FDJ.QUEST_START_MAPS[questID]
end

local questIndex = {}

local function QuestRef(questID)
    questIndex[questID] = questIndex[questID] or { dungeons = {}, chains = {} }
    return questIndex[questID]
end

local function AddUnique(list, value)
    for i = 1, #list do
        if list[i] == value then
            return
        end
    end
    list[#list + 1] = value
end

local dungeons = {}
local dungeonNames = {}
for name, dungeon in pairs(FDJ.DB or {}) do
    if type(dungeon) == "table" and type(dungeon.quests) == "table" then
        dungeonNames[#dungeonNames + 1] = name
    end
end
table.sort(dungeonNames)

for _, name in ipairs(dungeonNames) do
    local dungeon = FDJ.DB[name]
    local quests = {}
    for _, quest in ipairs(dungeon.quests) do
        local questID = tonumber(quest.id)
        if questID then
            local chain = FDJ.QUEST_PREREQ_CHAINS and FDJ.QUEST_PREREQ_CHAINS[questID]
            local steps = {}
            if chain then
                for _, step in ipairs(chain) do
                    local stepID = tonumber(step.id)
                    if stepID and stepID ~= questID then
                        steps[#steps + 1] = {
                            id = stepID,
                            name = step.name or ("Quest " .. tostring(stepID)),
                            level = step.level,
                            startsInDungeon = step.startsInDungeon and true or nil,
                            needsDungeon = step.needsDungeon and true or nil,
                            map = StartMap(stepID),
                        }
                    end
                end
            end
            local targetIndex = #steps + 1
            local ref = QuestRef(questID)
            AddUnique(ref.dungeons, name)
            if #steps > 0 then
                ref.chains[#ref.chains + 1] = {
                    dungeon = name,
                    index = targetIndex,
                    total = targetIndex,
                    target = questID,
                }
            end
            for index, step in ipairs(steps) do
                local stepRef = QuestRef(step.id)
                AddUnique(stepRef.dungeons, name)
                stepRef.chains[#stepRef.chains + 1] = {
                    dungeon = name,
                    index = index,
                    total = targetIndex,
                    target = questID,
                }
            end
            quests[#quests + 1] = {
                id = questID,
                name = quest.name or ("Quest " .. tostring(questID)),
                level = quest.level,
                faction = quest.faction,
                map = StartMap(questID),
                chain = steps,
            }
        end
    end
    table.sort(quests, function(a, b)
        if a.name == b.name then
            return a.id < b.id
        end
        return a.name < b.name
    end)
    dungeons[name] = {
        name = name,
        level = dungeon.level,
        quests = quests,
    }
end

local file = assert(io.open(outputPath, "w"))
local function Write(line)
    file:write(line or "", "\n")
end

Write("-- AUTO-GENERATED FILE")
Write("-- DO NOT EDIT MANUALLY")
Write("-- Source: ForeverDungeonJournal " .. ReadVersion())
Write("-- Generated by tools/generate-dungeon-chains.lua")
Write("--")
Write("-- Dungeon quests and the required pre-quest chains from")
Write("-- ForeverDungeonJournal. Coordinates use Questie's 0-100 UiMapID space.")
Write("")
Write("local ADDON_NAME, ns = ...")
Write("ns.DungeonChains = {")
Write("\tsource = " .. Quote("ForeverDungeonJournal " .. ReadVersion()) .. ",")
Write("\torder = {")
for _, name in ipairs(dungeonNames) do
    Write("\t\t" .. Quote(name) .. ",")
end
Write("\t},")
Write("\tdungeons = {")
for _, name in ipairs(dungeonNames) do
    local dungeon = dungeons[name]
    Write("\t\t[" .. Quote(name) .. "] = {")
    Write("\t\t\tname = " .. Quote(dungeon.name) .. ",")
    if dungeon.level then
        Write("\t\t\tlevel = " .. Quote(dungeon.level) .. ",")
    end
    Write("\t\t\tquests = {")
    for _, quest in ipairs(dungeon.quests) do
        local fields = {
            "id = " .. tostring(quest.id),
            "name = " .. Quote(quest.name),
        }
        if quest.level then fields[#fields + 1] = "level = " .. tostring(quest.level) end
        if quest.faction and quest.faction ~= "Both" then
            fields[#fields + 1] = "faction = " .. Quote(quest.faction)
        end
        local coord = Coord(quest.map)
        if coord then fields[#fields + 1] = coord end
        Write("\t\t\t\t{ " .. table.concat(fields, ", ") .. ",")
        if #quest.chain > 0 then
            Write("\t\t\t\t  chain = {")
            for _, step in ipairs(quest.chain) do
                local stepFields = {
                    "id = " .. tostring(step.id),
                    "name = " .. Quote(step.name),
                }
                if step.level then stepFields[#stepFields + 1] = "level = " .. tostring(step.level) end
                if step.startsInDungeon then stepFields[#stepFields + 1] = "startsInDungeon = true" end
                if step.needsDungeon then stepFields[#stepFields + 1] = "needsDungeon = true" end
                local stepCoord = Coord(step.map)
                if stepCoord then stepFields[#stepFields + 1] = stepCoord end
                Write("\t\t\t\t    { " .. table.concat(stepFields, ", ") .. " },")
            end
            Write("\t\t\t\t  },")
        end
        Write("\t\t\t\t},")
    end
    Write("\t\t\t},")
    Write("\t\t},")
end
Write("\t},")
Write("\tquests = {")
local questIDs = {}
for questID in pairs(questIndex) do
    questIDs[#questIDs + 1] = questID
end
table.sort(questIDs)
for _, questID in ipairs(questIDs) do
    local ref = questIndex[questID]
    table.sort(ref.chains, function(a, b)
        if a.dungeon ~= b.dungeon then return a.dungeon < b.dungeon end
        if a.index ~= b.index then return a.index < b.index end
        return (a.target or 0) < (b.target or 0)
    end)
    local quotedDungeons = {}
    for i = 1, #ref.dungeons do quotedDungeons[i] = Quote(ref.dungeons[i]) end
    local chainParts = {}
    for i = 1, #ref.chains do
        local chain = ref.chains[i]
        chainParts[i] = string.format(
            "{ dungeon = %s, index = %d, total = %d, target = %d }",
            Quote(chain.dungeon), chain.index, chain.total, chain.target)
    end
    Write("\t\t[" .. tostring(questID) .. "] = { dungeons = { "
        .. table.concat(quotedDungeons, ", ") .. " }, chains = { "
        .. table.concat(chainParts, ", ") .. " } },")
end
Write("\t},")
Write("}")
file:close()
