extends TestCase
## Costly material components (owner's pick, 2026-10-08): a spell whose Material component has a cost and is used up
## needs that material carried (no component pouch or focus stands in for it) and uses it up; items of one kind count
## together toward the cost. One the spell keeps isn't needed at all (owner, 2026-10-09). Hands stay free.


## A pregen wizard knowing `spells`, without the starter kit's components (each test gives its own).
func _wizard(e: Encounter, spells: Array) -> Combatant:
	var c := TestCombat.caster_with(e, spells, Vector2i(2, 3))
	_empty(c.creature as Character)
	return c


func _empty(ch: Character) -> void:
	for material: String in ["diamond", "pearl", "incense"]:
		while ch.material_worth(material) > 0.0:
			for e: Dictionary in ch.inventory.duplicate():
				if str(e["id"]) == material:
					ch.remove_one(material, e)


func test_a_spell_waits_for_a_material_it_uses_up_but_not_for_one_it_keeps() -> void:
	var e := TestCombat.open_field(3)
	var c := _wizard(e, ["chromatic_orb", "revivify"])
	var ch := c.creature as Character
	var t := TestCombat.punching_bag(e, Vector2i(6, 3))
	TestCombat.start_with(e, c)
	var listed := {}
	for x in e.spells.castable(c):
		listed[str(x["id"])] = x
	assert_true(bool((listed["chromatic_orb"] as Dictionary)["legal"]), "Chromatic Orb keeps its diamond, so it needs none")
	assert_eq(str((listed["revivify"] as Dictionary)["reason"]), "Needs Diamond worth 300 gp", "Revivify uses its diamonds up")
	assert_true(e.spells.cast(c, "chromatic_orb", 1, [t]).ok, "no diamond, and still the spell")
	for id: String in ["chromatic_orb", "identify", "gate", "programmed_illusion", "songals_elemental_suffusion"]:
		var spell := Compendium.shared().spell_data(id)
		assert_false(spell.is_empty(), id)
		assert_eq(ch.component_why(spell), "", "%s keeps its component, so it needs none" % id)
		assert_eq(Character.costly_component(spell), {}, id)


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
	_empty(ch)
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


func test_pregens_start_with_incense_for_a_familiar() -> void:
	var silvain := Pregens.build("silvain_aster", 9)
	assert_eq(silvain.component_why(Compendium.shared().spell_data("chromatic_orb")), "", "Chromatic Orb needs no diamond")
	assert_eq(silvain.material_worth("diamond"), 0.0, "so the kit no longer packs one")
	assert_eq(silvain.material_worth("incense"), 20.0, "two blocks of incense for Find Familiar")
	var liriel := Pregens.build("liriel_dawnsong", 9)
	assert_true(liriel.knows_spell("revivify"))
	assert_ne(liriel.component_why(Compendium.shared().spell_data("revivify")), "", "Revivify's diamonds are bought")
