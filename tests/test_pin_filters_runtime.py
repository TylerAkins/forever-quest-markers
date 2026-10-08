"""Exercise the low-level gap setting and Shift-click hidden quest pins with WoW API doubles."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON_FILES = ("Config.lua", "HiddenQuests.lua", "Eligibility.lua", "MapPins.lua")


class PinFilterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.lua = LuaRuntime()
        self.lua.execute("""
            ns = {}
            messages = {}
            refreshes = {}
            print = function(message) table.insert(messages, message) end
            function said(text)
                for _, message in ipairs(messages) do
                    if message:find(text, 1, true) then return true end
                end
                return false
            end
            playerName = "Thrall"
            realmName = "Forever"
            UnitName = function() return playerName end
            GetRealmName = function() return realmName end
            UnitLevel = function() return 30 end
            C_QuestLog = {}
            shift = false
            IsShiftKeyDown = function() return shift end
            GameTooltip = { Hide = function() tooltipHidden = true end }
            CreateFrame = function() return { SetScript = function() end } end
        """)
        for name in ADDON_FILES:
            self.lua.execute((ROOT / name).read_text(encoding="utf-8"), "ForeverQuestPins", self.lua.globals().ns)
        self.lua.execute("""
            ns.RequestRefresh = function(reason) table.insert(refreshes, reason) end
            ns.TrackQuest = function(questID) tracked = questID end
        """)

    def use_mirror(self, text: str) -> None:
        self.lua.globals().mirror = text
        self.lua.execute("""
            C_CVar = {
                GetCVar = function() return mirror end,
                SetCVar = function(_, text) mirror = text end,
                RegisterCVar = function() end,
            }
        """)

    def test_trivial_gap_restores_from_mirror_and_clamps(self) -> None:
        self.use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=5;enabled=1")
        self.lua.execute("""
            assert(ns.InitSettings().trivialLevelGap == 5)
            ns.SetOption("trivialLevelGap", 1)
            assert(ns.GetOption("trivialLevelGap") == 3)
            ns.SetOption("trivialLevelGap", 99)
            assert(ns.GetOption("trivialLevelGap") == 15)
            ns.SetOption("trivialLevelGap", 6)
            assert(ForeverQuestPinsDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharDB.trivialLevelGap == 6)
            assert(ForeverQuestPinsDB_Settings.trivialLevelGap == 6)
            assert(ForeverQuestPinsCharacterSettings.trivialLevelGap == 6)
            assert(mirror:find("trivialLevelGap=6", 1, true))
        """)

    def test_out_of_range_mirror_gap_falls_back_to_default(self) -> None:
        self.use_mirror("revision=42;waypointProvider=blizzard;trivialLevelGap=40;enabled=1")
        self.lua.execute("""
            assert(ns.InitSettings().trivialLevelGap == 9)
        """)

    def test_slash_trivial_sets_gap_and_bare_command_toggles(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            ns.SlashCommand("trivial 5")
            assert(ns.GetOption("trivialLevelGap") == 5)
            assert(said("hiding quests 5+ levels below you"))
            ns.SlashCommand("trivial 40")
            assert(ns.GetOption("trivialLevelGap") == 15)
            assert(ns.GetOption("showTrivial") == false)
            ns.SlashCommand("trivial")
            assert(ns.GetOption("showTrivial") == true)
            assert(ns.GetOption("trivialLevelGap") == 15)
        """)

    def test_hidden_quests_are_per_character_in_account_db(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            assert(ns.HideQuests({ 101, 102, 101 }) == 2)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"][101] == true)
            assert(refreshes[#refreshes] == "quest-hidden")

            playerName = "Jaina"
            assert(not ns.IsQuestHidden(101))
            assert(ForeverQuestPinsDB.hiddenQuests["Jaina-Forever"] == nil)
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(not ns.IsQuestHidden(201))

            playerName = nil
            assert(ns.HideQuests({ 301 }) == 0)
            assert(not ns.IsQuestHidden(301))
        """)

    def test_hidden_quests_survive_init_and_wipe_settings(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            ns.HideQuests({ 101 })
            ns.SetOption("showTrivial", true)
            ns.WipeSettings()
            assert(ns.IsQuestHidden(101))

            ForeverQuestPinsCharDB._revision = 999
            ns.db = nil
            ns.InitSettings()
            assert(ns.db == ForeverQuestPinsDB)
            assert(ns.IsQuestHidden(101))
        """)

    def test_reset_hidden_quest_pins_clears_only_current_character(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            ns.HideQuests({ 101, 102 })
            playerName = "Jaina"
            ns.HideQuests({ 201 })
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 2)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
            assert(ForeverQuestPinsDB.hiddenQuests["Thrall-Forever"] == nil)
            assert(said("Restored 2 hidden quest pin(s)."))
            playerName = "Jaina"
            assert(ns.IsQuestHidden(201))
            playerName = "Thrall"
            assert(ns.ResetHiddenQuestPins() == 0)
        """)

    def test_unhide_one_and_slash_list(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            ns.GetQuestTitle = function(questID) return questID == 101 and "Sharptusk" or nil end
            ns.HideQuests({ 102, 101 })
            local ids = ns.HiddenQuestIDs()
            assert(#ids == 2 and ids[1] == 101 and ids[2] == 102)
            ns.SlashCommand("hidden")
            assert(said("101 Sharptusk"))
            ns.SlashCommand("unhide 101")
            assert(not ns.IsQuestHidden(101) and ns.IsQuestHidden(102))
            ns.SlashCommand("unhide 999")
            assert(said("Quest 999 is not hidden"))
            ns.SlashCommand("unhide")
            assert(said("Usage: /fqp unhide"))
            ns.SlashCommand("unhidden")
            assert(said("Unknown command"))
            ns.SlashCommand("unhide all")
            assert(#ns.HiddenQuestIDs() == 0)
            ns.SlashCommand("hidden")
            assert(said("No hidden quest pins"))
        """)

    def test_shift_click_hides_every_quest_on_stacked_pin(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 }, { id = 103 } } }
            pin.Hide = function(self) self.hidden = true end
            shift = true
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == nil)
            assert(ns.IsQuestHidden(101) and ns.IsQuestHidden(102) and ns.IsQuestHidden(103))
            assert(tooltipHidden and pin.hidden)
            assert(said("Hid 3 quest(s)."))
            assert(refreshes[#refreshes] == "quest-hidden")
            local available, reason = ns.IsQuestAvailable(102, { minLevel = 1 })
            assert(available == false and reason == "user-hidden")
        """)

    def test_plain_click_still_tracks(self) -> None:
        self.lua.execute("""
            ns.InitSettings()
            local pin = { questID = 101, quests = { { id = 101 }, { id = 102 } } }
            ForeverQuestPinsMapPinMixin.OnClick(pin, "RightButton")
            assert(tracked == nil)
            ForeverQuestPinsMapPinMixin.OnClick(pin, "LeftButton")
            assert(tracked == 101)
            assert(not ns.IsQuestHidden(101) and not ns.IsQuestHidden(102))
        """)


if __name__ == "__main__":
    unittest.main()
