package attdsl

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var RaceIDs = map[string]int{
	"HUMAN": 1, "ORC": 2, "DWARF": 3, "NIGHTELF": 4, "NIGHT_ELF": 4,
	"SCOURGE": 5, "UNDEAD": 5, "TAUREN": 6, "GNOME": 7, "TROLL": 8,
	"GOBLIN": 9, "BLOODELF": 10, "BLOOD_ELF": 10, "DRAENEI": 11,
	"WORGEN": 22, "PANDAREN_NEUTRAL": 24, "PANDAREN_ALLIANCE": 25,
	"PANDAREN_HORDE": 26, "SKYBORNE_ALLIANCE": 95, "SKYBORNE_HORDE": 96,
}

var ClassIDs = map[string]int{
	"WARRIOR": 1, "PALADIN": 2, "HUNTER": 3, "ROGUE": 4, "PRIEST": 5,
	"DEATHKNIGHT": 6, "DEATH_KNIGHT": 6, "SHAMAN": 7, "MAGE": 8,
	"WARLOCK": 9, "MONK": 10, "DRUID": 11, "DEMONHUNTER": 12,
	"DEMON_HUNTER": 12, "EVOKER": 13,
}

var ProfessionIDs = map[string]int{
	"ABOMINABLE_STITCHING": 2787, "ARCANA_MANIPULATION": 2821, "ASCENSION_CRAFTING": 2791,
	"ALCHEMY": 171, "ARCHAEOLOGY": 794, "BLACKSMITHING": 164, "COOKING": 185,
	"DYE_CRAFTING": 2984, "ENCHANTING": 333, "ENGINEERING": 202, "GOBLIN_ENGINEERING": 20222,
	"GNOMISH_ENGINEERING": 20219, "FIRST_AID": 129, "FISHING": 356, "HERBALISM": 182,
	"INSCRIPTION": 773, "JEWELCRAFTING": 755, "JUNKYARD_TINKERING": 2720,
	"LEATHERWORKING": 165, "LOCKPICKING": 633, "MINING": 186, "MOONCLOTH_TAILORING": 26798,
	"PICKPOCKETING": 921, "POISONS": 40, "PROTOFORM_SYNTHESIS": 2819, "RUNEFORGING": 960,
	"SHADOWEAVE_TAILORING": 26801, "SKINNING": 393, "SOUL_CYPHERING": 2777,
	"SPELLFIRE_TAILORING": 26797, "STYGIA_CRAFTING": 2811, "SUPPLY_SHIPMENTS": 2886,
	"TAILORING": 197, "TUSKARR_FISHING_GEAR": 2847,
}

var ExpansionVersions = map[string][4]int{
	"CLASSIC": {1, 0, 0, 0}, "VANILLA": {1, 0, 0, 0}, "CLASSICERA": {1, 0, 0, 0},
	"TBC": {2, 0, 1, 0}, "BC": {2, 0, 1, 0}, "BURNINGCRUSADE": {2, 0, 1, 0},
	"WRATH": {3, 0, 2, 0}, "WOTLK": {3, 0, 2, 0}, "CATA": {4, 0, 3, 0},
	"CATACLYSM": {4, 0, 3, 0}, "MOP": {5, 0, 4, 0}, "PANDARIA": {5, 0, 4, 0},
	"WOD": {6, 0, 2, 0}, "WOWD": {6, 0, 2, 0}, "DRAENOR": {6, 0, 2, 0},
	"LEGION": {7, 0, 3, 0}, "BFA": {8, 0, 1, 0}, "BATTLEFORAZEROTH": {8, 0, 1, 0},
	"SL": {9, 0, 1, 0}, "SHADOWLANDS": {9, 0, 1, 0}, "DF": {10, 0, 2, 0},
	"DRAGONFLIGHT": {10, 0, 2, 0}, "TWW": {11, 0, 2, 0}, "WARWITHIN": {11, 0, 2, 0},
	"MID": {12, 0, 0, 0}, "MIDNIGHT": {12, 0, 0, 0},
}

var DefaultForeverTags = map[string]bool{
	"ANYCLASSIC": true, "FOREVER": true, "CAMELOT": true, "CLASSIC": true, "CRIEVE": true,
	"EXPLORATION": true, "IGNORE_ERRORS": true, "OBJECTIVES": true, "NOSIMPLIFY": true,
	"INCLUDE_QUALITY": true,
}

var DefaultForeverPatch = [4]int{1, 60, 1, 69893}

type BuildContext struct {
	Patch     [4]int
	Tags      map[string]bool
	Maps      map[string]int
	Timelines map[string]string
}

func NewBuildContext() BuildContext {
	tags := make(map[string]bool, len(DefaultForeverTags))
	for tag := range DefaultForeverTags {
		tags[tag] = true
	}
	return BuildContext{Patch: DefaultForeverPatch, Tags: tags, Maps: map[string]int{}, Timelines: map[string]string{}}
}

func ParsePatch(values []int) [4]int {
	var result [4]int
	copy(result[:], values)
	return result
}

func ParseVersionToken(token string) ([4]int, bool) {
	compact := strings.ToUpper(strings.ReplaceAll(strings.ReplaceAll(strings.TrimSpace(token), "-", ""), " ", ""))
	if patch, ok := ExpansionVersions[compact]; ok {
		return patch, true
	}
	parts := strings.Split(strings.TrimSpace(token), ".")
	if len(parts) == 0 {
		return [4]int{}, false
	}
	var values []int
	for _, part := range parts {
		value, err := strconv.Atoi(part)
		if err != nil || value < 0 {
			return [4]int{}, false
		}
		values = append(values, value)
	}
	return ParsePatch(values), true
}

func LoadForeverConstants(root string) (BuildContext, error) {
	ctx := NewBuildContext()
	foreverDB := filepath.Join(root, ".contrib", ".db", "forever")
	configPath := filepath.Join(foreverDB, ".config", "forever.config")
	if data, err := os.ReadFile(configPath); err == nil {
		cleaned := stripJSONC(string(data))
		var config struct {
			DataPatch        []int    `json:"DataPatch"`
			PreProcessorTags []string `json:"PreProcessorTags"`
		}
		if err := json.Unmarshal([]byte(cleaned), &config); err != nil {
			return ctx, fmt.Errorf("parse %s: %w", configPath, err)
		}
		if len(config.DataPatch) > 0 {
			ctx.Patch = ParsePatch(config.DataPatch)
		}
		ctx.Tags = make(map[string]bool, len(config.PreProcessorTags))
		for _, tag := range config.PreProcessorTags {
			ctx.Tags[strings.ToUpper(tag)] = true
		}
	} else if !os.IsNotExist(err) {
		return ctx, err
	}
	intPattern := regexp.MustCompile(`\b([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\s*;?`)
	strPattern := regexp.MustCompile(`\b([A-Z][A-Z0-9_]*)\s*=\s*"([^"]*)"\s*;?`)
	for _, path := range []string{
		filepath.Join(foreverDB, ".config", "constants", "maps.lua"),
		filepath.Join(root, ".contrib", "Parser", "lib", "Constants", "Maps.lua"),
	} {
		if err := loadAssignments(path, intPattern, func(name, value string) {
			if _, exists := ctx.Maps[name]; !exists {
				parsed, _ := strconv.Atoi(value)
				ctx.Maps[name] = parsed
			}
		}); err != nil {
			return ctx, err
		}
	}
	for _, path := range []string{
		filepath.Join(foreverDB, ".config", "constants", "timelines.lua"),
		filepath.Join(root, ".contrib", "Parser", "lib", "Constants", "Timelines.lua"),
	} {
		if err := loadAssignments(path, strPattern, func(name, value string) {
			if _, exists := ctx.Timelines[name]; !exists {
				ctx.Timelines[name] = value
			}
		}); err != nil {
			return ctx, err
		}
	}
	return ctx, nil
}

func stripJSONC(text string) string {
	lineComment := regexp.MustCompile(`(?m)//.*?$`)
	trailingComma := regexp.MustCompile(`,\s*([}\]])`)
	return trailingComma.ReplaceAllString(lineComment.ReplaceAllString(text, ""), "$1")
}

func loadAssignments(path string, pattern *regexp.Regexp, add func(string, string)) error {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, match := range pattern.FindAllStringSubmatch(string(data), -1) {
		add(match[1], match[2])
	}
	return nil
}
