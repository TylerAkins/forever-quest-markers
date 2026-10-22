package questiedb

import (
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode"
)

// LuaTable is the small Lua table subset used by Questie's embedded zone
// tables and policy files. Integer-keyed entries are kept separately from
// string-keyed entries so array-like and map-like values can share one type.
type LuaTable struct {
	Numbers map[int]any
	Strings map[string]any
}

func NewLuaTable() *LuaTable {
	return &LuaTable{Numbers: map[int]any{}, Strings: map[string]any{}}
}

func (table *LuaTable) Set(key, value any) error {
	switch typed := key.(type) {
	case int:
		table.Numbers[typed] = value
		return nil
	case int64:
		number, ok := Int(typed)
		if !ok {
			return fmt.Errorf("Lua table key %d is out of range", typed)
		}
		table.Numbers[number] = value
		return nil
	case uint64:
		number, ok := Int(typed)
		if !ok {
			return fmt.Errorf("Lua table key %d is out of range", typed)
		}
		table.Numbers[number] = value
		return nil
	case float64:
		number, ok := Int(typed)
		if !ok {
			return fmt.Errorf("Lua table key %v is not an integer", typed)
		}
		table.Numbers[number] = value
		return nil
	case string:
		table.Strings[typed] = value
		return nil
	default:
		return fmt.Errorf("unsupported Lua table key %T", key)
	}
}

func (table *LuaTable) Get(key int) any {
	if table == nil {
		return nil
	}
	return table.Numbers[key]
}

func (table *LuaTable) GetString(key string) any {
	if table == nil {
		return nil
	}
	return table.Strings[key]
}

func (table *LuaTable) IntKeys() []int {
	if table == nil {
		return nil
	}
	keys := make([]int, 0, len(table.Numbers))
	for key := range table.Numbers {
		keys = append(keys, key)
	}
	sort.Ints(keys)
	return keys
}

func (table *LuaTable) StringKeys() []string {
	if table == nil {
		return nil
	}
	keys := make([]string, 0, len(table.Strings))
	for key := range table.Strings {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

// ParseLuaExpression parses and evaluates a Lua expression with a fixed set of
// identifiers. Unsupported syntax and unknown identifiers are errors.
func ParseLuaExpression(source string, vars map[string]any) (any, error) {
	parser := luaParser{source: source}
	parser.skipSpace()
	expression, err := parser.parseOr()
	if err != nil {
		return nil, err
	}
	parser.skipSpace()
	if parser.position != len(parser.source) {
		return nil, parser.errorf("unexpected trailing Lua input")
	}
	return expression.evaluate(evalContext{vars: vars})
}

// ParseLuaReturnTable parses the body of a Questie [[return { ... }]] table.
func ParseLuaReturnTable(source string, vars map[string]any) (*LuaTable, error) {
	parser := luaParser{source: source}
	parser.skipSpace()
	if !parser.consumeKeyword("return") {
		return nil, parser.errorf("expected return")
	}
	value, err := parser.parseOr()
	if err != nil {
		return nil, err
	}
	parser.skipSpace()
	if parser.position != len(parser.source) {
		return nil, parser.errorf("unexpected trailing Lua input")
	}
	evaluated, err := value.evaluate(evalContext{vars: vars})
	if err != nil {
		return nil, err
	}
	table, ok := evaluated.(*LuaTable)
	if !ok {
		return nil, fmt.Errorf("Lua return value is %T, not a table", evaluated)
	}
	return table, nil
}

// ExtractLuaLongString returns the body of an assignment such as
// name = [[return { ... }]].
func ExtractLuaLongString(source, name string) (string, error) {
	pattern := regexp.MustCompile(`(?m)^[^\n]*\b` + regexp.QuoteMeta(name) + `\s*=\s*\[(=*)\[`)
	match := pattern.FindStringSubmatchIndex(source)
	if match == nil {
		return "", fmt.Errorf("missing Lua long-string assignment %q", name)
	}
	equals := source[match[2]:match[3]]
	start := match[1]
	closer := "]" + equals + "]"
	end := strings.Index(source[start:], closer)
	if end < 0 {
		return "", fmt.Errorf("unterminated Lua long string %q", name)
	}
	return source[start : start+end], nil
}

// ParseLuaLongStringTable extracts and parses a named [[return { ... }]] table.
func ParseLuaLongStringTable(source, name string, vars map[string]any) (*LuaTable, error) {
	body, err := ExtractLuaLongString(source, name)
	if err != nil {
		return nil, err
	}
	return ParseLuaReturnTable(body, vars)
}

// ParseLuaTableAssignment parses a named table literal such as
// local dungeons = { ... }.
func ParseLuaTableAssignment(source, name string, vars map[string]any) (*LuaTable, error) {
	pattern := regexp.MustCompile(`\b` + regexp.QuoteMeta(name) + `\s*=\s*\{`)
	match := pattern.FindStringIndex(source)
	if match == nil {
		return nil, fmt.Errorf("missing Lua table assignment %q", name)
	}
	start := match[1] - 1
	text, err := ExtractLuaValue(source, start)
	if err != nil {
		return nil, err
	}
	value, err := ParseLuaExpression(text, vars)
	if err != nil {
		return nil, err
	}
	table, ok := value.(*LuaTable)
	if !ok {
		return nil, fmt.Errorf("Lua assignment %q is %T, not a table", name, value)
	}
	return table, nil
}

// ExtractLuaValue returns the text of one Lua value beginning at start. It is
// limited to balanced tables, parenthesized expressions, strings, and atoms.
func ExtractLuaValue(source string, start int) (string, error) {
	if start < 0 || start >= len(source) {
		return "", fmt.Errorf("Lua value starts outside the source")
	}
	depth := 0
	var quote byte
	longClose := ""
	for index := start; index < len(source); index++ {
		character := source[index]
		if quote != 0 {
			if character == '\\' {
				index++
				continue
			}
			if character == quote {
				quote = 0
			}
			continue
		}
		if longClose != "" {
			if strings.HasPrefix(source[index:], longClose) {
				index += len(longClose) - 1
				longClose = ""
			}
			continue
		}
		switch character {
		case '\'', '"':
			quote = character
		case '-':
			if strings.HasPrefix(source[index:], "--") {
				if close, ok := luaBlockCommentClose(source[index:]); ok {
					index += close - 1
				} else {
					newline := strings.IndexByte(source[index:], '\n')
					if newline < 0 {
						index = len(source)
					} else {
						index += newline
					}
				}
			}
		case '[':
			if close, ok := luaLongStringClose(source[index:]); ok {
				longClose = close
				index += len(close) - 1
			}
		case '{', '(':
			depth++
			if depth == 1 && index != start {
				return "", fmt.Errorf("unexpected nested value at %d", index)
			}
		case '}', ')':
			depth--
			if depth == 0 {
				if character == ')' && source[start] != '(' {
					return "", fmt.Errorf("unbalanced Lua value")
				}
				return source[start : index+1], nil
			}
		case ',':
			if depth == 0 {
				return strings.TrimSpace(source[start:index]), nil
			}
		}
	}
	if depth != 0 || quote != 0 || longClose != "" {
		return "", fmt.Errorf("unterminated Lua value")
	}
	return strings.TrimSpace(source[start:]), nil
}

func luaBlockCommentClose(source string) (int, bool) {
	if !strings.HasPrefix(source, "--[") {
		return 0, false
	}
	rest := source[3:]
	equals := 0
	for equals < len(rest) && rest[equals] == '=' {
		equals++
	}
	if equals >= len(rest) || rest[equals] != '[' {
		return 0, false
	}
	closer := "]" + strings.Repeat("=", equals) + "]"
	end := strings.Index(rest[equals+1:], closer)
	if end < 0 {
		return 0, false
	}
	return 3 + equals + 1 + end + len(closer), true
}

func luaLongStringClose(source string) (string, bool) {
	if len(source) < 2 || source[0] != '[' {
		return "", false
	}
	equals := 0
	for equals+1 < len(source) && source[equals+1] == '=' {
		equals++
	}
	if equals+1 >= len(source) || source[equals+1] != '[' {
		return "", false
	}
	return "]" + strings.Repeat("=", equals) + "]", true
}

// StripLuaComments removes line and block comments while preserving strings.
func StripLuaComments(source string) string {
	var builder strings.Builder
	builder.Grow(len(source))
	for index := 0; index < len(source); {
		character := source[index]
		if character == '\'' || character == '"' {
			start := index
			index++
			for index < len(source) {
				if source[index] == '\\' {
					index += 2
					continue
				}
				if source[index] == character {
					index++
					break
				}
				index++
			}
			builder.WriteString(source[start:index])
			continue
		}
		if character == '-' && strings.HasPrefix(source[index:], "--") {
			if close, ok := luaBlockCommentClose(source[index:]); ok {
				index += close
				continue
			}
			newline := strings.IndexByte(source[index:], '\n')
			if newline < 0 {
				break
			}
			builder.WriteByte('\n')
			index += newline + 1
			continue
		}
		if character == '[' {
			if close, ok := luaLongStringClose(source[index:]); ok {
				start := index
				index += len(close) - 1
				end := strings.Index(source[index:], close)
				if end < 0 {
					builder.WriteString(source[start:])
					break
				}
				index += end + len(close)
				builder.WriteString(source[start:index])
				continue
			}
		}
		builder.WriteByte(character)
		index++
	}
	return builder.String()
}

type evalContext struct {
	vars map[string]any
}

type luaExpression interface {
	evaluate(evalContext) (any, error)
}

type luaLiteral struct{ value any }

func (literal luaLiteral) evaluate(evalContext) (any, error) { return literal.value, nil }

type luaIdentifier struct{ name string }

func (identifier luaIdentifier) evaluate(context evalContext) (any, error) {
	value, ok := context.vars[identifier.name]
	if !ok {
		return nil, fmt.Errorf("unknown Lua identifier %q", identifier.name)
	}
	return value, nil
}

type luaUnary struct {
	operator string
	value    luaExpression
}

func (unary luaUnary) evaluate(context evalContext) (any, error) {
	value, err := unary.value.evaluate(context)
	if err != nil {
		return nil, err
	}
	switch unary.operator {
	case "not":
		return !luaTruthy(value), nil
	default:
		return nil, fmt.Errorf("unsupported Lua unary operator %q", unary.operator)
	}
}

type luaBinary struct {
	operator    string
	left, right luaExpression
}

func (binary luaBinary) evaluate(context evalContext) (any, error) {
	left, err := binary.left.evaluate(context)
	if err != nil {
		return nil, err
	}
	switch binary.operator {
	case "and":
		if !luaTruthy(left) {
			return left, nil
		}
		return binary.right.evaluate(context)
	case "or":
		if luaTruthy(left) {
			return left, nil
		}
		return binary.right.evaluate(context)
	}
	right, err := binary.right.evaluate(context)
	if err != nil {
		return nil, err
	}
	switch binary.operator {
	case "==":
		return luaEquals(left, right), nil
	case "~=":
		return !luaEquals(left, right), nil
	case "<", "<=", ">", ">=":
		return luaCompare(binary.operator, left, right)
	default:
		return nil, fmt.Errorf("unsupported Lua operator %q", binary.operator)
	}
}

type luaCall struct {
	name string
	args []luaExpression
}

func (call luaCall) evaluate(context evalContext) (any, error) {
	values := make([]any, 0, len(call.args))
	for _, argument := range call.args {
		value, err := argument.evaluate(context)
		if err != nil {
			return nil, err
		}
		values = append(values, value)
	}
	switch call.name {
	case "l10n", "tostring":
		if len(values) == 0 {
			return "", nil
		}
		if text, ok := values[len(values)-1].(string); ok {
			return text, nil
		}
		return fmt.Sprint(values[len(values)-1]), nil
	case "tonumber":
		if len(values) == 0 {
			return nil, nil
		}
		if number, ok := Int(values[0]); ok {
			return number, nil
		}
		if text, ok := values[0].(string); ok {
			if number, err := strconv.Atoi(strings.TrimSpace(text)); err == nil {
				return number, nil
			}
		}
		return nil, nil
	default:
		return nil, fmt.Errorf("unsupported Lua function %q", call.name)
	}
}

type luaTableField struct {
	key   luaExpression
	value luaExpression
}

type luaTableExpression struct {
	fields []luaTableField
}

func (expression luaTableExpression) evaluate(context evalContext) (any, error) {
	table := NewLuaTable()
	next := 1
	for _, field := range expression.fields {
		key := luaExpression(luaLiteral{next})
		if field.key != nil {
			key = field.key
		}
		evaluatedKey, err := key.evaluate(context)
		if err != nil {
			return nil, err
		}
		if field.key == nil {
			number, ok := Int(evaluatedKey)
			if !ok {
				return nil, fmt.Errorf("implicit Lua table key is not an integer")
			}
			next = number + 1
		} else if number, ok := Int(evaluatedKey); ok && number >= next {
			next = number + 1
		}
		value, err := field.value.evaluate(context)
		if err != nil {
			return nil, err
		}
		if err := table.Set(evaluatedKey, value); err != nil {
			return nil, err
		}
	}
	return table, nil
}

type luaParser struct {
	source   string
	position int
}

func (parser *luaParser) parseOr() (luaExpression, error) {
	left, err := parser.parseAnd()
	if err != nil {
		return nil, err
	}
	for {
		parser.skipSpace()
		if !parser.consumeKeyword("or") {
			return left, nil
		}
		right, err := parser.parseAnd()
		if err != nil {
			return nil, err
		}
		left = luaBinary{operator: "or", left: left, right: right}
	}
}

func (parser *luaParser) parseAnd() (luaExpression, error) {
	left, err := parser.parseComparison()
	if err != nil {
		return nil, err
	}
	for {
		parser.skipSpace()
		if !parser.consumeKeyword("and") {
			return left, nil
		}
		right, err := parser.parseComparison()
		if err != nil {
			return nil, err
		}
		left = luaBinary{operator: "and", left: left, right: right}
	}
}

func (parser *luaParser) parseComparison() (luaExpression, error) {
	left, err := parser.parseUnary()
	if err != nil {
		return nil, err
	}
	for {
		parser.skipSpace()
		operator := ""
		for _, candidate := range []string{"==", "~=", "<=", ">=", "<", ">"} {
			if strings.HasPrefix(parser.source[parser.position:], candidate) {
				operator = candidate
				break
			}
		}
		if operator == "" {
			return left, nil
		}
		parser.position += len(operator)
		right, err := parser.parseUnary()
		if err != nil {
			return nil, err
		}
		left = luaBinary{operator: operator, left: left, right: right}
	}
}

func (parser *luaParser) parseUnary() (luaExpression, error) {
	parser.skipSpace()
	if parser.consumeKeyword("not") {
		value, err := parser.parseUnary()
		if err != nil {
			return nil, err
		}
		return luaUnary{operator: "not", value: value}, nil
	}
	return parser.parsePrimary()
}

func (parser *luaParser) parsePrimary() (luaExpression, error) {
	parser.skipSpace()
	if parser.position >= len(parser.source) {
		return nil, parser.errorf("unexpected end of Lua input")
	}
	character := parser.source[parser.position]
	switch character {
	case '(':
		parser.position++
		value, err := parser.parseOr()
		if err != nil {
			return nil, err
		}
		parser.skipSpace()
		if parser.position >= len(parser.source) || parser.source[parser.position] != ')' {
			return nil, parser.errorf("missing closing parenthesis")
		}
		parser.position++
		return value, nil
	case '{':
		return parser.parseTable()
	case '\'', '"':
		value, err := parser.parseString()
		if err != nil {
			return nil, err
		}
		return luaLiteral{value}, nil
	case '[':
		if close, ok := luaLongStringClose(parser.source[parser.position:]); ok {
			start := parser.position + len(close) - 1
			end := strings.Index(parser.source[start:], close)
			if end < 0 {
				return nil, parser.errorf("unterminated Lua long string")
			}
			value := parser.source[start : start+end]
			parser.position = start + end + len(close)
			return luaLiteral{value}, nil
		}
	}
	if character == '-' || (character >= '0' && character <= '9') {
		return parser.parseNumber()
	}
	if isLuaIdentifierStart(character) {
		name := parser.parseIdentifierPath()
		parser.skipSpace()
		if parser.position < len(parser.source) && parser.source[parser.position] == '(' {
			parser.position++
			args, err := parser.parseArguments()
			if err != nil {
				return nil, err
			}
			return luaCall{name: name, args: args}, nil
		}
		switch name {
		case "nil":
			return luaLiteral{nil}, nil
		case "true":
			return luaLiteral{true}, nil
		case "false":
			return luaLiteral{false}, nil
		default:
			return luaIdentifier{name: name}, nil
		}
	}
	return nil, parser.errorf("unsupported Lua expression")
}

func (parser *luaParser) parseTable() (luaExpression, error) {
	if parser.source[parser.position] != '{' {
		return nil, parser.errorf("expected Lua table")
	}
	parser.position++
	table := luaTableExpression{}
	next := 1
	for {
		parser.skipSpace()
		if parser.position >= len(parser.source) {
			return nil, parser.errorf("unterminated Lua table")
		}
		if parser.source[parser.position] == '}' {
			parser.position++
			return table, nil
		}
		var key luaExpression
		if parser.source[parser.position] == '[' {
			parser.position++
			parsed, err := parser.parseOr()
			if err != nil {
				return nil, err
			}
			parser.skipSpace()
			if parser.position >= len(parser.source) || parser.source[parser.position] != ']' {
				return nil, parser.errorf("missing Lua table key bracket")
			}
			parser.position++
			parser.skipSpace()
			if parser.position >= len(parser.source) || parser.source[parser.position] != '=' ||
				(parser.position+1 < len(parser.source) && parser.source[parser.position+1] == '=') {
				return nil, parser.errorf("missing Lua table key assignment")
			}
			parser.position++
			key = parsed
		} else if name, ok := parser.tryNamedKey(); ok {
			key = luaLiteral{name}
		}
		value, err := parser.parseOr()
		if err != nil {
			return nil, err
		}
		if key == nil {
			key = luaLiteral{next}
			next++
		}
		table.fields = append(table.fields, luaTableField{key: key, value: value})
		parser.skipSpace()
		if parser.position < len(parser.source) && (parser.source[parser.position] == ',' || parser.source[parser.position] == ';') {
			parser.position++
			continue
		}
		if parser.position >= len(parser.source) || parser.source[parser.position] != '}' {
			return nil, parser.errorf("expected Lua table separator")
		}
	}
}

func (parser *luaParser) tryNamedKey() (string, bool) {
	saved := parser.position
	if parser.position >= len(parser.source) || !isLuaIdentifierStart(parser.source[parser.position]) {
		return "", false
	}
	name := parser.parseIdentifierPath()
	parser.skipSpace()
	if parser.position < len(parser.source) && parser.source[parser.position] == '=' &&
		(parser.position+1 >= len(parser.source) || parser.source[parser.position+1] != '=') {
		parser.position++
		return name, true
	}
	parser.position = saved
	return "", false
}

func (parser *luaParser) parseArguments() ([]luaExpression, error) {
	args := []luaExpression{}
	parser.skipSpace()
	if parser.position < len(parser.source) && parser.source[parser.position] == ')' {
		parser.position++
		return args, nil
	}
	for {
		value, err := parser.parseOr()
		if err != nil {
			return nil, err
		}
		args = append(args, value)
		parser.skipSpace()
		if parser.position >= len(parser.source) {
			return nil, parser.errorf("unterminated Lua function call")
		}
		if parser.source[parser.position] == ')' {
			parser.position++
			return args, nil
		}
		if parser.source[parser.position] != ',' {
			return nil, parser.errorf("expected Lua argument separator")
		}
		parser.position++
	}
}

func (parser *luaParser) parseString() (string, error) {
	quote := parser.source[parser.position]
	parser.position++
	var builder strings.Builder
	for parser.position < len(parser.source) {
		character := parser.source[parser.position]
		parser.position++
		if character == quote {
			return builder.String(), nil
		}
		if character != '\\' {
			builder.WriteByte(character)
			continue
		}
		if parser.position >= len(parser.source) {
			return "", parser.errorf("unterminated Lua escape")
		}
		escaped := parser.source[parser.position]
		parser.position++
		switch escaped {
		case 'n':
			builder.WriteByte('\n')
		case 'r':
			builder.WriteByte('\r')
		case 't':
			builder.WriteByte('\t')
		case '\\', '\'', '"':
			builder.WriteByte(escaped)
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			number := int(escaped - '0')
			for count := 1; count < 3 && parser.position < len(parser.source); count++ {
				next := parser.source[parser.position]
				if next < '0' || next > '9' {
					break
				}
				number = number*10 + int(next-'0')
				parser.position++
			}
			builder.WriteByte(byte(number))
		default:
			builder.WriteByte(escaped)
		}
	}
	return "", parser.errorf("unterminated Lua string")
}

func (parser *luaParser) parseNumber() (luaExpression, error) {
	start := parser.position
	if parser.source[parser.position] == '-' {
		parser.position++
	}
	for parser.position < len(parser.source) {
		character := parser.source[parser.position]
		if (character >= '0' && character <= '9') || character == '.' || character == 'e' || character == 'E' || character == '+' || character == '-' {
			parser.position++
			continue
		}
		break
	}
	text := parser.source[start:parser.position]
	if strings.ContainsAny(text, ".eE") {
		number, err := strconv.ParseFloat(text, 64)
		if err != nil {
			return nil, parser.errorf("invalid Lua number %q", text)
		}
		return luaLiteral{number}, nil
	}
	number, err := strconv.ParseInt(text, 10, 64)
	if err != nil {
		return nil, parser.errorf("invalid Lua integer %q", text)
	}
	return luaLiteral{number}, nil
}

func (parser *luaParser) parseIdentifierPath() string {
	start := parser.position
	for parser.position < len(parser.source) && isLuaIdentifierPart(parser.source[parser.position]) {
		parser.position++
	}
	name := parser.source[start:parser.position]
	for parser.position < len(parser.source) && parser.source[parser.position] == '.' {
		next := parser.position + 1
		if next >= len(parser.source) || !isLuaIdentifierStart(parser.source[next]) {
			break
		}
		parser.position = next
		for parser.position < len(parser.source) && isLuaIdentifierPart(parser.source[parser.position]) {
			parser.position++
		}
		name = parser.source[start:parser.position]
	}
	return name
}

func (parser *luaParser) consumeKeyword(keyword string) bool {
	if !strings.HasPrefix(parser.source[parser.position:], keyword) {
		return false
	}
	end := parser.position + len(keyword)
	if end < len(parser.source) && isLuaIdentifierPart(parser.source[end]) {
		return false
	}
	parser.position = end
	return true
}

func (parser *luaParser) skipSpace() {
	for parser.position < len(parser.source) {
		character := parser.source[parser.position]
		if unicode.IsSpace(rune(character)) {
			parser.position++
			continue
		}
		if character == '-' && strings.HasPrefix(parser.source[parser.position:], "--") {
			if close, ok := luaBlockCommentClose(parser.source[parser.position:]); ok {
				parser.position += close
				continue
			}
			newline := strings.IndexByte(parser.source[parser.position:], '\n')
			if newline < 0 {
				parser.position = len(parser.source)
				return
			}
			parser.position += newline + 1
			continue
		}
		return
	}
}

func (parser *luaParser) errorf(format string, args ...any) error {
	line := 1 + strings.Count(parser.source[:parser.position], "\n")
	return fmt.Errorf("line %d: %s", line, fmt.Sprintf(format, args...))
}

func isLuaIdentifierStart(character byte) bool {
	return character == '_' || (character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z')
}

func isLuaIdentifierPart(character byte) bool {
	return isLuaIdentifierStart(character) || (character >= '0' && character <= '9')
}

func luaTruthy(value any) bool {
	return value != nil && value != false
}

func luaEquals(left, right any) bool {
	if left == nil || right == nil {
		return left == nil && right == nil
	}
	if leftNumber, ok := Float(left); ok {
		if rightNumber, ok := Float(right); ok {
			return leftNumber == rightNumber
		}
	}
	if leftString, ok := left.(string); ok {
		if rightString, ok := right.(string); ok {
			return leftString == rightString
		}
	}
	if leftBool, ok := left.(bool); ok {
		if rightBool, ok := right.(bool); ok {
			return leftBool == rightBool
		}
	}
	return left == right
}

func luaCompare(operator string, left, right any) (any, error) {
	if leftNumber, ok := Float(left); ok {
		if rightNumber, ok := Float(right); ok {
			switch operator {
			case "<":
				return leftNumber < rightNumber, nil
			case "<=":
				return leftNumber <= rightNumber, nil
			case ">":
				return leftNumber > rightNumber, nil
			case ">=":
				return leftNumber >= rightNumber, nil
			}
		}
	}
	if leftString, ok := left.(string); ok {
		if rightString, ok := right.(string); ok {
			switch operator {
			case "<":
				return leftString < rightString, nil
			case "<=":
				return leftString <= rightString, nil
			case ">":
				return leftString > rightString, nil
			case ">=":
				return leftString >= rightString, nil
			}
		}
	}
	return nil, fmt.Errorf("cannot compare %T %s %T", left, operator, right)
}
