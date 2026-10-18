extends TestCase
## The Arcane Grimoire is a Wizard's Spellcasting Focus, not a spellbook (owner, 2026-10-18). Attuned by a Wizard, it is
## a focus for Wizard spells; while it is held (in a hand or kept as the focus) those spells gain its +1, +2 or +3 to
## spell attack rolls and save DCs, and Arcane Recovery brings back one more slot level. It holds no spells, so nothing
## can be copied out of it (tests/unit/test_spellbook_loot.gd keeps the real spellbooks honest).

const IDS: Array[String] = ["arcane_grimoire_plus_1", "arcane_grimoire_plus_2", "arcane_grimoire_plus_3"]
const RARITIES: Array[String] = ["uncommon", "rare", "very_rare"]


func _wizard(level: int = 5) -> Character:
	return TestChars.pregen("ratatoille", level)


func test_the_data_is_a_focus_for_wizards_and_holds_no_spells() -> void:
	for i in IDS.size():
		var data := Compendium.shared().item_data(IDS[i])
		assert_false(data.has("spells"), "%s holds no spells: it is not a spellbook" % IDS[i])
		assert_eq(Gear.focus_kind(data), "arcane", "%s is an arcane focus" % IDS[i])
		assert_eq(Gear.carry_slot(data), "focus", "it goes in the doll's focus slot")
		assert_true(MagicItems.is_held(data), "and works while held")
		assert_eq(MagicItems.attunement_text(data), "by a Wizard")
		assert_eq(MagicItems.rarity(data), RARITIES[i])
		var bonuses := (data["modifiers"] as Array).filter(func(m: Dictionary) -> bool: return str(m["stat"]) in ["spell_attack", "spell_dc"])
		assert_eq(bonuses.size(), 2, "a spell attack bonus and a save DC bonus")
		for m: Dictionary in bonuses:
			assert_eq(int(m["value"]), i + 1, "+%d by its rarity" % (i + 1))
			assert_eq((m["when"] as Dictionary).get("spell_class", ""), "wizard", "to Wizard spells")


func test_it_adds_its_bonus_to_wizard_spells_while_held_or_kept_as_the_focus() -> void:
	for i in IDS.size():
		var id := IDS[i]
		var ch := _wizard()
		var dc := ch.spell_save_dc("wizard").total()
		var attack := ch.spell_attack_bonus("wizard").total()
		ch.add_item(id)
		assert_eq(ch.attune_blocker(id), "", "a Wizard can attune")
		assert_true(ch.attune(id))
		assert_eq(ch.spell_save_dc("wizard").total(), dc, "in the pack it adds nothing: nobody holds it")
		assert_true(ch.equip(id, "focus"))
		assert_eq(ch.focus_item("arcane"), id, "kept as the focus, it is the Wizard's arcane focus")
		assert_eq(ch.spell_save_dc("wizard").total(), dc + i + 1, "+%d to the save DC" % (i + 1))
		assert_eq(ch.spell_attack_bonus("wizard").total(), attack + i + 1, "and to the spell attack")
		assert_true(ch.spell_save_dc("wizard").has_part(str(Compendium.shared().item_data(id)["name"])), "named in the breakdown")
		ch.unequip_item(id)
		assert_eq(ch.spell_save_dc("wizard").total(), dc, "taken off the focus slot, nothing")
		ch.unequip("main_hand")   # his Arcane Focus staff is also a Quarterstaff, held: the first focus found
		assert_true(ch.equip(id, "off_hand"))
		assert_eq(ch.spell_save_dc("wizard").total(), dc + i + 1, "held in a hand it adds the same")
		assert_eq(ch.focus_item("arcane"), id, "and is still the arcane focus")


func test_it_does_nothing_until_a_wizard_attunes() -> void:
	var ch := _wizard()
	var dc := ch.spell_save_dc("wizard").total()
	ch.add_item(IDS[1])
	assert_true(ch.equip(IDS[1], "focus"))
	assert_eq(ch.spell_save_dc("wizard").total(), dc, "unattuned, in the focus slot: no bonus")
	assert_eq(ch.arcane_recovery_levels(), 3, "nor to Arcane Recovery")


func test_only_a_wizard_attunes_so_only_a_wizards_spells_gain_the_bonus() -> void:
	for pair: Array in [["hedda_ironvow", "cleric"], ["kip_smudgewick", "warlock"]]:
		var ch := TestChars.pregen(str(pair[0]), 5)
		var dc := ch.spell_save_dc(str(pair[1])).total()
		ch.add_item(IDS[0])
		assert_true(ch.attune_blocker(IDS[0]).begins_with("Requires attunement"), "%s can't attune: %s" % [pair[0], ch.attune_blocker(IDS[0])])
		assert_false(ch.attune(IDS[0]))
		assert_true(ch.equip(IDS[0], "focus"), "though the Focus slot takes it, as it takes a Holy Symbol of anyone's")
		assert_eq(ch.spell_save_dc(str(pair[1])).total(), dc, "%s's own spells gain nothing from it" % pair[0])
		assert_eq(ch.arcane_recovery_levels(), 0, "%s has no Arcane Recovery to add to" % pair[0])


func test_arcane_recovery_brings_back_one_more_slot_level() -> void:
	var plain := _wizard()
	assert_eq(plain.arcane_recovery_levels(), 3, "half of level 5, rounded up")
	assert_eq(_wizard(1).arcane_recovery_levels(), 1)
	for id in IDS:
		var ch := _wizard()
		ch.add_item(id)
		assert_true(ch.attune(id))
		assert_eq(ch.arcane_recovery_levels(), 4, "%s: one more, whatever its bonus" % id)
	assert_eq(TestChars.pregen("hedda_ironvow", 5).arcane_recovery_levels(), 0, "a Cleric has no Arcane Recovery")
