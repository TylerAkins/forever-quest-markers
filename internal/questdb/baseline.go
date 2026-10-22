package questdb

import (
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
)

type baselineQuest struct {
	ID         int
	HasCoord   bool
	MapID      int
	X          float64
	Y          float64
	CoordCount int
	Flags      map[string]bool
}

var baselineRowPattern = regexp.MustCompile(`^\s*\[(\d+)\]\s*=\s*\{(.*)\},\s*$`)
var baselineCoordsPattern = regexp.MustCompile(`\{\s*(-?[0-9.]+)\s*,\s*(-?[0-9.]+)\s*,\s*(\d+)\s*\}`)

func parseBaseline(filePath string) (map[int]baselineQuest, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, err
	}
	quests := map[int]baselineQuest{}
	inQuests := false
	for _, line := range strings.Split(string(data), "\n") {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "--") {
			continue
		}
		if strings.HasPrefix(trimmed, "ns.Quests") {
			inQuests = true
			continue
		}
		if strings.HasPrefix(trimmed, "ns.ByMap") || (inQuests && trimmed == "}") {
			break
		}
		if !inQuests {
			continue
		}
		match := baselineRowPattern.FindStringSubmatch(line)
		if match == nil {
			return nil, fmt.Errorf("unrecognized baseline quest row %q", trimmed)
		}
		id, _ := strconv.Atoi(match[1])
		body := match[2]
		quest := baselineQuest{ID: id, Flags: map[string]bool{}}
		if mapID := intField(body, "mapID"); mapID > 0 {
			quest.MapID = mapID
			quest.HasCoord = true
			quest.CoordCount = 1
			quest.X = floatField(body, "x")
			quest.Y = floatField(body, "y")
		}
		if coordsStart := strings.Index(body, "coords={"); coordsStart >= 0 {
			coords := balancedTable(body[coordsStart+len("coords="):])
			quest.CoordCount += len(baselineCoordsPattern.FindAllString(coords, -1))
		}
		for _, flag := range []string{"isAttunement", "isInstanceQuest", "isYearly", "repeatable", "isBreadcrumb", "isMonthly"} {
			quest.Flags[flag] = strings.Contains(body, flag+"=true")
		}
		quests[id] = quest
	}
	if len(quests) == 0 {
		return nil, fmt.Errorf("baseline contains no quest records")
	}
	return quests, nil
}

func balancedTable(source string) string {
	if source == "" || source[0] != '{' {
		return ""
	}
	depth := 0
	for index := 0; index < len(source); index++ {
		switch source[index] {
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return source[:index+1]
			}
		}
	}
	return source
}

var mapIDPattern = regexp.MustCompile(`\bmapID=(-?\d+)`)
var xPattern = regexp.MustCompile(`\bx=(-?[0-9.]+)`)
var yPattern = regexp.MustCompile(`\by=(-?[0-9.]+)`)

func intField(body, name string) int {
	pattern := regexp.MustCompile(`\b` + regexp.QuoteMeta(name) + `=(-?\d+)`)
	match := pattern.FindStringSubmatch(body)
	if match == nil {
		return 0
	}
	value, _ := strconv.Atoi(match[1])
	return value
}

func floatField(body, name string) float64 {
	pattern := regexp.MustCompile(`\b` + regexp.QuoteMeta(name) + `=(-?[0-9.]+)`)
	match := pattern.FindStringSubmatch(body)
	if match == nil {
		return 0
	}
	value, _ := strconv.ParseFloat(match[1], 64)
	return value
}
