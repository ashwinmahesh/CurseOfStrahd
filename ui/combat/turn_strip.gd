class_name TurnStrip
extends MarginContainer

## The turn order's row of portraits, scrolling sideways when the row is wider than the room the HUD gives it (owner,
## 2026-10-14: scroll the combatant order so the current turn's creature is in view, and allow scrolling left and right).
## CombatHud fills `strip` with one card a combatant and names each one (register). At the start of a fight and at each
## new turn the row glides to put the card whose turn it is in the middle. The player can scroll it too, with the mouse
## wheel or a trackpad over it, a touch drag, the arrows at its ends, or on a pad LB + X / LB + RB, which look along the
## order and bring each creature in turn into view (CombatView._look_along_order); the row then stays where they put it
## until the next turn, however often the cards are rebuilt. A fade with an arrow and a count marks an end that has more
## cards beyond it. While every card fits nothing here changes, and the wheel is left to zoom the camera.

## How wide the fade and arrow at each end are.
const EDGE := 52.0
## What one notch of the wheel moves, in pixels (a card with its gap is about 44 wide).
const WHEEL_STEP := 64.0
## How much of the view an arrow's click moves.
const PAGE := 0.7
## How fast the glide closes the distance: after t seconds a fraction of exp(-EASE * t) of it is left.
const EASE := 9.0

## The widest the view gets (CombatHud sets it): up to that the box is as wide as its cards, and a longer order scrolls.
var max_width := 1000000.0
## The cards, side by side (CombatHud adds them here).
var strip := HBoxContainer.new()
var scroll := ScrollContainer.new()
## Where the row is heading and where it is now, in pixels from its start; the glide eases one towards the other.
var goal := 0.0
var _pos := 0.0
## The creature a pad has looked at along the order (its card is marked), until the next turn.
var looked := ""
## The turn the row last followed ("id@round"), so a rebuild within a turn leaves the scroll where it is.
var _turn := ""
## The creature to bring to the middle as soon as the view has a width to measure by, and whether to jump there.
var _centre := ""
var _snap := false
var _cards := {}
var _left: End
var _right: End


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.gui_input.connect(_on_scroll_input)
	add_child(scroll)
	scroll.add_child(strip)
	var edges := Control.new()
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edges)
	_left = End.new(true)
	_right = End.new(false)
	_left.pressed.connect(func() -> void: scroll_by(-PAGE * view_width()))
	_right.pressed.connect(func() -> void: scroll_by(PAGE * view_width()))
	edges.add_child(_left)
	edges.add_child(_right)


# --- The cards ------------------------------------------------------------------------------------

## CombatHud calls this before it rebuilds the cards, then register for each combatant's, then follow_turn.
func clear_cards() -> void:
	_cards.clear()


func register(id: String, card: Control) -> void:
	_cards[id] = card


## The turn that's up (CombatHud._refresh_strip, on every refresh): the row glides to its card once per turn. At the
## first call, the start of a fight, it is already there.
func follow_turn(id: String, round_no: int) -> void:
	var key := "%s@%d" % [id, round_no]
	if key != _turn:
		var first := _turn == ""
		_turn = key
		looked = ""
		centre_on(id, first)
	_try_centre()


## A creature the pad looked at: its card is to be marked and brought to the middle. CombatHud rebuilds the cards with
## the mark, and follow_turn takes the view there once they are in.
func look(id: String) -> void:
	looked = id
	centre_on(id)


## Brings the card of `id` to the middle of the view, jumping there with `snap`, as soon as the cards and the view are
## there to measure.
func centre_on(id: String, snap := false) -> void:
	_centre = id
	_snap = snap


# --- Scrolling ------------------------------------------------------------------------------------

## The scroll position that puts the item spanning [x, x + w) in the middle of a view `view` wide, over `content` of
## row, held to what the row can scroll.
static func centred(x: float, w: float, view: float, content: float) -> float:
	return clampf(x + w * 0.5 - view * 0.5, 0.0, maxf(0.0, content - view))


## One step of the glide: `pos` a fraction of the way to `to` for `delta` seconds, and there once it is within a pixel.
static func eased(pos: float, to: float, delta: float) -> float:
	if absf(to - pos) < 1.0:
		return to
	return lerpf(pos, to, 1.0 - exp(-EASE * delta))


## How many of the cards, given as [x, width] spans in row order, are wholly out of a view that starts at `pos` and is
## `view` wide: x is those before it, y those after.
static func hidden_cards(spans: Array[Vector2], pos: float, view: float) -> Vector2i:
	var out := Vector2i.ZERO
	for s in spans:
		if s.x + s.y <= pos + 1.0:
			out.x += 1
		elif s.x >= pos + view - 1.0:
			out.y += 1
	return out


func view_width() -> float:
	return scroll.size.x


func content_width() -> float:
	return strip.get_combined_minimum_size().x


## Whether the row is wider than its view (before the first layout, no).
func can_scroll() -> bool:
	return view_width() > 1.0 and content_width() > view_width() + 0.5


func max_scroll() -> float:
	return maxf(0.0, content_width() - view_width())


## Where the row is, as the player sees it.
func position_now() -> float:
	return _pos


## Moves the row by `by` pixels at the player's say: eased, or `at_once` (a trackpad or a finger keeps up with itself).
## A centring on a card that was still waiting for the view to be measured is given up; the next turn takes the row on.
func scroll_by(by: float, at_once := false) -> void:
	_centre = ""
	goal = clampf((_pos if at_once else goal) + by, 0.0, max_scroll())
	if at_once:
		_pos = goal
		_apply()


## Where each card in the row stands, from the cards' own widths: a card added to a container is as wide as it will be
## at once but sits at 0 until the container's next sort, so this is right on the frame the cards were added too.
func _spans() -> Dictionary:
	var out := {}
	var x := 0.0
	var gap := float(strip.get_theme_constant("separation"))
	for n: Node in strip.get_children():
		var c := n as Control
		if c == null or not c.visible:
			continue
		var w := c.get_combined_minimum_size().x
		out[c] = Rect2(x, 0.0, w, c.get_combined_minimum_size().y)
		x += w + gap
	return out


## The card's span in the row (an empty Rect2 for a creature without a card).
func card_rect(id: String) -> Rect2:
	var card := _cards.get(id) as Control
	if card == null or not is_instance_valid(card) or card.get_parent() != strip:
		return Rect2()
	return (_spans().get(card, Rect2()) as Rect2)


## Whether the card is wholly inside the view now.
func in_view(id: String) -> bool:
	var r := card_rect(id)
	return r.size.x > 0.0 and r.position.x >= _pos - 0.5 and r.end.x <= _pos + view_width() + 0.5


func _try_centre() -> void:
	if _centre == "":
		return
	if not _cards.has(_centre):
		_centre = ""   # no card to show (they fell and left the order)
		return
	var r := card_rect(_centre)
	if r.size.x < 1.0 or view_width() < 1.0:
		return   # the view hasn't been laid out yet (the start of the fight): _process tries again
	goal = centred(r.position.x, r.size.x, view_width(), content_width())
	if _snap:
		_pos = goal
		_apply()
	_centre = ""
	_snap = false


func _apply() -> void:
	var at := roundi(_pos)
	if scroll.scroll_horizontal != at:
		scroll.scroll_horizontal = at


func _process(delta: float) -> void:
	# The box takes the room the cards need, up to max_width.
	var want := minf(content_width(), max_width)
	if not is_equal_approx(custom_minimum_size.x, want):
		custom_minimum_size.x = want
	_try_centre()
	if view_width() > 1.0:
		goal = clampf(goal, 0.0, max_scroll())
	if _pos != goal:
		_pos = eased(_pos, goal, delta)
	# Always, not only when it moves: a rebuilt row puts the scroll back to 0 until the layout catches up.
	_apply()
	_update_edges()


func _on_scroll_input(ev: InputEvent) -> void:
	if not can_scroll():
		return
	var by := 0.0
	var at_once := false
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if not mb.pressed:
			return
		var notch := WHEEL_STEP * (mb.factor if mb.factor > 0.0 else 1.0)
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				by = -notch
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				by = notch
			_:
				return
	elif ev is InputEventPanGesture:
		var d := (ev as InputEventPanGesture).delta
		by = (d.x if absf(d.x) > absf(d.y) else d.y) * view_width() / 8.0
		at_once = true
	elif ev is InputEventScreenDrag:
		by = -(ev as InputEventScreenDrag).relative.x
		at_once = true
	else:
		return
	scroll_by(by, at_once)
	scroll.accept_event()


# --- The ends -------------------------------------------------------------------------------------

## An end shows while there is row beyond it, with how many cards are wholly out of sight that way.
func _update_edges() -> void:
	var can := can_scroll()
	var spans: Array[Vector2] = []
	if can:
		for r: Variant in _spans().values():
			spans.append(Vector2((r as Rect2).position.x, (r as Rect2).size.x))
	var out := hidden_cards(spans, _pos, view_width())
	_left.show_more(can and _pos > 0.5, out.x)
	_right.show_more(can and _pos < max_scroll() - 0.5, out.y)


## One end of the row: the panel's own black fading to nothing towards the cards (so a card slides under the edge instead
## of being cut), with an arrow and the number of cards out of sight that way. A click takes the row most of a view along.
class End extends Button:
	## How many cards are wholly out of sight that way.
	var beyond := 0
	var _count := Label.new()

	func _init(left: bool) -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		anchor_left = 0.0 if left else 1.0
		anchor_right = anchor_left
		anchor_bottom = 1.0
		offset_left = 0.0 if left else -EDGE
		offset_right = EDGE if left else 0.0
		for state: String in ["normal", "hover", "pressed"]:
			add_theme_stylebox_override(state, _fade(left, 0.99 if state == "normal" else 1.0))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -4)
		var arrow := _label("‹" if left else "›", 34, "gilt_light")
		box.add_child(arrow)
		_count.add_theme_font_size_override("font_size", 15)
		_count.add_theme_color_override("font_color", Look.color("vellum"))
		_count.add_theme_color_override("font_outline_color", Look.color("void"))
		_count.add_theme_constant_override("outline_size", 5)
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_count)
		add_child(box)
		visible = false

	func _label(text_: String, size_: int, colour: String) -> Label:
		var l := Label.new()
		l.text = text_
		l.add_theme_font_size_override("font_size", size_)
		l.add_theme_color_override("font_color", Look.color(colour))
		l.add_theme_color_override("font_outline_color", Look.color("void"))
		l.add_theme_constant_override("outline_size", 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	## Shown while there's more that way; `out` is how many cards are wholly out of sight there.
	func show_more(more: bool, out: int) -> void:
		visible = more
		beyond = out
		_count.text = str(out) if out > 0 else ""
		_count.visible = out > 0
		tooltip_text = "%d more this way: scroll, or click" % out if out > 0 else "More this way: scroll, or click"

	static func _fade(left: bool, strength: float) -> StyleBoxTexture:
		var solid := Color(Look.color("ui_black"), 0.92 * strength)
		var g := Gradient.new()
		g.colors = PackedColorArray([solid, Color(solid, 0.0)] if left else [Color(solid, 0.0), solid])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2.ZERO
		t.fill_to = Vector2(1.0, 0.0)
		t.width = 32
		t.height = 2
		var box := StyleBoxTexture.new()
		box.texture = t
		return box
