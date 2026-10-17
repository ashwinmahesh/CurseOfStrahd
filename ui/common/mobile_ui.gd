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
	if node.has_meta(&"mobile_tabs"):
		return
	if node is Control:
		var control := node as Control
		control.custom_minimum_size.x = minf(control.custom_minimum_size.x, 160) if control is UiParts.Drawn else 0
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if node is Label:
		var label := node as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var base := int(label.get_meta(&"mobile_base_font", clampi(label.get_theme_font_size("font_size"), 14, 24)))
		label.set_meta(&"mobile_base_font", base)
		label.add_theme_font_size_override("font_size", UiScale.text(base))
	elif node is RichTextLabel:
		var rich := node as RichTextLabel
		for font_size: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
			rich.add_theme_font_size_override(font_size, UiScale.text(18))
	elif node is LineEdit:
		(node as LineEdit).custom_minimum_size.y = 48
		(node as LineEdit).add_theme_font_size_override("font_size", UiScale.text(18))
	elif node is Button:
		var button_ := node as Button
		button_.custom_minimum_size.y = 48
		button_.add_theme_font_size_override("font_size", UiScale.text(18))
		button_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if button_.get_parent() is FlowContainer:
			button_.autowrap_mode = TextServer.AUTOWRAP_OFF
			button_.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	elif node is Slider:
		(node as Slider).custom_minimum_size.y = 48
	for child in node.get_children():
		fit(child)


static func tabs(values: Array[String], selected: String, pick: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_meta(&"mobile_tabs", true)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	scroll.add_child(row)
	for value in values:
		var tab := button(value, func() -> void:
			select_tab(scroll, value)
			pick.call(value))
		tab.set_meta(&"tab_value", value)
		tab.toggle_mode = true
		tab.button_pressed = value == selected
		tab.autowrap_mode = TextServer.AUTOWRAP_OFF
		if value == selected:
			UiParts.light_up(tab)
		row.add_child(tab)
	scroll.set_meta(&"pad_tabs", func(step: int) -> void:
		var buttons := row.get_children()
		var current := 0
		for i in buttons.size():
			if (buttons[i] as Button).button_pressed:
				current = i
		for i in range(1, buttons.size() + 1):
			var next := buttons[posmod(current + step * i, buttons.size())] as Button
			if not next.disabled:
				next.pressed.emit()
				if is_instance_valid(next) and not next.is_queued_for_deletion() and next.is_inside_tree():
					scroll.ensure_control_visible.call_deferred(next)
				break)
	return scroll


static func select_tab(scroll: ScrollContainer, selected: String) -> void:
	for tab: Button in scroll.get_child(0).get_children():
		tab.button_pressed = str(tab.get_meta(&"tab_value", "")) == selected
		if tab.button_pressed:
			UiParts.light_up(tab)
		else:
			tab.add_theme_stylebox_override("normal", UiKit.button_style("normal"))
			tab.remove_theme_color_override("font_color")
