package release

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPlanAutomatedRelease(t *testing.T) {
	tests := []struct {
		name, previous, current string
		changed                 bool
		want                    string
		wantErr                 bool
	}{
		{"no change", "1.2.3", "1.2.3", false, "", false},
		{"next patch", "1.2.3", "1.2.4", true, "v1.2.4", false},
		{"manual minor", "1.2.3", "1.3.0", true, "v1.3.0", false},
		{"manual major", "1.2.3", "2.0.0", true, "v2.0.0", false},
		{"wrong increment", "1.2.3", "1.2.5", true, "", true},
		{"downgrade", "1.2.3", "1.2.2", true, "", true},
		{"invalid version", "1.02.3", "1.2.4", true, "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := PlanAutomatedRelease(tt.previous, tt.current, tt.changed)
			if (err != nil) != tt.wantErr || got != tt.want {
				t.Fatalf("PlanAutomatedRelease() = %q, %v; want %q, error=%v", got, err, tt.want, tt.wantErr)
			}
		})
	}
}

func TestPlanTagRejectsCollision(t *testing.T) {
	if got, err := PlanTag("same", "same"); err != nil || got != "reuse" {
		t.Fatalf("PlanTag(same SHA) = %q, %v; want reuse", got, err)
	}
	if _, err := PlanTag("old", "new"); err == nil {
		t.Fatal("PlanTag accepted a tag pointing at another commit")
	}
}

func TestParseVersionAndPrepareRejectStaleOrInvalidReleaseState(t *testing.T) {
	if _, err := ParseVersion("v0.1.21"); err == nil {
		t.Fatal("tag prefix was accepted as a version")
	}
	root := t.TempDir()
	if err := os.MkdirAll(filepath.Join(root, "Database"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "VERSION"), []byte("0.1.20\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "Database", "build_report.json"), []byte(`{"artifact":{"commit":"abc","sha256":"abc"},"counts":{"quests":1,"coord_pins":1,"instance_quests":0,"yearly_quests":0}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "CHANGELOG.md"), []byte("# Changelog\n\n## 0.1.20 - old\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Prepare(root, "0.1.21", "2026-09-20", false); err == nil || !strings.Contains(err.Error(), "released version 0.1.21") {
		t.Fatalf("stale VERSION error = %v", err)
	}
	if err := os.WriteFile(filepath.Join(root, "VERSION"), []byte("0.1.21\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "Database", "build_report.json"), []byte(`{"artifact":{"commit":"abc","sha256":"abc"},"counts":{"quests":"bad","coord_pins":1,"instance_quests":0,"yearly_quests":0}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Prepare(root, "0.1.21", "2026-09-20", false); err == nil {
		t.Fatalf("invalid report error = %v", err)
	}
}

func TestReleaseNotesRequireOneCurrentVersionAndNoEmail(t *testing.T) {
	version := Version{Major: 1, Minor: 2, Patch: 3}
	if err := ValidateReleaseNotes("## 1.2.3 - 2026-01-01\n\nNotes\n", version); err != nil {
		t.Fatal(err)
	}
	for _, notes := range []string{"## 1.2.2 - old\n", "## 1.2.3 - date\n## 1.2.3 - again\n", "## 1.2.3 - date\ncontact x@example.com\n"} {
		if err := ValidateReleaseNotes(notes, version); err == nil {
			t.Fatalf("ValidateReleaseNotes accepted %q", notes)
		}
	}
}

func TestPrepareDryRunDoesNotWrite(t *testing.T) {
	root := t.TempDir()
	write := func(path, contents string) {
		t.Helper()
		full := filepath.Join(root, path)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("VERSION", "1.2.3\n")
	write("CHANGELOG.md", "# Changelog\n\n## 1.2.3 - old\n")
	write("RELEASE_NOTES.md", "old notes\n")
	write("Database/build_report.json", `{"artifact":{"commit":"abc123","sha256":"abc123"},"counts":{"quests":2,"coord_pins":3,"instance_quests":1,"yearly_quests":0}}`)
	before, err := os.ReadFile(filepath.Join(root, "CHANGELOG.md"))
	if err != nil {
		t.Fatal(err)
	}
	version, err := Prepare(root, "1.2.3", "2026-05-06", true)
	if err != nil || version.String() != "1.2.4" {
		t.Fatalf("Prepare() = %s, %v", version, err)
	}
	after, err := os.ReadFile(filepath.Join(root, "CHANGELOG.md"))
	if err != nil {
		t.Fatal(err)
	}
	if string(before) != string(after) {
		t.Fatal("dry run modified CHANGELOG.md")
	}
	releaseNotes, err := os.ReadFile(filepath.Join(root, "RELEASE_NOTES.md"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(string(releaseNotes)) != "old notes" {
		t.Fatal("dry run modified RELEASE_NOTES.md")
	}
}

func TestPrepareWritesPatchReleaseIdempotently(t *testing.T) {
	root := t.TempDir()
	write := func(path, contents string) {
		t.Helper()
		full := filepath.Join(root, path)
		if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(full, []byte(contents), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("VERSION", "0.1.21\n")
	write("CHANGELOG.md", "# Changelog\n\n## 0.1.21 - 2026-09-19\n\n- Existing release.\n")
	write("Database/build_report.json", `{"artifact":{"commit":"abc123","sha256":"abc123"},"counts":{"quests":3501,"coord_pins":3725,"instance_quests":27,"yearly_quests":0}}`)
	for range 2 {
		if version, err := Prepare(root, "0.1.21", "2026-09-20", false); err != nil || version.String() != "0.1.22" {
			t.Fatalf("Prepare() = %s, %v", version, err)
		}
	}
	changelog, err := os.ReadFile(filepath.Join(root, "CHANGELOG.md"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(changelog), "## 0.1.22") != 1 || !strings.Contains(string(changelog), "`abc123`") || strings.Index(string(changelog), "## 0.1.22") > strings.Index(string(changelog), "## 0.1.21") {
		t.Fatalf("changelog was not updated idempotently: %s", changelog)
	}
	version, err := os.ReadFile(filepath.Join(root, "VERSION"))
	if err != nil || string(version) != "0.1.22\n" {
		t.Fatalf("VERSION = %q, %v", version, err)
	}
	notes, err := os.ReadFile(filepath.Join(root, "RELEASE_NOTES.md"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(notes), "## ") != 1 || !strings.Contains(string(notes), "2026-09-20") {
		t.Fatalf("unexpected notes: %s", notes)
	}
}
