local _, ns = ...

-- Questie sends quest links as plain text, for example
--   [[53] Chasing A-Me 01 (4243)]
-- because the chat server strips addon hyperlinks. Turn that text into the
-- game's own quest hyperlink before the chat frame draws it. Existing
-- hyperlinks are copied through unchanged.

local LEVEL_PATTERN = "%[%[(%d+)%]%s*([^%[%]]-)%s*%((%d+)%)%]"
local PLAIN_PATTERN = "%[([^%[%]]-)%s*%((%d+)%)%]"
local EVENTS = {
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function QuestieLoaded()
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "Questie")
        if ok and loaded then
            return true
        end
    end
    if type(IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(IsAddOnLoaded, "Questie")
        if ok and loaded then
            return true
        end
    end
    return _G.Questie ~= nil or _G.QuestieLink ~= nil
end

local function Enabled()
    return ns.GetOption and ns.GetOption("translateQuestieLinks") ~= false
end

local function KnownTitle(questID)
    local data = ns.Quests and ns.Quests[questID]
    if data and type(data.title) == "string" and data.title ~= "" then
        return data.title
    end
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and type(title) == "string" and title ~= "" then
            return title
        end
    end
    return ns.GetQuestTitle and ns.GetQuestTitle(questID, true) or nil
end

local function QuestLink(questID, level, name)
    if type(questID) ~= "number" or type(name) ~= "string" or name == "" then
        return nil
    end
    level = tonumber(level) or 0
    return "|cffffd100|Hquest:" .. questID .. ":" .. level .. "|h[" .. name .. "]|h|r"
end

local function PlainText(text)
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function TranslateHyperlink(data, text)
    local questID, level
    local id, levelText = data:match("^quest:(%d+):(%d+)")
    if not id then
        id, levelText = data:match("^questie:(%d+):(%d+)")
    end
    if not id then
        id = data:match("^quest:(%d+)") or data:match("^questie:(%d+)")
    end
    if id then
        questID = tonumber(id)
        level = tonumber(levelText)
    end
    if not questID then
        return nil
    end

    local plain = PlainText(text)
    local _, name = plain:match("^%[%[(%d+)%]%s*(.-)%s*%(%d+%)%]$")
    if not name then
        name = plain:match("^%[(.-)%s*%(%d+%)%]$")
    end
    if not name then
        if data:sub(1, 8) ~= "questie:" then
            return nil
        end
        name = KnownTitle(questID)
    end
    if not name or name == "" then
        return nil
    end
    if not level or level <= 0 then
        local db = ns.Quests and ns.Quests[questID]
        level = db and db.minLevel or 0
    end
    return QuestLink(questID, level, name)
end

local function TranslatePlain(segment)
    -- The plain form excludes brackets in the name, so it cannot match the
    -- level-prefixed form. Run it first, then the level-prefixed form.
    segment = segment:gsub(PLAIN_PATTERN, function(name, questID)
        questID = tonumber(questID)
        if not questID then
            return nil
        end
        local title = KnownTitle(questID)
        if title ~= name then
            return nil
        end
        local data = ns.Quests and ns.Quests[questID]
        return QuestLink(questID, data and data.minLevel or 0, name) or nil
    end)
    segment = segment:gsub(LEVEL_PATTERN, function(level, name, questID)
        questID = tonumber(questID)
        if not questID then
            return nil
        end
        return QuestLink(questID, level, name) or nil
    end)
    return segment
end

local function Translate(message)
    if type(message) ~= "string" then
        return message
    end
    if not message:find("%(%d+%)%]") and not message:find("|Hquestie:", 1, true) then
        return message
    end
    local out = {}
    local position = 1
    while true do
        local hyperlink = message:find("|H", position, true)
        if not hyperlink then
            out[#out + 1] = TranslatePlain(message:sub(position))
            break
        end
        out[#out + 1] = TranslatePlain(message:sub(position, hyperlink - 1))
        local textStart = message:find("|h", hyperlink, true)
        if not textStart then
            out[#out + 1] = message:sub(hyperlink)
            break
        end
        local textEnd = message:find("|h", textStart + 2, true)
        if not textEnd then
            out[#out + 1] = message:sub(hyperlink)
            break
        end
        local data = message:sub(hyperlink + 2, textStart - 1)
        local text = message:sub(textStart + 2, textEnd - 1)
        out[#out + 1] = TranslateHyperlink(data, text) or message:sub(hyperlink, textEnd + 1)
        position = textEnd + 2
    end
    return table.concat(out)
end

local function Filter(_, _, message, ...)
    if not Enabled() or QuestieLoaded() then
        return false
    end
    local translated = Translate(message)
    if translated ~= message then
        return false, translated, ...
    end
    return false
end

ns.ChatQuestLinks = {
    Translate = Translate,
    QuestieLoaded = QuestieLoaded,
    Filter = Filter,
}

if type(ChatFrame_AddMessageEventFilter) == "function" then
    for i = 1, #EVENTS do
        ChatFrame_AddMessageEventFilter(EVENTS[i], Filter)
    end
end
