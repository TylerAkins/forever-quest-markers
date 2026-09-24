---
name: wowhead-quest-database
description: Refresh the Wowhead Forever quest database, check for upstream changes, and update lastCheckedForChanges. Use when the user says "go look for changes", update Wowhead data, or work on the ATT replacement database.
---

# Wowhead quest database maintenance

## References

- Source URL list (human): `docs/wowhead-quest-database.md`
- Source URL list (code): `tools/wowhead_db/sources.py`
- Data directory: `data/wowhead/`
- Cutover plan (addon not in scope here): `docs/WOWHEAD_DATABASE_CUTOVER.md`

## When the user says "go look for changes"

1. Read `data/wowhead/manifest.json` and note `lastCheckedForChanges`.
2. Run index refresh (respect rate limits):

   ```bash
   python3 tools/build_wowhead_db.py sync-sources --rebuild-zone-map
   ```

3. Compare new `data/wowhead/sources/*.json` to git:
   - New quest IDs in any snapshot
   - Changed `envChange` blocks on existing rows
   - Quest count deltas per slug in `manifest.json` → `sources`
4. Update `data/wowhead/manifest.json` (`lastCheckedForChanges` is set by the tool).
5. If detail fields are needed for new/changed quests, run (in batches):

   ```bash
   python3 tools/build_wowhead_db.py sync-quests --limit 100
   ```

6. Summarize: counts, notable new Forever quests, PvP/dungeon/raid categorization changes.

## Rate limiting

- Default `--delay 1.25` seconds between uncached HTTP requests.
- HTML cache: `.cache/wowhead-html/` (safe to delete; re-fetch is slow).
- Never parallel-scrape Wowhead from this repo.

## Pin categories

See `data/wowhead/pin_categories.json`. PvP uses purple tint; raid category is mostly placeholder except Onyxia.

## Tests

```bash
python3 tests/test_wowhead_db.py
```
