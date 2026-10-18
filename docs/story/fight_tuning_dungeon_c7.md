# The Dungeon Expansion's C7 fights: the entry's stone dragons and the king's balcony

(Owner, 2026-10-13: the book's fights were written for weaker characters. Over seeds 1-8 the four pregens on the sharp
autopilot win five in eight on Balanced, give or take one, each fight played from where the party stands when it starts,
its foes starting spread out. Owner, 2026-10-18: "We can keep this at 8/8. Some combats are just meant to drain resources",
then "Unless theyre guarding something or its a special encounter." Held by `tests/integration/test_scaled_fights_c7.gd`.
The package: Dungeon Expansion Plan C7, docs/regions/castle_ravenloft_gates.md §14.)

| Fight | Where | Version | Level | Book | Now | Wins |
|---|---|---|---|---|---|---|
| `crg_entry_dragons` | main_floor | L11v0 | 11 | four red dragon wyrmlings (Master Quest, K7) | 4 red dragon wyrmling (65 HP) | 5 |
| `crg_entry_dragons` | main_floor | L10v1 | 10 | same | 4 red dragon wyrmling (52 HP) | 5 |
| `crg_entry_dragons` | main_floor | L9v2 | 9 | same | 4 red dragon wyrmling (47 HP) | 4 |
| `crg_balcony_zombies` | chapel_balcony | one version | 9 to 11 | a couple of zombies (K28) | 2 strahd zombie, as the book has them | 8 |

Which fight falls on which side of the owner's rule:

- **The dragons are held to 5 in 8.** They guard the way out of the castle, they are the book's signature set piece for the
  entry hall (the first thing the party meets and the last), and they come to life on purpose: a special encounter.
- **The balcony is left at 8 in 8.** It guards nothing (the book lists no treasure and no find in the king's balcony, and our
  thrones hold none), it is a side room off the chapel that no story beat passes through, and it is a plain ambush: two
  zombies that rise when the party steps out onto the gallery. It is an attrition fight, which the party wins at the cost of
  the first round (it is surprised) and a few spells.

## The dragons (K7)

The book's survey (Veeder on the 2016 text) calls them child-sized dragons; Master Quest makes them four red dragon wyrmlings that
don't follow anyone out of the room and Reloaded two. The stat block is the 2024 Red Dragon Wyrmling (75 HP, AC 17, two Rends, a 15-ft
fire cone on a 5-6), read twice from aidedd.org. They start on the four plinths' squares, one in each corner of the entry hall
(no burst catches more than two of them), and the party stands within two squares of a plinth beside the great doors, where the
scene that wakes them is called. At the stat block's own 75 HP the four win two in eight at level 10; three win six. HP is the only lever the
fight is tuned by:

| HP | L9 | L10 | L11 |
|---|---|---|---|
| 45 | 8 | 8 | |
| 46 | 7 | | |
| 47 | 4 | | |
| 48 | 3 | 7 | |
| 50 | 4 | 6 | |
| 52 | 4 | 5 | |
| 55 | 4 | 4 | 8 |
| 58 | 4 | 4 | |
| 60 | | | 7 |
| 62 | | 4 | 6 |
| 64 | | | 6 |
| 65 | | | 5 |
| 66 | | | 5 |
| 68 | | 4 | 4 |
| 75 | | 2 | |

Level 9 never lands on five: 46 HP is seven wins and 47 HP is four, and three dragons at 75 to 120 HP are four as well. The harder side
(47 HP) is the one kept.

## The balcony (K28)

The book's two zombies in the thrones are the Strahd zombies of CoS p. 241 and are kept as they are, ambushing a surprised party.
For the sharp party at levels 9 to 11 they are no 5-in-8 fight: two to eight of them (up to 150 HP each, a thousand Hit Points
between them) win 8 in 8 with nobody dropped, and so do two zombies with three wights and a vampire spawn, or with ten ghasts. The
first pass of this package added Strahd's spawn along the rail (ours, not the book's) to pull the fight to 5 in 8; the owner
chose to leave the fight at 8 in 8 instead (above), so the spawn are not in the data. What was tried, for anyone who wants a harder
balcony (level 10 unless marked; the spawn's HP is the stat block's own 90 unless given):

| Foes besides the two zombies | L9 | L10 | L11 |
|---|---|---|---|
| 1 to 3 wights, 1 spawn | | 8 each | |
| 4 spawn: 90 HP (stat block) | | 7 | |
| 4 spawn: 110, 130, 160 HP | | 7, 6, 6 | |
| 4 spawn: 175, 185, 200, 260 HP | | 4, 4, 4, 0 | |
| 5 spawn: 103, 110, 118, 125 HP | 6, 6, 6, 6 | (110) 8 | |
| 5 spawn: 140, 160 HP | 4, 4 | | |
| 6 spawn: 75, 85 HP | 6, 6 | | |
| 6 spawn: 86 to 99 HP | 4 | (90, 97) 7, 6 | |
| 6 spawn: 103, 110 HP | 3 (103) | 5, 3 | |
| 7 spawn: 97, 103, 110 HP | | | 6, 5, 5 |

With six spawn at 103 HP (seven at level 11) the real series test measured 5 at every level, at 7 to 9 rounds a fight.

## Method

A throwaway FightSeriesCase test (never committed) read an encounter's foes from the data, set their
`hp` and count from an environment grid and played seeds 1-8 for each cell, as docs/story/fight_tuning.md does; the numbers above were
then confirmed by the real series test.
