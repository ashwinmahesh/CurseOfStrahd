# Animals, the dead and plants who talk (lane 2)

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

## Batch 2: the animals east of the crossroads (branch `more-to-speak-with-2`)

| Who | Where | What they know | What it does |
|---|---|---|---|
| The big dog | Vallaki, the square | Milivoj carried a sack of old bones to the coffin maker's back door; the cold dead in Henrik's back room; a ring by the stocks | `vallaki_dog_told` (a way to make Milivoj confess); The Bones of St. Andral to `rumored`; reveals `stocks_mud` (Ring of Protection) |
| The camp dog | The Vistani camp by the lake | Luvash's grief, then Bluto carrying Arabelle north in a sack | The Missing Girl to `rumored`, or from `asked` to `clue` |
| Arrigal's black horse | The Vistani camp | He rides to the castle at night; a snake-smelling knife under his wagon | `arrigal_suspected`; reveals `arrigal_wagon_drawer` (Dagger of Venom) |
| A bay in the inn's stable | The Blue Water Inn | The striped beast in Rictavio's wagon, and the old man's voice he uses with it | `rictavio_suspected` |
| Stella Wachter | Wachterhaus | The spell finds no cat in the room to answer | Seen through, as Insight would (`stella_bound_known`, The Cat in the Window to `bound`) |
| The ravens | The Wizard of Wines | Where the druids came from, where Davian hid his last stone, where the thief took the other; their own hoard | `yester_hill_known`, `winery_stone_hiding_told`, The Third Stone to `told`; reveals `roost_hoard` (Ring of Feather Falling) |
| The ravens in the dead oak | Old Bonegrinder's crag | Children go into the mill and don't come out; Ilinca is one of them | The Children in the Mill to `heard`; reveals `oak_raven_hoard` (Figurine of Wondrous Power, Silver Raven) |
| The goats | Krezk, the pens | The billy talks in his sleep; Petru smells of wolf; a warm ring under the track cairn | The One-Horned Billy and The Pack's Runt to `rumored`; reveals `track_cairn_ring` (Ring of Warmth) |
| The roost | Castle Ravenloft, under the roofs | They hate the count's bats; Pidlwick II's key; a ring in the far nest | Calms them, even after a raven was hurt (`roost_ravens_calm`); reveals `nest_ring` (Ring of Evasion); Thistle approves |

Tests: tests/integration/test_speak_with_animals_east.gd.

## Batch 3: the dead around Barovia and Vallaki (branch `more-to-speak-with-3`)

Speak with Dead is a 3rd-level spell, so a party first casts it around Vallaki: these are the dead a party of level 5
or more can still reach, around the village (on the way back), the roads and the places past Vallaki.

| Who | Where | What they know | What it does |
|---|---|---|---|
| Kolyan Indirovich | His coffin in the mansion, or his grave in the churchyard (not once he's raised) | Where he found Ireena: the lake road past Vallaki, the winter the wolves were bad, with a boy shouting a name in the trees; his wife's brooch behind the study desk | With Izek's story heard, `izek_sister_truth` (Izek's Obsession to `truth_guessed`); otherwise `ireena_finding_known`, and Izek's story finishes it; reveals `study_panel` (Brooch of Shielding) |
| Nicu | The crossroads gallows, or his grave by the road (not once he has walked: he died Undead) | The mare's owner and his sons hanged him; a farmer hid a sack behind the field wall while they argued over the knot; a message for his sister | Reveals `field_wall_cache` (Gauntlets of Ogre Power); `nicu_spoke` lets the party give Luminita his last words |
| Brother Kesten | Old Bonegrinder, his skull by the bone heap once his holy symbol is found | The children in the loft; the three words that send Offalia off; Bella wants the soul bags, not the mill | A sure way to lure Offalia from the oven (no Deception roll) |
| Mircea, Grigor's brother | The bone midden below the werewolf den | The pack wanted him bitten; Emil, in silver chains, told him to say no; where his boots came off | Reveals `mud_boots` (Boots of Speed) |
| Tudor the shepherd | The reeds at the Lake Zarovich landing | Old Greytooth killed him while a man in a wolfskin coat watched from the rise, a man he'd seen take a purse from Arrigal | A second way to confront Szoldar, without Yevgeni (The Hunters at the Inn) |

Left out on purpose: the dead in Death House's dungeon (a party there is level 1 to 3, long before the spell) and the
three small graves in St. Andral's churchyard (Ana and her friends are vampire spawn, not corpses; Black Roses).
Tests: tests/integration/test_speak_with_dead.gd.

## Batch 4: the dead of the high places (branch `more-to-speak-with-4`)

| Who | Where | What they know | What it does |
|---|---|---|---|
| Marina | Berez, her bier in the vault under the monument | A thorn in her heart at her window, and the old woman from the hut singing on the marsh | `marina_truth_known`, The Witch of Berez to `truth` (as the Arcana deduction does) |
| The last sister | The Abbey of St. Markovia, the nuns' graves in the garden | The Abbot came down with wings in a fever year and began to mend what wasn't broken; the holy water at her feet | `abbot_nature_known` (as the Religion check does); reveals `grave_holy_water` |
| The first Pidlwick | Castle Ravenloft's catacombs, the jester's crypt | His clockwork copy pushed him down the stair; a false bottom under him | `pidlwick_crypt_told` (a way to confront Pidlwick II); reveals `jester_cape` (Cape of the Mountebank) |
| A prisoner in shackles | Castle Ravenloft's larders, the dungeon | The guards' talk of the glass heart in the high tower; the open cell's straw is a lid | The Heart of Sorrow to `heard`; reveals the trap `larders_open_cell_pit` |
| Sergei von Zarovich | Castle Ravenloft's catacombs, his tomb | Tatyana chose the wedding flowers; if she came looking for him she'd go to the pool at Krezk | The Pool of the White Sun to `rumored` (a new first stage) |
| A frozen traveller | The Amber Temple, inside the doors | Came for a gift, sat down for a moment; the sword in their hand | Reveals `frozen_hand_sword` (Frost Brand) |

`reveal` now takes a trap's id too: the trap shows as found, as a warning would show it (docs/contracts/dialogue.md).
Left out on purpose: Argynvost's skull (bringing it home isn't built yet), the squires' graves (they died before Ioan
rode out, so they can't clear him), the Krezkovs' children, and the undead (the brides, Beucephalus, Silverjaw's
watch). Tests: tests/integration/test_speak_with_dead_high.gd.

## Speak with Plants (branch `speak-with-plants`)

Plants answer for the last day only (2024 PHB: "events in the spell's area within the past day"), so each one tells
what passed it last night. The conversation casts the spell with a 3rd-level slot (it isn't a Ritual).

| Who | Where | What they know | What it does |
|---|---|---|---|
| The wolfsbane | The werewolf den's door, planted in rows | Zuleika cut some at moonset to dry in the caves, and hid a flask in the bundles | Reveals `herb_elixir` (Elixir of Health) |
| The last green row | The Wizard of Wines' vineyard | While the druids hold it: the blights and a singing druid came from the hill with the black tree, and the druid dropped his sickle to the ravens; once it's won back, only the family's lamps | `yester_hill_known`; reveals `vine_sickle` (+1 Moon Sickle) |
| The hags' garden | Old Bonegrinder's hill, while Bella is there | Offalia picked a basket for the baking; Bella flew home on a broom and hid it in the rafters | Reveals `rafters_broom` (Broom of Flying) |

Tests: tests/integration/test_speak_with_plants.gd.
