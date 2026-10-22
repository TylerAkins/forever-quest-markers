package questiedb

import (
	"fmt"
	"sort"
)

// Coord is a quest marker in Questie's 0-100 UI-map space.
type Coord struct {
	MapID int
	X     float64
	Y     float64
}

// Dungeon is one Forever dungeon-entrance record from QuestieDB.
type Dungeon struct {
	ID        int
	Name      string
	AltIDs    []int
	Parent    int
	Locations []Coord
}

// Zones holds QuestieDB's Forever area, sub-zone, and dungeon tables.
type Zones struct {
	AreaToMap     map[int]int
	SubZoneParent map[int]int
	Dungeons      map[int]Dungeon
	altToDungeon  map[int]int
}

// LoadZones reads and merges QuestieDB's Forever zone support tables.
func LoadZones(artifact *Artifact) (*Zones, error) {
	zones := &Zones{
		AreaToMap:     map[int]int{},
		SubZoneParent: map[int]int{},
		Dungeons:      map[int]Dungeon{},
		altToDungeon:  map[int]int{},
	}
	if err := zones.loadAreaMap(artifact); err != nil {
		return nil, err
	}
	if err := zones.loadSubZones(artifact); err != nil {
		return nil, err
	}
	if err := zones.loadDungeons(artifact); err != nil {
		return nil, err
	}
	return zones, nil
}

func (zones *Zones) loadAreaMap(artifact *Artifact) error {
	source, err := artifact.ReadZoneSource("areaIdToUiMapId.lua")
	if err != nil {
		return err
	}
	base, err := ParseLuaLongStringTable(source, "areaIdToUiMapId", nil)
	if err != nil {
		return fmt.Errorf("parse areaIdToUiMapId: %w", err)
	}
	override, err := ParseLuaLongStringTable(source, "areaIdToUiMapIdOverride", nil)
	if err != nil {
		return fmt.Errorf("parse areaIdToUiMapIdOverride: %w", err)
	}
	for key, value := range base.Numbers {
		mapID, ok := Int(value)
		if !ok {
			return fmt.Errorf("areaIdToUiMapId[%d] is %T, not an integer", key, value)
		}
		zones.AreaToMap[key] = mapID
	}
	for key, value := range override.Numbers {
		mapID, ok := Int(value)
		if !ok {
			return fmt.Errorf("areaIdToUiMapIdOverride[%d] is %T, not an integer", key, value)
		}
		zones.AreaToMap[key] = mapID
	}
	return nil
}

func (zones *Zones) loadSubZones(artifact *Artifact) error {
	source, err := artifact.ReadZoneSource("subZoneToParentZone.lua")
	if err != nil {
		return err
	}
	base, err := ParseLuaLongStringTable(source, "subZoneToParentZone", nil)
	if err != nil {
		return fmt.Errorf("parse subZoneToParentZone: %w", err)
	}
	override, err := ParseLuaLongStringTable(source, "subZoneToParentZoneOverride", nil)
	if err != nil {
		return fmt.Errorf("parse subZoneToParentZoneOverride: %w", err)
	}
	for key, value := range base.Numbers {
		parent, ok := Int(value)
		if !ok {
			return fmt.Errorf("subZoneToParentZone[%d] is %T, not an integer", key, value)
		}
		zones.SubZoneParent[key] = parent
	}
	for key, value := range override.Numbers {
		parent, ok := Int(value)
		if !ok {
			return fmt.Errorf("subZoneToParentZoneOverride[%d] is %T, not an integer", key, value)
		}
		zones.SubZoneParent[key] = parent
	}
	return nil
}

func (zones *Zones) loadDungeons(artifact *Artifact) error {
	source, err := artifact.ReadZoneSource("dungeons.lua")
	if err != nil {
		return err
	}
	table, err := ParseLuaTableAssignment(source, "dungeons", map[string]any{"isHorde": false})
	if err != nil {
		return fmt.Errorf("parse dungeons: %w", err)
	}
	for _, id := range table.IntKeys() {
		value, ok := table.Numbers[id].(*LuaTable)
		if !ok {
			return fmt.Errorf("dungeons[%d] is %T, not a table", id, table.Numbers[id])
		}
		dungeon := Dungeon{ID: id}
		dungeon.Name, _ = value.Get(1).(string)
		dungeon.AltIDs = Ints(value.Get(2))
		dungeon.Parent = intValue(value.Get(3))
		locations, _ := value.Get(4).(*LuaTable)
		if locations != nil {
			for _, locationKey := range locations.IntKeys() {
				coords, ok := locations.Numbers[locationKey].(*LuaTable)
				if !ok {
					return fmt.Errorf("dungeons[%d] location %d is not a table", id, locationKey)
				}
				area := intValue(coords.Get(1))
				x, okX := Float(coords.Get(2))
				y, okY := Float(coords.Get(3))
				if !okX || !okY {
					return fmt.Errorf("dungeons[%d] location %d has invalid coordinates", id, locationKey)
				}
				mapID, ok := zones.ResolveArea(area)
				if !ok {
					continue
				}
				dungeon.Locations = append(dungeon.Locations, Coord{MapID: mapID, X: x, Y: y})
			}
		}
		sort.Slice(dungeon.Locations, func(i, j int) bool {
			left, right := dungeon.Locations[i], dungeon.Locations[j]
			if left.MapID != right.MapID {
				return left.MapID < right.MapID
			}
			if left.X != right.X {
				return left.X < right.X
			}
			return left.Y < right.Y
		})
		zones.Dungeons[id] = dungeon
		for _, alt := range dungeon.AltIDs {
			if _, exists := zones.altToDungeon[alt]; !exists {
				zones.altToDungeon[alt] = id
			}
		}
	}
	return nil
}

// ResolveArea maps an AreaTable ID to a UI map ID, following sub-zone parents
// only when the area has no direct entry. A direct 0 entry is Questie's
// display-suppression marker and resolves to false.
func (zones *Zones) ResolveArea(area int) (int, bool) {
	seen := map[int]bool{}
	for area > 0 && !seen[area] {
		if mapID, ok := zones.AreaToMap[area]; ok {
			if mapID <= 0 {
				return 0, false
			}
			return mapID, true
		}
		seen[area] = true
		parent, ok := zones.SubZoneParent[area]
		if !ok || parent == area || parent <= 0 {
			return 0, false
		}
		area = parent
	}
	return 0, false
}

// DungeonForArea returns the dungeon record for a dungeon area or alias.
func (zones *Zones) DungeonForArea(area int) (Dungeon, bool) {
	if dungeon, ok := zones.Dungeons[area]; ok {
		return dungeon, true
	}
	id, ok := zones.altToDungeon[area]
	if !ok {
		return Dungeon{}, false
	}
	dungeon, ok := zones.Dungeons[id]
	return dungeon, ok
}

// ResolveDungeonEntrances returns open-world entrance coordinates for a
// dungeon area. Entrances already carry resolved UI map IDs.
func (zones *Zones) ResolveDungeonEntrances(area int) []Coord {
	dungeon, ok := zones.DungeonForArea(area)
	if !ok {
		return nil
	}
	result := make([]Coord, len(dungeon.Locations))
	copy(result, dungeon.Locations)
	return result
}
