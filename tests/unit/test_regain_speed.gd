extends TestCase
## Speed back when a Speed-0 hold ends mid-turn (owner reports 2026-10-12): breaking free of Restrained, escaping a
## grapple, or the engulfing monster dying gives the hero the turn's Speed less what was already walked.


func _held_turn(e: Encounter, hero: Combatant) -> void:
	TestCombat.start_with(e, hero)
	hero.reset_turn()   # the turn starts held: Speed 0
	assert_eq(hero.movement_left, 0, "no movement while held")


func test_breaking_free_of_a_web_gives_the_speed_back() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	var web := Effect.new("Web", &"spell", "web").with_condition(&"restrained")
	web.escape = {"skill": "athletics", "dc": 1}
	ilse.creature.add_effect(web)
	_held_turn(e, ilse)
	assert_true(e.escape_effect(ilse, web.id).ok)
	assert_false(ilse.creature.has_condition(&"restrained"))
	assert_eq(ilse.movement_left, ilse.speed(), "the whole Speed for the rest of the turn")
	assert_true(e.move(ilse, Vector2i(5, 2)).ok, "and she walks")


func test_escaping_a_grapple_gives_the_speed_back() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var ogre := TestCombat.foe(e, "ogre", Vector2i(3, 2))
	e.grapples[ilse.id] = ogre.id
	ilse.creature.add_condition(&"grappled", ogre.name())
	ilse.set_meta("escape_dc", 1)
	_held_turn(e, ilse)
	for i in 5:
		if not ilse.creature.has_condition(&"grappled"):
			break
		ilse.action_available = true
		e.escape_grapple(ilse)
	assert_false(ilse.creature.has_condition(&"grappled"), "free")
	assert_eq(ilse.movement_left, ilse.speed())


func test_the_engulfer_dying_gives_the_speed_back() -> void:
	var e := TestCombat.open_field(3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var mound := TestCombat.foe(e, "shambling_mound", Vector2i(3, 2))
	e.monster_actions.engulf(mound, ilse, {"escape": 15}, "Engulf")
	_held_turn(e, ilse)
	e.deal_damage(ilse, mound, [{"amount": mound.creature.hp + 50, "type": "slashing"}], false, "A last blow")
	assert_true(mound.creature.dead or mound.creature.hp <= 0, "the mound falls")
	assert_eq(ilse.movement_left, ilse.speed(), "out, and free to move")
