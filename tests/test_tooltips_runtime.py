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
            assert(#GameTooltip.lines == 1)
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
