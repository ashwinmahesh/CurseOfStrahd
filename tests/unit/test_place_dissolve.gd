extends TestCase
## A new place resolving out of a soft blur (Visual Polish Plan 10, PlaceDissolve): one layer over the world and
## under the HUD that never takes a click, soft at once and sharp again once the black has lifted, then hidden;
## nothing without motion.

var _game: Node


func before_each() -> void:
	PlaceDissolve.headless_too = true
	_game = Node.new()
	add_child(_game)


func after_each() -> void:
	PlaceDissolve.headless_too = false
	_game.queue_free()


func test_soft_then_sharp_under_the_hud() -> void:
	var d := PlaceDissolve.play(_game, 0.12)
	assert_true(d != null, "it plays")
	if d == null:
		return
	assert_true(d.layer < 10, "under the HUD, which stays crisp (layer %d)" % d.layer)
	assert_eq((d.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "clicks go through it")
	assert_true(is_equal_approx(d.amount(), 1.0), "soft as the black starts to lift")
	d._tw.custom_step(0.12 + PlaceDissolve.SECONDS + 0.1)
	assert_false(d.visible, "sharp and gone once the place is in")
	assert_eq(PlaceDissolve.play(_game, 0.0), d, "the next change of place uses the same layer")


func test_nothing_without_motion() -> void:
	PlaceDissolve.headless_too = false
	assert_true(PlaceDissolve.play(_game, 0.0) == null, "never in headless runs or still captures")
