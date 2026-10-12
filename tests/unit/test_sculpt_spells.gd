extends TestCase
## Sculpt Spells (Evoker 6; SpellSaves, the combat view's TargetPicker): an Evoker's Evocation spell shields up to 1 + its
## level creatures in it, who succeed on their saves and take no damage. The player picks them as the spell goes off,
## starting from the caster and its allies nearest it; the AI shields those. House rule (Ashwin, 2026-10-12): the
## caster can be one of them, where the 2024 text says "other creatures".


func _evoker(e: Encounter, cell: Vector2i, wizard_subclass: String = "evoker") -> Combatant:
	var ch := TestChars.custom("wizard", "human", 7, {"wizard_subclass": [wizard_subclass],
		"wizard.cantrips": ["thunderclap", "fire_bolt", "mage_hand"]})
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: String in ["fireball", "burning_hands"]:
		if not s in prepared:
			prepared.append(s)
	ch.finish_long_rest()
	return e.add(ch, &"party", cell)


## An ally who fails every save (so a spell it isn't shielded from always hurts it), with plenty of Hit Points.
func _ally(e: Encounter, cell: Vector2i) -> Combatant:
	return e.add(TestChars.dummy(120, false, {"type": "humanoid", "ac": 1,
		"abilities": {"str": 1, "dex": 1, "con": 1, "int": 1, "wis": 1, "cha": 1}}), &"party", cell)


func _ids(list: Array) -> Array:
	return list.map(func(o: Variant) -> String: return (o as Combatant).id)


func test_fireball_spares_whoever_the_player_picks_the_caster_too() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(2, 2))
	var a1 := _ally(e, Vector2i(5, 2))
	var a2 := _ally(e, Vector2i(5, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var hp := {c.id: c.creature.hp, a1.id: a1.creature.hp, a2.id: a2.creature.hp, foe.id: foe.creature.hp}
	var r := e.spells.cast(c, "fireball", 3, [], Vector2(4.5, 3.5), Vector2.ZERO, {"sculpt": [c.id, a1.id]})
	assert_true(r.ok, r.reason)
	assert_eq(c.creature.hp, int(hp[c.id]), "the Evoker shields itself (house rule)")
	assert_eq(a1.creature.hp, int(hp[a1.id]), "the ally picked")
	assert_true(a2.creature.hp < int(hp[a2.id]), "the ally left out burns")
	assert_true(foe.creature.hp < int(hp[foe.id]))


func test_without_picks_the_caster_and_the_nearest_allies_up_to_one_plus_the_level() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(2, 3))
	var near: Array[Combatant] = [_ally(e, Vector2i(3, 3)), _ally(e, Vector2i(4, 3)), _ally(e, Vector2i(5, 3))]
	var far := _ally(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var start := far.creature.hp
	var hp := near.map(func(o: Combatant) -> int: return o.creature.hp)
	var me := c.creature.hp
	assert_true(e.spells.cast(c, "fireball", 3, [], Vector2(4.5, 3.5), Vector2.ZERO).ok)
	assert_eq(c.creature.hp, me)
	for i in near.size():
		assert_eq(near[i].creature.hp, int(hp[i]), "%d of the 4 a level 3 Fireball shields" % (i + 2))
	assert_true(far.creature.hp < start, "the fifth burns")


func test_the_pick_starts_from_the_caster_and_its_allies_and_keeps_to_the_cap() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(2, 2))
	var a1 := _ally(e, Vector2i(4, 2))
	var a2 := _ally(e, Vector2i(5, 4))
	var foe := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:fireball")
	var picker := TargetPicker.new(e)
	assert_true(picker.sculpt(c, a, Vector2(4.5, 3.5), Vector2.ZERO, 1 + 1 + 1), "allies caught: ask")
	assert_eq(picker.step, "sculpt")
	assert_eq(_ids(picker._sculpt_picks), [c.id, a1.id, a2.id], "the caster first, then its allies nearest it")
	assert_true(picker.candidate(foe), "any creature in it can be shielded")
	assert_true(picker.pick(foe.cell, foe).is_empty(), "a fourth: the cap at level 3 is 4")
	var pet := _ally(e, Vector2i(5, 3))
	picker.reset()
	assert_true(picker.sculpt(c, a, Vector2(4.5, 3.5), Vector2.ZERO, 3))
	assert_eq(picker._sculpt_picks.size(), 4, "already at the cap")
	assert_eq(str(picker.pick(foe.cell, foe)["do"]), "refuse", "no fifth")
	assert_true(picker.pick(pet.cell, pet).is_empty(), "a click takes one back")
	assert_true(picker.pick(c.cell, c).is_empty())
	assert_eq(_ids(picker._sculpt_picks), [a1.id, a2.id], "the caster unpicked too")
	var shown := picker.show(c.cell, c)
	assert_true(str(shown["title"]).contains("2 of 4"), str(shown["title"]))
	var cmd := picker.confirm()
	assert_eq(str(cmd["do"]), "perform")
	assert_eq(((cmd["action"] as Dictionary)["opts"] as Dictionary)["sculpt"], [a1.id, a2.id])
	var me := c.creature.hp
	var r := cat.perform(c, cmd["action"] as Dictionary, cmd["targets"] as Array, cmd["point"] as Vector2, cmd["dir"] as Vector2, 3)
	assert_true(r.ok, r.reason)
	for i in 10:
		if e.pending == null:
			break
		e.answer_reaction(false)   # a reroll offered for the Evoker's own save, declined
	assert_true(c.creature.hp < me, "left out of the picks, the Evoker burns")


func test_no_question_with_only_foes_in_it_or_from_a_wizard_who_isnt_an_evoker() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(0, 0))
	_ally(e, Vector2i(1, 0))
	TestCombat.punching_bag(e, Vector2i(9, 6))
	var other := _evoker(e, Vector2i(0, 7), "abjurer")
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var picker := TargetPicker.new(e)
	assert_false(picker.sculpt(c, cat.find(c, "spell:fireball"), Vector2(9.5, 6.5), Vector2.ZERO, 3), "only a foe: just cast")
	assert_false(picker.sculpt(other, cat.find(other, "spell:fireball"), Vector2(0.5, 6.5), Vector2.ZERO, 3), "no Sculpt Spells")
	assert_false(picker.active())


func test_a_cone_asks_after_its_aim_and_a_spell_from_the_caster_asks_at_once() -> void:
	var e := TestCombat.open_field()
	var c := _evoker(e, Vector2i(2, 3))
	var ally := _ally(e, Vector2i(3, 3))
	TestCombat.start_with(e, c)
	var cat := ActionCatalog.new(e)
	var picker := TargetPicker.new(e)
	var hands := cat.find(c, "spell:burning_hands")
	assert_true(picker.begin(c, hands, 1) == hands and not picker.active(), "Burning Hands is aimed first")
	assert_true(picker.sculpt(c, hands, Vector2.INF, Vector2.RIGHT, 1), "the ally in the cone")
	assert_false(picker.candidate(c), "the caster isn't in its own cone")
	assert_true(picker.undo() and not picker.active(), "Backspace: aim again")
	var clap := cat.find(c, "spell:thunderclap")
	assert_eq(str(clap["targeting"]), "none")
	assert_true(picker.takes(c, clap), "Thunderclap with an ally beside the caster")
	picker.begin(c, clap, 0)
	assert_eq(picker.step, "sculpt")
	assert_eq(_ids(picker._sculpt_picks), [ally.id], "a cantrip shields one")
	assert_false(picker.undo(), "no aim to go back to: Backspace cancels")
