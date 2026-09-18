"""Safe evaluator for the ATT Lua DSL subset.

Unknown identifiers become unresolved sentinels so header names such as
`QUESTS` still wrap child groups. Function bodies are never executed.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

from .constants import CLASS_IDS, RACE_IDS, BuildContext
from .parser import (
    Assign,
    BinOp,
    BreakStat,
    Call,
    CallStat,
    Chunk,
    DoBlock,
    ForIn,
    ForNum,
    FunctionDef,
    FunctionExpr,
    IfStat,
    Index,
    Literal,
    Name,
    Node,
    RepeatStat,
    ReturnStat,
    Table,
    UnaryOp,
    Vararg,
    WhileStat,
)


class EvalError(ValueError):
    def __init__(self, message: str, node: Node | None = None) -> None:
        self.node = node
        loc = ""
        if node is not None:
            loc = f"line {node.line}: "
        super().__init__(loc + message)


@dataclass(frozen=True)
class Unresolved:
    name: str

    def __str__(self) -> str:
        return self.name


@dataclass(frozen=True)
class FactionRaces:
    faction: str


@dataclass
class FunctionSkip:
    params: list[str] = field(default_factory=list)


@dataclass
class LuaTable:
    array: list[Any] = field(default_factory=list)
    mapping: dict[Any, Any] = field(default_factory=dict)

    def set(self, key: Any, value: Any) -> None:
        if isinstance(key, int) and key >= 1:
            while len(self.array) < key:
                self.array.append(None)
            self.array[key - 1] = value
            return
        self.mapping[key] = value

    def get(self, key: Any, default: Any = None) -> Any:
        if isinstance(key, int) and 1 <= key <= len(self.array):
            value = self.array[key - 1]
            return default if value is None else value
        if key in self.mapping:
            return self.mapping[key]
        return default

    def append(self, value: Any) -> None:
        self.array.append(value)

    def items(self):
        for index, value in enumerate(self.array, start=1):
            if value is not None:
                yield index, value
        yield from self.mapping.items()

    def values(self):
        for _, value in self.items():
            yield value

    def __contains__(self, key: Any) -> bool:
        if isinstance(key, int) and 1 <= key <= len(self.array):
            return self.array[key - 1] is not None
        return key in self.mapping


class Environment(dict[str, Any]):
    """Nested assignment helper: env['ExportDB'] auto-vivifies tables."""

    def auto_table(self, name: str) -> LuaTable:
        value = self.get(name)
        if isinstance(value, LuaTable):
            return value
        table = LuaTable()
        self[name] = table
        return table


def new_environment(ctx: BuildContext) -> Environment:
    env = Environment()
    env["MAP"] = _dict_to_lua(ctx.maps)
    env["TIMELINE"] = _dict_to_lua(ctx.timelines)
    env["_G"] = env
    env["ROOTS"] = _dict_to_lua(
        {
            "Zones": "Zones",
            "Instances": "Instances",
            "PVP": "PVP",
            "Holidays": "Holidays",
            "WorldEvents": "WorldEvents",
            "Professions": "Professions",
            "Character": "Character",
            "ExpansionFeatures": "ExpansionFeatures",
        }
    )
    env["ALLIANCE_ONLY"] = FactionRaces("Alliance")
    env["HORDE_ONLY"] = FactionRaces("Horde")
    env["NEUTRAL"] = 0
    env["FRIENDLY"] = 3000
    env["HONORED"] = 9000
    env["REVERED"] = 21000
    env["EXALTED"] = 42000
    env["UNFRIENDLY"] = -3000
    env["HOSTILE"] = -6000
    env["HATED"] = -42000
    env["IGNORED_VALUE"] = 0
    env.update(RACE_IDS)
    env.update(CLASS_IDS)
    env.update(ctx.maps)
    env.update(ctx.timelines)
    env.update(ctx.extra_globals)
    env["_roots"] = []
    _install_constructors(env)
    return env


def evaluate_chunk(chunk: Chunk, env: Environment) -> Environment:
    for stat in chunk.stats:
        _eval_stat(stat, env)
    return env


def _eval_stat(stat: Node, env: Environment) -> None:
    if isinstance(stat, Assign):
        values = [_eval_exp(value, env) for value in stat.values]
        for index, target in enumerate(stat.targets):
            value = values[index] if index < len(values) else None
            _assign(target, value, env, is_local=stat.is_local)
        return
    if isinstance(stat, CallStat):
        value = _eval_exp(stat.call, env)
        if isinstance(value, LuaTable):
            roots = env["_roots"]
            if not roots or roots[-1].get("data") is not value:
                roots.append({"category": "loose", "data": value})
        return
    if isinstance(stat, FunctionDef):
        fn = FunctionSkip(params=stat.params)
        if stat.name is None:
            return
        _assign(stat.name, fn, env, is_local=stat.is_local)
        return
    if isinstance(stat, (ReturnStat, BreakStat, FunctionSkip)):
        return
    if isinstance(stat, DoBlock):
        for child in stat.body:
            _eval_stat(child, env)
        return
    if isinstance(stat, IfStat):
        for cond, body in stat.clauses:
            if cond is None or _truthy(_eval_exp(cond, env)):
                for child in body:
                    _eval_stat(child, env)
                return
        return
    if isinstance(stat, (WhileStat, RepeatStat, ForNum)):
        # Loops are not executed. ATT data files do not need them for quests.
        return
    if isinstance(stat, ForIn):
        # Rare at data top-level; skip to remain side-effect free.
        return
    raise EvalError(f"unsupported statement {type(stat).__name__}", stat)


def _assign(target: Node, value: Any, env: Environment, is_local: bool) -> None:
    if isinstance(target, Name):
        env[target.ident] = value
        return
    if isinstance(target, Index):
        obj = _eval_exp(target.obj, env)
        key = _eval_exp(target.key, env)
        table = _as_table(obj, target)
        table.set(key, value)
        return
    raise EvalError("invalid assignment target", target)


def _eval_exp(node: Node, env: Environment) -> Any:
    if isinstance(node, Literal):
        return node.value
    if isinstance(node, Vararg):
        return None
    if isinstance(node, Name):
        if node.ident in env:
            return env[node.ident]
        return Unresolved(node.ident)
    if isinstance(node, FunctionExpr):
        return FunctionSkip(params=node.params)
    if isinstance(node, Table):
        return _eval_table(node, env)
    if isinstance(node, Index):
        obj = _eval_exp(node.obj, env)
        key = _eval_exp(node.key, env)
        if isinstance(obj, LuaTable):
            value = obj.get(key)
            if value is None and isinstance(key, str) and key not in obj.mapping:
                # Auto-vivify nested tables for assignments like ExportDB.OnTooltipDB.X
                nested = LuaTable()
                obj.set(key, nested)
                return nested
            return value
        if isinstance(obj, dict):
            return obj.get(key)
        if isinstance(obj, Environment):
            return obj.get(str(key), Unresolved(str(key)))
        if isinstance(obj, Unresolved):
            return Unresolved(f"{obj.name}.{key}")
        return None
    if isinstance(node, Call):
        func = _eval_exp(node.func, env)
        args = [_eval_exp(arg, env) for arg in node.args]
        if node.method:
            args = [func, *args]
        return _call(func, args, node)
    if isinstance(node, UnaryOp):
        value = _eval_exp(node.operand, env)
        if node.op == "not":
            return not _truthy(value)
        if node.op == "-":
            if isinstance(value, (int, float)):
                return -value
            raise EvalError("unary minus on non-number", node)
        if node.op == "#":
            if isinstance(value, LuaTable):
                return len(value.array)
            if isinstance(value, (list, str)):
                return len(value)
            return 0
        raise EvalError(f"unsupported unary {node.op}", node)
    if isinstance(node, BinOp):
        if node.op == "and":
            left = _eval_exp(node.left, env)
            return _eval_exp(node.right, env) if _truthy(left) else left
        if node.op == "or":
            left = _eval_exp(node.left, env)
            return left if _truthy(left) else _eval_exp(node.right, env)
        left = _eval_exp(node.left, env)
        right = _eval_exp(node.right, env)
        if node.op == "..":
            return f"{_lua_tostring(left)}{_lua_tostring(right)}"
        if node.op in {"+", "-", "*", "/", "%", "^", "//"}:
            if not isinstance(left, (int, float)) or not isinstance(right, (int, float)):
                raise EvalError(f"arithmetic {node.op} on non-numbers", node)
            if node.op == "+":
                return left + right
            if node.op == "-":
                return left - right
            if node.op == "*":
                return left * right
            if node.op == "/":
                return left / right
            if node.op == "%":
                return left % right
            if node.op == "//":
                return left // right
            return left**right
        ops = {
            "<": lambda a, b: a < b,
            ">": lambda a, b: a > b,
            "<=": lambda a, b: a <= b,
            ">=": lambda a, b: a >= b,
            "==": lambda a, b: a == b,
            "~=": lambda a, b: a != b,
        }
        cmp = ops.get(node.op)
        if cmp is None:
            raise EvalError(f"unsupported operator {node.op}", node)
        try:
            return cmp(left, right)
        except TypeError:
            return False
    raise EvalError(f"unsupported expression {type(node).__name__}", node)


def _eval_table(node: Table, env: Environment) -> LuaTable:
    table = LuaTable()
    array_index = 1
    for field in node.fields:
        value = _eval_exp(field.value, env)
        if field.key is None:
            table.set(array_index, value)
            array_index += 1
        else:
            key = _eval_exp(field.key, env)
            table.set(key, value)
    return table


def _call(func: Any, args: list[Any], node: Node) -> Any:
    if isinstance(func, FunctionSkip):
        # Local helper wrappers are not executed. Keep the last table argument
        # so nested quest groups are not dropped.
        for arg in reversed(args):
            if isinstance(arg, LuaTable):
                return arg
        return args[-1] if args else None
    if callable(func):
        try:
            return func(*args)
        except TypeError:
            # Some constructors are varargs; last-arg table is optional.
            try:
                return func(*args, None)
            except TypeError as exc:
                raise EvalError(f"call failed: {exc}", node) from exc
    if isinstance(func, Unresolved):
        return _generic_struct(func.name, args)
    if func is None:
        return None
    raise EvalError(f"attempt to call {type(func).__name__}", node)


def _truthy(value: Any) -> bool:
    return value is not None and value is not False


def _lua_tostring(value: Any) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def _as_table(obj: Any, node: Node) -> LuaTable:
    if isinstance(obj, LuaTable):
        return obj
    if isinstance(obj, Environment):
        # Treat env as a mapping via a shim table.
        table = LuaTable()
        for key, value in obj.items():
            table.set(key, value)
        return table
    if obj is None or isinstance(obj, Unresolved):
        table = LuaTable()
        return table
    raise EvalError("attempt to index a non-table", node)


def _dict_to_lua(data: dict[Any, Any]) -> LuaTable:
    table = LuaTable()
    for key, value in data.items():
        table.set(key, value)
    return table


def lua_to_python(value: Any) -> Any:
    """Convert LuaTable trees into dict/list structures for extraction."""
    if isinstance(value, LuaTable):
        has_map = bool(value.mapping)
        if not has_map:
            return [lua_to_python(v) for v in value.array]
        result: dict[Any, Any] = {}
        for key, item in value.items():
            result[key] = lua_to_python(item)
        if value.array:
            result["_array"] = [lua_to_python(v) for v in value.array]
        return result
    if isinstance(value, list):
        return [lua_to_python(v) for v in value]
    if isinstance(value, dict):
        return {k: lua_to_python(v) for k, v in value.items()}
    return value


def _copy_table(value: Any) -> Any:
    if isinstance(value, LuaTable):
        copied = LuaTable()
        copied.array = [_copy_table(v) for v in value.array]
        copied.mapping = {k: _copy_table(v) for k, v in value.mapping.items()}
        return copied
    if isinstance(value, list):
        return [_copy_table(v) for v in value]
    if isinstance(value, dict):
        return {k: _copy_table(v) for k, v in value.items()}
    return value


def _is_array_table(table: LuaTable) -> bool:
    return bool(table.array) and not table.mapping


def _as_groups(t: Any) -> LuaTable:
    if t is None:
        return LuaTable()
    if isinstance(t, list):
        table = LuaTable()
        table.array = list(t)
        return table
    if not isinstance(t, LuaTable):
        table = LuaTable()
        table.set("value", t)
        return table
    if t.array and "groups" not in t.mapping and "g" not in t.mapping:
        wrapper = LuaTable()
        groups = LuaTable()
        groups.array = list(t.array)
        wrapper.set("groups", groups)
        for key, value in t.mapping.items():
            wrapper.set(key, value)
        return wrapper
    return t


def _struct(field: str, ident: Any, t: Any = None) -> LuaTable:
    table = _as_groups(t)
    table.set(field, ident)
    return table


def _apply_data(data: LuaTable, target: LuaTable) -> None:
    for key, value in data.items():
        if key in {"IgnoreWarnings", "g", "groups"}:
            continue
        if target.get(key) is None:
            target.set(key, _copy_table(value))


def _bubble_down(data: Any, t: Any) -> Any:
    if not isinstance(data, LuaTable) or t is None:
        return t
    if isinstance(t, list):
        for item in t:
            _bubble_down(data, item)
        return t
    if not isinstance(t, LuaTable):
        return t
    groups = t.get("groups")
    g = t.get("g")
    if groups is not None or g is not None:
        _apply_data(data, t)
        _bubble_down(data, groups)
        _bubble_down(data, g)
        return t
    if _is_array_table(t):
        for item in t.array:
            _bubble_down(data, item)
        return t
    _apply_data(data, t)
    return t


def _generic_struct(name: str, args: list[Any]) -> LuaTable:
    table = LuaTable()
    table.set("_ctor", name)
    for arg in args:
        if isinstance(arg, LuaTable):
            if _is_array_table(arg) and "groups" not in table.mapping:
                table.set("groups", arg)
            else:
                for key, value in arg.items():
                    if table.get(key) is None:
                        table.set(key, value)
                if arg.array and table.get("groups") is None and not arg.mapping:
                    table.set("groups", arg)
        elif isinstance(arg, (int, float, str, Unresolved)):
            if table.get("_id") is None:
                table.set("_id", arg)
    return table


def _optional_table(args: list[Any], index: int = 1) -> Any:
    if len(args) > index:
        return args[index]
    return None


def _install_constructors(env: Environment) -> None:
    def q(quest_id: Any, t: Any = None) -> LuaTable:
        return _struct("questID", quest_id, t)

    def npc(npc_id: Any, t: Any = None) -> LuaTable:
        return _struct("npcID", npc_id, t)

    def m(map_id: Any, t: Any = None) -> LuaTable:
        return _struct("mapID", map_id, t)

    def inst(instance_id: Any, t: Any = None) -> LuaTable:
        return _struct("instanceID", instance_id, t)

    def ach(ach_id: Any, t: Any = None) -> LuaTable:
        return _struct("achievementID", ach_id, t)

    def item(item_id: Any, t: Any = None) -> LuaTable:
        return _struct("itemID", item_id, t)

    def obj(object_id: Any, t: Any = None) -> LuaTable:
        return _struct("objectID", object_id, t)

    def spell(spell_id: Any, t: Any = None) -> LuaTable:
        return _struct("spellID", spell_id, t)

    def recipe(recipe_id: Any, t: Any = None) -> LuaTable:
        return _struct("recipeID", recipe_id, t)

    def faction(faction_id: Any, t: Any = None) -> LuaTable:
        return _struct("factionID", faction_id, t)

    def header(header_id: Any, t: Any = None, *rest: Any) -> LuaTable:
        last = t
        for arg in rest:
            if isinstance(arg, LuaTable):
                last = arg
        return _struct("headerID", header_id, last)

    def objective(obj_id: Any, t: Any = None) -> LuaTable:
        return _struct("objectiveID", obj_id, t)

    def exploration(expl_id: Any, t: Any = None) -> LuaTable:
        return _struct("explorationID", expl_id, t)

    def prof(skill_id: Any, t: Any = None) -> LuaTable:
        return _struct("professionID", skill_id, t)

    def bubbleDown(data: Any, t: Any = None) -> Any:
        return _bubble_down(data, t)

    def bubbleDownSelf(data: Any, t: Any = None) -> Any:
        table = _as_groups(t)
        return _bubble_down(data, table)

    def applyData(data: Any, t: Any = None) -> Any:
        if isinstance(data, LuaTable) and isinstance(t, LuaTable):
            _apply_data(data, t)
        return t

    def clone(t: Any, c: Any = None) -> Any:
        copied = _copy_table(t)
        if c is None:
            return copied
        if isinstance(c, LuaTable) and isinstance(copied, LuaTable):
            for key, value in copied.items():
                if c.get(key) is None:
                    c.set(key, value)
            return c
        return copied

    def a(t: Any) -> Any:
        table = _as_groups(t)
        if table.get("races") is None:
            table.set("races", FactionRaces("Alliance"))
        return table

    def h(t: Any) -> Any:
        table = _as_groups(t)
        if table.get("races") is None:
            table.set("races", FactionRaces("Horde"))
        return table

    def pvp(t: Any) -> Any:
        return bubbleDown(_dict_to_lua({"pvp": True}), t)

    def applyevent(event_id: Any, data: Any = None) -> Any:
        payload: dict[str, Any] = {"isYearly": True}
        if isinstance(event_id, int):
            payload["e"] = event_id
        elif isinstance(event_id, float) and event_id.is_integer():
            payload["e"] = int(event_id)
        return _bubble_down(_dict_to_lua(payload), data)

    def root(category: Any, g: Any = None) -> Any:
        env["_roots"].append({"category": category, "data": g})
        return g

    def maproot(*args: Any) -> Any:
        if not args:
            return None
        data = args[-1]
        for map_id in reversed(args[:-1]):
            data = m(map_id, data)
        return root(env["ROOTS"].get("Zones"), data)

    def battleground(map_id: Any, g: Any = None) -> Any:
        return root(env["ROOTS"].get("PVP"), m(map_id, g))

    def createHeader(t: Any = None) -> Any:
        table = _as_groups(t)
        readable = table.get("readable")
        return Unresolved(str(readable) if readable is not None else "header")

    def visit_exploration(expl_id: Any, t: Any = None) -> LuaTable:
        return exploration(expl_id, t)

    def explorationHeader(t: Any = None) -> Any:
        return _generic_struct("explorationHeader", [t])

    def filter_(filter_id: Any, t: Any = None) -> LuaTable:
        return _struct("filterID", filter_id, t)

    def class_(class_id: Any, t: Any = None) -> LuaTable:
        return _struct("classID", class_id, t)

    def race(race_id: Any, t: Any = None) -> LuaTable:
        return _struct("raceID", race_id, t)

    def n_(id_: Any, t: Any = None) -> LuaTable:
        return npc(id_, t)

    def identity_last(*args: Any) -> Any:
        for arg in reversed(args):
            if isinstance(arg, LuaTable):
                return arg
        return args[-1] if args else None

    constructors: dict[str, Callable[..., Any]] = {
        "q": q,
        "quest": q,
        "n": n_,
        "npc": n_,
        "m": m,
        "map": m,
        "inst": inst,
        "ach": ach,
        "achievement": ach,
        "i": item,
        "item": item,
        "o": obj,
        "object": obj,
        "sp": spell,
        "spell": spell,
        "r": recipe,
        "recipe": recipe,
        "faction": faction,
        "header": header,
        "objective": objective,
        "qo": objective,
        "questobjective": objective,
        "exploration": exploration,
        "prof": prof,
        "profession": prof,
        "bubbleDown": bubbleDown,
        "bubbleDownSelf": bubbleDownSelf,
        "applyData": applyData,
        "applyDataSelf": applyData,
        "clone": clone,
        "a": a,
        "h": h,
        "pvp": pvp,
        "root": root,
        "maproot": maproot,
        "battleground": battleground,
        "createHeader": createHeader,
        "visit_exploration": visit_exploration,
        "explorationHeader": explorationHeader,
        "filter": filter_,
        "cl": class_,
        "class": class_,
        "race": race,
        "struct": lambda field, ident, t=None: _struct(str(field), ident, t),
        "print": lambda *args: None,
        "error": lambda *args: None,
        "type": lambda v: type(v).__name__,
        "tostring": _lua_tostring,
        "tonumber": lambda v: float(v) if isinstance(v, str) and v.replace(".", "", 1).isdigit() else v,
        "pairs": lambda t: t,
        "ipairs": lambda t: t,
        "select": lambda *args: args[-1] if args else None,
        "setmetatable": lambda t, _mt: t,
        "getmetatable": lambda _t: None,
        "rawget": lambda t, k: t.get(k) if isinstance(t, LuaTable) else None,
        "rawset": lambda t, k, v: t.set(k, v) if isinstance(t, LuaTable) else None,
        "applyevent": applyevent,
        "applyclassicphase": identity_last,
        "applyeventself": applyevent,
        "bubbleDownFiltered": lambda data, _filter, t=None: _bubble_down(data, t),
        "bubbleDownAndReplace": _bubble_down,
    }
    env.update(constructors)
    env["ExportDB"] = LuaTable()
