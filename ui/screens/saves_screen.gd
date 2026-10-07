class_name SavesScreen
extends CanvasLayer
## The saves on a page of their own (owner, 2026-10-07: "When clicking Save Game, we should be able to select the slot
## to save to, or save to a new slot"). Over the pause menu it saves, in a new slot or over one of the player's own
## saves once they confirm, or loads; over the title it loads, since the title's column has no room for a list. The
## list scrolls, so any number of saves fits, and every line ends in an ellipsis rather than spilling. Back or Escape
## returns to whatever opened it (Escape first closes the overwrite question, if it's up).

## Closed by Back, Escape or a save (after `saved`).
signal closed
## A save was written to `slot`.
signal saved(slot: String)

enum Mode { SAVE, LOAD }

## The frame, as wide as the credits' and short enough for the shortest window the game draws (1600 x 900).
const SIZE := Vector2(1100, 760)

var mode := Mode.LOAD
## What happens once a save has loaded: the opener leaves for the game (the pause menu unpauses first).
var after_load: Callable
var _list: VBoxContainer
var _note: Label
var _ask: Control                  ## the overwrite question, while it's up
var _new: Button                   ## New Save, when saving
var _back: Button
var _hidden: CanvasItem            ## what the page hides under it while it's up (the arch, the title's column)


func _init() -> void:
	name = "SavesScreen"
	layer = 31


## Opens the page over `parent` (the pause menu or the title) and returns it. `hide` (the arch, the title's column)
## is hidden while the page is up, so nothing of it shows around the frame.
static func open_on(parent: Node, mode_: Mode, after_load_: Callable, hide: CanvasItem = null) -> SavesScreen:
	var page := SavesScreen.new()
	page.mode = mode_
	page.after_load = after_load_
	page._hidden = hide
	if hide != null:
		hide.visible = false
	parent.add_child(page)
	page._build()
	return page


func _build() -> void:
	var box := UiKit.screen_frame(self, "Save Game" if mode == Mode.SAVE else "Load a Save", SIZE)
	# Clear of the title's arch, whose point hangs into the frame.
	var clear := Control.new()
	clear.custom_minimum_size = Vector2(0, 14)
	box.add_child(clear)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var hint := UiKit.label("Choose a save to save over, or start a new one. Every other save stays as it is."
		if mode == Mode.SAVE else "Choose a save to load. The game's own autosaves and a fight's round start are here too.",
		15, "parchment")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(1, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hint)
	if mode == Mode.SAVE:
		_new = UiParts.primary_button("New Save", _save_new)
		_new.name = "NewSave"
		_new.tooltip_text = "Saves the game in a new slot."
		_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(_new)
	box.add_child(head)
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.name = "Slots"
	_list.add_theme_constant_override("separation", 6)
	pane.add_child(UiParts.fill_scroll(_list))
	box.add_child(pane)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	var back := UiKit.button("Back", close, 18)
	back.name = "Back"
	back.tooltip_text = "Back (Esc)"
	foot.add_child(back)
	_note = UiKit.label("", 15, "gilt_light")
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.custom_minimum_size = Vector2(1, 0)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_note)
	box.add_child(foot)
	_back = back
	_fill()
	# A quicksave (F5) while the page is up shows in the list.
	EventBus.game_saved.connect(func(_slot: String) -> void:
		if not is_queued_for_deletion():
			_fill())
	_focus()


## The saves this page offers: to save over, only the player's own games still being played (the autosave and a
## fight's round start are the game's, and a finished game is kept as its ending); to load, every one.
func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in SaveSystem.list_slots():
		if mode == Mode.LOAD or (str(s["kind"]) == "" and str(s["finished"]) == ""):
			out.append(s)
	return out


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var shown := slots()
	if shown.is_empty():
		_list.add_child(UiKit.label("No saves of your own yet: New Save makes the first." if mode == Mode.SAVE
			else "No saves yet.", 15, "parchment"))
	for s in shown:
		_list.add_child(_row(s))


## The keyboard starts on New Save when saving, else on the newest save's Load (Back if there's none).
func _focus() -> void:
	var target: Button = _new
	if target == null:
		for b in _list.find_children("Act", "Button", true, false):
			if not b.is_queued_for_deletion():
				target = b as Button
				break
	if target == null:
		target = _back
	target.grab_focus.call_deferred()


## One save: its place, what kind of save it is with the day and when, the party, and the page's button.
func _row(s: Dictionary) -> Control:
	var slot := str(s["slot"])
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var place := _fit(str(s["location"]), 19, "gilt_light")
	place.add_theme_font_override("font", UiKit.display_font())
	info.add_child(place)
	info.add_child(_fit("%s · Day %d · %s" % [kind_of(s), int(s["day"]), when(s)], 14, "vellum"))
	info.add_child(_fit(str(s["party"]), 13, "parchment"))
	line.add_child(info)
	var act := UiParts.small_button("Save Here" if mode == Mode.SAVE else "Load", func() -> void:
		if mode == Mode.SAVE:
			_confirm(s)
		else:
			_load(slot))
	act.name = "Act"
	act.tooltip_text = "Save over this one (you'll be asked first)." if mode == Mode.SAVE else "Load this save."
	act.custom_minimum_size = Vector2(124, 0)
	line.add_child(act)
	var tip := "%s · Day %d · %s\n%s\n%s" % [s["location"], int(s["day"]), when(s), s["party"], slot]
	var row := UiParts.row(line, func() -> Control: return UiParts.rules_tip(kind_of(s), "", tip),
		slot == SaveSystem.current_slot)
	row.name = slot
	return row


## What kind of save it is, as its row says: the game's own slot, the autosave, a fight's round start, or a save.
static func kind_of(s: Dictionary) -> String:
	match str(s.get("kind", "")):
		"autosave":
			return "Autosave"
		"round":
			return "Fight, round start"
	if str(s.get("finished", "")) != "":
		return "Finished"
	return "This game" if str(s["slot"]) == SaveSystem.current_slot else "Save"


## When it was saved, to the minute ("2026-10-07 22:19").
static func when(s: Dictionary) -> String:
	var t := str(s.get("saved_at", "")).replace("T", " ")
	return t.substr(0, 16) if t.length() >= 16 else t


## A line that takes no width of its own (its row decides) and ends in an ellipsis if it's too long.
static func _fit(text: String, size: int, colour: String) -> Label:
	var l := UiKit.label(text, size, colour)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(1, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- Saving and loading -----------------------------------------------------------------------------

func _save_new() -> void:
	_save(SaveSystem.new_slot_name())


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot)
	if err != OK:
		_note.text = "Can't save now." if err == ERR_UNAVAILABLE else "The save couldn't be written (%s)." % error_string(err)
		return
	Audio.sfx("page")
	saved.emit(slot)
	close()


func _load(slot: String) -> void:
	var err := SaveSystem.load_slot(slot)
	if err == OK:
		if after_load.is_valid():
			after_load.call()
		return
	_note.text = "That save is from a newer build of the game." if err == ERR_FILE_UNRECOGNIZED \
		else "That save couldn't be read (%s)." % error_string(err)


## The question before a save is written over another: the save it replaces, and Overwrite or Cancel.
func _confirm(s: Dictionary) -> void:
	_close_confirm()
	_ask = Control.new()
	_ask.name = "Confirm"
	_ask.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ask)
	var dim := ColorRect.new()
	dim.color = Color(Look.color("void"), 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(dim)
	var p := UiKit.panel("ui_black", "gilt")
	(p.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(28)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	# No size of its own: it grows out from the centre as wide and tall as its content.
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(560, 0)
	UiKit.trim(p, 56.0)
	_ask.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	var q := UiKit.title("Overwrite this save?")
	q.add_theme_font_size_override("font_size", 26)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	col.add_child(UiKit.divider(260.0))
	for t: Array in [[str(s["location"]), 18, "gilt_light"], ["%s · Day %d · %s" % [kind_of(s), int(s["day"]), when(s)], 15, "vellum"],
			[str(s["party"]), 14, "parchment"]]:
		var l := _fit(str(t[0]), int(t[1]), str(t[2]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	var warn := UiKit.label("It's replaced by the game as it is now. Every other save stays as it is.", 15, "parchment", 500)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(warn)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var slot := str(s["slot"])
	var yes := UiParts.primary_button("Overwrite", func() -> void:
		_close_confirm()
		_save(slot))
	yes.name = "Overwrite"
	buttons.add_child(yes)
	var no := UiKit.button("Cancel", _close_confirm, 18)
	no.name = "Cancel"
	no.tooltip_text = "Keep that save (Esc)"
	buttons.add_child(no)
	col.add_child(buttons)
	no.grab_focus.call_deferred()


func confirm_open() -> bool:
	return _ask != null


func _close_confirm() -> void:
	if _ask != null:
		_ask.queue_free()
		_ask = null
		_focus()


func close() -> void:
	if is_queued_for_deletion():
		return
	_close_confirm()
	if _hidden != null and is_instance_valid(_hidden):
		_hidden.visible = true
	closed.emit()
	UiMotion.dismiss(self)


## Escape (the pause menu's action or the title's) closes the question if it's up, else the page.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _ask != null:
			_close_confirm()
		else:
			close()
