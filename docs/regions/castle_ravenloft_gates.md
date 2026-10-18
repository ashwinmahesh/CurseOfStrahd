# Castle Ravenloft, part `gates`: the approach, the main floor, the dining hall and the chapel (Phase 6)

Plan §10 Phase 6; ADR 0014 (castle, Strahd, endings); ADR 0011 (treasure spots). Overview and seams:
docs/regions/castle_ravenloft.md. Task: docs/tasks/P6-04.md. Party level 9 to 11 on arrival; the castle gives no
milestone. Area numbers below follow the book's keyed areas (K1 to K17) only as a guide for checking; every line,
name and description in the data and dialogue is our own.

## 1. What this part is for

The front of the house. The party comes up the castle road, over the drawbridge and through the gatehouse into the
front courtyard, and the great doors open before anyone touches them: the castle is open to everyone, invited or not.
Inside is the main floor, the hub of the whole castle: every other part is reached from here (the grand stairs up to
the Court of the Count, the high tower stairway to the spires, the servants' stairs down to the larders, the stairs
down to the crypts).

Three things happen here:

- **The dinner.** A party that accepted Strahd's invitation (the presence package's black carriage,
  `strahd_invitation == "accepted"`) finds him at the organ in the dining hall. He is a perfect host: he seats them,
  feeds them, talks, and leaves. No fight unless the party starts one, and then he tests them for a few rounds and goes
  (`withdraw`). The party that walks in uninvited finds the table laid for exactly as many as they are, and no host.
- **Two Tarokka treasure places**: the chapel's altar, under the dust of the last prayer said there; and a hoard behind
  a hearth that burns with no wood, at the end of the hall of faces.
- **Two enemy rooms**: the chapel (`artifact`) and the overlook balcony (`executioner`).

Tone: a grand, cold, beautiful house that is pleased to see you. Nothing here hurries. The menace is in the manners.

## 2. Maps and areas

Four maps. Area, prop, container and door ids carry the prefix `crg_` (Narrator keys are global and four other parts
write castle rooms at the same time).

| Map | Size, theme | Areas (book areas) | What happens |
|---|---|---|---|
| `castle_ravenloft_gates` | 40 x 34, `shrine_yard`, outdoors, dim | `crg_cliff_road` (the road's end below the gates), `crg_drawbridge`, `crg_gatehouse` (the gate passage, portcullis), `crg_front_courtyard` (K1), `crg_servants_court` (K2 the center court gate, K3), `crg_carriage_house` (K4), `crg_overlook_walk` (K5, the walk along the outer wall) | Arrival (spawn `gate`), the drawbridge over the chasm, the portcullis, the keep's great doors; the black carriage; the gargoyles on a night visit by uninvited guests (`crg_courtyard_gargoyles`). |
| `castle_ravenloft_main_floor` | 52 x 25, `manor` (castle stone walls, marble and parquet floors set per area), dark | `crg_entry` (K7), `crg_great_entry` (K8), `crg_guests_hall` (K9), `crg_dining_hall` (K10), `crg_servery`, `crg_turret_post_west`, `crg_turret_post_east` (K11 to K13), `crg_tower_stair_foot`, `crg_hall_of_faces` (K14), `crg_hidden_hoard` (behind the hearth), `crg_chapel_access` (K16, K17) | The hub: spawns from every part, exits to every part. The dinner; the hall of faces and its ever-burning hearth; the hidden hoard (Tarokka place); the turret guards. |
| `castle_ravenloft_chapel` | 20 x 22, `church`, dark | `crg_chapel_chancel`, `crg_chapel_nave` (K15), `crg_chapel_porch` | The chapel's altar (Tarokka place); Strahd's final battle when the reading says `artifact`; Ireena at the altar while Strahd holds her (§6, "Ireena in the chapel"). |
| `castle_ravenloft_overlook` | 26 x 13, `shrine_yard`, outdoors, dim | `crg_overlook_landing`, `crg_overlook` (K6) | A long balcony over a thousand-foot drop; Strahd's final battle when the reading says `executioner`. |

### Ways between maps

| From | Exit (cell) | To (spawn) |
|---|---|---|
| gates | `road_out`, `road_out_east` (19,33), (20,33) | travel map |
| gates | `great_doors`, `great_doors_east` (19,8), (20,8) | `castle_ravenloft_main_floor:from_gates` |
| gates | `overlook_walk`, `overlook_walk_east` (3,0), (4,0) | `castle_ravenloft_overlook:from_gates` |
| main floor | `great_doors_out`, `great_doors_out_east` (25,24), (26,24) | `castle_ravenloft_gates:from_main_floor` |
| main floor | `chapel_doors`, `chapel_doors_south` (45,17), (45,18) | `castle_ravenloft_chapel:from_main_floor` |
| chapel | `chapel_out`, `chapel_out_east` (9,21), (10,21) | `castle_ravenloft_main_floor:from_chapel` |
| overlook | `walk_back`, `walk_back_south` (0,3), (0,4) | `castle_ravenloft_gates:from_overlook` |

### Seams (overview table), all in `castle_ravenloft_main_floor`

| Seam | Exit (cell, label) | Arrives at | Spawn here for the way back |
|---|---|---|---|
| gates → court | `grand_stairs_up`, `grand_stairs_up_east` (25,1), (26,1), "The grand stairs up" | `castle_ravenloft_court:from_gates` | `from_court` (25,4) |
| gates → spires | `high_tower_stairway` (39,1), "The high tower stairway, up" | `castle_ravenloft_spires:from_gates` | `from_spires` (38,3) |
| gates → larders | `servants_stairs_down` (1,1), "The servants' stairs down to the kitchens" | `castle_ravenloft_larders:from_gates` | `from_larders` (3,2) |
| gates → catacombs | `crypt_stairs_down` (44,23), "The stairs down to the crypts" | `castle_ravenloft_catacombs:from_gates` | `from_catacombs` (42,22) |

Other spawns: gates `gate` (19,31, arrival by road), `default` (19,12, in the courtyard before the doors: where the
black carriage sets the party down), `from_main_floor` (19,10), `from_overlook` (3,2); main floor `default` and
`from_gates` (25,22), `from_chapel` (43,17); chapel `default` and `from_main_floor` (9,19); overlook `default` and
`from_gates` (1,3).

### Secret door and hidden room

The hall of faces ends at a great hearth (`crg_ever_hearth`, (46,5)) whose fire burns with no wood, no smoke and no
heat. Behind it is a small vault, `crg_hidden_hoard`, reached by the secret door `crg_hearth_back` at (47,5)
(Perception DC 13 to find; it won't move while the fire burns: `when: flag.crg_ever_hearth_out`). The hearth's
conversation (`gates_hearth:start`) puts the fire out three ways:

- **Shut the flue and smother it** (no roll): the fire dies, and the hall wakes: `crg_faces_wake` (below).
- **Holy water** (`[if item:holy_water]`, spends one): it goes out quietly.
- **Arcana DC 15**, unpicking the spell that feeds it: quietly. A failure knots the spell tighter: that option is gone
  (`crg_hearth_arcana_failed`), so the only ways left are holy water or the loud way.

## 3. Encounters (2024 DMG, four characters at level 10: Low 6400 / Moderate 9200 / High 12400)

XP: Strahd 13000 (CR 15), Strahd's animated armor 2300, helmed horror 1100, vampire spawn 1800, gargoyle 450,
guardian portrait 200, swarm of bats 50. The castle wears a party down room by room; only the final battles are meant
to be hard.

| id | Map | Trigger | Level 10+ | Below 10 |
|---|---|---|---|---|
| `crg_courtyard_gargoyles` | gates | enter `crg_front_courtyard` at night, uninvited (`flag.strahd_invitation != "accepted"`) | 6 gargoyles (2700) | 4 gargoyles (1800) |
| `crg_turret_guard` | main floor | enter `crg_turret_post_east` | 2 Strahd's animated armor (4600) | 1 (2300) |
| `crg_faces_wake` | main floor | `flag:crg_ever_hearth_out` unless it went out quietly | 2 guardian portraits + 3 helmed horrors (3700) | 2 portraits + 2 horrors (2600) |
| `crg_dinner_affront` | main floor | dialogue (the party draws on Strahd at his table) | Strahd at 375 HP (fights until beaten, then flees with a parting line; flag `strahd_withdrew`) + 3 swarms of bats + 2 suits of his animated armour | same |
| `crg_chapel_final_battle` | chapel | enter `crg_chapel_nave`; `final_battle: castle_ravenloft_chapel`, `lair: true` | Strahd (350 HP) + 2 vampire spawn (his thralls at prayer in the pews) + 4 more of his spawn: 23800, a deadly finale | same |
| `crg_overlook_final_battle` | overlook | enter `crg_overlook`; `final_battle: castle_ravenloft_overlook`, `lair: true` | Strahd (350 HP) + 3 swarms of bats boiling up from the cliff + one of his spawn: 14950 | same |

Strahd's dinner is tuned like his other fights (owner, 2026-10-13): the sharp test party carrying the Sunsword wins 5 of
8, Strahd at 375 HP with two suits of his armour. He fights until he's beaten (owner, 2026-10-13: "let him fight till
his HP goes to 0, but that's his signal to flee") and goes with a parting line, which the fight waits for
(tests/integration/test_scaled_boss_fights.gd). His spawn didn't last against the Sunsword and Turn Undead, so the
count's armour fights here instead.

Strahd's final battles are tuned for a party carrying the Sunsword (owner, 2026-10-13), at the sharp test party's 5
wins in 8 on Balanced: Strahd at 350 or 375 Hit Points with one to five of his spawn beside him, and he keeps out of the
blade's sunlight where he can (a legendary move held back to slip out of it before his turn, his spells cast from
outside it, Charm on its bearer first). Without the Sunsword he stays near-unbeatable, as in the book
(tests/integration/test_scaled_boss_fights.gd).

Why Strahd appears outside a final battle: only at the dinner, as the host the invitation promised. He fights there
only if the party attacks him at his own table, and then he leaves (`withdraw`), as ADR 0014 asks of every fight that
isn't the last one. The dinner fight's own flag on victory is `crg_dinner_fight_over`.

The final battles have no `when` of their own: the engine adds `final_room:<room>`, `strahds_lair` at `foretold` or
later and Strahd not destroyed, and plays `strahd/final:parley` first. Neither has a victory flag: a won fight is not
replayed, and Misty Escape (the engine's) sends Strahd to his coffin.

## 4. The Tarokka

| Place | Map | Spot | How it's reached |
|---|---|---|---|
| `castle_ravenloft_chapel` | `castle_ravenloft_chapel` | container `crg_chapel_altar` (9,2), the altar heaped with dust | Walk in. If Strahd waits here (`artifact`), the final battle starts in the nave first. |
| `castle_ravenloft_hidden_hearth` | `castle_ravenloft_main_floor` | container `crg_hearth_hoard` (49,2), an iron strongbox in the hidden vault | Put out the hearth (conversation), search (DC 13) for the seam beside it, open the door, open the box. |

Hints: the Narrator's lines for the nave and the hall of faces have `[treasure_at:...]` variants; the hearth's
conversation says what is behind it when a treasure is there.

Enemy rooms: `castle_ravenloft_chapel` (card `artifact`) and `castle_ravenloft_overlook` (card `executioner`), one
encounter each as above. The `mists` card may pick either.

## 5. The dinner (narrative/castle_ravenloft/gates_dinner.dialogue)

- Strahd stands by the organ in the dining hall at (5,5) (`npcs` entry with `approach: 8`) when
  `flag.strahd_invitation == "accepted" and not flag.castle_dinner`. He stops playing and greets the party, with
  lines for what they've done: their first answer to him (`strahd_first_impression`), the letter (Ilse), Ireena with
  them or held in the castle (`ireena_held_by_strahd`), the road fight (`strahd_test`), the beacon at Argynvostholt (`argynvost_beacon_lit`), the
  Amber Temple (`dark_gifts_taken`), Marina's truth (`strahd_knows_marina_truth`). Quest
  `dinner_at_castle_ravenloft seated`.
- The table: talk (why he invited them; the house; Tatyana, if Ireena is there or known); the wine (`Medicine DC 13`
  tells it is only wine, very old); `Insight DC 17` on what he actually wants (a failure is spent, and he notices: he
  is amused, `crg_dinner_stared`); a cleric's grace said at his table.
- Endings: **thank him** (`castle_dinner = "dined"`, quest `dined`): he leaves the party the run of the house for the
  night, and goes; or **draw on him** (`castle_dinner = "affront"`, quest `affront`, `combat crg_dinner_affront`).
- No menu depends on a roll; leaving is always there.
- While the invitation is open and dinner isn't over, the castle's walk-in fights wait (the dinner truce, §8); the
  Steward stands in the hall.
- Uninvited: no host. The table is laid for exactly as many as the party; the organ plays a few bars by itself when
  they come in (Narrator).

## 6. Flags (data/flags/castle_ravenloft_gates.json)

| Flag | Type | Set by | Read by |
|---|---|---|---|
| `castle_dinner` | string | dinner: `dined` or `affront` | dinner NPC `when`, Narrator, banter; endings and epilogues may read it |
| `crg_dinner_stared` | bool | dinner (Insight failed) | dinner (his remark when leaving) |
| `crg_dinner_wine_known` | bool | dinner (Medicine) | dinner, banter |
| `crg_dinner_fight_over` | bool | `crg_dinner_affront` won | Narrator, banter |
| `crg_ever_hearth_out` | bool | hearth conversation | hearth prop `burning`, the secret door's `when`, `crg_faces_wake` trigger, Narrator |
| `crg_hearth_quiet` | bool | hearth (holy water or Arcana) | `crg_faces_wake` `when` |
| `crg_hearth_arcana_failed` | bool | hearth (Arcana failed) | hearth |
| `crg_hoard_opened` | bool | container `crg_hearth_hoard` | banter |
| `crg_altar_opened` | bool | container `crg_chapel_altar` | Narrator (the nave) |
| `crg_gargoyles_broken` | bool | `crg_courtyard_gargoyles` won | Narrator (the courtyard) |
| `crg_turret_guard_broken` | bool | `crg_turret_guard` won | Narrator (the turret post) |
| `castle_truce_over` | bool | the engine, as the party leaves the castle with the invitation open and no dinner yet (StoryConditions.note_departure) | the castle's truce (StoryConditions.TRUCES) |

Read from elsewhere: `strahd_invitation`, `strahd_test`, `ireena_held_by_strahd` (presence, P6-03; the dinner fight's
withdraw sets the presence package's `strahd_withdrew`, which the parley reads);
`strahd_first_impression`, `strahd_met` (village); `argynvost_beacon_lit`, `order_fate` (Argynvostholt);
`dark_gifts_taken` (Amber Temple); `strahd_knows_marina_truth` (Berez); `ireena_pool_vision` (Krezk).

**Ireena in the chapel** (Story Allies Presence Plan, package I5). While `ireena_held_by_strahd` is set and she is not a
guest, the chapel's `ireena` entry stands at the altar (10,2), entranced (`approach: 7`, `steps_aside`; her usual sprite, so no line says what she wears).
The entry is hidden while the chapel's final battle is live (`final_room:castle_ravenloft_chapel`, the reading given, Strahd
neither destroyed nor in his coffin): the parley says she is upstairs, and she is not at the altar behind him. After he falls
to his coffin she is there again. `narrative/castle_ravenloft/chapel_ireena.dialogue` mirrors the window's menu
(`strahd/ireena:window_menu`): the Holy Symbol of Ravenkind, a Cleric's or Paladin's faith, the Sunsword, Religion DC 15
(a warding prayer), Persuasion DC 15 (spent on failure), and "Leave her". Any success runs `woken`: **it clears
`ireena_held_by_strahd` and `join ireena`** (the one place this plan moves her main state), pays companion approval, and
gives Ismark a line if he came up with the party. A failed prayer or plea costs 10 minutes and a step
(`ireena_chapel_pull`); at two the trance holds for now (30 more minutes, the visit ends, `ireena_chapel_pull` back to 0)
and the party may come back. Two pictures (docs/ui/cutscenes.md): `ireena_altar` at the first sight of her and
`ireena_woken` when she wakes. Side flags (castle_ravenloft_personal.json): `ireena_chapel_seen`, `ireena_chapel_pull`.
Not changed: `ireena_sanctuary = "taken"`, `strahd_window = "taken"` and the Sanctuary quest's `taken` stage (a failure
ending) stay as the window left them.

## 7. Quest

`dinner_at_castle_ravenloft` (giver `strahd`): `seated` → `dined` (success) or `affront` (failure).

## 8. NPCs

Strahd (`strahd`, voice docs/voice/strahd.md) hosts the dinner. The castle's named people (Rahadin, the brides, Cyrus)
belong to the other parts.

**The household** (owner, 2026-10-15: "Is Castle Ravenloft supposed to be empty when you walk through it? Should there
be servants?"). The book keeps its living staff to Cyrus and Rahadin and fills the rooms with the dead and the
animated; the main floor now has three of them walking it, each with a short conversation
(narrative/castle_ravenloft/gates_household.dialogue) that sets nothing and can always be left. Each entry has
`steps_aside`, so they leave the board for every fight on the map (the tuned fights are played as before).

| Who | Id (stat block, art) | Where | What they do |
|---|---|---|---|
| The Steward | `castle_steward` (`ghost`; his own art, owner's yes 2026-10-15) | dining hall, from the sideboard (11,12) up the east side to (11,6) | the ghost of the last steward, straightening places that are already straight; he can't carry a dish, and the dishes arrive anyway (the dinner's "nobody carries it in" stands). His lines follow the dinner: expecting the master's guests, after a thank-you, after steel at the table. Voice: docs/voice/castle_steward.md |
| The Dead Sentry | `castle_dead_sentry` (`strahd_zombie`) | great entry, east side, (31,12) to (31,2) | a castle guard dead since the wedding night, on the round nobody relieved; Narrator lines only |
| The Hall Broom | `castle_hall_broom` (`broom_of_animated_attack`) | guests' hall, sweeping from (14,11) round the room | an animated broom at its sweeping (`work: swing`); Narrator lines only |

**The court and the rest of the household** (owner, same day: "fill Castle Ravenloft with generic NPCs who act as the
servants or Strahd's court (it could be vampires) ... make sure they have paths which they walk around"; and that
evening: "all the pale courtiers have the same lines, and that shouldn't be the case"). Fourteen more, each their own
person: a name nobody else in the game has, one map, a route, and a conversation of their own in
narrative/castle_ravenloft/household.dialogue that sets nothing and can always be left. Every one steps aside for
fights. The courtiers and ghosts talk; the dead watch and kitchen hands have Narrator lines only. The courtiers' and
the ghosts' greetings follow the dinner (invited, dined, affront, or uninvited), and while the truce holds five of them
explain it in their own words (test_castle_household checks each walks one map, under their own name, opening with
words nobody else says).

| Who (id; art) | Walks | Who they are | Manner, and their secret or complaint |
|---|---|---|---|
| Lord Aubrey Thale (`castle_courtier_1`; `vampire_spawn`) | main floor: a loop round the great entry's middle (24,7)-(27,12) | a gentleman traveller who came through the mists in his own carriage 190 years ago, dined and stayed the night | languid, dry, the court's gossip; his carriage still waits in the carriage house, and he is leaving in the morning |
| Lady Celestine Morrow (`castle_courtier_2`; the `vampire` art, also Corvina's) | main floor: the hall of faces (35,8) to (48,8) | a lady of fashion from beyond the mists who came up for a ball and danced the last dance with the host | vain, flirtatious, wistful; no glass shows her face, and she is forgetting it (the party can describe it to her) |
| Boyar Vintila Crainic (`castle_courtier_3`; `noble`) | the court: the audience hall (14,5) to (29,5) | a boyar of the orchards above the Ivlis, 206 years waiting to present a petition about a moved boundary stone | pompous, punctilious, comic; won't let anyone carry his petition for him; afraid of Rahadin's list |
| Sir Lothar Brandt (`castle_courtier_4`; `vampire_spawn`) | the court: the trophy room (35,7) to (41,4) | a hunter of the dead who came up the road 90 years ago to end the count and was made one of his court | bitter, wry; one of the wolves on the wall is his own kill, hung where he'd see it; he can't say how to kill his master ("listen to what I'm not saying") |
| Nicodim the Verger (`castle_ghost_servant_2`; `ghost`) | main floor: the chapel passage (40,14) to (40,21) | the chapel's verger, who believes it is still the night before Sergei and Tatyana's wedding | fussy, kind, devout; takes Ireena for the bride (her interject) |
| Anghel Daskal (`castle_ghost_servant_3`; `ghost`) | the court: the study (5,8) to (9,6) | the count's secretary, who wrote his letters and kept his day-book | precise, proud, a little jealous that the count writes his own letters now; won't look at the portrait over the mantel, having written out the wedding's banns |
| Ghenadie the Valet (`castle_ghost_servant_4`; `ghost`) | the Rooms of Weeping: the count's bedroom (3,6) to (10,2) | the count's valet, turning down a bed the master hasn't slept in since the wedding | discreet, devoted, hurt not to be needed; warns of the three ladies and of Helga |
| Vlaicu the Lamplighter (`castle_ghost_servant`; `ghost`) | the spires: the foot of the high tower (2,6) to (5,18) | the castle's lamplighter, who died on the 209th step | tired, plain-spoken, grumbles about the stair; warns of the little wooden man who pushes; the tower is lit to make travellers think someone's home |
| The Dead Halberdier (`castle_dead_guard_1`; `strahd_zombie`) | the courtyard before the keep (9,9) to (30,9) | one of the watch | knocks three times at the great doors on every round, for carriages that stopped coming |
| The Dead Archer (`castle_dead_guard_2`; `strahd_zombie`) | the courtyard inside the gatehouse wall (11,20) to (28,20) | one of the archers who shot the count on the wedding night (History 13) | draws and looses an empty bow, and looks for where it landed |
| The Dead Doorward (`castle_dead_guard_3`; `strahd_zombie`) | main floor: the entry hall (23,17) to (23,22) | the entry hall's doorward | holds out his hands for the guests' swords, and stops nobody |
| The Dead Turnkey (`castle_dead_guard_4`; `strahd_zombie`) | the dungeon: the passage between the cells (3,13) to (23,12) | the dungeon's turnkey | shakes every cell gate on his round; catches a wrist that reaches for his keys, and lets it go |
| The Dead Scullion (`castle_dead_servant_1`; `zombie`) | the larders: the kitchen round Cyrus (21,2)-(28,2)-(21,6) | a scullion | scours the same clean pot all night while Cyrus praises him (or waits by Cyrus's empty stool) |
| The Dead Torchbearer (`castle_dead_servant_2`; `zombie`) | the larders: the guards' run end to end (3,9) to (36,9) | a drudge of the lower floors | lights torches that are already burning; his sleeve is scorched and he hasn't noticed |

**The dinner truce** (owner, 2026-10-15: the castle's fights shouldn't be there until the dinner sequence is
complete, unless the book says so; it doesn't say the guardians stand down for guests, so the owner's word decides).
While `strahd_invitation == "accepted"` and `castle_dinner` is unset, every castle fight that starts as the party walks
into a room waits (StoryConditions.TRUCES, read by `encounter_when` with the map's region): the turret guard, the
gargoyles' and guardians' halls, the larders' dead watch, the spires' sentries, the cauldron coven (not shown waiting
either), and Strahd's final battles (he is at the organ). Fights the party starts itself still come: talking one
into being (Rahadin, the brides, Cyrus, the dinner affront), putting out the hearth the loud way (`crg_faces_wake`),
robbing the ravens' nest, a failed check on Rahadin's footlocker, breaking the Heart of Sorrow. A Long Rest under the
truce is a safe one (the rest screen). Once dinner ends, thanked or affronted, every held fight is back as it was and
starts the next time the party walks in. A party that excuses itself from the table is still a guest, so the truce
holds while it walks about the castle; leaving the castle ends it for good (owner, 2026-10-15: "end it once they leave
Castle Ravenloft ... when they return, it's back to how it was"): arriving at any place outside the region sets
`castle_truce_over` (StoryConditions.note_departure, from LocationView), and a party that comes back finds every fight
as it was, while Strahd's table still waits if dinner never happened (tests/integration/test_castle_household.gd).

## 9. Loot

| Container | Map | Contents |
|---|---|---|
| `crg_carriage_box` | gates | blanket, hooded lantern, oil |
| `crg_guard_locker` (lock 14) | gates | 20 crossbow bolts, rope, 12 gp |
| `crg_servery_cupboard` | main floor | 4 rations, 6 candles |
| `crg_dining_sideboard` | main floor | 2 glass bottles (old wine), 25 gp of silver plate |
| `crg_guests_wardrobe` | main floor | fine clothes, perfume |
| `crg_turret_rack` | main floor | halberd, shield, 20 crossbow bolts |
| `crg_hearth_hoard` | main floor | 320 gp in old crowns, an Animated Shield (very rare); the Tarokka treasure when the reading puts one here |
| `crg_chapel_altar` | chapel | 4 candles, 2 holy water, a reliquary holy symbol; the Tarokka treasure when the reading puts one here |
| `crg_poor_box` | chapel | 7 gp |

The random magic-item system (ADR 0012) scatters the rest.

## 10. Critical path (a test bot)

From the travel map (or `_start("castle_ravenloft_gates", 10)`, which arrives at `default` in the courtyard).
Day, or night with the invitation accepted, avoids the gargoyles. Set `strahd_invitation = "accepted"` before the
main floor loads (or call `view().refresh_npcs()` after setting it) so Strahd is at the table. This whole path,
the dinner fight and the overlook's final battle were played once with StoryBot at level 10 (a temporary test,
removed): every step below passed.

1. **Gate to the main floor:** `go_to("castle_ravenloft_main_floor")` (walks over the drawbridge, opens the
   portcullis door `crg_portcullis` at (19,22) on the way, steps on the great doors (19,8)). Arrives at `from_gates`
   (25,22).
2. **The dinner** (invited): `talk("strahd")` (he stands at (5,5) and speaks on approach). Prefer "Thank him for his
   hospitality". Avoid "Draw on him". Expect `castle_dinner == "dined"`. (Prefer "Draw on him" for the fight: he
   withdraws, `strahd_withdrew` and `crg_dinner_fight_over` are set.)
3. **Hidden hearth:** `use(Vector2i(46,5))` (the hearth) and prefer "Shut the flue and smother it" (or "Find the
   spell", "holy water"); win `crg_faces_wake` when it starts; `walk_to(Vector2i(47,6))`, call `view().search()`
   until `crg_hearth_back` is found; `use(Vector2i(49,2))` (the strongbox).
4. **Chapel (treasure, and the artifact room):** `go_to("castle_ravenloft_chapel")` (from the main floor through the
   door (38,11), the chapel access, the chapel doors (45,17)); arrives at (9,19); walking through the door (9,16)
   into the nave starts `crg_chapel_final_battle` when the reading names the chapel; `use(Vector2i(9,2))` opens the
   altar.
5. **Overlook (the executioner room):** `go_to("castle_ravenloft_gates")`, then `go_to("castle_ravenloft_overlook")`
   (the side gate (7,15), the walk, exit (3,0)); arrives at (1,3); `walk_to(Vector2i(8,3))` enters `crg_overlook`
   and starts `crg_overlook_final_battle` when the reading names it.
6. **To the other parts:** `go_to("castle_ravenloft_court")`, `go_to("castle_ravenloft_spires")`,
   `go_to("castle_ravenloft_larders")`, `go_to("castle_ravenloft_catacombs")` all start from the main floor's exits
   above.

## 11. Monsters needed

None beyond data/monsters and the Phase 6 list: `strahd_von_zarovich`, `strahds_animated_armor`, `guardian_portrait`,
`helmed_horror` (P6-02), and the existing `gargoyle`, `vampire_spawn`, `swarm_of_bats`.

## 12. Props needed (stand-ins used now)

- Gargoyles perched on the gatehouse and the keep (none placed; the monsters stand there when they wake).
- The black carriage (`wagon`), its black horses (`horse`).
- The keep's great doors: an exits rule so a label like "great doors" draws `door_double` or `manor_door` (today
  `door_house`).
- A drawbridge with chains, and a parapet over a drop (`bridge_parapet` for both).
- The ever-burning hearth: a fire that gives no heat, ideally a pale or green flame (`fireplace` with `burning`).
- The hall of faces: carved stone faces of the Zarovich dead (`relief`), and a guardian portrait (`painting`).
- The chapel: a broken stained window (`window_stained`), a saint with her face cut away (`statue_saint`), a
  dust-heaped altar (`altar_church`).
- A castle theme (stone floors and stone walls for halls; today `manor` with area `floor`/`walls` surfaces), and a
  `place_looks` entry for the courtyard's flagstones (today `shrine_yard` grass with cobbled areas).

## 13. Files

- Doc: docs/regions/castle_ravenloft_gates.md (this file); task docs/tasks/P6-04.md
- Locations: data/locations/{castle_ravenloft_gates, castle_ravenloft_main_floor, castle_ravenloft_chapel,
  castle_ravenloft_overlook}.json
- Travel: data/travel/castle_ravenloft.json (place `castle_ravenloft`, road from the Ivlis crossroads, table
  `svalich_woods`)
- Flags: data/flags/castle_ravenloft_gates.json; quest data/quests/dinner_at_castle_ravenloft.json
- NPCs (the household): data/npcs/{castle_steward, castle_dead_sentry, castle_hall_broom}.json, and the court and
  the rest of the household, data/npcs/{castle_courtier_1..4, castle_ghost_servant, castle_ghost_servant_2..4,
  castle_dead_guard_1..4, castle_dead_servant_1, castle_dead_servant_2}.json (narrative/castle_ravenloft/
  household.dialogue); voice docs/voice/castle_steward.md
- Dialogue: narrative/castle_ravenloft/{gates_dinner, gates_hearth, gates_castle, gates_household}.dialogue;
  narrative/narrator/castle_ravenloft_gates.dialogue; narrative/banter/castle_ravenloft_gates.dialogue
