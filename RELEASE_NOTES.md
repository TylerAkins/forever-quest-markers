## 1.1.8 - 2026-11-23

- Add an optional beta quest tracker module inside Blizzard's tracker. It groups tracked quests by zone, collapses zone headers, sorts by Blizzard order, distance, level, or title, filters the view, and scrolls with the mouse wheel. It uses Blizzard's own quest blocks, item buttons, POI buttons, and Edit Mode. Off by default.
- Keep Blizzard's tracker unchanged while gamepad UI is active, which avoids the gamepad navigation errors that led to the 1.1.7 removal. The beta is disabled in gamepad UI and `/fqp nearest` reports that it is unavailable there.
- Restore `/fqp nearest`, the tracker right-click menu, and **Copy Wowhead URL** for the new module. The first load after this update resets the old beta opt-in once.
- Keep the **Quests** header and its menu reachable when a view filter has no matches, disable the tracker choices in the setup guide while gamepad UI is active, and stop the hidden beta module from handling quest events. The tracker bottom spacing is configurable from 0 to 60px, default 15px.
