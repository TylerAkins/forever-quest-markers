"""Execute quest-completion eligibility behavior against WoW API doubles."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class CompletionRuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lua = LuaRuntime()
        self.lua.execute("ns = {}; C_QuestLog = {}")
        self.lua.execute(
            (ROOT / "Eligibility.lua").read_text(),
            "ForeverQuestPins",
            self.lua.globals().ns,
        )

    def test_completed_id_list_wins_over_account_completion(self) -> None:
        self.lua.execute("""
            C_QuestLog.GetAllCompletedQuestIDs = function() return { [1] = 3090 } end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsQuestFlaggedCompletedOnAccount = function()
                error('account completion must not be consulted')
            end
            assert(ns.IsQuestFlaggedCompleted(3090) == true)
            assert(ns.IsQuestFlaggedCompleted(2953) == false)
        """)

    def test_empty_completed_id_list_is_authoritative(self) -> None:
        self.lua.execute("""
            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return true end
            assert(ns.IsQuestFlaggedCompleted(2953) == false)
        """)

    def test_legacy_completed_list_and_single_quest_fallback(self) -> None:
        self.lua.execute("""
            GetQuestsCompleted = function()
                return { [2953] = true, [2966] = 1, [2970] = 2970 }
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(2966) == true)
            assert(ns.IsQuestFlaggedCompleted(2970) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)
        """)

    def test_quest_log_scan_hides_accepted_quests_when_is_on_quest_is_false(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.GetNumQuestLogEntries = function() return 2 end
            C_QuestLog.GetInfo = function(index)
                if index == 1 then return { isHeader = true, title = "Zephras Isle" } end
                return { questID = 92460, isHeader = false, title = "Coming of Age" }
            end
            assert(ns.IsOnQuest(92460) == true)
            assert(ns.IsOnQuest(92461) == false)
        """)

    def test_legacy_quest_log_title_counts_as_accepted(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function() return false end
            GetNumQuestLogEntries = function() return 1 end
            GetQuestLogTitle = function()
                return "Harmony in Balance", 1, nil, false, false, nil, nil, 92461
            end
            assert(ns.IsOnQuest(92461) == true)
            assert(ns.IsOnQuest(92460) == false)
        """)

    def test_log_index_counts_when_is_on_quest_is_false(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.GetLogIndexForQuestID = function(questID)
                if questID == 92462 then return 3 end
                return 0
            end
            assert(ns.IsOnQuest(92462) == true)
            assert(ns.IsOnQuest(1) == false)
        """)

    def test_throwing_log_index_falls_through_to_the_quest_log(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.GetLogIndexForQuestID = function() error("index unavailable") end
            GetQuestLogIndexByID = function() error("index unavailable") end
            C_QuestLog.GetNumQuestLogEntries = function() return 1 end
            C_QuestLog.GetInfo = function()
                return { questID = 92460, isHeader = false }
            end
            assert(ns.IsOnQuest(92460) == true)
            assert(ns.IsOnQuest(92461) == false)
        """)

    def test_log_completion_marks_a_turn_in_when_ready_api_is_false(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.ReadyForTurnIn = function() return false end
            C_QuestLog.GetNumQuestLogEntries = function() return 2 end
            C_QuestLog.GetInfo = function(index)
                if index == 1 then return { questID = 92469, isComplete = 1 } end
                return { questID = 92461, isComplete = false }
            end
            assert(ns.IsQuestReadyForTurnIn(92469) == true)
            assert(ns.IsQuestReadyForTurnIn(92461) == false)
            assert(ns.IsQuestReadyForTurnIn(1) == false)
        """)

    def test_open_objectives_in_the_log_are_not_ready_to_turn_in(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsOnQuest = function(questID) return questID == 1485 end
            C_QuestLog.ReadyForTurnIn = function() return true end
            C_QuestLog.IsComplete = function() return true end
            C_QuestLog.GetNumQuestLogEntries = function() return 1 end
            C_QuestLog.GetInfo = function()
                return { questID = 1485, isComplete = false }
            end
            assert(ns.IsQuestReadyForTurnIn(1485) == false)
        """)

    def test_single_quest_api_is_used_only_without_a_completed_list(self) -> None:
        self.lua.execute("""
            C_QuestLog.IsQuestFlaggedCompleted = function(questID)
                return questID == 2953
            end
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            assert(ns.IsQuestFlaggedCompleted(3090) == false)
        """)


if __name__ == "__main__":
    unittest.main()
