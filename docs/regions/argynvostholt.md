# Region design: Argynvostholt, the dragon's house (Phase 5)

Plan §6 row 8. Party level 7 or 8 on arrival, one level higher after the region's climax (one `xp milestone`, §8).
Source: *Curse of Strahd* chapter 7, retold in our own words: every line, description and name of a scene here is
ours. Implementation reads this doc; the data and dialogue files in §13 are the source of truth for exact text.

## 1. What this region is for

Argynvostholt is a ruined mansion on a wooded ridge north of the Svalich Woods. A silver dragon, Argynvost, who liked
people enough to wear a man's shape among them, built it, founded a knightly order there (the **Order of the Silver
Dragon**) and lit a beacon at the top of its tower every night so that the valley knew someone was keeping watch.
When the young lord of the castle came over the mountains with his army, before he was what he is now, the Order
fought him and lost. The house fell in a single night. The dragon died in his own courtyard with his knights around
him, and the conqueror carried his skull home as a trophy. The beacon went dark.

The knights got up again. They are revenants now, led by their commander, **Vladimir Horngaard**, whose hatred of
Strahd has curdled into something stranger: he no longer wants Strahd dead. Death would be a door out of the valley
and away from the Order. Vladimir wants him alive, imprisoned in his own country, forever, and he keeps his dead
knights at their posts so that someone will always be there to hate him properly.

The region asks the party one question: **what do you do with an army of the dead that hates your enemy for the
wrong reasons?** Three answers, recorded in the string flag **`order_fate`**:

- **`"rest"`: light the beacon.** The dragon's echo tells the party there is still a little of his fire in his bones.
  Kindled at the mausoleum and carried to the top of the tower, it lights the beacon for one night, and one night is
  enough: the knights remember who they were and lie down at last. The land is blessed by the light; the Order does not
  ride. Vladimir tries to stop it.
- **`"ride"`: the Order rides with the party.** Help Sir Godfrey Gwilym remember the oath they swore, reveal what the
  dragon really asked of Vladimir, or beat Vladimir in a trial of arms, and the knights march on Castle Ravenloft beside
  the party in the finale (Phase 6). The beacon waits for the skull.
- **`"grudge"`: swear Vladimir's oath.** Promise that when the party reaches Strahd they will break him and not end
  him. Vladimir pays: what he keeps, safe passage, and the Order watching at the castle to see the promise kept.
  Phase 6 decides what the knights do when the party moves to end him anyway.

Tone: a ghost story about loyalty. The dead are courteous, tired and occasionally funny (Godfrey's failing memory,
Vladimir's ceremony for guests nobody has entered in a book for three centuries). The mausoleum and the beacon are the
places where it stops being funny.

## 2. Who is here and what each wants

| Who | Id (stat block) | Wants | Fears | Secret | Voice |
|---|---|---|---|---|---|
| Vladimir Horngaard, commander of the dead Order | `vladimir_horngaard` (`vladimir_horngaard`) | Strahd alive and suffering forever; the Order kept together; the beacon dark | Rest, and what waits after it: facing the dragon he failed | The dragon's last words to him were "let them go home"; he swore the Order to vengeance instead and never told them | Short, formal, no contractions, military courtesy without warmth; deadpan ceremony ("Godfrey will enter you in the book of guests") |
| Sir Godfrey Gwilym, his second (the Tarokka ally) | `sir_godfrey_gwilym` (`sir_godfrey_gwilym`) | To remember why they swore; one decent ride before the dark | That he has already forgotten the part that mattered; his own name going next | Keeps a list of the knights' names and what each loved on his wall in charcoal; half heard the dragon's last words | Courteous, slow, loses words mid-sentence; gentle jokes about being dead ("some of the fingers are borrowed") |
| Argynvost, the dragon's echo | `argynvost` (none) | His knights released; the beacon lit; his skull home | That his knights became what they fought | He loved Vladimir like a son and blames himself for the oath sworn over his body | Warm, unhurried, simple images (snow, lamps, the watch); "Keep the watch" |
| The dead knights at the table | `order_knight` (`revenant`) | Orders | Being dismissed | They don't remember most of their names | Two or three words; a hinge of a voice |
| The Phantom Warden of the mausoleum | `phantom_warden` (`phantom_warrior`) | No one but the Order at the dragon's rest | Failing the watch again | He was the gate guard the night the house fell | Ritual phrases, nothing else |
| Phantom warriors (men-at-arms) | (`phantom_warrior`) | To finish the last battle | | They ride home every night along the road and never arrive | (no lines) |

Voice bibles: docs/voice/{vladimir_horngaard, sir_godfrey_gwilym, argynvost, order_knight, phantom_warden}.md.

## 3. Layout and scenes

Five maps (data/locations/). Every map is dark or dim; the house has no fires.

| Map | Theme | Areas (enter: triggers) | What happens |
|---|---|---|---|
| `argynvostholt` (grounds, 42 x 32, outdoors) | `village` (border trees; the mansion front and the mausoleum are TownBuilder houses; one-square wall lines are low yard walls) | `holt_approach`, `holt_courtyard`, `holt_stable_ruin`, `holt_squires_graves`, `holt_mausoleum_yard`, `holt_north_woods` | The road in (exit `road_out` → travel), the gatehouse footings, the courtyard where the dragon fell (the frost scar, the toppled statue), Godfrey on the front steps (approach 6), the front doors, the mausoleum door, the beacon tower (a `burning` prop when lit). The phantom men-at-arms fight their last battle in the courtyard at night (`courtyard_phantoms`). |
| `argynvostholt_hall` (ground floor, 36 x 25) | `manor` | `holt_chapel`, `holt_great_hall`, `holt_armory`, `holt_west_gallery`, `holt_entry_hall`, `holt_servants_hall` | Vladimir at the head of a table of dead knights (the court, the pact, the muster, the trial of arms); the chapel's dragon window where the echo answers; the oath stone; the armory; a servant's hidden stash. Stair up. |
| `argynvostholt_upper` (upper floor, 36 x 22) | `manor` | `holt_dormitory`, `holt_study`, `holt_hall_of_heroes`, `holt_landing`, `holt_godfrey_quarters`, `holt_commanders_room` | Godfrey's room and his wall of names; the dragon's study and the Order's chronicle (the skull's fate); the hall of heroes with a weak floor; Vladimir's bare room and his duty roster; the tower stair. |
| `argynvostholt_beacon` (the tower, 14 x 22) | `dungeon` | `holt_tower_stair`, `holt_lantern_room` | A spiral stair (raised floor 1 to 4) to the open lantern room (a self-exit at (10, 8)): the dark that nests in the cold lamp (`lamp_dark`), the lamp-keeper's locker (treasure spot), the beacon's cradle on its plinth (prop dialogue; burns when lit), the confrontation with Vladimir. |
| `argynvostholt_mausoleum` (16 x 18) | `church` | `holt_vestibule`, `holt_bone_hall` | The Phantom Warden in the one-square doorway (he blocks it until he stands aside); the dragon's headless skeleton on its raised bier; the knights' offerings. |

Area, prop, container, trap and door ids carry the prefix `holt_`, because Narrator keys (`enter:`, `examine:`,
`open:`) are global and Vallaki already uses `great_hall`. Every prop and container `model` resolves in
art/sprites/props/catalog.json; furniture that the `=` low-cover dressing would draw wrongly (pews in a manor, crates
in a courtyard, the bier and the beacon plinth) is placed as props on open squares or as raised floor instead.

### The flow (all optional; the beacon path is the critical path)

1. **The road.** Five hours from Vallaki, four and a half from Tser Pool, on the knights' road (table
   `argynvostholt_road`): the Order's night patrol, the phantom company riding home, werewolves, the conqueror's dead
   still marching. If the Order rides, its knights are out hunting.
2. **The steps.** Sir Godfrey waits on the broken front steps and speaks as the party comes up the drive
   (`godfrey_met`; quest `the_order_of_the_silver_dragon met`). He warns them off the courtyard after dark, sends them
   to the commander and, if the cards named him, offers his sword.
3. **The great hall.** Vladimir receives them from his winged chair at the head of the table (`vladimir_met`;
   `commander`). He will not fight Strahd to end him, will not let the beacon burn, and keeps something that came to
   his door long ago. He offers terms (the pact) and the old law (a trial of arms).
4. **The chapel.** Frost draws a dragon's head across the great window and the echo of Argynvost answers
   (`argynvost_echo_met`; quest `the_dark_beacon echo`): the fall, the oath (`order_oath_learned`), the skull in the
   castle (`argynvost_skull_known`), the fire left in his bones, and, if asked, his last words to Vladimir
   (`vladimir_last_words_known`).
5. **Upstairs.** Godfrey's wall of names (`godfrey_list_read`); the chronicle (the skull's fate); Vladimir's roster of
   men four hundred years dead; the tower door.
6. **The mausoleum.** The Phantom Warden lets the party pass for the oath, for Godfrey's word, or for a good answer
   (History 15 / Religion 14), or the party forces the door (`bone_watch`). At the bones, the party kindles a cold
   silver flame (`dragon_fire_kindled`) if the echo told them how (or Arcana 15 works it out).
7. **The beacon.** The dark in the lamp rises when the party reaches the top (`lamp_dark`). With the dragon's flame,
   the cradle conversation is the climax: Vladimir comes up the stair. The party moves him (the dragon's last words,
   no roll; or Persuasion 17), fights him (`beacon_stand`), or backs down. The beacon burns; the knights lie down;
   the milestone; Vladimir's keeping is handed over.
8. **The muster** (instead of 7). With Godfrey remembering, or the dragon's words known, the party asks Vladimir to
   call the Order to the table and speaks to all of them. The knights choose to ride.
9. **The pact** (instead of 7 or 8). Vladimir's terms, sworn over the table.

## 4. The three paths

| | The beacon (`rest`) | The ride (`ride`) | The grudge (`grudge`) |
|---|---|---|---|
| Needs | the echo (or Arcana 15) → the mausoleum → the flame → the top of the tower | Godfrey remembering (oath, list, the dragon's words or Persuasion 15) or the dragon's words; or a trial of arms | Meeting Vladimir |
| Climax | Vladimir at the cradle: words (plain) / Persuasion 17 / fight `beacon_stand` | the muster: words (plain), Godfrey + Persuasion 14 (a failure still rides, without Vladimir), Persuasion 18 alone, or the duel `vladimir_duel` | the oath sworn at the table |
| Vladimir | `vladimir_fate`: `made_peace` (moved) or `released` (fought, then freed by the light) | `rides` (moved), `abandoned` (the knights follow Godfrey and leave him), `yielded` (beaten; Godfrey leads) | `pact` |
| What the party gets | the milestone; the keeping (from where Vladimir stood); the land blessed (`argynvost_beacon_lit`); Godfrey stays one more ride if he is the ally | the milestone; the keeping; the Order at the castle | the milestone; the keeping; the Order's war chest (150 gp, 2 holy water); safe roads; the Order watching at the castle |
| Afterwards | the knights slumped at the table at peace; the hall silent; the beacon burning on the grounds and the tower | knights sharpening swords that don't need it; hunters on the night roads | knights at their posts; Godfrey grieving; Vladimir satisfied |
| Late change | none | lighting the beacon later releases them instead (`ride` → `rest`, no fight) | lighting the beacon breaks the oath: Vladimir fights (`beacon_stand`), `vladimir_pact_broken`, `grudge` → `rest` |

No path is gated by a roll: the beacon and the muster each have a plain route for a party that did the legwork
(`vladimir_last_words_known`), and every failed roll falls through to a fight or to another try.

## 5. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| The Order's fate | tower / hall | rest, ride, grudge, or leave it | `order_fate`, quests | Phase 6 finale (the Order at the castle, the beacon's blessing, the knights opposing the killing blow); epilogue |
| How Vladimir ends | tower / hall | move him, fight him, abandon him, swear with him | `vladimir_fate` | epilogue; Phase 6 (Vladimir riding or watching) |
| The mausoleum door | mausoleum | oath, Godfrey, History/Religion, force | `mausoleum_opened` / `bone_watch_defeated` | the warden's last words |
| Godfrey | steps / quarters | help him remember (oath, list, words, Persuasion), take him as ally (cards), tell him to rest at the lighting | `godfrey_remembers`, `join`, `find_the_ally` | the muster, the warden, the beacon scene, Phase 6 (Godfrey at the castle) |
| The keeping | hall / tower | earn it by any ending, a trial of arms, or the pact | `tarokka give argynvostholt_vladimir` | the treasure quests |
| Breaking the pact | tower | light the beacon after swearing | `vladimir_pact_broken` | Vladimir's last words; banter |

## 6. Encounters (2024 DMG budgets for four characters)

Level 7: Low 3000 / Moderate 5200 / High 6800. Level 8: Low 4000 / Moderate 6800 / High 8400. Each fight has an
`level >= 8` variant, a `level >= 7` variant and a lighter fallback. XP from data/monsters: phantom warrior 700
(45 HP), Vladimir 2900 (195 HP), revenant 1800 (136 HP), wraith 1800 (67 HP), specter 200. Revenants regenerate 10 a
turn unless hit by fire or radiant: Hedda's radiant spells and Silvain's fire are the answer, and lines say so.

| id | Map | Trigger | L8 (XP, band) | L7 (XP, band) | Under 7 |
|---|---|---|---|---|---|
| `courtyard_phantoms` | grounds | enter `holt_courtyard` at night, after meeting Godfrey, before the Order's fate | 4 phantom warriors (2800) | 3 (2100) | 2 (1400) |
| `bone_watch` | mausoleum | dialogue (forcing the warden) | the warden + 3 phantom warriors (2800) | warden + 2 (2100) | warden + 1 (1400) |
| `lamp_dark` | tower | enter `holt_lantern_room` | 2 wraiths + 2 specters (4000, Low) | wraith + 3 specters (2400) | wraith at 50 HP + 2 specters (2200) |
| `vladimir_duel` | hall | dialogue (the trial of arms) | Vladimir + a revenant second (4700, Low+) | Vladimir alone (2900) | Vladimir at 140 HP |
| `beacon_stand` | tower | dialogue (the party won't back down, fails to move him, or breaks the pact) | Vladimir + 2 revenants at 110 HP + a phantom warrior (7200, Moderate) | Vladimir at 170 HP + a revenant at 110 HP (4700, Low+) | Vladimir at 150 HP alone |

Phantom warriors, wraiths and specters resist weapon damage (and fire), so those fights sit under their XP band on
purpose: Hedda's radiant spells and Silvain's force spells carry them. Critical path fights: `lamp_dark` always (the
treasure and the cradle are up there); `beacon_stand` only if the party didn't learn the dragon's last words and
fails Persuasion 17. Godfrey fights on the party's side when he's a guest.
Road table `argynvostholt_road` (map `road_forest`): werewolf hunters (2 werewolves, 3 dire wolves: 2000), the
conqueror's dead (6 Strahd zombies, 2 ghasts: 2100), and four conversation events.

## 7. The Tarokka

- **`argynvostholt_beacon`** ("at the top of its dark beacon tower"): `treasure_spots` in `argynvostholt_beacon` →
  container `holt_lampkeeper_locker` at (11, 13), an iron locker bolted beside the cradle in the lantern room.
  Reached by climbing the tower and winning `lamp_dark`. The cradle line hints at it when `treasure_at:argynvostholt_beacon`.
- **`argynvostholt_vladimir`** ("in the keeping of the dead knight who commands it"): `treasure_spots` in
  `argynvostholt_hall` → dialogue `argynvostholt/vladimir:keeping` (`tarokka give argynvostholt_vladimir`). Something
  came to the house long ago in the hands of a hunter who meant to end Strahd with it and died at the door; Vladimir
  has kept it ever since precisely so that nobody would. Every ending reaches `keeping` (the lighting, the muster, the
  pact), and so does a won trial of arms ("We only want what you're keeping"). He mentions it when asked
  (`[if treasure_at:argynvostholt_vladimir] You're keeping something that could hurt Strahd.`).
- **Ally `ghost` → Sir Godfrey Gwilym.** `data/npcs/sir_godfrey_gwilym.json` (`guest: true`, `guest_build` monster
  `sir_godfrey_gwilym`). Join scene: `argynvostholt/godfrey:cards` (option "Madam Eva's cards named you, Sir Godfrey.")
  → he fears he's half a knight without his oath → say the oath with him (`order_oath_learned`), read him his own wall
  (`godfrey_list_read`), or, with no legwork, "We can't give you back what you've lost. We can give you something new
  to remember." → `join sir_godfrey_gwilym`, `quest find_the_ally found`. If the beacon is lit before he has joined,
  he climbs the tower and asks to stay for one more ride (`beacon:godfrey_asks`): yes joins him; "rest" sets
  `find_the_ally lost`.

## 8. Milestone

One `xp milestone` (7 → 8 or 8 → 9) in `argynvostholt/vladimir:climax_end`, guarded by
`argynvostholt_milestone_reached`. Every ending jumps there: the lighting (beacon.dialogue), the muster and the
pact (vladimir.dialogue). A trial of arms on its own is not the climax.

## 9. Flags read from earlier regions

| Flag (owner) | Read by |
|---|---|
| `strahd_met` (village) | vladimir (Strahd's boredom) |
| `vallaki_backed`, `bones_returned` (Vallaki) | godfrey (news of Vallaki; St. Andral's) |
| `tarokka.ally.npc`, `treasure_at:` (campaign) | godfrey, vladimir, beacon |
| `guest:ireena` | vladimir, argynvost (interjections) |

## 10. Flags (data/flags/argynvostholt.json) and what Phase 6 reads

All flags are registered, set and read in this package. The ones later content should read:

- **`order_fate`** (`rest` / `ride` / `grudge`; unset if the party walked away): the finale. `ride`: the knights
  (and Vladimir if `vladimir_fate == "rides"`, Godfrey if not already a guest) arrive at the castle as allies.
  `rest`: the beacon's light is on the castle every night; a blessing for the final fight. `grudge`: the knights are
  at the castle to see the oath kept; they move to stop the killing blow (`vladimir_pact`).
- `argynvost_beacon_lit`: the blessing; the epilogue; Strahd's reaction (he can see it from his window).
- `argynvost_skull_known`: the dragon's skull is a trophy somewhere in Castle Ravenloft. Brought home to the bones in
  the mausoleum it lights the beacon fully: the ending for `ride` and `grudge` knights after Strahd falls, and the
  echo's own rest.
- `vladimir_fate` (`made_peace`, `released`, `rides`, `abandoned`, `yielded`, `pact`), `vladimir_pact`,
  `vladimir_pact_broken`, `godfrey_remembers`: epilogue slides; Phase 6 knight scenes.
- Quests: `the_order_of_the_silver_dragon` (`ride`, `rest` succeed; `grudge` fails), `the_dark_beacon` (`lit`
  succeeds; `waiting` stays open for the skull); `find_the_ally found` / `lost` for Godfrey.

## 11. Loot

| Container | Map | Contents | DMG item candidate |
|---|---|---|---|
| `holt_stable_saddlebags` | grounds | lance, 18 gp (old crowns) | |
| `holt_armory_rack` | hall | longsword, shield, lance | yes (a knight's weapon) |
| `holt_armory_chest` (lock 15) | hall | 60 gp, 2 holy water | yes |
| `holt_pantry_cupboard` | hall | 6 candles, oil, a lamp | |
| `holt_loose_hearthstone` (search 14, prop) | hall | potion of healing | |
| `holt_dormitory_footlocker` | upper | playing cards, dice, 24 gp | |
| `holt_dragon_desk` | upper | ink, ink pen, parchment, 35 gp | yes (the dragon's study) |
| `holt_godfrey_chest` | upper | 9 gp, a book | |
| `holt_commanders_chest` (lock 18) | upper | 120 gp, a level 1 spell scroll | yes (the commander's strongbox) |
| `holt_lampkeeper_locker` | tower | 2 torches, oil, tinderbox, 15 gp; the Tarokka treasure when the reading puts one here | yes |
| `holt_offering_niches` | mausoleum | 30 gp in silver, 4 candles | yes (an offering to a dragon) |

The chapter's fixed treasures are the two Tarokka places. The pact pays 150 gp and 2 holy water through dialogue.
No new item is required: the dragon's flame is a flag (`dragon_fire_kindled`), not an item (see §12).

## 12. Engine, art and data needs (nothing worked around in data)

- **Engine (P5-04), landed while this was written:** `treasure_spots`, `tarokka give`, `treasure_at:`, merged travel
  files (my roads join `vallaki` and `tser_pool`, which live in barovia.json). One leftover: `campaign_checks`'
  `place_ok` still lists `argynvostholt_vladimir` as a later-phase place because it isn't a location id; it should
  accept a place that has a treasure spot.
- **A silver flame.** The beacon's `burning` prop draws the ordinary orange fire; the beacon burns cold and silver.
  A `flame` colour on burning props (or a `burning_style`) would let the light look right.
- **Conditional rest.** After the beacon is lit the house should be `safe`; `rest` is a fixed value.
- **The beacon on the travel map.** A lit marker for Argynvostholt when `argynvost_beacon_lit`.
- **Carrying the flame.** A quest item (`argynvosts_flame`, a lantern of cold fire) would show in the pack; today a
  flag stands in. Nice to have, not required.
- **Revenants:** Regeneration's pause after fire or radiant damage and Rejuvenation (the story assumes a beaten
  revenant's wounds close and he yields rather than dies; Vladimir "yields" after the duel).
- **Stat blocks** (P5-03, landed): `vladimir_horngaard`, `sir_godfrey_gwilym`, `phantom_warrior`, `wraith`. Their
  Vengeful Glare and Rejuvenation are text only; nothing in this package depends on them.
- **Themes:** a `ruin` theme for the grounds (broken walls without roofs, weeds through flagstones; today the
  mansion front, gatehouse and mausoleum are drawn as village houses); a `tower` theme (a round stone stair and an
  open parapet).
- **Prop art wanted** (each uses the nearest catalog model for now): a silver-dragon stained window (`window_tall`),
  a toppled dragon statue head and a broken rearing dragon (`statue_head`, `statue_knight`), a winged commander's
  chair (`armchair`), the oath stone (`relief`), a headless dragon skeleton on a bier (`bones`), the beacon cradle
  with a silver flame (`brazier`), the beacon tower seen from the courtyard (`window_tall` on the house front), an
  empty plinth (`altar_stone`), the Order's banners (`tapestry`).
- **Art:** portraits and sprites for `vladimir_horngaard` (a revenant knight in black-scaled plate, a dragon-winged
  helm), `sir_godfrey_gwilym` (a big grey dead knight, dented plate, kind eyes), `order_knight` (a generic revenant
  knight), `phantom_warden` (a translucent man-at-arms); a portrait for `argynvost` (a dragon's head drawn in frost
  on stained glass) and a faint silver shimmer sprite; monster sprites for `phantom_warrior` and `wraith`. Props: a
  headless dragon skeleton on a bier, the silver-dragon window, the beacon cradle, a toppled dragon statue, a long
  table of seated knights, rotted banners.

## 13. Critical path (story bot)

From Vallaki at level 7 with four pregens. Prefer, in order: "Madam Eva's cards named you, Sir Godfrey.", "something
new to remember", "Why can't your knights rest?", "What did you ask of him", "Why is the beacon dark?", "What oath",
"Speak the Order's oath", "Kindle a light", "He told you to let them go", "Light the beacon", "Ride with us, Sir
Godfrey". Avoid: "We swear it", "Stand aside", "go through you", "trial of arms", "Lower the flame", "Rest, Sir
Godfrey", "Not yet", "Leave him be".

1. `go_to("argynvostholt")` (travel from Vallaki), or start there: `_start("argynvostholt", 7)` by day. No flags need
   setting first.
2. Godfrey speaks on approach (or `talk("sir_godfrey_gwilym")`); if he's the ally, he joins.
3. `go_to("argynvostholt_hall")`, `talk("argynvost")`: the beacon, the last words, the oath.
4. `go_to("argynvostholt_mausoleum")`: the warden speaks on approach → the oath; `use` the bones (7, 5) → kindle.
5. `go_to("argynvostholt_beacon")` (arrives at the stair foot), then `walk_to(Vector2i(10, 8))` (the stair head, a
   self-exit to the lantern room); `lamp_dark` starts on arrival; `use` the locker (11, 13); `use` the cradle (6, 15)
   → Vladimir → the last words → the lighting → milestone → keeping.
6. Expect: `order_fate == "rest"`, `argynvost_beacon_lit`, `argynvostholt_milestone_reached`, `treasure_found_*` for
   any treasure the reading put here.

Short routes for the Phase 5 exit test: **beacon treasure** = steps 1 and 5 (open the locker after `lamp_dark`);
**Vladimir's keeping** = step 1, `talk("vladimir_horngaard")`, prefer "Name your terms", "We swear it" (the pact,
no fight); **the ally** = steps 1 and 2.

## 14. Files

- Region: docs/regions/argynvostholt.md (this file); task docs/tasks/P5-08.md
- Voice: docs/voice/{vladimir_horngaard, sir_godfrey_gwilym, argynvost, order_knight, phantom_warden}.md
- NPCs: data/npcs/{vladimir_horngaard, sir_godfrey_gwilym, argynvost, order_knight, phantom_warden}.json
- Quests: data/quests/{the_order_of_the_silver_dragon, the_dark_beacon}.json
- Flags: data/flags/argynvostholt.json
- Locations: data/locations/{argynvostholt, argynvostholt_hall, argynvostholt_upper, argynvostholt_beacon,
  argynvostholt_mausoleum}.json
- Travel: data/travel/argynvostholt.json; table data/random_encounters/argynvostholt_road.json
- Dialogue: narrative/argynvostholt/{godfrey, vladimir, argynvost, mausoleum, beacon, knights, events}.dialogue;
  narrative/narrator/argynvostholt.dialogue; narrative/banter/argynvostholt.dialogue
