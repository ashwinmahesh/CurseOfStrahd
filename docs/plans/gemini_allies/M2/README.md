# Gemini drafts for package M2 (Ezmerelda's Hunter's Ledger and her hub)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`, plain
text, no routing; the bridge was already running and was not touched. No model id was reported (`configured_model` and
`reported_model` are null in the bridge's log). One conversation, three messages.

| File | What it is |
|---|---|
| `brief_1.txt` | The hub: the ledger's first showing, her greetings, the three ledger frames, goodbye, the Rudolph, leg, Vistani and "where we are heading" topics (3 + 2 + 3 variants) and six option texts: 29 lines. Both voice bibles' samples, the Narrator's rules, the canon limits and the format. |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `brief_2.txt` | Ledger names 1 to 7 (Dragan at Tser Falls, the Tinker's Wagon, the count's fowlers, the Vine Mother, Morgantha, Wintersplinter, the Count's Huntsman): a briefing and a payment for each, from a fact sheet drawn only from our data, with the items each payment may name: 28 lines and 14 option texts |
| `raw_reply_2.txt` | Gemini's reply, untouched |
| `brief_3.txt` | Names 8 to 13 (the Grandsire, Kiril, Khazan, Baba Lysaga, Sarkhaza, the Eye Below), the two gifts from her wagon and the closing: 30 lines and 12 option texts |
| `raw_reply_3.txt` | Gemini's reply, untouched |
| `messages_1.json` .. `messages_3.json` | The bridge's record of the conversation (ids, states) after each message |

The lines live in `narrative/allies/ezmerelda.dialogue`: 87 spoken lines (86 Ezmerelda, 1 Narrator), all new and unvoiced,
and the party's option texts (the game does not voice those).

## What was edited after the drafts

Gemini's lines came back in the right shape and register (it used only moods the game has: sly, weary, sad, smile, angry),
so the edits are canon and fit, not new ideas. Most lines were trimmed a little; the longest (up to 30 words) were cut to
about 24, and the average is 20 words.

- **Canon.** The first draft of the ledger's opening said she writes only killers "I've tracked myself"; Khazan, who sat
  under her camp for months unknown to her, is in the book, so it is "killers I trust enough to ink". "I left my teacher
  to escape those [chore lists]" had her leave Rudolph; it is he who left, so "I've had a lifetime of Rudolph's". Her brace
  "kicks twice as hard"; the data says it kicks harder than the old one. The ward is keyed to her name, not "warded for my
  hands alone"; "the old fox still isn't home" became "still no Rudolph" (she may have no idea where he is). Morgantha's
  daughters are not "sisters" (all three hags). The Vine Mother, the Huntsman and the fowlers had details the facts do not
  hold, cut: "for years" scratching names on cairns (the data does not say how long), the raven in the fowlers' cage (she
  does not know whose cage it is), "biting flies" for Lysaga (swarms in jars), "bring me her wordless silence" (it is "tell
  me when she's quiet"), "under the lake" for Khazan (under the tower: the island, the flooded crypt). Sarkhaza "eating from
  a cage" is "eating what came in cages".
- **Fit.** "Madam Eva dealing me into other people's card games" is the line she already has ("other people's games"); the
  Vistani tightrope sentence was clumsy and was rewritten; the Amber Temple warning ("if you take free gifts here, I'm
  keeping my silver") now says what she means; "three hunts" in the hunt frame became "the hunts" because she may have
  fewer; "Give the valley a day to move" became "Come back once the valley's moved". "Don't give him your name" (Khazan)
  became "don't offer".
- **Items.** A payment line names only what that name pays (the fixed items in the table in docs/story/side_quests.md),
  never a number; the healing draught she adds scales by level, so the lines say "a healing draught".
- **Structure (mine, nothing to draft).** Which three names she offers, the "at most three newest topics" rule, the payment
  by level, the fourth and eighth names' gifts, the closed names, and the option texts of the doors in her tower, abbey and
  yard conversations (`Have you any paying work?`), "That's enough names for now.", and "Hunt with us." (the existing
  wording). The hunt frames and payments are different nodes (`brief_*`, `claim_*`); a briefing never starts a fight.
