#!/usr/bin/env python3
"""Build Forever Quest Pins database files from All The Things Forever data."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from att_dsl.constants import BuildContext, load_forever_constants
from att_dsl.emit import write_outputs
from att_dsl.evaluator import Environment, evaluate_chunk, new_environment
from att_dsl.extract import ExtractResult, extract_from_roots
from att_dsl.parser import ParseError, parse_lua
from att_dsl.preprocessor import PreprocessError, preprocess


ATT_REPO_URL = "https://github.com/ATTWoWAddon/AllTheThings.git"
SKIP_DIR_NAMES = {".config", "zzold", ".wago", ".git"}


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    att_root = _resolve_att_root(args)
    sha = _git_sha(att_root) if args.att_sha is None else args.att_sha
    ctx = load_forever_constants(att_root)
    forever_db = att_root / ".contrib" / ".db" / "forever"
    if not forever_db.is_dir():
        raise SystemExit(f"Forever database not found: {forever_db}")

    files = _lua_files(forever_db)
    result = ExtractResult()
    errors: list[str] = []

    for path in files:
        rel = path.relative_to(forever_db).as_posix()
        try:
            _parse_file(path, rel, ctx, result)
            result.files_parsed += 1
        except (ParseError, PreprocessError, ValueError) as exc:
            message = f"{rel}: {exc}"
            errors.append(message)
            print(f"ERROR: {message}", file=sys.stderr)

    if errors and not args.keep_going:
        print(f"Failed to parse {len(errors)} file(s).", file=sys.stderr)
        return 1

    stats = _stats(result, sha, files, errors)
    out_dir = Path(args.out)
    write_outputs(out_dir, result.quests, sha, ATT_REPO_URL, stats)

    _log_summary(stats)
    if args.report:
        Path(args.report).write_text(json.dumps(stats, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--att",
        dest="att_path",
        help="Path to a local AllTheThings checkout",
    )
    parser.add_argument(
        "--clone-dir",
        default=str(ROOT / ".cache" / "AllTheThings"),
        help="Where to clone ATT when --att is not provided",
    )
    parser.add_argument("--att-url", default=ATT_REPO_URL, help="ATT git URL used when cloning")
    parser.add_argument("--att-sha", default=None, help="Override recorded ATT commit SHA")
    parser.add_argument(
        "--out",
        default=str(ROOT / "Database"),
        help="Directory for generated Lua/JSON outputs",
    )
    parser.add_argument("--report", help="Optional extra JSON report path")
    parser.add_argument("--keep-going", action="store_true", help="Continue after parse errors")
    parser.add_argument("--skip-clone", action="store_true", help="Do not clone; --att is required")
    return parser.parse_args(argv)


def _resolve_att_root(args: argparse.Namespace) -> Path:
    if args.att_path:
        path = Path(args.att_path).expanduser().resolve()
        if not path.is_dir():
            raise SystemExit(f"ATT path does not exist: {path}")
        return path
    if args.skip_clone:
        raise SystemExit("--att is required when --skip-clone is set")
    clone_dir = Path(args.clone_dir).expanduser().resolve()
    _ensure_att_checkout(clone_dir, args.att_url)
    return clone_dir


def _ensure_att_checkout(clone_dir: Path, url: str) -> None:
    if (clone_dir / ".git").is_dir():
        subprocess.run(["git", "-C", str(clone_dir), "fetch", "--depth", "1", "origin"], check=False)
        subprocess.run(["git", "-C", str(clone_dir), "checkout", "FETCH_HEAD"], check=False)
        return
    clone_dir.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", url, str(clone_dir)],
        check=True,
    )
    subprocess.run(
        [
            "git",
            "-C",
            str(clone_dir),
            "sparse-checkout",
            "set",
            ".contrib/.db/forever",
            ".contrib/Parser/lib/Constants",
            ".contrib/Standard.lua",
        ],
        check=True,
    )


def _git_sha(repo: Path) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def _lua_files(forever_db: Path) -> list[Path]:
    files: list[Path] = []
    for path in sorted(forever_db.rglob("*.lua")):
        rel_parts = {part.lower() for part in path.relative_to(forever_db).parts}
        if rel_parts & SKIP_DIR_NAMES:
            continue
        files.append(path)
    return files


def _parse_file(path: Path, rel: str, ctx: BuildContext, result: ExtractResult) -> None:
    source = path.read_text(encoding="utf-8")
    processed = preprocess(source, ctx)
    chunk = parse_lua(processed, filename=rel)
    env: Environment = new_environment(ctx)
    evaluate_chunk(chunk, env)
    extract_from_roots(env.get("_roots", []), rel, result)


def _stats(
    result: ExtractResult,
    sha: str,
    files: list[Path],
    errors: list[str],
) -> dict[str, object]:
    coord_pins = sum(len(record.coords) for record in result.quests.values())
    maps = sorted(
        {
            coord.map_id
            for record in result.quests.values()
            for coord in record.coords
        }
    )
    return {
        "att_sha": sha,
        "att_source": ATT_REPO_URL,
        "files_discovered": len(files),
        "files_parsed": result.files_parsed,
        "parse_errors": errors,
        "quests_seen": result.quests_seen,
        "quests_emitted": len(result.quests),
        "quests_with_coords": result.quests_with_coords,
        "coord_pins": coord_pins,
        "excluded": dict(sorted(result.excluded.items())),
        "map_ids": maps,
        "map_count": len(maps),
    }


def _log_summary(stats: dict[str, object]) -> None:
    print(f"ATT commit: {stats['att_sha']}")
    print(f"Files parsed: {stats['files_parsed']} / {stats['files_discovered']}")
    print(f"Quests seen: {stats['quests_seen']}")
    print(f"Quests with coordinates: {stats['quests_with_coords']}")
    print(f"Coordinate pins: {stats['coord_pins']}")
    print(f"Maps indexed: {stats['map_count']}")
    excluded = stats["excluded"]
    if excluded:
        print("Excluded:")
        for reason, count in excluded.items():  # type: ignore[union-attr]
            print(f"  {reason}: {count}")
    errors = stats["parse_errors"]
    if errors:
        print(f"Parse errors: {len(errors)}")  # type: ignore[arg-type]


if __name__ == "__main__":
    raise SystemExit(main())
