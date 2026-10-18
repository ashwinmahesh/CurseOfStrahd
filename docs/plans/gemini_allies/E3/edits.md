# E3: Ireena keeps out of fights: Narrator lines

Drafted by Gemini through Ashwin's ai-bridge (service v2.0.0, project `ai-bridge`, target `gemini`, 2026-10-18, subscription,
no API key). `brief.md` is what was sent, `reply.json` the bridge's whole record of the exchange (brief, reply, state), and
`reply.txt` Gemini's reply verbatim. Nothing is voiced: the lines are listed in the hand-off for the voice thread.

The game's file is `narrative/narrator/keeps_back.dialogue`. Six lines: the first-fight line (`combat:keeps_back:ireena:first`,
plays once) and five for later fights (`combat:keeps_back:ireena`, one a fight, cooldown 20 game minutes).

## What was kept and what was cut

| Key | Gemini's | Final | Why |
|---|---|---|---|
| first | A1 "Ireena steps back from the fray, her hand still on her pommel. Whatever comes for your throat parts around her like dark water round a stone." and A2 "...as if it has been warned whose she is." | "Ireena steps back, blade sheathed. What comes for you goes round her like water round a stone, as if it had been told whose she is." | Joined A1's image with A2's hint (27 words, under the 30 the brief allowed). "Hand on her pommel" read as if she might draw, "your throat" and "warned" were more melodrama than the Narrator's register; "told whose she is" is the plan's wording. |
| 1 | B1 | B1 as written | 14 words, shows her hating it without whining. |
| 2 | B2 | B2 as written | The enemies' eyes sliding past her; 11 words. |
| 3 | B6 | B6 as written | 13 words; "cannot answer" is the hurt, said without pity. |
| 4 | B7 "Not one blade angles toward Ireena where she waits at the roadside." | "Not one blade angles toward Ireena where she waits." | "At the roadside" would be wrong in a house or a crypt: fights happen anywhere. |
| 5 | B8 | B8 as written | The distance between your back and the dark; 13 words. |

Left out: B3 (jaw set hard, three paces: nearly B1), B4 (swallowing the sharp word: soft, and "yields the ground to you" reads as
the party's doing), B5 ("as if she stood behind glass": the opposite of her own line "I'm not made of glass", and it makes
her sound protected like a damsel, which the brief ruled out).

Checks: no `{name}` or `{target}` (so all six can be voiced); none names Strahd, a vampire or who claims her; none shows her
drawing steel, being hurt or being guarded; every regular line is one sentence under 15 words (docs/voice/narrator.md rule 8).
