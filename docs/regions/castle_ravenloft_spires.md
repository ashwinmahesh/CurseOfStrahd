# Castle Ravenloft, part `spires`: the high tower and the spires (Phase 6)

Plan §10 Phase 6; ADR 0014 (castle, final battle); ADR 0011 (treasure spots, allies). Overview and seams:
docs/regions/castle_ravenloft.md. Task: docs/tasks/P6-06.md. The party arrives at level 9 to 11; fights are tuned for
four characters at level 10 with one guest. The castle gives no milestone. Every name of a scene, line and
description here is our own; the book's area numbers are cited only so the layout can be checked against it (the
numbers marked "?" are from memory and need checking).

## 1. What this part is for

The tallest towers of the castle and the roofs between them. A stair winds up the inside of the high tower around an
open well; at the top, in a round room with windows on the whole valley, hangs **the Heart of Sorrow**: a great
crystal heart that beats, slowly, for Strahd. Every wound he takes, it takes first. Above the tower rooms are the
roofs: a slate keep roof, a narrow bridge across the drop, and the **north tower peak** where stone guardians crouch
on the parapet (not all of them stone). Under the roofs, in the rafters, is **the ravens' roost**. And on the stair
lives **Pidlwick II**, a child-sized clockwork jester who has been alone for a very long time.

Three things to do here, all optional unless the cards point here:

- **Break the heart.** Shattering it strips Strahd's ward for the rest of the game (flag
  `heart_of_sorrow_shattered`, §6). Strahd feels it break and comes to see who did it.
- **Take the treasures** the reading may have put at the north tower peak or in the ravens' roost.
- **Meet Pidlwick II**, the marionette card's ally, and decide whether to take a lonely toy with a dark secret along.

Tone: vertigo and loneliness. The wind never stops; the castle is very quiet up here; everyone who lives in the
spires is someone Strahd has set aside.

## 2. Who is here

| Who | Id (stat block) | Wants | Fears | Secret | Voice |
|---|---|---|---|---|---|
| Pidlwick II, clockwork jester | `pidlwick_ii` (`pidlwick_ii`), guest | A friend; to be chosen over someone else for once; to leave the castle | Being boxed up; winding down; the high tower stair | He pushed the first Pidlwick, the jester he was built to copy, down the stair, because the children loved the jester and not him | Mute: mime, bells, and words chalked on a little slate in capitals (PLAY? / FELL. STAIRS.) |
| Escher, a cast-off consort | `escher` (`vampire_spawn`, named) | Out of the castle; to matter again; Strahd hurt | Strahd; the sun; being forgotten | Strahd once took him up to see the heart, as one shows a lover a scar | Arch, vain, bitter wit; drawls; calls Strahd "our host" |
| Strahd | `strahd` (`strahd_von_zarovich`) | His heart whole; to know who broke it | (never shows it) | | docs/voice/strahd.md |

Voice bibles: docs/voice/escher.md, docs/voice/pidlwick_ii.md. Casting note: Pidlwick II never speaks aloud; his lines
are his slate in capitals (voice them as a small tinny whisper, or leave him silent).

## 3. Maps, areas and seams

Five maps. Ids, cells are `[x, z]`.

| Map | Book areas (approx.) | Theme | Areas | What is here |
|---|---|---|---|---|
| `castle_ravenloft_spires` (entry, 32 x 21, dark) | K18 high tower stairway, K19 grand landing? | `church` (stone) | `spires_tower_foot`, `spires_lamp_closet` (hidden), `spires_lower_stair`, `spires_grand_landing`, `spires_upper_stair`, `spires_high_landing` | The stair winds around an open well (void): foot of the tower (raised 0) → lower turns (1) → the grand landing (2) → upper turns (3, 4) → the high landing (4). Pidlwick II on the grand landing; the first Pidlwick's portrait by the well; a secret closet; a broken step; the stair's sentries. |
| `castle_ravenloft_spires_heart` (18 x 16, dim) | K20 Heart of Sorrow | `church` | `spires_heart_landing`, `spires_heart_chamber` | The round room at the top of the high tower, the heart hanging over a dais. The `marionette` enemy room. |
| `castle_ravenloft_spires_rooms` (30 x 20, dark) | K54 familiar room, K55 element room, K56 cauldron (and K21 to K24, the towers' small rooms?) | `manor` | `spires_familiars_room`, `spires_stillroom`, `spires_roof_stair`, `spires_tower_gallery`, `spires_cauldron_room`, `spires_escher_suite`, `spires_tower_vestibule` | The bats' room, the stillroom of four glass vessels, the witches' cauldron, Escher locked in his suite (with a hidden stair behind his wardrobe up to the roost), the ladder to the roofs. |
| `castle_ravenloft_spires_roofs` (36 x 26, outdoors) | K57 tower roof, K58 bridge, K59/K60 north tower peak? | `dungeon` (outdoors, void around) | `spires_south_tower_roof`, `spires_walkway`, `spires_keep_roof`, `spires_bridge`, `spires_north_peak` | Battlements, slate roofs, a two-square bridge over the drop, the stone guardians and the hollow one (a treasure place). |
| `castle_ravenloft_spires_roost` (26 x 14, dark) | the ravens' roost under the roofs | `attic` | `spires_roost` | Beams, nests, droppings and hundreds of ravens; the great nest (a treasure place); a brass key. |

### Seams (overview table) and internal ways

| Exit (map, cell) | Leads to | Kind |
|---|---|---|
| `castle_ravenloft_spires` `to_main_floor` (0, 12) | `castle_ravenloft_main_floor:from_spires` | door in the foot of the tower (gates seam) |
| `castle_ravenloft_spires` `to_court` (19, 0) | `castle_ravenloft_court:from_spires` | arch off the grand landing (court seam) |
| spawns `from_gates` (3, 12), `from_court` (19, 2) | | the two seams arriving |
| `castle_ravenloft_spires` `up_to_heart` (12, 18) | `castle_ravenloft_spires_heart:from_stair` | stair up from the high landing |
| `castle_ravenloft_spires` `to_rooms` (24, 20) | `castle_ravenloft_spires_rooms:from_high_tower` | door off the high landing |
| `castle_ravenloft_spires_heart` `down_to_landing` (5, 14) | `castle_ravenloft_spires:from_heart` | stair down |
| `castle_ravenloft_spires_rooms` `to_high_tower` (24, 19) | `castle_ravenloft_spires:from_rooms` | door |
| `castle_ravenloft_spires_rooms` `up_to_roofs` (25, 2) | `castle_ravenloft_spires_roofs:from_rooms` | ladder up |
| `castle_ravenloft_spires_rooms` `back_stair` (19, 10) | `castle_ravenloft_spires_roost:from_back_stair` | hidden stair behind Escher's wardrobe; `when` `flag.spires_back_stair_found or flag.spires_back_stair_told` |
| `castle_ravenloft_spires_roofs` `down_to_rooms` (6, 21) | `castle_ravenloft_spires_rooms:from_roofs` | hatch down |
| `castle_ravenloft_spires_roofs` `hatch_to_roost` (4, 4) | `castle_ravenloft_spires_roost:from_roofs` | hatch down |
| `castle_ravenloft_spires_roost` `up_to_roofs` (3, 2) | `castle_ravenloft_spires_roofs:from_roost` | hatch up |
| `castle_ravenloft_spires_roost` `back_stair_down` (22, 11) | `castle_ravenloft_spires_rooms:from_back_stair` | the hidden stair from above (always usable from this side) |

Secret ways and locks: the lamplighters' closet behind a panel in the foot of the tower (door `spires_closet_panel`,
secret DC 14, a hidden area); Escher's door locked (DC 16, he is kept in); the hidden stair behind his wardrobe (search
prop `spires_wardrobe_seam`, DC 15, or Escher's or Pidlwick's word). Traps: `spires_broken_step` on the upper turns
(found DC 14, Dex 15, 4d6 bludgeoning: a fall to the turn below), `spires_slick_slates` on the keep roof (found DC 13,
Dex 14, 3d6 bludgeoning and prone), `spires_rotten_beam` in the roost (found DC 13, Dex 13, 2d6 bludgeoning).

Area, prop, container, trap and door ids carry the prefix `spires_` (Narrator keys are global). Rest: `risky` on the
stair, in the tower rooms and in the roost; `no` at the heart and on the roofs.

## 4. Encounters (2024 DMG, level 10: Low 6,400 / Moderate 9,200 / High 12,400 for four)

XP: Strahd 13,000 (CR 15, P6-02), Strahd's animated armor 2,300 (CR 6), helmed horror 1,100, vampire spawn 1,800,
gargoyle 450, black pudding 1,100, Barovian witch 100, swarm of bats or ravens 50.

| Id | Map | Trigger | Level 11+ | Level 10 (default) | Lower |
|---|---|---|---|---|---|
| `spires_stair_watch` | spires | enter `spires_upper_stair` | 4 vampire spawn + 3 bat swarms (7,350) | 3 spawn + 3 swarms (5,550) | 2 spawn + 1 swarm (3,650) |
| `heart_guardians` | heart | dialogue (striking the heart) | 2 animated armor + 2 helmed horrors (6,800, Low+) | 2 armor + 1 horror (5,700) | 1 armor + 1 horror (3,400) |
| `heart_of_sorrow_final` | heart | enter `spires_heart_chamber`; `final_battle: castle_ravenloft_heart_of_sorrow`, `lair: true` | Strahd + a helmed horror (14,100: above High; the heart's ward adds 50 HP unless shattered) | same | same |
| `heart_strahd_test` | heart | `flag:heart_of_sorrow_shattered` | Strahd alone, `withdraw` after 1 round or below 110 HP | same | same |
| `cauldron_coven` | rooms | enter `spires_cauldron_room` | 8 witches + black pudding (1,900) | 6 witches + pudding (1,700) | 4 witches + pudding |
| `escher_fight` | rooms | dialogue | Escher + 2 bat swarms (1,900) | same | same |
| `peak_guardians` | roofs | enter `spires_north_peak` | 8 gargoyles (3,600) | 6 gargoyles (2,700) | 4 gargoyles |
| `roost_swarm`, `roost_swarm_roused` | roost | open the great nest / the ravens roused in dialogue | 6 raven swarms (300) | same | same |

The castle is fought as a run without a safe rest, so several fights sit under Low on purpose; the gargoyles fight
on a windy peak with two-square bridges and drops, the coven's pudding splits, and the witches are mostly a nuisance
with nasty spells. **Strahd outside the final battle** appears once, in `heart_strahd_test`: he feels his heart break
and comes up the well as mist to see who did it, fights one round and leaves (`withdraw`, flag
`strahd_heart_tested`); it doesn't fire when the heart room is his drawn room (`final_room:`) or once
`strahds_lair` is `confronted` or later.

## 5. The Tarokka

- **`castle_ravenloft_north_tower_peak`** ("among the stone guardians"): `treasure_spots` in
  `castle_ravenloft_spires_roofs` → container `spires_hollow_guardian` at (31, 3), a guardian that never moved, its
  base hollow. Reached across the bridge; `peak_guardians` starts when the party steps onto the peak. The Narrator's
  `open:` line hints when `treasure_at:` holds.
- **`castle_ravenloft_ravens_roost`** ("among the ravens' nests"): `treasure_spots` in `castle_ravenloft_spires_roost`
  → container `spires_great_nest` at (15, 6). Opening it with the ravens unsettled starts `roost_swarm`; the ravens can
  be calmed first (the Keepers' friendship `keepers_allied` or the road raven fed `raven_fed`, food, or Animal
  Handling 14, 18 if the party struck the road raven). The verse's "clever hand" is Pidlwick II, who hides bright
  things in nests; the ravens took his key.
- **`castle_ravenloft_heart_of_sorrow`** (enemy room, card `marionette`): encounter `heart_of_sorrow_final` in
  `castle_ravenloft_spires_heart`, trigger `enter_area:spires_heart_chamber` (the whole round room). Strahd waits by the
  heart with one helmed horror; the engine adds the reading's conditions and plays the parley first.
- **Ally `marionette` → Pidlwick II** (`data/npcs/pidlwick_ii.json`, `guest: true`, `guest_build` monster
  `pidlwick_ii`). Join scene `castle_ravenloft/spires_pidlwick:cards` (option "Madam Eva's cards showed us a clockwork
  jester.") → `join pidlwick_ii`, `quest find_the_ally found`. Also possible otherwise: bring back his wind-up key
  from the roost (`the_jesters_key`) and he asks to come. Turning him away when the cards named him sets
  `find_the_ally lost`.

## 6. The Heart of Sorrow (how it weakens Strahd)

The heart is a prop (`spires_heart_of_sorrow`, conversation `spires_heart:heart`). Learning what it is is optional:
Escher sells it (a promise, gold, or Persuasion 15; Intimidation 14 works but turns him hostile, a failure starts a
fight), Pidlwick points at it, Arcana 15 at the heart, or a cleric listens to it (no roll). Striking it brings the
tower's guardians up the stair (`heart_guardians`); with them down, the next blow breaks it (no roll, ten minutes of
work): **`heart_of_sorrow_shattered`** is set and quest `the_heart_of_sorrow` reaches `shattered`. Then Strahd's
test (§4).

**What the flag does in the final battle (request to P6-01 / P6-02):** while `heart_of_sorrow_shattered` is unset,
Strahd fights every final battle and the coffin fight with the heart's ward, 50 extra hit points that are lost first
(simplest: 50 Temporary Hit Points when the fight starts; the book's heart absorbs his damage up to its own 50 HP).
Suggested data on his stat block: `"ward": {"hp": 50, "unless": "flag.heart_of_sorrow_shattered", "name": "Heart of
Sorrow"}`. Strahd's parley (P6-03) may read the flag for a line ("You broke something of mine"). In this package the
flag is read by the heart room's Narrator, Escher, Pidlwick and the banter.

## 7. Choices and consequences

| Choice | Where | Options | Flags |
|---|---|---|---|
| Pidlwick II | grand landing | take him (cards, or his key returned), refuse him, learn what he did (Insight 14, the portrait, Escher) | `pidlwick_met`, `pidlwick_truth_known`, `pidlwick_wary` (Insight failed: he won't talk about it again), `pidlwick_refused`, `join`, `find_the_ally` |
| Escher's price | his suite | a promise to leave his door open, 100 gp (200 after a failed Persuasion), Persuasion, Intimidation, a fight | `escher_bargain`, `escher_slighted`, `escher_threatened`, `escher_fight_won`, `heart_of_sorrow_known` |
| The heart | top of the tower | shatter it or leave it | `heart_guardians_beaten`, `heart_of_sorrow_shattered`, `strahd_heart_tested` |
| The ravens | roost | befriend, feed, calm, or fight | `roost_ravens_calm`, `roost_swarm_cleared` |

## 8. NPCs, flags, quests

- NPCs: `escher`, `pidlwick_ii` (data/npcs/, docs/voice/). Strahd's existing NPC isn't used as a speaker here.
- Flags: data/flags/castle_ravenloft_spires.json. Read from other packages: `keepers_allied` (Wizard of Wines),
  `raven_fed`, `raven_harmed` (Svalich road), `blinsky_met` (Vallaki), `guest:ireena`, `tarokka.ally.npc`,
  `treasure_at:`, `quest.strahds_lair`, `final_room:` (engine).
- Quests: `the_heart_of_sorrow` (heard → found → shattered), `the_jesters_key` (asked → found → returned).
  `find_the_ally` (`found` / `lost`) for Pidlwick II.

## 9. Loot (story items only; ADR 0012 scatters the rest)

| Container | Map | Contents |
|---|---|---|
| `spires_closet_cupboard` (hidden closet) | spires | 2 lamps, oil 3, candles 6, potion of healing, 40 gp |
| `spires_keeper_trunk` | rooms | rope, 2 vials, 30 gp |
| `spires_stillroom_cabinet` | rooms | 2 potions of healing, 2 alchemist's fire, acid, 3 vials |
| `spires_witch_shelf` | rooms | herbalism kit, basic poison, 4 candles, 25 gp |
| `spires_escher_dressing` | rooms | perfume, fine clothes, 180 gp |
| `spires_hollow_guardian` | roofs | 60 gp (old coins); the Tarokka treasure when the reading puts one here |
| `spires_great_nest` | roost | 35 gp of bright odds and ends, a mirror; the Tarokka treasure when the reading puts one here |

Escher's promise pays 150 gp (his ring).

## 10. Monsters needed

None beyond the ids P6-02 is writing: `strahd_von_zarovich`, `pidlwick_ii`, `strahds_animated_armor`,
`helmed_horror`, `barovian_witch`, `black_pudding`. Optional: a `heart_of_sorrow` object stat block (AC 15, 50 HP)
if the engine ever lets the party strike the heart during the final battle.

## 11. Props needed (nearest catalog model used now)

- The Heart of Sorrow: a man-sized crystal heart on chains, red light inside (`cage_hanging`); its shards
  (`glass_ring`).
- A witches' cauldron on a fire (`brazier_green`).
- Gargoyle statues on a parapet (`statue_knight`); the hollow one (`statue_knight`).
- Bat perches (`perch`); ravens' nests on beams (`roc_nest`); a great nest (`roc_nest`).
- A portrait of a jester in bells (`painting`).
- Four glass vessels on stands (`cabinet_glass`).
- A roof hatch and ladder (stair pieces), crenellated parapets (walls), a slate roof (texture `village/roof_slate`).

## 12. Critical path (story bot)

Start: `_start("castle_ravenloft_spires", 10)` at spawn `from_gates` (or arrive from the main floor).

1. **Pidlwick II.** Walk up the lower turns to the grand landing (any cell near (16, 3)); he approaches and speaks
   (or `talk("pidlwick_ii")`). Prefer "Madam Eva's cards showed us a clockwork jester." then "Come with us." →
   `guest:pidlwick_ii`, `find_the_ally == found`.
2. **The heart (enemy room).** Walk to the high landing via the upper turns (`spires_stair_watch` starts there; the
   step at (29, 7) is a trap: walk (28, 7) or (30, 7)), then the stair `up_to_heart` (12, 18). In the heart map,
   step into `spires_heart_chamber` (e.g. (8, 11)): with the marionette reading and `strahds_lair` foretold the final
   battle starts. Otherwise `use` the heart (8, 6) → "Strike it." → `heart_guardians` → `use` again → "Strike it." →
   `heart_of_sorrow_shattered`; `heart_strahd_test` follows at once (rest below first: Strahd strikes for one
   round and leaves).
3. **North tower peak.** From the high landing take `to_rooms` (24, 20); in the rooms, through the door (23, 6) to
   the ladder `up_to_roofs` (25, 2); on the roofs walk the walkway north to the keep roof, then the bridge east
   (rows 5 and 6) onto the peak (`peak_guardians`), then open `spires_hollow_guardian` (31, 3).
4. **Ravens' roost.** On the roofs, `hatch_to_roost` (4, 4). In the roost, `use` the ravens (8, 3) and prefer
   "Scatter some food", the Keepers' option, or Animal Handling; then open `spires_great_nest` (15, 6). Without
   calming them, the first open starts `roost_swarm`; win and open again.

Expect: `treasure_found_*` for any treasure the reading put at the two places.

## 13. Files

- Doc: docs/regions/castle_ravenloft_spires.md (this file); task docs/tasks/P6-06.md
- Locations: data/locations/castle_ravenloft_spires.json, castle_ravenloft_spires_heart.json,
  castle_ravenloft_spires_rooms.json, castle_ravenloft_spires_roofs.json, castle_ravenloft_spires_roost.json
- NPCs: data/npcs/escher.json, data/npcs/pidlwick_ii.json; voice docs/voice/escher.md, docs/voice/pidlwick_ii.md
- Quests: data/quests/the_heart_of_sorrow.json, data/quests/the_jesters_key.json
- Flags: data/flags/castle_ravenloft_spires.json
- Dialogue: narrative/castle_ravenloft/spires_pidlwick.dialogue, spires_escher.dialogue, spires_heart.dialogue,
  spires_roost.dialogue; narrative/narrator/castle_ravenloft_spires.dialogue;
  narrative/banter/castle_ravenloft_spires.dialogue
