## 1.1.11 - 2026-11-26

- Fix clicking a tracked quest not opening the quest log. The beta tracker now runs Blizzard's quest click through a secure delegate, so opening the quest log no longer writes the map's quest log and scroll fields as ForeverQuestPins and the map keeps working in combat. `/fqp trackerdebug` reports the active click path.
