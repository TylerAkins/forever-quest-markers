---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------

maproot(MAP.ZEPHRAS_ISLE, {
	timeline = { TIMELINE.ADDED_1_60_1 },
	["races"] = { SKYBORNE_ALLIANCE, SKYBORNE_HORDE },
	["groups"] = {
		n(QUESTS, {
			q(92460, {
				["qg"] = 251362,
				["coord"] = { 42.8, 23.4, MAP.ZEPHRAS_ISLE },
			}),
			q(92461, {
				["qg"] = 251361,
				["coords"] = { 42.1, 23.5, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92460 },
			}),
			q(92462, {
				["qg"] = 251368,
				["coords"] = { 43.4, 24.8, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92460 },
			}),
		}),
	},
});
