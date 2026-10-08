class_name PadPrompts
extends CanvasLayer
## The pad's prompt bar (U6, docs/ui/controller.md): along the bottom right while the pad is in use on a screen, the
## buttons that do something there with their pictures: A to choose, B to go back, Y to explain when what has focus
## has a rules card, X for its menu when it has one ("pad_menu" meta, the menu's name), LB/RB when the screen has tabs
## and LT/RT when it has characters. A screen can add its own with pad_prompts() -> Array of [place, text].
## PadNav makes it; it redraws only when the screen, focus or pad family changes.

const ICON := 26
const LAYER := 118

var _bar: HBoxContainer
var _key := ""


func _init() -> void:
	name = "PadPrompts"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var s := UiKit.style("ui_black", "gilt_dark", 1, 0.86)
	s.set_content_margin_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	plate.add_theme_stylebox_override("panel", s)
	add_child(plate)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 14)
	plate.add_child(_bar)


## What the bar shows for `scope` with `focus`: [[place or places joined by "+", text], ...].
static func prompts_for(scope: Node, focus: Control) -> Array:
	var out: Array = [["a", "Choose"], ["b", "Back"]]
	if focus != null:
		if focus.has_meta(&"pad_menu"):
			out.append(["x", str(focus.get_meta(&"pad_menu"))])
		if not TipCards.source_at(focus).is_empty():
			out.append(["y", "Explain"])
	if scope != null:
		if scope.has_method(&"pad_tab") or _has_tabs(scope):
			out.append(["lb+rb", "Tabs"])
		if scope.has_method(&"pad_character"):
			out.append(["lt+rt", "Character"])
		if scope.has_method(&"pad_prompts"):
			out.append_array(scope.call(&"pad_prompts") as Array)
	return out


static func _has_tabs(root: Node) -> bool:
	for n: Node in root.find_children("*", "", true, false):
		var ci := n as CanvasItem
		if ci == null or not ci.is_visible_in_tree():
			continue
		if n is TabContainer or n is TabBar:
			return true
	return false


func _process(_delta: float) -> void:
	var nav := PadNav.current
	var scope := nav.scope if nav != null and nav.pad else null
	if scope == null:
		visible = false
		_key = ""
		return
	var focus := get_viewport().gui_get_focus_owner()
	var key := "%d:%d:%s" % [scope.get_instance_id(), focus.get_instance_id() if focus != null else 0, PadGlyphs.family()]
	visible = true
	if key == _key:
		return
	_key = key
	show_prompts(prompts_for(scope, focus))


func show_prompts(list: Array) -> void:
	for c: Node in _bar.get_children():
		c.queue_free()
	for p: Array in list:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		for place: String in str(p[0]).split("+"):
			var tex := PadGlyphs.texture(place)
			if tex == null:
				continue
			var icon := TextureRect.new()
			icon.texture = tex
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(ICON, ICON)
			icon.modulate = Look.color("vellum")
			item.add_child(icon)
		var l := UiKit.label(str(p[1]), 15, "vellum")
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(l)
		_bar.add_child(item)
