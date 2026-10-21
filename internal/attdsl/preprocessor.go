package attdsl

import (
	"fmt"
	"regexp"
	"strings"
)

var directivePattern = regexp.MustCompile(`(?i)^\s*--\s*#(if|ifdef|ifndef|elseif|elif|else|endif)\b(.*)$`)

type preprocessFrame struct {
	parentActive bool
	taking       bool
	taken        bool
	kind         string
}

func UnwrapDisabledModule(source string) string {
	if source == "" {
		return source
	}
	lines := strings.SplitAfter(source, "\n")
	start := -1
	equals := ""
	openPattern := regexp.MustCompile(`^--\[(=*)\[$`)
	for index, line := range lines {
		if match := openPattern.FindStringSubmatch(strings.TrimSpace(strings.TrimSuffix(line, "\n"))); match != nil {
			start, equals = index, match[1]
			break
		}
	}
	if start < 0 || start > 10 {
		return source
	}
	closer := "]" + equals + "]"
	end := -1
	for index := len(lines) - 1; index > start; index-- {
		if strings.TrimSpace(strings.TrimSuffix(lines[index], "\n")) == "--"+closer {
			end = index
			break
		}
	}
	if end <= start {
		return source
	}
	for _, line := range lines[end+1:] {
		if strings.TrimSpace(line) != "" {
			return source
		}
	}
	body := strings.Join(lines[start+1:end], "")
	if strings.Contains(body, "--["+equals+"[") || strings.Contains(body, closer) {
		return source
	}
	return strings.Join(lines[:start], "") + body
}

func Preprocess(source string, ctx BuildContext) (string, error) {
	if source == "" {
		return source, nil
	}
	lines := strings.SplitAfter(source, "\n")
	stack := []preprocessFrame{}
	output := make([]string, 0, len(lines))
	for index, line := range lines {
		stripped := strings.TrimRight(strings.TrimSuffix(line, "\n"), "\r \t")
		match := directivePattern.FindStringSubmatch(stripped)
		if match != nil {
			kind, rest := strings.ToLower(match[1]), strings.TrimSpace(match[2])
			switch kind {
			case "if", "ifdef", "ifndef":
				parentActive := len(stack) == 0 || stack[len(stack)-1].taking
				condition := evalCondition(rest, ctx, kind)
				taking := parentActive && condition
				stack = append(stack, preprocessFrame{parentActive: parentActive, taking: taking, taken: taking, kind: kind})
			case "elseif", "elif":
				if len(stack) == 0 || stack[len(stack)-1].kind == "else" {
					return "", fmt.Errorf("line %d: unexpected #elseif", index+1)
				}
				frame := &stack[len(stack)-1]
				taking := frame.parentActive && !frame.taken && evalCondition(rest, ctx, "if")
				frame.taking, frame.taken = taking, frame.taken || taking
			case "else":
				if len(stack) == 0 {
					return "", fmt.Errorf("line %d: unexpected #else", index+1)
				}
				frame := &stack[len(stack)-1]
				frame.taking, frame.taken, frame.kind = frame.parentActive && !frame.taken, true, "else"
			case "endif":
				if len(stack) == 0 {
					return "", fmt.Errorf("line %d: unexpected #endif", index+1)
				}
				stack = stack[:len(stack)-1]
			}
			output = append(output, newlineOnly(line))
			continue
		}
		active := len(stack) == 0 || stack[len(stack)-1].taking
		if active {
			output = append(output, line)
		} else {
			output = append(output, newlineOnly(line))
		}
	}
	if len(stack) != 0 {
		return "", fmt.Errorf("line %d: unclosed #if directive", len(lines))
	}
	return strings.Join(output, ""), nil
}

func newlineOnly(line string) string {
	if strings.HasSuffix(line, "\n") {
		return "\n"
	}
	return ""
}

func evalCondition(expression string, ctx BuildContext, kind string) bool {
	if comment := strings.Index(expression, "--"); comment >= 0 {
		expression = expression[:comment]
	}
	if kind == "ifndef" {
		return !evalOr(expression, ctx)
	}
	return evalOr(expression, ctx)
}

func evalOr(expression string, ctx BuildContext) bool {
	parts := regexp.MustCompile(`(?i)\s+OR\s+`).Split(expression, -1)
	for _, part := range parts {
		if evalAnd(strings.TrimSpace(part), ctx) {
			return true
		}
	}
	return false
}

func evalAnd(expression string, ctx BuildContext) bool {
	parts := regexp.MustCompile(`(?i)\s+AND\s+`).Split(expression, -1)
	for _, part := range parts {
		if !evalNot(strings.TrimSpace(part), ctx) {
			return false
		}
	}
	return true
}

func evalNot(expression string, ctx BuildContext) bool {
	expression = strings.TrimSpace(expression)
	negated := false
	for strings.HasPrefix(strings.ToUpper(expression), "NOT ") {
		negated = !negated
		expression = strings.TrimSpace(expression[4:])
	}
	result := evalAtom(expression, ctx)
	if negated {
		return !result
	}
	return result
}

func evalAtom(expression string, ctx BuildContext) bool {
	tokens := strings.Fields(expression)
	if len(tokens) == 0 {
		return false
	}
	head := strings.ToUpper(tokens[0])
	if head == "AFTER" || head == "BEFORE" {
		if len(tokens) < 2 {
			return false
		}
		version, ok := ParseVersionToken(tokens[1])
		if !ok {
			return head == "BEFORE"
		}
		comparison := comparePatch(ctx.Patch, version)
		if head == "AFTER" {
			return comparison >= 0
		}
		return comparison < 0
	}
	return ctx.Tags[strings.Trim(head, "()")]
}

func comparePatch(left, right [4]int) int {
	for i := range left {
		if left[i] < right[i] {
			return -1
		}
		if left[i] > right[i] {
			return 1
		}
	}
	return 0
}
