# The Larders' two singles, and the churchyard dead

(2026-10-15, owner's rule: the sharp party wins 5 in 8 on Balanced, give or take one; neither Cyrus nor Doru is on the boss
lane's list. Held by `tests/integration/test_scaled_fights_larders.gd`; the churchyard by `test_scaled_fights_barovia.gd`.)

| Fight | Where | Level | Was | Now | Wins |
|---|---|---|---|---|---|
| `larders_cyrus_fight` | castle_ravenloft_larders | 10 | Cyrus Belview (a mongrelfolk) | Cyrus Belview and 15 Belview cooks, all berserkers at 80 HP | 5-6 |
| `larders_doru_hunger` | castle_ravenloft_larders_dungeon | 10 | Doru (a vampire spawn) | Doru and six more starved spawn in the neighbouring cells, all at 104 HP | 5 |
| `churchyard_dead` | village_of_barovia | 3 | 8 Strahd zombie, zombie (7 wins in 8) | 8 Strahd zombie, 3 zombie | 5 |

A lone foe cannot be made a fight for four level 10 heroes by Hit Points alone (Doru at five times his Hit Points still lost
eight times in eight to nothing), so each gets company that fits the place: the Belview kitchen, and the other chained
prisoners of the Larders. The two narration lines were reworded to say so (Cyrus: 'and the Belview cooks come out of the
pantries with knives'; Doru: 'and down the row the other cells begin to rattle'). The churchyard dead used to stay at 7 in 8
because the burial playthrough lost the six-win line-ups; with the engine as it is now the burial wins the 11-foe one.
