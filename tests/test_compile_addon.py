#!/usr/bin/env python3
"""Tests for the local addon compiler."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "compile_addon.py"
SPEC = importlib.util.spec_from_file_location("compile_addon", SCRIPT)
assert SPEC and SPEC.loader
COMPILE_ADDON = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILE_ADDON)


class CompileAddonTests(unittest.TestCase):
    def test_build_is_clean_and_installable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "ForeverQuestPins"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("remove me", encoding="utf-8")

            built = COMPILE_ADDON.compile_addon(output)

            self.assertFalse(stale.exists())
            self.assertIn(output / "ForeverQuestPins.toc", built)
            self.assertTrue((output / "Database" / "ForeverQuests.lua").is_file())
            self.assertTrue((output / "Media" / "QuestAvailable.tga").is_file())
            self.assertFalse((output / "Database" / "build_report.json").exists())
            self.assertNotIn(
                "@project-version@",
                (output / "ForeverQuestPins.toc").read_text(encoding="utf-8"),
            )

    def test_dry_run_does_not_replace_existing_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "ForeverQuestPins"
            stale = output / "stale.txt"
            stale.parent.mkdir(parents=True)
            stale.write_text("keep me", encoding="utf-8")

            built = COMPILE_ADDON.compile_addon(output, dry_run=True)

            self.assertTrue(stale.exists())
            self.assertIn(output / "ForeverQuestPins.toc", built)


if __name__ == "__main__":
    unittest.main()
