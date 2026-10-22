## 0.3.0 - 2026-10-21

- Replace the All The Things Forever datasource with QuestieDB Forever and Questie policy corrections. No ATT fallback remains.
- Ship 5232 quests with 7260 coordinate pins, including item- and object-started quests, open-world dungeon entrances, and coordless records kept for tooltips and prerequisites.
- Group nearby spawn points into up to six pins per quest. Hovering shows the spawn count and every location on the map. The **Show spawn clusters** option switches to one pin per quest.
- Add NPC tooltips for ready turn-ins alongside available accepts, with `!` and `?` markers and duplicate suppression.
- Classify dungeon and raid quests from `C_QuestLog.GetQuestTagInfo`, generated Questie tag corrections, and the static database hint, in that order.
- Map Questie repeatable and monthly flags, split prerequisite AND/OR lists, and preserve holiday starts as yearly without inventing event IDs.
- Keep 4098 of 4152 previous ATT start pins. The 54 known gaps are 27 missing starters, 12 quests absent from QuestieDB, 8 item starts without a drop source, 1 item drop without a spawn, and 6 starters without a spawn or waypoint.
- Replace the ATT converter with `internal/questiedb`, `internal/questiepolicy`, and `internal/questdb`; add deterministic generation, provenance, parity reporting, CI drift checks, and the QuestieDB update workflow.
- Update attribution for QuestieDB and Questie (GPL-3.0) and the addon license to GPL-3.0-or-later.
