package questiedb

import "testing"

func TestResolveAreaFollowsSubZoneParentsAndSuppression(t *testing.T) {
	zones := &Zones{
		AreaToMap:     map[int]int{10: 20, 30: 0},
		SubZoneParent: map[int]int{11: 10, 12: 11, 31: 30},
	}
	if got, ok := zones.ResolveArea(10); !ok || got != 20 {
		t.Fatalf("direct area = %d/%v, want 20/true", got, ok)
	}
	if got, ok := zones.ResolveArea(12); !ok || got != 20 {
		t.Fatalf("nested sub-zone = %d/%v, want 20/true", got, ok)
	}
	if _, ok := zones.ResolveArea(30); ok {
		t.Fatal("zero map entry should suppress the area")
	}
	if _, ok := zones.ResolveArea(31); ok {
		t.Fatal("suppressed parent should suppress its sub-zone")
	}
	if _, ok := zones.ResolveArea(99); ok {
		t.Fatal("unknown area should not resolve")
	}
}

func TestResolveDungeonEntrancesByAreaAndAlias(t *testing.T) {
	zones := &Zones{
		Dungeons: map[int]Dungeon{
			100: {
				ID:        100,
				Name:      "Test Dungeon",
				AltIDs:    []int{101},
				Locations: []Coord{{MapID: 20, X: 30, Y: 40}},
			},
		},
		altToDungeon: map[int]int{101: 100},
	}
	if dungeon, ok := zones.DungeonForArea(101); !ok || dungeon.Name != "Test Dungeon" {
		t.Fatalf("alias lookup = %+v/%v", dungeon, ok)
	}
	entrances := zones.ResolveDungeonEntrances(100)
	if len(entrances) != 1 || entrances[0] != (Coord{MapID: 20, X: 30, Y: 40}) {
		t.Fatalf("entrances = %+v", entrances)
	}
	if entrances := zones.ResolveDungeonEntrances(999); entrances != nil {
		t.Fatalf("unknown dungeon = %+v", entrances)
	}
}
