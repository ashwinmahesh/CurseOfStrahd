class_name TipCard
extends PanelContainer
## One card on the rules-card layer (U1, TipCards): a control's tooltip or a glossary term, framed in the Crimson look
## (black ground, gilt edge, ironwork corners). Like a tooltip it lets the pointer pass through at first; once the
## pointer has rested on what opened it a moment longer (a gilt line runs along its top edge) it settles, and the
## pointer can move onto it to rest on its gilded words, which open further cards beside it. A pin in its top edge
## keeps it open; a pinned card wears a gilt clasp, can be dragged by its top edge and closes from its cross or a
## right-click.

signal pin_pressed(card: TipCard)
signal close_pressed(card: TipCard)
signal raised(card: TipCard)

## The height of the top edge that holds the pin and the cross and serves as the handle.
const STRIP := 22.0
## A glossary card's text width.
const TERM_WIDTH := 340.0
const HINT := "Rest on a gilded word for its rules · middle-click pins"
const HINT_PLAIN := "Middle-click pins this card"

## "term:<id>" or "tip:<instance id of the control>".
var key := ""
## The control or gilded text it was opened from (null once pinned: it no longer follows it).
var source: Control
## The card whose gilded word opened this one.
var parent_card: TipCard
var pinned := false
## The glossary term shown, "" for a control's own card.
var term := ""
## Seconds the pointer has been away from it and from what opened it.
var away := 0.0
## Whether it takes the pointer yet (settled), and how far along settling it is, in seconds.
var settled := false
var settle_t := 0.0

var _body: VBoxContainer
var _content: Control
var _hint: Label
var _scroll: ScrollContainer
var _hot := ""
var _dragging := false


func setup(content: Control, key_: String, source_: Control, parent_: TipCard, term_: String = "") -> void:
	key = key_
	source = source_
	parent_card = parent_
	term = term_
	name = "TipCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_body)
	_content = content
	_body.add_child(content)
	var words := not content.find_children("*", "TermText", true, false).filter(func(n: Node) -> bool:
		return (n as TermText).text.contains("[url=term:")).is_empty()
	var w := maxf(content.get_combined_minimum_size().x, 220.0)
	_hint = UiParts.wrapped(HINT if words else HINT_PLAIN, 12, "parchment", w)
	_hint.modulate.a = 0.75
	_body.add_child(_hint)
	_restyle()
	UiKit.trim(self, 26.0)
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	mouse_exited.connect(func() -> void:
		_hot = ""
		queue_redraw())


## A glossary term's card: its name and kind, its text with further terms gilded, how this game plays it where that
## differs, and related terms.
static func term_content(id: String) -> Control:
	var e := Glossary.entry(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := UiKit.header(str(e.get("name", id)))
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Look.color("gilt_light"))
	head.add_child(t)
	head.add_child(UiParts.gap())
	var kind := UiParts.caption(str(e.get("kind", "Rule")).to_upper(), 11, "parchment")
	kind.add_theme_font_override("font", UiParts.caps_font())
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(kind)
	box.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(Look.color("gilt_dark"), 0.9)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	box.add_child(TermText.make(str(e.get("text", "")), 14, "vellum", TERM_WIDTH, [id]))
	if str(e.get("here", "")) != "":
		box.add_child(TermText.make("In this game: " + str(e["here"]), 13, "moonlight", TERM_WIDTH, [id]))
	var see: Array[String] = []
	var names: Array[String] = []
	for s: Variant in e.get("see", []):
		if Glossary.has(str(s)):
			see.append(Glossary.link(str(s)))
			names.append(str(Glossary.entry(str(s)).get("name", s)))
	if not see.is_empty():
		var also := TermText.make("See also: " + ", ".join(names), 13, "parchment", TERM_WIDTH, [id])
		also.text = "See also: " + ", ".join(see)
		box.add_child(also)
	return box


## From now on the pointer can come onto it.
func settle() -> void:
	settled = true
	mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	queue_redraw()


## Settling, `t` of `of` seconds along: drawn as the gilt line along the top edge.
func settling(t: float, of: float) -> void:
	settle_t = t
	queue_redraw()
	if t >= of:
		settle()


func set_pinned(on: bool) -> void:
	pinned = on
	if on:
		source = null
		parent_card = null
		away = 0.0
		settle()
	_hint.visible = not on
	_restyle()
	reset_size()


## Puts the content in a scroll box when the card would be taller than `max_h`.
func fit_height(max_h: float) -> void:
	if _scroll != null or get_combined_minimum_size().y <= max_h:
		return
	var w := _content.get_combined_minimum_size().x
	_body.remove_child(_content)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var room := max_h - STRIP - 24.0 - (_hint.get_combined_minimum_size().y + 6.0 if _hint.visible else 0.0)
	_scroll.custom_minimum_size = Vector2(w + 12.0, maxf(room, 120.0))
	_scroll.add_child(_content)
	_body.add_child(_scroll)
	_body.move_child(_scroll, 0)
	reset_size()


func _restyle() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color("ui_black"), 0.97)
	s.border_color = Look.color("gilt_light" if pinned else "gilt")
	s.set_border_width_all(2 if pinned else 1)
	s.set_corner_radius_all(7)
	s.corner_detail = 1
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = STRIP + 2.0
	s.content_margin_bottom = 14
	s.shadow_color = Color(Look.color("void"), 0.65)
	s.shadow_size = 10
	add_theme_stylebox_override("panel", s)
	queue_redraw()


## The pin and the cross sit in the top edge just inside the corner ironwork.
func pin_rect() -> Rect2:
	return Rect2(Vector2(size.x - (68.0 if pinned else 44.0), 4.0), Vector2(18, 18))


func close_rect() -> Rect2:
	return Rect2(Vector2(size.x - 44.0, 4.0), Vector2(18, 18)) if pinned else Rect2()


func _draw() -> void:
	var gilt := Look.color("gilt")
	var bright := Look.color("gilt_light")
	# The pin: a lozenge head on a short needle, hollow until it holds the card.
	var pr := pin_rect()
	var head := pr.position + Vector2(pr.size.x * 0.62, pr.size.y * 0.36)
	var lit := pinned or _hot == "pin"
	draw_line(head + Vector2(-2, 2), pr.position + Vector2(2, pr.size.y - 2), bright if lit else gilt, 1.5, true)
	UiParts.diamond(self, head, 5.5, Look.color("void"), true)
	UiParts.diamond(self, head, 5.0, bright if lit else Look.color("gilt_dark"), pinned)
	if not pinned:
		UiParts.diamond(self, head, 5.0, bright if lit else gilt, false)
	if pinned:
		# The cross, in a small lozenge, and the clasp at the top centre that marks a pinned card.
		var cr := close_rect()
		var c := cr.get_center()
		var hot := _hot == "close"
		UiParts.diamond(self, c, 8.5, Look.color("ui_wine") if hot else Look.color("ui_oxblood"), true)
		UiParts.diamond(self, c, 8.5, bright if hot else gilt, false)
		var col := Look.color("ivory") if hot else bright
		draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), col, 1.5, true)
		draw_line(c + Vector2(3, -3), c + Vector2(-3, 3), col, 1.5, true)
		var m := Vector2(size.x / 2.0, 0)
		var arch := UiParts.arch_points(Rect2(m + Vector2(-26, -7), Vector2(52, 16)), 8.0, 10)
		UiParts.gradient_fill(self, arch, Look.color("ui_wine"), Look.color("ui_oxblood"))
		UiParts.closed_line(self, arch, bright, 1.5)
		UiParts.diamond(self, m + Vector2(0, 2), 3.0, bright, true)
	# A fine rule under the strip, between the corner ironwork; while the card settles a gilt line runs along it.
	var x0 := 34.0
	var x1 := size.x - (74.0 if pinned else 50.0)
	draw_line(Vector2(x0, STRIP + 1.0), Vector2(x1, STRIP + 1.0), Color(Look.color("gilt_dark"), 0.6), 1.0)
	if not settled and settle_t > 0.0:
		var k := clampf(settle_t / TipCards.SETTLE, 0.0, 1.0)
		draw_line(Vector2(x0, STRIP + 1.0), Vector2(lerpf(x0, x1, k), STRIP + 1.0), Look.color("gilt_light"), 2.0)


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		if _dragging:
			position += mm.relative
			_keep_on_screen()
			accept_event()
			return
		var hot := "pin" if pin_rect().grow(3).has_point(mm.position) else ("close" if close_rect().grow(3).has_point(mm.position) else "")
		if hot != _hot:
			_hot = hot
			queue_redraw()
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if not mb.pressed:
			_dragging = false
			return
		raised.emit(self)
		if pin_rect().grow(3).has_point(mb.position):
			pin_pressed.emit(self)
		elif close_rect().grow(3).has_point(mb.position):
			close_pressed.emit(self)
		elif mb.position.y <= STRIP + 2.0:
			# The top edge is the handle; dragging a card that isn't pinned yet pins it where you leave it.
			if not pinned:
				pin_pressed.emit(self)
			_dragging = true
		accept_event()
	elif mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
		pin_pressed.emit(self)
		accept_event()
	elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and pinned:
		close_pressed.emit(self)
		accept_event()


func _keep_on_screen() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(clampf(position.x, 0.0, maxf(0.0, vp.x - size.x)), clampf(position.y, 8.0, maxf(8.0, vp.y - size.y)))
