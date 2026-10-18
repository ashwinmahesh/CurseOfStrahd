extends TestCase
## Everyone walks 25% faster while exploring (owner 2026-10-18), all from WalkPace.FASTER; a fight's squares don't.


func test_the_walk_is_a_quarter_faster_than_it_was() -> void:
	assert_between(WalkPace.FASTER, 1.25 - 0.0001, 1.25 + 0.0001, "one scale for every walker")
	# What each pace was before, in seconds a square (or squares a second, for the two that walk by speed).
	assert_between(LocationView.STEP_TIME, 0.26 / 1.25 - 0.0001, 0.26 / 1.25 + 0.0001, "the party exploring")
	assert_between(LocationView.SNEAK_STEP_TIME, 0.46 / 1.25 - 0.0001, 0.46 / 1.25 + 0.0001, "the party sneaking")
	assert_between(NpcRoutes.STEP_TIME, 0.7 / 1.25 - 0.0001, 0.7 / 1.25 + 0.0001, "townsfolk on their rounds")
	assert_between(LocationLead.NPC_STEP, 0.34 / 1.25 - 0.0001, 0.34 / 1.25 + 0.0001, "one leading the party")
	assert_between(NpcWalker.SPEED, 1.12 * 1.25 - 0.0001, 1.12 * 1.25 + 0.0001, "the gray-box villager")
	assert_between(PartyMember.SPEED, 2.8 * 1.25 - 0.0001, 2.8 * 1.25 + 0.0001, "the gray-box party")


func test_a_fights_squares_keep_their_pace() -> void:
	assert_between(CombatView.STEP_TIME, 0.37 - 0.0001, 0.37 + 0.0001, "combat movement is left alone")


func test_the_one_leading_is_still_no_quicker_than_the_party() -> void:
	assert_true(LocationLead.NPC_STEP >= LocationView.STEP_TIME, "the party keeps up with a lead")
	assert_true(NpcRoutes.STEP_TIME > LocationView.STEP_TIME, "a stroll stays slower than the party's walk")
