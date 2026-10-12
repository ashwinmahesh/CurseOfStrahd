# Animals and the dead who talk (lane 2)

Ashwin (2026-10-11): more animals and dead to talk to with Speak with Animals and Speak with Dead. Each one is true to
Curse of Strahd and this game's own story, stands where it makes sense, and knows something worth the casting: a hint
(a quest's journal stage, a way past someone's lie) or where something is hidden (a Tip, docs/story/found_magic_items.md).
Built in batches; this page lists what's built.

## How it works

- **The conversation casts the spell.** An option tagged `[knows:speak_with_animals]` runs `cast speak_with_animals`
  (a Ritual: ten more minutes, no slot); `[knows:speak_with_dead]` runs `cast speak_with_dead` (a 3rd-level slot or
  higher). A casting from the character sheet that's still running needs none: an `[if spell:<id>]` option asks
  straight away. No slot left: a notice says so and the menu comes back (docs/contracts/dialogue.md, `cast`).
- **A told find shows itself.** `reveal <search prop>` marks a hidden find as found, as if the party had searched it
  out; it's on the map once the conversation ends.
- **Who can be spoken with.** Speak with Animals: Beasts (not a wereraven or werewolf in animal form, and not Stella
  Wachter, whatever she thinks). Speak with Dead (2024 PHB): a corpse with a mouth that wasn't Undead when it died,
  once (a flag per corpse); it knows only what it knew alive.
- **Without the spell** an animal is only an animal: the new options don't show, and a conversation that used to be a
  single line stays one.

## Batch 1: the animals of the western valley (branch `more-to-speak-with`)

| Who | Where | What they know | What it does |
|---|---|---|---|
| The master's wolves | Old Svalich Road, the narrows | Their master sent them to look, not eat; an old man sits in the fog | The wolves let the party by (`mists_wolves_cowed`); Thistle approves |
| A crow on a barrel | Old Svalich Road, the village edge | The children in the road have no smell; a pack under the torn deer | `mists_crow_told` opens a way to see through Rose and Thorn; reveals `carcass_pack` (Boots of the Winterlands) |
| Lupu | Village of Barovia, by the mansion | His boy Sergiu is in the study wall | `sergiu_known`, `lupu_friend`; The Burgomaster's Hound to `asked` |
| A goat | Village of Barovia, by the fallen barn | A stick that tastes of storms under the beams; the church screams at night | Reveals `barn_beams_stash` (Javelin of Lightning) |
| The flock | The High Pasture | One goat too many, out of the fog, and something wet coming after her | The Goatherd's Count to `asked` |
| Snowdrop | The High Pasture, from Erno's menu | Fifty years waiting for the man in grey boots, who is still in the fog | Points at Ilarion (The Last Traveller); the wolves come |
| The camp dog | Tser Pool | Nicu rode east and didn't come back; a smoking flask in the stump | The Hanged Vistana to `asked`; reveals `tser_stump_flask` (Potion of Fire Breath) |
| Bujor | The old den up the deer path | Whose iron holds the cub | `bear_trap_marked` (Old Marin) |
| Steaua | The crossroads milestone | The carriage's bargain; something hidden behind her stone | Calms her (`mare_calmed`); reveals `milestone_hollow` (Wand of Web) |
| A raven on a fencepost | The River Ivlis crossroads | The Keepers of the Feather want hands; a man buried his boots in the newest mound | The Wizard of Wines to `rumored`; reveals `newer_mound` (Boots of Elvenkind) |

The One-Horned Billy (Krezk) and Elvir's bones (Yester Hill) were there before; both now cast in the scene too.
Tests: tests/integration/test_speak_with_animals.gd.

## Still to build

- The animals of Vallaki, the Wizard of Wines, Old Bonegrinder, Krezk and Castle Ravenloft's roost.
- The dead around the village of Barovia, Death House, the crossroads gallows, Vallaki and Old Bonegrinder.
- The dead of Krezk, Berez, Argynvostholt, Yester Hill's barrows and Castle Ravenloft's catacombs.
