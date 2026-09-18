# Changelog

## 0.1.2

- Options for auto-accept and auto-turn in when talking to NPCs
- Settings panel checkboxes; `/fqp accept` and `/fqp turnin` toggles
- Hold Shift to skip automation for one NPC interaction
- Auto-turn in does not pick when a quest has multiple rewards

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
