# Forever Quest Pins

**Beta** for World of Warcraft Forever (Interface 16001).

Yellow **!** start markers for normal quests, blue **!** for repeatable, red-orange **!** for dungeon and raid, class-colored **!** for class quests, and copper **!** for profession quests on Blizzard’s native world map.

Forever already has a modern quest tracker and objective pins for quests **in your log**. This addon does not replace that. It adds start locations for **unaccepted** quests.

## Requirements

- World of Warcraft **Forever** only (not Retail, Classic Era, or Cataclysm Classic)
- Folder name must be exactly `ForeverQuestPins`
- No other addons required (not TomTom or HereBeDragons)

TomTom is an optional waypoint provider. The default is **Blizzard Map Pins**.

## Features

- Yellow `!` pins for normal quest starts, blue `!` for repeatable, red-orange `!` for dungeon and raid, class-colored `!` for class quests, and copper `!` for profession quests
- Map pin tooltips with `[level] quest name` (same suggested level as the Forever tracker) and NPC names (IDs only if debug is on)
- NPC mouseover tooltips listing quests you can accept (on by default)
- Pins stay on the map art in windowed and fullscreen layouts
- Overlapping starts on the same spot stack into one pin
- Optional auto-accept and auto-turn-in when talking to NPCs (off by default; hold **Shift** to skip once)
- Seasonal / holiday starts (Lunar Festival elders, Darkmoon Faire, …) off by default
- AQ opening **war effort** commodity pins in Orgrimmar / Ironforge on by default (turn off in settings if the stack is too noisy)

Quest coordinates and restrictions come from [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever data, converted by `tools/build_quest_db.py`. Quests without a usable spawn in ATT stay in the database for tooltips and prerequisites but may not get a map pin.

## Install

**CurseForge:** install [Forever Quest Pins](https://www.curseforge.com/wow/addons/forever-quest-pins) and select the Forever game flavor when the client offers it.

**GitHub:** download a `ForeverQuestPins-v*-forever.zip` file from [GitHub Releases](https://github.com/TylerAkins/forever-quest-markers/releases), not GitHub's automatically generated “Source code” archives.

Extract the downloaded zip so the folder is `ForeverQuestPins`, copy it into `Interface\AddOns\`, then restart the game or `/reload`. Enable the addon at character select if needed.

## Settings

The optional **Limit auto-accept quest level** checkbox defaults off. Its **Auto Accept quest Range** slider runs from -5 to +5 and defaults to +1. This is a maximum recommended quest level relative to your current level: at level 15, +1 allows level 16 and below. Auto-accept must also be enabled. Unknown quest levels and shared-quest confirmations are left for manual acceptance while the limit is enabled. The limit does not hide map pins or affect turn-ins.

Escape → Options → AddOns → **Forever Quest Pins**, use the world map's **Show** dropdown for quest-start pins, or use the slash commands below. The addon synchronizes choices across account-wide and per-character SavedVariables, plus a small CVar mirror. Revision numbers let the newest copy win without stale defaults overwriting saved choices.

| Option | Default |
|--------|---------|
| Show quest-start pins | On |
| Show trivial / low-level pins | Off (hides pins for quests 9+ levels below your character) |
| Show repeatable quest pins | On |
| Show seasonal / holiday pins | Off |
| Show AQ war effort pins | Off (capital turn-ins: Senior Sergeants, signets, \"Needs Your Help\") |
| Show in-world destination marker | Uses Blizzard’s current shared navigation setting |
| Waypoint provider | Blizzard Map Pins (TomTom optional) |
| Icon Scale | 100% (adjustable from 50% to 150%) |
| Auto-accept quests | Off |
| Auto-turn in quests | Off (will not pick when there are multiple rewards) |
| Show quests on NPC tooltips | On (available accepts only) |
| Debug tooltips | Off |

Click a quest-start marker to set a waypoint at its zone coordinates. For stacked markers, the first quest is selected. When that quest is accepted, Blizzard tracking takes over its objectives and turn-in. With TomTom selected, the waypoint follows `C_QuestLog.GetNextWaypoint` as quest progress changes. If Blizzard has no location yet, no objective coordinate is invented. Selecting TomTom without it loaded displays a message.

Blizzard supports one user waypoint at a time. Clicking a start replaces that waypoint. Manually changing the Blizzard pin or tracking another quest stops the pending handoff. The addon only clears a matching pin that it created. Forever builds may differ in API support; an unavailable API is reported in chat. Enable **Show in-world destination marker** under Navigation to display Blizzard’s floating marker and distance. This controls the shared `showInGameNavigation` game setting and reflects its current value, including changes made by other addons.

## Commands

| Command | Action |
|---------|--------|
| `/fqp` | Help |
| `/fqp on` / `/fqp off` | Enable or disable pins |
| `/fqp trivial` | Toggle low-level / trivial pins |
| `/fqp repeatable` | Toggle repeatable quest pins |
| `/fqp seasonal` | Toggle holiday / seasonal pins |
| `/fqp wareffort` | Toggle AQ war effort pins in capitals |
| `/fqp accept` | Toggle auto-accept |
| `/fqp turnin` | Toggle auto-turn-in |
| `/fqp npctooltip` | Toggle NPC quest accept tooltips |
| `/fqp debug` | Toggle debug tooltips |
| `/fqp track <id>` | Track a quest start, or Blizzard-provided objective / turn-in |
| `/fqp clear` | Clear the addon waypoint or its tracked quest |
| `/fqp refresh` | Rebuild pins on the current map |
| `/fqp stats` | Print the database commit, quest count, and painted pin count |
| `/fqp settings` | Print saved and effective option values for debugging |
| `/fqp why <id>` | Why a quest is pinned or hidden |
| `/fqp available` | Starts that should pin on the open map |
| `/fqp wipe` | Reset options (recovery; see Support) |
| `/fqp apis` | Which Forever map/quest APIs this client exposes |

## Beta limitations

Forever’s quest data is still moving. Missing pins are often a gap in the published export: most quest givers have no coordinates, so those quests cannot be pinned.

- **Saved settings:** Forever Beta 1.60.1.69913 can write account and character SavedVariables without restoring them. Revisioned copies alone cannot fix this client bug. The optional local repair below has been confirmed on a native macOS Forever installation.
- **Not a tracker.** No objectives, no turn-in map pins, no quest-log UI
- **Quest eligibility depends on source data.** Forever exposes completion, quest-log membership, and quests offered by the NPC currently being visited, but no API that answers whether an arbitrary quest ID can be accepted. Missing prerequisites can therefore produce early pins until the database is corrected. NPC tooltips list available accepts only (including session gossip offers); they do not list in-log turn-ins.
- Missing quest starters are learned for the current session when an NPC offers them through gossip or quest details. Unavailable titles appear as `Quest <ID> (title unavailable)` until loaded.
- **Forever-only quests** missing from the export will not pin until the export (or a gossip offer we already saw this session) knows them
- **Item-started** and **object-started** quests stay in the database. They get a start pin only when the export has a usable spawn (drop NPC, chest, or world object). Pure item starts with no spawn stay tooltip-only.
- **Holiday** starts stay hidden unless seasonal pins are on
- **Continent** view needs `C_Map.GetMapRectOnMap`; without it, pins only appear on the quest’s own zone map
- **Patrols** (for example Morin Cloudstalker) use the exported static points, plus a second pin at a known path end, until the NPC is visible and near those points
- Reputation requirements are not copied into the addon database, so they do not hide pins
- Most start pins share Blizzard’s `QuestNormal` shape; special pins tint it (blue, red-orange, class color, or copper), with bundled yellow/blue/red-orange fallbacks. Rogue class pins add a dark bang shadow so they stay distinct from normal yellow. Mixed stacks stay yellow.

## Support

For settings that reset despite being saved to disk, close WoW completely and run `tools/repair_local_settings.py` from the GitHub source checkout with `--addon` pointing to your installed `ForeverQuestPins` folder and `--saved` pointing to that account's `SavedVariables/ForeverQuestPins.lua`. It previews by default; add `--apply` to create a TOC backup and link the live account settings into the addon loader. It never edits the saved settings. Reapply after addon updates replace the TOC. This is account-specific: do not share the patched addon across accounts. To undo, restore `ForeverQuestPins.toc.before-settings-repair` and remove only the `LocalSavedVariables` link, leaving its target directory intact. The repair tool is available in the source repository, not the CurseForge addon package.

- Bugs: [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues)
- Please include `/fqp stats` (and `/fqp why <id>` if a specific quest is wrong)
- Quest **database** mistakes usually belong in [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever data, or in this repo’s ATT converter if ATT has the quest but we dropped a spawn
- If you ran a **0.1.10–0.1.16** beta and options still reset after `/reload`, close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under `WTF\Account\...\SavedVariables\` and `WTF\Account\...\<realm>\<char>\SavedVariables\`. New users can ignore this.

## License

Addon code is **GPLv3** ([LICENSE](LICENSE)). Quest records come from [All The Things](https://github.com/ATTWoWAddon/AllTheThings). See [ATTRIBUTION.md](ATTRIBUTION.md).

Maintainers: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
