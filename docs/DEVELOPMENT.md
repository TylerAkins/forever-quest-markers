# Development

Forever Quest Pins is a small World of Warcraft Forever addon (Interface **16001**). Players should read [README.md](../README.md). This file is for maintaining the repo, database, and releases.

## Layout

| Path | Role |
|------|------|
| `ForeverQuestPins.toc` | Load order, Interface 16001, packager metadata |
| `Config.lua` | Saved variables, slash commands, settings panel |
| `HiddenQuests.lua` | Per-character Shift-click hidden quest pins, stored in the account DB under `hiddenQuests["Name-Realm"]` |
| `Eligibility.lua` | Completion, log, source quests, NPC-offered quests |
| `MapPins.lua` | World-map start pins |
| `Waypoints.lua` | Optional Blizzard / TomTom navigation and selected quest lifecycle |
| `AutoQuests.lua` | Optional auto-accept / auto-turn-in |
| `Core.lua` | Events and refresh |
| `Database/ForeverQuests.lua` | Generated quest records (do not edit by hand) |
| `Database/Metadata.lua` | Pinned ATT commit |
| `Database/build_report.json` | Build stats (not shipped in the player zip) |
| `VERSION` | Current stable release used by automated version checks |
| `RELEASE_NOTES.md` | Curated notes for only the current release |
| `Media/QuestAvailable.tga` | Yellow fallback bang if `QuestNormal` fails |
| `Media/QuestRepeatable.tga` | Blue fallback if the tinted `QuestNormal` atlas cannot be used |
| `Media/QuestAttunement.tga` | Red-orange fallback for dungeon and raid quests |
| `tools/build_quest_db.py` | ATT Forever `.contrib/.db/forever` → `Database/` |
| `tools/att_dsl/` | ATT Lua parser and quest extractor |
| `tools/release.py` | Prepares database releases and validates automated patch releases |
| `tools/update_forever_interface.py` | Blizzard build feed → TOC compatibility release |
| `tools/generate_quest_icon.py` | Regenerates the fallback TGA |
| `.pkgmeta` | [BigWigs packager](https://github.com/BigWigsMods/packager) rules |

## Database

Coordinates and restrictions come from [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever data (`.contrib/.db/forever`).

```bash
python3 tools/build_quest_db.py --att /path/to/AllTheThings --out Database
```

A second run on the same ATT commit produces the same bytes. NPC turn-in ids are compiled into the database but are not shown on map pins or NPC tooltips.

### Automated updates

Workflow **Update ATT database** (`.github/workflows/update-att-db.yml`):

- Daily at 06:00 UTC and on manual **Run workflow**
- Checks out ATT `main` (sparse: Forever DB + parser constants)
- Opens a versioned PR only when `Database/ForeverQuests.lua` changed; ATT SHA-only updates with no quest diff are ignored
- Closes its existing `att-db-update` PR if regenerated quest records return to the version already on `main`
- Bumps the patch version and updates `CHANGELOG.md` and the current `RELEASE_NOTES.md`
- Publishes the prepared GitHub and CurseForge release after a human reviews and merges the PR
- Needs **Settings → Actions → General → Workflow permissions → Allow GitHub Actions to create and approve pull requests**

It never pushes generated data straight to `main` or merges its own PR.

## Forever interface updates

Workflow **Update Forever interface** (`.github/workflows/update-forever-interface.yml`):

- Runs Wednesday at 12:00 UTC, after the US Tuesday and EU Wednesday maintenance windows
- Reads Blizzard's explicit `wow_classic_beta` product feed and converts versions such as `1.60.1.69913` to Interface `16001`
- Ignores build-only changes when the calculated Interface is unchanged
- Opens or refreshes the reviewed `forever-interface-update` PR with the TOC, next patch version, changelog entry, and current release notes
- Closes that fixed PR if the current Interface is already supported on `main`
- Publishes the prepared GitHub and CurseForge release only after a human merges the PR

Run it manually from `main` when an out-of-cycle Forever patch lands. If Blizzard moves Forever off `wow_classic_beta` after launch, change the single `VERSIONS_URL` constant in `tools/update_forever_interface.py` rather than falling back to another WoW flavor.

## Tests

```bash
python3 tests/test_build_quest_db.py
python3 tests/test_validate_generated.py
python3 tests/test_addon_lua.py
python3 -m pip install -r tests/requirements.txt
python3 tests/test_quest_info_runtime.py
python3 tests/test_waypoints_runtime.py
python3 tests/test_eligibility_runtime.py
python3 tests/test_pin_filters_runtime.py
python3 tests/test_compile_addon.py
python3 tests/test_att_release.py
python3 tests/test_update_forever_interface.py
```

CI (`validate`) also regenerates the database at the pinned ATT commit and fails on drift, then dry-runs the packager.

## Local builds

Build a clean, directly installable addon folder with:

```bash
python3 tools/compile_addon.py
```

Each run deletes the previous `.compiled/ForeverQuestPins` directory and recreates it from the files shipped by `.pkgmeta`. The generated TOC uses the current Git description as its version. Copy `.compiled/ForeverQuestPins` directly into the client's `Interface/AddOns` directory.

Use `python3 tools/compile_addon.py --dry-run` to list the files without changing `.compiled/`.

## Releases

| Channel | Trigger | Result |
|---------|---------|--------|
| Stable | Push an annotated `v*` tag, or merge a prepared quest database/interface PR | Numbered GitHub Release and CurseForge package |
| Preview | Merge to `main` or manually run the Release workflow | Commit-specific GitHub Actions artifact |

Only stable tags are distributed to players. Preview builds are for testing and do not push or move a Git tag. Do not point players at GitHub's “Source code” archives; the packager zip is the installable addon.

`.pkgmeta` ships addon Lua, `Database/*.lua`, `Media/`, `LICENSE`, `README.md`, `ATTRIBUTION.md`, `CHANGELOG.md`, and `RELEASE_NOTES.md`. It does **not** ship `VERSION`, `tests/`, `tools/`, `.github/`, or `build_report.json`.

The packager uploads `RELEASE_NOTES.md` as the release changelog instead of generating notes from Git commits. This prevents commit metadata from appearing on CurseForge and avoids publishing the full release history. Automated database and Forever Interface PRs replace this file with only their prepared release entry. CI requires that entry to match `VERSION` and rejects email addresses.

All stable releases must update `VERSION` to match the tag. Automated database and Forever Interface PRs do this, and merging either creates the tag. If both prepare the same patch concurrently, merge one and manually rerun the other updater so its fixed PR refreshes against the new `main`. For other releases, update `VERSION`, `CHANGELOG.md`, and `RELEASE_NOTES.md` in the release PR before creating the tag.

## CurseForge

CurseForge uses its [native automatic packager](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging). GitHub Actions does not upload to CurseForge.

Project configuration:

1. Set **Source Code** to the public GitHub repository.
2. Set **Automatic Packaging** to package new tagged commits, not all commits.
3. Generate a dedicated CurseForge API token for the repository webhook.
4. In GitHub repository settings, add a webhook for push events with this payload URL:

   ```text
   https://www.curseforge.com/api/projects/{projectID}/package?token={token}
   ```

5. Keep the webhook defaults and verify its initial delivery succeeds.

The payload URL contains the API token. Never commit it, add it as an Actions secret, paste it into an issue, or include it in logs. Revoke and replace the token if the URL is exposed.

The native packager reads `.pkgmeta` and replaces `@project-version@` with the pushed tag. A normal tag such as `v0.1.22` is a Release; tags containing `beta` or `alpha` receive the corresponding CurseForge status. Do not add `X-Curse-Project-ID` solely for native packaging.

License on CurseForge: **GPLv3**. Credit All The Things for the quest data. See [ATTRIBUTION.md](../ATTRIBUTION.md).

## Pin textures

Normal map pins call `SetAtlas("QuestNormal", false)` at a fixed 24px size. Special pins use the same atlas with desaturation and a vertex tint: red-orange for dungeon/raid, `RAID_CLASS_COLORS` / `C_ClassColor` for class-only stacks, copper `(1.00, 0.65, 0.20)` for profession-only stacks, and blue for repeatable-only stacks. Rogue class pins also draw a near-black tinted `QuestNormal` on the ARTWORK fill layer, offset 1px down-right, so class yellow does not look like a normal start. Priority is instance/attunement, class, profession, repeatable, then normal; mixed stacks stay yellow. Bundled yellow, blue, and red-orange TGAs remain as fallbacks, followed by `QuestDaily` for repeatable pins. Do not bind `Interface\GossipFrame\AvailableQuestIcon` on the map: on Forever that path can succeed with no pixels and hide working art.

## Support split

- Pin / eligibility / auto-quest bugs → this repo’s issues
- Wrong coordinates or missing Forever quests in the converted DB → [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever data, unless our converter dropped a spawn ATT has

## Waypoint providers

Blizzard Map Pins is the default. Start clicks use zone coordinates, normalized
from the database's 0–100 units, with `UiMapPoint.CreateFromCoordinates`,
`C_Map.SetUserWaypoint`, and optionally `C_SuperTrack.SetSuperTrackedUserWaypoint`.
On acceptance, `C_SuperTrack.SetSuperTrackedQuestID` hands objective and turn-in
navigation to Blizzard. TomTom receives the location returned by
`C_QuestLog.GetNextWaypoint` and updates on quest-log / POI refreshes.
Unavailable coordinates remove the old TomTom target until new data arrives.

References checked during implementation:

- [Blizzard map API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
- [Blizzard quest location API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Blizzard super-tracking API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua)
- [Adventure Guide Forever](https://github.com/cjber/adventure-guide-forever), which documents native waypoint guidance as its optional-provider fallback

The published Classic and Classic Beta API snapshots omit the retail user
waypoint functions. Check actual Forever support with `/fqp apis`; runtime
capability checks report unsupported clients/maps. TomTom signatures and options
were also verified against the locally installed Forever-compatible TomTom.
The user verified that `/console showInGameNavigation 1` enables Forever's
native floating navigation marker. The Navigation checkbox reads and writes
that shared CVar directly, so it reflects changes from the console or other
addons and does not overwrite the player's choice on login. Verify presentation
in game.

In-game verification: choose Blizzard Map Pins with TomTom disabled, click a
start on both its zone map and a parent map, accept it, progress its objectives,
and turn it in. Repeat with TomTom selected. Check changing provider, manually
replacing a Blizzard pin, abandoning a selected quest, and reloading the saved
provider setting. Stacked start markers select their first quest.
