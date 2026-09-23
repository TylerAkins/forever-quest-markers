#!/usr/bin/env python3
"""Tests for the ATT Forever quest-database converter."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))

from att_dsl.constants import BuildContext, DEFAULT_FOREVER_PATCH
from att_dsl.emit import emit_lua_database
from att_dsl.evaluator import evaluate_chunk, new_environment
from att_dsl.extract import ExtractResult, extract_from_roots, mark_attunement_chains
from att_dsl.parser import ParseError, parse_lua
from att_dsl.preprocessor import preprocess


FIXTURES = ROOT / "tests" / "fixtures"


def _ctx() -> BuildContext:
    return BuildContext(
        patch=DEFAULT_FOREVER_PATCH,
        maps={
            "ZEPHRAS_ISLE": 2521,
            "EASTERN_KINGDOMS": 1415,
            "ELWYNN_FOREST": 1429,
            "NORTHSHIRE_VALLEY": 425,
            "DUN_MOROGH": 1426,
            "ORGRIMMAR": 1454,
            "MULGORE": 1412,
        },
        timelines={"ADDED_1_60_1": "added 1.60.1.69893"},
    )


def _extract_fixture(name: str) -> ExtractResult:
    path = FIXTURES / name
    source = preprocess(path.read_text(encoding="utf-8"), _ctx())
    chunk = parse_lua(source, filename=name)
    env = new_environment(_ctx())
    evaluate_chunk(chunk, env)
    result = ExtractResult()
    extract_from_roots(env.get("_roots", []), name, result)
    return result


class PreprocessorTests(unittest.TestCase):
    def test_forever_keeps_before_cata_and_drops_sod(self) -> None:
        result = _extract_fixture("preprocessor.lua")
        self.assertIn(1001, result.quests)
        self.assertEqual(result.quests[1001].faction, "Alliance")
        self.assertIn(1003, result.quests)
        self.assertNotIn(1002, result.quests)


class ParserFailureTests(unittest.TestCase):
    def test_malformed_table_fails_loudly(self) -> None:
        with self.assertRaises(ParseError):
            parse_lua("q(1, { qg = 2, ", filename="broken.lua")


class RecipeHelperTests(unittest.TestCase):
    def test_profession_recipe_helper_calls_do_not_emit_roots(self) -> None:
        env = new_environment(_ctx())
        source = "local i = GetRecipeHelperForProfession(ALCHEMY); i(0, 2259);"

        evaluate_chunk(parse_lua(source, filename="alchemy.lua"), env)

        self.assertEqual([], env["_roots"])


class RequiredSkillTests(unittest.TestCase):
    def test_required_skill_is_preserved_and_emitted(self) -> None:
        env = new_environment(_ctx())
        source = 'q(90003, { qg=100, coord={10, 20, MAP.ELWYNN_FOREST}, requireSkill=TAILORING })'
        evaluate_chunk(parse_lua(source, filename="profession.lua"), env)
        result = ExtractResult()
        extract_from_roots(env.get("_roots", []), "profession.lua", result)

        self.assertEqual(result.quests[90003].required_skill, 197)
        self.assertRegex(
            emit_lua_database(result.quests, "abc123"),
            r"\[90003\] = \{[^\n]*requireSkill=197",
        )

    def test_unknown_required_skill_is_retained_symbolically(self) -> None:
        env = new_environment(_ctx())
        source = 'q(90004, { qg=100, coord={10, 20, MAP.ELWYNN_FOREST}, requireSkill=NEW_PROFESSION })'
        evaluate_chunk(parse_lua(source, filename="profession.lua"), env)
        result = ExtractResult()
        extract_from_roots(env.get("_roots", []), "profession.lua", result)

        self.assertEqual(result.quests[90004].required_skill, "NEW_PROFESSION")
        self.assertIn('requireSkill="NEW_PROFESSION"', emit_lua_database(result.quests, "abc123"))


class ZephrasTests(unittest.TestCase):
    def test_inherits_zone_races_and_map(self) -> None:
        result = _extract_fixture("zephras.lua")
        self.assertEqual(set(result.quests), {92460, 92461, 92462})
        start = result.quests[92460]
        self.assertEqual(start.coords[0].map_id, 2521)
        self.assertAlmostEqual(start.coords[0].x, 42.8)
        self.assertAlmostEqual(start.coords[0].y, 23.4)
        self.assertEqual(start.qgs, [251362])
        self.assertEqual(start.unresolved_races, ["SKYBORNE_ALLIANCE", "SKYBORNE_HORDE"])
        follow = result.quests[92461]
        self.assertEqual(follow.source_quests, [92460])
        self.assertAlmostEqual(follow.coords[0].x, 42.1)


class ElwynnTests(unittest.TestCase):
    def test_alliance_and_class_restrictions(self) -> None:
        result = _extract_fixture("elwynn.lua")
        threat = result.quests[783]
        self.assertEqual(threat.faction, "Alliance")
        self.assertEqual(threat.qgs, [823])

        paladin = result.quests[3101]
        self.assertEqual(paladin.races, [1])
        self.assertEqual(paladin.classes, [2])
        self.assertEqual(paladin.qgs, [197])
        self.assertEqual(paladin.source_quests, [7])

    def test_objective_coords_are_not_used_as_start_pins(self) -> None:
        result = _extract_fixture("elwynn.lua")
        bounty = result.quests[6]
        self.assertEqual(len(bounty.coords), 1)
        self.assertAlmostEqual(bounty.coords[0].x, 48.1)
        self.assertAlmostEqual(bounty.coords[0].y, 42.9)
        self.assertEqual(bounty.min_level, 2)

    def test_or_source_quests_and_alt_quests(self) -> None:
        result = _extract_fixture("elwynn.lua")
        either = result.quests[90001]
        self.assertEqual(either.source_quests, [10, 11, 12])
        self.assertEqual(either.source_quest_num_required, 1)
        warlock = result.quests[1599]
        self.assertEqual(warlock.alt_quests, [1598])
        self.assertEqual(warlock.coords[0].map_id, 1426)

    def test_item_started_without_coords_is_excluded(self) -> None:
        result = _extract_fixture("elwynn.lua")
        self.assertNotIn(90002, result.quests)
        self.assertGreaterEqual(result.excluded.get("no_coords", 0), 1)


class LocalAssignmentTests(unittest.TestCase):
    def test_altquests_from_local_table_and_level_range(self) -> None:
        result = _extract_fixture("locals.lua")
        quest = result.quests[8368]
        self.assertEqual(quest.alt_quests, [100, 101, 102])
        self.assertEqual(quest.faction, "Horde")
        self.assertEqual(quest.min_level, 10)
        self.assertEqual(quest.max_level, 19)


class EmitTests(unittest.TestCase):
    def test_lua_output_is_deterministic(self) -> None:
        result = _extract_fixture("zephras.lua")
        first = emit_lua_database(result.quests, "abc123")
        second = emit_lua_database(result.quests, "abc123")
        self.assertEqual(first, second)
        self.assertIn("ATT commit: abc123", first)
        self.assertIn("[92460]", first)
        self.assertIn("ns.ByMap", first)
        self.assertIn("[2521]", first)


class AttunementTests(unittest.TestCase):
    def test_instance_membership_is_inherited_but_not_leaked(self) -> None:
        env = new_environment(_ctx())
        evaluate_chunk(parse_lua('root(1, { inst(226, { q(5723, { coord = {70, 31, 1456} }) }), q(999, { coord = {50, 50, 1456} }) })'), env)
        result = ExtractResult()
        extract_from_roots(env.get("_roots", []), "instance.lua", result)
        self.assertTrue(result.quests[5723].is_instance_quest)
        self.assertFalse(result.quests[999].is_instance_quest)
        self.assertIn("isInstanceQuest=true", emit_lua_database(result.quests, "abc123"))

    def test_instance_access_quests_mark_full_chains_and_alternatives(self) -> None:
        result = _extract_fixture("attunement.lua")
        marked = mark_attunement_chains(result.quests, result.attunement_quest_ids)

        self.assertEqual(result.attunement_quest_ids, {100, 200, 201})
        self.assertEqual(marked, {80, 81, 90, 100, 101, 200, 201})
        self.assertTrue(all(result.quests[quest_id].is_attunement for quest_id in marked))

    def test_faction_quest_data_wrappers_are_extracted(self) -> None:
        result = _extract_fixture("attunement.lua")

        self.assertIn(200, result.quests)
        self.assertIn(201, result.quests)
        self.assertEqual(result.quests[200].coords[0].map_id, 1429)
        self.assertEqual(result.quests[201].coords[0].map_id, 1454)

    def test_attunement_flag_is_emitted(self) -> None:
        result = _extract_fixture("attunement.lua")
        mark_attunement_chains(result.quests, result.attunement_quest_ids)

        output = emit_lua_database(result.quests, "abc123")
        self.assertRegex(output, r"\[100\] = \{[^\n]*isAttunement=true")


class CheckoutTests(unittest.TestCase):
    def test_sparse_checkout_supports_file_paths(self) -> None:
        script = (TOOLS / "build_quest_db.py").read_text(encoding="utf-8")
        self.assertIn('"sparse-checkout",\n            "set",\n            "--no-cone",', script)


class MulgoreTimelineTests(unittest.TestCase):
    def test_pre_cata_quests_kept_and_holiday_flagged(self) -> None:
        result = _extract_fixture("mulgore.lua")
        self.assertIn(754, result.quests)
        self.assertIn(748, result.quests)
        self.assertNotIn(24440, result.quests)
        winterhoof = result.quests[754]
        self.assertEqual(winterhoof.coords[0].map_id, 1412)
        self.assertAlmostEqual(winterhoof.coords[0].x, 48.5)
        self.assertAlmostEqual(winterhoof.coords[0].y, 60.4)
        self.assertEqual(winterhoof.qgs, [2948])
        self.assertEqual(winterhoof.source_quests, [748])
        elder = result.quests[8673]
        self.assertTrue(elder.is_yearly)
        self.assertAlmostEqual(elder.coords[0].x, 48.4)
        self.assertAlmostEqual(elder.coords[0].y, 53.2)


if __name__ == "__main__":
    unittest.main()
