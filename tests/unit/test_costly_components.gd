extends TestCase
## Costly material components (owner's pick, 2026-10-08): a spell whose Material component has a cost needs that
## material carried (no component pouch or focus stands in for it) and uses it up when the spell says so; items of one
## kind count together toward the cost. Hands stay free.


func _wizard(e: Encounter, spells: Array) -> Combatant:
	return TestCombat.caster_with(e, spells, Vector2i(2, 3))


func test_a_spell_waits_for_its_material_and_keeps_one_it_doesnt_use_up() -> void:
	var e := TestCombat.open_field(3)
	var c := _wizard(e, ["chromatic_orb"])
	var ch := c.creature as Character
	var t := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var orb := {}
	for x in e.spells.castable(c):
		if str(x["id"]) == "chromatic_orb":
			orb = x
	assert_false(bool(orb["legal"]))
	assert_eq(str(orb["reason"]), "Needs Diamond worth 50 gp")
	assert_false(e.spells.cast(c, "chromatic_orb", 1, [t]).ok, "no diamond, no spell")
	ch.add_item("diamond")
	assert_true(e.spells.cast(c, "chromatic_orb", 1, [t]).ok)
	assert_eq(ch.material_worth("diamond"), 100.0, "Chromatic Orb doesn't use its diamond up")


func test_a_consumed_component_is_used_up_by_worth() -> void:
	var ch := TestChars.custom("cleric", "human", 5)
	var revivify := Compendium.shared().spell_data("revivify")
	ch.add_item("diamond", 2)
	assert_eq(ch.component_why(revivify), "Needs Diamond worth 300 gp (has 200 gp)")
	ch.add_item("diamond", 2)
	assert_eq(ch.component_why(revivify), "", "four diamonds of 100 gp make up 300 gp")
	assert_eq(ch.use_component(revivify), "3 Diamond")
	assert_eq(ch.material_worth("diamond"), 100.0, "one left")
	var bless := Compendium.shared().spell_data("bless")
	assert_eq(ch.component_why(bless), "", "a component worth little, or one that's a focus, isn't tracked")
	assert_eq(ch.use_component(Compendium.shared().spell_data("identify")), "", "Identify keeps its pearl")


func test_a_ritual_while_exploring_still_burns_its_incense() -> void:
	var ch := TestChars.pregen("silvain_aster", 3)
	assert_true(ch.knows_spell("find_familiar"))
	var st := StoryState.new()
	st.party.append(ch)
	var res := FieldCasting.cast_utility(st, ch, "find_familiar", true)
	assert_false(bool(res["ok"]), "no incense")
	assert_eq(str(res["text"]), "Needs Incense worth 10 gp")
	var option := {}
	for o in FieldCasting.utility_options(st.party, ch, DiceRoller.new(1)):
		if str(o["id"]) == "find_familiar":
			option = o
	assert_false(bool(option["legal"]), "the spell list says why")
	ch.add_item("incense", 2)
	res = FieldCasting.cast_utility(st, ch, "find_familiar", true)
	assert_true(bool(res["ok"]), str(res["text"]))
	assert_true(str(res["text"]).contains("using up Incense"), str(res["text"]))
	assert_eq(ch.material_worth("incense"), 10.0, "one block burned")


func test_the_materials_are_sold_and_every_kind_has_an_item() -> void:
	var lucian := Compendium.shared().get_entry("npcs", "father_lucian")
	var sold: Array = (lucian["shop"]["sells"] as Array).map(func(x: Dictionary) -> String: return str(x["id"]))
	assert_true("diamond" in sold and "diamond_dust" in sold and "incense" in sold, "the Vallaki church sells them")
	for f in DirAccess.get_files_at("res://data/spells"):
		if not f.ends_with(".json"):
			continue
		var spell := Compendium.shared().spell_data(f.get_basename())
		var cc := Character.costly_component(spell)
		if cc.is_empty():
			continue
		var item := Compendium.shared().item_data(str(cc["material"]))
		assert_false(item.is_empty(), "%s: an item for %s" % [f, cc["material"]])
		assert_eq(str(item.get("material", "")), str(cc["material"]), "%s: its item counts as %s" % [f, cc["material"]])
