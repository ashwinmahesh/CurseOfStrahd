# sq-stuck-2: Gemini briefs and raw replies

Rule (Ashwin, 2026-10-18): every new or rewritten dialogue line is drafted by Gemini through his ai-bridge, on his
subscription, then reviewed and edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project
`ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id was
reported by the bridge (`model` is null in its record). One conversation per brief. Each reply is kept exactly as Gemini
wrote it (`*.reply.txt`); `*.messages.json` is the bridge's record of the conversation.

These lines go with package S2 of the side quest failure plan (`Side Quest Failure Plan - 2026-10-18`, Part A): quests that
could be left stuck for good now stay finishable or close. Every line below is unvoiced.

| File | What it asked for | Where the lines went |
|---|---|---|
| `ravens.*` | Danika paying under Lady Wachter's rule (3), Danika paying during the festival (3), Bray running for his mother (1), the rewritten journal entry | `narrative/vallaki/the_ravens_ransom.dialogue`: `paid_danika_wachter`, `paid_danika_festival`, `bray`; `data/quests/the_ravens_ransom.json` (`done`) |
| `island.*` | Old Nistor's greeting when both the bell and the island are open (2), and the two options | `narrative/lake_zarovich/old_fisher.dialogue`: `bell_or_island` |
| `island2.*` | the same greeting for a bell that is already silenced (2) | `old_fisher.dialogue`: `bell_or_island` (the `bell_silenced` branch) |
| `ilya.*` | Anna's opening for an Abbot who is slain or fled (1 each), the mending scene (4), the journal entry | `narrative/krezk/anna.dialogue`: `recovering`; `data/quests/the_burgomasters_son.json` (`recovering`) |
| `beacon.*` | Argynvost's warning (3), the two options, the flame going out (3), the cradle, the echo and the bones afterwards (1 each), the journal entry | `narrative/argynvostholt/beacon.dialogue`: `oath_ask`, `oath_kept`, `cradle`; `argynvost.dialogue`: `start`; `mausoleum.dialogue`: `bones`; `data/quests/the_dark_beacon.json` (`kept_dark`) |

Lines in the game: 26 new spoken or Narrator lines and 3 new party options, all unvoiced: Danika 6 and Bray 1; Old
Nistor 4 and 1 option; Anna 6; the beacon 9 (Argynvost 4, Narrator 5) and 2 options. Three journal entries (one rewritten:
The Ravens' Ransom's `done`, two new: `recovering`, `kept_dark`). The Hunter's Tower needed no new line (a one-line
`quest` statement in the abbey's join), and The Baron's Island's fix is the Nistor menu above. The Hunter's Ledger was
already fixed by the branch `sq-stuck` (commit 4cfa3aeed) and is not in this package.

## What was edited after the drafts

- **Canon.** Gemini had the mail "his grandfather's" with "a Martikov doesn't keep a debt" (it means the opposite: a
  Martikov pays what is owed); Bray "upstairs with stew" (he is in the taproom, so it is "stew in him instead of a cage
  round him"); "silver" for the coin (it is gold: "counted to the copper"); "Mum, Dad" for Bray (the inn's Bray says "Mama,
  Papa"; one parent, "Mama", works whoever is there); "wet torches" at the festival (cut); "bells at St Markovia" for
  Anna's news of the dead Abbot (nobody has said the abbey has bells: "the thing on the mountain is dead", Dmitri's own
  words); "Dmitri set it aside for the mason" (Anna and Dmitri both kept the money for the stone: "we set it aside");
  "cupped hands" for the flame (the party carries a lit light, so "lower the silver flame toward the stone"); "rusted
  gauntlet" for the knights (cut); "a pinch of grey ash" in the cradle (the cradle already holds ash set like mortar: "cold
  ash and old soot"); "the revenants of the Order" in the journal (the game says the dead knights).
- **Fit.** Trimmed about 15% (Gemini runs long). Mood tags `[neutral]` dropped. Danika's first line under Lady Wachter's
  rule was over the 60-word line limit and was shortened. Nobody dies in Ilya's scene: the draft's last sentence about the
  boy climbing the wall was cut from the journal as a promise.
- **Not drafted by Gemini (data, not spoken):** every flag, condition and node id; the quest hints; the mechanical
  journal change "Urwin gave us" to "We were given" in The Ravens' Ransom (the draft's own sentence is used).
