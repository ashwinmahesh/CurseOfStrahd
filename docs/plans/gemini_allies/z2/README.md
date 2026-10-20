# Gemini drafts for package Z2 (Izek, her brother)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`,
project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id
is reported in the bridge's records.

| File | What it is |
|---|---|
| `common.txt` | The shared context appended to each brief: the format, Izek, Ireena, the Narrator, the canon limits |
| `brief_1.txt` / `reply_1.reply.txt` | Part A: the woods, the rider, the grave, his post, joining, his talk, Ireena's hint |
| `brief_2.txt` / `reply_2.reply.txt` | Part B: the three scenes between Izek and Ireena |
| `brief_3.txt` / `reply_3.reply.txt` | Part C: Strahd at the window, Izek's road lines, eight epilogue slides |
| `brief_4.txt` / `reply_4.reply.txt` | The first doll given away, and four epilogue corrections |
| `brief_5.txt` / `reply_5.reply.txt` | Two epilogue slides for the guard who also knows the other name |
| `*.messages.json` | The bridge's record of each message |

## What was edited after the drafts

Canon (checked against our data):

- **The scenes' places.** Gemini wrote the guard's four Narrator lines as one node, one with the church "porch" and one with the
  mansion's "porch": the church's is now inside, against the nave wall, and the mansion's inside against the barred shutters
  (Ireena stands in both interiors). `window_izek_krezk` lost the shutters clause (the existing `krezk` node already says it).
- **Invented details.** "A boy bleed in the snow" lost the snow. "While I was rotting in Vallaki" became "breaking heads in
  Vallaki". "Large hands mended the nets" lost the nets (Kasimir's craft): "a man's big hands". "Dry pine" became "dry sticks" (his
  story is gathering sticks).
- **Ismark.** "I cannot even claim to be the bigger brother" confused Ismark with Izek: "They call me Ismark the Lesser at the tavern.
  Looking at you, I believe it."
- **Who the doll is for.** "Every one in that chest was carved for her" (to Ireena, in front of her) became "for you". "When we are
  alone by the fire" became "when it is only us" (the scene also plays at her door).
- **Ireena cannot be hurt in a fight now** (E3): the road line "Is she hurt?" became "Is she all right? Look at her first".
- **The first doll is hers after the first scene**: `idle_doll` waits for `not izek_sister_1` and `talk_dolls` has a second version
  (`talk_dolls_given`, brief 4).
- **The spurned Izek stays the Baron's man.** Gemini's first epilogue had him walking out of the town gates, which only the truth
  does: brief 4 rewrote `izek_c`/`izek_g`. The dead-but-told versions (`izek_d2`/`izek_h2`) lost "his name given back to the sister
  he lost", which read oddly.
- **Epilogues.** "A quiet dog with a warm right hand" became "a quiet guard".

Register and length (cut about 15%): trimmed lines in `grave`, `guard_set`, `talk_castle` and the window scene; the Ireena hint lost
a clause; the road line for the lake lost "no use for that water" nothing (kept).

Structure (mine, nothing to draft): every router (`back`, `sister_next`, `guard`, the placements), the conditions of every option,
the flags each node sets, `with_her` as the line shared by every rejoin, the opening conditions and the order of the camp talks,
the epilogues' conditions, and the option texts' pairing with the replies.
