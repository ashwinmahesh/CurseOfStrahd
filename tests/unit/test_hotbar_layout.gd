extends TestCase
## U2: a hotbar the player arranges (ActionCatalog.arranged): their own order on each tab, a Favourites tab gathering
## the starred actions from every tab, a Hidden tab for the ones put away, all kept on the character from fight to
## fight and in its save.


func _fight() -> Dictionary:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(2, 3))
	TestCombat.punching_bag(e, Vector2i(8, 3))
	TestCombat.start_with(e, c)
	return {"e": e, "c": c, "cat": ActionCatalog.new(e)}


func _ids(list: Array[Dictionary]) -> Array:
	return list.map(func(a: Dictionary) -> String: return str(a["id"]))


func test_untouched_tabs_keep_their_order() -> void:
	var f := _fight()
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	var plain: Array = []
	for a in cat.actions_for(c):
		if str(a["tab"]) == ActionCatalog.COMMON:
			plain.append(str(a["id"]))
	assert_eq(_ids(cat.arranged(c, ActionCatalog.COMMON)), plain)
	assert_false(ActionCatalog.FAVOURITES in cat.tabs_for(c), "no Favourites tab until something is starred")
	assert_false(ActionCatalog.HIDDEN in cat.tabs_for(c))


func test_a_moved_action_keeps_its_new_place_into_the_next_fight() -> void:
	var f := _fight()
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	var before := _ids(cat.arranged(c, ActionCatalog.COMMON))
	var last := str(before[before.size() - 1])
	cat.move_action(c, ActionCatalog.COMMON, last, 0)
	var after := _ids(cat.arranged(c, ActionCatalog.COMMON))
	assert_eq(str(after[0]), last, "first now, so its hotkey is 1")
	assert_eq(after.size(), before.size(), "nothing lost or doubled")
	cat.move_action(c, ActionCatalog.COMMON, last, 2)
	assert_eq(str(_ids(cat.arranged(c, ActionCatalog.COMMON))[2]), last)
	var e2 := TestCombat.open_field(4)
	var c2 := e2.add(c.creature, &"party", Vector2i(2, 3))
	TestCombat.punching_bag(e2, Vector2i(8, 3))
	TestCombat.start_with(e2, c2)
	assert_eq(str(_ids(ActionCatalog.new(e2).arranged(c2, ActionCatalog.COMMON))[2]), last, "the hero keeps the arrangement")


func test_favourites_gather_on_their_own_tab_first() -> void:
	var f := _fight()
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	var common := _ids(cat.arranged(c, ActionCatalog.COMMON))
	var attack := ""
	for a in cat.actions_for(c):
		if str(a["kind"]) == "attack":
			attack = str(a["id"])
			break
	cat.set_favourite(c, str(common[1]), true)
	cat.set_favourite(c, attack, true)
	assert_eq(cat.tabs_for(c)[0], ActionCatalog.FAVOURITES)
	assert_eq(_ids(cat.arranged(c, ActionCatalog.FAVOURITES)), [str(common[1]), attack], "in the order they were starred")
	assert_true(str(common[1]) in _ids(cat.arranged(c, ActionCatalog.COMMON)), "still on its own tab too")
	cat.move_action(c, ActionCatalog.FAVOURITES, attack, 0)
	assert_eq(_ids(cat.arranged(c, ActionCatalog.FAVOURITES)), [attack, str(common[1])], "the Favourites tab has its own order")
	cat.set_favourite(c, attack, false)
	cat.set_favourite(c, str(common[1]), false)
	assert_false(ActionCatalog.FAVOURITES in cat.tabs_for(c), "the tab goes when it's empty")


func test_hidden_actions_move_to_the_hidden_tab_and_still_work() -> void:
	var f := _fight()
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	cat.set_hidden(c, "dodge", true)
	assert_false("dodge" in _ids(cat.arranged(c, ActionCatalog.COMMON)))
	assert_eq(cat.tabs_for(c)[cat.tabs_for(c).size() - 1], ActionCatalog.HIDDEN)
	var hidden := cat.arranged(c, ActionCatalog.HIDDEN)
	assert_eq(_ids(hidden), ["dodge"])
	assert_true(cat.perform(c, hidden[0]).ok, "a hidden action still works from its tab")
	cat.set_hidden(c, "dodge", false)
	assert_true("dodge" in _ids(cat.arranged(c, ActionCatalog.COMMON)), "shown again")


func test_the_arrangement_is_saved_with_the_character() -> void:
	var f := _fight()
	var c := f["c"] as Combatant
	var cat := f["cat"] as ActionCatalog
	cat.set_favourite(c, "dash", true)
	cat.set_hidden(c, "dodge", true)
	cat.move_action(c, ActionCatalog.COMMON, "dash", 0)
	var ch := c.creature as Character
	var back := Character.from_dict(JSON.parse_string(JSON.stringify(ch.to_dict())) as Dictionary)
	assert_eq(JSON.stringify(back.hotbar), JSON.stringify(ch.hotbar))
	var monster := TestCombat.punching_bag(f["e"] as Encounter, Vector2i(9, 6))
	cat.set_favourite(monster, "dash", true)
	assert_eq(ActionCatalog.layout(monster), {}, "a creature without a sheet keeps nothing")
