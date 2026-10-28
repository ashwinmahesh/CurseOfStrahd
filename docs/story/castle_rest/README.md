# Long Rests in Castle Ravenloft

Held ask (2026-10-24): allow Long Rests inside the castle once the current floor is cleared of enemies, with a chance of
vampires interrupting it, a night line and a dream for each new place to sleep, a castle-wide rule rather than a per-room one,
and no change to saves or settings. The lane picked the first of the two options it was given (a rest, rather than a sanctuary
or shrine) because the camp, the night's visitors and the night lines already exist and only the castle's gate was missing.

- **Floors.** Every walled map of the castle has a `floor` (data/locations/castle_ravenloft_*.json): `ground` (main floor, chapel,
  King's Balcony), `court` (the count's floor), `tower` (the High Tower, the tower rooms, the roost, the roofs, the heart),
  `larders` (the larders, the dungeon, the brazier room) and `catacombs` (the catacombs, Old Tombs, Lesser Vaults, Strahd's
  crypt). `RestRules.rest_maps` keeps only the maps of the party's floor, so `waiting_fights` (and the refusal, "Enemies still
  prowl this floor.") counts only that floor's enemies. A building whose maps have no `floor` (Death House) is as before. The
  places that allow no sleep (`rest: no`) still allow none.
- **Interruption.** A night in a risky castle place is broken on a 1 or a 2 on the d6 (`interrupt_on` in
  data/camp/night_visitors.json; elsewhere 1). The camp's night visitors then come for it: the castle's own groups (bats and a
  zombie at levels 1-3, bats and the dead at 4-6, three vampire spawn and bats from 7) in the halls and on the roofs too
  (`region_settings`), where any other house gets rats, shadows and wraiths. Strahd's own visit at night is as before.
- **Words.** A night line for each of the eight places that had only the castle's (`rest:long:<place>`: the Old Tombs, the
  Lesser Vaults, the King's Balcony, the West Wing, the Larders, the High Tower, the tower rooms, the Ravens' Roost), four more
  castle dreams in nights.dialogue, and the three castle visitor texts rewritten to read under a vault as well as in the open.
  Drafted by Gemini through the ai-bridge: `gemini_brief.md` is the brief and `gemini_reply.json` the raw reply. Edits to the
  draft: the Old Tombs line placed the sleepers "between the old king and his finer son", a layout the map doesn't give (the
  king's vault and the white tomb are separate), so it now says within reach of the king's vault and his younger son's white
  tomb; the balcony's "velvet on the two tall thrones" became "the seats of the two tall thrones" (the map names no velvet). The
  rest is as drafted.
