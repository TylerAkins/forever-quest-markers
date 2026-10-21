package attdsl

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

const ATTRepoURL = "https://github.com/ATTWoWAddon/AllTheThings.git"

func RunBuild(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("build-db", flag.ContinueOnError)
	flags.SetOutput(stderr)
	attRootArg := flags.String("att", "", "path to an AllTheThings checkout")
	cloneDir := flags.String("clone-dir", filepath.Join(".cache", "AllTheThings"), "where to clone ATT if --att is omitted")
	attURL := flags.String("att-url", ATTRepoURL, "ATT git URL used when cloning")
	attSHAArg := flags.String("att-sha", "", "override the recorded ATT commit SHA")
	output := flags.String("out", "Database", "directory for generated Lua and JSON files")
	reportPath := flags.String("report", "", "optional extra JSON report path")
	keepGoing := flags.Bool("keep-going", false, "continue after parse errors")
	skipClone := flags.Bool("skip-clone", false, "do not clone; --att is required")
	if err := flags.Parse(args); err != nil {
		return err
	}
	attRoot := *attRootArg
	if attRoot != "" {
		absolute, err := filepath.Abs(attRoot)
		if err != nil {
			return err
		}
		attRoot = absolute
		info, err := os.Stat(attRoot)
		if err != nil || !info.IsDir() {
			return fmt.Errorf("ATT path does not exist: %s", attRoot)
		}
	} else {
		if *skipClone {
			return errors.New("--att is required when --skip-clone is set")
		}
		absolute, err := filepath.Abs(*cloneDir)
		if err != nil {
			return err
		}
		attRoot = absolute
		if err := ensureATTCheckout(attRoot, *attURL); err != nil {
			return err
		}
	}
	attSHA := *attSHAArg
	if attSHA == "" {
		output, err := exec.Command("git", "-C", attRoot, "rev-parse", "HEAD").Output()
		if err != nil {
			return fmt.Errorf("read ATT commit: %w", err)
		}
		attSHA = strings.TrimSpace(string(output))
	}
	ctx, err := LoadForeverConstants(attRoot)
	if err != nil {
		return err
	}
	foreverDB := filepath.Join(attRoot, ".contrib", ".db", "forever")
	if info, err := os.Stat(foreverDB); err != nil || !info.IsDir() {
		return fmt.Errorf("Forever database not found: %s", foreverDB)
	}
	liveFiles, zzoldFiles, err := luaFiles(foreverDB)
	if err != nil {
		return err
	}
	allFiles := append(append([]string{}, liveFiles...), zzoldFiles...)
	result := NewExtractResult(ctx.Patch)
	var errorsFound []string
	for _, path := range liveFiles {
		rel, _ := filepath.Rel(foreverDB, path)
		rel = filepath.ToSlash(rel)
		if err := parseFile(path, rel, ctx, result); err != nil {
			errorsFound = append(errorsFound, rel+": "+err.Error())
			fmt.Fprintf(stderr, "ERROR: %s: %v\n", rel, err)
			continue
		}
		result.FilesParsed++
	}
	if len(errorsFound) > 0 && !*keepGoing {
		fmt.Fprintf(stderr, "Failed to parse %d live file(s).\n", len(errorsFound))
		return errors.New("ATT live data contains parse errors")
	}
	zzoldResult := NewExtractResult(ctx.Patch)
	var zzoldErrors []string
	for _, path := range zzoldFiles {
		rel, _ := filepath.Rel(foreverDB, path)
		rel = filepath.ToSlash(rel)
		if err := parseFile(path, rel, ctx, zzoldResult); err != nil {
			zzoldErrors = append(zzoldErrors, rel+": "+err.Error())
			fmt.Fprintf(stderr, "ERROR: %s: %v\n", rel, err)
			continue
		}
		zzoldResult.FilesParsed++
	}
	if len(zzoldErrors) > 0 && !*keepGoing {
		fmt.Fprintf(stderr, "Failed to parse %d zzOLD file(s).\n", len(zzoldErrors))
		return errors.New("ATT zzOLD data contains parse errors")
	}
	zzoldFallback := 0
	for id, record := range zzoldResult.Quests {
		if result.Quests[id] == nil {
			result.Quests[id] = record
			zzoldFallback++
			continue
		}
		existing := result.Quests[id]
		existing.IsInstanceQuest = existing.IsInstanceQuest || record.IsInstanceQuest
		if existing.ATTTitle == "" {
			existing.ATTTitle = record.ATTTitle
		}
	}
	result.QuestsSeen += zzoldResult.QuestsSeen
	result.QuestsWithCoords = len(result.Quests)
	result.FilesParsed += zzoldResult.FilesParsed
	for reason, count := range zzoldResult.Excluded {
		result.Excluded[reason] += count
	}
	for id := range zzoldResult.AttunementQuestIDs {
		result.AttunementQuestIDs[id] = true
	}
	errorsFound = append(errorsFound, zzoldErrors...)
	result.MarkAttunementChains()
	stats := buildStats(result, attSHA, len(allFiles), errorsFound)
	stats["zzold_files_parsed"] = zzoldResult.FilesParsed
	stats["zzold_fallback_quests"] = zzoldFallback
	if err := WriteOutputs(*output, result.Quests, attSHA, stats); err != nil {
		return err
	}
	logSummary(stdout, stats)
	if *reportPath != "" {
		report, err := EmitReport(stats)
		if err != nil {
			return err
		}
		report = append(report, '\n')
		if err := os.WriteFile(*reportPath, report, 0o644); err != nil {
			return err
		}
	}
	return nil
}

func parseFile(path, relative string, ctx BuildContext, result *ExtractResult) error {
	sourceBytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	source := string(sourceBytes)
	processed, err := Preprocess(UnwrapDisabledModule(source), ctx)
	if err != nil {
		return err
	}
	statements, err := ParseLua(processed, relative)
	if err != nil {
		return err
	}
	env := NewEnvironment(ctx)
	if err := env.Evaluate(statements); err != nil {
		return err
	}
	result.ExtractRoots(env.Roots, relative)
	ApplyTitles(source, result)
	return nil
}

func luaFiles(root string) (live, zzold []string, err error) {
	err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			if path == root {
				return nil
			}
			name := strings.ToLower(entry.Name())
			if name == ".config" || name == ".wago" || name == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(path) != ".lua" {
			return nil
		}
		parts := strings.Split(filepath.ToSlash(path), "/")
		old := false
		for _, part := range parts {
			if strings.EqualFold(part, "zzold") {
				old = true
				break
			}
		}
		if old {
			zzold = append(zzold, path)
		} else {
			live = append(live, path)
		}
		return nil
	})
	sort.Strings(live)
	sort.Strings(zzold)
	return live, zzold, err
}

func ensureATTCheckout(path, url string) error {
	if info, err := os.Stat(filepath.Join(path, ".git")); err == nil && info.IsDir() {
		_ = exec.Command("git", "-C", path, "fetch", "--depth", "1", "origin").Run()
		_ = exec.Command("git", "-C", path, "checkout", "FETCH_HEAD").Run()
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if output, err := exec.Command("git", "clone", "--depth", "1", "--filter=blob:none", "--sparse", url, path).CombinedOutput(); err != nil {
		return fmt.Errorf("clone ATT: %w: %s", err, output)
	}
	command := exec.Command("git", "-C", path, "sparse-checkout", "set", "--no-cone", ".contrib/.db/forever", ".contrib/Parser/lib/Constants", ".contrib/Standard.lua")
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("configure ATT sparse checkout: %w: %s", err, output)
	}
	return nil
}

func buildStats(result *ExtractResult, sha string, fileCount int, parseErrors []string) map[string]any {
	coordPins := 0
	mapSet := map[int]bool{}
	attunement := 0
	titles := 0
	for _, record := range result.Quests {
		coordPins += len(record.Coords)
		for _, coord := range record.Coords {
			mapSet[coord.MapID] = true
		}
		if record.IsAttunement {
			attunement++
		}
		if record.ATTTitle != "" {
			titles++
		}
	}
	maps := make([]int, 0, len(mapSet))
	for id := range mapSet {
		maps = append(maps, id)
	}
	sort.Ints(maps)
	excluded := map[string]int{}
	for reason, count := range result.Excluded {
		excluded[reason] = count
	}
	if parseErrors == nil {
		parseErrors = []string{}
	}
	return map[string]any{"att_sha": sha, "att_source": ATTRepoURL, "files_discovered": fileCount, "files_parsed": result.FilesParsed, "parse_errors": parseErrors, "quests_seen": result.QuestsSeen, "quests_emitted": len(result.Quests), "quests_with_coords": result.QuestsWithCoords, "coord_pins": coordPins, "attunement_quests": attunement, "att_titles": titles, "excluded": excluded, "map_ids": maps, "map_count": len(maps)}
}

func logSummary(output io.Writer, stats map[string]any) {
	fmt.Fprintf(output, "ATT commit: %v\nFiles parsed: %v / %v\nQuests seen: %v\nQuests with coordinates: %v\nCoordinate pins: %v\nAttunement quests: %v\nATT title fallbacks: %v\nMaps indexed: %v\n", stats["att_sha"], stats["files_parsed"], stats["files_discovered"], stats["quests_seen"], stats["quests_with_coords"], stats["coord_pins"], stats["attunement_quests"], stats["att_titles"], stats["map_count"])
	if count := statInt(stats, "zzold_fallback_quests"); count != 0 {
		fmt.Fprintf(output, "zzOLD fallback quests: %d\n", count)
	}
	if excluded, ok := stats["excluded"].(map[string]int); ok && len(excluded) > 0 {
		fmt.Fprintln(output, "Excluded:")
		keys := make([]string, 0, len(excluded))
		for key := range excluded {
			keys = append(keys, key)
		}
		sort.Strings(keys)
		for _, key := range keys {
			fmt.Fprintf(output, "  %s: %d\n", key, excluded[key])
		}
	}
	if parseErrors, ok := stats["parse_errors"].([]string); ok && len(parseErrors) > 0 {
		fmt.Fprintf(output, "Parse errors: %d\n", len(parseErrors))
	}
}
