extends TestCase
## The Examine card (Combat HUD plan, owner pick 2026-10-09; Baldur's Gate 3's Examine): ActionCatalog.examine.


func _lines(card: Dictionary, heading: String) -> Array:
	for s: Variant in card["sections"]:
		if str((s as Dictionary)["heading"]) == heading:
			return (s as Dictionary)["lines"] as Array
	return []


func test_a_foe_shows_what_the_party_could_know() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var z := TestCombat.foe(e, "zombie", Vector2i(3, 2))
	TestCombat.start_with(e, ilse)
	var cat := ActionCatalog.new(e)
	var card := cat.examine(ilse, z)
	assert_eq(str(card["title"]), z.name())
	assert_eq(str(card["subtitle"]), "Medium Undead · CR 1/4", "what it is")
	assert_eq(str(_lines(card, "Condition")[0]), "Not Bloodied", "a foe's Hit Points stay hidden, as on its bar")
	assert_true(str(_lines(card, "Defenses")[0]).begins_with("Unknown"), "its defenses wait for a Study")
	assert_true(str(_lines(card, "Your odds")[0]).begins_with("Greatsword: hit"), "the odds of Ilse's best attack")
	e.studied[str((z.creature as Monster).data["id"])] = true
	card = cat.examine(ilse, z)
	assert_true(_lines(card, "Defenses").any(func(l: Variant) -> bool: return str(l).contains("Poison")), "studied: its immunities")
	assert_true(_lines(card, "Abilities").any(func(l: Variant) -> bool: return str(l).begins_with("Traits")), "and its abilities")


func test_an_ally_shows_its_hit_points_and_classes() -> void:
	var e := TestCombat.open_field()
	var ilse := TestCombat.hero(e, "ilse_varga", Vector2i(2, 2), 5)
	var god := TestCombat.hero(e, "godrick_pendlebrook", Vector2i(2, 4), 5)
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, ilse)
	var card := ActionCatalog.new(e).examine(ilse, god)
	assert_true(str(card["subtitle"]).contains("Paladin 5"))
	assert_true(str(_lines(card, "Condition")[0]).contains("/ %d Hit Points" % god.creature.max_hp()))
	assert_true(_lines(card, "Your odds").is_empty(), "no odds against a friend")
