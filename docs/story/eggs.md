# Hidden nods and hidden achievements (the easter-egg plan, 2026-10-18)

Status: package E1 built 2026-10-18 · not yet seen by the owner. Each later package adds its own section below, so the
appends don't collide. Every nod is a wink in our own words: no outside name, quote, art or sound goes into the game,
and nothing sits in a cutscene, a main conversation or a serious scene. Hidden achievements show as "A secret" until
earned, and there is no setting to switch them off.

## E1: hidden achievements and fight counts

Code: `core/achievements.gd` (the list, `hidden_defs`, `check_story`, `note_fight`, `for_fight`, `for_story_fight`),
`story/fight_tally.gd` and `story/run_stats.gd` (the counts), `combat/object_fire.gd` (the burst counters),
`ui/screens/achievements_panel.gd` (draws what `Achievements.all()` hands it), `world/game_root.gd` (`_refresh` calls
`check_story`). Data: `data/achievements/<package>.json` (schema `data/schemas/achievements.schema.json`),
`data/flags/eggs_engine.json`. Tests: `tests/unit/test_achievements_hidden.gd`. Validator: `tools/data/validate_data.py`
(`achievement_checks`, the engine flags) and `tools/data/story_reach.py`.

### The hidden achievements

One data file per package, so the packages don't collide: `{"id": "<package>", "achievements": [{id, name, text, hidden,
when}]}`. They come after the sixteen in `Achievements.LIST` and before the endings' own. `Achievements.all()` hands a
hidden, unearned one out as `Achievements.HIDDEN_NAME` ("A secret") with `HIDDEN_TEXT` ("Hidden until it is earned."),
so the Achievements panel (and anything else that lists them) can't give one away; once earned the row shows its own
name and how it is earned, with the date. The ending's list and the toast ("Achievement: <name>") name an achievement
only once it is earned. The wiki's achievements page reads `Achievements.LIST` only, so it lists none of them.

A package earns its achievements one of two ways:

- **In code.** Add the id to `Achievements.for_fight` (any fight, Skirmish included), `for_story_fight` (a story fight,
  with the run's counts) or `for_ending`.
- **With a `when`.** A story condition (docs/contracts/dialogue.md: flags, items, quests, visited places...). The game
  calls `Achievements.check_story` from `GameRoot._refresh`, which runs whenever the party's state may have changed, and
  every hidden achievement with a `when` that now holds is earned once and toasted. `make validate` reads a `when`'s
  flags like any condition's (registered, and set somewhere).

An id is unique across every file, `Achievements.LIST` and the endings' `ending_<id>`, and so is a name
(`achievement_checks`). A capture run earns none, as ever.

### The three E1 earns

| Id | Name | Earned by |
|---|---|---|
| `a_little_push` | A Little Push | On a hero's own turn, a foe goes over the edge of a map's open drop (`FightTally`: `pushed_over`). |
| `spark_and_barrel` | Spark and Barrel | One burst barrel of lamp oil hurts two foes or more (`ObjectFire.most_foes_hit`). |
| `knocked_not_killed` | Knocked, Not Killed | Ten foes knocked out with the Knock Out rule over one playthrough (`RunStats` `knocked_out`). |

The first two are earned in any fight, Skirmish too; the third is the run's, so a story one.

### The counts

All read from the combat log once a fight is over, as the rest of `FightTally` is (a fight saved and loaded mid-way
keeps only the log's last 40 lines, as for every stat):

- `knocked_out`: "X knocks Y out (1 Hit Point...)" credits X, when Y is on the enemy side. A knocked-out foe lives, so it is
  no longer also counted as a kill by the hero whose blow came before it (the line comes before the blow's own hit line).
  `RunStats.HERO_KEYS` adds it to each hero's record and the party's totals.
- `pushed_over`: "Y goes over the edge" on the enemy side, credited to whoever's turn the last "X's turn" line says, when
  that is a hero or guest. A shove, a spell's push or a flyer's fall all count. A hero going over, or a push on a
  foe's turn, counts for no one.
- `improvised`: the attack roll of a thrown improvised weapon, its label ending "(improvised)" (a chair, a crate, a stool,
  a thing lying about). A thrown weapon from the ground is thrown as itself and doesn't count.
- `ObjectFire.bursts` and `most_foes_hit` count in the fight's `e.objects.fire`: the barrels that burst, and the most
  enemy-side creatures one burst hurt (a chain of barrels is one burst each).

### Side flags (`data/flags/eggs_engine.json`)

`Achievements.watch` calls `note_fight` when a story fight ends and it sets, in the run's story flags and never cleared:
`eggs_pushed_over_edge`, `eggs_barrel_burst` (any burst, whoever it caught) and `eggs_threw_furniture`. Later packages
read them in dialogue (the camp's banter about a thrown chair, the castle gargoyle that has heard of pushers). The
registry marks them `"set_by": "engine"`: `make validate` and the story-reach walk then count a flag set by the game, and
refuse a dialogue that tries to set one. No save version changes: flags and run stats are free-form already.

## R1: the Village of Barovia and the road in

Gemini record and the plan-versus-game notes: `docs/plans/gemini_eggs/r1/README.md`. Test:
`tests/integration/test_eggs_village.gd`. Flags: `data/flags/eggs_village.json` (`eggs_sky_man_heard`, `eggs_dog_lupu`)
and `eggs_spade_first` in `data/flags/world_checks.json`.

- **The man who fell from the sky, part 1 of 3.** The Vistani sisters at the Blood of the Vine (`vistani:strangers`, once
  they have said who they are) laugh about a man the mists dropped in a field last spring, who swore a flying ship like
  a great squid had fallen with him aboard and a worm had gone in through his eye. Mirabel says it was a stye. Parts 2
  and 3 are Van Richten's jar (R5) and a leech at camp (R6a); the hidden achievement that reads all three is R7's.
- **Lupu**, the burgomaster's hound, can be petted by day, at night (he stops howling for a breath) and once his trouble
  is over (`the_burgomasters_hound:pet`). One of the five dogs the hidden Good Dogs, All counts (R7 writes it).
- **The patient spade, hole 1 of 3.** Earth stamped flat beside the far charcoal mound in the Charcoal-Burners' Hollow
  (`hollow_stamped_earth`); with a shovel in the party, `hollow_dig` (Athletics DC 8) turns up a dead pedlar's tin, 15
  gp and his note, which points on to the lake's reedy inlet. Holes 2 and 3 are R5's, and so is Patient Spade.
## R2: Tser Pool and the Svalich road

Gemini record and notes: `docs/plans/gemini_eggs/r2/README.md`. Test: `tests/integration/test_eggs_svalich.gd`. Flags:
`data/flags/eggs_svalich.json`. Item: `rival_monster_guide`. NPC: `tser_owl`.

- **The Tser Pool dog** (`tser_camp:dog_pet`), one of the five good dogs.
- **The owlbear at Tser Pool.** The camp's children have put a barn owl on the stage rail in a bear-fur cap, under a
  chalk sign: OWLBEAR. DO NOT FEED. Animal Handling DC 12 eases the cap off (Thistle and Wren approve); with Speak with
  Animals it says what it thinks of being a bear.
- **Bujor's admirer.** A druid at the end of The Dancing Bear offers to dance the bear's part, or to visit him in the
  den in a bear's shape, and Lavinia answers.
- **Fennimore's research assistant** lives in his breast pocket and, with Speak with Animals, insists it is enormous
  where it comes from and has one piece of battle advice, about faces.
- **The other fellow's guide.** Once his own guidebook is started, Fennimore rants about a rival with one glass eye and
  gives the party the rival's best-selling monster guide, furiously annotated.
- **A borrowed name.** On a visit after the reading, Madam Eva remarks once on a hero named Tav (`hero_named:tav`).
## R3: Vallaki

Gemini record and notes: `docs/plans/gemini_eggs/r3/README.md`. Test: `tests/integration/test_eggs_vallaki.gd`. Flags:
`data/flags/eggs_vallaki.json` and `eggs_puppet_seen` in `data/flags/world_checks.json`. Item: `vanity_puppet`.

- **The puppet with no reflection.** A sharp look along Blinsky's top shelf (`top_shelf_look`, Perception DC 12) finds
  a pale puppet posed before a toy mirror that shows only the shop; Blinsky sells it from then on (one, 6 gp). Emanoil,
  shown it, pays twice over and makes up a couplet (`emanoil:puppet`).
- **The Baron's fifth decree** forbids shoving a neighbour off a roof, into the river or onto a bonfire; the festive
  clocks still come last and repeat.
- **Two good dogs**: the big dog in the square and the Vistani camp dog (`dog_pet` in each).
- **A letter under the straps** of Rictavio's sea chest (`trunk_strap_papers`, Investigation DC 14): an old druid in
  the west calls its reader "child" and tells him to stop hunting alone. It never names him.
- **The masked hero in chalk** on the back of a notice board by the square (`square_chalk_board`): the children's hero
  has lately grown horns and an eyepatch, and a lady in red holds his leash.
- **The Lady of Loss**: a black tract on the Wachterhaus book club's chairs (`black_tract`), with a teacher's note about a
  novice who forgets her own name and picks the flowers that open at night.
## R5: the lake, Van Richten's Tower, Berez and Mount Baratok

Gemini record and the plan-versus-game notes: `docs/plans/gemini_eggs/r5/README.md`. Test:
`tests/integration/test_eggs_east.gd`. Flags: `data/flags/eggs_east.json` (`eggs_orb_fed`, `eggs_orb_asked`) and
`eggs_spade_second`, `eggs_spade_third`, `eggs_orb_found`, `eggs_jar_seen` in `data/flags/world_checks.json`. Item:
`pedlars_spade_head`.

- **The patient spade, holes 2 and 3.** The hummock ringed with stones at the reedy inlet (`inlet_hummock`, `inlet_dig`,
  Athletics DC 10) holds the pedlar's second tin: 40 gp, a Potion of Greater Healing and a note that points on to where
  the old road drowns in the marsh. The tilted slab on the Berez marsh track (`marsh_spade_slab`, `marsh_dig`, DC 12)
  holds the last: 60 gp, his spade-head (gear, 25 gp) and his farewell. Both need a shovel in the party. Patient Spade
  (hidden, once all three holes are dug) is R7's: hole 1 is R1's flag, and a package may not name a flag that hasn't landed.
- **The jar marked DO NOT, part 2 of 3.** Van Richten's label (`jar_do_not`, Arcana DC 13, on the tower's jars): a small
  grey thing with feelers, taken from the eye of a sailor who swore a ship like a squid fell out of the sky. It turns to
  face whoever looks. Sets `eggs_jar_seen`; the achievement that reads all three parts is R7's.
- **The hungry orb.** Lifting the furs on the Mad Mage's bed (`lift_furs`, Investigation DC 15) finds a cracked glass orb
  in a chalked rag (`eggs_orb_found`); it shows by the bed from then on (`baratok_orb`, `hungry_orb:orb`). Fed a
  first-level spell scroll it purrs, the party gains Heroic Inspiration and the hearth that never had a fire lights
  (`eggs_orb_fed`). It eats once.
- **A saucer on the sill**: a variant among the cold hearth's own lines (`examine:baratok_cold_hearth`); once the orb is
  fed the hearth burns and the Narrator says so.
- **The meddler with the pipe**: the restored Mordenkainen, asked whose the orb is (`mordenkainen:orb_owner`, once it is
  found), says it was a young wizard's and that his teacher left it by the fire uninvited.
- **Engine touch.** `item:spell_scroll_level_1` and `take spell_scroll_level_1` mean any Spell Scroll of that level
  (`StoryState.is_scroll_of`): scrolls are always carried as a particular spell, so the generic id never matched.

## R6a: companions at camp, on the road and in dreams

Gemini record and the plan-versus-game notes: `docs/plans/gemini_eggs/r6a/README.md`. Test:
`tests/integration/test_eggs_camp.gd`. Flags: `data/flags/eggs_camp.json` (`eggs_song_1` to `eggs_song_3`, strings
holding `hope`, `grim` or `silly`; `eggs_song_sung`; `eggs_eye_checked`; `eggs_quillon_rivals`). Achievement:
`data/achievements/r6a.json` (Encore).

- **Thistle and the bear** (`camp/thistle:talk_bujor`, once The Dancing Bear is done): she has been thinking about
  Bujor more than is usual and asks the party not to tell. Two of the three answers earn her approval +1.
- **Wren's unfinished song** (`camp/wren:talk_song`, any camp once the party has been to Vallaki): three lines picked
  from hopeful, grim or silly each, sung at the fire. Approval wren +2, Heroic Inspiration for the party, Encore. The
  next night at the Blue Water Inn (`rest:long:vallaki_blue_water_inn` in `nights.dialogue`, a `[once]` variant) the
  room joins in on the last line. The lyrics are ours.
- **Quillon's colleague in red** (`camp/kip:quillon_rivals`, one more question at his first call): a rival who sings his
  contracts.
- **Something behind the eye** (`camp/ratatoille:talk_eye`, or `silvain:talk_eye` when Ratatouille isn't along, after
  the reedy inlet or the marsh track): Medicine DC 10 finds a marsh leech under the lid. Sets `eggs_eye_checked`, part
  three of the sky-man's three; Ratatouille's comfort answer earns approval +1.
- **Two banters** in `banter/party_six.dialogue`: Ilse and Wren, and Godrick and Liriel, about a thrown chair (once
  `eggs_threw_furniture`), and Godrick telling Thistle of a horned woman whose heart ran too hot.
- **The visitor with a borrowed face**: a `[once]` variant of `dream:amber_temple` once a dark gift is taken. No joke.

## R6b: camp nights and the party

Gemini record and the plan-versus-game notes: `docs/plans/gemini_eggs/r6b/README.md`. Test:
`tests/integration/test_eggs_camp_nights.gd`. Flags: `data/flags/eggs_camp_nights.json` (`eggs_ilse_compliment`,
`eggs_party_held`).

- **Worth killing later** (`camp/ilse:talk_warrior`, from level 4): Ilse pays the party the highest compliment she
  knows, borrowed from a dragon-riding warrior she once served beside who sorted everyone into prey and worth killing
  later. A laugh; there is no approval for Ilse (a hero, not one of the six).
- **A cask for the camp** (`camp/godrick:talk_party`, once `winery_wine_flows`): the Martikovs' thanks arrive as a
  cask and Godrick calls a party. Every hero and companion at the fire gives a toast, the six companions earn approval
  +1 and the party Heroic Inspiration; it ends with someone asleep against Godrick. It starts no romance.
- **Checking for a pulse** (`camp:night` in `narrator/camp.dialogue`, a `[once and level >= 4]` variant): you wake in
  the small hours to find one of your company very close over another sleeper's throat, swearing they were checking
  for a fever. It names no one.

