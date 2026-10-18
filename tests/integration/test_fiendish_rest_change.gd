extends TestCase
## Changing Fiendish Resilience after a rest, found and done through the rest screen (owner report 2026-10-18). A Fiend
## Warlock chooses a damage type to resist after a Short or a Long Rest and keeps it until they choose again: the rest
## screen's button names it, the screen it opens says what it is, the line after the rest tells the player, and a Short
## Rest's change is still there when the rest screen is closed and opened again.

const KEY := "fiend_patron.10.fiendish_resilience"

var root: Node


func before_each() -> void:
	for id: String in ["test_hall", "test_hall_two"]:
		Compendium.shared().tables["locations"][id] = {"id": id, "name": "Test Hall", "region": "test", "summary": "",
			"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var kip := Pregens.build("kip_smudgewick", 10)
	kip.finish_long_rest()
	GameState.story.party.append(kip)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	for id: String in ["test_hall", "test_hall_two"]:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


func _says(screen: Node, text: String) -> bool:
	return screen.find_children("*", "Label", true, false).any(func(l: Node) -> bool:
		return (l as Label).text.contains(text) and not l.is_queued_for_deletion())


func _rest() -> RestScreen:
	root.call("open_screen", "rest", 0)
	await _frames(2)
	return root.get("screen") as RestScreen


func _widget(n: Node) -> ChoiceWidget:
	for w in n.find_children("*", "ChoiceWidget", true, false):
		if (w as ChoiceWidget).choice.key == KEY and not (w as Node).is_queued_for_deletion():
			return w as ChoiceWidget
	return null


## Opens the rest screen's change button and picks `type` on its screen; returns the PrepareScreen.
func _change_to(rest: RestScreen, button: String, type: String) -> PrepareScreen:
	var b := _button(rest, button)
	assert_true(b != null, "a button called %s" % button)
	b.pressed.emit()
	await _frames(2)
	var ps := rest.find_children("*", "PrepareScreen", true, false)[0] as PrepareScreen
	var w := _widget(ps)
	assert_true(w != null, "Fiendish Resilience's widget is on the screen")
	var kip := GameState.story.party[0]
	var was := kip.picks_for(KEY)[0]
	w.call("_toggle", was, false)
	await _frames(2)
	w = _widget(ps)
	w.call("_toggle", type, true)
	await _frames(2)
	return ps


func test_after_a_short_rest_the_button_the_line_and_the_screen_name_it() -> void:
	var rest := await _rest()
	assert_true(_button(rest, "Change Fiendish Resilience") == null, "nothing before a rest")
	rest.call("_finish_short")
	await _frames(2)
	assert_true(_button(rest, "Change Fiendish Resilience") != null, "the button says what it changes")
	assert_true(_says(rest, "You can change Fiendish Resilience now"), "and the log says so")
	var kip := GameState.story.party[0]
	assert_eq(kip.picks_for(KEY), ["acid"] as Array[String], "Kip starts resisting acid")
	assert_eq(kip.resistance_source(&"cold"), "", "and not to Cold (a Tiefling's Fire is the species', not the feature's)")
	var ps := await _change_to(rest, "Change Fiendish Resilience", "cold")
	assert_true(_says(ps, "Change Fiendish Resilience"), "the screen is titled for it")
	assert_true(_says(ps, "damage type"), "and its intro explains it")
	assert_eq(kip.picks_for(KEY), ["cold"] as Array[String])
	assert_eq(kip.resistance_source(&"cold"), "Fiendish Resilience", "Resistance to Cold, from the feature")
	assert_eq(kip.resistance_source(&"acid"), "", "and no longer to Acid")


func test_the_short_rest_change_is_still_there_when_the_screen_is_opened_again() -> void:
	var rest := await _rest()
	rest.call("_finish_short")
	await _frames(2)
	root.call("close_screen")
	await _frames(2)
	rest = await _rest()
	assert_true(_button(rest, "Change Fiendish Resilience") != null, "a new screen, the same chance")
	var ps := await _change_to(rest, "Change Fiendish Resilience", "cold")
	assert_eq((GameState.story.party[0]).resistance_source(&"cold"), "Fiendish Resilience", "and it still works")
	ps.free()
	root.call("close_screen")
	await _frames(2)
	GameState.story.advance_minutes(RestRules.CHANGE_MINUTES + 1)
	rest = await _rest()
	assert_true(_button(rest, "Change Fiendish Resilience") == null, "an hour on, the chance has passed")


func test_moving_on_closes_the_short_rest_change() -> void:
	var rest := await _rest()
	rest.call("_finish_short")
	await _frames(2)
	root.call("close_screen")
	await _frames(2)
	GameState.story.location = "test_hall_two"
	rest = await _rest()
	assert_true(_button(rest, "Change Fiendish Resilience") == null, "the party is somewhere else")


func test_after_a_long_rest_it_changes_too() -> void:
	var rest := await _rest()
	rest.call("_long_rest", "safe")
	await _frames(2)
	assert_true(_button(rest, "Change Fiendish Resilience") != null, "a Fiend Warlock alone: just that")
	assert_true(_button(rest, "Change prepared spells") == null, "no spells to prepare, so none promised")
	assert_true(_says(rest, "You can change Fiendish Resilience now"))
	var ps := await _change_to(rest, "Change Fiendish Resilience", "psychic")
	assert_true(_says(ps, "Change Fiendish Resilience"))
	assert_eq((GameState.story.party[0]).resistance_source(&"psychic"), "Fiendish Resilience", "Resistance to Psychic")
	assert_eq((GameState.story.party[0]).resistance_source(&"acid"), "")


func test_a_mixed_party_is_told_both() -> void:
	var hedda := Pregens.build("hedda_ironvow", 3)
	hedda.finish_long_rest()
	GameState.story.party.append(hedda)
	var rest := await _rest()
	rest.call("_long_rest", "safe")
	await _frames(2)
	assert_true(_button(rest, "Change prepared spells and Fiendish Resilience") != null, "both are named")
	assert_true(_says(rest, "You can change prepared spells and Fiendish Resilience now"))


## The saved game with the Resistance as the screen left it.
func _saved_and_loaded() -> Character:
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.from_dict(saved)
	return GameState.story.party[0]


func test_a_change_after_a_short_rest_survives_a_save_and_load() -> void:
	var rest := await _rest()
	rest.call("_finish_short")
	await _frames(2)
	await _change_to(rest, "Change Fiendish Resilience", "lightning")
	var back := _saved_and_loaded()
	assert_eq(back.picks_for(KEY), ["lightning"] as Array[String])
	assert_eq(back.resistance_source(&"lightning"), "Fiendish Resilience", "Resistance to Lightning")
	assert_eq(back.resistance_source(&"acid"), "", "the old one is gone")
	assert_false(RestRules.short_change(GameState.story).is_empty(), "and the chance to change it again is saved too")


func test_a_change_after_a_long_rest_survives_a_save_and_load() -> void:
	var rest := await _rest()
	rest.call("_long_rest", "safe")
	await _frames(2)
	await _change_to(rest, "Change Fiendish Resilience", "thunder")
	var back := _saved_and_loaded()
	assert_eq(back.picks_for(KEY), ["thunder"] as Array[String])
	assert_eq(back.resistance_source(&"thunder"), "Fiendish Resilience", "Resistance to Thunder")
	assert_eq(back.resistance_source(&"acid"), "", "the old one is gone")


func test_a_long_rest_after_a_short_one_keeps_the_choice_and_offers_it_again() -> void:
	var rest := await _rest()
	rest.call("_finish_short")
	await _frames(2)
	await _change_to(rest, "Change Fiendish Resilience", "cold")
	for ps in rest.find_children("*", "PrepareScreen", true, false):
		ps.free()
	GameState.story.advance_minutes(17 * 60)   # the 16 hours between Long Rests
	rest.call("_long_rest", "safe")
	await _frames(2)
	var kip := GameState.story.party[0]
	assert_eq(kip.picks_for(KEY), ["cold"] as Array[String], "a Long Rest does not undo the choice")
	assert_eq(kip.resistance_source(&"cold"), "Fiendish Resilience")
	await _change_to(rest, "Change Fiendish Resilience", "radiant")
	assert_eq(kip.resistance_source(&"radiant"), "Fiendish Resilience", "and it can be changed again")
	assert_eq(kip.resistance_source(&"cold"), "", "the old one gone")
