## 0.1.37 - 2026-09-25

- Ship quest-start pins from the Wowhead Forever scrape instead of All The Things.
- 3898 quests with 4701 coordinate pins across 47 maps, including Zephras Isle.
- Purple pins for PvP quests. Holiday quests stay hidden unless seasonal pins are on.
- Hide a quest pin when that quest is already in the quest log, even if `C_QuestLog.IsOnQuest` returns false.
- Show a yellow `?` on the turn-in NPC once that quest is ready to hand in. An unfinished quest stays off the tooltip.
