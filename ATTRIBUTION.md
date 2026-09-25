# Attribution

## Wowhead Forever

The shipped files in `Database/` are generated from the Wowhead Forever quest pages stored in `data/forever-quests/`. Wowhead is not bundled and is not required at runtime. Quest names, coordinates, and NPC ids on those pages belong to their sources; this repository stores a converted pin database so the addon can draw them.

## All The Things

`tools/build_quest_db.py` can still convert the [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever database. That path is not what the addon loads. When it is used, quest coordinates, quest-giver IDs, source quests, and eligibility fields are **converted** from All The Things:

- Upstream: https://github.com/ATTWoWAddon/AllTheThings
- License: MIT
- This repository does not bundle the ATT addon and does not require it at runtime
- This repository does not claim ownership of ATT data
- Running that converter records the ATT commit SHA in the files it writes

The MIT license requires that ATT’s copyright notice be preserved for derived portions:

```
MIT License

Copyright (c) 2026 AllTheThings WoW Addon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Addon code

Forever Quest Pins is original GPLv3 code: a native-map overlay and its own ATT converter. Tracker UI, Questie integration, and HereBeDragons usage from other addons were not copied.

Map pins use Blizzard’s `QuestNormal` atlas. The generated yellow, blue, and red-orange textures under `Media/` are original fallback art used only when the preferred atlas rendering fails.

## License

- Addon source: **GPLv3** ([LICENSE](LICENSE))
- ATT-derived `Database/` records: **MIT**, as above
