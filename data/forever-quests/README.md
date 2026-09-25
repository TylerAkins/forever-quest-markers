# Forever quest database

Quest catalog for Forever Quest Pins and future forever-guide-mate work. This tree is independent of the shipped ATT-derived `Database/ForeverQuests.lua` until a deliberate cutover (see `docs/QUEST_DATABASE_CUTOVER.md`).

## Layout

| Path | Purpose |
|------|---------|
| `manifest.json` | Schema version, per-source `lastFetched`, **`lastCheckedForChanges`**, aggregate stats |
| `quest_index.json` | One row per quest ID (merged from all index pages) |
| `sources/*.json` | Raw list snapshots per index URL |
| `details/<id>.json` | Per-quest map data, infobox flags, start pins, prerequisites |
| `object_index.json` | Names and ids from the objects list. No spawn coordinates |
| `zone_ui_map_ids.json` | Zone id → UiMapID (bootstrapped from ATT pins + index) |
| `attunement_quest_ids.json` | Attunement chain seeds from the current ATT export |
| `pin_categories.json` | Pin color / category reference (includes PvP purple) |

## What is saved

`manifest.json` stats are the current counts. Quest detail pages are saved except quest 7507, which redirect-loops on the old name. The objects list is names and zone ids only.

World objects you click (kegs, corpses, plaques) are not the same as quest pages. Their list is:

https://www.wowhead.com/forever/objects/quests

That page does not include Chen's Empty Keg, and it does not include each spawn coordinate. Those coordinates are on each object's own page, which is not downloaded yet.

## Run it again

See `docs/quest-database.md`. HTML cache: `.cache/quest-html/`.
