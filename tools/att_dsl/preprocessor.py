"""ATT `-- #if` / `-- #endif` preprocessor.

ATT's C# parser treats `-- #if ...` comments as conditional compilation
directives before Lua is evaluated. Forever's current patch is 1.60.1, so
`AFTER CATA` is false and `BEFORE CATA` is true.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .constants import BuildContext, parse_version_token


_DIRECTIVE_RE = re.compile(
    r"^\s*--\s*#(?P<kind>if|ifdef|ifndef|elseif|elif|else|endif)\b(?P<rest>.*)$",
    re.IGNORECASE,
)


class PreprocessError(ValueError):
    def __init__(self, message: str, line: int | None = None) -> None:
        self.line = line
        prefix = f"line {line}: " if line is not None else ""
        super().__init__(prefix + message)


@dataclass
class _Frame:
    parent_active: bool
    taking: bool
    taken: bool
    kind: str


def preprocess(source: str, ctx: BuildContext) -> str:
    """Return Lua source with inactive `-- #if` blocks removed."""
    lines = source.splitlines(keepends=True)
    stack: list[_Frame] = []
    output: list[str] = []

    for index, line in enumerate(lines, start=1):
        stripped = line.split("\n", 1)[0].rstrip()
        match = _DIRECTIVE_RE.match(stripped)
        if match:
            kind = match.group("kind").lower()
            rest = match.group("rest").strip()
            if kind in {"if", "ifdef", "ifndef"}:
                parent_active = stack[-1].taking if stack else True
                cond = _eval_condition(rest, ctx, kind)
                taking = parent_active and cond
                stack.append(_Frame(parent_active, taking, taking, kind))
            elif kind in {"elseif", "elif"}:
                if not stack or stack[-1].kind == "else":
                    raise PreprocessError("unexpected #elseif", index)
                frame = stack[-1]
                cond = _eval_condition(rest, ctx, "if")
                taking = frame.parent_active and (not frame.taken) and cond
                frame.taking = taking
                frame.taken = frame.taken or taking
            elif kind == "else":
                if not stack:
                    raise PreprocessError("unexpected #else", index)
                frame = stack[-1]
                taking = frame.parent_active and (not frame.taken)
                frame.taking = taking
                frame.taken = True
                frame.kind = "else"
            elif kind == "endif":
                if not stack:
                    raise PreprocessError("unexpected #endif", index)
                stack.pop()
            output.append("\n" if line.endswith("\n") else "")
            continue

        active = stack[-1].taking if stack else True
        if active:
            output.append(line)
        else:
            output.append("\n" if line.endswith("\n") else "")

    if stack:
        raise PreprocessError("unclosed #if directive", len(lines))
    return "".join(output)


def _eval_condition(expr: str, ctx: BuildContext, kind: str) -> bool:
    expr = expr.split("--", 1)[0].strip()
    if kind == "ifndef":
        return not _eval_or(expr, ctx)
    return _eval_or(expr, ctx)


def _eval_or(expr: str, ctx: BuildContext) -> bool:
    parts = re.split(r"\s+OR\s+", expr, flags=re.IGNORECASE)
    return any(_eval_and(part.strip(), ctx) for part in parts)


def _eval_and(expr: str, ctx: BuildContext) -> bool:
    parts = re.split(r"\s+AND\s+", expr, flags=re.IGNORECASE)
    return all(_eval_not(part.strip(), ctx) for part in parts)


def _eval_not(expr: str, ctx: BuildContext) -> bool:
    expr = expr.strip()
    negated = False
    while expr.upper().startswith("NOT "):
        negated = not negated
        expr = expr[4:].strip()
    result = _eval_atom(expr, ctx)
    return (not result) if negated else result


def _eval_atom(expr: str, ctx: BuildContext) -> bool:
    if not expr:
        return False
    tokens = expr.split()
    head = tokens[0].upper()
    if head in {"AFTER", "BEFORE"}:
        if len(tokens) < 2:
            return False
        version = parse_version_token(tokens[1])
        if version is None:
            # Unknown expansion name: fail closed for AFTER, open for BEFORE.
            return head == "BEFORE"
        if head == "AFTER":
            return ctx.patch >= version
        return ctx.patch < version
    tag = head.strip("()")
    return tag in ctx.tags
