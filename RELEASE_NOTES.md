## 0.1.25 - 2026-09-20

- Fix invisible quest-start icons by registering pins with Blizzard's managed map system. Keep the native yellow, blue, and red-orange icon style.
- Show complete ATT-derived dungeon and raid attunement chains with red-orange `!` pins.
- Synchronize revisioned account and character settings and flush them on logout. Forever's client-side SavedVariables loading bug still requires the optional local repair described in the README; installing this release alone does not repair that client bug.
- Regenerate ATT data at `5b09b3adf6816fcf95acef09251169e5ae97e80e`, including faction-specific quest wrappers: 3665 quests, 3925 coordinate pins, 49 maps, and 27 attunement quests.
