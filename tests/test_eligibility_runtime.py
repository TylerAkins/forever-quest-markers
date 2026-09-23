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
