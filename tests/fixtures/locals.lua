local TIER = {
	100,
	101,
	102,
};

root(ROOTS.PVP, {
	n(QUESTS, {
		q(8368, {
			["altQuests"] = TIER,
			["qg"] = 15350,
			["coord"] = { 80.0, 30.0, MAP.ORGRIMMAR },
			["races"] = HORDE_ONLY,
			["lvl"] = { 10, 19 },
		}),
	}),
});
