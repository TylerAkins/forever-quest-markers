#!/usr/bin/env python3
"""Tests for Wowhead database parsers (offline fixtures)."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))

from wowhead_db.classify import classify_pin_category
from wowhead_db.parse_list import parse_quest_list
from wowhead_db.parse_quest import extract_start_pins, parse_quest_detail

FIXTURES = ROOT / "tests" / "fixtures" / "wowhead"


class ParseListTests(unittest.TestCase):
    def test_elwynn_listview_extracts_quest_rows(self) -> None:
        html = (FIXTURES / "elwynn-forest.html").read_text(encoding="utf-8")
        rows = parse_quest_list(html)
        self.assertGreater(len(rows), 10)
        ids = {row["id"] for row in rows}
        self.assertIn(6, ids)
        self.assertIn(16, ids)


class ParseQuestTests(unittest.TestCase):
    def test_quest_mapper_start_pin(self) -> None:
        html = (FIXTURES / "quest-6.html").read_text(encoding="utf-8")
        detail = parse_quest_detail(html, 6)
        pins = extract_start_pins(detail["mapper"])
        self.assertEqual(1, len(pins))
        self.assertEqual(823, pins[0]["npcId"])
        self.assertAlmostEqual(48.2, pins[0]["x"])
        self.assertAlmostEqual(42.8, pins[0]["y"])

    def test_repeatable_flag_from_infobox(self) -> None:
        html = (FIXTURES / "quest-16.html").read_text(encoding="utf-8")
        detail = parse_quest_detail(html, 16)
        self.assertTrue(detail["infoboxFlags"].get("repeatable"))


class ClassifyTests(unittest.TestCase):
    def test_battleground_source_is_pvp(self) -> None:
        cat = classify_pin_category(
            source_kinds={"battleground"},
            list_row={"type": 41},
            detail_flags={},
        )
        self.assertEqual("pvp", cat)

    def test_dungeon_source_is_instance(self) -> None:
        cat = classify_pin_category(
            source_kinds={"dungeon"},
            list_row={},
            detail_flags={},
        )
        self.assertEqual("instance", cat)


if __name__ == "__main__":
    unittest.main()
