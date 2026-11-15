# CurseForge description (paste into project page)

Paste everything below this line into the CurseForge long description.

---

# Forever Quest Pins

Find the quests you have not accepted yet.

Forever Quest Pins adds quest-start markers to Blizzard's world map for unaccepted quests in World of Warcraft Forever. It also adds quest icons beside NPC nameplates and quest lines to NPC tooltips, so you can see who has work for you without opening the quest log.

## What it does

- Yellow `!` markers for normal quest starts, blue `!` for repeatable quests, red-orange `!` for dungeon and raid quests, class-colored `!` for class quests, and copper `!` for profession quests.
- Nameplate icons for NPCs that offer a quest, accept a ready turn-in, or are an active quest objective. Completed objectives drop the icon.
- NPC mouseover tooltips list quests you can accept and quests ready to turn in.
- Click a marker to track the quest start. The addon uses Blizzard map pins by default, with optional TomTom support.
- Nearby spawn points for one quest group share a marker. Hover to see the spawn count and every location.
- Shift-click a marker to hide it for the current character. Restore hidden markers from settings or `/fqp unhide`.
- Adjustable low-level and high-level ranges, repeatable quests, seasonal events, and AQ war effort markers.
- Optional auto-accept and auto-turn-in when talking to NPCs. Hold Shift to skip once.

## Built for Forever

Forever already has a modern quest tracker and objective pins for quests in your log. This addon fills the gap before you accept a quest: it shows where quest starts are and who offers them.

Quest coordinates, quest-giver IDs, turn-in targets, and restrictions come from QuestieDB Forever data, with holiday and instance policy from Questie. Quests without a usable spawn stay in the database for tooltips and prerequisites but may not get a map marker. Nameplate objective icons use the client's unit tooltip, not extra database data.

## Install

Install from CurseForge and select the Forever game flavor when the client offers it. If you install manually, the folder must be named `ForeverQuestPins` inside `Interface\AddOns`.

## Settings and commands

Open **Escape > Options > AddOns > Forever Quest Pins**, use the world map's **Show** dropdown, or use `/fqp`.

| Command | Action |
|---------|--------|
| `/fqp` | Show help |
| `/fqp on` / `/fqp off` | Enable or disable quest-start pins |
| `/fqp nameplates` | Toggle quest icons on nameplates |
| `/fqp npctooltip` | Toggle quest lines on NPC tooltips |
| `/fqp spawns` | Toggle grouped spawn markers |
| `/fqp seasonal` | Toggle seasonal and holiday markers |
| `/fqp wareffort` | Toggle AQ war effort markers |
| `/fqp accept` | Toggle auto-accept |
| `/fqp turnin` | Toggle auto-turn-in |
| `/fqp hidden` | List hidden quest markers |
| `/fqp unhide <id\|all>` | Restore hidden quest markers |
| `/fqp why <id>` | Explain why a quest is shown or hidden |

## Good to know

- Forever only (Interface 16001). This is not for Retail, Classic Era, or Cataclysm Classic.
- The addon does not replace Forever's quest tracker. It does not add a quest-log UI or turn-in map pins.
- Quest data changes over time. Missing markers are often gaps in the published QuestieDB export, not a setting.
- Nameplate objective icons use the client's unit tooltip and disappear when the objective is complete.
- Reputation requirements are not in the addon database, so they do not hide markers.
- Auto-accept and auto-turn-in are off by default.
- Hidden quest markers are stored per character.

## Support

Report bugs on [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues). Include `/fqp stats`, and for nameplate icon issues include `/fqp nameplatedebug`.

## Credits

Quest data comes from [QuestieDB](https://github.com/Questie/QuestieDB) and [Questie](https://github.com/Questie/Questie). Addon code is GPL-3.0-or-later. See `ATTRIBUTION.md` in the repository.

World of Warcraft, its quests, and related names are trademarks and copyrights of Blizzard Entertainment, Inc. This addon is not affiliated with Blizzard.
