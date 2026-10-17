extends TestCase
## Steel Wind Strike (2024 PHB, level 5): up to five creatures within 30 ft, a melee spell attack against each. The
## hotbar picks them one by one (the "multi" pick every spell on several creatures uses), enemies only, each at most
## once, and casts with however many were picked.


## A level 9 wizard who knows it and `n` bags in reach: {e, c, bags}.
func _field(n: int) -> Dictionary:
	var e := TestCombat.open_field(5)
	var c := TestCombat.caster_with(e, ["steel_wind_strike"], Vector2i(1, 3))
	var bags: Array[Combatant] = []
	for i in n:
		bags.append(TestCombat.punching_bag(e, Vector2i(5 + (i % 3), 1 + i), 500))
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "bags": bags}


## The attack rolls made at each creature since event `from`.
func _attacks_by_target(e: Encounter, from: int) -> Dictionary:
	var out := {}
	for i in range(from, e.events.size()):
		var ev := e.events[i] as Dictionary
		if str(ev.get("type", "")) == "attack":
			out[str(ev.get("target", ""))] = int(out.get(str(ev.get("target", "")), 0)) + 1
	return out


func test_the_hotbar_takes_up_to_five_picks() -> void:
	var f := _field(2)
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:steel_wind_strike")
	assert_false(a.is_empty(), "the wizard knows Steel Wind Strike")
	assert_eq(str(a["targeting"]), "multi", "not a single click on one foe")
	assert_eq(e.spells.target_count(Compendium.shared().spell_data("steel_wind_strike"), 5), 5, "up to five")
	assert_eq(ActionCatalog.spell_targeting(Compendium.shared().spell_data("true_strike")), "enemy", "a spell on one enemy is unchanged")


func test_only_enemies_can_be_picked() -> void:
	var f := _field(1)
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var friend := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	var cat := ActionCatalog.new(e)
	var a := cat.find(c, "spell:steel_wind_strike")
	assert_eq(cat.target_why(c, a, friend), "Choose an enemy")
	assert_eq(cat.target_why(c, a, (f["bags"] as Array)[0] as Combatant), "", "a foe in reach is fine")


func test_a_pick_of_three_attacks_three_creatures_once_each() -> void:
	var f := _field(3)
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var bags := f["bags"] as Array
	var from := e.events.size()
	var r := e.spells.cast(c, "steel_wind_strike", 5, bags)
	assert_true(r.ok, r.reason)
	var by := _attacks_by_target(e, from)
	assert_eq(by.size(), 3, "all three were struck at")
	for b: Variant in bags:
		assert_eq(int(by.get((b as Combatant).id, 0)), 1, "one melee spell attack each")


func test_five_picks_attack_five_creatures() -> void:
	var f := _field(5)
	var e := f["e"] as Encounter
	var c := f["c"] as Combatant
	var from := e.events.size()
	var r := e.spells.cast(c, "steel_wind_strike", 5, f["bags"] as Array)
	assert_true(r.ok, r.reason)
	assert_eq(_attacks_by_target(e, from).size(), 5)


func test_six_picks_are_too_many() -> void:
	var f := _field(6)
	var e := f["e"] as Encounter
	var r := e.spells.cast(f["c"] as Combatant, "steel_wind_strike", 5, f["bags"] as Array)
	assert_false(r.ok)
	assert_true(r.reason.begins_with("Too many targets"), r.reason)


func test_one_creature_cannot_take_all_five_attacks() -> void:
	var f := _field(1)
	var e := f["e"] as Encounter
	var bag := (f["bags"] as Array)[0] as Combatant
	var r := e.spells.cast(f["c"] as Combatant, "steel_wind_strike", 5, [bag, bag, bag])
	assert_false(r.ok)
	assert_eq(r.reason, "Choose distinct creatures")


func test_rays_and_beams_may_still_share_a_creature() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.caster_with(e, ["scorching_ray"], Vector2i(1, 3))
	var bag := TestCombat.punching_bag(e, Vector2i(5, 3), 500)
	TestCombat.start_with(e, c)
	var r := e.spells.cast(c, "scorching_ray", 2, [bag, bag, bag])
	assert_true(r.ok, r.reason)
