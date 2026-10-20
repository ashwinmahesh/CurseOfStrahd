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

Four maps (the fourth, the Lesser Vaults, is §14), all `dungeon` theme, dark. Area, prop, container, door and trap ids carry the prefix `cat_` (Narrator keys
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
| `cat_stairs_to_main_floor` (catacombs) | (3, 1) | `castle_ravenloft_main_floor` | `from_catacombs` (bricked up: `when: false`, §14) |
| `cat_stairs_to_larders` (catacombs) | (40, 1) | `castle_ravenloft_larders` | `from_catacombs` |
| `cat_down_to_tombs` (catacombs) | (5, 29) | `castle_ravenloft_catacombs_tombs` | `from_catacombs` |
| `cat_black_stair_down` (catacombs) | (18, 15) | `castle_ravenloft_catacombs_strahd` | `from_catacombs` |
| `cat_stairs_to_vaults` (catacombs) | (31, 29) | `castle_ravenloft_catacombs_vaults` | `from_catacombs` (§14) |
| `cat_tombs_up` (tombs) | (16, 1) | `castle_ravenloft_catacombs` | `from_tombs` |
| `cat_black_stair_up` (Strahd's tomb) | (11, 1) | `castle_ravenloft_catacombs` | `from_strahd` |

Spawns on the entry map: `from_vaults` (31, 28) (§14), `default` and `from_gates` (3, 3), `from_larders` (40, 3), `from_tombs` (5, 27),
`from_strahd` (18, 14). The gates part's `crypt_stairs_down` would arrive at `from_gates` but is bricked up (§14), so nobody does: the way in is the
larders part's long stair, arriving at `from_larders`. `from_gates` stays where it was (rule 2: no spawn moves), as `default`'s twin.

## 3. Tarokka places (treasure spots) and enemy rooms

| Place / room | Map | Spot | Enemy room encounter |
|---|---|---|---|
| `castle_ravenloft_catacombs` (horseman) | catacombs | | `cat_horseman_final`, area `cat_beucephalus_crypt` |
| `castle_ravenloft_crypt_of_the_mad_dog` | catacombs | container `cat_mad_dog_sarcophagus` (2, 9) | |
| `castle_ravenloft_crypt_of_the_wizard` | catacombs | container `cat_conjurer_reliquary` (5, 23), key `arcane_focus_wand` | |
| `castle_ravenloft_gargoyle_tomb` | catacombs | container `cat_champion_slab` (39, 9) | |
| `castle_ravenloft_sergeis_tomb` (broken_one, innocent) | tombs | dialogue `castle_ravenloft/catacombs_sergei:take_treasure` | `cat_sergei_final` |
| `castle_ravenloft_tomb_of_barov_and_ravenovia` (ghost, raven) | tombs | container `cat_ravenovia_sarcophagus` (18, 22) | `cat_royal_final` |
| `castle_ravenloft_strahds_tomb` (darklord) | Strahd's tomb | container `cat_tomb_chest` (11, 16): 150 gp, 3 candles, 2 Potions of Healing (Supreme), the Nine Lives Stealer longsword he carried when he took the valley (very rare) | `cat_darklord_final` |

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
| `cat_horseman_final` | catacombs, enter `cat_beucephalus_crypt` | Strahd (375 HP), the nightmare Beucephalus, 2 swarms of bats, 2 of his spawn | 17,400 above High | `final_battle: castle_ravenloft_catacombs`, `lair` |
| `cat_sleepers` | catacombs, enter `cat_sleepers_crypt` | night: 3 vampire spawn; day: 2, surprised in their coffins | 5,400 / 3,600 | optional; `cat_sleepers_slain` |
| `cat_gargoyle_watch` | catacombs, enter `cat_gargoyle_tomb` | 6 gargoyles | 2,700 | guards a treasure place; `cat_gargoyles_slain` |
| `cat_sergei_final` | tombs, enter `castle_ravenloft_sergeis_tomb` | Strahd (350 HP), 3 dire wolves, 2 swarms of bats, 3 of his spawn | 19,100 above High | `final_battle: castle_ravenloft_sergeis_tomb`, `lair` |
| `cat_guardians` | tombs, enter `cat_guardians_hall` | Strahd's animated armor, 2 helmed horrors | 4,500 | on the way to the royal tomb; `cat_guardians_stilled` |
| `cat_royal_final` | tombs, enter `castle_ravenloft_tomb_of_barov_and_ravenovia` | Strahd (400 HP), 3 specters, 2 of his spawn | 17,200 above High | `final_battle: castle_ravenloft_tomb_of_barov_and_ravenovia`, `lair` |
| `cat_darklord_final` | Strahd's tomb, enter `castle_ravenloft_strahds_tomb` | Strahd (350 HP), 2 vampire spawn | 16,600 above High | `final_battle: castle_ravenloft_strahds_tomb`, `lair`; sets `cat_keepers_defeated` (the spawn are the keepers) |
| `cat_tomb_keepers` | Strahd's tomb, enter `castle_ravenloft_strahds_tomb` while `not flag.cat_keepers_defeated` | 2 vampire spawn, 3 swarms of bats | 3,750 | the short fight at the tomb while he rests (or is out); `cat_keepers_defeated` |
| `cat_daylight_waking` | Strahd's tomb, dialogue (the coffin by day) | Strahd (350 HP), 2 swarms of bats, one of his spawn | 14,900 above High | `lair`; not a final battle (no parley) |
| `cat_oathbreakers` | Strahd's tomb, dialogue (the coffin, Vladimir's pact) | Vladimir Horngaard, 5 revenants, the fifth at 80 HP (5 of 8 at level 10) | 11,900 High | only if the party swore Vladimir's pact (Argynvostholt) and breaks it; `cat_oathbreakers_beaten` | (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points and helpers in this note are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)

Strahd's final battles are tuned for a party carrying the Sunsword (owner, 2026-10-13), at the sharp test party's 5
wins in 8 on Balanced: Strahd at 350 or 375 Hit Points with one to five of his spawn beside him, and he keeps out of the
blade's sunlight where he can (a legendary move held back to slip out of it before his turn, his spells cast from
outside it, Charm on its bearer first). Without the Sunsword he stays near-unbeatable, as in the book
(tests/integration/test_scaled_boss_fights.gd).
Woken by day in his coffin (`cat_daylight_waking`) he is the same 5 in 8 for a Sunsword party. (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points and helpers in this note are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)

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
| `cat_markovia_bone_lifted` | bool | the Lesser Vaults' Saint Markovia scene (`castle_ravenloft/catacombs_crypts:lift`) | the same scene (it plays once) |
| `cat_eisglaze_mold_burnt` | bool | the Baron's mold scene (`catacombs_crypts:burn`, needs a torch, oil or alchemist's fire) | his trap's `when`, the scene |
| `cat_klutz_freed` | bool | Sir Klutz's sword scene (`catacombs_crypts:pull`) | the same scene |
| `cat_jarnwald_fell` | bool | the illusory floor's trap (`cat_jarnwald_pit`) | the ghouls' encounter trigger (`flag:`) |
| `cat_sasha_slain` | bool | the `cat_sasha` encounter | Sasha's bier scene |

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
- The tunnel from the brazier room (Dungeon Expansion Plan C4, docs/regions/castle_ravenloft_larders.md §17): the lower
  gallery has a notch in its south wall at (38, 29), the exit `cat_tunnel_mouth`, and the arrival `from_tunnel` (38, 27).
  The green stone in the brazier room lands there too.

## 13. Critical path (story bot)

Start at `castle_ravenloft_catacombs` (spawn `from_larders`, the way a party arrives now that the chapel-side stair is bricked up, or
`_start("castle_ravenloft_catacombs", 10)`), by day
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

## 14. The crypts that hold something (Dungeon Expansion Plan C1, 2026-10-18)

Package C1 of the plan ("Dungeon Expansion Plan - 2026-10-18.md" in the project's files) adds the book's crypts that hold
something. Source: R. C. Veeder's area-by-area survey of the 2016 text, "K84: a diachronic survey of Ravenloft's catacombs"
(rcveeder.net, 2021; checked 2026-10-18): the occupant, the one-line contents and which crypts are empty come from it, and
everything past that line (the coins, the plaques, the menus) is ours and labelled so. The dialogue and narration were
drafted by Gemini through the ai-bridge (docs/story/gemini_drafts/castle_crypts/, with each brief and raw reply).

**Rule 2 held (extend, never redraw).** No square, spawn, exit, prop, container, door or fight start that existed moved
(tests/integration/test_catacomb_crypts.gd pins them). The plan expected "about fourteen solid wall blocks" to become
crypts; the catacombs' entry map has none (all sixteen crypt rooms are open interiors behind gates, and eight of them held
only a decor crypt). So:

- **Seven crypts went into seven of those empty rooms**, additive only: new props, containers, traps, finds, a plaque
  with the epitaph, a name on the gate's label, an area with its own floor and walls (below).
- **The other nine crypts and Khazan's door went to a new map**, `castle_ravenloft_catacombs_vaults` (the Lesser Vaults,
  52 x 27, mood `ravenloft_vaults`: older, rougher stone, grey backdrop). One wall cell of the lower gallery's south wall
  became its stair (`cat_stairs_to_vaults` (31, 29) down, `vaults_stairs_up` (1, 13) up, spawns `from_catacombs` (3, 13) and
  `from_vaults` (31, 28)).
- **Crypt 32's niche opens on Strahd's tomb**: three wall cells at the tomb's north-west corner became a niche
  (`cat_finderway_back` (3, 4), spawn `from_finderway` (3, 5), area `cat_finderway_alcove`), open to the tomb's floor at
  (3, 7); the Vaults' `vaults_finderway_portal` (50, 19) leads to it, spawn `from_strahd_alcove` (49, 19) back.

### The seven crypts in place (the catacombs map)

| Book crypt | Room, gate | What it holds |
|---|---|---|
| 11, Tasha Petrovna | `cat_crypt_tasha`, (11, 6) to (14, 10), gate (10, 8) | the sun painted on the vault (`cat_tasha_sun`, a `sunlight` light: a vampire in its radius burns as in sunlight, in a fight) and her silver holy symbol (a find, `holy_symbol_amulet`) |
| 12, King Troisky | `cat_crypt_troisky`, (16, 6) to (19, 10), gate (20, 8) | a three-faced helm; the sunk step before his slab is a gas plate (`cat_troisky_gas`: Con 16, 5d10 poison, poisoned) guarding a coffer of 120 gp |
| 22, Sir Erick Vonderbucks | `cat_crypt_erick`, (11, 20) to (14, 24), gate (10, 22) | a corpse dipped in gold; 180 gp flaked off it (a container) |
| 28, Bascal Ofenheiss | `cat_crypt_bascal`, (24, 6) to (27, 10), gate (23, 8) | the bell on a cord (`cat_bascal_fire`: Dex 16, 6d6 fire) over the jeweled electrum spork (`jeweled_electrum_spork`, a 250 gp curio) |
| 29, Baron Eisglaze Drüf | `cat_crypt_eisglaze`, (29, 6) to (32, 10), gate (33, 8) | brown mold (`cat_eisglaze_cold`: Con 15, 5d8 cold, only until `cat_eisglaze_mold_burnt`; a torch, oil or alchemist's fire burns it in the `eisglaze_mold` conversation) over his sword, a **Giant Slayer longsword** (rare, DMG 2024; search, Investigation 12) |
| 33, Sir Klutz Tripalotsky | `cat_crypt_klutz`, (24, 20) to (27, 24), gate (23, 22) | the skeleton with the sword: pull it and his ghost (`sir_klutz`, a `ghost` stat block) offers to fight one battle as a guest, leaving when that fight ends |
| 31 (no name, only wealth) | `cat_crypt_31`, (29, 20) to (32, 24), gate (33, 22) | a painted false floor over a spiked pit (`cat_c31_pit`: pit 10 ft, Dex 15, 2d10 piercing) in front of the noble's crypt that was already there |

### The Lesser Vaults (the new map)

A long passage (y 12 to 14) with crypts off both sides. Every crypt keeps its own floor, walls and light.

| Book crypt | Room, gate | What it holds |
|---|---|---|
| 6, Saint Markovia | `cat_crypt_markovia`, (2, 4) to (8, 10), gate (5, 11) | her sarcophagus behind a dart plate (`cat_markovia_darts`: Dex 15, 4d6 poison, poisoned); her thighbone on the lid, which when lifted shows her ghost for a few words (`catacombs_crypts:lift`). lifting it gives the party the item `saint_markovias_thighbone` (`give` in the `lift` node; Dungeon Expansion Plan I1, docs/story/castle_artifacts.md) |
| 25, Stefan Gregorovich | `cat_crypt_stefan`, (11, 6) to (15, 10), gate (13, 11) | a skull that answers every question and is always wrong (`catacombs_skulls:stefan`) |
| 26, Intree Sik-Valoo | `cat_crypt_intree`, (18, 6) to (22, 10), gate (20, 11) | a skull that answers truly (`catacombs_skulls:intree`): where Strahd sleeps, how he is ended, what Saint Finderway's niche does |
| 14, Stahbal Indi-Bhak | `cat_crypt_stahbal`, (25, 1) to (38, 10), gate (31, 11) | a round shaft and twelve upright coffins; the captains rise (`cat_stahbal`) |
| 15, Khazan | a sealed door, `cat_khazan_door` (42, 12) | his name and nothing behind it (he lies under his own tower now): one Narrator line |
| 35, Sir Jarnwald | `cat_crypt_jarnwald`, (2, 16) to (11, 24), gate (6, 15) | an illusory floor over a pit (`cat_jarnwald_pit`, 24 squares, Dex 14, 2d10 bludgeoning, sets `cat_jarnwald_fell`) of ghouls (`cat_jarnwald_ghouls`, on that flag) |
| 20, Sasha Ivliskova | `cat_crypt_sasha`, (14, 16) to (21, 22), gate (17, 15) | a bride in webs on her bier: speak to her and she wakes, asks if her love has come, and attacks (`catacombs_sasha:bier`, `cat_sasha`); easing the lid shut after hearing her out ends without a fight |
| 21, Patrina Velikovna | `cat_crypt_patrina`, (24, 16) to (29, 21), gate (26, 15) | her bier is empty (her ghost is at the Amber Temple); 250 gp of old coins |
| 27 (no occupant) | `cat_crypt_spiders`, (32, 16) to (42, 25), gate (37, 15) | webs (difficult terrain) and the spiders (`cat_spiders`) |
| 32, Saint Finderway | `cat_crypt_finderway`, (45, 16) to (49, 21), gate (47, 15) | two niches; the dusty one is a wall piece, the humming one an exit to Strahd's tomb |

### The four fights (non-boss: 5 in 8 for the sharp party on Balanced, tests hold 4 to 6, seeds 1-8, level 10)

| Fight | Where | Foes | Wins | Note |
|---|---|---|---|---|
| `cat_stahbal` | crypt 14, Stahbal Indi-Bhak's hall (entering it) | 6 wights (144 HP), 12 skeletons | 5 | the captains rise from the coffins along the walls; 12.5 rounds, 2.5 heroes down a fight |
| `cat_sasha` | crypt 20, the bride's crypt (a conversation, then `combat cat_sasha`) | 7 vampire spawn (86 HP; Sasha Ivliskova and six bridesmaids in webs) | 5 | woken by speaking to her; sets `cat_sasha_slain`; 5.8 rounds, 1.9 down |
| `cat_spiders` | crypt 27, the webbed crypt (entering it) | 7 giant spiders (80 HP), 4 wraiths | 5 | the wraiths are the nest's older prey, up out of the webs. Spiders alone only reached 5 in 8 as 12 spiders at 285 HP, a 20-round slog with two stalled fights; 7.6 rounds, 1.4 down |
| `cat_jarnwald_ghouls` | crypt 35, the Trickster's crypt (the `cat_jarnwald_fell` flag, set by the illusory floor) | 10 ghouls (79 HP), 3 ghasts (98 HP) | 5 | measured with the pit already sprung (as in play: a sprung trap is not armed in the fight); 4.9 rounds, 1.9 down |

Held by tests/integration/test_scaled_fights_castle_rooms.gd, spread by tests/unit/test_fight_spread.gd. The measured
lines are in docs/story/fight_tuning_castle.md.

### Loot (for the loot audit lane)

Coin and item placements, scaled to the hoard rules (small purses, like the rest of the catacombs): Troisky's coffer 120 gp,
Erick's gold 180 gp, Patrina's coins 250 gp, the jeweled electrum spork (250 gp, a curio nobody else carries), Tasha's
silver holy symbol (a plain `holy_symbol_amulet`), and one magic find: a **Giant Slayer longsword** (rare, DMG 2024, no attunement) under the mold in crypt 29.
The plan said the Luck Blade there; it is legendary (legendary is for the four villains, and test_found_items caps a hidden
find at very rare) and Dmitri Krezkov already sells one. Two swaps were tried and dropped: a Flame Tongue (Argynvostholt's armory
already holds one, `armory_flame_tongue`, and "each lasting item once" allows no second: docs/story/magic_item_audit.md,
tests/unit/test_loot_distinct.gd on the item-audit branch) and Tramontane armor (a very rare find, but test_found_items
wants finds from the 2024 DMG and Tramontane armor is "AU"). Giant Slayer is DMG 2024, placed nowhere else (checked by hand
against the item-audit branch's placements, template ids included), and is a combat item for the party's sword arms. The
band is rare, not the very rare the plan wanted, because no very rare DMG weapon is left unplaced. If the loot audit wants
another item, it is one id in `cat_eisglaze_sword`.

### Small code (hook files)

- `LocationFights._light_the_fight` (world/exploration/location_fights.gd): a location light with `sunlight: true` is true
  sunlight in a fight (Tasha's painted sun). Schema: `lights[].sunlight`.
- `StoryState.release_one_fight_guests` (story/story_state.gd), asked by `LocationFights._end_encounter` after
  `see_to_fallen_guests`: an NPC with `leaves_after_fight: true` (Sir Klutz) leaves the party when the next fight ends.
  Schema: npc `leaves_after_fight`. Test: tests/unit/test_one_fight_guests.gd.

### Files

Maps: data/locations/castle_ravenloft_catacombs.json, castle_ravenloft_catacombs_strahd.json, castle_ravenloft_catacombs_vaults.json.
Dialogue: narrative/narrator/castle_ravenloft_catacombs.dialogue, narrative/castle_ravenloft/{catacombs_crypts, catacombs_skulls,
catacombs_sasha}.dialogue. Data: data/flags/castle_ravenloft_catacombs.json, data/npcs/{stefan_skull, intree_skull,
sasha_ivliskova, sir_klutz}.json, data/items/jeweled_electrum_spork.json, art/atmosphere/moods.json (`ravenloft_vaults`),
art/audio.json. Tests: tests/integration/test_catacomb_crypts.gd, tests/unit/test_one_fight_guests.gd and four tests added to
test_scaled_fights_castle_rooms.gd.

### The walled stair (C1 hand-off 2)

In the book the stair from the chapel side down to the crypts is bricked up, so a party has to find another way down. Ours
now is, at both ends: `crypt_stairs_down` (main floor (44, 23)) and `cat_stairs_to_main_floor` (here (3, 1)) keep their squares
and spawns but gain `when: false` and a `locked_text` (stepping onto either says why), and a chink in the masonry stands beside each
(`crypt_stair_chink` (44, 22) on the main floor, `cat_stair_chink` (4, 2) here; Narrator `examine:` lines, each with a variant for
`flag.strahd_in_coffin`: his mist draws through it and goes down). The way down is the servants' stairs to the larders and the
larders' long stair (`larders_long_stair`, arriving at `from_larders` (40, 3)); the way up is `cat_stairs_to_larders` and
`larders_stair_up`. Strahd turning to mist (`strahd:fled_to_coffin`: "through the cracks, and down") is the thing the masonry was
never meant to stop. The story bot finds the longer road by itself (it takes only exits whose `when` holds), so
test_phase6_exit's walk to Strahd's tomb now goes through the larders; tests/integration/test_castle_crypt_stair.gd pins the
bricking, the route and the chinks. Six new Narrator lines (two `locked_text`, two chink looks, two mist variants), drafted by
Gemini (docs/story/gemini_drafts/castle_crypts/brief6.txt and reply6).

