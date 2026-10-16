class_name TouchRouter
extends Node
## One touch path for stock controls and the world. GUI clicks are emitted only after a tap is recognized;
## world commands are semantic calls, so neither dragging nor mouse emulation can accidentally execute one.

var gestures := TouchGesture.new()
var owners: Dictionary = {}
var context_next := false
var explain_next := false
var _epoch := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not MobileDevice.enabled() or event.has_meta(&"touch_synthetic"):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press.call_deferred(touch.index, touch.position, _epoch)
		else:
			_release.call_deferred(touch.index, touch.position, touch.canceled, _epoch)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag.call_deferred(event as InputEventScreenDrag, _epoch)
		get_viewport().set_input_as_handled()


func _press(index: int, at: Vector2, epoch: int) -> void:
	if epoch != _epoch:
		return
	if MobileDevice.current != null:
		MobileDevice.current.modality = "touch"
	if PadNav.current != null:
		PadNav.current._use_pad(false, -1)
	_point(at)
	var control := get_viewport().gui_get_hovered_control()
	owners[index] = weakref(control) if control != null else null
	gestures.press(index, at, "ui" if control != null else "world", Time.get_ticks_msec())
	if control is Slider:
		_button(at, MOUSE_BUTTON_LEFT, true)


func _drag(drag: InputEventScreenDrag, epoch: int) -> void:
	if epoch != _epoch:
		return
	var update := gestures.move(drag.index, drag.position)
	var control := _owner(drag.index)
	if control is Slider:
		_point(drag.position, drag.relative, MOUSE_BUTTON_MASK_LEFT)
		return
	match str(update.get("kind", "")):
		"scroll":
			var node: Node = control
			while node != null and not node is ScrollContainer:
				node = node.get_parent()
			if node is ScrollContainer:
				var scroll := node as ScrollContainer
				var delta := update["delta"] as Vector2
				scroll.scroll_vertical -= roundi(delta.y)
				scroll.scroll_horizontal -= roundi(delta.x)
		"pan", "camera":
			var target := world_target()
			if target != null:
				target.call("touch_camera", update)


func _release(index: int, at: Vector2, canceled: bool, epoch: int) -> void:
	if epoch != _epoch:
		return
	var control := _owner(index)
	var update := gestures.release(index, at, Time.get_ticks_msec(), canceled)
	owners.erase(index)
	if control is Slider:
		_button(at, MOUSE_BUTTON_LEFT, false)
		return
	if update.is_empty():
		return
	var context := context_next or str(update["kind"]) == "context"
	context_next = false
	if str(update["owner"]) == "ui":
		if control == null or not control.is_visible_in_tree():
			return
		_point(at)
		var hit := get_viewport().gui_get_hovered_control()
		if hit != control and (hit == null or not control.is_ancestor_of(hit)):
			return
		if explain_next and PadNav.current != null:
			explain_next = false
			PadNav.current.explain(control)
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
		if _owner(index) is Slider:
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
