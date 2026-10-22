package questiedb

import (
	"bytes"
	"compress/zlib"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"sort"
)

// DecodeCBOR decodes the small CBOR subset used by the baked QuestieDB TOC.
// It intentionally accepts only definite/indefinite arrays and maps, byte and
// text strings, integers, floats, booleans, null, and ignored tags.
func DecodeCBOR(data []byte) (any, error) {
	decoder := cborDecoder{data: data}
	value, err := decoder.value()
	if err != nil {
		return nil, err
	}
	if decoder.offset != len(data) {
		return nil, fmt.Errorf("CBOR payload has %d trailing bytes", len(data)-decoder.offset)
	}
	return value, nil
}

// DecodeBaked decodes a base64 TOC value. When inflate is true the decoded
// bytes are zlib-compressed (the entity ID lists use this form).
func DecodeBaked(value string, inflate bool) (any, error) {
	raw, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		return nil, fmt.Errorf("decode base64: %w", err)
	}
	if inflate {
		reader, err := zlib.NewReader(bytes.NewReader(raw))
		if err != nil {
			return nil, fmt.Errorf("open zlib payload: %w", err)
		}
		defer reader.Close()
		raw, err = io.ReadAll(reader)
		if err != nil {
			return nil, fmt.Errorf("inflate zlib payload: %w", err)
		}
	}
	return DecodeCBOR(raw)
}

type cborDecoder struct {
	data   []byte
	offset int
}

func (decoder *cborDecoder) value() (any, error) {
	if decoder.offset >= len(decoder.data) {
		return nil, fmt.Errorf("unexpected end of CBOR payload")
	}
	initial := decoder.data[decoder.offset]
	decoder.offset++
	major := initial >> 5
	additional := initial & 0x1f
	length, indefinite, err := decoder.length(additional)
	if err != nil {
		return nil, err
	}
	switch major {
	case 0:
		if indefinite {
			return nil, fmt.Errorf("indefinite unsigned integer")
		}
		if length > math.MaxInt64 {
			return length, nil
		}
		return int64(length), nil
	case 1:
		if indefinite {
			return nil, fmt.Errorf("indefinite negative integer")
		}
		if length > math.MaxInt64 {
			return nil, fmt.Errorf("negative integer out of range")
		}
		return -1 - int64(length), nil
	case 2:
		if indefinite {
			return decoder.indefiniteBytes()
		}
		return decoder.take(int(length))
	case 3:
		if indefinite {
			return decoder.indefiniteText()
		}
		raw, err := decoder.take(int(length))
		if err != nil {
			return nil, err
		}
		return string(raw), nil
	case 4:
		if indefinite {
			items := []any{}
			for {
				if decoder.peek() == 0xff {
					decoder.offset++
					return items, nil
				}
				item, err := decoder.value()
				if err != nil {
					return nil, err
				}
				items = append(items, item)
			}
		}
		items := make([]any, 0, length)
		for i := uint64(0); i < length; i++ {
			item, err := decoder.value()
			if err != nil {
				return nil, err
			}
			items = append(items, item)
		}
		return items, nil
	case 5:
		result := map[any]any{}
		if indefinite {
			for {
				if decoder.peek() == 0xff {
					decoder.offset++
					return result, nil
				}
				key, err := decoder.value()
				if err != nil {
					return nil, err
				}
				value, err := decoder.value()
				if err != nil {
					return nil, err
				}
				result[canonicalKey(key)] = value
			}
		}
		for i := uint64(0); i < length; i++ {
			key, err := decoder.value()
			if err != nil {
				return nil, err
			}
			value, err := decoder.value()
			if err != nil {
				return nil, err
			}
			result[canonicalKey(key)] = value
		}
		return result, nil
	case 6:
		if indefinite {
			return nil, fmt.Errorf("indefinite CBOR tag")
		}
		// Tags carry no meaning for the baked entity values.
		return decoder.value()
	case 7:
		if indefinite {
			return nil, fmt.Errorf("indefinite simple value")
		}
		switch additional {
		case 20:
			return false, nil
		case 21:
			return true, nil
		case 22, 23:
			return nil, nil
		case 25:
			if length > math.MaxUint16 {
				return nil, fmt.Errorf("invalid half float")
			}
			return halfToFloat(uint16(length)), nil
		case 26:
			return float64(math.Float32frombits(uint32(length))), nil
		case 27:
			return math.Float64frombits(length), nil
		default:
			return nil, fmt.Errorf("unsupported CBOR simple value %d", additional)
		}
	default:
		return nil, fmt.Errorf("unsupported CBOR major type %d", major)
	}
}

func (decoder *cborDecoder) length(additional byte) (uint64, bool, error) {
	switch {
	case additional < 24:
		return uint64(additional), false, nil
	case additional == 24:
		raw, err := decoder.take(1)
		if err != nil {
			return 0, false, err
		}
		return uint64(raw[0]), false, nil
	case additional == 25:
		raw, err := decoder.take(2)
		if err != nil {
			return 0, false, err
		}
		return uint64(binary.BigEndian.Uint16(raw)), false, nil
	case additional == 26:
		raw, err := decoder.take(4)
		if err != nil {
			return 0, false, err
		}
		return uint64(binary.BigEndian.Uint32(raw)), false, nil
	case additional == 27:
		raw, err := decoder.take(8)
		if err != nil {
			return 0, false, err
		}
		return binary.BigEndian.Uint64(raw), false, nil
	case additional == 31:
		return 0, true, nil
	default:
		return 0, false, fmt.Errorf("invalid CBOR additional information %d", additional)
	}
}

func (decoder *cborDecoder) indefiniteBytes() (any, error) {
	var buffer bytes.Buffer
	for {
		if decoder.peek() == 0xff {
			decoder.offset++
			return buffer.Bytes(), nil
		}
		chunk, err := decoder.value()
		if err != nil {
			return nil, err
		}
		raw, ok := chunk.([]byte)
		if !ok {
			return nil, fmt.Errorf("indefinite byte string contains %T", chunk)
		}
		buffer.Write(raw)
	}
}

func (decoder *cborDecoder) indefiniteText() (any, error) {
	var buffer bytes.Buffer
	for {
		if decoder.peek() == 0xff {
			decoder.offset++
			return buffer.String(), nil
		}
		chunk, err := decoder.value()
		if err != nil {
			return nil, err
		}
		text, ok := chunk.(string)
		if !ok {
			return nil, fmt.Errorf("indefinite text string contains %T", chunk)
		}
		buffer.WriteString(text)
	}
}

func (decoder *cborDecoder) take(length int) ([]byte, error) {
	if length < 0 || decoder.offset+length > len(decoder.data) {
		return nil, fmt.Errorf("unexpected end of CBOR payload")
	}
	raw := decoder.data[decoder.offset : decoder.offset+length]
	decoder.offset += length
	return raw, nil
}

func (decoder *cborDecoder) peek() byte {
	if decoder.offset >= len(decoder.data) {
		return 0
	}
	return decoder.data[decoder.offset]
}

func halfToFloat(value uint16) float64 {
	sign := value >> 15
	exponent := (value >> 10) & 0x1f
	fraction := value & 0x3ff
	var result float64
	switch exponent {
	case 0:
		result = math.Ldexp(float64(fraction), -24)
	case 31:
		if fraction == 0 {
			result = math.Inf(1)
		} else {
			result = math.NaN()
		}
	default:
		result = math.Ldexp(float64(fraction+1024), int(exponent)-25)
	}
	if sign != 0 {
		return -result
	}
	return result
}

func canonicalKey(key any) any {
	switch typed := key.(type) {
	case []byte:
		return string(typed)
	case int64:
		if typed >= math.MinInt && typed <= math.MaxInt {
			return int(typed)
		}
		return typed
	case uint64:
		if typed <= math.MaxInt {
			return int(typed)
		}
		return typed
	default:
		return key
	}
}

// Int converts a decoded numeric value to an int.
func Int(value any) (int, bool) {
	switch typed := value.(type) {
	case int:
		return typed, true
	case int64:
		return int(typed), typed >= math.MinInt && typed <= math.MaxInt
	case uint64:
		return int(typed), typed <= math.MaxInt
	case float64:
		if math.Trunc(typed) == typed && typed >= math.MinInt && typed <= math.MaxInt {
			return int(typed), true
		}
	}
	return 0, false
}

// Float converts a decoded numeric value to a float64.
func Float(value any) (float64, bool) {
	switch typed := value.(type) {
	case int:
		return float64(typed), true
	case int64:
		return float64(typed), true
	case uint64:
		return float64(typed), true
	case float64:
		return typed, true
	}
	return 0, false
}

// MapGet reads a Lua-style one-based array or integer-keyed map.
func MapGet(value any, key int) any {
	switch typed := value.(type) {
	case map[any]any:
		return typed[key]
	case []any:
		if key >= 1 && key <= len(typed) {
			return typed[key-1]
		}
	}
	return nil
}

// Array returns a Lua-style array. Integer-keyed maps are returned in key order.
func Array(value any) []any {
	switch typed := value.(type) {
	case []any:
		return typed
	case *LuaTable:
		keys := typed.IntKeys()
		result := make([]any, 0, len(keys))
		for _, key := range keys {
			result = append(result, typed.Numbers[key])
		}
		return result
	case map[any]any:
		type keyed struct {
			key   int
			value any
		}
		items := make([]keyed, 0, len(typed))
		for key, item := range typed {
			if index, ok := Int(key); ok {
				items = append(items, keyed{index, item})
			}
		}
		sort.Slice(items, func(i, j int) bool { return items[i].key < items[j].key })
		result := make([]any, 0, len(items))
		for _, item := range items {
			result = append(result, item.value)
		}
		return result
	}
	return nil
}

// Ints returns every integer in an array or integer-keyed map.
func Ints(value any) []int {
	items := Array(value)
	result := make([]int, 0, len(items))
	seen := map[int]bool{}
	for _, item := range items {
		if number, ok := Int(item); ok && !seen[number] {
			seen[number] = true
			result = append(result, number)
		}
	}
	sort.Ints(result)
	return result
}
