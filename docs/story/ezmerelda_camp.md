# Ezmerelda at camp, Madam Eva's card and her plan at the castle (Story Allies Presence Plan, package M3)

Ezmerelda d'Avenir travels with the party as a guest (the Tarokka's Mists ally, or by her own choice at the tower). Her hub
(package M2, `narrative/allies/ezmerelda.dialogue`) answers what she is asked. This package gives her the three things the
hub does not: talks she starts herself at the fire, a scene with the seer who dealt her into other people's games, and the
plan she gives at the castle's gates.

## The camp talks (`narrative/camp/ezmerelda.dialogue`)

After a Long Rest at camp a guest asks for a word the way a companion does (`CampTalk.who_asks` reads `guest:<npc>`,
docs/story/camp.md, "Guests ask too"): a speech bubble over her, "Ezmerelda wants a word". The file offers the first talk whose
condition holds, one a rest, each once, so the later part of the story comes first:

| Talk | Offered when (she is along, and) | What it is about |
|---|---|---|
| `castle_eve` | the party is level 9 and has not been to the castle gates | the doors she takes first; the entry she wants in Rudolph's next book, spelled right |
| `leg` | the werewolf den is settled (`wolf_pack_leader`) | two openings: Kiril alive and still hunting for the castle, or Kiril dead and the brace no lighter; the same two replies |
| `rudolph` | Van Richten and she are reunited, or the party found him out | why he keeps leaving and keys his wards to her name alone |
| `wagons` | the party has been to Tser Pool | the show wagon she was raised in, a card trick that goes slightly wrong, why she cannot go back |
| `fear` | the party is level 6 | she is not as brave as her reputation, and this may be wisdom |

Each ends after one reply to one of two things the party can say. Nothing rolls, nobody is judged, and **nothing changes**: no
flag is set. (Her trust counter, `ezmerelda_trust`, belongs to the tower and the ledger.) The hub's facts about the leg, Rudolph
and her people are not repeated: the talks are how she feels about them.

## Madam Eva's card (`narrative/svalich_road/madam_eva.dialogue`, `ezmerelda_card`)

Once the reading is done and Ezmerelda is along, Eva's later-visit menu (`again_menu`) offers "Ezmerelda is with us. Will you
read for her?". Eva, who has been telling her to eat since she was six, turns one card from the bottom of the deck, not one of
the five of the reading and not named: an empty chair beside a cold hearth and a shuttered lantern. Nothing is foretold. The
party can ask what it means ("The cards do not mean. The cards are patient, and they wait.") or tell Ezmerelda to eat. Once
(`eva_card_for_ezmerelda`), and back to Eva's menu.

## The plan at the castle (`narrative/allies/ezmerelda_castle.dialogue`)

Two props of `castle_ravenloft_gates` call it on approach (a prop's `call`, `approach` 6, once; `call_when`: she is along and the
plan not yet told): the drawbridge's chains (`plan`, for those who walk up the road) and the keep's carved crest (`plan_keep`,
for those the black carriage set down in the front courtyard). She answers her own line in the hub ("Paper plans die on the
drawbridge") with four rules: look for the master of the house by daylight, nobody lifts the lid until all are ready to finish
it, nobody wanders off, and if she says run, they run. It gives no puzzle answers and says where nothing is. It sets
`ezmerelda_castle_plan`, which unlocks her two lines on entering the catacombs and the tombs (`quest_plan_catacombs`,
`quest_plan_tombs` in `narrative/banter/guest_ezmerelda.dialogue`).

## Lines

59 new unvoiced lines: the camp talks 38, the plan 9, Eva's card 10 and the two catacomb lines. Drafted by Gemini through the
ai-bridge (`docs/plans/gemini_allies/m3/`), edited.

## Tests

`tests/unit/test_ezmerelda_camp.gd`: she asks only while she is along; each talk waits for its event; they come one a night, the
later story first, each once; the camp offers her bubble; every talk ends after one reply by either option and sets no flag; the
leg talk's two openings; her never naming the count; Eva's card (offered once, only with her along, both replies, only its own
flag); the plan's rules and flag; the catacomb lines. `tests/integration/test_ezmerelda_castle_calls.gd` boots the gates: the two
props carry the call, it plays once at the chains with her along, never without her or after the plan, and under the crest for
those the carriage set down.
