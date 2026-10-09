extends TestCase
## Dice moments (owner 2026-10-09: the big emerald d20 only for the heroes' saving throws, death saves included):
## CombatView._hero_saves picks them out of the creatures' d20 events, each once.


func test_only_the_heroes_saves_are_picked_once_each() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var view := CombatView.new()
	view.e = e
	view._hero_saves()   # whatever the start rolled
	ilse.creature.roll_save(e.dice, &"con", 12)
	z.creature.roll_save(e.dice, &"wis", 12)
	ilse.creature.roll_d20(e.dice, D20Test.Kind.ABILITY_CHECK, Breakdown.new("Athletics"), 10, [] as Array[String])
	var saves := view._hero_saves()
	assert_eq(saves.size(), 1, "Ilse's save, not the zombie's or her check")
	assert_eq(saves[0]["who"], ilse)
	assert_true(view._hero_saves().is_empty(), "each one shows once")
	ilse.creature.hp = 0
	ilse.creature.roll_death_save_d20(e.dice)
	var ds := view._hero_saves()
	assert_eq(ds.size(), 1, "a death save is a saving throw too")
	assert_true((ds[0]["test"] as D20Test).label.begins_with("Death save"))
	view.free()
