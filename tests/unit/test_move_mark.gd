extends TestCase
## Moving Hex or Hunter's Mark (2024: once the target drops to 0 Hit Points, a Bonus Action on a later turn moves it to
## a new creature, no slot, Concentration carrying on; owner question 2026-10-12): the hotbar slot shows only then, Hex's
## ability curse goes with it, Hunter's Mark needs a quarry the caster can see, and the AI moves a mark too.


func _to_next_turn_of(e: Encounter, c: Combatant) -> void:
	e.end_turn()
	while e.current() != c:
		e.end_turn()


func _move_slot(e: Encounter, c: Combatant, label: String) -> Dictionary:
	for a in ActionCatalog.new(e).actions_for(c):
		if str(a["label"]) == label:
			return a
	return {}


func test_move_hex_waits_for_the_target_to_drop_and_the_curse_goes_along() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3))
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var b := TestCombat.punching_bag(e, Vector2i(3, 5), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hex", 1, [a], Vector2.INF, Vector2.ZERO, {"choice": "str"}).ok)
	var conc := c.creature.concentration
	_to_next_turn_of(e, c)
	assert_true(_move_slot(e, c, "Move Hex").is_empty(), "no Move Hex on the bar while the hexed creature is up")
	a.creature.hp = 0
	a.creature.dead = true
	var slot := _move_slot(e, c, "Move Hex")
	assert_false(slot.is_empty(), "once it drops, Move Hex is on the bar")
	assert_eq(str(slot["cost"]), "bonus", "a Bonus Action")
	assert_true(bool(slot["legal"]), str(slot["reason"]))
	var slots := (c.creature as Character).slots_left(1)
	assert_true(ActionCatalog.new(e).perform(c, slot, [b]).ok)
	assert_eq(str(c.creature.modifiers_for(&"extra_damage")[0].data["vs"]), b.id, "the extra Necrotic follows to the new creature")
	assert_true(b.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "hex" and fx.modifiers.any(
		func(m: Modifier) -> bool: return str(m.data.get("on", "")).begins_with("check:"))), "and so does the curse on its Strength checks")
	assert_false(c.bonus_available, "the Bonus Action is spent")
	assert_eq((c.creature as Character).slots_left(1), slots, "no spell slot")
	assert_true(c.creature.concentration == conc and not conc.ended, "the same Concentration carries on")
	conc.end("test")
	assert_false(b.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == "hex"), "and ending it lifts the moved curse")


func test_hunters_mark_needs_a_quarry_it_can_see() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["hunters_mark"], Vector2i(2, 3), 9, "thistle")
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var b := TestCombat.punching_bag(e, Vector2i(3, 5), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hunters_mark", 1, [a]).ok)
	_to_next_turn_of(e, c)
	a.creature.hp = 0
	a.creature.dead = true
	b.creature.add_condition(&"invisible", "test")
	var mv := e.spells.sustained_for(c, "hunters_mark")
	var r := e.spells.use_sustained(c, str(mv["id"]), [b])
	assert_false(r.ok, "can't mark what it can't see")
	b.creature.remove_condition(&"invisible")
	assert_true(e.spells.use_sustained(c, str(mv["id"]), [b]).ok)
	assert_eq(str(c.creature.modifiers_for(&"extra_damage")[0].data["vs"]), b.id)


func test_the_ai_moves_its_mark_to_the_nearest_foe() -> void:
	var e := TestCombat.open_field(4)
	var c := TestCombat.caster_with(e, ["hex"], Vector2i(2, 3))
	c.controller = &"ai"
	var a := TestCombat.punching_bag(e, Vector2i(3, 3), 200)
	var near := TestCombat.punching_bag(e, Vector2i(4, 3), 200)
	TestCombat.punching_bag(e, Vector2i(12, 7), 200)
	TestCombat.start_with(e, c)
	assert_true(e.spells.cast(c, "hex", 1, [a], Vector2.INF, Vector2.ZERO, {"choice": "dex"}).ok)
	_to_next_turn_of(e, c)
	a.creature.hp = 0
	a.creature.dead = true
	e.ai.begin_turn(c)
	assert_eq(str(c.creature.modifiers_for(&"extra_damage")[0].data["vs"]), near.id, "moved to the nearest foe it can see")
	assert_false(c.bonus_available)
