package attdsl

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPreprocessKeepsForeverAndDropsInactiveData(t *testing.T) {
	fixture, err := os.ReadFile(filepath.Join("..", "..", "tests", "fixtures", "preprocessor.lua"))
	if err != nil {
		t.Fatal(err)
	}
	got, err := Preprocess(string(fixture), NewBuildContext())
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(got, "q(1002") || strings.Contains(got, "HORDE_ONLY") {
		t.Fatalf("inactive branch remained: %s", got)
	}
	if !strings.Contains(got, "q(1001") || !strings.Contains(got, "q(1003") || !strings.Contains(got, "ALLIANCE_ONLY") {
		t.Fatalf("Forever branch missing: %s", got)
	}
}

func TestPreprocessHandlesNestedAndMalformedDirectives(t *testing.T) {
	ctx := NewBuildContext()
	ctx.Tags["EXPERIMENT"] = true
	source := "-- #if EXPERIMENT\nA\n-- #if NOT AFTER CATA\nB\n-- #else\nC\n-- #endif\n-- #else\nD\n-- #endif\n"
	got, err := Preprocess(source, ctx)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "A\n") || !strings.Contains(got, "B\n") || strings.Contains(got, "C\n") || strings.Contains(got, "D\n") {
		t.Fatalf("nested directives selected wrong branch: %q", got)
	}
	for _, malformed := range []string{"-- #else\n", "-- #elseif CATA\n", "-- #if FOREVER\n"} {
		if _, err := Preprocess(malformed, ctx); err == nil {
			t.Errorf("accepted malformed directives %q", malformed)
		}
	}
}

func TestUnwrapDisabledModuleRequiresValidTopLevelComment(t *testing.T) {
	wrapped := "--[[\nroot(1, {})\n--]]\n"
	if got := UnwrapDisabledModule(wrapped); got != "root(1, {})\n" {
		t.Fatalf("unwrapped module = %q", got)
	}
	for _, source := range []string{"--[[\nroot(1, {})\n--]]\nrun()\n", "--[=[\nroot(1, {})\n--]]\n"} {
		if got := UnwrapDisabledModule(source); got != source {
			t.Errorf("unexpectedly unwrapped %q to %q", source, got)
		}
	}
}

func TestParseVersionTokens(t *testing.T) {
	if patch, ok := ParseVersionToken("Cata"); !ok || patch != ([4]int{4, 0, 3, 0}) {
		t.Fatalf("Cata token = %v, %v", patch, ok)
	}
	if patch, ok := ParseVersionToken("1.60.1"); !ok || patch != ([4]int{1, 60, 1, 0}) {
		t.Fatalf("numeric token = %v, %v", patch, ok)
	}
	if _, ok := ParseVersionToken("UNKNOWN_EXPANSION"); ok {
		t.Fatal("unknown token parsed")
	}
}

func TestLuaParserReportsMalformedSourceAndAcceptsTrailingDecimalPoint(t *testing.T) {
	if _, err := ParseLua("q(1, { qg = 2, ", "broken.lua"); err == nil {
		t.Fatal("malformed Lua parsed successfully")
	}
	if _, err := ParseLua("q(1, { coord = { 41., 79.0, 1 } })", "coords.lua"); err != nil {
		t.Fatalf("trailing decimal point rejected: %v", err)
	}
}

func TestParseAndEvaluateLuaFixtures(t *testing.T) {
	ctx := NewBuildContext()
	ctx.Maps = map[string]int{"EASTERN_KINGDOMS": 13, "ELWYNN_FOREST": 12, "NORTHSHIRE_VALLEY": 9, "MULGORE": 7, "ZEPHRAS_ISLE": 2712, "DUN_MOROGH": 1}
	for _, name := range []string{"preprocessor.lua", "mulgore.lua", "locals.lua", "elwynn.lua", "zephras.lua", "attunement.lua"} {
		t.Run(name, func(t *testing.T) {
			source, err := os.ReadFile(filepath.Join("..", "..", "tests", "fixtures", name))
			if err != nil {
				t.Fatal(err)
			}
			processed, err := Preprocess(string(source), ctx)
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
			if len(env.Roots) == 0 {
				t.Fatal("fixture did not produce any roots")
			}
		})
	}
}

func TestRecipeHelperDoesNotCreateQuestRootsAndEmitIsDeterministic(t *testing.T) {
	ctx := fixtureContext()
	source := "local register = GetRecipeHelperForProfession(ALCHEMY); register(0, 2259)"
	statements, err := ParseLua(source, "alchemy.lua")
	if err != nil {
		t.Fatal(err)
	}
	env := NewEnvironment(ctx)
	if err := env.Evaluate(statements); err != nil {
		t.Fatal(err)
	}
	if len(env.Roots) != 0 {
		t.Fatalf("recipe registration created %d roots", len(env.Roots))
	}
	result := extractFixture(t, "zephras.lua")
	first, second := EmitLuaDatabase(result.Quests, "abc123"), EmitLuaDatabase(result.Quests, "abc123")
	if first != second {
		t.Fatal("Lua database emission is not deterministic")
	}
}
