package compile

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/TylerAkins/forever-quest-markers/internal/zones"
)

const schemaVersion = 2

var holidaySorts = map[string]bool{
	"WINTER_VEIL":        true,
	"HARVEST_FESTIVAL":   true,
	"CHILDRENS_WEEK":     true,
	"LOVE_IS_IN_THE_AIR": true,
	"PILGRIMS_BOUNTY":    true,
	"NOBLEGARDEN":        true,
	"BREWFEST":           true,
	"MIDSUMMER":          true,
	"LUNAR_FESTIVAL":     true,
	"DARKMOON_FAIRE":     true,
	"DAY_OF_THE_DEAD":    true,
	"SEASONAL":           true,
	"HALLOWS_END":        true,
}

// Options selects the published wow-database export and the addon Database directory.
type Options struct {
	ExportDir      string
	OutDir         string
	DatabaseCommit string
	Check          bool
}

type manifestFile struct {
	SchemaVersion int    `json:"schemaVersion"`
	Commit        string `json:"commit"`
	Shards        []struct {
		Path string `json:"path"`
	} `json:"shards"`
}

type shardFile struct {
	SchemaVersion int                    `json:"schemaVersion"`
	Quests        map[string]exportQuest `json:"quests"`
}

type exportQuest struct {
	ID                   int        `json:"id"`
	Faction              string     `json:"faction"`
	StartedBy            []provider `json:"startedBy"`
	FinishedBy           []provider `json:"finishedBy"`
	Places               []place    `json:"places"`
	PreQuestGroup        []int      `json:"preQuestGroup"`
	PreQuestSingle       []int      `json:"preQuestSingle"`
	ExclusiveTo          []int      `json:"exclusiveTo"`
	BreadcrumbForQuestID int        `json:"breadcrumbForQuestId"`
	RequiredLevel        int        `json:"requiredLevel"`
	RequiredRaces        []int      `json:"requiredRaces"`
	RequiredClasses      []int      `json:"requiredClasses"`
	RequiredSkill        *skill     `json:"requiredSkill"`
	QuestType            questType  `json:"questType"`
}

type provider struct {
	ID   int    `json:"id"`
	Type string `json:"type"`
}

type place struct {
	ID     int         `json:"id"`
	Type   string      `json:"type"`
	Role   string      `json:"role"`
	Spawns [][]float64 `json:"spawns"`
}

type skill struct {
	SkillID int `json:"skillId"`
	Value   int `json:"value"`
}

type questType struct {
	Repeatable bool   `json:"repeatable"`
	Daily      bool   `json:"daily"`
	Weekly     bool   `json:"weekly"`
	Monthly    bool   `json:"monthly"`
	Dungeon    bool   `json:"dungeon"`
	Raid       bool   `json:"raid"`
	Sort       string `json:"sort"`
}

type coord struct {
	mapID int
	x     float64
	y     float64
}

type record struct {
	id                     int
	coords                 []coord
	starters               []int
	turnIns                []int
	sourceQuests           []int
	sourceQuestNumRequired *int
	altQuests              []int
	faction                string
	races                  []int
	classes                []int
	requireSkill           int
	minLevel               int
	breadcrumb             bool
	repeatable             bool
	daily                  bool
	weekly                 bool
	monthly                bool
	warEffort              bool
	instance               bool
	yearly                 bool
}

// Run writes Database Lua and the build report, or compares them when Check is set.
func Run(opts Options) error {
	if opts.ExportDir == "" {
		return fmt.Errorf("export directory is required")
	}
	if opts.OutDir == "" {
		return fmt.Errorf("output directory is required")
	}
	if !commitPattern(opts.DatabaseCommit) {
		return fmt.Errorf("database commit must be a git sha")
	}
	files, err := renderExport(opts.ExportDir, opts.DatabaseCommit)
	if err != nil {
		return err
	}
	if opts.Check {
		return compare(opts.OutDir, files)
	}
	return write(opts.OutDir, files)
}

func renderExport(exportDir, databaseCommit string) (map[string][]byte, error) {
	manifest, quests, err := loadExport(exportDir)
	if err != nil {
		return nil, err
	}
	records := make([]record, 0, len(quests))
	for _, quest := range quests {
		row, err := mapQuest(quest)
		if err != nil {
			return nil, err
		}
		records = append(records, row)
	}
	sort.Slice(records, func(i, j int) bool { return records[i].id < records[j].id })
	return render(records, manifest.Commit, databaseCommit)
}

func loadExport(exportDir string) (manifestFile, []exportQuest, error) {
	raw, err := os.ReadFile(filepath.Join(exportDir, "manifest.json"))
	if err != nil {
		return manifestFile{}, nil, err
	}
	var manifest manifestFile
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return manifestFile{}, nil, fmt.Errorf("manifest: %w", err)
	}
	if manifest.SchemaVersion != schemaVersion {
		return manifestFile{}, nil, fmt.Errorf("manifest schemaVersion %d", manifest.SchemaVersion)
	}
	if !commitPattern(manifest.Commit) {
		return manifestFile{}, nil, fmt.Errorf("manifest commit must be a git sha")
	}
	if len(manifest.Shards) == 0 {
		return manifestFile{}, nil, fmt.Errorf("manifest has no shards")
	}
	seen := map[int]bool{}
	var quests []exportQuest
	for _, shard := range manifest.Shards {
		if shard.Path == "" || filepath.IsAbs(shard.Path) || strings.Contains(shard.Path, "..") {
			return manifestFile{}, nil, fmt.Errorf("invalid shard path %q", shard.Path)
		}
		body, err := os.ReadFile(filepath.Join(exportDir, filepath.FromSlash(shard.Path)))
		if err != nil {
			return manifestFile{}, nil, err
		}
		var file shardFile
		if err := json.Unmarshal(body, &file); err != nil {
			return manifestFile{}, nil, fmt.Errorf("%s: %w", shard.Path, err)
		}
		if file.SchemaVersion != schemaVersion {
			return manifestFile{}, nil, fmt.Errorf("%s: schemaVersion %d", shard.Path, file.SchemaVersion)
		}
		for key, quest := range file.Quests {
			if quest.ID == 0 {
				id, err := strconv.Atoi(key)
				if err != nil {
					return manifestFile{}, nil, fmt.Errorf("%s: quest key %s", shard.Path, key)
				}
				quest.ID = id
			}
			if seen[quest.ID] {
				return manifestFile{}, nil, fmt.Errorf("duplicate quest %d", quest.ID)
			}
			seen[quest.ID] = true
			quests = append(quests, quest)
		}
	}
	if len(quests) == 0 {
		return manifestFile{}, nil, fmt.Errorf("empty quest list")
	}
	return manifest, quests, nil
}

func mapQuest(quest exportQuest) (record, error) {
	if len(quest.PreQuestGroup) > 0 && len(quest.PreQuestSingle) > 0 {
		return record{}, fmt.Errorf("quest %d: preQuestGroup and preQuestSingle are both set", quest.ID)
	}
	row := record{
		id:         quest.ID,
		starters:   npcIDs(quest.StartedBy, quest.Places, "available"),
		turnIns:    npcIDs(quest.FinishedBy, quest.Places, "turnIn"),
		altQuests:  sortedCopy(quest.ExclusiveTo),
		races:      sortedCopy(quest.RequiredRaces),
		classes:    sortedCopy(quest.RequiredClasses),
		minLevel:   quest.RequiredLevel,
		breadcrumb: quest.BreadcrumbForQuestID != 0,
		daily:      quest.QuestType.Daily,
		weekly:     quest.QuestType.Weekly,
		monthly:    quest.QuestType.Monthly,
		repeatable: quest.QuestType.Repeatable || quest.QuestType.Daily || quest.QuestType.Weekly || quest.QuestType.Monthly,
		warEffort:  quest.QuestType.Sort == "AHN_QIRAJ_WAR",
		instance:   quest.QuestType.Dungeon || quest.QuestType.Raid,
		yearly:     holidaySorts[quest.QuestType.Sort],
	}
	switch quest.Faction {
	case "", "Both":
	case "Alliance", "Horde":
		row.faction = quest.Faction
	default:
		return record{}, fmt.Errorf("quest %d: unknown faction %q", quest.ID, quest.Faction)
	}
	if quest.RequiredSkill != nil {
		row.requireSkill = quest.RequiredSkill.SkillID
	}
	if len(quest.PreQuestGroup) > 0 {
		row.sourceQuests = sortedCopy(quest.PreQuestGroup)
	} else if len(quest.PreQuestSingle) > 0 {
		row.sourceQuests = sortedCopy(quest.PreQuestSingle)
		required := 1
		row.sourceQuestNumRequired = &required
	}
	coords, err := availableCoords(quest)
	if err != nil {
		return record{}, err
	}
	row.coords = coords
	return row, nil
}

func availableCoords(quest exportQuest) ([]coord, error) {
	seen := map[coord]bool{}
	var coords []coord
	for _, spot := range quest.Places {
		if spot.Role != "available" {
			continue
		}
		for _, spawn := range spot.Spawns {
			if len(spawn) != 3 {
				return nil, fmt.Errorf("quest %d: spawn must be [zoneId, x, y]", quest.ID)
			}
			x, y := spawn[1], spawn[2]
			if x < 0 || y < 0 {
				continue
			}
			zoneID := int(spawn[0])
			if float64(zoneID) != spawn[0] {
				return nil, fmt.Errorf("quest %d: zone id %v", quest.ID, spawn[0])
			}
			uiMapID, ok := zones.UIMap(zoneID)
			if !ok {
				return nil, fmt.Errorf("quest %d: unknown zone %d", quest.ID, zoneID)
			}
			if uiMapID == 0 {
				continue
			}
			point := coord{mapID: uiMapID, x: round4(x), y: round4(y)}
			if seen[point] {
				continue
			}
			seen[point] = true
			coords = append(coords, point)
		}
	}
	sort.Slice(coords, func(i, j int) bool {
		if coords[i].mapID != coords[j].mapID {
			return coords[i].mapID < coords[j].mapID
		}
		if coords[i].x != coords[j].x {
			return coords[i].x < coords[j].x
		}
		return coords[i].y < coords[j].y
	})
	return coords, nil
}

func npcIDs(providers []provider, places []place, role string) []int {
	seen := map[int]bool{}
	var ids []int
	for _, item := range providers {
		if item.Type == "npc" && item.ID != 0 && !seen[item.ID] {
			seen[item.ID] = true
			ids = append(ids, item.ID)
		}
	}
	for _, spot := range places {
		if spot.Role == role && spot.Type == "npc" && spot.ID != 0 && !seen[spot.ID] {
			seen[spot.ID] = true
			ids = append(ids, spot.ID)
		}
	}
	sort.Ints(ids)
	return ids
}

func sortedCopy(values []int) []int {
	if len(values) == 0 {
		return nil
	}
	out := append([]int(nil), values...)
	sort.Ints(out)
	return out
}

func round4(value float64) float64 {
	return math.Round(value*10000) / 10000
}

func commitPattern(value string) bool {
	if len(value) < 7 || len(value) > 40 {
		return false
	}
	for _, char := range value {
		switch {
		case char >= '0' && char <= '9':
		case char >= 'a' && char <= 'f':
		default:
			return false
		}
	}
	return true
}

func render(records []record, questieCommit, databaseCommit string) (map[string][]byte, error) {
	byMap := map[int][]int{}
	coordPins := 0
	withCoords := 0
	var quests bytes.Buffer
	quests.WriteString(luaHeader(false))
	quests.WriteString("ns.Quests = {\n")
	for _, row := range records {
		fmt.Fprintf(&quests, "\t[%d] = { %s },\n", row.id, questBody(row))
		if len(row.coords) == 0 {
			continue
		}
		withCoords++
		coordPins += len(row.coords)
		seen := map[int]bool{}
		for _, point := range row.coords {
			if seen[point.mapID] {
				continue
			}
			seen[point.mapID] = true
			byMap[point.mapID] = append(byMap[point.mapID], row.id)
		}
	}
	quests.WriteString("}\n\nns.ByMap = {\n")
	mapIDs := make([]int, 0, len(byMap))
	for mapID := range byMap {
		mapIDs = append(mapIDs, mapID)
	}
	sort.Ints(mapIDs)
	for _, mapID := range mapIDs {
		ids := byMap[mapID]
		sort.Ints(ids)
		fmt.Fprintf(&quests, "\t[%d] = { %s },\n", mapID, joinInts(ids))
	}
	quests.WriteString("}\n")

	var meta bytes.Buffer
	meta.WriteString(luaHeader(true))
	meta.WriteString("ns.Metadata = {\n")
	fmt.Fprintf(&meta, "\tsource = \"Questie/QuestieDB\",\n")
	fmt.Fprintf(&meta, "\tquestieCommit = %q,\n", questieCommit)
	fmt.Fprintf(&meta, "\tdatabaseCommit = %q,\n", databaseCommit)
	fmt.Fprintf(&meta, "\tquestCount = %d,\n", len(records))
	fmt.Fprintf(&meta, "\tcoordCount = %d,\n", coordPins)
	fmt.Fprintf(&meta, "\tmapCount = %d,\n", len(byMap))
	meta.WriteString("\tgeneratedBy = \"cmd/compile\",\n")
	meta.WriteString("}\n")

	report, err := json.MarshalIndent(map[string]any{
		"coord_pins":         coordPins,
		"database_commit":    databaseCommit,
		"map_count":          len(byMap),
		"questie_commit":     questieCommit,
		"quests_emitted":     len(records),
		"quests_with_coords": withCoords,
		"schema_version":     schemaVersion,
		"tooltip_only":       len(records) - withCoords,
	}, "", "  ")
	if err != nil {
		return nil, err
	}
	report = append(report, '\n')
	return map[string][]byte{
		"ForeverQuests.lua": quests.Bytes(),
		"Metadata.lua":      meta.Bytes(),
		"build_report.json": report,
	}, nil
}

func luaHeader(metadata bool) string {
	lines := []string{
		"-- AUTO-GENERATED FILE",
		"-- DO NOT EDIT MANUALLY",
		"-- Source: Questie/QuestieDB",
		"-- Generated by cmd/compile",
	}
	if !metadata {
		lines = append(lines,
			"--",
			"-- Compact quest records keyed by questID. Coordinates are 0-100 on a Blizzard UiMapID.",
		)
	}
	return strings.Join(lines, "\n") + "\n\nlocal ADDON_NAME, ns = ...\n"
}

func questBody(row record) string {
	var parts []string
	if len(row.coords) > 0 {
		primary := row.coords[0]
		parts = append(parts,
			fmt.Sprintf("mapID=%d", primary.mapID),
			"x="+formatNum(primary.x),
			"y="+formatNum(primary.y),
		)
		if len(row.coords) > 1 {
			points := make([]string, len(row.coords))
			for i, point := range row.coords {
				points[i] = fmt.Sprintf("{ %s, %s, %d }", formatNum(point.x), formatNum(point.y), point.mapID)
			}
			parts = append(parts, "coords={ "+strings.Join(points, ", ")+" }")
		}
	}
	if len(row.starters) == 1 {
		parts = append(parts, fmt.Sprintf("qg=%d", row.starters[0]))
	} else if len(row.starters) > 1 {
		parts = append(parts, "qgs={ "+joinInts(row.starters)+" }")
	}
	if len(row.turnIns) > 0 {
		parts = append(parts, "turnIns={ "+joinInts(row.turnIns)+" }")
	}
	if len(row.sourceQuests) > 0 {
		parts = append(parts, "sourceQuests={ "+joinInts(row.sourceQuests)+" }")
	}
	if row.sourceQuestNumRequired != nil {
		parts = append(parts, fmt.Sprintf("sourceQuestNumRequired=%d", *row.sourceQuestNumRequired))
	}
	if len(row.altQuests) > 0 {
		parts = append(parts, "altQuests={ "+joinInts(row.altQuests)+" }")
	}
	if row.faction != "" {
		parts = append(parts, fmt.Sprintf("faction=%q", row.faction))
	}
	if len(row.races) > 0 {
		parts = append(parts, "races={ "+joinInts(row.races)+" }")
	}
	if len(row.classes) > 0 {
		parts = append(parts, "classes={ "+joinInts(row.classes)+" }")
	}
	if row.requireSkill != 0 {
		parts = append(parts, fmt.Sprintf("requireSkill=%d", row.requireSkill))
	}
	if row.minLevel != 0 {
		parts = append(parts, fmt.Sprintf("minLevel=%d", row.minLevel))
	}
	if row.breadcrumb {
		parts = append(parts, "isBreadcrumb=true")
	}
	if row.repeatable {
		parts = append(parts, "repeatable=true")
	}
	if row.daily {
		parts = append(parts, "isDaily=true")
	}
	if row.weekly {
		parts = append(parts, "isWeekly=true")
	}
	if row.monthly {
		parts = append(parts, "isMonthly=true")
	}
	if row.warEffort {
		parts = append(parts, "isWarEffort=true")
	}
	if row.instance {
		parts = append(parts, "isInstanceQuest=true")
	}
	if row.yearly {
		parts = append(parts, "isYearly=true")
	}
	return strings.Join(parts, ", ")
}

func joinInts(values []int) string {
	parts := make([]string, len(values))
	for i, value := range values {
		parts[i] = strconv.Itoa(value)
	}
	return strings.Join(parts, ", ")
}

func formatNum(value float64) string {
	if value == math.Trunc(value) {
		return strconv.FormatInt(int64(value), 10)
	}
	text := strconv.FormatFloat(value, 'f', 4, 64)
	text = strings.TrimRight(text, "0")
	text = strings.TrimRight(text, ".")
	return text
}

func compare(dir string, files map[string][]byte) error {
	for name, body := range files {
		existing, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return fmt.Errorf("check %s: %w", name, err)
		}
		if !bytes.Equal(existing, body) {
			return fmt.Errorf("check %s: published bytes differ", name)
		}
	}
	return nil
}

func write(dir string, files map[string][]byte) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for name, body := range files {
		target := filepath.Join(dir, name)
		temp, err := os.CreateTemp(dir, name+".")
		if err != nil {
			return err
		}
		tempName := temp.Name()
		_, writeErr := temp.Write(body)
		closeErr := temp.Close()
		if writeErr != nil {
			_ = os.Remove(tempName)
			return writeErr
		}
		if closeErr != nil {
			_ = os.Remove(tempName)
			return closeErr
		}
		if err := os.Rename(tempName, target); err != nil {
			_ = os.Remove(tempName)
			return err
		}
	}
	return nil
}
