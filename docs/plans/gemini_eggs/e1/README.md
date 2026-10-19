# E1: hidden achievements and fight counts (no lines drafted)

The easter-egg plan gives package E1 no dialogue: its table counts 0 new spoken or narrated lines, and the briefs table
has no E1 row. So there is no brief or raw Gemini reply here, and the ai-bridge was not used.

The only new player-facing text in E1 is mechanical, not voiced:

- Three hidden achievements in `data/achievements/e1.json`. The names (A Little Push, Spark and Barrel, Knocked, Not
  Killed) are the plan's own. Each "how it is earned" line is one plain sentence in the style of the sixteen already in
  `Achievements.LIST` ("Defeat 100 foes in one playthrough."), shown only once the achievement is earned.
- The two strings every unearned hidden achievement reads as in the panel: "A secret" (the plan's wording) and "Hidden
  until it is earned."

Nothing here is spoken, so `make voice` has nothing to do for E1. Later packages (R5, R6a, R7) add their hidden
achievements as `data/achievements/<package>.json` and draft any voiced lines in their own `gemini_eggs/<package>/`.
