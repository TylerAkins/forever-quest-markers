# Attribution

## All The Things

Quest coordinates, quest-giver IDs, source quests, and eligibility fields in `Database/` are converted from the [All The Things](https://github.com/ATTWoWAddon/AllTheThings) Forever database.

- Upstream: https://github.com/ATTWoWAddon/AllTheThings
- License: MIT
- This repository does **not** bundle the ATT addon
- This repository does **not** claim ownership of ATT data
- Runtime ATT is not required

The MIT license requires that ATT’s copyright notice be preserved for derived portions. The ATT MIT notice is reproduced below.

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

Generated Lua files also record the exact ATT commit SHA used for that conversion.

## Original addon code

Tracker-style UI, Questie integration, and HereBeDragons usage from other addons were **not** copied. Forever Quest Pins is a small native-map overlay with its own ATT converter.

Map pins use Blizzard’s `QuestNormal` atlas, then `Media/QuestAvailable.tga` if `SetAtlas` errors.

## License

Addon source is **GPLv3** ([LICENSE](LICENSE)). ATT-derived data remains MIT-licensed as described above.
