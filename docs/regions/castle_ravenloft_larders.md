# Castle Ravenloft, part `larders`: the Larders of Ill Omen and the dungeon (Phase 6)

Plan §10 Phase 6; ADR 0014 (castle, Strahd, endings); ADR 0011 (treasure spots). Overview and seams:
docs/regions/castle_ravenloft.md. Task: docs/tasks/P6-07.md. Book areas are named (roughly K61 to K83) only so the
part can be checked against *Curse of Strahd* chapter 4; every line, description and name in the data and dialogue
is our own. The data and dialogue files in §15 are the source of truth for exact text.

## 1. What this part is for

Below the castle's main floor the servants once kept house: a kitchen, a hall for the staff to eat in, a wine cellar,
the guards' rooms. One servant is left. **Cyrus Belview**, a mongrelfolk cook the Abbot of Krezk gave the castle long
ago, still keeps the fire lit and the soup on, and he cooks for the "guests" in the cells below.

Further down is the dungeon: cells, a torture chamber, a workroom where the bones of the castle's old enemies are
made into chairs, and the **hall of bones**, where the lord of the house sits at a table built of them when he wants
company. A green furnace that never needs fuel feeds the dungeon's lamps; an iron lift on a chain drops from the
larders to the cells.

The part asks the party: **what do you owe the people you find down here?** A frightened lamplighter, a priest's
son who was already a monster when you met him, a holy man who isn't, and a cook who loves his master and also
slips a crying girl extra bread. Each can be helped, used, left or ended, and each choice is remembered.

Tone: a kitchen comedy that keeps tipping into horror. Cyrus is funny until you look in the pot.

## 2. Who is here and what each wants

| Who | Id (stat block) | Wants | Fears | Secret | Voice |
|---|---|---|---|---|---|
| Cyrus Belview, the cook | `cyrus_belview` (`mongrelfolk`, named in fights) | the Master pleased, the soup praised, news of his family at the abbey | the Master's silence; an empty larder | he laid the bricks over the wine merchant; he feeds the girl extra so she won't be "ripe" yet | cheerful, sing-song, servile; talks to his pots; sometimes calls himself "Cyrus"; kitchen words for everything |
| Nadia Boteanu, a prisoner | `nadia_boteanu` (`commoner`) | out; her lamps; her mother in Vallaki | being taken back to the table | she has counted the chairs in the hall of bones | quick, frightened, dry; a lamplighter's practical eye |
| Doru, a prisoner (only if the party let him out of the undercroft) | `doru` (exists, `vampire_spawn`) | an end, or blood; his father | the hunger winning | Strahd chained him for coming home with nothing | docs/voice/doru.md |
| "Brother Anatol", a prisoner who isn't | `brother_anatol` (`vampire_spawn`, named in fights) | to be rescued, so the rescuers walk him to his master's table | being found out too soon | a vampire spawn; the shackle was never locked | gentle, pious, a shade too smooth; turns cold and amused when unmasked |
| The dead watch | (`wight`, `helmed_horror`, `strahd_zombie`) | to keep a watch nobody relieved | | | (no lines) |
| The jailers | (`helmed_horror`) | to keep the keys | | | (no lines) |
| The Questioner | (`wight`, named) | answers | | | (no lines) |
| The furnace's keepers | (`flameskull`, `fire_elemental`) | the green fire fed | | | (no lines) |
| Strahd (final battle, the `donjon` card) | `strahd_von_zarovich` | his guests seated | | | the presence package's voice |

Voice bibles: docs/voice/{cyrus_belview, nadia_boteanu, brother_anatol}.md (Doru's exists).

## 3. Maps, areas and seams

Two maps, both `dungeon`, dark. Area, prop, container, door, trap and encounter ids carry the prefix `larders_`
because Narrator keys (`enter:`, `examine:`, `open:`) are global.

### `castle_ravenloft_larders`: the Larders of Ill Omen (40 x 24), the entry map

| Area | Book (roughly) | What's there |
|---|---|---|
| `larders_servants_stair` | | foot of the servants' stair from the main floor (spawn `from_gates`, exit up); Nadia's shawl if she ran |
| `larders_servants_hall` | K62 | a long table laid for a staff three centuries gone |
| `larders_kitchen` | K65 | Cyrus at the oven (approach 5), the stove, the cauldron, the dumbwaiter up to the dining hall |
| `larders_pantry` | K61 area | the larder: hanging meat that isn't all mutton, sacks, jars |
| `larders_cooks_room` | K66 (the butler's rooms) | Cyrus's straw bed and his box of treasures |
| `larders_guards_run` | K64, K68 | the long passage that ties the floor together |
| `larders_wine_cellar` | K63 | rows of casks and racks; at the very back, one rack bricked over (the Tarokka place) |
| `larders_guardroom` | K69 | the dead watch, still on duty (fight `larders_guardroom`) |
| `larders_winch_room` | the elevator | the lift winch and the cage, down to the cells |
| `larders_jailers_stair` | | the stair down to the dungeon, and the long stair on down to the crypts |

### `castle_ravenloft_larders_dungeon`: the dungeon (40 x 27)

| Area | Book (roughly) | What's there |
|---|---|---|
| `larders_dungeon_stair` | | foot of the jailers' stair (spawn `from_larders`) |
| `larders_dungeon_hall` | K73 | a vaulted hall of pillars; the guest list chalked on slate |
| `larders_jailers_post` | K74 area | three helmed horrors and the key board (fight `larders_jailers`) |
| `larders_furnace_room` | K78, K79 (the brazier rooms, reworked) | the green furnace, its gears and chains, the sluice wheel; flameskulls and a bound fire (fight `larders_furnace`) |
| `larders_stokers_crawl` | | a hidden crawl between the furnace and the hall of bones (two secret doors, DC 15) |
| `larders_cell_stair` | | the passage down from the hall to the cells |
| `larders_north_cells` | K74 | Nadia (N1), Doru if he came home (N2), a tallying skeleton (N3), the open cell with the pit (N4) |
| `larders_cell_passage` | | the passage between the rows ("past the cells") |
| `larders_south_cells` | K75 | Brother Anatol (S1), two empty cells, a loose stone (S3) |
| `larders_lift_foot` | the elevator | the bottom of the lift shaft (spawn `from_lift`) |
| `larders_torture_chamber` | K76 | the rack, the stocks, the drain; the Questioner (fight `larders_questioner`) |
| `larders_bonewright` | | a workroom where bones become furniture; a half-made chair |
| `larders_hall_of_bones` | K67 (moved below, as the cards' verses put it) | the table and throne of bones, the green lamp (trap), the Tarokka place and the `donjon` enemy room |

### Seams (both sides written; overview table)

| Seam | In my map | Goes to |
|---|---|---|
| gates ↔ larders | `castle_ravenloft_larders` exit `larders_stair_up` at (2, 1), spawn `from_gates` (2, 3) | `castle_ravenloft_main_floor:from_larders` |
| larders ↔ catacombs | `castle_ravenloft_larders` exit `larders_long_stair` at (37, 22), spawn `from_catacombs` (37, 20) | `castle_ravenloft_catacombs:from_larders` |

The long stair is "the dungeon's way down": the jailers' stair runs on past the dungeon to the crypts, so a party
can reach the catacombs without walking the cells. Internal joins: the jailers' stair (`larders_stair_down` (33, 22)
→ dungeon `from_larders`; `larders_dungeon_up` (2, 1) → larders `from_dungeon`) and the lift (`larders_lift_down`
(28, 16) → dungeon `from_lift`, only when `larders_lift_ready`; `larders_lift_up` (24, 8) → larders `from_lift`).

## 4. The flow (all optional; the two Tarokka places are the critical path)

1. **The kitchen.** Cyrus greets the party as guests (`larders_cyrus_met`; quest `the_cooks_guests heard`). He
   talks about the guests below, the wine man he bricked up (`larders_niche_told`), the Master's table and its green
   lamp (`larders_lamp_told`), and his family at the abbey (`larders_cyrus_family_news`). Asked to help a prisoner,
   he can be moved by family news, paid (30 gp; 80 after a failed Persuasion), persuaded or frightened; a failed
   Intimidation makes him scream for the watch (`larders_watch_alarm` in the kitchen, he turns hostile).
2. **The wine cellar.** The bricked rack at the back (prop dialogue `larders_cellar:niche`): pull the bricks down;
   a wine merchant sits among his bottles with his ledger in his lap, and whatever the cards hid with him.
3. **The guardroom.** The dead watch (`larders_guardroom`), or they come to the kitchen if Cyrus raised the alarm.
4. **Down.** The jailers' stair (or the lift, once the winch's brake is set) to the dungeon hall.
5. **The cells.** Open the gates (barred from outside, not locked) and talk. Nadia (quest `found`): what she saw at
   the table (`larders_hall_told`), the chain (the jailers' keys, Sleight of Hand 13, Athletics 15), and the way
   out. Doru: rest, freedom (he can't help himself: `larders_doru_hunger`) or left. Brother Anatol: see through him
   (his breath, the bread, the cook's word, Father Lucian, Insight 15, Religion 12, a raised holy symbol) or free
   him and be ambushed (`larders_false_brother`, the party surprised).
6. **The jailers' post and the furnace.** Keys (`larders_keys_taken`); the furnace keepers (`larders_furnace`);
   the sluice wheel drowns the green fire (`larders_furnace_quenched`), which puts out the lamp over the table of
   bones (its trap no longer fires) and darkens the dungeon's lamps.
7. **The torture chamber and the bonewright's room.** The Questioner and what lives in the drain
   (`larders_questioner`). A back door to the hall of bones.
8. **The hall of bones.** The table, the throne, the lamp. The drawer of the table holds the cards' treasure when
   the reading puts one here. If the reading's enemy card is `donjon` (or `mists` picks this room), Strahd waits at
   the head of the table and the final battle starts on entering.

## 5. Choices and their consequences

| Choice | Where | Options | Immediate | Later |
|---|---|---|---|---|
| Nadia's way out | her cell | Cyrus's scrap barrel (`escaped`), run up the stair alone (`sent_alone`), hide in the cell (`waits`), leave her chained | `larders_nadia_fate`; quest `escaped` / `hidden` | `sent_alone`: her shawl folded on the bottom step next time (quest `caught`, failure); `waits` can still go out with Cyrus; epilogue |
| Cyrus | kitchen | befriend (family, gold, words), frighten, provoke, kill | `larders_cyrus_helps`, `larders_cyrus_wary` (price rises), `larders_cyrus_hostile` (alarm fight), `larders_cyrus_slain` | no barrel for Nadia if he's hostile or dead; epilogue |
| Doru | his cell | end him at his asking, free him, leave him | `larders_doru_fate` (`rest`, `freed`, `left`); `larders_doru_hunger` on freeing | Donavich's epilogue |
| Brother Anatol | his cell | unmask him (many ways), free him | `larders_anatol_fate` (`unmasked`, `freed`); ambush with the party surprised if freed | a vampire spawn fewer, or one left waiting in a cell |
| The green fire | furnace room | quench it or not | `larders_furnace_quenched` | the bone lamp's trap is gone; the hall of bones is dark (a Narrator variant) |
| The bricked rack | wine cellar | open it or not | treasure, 35 gp, the merchant's ledger | |

No menu depends on one spent check: Cyrus's help has four routes besides the rolls; Anatol has seven tells besides
Insight; Nadia's chain has keys, a pick, a pull, or later.

## 6. Encounters (2024 DMG, party of four at level 10 with a guest)

Level 10 budgets for four: Low 6,400 / Moderate 9,200 / High 12,400 (a guest adds a fifth). XP from data/monsters:
helmed horror 1,100, wight 700, Strahd zombie 200, flameskull 1,100, fire elemental 1,800, vampire spawn 1,800, black
pudding 1,100, crawling claw 10, skeleton 50, mongrelfolk 50, Strahd 13,000.

| id | Map | Trigger | Monsters | XP |
|---|---|---|---|---|
| `larders_guardroom` | larders | enter `larders_guardroom`, unless the watch is beaten | Sergeant of the Watch (wight), a second wight, 2 helmed horrors, 4 Strahd zombies | 4,400 |
| `larders_watch_alarm` | larders | dialogue (Cyrus screams) | the same watch, in the kitchen | 4,400 |
| `larders_cyrus_fight` | larders | dialogue (the party attacks him) | Cyrus Belview (mongrelfolk) | 50 |
| `larders_jailers` | dungeon | enter `larders_jailers_post` | 3 helmed horrors | 3,300 |
| `larders_furnace` | dungeon | enter `larders_furnace_room` | 2 flameskulls, the bound fire (fire elemental) | 4,000 |
| `larders_questioner` | dungeon | enter `larders_torture_chamber` | The Questioner (wight), 2 black puddings from the drain, 6 crawling claws | 2,960 |
| `larders_false_brother` | dungeon | dialogue (freed him), party surprised | Brother Anatol + 2 vampire spawn off the ceiling | 5,400 |
| `larders_false_brother_unmasked` | dungeon | dialogue (unmasked), no surprise | the same | 5,400 |
| `larders_doru_hunger` | dungeon | dialogue (freed him) | Doru (vampire spawn) | 1,800 |
| `larders_donjon` | dungeon | enter `larders_hall_of_bones`; `final_battle: castle_ravenloft_hall_of_bones`, `lair: true` | Strahd at the head of the table, 6 skeletons rising from the bone chairs | 13,300 |

The side fights sit at or under Low on purpose: the castle is long, the party rests little, and Strahd waits at the
end. None is on the way to either Tarokka place. Strahd appears in this part only in the final battle.

## 7. The Tarokka

- **`castle_ravenloft_wine_cellar`** ("one rack holds no wine. A tradesman was walled in among the bottles"):
  `treasure_spots` in `castle_ravenloft_larders` → dialogue `castle_ravenloft/larders_cellar:niche`, from the prop
  `larders_bricked_rack` at (7, 23) on the cellar's back wall. "Pull the bricks down" (no roll) → `tarokka give
  castle_ravenloft_wine_cellar` when `treasure_at:` the place. Cyrus tells where the rack is; the corks pressed in
  the mortar and the verse point there too.
- **`castle_ravenloft_hall_of_bones`** ("his old enemies were made into furniture. Sit at their table, and mind the
  lamp"): `treasure_spots` in `castle_ravenloft_larders_dungeon` → container `larders_bone_table` (36, 18), the
  drawer at the head of the table of bones. The lamp is the trap `larders_bone_lamp_trap` on the chairs around the table
  (detect 14, disarm 15, Dex 15, 4d10 fire), off once the furnace is quenched.
- **Enemy room `castle_ravenloft_hall_of_bones` (card `donjon`)**: encounter `larders_donjon` in the dungeon map,
  trigger `enter_area:larders_hall_of_bones`. The engine adds the reading's room, `strahds_lair` and Strahd's state
  to its `when` and plays `strahd/final:parley` first. The lamp's trap doesn't run in combat.

## 8. Traps and secret doors

- `larders_bone_lamp_trap` (hall of bones): see §7. `when: not flag.larders_furnace_quenched`.
- `larders_open_cell_pit` (N4, the cell whose gate stands open, with a satchel on the straw as bait): a false floor
  over an oubliette, `pit_ft` 40 (4d6 bludgeoning is the fall itself; the climb out is rope or DC 15 Athletics,
  world/exploration/pit_fall.gd); detect 15, disarm 15, Dex 14.
- Secret doors `larders_crawl_furnace` (30, 9) and `larders_crawl_throne` (37, 11), DC 15: the stoker's crawl, with
  a dead stoker's pouch. A back way into the hall of bones.

## 9. Flags read from other parts and regions

| Flag (owner) | Read by |
|---|---|
| `doru_freed`, `doru_cure_promised` (village_of_barovia) | Doru in cell N2 exists only if the party let him out; the cure line |
| `belview_family_met`, `clovin_met`, `abbot_fate` (krezk) | Cyrus's family and Father |
| `lucian_met` (vallaki) | a no-roll way to unmask Anatol |
| `winery_wine_flows` (wizard_of_wines) | Cyrus's cellar talk; Narrator in the cellar |
| `strahd_met` (village_of_barovia) | Cyrus on the Master |

## 10. Flags (data/flags/castle_ravenloft_larders.json) and what others should read

All are registered, set and read in this package. For the endings and epilogues (P6 endings owner):

- **`larders_nadia_fate`** (`escaped`, `sent_alone`, `waits`; unset if left chained or never found): `escaped` she
  is home in Vallaki lighting lamps; `waits` she lives if Strahd is destroyed, else not; `sent_alone` she was caught.
- **`larders_doru_fate`** (`rest`, `freed`, `left`) and `larders_doru_destroyed`: Donavich's slide.
- **`larders_cyrus_slain`**, `larders_cyrus_helps`, `larders_cyrus_hostile`: Cyrus's slide (he keeps cooking for an
  empty castle, goes home to the abbey, or is gone).
- `larders_anatol_destroyed`, `larders_furnace_quenched`, `larders_niche_opened`: flavour.

## 11. Quests

- **`the_cooks_guests`** ("The Cook's Guests"): `heard` (Cyrus mentions his guests) → `found` (Nadia) → `freed`
  (her chain off) → `escaped` (success) / `hidden` (open: she waits in her cell) / `caught` (failure: she ran alone).

## 12. Loot

| Container | Map | Contents |
|---|---|---|
| `larders_pantry_shelves` | larders | 6 rations, 2 oil, a tinderbox |
| `larders_cyrus_box` (flag `larders_cyrus_box_opened`; Cyrus notices) | larders | 7 gp in buttons and coins, 3 candles |
| `larders_watch_lockers` | larders | 2 longswords, a chain shirt, a shield, 40 gp |
| `larders_jailers_chest` | dungeon | 2 manacles, a hooded lantern, a holy symbol, 26 gp (the prisoners' things) |
| `larders_lure_satchel` (in the pit cell) | dungeon | a potion of healing, 12 gp |
| `larders_torture_chest` | dungeon | thieves' tools, 2 manacles, 18 gp |
| `larders_stoker_pouch` (secret crawl) | dungeon | 2 potions of healing, 15 gp |
| `larders_bone_table` | dungeon | 60 gp in old coin; the Tarokka treasure when the reading puts one here |
| prop `larders_loose_stone` (search 14) | dungeon | a potion of healing |
| dialogue (the niche) | larders | 35 gp, a book (the merchant's ledger) |

No new items: the jailers' keys and the merchant's ledger are flags and text.

## 13. Monsters needed

None: every id used exists in data/monsters (`strahd_von_zarovich`, `helmed_horror`, `skeleton`, `black_pudding`,
`crawling_claw` from P6-02; `wight`, `strahd_zombie`, `flameskull`, `fire_elemental`, `vampire_spawn`,
`mongrelfolk`, `commoner`). Cyrus fights as `mongrelfolk` named "Cyrus Belview"; if P6-02 gives him his own block,
swap the encounter's `monster` and his npc `monster`.

## 14. Props needed (each uses the nearest catalog art today)

- A table, chairs and a throne built of bones (`table_set`, `chair_high`); a skull chandelier burning green
  (`candelabra` with a fixed `magic` light: a `burning` prop draws a bonfire, too big for a lamp).
- The green furnace (`brazier_green` with `burning`); an iron lift cage on chains (`cage_hanging`); a sluice wheel
  (`winch`).
- A key board (`tally_board`); a bricked-up wine rack with corks in the mortar (`brick_wall`); the open niche
  (`wall_alcoves`); a merchant's skeleton among bottles (`skeleton_leather`).
- A cauldron on a hook (`tub_wooden`); hanging meat (`carcass`); a slate guest list (`notes_wall`); an iron maiden
  (`coats`); a half-made chair of bones (`chair_high`).
- Portraits and sprites: `cyrus_belview` (a stooped mongrelfolk cook: boar's tusk, hare's ear, goat's hoof, a
  stained apron), `nadia_boteanu` (a young woman in a soot-streaked dress, lamplighter's pole-hook burns on her
  hands), `brother_anatol` (a pale, clean-shaven monk in a grey habit with a sun badge; too clean for a cell).

Engine asks (nice to have): a `when` on `lights` (the bone lamp's light should die with the furnace), and a green
`burning` style for the furnace and the lamp.

## 15. Critical path (story bot)

Start in `castle_ravenloft_larders` at `from_gates`, level 10, by day. No flags need setting.

- **The wine cellar treasure:** `walk_to(Vector2i(7, 22))`, `use` the prop `larders_bricked_rack` (7, 23) →
  prefer "Pull the bricks down" → `tarokka give castle_ravenloft_wine_cellar`. The cellar door (7, 11) is an
  ordinary door; nothing fights on the way.
- **The hall of bones treasure:** `go_to("castle_ravenloft_larders_dungeon")` (exit `larders_stair_down` at
  (33, 22) in the jailers' stair; arrives at `from_larders` (2, 3)), then walk east through the dungeon hall, down
  the cell stair (20, 6)-(21, 11), along the cell passage to the hall's door (25, 12), and open the container
  `larders_bone_table` (36, 18). The trap on the chairs may fire (damage only). No fight on the way unless the
  reading's enemy room is this one.
- **The enemy room (`donjon`):** same walk; `larders_donjon` starts on entering `larders_hall_of_bones` (after the
  parley). Prefer "Turn the wheel" in the furnace room first if the bot visits it (optional).
- **The prisoners (optional):** prefer "Use the jailers' keys", "The cook will smuggle you out", "Your breath doesn't
  fog", "Stay in your cell", "We could end this"; avoid "We're getting you out" (Anatol's ambush), "Strike the
  chains off" (Doru), "(Draw steel on him.)" and the Intimidation option with Cyrus.

## 16. Files

- Region: docs/regions/castle_ravenloft_larders.md (this file); task docs/tasks/P6-07.md
- Locations: data/locations/{castle_ravenloft_larders, castle_ravenloft_larders_dungeon}.json
- NPCs: data/npcs/{cyrus_belview, nadia_boteanu, brother_anatol}.json; voice docs/voice/{same}.md
- Quest: data/quests/the_cooks_guests.json; flags data/flags/castle_ravenloft_larders.json
- Dialogue: narrative/castle_ravenloft/{larders_cyrus, larders_cells, larders_cellar, larders_machinery}.dialogue;
  narrative/narrator/castle_ravenloft_larders.dialogue; narrative/banter/castle_ravenloft_larders.dialogue
