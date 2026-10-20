# Gemini drafts for package I3 (Ireena's letters)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`
(version 2, multi-project), project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and
was not touched. No model id is reported in the bridge's records (a reported or configured model is null).

| File | What it is |
|---|---|
| `brief_1.txt` | The three couriers, the six letters (with the festival's and the den's variants), the two exits and the two cold greetings |
| `reply_1.reply.txt`, `reply_1.messages.json` | Gemini's reply, untouched, and the bridge's record of it |
| `brief_2.txt` | Strahd's note about three unanswered letters, its four place lines and the burn / keep lines |
| `reply_2.reply.txt`, `reply_2.messages.json` | Gemini's reply, untouched, and the bridge's record |

The lines live in `narrative/allies/ireena_letters.dialogue` (40 new lines: Ireena 26, Narrator 8, Strahd 6, plus the party's
option texts, all unvoiced).

## What was edited after the drafts

Canon and repetition:

- **The spoon joke.** The dinner letter asked whether anyone "counted the spoons", which is the hub's own news line
  (`allies/ireena:n_dinner`). It became whether anyone "had the sense to eat nothing and keep one hand free".
- **The innkeeper's birds.** Strahd's inn line had the innkeeper "forever watching the sky for birds", a hint at the
  Keepers that the brief forbade: it became the inn's windows, which she keeps shut.
- **Weather and roads.** The couriers had rain and "muddy ruts" (the weather is the game's, not a line's): "wiping rain from
  his chin" became "wiping his nose on his sleeve"; the ruts went. The Krezk courier is a pilgrim, not "his" sleeve only.
- **Strahd cannot be warm.** His kept letter held "the faint, lingering heat of a living hand"; it holds a cold that does
  not leave the skin. His burnt letter's wax stays a slow vein, with the first letter's image not repeated.
- **The church.** "the threshold where the old bell hangs" lost the bell (it is St. Andral's visit's).
- **The abbot letter** said "the shutters here" (she is not always behind shutters): "My latches are all well kept".

Register and length (cut about 15%):

- Lost a "quite" in two lines, the second sentence of the beacon letter's first line, and "Come and tell me who lit it before
  the gossips ruin the story" became "Tell me who lit it before the gossips ruin the story" (an order, not an invitation).
- `cold_two`: "Two letters I sent down that road, and not so much as a scrap of charcoal by way of a reply. I was beginning to
  think you had forgotten how to read my hand." became one sentence, and "Sit down and take your cloaks off before you drip
  all over the floorboards" became "Sit down. You are dripping on everything I own." (it reads in a church as in a house).
- Strahd's first line lost "though I suppose the road leaves little time for those who wait", which pointed at the wrong
  person; his Krezk and mansion lines lost "quite" and "now".

Structure (mine, nothing to draft): the routers (`courier`, `pick`, `after`, `strahd_silence`'s place router, the flag reads),
the flags each node sets, the cold check-in hook in `narrative/allies/ireena.dialogue`, and the option texts.
