"""Extract quest display names from ATT Forever Lua source comments."""

from __future__ import annotations

import re

from .extract import ExtractResult

# q(8171, { -- The Battle for Arathi Basin! [Level 20] (Horde)
_Q_LINE = re.compile(r"\bq\(\s*(\d+)\s*,\s*\{[^\n]*--\s*(.+)")
_TRAILING_FACTION = re.compile(r"\s*\((?:Horde|Alliance)\)\s*$", re.IGNORECASE)
_LEVEL_BRACKET = re.compile(r"\s*\[Level\s+[^\]]+\]\s*")


def normalize_att_title(raw: str) -> str:
    title = raw.strip()
    title = _TRAILING_FACTION.sub("", title)
    title = _LEVEL_BRACKET.sub(" ", title)
    return " ".join(title.split())


def extract_titles_from_source(source: str) -> dict[int, str]:
    titles: dict[int, str] = {}
    for line in source.splitlines():
        match = _Q_LINE.search(line)
        if not match:
            continue
        quest_id = int(match.group(1))
        title = normalize_att_title(match.group(2))
        if title and quest_id not in titles:
            titles[quest_id] = title
    return titles


def apply_titles_from_source(source: str, result: ExtractResult) -> int:
    applied = 0
    for quest_id, title in extract_titles_from_source(source).items():
        record = result.quests.get(quest_id)
        if record is None:
            continue
        if record.att_title:
            continue
        record.att_title = title
        applied += 1
    return applied
