class_name SavesScreen
extends CanvasLayer
## The saves on a page of their own (owner, 2026-10-07: "When clicking Save Game, we should be able to select the slot
## to save to, or save to a new slot"). Over the pause menu it saves, in a new slot or over one of the player's own
## saves once they confirm, or loads; over the title it loads, since the title's column has no room for a list. The
## list scrolls, so any number of saves fits, and every line ends in an ellipsis rather than spilling. Back or Escape
## returns to whatever opened it (Escape first closes the overwrite question, if it's up).
## Q9: each save shows its picture and the player's note (typed above the list when saving), the list sorts by when,
## place or day, and loading has a second tab for the backups kept before each update. Q12: a Chapters tab, to jump in
## at the start of any chapter.

## Closed by Back, Escape or a save (after `saved`).
signal closed
## A save was written to `slot`.
signal saved(slot: String)

enum Mode { SAVE, LOAD }

## The frame, as wide as the credits' and short enough for the shortest window the game draws (1600 x 900).
const SIZE := Vector2(1100, 760)
## A save's picture in its row.
const PICTURE := Vector2(160, 90)
## How the list is sorted, kept with the player's settings: [id, the button's words].
const SORTS := [["newest", "Newest first"], ["place", "By place"], ["day", "By day"]]
const TABS: Array[String] = ["Your Saves", "Chapters", "Backups"]
## The travel map, for a chapter's picture and a save without one of its own.
const MAP := "res://art/ui/map/barovia.png"
## How much of the map a picture shows, in map pixels (16:9).
const MAP_VIEW := Vector2(640, 360)

var mode := Mode.LOAD
## What happens once a save has loaded: the opener leaves for the game (the pause menu unpauses first).
var after_load: Callable
var _list: VBoxContainer
var _status: Label
var _ask: Control                  ## the overwrite question, while it's up
var _new: Button                   ## New Save, when saving
var _back: Button
var _hidden: CanvasItem            ## what the page hides under it while it's up (the arch, the title's column)
var _closing := false
var _tab := "Your Saves"           ## loading: the player's saves or the backups
var _tabs: Control
var _hint: Label
var _note_edit: LineEdit           ## the player's note for the save about to be made
var _sort: Button


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
	_hint = UiKit.label("", 15, "parchment")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(1, 0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_hint)
	_sort = UiKit.button(_sort_words(), _next_sort, 15)
	_sort.name = "Sort"
	_sort.tooltip_text = "How the list is sorted: newest first, by place, or by the day in Barovia."
	head.add_child(_sort)
	box.add_child(head)
	if mode == Mode.SAVE:
		var note_row := HBoxContainer.new()
		note_row.add_theme_constant_override("separation", 16)
		_note_edit = LineEdit.new()
		_note_edit.name = "Note"
		_note_edit.placeholder_text = "Your note on this save (optional)"
		_note_edit.max_length = 60
		_note_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_note_edit.add_theme_font_size_override("font_size", 16)
		_note_edit.tooltip_text = "Shown with the save in every list. Writing over a save keeps its note unless you type a new one."
		_note_edit.text_submitted.connect(func(_t: String) -> void: _save_new())
		note_row.add_child(_note_edit)
		_new = UiParts.primary_button("New Save", _save_new)
		_new.name = "NewSave"
		_new.tooltip_text = "Saves the game in a new slot."
		_new.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note_row.add_child(_new)
		box.add_child(note_row)
	else:
		_tabs = Control.new()
		_tabs.custom_minimum_size = Vector2(0, 40)
		box.add_child(_tabs)
		_draw_tabs()
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
	_status = UiKit.label("", 15, "gilt_light")
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(1, 0)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status)
	box.add_child(foot)
	_back = back
	_fill()
	# A quicksave (F5) while the page is up shows in the list.
	# Deferred, so a save made from a row's own button never takes that button out of the list while it's still being
	# pressed, and not at all once the page is closing.
	EventBus.game_saved.connect(func(_slot: String) -> void:
		if not _closing:
			_fill.call_deferred())
	_focus()


## The saves this page offers, sorted: to save over, only the player's own games still being played (the autosave and
## a fight's round start are the game's, and a finished game is kept as its ending), and in an Honour run only its own
## one save; to load, every one.
func slots(dir: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var honour := mode == Mode.SAVE and SaveSystem.honour()
	for s in SaveSystem.list_slots(dir):
		if honour and str(s["slot"]) != SaveSystem.current_slot:
			continue   # an Honour run saves only over its own one save
		if mode == Mode.LOAD or (str(s["kind"]) == "" and str(s["finished"]) == ""):
			out.append(s)
	return sorted(out, sort_id())


## The player's sort (SORTS), "newest" until they pick another.
static func sort_id() -> String:
	var id := str(GameSettings.value("saves_sort", "newest"))
	return id if SORTS.any(func(o: Array) -> bool: return str(o[0]) == id) else "newest"


func _next_sort() -> void:
	var ids: Array = SORTS.map(func(o: Array) -> String: return str(o[0]))
	GameSettings.set_value("saves_sort", str(ids[(ids.find(sort_id()) + 1) % ids.size()]))
	_sort.text = _sort_words()
	_fill()


static func _sort_words() -> String:
	for o: Array in SORTS:
		if str(o[0]) == sort_id():
			return "%s  ›" % o[1]
	return ""


## `list` (as SaveSystem.list_slots gives it: newest first, finished games last) sorted by `how`: "newest" keeps it,
## "place" goes by the place's name and "day" by the latest day in Barovia, the newest save first within each.
static func sorted(list: Array[Dictionary], how: String) -> Array[Dictionary]:
	var out := list.duplicate()
	if how == "newest":
		return out
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if how == "place" and str(a["location"]) != str(b["location"]):
			return str(a["location"]).naturalnocasecmp_to(str(b["location"])) < 0
		if how == "day" and int(a["day"]) != int(b["day"]):
			return int(a["day"]) > int(b["day"])
		return str(a["saved_at"]) > str(b["saved_at"]))
	return out


func _draw_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var strip := UiParts.tab_strip(TABS, _tab, func(t: String) -> void:
		_tab = t
		_draw_tabs()
		_fill()
		_focus())
	strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	for b in strip.get_children():
		b.name = str((b as Button).text).replace(" ", "")
		(b as Button).tooltip_text = {"Your Saves": "Your saves, the autosaves and a fight's round start.",
			"Chapters": "Jump in at the start of any chapter, the party at that chapter's level and gear.",
			"Backups": "A copy of every save, kept before each update of the game."}.get((b as Button).text, "") as String
	_tabs.add_child(strip)


func _fill() -> void:
	if _closing:
		return
	_sort.visible = true
	# Out of the list at once, so the new rows can take their slots' names.
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if mode == Mode.SAVE and SaveSystem.honour():
		_hint.text = "An Honour run keeps one save, and the game keeps it up to date. Saving writes over it."
		_new.visible = SaveSystem.current_slot == "" or not SaveSystem.has_slot(SaveSystem.current_slot)
	elif mode == Mode.SAVE:
		_hint.text = "Choose a save to save over, or start a new one. Every other save stays as it is."
	elif _tab == "Chapters":
		_hint.text = "Begin at the start of any chapter, the party at its level and gear. Its first save makes a new slot."
		_sort.visible = false
		_fill_chapters()
		return
	elif _tab == "Backups":
		_hint.text = "Copies of your saves from before each update. A game loaded from one saves in a new slot."
		_fill_backups()
		return
	else:
		_hint.text = "Choose a save to load. The game's own autosaves and a fight's round start are here too."
	var shown := slots()
	if shown.is_empty():
		_list.add_child(UiKit.label("No saves of your own yet: New Save makes the first." if mode == Mode.SAVE
			else "No saves yet.", 15, "parchment"))
	for s in shown:
		_list.add_child(_row(s))


## Each chapter (Q12, SaveSystem.chapters) in story order: the map around it, its number and title, the party's level
## and the day, and Begin.
func _fill_chapters() -> void:
	var list := SaveSystem.chapters()
	if list.is_empty():
		_list.add_child(UiKit.label("No chapter saves in this build.", 15, "parchment"))
	for s in list:
		_list.add_child(_chapter_row(s))


func _chapter_row(s: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.add_child(picture(s))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := _fit("Chapter %d: %s" % [int(s["number"]), s["title"]], 19, "gilt_light")
	head.add_theme_font_override("font", UiKit.display_font())
	info.add_child(head)
	info.add_child(_fit("Level %d · Day %d · %s" % [int(s["level"]), int(s["day"]), s["location"]], 14, "vellum"))
	info.add_child(_fit(", ".join(SaveSystem.chapter_party()), 13, "parchment"))
	line.add_child(info)
	var go := UiParts.small_button("Begin", func() -> void: _begin(s))
	go.name = "Act"
	go.tooltip_text = "Start a game here with your heroes at this level; the others wait at camp. Its first save makes a slot of its own."
	go.custom_minimum_size = Vector2(124, 0)
	line.add_child(go)
	var about := place_summary(str(s.get("location_id", "")), str(s.get("place", "")))
	var row := UiParts.row(line, func() -> Control: return UiParts.rules_tip(str(s["title"]),
		"Chapter %d · Level %d" % [int(s["number"]), int(s["level"])], about))
	row.name = str(s["chapter"])
	return row


## Each backup (newest first) under a heading saying when it was kept, with its saves.
func _fill_backups() -> void:
	var folders := SaveSystem.backups()
	if folders.is_empty():
		_list.add_child(UiKit.label("No backups yet. The game keeps a copy of every save before each update.", 15, "parchment"))
	for f in folders:
		var shown := slots(SaveSystem.backups_dir().path_join(f))
		if shown.is_empty():
			continue
		_list.add_child(UiParts.section(backup_title(f)))
		for s in shown:
			_list.add_child(_row(s))


## A backup's heading from its folder name (<date>T<time>_<commit>): "Kept 2026-10-07 18:55, before build 463d4670".
static func backup_title(folder: String) -> String:
	var at := folder.get_slice("_", 0)
	var stamp := "%s %s" % [at.get_slice("T", 0), at.get_slice("T", 1).replace("-", ":").left(5)]
	return "Kept %s, before build %s" % [stamp, folder.get_slice("_", 1)]


## The keyboard starts on New Save when saving, else on the newest save's Load (Back if there's none).
func _focus() -> void:
	_grab_focus.call_deferred()


## Picked once the list has settled (a delete or a tab rebuilds it), so it's never a row on its way out.
func _grab_focus() -> void:
	if _closing or not is_inside_tree():
		return
	var target: Button = _new if _new != null and _new.visible else null
	if target == null:
		for b in _list.find_children("Act", "Button", true, false):
			if not b.is_queued_for_deletion() and (b as Button).is_inside_tree():
				target = b as Button
				break
	if target == null:
		target = _back
	target.grab_focus()


## One save: its picture, its place, what kind of save it is with the day and when, the party, the player's note, and
## the page's button.
func _row(s: Dictionary) -> Control:
	var slot := str(s["slot"])
	var home := _in_saves(s)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.add_child(picture(s))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var place := _fit(str(s["location"]), 19, "gilt_light")
	place.add_theme_font_override("font", UiKit.display_font())
	info.add_child(place)
	var difficulty := str(s.get("mode", ""))
	info.add_child(_fit("%s%s · Day %d · Level %d · %s" % [kind_of(s), " · " + difficulty if difficulty != "" else "",
		int(s["day"]), int(s.get("level", 1)), when(s)], 14, "vellum"))
	info.add_child(_fit(str(s["party"]), 13, "parchment"))
	var note := str(s.get("note", ""))
	if note != "":
		var n := _fit("“%s”" % note, 15, "gilt")
		n.name = "Note"
		info.add_child(n)
	line.add_child(info)
	var act := UiParts.small_button("Save Here" if mode == Mode.SAVE else "Load", func() -> void:
		if mode == Mode.SAVE and SaveSystem.honour():
			_save(slot)   # the run's own one save: nothing else to lose
		elif mode == Mode.SAVE:
			_confirm(s)
		else:
			_load(s))
	act.name = "Act"
	act.tooltip_text = "Save over this one (you'll be asked first)." if mode == Mode.SAVE else "Load this save."
	act.custom_minimum_size = Vector2(124, 0)
	line.add_child(act)
	# Any of the player's saves can be deleted, after a question; never a backup's copy, nor a live Honour run's save.
	if home and not _live_honour(slot):
		var gone := UiParts.small_button("Delete", func() -> void: _confirm_delete(s))
		gone.name = "Delete"
		gone.tooltip_text = "Delete this save (you'll be asked first)."
		line.add_child(gone)
	var tip := "%s · Day %d · %s\n%s%s\n%s" % [s["location"], int(s["day"]), when(s), s["party"],
		"\n“%s”" % note if note != "" else "", slot]
	var row := UiParts.row(line, func() -> Control: return UiParts.rules_tip(kind_of(s), "", tip),
		home and slot == SaveSystem.current_slot)
	row.name = slot
	return row


## A save's picture (Q9), framed in gilt. A chapter, or a save with none (a fight's round start, one from before
## pictures), shows the travel map around its place; one off the map shows the crest on black.
static func picture(s: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = PICTURE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var path := str(s.get("thumb", ""))
	var img := Image.load_from_file(path) if path != "" and FileAccess.file_exists(path) else null
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else \
		map_view(str(s.get("location_id", "")), str(s.get("place", "")))
	if tex != null:
		var pic := TextureRect.new()
		pic.name = "Picture"
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pic)
	holder.add_child(UiParts.drawn(PICTURE, func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		if tex == null:
			c.draw_rect(r, Look.color("ui_black"))
			UiParts.crest(c, c.size / 2.0, 14.0)
		c.draw_rect(r.grow(-1), Look.color("gilt_dark"), false, 2.0)))
	return holder


## The travel map around `place` (a travel place's id) or else the place `location_id` is at or in the region of, or
## null when it's off the map (Death House's cellars are in the village's region; a test room is nowhere).
static func map_view(location_id: String, place: String = "") -> Texture2D:
	var at := _map_place(location_id, place)
	if at.is_empty() or not ResourceLoader.exists(MAP):
		return null
	var map := load(MAP) as Texture2D
	var pos := at.get("pos", []) as Array
	var size := map.get_size()
	var view := Rect2(Vector2(float(pos[0]), float(pos[1])) * size - MAP_VIEW / 2.0, MAP_VIEW)
	view.position = view.position.clamp(Vector2.ZERO, size - MAP_VIEW)
	var crop := AtlasTexture.new()
	crop.atlas = map
	crop.region = view
	return crop


## The travel place (data/travel) for `place` or `location_id`: the place by id, else the one at that location, else
## one in the location's region. {} if none.
static func _map_place(location_id: String, place: String) -> Dictionary:
	var region := str(Compendium.shared().get_entry("locations", location_id).get("region", "")) if location_id != "" else ""
	var by_region := {}
	for t: Variant in (Compendium.shared().tables.get("travel", {}) as Dictionary).values():
		for p: Variant in (t as Dictionary).get("places", []):
			var d := p as Dictionary
			if (d.get("pos", []) as Array).size() < 2:
				continue
			if (place != "" and str(d["id"]) == place) or (location_id != "" and str(d.get("location", "")) == location_id):
				return d
			if by_region.is_empty() and region != "" and str(d.get("region", "")) == region:
				by_region = d
	return by_region


## What the travel map says of a place, for a chapter's tooltip ("" if nothing).
static func place_summary(location_id: String, place: String) -> String:
	return str(_map_place(location_id, place).get("summary", ""))


## A save in the saves folder (not a backup's copy).
static func _in_saves(s: Dictionary) -> bool:
	return str(s.get("dir", SaveSystem.save_dir)).simplify_path() == SaveSystem.save_dir.simplify_path()


## What kind of save it is, as its row says: the game's own slot, the autosave, a fight's round start, or a save.
static func kind_of(s: Dictionary) -> String:
	match str(s.get("kind", "")):
		"autosave":
			return "Autosave"
		"round":
			return "Fight, round start"
	if str(s.get("finished", "")) != "":
		return "Finished"
	return "This game" if _in_saves(s) and str(s["slot"]) == SaveSystem.current_slot else "Save"


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


## The note typed above the list, or null (keep the save's own) when there's none.
func _typed_note() -> Variant:
	var t := _note_edit.text.strip_edges() if _note_edit != null else ""
	return t if t != "" else null


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot, _typed_note())
	if err != OK:
		_status.text = "Can't save now." if err == ERR_UNAVAILABLE else "The save couldn't be written (%s)." % error_string(err)
		return
	Audio.sfx("page")
	saved.emit(slot)
	close()


func _load(s: Dictionary) -> void:
	var err := SaveSystem.load_from(str(s.get("dir", SaveSystem.save_dir)), str(s["slot"]))
	if err == OK:
		if after_load.is_valid():
			after_load.call()
		return
	_status.text = "That save is from a newer build of the game." if err == ERR_FILE_UNRECOGNIZED \
		else "That save couldn't be read (%s)." % error_string(err)


func _begin(chapter: Dictionary) -> void:
	var err := SaveSystem.begin_chapter(chapter)
	if err == OK:
		if after_load.is_valid():
			after_load.call()
		return
	_status.text = "That chapter couldn't be read (%s)." % error_string(err)


## The question before a save is written over another: the save it replaces, and Overwrite or Cancel.
func _confirm(s: Dictionary) -> void:
	var keeps: Variant = _typed_note()
	var slot := str(s["slot"])
	_question(s, "Overwrite this save?", str(keeps) if keeps != null else str(s.get("note", "")),
		"It's replaced by the game as it is now. Every other save stays as it is.", "Overwrite", func() -> void: _save(slot))


## The question before a save is deleted (owner, 2026-10-08: "We should be able to delete save files from the UI"):
## the save, and Delete or Cancel.
func _confirm_delete(s: Dictionary) -> void:
	_question(s, "Delete this save?", str(s.get("note", "")), "It's gone for good, with its picture. Every other save stays as it is.",
		"Delete", func() -> void: _delete(s))


## A live Honour run's one save, which can't be deleted from inside that run (from the title it can).
func _live_honour(slot: String) -> bool:
	return get_parent() is PauseMenu and SaveSystem.honour() and slot == SaveSystem.current_slot


func _delete(s: Dictionary) -> void:
	if SaveSystem.delete_save(str(s["slot"])):
		Audio.sfx("page")
		_status.text = "Deleted."
	else:
		_status.text = "That save is already gone."
	_fill()
	_focus()


## A question about one save: `title`, the save's place, kind, day and party, its note, `warn`, and `yes_text` (which
## runs `on_yes`) or Cancel. Escape cancels.
func _question(s: Dictionary, title: String, note: String, warn_text: String, yes_text: String, on_yes: Callable) -> void:
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
	var q := UiKit.title(title)
	q.add_theme_font_size_override("font_size", 26)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	col.add_child(UiKit.divider(260.0))
	for t: Array in [[str(s["location"]), 18, "gilt_light"], ["%s · Day %d · %s" % [kind_of(s), int(s["day"]), when(s)], 15, "vellum"],
			[str(s["party"]), 14, "parchment"]]:
		var l := _fit(str(t[0]), int(t[1]), str(t[2]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	if note != "":
		var n := _fit("“%s”" % note, 15, "gilt")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
	var warn := UiKit.label(warn_text, 15, "parchment", 500)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(warn)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UiParts.primary_button(yes_text, func() -> void:
		_close_confirm()
		on_yes.call())
	yes.name = yes_text
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
	if _closing or is_queued_for_deletion():
		return
	_closing = true
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
