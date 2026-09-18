maproot(MAP.MULGORE, {
	groups = {
		q(754, {
			qg = 2948,
			coord = { 48.5, 60.4, MAP.MULGORE },
			timeline = { REMOVED_4_0_3 },
			sourceQuest = 748,
			races = { TAUREN },
			lvl = 4,
		}),
		q(24440, {
			qg = 2948,
			coord = { 48.6, 59.8, MAP.MULGORE },
			timeline = { ADDED_4_0_3 },
			races = { TAUREN },
		}),
		q(748, {
			qg = 2948,
			coord = { 48.5, 60.4, MAP.MULGORE },
			races = { TAUREN },
		}),
	},
});

applyevent(EVENTS.LUNAR_FESTIVAL, {
	groups = {
		q(8673, {
			qg = 15575,
			coord = { 48.4, 53.2, MAP.MULGORE },
		}),
	},
});
