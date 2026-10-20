# Gemini drafts for package I4 (Ireena at camp, and the fights she watches)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`,
project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id
is reported in the bridge's records.

| File | What it is |
|---|---|
| `brief_1.txt` | The seven camp talks: the situation, each scene's occasion, the shape (scene, two options, two replies), voice and canon limits |
| `reply_1.reply.txt`, `reply_1.messages.json` | Gemini's reply, untouched, and the bridge's record |
| `brief_2.txt` | Two redrafted and two new road lines for after a fight, and four Narrator lines from the back of one |
| `reply_2.reply.txt`, `reply_2.messages.json` | Gemini's reply, untouched, and the bridge's record |

## What was edited after the drafts

Canon (checked against our data):

- **Invented specifics.** The castle's "third step on the south turret stair has a cracked riser" became "I know where the
  stairs go" (her own existing line), and the reply that warned about "that third stair" now says "the stairs". The burial's
  "took three hours to dig" became "dug by lamplight"; the man in the water's warm hand went (only the name he knew her by is
  ours); the fight count "seven blows given, three taken on the left flank" became "every blow, and who took it".
- **Who carved the dolls.** Izek had Blinsky carve them, he did not carve them: "carving my face into little dolls" became
  "who had my face carved". "The Baron's man" went (he has left the Baron's service once he knows) and so did "winter fevers".
  "If we pass through Vallaki again" became "If I meet him again" (he leaves Vallaki after the truth).
- **The window.** "before you caught my arm" invented how she was held back (there are six ways it ends); the casement is
  not the churchyard gate, so the talk is not offered for it.
- **The burial.** A hasty burial has no words, so the talk has a variant for it and the first option no longer says "with
  every proper word".
- **Moods.** Gemini used [defiant], [bitter], [dry], [tense], [urgent], [somber] and [steady]: none is a mood of the game
  (neutral, smile, angry, afraid, sad, sly, weary), so they are gone, and the Narrator's combat lines carry none.

Register and length (cut about 15%): "Do not pull your wrist on the parry" went from `kept_back_a`; the amber reply's "lean winter
bargain" became "hard bargain" and "comes off with soap" became "washes off"; a typo ("Ifthose"); the pool's "across the years" went from `pool_a`; the burial's
"The village church has lost enough of its register" became "The village has lost enough of its record"; the stone line lost
"heavy" and "back to the dirt" (a combat line is one sentence under 15 words).

Structure (mine, nothing to draft): the seven opening nodes (`talk_*`, the condition each waits for and their order), the two
pool openings' router, the hasty-burial variant, the trust each option gives, and the option texts' pairing with the replies.
