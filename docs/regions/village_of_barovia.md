# Region design: the Village of Barovia (Phase 3)

Plan §6 row 2. Party level 3 on arrival (after Death House), level 4 after the burial (`xp milestone`).
Source: *Curse of Strahd* chapter 3, retold in our own words. Owner of this package: the Village narrative designer.
Implementation reads this doc; the data and dialogue files listed at the end are the source of truth for exact text.

## 1. What this region is for

Phase 3 exit: the player meets Ismark and Ireena and makes the first meaningful choices. The village is the
campaign's first hub: a place of shut doors and frightened people, where every NPC is a small trap of kindness or
cruelty, and where Strahd introduces himself in person. Everything the party decides here is a flag Phase 4
(Old Svalich Road, Tser Pool, Vallaki) reads.

Tone: dread with a wink (plan §2.4). The village is grey, muddy and starving; the jokes come from the people
(Ismark's gallows wit, Bildrath's stinginess, Morgantha's sweetness, Arik's silence, Strahd's manners).

## 2. Layout and scenes

Six maps (data/locations/). The exterior is one 40 x 30 grid; interiors are separate maps joined by exits.

| Map | Areas (enter: triggers) | What happens |
|---|---|---|
| `village_of_barovia` (exterior) | `mansion_yard`, `north_lane`, `churchyard`, `village_road_west`, `village_square`, `village_road_east`, `mary_lane`, `mercantile_front`, `back_lanes`, `death_house_lot` | Muddy streets, boarded houses, the square and its dry well, Morgantha and her pastry cart, the burial in the churchyard, Strahd at the lych-gate, the road west toward the crossroads, Tser Pool and Vallaki (the Gates of Barovia lie east, on Into the Mists' map). |
| `blood_of_the_vine` | `tavern_common_room`, `tavern_bar`, `tavern_back_room` | Ismark drinking alone, Arik the barkeep, the three Vistani women; the satchel and last note of Silvain's lost colleague Aurel Mirescu. |
| `burgomaster_mansion` | `mansion_hall`, `mansion_study`, `mansion_kitchen`, `mansion_parlor`, `mansion_wake_room` | Ireena, her father's coffin, claw-scored doors, the optional night vigil (siege). |
| `village_church` | `church_nave`, `church_altar`, `church_vestry`, `undercroft_stairwell`, `undercroft` | Father Donavich praying over his son's screams; Doru in the undercroft. One map with two walled regions; the stairs are an exit to a spawn on the same map. |
| `bildraths_mercantile` | `mercantile_shop`, `mercantile_storeroom` | Bildrath's ten-times prices, Parriwimple, the strongbox. |
| `mad_marys_house` | `mary_front_room`, `gertruda_room`, `mary_bedroom` | Mad Mary and the empty room her daughter Gertruda left by the window. |

Connections: each interior's door is an exit on the building's wall in the exterior, and an exit back to a
`from_<place>` spawn. The Death House door (exterior `death_house_door`) leads to `death_house_ground`, spawn
`from_village`; Death House's front door should lead to `village_of_barovia`, spawn `from_death_house`. The east road
spawn `from_east_road` is where Into the Mists' `into_the_village` exit arrives (the Gates of Barovia are on that map). The west road has no exit yet (Phase 4 adds the travel map); its prop
`road_west_gates` runs the departure scene.

### Scene flow (the expected path; every step is optional except where noted)

1. **Out of Death House.** The party leaves the house onto its weedy lot (`from_death_house`). Narrator first sight of
   the village. Death House flags colour the lot's narration and two conversations (§7).
2. **The square.** Morgantha (by day, until the burial) sells dream pastries from a cart. Bildrath's Mercantile and the
   Blood of the Vine face the square. Sobbing carries from Mad Mary's lane.
3. **Blood of the Vine.** Ismark asks for two things: help bury his father, and take his sister Ireena to Vallaki.
   The Vistani women point the party toward Madam Eva at Tser Pool (Phase 4) and quietly report on them.
4. **The mansion.** Ireena opens the barred door (to Ismark's name, or to a Persuasion check if the party comes
   alone). She will not leave until her father is buried. The party can stand watch one night (siege fight).
5. **The church.** Father Donavich agrees to say the rites, or doesn't, depending on what the party does about Doru.
6. **The undercroft.** Doru: free him, destroy him, or leave him locked.
7. **The burial.** The coffin goes from the mansion to the churchyard (`burial_procession`). Rites by Donavich, by a
   party cleric, by someone who remembers the words, or none. The grave is filled; the party reaches level 4.
   Strahd appears at the lych-gate (or, if Doru was freed, sends Doru with his message). Defiance or a hasty burial
   wakes the churchyard dead.
8. **The escort choice.** At the grave, Ireena asks to be taken west: Vallaki (Ismark's plan) or Krezk, with or
   without Ismark, or not at all. The `road_west_gates` prop plays the departure and hands over to Phase 4.

## 3. NPCs (voice bibles in docs/voice/)

| id | Name | Where | Wants | Fears | Voice in a line | Stat block |
|---|---|---|---|---|---|---|
| `ismark` | Ismark Kolyanovich | tavern, then mansion; graveside | Ireena safe, father buried, to be more than "the Lesser" | failing his sister as he failed his father | weary gallows wit, a soldier's bluntness, a drinker's honesty | warrior_veteran (guest) |
| `ireena` | Ireena Kolyana | mansion parlor; graveside; then the party (guest) | to bury her father properly, then to stop being hunted | the dreams, the bites, that she is not who she thinks she is | proud, direct, dry; refuses pity | noble (guest) |
| `donavich` | Father Donavich | church altar; graveside | his son saved, his faith back | that the Morninglord has left Barovia; that he will open the door | hoarse prayer-speech, apology, sudden flashes of the preacher he was | priest_acolyte |
| `doru` | Doru | undercroft | blood; under it, his father's forgiveness | the hunger winning; the castle | wheedling, boyish, then a starved snarl | vampire_spawn |
| `bildrath` | Bildrath Cantemir | mercantile | money, order, never to be cheated | waste, credit, change | prim shopkeeper precision; every sentence a price | commoner |
| `parriwimple` | Parriwimple | mercantile; graveside if hired | to be useful and liked | his uncle's disappointment | slow, earnest, literal; counts things | tough |
| `mad_mary` | Mad Mary | her townhouse | Gertruda home | that Gertruda left because of her | grief in circles, sharp lucid edges | commoner |
| `morgantha` | Morgantha | the square with her cart | customers, and their children | nothing in this village | sugar, endearments, appraisal | night_hag |
| `arik` | Arik | behind the bar | nothing, visibly | nothing, visibly | one to four words, flat | commoner |
| `alenka`, `mirabel`, `sorvia` | the Vistani women | tavern corner table | wine, amusement, news for their patron | the mists closing on them | Alenka honeyed, Mirabel mocking, Sorvia blurting (one bible: vistani_women.md) | commoner |
| `strahd` | Strahd von Zarovich | the lych-gate at the burial | Ireena; to be entertained by the new arrivals | being bored; being refused (he hides it) | elegant, courteous, mocking, warm in the worst way | none yet (not fought here) |

## 4. Quests (data/quests/)

| id | Giver | Stages (in order the journal can show them) |
|---|---|---|
| `bury_the_burgomaster` | Ismark | `asked` → `find_a_priest` → `priest_agreed` or `no_priest` → `procession` → `buried` (success) |
| `escort_ireena` | Ismark | `asked` → `ready` → `accepted` or `declined` → `departed` (Phase 4 continues; no stage ends it here) |
| `the_priests_son` | Donavich | `heard` → `cure_promised` (optional) → `doru_destroyed` (success) or `doru_freed` (failure) or `doru_left` (open; Phase 5 may return) |
| `find_gertruda` | Mad Mary | `heard` → `promised` or `refused` → `window_clue` (optional; Phase 6 resolves her in Castle Ravenloft) |

## 5. Encounters (2024 DMG budgets, four level 3 characters: Low 600, Moderate 900, High 1600)

| id | Map | Trigger | Monsters | XP | Band |
|---|---|---|---|---|---|
| `mansion_siege` | burgomaster_mansion | `flag:mansion_vigil` (the party chooses to stand watch) | 2 dire wolves, 2 Strahd zombies, 2 zombies | 900 | Moderate |
| `doru_undercroft` | village_church | dialogue (`combat doru_undercroft`) | Doru (vampire spawn) | 1800 | above High (see note) |
| `churchyard_dead` | village_of_barovia | dialogue (burial: Strahd defied or attacked, or a hasty burial) | 4 Strahd zombies, 2 zombies | 900 | Moderate |
| `night_streets_dead` | village_of_barovia | `enter_area:village_square` at night | 2 Strahd zombies, 4 zombies | 600 | Low |

Doru is the adventure's vampire spawn and is deliberately over budget (1800 vs High 1600): the party is warned by
Donavich, by the screams and by an Insight check, and has two non-violent outs. Donavich gives two flasks of holy water
if he is friendly or gives his blessing, and the vestry chest holds two more; the narrow stair is a choke point. If
playtests show it is too punishing, the cleanest fix is an encounter-level HP override ("starved: 60 HP"), which the
location format cannot express yet.

`night_streets_dead` only fires when `night` is true; Phase 3 may not have a day/night clock yet, in which case it is
dormant until Phase 4.

## 6. Choices and their consequences

| Choice | Where | Options | Immediate effect | Downstream (who reads it) |
|---|---|---|---|---|
| Help Ismark | tavern | agree; press for payment (Persuasion 12: the burgomaster's strongbox); refuse | quests start; `ismark_offered_strongbox` | Ireena reacts if the strongbox is opened without leave |
| Bury the burgomaster, and how | church, mansion, churchyard | Donavich's rites; a party cleric's rites; lay words (Religion 12); hasty, no words | `burial_method`; Ireena's attitude; hasty wakes the dead | Phase 4 Ireena dialogue; Phase 5 may raise an unblessed Kolyan |
| Doru | undercroft, church | free him; destroy him (with or without Donavich's blessing); leave him locked; promise a cure | Donavich officiates or refuses; Doru delivers Strahd's message if freed | Phase 4/5: a freed Doru hunts the roads; a locked Doru is still below the church; a promised cure is remembered |
| Stand watch at the mansion | mansion | keep the vigil (siege fight) or not | Ireena and Ismark warm to the party | Ireena's trust (attitude) in Phase 4 |
| Strahd at the grave | churchyard | defy; threaten (Intimidation 20); courtesy; attack; silence | `strahd_first_impression`; defiance or violence wakes the dead | Phase 4+ Strahd scenes open with the party's first answer |
| Escort Ireena | churchyard / mansion | Vallaki; Krezk; with or without Ismark; not now; refuse | Ireena joins as a guest; quest stage | Phase 4 escort, Vallaki arrival, Tser Pool |
| Morgantha's pastries | square | buy one or three; eat a sample (dream); refuse; see through her (Insight 15, Medicine 15); drive her off (Intimidation 13) | `dream_pastries_bought`, `dream_pastry_eaten`, `morgantha_suspected`, `morgantha_driven_off` (her cart leaves the square) | Phase 5 Old Bonegrinder: she knows her customers and remembers who threatened her; suspicion opens options |
| Mad Mary's daughter | Mary's house | promise to look; refuse; tell her the window was opened from inside | quest `find_gertruda` | Phase 6: Gertruda in Castle Ravenloft |
| Rob Bildrath | storeroom strongbox | open it (lock 15) or not | Bildrath accuses, bans or forgives | Phase 4 can read `bildrath_robbed` for reputation |
| Hire Parriwimple | mercantile | befriend him, or pay his uncle | he carries the coffin and digs the grave | burial scene line; Phase 4 reputation |

## 7. Reacting to Death House (flags owned by the Into the Mists / Death House writer)

The village reads these Death House flags; they are registered and set in the Death House package.

| Flag | Read by |
|---|---|
| `death_house_children_at_rest` | banter, donavich, ismark, narrator |
| `death_house_children_riding` | donavich |
| `death_house_completed` | burial, ireena, ismark, narrator, vistani |
| `death_house_refused` | donavich, ismark, narrator |
| `death_house_sacrificed` | banter, donavich, ismark, narrator |

- Ismark's first meeting: a different greeting if the party came out of the house (`death_house_completed`), a
  remark on the house screaming and bricking itself up (`death_house_refused`), a long look at their hands
  (`death_house_sacrificed`), and thanks if Rose and Thorn are at rest.
- Father Donavich's first meeting: he smells a failed funeral on a party that made the offering, heard the bell ring
  when the house turned on a party that refused, sees two small passengers over the shoulder of a party carrying the
  children (`death_house_children_riding`), or blesses the party that laid them to rest.
- Ireena, the Vistani and Strahd only mention the house if the party came out of it (`death_house_completed`).
- The Death House lot and facade narration, and one banter, change with the outcome.

## 8. Phase 4 hand-off (read these)

- Quest stages: `escort_ireena` (`accepted`, `declined`, `departed`), `the_priests_son`, `find_gertruda`.
- `ireena_escort` ("accepted" / "later" / "declined"; leaving by the west road without her sets "declined"),
  `ireena_destination` ("vallaki" / "krezk"), `ireena_in_party`,
  `ismark_joins_escort`, `village_departed`.
- `burial_method` ("church_rites", "cleric_rites", "lay_rites", "hasty"), `burgomaster_buried`.
- `strahd_first_impression` ("defiant", "courteous", "violent", "silent"; unset if Doru carried the message), `strahd_met`.
- `doru_destroyed`, `doru_freed`, `doru_left_locked`, `doru_cure_promised`, `donavich_mercy_blessing`.
- `madam_eva_rumor` (the Vistani sent you to Tser Pool), `vistani_spies_suspected`.
- `ireena_bite_seen`, `tamsin_locket_recognized`, `ilse_invitation_shown`, `holy_symbol_rumor`, `scholar_notes_found`.
- `dream_pastries_bought` (int), `dream_pastry_eaten`, `morgantha_suspected`, `morgantha_driven_off`,
  `bonegrinder_rumor` (Phase 5).
- `gertruda_search_promised` (Phase 6), `wine_shortage_heard` (Phase 5 Wizard of Wines), `bildrath_robbed`.
- Attitudes: `ireena`, `ismark`, `donavich`, `bildrath`, `mad_mary` change in these conversations.
- The west road needs an exit to the travel map at [0, 12] (the `road_west_gates` prop's departure scene sets
  `village_departed` first) with a `from_village` spawn on the other side; the village has a `from_west_road` spawn
  at [2, 12] for the way back.

## 9. Flags (data/flags/village_of_barovia.json)

Every flag below is registered, set and read (generated from the files). "P4"/"P5"/"P6" marks flags a later
phase is expected to read too.

| Flag | Type | Meaning | Set by | Read by |
|---|---|---|---|---|
| `ismark_met` | bool | The party has met Ismark at the Blood of the Vine; he moves to the mansion. | ismark | arik, banter, ireena, map:blood_of_the_vine, map:burgomaster_mansion, map:village_of_barovia, narrator, road_west |
| `ismark_the_lesser_heard` | bool | Someone (Arik or the Vistani) told the party Ismark's nickname, 'the Lesser'. | arik, vistani | ismark |
| `ismark_offered_strongbox` | bool | Ismark, pressed for payment, offered the burgomaster's strongbox. | ismark | ireena, ismark |
| `mansion_strongbox_opened` | bool | The burgomaster's strongbox in the mansion study has been opened. | map:burgomaster_mansion (mansion_strongbox) | ireena, ismark |
| `strongbox_theft_noticed` | bool | Ismark or Ireena has remarked on the strongbox being opened without leave. | ireena, ismark | ireena, ismark |
| `ireena_met` | bool | The party has spoken with Ireena in the mansion. | ireena | ireena, ismark, road_west |
| `ireena_door_opened` | bool | Ireena opened the barred mansion door to the party before Ismark vouched for them. | ireena | map:village_of_barovia |
| `ireena_bite_seen` | bool | A party member saw the two bite marks on Ireena's neck. | ireena | banter, burial; P4 |
| `tamsin_locket_recognized` | bool | Tamsin showed Ireena the locket: the portrait has her face. | ireena | banter, burial; P4+; Tatyana |
| `ilse_invitation_shown` | bool | Ilse showed Ismark the letter signed with an S; Strahd remarks on it at the burial. | ismark | burial |
| `burial_agreed` | bool | The party agreed to help bury the burgomaster. | ireena, ismark | bildrath, donavich, ireena, ismark, parriwimple |
| `donavich_met` | bool | The party has spoken with Father Donavich. | donavich | donavich |
| `donavich_will_officiate` | bool | Father Donavich agreed to say the burial rites. | donavich | burial, donavich, ireena, map:village_church, map:village_of_barovia |
| `donavich_refused_rites` | bool | Father Donavich refuses to bury the burgomaster (Doru was destroyed against his wishes). | donavich | burial, donavich, ireena, map:village_church, map:village_of_barovia |
| `donavich_knows_fate` | bool | Donavich has reacted to Doru being destroyed or freed. | donavich | donavich |
| `donavich_mercy_blessing` | bool | Donavich gave the party leave to destroy Doru as a mercy. | donavich | burial, donavich, doru, map:village_church, map:village_of_barovia; P5 |
| `donavich_mercy_refused` | bool | Donavich refused the party's plea to end Doru's suffering. | donavich | donavich |
| `donavich_gave_holy_water` | bool | Donavich gave the party two flasks of holy water. | donavich | donavich |
| `vestry_chest_opened` | bool | The church vestry chest (holy water, candles) has been opened. | map:village_church (vestry_chest) | donavich |
| `undercroft_unbarred` | bool | Donavich lifted the bar on the undercroft door. | donavich | donavich, map:village_church |
| `doru_revealed` | bool | Donavich admitted the voice under the church is his son Doru. | donavich | donavich |
| `doru_spoken_to` | bool | The party spoke with Doru in the undercroft. | doru | donavich |
| `doru_destroyed` | bool | Doru the vampire spawn was destroyed (encounter doru_undercroft). | map:village_church (doru_undercroft) | banter, burial, donavich, map:village_church, map:village_of_barovia, narrator; P5 |
| `doru_freed` | bool | The party let Doru out of the undercroft; he fled toward the castle. | doru | banter, burial, donavich, ireena, map:village_church, narrator; P4 |
| `doru_left_locked` | bool | The party chose to leave Doru locked in the undercroft. | donavich, doru | donavich; P5 |
| `doru_cure_promised` | bool | The party promised Donavich to look for a way to save Doru. | donavich | donavich; P5 |
| `holy_symbol_rumor` | bool | Donavich told Hedda of the Holy Symbol of Ravenkind. | donavich | banter; P4 |
| `burial_procession` | bool | The coffin has left the mansion for the churchyard; NPCs move to the grave. | ireena | ireena, ismark, map:bildraths_mercantile, map:burgomaster_mansion, map:village_church, map:village_of_barovia, narrator |
| `parriwimple_pallbearer` | bool | Parriwimple (hired or befriended) carries the coffin and digs the grave. | bildrath, parriwimple | bildrath, burial, ireena, ismark, map:bildraths_mercantile, map:village_of_barovia, narrator, parriwimple |
| `parriwimple_befriended` | bool | The party was kind to Parriwimple; he'll help for free. | parriwimple | bildrath, parriwimple |
| `burial_method` | string | How the burgomaster was buried: church_rites, cleric_rites, lay_rites or hasty. | burial | banter, burial, ireena, narrator; P4 |
| `burgomaster_buried` | bool | Kolyan Indirovich is buried in the churchyard. | burial | bildrath, donavich, ismark, map:bildraths_mercantile, map:village_church, map:village_of_barovia, narrator, parriwimple; P4 |
| `strahd_met` | bool | Strahd appeared in person at the burial. | burial | banter; P4 |
| `strahd_first_impression` | string | The party's answer to Strahd at the grave: defiant, courteous, violent or silent; unset if Doru carried the message. | burial | banter, ireena; P4+ |
| `churchyard_dead_cleared` | bool | The party defeated the churchyard dead (encounter churchyard_dead). | map:village_of_barovia (churchyard_dead) | ireena, map:village_of_barovia |
| `mansion_vigil` | bool | The party chose to stand watch at the mansion; triggers encounter mansion_siege. | ireena | ireena, ismark, map:burgomaster_mansion |
| `mansion_siege_survived` | bool | The party held the mansion through the night (encounter mansion_siege). | map:burgomaster_mansion (mansion_siege) | banter, ireena, ismark, map:burgomaster_mansion, narrator |
| `ireena_escort` | string | Ireena's escort decision: accepted, later or declined. | ireena, road_west | ireena, ismark, map:burgomaster_mansion, map:village_of_barovia, road_west; P4 |
| `ireena_destination` | string | Where the party agreed to take Ireena: vallaki or krezk. | ireena | road_west; P4 |
| `ireena_in_party` | bool | Ireena travels with the party as a guest. | ireena | banter, narrator, road_west; P4; the engine adds the guest |
| `ismark_joins_escort` | bool | Ismark travels with the party and Ireena as a guest. | ireena | road_west; P4 |
| `village_departed` | bool | The party set out west from the village. | road_west | road_west; P4 |
| `vistani_met` | bool | The party has spoken with the Vistani women in the tavern. | vistani | vistani |
| `madam_eva_rumor` | bool | The Vistani women told the party about Madam Eva at Tser Pool. | vistani | banter, ireena, road_west; P4 |
| `vistani_wine_bought` | bool | The party bought the Vistani women a bottle. | vistani | vistani |
| `vistani_spies_suspected` | bool | The party noticed the Vistani women are watching them for someone. | vistani | banter, burial; P4 |
| `wine_shortage_heard` | bool | Arik said the Wizard of Wines deliveries have stopped. | arik | arik; P5 |
| `arik_hollow_noticed` | bool | An Insight check showed there is nobody behind Arik's eyes. | arik | banter |
| `scholar_notes_found` | bool | The party read Aurel Mirescu's last note in the tavern's back room. | map:blood_of_the_vine (aurel_last_note) | arik, banter; P4 |
| `morgantha_met` | bool | The party met Morgantha and her pastry cart. | morgantha | banter, morgantha |
| `dream_pastries_bought` | int | How many dream pastries the party bought from Morgantha. | morgantha | morgantha; P5 |
| `dream_pastry_eaten` | bool | A party member ate Morgantha's sample and dreamed. | morgantha | banter, morgantha; P5 |
| `morgantha_suspected` | bool | The party saw through Morgantha (Insight or Medicine). | morgantha | banter, morgantha; P5 |
| `morgantha_driven_off` | bool | The party intimidated Morgantha out of the village; she remembers. | morgantha | map:village_of_barovia, narrator; P5 |
| `bonegrinder_rumor` | bool | The party learned Morgantha bakes at the old windmill on the Vallaki road. | morgantha, parriwimple | banter; P5 |
| `mad_mary_met` | bool | The party has spoken with Mad Mary. | mad_mary | mad_mary |
| `gertruda_search_promised` | bool | The party promised Mary to look for Gertruda. | mad_mary | banter, mad_mary, narrator; P6 |
| `gertruda_window_clue` | bool | The party found that Gertruda's window latch was opened from the inside. | map:mad_marys_house (gertruda_window) | mad_mary |
| `bildrath_met` | bool | The party has been into Bildrath's Mercantile. | bildrath | bildrath |
| `bildrath_discount` | bool | The party out-haggled Bildrath: ten percent off the kit and the potion. | bildrath | bildrath |
| `bildrath_haggle_failed` | bool | Bildrath refused to haggle; he won't entertain it again. | bildrath | bildrath |
| `bildrath_potion_sold` | bool | The party bought Bildrath's one potion of healing. | bildrath | bildrath |
| `bildrath_robbed` | bool | The mercantile strongbox was opened. | map:bildraths_mercantile (bildrath_strongbox) | bildrath, narrator; P4 can read for reputation |
| `bildrath_accused` | bool | Bildrath has confronted the party about the strongbox. | bildrath | bildrath |
| `bildrath_banned` | bool | Bildrath threw the party out for theft. | bildrath | bildrath |
| `bildrath_repaid` | bool | The party repaid Bildrath's thirty gold. | bildrath | bildrath |
| `night_dead_cleared` | bool | The party cleared the dead from the square at night (encounter night_streets_dead). | map:village_of_barovia (night_streets_dead) | map:village_of_barovia |

## 10. Files

- Voice: docs/voice/{ismark, ireena, donavich, doru, bildrath, parriwimple, mad_mary, morgantha, arik,
  vistani_women, strahd}.md
- NPCs: data/npcs/{ismark, ireena, donavich, doru, bildrath, parriwimple, mad_mary, morgantha, arik, alenka, mirabel,
  sorvia, strahd}.json (portrait and sprite art ids equal the npc id)
- Quests: data/quests/{bury_the_burgomaster, escort_ireena, the_priests_son, find_gertruda}.json
- Flags: data/flags/village_of_barovia.json
- Locations: data/locations/{village_of_barovia, blood_of_the_vine, burgomaster_mansion, village_church,
  bildraths_mercantile, mad_marys_house}.json
- Dialogue: narrative/village_of_barovia/{ismark, ireena, donavich, doru, bildrath, parriwimple, mad_mary, morgantha,
  arik, vistani, burial, road_west}.dialogue; narrative/narrator/village_of_barovia.dialogue;
  narrative/banter/village_of_barovia.dialogue

## 11. Engine needs the format can't express yet

- **Joining a guest:** no dialogue statement adds Ireena or Ismark to the party. The files set `ireena_in_party` and
  `ismark_joins_escort`; the engine should add the guest when those flags turn true (or add `join <npc>` / `leave <npc>`).
- **Gold conditions:** shop options use `gold -N` with no way to test the purse. The engine should refuse a purchase the
  party can't afford (or add a `gold >= N` condition).
- **Dream pastries are not an item.** Purchases are counted in `dream_pastries_bought`; an item `dream_pastry`
  (consumable, triggers `dream:dream_pastry`) would let the party carry and eat them.
- **Banter eligibility:** each banter node opens with an `if` gate; the engine should treat a node as eligible only
  when its leading condition holds.
- **Doru's HP:** see §5.
- **Quest stage on victory:** encounters set a flag but not a quest stage, so `the_priests_son doru_destroyed` is
  written when Donavich hears the news or at the burial. An encounter-level `quest` field would make it immediate.
- **Talk on approach:** Doru should speak as the party reaches the bottom of the stair (an NPC `talk_on_enter`, or an
  encounter-like `dialogue:` trigger on `enter_area:undercroft`); for now the player clicks him.
- **Self-exits:** the church stair is an exit from `village_church` to a spawn on the same map. If the scene loader
  dislikes reloading the current map, split the undercroft into its own location (same grid rows 15-26).
- **Before Death House:** Into the Mists drops the party at the east road, so the village is open before Death House.
  Its fights assume level 3; Phase 3 should steer the party to the Death House lot first (the children are there).
