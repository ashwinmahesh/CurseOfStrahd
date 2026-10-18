# Gemini drafts for packages A1 and A2 (Argynvostholt's west wing, the dragon statue, the front steps, the chapel's revenants)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`,
plain text, no routing, no model or effort override. Brief 1 and its reply: 21 lines (20 numbered items; item 2 has two
variants, items 16 to 19 are one short conversation). Brief 2 (same conversation): five more pieces of text the first
brief left out (the guest book's page, the pot's two check outcomes, the trap's description and the map's summary and
text).

| File | What it is |
|---|---|
| `brief_1.txt` | The brief as sent: the place and its history, the Narrator's rules, five existing lines and the dead knights' voice to match, then the 20 items with the facts each line may use |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `messages_1.json` | The bridge's record of the exchange (ids, states; no model id was reported) |
| `brief_2.txt` | The second brief: the five pieces of text with the facts each may use |
| `raw_reply_2.txt` | Gemini's reply, untouched |
| `messages_2.json` | The bridge's record of the whole conversation, both exchanges |

The lines live in `narrative/narrator/argynvostholt.dialogue` (the new "west wing" and "dragon statue and front steps"
sections, plus one new variant inside `enter:holt_chapel`) and `narrative/argynvostholt/knights.dialogue` (`kneeling`).
The two encounter texts are in `data/locations/argynvostholt_west_wing.json` (`ballroom_colony`) and
`data/locations/argynvostholt_hall.json` (`chapel_revenants`). They are unvoiced; the hand-off lists every one.

Contents of the rooms beyond their names are ours (the references give only the names Q4, Q6, Q7, Q10, Q11, Q12), and
the brief said so to Gemini; the region doc (§15) marks them the same way.

## What was edited after the draft

- Item 5 (`enter:holt_wine_store`): "fill the cellar" became "fill the room" (the store is a ground-floor room).
- Item 8 (`examine:holt_dragon_statue`): Gemini's "stands taller than the house" is gone. The statue is a stand-in
  figure drawn about 20 ft tall (a rearing silver dragon's height, scale-ups' `scale` 4), not taller than a house. The
  frost sentence is kept.
- Item 14 (the revenants rise): Gemini's second sentence ("Steel clears the scabbard with the dry scrape of an old lock
  turning") became "Plate scrapes plate with the dry sound of an old lock turning": revenants fight bare-handed in
  their stat block, and nothing here says they draw swords.
- Items 14 and 15: "Colored" and "armored" are "Coloured" and "armoured", the house's spelling. Both lines also lost
  their counts: "The three figures rise together" is "The kneeling figures rise together", and "across three armoured
  figures kneeling in a row" is "across armoured figures kneeling", because the fight has four knights in every level
  variant (the sharp party does not lose to the book's three at any hit points a fight can finish at; see
  docs/story/fight_tuning_holt_west.md).
- Item 15 is a new night variant inside `enter:holt_chapel`, conditioned `night and not flag.order_fate and not
  flag.chapel_revenants_cleared` (the knights are only there then).
- Items 16 to 19 (the kneeling knights): "Thecommander permits you" was a typo, and it also made the commander the
  authority; it is now "Go in peace." The three spoken lines are a short menu: after "You know the words. Keep them."
  the party may ask what they pray for ("We pray for the lamp. Pray, or pass.") or leave; both end on "Go in peace."
  (every conversation has a way out; no roll is involved).
- Items 1 to 4, 6, 7, 9 to 13 and 20 are Gemini's words unchanged (item 2's second variant plays once the colony is
  cleared; items 12 and 13 are the front steps' trap `found` and `triggered` lines).

## The second brief

Gemini's five pieces went in with one edit: the guest book's "A heavy ledger rests on a brass stand" is "A guest book rests
on a brass stand" (the prop is the guest book; the Narrator calls it that elsewhere). The pot's two outcomes (`holt_pot_lid`
success and failure in `argynvostholt_west_wing.json`, the success also gives 25 gp), the trap's `text` and the map's
`summary` and `text` are Gemini's words as sent; the guest book's page is the prop's `text` (a codex page, never voiced).
None of these five is spoken: the check texts show in the game's notice, and books and descriptions are never voiced.

## Facts and guesses

- Book facts used: the room names and numbers Q4, Q6, Q7, Q10, Q11, Q12 and Q13 (Strahd Reloaded's citations), "a colony
  of giant spiders in Q4" and the three revenants of Q13 who attack anyone who enters (Elven Tower, chapter 7). The
  dragon statue (Q1) and the trapped front steps (Q2) are named by Reloaded's notes and have no contents in any of the
  references, so the statue's look and the steps' ward (frost, the Order's) are ours.
- Ours, not the book's: everything in the rooms (the pot's rattle, the guest book, the steward's strongbox, the dragon's
  hollow, the cocooned satchel), the spiders' count, the knights' prayer and the rule that they rise only after dark
  against a party without the oath or Godfrey's word (the plan's default, `Dungeon Expansion Plan`, Decisions).
