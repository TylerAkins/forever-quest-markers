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
        self.assertIn("function ns.HasQuestCompletionAPI()", text)

    def test_no_herebedragons_or_att_runtime_dep(self) -> None:
        combined = "\n".join((ROOT / rel).read_text(encoding="utf-8") for rel in LUA_FILES)
        self.assertNotIn("HereBeDragons", combined)
        self.assertNotIn("LibStub", combined)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertNotIn("OptionalDeps", toc)
        self.assertNotIn("RequiredDeps", toc)

    def test_pins_prefer_blizzard_quest_icon(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        atlas_at = text.find('ICON_ATLAS = "QuestNormal"')
        gossip_at = text.find("Interface\\\\GossipFrame\\\\AvailableQuestIcon")
        fallback_at = text.find("Media\\\\QuestAvailable")
        self.assertNotEqual(atlas_at, -1)
        self.assertNotEqual(gossip_at, -1)
        self.assertNotEqual(fallback_at, -1)
        self.assertLess(atlas_at, gossip_at)
        self.assertLess(gossip_at, fallback_at)
        self.assertIn("tex:SetAtlas(name, true)", text)
        self.assertIn("TrySetFile(tex, ICON_GOSSIP)", text)
        self.assertIn("TrySetFile(tex, ICON_FALLBACK)", text)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertNotIn('CreateFrame("Frame"):CreateTexture()', config)
        toc = (ROOT / "ForeverQuestPins.toc").read_text(encoding="utf-8")
        self.assertIn("Interface\\GossipFrame\\AvailableQuestIcon", toc)

    def test_seasonal_pins_are_opt_in(self) -> None:
        eligibility = (ROOT / "Eligibility.lua").read_text(encoding="utf-8")
        self.assertIn("function ns.IsEventActive(eventID)", eligibility)
        self.assertIn('return false, "seasonal"', eligibility)
        config = (ROOT / "Config.lua").read_text(encoding="utf-8")
        self.assertIn("showSeasonal = false", config)
        self.assertIn('msg == "seasonal"', config)

    def test_pins_try_every_known_map_on_the_viewed_canvas(self) -> None:
        text = (ROOT / "MapPins.lua").read_text(encoding="utf-8")
        self.assertIn("local function CandidateMapIDs(viewedMapID, byMap)", text)
        self.assertIn("for mapID in pairs(byMap) do", text)


if __name__ == "__main__":
    unittest.main()
