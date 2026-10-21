package release

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	versionPattern = regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`)
	emailPattern   = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	dateHeading    = regexp.MustCompile(`(?m)^## (\d+\.\d+\.\d+)(?:\s+[-—].*)?$`)
)

type Version struct {
	Major int
	Minor int
	Patch int
}

func ParseVersion(value string) (Version, error) {
	parts := versionPattern.FindStringSubmatch(strings.TrimSpace(value))
	if parts == nil {
		return Version{}, fmt.Errorf("invalid stable version: %q", value)
	}
	numbers := make([]int, 3)
	for i := range numbers {
		number, err := strconv.Atoi(parts[i+1])
		if err != nil {
			return Version{}, fmt.Errorf("invalid stable version: %q", value)
		}
		numbers[i] = number
	}
	return Version{Major: numbers[0], Minor: numbers[1], Patch: numbers[2]}, nil
}

func (v Version) NextPatch() Version { return Version{v.Major, v.Minor, v.Patch + 1} }

func (v Version) String() string { return fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch) }

func PlanAutomatedRelease(previousText, currentText string, changed bool) (string, error) {
	if !changed {
		return "", nil
	}
	previous, err := ParseVersion(previousText)
	if err != nil {
		return "", err
	}
	current, err := ParseVersion(currentText)
	if err != nil {
		return "", err
	}
	expected := previous.NextPatch()
	if current != expected {
		return "", fmt.Errorf("release content changed, but VERSION must advance from %s to %s; found %s", previous, expected, current)
	}
	return "v" + current.String(), nil
}

func PlanTag(existingSHA, targetSHA string) (string, error) {
	if targetSHA == "" {
		return "", errors.New("target tag commit SHA is required")
	}
	if existingSHA == "" {
		return "create", nil
	}
	if existingSHA != targetSHA {
		return "", fmt.Errorf("tag already points to %s, not target commit %s", existingSHA, targetSHA)
	}
	return "reuse", nil
}

func ValidateReleaseNotes(notes string, version Version) error {
	matches := dateHeading.FindAllStringSubmatch(notes, -1)
	if len(matches) != 1 || matches[0][1] != version.String() {
		return fmt.Errorf("RELEASE_NOTES.md must contain exactly one release heading for %s", version)
	}
	if emailPattern.MatchString(notes) {
		return errors.New("RELEASE_NOTES.md must not contain email addresses")
	}
	return nil
}

func ReleaseNotes(entry string, version Version) (string, error) {
	notes := strings.TrimRight(entry, " \t\r\n") + "\n"
	if err := ValidateReleaseNotes(notes, version); err != nil {
		return "", err
	}
	return notes, nil
}

func ReplaceOrInsertChangelogEntry(changelog string, version Version, entry string) (string, error) {
	var sectionPattern = regexp.MustCompile(`(?m)^## (\d+\.\d+\.\d+)(?:\s+[-—].*)?$`)
	headings := sectionPattern.FindAllStringSubmatchIndex(changelog, -1)
	for index, heading := range headings {
		if changelog[heading[2]:heading[3]] != version.String() {
			continue
		}
		end := len(changelog)
		if index+1 < len(headings) {
			end = headings[index+1][0]
		}
		return changelog[:heading[0]] + strings.TrimRight(entry, " \t\r\n") + "\n\n" + changelog[end:], nil
	}
	firstRelease := regexp.MustCompile(`(?m)^## \d+\.\d+\.\d+`).FindStringIndex(changelog)
	if firstRelease == nil {
		return "", errors.New("CHANGELOG.md has no release heading")
	}
	return changelog[:firstRelease[0]] + entry + "\n" + changelog[firstRelease[0]:], nil
}

func Prepare(root, baseText, releaseDate string, dryRun bool) (Version, error) {
	base, err := ParseVersion(baseText)
	if err != nil {
		return Version{}, err
	}
	target := base.NextPatch()
	versionPath := filepath.Join(root, "VERSION")
	currentText, err := os.ReadFile(versionPath)
	if err != nil {
		return Version{}, err
	}
	current, err := ParseVersion(string(currentText))
	if err != nil {
		return Version{}, err
	}
	if current != base && current != target {
		return Version{}, fmt.Errorf("VERSION must be the released version %s or prepared version %s; found %s", base, target, current)
	}
	reportBytes, err := os.ReadFile(filepath.Join(root, "Database", "build_report.json"))
	if err != nil {
		return Version{}, err
	}
	var report map[string]json.RawMessage
	if err := json.Unmarshal(reportBytes, &report); err != nil {
		return Version{}, err
	}
	var attCommit string
	if err := json.Unmarshal(report["att_sha"], &attCommit); err != nil || attCommit == "" {
		return Version{}, errors.New("Database/build_report.json is missing string field 'att_sha'")
	}
	quests, err := requiredReportInt(report, "quests_emitted")
	if err != nil {
		return Version{}, err
	}
	coordinates, err := requiredReportInt(report, "coord_pins")
	if err != nil {
		return Version{}, err
	}
	attunement, err := requiredReportInt(report, "attunement_quests")
	if err != nil {
		return Version{}, err
	}
	entry := fmt.Sprintf("## %s - %s\n\n- Update the ATT Forever quest database to `%s`.\n- Ship %d quests with %d coordinate pins (%d attunement quests).\n", target, releaseDate, attCommit, quests, coordinates, attunement)
	changelogPath := filepath.Join(root, "CHANGELOG.md")
	changelogBytes, err := os.ReadFile(changelogPath)
	if err != nil {
		return Version{}, err
	}
	changelog, err := ReplaceOrInsertChangelogEntry(string(changelogBytes), target, entry)
	if err != nil {
		return Version{}, err
	}
	notes, err := ReleaseNotes(entry, target)
	if err != nil {
		return Version{}, err
	}
	if dryRun {
		return target, nil
	}
	if err := os.WriteFile(versionPath, []byte(target.String()+"\n"), 0o644); err != nil {
		return Version{}, err
	}
	if err := os.WriteFile(changelogPath, []byte(changelog), 0o644); err != nil {
		return Version{}, err
	}
	if err := os.WriteFile(filepath.Join(root, "RELEASE_NOTES.md"), []byte(notes), 0o644); err != nil {
		return Version{}, err
	}
	return target, nil
}

func requiredReportInt(report map[string]json.RawMessage, key string) (int, error) {
	value, ok := report[key]
	if !ok {
		return 0, fmt.Errorf("Database/build_report.json is missing integer field %q", key)
	}
	var number json.Number
	if err := json.Unmarshal(value, &number); err != nil {
		return 0, fmt.Errorf("Database/build_report.json is missing integer field %q", key)
	}
	parsed, err := strconv.Atoi(number.String())
	if err != nil {
		return 0, fmt.Errorf("Database/build_report.json is missing integer field %q", key)
	}
	return parsed, nil
}

func Run(args []string, stdout io.Writer) error {
	if len(args) == 0 {
		return errors.New("release requires prepare, validate, validate-notes, or validate-tag")
	}
	switch args[0] {
	case "prepare":
		flags := flag.NewFlagSet("prepare", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		base := flags.String("base-version", "", "released base version")
		root := flags.String("root", ".", "repository root")
		date := flags.String("date", time.Now().UTC().Format("2006-01-02"), "release date")
		dryRun := flags.Bool("dry-run", false, "validate without writing files")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		if *base == "" {
			return errors.New("--base-version is required")
		}
		version, err := Prepare(*root, *base, *date, *dryRun)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, version)
		return err
	case "validate":
		flags := flag.NewFlagSet("validate", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		previous := flags.String("previous-version", "", "previous stable version")
		current := flags.String("current-version", "", "current stable version")
		changed := flags.Bool("release-content-changed", false, "release content changed")
		root := flags.String("root", ".", "repository root")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		tag, err := PlanAutomatedRelease(*previous, *current, *changed)
		if err != nil || tag == "" {
			return err
		}
		version, err := ParseVersion(*current)
		if err != nil {
			return err
		}
		notes, err := os.ReadFile(filepath.Join(*root, "RELEASE_NOTES.md"))
		if err != nil {
			return err
		}
		if err := ValidateReleaseNotes(string(notes), version); err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, tag)
		return err
	case "validate-notes":
		flags := flag.NewFlagSet("validate-notes", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		versionText := flags.String("version", "", "stable version")
		root := flags.String("root", ".", "repository root")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		version, err := ParseVersion(*versionText)
		if err != nil {
			return err
		}
		notes, err := os.ReadFile(filepath.Join(*root, "RELEASE_NOTES.md"))
		if err != nil {
			return err
		}
		return ValidateReleaseNotes(string(notes), version)
	case "validate-tag":
		flags := flag.NewFlagSet("validate-tag", flag.ContinueOnError)
		flags.SetOutput(io.Discard)
		existing := flags.String("existing-sha", "", "existing tag commit SHA")
		target := flags.String("target-sha", "", "target commit SHA")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		decision, err := PlanTag(*existing, *target)
		if err != nil {
			return err
		}
		_, err = fmt.Fprintln(stdout, decision)
		return err
	default:
		return fmt.Errorf("unknown release command %q", args[0])
	}
}
