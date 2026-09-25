"""Extract Source list data from saved HTML (inline Listview + JSON listviews)."""

from __future__ import annotations

import json
import re
from typing import Any

from .parse_list import parse_quest_list

_LISTVIEWS_JSON_RE = re.compile(
    r'<script type="application/json" id="data\.page\.listPage\.listviews">(\[.*?\])</script>',
    re.DOTALL,
)
_QUEST_ID_RE = re.compile(r"quest=(\d+)")


def extract_inline_listviews(html: str) -> list[dict[str, Any]]:
    """Parse `new Listview({... data: [...]})` blocks, including zone tabs."""
    views: list[dict[str, Any]] = []
    decoder = json.JSONDecoder()
    for match in re.finditer(r"new Listview\(\{", html):
        window = html[match.start() : match.start() + 700]
        template_match = re.search(r"template:\s*'([^']+)'", window)
        id_match = re.search(r"id:\s*'([^']+)'", window)
        data_at = window.find("data:")
        if template_match is None or data_at < 0:
            continue
        bracket = html.find("[", match.start() + data_at)
        if bracket < 0:
            continue
        try:
            data, _end = decoder.raw_decode(html[bracket:])
        except json.JSONDecodeError:
            continue
        if not isinstance(data, list):
            continue
        views.append(
            {
                "template": template_match.group(1),
                "id": id_match.group(1) if id_match else None,
                "data": [row for row in data if isinstance(row, dict)],
            }
        )
    return views


def extract_page_listviews(html: str) -> list[dict[str, Any]]:
    views: list[dict[str, Any]] = []

    quest_rows = parse_quest_list(html)
    if quest_rows:
        views.append({"template": "quest", "id": "quests", "data": quest_rows})

    json_match = _LISTVIEWS_JSON_RE.search(html)
    if json_match:
        try:
            payload = json.loads(json_match.group(1))
        except json.JSONDecodeError:
            payload = []
        if isinstance(payload, list):
            for entry in payload:
                if isinstance(entry, dict) and isinstance(entry.get("data"), list):
                    views.append(entry)

    return views


def quest_id_from_url(url: str) -> int | None:
    match = _QUEST_ID_RE.search(url)
    if not match:
        return None
    return int(match.group(1))
