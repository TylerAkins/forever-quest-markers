# Development

Forever Quest Pins is a small World of Warcraft Forever addon (Interface **16001**). Players should read [README.md](../README.md). This file is for maintaining the repo, database, and releases.

Repository tools use Go 1.27 or later. The Lua runtime tests also require LuaJIT on `PATH`.

## Layout

| Path | Role |
|------|------|
| `ForeverQuestPins.toc` | Load order, Interface 16001, packager metadata |
| `Bindings.xml` | Key binding for using the tracked quest's special item |
| `Config.lua` | Saved variables, slash commands, settings panel |
| `Sparkle.lua` | Native quest item sparkle CVar, login and graphics-change reapply, combat deferral |
| `HiddenQuests.lua` | Per-character Shift-click hidden quest pins, stored in the account DB under `hiddenQuests["Name-Surname"]`; pre-1.1.0 realm-keyed buckets are adopted on first access |
| `Eligibility.lua` | Completion, log, source quests, NPC-offered quests |
| `Events.lua` | Holiday windows and AQ war effort phase state from generated policy |
| `MapPins.lua` | World-map start pins |
| `Nameplates.lua` | Quest start, turn-in, and objective icons on NPC nameplates |
| `Waypoints.lua` | Optional Blizzard / TomTom navigation and selected quest lifecycle |
| `QuestItemKeybind.lua` | Keybind that uses the special item on the tracked quest |
| `Breadcrumbs.lua` | Skipped-breadcrumb detection, warning dialog, and quest actions |
| `QuestLinks.lua` | Copy Wowhead URL menu entry for tracked quest blocks |
| `ChatQuestLinks.lua` | Turns Questie's plain-text chat links into clickable quest links |
| `TrackerData.lua` | Quest-log zone headers, current-zone chain, distance, and the tracker sort/filter view |
| `Tracker.lua` | Optional beta quest module inside Blizzard's tracker, zone headers, scroll viewport, and gamepad fallback |
| `MinimapButton.lua` | Draggable minimap button that opens Quest Finder and settings |
| `QuestFinder.lua` | Quest Finder window for breadcrumbs, available quests, and dungeon chains |
| `AutoQuests.lua` | Optional auto-accept / auto-turn-in |
| `Core.lua` | Events and refresh |
| `Database/ForeverQuests.lua` | Generated quest records (do not edit by hand) |
| `Database/Metadata.lua` | Pinned QuestieDB artifact, checksum, policy commit, and counts |
| `Database/QuestTagCorrections.lua` | Generated static instance-tag corrections |
| `Database/DungeonChains.lua` | Generated dungeon quests and required pre-quest chains from ForeverDungeonJournal |
| `Database/DungeonRoutes.lua` | Generated curated dungeon guide steps from Dungeon_Quests_Forever |
| `Database/EventPolicy.lua` | Generated holiday windows, per-quest overrides, Lunar Festival years, and AQ war effort IDs |
| `Database/BookQuests.lua` | Hand-maintained library book pickup quest IDs for the collectible book category |
| `Database/ZoneLevels.lua` | Hand-maintained zone level ranges copied from Leatrix Maps |
| `Database/BreadcrumbTargets.lua` | Hand-maintained breadcrumb quest to target-zone overrides |
| `Database/ExcludedQuests.lua` | Hand-maintained quest IDs that should never show map pins |
| `Database/build_report.json` | Build stats (not shipped in the player zip) |
| `VERSION` | Current stable release used by automated version checks |
| `RELEASE_NOTES.md` | Curated notes for only the current release |
| `Media/QuestAvailable.tga` | Yellow fallback bang if `QuestNormal` fails |
| `Media/QuestBook.tga` | Bundled transparent book icon for book-only pins |
| `Media/QuestRepeatable.tga` | Blue fallback if the tinted `QuestNormal` atlas cannot be used |
| `Media/QuestAttunement.tga` | Red-orange fallback for dungeon and raid quests |
| `cmd/fqp` | Go command-line entry point for repository tools |
| `internal/questiedb/` | QuestieDB TOC, CBOR, entity, zone, and dungeon readers |
| `internal/questiepolicy/` | Questie holiday and instance-tag policy parser |
| `internal/questdb/` | Merge, start resolution, schema mapping, emitter, and report |
| `internal/release/` | Prepares database releases and validates automated patch releases |
| `internal/foreverupdate/` | Blizzard build feed to TOC compatibility release |
| `internal/addontools/` | Addon compiler, settings repair, and fallback TGA generation |
| `.pkgmeta` | [BigWigs packager](https://github.com/BigWigsMods/packager) rules |

## Database

Quest coordinates, starters, turn-in targets, and restrictions come from the latest stable [QuestieDB](https://github.com/Questie/QuestieDB) Forever release artifact. Holiday membership, event windows, the AQ war effort quest list, and instance-tag corrections come from [Questie](https://github.com/Questie/Questie).

```bash
go run ./cmd/fqp build-db \
  --questiedb /path/to/QuestieDB-Forever.zip \
  --questiedb-sha bdfc31538466a575c9a4aa8d7c2cf9678cf3ca4734f682c5381f0d697e567aa8 \
  --questiedb-ref v1.1.4 \
  --questie /path/to/Questie \
  --questie-sha d0b0e89ac228e380e139f1c524408507e6d4fe1b \
  --out Database
```

`--questiedb` accepts the release zip or an extracted directory. A second run on the same artifact and policy commit produces the same bytes. `Database/Metadata.lua` records the artifact SHA-256, build commit, policy commit, contract version, and counts. `Database/QuestTagCorrections.lua` is loaded before `Eligibility.lua` and gives the runtime a static instance hint when `C_QuestLog.GetQuestTagInfo` is missing or slow.

`Database/EventPolicy.lua` is generated from Questie's Era event data. It carries year-less `{ month, day, hour, minute }` windows, per-quest overrides such as the Winter Veil presents, Questie's Lunar Festival year table, and the `AQWarEffortQuests` IDs. The build fails if a yearly quest has no event name or a referenced event has neither a window nor a disabled marker. Darkmoon Faire is emitted as disabled: Questie skips it on Forever, it has no importable faire window, and most of its records mix Mulgore and Elwynn coordinates. Lunar Festival windows end at Questie's pinned year; later years hide with `lunar-year-unknown` instead of failing the build.

`Database/BookQuests.lua` is hand-maintained. The generated artifact has no objective text, so the build cannot reliably identify the library pickup quests. The list matches the quests whose objective is "Collect '<book title>' and bring it to ..." and excludes the Friend of the Library turn-ins (78150, 79536, 82208, 84394). `TestBookQuestListMatchesGeneratedDatabase` pins the 40 IDs, checks that each exists in `Database/ForeverQuests.lua`, and fails when the list or generated data diverges.

`Database/ZoneLevels.lua` is hand-maintained from Leatrix Maps' "Level range table" under **Show zone levels**. Quest Finder prefers these ranges. City entries are `false`, which suppresses a computed range. Maps Leatrix does not list fall back to the minimum levels of quests with starts in that zone.

`Database/BreadcrumbTargets.lua` is hand-maintained. Quest Finder derives a breadcrumb's target zone from the follow-up quests that list it in `sourceQuestSingle` or `sourceQuestGroup`. Add an override there when the follow-up starts outside the zone the breadcrumb is meant for, or when the follow-up is missing. Values are a UiMapID or a list of map IDs.

Quest Finder's Loremaster bar counts quests assigned to the selected zone, including chain steps with no start coordinates. It uses Questie's `zone` field first and falls back to start coordinates for records without one. It keeps quests that match the player's faction, race, and class, and excludes repeatable, monthly, seasonal, and profession quests. Completed counts come from the quest completion API.

The generated records separate prerequisites into AND (`sourceQuestGroup`) and OR (`sourceQuestSingle`, required count 1) lists. Coordless records stay in the database for tooltips and prerequisites but are excluded from `ns.ByMap`; gossip-learned starts fill their coordinates at runtime. Each record also carries Questie's assigned quest zone as `zone` when it maps to a UiMapID, so Quest Finder can count chain steps without start coordinates. Turn-in NPC and object ids are compiled into the database and shown on NPC tooltips when the quest is active and complete. Nameplate objective icons use the client's unit tooltip (`C_TooltipInfo.GetUnit`) instead of generated objective NPC data.

`Database/DungeonChains.lua` comes from a local ForeverDungeonJournal install, not QuestieDB. It carries each dungeon's quest list, the required pre-quest chain, and the journal's start coordinates. Regenerate it after a journal update:

```bash
luajit tools/generate-dungeon-chains.lua \
  "/Applications/World of Warcraft/_forever_/Interface/AddOns/ForeverDungeonJournal" \
  Database/DungeonChains.lua
```

The addon marks chain quests as dungeon quests, so a normal outdoor pre-quest that unlocks a dungeon step uses the dungeon pin color and the **Show dungeon / raid quest pins** filter.

`Database/DungeonRoutes.lua` comes from the Dungeon_Quests_Forever dungeon and attunement guides. All dungeon guides are included, plus the UBRS key and Onyxia attunement guides. Cozy Sleeping Bag and Mallet of Zul'Farrak have no guide. Regenerate it after a guide update:

```bash
luajit tools/generate-dungeon-routes.lua \
  "/path/to/Dungeon_Quests_Forever" \
  Database/DungeonRoutes.lua
```

Zone routes remain automatic. Dungeon Guide routes use these curated Accept, Do, and Turn in steps. Objective text is summarized by this project; step order, NPC coordinates, and faction flags come from the guide.

Optional parity review against an older database:

```bash
go run ./cmd/fqp build-db ... --out Database --baseline /path/to/old/ForeverQuests.lua
```

This adds recovered/lost starts, coordinate changes, flag changes, and conflicts to `Database/build_report.json`. The committed build report omits the baseline so it can be reproduced from the pinned inputs.

### Automated updates

Workflow **Update QuestieDB database** (`.github/workflows/update-questie-db.yml`):

- Wednesday, Friday, Saturday, and Sunday at 06:00 UTC and on manual **Run workflow**
- Resolves the latest non-prerelease QuestieDB release and fails when none exists
- Downloads that stable `v*` Forever artifact and records its tag and SHA-256 in the PR
- Checks out Questie at the policy commit already pinned in `Database/Metadata.lua`
- Opens a versioned PR only when `Database/ForeverQuests.lua` or `Database/EventPolicy.lua` changed; artifact SHA-only updates with no data diff are ignored
- Closes its existing `questie-db-update` PR if regenerated quest records return to the version already on `main`
- Bumps the patch version and updates `CHANGELOG.md` and the current `RELEASE_NOTES.md`
- Publishes the prepared GitHub and CurseForge release after a human reviews and merges the PR
- Needs **Settings > Actions > General > Workflow permissions > Allow GitHub Actions to create and approve pull requests**

It never pushes generated data straight to `main` or merges its own PR.

## Forever interface updates

Workflow **Update Forever interface** (`.github/workflows/update-forever-interface.yml`):

- Runs Wednesday at 12:00 UTC, after the US Tuesday and EU Wednesday maintenance windows
- Reads Blizzard's explicit `wow_classic_beta` product feed and converts versions such as `1.60.1.69913` to Interface `16001`
- Ignores build-only changes when the calculated Interface is unchanged
- Opens or refreshes the reviewed `forever-interface-update` PR with the TOC, next patch version, changelog entry, and current release notes
- Closes that fixed PR if the current Interface is already supported on `main`
- Publishes the prepared GitHub and CurseForge release only after a human merges the PR

Run it manually from `main` when an out-of-cycle Forever patch lands. If Blizzard moves Forever off `wow_classic_beta` after launch, change the single `VersionsURL` constant in `internal/foreverupdate/update.go` rather than falling back to another WoW flavor.

## Tests

```bash
go test ./...
go vet ./...
```

The Go Lua-runtime tests require LuaJIT on `PATH`. On macOS with Homebrew, install it with `brew install luajit`; CI installs the Ubuntu `luajit` package.

CI (`validate`) runs the Go tests, checks release intent, and dry-runs the packager. Database regeneration runs in the automated update workflow, not CI.

## Local builds

After editing `CHANGELOG.md` for a player-facing release, run `go run ./cmd/fqp generate-news` and include `WhatsNew.lua` in the change. The generator selects the latest release with player-facing entries and omits QuestieDB artifact and quest-count entries. Database-only releases therefore do not produce a new chat announcement. The Go tests check that the generated file is current.

Build a clean, directly installable addon folder with:

```bash
go run ./cmd/fqp compile-addon
```

Each run deletes the previous `.compiled/ForeverQuestPins` directory and recreates it from the files shipped by `.pkgmeta`. The generated TOC uses the current Git description as its version. Copy `.compiled/ForeverQuestPins` directly into the client's `Interface/AddOns` directory.

Use `go run ./cmd/fqp compile-addon --dry-run` to list the files without changing `.compiled/`.

## Other repository tools

Run the Blizzard compatibility updater with `go run ./cmd/fqp update-interface`. It fetches the current `wow_classic_beta` version feed and prepares release files only when the interface changes. Use `--versions-file /path/to/feed` to test a saved response, or `--dry-run` to preview it.

Prepare or validate release metadata with `go run ./cmd/fqp release prepare --base-version VERSION`, `go run ./cmd/fqp release validate-notes --version VERSION`, `go run ./cmd/fqp release validate ...`, or `go run ./cmd/fqp release validate-tag ...`. The automated workflows use the validation commands when deciding whether a reviewed patch release is valid.

Regenerate fallback textures with `go run ./cmd/fqp generate-icon`. Repair local account settings with `go run ./cmd/fqp repair-settings --addon /path/to/ForeverQuestPins --saved /path/to/SavedVariables/ForeverQuestPins.lua`; add `--apply` only after closing WoW completely. The tool previews by default and never modifies the saved settings file.

## Releases

| Channel | Trigger | Result |
|---------|---------|--------|
| Stable | Push an annotated `v*` tag, or merge a prepared quest database/interface PR | Numbered GitHub Release and CurseForge package |
| Preview | Merge to `main` or manually run the Release workflow | Commit-specific GitHub Actions artifact |

Only stable tags are distributed to players. Preview builds are for testing and do not push or move a Git tag. Do not point players at GitHub's “Source code” archives; the packager zip is the installable addon.

`.pkgmeta` ships addon Lua, `Database/*.lua`, `Media/`, `LICENSE`, `README.md`, `ATTRIBUTION.md`, `CHANGELOG.md`, and `RELEASE_NOTES.md`. It does **not** ship `VERSION`, `CURSEFORGE_DESCRIPTION.md`, `tests/`, `cmd/`, `internal/`, `.github/`, or `build_report.json`.

The packager uploads `RELEASE_NOTES.md` as the release changelog instead of generating notes from Git commits. This prevents commit metadata from appearing on CurseForge and avoids publishing the full release history. Automated database and Forever Interface PRs replace this file with only their prepared release entry. CI requires that entry to match `VERSION` and rejects email addresses.

All stable releases must update `VERSION` to match the tag. Automated database and Forever Interface PRs do this, and merging either creates the tag. If both prepare the same patch concurrently, merge one and manually rerun the other updater so its fixed PR refreshes against the new `main`. For other releases, update `VERSION`, `CHANGELOG.md`, and `RELEASE_NOTES.md` in the release PR before creating the tag.

## CurseForge

CurseForge uses its [native automatic packager](https://support.curseforge.com/support/solutions/articles/9000197281-automatic-packaging). GitHub Actions does not upload to CurseForge.

Project configuration:

1. Set **Source Code** to the public GitHub repository.
2. Set **Automatic Packaging** to package new tagged commits, not all commits.
3. Generate a dedicated CurseForge API token for the repository webhook.
4. In GitHub repository settings, add a webhook for push events with this payload URL:

   ```text
   https://www.curseforge.com/api/projects/{projectID}/package?token={token}
   ```

5. Keep the webhook defaults and verify its initial delivery succeeds.

The payload URL contains the API token. Never commit it, add it as an Actions secret, paste it into an issue, or include it in logs. Revoke and replace the token if the URL is exposed.

The native packager reads `.pkgmeta` and replaces `@project-version@` with the pushed tag. A normal tag such as `v0.1.22` is a Release; tags containing `beta` or `alpha` receive the corresponding CurseForge status. Do not add `X-Curse-Project-ID` solely for native packaging.

The project long description is maintained in `CURSEFORGE_DESCRIPTION.md`. Paste the section below its separator into the CurseForge project page when it changes.

License on CurseForge: **GPL-3.0-or-later**. Credit QuestieDB for the quest data and Questie for policy corrections. See [ATTRIBUTION.md](../ATTRIBUTION.md).

## Pin textures

Normal map pins call `SetAtlas("QuestNormal", false)` at a fixed 24px size. Special pins use the same atlas with desaturation and a vertex tint: red-orange for dungeon/raid, `RAID_CLASS_COLORS` / `C_ClassColor` for class-only stacks, copper `(1.00, 0.65, 0.20)` for profession-only stacks, and blue for repeatable-only stacks. Pins whose quests are all library book pickups use `Media/QuestBook.tga` with a subtle black drop shadow when the **Show book icon for book quest pins** option is on; a stack mixed with a normal quest keeps the normal marker. Rogue class pins also draw a near-black tinted `QuestNormal` on the ARTWORK fill layer, offset 1px down-right, so class yellow does not look like a normal start. Priority is instance, class, profession, book, repeatable, then normal; mixed stacks stay yellow, and a repeatable quest in a multi-quest stack adds `(Repeatable)` to its tooltip line. Instance classification asks `C_QuestLog.GetQuestTagInfo`, falls back to the generated Questie tag corrections, then to the static `isInstanceQuest` flag. Bundled yellow, blue, and red-orange TGAs remain as fallbacks, followed by `QuestDaily` for repeatable pins. Do not bind `Interface\GossipFrame\AvailableQuestIcon` on the map: on Forever that path can succeed with no pixels and hide working art.

Addon map pins are ordinary buttons parented to the map canvas and never enter Blizzard's MapCanvas pin pools. Calling `WorldMapFrame:AcquirePin` from addon code adds our template to the canvas `pinPools` table, which is shared Blizzard state that addon code should not write. Keep pin creation on our frames and add a regression case that fails if `AcquirePin` is called.

Never post-hook `WorldMapFrame`. A `hooksecurefunc` post-hook runs inside Blizzard's map execution, so the rest of that execution inherits the addon's taint. In 1.1.1 the `Show`, `Hide`, `OnMapChanged`, `OnCanvasScaleChanged`, and `SynchronizeDisplayState` hooks made `SetDisplayState` write the quest log list and scroll container fields after `ShowUIPanel` as ForeverQuestPins. The next map opened in combat read those fields while placing its pins, and the client refused `SetPassThroughButtons` and `SetPropagateMouseClicks` with this addon named. Open, close, map changes, and canvas scale changes are watched from `mapWatch`'s `OnUpdate`, which runs in the addon's own execution. The watch skips map calls during combat and replays a pending open or close after combat, so opening the map in combat cannot taint Blizzard's pin placement.

The pin filters live in Blizzard's world map tracking menu (`MENU_WORLD_MAP_TRACKING`). Register the menu callback from `ns.TryRegisterWorldMapDropdown` after `Blizzard_WorldMap` loads; the map rebuilds that menu from `OnShow`. The addon no longer draws a second filter button or list over the map. If a future client reports a blocked map action, compare the map-open stack with this callback before changing the menu registration.

`/fqp taint` scans the map, quest log, and tracker frames with `issecurevariable` and names the addon that last wrote each tainted field; run it before `/reload` after a block, and check that no map field is tainted.

The skipped-breadcrumb dialog no longer abandons the quest from addon code. Selecting a quest with `C_QuestLog.SetSelectedQuest` makes the quest log write `DetailsFrame.questID` and related fields under the addon's taint; the map reads them while placing pins in combat and refuses `SetPassThroughButtons`. The dialog tells the player to abandon from the quest log and sets a waypoint to the skipped breadcrumb through `ns.TrackQuest` when the quest disappears. The dialog's **Set Waypoint** action remains. A waypoint failure reports the reason but does not block the dialog.

The addon keeps each pin's center for its own hover lookup and uses a private tooltip while Gamepad UI is active. Verify in game by hovering an addon pin with the controller, then closing the map, and by opening the map in combat; confirm the tooltip works and no blocked-action popup appears. Do not test with `/console taintLog` on: on Forever it breaks post-hooked methods and does not produce a usable log.

## Support split

- Pin / eligibility / auto-quest / NPC tooltip bugs belong in this repo’s issues
- Wrong coordinates or missing Forever quests in the converted DB belong in [QuestieDB](https://github.com/Questie/QuestieDB) Forever data, unless our converter dropped a spawn QuestieDB has
- Wrong holiday membership, event dates, AQ war effort membership, or instance tags belong in [Questie](https://github.com/Questie/Questie) corrections, unless our parser dropped an entry

## Waypoint providers

Blizzard Map Pins is the default. Start clicks use zone coordinates, normalized
from the database's 0–100 units, with `UiMapPoint.CreateFromCoordinates`,
`C_Map.SetUserWaypoint`, and optionally `C_SuperTrack.SetSuperTrackedUserWaypoint`.
On acceptance, `C_SuperTrack.SetSuperTrackedQuestID` hands objective and turn-in
navigation to Blizzard. TomTom receives the location returned by
`C_QuestLog.GetNextWaypoint` and updates on quest-log / POI refreshes.
Unavailable coordinates remove the old TomTom target until new data arrives.

References checked during implementation:

- [Blizzard map API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
- [Blizzard quest location API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Blizzard super-tracking API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua)
- [Adventure Guide Forever](https://github.com/cjber/adventure-guide-forever), which documents native waypoint guidance as its optional-provider fallback

The published Classic and Classic Beta API snapshots omit the retail user
waypoint functions. Check actual Forever support with `/fqp apis`; runtime
capability checks report unsupported clients/maps. TomTom signatures and options
were also verified against the locally installed Forever-compatible TomTom.
The user verified that `/console showInGameNavigation 1` enables Forever's
native floating navigation marker. The Navigation checkbox reads and writes
that shared CVar directly, so it reflects changes from the console or other
addons and does not overwrite the player's choice on login. Verify presentation
in game.

`ns.TrackQuest`, `ns.UpdateWaypoint`, and `ns.ClearWaypoint` refuse to write while
`AddOnActionsRestricted()` is true. A super-track or user waypoint write from
addon code in combat taints the map's pin refresh. Existing tracking resumes on
the post-combat refresh; a new tracking click in combat reports that tracking is
unavailable.

In-game verification: choose Blizzard Map Pins with TomTom disabled, click a
start on both its zone map and a parent map, accept it, progress its objectives,
and turn it in. Repeat with TomTom selected. Check changing provider, manually
replacing a Blizzard pin, abandoning a selected quest, and reloading the saved
provider setting. Stacked start markers select their first quest.

## Quest tracker links

`QuestLinks.lua` appends **Copy Wowhead URL** to `MENU_QUEST_OBJECTIVE_TRACKER`.
Forever's menu does not supply quest context, so secure post-hooks on the tracker
header enter/leave methods identify the hovered block. The menu action captures
its quest ID before the block can be recycled. This supports mouse right-clicks
on Blizzard's quest titles and on the beta module's quest titles; gamepad menus
without a hovered header are unchanged.

The menu tag, hover methods, owner, and popup edit box contract were checked
against the [Forever Blizzard UI source at 734f065](https://github.com/Gethe/wow-ui-source/tree/734f065329cff4992835b01a84f210a297db91b6),
including `Blizzard_QuestObjectiveTracker.lua`, `Blizzard_ObjectiveTrackerModule.lua`,
`Blizzard_StaticPopup/StaticPopup.lua`, and `Blizzard_StaticPopup_Game/GameDialog.lua`.
Runtime tests cover URL selection, invalid IDs, delayed initialization, menu scope,
and capturing the selected quest independently of later hover changes.

In game, right-click two different tracked quest titles and copy each URL. Confirm
the Forever quest IDs, existing tracking/details/share/abandon actions, Escape
closing the copy dialog, and behavior after `/reload`. Combat and taint behavior
require client verification.

## Quest tracker beta

`Tracker.lua` creates a standalone quest module frame, `FQPStandaloneTracker`,
parented to `UIParent` and positioned from Blizzard's `ObjectiveTrackerFrame`. It
uses `ObjectiveTrackerModuleTemplate`, mixes in `QuestObjectiveTrackerMixin`, and
owns its own container. Blizzard's `QuestObjectiveTracker` is removed from
`ObjectiveTrackerFrame` and hidden while ours is active. Its quest events are
unregistered for that time so auto-quest popups and turn-in updates are handled
once by our module; they are registered again when Blizzard's module is restored.
Disabling the option restores it. The addon never assigns Blizzard's
`BuildQuestWatchInfos`, `EnumQuestWatchData`, `SetTrackerTargetButton`,
`SelectFirstButton`, or `UpdateSmartNavigationOverrides`; the repository contract
test checks that.

The standalone frame copies Blizzard's position and size when it is created. Drag
the **Quests** header to move it. The frame fills the Edit Mode height; the module
scrolls inside it. The height follows Edit Mode's height slider, but moving the
source frame in Edit Mode does not move the standalone tracker.

`Tracker.lua` is a beta feature and `enhanceQuestTracker` defaults off. A new
`_trackerBetaSeenV2` marker forces the option off once for installs that had the
retired beta enabled, then respects later choices. The settings section, setup
guide, and tracker right-click menu label it **BETA**. The menu is attached only
to our module header; Blizzard's header is not hooked while the beta is off, so
the stock tracker stays untouched. Enable the beta from settings or the setup
guide.

`TrackerData.lua` annotates each watched quest with its native quest-log header,
current-zone match, instance flag, level, title, and distance. Zone groups put the
current zone first, then sort and filter the view. Combat reuses the cached
annotations; a quest first seen in combat goes under **Other** until the next
out-of-combat layout. Filters never call `AddQuestWatch` or `RemoveQuestWatch`.

- `Tracker.lua` inserts `ObjectiveTrackerBlockTemplate` headers for each zone.
  Header clicks and the collapse arrow toggle the zone, and the state lives in
  `ForeverQuestPinsDB.trackerCollapsedZones["Name-Surname"]`, outside
  `ns.defaults` so settings sync never copies it.
- Zone headers use `ObjectiveTrackerHeaderFont`, `OBJECTIVE_TRACKER_COLOR`, and
  `ObjectiveTrackerModuleMinimizeButtonTemplate`. The **Quests** module header
  stays fixed. All other blocks scroll.
- Scrolling reparents the module's `ContentsFrame` into a `ScrollFrame`. The
  module sets the scroll child's width before the base layout so quest text is
  measured at the real width, then caps `contentsHeight` to the available
  viewport in `UpdateScrollViewport`. The scroll child keeps the full content
  height, and `SetCollapsed` hides and resets the viewport. Mouse wheel handlers
  are attached to the module, scroll frame, content, zone headers, quest blocks,
  item buttons, and POI buttons. Quest blocks keep wheel and hover input but do
  not take clicks, so their header, item, and POI buttons keep working when a
  block is reused. Zone headers keep their row click so the area beside the
  collapse arrow still toggles, and auto-quest popups keep it so their row opens
  the quest. The bottom inset is configurable as
  `trackerBottomInset`, default 15px and adjustable from 0 to 60px, so the last row
  can clear the action bars without the old large gap.
- Auto-quest popup blocks use a negative offset in Blizzard's module. The
  tracker clamps that offset to zero inside the scroll child so the popup's left
  edge and icon are not clipped.
- Quest blocks use a 30px indent so the visible 20px POI icon stays inside the
  clipped scroll area. The wider POI glow is hidden there instead of clipping
  its edge. Zone headers use a 7px offset so their text lines up with the
  **Quests** module header.
- When a non-all filter has no matches, the module keeps its header available
  with a muted "No tracked quests match this filter." block. The right-click
  menu stays reachable instead of disappearing with the content.
- Sort, filter, and zone changes reset the scroll position to the top. Quest
  updates preserve it and clamp it when the content shrinks.
- Edit Mode is Blizzard's existing Objective Tracker system. Moving the tracker,
  changing its height, text size, or opacity needs no custom mover; the viewport
  follows the height setting. The standalone tracker copies the size and position
  when it is created and follows later height changes, but not later position
  changes; drag its header to move it.
- `InputUtil.IsGamepadUIEnabled()` is a hard gate. When gamepad UI is active the
  module is not added, the settings controls are disabled with a note, and the
  setup guide disables the same Quest tracker choices. `/fqp nearest` reports
  that the tracker is unavailable. A gamepad init callback restores Blizzard's
  module immediately, even in combat. Uninit re-enables the saved option out of
  combat.
- `ns.SelectNearestQuest` uses the beta module's `BuildQuestWatchInfos`, so the
  active filter shapes the candidate list. With the beta off it uses Blizzard's
  raw watch list and ignores a saved filter.
- Our module's quest events are unregistered when the beta is turned off and
  registered again when it is turned back on, so a hidden module does not keep
  processing watch-list or turn-in events.
- Registration waits for `QuestObjectiveTracker.uiOrder` and the manager's
  container mapping. If the client is not ready, it retries on a one-second
  timer instead of adding a duplicate module before `ObjectiveTrackerManager.Init`.
- During combat, the standalone module stays active. It no longer lives inside
  Blizzard's tracker container, so its layout does not taint the container or quest
  log when the map places pins. Gamepad activation still restores Blizzard's module
  immediately because leaving our module active would disrupt Blizzard's gamepad
  targeting.
- Quest blocks route Blizzard's `OnBlockHeaderClick` through `CreateSecureDelegate`
  when the client provides it, with a `securecallfunction` fallback. The module
  and blocks are addon frames, so calling the handler directly opens the quest
  log in addon execution and makes the map write the quest log details and scroll
  container fields as `ForeverQuestPins`, which blocks `SetPassThroughButtons` in
  combat. The secure delegate keeps the quest log refresh secure. Zone headers
  shadow the block's `OnHeaderClick` in `AddZoneHeader` so they still toggle
  without putting the module in the quest click path. The module registers its
  standalone container in `ObjectiveTrackerManager.moduleToContainerMap` so
  Blizzard's `GetContextMenuParent` returns it and the right-click menu stays on
  Blizzard's handler too.
- `SpokenTracker.lua` attaches Spoken's Play button to quest blocks when `Spoken`
  and `VoiceOver.QuestOverlayUI` are present. It hooks the module's `AddBlock`,
  sweeps the existing `usedBlocks` when Spoken loads and on
  `VOICE_PACKS_LOADED`, `PART_SWITCHED`, and `UpdateTrackerButtons`, and hides the
  button when `ShowsTrackerButton` is false. It never writes
  `block.rightEdgeOffset`, so the item button's click path stays untouched.

Runtime cases cover grouping, every sort and filter, the current-zone match,
**Other**, missing header and distance APIs, the per-character collapse table,
combat caching, combat retention of the standalone tracker, module registration and
restoration, secure quest-click delegation, gamepad fallback, zone header insertion,
collapse skipping, and the scroll viewport math. In-game checks still cover the
side-by-side look, the header drag, scrolling over every control, animations,
combat, taint, and the gamepad transition.

Known limits: the module relies on Blizzard's tracker internals; if a client patch
renames them, `CanUseQuestTracker` leaves Blizzard's tracker unchanged. Third-party
addons that enumerate tracker blocks by the `quest` tag also see zone header blocks;
those blocks use string IDs and are ignored by normal quest consumers. The standalone
tracker is not part of Blizzard's Edit Mode system, so moving it uses the header drag.
Its height follows the Edit Mode slider, but moving the source frame in Edit Mode does
not move the standalone tracker.

## Quest item sparkles

`Sparkle.lua` keeps the client's native quest item sparkle enabled. It writes one
CVar, `outlineModeShowLootEffectWhenDisabled`. Never read or write
`graphicsOutlineMode`, `outlineMode`, or any other outline CVar: those remove the
player's Self Highlight outline, and earlier sparkle addons were changed for that
reason. The client has one switch for quest items and quest givers, so enabling
the option makes quest givers sparkle too.

- The option is `sparkleQuestItems`, default off, and the setup guide offers it
  on the **Navigation** page. It uses the normal defaults and settings mirror, so
  existing installs keep a saved on value and gain the key only when missing.
- `ns.ApplySparkleSetting` runs at `PLAYER_LOGIN`, again after five seconds, and
  one second after `CVAR_UPDATE` for `graphicsquality` or `raidgraphicsquality`.
  Graphics presets reset the CVar, which is why the delayed reapply exists.
- With the option off, both of those paths leave the CVar alone, so a fresh
  install never writes it and a player who set the sparkle in the game's graphics
  options keeps that choice.
- A write during combat is deferred to `PLAYER_REGEN_ENABLED`.
- Turning the option off calls `ns.DisableSparkleSetting`, which writes `"0"` and
  prints one restart notice per off period. The client keeps drawing sparkles
  until the game restarts; `/reload` does not clear them.
- A missing `C_CVar`, missing `GetCVar`/`SetCVar`, or a missing target CVar makes
  the apply a no-op. `/fqp apis` reports the API and CVar state, and `/fqp
  settings` prints the option.

Runtime cases cover the default and settings migration, the single-CVar
boundary, the delayed graphics reapply, combat deferral, the one-time warning,
and missing-API handling. In-game checks still cover the rendered sparkle, the
unchanged character outline, preset recovery, and the restart requirement.
