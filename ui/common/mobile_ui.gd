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

