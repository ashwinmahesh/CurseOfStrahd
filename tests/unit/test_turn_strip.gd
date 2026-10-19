extends TestCase
## The turn order scrolls when it is wider than its panel (owner, 2026-10-14; ui/combat/turn_strip.gd): a fight of 24
## has the creature whose turn it is in view at its start and at every turn, a hand on the wheel or an arrow holds it
## where it was put until the next turn, the pad's look along the order brings each creature into view and rings it,
## and a short order is left exactly as it was.

var hud: CombatHud
var e: Encounter


func after_each() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A fight of `foes` zombies and four heroes on the open field, the first hero to act, and its HUD on screen.
func _fight(foes: int) -> TurnStrip:
	e = TestCombat.open_field()
	var heroes: Array[Combatant] = []
	for k in 4:
		heroes.append(TestCombat.hero(e, ["ilse_varga", "godrick_pendlebrook", "thistle", "silvain_aster"][k], Vector2i(0, k), 3))
	for k in foes:
		TestCombat.foe(e, "zombie", Vector2i(3 + k % 9, int(k / 9.0) * 2 + 1))
	TestCombat.start_with(e, heroes[0])
	hud = CombatHud.new()
	add_child(hud)
	hud.build(e, ActionCatalog.new(e))
	hud.refresh()
	return hud.get("_strip_view") as TurnStrip


## Lets the layout catch up and the glide finish.
func _settle(view: TurnStrip) -> void:
	await _frames(3)
	view._process(10.0)
	await _frames(2)
	view._process(10.0)


func _wheel(button: MouseButton, at: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	return ev


## The card of `c` sits in the middle of the view, unless the row ends before it can.
func _centred(view: TurnStrip, c: Combatant) -> bool:
	var r := view.card_rect(c.id)
	var mid := r.position.x + r.size.x * 0.5 - view.view_width() * 0.5
	return absf(view.position_now() - clampf(mid, 0.0, view.max_scroll())) < 1.5


# --- The sums -------------------------------------------------------------------------------------

func test_centring_holds_to_what_the_row_can_scroll() -> void:
	assert_eq(TurnStrip.centred(0.0, 60.0, 900.0, 2000.0), 0.0, "the first card: the start of the row")
	assert_eq(TurnStrip.centred(1000.0, 60.0, 900.0, 2000.0), 580.0, "a middle card: its middle in the view's middle")
	assert_eq(TurnStrip.centred(1940.0, 60.0, 900.0, 2000.0), 1100.0, "the last card: the end of the row")
	assert_eq(TurnStrip.centred(300.0, 60.0, 900.0, 800.0), 0.0, "a row that fits has nowhere to scroll")


func test_the_glide_closes_in_and_lands() -> void:
	var pos := 0.0
	for i in 600:
		var next := TurnStrip.eased(pos, 400.0, 1.0 / 60.0)
		assert_true(next >= pos and next <= 400.0, "never backwards, never past it")
		pos = next
	assert_eq(pos, 400.0, "ten seconds on, it is there")
	assert_eq(TurnStrip.eased(100.0, 100.4, 0.016), 100.4, "within a pixel it lands")
	assert_true(TurnStrip.eased(0.0, 400.0, 1.0 / 60.0) < 100.0, "a frame moves it a part of the way")
	assert_eq(TurnStrip.eased(300.0, 0.0, 10.0), 0.0, "and back")


func test_cards_out_of_sight_are_counted_by_end() -> void:
	var spans: Array[Vector2] = []
	for k in 10:
		spans.append(Vector2(k * 60.0, 54.0))
	assert_eq(TurnStrip.hidden_cards(spans, 0.0, 300.0), Vector2i(0, 5), "five are past a view 300 wide")
	assert_eq(TurnStrip.hidden_cards(spans, 150.0, 300.0), Vector2i(2, 2), "scrolled on: two behind, two beyond (the cut ones are not counted)")
	assert_eq(TurnStrip.hidden_cards(spans, 300.0, 300.0), Vector2i(5, 0), "at the end: five behind")
	assert_eq(TurnStrip.hidden_cards(spans, 0.0, 700.0), Vector2i.ZERO, "all in view")


# --- A fight of 24 --------------------------------------------------------------------------------

func test_a_long_order_stays_inside_its_panel_and_shows_whose_turn_it_is() -> void:
	var view := _fight(20)
	await _settle(view)
	assert_eq(e.order.size(), 24, "24 in the order")
	assert_true(view.can_scroll(), "24 portraits are wider than the panel")
	var panel := hud.get("_strip_panel") as Control
	assert_true(panel.size.x <= CombatHud.ORDER_MAX_WIDTH + 200.0, "the box stops growing at its widest (%.0f)" % panel.size.x)
	assert_true(get_tree().root.get_visible_rect().encloses(panel.get_global_rect()), "and stays inside the window")
	assert_true(view.get_global_rect().encloses(view.scroll.get_global_rect()), "the scrolling view stays in the strip")
	assert_true(view.in_view(e.current().id), "the first turn is in view at the start of the fight")
	assert_true(_centred(view, e.current()), "...in the middle, or at the start of the row, which it is")
	assert_false((view.get("_left") as Control).visible, "nothing before it: no arrow on the left")
	assert_true((view.get("_right") as Control).visible, "more beyond: an arrow on the right")
	assert_between((view.get("_right") as TurnStrip.End).beyond, 4, 16, "with how many are out of sight")


func test_every_turn_of_a_round_and_the_next_comes_into_view() -> void:
	# 40 in the order: since the smaller cards (2026-10-19) 24 of them leave only a few turns off the ends of the row.
	var view := _fight(36)
	await _settle(view)
	var round_no := e.round_no
	var middles := 0
	for k in 44:
		var c := e.current()
		assert_true(view.in_view(c.id), "%s (turn %d of the order) is in view" % [c.name(), k])
		assert_true(_centred(view, c), "%s is in the middle, or as near as the row's ends let it" % c.name())
		if view.position_now() > 1.0 and view.position_now() < view.max_scroll() - 1.0:
			middles += 1
		assert_true(e.end_turn().ok, "the turn ends")
		hud.refresh()
		await _settle(view)
	assert_true(e.round_no > round_no, "it took the order past a round")
	assert_true(middles >= 10, "most turns were away from the ends of the row (%d)" % middles)


func test_hand_scrolling_holds_until_the_next_turn() -> void:
	var view := _fight(36)
	await _settle(view)
	view.scroll_by(500.0, true)
	await _settle(view)
	var held := view.position_now()
	assert_between(held, 499.0, 501.0, "moved by hand")
	assert_eq(view.scroll.scroll_horizontal, roundi(held), "and the scroll container is there")
	assert_false(view.in_view(e.current().id), "the turn that is up has gone out of view")
	for k in 3:
		hud.refresh()   # a hit point lost, a condition: a rebuild of the cards in the same turn
		await _settle(view)
	assert_between(view.position_now(), held - 0.5, held + 0.5, "refreshes within the turn leave it where it was put")
	assert_eq(view.scroll.scroll_horizontal, roundi(held), "also in the container itself")
	assert_true(e.end_turn().ok)
	hud.refresh()
	await _settle(view)
	assert_true(view.in_view(e.current().id), "the next turn takes it back")
	assert_true(_centred(view, e.current()), "to the middle")


func test_the_wheel_the_trackpad_and_the_arrows_scroll() -> void:
	var view := _fight(36)
	await _settle(view)
	var over := view.scroll.get_global_rect().get_center()
	view.scroll.gui_input.emit(_wheel(MOUSE_BUTTON_WHEEL_DOWN, over))
	assert_eq(view.goal, TurnStrip.WHEEL_STEP, "a notch down: on to the right")
	view.scroll.gui_input.emit(_wheel(MOUSE_BUTTON_WHEEL_RIGHT, over))
	assert_eq(view.goal, 2.0 * TurnStrip.WHEEL_STEP, "a sideways notch the same way")
	view.scroll.gui_input.emit(_wheel(MOUSE_BUTTON_WHEEL_UP, over))
	assert_eq(view.goal, TurnStrip.WHEEL_STEP, "up: back")
	await _settle(view)
	assert_between(view.position_now(), TurnStrip.WHEEL_STEP - 0.5, TurnStrip.WHEEL_STEP + 0.5, "the glide gets there")
	assert_true((view.get("_left") as Control).visible, "something to go back to: the left arrow shows")
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(2.0, 0.0)
	view.scroll.gui_input.emit(pan)
	assert_true(view.position_now() > TurnStrip.WHEEL_STEP + 10.0, "a trackpad swipe moves it at once")
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(-40.0, 0.0)
	var before := view.position_now()
	view.scroll.gui_input.emit(drag)
	assert_eq(view.position_now(), before + 40.0, "a finger dragging left carries the row left")
	view.scroll_by(-100000.0, true)
	assert_eq(view.position_now(), 0.0, "it stops at the start")
	view.scroll_by(100000.0, true)
	assert_eq(view.position_now(), view.max_scroll(), "and at the end")
	await _settle(view)
	assert_false((view.get("_right") as Control).visible, "no arrow on the right at the end")
	var page := 0.7 * view.view_width()
	view.scroll_by(-view.max_scroll(), true)
	(view.get("_right") as Button).pressed.emit()
	assert_between(view.goal, page - 0.5, page + 0.5, "the right arrow takes most of a view")
	await _settle(view)
	(view.get("_left") as Button).pressed.emit()
	assert_eq(view.goal, 0.0, "the left arrow takes it back")


func test_a_wheel_over_a_portrait_reaches_the_order() -> void:
	var view := _fight(20)
	await _settle(view)
	var card := view.strip.get_child(2) as Control
	get_viewport().push_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, card.get_global_rect().get_center()), true)
	await _frames(1)
	assert_eq(view.goal, TurnStrip.WHEEL_STEP, "the wheel through the GUI, over a portrait, scrolls the order")


func test_the_pad_looking_along_the_order_brings_each_into_view_and_rings_them() -> void:
	var view := _fight(20)
	await _settle(view)
	var last := e.order[e.order.size() - 1]
	hud.look_at(last.id)
	await _settle(view)
	assert_eq(view.looked, last.id, "the order remembers who was looked at")
	assert_true(view.in_view(last.id), "the last of 24 is brought into view")
	assert_true(_centred(view, last), "to the middle, as near as the end allows")
	var ring := (view.strip.get_children().filter(func(n: Node) -> bool:
		return n is PanelContainer and (n as Control).tooltip_text.ends_with(last.name())).front() as Control)
	var box := ring.get_theme_stylebox("panel") as StyleBoxFlat
	assert_eq(box.border_color, Look.color("vellum"), "ringed in white")
	var other := e.order[10]
	hud.look_at(other.id)
	await _settle(view)
	assert_true(_centred(view, other), "and from there to one in the middle")
	assert_true(e.end_turn().ok)
	hud.refresh()
	await _settle(view)
	assert_eq(view.looked, "", "the next turn clears the ring")
	assert_true(_centred(view, e.current()), "and takes the order back to whose turn it is")


func test_a_fallen_foe_leaves_the_order_and_the_turn_still_shows() -> void:
	var view := _fight(20)
	await _settle(view)
	var gone := e.order[6]
	gone.creature.dead = true
	gone.creature.hp = 0
	hud.look_at(gone.id)   # no card for them now: nothing to centre on, and nothing breaks
	await _settle(view)
	assert_eq(view.strip.get_child_count(), 23, "one card fewer")
	assert_true(view.in_view(e.current().id), "the turn that is up stays in view")


# --- A short order is left alone ------------------------------------------------------------------

func test_a_short_order_does_not_scroll_and_leaves_the_wheel_alone() -> void:
	var view := _fight(2)
	await _settle(view)
	assert_false(view.can_scroll(), "six portraits fit")
	assert_false((view.get("_left") as Control).visible, "no arrow on the left")
	assert_false((view.get("_right") as Control).visible, "none on the right")
	assert_eq(view.scroll.scroll_horizontal, 0, "at the start")
	view.scroll.gui_input.emit(_wheel(MOUSE_BUTTON_WHEEL_DOWN, view.scroll.get_global_rect().get_center()))
	assert_eq(view.goal, 0.0, "the wheel does nothing here: it zooms the camera")
	for k in 6:
		assert_true(e.end_turn().ok)
		hud.refresh()
		await _settle(view)
		assert_eq(view.position_now(), 0.0, "no turn moves it")
		assert_true(view.in_view(e.current().id), "everyone is in view")
	var panel := hud.get("_strip_panel") as Control
	assert_true(panel.size.x < CombatHud.ORDER_MAX_WIDTH * 0.7, "a short order's box is only as wide as its cards (%.0f)" % panel.size.x)
