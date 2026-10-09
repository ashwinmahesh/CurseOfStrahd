extends TestCase
## A rider who drops to 0 Hit Points falls off into a free space (QA FN-21), and a Hit Point maximum that drops when
## an effect ends takes current Hit Points down with it (QA FN-22). 2024 PHB: Mounted Combat; Hit Point Maximum.


func test_a_rider_who_drops_falls_off_beside_the_mount() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 3))
	var steed := e.add(TestCombat.monster("dire_wolf"), &"party", Vector2i(4, 3))
	TestCombat.foe(e, "zombie", Vector2i(11, 7))
	TestCombat.start_with(e, ilse)
	assert_true(e.mount(ilse, steed).ok)
	assert_eq(ilse.cell, steed.cell, "riding: one square")
	e.deal_damage(null, ilse, [{"amount": ilse.creature.hp + 5, "type": "slashing"}], false, "A blow")
	assert_true(ilse.is_down(), "down")
	assert_true(e.mount_of(ilse) == null and e.rider_of(steed) == null, "off the mount")
	assert_ne(ilse.cell, steed.cell, "not in the mount's square")
	assert_eq(steed.cell, Vector2i(4, 3), "the mount stays where it was")
	assert_true(e.distance(ilse, steed) <= 5, "beside it")
	assert_true(ilse.creature.has_condition(&"prone"), "Prone")


func test_aid_ending_brings_hit_points_down_to_the_new_maximum() -> void:
	var ch := TestChars.pregen("godrick_pendlebrook", 7)
	ch.finish_long_rest()
	var base := ch.max_hp()
	var aid := Effect.new("Aid", &"spell", "aid").with_modifier("hp_max", {"value": 10})
	ch.add_effect(aid)
	ch.heal(10, "Aid")
	assert_eq(ch.max_hp(), base + 10)
	assert_eq(ch.hp, base + 10, "Aid raised both")
	ch.remove_effect(aid)   # dispelled, or its 8 hours are up
	assert_eq(ch.max_hp(), base)
	assert_eq(ch.hp, base, "no more Hit Points than the maximum")


func test_ending_an_effect_leaves_hit_points_below_the_maximum_alone() -> void:
	var ch := TestChars.pregen("godrick_pendlebrook", 7)
	ch.finish_long_rest()
	var aid := Effect.new("Aid", &"spell", "aid").with_modifier("hp_max", {"value": 10})
	ch.add_effect(aid)
	ch.hp = 12
	ch.remove_effect(aid)
	assert_eq(ch.hp, 12, "a wounded hero keeps what they have")
