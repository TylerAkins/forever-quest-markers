package repositorytests

import (
	"regexp"
	"sort"
	"strings"
	"testing"
)

var localizationKeyPattern = regexp.MustCompile(`L\["([^"\\]*)"\]`)
var localizationDynamicPattern = regexp.MustCompile(`\bL\[\s*[A-Za-z_]`)
var localizationEntryPattern = regexp.MustCompile(`^\s*\["([^"\\]*)"\]\s*=`)

func TestEveryLocaleCoversEveryUsedString(t *testing.T) {
	base := root(t)
	toc := read(t, base, "ForeverQuestPins.toc")

	used := map[string]string{}
	for _, line := range strings.Split(toc, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasSuffix(line, ".lua") || strings.HasPrefix(line, "##") {
			continue
		}
		if line == "Localization.lua" {
			continue
		}
		path := strings.ReplaceAll(line, "\\", "/")
		source := read(t, base, path)
		if match := localizationDynamicPattern.FindString(source); match != "" {
			t.Errorf("%s uses a dynamic localization key (%s); use a literal L[\"...\"] key so the coverage test can see it", path, match)
		}
		for _, match := range localizationKeyPattern.FindAllStringSubmatch(source, -1) {
			used[match[1]] = path
		}
	}
	if len(used) == 0 {
		t.Fatal("no localized strings found in TOC files")
	}

	translations := parseLocalizationTables(t, read(t, base, "Localization.lua"))
	locales := []string{"esES", "deDE", "frFR", "ptBR", "zhCN", "zhTW", "koKR", "itIT", "ruRU"}
	if len(translations) != len(locales) {
		t.Fatalf("found %d locale tables, want %d", len(translations), len(locales))
	}

	var missing []string
	for _, locale := range locales {
		keys, ok := translations[locale]
		if !ok {
			t.Errorf("missing locale table %s", locale)
			continue
		}
		for key, path := range used {
			if !keys[key] {
				missing = append(missing, locale+": "+key+" ("+path+")")
			}
		}
	}
	sort.Strings(missing)
	for _, entry := range missing {
		t.Error("missing translation " + entry)
	}

	reference := translations["esES"]
	for _, locale := range locales[1:] {
		for key := range translations[locale] {
			if !reference[key] {
				t.Errorf("%s has key not present in esES: %q", locale, key)
			}
		}
	}
}

func parseLocalizationTables(t *testing.T, source string) map[string]map[string]bool {
	t.Helper()
	tables := map[string]map[string]bool{}
	locale := ""
	section := ""
	for _, line := range strings.Split(source, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "if locale == \"") || strings.HasPrefix(trimmed, "elseif locale == \"") {
			start := strings.Index(trimmed, "\"") + 1
			end := strings.Index(trimmed[start:], "\"")
			locale = trimmed[start : start+end]
			section = ""
			continue
		}
		if strings.HasPrefix(trimmed, "local trackerTranslations") {
			section = "tracker"
			locale = ""
			continue
		}
		if strings.HasPrefix(trimmed, "local interfaceTranslations") {
			section = "interface"
			locale = ""
			continue
		}
		if section != "" && strings.HasSuffix(trimmed, "= {") {
			fields := strings.Fields(trimmed)
			if len(fields) > 0 {
				locale = fields[0]
			}
			continue
		}
		if locale == "" {
			continue
		}
		match := localizationEntryPattern.FindStringSubmatch(line)
		if match == nil {
			continue
		}
		if tables[locale] == nil {
			tables[locale] = map[string]bool{}
		}
		tables[locale][match[1]] = true
	}
	return tables
}
