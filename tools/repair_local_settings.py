#!/usr/bin/env python3
"""Link this addon's live account settings into Forever's ordinary Lua loader."""

import argparse
from pathlib import Path
import shutil


def repair(addon: Path, saved: Path, *, dry_run: bool = True) -> None:
    """Patch only ForeverQuestPins; never modify the SavedVariables file."""
    addon = addon.resolve()
    saved = saved.resolve(strict=True)
    toc = addon / "ForeverQuestPins.toc"
    if addon.name != "ForeverQuestPins" or saved.name != "ForeverQuestPins.lua":
        raise ValueError("Expected ForeverQuestPins addon and SavedVariables paths")
    text = toc.read_text(encoding="utf-8")
    link = addon / "LocalSavedVariables"
    entry = "LocalSavedVariables\\ForeverQuestPins.lua"
    if link.is_symlink():
        if link.resolve() != saved.parent:
            raise ValueError("Existing settings link points to another account")
    elif link.exists():
        raise ValueError("Refusing to replace an existing LocalSavedVariables directory")
    lines = text.splitlines()
    if entry not in lines:
        index = next(i for i, line in enumerate(lines) if line.strip() and not line.startswith("#"))
        lines.insert(index, entry)
    print(f"Link {link} to {saved.parent}; load live account settings before addon code")
    if dry_run:
        return
    backup = toc.with_suffix(".toc.before-settings-repair")
    if not backup.exists():
        shutil.copy2(toc, backup)
    if not link.is_symlink():
        link.symlink_to(saved.parent, target_is_directory=True)
    toc.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--saved", type=Path, required=True)
    parser.add_argument("--apply", action="store_true", help="Apply only with WoW fully closed")
    args = parser.parse_args()
    repair(args.addon, args.saved, dry_run=not args.apply)
