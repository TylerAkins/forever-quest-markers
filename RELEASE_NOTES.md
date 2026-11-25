## 1.1.10 - 2026-11-25

- Fix quest item icons in the beta tracker so clicking an icon uses the item. The row block now handles wheel and hover input without taking clicks, and the interactive controls sit above the reused row.
- Keep the beta tracker's quest item buttons clickable on later clicks and stop the scroll viewport from clipping their 42px item frame. The buttons now stay above the row in combat, cached blocks refresh their quest log index, and the content leaves room above and right for the overhang.
- Drop turned-in quests from the beta tracker. Watched quests that are no longer in the quest log are filtered out, and the tracker refreshes on `QUEST_TURNED_IN` when the custom module's own handler is missing.
- Stop the breadcrumb dialog from abandoning quests from addon code. Selecting a quest there tainted the map's quest log and blocked map pins in combat. The dialog now asks you to abandon from the quest log and sets a waypoint to the skipped breadcrumb when the quest disappears.
- Move the beta tracker into its own frame instead of Blizzard's tracker container. It keeps running during combat, so it no longer reverts to Blizzard's tracker. Drag the **Quests** header to move it.
- Stop quest clicks in the beta tracker from tainting the map. Clicking a tracked quest in combat now opens the quest details without making the map's quest log and scroll container write as ForeverQuestPins, so the map's pins keep working.
- Stop the map pin watcher from touching map state during combat. Opening the map in combat could taint the map's protected pin placement and block `SetPassThroughButtons`.
- Refresh the beta tracker when you accept, update, or remove a quest. A fallback quest event listener now marks the tracker dirty even if the custom module's own event registration is missed.
- Show Spoken's Play button on the beta tracker's quest blocks when Spoken and Spoken_Quests are loaded. The bridge checks for Spoken at runtime and stays out of the way when it is not installed.
- Let the beta tracker follow the Edit Mode height slider. It now fills the source tracker's height instead of shrinking to the content, keeps that viewport when the content is short, and relayouts when the slider changes.
