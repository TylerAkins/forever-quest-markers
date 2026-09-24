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

## Refresh (paste-URL scan)

**Default:** paste Wowhead URLs to an agent. **The agent fetches and ingests** (you do not):

```bash
python3 tools/build_wowhead_db.py ingest --url 'https://www.wowhead.com/forever/quests/...' --delay 1.5
```

See `docs/skills/wowhead-quest-database/SKILL.md`.

**Bulk (optional):** `sync-sources` / `sync-quests` for full re-scrapes. HTML cache: `.cache/wowhead-html/`.

| File | Contents |
|------|----------|
| `object_index.json` | Quest-start **objects** from `objects/quests` (JSON listview) |
| `quest_index.json` | Quest list rows from zone/dungeon/etc. pages |

## “Go look for changes”

Tell an agent: **read `docs/skills/wowhead-quest-database/SKILL.md`** — re-scan URLs from `docs/wowhead-quest-database.md` in batches and update `manifest.json` → `lastCheckedForChanges`.
