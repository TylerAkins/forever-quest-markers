# Forever Quest Pins

Yellow **!** markers on Blizzard’s native world map for quests you can currently accept but have not already taken.

World of Warcraft Forever already includes Blizzard’s modern quest tracker and objective-map pins for quests in your log. This addon does **not** replace that. It only supplements the map with start locations for unaccepted quests.

**Repository:** [github.com/TylerAkins/forever-quest-markers](https://github.com/TylerAkins/forever-quest-markers)

## Install

Download an **addon zip** from [Releases](https://github.com/TylerAkins/forever-quest-markers/releases) (not GitHub’s “Source code” archive). Extract so the folder is named exactly `ForeverQuestPins`, then copy it into your Forever `Interface\AddOns\` directory.

- **Stable:** the newest `v*` release (for example `ForeverQuestPins-v0.1.4-forever.zip`)
- **Current `main`:** the [Latest](https://github.com/TylerAkins/forever-quest-markers/releases/tag/latest) pre-release (`ForeverQuestPins-latest-forever.zip`), rebuilt on every merge to `main`

Restart the game (or `/reload`) and enable the addon at character select if needed.

## What it shows

- Yellow quest-start bangs on `WorldMapFrame`
- Only quests that appear acceptable for this character
- Hidden when the quest is already completed, already in the log, blocked by ATT source quests, or clearly the wrong faction / race / class / level

It does **not** track objectives, turn-ins, or quest-log progress. Use the built-in Forever tracker for that. Optional auto-accept and auto-turn-in can be enabled in the addon options or with `/fqp accept` and `/fqp turnin`.

## Data source

Quest coordinates and restrictions are converted from [All The Things](https://github.com/ATTWoWAddon/AllTheThings)’s Forever database (`.contrib/.db/forever/`). ATT is **not** required at runtime and is not bundled.

Generated files:

- `Database/ForeverQuests.lua` — compact quest-start records
- `Database/Metadata.lua` — ATT commit SHA and quest counts
- `Database/build_report.json` — machine-readable conversion summary (not shipped in the player zip)

Pins use Blizzard’s gossip yellow ! (`Interface\GossipFrame\AvailableQuestIcon`) because Forever’s `QuestNormal` atlas can bind without drawing. If that file is missing they fall back to `QuestNormal`, then to `Media/QuestAvailable.tga`. The addon does not depend on Questie, ATT, TomTom, or HereBeDragons.

## Commands

| Command | Action |
|---------|--------|
| `/fqp` | Help |
| `/fqp on` / `/fqp off` | Enable or disable pins |
| `/fqp trivial` | Toggle low-level/trivial pins (only hides them when `GetQuestGreenRange` exists) |
| `/fqp seasonal` | Toggle holiday/seasonal pins (Lunar Festival elders, Darkmoon Faire, etc.; off by default) |
| `/fqp accept` | Toggle auto-accept quests when talking to NPCs |
| `/fqp turnin` | Toggle auto-turn in completed quests |
| `/fqp debug` | Toggle debug tooltips (quest/NPC IDs and pin diagnostics); also a checkbox in the addon options |
| `/fqp refresh` | Rebuild pins on the current map |
| `/fqp stats` | Print ATT SHA, quest count, and painted pin count |
| `/fqp apis` | Print which Forever map/quest APIs this client exposes |
| `/fqp why <id>` | Print why a quest is pinned or hidden (completion, log, source quests) |
| `/fqp available` | List quests that should pin on the currently viewed map |

## Automated database updates

A scheduled GitHub Action clones ATT, regenerates `Database/`, runs tests, and opens a pull request when the converted data changes. It does not push directly to `main`.

You can also run it manually from the Actions tab (`Update ATT database`).

## Regenerating the database locally

```bash
python3 tools/build_quest_db.py --att /path/to/AllTheThings
```

If `--att` is omitted, the script clones ATT into `.cache/AllTheThings`.

```bash
python3 tests/test_build_quest_db.py
python3 tests/test_validate_generated.py
python3 tests/test_addon_lua.py
```

## Beta limitations

Forever’s ATT tree is still being filled in. Zone files that have not yet been migrated out of `zzOLD` are used as a **fallback** for quest IDs missing from the live Forever tree. Cata-and-later `ADDED_*` entries are skipped; classic quests marked `REMOVED_4_0_3` are kept. Daily conversion PRs pick up live ATT updates automatically.

Other current limits:

- Item-started quests with no map coordinate are omitted
- Holiday / battleground quests are hidden unless `/fqp seasonal` is enabled or the client reports the event as active
- Continent-map projection needs `C_Map.GetMapRectOnMap`; without it, pins only show on the quest’s own UiMapID
- Wandering quest givers use ATT’s static coordinate (and a second pin at the other end of known patrols, such as Morin Cloudstalker) until the NPC is visible and near that pin, then the nearest bang follows them
- Unknown Forever-only race IDs (for example Skyborne) are stored but not used to hide pins
- Reputation gates from ATT are parsed where present but not yet used to hide pins

## Credits & license

Addon code is **GPLv3** — see [LICENSE](LICENSE). Quest data is derived from All The Things (MIT). This project does not claim ownership of ATT data. See [ATTRIBUTION.md](ATTRIBUTION.md).
