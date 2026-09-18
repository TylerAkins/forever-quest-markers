maproot(MAP.EASTERN_KINGDOMS, MAP.ELWYNN_FOREST, {
	groups = {
		m(MAP.NORTHSHIRE_VALLEY, {
			groups = {
				n(QUESTS, {
					q(783, {
						qg = 823,
						coord = { 48.1, 42.9, MAP.ELWYNN_FOREST },
						races = ALLIANCE_ONLY,
					}),
					q(6, {
						sourceQuest = 18,
						qg = 823,
						coord = { 48.1, 42.9, MAP.ELWYNN_FOREST },
						races = ALLIANCE_ONLY,
						lvl = 2,
						groups = {
							objective(1, {
								provider = { "i", 182 },
								coord = { 57.4, 48.6, MAP.ELWYNN_FOREST },
								cr = 103,
							}),
						},
					}),
					q(3101, {
						sourceQuest = 7,
						providers = {
							{ "n", 197 },
							{ "i", 9570 },
						},
						coord = { 48.9, 41.6, MAP.ELWYNN_FOREST },
						classes = { PALADIN },
						races = { HUMAN },
					}),
					q(1599, {
						altQuests = { 1598 },
						qg = 460,
						coord = { 28.6, 66.1, MAP.DUN_MOROGH },
						classes = { WARLOCK },
					}),
					q(90001, {
						sourceQuests = { 10, 11, 12 },
						sourceQuestNumRequired = 1,
						qg = 100,
						coord = { 10.0, 20.0, MAP.ELWYNN_FOREST },
					}),
					q(90002, {
						-- item-started; no map coordinate
						qs = 47834,
					}),
				}),
			},
		}),
	},
});
