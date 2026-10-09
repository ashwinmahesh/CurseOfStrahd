class_name PadPrompts
extends CanvasLayer
## The pad's prompt bar (U6, docs/ui/controller.md): along the bottom right while the pad is in use on a screen, the
## buttons that do something there with their pictures: A to choose, B to go back, Y to explain when what has focus
## has a rules card, X for its menu when it has one (its pad_menu_name() or "pad_menu" meta: the menu's name), LB/RB
## when the screen has tabs
## and LT/RT when it has characters. A screen can add its own with pad_prompts() -> Array of [place, text], which
## replace the general ones for the same buttons.
## PadNav makes it; it redraws only when the screen, focus or pad family changes.

const ICON := 26
const LAYER := 118

## What the pad does in the world when no screen is in front (exploring: PadExplore; fights: PadCombat): [place,
## text] pairs, and who set them (set_world, clear_world), so one never clears the other's.
static var world: Array = []
static var _world_owner: WeakRef = null
## How far above the bottom edge the world's bar stands (clear of the exploring command bar, or a fight's hotbar).
static var world_raise := WORLD_RAISE
## Where the bar is over the world while it shows (empty when it doesn't), for the HUD to keep its exit plaques clear
## of it (ExploreHud; UI QA UI-12: a plaque at the screen's edge sat half under the bar).
static var world_rect := Rect2()


static func set_world(owner: Object, list: Array, raise: float = WORLD_RAISE) -> void:
	world = list
	world_raise = raise
	_world_owner = weakref(owner)


## Clears the world's prompts if `owner` set them.
static func clear_world(owner: Object) -> void:
	if owns(owner):
		world = []
		_world_owner = null


static func owns(owner: Object) -> bool:
	return _world_owner != null and _world_owner.get_ref() == owner

var _bar: HBoxContainer
var _plate: PanelContainer
## How far the bar stands above the bottom edge over the world, clear of the HUD's command bar.
const WORLD_RAISE := 78.0
var _key := ""


func _init() -> void:
	name = "PadPrompts"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var plate := PanelContainer.new()
	_plate = plate
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
	var extra: Array = scope.call(&"pad_prompts") as Array if scope != null and scope.has_method(&"pad_prompts") else []
	var out: Array = [["a", "Type" if focus is LineEdit or focus is TextEdit else "Choose"], ["b", "Back"]]
	if focus != null:
		var menu := str(focus.call(&"pad_menu_name")) if focus.has_method(&"pad_menu_name") \
			else str(focus.get_meta(&"pad_menu", ""))
		if menu != "":
			out.append(["x", menu])
		if not TipCards.source_at(focus).is_empty():
			out.append(["y", "Explain"])
	if scope != null:
		if scope.has_method(&"pad_tab") or _has_tabs(scope):
			out.append(["lb+rb", "Tabs"])
		if scope.has_method(&"pad_character") or _has_marked(scope, &"pad_characters"):
			out.append(["lt+rt", "Character"])
	# The screen's own come last and replace any general one for the same buttons ("Steps" for "Tabs").
	var own := {}
	for p: Array in extra:
		own[str(p[0])] = true
	out = out.filter(func(p: Array) -> bool: return not own.has(str(p[0])))
	out.append_array(extra)
	return out


static func _has_tabs(root: Node) -> bool:
	for n: Node in root.find_children("*", "", true, false):
		var ci := n as CanvasItem
		if ci == null or not ci.is_visible_in_tree():
			continue
		if n is TabContainer or n is TabBar or n.has_meta(&"pad_tabs"):
			return true
	return false


static func _has_marked(root: Node, key: StringName) -> bool:
	for n: Node in root.find_children("*", "Control", true, false):
		if n.has_meta(key) and (n as Control).is_visible_in_tree():
			return true
	return false


func _process(_delta: float) -> void:
	var nav := PadNav.current
	var scope := nav.scope if nav != null and nav.pad else null
	# Over the world (or a HUD's own buttons) the bar stands above the command bar; over a screen, in the corner.
	var raised := scope == null or scope is CanvasLayer and (scope as CanvasLayer).layer < PadNav.LAYER_MIN
	_plate.offset_bottom = -12.0 - ((world_raise if scope == null else WORLD_RAISE) if raised else 0.0)
	_plate.offset_top = _plate.offset_bottom - _plate.get_combined_minimum_size().y
	if _world_owner != null and _world_owner.get_ref() == null:
		world = []   # whoever set them is gone (a fight that ended)
		_world_owner = null
	if scope == null:
		var shown := nav != null and nav.pad and not world.is_empty() and nav.popup_open() == null
		visible = shown
		world_rect = _plate.get_rect() if shown else Rect2()
		var wkey := "world:%s:%s" % [str(world), PadGlyphs.family()]
		if shown and wkey != _key:
			_key = wkey
			show_prompts(world)
		elif not shown:
			_key = ""
		return
	world_rect = Rect2()
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
			# Smoothed from its mipmaps: the project's nearest filter shrank the 64 px pictures' letters to noise, the
			# bumpers' "LB" reading as "IR" in a 1280x720 window (UI QA UI-09).
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			icon.custom_minimum_size = Vector2(ICON, ICON)
			icon.modulate = Look.color("vellum")
			item.add_child(icon)
		var l := UiKit.label(str(p[1]), 15, "vellum")
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(l)
		_bar.add_child(item)
