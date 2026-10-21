package attdsl

import (
	"fmt"
	"math"
	"strconv"
	"strings"

	"github.com/yuin/gopher-lua/ast"
	"github.com/yuin/gopher-lua/parse"
)

type LuaTable struct {
	Array   []any
	Mapping map[any]any
	Keys    []any
}

func NewLuaTable() *LuaTable { return &LuaTable{Mapping: map[any]any{}} }

func (table *LuaTable) Set(key, value any) {
	if index, ok := key.(int); ok && index > 0 {
		for len(table.Array) < index {
			table.Array = append(table.Array, nil)
		}
		table.Array[index-1] = value
		return
	}
	table.Mapping[key] = value
	if !containsKey(table.Keys, key) {
		table.Keys = append(table.Keys, key)
	}
}

func (table *LuaTable) Get(key any) any {
	if index, ok := key.(int); ok && index > 0 && index <= len(table.Array) {
		return table.Array[index-1]
	}
	return table.Mapping[key]
}

func (table *LuaTable) Items() []TableEntry {
	items := make([]TableEntry, 0, len(table.Array)+len(table.Mapping))
	for index, value := range table.Array {
		if value != nil {
			items = append(items, TableEntry{index + 1, value})
		}
	}
	for _, key := range table.Keys {
		if value, ok := table.Mapping[key]; ok {
			items = append(items, TableEntry{key, value})
		}
	}
	return items
}

type TableEntry struct{ Key, Value any }
type unresolved struct{ Name string }
type factionRaces struct{ Faction string }
type skippedFunction struct{ Params []string }
type builtin func([]any) (any, error)
type rootRecord struct{ Category, Data any }

type Environment struct {
	Values map[string]any
	Roots  []rootRecord
}

func ParseLua(source, filename string) ([]ast.Stmt, error) {
	statements, err := parse.Parse(strings.NewReader(source), filename)
	if err != nil {
		return nil, err
	}
	return statements, nil
}

func NewEnvironment(ctx BuildContext) *Environment {
	env := &Environment{Values: map[string]any{}}
	env.Values["_G"] = env
	mapTable := NewLuaTable()
	for name, id := range ctx.Maps {
		mapTable.Set(name, id)
		env.Values[name] = id
	}
	timelineTable := NewLuaTable()
	for name, value := range ctx.Timelines {
		timelineTable.Set(name, value)
		env.Values[name] = value
	}
	env.Values["MAP"], env.Values["TIMELINE"] = mapTable, timelineTable
	roots := NewLuaTable()
	for _, name := range []string{"Zones", "Instances", "PVP", "Holidays", "WorldEvents", "Professions", "Character", "ExpansionFeatures"} {
		roots.Set(name, name)
	}
	env.Values["ROOTS"] = roots
	for name, value := range map[string]int{"NEUTRAL": 0, "FRIENDLY": 3000, "HONORED": 9000, "REVERED": 21000, "EXALTED": 42000, "UNFRIENDLY": -3000, "HOSTILE": -6000, "HATED": -42000, "IGNORED_VALUE": 0} {
		env.Values[name] = value
	}
	env.Values["ALLIANCE_ONLY"] = factionRaces{"Alliance"}
	env.Values["HORDE_ONLY"] = factionRaces{"Horde"}
	for name, id := range RaceIDs {
		env.Values[name] = id
	}
	for name, id := range ClassIDs {
		env.Values[name] = id
	}
	for name, id := range ProfessionIDs {
		env.Values[name] = id
	}
	for name, id := range ctx.Maps {
		env.Values[name] = id
	}
	for name, value := range ctx.Timelines {
		env.Values[name] = value
	}
	env.installBuiltins()
	return env
}

func (env *Environment) value(name string) any {
	if value, exists := env.Values[name]; exists {
		return value
	}
	return unresolved{Name: name}
}

func (env *Environment) Evaluate(statements []ast.Stmt) error {
	for _, statement := range statements {
		if err := env.evalStatement(statement); err != nil {
			return err
		}
	}
	return nil
}

func (env *Environment) evalStatement(statement ast.Stmt) error {
	switch node := statement.(type) {
	case *ast.AssignStmt:
		values := make([]any, 0, len(node.Rhs))
		for _, expression := range node.Rhs {
			value, err := env.evalExpression(expression)
			if err != nil {
				return err
			}
			values = append(values, value)
		}
		return env.assign(node.Lhs, values)
	case *ast.LocalAssignStmt:
		values := make([]any, 0, len(node.Exprs))
		for _, expression := range node.Exprs {
			value, err := env.evalExpression(expression)
			if err != nil {
				return err
			}
			values = append(values, value)
		}
		for index, name := range node.Names {
			if index < len(values) {
				env.Values[name] = values[index]
			} else {
				env.Values[name] = nil
			}
		}
	case *ast.FuncDefStmt:
		if node.Name != nil && len(node.Name.Method) == 0 {
			name, ok := node.Name.Func.(*ast.IdentExpr)
			if ok {
				env.Values[name.Value] = skippedFunction{Params: node.Func.ParList.Names}
			}
		}
	case *ast.FuncCallStmt:
		value, err := env.evalExpression(node.Expr)
		if err != nil {
			return err
		}
		if table, ok := value.(*LuaTable); ok {
			if len(env.Roots) == 0 || env.Roots[len(env.Roots)-1].Data != table {
				env.Roots = append(env.Roots, rootRecord{Category: "loose", Data: table})
			}
		}
	case *ast.DoBlockStmt:
		for _, child := range node.Stmts {
			if err := env.evalStatement(child); err != nil {
				return err
			}
		}
	case *ast.IfStmt:
		condition, err := env.evalExpression(node.Condition)
		if err != nil {
			return err
		}
		if truthy(condition) {
			for _, child := range node.Then {
				if err := env.evalStatement(child); err != nil {
					return err
				}
			}
		} else {
			for _, child := range node.Else {
				if err := env.evalStatement(child); err != nil {
					return err
				}
			}
		}
	case *ast.GenericForStmt:
		values := make([]any, 0, len(node.Exprs))
		for _, expression := range node.Exprs {
			value, err := env.evalExpression(expression)
			if err != nil {
				return err
			}
			values = append(values, value)
		}
		if len(values) == 0 {
			return nil
		}
		table, ok := values[0].(*LuaTable)
		if !ok {
			return nil
		}
		previous := make(map[string]any, len(node.Names))
		existed := make(map[string]bool, len(node.Names))
		for _, name := range node.Names {
			previous[name], existed[name] = env.Values[name], env.has(name)
		}
		for _, item := range table.Items() {
			loopValues := []any{item.Key, item.Value}
			for index, name := range node.Names {
				if index < len(loopValues) {
					env.Values[name] = loopValues[index]
				} else {
					env.Values[name] = nil
				}
			}
			for _, child := range node.Stmts {
				if err := env.evalStatement(child); err != nil {
					return err
				}
			}
		}
		for _, name := range node.Names {
			if existed[name] {
				env.Values[name] = previous[name]
			} else {
				delete(env.Values, name)
			}
		}
	case *ast.NumberForStmt, *ast.WhileStmt, *ast.RepeatStmt, *ast.ReturnStmt, *ast.BreakStmt, *ast.GotoStmt, *ast.LabelStmt:
		// ATT data files use loops only for parser-time helpers. The source converter
		// deliberately skips those bodies rather than executing arbitrary code.
	default:
		return fmt.Errorf("unsupported Lua statement %T", statement)
	}
	return nil
}

func (env *Environment) has(name string) bool { _, ok := env.Values[name]; return ok }

func (env *Environment) assign(targets []ast.Expr, values []any) error {
	for index, target := range targets {
		var value any
		if index < len(values) {
			value = values[index]
		}
		switch lhs := target.(type) {
		case *ast.IdentExpr:
			env.Values[lhs.Value] = value
		case *ast.AttrGetExpr:
			object, err := env.evalExpression(lhs.Object)
			if err != nil {
				return err
			}
			key, err := env.evalExpression(lhs.Key)
			if err != nil {
				return err
			}
			table, ok := object.(*LuaTable)
			if !ok {
				if object == nil {
					table, ok = NewLuaTable(), true
				}
				if _, isUnknown := object.(unresolved); isUnknown {
					table, ok = NewLuaTable(), true
				}
				if environment, isEnvironment := object.(*Environment); isEnvironment {
					if name, isString := key.(string); isString {
						environment.Values[name] = value
						continue
					}
				}
				if !ok {
					return fmt.Errorf("cannot assign field on %T", object)
				}
			}
			table.Set(key, value)
		default:
			return fmt.Errorf("unsupported Lua assignment target %T", target)
		}
	}
	return nil
}

func (env *Environment) evalExpression(expression ast.Expr) (any, error) {
	switch node := expression.(type) {
	case *ast.NilExpr:
		return nil, nil
	case *ast.TrueExpr:
		return true, nil
	case *ast.FalseExpr:
		return false, nil
	case *ast.NumberExpr:
		if strings.HasPrefix(strings.ToLower(node.Value), "0x") {
			value, err := strconv.ParseInt(node.Value[2:], 16, 64)
			return int(value), err
		}
		if strings.ContainsAny(node.Value, ".eE") {
			return strconv.ParseFloat(node.Value, 64)
		}
		value, err := strconv.ParseInt(node.Value, 10, 64)
		return int(value), err
	case *ast.StringExpr:
		return node.Value, nil
	case *ast.IdentExpr:
		return env.value(node.Value), nil
	case *ast.TableExpr:
		table := NewLuaTable()
		arrayIndex := 1
		for _, field := range node.Fields {
			value, err := env.evalExpression(field.Value)
			if err != nil {
				return nil, err
			}
			if field.Key == nil {
				table.Set(arrayIndex, value)
				arrayIndex++
				continue
			}
			key, err := env.evalExpression(field.Key)
			if err != nil {
				return nil, err
			}
			table.Set(key, value)
		}
		return table, nil
	case *ast.AttrGetExpr:
		object, err := env.evalExpression(node.Object)
		if err != nil {
			return nil, err
		}
		key, err := env.evalExpression(node.Key)
		if err != nil {
			return nil, err
		}
		if table, ok := object.(*LuaTable); ok {
			value := table.Get(key)
			if value == nil {
				if _, isString := key.(string); isString {
					value = NewLuaTable()
					table.Set(key, value)
				}
			}
			return value, nil
		}
		if environment, ok := object.(*Environment); ok {
			if name, ok := key.(string); ok {
				return environment.value(name), nil
			}
		}
		if unknown, ok := object.(unresolved); ok {
			return unresolved{Name: unknown.Name + "." + luaString(key)}, nil
		}
		return nil, nil
	case *ast.FuncCallExpr:
		return env.call(node)
	case *ast.FunctionExpr:
		return skippedFunction{Params: node.ParList.Names}, nil
	case *ast.UnaryNotOpExpr:
		value, err := env.evalExpression(node.Expr)
		return !truthy(value), err
	case *ast.UnaryMinusOpExpr:
		value, err := env.evalExpression(node.Expr)
		if err != nil {
			return nil, err
		}
		number, ok := numeric(value)
		if !ok {
			return nil, fmt.Errorf("unary minus expects number")
		}
		return -number, nil
	case *ast.UnaryLenOpExpr:
		value, err := env.evalExpression(node.Expr)
		if err != nil {
			return nil, err
		}
		if table, ok := value.(*LuaTable); ok {
			return len(table.Array), nil
		}
		if text, ok := value.(string); ok {
			return len(text), nil
		}
		return 0, nil
	case *ast.ArithmeticOpExpr:
		return env.evalArithmetic(node)
	case *ast.RelationalOpExpr:
		return env.evalRelational(node)
	case *ast.LogicalOpExpr:
		left, err := env.evalExpression(node.Lhs)
		if err != nil {
			return nil, err
		}
		if node.Operator == "and" {
			if !truthy(left) {
				return left, nil
			}
			return env.evalExpression(node.Rhs)
		}
		if truthy(left) {
			return left, nil
		}
		return env.evalExpression(node.Rhs)
	case *ast.StringConcatOpExpr:
		left, err := env.evalExpression(node.Lhs)
		if err != nil {
			return nil, err
		}
		right, err := env.evalExpression(node.Rhs)
		if err != nil {
			return nil, err
		}
		return luaString(left) + luaString(right), nil
	default:
		return nil, fmt.Errorf("unsupported Lua expression %T", expression)
	}
}

func (env *Environment) evalArithmetic(node *ast.ArithmeticOpExpr) (any, error) {
	leftValue, err := env.evalExpression(node.Lhs)
	if err != nil {
		return nil, err
	}
	rightValue, err := env.evalExpression(node.Rhs)
	if err != nil {
		return nil, err
	}
	left, leftOK := numeric(leftValue)
	right, rightOK := numeric(rightValue)
	if !leftOK || !rightOK {
		return nil, fmt.Errorf("operator %s requires numeric operands", node.Operator)
	}
	switch node.Operator {
	case "+":
		return left + right, nil
	case "-":
		return left - right, nil
	case "*":
		return left * right, nil
	case "/":
		return left / right, nil
	case "//":
		return math.Floor(left / right), nil
	case "%":
		return math.Mod(left, right), nil
	case "^":
		return math.Pow(left, right), nil
	default:
		return nil, fmt.Errorf("unsupported arithmetic operator %s", node.Operator)
	}
}

func (env *Environment) evalRelational(node *ast.RelationalOpExpr) (any, error) {
	left, err := env.evalExpression(node.Lhs)
	if err != nil {
		return nil, err
	}
	right, err := env.evalExpression(node.Rhs)
	if err != nil {
		return nil, err
	}
	if leftNumber, ok := numeric(left); ok {
		if rightNumber, ok := numeric(right); ok {
			switch node.Operator {
			case "==":
				return leftNumber == rightNumber, nil
			case "~=":
				return leftNumber != rightNumber, nil
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
	leftString, leftOK := left.(string)
	rightString, rightOK := right.(string)
	if leftOK && rightOK {
		switch node.Operator {
		case "==":
			return leftString == rightString, nil
		case "~=":
			return leftString != rightString, nil
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
	switch node.Operator {
	case "==":
		return left == right, nil
	case "~=":
		return left != right, nil
	}
	return nil, fmt.Errorf("unsupported comparison %s for %T and %T", node.Operator, left, right)
}

func (env *Environment) call(node *ast.FuncCallExpr) (any, error) {
	var function any
	var err error
	var methodReceiver any
	if node.Receiver != nil {
		receiver, evalErr := env.evalExpression(node.Receiver)
		if evalErr != nil {
			return nil, evalErr
		}
		methodReceiver = receiver
		function, err = env.method(receiver, node.Method)
	} else {
		function, err = env.evalExpression(node.Func)
	}
	if err != nil {
		return nil, err
	}
	args := make([]any, 0, len(node.Args))
	if node.Receiver != nil {
		args = append(args, methodReceiver)
	}
	for _, expression := range node.Args {
		value, evalErr := env.evalExpression(expression)
		if evalErr != nil {
			return nil, evalErr
		}
		args = append(args, value)
	}
	switch callable := function.(type) {
	case builtin:
		return callable(args)
	case skippedFunction:
		for index := len(args) - 1; index >= 0; index-- {
			if _, ok := args[index].(*LuaTable); ok {
				return args[index], nil
			}
		}
		if len(args) > 0 {
			return args[len(args)-1], nil
		}
		return nil, nil
	case unresolved:
		return genericStruct(callable.Name, args), nil
	case nil:
		return nil, nil
	default:
		return nil, fmt.Errorf("attempt to call non-function %T", function)
	}
}

func (env *Environment) method(receiver any, name string) (any, error) {
	if table, ok := receiver.(*LuaTable); ok {
		if nested, ok := table.Get(name).(builtin); ok {
			return nested, nil
		}
	}
	return nil, fmt.Errorf("unknown method %s on %T", name, receiver)
}

func (env *Environment) installBuiltins() {
	add := func(names []string, function builtin) {
		for _, name := range names {
			env.Values[name] = function
		}
	}
	constructor := func(field string) builtin {
		return func(args []any) (any, error) {
			var ident, data any
			if len(args) > 0 {
				ident = args[0]
			}
			if len(args) > 1 {
				data = args[1]
			}
			return structValue(field, ident, data), nil
		}
	}
	add([]string{"q", "quest"}, constructor("questID"))
	add([]string{"n", "npc"}, constructor("npcID"))
	add([]string{"m", "map"}, constructor("mapID"))
	add([]string{"inst"}, constructor("instanceID"))
	add([]string{"ach", "achievement"}, constructor("achievementID"))
	add([]string{"i", "item"}, constructor("itemID"))
	add([]string{"o", "object"}, constructor("objectID"))
	add([]string{"sp", "spell"}, constructor("spellID"))
	add([]string{"r", "recipe"}, constructor("recipeID"))
	add([]string{"faction"}, constructor("factionID"))
	add([]string{"objective", "qo", "questobjective"}, constructor("objectiveID"))
	add([]string{"exploration", "visit_exploration"}, constructor("explorationID"))
	add([]string{"prof", "profession"}, constructor("professionID"))
	add([]string{"filter"}, constructor("filterID"))
	add([]string{"cl", "class"}, constructor("classID"))
	add([]string{"race"}, constructor("raceID"))
	add([]string{"header"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		var data any
		for _, arg := range args[1:] {
			if _, ok := arg.(*LuaTable); ok {
				data = arg
			}
		}
		return structValue("headerID", args[0], data), nil
	})
	add([]string{"struct"}, func(args []any) (any, error) {
		if len(args) < 2 {
			return nil, nil
		}
		var data any
		if len(args) > 2 {
			data = args[2]
		}
		return structValue(luaString(args[0]), args[1], data), nil
	})
	add([]string{"bubbleDown"}, func(args []any) (any, error) {
		if len(args) < 2 {
			return nil, nil
		}
		return bubbleDown(args[0], args[1]), nil
	})
	add([]string{"bubbleDownSelf"}, func(args []any) (any, error) {
		var data, target any
		if len(args) > 0 {
			data = args[0]
		}
		if len(args) > 1 {
			target = args[1]
		}
		target = asGroups(target)
		return bubbleDown(data, target), nil
	})
	add([]string{"applyData", "applyDataSelf"}, func(args []any) (any, error) {
		if len(args) > 1 {
			if data, ok := args[0].(*LuaTable); ok {
				if target, ok := args[1].(*LuaTable); ok {
					applyData(data, target)
				}
			}
			return args[1], nil
		}
		return nil, nil
	})
	add([]string{"clone"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		copy := copyValue(args[0])
		if len(args) < 2 {
			return copy, nil
		}
		if target, ok := args[1].(*LuaTable); ok {
			if source, ok := copy.(*LuaTable); ok {
				applyData(source, target)
				return target, nil
			}
		}
		return copy, nil
	})
	add([]string{"a"}, func(args []any) (any, error) {
		var value any
		if len(args) > 0 {
			value = args[0]
		}
		table := asGroups(value)
		if table.Get("races") == nil {
			table.Set("races", factionRaces{"Alliance"})
		}
		return table, nil
	})
	add([]string{"h"}, func(args []any) (any, error) {
		var value any
		if len(args) > 0 {
			value = args[0]
		}
		table := asGroups(value)
		if table.Get("races") == nil {
			table.Set("races", factionRaces{"Horde"})
		}
		return table, nil
	})
	add([]string{"pvp"}, func(args []any) (any, error) {
		var target any
		if len(args) > 0 {
			target = args[0]
		}
		data := NewLuaTable()
		data.Set("pvp", true)
		return bubbleDown(data, target), nil
	})
	add([]string{"root"}, func(args []any) (any, error) {
		var category, data any
		if len(args) > 0 {
			category = args[0]
		}
		if len(args) > 1 {
			data = args[1]
		}
		env.Roots = append(env.Roots, rootRecord{category, data})
		return data, nil
	})
	add([]string{"maproot"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		data := args[len(args)-1]
		for index := len(args) - 2; index >= 0; index-- {
			data = structValue("mapID", args[index], data)
		}
		env.Roots = append(env.Roots, rootRecord{"Zones", data})
		return data, nil
	})
	add([]string{"battleground"}, func(args []any) (any, error) {
		var mapID, data any
		if len(args) > 0 {
			mapID = args[0]
		}
		if len(args) > 1 {
			data = args[1]
		}
		data = structValue("mapID", mapID, data)
		env.Roots = append(env.Roots, rootRecord{"PVP", data})
		return data, nil
	})
	add([]string{"createHeader"}, func(args []any) (any, error) { return unresolved{Name: "header"}, nil })
	add([]string{"explorationHeader"}, func(args []any) (any, error) { return genericStruct("explorationHeader", args), nil })
	add([]string{"GetRecipeHelperForProfession"}, func(_ []any) (any, error) { return builtin(func([]any) (any, error) { return nil, nil }), nil })
	add([]string{"applyevent", "applyeventself"}, func(args []any) (any, error) {
		data := NewLuaTable()
		data.Set("isYearly", true)
		if len(args) > 0 {
			if id, ok := integer(args[0]); ok {
				data.Set("e", id)
			}
		}
		var target any
		if len(args) > 1 {
			target = args[1]
		}
		return bubbleDown(data, target), nil
	})
	add([]string{"applyclassicphase"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		return args[len(args)-1], nil
	})
	add([]string{"bubbleDownFiltered"}, func(args []any) (any, error) {
		if len(args) < 3 {
			return nil, nil
		}
		return bubbleDown(args[0], args[2]), nil
	})
	add([]string{"bubbleDownAndReplace"}, func(args []any) (any, error) {
		if len(args) < 2 {
			return nil, nil
		}
		return bubbleDown(args[0], args[1]), nil
	})
	add([]string{"print", "error"}, func([]any) (any, error) { return nil, nil })
	add([]string{"type"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return "nil", nil
		}
		switch args[0].(type) {
		case *LuaTable:
			return "table", nil
		case string:
			return "string", nil
		case int, float64:
			return "number", nil
		case bool:
			return "boolean", nil
		default:
			return "function", nil
		}
	})
	add([]string{"tostring"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return "nil", nil
		}
		return luaString(args[0]), nil
	})
	add([]string{"tonumber"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		if _, ok := numeric(args[0]); ok {
			return args[0], nil
		}
		if text, ok := args[0].(string); ok {
			if number, err := strconv.ParseFloat(text, 64); err == nil {
				return number, nil
			}
		}
		return nil, nil
	})
	add([]string{"pairs", "ipairs"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		return args[0], nil
	})
	add([]string{"select"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		return args[len(args)-1], nil
	})
	add([]string{"setmetatable"}, func(args []any) (any, error) {
		if len(args) == 0 {
			return nil, nil
		}
		return args[0], nil
	})
	add([]string{"getmetatable"}, func([]any) (any, error) { return nil, nil })
	add([]string{"rawget"}, func(args []any) (any, error) {
		if len(args) < 2 {
			return nil, nil
		}
		if table, ok := args[0].(*LuaTable); ok {
			return table.Get(args[1]), nil
		}
		return nil, nil
	})
	add([]string{"rawset"}, func(args []any) (any, error) {
		if len(args) < 3 {
			return nil, nil
		}
		if table, ok := args[0].(*LuaTable); ok {
			table.Set(args[1], args[2])
		}
		return nil, nil
	})
	add([]string{"table"}, func([]any) (any, error) { return nil, nil })
	table := NewLuaTable()
	table.Set("insert", builtin(func(args []any) (any, error) {
		if len(args) < 2 {
			return nil, nil
		}
		target, ok := args[0].(*LuaTable)
		if !ok {
			return nil, nil
		}
		if len(args) == 2 {
			target.Array = append(target.Array, args[1])
			return nil, nil
		}
		position, ok := integer(args[1])
		if !ok {
			return nil, nil
		}
		if position < 1 {
			position = 1
		}
		if position > len(target.Array)+1 {
			position = len(target.Array) + 1
		}
		target.Array = append(target.Array, nil)
		copy(target.Array[position:], target.Array[position-1:])
		target.Array[position-1] = args[2]
		return nil, nil
	}))
	env.Values["table"] = table
}

func (env *Environment) callNamed(name string, args []any) (any, error) {
	if function, ok := env.Values[name].(builtin); ok {
		return function(args)
	}
	return nil, fmt.Errorf("unknown function %s", name)
}

func structValue(field string, ident, data any) *LuaTable {
	table := asGroups(data)
	table.Set(field, ident)
	return table
}

func asGroups(value any) *LuaTable {
	if value == nil {
		return NewLuaTable()
	}
	if table, ok := value.(*LuaTable); ok {
		if len(table.Array) > 0 && table.Mapping["groups"] == nil && table.Mapping["g"] == nil {
			wrapper, groups := NewLuaTable(), NewLuaTable()
			groups.Array = append(groups.Array, table.Array...)
			wrapper.Set("groups", groups)
			for key, item := range table.Mapping {
				wrapper.Set(key, item)
			}
			return wrapper
		}
		return table
	}
	table := NewLuaTable()
	table.Set("value", value)
	return table
}

func applyData(data, target *LuaTable) {
	for _, item := range data.Items() {
		key, ok := item.Key.(string)
		if ok && (key == "IgnoreWarnings" || key == "g" || key == "groups") {
			continue
		}
		if target.Get(item.Key) == nil {
			target.Set(item.Key, copyValue(item.Value))
		}
	}
}

func bubbleDown(data, target any) any {
	dataTable, ok := data.(*LuaTable)
	if !ok || target == nil {
		return target
	}
	if table, ok := target.(*LuaTable); ok {
		groups, g := table.Get("groups"), table.Get("g")
		if groups != nil || g != nil {
			applyData(dataTable, table)
			bubbleDown(dataTable, groups)
			bubbleDown(dataTable, g)
			return table
		}
		if len(table.Array) > 0 && len(table.Mapping) == 0 {
			for _, value := range table.Array {
				bubbleDown(dataTable, value)
			}
			return table
		}
		applyData(dataTable, table)
	}
	return target
}

func copyValue(value any) any {
	table, ok := value.(*LuaTable)
	if !ok {
		return value
	}
	copy := NewLuaTable()
	for _, item := range table.Array {
		copy.Array = append(copy.Array, copyValue(item))
	}
	for _, item := range table.Items() {
		if _, isArrayKey := item.Key.(int); !isArrayKey {
			copy.Set(item.Key, copyValue(item.Value))
		}
	}
	return copy
}

func genericStruct(name string, args []any) *LuaTable {
	table := NewLuaTable()
	table.Set("_ctor", name)
	for _, arg := range args {
		if value, ok := arg.(*LuaTable); ok {
			if len(value.Array) > 0 && table.Get("groups") == nil {
				table.Set("groups", value)
				continue
			}
			for _, item := range value.Items() {
				if table.Get(item.Key) == nil {
					table.Set(item.Key, item.Value)
				}
			}
			if len(value.Array) > 0 && table.Get("groups") == nil && len(value.Mapping) == 0 {
				table.Set("groups", value)
			}
		} else if _, isComplex := arg.(factionRaces); !isComplex {
			if table.Get("_id") == nil {
				if _, ok := arg.(unresolved); ok {
					table.Set("_id", arg)
				} else if _, ok := arg.(string); ok {
					table.Set("_id", arg)
				} else if _, ok := numeric(arg); ok {
					table.Set("_id", arg)
				}
			}
		}
	}
	return table
}

func integer(value any) (int, bool) {
	number, ok := numeric(value)
	return int(number), ok && math.Trunc(number) == number
}

func containsKey(keys []any, sought any) bool {
	for _, key := range keys {
		if key == sought {
			return true
		}
	}
	return false
}

func numeric(value any) (float64, bool) {
	switch number := value.(type) {
	case int:
		return float64(number), true
	case int64:
		return float64(number), true
	case float64:
		return number, true
	default:
		return 0, false
	}
}

func truthy(value any) bool { return value != nil && value != false }

func luaString(value any) string {
	switch typed := value.(type) {
	case string:
		return typed
	case int:
		return strconv.Itoa(typed)
	case float64:
		return strconv.FormatFloat(typed, 'g', -1, 64)
	case bool:
		return strconv.FormatBool(typed)
	case unresolved:
		return typed.Name
	case nil:
		return "nil"
	default:
		return fmt.Sprint(value)
	}
}
