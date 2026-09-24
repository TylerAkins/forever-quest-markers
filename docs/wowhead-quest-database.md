# Wowhead Forever quest database

This document is the human-readable index for our Wowhead-sourced quest database. The machine-readable copy of the source URLs lives in `tools/wowhead_db/sources.py` and `data/wowhead/manifest.json`.

**Last checked for changes:** see `data/wowhead/manifest.json` → `lastCheckedForChanges`.

## Why

We are moving away from [All The Things](https://github.com/ATTWoWAddon/AllTheThings) as the primary data source so we can:

- Own schema and fix tooltip / pin edge cases
- Share one database with **forever-guide-mate**
- Classify PvP, repeatable, dungeon/instance, attunement, and (future) raid quests explicitly

Addon cutover is **not** part of this work; see `docs/WOWHEAD_DATABASE_CUTOVER.md`.

## Pin categories

| Category | Color | Notes |
|----------|-------|--------|
| Normal | Yellow (`QuestNormal`) | Default |
| Repeatable | Blue tint | Same as today |
| Dungeon / instance / attunement | Orange tint | Same as today |
| **PvP** | **Purple tint** `(0.78, 0.22, 0.95)` | New; battleground index + Wowhead type 41 |
| Raid | Orange (reserved) | Only Onyxia's Lair in Forever for now |

Full values: `data/wowhead/pin_categories.json`.

## Wowhead index URLs

### Objects

- https://www.wowhead.com/forever/objects/quests

### Eastern Kingdoms

- https://www.wowhead.com/forever/quests/eastern-kingdoms/alterac-mountains
- https://www.wowhead.com/forever/quests/eastern-kingdoms/alterac-valley
- https://www.wowhead.com/forever/quests/eastern-kingdoms/anvilmar
- https://www.wowhead.com/forever/quests/eastern-kingdoms/arathi-highlands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/badlands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/blackrock-mountain
- https://www.wowhead.com/forever/quests/eastern-kingdoms/blasted-lands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/burning-steppes
- https://www.wowhead.com/forever/quests/eastern-kingdoms/crafting
- https://www.wowhead.com/forever/quests/eastern-kingdoms/deeprun-tram
- https://www.wowhead.com/forever/quests/eastern-kingdoms/dun-morogh
- https://www.wowhead.com/forever/quests/eastern-kingdoms/duskwood
- https://www.wowhead.com/forever/quests/eastern-kingdoms/eastern-plaguelands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/elwynn-forest
- https://www.wowhead.com/forever/quests/eastern-kingdoms/hillsbrad-foothills
- https://www.wowhead.com/forever/quests/eastern-kingdoms/ironforge
- https://www.wowhead.com/forever/quests/eastern-kingdoms/kharanos
- https://www.wowhead.com/forever/quests/eastern-kingdoms/loch-modan
- https://www.wowhead.com/forever/quests/eastern-kingdoms/redridge-mountains
- https://www.wowhead.com/forever/quests/eastern-kingdoms/riverglades
- https://www.wowhead.com/forever/quests/eastern-kingdoms/searing-gorge
- https://www.wowhead.com/forever/quests/eastern-kingdoms/shadowfang-keep
- https://www.wowhead.com/forever/quests/eastern-kingdoms/silverpine-forest
- https://www.wowhead.com/forever/quests/eastern-kingdoms/stormwind-city
- https://www.wowhead.com/forever/quests/eastern-kingdoms/stonewrought-dam
- https://www.wowhead.com/forever/quests/eastern-kingdoms/stranglethorn-vale
- https://www.wowhead.com/forever/quests/eastern-kingdoms/swamp-of-sorrows
- https://www.wowhead.com/forever/quests/eastern-kingdoms/the-hinterlands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/thoradins-wall
- https://www.wowhead.com/forever/quests/eastern-kingdoms/tirisfal-glades
- https://www.wowhead.com/forever/quests/eastern-kingdoms/undercity
- https://www.wowhead.com/forever/quests/eastern-kingdoms/western-plaguelands
- https://www.wowhead.com/forever/quests/eastern-kingdoms/westfall
- https://www.wowhead.com/forever/quests/eastern-kingdoms/wetlands

### Kalimdor

- https://www.wowhead.com/forever/quests/kalimdor/abyssal-sands
- https://www.wowhead.com/forever/quests/kalimdor/ashenvale
- https://www.wowhead.com/forever/quests/kalimdor/azshara
- https://www.wowhead.com/forever/quests/kalimdor/blackmaw-hold
- https://www.wowhead.com/forever/quests/kalimdor/darkshore
- https://www.wowhead.com/forever/quests/kalimdor/darnassus
- https://www.wowhead.com/forever/quests/kalimdor/desolace
- https://www.wowhead.com/forever/quests/kalimdor/durotar
- https://www.wowhead.com/forever/quests/kalimdor/dustwallow-marsh
- https://www.wowhead.com/forever/quests/kalimdor/felwood
- https://www.wowhead.com/forever/quests/kalimdor/feralas
- https://www.wowhead.com/forever/quests/kalimdor/field-of-giants
- https://www.wowhead.com/forever/quests/kalimdor/moonglade
- https://www.wowhead.com/forever/quests/kalimdor/mulgore
- https://www.wowhead.com/forever/quests/kalimdor/orgrimmar
- https://www.wowhead.com/forever/quests/kalimdor/ruttheran-village
- https://www.wowhead.com/forever/quests/kalimdor/silithus
- https://www.wowhead.com/forever/quests/kalimdor/stonetalon-mountains
- https://www.wowhead.com/forever/quests/kalimdor/tanaris
- https://www.wowhead.com/forever/quests/kalimdor/teldrassil
- https://www.wowhead.com/forever/quests/kalimdor/the-barrens
- https://www.wowhead.com/forever/quests/kalimdor/thousand-needles
- https://www.wowhead.com/forever/quests/kalimdor/thunder-bluff
- https://www.wowhead.com/forever/quests/kalimdor/ungoro-crater
- https://www.wowhead.com/forever/quests/kalimdor/winterspring

### Classes

- https://www.wowhead.com/forever/quests/classes/druid
- https://www.wowhead.com/forever/quests/classes/hunter
- https://www.wowhead.com/forever/quests/classes/mage
- https://www.wowhead.com/forever/quests/classes/paladin
- https://www.wowhead.com/forever/quests/classes/priest
- https://www.wowhead.com/forever/quests/classes/rogue
- https://www.wowhead.com/forever/quests/classes/shaman
- https://www.wowhead.com/forever/quests/classes/warlock
- https://www.wowhead.com/forever/quests/classes/warrior

### Dungeons

- https://www.wowhead.com/forever/quests/dungeons/blackfathom-deeps
- https://www.wowhead.com/forever/quests/dungeons/blackrock-depths
- https://www.wowhead.com/forever/quests/dungeons/blackrock-spire
- https://www.wowhead.com/forever/quests/dungeons/dire-maul
- https://www.wowhead.com/forever/quests/dungeons/gnomeregan
- https://www.wowhead.com/forever/quests/dungeons/maraudon
- https://www.wowhead.com/forever/quests/dungeons/ragefire-chasm
- https://www.wowhead.com/forever/quests/dungeons/razorfen-downs
- https://www.wowhead.com/forever/quests/dungeons/razorfen-kraul
- https://www.wowhead.com/forever/quests/dungeons/ruins-of-lordaeron
- https://www.wowhead.com/forever/quests/dungeons/scarlet-monastery
- https://www.wowhead.com/forever/quests/dungeons/scholomance
- https://www.wowhead.com/forever/quests/dungeons/shadowfang-keep
- https://www.wowhead.com/forever/quests/dungeons/stratholme
- https://www.wowhead.com/forever/quests/dungeons/the-deadmines
- https://www.wowhead.com/forever/quests/dungeons/the-hall-of-thanes
- https://www.wowhead.com/forever/quests/dungeons/the-stockade
- https://www.wowhead.com/forever/quests/dungeons/the-temple-of-atalhakkar
- https://www.wowhead.com/forever/quests/dungeons/uldaman
- https://www.wowhead.com/forever/quests/dungeons/wailing-caverns
- https://www.wowhead.com/forever/quests/dungeons/zulfarrak

### Raids

- https://www.wowhead.com/forever/quests/raids/onyxias-lair *(only Forever raid with quests today)*

### World events

- https://www.wowhead.com/forever/quests/world-events/childrens-week
- https://www.wowhead.com/forever/quests/world-events/darkmoon-faire
- https://www.wowhead.com/forever/quests/world-events/hallows-end
- https://www.wowhead.com/forever/quests/world-events/love-is-in-the-air
- https://www.wowhead.com/forever/quests/world-events/lunar-festival
- https://www.wowhead.com/forever/quests/world-events/midsummer
- https://www.wowhead.com/forever/quests/world-events/winter-veil

### Professions

- https://www.wowhead.com/forever/quests/professions/alchemy
- https://www.wowhead.com/forever/quests/professions/blacksmithing
- https://www.wowhead.com/forever/quests/professions/cooking
- https://www.wowhead.com/forever/quests/professions/engineering
- https://www.wowhead.com/forever/quests/professions/first-aid
- https://www.wowhead.com/forever/quests/professions/fishing
- https://www.wowhead.com/forever/quests/professions/herbalism
- https://www.wowhead.com/forever/quests/professions/leatherworking
- https://www.wowhead.com/forever/quests/professions/tailoring

### Other

- https://www.wowhead.com/forever/quests/uncategorized

### Battlegrounds (PvP)

- https://www.wowhead.com/forever/quests/battlegrounds/alterac-valley
- https://www.wowhead.com/forever/quests/battlegrounds/arathi-basin
- https://www.wowhead.com/forever/quests/battlegrounds/warsong-gulch

## How we scan (paste URL)

You paste a Wowhead link; **the agent** runs:

```bash
python3 tools/build_wowhead_db.py ingest --url '<pasted url>' --delay 1.5
```

No manual fetching on your side. The agent waits ~1.5s between Wowhead requests.

**Objects:** [objects/quests](https://www.wowhead.com/forever/objects/quests) uses Wowhead’s JSON listview (not the quest Listview). Ingest writes `object_index.json`.

Bulk `sync-sources` / `sync-quests` are optional; default is agent `ingest` per pasted URL.

## Tooling

- `tools/build_wowhead_db.py` — `ingest` (primary), `sync-*` (bulk)
- `tools/wowhead_db/` — parsers, classifier, ingest
- Agent skill: `docs/skills/wowhead-quest-database/SKILL.md`
