extends TestCase
## Fights that can't stall forever: a foe with no way to any enemy gives the fight up after two turns of it, one that
## can still find a way (round a wall, through a door) stays; the party's autopilot Searches for hidden foes and foes
## search for hidden heroes; a creature standing on a body is attacked like any other.


## A wall splits the room with no way through: the wolf, already as close as it can get, gives up on its second turn,
## and with no foe left the fight is won.
func test_a_foe_with_no_way_to_its_enemies_gives_up_the_fight() -> void:
	var e := TestCombat.encounter(["....#....", "....#....", "....#...."], 4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 1))
	TestCombat.start_with(e, w)
	assert_true(e.ai.tactics.cut_off(w), "no way round the wall")
	e.run_ai_turn()
	assert_false(w.has_meta("left_fight"), "one turn cut off: it stays")
	assert_eq(e.current(), hedda)
	e.end_turn()
	e.run_ai_turn()
	assert_true(w.has_meta("left_fight"), "the second turn in a row it gives up")
	assert_true(e.log.texts().has("Wolf can find no way to reach its foes"))
	assert_eq(e.state, Encounter.State.OVER)
	assert_eq(e.outcome, "victory")


func test_a_foe_with_a_way_round_or_a_door_to_open_stays() -> void:
	var e := TestCombat.encounter(["....#....", ".........", "....#...."], 4)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 0))
	TestCombat.start_with(e, w)
	assert_false(e.ai.tactics.cut_off(w), "the gap in the wall")
	# A shut door in the gap: the wolf can't open it, but the party can, so the fight isn't over.
	var gap: Array[Vector2i] = [Vector2i(4, 1)]
	var door := e.objects.add("door_wood", gap, {"open": false})
	assert_true(e.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL), "the shut door walls the gap")
	assert_false(e.ai.tactics.cut_off(w), "a door counts as a way through")
	assert_true(e.grid.has_flag(Vector2i(4, 1), CombatGrid.WALL), "and is put back shut")
	for i in 3:
		e.run_ai_turn()
		e.end_turn()
	assert_false(w.has_meta("left_fight"), "it waits behind the door")
	assert_false(door.open)


## A legendary creature holds its ground however long it's cut off: its fight is the story's.
func test_a_legendary_creature_never_gives_up() -> void:
	var e := TestCombat.encounter(["....#....", "....#....", "....#...."], 4)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(5, 1))
	(w.creature as Monster).data["legendary_actions"] = {}
	TestCombat.start_with(e, w)
	for i in 3:
		e.run_ai_turn()
		e.end_turn()
	assert_false(w.has_meta("left_fight"))


## The party's autopilot (balance series) looks for a foe it can't see or hear rather than wait it out.
func test_the_autopilot_searches_for_hidden_foes() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var s := TestCombat.foe(e, "shadow", Vector2i(8, 5))
	s.hidden = true
	s.stealth_total = 1
	s.creature.add_condition(&"invisible", "Hidden")
	TestCombat.start_with(e, ilse)
	assert_false(e.can_see(ilse, s))
	PartyAutopilot.new(e).play(ilse)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.begins_with("Ilse Varga searches")), "she searched")
	assert_false(s.hidden, "and found the shadow")


func test_foes_search_for_hidden_heroes() -> void:
	var e := TestCombat.open_field(4)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(8, 5))
	ilse.hidden = true
	ilse.stealth_total = 1
	ilse.creature.add_condition(&"invisible", "Hidden")
	TestCombat.start_with(e, w)
	assert_eq(str(e.ai.plan_turn(w)["kind"]), "search")
	e.run_ai_turn()
	assert_false(ilse.hidden, "the wolf sniffed her out")


## A dead creature is an object: the living one standing on its body is what's in the square, seen and struck as usual.
func test_a_creature_standing_on_a_body_is_attacked_like_any_other() -> void:
	var e := TestCombat.open_field(4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var body := TestCombat.foe(e, "wolf", Vector2i(4, 3))
	var w := TestCombat.foe(e, "wolf", Vector2i(9, 6))
	w.creature.name = "Grey Wolf"
	TestCombat.start_with(e, hedda)
	body.creature.hp = 0
	body.creature.dead = true
	w.cell = Vector2i(4, 3)
	assert_eq(e.occupant_at(Vector2i(4, 3)), w, "the square holds the living wolf")
	assert_true(e.can_see(hedda, w))
	var plan := e.ai.plan_turn(hedda)
	assert_eq(str(plan["kind"]), "attack")
	assert_eq(plan["target"], w)
	PartyAutopilot.new(e).play(hedda)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("Grey Wolf") and (t.contains(" hits ") or t.contains(" misses "))),
		"Hedda swung at it")

