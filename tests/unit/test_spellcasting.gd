extends TestCase
## Spell slots (single class, third casters, multiclass), cantrip scaling and upcasting (2024 PHB).


func test_full_caster_table() -> void:
	assert_eq(Spellcasting.slots_for_caster_level(1), [2, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int])
	assert_eq(Spellcasting.slots_for_caster_level(5), [4, 3, 2, 0, 0, 0, 0, 0, 0] as Array[int])
	assert_eq(Spellcasting.slots_for_caster_level(9), [4, 3, 3, 3, 1, 0, 0, 0, 0] as Array[int])
	assert_eq(Spellcasting.slots_for_caster_level(20), [4, 3, 3, 3, 3, 2, 2, 1, 1] as Array[int])


func test_third_caster_alone_rounds_up() -> void:
	var ek := func(level: int) -> Array[int]: return Spellcasting.slots_for([{"progression": "third", "level": level}])
	assert_eq(ek.call(3), [2, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int])
	assert_eq(ek.call(4), [3, 0, 0, 0, 0, 0, 0, 0, 0] as Array[int], "EK 4 has three level 1 slots")
	assert_eq(ek.call(7), [4, 2, 0, 0, 0, 0, 0, 0, 0] as Array[int])
	assert_eq(ek.call(19), [4, 3, 3, 1, 0, 0, 0, 0, 0] as Array[int])


func test_multiclass_rounds_third_casters_down() -> void:
	var slots := Spellcasting.slots_for([{"progression": "third", "level": 3}, {"progression": "full", "level": 2}])
	assert_eq(slots, [4, 2, 0, 0, 0, 0, 0, 0, 0] as Array[int], "floor(3/3) + 2 = caster level 3")
	var half := Spellcasting.slots_for([{"progression": "half", "level": 5}, {"progression": "full", "level": 1}])
	assert_eq(half, [4, 3, 0, 0, 0, 0, 0, 0, 0] as Array[int], "ceil(5/2) + 1 = caster level 4")


func test_cantrip_scaling() -> void:
	var bolt := Compendium.shared().spell_data("fire_bolt")
	assert_eq(Spellcasting.damage_dice(bolt, 1), "1d10")
	assert_eq(Spellcasting.damage_dice(bolt, 4), "1d10")
	assert_eq(Spellcasting.damage_dice(bolt, 5), "2d10")
	assert_eq(Spellcasting.damage_dice(bolt, 11), "3d10")
	assert_eq(Spellcasting.damage_dice(bolt, 17), "4d10")


func test_upcasting() -> void:
	var fireball := Compendium.shared().spell_data("fireball")
	assert_eq(Spellcasting.damage_dice(fireball, 5, 3), "8d6")
	assert_eq(Spellcasting.damage_dice(fireball, 9, 5), "10d6")
	var cure := Compendium.shared().spell_data("cure_wounds")
	assert_eq(Spellcasting.heal_dice(cure, 1), "2d8")
	assert_eq(Spellcasting.heal_dice(cure, 3), "6d8")


func test_wizard_cannot_prepare_spells_above_its_slots() -> void:
	var wiz := TestChars.pregen("silvain_aster", 1)
	var book := wiz.choice("wizard.spellbook")
	ChoiceOptions.populate(book, wiz)
	var fb := book.option("fireball")
	assert_false(fb.legal)
	assert_eq(fb.reason, "Needs level 3 spell slots")
	assert_true(book.option("magic_missile").legal)


func test_prepared_spells_come_from_the_spellbook() -> void:
	var wiz := TestChars.pregen("silvain_aster", 1)
	var prepared := wiz.choice("wizard.prepared")
	ChoiceOptions.populate(prepared, wiz)
	var ids: Array[String] = []
	for o in prepared.options:
		ids.append(o.id)
	ids.sort()
	var book: Array[String] = ["burning_hands", "mage_armor", "magic_missile", "shield", "sleep", "thunderwave"]
	assert_eq(ids, book)
