# The Dungeon Expansion's T1 fight: the ambush under the faceless god

(Owner, 2026-10-13: the book's fights were written for weaker characters. Over seeds 1-8 the four pregens on the sharp
autopilot win five in eight on Balanced, give or take one, each fight played from where the party stands when it starts, its
foes starting spread out. Owner, 2026-10-18: attrition fights may stay at 8 in 8, "unless theyre guarding something or its a
special encounter". Held by `tests/integration/test_scaled_fights_t1.gd`. The package: Dungeon Expansion Plan T1,
docs/regions/amber_temple.md §4.7.)

| Fight | Where | Version | Level | Book | Now | Wins |
|---|---|---|---|---|---|---|
| `statue_ambush` | faceless_god | L10v0 | 10 | an arcanaloth in magical darkness at the God of Secrets (X5a) and three flameskulls behind arrow slits (X17), Elven Tower's chapter 13 | the shape in the dark (arcanaloth, leaves after round 2) + 3 flameskull, party surprised | 4 |
| `statue_ambush` | faceless_god | L9v1 | 9 | same | the shape in the dark (arcanaloth, leaves after round 1) + 3 flameskull, party surprised | 5 |

Level 10 sits on the harder side (4), as the rule allows where no line-up lands on 5: with the shape leaving after round 1 the
party wins 6, after round 2 it wins 4. Why it is held to 5 in 8: it is the book's signature set piece for the temple's way in, the first thing that happens in the
great hall, and a special encounter by the owner's rule.

## How it was tuned

The party stands on the great hall's south edge, (19, 21) to (21, 21), as it steps up out of the south gallery, and is
surprised. The shape is the 2025 arcanaloth (175 HP) at the statue's head; the flameskulls start in the arrow-slit gallery,
two of them at the slits. Its `withdraw` (after N rounds, or below 120 HP) was the first lever, the flameskulls' count and
Hit Points the second. Wins over seeds 1-8:

| Shape leaves after | Flameskulls | L9 | L10 |
|---|---|---|---|
| round 2 | 3 at 40 HP | 0 | 4 |
| round 1 | 3 at 40 HP | 5 | 6 |
| round 1 | 2 at 40 HP | 8 | |
