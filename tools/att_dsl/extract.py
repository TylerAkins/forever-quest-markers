"""Walk evaluated ATT objects and extract quest-start pin records."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Iterable

from .constants import DEFAULT_FOREVER_PATCH, parse_version_token
from .evaluator import FactionRaces, LuaTable, Unresolved


from .war_effort import is_war_effort_record


INHERIT_KEYS = (
    "races",
    "classes",
    "timeline",
    "lvl",
    "minReputation",
    "maxReputation",
    "pvp",
    "u",
    "isDaily",
    "isWeekly",
    "isMonthly",
    "isYearly",
    "repeatable",
    "isWorldQuest",
    "isBreadcrumb",
)


@dataclass
class Coord:
    map_id: int
    x: float
    y: float


@dataclass
class QuestRecord:
    quest_id: int
    coords: list[Coord]
    qgs: list[int] = field(default_factory=list)
    source_quests: list[int] = field(default_factory=list)
    source_quest_num_required: int | None = None
    alt_quests: list[int] = field(default_factory=list)
    races: list[int] = field(default_factory=list)
    unresolved_races: list[str] = field(default_factory=list)
    classes: list[int] = field(default_factory=list)
    required_skill: int | str | None = None
    faction: str | None = None
    min_level: int | None = None
    max_level: int | None = None
    is_daily: bool = False
    is_weekly: bool = False
    is_yearly: bool = False
    is_monthly: bool = False
    repeatable: bool = False
    is_breadcrumb: bool = False
    is_world_quest: bool = False
    is_war_effort: bool = False
    is_attunement: bool = False
    is_instance_quest: bool = False
    event: int | None = None
    source_file: str = ""


@dataclass
class ExtractResult:
    quests: dict[int, QuestRecord] = field(default_factory=dict)
    excluded: dict[str, int] = field(default_factory=dict)
    files_parsed: int = 0
    quests_seen: int = 0
    quests_with_coords: int = 0
    warnings: list[str] = field(default_factory=list)
    attunement_quest_ids: set[int] = field(default_factory=set)
    patch: tuple[int, int, int, int] = DEFAULT_FOREVER_PATCH

    def bump_excluded(self, reason: str) -> None:
        self.excluded[reason] = self.excluded.get(reason, 0) + 1


@dataclass
class _Context:
    is_instance_quest: bool = False
    map_id: int | None = None
    races: Any = None
    classes: Any = None
    timeline: Any = None
    lvl: Any = None
    npc_id: int | None = None
    npc_coord: list[Coord] | None = None
    source_file: str = ""
    is_yearly: bool = False
    event: Any = None


def extract_from_roots(roots: list[Any], source_file: str, result: ExtractResult) -> None:
    for root in roots:
        data = root.get("data") if isinstance(root, dict) else root
        _walk(data, _Context(source_file=source_file), result)


def extract_quests(value: Any, source_file: str, result: ExtractResult | None = None) -> ExtractResult:
    result = result or ExtractResult()
    _walk(value, _Context(source_file=source_file), result)
    return result


def _walk(node: Any, ctx: _Context, result: ExtractResult) -> None:
    if node is None:
        return
    if isinstance(node, list):
        for item in node:
            _walk(item, ctx, result)
        return
    if isinstance(node, LuaTable):
        _walk_table(node, ctx, result)
        return
    if isinstance(node, dict):
        _walk_mapping(node, ctx, result)


def _walk_table(table: LuaTable, ctx: _Context, result: ExtractResult) -> None:
    child_ctx = _child_context(table, ctx)
    if _as_int(table.get("instanceID")) is not None:
        result.attunement_quest_ids.update(_parse_source_quests(table))
    quest_id = _as_int(table.get("questID"))
    if quest_id is not None and table.get("objectiveID") is None:
        _record_quest(table, child_ctx, result)
    groups = table.get("groups")
    g = table.get("g")
    _walk(groups, child_ctx, result)
    _walk(g, child_ctx, result)
    _walk(table.get("allianceQuestData"), child_ctx, result)
    _walk(table.get("hordeQuestData"), child_ctx, result)
    if table.array:
        # Do not treat numeric quest fields / coord triples as child objects.
        if _looks_like_object_array(table):
            for item in table.array:
                _walk(item, child_ctx, result)


def _walk_mapping(mapping: dict[Any, Any], ctx: _Context, result: ExtractResult) -> None:
    dummy = LuaTable()
    dummy.mapping = dict(mapping)
    array = mapping.get("_array")
    if isinstance(array, list):
        dummy.array = list(array)
    _walk_table(dummy, ctx, result)


def _looks_like_object_array(table: LuaTable) -> bool:
    if table.mapping:
        return False
    return any(isinstance(item, (LuaTable, dict)) for item in table.array)


def _child_context(table: LuaTable, ctx: _Context) -> _Context:
    map_id = _as_int(table.get("mapID")) or ctx.map_id
    races = table.get("races") if table.get("races") is not None else ctx.races
    classes = table.get("classes") if table.get("classes") is not None else ctx.classes
    timeline = table.get("timeline") if table.get("timeline") is not None else ctx.timeline
    lvl = table.get("lvl") if table.get("lvl") is not None else ctx.lvl
    npc_id = ctx.npc_id
    npc_coord = ctx.npc_coord
    raw_npc = table.get("npcID")
    if _as_int(raw_npc) is not None and _as_int(raw_npc) > 0:
        npc_id = _as_int(raw_npc)
        coords = _parse_coords(table, map_id)
        if coords:
            npc_coord = coords
    is_yearly = bool(table.get("isYearly")) if table.get("isYearly") is not None else ctx.is_yearly
    event = table.get("e") if table.get("e") is not None else ctx.event
    return _Context(
        is_instance_quest=ctx.is_instance_quest or _as_int(table.get("instanceID")) is not None,
        map_id=map_id,
        races=races,
        classes=classes,
        timeline=timeline,
        lvl=lvl,
        npc_id=npc_id,
        npc_coord=npc_coord,
        source_file=ctx.source_file,
        is_yearly=is_yearly,
        event=event,
    )


def _record_quest(table: LuaTable, ctx: _Context, result: ExtractResult) -> None:
    quest_id = _as_int(table.get("questID"))
    if quest_id is None:
        return
    result.quests_seen += 1

    if _should_exclude_timeline(table.get("timeline") or ctx.timeline, result.patch):
        result.bump_excluded("timeline")
        return
    if table.get("isWorldQuest"):
        result.bump_excluded("world_quest")
        return

    coords = _parse_coords(table, ctx.map_id)
    if not coords and ctx.npc_coord:
        coords = list(ctx.npc_coord)

    qgs = _parse_qgs(table)
    if not qgs and ctx.npc_id:
        qgs = [ctx.npc_id]

    if not coords:
        result.bump_excluded("no_coords")
        return

    races, unresolved_races, faction = _parse_races(table.get("races") if table.get("races") is not None else ctx.races)
    classes = _parse_int_list(table.get("classes") if table.get("classes") is not None else ctx.classes)
    required_skill = _parse_required_skill(table.get("requireSkill"))
    min_level, max_level = _parse_level(table.get("lvl") if table.get("lvl") is not None else ctx.lvl)
    source_quests = _parse_source_quests(table)
    alt_quests = _parse_int_list(table.get("altQuests") or table.get("altQuestID"))
    num_required = _as_int(table.get("sourceQuestNumRequired"))

    record = QuestRecord(
        quest_id=quest_id,
        coords=coords,
        qgs=qgs,
        source_quests=source_quests,
        source_quest_num_required=num_required,
        alt_quests=alt_quests,
        races=races,
        unresolved_races=unresolved_races,
        classes=classes,
        required_skill=required_skill,
        faction=faction,
        min_level=min_level,
        max_level=max_level,
        is_daily=bool(table.get("isDaily")),
        is_weekly=bool(table.get("isWeekly")),
        is_yearly=bool(table.get("isYearly") if table.get("isYearly") is not None else ctx.is_yearly),
        is_monthly=bool(table.get("isMonthly")),
        repeatable=bool(table.get("repeatable")),
        is_instance_quest=ctx.is_instance_quest,
        is_breadcrumb=bool(table.get("isBreadcrumb")),
        is_world_quest=bool(table.get("isWorldQuest")),
        event=_as_int(table.get("e") if table.get("e") is not None else ctx.event),
        source_file=ctx.source_file,
    )
    record.is_war_effort = is_war_effort_record(record)

    existing = result.quests.get(quest_id)
    if existing is None:
        result.quests[quest_id] = record
        result.quests_with_coords += 1
        return
    _merge_records(existing, record)


def _merge_records(dst: QuestRecord, src: QuestRecord) -> None:
    dst.is_instance_quest = dst.is_instance_quest or src.is_instance_quest
    seen_coords = {(c.map_id, c.x, c.y) for c in dst.coords}
    for coord in src.coords:
        key = (coord.map_id, coord.x, coord.y)
        if key not in seen_coords:
            dst.coords.append(coord)
            seen_coords.add(key)
    dst.qgs = _unique(dst.qgs + src.qgs)
    dst.source_quests = _unique(dst.source_quests + src.source_quests)
    dst.alt_quests = _unique(dst.alt_quests + src.alt_quests)
    dst.races = _unique(dst.races + src.races)
    dst.unresolved_races = _unique(dst.unresolved_races + src.unresolved_races)
    dst.classes = _unique(dst.classes + src.classes)
    if dst.required_skill is None:
        dst.required_skill = src.required_skill
    if dst.faction is None:
        dst.faction = src.faction
    if dst.min_level is None:
        dst.min_level = src.min_level
    if dst.max_level is None:
        dst.max_level = src.max_level
    if dst.source_quest_num_required is None:
        dst.source_quest_num_required = src.source_quest_num_required
    if not dst.is_yearly:
        dst.is_yearly = src.is_yearly
    if dst.event is None:
        dst.event = src.event
    if not dst.is_war_effort:
        dst.is_war_effort = src.is_war_effort
    if not dst.is_attunement:
        dst.is_attunement = src.is_attunement


def mark_attunement_chains(quests: dict[int, QuestRecord], access_quests: Iterable[int]) -> set[int]:
    """Mark instance access quests, their alternatives, and prerequisites."""
    marked: set[int] = set()
    pending = list(access_quests)
    while pending:
        quest_id = pending.pop()
        if quest_id in marked:
            continue
        marked.add(quest_id)
        record = quests.get(quest_id)
        if record is None:
            continue
        record.is_attunement = True
        pending.extend(record.source_quests)
        pending.extend(record.alt_quests)
    return {quest_id for quest_id in marked if quest_id in quests}


def _unique(values: list[int] | list[str]) -> list:
    seen: set[Any] = set()
    out = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        out.append(value)
    return out


def _parse_coords(table: LuaTable, inherited_map: int | None) -> list[Coord]:
    raw = table.get("coords")
    if raw is None:
        raw = table.get("coord")
    if raw is None:
        return []
    coords: list[Coord] = []
    for triple in _coord_entries(raw):
        parsed = _parse_coord_triple(triple, inherited_map)
        if parsed is not None:
            coords.append(parsed)
    return coords


def _coord_entries(raw: Any) -> list[Any]:
    if isinstance(raw, LuaTable):
        if raw.array and isinstance(raw.array[0], LuaTable):
            return list(raw.array)
        if raw.array and isinstance(raw.array[0], (int, float)):
            return [raw]
        if raw.mapping:
            return [raw]
        return list(raw.array)
    if isinstance(raw, list):
        if raw and isinstance(raw[0], (list, LuaTable, dict)):
            return raw
        if raw and isinstance(raw[0], (int, float)):
            return [raw]
    return []


def _parse_coord_triple(raw: Any, inherited_map: int | None) -> Coord | None:
    values = _sequence(raw)
    if len(values) < 2:
        return None
    try:
        x = float(values[0])
        y = float(values[1])
    except (TypeError, ValueError):
        return None
    map_id = _as_int(values[2]) if len(values) >= 3 else inherited_map
    if map_id is None:
        return None
    return Coord(map_id=map_id, x=x, y=y)


def _parse_qgs(table: LuaTable) -> list[int]:
    qgs: list[int] = []
    qgs.extend(_parse_int_list(table.get("qgs") or table.get("qg")))
    providers = table.get("providers") or table.get("provider")
    for provider in _provider_entries(providers):
        values = _sequence(provider)
        if len(values) >= 2 and isinstance(values[0], str) and values[0].lower() == "n":
            npc_id = _as_int(values[1])
            if npc_id:
                qgs.append(npc_id)
    return _unique(qgs)


def _provider_entries(raw: Any) -> list[Any]:
    if raw is None:
        return []
    seq = _sequence(raw)
    if not seq:
        return []
    first = seq[0]
    if isinstance(first, str) and first.lower() in {"n", "i", "o", "s"}:
        return [raw]
    return seq


def _parse_source_quests(table: LuaTable) -> list[int]:
    values = _parse_int_list(table.get("sourceQuests"))
    single = _as_int(table.get("sourceQuest"))
    if single is not None:
        values.append(single)
    return _unique(values)


def _parse_races(raw: Any) -> tuple[list[int], list[str], str | None]:
    if isinstance(raw, FactionRaces):
        return [], [], raw.faction
    races: list[int] = []
    unresolved: list[str] = []
    faction: str | None = None
    for item in _sequence(raw) or ([raw] if raw is not None else []):
        if isinstance(item, FactionRaces):
            faction = item.faction
            continue
        number = _as_int(item)
        if number is not None:
            races.append(number)
            continue
        if isinstance(item, Unresolved):
            unresolved.append(item.name)
            continue
        if isinstance(item, str):
            unresolved.append(item)
    return _unique(races), _unique(unresolved), faction


def _parse_int_list(raw: Any) -> list[int]:
    if raw is None:
        return []
    if isinstance(raw, (int, float)) and not isinstance(raw, bool):
        return [int(raw)]
    out: list[int] = []
    for item in _sequence(raw):
        number = _as_int(item)
        if number is not None:
            out.append(number)
    return out


def _parse_required_skill(raw: Any) -> int | str | None:
    number = _as_int(raw)
    if number is not None:
        return number
    if isinstance(raw, Unresolved):
        return raw.name
    if isinstance(raw, str) and raw:
        return raw
    return None


def _parse_level(raw: Any) -> tuple[int | None, int | None]:
    if raw is None:
        return None, None
    if isinstance(raw, (int, float)) and not isinstance(raw, bool):
        return int(raw), None
    values = [_as_int(v) for v in _sequence(raw)]
    values = [v for v in values if v is not None]
    if not values:
        return None, None
    if len(values) == 1:
        return values[0], None
    return values[0], values[1]


_TIMELINE_TEXT_RE = re.compile(
    r"^(created|added|removed|deleted)\s+(\d+(?:\.\d+)*)",
    re.IGNORECASE,
)
_TIMELINE_NAME_RE = re.compile(
    r"^(CREATED|ADDED|REMOVED|DELETED)_(\d+)_(\d+)(?:_(\d+))?",
    re.IGNORECASE,
)


def _timeline_kind_version(raw: Any) -> tuple[str, tuple[int, int, int, int]] | None:
    if isinstance(raw, Unresolved):
        text = raw.name
    else:
        text = str(raw).strip()
    match = _TIMELINE_TEXT_RE.match(text)
    if match:
        version = parse_version_token(match.group(2))
        if version is None:
            return None
        return match.group(1).lower(), version
    match = _TIMELINE_NAME_RE.match(text)
    if match:
        patch = match.group(4) or "0"
        version = (int(match.group(2)), int(match.group(3)), int(patch), 0)
        return match.group(1).lower(), version
    return None


def _should_exclude_timeline(raw: Any, patch: tuple[int, int, int, int]) -> bool:
    """Drop content that does not exist on Forever's current patch."""
    events = _sequence(raw)
    if not events and isinstance(raw, str):
        events = [raw]
    added: list[tuple[int, int, int, int]] = []
    removed: list[tuple[int, int, int, int]] = []
    created = False
    deleted = False
    for event in events:
        parsed = _timeline_kind_version(event)
        if parsed is None:
            continue
        kind, version = parsed
        if kind == "added":
            added.append(version)
        elif kind == "removed":
            removed.append(version)
        elif kind == "created":
            created = True
        elif kind == "deleted":
            deleted = True
    if deleted:
        return True
    if created and not added:
        return True
    if added and not any(version <= patch for version in added):
        return True
    if any(version <= patch for version in removed):
        return True
    return False


def _sequence(raw: Any) -> list[Any]:
    if raw is None:
        return []
    if isinstance(raw, LuaTable):
        if raw.array:
            return list(raw.array)
        return list(raw.mapping.values())
    if isinstance(raw, list):
        return raw
    if isinstance(raw, tuple):
        return list(raw)
    return []


def _as_int(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return None


def iter_lua_objects(value: Any) -> Iterable[LuaTable]:
    if isinstance(value, LuaTable):
        yield value
        for child in value.values():
            yield from iter_lua_objects(child)
    elif isinstance(value, list):
        for item in value:
            yield from iter_lua_objects(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from iter_lua_objects(item)
