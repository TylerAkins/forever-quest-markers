#!/usr/bin/env python3
"""Build Database/ForeverQuests.lua from data/forever-quests (Wowhead)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.quest_db.emit_wowhead import emit_database, write_outputs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data",
        type=Path,
        default=ROOT / "data" / "forever-quests",
        help="Wowhead quest database directory",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ROOT / "Database",
        help="Directory for ForeverQuests.lua, Metadata.lua, and build_report.json",
    )
    args = parser.parse_args(argv)
    if not (args.data / "quest_index.json").is_file():
        raise SystemExit(f"Wowhead quest index not found: {args.data / 'quest_index.json'}")
    quests, stats = emit_database(args.data)
    write_outputs(args.out, quests, stats)
    print(f"Wrote {stats['quests_emitted']} quests, {stats['coord_pins']} pins, {stats['map_count']} maps")
    print(f"Skipped {stats['skipped_no_coords']} quests with no mappable start")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
