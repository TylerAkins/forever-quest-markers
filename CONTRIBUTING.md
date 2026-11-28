# Contributing

## Supported languages

Every player-facing string must be available in all supported client locales. Do not merge a feature, setting, command, dialog, tooltip, chat message, or error message with English-only text.

| Locale | Language | Flag |
| --- | --- | --- |
| `enUS` | English (source) | 🇺🇸 |
| `esES` | Spanish (Spain) | 🇪🇸 |
| `esMX` | Spanish (Latin America) | 🇲🇽 |
| `deDE` | German | 🇩🇪 |
| `frFR` | French | 🇫🇷 |
| `ptBR` | Brazilian Portuguese | 🇧🇷 |
| `zhCN` | Simplified Chinese | 🇨🇳 |
| `zhTW` | Traditional Chinese | 🇹🇼 |
| `koKR` | Korean | 🇰🇷 |
| `itIT` | Italian | 🇮🇹 |
| `ruRU` | Russian | 🇷🇺 |

The `esMX` client reuses the `esES` table and applies Latin American dungeon terms at load time. Add a new string to the `esES` table, then check that it reads correctly with `calabozo` instead of `mazmorra`.

## Localization rules

- Put player-facing text behind a literal `ns.L["English text"]` key.
- Add the same English key to every locale table in `Localization.lua`. The `enUS` source text is the key, so English needs no separate table entry.
- Keep format placeholders in the same order and spelling: `%s`, `%d`, `%%`.
- Keep `/fqp` command names unchanged. Translate only the description after the command.
- Keep color codes such as `|cffffd100` and `|r` unchanged.
- Keep product and service names unchanged: `Quest Finder`, `Blizzard`, `Wowhead`, `Questie`, `TomTom`, `PvP`, `AQ`, and `BETA`.
- Use the official World of Warcraft term for game concepts such as `Loremaster`, dungeons, raids, professions, and quests in each locale.
- Do not use dynamic keys such as `L[someVariable]`. The coverage test only sees literal keys.
- Debug-only diagnostics may stay in English, but anything a player can see during normal use must be localized.

## Before opening a pull request

1. Run `go test ./...`. The localization coverage test fails when a Lua file shipped by the TOC uses a key that is missing from any supported locale.
2. Check that placeholders and `/fqp` command names survived translation. The runtime tests check both.
3. Run `go vet ./...`.
4. Have a native speaker review new translations when possible. Mechanical checks do not catch awkward wording or wrong game terminology.

The implementation details for the translation tables and tests are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md#localization).
