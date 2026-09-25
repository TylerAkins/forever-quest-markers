"""Execute NPC tooltip behavior against a small WoW API double."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class TooltipRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/fixtures/npc_tooltips.lua").read_text())
        self.load("NPCTooltips.lua")
        self.lua.execute("ns.NPCTooltips:Initialize()")

    def load(self, name: str) -> None:
        self.lua.execute((ROOT / name).read_text(), "ForeverQuestPins", self.lua.globals().ns)

    def test_available_rows_use_levels_and_stable_order(self) -> None:
        self.lua.execute("""
            ns.Quests = {
                [1] = {qg=100}, [2] = {qg=100}, [3] = {qg=100},
                [4] = {qg=100}, [5] = {qg=200},
            }
            ns.titles = {[1]='Available', [2]='Active', [3]='Lower', [4]='Unknown level', [5]='Elsewhere'}
            ns.levels = {[1]=12, [2]=12, [3]=10}
            ns.active = {[2]=true}
            GameTooltip:SetUnit('mouseover')
            assert(#GameTooltip.lines == 4)
            assert(GameTooltip.lines[1].text == 'Native NPC information')
            assert(GameTooltip.lines[2].text == '! [10] Lower')
            assert(GameTooltip.lines[3].text == '! [12] Available')
            assert(GameTooltip.lines[4].text == '! Unknown level')
            for index=2,#GameTooltip.lines do
                assert(GameTooltip.lines[index].r == 1 and GameTooltip.lines[index].g == .82)
            end
        """)

    def test_turn_in_rows_follow_the_quest_in_the_log(self) -> None:
        self.lua.execute("""
            ns.Quests[92469] = {qg=200, endNpc=100}
            ns.Quests[92461] = {qg=100, endNpc=100}
            ns.titles[92469] = 'Return to Rorian'
            ns.titles[92461] = 'Harmony in Balance'
            ns.levels[92469] = 4
            ns.levels[92461] = 1
            GameTooltip:SetUnit('mouseover')
            assert(#GameTooltip.lines == 2)
            assert(GameTooltip.lines[2].text == '! [1] Harmony in Balance')
            ns.active[92461] = true
            ns.active[92469] = true
            ns.ready[92469] = true
            ns.NPCTooltips:Refresh()
            assert(#GameTooltip.lines == 2)
            assert(GameTooltip.lines[2].text == '? [4] Return to Rorian')
            assert(GameTooltip.lines[2].r == 1 and GameTooltip.lines[2].g == .82)
            ns.active[92469] = nil
            ns.active[92461] = nil
            ns.NPCTooltips:Refresh()
            assert(GameTooltip.lines[2].text == '! [1] Harmony in Balance')
            assert(#GameTooltip.lines == 2)
        """)

    def test_unfinished_quest_does_not_show_a_turn_in_and_an_offer(self) -> None:
        self.lua.execute("""
            ns.Quests[1485] = {qg=100, endNpc=100}
            ns.Quests[1499] = {qg=100, endNpc=200}
            ns.titles[1485] = 'Vile Familiars'
            ns.titles[1499] = 'Vile Familiars'
            ns.levels[1485] = 4
            ns.levels[1499] = 4
            ns.active[1485] = true
            GameTooltip:SetUnit('mouseover')
            assert(#GameTooltip.lines == 1)
            ns.ready[1485] = true
            ns.NPCTooltips:Refresh()
            assert(#GameTooltip.lines == 2)
            assert(GameTooltip.lines[2].text == '? [4] Vile Familiars')
            ns.active[1485] = nil
            ns.ready[1485] = nil
            ns.NPCTooltips:Refresh()
            assert(#GameTooltip.lines == 2)
            assert(GameTooltip.lines[2].text == '! [4] Vile Familiars')
        """)

    def test_quest_state_transitions_refresh_available_rows(self) -> None:
        self.lua.execute("""
            ns.Quests[1] = {qg=100}; ns.titles[1] = 'Quest'; ns.levels[1]=12
            GameTooltip:SetUnit('mouseover')
            assert(GameTooltip.lines[2].text == '! [12] Quest')
            ns.active[1]=true; ns.NPCTooltips:Refresh()
            assert(#GameTooltip.lines == 1)
            ns.active[1]=nil; ns.completed[1]=true; ns.NPCTooltips:Refresh()
            assert(#GameTooltip.lines == 1)
            ns.completed[1]=nil; ns.NPCTooltips:Refresh()
            assert(GameTooltip.lines[2].text == '! [12] Quest')
        """)

    def test_duplicate_callbacks_rebuild_switch_and_setting(self) -> None:
        self.lua.execute("""
            ns.Quests[1]={qg=100, qgs={100}}; ns.titles[1]='Quest'
            ns.options.enabled=false
            GameTooltip:SetUnit('mouseover'); postCall(GameTooltip, nativeTooltipData.mouseover); postCall(GameTooltip, nativeTooltipData.mouseover)
            assert(#GameTooltip.lines == 2)
            ns.NPCTooltips:Refresh(); assert(#GameTooltip.lines == 2)
            units.mouseover=200; GameTooltip:SetUnit('mouseover'); assert(#GameTooltip.lines == 1)
            units.mouseover=100; ns.NPCTooltips:Refresh(); assert(#GameTooltip.lines == 2)
            ns.options.showNPCTooltips=false; ns.NPCTooltips:Refresh(); assert(#GameTooltip.lines == 1)
        """)

    def test_delayed_data_and_dynamic_starters(self) -> None:
        self.lua.execute("""
            ns.Quests[1]={qg=100}; GameTooltip:SetUnit('mouseover')
            assert(GameTooltip.lines[2].text == '! Quest 1 (title unavailable)')
            ns.titles[1]='Loaded'; ns.levels[1]=12; ns.NPCTooltips:Refresh()
            assert(GameTooltip.lines[2].text == '! [12] Loaded')
            ns.Quests[2]={qg=100}; ns.titles[2]='New'; ns.NPCTooltips:InvalidateIndex()
            ns.NPCTooltips:Refresh(); assert(#GameTooltip.lines == 3)
        """)

    def test_legacy_hook_and_scanner_tooltip_isolation(self) -> None:
        self.lua.execute('TooltipDataProcessor=nil; postCall=nil')
        self.load('NPCTooltips.lua')
        self.lua.execute("""
            ns.NPCTooltips:Initialize()
            ns.Quests[1]={qg=100}; ns.titles[1]='Quest'
            GameTooltip:SetUnit('mouseover')
            assert(#GameTooltip.lines == 2)
            local scanner={}
            ns.NPCTooltips:Show(scanner)
            assert(scanner.fqpQuestRows == nil)
        """)

    def test_offered_quests_repair_starters_without_map_coordinates(self) -> None:
        self.load('Eligibility.lua')
        self.lua.execute("""
            C_QuestLog.GetTitleForQuestID=function(id) return 'Quest '..id end
            ns.Quests[1]={qg=200, qgs={300}, mapID=1, x=10, y=20}
            ns.Quests[2]={sourceQuests={999}}
            assert(#ns.NPCTooltips:GetRows(100)==0)
            ns.SetLastOfferNPC(100,nil,nil,nil)
            for id=1,3 do ns.NoteOfferedQuest(id) end
            local rows=ns.NPCTooltips:GetRows(100)
            assert(#rows==3)
            assert(ns.Quests[1].qg==200 and ns.Quests[1].qgs[1]==300)
            assert(ns.Quests[1].mapID==1 and ns.Quests[1].x==10)
            assert(ns.Quests[1].qgs[2]==100)
            ns.NoteOfferedQuest(1)
            assert(#ns.Quests[1].qgs==2)
            assert(#ns.NPCTooltips:GetRows(200)==1)
            assert(#ns.NPCTooltips:GetRows(300)==1)
            assert(next(ns.ByMap)==nil)
            ns.SetLastOfferNPC(nil,nil,nil,nil)
            ns.NoteOfferedQuest(4)
            assert(ns.Quests[4]==nil)
            ns.SetLastOfferNPC(nil,1,25,30)
            ns.NoteOfferedQuest(5)
            assert(ns.ByMap[1][1]==5 and ns.Quests[5].qg==nil)
        """)

    def test_new_offered_quest_keeps_map_pin_and_hides_when_accepted(self) -> None:
        self.load('Eligibility.lua')
        self.lua.execute("""
            ns.SetLastOfferNPC(100,2521,42,23)
            ns.NoteOfferedQuest(92499)
            ns.NoteOfferedQuest(92499)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==92499)
            assert(#ns.NPCTooltips:GetRows(100)==1)
            C_QuestLog.IsOnQuest=function() return true end
            assert(#ns.NPCTooltips:GetRows(100)==0)
            C_QuestLog.IsOnQuest=function() return false end
            C_QuestLog.IsQuestFlaggedCompleted=function() return true end
            assert(#ns.NPCTooltips:GetRows(100)==0)
        """)

    def test_failed_title_load_retries_on_lookup_and_recovers(self) -> None:
        self.load('Eligibility.lua')
        self.lua.execute("""
            CreateFrame=function()
                frame={}
                function frame:SetScript(name,fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            requests=0
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            C_QuestLog.GetQuestDifficultyLevel=function() return 12 end
            ns.SetLastOfferNPC(100,nil,nil,nil)
            ns.NoteOfferedQuest(1)
            GameTooltip:SetUnit('mouseover')
            assert(requests==1)
        """)
        self.load('Core.lua')
        self.lua.execute("""
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(requests==1)
            assert(GameTooltip.lines[2].text=='! [12] Quest 1 (title unavailable)')
            GameTooltip:SetUnit('mouseover')
            assert(requests==2)
            GameTooltip:SetUnit('mouseover')
            assert(requests==2)
            C_QuestLog.GetTitleForQuestID=function() return 'Loaded quest' end
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            assert(GameTooltip.lines[2].text=='! [12] Loaded quest')
        """)

    def test_level_lookup_requests_data_once_and_never_uses_minimum(self) -> None:
        self.load('Eligibility.lua')
        self.lua.execute("""
            local requests=0
            C_QuestLog.GetQuestDifficultyLevel=function() return nil end
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            ns.Quests[1]={minLevel=5}
            assert(ns.GetQuestDifficultyLevel(1)==nil)
            assert(ns.GetQuestDifficultyLevel(1)==nil and requests==1)
            C_QuestLog.GetQuestDifficultyLevel=function() return 12 end
            assert(ns.GetQuestDifficultyLevel(1)==12)
        """)

    def test_required_profession_filters_only_when_skill_data_is_known(self) -> None:
        self.lua.execute("""
            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Orc','Orc',2 end
            UnitClass=function() return 'Druid','DRUID',11 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 13 end
            IsPlayerSpell=function(spellID) return spellID == 9788 end
            GetProfessions=function() return 1,nil,nil,2 end
            GetProfessionInfo=function(index)
                local skillLine = index == 1 and 197 or 356
                return 'Profession',nil,1,75,nil,nil,skillLine
            end
        """)
        self.load("Eligibility.lua")
        self.lua.execute("""
            assert(ns.IsQuestAvailable(1,{requireSkill=197}) == true)
            assert(ns.IsQuestAvailable(5,{requireSkill=9788}) == true)
            local available, reason = ns.IsQuestAvailable(2,{requireSkill=164})
            assert(available == false and reason == 'profession')
            assert(ns.IsQuestAvailable(3,{requireSkill='NEW_PROFESSION'}) == true)

            GetProfessions=nil
            GetProfessionInfo=nil
            ns.InvalidateProfessionCache()
            assert(ns.IsQuestAvailable(4,{requireSkill=164}) == true)
        """)

    def test_failed_data_event_does_not_trigger_retry_loop(self) -> None:
        self.lua.execute("""
            CreateFrame=function()
                frame={}
                function frame:SetScript(name, fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            dataLoads=0
            ns.OnQuestDataLoad=function() dataLoads=dataLoads+1 end
        """)
        self.load('Core.lua')
        self.lua.execute("""
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(dataLoads==0)
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            frame.OnEvent(frame,'QUEST_DATA_LOAD',1)
            assert(dataLoads==2)
        """)

    def test_hover_probe_reports_structured_fields_once(self) -> None:
        self.lua.execute("""
            nativeTooltipData.mouseover={type=2, lines={
                {type=2,leftText='NPC'},
                {type=17,leftText='Quest Name',questID=42,args={{field='questID',intVal=42}}},
                {type=8,leftText='0/1 Objective',completed=false},
            }}
            C_QuestLog.UnitIsRelatedToActiveQuest=function() return true end
            ns.NPCTooltips:ArmProbe()
            GameTooltip:SetUnit('mouseover')
            local output=table.concat(chat,'\\n')
            assert(output:find('NPC 100',1,true))
            assert(output:find('relatedToActiveQuest=true',1,true))
            assert(output:find('questID=42',1,true))
            assert(output:find('args[1]: field=questID, intVal=42',1,true))
            chat={}
            GameTooltip:SetUnit('mouseover')
            assert(#chat==0)
        """)


if __name__ == "__main__":
    unittest.main()
