#!/usr/bin/env python3
"""Lightweight checks for runtime Lua files."""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA_FILES = [
    "Config.lua",
    "Eligibility.lua",
    "MapPins.lua",
    "Core.lua",
    "Database/Metadata.lua",
    "Database/ForeverQuests.lua",
]


class AddonLuaTests(unittest.TestCase):
    def test_toc_load_order(self) -> None:
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("## Interface: 16001", toc)
        self.assertIn("## SavedVariables: ForeverQuestPinsDB_Settings", toc)
        self.assertNotIn("ForeverQuestPinsDB\n", toc)
        for name in LUA_FILES:
            self.assertIn(name.replace("/", "\\"), toc)

    def test_single_savedvariables_name(self) -> None:
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("ForeverQuestPinsDB_Settings", toc)
        forever = (ROOT / "Database" / "ForeverQuests.lua").read_text(encoding="utf-8")
        self.assertNotIn("ForeverQuestPinsDB_Settings", forever)

    def test_balanced_braces_and_addon_table(self) -> None:
        for rel in LUA_FILES:
            text = (ROOT / rel).read_text(encoding="utf-8")
            self.assertEqual(text.count("{"), text.count("}"), f"{rel} braces")
            self.assertEqual(text.count("("), text.count(")"), f"{rel} parens")
            self.assertIn("local ADDON_NAME, ns = ...", text)

    def test_eligibility_function_exists(self) -> None:
        text = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.IsQuestAvailable(questID, data)", text)
        self.assertIn("sourceQuestNumRequired", text)

    def test_no_herebedragons_or_att_runtime_dep(self) -> None:
        combined = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in LUA_FILES)
        self.assertNotIn("HereBeDragons", combined)
        self.assertNotIn("LibStub", combined)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertNotIn("OptionalDeps", toc)
        self.assertNotIn("RequiredDeps", toc)


if __name__ == "__main__":
    unittest.main()
