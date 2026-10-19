# Eggs plan, package R4: Old Bonegrinder, the winery and Krezk

Built from Part C ("R4") and Part D of the 2026-10-18 easter eggs plan (kept in the owner's vault). Four winks and one
good dog, all hidden where the player has to look, none in a serious scene, none moving a main flag. Every new line
below was drafted by Gemini through the ai-bridge (`brief_*.txt`, the raw replies `raw_*.reply.txt`, the bridge's full
message records `raw_*.messages.json`), then edited by hand for length, canon and the Narrator's rules. All of them are
unvoiced.

## What is where

| Nod | Where | What the player does | Reward |
|---|---|---|---|
| 13 The aunt by the river | `data/locations/old_bonegrinder.json`, check `receipt_back_pages` on `bonegrinder_receipt_book` (Investigation DC 12, offered once the front of the book has been read) | Read the back pages | Codex: A letter from the river |
| 14 Spectacles in the sails | `data/locations/old_bonegrinder_hill.json`, hidden find `sail_lashings` at (13, 5) beside the sails (Perception DC 14); item `tiny_brass_spectacles` (gear, 15 gp) | Search near the sails | A trinket; the Narrator's line has a gnome and a halfling variant |
| 15 Davian's notice | `data/locations/wizard_of_wines_press_house.json`, book prop `press_notice` at (22, 7), against the east wall, on the `sign` model | Read it | A laugh |
| 16 The cheese stair | `data/locations/krezk.json`, check `lift_a_cheese` on `goat_cheeses` (Athletics DC 8) reveals the hidden find `cheese_stair_glove` at (14, 23); `wall_watch` in `narrative/krezk/townsfolk.dialogue` gains a line once `eggs_cheese_stair_found` is set | Lift a cheese, then use the glove | 30 gp; a Potion of Climbing; Lazar's line |
| 2 Sprig | `narrative/wizard_of_wines/sprig.dialogue`, `pat` | Pat it (first time) | A laugh; sets `eggs_dog_sprig` for the later Good Dogs, All achievement |

## Where the plan and the game differ

- The plan puts Davian's sign "by the lamp oil" in the Press House. No lamp-oil barrel stands in any Wizard of Wines
  location (the Narrator's line for the cleared press house does mention lamp oil). The notice is hung on the east wall of the press floor
  (a sign is a wall piece and must stand beside a wall), 4 or more squares from every fight start, and says what the plan wants it to
  say; no barrel was added, so no fight changed.
- The gnome or halfling "interject" for the spectacles is a pair of Narrator variants (`[species:gnome]`,
  `[species:halfling]`) on `search:sail_lashings`: a hidden find runs no conversation, so an interject has nowhere to
  play, and the Narrator already reacts to who is acting.
- The glove holds the Potion of Climbing as a hidden find (a check's own items may not be common magic, test
  `test_placed_checks_give_playable_things_that_fit_their_region`); the 30 gp are the lift's own reward, from under the
  lowest step.

## Gemini record

Three briefs, one reply each, sent to the `ai-bridge` project's Gemini target on 2026-10-18 with no model or effort
override (so the bridge's default; the message records show no model reported):

- `brief_a_krezk.txt` / `raw_a_krezk.reply.txt`: the cheese stair lines and Lazar's line.
- `brief_b_bonegrinder.txt` / `raw_b_bonegrinder.reply.txt`: the aunt's letter, the back-pages lines, the sail-lashings lines.
  (The brief names one word from the plan's deny list, in an instruction not to use it; the reply does not use it.)
- `brief_c_winery.txt` / `raw_c_winery.reply.txt`: Davian's notice and Sprig's first pat.

Edits made to the drafts (all of them shortened, none used verbatim except where noted):

- Lazar: took option B's idea (the wall keeps the road out, the cheese keeps the winter out) and opened with "before you
  ask, no", the watchman's habit; dropped A's "Come down from the dairy" (nobody has climbed yet).
- The cheese lines: B's wording of the stair, trimmed; the failure is A's millstone; the glove line gains the last
  sentence (the cheese holds), mine.
- The letter: A's, with "marrow-salt" and "petal" kept, B's "stayed for good", trimmed to 80 words.
- Back-pages lines: A's success, trimmed; the failure rewritten so that the pages are not destroyed (another hand may
  still try).
- Sail lashings: A's plain line with B's "brambles broken in a line"; the gnome and halfling variants rewritten to
  keep the Narrator to what can be seen.
- Notice: A and B merged, the plan's beat ("the blights are not that stupid, and neither am I") restored.
- Sprig: A's two lines, trimmed.
