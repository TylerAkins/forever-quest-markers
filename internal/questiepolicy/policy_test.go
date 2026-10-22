package questiepolicy

import (
	"os"
	"path/filepath"
	"testing"
)

func writePolicyFile(t *testing.T, root, relative, content string) {
	t.Helper()
	path := filepath.Join(root, relative)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLoadHolidayAndTagPolicy(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `
tinsert(eventQuests, { "Test Event", 100, { 10, 20 }, 1, "npc", nil, nil })
tinsert(eventQuests, { "Test Event", 101, { 10, 20 }, 1, "npc", nil, true })
`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `
function _QuestieDB.InitializeQuestTagInfoCorrections()
    _QuestieDB.questTagCorrections = {
        [100] = (Expansions.Current == Expansions.Era and { 81, l10n("Dungeon") }) or nil,
        [101] = (Expansions.Current == Expansions.Cata and { 81, l10n("Dungeon") }) or nil,
        [102] = { 5, l10n("Group") },
    }
end
`)
	policy, err := Load(root)
	if err != nil {
		t.Fatal(err)
	}
	if policy.HolidayEntries != 2 || len(policy.HolidayQuestIDs) != 1 {
		t.Fatalf("holiday entries=%d included=%d, want 2/1", policy.HolidayEntries, len(policy.HolidayQuestIDs))
	}
	if !policy.HolidayQuestIDs[100] || policy.HolidayQuestIDs[101] {
		t.Fatalf("unexpected holiday IDs: %v", policy.HolidayQuestIDs)
	}
	if policy.HiddenEntries != 1 {
		t.Fatalf("hidden entries = %d, want 1", policy.HiddenEntries)
	}
	if policy.TagEntries != 2 {
		t.Fatalf("tag entries = %d, want 2", policy.TagEntries)
	}
	if !policy.InstanceQuestIDs[100] {
		t.Fatal("quest 100 should be an instance quest")
	}
	if policy.InstanceQuestIDs[101] {
		t.Fatal("Cata-only correction must not apply to Forever")
	}
	if !IsInstanceTag(98) || IsInstanceTag(5) {
		t.Fatal("instance tag set is wrong")
	}
}

func TestLoadRejectsUnknownHolidaySyntax(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `
tinsert(eventQuests, { "Test Event", 100, unknownSyntax(1) })
`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `
_QuestieDB.questTagCorrections = {}
`)
	if _, err := Load(root); err == nil {
		t.Fatal("expected unknown holiday syntax to fail")
	}
}

func TestLoadRejectsMissingHolidayFiles(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = {}`)
	if _, err := Load(root); err == nil {
		t.Fatal("expected missing holiday files to fail")
	}
}

func TestLoadRejectsMalformedTagEntry(t *testing.T) {
	root := t.TempDir()
	writePolicyFile(t, root, "Database/Corrections/Holidays/quests/Test.lua", `tinsert(eventQuests, { "Test", 1 })`)
	writePolicyFile(t, root, "Database/Corrections/questTagInfoCorrections.lua", `_QuestieDB.questTagCorrections = { [1] = "Dungeon" }`)
	if _, err := Load(root); err == nil {
		t.Fatal("expected malformed tag entry to fail")
	}
}
