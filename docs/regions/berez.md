# Region design: the Ruins of Berez, Mount Baratok and the Tsolenka Pass (Phase 5, region 9b)

Plan §6 row 9, second half: Baba Lysaga, the Mad Mage, Baba Lysaga's hut. The party arrives at **level 8-9** and gets
one `xp milestone` at the region's climax (Baba Lysaga's end, or the bargain that buys her gem). Source: *Curse of
Strahd*, the chapters on Berez, Mount Baratok and the Tsolenka Pass, retold in our own words: every name below that
isn't in the book (Burgomaster Ivo Dragan, Sergeant Dorin Valcu, the memory jar, the root in the cradle, the watchword)
is ours. Implementation reads this doc; the data and dialogue files in §13 are the source of truth for exact text.

Three places, one package. Location `region` fields: `berez`, `mount_baratok`, `tsolenka_pass`.

## 1. What this region is for

- **Berez** is the region's heart and its climax: a drowned village in the marsh south of the Luna, where Strahd's
  old nurse, the witch **Baba Lysaga**, keeps house in a hut that stands on a giant stump and walks when it likes. She
  holds one of the Wizard of Wines' three gems, and she holds a secret: she killed **Marina**, the Berez girl Strahd
  loved because she wore Tatyana's face, and let him drown the village for it. The choice that matters is *how she
  ends*: killed in her own kitchen, lured out and separated from her hut, bought off with her secret, or betrayed to
  Strahd, who breaks her himself.
- **Mount Baratok** holds the **Mad Mage**, an archwizard from beyond the mists whose memory was taken when he lost
  to Strahd. Giving him back his mind is the side thread, and it matters: only the restored **Mordenkainen** can join
  as the Tarokka ally, and only he can tell the party the old watchword of the Tsolenka gate.
- **The Tsolenka Pass** is the road to the Amber Temple (region 10): a cliff road, a bridge over a gorge where the
  roc of Mount Ghakis hunts by day, and a guard tower whose ghostly watch has kept the gate shut for centuries. The
  party gets past the watch (fight, watchword, a lie, or rest for the dead) and raises the gate.

Tone: fairy-tale horror with a wink, then none. Baba Lysaga is funny the way a grandmother with a cleaver is funny:
she fusses, feeds, scolds and boasts about her boy, and the stew is not what it seems. The Mad Mage is funny and sad
at once. Marina's vault and the last words in the hut are where it stops being funny.

## 2. Who is here, what they want, how they talk

The voices are written here (this package keeps its bibles in the region doc; they can move to docs/voice/ if the
lead prefers one file per NPC).

### Baba Lysaga (`baba_lysaga`, stat block `baba_lysaga`)

The midwife who brought Strahd into the world and nursed him, and who has believed ever since that she is his true
mother. Small, ancient, quick as a magpie; a face like a walnut, eyes like wet currants, a voice that goes from
cooing to shrieking in one breath. She lives on the wreck of Berez "to keep house for my boy's grief", with straw men
for guards, swarms in her jars, and a hut that loves her like a dog.

- **Wants:** her boy's love, his gratitude, his visits; to be his mother in his eyes. No other woman near him, ever.
- **Fears:** that Strahd will learn what she did to Marina and look at her like a stranger.
- **Secret:** she killed Marina with a thorned doll over her own hearth and let Strahd believe Berez did it. The doll
  still hangs there. She'd do it again, and she nearly tells you so whenever a red-haired woman comes near.
- **How she talks:** nursery cadence and kitchen proverbs, short and sing-song, then a sudden snap. Calls strangers
  "dumplings", "chickens", "my ducks"; calls Strahd "my boy", "my little prince", never by name. Feeds people as a
  threat. Pet phrases: "Eat, eat." "Hush now." "Rot and root." "My boy, my beautiful boy."
- **What makes her funny:** the doting grandmother routine, aimed at a vampire. She brags about his teeth coming in.
- **Reactions:** wizards are "clever chickens, all bones"; clerics get spat at ("your sun doesn't come down here");
  rogues are watched ("that one counts my spoons"); fighters are sized up for the pot. Ireena's face sends her
  straight to murder: "Not that face. Not again."
- Sample lines: "Visitors! The river took all the visitors years ago. What are you: lost, hungry, or stupid?" /
  "He was such a beautiful baby. Teeth already. I knew then." / "Eat. You'll want your strength. Everyone does, at
  the end."

### The Mad Mage (`mad_mage`) who is Mordenkainen (`mordenkainen`, guest, stat block `mordenkainen`)

Two NPC ids for one man: `mad_mage` speaks until his memory comes back; `mordenkainen` speaks after, and is the one who
can join. A legendary archmage from another world who came through the mists decades ago to end Strahd, fought him,
and lost. Strahd didn't kill him: he had the witch of Berez take his memory and bottle it, and left him on a mountain
as a trophy. He lives in a stone hut he raised with magic he no longer understands, and the weather around it does
whatever he forgets he told it to.

- **Wants (mad):** to remember what he forgot, and to win the game of dragonchess he plays against nobody.
  **(restored):** to finish what he came for, and never to be pitied.
- **Fears:** being made a fool of twice. **Secret (restored):** he was beaten because he was proud, not because he
  was weak, and he knows it.
- **How he talks (mad):** grand openings that collapse mid-sentence; names that aren't his ("I am... Osric? No. Osric
  was a goat."); suspects visitors of being illusions; sudden needle-sharp lucidity about spells, then nothing.
  **(restored):** crisp, imperious, dry, impatient with fools and with himself; short sentences, no flourishes.
- **Reactions:** a wizard (Silvain) gets professional jealousy, then respect; a cleric gets a grudging thank-you for
  the spell; anyone who pities him gets a very cold look.
- Sample lines (mad): "Are you real? The last three visitors were birds." (restored): "My name is Mordenkainen. I came
  here to kill him, and he made me forget how to want to."

### Sergeant Dorin Valcu (`tsolenka_sergeant`) and the Phantom Watchman (`tsolenka_watchman`), stat block `phantom_warrior`

The last sergeant of the Tsolenka watch and his men, dead at their posts since before the mists. Their orders, from
kings nobody remembers, were that nothing comes down from the mountain and nobody goes up. They are tired and proud
and very correct.

- **Wants:** to be relieved. **Fears:** abandoning the post. **Secret:** he's no longer sure what's up there; only
  that it whispered to the men who went.
- **How he talks:** watch procedure: challenge, watchword, "state your business", log entries spoken aloud. Calls
  everyone "traveller"; calls the watch "the lads".
- Sample lines: "Halt. Watchword." / "Nothing comes down the mountain. Nobody goes up it. Those are the orders. I
  didn't write them; I keep them."

### Strahd (existing NPC `strahd`, a night cameo at Marina's monument)

At night he lays a black rose at the statue. Courteous, mournful, possessive (docs/voice/strahd.md). The only place in
the game where he grieves where the party can see it, and where they can hand him the truth.

## 3. Layout and scenes

Nine maps (data/locations/). Map themes use only existing ones; §11 lists the themes the art thread could add.

| Map | Theme | Areas (`enter:` triggers) | What happens |
|---|---|---|---|
| `berez` (46 x 34, outdoors) | riverside | `berez_causeway`, `berez_riverbank`, `berez_drowned_lane`, `berez_burgomaster_ruin`, `berez_monument_mound`, `berez_scarecrow_field`, `berez_hut_stump` | The drowned village: the Luna along the north, reeds, pools, broken walls; Marina's monument on its dry mound in the west; the giant stump and the hut in the east; scarecrows in the reeds. Arrival from the road (exit `berez_road` → travel). |
| `berez_baba_lysagas_hut` (16 x 12) | house | `lysaga_hearth_room`, `lysaga_kitchen`, `lysaga_nursery` | Inside the hut: hearth, rocking chair, the thorned doll, drawings of her boy, the jars, the pantry, the tub, the cradle with a swaddled root and a green gem. Supper, the bargain or the fight. Tarokka spot. |
| `berez_marinas_monument` (14 x 12) | church | `marina_vault`, `marina_vault_stair` | The dry vault under the statue: Marina on her bier, untouched by time, Strahd's roses and candles, his verse in the wall, her dowry chest. Tarokka spot. |
| `berez_marsh_track` (32 x 20, outdoors) | riverside | `berez_track` | Battlefield for the marsh road's random fights. |
| `mount_baratok` (36 x 28, outdoors) | wilderness | `baratok_trail`, `baratok_hut_yard`, `baratok_summit`, `baratok_lookout` | Switchback trail, frost garden of frozen birds, a ring of lightning glass, the stone hut, the cairn on the summit (warded), the lookout over Van Richten's lake. |
| `mount_baratok_hut` (14 x 10) | house | `baratok_hut_room`, `baratok_hut_study` | The Mad Mage at home: dragonchess against nobody, a mirror turned to the wall, blank books, chalked equations. Safe rest. |
| `mount_baratok_trail` (32 x 20, outdoors) | wilderness | `baratok_ledge` | Battlefield for the mountain roads' random fights. |
| `tsolenka_pass` (40 x 34, outdoors) | shrine_yard | `tsolenka_climb`, `tsolenka_landing`, `tsolenka_bridge`, `tsolenka_shelf`, `tsolenka_gate_road`, `tsolenka_beyond` | The cliff road, a frozen wayside shrine, the bridge over the gorge, the roc's shelf and its nest, the tower and its portcullis, the road beyond to the Amber Temple (exit `tsolenka_temple_road`, only once the gate is up). |
| `tsolenka_pass_guard_tower` (20 x 13) | dungeon | `tower_vestibule`, `tower_guardroom`, `tower_gatehouse`, `tower_barracks`, `tower_captains_room` | The ghostly watch in the guardroom; the winch for the gate; bunks and footlockers; the captain's room with the watch log and strongbox. Tarokka spot. |

### 3.1 Berez, step by step

1. **Arrival.** The causeway out of the reeds. The Narrator sets the drowned street, the dry mound in the west with a
   white statue on it, and the stump in the east with a hut on it that is breathing.
2. **The scarecrows** (`berez_scarecrows`) stand up out of the reeds when the party crosses the field around the
   stump, with marsh lights and insect swarms. Not if the party came as her guests, made her bargain, or Strahd has
   already been.
3. **The window.** Baba Lysaga leans out of her hut (approach) and asks what they are: lost, hungry or stupid. The
   party can (a) accept her hospitality ("glad of a fire"), (b) lie that her boy sent them (Deception 15), (c) name
   Marina if they already know, or (d) challenge her ("Come down, witch"), which starts the hard fight against her
   and the hut together.
4. **Supper** (`lysaga_hearth_room`). She feeds them, boasts about her boy, sings to the cradle, and watches their
   hands. The party learns what she is; the doll over the hearth (examine) tells the rest (`marina_truth_known`). If
   Ireena is with the party, Lysaga ladles her a special bowl (Insight 14 or Medicine 13 notices the almonds; failing
   that, Ireena smells it herself), and Lysaga's mask slips: "Not that face again" also proves the murder.
5. **The turn**, from the hearth: fight her in her kitchen ("Enough games", `lysaga_in_hut`: the hut can't fight what's
   inside it, and when she dies in it, it dies with her); blackmail her with the doll ("He'll hear it from us",
   `lysaga_bargained`: the gem and whatever's in her kitchen for silence; Intimidation 15 adds the wizard's jar); or
   thank her for supper and leave, carrying the secret.
6. **Marina's monument.** The statue on the dry mound, the only dry thing in Berez, and Strahd's verse on its plinth.
   Digging at the plinth finds the stair to the vault (`marina_vault_found`). Lighting the grave-lamp at her feet while
   the witch lives brings Baba Lysaga screaming across the marsh in her flying skull-bowl (`lysaga_at_monument`):
   **the lure** that separates her from her hut. With her dead, the masterless hut guards its stump alone
   (`creeping_hut_masterless`).
7. **Strahd at the monument** (night, once). He asks who they are to her. Told the truth (`marina_truth_known`), he
   goes very still, thanks them, and goes "to see to my house" (`strahd_knows_marina_truth`). When the party returns
   to the stump, the hut lies broken in the mud with its legs snapped and Baba Lysaga keening beside it
   (`berez/lysaga:scorned`): finish her (`lysaga_scorned`, easy) or leave her with nothing (`lysaga_left_broken`).
8. **The end.** However she falls, her last words (approach, where she fell) and the region's milestone; the gem in
   the cradle (prop `lysaga_cradle`: "Take the green stone." sets `winery_gem_berez_found` and moves the winery's quest
   `the_third_stone` to `found`), the pantry (Tarokka spot), the labelled jar (prop `lysaga_labelled_jar`: the Mad
   Mage's memory).

### 3.2 Mount Baratok

1. The trail up; frozen birds hanging mid-flight in a frost garden; a ring of glass where lightning hit the same spot
   all year. The lookout shows the lake and the tower on its island below (Van Richten's Tower, region 9a).
2. **The Mad Mage** in his hut (approach): suspicious, grand, broken. Talking gets fragments (Insight 14: he keeps
   looking at the summit; a wizard recognises the spell he mumbles and says the name in front of it, which hurts him).
3. **Three ways to give him back his mind**, any one of them, none needing a roll:
   - **His spellbook** under the cairn on the summit (prop `baratok_cairn`: "Unstack the stones.", behind his own
     ward: a thunder trap, detect 15, disarm 15, DEX 15, 4d6). Show it to him, then read him his last page: two steps,
     no check. Without the book, Arcana 16 can talk him back (one try).
   - **The witch's jar** from Baba Lysaga's shelf (prop `lysaga_labelled_jar` once she is dead or broken, or demanded
     in the bargain with Intimidation 15), labelled in her scrawl. Uncork it.
   - **Greater Restoration**, from a cleric, druid or bard of level 9 or higher (`level >= 9`; Hedda has it prepared
     at 9 through the Life Domain).
4. **Restored**, `mordenkainen` speaks: he remembers Strahd, the castle, the witch's jar, and his shame. He gives the
   party the Tsolenka watchword (`tsolenka_watchword_known`), warns them about the Amber Temple's gifts, and:
   - **if the Tarokka names him** (`tarokka.ally.npc == mordenkainen`), joins (`join mordenkainen`,
     `find_the_ally found`);
   - otherwise promises to come when they go up to the castle (`mordenkainen_promised_aid`) and stays to rebuild his
     spells.
   - Unrestored, he can't join even if the cards name him: he agrees grandly and forgets halfway through the sentence.

### 3.3 The Tsolenka Pass

1. The cliff road, a wayside shrine with frozen offerings, the landing, then the **bridge** over the gorge. By day the
   **roc of Mount Ghakis** drops on anything on the bridge (`roc_of_ghakis`); by night it sleeps (the Narrator says so
   on the landing). Its nest on the crag holds what's left of earlier travellers.
2. The **guard tower** straddles the road with its portcullis down. Inside, Sergeant Valcu challenges the party
   (approach): the watchword (from Mordenkainen) passes them; Deception 15 as "the relief" passes them; Persuasion 15
   or Religion 13 (or a cleric's rites) releases the watch to rest; failure, or "Stand aside", is a fight
   (`tsolenka_watch`).
3. **The winch** in the gatehouse (examine) raises the portcullis (`tsolenka_gate_open`): the gate doors open, the
   road north becomes a way out, and the travel road to the Amber Temple appears.

### 3.4 Travel (data/travel/berez.json)

All three places are on the map from the start (a drowned village, a mountain and an old road everyone knows of).

| Road | From → to | Hours | Table |
|---|---|---|---|
| `vallaki_to_berez` | Vallaki → Berez | 3 | `berez_marsh` |
| `wizard_of_wines_to_berez` | Wizard of Wines → Berez (the ravens' way) | 2 | `berez_marsh` |
| `vallaki_to_mount_baratok` | Vallaki → Mount Baratok | 5 | `baratok_slopes` |
| `van_richtens_tower_to_mount_baratok` | Van Richten's Tower → Mount Baratok | 2 | `baratok_slopes` |
| `vallaki_to_tsolenka_pass` | Vallaki → Tsolenka Pass | 6 | `baratok_slopes` |
| `mount_baratok_to_tsolenka_pass` | Mount Baratok → Tsolenka Pass | 4 | `baratok_slopes` |
| `tsolenka_pass_to_amber_temple` | Tsolenka Pass → `amber_temple` (region 10's place) | 3 | `baratok_slopes`, only when `tsolenka_gate_open` |

The Amber Temple package's place `amber_temple` (0.42, 0.11, data/travel/amber_temple.json) sits just above the
pass and adds no road of its own: this file's `tsolenka_pass_to_amber_temple` is the way up, and it only appears once
the portcullis is raised.

## 4. Quests

| Quest | Stages | Set by |
|---|---|---|
| `the_witch_of_berez` | `arrived` → `invited` → `truth` → (`strahd_told`) → `slain` / `bargained` / `broken` (success) | lysaga, hut, marina, encounters |
| `the_mad_mage` | `met` → `book_found` / `jar_found` → `restored` → `joined` / `promised` (success) | mordenkainen, the cairn |
| `the_tsolenka_gate` | `reached` → `watch_passed` → `open` (success) | watch, encounter, winch |

The Wizard of Wines gem is the winery package's quest `the_third_stone`: every way the party takes the gem here sets
`winery_gem_berez_found` and `quest the_third_stone found` (the cradle, the bargain, the broken witch), which Davian's
return option reads.
`find_the_ally found` is the Svalich Road quest; Mordenkainen's join moves it.

## 5. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| How to meet the witch | the window | guests, lie, name Marina, challenge | `lysaga_guests` / `lysaga_and_hut` | supper scene or the hard fight |
| Her end | hearth, monument, stump | fight inside, lure to the monument, bargain, tell Strahd, challenge | `lysaga_fate` = `slain` / `bargained` / `broken` | the hut lives or dies; the gem; Strahd's view of the party (castle) |
| The truth about Marina | the doll, Ireena's bowl, her last words | learn it, use it, tell Strahd, keep it | `marina_truth_known`, `strahd_knows_marina_truth` | Strahd breaks the hut himself; he remembers who told him (castle, epilogue) |
| The grave-lamp | monument | light it while she lives | `lysaga_lured` | she fights without her hut; the hut fights alone later |
| The vault | monument | dig for the stair, leave her be | `marina_vault_found` | Marina's dowry chest (Tarokka spot); Ireena's echo |
| The Mad Mage | his hut | book, jar, spell, or leave him | `mordenkainen_restored` | the ally (Tarokka), the watchword, `mordenkainen_promised_aid` for the castle |
| The watch | the tower | watchword, lie, release, fight | `tsolenka_watch_fate` = `passed` / `released` / `fought` | ghosts at their posts (greet you) or gone |
| The gate | the winch | raise it | `tsolenka_gate_open` | the road to the Amber Temple |
| The roc | the bridge | cross by day (fight) or by night | `roc_driven_off` | the nest's loot; Narrator lines |

No skill check gates a path that matters: every ending of the witch and every way past the watch can be reached
with plain options, and the Mad Mage has two roll-free cures.

## 6. Encounters (2024 DMG budgets for four characters)

Level 8: Low 4000 / Moderate 6800 / High 8400. Level 9: Low 5200 / Moderate 8000 / High 10400. Each Berez and pass
fight has `level >= 9`, `level >= 8` and a lighter fallback. Hit points are tuned with `hp` (listed); XP is the stat
blocks' (Baba Lysaga 7200, her hut 7200, roc 7200, phantom warrior 700, will-o'-wisp 450, scarecrow 200, swarm of
insects 100).

| id | Map | Trigger | L9 | L8 | Under 8 | Band |
|---|---|---|---|---|---|---|
| `berez_scarecrows` | berez | enter `berez_scarecrow_field` (not guests / bargained / after Strahd) | 6 scarecrows, 2 wisps, 2 insect swarms (2300) | 5 scarecrows, wisp, 2 swarms (1650) | 4 scarecrows, 2 swarms (1000) | Low (a skirmish) |
| `berez_drowned_lights` | berez | enter `berez_drowned_lane` at night | 3 wisps, 2 swarms (1550) | same | 2 wisps, swarm | Low |
| `lysaga_in_hut` (critical path) | hut | dialogue | Lysaga 120 HP, 2 swarms (7400) | Lysaga 105 HP, 2 swarms | Lysaga 85 HP, swarm | Moderate |
| `lysaga_at_monument` | berez | dialogue (the grave-lamp) | Lysaga 120, 2 swarms, 2 scarecrows (7800) | Lysaga 105, 2 swarms, scarecrow | Lysaga 85, 2 swarms | Moderate |
| `creeping_hut_masterless` | berez | enter `berez_hut_stump` after the lure | the hut at 200 HP (7200) | 160 HP | 120 HP | Low-Moderate |
| `lysaga_and_hut` | berez | dialogue (the challenge) | Lysaga 100 + hut 150 (14400 nominal) | 85 + 120 | 70 + 100 | above High: the very hard way |
| `lysaga_scorned` | berez | dialogue (after Strahd) | Lysaga at 60 HP, no hut | same | same | Low in effect |
| `roc_of_ghakis` | tsolenka_pass | enter `tsolenka_bridge` by day | roc 190 HP (7200) | 160 HP | 130 HP | Low-Moderate |
| `tsolenka_watch` | tower | dialogue | sergeant + 4 phantom warriors (3500) | same | sergeant + 3 | Low |

Shaping Baba Lysaga: together with her hut she is 14400 XP, deadly for level 9. The region separates them three
ways (inside the hut the hut can't fight; the lure pulls her to the monument; Strahd breaks the hut), trims her hit
points, and lets guests help (Mordenkainen restored first, Ireena, the Tarokka ally). Only the party that walks up and
challenges her at her door fights both at once, and even then at reduced hit points.

### Random encounters (data/random_encounters/)

- `berez_marsh` (map `berez_marsh_track`, day 0.2, night 0.45; Vallaki ↔ Berez): insect clouds and scarecrows by day,
  marsh lights and walking scarecrows by night (900-2050 XP, Low); events `berez/events:drowned_bell` (a bell under
  the water, a drowned shrine's offerings) and `berez/events:raven_guide` (a raven leads the party round the pools:
  better if the Keepers of the Feather know them).
- `baratok_slopes` (map `mount_baratok_trail`, day 0.2, night 0.4; the mountain roads to Baratok, the pass and the
  temple): dire wolves, ogres, giant spiders, werewolves at night (800-2100 XP, Low); events
  `mount_baratok/events:lightning_ridge` (a ridge where the Mad Mage's storm lands every evening) and
  `tsolenka_pass/events:roc_shadow` (the roc goes over; foreshadowing).

## 7. Milestone

One `xp milestone` (level 8 → 9 or 9 → 10), in `narrative/berez/lysaga.dialogue` node `milestone`, guarded by
`berez_milestone_reached`. Every ending of the witch reaches it: her last words (killed in the hut, at the monument,
at her door, or after Strahd), the bargain, or leaving her broken.

## 8. Tarokka treasure spots and the ally

| Place (outcomes.json) | Location | Spot | Notes |
|---|---|---|---|
| `berez_baba_lysagas_hut` (stars 9) | `berez_baba_lysagas_hut` | container `lysagas_pantry` | "Take it from her kitchen." Shown when she is dead, bargained or broken (setup for the exit test: `lysaga_dead`). Narrator hint on entering the kitchen while the treasure is there. |
| `berez_marinas_monument` (stars 3) | `berez_marinas_monument` | container `marinas_dowry_chest` | In the vault under the statue (exit from `berez` once `marina_vault_found`; digging at the plinth always finds it). Lysaga hints at it ("ask the hag"). |
| `tsolenka_pass_guard_tower` (swords 3) | `tsolenka_pass_guard_tower` | container `captains_strongbox` (lock 15) | The captain's room, past the watch. The sergeant mentions it while it's there. |

**Ally:** the broken one (`broken_one` → `mordenkainen`). `mount_baratok/mordenkainen:start` reaches `join mordenkainen`
when `tarokka.ally.npc == mordenkainen` and he is restored. Routes to restoration with no roll: Greater Restoration
(cleric/druid/bard, `level >= 9`), the jar (`mordenkainen_memory_jar_taken`), or the spellbook
(`mordenkainen_spellbook_found`, two steps). The exit test starts at level 11 with Hedda, so the spell route works
with no setup; setup if needed: `mordenkainen_memory_jar_taken: true`.

## 9. Loot and fixed items

| Container | Where | Contents |
|---|---|---|
| `berez_burgomaster_strongbox` (lock 15) | burgomaster's ruin | 60 gp, potion of healing, ink pen |
| `berez_drowned_chest` | a drowned house | 25 gp, rope, lamp |
| `berez_fisher_locker` | by the jetty | 8 gp, net |
| search prop `berez_sunken_purse` (DC 14) | reeds | antitoxin |
| `lysagas_pantry` (Tarokka spot) | hut kitchen | 3 rations, 12 gp |
| `lysagas_jar_shelf` | hut kitchen | 2 potions of healing, antitoxin (the labelled jar beside it is a prop) |
| prop `lysaga_cradle` | hut nursery | **the Wizard of Wines gem** (dialogue: `winery_gem_berez_found`, `the_third_stone found`) |
| `marinas_dowry_chest` (Tarokka spot) | vault | 150 gp |
| `berez_vault_niche` | vault | 30 gp (Strahd's offerings; taking them is noticed by no one, yet) |
| prop `baratok_cairn` (warded) | Baratok summit | 2 level 1 spell scrolls (given in the dialogue); `mordenkainen_spellbook_found` |
| `baratok_summit_cache` | a cleft below the summit | 15 gp, potion of healing |
| `baratok_hut_pack` | Mad Mage's hut | rations, component pouch |
| `roc_nest` | the roc's crag | 140 gp, chain shirt, longsword, potion of healing |
| `tower_footlocker` | barracks | 20 gp, crossbow bolts, a blanket |
| `captains_strongbox` (lock 15, Tarokka spot) | captain's room | 90 gp, potion of healing |

**Containers that should receive Dungeon Master's Guide magic items** (the magic-items thread places them):
`lysagas_jar_shelf` (a potion or a wand), `marinas_dowry_chest` (jewellery-type wondrous item), `roc_nest` (a dead
adventurer's armour or weapon), `captains_strongbox` (a watch officer's item: a cloak, a ring), `baratok_summit_cache`
(a scroll of a higher level once those exist), `berez_burgomaster_strongbox` (a modest item the burgomaster hoarded).

**Fixed Curse of Strahd items needed** (none exist in data/items yet; this package uses flags until they do):
- the Wizard of Wines gem from Berez (the winery package's third stone; no item file exists yet): once it does, add
  `give <gem>` next to `quest the_third_stone found` in `berez/hut:cradle_take`, `berez/lysaga:bargain_struck` and
  `berez/lysaga:leave_broken` (today the flag and the quest stage carry it);
- Mordenkainen's spellbook (a story item; today `mordenkainen_spellbook_found`);
- the witch's jar of his memory (a story item; today `mordenkainen_memory_jar_taken`).

## 10. Flags (data/flags/berez.json) and what other regions read

All flags are registered, set and read (`make validate`). For other packages:

- **`winery_gem_berez_found`** (bool) and quest **`the_third_stone found`** (the winery package's quest): the party has
  the Berez stone (from the cradle, the bargain, or the broken witch). Davian's return option reads the quest stage.
- **`lysaga_fate`** (`slain` / `bargained` / `broken`), **`lysaga_dead`**: Castle Ravenloft (Strahd's attitude: he
  liked his nurse less than she thought), the epilogue.
- **`marina_truth_known`**, **`strahd_knows_marina_truth`**: Strahd's scenes in the castle ("you told me the truth
  once; it bought you nothing, but I remember it").
- **`mordenkainen_restored`**, **`mordenkainen_promised_aid`** (he comes to the castle if asked; Phase 6),
  `guest:mordenkainen`.
- **`tsolenka_gate_open`** (the road to the Amber Temple), `tsolenka_watch_fate` (`passed` / `released` / `fought`),
  `roc_driven_off`: the Amber Temple package (the gate behind the party; the watch's warning about whispers).
- Quests: `the_witch_of_berez`, `the_mad_mage`, `the_tsolenka_gate`.

Flags read from earlier regions: `strahd_met`, `tamsin_locket_recognized` (village), `wizard_of_wines_hook`,
`keepers_of_the_feather_met` (Vallaki), `raven_fed` (Svalich Road); conditions `guest:ireena`, `guest:kasimir_velikov`,
`guest:rictavio`, `guest:mordenkainen`, `name:ilse_varga`, `tarokka.ally.npc`, `treasure_at:<place>`, `level >= 9`.

## 11. Art and theme needs

- **Themes** the environment-art thread could add: `marsh` (reeds, pools, rotten timber, drowned ruins: today
  `riverside` draws the ruins' `#` as trees and the broken walls as low walls), `mountain` (rock walls and scree instead
  of pines for Mount Baratok), `mountain_pass` (cliff road, gorge, a stone bridge: today `shrine_yard`), and a
  `witch_hut` interior (crooked timber, hanging herbs; today `house`). The vault uses `church`; a `crypt` theme would
  suit it better.
- **Props wanted** (stand-ins from the catalog in brackets): Marina's statue `statue_marina` [crypt_small], a
  scarecrow on a post `scarecrow_post` [straw], the creeping hut on its stump `creeping_hut` [cottage + stump], a
  flying skull-bowl, a thorned doll `poppet` [doll], frozen birds `frozen_birds` [bird_case], a lightning-glass ring
  `glass_ring` [rune_circle], a roc's nest `roc_nest` [straw], phantom watchmen at posts.
- **Portraits and sprites:** `baba_lysaga`, `mad_mage` (Mordenkainen unkempt), `mordenkainen` (restored),
  `tsolenka_sergeant`, `tsolenka_watchman` (phantom soldiers in old mail). The broken hut lying on its side, and the
  hut standing up on its root legs, would make the two biggest moments read.
- **Travel map:** the parchment has no marsh or drowned village south-west of Vallaki and no hut on the big north-west
  peak. `berez` sits in the clearing south-west of Vallaki (0.27, 0.62), `mount_baratok` on the slope of the large
  peak above the lake (0.18, 0.20), `tsolenka_pass` in the saddle between the fourth and fifth peaks from the left
  (0.39, 0.145), clear of the werewolf den (0.285, 0.22) and Argynvostholt (0.455, 0.23). A repaint could add a marsh
  with a ruined village, a hut on the peak and a pass with a tower.

## 12. Engine needs the format can't express

- **A monster that leaves when hurt.** The roc should flee at half its hit points (`roc_driven_off`); today the fight
  ends when it dies. Likewise Lysaga's flying skull-bowl (she "flies") is flavour only.
- **Two flags from one victory.** Each Lysaga fight sets one flag; the last-words conversation sets the rest
  (`lysaga_dead`, `lysaga_fate`, `creeping_hut_destroyed`). If the party walks away before she speaks (it's an
  approach scene, so they shouldn't), the flags wait.
- **Containers that react to theft in front of their owner.** The cradle and the jars only appear once Lysaga can't
  stop the party; a "she sees you" event would let a thief try it during supper.
- **Poison in dialogue.** Ireena's bowl can't hurt her (no damage or condition statement in dialogue); the scene is
  played so a failure still ends with her pushing it away.
- **Stat blocks:** all exist. Her swarms are `swarm_of_insects`; the flying skull-bowl has no stat block.
- **Items:** see §9 (the gem, the spellbook, the memory jar).

## 13. The critical path a test bot follows (level 9 party)

Prefer (in this order): `glad of a fire`, `Enough games`, `Take the green stone`, `Take the jar, gently`, `Unstack
the stones`, `Uncork the witch's jar`, `(Cast Greater Restoration on him.)`, `Show him the spellbook`, `Read him the
last page`, `Madam Eva's cards named you. Will you come?`, `Will you help us against him?`, `held by dead men`,
`Cold hearth, shut door.`, `Stand aside`, `Haul on the winch`, `Dig around the plinth`. Avoid: `Come down, witch` (the
hard fight at her door), `Light the grave-lamp` (the lure: valid, adds the hut fight), `Your nurse did` (Strahd's
branch: valid, longer), `We never said we'd leave you alive`.

Setup for the Phase 5 exit test (`SETUP` in tests/integration/test_phase5_exit.gd): `berez_baba_lysagas_hut`:
`{"lysaga_dead": true}` (the pantry is shown once she is dead; the test opens it directly anyway);
`berez_marinas_monument` and `tsolenka_pass_guard_tower`: none; `mordenkainen`: none at level 11 with Hedda (Greater
Restoration), else `{"mordenkainen_memory_jar_taken": true}`.

1. Travel Vallaki → Berez (`vallaki_to_berez`). Walk east toward the stump: `berez_scarecrows` (win).
2. Lysaga speaks from her window: "We're only travellers, grandmother. We'd be glad of a fire." → `lysaga_guests`.
3. Exit `berez_hut_door` into `berez_baba_lysagas_hut`. She speaks at the hearth; after the supper beat, "Enough
   games. Give us the green stone, or we'll take it." → `lysaga_in_hut` (win).
4. Her last words (approach) → `milestone` (`berez_milestone_reached`, quest `the_witch_of_berez slain`).
5. Use the cradle (prop `lysaga_cradle`): "Take the green stone." (`winery_gem_berez_found`, `the_third_stone found`);
   open `lysagas_pantry` (Tarokka spot) and `lysagas_jar_shelf`; use the labelled jar (prop `lysaga_labelled_jar`):
   "Take the jar, gently." (`mordenkainen_memory_jar_taken`).
6. Travel to Mount Baratok; enter `mount_baratok_hut`; the Mad Mage speaks: "Uncork the witch's jar for him." (or the
   spell) → restored; "Madam Eva's cards named you. Will you come?" if he's the ally, else "Will you help us against
   him?" (promise) and "The gate in the Tsolenka Pass is held by dead men." (watchword).
7. Travel to the Tsolenka Pass; cross the bridge (`roc_of_ghakis` by day: win); exit `tsolenka_tower_door`; the
   sergeant: "Cold hearth, shut door." (watchword) or "Stand aside, sergeant, or be made to." → `tsolenka_watch` (win).
8. Examine the winch in the gatehouse: "Haul on the winch." → `tsolenka_gate_open`; walk north through the gate to
   `tsolenka_temple_road` (the Amber Temple road appears on the map).

## 14. Files

- Region: docs/regions/berez.md (this file; voices in §2)
- NPCs: data/npcs/{baba_lysaga, mad_mage, mordenkainen, tsolenka_sergeant, tsolenka_watchman}.json
- Quests: data/quests/{the_witch_of_berez, the_mad_mage, the_tsolenka_gate}.json
- Flags: data/flags/berez.json
- Locations: data/locations/{berez, berez_baba_lysagas_hut, berez_marinas_monument, berez_marsh_track, mount_baratok,
  mount_baratok_hut, mount_baratok_trail, tsolenka_pass, tsolenka_pass_guard_tower}.json
- Travel: data/travel/berez.json · Random tables: data/random_encounters/{berez_marsh, baratok_slopes}.json
- Dialogue: narrative/berez/{lysaga, hut, marina, events}.dialogue; narrative/mount_baratok/{mordenkainen,
  events}.dialogue; narrative/tsolenka_pass/{watch, events}.dialogue; narrative/narrator/berez.dialogue;
  narrative/banter/berez.dialogue
