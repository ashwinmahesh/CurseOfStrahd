# The west wing's spiders and the chapel's revenants (dungeon expansion packages A1 and A2)

(2026-10-18, owner's rule: the sharp test party wins 5 in 8 on Balanced, give or take one; the plan holds both fights to
it, and Ashwin's note of the same day keeps fights that guard something to their band. Held by
`tests/integration/test_scaled_fights_holt_ballroom.gd` and `test_scaled_fights_holt_chapel.gd`, three level variants
each, 4 to 6 wins in 8 and every seed finishing. Measured with the four pregens on the sharp autopilot, seeds 1 to 8.)

| Fight | Where | Level | Foes | Wins | Rounds | Party members down |
|---|---|---|---|---|---|---|
| `ballroom_colony` | argynvostholt_west_wing, from the ballroom doors onto the dance floor | 8 | 16 giant spiders at 95 HP, 3 swarms of spiderlings at 70 HP | 5 | 8.4 | 1.8 |
| `ballroom_colony` | the same | 7 | 12 giant spiders at 95 HP, 2 swarms at 60 HP | 5 | 10.1 | 2.6 |
| `ballroom_colony` | the same | 6 | 8 giant spiders at 100 HP, 1 swarm at 60 HP | 5 | 9.4 | 2.0 |
| `chapel_revenants` | argynvostholt_hall, from the west gallery's door into the nave | 8 | 4 revenants at 200 HP | 5 | 9.4 | 1.9 |
| `chapel_revenants` | the same | 7 | 4 revenants at 120 HP | 5 | 6.2 | 2.5 |
| `chapel_revenants` | the same | 6 | 4 revenants at 140 HP | 5 | 7.9 | 2.9 |

Both fights wait in plain view (`waiting`): the revenants kneel in the chapel with their backs to the door, and the first six
spiders hang in view in the ballroom's webs while the rest of the colony is `unseen` in the high webs, with the swarms in
view. The party can see them from the doors and walk away; stepping onto the dance floor, or into the nave, starts the fight.
The book's three revenants are four here (the sharp party does not lose to three at any hit points a fight can finish at:
3 at 150 HP won 8 in 8 at level 8; at 200 and at 260 HP they won 7 and the eighth seed timed out). The chapel's text and its
`enter:holt_chapel` night line therefore name no count.

## What was found on the way

- **A downed hero in a one-square doorway ends the fight in a stalemate, not a loss.** The first measurements (the party
  starting on the first square inside the door, as the trigger's area gave it, the rest still in the doorway and the passage
  behind) timed out in 1 to 5 seeds of 8 at every hit point count near the band. The cause, read off the end of a timed-out
  seed: the cleric and the paladin lay unconscious in the doorway, the hidden ranger stood behind them in the passage, and the
  foes (AiBrain skips downed heroes, and could not see the hider) idled for the last twenty rounds. Widening the ballroom's
  entrance to three door leaves did not cure it (one seed in four still timed out), so both fights now start deeper: the
  ballroom's own area is rows 1 to 7 (the two rows by the doors are a second area of the same name), and the chapel gets a
  nested area `holt_chapel_nave` (x 1 to 6, rows 1 to 8, the chapel's own name and light, so the room is furnished as it
  was) that its fight triggers on. With the whole party in the room every measurement finished, and the results move
  smoothly with the hit points.
- **A Large foe takes 2 x 2 squares.** The first spider squares were picked as single points and the game played the fight
  with spiders standing on each other and in the east wall (nothing stopped it); tests/unit/test_fight_spread.gd caught it
  (`on another foe`, `blocked`). The squares are now generated (a farthest-point order over the free floor, no footprint on
  another foe, the fallen chandelier, a prop or a square beside the party's start; the first six spiders in view, the rest
  `unseen`), and the three variants were measured again on them: the same counts and Hit Points land at 5 of 8 on the
  valid layout (16 at 85 HP gave 6, 105 HP 5; 12 at 85 HP 6, 105 HP 2; 8 at 90 HP 6, 110 HP 3), still with every seed finishing.
- **Lots of weak spiders lose to Fireball and Spirit Guardians.** 24 spiders at 70 HP and 34 at 60 won 8 of 8; 24 at 100 HP
  (door start) 5 of 8 but two seeds stalled. In the room: 16 spiders at 75 HP 7 of 8, at 85 HP 6, at 95 HP 5, at 110 HP 2,
  at 130 HP 0.
- **Chapel, level 8:** 4 revenants at 170 HP 6 of 8, 185 HP 4, 200 HP 5. **Level 7:** at 105 HP 7 of 8, 120 HP 5, 130 HP 4.
  **Level 6:** at 100 HP 7, 125 HP 6, 140 HP 5. The steps are 2 to 3 wins a time, so 5 was picked where it was found. (The
  level 6 row has more Hit Points than the level 7 one because the two runs landed where the dice did; both are in the band.)
- Revenants regenerate 10 a turn unless fire or radiant damage stops it, so a long fight stalls once the party's spells are
  spent: keep their Hit Points near these numbers.

## Starting squares

Ballroom: the leader at (8, 7), the rest at (8, 8), (8, 9) and (7, 9), the three door leaves open. Chapel: the leader at
(4, 8), the rest at (4, 9), (4, 10) and (3, 10). Both are the first squares of the trigger area reached from the door the
story's route would use (the chapel's other way in, the great hall's single door at (8, 6), puts the leader at (6, 6) and the
rest in that doorway; it was not measured).

## XP levelling

Both fights are on the xp sim's Argynvostholt stage (`ballroom_colony` as an optional fight, `chapel_revenants` a night one;
tools/balance/xp_sim.py). `make xp-sim` after: no gate moved by more than 0.03 of a level (route all at gate 10 -0.40 to -0.38, route alt
at gate 8 -0.31 to -0.28, plus the 11 and 9 gates by 0.01); the one-level ceiling holds on every route.
