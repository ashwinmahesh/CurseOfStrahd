# Kasimir at the castle (Story Allies Presence Plan, package K2)

Package K1 gave Kasimir Velikov his road to the Amber Temple and his closure at the camp. This package follows him to the castle. It
covers what he does at Castle Ravenloft's gates after the bargain at Tarakamedes, what the host says to him, his word over the
coffin and three camp talks. **Not built yet: the crypt scene and the knot errand for a sister laid to rest.** Both need the crypt of
Patrina Velikovna in the Lesser Vaults, which is on the castle crypts lane (branch `castle-crypts-stair`), not on main.

**No story flag moves**; the one new flag, `kasimir_at_gates`, is a side flag (`data/flags/allies_kasimir.json`).

## If he made the bargain (kasimir_bargain == "made")

He gave every year he had left but one so Patrina would live, and she walked ahead of him toward the castle. He travels with the
party (he is a guest and the rule `guest_stays` keeps him from being sent home). At the castle he will not go in:

- **By the road**: the first time the party comes near the chasm's edge (`crg_chasm_edge`, the road's end, a prop's `call`,
  `approach` 6, `call_when` on the bargain and "has not yet left"), `allies/kasimir_castle:gates_road` plays. She went in by the front
  door; he will wait on this side of the ditch. The party can say they will tell her he is here, or ask him to come in, and he answers
  either; then `farewell_tail`: he leaves the party (`leave`), sets `kasimir_at_gates` and sits on a stone by the road.
- **By the carriage**: carried to the castle's front courtyard, the dinner (`gates_dinner:start`) has the host greet him ("Your sister
  arrived ahead of you"; "A clever guest knows when to come home"; she is resting upstairs and has earned it), and he takes the air by
  the gate. The same `farewell_tail` words, written out in the dinner so the table can go on for the others.
- **By the road below the drawbridge**, from then on, `gates` (an NPC of `castle_ravenloft_gates` while `kasimir_at_gates` and he is
  not with the party; the Vistani camp's Kasimir stands there no longer): how long he has left, anything to tell her (nothing to
  carry, one thing to say), and his scrolls (his shop).

## If she was laid to rest, or he made his peace

At the dinner the host greets him ("you finally take a chair at my board with a quiet mind. Grief suited you better") and he stays in the
party. The rest of his story is K1's.

## Over the coffin (`catacombs_coffin`)

An `interject` each while the count sleeps and once he lies beaten, for whoever of the party is Kasimir: his people were the count's
guests and stayed as his tenants.

## Camp talks (`narrative/camp/kasimir_velikov.dialogue`)

When he travels with the party a Long Rest at camp can bring three talks (`CampTalk.who_asks` reads `guest:<npc>`), one a night, each
once, the later story first: `castle_eve` (the night before the castle: the day they stoned Patrina and the speech he will not make),
`counting` (the bargain: the knots on the net, a year weighed in two hands) and `peace` (laid to rest: the wide silence he does not yet
trust). Nothing rolls and no flag is set.

## Lines

47 new unvoiced lines (the gates 20, the camp talks 19, the dinner and the coffin 8; the dinner repeats the farewell's two closing
lines word for word, so they have one recording each). Drafted by Gemini through the ai-bridge (`docs/plans/gemini_allies/k2/`), edited.

## Tests

`tests/unit/test_kasimir_castle.gd` (11 tests): the farewell either way and what it changes; the dinner for the bargain, for peace and
for neither; the coffin; where he sits and that the camp lets him go; the hub; the camp talks' conditions, order and endings; no
mention of the count. `tests/integration/test_kasimir_castle_call.gd` boots the gates: the chasm's edge carries the call, plays it on
arrival once, and not without the bargain, without him or after he has gone.
