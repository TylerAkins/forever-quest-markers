-- Regenerate Database/DungeonRoutes.lua from the Dungeon_Quests_Forever
-- dungeon and attunement guides.
--
-- Usage:
--   luajit tools/generate-dungeon-routes.lua <Dungeon_Quests_Forever path> [output]
--
-- The guide supplies step order, quest IDs, NPC coordinates, and faction flags.
-- Quest titles come from Database/ForeverQuests.lua. Objective text is
-- summarized by this project so the generated route does not copy guide prose.

local guideRoot = assert(arg[1], "Dungeon_Quests_Forever path is required")
local outputPath = arg[2] or "Database/DungeonRoutes.lua"
if guideRoot:sub(-1) ~= "/" then
    guideRoot = guideRoot .. "/"
end

local function Make(kind, quest, npcKey, text, opts)
    local step = opts or {}
    step.type, step.quest, step.npc, step.text = kind, quest, npcKey, text or step.text
    return step
end

local function NewNamespace()
    local ns = { NPCS = {} }
    setmetatable(ns, {
        __index = function(target, key)
            local value = {}
            rawset(target, key, value)
            return value
        end,
    })
    ns.L = function(_, english) return english end
    ns.Accept = function(quest, npc, opts) return Make("accept", quest, npc, nil, opts) end
    ns.TurnIn = function(quest, npc, opts) return Make("turnin", quest, npc, nil, opts) end
    ns.Talk = function(quest, npc, text, opts) return Make("talk", quest, npc, text, opts) end
    ns.Do = function(quest, text, opts) return Make("do", quest, nil, text, opts) end
    return ns
end

local sharedPath = guideRoot .. "Guides/Dungeons/30-46_ScarletMonasteryShared.lua"
local guidePaths = {}
local pipe = assert(io.popen('ls "' .. guideRoot .. 'Guides/Dungeons"/*.lua'))
for line in pipe:lines() do
    if not line:match("ScarletMonasteryShared") then
        guidePaths[#guidePaths + 1] = line
    end
end
pipe:close()
guidePaths[#guidePaths + 1] = guideRoot .. "Guides/Attunements/1_UpperBlackrockSpire.lua"
guidePaths[#guidePaths + 1] = guideRoot .. "Guides/Attunements/3_OnyxiasLair.lua"

-- Load all guides into one namespace, matching the source addon. Shared NPC
-- keys such as varimathras are defined by one guide and used by another.
local ns = NewNamespace()
ns.RegisterDungeon = function() end
assert(loadfile(sharedPath))("DungeonQuestsForever", ns)

local guides = {}
for _, path in ipairs(guidePaths) do
    local captured
    ns.RegisterDungeon = function(_, key, build)
        local ok, data = pcall(build)
        captured = { key = key, ok = ok, data = data }
    end
    assert(loadfile(path))("DungeonQuestsForever", ns)
    if not captured or not captured.ok then
        error("guide failed to build: " .. path .. ": " .. tostring(captured and captured.data))
    end
    guides[#guides + 1] = {
        path = path,
        key = captured.key,
        name = captured.data.name,
        steps = captured.data.steps or {},
    }
end

local aliases = {
    ["The Hall of Thanes"] = { "Hall of Thanes" },
    ["Dire Maul - East"] = { "Dire Maul: East" },
    ["Dire Maul - North"] = { "Dire Maul: North" },
    ["Dire Maul - West"] = { "Dire Maul: West" },
    ["Scarlet Monastery - Graveyard"] = { "Scarlet Monastery: Graveyard" },
    ["Scarlet Monastery - Library"] = { "Scarlet Monastery: Library" },
    ["Scarlet Monastery - Armory"] = { "Scarlet Monastery: Armory" },
    ["Scarlet Monastery - Cathedral"] = { "Scarlet Monastery: Cathedral" },
    ["Stratholme"] = { "Stratholme: Living", "Stratholme: Undead" },
    ["Onyxia's Lair"] = { "Onyxia Attunement" },
    ["Upper Blackrock Spire key"] = { "Upper Blackrock Spire" },
}

local chains = {}
assert(loadfile("Database/DungeonChains.lua"))("ForeverQuestPins", chains)
local known = {}
for _, name in ipairs(chains.DungeonChains.order) do
    known[name] = true
end

-- Short objective summaries written for this addon. BRD has hand-written
-- summaries; every other Do step gets a short generated summary below.
local ROUTE_TEXT = {
    [3442] = "Gather 4 Hearts of Flame and 4 Golem Oil globes.",
    [3443] = "Gather 8 Thorium Plated Daggers.",
    [3452] = "Find a Symbol of Ragnaros.",
    [3463] = "Burn the four sentry towers with the Torch of Retribution.",
    [3701] = "Recover the Thaurissan relic information in the Burning Steppes.",
    [3906] = "Kill Overmaster Pyron at the Blackrock Mountain quarry.",
    [4022] = "Present the Black Dragonflight Molt to Cyrus Therepentous.",
    [4023] = "Prove your worth to Cyrus Therepentous.",
    [4061] = "Recover 10 Fractured Elemental Shards in the Burning Steppes.",
    [4182] = "Kill 15 Black Broodlings, 10 Black Dragonspawn, 4 Black Wyrmkin, and 1 Black Drake.",
    [4262] = "Kill Overmaster Pyron.",
    [8945] = "Rescue Ysida Harmon from Baron Rivendare in Stratholme.",
    [8947] = "Gather the crafting reagents for Anthion Harmon.",
    [8949] = "Collect 25 Ogre Warbeads in Dire Maul or Blackrock Spire.",
    [8950] = "Gather the reagents for Falrin Treeshaper in Dire Maul.",
    [3907] = "Kill Lord Incendius in Blackrock Depths.",
    [4024] = "Kill Bael'Gar in Blackrock Depths.",
    [4063] = "Kill Golem Lord Argelmach and gather 10 Intact Elemental Cores.",
    [4081] = "Kill Dark Iron dwarves in Blackrock Depths.",
    [4083] = "Recover the Spectral Chalice.",
    [4123] = "Deliver the Heart of the Mountain to Maxwort Uberglint.",
    [4201] = "Gather 4 Gromsblood, 10 Giant Silver Veins, and Nagmara's Filled Vial.",
    [4263] = "Kill Lord Incendius in Blackrock Depths.",
    [4286] = "Recover 20 Dark Iron Fanny Packs in Blackrock Depths.",
    [7201] = "Recover 10 Essence of the Elements in Blackrock Depths.",
    [9015] = "Place the Banner of Provocation in the Ring of the Law.",
    [3802] = "Kill Fineous Darkvire, recover Ironfel, and use it at the Shrine of Thaurissan.",
    [4003] = "Kill Emperor Dagran Thaurissan and free Princess Moira Bronzebeard.",
    [4082] = "Kill high-ranking Dark Iron officials in Blackrock Depths.",
    [4121] = "Escort Grark Lorkrub from the Burning Steppes to the Searing Gorge.",
    [4126] = "Deliver the recipe to Ragnar Thunderbrew in Kharanos.",
    [4132] = "Kill General Angerforge in Blackrock Depths.",
    [4134] = "Deliver the recipe to Vivian Lagrave in Kargath.",
    [4136] = "Take Ribbly's Head to Yuka Screwspigot.",
    [4282] = "Find Marshal Windsor's lost information.",
    [4362] = "Rescue Princess Moira Bronzebeard in Blackrock Depths.",
}

local function StepText(step)
    if step.type == "do" then
        return ROUTE_TEXT[step.quest] or "Complete the quest objective."
    end
    if step.type == "accept" and step.text then
        return "Use or find the quest starter."
    end
    if step.type == "turnin" and step.text then
        return "Use the quest object to turn in."
    end
    return nil
end

local routes = {}
local function Route(target)
    local route = routes[target]
    if not route then
        route = { steps = {}, sources = {} }
        routes[target] = route
    end
    return route
end

local function AddGuide(guide, target, prepend)
    local route = Route(target)
    route.sources[#route.sources + 1] = guide.path:match("[^/]+$")
    local function usable(step)
        return type(step.quest) == "number" and step.quest > 0
    end
    if prepend then
        local combined = {}
        for _, step in ipairs(guide.steps) do
            if usable(step) then
                combined[#combined + 1] = step
            end
        end
        for _, step in ipairs(route.steps) do
            combined[#combined + 1] = step
        end
        route.steps = combined
    else
        for _, step in ipairs(guide.steps) do
            if usable(step) then
                route.steps[#route.steps + 1] = step
            end
        end
    end
end

for _, guide in ipairs(guides) do
    local targets = aliases[guide.name]
    if not targets then
        if known[guide.name] then
            targets = { guide.name }
        else
            error("no dungeon mapping for guide " .. guide.name .. " (" .. guide.path .. ")")
        end
    end
    local prepend = guide.name == "Upper Blackrock Spire key"
    for _, target in ipairs(targets) do
        if not known[target] then
            error("unknown DungeonChains name " .. target .. " for guide " .. guide.name)
        end
        AddGuide(guide, target, prepend)
    end
end

local function Quote(value)
    if value == nil then
        return "nil"
    end
    if type(value) == "number" then
        return tostring(value)
    end
    local text = tostring(value)
    text = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
    return '"' .. text .. '"'
end

local function SortedKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local lines = {
    "-- AUTO-GENERATED FILE",
    "-- DO NOT EDIT MANUALLY",
    "-- Source: Dungeon_Quests_Forever Guides/Dungeons and Guides/Attunements (UBRS key, Onyxia)",
    "-- Generated by tools/generate-dungeon-routes.lua",
    "--",
    "-- Step order, NPC coordinates, and faction flags come from the guide.",
    "-- Quest titles come from the addon quest database.",
    "-- NPC names are resolved from the client at runtime.",
    "-- Objective text is summarized by this project, not copied from the guide.",
    "",
    "local ADDON_NAME, ns = ...",
    "ns.DungeonRoutes = {",
}
for _, target in ipairs(SortedKeys(routes)) do
    local route = routes[target]
    lines[#lines + 1] = "    [" .. Quote(target) .. "] = {"
    lines[#lines + 1] = '        source = "Dungeon_Quests_Forever",'
    lines[#lines + 1] = "        sources = {"
    for _, source in ipairs(route.sources) do
        lines[#lines + 1] = "            " .. Quote(source) .. ","
    end
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "        steps = {"
    local referenced = {}
    for _, step in ipairs(route.steps) do
        local parts = {
            "type = " .. Quote(step.type),
            "quest = " .. Quote(step.quest),
        }
        if step.npc then
            parts[#parts + 1] = "npc = " .. Quote(step.npc)
            referenced[step.npc] = true
        end
        if step.faction then
            parts[#parts + 1] = "faction = " .. Quote(step.faction)
        end
        local text = StepText(step)
        if text then
            parts[#parts + 1] = "text = " .. Quote(text)
        end
        if step.targets and #step.targets > 0 then
            local targets = {}
            for _, key in ipairs(step.targets) do
                targets[#targets + 1] = Quote(key)
                referenced[key] = true
            end
            parts[#parts + 1] = "targets = { " .. table.concat(targets, ", ") .. " }"
        end
        if step.map and step.x and step.y then
            parts[#parts + 1] = "map = " .. Quote(step.map)
            parts[#parts + 1] = "x = " .. Quote(step.x)
            parts[#parts + 1] = "y = " .. Quote(step.y)
        end
        lines[#lines + 1] = "            { " .. table.concat(parts, ", ") .. " },"
    end
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "        npcs = {"
    for _, key in ipairs(SortedKeys(referenced)) do
        local npc = ns.NPCS[key]
        if npc then
            local parts = {
                "id = " .. Quote(npc.id),
            }
            if npc.map then
                parts[#parts + 1] = "map = " .. Quote(npc.map)
            end
            if npc.x then
                parts[#parts + 1] = "x = " .. Quote(npc.x)
            end
            if npc.y then
                parts[#parts + 1] = "y = " .. Quote(npc.y)
            end
            lines[#lines + 1] = "            " .. key .. " = { " .. table.concat(parts, ", ") .. " },"
        end
    end
    lines[#lines + 1] = "        },"
    lines[#lines + 1] = "    },"
end
lines[#lines + 1] = "}"
lines[#lines + 1] = ""

local file = assert(io.open(outputPath, "w"))
file:write(table.concat(lines, "\n"))
file:close()

local routeCount = 0
for _ in pairs(routes) do routeCount = routeCount + 1 end
print(("Wrote %s with %d dungeon routes"):format(outputPath, routeCount))
