n(QUESTS, {
	q(1001, {
		["qg"] = 1,
		["coord"] = { 1.0, 2.0, MAP.ELWYNN_FOREST },
		-- #if AFTER CATA
		["races"] = HORDE_ONLY,
		-- #else
		["races"] = ALLIANCE_ONLY,
		-- #endif
	}),
	-- #if SEASON_OF_DISCOVERY
	q(1002, {
		["qg"] = 2,
		["coord"] = { 3.0, 4.0, MAP.ELWYNN_FOREST },
	}),
	-- #endif
	-- #if BEFORE CATA
	q(1003, {
		["qg"] = 3,
		["coord"] = { 5.0, 6.0, MAP.ELWYNN_FOREST },
	}),
	-- #endif
});
