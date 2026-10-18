# C4: what was edited in Gemini's drafts

Three requests went to `gemini` through the ai-bridge on 2026-10-18 (project `ai-bridge`; the model was not named in
any request, so it is whatever the bridge's default for Gemini was and is not reported here). The briefs are brief.md,
brief2.md and brief3.md; the raw replies are the bridge's message records, gemini_reply.json, gemini_reply2.json and
gemini_reply3.json (each has the full brief as `body` and the reply as `result`). Where the lane changed a line, the lane's
text is what is in the game.

## First request: 55 slots (brief.md, gemini_reply.json)

Answered every slot. Used as drafted: W01, W02, W03, W04, R01, R02, R03, R04a, R05, V01 to V04, V06, V07, T01 to T11, O01 to
O11, O13, O14, C01, F02, F06.

| Slot | Change and why |
|---|---|
| D01 | "kept off the household maps" is now "kept off the household's plans" (a stair is built, not mapped) |
| W05 | The second sentence ("Even his jokes have a way of lingering.") reads as a joke the count made. Now "As likenesses go, it was the better-tempered one." The line plays as a `combat:kill` variant that holds only in the brazier room, after the glyph, before the image has melted |
| V05 | "the lower beds" is wrong (the brides' rooms are above, on the Rooms of Weeping). Now "the sleeping rooms" |
| T12 | The trapdoor's drop happens on the next step (the slab's talk), so "and the floor is gone" is cut: "Then the polished stone tips." |
| O12 | "Smash the hanging hourglass." Now "Strike the hanging hourglass." The glass does not break (see X01 below) |
| F01 | 37 words; the limit is 35. "takes your feet out from under you ... with nothing to catch your hands" and "the cold stone floor" are now "whips your feet out from under you ... nothing to catch your hands" and "the cold floor" (34 words) |
| F03, F04, F05 | An option that needs a spell has to name it (docs/contracts/dialogue.md, `[knows:...]`). Now "Climb the slick chute with Spider Climb.", "Float up the dark chute with Levitate.", "Fly up the black marble chute with Fly." |
| F07 | "with its trapdoor still yawning open": the trap is spent once sprung, it doesn't gape. Now "its trapdoor spent and sagging" |
| R04b, G01 to G04 | Replaced by the third request: the book's two golems lose the party in about three rounds at any Hit Points, so one wakes (the west knight) and the other is armour |
| T08 | Used once for every stone's step into the fire, as a repeated line (it names no colour) |

## Second request: two lines (brief2.md, gemini_reply2.json)

- X01 (striking the hourglass), replaced by the third request's G02 for the one-golem fight. Its "Your blade rings" would also have
  assumed a sword.
- X02 (the puddle of wax, `examine:brazier_wax_puddle`): used as drafted.

## Third request: five lines for the one-golem fight (brief3.md, gemini_reply3.json)

G01, G02, G03, G04 and R04b, asked again with the fact that only the west knight is a golem. Edits:

| Slot | Change and why |
|---|---|
| G02 | "The hanging vessel" is now "The hanging glass" (the hourglass is the only thing it can be) |
| G03 | "after a very long rest" (a game term in this game) is now "after a very long sleep" |

G04 is the encounter's `text`; R04b plays as the room's `enter:brazier_room` line once the golem is beaten.

## Not voiced

None of these lines is voiced. For the voice thread: every `Narrator:` line in narrative/castle_ravenloft/larders_brazier.dialogue
and everything this lane added to narrative/narrator/castle_ravenloft_larders.dialogue (from the "Below the dungeon" heading to
the end of the file). Option labels are never voiced.
