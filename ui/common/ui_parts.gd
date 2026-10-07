class_name UiParts
extends RefCounted
## The drawn pieces every screen and HUD shares, first made for the character sheet (docs/ui/party_management.md
## pm_02): ability medallions, the Armor Class shield and stat plaques, Hit Points and load bars, pips for slots and
## resources, tags, section rules, row cards, framed portraits, party chips, tab strips, compact and primary buttons,
## and tooltips that gild the rules words in long rules text and lay a Breakdown out line by line. A rich tooltip opens
## as a card on the TipCards layer, which the pointer can cross onto and pin (U1). UiKit holds the theme, screen frames,
## labels and buttons these build on. Colours come from Look (the palette plus the UI-only crimson and gilt).

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

## A control painted by `painter(self)`, with `tip()` building its tooltip (a card on the TipCards layer).
class Drawn extends Control:
	var painter: Callable
	var tip: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## Any content with a rich tooltip: the panel is invisible and passes the mouse on so scrolling still works.
class Tipped extends PanelContainer:
	var tip: Callable


## A button with a rich tooltip (an option's rules text, a class's summary).
class TipButton extends Button:
	var tip: Callable


## A themed button whose hover shows `tip()`; `lit` gives it the chosen look.
static func tip_button(text: String, on_press: Callable, tip: Callable, lit: bool = false, size: int = 15) -> TipButton:
	var b := TipButton.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	UiKit.button_look(b)
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(on_press)
	b.tip = tip
	if lit:
		light_up(b)
	return b


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


## `plain` is the tip in a few words (a bar's "16 / 39"), kept as the "plain_tip" meta for tests and tools; the card
## itself comes from `tip`.
static func _set_tip(c: Control, tip: Callable, plain: String) -> void:
	if tip.is_valid():
		if plain != "":
			c.set_meta(&"plain_tip", plain)
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
	# Bevelled corners, not squares (owner, 2026-10-06).
	s.set_corner_radius_all(7)
	s.corner_detail = 1
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


## A small rounded tag ("Bonus Action", "Concentration", "Short Rest"); a rules term's tag opens its glossary card.
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
	# A tag that names a rules term ("Bloodied", "Concentration", "Bonus Action") opens its glossary card.
	var term := Glossary.id_for(text)
	if term != "":
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.set_meta(&"tip_card", func() -> Control: return TipCard.term_content(term))
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
## below. `side` scales it (124 on the sheet, about 100 beside creation); `delta` (level up) shows a ▲/▼ badge.
## Hover: where the score comes from.
static func medallion(ability_name: String, modifier: int, score: int, tip: Callable, side: float = 124.0,
		delta: int = 0) -> Drawn:
	return drawn(Vector2(side, side), func(c: Control) -> void:
		var k := c.size.y / 124.0
		var w := c.size.x
		var centre := Vector2(w / 2.0, 62.0 * k)
		var gilt := Look.color("gilt")
		centred_text(c, caps_font(), ability_name.to_upper(), Vector2(w / 2.0, 9.0 * k), maxi(9, roundi(12 * k)), Look.color("parchment"), 3)
		c.draw_circle(centre, 41.0 * k, Look.color("void"))
		c.draw_circle(centre, 38.0 * k, Look.color("ui_oxblood"))
		c.draw_circle(centre + Vector2(0, -8 * k), 26.0 * k, Color(Look.color("ui_wine"), 0.55))
		c.draw_arc(centre, 39.0 * k, 0.0, TAU, 48, gilt if delta == 0 else Look.color("bile"), 2.5, true)
		c.draw_arc(centre, 33.0 * k, 0.0, TAU, 48, Color(Look.color("gilt_dark"), 0.9), 1.0, true)
		for a: float in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0]:
			diamond(c, centre + Vector2(cos(a), sin(a)) * 39.0 * k, 4.0 * k, Look.color("gilt_light"), true)
		centred_text(c, figure_font(), UiKit.signed(modifier), centre + Vector2(0, -2 * k), roundi(32 * k), Look.color("ivory"))
		var plaque := Rect2(Vector2(w / 2.0 - 20.0 * k, 92.0 * k), Vector2(40, 22) * k)
		c.draw_colored_polygon(_octagon(plaque, 5.0 * k), Look.color("ui_black"))
		_outline(c, _octagon(plaque, 5.0 * k), gilt, 1.5)
		centred_text(c, figure_font(), str(score), plaque.get_center() + Vector2(0, 1), roundi(16 * k), Look.color("gilt_light"), 3)
		if delta != 0:
			delta_badge(c, Vector2(w - 16 * k, 24 * k), delta),
		tip, "%s %d (%s)" % [ability_name, score, UiKit.signed(modifier)])


## A small "▲2" (bile) or "▼1" (rose) badge centred on `at`: what a level up changes, by shape as well as colour.
static func delta_badge(c: CanvasItem, at: Vector2, delta: int) -> void:
	var text := ("▲%d" if delta > 0 else "▼%d") % absi(delta)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0
	var r := Rect2(at - Vector2(w / 2.0, 9), Vector2(w, 18))
	var col := Look.color("bile" if delta > 0 else "rose")
	c.draw_rect(r, Look.color("void"))
	c.draw_rect(r, col, false, 1.0)
	centred_text(c, f, text, at, 12, col, 2)


## The Armor Class shield.
static func shield(value: int, tip: Callable, delta: int = 0) -> Drawn:
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
		centred_text(c, caps_font(), "CLASS", Vector2(w / 2.0, 105), 11, Look.color("parchment"), 3)
		if delta != 0:
			delta_badge(c, Vector2(w - 14, 10), delta),
		tip, "Armor Class %d" % value)


## A cut-cornered plaque for Initiative, Speed and Proficiency Bonus: the value large, the caption below.
static func plaque(value: String, caption: String, tip: Callable, small: String = "", delta: int = 0) -> Drawn:
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
			centred_text(c, caps_font(), words[i], Vector2(w / 2.0, 87.0 + i * 11.0), 11, Look.color("parchment"), 3)
		if delta != 0:
			delta_badge(c, Vector2(w - 14, 12), delta),
		tip, caption)


## A gilt-framed bar: Hit Points (crimson, with temporary Hit Points in moonlight) or a load (gilt). Thin bars
## (under 16 px, for HUD cards) drop the inner rule and the text. While rolling (roll_bar) a gain fills up to the new
## value and a loss drops at once, the lost part lingering pale and draining away.
static func bar(value: float, maximum: float, extra: float, text: String, fill: String, tip: Callable,
		width: float = 300.0, height: float = 26.0) -> Drawn:
	return drawn(Vector2(width, height), func(c: Control) -> void:
		# A long hexagon like the buttons: the ends come to points.
		var r := Rect2(Vector2.ZERO, c.size)
		var thin := c.size.y < 16.0
		var tip_w := c.size.y / 2.0
		var outer := _long_hex(r, tip_w)
		c.draw_colored_polygon(outer, Look.color("void"))
		var inner := r.grow(-2.0 if thin else -3.0)
		var span := maxf(maximum + extra, 1.0)
		var shown := value
		var lost := value
		var label := text
		if c.has_meta(&"roll_from"):
			var from := float(c.get_meta(&"roll_from"))
			var t := float(c.get_meta(&"roll_t", 1.0))
			if from > value:
				lost = lerpf(from, value, t)
			else:
				shown = lerpf(from, value, t)
				lost = shown
			if text != "" and c.has_meta(&"roll_text"):
				label = str((c.get_meta(&"roll_text") as Callable).call(lerpf(from, value, t)))
		var f := clampf(shown / span, 0.0, 1.0)
		if lost > shown:
			var gone := Rect2(inner.position + Vector2(inner.size.x * f, 0), Vector2(inner.size.x * clampf((lost - shown) / span, 0.0, 1.0 - f), inner.size.y))
			_fill(c, _clip_hex(gone, inner, tip_w - 2.0), Color(Look.color("rose"), 0.8))
		if f > 0.0:
			var fr := Rect2(inner.position, Vector2(inner.size.x * f, inner.size.y))
			_fill(c, _clip_hex(fr, inner, tip_w - 2.0), Look.color(fill))
			var shine := Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.4))
			_fill(c, _clip_hex(shine, inner, tip_w - 2.0), Color(Look.color("ivory"), 0.12))
		if extra > 0.0:
			var ex := Rect2(inner.position + Vector2(inner.size.x * f, 0), Vector2(inner.size.x * clampf(extra / span, 0.0, 1.0 - f), inner.size.y))
			_fill(c, _clip_hex(ex, inner, tip_w - 2.0), Look.color("moonlight"))
		closed_line(c, outer, Look.color("gilt" if not thin else "gilt_dark"), 1.5 if not thin else 1.0)
		if label != "" and not thin:
			centred_text(c, figure_font(), label, r.get_center() + Vector2(0, 1), clampi(int(c.size.y * 0.66), 12, 17), Look.color("ivory")),
		tip, text)


## Rolls a bar (from bar()) to `value` from the value last shown under `key`: the bar and its text (`fmt(v)`, if
## given) move instead of jumping (G9). Nothing moves without motion or when the value hasn't changed.
static func roll_bar(d: Drawn, key: String, value: float, fmt: Callable = Callable()) -> void:
	var from := UiMotion.last_shown(key, value)
	if not UiMotion.on() or is_equal_approx(from, value):
		return
	d.set_meta(&"roll_from", from)
	d.set_meta(&"roll_t", 0.0)
	if fmt.is_valid():
		d.set_meta(&"roll_text", fmt)
	var start := func() -> void:
		UiMotion.soon(d, func() -> void:
			var tw := UiMotion.tween_for(d)
			# A loss shows for a moment before it drains.
			tw.tween_interval(0.2 if from > value else 0.0)
			tw.tween_method(func(t: float) -> void:
				d.set_meta(&"roll_t", t)
				d.queue_redraw(), 0.0, 1.0, UiMotion.roll_seconds(from, value)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))
	if d.is_inside_tree():
		start.call()
	else:
		d.tree_entered.connect(start, CONNECT_ONE_SHOT)


## A rectangle with its two ends drawn to points `tip` wide.
static func _long_hex(r: Rect2, tip: float) -> PackedVector2Array:
	var t := minf(tip, r.size.x / 2.0)
	var m := r.get_center().y
	return PackedVector2Array([Vector2(r.position.x, m), Vector2(r.position.x + t, r.position.y), Vector2(r.end.x - t, r.position.y),
		Vector2(r.end.x, m), Vector2(r.end.x - t, r.end.y), Vector2(r.position.x + t, r.end.y)])


## Part of a bar (`part`, inside `whole`) cut to the whole bar's pointed ends.
static func _clip_hex(part: Rect2, whole: Rect2, tip: float) -> PackedVector2Array:
	var poly := Geometry2D.intersect_polygons(PackedVector2Array([part.position, Vector2(part.end.x, part.position.y), part.end,
		Vector2(part.position.x, part.end.y)]), _long_hex(whole, tip))
	return poly[0] if not poly.is_empty() else PackedVector2Array()


static func _fill(c: CanvasItem, poly: PackedVector2Array, colour: Color) -> void:
	if poly.size() >= 3:
		c.draw_colored_polygon(poly, colour)


## A creature's Hit Points as a bar: crimson, brighter when Bloodied, temporary Hit Points in moonlight, grey when
## down. Hover: the maximum's Breakdown.
static func hp_bar(cr: Creature, width: float = 300.0, height: float = 26.0, with_text: bool = true) -> Drawn:
	var fill := "pewter" if cr.hp <= 0 else ("vampire_red" if cr.is_bloodied() else "crimson")
	var text := "%d / %d" % [cr.hp, cr.max_hp()] if with_text else ""
	var most := cr.max_hp()
	var d := bar(cr.hp, most, cr.temp_hp, text, fill, func() -> Control:
		return breakdown_tip(cr.max_hp_breakdown(), "Hit Point maximum", str(cr.max_hp()),
			"%d of %d now%s.%s" % [cr.hp, cr.max_hp(), ", plus %d temporary" % cr.temp_hp if cr.temp_hp > 0 else "",
				" Bloodied." if cr.is_bloodied() and cr.hp > 0 else ""]), width, height)
	# Each place a creature's bar appears rolls from what that place last showed.
	roll_bar(d, "hp:%d:%dx%d" % [cr.get_instance_id(), int(width), int(height)], cr.hp, func(v: float) -> String:
		return "%d / %d" % [roundi(v), most])
	return d


# --- Icons ----------------------------------------------------------------------------------------

static var _icons: Script = null
static var _icons_looked := false


## Item and spell art from the Icons helper (ui/common/icons.gd, the icons branch) once the project has it, looked
## up by name so screens show icons as soon as that file lands: kind "item" or "spell". Null without art.
static func icon_texture(kind: String, id: String) -> Texture2D:
	if not has_icons() or not kind in ["item", "spell"]:
		return null
	return _icons.call(kind, id) as Texture2D


## The tile for a hotbar entry (its spell, the weapon it swings or throws, the item it uses), or null for plain
## actions like Dash or without icon art.
static func action_icon(action: Dictionary) -> Texture2D:
	if not has_icons():
		return null
	return _icons.call("for_action", action) as Texture2D


static func has_icons() -> bool:
	if not _icons_looked:
		_icons_looked = true
		for c: Dictionary in ProjectSettings.get_global_class_list():
			if str(c["class"]) == "Icons":
				_icons = load(str(c["path"])) as Script
	return _icons != null


## A square icon to start a row, or null while the project has no icon art. An item or spell without art gets a
## blank square, so rows stay aligned.
static func icon_slot(kind: String, id: String, side: float = 32.0) -> Control:
	if not has_icons():
		return null
	var t := TextureRect.new()
	t.texture = icon_texture(kind, id)
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Puts the icon on a button, untinted (the theme tints plain button icons gilt), when there is art for it.
static func icon_on_button(b: Button, kind: String, id: String, side: int = 26) -> void:
	texture_on_button(b, icon_texture(kind, id), side)


## The same for a texture already in hand (a hotbar entry's `action_icon`).
static func texture_on_button(b: Button, tex: Texture2D, side: int = 26) -> void:
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", side)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(Color.WHITE, 0.4))


## Adds an icon slot to the start of `row` when there is icon art.
static func add_icon(row: Container, kind: String, id: String, side: float = 32.0) -> void:
	var slot := icon_slot(kind, id, side)
	if slot != null:
		row.add_child(slot)


# --- Layout pieces every screen shares ------------------------------------------------------------

## Engraved small capitals ("HIT POINTS").
static func caption(text: String, size: int = 12, colour: String = "parchment") -> Label:
	return label(text.to_upper(), size, colour, caps_font())


## A number in the book serif ("+5", "14").
static func figure(text: String, size: int = 18, colour: String = "ivory") -> Label:
	return label(text, size, colour, figure_font())


## An empty control that takes the spare width in a row.
static func gap() -> Control:
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## A row card: content on a faint crimson ground with a fine gilt edge; `lit` marks the chosen one. With `tip`,
## hovering anywhere on the row shows it.
static func row(content: Control, tip: Callable = Callable(), lit: bool = false, margin: int = 7) -> Control:
	var c := card("ui_wine" if lit else "ui_oxblood", "gilt_light" if lit else "gilt_dark", 0.75 if lit else 0.55, margin)
	if lit:
		(c.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	c.add_child(content)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not tip.is_valid():
		return c
	return tipped(c, tip)


## How a feature is used, as a coloured tag (passive features get none).
const ACTION_TAGS := {"action": ["Action", "rose"], "bonus_action": ["Bonus Action", "flame"],
	"reaction": ["Reaction", "lilac"], "free": ["Free", "bile"], "special": ["Special", "moonlight"]}


## A feature as a row: its name, how it's used, where it comes from (`source_text`), its one-line summary, and the
## full rules text on hover. Takes the feature dictionaries Character and LevelUpController hand out.
static func feature_row(f: Dictionary, source_text: String, width: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiKit.label(str(f.get("name", "")), 16, "gilt_light"))
	var tag := ACTION_TAGS.get(str(f.get("action", "passive")), []) as Array
	if not tag.is_empty():
		head.add_child(pill(str(tag[0]), str(tag[1])))
	var text_only := str(f.get("implemented", "")) == "text"
	if text_only:
		head.add_child(pill("Rules text only", "bone"))
	head.add_child(gap())
	head.add_child(UiKit.label(source_text, 12, "bone"))
	col.add_child(head)
	var summary := str(f.get("summary", ""))
	var text := str(f.get("text", "")) if str(f.get("text", "")) != "" else summary
	if summary == "":
		summary = text if text.length() <= 160 else text.left(157) + "..."
	if summary != "":
		col.add_child(TermText.make(summary, 14, "vellum", width - 20.0))
	return row(col, func() -> Control:
		return rules_tip(str(f.get("name", "")), str(f.get("source", "")), text, [],
			"Rules text only for now: the game doesn't apply this one for you yet." if text_only else ""))


## A row you can click (a backpack item, a slot): the row card with an invisible button over it that lights on hover;
## `lit` marks the chosen one, `tip` shows on hover.
static func click_row(content: Control, on_press: Callable, lit: bool = false, tip: Callable = Callable(), margin: int = 7) -> Control:
	var c := card("ui_wine" if lit else "ui_oxblood", "gilt_light" if lit else "gilt_dark", 0.75 if lit else 0.55, margin)
	if lit:
		(c.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(content)
	var b := TipButton.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(Look.color("gilt_light"), 0.07)
	glow.border_color = Color(Look.color("gilt"), 0.8)
	glow.set_border_width_all(1)
	for state: String in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", glow)
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(on_press)
	b.tip = tip
	c.add_child(b)
	return c


## The look of a chosen toggle (a party chip, a tab, a filter, a picked option): wine ground, bright gilt edge.
static func light_up(b: Button) -> void:
	var on := UiKit.button_style("hover")
	on.border_color = Look.color("gilt_light")
	on.set_border_width_all(2)
	on.border_width_bottom = 3
	var was := b.get_theme_stylebox("normal") as StyleBoxFlat
	if was != null:
		on.content_margin_left = was.content_margin_left
		on.content_margin_right = was.content_margin_right
		on.content_margin_top = was.content_margin_top
		on.content_margin_bottom = was.content_margin_bottom
	b.add_theme_stylebox_override("normal", on)
	b.add_theme_color_override("font_color", Look.color("gilt_light"))
	# Lozenges just inside its points, where there's room beside the text.
	if on.content_margin_left >= 16.0:
		mark_ends(b, false)


## A smaller button for inside rows and HUD cards, so a row with one is no taller than one without.
static func small_button(text: String, on_press: Callable, icon_id: String = "") -> Button:
	var b := UiKit.button(text, on_press, 13, icon_id)
	compact(b)
	return b


static func compact(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := UiKit.button_style(state)
		s.content_margin_top = 3
		s.content_margin_bottom = 3
		s.content_margin_left = 13
		s.content_margin_right = 13
		b.add_theme_stylebox_override(state, s)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_constant_override("icon_max_width", 16)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The one button that finishes a screen (Confirm, Begin the adventure): larger, on a blood-red ground.
static func primary_button(text: String, on_press: Callable, icon_id: String = "") -> Button:
	var b := UiKit.button(text, on_press, 20, icon_id)
	for state: String in ["normal", "hover", "pressed"]:
		var s := UiKit.button_style(state)
		s.bg_color = Look.color("blood" if state == "normal" else ("crimson" if state == "hover" else "blood_deep"))
		s.border_color = Look.color("gilt_light")
		s.set_border_width_all(2)
		s.border_width_bottom = 3
		s.content_margin_left = 26
		s.content_margin_right = 26
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Look.color("ivory"))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark_ends(b, false)
	return b


## A portrait in a double gilt frame with lozenges at the corners; greyed when down, faded when dead.
static func framed_portrait(art_id: String, side: float, down: bool = false, dead: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := 4.0 if side < 100.0 else 6.0
	var back := ColorRect.new()
	back.color = Look.color("ui_black")
	back.position = Vector2(inset, inset)
	back.size = Vector2(side - inset * 2.0, side - inset * 2.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	var pic := UiKit.portrait(art_id, side - inset * 2.0)
	pic.position = back.position
	pic.size = back.size
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dead:
		pic.modulate = Color(Look.color("pewter"), 0.45)
	elif down:
		pic.modulate = Look.color("pewter")
	holder.add_child(pic)
	var big := side >= 100.0
	holder.add_child(drawn(Vector2(side, side), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_rect(r.grow(-1), Look.color("gilt"), false, 2.0 if big else 1.5)
		if big:
			c.draw_rect(r.grow(-5), Color(Look.color("gilt_dark"), 0.9), false, 1.0)
		var k := 7.0 if big else 4.5
		for p: Vector2 in [Vector2(1, 1), Vector2(c.size.x - 1, 1), Vector2(1, c.size.y - 1), c.size - Vector2(1, 1)]:
			diamond(c, p, k, Look.color("void"), true)
			diamond(c, p, k - 2.0, Look.color("gilt_light"), true)))
	return holder


## A party member's chip: their portrait and first name, the chosen one lit, greyed when they're down.
static func chip(ch: Character, lit: bool, on_press: Callable, width: float = 132.0) -> Button:
	var b := UiKit.button(ch.name.get_slice(" ", 0), on_press, 16)
	var path := "res://art/portraits/%s.png" % CombatToken.art_for(ch)
	if ResourceLoader.exists(path):
		b.icon = load(path) as Texture2D
	b.expand_icon = true
	b.custom_minimum_size = Vector2(width, 46)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tint := Look.color("pewter") if ch.hp <= 0 else Color.WHITE
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, tint)
	if lit:
		light_up(b)
	b.tooltip_text = "%s · %s · %d / %d HP" % [ch.name, ch.class_summary(), ch.hp, ch.max_hp()]
	return b


## Portrait chips for the whole party; `on_pick(i)` when one is pressed.
static func party_chips(party: Array[Character], index: int, on_pick: Callable) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	for i in party.size():
		strip.add_child(chip(party[i], i == index, func() -> void: on_pick.call(i)))
	return strip


## Tab buttons over a pane: the current one lit and joined to the pane; `on_pick(name)` when one is pressed.
static func tab_strip(names: Array[String], current: String, on_pick: Callable, icons: Dictionary = {},
		size: int = 15) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 3)
	for t in names:
		var b := UiKit.button(t, func() -> void: on_pick.call(t), size, str(icons.get(t, "")))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s := UiKit.button_style("hover" if t == current else "normal")
		s.content_margin_left = 8
		s.content_margin_right = 8
		if t == current:
			s.border_color = Look.color("gilt_light")
			s.border_width_bottom = 0
			b.add_theme_color_override("font_color", Look.color("gilt_light"))
		else:
			s.bg_color = Color(Look.color("ui_black"), 0.95)
		b.add_theme_stylebox_override("normal", s)
		strip.add_child(b)
	return strip


## The pane under a tab strip, or around any block of content: a faint crimson ground with a gilt edge.
static func pane(margin: int = 12) -> PanelContainer:
	var p := card("ui_oxblood", "gilt", 0.35, margin)
	(p.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	return p


## A scroll area that fills its parent, without a horizontal bar.
static func fill_scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


# --- Gothic shapes (owner's pick, the Crimson settings concept: arched frames, crests, hexagonal buttons) -----

static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


## An arched panel's outline: straight sides, a pointed (lancet) arch whose apex is `r`'s top edge and whose shoulders
## are `rise` lower, and a flat bottom. Convex, so it fills with draw_polygon.
static func arch_points(r: Rect2, rise: float, steps: int = 18) -> PackedVector2Array:
	var x0 := r.position.x
	var w := r.size.x
	var apex := Vector2(x0 + w / 2.0, r.position.y)
	var sh := r.position.y + rise
	var pts := PackedVector2Array([Vector2(x0, r.end.y), Vector2(x0, sh)])
	pts.append_array(_bezier(Vector2(x0, sh), Vector2(x0, sh - rise * 0.5), Vector2(x0 + w * 0.286, r.position.y + rise * 0.167), apex, steps))
	pts.append_array(_bezier(apex, Vector2(x0 + w * 0.714, r.position.y + rise * 0.167), Vector2(x0 + w, sh - rise * 0.5), Vector2(x0 + w, sh), steps))
	pts.append(Vector2(x0 + w, r.end.y))
	return pts


## Fills a convex shape with a vertical gradient (wine at the top fading to black, like the concept).
static func gradient_fill(c: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - lo) / maxf(hi - lo, 1.0)))
	c.draw_polygon(pts, cols)


static func closed_line(c: CanvasItem, pts: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, colour, width, true)


## The crest at an arch's apex: a gilt ring around a lozenge.
static func crest(c: CanvasItem, centre: Vector2, r: float = 13.0) -> void:
	c.draw_circle(centre, r, Look.color("ui_black"))
	c.draw_arc(centre, r, 0.0, TAU, 32, Look.color("gilt"), 1.2, true)
	diamond(c, centre, r * 0.82, Look.color("gilt_light"), true)


## A curl of scrollwork at an arch's shoulder; `flip` mirrors it for the right side.
static func curl(c: CanvasItem, at: Vector2, k: float = 1.0, flip: bool = false) -> void:
	var m := Vector2(-1.0 if flip else 1.0, 1.0) * k
	var p0 := at
	var pts := PackedVector2Array([p0])
	pts.append_array(_bezier(p0, p0 + Vector2(0, -20) * m, p0 + Vector2(18, -28) * m, p0 + Vector2(30, -18) * m, 12))
	var p3 := p0 + Vector2(30, -18) * m
	pts.append_array(_bezier(p3, p0 + Vector2(38, -11) * m, p0 + Vector2(30, 0) * m, p0 + Vector2(22, -6) * m, 10))
	c.draw_polyline(pts, Look.color("gilt"), 1.5, true)


## A title's rule: a fine gilt line either side of a lozenge.
static func title_rule(c: CanvasItem, centre: Vector2, half: float) -> void:
	var gilt := Look.color("gilt")
	c.draw_line(centre + Vector2(-half, 0), centre + Vector2(-12, 0), gilt, 1.0, true)
	c.draw_line(centre + Vector2(12, 0), centre + Vector2(half, 0), gilt, 1.0, true)
	diamond(c, centre, 5.0, gilt, true)


## The footer flourish: a gilt wave with a lozenge at its middle.
static func footer_wave(c: CanvasItem, centre: Vector2, half: float) -> void:
	var k := half / 80.0
	var a := centre + Vector2(-80, 0) * k
	var pts := PackedVector2Array([a])
	pts.append_array(_bezier(a, centre + Vector2(-50, -10) * k, centre + Vector2(-25, 10) * k, centre, 14))
	pts.append_array(_bezier(centre, centre + Vector2(25, -10) * k, centre + Vector2(50, 10) * k, centre + Vector2(80, 0) * k, 14))
	c.draw_polyline(pts, Look.color("gilt"), 1.2, true)
	diamond(c, centre, 5.0, Look.color("gilt"), true)


## L-shaped brackets at a rectangle's bottom corners (and its top ones with `top`).
static func brackets(c: CanvasItem, r: Rect2, arm: float = 18.0, top: bool = false) -> void:
	var gilt := Look.color("gilt")
	var corners := [[r.position + Vector2(0, r.size.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]
	if top:
		corners.append([r.position, Vector2(1, 1)])
		corners.append([Vector2(r.end.x, r.position.y), Vector2(-1, 1)])
	for cn: Variant in corners:
		var at := (cn as Array)[0] as Vector2
		var d := (cn as Array)[1] as Vector2
		c.draw_line(at, at + Vector2(0, arm * d.y), gilt, 2.0, true)
		c.draw_line(at, at + Vector2(arm * d.x, 0), gilt, 2.0, true)


## Lozenges at a button's two points, the concept's mark for the chosen one: outside it where there's room (a menu
## column), else just inside its tips.
static func mark_ends(b: Control, outside: bool = true) -> void:
	b.draw.connect(func() -> void:
		var y := b.size.y / 2.0
		var dx := -11.0 if outside else 9.0
		diamond(b, Vector2(dx, y), 5.0 if outside else 3.5, Look.color("gilt_light"), true)
		diamond(b, Vector2(b.size.x - dx, y), 5.0 if outside else 3.5, Look.color("gilt_light"), true))
	b.queue_redraw()


# --- Tooltips -------------------------------------------------------------------------------------

static func _tip_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
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


## Rules text: a title, a subtitle ("Level 3 Evocation"), facts as label/value rows, then the text wrapped, with its
## rules words gilded (a condition's own name stays plain on its own tip).
static func rules_tip(title_text: String, subtitle: String, body: String, facts: Array = [], foot: String = "") -> Control:
	var box := _tip_box()
	_tip_head(box, title_text, subtitle)
	var own := Glossary.id_for(title_text)
	var skip := [own] if own != "" else []
	if not facts.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 0)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS
		for f: Variant in facts:
			var pair := f as Array
			grid.add_child(label(str(pair[0]), 13, "parchment"))
			grid.add_child(TermText.make(str(pair[1]), 13, "vellum", TIP_WIDTH - 120.0, skip))
		box.add_child(grid)
	if body != "":
		box.add_child(TermText.make(body, 14, "vellum", TIP_WIDTH, skip))
	if foot != "":
		box.add_child(TermText.make(foot, 13, "moonlight", TIP_WIDTH, skip))
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
		box.add_child(TermText.make(n, 13, "moonlight", TIP_WIDTH))
	if foot != "":
		box.add_child(TermText.make(foot, 13, "parchment", TIP_WIDTH))
	return box
