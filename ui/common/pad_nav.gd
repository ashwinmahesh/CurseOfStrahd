class_name PadNav
extends Node
## The controller on every screen (Improvement Ideas U6, docs/ui/controller.md). UiFeel makes one at start; `current`
## is it. It notes whether the last input came from a pad or from the mouse and keyboard (`pad`, and the pad's
## `family` for its button pictures), and while the pad is in use it drives the screen in front:
## - The scope is the topmost visible screen layer (CanvasLayers LAYER_MIN to LAYER_MAX, or any layer whose
##   "pad_scope" meta is true; false leaves one out) with something to choose. Focus lands on its first choice when it
##   comes up (a control with the "pad_first" meta, else the first in reading order) and goes back to where it was
##   when a page over it closes, or to the nearest choice when a screen rebuilds under it.
## - The D-pad and left stick move focus to the nearest choice that way inside the scope only, repeating while held,
##   and scroll lists to keep it in view; on a slider (or a control with pad_adjust) left and right change it.
##   Buttons that take no focus from the mouse, controls with a rules card (TipCards.tip_of) and clickable widgets (a
##   script _gui_input, or the "pad_target" meta) count as choices; "pad_skip" leaves a control and its children out.
## - A presses a button (the engine does that) or clicks any other choice; X right-clicks it (item menus); Y opens
##   its rules card, then pins it, then closes it; LB/RB step the screen's tabs (its pad_tab(step), else a TabContainer,
##   TabBar or group of toggle buttons); LT/RT its character (pad_character(step)); the right stick scrolls. B is
##   each screen's own Escape (combat_cancel and ui_cancel are on it), so every screen keeps its way back.
## - The pointer follows focus (a mouse move to its middle that this tracker ignores), so hover cards, tooltips and
##   hover looks show as they do for the mouse; the system pointer hides while the pad is in use. FocusRing draws
##   the candle frame.
## With no scope (exploring, a fight) the pad's buttons are left to game_root and CombatView.

signal device_changed(pad: bool)

static var current: PadNav = null

const LAYER_MIN := 20
const LAYER_MAX := 99
## Seconds a held direction waits before repeating, then between repeats.
const REPEAT_DELAY := 0.38
const REPEAT_EVERY := 0.085
## How far a stick leans before it counts as a press, and how far back it must come to count as let go.
const STICK_ON := 0.55
const STICK_OFF := 0.35
## How far the mouse travels (pixels) before it takes over from the pad again.
const MOUSE_TAKES_OVER := 10.0
## The right stick's scrolling at full lean, in pixels a second.
const SCROLL_SPEED := 1100.0
## A control covering more than this share of the screen is a backdrop, never a choice.
const BACKDROP := 0.6
## How much a sideways offset counts against a choice, against its distance straight ahead.
const SIDEWAYS := 2.5

const DPAD := {
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
}

## The last input came from a pad.
var pad := false
## The pad's family, for its pictures: "xbox", "playstation" or "nintendo".
var family := "xbox"
var ring: FocusRing
## The scope this frame (null when nothing is in front).
var scope: CanvasLayer = null

var _layers: Array[CanvasLayer] = []
## Scope instance id -> WeakRef of the control that had focus there.
var _remember: Dictionary = {}
## Where focus last was (viewport coordinates), for landing near it when a screen rebuilds.
var _last_rect := Rect2()
var _last_scope_id := 0
## The direction held on the D-pad or left stick, and the time to its next repeat.
var _held := Vector2i.ZERO
var _held_t := 0.0
var _dpad_held := Vector2i.ZERO
var _stick := Vector2.ZERO
var _stick_dir := Vector2i.ZERO
## Triggers and other axes bound to actions: action -> whether it's down, so a lean presses once.
var _axis_down: Dictionary = {}
var _mouse_travel := 0.0


func _init() -> void:
	name = "PadNav"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	ring = FocusRing.new()
	add_child(ring)
	get_tree().node_added.connect(_on_node_added)
	for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		_on_node_added(n)


func _on_node_added(n: Node) -> void:
	if n is CanvasLayer and n != ring:
		_layers.append(n as CanvasLayer)


## Back to the mouse and keyboard with nothing held (tests call it between cases).
func reset() -> void:
	_use_pad(false, -1)
	_held = Vector2i.ZERO
	_dpad_held = Vector2i.ZERO
	_stick = Vector2.ZERO
	_stick_dir = Vector2i.ZERO
	_axis_down.clear()
	_remember.clear()
	scope = null


# --- Which device ---------------------------------------------------------------------------------

## A pad's family from its name and vendor (Input.get_joy_name / get_joy_info): PlayStation and Nintendo pads by name
## or vendor id, everything else reads as Xbox (Godot names the buttons by the Xbox layout's positions).
static func family_of(joy_name: String, vendor: int = 0) -> String:
	var n := joy_name.to_lower()
	if vendor == 0x054C or ["dualsense", "dualshock", "playstation", "ps3", "ps4", "ps5", "sony"].any(
			func(w: String) -> bool: return n.contains(w)):
		return "playstation"
	if vendor == 0x057E or ["nintendo", "switch", "pro controller", "joy-con", "joycon"].any(
			func(w: String) -> bool: return n.contains(w)):
		return "nintendo"
	return "xbox"


func _use_pad(on: bool, device: int) -> void:
	if on and device in Input.get_connected_joypads():
		var info := Input.get_joy_info(device)
		family = family_of(Input.get_joy_name(device), int(info.get("vendor_id", 0)))
	_mouse_travel = 0.0
	if on == pad:
		return
	pad = on
	if on:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# A control that only the pad gives focus to lets it go, so a later Space or Enter isn't sent to it.
		var vp := get_viewport()
		var f := vp.gui_get_focus_owner() if vp != null else null
		if f != null and f.has_meta(&"pad_was_none"):
			f.release_focus()
	device_changed.emit(pad)


func _input(event: InputEvent) -> void:
	if event.has_meta(&"pad_synthetic"):
		return   # this tracker's own pointer moves and clicks
	var joy := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if event is InputEventJoypadButton or event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_ON:
		_use_pad(true, event.device)
	elif event is InputEventKey and (event as InputEventKey).pressed or event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_use_pad(false, -1)
	elif event is InputEventMouseMotion:
		_mouse_travel += (event as InputEventMouseMotion).relative.length()
		if _mouse_travel > MOUSE_TAKES_OVER:
			_use_pad(false, -1)
	if not joy or not pad:
		return
	if not InputMap.has_action(&"pad_context"):
		InputActions.ensure()
	scope = scope_now()
	if scope == null:
		_held = Vector2i.ZERO
		return
	if _drive(event):
		get_viewport().set_input_as_handled()


## What a pad event does on the screen in front; true when it's used up here.
func _drive(event: InputEvent) -> bool:
	var dir := _direction(event)
	var f := focus_in(scope)
	if f == null:
		# Nothing has focus yet: a direction or A only puts it on the screen; B still goes back.
		if dir != Vector2i.ZERO or event.is_action_pressed(&"ui_accept"):
			land(scope)
			return true
		return false
	if dir != Vector2i.ZERO:
		_held = dir
		_held_t = REPEAT_DELAY
		step(dir)
		return true
	if event is InputEventJoypadMotion and _is_direction_axis(event as InputEventJoypadMotion):
		return true   # a stick resting or easing back: used up, so nothing else reads it as a press
	if event.is_action_pressed(&"ui_accept"):
		if f is BaseButton or f is LineEdit or f is TextEdit:
			return false   # the engine presses buttons and lets fields take it
		click(f, MOUSE_BUTTON_LEFT)
		return true
	if _pressed(event, &"pad_context"):
		click(f, MOUSE_BUTTON_RIGHT)
		return true
	if _pressed(event, &"pad_explain"):
		explain(f)
		return true
	if _pressed(event, &"pad_tab_prev") or _pressed(event, &"pad_tab_next"):
		return tab(scope, -1 if event.is_action(&"pad_tab_prev") else 1)
	if _pressed(event, &"pad_char_prev") or _pressed(event, &"pad_char_next"):
		if scope.has_method(&"pad_character"):
			scope.call(&"pad_character", -1 if event.is_action(&"pad_char_prev") else 1)
			return true
	return false


## The direction a D-pad press or a left-stick lean starts (Vector2i.ZERO for anything else, or a lean held on).
func _direction(event: InputEvent) -> Vector2i:
	var jb := event as InputEventJoypadButton
	if jb != null and DPAD.has(jb.button_index):
		var d := DPAD[jb.button_index] as Vector2i
		if jb.pressed:
			_dpad_held = d
			return d
		if _dpad_held == d:
			_dpad_held = Vector2i.ZERO
		return Vector2i.ZERO
	var jm := event as InputEventJoypadMotion
	if jm == null or not _is_direction_axis(jm):
		return Vector2i.ZERO
	if jm.axis == JOY_AXIS_LEFT_X:
		_stick.x = jm.axis_value
	else:
		_stick.y = jm.axis_value
	var now := Vector2i.ZERO
	if maxf(absf(_stick.x), absf(_stick.y)) >= (STICK_OFF if _stick_dir != Vector2i.ZERO else STICK_ON):
		if absf(_stick.x) >= absf(_stick.y):
			now = Vector2i.RIGHT if _stick.x > 0.0 else Vector2i.LEFT
		else:
			now = Vector2i.DOWN if _stick.y > 0.0 else Vector2i.UP
	var started := now != Vector2i.ZERO and now != _stick_dir
	_stick_dir = now
	return now if started else Vector2i.ZERO


static func _is_direction_axis(jm: InputEventJoypadMotion) -> bool:
	return jm.axis == JOY_AXIS_LEFT_X or jm.axis == JOY_AXIS_LEFT_Y


## A button press of `action`, or a trigger's lean past halfway (once, until it comes back).
func _pressed(event: InputEvent, action: StringName) -> bool:
	if not event.is_action(action):
		return false
	if event is InputEventJoypadMotion:
		var down := event.get_action_strength(action) >= 0.5
		var was := bool(_axis_down.get(action, false))
		_axis_down[action] = down
		return down and not was
	return event.is_action_pressed(action)


func _process(delta: float) -> void:
	if not pad:
		ring.hide_ring()
		return
	scope = scope_now()
	var vp := get_viewport()
	var f := vp.gui_get_focus_owner()
	if scope == null:
		ring.hide_ring()
		if f != null:
			f.release_focus()   # exploring or fighting, A and B are the world's, never a HUD button's
		return
	f = focus_in(scope)
	if f == null:
		land(scope)
		f = focus_in(scope)
	if f == null:
		ring.hide_ring()
		return
	# Kept up to date whoever moved focus (a screen's own grab_focus too), for coming back to it.
	var sid := scope.get_instance_id()
	var kept := _remember.get(sid) as WeakRef
	if kept == null or kept.get_ref() != f:
		_remember[sid] = weakref(f)
	_last_scope_id = sid
	_last_rect = rect_of(f)
	ring.target(_last_rect)
	_repeat(delta)
	_scroll(delta)


func _repeat(delta: float) -> void:
	var holding := _dpad_held if _dpad_held != Vector2i.ZERO else _stick_dir
	if holding == Vector2i.ZERO or holding != _held:
		_held = holding
		_held_t = REPEAT_DELAY
		return
	_held_t -= delta
	if _held_t <= 0.0:
		_held_t = REPEAT_EVERY
		step(_held)


## The right stick scrolls the list that holds focus (else the screen's biggest).
func _scroll(delta: float) -> void:
	if not InputMap.has_action(&"pad_scroll_down"):
		return
	var v := Input.get_vector(&"pad_scroll_left", &"pad_scroll_right", &"pad_scroll_up", &"pad_scroll_down")
	if v.length() < 0.2:
		return
	var sc := scroller(scope)
	if sc == null:
		return
	sc.scroll_vertical += roundi(v.y * SCROLL_SPEED * delta)
	sc.scroll_horizontal += roundi(v.x * SCROLL_SPEED * delta)


# --- The screen in front --------------------------------------------------------------------------

## The topmost visible screen layer with something to choose, or null.
func scope_now() -> CanvasLayer:
	var open: Array[CanvasLayer] = []
	for i in range(_layers.size() - 1, -1, -1):
		var l := _layers[i]
		if not is_instance_valid(l):
			_layers.remove_at(i)
			continue
		if l.is_inside_tree() and is_scope(l):
			open.append(l)
	open.sort_custom(func(a: CanvasLayer, b: CanvasLayer) -> bool:
		return a.layer > b.layer if a.layer != b.layer else a.is_greater_than(b))
	for l in open:
		if not choices(l).is_empty():
			return l
	return null


static func is_scope(l: CanvasLayer) -> bool:
	if not l.visible or l.is_queued_for_deletion() or l.process_mode == Node.PROCESS_MODE_DISABLED:
		return false   # hidden, or sinking away (UiMotion.dismiss)
	if l.has_meta(&"pad_scope"):
		return bool(l.get_meta(&"pad_scope"))
	return l.layer >= LAYER_MIN and l.layer <= LAYER_MAX


static func inside(c: Node, root: Node) -> bool:
	return c == root or root.is_ancestor_of(c)


## The control with focus, if it's on `root`.
func focus_in(root: Node) -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if f != null and f.is_visible_in_tree() and inside(f, root) else null


## Every choice on `root`, in tree order.
static func choices(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	var vp := root.get_viewport()
	if vp == null:
		return out
	var screen := vp.get_visible_rect().size
	_collect(root, out, screen.x * screen.y * BACKDROP)
	return out


static func _collect(n: Node, out: Array[Control], backdrop: float) -> void:
	for ch: Node in n.get_children():
		if ch is Window or ch.has_meta(&"pad_skip"):
			continue
		var ci := ch as CanvasItem
		if ci != null and not ci.visible:
			continue
		var c := ch as Control
		if c != null and is_choice(c, backdrop):
			out.append(c)
		_collect(ch, out, backdrop)


static func is_choice(c: Control, backdrop: float = INF) -> bool:
	if c is ScrollBar or c is ScrollContainer or c is TermText:
		return false
	var r := rect_of(c)
	if r.size.x < 2.0 or r.size.y < 2.0 or r.size.x * r.size.y > backdrop:
		return false
	if c.has_meta(&"pad_target"):
		return bool(c.get_meta(&"pad_target"))
	if c.focus_mode != Control.FOCUS_NONE or c is BaseButton:
		return true
	if TipCards.tip_of(c).is_valid():
		return true
	return c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_script() != null and c.has_method(&"_gui_input")


## A control's rectangle on the screen (viewport coordinates, through its CanvasLayer).
static func rect_of(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale()).abs()


# --- Moving focus ---------------------------------------------------------------------------------

## Puts focus on `root`'s remembered choice, else the one it names ("pad_first"), else the one nearest where focus
## just was (a screen that rebuilt), else its first in reading order.
func land(root: CanvasLayer) -> void:
	var list := choices(root)
	if list.is_empty():
		return
	var sid := root.get_instance_id()
	var keep := _remember.get(sid) as WeakRef
	var c := keep.get_ref() as Control if keep != null else null
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree() or not c in list:
		c = null
		for named in list:
			if named.has_meta(&"pad_first"):
				c = named
				break
	if c == null:
		c = _nearest(list, _last_rect.get_center()) if sid == _last_scope_id and _last_rect.size != Vector2.ZERO \
			else first(list)
	_last_scope_id = sid
	focus_on(c)


## The first choice in reading order.
static func first(list: Array[Control]) -> Control:
	var best: Control = null
	var best_r := Rect2()
	for c in list:
		var r := rect_of(c)
		if best == null or r.position.y < best_r.position.y - 12.0 \
				or absf(r.position.y - best_r.position.y) <= 12.0 and r.position.x < best_r.position.x:
			best = c
			best_r = r
	return best


static func _nearest(list: Array[Control], at: Vector2) -> Control:
	var best: Control = null
	var d := INF
	for c in list:
		var dc := rect_of(c).get_center().distance_squared_to(at)
		if dc < d:
			d = dc
			best = c
	return best


## Moves focus one choice `dir`. A slider takes left and right itself, and so does a control with a pad_adjust(dir)
## method or a "pad_adjust" meta Callable (a row of choices, a drawn slider).
func step(dir: Vector2i) -> void:
	if scope == null:
		return
	var f := focus_in(scope)
	if f == null:
		land(scope)
		return
	if dir.y == 0 and f.has_method(&"pad_adjust"):
		f.call(&"pad_adjust", dir.x)
		return
	if dir.y == 0 and f.has_meta(&"pad_adjust"):
		(f.get_meta(&"pad_adjust") as Callable).call(dir.x)
		return
	var r := f as Range
	if r != null and dir.y == 0 and r.editable:
		var by := r.step if r.step > 0.0 else (r.max_value - r.min_value) / 20.0
		r.value += by * dir.x
		return
	var to := neighbour(f, dir, choices(scope))
	if to != null:
		focus_on(to)


## The choice nearest `from` in direction `dir`: straight ahead first, then the least sideways.
static func neighbour(from: Control, dir: Vector2i, list: Array[Control]) -> Control:
	var a := rect_of(from)
	var ac := a.get_center()
	var best: Control = null
	var best_score := INF
	for c in list:
		if c == from or from.is_ancestor_of(c) or c.is_ancestor_of(from):
			continue
		var b := rect_of(c)
		var bc := b.get_center()
		if (bc - ac).dot(Vector2(dir)) <= 1.0:
			continue
		var ahead: float
		var side: float
		if dir.x != 0:
			ahead = maxf(0.0, b.position.x - a.end.x) if dir.x > 0 else maxf(0.0, a.position.x - b.end.x)
			side = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
		else:
			ahead = maxf(0.0, b.position.y - a.end.y) if dir.y > 0 else maxf(0.0, a.position.y - b.end.y)
			side = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
		var centre_off := absf((bc - ac).dot(Vector2(dir.y, dir.x)))
		var score := ahead + side * SIDEWAYS + centre_off * 0.05
		if score < best_score:
			best_score = score
			best = c
	return best


## Gives `c` focus (one that takes none from the mouse gets it until it loses it), brings it into view and moves the
## pointer onto it.
func focus_on(c: Control) -> void:
	if c.focus_mode == Control.FOCUS_NONE:
		c.set_meta(&"pad_was_none", true)
		c.focus_mode = Control.FOCUS_ALL
		c.focus_exited.connect(_restore_focus_mode.bind(c), CONNECT_ONE_SHOT)
	c.grab_focus()
	if scope != null and inside(c, scope):
		_remember[scope.get_instance_id()] = weakref(c)
	for p: Node in _ancestors(c):
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
	_last_rect = rect_of(c)
	_point_at(_last_rect.get_center())


static func _restore_focus_mode(c: Control) -> void:
	if is_instance_valid(c) and c.has_meta(&"pad_was_none"):
		c.remove_meta(&"pad_was_none")
		c.focus_mode = Control.FOCUS_NONE


static func _ancestors(c: Node) -> Array[Node]:
	var out: Array[Node] = []
	var p := c.get_parent()
	while p != null:
		out.append(p)
		p = p.get_parent()
	return out


# --- Standing in for the mouse --------------------------------------------------------------------

## Where the pointer is, for code that follows it (TipCards): the middle of the focused choice while the pad is in
## use, else the mouse.
static func pointer(vp: Viewport) -> Vector2:
	if current != null and current.pad:
		var f := vp.gui_get_focus_owner()
		if f != null and f.is_visible_in_tree():
			return rect_of(f).get_center()
	return vp.get_mouse_position()


## Whether the pad is the device in use now.
static func active() -> bool:
	return current != null and current.pad


func _point_at(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	_send(ev)


## A click of `button` in the middle of `c`, as the mouse would make it.
func click(c: Control, button: MouseButton) -> void:
	var at := rect_of(c).get_center()
	_point_at(at)
	for down: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		_send(ev)


## Sent once the event being handled is done with (a click inside a press would be handled twice).
func _send(ev: InputEvent) -> void:
	ev.set_meta(&"pad_synthetic", true)
	_push.call_deferred(ev)


func _push(ev: InputEvent) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.push_input(ev, true)


## Y: the rules card of `c` (or of the first thing in it that has one) opens at once; again pins it, and again
## closes it (TipCards.explain). With no card to show, it closes the newest pinned card.
func explain(c: Control) -> void:
	var cards := TipCards.current
	if cards == null:
		return
	var src := TipCards.source_at(c)
	if src.is_empty():
		for d: Node in c.find_children("*", "Control", true, false):
			src = TipCards.source_at(d as Control)
			if not src.is_empty():
				break
	cards.explain(src, rect_of(c).get_center())


## LB/RB: the screen's next or previous tab. True when it had tabs to step through.
func tab(root: Node, step_: int) -> bool:
	if root.has_method(&"pad_tab"):
		root.call(&"pad_tab", step_)
		return true
	for n: Node in root.find_children("*", "", true, false):
		var ci := n as CanvasItem
		if ci == null or not ci.is_visible_in_tree():
			continue
		if n is TabContainer:
			var tc := n as TabContainer
			if tc.get_tab_count() > 1:
				tc.current_tab = wrapi(tc.current_tab + step_, 0, tc.get_tab_count())
				return true
		elif n is TabBar:
			var tb := n as TabBar
			if tb.tab_count > 1:
				tb.current_tab = wrapi(tb.current_tab + step_, 0, tb.tab_count)
				return true
		elif n is BaseButton and (n as BaseButton).toggle_mode and (n as BaseButton).button_group != null \
				and (n as BaseButton).button_pressed:
			var group := (n as BaseButton).button_group.get_buttons().filter(
				func(b: BaseButton) -> bool: return b.is_visible_in_tree() and not b.disabled)
			if group.size() > 1:
				click(group[wrapi(group.find(n) + step_, 0, group.size())] as BaseButton, MOUSE_BUTTON_LEFT)
				return true
	return false


## The list the right stick scrolls: the one holding focus, else the biggest on the screen.
static func scroller(root: Node) -> ScrollContainer:
	var f := root.get_viewport().gui_get_focus_owner() if root.get_viewport() != null else null
	if f != null and inside(f, root):
		for p: Node in _ancestors(f):
			if p is ScrollContainer and (p as ScrollContainer).is_visible_in_tree():
				return p as ScrollContainer
	var best: ScrollContainer = null
	var area := 0.0
	for n: Node in root.find_children("*", "ScrollContainer", true, false):
		var sc := n as ScrollContainer
		if sc.is_visible_in_tree() and sc.size.x * sc.size.y > area:
			area = sc.size.x * sc.size.y
			best = sc
	return best
