"""Exercise the tracker menu and copy dialog with Forever UI doubles."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


class QuestLinkTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            ns = {}
            CLOSE = "Close"
            StaticPopupDialogs = {}
            editBox = {
                SetText = function(_, text) copiedText = text end,
                SetFocus = function() focused = true end,
                HighlightText = function() selected = true end,
            }
            StaticPopup_Show = function(name, _, _, data)
                local dialog = { GetEditBox = function() return editBox end }
                StaticPopupDialogs[name].OnShow(dialog, data)
                return dialog
            end
        """)
        self.lua.execute((ROOT / "QuestLinks.lua").read_text(), "ForeverQuestPins", self.lua.globals().ns)

    def test_url_selection_and_validation(self):
        self.lua.execute("""
            assert(ns.ShowWowheadQuestURL(8383))
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            assert(focused and selected)
            for _, id in ipairs({ 0, -1, 1.5, "8383", math.huge, 0/0 }) do
                assert(not ns.ShowWowheadQuestURL(id))
            end
            assert(not ns.ShowWowheadQuestURL(nil))
            assert(ns.ShowWowheadQuestURL(6))
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")
        """)

    def test_delayed_registration_menu_scope_and_captured_quest(self):
        self.lua.execute("""
            assert(not ns.TryRegisterQuestLinks())
            local owner = {}
            local hooks = {}
            local registrations = 0
            QuestObjectiveTracker = {
                OnBlockHeaderEnter = function() end,
                OnBlockHeaderLeave = function() end,
                GetContextMenuParent = function() return owner end,
            }
            hooksecurefunc = function(_, name, callback) hooks[name] = callback end
            Menu = { ModifyMenu = function(tag, callback)
                assert(tag == "MENU_QUEST_OBJECTIVE_TRACKER")
                registrations = registrations + 1
                modify = callback
            end }
            assert(ns.TryRegisterQuestLinks())
            assert(ns.TryRegisterQuestLinks() and registrations == 1)
            local buttons = {}
            local root = {
                CreateDivider = function() end,
                CreateButton = function(_, label, callback)
                    assert(label == "Copy Wowhead URL")
                    table.insert(buttons, callback)
                end,
            }
            modify(owner, root)
            assert(#buttons == 0)
            local block = { id = 8383 }
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify({}, root)
            assert(#buttons == 0)
            modify(owner, root)
            assert(#buttons == 1)
            block.id = 6
            hooks.OnBlockHeaderLeave(QuestObjectiveTracker, block)
            buttons[1]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=8383")
            modify(owner, root)
            assert(#buttons == 1)
            hooks.OnBlockHeaderEnter(QuestObjectiveTracker, block)
            modify(owner, root)
            buttons[2]()
            assert(copiedText == "https://www.wowhead.com/forever/quest=6")
        """)


if __name__ == "__main__":
    unittest.main()
