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
		if control is ScrollContainer:
			var candidate := control as ScrollContainer
			if candidate.get_v_scroll_bar().max_value > candidate.size.y:
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
			label = button.text
			disabled = button.disabled
			selected = button.button_pressed if button.toggle_mode else false
			role = "button"
		elif control is Label:
			label = (control as Label).text
		elif control is RichTextLabel:
			label = (control as RichTextLabel).get_parsed_text()
		elif control is LineEdit:
			var input := control as LineEdit
			label = input.placeholder_text
			value = "Hidden text" if input.secret else input.text
			role = "input"
		elif control is Slider:
			label = control.tooltip_text if control.tooltip_text != "" else "Adjust value"
			value = str((control as Slider).value)
			role = "slider"
		if label != "" and rect.size.x >= 1 and rect.size.y >= 1:
			var id := str(control.get_instance_id())
			var size := Vector2(control.get_window().size)
			# Account for stretch, interface scale and letterboxing before mapping to UIKit points.
			var transform := control.get_viewport().get_screen_transform() * control.get_global_transform_with_canvas() * control.get_global_transform().affine_inverse()
			rect = transform * rect
			rect.position -= Vector2(control.get_window().position)
			items.append({"id": id, "label": label, "value": value, "role": role, "disabled": disabled,
				"selected": selected, "hint": control.tooltip_text,
				"frame": [rect.position.x / size.x, rect.position.y / size.y, rect.size.x / size.x, rect.size.y / size.y]})
			controls[id] = weakref(control)
			if control is BaseButton or control is LineEdit:
				return
	for child in node.get_children():
		_collect(child, clip, items)


func activate(kind: String, command: String) -> void:
	if kind == "access_scroll":
		if is_instance_valid(scroll):
			scroll.scroll_vertical += roundi(scroll.size.y * (0.8 if command == "down" else -0.8))
		return
	if command.get_slice(":", 0) != str(revision):
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
	elif control is LineEdit:
		control.grab_focus()
