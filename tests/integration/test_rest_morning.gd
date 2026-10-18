extends TestCase
## The hour after a Long Rest (lane 24, the rest screen's gaps; story/long_rest.gd): opened again within it, the rest
## screen still offers the companions' words and the change of prepared spells, whatever closed it (Strahd's night
## visit waits for it now); closing it with a word waiting says where to hear it; and a magic item's safe rest is the
## same Long Rest as any other.

var root: Node
const HALL := "test_morning_hall"


func before_each() -> void:
	Compendium.shared().tables["locations"][HALL] = {"id": HALL, "name": "Test Hall", "region": "svalich_road",
		"summary": "", "map": {"rows": ["#######", "#.....#", "#.....#", "#######"]}, "spawns": {"default": [2, 1]},
		"rest": "safe"}
	GameState.reset()
	for id: String in ["thistle", "liriel_dawnsong", "godrick_pendlebrook", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.set_flag("strahd_knelt", "thistle")   # Thistle has a word to say after the next rest
	GameState.story.location = HALL
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(2)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
		await _frames(3)
	(Compendium.shared().tables["locations"] as Dictionary).erase(HALL)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b.is_queued_for_deletion():
			return b as Button
	return null


func _rest_screen() -> RestScreen:
	root.call("open_screen", "rest", 0)
	await _frames(1)
	return root.get("screen") as RestScreen


func test_the_morning_keeps_the_rest_screens_offers() -> void:
	var rest := await _rest_screen()
	rest.call("_long_rest", "safe")
	await _frames(1)
	assert_true(_button(rest, "Thistle wants a word") != null, "her word, as the rest ends")
	root.call("close_screen")
	await _frames(2)
	rest = await _rest_screen()
	assert_true(_button(rest, "Thistle wants a word") != null, "still there when the screen opens again")
	assert_true(_button(rest, "Change prepared spells") != null, "and the change of prepared spells")
	root.call("close_screen")
	await _frames(2)
	GameState.story.advance_minutes(LongRest.MORNING_MINUTES + 1)
	rest = await _rest_screen()
	assert_true(_button(rest, "Thistle wants a word") == null, "the morning is over: she'll ask at the next rest")
	assert_true(_button(rest, "Change prepared spells") == null, "and the chance to change spells has passed")


func test_closing_with_a_word_waiting_says_where_to_hear_it() -> void:
	var st := GameState.story
	assert_eq(RestScreen.talk_hint(st), "", "no rest yet")
	var rest := await _rest_screen()
	rest.call("_long_rest", "safe")
	assert_true(RestScreen.talk_hint(st).begins_with("Thistle wants a word: open Rest"), RestScreen.talk_hint(st))
	CampTalk.mark(st, "camp/thistle:talk_knelt")
	assert_eq(RestScreen.talk_hint(st), "", "once she's had her word")


func test_a_magic_items_safe_rest_is_a_full_long_rest() -> void:
	var st := GameState.story
	var thistle := st.party[0]
	thistle.add_item("rod_of_security")
	st.add_guest("ismark")
	var ismark := st.guests[0]
	ismark.hp = 1
	st.miles_since_long_rest = 7.0
	root.call("open_screen", "inventory", 0)
	await _frames(1)
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "rod_of_security"
	inv.call("_use_power", "paradise", {})
	await _frames(1)
	assert_eq(ismark.hp, ismark.max_hp(), "the guest slept too")
	assert_eq(st.miles_since_long_rest, 0.0, "the miles walked since are behind them")
	assert_true(LongRest.morning_open(st), "its morning, as any Long Rest's")
	var said := inv.find_children("*", "Label", true, false).any(func(l: Node) -> bool:
		return (l as Label).text.contains("Thistle wants a word"))
	assert_true(said, "and where to hear the word waiting")
	root.call("close_screen")
	await _frames(2)
	var rest := await _rest_screen()
	assert_true(_button(rest, "Thistle wants a word") != null, "the rest screen has it")
