# Source database → addon cutover plan

This document describes how to **later** wire the Source-built database into Forever Quest Pins (and share it with forever-guide-mate). Building `data/forever-quests/` is intentionally separate from shipping a new addon version.

## Current state

| Layer | Source today | Target |
|-------|----------------|--------|
| Shipped pins | `Database/ForeverQuests.lua` from ATT via `tools/build_quest_db.py` | Generated from `data/forever-quests/` |
| Coordinates | ATT `coord` / `coords` | Source `Mapper` start pins + `zone_ui_map_ids.json` |
| Repeatable / attunement / instance | ATT flags | Source infobox + source taxonomy + attunement seed |
| PvP | Not distinguished | `pinCategory: pvp` + purple tint (new art `QuestPvP.tga`) |

## Phase 1 — Data parity (no player release)

1. **Complete detail sync**

   ```bash
   python3 tools/fetch_quest_pages.py sync-quests
   ```

2. **Add emitter** `tools/quest_db/emit_lua.py` (future PR) that writes:
   - `Database/ForeverQuests.lua` (or `Database/SourceQuests.lua` during dual-run)
   - `Database/Metadata.lua` with `source = "source"`, scrape timestamps, quest counts

3. **Diff harness** — script comparing ATT output vs Source output per `questID`:
   - `mapID`, `x`, `y`, `qg`, `faction`, flags
   - Report-only CI job; do not fail until parity is acceptable

4. **Attunement** — replace `attunement_quest_ids.json` seed with Source-derived chains when available (prerequisite graph from detail pages + manual overrides).

## Phase 2 — Addon integration

1. **MapPins.lua**
   - Extend `SetPinTexture` with PvP branch using tint from `pin_categories.json`.
   - Add `Media/QuestPvP.tga` fallback (same silhouette as `QuestNormal`).
   - Read `pinCategory` or legacy booleans from generated Lua.

2. **Eligibility / tooltips**
   - Prefer Source-sourced prerequisite IDs (`prerequisiteQuestIds` in detail JSON) for availability.
   - Keep runtime quest title APIs; use DB for static fields only.

3. **TOC / packager**
   - Ship new Lua only after parity sign-off.
   - Update `ATTRIBUTION.md` (Source + Blizzard; remove ATT data credit when ATT file is dropped).

## Phase 3 — CI and releases

1. New workflow (or extend `update-att-db.yml` successor):
   - Weekly `sync-sources` on a bot branch
   - Open PR when `quest_index.json` or `sources/` change
   - Optional slow `sync-quests` on self-hosted runner

2. **Versioning**: database PRs do not require `VERSION` bump until Phase 2 merges.

## Phase 4 — forever-guide-mate

The JSON schema is designed for reuse:

- `quest_index.json` — discovery, zones, sides, levels, envChange
- `details/<id>.json` — mapper objectives, NPC ids, coordinates for guides
- `pin_categories.json` — consistent UX colors

Consume via shared git submodule or copied `data/forever-quests/` snapshot; avoid duplicating scrape logic in the guide addon.

## Rollback

Keep `tools/build_quest_db.py` and ATT workflow until Source parity is proven. Toggle with a build flag:

```bash
# Future
python3 tools/build_quest_db.py --source att|source
```

## Checklist before first Source-shipped release

- [ ] Detail coverage ≥ 99% of indexed quest IDs with start pins
- [ ] Diff report: &lt; agreed threshold for coordinate drift vs ATT
- [ ] PvP quests classified on all three battleground indexes
- [ ] Manual pass on tooltip regressions (NPC finisher rows unchanged policy)
- [ ] Player-facing changelog + attribution updated
