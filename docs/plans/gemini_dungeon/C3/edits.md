# C3: what was edited in Gemini's draft

The brief is brief.md; the raw reply is gemini_reply.json (the bridge's message record, sent to `gemini` on 2026-10-18; the
model was not named in the request, so it is whatever the bridge's default for Gemini was and is not reported here).
It answered all 56 slots. Where the lane changed a line, the lane's text is what is in the game.

## Changed

| Slot | Why |
|---|---|
| S07 | The reply had a stray CJK character ("where 鑄ed wolves"). Now "where cast wolves pursue a stag through iron trees". Played as `open:court_way_bronze_doors`, since a door is opened, not examined |
| S11b | "The fire remains quite comfortable" contradicts the study fire, which gives no warmth. Now "The fire burns on, unbothered." |
| S12d | "cold rain" is a weather the roof does not always have. Now "back out into the open air" |
| S13 | "a thirty-foot square tower" read as 30 ft on a side. Now "a square tower of dark adamantine, thirty feet high" (it is 20 ft square). Played as `enter:court_vault_dome`, on its own area over the whole vault, once |
| H10 | "feather mattresses" and "tucked you in" do not fit a guest room with one bed. Now "on the carpet of the castle's guest room ... Whoever carried you up the stairs did not stay to be thanked." |
| G04 | An option that needs a spell has to name it (docs/contracts/dialogue.md, `[knows:...]`). Now "Cast Create or Destroy Water on the fire." |

## Not used

- T01, T02 and T04 (a conversation at the tower's door). The tower is clickable through its exit instead, whose menu line
  is generated, so only T03 is used, as the door's `locked_text`.

## Second request: five more labels

The first conversation menus left every way out but one to a plain "Leave it." and had no sure way to find the passage
if every look at the hearth failed (the plan's rule 8). A second, short brief (brief2.md, reply in gemini_reply2.json)
asked Gemini for five option labels: L01 (spend an hour taking the hearth apart: finds the passage with no roll, costs
`time +60`, and plays S09a's line as it is), L02 and L03 (leave the sconce and the rope alone), L04 and L05 (climb down
the smokestack, leave it). All five are used as drafted. The only text in the conversations that Gemini did not draft is
the two syntax-only words in the unused slots' place: nothing.

## Not voiced

None of these lines is voiced. For the voice thread, the Narrator lines (everything in narrative/narrator that this lane
added, and every `Narrator:` line in narrative/castle_ravenloft/court_way.dialogue) are listed in the hand-off. Option
labels (G03 to G06, G08, H02 to H05, K02, R02, L01 to L05) are never voiced.
