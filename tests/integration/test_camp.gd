extends TestCase
## The camp (F16, world/exploration/location_camp.gd): a Long Rest wherever the place's own rest is risky makes camp
## near the party, the company sits round the fire (those waiting at camp too), walking up to someone who wants a word
## starts their talk, sleeping is the Long Rest, and breaking camp packs it away. Indoors there's no tent and the
## Narrator speaks of walls, not trees; a cramped room makes a smaller camp; with nowhere for a fire the party sleeps
## where it stands. A safe place and a booked room keep the rest screen. The party plays on Story, whose safe rests
## keep the nights quiet and don't stop the camp.

var root: Node
const FIELD := "test_camp_field"
const ROOM := "test_camp_room"


func before_each() -> void:
	var rows: Array = []
	for z in 14:
		rows.append("#".repeat(20) if z == 0 or z == 13 else "#" + ".".repeat(18) + "#")
	Compendium.shared().tables["locations"][FIELD] = {"id": FIELD, "name": "Test Field", "region": "svalich_road",
		"summary": "", "map": {"rows": rows, "outdoors": true, "theme": "forest"}, "spawns": {"default": [9, 7]}, "rest": "risky"}
	GameState.reset()
	GameState.story.options["difficulty"] = "story"
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
	(Compendium.shared().tables["locations"] as Dictionary).erase(ROOM)


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
	assert_true(make != null and not make.disabled, "the Long Rest makes camp here")
	if make != null:
		make.pressed.emit()
	await _frames(2)
	return LocationCamp.of(_view())


## Walks the party into a room of `rows` (indoors), standing at `at`.
func _enter_room(rows: Array, at: Array) -> void:
	Compendium.shared().tables["locations"][ROOM] = {"id": ROOM, "name": "Test Room", "region": "village_of_barovia",
		"summary": "", "map": {"rows": rows, "outdoors": false, "theme": "manor"}, "spawns": {"default": at}, "rest": "risky"}
	root.call("enter_location", ROOM, "default")
	await _frames(3)


## Everyone at camp has a square of their own, off the fire and the camp's pieces.
func _assert_everyone_has_a_square(camp: LocationCamp) -> void:
	var view := _view()
	var used := {}
	for p: Variant in view.loc["props"]:
		var prop := p as Dictionary
		if bool(prop.get("camp", false)):
			used[Vector2i(int((prop["cell"] as Array)[0]), int((prop["cell"] as Array)[1]))] = prop["id"]
	for id: String in camp.people:
		var cell := ((camp.people[id] as Dictionary)["token"] as CombatToken).combatant.cell
		assert_false(used.has(cell), "%s has a square of their own (%s), not %s's" % [id, cell, used.get(cell, "")])
		assert_true(view.grid.flags(cell) & CombatGrid.WALL == 0, "%s isn't in a wall" % id)
		used[cell] = id


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


## Thistle walks with the party, so her mark hangs on the view's own figure, which outlives the camp (owner,
## 2026-10-13: it stayed over her after camp was broken).
func test_breaking_camp_without_a_word_takes_the_mark_down_and_the_word_waits() -> void:
	GameState.story.set_flag("strahd_knelt", "thistle")
	var camp := await _make_camp()
	var view := _view()
	assert_eq(str(camp.talks.get("thistle", "")), "camp/thistle:talk_knelt", "Thistle, in the party, wants a word")
	var tok := view.tokens["thistle"] as Node3D
	assert_true(tok.has_node("WantsAWord"), "a mark over her")
	view.in_combat = true
	await _frames(1)
	assert_false((tok.get_node("WantsAWord") as Node3D).visible, "no mark in the middle of a fight")
	view.in_combat = false
	await _frames(1)
	assert_true((tok.get_node("WantsAWord") as Node3D).visible, "back once it's over")
	camp.strike()
	await _frames(2)
	assert_false(tok.has_node("WantsAWord"), "the mark goes with the camp")
	assert_true(view.find_children("WantsAWord", "", true, false).is_empty(), "no mark left over anyone")
	assert_false(bool(GameState.story.flags.get("_camp/camp/thistle:talk_knelt", false)), "her word still waits")
	camp = await _make_camp()
	assert_true(camp != null, "camp again")
	if camp != null:
		assert_eq(str(camp.talks.get("thistle", "")), "camp/thistle:talk_knelt", "she asks again at the next camp")
		assert_true((view.tokens["thistle"] as Node).has_node("WantsAWord"), "with her mark")


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


## The bar's "Change prepared spells" shows before the night too (owner's house rule, deviations.md: the spells a Long
## Rest lets casters change, any time outside a fight) and opens the any-time screen; in the morning it is the night's
## own, counted from the list the night ended with.
func test_the_camp_changes_prepared_spells_before_the_night_and_in_the_morning() -> void:
	var camp := await _make_camp()
	await _frames(3)
	var prepare := _visible_button(camp.bar, "Change prepared spells")
	assert_true(prepare != null, "offered at camp before sleeping")
	assert_true(camp.can_prepare())
	prepare.pressed.emit()
	await _frames(2)
	var screens := camp.bar.find_children("*", "PrepareScreen", true, false)
	assert_eq(screens.size(), 1)
	var ps := screens[0] as PrepareScreen
	assert_eq(ps.rest_kind, PrepareScreen.ANYTIME, "no rest needed")
	assert_true(ps.only == null, "for the whole party")
	assert_false(ps.find_children("*", "ChoiceWidget", true, false).is_empty(), "their lists")
	ps.free()
	camp.sleep()
	await _frames(3)
	prepare = _visible_button(camp.bar, "Change prepared spells")
	assert_true(prepare != null, "and in the morning")
	prepare.pressed.emit()
	await _frames(2)
	screens = camp.bar.find_children("*", "PrepareScreen", true, false)
	assert_eq(screens.size(), 1)
	assert_eq((screens[0] as PrepareScreen).rest_kind, "long_rest", "the morning's change is counted from the night's list")
	assert_false((screens[0] as PrepareScreen).earlier.is_empty())
	screens[0].free()


func _visible_button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree() and not b.is_queued_for_deletion():
			return b as Button
	return null


func test_a_safe_place_or_a_room_booked_for_the_night_keeps_the_rest_screen() -> void:
	(Compendium.shared().tables["locations"][FIELD] as Dictionary)["rest"] = "safe"
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	assert_true(_button(rest, "Make camp (8 hours)") == null, "no camp in a safe place")
	assert_true(_button(rest, "Take a Long Rest (8 hours)") != null, "the plain Long Rest")
	root.call("close_screen")
	await _frames(1)
	(Compendium.shared().tables["locations"][FIELD] as Dictionary)["rest"] = "risky"
	var st := GameState.story
	st.set_flag("_room", {"id": "room_modest", "location": st.location, "day": st.day})
	root.call("open_screen", "rest", 0)
	await _frames(1)
	rest = root.get("screen") as RestScreen
	assert_true(_button(rest, "Make camp (8 hours)") == null, "a room is booked here: no camp")
	assert_true(_button(rest, "Take a Long Rest (8 hours)") != null, "the night in the room")


func test_indoors_the_camp_has_no_tent_and_the_fire_lights_the_walls() -> void:
	var rows: Array = []
	for z in 12:
		rows.append("#".repeat(16) if z == 0 or z == 11 else "#" + ".".repeat(14) + "#")
	await _enter_room(rows, [7, 6])
	var camp := await _make_camp()
	assert_true(camp != null, "camp is made indoors")
	if camp == null:
		return
	assert_eq(camp.setting, CampSite.INDOORS)
	var view := _view()
	var fire: Dictionary = {}
	for p: Variant in view.loc["props"]:
		var prop := p as Dictionary
		if bool(prop.get("camp", false)):
			assert_ne(str(prop["model"]), "tent", "no tent under a roof")
			if str(prop["id"]) == "camp_fire":
				fire = prop
	assert_false(fire.is_empty(), "a fire on the floor")
	_assert_everyone_has_a_square(camp)
	var said: Array[String] = []
	view.narration.connect(func(t: String) -> void: said.append(t))
	GameState.story.minute_of_day = 12 * 60   # by day, the fire's plain line
	LocationInteraction._use_prop(view, fire)
	assert_eq(said.size(), 1, "the fire is looked at")
	assert_true(said[0].contains("walls"), "its light on the walls, not the trees: %s" % [said])


func test_a_cramped_room_makes_a_smaller_camp() -> void:
	await _enter_room(["#########", "#.......#", "#.......#", "#########"], [3, 1])
	var camp := await _make_camp()
	assert_true(camp != null, "camp is made in a narrow room")
	if camp == null:
		return
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot"]:
		assert_true(camp.people.has(id), "%s is at camp" % id)
	_assert_everyone_has_a_square(camp)
	camp.sleep()
	assert_true(camp.slept, "the night is slept there")


func test_with_nowhere_for_a_fire_the_party_sleeps_where_it_stands() -> void:
	await _enter_room(["#######", "#~~~~~#", "#~~~~~#", "#~~~~~#", "#######"], [3, 2])
	root.call("open_screen", "rest", 0)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	var make := _button(rest, "Make camp (8 hours)")
	assert_true(make != null, "the Long Rest means to make camp")
	if make == null:
		return
	make.pressed.emit()
	await _frames(2)
	assert_true(LocationCamp.of(_view()) == null, "no camp in the rubble")
	assert_true(root.get("screen") == rest, "the rest screen stays")
	assert_true(GameState.story.flags.has(RestRules.DONE_AT), "the Long Rest is taken there")
	var log := rest.get("_log") as Label
	assert_true(log.text.begins_with(RestScreen.NO_ROOM), "and the log says why: %s" % log.text)
