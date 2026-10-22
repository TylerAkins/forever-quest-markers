package questdb

import (
	"flag"
	"fmt"
	"io"
	"path/filepath"
)

// RunBuild is the cmd/fqp build-db entry point.
func RunBuild(args []string, stdout, stderr io.Writer) error {
	flags := flag.NewFlagSet("build-db", flag.ContinueOnError)
	flags.SetOutput(stderr)
	artifactPath := flags.String("questiedb", "", "QuestieDB-Forever.zip or extracted QuestieDB directory")
	artifactSHA := flags.String("questiedb-sha", "", "expected SHA-256 of the QuestieDB zip")
	artifactRef := flags.String("questiedb-ref", "", "artifact label recorded in metadata (for example preview)")
	policyPath := flags.String("questie", "", "Questie checkout containing Database/Corrections")
	policyCommit := flags.String("questie-sha", "", "pinned Questie commit recorded in metadata")
	outputDir := flags.String("out", "Database", "output directory")
	reportPath := flags.String("report", "", "build report path (default <out>/build_report.json)")
	baselinePath := flags.String("baseline", "", "optional previous ForeverQuests.lua for parity reporting")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *artifactPath == "" {
		return fmt.Errorf("--questiedb is required")
	}
	if *policyPath == "" {
		return fmt.Errorf("--questie is required")
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("unexpected arguments: %v", flags.Args())
	}
	actualPolicyCommit := ParsePolicyCommit(*policyPath, "")
	if *policyCommit != "" && actualPolicyCommit != "" && actualPolicyCommit != *policyCommit {
		return fmt.Errorf("Questie checkout is at %s, want %s", actualPolicyCommit, *policyCommit)
	}
	if *policyCommit == "" {
		*policyCommit = actualPolicyCommit
	}
	report := *reportPath
	if report == "" {
		report = filepath.Join(*outputDir, "build_report.json")
	}
	result, err := Build(Options{
		ArtifactPath: *artifactPath,
		ArtifactSHA:  *artifactSHA,
		ArtifactRef:  *artifactRef,
		PolicyPath:   *policyPath,
		PolicyCommit: *policyCommit,
		OutputDir:    *outputDir,
		ReportPath:   report,
		BaselinePath: *baselinePath,
	})
	if err != nil {
		return err
	}
	fmt.Fprintf(stdout, "built %d quests, %d pins, %d turn-in quests, %d static instance quests, %d yearly quests\n",
		result.Report.Counts.Quests,
		result.Report.Counts.CoordPins,
		result.Report.Counts.QuestsWithTurnIns,
		result.Report.Counts.InstanceQuests,
		result.Report.Counts.YearlyQuests,
	)
	fmt.Fprintf(stdout, "report: %s\n", report)
	return nil
}
