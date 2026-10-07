# The companions' personal quests

Owner requests (2026-10-06): "create good personal quests for each of the prebuilt characters that are intertwined
with the story of the world (like a good DM would)", then "replace the playable characters" with six new ones and
"redo any dialogue". Each of the six came to Barovia for a reason (docs/voice/<id>.md); these quests turn those
reasons into arcs that run through places the campaign already has and pay off in Castle Ravenloft. They lean on the
module's own threads: the dead Order at Argynvostholt, the Abbot, Kiril's pack, the Martikovs and Mordenkainen,
Kasimir, Patrina and Rahadin, Master Vosk and Strahd's letters.

The first four companions (Ilse, Tamsin, Hedda, Silvain) leave the roster (`roster: false`). Their data stays in the
game so older saves keep working (owner, 2026-10-06): their quests (`kestrel_company`, `the_locket`, `cold_prayers`,
`aurels_last_chapter`), flags (data/flags/companions_first_four.json), NPCs (`kestrel_vell`, `jory_fenn`,
`kestrel_merrow`, `aurel_mirescu`), scenes (narrative/companions/{kestrel,locket,prayers,aurel}.dialogue), camp talks,
banter (banter/party_companions.dialogue), props, Madam Eva's options, the hooks that move their quests on, and their
Castle Ravenloft payoffs (narrative/castle_ravenloft/personal_*.dialogue, tests/integration/test_castle_personal_quests.gd).
Everything of theirs is gated on `name:` so a new game never sees it. Their incidental party lines in the regions were
rewritten for the six, so in an old save they speak only in their own quest scenes.

## Rules every scene follows

- **Only with the companion.** Every scene, option and prop needs that pregen in the party (`name:` selectors and
  conditions, props' and NPCs' `when`). A custom hero never answers to a pregen's name (`StoryState.member_matches`),
  so when the hero takes a pregen's place that pregen's quest never starts and nothing of it shows.
- **Stages only move forward.** Every `quest` statement outside the opening is guarded by
  `if not (quest.<id> >= <stage>)`, so finding things out of order never rolls the journal back.
- **Camp talks.** After a Long Rest a companion may ask for a word (`story/camp_talk.gd`, `narrative/camp/<who>.dialogue`).
  A talk is a node whose first statement is `if <condition>`; it's offered once the condition holds and plays once.
- **Party banter** between the six plays anywhere: `narrative/banter/party_six.dialogue`, each exchange gated on its
  speakers being in the party.
- **Madam Eva** takes a truth from any of the six as her price, and answers one question from each
  (`narrative/svalich_road/madam_eva.dialogue`; flags `eva_truth_teller`, `eva_question`).
- Scenes live in `narrative/companions/<quest>.dialogue`; hooks in region files jump there and come back.
- `knows:<spell>` (new selector): a party member who can cast that spell now. Thistle's cure needs `knows:remove_curse`.

## Godrick Pendlebrook: A Knight, More or Less (`the_ladle`)

Sir Pellam knighted his squire with a soup ladle on his deathbed and sent him to have it done "proper" by the Order of
the Silver Dragon, with the sword of Pellam's grandfather Sir Aldric Ashgrove, who rode out of the mists the night
before the Order's last battle. Vladimir remembers Aldric as a deserter; Sir Godfrey wrote the truth on his wall.

| Stage | Where | How |
|---|---|---|
| `the_errand` | Into the Mists | arrival:hooks |
| `the_order_found` | Argynvostholt: Godrick shows Sir Godfrey the sword | godfrey menu, companions/ladle:sword |
| `the_deserter` | Vladimir calls Aldric a coward (skipped if the wall was read first; Godrick quotes it back) | vladimir menu, ladle:vladimir |
| `kept_faith` | Low on Godfrey's wall: "Aldric Ashgrove rode for help. The dragon sent him." | godfrey menu, ladle:wall |
| `knighted` | Godfrey knights him once the Order has its oath back (`godfrey_remembers`); gives a +1 sword | godfrey menu or companion menu, ladle:knighting |

Madam Eva: truth "he can barely read"; question "is the Order still here?" Camp: the ladle; learning to read
(`godrick_letters`); the ladle passed on after the knighting.

## Liriel Dawnsong: Carry the Dawn (`carry_the_dawn`)

The Morninglord showed her a valley with no sun and told her to carry the dawn there. Her test is the Abbot, an angel
of her own heaven, sewing the devil a bride.

| Stage | Where | How |
|---|---|---|
| `the_vision` | Into the Mists | arrival:hooks |
| `the_silence` | Her god feels far away | camp/liriel:talk_silence |
| `a_spark` | St. Andral's bones come home | vallaki/lucian:return |
| `the_angel` | She knows the Abbot for an angel and kneels | abbey abbot:first |
| `the_fall` | The Abbot reveals the bride | abbot:bride |
| (choice) | "Do you still remember the sun?" (`liriel_asked_abbot`) opens a way to his repentance at the unveiling | abbot menu, companions/dawn:sun, :unveil |
| `faith_kept` | After the Abbot's story ends, any ending | camp/liriel:talk_faith |
| `the_dawn` | She sings real dawn into Castle Ravenloft's chapel (prop `crg_chapel_dawn_step_liriel`) | dawn:chapel |

Madam Eva: truth "she's afraid of the dark"; question "will dawn come?"

## Thistle: Grandda's Trail (`fens_trail`)

Raised in the woods by the trapper Fen Burley, who followed a giant wolf into the fog. Kiril's pack, hunting beyond the
mists, bit him; he wouldn't hunt children, so he hangs in silver in the den beside Emil (npc `fen_burley`).

| Stage | Where | How |
|---|---|---|
| `the_trail` | Into the Mists | arrival:hooks |
| `the_blazes` | Svalich crossroads, a dead tree by the signpost (prop `fen_blaze_crossroads`) | companions/fen:blaze_crossroads |
| `the_wolf_road` | Lake Zarovich trail, a left-handed blaze and the word RUN (prop `fen_blaze_lake`) | fen:blaze_lake |
| `found_him` | Werewolf den caves, west alcove | fen:start |
| `fen_cured` / `fen_freed` / `fen_rests` | Remove Curse; break or pick his chains (or Emil's key); or mercy at his asking (`fen_fate`) | fen:cure, :freed, :mercy |

Kiril asks her to run with the pack before the challenge (`kiril_offer_heard`, werewolf_den/kiril:challenge). Madam
Eva: truth "she likes towns and fits nowhere"; question "is Grandda alive?" Camp: Grandda; the cakes; after Fen.

## Ratatoille: A Seat at the Table (`a_seat_at_the_table`)

He learned magic so people would sit with him, and came to apprentice himself to "the Wizard of Wines". It's a
winery, named for the wizard who paid the Martikovs in vine stones: Mordenkainen, now mad on Mount Baratok.

| Stage | Where | How |
|---|---|---|
| `the_apprenticeship` | Into the Mists | arrival:hooks |
| `a_winery` | Davian: the Wizard of Wines is a winery, named for a rude wizard who played dragonchess against himself | wizard_of_wines/davian:stones or menu, companions/table:winery |
| `the_kitchen` | He cooks the Martikovs' supper once the winery is theirs again | davian menu, table:supper |
| `the_wizard_found` | He recognises the mad mage (or connects him at the winery if met first) | mount_baratok/mordenkainen:start |
| `the_masters_word` | Mordenkainen restored: "Status is a coat. Cook." | mordenkainen restored menu, table:apprentice |
| `his_own_table` | He cooks for the party: "Ratatoille. Cook. And wizard. In that order." | camp/ratatoille:talk_table |

Temptations along the way: Zantras's audience in the Amber Temple (`ratatoille_zantras_refused`) and Strahd's offer of
a title and a tower at dinner (`ratatoille_refused_strahd`); the final talk mentions whichever he turned down.

## Wren Featherfoot: The Last Lesson (`the_last_lesson`)

His master Sorrel, a dusk elf who never spoke of home, died before the last lesson and left a letter for "my brother
Kasimir". Sorrel was Kasimir's and Patrina's younger brother, who left before the mists; Rahadin killed their mother.

| Stage | Where | How |
|---|---|---|
| `the_letter` | Into the Mists | arrival:hooks |
| `the_brother` | The Vistani camp: Kasimir reads it aloud: "Let her rest, brother. Don't go to the temple." | vallaki/kasimir menu, companions/lesson:kasimir |
| (choice) | At Patrina's ghost, Wren has Kasimir read her the last line; it leads to her rest | amber_temple/patrina:kasimir_meets, lesson:patrina |
| `let_her_rest` | After patrinas_wail ends (at rest, destroyed, or restored) | camp/wren:talk_rest |
| `the_chamberlain` | Rahadin, in Castle Ravenloft | castle_ravenloft/court_rahadin menu, lesson:rahadin |
| `learned` / `unlearned` | Pity instead of hate, and he walks away (success); or he goes for Rahadin's throat (failure, the fight) | lesson:rahadin_pity, :rahadin_rage |

## Kip Smudgewick: The Fine Print (`the_fine_print`)

He signed a devil's contract to save the family orchard (the apricots never rot). Mister Quillon (npc
`mister_quillon`, at the campfire only) offered a way out: "a signature of the lord of the land of mists, freely given,
in his own hand". He meant a soul. It says signature.

| Stage | Where | How |
|---|---|---|
| `the_contract` | Into the Mists | arrival:hooks |
| `the_assessor` | Quillon calls at the fire | camp/kip:talk_quillon |
| `the_small_print` | The party reads it (Ratatoille, Wren or Liriel, or Kip's Investigation 14), or Master Vosk reads it for a fee | camp/kip:talk_reading, amber_temple/vosk menu, companions/fine_print:vosk |
| `signed` | Strahd's first letter kept (Kip asks for it), his dinner invitation kept, or Strahd signs at dinner | strahd/letters:first and :invitation_choice, castle_ravenloft/gates_dinner |
| `free` | Quillon is paid with the signature; the contract burns; the apricots start to rot | camp/kip:talk_settle |
| `strahds_debtor` | At dinner Kip lets Strahd buy the contract instead (failure) | fine_print:dinner_sold |

## Castle Ravenloft

The castle beats are built in rather than left as hooks: Liriel's dawn at the chapel altar step, Wren's lesson with
Rahadin, Ratatoille's and Kip's moments at Strahd's dinner, and Strahd greeting each of the six by what they came for
(castle_ravenloft/gates_dinner). Godrick's knighting happens at Argynvostholt.

## New NPCs

`fen_burley` and `mister_quillon`, each with a portrait of their own; on the map Fen wears the werewolf figure and
Quillon (who only appears at the campfire) the noble's. Voice bibles: docs/voice/fen_burley.md, docs/voice/mister_quillon.md.

## Lines to voice

Every line in `narrative/companions/*.dialogue`, `narrative/camp/*.dialogue` and
`narrative/banter/party_six.dialogue`, plus the party lines rewritten across every region for the six. None are voiced
until the owner picks the six's voices. Lines with `{name}` are never voiced.
