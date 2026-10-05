package zones

import "testing"

func TestUIMapKnownClassicZones(t *testing.T) {
	elwynn, ok := UIMap(12)
	if !ok || elwynn != 1429 {
		t.Fatalf("Elwynn zone 12 = %d, %v", elwynn, ok)
	}
	tanaris, ok := UIMap(440)
	if !ok || tanaris != 1446 {
		t.Fatalf("Tanaris zone 440 = %d, %v", tanaris, ok)
	}
}

func TestUIMapZephrasIsle(t *testing.T) {
	uiMapID, ok := UIMap(16593)
	if !ok || uiMapID != 2521 {
		t.Fatalf("Zephras Isle zone 16593 = %d, %v", uiMapID, ok)
	}
}

func TestUIMapUnverifiedZoneEmitsNoPin(t *testing.T) {
	uiMapID, ok := UIMap(28)
	if !ok || uiMapID != 0 {
		t.Fatalf("unverified zone 28 = %d, %v", uiMapID, ok)
	}
}

func TestUIMapUnknownZoneIsMissing(t *testing.T) {
	if _, ok := UIMap(99999); ok {
		t.Fatal("unknown zone was present")
	}
}
