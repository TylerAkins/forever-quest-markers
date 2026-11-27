## 1.2.0 - 2026-11-27

- Add a draggable minimap button. Left-click opens Quest Finder; right-click opens addon settings. Hide it in **Interface** settings. Quest Finder is also draggable by its header and remembers its position; `/fqp finderreset` returns it to the screen center.
- Add **Quest Finder** with breadcrumbs for the current or selected zone, quests available in a zone, and dungeon quests with their start zone and full required pre-quest chains. Breadcrumbs are matched by the zone they lead to, so a capital-city breadcrumb for the Plaguelands appears under the Plaguelands. Zone selectors use Leatrix Maps' zone levels and dungeon selectors use the journal's dungeon levels. The **All dungeons** view shows acceptable quests with an available-versus-total count; clicking a dungeon opens its full list, including quests you cannot pick up yet, with status labels. Availability uses the player's level and quest prerequisites, not the map pin level filters. Opposite-faction, wrong-race, and wrong-class quests and chain steps stay hidden. Quests that start inside a dungeon are tagged **In dungeon** and do not offer a map pin. Filter by dungeon and select a dungeon header to expand its chain. Click a row to set a Blizzard map pin from any zone. The breadcrumb and available-quest lists use the same filters as the map pins.
- Mark dungeon chain pre-quests as dungeon quests from ForeverDungeonJournal data, so outdoor steps that unlock a dungeon use the dungeon pin color and filter.
- Add a keybind that uses the special item on the tracked quest.
- Turn Questie's plain-text chat links into the game's own yellow clickable quest links. Existing links and clients with Questie loaded are left alone. Toggle it with `/fqp chatlinks`.
- The beta tracker's **All quests** view now includes every quest in the log, not only Blizzard's watched quests. **Tracked only** keeps the old view.
- Move pin filters back into Blizzard's world map tracking menu.
- Give book-only pins their own size slider, defaulting to 75% of a quest pin.
- Run QuestieDB updates Wednesday, Friday, Saturday, and Sunday.
