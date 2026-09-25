#!/usr/bin/env python3
"""Emitter tests for the Wowhead quest database."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.quest_db.emit_wowhead import emit_database, emit_lua_database


def _write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


class EmitWowheadTests(unittest.TestCase):
    def test_npc_object_and_unmapped_zone(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write(
                root / "quest_index.json",
                {
                    "10": {
                        "id": 10,
                        "name": "Find the Bowl",
                        "pinCategory": "normal",
                        "sourceKinds": ["zone"],
                        "sourceSlugs": ["ek/elwynn-forest"],
                        "faction": "Alliance",
                        "minLevel": 2,
                    },
                    "11": {
                        "id": 11,
                        "name": "Camping 101: Alchemy",
                        "pinCategory": "repeatable",
                        "sourceKinds": ["world_event"],
                        "sourceSlugs": ["event/lunar-festival"],
                        "minLevel": 4,
                    },
                    "12": {
                        "id": 12,
                        "name": "No Map",
                        "pinCategory": "pvp",
                        "sourceKinds": ["battleground"],
                        "sourceSlugs": ["bg/warsong-gulch"],
                    },
                },
            )
            _write(
                root / "object" / "5.json",
                {
                    "spawns": [
                        {"zoneId": 12, "uiMapId": 1429, "x": 1, "y": 2},
                    ]
                },
            )
            _write(
                root / "details" / "10.json",
                {
                    "questId": 10,
                    "pinCategory": "instance",
                    "faction": "Alliance",
                    "infoboxMarkup": (
                        "[icon name=quest-end]End: [url=/forever/npc=240/deputy-rainer]"
                        "Deputy Rainer[/url][/icon]"
                        "[icon name=quest-end]End: [url=/forever/npc=241/marshal-dughan]"
                        "Marshal Dughan[/url][/icon]"
                    ),
                    "races": [],
                    "classes": [1],
                    "minLevel": 2,
                    "mapper": {
                        "objectives": {
                            "12": {
                                "levels": [
                                    [
                                        {
                                            "point": "start",
                                            "type": 1,
                                            "id": 197,
                                            "name": "Marshal McBride",
                                            "coord": [48.1, 42.9],
                                            "coords": [[1, 1], [48.1, 42.9]],
                                        },
                                        {
                                            "point": "start",
                                            "type": 2,
                                            "id": 5,
                                            "name": "Bowl",
                                            "coord": [10, 20],
                                            "coords": [[10, 20], [11, 21]],
                                        },
                                        {
                                            "point": "end",
                                            "type": 1,
                                            "id": 240,
                                            "name": "Deputy Rainer",
                                            "coord": [24, 74],
                                        },
                                        {
                                            "point": "end",
                                            "type": 2,
                                            "id": 55,
                                            "name": "Crate",
                                            "coord": [25, 75],
                                        },
                                    ]
                                ]
                            }
                        }
                    },
                },
            )
            _write(
                root / "details" / "11.json",
                {
                    "questId": 11,
                    "pinCategory": "repeatable",
                    "mapper": {
                        "objectives": {
                            "4": {
                                "levels": [
                                    [
                                        {
                                            "point": "start",
                                            "type": 1,
                                            "id": 9,
                                            "coord": [51.8, 35.6],
                                        }
                                    ]
                                ]
                            }
                        }
                    },
                },
            )
            _write(
                root / "details" / "12.json",
                {
                    "questId": 12,
                    "pinCategory": "pvp",
                    "mapper": {
                        "objectives": {
                            "99999": {
                                "levels": [
                                    [
                                        {
                                            "point": "start",
                                            "type": 1,
                                            "id": 1,
                                            "coord": [5, 5],
                                        }
                                    ]
                                ]
                            }
                        }
                    },
                },
            )

            quests, stats = emit_database(root)

        self.assertEqual(stats["quests_emitted"], 2)
        self.assertEqual(stats["skipped_no_coords"], 1)
        bowl = quests[10]
        self.assertEqual(bowl["coords"][0], (10.0, 20.0, 1429))
        self.assertIn((11.0, 21.0, 1429), bowl["coords"])
        self.assertNotIn((1.0, 1.0, 1429), bowl["coords"])
        self.assertEqual(bowl["npcs"], [197])
        self.assertEqual(bowl["end_npcs"], [240, 241])
        self.assertTrue(bowl["is_instance_quest"])
        self.assertEqual(bowl["classes"], [1])
        camping = quests[11]
        self.assertEqual(camping["coords"], [(51.8, 35.6, 1419)])
        self.assertTrue(camping["repeatable"])
        self.assertTrue(camping["is_yearly"])
        self.assertEqual(camping["require_skill"], 171)
        lua = emit_lua_database(quests)
        self.assertIn("[10] = { mapID=1429", lua)
        self.assertIn("qg=197", lua)
        self.assertIn("endNpcs={ 240, 241 }", lua)
        self.assertIn("isInstanceQuest=true", lua)
        self.assertNotIn("[12] =", lua)
        self.assertIn("requireSkill=171", lua)
        self.assertIn("isYearly=true", lua)


if __name__ == "__main__":
    unittest.main()
