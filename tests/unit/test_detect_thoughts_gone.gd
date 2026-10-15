extends TestCase
## Detect Thoughts out of the game (Ashwin, 2026-10-13): the spell and the four items that cast it are hidden (files
## kept); what granted it grants another spell of its level (Mind Spike, or Augury for the Knowledge Domain, which has
## Mind Spike already); a save's copies of the items become items of the same rarity and price when it loads
## (SaveSystem.WITHDRAWN); the Death House card cabinet hides Eyes of Minute Seeing; the Wand of Wonder's 21-25 casts
## Mind Spike.

const ITEMS := ["helm_of_telepathy", "medallion_of_thoughts", "potion_of_mind_reading", "crystal_ball_of_mind_reading"]


func test_the_spell_and_its_items_are_out_of_every_list() -> void:
	var comp := Compendium.shared()
	assert_false(Compendium.playable(comp.spell_data("detect_thoughts")))
	assert_true(comp.spell_data("detect_thoughts").has("removed"))
	for cls: String in ["bard", "sorcerer", "wizard"]:
		for s in comp.spells_for(cls):
			assert_ne(str(s["id"]), "detect_thoughts", cls)
	for id: String in ITEMS:
		var data := comp.item_data(id)
		assert_false(data.is_empty(), id)
		assert_false(Compendium.playable(data), "%s is hidden, its data kept" % id)
		assert_true(data.has("removed"), id)
		assert_true(SaveSystem.WITHDRAWN.has(id), "%s has stand-ins for old saves" % id)
	for sub: String in ["aberrant_sorcery", "great_old_one_patron", "knowledge_domain"]:
		assert_false("detect_thoughts" in JSON.stringify(comp.subclass_data(sub).get("always_prepared", {})), sub)
	assert_false("detect_thoughts" in JSON.stringify(comp.feat_data("telepathic")))
	assert_false("detect_thoughts" in SpellCaster.PSIONIC_SPELLS)
	assert_false(FieldCasting.CHECK_AIDS.has("detect_thoughts"))
	assert_false("detect_thoughts" in RecommendedPicks.SPELLS)
	for m: String in ["strahd_von_zarovich", "rictavio", "mordenkainen", "arcanaloth"]:
		assert_false("detect_thoughts" in JSON.stringify(comp.monster_data(m)), m)
		assert_false("Detect Thoughts" in JSON.stringify(comp.monster_data(m)), m)


func test_what_granted_it_grants_another_spell_of_its_level() -> void:
	var aberrant := TestChars.custom("sorcerer", "human", 3, {"sorcerer_subclass": ["aberrant_sorcery"]})
	assert_true(aberrant.knows_spell("mind_spike"), "Aberrant Sorcery: Mind Spike")
	assert_false(aberrant.knows_spell("detect_thoughts"))
	assert_true("mind_spike" in SpellCaster.PSIONIC_SPELLS, "a Psionic Spell, so Psionic Sorcery casts it")
	var goo := TestChars.custom("warlock", "human", 3, {"warlock_subclass": ["great_old_one_patron"]})
	assert_true(goo.knows_spell("mind_spike"), "Great Old One: Mind Spike")
	assert_false(goo.knows_spell("detect_thoughts"))
	var knowledge := TestChars.custom("cleric", "human", 3, {"cleric_subclass": ["knowledge_domain"]})
	assert_true(knowledge.knows_spell("augury"), "Knowledge Domain: Augury (it has Mind Spike already)")
	assert_eq(knowledge.resource_casts("augury").size(), 1, "a Divination spell, so Mind Magic casts it")
	assert_false(knowledge.knows_spell("detect_thoughts"))
	var feat := JSON.stringify(Compendium.shared().feat_data("telepathic"))
	assert_true(feat.contains("\"mind_spike\""), "the Telepathic feat: Mind Spike")
	for id: String in ["mind_spike", "augury"]:
		assert_eq(int(Compendium.shared().spell_data(id).get("level", 0)), 2, id)
		assert_true(Compendium.playable(Compendium.shared().spell_data(id)), id)
	var rat := Pregens.build("ratatoille", 3)
	var savant := (rat.build["choices"] as Dictionary).get("diviner.3.divination_savant", []) as Array
	assert_true("mind_spike" in savant, str(savant))
	assert_false(rat.knows_spell("detect_thoughts"))


func test_a_saves_items_become_ones_of_the_same_rarity_and_price() -> void:
	var comp := Compendium.shared()
	for id: String in ITEMS:
		var old := comp.item_data(id)
		for sub: Variant in SaveSystem.WITHDRAWN[id]:
			var data := comp.item_data(str(sub))
			assert_true(Compendium.playable(data), str(sub))
			assert_eq(MagicItems.rarity(data), MagicItems.rarity(old), "%s for %s" % [sub, id])
			# The same price when the 2024 DMG priced by rarity; since Ashwin's Sane Magical Prices (2026-10-14) each
			# item has its own (data/treasure/magic_prices.json), and the withdrawn ones, out of play, kept the book's.
			assert_eq(MagicItems.price_for(MagicItems.rarity(data), MagicItems.is_consumable(data)), float(old.get("cost_gp", 0)),
				"%s for %s: the book's price for its rarity" % [sub, id])
	var save := {"version": GameState.SAVE_VERSION, "story": {
		"location_states": {"abbey_of_st_markovia_wards": {"treasure": {"surgery_cabinet": [{"id": "potion_of_mind_reading", "qty": 1}]}}},
		"party": [{"id": "ratatoille", "attuned": ["medallion_of_thoughts"], "inventory": [
			{"id": "potion_of_healing_superior", "qty": 2, "slot": ""},
			{"id": "potion_of_mind_reading", "qty": 1, "slot": "", "new": true},
			{"id": "medallion_of_thoughts", "qty": 1, "slot": "neck", "charges": 3}]}],
		"stash": [{"id": "helm_of_telepathy", "qty": 1}, {"id": "crystal_ball_of_mind_reading", "qty": 1}]}}
	var up := SaveSystem.upgrade(save)
	var text := JSON.stringify(up)
	for id: String in ITEMS:
		assert_false(text.contains("\"%s\"" % id), "%s is gone" % id)
	var story := up["story"] as Dictionary
	var chest := ((story["location_states"] as Dictionary)["abbey_of_st_markovia_wards"] as Dictionary)["treasure"] as Dictionary
	assert_eq(str(((chest["surgery_cabinet"] as Array)[0] as Dictionary)["id"]), "potion_of_healing_superior", "the first copy found")
	var hero := (story["party"] as Array)[0] as Dictionary
	var inv := hero["inventory"] as Array
	assert_eq(str((inv[0] as Dictionary)["id"]), "potion_of_healing_superior")
	assert_eq(str((inv[1] as Dictionary)["id"]), "potion_of_heroism", "the second copy: the next stand-in")
	assert_eq(str((inv[2] as Dictionary)["id"]), "eyes_of_minute_seeing")
	assert_eq(str((inv[2] as Dictionary)["slot"]), "", "off the neck")
	assert_eq(hero["attuned"], [], "the attunement ends")
	var stash := (story["stash"] as Array).map(func(d: Variant) -> String: return str((d as Dictionary)["id"]))
	assert_eq(stash, ["circlet_of_blasting", "crystal_ball_of_true_seeing"])
	var ch := Character.from_dict(hero)
	assert_true(ch.carries("potion_of_heroism"))
	assert_true(ch.carries("eyes_of_minute_seeing"))


func test_a_stand_in_joins_a_stack_of_its_kind() -> void:
	var save := {"version": GameState.SAVE_VERSION, "story": {"party": [{"id": "ratatoille", "inventory": [
		{"id": "potion_of_mind_reading", "qty": 2, "slot": ""},
		{"id": "potion_of_healing_superior", "qty": 1, "slot": ""}]}]}}
	var inv := ((((SaveSystem.upgrade(save)["story"] as Dictionary)["party"] as Array)[0] as Dictionary)["inventory"]) as Array
	assert_eq(inv.size(), 1, str(inv))
	assert_eq(str((inv[0] as Dictionary)["id"]), "potion_of_healing_superior")
	assert_eq(int((inv[0] as Dictionary)["qty"]), 3, "one stack of three")


func test_death_houses_card_cabinet_hides_eyes_of_minute_seeing() -> void:
	var found := ""
	for p: Variant in Compendium.shared().get_entry("locations", "death_house_ground").get("props", []):
		if str((p as Dictionary).get("id", "")) == "den_cabinet_board":
			found = str((p as Dictionary).get("item", ""))
	assert_eq(found, "eyes_of_minute_seeing")


func test_the_wand_of_wonders_mind_reading_roll_casts_mind_spike() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 5)
	var ch := c.creature as Character
	var t := TestCombat.punching_bag(e, Vector2i(6, 2), 200)
	ch.add_item("wand_of_wonder")
	assert_true(ch.attune("wand_of_wonder"))
	TestCombat.start_with(e, c)
	var s := 1
	while true:
		var roll := DiceRoller.new(s).roll_one(100)
		if roll >= 21 and roll <= 25:
			break
		s += 1
	e.dice.reseed(s)
	var hp := t.creature.hp
	assert_true(e.items.use(c, "wand_of_wonder", "wonder", [t], e.center_of(t)).ok)
	assert_true(e.log.dump().contains("Mind Spike"), e.log.dump())
	assert_false(e.log.dump().contains("Detect Thoughts"))
	assert_true(t.creature.hp < hp or e.log.dump().contains("saves"), "it struck the target's mind")
