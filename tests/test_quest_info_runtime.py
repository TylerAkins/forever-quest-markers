"""Execute quest-info and learned-starter behavior against WoW API doubles."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class QuestInfoRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/fixtures/quest_info.lua").read_text())

    def load(self, name: str) -> None:
        self.lua.execute((ROOT / name).read_text(), "ForeverQuestPins", self.lua.globals().ns)

    def test_offered_quests_repair_starters_without_map_coordinates(self) -> None:
        self.load("Eligibility.lua")
        self.lua.execute("""
            ns.Quests[1]={qg=200, qgs={300}, mapID=1, x=10, y=20}
            ns.SetLastOfferNPC(100,nil,nil,nil)
            for id=1,3 do ns.NoteOfferedQuest(id) end
            assert(ns.IsOffered(1) and ns.IsOffered(2) and ns.IsOffered(3))
            assert(ns.Quests[1].qg==200 and ns.Quests[1].qgs[1]==300)
            assert(ns.Quests[1].mapID==1 and ns.Quests[1].x==10)
            assert(ns.Quests[1].qgs[2]==100)
            ns.NoteOfferedQuest(1)
            assert(#ns.Quests[1].qgs==2)
            assert(next(ns.ByMap)==nil)
            ns.SetLastOfferNPC(nil,nil,nil,nil)
            ns.NoteOfferedQuest(4)
            assert(ns.Quests[4]==nil)
            ns.SetLastOfferNPC(nil,1,25,30)
            ns.NoteOfferedQuest(5)
            assert(ns.ByMap[1][1]==5 and ns.Quests[5].qg==nil)
        """)

    def test_new_offered_quest_hides_when_accepted(self) -> None:
        self.load("Eligibility.lua")
        self.lua.execute("""
            ns.SetLastOfferNPC(100,2521,42,23)
            ns.NoteOfferedQuest(92499)
            ns.NoteOfferedQuest(92499)
            assert(#ns.ByMap[2521]==1 and ns.ByMap[2521][1]==92499)
            assert(ns.IsQuestAvailable(92499, ns.Quests[92499]) == true)
            C_QuestLog.IsOnQuest=function() return true end
            local available, reason=ns.IsQuestAvailable(92499, ns.Quests[92499])
            assert(available == false and reason == 'in-log')
        """)

    def test_failed_title_load_retries_on_lookup_and_recovers(self) -> None:
        self.load("Eligibility.lua")
        self.lua.execute("""
            CreateFrame=function()
                frame={}
                function frame:SetScript(name,fn) self[name]=fn end
                function frame:RegisterEvent() end
                return frame
            end
            requests=0
            C_QuestLog.RequestLoadQuestByID=function() requests=requests+1 end
            assert(ns.GetQuestTitle(1)==nil and requests==1)
        """)
        self.load("Core.lua")
        self.lua.execute("""
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(requests==1)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            assert(ns.GetQuestTitle(1)==nil and requests==2)
            C_QuestLog.GetTitleForQuestID=function() return 'Loaded quest' end
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            assert(ns.GetQuestTitle(1)=='Loaded quest')
        """)

    def test_level_lookup_requests_data_once_and_never_uses_minimum(self) -> None:
        self.load("Eligibility.lua")
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

    def test_failed_data_event_does_not_trigger_success_handler(self) -> None:
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
        self.load("Core.lua")
        self.lua.execute("""
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,false)
            assert(dataLoads==0)
            frame.OnEvent(frame,'QUEST_DATA_LOAD_RESULT',1,true)
            frame.OnEvent(frame,'QUEST_DATA_LOAD',1)
            assert(dataLoads==2)
        """)


if __name__ == "__main__":
    unittest.main()
