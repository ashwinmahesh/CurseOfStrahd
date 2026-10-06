# Region design: Krezk and the Abbey of St. Markovia (Phase 5)

Plan §6 row 7. The party arrives at level 6 or 7 (after Vallaki and one or two of the other Phase 5 regions) and leaves
one level higher (one `xp milestone`, §8). Source: *Curse of Strahd* chapter 8, retold in spirit and entirely in our
own words. Two region ids share this package and this doc: `krezk` (the village, the Krezkovs' house, the Pool of the
White Sun) and `abbey_of_st_markovia` (the abbey grounds, its church, its wards and its garden). The data and dialogue
files in §16 are the source of truth for exact text.

## 1. What this region is for

The far west of the valley, where the road stops. Krezk is the last village: a mountain shelf behind a wall three men
high whose gate opens only for a reason. Above it on the mountainside, the Abbey of St. Markovia, built by a saint for
the sick and the motherless, is kept now by **the Abbot**: a celestial sent long ago to guard the valley's faith,
bent by centuries of watching it suffer, who has decided with perfect serenity that the lord of Barovia is not evil but
lonely, and that the cure is a wife. He is sewing one, **Vasilka**, from Krezk's dead. He needs a wedding dress.

The region's three plan beats:

- **Bring the wedding dress** (§4.4): the Abbot asks; the dress can be Anna Krezkova's own (kept for a daughter she no
  longer has), or the abbey matron's from a locked room in the wards. Another region (Vallaki) may add a third source.
- **The Abbot's fate** (§4.5, the climax): when the dress arrives he wakes Vasilka, and the party decides what becomes of
  him: a wedding, a repentance, a broken angel, or a dead one (`abbot_fate`).
- **Ireena at the Pool** (§4.3): if Ireena travels with the party, the Pool of the White Sun shows her Sergei, Strahd's
  dead brother, and she remembers being Tatyana. She chooses; nothing is resolved (`ireena_pool_choice`), so her ending
  stays open for Phase 6.

Threaded through them: Dmitri and Anna Krezkov's dying son Ilya, whom the Abbot offers to heal for the dress; the
Belviews, a Krezk family the Abbot has been "improving" with animal parts for generations; and, when the Tarokka's Mists
card names her, **Ezmerelda d'Avenir**, watching the abbey from the top of the switchback.

Tone: Krezk is dour and dry (stubborn mountain people, gallows understatement, goats). The Abbey is one of the game's
scariest places (plan §5.7): the humour thins to Clovin's exhausted sarcasm and the Abbot's dreadful calm, and some
Narrator lines carry no joke at all.

## 2. Who's here and what they want

| NPC | id (stat block) | Wants | Fears | Voice |
|---|---|---|---|---|
| Dmitri Krezkov, burgomaster | `dmitri_krezkov` (`warrior_veteran`) | Krezk kept; his son alive without owing the Abbot | a sixth grave; that his pride digs it | few words laid like stones; "That's a reason." |
| Anna Krezkova | `anna_krezkova` (`commoner`) | Ilya to live, at any price | the silence when she stops singing | plain, quick, gallows-practical |
| Ilya Krezkov, 8 | `ilya_krezkov` (`commoner`) | to see past the wall | not much; he's eight | frank questions |
| The Krezk Watchman | `krezk_guard` (`vallaki_guard`, the town guard block) | to finish his watch with the gate shut | being the one who let him in | deadpan farmer |
| Kasha Varo, shrine keeper | `kasha_varo` (`commoner`) | the pool respected, the graves kept | whoever turns the graves at night | chatty, folk-wise, "my knees know things" |
| The Abbot | `abbot` (`deva`, shown as "The Abbot") | to wake his bride and send her to the castle; peace by spring | that Markovia was right | gentle, unhurried, "child", monstrous things said like carpentry |
| Vasilka | `vasilka` (`flesh_golem`, shown as "Vasilka") | to be told what happens next | nothing; she wasn't taught fear | etiquette-primer politeness |
| Clovin Belview | `clovin_belview` (`mongrelfolk`) | wine, no more improvements, the letter read to him | the Abbot being kind to him | the abbey's only comedian; weary patter |
| The Belviews | `belview` (`mongrelfolk`) | no more gifts; the cell-dwellers fed | Krezk's stones | mimicry in your own voice |
| Sergei von Zarovich | `sergei_von_zarovich` (no block) | Ireena's peace, as she chooses it | that she'll choose for his sake | very few, warm words |
| Ezmerelda d'Avenir | `ezmerelda` (`ezmerelda_davenir`, guest) | Strahd's end; a word with Van Richten first | being left behind again | sardonic hunter's rules |

Voice bibles: docs/voice/{dmitri_krezkov, anna_krezkova, ilya_krezkov, krezk_guard, kasha_varo, abbot, vasilka,
clovin_belview, belview, sergei_von_zarovich, ezmerelda}.md. Ireena and Ismark speak by their own bibles (Village of
Barovia); their NPC files are not this package's.

## 3. Layout and scenes

Seven maps (data/locations/). Krezk sits at the art's walled hill town (pos 0.075, 0.51), the abbey at the small
village with a church above it (0.07, 0.36), per docs/ui/travel_map.md.

| Map | Theme | Areas | What happens |
|---|---|---|---|
| `krezk` (44 x 30) | village | `krezk_road`, `abbey_track`, `krezk_gate_inside`, `krezk_square`, `burgomaster_yard`, `pool_lane`, `krezk_east_lanes`, `krezk_pens`, `krezk_south_row` | Outside: the end of the road (spawn `from_road`, exit `road_east` → travel), the shut gate (door `krezk_gate`, `when: flag.krezk_gate_open`) and the watchman (approach), the switchback track up to the abbey (exit `abbey_track_up`). Inside: the burgomaster's house, the well square, goat pens, cottages, the lane north to the pool. Ilya at the well once healed. Wolves at night while the gate is shut. |
| `krezk_burgomaster_house` (22 x 13) | house | `krezkov_hall`, `guest_room`, `ilya_room`, `krezkov_bedroom` | Dmitri in the hall, Anna and Ilya in the sickroom, Anna's locked chest (DC 15), the village ledger (codex). Ireena and Ismark lodge here if they stay. Safe rest. |
| `krezk_pool_of_the_white_sun` (24 x 18) | shrine_yard | `pool_edge`, `white_sun_pavilion`, `krezk_graves`, `north_graves` | The pool (prop `white_sun_pool` → `krezk/pool:the_pool`: wade in, fill flasks, the wishes; Ireena's vision), the White Sun's pavilion (`krezk/pool:shrine`), Kasha, the Krezkov children's stones, a secretly turned grave (search DC 12). Safe rest. Tarokka spot. |
| `abbey_of_st_markovia` (36 x 30) | village | `switchback_top`, `abbey_gate`, `abbey_courtyard`, `cloister_walk`, `west_court` | The top of the switchback (from Krezk, `from_krezk`; travel `from_road`), Ezmerelda when she's the ally, the gate, Clovin (approach), a Belview by the well, Markovia's statue, the cart shed, doors to the church, wards and garden. |
| `abbey_of_st_markovia_shrine` (26 x 17) | church | `church_nave`, `church_chancel`, `abbot_cell`, `sacristy`, `church_porch` | The Abbot (approach), the great sunburst (prop → `abbey_of_st_markovia/shrine:sunburst`), the Abbot's ledger of improvements (codex), the sacristy chest. The unveiling and both Abbot fights play here. No rest. Tarokka spot. |
| `abbey_of_st_markovia_wards` (30 x 22) | dungeon | `belview_kitchen`, `wards_hall`, `foundling_ward`, `ward_cells`, `wards_corridor`, `matron_room`, `abbey_surgery` | The Belviews' kitchen, the foundling ward ("where the young were once kept") with the foundling's locker, the barred cells (prop → `belviews:cells`), the matron's locked room (DC 13; Clovin: kick it low by the hinge) with the bridal trunk, the surgery with Vasilka on her table. No rest. Tarokka spot. |
| `abbey_of_st_markovia_garden` (24 x 18) | shrine_yard | `scarecrow_row`, `frost_beds`, `nuns_graves`, `garden_shed_yard` | Frost beds, the tool shed, the nuns' graves, and the row of stitched scarecrows that climb down off their poles (fight). Tarokka spot. |

### The flow (every step optional except the climax)

1. **The gate** (§4.1). The watchman stops the party. A reason opens it; without one, he points up the mountain.
2. **The abbey.** Clovin at the gate (and his letter, §4.6); the Abbot in his church, who vouches for the party, reveals
   his bride and asks for a wedding dress, offering to heal Ilya in return. Vasilka in the wards; the cells; the garden.
3. **Krezk.** "The Abbot sent us" opens the gate. Dmitri and Anna; Ilya's fever (§4.2); Anna's dress; the pool and
   Kasha (§4.3).
4. **The dress** (§4.4), from Anna or the matron's trunk.
5. **The unveiling** (§4.5): back in the abbey church, the dress delivered, Vasilka wakes, the Abbot's fate. Milestone.
6. **After:** Krezk, the Belviews and the abbey change with `abbot_fate` and `ilya_fate` (§5).

## 4. The threads

### 4.1 The gate of Krezk

The watchman (approach 4) names the rule: Krezk opens for a reason, and the burgomaster decides what a reason is. Each
reason fetches Dmitri, who opens the gate a body's width (`krezk_gate_open`, quest `the_gate_of_krezk opened`) and
records why (`krezk_reason`):

| Reason (option) | Condition | `krezk_reason` | Notes |
|---|---|---|---|
| "This is Ireena Kolyana..." | `guest:ireena` | `ireena` | Her father once sent Krezk salt. Also `krezk_refuge_offered`. |
| "The Abbot of St. Markovia sent us." | `abbot_vouched` | `abbot` | The plain, always-available route (the abbey track is outside the wall). |
| "...We know why it stopped." (the wine) | `wizard_of_wines_hook` or `wine_shortage_heard` | `wine` | Dmitri wants the Martikovs' cart back. |
| "We just cleared the wolves off your doorstep." | `krezk_wolves_driven_off` | `wolves` | After the night fight at the gate. |
| [Cleric] "I'm a priest..." | a cleric | `cleric` | Dmitri's son needs one; sets `ilya_heard`. |
| [Persuasion DC 14] (one try) | | `persuaded` | |
| [Intimidation DC 16] | | `cowed` | Dmitri stays cold; no refuge for Ireena. Failure: an arrow at your feet. |
| "Is there anywhere up here that does take strangers?" | | (refused) | `krezk_abbey_directed`, quest `refused`: go to the abbey. |

Dmitri also reacts to `vallaki_backed` (cold to Lady Wachter's helpers, a handshake for the council).

### 4.2 Ilya, the burgomaster's son

Ilya is eight and a month into a fever. Five Krezkov children lie in the graves by the pool. Anna wants the Abbot's
help; Dmitri won't owe the Abbot anything ("the Belviews went up that mountain sick..."). Quest
`the_burgomasters_son` (`heard`, `abbot_offer`, `frail`, `healed`). Cures, all at the bedside or the climax:

- **A cleric's prayer** ([Cleric] "Let me pray over him."): `ilya_fate = "healed"`, Anna gives the 40 gp saved for his stone.
- **The White Sun's water** (fill flasks at the pool, `white_sun_water`): the fever breaks, he stays weak (`frail`).
- **The Abbot's hands**: in the wedding, repentant and broken endings he goes down at dawn and heals the boy (`healed`,
  upgrading `frail`). If the party kills him or flees with Ireena, he doesn't.
- Never cured: `ilya_fate` stays unset (the epilogue may read it as his death in the winter).

### 4.3 The Pool of the White Sun, and Ireena

A round pool at the north end of Krezk that never freezes; when the sun goes in, its reflection lingers in the water a
breath longer than in the sky. Kasha keeps the shrine and the graves; she has twice seen a young man in the water.

- **The pool** (`krezk/pool:the_pool`): wade in (the Tarokka spot, §11), fill two flasks of holy water once
  (`white_sun_water`), steal the wishes (9 gp, `pool_offerings_taken`; Kasha scolds, the pool's sky goes grey), pray at
  the pavilion (`white_sun_prayed`).
- **Ireena** (only while `guest:ireena`, the first time the pool is used): she kneels; beside her reflection stands
  Sergei. He calls her Tatyana; she remembers a chapel of white flowers, a wall and a stair. The water is his only door:
  he can't come out; she could come in, when she's ready. The party speaks, she chooses, and either way she stays a guest:
  - "Go to him, if you want to..." → she won't, not while Strahd lives: she promises to come back when he's dead
    (`ireena_pool_choice = "promised"`).
  - "Stay with us... You're not her. Not only her." → she says her own name and lets Sergei go (`"stayed"`).
  - [Insight DC 14] shows she wants both, then the same choice.
  Sets `ireena_pool_vision`, quest `the_pool_of_the_white_sun` (`seen` → `promised` / `stayed`). Callbacks:
  `eva_question == "ireena"` ("keep her away from still water"), `ireena_falls_memory`, `tamsin_locket_recognized`,
  `stanimir_tale_heard`. **Phase 6 decides her ending**; this scene only records her state of mind.
- **Refuge:** Dmitri offers Ireena his roof (`krezk_refuge_offered`), unless the party threatened the gate. She stays
  (`leave ireena`, `ireena_in_krezk`; Ismark may stay too, `ismark_in_krezk`) unless she promised Sergei, in which case
  she says she must go where the party goes. She rejoins from the Krezkovs' hall.

### 4.4 The Abbot and the wedding dress

The Abbot meets the party in his church (approach) and lights candles with his fingertips. Religion DC 15, a cleric
or a paladin sees what he is (`abbot_nature_known`). If Ireena is with the party, every candle leans toward her and he
recognises Tatyana (`abbot_saw_ireena`; Insight DC 13 shows the collector's look). He tells his version of Markovia
("brave, and mistaken", `markovia_story_heard`), calls the Belviews his family, vouches for the party at Krezk
(`abbot_vouched`), and reveals his work (`abbot_bride_revealed`): a bride for the lord of the valley, "from what Krezk
was finished with". He asks for a wedding dress (quest `the_abbots_bride asked`, `abbot_dress_asked`) and offers to heal
Ilya for it. Refusing (`abbot_dress_refused`) can be taken back.

The dress (quest `dress_found`):

- **Anna's**: "The Abbot asked us for a wedding dress..." Anna gives her own, kept for her daughters, whether the party
  tells her the truth or not (`anna_dress_given`, `wedding_dress_found`, `wedding_dress_source = "anna"`). Refusing her
  points the party to the matron's room (`anna_dress_declined`). If the party later uses the matron's dress instead, it
  can bring Anna's back (`anna_dress_returned`).
- **The matron's**: in a trunk in her locked room in the wards (door DC 13; container flag `wards_dress_found`). Clovin
  gives the hint.
- **Elsewhere (hook):** Vallaki's seamstress or Lydia Petrovna could make one; that region would set
  `wedding_dress_found` and `wedding_dress_source` (e.g. `"vallaki"`). The unveiling has a line for any other source.

"We've brought a dress for your bride." delivers it (`wedding_dress_delivered`) and goes straight into the unveiling.

### 4.5 The unveiling (the climax) and the Abbot's fate

If Ireena is present and he has seen her, the party may first send her to wait by the courtyard well
(`ireena_waits_in_courtyard`, `leave ireena`; she rejoins there). Then the Belviews carry Vasilka in on a bier,
humming, in the dress; the Abbot lays his palms on her and she wakes, politely. He means Clovin to drive her to the
castle tomorrow. The party decides (`unveiling:choice`):

| Option | Needs | Result |
|---|---|---|
| "Read him Markovia's letter." | `markovia_letter_read` (from Clovin, §4.6) | **repentant** |
| "Tell him what Ireena saw in the Pool of the White Sun." | `ireena_pool_vision` | **repentant** |
| [Persuasion DC 12] "We've read his letters..." (one try) | `wachter_evidence` or `death_house_read_strahd_letter` | **repentant**, or he refuses |
| [Persuasion DC 16] "He won't love her..." (one try) | | **repentant**, or he refuses |
| [Religion DC 14] "You were sent to keep this valley's faith..." (one try) | `abbot_nature_known` | **repentant**, or he refuses |
| "It's your abbey. We won't stand in your way." | | **wedding** |
| "Stop this. She isn't yours to give away." | | fight `bride_defends` (he won't lift a hand), then judgement |
| "Kill him." | | fight `abbot_wrath` |

After `bride_defends` (`bride_defeated`, `vasilka_fate = "destroyed"`) the Abbot kneels by her (approach) and the party
judges him: "Read him Markovia's letter." or [Religion DC 14] → **repentant** (failure → broken); "Leave him with what
he's done." → **broken**; "Kill him." → **slain** (he doesn't resist; he becomes light).

**If Ireena is in the church** when Vasilka wakes, he wants her instead ("Why send him a copy?"): "At the pool she chose
a dead man over him..." (with `ireena_pool_vision`) → **repentant**; "Never..." → fight `abbot_wrath`; "We're leaving.
All of us. Now." → he lets them go and writes to the castle about Ireena (`abbot_told_strahd`, `abbot_fate =
"wedding"`, quest `fled`). He never gets her: there is no option to hand her over.

After `abbot_wrath` (`abbot_struck_down`) Clovin speaks over the empty habit (approach): **slain**; an awake Vasilka asks
whether the wedding is cancelled (lay her to rest, or leave her standing, `abandoned`); an unwoken one stays on her
table (`never_woke`).

Every ending reaches `unveiling:the_end`, the region's one milestone.

### 4.6 Clovin and Markovia's letter

Clovin (approach, inside the abbey gate) found St. Markovia's last letter under a floorboard as a boy and can't read
it. "What's that paper you keep touching?" → "May we read it to you?" reads it aloud (our own words: she went up the
road to end the devil, not to reason with him; "patience is how he feeds"; keep the house open to the hurt and shut to
him) and sets `markovia_letter_read`, the plain key to the Abbot's repentance. He also hints at the matron's dress,
describes how Vasilka was made, shares his last inch of wine (`clovin_befriended`), and may already have met the party
on the road with a broken cart (`clovin_met_on_road`, random event).

### 4.7 The Belviews, the cells and the garden

- **The kitchen:** the family's warren (`belview_family_met`); after the Abbot's end they ask if it's all right to stop
  where they are.
- **The cells:** the Abbot's failures, starving behind bars along the wards' corridor. Animal Handling DC 13 or
  Persuasion DC 14 lets them out calmly (`wards_cells_freed`: they flee onto the mountain; Krezk sees them; the Abbot
  reproaches the party). A failure, or "Draw the pins, and stand ready to fight", starts `wards_cells`.
- **The garden:** the scarecrows the Abbot stitched climb down when the party walks along the north wall
  (`garden_sentry`); the tallest, the Stitched Sentry, holds whatever the Tarokka hid there.
- **Vasilka on her table** (wards surgery): Medicine DC 12 shows she is several women (`vasilka_examined`); Kasha's
  turned grave (`turned_earth_found`) is where some of them came from.

### 4.8 Ezmerelda d'Avenir (the Mists ally)

When `tarokka.ally.npc == ezmerelda`, she sits at the top of the abbey switchback with a spyglass on the abbey roof
(approach 5): "Say something a vampire wouldn't say." She's hunting the "angel" (angels don't stitch) and looking for
Van Richten (callbacks: `rictavio_unmasked`, `rictavio_gone`, `rictavio_secret_kept`; Madam Eva's message to eat
something, `eva_reading_done`). "We're going after the devil in the castle. Hunt with us." → `join ezmerelda`, quest
`find_the_ally found` (only when she is the card's ally); `ezmerelda_met`. She interjects in the Abbot's scenes. NPC file
`data/npcs/ezmerelda.json` (guest, `guest_build` `ezmerelda_davenir`) is shared with Van Richten's Tower, which may meet
her too (it reads `guest:ezmerelda` and `ezmerelda_met`).

## 5. The Abbot's fates

| | wedding | repentant | broken | slain |
|---|---|---|---|---|
| How | "It's your abbey..."; or fleeing with Ireena | the letter, the pool, or a won Persuasion/Religion appeal | Vasilka destroyed, then "Leave him..." (or a failed appeal) | "Kill him." after the bride fight, or `abbot_wrath` won |
| Vasilka | `sent` to the castle | `laid_to_rest` (he unmakes her) | `destroyed` | `destroyed`, `laid_to_rest`, `abandoned` or `never_woke` |
| Ilya | healed (not if fled) | healed | healed (he goes down once, silently) | not by him |
| Reward | 2 potions of healing | 2 potions of healing, the sacristy | | |
| Krezk after | a black ribbon on the gate; Dmitri furious (worse in Anna's dress) | a light walked off the mountain; Dmitri doesn't know whom to hate | the Belviews come down for bread | the bell rung for him; the abbey quiet |
| Abbey after | the Abbot glowing in his church; bell ringing with nobody in the tower | dark window; Belviews in daylight | a mute figure on the altar step | washing on a line |
| Phase 6 hook | Vasilka arrives at the castle; `abbot_told_strahd` | none | none | none |

No skill check gates any ending: every one can be reached with plain options (the letter is plain once read to Clovin).

## 6. Choices and their consequences

| Choice | Where | Options | Immediate | Downstream |
|---|---|---|---|---|
| The gate's reason | Krezk gate | Ireena, the Abbot, the wine, wolves, a priest, persuade, threaten, go to the abbey | `krezk_reason`, `krezk_gate_open` | Dmitri's warmth; refuge for Ireena (not if `cowed`) |
| Ireena's refuge | Dmitri | stay, go on | `ireena_in_krezk`, `leave ireena` | where she is when Phase 6 begins |
| Ireena at the pool | the pool | promise Sergei, stay herself | `ireena_pool_choice` | the Abbot's plain repentance; Phase 6's ending |
| The stolen wishes | the pool | take, leave | `pool_offerings_taken` | Kasha; the pool's sky |
| Ilya's cure | bedside / climax | cleric, pool water, the Abbot | `ilya_fate` | Krezk after; the epilogue |
| The dress | Anna / the wards / (Vallaki) | Anna's, the matron's, refuse | `wedding_dress_source` | Dmitri's anger at the wedding; Anna's dress returned |
| The letter | Clovin | read it, don't | `markovia_letter_read` | the plain repentance |
| The cells | wards | calm them, fight them, leave them | `wards_cells_freed` / `wards_cells_fought` | Belviews on the mountainside; the Abbot's reproach |
| Ireena at the unveiling | church | send her out, let her stay | `ireena_waits_in_courtyard` | the Abbot's demand; flight (`abbot_told_strahd`) |
| **The Abbot's fate** | church | §5 | `abbot_fate`, `vasilka_fate` | Krezk, the Belviews, Ilya, Phase 6, the epilogue |
| Ezmerelda | switchback | join, not yet | `join ezmerelda` | the ally; Van Richten's Tower |

## 7. Encounters (2024 DMG budgets for four characters)

Level 6: Low 2400 / Moderate 4000 / High 5600. Level 7: Low 3000 / Moderate 5200 / High 6800. Guests (Ireena as a
`noble`, Ezmerelda as a CR 8 hunter, Ismark) fight on the party's side. Stand-ins: the Belview Brutes are `berserker`
with a name override.

| id | Map | Trigger | L7 (XP) | L6 (XP) | Lower |
|---|---|---|---|---|---|
| `gate_wolves` | krezk | enter `krezk_road` at night while the gate is shut | werewolf, 3 dire wolves, 2 wolves (1400, below Low) | werewolf, 2 dire wolves, wolf (1150) | same |
| `garden_sentry` | garden | enter `scarecrow_row` | the Stitched Sentry (scarecrow, 60 HP) + 4 scarecrows (1000) | same | same |
| `wards_cells` | wards | `flag:wards_cells_riot` | 2 Belview Brutes + 6 mongrelfolk (1200) | Brute + 4 mongrelfolk (650) | same |
| `bride_defends` | church | dialogue (the unveiling, "Stop this") | Vasilka (flesh golem, 127 HP), 2 Brutes, 4 mongrelfolk (2900, Low) | Vasilka, Brute, 4 mongrelfolk (2450, Low) | Vasilka at 80 HP + 3 mongrelfolk (1950) |
| `abbot_wrath` | church | dialogue ("Attack the Abbot", "Kill him", "Never") | the Abbot (deva at 120 HP of 229) + 2 mongrelfolk (6000, Moderate-High) | the Abbot at 100 HP + 1 mongrelfolk (5950, High) | the Abbot at 85 HP |

The climax fight on the critical path's fighting branch is `bride_defends`, a Low fight the autopilot wins; the Abbot
himself only fights if the party attacks him or will not give up Ireena, and every warning in the region (Clovin, the
candles, Insight, Ezmerelda) says not to. His HP is cut to about half so the fight, though High, is winnable at 6-7.

Road table `krezk_road` (map `road_ambush`, 20% by day / 45% by night): 3 dire wolves + 3 wolves (750), 2 druids with
2 needle and 4 twig blights (1100), Clovin's broken cart (event, once), the White Sun waystone (event, once), 3 werewolves
+ 2 wolves at night (2200), the walking dead pilgrims: 5 Strahd zombies + 2 ghouls at night (1400).

## 8. Milestone

One `xp milestone` (level 6 → 7 or 7 → 8), in `abbey_of_st_markovia/unveiling:the_end`, guarded by
`krezk_milestone_reached`. Every ending of the Abbot's story reaches it: repentant, wedding, fled, broken (after
`bride_defends` and the kneeling judgement), slain (kneeling, or after `abbot_wrath` through Clovin's `after_wrath`).

## 9. Reading earlier regions

| Flag (owner) | Read by |
|---|---|
| `ireena_destination` (village) | gate (Ireena at the end of the road) |
| `guest:ireena`, `guest:ismark` (engine) | gate, Dmitri, the pool, the Abbot, the unveiling, Anna, banter |
| `ireena_falls_memory`, `eva_question`, `eva_reading_done`, `stanimir_tale_heard` (Svalich Road) | the pool; Ezmerelda |
| `tamsin_locket_recognized` (village) | the pool |
| `vallaki_backed` (Vallaki) | the gate (Dmitri on Vallaki's news) |
| `wizard_of_wines_hook` (Vallaki), `wine_shortage_heard` (village) | the gate (the wine reason), Dmitri, the watchman |
| `rictavio_unmasked`, `rictavio_gone`, `rictavio_secret_kept` (Vallaki) | Ezmerelda |
| `wachter_evidence` (Vallaki), `death_house_read_strahd_letter` (Death House) | the unveiling (Strahd's letters, DC 12) |
| `tarokka.ally.npc`, `tarokka.<slot>.place`, `tarokka.<slot>.region`, `treasure_at:<place>` | Ezmerelda's placement and join; the spots; the abbey's travel place |

## 10. Flags (data/flags/krezk.json) and what later regions read

All 59 flags are registered, set and read (`make validate`). The ones later regions should read:

- **`abbot_fate`** (`wedding` / `repentant` / `broken` / `slain`) and **`vasilka_fate`** (`sent`, `laid_to_rest`,
  `destroyed`, `abandoned`, `never_woke`): Phase 6 (Vasilka at the castle when `sent`; Strahd's contempt for the gift),
  the epilogue.
- **`abbot_told_strahd`**: Strahd knows where Ireena sleeps (Phase 6 harassment, the castle).
- **`ireena_pool_vision`**, **`ireena_pool_choice`** (`promised` / `stayed`): Ireena's ending in Phase 6. `promised`
  means she has sworn to return to the pool and Sergei once Strahd is dead; `stayed` means she has chosen her own life.
- **`ireena_in_krezk`**, `ismark_in_krezk`: where they are.
- **`ilya_fate`** (`healed` / `frail` / unset), `wedding_dress_source`, `krezk_gate_open`, `krezk_reason`: epilogue.
- **`ezmerelda_met`** (and `guest:ezmerelda`): Van Richten's Tower.
- Quests: `the_gate_of_krezk`, `the_burgomasters_son`, `the_abbots_bride`, `the_pool_of_the_white_sun`; and the shared
  `find_the_ally found` (Ezmerelda), `find_the_tome` / `find_the_holy_symbol` / `find_the_sunsword found` (dialogue spots).
- **Other regions may set** `wedding_dress_found` with `wedding_dress_source` (a Vallaki dress).

## 11. Tarokka places and the ally

Each place is a location of the same id with one `treasure_spots` entry:

| Place (cards) | Location | Spot | How it's found |
|---|---|---|---|
| `krezk_pool_of_the_white_sun` (Glyphs 3) | `krezk_pool_of_the_white_sun` | dialogue `krezk/pool:the_pool` | use the pool (prop `white_sun_pool`, [9, 10]) → "Wade in." → `tarokka give`. Behind Krezk's gate. If Ireena hasn't had her vision yet, the first use plays it; use the pool again. Moves the right `find_the_*` quest. |
| `abbey_of_st_markovia_shrine` (Glyphs 1) | `abbey_of_st_markovia_shrine` | dialogue `abbey_of_st_markovia/shrine:sunburst` | use the sunburst over the altar (prop `chapel_sunburst`, [12, 0]) → "Lift it down from its hooks and look behind it." → `tarokka give`. Moves the quest. |
| `abbey_of_st_markovia_wards` (Coins 2) | `abbey_of_st_markovia_wards` | container `foundling_locker` ([12, 2], foundling ward) | open it. |
| `abbey_of_st_markovia_garden` (Glyphs 2) | `abbey_of_st_markovia_garden` | encounter `garden_sentry` | walk into `scarecrow_row`; win the fight; the Stitched Sentry's loot. |

Hints: when a treasure waits there (`treasure_at:`), the pool shows something catching a light under the water, the
sunburst shows a thin line of light round its edge, and Kasha mentions the shine in the pool.

**Ally (Mists):** `ezmerelda`, §4.8: `abbey_of_st_markovia` switchback, `abbey_of_st_markovia/ezmerelda:start` →
"We're going after the devil in the castle. Hunt with us." → `join ezmerelda`.

## 12. Loot

| Container | Map | Contents | Notes |
|---|---|---|---|
| `krezk_woodshed_crate` | krezk | 3 torches, 2 oil | by the woodpile inside the gate |
| `anna_chest` | Krezkovs' house | perfume, 4 candles, blanket, 15 gp | locked DC 15; robbing it sets `krezkov_chest_robbed` (Anna notices) |
| `krezkov_larder` | Krezkovs' house | 4 rations, jug | |
| `cart_shed_crate` | abbey grounds | 2 sacks, rope, 2 jugs, 6 gp | Clovin's handcart |
| `sacristy_chest` | church | 2 holy water, 6 candles, robe, 22 gp | the Abbot says to take it in the repentant ending |
| `foundling_locker` | wards | blanket, 2 candles, 3 gp | Tarokka spot |
| `bridal_trunk` | wards (matron's room) | fine clothes, perfume, 12 gp | sets `wards_dress_found` (the matron's wedding dress) |
| `surgery_cabinet` | wards | healer's kit, 3 vials, antitoxin | |
| `belview_pot` | wards | 2 rations, 2 gp | |
| `garden_shed` | garden | sickle, shovel, rope, 2 sacks | |

Given in dialogue: 2 holy water (the pool, once), 2 potions of healing (the Abbot: wedding or repentant), 40 gp (Anna,
for a cleric's cure), 9 gp (the stolen wishes).

**Curse of Strahd fixed items:** chapter 8 needs none beyond the three Tarokka treasures, which the spots hand over
(`tome_of_strahd`, `holy_symbol_of_ravenkind`, `sunsword`, all in data/magic_items).

**For the DMG magic item thread** (containers that suit a placed item): `sacristy_chest` (a holy item),
`surgery_cabinet` (potions), `bridal_trunk` (something the matron kept "for when the war is over"), `garden_shed`,
`cart_shed_crate`. The `abbot_wrath` fight could also carry `loot`.

**Item need:** a `wedding_dress` story item (data/items) so the dress shows in the pack; today the dress is tracked by
flags only (`wedding_dress_found`, `wards_dress_found`, `wedding_dress_delivered`).

## 13. Art and theme needs

- **Portraits and sprites:** `dmitri_krezkov`, `anna_krezkova`, `ilya_krezkov`, `krezk_guard` (a Krezk villager in a
  sheepskin with a spear; could fall back to `vallaki_guard`), `kasha_varo`, `abbot` (and his combat form with wings of
  light for `deva`), `vasilka` (in a shroud on her table, and in the wedding dress awake; also the `flesh_golem` combat
  sprite as Vasilka), `clovin_belview`, `belview` (several mongrelfolk variants: goat eyes, hound ears, feathered hands,
  a bull-shouldered Brute for `berserker`), `sergei_von_zarovich` (portrait as a reflection in water), `ezmerelda`.
- **Monsters:** `scarecrow` (stitched sacking in a monk's habit), `mongrelfolk`.
- **Props wanted (stand-ins used now):** scarecrow (`coats`), the White Sun pavilion statue holding a sunburst
  (`shrine_small`), the pool's edge (`ledge`, invisible; the water tiles draw the pool), the gilded abbey sunburst
  (`crest`), Markovia's statue with a mace (`statue_knight`), a surgery table and a bier (`table_round`), cell bars
  (`barred_door`), a small pipe organ (`harpsichord`), Anna's painted chest (`chest_painted`), a stone cairn (`cairn`),
  the bell tower (`palisade`, invisible), the switchback view (`rocks`).
- **Themes:** a **walled mountain village** for `krezk` (a stone wall three men high with a wall-walk and an oak gate;
  turf-roofed stone cottages; today `village` draws the one-square wall line as a low yard wall), an **abbey** for
  `abbey_of_st_markovia` (grey stone wings, slate, a cloister, a bell tower), a **frost garden** variant of
  `shrine_yard` for the garden, a **whitewashed infirmary** for the wards (today `dungeon`), and the pool's water with a
  white open pavilion in `shrine_yard`.

## 14. The critical path (story bot)

Party of four at level 6, by day, starting at `krezk` (or travelling there from Vallaki: the place is on the map from the
start). Prefer, in this order: `"The Abbot of St. Markovia sent us"`, `"Is there anywhere up here"`,
`"What's that paper"`, `"May we read it"`, `"Clovin says you have work"`, `"Go on."`, `"We'll find her a dress."`,
`"The Abbot asked us for a wedding dress"`, `"Tell her the truth"`, `"We've brought a dress"`,
`"Read him Markovia's letter."`. Avoid: `"Attack"`, `"Kill"`, `"Steal"`, `"Intimidation"`, `"No. We won't help"`,
`"No. We can't take this"`, `"We're leaving"`, `"Stop this"`, `"It's your abbey"`.

1. At Krezk the watchman speaks on approach (or `talk("krezk_guard")`): "Is there anywhere up here that does take
   strangers?" → `krezk_abbey_directed`, quest `the_gate_of_krezk refused`.
2. `go_to("abbey_of_st_markovia")` (exit `abbey_track_up`). Clovin speaks on approach: "What's that paper you keep
   touching?" → "May we read it to you?" → `markovia_letter_read`.
3. `go_to("abbey_of_st_markovia_shrine")`. The Abbot speaks on approach: "Clovin says you have work in the wards. What is
   it?" → "Go on." → "We'll find her a dress." (he vouches at once while the gate is shut) → `abbot_dress_asked`,
   `abbot_vouched`, quests `the_abbots_bride asked`, `the_burgomasters_son abbot_offer`.
4. `go_to("krezk")`, `talk("krezk_guard")`: "The Abbot of St. Markovia sent us. He vouches for us." → `krezk_gate_open`
   (`krezk_reason = "abbot"`).
5. `go_to("krezk_burgomaster_house")` (through the gate door), `talk("anna_krezkova")`: "The Abbot asked us for a
   wedding dress..." → "Tell her the truth..." → `wedding_dress_found`, quest `dress_found`.
6. `go_to("abbey_of_st_markovia_shrine")`, `talk("abbot")`: "We've brought a dress for your bride." → the unveiling →
   "Read him Markovia's letter." → the milestone.

Expected at the end: `abbot_fate == "repentant"`, `vasilka_fate == "laid_to_rest"`, `ilya_fate == "healed"`,
`krezk_milestone_reached`, quests `the_abbots_bride repented`, `the_burgomasters_son healed`, `the_gate_of_krezk
opened`. **Fighting branch:** at the unveiling prefer "Stop this. She isn't yours to give away." → fight
`bride_defends` (Low) → `talk("abbot")` (he kneels, approach) → "Leave him with what he's done." → `abbot_fate ==
"broken"`, milestone. **Wedding branch:** "It's your abbey. We won't stand in your way." → `"wedding"`.

The treasure spots and ally (§11): pool, `use([9, 10])` in `krezk_pool_of_the_white_sun` → "Wade in."; sunburst,
`use([12, 0])` in `abbey_of_st_markovia_shrine` → "Lift it down"; the foundling locker `use([12, 2])` in the wards; the
garden fight on entering `scarecrow_row`; Ezmerelda `talk("ezmerelda")` → "We're going after the devil in the castle.
Hunt with us."

## 15. Engine needs the format can't express

- **Moving the treasure quest for container and encounter spots.** Dialogue spots move `find_the_tome` / `_holy_symbol`
  / `_sunsword` to `found` themselves; the foundling locker and the garden fight can't. The engine should move the
  slot's quest when `Tarokka.take_from` yields it (or tell writers how to).
- **A conversation that starts on entering an area** (`enter_area` → dialogue, with a condition). Ireena's vision
  should begin when she walks into the shrine yard, not when someone uses the pool; today the Narrator hints
  ("Ireena has stopped walking") and the pool is the trigger.
- **Monsters placed on occupied squares.** `start_encounter` doesn't nudge a monster off a square a party member or
  guest stands on. The church fights put the monsters away from where the party talks to the Abbot, but a nudge would be
  safer everywhere.
- **A watchman on the wall-walk.** An NPC can't stand on a wall square, so the gate's watchman stands outside the gate.
- **A `wedding_dress` story item** (§12).
- **Time for the rite.** The Abbot "doesn't wait for dusk"; a `time until` before the rite would push the clock to night
  for a party arriving in the morning (left out so the bot's day stays a day).
- **Shared narrator triggers.** `combat:start` / `combat:victory` variants here are gated with `at:<location>`; a
  `here:<region>` condition (as Vallaki asked) would be tidier.

## 16. Files

- Region: docs/regions/krezk.md (this file); task docs/tasks/P5-07.md
- Voice: docs/voice/{dmitri_krezkov, anna_krezkova, ilya_krezkov, krezk_guard, kasha_varo, abbot, vasilka,
  clovin_belview, belview, sergei_von_zarovich, ezmerelda}.md
- NPCs: data/npcs/{dmitri_krezkov, anna_krezkova, ilya_krezkov, krezk_guard, kasha_varo, abbot, vasilka, clovin_belview,
  belview, sergei_von_zarovich, ezmerelda}.json
- Quests: data/quests/{the_gate_of_krezk, the_burgomasters_son, the_abbots_bride, the_pool_of_the_white_sun}.json
- Flags: data/flags/krezk.json
- Locations: data/locations/{krezk, krezk_burgomaster_house, krezk_pool_of_the_white_sun, abbey_of_st_markovia,
  abbey_of_st_markovia_shrine, abbey_of_st_markovia_wards, abbey_of_st_markovia_garden}.json
- Travel: data/travel/krezk.json (places `krezk`, `abbey_of_st_markovia`; roads Vallaki → Krezk, 5 h, table
  `krezk_road`; Krezk → the abbey, 1 h). Random table: data/random_encounters/krezk_road.json
- Dialogue: narrative/krezk/{gate, dmitri, anna, pool, kasha, ireena, road}.dialogue;
  narrative/abbey_of_st_markovia/{abbot, unveiling, clovin, belviews, vasilka, shrine, ezmerelda}.dialogue;
  narrative/narrator/{krezk, abbey_of_st_markovia}.dialogue; narrative/banter/krezk.dialogue
