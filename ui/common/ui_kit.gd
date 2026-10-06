class_name UiKit
extends RefCounted
## Shared building blocks for the party-facing screens (plan §5.6 "Gothic but readable"): crimson-black panels with
## aged gold trim and wrought-iron corners, labels with outlines, buttons with icons, section headers, breakdown
## tooltips, and the theme every stock control falls back to. Colours come from the palette (Look, including the
## UI-only crimson and gilt); UI draws on CanvasLayers after the palette pass so state colours are never quantized away.

## Gemini silhouettes made white with alpha (make ui_art), tinted with palette colours where they're drawn.
const CORNER := preload("res://art/ui/corner.png")
const DIVIDER := preload("res://art/ui/divider.png")

static var _display_font: Font
static var _themed := false


## The display face for titles, headers and buttons: a medieval book hand the system already has (Luminari on macOS),
## falling back to the default font. Nothing is downloaded or shipped with the game.
static func display_font() -> Font:
	if _display_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Luminari", "Trattatello", "Apple Chancery", "Palatino", "Georgia"])
		_display_font = f
	return _display_font


static func icon(id: String) -> Texture2D:
	var path := "res://art/ui/icons/%s.png" % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
	var l := label(text, 30, "gilt_light")
	l.add_theme_font_override("font", display_font())
	return l


static func header(text: String) -> Label:
	var l := label(text, 20, "gilt")
	l.add_theme_font_override("font", display_font())
	return l


static func style(bg: String = "ui_black", border: String = "gilt_dark", width: int = 2, alpha: float = 0.95) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), alpha)
	s.border_color = Look.color(border)
	s.set_border_width_all(width)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(10)
	return s


static func panel(bg: String = "ui_black", border: String = "gilt_dark") -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(bg, border)
	s.shadow_color = Color(Look.color("void"), 0.6)
	s.shadow_size = 10
	p.add_theme_stylebox_override("panel", s)
	return p


## Gothic trim on any control: a fine inner gilt rule and a wrought-iron flourish at each corner (one ornament,
## mirrored), drawn after the control's own box. `corner` is the ornament's width in pixels.
static func trim(c: Control, corner: float = 64.0, colour: String = "gilt") -> void:
	var tint := Look.color(colour)
	var rule := Color(Look.color("gilt_dark"), 0.8)
	var h := corner * float(CORNER.get_height()) / float(CORNER.get_width())
	c.draw.connect(func() -> void:
		var sz := c.size
		c.draw_rect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), rule, false, 1.0)
		for flip: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var at := Vector2(-3.0 if flip.x > 0.0 else sz.x + 3.0, -3.0 if flip.y > 0.0 else sz.y + 3.0)
			c.draw_set_transform(at, 0.0, flip)
			c.draw_texture_rect(CORNER, Rect2(Vector2.ZERO, Vector2(corner, h)), false, tint)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	c.queue_redraw()


## A gilt scrollwork rule, centred, for under titles and between sections.
static func divider(width: float = 360.0, colour: String = "gilt") -> TextureRect:
	var t := TextureRect.new()
	t.texture = DIVIDER
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(width, width * float(DIVIDER.get_height()) / float(DIVIDER.get_width()))
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.modulate = Look.color(colour)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A full-screen frame for a screen: dimmed backdrop and a centered panel. Returns the panel's content box.
static func screen_frame(root: CanvasLayer, title_text: String, size: Vector2 = Vector2(1400, 800)) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var p := panel("ui_black", "gilt_dark")
	(p.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(24)
	_centre(p, Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, size.y / 2.0))
	trim(p, 128.0)
	root.add_child(p)
	# The title sits on a crimson plaque astride the top border, with gilt scrollwork spreading out behind it.
	var t := title(title_text)
	t.add_theme_font_size_override("font_size", 28)
	var tw := display_font().get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var crest := divider(minf(tw + 340.0, size.x - 300.0))
	_centre(crest, Vector2(0, -size.y / 2.0), Vector2(0, -size.y / 2.0))
	crest.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crest.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(crest)
	var plaque := PanelContainer.new()
	var ps := style("ui_oxblood", "gilt", 2, 1.0)
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 2
	ps.content_margin_bottom = 4
	ps.shadow_color = Color(Look.color("void"), 0.7)
	ps.shadow_size = 6
	plaque.add_theme_stylebox_override("panel", ps)
	plaque.add_child(t)
	_centre(plaque, Vector2(0, -size.y / 2.0), Vector2(0, -size.y / 2.0))
	plaque.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plaque.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(plaque)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	var head := HBoxContainer.new()
	var esc := label("Esc: close", 13, "parchment")
	esc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(esc)
	var clear_of_corner := Control.new()
	clear_of_corner.custom_minimum_size = Vector2(70, 0)
	head.add_child(clear_of_corner)
	box.add_child(head)
	return box


static func _centre(c: Control, top_left: Vector2, bottom_right: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = top_left.x
	c.offset_top = top_left.y
	c.offset_right = bottom_right.x
	c.offset_bottom = bottom_right.y


static func button(text: String, on_press: Callable, size: int = 16, icon_id: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	button_look(b)
	if icon_id != "":
		b.icon = icon(icon_id)
		b.add_theme_constant_override("icon_max_width", size + 8)
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(on_press)
	return b


## Crimson-black faces with gilt edges; the icon takes the gilt tint (white silhouettes multiply to the colour).
static func button_look(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, button_style(state))
	b.add_theme_font_override("font", display_font())
	b.add_theme_color_override("font_color", Look.color("vellum"))
	b.add_theme_color_override("font_hover_color", Look.color("gilt_light"))
	b.add_theme_color_override("font_pressed_color", Look.color("gilt_light"))
	b.add_theme_color_override("font_focus_color", Look.color("vellum"))
	b.add_theme_color_override("font_disabled_color", Look.color("gilt_dark"))
	b.add_theme_color_override("icon_normal_color", Look.color("gilt"))
	b.add_theme_color_override("icon_hover_color", Look.color("gilt_light"))
	b.add_theme_color_override("icon_pressed_color", Look.color("gilt_light"))
	b.add_theme_color_override("icon_focus_color", Look.color("gilt"))
	b.add_theme_color_override("icon_disabled_color", Look.color("gilt_dark"))


static func button_style(state: String) -> StyleBoxFlat:
	var s: StyleBoxFlat
	match state:
		"hover":
			s = style("ui_wine", "gilt", 2)
		"pressed":
			s = style("blood", "gilt_light", 2)
		"focus":
			s = style("ui_wine", "gilt_light", 2)
			s.draw_center = false
		"disabled":
			s = style("ui_black", "ui_oxblood", 2)
		_:
			s = style("ui_oxblood", "gilt_dark", 2)
	s.border_width_bottom += 1
	s.set_content_margin_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s


## The look every stock control falls back to (tabs, scroll bars, tooltips, text fields, check boxes, pop-ups),
## merged into the engine's default theme once at start so nothing shows Godot's grey.
static func install_theme() -> void:
	if _themed:
		return
	_themed = true
	var t := Theme.new()
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			t.set_stylebox(state, type, button_style(state))
		t.set_color("font_color", type, Look.color("vellum"))
		t.set_color("font_hover_color", type, Look.color("gilt_light"))
		t.set_color("font_pressed_color", type, Look.color("gilt_light"))
		t.set_color("font_focus_color", type, Look.color("vellum"))
		t.set_color("font_disabled_color", type, Look.color("gilt_dark"))
		t.set_color("icon_normal_color", type, Look.color("gilt"))
		t.set_color("icon_hover_color", type, Look.color("gilt_light"))
	for type: String in ["CheckBox", "CheckButton"]:
		for state: String in ["normal", "pressed", "disabled"]:
			var flat := StyleBoxEmpty.new()
			flat.set_content_margin_all(4)
			t.set_stylebox(state, type, flat)
	t.set_color("font_color", "Label", Look.color("vellum"))
	t.set_color("font_outline_color", "Label", Look.color("void"))
	t.set_constant("outline_size", "Label", 3)
	t.set_color("default_color", "RichTextLabel", Look.color("vellum"))
	t.set_stylebox("panel", "PanelContainer", style("ui_black", "gilt_dark"))
	t.set_stylebox("panel", "Panel", style("ui_black", "gilt_dark"))
	var tip := style("ui_black", "gilt", 1, 0.97)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Look.color("vellum"))
	for type: String in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, style("ui_oxblood", "gilt_dark", 2, 1.0))
		t.set_stylebox("focus", type, style("ui_oxblood", "gilt", 2, 1.0))
		t.set_stylebox("read_only", type, style("ui_black", "ui_oxblood", 2, 1.0))
		t.set_color("font_color", type, Look.color("vellum"))
		t.set_color("caret_color", type, Look.color("gilt_light"))
		t.set_color("selection_color", type, Look.color("ui_wine"))
		t.set_color("font_placeholder_color", type, Look.color("bone"))
	var tab_on := style("ui_wine", "gilt", 0, 1.0)
	tab_on.border_width_top = 3
	tab_on.set_content_margin_all(8)
	var tab_off := style("ui_black", "ui_oxblood", 0, 1.0)
	tab_off.set_content_margin_all(8)
	var tab_hover := style("ui_oxblood", "gilt_dark", 0, 1.0)
	tab_hover.border_width_top = 2
	tab_hover.set_content_margin_all(8)
	for type: String in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", type, tab_on)
		t.set_stylebox("tab_unselected", type, tab_off)
		t.set_stylebox("tab_hovered", type, tab_hover)
		t.set_stylebox("tab_disabled", type, tab_off)
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_color("font_selected_color", type, Look.color("gilt_light"))
		t.set_color("font_unselected_color", type, Look.color("parchment"))
		t.set_color("font_hovered_color", type, Look.color("vellum"))
		t.set_font("font", type, display_font())
	t.set_stylebox("panel", "TabContainer", style("ui_black", "gilt_dark", 2, 0.9))
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := style("ui_black", "ui_oxblood", 1, 0.9)
		track.set_content_margin_all(3)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		for g: Array in [["grabber", "gilt_dark"], ["grabber_highlight", "gilt"], ["grabber_pressed", "gilt_light"]]:
			var grab := StyleBoxFlat.new()
			grab.bg_color = Look.color(str(g[1]))
			grab.set_corner_radius_all(3)
			t.set_stylebox(str(g[0]), type, grab)
	t.set_stylebox("panel", "PopupMenu", style("ui_black", "gilt_dark", 2, 0.97))
	t.set_stylebox("hover", "PopupMenu", style("ui_oxblood", "gilt_dark", 0, 1.0))
	t.set_color("font_color", "PopupMenu", Look.color("vellum"))
	t.set_color("font_hover_color", "PopupMenu", Look.color("gilt_light"))
	t.set_color("font_separator_color", "PopupMenu", Look.color("gilt"))
	t.set_color("font_disabled_color", "PopupMenu", Look.color("bone"))
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Look.color("void")
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Look.color("crimson")
	t.set_stylebox("background", "ProgressBar", bar_back)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_stylebox("panel", "ItemList", style("ui_black", "gilt_dark", 2, 0.95))
	t.set_stylebox("selected", "ItemList", style("ui_wine", "gilt", 1, 1.0))
	t.set_stylebox("selected_focus", "ItemList", style("ui_wine", "gilt", 1, 1.0))
	t.set_color("font_color", "ItemList", Look.color("vellum"))
	t.set_color("font_selected_color", "ItemList", Look.color("gilt_light"))
	var groove := style("ui_black", "gilt_dark", 1, 1.0)
	groove.set_content_margin_all(3)
	var filled := StyleBoxFlat.new()
	filled.bg_color = Look.color("blood")
	filled.set_content_margin_all(3)
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var rule := StyleBoxLine.new()
	rule.color = Look.color("gilt_dark")
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	ThemeDB.get_default_theme().merge_with(t)


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
