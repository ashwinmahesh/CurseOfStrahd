# Castle Ravenloft part `catacombs`: the crypts and the tombs (Phase 6, P6-08)

Plan §10 Phase 6; ADR 0014 (castle, Strahd, endings); ADR 0011 (treasure spots). The overview is
docs/regions/castle_ravenloft.md. Source: *Curse of Strahd* chapter 4, areas K84 to K88, retold in our own words; the
data and dialogue files in §12 are the source of truth for exact text. Party level 9 to 11 (fights tuned for four at
level 10 with one guest); the castle gives no milestone.

## 1. What this part is for

Under the castle the house of von Zarovich keeps its dead: generals, stewards, a court conjurer, a jester, a famous
champion, the lord's black horse, and below them the old tombs where Strahd's murdered brother and his parents lie.
At the very bottom is the only place in the valley where Strahd can be ended: his coffin.

The part has three jobs:

- **Six Tarokka places and four enemy rooms** (the overview's table): four crypt treasures in the catacombs, the
  treasures and Strahd's final battle in three tombs, and the horseman's battle among the crypts.
- **The coffin.** Every road to Strahd's destruction ends here (ADR 0014): beaten anywhere else he turns to mist and
  goes to ground in his coffin (`strahd_in_coffin`), and the party comes down the black stair to finish him with the
  stake (`strahd_destroyed`, quest `strahds_lair destroyed`, then `end_game`).
- **Ireena's story.** Sergei's tomb is the last place her past life can speak to her before the end.

Tone: the quiet after the castle's noise. The crypts are orderly, cold and almost tender; the horror is how long
everything here has waited. The coffin scene is the campaign's last conversation and has no joke in it until he
makes one.

## 2. Maps (data/locations/)

Three maps, all `dungeon` theme, dark. Area, prop, container, door and trap ids carry the prefix `cat_` (Narrator keys
are global), except the three tomb areas, which are named by their room ids so that the final battles' trigger
areas are literally the rooms.

| Map | Book | Size | Areas | What is there |
|---|---|---|---|---|
| `castle_ravenloft_catacombs` (entry) | K84 | 44 x 31 | `cat_upper_gallery`, `cat_lower_gallery`, `cat_mad_dog_crypt`, `cat_jester_crypt`, `cat_conjurer_crypt`, `cat_stewards_crypt`, `cat_hidden_ossuary`, `cat_hall_of_names`, `cat_beucephalus_crypt`, `cat_gargoyle_tomb`, `cat_sleepers_crypt` | Two galleries joined by three aisles of crypts behind iron crypt gates (fifteen doors, one chained shut, one secret). The hall of names in the middle, with a statue of the lord and the black stair down to his tomb. The Mad Dog's crypt (trap), the conjurer's crypt (glyph, the wand and the sealed reliquary), the jester's crypt, the champion's tomb and its gargoyles, the sleepers' crypt (vampire spawn), the forgotten ossuary behind a secret door (DC 16), the black horse Beucephalus's stall-crypt (the horseman's room). |
| `castle_ravenloft_catacombs_tombs` | K85, K87, K88 | 28 x 27 | `cat_tombs_vestibule`, `castle_ravenloft_sergeis_tomb`, `cat_guardians_hall`, `castle_ravenloft_tomb_of_barov_and_ravenovia` | A vestibule at the foot of the stair; Sergei's white tomb with his sarcophagus and a basin of still water (K85); the guardians' hall, six stone knights, three of them not stone (K87); the royal vault, King Barov and Queen Ravenovia side by side on a dais (K88). |
| `castle_ravenloft_catacombs_strahd` | K86 | 23 x 21 | `cat_black_stair`, `castle_ravenloft_strahds_tomb` | The foot of the black stair; the tomb: a stepped dais, the plain coffin on trestles, a statue of the young lord in armour, green braziers, an iron chest at the dais foot. |

### Ways in and out (the seams; overview table)

| Exit | Cell | To | Spawn |
|---|---|---|---|
| `cat_stairs_to_main_floor` (catacombs) | (3, 1) | `castle_ravenloft_main_floor` | `from_catacombs` |
| `cat_stairs_to_larders` (catacombs) | (40, 1) | `castle_ravenloft_larders` | `from_catacombs` |
| `cat_down_to_tombs` (catacombs) | (5, 29) | `castle_ravenloft_catacombs_tombs` | `from_catacombs` |
| `cat_black_stair_down` (catacombs) | (18, 15) | `castle_ravenloft_catacombs_strahd` | `from_catacombs` |
| `cat_tombs_up` (tombs) | (16, 1) | `castle_ravenloft_catacombs` | `from_tombs` |
| `cat_black_stair_up` (Strahd's tomb) | (11, 1) | `castle_ravenloft_catacombs` | `from_strahd` |

Spawns on the entry map: `default` and `from_gates` (3, 3), `from_larders` (40, 3), `from_tombs` (5, 27),
`from_strahd` (18, 14). The gates part's `crypt_stairs_down` arrives at `from_gates`; the larders part's way down
should arrive at `from_larders`.

## 3. Tarokka places (treasure spots) and enemy rooms

| Place / room | Map | Spot | Enemy room encounter |
|---|---|---|---|
| `castle_ravenloft_catacombs` (horseman) | catacombs | | `cat_horseman_final`, area `cat_beucephalus_crypt` |
| `castle_ravenloft_crypt_of_the_mad_dog` | catacombs | container `cat_mad_dog_sarcophagus` (2, 9) | |
| `castle_ravenloft_crypt_of_the_wizard` | catacombs | container `cat_conjurer_reliquary` (5, 23), key `arcane_focus_wand` | |
| `castle_ravenloft_gargoyle_tomb` | catacombs | container `cat_champion_slab` (39, 9) | |
| `castle_ravenloft_sergeis_tomb` (broken_one, innocent) | tombs | dialogue `castle_ravenloft/catacombs_sergei:take_treasure` | `cat_sergei_final` |
| `castle_ravenloft_tomb_of_barov_and_ravenovia` (ghost, raven) | tombs | container `cat_ravenovia_sarcophagus` (18, 22) | `cat_royal_final` |
| `castle_ravenloft_strahds_tomb` (darklord) | Strahd's tomb | container `cat_tomb_chest` (11, 16) | `cat_darklord_final` |

- **The Mad Dog** (book: General Kroval "Mad Dog" Grislek, a K84 crypt). The gate is chained (lock 15). A scything
  blade waits in front of the sarcophagus (`cat_mad_dog_blade`, detect 15, DEX 15, 4d10). The reading's treasure is
  under him, in the sarcophagus.
- **The conjurer** (the book's minor wizard in K84; name and details ours). A glyph in the threshold (DEX 15,
  4d8 lightning). He lies on a bier holding a plain wand; using the bier gives `arcane_focus_wand`. The sealed
  reliquary opens with that wand (its `key`), or by picking (DC 22), forcing or Knock: the wand is the key, but never
  the only one.
- **The champion** (the book's warrior watched by gargoyles; name ours). Six gargoyles crouch at the corners of the
  slab and wake when the party walks in (`cat_gargoyle_watch`). The treasure is on the slab.
- **Sergei's tomb.** The sarcophagus conversation shows the treasure in his stone hands and gives it over (`tarokka
  give castle_ravenloft_sergeis_tomb`).
- **The royal tomb.** "She has kept this for her son's enemies": the treasure is in Queen Ravenovia's sarcophagus.
- **Strahd's tomb.** The chest at the foot of his dais. The keepers fight (below) stands in front of it.

Every place is reachable without Strahd: the final battles only start in the room the reading names (the engine adds
`final_room`, `strahds_lair` foretold or later, not destroyed); each also has `when: not flag.strahd_in_coffin` so a
beaten Strahd never waits anywhere but his coffin.

## 4. Encounters (2024 DMG, four characters at level 10: Low 6,400 / Moderate 9,200 / High 12,400)

XP: Strahd 13,000; vampire spawn 1,800; Strahd's animated armor 2,300; helmed horror 1,100; Vladimir 2,900;
revenant 1,800; nightmare 700; gargoyle 450; dire wolf 200; specter 200; swarm of bats 50.

| id | Map, trigger | Who | XP | Notes |
|---|---|---|---|---|
| `cat_horseman_final` | catacombs, enter `cat_beucephalus_crypt` | Strahd, the nightmare Beucephalus, 2 swarms of bats | 13,800 High | `final_battle: castle_ravenloft_catacombs`, `lair` |
| `cat_sleepers` | catacombs, enter `cat_sleepers_crypt` | night: 3 vampire spawn; day: 2, surprised in their coffins | 5,400 / 3,600 | optional; `cat_sleepers_slain` |
| `cat_gargoyle_watch` | catacombs, enter `cat_gargoyle_tomb` | 6 gargoyles | 2,700 | guards a treasure place; `cat_gargoyles_slain` |
| `cat_sergei_final` | tombs, enter `castle_ravenloft_sergeis_tomb` | Strahd, 2 dire wolves, 2 swarms of bats | 13,500 High | `final_battle: castle_ravenloft_sergeis_tomb`, `lair` |
| `cat_guardians` | tombs, enter `cat_guardians_hall` | Strahd's animated armor, 2 helmed horrors | 4,500 | on the way to the royal tomb; `cat_guardians_stilled` |
| `cat_royal_final` | tombs, enter `castle_ravenloft_tomb_of_barov_and_ravenovia` | Strahd, 3 specters | 13,600 High | `final_battle: castle_ravenloft_tomb_of_barov_and_ravenovia`, `lair` |
| `cat_darklord_final` | Strahd's tomb, enter `castle_ravenloft_strahds_tomb` | Strahd, 2 vampire spawn | 16,600 High+ | `final_battle: castle_ravenloft_strahds_tomb`, `lair`; sets `cat_keepers_defeated` (the spawn are the keepers) |
| `cat_tomb_keepers` | Strahd's tomb, enter `castle_ravenloft_strahds_tomb` while `not flag.cat_keepers_defeated` | 2 vampire spawn, 3 swarms of bats | 3,750 | the short fight at the tomb while he rests (or is out); `cat_keepers_defeated` |
| `cat_daylight_waking` | Strahd's tomb, dialogue (the coffin by day) | Strahd, 2 swarms of bats | 13,100 High | `lair`; not a final battle (no parley) |
| `cat_oathbreakers` | Strahd's tomb, dialogue (the coffin, Vladimir's pact) | Vladimir Horngaard, 2 revenants | 6,500 Low | only if the party swore Vladimir's pact (Argynvostholt) and breaks it; `cat_oathbreakers_beaten` |

The darklord's room is the hardest on purpose ("where he is strongest"). Strahd appears outside a final battle only
in `cat_daylight_waking`, which is the owner's rule for finding him asleep by day (§5): a hard fight in his own lair,
not a free kill. No fight here uses `withdraw`.

## 5. Strahd's coffin (ADR 0014)

The coffin is the prop `cat_strahds_coffin` (11, 12), dialogue `castle_ravenloft/catacombs_coffin:coffin`:

1. **He is out** (night, never beaten): the coffin is empty earth. The party may pour holy water into it
   (`cat_coffin_hallowed`: when he comes home he lies in a bed that burns; a line in the stake scene remembers it).
2. **He is asleep** (`day`, not beaten): he lies in the coffin. "Drive the stake into his heart while he sleeps" (or
   draw the Sunsword over him) wakes him as the point touches: `combat cat_daylight_waking`. Dropped to 0 Hit Points
   he turns to mist and sinks into the coffin beside the fight (the engine's Misty Escape, `strahd_in_coffin`). So the
   party can never destroy him here before he has been beaten once, and finding him by day only buys a hard fight
   in his own lair.
3. **He rests** (`strahd_in_coffin`): entering the tomb first starts `cat_tomb_keepers` unless the keepers are
   already dead (the darklord battle killed them). Then the coffin: he lies grey and unable to move and talks. The
   party can let him speak (once: his last offer, refused by the party's lines), close the lid ("Not yet"), or end
   him: the stake; the stake in Ireena's hands (if she travels with the party); the Sunsword's light; the Holy
   Symbol's dawn. Each sets `cat_staked_by` (`party`, `ireena`, `sun`), then `the_end`: `set strahd_destroyed`,
   `quest strahds_lair destroyed`, the last lines (Ireena's promise to Sergei, the Order's knights), `end_game`.
4. **Vladimir's pact.** If the party swore Vladimir Horngaard's oath at Argynvostholt (`vladimir_pact`, not
   `vladimir_pact_broken`), he comes down the black stair before the killing blow: "Break him. Do not end him."
   The dragon's last words (`vladimir_last_words_known`, no roll) or Persuasion 18 move him aside
   (`cat_vladimir_stood_aside`); refusing, or failing the roll, breaks the oath (`vladimir_pact_broken`) and he fights
   (`cat_oathbreakers`). Closing the lid is always there.
5. **Destroyed already** (`strahd_destroyed` set by anything else): ash in the coffin, and `end_game`.

Where he ended the final battle doesn't matter: the darklord battle in this room ends with him sinking into the
coffin next to the party, and they use it straight away.

## 6. Ireena and Sergei (K85)

When Ireena travels with the party, the sarcophagus or the basin opens her scene first (once,
`cat_ireena_at_tomb`):

- She never saw the pool at Krezk: Sergei's face in the still water, "Tatyana", her first memory of him, and his
  word about a pool in the north where he can say more (`remembered`).
- She promised at the pool (`ireena_pool_choice == "promised"`): she tells his bones she is nearly done
  (`promised`); the stake scene remembers it.
- She chose herself at the pool (`stayed`): she says goodbye properly, to his bones this time, and he calls her
  Ireena (`farewell`).

The treasure and the inscription ("Beloved", and, scratched later by another hand, "Forgive me") come after. A
Religion 13 option lets a party member say the rites (`cat_sergei_rites_said`), which warms the room's Narrator line.

## 7. NPCs

No new NPCs. Speakers: `sergei_von_zarovich` (existing; seen only in still water, here the basin), `ireena`,
`strahd`, `vladimir_horngaard` (only with the pact). Beucephalus is the `nightmare` stat block with a name.

## 8. Flags (data/flags/castle_ravenloft_catacombs.json) and quests

| Flag | Type | Set by | Read by |
|---|---|---|---|
| `strahd_destroyed` | bool | coffin `the_end` (the stake) | coffin (`ashes`); the endings (P6-09) |
| `strahd_in_coffin` | bool | the engine (Misty Escape, P6-01); also `cat_daylight_waking`'s victory (he mists into the coffin beside the fight) | coffin, every final battle's `when`, Narrator, banter |
| `cat_staked_by` | string | coffin (`party`, `ireena`, `sun`) | coffin `the_end`; epilogues may read it |
| `cat_ireena_at_tomb` | string | Sergei's tomb (`remembered`, `promised`, `farewell`) | coffin, font, Narrator, banter; epilogues may read it |
| `cat_keepers_defeated` | bool | `cat_darklord_final`, `cat_tomb_keepers` | `cat_tomb_keepers` `when`, Narrator |
| `cat_coffin_hallowed` | bool | coffin (holy water) | coffin `resting` |
| `cat_last_words_heard` | bool | coffin | coffin (the option shows once) |
| `cat_vladimir_stood_aside` | bool | coffin (Vladimir moved) | coffin |
| `cat_oathbreakers_beaten` | bool | `cat_oathbreakers` | coffin `the_end` |
| `cat_sleepers_slain`, `cat_gargoyles_slain`, `cat_guardians_stilled` | bool | encounters | Narrator |
| `cat_mad_dog_blade_known` | bool | the trap (found or sprung) | Narrator |
| `cat_sergei_rites_said` | bool | Sergei's tomb | Narrator |

Read from other parts: `vladimir_pact`, `vladimir_pact_broken` (also set here), `vladimir_last_words_known`,
`order_fate` (Argynvostholt); `ireena_pool_vision`, `ireena_pool_choice` (Krezk). Quest moved: `strahds_lair destroyed`.
No new quest: the journal's `strahds_lair` covers the end, and the treasure quests move by `tarokka give` and the
treasure containers.

## 9. Monsters needed

None missing. Uses `strahd_von_zarovich`, `strahds_animated_armor`, `helmed_horror` (P6-02) and existing
`vampire_spawn`, `nightmare`, `gargoyle`, `swarm_of_bats`, `dire_wolf`, `specter`, `vladimir_horngaard`, `revenant`.

## 10. Props needed

Each uses the nearest catalog model today:

- Crouching gargoyle statues for the champion's slab (none placed; the gargoyles appear when the fight starts).
- A stone font of still water for Sergei's tomb (`puddle`).
- A sealed stone reliquary with a wand slot (`chest_iron`).
- A stall-crypt manger heaped with bones (`bones`).
- Strahd's coffin: black lacquer on a stepped stone plinth rather than trestles (`coffin`).
- A statue of the young Strahd in armour (`statue_knight`).
- Regimental banners for the Mad Dog (`tapestry`); a bronze plaque (`relief`); a wall of carved names (`relief`).

## 11. Engine and other owners

- **Misty Escape (P6-01):** when Strahd drops to 0 Hit Points in a fight on `castle_ravenloft_catacombs_strahd`
  (the darklord battle, the daylight fight), treat it as Misty Escape into the coffin beside him (`strahd_in_coffin`),
  not as destruction: the stake belongs to the coffin conversation. If the engine sets `strahd_destroyed` itself, the
  coffin's `ashes` node still ends the game.
- **The Narrator node `strahd:fled_to_coffin`** (in narrative/narrator/castle_ravenloft_catacombs.dialogue) is
  written for the engine to play when Misty Escape sets `strahd_in_coffin` anywhere, so the player knows where to go.
- **`end_game` (P6-09):** the coffin uses it in `the_end` and `ashes`.
- **Flags:** `strahd_destroyed` and `strahd_in_coffin` are registered in this part's flag file; if the engine or
  endings package registers them too, one of the two should go.

## 12. Files

- Doc: docs/regions/castle_ravenloft_catacombs.md (this file); task docs/tasks/P6-08.md
- Locations: data/locations/{castle_ravenloft_catacombs, castle_ravenloft_catacombs_tombs,
  castle_ravenloft_catacombs_strahd}.json
- Flags: data/flags/castle_ravenloft_catacombs.json
- Dialogue: narrative/castle_ravenloft/{catacombs_coffin, catacombs_sergei}.dialogue;
  narrative/narrator/castle_ravenloft_catacombs.dialogue; narrative/banter/castle_ravenloft_catacombs.dialogue

## 13. Critical path (story bot)

Start at `castle_ravenloft_catacombs` (spawn `from_gates`, or `_start("castle_ravenloft_catacombs", 10)`), by day
unless a step says otherwise. Prefer: "Take what lies in his hands", "Drive the stake through his heart",
"Drive the stake into his heart while he sleeps", "dragon told you", "We break our oath". Avoid: "Not yet",
"Back away", "Close the lid", "Leave him in peace".

- **Mad Dog:** `walk_to((8, 8))`, `use((2, 9))` (the bot opens the chained gate (7, 8) by pick or force; the blade
  trap may spring or be found on the way). Expect `treasure_found_*` if the reading put one there.
- **Conjurer:** `use((2, 19))` (the bier gives the wand; gate (7, 21), glyph at (6, 21)), then `use((5, 23))`
  (the reliquary unlocks with the wand).
- **Champion:** `walk_to((38, 9))` (enter `cat_gargoyle_tomb`: `cat_gargoyle_watch`), then `use((39, 9))`.
- **Horseman room:** `walk_to((32, 15))` with the reading's enemy card `horseman` (or roam pick): parley, then
  `cat_horseman_final`.
- **Sergei's tomb:** `go_to("castle_ravenloft_catacombs_tombs")` (exit (5, 29)), `walk_to((6, 6))` (the final battle
  if `broken_one` or `innocent`), `use((6, 4))` → "Take what lies in his hands".
- **Royal tomb:** in the tombs map, `walk_to((16, 18))` (the guardians' hall: `cat_guardians`), then
  `walk_to((16, 20))` (the final battle if `ghost` or `raven`), `use((18, 22))`.
- **Strahd's tomb:** from the catacombs `go_to("castle_ravenloft_catacombs_strahd")` (the black stair (18, 15)),
  `walk_to((11, 9))` (the darklord battle if `darklord`, else `cat_tomb_keepers`), `use((11, 16))` for the treasure.
- **The end:** with `strahd_in_coffin` set (after any final battle), go to Strahd's tomb, `walk_to((11, 9))`
  (`cat_tomb_keepers` unless already won), `use((11, 12))` → "Drive the stake through his heart". Expect
  `strahd_destroyed`, `strahds_lair == destroyed`, and the ending screen (`end_game`). By day without
  `strahd_in_coffin`: `use((11, 12))` → "Drive the stake into his heart while he sleeps" → `cat_daylight_waking`;
  after the win, `use((11, 12))` again → the stake.
