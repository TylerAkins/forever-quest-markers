---
name: quest-database
description: Refresh the Forever quest database from the URL list in docs/quest-database.md. Use when the user says "go look for changes" or asks to update data/forever-quests.
---

# Forever quest database

The URL list is `docs/quest-database.md` and `tools/quest_db/sources.py`. Data lives in `data/forever-quests/`. Cutover into the addon is `docs/QUEST_DATABASE_CUTOVER.md` and is out of scope until the user asks.

Quest detail pages are fetched in Chrome on the user's machine (`--browser`). Do not start a bulk download from a cloud agent.

## Page types

| URL pattern | Result |
|-------------|--------|
| `.../quests/...` | `sources/*.json` + `quest_index.json` |
| `.../objects/quests` | `object_index.json` (names and ids only, no spawn coordinates) |
| `.../quest=<id>` | `details/<id>.json` |
| `.../object=<id>` | Not downloaded yet. Required for multi-spawn object starters |

## Look for changes

1. Read `data/forever-quests/manifest.json` → `lastCheckedForChanges`.
2. Re-ingest the list URLs from `docs/quest-database.md`.
3. Diff `sources/`, `quest_index.json`, and `object_index.json`.
4. New quest ids need `sync-quests --browser --quest <id>` on the user's machine.

```bash
python3 tools/fetch_quest_pages.py ingest --browser --force --url 'https://www.wowhead.com/forever/quests/...'
python3 tools/fetch_quest_pages.py sync-quests --browser --force --quest 7507
```

## Tests

```bash
python3 tests/test_quest_pages.py
```
