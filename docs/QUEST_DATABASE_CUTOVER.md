# Quest database → addon cutover plan

This document describes how to later wire `data/forever-quests/` into Forever Quest Pins (and share it with forever-guide-mate). That tree is intentionally separate from shipping a new addon version.

## Current state

| Layer | Today | Target |
|-------|-------|--------|
| Shipped pins | `Database/ForeverQuests.lua` from ATT via `tools/build_quest_db.py` | Generated from `data/forever-quests/` |
| Quest pages | 5057 of 5058 detail files. Quest 7507 still missing | Bare `quest=<id>` URL saved for 7507 |
| Coordinates | Start pins only when the quest page marks a start. Turn-ins stay inside `mapper`. Object spawn lists are not downloaded | Start and turn-in pins, plus every spawn from object pages |
| Repeatable / attunement / instance | Infobox flags, list taxonomy, ATT attunement seed | Same, with attunement derived from the quest graph |
| PvP | `pinCategory: pvp` in the JSON | Purple tint in the addon (new art `QuestPvP.tga`) |

## Phase 1 — Data parity (no player release)

1. **Finish the one missing quest page**

   ```bash
   python3 tools/fetch_quest_pages.py sync-quests --browser --force --quest 7507
   ```

2. **Object spawns.** Download each object page for ids in `object_index.json` and attach every coordinate to the quest that object starts. Item quests whose starter is not on that list need the item page as well.

3. **Add emitter** `tools/quest_db/emit_lua.py` (future PR) that writes:
   - `Database/ForeverQuests.lua`
   - `Database/Metadata.lua` with timestamps and quest counts

4. **Diff harness** — script comparing ATT output vs this database per `questID`:
   - `mapID`, `x`, `y`, `qg`, `faction`, flags
   - Report-only CI job; do not fail until parity is acceptable

5. **Attunement** — replace `attunement_quest_ids.json` seed with chains from the prerequisite graph plus manual overrides.

## Phase 2 — Addon integration

1. **MapPins.lua**
   - Extend `SetPinTexture` with PvP branch using tint from `pin_categories.json`.
   - Add `Media/QuestPvP.tga` fallback (same silhouette as `QuestNormal`).
   - Read `pinCategory` or legacy booleans from generated Lua.

2. **Eligibility / tooltips**
   - Prefer `prerequisiteQuestIds` in detail JSON for availability.
   - Keep runtime quest title APIs; use DB for static fields only.

3. **TOC / packager**
   - Ship new Lua only after parity sign-off.
   - Update `ATTRIBUTION.md` when the ATT file is dropped.

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

Keep `tools/build_quest_db.py` and the ATT workflow until pin parity is proven.

## Checklist before the first release that ships this database

- [ ] Detail coverage for every indexed quest id, including object-start quests that have no `start` point on the quest page
- [ ] Multi-spawn objects (Chen's Empty Keg and the rest) have one pin per spawn
- [ ] Diff report: &lt; agreed threshold for coordinate drift vs ATT
- [ ] PvP quests classified on all three battleground indexes
- [ ] Manual pass on tooltip regressions (available starts, and log quests on their end NPC)
- [ ] Player-facing changelog + attribution updated
