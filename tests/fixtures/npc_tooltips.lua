ns = { Quests = {}, options = { showNPCTooltips = true }, titles = {}, levels = {}, active = {}, ready = {} }
ns.GetOption = function(key) return ns.options[key] end
ns.GetQuestTitle = function(id) return ns.titles[id] end
ns.GetQuestDifficultyLevel = function(id) return ns.levels[id] end
ns.IsOnQuest = function(id) return ns.active[id] end
ns.IsQuestAvailable = function(id) return not ns.active[id] and not ns.completed[id] end
ns.completed = {}
ns.PrefetchQuestInfo = function() end
ns.GetNPCName = function(id) return ns.names[id] end
ns.names = {}
C_QuestLog = { ReadyForTurnIn = function(id) return ns.ready[id] end }
units = { mouseover = 100, npc = 100 }
UnitGUID = function(unit)
    if units[unit] then return 'Creature-0-0-0-0-' .. units[unit] .. '-0000000000' end
end
Enum = { TooltipDataType = { Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
nativeTooltipData = { mouseover = { type=2, lines={{type=2,leftText='Native NPC information'}} } }
C_TooltipInfo = { GetUnit = function(unit) return nativeTooltipData[unit] end }
chat = {}
print = function(...)
    local values = {}
    for index=1,select('#', ...) do values[index] = tostring(select(index, ...)) end
    chat[#chat + 1] = table.concat(values, ' ')
end
GameTooltip = { lines = {}, scripts = {}, unit = 'mouseover', shown = true }
function GameTooltip:GetUnit() return 'NPC', self.unit end
function GameTooltip:IsShown() return self.shown end
function GameTooltip:Show() self.shown = true end
function GameTooltip:AddLine(text, r, g, b, wrap)
    self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b, wrap = wrap }
end
function GameTooltip:SetOwner() end
function GameTooltip:SetText(text, r, g, b)
    self:ClearLines()
    self:AddLine(text, r, g, b)
end
function GameTooltip:HookScript(event, fn) self.scripts[event] = fn end
function GameTooltip:HasScript(event) return event == 'OnTooltipSetUnit' end
function GameTooltip:ClearLines()
    self.lines = {}
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
end
function GameTooltip:SetUnit(unit)
    self.unit = unit
    self:ClearLines()
    self:AddLine('Native NPC information', 1, 1, 1)
    if postCall then postCall(self, nativeTooltipData[unit]) else self.scripts.OnTooltipSetUnit(self) end
end
