extends TestCase
## One slot per idea on the hotbar (Combat HUD plan, the owner's ask of 2026-10-09: "a toggle for features (ask, auto,
## off) instead of three buttons"): each standing rule is one toggle on the Reactions tab, an action's variants share a
## container slot, and common actions that can't apply in this fight stay off it (ActionCatalog.slots).


func _slot(cat: ActionCatalog, c: Combatant, tab: String, label: String) -> Dictionary:
	for s in cat.slots(c, tab):
		if str(s["label"]) == label:
			return s
	return {}


func _labels(cat: ActionCatalog, c: Combatant, tab: String) -> Array[String]:
	var out: Array[String] = []
	for s in cat.slots(c, tab):
		out.append(str(s["label"]))
	return out


func test_each_rule_is_one_toggle_on_the_reactions_tab() -> void:
	var e := TestCombat.open_field()
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, god)
	var cat := ActionCatalog.new(e)
	assert_true(ActionCatalog.REACTIONS in cat.tabs_for(god))
	for label in _labels(cat, god, cat.class_tab(god)):
		assert_false(label.ends_with(": Ask") or label.ends_with(": Automatic") or label.ends_with(": Off"), "%s left the Paladin tab" % label)
	var smite := _slot(cat, god, ActionCatalog.REACTIONS, "Divine Smite")
	assert_true(bool(smite.get("toggle", false)), "Divine Smite is one toggle")
	assert_eq((smite["items"] as Array).size(), 3, "Ask, Automatic and Off inside it")
	assert_eq(str(smite["sub"]), "Ask", "Ask to start with")
	for rule: String in ["Knock Out", "Heroic Inspiration"]:
		assert_true(bool(_slot(cat, god, ActionCatalog.REACTIONS, rule).get("toggle", false)), "%s is a toggle too" % rule)


func test_a_toggle_steps_through_its_modes_on_any_turn() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)   # not Godrick's turn: a rule still changes
	var cat := ActionCatalog.new(e)
	var smite := _slot(cat, god, ActionCatalog.REACTIONS, "Divine Smite")
	var items := smite["items"] as Array
	var next := items[(int(smite["current"]) + 1) % items.size()] as Dictionary
	assert_true(cat.set_rule(god, next).ok, "changed off-turn")
	assert_eq(str(god.reaction_rules.get("divine_smite", "")), "auto")
	assert_eq(str(_slot(cat, god, ActionCatalog.REACTIONS, "Divine Smite")["sub"]), "Automatic", "the slot shows the new mode")
	assert_true(god.action_available and god.bonus_available and god.reaction_available, "nothing spent")
	assert_true(e.events.filter(func(ev: Variant) -> bool: return str((ev as Dictionary).get("type", "")) == "ability").is_empty(),
		"nothing to show on the field")


func test_variants_share_a_container_slot() -> void:
	var e := TestCombat.open_field()
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	var tam := TestCombat.hero(e, "tamsin_tealeaf", Vector2i(2, 4), 5)
	var hed := TestCombat.hero(e, "hedda_ironvow", Vector2i(2, 6), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, god)
	var cat := ActionCatalog.new(e)
	var shove := _slot(cat, god, ActionCatalog.COMMON, "Shove")
	assert_true(bool(shove.get("group", false)), "Shove is one slot")
	assert_eq((shove["items"] as Array).map(func(a: Dictionary) -> String: return cat.variant_name(a, "label:Shove")), ["Prone", "Push"])
	var command := _slot(cat, god, ActionCatalog.SPELLS, "Command")
	assert_eq((command["items"] as Array).size(), 5, "Command's five words in one slot")
	assert_false(_labels(cat, god, ActionCatalog.SPELLS).has("Command: Halt"))
	assert_eq((_slot(cat, tam, cat.class_tab(tam), "Cunning")["items"] as Array).size(), 3, "Cunning Action's Dash, Disengage and Hide")
	assert_eq((_slot(cat, hed, cat.class_tab(hed), "Divine Spark")["items"] as Array).size(), 2, "Divine Spark's Heal and Harm")
	# A container's members still do what they did.
	var push := (shove["items"] as Array)[1] as Dictionary
	assert_eq(str(push["id"]), "shove_push")


func test_common_actions_that_cant_apply_stay_off_the_hotbar() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var common := _labels(cat, ilse, ActionCatalog.COMMON)
	for gone: String in ["Influence", "Utilize", "Stabilize"]:
		assert_false(gone in common, "%s isn't on the hotbar" % gone)
	assert_false(cat.find(ilse, "influence").is_empty(), "still in the catalog, with its reason")
	god.creature.take_damage(god.creature.hp, &"slashing")
	assert_true("Stabilize" in _labels(cat, ilse, ActionCatalog.COMMON), "Stabilize shows once someone is dying")


func test_an_armed_smite_is_marked() -> void:
	var e := TestCombat.open_field()
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 2), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, god)
	var cat := ActionCatalog.new(e)
	var smite := cat.find(god, "spell:divine_smite")
	assert_false(bool(smite.get("armed", true)))
	assert_true(cat.perform(god, smite).ok)
	assert_true(bool(cat.find(god, "spell:divine_smite")["armed"]), "armed for the turn, and the slot says so")


func test_every_slot_but_a_rule_has_an_icon() -> void:
	# Common actions and class abilities have tiles of their own (art/icons.json "features"); a rule shows its mode.
	var e := TestCombat.open_field()
	var heroes: Array[Combatant] = []
	for i in 4:
		heroes.append(TestCombat.hero(e, ["ilse_varga", "godrick_pendlebrook", "tamsin_tealeaf", "wren_featherfoot"][i] as String, Vector2i(2, 1 + i * 2), 5))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, heroes[0])
	var cat := ActionCatalog.new(e)
	for h in heroes:
		for tab: String in [ActionCatalog.COMMON, cat.class_tab(h)]:
			for s in cat.slots(h, tab):
				assert_true(Icons.for_action(s) != null, "%s's %s has an icon" % [h.name(), s["label"]])
		for s in cat.slots(h, ActionCatalog.REACTIONS):
			assert_true(Icons.for_action(s) == null, "a rule shows its mode, not an icon")
	assert_true(Icons.for_action(cat.find(heroes[0], "dash")) == Icons.feature("dash"), "Dash has its own tile, not the rune")
