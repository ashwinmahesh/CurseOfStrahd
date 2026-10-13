extends TestCase
## Drinking a potion, or giving it to a creature within 5 ft, is a Bonus Action (2024 DMG, Potions; the owner's wish,
## 2026-10-12). Every potion is held to it, so a new one can't come in costing an Action. Oils are potions too but are
## applied, not drunk, so they keep their own cost.


## Every potion in the game: [{id, data}].
func _potions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for folder: String in ["items", "magic_items"]:
		for d in Compendium.shared().all(folder):
			if str(d.get("category", "")) == "potion":
				out.append(d)
	return out


func test_every_potion_is_drunk_as_a_bonus_action() -> void:
	var drunk := 0
	for d in _potions():
		var id := str(d["id"])
		var drink := {}
		for p in MagicItems.powers_of(d):
			if str(p.get("id", "")) == "drink":
				drink = p
		if id.begins_with("oil_of_"):
			assert_true(drink.is_empty(), "%s is applied, not drunk" % id)
			continue
		assert_false(drink.is_empty(), "%s is drunk" % id)
		var sid := CombatItems.power_spell(id, drink)
		var spell: Dictionary = Compendium.shared().spell_data(sid) if sid != "" else {}
		assert_eq(CombatItems.power_cost(drink, spell), "bonus", "%s: a Bonus Action to drink" % id)
		drunk += 1
	assert_true(drunk >= 40, "the healing potions and the magic ones (%d)" % drunk)


func test_on_the_hotbar_a_potion_costs_the_bonus_action_and_leaves_the_action() -> void:
	var e := TestCombat.open_field()
	var hedda := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 2))
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(3, 2))
	TestCombat.foe(e, "wolf", Vector2i(10, 6))
	var ch := hedda.creature as Character
	for d in _potions():
		ch.add_item(str(d["id"]))
	TestCombat.start_with(e, hedda)
	ilse.creature.hp = 1
	var cat := ActionCatalog.new(e)
	var drinks: Array[Dictionary] = []
	for a in cat.actions_for(hedda):
		if str(a.get("power_id", "")) == "drink":
			drinks.append(a)
	assert_true(drinks.size() >= 40, "every potion's Drink is on the Items tab (%d)" % drinks.size())
	for a in drinks:
		assert_eq(str(a["cost"]), "bonus", "%s on the hotbar" % a["item_id"])
		assert_eq(str(cat.details(hedda, a)["lines"][0]), "Costs: a Bonus Action", "%s's tooltip" % a["item_id"])
	assert_false(str(ActionCatalog.ACTION_TEXT["utilize"]).contains("such as a lever or a potion"),
		"Utilize doesn't offer to drink a potion with the Action")
	var r := cat.perform(hedda, cat.find(hedda, "item:potion_of_healing:drink"), [ilse])
	assert_true(r.ok, r.reason)
	assert_true(ilse.creature.hp > 1, "given to Ilse, it heals her")
	assert_false(hedda.bonus_available, "it took the Bonus Action")
	assert_true(hedda.action_available, "and left the Action")
	assert_false(bool(cat.find(hedda, "item:potion_of_healing_greater:drink")["legal"]), "one potion a turn")
