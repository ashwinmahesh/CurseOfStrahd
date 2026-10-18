# Gemini drafts for package M1 (Ezmerelda on the hunt)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`,
plain text, no routing; the bridge was already running and was not touched. No model id was reported (`configured_model`
and `reported_model` are null in the bridge's log). One conversation, two messages.

| File | What it is |
|---|---|
| `brief_1.txt` | The yard, the reunion (two openings and a shared exchange), the gift, the hub, the joining speech and her return to the shore: 41 lines and 3 option texts, with the logic of each node, both voice bibles and existing lines, the Narrator's rules, the canon limits and the format |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `brief_2.txt` | Two redrafts (the cat's moment in the reunion; her first line when Rudolph walks with the party) and the three road meetings: 3 + 15 lines, five short answers about Rudolph, 2 option texts |
| `raw_reply_2.txt` | Gemini's reply, untouched |
| `messages_1.json`, `messages_2.json` | The bridge's record of the conversation (ids, states) after each message |

The lines live in `narrative/allies/ezmerelda_hunt.dialogue`: 61 spoken lines (39 Ezmerelda, 13 Narrator, 9 Rictavio), all
new and unvoiced, and five option texts (what the party says; the game does not voice those).

## What was edited after the drafts

Format and canon (not new ideas):

- **Moods.** Gemini's second reply used `[dry]`, `[wary]`, `[quiet]`, `[fond]`, `[guarded]`, `[firm]`, none of which the game
  has (`tools/data/dialogue_lint.py` MOODS); dropped. One road line, "Try not to tread on him...", got `[smile]` so she is not
  flat in every scene.
- **Typo:** "moustachedrying" in `yard_rudolph`. **British spelling:** "rumors" to "rumours".
- **Stage directions inside speech:** `reunion_promise` had "Turning to you, he keeps his voice flat." in Rictavio's mouth;
  removed. `reunion_scene` had the cat's snarl as part of Ezmerelda's line; that was redrafted by Gemini (brief 2, `reunion_cat`).
- **Contractions.** Gemini wrote formally ("Do not mind me; I am only"); Ezmerelda is quick and colloquial, so "Don't mind
  me. I'm", "I've hunted alone for years... so I won't die stupidly", "you can't finish", "He's inside... and I'm out
  here... so I don't have to knock", "Not until I've looked Rudolph in the eye", "don't answer anything that calls".
- **"child"** in `reunion_costume` ("Put the bolt down, child"): she is not a child and hates being called "girl"; cut.
- **Canon.** "leave you at the river" has no river in our story; the tower is warded, not locked, so "wrong to leave without a
  word, and wrong to ward the tower against you". "A stray cat": the cat is caged, so the line now says only "Twelve years,
  and you hid behind a stage moustache." The coat "got me through three towns" was new history; cut.
  "as if I were twelve again" (road, reconciled) clashed with the twelve years; "as if I were still an apprentice".
  The promise scene: Gemini had her say she "had a crossbow on them at the lake"; at the tower she says she will claim she
  wrung it out of them, so "I wrung it out of them. You taught me how."
- **Who brought whom.** `reunion_end`: "You brought her to a quiet door" became "You brought me out the quiet way" (the party
  brought him out to her). `yard_leave`: "in the hall" to "in the taproom".
- **Length.** The gift lines lost a third ("I pack for bad weather" and "before you go back on the road" went, so they read
  right in the yard or on the road); `reunion_end` lost "Come back when I've finished lecturing him" (the gift follows).
- **`reunion_unmasked`.** "Close the door behind you. I told myself it would take you another week to read my tracks."
  mixed whom he is talking to; now "Shut the door behind me. I told myself it would take you another week to find me."
- **`reunion_costume`:** "not even for - " became "not even for..." (the showman cut off).
- **Shore.** "Go up those steps" to "Go in" (the tower has a causeway and a door, not steps); "the wagon ruts".

Structure (mine, nothing to draft): the options of `yard_first` moved into `yard_menu`, shared with `yard_again`; the gift
lines are one node (`gift`) every ending that can pay goes through, so a gift is never voiced twice; the `appear` statement
was not used (Rictavio already stands in the inn, and `stage_npc` does nothing for an NPC already on the map).
