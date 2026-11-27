# Forever Quest Pins

Quest-start pins and nameplate quest icons for World of Warcraft Forever (Interface 16001).

Yellow **!** start markers for normal quests, blue **!** for repeatable, red-orange **!** for dungeon and raid, class-colored **!** for class quests, and copper **!** for profession quests on Blizzard’s native world map.

Forever already has a modern quest tracker and objective pins for quests **in your log**. This addon adds start locations for **unaccepted** quests and quest icons on NPC nameplates. It also offers an optional beta layout for Blizzard's tracker with zone groups, sorting, filters, and scrolling.

## Requirements

- World of Warcraft **Forever** only (not Retail, Classic Era, or Cataclysm Classic)
- Folder name must be exactly `ForeverQuestPins`
- No other addons required

TomTom is an optional waypoint provider. The default is **Blizzard Map Pins**.

## Features

- Yellow `!` pins for normal quest starts, blue `!` for repeatable, red-orange `!` for dungeon and raid, class-colored `!` for class quests, and copper `!` for profession quests
- Collectible library book pickups have their own pin category, off by default. Turn it on to show their map pins, NPC tooltip lines, and nameplate icons, and to include them in auto-accept. Book-only pins use a bundled transparent book icon with a subtle drop shadow when **Show book icon for book quest pins** is on; stacks mixed with other quests keep the normal marker. Book icons have their own size slider and default to 75% of a quest pin.
- Dungeon chain pre-quests use the dungeon pin color too. ForeverDungeonJournal's required chain data marks outdoor steps that unlock a dungeon quest, so they appear under **Show dungeon / raid quest pins** instead of hiding among normal yellow pins.
- Map pin tooltips with `[level] quest name` (Forever tracker level when available; Questie inline name when the client has not loaded a title) and NPC names (IDs only if debug is on)
- NPC mouseover tooltips listing quests you can accept and quests ready to turn in (on by default)
- Quest icons beside NPC nameplates for quests you can accept, turn in, or are working on (on by default)
- Nameplate icons show `!` for an acceptable quest, `?` for a ready turn-in, and a quest bullet for an active objective. Completed objectives drop the icon.
- Questie's plain-text and Questie chat links, such as `[[53] Chasing A-Me 01 (4243)]`, become the game's own yellow clickable quest links. Existing native links and clients with Questie loaded are left alone, and the conversion can be turned off in Interface settings or with `/fqp chatlinks`.
- A keybind under **Key Bindings > AddOns > Forever Quest Pins** uses the special item on the tracked quest the tracker highlights, including the quest chosen by **Select nearest quest**. It does nothing when the selected quest has no usable item.
- A minimap button opens **Quest Finder** on left-click and addon settings on right-click. Drag it around the minimap; hide it in **Interface** settings. The Quest Finder header is also draggable, and its position is remembered.
- Quest Finder shows a per-zone Loremaster progress bar for the current or selected zone, calculated from eligible quests assigned to the zone, including chain steps with no map pin, and your completed quests. Repeatable, monthly, seasonal, and profession quests are excluded.
- Each Quest Finder tab has a show-all option: **Show all breadcrumbs**, **Show all zone quests**, and **Show all dungeon quests**. Breadcrumbs adds completed and in-log breadcrumbs, zone quests lists every Loremaster quest assigned to the zone, and dungeon quests adds completed and unavailable dungeon quests and chain steps.
- For a selected zone, **Auto route** opens a small beta route window that orders the Loremaster quests and their source-quest prerequisites, picks up acceptable quests that start on your current map, and finishes in-log objectives before turning the batch in. It is intentionally lazy questing, not an optimal path.
- For a selected dungeon with a curated guide, **Guide route** follows the Dungeon Quests Forever step order, including **Accept**, **Do**, and **Turn in** steps. Blackrock Depths is included first; other dungeons are disabled until their guides are added. The route modal includes a copy button beside the quest that opens its Wowhead Forever URL for copying.
- Both route windows re-evaluate after quest events, zone changes, and quest-giver interactions, hide completed steps, support Skip and Reset, and move the waypoint to the current step. Escape leaves the window open; use its close button or shift-left-click on the minimap button to hide it. Start points and guide NPCs come from the database; objective and turn-in points come from the client once the quest is in your log.
- **Quest Finder** lists breadcrumbs for the current or selected zone, quests available in a zone, and available dungeon quests with their required pre-quest chains. Breadcrumbs are matched by the zone they lead to, so a capital-city breadcrumb for the Plaguelands appears under the Plaguelands, and breadcrumbs whose follow-up is already complete or in the log are hidden. Alternate capital-city versions are grouped into one row that lists every start city, and clicking a row with multiple start zones opens a start-zone chooser. A search box filters the current view by quest, dungeon, zone, or status text. Zone selectors use Leatrix Maps' zone levels, dungeon selectors use the journal's dungeon levels, and every row shows the quest level, start zone, and type tags such as Dungeon, Repeatable, Profession, Class, PvP, Breadcrumb, or Book. The **All dungeons** view shows only acceptable quests and an available-versus-total count. Clicking a dungeon opens its full quest list and chains, including quests you cannot pick up yet, with Complete, In log, Unavailable, and Unknown statuses. Availability uses the player's level and quest prerequisites, not the map pin level filters. Opposite-faction, wrong-race, and wrong-class quests and chain steps stay hidden. Quests that start inside a dungeon are tagged **In dungeon** and do not offer a map pin. Click a row to set a Blizzard map pin from any zone. The breadcrumb and available-quest lists use the same eligibility and display filters as the map pins.
- Optional **beta** quest tracker layout with zone groups, collapsible zone headers, sort options (Blizzard order, distance, level, title), view filters, and mouse-wheel scrolling. It uses Blizzard's own tracker header, quest blocks, item buttons, and POI buttons, and Edit Mode moves and resizes it normally. Off by default.
- Pins stay on the map art in windowed and fullscreen layouts
- Nearby spawn points for one quest group share one pin (up to six per quest). Hover to see the spawn count in the tooltip and every spawn location on the map. Turn off **Show spawn clusters** to show one pin per quest instead
- Overlapping starts on the same spot stack into one pin
- **Shift-click** a pin to hide it (every quest on a stacked pin) for the current character; restore with **Reset hidden quest pins** in settings or `/fqp unhide`
- Adjustable level range with one two-handle slider: hide quests below you and quests above you (default hides quests 9+ levels below and shows all levels above)
- Optional auto-accept and auto-turn-in when talking to NPCs (off by default; hold **Shift** to skip once)
- Warn when you accept a quest whose breadcrumb quest you skipped. The dialog can set a waypoint to the breadcrumb, abandon the quest you just accepted, or ignore the warning (on by default). **Abandon Quest** selects the quest in your log from addon code, so using it can make the map report a blocked action in combat until you reload.
- Seasonal / holiday starts (such as Lunar Festival elders) off by default; when on, pins appear only while the event is live
- AQ opening **war effort** commodity pins in Orgrimmar / Ironforge off by default; when on, they appear after a war effort quest is offered or in your log, or with the always-show override
- Keeps the game's quest item sparkle on if you turn it on, including after a graphics preset resets it (off by default, and offered in the first-run setup guide). The same client setting also makes quest givers sparkle, and turning it off needs a full game restart; `/reload` is not enough

Quest coordinates, quest-giver IDs, turn-in targets, and restrictions come from [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, with holiday, event, and instance-tag policy from [Questie](https://github.com/Questie/Questie). The Go tool `go run ./cmd/fqp build-db` generates the addon database. Quests without a usable spawn stay in the database for tooltips and prerequisites but may not get a map pin. Nameplate objective icons use the client’s unit tooltip, not extra database data.

## Install

**CurseForge:** install [Forever Quest Pins](https://www.curseforge.com/wow/addons/forever-quest-pins) and select the Forever game flavor when the client offers it.

**GitHub:** download a `ForeverQuestPins-v*-forever.zip` file from [GitHub Releases](https://github.com/TylerAkins/forever-quest-markers/releases), not GitHub's automatically generated “Source code” archives.

Extract the downloaded zip so the folder is `ForeverQuestPins`, copy it into `Interface\AddOns\`, then restart the game or `/reload`. Enable the addon at character select if needed.

## Settings

The optional **Limit auto-accept quest level** checkbox defaults off. It turns on a level range relative to your current level, set with one slider that has two handles. Both ends run from -10 to +5; the defaults are -10 and +1. At level 15 with -5 and +5, quests from level 10 to 20 are auto-accepted. Auto-accept must also be enabled. Unknown quest levels and shared-quest confirmations are left for manual acceptance while the limit is enabled. The limit does not hide map pins or affect turn-ins.

The optional **Don't auto-accept grey quests** checkbox defaults off. It skips quests the game shows as grey (trivial) for your level, using the game's own grey flag where it is available. Quests with an unknown level are not treated as grey.

**Warn on skipped breadcrumbs** defaults on. When you accept a quest before its breadcrumb quest is completed or in your quest log, a dialog names both quests. **Set Waypoint** uses your configured waypoint provider, **Abandon Quest** removes the quest you just accepted, and **Ignore** hides the warning for that quest until you reload. **Abandon Quest** selects the quest in your quest log from addon code, which can make the map report a blocked action in combat until you reload. Abandon it from the quest log instead if you want to avoid that.

**Enhance quest tracker (BETA)** is off by default. Turn it on in settings or the setup guide. It groups Blizzard's tracked quests under the zone headers from your quest log, puts the current zone first, and adds **Sort quests** and **Show quests** dropdowns. **All quests** includes every quest in your quest log, including quests that are not on Blizzard's watch list; **Tracked only** keeps the old watch-list view. Once it is on, right-click the **Quests** header for the same controls. A filter with no matches keeps the **Quests** header visible with a short note, so the menu is still reachable. Zone headers collapse and remember their state per character. The tracker scrolls with the mouse wheel when it has more quests than fit; the **Quests** header stays fixed. Edit Mode moves the tracker, changes its height, text size, and opacity, and the scroll viewport follows the height. In combat the tracker uses cached zone data and returns to a fresh view after combat. **Current zone only**, **Instance quests**, and **Completed quests only** are view filters: they never add or remove quests from the log. **Select nearest quest** is off by default; when on, it super-tracks the closest quest in the active view and updates it as you move. With the beta on, it uses the active **Show quests** filter, so a current-zone filter only considers current-zone quests. With the beta off, it uses every tracked quest. Use `/fqp nearest` to select it once. The beta is unavailable while gamepad UI is active; Blizzard's tracker runs unchanged there.

**Show quest item sparkles** is off by default and is also offered on the setup guide's **Navigation** page. Turning it on keeps the client's native quest item sparkle enabled, including after a graphics preset resets it. The client has one switch for quest items and quest givers, so quest givers sparkle too. Turning the option off writes the native setting back to off, but the game keeps drawing sparkles until you restart it; `/reload` is not enough. With the option off the addon never writes the setting, so your own choice in the game's graphics options stands.

Escape > Options > AddOns > **Forever Quest Pins**, the world map's tracking menu, or the slash commands below. The settings page is split into **General**, **Map pins**, **Quest automation**, **Navigation**, **Quest tracker**, and **Interface** sections in the Settings sidebar. The addon synchronizes choices across account-wide and per-character SavedVariables, plus a small CVar mirror. Revision numbers let the newest copy win without stale defaults overwriting saved choices.

| Option | Default |
|--------|---------|
| Show quest-start pins | On |
| Show quest pins on world and continent maps | On (turn off to keep pins on zone, city, and dungeon maps) |
| Click pins to track quest starts | On for zone maps (turn off to let plain clicks pass through pins; pin tooltips and Shift-click hiding still work) |
| Track from world and continent maps | Off |
| Show trivial / low-level pins | Off (hides pins for quests too far below your character) |
| Level range slider | 9 levels below to all above (drag either handle; the below handle is inactive while low-level pins are shown) |
| Show repeatable quest pins | On |
| Show collectible book quest pins | Off |
| Show book icon for book quest pins | Off (book-only pins use the bundled book icon when on) |
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
| Book icon size | 75% (adjustable from 25% to 150%) |
| Auto-accept quests | Off |
| Warn on skipped breadcrumbs | On (dialog offers Set Waypoint, Abandon Quest, and Ignore) |
| Auto-turn in quests | Off (will not pick when there are multiple rewards) |
| Show quests on NPC tooltips | On (available accepts and ready turn-ins) |
| Show quest icons on nameplates | On (quest start, ready turn-in, and active objective icons beside NPC names) |
| Show quest item sparkles | Off (keeps the native quest item sparkle on; quest givers sparkle too, and turning it off needs a full game restart) |
| Show minimap button | On (left-click opens Quest Finder, shift-left-click toggles the last route, right-click opens settings) |
| Make Questie chat links clickable | On (does nothing while Questie is loaded) |
| Enhance quest tracker (BETA) | Off (zone groups, sorting, filters, and mouse-wheel scrolling; unavailable in gamepad UI) |
| Sort quests | Blizzard order (distance, level, or title optional) |
| Show quests | All quests (tracked only, current zone only, instance quests, or completed quests optional) |
| Tracker bottom spacing | 15px (slider 0-60px; space kept above the action bars) |
| Select nearest quest | Off (super-track the closest tracked quest; `/fqp nearest` selects it once) |
| Debug tooltips | Off |
| Reset hidden quest pins | Button: shows every pin you hid with Shift-click on the current character |

Shift-click a quest-start marker on any map to hide it. On a stacked marker every quest is hidden, so the marker disappears. Hidden quests also drop out of NPC mouseover tooltips, and `/fqp why <id>` reports them as `user-hidden`. The list is per character but saved in the account SavedVariables file (not the CVar mirror), so the settings repair below covers it. Use **Reset hidden quest pins** in settings, or `/fqp hidden` and `/fqp unhide <id|all>`, to restore them.

Click a quest-start marker to set a waypoint at the nearest actual spawn in its cluster. For stacked markers, the first quest is selected. When that quest is accepted, Blizzard tracking takes over its objectives and turn-in. With TomTom selected, the waypoint follows `C_QuestLog.GetNextWaypoint` as quest progress changes. If Blizzard has no location yet, no objective coordinate is invented. Selecting TomTom without it loaded displays a message.

Blizzard supports one user waypoint at a time. Clicking a start replaces that waypoint. Manually changing the Blizzard pin or tracking another quest stops the pending handoff. The addon only clears a matching pin that it created. Forever builds may differ in API support; an unavailable API is reported in chat. Enable **Show in-world destination marker** under Navigation to display Blizzard’s floating marker and distance. This controls the shared `showInGameNavigation` game setting and reflects its current value, including changes made by other addons.

Right-click a quest title in Blizzard’s quest tracker and choose **Copy Wowhead URL** to open its Forever quest link. Press Cmd+C or Ctrl+C to copy the selected URL. While the beta tracker is active, right-clicking the **Quests** header opens the tracker sort and filter menu.

## Commands

| Command | Action |
|---------|--------|
| `/fqp` | Help |
| `/fqp finder` | Open Quest Finder |
| `/fqp finderreset` | Reset Quest Finder to the screen center |
| `/fqp finderdebug` | Print Quest Finder counts and active filters |
| `/fqp options` | Open the addon settings |
| `/fqp on` / `/fqp off` | Enable or disable pins |
| `/fqp trivial` | Toggle low-level / trivial pins |
| `/fqp trivial <3-15>` | Hide quests this many levels below you |
| `/fqp highlevel <3-15>` | Hide quests this many levels above you; 15 shows all |
| `/fqp hidden` | List quest pins hidden with Shift-click on this character |
| `/fqp unhide <id\|all>` | Restore one or all hidden quest pins |
| `/fqp repeatable` | Toggle repeatable quest pins |
| `/fqp books` | Toggle collectible book quest pins |
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
| `/fqp chatlinks` | Toggle clickable Questie chat links |
| `/fqp nameplatedebug` | Print visible nameplate icon state |
| `/fqp debug` | Toggle debug tooltips |
| `/fqp track <id>` | Track a quest start, or Blizzard-provided objective / turn-in |
| `/fqp nearest` | Select the closest tracked quest once |
| `/fqp trackerdebug` | Print quest tracker layout diagnostics |
| `/fqp clear` | Clear the addon waypoint or its tracked quest |
| `/fqp refresh` | Rebuild pins on the current map |
| `/fqp stats` | Print the database commit, quest count, and painted pin count |
| `/fqp settings` | Print saved and effective option values for debugging |
| `/fqp why <id>` | Why a quest is pinned or hidden |
| `/fqp available` | Starts that should pin on the open map |
| `/fqp wipe` | Reset options (recovery; see Support) |
| `/fqp apis` | Which Forever map/quest APIs this client exposes |
| `/fqp taint` | List Blizzard fields tainted by an addon (debug; run after a blocked-action popup) |

## Known limitations

Forever’s quest data is still moving. Missing pins are often a gap in the published export: most quest givers have no coordinates, so those quests cannot be pinned.

- **Saved settings:** Forever client 1.60.1.69913 can write account and character SavedVariables without restoring them. Revisioned copies alone cannot fix this client bug. The optional local repair below has been confirmed on a native macOS Forever installation.
- **Optional beta tracker.** The quest tracker layout is a beta feature, off by default. While gamepad UI is active, the addon leaves Blizzard's tracker unchanged. It does not add a quest-log UI or turn-in map pins.
- **Quest eligibility depends on source data.** Forever exposes completion, quest-log membership, and quests offered by the NPC currently being visited, but no API that answers whether an arbitrary quest ID can be accepted. Missing prerequisites can therefore produce early pins until the database is corrected. NPC tooltips list available accepts (including session gossip offers) and active quests that are ready to turn in at that NPC. Incomplete turn-ins are not listed.
- Missing quest starters are learned for the current session when an NPC offers them through gossip or quest details. Unavailable titles appear as `Quest <ID> (title unavailable)` until loaded.
- **Forever-only quests** missing from the export will not pin until the export (or a gossip offer we already saw this session) knows them
- **Item-started** and **object-started** quests stay in the database. They get a start pin only when the export has a usable spawn (drop NPC, chest, or world object). Pure item starts with no spawn stay tooltip-only.
- **Holiday** starts stay hidden unless seasonal pins are on, and then they appear only while the event window is live. Darkmoon Faire stays hidden on Forever.
- **AQ war effort** pins need a confirmed phase: a war effort quest offered or in your log this session, or the always-show override. No Forever API reports the realm phase.
- **Continent** view needs `C_Map.GetMapRectOnMap`; without it, pins only appear on the quest’s own zone map
- **Patrols** (for example Morin Cloudstalker) use the exported static points, plus a second pin at a known path end, until the NPC is visible and near those points
- Reputation requirements are not copied into the addon database, so they do not hide pins
- Most start pins share Blizzard’s `QuestNormal` shape; special pins tint it (blue, red-orange, class color, or copper), with bundled yellow/blue/red-orange fallbacks. Book-only pins use a bundled transparent book icon with a subtle drop shadow instead. Rogue class pins add a dark bang shadow so they stay distinct from normal yellow. Mixed stacks stay yellow; when a stack contains a repeatable quest, its tooltip line ends with `(Repeatable)`.

## Support

For settings that reset despite being saved to disk, close WoW completely and run `go run ./cmd/fqp repair-settings` from the GitHub source checkout using Go 1.27 or later. Pass `--addon` pointing to your installed `ForeverQuestPins` folder and `--saved` pointing to that account's `SavedVariables/ForeverQuestPins.lua`. It previews by default; add `--apply` to create a TOC backup and link the live account settings into the addon loader. It never edits the saved settings. Reapply after addon updates replace the TOC. This is account-specific: do not share the patched addon across accounts. To undo, restore `ForeverQuestPins.toc.before-settings-repair` and remove only the `LocalSavedVariables` link, leaving its target directory intact. The repair tool is available in the source repository, not the CurseForge addon package.

- Bugs: [GitHub Issues](https://github.com/TylerAkins/forever-quest-markers/issues)
- Please include `/fqp stats` (and `/fqp why <id>` if a specific quest is wrong). For nameplate icon issues, include `/fqp nameplatedebug`.
- For a blocked-action popup or taint report, include the protected function name from the popup and the output of `/fqp taint`, run right after the popup appears and before `/reload`.
- Quest **database** mistakes usually belong in [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, or in this repo’s QuestieDB converter if QuestieDB has the quest but we dropped a spawn
- Quest **policy** mistakes (holiday membership or instance tags) belong in [Questie](https://github.com/Questie/Questie) corrections, or in the matching parser here
- If you ran a **0.1.10–0.1.16** build and options still reset after `/reload`, close the game and delete leftover `ForeverQuestPins.lua` (and `.bak`) under `WTF\Account\...\SavedVariables\` and `WTF\Account\...\<realm>\<char>\SavedVariables\`. New users can ignore this.

## License

Addon code is **GPL-3.0-or-later** ([LICENSE](LICENSE)). Quest records come from [QuestieDB](https://github.com/Questie/QuestieDB), with policy data from [Questie](https://github.com/Questie/Questie). See [ATTRIBUTION.md](ATTRIBUTION.md).

Maintainers: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
