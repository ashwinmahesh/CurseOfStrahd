# F2 (lost companions and Liriel's dark gift): Gemini brief and raw reply

Rule (Ashwin, 2026-10-18): every new or rewritten spoken or Narrator line is drafted by Gemini through his ai-bridge on his
subscription, then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target
`gemini`, plain text, no routing; the bridge was already running and was not touched. No model id was reported (`model`,
`configured_model` and `reported_model` are null in the bridge's record). One conversation, one message (33296cca). The
reply is kept exactly as Gemini wrote it (`f2.reply.txt`); `f2.messages.json` is the bridge's record.

| File | What it is |
|---|---|
| `f2.brief.txt` | Ten `lost` journal entries (one per companion quest), Liriel's warning at the first amber voice, the `dawn_lost` journal entry and the journal's warning line |
| `f2.reply.txt` | Gemini's reply, untouched |
| `f2.messages.json` | The bridge's record of the conversation |

New text in the game: one spoken line (Liriel, unvoiced), eleven journal entries and one journal warning:

| Where | What |
|---|---|
| `narrative/amber_temple/vestiges.dialogue` (each of the sixteen `*_call` nodes) and `vosk.dialogue:offer` | Liriel's line, once (`liriel_amber_warned`) |
| `data/quests/<the ten companion quests>.json` | the `lost` journal entries |
| `data/quests/carry_the_dawn.json` | `dawn_lost`'s journal entry, and the rule's `warn` |

## What was edited after the draft

- **Facts a lost hero can't have.** The hero can be lost at any stage, so "before we ever found the Wizard of Wines"
  (Ratatouille) went; so did invented things the party may not hold: Ratatouille's cast-iron pot, Ilse's folded list,
  the contract "in his coat" (Kip) and Wren's unbroken wax seal. Hedda's "on the road" went (the altar is not a road).
- **Fit.** Tamsin "find the woman painted inside" became "learned who the woman in the silver locket is" (his quest asks
  who she is); Kip's ends "wherever he is", which reads right for the altar and the Deck alike.
- **Length.** Liriel's `dawn_lost` entry lost "laid her hand on the amber" (the gift is taken through a picker, not a touch)
  and "right"; the rest were trimmed by a few words each.
- **Kept as drafted:** Liriel's warning line (B1), the journal warning (B3), Godrick's and Wren's sense, and the voice.
