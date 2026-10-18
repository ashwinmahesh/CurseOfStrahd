extends TestCase
## Armor Training (2024): armor a caster has no training with gives Disadvantage on Strength and Dexterity D20 Tests and
## no spellcasting. Owner report 2026-10-18: Liriel Dawnsong, a Thaumaturge Cleric with no Heavy armor training, was
## wearing Plate Armor +1 and "can't cast any spells for some reason": the rule shut every spell, and the reason showed
## only on hover as "Wearing armor without training". Now the reason names the armor (Character.armor_cast_blocker),
## whatever casts: every spell slot, a Reaction's offer and the cast itself.

const PLATE := "armor_plus_1__plate_armor"


func _plate_name() -> String:
	return str(Compendium.shared().item_data(PLATE).get("name", PLATE))


## Liriel at level 5 (a Thaumaturge: Light and Medium armor and Shields, no Heavy) wearing Plate Armor +1.
func _liriel_in_plate(e: Encounter) -> Combatant:
	var c := TestCombat.hero(e, "liriel_dawnsong", Vector2i(3, 3), 5)
	var ch := c.creature as Character
	ch.add_item(PLATE)
	assert_true(ch.equip(PLATE, "armor"), "the plate goes on")
	return c


func _spell(e: Encounter, c: Combatant, id: String) -> Dictionary:
	for s in e.spells.castable(c):
		if str(s["id"]) == id:
			return s
	return {}


func test_the_premise_a_thaumaturge_has_no_heavy_armor_training() -> void:
	var ch := TestChars.pregen("liriel_dawnsong", 5)
	assert_false(ch.has_armor_training("heavy"), "Thaumaturge, not Protector")
	assert_true(ch.has_armor_training("medium"), "a Cleric wears Medium armor")
	assert_true(ch.untrained_armor().is_empty(), "and what she starts in suits her")
	assert_eq(ch.armor_cast_blocker(), "")


func test_untrained_armor_shuts_every_spell_and_the_reason_names_it() -> void:
	var e := TestCombat.open_field()
	var c := _liriel_in_plate(e)
	var foe := TestCombat.foe(e, "zombie", Vector2i(5, 3))
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	var why := "Wearing %s without training" % _plate_name()
	for id: String in ["sacred_flame", "guiding_bolt", "cure_wounds", "bless"]:
		var s := _spell(e, c, id)
		assert_false(s.is_empty(), "%s is one of her spells" % id)
		assert_false(bool(s["legal"]), "%s can't be cast in the plate" % id)
		assert_eq(str(s["reason"]), why, "%s says which armor" % id)
	var r := e.spells.cast(c, "sacred_flame", 0, [foe])
	assert_false(r.ok, "casting it anyway does nothing")
	assert_eq(r.reason, why, "and says the same")
	assert_eq(ch.armor_cast_blocker(), why, "the one reason behind them all")
	assert_eq(str(ch.untrained_armor().get("id", "")), PLATE)


func test_taking_it_off_or_wearing_trained_armor_gives_the_spells_back() -> void:
	var e := TestCombat.open_field()
	var c := _liriel_in_plate(e)
	TestCombat.start_with(e, c)
	var ch := c.creature as Character
	assert_false(bool(_spell(e, c, "sacred_flame")["legal"]))
	ch.unequip_item(PLATE)
	assert_eq(ch.armor_cast_blocker(), "", "bare, nothing stops her")
	assert_true(bool(_spell(e, c, "sacred_flame")["legal"]), "Sacred Flame is back")
	assert_true(bool(_spell(e, c, "cure_wounds")["legal"]), "and Cure Wounds")
	ch.add_item("breastplate")
	assert_true(ch.equip("breastplate", "armor"))
	assert_true(ch.untrained_armor().is_empty(), "a Cleric is trained in Medium armor")
	assert_true(bool(_spell(e, c, "guiding_bolt")["legal"]), "Guiding Bolt too")


func test_a_caster_trained_in_heavy_armor_casts_in_plate() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3), 5)   # a Protector Cleric: Heavy armor
	var ch := c.creature as Character
	assert_true(ch.has_armor_training("heavy"), "Hedda is trained in Heavy armor")
	ch.add_item(PLATE)
	assert_true(ch.equip(PLATE, "armor"))
	TestCombat.start_with(e, c)
	assert_eq(ch.armor_cast_blocker(), "")
	assert_true(bool(_spell(e, c, "sacred_flame")["legal"]), "she casts in the plate")


func test_a_reaction_spell_waits_on_the_same_rule() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.caster_with(e, ["shield"], Vector2i(3, 3), 5)   # a Wizard: no armor training at all
	var ch := c.creature as Character
	TestCombat.start_with(e, c)
	assert_true(e.spells.can_cast_reaction(c, "shield"), "unarmored, Shield is on offer")
	ch.add_item(PLATE)
	assert_true(ch.equip(PLATE, "armor"))
	assert_ne(ch.armor_cast_blocker(), "", "a Wizard in plate")
	assert_false(e.spells.can_cast_reaction(c, "shield"), "no Shield in armor they have no training with")
