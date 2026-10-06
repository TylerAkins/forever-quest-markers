## Unreleased

- Item-started quests use a loot-bag pin with a small `!`; object-started quests use a scroll pin with a small `!`.
- Pin style priority is dungeon/raid, class, profession, item, object, repeatable, then normal; mixed stacks stay yellow.

## 0.2.0 - 2026-10-06

- Class-restricted quest starts use your class color; profession starts use copper.
- Rogue class pins add a dark bang shadow so yellow does not blend into normal starts.
- Dungeon/raid pins still win over class and profession when a stack is instance-only.
- Start pins hide right away after accept or turn-in, without needing `/reload`.
- Lower memory churn on map open/pan by keeping quest and NPC indexes across layout refreshes.
