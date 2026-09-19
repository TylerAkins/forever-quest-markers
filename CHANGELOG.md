# Changelog

Notable changes to Forever Quest Pins. The GitHub [`latest`](https://github.com/TylerAkins/forever-quest-markers/releases/tag/latest) pre-release tracks `main`. Numbered releases are `v*` tags.

## 0.1.17 — 2026-09-19

- Bind options the way working Forever addons do (Quest Master / AceDB, HideAnything): one SavedVariables table, created on `ADDON_LOADED` if missing, mutated in place, never replaced; write the same keys onto the per-character table; flush on logout. Drop `LoadSavedVariablesFirst` and the late-bind scratch buffer that left Forever serializing an empty table.

## 0.1.16 — 2026-09-19

- Store settings in a separate per-character SavedVariables table (`ForeverQuestPinsCharacterSettings`) because Forever is not persisting this addon’s account-wide table; request SavedVariables before addon files load

## 0.1.15 — 2026-09-19

- Remove native Settings registrations: initializing a proxy setting can invoke its default-value setter and overwrite a saved `autoAccept=true` / `autoTurnIn=true` with `false`; the Options canvas now exclusively reads and writes the addon SavedVariables table

## 0.1.14 — 2026-09-19

- Stop creating `ForeverQuestPinsDB_Settings` at file load (Forever can bind the real SavedVariables table later); buffer changes until that table exists, merge on login, and only create a new table on `PLAYER_ENTERING_WORLD` if still missing

## 0.1.13 — 2026-09-19

- Fix Options checkboxes that used Blizzard’s legacy Settings API fallback (values lived outside `ForeverQuestPinsDB_Settings` and vanished on `/reload`); use proxy settings that call `SetOption`, drop the broken fallback, and retry registration on `PLAYER_LOGIN`
- `/fqp settings` dumps raw SavedVariables vs effective values

## 0.1.12 — 2026-09-19

- Persist options the usual way: fill `ForeverQuestPinsDB_Settings` on `ADDON_LOADED`, write keys on that table, bind Forever Settings checkboxes to it, and toggle from the saved flag instead of `GetChecked`
- `/fqp stats` prints auto-accept and auto-turn-in

## 0.1.11 — 2026-09-19

- Persist auto-accept / auto-turn-in in the addon SavedVariables table Forever actually writes (not a separate `_G` copy), merge clicks if that table arrives late, and do not treat Options `SetChecked` as a click

## 0.1.10 — 2026-09-19

- Keep auto-accept and auto-turn-in checked after `/reload` (do not assign defaults before SavedVariables load; re-sync the Options checkboxes)

## 0.1.9 — 2026-09-19

- Pin tooltips show suggested quest level like the Forever tracker (`[9] Minshina's Skull`), via `C_QuestLog.GetQuestDifficultyLevel`

## 0.1.8 — 2026-09-19

- Use Blizzard’s retail `QuestNormal` bang at a fixed 24px size
- Drop the solid yellow square behind pins
- Keep `Media/QuestAvailable.tga` only if `SetAtlas` errors
- Do not bind gossip `AvailableQuestIcon` on the map

## 0.1.7

- Draw a solid yellow fill so a hoverable pin could not be an empty hitbox
- Overlay the bundled TGA instead of Forever’s empty gossip / atlas binds

## 0.1.6

- Prefer gossip `AvailableQuestIcon` when `QuestNormal` drew nothing
- Treat ATT breadcrumb sources as skippable (Gornek’s Cutting Teeth vs Kaltunk)
- Remember quests an NPC just offered, including Forever-only starts missing from ATT

## 0.1.5

- Show Morin Cloudstalker’s The Venture Co. and Supervisor Fizsprocket after the Ravaged Caravan crate
- Keep ATT coordinates (plus Morin’s crate-end patrol pin); do not replace them with a live or stale NPC point
- `/fqp why <id>` and `/fqp available`
- Merges to `main` publish a moving `latest` pre-release zip

## 0.1.4

- Windowed and maximized pins stay on the map art
- Stack overlapping starts onto one bang
- Project live NPC positions from continent coords onto the zone map
- Treat `GetQuestsCompleted` as a completion fallback

## 0.1.3

- Fixed on-screen bang size (do not inherit map zoom or native atlas size)
- Draw pins above map tiles
- Keep a pin when the first layout pass has no canvas size yet

## 0.1.2

- Auto-accept and auto-turn-in options (`/fqp accept`, `/fqp turnin`; hold Shift to skip)
- Debug tooltips; names instead of IDs unless debug is on
- Prefetch quest titles
- Parent pins to the map canvas so they do not drift on resize
- Snap wandering quest-giver pins while the NPC is visible

## 0.1.1

- Blizzard `QuestNormal` atlas on map pins, with gossip and TGA fallbacks
- Unmigrated ATT `zzOLD` zones as a fallback for classic (pre-Cata) quests
- Seasonal pins off unless `/fqp seasonal` is on or the event is active
- Project zone pins onto continent maps

## 0.1.0

- Initial release: native world-map start markers for unaccepted quests
- ATT Forever database converter and automated update workflow
