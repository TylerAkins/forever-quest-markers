package luatests

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"testing"
)

func TestLuaRuntimeCompatibilityCases(t *testing.T) {
	luajit, err := exec.LookPath("luajit")
	if err != nil {
		t.Fatal("LuaJIT is required for Lua runtime tests: install luajit and put it on PATH")
	}
	_, testFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("could not locate test source")
	}
	root := filepath.Clean(filepath.Join(filepath.Dir(testFile), "..", ".."))
	caseFile := filepath.Join(filepath.Dir(testFile), "runtime_cases.lua")
	source, err := os.ReadFile(caseFile)
	if err != nil {
		t.Fatal(err)
	}
	casePattern := regexp.MustCompile(`cases\["([^"]+)"\] = function\(\)`)
	matches := casePattern.FindAllSubmatch(source, -1)
	if len(matches) == 0 {
		t.Fatal("no Lua runtime cases were found")
	}
	cases := make([]string, 0, len(matches))
	for _, match := range matches {
		cases = append(cases, string(match[1]))
	}
	sort.Strings(cases)
	for _, name := range cases {
		t.Run(name, func(t *testing.T) {
			command := exec.Command(luajit, filepath.Join("internal", "luatests", "runtime_cases.lua"))
			command.Dir = root
			command.Env = append(os.Environ(), "FQP_LUA_CASE="+name)
			if output, err := command.CombinedOutput(); err != nil {
				t.Fatalf("LuaJIT runtime case failed: %v\n%s", err, output)
			}
		})
	}
}
