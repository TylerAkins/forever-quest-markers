## 1.1.2 - 2026-11-21

- Opening the world map in combat no longer shows a blocked-action popup from the addon's map hooks or filter menu. The addon no longer post-hooks Blizzard's map frame or modifies the world map's Show menu, both of which tainted the map layout. The pin filters have their own button on the world map.
- The skipped-breadcrumb **Abandon Quest** action stays, with a known cost: it selects the quest in your log from addon code, so using it can make the map report a blocked action in combat until you reload. Abandon from the quest log to avoid it.
- The enhanced quest tracker falls back to Blizzard's flat list when the client refuses a zone header in combat, instead of raising a Lua error.
- Added `/fqp taint` for blocked-action reports.
