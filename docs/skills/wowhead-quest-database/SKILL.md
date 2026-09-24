---
name: wowhead-quest-database
description: Scan Wowhead Forever URLs the user pastes, merge into data/wowhead, and update lastCheckedForChanges. Use when the user pastes Wowhead links, says "go look for changes", or asks to refresh the ATT replacement database.
---

# Wowhead quest database (agent scans URLs)

The **user only pastes Wowhead URLs** (or says “go look for changes”). **You** fetch and ingest. Never tell the user to curl, wget, or run fetch steps themselves.

## References

- URL index: `docs/wowhead-quest-database.md`
- Data: `data/wowhead/` (`manifest.json`, `quest_index.json`, `object_index.json`, `sources/`, `details/`)
- Cutover (addon later): `docs/WOWHEAD_DATABASE_CUTOVER.md`

## When the user pastes URL(s)

For **each** URL (one shell invocation per URL, or `--url-file` for a batch):

```bash
python3 tools/build_wowhead_db.py ingest --url 'PASTED_URL' --delay 1.5
```

The ingest command **fetches** the page (browser-like user agent), parses it, and writes under `data/wowhead/`. Do not use `--html-file` unless you already saved HTML while debugging.

After each URL (or small batch), **commit and push** if this is an ongoing DB build on a branch.

Wait **≥1.5s** between Wowhead requests (`--pause 1.5` with `--url-file`).

### Page types

| URL pattern | Result |
|-------------|--------|
| `.../quests/...` (zones, dungeons, classes, etc.) | `sources/*.json` + `quest_index.json` |
| `.../objects/quests` | `object_index.json` (JSON listview, not quest Listview) |
| `.../quest=123/...` | `details/123.json` |

## “Go look for changes”

1. Read `data/wowhead/manifest.json` → `lastCheckedForChanges`.
2. **You** re-run `ingest --url` for URLs from `docs/wowhead-quest-database.md` (in batches).
3. Diff `sources/`, `quest_index.json`, `object_index.json` for new IDs or `envChange` deltas.
4. Summarize and update git; `lastCheckedForChanges` is set by ingest.

## Bulk optional

Only if the user asks to refresh everything:

```bash
python3 tools/build_wowhead_db.py sync-sources --delay 1.5
```

## Pin categories

`data/wowhead/pin_categories.json` — PvP purple `(0.78, 0.22, 0.95)`.

## Tests

```bash
python3 tests/test_wowhead_db.py
```
