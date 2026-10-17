class_name TouchRouter
extends Node
## One touch path for stock controls and the world. GUI clicks are emitted only after a tap is recognized;
## world commands are semantic calls, so neither dragging nor mouse emulation can accidentally execute one.

var gestures := TouchGesture.new()
var owners: Dictionary = {}
var context_next := false
var explain_next := false
var _epoch := 0
var selection_sheet: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not MobileDevice.enabled() or event.has_meta(&"touch_synthetic"):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		MobileDevice.pointer = touch.position
		if touch.pressed:
			_press.call_deferred(touch.index, touch.position, _epoch)
		else:
			_release.call_deferred(touch.index, touch.position, touch.canceled, _epoch)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		MobileDevice.pointer = (event as InputEventScreenDrag).position
		_drag.call_deferred(event as InputEventScreenDrag, _epoch)
		get_viewport().set_input_as_handled()


func _press(index: int, at: Vector2, epoch: int) -> void:
	if epoch != _epoch:
		return
	if MobileDevice.current != null:
		MobileDevice.current.set_modality("touch")
	if PadNav.current != null:
		PadNav.current.clear_held()
		PadNav.current._use_pad(false, -1)
	_point(at)
	var control := get_viewport().gui_get_hovered_control()
	var surface: Node = control
	while surface != null and not surface.has_method("touch_surface_press"):
		surface = surface.get_parent()
	if surface is Control:
		control = surface as Control
	owners[index] = weakref(control) if control != null else null
	gestures.press(index, at, "ui" if control != null else "world", Time.get_ticks_msec())
	if control != null and control.has_method("touch_surface_press"):
		control.call("touch_surface_press", index, at)
	elif control is Slider:
		_button(at, MOUSE_BUTTON_LEFT, true)


func _drag(drag: InputEventScreenDrag, epoch: int) -> void:
	if epoch != _epoch:
		return
	var update := gestures.move(drag.index, drag.position)
	var control := _owner(drag.index)
	if control != null and control.has_method("touch_surface_drag"):
		control.call("touch_surface_drag", drag.index, drag.position)
		return
	if control is Slider:
		_point(drag.position, drag.relative, MOUSE_BUTTON_MASK_LEFT)
		return
	match str(update.get("kind", "")):
		"scroll":
			_scroll(control, update["delta"] as Vector2)
		"pan", "camera":
			var target := world_target()
			if target != null:
				target.call("touch_camera", update)


## A vertical swipe over a horizontal tab strip belongs to the enclosing page. At a nested list's edge,
## continue through its parent rather than trapping the player's finger in a container that cannot move.
func _scroll(control: Control, delta: Vector2) -> void:
	var vertical := absf(delta.y) >= absf(delta.x)
	var amount := roundi(delta.y if vertical else delta.x)
	var node: Node = control
	while node != null:
		if node is ScrollContainer:
			var scroll := node as ScrollContainer
			var mode := scroll.vertical_scroll_mode if vertical else scroll.horizontal_scroll_mode
			var bar: ScrollBar = scroll.get_v_scroll_bar() if vertical else scroll.get_h_scroll_bar()
			var limit := maxf(0.0, bar.max_value - bar.page)
			if mode != ScrollContainer.SCROLL_MODE_DISABLED and limit > 0 and (amount < 0 and bar.value < limit or amount > 0 and bar.value > 0):
				if vertical:
					scroll.scroll_vertical -= amount
				else:
					scroll.scroll_horizontal -= amount
				return
		node = node.get_parent()


func _release(index: int, at: Vector2, canceled: bool, epoch: int) -> void:
	if epoch != _epoch:
		return
	var control := _owner(index)
	var update := gestures.release(index, at, Time.get_ticks_msec(), canceled)
	owners.erase(index)
	if control != null and control.has_method("touch_surface_release"):
		control.call("touch_surface_release", index, at, canceled or not control.is_visible_in_tree())
		return
	if control is Slider:
		_button(at, MOUSE_BUTTON_LEFT, false)
		return
	if update.is_empty():
		return
	# Buttons and text fields use their primary action even after a slow frame or deliberate hold. A
	# synthesized right click on a field opens Godot's desktop menu over the native software keyboard.
	# Explicit alternate actions and held world gestures retain their context behavior.
	var primary_control := control is BaseButton or control is LineEdit or control is TextEdit
	var context := context_next or (str(update["kind"]) == "context" and not primary_control)
	context_next = false
	if str(update["owner"]) == "ui":
		if control == null or not control.is_visible_in_tree():
			return
		_point(at)
		var hit := get_viewport().gui_get_hovered_control()
		if hit != control and (hit == null or not control.is_ancestor_of(hit)):
			return
		if control is BaseButton and not (control as BaseButton).disabled:
			MobileNative.feedback()
		if explain_next and PadNav.current != null:
			explain_next = false
			PadNav.current.explain(control)
		elif control is OptionButton and not context:
			_show_selection(control as OptionButton)
		else:
			var button := MOUSE_BUTTON_RIGHT if context else MOUSE_BUTTON_LEFT
			_button(at, button, true)
			_button(at, button, false)
	else:
		var target := world_target()
		if target != null:
			target.call("touch_tap", at, context or explain_next)
			explain_next = false


func _owner(index: int) -> Control:
	var ref := owners.get(index) as WeakRef
	return ref.get_ref() as Control if ref != null else null


func world_target() -> Node:
	if get_tree().paused or (PadNav.current != null and PadNav.current.scope_now() != null):
		return null
	var targets := get_tree().get_nodes_in_group(&"touch_world")
	targets.reverse()
	for target: Node in targets:
		if bool(target.call("touch_ready")):
			return target
	return null


func cancel() -> void:
	_epoch += 1
	for index: int in owners:
		var control := _owner(index)
		if control != null and control.has_method("touch_surface_cancel"):
			control.call("touch_surface_cancel")
		elif control is Slider:
			_button(Vector2(-100, -100), MOUSE_BUTTON_LEFT, false)
	owners.clear()
	gestures.cancel()
	context_next = false
	explain_next = false


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel()


func _point(at: Vector2, relative: Vector2 = Vector2.ZERO, mask: MouseButtonMask = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = mask
	event.set_meta(&"touch_synthetic", true)
	event.set_meta(&"touch_gui", true)
	get_viewport().push_input(event, true)


func _button(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	event.set_meta(&"touch_synthetic", true)
	event.set_meta(&"touch_gui", true)
	get_viewport().push_input(event, true)


## Stock OptionButton popups live in a different viewport. Present their exact options in the same touch path
## instead of sending synthetic mouse events to the wrong viewport or depending on tiny native popup rows.
func _show_selection(option: OptionButton) -> void:
	if option.disabled:
		return
	_close_selection()
	selection_sheet = CanvasLayer.new()
	selection_sheet.layer = 90
	selection_sheet.set_meta(&"pad_scope", true)
	add_child(selection_sheet)
	var body := MobilePage.build(selection_sheet, option.tooltip_text if option.tooltip_text != "" else "Choose", _close_selection)
	(body.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var source: WeakRef = weakref(option)
	for i in option.item_count:
		if option.is_item_separator(i):
			continue
		var button := MobileUi.button(option.get_item_text(i), func() -> void:
			var current := source.get_ref() as OptionButton
			_close_selection()
			if current == null or not current.is_inside_tree() or current.disabled or i >= current.item_count or current.is_item_disabled(i):
				return
			current.select(i)
			current.item_selected.emit(i))
		button.disabled = option.is_item_disabled(i)
		if i == option.selected:
			UiParts.light_up(button)
		body.add_child(button)


func _close_selection() -> void:
	if selection_sheet != null:
		selection_sheet.hide()
		selection_sheet.queue_free()
		selection_sheet = null
	cancel()
