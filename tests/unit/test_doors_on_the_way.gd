extends TestCase
## Shut doors in a fight (burgomaster's mansion siege, 2026-10-13: zombies behind the wake room door and the party
## behind the parlor's waited out all thirty rounds): a creature that opens doors walks to one on its way to its foe,
## opens it with its object interaction and goes on; a beast waits behind it; the party's autopilot opens doors too. A
## foe the heroes can still walk up to isn't cut off, though it can't reach them.


const CORRIDOR: Array[String] = ["#########", "#.......#", "#########"]


func _door(e: Encounter, cell: Vector2i) -> BattleObject:
	var cells: Array[Vector2i] = [cell]
	return e.objects.add("door_wood", cells, {"open": false})


func test_a_zombie_opens_the_door_between_it_and_the_party() -> void:
	var e := TestCombat.encounter(CORRIDOR, 4)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var z := TestCombat.foe(e, "zombie", Vector2i(7, 1))
	var door := _door(e, Vector2i(4, 1))
	TestCombat.start_with(e, z)
	assert_true(AiBrain.door_opener(z))
	e.run_ai_turn()
	assert_true(door.open, "it opened the door on its way")
	assert_true(z.cell.x < 4, "and walked on through it: %s" % z.cell)


func test_a_wolf_waits_behind_a_shut_door() -> void:
	var e := TestCombat.encounter(CORRIDOR, 4)
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var w := TestCombat.foe(e, "wolf", Vector2i(7, 1))
	var door := _door(e, Vector2i(4, 1))
	TestCombat.start_with(e, w)
	assert_false(AiBrain.door_opener(w), "a beast doesn't open doors")
	e.run_ai_turn()
	assert_false(door.open)
	assert_true(w.cell.x > 4)


func test_the_autopilot_opens_a_door_on_its_way_to_a_foe() -> void:
	var e := TestCombat.encounter(CORRIDOR, 4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	TestCombat.foe(e, "zombie", Vector2i(7, 1))
	var door := _door(e, Vector2i(4, 1))
	TestCombat.start_with(e, hedda)
	PartyAutopilot.new(e).play(hedda)
	assert_true(door.open, "Hedda opened it")
	assert_true(hedda.cell.x >= 4, "and went through: %s" % hedda.cell)


## A Large dire wolf can't squeeze through a one-square gap, but the hero on the far side can walk up to it: the fight
## can still be finished, so it stays. With a bystander standing in the gap neither can, and it's cut off.
func test_a_foe_the_heroes_can_walk_up_to_isnt_cut_off() -> void:
	var e := TestCombat.encounter(["##########", "#....#...#", "#....#...#", "#........#", "##########"], 4)
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(7, 2))
	var dw := TestCombat.foe(e, "dire_wolf", Vector2i(1, 1))
	TestCombat.start_with(e, dw)
	assert_eq(dw.size_cells, 2)
	assert_false(e.ai.tactics.cut_off(dw), "Hedda can come round to it")
	e.grid.set_flag(Vector2i(5, 3), CombatGrid.LOW, true)
	assert_true(e.ai.tactics.cut_off(dw), "with the gap blocked, nobody can")
	assert_eq(hedda.cell, Vector2i(7, 2))
