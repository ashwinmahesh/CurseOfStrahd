class_name MobileSkirmish
extends RefCounted
## Touch composition for the existing Skirmish commands. Map taps only select a square; Apply commits it.

var host: SkirmishScreen
var body: VBoxContainer
var tabs: ScrollContainer
var status: Label
var field_section := "Placement"
var list: VBoxContainer
var modal: CanvasLayer
var candidate := Vector2i(-1, -1)
var erase := false
var cursor := Vector2i.ZERO
var map_scroll: ScrollContainer
var cell_size := 44
var edit_history: Array[Dictionary] = []
var review: VBoxContainer


func _init(screen: SkirmishScreen) -> void:
	host = screen


func build() -> void:
	body = MobilePage.build(host.layer, "Skirmish", host._to_title)
	var page := body.get_parent().get_parent().get_parent() as MobilePage
	page.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs = MobileUi.tabs(SkirmishScreen.TABS, host.tab, func(value: String) -> void:
		host.tab = value
		host._filter = ""
		candidate = Vector2i(-1, -1)
		draw()
		page.scroll.set_deferred("scroll_vertical", 0))
	page.toolbar.add_child(tabs)
	if not MobilePracticeRecovery.read().is_empty():
		page.toolbar.add_child(MobileUi.button("Resume practice battle", func() -> void:
			if MobilePracticeRecovery.request():
				host.get_tree().change_scene_to_file(SkirmishScreen.ARENA_SCENE)))
	status = MobileUi.text("")
	host._note = status
	page.toolbar.add_child(status)
	host._frame = body


func draw() -> void:
	if host.tab != "Field":
		edit_history.clear()
	SkirmishScreen.kept_tab = host.tab
	MobileUi.select_tab(tabs, host.tab)
	MobileUi.clear(body)
	host.sketch = null
	list = null
	review = null
	match host.tab:
		"Party": _party()
		"Foes": _foes()
		"Field": _field()
		"Saved": _saved()
	body.add_child(MobileUi.button("Review and fight", _fight_review))
	body.add_child(MobileUi.button("Achievements", host.open_achievements))
	body.add_child(MobileUi.button("Back to title", host._to_title))


func _party() -> void:
	var names: Array[String] = []
	for entry in host.setup.party:
		names.append(str((entry["build"] as Dictionary).get("name", "Hero")))
	names.append("Add hero")
	body.add_child(MobileUi.tabs(names, names[host.hero_index] if host.hero_index >= 0 else "Add hero", func(value: String) -> void:
		host._select_hero(-1 if value == "Add hero" else names.find(value))
		host._filter = ""
		draw()))
	if host.hero_index < 0:
		body.add_child(MobileUi.text("Party: %d of %d heroes" % [host.setup.party.size(), SkirmishSetup.PARTY_CAP]))
		body.add_child(_level(SkirmishScreen.add_level, func(value: int) -> void: SkirmishScreen.add_level = value))
		var create := MobileUi.button("Create your own hero", host._open_creator)
		create.disabled = host.setup.party.size() >= SkirmishSetup.PARTY_CAP
		body.add_child(create)
		_search("Search heroes or classes", _fill_heroes)
		_fill_heroes()
		return
	var ch := host.lab_hero
	body.add_child(MobileUi.text(ch.name + " · " + ch.class_summary(), "gilt_light"))
	body.add_child(MobileUi.text("%d HP · AC %d · %s" % [ch.max_hp(), ch.ac_value(), SkirmishScreen._gear_line(ch)]))
	body.add_child(MobileUi.button("Character sheet", func() -> void: host.open_screen("sheet", 0)))
	body.add_child(MobileUi.button("Inventory and equipment", func() -> void: host.open_screen("inventory", 0)))
	var lowest := maxi(1, ch.character_level() - (host.undo.get(host.hero_index, []) as Array).size())
	if host.setup.pregen_of(host.hero_index) != "":
		lowest = 1
	body.add_child(_level(ch.character_level(), host._set_level, lowest))
	var level := MobileUi.button("Take the next level by hand", host._level_by_hand)
	level.disabled = ch.character_level() >= HeroLab.MAX_LEVEL
	body.add_child(level)
	body.add_child(MobileUi.button("Remove hero", func() -> void:
		_confirm("Remove " + ch.name + "?", "This removes the hero and their equipment from this setup.", "Remove", host._remove_hero)))
	_search("Search items to give this hero", _fill_items)
	_fill_items()


func _level(value: int, change: Callable, lowest: int = 1) -> Control:
	var option := OptionButton.new()
	option.tooltip_text = "Hero level"
	for level in range(1, HeroLab.MAX_LEVEL + 1):
		option.add_item("Level %d" % level)
		option.set_item_disabled(level - 1, level < lowest)
	option.select(value - 1)
	option.item_selected.connect(func(index: int) -> void: change.call(index + 1))
	MobileUi.fit(option)
	return option


func _search(placeholder: String, fill: Callable) -> void:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.text = host._filter
	input.custom_minimum_size.y = 48
	input.add_theme_font_size_override("font_size", UiScale.text(18))
	input.text_changed.connect(func(value: String) -> void:
		host._filter = value
		fill.call())
	body.add_child(input)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)


func _matches(text: String) -> bool:
	var query := host._filter.strip_edges().to_lower()
	return query.is_empty() or text.to_lower().contains(query)


func _fill_heroes() -> void:
	MobileUi.clear(list)
	for entry in Compendium.shared().all("pregens"):
		var id := str(entry["id"])
		if _matches(str(entry["name"])):
			var button := MobileUi.button(str(entry["name"]), func() -> void:
				_confirm(str(entry["name"]), str(entry.get("summary", "")) + "\nLevel %d" % SkirmishScreen.add_level, "Add hero", func() -> void: host._add_pregen(id)))
			button.disabled = host.setup.party.size() >= SkirmishSetup.PARTY_CAP
			list.add_child(button)
	for entry in Compendium.shared().all_playable("classes"):
		var id := str(entry["id"])
		if _matches(str(entry["name"])):
			var button := MobileUi.button("Quick " + str(entry["name"]), func() -> void:
				_confirm("Quick " + str(entry["name"]), "Uses the class's recommended scores and sensible picks. You can change equipment and take later levels by hand.", "Add hero", func() -> void: host._add_quick(id)))
			button.disabled = host.setup.party.size() >= SkirmishSetup.PARTY_CAP
			list.add_child(button)


func _fill_items() -> void:
	MobileUi.clear(list)
	var count := 0
	for entry in HeroLab.all_items():
		if not _matches(str(entry.get("name", "")) + " " + str(entry.get("category", ""))):
			continue
		if host._filter == "" and not MagicItems.is_magic(entry):
			continue
		count += 1
		if count > SkirmishScreen.LIST_CAP:
			list.add_child(MobileUi.text("Search to narrow the remaining items."))
			break
		var id := str(entry["id"])
		list.add_child(MobileUi.button(str(entry["name"]), func() -> void:
			_confirm(str(entry["name"]), str(entry.get("text", entry.get("summary", ""))), "Give to " + host.lab_hero.name, func() -> void: host._give(id))))


func _foes() -> void:
	body.add_child(MobileUi.text("Foes: %d of %d · %d XP · %s" % [host.setup.foes.size(), SkirmishSetup.MAX_FOES, host.setup.xp_total(), host.setup.difficulty()], "gilt_light"))
	var seen := {}
	for foe in host.setup.foes:
		var id := str(foe["monster"])
		if seen.has(id):
			continue
		seen[id] = true
		body.add_child(MobileUi.text("%d × %s" % [host.setup.foe_count(id), Compendium.shared().monster_data(id).get("name", id)]))
		body.add_child(MobileUi.button("Remove one", func() -> void:
			host.setup.remove_foe(id)
			draw()))
	_search("Search creatures by name or type", _fill_foes)
	_fill_foes()


func _fill_foes() -> void:
	MobileUi.clear(list)
	var count := 0
	for entry in SkirmishSetup.monsters():
		if not _matches(str(entry.get("name", "")) + " " + str(entry.get("type", ""))):
			continue
		count += 1
		if count > SkirmishScreen.LIST_CAP:
			list.add_child(MobileUi.text("Search to narrow the remaining creatures."))
			break
		var id := str(entry["id"])
		list.add_child(MobileUi.button(str(entry["name"]) + " · CR " + SkirmishSetup.cr_text(entry.get("cr", 0)), func() -> void:
			_confirm(str(entry["name"]), str(entry.get("summary", "")), "Use placement brush" if host.tab == "Field" else "Add foe", func() -> void:
				if host.tab == "Field":
					host.brush = {"kind": "new", "monster": id}
					field_section = "Placement"
					draw()
				else:
					host._add_foe(id))))


func _field() -> void:
	body.add_child(MobileUi.tabs(["Placement", "Maps", "Add foes", "Conditions"], field_section, func(value: String) -> void:
		field_section = value
		host._filter = ""
		candidate = Vector2i(-1, -1)
		draw()))
	match field_section:
		"Maps":
			_search("Search maps", _fill_maps)
			_fill_maps()
		"Add foes":
			_search("Search creatures", _fill_foes)
			_fill_foes()
		"Conditions":
			body.add_child(MobileUi.text("Light and surprise", "gilt_light"))
			if host.setup.outdoors():
				body.add_child(MobileUi.tabs(["Day", "Night"], host.setup.time.capitalize(), func(value: String) -> void: host.setup.time = value.to_lower()))
			else:
				body.add_child(MobileUi.text("Indoors uses this location's own lighting."))
			var options: Array[String] = ["None surprised", "Foes surprised", "Party surprised"]
			var keys: Array[String] = ["", "enemies", "party"]
			body.add_child(MobileUi.tabs(options, options[keys.find(host.setup.surprise)], func(value: String) -> void: host.setup.surprise = keys[options.find(value)]))
		_: _placement()


func _fill_maps() -> void:
	MobileUi.clear(list)
	for entry in SkirmishSetup.maps():
		if not _matches(str(entry["name"]) + " " + str(entry.get("region", ""))):
			continue
		var id := str(entry["id"])
		list.add_child(MobileUi.button(str(entry["name"]), func() -> void:
			_confirm("Use " + str(entry["name"]) + "?", "Placed squares will be cleared for the new field.", "Use map", func() -> void:
				_record_edit()
				host.setup.map_id = id
				host.setup.unpin()
				host.brush = {}
				field_section = "Placement"
				draw())))


func _placement() -> void:
	body.add_child(MobileUi.text("Choose a piece, then a square. Apply commits the preview. Drag the map to pan; the cursor controls offer precise placement."))
	var pieces := host._piece_strip()
	MobileUi.fit(pieces)
	body.add_child(pieces)
	var tools := HBoxContainer.new()
	tools.add_child(MobileUi.button("Place" if erase else "Erase", func() -> void:
		erase = not erase
		candidate = Vector2i(-1, -1)
		draw()))
	tools.add_child(MobileUi.button("Undo edit", undo_edit))
	tools.add_child(MobileUi.button("Clear placements", func() -> void:
		_confirm("Clear placements?", "Everyone will use an automatically chosen starting square.", "Clear", func() -> void:
			_record_edit()
			host.setup.unpin()
			host.brush = {}
			draw())))
	body.add_child(tools)
	map_scroll = ScrollContainer.new()
	map_scroll.custom_minimum_size.y = 220
	body.add_child(map_scroll)
	host.sketch = MapSketch.new()
	host.sketch.editable = true
	var grid := host.setup.grid()
	host.sketch.custom_minimum_size = Vector2(grid.width, grid.depth) * cell_size
	map_scroll.add_child(host.sketch)
	host.sketch.cell_clicked.connect(func(cell: Vector2i, _button: int) -> void: pick_cell(cell))
	host._show_sketch()
	var directions := HBoxContainer.new()
	for direction: String in ["Left", "Up", "Down", "Right"]:
		var offset: Vector2i = {"Left": Vector2i.LEFT, "Up": Vector2i.UP, "Down": Vector2i.DOWN, "Right": Vector2i.RIGHT}[direction]
		directions.add_child(MobileUi.button(direction, func() -> void:
			cursor = (cursor + offset).clamp(Vector2i.ZERO, Vector2i(grid.width - 1, grid.depth - 1))
			pick_cell(cursor)
			map_scroll.scroll_horizontal = roundi(cursor.x * cell_size - map_scroll.size.x / 2)
			map_scroll.scroll_vertical = roundi(cursor.y * cell_size - map_scroll.size.y / 2)))
	body.add_child(directions)
	review = VBoxContainer.new()
	body.add_child(review)
	_review_cell()


func pick_cell(cell: Vector2i) -> void:
	cursor = cell
	var piece := host.setup.piece_at(host.setup.placements(host.setup.grid()), cell)
	if host.brush.is_empty() and not erase and not piece.is_empty():
		host.brush = piece
		candidate = Vector2i(-1, -1)
		draw()
		return
	candidate = cell
	host.sketch.hover = cell
	host.sketch.queue_redraw()
	_review_cell()


func _review_cell() -> void:
	if review == null:
		return
	MobileUi.clear(review)
	var kind := str(host.brush.get("kind", ""))
	review.add_child(MobileUi.text("Erase mode" if erase else ("Choose a piece to move, or Add foes to choose a brush." if kind == "" else "Selected: " + kind)))
	if candidate.x < 0:
		return
	review.add_child(MobileUi.text("Square %d, %d" % [candidate.x, candidate.y]))
	var problem := ""
	if not erase:
		problem = "Choose a piece first." if kind == "" else host.setup.place_problem(host.setup.grid(), "foe" if kind == "new" else kind, int(host.brush.get("index", -1)), candidate, str(host.brush.get("monster", "")))
	else:
		problem = "No piece on this square." if host.setup.piece_at(host.setup.placements(host.setup.grid()), candidate).is_empty() else ""
	if problem != "":
		review.add_child(MobileUi.text(problem, "rose"))
	var apply := MobileUi.button("Apply removal" if erase else "Apply placement", commit_cell)
	apply.disabled = problem != ""
	review.add_child(apply)


func commit_cell() -> void:
	if candidate.x < 0:
		return
	var cell := candidate
	candidate = Vector2i(-1, -1)
	_record_edit()
	host._sketch_clicked(cell, MOUSE_BUTTON_RIGHT if erase else MOUSE_BUTTON_LEFT)


func _record_edit() -> void:
	edit_history.append(host.setup.to_dict())
	if edit_history.size() > 30:
		edit_history.pop_front()


func undo_edit() -> void:
	if edit_history.is_empty():
		return
	host.setup = SkirmishSetup.from_dict(edit_history.pop_back())
	SkirmishScreen.current = host.setup
	host.brush = {}
	candidate = Vector2i(-1, -1)
	host._select_hero(host.hero_index)
	draw()


func _saved() -> void:
	var name := LineEdit.new()
	name.placeholder_text = "Setup name"
	name.text = host.setup.title
	name.custom_minimum_size.y = 48
	name.text_changed.connect(func(value: String) -> void: host.setup.title = value.strip_edges() if value.strip_edges() != "" else "Skirmish")
	body.add_child(name)
	body.add_child(MobileUi.button("Save setup", func() -> void:
		if SkirmishLibrary.has(host.setup.title):
			_confirm("Replace saved setup?", host.setup.title, "Replace", host._save)
		else:
			host._save()))
	for entry in SkirmishLibrary.list():
		var file := str(entry["file"])
		body.add_child(MobileUi.text(str(entry["title"]), "gilt_light"))
		body.add_child(MobileUi.text("%d heroes · %d foes · %s" % [entry["heroes"], entry["foes"], entry["saved_at"]]))
		body.add_child(MobileUi.button("Load setup", func() -> void:
			_confirm("Load setup?", "Replaces the current party and field. Save your current setup first to keep it.", "Load", func() -> void: host._load(file))))
		var use_fight := MobileUi.button("Use its fight with this party", func() -> void:
			_confirm("Use saved fight?", "Keeps your heroes and replaces the field and foes.", "Use fight", func() -> void: host._load(file, true)))
		use_fight.disabled = host.setup.party.is_empty()
		body.add_child(use_fight)
		body.add_child(MobileUi.button("Delete saved setup", func() -> void:
			_confirm("Delete setup?", str(entry["title"]), "Delete", func() -> void:
				SkirmishLibrary.delete(file)
				draw())))


func _fight_review() -> void:
	var text := str(SkirmishSetup.map_entry(host.setup.map_id).get("name", "Field")) + "\n"
	text += "%d heroes · %d foes · %d XP · %s\n" % [host.setup.party.size(), host.setup.foes.size(), host.setup.xp_total(), host.setup.difficulty()]
	text += "\n".join(host._foe_lines())
	var problem := host.setup.problem()
	if problem != "":
		host.say(problem)
		return
	if not MobilePracticeRecovery.read().is_empty():
		text += "\nStarting this fight replaces the paused practice battle."
	_confirm("Start this fight?", text, "Fight", host._fight)


func _confirm(title: String, text: String, action: String, commit: Callable) -> void:
	_close_modal()
	modal = CanvasLayer.new()
	modal.layer = 95
	host.add_child(modal)
	var content := MobilePage.build(modal, title, _close_modal)
	(content.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(MobileUi.text(text))
	content.add_child(MobileUi.button(action, func() -> void:
		if modal == null:
			return
		_close_modal()
		commit.call()))


func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	UiFeel.touch.cancel()
