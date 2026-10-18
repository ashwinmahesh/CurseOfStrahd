extends TestCase
## Guests are interactable (owner, 2026-10-17: "Pidlwick is in my party, and I now have the key. How do I give it to him?
## We should make NPCs interactable if they're with the party"): Pidlwick II walks with the party, and his figure, his card on
## the HUD and his card on the Party screen all open the same choices (Talk, Give..., Send home). Pidlwick's key goes from
## the pack to his back end to end, through a click on him, through Give..., and through the Party screen.

const ROOM := {
	"id": "test_guest_room", "name": "Test Guest Room", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"#............#",
		"##############"], "light": "dim"},
	"spawns": {"default": [6, 3]},
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_guest_room"] = ROOM.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.add_guest("pidlwick_ii")
	GameState.story.set_flag("pidlwick_met")
	GameState.story.location = "test_guest_room"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	Compendium.shared().tables["locations"].erase("test_guest_room")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _dialogue() -> DialogueUI:
	return root.get("dialogue") as DialogueUI


func _guest_cell() -> Vector2i:
	return _view().guest_members[0].cell


func _found_the_key() -> void:
	var st := GameState.story
	st.set_flag("pidlwick_key_found")
	st.set_quest_stage("the_jesters_key", "found")
	st.gain_item("pidlwicks_key", 1, st.party[0])


func _keys() -> int:
	var n := 0
	for ch in GameState.story.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == "pidlwicks_key":
				n += int(e.get("qty", 1))
	return n


## Picks the conversation's option whose words contain `text`.
func _pick(text: String) -> void:
	var d := _dialogue()
	for i in 12:
		if d == null or not d.options_shown.is_empty():
			break
		d.call("_advance")   # his lines first
		await _frames(1)
	for i in d.options_shown.size():
		if str((d.options_shown[i] as Dictionary)["text"]).contains(text):
			d.call("_choose", i)
			await _frames(1)
			return
	fail("no option '%s' among %s" % [text, d.options_shown.map(func(o: Variant) -> String: return str((o as Dictionary)["text"]))])


func test_he_is_a_thing_in_the_world_with_a_menu() -> void:
	var v := _view()
	assert_eq(v.guest_members.size(), 1, "he walks with the party")
	var thing := v.thing_at(_guest_cell())
	assert_eq(str(thing.get("kind", "")), "guest")
	assert_eq(str(thing.get("id", "")), "pidlwick_ii")
	assert_eq(str(thing.get("label", "")), "Talk to Pidlwick II")
	assert_eq(Cursors.for_thing(thing), "talk", "the talk cursor, like anyone else")
	var menu := v.actions_at(_guest_cell())
	assert_eq(str(menu["title"]), "Pidlwick II")
	var ids: Array[String] = []
	for a: Dictionary in menu["actions"]:
		ids.append(str(a["id"]))
	assert_true("guest_talk:pidlwick_ii" in ids and "guest_give:pidlwick_ii" in ids and "guest_home:pidlwick_ii" in ids and "look" in ids, str(ids))


func test_the_pad_can_mark_him() -> void:
	var v := _view()
	v.leader().cell = _guest_cell() + Vector2i(1, 0)
	var things := root.get("pad").call("things") as Array
	assert_true(_guest_cell() in things, "the controller marks him like any other thing (%s in %s)" % [_guest_cell(), things])


func test_clicking_him_opens_his_conversation_and_the_key_goes_back_through_it() -> void:
	_found_the_key()
	var v := _view()
	var cell := _guest_cell()
	v.click(cell)
	for i in 80:
		if _dialogue() != null:
			break
		LocationWalk.tick(v, 0.3)
		v._process(0.3)
		await _frames(1)
	assert_true(_dialogue() != null, "a click on him starts a conversation")
	assert_eq(str(root.get("_dialogue_ref")), "castle_ravenloft/spires_pidlwick:companion")
	await _pick("We found your key")
	await _pick("Nothing. Let's go.")   # through his thanks (and the key leaving the pack, his present coming) to the menu again
	assert_true(bool(GameState.story.get_flag("pidlwick_wound", false)), "he is wound")
	assert_eq(GameState.story.quest_stage("the_jesters_key"), "returned")
	assert_eq(_keys(), 0, "the key left the pack")
	assert_true(GameState.story.party_has_item("figurine_of_wondrous_power_ebony_fly"), "and his present is the party's")
	await _frames(2)
	assert_true(_dialogue() == null, "the conversation has its exit")
	assert_true("pidlwick_ii" in GameState.story.guest_ids, "and he is still with the party")


func test_give_hands_over_the_key_without_a_conversation_first() -> void:
	_found_the_key()
	assert_eq(_keys(), 1, "the key is in the pack, an item to see")
	root.call("world_action", _guest_cell(), "guest_give:pidlwick_ii")
	await _frames(1)
	var picker := root.get("_prompting") as GiftPicker
	assert_true(picker != null, "the picker lists what he can be handed")
	assert_eq(picker.gifts.size(), 1)
	assert_eq(str(picker.gifts[0]["label"]), "The brass wind-up key")
	picker.choices[0].pressed.emit()
	await _frames(2)
	assert_true(root.get("_prompting") == null)
	assert_true(_dialogue() != null, "he answers")
	assert_eq(str(root.get("_dialogue_ref")), "castle_ravenloft/spires_pidlwick:key_back")
	await _pick("Nothing. Let's go.")
	assert_true(bool(GameState.story.get_flag("pidlwick_wound", false)))
	assert_eq(_keys(), 0)


func test_give_says_so_when_there_is_nothing_to_give() -> void:
	root.call("give_to_guest", "pidlwick_ii")
	await _frames(1)
	assert_true(root.get("_prompting") == null, "no empty picker")
	assert_true(_dialogue() == null)


func test_his_card_on_the_hud_opens_the_menu() -> void:
	var hud := root.get("hud") as ExploreHud
	var card := hud.find_child("Guest_pidlwick_ii", true, false) as Button
	assert_true(card != null, "his card can be clicked")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card.gui_input.emit(ev)
	await _frames(1)
	var menu := root.get("menu") as ContextMenu
	var labels: Array[String] = []
	for i in menu.item_count:
		labels.append(menu.get_item_text(i))
	assert_true("Talk" in labels and "Give..." in labels and "Send home" in labels, str(labels))
	menu.hide()


func test_his_card_on_the_party_screen_talks_and_gives() -> void:
	root.call("open_screen", "party", 0)
	await _frames(3)
	var screen := root.get("screen") as Node
	var talk := screen.find_child("Talk_pidlwick_ii", true, false) as Button
	var give := screen.find_child("Give_pidlwick_ii", true, false) as Button
	assert_true(talk != null and give != null, "Talk and Give... beside Send home")
	assert_true(give.disabled, "nothing to give yet, and the tooltip says what to do about potions: %s" % give.tooltip_text)
	assert_true(give.tooltip_text.contains("Potions"))
	_found_the_key()
	root.call("open_screen", "party", 0)
	await _frames(3)
	screen = root.get("screen") as Node
	give = screen.find_child("Give_pidlwick_ii", true, false) as Button
	assert_false(give.disabled, "the key is his")
	talk = screen.find_child("Talk_pidlwick_ii", true, false) as Button
	talk.pressed.emit()
	await _frames(2)
	assert_true(root.get("screen") == null, "the screen steps aside")
	assert_true(_dialogue() != null, "and he speaks")


func test_send_home_from_the_menu() -> void:
	root.call("world_action", _guest_cell(), "guest_home:pidlwick_ii")
	await _frames(2)
	assert_false("pidlwick_ii" in GameState.story.guest_ids, "he waits where he was found")
	assert_true(_view().guest_members.is_empty())


func test_a_guest_with_nothing_of_his_own_says_a_road_line() -> void:
	GameState.story.add_guest("adrian_martikov")
	_view().place_guests()
	var lines: Array = []
	_view().banter.connect(func(l: Array) -> void: lines.append(l))
	var adrian_cell := Vector2i(-1, -1)
	for g in _view().guest_members:
		if g.creature == GameState.story.guests[1]:
			adrian_cell = g.cell
	assert_ne(adrian_cell, Vector2i(-1, -1))
	LocationGuests.talk(_view(), "adrian_martikov")
	assert_eq(lines.size(), 1, "one of his lines came out")
	for l: Dictionary in lines[0]:
		assert_eq(str(l["speaker_id"]), "adrian_martikov")
