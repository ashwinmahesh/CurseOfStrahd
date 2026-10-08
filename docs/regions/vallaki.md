# Region design: Vallaki and the Festival of the Blazing Sun (Phase 4)

Plan §6 row 4. Party level 4 on arrival (after the burial in the Village of Barovia), level 5 by the end of the region
(one `xp milestone`, §7). Source: *Curse of Strahd* chapter 5, retold in our own words. Implementation reads this doc;
the data and dialogue files in §12 are the source of truth for exact text.

## 1. What this region is for

Phase 4 exit: **Vallaki plays out differently depending on which faction the party backs.** Vallaki is the campaign's
second hub: a walled town kept "happy" by decree, where two people want to rule and the townsfolk want to survive
both. The Festival of the Blazing Sun is the turning point. The party backs Baron Vargas Vallakovich, backs Lady Fiona
Wachter, or backs neither and stands with the town (Father Lucian, the Martikovs). Each choice leads to a different
festival scene, a different fight, a different aftermath and a different town afterwards, recorded in the string flag
**`vallaki_backed`** (`"baron"`, `"wachter"`, `"neither"`).

Tone: dread with a wink. The town is cheerful by order; the jokes come from the people (the Baron's desperate
optimism, Blinsky's gloom, Rictavio's bluster, Lady Wachter's composure, the watch's tired decency). The Wachter
cellar and Victor's attic are where it stops being funny.

## 2. Factions and what each wants

| Faction | Leader | Wants | Offers the party | Price |
|---|---|---|---|---|
| The Baron | Baron Vargas Vallakovich (`baron_vargas`), Izek Strazni (`izek`), the watch | The festival to succeed, Lady Wachter caught, to be told he was right. Unhappiness lets the devil in, so happiness is the law. | 100 gp, Festival Marshal sashes, a place on the dais forever | Keeping a petty tyranny in place: stocks for frowning, Izek's fist, festivals every week |
| Lady Wachter | Lady Fiona Wachter (`lady_wachter`), her sons Nikolai and Karl, her "book club" (a Strahd cult), hired swords | The burgomaster's chair, ruled openly in Strahd's name: "a vassal who pays her rent sleeps soundly" | 150 gp, her favour, an end to the festivals and the stocks | Vallaki bows to the castle; Ireena isn't safe there; the Baron's fate is the party's to decide; Victor may vanish |
| The town (neither) | Father Lucian (`father_lucian`), Urwin and Danika Martikov (`urwin_martikov`, `danika_martikov`, secretly Keepers of the Feather) | The saint's bones home, nobody in the stocks, no castle collaborator in charge | The town's gratitude, a council, the Keepers' trust (Phase 5 hook) | No gold from either ruler; a fight with Izek and the Baron's loyal sergeants; Lady Wachter goes free without proof |

## 3. Layout and scenes

Eight maps (data/locations/). The exterior is a 50 x 36 walled town; the camp lies outside the west gate.

| Map | Areas (enter: triggers) | What happens |
|---|---|---|
| `vallaki` | `east_gate`, `main_street`, `west_gate`, `town_square`, `market_row`, `east_row`, `mansion_grounds`, `wachter_lane`, `st_andrals_yard`, `lower_town`, `inn_street`, `stockade` | The gate watch on arrival (spawn `from_road`; exit `east_gate_road` → `travel`), the square with the dais, stocks and wicker sun, the herald, Izek by day, Milivoj digging, Arasek's stall, the lockup. The festival and its aftermath play here. |
| `vallaki_blue_water_inn` | `taproom`, `inn_kitchen`, `guest_rooms`, `rictavio_room`, `wagon_yard`, `rictavio_wagon` | Urwin (shop), Danika, Rictavio; his locked wagon (journal, lockbox, the caged beast). Safe rest. Ireena may lodge here. |
| `vallaki_burgomaster_mansion` | `great_hall`, `mansion_foyer`, `izek_quarters`, `dining_hall`, `baron_study`, `lydia_parlor`, `attic` | The Baron, Lydia, Izek's room with the chest of dolls (fight by night), Victor's attic with the teleportation circle (a trap). |
| `vallaki_st_andrals` | `vestry`, `chancel`, `crypt_stair`, `nave`, `crypt` | Father Lucian, the empty sarcophagus, the night vigil (fight), Ireena's sanctuary. Crypt via a stair (self-exit, as the village church). |
| `vallaki_wachter_house` | `wachter_hall`, `wachter_parlor`, `wachter_study`, `stella_room`, `cellar` | Tea with Lady Wachter; Stella behind a locked door; a secret panel (DC 15) to the cellar shrine and Strahd's letter; the cult by night (fight). |
| `vallaki_coffin_maker` | `workshop`, `henrik_rooms`, `storeroom` | Henrik; the storeroom where vampire spawn sleep by day (fight) beside the crate with the bones. Open by day only. |
| `vallaki_blinsky_toys` | `toy_shop`, `toy_workshop` | Blinsky (shop), his order book of Izek's dolls. Open by day only. |
| `vallaki_vistani_camp` | `lakeshore`, `luvash_wagon`, `camp_fire`, `arrigal_wagon`, `camp_edge` | Arrigal, Luvash, a Vistana, Kasimir; Bluto on the lakeshore with Arabelle in a sack. Lake Zarovich is void cells (deep water). |

### The day-by-day flow (every step optional except the festival)

1. **The east gate.** The watch stops the party, names the rules (the festival at noon, no frowning, lamps out at the
   second bell) and the inn. Ireena, if escorted, is announced to the Baron. `vallaki_arrived`; quest
   `festival_of_the_blazing_sun announced`; `sanctuary_for_ireena arrived`.
2. **St. Andral's.** Father Lucian has stripped his altar: three nights ago the bones of St. Andral were taken from the
   crypt. Only he and the gravedigger knew the lid's trick. He can't promise Ireena holy ground until the saint is home.
3. **The bones** (§4.2): Milivoj → Henrik → the storeroom by day, or the vigil at night → the bones back in the crypt →
   the milestone, sanctuary for Ireena.
4. **Courting.** The Baron receives the party and offers a sash; Lady Wachter pours tea and offers a coup; Lucian (or
   Urwin) offers neither, only the town. The party may pledge to any of them, and change its mind until the festival.
5. **Side threads.** Izek and his dolls (Blinsky, the mansion), Victor's attic (Lydia's worry), Rictavio's secret
   (the wagon), the missing Arabelle (the camp), the lockup's malcontents, the Wachter cellar.
6. **The night before.** The wicker sun can be soaked (for Lady Wachter) or guarded (for the Baron).
7. **The Festival of the Blazing Sun** (§4.1): the herald starts it at noon once the party has met the Baron, Lady
   Wachter or Lucian. The Baron's speech, the sun (blazes, dies or smoulders), the turn, the fight.
8. **The aftermath:** the winner holds the dais; `vallaki_backed` is set; the town changes (§5).

## 4. The big threads

### 4.1 The Festival of the Blazing Sun (the turning point)

The Baron holds a festival every week; attendance and cheering are compulsory. This one burns a wicker sun taller than
a house in the square at noon. The festival is a staged quest on the clock (F2): the herald (`vallaki_herald`, by
the dais) begins it when asked, once the party has met at least one faction leader, at noon (asked at another hour,
the party can wait for noon: `time until 12`); his bell rings it in at 11 (data/schedule/vallaki.json). Starting it sets
`festival_begun`; the town fills the square (festival NPC entries), and the Baron, appearing on the dais, speaks on
approach (`festival:speech`).

- **The sun.** `festival_sun_guarded` (the party watched it all night for the Baron, perhaps catching Lady Wachter's
  servant, `wachter_saboteur_caught`): it blazes, the one real cheer the town ever gives. `festival_sun_soaked` (soaked
  for Lady Wachter): it hisses and dies. Neither: drizzle, it smoulders, someone laughs.
- **The turn** (by `vallaki_pledge`; if unset, a three-way choice on the spot):
  - **Baron:** Lady Wachter's coup comes out of the crowd: her sons, cultists and hired swords (`festival_coup`). With
    her letter in the Baron's hands (`wachter_exposed`) he denounces her first; with her servant caught he names him.
  - **Wachter:** she calls the Baron down in front of everyone; he orders Izek and the watch to seize her; the party
    holds them off (`festival_loyalists`).
  - **Town:** the Baron, furious at the dead sun, orders the lockup's malcontents brought out for the lash (unless the
    party freed them); Lucian steps in front of the crowd and Izek, his arm on fire, goes for the priest
    (`festival_izek_rampage`).
- `festival_climax` is set as the fight starts; the crowd NPCs step aside.

### 4.2 The bones of St. Andral and the spawn

The gravedigger Milivoj sold the bones to Henrik the coffin maker for twenty gold to feed his siblings. Henrik bought
them because a voice in his head told him to; the voice came with crates delivered by a driverless black carriage,
and in the crates sleep vampire spawn, waiting for the church to be "just a church".

- **Milivoj** (`st_andrals_yard`, by day): Insight 12, Intimidation 13 or Persuasion 13, or the lever scrapes on the
  lid (search DC 12 in the crypt, `lid_scrapes_found`) make him confess. The party may shield him from Lucian.
- **Henrik** (workshop, by day): Insight 11, then Persuasion or Intimidation 12 (either result confesses). His order
  book also names "M." and the crates.
- **Two ways to the bones**, either one of the two fights, never both: raid the storeroom by day (the spawn wake in
  their crates, surprised: `storeroom_spawn`), or keep vigil in the church at night while the bones are missing
  (`church_siege`, triggered by `church_vigil` from Lucian's dialogue). After either, the bones lie in the small crate
  (container `bones_crate`, item `st_andrals_bones`, flag `bones_recovered`).
- **Return** them to Lucian: `bones_returned`, two holy water, the Vallaki milestone (if not yet given), and sanctuary
  for Ireena.

### 4.3 Izek and Ireena

Izek lost his little sister and his arm to wolves in the woods by the lake when he was nine, and woke with a fiendish
arm. He has dreamed of a red-haired woman ever since and has Blinsky carve her as dolls. She is Ireena, and the
"dreams" are memories: she is his lost sister (Ireena was found wandering at about that age with no memory).

- He sees Ireena in the square (`izek_saw_ireena`, quest `izek_obsession noticed`).
- Clues: Blinsky (or his order book, or the chest in Izek's room) → `izek_dolls_seen`; Izek's story of the arm →
  `izek_story_heard`; Insight 12 with Izek, or asking Ireena what she remembers, → `izek_sister_truth`.
- Telling him (Persuasion 14, or Ireena telling him herself) → `izek_told_truth`: he quits the Baron and won't fight at
  the festival. Failing in his room at night, or threatening him there, starts `izek_confrontation`.
- **Baron path:** after the festival Izek asks the Baron for Ireena as his reward. The party makes the Baron refuse
  (Persuasion 14, `izek_spurned`), tells Izek the truth, or fights him (`izek_duel`).
- In the Wachter and town paths Izek dies in the festival fight if he's in it (`izek_dead`).

### 4.4 Lady Wachter's coup

Tea in the parlour; frankness about her plan and her lord. Insight 14 reads her; Investigation 13 gets the truth about
Stella (who believes she is a cat, after a promise to someone who took it literally). Pledging to her sets
`vallaki_pledge = "wachter"` and her orders: soak the sun, keep Izek off her on the day, don't kill him before.

- **The cellar:** a secret panel behind the study bookcase (secret DC 15; a search of the bookcase, DC 13, hints) leads
  to a shrine with Strahd's letter (`wachter_evidence`). By day it's empty; by night her book club meets there
  (`wachter_cellar_cult`, not if pledged to her). Breaking it (`wachter_cult_broken`) removes her sons and turns her
  cold; the coup goes ahead with hired swords only.
- **Evidence** to the Baron or Lucian sets `wachter_exposed`; at the festival the Baron reads her out (Baron path) or
  Lucian reads the letter to the crowd (town path).

### 4.5 Rictavio and his wagon

A loud half-elf showman at the Blue Water Inn, really Rudolph van Richten. His wagon in the stable yard (lock DC 20)
holds a caged beast (seen, not fought), a lockbox (DC 18: three holy water, two daggers, 25 gp) and his journal with
the bookplate. Insight 15, a sage's recognition, the journal, or the Tarokka unmask him (`rictavio_unmasked`); he gives
two holy water and advice (the spawn sleep by day). He confronts the party if they opened the wagon. He leaves Lady
Wachter's town (`rictavio_gone`). **If the Tarokka names him** (`tarokka.ally.npc == rictavio`) he joins as the ally
(`join rictavio`, `find_the_ally found`), unless the party handed the town to Lady Wachter, when it takes Persuasion 15.

### 4.6 Blinsky, the Martikovs, Arasek

- **Blinsky Toys:** a shop (dice, cards, whistles, marbles, caltrops, tools, 1.5x), gloom as a brand, Izek's dolls.
  If Ireena is with the party he recognises "the doll lady". Performance 12 makes him almost laugh (a whistle).
- **The Blue Water Inn:** Urwin sells supplies (1.5x, one potion at 75 gp) and refuses to trade with the party in
  Lady Wachter's town (`closed`). Danika runs the kitchen and gives the Wizard of Wines hook (`wizard_of_wines_hook`,
  reacting to `wine_shortage_heard`). Urwin reveals the **Keepers of the Feather** (`keepers_of_the_feather_met`) if
  the town won, or after the festival with the bones returned, or if the party fed the raven on the road
  (`raven_fed`); never if it struck the raven (`raven_harmed`). Ireena can lodge here before the bones come home.
- **Gunther Arasek** at his stall in the square: weapons, armour and gear at 2x (wolves eat the carts), road news.

### 4.7 Arrigal's camp and the missing Arabelle

Outside the west gate. Arrigal greets the party with velvet coldness (remembering Tser Pool: `tser_pool_brawl_won`,
`vistani_robbed`, `nicu_kin_told`) and offers Ireena a wagon "where his carriages can't go" (Insight 15:
`arrigal_suspected`, he'd deliver her to the castle). Luvash, drunk with grief, asks the party to find Arabelle
(`missing_arabelle`). The Vistana at the fire saw Bluto the fisherman with a moving sack (`clue`), or a search of the
shore finds drag marks. On the lakeshore Bluto wades out to give Arabelle to the lake: Persuasion 13, Intimidation 13
or Athletics 12 saves her outright; a failure throws the sack, and the best swimmer gets two tries (Athletics 13, then
Perception 12). Rescued: Luvash's gratitude (50 gp, `vistani_friends`). Lost: `arabelle_lost`. If the Tarokka names
Arabelle, she insists on going with the party. **Kasimir Velikov** (made by the Svalich Road package for the Tarokka)
sits apart, mourning his sister Patrina and dreaming of the Amber Temple (`kasimir_sister_told`); he joins if he is
the ally.

### 4.8 Victor's attic and Lydia Petrovna

Lydia sews every banner and worries about Victor, who hasn't come down in four days (quest `victors_circle heard`).
Victor's teleportation circle is a trap on the attic floor (CON 14, 4d6 force) that has already erased two maids.
Arcana 14 or a wizard sees the destination sigil names nowhere (`victor_circle_flaw_known`); telling him persuades him
(he gives a level 1 spell scroll). Otherwise: Persuasion 14, scuff the circle (`victor_circle = "broken"`, he hates the
party), tell the Baron (`reported`), or encourage him. **If Lady Wachter wins and the circle is still his**, Victor
steps into it the day his father falls (`victor_vanished`). If the Tarokka names Victor, he joins as the ally.

### 4.9 Ireena in Vallaki

Ireena arrives as a guest (the gate joins her if `ireena_in_party` is set and the engine hasn't added her; Ismark the
same with `ismark_joins_escort`). She wants sanctuary at St. Andral's; Lucian can't give it until the bones return.
Meanwhile she can lodge at the inn (`leave ireena`, `ireena_sanctuary = "inn"`). With the bones home she can take
sanctuary (`"st_andrals"`) or keep travelling (`"with_party"`); Ismark can stay to guard her (`ismark_guards_ireena`,
`leave ismark`) or come along. In Lady Wachter's town she refuses to stay (`"moving_on"`, rejoins, `ireena_destination
= "krezk"`).

## 5. The three faction paths

| | Baron | Lady Wachter | Neither (the town) |
|---|---|---|---|
| Pledge | `baron:pledge` ("We'll stand with you, Baron.") | `lady_wachter:pledge` ("About your offer. We're with you." or from the offer) | `lucian:pledge_town` or `martikovs:pledge_town` ("Then we'll stand with the town...") |
| Prep | guard the sun; bring her letter to the Baron | soak the sun; leave Izek alive | free the malcontents; bring the bones home; bring the letter to Lucian |
| The sun | blazes (if guarded) | dies (if soaked) | smoulders (default) |
| Fight | `festival_coup` (her sons, cult, hired swords) | `festival_loyalists` (Izek, sergeants, watch) | `festival_izek_rampage` (Izek, loyal sergeants) |
| Aftermath scene | the Baron in triumph; Lady Wachter to the stocks; Izek claims Ireena | Lady Wachter takes the dais; the party decides the Baron's fate (exile, stocks, "as you like"); Victor may vanish; Ireena leaves | the crowd sits the Baron down; Lady Wachter read out (letter, Persuasion 15) or slips away; a council forms |
| Reward | 100 gp; Marshals | 150 gp | the Keepers of the Feather; Lucian's bench |
| The town after | bunting brighter, Lady Wachter in the stocks, the Baron holding court on the dais, Izek at his shoulder (if alive), a new decree | bunting gone, black ribbons, the Baron in the stocks (or gone), Lady Wachter in the Baron's hall, Lydia (and Victor) in the church, the inn won't trade, Rictavio leaves | stocks broken for firewood, Urwin's council on the dais, the Baron sulking in his study, Lady Wachter in the lockup or glowering at home |
| `vallaki_backed` | `"baron"` | `"wachter"` | `"neither"` |

The paths diverge at the pledge (dialogue, prep tasks, NPC reactions, banter), visibly at the sun, decisively at the
fight, and permanently in the aftermath. No skill check gates any path: every pledge and every festival branch can be
reached with plain options. QA golden path (story bot preferences): gate → "This is Ireena"; Lucian → "We'll find the
bones"; the pledge option above; herald → "We're ready. Let the festival begin."; then the aftermath options
("Exile him", "Read the crowd the letter", "[Persuasion DC 14] Baron. Refuse him").

## 6. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| Whom to back | Baron, Lady Wachter, Lucian/Urwin, or the festival | baron, wachter, town; switching sets `baron_betrayed` / `wachter_betrayed` | quest stages, prep orders, banter | the festival branch, `vallaki_backed`, every NPC after |
| The wicker sun | the square at night | soak (Wachter), guard (Baron), leave it | `festival_sun_soaked` / `_guarded` | the festival scene; the sun's remains afterwards |
| Lady Wachter's letter | cellar, then Baron or Lucian | give it, keep it, never find it | `wachter_exposed` | how the coup starts; whether she is locked up or walks free |
| The cellar by night | Wachterhaus | fight the cult or avoid it | `wachter_cult_broken` | her sons are gone; she turns cold; the coup is hired swords only |
| The bones: raid or vigil | coffin maker / church | storeroom by day, vigil by night | one spawn fight | milestone, sanctuary, Lucian's standing at the festival |
| Milivoj | churchyard | shield him, name him, give him coin | `milivoj_shielded` | Lucian's words at the return |
| The malcontents | lockup | Persuasion 14, 15 gp, leave them | `malcontents_freed` | the town path's festival scene |
| Izek | square, mansion, aftermath | truth, threat, fight, make the Baron refuse | `izek_told_truth` / `izek_dead` / `izek_spurned` | festival fights, the Baron path's claim, Ireena's safety |
| The Baron's fate (Wachter path) | aftermath | exile, stocks, "as you like" | `baron_fate` | Lydia and Victor in the church; epilogue |
| Lady Wachter's fate (Baron path) | after | stocks or exile (Persuasion 15) | `wachter_fate` | who stands in the stocks |
| Victor's circle | attic | persuade, break, report, encourage | `victor_circle` | `victor_vanished` in the Wachter path; Victor as ally |
| Ireena's refuge | Lucian, Urwin, Ireena | church, inn, with the party | `ireena_sanctuary`, `leave`/`join` | Izek's claim; later regions |
| Arabelle | lakeshore | talk, scare, grab; dive | `arabelle_rescued` / `_lost` | `vistani_friends`; Lake Zarovich |
| Rictavio | inn | unmask, keep his secret, open his wagon | `rictavio_unmasked`, `rictavio_secret_kept` | Van Richten's Tower; the Tarokka ally |

## 7. Encounters (2024 DMG budgets for four characters)

Level 3: Low 600 / Moderate 900 / High 1600. Level 4: Low 1000 / Moderate 1500 / High 2000. Level 5: Low 2000 /
Moderate 3000 / High 4400. Each fight has variants: `level >= 5`, `level >= 4`, and a lighter fallback for a party
that arrives under level 4. Stand-ins (no data yet, see §11): the town guard is `bandit`, the watch sergeants and
Izek are `warrior_veteran` (Izek with 95-110 HP), Lady Wachter's sons are `tough`.

| id | Map | Trigger | L5 monsters (XP, band) | L4 monsters (XP, band) | Under 4 |
|---|---|---|---|---|---|
| `storeroom_spawn` | coffin maker | enter `storeroom` (spawn surprised) | 2 vampire spawn (3600, Moderate) | spawn + 2 rat swarms (1900, Moderate) | spawn at 50 HP |
| `church_siege` | St. Andral's | `flag:church_vigil`, at night, bones missing | 2 vampire spawn + 2 bat swarms (3700, Moderate) | spawn + 2 bat swarms (1900, Moderate) | spawn at 55 HP + 1 swarm |
| `wachter_cellar_cult` | Wachterhaus | enter `cellar` at night, not pledged to her | sons, 4 cultists, 3 hired swords, a shadow (2500, Low) | sons, 4 cultists, 1 hired sword (1000, Low) | sons, 3 cultists |
| `izek_confrontation` | mansion | dialogue (Izek's room, at night) | Izek + 2 sergeants (2100, Low) | Izek + 1 sergeant (1400, Low) | Izek at 60 HP |
| `festival_coup` | town square | dialogue (Baron path) | sons, 4 cultists, 3 hired swords, 2 captains (3300, Moderate); cult broken: 4 swords, captain, 2 knives (3300) | sons, 6 cultists, sword, captain (1500, Moderate); cult broken (1250, Low) | sons, 3 cultists, captain at 40 HP |
| `festival_loyalists` | town square | dialogue (Wachter path) | Izek, 4 sergeants, 4 guards (3600, Moderate); without Izek (3350) | Izek, sergeant, 4 guards (1500, Moderate); without Izek (1250) | Izek at 60 HP + 3 guards |
| `festival_izek_rampage` | town square | dialogue (town path) | Izek, 3 sergeants, captain, 2 guards (3300, Moderate); without Izek (3300) | Izek, sergeant, 2 guards (1450, Low+); without Izek (1400) | Izek at 60 HP + 2 guards |
| `izek_duel` | town square | dialogue (Baron path aftermath) | Izek + 2 sergeants (2100, Low) | Izek + sergeant (1400, Low) | Izek at 70 HP |

The two spawn fights are mutually exclusive (each removes the other), so the region's vampire spawn are fought once.
The under-4 spawn variants are above High for level 3 even with reduced HP (as Doru was in the village); the party is
warned by Lucian, Henrik and Rictavio, can fight by day with the spawn surprised, and gets holy water from Lucian,
Rictavio and the vestry. The festival fights follow the speech with no rest, so they sit at Moderate, not High.

## 8. Milestone

One `xp milestone` (level 4 → 5), guarded by `vallaki_milestone_reached`: at the bones' return (Lucian) or at the
festival's end (each aftermath), whichever comes first. A party that returns the bones fights the festival at level 5.

## 9. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `ireena_in_party`, `ismark_joins_escort` (village) | gate (joins the guests if the engine hasn't) |
| `ireena_met` (village) | izek, ireena (the sister deduction) |
| `burgomaster_buried`, `strahd_met`, `strahd_first_impression` (village) | baron, lady_wachter |
| `donavich_met`, `doru_destroyed`, `doru_freed`, `doru_left_locked`, `donavich_mercy_blessing`, `holy_symbol_rumor` (village) | lucian, rictavio |
| `wine_shortage_heard` (village) | martikovs (Danika) |
| `tamsin_locket_recognized` (village), `death_house_read_strahd_letter` (Death House) | banter |
| `bildrath_robbed`, `bonegrinder_rumor` (village), `mists_wolves_cowed` (into the mists) | arasek |
| `madam_eva_rumor` (village), `tser_pool_brawl_won`, `vistani_robbed`, `vistani_repaid`, `nicu_kin_told` (svalich road) | vistani_camp (Arrigal), kasimir |
| `raven_fed`, `raven_harmed` (svalich road) | martikovs (the Keepers) |
| `tarokka.ally.npc` (rictavio, van_richten, victor_vallakovich, kasimir_velikov, arabelle), `tarokka.drawn` | rictavio, victor, kasimir, vistani_camp |

## 10. Flags (data/flags/vallaki.json) and what later regions read

All 85 flags are registered, set and read (`make validate`). The ones later regions should read:

- **`vallaki_backed`** (`baron` / `wachter` / `neither`): Strahd's attitude (Lady Wachter tells him the party helped
  her), the Vistani, Krezk's welcome, the epilogue slides.
- `baron_fate` (`rules`, `deposed`, `exiled`, `stocks`, `executed`), `wachter_fate` (`stocks`, `exiled`, `ruler`,
  `exposed`, `free`), `izek_dead`, `izek_told_truth`, `victor_vanished`: epilogue; Strahd scenes.
- `ireena_sanctuary` (`inn`, `st_andrals`, `with_party`, `moving_on`), `ismark_guards_ireena`, `ireena_destination`
  (set to `krezk` in Lady Wachter's town): Krezk, the castle, Ireena's later scenes. Ireena is a guest when
  `with_party` / `moving_on`.
- `bones_returned`: St. Andral's is holy ground (a refuge later regions may use).
- `rictavio_unmasked`, `rictavio_secret_kept`, `rictavio_gone`: Van Richten's Tower, Ezmerelda.
- `keepers_of_the_feather_met`, `wizard_of_wines_hook`: Phase 5 Wizard of Wines (Davian Martikov, the ravens).
- `arabelle_rescued`, `arabelle_lost`, `vistani_friends`, `arrigal_suspected`: Lake Zarovich, Vistani scenes.
- `kasimir_sister_told`: the Amber Temple.
- Quests: `festival_of_the_blazing_sun`, `wachter_plot`, `bones_of_st_andral`, `izek_obsession`, `victors_circle`,
  `missing_arabelle`, `sanctuary_for_ireena`; `find_the_ally found` / `lost` (Svalich Road's quest) when a Vallaki
  ally joins or refuses.

**Tarokka treasure areas** (location:area; the lead places treasures): `vallaki_coffin_maker:storeroom`,
`vallaki_burgomaster_mansion:attic`, `vallaki_burgomaster_mansion:izek_quarters`,
`vallaki_burgomaster_mansion:baron_study`, `vallaki_st_andrals:crypt`, `vallaki_wachter_house:cellar`,
`vallaki_wachter_house:wachter_study`, `vallaki_blue_water_inn:rictavio_wagon`, `vallaki_blinsky_toys:toy_workshop`,
`vallaki_vistani_camp:luvash_wagon`, `vallaki_vistani_camp:camp_edge`. The outcomes file already names five of these.

## 11. Engine needs the format can't express

- **The festival as a timed event.** It now begins at noon (the herald waits for it) and the Baron's watch keeps a
  clock of its own (data/schedule/vallaki.json: arrests at eight every third morning, release at the evening bell),
  but the festival day itself is still the party's choice. A fixed festival day (e.g. the second noon after arrival)
  would make it a real deadline. Likewise St. Andral's Feast: the spawn should attack the church on their own the
  night after the theft is known, not only when the party keeps vigil (a Schedule event could do it).
- **A town guard that reacts to crimes.** Picking the wagon, the Baron's strongbox, Lady Wachter's desk or Arrigal's
  chest, killing Izek in the mansion, or brawling in the square has no watch response; only the victims' dialogue
  notices. Needs a "seen committing a crime" event and a guard response (fine, lockup, fight).
- **The burning effigy.** The wicker sun needs a fire effect (blazing, smouldering, dead and dripping) driven by
  `festival_sun_guarded`/`_soaked`; today only the Narrator says so. Props with a `when` already swap after the
  festival (the stocks).
- **A palisade/town theme.** The `village` theme draws every wall cell as a house, including the stockade; the
  `forest` theme draws the Vistani wagons as trees. Wagon and palisade dressing (or per-block models) would fix both.
- **`here:<location>` condition** for region-specific `rest:` and `combat:` Narrator lines (Vallaki has none for rest).
- **Deep water.** The lake is void cells; switch to the new `w` cell when the schema and grid accept it.
- **Stat blocks:** Izek (fiendish arm, fire), a town `guard` and `guard captain`, `wereraven` (Urwin, Danika),
  an apprentice wizard (Victor), Rudolph van Richten, Kasimir (a dusk elf mage), a saber-toothed tiger for the wagon.
- **Shops on the right-click menu:** Urwin's `closed` condition uses `vallaki_backed`; the validator doesn't scan shop
  conditions for flags.
- **Guests from the village:** nothing calls `join ireena` when she agrees in the village; the gate does it as a
  fallback. If the road adds her earlier, the gate's `join` is a harmless no-op.
- **Art:** `milivoj`, `henrik`, `gunther_arasek`, `luvash`, `arabelle`, `bluto`, `kasimir_velikov` need portraits and
  sprites (`vallaki_herald` and `vallaki_jailer` reuse `vallaki_guard`).

## 12. Files

- Region: docs/regions/vallaki.md (this file)
- Voice: docs/voice/{baron_vargas, izek, lady_wachter, father_lucian, milivoj, henrik, rictavio, blinsky,
  urwin_martikov, danika_martikov, arrigal, victor_vallakovich, lydia_petrovna, vallaki_guard, vistana, luvash,
  arabelle, bluto, gunther_arasek, kasimir_velikov}.md
- NPCs: data/npcs/{baron_vargas, izek, lady_wachter, father_lucian, milivoj, henrik, rictavio, blinsky, urwin_martikov,
  danika_martikov, arrigal, victor_vallakovich, lydia_petrovna, vallaki_guard, vallaki_herald, vallaki_jailer, vistana,
  luvash, arabelle, bluto, gunther_arasek}.json (kasimir_velikov.json belongs to the Svalich Road package)
- Quests: data/quests/{bones_of_st_andral, festival_of_the_blazing_sun, wachter_plot, izek_obsession, victors_circle,
  missing_arabelle, sanctuary_for_ireena}.json; item data/items/st_andrals_bones.json
- Flags: data/flags/vallaki.json
- Locations: data/locations/{vallaki, vallaki_blue_water_inn, vallaki_burgomaster_mansion, vallaki_st_andrals,
  vallaki_wachter_house, vallaki_coffin_maker, vallaki_blinsky_toys, vallaki_vistani_camp}.json
- Dialogue: narrative/vallaki/{gate, festival, aftermath, baron, lady_wachter, lucian, milivoj, henrik, rictavio,
  blinsky, martikovs, arasek, victor, lydia, izek, ireena, vistani_camp, kasimir}.dialogue;
  narrative/narrator/vallaki.dialogue; narrative/banter/vallaki.dialogue
