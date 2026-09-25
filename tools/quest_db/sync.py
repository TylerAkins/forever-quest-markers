"""Orchestrate Source list + quest detail synchronization."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Protocol

from .classify import classify_pin_category
from .http import quest_detail_url


class _HtmlClient(Protocol):
    def get_html(self, url: str, *, force: bool = False) -> str: ...
from .ingest import ingest_html
from .parse_quest import eligibility_restrictions, extract_start_pins, parse_quest_detail
from .sources import SOURCE_PAGES
from .store import load_manifest, save_manifest, utc_now_iso, write_json
from .zone_resolver import bootstrap_zone_ui_map_ids


def sync_sources(
    data_root: Path,
    client: _HtmlClient,
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
    client: _HtmlClient,
    *,
    limit: int | None = None,
    quest_ids: list[int] | None = None,
    force: bool = False,
    attunement_seed_path: Path | None = None,
) -> dict[str, Any]:
    manifest = load_manifest(data_root)
    index_path = data_root / "quest_index.json"
    if not index_path.is_file():
        raise SystemExit("quest_index.json missing; run sync-sources or ingest list URLs first")

    quest_index: dict[str, Any] = json.loads(index_path.read_text(encoding="utf-8"))
    details_dir = data_root / "details"
    details_dir.mkdir(parents=True, exist_ok=True)
    errors_path = data_root / "fetch_errors.jsonl"

    attunement_ids = _load_attunement_ids(data_root, attunement_seed_path)

    processed = 0
    skipped_errors = 0
    wanted = {str(qid) for qid in quest_ids} if quest_ids else None
    pending = [
        qid
        for qid in sorted(quest_index.keys(), key=int)
        if (wanted is None or qid in wanted)
        and (force or not (details_dir / f"{qid}.json").is_file())
    ]
    if limit is not None:
        pending = pending[:limit]
    print(
        f"quest details: {len(quest_index) - len(pending)} already saved, {len(pending)} to fetch",
        flush=True,
    )

    for index, qid in enumerate(pending, start=1):
        detail_path = details_dir / f"{qid}.json"
        entry = quest_index[qid]
        url = quest_detail_url(int(qid), entry.get("name"))
        print(f"[{index}/{len(pending)}] {url}", flush=True)
        try:
            html = client.get_html(url, force=force)
        except Exception as exc:  # noqa: BLE001 — log and continue batch
            skipped_errors += 1
            print(f"  failed: {exc}", flush=True)
            with errors_path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps({"questId": int(qid), "url": url, "error": str(exc)}) + "\n")
            continue

        detail = parse_quest_detail(html, int(qid))
        detail["fetchedAt"] = utc_now_iso()
        detail["startPins"] = extract_start_pins(detail.get("mapper"))

        pin_category = classify_pin_category(
            source_kinds=set(entry.get("sourceKinds") or []),
            list_row=entry.get("list"),
            detail_flags=detail.get("infoboxFlags"),
            attunement_ids=attunement_ids,
            quest_id=int(qid),
        )
        detail["pinCategory"] = pin_category
        restrictions = eligibility_restrictions(detail.get("infoboxMarkup"), entry.get("list"))
        detail.update(restrictions)
        write_json(detail_path, detail)

        entry["pinCategory"] = pin_category
        entry.update(restrictions)
        entry["hasDetail"] = True
        entry["startPinCount"] = len(detail["startPins"])
        if detail["startPins"]:
            entry["primaryStart"] = detail["startPins"][0]
        processed += 1
        print(
            f"  saved quest {qid} faction={restrictions.get('faction')} races={restrictions.get('races')} starts={len(detail['startPins'])}",
            flush=True,
        )

        if processed % 25 == 0:
            write_json(index_path, quest_index)
            manifest["stats"]["questDetailCount"] = len(list(details_dir.glob("*.json")))
            save_manifest(data_root, manifest)

    manifest["stats"]["questDetailCount"] = len(list(details_dir.glob("*.json")))
    manifest["stats"]["questIndexCount"] = len(quest_index)
    manifest["stats"]["questDetailFetchErrors"] = skipped_errors
    manifest["lastFullSyncCompleted"] = utc_now_iso()
    write_json(index_path, quest_index)
    save_manifest(data_root, manifest)
    return manifest


def backfill_eligibility(data_root: Path) -> int:
    """Fill faction/races/classes/minLevel on detail files already downloaded."""
    index_path = data_root / "quest_index.json"
    quest_index: dict[str, Any] = {}
    if index_path.is_file():
        quest_index = json.loads(index_path.read_text(encoding="utf-8"))

    updated = 0
    details_dir = data_root / "details"
    for path in details_dir.glob("*.json"):
        detail = json.loads(path.read_text(encoding="utf-8"))
        qid = str(detail.get("questId") or path.stem)
        entry = quest_index.get(qid, {})
        restrictions = eligibility_restrictions(detail.get("infoboxMarkup"), entry.get("list"))
        detail.update(restrictions)
        write_json(path, detail)
        if entry:
            entry.update(restrictions)
            quest_index[qid] = entry
        updated += 1

    if quest_index:
        write_json(index_path, quest_index)
    return updated


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
    return set()
