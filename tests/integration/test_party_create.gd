extends TestCase
## Creating a character from the party screen (owner, 2026-10-07): a custom character made at any time outside fights
## and conversations goes through the whole creator, starts at level 1, joins the party (or camp, when it's full) and
## takes the party's level on the level-up screen. A game holds up to four custom characters, the starting hero among
## them; they save and load with the game.

const LOC := {
	"id": "test_camp", "name": "Test Camp", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]}
}

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


## A finished level-1 custom character, as the creator makes one.
func _custom(name: String, portrait: String = "hero_01", class_id: String = "fighter") -> Character:
	var app := HeroLook.default_appearance("female", class_id)
	app["portrait"] = portrait
	app["art"] = portrait
	var b := CharacterBuilder.new(null, {"appearance": app})
	_fill(b, name, class_id)
	var ch := b.build_character()
	assert_true(ch != null, str(b.errors()))
	ch.finish_long_rest()
	return ch


func _fill(b: CharacterBuilder, name: String, class_id: String = "fighter") -> void:
	b.set_class(class_id)
	b.set_background("soldier")
	b.set_species("human")
	var missing := TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
		func(key: String, chosen: Array) -> void: b.choose(key, chosen))
	assert_true(missing.is_empty(), str(missing))
	b.set_name(name)


func _game(travelling: Array[String], camp: Array[String] = [], milestones: int = 0) -> StoryState:
	Compendium.shared().tables["locations"]["test_camp"] = LOC.duplicate(true)
	GameState.reset()
	var st := GameState.story
	for id in travelling:
		var ch := Pregens.build(id, 1 + milestones)
		ch.finish_long_rest()
		st.party.append(ch)
	for id in camp:
		st.bench.append(Pregens.build(id, 1 + milestones))
	st.milestones = milestones
	st.location = "test_camp"
	return st


func _open_world() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame


func _labels(n: Node) -> Array[String]:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b as Button
	return null


func test_a_new_character_joins_the_party_while_theres_room_else_camp() -> void:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"]:
		st.party.append(Pregens.build(id, 1))
	var mira := _custom("Mira Vell")
	assert_true(st.recruit(mira), "a fourth joins the road")
	assert_eq(st.party[3], mira)
	var oskar := _custom("Oskar Brann", "hero_02")
	assert_false(st.recruit(oskar), "a fifth waits at camp")
	assert_true(oskar in st.bench)
	assert_eq(st.custom_members().size(), 2)


func test_every_member_of_the_company_has_an_id_of_their_own() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("ilse_varga", 1))
	var a := _custom("Mira Vell")
	var b := _custom("Mira Vell", "hero_03")
	st.recruit(a)
	st.recruit(b)
	assert_ne(a.id, b.id, "two characters never share the id their figures and voices are found by")
	assert_ne(a.id, "ilse_varga")


func test_a_game_holds_four_custom_characters_the_starting_hero_among_them() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("ilse_varga", 1))
	st.party.append(_custom("Vasha Dunmere"))
	assert_eq(st.create_blocker(), "", "the starting hero leaves room for three more")
	for n: Array in [["Mira Vell", "hero_02"], ["Oskar Brann", "hero_03"]]:
		st.recruit(_custom(str(n[0]), str(n[1])))
	assert_eq(st.create_blocker(), "")
	st.recruit(_custom("Dorota Kask", "hero_04"))
	assert_eq(st.custom_members().size(), StoryState.CUSTOM_CAP)
	assert_ne(st.create_blocker(), "", "the fifth is refused, with the reason")
	assert_true(str(StoryState.CUSTOM_CAP) in st.create_blocker())
	st.send_to_camp(st.party[1])
	assert_ne(st.create_blocker(), "", "those at camp still count")


func test_a_new_character_takes_the_partys_level_one_level_at_a_time() -> void:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		st.party.append(Pregens.build(id, 4))
	st.milestones = 3
	var mira := _custom("Mira Vell")
	st.recruit(mira)
	assert_eq(mira.character_level(), 1, "made at level 1")
	assert_eq(st.levels_waiting(mira), 3, "three levels wait to match the party's 4")
	while st.can_level_up(mira):
		var up := LevelUpController.new(mira)
		up.choose_class("fighter")
		up.take_fixed_hit_points()
		TestChars.auto_pick(up.pending_choices, up.choose)
		assert_true(up.confirm(), str(up.errors()))
	assert_eq(mira.character_level(), st.party[0].character_level(), "level with the party")


func test_a_name_the_company_already_has_is_taken() -> void:
	var b := CharacterBuilder.new(null, {"appearance": HeroLook.default_appearance("female", "fighter")})
	b.taken_names = ["Mira Vell", "Ilse Varga"]
	_fill(b, "Mira Vell")
	assert_false(b.errors().is_empty(), "Mira is already in the company")
	b.set_name("Mira Dunn")
	assert_true(b.errors().is_empty(), str(b.errors()))


func test_custom_characters_save_and_load_with_their_own_look() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("thistle", 3))
	var mira := _custom("Mira Vell", "hero_05")
	var app := (mira.build["appearance"] as Dictionary).duplicate()
	app.merge({"hair": "wavy", "hair_colour": "auburn"}, true)
	mira.build["appearance"] = app
	st.recruit(mira)
	for n: Array in [["Oskar Brann", "hero_02"], ["Dorota Kask", "hero_03"], ["Lev Sarn", "hero_04"]]:
		st.recruit(_custom(str(n[0]), str(n[1])))
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(back.party.size(), 4)
	assert_eq(back.bench.size(), 1, "the one at camp comes back at camp")
	assert_eq(back.custom_members().size(), 4)
	var mira2 := back.party[1]
	assert_eq(mira2.id, mira.id)
	assert_eq(mira2.build["appearance"], app, "the look the player made, not a roster hero's")
	assert_eq(CombatToken.art_for(mira2), "hero_05")
	assert_ne(back.create_blocker(), "", "the cap holds after a load")


func test_a_save_with_no_custom_characters_still_loads() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("thistle", 2))
	var d := JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary
	d.erase("bench")
	var back := StoryState.from_dict(d)
	assert_eq(back.party.size(), 1)
	assert_eq(back.custom_members().size(), 0)
	assert_eq(back.create_blocker(), "")


func test_the_party_screen_creates_a_character_who_can_level_up_at_once() -> void:
	var st := _game(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow"], [], 2)
	await _open_world()
	root.call("open_screen", "party", 0)
	await get_tree().process_frame
	var create := _button(root.get("screen") as Node, "Create a character")
	assert_true(create != null, "the party screen offers it")
	assert_false(create.disabled, "outside fights and conversations")
	assert_true("Custom characters 0 of 4" in _labels(root.get("screen") as Node))
	create.pressed.emit()
	await get_tree().process_frame
	var cs := root.get("screen") as CreationScreen
	assert_true(cs != null, "the creator opens")
	assert_eq(cs.builders.size(), 1)
	assert_true(HeroLook.is_custom(cs.b().preview()), "with the paper doll, as for the hero")
	for step in CharacterBuilder.STEP_NAMES.size():
		cs.step = step
		cs.call("_draw")
	_fill(cs.b(), "Mira Vell")
	assert_true(cs.b().errors().is_empty(), str(cs.b().errors()))
	cs.confirmed[0] = true
	cs.call("_finish")
	await get_tree().process_frame
	assert_eq(st.party.size(), 4, "she joins the road")
	var mira := st.party[3]
	assert_eq(mira.name, "Mira Vell")
	assert_eq(mira.character_level(), 1)
	var view := root.get("view") as LocationView
	assert_eq(view.members.size(), 4, "with a figure of her own")
	var party := root.get("screen") as PartyScreen
	assert_true(party != null, "back on the party screen")
	assert_true("▲ 2 level ups waiting" in _labels(party), "her levels wait on her card")
	root.call("open_screen", "level_up", 3)
	await get_tree().process_frame
	var up := root.get("screen") as LevelUpScreen
	assert_eq(up.ch, mira, "the level-up screen opens for her")
	TestChars.auto_pick(up.ctl.pending_choices, up.ctl.choose)
	up.call("_confirm")
	await get_tree().process_frame
	assert_eq(mira.character_level(), 2)
	assert_true(root.get("screen") is LevelUpScreen, "the next level opens straight away")


func test_with_the_party_full_the_new_character_waits_at_camp_ready_to_swap_in() -> void:
	var st := _game(["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"])
	await _open_world()
	root.call("open_screen", "create", 0)
	await get_tree().process_frame
	var cs := root.get("screen") as CreationScreen
	_fill(cs.b(), "Oskar Brann")
	cs.confirmed[0] = true
	cs.call("_finish")
	await get_tree().process_frame
	assert_eq(st.party.size(), 4)
	assert_eq(st.bench.size(), 1, "he waits at camp")
	var roster := root.get("screen") as RosterScreen
	assert_true(roster != null, "the roster screen opens")
	assert_true("Choose whose place Oskar takes." in _labels(roster), "with him picked to swap in")


func test_back_from_the_creator_returns_to_the_party() -> void:
	var st := _game(["ilse_varga", "tamsin_tealeaf"])
	await _open_world()
	root.call("open_screen", "create", 0)
	await get_tree().process_frame
	var cs := root.get("screen") as CreationScreen
	cs.cancelled.emit()
	await get_tree().process_frame
	assert_true(root.get("screen") is PartyScreen, "the party screen again")
	assert_eq(st.roster().size(), 2, "nobody new")


func test_portraits_and_names_the_company_has_are_taken() -> void:
	var st := _game(["ilse_varga"])
	var vasha := _custom("Vasha Dunmere", "hero_01")
	st.party.append(vasha)
	await _open_world()
	root.call("open_screen", "create", 0)
	await get_tree().process_frame
	var cs := root.get("screen") as CreationScreen
	var app := cs.b().build["appearance"] as Dictionary
	assert_ne(str(app["portrait"]), "hero_01", "a new face by default")
	assert_eq(str(app["art"]), str(app["portrait"]))
	assert_eq(str(cs.taken_portraits.get("hero_01", "")), "Vasha Dunmere")
	_fill(cs.b(), "Vasha Dunmere")
	assert_false(cs.b().errors().is_empty(), "Vasha's name is taken")
	cs.step = CharacterBuilder.Step.APPEARANCE
	cs.set("_appearance_tab", "Portrait & voice")
	cs.call("_draw")
	await get_tree().process_frame
	var worn: Button = null
	for b in cs.find_children("*", "Button", true, false):
		if (b as Button).tooltip_text == "Vasha Dunmere wears this portrait.":
			worn = b as Button
	assert_true(worn != null and worn.disabled, "her portrait shows as worn")


func test_the_create_option_stays_visible_but_says_why_once_four_are_made() -> void:
	var st := _game(["ilse_varga"])
	for n: Array in [["Vasha Dunmere", "hero_01"], ["Mira Vell", "hero_02"], ["Oskar Brann", "hero_03"], ["Lev Sarn", "hero_04"]]:
		st.recruit(_custom(str(n[0]), str(n[1])))
	await _open_world()
	root.call("open_screen", "party", 0)
	await get_tree().process_frame
	var party := root.get("screen") as Node
	var create := _button(party, "Create a character")
	assert_true(create != null, "still shown")
	assert_true(create.disabled, "but off")
	assert_true(st.create_blocker() in _labels(party), "with the reason beside it")
	assert_true("Custom characters 4 of 4" in _labels(party))


func test_no_new_character_in_a_fight() -> void:
	_game(["ilse_varga", "tamsin_tealeaf"])
	await _open_world()
	var was := ModeController.mode
	ModeController.mode = ModeController.Mode.COMBAT
	root.call("open_screen", "party", 0)
	await get_tree().process_frame
	var create := _button(root.get("screen") as Node, "Create a character")
	assert_true(create.disabled)
	assert_true("Not in the middle of a fight or a conversation." in _labels(root.get("screen") as Node))
	ModeController.mode = was
