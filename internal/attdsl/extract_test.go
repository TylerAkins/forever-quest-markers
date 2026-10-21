package attdsl

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func fixtureContext() BuildContext {
	ctx := NewBuildContext()
	ctx.Maps = map[string]int{"EASTERN_KINGDOMS": 1415, "ELWYNN_FOREST": 1429, "NORTHSHIRE_VALLEY": 425, "MULGORE": 1412, "ZEPHRAS_ISLE": 2521, "DUN_MOROGH": 1426, "ORGRIMMAR": 1454}
	ctx.Timelines["ADDED_1_60_1"] = "added 1.60.1.69893"
	return ctx
}

func extractFixture(t *testing.T, name string) *ExtractResult {
	t.Helper()
	ctx := fixtureContext()
	sourceBytes, err := os.ReadFile(filepath.Join("..", "..", "tests", "fixtures", name))
	if err != nil {
		t.Fatal(err)
	}
	source := string(sourceBytes)
	processed, err := Preprocess(UnwrapDisabledModule(source), ctx)
	if err != nil {
		t.Fatal(err)
	}
	statements, err := ParseLua(processed, name)
	if err != nil {
		t.Fatal(err)
	}
	env := NewEnvironment(ctx)
	if err := env.Evaluate(statements); err != nil {
		t.Fatal(err)
	}
	result := NewExtractResult(ctx.Patch)
	result.ExtractRoots(env.Roots, name)
	ApplyTitles(source, result)
	return result
}

func TestExtractElwynnKeepsQuestRestrictionsAndExclusions(t *testing.T) {
	result := extractFixture(t, "elwynn.lua")
	if result.Quests[783].Faction != "Alliance" || !equalInts(result.Quests[783].QGs, []int{823}) {
		t.Fatalf("quest 783 = %#v", result.Quests[783])
	}
	paladin := result.Quests[3101]
	if !equalInts(paladin.Races, []int{1}) || !equalInts(paladin.Classes, []int{2}) || !equalInts(paladin.QGs, []int{197}) || !equalInts(paladin.SourceQuests, []int{7}) {
		t.Fatalf("quest 3101 = %#v", paladin)
	}
	bounty := result.Quests[6]
	if len(bounty.Coords) != 1 || bounty.Coords[0].X != 48.1 || bounty.MinLevel == nil || *bounty.MinLevel != 2 {
		t.Fatalf("quest 6 = %#v", bounty)
	}
	either := result.Quests[90001]
	if !equalInts(either.SourceQuests, []int{10, 11, 12}) || either.SourceQuestNumRequired == nil || *either.SourceQuestNumRequired != 1 {
		t.Fatalf("quest 90001 = %#v", either)
	}
	if _, exists := result.Quests[90002]; exists || result.Excluded["no_coords"] == 0 {
		t.Fatal("item-start quest without coordinates was not excluded")
	}
}

func TestExtractZephrasInheritsMapAndRaceRestrictions(t *testing.T) {
	result := extractFixture(t, "zephras.lua")
	if len(result.Quests) != 3 {
		t.Fatalf("got %d Zephras quests", len(result.Quests))
	}
	start := result.Quests[92460]
	if start.Coords[0].MapID != 2521 || start.Coords[0].X != 42.8 || !equalInts(start.QGs, []int{251362}) || !equalInts(start.Races, []int{95, 96}) {
		t.Fatalf("start quest = %#v", start)
	}
	if !equalInts(result.Quests[92461].SourceQuests, []int{92460}) {
		t.Fatalf("follow-up quest = %#v", result.Quests[92461])
	}
}

func TestExtractInstanceAttunementChains(t *testing.T) {
	result := extractFixture(t, "attunement.lua")
	result.MarkAttunementChains()
	for _, id := range []int{80, 81, 90, 100, 101, 200, 201} {
		if result.Quests[id] == nil || !result.Quests[id].IsAttunement {
			t.Errorf("quest %d was not marked attunement", id)
		}
	}
	if result.Quests[200].Coords[0].MapID != 1429 || result.Quests[201].Coords[0].MapID != 1454 {
		t.Fatalf("faction quest data maps: %d, %d", result.Quests[200].Coords[0].MapID, result.Quests[201].Coords[0].MapID)
	}
}

func TestUnwrappedDisabledInstanceModuleRetainsAttunementAccessQuest(t *testing.T) {
	result := extractFixture(t, "disabled_module.lua")
	result.MarkAttunementChains()
	if record := result.Quests[7848]; record == nil || !record.IsAttunement {
		t.Fatalf("disabled module access quest was not preserved: %#v", record)
	}
}

func TestExtractRequiredSkillAndUnresolvedIdentifier(t *testing.T) {
	for _, test := range []struct {
		id    int
		skill any
	}{{90003, 197}, {90004, "NEW_PROFESSION"}} {
		source := "q(" + strconv.Itoa(test.id) + ", { qg=100, coord={10, 20, MAP.ELWYNN_FOREST}, requireSkill=" + fmt.Sprint(test.skill) + " })"
		ctx := fixtureContext()
		statements, err := ParseLua(source, "profession.lua")
		if err != nil {
			t.Fatal(err)
		}
		env := NewEnvironment(ctx)
		if err := env.Evaluate(statements); err != nil {
			t.Fatal(err)
		}
		result := NewExtractResult(ctx.Patch)
		result.ExtractRoots(env.Roots, "profession.lua")
		record := result.Quests[test.id]
		if record == nil || record.RequiredSkill != test.skill {
			t.Fatalf("quest %d required skill = %#v", test.id, record)
		}
		output := EmitLuaDatabase(result.Quests, "abc123")
		if !strings.Contains(output, "requireSkill=") {
			t.Fatalf("required skill absent from output: %s", output)
		}
	}
}

func TestTimelineExcludesFutureAndDeletedQuests(t *testing.T) {
	result := extractFixture(t, "mulgore.lua")
	if result.Quests[24440] != nil {
		t.Fatal("removed quest was emitted")
	}
	if result.Quests[754] == nil || result.Quests[8673] == nil || !result.Quests[8673].IsYearly {
		t.Fatal("current Forever or yearly quest was omitted")
	}
}

func TestTitlesNormalizeAndEmit(t *testing.T) {
	source := "q(8171, { -- The Battle for Arathi Basin! [Level 20] (Horde)\n qg=15021, coord={73.3,29.7,MAP.ELWYNN_FOREST},\n})"
	if got := NormalizeATTTitle("The Battle for Arathi Basin! [Level 20] (Horde)"); got != "The Battle for Arathi Basin!" {
		t.Fatalf("normalized title %q", got)
	}
	ctx := fixtureContext()
	statements, err := ParseLua(source, "titles.lua")
	if err != nil {
		t.Fatal(err)
	}
	env := NewEnvironment(ctx)
	if err := env.Evaluate(statements); err != nil {
		t.Fatal(err)
	}
	result := NewExtractResult(ctx.Patch)
	result.ExtractRoots(env.Roots, "titles.lua")
	ApplyTitles(source, result)
	if result.Quests[8171] == nil || result.Quests[8171].ATTTitle != "The Battle for Arathi Basin!" {
		t.Fatalf("title result %#v", result.Quests[8171])
	}
}

func equalInts(got, want []int) bool {
	if len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i] != want[i] {
			return false
		}
	}
	return true
}
