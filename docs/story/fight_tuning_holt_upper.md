# The trapped hallway on Argynvostholt's third floor (dungeon expansion package A3)

(2026-10-20, owner's rule: the sharp test party wins 5 in 8 on Balanced, give or take one; the plan holds the fight to it, and
the hallway guards the only way up to everything on the floor. Held by `tests/integration/test_scaled_fights_a3.gd`, three level
variants, 4 to 6 wins in 8 and every seed finishing. Measured with the four pregens on the sharp autopilot, seeds 1 to 8.)

| Fight | Where | Level | Foes | Wins | Rounds | Party members down |
|---|---|---|---|---|---|---|
| `trapped_hall` | argynvostholt_third, from the stair head into the hallway | 8 | 16 phantom warriors at 55 HP (7 in each quarters, 2 behind) | 5 | 8.5 | 1.8 |
| `trapped_hall` | the same | 7 | 14 phantom warriors at 45 HP (6 and 6, 2 behind) | 5 | 8.4 | 1.9 |
| `trapped_hall` | the same | 6 | 12 phantom warriors at 45 HP (5 and 5, 2 behind) | 5 | 9.4 | 2.1 |

The other phantom fights in the house use 11 to 15 phantoms at the stat block's 45 HP (the courtyard's twelve to fourteen,
the mausoleum's eleven to fifteen), so the hallway's counts sit with them; level 8 needed 10 Hit Points more on each as well,
since 7 and 7 at 45 HP won 6 in 8.

## How it was tuned

The four stand just inside the hallway, at (18, 20) to (21, 20), as they step up from the stair head (the fight's area is
rows 16 to 20; the stair head below it is its own area and starts nothing). The phantoms start in the two knights' quarters
(spread along their lengths, none within reach of the hallway's doors) and behind the party at the stair head's two corners, so no
Fireball takes more than three quarters of them (tests/unit/test_fight_spread.gd). Wins over seeds 1-8 (phantoms as west + east + behind, at the stat block's 45 HP unless it says):

- **Level 8:** 5 + 5 + 2 won 8 (at 60 HP 4, at 75 HP 5, at 100 HP 1); 6 + 6 + 2 won 7 (at 55 HP 7); 7 + 7 + 2 won 6, **at 55 HP 5**.
- **Level 7:** 4 + 4 + 2 won 8; 5 + 5 + 2 at 75 HP won 2; **6 + 6 + 2 won 5**.
- **Level 6:** 4 + 3 + 1 won 8; 4 + 4 + 1 at 75 HP won 3; **5 + 5 + 2 won 5**.

(The first build had 12, 10 and 8 phantoms for levels 8, 7 and 6: all three won 8 in 8 in 8 to 10 rounds with a hero down about
once a fight. Level 8 could also have been 5 + 5 + 2 at 75 HP, which won 5; sixteen at 55 HP was picked to keep the hallway full
of knights rather than a few tough ones.)
