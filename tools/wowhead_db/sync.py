"""Orchestrate Wowhead list + quest detail synchronization."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .classify import classify_pin_category
from .http import WowheadClient
from .ingest import ingest_html
from .parse_quest import extract_start_pins, parse_quest_detail
from .sources import SOURCE_PAGES
from .store import load_manifest, save_manifest, utc_now_iso, write_json
from .zone_resolver import bootstrap_zone_ui_map_ids


def sync_sources(
    data_root: Path,
    client: WowheadClient,
    *,
    force: bool = False,
) -> dict[str, Any]:
    manifest = load_manifest(data_root)
    manifest["lastFullSyncStarted"] = utc_now_iso()
    save_manifest(data_root, manifest)

    for page in SOURCE_PAGES:
        html = client.get_html(page.url, force=force)
        ingest_html(data_root, page.url, html)

    manifest = load_manifest(data_root)
    manifest["stats"]["sourcePageCount"] = len(SOURCE_PAGES)
    manifest["lastFullSyncCompleted"] = utc_now_iso()
    save_manifest(data_root, manifest)
    return manifest


def sync_quest_details(
    data_root: Path,
    client: WowheadClient,
    *,
    limit: int | None = None,
    force: bool = False,
    attunement_seed_path: Path | None = None,
) -> dict[str, Any]:
    manifest = load_manifest(data_root)
    index_path = data_root / "quest_index.json"
    if not index_path.is_file():
        raise SystemExit("quest_index.json missing; run sync-sources first")

    quest_index: dict[str, Any] = json.loads(index_path.read_text(encoding="utf-8"))
    details_dir = data_root / "details"
    details_dir.mkdir(parents=True, exist_ok=True)

    attunement_ids = _load_attunement_ids(data_root, attunement_seed_path)

    processed = 0
    for qid in sorted(quest_index.keys(), key=int):
        if limit is not None and processed >= limit:
            break
        detail_path = details_dir / f"{qid}.json"
        if detail_path.is_file() and not force:
            continue

        url = f"https://www.wowhead.com/forever/quest={qid}"
        html = client.get_html(url, force=force)
        detail = parse_quest_detail(html, int(qid))
        detail["fetchedAt"] = utc_now_iso()
        detail["startPins"] = extract_start_pins(detail.get("mapper"))

        entry = quest_index[qid]
        pin_category = classify_pin_category(
            source_kinds=set(entry.get("sourceKinds") or []),
            list_row=entry.get("list"),
            detail_flags=detail.get("infoboxFlags"),
            attunement_ids=attunement_ids,
            quest_id=int(qid),
        )
        detail["pinCategory"] = pin_category
        write_json(detail_path, detail)

        entry["pinCategory"] = pin_category
        entry["hasDetail"] = True
        entry["startPinCount"] = len(detail["startPins"])
        if detail["startPins"]:
            entry["primaryStart"] = detail["startPins"][0]
        processed += 1

    manifest["stats"]["questDetailCount"] = sum(
        1 for path in details_dir.glob("*.json")
    )
    manifest["stats"]["questIndexCount"] = len(quest_index)
    manifest["lastFullSyncCompleted"] = utc_now_iso()
    write_json(index_path, quest_index)
    save_manifest(data_root, manifest)
    return manifest


def rebuild_zone_map(data_root: Path, att_quests_lua: Path) -> dict[str, Any]:
    index = json.loads((data_root / "quest_index.json").read_text(encoding="utf-8"))
    zone_map = bootstrap_zone_ui_map_ids(index, att_quests_lua)
    write_json(data_root / "zone_ui_map_ids.json", zone_map)
    return zone_map


def _load_attunement_ids(data_root: Path, seed_path: Path | None) -> set[int]:
    path = seed_path or (data_root / "attunement_quest_ids.json")
    if path.is_file():
        raw = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(raw, list):
            return {int(x) for x in raw}
    # Fallback: quests whose names in index suggest attunement (rare); keep empty by default.
    return set()
