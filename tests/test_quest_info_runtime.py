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

    def test_skyborne_race_restrictions_filter_the_opposite_faction(self) -> None:
        self.lua.execute("""
            ns.options={showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            UnitRace=function() return 'Skyborne','Skyborne',96 end
            UnitClass=function() return 'Hunter','HUNTER',3 end
            UnitFactionGroup=function() return 'Horde' end
            UnitLevel=function() return 10 end
        """)
        self.load("Eligibility.lua")
        self.lua.execute("""
            assert(ns.IsQuestAvailable(92598,{races={96}}) == true)
            local available, reason = ns.IsQuestAvailable(92597,{races={95}})
            assert(available == false and reason == 'race')
        """)

    def test_npc_offers_quest_accept_respects_starter_and_offered(self) -> None:
        self.load("Eligibility.lua")
        self.lua.execute("""
            ns.Quests[7]={qg=197}
            assert(ns.NpcOffersQuestAccept(197, 7, ns.Quests[7]) == true)
            assert(ns.NpcOffersQuestAccept(198, 7, ns.Quests[7]) == false)
            ns.offeredQuestIDs[99]=true
            assert(ns.NpcOffersQuestAccept(555, 99, nil) == true)
        """)

    def test_npc_tooltip_accept_rows_skip_in_log_quests(self) -> None:
        self.lua.execute("""
            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] end,
                IsQuestFlaggedCompleted=function() return false end,
            }
            UnitLevel=function() return 20 end
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,1,1 end
        """)
        self.load("Eligibility.lua")
        self.load("NPCTooltips.lua")
        self.lua.execute("""
            ns.Quests[10]={qg=100}
            ns.NPCTooltips:InvalidateStarterIndex()
            local rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==1 and rows[1].id==10)
            ns.active[10]=true
            rows=ns.NPCTooltips:GetAcceptRows(100)
            assert(#rows==0)
        """)

    def test_npc_tooltip_shows_in_log_turn_ins_and_accepts(self) -> None:
        self.lua.execute("""
            ns.options={showNPCTooltips=true,showRepeatable=true,showSeasonal=true,showWarEffort=true,showTrivial=true}
            ns.Quests={}
            ns.active={}
            ns.complete={}
            function ns.GetOption(key) return ns.options[key] end
            function GetQuestsCompleted() return {} end
            C_QuestLog={
                IsOnQuest=function(id) return ns.active[id] and true or false end,
                IsQuestFlaggedCompleted=function() return false end,
                IsComplete=function(id) return ns.complete[id] and true or false end,
            }
            UnitLevel=function() return 20 end
            UnitGUID=function() return 'Creature-0-0-0-0-100-0000000000' end
            lines={}
            GameTooltip={
                AddLine=function(_, text) lines[#lines+1]=text end,
                Show=function() end,
            }
        """)
        self.load("Eligibility.lua")
        self.load("NPCTooltips.lua")
        self.lua.execute("""
            function ns.GetQuestTitle(id) return 'Quest '..id end
            function ns.GetQuestDifficultyLevel(id) return 5 end
            function ns.GetQuestDifficultyRGB() return 1,0.8,0 end
            ns.Quests[10]={qg=100}
            ns.Quests[20]={turnIns={100}}
            ns.active[20]=true
            ns.complete[20]=true
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(lines[1]=='! [5] Quest 10')
            assert(#lines==1)

            lines={}
            GameTooltip.fqpQuestRows=nil
            ns.Quests[10]=nil
            ns.NPCTooltips:InvalidateStarterIndex()
            ns.NPCTooltips:AppendAcceptRows(GameTooltip, 'target')
            assert(#lines==0)
        """)

    def test_yearly_quests_stay_hidden_until_seasonal_pins_are_on(self) -> None:
        self.lua.execute("""
            ns.options={showRepeatable=true,showSeasonal=false,showWarEffort=true,showTrivial=true}
            function ns.GetOption(key) return ns.options[key] end
            UnitLevel=function() return 60 end
            C_QuestLog={
                IsOnQuest=function() return false end,
                IsQuestFlaggedCompleted=function() return false end,
            }
        """)
        self.load("Eligibility.lua")
        self.lua.execute("""
            local available, reason = ns.IsQuestAvailable(8673, {isYearly=true, minLevel=1})
            assert(available == false and reason == 'seasonal')
            available, reason = ns.IsQuestAvailable(155, {minLevel=14})
            assert(available == true and reason == 'no-prereq')
        """)

    def test_npc_id_from_secret_guid_returns_nil(self) -> None:
        self.load("Eligibility.lua")
        self.lua.execute("""
            issecretvalue=function() return true end
            assert(ns.NpcIDFromGUID('secret-guid')==nil)
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


class QuestTrackerCombatRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lua = LuaRuntime()
        self.lua.execute("""
            ns = {hideTracker=true}
            function ns.GetOption() return ns.hideTracker end
            function CreateFrame()
                frame = {}
                function frame:SetScript(name, fn) self[name] = fn end
                function frame:RegisterEvent() end
                return frame
            end
            inCombat = false
            function UnitAffectingCombat() return inCombat end
            tracker = {alpha=0.65, collapsed=false}
            function tracker:GetAlpha() return self.alpha end
            function tracker:SetAlpha(alpha) self.alpha = alpha end
            function tracker:SetCollapsed() error('Blizzard layout was tainted') end
            function tracker:Show() error('Blizzard visibility was changed') end
            function tracker:Hide() error('Blizzard visibility was changed') end
            ObjectiveTrackerFrame = tracker
        """)
        self.lua.execute((ROOT / "Core.lua").read_text(), "ForeverQuestPins", self.lua.globals().ns)

    def test_combat_hides_without_layout_changes_and_restores_original_alpha(self) -> None:
        self.lua.execute("""
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == false)
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)
            tracker.collapsed = true
            tracker.alpha = 0
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0 and tracker.collapsed == true)
        """)

    def test_disabling_option_during_combat_restores_tracker(self) -> None:
        self.lua.execute("""
            inCombat = true
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0)
            ns.hideTracker = false
            ns.SyncQuestTrackerCombatVisibility()
            assert(tracker.alpha == 0.65)
            tracker.alpha = 0.8
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.8)
        """)

    def test_disabled_option_leaves_tracker_untouched(self) -> None:
        self.lua.execute("""
            ns.hideTracker = false
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65)
        """)

    def test_missing_tracker_can_be_retried_and_original_frame_is_restored(self) -> None:
        self.lua.execute("""
            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = {}
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = tracker
            ns.ApplyQuestTrackerCombatHide(true)
            ObjectiveTrackerFrame = nil
            ns.ApplyQuestTrackerCombatHide(false)
            assert(tracker.alpha == 0.65)
        """)

    def test_quest_completion_and_level_up_refresh_leave_collapse_unchanged(self) -> None:
        self.lua.execute("""
            refreshes = 0
            ns.MapPins = {Refresh=function(_, reason)
                assert(reason == 'PLAYER_LEVEL_UP' or reason == 'QUEST_TURNED_IN')
                refreshes = refreshes + 1
            end}
            frame.OnEvent(frame, 'PLAYER_REGEN_DISABLED')
            frame.OnEvent(frame, 'QUEST_TURNED_IN', 1)
            frame.OnUpdate(frame, 0.2)
            frame.OnEvent(frame, 'PLAYER_LEVEL_UP')
            frame.OnUpdate(frame, 0.2)
            assert(refreshes == 2 and tracker.alpha == 0)
            frame.OnEvent(frame, 'PLAYER_REGEN_ENABLED')
            assert(tracker.alpha == 0.65 and tracker.collapsed == false)
        """)

    def test_map_refresh_skips_quest_state_cache_invalidation(self) -> None:
        self.lua.execute("""
            completion = 0
            profession = 0
            starter = 0
            ns.InvalidateCompletionCache = function() completion = completion + 1 end
            ns.InvalidateProfessionCache = function() profession = profession + 1 end
            ns.NPCTooltips = {InvalidateStarterIndex=function() starter = starter + 1 end}
            ns.MapPins = {Refresh=function() end}
            ns.RefreshNow('map-show')
            ns.RefreshNow('map-changed')
            ns.RefreshNow('canvas-zero')
            assert(completion == 0 and profession == 0 and starter == 0)
            ns.RefreshNow('QUEST_TURNED_IN')
            assert(completion == 1 and profession == 1 and starter == 0)
        """)


if __name__ == "__main__":
    unittest.main()
