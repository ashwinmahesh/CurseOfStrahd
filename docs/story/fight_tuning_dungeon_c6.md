# The Dungeon Expansion's C6 fights: the guardians' passage and the parapets

(Owner, 2026-10-13: the book's fights were written for weaker characters. Over seeds 1-8 the four pregens on the sharp
autopilot win five in eight on Balanced, give or take one, each fight played from where the party stands when it starts, its
foes starting spread out. Owner, 2026-10-18: attrition fights may stay at 8 in 8, "unless theyre guarding something or its a
special encounter". Held by `tests/integration/test_scaled_fights_c6.gd`. The package: Dungeon Expansion Plan C6,
docs/regions/castle_ravenloft_court.md §16.)

| Fight | Where | Version | Level | Book | Now | Wins |
|---|---|---|---|---|---|---|
| `court_vermin` | west wing | L10v0 | 10 | rat swarms piled into the shapes of guards beside the steel door (K35) | 12 swarms of rats at 200 Hit Points each, in the `boiling_tide` state (+5 to their attack rolls), spread along the passage | 5 (13.1 rounds, 2.6 heroes dropped a fight) |
| `court_parapet_watch` | parapets | L10v0 | 10 | Strahd's animated armour patrols and attacks those who linger (K46) | 2 of Strahd's animated armour, standing in plain view facing west along the walk | 8 |

The rats guard the door to the count's dining hall, so they are held to 5 in 8 like any guard. The parapets' armour is attrition,
a patrol that is simply there: it stays at 8 in 8 (6.5 rounds, nobody dropped).

## How the rats were tuned

The party steps into the door's area from the east, (27, 11) to (30, 11), and the rats start spread along the whole passage
(tests/unit/test_fight_spread.gd: twelve foes, no Fireball catches more than three quarters of them). A swarm of rats is a
CR 1/4 stat block (24 Hit Points, +2 to hit, 5 damage a bite) that resists weapon damage, so against a level 10 party only its
Hit Points or its numbers can be raised, and a plain swarm hits too rarely to hurt: twelve at 200 Hit Points won 8 in 8 in
15 rounds and dropped one hero a fight. So the swarm gained a state, `boiling_tide` (data/monsters/swarm_of_rats.json, a trait
a fight turns on for its foes by `states`; the Death House's rats do not have it): +5 to attack rolls, as if a hundred rats
were biting at once. Wins over seeds 1-8, twelve swarms:

| Hit Points each | No state | `boiling_tide` |
|---|---|---|
| 100 | 8 (7 rounds) | 8 (7 rounds) |
| 150 | 8 (11 rounds) | 6 (11 rounds) |
| 200 | 8 (15 rounds) | 5 (13 rounds) |
| 260 | 5 (19 rounds, a timeout) | 0 |
| 320 | 2 | |

Sixteen swarms at 110 and twenty at 100 without the state won 8 in 8 in about 10 rounds with at most a hero down. Twelve at 200
Hit Points with the state is the 5 in 8 that does not drag (13 rounds).
