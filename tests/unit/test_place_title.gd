extends TestCase
## The place's name on arriving (Visual Polish Plan 6, PlaceTitle): over the HUD and under the menus, the black fade
## and the loading card; never over a loading card, which names the place itself; never taking a click; a long name
## wraps on screen; one at a time; a journey's hour beneath; out of the way of a conversation.

var _game: Node


func before_each() -> void:
	PlaceTitle.headless_too = true
	_game = Node.new()
	add_child(_game)


func after_each() -> void:
	PlaceTitle.headless_too = false
	_game.queue_free()


func test_its_layer_and_clicks() -> void:
	var t := PlaceTitle.show_for(_game, {"name": "The Village of Barovia"})
	assert_true(t != null, "it shows")
	if t == null:
		return
	assert_true(t.layer > 10 and t.layer < 25, "over the HUD, under the menus (layer %d)" % t.layer)
	assert_true(t.layer < 39, "under the place's fade from black and the loading card")
	for c in t.find_children("*", "Control", true, false):
		assert_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s lets clicks through" % c.name)
	assert_eq((t.find_child("Name", true, false) as Label).text, "The Village of Barovia")


func test_never_over_a_loading_card() -> void:
	var card := CanvasLayer.new()
	card.set_script(load("res://ui/screens/loading_card.gd"))
	_game.add_child(card)
	assert_true(PlaceTitle.show_for(_game, {"name": "Vallaki", "region": "vallaki"}) == null, "the card names it")
	card.queue_free()


func test_a_long_name_stays_on_screen_and_one_shows_at_a_time() -> void:
	var long_name := "The Ruins of Argynvostholt, Seat of the Order of the Silver Dragon, Cold Halls Beyond"
	var t := PlaceTitle.show_for(_game, {"name": long_name})
	await get_tree().process_frame
	await get_tree().process_frame
	var box := t.find_child("Title", true, false) as Control
	var screen := t.get_viewport().get_visible_rect().size.x
	assert_true(box.size.x <= screen, "%.0f px wide on a %.0f px screen" % [box.size.x, screen])
	assert_true((t.find_child("Name", true, false) as Label).get_line_count() >= 2, "it wraps")
	t.set_subtitle("18:00")
	assert_true((t.find_child("Subtitle", true, false) as Label).visible, "the hour beneath")
	PlaceTitle.show_for(_game, {"name": "Krezk"})
	await get_tree().process_frame
	var titles := _game.get_children().filter(func(c: Node) -> bool: return c is PlaceTitle and not c.is_queued_for_deletion())
	assert_eq(titles.size(), 1, "a quick change of place shows only the new name")


func test_nothing_without_a_name_or_motion() -> void:
	assert_true(PlaceTitle.show_for(_game, {}) == null, "no name, no title")
	PlaceTitle.headless_too = false
	assert_true(PlaceTitle.show_for(_game, {"name": "Krezk"}) == null, "never in headless runs")
