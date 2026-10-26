class_name BugReportScreen
extends CanvasLayer
## Report a bug's screen (BugReports, dev builds only), over everything while the game waits: the picture taken as it
## opened beside where the game is, a kind of problem (one or none), what went wrong in his own words, and Send.
## Sent, it says where the report went, with a way to open that folder. Esc, B or Cancel closes it and writes nothing.
## With a pad, A on the words opens the pad's board (PadKeyboard), LB/RB step the kinds and Start sends; on a keyboard
## Cmd or Ctrl+Enter sends.

signal closed

const SIZE := Vector2(1080, 660)
const PICTURE := Vector2(400, 225)
const WIDE := 1000.0

var reports: BugReports
var shot: Image
var context: Dictionary = {}
var save: Dictionary = {}
## The kind picked (one of BugReports.KINDS), or "".
var kind := ""
## The folder the report went to, once sent.
var sent_to := ""
var words: TextEdit
var _box: VBoxContainer
var _note: Label
var _closing := false


func _init() -> void:
	name = "BugReportScreen"
	layer = 98   # over every screen, under the pad's board (99) and the rules cards and error notice (120)
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(reports_: BugReports, shot_: Image, context_: Dictionary, save_: Dictionary) -> void:
	reports = reports_
	shot = shot_
	context = context_
	save = save_
	_box = UiKit.screen_frame(self, "Report a bug", SIZE)
	_box.add_theme_constant_override("separation", 12)
	_compose()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var clear := Control.new()   # clear of the title's crest
	clear.custom_minimum_size = Vector2(0, 14)
	_box.add_child(clear)


## The report to write: the picture and where the game is, the kinds, the words, and Send or Cancel.
func _compose() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	top.add_child(_picture())
	var where := VBoxContainer.new()
	where.add_theme_constant_override("separation", 6)
	var w := WIDE - PICTURE.x - 22.0
	where.add_child(_line(str(context.get("place", "")), 20, "gilt_light", w))
	var when := str(context.get("clock", ""))
	where.add_child(_line("%s%s" % [when + "  ·  " if when != "" else "", context.get("mode", "")], 16, "vellum", w))
	where.add_child(_line("Open: %s" % context.get("screen", ""), 15, "parchment", w))
	var party := context.get("party", []) as Array
	var names: Array[String] = []
	for line: Variant in party:
		names.append(str(line).get_slice(":", 0).trim_suffix(" (leading)"))
	where.add_child(_line("Party: %s" % (", ".join(names) if not names.is_empty() else "none"), 15, "parchment", w))
	where.add_child(_line("Build: %s" % context.get("build", ""), 13, "parchment", w))
	where.add_child(_line("Goes to: %s" % _short(reports.folder() if reports != null else ""), 13, "parchment", w))
	top.add_child(where)
	_box.add_child(top)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 8)
	kinds.add_child(_line("Kind:", 16, "vellum", 0.0))
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for k: String in BugReports.KINDS:
		var b := UiKit.button(k, func() -> void: pass, 15)
		b.name = "Kind" + k.replace(" ", "")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = k == kind
		b.toggled.connect(func(on: bool) -> void:
			if on:
				kind = k
			elif kind == k:
				kind = "")
		kinds.add_child(b)
	_box.add_child(kinds)
	words = TextEdit.new()
	words.name = "Words"
	words.placeholder_text = "What happened, and what did you expect? (Cmd+Enter sends)"
	words.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	words.custom_minimum_size = Vector2(WIDE, 170)
	words.add_theme_font_size_override("font_size", 17)
	words.set_meta(&"pad_first", true)   # with a pad, A on it opens the board
	_box.add_child(words)
	_note = _line("Writes what you put here, the picture, where the game is and a copy of it. Nothing touches your saves.",
		14, "parchment", WIDE)
	_box.add_child(_note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var send_b := UiKit.button("Send report", send, 18)
	send_b.name = "Send"
	row.add_child(send_b)
	var cancel := UiKit.button("Cancel", close, 18)
	cancel.name = "Cancel"
	row.add_child(cancel)
	_box.add_child(row)
	_focus_soon(words)   # typing can start at once


func _picture() -> Control:
	var frame := PanelContainer.new()
	var s := UiKit.style("ui_black", "gilt_dark", 2, 1.0)
	s.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", s)
	frame.custom_minimum_size = PICTURE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if shot != null:
		var t := TextureRect.new()
		t.name = "Picture"
		t.texture = ImageTexture.create_from_image(shot)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = PICTURE - Vector2(4, 4)
		frame.add_child(t)
	else:
		var none := _line("No picture: nothing is drawn in a headless run.", 14, "parchment", PICTURE.x - 24.0)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(none)
	return frame


func _line(text: String, size: int, colour: String, wrap: float) -> Label:
	var l := UiKit.label(text, size, colour, wrap)
	if wrap > 0.0:
		l.max_lines_visible = 3
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## A path with the home folder as ~.
static func _short(path: String) -> String:
	var home := OS.get_environment("HOME")
	return "~" + path.trim_prefix(home) if home != "" and path.begins_with(home) else path


## Writes the report (once), then says where it went.
func send() -> void:
	if sent_to != "" or _closing:
		return
	sent_to = reports.write(words.text, kind, shot, context, save)
	if sent_to == "":
		_note.text = "Couldn't write the report in %s." % _short(reports.folder())
		_note.add_theme_color_override("font_color", Look.color("flame"))
		return
	Audio.sfx("page")
	_sent()


func _sent() -> void:
	_clear()
	_box.add_child(_filler())
	var head := UiKit.header("Sent")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(head)
	var in_vault := BugReports.vault() != "" and sent_to.contains("/" + BugReports.vault() + "/")
	var said := _line("The report is in the vault, where Claude reads it:" if in_vault \
		else "The report is here, outside the vault: copy the folder into the vault's Bug Reports for Claude to read it.",
		17, "vellum", WIDE)
	said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(said)
	var where := _line(_short(sent_to), 16, "gilt_light", WIDE)
	where.name = "SentTo"
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(where)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiKit.button("Open the folder", func() -> void: OS.shell_open(sent_to), 18))
	var done := UiKit.button("Done", close, 18)
	done.name = "Done"
	row.add_child(done)
	_box.add_child(row)
	_box.add_child(_filler())
	_focus_soon(done)


## Room that grows, so the few lines of the sent page sit in the middle of the frame.
static func _filler() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Focus on `c` once the screen is built, if it's still there then (a page rebuilt meanwhile drops it).
static func _focus_soon(c: Control) -> void:
	(func() -> void:
		if is_instance_valid(c) and c.is_inside_tree():
			c.grab_focus()).call_deferred()


## Closes the screen (written or not); the game goes on as it was.
func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	UiMotion.dismiss(self)


## Escape closes even while the words have the keyboard; Cmd or Ctrl+Enter sends. Both wait while the pad's board is
## open over the screen (its B leaves the words as they were).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or _closing or _board_open():
		return
	if k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.is_command_or_control_pressed():
		get_viewport().set_input_as_handled()
		if sent_to == "":
			send()
		else:
			close()


## The pad's Start: sends, or once sent, closes.
func pad_confirm() -> void:
	if sent_to == "":
		send()
	else:
		close()


## The pad's B (and any other way back): closes.
func _unhandled_input(event: InputEvent) -> void:
	if _closing or _board_open():
		return
	if event.is_action_pressed(&"combat_cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _board_open() -> bool:
	return is_inside_tree() and not get_tree().root.find_children("*", "PadKeyboard", false, false).is_empty()
