class_name SheetParts
extends RefCounted
## Drawn pieces for the character sheet (docs/ui/party_management.md pm_02): ability medallions, the Armor Class
## shield and the other stat plaques, the Hit Points bar, pips for slots and resources, small tags, section rules,
## and tooltips that wrap long rules text and lay a Breakdown out line by line. Colours come from Look (the palette
## plus the UI-only crimson and gilt), so the sheet matches every other menu.

const TIP_WIDTH := 400.0
const NO_VALUE := -1000000

static var _figure_font: Font
static var _caps_font: Font


## A book serif for the big numbers (Hoefler Text or Baskerville on macOS), with lining figures so "14" doesn't
## dip below the line.
static func figure_font() -> Font:
	if _figure_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Hoefler Text", "Baskerville", "Palatino", "Georgia"])
		f.font_weight = 700
		f.fallbacks = [ThemeDB.fallback_font]
		var v := FontVariation.new()
		v.base_font = f
		v.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
		_figure_font = v
	return _figure_font


## Numbers for the figure font: a true minus sign instead of a hyphen ("−1").
static func figures(text: String) -> String:
	return text.replace("-", "−")


## Engraved capitals for captions ("ARMOR CLASS"): Copperplate on macOS.
static func caps_font() -> Font:
	if _caps_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Copperplate", "Palatino", "Georgia"])
		f.font_weight = 600
		f.fallbacks = [ThemeDB.fallback_font]
		_caps_font = f
	return _caps_font


# --- Controls with their own drawing and rich tooltips -------------------------------------------

## A control painted by `painter(self)`, with `tip()` building its tooltip.
class Drawn extends Control:
	var painter: Callable
	var tip: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

	func _make_custom_tooltip(_for_text: String) -> Object:
		return tip.call() as Control if tip.is_valid() else null


## Any content with a rich tooltip: the panel is invisible and passes the mouse on so scrolling still works.
class Tipped extends PanelContainer:
	var tip: Callable

	func _make_custom_tooltip(_for_text: String) -> Object:
		return tip.call() as Control if tip.is_valid() else null


static func drawn(size: Vector2, painter: Callable, tip: Callable = Callable(), plain: String = "") -> Drawn:
	var d := Drawn.new()
	d.custom_minimum_size = size
	d.painter = painter
	_set_tip(d, tip, plain)
	return d


## Wraps `content` so hovering anywhere on it shows `tip()`.
static func tipped(content: Control, tip: Callable, plain: String = "") -> Tipped:
	var t := Tipped.new()
	t.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	t.add_child(content)
	_set_tip(t, tip, plain)
	return t


static func _set_tip(c: Control, tip: Callable, plain: String) -> void:
	if tip.is_valid():
		# The engine only asks for a custom tooltip when the plain one isn't empty.
		c.tooltip_text = plain if plain != "" else "·"
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c is Drawn:
		(c as Drawn).tip = tip
	elif c is Tipped:
		(c as Tipped).tip = tip


# --- Text -----------------------------------------------------------------------------------------

static func label(text: String, size: int = 15, colour: String = "vellum", font: Font = null) -> Label:
	var l := UiKit.label(figures(text) if font == figure_font() else text, size, colour)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## A label hard-wrapped to `width` pixels, so it sizes itself exactly (tooltips size to their content).
static func wrapped(text: String, size: int, colour: String, width: float) -> Label:
	return label(wrap_text(text, size, width), size, colour)


static func wrap_text(text: String, size: int, width: float, font: Font = null) -> String:
	var f := font if font != null else ThemeDB.fallback_font
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if line != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)


## Draws `text` centred on `centre` (vertically by its cap height), with a dark outline.
static func centred_text(c: CanvasItem, font: Font, text: String, centre: Vector2, size: int, colour: Color,
		outline: int = 4) -> void:
	var t := figures(text) if font == figure_font() else text
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(centre.x - w / 2.0, centre.y + (font.get_ascent(size) - font.get_descent(size)) / 2.0 - 1.0)
	if outline > 0:
		c.draw_string_outline(font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Look.color("void"))
	c.draw_string(font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


# --- Panels and rules -----------------------------------------------------------------------------

## A dark card with a fine gilt edge, for grouping rows.
static func card(bg: String = "ui_oxblood", border: String = "gilt_dark", alpha: float = 0.6, margin: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), alpha)
	s.border_color = Color(Look.color(border), 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", s)
	return p


## A section title in the book hand with a gilt rule running out to the right from a small lozenge.
static func section(title_text: String, right: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var t := UiKit.header(title_text)
	t.add_theme_font_size_override("font_size", 19)
	row.add_child(t)
	var rule := drawn(Vector2(20, 22), func(c: Control) -> void:
		var y := c.size.y / 2.0 + 2.0
		var gilt := Look.color("gilt")
		diamond(c, Vector2(5, y), 4.0, gilt, true)
		c.draw_line(Vector2(12, y), Vector2(c.size.x, y), Color(Look.color("gilt_dark"), 0.9), 1.0))
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rule)
	if right != null:
		row.add_child(right)
	return row


## A small rounded tag ("Bonus Action", "Concentration", "Short Rest").
static func pill(text: String, colour: String = "gilt", size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(colour), 0.16)
	s.border_color = Color(Look.color(colour), 0.75)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var l := UiKit.label(text, size, colour)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


# --- Shapes ---------------------------------------------------------------------------------------

static func diamond(c: CanvasItem, at: Vector2, r: float, colour: Color, filled: bool) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
	if filled:
		c.draw_colored_polygon(pts, colour)
	else:
		pts.append(pts[0])
		c.draw_polyline(pts, colour, 1.5, true)


static func _octagon(r: Rect2, cut: float) -> PackedVector2Array:
	var p := r.position
	var e := r.end
	return PackedVector2Array([Vector2(p.x + cut, p.y), Vector2(e.x - cut, p.y), Vector2(e.x, p.y + cut),
		Vector2(e.x, e.y - cut), Vector2(e.x - cut, e.y), Vector2(p.x + cut, e.y), Vector2(p.x, e.y - cut), Vector2(p.x, p.y + cut)])


static func _outline(c: CanvasItem, pts: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, colour, width, true)


## Proficiency mark: a hollow ring (none), a gilt lozenge (proficient), a lozenge in a ring (Expertise).
static func mark(rank: int) -> Drawn:
	return drawn(Vector2(14, 14), func(c: Control) -> void:
		var at := c.size / 2.0
		if rank <= 0:
			c.draw_arc(at, 3.5, 0.0, TAU, 16, Look.color("bone_dark"), 1.2, true)
		else:
			diamond(c, at, 4.5, Look.color("gilt_light" if rank >= 2 else "gilt"), true)
			if rank >= 2:
				c.draw_arc(at, 6.5, 0.0, TAU, 20, Look.color("gilt_light"), 1.0, true))


## A row of lozenges: `left` filled in `colour`, the rest hollow. Past 10 it reads "left / total" instead.
static func pips(total: int, left: int, colour: String = "gilt_light") -> Control:
	if total > 10:
		var l := label("%d / %d" % [left, total], 15, colour if left > 0 else "bone", figure_font())
		return l
	var step := 15.0
	return drawn(Vector2(step * total + 2.0, 18), func(c: Control) -> void:
		for i in total:
			var at := Vector2(8.0 + i * step, c.size.y / 2.0)
			if i < left:
				diamond(c, at, 6.0, Look.color(colour), true)
				diamond(c, at, 6.0, Look.color("void"), false)
			else:
				diamond(c, at, 5.0, Look.color("gilt_dark"), false))


## An ability medallion: the name engraved above, the modifier large on a gilt-ringed disc, the score on a plaque
## below. Hover: where the score comes from.
static func medallion(ability_name: String, modifier: int, score: int, tip: Callable) -> Drawn:
	return drawn(Vector2(124, 124), func(c: Control) -> void:
		var w := c.size.x
		var centre := Vector2(w / 2.0, 62.0)
		var gilt := Look.color("gilt")
		centred_text(c, caps_font(), ability_name.to_upper(), Vector2(w / 2.0, 9.0), 12, Look.color("parchment"), 3)
		c.draw_circle(centre, 41.0, Look.color("void"))
		c.draw_circle(centre, 38.0, Look.color("ui_oxblood"))
		c.draw_circle(centre + Vector2(0, -8), 26.0, Color(Look.color("ui_wine"), 0.55))
		c.draw_arc(centre, 39.0, 0.0, TAU, 48, gilt, 2.5, true)
		c.draw_arc(centre, 33.0, 0.0, TAU, 48, Color(Look.color("gilt_dark"), 0.9), 1.0, true)
		for a: float in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
			diamond(c, centre + Vector2(cos(a), sin(a)) * 39.0, 4.0, Look.color("gilt_light"), true)
		centred_text(c, figure_font(), UiKit.signed(modifier), centre + Vector2(0, -2), 32, Look.color("ivory"))
		var plaque := Rect2(Vector2(w / 2.0 - 20.0, 92.0), Vector2(40, 22))
		c.draw_colored_polygon(_octagon(plaque, 5.0), Look.color("ui_black"))
		_outline(c, _octagon(plaque, 5.0), gilt, 1.5)
		centred_text(c, figure_font(), str(score), plaque.get_center() + Vector2(0, 1), 16, Look.color("gilt_light"), 3),
		tip, "%s %d (%s)" % [ability_name, score, UiKit.signed(modifier)])


## The Armor Class shield.
static func shield(value: int, tip: Callable) -> Drawn:
	return drawn(Vector2(84, 108), func(c: Control) -> void:
		var w := c.size.x
		var pts := PackedVector2Array([Vector2(6, 8), Vector2(w / 2.0, 2), Vector2(w - 6, 8), Vector2(w - 6, 44),
			Vector2(w - 10, 58), Vector2(w - 20, 70), Vector2(w / 2.0, 84), Vector2(20, 70), Vector2(10, 58), Vector2(6, 44)])
		c.draw_colored_polygon(pts, Look.color("ui_oxblood"))
		var inner := PackedVector2Array()
		var mid := Vector2(w / 2.0, 42)
		for p in pts:
			inner.append(mid + (p - mid) * 0.84)
		c.draw_colored_polygon(inner, Color(Look.color("ui_wine"), 0.5))
		_outline(c, inner, Color(Look.color("gilt_dark"), 0.9), 1.0)
		_outline(c, pts, Look.color("gilt"), 2.5)
		centred_text(c, figure_font(), str(value), Vector2(w / 2.0, 40), 34, Look.color("ivory"))
		centred_text(c, caps_font(), "ARMOR", Vector2(w / 2.0, 94), 11, Look.color("parchment"), 3)
		centred_text(c, caps_font(), "CLASS", Vector2(w / 2.0, 105), 11, Look.color("parchment"), 3),
		tip, "Armor Class %d" % value)


## A cut-cornered plaque for Initiative, Speed and Proficiency Bonus: the value large, the caption below.
static func plaque(value: String, caption: String, tip: Callable, small: String = "") -> Drawn:
	return drawn(Vector2(74, 108), func(c: Control) -> void:
		var w := c.size.x
		var r := Rect2(Vector2(4, 12), Vector2(w - 8, 62))
		var pts := _octagon(r, 10.0)
		c.draw_colored_polygon(pts, Look.color("ui_oxblood"))
		c.draw_colored_polygon(_octagon(r.grow(-5), 7.0), Color(Look.color("ui_wine"), 0.5))
		_outline(c, _octagon(r.grow(-5), 7.0), Color(Look.color("gilt_dark"), 0.9), 1.0)
		_outline(c, pts, Look.color("gilt"), 2.0)
		var fs := 30 if value.length() <= 3 else 24
		centred_text(c, figure_font(), value, r.get_center() + Vector2(0, -4 if small != "" else 0), fs, Look.color("ivory"))
		if small != "":
			centred_text(c, caps_font(), small, r.get_center() + Vector2(0, 19), 10, Look.color("parchment"), 3)
		var words := caption.to_upper().split(" ")
		for i in words.size():
			centred_text(c, caps_font(), words[i], Vector2(w / 2.0, 87.0 + i * 11.0), 11, Look.color("parchment"), 3),
		tip, caption)


## A gilt-framed bar: Hit Points (crimson, with temporary Hit Points in moonlight) or a load (gilt).
static func bar(value: float, maximum: float, extra: float, text: String, fill: String, tip: Callable,
		width: float = 300.0) -> Drawn:
	return drawn(Vector2(width, 26), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r, Look.color("void"))
		var inner := r.grow(-3)
		var span := maxf(maximum + extra, 1.0)
		var f := clampf(value / span, 0.0, 1.0)
		if f > 0.0:
			var fr := Rect2(inner.position, Vector2(inner.size.x * f, inner.size.y))
			c.draw_rect(fr, Look.color(fill))
			c.draw_rect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.4)), Color(Look.color("ivory"), 0.12))
		if extra > 0.0:
			var ex := Rect2(inner.position + Vector2(inner.size.x * f, 0), Vector2(inner.size.x * clampf(extra / span, 0.0, 1.0 - f), inner.size.y))
			c.draw_rect(ex, Look.color("moonlight"))
		c.draw_rect(r, Look.color("gilt"), false, 1.5)
		c.draw_rect(r.grow(-3), Color(Look.color("gilt_dark"), 0.8), false, 1.0)
		centred_text(c, figure_font(), text, r.get_center() + Vector2(0, 1), 17, Look.color("ivory")),
		tip, text)


# --- Tooltips -------------------------------------------------------------------------------------

static func _tip_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	return box


static func _tip_head(box: VBoxContainer, title_text: String, subtitle: String, value: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var t := UiKit.header(title_text)
	t.add_theme_font_size_override("font_size", 19)
	t.add_theme_color_override("font_color", Look.color("gilt_light"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if value != "":
		row.add_child(label(value, 20, "ivory", figure_font()))
	box.add_child(row)
	if subtitle != "":
		box.add_child(label(subtitle, 13, "parchment"))
	var rule := ColorRect.new()
	rule.color = Color(Look.color("gilt_dark"), 0.9)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)


## Rules text: a title, a subtitle ("Level 3 Evocation"), facts as label/value rows, then the text wrapped.
static func rules_tip(title_text: String, subtitle: String, body: String, facts: Array = [], foot: String = "") -> Control:
	var box := _tip_box()
	_tip_head(box, title_text, subtitle)
	if not facts.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 0)
		for f: Variant in facts:
			var pair := f as Array
			grid.add_child(label(str(pair[0]), 13, "parchment"))
			grid.add_child(wrapped(str(pair[1]), 13, "vellum", TIP_WIDTH - 120.0))
		box.add_child(grid)
	if body != "":
		box.add_child(wrapped(body, 14, "vellum", TIP_WIDTH))
	if foot != "":
		box.add_child(wrapped(foot, 13, "moonlight", TIP_WIDTH))
	return box


## A Breakdown line by line: "Armor Class 17" over "Chain Mail 16 / + Defense 1", then its floors and notes.
static func breakdown_tip(b: Breakdown, title_text: String = "", shown: String = "", foot: String = "") -> Control:
	var box := _tip_box()
	box.custom_minimum_size = Vector2(260, 0)
	_tip_head(box, title_text if title_text != "" else b.label, "", shown if shown != "" else str(b.total()))
	if b.override_value != NO_VALUE:
		box.add_child(wrapped("Set to %d by %s" % [b.override_value, b.override_label], 14, "gilt", TIP_WIDTH))
	else:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 0)
		for i in b.parts.size():
			var p := b.parts[i]
			var v := int(p["value"])
			grid.add_child(label(str(p["label"]), 14, "parchment"))
			var vl := label(str(v) if i == 0 else UiKit.signed(v), 14, "vellum" if v >= 0 or i == 0 else "rose", figure_font())
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(vl)
		box.add_child(grid)
		if b.floor_value > b.sum():
			box.add_child(wrapped("Raised to %d by %s" % [b.floor_value, b.floor_label], 13, "gilt", TIP_WIDTH))
	for n in b.notes:
		box.add_child(wrapped(n, 13, "moonlight", TIP_WIDTH))
	if foot != "":
		box.add_child(wrapped(foot, 13, "parchment", TIP_WIDTH))
	return box
