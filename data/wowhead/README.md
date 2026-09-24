# Wowhead Forever quest database

Structured quest data scraped from [Wowhead Forever](https://www.wowhead.com/forever) for **Forever Quest Pins** and future **forever-guide-mate** work. This tree is independent of the shipped ATT-derived `Database/ForeverQuests.lua` until a deliberate cutover (see `docs/WOWHEAD_DATABASE_CUTOVER.md`).

## Layout

| Path | Purpose |
|------|---------|
| `manifest.json` | Schema version, per-source `lastFetched`, **`lastCheckedForChanges`**, aggregate stats |
| `quest_index.json` | One row per quest ID (merged from all index pages) |
| `sources/*.json` | Raw list snapshots per Wowhead URL |
| `details/<id>.json` | Per-quest mapper, infobox flags, start pins, prerequisites |
| `zone_ui_map_ids.json` | Wowhead zone id → UiMapID (bootstrapped from ATT pins + index) |
| `attunement_quest_ids.json` | Attunement chain seeds (from current ATT export until Wowhead tagging exists) |
| `pin_categories.json` | Pin color / category reference (includes PvP purple) |

## Refresh

```bash
# Index pages only (~2 minutes at default rate limit)
python3 tools/build_wowhead_db.py sync-sources --rebuild-zone-map

# Quest detail pages (resumable; run in batches)
python3 tools/build_wowhead_db.py sync-quests --limit 200
python3 tools/build_wowhead_db.py sync-quests   # continues until complete
```

HTML is cached under `.cache/wowhead-html/` (not committed).

## “Go look for changes”

Tell an agent: **read `docs/skills/wowhead-quest-database/SKILL.md` and run the refresh workflow.** That skill updates `manifest.json` → `lastCheckedForChanges` and compares new list snapshots to the committed `sources/` files.
