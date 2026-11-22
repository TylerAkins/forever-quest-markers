## 1.1.5 - 2026-11-22

- Quest tracking no longer writes Blizzard's waypoint or super-track during combat or another restricted action. That write could taint the map's pin refresh and block `SetPassThroughButtons`. Existing tracking resumes after combat.
