extends TestCase
## The new game's party pick (owner, 2026-10-07: "there's no way to go back", "I can't see the button to create my
## character"): every card, the create-your-own card, Back and Begin fit on screen, and Back and Escape leave the pick
## and the hero creator.

var menu: Control


func before_each() -> void:
	menu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	await get_tree().process_frame


func after_each() -> void:
	if menu != null:
		menu.queue_free()
		menu = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			out.append(b as Button)
	return out


func _button(text: String) -> Button:
	for b in _buttons():
		if b.text == text:
			return b
	return null


func _escape() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)


func test_the_pick_fits_and_goes_back() -> void:
	menu.call("_new_game")
	await _frames(3)
	var screen := menu.get_viewport_rect().size
	var back := _button("Back")
	var begin: Button = null
	for b in _buttons():
		if b.text.begins_with("Begin"):
			begin = b
	assert_true(back != null and begin != null, "Back and Begin are both there")
	for b: Button in [back, begin]:
		var r := b.get_global_rect()
		assert_true(r.end.y <= screen.y and r.position.y >= 0.0, "%s is on screen (%s in %s)" % [b.text, r, screen])
	var own_card := false
	for l in menu.find_children("*", "Label", true, false):
		if (l as Label).text == "Your own hero" and (l as Label).is_visible_in_tree():
			own_card = true
			assert_true((l as Label).get_global_rect().end.y <= screen.y, "the create-your-own card is on screen")
	assert_true(own_card, "a card to create your own hero")
	back.pressed.emit()
	await _frames(2)
	assert_eq(str(menu.get("_view")), "title")
	menu.call("_new_game")
	await _frames(2)
	_escape()
	await _frames(3)
	assert_eq(str(menu.get("_view")), "title", "Escape goes back to the title too")


func test_the_hero_creator_backs_out_to_the_pick() -> void:
	menu.call("_new_game")
	await _frames(2)
	menu.call("_open_hero")
	await _frames(3)
	var cs := menu.get("_creation") as CreationScreen
	assert_true(cs != null, "the creator opens")
	cs.step = 2
	cs.call("_draw")
	await _frames(1)
	_escape()
	await _frames(3)
	assert_eq(cs.step, 1, "Escape steps back a step")
	cs.step = 0
	cs.call("_draw")
	await _frames(1)
	_escape()
	await _frames(3)
	assert_true(menu.get("_creation") == null, "and from the first step leaves the creator")
	assert_eq(str(menu.get("_view")), "new_game", "back at the pick")
