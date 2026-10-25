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
	for path in Compendium.data_files("spells"):
		var f := path.get_file()
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


## Diamonds and the other components spells use up, for sale from the start (Ashwin, 2026-10-15: no diamonds turned
## up, so Revivify couldn't be cast): every one sold, without running out, at its own price by a merchant who never
## joins the party; diamonds at a church in each town; and diamonds among a fight's finds from level 5.
func test_every_used_up_component_is_always_for_sale() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("liriel_dawnsong", 1))
	st.gold = 10000.0
	var materials := {}
	for path in Compendium.data_files("spells"):
		var spell := Compendium.shared().spell_data(path.get_file().get_basename())
		var cc := Character.costly_component(spell)
		if not cc.is_empty() and Compendium.playable(spell):
			materials[str(cc["material"])] = true
	assert_true(materials.has("diamond") and materials.has("onyx"), str(materials.keys()))
	for m: String in materials:
		var sellers: Array[String] = []
		for npc: String in Compendium.shared().table("npcs"):
			var data := Compendium.shared().get_entry("npcs", npc)
			if bool(data.get("guest", false)) or not data.has("shop"):
				continue
			for w in st.shop_wares(npc):
				var item := Compendium.shared().item_data(m)
				if str(w["id"]) == m and int(w["qty"]) < 0 \
						and float(w["price"]) == Trade.buy_price(st, npc, float(item["cost_gp"]) * StoryState.shop_lot(item)):
					sellers.append(npc)
		assert_false(sellers.is_empty(), "%s is always for sale at its price somewhere" % m)
	for npc: String in ["donavich", "father_lucian", "kasha_varo"]:
		st.attitudes[npc] = "indifferent"
		var diamond := st.shop_wares(npc).filter(func(w: Dictionary) -> bool: return str(w["id"]) == "diamond")
		assert_eq(diamond.size(), 1, "%s sells diamonds" % npc)
		assert_eq(int((diamond[0] as Dictionary)["qty"]), -1, "%s never runs out" % npc)
		assert_eq(float((diamond[0] as Dictionary)["price"]), 100.0, "at 100 gp each")
	var regions := ["donavich", "father_lucian", "kasha_varo"].map(func(n: String) -> String:
		return str(Compendium.shared().get_entry("npcs", n)["region"]))
	assert_eq(regions, ["village_of_barovia", "vallaki", "krezk"], "one in each town")
	var liriel := st.party[0]
	for i in 3:
		assert_eq(st.shop_buy("donavich", "diamond", liriel), "")
	assert_eq(liriel.component_why(Compendium.shared().spell_data("revivify")), "", "three diamonds: a Revivify")
	assert_eq(st.gold, 9700.0)


func test_the_dead_can_be_raised_in_every_town() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("liriel_dawnsong", 3))
	for npc: String in ["donavich", "father_lucian", "kasha_varo"]:
		st.attitudes[npc] = "indifferent"   # a friendly priest takes 10% off the fee
		var raise := Services.offered(st, npc).filter(func(l: Dictionary) -> bool: return str(l["id"]) == "raise_dead")
		assert_eq(raise.size(), 1, "%s raises the dead" % npc)
		assert_eq(Services.cost(raise[0] as Dictionary), 2500.0, "the 2024 PHB's 2,000 gp and the 500 gp diamond")


func test_fights_turn_up_diamonds_from_level_5() -> void:
	var found := {}
	for level: int in [3, 5, 8, 10]:
		for i in 200:
			var it := RoadSpoils.find(DiceRoller.new(i), level, false)
			if str(it["id"]) in ["onyx", "pearl", "diamond"]:
				found["%d:%s" % [level, it["id"]]] = true
	assert_true(found.has("3:pearl") and not found.has("3:diamond"), "pearls before: %s" % str(found.keys()))
	for level: int in [5, 8, 10]:
		assert_true(found.has("%d:diamond" % level), "a diamond at level %d" % level)
