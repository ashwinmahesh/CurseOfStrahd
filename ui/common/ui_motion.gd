class_name UiMotion
extends RefCounted
## G9, the interface in motion: screens that rise into place and sink away, a leaf that turns across the journal,
## Tarokka cards that flip face up, and numbers (Hit Points, gold) that roll to their new value instead of jumping.
## Everything is cosmetic and short; tweens run on the scene tree so a paused game still animates its menus. Motion is
## off in headless runs (tests) and in still captures, where every frame has to show the finished screen; a capture
## that wants it passes --motion.

## Off: everything snaps to its end at once. A later Settings switch for reduced motion can set it.
static var reduced := false
static var _checked := false
## The last value shown for each rolling number, by its key.
static var _shown: Dictionary = {}


static func on() -> bool:
	if not _checked:
		_checked = true
		var args := OS.get_cmdline_user_args()
		var still := false
		for a in args:
			if a.begins_with("--out="):
				still = true
		if DisplayServer.get_name() == "headless" or (still and not "--motion" in args):
			reduced = true
	return not reduced


## A tween on the scene tree that keeps running while the game is paused and dies with `node`.
static func tween_for(node: Node) -> Tween:
	return node.get_tree().create_tween().bind_node(node).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


## Calls `call` after `frames` more frames while `node` is still in the tree. Motion starts this way because the frame
## that builds a screen (or rebuilds the HUD) is a long one, and a tween started in it would spend that whole time in
## its first step and jump most of the way to its end.
static func soon(node: Node, call: Callable, frames: int = 2) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if frames <= 0:
		call.call()
		return
	# Held weakly: a screen freed in the meantime just drops its motion.
	var ref: WeakRef = weakref(node)
	node.get_tree().process_frame.connect(func() -> void:
		var n := ref.get_ref() as Node
		if n != null:
			soon(n, call, frames - 1), CONNECT_ONE_SHOT)


## A screen frame opening (UiKit.screen_frame): the backdrop darkens, the panel rises into place from a touch
## smaller, and the title's arch and the trim settle a beat later.
static func open_frame(dim: Control, panel: Control, crown: Array[Control]) -> void:
	if not on() or not panel.is_inside_tree():
		return
	dim.modulate.a = 0.0
	panel.pivot_offset = (Vector2(panel.offset_right, panel.offset_bottom) - Vector2(panel.offset_left, panel.offset_top)) / 2.0
	panel.scale = Vector2(0.965, 0.965)
	panel.modulate.a = 0.0
	for c in crown:
		c.modulate.a = 0.0
	soon(panel, func() -> void:
		var tw := tween_for(panel).set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(dim, "modulate:a", 1.0, 0.18)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.24)
		tw.tween_property(panel, "modulate:a", 1.0, 0.16)
		for c in crown:
			tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(0.08))


## Closes a screen: it stops taking input at once, sinks and fades, then is freed. Without motion it's freed at once.
static func dismiss(layer: CanvasLayer) -> void:
	if not on() or not layer.is_inside_tree():
		layer.queue_free()
		return
	Audio.sfx("close")
	layer.process_mode = Node.PROCESS_MODE_DISABLED
	for c: Node in layer.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Freed after a moment whatever happens, so a closed screen never lingers.
	var ref: WeakRef = weakref(layer)
	layer.get_tree().create_timer(0.6, true).timeout.connect(func() -> void:
		var gone := ref.get_ref() as Node
		if gone != null:
			gone.queue_free())
	soon(layer, func() -> void:
		var tw := tween_for(layer).set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		for ch: Node in layer.get_children():
			var ci := ch as CanvasItem
			if ci != null and ci.visible:
				tw.tween_property(ci, "modulate:a", 0.0, 0.16)
		# A null default still counts as none, so get_meta would raise an error for a screen without a frame.
		var panel := layer.get_meta(&"frame_panel") as Control if layer.has_meta(&"frame_panel") else null
		if panel != null and is_instance_valid(panel):
			panel.pivot_offset = panel.size / 2.0
			tw.tween_property(panel, "scale", Vector2(0.975, 0.975), 0.16)
		tw.chain().tween_callback(layer.queue_free), 1)


## A page turning over `page` (the journal changing tabs): the leaf's dark back sweeps across from the right,
## uncovering the new page behind its gilt edge, with a soft shadow on the page it reveals.
static func turn_page(page: Control, forward: bool = true) -> void:
	Audio.sfx("page")
	if not on() or not page.is_inside_tree():
		return
	var layer := page.get_canvas_layer_node()
	var host: Node = layer if layer != null else page.get_tree().root
	var leaf := UiParts.drawn(Vector2.ZERO, func(c: Control) -> void: _leaf(c, page, forward))
	leaf.set_anchors_preset(Control.PRESET_FULL_RECT)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.set_meta(&"t", 0.0)
	host.add_child(leaf)
	soon(leaf, func() -> void:
		var tw := tween_for(leaf)
		tw.tween_method(func(t: float) -> void:
			leaf.set_meta(&"t", t)
			leaf.queue_redraw(), 0.0, 1.0, 0.42).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(leaf.queue_free))


static func _leaf(c: Control, page: Control, forward: bool) -> void:
	if not is_instance_valid(page) or not page.is_visible_in_tree():
		return
	var r := page.get_global_rect()
	var t := float(c.get_meta(&"t", 0.0))
	var lift := sin(t * PI) * minf(48.0, r.size.x * 0.06)
	# The fold runs across the page; above the middle it leads, below it trails, like a leaf held by its corner.
	var x := r.end.x - t * r.size.x if forward else r.position.x + t * r.size.x
	var top := Vector2(x - lift if forward else x + lift, r.position.y)
	var bottom := Vector2(x + lift if forward else x - lift, r.end.y)
	var far := r.position.x if forward else r.end.x
	var back := PackedVector2Array([Vector2(far, r.position.y), top, bottom, Vector2(far, r.end.y)])
	var ink := Look.color("ui_black")
	var wine := Look.color("ui_wine")
	c.draw_polygon(back, PackedColorArray([ink, wine, wine, ink]))
	# Faint ruled lines on the leaf's back, so it reads as a page.
	var rule := Color(Look.color("gilt_dark"), 0.35)
	var y := r.position.y + 30.0
	while y < r.end.y - 16.0:
		var k := (y - r.position.y) / maxf(r.size.y, 1.0)
		var edge := top.lerp(bottom, k).x - 18.0 * (1.0 if forward else -1.0)
		var near := far + 24.0 * (1.0 if forward else -1.0)
		if (edge > near) == forward:
			c.draw_line(Vector2(near, y), Vector2(edge, y), rule, 1.0)
		y += 24.0
	# The shadow the leaf throws on the new page, then the leaf's gilt edge.
	var dir := 1.0 if forward else -1.0
	var shade := PackedVector2Array([top, bottom, bottom + Vector2(36.0 * dir, 0), top + Vector2(36.0 * dir, 0)])
	var dark := Color(Look.color("void"), 0.55 * sin(t * PI))
	var clear := Color(Look.color("void"), 0.0)
	c.draw_polygon(shade, PackedColorArray([dark, dark, clear, clear]))
	c.draw_line(top, bottom, Look.color("gilt_light"), 2.0, true)


## A Tarokka card turning face up: it shows its back, then flips about its middle to its face. `delay` holds the back
## a moment first (cards dealt one after another).
static func flip_in(card: Control, delay: float = 0.15) -> void:
	if not on():
		return
	var face: Array[CanvasItem] = []
	for ch: Node in card.get_children():
		var ci := ch as CanvasItem
		if ci != null and ci.visible:
			face.append(ci)
			ci.visible = false
	var paint_back := func() -> void: _tarokka_back(card)
	card.draw.connect(paint_back)
	card.queue_redraw()
	var swap := func() -> void:
		if card.draw.is_connected(paint_back):
			card.draw.disconnect(paint_back)
		for ci in face:
			if is_instance_valid(ci):
				ci.visible = true
		card.queue_redraw()
	var start := func() -> void:
		soon(card, func() -> void:
			var tw := tween_for(card)
			tw.tween_callback(func() -> void: card.pivot_offset = card.size / 2.0).set_delay(delay)
			tw.tween_property(card, "scale:x", 0.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(swap)
			tw.tween_property(card, "scale:x", 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK))
	if card.is_inside_tree():
		start.call()
	else:
		card.tree_entered.connect(start, CONNECT_ONE_SHOT)


## A Vistani card back: crimson field, a gilt rule inset, a lozenge eye in the middle and a lozenge at each corner.
static func _tarokka_back(card: Control) -> void:
	var r := Rect2(Vector2.ZERO, card.size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var field := UiParts._octagon(r, 7.0)
	UiParts.gradient_fill(card, field, Look.color("ui_wine"), Look.color("ui_oxblood"))
	UiParts.closed_line(card, field, Look.color("gilt"), 2.0)
	var inner := r.grow(-9.0)
	UiParts.closed_line(card, UiParts._octagon(inner, 5.0), Color(Look.color("gilt_dark"), 0.9), 1.0)
	var m := r.get_center()
	var k := minf(r.size.x, r.size.y) * 0.22
	UiParts.diamond(card, m, k, Look.color("ui_black"), true)
	UiParts.diamond(card, m, k, Look.color("gilt"), false)
	UiParts.diamond(card, m, k * 0.45, Look.color("gilt_light"), true)
	card.draw_arc(m, k * 1.35, 0.0, TAU, 36, Color(Look.color("gilt_dark"), 0.8), 1.0, true)
	for corner: Vector2 in [inner.position + Vector2(9, 9), Vector2(inner.end.x - 9, inner.position.y + 9),
			Vector2(inner.position.x + 9, inner.end.y - 9), inner.end - Vector2(9, 9)]:
		UiParts.diamond(card, corner, 4.0, Look.color("gilt"), true)


## Shows `value` in `label` through `fmt(value) -> String`, rolling from the last value shown under `key` (the party's
## gold, a creature's Hit Points) so a change counts up or down instead of jumping.
static func roll(label: Label, key: String, value: float, fmt: Callable) -> void:
	var from := float(_shown.get(key, value))
	_remember(key, value)
	label.text = str(fmt.call(value))
	if not on() or is_equal_approx(from, value):
		return
	label.text = str(fmt.call(from))
	var start := func() -> void:
		soon(label, func() -> void:
			var tw := tween_for(label).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_method(func(v: float) -> void: label.text = str(fmt.call(v)), from, value, roll_seconds(from, value)))
	if label.is_inside_tree():
		start.call()
	else:
		label.tree_entered.connect(start, CONNECT_ONE_SHOT)


## The value last shown under `key` and remembers the new one: where a rolling number or bar starts from.
static func last_shown(key: String, value: float) -> float:
	var from := float(_shown.get(key, value))
	_remember(key, value)
	return from


static func roll_seconds(from: float, to: float) -> float:
	return clampf(0.3 + absf(to - from) * 0.01, 0.3, 0.8)


static func _remember(key: String, value: float) -> void:
	if _shown.size() > 600:
		_shown.clear()
	_shown[key] = value
