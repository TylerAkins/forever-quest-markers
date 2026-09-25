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
