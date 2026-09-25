# Changelog

Notable changes to Forever Quest Pins. Numbered releases use `v*` tags. Builds from `main` are available as commit-specific GitHub Actions artifacts for testing.

## 0.1.37 - 2026-09-25

- Update the ATT Forever quest database to `19896d7fddbd815e034872fb14729684076348be`.
- Ship 3967 quests with 4230 coordinate pins across 49 maps.

## 0.1.36 - 2026-09-25

- Update the ATT Forever quest database to `8c98ec1d81128e317eb04f21bc25290d7d8b2049`.
- Ship 3818 quests with 4081 coordinate pins across 49 maps.

## 0.1.35 - 2026-09-24

- Learn missing NPC quest starters from offered quests during the current session, including when map coordinates are unavailable.
- Keep NPC tooltip quests visible with a placeholder when their titles are unavailable, and retry failed title loads on later lookups.

## 0.1.34 - 2026-09-24

- Update the ATT Forever quest database to `29473e9ec0f9081bbc4adf9bd1d77263ab0ed8f1`.
- Ship 3788 quests with 4048 coordinate pins across 49 maps.

## 0.1.33 - 2026-09-23

- Turn off **Show trivial / low-level pins** and **Show AQ war effort pins** by default so new installs see a quieter map; enable them under AddOns or with `/fqp trivial` and `/fqp wareffort`.

## 0.1.32 - 2026-09-23

- Treat this character's completed-quest list as the only completion source when it loads, so a follow-up such as The Stagnant Oasis stays hidden until The Forgotten Pools is turned in on this character.

## 0.1.31 - 2026-09-23

- Preserve ATT `requireSkill` restrictions in the generated quest database.
- Hide profession-specific quest pins and NPC tooltip rows unless the character knows the required profession or specialization.

## 0.1.30 - 2026-09-23

- Update the ATT Forever quest database to `1bf370c85bb1f2a8fd609677555fc61ef86b0984`.
- Ship 3786 quests with 4046 coordinate pins across 49 maps.

## 0.1.29 - 2026-09-22

- Update the ATT Forever quest database to `7dac12df8c523de5519dcb84480cea0010b7ff12`.
- Ship 3698 quests with 3958 coordinate pins across 49 maps.

## 0.1.28 - 2026-09-21

- Show available ATT-listed quests in NPC mouseover tooltips with their recommended quest levels, independently of map-pin visibility.
- Add an enabled-by-default NPC tooltip setting and refresh rows when quest state, title, or level data changes.
- Preserve Forever's native objective blocks and omit incomplete or completed finisher rows because the tested client does not expose a reliable quest-to-finisher relationship on hover.
- Refresh ATT source provenance to `3365ae17615c11bd7c091ddcf5b99ac7b9cee7b4`; the shipped quest records remain unchanged from 0.1.27.

## 0.1.27 - 2026-09-21

- Update the ATT Forever quest database to `5cf53e4932c7359506c8ec03701aa332c934756b`.
- Ship 3698 quests with 3958 coordinate pins across 49 maps.

## 0.1.26 - 2026-09-20

- Extend red-orange map pins to ATT dungeon and raid quests, including the Ragefire Chasm quests, alongside attunement chains.
- Add an optional auto-accept recommended-level ceiling, disabled by default, with a -5 to +5 slider defaulting to +1 relative to the player's level.

## 0.1.25 - 2026-09-20

- Register map pins with Blizzard's map pin pool so the map owns their layering, scaling, and redraw lifecycle.

- Remove the always-visible fallback icon layer and avoid resetting unchanged pin anchors every frame.
- Add an optional local account SavedVariables loading repair for affected Forever clients, with a TOC backup and dry-run mode.

- Synchronize revisioned account and character settings with legacy/CVar mirrors and a logout flush. Affected Forever clients still require the optional local settings-loader repair.
- Show complete ATT-derived dungeon and raid attunement chains with red-orange `!` pins; mixed stacks remain yellow.
- Extract faction-specific ATT quest wrappers and regenerate the database at `5b09b3adf6816fcf95acef09251169e5ae97e80e`.
- Ship 3665 quests with 3925 coordinate pins across 49 maps, including 27 attunement quests.

## 0.1.24 - 2026-09-20

- Show ATT-marked repeatable quest starts with blue `!` pins; mixed normal/repeatable stacks remain yellow.
- Add a default-on setting and `/fqp repeatable` command for repeatable quest pins.
- Update the ATT Forever quest database to `5b09b3adf6816fcf95acef09251169e5ae97e80e`.
- Ship 3505 quests with 3729 coordinate pins across 49 maps.

## 0.1.23 - 2026-09-20

- Update the ATT Forever quest database to `6274f2e694e7894f95adb2419a0f18155b2fe0e0`.
- Ship 3505 quests with 3729 coordinate pins across 49 maps.

## 0.1.22 - 2026-09-20

- Update the ATT Forever quest database to `54e1fefdbe3b555d38a5560a35ab0c56382870c6`.
- Ship 3503 quests with 3727 coordinate pins across 49 maps.

## 0.1.21 — 2026-09-19

- Simplify settings persistence to one authoritative account-wide table initialized once on `ADDON_LOADED`.
- Migrate missing values from the legacy per-character table without continuing to synchronize two competing stores.
- Mirror the seven boolean options into a custom CVar as a temporary fallback for Forever 1.60.1 builds that restore CVars but skip addon SavedVariables.

## 0.1.20 — 2026-09-19

- Fix options resetting after `/reload` again: do not create empty SavedVariables on `ADDON_LOADED` before Forever injects saved tables; prefer the per-character table when merging; always write both SavedVariables on change.

## 0.1.19 — 2026-09-19

- Optional **AQ war effort** pins (Orgrimmar / Ironforge commodity turn-ins). On by default; turn off under AddOns or with `/fqp wareffort` if the stacked markers are too noisy.

## 0.1.18 — 2026-09-19

- Options persist again after `/reload` for new installs
- If you already ran **0.1.10–0.1.16** and a toggle still snaps back: fully close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under account and character `SavedVariables`. New users skip this.
- `/fqp wipe` only prints those paths; it does not delete files while the client is running
- Do not copy a default-filled placeholder over a SavedVariables table Forever injects later

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
