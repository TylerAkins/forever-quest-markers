-- Regenerate Database/DungeonRoutes.lua from a Dungeon_Quests_Forever guide.
--
-- Usage:
--   luajit tools/generate-dungeon-routes.lua <Dungeon_Quests_Forever path> [output]
--
-- Only Blackrock Depths is generated for now. More dungeon guides can be added
-- here as they are ready.

local guideRoot = assert(arg[1], "Dungeon_Quests_Forever path is required")
local outputPath = arg[2] or "Database/DungeonRoutes.lua"
if guideRoot:sub(-1) ~= "/" then
    guideRoot = guideRoot .. "/"
end

local guidePath = guideRoot .. "Guides/Dungeons/52-60_BlackrockDepths.lua"

local ns = { NPCS = {} }
ns.L = function(_, english) return english end
local function Make(kind, quest, npcKey, text, opts)
    local step = opts or {}
    step.type, step.quest, step.npc, step.text = kind, quest, npcKey, text or step.text
    return step
end
ns.Accept = function(quest, npc, opts) return Make("accept", quest, npc, nil, opts) end
ns.TurnIn = function(quest, npc, opts) return Make("turnin", quest, npc, nil, opts) end
ns.Talk = function(quest, npc, text, opts) return Make("talk", quest, npc, text, opts) end
ns.Do = function(quest, text, opts) return Make("do", quest, nil, text, opts) end

local data
ns.RegisterDungeon = function(_, _, build)
    data = build()
end

assert(loadfile(guidePath))("DungeonQuestsForever", ns)

-- Short objective summaries written for this addon. They are intentionally
-- paraphrased so the generated route does not copy the source guide's prose.
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

local function SimplifyItemText(text)
    if not text then
        return nil
    end
    text = text:gsub("^Object:%s*", ""):gsub("^Quest item:%s*", "")
    return text
end

for _, step in ipairs(data.steps) do
    if step.type == "do" and not ROUTE_TEXT[step.quest] then
        error("missing route text for quest " .. tostring(step.quest))
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

local referenced = {}
local function Mark(key)
    if key then
        referenced[key] = true
    end
end
for _, step in ipairs(data.steps) do
    Mark(step.npc)
    for _, target in ipairs(step.targets or {}) do
        Mark(target)
    end
end

local lines = {
    "-- AUTO-GENERATED FILE",
    "-- DO NOT EDIT MANUALLY",
    "-- Source: Dungeon_Quests_Forever Guides/Dungeons/52-60_BlackrockDepths.lua",
    "-- Generated by tools/generate-dungeon-routes.lua",
    "--",
    "-- Blackrock Depths guide steps. Other dungeons are not generated yet.",
    "-- Step order and NPC coordinates come from the guide. Quest titles come from the addon quest database.",
    "-- Objective text is summarized by this project, not copied from the guide.",
    "",
    "local ADDON_NAME, ns = ...",
    "ns.DungeonRoutes = {",
    '    ["Blackrock Depths"] = {',
    '        source = "Dungeon_Quests_Forever",',
    "        steps = {",
}
for _, step in ipairs(data.steps) do
    local parts = {
        "type = " .. Quote(step.type),
        "quest = " .. Quote(step.quest),
    }
    if step.npc then
        parts[#parts + 1] = "npc = " .. Quote(step.npc)
    end
    if step.faction then
        parts[#parts + 1] = "faction = " .. Quote(step.faction)
    end
    local text
    if step.type == "do" then
        text = ROUTE_TEXT[step.quest]
    else
        text = SimplifyItemText(step.text)
    end
    if text then
        parts[#parts + 1] = "text = " .. Quote(text)
    end
    if step.targets and #step.targets > 0 then
        local targets = {}
        for _, target in ipairs(step.targets) do
            targets[#targets + 1] = Quote(target)
        end
        parts[#parts + 1] = "targets = { " .. table.concat(targets, ", ") .. " }"
    end
    lines[#lines + 1] = "            { " .. table.concat(parts, ", ") .. " },"
end
lines[#lines + 1] = "        },"
lines[#lines + 1] = "        npcs = {"
local npcKeys = {}
for key in pairs(referenced) do
    npcKeys[#npcKeys + 1] = key
end
table.sort(npcKeys)
for _, key in ipairs(npcKeys) do
    local npc = ns.NPCS[key]
    if npc then
        local parts = {
            "id = " .. Quote(npc.id),
            "name = " .. Quote(npc.name),
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
lines[#lines + 1] = "}"
lines[#lines + 1] = ""

local file = assert(io.open(outputPath, "w"))
file:write(table.concat(lines, "\n"))
file:close()
print("Wrote " .. outputPath .. " from " .. guidePath)
