# Development

Forever Quest Pins is a small World of Warcraft Forever addon (Interface **16001**). Players should read [README.md](../README.md). This file is for maintaining the repo, database, and releases.

## Layout

| Path | Role |
|------|------|
| `ForeverQuestPins.toc` | Load order, Interface 16001, packager metadata |
| `Config.lua` | Saved variables, slash commands, settings panel |
| `Eligibility.lua` | Completion, log, source quests, NPC-offered quests |
| `NPCTooltips.lua` | Available quest rows on NPC tooltips and the one-shot hover-data probe |
| `MapPins.lua` | World-map start pins |
| `AutoQuests.lua` | Optional auto-accept / auto-turn-in |
| `Core.lua` | Events and refresh |
| `Database/ForeverQuests.lua` | Generated start records (do not edit by hand) |
| `Database/Metadata.lua` | Generated quest-database provenance |
| `Database/build_report.json` | Converter stats (not shipped in the player zip) |
| `VERSION` | Current stable release used by automated version checks |
| `RELEASE_NOTES.md` | Curated notes for only the current release |
| `Media/QuestAvailable.tga` | Yellow fallback bang if `QuestNormal` fails |
| `Media/QuestRepeatable.tga` | Blue fallback if the tinted `QuestNormal` atlas cannot be used |
| `Media/QuestAttunement.tga` | Red-orange fallback for ATT-derived attunement chains |
| `tools/emit_wowhead_db.py` | Wowhead `data/forever-quests/` → shipped `Database/` |
| `tools/build_quest_db.py` | ATT Forever → `Database/` (kept, not what CI ships) |
| `tools/fetch_quest_pages.py` | Forever list pages → `data/forever-quests/` |
| `data/forever-quests/` | Quest index + details (see `docs/quest-database.md`) |
| `tools/att_release.py` | Prepares ATT releases and validates automated patch releases |
| `tools/update_forever_interface.py` | Blizzard build feed → TOC compatibility release |
| `tools/generate_quest_icon.py` | Regenerates the fallback TGA |
| `.pkgmeta` | [BigWigs packager](https://github.com/BigWigsMods/packager) rules |

## Database

Coordinates and restrictions come from ATT `.contrib/.db/forever/`. Runtime ATT is not required.

```bash
python3 tools/build_quest_db.py --att /path/to/AllTheThings
```

If `--att` is omitted, the script clones ATT into `.cache/AllTheThings`.

Live Forever zone files are preferred. `zzOLD` is a fallback for quest IDs still missing from the live tree. Cata-and-later `ADDED_*` rows are skipped; classic `REMOVED_4_0_3` rows are kept.

### Automated updates

Workflow **Update ATT database** (`.github/workflows/update-att-db.yml`):

- Manual **Run workflow** only. It is not scheduled, because the shipped database is the Wowhead export
- Opens a versioned PR only when the shipped quest records changed; ATT SHA-only updates are ignored
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
python3 tests/test_tooltips_runtime.py
python3 tests/test_compile_addon.py
python3 tests/test_att_release.py
python3 tests/test_update_forever_interface.py
```

CI (`validate`) regenerates `Database/` with `tools/emit_wowhead_db.py` and fails on drift, then dry-runs the packager. `tools/build_quest_db.py` still converts All The Things, and `.github/workflows/update-att-db.yml` can be run by hand, but that workflow is not on a schedule.

### Forever hover-data probe

Run the intentionally undocumented `/fqp hoverprobe`, then move the cursor onto an NPC. The next unit tooltip prints its NPC ID, the result of `C_QuestLog.UnitIsRelatedToActiveQuest`, and every exposed structured tooltip line and nested argument. The probe is one-shot and read-only. It does not add active or turn-in rows.

Forever Beta testing found native quest-title/objective lines on objective-related units, but ordinary unit lines and no quest identifier on both incomplete and completed finisher NPCs. `UnitIsRelatedToActiveQuest` also returned false for the incomplete finisher. Keep finisher rows disabled unless a later client build exposes a quest ID. Native objective blocks should not be duplicated.

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
| Stable | Push an annotated `v*` tag, or merge a prepared ATT database/interface PR | Numbered GitHub Release and CurseForge package |
| Preview | Merge to `main` or manually run the Release workflow | Commit-specific GitHub Actions artifact |

Only stable tags are distributed to players. Preview builds are for testing and do not push or move a Git tag. Do not point players at GitHub's “Source code” archives; the packager zip is the installable addon.

`.pkgmeta` ships addon Lua, `Database/*.lua`, `Media/`, `LICENSE`, `README.md`, `ATTRIBUTION.md`, `CHANGELOG.md`, and `RELEASE_NOTES.md`. It does **not** ship `VERSION`, `tests/`, `tools/`, `.github/`, or `build_report.json`.

The packager uploads `RELEASE_NOTES.md` as the release changelog instead of generating notes from Git commits. This prevents commit metadata from appearing on CurseForge and avoids publishing the full release history. Automated ATT and Forever Interface PRs replace this file with only their prepared release entry. CI requires that entry to match `VERSION` and rejects email addresses.

All stable releases must update `VERSION` to match the tag. Automated ATT and Forever Interface PRs do this, and merging either creates the tag. If both prepare the same patch concurrently, merge one and manually rerun the other updater so its fixed PR refreshes against the new `main`. For other releases, update `VERSION`, `CHANGELOG.md`, and `RELEASE_NOTES.md` in the release PR before creating the tag.

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

License on CurseForge: **GPLv3**. Credit All The Things (MIT) for converted data.

## Pin textures

Normal map pins call `SetAtlas("QuestNormal", false)` at a fixed 24px size. Repeatable and attunement pins use the same atlas with desaturation and blue or red-orange vertex tints so their silhouettes match exactly. Bundled yellow, blue, and red-orange TGAs remain as fallbacks, followed by `QuestDaily` for repeatable pins. Do not bind `Interface\GossipFrame\AvailableQuestIcon` on the map: on Forever that path can succeed with no pixels and hide working art.

## Support split

- Pin / eligibility / auto-quest bugs → this repo’s issues
- Wrong coordinates or missing Forever quests in the converted DB → [All The Things](https://github.com/ATTWoWAddon/AllTheThings) unless our converter dropped a row that ATT has
