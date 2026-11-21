## 1.1.2 - 2026-11-21

- Opening the world map in combat no longer shows a blocked-action popup naming this addon. The addon no longer post-hooks Blizzard's map frame or modifies the world map's Show menu, both of which tainted the map layout. The pin filters have their own button on the world map.
- The enhanced quest tracker falls back to Blizzard's flat list when the client refuses a zone header in combat, instead of raising a Lua error.
- Added `/fqp taint` for blocked-action reports.
