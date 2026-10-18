# Castle Ravenloft, part `court`: the Court of the Count and the Rooms of Weeping (Phase 6)

Plan §10 Phase 6; ADR 0014 (castle, final battle, Strahd); ADR 0011 (treasure spots). Overview and seams:
docs/regions/castle_ravenloft.md. Task: docs/tasks/P6-05.md. Party level 9 to 11 (fights tuned for four at level 10
plus a guest); the castle gives no milestone. Source: *Curse of Strahd* chapter 4, the castle's second and third
floors (roughly K25 to K53), retold in our own words. The data and dialogue files in §12 are the source of truth for
exact text.

## 1. What this part is for

The upper floors are where Strahd lives rather than where he receives. Below is the house he shows; up here is the
house he keeps: the throne nobody kneels at, the study where he reads the same letters, the vault he never spends, his
bedroom with a mirror that shows the bed and not the man, the three women he made and keeps in a lounge like
ornaments, and a sixteen-year-old village girl in the guest room who thinks she is in a love story.

The part asks one question: **who in this house can still leave?** Gertruda can, if the party finds the right words
and gets her past Rahadin. Lief Lipsiege, chained to his ledgers, can, if the party is willing to fight his rug for
him. Anastrasya, the youngest bride, cannot, and knows it, and asks for the other kind of leaving.

Tone: a doll's house with something wrong in every room. Rahadin's courtesy, Lief's arithmetic and Volenta's games
are the comedy; the guest room is where it stops being funny.

## 2. Who is here and what each wants

| Who | Id (stat block) | Wants | Fears | Secret | Voice |
|---|---|---|---|---|---|
| Rahadin, the chamberlain | `rahadin` (`rahadin`) | The master's house in order; guests where guests belong | Being dismissed; a house with no master to serve | He served Strahd gladly before the pact and would choose the same again | Clipped, exact, no contractions; counts things; faint screaming follows him like a draught |
| Ludmilla Vilisevic, the eldest bride | `ludmilla_vilisevic` (`vampire_spawn`) | To be the only one; to be looked at the way he looks at the portraits | Being replaced by a face she can never wear | She tells the party where the vault is out of spite | Cold, educated, precise; quotes poets; every compliment is a cut |
| Anastrasya Karelova, the youngest bride | `anastrasya_karelova` (`vampire_spawn`) | Rest; for the girl in the guest room not to become her | Forgetting her mother's face | She slept in the guest room once, in a borrowed gown, and thought she was lucky | Quiet, plain words from Krezk; stops mid-thought; the only bride who says "please" |
| Volenta Popofsky, the third bride | `volenta_popofsky` (`vampire_spawn`) | Games; fear she can taste | Boredom | She keeps a tally on her coffin lid of how many nights each new guest lasted | Giggling, teasing questions, nursery rhymes turned wrong |
| Lief Lipsiege, the count's accountant | `lief_lipsiege` (`commoner`) | The books balanced; to be left alone with them | Rahadin; the rug; the outside | He tried to leave once, forty years ago, and the chain is the result | Fussy, numerical, gallows-dry; talks in sums and percentages |
| Gertruda, Mad Mary's daughter | `gertruda` (`commoner`, guest) | The love story she was promised | Her mother's anger; that the love story isn't true | Under the dreaming she is frightened, and hums when she is | Breathless, sheltered, fairy-tale words; braver than she sounds once the spell cracks |
| Helga Ruvak, the maid of the private floor (the book's) | `helga_ruvak` (`vampire_spawn`; her own art, owner's yes 2026-10-15) | To be thought harmless; to be the one the master sends for | The brides; being seen through too early | She is a vampire spawn keeping up the part of a frightened maid (Insight 14 sees it) | Meek, quick "if you please", always asks whether the guests are staying the night; amused, not angry, once seen through |
| The Dead Watchman | `castle_dead_watchman` (`strahd_zombie`) | The watch kept | | | Narrator lines only: he paces the King's Hall and salutes the throne room doors |

The household (owner, 2026-10-15, "should there be servants?"): Helga walks the Rooms of Weeping's corridor from
(10, 10), dusting the frames at (4, 9) and (27, 9); the watchman walks the King's Hall from (6, 11) to the throne room
doors (22, 11) and on to (38, 11). Their conversations (narrative/castle_ravenloft/court_household.dialogue) set
nothing and can always be left, and their entries have `steps_aside`, so neither stands in any fight on these maps.
Voice: docs/voice/helga_ruvak.md. Two courtiers (vampire spawn) walk the audience hall and the trophy room, Boyar
Vintila Crainic with his petition and Sir Lothar Brandt among the trophies; two ghosts of the household walk the study
and the count's bedroom, Anghel Daskal the secretary and Ghenadie the valet (household.dialogue; who they are:
castle_ravenloft_gates.md §8).

Voice bibles: docs/voice/{rahadin, ludmilla_vilisevic, anastrasya_karelova, volenta_popofsky, lief_lipsiege,
gertruda}.md. Strahd (`strahd`) speaks in this part only through the final battles' parley (presence package); his
rooms speak for him.

## 3. Maps and areas (book areas)

Three maps, all `manor` theme, dark. Area, prop, container, door and trap ids carry the prefix `court_` (Narrator keys
are global).

| Map | Size | Areas (book area) | What happens |
|---|---|---|---|
| `castle_ravenloft_court` (the Court of the Count, second floor) — entry map | 44 x 25 | `court_grand_landing` (the head of the grand stairs), `court_kings_hall` (K27, the long hall), `court_audience_hall` (K25), `court_study` (K37), `court_trophy_room` (K31), `court_accountant` (K30), `court_guard_post` (K26, the guards' run), `court_stair_hall` (the tower stair, standing in for K39/K40) | Rahadin receives the party in the long hall; the throne on its dais; the study with the lady over the hearth and a bookcase door into the audience hall; the dragon's skull among the trophies; Lief at his desk and the rug; Strahd's armour in the guardroom; the portrait of a young woman in an alcove of the long hall that hides the stair down to the vault; the tower stairs (spires) and the stairs up (Rooms of Weeping). |
| `castle_ravenloft_court_weeping` (the Rooms of Weeping, third floor) | 40 x 23 | `court_weeping_landing`, `court_weeping_hall`, `court_strahds_bedchamber` (K42), `court_strahds_bath` (K43), `court_portrait_gallery` (K47), `court_lounge` (K49), `court_ludmilla_room`, `court_anastrasya_room`, `court_volenta_room`, `court_guest_room` (K50), `court_rahadin_chamber` (K53) | Strahd's bedroom (locked, lock 16) and bath; his portrait that watches the gallery; the three brides in the lounge with their rooms behind it (the book keeps them elsewhere; we keep them together); Gertruda in the guest room; Rahadin's bare room. |
| `castle_ravenloft_court_treasury` (the vault, K41) | 16 x 13 | `court_vault_stair`, `court_treasury` (and `court_vault_dome`, the same squares, for the line about the ceiling) | A narrow stair from behind the portrait down to a vault of heaped coin: a glyph on the bottom step, and the hoard. Daern's Instant Fortress stands in its north-east corner under a black dome of star shards (§15). |
| `castle_ravenloft_court_belfry` (the back way, K38 to K40) | 48 x 22 | `court_way_flue`, `court_way_false_treasury` (K38), `court_way_hall_of_webs` (K39), `court_way_belfry` (K40), `court_way_vault_stair` | Behind the study's hearth: a false treasury with a trapped chest and two sconces, a hall of webs, a belfry with a rope, and a secret stair down to the vault (§15). |

### Seams

| Exit (cell) | To | Spawn here |
|---|---|---|
| `court_stairs_down` (22, 23), on the landing | `castle_ravenloft_main_floor:from_court` (gates) | `from_gates` (22, 21), also `default` |
| `court_tower_stairs` (41, 15), in the stair hall | `castle_ravenloft_spires:from_court` (spires) | `from_spires` (39, 16) |
| `court_stairs_up` (41, 23), in the stair hall | `castle_ravenloft_court_weeping:from_court` | `from_weeping` (39, 22) |
| `court_vault_passage` (12, 14), the alcove (when `flag.court_treasury_found`) | `castle_ravenloft_court_treasury:from_court` | `from_treasury` (12, 13) |
| weeping `court_weeping_stairs_down` (38, 10) | `castle_ravenloft_court:from_weeping` | weeping `from_court` (36, 10) |
| treasury `court_vault_stairs_up` (7, 1) | `castle_ravenloft_court:from_treasury` | treasury `from_court` (8, 2) |
| the study hearth (`court_hearth_grate`, a conversation's `move`, not an exit) | `castle_ravenloft_court_belfry:from_study` (2, 15) | court `from_hearth` (4, 2), also `from_chimney` |
| belfry `court_way_to_study` (2, 13) | `castle_ravenloft_court:from_hearth` | |
| belfry `court_way_stair_down` (42, 3) | `castle_ravenloft_court_treasury:from_court` (the portrait stair's own foot, (8, 2)) | belfry `from_treasury` (42, 4) |
| the false treasury's gas (`court_way:gassed`, `move`) | `castle_ravenloft_court_weeping:from_gas` (19, 20), in the guest room | |
| the roof's smokestack (`court_way:down`, `move`) | `castle_ravenloft_court:from_chimney` (4, 2) | |

### Secret ways, locks and traps

- **The vault stair** (the tempter's "painting of the woman he lost"): the alcove in the long hall's south wall holds
  `court_lady_portrait` (12, 15), an examine prop that opens `court_halls:lady_portrait`. The party swings her aside
  if it knows how (`court_treasury_known` from Lief or Ludmilla's spite, or `court_ledger_read` from his ledger; no
  roll), or finds the catch with
  Investigation 16 or Perception 18 (not spent; can be tried again after a short wait). Sets `court_treasury_found`;
  the exit `court_vault_passage` (a stair down, drawn only once found) opens.
- **The study bookcase** `court_study_bookcase` (11, 2): a secret door (Search DC 15) from the study straight onto the
  audience hall's dais.
- Locks: the count's bedroom door (16), Lief's strongbox (15), the jewel box by Strahd's bed (17), Rahadin's
  footlocker (17), the vault strongbox (18).
- Traps: `court_trophy_crossbow` (the trophy cabinet is wired to a hunting crossbow; detect 14, disarm 14, Dex 14,
  3d10 piercing) and `court_vault_glyph` (a glyph on the vault's bottom step; detect 16, disarm 15, Dex 15, 5d8
  lightning).

## 4. The flow (all optional; each Tarokka place is one short walk from the entry)

1. **The landing and the long hall.** The party comes up the grand stairs onto the landing and into the King's Hall,
   where Rahadin waits (approach 5, `rahadin_met`): the house's rules, a little about his master and the screaming
   that follows him. A party that attacks him fights him here (`court_rahadin_fight`).
2. **The audience hall** (double doors north of the long hall): the throne on its dais, the Zarovich crest. The throne
   hides a compartment (treasure spot). The beast's final battle.
3. **The study** (door at the west end of the long hall): the lady over the hearth (treasure spot), Strahd's desk,
   his unsent letters (a book), the bookcase door to the dais. The seer's final battle.
4. **Lief's office** (door off the long hall): Lief, his ledger (a book: it lists the vault "behind the lady", and a
   guest account for "G., sixteen, three gowns, pending" beside the closed account of "A. Karelova"), his strongbox
   and his rug. Freeing him means fighting the rug (`court_accountant_rug`); afterwards he leaves for Vallaki.
5. **The vault.** Swing the lady aside, go down, mind the glyph. The tempter's final battle; the hoard is the
   treasure spot.
6. **The trophy room**: hunting trophies, a trapped cabinet, and a dragon's skull mounted like a stag's head
   (`argynvost_skull_found`; Argynvostholt's quest the_dark_beacon wants it home: see §11).
7. **The guardroom** (off the landing): Strahd's animated armour and helmed horrors (`court_post_watch`) and their
   weapon rack.
8. **Up to the Rooms of Weeping** (the stair hall): the brides in the lounge (talk; Ludmilla's spite gives the vault;
   Anastrasya's story frees Gertruda's mind; a fight if provoked), Gertruda in the guest room, Strahd's bedroom and
   bath, the portrait gallery (`court_portrait_watch`), Rahadin's room.
9. **Bringing Gertruda home.** She joins as a guest (`join gertruda`). At the head of the grand stairs Rahadin is
   waiting (`court_rahadin:intercept`): fight him, talk him aside (Persuasion 16 or Intimidation 17; a failure is a
   fight), or give her back (the quest fails). At Mad Mary's house in the village of Barovia, Mary sees her daughter
   and the quest ends (`court_gertruda:homecoming`).

## 5. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Gertruda | guest room | convince her (Mary's message, Anastrasya's story, Lief's ledger, a Cleric's blessing, Insight 13 then honesty, or Persuasion 15), or leave her | `gertruda_rescued`, `join gertruda`, quest `find_gertruda found` | Rahadin's intercept; Mary's house; endings may read `gertruda_home` / `gertruda_given_back` |
| A failed Persuasion with Gertruda | guest room | | she sends word to the master (`court_gertruda_warned_him`) | Rahadin can't be talked aside at the stairs: fight him or give her back |
| Rahadin at the stairs | landing | fight, Persuasion 16, Intimidation 17, give her back | `rahadin_defeated` / `rahadin_stood_aside` / `gertruda_given_back` + `find_gertruda lost` | Rahadin gone from his room if beaten |
| Lief | his office | leave him, or free him (the rug fights) | `court_rug_destroyed`, then `lief_freed` | he leaves for Vallaki (endings may read `lief_freed`) |
| The brides | lounge | talk, provoke (fight), Intimidation 16 on Volenta (a failure is the fight) | `court_brides_met`, `court_brides_fought` | Anastrasya stays out of the fight if she told her story; afterwards she asks for rest (`anastrasya_at_rest`) |
| Anastrasya's rest | her room | grant it, or refuse | `anastrasya_at_rest` | epilogue material |

No menu depends on a single social check: every one has a plain way on (evidence, a class option, a fight, or
walking away), and the social failures cost something (Gertruda's warning, a fight with Rahadin or the brides).

## 6. Encounters (2024 DMG budgets, four characters at level 10: Low 6400 / Moderate 9200 / High 12400)

XP from the stat blocks (P6-02 writes the new ones; Curse of Strahd numbers): Strahd 13000 (CR 15, lair 15),
Rahadin 5900 (CR 10), Strahd's animated armour 2300, helmed horror 1100, vampire spawn 1800, rug of smothering 450,
guardian portrait 200, crawling claw 10, dire wolf 200, swarm of bats 50.

| id | Map | Trigger | Monsters | XP (band) |
|---|---|---|---|---|
| `court_final_audience_hall` (final battle `castle_ravenloft_audience_hall`, beast, lair) | court | enter `court_audience_hall` | Strahd on the dais (350 HP), 3 dire wolves, 4 of his spawn | 20800 (above High) |
| `court_final_study` (final battle `castle_ravenloft_study`, seer, lair) | court | enter `court_study` | Strahd by the hearth (350 HP), 2 swarms of bats down the chimney, 5 of his spawn | 22100 (above High) |
| `court_final_treasury` (final battle `castle_ravenloft_treasury`, tempter, lair) | treasury | enter `court_treasury` | Strahd on the hoard (400 HP), a helmed horror, 3 of his spawn | 19500 (above High) |
| `court_post_watch` | court | enter `court_guard_post` | Strahd's animated armour, 3 helmed horrors | 5600 (Low) |
| `court_rahadin_fight` | court | dialogue (Rahadin in the hall or at the stairs) | Rahadin and 2 of Strahd's animated armour and a third, battered (at the stairs Rahadin at 300 HP and the third at 50; in the hall the third at 90) | 12800 (High) |
| `court_accountant_rug` | court | dialogue (freeing Lief) | rug of smothering, 3 crawling claws | 480 (trivial; a scare) |
| `court_portrait_watch` | weeping | enter `court_portrait_gallery` | guardian portrait, 2 of Strahd's animated armour | 4800 (under Low) |
| `court_way_spiders` | belfry | dialogue (pulling the belfry's rope) | 8 giant spiders at 185 Hit Points each, round the walls of the belfry | 1600 (Low; Hit Points raised, see §15) |
| `court_brides_fight` | weeping | dialogue (provoking the brides) | Ludmilla, Volenta, 2 of Strahd's spawn and 2 animated armours; or all three brides and 2 armours | 11800 / 10000 |
| `court_rahadin_chamber_fight` | weeping | dialogue (Rahadin in his room) | Rahadin and 3 of Strahd's animated armour | 12800 (High) |

Retuned for the sharp test party (owner, 2026-10-13: the autopilot smites, opens with Spirit Guardians and throws
Fireball as he plays, and wins 5 in 8 on Balanced at every level): at level 10 Rahadin on the stair, in the hall and in
his chamber and both brides fights win 4 or 5 of 8 (tests/integration/test_scaled_boss_fights.gd). (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points, helpers and win counts in this paragraph are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)

Strahd's final battles are tuned for a party carrying the Sunsword (owner, 2026-10-13), at the sharp test party's 5
wins in 8 on Balanced: Strahd at 350 or 375 Hit Points with one to five of his spawn beside him, and he keeps out of the
blade's sunlight where he can (a legendary move held back to slip out of it before his turn, his spells cast from
outside it, Charm on its bearer first). Without the Sunsword he stays near-unbeatable, as in the book
(tests/integration/test_scaled_boss_fights.gd). (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points, helpers and win counts in this paragraph are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)

The engine plays the parley first and moves `strahds_lair` to `confronted` when a final battle starts; dropping
Strahd to 0 there turns him to mist and sends him to his coffin (catacombs). Strahd appears in this part only in the
three final battles: no harassment fight here.

## 7. Tarokka places (ADR 0011) and enemy rooms (ADR 0014)

- **`castle_ravenloft_audience_hall`** ("a seat made for one"): `treasure_spots` in `castle_ravenloft_court` →
  container `court_throne` (21, 1), the throne on its dais; the seat lifts on a hinge. Enemy room for **beast**:
  `court_final_audience_hall`.
- **`castle_ravenloft_study`** ("a lady made of paint and varnish ... above the hearth"): `treasure_spots` in
  `castle_ravenloft_court` → container `court_study_portrait` (6, 0), the portrait over the fireplace (open it from
  (6, 1)). Enemy room for **seer**: `court_final_study`.
- **`castle_ravenloft_treasury`** ("buried under coin heaped like snowdrifts"): `treasure_spots` in
  `castle_ravenloft_court_treasury` → container `court_treasury_hoard` (7, 8), the heaps of coin. Enemy room for
  **tempter** ("find the painting of the woman he lost; behind her lies his hoard"): `court_final_treasury`.

## 8. Quests and the find_gertruda ending

`find_gertruda` (village_of_barovia's quest) gains three stages (one edit to data/quests/find_gertruda.json): `found`
(she agreed to come home and joined), `home` (success: Mary's house) and `lost` (failure: handed back to Rahadin).
Finding her works whether or not the party ever met Mary: the `found` journal names her mother and her house. Mary's
house (data/locations/mad_marys_house.json, village owner) gains three NPC entries (one edit): Mary meets the party
with `castle_ravenloft/court_gertruda:homecoming` when `guest:gertruda` (approach), then `court_gertruda:mary_after`
once `gertruda_home`; Gertruda stands in her own room afterwards (`court_gertruda:at_home`). No new quest of our own.

## 9. Flags (data/flags/castle_ravenloft_court.json)

Read by later content (endings, epilogues): `gertruda_home`, `gertruda_given_back`, `lief_freed`,
`anastrasya_at_rest`, `rahadin_defeated`, `court_brides_fought`, `argynvost_skull_found`. Internal: `rahadin_met`,
`rahadin_stood_aside`, `court_treasury_known`, `court_treasury_found`, `court_ledger_read`, `court_rug_destroyed`,
`lief_met`, `court_post_cleared`, `court_gallery_cleared`, `court_brides_met`, `court_anastrasya_story`,
`gertruda_met`, `gertruda_rescued`, `court_gertruda_warned_him`, `court_gertruda_insight`.

The back way's (§15): `court_way_sconce_set`, `court_way_gas_known`, `court_way_gassed`, `court_way_chest_taken`,
`court_way_bell_rung`, `court_way_spiders_cleared` are registered here; `court_hearth_found`, `court_hearth_out` and
`court_stack_climbed` are set by world checks, so they are in data/flags/world_checks.json. None is read by the main story.

Flags read from others: `gertruda_search_promised` (village_of_barovia: Mary's message), `guest:ireena`,
`guest:gertruda`, `tarokka` conditions.

## 10. Loot

| Container | Map | Contents |
|---|---|---|
| `court_throne` | court | 40 gp in old crowns; the Tarokka treasure when the reading puts one here |
| `court_study_portrait` | court | nothing of its own; the Tarokka treasure when the reading puts one here |
| `court_study_desk` | court | ink, ink pen, parchment, 25 gp |
| `court_trophy_cabinet` (trapped) | court | a spear, a longbow, 60 gp |
| `court_tax_strongbox` (lock 15) | court | 220 gp (a year of Vallaki's tithe) |
| `court_post_rack` | court | longsword, shield, light crossbow, 20 bolts |
| `court_strahd_wardrobe` | weeping | fine clothes x2 |
| `court_strahd_jewel_box` (lock 17) | weeping | 300 gp in rings and pins, a Ring of Shooting Stars (very rare) |
| `court_bath_cabinet` | weeping | perfume x2 |
| `court_gallery_cabinet` | weeping | potion of healing x2 |
| `court_guest_wardrobe` | weeping | fine clothes x3 (gowns, all one size) |
| `court_ludmilla_shelf` | weeping | book x2, perfume, an Ioun Stone (Reserve) (rare) |
| `court_anastrasya_trunk` | weeping | travelers' clothes, 3 gp in Krezk copper, a Figurine of Wondrous Power (Onyx Dog) (rare) |
| `court_volenta_trunk` | weeping | dagger, playing cards, 45 gp, a Mace of Terror (rare) |
| `court_rahadin_rack` | weeping | scimitar x2, dagger |
| `court_rahadin_footlocker` (lock 17) | weeping | 150 gp, a Potion of Healing (Greater), a Scimitar of Speed (very rare), a Ring of X-ray Vision (rare) |
| `court_treasury_hoard` | treasury | 5400 gp (the book's heaps of copper, silver, gold and platinum, a quarter of their worth, §15); the Tarokka treasure when the reading puts one here |
| `court_treasury_strongbox` (lock 18) | treasury | 600 gp, the Manual of Gainful Exercise (very rare), the Rod of Lordly Might (legendary) |
| `court_treasury_jewels` | treasury | 1000 gp in jewellery, 8 diamonds and 7 pearls (the book's fifteen 100 gp gems), an Ioun Stone (Absorption) (very rare) |
| `court_way_chest_a`, `court_way_chest_b` | belfry (false treasury) | 14 gp, 21 gp |
| the trapped chest (`court_way_gas_chest`, a conversation) | belfry (false treasury) | 35 gp, once |
| `court_way_skeleton` (a prop) | belfry (false treasury) | a torch, once |

The random magic-item system (ADR 0012) adds items to these containers; no story item is placed here besides the
Tarokka treasures.

## 11. Monsters needed

None beyond the list P6-02 is writing: `strahd_von_zarovich`, `rahadin`, `strahds_animated_armor`,
`guardian_portrait`, `helmed_horror`, `crawling_claw`, `rug_of_smothering`. Existing: `vampire_spawn` (the brides, by
`name`), `dire_wolf`, `swarm_of_bats`, `commoner` (Lief, Gertruda).

## 12. Props needed

Each uses the nearest catalog piece for now:

- a throne on a dais (`chair_high`) and the Zarovich crest behind it (`crest`);
- a portrait of a young red-haired woman, alone (`painting`, which shows a family): over the study hearth, in the long
  hall's alcove, and by Strahd's bed;
- a full-length portrait of Strahd that can come alive (`painting`);
- a dragon's skull mounted on a wall (`dragon_bones`);
- heaps of gold coin on a vault floor (`chest`, `sack`);
- a portrait that swings open on a hidden stair (the stair is the catalog's `stair_down`; the portrait is `painting`);
- a living rug (`rug_runner` while it lies still);
- a chained desk with an iron ankle shackle (`desk`);
- cobwebs for the stair hall (none placed yet).

## 13. Engine, art and other owners

- Art (P6-12): portraits and sprites for the six NPCs; Rahadin (a small dusk elf in black, a scimitar, a pale draught
  of faces around him), the brides (three women in old-fashioned gowns, each different: Ludmilla severe, Anastrasya a
  village girl in a lady's dress, Volenta small and bright-eyed), Lief (a thin old clerk, ink-stained, shackled),
  Gertruda (sixteen, dark hair, a blue gown too fine for her). Voice casting for the six (audio/voice/casting.json).
- Argynvostholt: the dragon's skull here is only seen (`argynvost_skull_found`). Bringing it home needs a quest item
  (`argynvosts_skull`) and a hand-in at the mausoleum; if the lead wants that, the trophy room can hand it over.

## 14. Critical path (test bots)

Start: `_start("castle_ravenloft_court", 10)` (arrives at `from_gates` (22, 21)) by day, four pregens. Prefer:
"We'll find our own way", "Show us the way behind her", "Swing her aside", "Your mother isn't angry", "Anastrasya
slept in this room", "The ledger", "Come home", "Then we go through you". Avoid: "Gertruda, go back", "We didn't come
as guests", "Stand aside or fall with him", "Leave her be", "We'll deal with the rug" (unless freeing Lief).

1. **Audience hall** (beast; treasure): walk north to (22, 13) (Rahadin speaks: "We'll find our own way."), open the
   doors (21, 10), walk to (21, 4): `court_final_audience_hall` starts there when the reading's room is the audience
   hall. Open `court_throne` (21, 1) from (21, 2).
2. **Study** (seer; treasure): from the long hall walk to (5, 11), open the door (5, 10), walk to (5, 5):
   `court_final_study`. Open `court_study_portrait` (6, 0) from (6, 1).
3. **Treasury** (tempter; treasure): open the office door (4, 14), `use` the ledger (7, 16) (`court_ledger_read`),
   `use` the portrait (12, 15) → "Swing her aside" (`court_treasury_found`), `walk_to`
   (12, 14) (the exit), arrive at (8, 2) in the vault; the glyph (7, 3)/(8, 3) is on the way (search first or take the
   hit); walk to (7, 5): `court_final_treasury`. Open `court_treasury_hoard` (7, 8).
4. **Gertruda** (find_gertruda): steps 3's ledger first, then walk to the stair hall door (36, 14) and the stairs up
   (41, 23); in the Rooms of Weeping walk to (19, 11), open the guest door (19, 12), `talk("gertruda")` → "The
   ledger" → "Come home" (`join gertruda`). Back down to (39, 22), walk to the landing: Rahadin intercepts at
   (22, 20) → "Then we go through you" (`court_rahadin_fight`) or Persuasion. Take the stairs (22, 23) and travel to
   the village of Barovia; enter `mad_marys_house`: Mary's homecoming (`gertruda_home`, `find_gertruda home`).
5. **Enemy rooms only** (Phase 6 exit test): set the reading's enemy to the card, then `go_to` the room's map and
   walk into the area; for the treasury set `court_treasury_found` first.

## 15. The back way behind the study, the smokestack and Strahd's tower (Dungeon Expansion Plan C3, K37 to K41 and K52)

Source: R. C. Veeder's area-by-area survey of the 2016 text (rcveeder.net, "Paths of Pain and Torment", K37 to K41 and
K52), read 2026-10-18. What it gives, and what we added:

| Book | Ours |
|---|---|
| K37, the study: the fireplace hides a passage to K38; going through it while the fire burns hurts (no number given) | The grate (`court_hearth_grate`, in front of the hearth): a search finds the plate and the passage (Investigation 14 or Perception 16, a try each), and the fire has to go out before the party crawls through. Ways: wait three hours, Create or Destroy Water, a bucket of water, or beat it out with a cloak (Dexterity 12; it burns 1d6 fire, or 2d6 on a failure: ours) |
| K38, the false treasury: a little money and a trapped chest of sleeping gas; if the whole party sleeps they wake four hours later in K50; one of two sconces lacks its torch, which a dead adventurer holds, and putting it back opens the way on | As the book. The gas: the chest's conversation rolls the party's best Constitution save (13, or 8 once the vent is found); a held breath keeps the party awake and takes the 35 gp; a failure is `time +240` and a `move` to the guest room (`from_gas`). A rope opens the lid from across the room with no roll. The torch comes from the skeleton (`court_way_skeleton`); the sconce takes any torch, which stays in it. A stone panel (the door `court_way_panel`) then opens |
| K39, the hall (the survey calls it the Hall of Riches; we keep the plan's "hall of webs"): webs fill it, a single-file path is cut through them, to a pair of ornate bronze doors; a secret door leads to K31b | The webs are difficult squares either side of a clear path along row 14, with wall webs; the bronze doors are `court_way_bronze_doors`. The reliefs on them (cast wolves chasing a stag through iron trees) are ours. K31b is C2's: the hall's side wall has no secret door yet, and C2 adds it |
| K40, the belfry: webs and a large rope; pulling it rings a huge bell and summons giant spiders (the number isn't given); a secret door leads to K41 | The rope (`court_way_rope`, a conversation) calls `court_way_spiders`: 8 giant spiders, at 185 Hit Points each (the stat block's 26 is for a level 3 party), spread round the walls so no burst takes more than six. 5 wins in 8 for the sharp test party at level 10 (tests/integration/test_scaled_fights_castle_belfry.gd, 12.9 rounds, 2 dropped on average). Not pulling it avoids the fight. The secret door (Search 17) at the belfry's north wall leads down a stair to the treasury's own stair, `from_court` (8, 2), so no square of the vault moved; leaving goes up the portrait stair as before |
| K52, the smokestack: the chimney over the K37 fireplace, five feet wide at the top, smoke harmful | The keep roof's stack (`spires_smokestack`, with the ash at its foot): two Athletics 12 climbs, one with the fire out (a bruise on a failure) and one while it burns (1d6 poison on a success, 2d6 on a failure: ours). The first success (`court_stack_climbed`) leaves a rope for good and opens the conversation's way down, a `move` to the study (`from_chimney`) |
| K41, the treasury: Daern's Instant Fortress nearly fills the room under a domed ceiling painted black with pitch and glowing crystal shards like stars; the treasure is 25,500 gp | The tower (story/fortress_site.gd's footprint and LocationFortress.stand, no fortress code of ours) stands in the north-east corner on 16 wall squares, door facing south, never opening: the door (`fortress_entry`, `when: "false"`) says it opens only at its owner's word. The dome is the vault's new mood (`ravenloft_vault`, a night blue with frost dust), four pale lights, and the line `enter:court_vault_dome`. The hoard stays where it was (the Tarokka container `court_treasury_hoard` at (7, 8)): coins at a quarter of the book's 21,500 gp (5400 + 1000 in the casket), the gems at the book's count and value, no new magic item |

Nothing that existed moved: the treasury's rows are as they were (the tower sits on wall squares, tests/integration/
test_court_back_way.gd checks every row), the court's, the roof's and the weeping's spawns and props are where they
were, and the new things are inserts (court: two spawns and the grate prop; roofs: the stack prop; weeping: `from_gas`;
treasury: the tower, the dome area, one exit that never opens, four lights, the hoard's gold and the casket's gems).

The way in from the King's Hall's portrait stays. The belfry's stair joins the same stair, so leaving the treasury is
always up to the King's Hall. The fight and the way back through the hearth are optional; none of it sets a main flag.

Words: every line is in narrative/castle_ravenloft/court_way.dialogue and the Narrator files (castle_ravenloft_court,
castle_ravenloft_spires). They were drafted by Gemini through the ai-bridge and edited here: the brief, the raw reply and
the edits are in docs/plans/gemini_dungeon/C3/. None is voiced yet. Known rough edge: the guest room's arrival plays the
Rooms of Weeping's own entering line (the stairs bringing you up), since a flag set before `move` can't be cleared again.
