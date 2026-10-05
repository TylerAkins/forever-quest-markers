package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/TylerAkins/forever-quest-markers/internal/compile"
)

func main() {
	exportDir := flag.String("export", "", "wow-database export/forever directory")
	outDir := flag.String("out", "Database", "addon Database directory")
	databaseCommit := flag.String("database-commit", "", "wow-database git commit")
	check := flag.Bool("check", false, "compare the export with Database and write nothing")
	flag.Parse()
	if *exportDir == "" {
		fmt.Fprintln(os.Stderr, "compile: --export is required")
		os.Exit(2)
	}
	err := compile.Run(compile.Options{
		ExportDir:      *exportDir,
		OutDir:         *outDir,
		DatabaseCommit: *databaseCommit,
		Check:          *check,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "compile: %v\n", err)
		os.Exit(1)
	}
}
