class_name TermText
extends RichTextLabel
## Rules text with its glossary terms gilded (U1): resting the pointer on one opens its card beside it (TipCards), and
## clicking it pins the card. Sizes itself to its text like a wrapped Label, and lets clicks and the scroll wheel pass
## on to whatever holds it.

## The term under the pointer, "" when none.
var hovered_term := ""


## `text` with its terms gilded, `width` pixels wide (0: as wide as its container makes it). Terms in `skip` stay
## plain (a term's own card).
static func make(text: String, size: int = 14, colour: String = "vellum", width: float = 0.0, skip: Array = []) -> TermText:
	var t := TermText.new()
	t.add_theme_font_size_override("normal_font_size", size)
	t.add_theme_color_override("default_color", Look.color(colour))
	t.text = Glossary.bbcode(text, skip)
	if width > 0.0:
		# Short text keeps its own width, as a hard-wrapped Label would; long text wraps at `width`.
		var natural := ThemeDB.fallback_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		t.custom_minimum_size = Vector2(minf(width, ceilf(natural) + 4.0), 0)
	return t


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_menu_enabled = false
	selection_enabled = false
	meta_underlined = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_color_override("font_outline_color", Look.color("void"))
	add_theme_constant_override("outline_size", 3)
	add_theme_constant_override("line_separation", 3)
	meta_hover_started.connect(func(meta: Variant) -> void:
		var m := str(meta)
		if m.begins_with("term:"):
			hovered_term = m.substr(5))
	meta_hover_ended.connect(func(meta: Variant) -> void:
		if str(meta) == "term:" + hovered_term:
			hovered_term = "")
	meta_clicked.connect(func(meta: Variant) -> void:
		var m := str(meta)
		if m.begins_with("term:") and TipCards.current != null:
			TipCards.current.pin_term(m.substr(5), self))
	mouse_exited.connect(func() -> void: hovered_term = "")
