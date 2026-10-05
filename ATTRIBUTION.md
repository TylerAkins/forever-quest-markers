# Attribution

## QuestieDB

Quest coordinates, quest-giver IDs, turn-in NPCs, and eligibility fields in `Database/` are converted from the Forever export in [wow-database](https://github.com/TylerAkins/wow-database). That export is built from [Questie/QuestieDB](https://github.com/Questie/QuestieDB).

- Upstream data: https://github.com/Questie/QuestieDB
- Published export: https://github.com/TylerAkins/wow-database
- `Database/Metadata.lua` records the QuestieDB commit and the wow-database commit used for that conversion
- This repository does not bundle Questie or QuestieDB, and neither is required at runtime
- This repository does not claim ownership of QuestieDB data

QuestieDB and Questie remain under their own licenses.

## World of Warcraft

World of Warcraft, its quests, and related names are trademarks and copyrights of Blizzard Entertainment, Inc.

## Addon code

Forever Quest Pins is original GPLv3 code: a native-map overlay and a compiler that turns the published export into addon Lua. Tracker UI and HereBeDragons usage from other addons were not copied.

Map pins use Blizzard’s `QuestNormal` atlas. The generated yellow, blue, and red-orange textures under `Media/` are original fallback art used only when the preferred atlas rendering fails.

## License

- Addon source: **GPLv3** ([LICENSE](LICENSE))
- Quest records: QuestieDB, via the wow-database export
