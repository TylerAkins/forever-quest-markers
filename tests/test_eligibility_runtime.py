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

    def test_session_turn_in_hides_pin_when_completed_list_lags(self) -> None:
        self.lua.execute("""
            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            local available = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == true)
            ns.NoteQuestCompleted(2953)
            ns.InvalidateCompletionCache()
            assert(ns.IsQuestFlaggedCompleted(2953) == true)
            available, reason = ns.IsQuestAvailable(2953, { minLevel = 1 })
            assert(available == false and reason == 'completed')
        """)

    def test_session_accept_hides_offered_pin_when_log_lags(self) -> None:
        self.lua.execute("""
            C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.IsOnQuest = function() return false end
            UnitLevel = function() return 60 end
            ns.GetOption = function() return true end
            ns.NoteOfferedQuest(92499)
            local available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == true and reason == 'npc-offered')
            ns.NoteQuestAccepted(92499)
            assert(ns.IsOffered(92499) == false)
            assert(ns.IsOnQuest(92499) == true)
            available, reason = ns.IsQuestAvailable(92499, { minLevel = 1 })
            assert(available == false and reason == 'in-log')
            ns.NoteQuestRemoved(92499)
            assert(ns.IsOnQuest(92499) == false)
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

    def test_trivial_pins_hidden_when_nine_or_more_levels_below_player(self) -> None:
        self.lua.execute("""
            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 21 })
            assert(available == false and reason == 'trivial')
            available, reason = ns.IsQuestAvailable(2, { minLevel = 22 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')
        """)

    def test_trivial_pins_use_client_quest_level_without_db_min_level(self) -> None:
        self.lua.execute("""
            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 9 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 20 end
            UnitFactionGroup = function() return 'Horde' end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            C_QuestLog.GetQuestDifficultyLevel = function(questID)
                return questID == 8 and 5 or nil
            end
            local available, reason = ns.IsQuestAvailable(8, { faction = 'Horde' })
            assert(available == false and reason == 'trivial')
        """)

    def test_trivial_gap_uses_configured_option(self) -> None:
        self.lua.execute("""
            ns.GetOption = function(key)
                if key == 'trivialLevelGap' then return 5 end
                return key == 'showTrivial' and false or nil
            end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 25 })
            assert(available == false and reason == 'trivial')
            available = ns.IsQuestAvailable(2, { minLevel = 26 })
            assert(available == true)
        """)

    def test_hidden_quest_is_unavailable_even_when_offered(self) -> None:
        self.lua.execute("""
            ns.GetOption = function() return true end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            ns.IsQuestHidden = function(questID) return questID == 5 end
            ns.NoteOfferedQuest(5)
            local available, reason = ns.IsQuestAvailable(5, { minLevel = 1 })
            assert(available == false and reason == 'user-hidden')
            available, reason = ns.IsQuestAvailable(6, { minLevel = 1 })
            assert(available == true)
        """)

    def test_trivial_pins_shown_when_option_enabled(self) -> None:
        self.lua.execute("""
            ns.GetOption = function(key) return key == 'showTrivial' and true or nil end
            UnitLevel = function() return 30 end
            C_QuestLog.IsOnQuest = function() return false end
            C_QuestLog.IsQuestFlaggedCompleted = function() return false end
            local available, reason = ns.IsQuestAvailable(1, { minLevel = 1 })
            assert(available == true)
            assert(reason == 'ok' or reason == 'no-prereq')
        """)

    def test_secret_unit_guid_does_not_crash_offer_capture(self) -> None:
        self.lua.execute("""
            local secretGuid = 'Creature-0-0-0-0-3139-0000000000'
            issecretvalue = function(value) return value == secretGuid end
            UnitGUID = function(unit)
                if unit == 'npc' then return secretGuid end
            end
            C_Map = {
                GetBestMapForUnit = function() return 1 end,
                GetPlayerMapPosition = function()
                    return { x = 0.5, y = 0.25 }
                end,
            }
            ns.CaptureOfferContext()
            assert(ns.lastOffer ~= nil)
            assert(ns.lastOffer.qg == nil)
            assert(ns.lastOffer.mapID == 1)
            assert(ns.lastOffer.x == 50)
            assert(ns.lastOffer.y == 25)

            issecretvalue = function() return false end
            assert(ns.NpcIDFromGUID('Creature-0-0-0-0-3139-0000000000') == 3139)
            assert(ns.NpcIDFromGUID('Vehicle-0-0-0-0-417-0000000000') == 417)
        """)

    def test_secret_npc_name_is_ignored_without_being_cached(self) -> None:
        self.lua.execute("""
            local secretName = 'secret npc name'
            issecretvalue = function(value) return value == secretName end
            C_TooltipInfo = {
                GetHyperlink = function()
                    return { lines = { { leftText = secretName } } }
                end,
            }
            assert(ns.GetNPCName(3139) == nil)

            C_TooltipInfo.GetHyperlink = function()
                return { lines = { { leftText = "Gar'Thok" } } }
            end
            assert(ns.GetNPCName(3139) == "Gar'Thok")
        """)


if __name__ == "__main__":
    unittest.main()
