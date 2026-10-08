class_name LayoutCheck
extends RefCounted
## Layout checks (P5): what on a screen spills out of its box. Used by tests/integration/test_layout.gd, which opens
## every screen at several window sizes. A problem is a sentence naming the control by its path under the screen.
## Test-only.
##
## What counts as spilling, for text and anything that takes a click:
## - anything shown that reaches past the edge of the window (the Death Saving Throw button under the bar,
##   owner report 2026-10-07);
## - anything wider than a list that only scrolls up and down, or taller than one that only scrolls sideways (dialogue
##   options cut off at the right, owner report);
## - a button or label whose text is cut short without an ellipsis (a cut that says so is a choice, not a spill).

## Window sizes to check, by name. The game draws at 1600x900 and stretches (project.godot: canvas_items, expand), so
## every 16:9 window lays out alike; other shapes give the UI more height or width, never less.
const SIZES := {"1080p": Vector2i(1920, 1080), "1440p": Vector2i(2560, 1440), "a small window": Vector2i(1280, 720),
	"16:10": Vector2i(1440, 900), "4:3": Vector2i(1024, 768)}

const SLACK := 1.0   ## pixels of rounding allowed


## Every problem under `node` (its visible controls) in a window showing `screen`.
static func problems(node: Node, screen: Rect2) -> Array[String]:
	var out: Array[String] = []
	for n in node.find_children("*", "Control", true, false):
		var c := n as Control
		# A screen's frame (UiKit.screen_frame) that its content pushed past its design size: it grows right and down,
		# so its border and corners end up under the content or off the screen (UI QA, 2026-10-08: Level Up).
		if c.has_meta(&"design_size") and c.is_visible_in_tree():
			var want := c.get_meta(&"design_size") as Vector2
			if c.size.x > want.x + SLACK or c.size.y > want.y + SLACK:
				out.append("%s grew past its design size (%dx%d, not %dx%d)" % [_name(c, node), c.size.x, c.size.y, want.x, want.y])
		if not _matters(c) or not c.is_visible_in_tree() or c.size.x < 1.0 or c.size.y < 1.0 or _hidden_by_scroll(c):
			continue
		var r := c.get_global_rect()
		var name := _name(c, node)
		var scroll := _scroller(c)
		if scroll == null:
			if not _inside(r, screen):
				out.append("%s reaches past the window's edge (%s in %s)" % [name, _rect(r), _rect(screen)])
		else:
			var box := scroll.get_global_rect()
			# Along an axis the list doesn't scroll, what's in it must fit the list, and the window too (a list as wide
			# as its widest option can itself run past the edge).
			if scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				if r.position.x < box.position.x - SLACK or r.end.x > box.end.x + SLACK:
					out.append("%s is wider than its list %s (%s in %s)" % [name, _name(scroll, node), _rect(r), _rect(box)])
				elif r.position.x < screen.position.x - SLACK or r.end.x > screen.end.x + SLACK:
					out.append("%s reaches past the window's edge in its list (%s in %s)" % [name, _rect(r), _rect(screen)])
			if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				if r.position.y < box.position.y - SLACK or r.end.y > box.end.y + SLACK:
					out.append("%s is taller than its list %s (%s in %s)" % [name, _name(scroll, node), _rect(r), _rect(box)])
				elif r.position.y < screen.position.y - SLACK or r.end.y > screen.end.y + SLACK:
					out.append("%s reaches past the window's edge in its list (%s in %s)" % [name, _rect(r), _rect(screen)])
		var cut := _cut_text(c)
		if cut != "":
			out.append("%s cuts its text short: \"%s\"" % [name, cut])
	return out


## Text and anything that takes a click: what a player misses when it spills. Ornaments and backdrops (the title's
## mist, a screen's crest) may hang past an edge on purpose.
static func _matters(c: Control) -> bool:
	return c is Label or c is RichTextLabel or c is BaseButton or c is LineEdit or c is TextEdit or c is Range 		or c is ItemList or c is Tree or c is TabBar


## The nearest scrolling list `c` sits in, or null.
static func _scroller(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p as ScrollContainer
		if p is CanvasLayer or p is Window:
			return null
		p = p.get_parent()
	return null


## A control scrolled out of its list's view isn't on screen to spill.
static func _hidden_by_scroll(c: Control) -> bool:
	var s := _scroller(c)
	return s != null and not s.get_global_rect().intersects(c.get_global_rect())


## The text a label or button shows cut short with no ellipsis to say so, or "".
static func _cut_text(c: Control) -> String:
	var text := ""
	var font: Font = null
	var font_size := 16
	var room := c.size.x
	var trimmed := false
	if c is Label:
		var l := c as Label
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF or not l.clip_text:
			return ""
		text = l.text
		trimmed = l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		font = l.get_theme_font("font")
		font_size = l.get_theme_font_size("font_size")
		var sb := l.get_theme_stylebox("normal")
		room -= sb.get_minimum_size().x if sb != null else 0.0
	elif c is Button:
		var b := c as Button
		if not b.clip_text or b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return ""
		text = b.text
		trimmed = b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		font = b.get_theme_font("font")
		font_size = b.get_theme_font_size("font_size")
		var sb := b.get_theme_stylebox("normal")
		room -= sb.get_minimum_size().x if sb != null else 0.0
		if b.icon != null:
			room -= b.get_theme_constant("h_separation") + float(b.icon.get_width())
	else:
		return ""
	if text == "" or trimmed or font == null:
		return ""
	var line := text.get_slice("\n", 0)
	return line if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room + SLACK else ""


static func _inside(r: Rect2, box: Rect2) -> bool:
	return r.position.x >= box.position.x - SLACK and r.position.y >= box.position.y - SLACK \
		and r.end.x <= box.end.x + SLACK and r.end.y <= box.end.y + SLACK


static func _name(c: Node, under: Node) -> String:
	var path := str(under.get_path_to(c))
	var text := ""
	if c is Button:
		text = (c as Button).text
	elif c is Label:
		text = (c as Label).text
	text = text.get_slice("\n", 0)
	if text.length() > 40:
		text = text.substr(0, 40) + "..."
	return "%s %s%s" % [c.get_class(), path.get_file() if path.length() > 60 else path, " \"%s\"" % text if text != "" else ""]


static func _rect(r: Rect2) -> String:
	return "%d,%d %dx%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
