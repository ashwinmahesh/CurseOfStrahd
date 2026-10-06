# Region design: the Old Svalich Road and Tser Pool (Phase 4)

Plan §6 row 3. Party level 4 on the road (level 3 if they skipped the burial); no milestone here: Vallaki gives the
next one. Source: *Curse of Strahd* chapters 1 (the Tarokka) and 2 (the lands of Barovia), retold in our own words: no
read-aloud text and none of the book's card verses are reproduced; every verse, card meaning and line is new writing.
Owner of this package: the Region 3 narrative designer. The data and dialogue files in §12 are the source of truth.

## 1. What this region is for

The campaign spine (plan §5.5, ADR 0010). On the road out of the village the party learns that Barovia is a land of
roads, and that the roads have their own weather: wolves by day, the dead by night, a funeral that isn't, a raven that
is more than a raven, and the lord of the land himself riding past to say good evening. At Tser Pool, Madam Eva reads
the Tarokka, and the seeded draw decides where the three treasures lie, who the destined ally is, and in which room of
Castle Ravenloft Strahd will wait. Two seeds give two different campaigns (Phase 4 exit).

Tone: dread with a wink (plan §2.4). The road is grim; the Vistani camp is the first warm firelight in the valley and
the most dangerous place to be rude. The jokes come from Madam Eva's bluntness, Stanimir's hospitality, Luminita's
contempt, and Strahd's manners.

## 2. Maps and the travel map

| Map | Size, theme | Areas (`enter:` triggers) | What happens |
|---|---|---|---|
| `svalich_crossroads` | 40x26, svalich_road, outdoors | `crossroads_west_road`, `ivlis_bridge`, `crossroads_gallows`, `crossroads_falls_track`, `crossroads_junction`, `crossroads_east_road`, `crossroads_south_road` | The stone bridge over the Ivlis (water is void until the art pass), the signpost, the gallows with Nicu hanging, the hanged men's field (night fight), a cache under the bridge (search 13). Exits to travel: east road, west road, falls track; the castle road south is shut (`when: false`) until Phase 6. |
| `tser_pool` | 44x30, svalich_road, outdoors | `tser_road`, `tser_pool_shore`, `tser_horse_pen`, `tser_camp` | The Vistani camp: wagons round a bonfire, the black pool, the horse pen (Luminita), Stanimir by the fire (speaks on approach), Madam Eva's great tent (exit to the interior), Stanimir's strongbox (lock 15, 40 gp). Rest: safe (the devil lets the camp be). Exits to travel: road west, road east. |
| `tser_pool_eva_tent` | 13x10, tavern (cut-away), dim | `eva_tent_inner` | Madam Eva at her table; the iron-bound chest (the Diviner's treasure); charms. No rest. |
| `tser_falls` | 34x22, svalich_road, outdoors | `falls_ledge`, `falls_path`, `falls_west_glade`, `falls_east_glade` | The falls and the overlook (Ireena's memory), the offering stone, the cairn of names, a lost pack (rope, torches, a potion of healing, 6 gp), a werewolf at the lip at night. Exit to travel: the path south. |
| `road_ambush` | 32x18, svalich_road, outdoors | `open_road` | Battlefield for the `svalich_road` table: an open road between ditches, a broken cart, field walls. `default` spawn on the road; exits both ways to travel. Holds `road_dead_procession`. |
| `road_forest` | 32x20, forest, outdoors | `forest_road` | Battlefield for the `svalich_woods` table: the road narrowing through pines, small clearings, a fallen trunk. Holds `road_hunters`. |

Village of Barovia: a `road_west` exit at [0, 12] now leads to the travel map (`when: flag.village_departed`, so the
departure scene at the `road_west_gates` posts plays first; locked text points at the posts).

**data/travel/barovia.json** (this package owns it). Places: the Gates of Barovia (`into_the_mists_road`, `default`),
the Village of Barovia (`from_west_road`), the Ivlis Crossroads, Tser Falls (`when: visited:svalich_crossroads`; the
signpost names it), Tser Pool, Vallaki (`vallaki`, spawn `from_road`). Later places from plan §6 are left out until
their locations exist (Old Bonegrinder will split the Tser Pool–Vallaki road; Castle Ravenloft opens the crossroads'
south road).

| Road | Hours | Table |
|---|---|---|
| Gates – Village | 0.5 | svalich_road |
| Village – Crossroads | 1.5 | svalich_road |
| Crossroads – Tser Pool | 1.5 | svalich_road |
| Crossroads – Tser Falls | 1 | svalich_woods |
| Tser Falls – Tser Pool | 0.5 | svalich_woods |
| Tser Pool – Vallaki | 4 | svalich_woods |

Village to Vallaki is seven hours on foot: leave at noon and the walls come into sight at dusk, which is the point.

## 3. Scene flow (all optional except the reading, which the campaign needs)

1. **The departure** (village, Phase 3's `road_west`). Ireena and Ismark join as guests when the escort is accepted
   (`join ireena`, `join ismark` added to the village's escort scenes; `road_west:depart` repeats the joins for old saves).
2. **The crossroads.** A young Vistana hangs from the gallows with a board round his neck: HORSE THIEF. Cut him down and
   bury him (rites by a cleric or Religion 12), take his silver earring for his people, examine him (Medicine 12 warns
   that the field is waiting for dark), or leave him. Left hanging, he and the old hanged dead rise when the party walks
   into the gallows field at night. Ireena remembers her father cutting such men down; the signpost gives her one line.
3. **Tser Falls** (detour). With Ireena: at the lip she remembers a fall that was not hers (Tatyana's). Pull her back,
   ask her (Insight 13), or say her own name to her. At night a werewolf is waiting there.
4. **Tser Pool.** Stanimir greets the party at the fire (on approach), shares wine, sells camp goods, tells the old
   story (the prince, his brother, the bride, the wall), and answers who the Vistani answer to (Insight 14). Luminita in
   the horse pen asks after her brother. Telling either of them what happened to Nicu (`nicu_kin_told`) makes the camp
   grateful: Madam Eva reads for free, Luminita gives a potion if he was cut down, and Stanimir offers to tell the
   castle the party went east (`stanimir_misdirects`). The strongbox under a wagon is a temptation with a price.
5. **Madam Eva's reading.** §5.
6. **The road on.** Random events and fights on both roads (§6), including Strahd riding past once.

## 4. NPCs (voice bibles in docs/voice/)

| id | Name | Where | Wants | Fears | Voice in a line | Stat block |
|---|---|---|---|---|---|---|
| `madam_eva` | Madam Eva | her tent | the curse ended, without being seen to care | dealing another party the cards that kill them | blunt, present-tense, prices before prophecy | none (never fights) |
| `stanimir` | Stanimir | the fire | the camp fed and moving, his sister's children safe | the mists closing on the Vistani | big hospitable patter; cold when crossed | bandit_captain (shop) |
| `luminita` | Luminita | horse pen | Nicu home | what has happened | dry, rude to strangers, kind to horses | scout |
| `bogdan` | Bogdan | road event | his mother buried blessed | the dark on the road | slow country courtesy | commoner |
| `grigor` | Grigor | woods event | the wolves dead, his nephews alive | losing a boy | clipped hunter's suspicion | warrior_veteran |
| `strahd` | Strahd | road event (once) | Ireena; a good game | being refused (hidden) | docs/voice/strahd.md | none (never fights here) |
| `ireena`, `ismark` | guests | with the party | Phase 3 bibles | | | noble, warrior_veteran |

New ally npc files for the Tarokka (minimal; their regions will flesh them out): `kolyan_indirovich` (village; the
Horseman's ally) and `kasimir_velikov` (Vallaki's lakeside camp; the Seer's ally; the Vallaki writer has no Kasimir yet).
Art needed: `stanimir`, `kasimir_velikov`; Luminita borrows `vistana`, Bogdan and Grigor `commoner`/`villager`.

## 5. Madam Eva's reading

**Structure** (narrative/svalich_road/madam_eva.dialogue):

1. **Greeting.** She expected them. Variants for Death House survivors and for arriving without the Vistani rumour.
   With Ireena present she stops shuffling: "You have come round again" (`eva_recognized_ireena`); with Tamsin's locket
   recognised, she tells him to keep the stolen face in his pocket.
2. **The price.** Ten gold; or **a true thing** one of them has never told: Ilse (the fever), Hedda (her god's silence
   since the mist), Silvain (Aurel, not scholarship), Tamsin (the locket was planted), or any character's untold secret.
   The party hears it (`eva_truth_teller`), and banter remembers. Also: Persuasion 15 to read for the valley's sake
   (once); Intimidation 18 (success: a cold, forced reading and a hostile Eva; failure: Stanimir in the tent door; back
   down at double price, or fight the camp outside the tent); refuse (quest `refused`, come back any time). If the party
   brought Nicu home, she waives it (`kin`). If the strongbox was robbed, she names it first: give it back, lie
   (Deception 18), or keep it and take a forced reading.
3. **The reading.** `tarokka draw`, then five `tarokka read`s, each introduced by a line naming what the card stands
   for (the past, a power of light, a weapon, a friend, where he waits). Silvain answers the Tome, Hedda the Symbol, Ilse
   the Sunsword (class-based fallbacks for created characters). The ally card gets reactions: Darklord (no ally: "Count
   off"), Ismark (himself, if travelling), Kolyan (Ireena: "We put him there"), Parriwimple, a Vallaki ally (Ireena: "At
   least the cards are economical"), Ezmerelda, Arabelle (hurry). Then the five quests are `foretold`.
4. **The Diviner.** If Stars 2 is drawn for a treasure, Eva hands it over from her chest; that quest moves to `found`
   (`tser_treasure_given`). The item itself waits on an engine need (§11).
5. **One question more** (`eva_question`): Ireena (keep her from heights and still water; she has fallen before),
   leaving Barovia (only through his end), how he is destroyed (all of it at once, and sunlight), Kestrel Company (some
   went in as guests; some walk his roads in his colours), the locket (her name was Tatyana), dawn (it comes but never
   arrives), Aurel (still reading), why us (pick the answer that lets you sleep), or nothing.
6. **Later visits:** hear the reading again (re-reads all five cards), a reading for one of you alone (`respec`, only if
   she is friendly), her age ("I knew him when he was young and only ambitious"), and what the Vistani are to the castle.

**The mapping** (data/tarokka/outcomes.json). One place per common card serves all three treasures (the adventure uses
one treasure table for all three); Eva's framing line names the slot. Castle ids name the book's rooms (K numbers) for
Phase 6 to map onto its floors. `?` marks cards I am not sure of.

| Card | Place | | Card | Place |
|---|---|---|---|---|
| Swords 1 Avenger | `argynvostholt_vladimir` (Vladimir Horngaard) | | Coins 1 Swashbuckler ? | `castle_ravenloft_gargoyle_tomb` |
| Swords 2 Paladin | `castle_ravenloft_sergeis_tomb` (K85) | | Coins 2 Philanthropist ? | `abbey_of_st_markovia_wards` |
| Swords 3 Soldier ? | `tsolenka_pass_guard_tower` | | Coins 3 Trader ? | `wizard_of_wines_press_house` |
| Swords 4 Mercenary | `castle_ravenloft_treasury` (K41) | | Coins 4 Merchant | `wizard_of_wines_cellar` (the empty cask) |
| Swords 5 Myrmidon | `werewolf_den_shrine` (Mother Night) | | Coins 5 Guild Member ? | `castle_ravenloft_wine_cellar` |
| Swords 6 Berserker | `castle_ravenloft_crypt_of_the_mad_dog` (K84) | | Coins 6 Beggar | `vallaki_vistani_camp:camp_edge` (Kasimir) |
| Swords 7 Hooded One | `amber_temple_faceless_god` | | Coins 7 Thief ? | `village_of_barovia:churchyard` |
| Swords 8 Dictator | `castle_ravenloft_audience_hall` (K25) | | Coins 8 Tax Collector | `vallaki_vistani_camp:luvash_wagon` (Arabelle missing) |
| Swords 9 Torturer ? | `vallaki_burgomaster_mansion:izek_quarters` (the dolls) | | Coins 9 Miser ? | `castle_ravenloft_hidden_hearth` |
| Warrior | `castle_ravenloft_strahds_tomb` (K86) | | Rogue ? | `castle_ravenloft_ravens_roost` |
| Stars 1 Transmuter ? | `castle_ravenloft_north_tower_peak` | | Glyphs 1 Monk | `abbey_of_st_markovia_shrine` |
| Stars 2 Diviner | `tser_pool_eva_tent` (Eva's chest) | | Glyphs 2 Missionary ? | `abbey_of_st_markovia_garden` (scarecrow) |
| Stars 3 Enchanter | `berez_marinas_monument` | | Glyphs 3 Healer | `krezk_pool_of_the_white_sun` |
| Stars 4 Abjurer | `argynvostholt_beacon` | | Glyphs 4 Shepherd | `castle_ravenloft_tomb_of_barov_and_ravenovia` (K88) |
| Stars 5 Elementalist | `amber_temple_entrance` | | Glyphs 5 Druid | `yester_hill_gulthias_tree` |
| Stars 6 Evoker | `castle_ravenloft_crypt_of_the_wizard` (K84) | | Glyphs 6 Anarchist | `castle_ravenloft_hall_of_bones` (K67) |
| Stars 7 Illusionist | `vallaki_blue_water_inn:rictavio_wagon` | | Glyphs 7 Charlatan | `old_bonegrinder` |
| Stars 8 Necromancer ? | `castle_ravenloft_study` (portrait over the hearth) | | Glyphs 8 Bishop | `amber_temple_vault` |
| Stars 9 Conjurer | `berez_baba_lysagas_hut` | | Glyphs 9 Traitor | `vallaki_wachter_house:wachter_study` |
| Wizard | `van_richtens_tower` | | Priest | `castle_ravenloft_chapel` (K15) |

| High card | Ally (`npc`, region) | Strahd waits (`room`) |
|---|---|---|
| Artifact ? | `rictavio` (vallaki) | `castle_ravenloft_chapel` (K15) |
| Beast | `emil_toranescu` (werewolf_den) | `castle_ravenloft_audience_hall` (K25) |
| Broken One | `mordenkainen` (van_richtens_tower; Mount Baratok) | `castle_ravenloft_sergeis_tomb` (K85) |
| Darklord | none (`npc: ""`, see §11) | `castle_ravenloft_strahds_tomb` (K86) |
| Donjon | `victor_vallakovich` (vallaki) | `castle_ravenloft_hall_of_bones` (K67) |
| Executioner | `ismark` (village_of_barovia) | `castle_ravenloft_overlook` (K6) ? |
| Ghost | `sir_godfrey_gwilym` (argynvostholt) | `castle_ravenloft_tomb_of_barov_and_ravenovia` (K88, his father) |
| Horseman ? | `kolyan_indirovich` (village_of_barovia; must be raised) | `castle_ravenloft_catacombs` (K84) ? |
| Innocent | `parriwimple` (village_of_barovia) | `castle_ravenloft_sergeis_tomb` (K85) |
| Marionette | `pidlwick_ii` (castle_ravenloft) | `castle_ravenloft_heart_of_sorrow` (K20) |
| Mists | `ezmerelda` (abbey_of_st_markovia; she wanders) | `castle_ravenloft` (anywhere; he moves) |
| Raven | `davian_martikov` (wizard_of_wines) | `castle_ravenloft_tomb_of_barov_and_ravenovia` (K88, his mother) |
| Seer | `kasimir_velikov` (vallaki) | `castle_ravenloft_study` (K37) |
| Tempter ? | `arabelle` (lake_zarovich) | `castle_ravenloft_treasury` (K41) |

**Vallaki areas named by outcomes** (the Vallaki writer's ids): `vallaki_burgomaster_mansion:izek_quarters`,
`vallaki_blue_water_inn:rictavio_wagon`, `vallaki_vistani_camp:camp_edge` (Kasimir), `vallaki_vistani_camp:luvash_wagon`,
`vallaki_wachter_house:wachter_study`. Each needs the treasure findable there when its card is drawn, plus
`kasimir_velikov`, `rictavio` and `victor_vallakovich` able to join as the ally. The village's churchyard needs a grave
to dig when Coins 7 is drawn (`tarokka.tome == coins_7` etc.).

## 6. Encounters (2024 DMG budgets for four characters: level 3 Low 600 / Moderate 900 / High 1600; level 4 Low 1000 / Moderate 1500 / High 2000)

Every fight sits at Moderate for a level 3 party and Low for level 4, never above High for either; Ismark (a veteran)
and Ireena travelling as guests make them easier. The Tser Pool brawl is a choice the party makes, not a test.

| id | Map | Trigger | Monsters | XP | L3 / L4 |
|---|---|---|---|---|---|
| `crossroads_hanged_dead` | svalich_crossroads | enter `crossroads_gallows` at night, Nicu not cut down | Nicu + 4 hanged dead (5 Strahd zombies) | 1000 | Moderate / Low |
| `tser_pool_brawl` | tser_pool | dialogue (Stanimir: "Come and take it") | 2 bandit captains, 2 bandits, 2 scouts (Vistani) | 1150 | Moderate / Low |
| `tser_pool_ambush` | tser_pool | enter `tser_camp` after the party chose to fight Eva's family | the same | 1150 | Moderate / Low (party surprised) |
| `falls_werewolf` | tser_falls | enter `falls_ledge` at night | werewolf, dire wolf, 2 wolves | 1000 | Moderate / Low (party surprised) |
| `road_dead_procession` | road_ambush | dialogue (the night procession) | 6 Strahd zombies | 1200 | Moderate / Low |
| `road_hunters` | road_forest | dialogue (Grigor's hunters) | warrior veteran, 3 scouts | 1000 | Moderate / Low |

**Random tables** (data/random_encounters/). `svalich_road` (map road_ambush), 15% by day, 40% by night:

| Entry | When | What | XP |
|---|---|---|---|
| wolves_shadowing (3) | day | 3 dire wolves, 2 wolves | 700 |
| funeral (2, once) | day | event: Bogdan's mother in her coffin, bitten | — |
| raven (2, once) | day | event: a raven walks beside you (Keepers of the Feather) | — |
| lost_pack (1, once) | day | event: a peddler's pack; drag marks to a clawed pine | — |
| strahd_rides (1, once) | any | event: Strahd on his black horse; no fight | — |
| wolf_pack_night (3) | night | 4 dire wolves, 4 wolves | 1000 |
| dead_on_the_road (2) | night | 5 Strahd zombies, 2 zombies | 1100 |
| bats_and_dead (2) | night | 3 swarms of bats, 4 Strahd zombies, a zombie | 1000 |
| dead_procession (1, once) | night | event: the dead carrying an empty coffin; hide (Stealth 13), turn them (cleric, Religion 14) or fight | (1200) |
| werewolf_night (1) | night | werewolf, dire wolf, 2 wolves | 1000 |

`svalich_woods` (map road_forest), 20% by day, 50% by night: wolves_in_the_pines (3, day: 3 dire wolves, 2 wolves,
700), hunters (2, once, day: Grigor; Persuasion 13, Insight 12, Intimidation 14, or Ireena vouches; fight 1000),
raven, lost_pack, strahd_rides (as above), wolf_pack_night (3: 4 dire wolves, 4 wolves, 1000), werewolves (2: werewolf,
dire wolf, 2 wolves, 1000), dead_in_the_trees (1: 5 Strahd zombies, 2 zombies, 1100), bats_and_wolves (1: 4 swarms of
bats, 4 dire wolves, 1000). Every monster cell was checked against its map (open floor, room for Large creatures, no
overlaps, at least 6 squares from the arrival spawn).

**Monsters I wished for** (not in data/monsters yet): needle blight and twig blight (the woods' signature hazard;
vine blights lead them), berserker (Barovian hunters and Vallaki deserters), ghost (the road's lost travellers),
revenant (Argynvostholt's knights on patrol), druid (Yester Hill's raiders on the road), mongrelfolk, and a
2024 "Vistana" stat block (bandit and bandit captain stand in).

## 7. Choices and consequences

| Choice | Where | Options | Immediate effect | Downstream |
|---|---|---|---|---|
| The hanged man | crossroads | cut down and bury (with rites or not); take the earring; leave him | buried: stays dead; left: rises at night with the field | Tser Pool's gratitude (`nicu_kin_told`): free reading, Luminita's potion, Stanimir's lie to the castle |
| Tell his kin | Tser Pool | tell Luminita or Stanimir; give the earring; never say | quest `told`; Vistani friendly | Eva waives her price; P4 Vallaki's Vistani may hear it (`nicu_kin_told`, `luminita_confessed`) |
| The strongbox | Tser Pool | rob it, then repay / lie / refuse | refuse: the brawl; lie: Stanimir blames his own; Eva knows | `vistani_robbed`, `stanimir_deceived`; Eva's price |
| How to pay Eva | tent | coin, a secret, persuasion, threat, kin | `eva_reading_paid`, `eva_truth_teller` | banter; Vallaki's Vistani (Arrigal) can read how the party treated Eva |
| Threaten Eva | tent | back down (double price) or fight the camp | `tser_pool_brawl_won`: camp empties | Strahd remarks on it; later Vistani hostile |
| The question | tent | nine questions | `eva_question` | P5/P6 pay-offs (Kestrel Company, Aurel, Tatyana, Ireena and water) |
| Strahd on the road | event | defy, courtesy, shield Ireena, draw steel, silence | `strahd_road_encounter`, `strahd_met` | later Strahd scenes |
| The bitten grandmother | event | stake her, rush her to the church, say nothing, never look | `anca_fate` | P5: a new vampire spawn in the village churchyard unless staked |
| The raven | event | feed, study, shoo, harm | `raven_fed` / `raven_harmed` | P5 Wizard of Wines (the Keepers of the Feather) |
| The hunters | event | talk, read, scare, fight; Ireena vouches | `hunters_befriended` (windmill and werewolf rumours) or a fight | `bonegrinder_rumor`, `werewolf_rumor` for P5 |
| Ireena at the falls | Tser Falls | pull her back, ask, name her | `ireena_falls_memory` | P5 Krezk (the pool), P6 (the castle wall) |

## 8. Ireena on the road

Ireena joins as a guest in the village (`join ireena`; `join ismark` if he comes). Guests don't interject, so her beats
are `Ireena:` lines behind `guest:ireena`: the gallows (her father cut hanged men down), the signpost (once), Tser Falls
(the memory), Stanimir (he knew her father), Madam Eva (recognition; "Who is Tatyana?"; the Kolyan ally), Bogdan (her
father dug his well), Grigor (he knows her on sight, and that settles the standoff), Strahd on the road (he asks if
they treat her well; she can be shielded), and two banters. Ismark has lines at the gallows, the signpost, the reading
(if he is the ally) and a banter about Tser Pool.

## 9. Flags (data/flags/svalich_road.json)

Every flag below is registered, set and read (generated from the files). This region also sets the village's
`strahd_met` (Strahd on the road), `bonegrinder_rumor` (Grigor) and `vistani_spies_suspected` (Stanimir), and reads
`death_house_completed`, `madam_eva_rumor`, `tamsin_locket_recognized`, `strahd_first_impression`, `doru_freed`,
`donavich_refused_rites` and `burgomaster_buried`.

| Flag | Type | Meaning | Set by | Read by |
|---|---|---|---|---|
| `crossroads_gallows_seen` | bool | The party has seen the hanged Vistana (Nicu) on the gallows at the Ivlis crossroads. Starts the_hanged_vistana. | crossroads | banter, crossroads, luminita, stanimir |
| `nicu_body_examined` | bool | The party has made its one attempt to examine the hanged man (Medicine). | crossroads | crossroads |
| `nicu_token_taken` | bool | The party took Nicu's silver horse's-head earring from the body, to bring to his people. | crossroads | crossroads, luminita, stanimir |
| `nicu_cut_down` | bool | The party cut Nicu down from the gallows (or gathered his remains) and buried him by the road; he will not rise. | crossroads | banter, crossroads, luminita, map:svalich_crossroads, narrator, stanimir |
| `nicu_rites_said` | bool | Rites were said over Nicu's grave (a cleric, or a Religion check). | crossroads | banter, stanimir |
| `crossroads_dead_cleared` | bool | Nicu and the old hanged dead of the gallows field rose at night and were destroyed (encounter crossroads_hanged_dead). | map:svalich_crossroads (crossroads_hanged_dead) | banter, crossroads, luminita, narrator, stanimir |
| `ireena_crossroads` | bool | Ireena (as a guest) has remarked on the crossroads signpost; plays once. | crossroads | crossroads |
| `tser_pool_arrived` | bool | Stanimir has welcomed the party to the Tser Pool camp. | stanimir | stanimir |
| `stanimir_wine_shared` | bool | The party shared Stanimir's plum wine. | stanimir | stanimir |
| `stanimir_tale_heard` | bool | Stanimir told the party the story of the prince, his brother and the bride (Strahd, Sergei, Tatyana). | stanimir | stanimir, tser_falls |
| `stanimir_read` | bool | The party has made its one Insight attempt on whom the Vistani answer to. | stanimir | stanimir |
| `stanimir_misdirects` | bool | Grateful for news of Nicu, Stanimir will tell the castle the party went east. Later regions may soften Strahd's spies' reports. | stanimir | banter, madam_eva; P5+ |
| `vistani_robbed` | bool | The party opened Stanimir's strongbox at Tser Pool (container flag). | map:tser_pool (stanimir_strongbox) | banter, madam_eva, stanimir; P4 Vallaki |
| `vistani_repaid` | bool | The party gave back the forty gold taken from Stanimir's strongbox. | madam_eva, stanimir | banter, madam_eva, stanimir |
| `stanimir_deceived` | bool | The party lied its way out of the strongbox theft; Stanimir blames his own people. Madam Eva knows. | madam_eva, stanimir | banter, madam_eva, stanimir |
| `vistani_turned_hostile` | bool | The party drew steel on Madam Eva and chose to fight the camp; the Vistani wait outside her tent (encounter tser_pool_ambush). | madam_eva | map:tser_pool, stanimir |
| `tser_pool_brawl_won` | bool | The party fought the Tser Pool Vistani and won; Stanimir and Luminita are gone, the camp is empty. Later regions: Vistani across Barovia hear of it. | map:tser_pool (tser_pool_ambush), map:tser_pool (tser_pool_brawl) | banter, events, madam_eva, map:tser_pool, narrator; P4 Vallaki, P5 |
| `luminita_met` | bool | The party has spoken with Luminita in the horse pen. | luminita | luminita |
| `luminita_confessed` | bool | Luminita admitted the mare Nicu sold in Vallaki was one she found loose with a Vallaki brand. | luminita | banter; P4 Vallaki |
| `nicu_kin_told` | bool | The party told Luminita or Stanimir what became of Nicu (quest the_hanged_vistana told). The Tser Pool Vistani are grateful; Madam Eva reads for free. | luminita, stanimir | luminita, madam_eva, narrator, stanimir; P4 Vallaki |
| `eva_met` | bool | The party has met Madam Eva in her tent. | madam_eva | madam_eva, stanimir |
| `eva_recognized_ireena` | bool | Madam Eva greeted Ireena as someone who has 'come round again' (Tatyana's soul). Later regions may read it. | madam_eva | banter; P5 Krezk, P6 |
| `eva_haggle_failed` | bool | Madam Eva refused to read for free; the Persuasion option is gone. | madam_eva | madam_eva |
| `eva_threatened` | bool | The party threatened Madam Eva in her tent (Intimidation). | madam_eva | stanimir; P4 Vallaki |
| `eva_reading_paid` | string | How the Tarokka reading was paid: coin, truth, free (Persuasion), kin (news of Nicu) or forced (threat, theft or the brawl). Later regions (Vallaki's Vistani) may read it. | madam_eva | banter, madam_eva; P4 Vallaki |
| `eva_truth_teller` | string | Who paid Madam Eva with a secret: ilse_varga, hedda_ironvow, silvain_aster, tamsin_tealeaf, or other. The party heard it. | madam_eva | banter; P5+ |
| `eva_reading_done` | bool | Madam Eva has read the Tarokka for the party; the five quests are foretold. | madam_eva | madam_eva, narrator, stanimir |
| `tser_treasure_given` | bool | The Diviner was drawn for a treasure, and Madam Eva handed it over from her chest (the item itself waits on an engine need). | madam_eva | banter, narrator; P5/P6 |
| `eva_question` | string | The party's one question after the reading: ireena, escape, weakness, kestrel, locket, dawn, aurel, why or none. Later regions may pay it off. | madam_eva | banter; P5/P6 |
| `ireena_falls_memory` | bool | At Tser Falls, Ireena remembered a fall that wasn't hers (Tatyana). Later regions (Krezk, the castle) may read it. | tser_falls | banter, tser_falls; P5 Krezk, P6 |
| `falls_werewolf_slain` | bool | The party killed the werewolf waiting at the lip of Tser Falls at night (encounter falls_werewolf). | map:tser_falls (falls_werewolf) | banter, narrator |
| `strahd_road_encounter` | string | How the party met Strahd riding on the road: defiant, courteous, shield, violent or silent. Later Strahd scenes may read it. | events | banter, events; P5/P6 |
| `funeral_met` | bool | The party met Bogdan's funeral cart on the road (event, once). | events | events |
| `anca_examined` | bool | The party looked at Bogdan's mother in her coffin (a Medicine check or a cleric's blessing). | events | events |
| `anca_fate` | string | The bitten old woman in the coffin: staked, warned (rushed to the church), unwarned (the party saw the marks and said nothing) or unknown. Phase 5 may raise her in the village churchyard. | events | banter, events; P5 village |
| `dead_procession_met` | bool | The party met the procession of the dead on the road at night (event, once). | events | events |
| `dead_procession_turned` | bool | A cleric turned the dead procession back to its graves. | events | banter |
| `dead_procession_destroyed` | bool | The party destroyed the dead procession (encounter road_dead_procession). | map:road_ambush (road_dead_procession) | banter |
| `ravens_met` | bool | A raven walked beside the party on the road (event, once). | events | events |
| `raven_studied` | bool | The party has made its one Nature check on the raven. | events | events |
| `raven_fed` | bool | The party fed the raven; the Keepers of the Feather (Wizard of Wines, Phase 5) know them as friends. | events | banter; P5 Wizard of Wines |
| `raven_harmed` | bool | The party struck the raven down; the Keepers of the Feather (Phase 5) remember. | events | banter; P5 Wizard of Wines |
| `hunters_met` | bool | The party met Grigor's wolf hunters in the Svalich Woods (event, once). | events | events |
| `hunters_read` | bool | The party has made its one Insight check on the hunters. | events | events |
| `hunters_befriended` | bool | Grigor's hunters took the party for friends and shared news of the windmill and the werewolves. | events | banter; P5 |
| `hunters_fought` | bool | The party fought Grigor's hunters on the road (encounter road_hunters). | map:road_forest (road_hunters) | banter |
| `werewolf_rumor` | bool | The party has heard of, or found the marks of, werewolves in the hills above Lake Zarovich (Phase 5 Werewolf Den). | events | banter; P5 Werewolf Den |
| `lost_bundle_found` | bool | The party found the lost peddler's pack on the road (event, once). | events | events |
| `lost_bundle_tracked` | bool | The party has made its one Survival check on the peddler's drag marks. | events | events |

## 10. What later regions read

- **The reading:** `tarokka.<slot>` conditions and `{tarokka.<slot>.hint}` in journals; the five quests
  `find_the_tome`, `find_the_holy_symbol`, `find_the_sunsword` (`foretold` → `found`), `find_the_ally` (`foretold` →
  `found` or `lost`) and `strahds_lair` (`foretold` → `confronted` → `destroyed`). Each region that hides a treasure moves
  its quest to `found` when the party takes it; the ally's region moves `find_the_ally`.
- **Vallaki (P4):** `nicu_kin_told`, `luminita_confessed` (the mare carried a Vallaki brand; Arrigal's camp may know),
  `eva_reading_paid`, `eva_threatened`, `tser_pool_brawl_won`, `vistani_robbed` (how the Vistani at the lake greet the
  party); the Vallaki outcome areas in §5; `kasimir_velikov`; `stanimir_misdirects` (the castle's spies are a step
  behind); `tser_treasure_given`.
- **Phase 5:** `anca_fate` (village churchyard), `raven_fed` / `raven_harmed` (Wizard of Wines), `werewolf_rumor`,
  `hunters_befriended` (Werewolf Den), `bonegrinder_rumor` (Old Bonegrinder), `ireena_falls_memory`,
  `eva_recognized_ireena` and `eva_question == "ireena"` (Krezk and the pool), `eva_question` (Kestrel Company, Aurel,
  the locket), `strahd_road_encounter`.
- **Phase 6:** `strahd_road_encounter` (Strahd: "Not on the road... in my house"), `eva_question`, the enemy card's room.

## 11. Engine needs (the format can't express these; nothing is worked around in data)

- **Giving a treasure.** `give`, container `items` and prop `item` are validated against data/items only, so
  `give tome_of_strahd` (and the symbol and sword, all in data/magic_items, which the Compendium already loads) fails
  `make validate`. The Diviner hand-over in Eva's tent sets the quest to `found` and `tser_treasure_given` with a comment
  where the `give` belongs; every later treasure room hits the same wall.
- **No ally.** The Darklord's ally outcome is "none", but `npc` is required and checked. It holds `""` with region
  `castle_ravenloft` (listed as pending) and a `note`; the validator and `find_the_ally` should treat an empty npc as no
  ally (the hint already says so).
- **Respec switch.** No condition tells whether the owner switched respec off, so Eva's "read for one of you alone"
  option shows (and does nothing) when it's off, and can't safely be priced (the plan calls it a paid reading). A
  condition such as `option:respec` would fix both.
- **Rest lines by place.** Narrator `rest:` triggers merge across regions and prefer conditioned variants, and there is
  no condition for "the party is in location X", so Tser Pool's safe camp has no rest narration. `location:<id>` or
  `here:<region>` would allow it.
- **Guests speaking.** Interjection selectors only find party members, so every Ireena and Ismark line sits behind
  `if guest:...`. An `interject guest:ireena:` selector would read better.
- **Time in dialogue.** Burying Nicu or walking with Bogdan should cost an hour; no statement advances the clock.
- **Water.** The Ivlis and Tser Pool are void cells (impassable, drawn as nothing); a water tile in the legend would let
  the art pass draw them.
- **Random-table cells** are not checked against their map by `make validate` (this package checked them by script).
- **`tarokka read <slot> <speaker>`:** the contract allows a speaker; the linter's pattern doesn't (unused here).

## 12. Files

- Region doc: docs/regions/svalich_road.md
- Voice: docs/voice/{madam_eva, stanimir, luminita, road_folk}.md
- NPCs: data/npcs/{madam_eva, stanimir, luminita, bogdan, grigor, kolyan_indirovich, kasimir_velikov}.json
- Locations: data/locations/{svalich_crossroads, tser_pool, tser_pool_eva_tent, tser_falls, road_ambush, road_forest}.json;
  village_of_barovia.json gained only the `road_west` travel exit
- Travel and tables: data/travel/barovia.json; data/random_encounters/{svalich_road, svalich_woods}.json
- Tarokka: data/tarokka/{cards, outcomes}.json; treasures: data/magic_items/{tome_of_strahd, holy_symbol_of_ravenkind, sunsword}.json
- Quests: data/quests/{madam_evas_reading, find_the_tome, find_the_holy_symbol, find_the_sunsword, find_the_ally,
  strahds_lair, the_hanged_vistana}.json
- Flags: data/flags/svalich_road.json
- Dialogue: narrative/svalich_road/{madam_eva, stanimir, luminita, crossroads, tser_falls, events}.dialogue;
  narrative/narrator/svalich_road.dialogue; narrative/banter/svalich_road.dialogue; the village's ireena.dialogue
  (`join ireena`, `join ismark`) and road_west.dialogue (the joins repeated at departure)
