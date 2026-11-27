## 1.1.12 - 2026-11-26

- Keep tracked professions in a separate section below the quest list in the standalone tracker. When the quest module is collapsed, the professions section sits just below the quest header. Short quest lists now size to their content, so the professions section moves up and the list does not scroll when everything fits.
- Run the professions module's layout writes through a secure delegate and add the module to the `/fqp taint` scan. This keeps a combat map open from seeing ForeverQuestPins as the taint source.
