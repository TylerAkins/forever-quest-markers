#!/usr/bin/env python3
"""Prepare and validate patch releases for automated ATT database updates."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


@dataclass(frozen=True, order=True)
class Version:
    major: int
    minor: int
    patch: int

    @classmethod
    def parse(cls, value: str) -> Version:
        match = VERSION_RE.fullmatch(value.strip())
        if not match:
            raise ValueError(f"Invalid stable version: {value!r}")
        return cls(*(int(part) for part in match.groups()))

    def next_patch(self) -> Version:
        return Version(self.major, self.minor, self.patch + 1)

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"


def plan_merged_release(
    previous_version: str,
    current_version: str,
    *,
    quest_data_changed: bool,
) -> str | None:
    """Return the release tag for a valid database merge, or no release."""
    if not quest_data_changed:
        return None

    previous = Version.parse(previous_version)
    current = Version.parse(current_version)
    expected = previous.next_patch()
    if current != expected:
        raise ValueError(
            f"Quest data changed, but VERSION must advance from {previous} to {expected}; "
            f"found {current}"
        )
    return f"v{current}"


def plan_tag(existing_sha: str | None, target_sha: str) -> str:
    """Return whether to create or reuse a tag, rejecting collisions."""
    if not target_sha:
        raise ValueError("Target tag commit SHA is required")
    if existing_sha is None:
        return "create"
    if existing_sha != target_sha:
        raise ValueError(
            f"Tag already points to {existing_sha}, not target commit {target_sha}"
        )
    return "reuse"


def prepare_att_release(
    root: Path,
    *,
    base_version: str,
    release_date: str,
    dry_run: bool = False,
) -> Version:
    """Prepare VERSION and CHANGELOG.md for one idempotent patch release."""
    version_path = root / "VERSION"
    changelog_path = root / "CHANGELOG.md"
    report_path = root / "Database" / "build_report.json"

    base = Version.parse(base_version)
    target = base.next_patch()
    current = Version.parse(version_path.read_text(encoding="utf-8"))
    if current not in {base, target}:
        raise ValueError(
            f"VERSION must be the released version {base} or prepared version {target}; "
            f"found {current}"
        )

    report = json.loads(report_path.read_text(encoding="utf-8"))
    entry = _changelog_entry(target, release_date, report)
    changelog = _replace_or_insert_entry(
        changelog_path.read_text(encoding="utf-8"),
        target,
        entry,
    )

    if not dry_run:
        version_path.write_text(f"{target}\n", encoding="utf-8")
        changelog_path.write_text(changelog, encoding="utf-8")
    return target


def _changelog_entry(version: Version, release_date: str, report: dict[str, object]) -> str:
    sha = _required_string(report, "att_sha")
    quests = _required_int(report, "quests_emitted")
    coordinates = _required_int(report, "coord_pins")
    maps = _required_int(report, "map_count")
    return (
        f"## {version} - {release_date}\n\n"
        f"- Update the ATT Forever quest database to `{sha}`.\n"
        f"- Ship {quests} quests with {coordinates} coordinate pins across {maps} maps.\n"
    )


def _replace_or_insert_entry(changelog: str, version: Version, entry: str) -> str:
    version_heading = re.compile(
        rf"^## {re.escape(str(version))}(?:\s+[-—].*)?\n.*?(?=^## |\Z)",
        re.MULTILINE | re.DOTALL,
    )
    if version_heading.search(changelog):
        return version_heading.sub(entry.rstrip() + "\n\n", changelog, count=1)

    first_release = re.search(r"^## \d+\.\d+\.\d+", changelog, re.MULTILINE)
    if not first_release:
        raise ValueError("CHANGELOG.md has no release heading")
    return changelog[: first_release.start()] + entry + "\n" + changelog[first_release.start() :]


def _required_string(report: dict[str, object], key: str) -> str:
    value = report.get(key)
    if not isinstance(value, str) or not value:
        raise ValueError(f"Database/build_report.json is missing string field {key!r}")
    return value


def _required_int(report: dict[str, object], key: str) -> int:
    value = report.get(key)
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError(f"Database/build_report.json is missing integer field {key!r}")
    return value


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare", help="prepare the next ATT patch release")
    prepare.add_argument("--base-version", required=True)
    prepare.add_argument("--root", type=Path, default=ROOT)
    prepare.add_argument("--date", default=datetime.now(UTC).date().isoformat())
    prepare.add_argument("--dry-run", action="store_true")

    validate = subparsers.add_parser("validate", help="validate a merged ATT release")
    validate.add_argument("--previous-version", required=True)
    validate.add_argument("--current-version", required=True)
    validate.add_argument("--quest-data-changed", action="store_true")

    validate_tag = subparsers.add_parser(
        "validate-tag",
        help="decide whether an automated release tag is safe to create or reuse",
    )
    validate_tag.add_argument("--existing-sha")
    validate_tag.add_argument("--target-sha", required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.command == "prepare":
        version = prepare_att_release(
            args.root,
            base_version=args.base_version,
            release_date=args.date,
            dry_run=args.dry_run,
        )
        print(version)
        return 0

    if args.command == "validate":
        tag = plan_merged_release(
            args.previous_version,
            args.current_version,
            quest_data_changed=args.quest_data_changed,
        )
        if tag:
            print(tag)
        return 0

    print(plan_tag(args.existing_sha, args.target_sha))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
