# The companions' personal quests

Owner request (2026-10-06): "create good personal quests for each of the prebuilt characters that are intertwined
with the story of the world (like a good DM would)". Each pregen came to Barovia for a reason (docs/voice/*.md); these
quests turn those reasons into four arcs that run through the places already built (Phases 1 to 5) and end in Castle
Ravenloft (Phase 6, hooks below). They reuse the hooks the region writers already planted (Madam Eva's question and
price, Strahd's lines at the grave, Ireena and the locket, Donavich and the raven, Aurel's note, the vestiges) and add
a few scenes of their own.

## Rules every scene follows

- **Only with the companion.** Every scene, option and prop needs that pregen in the party (`name:` selectors and
  conditions, props' and NPCs' `when`). A custom hero never answers to a pregen's name (`StoryState.member_matches`),
  so when the hero takes a pregen's place that pregen's quest never starts and nothing of it shows. The other three
  quests run normally; lines other companions speak are interjections, so a missing companion simply says nothing.
- **Stages only move forward.** Every `quest` statement outside the opening is guarded by
  `if not (quest.<id> >= <stage>)`, so finding things out of order never rolls the journal back.
- **Camp talks.** After a Long Rest a companion may ask for a word (`story/camp_talk.gd`, `narrative/camp/<who>.dialogue`;
  the rest screen shows a button such as "Ilse wants a word"). A talk is a node whose first statement is `if
  <condition>`; it's offered once the condition holds, plays once, and each companion offers one at a time.
- **Party banter** that follows the quests anywhere: `narrative/banter/party_companions.dialogue`.
- Failed Persuasion and Insight options are spent (owner rule); every menu has another way on.

## Ilse Varga: Count Off (`kestrel_company`)

Kestrel Company, forty mercenaries, marched into Barovia a year ago on Strahd's invitation; Ilse let a fever keep her
behind. Madam Eva told her some of the forty "walk his roads still, in colours that are not their own".

| Stage | Where | How |
|---|---|---|
| `the_letter` | Into the Mists, the mist wall | arrival:hooks |
| `the_host` | Village: Ismark reads the letter, or Strahd at the grave | ismark:letter, burial |
| `the_tally` | Svalich crossroads: a carved milestone (prop `kestrel_tally_crossroads`) | companions/kestrel:tally_crossroads |
| `the_count` | Tser Pool: a marked ash (prop `kestrel_tally_tser`) | companions/kestrel:tally_tser |
| `the_deserter` | Vallaki: Jory Fenn at the south-east watch fire (npc `jory_fenn`); Stanimir can point there | companions/kestrel:jory, :stanimir |
| `vell_met` | Crossroads castle road, at night, level 5+, after the second tally (npc `kestrel_vell`) | companions/kestrel:vell |
| `vell_rests` | Win `kestrel_patrol` (or `kestrel_patrol_reached` if Ilse's Persuasion 15 got through to Vell: he fights held back, 45 HP) | encounter on svalich_crossroads |
| `count_off` | **Phase 6** (success) | castle hook |

Choices: forgive Jory or not (`kestrel_jory_forgiven`); reach Vell or not (`kestrel_vell_reached`). Camp talks: the
fever (`kestrel_fever_shared`, unless she told Madam Eva) and, after Vell, "Count off".

## Tamsin Tealeaf: The Woman in the Locket (`the_locket`)

Tamsin lifted a locket from a coach with no driver. It holds Tatyana's portrait, and her voice has called him since.
He was a courier who didn't know it: Strahd left the locket on his carriage seat for a thief to carry to Ireena.

| Stage | Where | How |
|---|---|---|
| `the_dreams` | Into the Mists | arrival:hooks |
| `her_face` | Village: Tamsin shows Ireena the locket | ireena:locket |
| `her_name` | Madam Eva's answer, or Sergei in the Krezk pool | madam_eva:q_locket, pool:ireena_vision |
| `the_inscription` | Camp talk: the back of the locket, "For T., from S. Every morning, at the water." (Ilse compares her S) | camp/tamsin |
| `the_coach` | Henrik's black carriage tells him (`locket_coach_known`); the camp talk or Arrigal confirm it | vallaki/henrik:confess, camp/tamsin, companions/locket:arrigal |
| `given_to_sergei` / `given_to_ireena` / `kept` | Krezk, the Pool of the White Sun: drop it in, give it to Ireena (if she travels with you), or keep it (`locket_fate`) | companions/locket:pool |

## Hedda Ironvow: Cold Prayers (`cold_prayers`)

Hedda dreamed of a silver raven with a sunburst; since the mist her god has felt far away. The warmth reaches
Barovia where somebody carries it.

| Stage | Where | How |
|---|---|---|
| `the_dream` | Into the Mists | arrival:hooks |
| `cold` | Madam Eva's price (Hedda's truth), or a camp talk after the burial | madam_eva:truth_hedda, camp/hedda |
| `the_symbol` | Village: Donavich names the Holy Symbol of Ravenkind | donavich:raven |
| `a_spark` | Vallaki: St. Andral's bones come home (`hedda_spark_felt`) | vallaki/lucian:return |
| `the_keepers` | Wizard of Wines: Davian tells the Keepers' story of the raven and the sun | companions/prayers:davian |
| `warmth` | Camp talk once the Holy Symbol is found (wherever the cards put it) | camp/hedda |
| `dawn` | **Phase 6** (success) | castle hook |

## Silvain Aster: Aurel's Last Chapter (`aurels_last_chapter`)

Aurel Mirescu went after the Tome of Strahd and wrote home once: "He knows I am reading." Madam Eva: "He is reading
still." Strahd keeps him in the east tower as an audience.

| Stage | Where | How |
|---|---|---|
| `the_letter` | Into the Mists | arrival:hooks |
| `the_satchel`, `the_cipher` | Camp talk after Aurel's note is read: his shorthand points to a showman in Vallaki and the Amber Temple | camp/silvain |
| `the_hunter` | Vallaki: Rictavio met him | companions/aurel:rictavio |
| `the_margins` | Amber Temple library: Aurel's note to Silvain in a chained book (prop `aurel_margins`) | companions/aurel:margins |
| `still_reading` | Camp talk once the Tome is found: Strahd's own note, "My reader Mirescu asks again to be allowed to sleep." | camp/silvain |
| `the_last_page` | **Phase 6** (success) | castle hook |

## Castle Ravenloft hooks (Phase 6, for the build thread)

Each is a trigger, a place and a payoff; every one needs its companion present (`name:`), and each quest's final
stage already exists in its quest file.

1. **Kestrel Company's table.** Trigger: Ilse present and `quest.kestrel_company >= the_deserter`. Place: the great
   dining hall, set for forty with the company's coats on the chairs; Captain Aldous Merrow (vampire spawn) at the
   head, the rest of the turned company in the walls and cellars. Payoff: Ilse calls the roll (`flag.kestrel_roll_kept`:
   she reads it from the captain's own book); Merrow answers for it (fight, or a Persuasion 18 roll call that makes
   him stand and be counted). If `flag.kestrel_jory_forgiven`, Jory's drum beats the company's call at the gate when
   the party arrives. `quest kestrel_company count_off`.
2. **Tatyana's portrait.** Trigger: Tamsin present. Place: wherever the castle hangs Tatyana's portrait (the locket's
   twin). Payoff by `flag.locket_fate`: "kept", Strahd asks for it ("You carried her home. Now give her to me."), and
   Tamsin gives it (`quest the_locket given_to_strahd`, failure) or throws it into the fire (`quest the_locket
   burned`, success); "pool", Strahd notices it's gone ("You gave it to my brother. How very like him to accept.");
   "ireena", if Ireena is with you she shows Strahd she has it, and remembers more. (Those two already ended at the
   pool; the castle beat is a payoff, not a stage.)
3. **Dawn in the devil's chapel.** Trigger: Hedda present carrying the Holy Symbol of Ravenkind
   (`quest.cold_prayers >= warmth`). Place: the castle's chapel. Payoff: she prays at the defiled altar and, for the
   length of the prayer, real dawn light comes through the windows; `quest cold_prayers dawn`.
4. **The east tower.** Trigger: Silvain present, `quest.aurels_last_chapter >= still_reading` (or simply reaching the
   tower: Aurel's note named its lit window). Place: the east tower library, the lamp that never goes out. Aurel,
   alive but kept awake and charmed, reads the Tome aloud to an empty chair. Payoff: wake him (Arcana or Persuasion
   15, or the Tome itself closed in his hands) and get him out, or, if the castle has turned him, Silvain's mercy;
   `quest aurels_last_chapter the_last_page`.

## New NPCs

`kestrel_vell` (Corporal Vell, vampire spawn; uses the vampire spawn art) and `jory_fenn` (Jory Fenn, Vallaki watchman;
uses the Vallaki guard art). Voice bibles: docs/voice/kestrel_vell.md, docs/voice/jory_fenn.md.

## Lines to voice

Every line in `narrative/companions/*.dialogue`, `narrative/camp/*.dialogue` and
`narrative/banter/party_companions.dialogue`, plus the lines added to existing files (arrival hooks have no new
lines; henrik:confess, lucian:return have one interjection or narration each). Lines with `{name}` are never voiced.
