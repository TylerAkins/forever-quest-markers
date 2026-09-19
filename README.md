# Forever Quest Pins

**Beta** for World of Warcraft Forever (Interface 16001).

Yellow **!** start markers on Blizzard’s native world map for quests you can accept but have not already taken.

Forever already has a modern quest tracker and objective pins for quests **in your log**. This addon does not replace that. It only adds start locations for **unaccepted** quests.

## Requirements

- World of Warcraft **Forever** only (not Retail, Classic Era, or Cataclysm Classic)
- Folder name must be exactly `ForeverQuestPins`
- No other addons required (not All The Things, Questie, TomTom, or HereBeDragons)

## Features

- Yellow `!` pins on `WorldMapFrame` for acceptable, unaccepted quest starts
- Tooltips with `[level] quest name` (same suggested level as the Forever tracker) and NPC names (IDs only if debug is on)
- Pins stay on the map art in windowed and fullscreen layouts
- Overlapping starts on the same spot stack into one pin
- Optional auto-accept and auto-turn-in when talking to NPCs (off by default; hold **Shift** to skip once)
- Seasonal / holiday starts (Lunar Festival elders, Darkmoon Faire, …) off by default
- AQ opening **war effort** commodity pins in Orgrimmar / Ironforge on by default (turn off in settings if the stack is too noisy)

Quest coordinates and restrictions come from [All The Things](https://github.com/ATTWoWAddon/AllTheThings)’s Forever database. ATT is **not** bundled and is **not** required at runtime.

## Install

**CurseForge:** install *Forever Quest Pins* and set the game flavor to Forever when the client offers it.

**Zip:** download an addon zip from [GitHub Releases](https://github.com/TylerAkins/forever-quest-markers/releases) — not the “Source code” archive.

- Named builds: `ForeverQuestPins-v0.1.8-forever.zip` (and later `v*` tags)
- Current `main`: [Latest](https://github.com/TylerAkins/forever-quest-markers/releases/tag/latest) pre-release (`ForeverQuestPins-latest-forever.zip`)

Extract so the folder is `ForeverQuestPins`, copy it into `Interface\AddOns\`, then restart the game or `/reload`. Enable the addon at character select if needed.

## Settings

Escape → Options → AddOns → **Forever Quest Pins**, or use the slash commands below. Choices are saved across `/reload` and logout. New installs do not need to touch SavedVariables files.

| Option | Default |
|--------|---------|
| Show quest-start pins | On |
| Show trivial / low-level pins | On (only hides them if the client has `GetQuestGreenRange`) |
| Show seasonal / holiday pins | Off |
| Show AQ war effort pins | On (capital turn-ins: Senior Sergeants, signets, \"Needs Your Help\") |
| Auto-accept quests | Off |
| Auto-turn in quests | Off (will not pick when there are multiple rewards) |
| Debug tooltips | Off |

## Commands

| Command | Action |
|---------|--------|
| `/fqp` | Help |
| `/fqp on` / `/fqp off` | Enable or disable pins |
| `/fqp trivial` | Toggle low-level / trivial pins |
| `/fqp seasonal` | Toggle holiday / seasonal pins |
| `/fqp wareffort` | Toggle AQ war effort pins in capitals |
| `/fqp accept` | Toggle auto-accept |
| `/fqp turnin` | Toggle auto-turn-in |
| `/fqp debug` | Toggle debug tooltips |
| `/fqp refresh` | Rebuild pins on the current map |
| `/fqp stats` | Print ATT SHA, quest count, and painted pin count |
| `/fqp why <id>` | Why a quest is pinned or hidden |
| `/fqp available` | Starts that should pin on the open map |
| `/fqp wipe` | Reset options (recovery; see Support) |
| `/fqp apis` | Which Forever map/quest APIs this client exposes |

## Beta limitations

Forever’s quest data is still moving. Missing or extra pins are often an upstream ATT gap, not a pin bug.

- **Not a tracker.** No objectives, no turn-in map pins, no quest-log UI
- **Forever-only quests** that ATT does not list yet will not pin until ATT (or a gossip offer we already saw this session) knows them
- **Item-started** quests with no map coordinate are omitted
- **Holiday** starts stay hidden unless seasonal pins are on or the client reports the event as active
- **Continent** view needs `C_Map.GetMapRectOnMap`; without it, pins only appear on the quest’s own zone map
- **Patrols** (for example Morin Cloudstalker) use ATT’s static points, plus a second pin at a known path end, until the NPC is visible and near those points
- Reputation gates from ATT are stored but not used to hide pins yet
- Pin art is Blizzard’s `QuestNormal` atlas, with `Media/QuestAvailable.tga` if that call errors

## Support

- Bugs: [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues)
- Please include `/fqp stats` (and `/fqp why <id>` if a specific quest is wrong)
- Quest **database** mistakes belong on [All The Things](https://github.com/ATTWoWAddon/AllTheThings), not here
- If you ran a **0.1.10–0.1.16** beta and options still reset after `/reload`, close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under `WTF\Account\...\SavedVariables\` and `WTF\Account\...\<realm>\<char>\SavedVariables\`. New users can ignore this.

## License

Addon code is **GPLv3** ([LICENSE](LICENSE)). Converted quest data remains **MIT** from All The Things. See [ATTRIBUTION.md](ATTRIBUTION.md).

Maintainers: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
