extends TestCase
## The Holy Symbol of Ravenkind is a Holy Symbol (owner, 2026-10-18): a Cleric or Paladin (a class whose spellcasting
## names a holy focus) has it as their spellcasting focus when it sits in the focus slot or in a hand, as they would a
## Reliquary; a class with another focus, or none, does not gain it. Its own powers and its attunement ("by a Cleric or
## Paladin") are as they were. The rules don't ask for a focus in a fight (it is assumed carried, deviations.md): this is
## the character's own record of it, on the doll and in Turn Undead's log line.

const RAVEN := "holy_symbol_of_ravenkind"


func _with_raven(pregen: String, level: int = 5) -> Character:
	var ch := TestChars.pregen(pregen, level)
	ch.add_item(RAVEN)
	return ch


func test_the_symbol_is_a_holy_focus_item_and_goes_in_the_focus_slot() -> void:
	var data := Compendium.shared().item_data(RAVEN)
	assert_eq(Gear.focus_kind(data), "holy")
	assert_eq(Gear.carry_slot(data), "focus", "the doll's focus slot takes it")
	assert_true(InventoryScreen.slot_takes("focus", Compendium.shared().item_data(RAVEN)), "and the pack offers it")
	assert_true(InventoryScreen.slot_takes("main_hand", data), "a hand takes it as before")


func test_a_cleric_has_it_as_a_holy_focus_from_the_focus_slot_or_a_hand() -> void:
	var ch := _with_raven("hedda_ironvow")
	assert_true("holy" in ch.focus_kinds(), "a Cleric's focus is holy")
	ch.unequip_item(ch.held_id("focus"))   # their own holy symbol is put away: nothing else to hand
	assert_false(ch.has_focus("holy"), "carried in the pack, it is not to hand")
	assert_true(ch.equip(RAVEN, "focus"))
	assert_true(ch.has_focus("holy"), "in the focus slot")
	assert_eq(ch.focus_item("holy"), RAVEN)
	ch.unequip_item(RAVEN)
	assert_true(ch.equip(RAVEN, "off_hand"))
	assert_true(ch.has_focus("holy"), "or held in a hand")
	assert_false(ch.has_focus("arcane"), "it is no other kind of focus")
	assert_false(ch.has_focus("druidic"))


func test_a_paladin_has_it_too() -> void:
	var ch := _with_raven("godrick_pendlebrook")
	assert_true("holy" in ch.focus_kinds(), "a Paladin's focus is holy")
	assert_true(ch.equip(RAVEN, "focus"))
	assert_true(ch.has_focus("holy"))


func test_a_class_without_a_holy_focus_does_not_gain_it() -> void:
	for pregen: String in ["ratatoille", "kip_smudgewick", "ilse_varga", "thistle", "wren_featherfoot"]:   # Wizard, Warlock, Fighter, Ranger, Monk
		var ch := _with_raven(pregen)
		assert_false("holy" in ch.focus_kinds(), "%s has no holy focus" % pregen)
		ch.equip(RAVEN, "focus")
		ch.equip(RAVEN, "off_hand")
		assert_false(ch.has_focus("holy"), "%s doesn't gain the Holy Symbol as a focus" % pregen)
		assert_eq(ch.focus_item("holy"), "")
		assert_false(ch.has_focus("arcane") and ch.focus_item("arcane") == RAVEN, "nor does it stand in for their own focus")


func test_a_cleric_does_not_count_an_arcane_focus_as_theirs() -> void:
	var ch := TestChars.pregen("hedda_ironvow", 5)
	ch.add_item("arcane_focus_orb")
	ch.equip("arcane_focus_orb", "focus")
	assert_false(ch.has_focus("arcane"), "a Cleric has no arcane focus")
	assert_false(ch.has_focus("holy"), "and an Orb is not a holy symbol")


func test_its_attunement_and_powers_are_as_they_were() -> void:
	var cleric := _with_raven("hedda_ironvow")
	var wizard := _with_raven("ratatoille")
	assert_true(wizard.attune_blocker(RAVEN).begins_with("Requires attunement"), "a Wizard still cannot attune: %s" % wizard.attune_blocker(RAVEN))
	assert_eq(cleric.attune_blocker(RAVEN), "", "a Cleric can")
	assert_true(cleric.attune(RAVEN))
	assert_true(cleric.equip(RAVEN, "focus"))
	assert_true(cleric.item_active(cleric.entry_of(RAVEN)), "attuned and kept in the focus slot, it works as a held item does")
	var powers := MagicItems.powers_of(Compendium.shared().item_data(RAVEN))
	assert_eq(powers.size(), 2, "Hold Vampires and Sunlight")
	assert_eq(int(MagicItems.charges(Compendium.shared().item_data(RAVEN)).get("max", 0)), 10, "its ten charges")


func test_a_held_item_that_needs_a_hand_is_not_put_in_the_focus_slot_on_its_own() -> void:
	# A character whose doll is filled for the first time (an old save) gets a focus it can leave there, not the symbol.
	var ch := TestChars.pregen("hedda_ironvow", 5)
	ch.unequip_item(ch.held_id("focus"))
	for e in ch.inventory:
		if Gear.carry_slot(Compendium.shared().item_data(str(e["id"]))) == "focus" and str(e["id"]) != RAVEN:
			e["qty"] = 0
	ch.add_item(RAVEN)
	ch.seed_doll()
	assert_eq(ch.held_id("focus"), "", "the Holy Symbol of Ravenkind stays in the pack until its bearer puts it there")


func test_turn_undead_names_the_symbol_a_cleric_holds_up() -> void:
	var e := TestCombat.open_field(6)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	var ch := h.creature as Character
	ch.add_item(RAVEN)
	ch.equip(RAVEN, "focus")
	TestCombat.foe(e, "zombie", Vector2i(5, 3))
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 3)
	assert_true(e.features.turn_undead(h).ok)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("presents the Holy Symbol of Ravenkind: Turn Undead")), str(e.log.texts()))


func test_turn_undead_with_an_ordinary_symbol_reads_as_before() -> void:
	var e := TestCombat.open_field(6)
	var h := TestCombat.hero(e, "hedda_ironvow", Vector2i(3, 3))
	TestCombat.foe(e, "zombie", Vector2i(5, 3))
	TestCombat.start_with(e, h)
	TestCombat.next_d20(e, 3)
	assert_true(e.features.turn_undead(h).ok)
	assert_true(e.log.texts().any(func(t: String) -> bool: return t.contains("presents a holy symbol: Turn Undead")), str(e.log.texts()))
