package attdsl

import (
	"regexp"
	"sort"
	"strconv"
	"strings"
)

type Coord struct {
	MapID int
	X, Y  float64
}

type QuestRecord struct {
	QuestID                                    int
	Coords                                     []Coord
	QGs                                        []int
	SourceQuests                               []int
	SourceQuestNumRequired                     *int
	AltQuests                                  []int
	Races                                      []int
	UnresolvedRaces                            []string
	Classes                                    []int
	RequiredSkill                              any
	Faction                                    string
	MinLevel, MaxLevel                         *int
	IsDaily, IsWeekly, IsYearly, IsMonthly     bool
	Repeatable, IsBreadcrumb, IsWorldQuest     bool
	IsWarEffort, IsAttunement, IsInstanceQuest bool
	Event                                      *int
	SourceFile, ATTTitle                       string
}

type ExtractResult struct {
	Quests                                    map[int]*QuestRecord
	Excluded                                  map[string]int
	FilesParsed, QuestsSeen, QuestsWithCoords int
	Warnings                                  []string
	AttunementQuestIDs                        map[int]bool
	Patch                                     [4]int
}

func NewExtractResult(patch [4]int) *ExtractResult {
	return &ExtractResult{Quests: map[int]*QuestRecord{}, Excluded: map[string]int{}, AttunementQuestIDs: map[int]bool{}, Patch: patch}
}

type walkContext struct {
	instance                        bool
	mapID                           *int
	races, classes, timeline, level any
	npcID                           *int
	npcCoord                        []Coord
	sourceFile                      string
	yearly                          bool
	event                           any
}

func (result *ExtractResult) ExtractRoots(roots []rootRecord, source string) {
	for _, root := range roots {
		result.walk(root.Data, walkContext{sourceFile: source})
	}
}

func (result *ExtractResult) Extract(value any, source string) {
	result.walk(value, walkContext{sourceFile: source})
}

func (result *ExtractResult) walk(value any, ctx walkContext) {
	switch node := value.(type) {
	case *LuaTable:
		result.walkTable(node, ctx)
	case []any:
		for _, item := range node {
			result.walk(item, ctx)
		}
	}
}

func (result *ExtractResult) walkTable(table *LuaTable, ctx walkContext) {
	child := childContext(table, ctx)
	if asInt(table.Get("instanceID")) != nil {
		for _, id := range parseSourceQuests(table) {
			result.AttunementQuestIDs[id] = true
		}
	}
	if questID := asInt(table.Get("questID")); questID != nil && table.Get("objectiveID") == nil {
		result.recordQuest(table, child, *questID)
	}
	result.walk(table.Get("groups"), child)
	result.walk(table.Get("g"), child)
	result.walk(table.Get("allianceQuestData"), child)
	result.walk(table.Get("hordeQuestData"), child)
	if looksLikeObjectArray(table) {
		for _, item := range table.Array {
			result.walk(item, child)
		}
	}
}

func looksLikeObjectArray(table *LuaTable) bool {
	if len(table.Mapping) > 0 {
		return false
	}
	for _, item := range table.Array {
		if _, ok := item.(*LuaTable); ok {
			return true
		}
	}
	return false
}

func childContext(table *LuaTable, ctx walkContext) walkContext {
	mapID := ctx.mapID
	if value := asInt(table.Get("mapID")); value != nil && *value != 0 {
		mapID = value
	}
	races := table.Get("races")
	if races == nil {
		races = ctx.races
	}
	classes := table.Get("classes")
	if classes == nil {
		classes = ctx.classes
	}
	timeline := table.Get("timeline")
	if timeline == nil {
		timeline = ctx.timeline
	}
	level := table.Get("lvl")
	if level == nil {
		level = ctx.level
	}
	npcID, npcCoord := ctx.npcID, ctx.npcCoord
	if id := asInt(table.Get("npcID")); id != nil && *id > 0 {
		npcID = id
		if coords := parseCoords(table, mapID); len(coords) > 0 {
			npcCoord = coords
		}
	}
	yearly := ctx.yearly
	if value := table.Get("isYearly"); value != nil {
		yearly = truthy(value)
	}
	event := table.Get("e")
	if event == nil {
		event = ctx.event
	}
	return walkContext{instance: ctx.instance || asInt(table.Get("instanceID")) != nil, mapID: mapID, races: races, classes: classes, timeline: timeline, level: level, npcID: npcID, npcCoord: npcCoord, sourceFile: ctx.sourceFile, yearly: yearly, event: event}
}

func (result *ExtractResult) recordQuest(table *LuaTable, ctx walkContext, questID int) {
	result.QuestsSeen++
	if shouldExcludeTimeline(firstNotNil(table.Get("timeline"), ctx.timeline), result.Patch) {
		result.Excluded["timeline"]++
		return
	}
	if truthy(table.Get("isWorldQuest")) {
		result.Excluded["world_quest"]++
		return
	}
	coords := parseCoords(table, ctx.mapID)
	if len(coords) == 0 && len(ctx.npcCoord) > 0 {
		coords = append([]Coord(nil), ctx.npcCoord...)
	}
	qgs := parseQGs(table)
	if len(qgs) == 0 && ctx.npcID != nil {
		qgs = []int{*ctx.npcID}
	}
	if len(coords) == 0 {
		result.Excluded["no_coords"]++
		return
	}
	races, unresolvedRaces, faction := parseRaces(firstNotNil(table.Get("races"), ctx.races))
	sourceQuests := parseSourceQuests(table)
	altQuests := parseIntList(firstNotNil(table.Get("altQuests"), table.Get("altQuestID")))
	record := &QuestRecord{
		QuestID: questID, Coords: coords, QGs: qgs, SourceQuests: sourceQuests,
		SourceQuestNumRequired: asInt(table.Get("sourceQuestNumRequired")), AltQuests: altQuests,
		Races: races, UnresolvedRaces: unresolvedRaces, Classes: parseIntList(firstNotNil(table.Get("classes"), ctx.classes)),
		RequiredSkill: parseRequiredSkill(table.Get("requireSkill")), Faction: faction,
		IsDaily: truthy(table.Get("isDaily")), IsWeekly: truthy(table.Get("isWeekly")),
		IsYearly: truthy(firstNotNil(table.Get("isYearly"), ctx.yearly)), IsMonthly: truthy(table.Get("isMonthly")),
		Repeatable: truthy(table.Get("repeatable")), IsInstanceQuest: ctx.instance,
		IsBreadcrumb: truthy(table.Get("isBreadcrumb")), IsWorldQuest: truthy(table.Get("isWorldQuest")),
		Event: asInt(firstNotNil(table.Get("e"), ctx.event)), SourceFile: ctx.sourceFile,
	}
	record.MinLevel, record.MaxLevel = parseLevel(firstNotNil(table.Get("lvl"), ctx.level))
	record.IsWarEffort = isWarEffort(record)
	if existing := result.Quests[questID]; existing != nil {
		mergeRecords(existing, record)
		return
	}
	result.Quests[questID] = record
	result.QuestsWithCoords++
}

func mergeRecords(dst, src *QuestRecord) {
	dst.IsInstanceQuest = dst.IsInstanceQuest || src.IsInstanceQuest
	for _, coord := range src.Coords {
		exists := false
		for _, old := range dst.Coords {
			if old == coord {
				exists = true
				break
			}
		}
		if !exists {
			dst.Coords = append(dst.Coords, coord)
		}
	}
	dst.QGs = uniqueInts(append(dst.QGs, src.QGs...))
	dst.SourceQuests = uniqueInts(append(dst.SourceQuests, src.SourceQuests...))
	dst.AltQuests = uniqueInts(append(dst.AltQuests, src.AltQuests...))
	dst.Races = uniqueInts(append(dst.Races, src.Races...))
	dst.UnresolvedRaces = uniqueStrings(append(dst.UnresolvedRaces, src.UnresolvedRaces...))
	dst.Classes = uniqueInts(append(dst.Classes, src.Classes...))
	if dst.RequiredSkill == nil {
		dst.RequiredSkill = src.RequiredSkill
	}
	if dst.Faction == "" {
		dst.Faction = src.Faction
	}
	if dst.MinLevel == nil {
		dst.MinLevel = src.MinLevel
	}
	if dst.MaxLevel == nil {
		dst.MaxLevel = src.MaxLevel
	}
	if dst.SourceQuestNumRequired == nil {
		dst.SourceQuestNumRequired = src.SourceQuestNumRequired
	}
	dst.IsYearly = dst.IsYearly || src.IsYearly
	if dst.Event == nil {
		dst.Event = src.Event
	}
	dst.IsWarEffort = dst.IsWarEffort || src.IsWarEffort
	dst.IsAttunement = dst.IsAttunement || src.IsAttunement
}

func (result *ExtractResult) MarkAttunementChains() map[int]bool {
	marked, pending := map[int]bool{}, make([]int, 0, len(result.AttunementQuestIDs))
	for id := range result.AttunementQuestIDs {
		pending = append(pending, id)
	}
	for len(pending) > 0 {
		id := pending[len(pending)-1]
		pending = pending[:len(pending)-1]
		if marked[id] {
			continue
		}
		marked[id] = true
		record := result.Quests[id]
		if record == nil {
			continue
		}
		record.IsAttunement = true
		pending = append(pending, record.SourceQuests...)
		pending = append(pending, record.AltQuests...)
	}
	emitted := map[int]bool{}
	for id := range marked {
		if result.Quests[id] != nil {
			emitted[id] = true
		}
	}
	return emitted
}

func parseCoords(table *LuaTable, inheritedMap *int) []Coord {
	raw := firstNotNil(table.Get("coords"), table.Get("coord"))
	entries := coordEntries(raw)
	coords := make([]Coord, 0, len(entries))
	for _, entry := range entries {
		values := sequence(entry)
		if len(values) < 2 {
			continue
		}
		x, xok := numberFloat(values[0])
		y, yok := numberFloat(values[1])
		if !xok || !yok {
			continue
		}
		mapID := inheritedMap
		if len(values) >= 3 {
			mapID = asInt(values[2])
		}
		if mapID != nil {
			coords = append(coords, Coord{MapID: *mapID, X: x, Y: y})
		}
	}
	return coords
}

func coordEntries(value any) []any {
	table, ok := value.(*LuaTable)
	if !ok {
		return nil
	}
	if len(table.Array) > 0 {
		switch table.Array[0].(type) {
		case *LuaTable:
			return table.Array
		case int, float64:
			return []any{table}
		}
		return table.Array
	}
	if len(table.Mapping) > 0 {
		return []any{table}
	}
	return nil
}

func parseQGs(table *LuaTable) []int {
	qgs := parseIntList(firstNotNil(table.Get("qgs"), table.Get("qg")))
	providers := firstNotNil(table.Get("providers"), table.Get("provider"))
	for _, provider := range providerEntries(providers) {
		values := sequence(provider)
		if len(values) >= 2 {
			if name, ok := values[0].(string); ok && strings.EqualFold(name, "n") {
				if id := asInt(values[1]); id != nil && *id != 0 {
					qgs = append(qgs, *id)
				}
			}
		}
	}
	return uniqueInts(qgs)
}

func providerEntries(value any) []any {
	values := sequence(value)
	if len(values) == 0 {
		return nil
	}
	if name, ok := values[0].(string); ok && strings.Contains("|n|i|o|s|", "|"+strings.ToLower(name)+"|") {
		return []any{value}
	}
	return values
}

func parseSourceQuests(table *LuaTable) []int {
	values := parseIntList(table.Get("sourceQuests"))
	if id := asInt(table.Get("sourceQuest")); id != nil {
		values = append(values, *id)
	}
	return uniqueInts(values)
}

func parseRaces(raw any) ([]int, []string, string) {
	if value, ok := raw.(factionRaces); ok {
		return nil, nil, value.Faction
	}
	var numbers []int
	var names []string
	faction := ""
	values := sequence(raw)
	if len(values) == 0 && raw != nil {
		values = []any{raw}
	}
	for _, value := range values {
		if race, ok := value.(factionRaces); ok {
			faction = race.Faction
			continue
		}
		if number := asInt(value); number != nil {
			numbers = append(numbers, *number)
			continue
		}
		switch unknown := value.(type) {
		case unresolved:
			names = append(names, unknown.Name)
		case string:
			names = append(names, unknown)
		}
	}
	return uniqueInts(numbers), uniqueStrings(names), faction
}

func parseIntList(raw any) []int {
	if raw == nil {
		return nil
	}
	if number := asInt(raw); number != nil {
		return []int{*number}
	}
	values := sequence(raw)
	out := make([]int, 0, len(values))
	for _, value := range values {
		if number := asInt(value); number != nil {
			out = append(out, *number)
		}
	}
	return out
}

func parseRequiredSkill(raw any) any {
	if number := asInt(raw); number != nil {
		return *number
	}
	switch value := raw.(type) {
	case unresolved:
		return value.Name
	case string:
		if value != "" {
			return value
		}
	}
	return nil
}

func parseLevel(raw any) (*int, *int) {
	if value := asInt(raw); value != nil {
		return value, nil
	}
	values := sequence(raw)
	numbers := make([]int, 0, len(values))
	for _, item := range values {
		if number := asInt(item); number != nil {
			numbers = append(numbers, *number)
		}
	}
	if len(numbers) == 0 {
		return nil, nil
	}
	if len(numbers) == 1 {
		return intPtr(numbers[0]), nil
	}
	return intPtr(numbers[0]), intPtr(numbers[1])
}

var timelineText = regexp.MustCompile(`(?i)^(created|added|removed|deleted)\s+(\d+(?:\.\d+)*)`)
var timelineName = regexp.MustCompile(`(?i)^(CREATED|ADDED|REMOVED|DELETED)_(\d+)_(\d+)(?:_(\d+))?`)

func timelineKindVersion(value any) (string, [4]int, bool) {
	text := strings.TrimSpace(luaString(value))
	if match := timelineText.FindStringSubmatch(text); match != nil {
		patch, ok := ParseVersionToken(match[2])
		return strings.ToLower(match[1]), patch, ok
	}
	if match := timelineName.FindStringSubmatch(text); match != nil {
		patchText := match[4]
		if patchText == "" {
			patchText = "0"
		}
		major, _ := strconv.Atoi(match[2])
		minor, _ := strconv.Atoi(match[3])
		sub, _ := strconv.Atoi(patchText)
		return strings.ToLower(match[1]), [4]int{major, minor, sub, 0}, true
	}
	return "", [4]int{}, false
}

func shouldExcludeTimeline(raw any, patch [4]int) bool {
	events := sequence(raw)
	if len(events) == 0 {
		if _, ok := raw.(string); ok {
			events = []any{raw}
		}
	}
	var added, removed [][4]int
	created, deleted := false, false
	for _, event := range events {
		kind, version, ok := timelineKindVersion(event)
		if !ok {
			continue
		}
		switch kind {
		case "added":
			added = append(added, version)
		case "removed":
			removed = append(removed, version)
		case "created":
			created = true
		case "deleted":
			deleted = true
		}
	}
	if deleted || created && len(added) == 0 {
		return true
	}
	if len(added) > 0 {
		found := false
		for _, version := range added {
			if comparePatch(version, patch) <= 0 {
				found = true
			}
		}
		if !found {
			return true
		}
	}
	for _, version := range removed {
		if comparePatch(version, patch) <= 0 {
			return true
		}
	}
	return false
}

func sequence(value any) []any {
	switch typed := value.(type) {
	case *LuaTable:
		if len(typed.Array) > 0 {
			return typed.Array
		}
		entries := typed.Items()
		sort.Slice(entries, func(i, j int) bool { return luaString(entries[i].Key) < luaString(entries[j].Key) })
		values := make([]any, 0, len(entries))
		for _, item := range entries {
			values = append(values, item.Value)
		}
		return values
	case []any:
		return typed
	case []int:
		values := make([]any, len(typed))
		for index, item := range typed {
			values[index] = item
		}
		return values
	}
	return nil
}

func asInt(value any) *int {
	switch number := value.(type) {
	case int:
		return intPtr(number)
	case int64:
		return intPtr(int(number))
	case float64:
		if number == float64(int(number)) {
			return intPtr(int(number))
		}
	}
	return nil
}

func numberFloat(value any) (float64, bool) { number, ok := numeric(value); return number, ok }
func intPtr(value int) *int                 { return &value }
func firstNotNil(values ...any) any {
	for _, value := range values {
		if value != nil {
			return value
		}
	}
	return nil
}
func uniqueInts(values []int) []int {
	seen := map[int]bool{}
	out := make([]int, 0, len(values))
	for _, value := range values {
		if !seen[value] {
			seen[value] = true
			out = append(out, value)
		}
	}
	return out
}
func uniqueStrings(values []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if !seen[value] {
			seen[value] = true
			out = append(out, value)
		}
	}
	return out
}

var warEffortNPCs = map[int]bool{15383: true, 15431: true, 15432: true, 15434: true, 15437: true, 15445: true, 15446: true, 15448: true, 15450: true, 15451: true, 15452: true, 15453: true, 15455: true, 15456: true, 15457: true, 15459: true, 15460: true, 15469: true, 15477: true, 15508: true, 15512: true, 15515: true, 15522: true, 15525: true, 15528: true, 15529: true, 15532: true, 15533: true, 15534: true, 15535: true, 15704: true, 15707: true}

func isWarEffort(record *QuestRecord) bool {
	if record.QuestID >= 8780 && record.QuestID <= 8789 {
		return true
	}
	for _, npc := range record.QGs {
		if warEffortNPCs[npc] {
			return true
		}
	}
	return false
}
