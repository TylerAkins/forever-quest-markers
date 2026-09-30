## 0.1.52 - 2026-09-30

- Stop using `HookScript` on `WorldMapFrame` for quest pin show, resize, and live snap; watch the map from the addon frame instead to reduce Edit Mode layout taint risk.
- Refine that watcher with `hooksecurefunc` Show/Hide, resize checks on the map frame, scroll container, detail frame, and canvas, and `OnUpdate` only while the world map is open.
