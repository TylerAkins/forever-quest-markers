"""Parse Wowhead Forever quest detail pages."""

from __future__ import annotations

import json
import re
from typing import Any

_INFobox_RE = re.compile(
    r'WH\.markup\.printHtml\("(\[.*?\])",\s*"infobox-contents-0"',
    re.DOTALL,
)
_mapper_re = re.compile(r"var myMapper = new Mapper\((\{.*?\})\);", re.DOTALL)
_gatherer_quest_re = re.compile(
    r'WH\.Gatherer\.addData\(5,\s*16,\s*(\{.*?\})\);',
    re.DOTALL,
)
_PAGE_INFO_RE = re.compile(r"var g_pageInfo = (\{.*?\});")


def parse_quest_detail(html: str, quest_id: int) -> dict[str, Any]:
    result: dict[str, Any] = {
        "questId": quest_id,
        "infoboxMarkup": None,
        "infoboxFlags": {},
        "mapper": None,
        "prerequisiteQuestIds": [],
        "pageInfo": None,
    }

    page_match = _PAGE_INFO_RE.search(html)
    if page_match:
        try:
            result["pageInfo"] = json.loads(page_match.group(1))
        except json.JSONDecodeError:
            pass

    infobox_match = _INFobox_RE.search(html)
    if infobox_match:
        raw = infobox_match.group(1)
        result["infoboxMarkup"] = _unescape_wh_markup(raw)
        result["infoboxFlags"] = _flags_from_infobox(result["infoboxMarkup"])

    mapper_match = _mapper_re.search(html)
    if mapper_match:
        try:
            result["mapper"] = json.loads(mapper_match.group(1))
        except json.JSONDecodeError:
            result["mapper"] = None

    prereq_ids: set[int] = set()
    for block in _gatherer_quest_re.findall(html):
        try:
            table = json.loads(block)
        except json.JSONDecodeError:
            continue
        for key, value in table.items():
            try:
                qid = int(key)
            except (TypeError, ValueError):
                continue
            if qid != quest_id:
                prereq_ids.add(qid)
    result["prerequisiteQuestIds"] = sorted(prereq_ids)

    return result


def extract_start_pins(mapper: dict[str, Any] | None) -> list[dict[str, Any]]:
    if not mapper:
        return []
    objectives = mapper.get("objectives") or {}
    pins: list[dict[str, Any]] = []
    for zone_id, zone_block in objectives.items():
        if not isinstance(zone_block, dict):
            continue
        levels = zone_block.get("levels") or []
        for level in levels:
            if not isinstance(level, list):
                continue
            for entry in level:
                if not isinstance(entry, dict):
                    continue
                if entry.get("point") != "start":
                    continue
                coord = entry.get("coord")
                if not (isinstance(coord, list) and len(coord) == 2):
                    continue
                pins.append(
                    {
                        "wowheadZoneId": int(zone_id) if str(zone_id).isdigit() else zone_id,
                        "zoneName": zone_block.get("zone"),
                        "x": float(coord[0]),
                        "y": float(coord[1]),
                        "npcId": entry.get("id"),
                        "npcName": entry.get("name"),
                    }
                )
    return pins


def _unescape_wh_markup(raw: str) -> str:
    return (
        raw.replace(r"\/", "/")
        .replace(r"\[", "[")
        .replace(r"\]", "]")
        .replace(r"\"", '"')
    )


def _flags_from_infobox(markup: str | None) -> dict[str, bool]:
    if not markup:
        return {}
    text = markup.lower()
    return {
        "repeatable": "repeatable" in text,
        "daily": "daily" in text,
        "weekly": "weekly" in text,
        "monthly": "monthly" in text,
        "pvp": "pvp" in text or "battleground" in text,
        "dungeon": "dungeon" in text,
        "raid": "raid" in text,
        "sharable": "sharable" in text,
    }
