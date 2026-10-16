class_name MobileUi
extends RefCounted
## Shared mobile controls; desktop themes and metrics remain untouched.


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func text(value: String, colour: String = "vellum") -> Label:
	var label := UiKit.label(value, UiScale.text(18), colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func button(value: String, action: Callable) -> Button:
	var result := UiKit.button(value, action, UiScale.text(18))
	result.custom_minimum_size.y = 48
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result



## Reflow a legacy panel only when explicitly hosted in a mobile sheet; desktop metrics are preserved.
static func fit(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.custom_minimum_size.x = minf(control.custom_minimum_size.x, 160) if control is UiParts.Drawn else 0
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is Label:
		var label := node as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", UiScale.text(18))
	elif node is Button:
		var button_ := node as Button
		button_.custom_minimum_size.y = 48
		button_.add_theme_font_size_override("font_size", UiScale.text(18))
		button_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif node is Slider:
		(node as Slider).custom_minimum_size.y = 48
	for child in node.get_children():
		fit(child)


static func tabs(values: Array[String], selected: String, pick: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	scroll.add_child(row)
	for value in values:
		var tab := button(value, func() -> void: pick.call(value))
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		if value == selected:
			UiParts.light_up(tab)
		row.add_child(tab)
	return scroll
