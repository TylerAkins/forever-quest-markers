"""Detect Classic Ahn'Qiraj war-effort quest starts for map pins."""

from __future__ import annotations

WAR_EFFORT_NPC_IDS = frozenset(
    {
        13418,
        15383,
        15431,
        15432,
        15434,
        15437,
        15445,
        15446,
        15448,
        15450,
        15451,
        15452,
        15453,
        15455,
        15456,
        15457,
        15459,
        15460,
        15469,
        15477,
        15508,
        15512,
        15515,
        15522,
        15525,
        15528,
        15529,
        15532,
        15533,
        15534,
        15535,
        15704,
        15707,
    }
)

BANNER_QUEST_MIN = 8780
BANNER_QUEST_MAX = 8789


def is_war_effort_record(record) -> bool:
    quest_id = record.quest_id
    if BANNER_QUEST_MIN <= quest_id <= BANNER_QUEST_MAX:
        return True
    if record.qgs:
        return any(npc in WAR_EFFORT_NPC_IDS for npc in record.qgs)
    return False
