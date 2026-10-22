package questiedb

import (
	"testing"
	"testing/fstest"
)

func TestParseLuaExpressionConditionalTable(t *testing.T) {
	vars := map[string]any{
		"Expansions.Current": 1,
		"Expansions.Era":     1,
		"Expansions.Wotlk":   3,
	}
	value, err := ParseLuaExpression(`(Expansions.Current == Expansions.Era and {1, l10n("Elite")}) or nil`, vars)
	if err != nil {
		t.Fatal(err)
	}
	table, ok := value.(*LuaTable)
	if !ok {
		t.Fatalf("got %T, want LuaTable", value)
	}
	if got, _ := Int(table.Get(1)); got != 1 {
		t.Fatalf("tag id = %d, want 1", got)
	}
	if got, _ := table.Get(2).(string); got != "Elite" {
		t.Fatalf("tag name = %q, want Elite", got)
	}
}

func TestParseLuaExpressionUnknownSyntaxFails(t *testing.T) {
	if _, err := ParseLuaExpression(`{1, mystery(2)}`, map[string]any{}); err == nil {
		t.Fatal("expected unknown function to fail")
	}
	if _, err := ParseLuaExpression(`{1, 2`, map[string]any{}); err == nil {
		t.Fatal("expected unterminated table to fail")
	}
}

func TestParseLuaLongStringTable(t *testing.T) {
	source := "local areaIdToUiMapId = [[\nreturn {\n  [10] = 20,\n  [30] = 40,\n}\n]]\n"
	table, err := ParseLuaLongStringTable(source, "areaIdToUiMapId", nil)
	if err != nil {
		t.Fatal(err)
	}
	if got, _ := Int(table.Numbers[10]); got != 20 {
		t.Fatalf("area 10 = %d, want 20", got)
	}
}

func TestStripLuaComments(t *testing.T) {
	source := "local a = 1 -- comment\n--[[ block\ncomment ]]\nlocal b = 2\n"
	got := StripLuaComments(source)
	if got != "local a = 1 \n\nlocal b = 2\n" {
		t.Fatalf("stripped source = %q", got)
	}
}

func TestFindTOCInNestedDirectory(t *testing.T) {
	fsys := fstest.MapFS{
		"QuestieDB/QuestieDB_Forever.toc": &fstest.MapFile{Data: []byte("## Version: 1\n")},
	}
	path, err := findTOC(fsys)
	if err != nil {
		t.Fatal(err)
	}
	if path != "QuestieDB/QuestieDB_Forever.toc" {
		t.Fatalf("path = %q", path)
	}
}

func TestReadMetadataAndChunkReassembly(t *testing.T) {
	toc := "## Version: 1.0\n## X-Contract-Version: 4\n## X-Flavor: Forever\n## X-BUILD-COMMIT: abc\n## X-Test: ~2~\n## X-Test-1: abc\n## X-Test-2: def\n"
	fsys := fstest.MapFS{
		"QuestieDB/QuestieDB_Forever.toc": &fstest.MapFile{Data: []byte(toc)},
	}
	artifact := &Artifact{fsys: fsys, Metadata: map[string]string{}, ids: map[string][]int{}, idsLoaded: map[string]bool{}, idSets: map[string]map[int]bool{}, scalars: map[string]any{}, quests: map[int]*Quest{}, npcs: map[int]*NPC{}, objects: map[int]*Object{}, items: map[int]*Item{}}
	if err := artifact.readMetadata("QuestieDB/QuestieDB_Forever.toc"); err != nil {
		t.Fatal(err)
	}
	if err := artifact.validate(); err != nil {
		t.Fatal(err)
	}
	value, err := artifact.stored("X-Test")
	if err != nil {
		t.Fatal(err)
	}
	if value != "abcdef" {
		t.Fatalf("chunked value = %q, want abcdef", value)
	}
	if _, err := artifact.stored("X-Missing"); err == nil {
		t.Fatal("expected missing metadata to fail")
	}
}

func TestArtifactRejectsWrongContractVersion(t *testing.T) {
	toc := "## X-Contract-Version: 3\n## X-Flavor: Forever\n## X-BUILD-COMMIT: abc\n"
	artifact := &Artifact{Metadata: map[string]string{}}
	for _, line := range []string{"X-Contract-Version", "X-Flavor", "X-BUILD-COMMIT"} {
		_ = line
	}
	artifact.Metadata["X-Contract-Version"] = "3"
	artifact.Metadata["X-Flavor"] = "Forever"
	artifact.Metadata["X-BUILD-COMMIT"] = "abc"
	_ = toc
	if err := artifact.validate(); err == nil {
		t.Fatal("expected wrong contract version to fail")
	}
}

func TestParseSpawnsListAndMapForms(t *testing.T) {
	list := []any{[]any{[]any{float64(1), float64(2)}, []any{float64(3), float64(4)}}}
	spawns := parseSpawns(list)
	if len(spawns) != 2 || spawns[0].Zone != 1 || spawns[1].X != 3 {
		t.Fatalf("list spawns = %+v", spawns)
	}
	mapped := map[any]any{10: []any{[]any{float64(5), float64(6)}}}
	spawns = parseSpawns(mapped)
	if len(spawns) != 1 || spawns[0].Zone != 10 || spawns[0].X != 5 {
		t.Fatalf("map spawns = %+v", spawns)
	}
}

func TestParseWaypointsUsesFirstPathPoint(t *testing.T) {
	value := map[any]any{10: []any{
		[]any{[]any{float64(1), float64(2)}, []any{float64(3), float64(4)}},
		[]any{[]any{float64(5), float64(6)}},
	}}
	waypoints := parseWaypoints(value)
	if len(waypoints) != 1 || waypoints[0].Zone != 10 || waypoints[0].X != 1 || waypoints[0].Y != 2 {
		t.Fatalf("waypoints = %+v", waypoints)
	}
}

func TestParseIDGroupsMapsStartedAndFinishedShapes(t *testing.T) {
	started := map[any]any{
		1: []any{10, 11},
		2: []any{20},
		3: []any{30, 31},
	}
	groups := parseIDGroups(started, 3)
	if len(groups.NPCs) != 2 || groups.NPCs[0] != 10 || groups.NPCs[1] != 11 {
		t.Fatalf("started NPCs = %v", groups.NPCs)
	}
	if len(groups.Objects) != 1 || groups.Objects[0] != 20 {
		t.Fatalf("started objects = %v", groups.Objects)
	}
	if len(groups.Items) != 2 || groups.Items[0] != 30 || groups.Items[1] != 31 {
		t.Fatalf("started items = %v", groups.Items)
	}

	finished := map[any]any{
		1: []any{40},
		2: []any{50, 51},
	}
	groups = parseIDGroups(finished, 2)
	if len(groups.NPCs) != 1 || groups.NPCs[0] != 40 {
		t.Fatalf("finished NPCs = %v", groups.NPCs)
	}
	if len(groups.Objects) != 2 || groups.Objects[0] != 50 || groups.Objects[1] != 51 {
		t.Fatalf("finished objects = %v", groups.Objects)
	}
	if len(groups.Items) != 0 {
		t.Fatalf("finished items = %v, want none", groups.Items)
	}
}

func TestStringValueAcceptsBytes(t *testing.T) {
	if got := stringValue([]byte("Sharptalon's Claw")); got != "Sharptalon's Claw" {
		t.Fatalf("stringValue = %q", got)
	}
}
