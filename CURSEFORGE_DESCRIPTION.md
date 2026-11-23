# CurseForge description (paste into project page)

Paste everything below this line into the CurseForge long description.

---

# Forever Quest Pins

Forever's map only shows quests you have already accepted. This addon shows the ones you have not.

It adds quest-start markers to the world map, quest icons to NPC nameplates, and quest lines to NPC tooltips. Markers use the same colors as the quest types: yellow for normal, blue for repeatable, red-orange for dungeon and raid, class color for class quests, and copper for profession quests.

## What it does

- Shows quest-start markers for unaccepted quests on the world map.
- Shows nameplate icons for NPCs that offer a quest, accept a turn-in, or are an active quest objective. The icon goes away when the objective is done.
- Lists quests you can accept and quests ready to turn in on NPC tooltips.
- Tracks a quest start with Blizzard map pins or TomTom when you click a marker.
- Groups nearby spawn points into one marker. Hover to see the count and every location.
- Hides a marker for the current character with Shift-click. Restore it in settings or with `/fqp unhide`.
- Filters by level range, repeatable quests, seasonal events, and AQ war effort.
- Auto-accepts and auto-turns in quests when you talk to NPCs. Hold Shift to skip once.

## Install

Install from CurseForge and choose the Forever game flavor. If you install by hand, the folder must be `ForeverQuestPins` inside `Interface\AddOns`.

## Commands

`/fqp` shows the full command list. The ones you will use most:

| Command | Action |
|---------|--------|
| `/fqp on` / `/fqp off` | Toggle quest-start markers |
| `/fqp nameplates` | Toggle nameplate icons |
| `/fqp npctooltip` | Toggle NPC quest lines |
| `/fqp spawns` | Toggle grouped spawn markers |
| `/fqp seasonal` | Toggle holiday markers |
| `/fqp wareffort` | Toggle AQ war effort markers |
| `/fqp hidden` | List hidden markers |
| `/fqp unhide <id\|all>` | Restore hidden markers |
| `/fqp why <id>` | Explain why a quest is shown or hidden |

## Notes

- Forever only (Interface 16001). Not for Retail, Classic Era, or Cataclysm Classic.
- This is not a quest tracker. Blizzard's tracker, objectives, and turn-in map pins are left as they are.
- Quest data comes from QuestieDB. Missing markers are usually missing data, not a setting.
- Reputation requirements are not in the addon database, so they do not hide markers.
- Auto-accept and auto-turn-in are off by default.

## Support

Report bugs on [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues). Include `/fqp stats`. For nameplate icon issues, include `/fqp nameplatedebug`.

## Credits

Quest data from [QuestieDB](https://github.com/Questie/QuestieDB) and [Questie](https://github.com/Questie/Questie). Addon code is GPL-3.0-or-later. See `ATTRIBUTION.md` in the repository.

World of Warcraft, its quests, and related names are trademarks and copyrights of Blizzard Entertainment, Inc. This addon is not affiliated with Blizzard.
