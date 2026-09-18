# Changelog

## 0.1.4

- Keep windowed and maximized map pins on the map art (A Sacred Burial at Red Rocks)
- Stack overlapping starts onto one bang so Morin Cloudstalker’s two follow-ups show as one pin with both names
- Project live NPC positions from continent coords onto the zone map
- Treat `GetQuestsCompleted` as a fallback so object-started prereqs (the Ravaged Caravan crate) can unlock follow-ups

## 0.1.3

- Keep quest bangs a fixed screen size (do not inherit map zoom or the native QuestNormal atlas size)
- Draw pins above map tiles so they cannot disappear under the zone art
- Stop dropping a pin when the first layout pass has no canvas size yet

## 0.1.2

- Options for auto-accept and auto-turn in when talking to NPCs
- Settings panel checkboxes; `/fqp accept` and `/fqp turnin` toggles
- Hold Shift to skip automation for one NPC interaction
- Auto-turn in does not pick when a quest has multiple rewards
- Debug checkbox in options; tooltips show quest and NPC names, with IDs only when debug is on
- Prefetch quest titles so names are ready before the first hover
- Place pins on the map canvas (`WorldMapFrame:GetCanvas` / `ScrollContainer.Child`) so they stay on coordinates when the map is resized or reopened
- Snap wandering quest-giver pins (for example Morin Cloudstalker / Ravaged Caravan) to the NPC while they are visible
- Keep pins glued to the map art: same parent as Blizzard's player/quest pins, `SetPinPosition` when available, and re-apply coordinates every frame so resize/reopen cannot drift

## 0.1.1

- Use Blizzard’s retail available-quest icon (`QuestNormal`) on map pins
- Fall back to `Interface\GossipFrame\AvailableQuestIcon`, then the bundled TGA
- Fill unmigrated zones from ATT `zzOLD`, keeping classic (pre-Cata) quests
- Hide Lunar Festival / other seasonal pins unless `/fqp seasonal` is on or the event is active
- Project zone pins onto continent maps even when child-map APIs are missing

## 0.1.0

- Initial Forever Quest Pins release
- Native world-map start markers for unaccepted quests
- ATT Forever database converter and automated update workflow
