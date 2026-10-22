package questdb

import (
	"os"
	"strings"
	"testing"

	"github.com/TylerAkins/forever-quest-markers/internal/questiedb"
	"github.com/TylerAkins/forever-quest-markers/internal/questiepolicy"
)

func TestRaceMaskToRacesAndFaction(t *testing.T) {
	cases := []struct {
		name       string
		mask       uint64
		races      []int
		faction    string
		unknown    uint64
		unrestrict bool
	}{
		{"alliance", 1 | 4 | 8 | 64 | (1 << 32), []int{1, 3, 4, 7, 95}, "Alliance", 0, false},
		{"horde", 2 | 16 | 32 | 128 | (1 << 33), []int{2, 5, 6, 8, 96}, "Horde", 0, false},
		{"both", 1 | 2, []int{1, 2}, "", 0, false},
		{"unrestricted", 0, nil, "", 0, true},
		{"unknown", 1 | 4096, []int{1}, "", 4096, false},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			races, unknown := raceMaskToRaces(test.mask)
			if unknown != test.unknown {
				t.Fatalf("unknown = %d, want %d", unknown, test.unknown)
			}
			if len(races) != len(test.races) {
				t.Fatalf("races = %v, want %v", races, test.races)
			}
			for index := range races {
				if races[index] != test.races[index] {
					t.Fatalf("races = %v, want %v", races, test.races)
				}
			}
			if faction := raceMaskToFaction(test.mask); faction != test.faction {
				t.Fatalf("faction = %q, want %q", faction, test.faction)
			}
		})
	}
}

func TestBuildUsesRequiredLevelForMinimum(t *testing.T) {
	builder := &recordBuilder{
		policy: &questiepolicy.Policy{
			HolidayQuestIDs:  map[int]bool{},
			InstanceQuestIDs: map[int]bool{},
		},
		gaps:      map[int]string{},
		conflicts: map[string]bool{},
	}
	record, err := builder.build(&questiedb.Quest{
		ID:            1145,
		RequiredLevel: 30,
		QuestLevel:    33,
	})
	if err != nil {
		t.Fatal(err)
	}
	if record.MinLevel != 30 {
		t.Fatalf("MinLevel = %d, want required level 30 (QuestLevel is 33)", record.MinLevel)
	}
}

func TestClassMaskToClasses(t *testing.T) {
	classes, unknown := classMaskToClasses(1 | 2 | 4 | 8 | 16 | 64 | 128 | 256 | 1024)
	if unknown != 0 {
		t.Fatalf("unknown = %d", unknown)
	}
	want := []int{1, 2, 3, 4, 5, 7, 8, 9, 11}
	if len(classes) != len(want) {
		t.Fatalf("classes = %v, want %v", classes, want)
	}
	for index := range want {
		if classes[index] != want[index] {
			t.Fatalf("classes = %v, want %v", classes, want)
		}
	}
	if classes, unknown := classMaskToClasses(0); classes != nil || unknown != 0 {
		t.Fatalf("zero mask = %v/%d", classes, unknown)
	}
}

func TestRenderRecordExcludesCoordlessFromByMap(t *testing.T) {
	records := []Record{
		{QuestID: 1, Title: "Coordless", TurnIns: []int{100}},
		{QuestID: 2, Title: "Pinned", Coords: []questiedb.Coord{{MapID: 10, X: 20, Y: 30}}, QG: 5},
	}
	output := string(renderQuests(records, Metadata{}))
	if !strings.Contains(output, "[1] = { turnIns={ 100 }, title=\"Coordless\" }") {
		t.Fatalf("coordless record missing:\n%s", output)
	}
	byMap := output[strings.Index(output, "ns.ByMap"):]
	if strings.Contains(byMap, "[1] = {") {
		t.Fatalf("coordless quest leaked into ByMap:\n%s", byMap)
	}
	if !strings.Contains(byMap, "[10] = { 2 }") {
		t.Fatalf("pinned quest missing from ByMap:\n%s", byMap)
	}
}

func TestRenderRecordFieldOrder(t *testing.T) {
	record := Record{
		QuestID:                7,
		Coords:                 []questiedb.Coord{{MapID: 10, X: 1.25, Y: 2.5}, {MapID: 11, X: 3, Y: 4}},
		QG:                     5,
		QGs:                    []int{5, 6},
		TurnIns:                []int{8},
		TurnInObjects:          []int{9},
		SourceQuestGroup:       []int{10},
		SourceQuestSingle:      []int{11, 12},
		SourceQuestNumRequired: 1,
		AltQuests:              []int{13},
		Races:                  []int{1},
		Faction:                "Alliance",
		MinLevel:               20,
		IsYearly:               true,
		Repeatable:             true,
		IsMonthly:              true,
		IsBreadcrumb:           true,
		IsInstanceQuest:        true,
		Title:                  `A "quoted" quest`,
	}
	got := renderRecord(record)
	for _, needle := range []string{
		`mapID=10, x=1.25, y=2.5`,
		`coords={ { 3, 4, 11 } }`,
		`qg=5`,
		`qgs={ 5, 6 }`,
		`turnIns={ 8 }`,
		`turnInObjects={ 9 }`,
		`sourceQuestGroup={ 10 }`,
		`sourceQuestSingle={ 11, 12 }, sourceQuestNumRequired=1`,
		`altQuests={ 13 }`,
		`races={ 1 }`,
		`faction="Alliance"`,
		`minLevel=20`,
		`isYearly=true`,
		`repeatable=true`,
		`isMonthly=true`,
		`isBreadcrumb=true`,
		`isInstanceQuest=true`,
		`title="A \"quoted\" quest"`,
	} {
		if !strings.Contains(got, needle) {
			t.Errorf("record missing %q:\n%s", needle, got)
		}
	}
}

func TestParseBaselineRowsAndFlags(t *testing.T) {
	root := t.TempDir() + "/baseline.lua"
	source := `local ADDON_NAME, ns = ...
ns.Quests = {
	[5] = { mapID=1431, x=18.2, y=56.3, coords={ { 20, 30, 1431 } }, qg=288, isYearly=true, isBreadcrumb=true },
	[6] = { qg=823 },
}
ns.ByMap = {
	[1431] = { 5 },
}
`
	if err := os.WriteFile(root, []byte(source), 0o644); err != nil {
		t.Fatal(err)
	}
	quests, err := parseBaseline(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(quests) != 2 {
		t.Fatalf("quests = %d, want 2", len(quests))
	}
	if !quests[5].HasCoord || quests[5].CoordCount != 2 || !quests[5].Flags["isYearly"] || !quests[5].Flags["isBreadcrumb"] {
		t.Fatalf("quest 5 = %+v", quests[5])
	}
	if quests[6].HasCoord {
		t.Fatal("quest 6 should be coordless")
	}
}

func TestRoundCoordinate(t *testing.T) {
	if got := roundCoordinate(18.376); got != 18.38 {
		t.Fatalf("got %v", got)
	}
}
