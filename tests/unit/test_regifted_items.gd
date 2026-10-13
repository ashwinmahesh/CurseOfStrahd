extends TestCase
## Gifts that changed after saves already held them (SaveSystem.REGIFTED): Mother's eighth gift was Boots of Levitation
## and is Winged Boots now (owner, 2026-10-13). A save from before swaps her pair once, where it was, and Winged Boots
## made before they had charges (SaveSystem.CHARGED_LATER) start with all four.


func _save(flags: Dictionary, inventory: Array, attuned: Array = [], stash: Array = []) -> Dictionary:
	return {"version": GameState.SAVE_VERSION, "story": {"flags": flags, "stash": stash, "bench": [],
		"party": [{"id": "ilse_varga", "attuned": attuned, "inventory": inventory}]}}


func _hero(up: Dictionary) -> Dictionary:
	return ((up["story"] as Dictionary)["party"] as Array)[0] as Dictionary


func test_her_boots_become_winged_boots_where_they_were() -> void:
	var up := SaveSystem.upgrade(_save({"mother_flown": true},
		[{"id": "dagger", "qty": 1, "slot": ""}, {"id": "boots_of_levitation", "qty": 1, "slot": "feet", "made": true}],
		["boots_of_levitation", "ring_of_protection"]))
	var hero := _hero(up)
	var boots := (hero["inventory"] as Array)[1] as Dictionary
	assert_eq(str(boots["id"]), "winged_boots")
	assert_eq(str(boots["slot"]), "feet", "still worn")
	assert_eq(hero["attuned"], ["winged_boots", "ring_of_protection"], "still attuned")
	assert_eq(int(boots["charges"]), 4, "all four charges")
	assert_true(bool(boots.get("new", false)), "shown as new in the inventory")
	assert_true(bool(((up["story"] as Dictionary)["flags"] as Dictionary).get("mother_boots_given", false)))


func test_a_stashed_pair_swaps_too() -> void:
	var up := SaveSystem.upgrade(_save({"mother_flown": true}, [], [], [{"id": "boots_of_levitation", "qty": 1, "made": true}]))
	var stashed := ((up["story"] as Dictionary)["stash"] as Array)[0] as Dictionary
	assert_eq(str(stashed["id"]), "winged_boots")
	assert_eq(int(stashed["charges"]), 4)


## Once: a pair found later, or one a new game's party holds when she has given Winged Boots, stays as it is.
func test_only_once_and_only_hers() -> void:
	var up := SaveSystem.upgrade(_save({"mother_flown": true}, [{"id": "boots_of_levitation", "qty": 1, "slot": "", "made": true}]))
	(_hero(up)["inventory"] as Array).append({"id": "boots_of_levitation", "qty": 1, "slot": "", "made": true})
	var again := SaveSystem.upgrade(up)
	var ids := (_hero(again)["inventory"] as Array).map(func(x: Variant) -> String: return str((x as Dictionary)["id"]))
	assert_eq(ids, ["winged_boots", "boots_of_levitation"], "the later pair stays")
	var given := SaveSystem.upgrade(_save({"mother_flown": true, "mother_boots_given": true},
		[{"id": "winged_boots", "qty": 1, "slot": "", "made": true, "charges": 3}, {"id": "boots_of_levitation", "qty": 1, "slot": "", "made": true}]))
	ids = (_hero(given)["inventory"] as Array).map(func(x: Variant) -> String: return str((x as Dictionary)["id"]))
	assert_eq(ids, ["winged_boots", "boots_of_levitation"], "she gave Winged Boots in this game")
	var before := SaveSystem.upgrade(_save({}, [{"id": "boots_of_levitation", "qty": 1, "slot": "", "made": true}]))
	assert_eq(str(((_hero(before)["inventory"] as Array)[0] as Dictionary)["id"]), "boots_of_levitation", "not hers: she hasn't flown")
	assert_false(((before["story"] as Dictionary)["flags"] as Dictionary).has("mother_boots_given"))


func test_older_winged_boots_get_their_charges() -> void:
	var up := SaveSystem.upgrade(_save({}, [{"id": "winged_boots", "qty": 1, "slot": "feet", "made": true, "budget_used": {"fly": 30}},
		{"id": "winged_boots", "qty": 1, "slot": "", "made": true, "charges": 1}]))
	var inv := _hero(up)["inventory"] as Array
	assert_eq(int((inv[0] as Dictionary)["charges"]), 4, "Ilarion's pair, from before charges")
	assert_eq(int((inv[1] as Dictionary)["charges"]), 1, "a pair with charges keeps its count")


## The 2024 Winged Boots: a Magic action and a charge for an hour of 30 ft flight; 1d4 charges back at dawn.
func test_winged_boots_fly_an_hour_a_charge() -> void:
	var e := TestCombat.open_field()
	var c := TestCombat.hero(e, "silvain_aster", Vector2i(2, 2), 3)
	var ch := c.creature as Character
	TestCombat.foe(e, "wolf", Vector2i(9, 2))
	ch.add_item("winged_boots")
	assert_true(ch.equip("winged_boots", "feet"))
	assert_true(ch.attune("winged_boots"))
	assert_eq(ch.charges_left("winged_boots"), 4)
	TestCombat.start_with(e, c)
	assert_eq(ch.speed("fly").total(), 0, "on foot until they're used")
	var r := e.items.use(c, "winged_boots", "fly")
	assert_true(r.ok, r.reason)
	assert_eq(ch.speed("fly").total(), 30, "Fly 30")
	assert_eq(ch.charges_left("winged_boots"), 3, "a charge spent")
	ch.on_dawn(DiceRoller.new(1))
	assert_true(ch.charges_left("winged_boots") > 3, "charges back at dawn")
