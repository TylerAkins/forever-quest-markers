# Forever Quest Pins

Quest-start pins and nameplate quest icons for World of Warcraft Forever (Interface 16001).

Yellow **!** start markers for normal quests, blue **!** for repeatable, red-orange **!** for dungeon and raid, class-colored **!** for class quests, and copper **!** for profession quests on Blizzard’s native world map.

Forever already has a modern quest tracker and objective pins for quests **in your log**. This addon does not replace that. It adds start locations for **unaccepted** quests and quest icons on NPC nameplates.

## Requirements

- World of Warcraft **Forever** only (not Retail, Classic Era, or Cataclysm Classic)
- Folder name must be exactly `ForeverQuestPins`
- No other addons required

TomTom is an optional waypoint provider. The default is **Blizzard Map Pins**.

## Features

- Yellow `!` pins for normal quest starts, blue `!` for repeatable, red-orange `!` for dungeon and raid, class-colored `!` for class quests, and copper `!` for profession quests
- Map pin tooltips with `[level] quest name` (Forever tracker level when available; Questie inline name when the client has not loaded a title) and NPC names (IDs only if debug is on)
- NPC mouseover tooltips listing quests you can accept and quests ready to turn in (on by default)
- Quest icons beside NPC nameplates for quests you can accept, turn in, or are working on (on by default)
- Nameplate icons show `!` for an acceptable quest, `?` for a ready turn-in, and a quest bullet for an active objective. Completed objectives drop the icon.
- Enhances Blizzard's quest tracker with zone groups, sort options (Blizzard order, distance, level, title), and view filters (all tracked quests, current zone only, instance quests). Right-click the **Quests** header for the same controls. Zone headers collapse and remember their state per character. On by default.
- Pins stay on the map art in windowed and fullscreen layouts
- Nearby spawn points for one quest group share one pin (up to six per quest). Hover to see the spawn count in the tooltip and every spawn location on the map. Turn off **Show spawn clusters** to show one pin per quest instead
- Overlapping starts on the same spot stack into one pin
- **Shift-click** a pin to hide it (every quest on a stacked pin) for the current character; restore with **Reset hidden quest pins** in settings or `/fqp unhide`
- Adjustable low-level range: choose how many levels below you a quest must be before its pin is hidden (default 9)
- Adjustable high-level range: choose how many levels above you quests must be before their pins are hidden (default shows all levels)
- Optional auto-accept and auto-turn-in when talking to NPCs (off by default; hold **Shift** to skip once)
- Warn when you accept a quest whose breadcrumb quest you skipped. The dialog can set a waypoint to the breadcrumb, abandon the quest you just accepted, or ignore the warning (on by default)
- Seasonal / holiday starts (such as Lunar Festival elders) off by default; when on, pins appear only while the event is live
- AQ opening **war effort** commodity pins in Orgrimmar / Ironforge off by default; when on, they appear after a war effort quest is offered or in your log, or with the always-show override

Quest coordinates, quest-giver IDs, turn-in targets, and restrictions come from [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, with holiday, event, and instance-tag policy from [Questie](https://github.com/Questie/Questie). The Go tool `go run ./cmd/fqp build-db` generates the addon database. Quests without a usable spawn stay in the database for tooltips and prerequisites but may not get a map pin. Nameplate objective icons use the client’s unit tooltip, not extra database data.

## Install

**CurseForge:** install [Forever Quest Pins](https://www.curseforge.com/wow/addons/forever-quest-pins) and select the Forever game flavor when the client offers it.

**GitHub:** download a `ForeverQuestPins-v*-forever.zip` file from [GitHub Releases](https://github.com/TylerAkins/forever-quest-markers/releases), not GitHub's automatically generated “Source code” archives.

Extract the downloaded zip so the folder is `ForeverQuestPins`, copy it into `Interface\AddOns\`, then restart the game or `/reload`. Enable the addon at character select if needed.

## Settings

The optional **Limit auto-accept quest level** checkbox defaults off. It turns on a level range relative to your current level, set with one slider that has two handles. Both ends run from -10 to +5; the defaults are -10 and +1. At level 15 with -5 and +5, quests from level 10 to 20 are auto-accepted. Auto-accept must also be enabled. Unknown quest levels and shared-quest confirmations are left for manual acceptance while the limit is enabled. The limit does not hide map pins or affect turn-ins.

The optional **Don't auto-accept grey quests** checkbox defaults off. It skips quests the game shows as grey (trivial) for your level, using the game's own grey flag where it is available. Quests with an unknown level are not treated as grey.

**Warn on skipped breadcrumbs** defaults on. When you accept a quest before its breadcrumb quest is completed or in your quest log, a dialog names both quests. **Set Waypoint** uses your configured waypoint provider, **Abandon Quest** removes the quest you just accepted, and **Ignore** hides the warning for that quest until you reload.

**Enhance quest tracker** defaults on. It groups Blizzard's tracked quests under the zone headers from your quest log, puts the current zone first, and adds **Sort quests** and **Show quests** dropdowns. Right-click the **Quests** header for the same controls. **Blizzard order** keeps the client's proximity order. **Distance** refreshes every 5 seconds while the tracker is visible and pauses in combat. **Current zone only**, **Instance quests**, and **Completed quests only** are view filters: they never add or remove tracked quests, and Shift-click still untracks. **Completed quests only** includes quests that are done and waiting to be turned in. **Select nearest quest** is off by default; when on, it super-tracks the closest tracked quest and updates it as you move. Use `/fqp nearest` to select it once. Click a zone's collapse arrow to hide its quests; the state is saved per character. Turn the option off to leave the tracker exactly as Blizzard draws it.

Escape > Options > AddOns > **Forever Quest Pins**, use the world map's **Show** dropdown for quest-start pins, or use the slash commands below. The settings page is split into **General**, **Map pins**, **Quest automation**, **Navigation**, **Quest tracker**, and **Interface** sections in the Settings sidebar. The addon synchronizes choices across account-wide and per-character SavedVariables, plus a small CVar mirror. Revision numbers let the newest copy win without stale defaults overwriting saved choices.

| Option | Default |
|--------|---------|
| Show quest-start pins | On |
| Show quest pins on world and continent maps | On (turn off to keep pins on zone, city, and dungeon maps) |
| Click pins to track quest starts | On for zone maps (turn off to let clicks pass through pins; pin tooltips remain available, but Shift-click hiding is unavailable) |
| Track from world and continent maps | Off |
| Show trivial / low-level pins | Off (hides pins for quests too far below your character) |
| Low-level range slider | 9 (hide quests 9+ levels below you; adjustable from 3 to 15, inactive while low-level pins are shown) |
| High-level range slider | All (show quests at every level above you; move left to hide quests 3+ through 14+ levels above you) |
| Show repeatable quest pins | On |
| Show spawn clusters | On (group nearby spawns into one pin; off shows one pin per quest) |
| Show tint for quests new in WoW Forever | Off (turn on to tint yellow start markers with the Forever yellow-to-blue gradient for quests not in original Classic) |
| Show seasonal / holiday quest pins | Off (when on, pins appear only while the event is live; Darkmoon Faire stays hidden) |
| Show normal quest start pins | On |
| Show class quest pins | On |
| Show profession quest pins | On |
| Show dungeon / raid quest pins | On |
| Show AQ war effort pins | Off (capital turn-ins; appears after a war effort quest is offered or in your log) |
| Always show AQ war effort pins | Off (skip the phase confirmation check) |
| Show in-world destination marker | Uses Blizzard’s current shared navigation setting |
| Waypoint provider | Blizzard Map Pins (TomTom optional) |
| Map pin size | 100% (adjustable from 50% to 150%) |
| Auto-accept quests | Off |
| Warn on skipped breadcrumbs | On (dialog offers Set Waypoint, Abandon Quest, and Ignore) |
| Auto-turn in quests | Off (will not pick when there are multiple rewards) |
| Show quests on NPC tooltips | On (available accepts and ready turn-ins) |
| Show quest icons on nameplates | On (quest start, ready turn-in, and active objective icons beside NPC names) |
| Enhance quest tracker | On (zone groups, sort, and filters inside Blizzard's quest tracker) |
| Sort quests | Blizzard order (distance, level, or title optional) |
| Show quests | All tracked quests (current zone only, instance quests, or completed quests optional) |
| Select nearest quest | Off (super-track the closest tracked quest; `/fqp nearest` selects it once) |
| Debug tooltips | Off |
| Reset hidden quest pins | Button: shows every pin you hid with Shift-click on the current character |

Shift-click a quest-start marker to hide it. On a stacked marker every quest is hidden, so the marker disappears. Hidden quests also drop out of NPC mouseover tooltips, and `/fqp why <id>` reports them as `user-hidden`. The list is per character but saved in the account SavedVariables file (not the CVar mirror), so the settings repair below covers it. Use **Reset hidden quest pins** in settings, or `/fqp hidden` and `/fqp unhide <id|all>`, to restore them.

Click a quest-start marker to set a waypoint at the nearest actual spawn in its cluster. For stacked markers, the first quest is selected. When that quest is accepted, Blizzard tracking takes over its objectives and turn-in. With TomTom selected, the waypoint follows `C_QuestLog.GetNextWaypoint` as quest progress changes. If Blizzard has no location yet, no objective coordinate is invented. Selecting TomTom without it loaded displays a message.

Blizzard supports one user waypoint at a time. Clicking a start replaces that waypoint. Manually changing the Blizzard pin or tracking another quest stops the pending handoff. The addon only clears a matching pin that it created. Forever builds may differ in API support; an unavailable API is reported in chat. Enable **Show in-world destination marker** under Navigation to display Blizzard’s floating marker and distance. This controls the shared `showInGameNavigation` game setting and reflects its current value, including changes made by other addons.

Right-click a quest title in Blizzard’s quest tracker and choose **Copy Wowhead URL** to open its Forever quest link. Press Cmd+C or Ctrl+C to copy the selected URL. Right-clicking the **Quests** header opens the tracker sort and filter menu instead.

## Commands

| Command | Action |
|---------|--------|
| `/fqp` | Help |
| `/fqp on` / `/fqp off` | Enable or disable pins |
| `/fqp trivial` | Toggle low-level / trivial pins |
| `/fqp trivial <3-15>` | Hide quests this many levels below you |
| `/fqp highlevel <3-15>` | Hide quests this many levels above you; 15 shows all |
| `/fqp hidden` | List quest pins hidden with Shift-click on this character |
| `/fqp unhide <id\|all>` | Restore one or all hidden quest pins |
| `/fqp repeatable` | Toggle repeatable quest pins |
| `/fqp spawns` | Toggle grouped spawn pins |
| `/fqp seasonal` | Toggle holiday / seasonal pins |
| `/fqp wareffort` | Toggle AQ war effort pins in capitals |
| `/fqp wareffort always` | Always show AQ war effort pins, skipping the phase confirmation |
| `/fqp accept` | Toggle auto-accept |
| `/fqp turnin` | Toggle auto-turn-in |
| `/fqp breadcrumb` | Toggle skipped-breadcrumb warnings |
| `/fqp breadcrumbtest` | Preview the skipped-breadcrumb dialog |
| `/fqp npctooltip` | Toggle NPC quest accept and ready turn-in tooltips |
| `/fqp nameplates` | Toggle quest icons on nameplates |
| `/fqp nameplatedebug` | Print visible nameplate icon state |
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

## Known limitations

Forever’s quest data is still moving. Missing pins are often a gap in the published export: most quest givers have no coordinates, so those quests cannot be pinned.

- **Saved settings:** Forever client 1.60.1.69913 can write account and character SavedVariables without restoring them. Revisioned copies alone cannot fix this client bug. The optional local repair below has been confirmed on a native macOS Forever installation.
- **Does not add a quest tracker.** The optional enhancement works inside Blizzard's existing tracker. It does not add a quest-log UI, new objectives, or turn-in map pins.
- **Quest eligibility depends on source data.** Forever exposes completion, quest-log membership, and quests offered by the NPC currently being visited, but no API that answers whether an arbitrary quest ID can be accepted. Missing prerequisites can therefore produce early pins until the database is corrected. NPC tooltips list available accepts (including session gossip offers) and active quests that are ready to turn in at that NPC. Incomplete turn-ins are not listed.
- Missing quest starters are learned for the current session when an NPC offers them through gossip or quest details. Unavailable titles appear as `Quest <ID> (title unavailable)` until loaded.
- **Forever-only quests** missing from the export will not pin until the export (or a gossip offer we already saw this session) knows them
- **Item-started** and **object-started** quests stay in the database. They get a start pin only when the export has a usable spawn (drop NPC, chest, or world object). Pure item starts with no spawn stay tooltip-only.
- **Holiday** starts stay hidden unless seasonal pins are on, and then they appear only while the event window is live. Darkmoon Faire stays hidden on Forever.
- **AQ war effort** pins need a confirmed phase: a war effort quest offered or in your log this session, or the always-show override. No Forever API reports the realm phase.
- **Continent** view needs `C_Map.GetMapRectOnMap`; without it, pins only appear on the quest’s own zone map
- **Patrols** (for example Morin Cloudstalker) use the exported static points, plus a second pin at a known path end, until the NPC is visible and near those points
- Reputation requirements are not copied into the addon database, so they do not hide pins
- Most start pins share Blizzard’s `QuestNormal` shape; special pins tint it (blue, red-orange, class color, or copper), with bundled yellow/blue/red-orange fallbacks. Rogue class pins add a dark bang shadow so they stay distinct from normal yellow. Mixed stacks stay yellow.

## Support

For settings that reset despite being saved to disk, close WoW completely and run `go run ./cmd/fqp repair-settings` from the GitHub source checkout using Go 1.27 or later. Pass `--addon` pointing to your installed `ForeverQuestPins` folder and `--saved` pointing to that account's `SavedVariables/ForeverQuestPins.lua`. It previews by default; add `--apply` to create a TOC backup and link the live account settings into the addon loader. It never edits the saved settings. Reapply after addon updates replace the TOC. This is account-specific: do not share the patched addon across accounts. To undo, restore `ForeverQuestPins.toc.before-settings-repair` and remove only the `LocalSavedVariables` link, leaving its target directory intact. The repair tool is available in the source repository, not the CurseForge addon package.

- Bugs: [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues)
- Please include `/fqp stats` (and `/fqp why <id>` if a specific quest is wrong). For nameplate icon issues, include `/fqp nameplatedebug`.
- Quest **database** mistakes usually belong in [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, or in this repo’s QuestieDB converter if QuestieDB has the quest but we dropped a spawn
- Quest **policy** mistakes (holiday membership or instance tags) belong in [Questie](https://github.com/Questie/Questie) corrections, or in the matching parser here
- If you ran a **0.1.10–0.1.16** build and options still reset after `/reload`, close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under `WTF\Account\...\SavedVariables\` and `WTF\Account\...\<realm>\<char>\SavedVariables\`. New users can ignore this.

## License

Addon code is **GPL-3.0-or-later** ([LICENSE](LICENSE)). Quest records come from [QuestieDB](https://github.com/Questie/QuestieDB), with policy data from [Questie](https://github.com/Questie/Questie). See [ATTRIBUTION.md](ATTRIBUTION.md).

Maintainers: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
