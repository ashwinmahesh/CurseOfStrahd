# Gemini drafts for package M3 (Ezmerelda at camp, Madam Eva's card, the plan at the castle)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`,
project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id
is reported in the bridge's records.

| File | What it is |
|---|---|
| `brief_1.txt` | The five camp talks (one with two openings): the situation, each scene's occasion, the shape, voice and canon limits |
| `reply_1.reply.txt`, `reply_1.messages.json` | Gemini's reply, untouched, and the bridge's record |
| `brief_2.txt` | Madam Eva's card, Ezmerelda's plan at the drawbridge, two lines in the catacombs |
| `reply_2.reply.txt`, `reply_2.messages.json` | Gemini's reply, untouched, and the bridge's record |
| `brief_3.txt`, `reply_3.reply.txt`, `reply_3.messages.json` | The plan's second opening, for those the black carriage set down in the front courtyard (the first send failed on a relative path and was resent; the conversation shows one message) |

## What was edited after the drafts

Canon (checked against our data):

- **Kinship.** Ezmerelda called Eva "Grandmother", a relation nobody gave them: she says "Madam Eva", and Eva keeps "child".
- **Moods.** Gemini used [neutral], [wry], [amused], [serious], [fierce] and (on the Narrator) [neutral]: none is a mood of the game
  (neutral, smile, angry, afraid, sad, sly, weary), so they are gone; the plan's rules carry [smile] and [angry].
- **Where things are.** "Up the mountain" and "before we cross the river" (Tser Pool has neither) became "down the road" and
  "from Stanimir's cart" (he feeds travellers). The plan's "wooden leg" became "brace and all" (it is oak and steel). "The scout"
  in the keep opening became Ezmerelda. The plan's lantern ("within reach of my lantern") became "within reach of my voice".
- **Invented specifics.** The silver bolt "with his mark on it" went; "dried fish" (Rudolph's habit is tea, the one thing he is bad
  at) became "that terrible tea"; "the steel leg clicks" became "the brace clicks" (it is oak and steel). "Down at Tser Pool, my
  people looked right through me" assumed she had been there with the party: "would look right through me, and I would let them".
  The tambourine and the pack fighting over her boot are Gemini's jokes and stay (the show wagon and the den's pack are canon).
- **The count.** "The master of the house" and "the thing in the castle" stand in for Strahd, as asked.
- **Repeated phrases.** The castle-eve talk's "one leg that cannot bleed for him" echoed her road line ("I've got the leg that
  doesn't bleed"): it is now an answer to it ("I have the leg that doesn't bleed, remember?").

Register and length (cut about 15%): `leg_a` lost "I will live without the applause" (it read wrong when Kiril is alive). Eva's
second line lost "so do not leave your chair empty too long" and the sausage line became "one sausage a week is an insult to my
camp". The plan's first rule lost a clause; "Grandmother" and the moods are above.

Structure (mine, nothing to draft): the five opening nodes (`talk_*`, conditions, order), the leg talk's router, the prop calls and
their conditions, `rules`, which both openings share, the Eva menu entry and the flags.
