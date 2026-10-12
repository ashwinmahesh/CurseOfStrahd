extends TestCase
## The camp in the wild (F16, world/exploration/location_camp.gd): a Long Rest out of doors makes camp near the party,
## the company sits round the fire (those waiting at camp too), walking up to someone who wants a word starts their
## talk, sleeping is the Long Rest, and breaking camp packs it away. Indoors and in towns the rest stays as it was.

var root: Node
const FIELD := "test_camp_field"


func before_each() -> void:
	var rows: Array = []
	for z in 14:
		rows.append("#".repeat(20) if z == 0 or z == 13 else "#" + ".".repeat(18) + "#")
	Compendium.shared().tables["locations"][FIELD] = {"id": FIELD, "name": "Test Field", "region": "svalich_road",
		"summary": "", "map": {"rows": rows, "outdoors": true, "theme": "forest"}, "spawns": {"default": [9, 7]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var wren := Pregens.build("wren_featherfoot", 3)
	wren.finish_long_rest()
	GameState.story.bench.append(wren)
	GameState.story.location = FIELD
	GameState.story.minute_of_day = 20 * 60
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(2)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	(Compendium.shared().tables["locations"] as Dictionary).erase(FIELD)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


func _make_camp() -> LocationCamp:
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	var make := _button(rest, "Make camp (8 hours)")
	assert_true(make != null and not make.disabled, "the Long Rest makes camp out here")
	make.pressed.emit()
	await _frames(2)
	return LocationCamp.of(_view())


func test_a_long_rest_in_the_wild_makes_camp_round_a_fire() -> void:
	var camp := await _make_camp()
	assert_true(camp != null, "camp is made")
	assert_true(root.get("screen") == null, "the rest screen gives way to it")
	var view := _view()
	var models: Array[String] = []
	for p: Variant in view.loc["props"]:
		if bool((p as Dictionary).get("camp", false)):
			models.append(str((p as Dictionary)["model"]))
			assert_true(view.prop_nodes.has(str((p as Dictionary)["id"])), "%s is drawn" % p["id"])
	assert_true("campfire" in models and "stewpot" in models and "bedroll" in models, "fire, pot, bedrolls: %s" % [models])
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot"]:
		assert_true(camp.people.has(id), "%s is by the fire" % id)
		var cell := ((camp.people[id] as Dictionary)["token"] as CombatToken).combatant.cell
		assert_true(view.grid.distance_ft(cell, 1, camp.center, 1) <= 10, "%s sits round it" % id)
	assert_eq(((camp.people["ratatoille"] as Dictionary)["token"] as CombatToken).combatant.cell, camp.center + CampSite.COOK,
		"Ratatouille at the stew pot")
	assert_eq(GameState.story.camp_company.size(), 1, "Wren, waiting at camp, is here too")
	# The leader walks about; the others stay by the fire.
	var thistle := view.members[2]
	var sat := thistle.cell
	view.walk_to(camp.center + Vector2i(5, 3))
	await _frames(60)
	assert_eq(thistle.cell, sat, "Thistle stays where she sat")


func test_walking_up_to_someone_who_wants_a_word_starts_their_talk() -> void:
	GameState.story.set_flag("strahd_knelt", "wren_featherfoot")
	var camp := await _make_camp()
	assert_eq(str(camp.talks.get("wren_featherfoot", "")), "camp/wren:talk_knelt", "Wren, at camp, wants a word")
	var view := _view()
	var cell := ((camp.people["wren_featherfoot"] as Dictionary)["token"] as CombatToken).combatant.cell
	var thing := view.thing_at(cell)
	assert_eq(str(thing.get("kind", "")), "camper")
	assert_eq(str(thing.get("label", "")), "Wren wants a word")
	assert_true(((camp.people["wren_featherfoot"] as Dictionary)["token"] as Node).has_node("WantsAWord"), "a mark over him")
	view.interact(thing)
	await _frames(2)
	assert_true(root.get("dialogue") != null, "the talk begins")
	assert_true(bool(GameState.story.flags.get("_camp/camp/wren:talk_knelt", false)), "and plays once")
	assert_false(camp.talks.has("wren_featherfoot"), "one word each this evening")
	# Someone with nothing particular to say: the Narrator says what they're about.
	(root.get("dialogue") as Node).queue_free()
	root.set("dialogue", null)
	ModeController.force(ModeController.Mode.EXPLORATION)
	var said: Array[String] = []
	view.narration.connect(func(t: String) -> void: said.append(t))
	camp.talk("liriel_dawnsong")
	assert_eq(said.size(), 1, "a line about Liriel")
	assert_true(said[0].contains("Liriel"), said[0])


func test_sleeping_by_the_fire_is_the_long_rest_and_breaking_camp_packs_up() -> void:
	var godrick := GameState.story.party[0]
	godrick.hp = 3
	var camp := await _make_camp()
	camp.sleep()
	assert_true(camp.slept, "slept")
	assert_eq(godrick.hp, godrick.max_hp(), "rested")
	assert_true(GameState.story.flags.has(RestRules.DONE_AT), "the Long Rest is counted")
	assert_ne(camp.sleep_refusal(), "", "no second night")
	await _frames(2)
	camp.strike()
	await _frames(2)
	var view := _view()
	assert_true(LocationCamp.of(view) == null, "camp is struck")
	for p: Variant in view.loc["props"]:
		assert_false(bool((p as Dictionary).get("camp", false)), "nothing of the camp left: %s" % p)
	assert_true(GameState.story.camp_company.is_empty(), "Wren is back at camp, out of the story")
	var thistle := view.members[2]
	var before := thistle.cell
	view.walk_to(view.leader().cell + Vector2i(4, 0))
	await _frames(60)
	assert_ne(thistle.cell, before, "the party follows its leader again")


func test_indoors_the_long_rest_is_as_it_was() -> void:
	(Compendium.shared().tables["locations"][FIELD] as Dictionary)["map"]["outdoors"] = false
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	assert_true(_button(rest, "Make camp (8 hours)") == null, "no camp indoors")
	assert_true(_button(rest, "Take a Long Rest (8 hours)") != null, "the plain Long Rest")
