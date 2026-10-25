# The last non-boss fights without a series test, and the churchyard dead

**Hit Points since 2026-10-24** (owner: "for ALL monster HP, just use the Monster Manual values; no custom HP"): the foes in these fights fight at their stat blocks' Hit Points. The raised or lowered Hit Points the tables below describe are gone from the data, and the win counts are the ones measured before; the combat-length pass measures the fights again.

(2026-10-15, owner's rule: the sharp party wins 5 in 8 on Balanced, give or take one; none of these is on the boss lane's
list. Held by `tests/integration/test_scaled_fights_rest.gd`; the churchyard by `test_scaled_fights_barovia.gd`.)

| Fight | Where | Level | Was | Now | Wins |
|---|---|---|---|---|---|
| `larders_cyrus_fight` | castle_ravenloft_larders | 10 | Cyrus Belview (a mongrelfolk) | Cyrus Belview and 15 Belview cooks, all berserkers at 80 HP | 5-6 |
| `larders_doru_hunger` | castle_ravenloft_larders_dungeon | 10 | Doru (a vampire spawn) | Doru and six more starved spawn in the neighbouring cells, all at 104 HP | 5 |
| `larders_false_brother` | castle_ravenloft_larders_dungeon | 10 | Brother Anatol and 2 vampire spawn | since 2026-10-24 Anatol is a Vampire (the 2025 block, a boss with legendary actions and the bosses' +25% damage) and the two spawn are Vampire Spawn, all at book Hit Points; now a boss fight, measured at full ability | 2 |
| `larders_false_brother_unmasked` | castle_ravenloft_larders_dungeon | 10 | Brother Anatol and 2 vampire spawn | the same three, a Vampire and two spawn at book Hit Points | 3 |
| `library_wardens` | amber_temple_library | 10 | 4 flameskull | 8 flameskull | 4 |
| `churchyard_dead` | village_of_barovia | 3 | 8 Strahd zombie, zombie (7 wins in 8) | 8 Strahd zombie, 3 zombie | 5 |

A lone foe cannot be made a fight for four level 10 heroes by Hit Points alone (Doru at five times his Hit Points still lost
eight times in eight to nothing), so Cyrus and Doru get company that fits the place: the Belview kitchen, and the other
chained prisoners of the Larders. The two narration lines were reworded to say so (Cyrus: 'and the Belview cooks come out of
the pantries with knives'; Doru: 'and down the row the other cells begin to rattle'), and the library's ('Skulls rise from the
top shelves...'). The library fight is played with the restricted gate open, as the party stands inside it: shut, the
survivors on the far side could neither be reached nor reach the party, and the fight never ended (the old 'flameskull
stall'). The churchyard dead used to stay at 7 in 8 because the burial playthrough lost the six-win line-ups; with the
engine as it is now the burial wins the 11-foe one.
