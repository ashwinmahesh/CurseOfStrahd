class_name MobileAccessibility
extends RefCounted
## Native semantic projection of the active mobile surface. Activation is checked against the latest snapshot.
## World commands remain accessible through MobileControls' target, party and action lists.

var controls: Dictionary = {}
var revision := 0
var snapshot_key := 0
var scope: Node
var scroll: ScrollContainer


func snapshot(root: Node) -> Dictionary:
	scope = PadNav.current.scope_now() if PadNav.current != null else null
	var active := scope if scope != null else root
	var items: Array[Dictionary] = []
	controls.clear()
	scroll = null
	_collect(active, Rect2(Vector2.ZERO, MobileDevice.logical_size()), items)
	var key := hash(items)
	if key == snapshot_key:
		return {}
	snapshot_key = key
	revision += 1
	return {"revision": str(revision), "items": items}


func _collect(node: Node, clip: Rect2, items: Array[Dictionary]) -> void:
	if node.is_queued_for_deletion():
		return
	if node is CanvasLayer and not (node as CanvasLayer).visible:
		return
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		if control.has_meta(&"access_row_button"):
			var button := (control.get_meta(&"access_row_button") as WeakRef).get_ref() as Control
			if is_instance_valid(button):
				_collect(button, clip, items)
			return
		if control is ScrollContainer:
			var candidate := control as ScrollContainer
			if candidate.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and candidate.get_v_scroll_bar().max_value > candidate.get_v_scroll_bar().page:
				scroll = candidate
			clip = clip.intersection(control.get_global_rect())
		var rect := clip.intersection(control.get_global_rect())
		var label := ""
		var value := ""
		var role := "text"
		var disabled := false
		var selected := false
		if control is Button:
			var button := control as Button
			label = str(button.get_meta(&"access_label", button.text if button.text != "" else button.tooltip_text))
			disabled = button.disabled
			selected = bool(button.get_meta(&"access_selected", button.button_pressed if button.toggle_mode else false))
			role = "button"
			if button is CheckButton or button is CheckBox:
				value = "On" if button.button_pressed else "Off"
		elif control is Label:
			label = (control as Label).text
		elif control is RichTextLabel:
			label = (control as RichTextLabel).get_parsed_text()
		elif control is LineEdit:
			var input := control as LineEdit
			label = _input_label(control, input.placeholder_text, "Text field")
			disabled = not input.editable
			value = "Hidden text" if input.secret else input.text
			role = "input"
		elif control is Slider:
			label = _input_label(control, control.tooltip_text, "Adjust value")
			value = str((control as Slider).value)
			role = "slider"
			disabled = not (control as Slider).editable
		if label != "" and rect.size.x >= 1 and rect.size.y >= 1:
			var id := str(control.get_instance_id())
			var size := Vector2(control.get_window().size)
			# Account for stretch, interface scale and letterboxing before mapping to UIKit points.
			var transform := control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * control.get_global_transform().affine_inverse()
			rect = transform * rect
			rect.position -= Vector2(control.get_window().position)
			items.append({"id": id, "label": label, "value": value, "role": role, "disabled": disabled,
				"selected": selected, "hint": str(control.get_meta(&"access_hint", control.tooltip_text)),
				"frame": [rect.position.x / size.x, rect.position.y / size.y, rect.size.x / size.x, rect.size.y / size.y]})
			controls[id] = weakref(control)
			if control is BaseButton or control is LineEdit:
				return
	for child in node.get_children():
		_collect(child, clip, items)


func activate(kind: String, command: String) -> void:
	if command.get_slice(":", 0) != str(revision):
		return
	if kind == "access_scroll":
		var direction := command.get_slice(":", 1)
		if is_instance_valid(scroll) and direction in ["up", "down"]:
			scroll.scroll_vertical += roundi(scroll.size.y * (0.8 if direction == "down" else -0.8))
		return
	var ref := controls.get(command.get_slice(":", 1)) as WeakRef
	var control := ref.get_ref() as Control if ref != null else null
	if control == null or control.is_queued_for_deletion() or not control.is_visible_in_tree():
		return
	if scope != null and control != scope and not scope.is_ancestor_of(control):
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return
	if control is Slider:
		var slider := control as Slider
		if not slider.editable or kind not in ["access_increment", "access_decrement"]:
			return
		slider.value += maxf(slider.step, (slider.max_value - slider.min_value) / 20.0) * (-1 if kind == "access_decrement" else 1)
	elif kind != "access_activate":
		return
	elif control is OptionButton:
		UiFeel.touch._show_selection(control as OptionButton)
	elif control is BaseButton:
		MobileNative.feedback()
		var button := control as BaseButton
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		button.pressed.emit()
	elif control is LineEdit and (control as LineEdit).editable:
		control.grab_focus()


func _input_label(control: Control, explicit: String, fallback: String) -> String:
	if control.has_meta(&"access_label"):
		return str(control.get_meta(&"access_label"))
	if explicit != "":
		return explicit
	var parent := control.get_parent()
	for index in range(control.get_index() - 1, -1, -1):
		var sibling := parent.get_child(index)
		if sibling is Label and (sibling as Label).text != "":
			return (sibling as Label).text
	return fallback
