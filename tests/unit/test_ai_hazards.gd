extends TestCase
## Dangerous ground in the AI's eyes (combat/ai/ai_hazards.gd; owner, 2026-10-13: "creatures shouldn't willingly move
## into dangerous terrain unless their intelligence is really low (ex hunger of hadar, spirit guardians)").

## A corridor with a long way round: row 3 runs straight from west to east, row 1 loops over the wall between them.
const LOOP := ["#############", "#...........#", "#.#########.#", "#...........#", "#############"]


## A Cloud of Daggers spread over `cells` (2024: on entering it, and ending a turn in it, 4d4 Slashing), kept by `by`.
func _daggers(e: Encounter, by: Combatant, cells: Array[Vector2i]) -> FieldObject:
	var o := FieldObject.new(FieldObject.Kind.ZONE, "cloud_of_daggers", "Cloud of Daggers")
	o.caster_id = by.id
	o.slot = 2
	o.save_dc = 13
	o.cells = cells
	o.cell = cells[0]
	o.rules = {"triggers": ["cast", "enter", "end_turn", "moved_into"], "damage": [{"dice": "4d4", "type": "slashing"}],
		"size": 5}
	o.rounds_left = 10
	e.spells.zones.add(o, CombatResult.new())
	return o


func _row(y: int, from_x: int, to_x: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(from_x, to_x + 1):
		out.append(Vector2i(x, y))
	return out


func _block(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			out.append(Vector2i(x, y))
	return out


func test_only_the_witless_ignore_dangerous_ground() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(0, 0))
	var berserker := TestCombat.foe(e, "berserker", Vector2i(9, 3))
	var zombie := TestCombat.foe(e, "zombie", Vector2i(9, 5))
	var wolf := TestCombat.foe(e, "wolf", Vector2i(9, 6))
	var blight := TestCombat.foe(e, "twig_blight", Vector2i(9, 7))
	TestCombat.start_with(e, hero)
	assert_true(e.ai.hazards.read(berserker) == null, "nothing dangerous on the field yet")
	_daggers(e, hero, _row(3, 4, 6))
	assert_true(e.ai.hazards.read(berserker) != null, "Intelligence 9 heeds it")
	assert_true(e.ai.hazards.read(zombie) == null, "Intelligence 3: a zombie shambles on")
	assert_true(e.ai.hazards.read(wolf) == null, "Intelligence 3: a wolf runs on")
	assert_true(e.ai.hazards.read(blight) == null, "a twig blight fights mindlessly (its profile)")
	var v := e.ai.hazards.read(berserker)
	assert_true(v.avoid.has(Vector2i(5, 3)), "its walk keeps out of the cloud")
	var through: Array[Vector2i] = [Vector2i(7, 3), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(3, 3)]
	assert_between(v.cost(through), 10.0 - 0.01, 10.0 + 0.01, "walking through: one hit of 4d4 (once a turn)")
	var into: Array[Vector2i] = [Vector2i(7, 3), Vector2i(6, 3)]
	assert_between(v.cost(into), 10.0 - 0.01, 10.0 + 0.01, "stepping in and staying: still one hit this turn")
	var past: Array[Vector2i] = [Vector2i(7, 3), Vector2i(7, 2), Vector2i(6, 2)]
	assert_between(v.cost(past), 0.0 - 0.01, 0.0 + 0.01, "beside it costs nothing")


func test_a_thinking_foe_takes_the_long_way_round() -> void:
	var e := TestCombat.encounter(LOOP, 3)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(11, 3))
	var foe := TestCombat.foe(e, "berserker", Vector2i(1, 3))
	TestCombat.start_with(e, foe)
	var cloud := _daggers(e, hero, _row(3, 4, 7))
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_eq(foe.creature.hp, hp, "never touched the daggers")
	assert_false(foe.cell in cloud.cells)
	assert_eq(foe.cell.y, 1, "the loop over the wall, Dashing: %s" % foe.cell)
	assert_true(foe.cell.x >= 9, "well along it: %s" % foe.cell)


## Circling the ground round after round and no nearer (a cleric who keeps her Spirit Guardians on it as it goes round,
## or a way round that never opens): the next round it strikes from in it instead of circling on.
func test_a_foe_circling_no_nearer_goes_in() -> void:
	var e := TestCombat.encounter(LOOP, 3)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(9, 3))
	var foe := TestCombat.foe(e, "berserker", Vector2i(3, 3))
	TestCombat.start_with(e, foe)
	_daggers(e, hero, _row(3, 5, 7))
	var plan := e.ai.plan_turn(foe)
	assert_eq(str(plan["kind"]), "approach", "the long way round first")
	assert_true(bool(plan.get("round", false)))
	e.ai._rounding[foe.id] = {"round": e.round_no - 1, "target": hero.id, "gap": e.distance(foe, hero)}
	plan = e.ai.plan_turn(foe)
	assert_eq(str(plan["kind"]), "attack", "circled a round already, no nearer: through the daggers")
	assert_eq(plan["target"] as Combatant, hero)


func test_a_mindless_foe_walks_straight_through() -> void:
	var e := TestCombat.encounter(LOOP, 3)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(11, 3))
	var z := TestCombat.foe(e, "zombie", Vector2i(1, 3))
	TestCombat.start_with(e, z)
	_daggers(e, hero, _row(3, 4, 7))
	var hp := z.creature.hp
	e.run_ai_turn()
	assert_eq(z.cell.y, 3, "straight down the corridor")
	assert_true(z.creature.hp < hp, "and into the daggers")


func test_it_attacks_from_a_square_outside_the_area() -> void:
	var e := TestCombat.open_field(5)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(6, 3))
	var foe := TestCombat.foe(e, "berserker", Vector2i(1, 3))
	TestCombat.start_with(e, foe)
	var cloud := _daggers(e, hero, _block(Vector2i(5, 2), Vector2i(5, 4)))
	var plan := e.ai.plan_turn(foe)
	assert_eq(str(plan["kind"]), "attack")
	assert_false(plan["cell"] in cloud.cells, "from beside the hero, clear of the daggers: %s" % plan["cell"])
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_eq(foe.creature.hp, hp, "walked round them")
	assert_eq(e.distance(foe, hero), 5)
	assert_false(foe.action_available, "and struck")


func test_with_no_way_round_it_goes_in() -> void:
	# The only hero stands in the middle of her own Spirit Guardians: every square beside her is in it. Too far to strike
	# her this turn through the spirits (Difficult Terrain to it), it doesn't stand at their edge: it wades in toward
	# her (owner, 2026-10-18: enemies don't waste their turn), and strikes the next.
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(5, 4))
	var foe := TestCombat.foe(e, "berserker", Vector2i(10, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	var spirits := e.spells.zones.live()[0]
	e.end_turn()
	assert_eq(e.current(), foe)
	var hp := foe.creature.hp
	assert_eq(str(e.ai.plan_turn(foe)["kind"]), "approach")
	e.run_ai_turn()
	assert_true(foe.cell in spirits.cells, "in among the spirits: %s" % foe.cell)
	assert_true(foe.creature.hp < hp, "and they bit")
	e.end_turn()
	assert_eq(e.current(), foe)
	assert_eq(str(e.ai.plan_turn(foe)["kind"]), "attack", "now it can reach her, and nothing else is there to reach")
	e.run_ai_turn()
	assert_eq(e.distance(foe, cleric), 5, "in beside her")


func test_with_no_way_round_a_slow_foe_wades_in_the_first_round() -> void:
	# Too slow to reach her through her spirits in one turn: it doesn't wait at their edge, it wades on in.
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(5, 4))
	var foe := TestCombat.foe(e, "berserker", Vector2i(10, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	var spirits := e.spells.zones.live()[0]
	foe.creature.base_speed["walk"] = 15
	e.end_turn()
	var gap := e.distance(foe, cleric)
	e.run_ai_turn()
	assert_true(foe.cell in spirits.cells, "on in: %s" % foe.cell)
	assert_true(e.distance(foe, cleric) < gap, "nearer her")


## What the ground could do at its worst: every die at its highest, every save failed, once a turn where it hits once a
## turn; and what a creature has room for (its Hit Points less a tenth of its Hit Point maximum, 1 at least).
func test_the_worst_the_ground_can_do() -> void:
	var e := TestCombat.open_field()
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(0, 0))
	var berserker := TestCombat.foe(e, "berserker", Vector2i(9, 3))
	TestCombat.start_with(e, hero)
	_daggers(e, hero, _row(3, 4, 6))
	var v := e.ai.hazards.read(berserker)
	var through: Array[Vector2i] = [Vector2i(7, 3), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(3, 3)]
	assert_between(v.worst(through), 16.0 - 0.01, 16.0 + 0.01, "4d4 at its highest, once a turn")
	var into: Array[Vector2i] = [Vector2i(7, 3), Vector2i(6, 3)]
	assert_between(v.worst(into), 16.0 - 0.01, 16.0 + 0.01, "stepping in and staying: still once")
	var past: Array[Vector2i] = [Vector2i(7, 3), Vector2i(7, 2), Vector2i(6, 2)]
	assert_between(v.worst(past), 0.0 - 0.01, 0.0 + 0.01, "beside it: nothing")
	var keep := ceili(0.1 * berserker.creature.max_hp())
	assert_between(v.room, berserker.creature.hp - keep - 0.01, berserker.creature.hp - keep + 0.01,
		"its Hit Points less a tenth of its maximum")
	assert_false(v.deadly(through))
	berserker.creature.hp = keep + 15
	v = e.ai.hazards.read(berserker)
	assert_true(v.deadly(through), "16 at the worst would leave it under a tenth")
	assert_false(v.deadly(past))
	berserker.creature.hp = keep + 16
	assert_false(e.ai.hazards.read(berserker).deadly(through), "exactly a tenth left is enough")


## Ground that could drop it at its worst it never walks into (owner, 2026-10-18: "as long as it won't kill them"):
## 3rd-level Spirit Guardians can do 24, and a berserker keeps a tenth of its 67 Hit Points (7).
func test_it_never_wades_into_ground_that_could_drop_it() -> void:
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(5, 4))
	var foe := TestCombat.foe(e, "berserker", Vector2i(10, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	var spirits := e.spells.zones.live()[0]
	foe.creature.hp = 30
	e.end_turn()
	assert_eq(e.current(), foe)
	e.run_ai_turn()
	assert_false(foe.cell in spirits.cells, "not among the spirits, %s" % foe.cell)
	assert_eq(foe.creature.hp, 30, "untouched")
	assert_true(e.distance(foe, cleric) <= 20, "at their edge, as close as it dares")
	foe.creature.hp = 31
	while e.current() != foe:
		e.end_turn()
	assert_eq(str(e.ai.plan_turn(foe)["kind"]), "attack", "31 Hit Points: 24 at the worst leaves the 7 it keeps")
	e.run_ai_turn()
	assert_true(foe.cell in spirits.cells)
	assert_eq(e.distance(foe, cleric), 5, "in beside her")
	while e.pending != null:
		e.answer_reaction(false)


## Held off from every foe by ground that could drop it, turn after turn (a hurt will-o'-wisp at the edge of a cleric's
## Spirit Guardians, unseen, the party never coming for it), it slips away rather than wait out the fight.
func test_held_off_by_ground_that_could_drop_it_it_slips_away() -> void:
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(5, 4))
	var foe := TestCombat.foe(e, "berserker", Vector2i(10, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	foe.creature.hp = 20
	for i in AiTactics.CUT_OFF_TURNS:
		while e.current() != foe:
			e.end_turn()
		assert_false(foe.has_meta("left_fight"), "turn %d: still here" % [i + 1])
		e.run_ai_turn()
		e.end_turn()
	assert_eq(str(foe.get_meta("left_fight", "")), "cut off", "gone")
	assert_eq(foe.creature.hp, 20, "never touched the spirits")


## Beside a cleric in her own Spirit Guardians, with no one else to strike, it strikes her round after round: the hole
## her own square makes in her spirits is no way round them (it used to walk out of them to close on her "round" them,
## and strike only every other round or so).
func test_beside_a_cleric_in_her_spirits_it_strikes_every_round() -> void:
	var e := TestCombat.open_field(4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(5, 4))
	var foe := TestCombat.foe(e, "berserker", Vector2i(6, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	for i in 2:
		while e.current() != foe:
			e.end_turn()
		var plan := e.ai.plan_turn(foe)
		assert_eq(str(plan["kind"]), "attack", "round %d: %s" % [i + 1, plan.get("why", "")])
		e.run_ai_turn()
		while e.pending != null:
			e.answer_reaction(false)
		assert_eq(e.distance(foe, cleric), 5, "round %d: still beside her" % [i + 1])
		e.end_turn()


## The way round the ground leads nowhere this turn (a bystander stands in the one gap): it doesn't wait on it, it
## goes through the ground, which won't drop it.
func test_a_way_round_that_goes_nowhere_isnt_waited_on() -> void:
	var e := TestCombat.encounter(LOOP, 3)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(9, 3))
	var foe := TestCombat.foe(e, "berserker", Vector2i(1, 3))
	var bystander := TestCombat.foe(e, "bandit", Vector2i(1, 2))
	bystander.side = &"neutral"
	TestCombat.start_with(e, foe)
	var cloud := _daggers(e, hero, _row(3, 4, 7))
	assert_true(bool(e.ai.plan_turn(foe).get("round", false)), "a way round, as far as the map goes")
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_true(foe.cell.x > 7, "through the daggers: %s" % foe.cell)
	assert_false(foe.cell in cloud.cells)
	assert_true(foe.creature.hp < hp, "and they cut")
	assert_eq(e.distance(foe, hero), 5)


func test_it_goes_for_the_hero_it_can_reach_round_the_area() -> void:
	# Silvain is nearer and within a swing this turn, but only from among his spirits; Ilse stands clear of them.
	var rows: Array[String] = []
	for z in 8:
		rows.append("................")
	var e := TestCombat.encounter(rows, 4)
	var cleric := TestCombat.caster_with(e, ["spirit_guardians"], Vector2i(2, 4))
	var archer := TestCombat.hero(e, "ilse_varga", Vector2i(15, 0))
	var foe := TestCombat.foe(e, "berserker", Vector2i(7, 4))
	TestCombat.start_with(e, cleric)
	assert_true(e.spells.cast(cleric, "spirit_guardians", 3).ok)
	e.end_turn()
	while e.current() != foe:
		e.end_turn()
	var hp := foe.creature.hp
	var plan := e.ai.plan_turn(foe)
	assert_eq((plan["target"] as Combatant).id, archer.id, "not the cleric in her spirits")
	e.run_ai_turn()
	assert_eq(foe.creature.hp, hp)
	assert_true(e.distance(foe, archer) < e.distance(foe, cleric))


func test_it_leaves_an_area_it_starts_in() -> void:
	# Beside Silvain in the daggers, it could swing at him without moving and take the daggers again as its turn ends;
	# Ilse stands clear of them within its reach this turn.
	var e := TestCombat.open_field(6)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(2, 3))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(8, 3))
	var foe := TestCombat.foe(e, "berserker", Vector2i(3, 3))
	TestCombat.start_with(e, hero)
	var cloud := _daggers(e, hero, _block(Vector2i(0, 1), Vector2i(4, 5)))
	while e.current() != foe:
		e.end_turn()
	foe.disengaged = true   # no parting swing to muddy the count
	var plan := e.ai.plan_turn(foe)
	assert_eq((plan["target"] as Combatant).id, ilse.id, "not Silvain, from inside the daggers")
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_false(foe.cell in cloud.cells, "out of the daggers before its turn ends: %s" % foe.cell)
	assert_eq(foe.creature.hp, hp, "walking out of an area doesn't hurt, and it didn't end its turn there")
	assert_eq(e.distance(foe, ilse), 5)


func test_with_no_way_round_it_pushes_on_through_rather_than_turning_back() -> void:
	# A long corridor full of daggers: stepping back out of them never reaches the hero at the far end.
	var e := TestCombat.encounter(["##########################", "#........................#", "##########################"], 6)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(24, 1))
	var foe := TestCombat.foe(e, "berserker", Vector2i(5, 1))
	TestCombat.start_with(e, foe)
	_daggers(e, hero, _row(1, 3, 21))
	e.run_ai_turn()
	assert_true(foe.cell.x > 5, "on down the corridor: %s" % foe.cell)


func test_a_coward_flees_round_the_area_too() -> void:
	var e := TestCombat.encounter(["........", "........", "........", "........", "........"], 2)
	var hero := TestCombat.caster_with(e, ["cloud_of_daggers"], Vector2i(3, 2))
	var bandit := TestCombat.foe(e, "bandit", Vector2i(4, 2))
	TestCombat.start_with(e, bandit)
	bandit.creature.hp = 4   # Bloodied: the coward runs
	var cloud := _daggers(e, hero, _block(Vector2i(6, 0), Vector2i(7, 4)))
	var hp := bandit.creature.hp
	bandit.disengaged = true   # no parting swing to muddy the count
	e.run_ai_turn()
	assert_false(bandit.cell in cloud.cells, "the far squares are the daggers: it stops short of them, %s" % bandit.cell)
	assert_eq(bandit.creature.hp, hp)


func test_the_autopilot_walks_a_hero_round_a_foes_area() -> void:
	var e := TestCombat.encounter(LOOP, 3)
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(1, 3), 5)
	var druid := TestCombat.foe(e, "druid", Vector2i(11, 3))
	# No bow to shoot down the corridor with: she has to walk.
	(ilse.creature as Character).unequip_item("shortbow")
	(ilse.creature as Character).remove_one("shortbow")
	TestCombat.start_with(e, ilse)
	_daggers(e, druid, _row(3, 4, 7))
	var hp := ilse.creature.hp
	PartyAutopilot.new(e).play(ilse)
	assert_eq(ilse.creature.hp, hp)
	assert_eq(ilse.cell.y, 1, "the loop: %s" % ilse.cell)


func test_spike_growth_hides_from_those_who_didnt_see_it_cast() -> void:
	var e := TestCombat.open_field(7)
	var hero := TestCombat.caster_with(e, ["spike_growth"], Vector2i(0, 4))
	var saw := TestCombat.foe(e, "berserker", Vector2i(11, 2))
	var missed := TestCombat.foe(e, "berserker", Vector2i(11, 6))
	TestCombat.start_with(e, hero)
	missed.creature.add_condition(&"blinded", "test")
	assert_true(e.spells.cast(hero, "spike_growth", 2, [], Vector2(5, 4)).ok)
	missed.creature.remove_condition(&"blinded", "test")
	var spikes := e.spells.zones.live()[0]
	assert_true(e.ai.hazards.knows(saw, spikes), "saw the ground sprout")
	assert_false(e.ai.hazards.knows(missed, spikes), "camouflaged: looks like plain ground")
	assert_true(e.ai.hazards.read(missed) == null)
	assert_true(e.ai.hazards.knows(hero, spikes), "its caster knows")
	# Hurt by it, it knows from then on.
	e.end_turn()
	while e.current() != missed:
		e.end_turn()
	var inside := spikes.cells[0]
	for cell in spikes.cells:
		if cell.x > inside.x:
			inside = cell
	var hp := missed.creature.hp
	missed.movement_left = 60
	e.move(missed, inside)
	assert_true(missed.creature.hp < hp, "the spikes")
	assert_true(e.ai.hazards.knows(missed, spikes), "now it knows")


func test_found_traps_and_fire_on_the_floor_are_walked_round() -> void:
	var e := TestCombat.encounter([".........", ".........", "........."], 3)
	var hero := TestCombat.hero(e, "ilse_varga", Vector2i(8, 1))
	var foe := TestCombat.foe(e, "berserker", Vector2i(0, 1))
	e.traps.add({"id": "pit", "cells": [[2, 1]], "pit_ft": 10, "save": {"ability": "dex", "dc": 12}}, false)
	TestCombat.start_with(e, foe)
	assert_true(e.ai.hazards.read(foe) == null, "a trap no one has found isn't known")
	e.traps.list[0]["found"] = true
	assert_true(e.ai.hazards.read(foe).avoid.has(Vector2i(2, 1)), "a found one is")
	e.objects.burning_square(Vector2i(4, 1), "Coals")
	var v := e.ai.hazards.read(foe)
	assert_true(v.avoid.has(Vector2i(4, 1)), "and so is fire on the floor")
	var hp := foe.creature.hp
	e.run_ai_turn()
	assert_false(bool(e.traps.list[0]["sprung"]), "round the pit")
	assert_eq(foe.creature.hp, hp, "round the coals")
	assert_eq(e.distance(foe, hero), 5, "and up to Ilse")
