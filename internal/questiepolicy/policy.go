package questiepolicy

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/TylerAkins/forever-quest-markers/internal/questiedb"
)

// InstanceTagIDs are the Questie quest tags that mark instanced content.
var InstanceTagIDs = map[int]bool{
	81: true, // Dungeon
	62: true, // Raid
	85: true, // Heroic
	88: true, // Raid (10)
	89: true, // Raid (25)
	98: true, // Scenario
}

// IsInstanceTag reports whether a Questie quest tag describes instanced content.
func IsInstanceTag(tagID int) bool {
	return InstanceTagIDs[tagID]
}

// Policy is the Questie event and quest-tag policy evaluated for Forever.
type Policy struct {
	HolidayQuestIDs  map[int]bool
	HolidayNames     map[int]string
	QuestTags        map[int]int
	QuestTagNames    map[int]string
	InstanceQuestIDs map[int]bool
	HolidayEntries   int
	HiddenEntries    int
	TagEntries       int
	Conflicts        []string
}

var foreverVars = map[string]any{
	"Expansions.Current": 1,
	"Expansions.Era":     1,
	"Expansions.Tbc":     2,
	"Expansions.Wotlk":   3,
	"Expansions.Cata":    4,
	"Expansions.MoP":     5,
	"Questie.IsSoD":      false,
	"Questie.IsEURegion": false,
}

// Load parses Questie's holiday quest files and quest-tag corrections under
// Forever (Era) semantics.
func Load(root string) (*Policy, error) {
	policy := &Policy{
		HolidayQuestIDs:  map[int]bool{},
		HolidayNames:     map[int]string{},
		QuestTags:        map[int]int{},
		QuestTagNames:    map[int]string{},
		InstanceQuestIDs: map[int]bool{},
	}
	if err := policy.loadHolidays(root); err != nil {
		return nil, err
	}
	if err := policy.loadTags(root); err != nil {
		return nil, err
	}
	return policy, nil
}

func (policy *Policy) loadHolidays(root string) error {
	pattern := filepath.Join(root, "Database", "Corrections", "Holidays", "quests", "*.lua")
	files, err := filepath.Glob(pattern)
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return fmt.Errorf("no Questie holiday quest files under %s", pattern)
	}
	sort.Strings(files)
	seen := map[int]string{}
	for _, file := range files {
		data, err := os.ReadFile(file)
		if err != nil {
			return err
		}
		source := questiedb.StripLuaComments(string(data))
		position := 0
		for {
			index := strings.Index(source[position:], "tinsert(eventQuests,")
			if index < 0 {
				break
			}
			start := position + index + len("tinsert(eventQuests,")
			for start < len(source) && (source[start] == ' ' || source[start] == '\t' || source[start] == '\r' || source[start] == '\n') {
				start++
			}
			if start >= len(source) || source[start] != '{' {
				return fmt.Errorf("%s: tinsert(eventQuests) is missing a table", file)
			}
			expression, err := questiedb.ExtractLuaValue(source, start)
			if err != nil {
				return fmt.Errorf("%s: %w", file, err)
			}
			value, err := questiedb.ParseLuaExpression(expression, foreverVars)
			if err != nil {
				return fmt.Errorf("%s: parse event quest: %w", file, err)
			}
			table, ok := value.(*questiedb.LuaTable)
			if !ok {
				return fmt.Errorf("%s: event quest entry is %T, not a table", file, value)
			}
			eventName, ok := table.Get(1).(string)
			if !ok || eventName == "" {
				return fmt.Errorf("%s: event quest entry has no event name", file)
			}
			questID, ok := questiedb.Int(table.Get(2))
			if !ok || questID <= 0 {
				return fmt.Errorf("%s: event quest entry %q has no quest ID", file, eventName)
			}
			policy.HolidayEntries++
			hidden, err := policy.hideCondition(table.Get(7))
			if err != nil {
				return fmt.Errorf("%s: event quest %d: %w", file, questID, err)
			}
			if hidden {
				policy.HiddenEntries++
			} else {
				if previous, exists := seen[questID]; exists {
					policy.Conflicts = append(policy.Conflicts, fmt.Sprintf("holiday quest %d appears in %s and %s", questID, previous, eventName))
				}
				seen[questID] = eventName
				policy.HolidayQuestIDs[questID] = true
				policy.HolidayNames[questID] = eventName
			}
			position = start + len(expression)
		}
	}
	return nil
}

func (policy *Policy) hideCondition(value any) (bool, error) {
	switch typed := value.(type) {
	case nil:
		return false, nil
	case bool:
		return typed, nil
	default:
		return false, fmt.Errorf("unsupported hide condition %T", value)
	}
}

var tagTablePattern = regexp.MustCompile(`\b_QuestieDB\.questTagCorrections\s*=\s*\{`)

func (policy *Policy) loadTags(root string) error {
	file := filepath.Join(root, "Database", "Corrections", "questTagInfoCorrections.lua")
	data, err := os.ReadFile(file)
	if err != nil {
		return err
	}
	source := questiedb.StripLuaComments(string(data))
	match := tagTablePattern.FindStringIndex(source)
	if match == nil {
		return fmt.Errorf("%s: questTagCorrections table not found", file)
	}
	expression, err := questiedb.ExtractLuaValue(source, match[1]-1)
	if err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	value, err := questiedb.ParseLuaExpression(expression, foreverVars)
	if err != nil {
		return fmt.Errorf("%s: parse questTagCorrections: %w", file, err)
	}
	table, ok := value.(*questiedb.LuaTable)
	if !ok {
		return fmt.Errorf("%s: questTagCorrections is %T, not a table", file, value)
	}
	for _, questID := range table.IntKeys() {
		entry := table.Numbers[questID]
		if entry == nil {
			continue
		}
		tagTable, ok := entry.(*questiedb.LuaTable)
		if !ok {
			return fmt.Errorf("%s: tag correction for quest %d is %T, not a table", file, questID, entry)
		}
		tagID, ok := questiedb.Int(tagTable.Get(1))
		if !ok {
			return fmt.Errorf("%s: tag correction for quest %d has no tag ID", file, questID)
		}
		name, _ := tagTable.Get(2).(string)
		policy.TagEntries++
		policy.QuestTags[questID] = tagID
		policy.QuestTagNames[questID] = name
		if IsInstanceTag(tagID) {
			policy.InstanceQuestIDs[questID] = true
		}
	}
	return nil
}
