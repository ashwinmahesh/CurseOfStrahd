extends TestCase
## The test party at full ability (owner, 2026-10-14: "the players using their skills to their full abilities"): on top
## of sharp play, the cleric heals a friend before they drop and unleashes the Radiance of the Dawn, the paladin lays
## hands on the fallen and brings out his Sacred Weapon, the ranger marks her target and calls down a barrage, and the
## wizard throws Cone of Cold. With full play off (AUTOPILOT_FULL=0) it
## plays as it did on 2026-10-13.


func before_each() -> void:
	PartyAutopilot.full = true


func after_each() -> void:
	PartyAutopilot.full = PartyAutopilot.full_by_default


static func _field() -> Encounter:
	var rows: Array[String] = []
	for z in 12:
		rows.append("....................")
	return TestCombat.encounter(rows)


## Burns every slot of the levels from `from` up (so a spell of that level can't be cast).
static func _spend_slots(ch: Character, from: int) -> void:
	var slots := ch.spellcasting_slots()
	for l in range(from, 10):
		ch.slots_used[l - 1] = slots[l - 1]


func test_the_cleric_unleashes_the_radiance_on_a_crowd() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(5, 5), 7)
		var ogre := TestCombat.foe(e, "ogre", Vector2i(10, 5))
		TestCombat.foe(e, "ogre", Vector2i(10, 6))
		var ch := liriel.creature as Character
		_spend_slots(ch, 3)
		TestCombat.start_with(e, liriel)
		var charges := ch.resource_left("channel_divinity")
		PartyAutopilot.new(e).play(liriel)
		assert_eq(ch.resource_left("channel_divinity") < charges, on, "the Radiance only at full ability (full %s)" % on)
		if on:
			assert_true(ogre.creature.hp < ogre.creature.max_hp(), "and it burns the ogre")


func test_the_cleric_mends_a_friend_under_a_third_with_healing_word() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var liriel := TestCombat.hero(e, "liriel_dawnsong", Vector2i(5, 5), 6)
		var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(7, 5), 6)
		TestCombat.foe(e, "ogre", Vector2i(14, 5))
		godrick.creature.hp = godrick.creature.max_hp() / 4
		var low: int = godrick.creature.hp
		TestCombat.start_with(e, liriel)
		PartyAutopilot.new(e).play(liriel)
		assert_eq(godrick.creature.hp > low, on, "Healing Word on Godrick only at full ability (full %s)" % on)


func test_the_paladin_lays_hands_on_the_fallen_beside_him() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(5, 5), 6)
		var rat := TestCombat.hero(e, "ratatoille", Vector2i(4, 5), 6)
		TestCombat.foe(e, "ogre", Vector2i(12, 5))
		e.deal_damage(null, rat, [{"amount": rat.creature.hp, "type": "force"}], false, "test")
		assert_eq(rat.creature.hp, 0, "Ratatouille is down")
		TestCombat.start_with(e, godrick)
		PartyAutopilot.new(e).play(godrick)
		assert_eq(rat.creature.hp > 0, on, "Lay On Hands lifts him only at full ability (full %s)" % on)


func test_the_paladin_brings_out_his_sacred_weapon_and_blesses_when_nothing_can_be_reached() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var godrick := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 5), 6)
		TestCombat.hero(e, "liriel_dawnsong", Vector2i(3, 6), 6)
		TestCombat.foe(e, "ogre", Vector2i(19, 5))
		TestCombat.start_with(e, godrick)
		PartyAutopilot.new(e).play(godrick)
		var conc := godrick.creature.concentration
		assert_eq(conc != null and conc.source_id == "bless", on, "Bless with the foe out of reach (full %s)" % on)
	PartyAutopilot.full = true
	var e2 := _field()
	var g2 := TestCombat.hero(e2, "godrick_pendlebrook", Vector2i(5, 5), 6)
	TestCombat.foe(e2, "ogre", Vector2i(8, 5))
	TestCombat.start_with(e2, g2)
	PartyAutopilot.new(e2).play(g2)
	assert_true(g2.creature.has_flag("sacred_weapon"), "Sacred Weapon with an ogre a step away")


func test_the_ranger_marks_her_target() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var thistle := TestCombat.hero(e, "thistle", Vector2i(2, 5), 6)
		TestCombat.foe(e, "ogre", Vector2i(12, 5))
		TestCombat.start_with(e, thistle)
		PartyAutopilot.new(e).play(thistle)
		var conc := thistle.creature.concentration
		assert_eq(conc != null and conc.source_id == "hunters_mark", on, "Hunter's Mark only at full ability (full %s)" % on)


func test_the_ranger_calls_down_a_barrage_on_a_crowd() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var thistle := TestCombat.hero(e, "thistle", Vector2i(2, 5), 9)
		for x: int in [8, 9, 10]:
			TestCombat.foe(e, "ogre", Vector2i(x, 5))
		TestCombat.start_with(e, thistle)
		var before := (thistle.creature as Character).slots_left(3)
		PartyAutopilot.new(e).play(thistle)
		assert_eq((thistle.creature as Character).slots_left(3) < before, on, "Conjure Barrage only at full ability (full %s)" % on)


func test_the_wizard_throws_cone_of_cold_at_three_foes() -> void:
	for on: bool in [false, true]:
		PartyAutopilot.full = on
		var e := _field()
		var rat := TestCombat.hero(e, "ratatoille", Vector2i(2, 5), 9)
		for x: int in [6, 7, 8]:
			TestCombat.foe(e, "ogre", Vector2i(x, 5))
		TestCombat.start_with(e, rat)
		var before := (rat.creature as Character).slots_left(5)
		PartyAutopilot.new(e).play(rat)
		assert_eq((rat.creature as Character).slots_left(5) < before, on, "Cone of Cold only at full ability (full %s)" % on)
