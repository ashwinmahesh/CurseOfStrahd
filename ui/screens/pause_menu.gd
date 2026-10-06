class_name PauseMenu
extends CanvasLayer
## Esc menu (plan §10 Phase 3 "save and load anywhere outside combat"): resume, save to a new or an existing slot,
## load any save, settings later, quit to the title. As the game-over screen it offers only loading.

var game_over := false
var root: Node
var st: StoryState
var _box: VBoxContainer


func _init() -> void:
	name = "PauseMenu"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "The party has fallen" if game_over else "Paused", Vector2(800, 700))
	if game_over:
		var lost := UiKit.label("Barovia keeps what it takes. Load a save to try again.", 17, "rose", 720)
		lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame.add_child(lost)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if not game_over:
		var resume := UiParts.primary_button("Resume", func() -> void: root.call("close_screen"))
		row.add_child(resume)
		var save := UiKit.button("Save in a new slot", _save_new, 16, "journal")
		if not SaveSystem.can_save():
			save.disabled = true
			save.tooltip_text = "In a fight the game saves itself at the start of each round; load that save to retry the round."
		row.add_child(save)
	row.add_child(UiKit.button("Quit to title", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 16))
	frame.add_child(row)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 6)
	if not game_over:
		var respec := CheckBox.new()
		respec.text = "Allow rebuilding a character at Madam Eva (respec)"
		respec.button_pressed = bool(st.options.get("respec", true))
		respec.toggled.connect(func(on: bool) -> void: st.options["respec"] = on)
		settings.add_child(respec)
	settings.add_child(PauseMenu.volume_row("Music", Audio.music_volume, func(v: float) -> void: Audio.set_volumes(v, Audio.sfx_volume)))
	settings.add_child(PauseMenu.volume_row("Effects", Audio.sfx_volume, func(v: float) -> void:
		Audio.set_volumes(Audio.music_volume, v)
		Audio.sfx("click")))
	frame.add_child(UiParts.section("Settings"))
	frame.add_child(UiParts.row(settings, Callable(), false, 12))
	frame.add_child(UiParts.section("Saves"))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_box))
	frame.add_child(pane)
	_list()


## A labelled volume slider (0-100%), saved with the player's settings as it moves.
static func volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UiParts.caption(text, 12)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.name = text
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(320, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.drag_ended.connect(func(_changed: bool) -> void: on_change.call(slider.value))
	row.add_child(slider)
	return row


func _list() -> void:
	for c in _box.get_children():
		c.queue_free()
	var slots := SaveSystem.list_slots()
	if slots.is_empty():
		_box.add_child(UiKit.label("No saves yet.", 15, "parchment"))
	for s in slots:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.label("%s · Day %d" % [s["location"], int(s["day"])], 15, "vellum"))
		info.add_child(UiKit.label("%s · %s" % [s["slot"], str(s["saved_at"]).replace("T", " ")], 12, "bone"))
		row.add_child(info)
		var slot := str(s["slot"])
		row.add_child(UiParts.small_button("Load", func() -> void: _load(slot)))
		if not game_over:
			row.add_child(UiParts.small_button("Overwrite", func() -> void: _save(slot)))
		var party_text := str(s["party"])
		_box.add_child(UiParts.row(row, func() -> Control: return UiParts.rules_tip("Party", "", party_text)))


func _save_new() -> void:
	_save("save_%s" % Time.get_datetime_string_from_system().replace(":", "-"))


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot)
	if err == OK:
		_list()
	else:
		_box.add_child(UiParts.row(UiKit.label("Can't save now (in combat).", 15, "gilt")))


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot) == OK:
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not game_over and event.is_action_pressed(&"combat_cancel") and root != null:
		get_viewport().set_input_as_handled()
		root.call("close_screen")
