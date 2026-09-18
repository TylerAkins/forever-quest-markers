"""Forever patch / preprocessor tags and WoW race-class constants."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


# WoW Classic-era race IDs. Forever adds extra races whose IDs are not published
# in ATT constants yet; unresolved names are stored but never used to hide pins.
RACE_IDS: dict[str, int] = {
    "HUMAN": 1,
    "ORC": 2,
    "DWARF": 3,
    "NIGHTELF": 4,
    "NIGHT_ELF": 4,
    "SCOURGE": 5,
    "UNDEAD": 5,
    "TAUREN": 6,
    "GNOME": 7,
    "TROLL": 8,
    "GOBLIN": 9,
    "BLOODELF": 10,
    "BLOOD_ELF": 10,
    "DRAENEI": 11,
    "WORGEN": 22,
    "PANDAREN_NEUTRAL": 24,
    "PANDAREN_ALLIANCE": 25,
    "PANDAREN_HORDE": 26,
}

CLASS_IDS: dict[str, int] = {
    "WARRIOR": 1,
    "PALADIN": 2,
    "HUNTER": 3,
    "ROGUE": 4,
    "PRIEST": 5,
    "DEATHKNIGHT": 6,
    "DEATH_KNIGHT": 6,
    "SHAMAN": 7,
    "MAGE": 8,
    "WARLOCK": 9,
    "MONK": 10,
    "DRUID": 11,
    "DEMONHUNTER": 12,
    "DEMON_HUNTER": 12,
    "EVOKER": 13,
}

# First patch of each expansion name used by ATT `-- #if AFTER/BEFORE` tags.
EXPANSION_VERSIONS: dict[str, tuple[int, int, int, int]] = {
    "CLASSIC": (1, 0, 0, 0),
    "VANILLA": (1, 0, 0, 0),
    "CLASSICERA": (1, 0, 0, 0),
    "TBC": (2, 0, 1, 0),
    "BC": (2, 0, 1, 0),
    "BURNINGCRUSADE": (2, 0, 1, 0),
    "WRATH": (3, 0, 2, 0),
    "WOTLK": (3, 0, 2, 0),
    "CATA": (4, 0, 3, 0),
    "CATACLYSM": (4, 0, 3, 0),
    "MOP": (5, 0, 4, 0),
    "PANDARIA": (5, 0, 4, 0),
    "WOD": (6, 0, 2, 0),
    "WOWD": (6, 0, 2, 0),
    "DRAENOR": (6, 0, 2, 0),
    "LEGION": (7, 0, 3, 0),
    "BFA": (8, 0, 1, 0),
    "BATTLEFORAZEROTH": (8, 0, 1, 0),
    "SL": (9, 0, 1, 0),
    "SHADOWLANDS": (9, 0, 1, 0),
    "DF": (10, 0, 2, 0),
    "DRAGONFLIGHT": (10, 0, 2, 0),
    "TWW": (11, 0, 2, 0),
    "WARWITHIN": (11, 0, 2, 0),
    "MID": (12, 0, 0, 0),
    "MIDNIGHT": (12, 0, 0, 0),
}

DEFAULT_FOREVER_TAGS: frozenset[str] = frozenset(
    {
        "ANYCLASSIC",
        "FOREVER",
        "CAMELOT",
        "CLASSIC",
        "CRIEVE",
        "EXPLORATION",
        "IGNORE_ERRORS",
        "OBJECTIVES",
        "NOSIMPLIFY",
        "INCLUDE_QUALITY",
    }
)

DEFAULT_FOREVER_PATCH: tuple[int, int, int, int] = (1, 60, 1, 69893)

_ASSIGN_INT_RE = re.compile(r"\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\s*;?", re.MULTILINE)
_ASSIGN_STR_RE = re.compile(
    r'\b([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"\s*;?',
    re.MULTILINE,
)


@dataclass
class BuildContext:
    """Patch / tag state used while preprocessing ATT Lua."""

    patch: tuple[int, int, int, int] = DEFAULT_FOREVER_PATCH
    tags: frozenset[str] = DEFAULT_FOREVER_TAGS
    maps: dict[str, int] = field(default_factory=dict)
    timelines: dict[str, str] = field(default_factory=dict)
    extra_globals: dict[str, Any] = field(default_factory=dict)


def parse_patch(values: list[int] | tuple[int, ...]) -> tuple[int, int, int, int]:
    padded = list(values) + [0, 0, 0, 0]
    return (int(padded[0]), int(padded[1]), int(padded[2]), int(padded[3]))


def parse_version_token(token: str) -> tuple[int, int, int, int] | None:
    raw = token.strip().upper().replace("-", "").replace(" ", "")
    if raw in EXPANSION_VERSIONS:
        return EXPANSION_VERSIONS[raw]
    parts = token.strip().split(".")
    if not parts or not all(p.isdigit() for p in parts):
        return None
    nums = [int(p) for p in parts]
    while len(nums) < 4:
        nums.append(0)
    return (nums[0], nums[1], nums[2], nums[3])


def load_forever_constants(att_root: str | Path) -> BuildContext:
    """Load Forever map/timeline constants and parser config."""
    root = Path(att_root)
    forever_db = root / ".contrib" / ".db" / "forever"
    config_dir = forever_db / ".config"
    ctx = BuildContext()

    config_path = config_dir / "forever.config"
    if config_path.is_file():
        data = json.loads(_strip_jsonc(config_path.read_text(encoding="utf-8")))
        patch = data.get("DataPatch") or list(DEFAULT_FOREVER_PATCH)
        ctx.patch = parse_patch(patch)
        tags = data.get("PreProcessorTags") or []
        ctx.tags = frozenset(str(t).upper() for t in tags)

    maps_path = config_dir / "constants" / "maps.lua"
    if maps_path.is_file():
        ctx.maps.update(_load_int_assignments(maps_path))

    parser_maps = root / ".contrib" / "Parser" / "lib" / "Constants" / "Maps.lua"
    if parser_maps.is_file():
        for name, value in _load_int_assignments(parser_maps).items():
            ctx.maps.setdefault(name, value)

    timelines_path = config_dir / "constants" / "timelines.lua"
    if timelines_path.is_file():
        ctx.timelines.update(_load_str_assignments(timelines_path))

    return ctx


def _strip_jsonc(text: str) -> str:
    text = re.sub(r"//.*?$", "", text, flags=re.MULTILINE)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return text


def _load_int_assignments(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    return {name: int(value) for name, value in _ASSIGN_INT_RE.findall(text)}


def _load_str_assignments(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {name: value for name, value in _ASSIGN_STR_RE.findall(text)}
