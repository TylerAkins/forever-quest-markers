---
name: wowhead-quest-database
description: Scan Wowhead Forever URLs the user pastes, merge into data/wowhead, and update lastCheckedForChanges. Use when the user pastes Wowhead links, says "go look for changes", or asks to refresh the ATT replacement database.
---

# Wowhead quest database (paste-URL scan)

**Primary workflow:** the user pastes one or more Wowhead Forever URLs (see `docs/wowhead-quest-database.md`). You **fetch each page like a browser**, then **ingest** the HTML. Do not rely on bulk `sync-sources` unless the user explicitly asks to refresh everything.

## References

- URL index: `docs/wowhead-quest-database.md`
- Data: `data/wowhead/` (`manifest.json`, `quest_index.json`, `object_index.json`, `sources/`, `details/`)
- Cutover (addon later): `docs/WOWHEAD_DATABASE_CUTOVER.md`

## Scan one pasted URL

1. Note `data/wowhead/manifest.json` → `lastCheckedForChanges` (before/after).
2. Fetch with a normal browser user agent (follow redirects):

   ```bash
   curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
     'PASTED_URL' -o /tmp/wowhead-page.html
   ```

   Wait **at least 1.5s** before the next Wowhead request.

3. Ingest (parses inline quest Listview **or** JSON `data.page.listPage.listviews` for object lists):

   ```bash
   python3 tools/build_wowhead_db.py ingest \
     --url 'PASTED_URL' \
     --html-file /tmp/wowhead-page.html
   ```

   Or let the tool fetch (same rate limit via `--delay`):

   ```bash
   python3 tools/build_wowhead_db.py ingest --url 'PASTED_URL'
   ```

4. Print the JSON report from ingest. Commit updated `data/wowhead/` when the user wants the DB saved.

### Page types

| URL pattern | Result |
|-------------|--------|
| `.../quests/...` zone/dungeon/class/etc. | Updates `sources/*.json` + `quest_index.json` |
| `.../objects/quests` | Updates `object_index.json` (quest-start objects; **not** inline quest Listview) |
| `.../quest=123/...` | Writes `details/123.json`, updates index row |

## Scan many URLs (user paste block)

Put URLs in a temp file (one per line), then:

```bash
python3 tools/build_wowhead_db.py ingest --url-file /tmp/wowhead-urls.txt --pause 1.5
```

Prefer **batches** (e.g. one region at a time) to avoid rate limits.

## “Go look for changes”

1. Read `lastCheckedForChanges` in `manifest.json`.
2. Re-scan URLs the user cares about (or the full list in `docs/wowhead-quest-database.md` in batches).
3. Diff git: new/changed quest IDs, `envChange` in list rows, object index changes.
4. For new/changed quests, scan detail URLs: `https://www.wowhead.com/forever/quest=<id>` via `ingest --url ...` (slow; batch).

Optional full refresh (rare): `python3 tools/build_wowhead_db.py sync-sources`

## Pin categories

`data/wowhead/pin_categories.json` — PvP uses **purple** tint `(0.78, 0.22, 0.95)`.

## Tests

```bash
python3 tests/test_wowhead_db.py
```
