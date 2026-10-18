# Ally visits

One file per character, `data/visits/<npc id>.json` (schema `data/schemas/ally_visits.schema.json`): the letters and road
meetings a friend of the party brings, in the same shape as Strahd's visits (`data/strahd/visits.json`). The game loads
every file here after Strahd's own visits and marks each visit an ally visit. How they differ from his, and the rules
`make validate` holds them to: docs/regions/strahd_presence.md, "Ally visits".
