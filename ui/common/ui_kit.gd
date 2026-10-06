class_name UiKit
extends RefCounted
## Shared building blocks for the party-facing screens (plan §5.6 "Gothic but readable"): iron-and-parchment panels,
## labels with outlines, buttons, section headers, breakdown tooltips. Colours come from the palette (Look); UI draws
## on CanvasLayers after the palette pass so state colours are never quantized away.


static func label(text: String, size: int = 16, colour: String = "vellum", wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Look.color(colour))
	l.add_theme_color_override("font_outline_color", Look.color("void"))
	l.add_theme_constant_override("outline_size", 4)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	return l


static func title(text: String) -> Label:
	return label(text, 26, "gilt_light")


static func header(text: String) -> Label:
	return label(text, 18, "gilt")


static func style(bg: String = "ui_black", border: String = "gilt_dark", width: int = 2, alpha: float = 0.95) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), alpha)
	s.border_color = Look.color(border)
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s


static func panel(bg: String = "ui_black", border: String = "gilt_dark") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border))
	return p


## A full-screen frame for a screen: dimmed backdrop and a centered panel. Returns the panel's content box.
static func screen_frame(root: CanvasLayer, title_text: String, size: Vector2 = Vector2(1400, 800)) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var p := panel("ui_black", "bone")
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -size.x / 2.0
	p.offset_right = size.x / 2.0
	p.offset_top = -size.y / 2.0
	p.offset_bottom = size.y / 2.0
	root.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	var head := HBoxContainer.new()
	var t := title(title_text)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(label("Esc: close", 13, "parchment"))
	box.add_child(head)
	return box


static func button(text: String, on_press: Callable, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", style("ui_oxblood", "gilt_dark", 2))
	b.add_theme_stylebox_override("hover", style("ui_wine", "gilt_light", 2))
	b.add_theme_stylebox_override("pressed", style("blood", "gilt_light", 2))
	b.add_theme_stylebox_override("focus", style("ui_wine", "gilt_light", 3))
	b.add_theme_stylebox_override("disabled", style("ui_black", "ui_oxblood", 2))
	b.add_theme_color_override("font_color", Look.color("vellum"))
	b.add_theme_color_override("font_disabled_color", Look.color("gilt_dark"))
	b.pressed.connect(on_press)
	return b


## A value whose tooltip is its Breakdown ("AC 17 = Chain Mail 16 + Defense 1").
static func stat(name_text: String, value: String, breakdown: Breakdown = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var n := label(name_text, 15, "parchment")
	n.custom_minimum_size = Vector2(170, 0)
	row.add_child(n)
	var v := label(value, 16, "vellum")
	if breakdown != null:
		v.tooltip_text = breakdown.describe()
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		v.text += "  ⓘ"
	row.add_child(v)
	return row


static func portrait(art_id: String, size: float = 96.0) -> TextureRect:
	var t := TextureRect.new()
	var path := "res://art/portraits/%s.png" % art_id
	t.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t


static func scroll(child: Control, min_size: Vector2) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func signed(v: int) -> String:
	return ("+%d" % v) if v >= 0 else str(v)
