ns = { Quests = {}, ByMap = {}, options = {}, titles = {}, levels = {}, active = {}, ready = {} }
ns.GetOption = function(key) return ns.options[key] end
ns.GetQuestTitle = function(id) return ns.titles[id] end
ns.GetQuestDifficultyLevel = function(id) return ns.levels[id] end
ns.IsOnQuest = function(id) return ns.active[id] end
ns.IsQuestAvailable = function(id) return not ns.active[id] and not ns.completed[id] end
ns.completed = {}
C_QuestLog = { ReadyForTurnIn = function(id) return ns.ready[id] end }
chat = {}
print = function(...)
    local values = {}
    for index=1,select('#', ...) do values[index] = tostring(select(index, ...)) end
    chat[#chat + 1] = table.concat(values, ' ')
end
