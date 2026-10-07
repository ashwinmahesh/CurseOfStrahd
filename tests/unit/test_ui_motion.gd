extends TestCase
## G9, the interface in motion, and A4's interface sounds: screens sink away before they're freed, numbers and Hit
## Point bars roll to their new value, Tarokka cards turn face up, and all of it snaps at once when motion is off
## (headless runs and still captures). The sounds the interface asks for are all listed.

var _was_reduced := false


func before_each() -> void:
	UiMotion.on()
	_was_reduced = UiMotion.reduced


func after_each() -> void:
	UiMotion.reduced = _was_reduced


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Waits until `done()` holds, or `seconds` pass (a busy machine draws slowly; motion counts in seconds, not frames).
func _until(done: Callable, seconds: float = 5.0) -> void:
	var left := seconds
	while left > 0.0 and not bool(done.call()):
		await get_tree().process_frame
		left -= get_process_delta_time()


func test_interface_sounds_are_listed() -> void:
	for id: String in ["click", "hover", "close", "quill", "pin", "unpin", "page", "coins", "card"]:
		assert_false(Audio.files("sfx", id).is_empty(), id)


func test_without_motion_everything_snaps() -> void:
	UiMotion.reduced = true
	var layer := CanvasLayer.new()
	add_child(layer)
	UiMotion.dismiss(layer)
	assert_true(layer.is_queued_for_deletion(), "freed at once")
	var l := Label.new()
	add_child(l)
	UiMotion.roll(l, "test:gold:snap", 10.0, func(v: float) -> String: return "%d gp" % int(v))
	UiMotion.roll(l, "test:gold:snap", 25.0, func(v: float) -> String: return "%d gp" % int(v))
	assert_eq(l.text, "25 gp")
	l.queue_free()


func test_a_closing_screen_stops_taking_input_then_goes() -> void:
	UiMotion.reduced = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := UiKit.screen_frame(layer, "Journal", Vector2(600, 400))
	var b := UiKit.button("Quest", func() -> void: pass)
	box.add_child(b)
	await _frames(2)
	UiMotion.dismiss(layer)
	assert_false(layer.is_queued_for_deletion(), "it sinks away first")
	assert_eq(b.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and takes no clicks while it does")
	assert_eq(layer.process_mode, Node.PROCESS_MODE_DISABLED)
	var ref: WeakRef = weakref(layer)
	await _until(func() -> bool: return ref.get_ref() == null)
	assert_true(ref.get_ref() == null, "then it's gone")


func test_numbers_roll_from_what_was_shown() -> void:
	UiMotion.reduced = false
	var fmt := func(v: float) -> String: return "%d gp" % int(v)
	var a := Label.new()
	UiMotion.roll(a, "test:gold:roll", 10.0, fmt)
	a.free()
	var l := Label.new()
	UiMotion.roll(l, "test:gold:roll", 60.0, fmt)
	assert_eq(l.text, "10 gp", "starts from the last value shown")
	add_child(l)
	await _until(func() -> bool: return l.text == "60 gp")
	assert_eq(l.text, "60 gp", "and ends on the new one")
	l.queue_free()


func test_hit_point_bars_roll() -> void:
	UiMotion.reduced = false
	var ch := Pregens.build("godrick_pendlebrook", 3)
	ch.hp = ch.max_hp()
	UiParts.hp_bar(ch, 200.0, 20.0).free()
	ch.hp = 3
	var bar := UiParts.hp_bar(ch, 200.0, 20.0)
	assert_eq(float(bar.get_meta(&"roll_from", -1.0)), float(ch.max_hp()), "a loss drains from the old value")
	add_child(bar)
	await _until(func() -> bool: return float(bar.get_meta(&"roll_t", 0.0)) >= 1.0)
	assert_eq(float(bar.get_meta(&"roll_t", 0.0)), 1.0, "and finishes")
	var again := UiParts.hp_bar(ch, 200.0, 20.0)
	assert_false(again.has_meta(&"roll_from"), "nothing rolls when nothing changed")
	bar.queue_free()
	again.free()


func test_tarokka_cards_turn_face_up() -> void:
	UiMotion.reduced = false
	var card := PanelContainer.new()
	var face := Label.new()
	face.text = "The Seer"
	card.add_child(face)
	card.custom_minimum_size = Vector2(110, 160)
	add_child(card)
	UiMotion.flip_in(card, 0.0)
	assert_false(face.visible, "the back shows first")
	await _until(func() -> bool: return face.visible and is_equal_approx(card.scale.x, 1.0))
	assert_true(face.visible, "then the face")
	assert_true(is_equal_approx(card.scale.x, 1.0), "standing flat again")
	card.queue_free()


func test_a_page_turns_across_the_journal() -> void:
	UiMotion.reduced = false
	var layer := CanvasLayer.new()
	add_child(layer)
	var page := PanelContainer.new()
	page.size = Vector2(400, 300)
	layer.add_child(page)
	UiMotion.turn_page(page)
	assert_eq(layer.get_child_count(), 2, "the leaf lies over the page")
	await _until(func() -> bool: return layer.get_child_count() == 1)
	assert_eq(layer.get_child_count(), 1, "and is gone once it has turned")
	layer.queue_free()
