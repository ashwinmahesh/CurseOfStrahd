extends TestCase
## 2024 PHB "Ability Scores and Modifiers" table and "Proficiency Bonus" table.


func test_modifier_table() -> void:
	var table := {1: -5, 2: -4, 3: -4, 4: -3, 5: -3, 8: -1, 9: -1, 10: 0, 11: 0, 12: 1, 13: 1,
		15: 2, 18: 4, 19: 4, 20: 5, 21: 5, 24: 7, 29: 9, 30: 10}
	for score: int in table:
		assert_eq(Abilities.modifier(score), int(table[score]), "score %d" % score)


func test_proficiency_bonus_by_level() -> void:
	var expected := [2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6]
	for level in range(1, 21):
		assert_eq(Abilities.proficiency_bonus(level), int(expected[level - 1]), "level %d" % level)


func test_proficiency_for_cr() -> void:
	assert_eq(Abilities.proficiency_for_cr(0.25), 2)
	assert_eq(Abilities.proficiency_for_cr(4), 2)
	assert_eq(Abilities.proficiency_for_cr(5), 3)
	assert_eq(Abilities.proficiency_for_cr(15), 5) # Strahd von Zarovich is CR 15
	assert_eq(Abilities.proficiency_for_cr(30), 9)


func test_passive_perception() -> void:
	# Level 1, Wisdom 15 (+2), proficient in Perception (+2): 10 + 4 = 14.
	assert_eq(Abilities.passive_score(4), 14)
	assert_eq(Abilities.passive_score(4, true), 19)
	assert_eq(Abilities.passive_score(4, false, true), 9)
	assert_eq(Abilities.passive_score(4, true, true), 14, "advantage and disadvantage cancel")


func test_eighteen_skills() -> void:
	assert_eq(Abilities.SKILLS.size(), 18)
	assert_eq(Abilities.SKILLS[&"athletics"], Abilities.STR)
	assert_eq(Abilities.SKILLS[&"stealth"], Abilities.DEX)
