# Gemini drafts for package K1 (Kasimir walks his road)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`,
plain text, no routing; the bridge was already running and was not touched. No model id was reported (`model`, `effort`
and the reported model are null in the bridge's record). One conversation, four messages.

| File | What it is |
|---|---|
| `brief_1.txt` | The camp greetings, "come with us to the temple", the closure when Patrina was laid to rest without him (four pieces she said, relayed one at a time), the closure when she was destroyed (was she afraid?), and going home or staying: 36 lines and 11 option texts, with his voice bible and twelve of his lines, the Narrator's rules, the canon limits (Patrina's fates exactly ours; no bargain offered; Strahd named once at most) and the format |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `brief_2.txt` | The hub: five openings, the Vallaki news (festival x3, Arabelle x2, Bluto x3), the Tome's dusk-elf page, what a dark gift costs, warnings about Tarakamedes and Vosk (before and after the party has met them), and the nine option texts of the hub menu; with the facts each topic may use and the ones it may not (Vosk's name and nature, any bargain) |
| `raw_reply_2.txt` | Gemini's reply, untouched |
| `brief_3.txt` | Two redrafts (the dragon topic had to read right whether or not he stood beside the party; a new variant for a bargain he was talked out of), two small missing nodes and the party's four options at the camp |
| `raw_reply_3.txt` | Gemini's reply, untouched |
| `brief_4.txt` | The two notices the Party screen shows when "Send home" is refused (on the mountain; after the bargain) |
| `raw_reply_4.txt` | Gemini's reply, untouched |
| `messages.json` | The bridge's record of the whole conversation (ids, states) |

The lines live in `narrative/allies/kasimir.dialogue` (84 spoken lines: 78 Kasimir, 6 Narrator; one of them,
"And you will want this. I was keeping it for whoever would take me into the mountains...", is his existing line from
`vallaki/kasimir:ally`, so it is already voiced; 83 are new) and 21 option texts there and 4 in
`narrative/vallaki/kasimir.dialogue`; the two notices are `guest_stays` in `data/npcs/kasimir_velikov.json`. All new
lines are unvoiced.

## What was edited after the drafts

Gemini ran long and a little formal, as the plan warned; nothing here is a new idea.

- **Canon.** `come`: "joints speak before he does" and "an old man's errand" cut (he is an elf, not an old man). `camp_cold`:
  "what you require from my chest" (no chest) became "what you require". `homeward`: Gemini had Patrina tell him to "stop making
  a spectacle of my grief"; she said "Go home... Be brave somewhere I can't see you", so he says "go home and be brave where she
  could not see me". `homeward_go`: "turns his back on the mountain ice / before the mist takes him" (the scene can be
  anywhere) became "turns toward the road home"; his wagon's shutters are not his to open, so he says he will be at the fire.
  `homeward_stay`: "A road will do." added so staying obeys her instead of defying her. `destroyed_yes`: "three centuries in the
  dark" (she sat in a reading hall) became "three centuries alone". `t_bluto_vistani`: "walked up the hill" (there is no hill)
  became "walked down to the water". `t_bluto_dead`: "one less fool on the shore" became "one fewer fisherman" (a kinder
  word for a man the camp pitied). `t_festival_baron`: Gemini's "Another soaked festival" was wrong (the festival can end dry);
  "Another festival, and nothing changed". `t_tome`: Tatyana "chose the stones below" became "chose the fall" (the codex says
  she fell from the walls). `t_arabelle_lost`: "It takes centuries to fade" became "a long time".
- **Format.** Nothing outside the game's moods ([sad], [smile], [weary] only). `rest_later` and the other jumps are mine
  (structure, nothing to draft).
- **Length.** Cut where a line only restated the one before: `destroyed_told` lost Gemini's middle line ("What remains in the
  amber is seldom gentle...": the dead are not in the amber), and `rest_close`'s Narrator line lost "onto the mud" for "to the
  ground". Every line is under 35 words.
- **The Narrator's net.** The plan says he puts the net down "for the first time in the game"; he already puts it down once in
  `vallaki/kasimir:trade`, so `rest_close` says his hands, for once, do not go after it.

Structure (mine, nothing to draft): the camp greetings jump to the menu; the three closures and the home-or-stay question
end the conversation on their last line; the hub's `kasimir_show_*` flags are menu scratch (it shows the three newest
unheard topics, recomputed every time it opens).
