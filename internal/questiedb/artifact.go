package questiedb

import (
	"archive/zip"
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// ContractVersion is the QuestieDB TOC contract this reader implements.
const ContractVersion = 4

// Flavor is the QuestieDB build flavor consumed by this addon.
const Flavor = "Forever"

// Artifact is an opened QuestieDB zip or extracted directory.
type Artifact struct {
	Path            string
	Directory       string
	Version         string
	BuildCommit     string
	BuildTime       string
	ContractVersion int
	Flavor          string
	Metadata        map[string]string

	fsys   fs.FS
	closer io.Closer
	root   string

	ids       map[string][]int
	idsLoaded map[string]bool
	idSets    map[string]map[int]bool
	scalars   map[string]any
	quests    map[int]*Quest
	npcs      map[int]*NPC
	objects   map[int]*Object
	items     map[int]*Item
}

// OpenArtifact opens a QuestieDB artifact zip or extracted directory and
// validates the TOC contract and flavor.
func OpenArtifact(filePath string) (*Artifact, error) {
	artifact := &Artifact{
		Path:      filePath,
		Metadata:  map[string]string{},
		ids:       map[string][]int{},
		idsLoaded: map[string]bool{},
		idSets:    map[string]map[int]bool{},
		scalars:   map[string]any{},
		quests:    map[int]*Quest{},
		npcs:      map[int]*NPC{},
		objects:   map[int]*Object{},
		items:     map[int]*Item{},
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		artifact.fsys = os.DirFS(filePath)
	} else {
		reader, err := zip.OpenReader(filePath)
		if err != nil {
			return nil, fmt.Errorf("open QuestieDB zip: %w", err)
		}
		artifact.closer = reader
		artifact.fsys = &reader.Reader
	}
	tocPath, err := findTOC(artifact.fsys)
	if err != nil {
		artifact.Close()
		return nil, err
	}
	artifact.root = path.Dir(tocPath)
	if artifact.root == "." {
		artifact.root = ""
	}
	if err := artifact.readMetadata(tocPath); err != nil {
		artifact.Close()
		return nil, err
	}
	if err := artifact.validate(); err != nil {
		artifact.Close()
		return nil, err
	}
	return artifact, nil
}

func (artifact *Artifact) Close() error {
	if artifact.closer != nil {
		return artifact.closer.Close()
	}
	return nil
}

func findTOC(fsys fs.FS) (string, error) {
	candidates := []string{
		"QuestieDB/QuestieDB_Forever.toc",
		"QuestieDB_Forever.toc",
	}
	for _, candidate := range candidates {
		if info, err := fs.Stat(fsys, candidate); err == nil && !info.IsDir() {
			return candidate, nil
		}
	}
	var found []string
	err := fs.WalkDir(fsys, ".", func(name string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !entry.IsDir() && strings.EqualFold(path.Base(name), "QuestieDB_Forever.toc") {
			found = append(found, name)
		}
		return nil
	})
	if err != nil {
		return "", fmt.Errorf("find QuestieDB TOC: %w", err)
	}
	if len(found) == 0 {
		return "", fmt.Errorf("QuestieDB TOC not found in %s", fsys)
	}
	if len(found) > 1 {
		sort.Strings(found)
		return "", fmt.Errorf("multiple QuestieDB TOCs found: %s", strings.Join(found, ", "))
	}
	return found[0], nil
}

func (artifact *Artifact) readMetadata(tocPath string) error {
	file, err := artifact.fsys.Open(tocPath)
	if err != nil {
		return fmt.Errorf("open QuestieDB TOC: %w", err)
	}
	defer file.Close()
	reader := bufio.NewReaderSize(file, 64*1024)
	for {
		line, err := reader.ReadString('\n')
		if len(line) > 0 {
			line = strings.TrimSuffix(line, "\n")
			line = strings.TrimSuffix(line, "\r")
			if strings.HasPrefix(line, "## ") {
				rest := line[3:]
				colon := strings.IndexByte(rest, ':')
				if colon <= 0 {
					return fmt.Errorf("malformed QuestieDB TOC line %q", line)
				}
				key := strings.TrimSpace(rest[:colon])
				value := rest[colon+1:]
				if strings.HasPrefix(value, " ") {
					value = value[1:]
				}
				artifact.Metadata[key] = value
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("read QuestieDB TOC: %w", err)
		}
	}
	return nil
}

func (artifact *Artifact) validate() error {
	artifact.Version = artifact.Metadata["Version"]
	artifact.BuildCommit = artifact.Metadata["X-BUILD-COMMIT"]
	artifact.BuildTime = artifact.Metadata["X-BUILD-TIME"]
	artifact.Flavor = artifact.Metadata["X-Flavor"]
	contract := artifact.Metadata["X-Contract-Version"]
	if contract == "" {
		return fmt.Errorf("QuestieDB TOC is missing X-Contract-Version")
	}
	number, err := strconv.Atoi(contract)
	if err != nil {
		return fmt.Errorf("QuestieDB X-Contract-Version %q is not an integer", contract)
	}
	if number != ContractVersion {
		return fmt.Errorf("QuestieDB contract version %d is unsupported (want %d)", number, ContractVersion)
	}
	artifact.ContractVersion = number
	if !strings.EqualFold(artifact.Flavor, Flavor) {
		return fmt.Errorf("QuestieDB flavor %q is unsupported (want %q)", artifact.Flavor, Flavor)
	}
	if artifact.BuildCommit == "" {
		return fmt.Errorf("QuestieDB TOC is missing X-BUILD-COMMIT")
	}
	return nil
}

// VerifyArtifactSHA256 checks a zip artifact against an expected digest.
func VerifyArtifactSHA256(filePath, expected string) (string, error) {
	expected = strings.ToLower(strings.TrimSpace(expected))
	if expected == "" {
		return "", nil
	}
	info, err := os.Stat(filePath)
	if err != nil {
		return "", err
	}
	if info.IsDir() {
		return "", fmt.Errorf("artifact SHA verification requires a zip, not a directory")
	}
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}
	actual := hex.EncodeToString(hash.Sum(nil))
	if actual != expected {
		return actual, fmt.Errorf("QuestieDB artifact SHA-256 mismatch: got %s, want %s", actual, expected)
	}
	return actual, nil
}

// ArtifactSHA256 computes the digest of a zip artifact.
func ArtifactSHA256(filePath string) (string, error) {
	info, err := os.Stat(filePath)
	if err != nil {
		return "", err
	}
	if info.IsDir() {
		return "", nil
	}
	file, err := os.Open(filePath)
	if err != nil {
		return "", err
	}
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func (artifact *Artifact) readRelative(name string) ([]byte, error) {
	full := name
	if artifact.root != "" {
		full = path.Join(artifact.root, name)
	}
	data, err := fs.ReadFile(artifact.fsys, full)
	if err != nil {
		return nil, fmt.Errorf("read QuestieDB file %s: %w", full, err)
	}
	return data, nil
}

var chunkPattern = regexp.MustCompile(`^~(\d+)~$`)

func (artifact *Artifact) stored(key string) (string, error) {
	raw, ok := artifact.Metadata[key]
	if !ok {
		return "", fmt.Errorf("QuestieDB TOC is missing %s", key)
	}
	match := chunkPattern.FindStringSubmatch(strings.TrimSpace(raw))
	if match == nil {
		return raw, nil
	}
	count, err := strconv.Atoi(match[1])
	if err != nil {
		return "", fmt.Errorf("invalid chunk count for %s", key)
	}
	var builder strings.Builder
	for index := 1; index <= count; index++ {
		chunkKey := fmt.Sprintf("%s-%d", key, index)
		chunk, ok := artifact.Metadata[chunkKey]
		if !ok {
			return "", fmt.Errorf("QuestieDB TOC is missing %s", chunkKey)
		}
		builder.WriteString(chunk)
	}
	return builder.String(), nil
}

// IDs returns the sorted entity IDs listed by the TOC.
func (artifact *Artifact) IDs(entity string) ([]int, error) {
	if artifact.idsLoaded[entity] {
		return artifact.ids[entity], nil
	}
	key := fmt.Sprintf("X-%s-IDS", entity)
	stored, err := artifact.stored(key)
	if err != nil {
		return nil, err
	}
	value, err := DecodeBaked(stored, true)
	if err != nil {
		return nil, fmt.Errorf("decode %s: %w", key, err)
	}
	ids := Ints(value)
	if len(ids) == 0 {
		return nil, fmt.Errorf("%s contains no IDs", key)
	}
	artifact.ids[entity] = ids
	artifact.idsLoaded[entity] = true
	set := make(map[int]bool, len(ids))
	for _, id := range ids {
		set[id] = true
	}
	artifact.idSets[entity] = set
	return ids, nil
}

func (artifact *Artifact) hasID(entity string, id int) (bool, error) {
	if _, err := artifact.IDs(entity); err != nil {
		return false, err
	}
	return artifact.idSets[entity][id], nil
}

func (artifact *Artifact) scalar(entity string, id int) (any, error) {
	key := fmt.Sprintf("%s:%d", entity, id)
	if cached, ok := artifact.scalars[key]; ok {
		return cached, nil
	}
	raw, err := artifact.stored(fmt.Sprintf("X-%s-%d-S", entity, id))
	if err != nil {
		return nil, err
	}
	value, err := DecodeBaked(raw, false)
	if err != nil {
		return nil, fmt.Errorf("decode %s scalar: %w", entity, err)
	}
	artifact.scalars[key] = value
	return value, nil
}

func (artifact *Artifact) field(entity string, id, index int, scalar any) (any, error) {
	key := fmt.Sprintf("X-%s-%d-%d", entity, id, index)
	if _, ok := artifact.Metadata[key]; ok {
		raw, err := artifact.stored(key)
		if err != nil {
			return nil, err
		}
		value, err := DecodeBaked(raw, false)
		if err != nil {
			return nil, fmt.Errorf("decode %s: %w", key, err)
		}
		return value, nil
	}
	return MapGet(scalar, index), nil
}

func stringValue(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case []byte:
		return string(typed)
	default:
		return ""
	}
}

func intValue(value any) int {
	number, _ := Int(value)
	return number
}

// Quest returns one decoded quest, or nil when the ID is absent.
func (artifact *Artifact) Quest(id int) (*Quest, error) {
	if quest, ok := artifact.quests[id]; ok {
		return quest, nil
	}
	known, err := artifact.hasID("Quest", id)
	if err != nil {
		return nil, err
	}
	if !known {
		artifact.quests[id] = nil
		return nil, nil
	}
	scalar, err := artifact.scalar("Quest", id)
	if err != nil {
		return nil, err
	}
	nameValue, err := artifact.field("Quest", id, 1, scalar)
	if err != nil {
		return nil, err
	}
	startedValue, err := artifact.field("Quest", id, 2, scalar)
	if err != nil {
		return nil, err
	}
	finishedValue, err := artifact.field("Quest", id, 3, scalar)
	if err != nil {
		return nil, err
	}
	races, err := artifact.numberField("Quest", id, 6, scalar)
	if err != nil {
		return nil, err
	}
	classes, err := artifact.numberField("Quest", id, 7, scalar)
	if err != nil {
		return nil, err
	}
	requiredLevel, err := artifact.numberField("Quest", id, 4, scalar)
	if err != nil {
		return nil, err
	}
	questLevel, err := artifact.numberField("Quest", id, 5, scalar)
	if err != nil {
		return nil, err
	}
	zone, err := artifact.numberField("Quest", id, 17, scalar)
	if err != nil {
		return nil, err
	}
	specialFlags, err := artifact.numberField("Quest", id, 24, scalar)
	if err != nil {
		return nil, err
	}
	flags, err := artifact.numberField("Quest", id, 23, scalar)
	if err != nil {
		return nil, err
	}
	breadcrumbFor, err := artifact.numberField("Quest", id, 27, scalar)
	if err != nil {
		return nil, err
	}
	preGroup, err := artifact.listField("Quest", id, 12, scalar)
	if err != nil {
		return nil, err
	}
	preSingle, err := artifact.listField("Quest", id, 13, scalar)
	if err != nil {
		return nil, err
	}
	exclusive, err := artifact.listField("Quest", id, 16, scalar)
	if err != nil {
		return nil, err
	}
	breadcrumbs, err := artifact.listField("Quest", id, 28, scalar)
	if err != nil {
		return nil, err
	}
	skillValue, err := artifact.field("Quest", id, 18, scalar)
	if err != nil {
		return nil, err
	}
	var skill *Skill
	if pair, ok := skillValue.(*LuaTable); ok {
		skill = &Skill{ID: intValue(pair.Get(1)), Rank: intValue(pair.Get(2))}
	} else if values := Array(skillValue); len(values) > 0 {
		skill = &Skill{ID: intValue(values[0])}
		if len(values) > 1 {
			skill.Rank = intValue(values[1])
		}
	}
	if skill != nil && skill.ID == 0 {
		skill = nil
	}
	quest := &Quest{
		ID:              id,
		Name:            stringValue(nameValue),
		StartedBy:       parseIDGroups(startedValue, 3),
		FinishedBy:      parseIDGroups(finishedValue, 2),
		RequiredLevel:   requiredLevel,
		QuestLevel:      questLevel,
		RequiredRaces:   uint64(max(races, 0)),
		RequiredClasses: uint16(max(classes, 0)),
		PreQuestGroup:   preGroup,
		PreQuestSingle:  preSingle,
		ExclusiveTo:     exclusive,
		Breadcrumbs:     breadcrumbs,
		BreadcrumbFor:   breadcrumbFor,
		ZoneOrSort:      zone,
		RequiredSkill:   skill,
		SpecialFlags:    specialFlags,
		Flags:           flags,
	}
	artifact.quests[id] = quest
	return quest, nil
}

func (artifact *Artifact) numberField(entity string, id, index int, scalar any) (int, error) {
	value, err := artifact.field(entity, id, index, scalar)
	if err != nil {
		return 0, err
	}
	return intValue(value), nil
}

func (artifact *Artifact) listField(entity string, id, index int, scalar any) ([]int, error) {
	value, err := artifact.field(entity, id, index, scalar)
	if err != nil {
		return nil, err
	}
	return Ints(value), nil
}

type IDGroups struct {
	NPCs    []int
	Objects []int
	Items   []int
}

func parseIDGroups(value any, maxGroup int) IDGroups {
	groups := IDGroups{}
	for group := 1; group <= maxGroup; group++ {
		ids := Ints(MapGet(value, group))
		switch group {
		case 1:
			groups.NPCs = ids
		case 2:
			groups.Objects = ids
		case 3:
			groups.Items = ids
		}
	}
	return groups
}

type Skill struct {
	ID   int
	Rank int
}

type Quest struct {
	ID              int
	Name            string
	StartedBy       IDGroups
	FinishedBy      IDGroups
	RequiredLevel   int
	QuestLevel      int
	RequiredRaces   uint64
	RequiredClasses uint16
	PreQuestGroup   []int
	PreQuestSingle  []int
	ExclusiveTo     []int
	Breadcrumbs     []int
	BreadcrumbFor   int
	ZoneOrSort      int
	RequiredSkill   *Skill
	SpecialFlags    int
	Flags           int
}

type Spawn struct {
	Zone int
	X    float64
	Y    float64
}

type NPC struct {
	ID        int
	Name      string
	Spawns    []Spawn
	Waypoints []Spawn
}

// NPC returns one decoded NPC, or nil when the ID is absent.
func (artifact *Artifact) NPC(id int) (*NPC, error) {
	if npc, ok := artifact.npcs[id]; ok {
		return npc, nil
	}
	known, err := artifact.hasID("Npc", id)
	if err != nil {
		return nil, err
	}
	if !known {
		artifact.npcs[id] = nil
		return nil, nil
	}
	scalar, err := artifact.scalar("Npc", id)
	if err != nil {
		return nil, err
	}
	name, err := artifact.field("Npc", id, 1, scalar)
	if err != nil {
		return nil, err
	}
	spawnValue, err := artifact.field("Npc", id, 7, scalar)
	if err != nil {
		return nil, err
	}
	waypointValue, err := artifact.field("Npc", id, 8, scalar)
	if err != nil {
		return nil, err
	}
	npc := &NPC{
		ID:        id,
		Name:      stringValue(name),
		Spawns:    parseSpawns(spawnValue),
		Waypoints: parseWaypoints(waypointValue),
	}
	artifact.npcs[id] = npc
	return npc, nil
}

type Object struct {
	ID        int
	Name      string
	Spawns    []Spawn
	Waypoints []Spawn
}

// Object returns one decoded object, or nil when the ID is absent.
func (artifact *Artifact) Object(id int) (*Object, error) {
	if object, ok := artifact.objects[id]; ok {
		return object, nil
	}
	known, err := artifact.hasID("Object", id)
	if err != nil {
		return nil, err
	}
	if !known {
		artifact.objects[id] = nil
		return nil, nil
	}
	scalar, err := artifact.scalar("Object", id)
	if err != nil {
		return nil, err
	}
	name, err := artifact.field("Object", id, 1, scalar)
	if err != nil {
		return nil, err
	}
	spawnValue, err := artifact.field("Object", id, 4, scalar)
	if err != nil {
		return nil, err
	}
	waypointValue, err := artifact.field("Object", id, 7, scalar)
	if err != nil {
		return nil, err
	}
	object := &Object{
		ID:        id,
		Name:      stringValue(name),
		Spawns:    parseSpawns(spawnValue),
		Waypoints: parseWaypoints(waypointValue),
	}
	artifact.objects[id] = object
	return object, nil
}

type Item struct {
	ID          int
	Name        string
	NPCDrops    []int
	ObjectDrops []int
}

// Item returns one decoded item, or nil when the ID is absent.
func (artifact *Artifact) Item(id int) (*Item, error) {
	if item, ok := artifact.items[id]; ok {
		return item, nil
	}
	known, err := artifact.hasID("Item", id)
	if err != nil {
		return nil, err
	}
	if !known {
		artifact.items[id] = nil
		return nil, nil
	}
	scalar, err := artifact.scalar("Item", id)
	if err != nil {
		return nil, err
	}
	name, err := artifact.field("Item", id, 1, scalar)
	if err != nil {
		return nil, err
	}
	npcDrops, err := artifact.listField("Item", id, 2, scalar)
	if err != nil {
		return nil, err
	}
	objectDrops, err := artifact.listField("Item", id, 3, scalar)
	if err != nil {
		return nil, err
	}
	item := &Item{
		ID:          id,
		Name:        stringValue(name),
		NPCDrops:    npcDrops,
		ObjectDrops: objectDrops,
	}
	artifact.items[id] = item
	return item, nil
}

func parseSpawns(value any) []Spawn {
	if value == nil {
		return nil
	}
	spawns := []Spawn{}
	add := func(zone int, points any) {
		for _, point := range Array(points) {
			x, y, ok := pointCoordinates(point)
			if ok {
				spawns = append(spawns, Spawn{Zone: zone, X: x, Y: y})
			}
		}
	}
	switch typed := value.(type) {
	case map[any]any:
		for _, zone := range sortedZoneKeys(typed) {
			add(zone, typed[zone])
		}
	case []any:
		if len(typed) == 0 {
			return nil
		}
		if isPointList(typed) {
			add(1, typed)
		} else {
			add(1, typed[0])
		}
	}
	return spawns
}

func parseWaypoints(value any) []Spawn {
	if value == nil {
		return nil
	}
	result := []Spawn{}
	addFirst := func(zone int, paths any) {
		items := Array(paths)
		if len(items) == 0 {
			return
		}
		var first any
		switch {
		case isPoint(items[0]):
			first = items[0]
		case isPath(items[0]):
			first = Array(items[0])[0]
		default:
			nested := Array(items[0])
			if len(nested) == 0 || !isPath(nested[0]) {
				return
			}
			first = Array(nested[0])[0]
		}
		x, y, ok := pointCoordinates(first)
		if ok {
			result = append(result, Spawn{Zone: zone, X: x, Y: y})
		}
	}
	switch typed := value.(type) {
	case map[any]any:
		for _, zone := range sortedZoneKeys(typed) {
			addFirst(zone, typed[zone])
		}
	case []any:
		if len(typed) == 0 {
			return nil
		}
		switch {
		case isPoint(typed[0]):
			addFirst(1, []any{typed})
		case isPath(typed[0]):
			addFirst(1, typed)
		default:
			addFirst(1, typed[0])
		}
	}
	return result
}

func sortedZoneKeys(values map[any]any) []int {
	keys := make([]int, 0, len(values))
	for key := range values {
		if number, ok := Int(key); ok {
			keys = append(keys, number)
		}
	}
	sort.Ints(keys)
	return keys
}

func pointCoordinates(value any) (float64, float64, bool) {
	coordinates := Array(value)
	if len(coordinates) < 2 {
		return 0, 0, false
	}
	x, okX := Float(coordinates[0])
	y, okY := Float(coordinates[1])
	return x, y, okX && okY
}

func isPoint(value any) bool {
	_, _, ok := pointCoordinates(value)
	return ok
}

func isPointList(value any) bool {
	items := Array(value)
	return len(items) > 0 && isPoint(items[0])
}

func isPath(value any) bool {
	items := Array(value)
	return len(items) > 0 && isPoint(items[0])
}

// ReadZoneSource returns one of QuestieDB's Forever zone support files.
func (artifact *Artifact) ReadZoneSource(name string) (string, error) {
	data, err := artifact.readRelative(path.Join("support", "Forever", "Zones", name))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// ArtifactPathForReport returns the absolute artifact path when available.
func ArtifactPathForReport(filePath string) string {
	absolute, err := filepath.Abs(filePath)
	if err != nil {
		return filePath
	}
	return absolute
}
