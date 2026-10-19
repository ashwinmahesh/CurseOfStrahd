extends TestCase
## Spells that items give (story/item_spells.gd, Ashwin, 2026-10-19): the character sheet lists the spells of the items a hero
## has working, marked with the item and what it has left, and casts them outside a fight through FieldItems.use, so charges,
## daily uses and the item's own rules apply. Only a worn or held, attuned (where it asks) item counts.


## The staffs are built on a quarterstaff (a template with one base), so they are carried under these ids.
const STAFF := "staff_of_healing__quarterstaff"
const FIRE := "staff_of_fire__quarterstaff"


func _party() -> StoryState:
	var st := StoryState.new()
	var cleric := TestChars.custom("cleric", "human", 9)
	cleric.finish_long_rest()
	var fighter := TestChars.pregen("ilse_varga", 5)
	st.party.append(cleric)
	st.party.append(fighter)
	return st


func _list(st: StoryState, ch: Character) -> Array[Dictionary]:
	return ItemSpells.entries(st, ch, DiceRoller.new(1))


func _of(st: StoryState, ch: Character, item_id: String, power_id: String) -> Dictionary:
	return ItemSpells.find(_list(st, ch), item_id, power_id)


func _staff(ch: Character) -> void:
	ch.add_item(STAFF)
	ch.equip(STAFF, "main_hand")
	assert_true(ch.attune(STAFF), "a cleric attunes to it")


# --- What is listed -------------------------------------------------------------------------------

func test_only_a_working_item_gives_its_spells() -> void:
	var st := _party()
	var cleric := st.party[0]
	cleric.add_item(STAFF)
	assert_true(_list(st, cleric).is_empty(), "in the pack")
	cleric.equip(STAFF, "main_hand")
	assert_true(_list(st, cleric).is_empty(), "held but not attuned")
	assert_true(cleric.attune(STAFF))
	var ids: Array[String] = []
	for o in _list(st, cleric):
		ids.append(str(o["spell_id"]))
		assert_eq(str(o["item_name"]), "Staff of Healing")
	assert_eq(ids, ["cure_wounds", "lesser_restoration", "mass_cure_wounds"])
	cleric.unequip_item(STAFF)
	assert_true(_list(st, cleric).is_empty(), "taken out of the hand, its spells go")
	cleric.equip(STAFF, "main_hand")
	cleric.end_attunement(STAFF)
	assert_true(_list(st, cleric).is_empty(), "attunement ended")


func test_charges_and_what_a_spell_costs() -> void:
	var st := _party()
	var cleric := st.party[0]
	_staff(cleric)
	var left := cleric.charges_left(STAFF)
	var cure := _of(st, cleric, STAFF, "cure_wounds")
	assert_eq(str(cure["kind"]), "charges")
	assert_eq(str(cure["cost"]), "1 charge")
	assert_eq(str(cure["usage"]), "%d/10 charges" % left)
	assert_eq(str(cure["item_charges"]), "%d/10 charges" % left)
	assert_true(str(cure["cost_note"]).contains("per level"), str(cure["cost_note"]))
	assert_eq(cure["levels"], [1, 2, 3, 4], "charges buy a higher level")
	assert_eq((cure["level_costs"] as Dictionary)[3], 3)
	assert_eq(str(_of(st, cleric, STAFF, "mass_cure_wounds")["cost"]), "5 charges")


func test_at_will_and_once_a_day() -> void:
	var st := _party()
	var cleric := st.party[0]
	cleric.add_item("rod_of_alertness")
	cleric.equip("rod_of_alertness", "main_hand")
	assert_true(cleric.attune("rod_of_alertness"))
	var detect := _of(st, cleric, "rod_of_alertness", "detect_magic")
	assert_eq(str(detect["kind"]), "at_will")
	assert_eq(str(detect["usage"]), "At will")
	cleric.add_item("orb_of_dragonkind")
	assert_true(cleric.attune("orb_of_dragonkind"))
	var cure := _of(st, cleric, "orb_of_dragonkind", "cure_wounds")
	assert_eq(str(cure["kind"]), "uses")
	assert_eq(str(cure["usage"]), "1/1 left")
	assert_eq(str(cure["cost"]), "once a day")
	assert_eq(str(cure["recharge"]), "at dawn")
	assert_eq(int(cure["level"]), 9, "the orb casts it at level 9")


func test_a_spell_with_nothing_to_do_outside_a_fight_says_so() -> void:
	var st := _party()
	var wizard := TestChars.custom("wizard", "human", 7)
	wizard.finish_long_rest()
	st.party.append(wizard)
	wizard.add_item(FIRE)
	wizard.equip(FIRE, "main_hand")
	assert_true(wizard.attune(FIRE), "a wizard attunes to it")
	var fireball := _of(st, wizard, FIRE, "fireball")
	assert_false(bool(fireball["legal"]))
	assert_eq(str(fireball["reason"]), ItemSpells.FIGHT_ONLY)
	var charges := wizard.charges_left(FIRE)
	var res := ItemSpells.cast(st, wizard, FIRE, "fireball", [wizard], 0, "", DiceRoller.new(1))
	assert_false(bool(res["ok"]))
	assert_eq(str(res["text"]), ItemSpells.FIGHT_ONLY)
	assert_eq(wizard.charges_left(FIRE), charges, "nothing spent")


# --- Casting ---------------------------------------------------------------------------------------

func test_cure_wounds_from_the_staff_heals_and_spends_charges_for_its_level() -> void:
	var st := _party()
	var cleric := st.party[0]
	var fighter := st.party[1]
	_staff(cleric)
	fighter.hp = 1
	var charges := cleric.charges_left(STAFF)
	var res := ItemSpells.cast(st, cleric, STAFF, "cure_wounds", [fighter], 2, "", DiceRoller.new(4))
	assert_true(bool(res["ok"]), str(res))
	assert_true(fighter.hp > 1, "healed")
	assert_eq(cleric.charges_left(STAFF), charges - 2, "two charges for the second level")


func test_mass_cure_wounds_goes_on_several_at_once() -> void:
	var st := _party()
	var cleric := st.party[0]
	var fighter := st.party[1]
	_staff(cleric)
	cleric.hp = 2
	fighter.hp = 1
	var charges := cleric.charges_left(STAFF)
	var res := ItemSpells.cast(st, cleric, STAFF, "mass_cure_wounds", [cleric, fighter], 0, "", DiceRoller.new(4))
	assert_true(bool(res["ok"]), str(res))
	assert_true(cleric.hp > 2 and fighter.hp > 1, "both healed")
	assert_eq(cleric.charges_left(STAFF), charges - 5)


func test_too_few_charges_names_the_reason() -> void:
	var st := _party()
	var cleric := st.party[0]
	_staff(cleric)
	cleric.entry_of(STAFF)["charges"] = 2
	var mass := _of(st, cleric, STAFF, "mass_cure_wounds")
	assert_false(bool(mass["legal"]))
	assert_eq(str(mass["reason"]), "Not enough charges (2 left, needs 5)")
	var res := ItemSpells.cast(st, cleric, STAFF, "mass_cure_wounds", [cleric], 0, "", DiceRoller.new(1))
	assert_false(bool(res["ok"]))
	assert_eq(str(res["text"]), "Not enough charges (2 left, needs 5)")
	assert_eq(cleric.charges_left(STAFF), 2, "nothing spent")
	assert_eq(_of(st, cleric, STAFF, "cure_wounds")["levels"], [1, 2], "the levels the charges still reach")


func test_a_daily_use_is_spent_and_comes_back_at_dawn() -> void:
	var st := _party()
	var cleric := st.party[0]
	var fighter := st.party[1]
	cleric.add_item("orb_of_dragonkind")
	assert_true(cleric.attune("orb_of_dragonkind"))
	fighter.hp = 1
	var res := ItemSpells.cast(st, cleric, "orb_of_dragonkind", "cure_wounds", [fighter], 0, "", DiceRoller.new(4))
	assert_true(bool(res["ok"]), str(res))
	assert_true(fighter.hp > 1, "healed")
	var spent := _of(st, cleric, "orb_of_dragonkind", "cure_wounds")
	assert_eq(str(spent["usage"]), "0/1 left")
	assert_false(bool(spent["legal"]))
	assert_true(str(spent["reason"]).begins_with("Used"), str(spent["reason"]))
	fighter.hp = 1
	var again := ItemSpells.cast(st, cleric, "orb_of_dragonkind", "cure_wounds", [fighter], 0, "", DiceRoller.new(4))
	assert_false(bool(again["ok"]))
	assert_eq(fighter.hp, 1, "not healed twice")
	cleric.on_dawn(DiceRoller.new(1))
	assert_eq(str(_of(st, cleric, "orb_of_dragonkind", "cure_wounds")["usage"]), "1/1 left", "back at dawn")


func test_an_exploring_spell_is_recorded_for_the_world() -> void:
	var st := _party()
	var cleric := st.party[0]
	cleric.add_item("wand_of_magic_detection")
	cleric.equip("wand_of_magic_detection", "main_hand")
	var charges := cleric.charges_left("wand_of_magic_detection")
	var o := _of(st, cleric, "wand_of_magic_detection", "detect_magic")
	assert_true(bool(o["legal"]), str(o["reason"]))
	assert_false(bool(o["needs_target"]), "it goes on its caster")
	var res := ItemSpells.cast(st, cleric, "wand_of_magic_detection", "detect_magic", [], 0, "", DiceRoller.new(1))
	assert_true(bool(res["ok"]), str(res))
	assert_eq(str(res["effect"]), "detect_magic", "what the world shows")
	assert_true(st.active_spells.has("detect_magic"))
	assert_eq(cleric.charges_left("wand_of_magic_detection"), charges - 1)


func test_an_item_that_is_no_longer_worked_does_not_cast() -> void:
	var st := _party()
	var cleric := st.party[0]
	_staff(cleric)
	cleric.unequip_item(STAFF)
	var charges := cleric.charges_left(STAFF)
	var res := ItemSpells.cast(st, cleric, STAFF, "cure_wounds", [cleric], 0, "", DiceRoller.new(1))
	assert_false(bool(res["ok"]))
	assert_true(str(res["text"]).contains("worn or held"), str(res["text"]))
	assert_eq(cleric.charges_left(STAFF), charges)


func test_the_rod_of_resurrection_lists_the_dead_it_can_reach() -> void:
	var st := _party()
	var cleric := st.party[0]
	var fighter := st.party[1]
	cleric.add_item("rod_of_resurrection")
	cleric.equip("rod_of_resurrection", "main_hand")
	assert_true(cleric.attune("rod_of_resurrection"))
	var o := _of(st, cleric, "rod_of_resurrection", "resurrection")
	assert_false(bool(o["legal"]))
	assert_eq(str(o["reason"]), "Nobody in the party is dead")
	fighter.hp = 0
	fighter.dead = true
	st.advance_minutes(30 * 24 * 60)
	o = _of(st, cleric, "rod_of_resurrection", "resurrection")
	assert_true(bool(o["legal"]), str(o["reason"]))
	assert_eq(o["targets"], [fighter])
	var charges := cleric.charges_left("rod_of_resurrection")
	var res := ItemSpells.cast(st, cleric, "rod_of_resurrection", "resurrection", [fighter], 0, "", DiceRoller.new(1))
	assert_true(bool(res["ok"]), str(res))
	assert_false(fighter.dead, "brought back")
	assert_eq(cleric.charges_left("rod_of_resurrection"), charges - 5)


func test_a_ring_that_casts_on_its_wearer_only_offers_no_other_target() -> void:
	var st := _party()
	var cleric := st.party[0]
	cleric.add_item("ring_of_jumping")
	assert_true(cleric.wear("ring_of_jumping"))
	assert_true(cleric.attune("ring_of_jumping"))
	var o := _of(st, cleric, "ring_of_jumping", "jump")
	assert_true(bool(o["self_only"]), "the ring's Jump is for its wearer (2024 DMG)")
	assert_eq(str(o["kind"]), "at_will")
