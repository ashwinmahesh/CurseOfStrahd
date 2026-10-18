# Gemini drafts for package I5 (Ireena in the chapel)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`,
plain text, no routing. Brief 1 and its reply: 31 lines. Brief 2 (same conversation): a four-line redraft, see below.

| File | What it is |
|---|---|
| `brief_1.txt` | The brief as sent: the scene's logic (how she is found, the five ways to wake her, the two-miss rule and its cost), her voice bible and existing lines, the Narrator's rules, the format |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `messages_1.json` | The bridge's record of the exchange (ids, states; no model id was reported) |
| `brief_2.txt` | The redraft brief: Ireena is shown by her usual sprite (a dark blue coat, white scarf, boots), so no line may put her in a white dress; four lines to replace |
| `raw_reply_2.txt` | Gemini's four lines, untouched |
| `messages_2.json` | The bridge's record of the whole conversation, both exchanges |

The lines live in `narrative/castle_ravenloft/chapel_ireena.dialogue`. They are unvoiced; the hand-off lists every one.

## What was edited after the draft

- `first_sight`: the saint is in the corner (the prop is at the east wall), not "above the altar"; the Narrator says
  "a white dress" and leaves "from her dreams" to Ireena, who has told the party about the dream (the Narrator only
  states what the party can see). The chapel is not "empty" (she is in it).
- `return_sight`: "since you were last here" instead of "guttered lower on the stones".
- `symbol`: names the Holy Symbol of Ravenkind as the game does; "the black window" (the window is black, not broken).
- `faith`: "your faith" instead of "your sworn word" (a cleric's god and a paladin's oath share the option).
- `sunlight`: "The Sunsword blazes in your hand" for Gemini's "comes clear with the sound of a winter morning"; the
  newly lit candles line is kept.
- `ward`: "The damp" for "The cellar damp" (a chapel, not a cellar).
- `ward_failed`: reworded; Gemini's line was almost word for word the window's "The words tangle and the prayer comes
  apart in your mouth".
- `trance_holds`: the first line also says the candles burned down a hand (the 30 minutes the scene takes).
- `woken`: "I let it be put on me" for "I let him put me in it" (nobody saw who dressed her); the sword line says she wants
  it on the record that she noticed, instead of asking for steel (she is kept out of fights by package E3); contractions
  once she is herself again.
- `ismark_woken` (inside `woken`): no "lace" (new detail); the dress is "that".
- Failure now costs: 10 minutes a miss, 30 when the trance holds, a failed Persuasion stays spent (engine rule), and the
  visit ends. Gemini's draft had none of that.

## The second pass (the dress)

The coordinator's call (2026-10-18): her figure is her usual sprite, so the Narrator's "white dress" and her "this rag"
lines went. The four lines that changed, from Gemini's second reply (`raw_reply_2.txt`), trimmed a little:

- `first_sight`, Narrator: "Ireena stands before the stone in her dark coat, hands folded at her waist, still as wax."
  (Gemini added "and boots"; cut.)
- `woken`, Ireena: "It was the lake from my dream, cold water up to my chin, and I stood here and let it." The dream's
  lake stays, the dress is no longer tied to what she wears.
- `woken`, Ismark: "Look at you, standing in the candles like a saint in a window. You took ten years off me."
- `woken`, Ireena: "Say one more word about it, brother, and I'll go down the mountain on my own." (contraction.)

The edit notes above for `woken` ("I let it be put on me", "that") describe the first pass; the lines are now these.
