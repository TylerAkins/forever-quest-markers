# Development

Forever Quest Pins is a small World of Warcraft Forever addon (Interface **16001**). Players should read [README.md](../README.md). This file is for maintaining the repo, database, and releases.

## Layout

| Path | Role |
|------|------|
| `ForeverQuestPins.toc` | Load order, Interface 16001, packager metadata |
| `Config.lua` | Saved variables, slash commands, settings panel |
| `Eligibility.lua` | Completion, log, source quests, NPC-offered quests |
| `MapPins.lua` | World-map start pins |
| `AutoQuests.lua` | Optional auto-accept / auto-turn-in |
| `Core.lua` | Events and refresh |
| `Database/ForeverQuests.lua` | Generated start records (do not edit by hand) |
| `Database/Metadata.lua` | Pinned ATT commit SHA |
| `Database/build_report.json` | Converter stats (not shipped in the player zip) |
| `Media/QuestAvailable.tga` | Fallback bang if `QuestNormal` fails |
| `tools/build_quest_db.py` | ATT Forever → `Database/` |
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

- Daily at 06:00 UTC, and on manual **Run workflow**
- Regenerates `Database/`, runs tests, opens a PR when the converted data changed
- Needs **Settings → Actions → General → Workflow permissions → Allow GitHub Actions to create and approve pull requests**

It never pushes generated data straight to `main`.

## Tests

```bash
python3 tests/test_build_quest_db.py
python3 tests/test_validate_generated.py
python3 tests/test_addon_lua.py
```

CI (`validate`) also regenerates the database at the pinned ATT SHA and fails on drift, then dry-runs the packager.

## Releases

| Channel | How | Zip |
|---------|-----|-----|
| Numbered | Push an annotated `v*` tag (`v0.1.8`) | `ForeverQuestPins-v0.1.8-forever.zip` |
| Rolling beta | Merge to `main` | `ForeverQuestPins-latest-forever.zip` on the moving `latest` pre-release tag |

Do not point players at GitHub’s “Source code” archives. The packager zip is the installable addon.

`.pkgmeta` ships addon Lua, `Database/*.lua`, `Media/`, `LICENSE`, `README.md`, `ATTRIBUTION.md`, and `CHANGELOG.md`. It does **not** ship `tests/`, `tools/`, `.github/`, or `build_report.json`.

## CurseForge

1. Create the project as a **WoW Forever** / custom addon if that flavor exists; otherwise note Interface **16001** in the listing.
2. Mark the first upload **Beta**.
3. Paste [README.md](../README.md) as the description (Markdown).
4. Upload the packager zip from GitHub Releases (`ForeverQuestPins-*-forever.zip`), not a source archive.
5. Add a screenshot of yellow `!` pins on the Forever world map; that is the listing thumbnail players look for.
6. After CurseForge assigns a project id, add `## X-Curse-Project-ID: <id>` to `ForeverQuestPins.toc`.

License on CurseForge: **GPLv3**. Credit All The Things (MIT) for converted data.

## Pin textures

Map pins call `SetAtlas("QuestNormal", false)` at a fixed 24px size. If that errors, they use `Media/QuestAvailable.tga`. Do not bind `Interface\GossipFrame\AvailableQuestIcon` on the map: on Forever that path can succeed with no pixels and hide a working atlas.

## Support split

- Pin / eligibility / auto-quest bugs → this repo’s issues
- Wrong coordinates or missing Forever quests in the converted DB → [All The Things](https://github.com/ATTWoWAddon/AllTheThings) unless our converter dropped a row that ATT has
