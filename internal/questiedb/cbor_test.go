package questiedb

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"testing"
)

func TestDecodeCBORPrimitives(t *testing.T) {
	cases := []struct {
		name string
		data []byte
		want any
	}{
		{"unsigned", []byte{0x18, 0x64}, int64(100)},
		{"negative", []byte{0x20}, int64(-1)},
		{"text", []byte{0x62, 'h', 'i'}, "hi"},
		{"bytes", []byte{0x42, 0x68, 0x69}, []byte("hi")},
		{"array", []byte{0x82, 0x01, 0x02}, []any{int64(1), int64(2)}},
		{"map", []byte{0xa1, 0x01, 0x61, 'a'}, map[any]any{1: "a"}},
		{"bool", []byte{0xf5}, true},
	}
	for _, test := range cases {
		t.Run(test.name, func(t *testing.T) {
			got, err := DecodeCBOR(test.data)
			if err != nil {
				t.Fatal(err)
			}
			if !equalCBOR(got, test.want) {
				t.Fatalf("got %#v, want %#v", got, test.want)
			}
		})
	}
}

func equalCBOR(left, right any) bool {
	switch leftValue := left.(type) {
	case []byte:
		rightValue, ok := right.([]byte)
		return ok && bytes.Equal(leftValue, rightValue)
	case []any:
		rightValue, ok := right.([]any)
		if !ok || len(leftValue) != len(rightValue) {
			return false
		}
		for index := range leftValue {
			if !equalCBOR(leftValue[index], rightValue[index]) {
				return false
			}
		}
		return true
	case map[any]any:
		rightValue, ok := right.(map[any]any)
		if !ok || len(leftValue) != len(rightValue) {
			return false
		}
		for key, value := range leftValue {
			if !equalCBOR(value, rightValue[key]) {
				return false
			}
		}
		return true
	default:
		return left == right
	}
}

func TestDecodeCBORRejectsTruncatedInput(t *testing.T) {
	if _, err := DecodeCBOR([]byte{0x62, 'h'}); err == nil {
		t.Fatal("expected truncated text to fail")
	}
	if _, err := DecodeCBOR([]byte{0x82, 0x01}); err == nil {
		t.Fatal("expected truncated array to fail")
	}
}

func TestDecodeBakedInflatesZlib(t *testing.T) {
	var compressed bytes.Buffer
	writer := zlib.NewWriter(&compressed)
	if _, err := writer.Write([]byte{0x82, 0x01, 0x02}); err != nil {
		t.Fatal(err)
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	encoded := base64.StdEncoding.EncodeToString(compressed.Bytes())
	value, err := DecodeBaked(encoded, true)
	if err != nil {
		t.Fatal(err)
	}
	if got := Ints(value); len(got) != 2 || got[0] != 1 || got[1] != 2 {
		t.Fatalf("got %v, want [1 2]", got)
	}
}

func TestIntsHandlesLuaTablesAndCBORMaps(t *testing.T) {
	table := NewLuaTable()
	if err := table.Set(1, 10); err != nil {
		t.Fatal(err)
	}
	if err := table.Set(2, 4); err != nil {
		t.Fatal(err)
	}
	if got := Ints(table); len(got) != 2 || got[0] != 4 || got[1] != 10 {
		t.Fatalf("LuaTable ints = %v, want [4 10]", got)
	}
	mapValue := map[any]any{1: int64(9), 2: int64(2)}
	if got := Ints(mapValue); len(got) != 2 || got[0] != 2 || got[1] != 9 {
		t.Fatalf("map ints = %v, want [2 9]", got)
	}
}
