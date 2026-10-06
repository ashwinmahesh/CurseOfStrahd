# Region design: Death House (Phase 3)

Plan §6 row 1 (second half). Party levels 1 to 3: level 1 on arrival, **level 2 when the party finds the stair hidden
in the walls**, **level 3 when the house is done with them** (the altar sacrifice, or breaking out after a refusal).
Source: *Curse of Strahd*, appendix B (Death House), retold in our own words: no read-aloud text, letters or journals
are reproduced; every document in the game is our own paraphrase. Owner: the Into the Mists / Death House narrative
designer. The data and dialogue files in §12 are the source of truth for exact text.

## 1. What this region is for

The tutorial dungeon, and the first real choice of the campaign. Death House teaches exploration (doors, locks,
traps, searching, secret doors, reading), conversation with checks, and combat on the same grid, while establishing
that Barovia rewards curiosity with dread. It ends with the plan's headline choice for this region: **sacrifice or
refuse at the altar**, and its second axis: **how much lore is uncovered**, which changes how the ending plays.

Tone: scary first (plan §5.7). Humor only through character, and thinly: Tamsin's patter getting quieter, Silvain's
pedantry under pressure, Hedda's calm. The nursemaid, the children's truth and the altar are played straight.

## 2. The story the house tells (in our words)

Gustav and Elisabeth Durst, a wealthy couple, founded a cult in their cellars hoping the lord in the castle would
reward them with eternal life. Their creed: one must die, that the rest may live forever. They lured travelers in,
gave them to the altar, and fed what was left to a shambling mound they kept in a heap of refuse below the house:
Lorghoth the Decayer. Gustav fathered a son, Walter, on the household's nursemaid; Elisabeth gave the newborn to the
altar as the cult's "first gift". The nursemaid followed the baby down and was killed. Strahd answered the cult with a
letter declining their devotion. The Dursts locked their children, Rose and Thorn, in the attic "so the robed people
wouldn't see them", and never went back up. The children starved. The cult rotted into ghouls and shades; the Dursts
became a ghast and a ghoul still sitting at supper. The house itself, hungry, now shows illusions of Rose and Thorn in
the road to lure new guests inside.

## 3. Layout and scenes

Six maps (data/locations/), joined by exits. Exterior: Death House's lot is part of `village_of_barovia` (the Village
owner's map): its `death_house_door` exit leads to `death_house_ground` spawn `from_village`; Death House's front door
and the escape window lead to `village_of_barovia` spawn `from_death_house`. The children's plea happens on
`into_the_mists_road` (docs/regions/into_the_mists.md).

| Map (size, light, rest) | Areas (`enter:` triggers) | Contents |
|---|---|---|
| `death_house_ground` (28x19, dim, risky) | `dh_foyer`, `dh_cloakroom`, `dh_main_hall`, `dh_den`, `dh_kitchen`, `dh_pantry`, `dh_dining_room` | Family portrait (the children from the road, decades ago), the burning lamp, the Den of Wolves (trophies, locked hunting cabinet: light crossbow), dumbwaiter, set dinner table, a lantern hidden behind the cloakroom coats (search 12). After a refusal: the front door is brick, the chandelier falls, the hall's weapons attack, and the dining room's tall window is the only way out. Mother's emergency purse under the bottom stair appears once the children are at rest. |
| `death_house_upper` (28x17, dim, risky) | `dh_upper_hall`, `dh_library`, `dh_secret_study`, `dh_servants_room`, `dh_conservatory` | Ancestor portraits, the stopped clock, a valley history (codex), a bookcase that is a secret door (DC 13; the library's narration points at it), the secret study (Strahd's letter, the deeds with the windmill, the cult's pamphlet, a chest with a scroll), the harpsichord with the nursemaid's lullaby. Rotten floorboard. After a refusal: blades in the wainscot. |
| `death_house_third` (28x17, dim, risky) | `dh_attic_stair`, `dh_attic_landing`, `dh_third_hall`, `dh_master_suite`, `dh_bathroom`, `dh_nursemaid_room`, `dh_nursery` | The animated black armor on the landing in front of the attic stair, the master suite, the black bath, the nursemaid's room (Gustav's letters to her: Walter), and the nursery, whose doorway the nursemaid's specter guards. After a refusal: soot from every hearth, and the floor's blades. |
| `death_house_attic` (26x16, dim, risky) | `dh_attic_hall`, `dh_spare_bedroom`, `dh_storage_room`, `dh_childrens_room` | The broom in the storage room, the spare bedroom with a warm alcove by the chimney (the hidden stair: search DC 14, or the dollhouse, or Rose), and the locked children's room (lock DC 12): Rose and Thorn's ghosts, the toy chest with their bones, the dollhouse. After a refusal: a falling beam. |
| `death_house_dungeon_1` (30x23, dark, risky) | `dh_stair_foot`, `dh_family_crypts`, `dh_crypt_passage`, `dh_cult_refectory`, `dh_cult_dormitory`, `dh_durst_chambers`, `dh_reliquary`, `dh_well_chamber`, `dh_lower_stair` | The family crypts (the children's empty crypts, Walter's unmarked one), a covered pit, the refectory with the cult's ledger, the dormitory of ghoul cultists, the Dursts at supper, the locked reliquary of victims' keepsakes (shadows), the well chamber (grick), the stair down. |
| `death_house_dungeon_2` (30x22, dark, **no rest**) | `dh_lower_landing`, `dh_flooded_passage`, `dh_robing_room`, `dh_winch_room`, `dh_ritual_antechamber`, `dh_ritual_chamber` | The flooded passage (rat swarms), the robing room, the winch that raises the portcullis, the antechamber, and the ritual chamber: the altar, the braziers, the shades beside the altar, and the breathing heap where Lorghoth sleeps. |

Exits: ground `stairs_up` [17,3] ↔ upper `stairs_down` [17,3]; upper `stairs_up` [17,12] ↔ third `stairs_down`
[17,12]; third `attic_stairs` [15,1] ↔ attic `stairs_down` [1,6]; attic `secret_stair_down` [7,2] (the alcove, open
once `death_house_secret_stair_found`) ↔ dungeon 1 `secret_stair_up` [3,1]; dungeon 1 `stairs_down` [27,18] ↔
dungeon 2 `stairs_up` [3,1]. Every exit cell sits on floor in a nook beside its stairs so nobody walks onto it by
accident.

### Scene flow

1. **The plea** (road). Rose and Thorn beg the party to save Walter from the monster in the basement. Insight 13 or
   Arcana 14 sees the illusion. Promise, refuse, pray, ask questions.
2. **The house is too tidy** (ground floor). The door clicks shut; the children are gone from the road. The family
   portrait shows the same children, decades old. No basement door anywhere.
3. **Upstairs** (second floor). The bookcase that opens: Strahd's letter, the deeds, the cult's pamphlet. The
   harpsichord's lullaby.
4. **The family floor** (third). The black armor wakes when the party nears the attic stair (fight). The nursemaid
   bars the nursery: calm her with the lullaby, words or prayer, or fight her. Her letters name Walter.
5. **The attic.** The broom. The locked children's room: Rose and Thorn's ghosts, who don't know they are dead. Tell
   them or not; let them ride along inside the party; carry their bones. The dollhouse shows the hidden stair (and,
   on a close look, the altar and the sleeping heap). **Finding the stair: level 2.**
6. **Below** (dungeon 1). The crypts (lay the children to rest: they say goodbye and tell you where Mother hid her
   purse). The ledger of victims. Ghoul cultists. The grick. The Dursts at supper (talk, then fight). The reliquary.
7. **The altar** (dungeon 2). Rats in the black water; the winch and the portcullis; the shades: *one must die*.
8. **The ending.** Sacrifice: the house is satisfied, every lock turns, **level 3**, walk out. Refuse: Lorghoth wakes;
   run (Dexterity, or fight the shades) or stand and fight; the house turns on the party floor by floor; the front
   door is brick; break out through the closing dining room window (**level 3**).

## 4. NPCs (voice bibles in docs/voice/)

| id | Name | Where | Wants | Fears | Voice in a line | Stat block |
|---|---|---|---|---|---|---|
| `rose` | Rose (Rosavalda Durst) | road (illusion); attic (ghost); crypt | her mother to come back; to be a good big sister | the basement, being forgotten | prim and bossy, quotes Mother | — |
| `thorn` | Thorn (Thornboldt Durst) | road (illusion); attic (ghost) | not to be left again | grown-ups who say they'll be right back | three-word truths at the worst moment | — |
| `durst_nursemaid` | The Nursemaid | third floor, nursery doorway | Walter, his lullaby, then rest | the robed ones | soft two-in-the-morning voice | specter |
| `gustav_durst` | Gustav Durst | dungeon 1 supper table | guests; to be noticed by Strahd | being ordinary | the host who never stops hosting | ghast |
| `elisabeth_durst` | Elisabeth Durst | dungeon 1 supper table | to be proven right | that the gift was wasted | sweet, low, mocking society voice | ghoul |
| `cult_shades` | The Shades | dungeon 2, beside the altar | one death on the altar | being known; the dawn | many voices, one refrain | — |
| `lorghoth` | Lorghoth the Decayer | dungeon 2 refuse heap | to wake and eat | — | says its own name, like a drain | shambling_mound |

The pregens interject throughout (name: selectors) and every major beat has a class/species/background line for
custom parties (guarded with `if not name:<pregen>` where the pregen also speaks).

## 5. Quests

- `death_house` (Death House, giver `rose`): `plea` → `secret_stair` → `the_altar` → `escaped_refused` (success) or
  `escaped_sacrificed` (success).
- `rose_and_thorn` (Rest for Rose and Thorn, giver `rose`): `met` → `remains` → `at_rest` (success), or `left_behind`
  (failure; set when the party meets the children's illusion in the road again after leaving the house).

## 6. Encounters (2024 DMG budgets for four characters)

Level 1 budget: Low 200 / Moderate 300 / High 400. Level 2: Low 400 / Moderate 600 / High 800.

| Map | id | Trigger | Monsters | XP | Level | Difficulty |
|---|---|---|---|---|---|---|
| third | `armor_guardian` | enter `dh_attic_landing` | animated armor ("Black Armor") | 200 | 1 | Low |
| third | `nursery_specter` | dialogue (fail or attack) | specter ("The Nursemaid") | 200 | 1 | Low (avoidable) |
| attic | `storage_broom` | enter `dh_storage_room` | broom of animated attack | 50 | 1 | Trivial |
| dungeon 1 | `dormitory_ghouls` | enter `dh_cult_dormitory` | 3 ghouls | 600 | 2 | Moderate (optional room) |
| dungeon 1 | `well_grick` | enter `dh_well_chamber` | grick | 450 | 2 | Low (on the path) |
| dungeon 1 | `reliquary_shadows` | enter `dh_reliquary` | 2 shadows | 200 | 2 | Below Low (optional, locked) |
| dungeon 1 | `durst_reunion` / `durst_reunion_shaken` | dialogue | ghast (Gustav) + ghoul (Elisabeth) | 650 | 2 | Moderate; the "shaken" version surprises the Dursts |
| dungeon 2 | `drowned_rats` | enter `dh_flooded_passage` | 2 swarms of rats | 100 | 2 | Trivial |
| dungeon 2 | `shades_harry` | dialogue (failed run) | 2 shadows | 200 | 2 | Below Low |
| dungeon 2 | `lorghoth_rises` / `lorghoth_rises_late` | dialogue ("stand and fight") | shambling mound | 1,800 | 2 | **Far beyond High, on purpose.** Only by choice; "run" avoids it. `_late` starts it 4 squares farther away. |
| ground | `ground_escape_weapons` | enter `dh_main_hall` after a refusal | 2 animated flying swords + broom | 150 | 2 | Trivial (pressure, not attrition) |
| third | `third_escape_swords` | enter `dh_third_hall` after a refusal | 3 animated flying swords | 150 | 2 | Trivial |
| ground | `window_last_guard` | dialogue (failed window check) | 2 animated flying swords | 100 | 2 | Trivial |

Critical path at level 1: the armor (200), plus the nursemaid (200, avoidable) and the broom (50, optional). Critical
path at level 2: the grick (450) and the rats (100); the ghouls, the Dursts and the shadows sit in side rooms off the
route (stair foot, crypts, refectory, well chamber, lower stair), so a cautious party can skip them.

Traps (fair DCs; damage sized for level 1 above ground and level 2 below):

| Map | id | Cells | Detect / disarm | Save | Damage | When |
|---|---|---|---|---|---|---|
| upper | `rotten_floorboard` | [12,8] | 11 / 11 | Dex 11 | 1d6 bludgeoning | always |
| attic | `attic_floorboards` | [10,7] | 12 / 12 | Dex 11 | 1d6 bludgeoning | always |
| dungeon 1 | `passage_pit` | [13,8] | 13 / 13 | Dex 12 | 2d6 bludgeoning | always |
| ground | `hall_chandelier` | [13,7] [14,7] | 12 / — | Dex 12 | 2d6 bludgeoning | after a refusal |
| upper | `hall_wall_blades` | [16,7] [17,7] | 13 / 13 | Dex 12 | 2d6 slashing | after a refusal |
| third | `soot_cloud` | [15,9] [16,9] | 12 / — | Con 12 | 1d6 poison + Poisoned | after a refusal |
| attic | `attic_beams` | [3,6] [3,7] | 12 / 13 | Dex 12 | 2d6 bludgeoning | after a refusal |

## 7. Choices and their consequences

```
Road: the plea ──── promise (death_house_promised_walter) ──► the shades throw it back at the altar; Village may read
   │          └─── see through it (Insight/Arcana) ─────────► lore +1
Second floor: the harpsichord (Performance 11 / Investigation 13, one try) ──► death_house_knows_lullaby
Third floor: the nursemaid ── lullaby ─────────────► calmed, no fight, Walter's truth (lore)
                          ├─ Persuasion 14 / cleric Religion 13 ─► calmed or fight
                          └─ attack ──────────────► fight (specter, 200 XP)
Attic: Rose and Thorn ── tell gently (Persuasion 12 / cleric Religion 10) ─► they ask to go to their crypt
                      ├─ tell plainly, or leave them ─► Thorn tries to possess (Charisma 12) ─► riding along
                      ├─ invite them along ──────────► riding along (death_house_children_riding)
                      └─ carry the bones (toy chest) ─► lay them to rest in the crypt ─► at peace, purse revealed,
                                                       the road lure ends; the Dursts can be shaken by the news
Attic: the dollhouse (Investigation 12) ── close look ─► the altar and the heap (lore)
Dungeon 1: the Dursts ── Intimidation 13 / Persuasion 15 ─► confession (lore) then fight
                      └─ "your children are at rest" ─► fight with the Dursts surprised
THE ALTAR ── lore >= 4, or denounce (Religion 14, one try) ─► head start
           ├─ REFUSE ─► Lorghoth wakes ─┬─ run: head start = clean; else Dexterity 12 or fight 2 shadows
           │                            └─ stand and fight: Lorghoth (1,800 XP; late version with a head start)
           │           then the house turns: brick front door, traps, animated weapons, the closing window
           │           (Athletics/Acrobatics 12, failure = one more fight) ─► level 3, out to the village lot
           └─ SACRIFICE ─► the player chooses a party member, who dies ─► the house is satisfied, level 3, walk out
```

Downstream (for later regions; the Village owner already reads these):
- **`death_house_sacrificed` vs `death_house_refused`** is the region's lasting mark. Suggested reactions: Donavich
  smells it on them; Ismark's first impression; Strahd's first words ("You fed my house" / "You refused my house");
  Hedda (if alive) carries it in banter for the campaign; the epilogue slides.
- **`death_house_children_at_rest`**: the lure in the road is gone; the house is "only a house".
- **`death_house_lorghoth_slain`**: a story the party can tell (and Strahd may have heard).
- **`death_house_lore`** (0-7) and the individual lore flags (`death_house_read_strahd_letter`,
  `death_house_learned_walter`, `death_house_dursts_confessed`...): Silvain and Strahd scenes; Ilse's letter.
- **`death_house_found_deeds`**: the Dursts held the deed to the windmill on the Old Svalich Road (Old Bonegrinder).
- **`death_house_promised_walter`**: a promise the party could not keep.

## 8. Milestones

- **Level 2**: `death_house/attic:milestone`, reached from every way of finding the hidden stair (dollhouse, Rose,
  the chimney seam search). Guarded by `death_house_milestone_dungeon` so it fires once.
- **Level 3**: in `death_house/altar:sacrifice_done` (sacrifice) or `death_house/escape:window_through` (refusal). The
  two are exclusive.

## 9. The house turns (after a refusal)

Everything below is gated on `flag.death_house_refused` (and most on `not flag.death_house_completed`):
- Every floor's `enter:` line and the rooms on the escape path switch to hostile variants (narrator, cooldown 30).
- Traps appear: falling beam (attic), soot (third), wall blades (upper), chandelier (ground).
- Animated weapons attack on the third floor and in the main hall.
- The front door exit is barred with brick (`locked_text`), and a "bricked doorway" prop appears.
- The dining room's tall window becomes the only way out: its prop runs `escape:window` (Athletics/Acrobatics 12;
  failure brings two more flying blades first). Success sets `death_house_completed` and opens the window exit.
- Any ghosts riding with the party are torn back into the house at the threshold.

## 10. Flags (data/flags/death_house.json)

Every flag is registered, set and read. "V" = the Village of Barovia reads it already; "P4+" = later phases should.

| Flag | Type | Set by | Read by |
|---|---|---|---|
| `death_house_heard_plea` | bool | rose_thorn | rose_thorn, rose_thorn_ghosts, house (portrait), narrator |
| `death_house_promised_walter` | bool | rose_thorn | altar; V/P4+ |
| `death_house_lure_tested` | bool | rose_thorn | rose_thorn |
| `death_house_saw_through_lure` | bool | rose_thorn, rose_thorn_ghosts, house | rose_thorn, rose_thorn_ghosts, house, banter |
| `death_house_read_strahd_letter` | bool | house | house, banter; P4+ |
| `death_house_found_deeds` | bool | house | banter; P5 (Old Bonegrinder) |
| `death_house_harpsichord_played` | bool | house | house |
| `death_house_knows_lullaby` | bool | house | nursemaid, dungeon (Walter's crypt), house |
| `death_house_nursemaid_calmed` | bool | nursemaid | map (nursemaid NPC), narrator |
| `death_house_nursemaid_destroyed` | bool | encounter `nursery_specter` | map (nursemaid NPC) |
| `death_house_learned_walter` | bool | house, nursemaid, dursts, dungeon | house, nursemaid, dursts, dungeon |
| `death_house_armor_destroyed` | bool | encounter `armor_guardian` | encounter `when`, narrator |
| `death_house_broom_destroyed` | bool | encounter `storage_broom` | encounter `when` |
| `death_house_children_met` | bool | rose_thorn_ghosts | rose_thorn_ghosts, attic, rose_thorn (return) |
| `death_house_children_truth` | bool | rose_thorn_ghosts, attic | rose_thorn_ghosts, attic, dursts, banter |
| `death_house_children_riding` | bool | rose_thorn_ghosts (cleared by dungeon, escape, altar) | map (ghost NPCs), attic, dungeon, escape, altar, narrator, banter; V |
| `death_house_children_remains_taken` | bool | attic | attic, dungeon, rose_thorn_ghosts |
| `death_house_children_at_rest` | bool | dungeon | map (cache, NPCs), attic, dursts, narrator; V |
| `death_house_secret_stair_found` | bool | attic | attic, map (alcove exit) |
| `death_house_milestone_dungeon` | bool | attic | attic |
| `death_house_dollhouse_altar_seen` | bool | attic | attic, altar |
| `death_house_read_cult_ledger` | bool | dungeon | dungeon |
| `death_house_dursts_confessed` | bool | dursts | dursts; P4+ |
| `death_house_dursts_destroyed` | bool | encounters `durst_reunion(_shaken)` | map (Durst NPCs), dungeon |
| `death_house_ghouls_destroyed` | bool | encounter `dormitory_ghouls` | encounter `when` |
| `death_house_grick_slain` | bool | encounter `well_grick` | encounter `when` |
| `death_house_shadows_destroyed` | bool | encounter `reliquary_shadows` | encounter `when` |
| `death_house_rats_scattered` | bool | encounter `drowned_rats` | encounter `when` |
| `death_house_lore` | int | `+= 1` once per discovery (7 sources) | altar (>= 4); V/P4+ |
| `death_house_portcullis_raised` | bool | lever `winch_lever` | door `portcullis`, narrator |
| `death_house_altar_denounced` | bool | altar | altar |
| `death_house_head_start` | bool | altar | altar |
| `death_house_refused` | bool | altar | maps (traps, exits, encounters, props), narrator, banter; V |
| `death_house_sacrificed` | bool | altar | narrator, dungeon, banter; V |
| `death_house_lorghoth_slain` | bool | encounters `lorghoth_rises(_late)` | escape, narrator, banter; P4+ |
| `death_house_window_attempted` | bool | escape | escape |
| `death_house_completed` | bool | altar (sacrifice), escape (window) | maps (exits, NPCs, props), narrator; V |

Lore sources (each adds 1 to `death_house_lore` once): seeing through the lure (road, portrait or ghosts), Strahd's
letter, Walter's truth (letters, nursemaid, Dursts or ledger), the children's deaths (ghosts or bones), the dollhouse
altar, the cult's ledger, the Dursts' confession.

## 11. Banter and narration

- Narrator: narrative/narrator/death_house.dialogue covers every area, prop, search, trap (found, triggered,
  disarmed) and open door or chest of note, plus generic checks, rests, a dream and combat lines scoped to "inside the
  house" (`visited:death_house_ground and not flag.death_house_completed`).
- Banter: narrative/banter/death_house.dialogue, 19 exchanges gated by name, class, species, background and story
  flags. Each node opens with an `if` gate (see "Engine needs").

## 12. Files

- Voice: docs/voice/{rose, thorn, gustav_durst, elisabeth_durst, durst_nursemaid, cult_shades}.md; the pregens'
  docs/voice/{ilse_varga, tamsin_tealeaf, hedda_ironvow, silvain_aster}.md; docs/voice/narrator.md
- NPCs: data/npcs/{rose, thorn, gustav_durst, elisabeth_durst, durst_nursemaid, cult_shades, lorghoth}.json
- Quests: data/quests/{death_house, rose_and_thorn}.json
- Flags: data/flags/death_house.json
- Locations: data/locations/{death_house_ground, death_house_upper, death_house_third, death_house_attic,
  death_house_dungeon_1, death_house_dungeon_2}.json
- Dialogue: narrative/death_house/{rose_thorn, rose_thorn_ghosts, house, nursemaid, attic, dungeon, dursts, altar,
  escape}.dialogue; narrative/narrator/death_house.dialogue; narrative/banter/death_house.dialogue

## 13. Engine needs the format can't express yet

1. **Sacrifice picks a victim.** When `death_house_sacrificed` turns true in `altar:sacrifice_done`, the game should
   pause the conversation, show the living party members, and kill the one the player picks (permanent death, no
   death saves). Suggested statement: `sacrifice` (or `kill choose`). Until then the flag is set and nobody dies.
   Lines after that point deliberately avoid pregen interjections, since the speaker may be the dead.
2. **NPC `when` after a conversation or fight.** NPC tokens are built when a map loads, but several NPCs stand in a
   doorway or a narrows and must vanish as soon as their scene resolves: the wolves (`mists_wolves_resolved`), the
   nursemaid (`death_house_nursemaid_calmed` / `_destroyed`), the Dursts (`death_house_dursts_destroyed`), the ghost
   children (`death_house_children_riding`). Re-check every NPC's `when` after each conversation and each fight.
   Also: when a conversation with an NPC that has a `monster` ends in `combat`, hide that NPC's token for the fight
   (the encounter places its own monster on a neighboring square).
3. **Narrator variants across files.** `rest:short`, `rest:long` (and any generic key) are defined in both
   death_house and village_of_barovia narrator files; the narrator currently keeps only the last file loaded. Merging
   variants across files makes both work (mine are all conditioned to "inside the house", so they win there and the
   village's plain lines play everywhere else).
4. **Banter selection.** Banter nodes open with an `if` gate; the game should play one eligible node (gate true) at
   a quiet moment while exploring the region, once each.
5. **`dream:death_house`.** Written for a long rest inside the house; nothing sends `dream:` triggers yet.
6. **Prop-specific check triggers.** `check:perception:<prop>:success|failure` lines exist for the search props; the
   engine currently sends only the generic `check:perception:success|failure`.

## 14. Notes and open questions

- The book's sacrifice offers no named victim. Here the victim is one of the party, chosen by the player; it is the
  darkest option in Phase 3 and intentionally costly. If the owner wants a softer version, an alternative is a
  captive in the dungeon (new NPC) — a larger change to the source.
- Lorghoth is ~2.25x the High budget at level 2. It is never forced: refusing offers "run" (clean with a head start,
  else Dexterity 12 or a small shadow fight) or "stand and fight". If playtests show players choosing to fight and
  dying, add a "flee by leaving the map" combat rule or soften the mound.
- Level 3 on the sacrifice path is granted at the altar (the house releases the party there), not at the door.
