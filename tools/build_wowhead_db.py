#!/usr/bin/env python3
"""Build and refresh the Wowhead-sourced Forever quest database."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from wowhead_db.http import WowheadClient
from wowhead_db.sync import rebuild_zone_map, sync_quest_details, sync_sources

DEFAULT_DATA_ROOT = ROOT / "data" / "wowhead"
DEFAULT_CACHE = ROOT / ".cache" / "wowhead-html"
DEFAULT_ATT_QUESTS = ROOT / "Database" / "ForeverQuests.lua"


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    data_root = Path(args.data_root)
    data_root.mkdir(parents=True, exist_ok=True)

    client = WowheadClient(
        cache_dir=Path(args.cache_dir),
        min_interval_s=args.delay,
    )

    if args.command == "sync-sources":
        sync_sources(data_root, client, force=args.force)
        if args.rebuild_zone_map:
            rebuild_zone_map(data_root, Path(args.att_quests))
        return 0

    if args.command == "sync-quests":
        sync_quest_details(
            data_root,
            client,
            limit=args.limit,
            force=args.force,
            attunement_seed_path=Path(args.attunement_seed) if args.attunement_seed else None,
        )
        if args.rebuild_zone_map:
            rebuild_zone_map(data_root, Path(args.att_quests))
        return 0

    if args.command == "rebuild-zone-map":
        rebuild_zone_map(data_root, Path(args.att_quests))
        return 0

    raise SystemExit(f"Unknown command: {args.command}")


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=("sync-sources", "sync-quests", "rebuild-zone-map"),
        help="sync-sources: index pages only; sync-quests: per-quest detail pages",
    )
    parser.add_argument("--data-root", default=str(DEFAULT_DATA_ROOT))
    parser.add_argument("--cache-dir", default=str(DEFAULT_CACHE))
    parser.add_argument(
        "--delay",
        type=float,
        default=1.25,
        help="Minimum seconds between uncached Wowhead HTTP requests",
    )
    parser.add_argument("--force", action="store_true", help="Ignore HTML cache / re-fetch")
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max quest detail pages to fetch (default: all missing)",
    )
    parser.add_argument(
        "--rebuild-zone-map",
        action="store_true",
        help="After sync, refresh data/wowhead/zone_ui_map_ids.json from ATT pins",
    )
    parser.add_argument("--att-quests", default=str(DEFAULT_ATT_QUESTS))
    parser.add_argument(
        "--attunement-seed",
        default=None,
        help="JSON list of attunement quest IDs (defaults to data/wowhead/attunement_quest_ids.json)",
    )
    return parser.parse_args(argv)


if __name__ == "__main__":
    raise SystemExit(main())
