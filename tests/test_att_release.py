#!/usr/bin/env python3
"""Tests for automated ATT database release preparation."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "att_release.py"
SPEC = importlib.util.spec_from_file_location("att_release", SCRIPT)
assert SPEC and SPEC.loader
ATT_RELEASE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = ATT_RELEASE
SPEC.loader.exec_module(ATT_RELEASE)


class AttReleaseTests(unittest.TestCase):
    def test_prepare_bumps_patch_and_adds_changelog_entry(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._repository_fixture(Path(temp_dir))

            version = ATT_RELEASE.prepare_att_release(
                root,
                base_version="0.1.21",
                release_date="2026-09-20",
            )

            self.assertEqual("0.1.22", str(version))
            self.assertEqual("0.1.22\n", (root / "VERSION").read_text(encoding="utf-8"))
            changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
            self.assertIn("## 0.1.22 - 2026-09-20", changelog)
            self.assertIn("`abc123`", changelog)
            self.assertLess(changelog.index("## 0.1.22"), changelog.index("## 0.1.21"))

    def test_prepare_is_idempotent_for_the_same_base_version(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._repository_fixture(Path(temp_dir))
            for _ in range(2):
                ATT_RELEASE.prepare_att_release(
                    root,
                    base_version="0.1.21",
                    release_date="2026-09-20",
                )

            changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
            self.assertEqual(1, changelog.count("## 0.1.22"))
            self.assertEqual("0.1.22\n", (root / "VERSION").read_text(encoding="utf-8"))

    def test_dry_run_does_not_write_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._repository_fixture(Path(temp_dir))
            before_version = (root / "VERSION").read_text(encoding="utf-8")
            before_changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")

            version = ATT_RELEASE.prepare_att_release(
                root,
                base_version="0.1.21",
                release_date="2026-09-20",
                dry_run=True,
            )

            self.assertEqual("0.1.22", str(version))
            self.assertEqual(before_version, (root / "VERSION").read_text(encoding="utf-8"))
            self.assertEqual(before_changelog, (root / "CHANGELOG.md").read_text(encoding="utf-8"))

    def test_invalid_or_stale_versions_fail(self) -> None:
        with self.assertRaisesRegex(ValueError, "Invalid stable version"):
            ATT_RELEASE.Version.parse("v0.1.21")

        with tempfile.TemporaryDirectory() as temp_dir:
            root = self._repository_fixture(Path(temp_dir), version="0.1.20")
            with self.assertRaisesRegex(ValueError, "released version 0.1.21"):
                ATT_RELEASE.prepare_att_release(
                    root,
                    base_version="0.1.21",
                    release_date="2026-09-20",
                )

    def test_merge_release_requires_exact_patch_and_quest_change(self) -> None:
        self.assertIsNone(
            ATT_RELEASE.plan_merged_release(
                "0.1.21",
                "0.1.21",
                quest_data_changed=False,
            )
        )
        self.assertEqual(
            "v0.1.22",
            ATT_RELEASE.plan_merged_release(
                "0.1.21",
                "0.1.22",
                quest_data_changed=True,
            ),
        )
        with self.assertRaisesRegex(ValueError, "must advance"):
            ATT_RELEASE.plan_merged_release(
                "0.1.21",
                "0.1.23",
                quest_data_changed=True,
            )
        with self.assertRaisesRegex(ValueError, "must advance"):
            ATT_RELEASE.plan_merged_release(
                "0.1.21",
                "0.1.21",
                quest_data_changed=True,
            )

    def test_tag_plan_creates_reuses_and_rejects_collisions(self) -> None:
        self.assertEqual("create", ATT_RELEASE.plan_tag(None, "abc123"))
        self.assertEqual("reuse", ATT_RELEASE.plan_tag("abc123", "abc123"))
        with self.assertRaisesRegex(ValueError, "already points"):
            ATT_RELEASE.plan_tag("def456", "abc123")

    @staticmethod
    def _repository_fixture(root: Path, *, version: str = "0.1.21") -> Path:
        (root / "Database").mkdir()
        (root / "VERSION").write_text(f"{version}\n", encoding="utf-8")
        (root / "CHANGELOG.md").write_text(
            "# Changelog\n\nNotable changes.\n\n## 0.1.21 - 2026-09-19\n\n- Existing release.\n",
            encoding="utf-8",
        )
        (root / "Database" / "build_report.json").write_text(
            json.dumps(
                {
                    "att_sha": "abc123",
                    "quests_emitted": 3501,
                    "coord_pins": 3725,
                    "map_count": 68,
                }
            ),
            encoding="utf-8",
        )
        return root


if __name__ == "__main__":
    unittest.main()
