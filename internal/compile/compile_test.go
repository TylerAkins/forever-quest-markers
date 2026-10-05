package compile

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const databaseCommit = "fc16119debb3b76a3ad9cf59c64b91f213924d9a"
const exportCommit = "9d39232dab48e35811a7cc02473c2f4e42b62ab6"

func TestTranslatesElwynnSpawnIntoUiMapCoordinates(t *testing.T) {
	lua := compileOne(t, questJSON(123, `"places":[{"role":"available","type":"npc","id":448,"spawns":[[12,25.02,92.9]]}]`))
	if !strings.Contains(lua, "[123] = { mapID=1429, x=25.02, y=92.9, qg=448 }") {
		t.Fatalf("elwynn line missing:\n%s", lua)
	}
	if strings.Contains(lua, "databaseCommit") {
		t.Fatal("ForeverQuests.lua embeds the commit")
	}
}

func TestDropsNegativeAndObjectiveSpawns(t *testing.T) {
	lua := compileOne(t, questJSON(10, `
		"startedBy":[{"type":"npc","id":1}],
		"places":[
			{"role":"available","type":"npc","id":1,"spawns":[[12,-1,-1]]},
			{"role":"objective","type":"object","id":9,"spawns":[[12,10,20]]}
		]`))
	if strings.Contains(lua, "mapID=") {
		t.Fatalf("negative and objective spawns became a pin:\n%s", lua)
	}
	if !strings.Contains(lua, "[10] = { qg=1 }") {
		t.Fatalf("tooltip starter missing:\n%s", lua)
	}
}

func TestUnverifiedZoneEmitsNoCoordinate(t *testing.T) {
	lua := compileOne(t, questJSON(11, `
		"startedBy":[{"type":"npc","id":4}],
		"places":[{"role":"available","type":"npc","id":4,"spawns":[[28,10,20]]}]`))
	if strings.Contains(lua, "mapID=") {
		t.Fatalf("unverified zone became a pin:\n%s", lua)
	}
}

func TestUnknownZoneFails(t *testing.T) {
	_, err := compileFixture(t, questJSON(12, `
		"places":[{"role":"available","type":"npc","id":1,"spawns":[[99999,10,20]]}]`))
	if err == nil || !strings.Contains(err.Error(), "unknown zone 99999") {
		t.Fatalf("error = %v", err)
	}
}

func TestBothPrereqListsFail(t *testing.T) {
	_, err := compileFixture(t, questJSON(13, `"preQuestGroup":[1],"preQuestSingle":[2]`))
	if err == nil || !strings.Contains(err.Error(), "both set") {
		t.Fatalf("error = %v", err)
	}
}

func TestPrereqGroupIsAndAndSingleIsOr(t *testing.T) {
	group := compileOne(t, questJSON(14, `"preQuestGroup":[2,1]`))
	if !strings.Contains(group, "sourceQuests={ 1, 2 }") || strings.Contains(group, "sourceQuestNumRequired") {
		t.Fatalf("group prereq:\n%s", group)
	}
	single := compileOne(t, questJSON(15, `"preQuestSingle":[8,3]`))
	if !strings.Contains(single, "sourceQuests={ 3, 8 }, sourceQuestNumRequired=1") {
		t.Fatalf("single prereq:\n%s", single)
	}
}

func TestFactionRacesClassesAndSkill(t *testing.T) {
	both := compileOne(t, questJSON(16, `"faction":"Both"`))
	if strings.Contains(both, "faction=") {
		t.Fatalf("Both faction was stored:\n%s", both)
	}
	restricted := compileOne(t, questJSON(90, `
		"faction":"Horde",
		"requiredRaces":[5,2],
		"requiredClasses":[11],
		"requiredSkill":{"skillId":185,"value":50}`))
	want := `faction="Horde", races={ 2, 5 }, classes={ 11 }, requireSkill=185`
	if !strings.Contains(restricted, want) || strings.Contains(restricted, "50") {
		t.Fatalf("restrictions:\n%s", restricted)
	}
}

func TestFlagsAndTurnIns(t *testing.T) {
	normal := compileOne(t, questJSON(155, `
		"finishedBy":[{"type":"npc","id":234}],
		"questType":{"event":true,"repeatable":false}`))
	if strings.Contains(normal, "isYearly") {
		t.Fatalf("quest 155 marked seasonal:\n%s", normal)
	}
	if !strings.Contains(normal, "turnIns={ 234 }") {
		t.Fatalf("turn-in missing:\n%s", normal)
	}

	holiday := compileOne(t, questJSON(8673, `"questType":{"sort":"LUNAR_FESTIVAL","event":true}`))
	if !strings.Contains(holiday, "isYearly=true") {
		t.Fatalf("holiday:\n%s", holiday)
	}

	war := compileOne(t, questJSON(8780, `"questType":{"sort":"AHN_QIRAJ_WAR"}`))
	if !strings.Contains(war, "isWarEffort=true") {
		t.Fatalf("war effort:\n%s", war)
	}

	raid := compileOne(t, questJSON(7761, `"questType":{"raid":true}`))
	if !strings.Contains(raid, "isInstanceQuest=true") || strings.Contains(raid, "isAttunement") {
		t.Fatalf("raid:\n%s", raid)
	}

	daily := compileOne(t, questJSON(17, `"questType":{"daily":true}`))
	if !strings.Contains(daily, "repeatable=true, isDaily=true") {
		t.Fatalf("daily:\n%s", daily)
	}
}

func TestCheckIsStableAndWritesNothing(t *testing.T) {
	body := questJSON(18, `"startedBy":[{"type":"npc","id":7}]`)
	dir := t.TempDir()
	export := writeExport(t, dir, body)
	out := filepath.Join(dir, "Database")
	opts := Options{ExportDir: export, OutDir: out, DatabaseCommit: databaseCommit}
	if err := Run(opts); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(filepath.Join(out, "ForeverQuests.lua"))
	if err != nil {
		t.Fatal(err)
	}
	opts.Check = true
	if err := Run(opts); err != nil {
		t.Fatal(err)
	}
	after, err := os.ReadFile(filepath.Join(out, "ForeverQuests.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if string(before) != string(after) {
		t.Fatal("check rewrote ForeverQuests.lua")
	}
	if err := os.WriteFile(filepath.Join(out, "ForeverQuests.lua"), []byte("changed\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Run(opts); err == nil {
		t.Fatal("check accepted drifted lua")
	}
	meta, err := os.ReadFile(filepath.Join(out, "Metadata.lua"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(meta)
	if !strings.Contains(text, `databaseCommit = "`+databaseCommit+`"`) || strings.Contains(text, "questieCommit") {
		t.Fatalf("metadata:\n%s", text)
	}
	if strings.Contains(text, "generatedAt") || strings.Contains(text, "attCommit") {
		t.Fatalf("metadata has a clock or ATT field:\n%s", text)
	}
}

func compileOne(t *testing.T, body string) string {
	t.Helper()
	files, err := compileFixture(t, body)
	if err != nil {
		t.Fatal(err)
	}
	return string(files["ForeverQuests.lua"])
}

func compileFixture(t *testing.T, body string) (map[string][]byte, error) {
	t.Helper()
	export := writeExport(t, t.TempDir(), body)
	return renderExport(export, databaseCommit)
}

func writeExport(t *testing.T, dir, body string) string {
	t.Helper()
	export := filepath.Join(dir, "export")
	if err := os.MkdirAll(filepath.Join(export, "quests"), 0o755); err != nil {
		t.Fatal(err)
	}
	manifest := `{
	  "schemaVersion": 2,
	  "commit": "` + exportCommit + `",
	  "shards": [{"path": "quests/0001.json"}]
	}`
	shard := `{"schemaVersion":2,"quests":{"1":` + body + `}}`
	if err := os.WriteFile(filepath.Join(export, "manifest.json"), []byte(manifest), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(export, "quests", "0001.json"), []byte(shard), 0o644); err != nil {
		t.Fatal(err)
	}
	return export
}

func questJSON(id int, extra string) string {
	return `{"id":` + strconv.Itoa(id) + `,` + extra + `}`
}
