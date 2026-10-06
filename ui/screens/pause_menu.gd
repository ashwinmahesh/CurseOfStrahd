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
	var frame := UiKit.screen_frame(self, "The party has fallen" if game_over else "Paused", Vector2(760, 640))
	if game_over:
		frame.add_child(UiKit.label("Barovia keeps what it takes. Load a save to try again.", 17, "parchment", 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if not game_over:
		row.add_child(UiKit.button("Resume", func() -> void: root.call("close_screen")))
		var save := UiKit.button("Save in a new slot", _save_new)
		if not SaveSystem.can_save():
			save.disabled = true
			save.tooltip_text = "In a fight the game saves itself at the start of each round; load that save to retry the round."
		row.add_child(save)
	row.add_child(UiKit.button("Quit to title", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
	frame.add_child(row)
	if not game_over:
		var respec := CheckBox.new()
		respec.text = "Allow rebuilding a character at Madam Eva (respec)"
		respec.button_pressed = bool(st.options.get("respec", true))
		respec.toggled.connect(func(on: bool) -> void: st.options["respec"] = on)
		frame.add_child(respec)
	frame.add_child(PauseMenu.volume_row("Music", Audio.music_volume, func(v: float) -> void: Audio.set_volumes(v, Audio.sfx_volume)))
	frame.add_child(PauseMenu.volume_row("Effects", Audio.sfx_volume, func(v: float) -> void:
		Audio.set_volumes(Audio.music_volume, v)
		Audio.sfx("click")))
	frame.add_child(UiKit.header("Saves"))
	_box = VBoxContainer.new()
	frame.add_child(UiKit.scroll(_box, Vector2(720, 340)))
	_list()


## A labelled volume slider (0-100%), saved with the player's settings as it moves.
static func volume_row(text: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UiKit.label(text, 16, "parchment")
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
		var text := "%s · %s · Day %d · %s" % [s["slot"], s["location"], int(s["day"]), str(s["saved_at"]).replace("T", " ")]
		var l := UiKit.label(text, 14)
		l.custom_minimum_size = Vector2(470, 0)
		l.tooltip_text = str(s["party"])
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var slot := str(s["slot"])
		row.add_child(UiKit.button("Load", func() -> void: _load(slot), 14))
		if not game_over:
			row.add_child(UiKit.button("Overwrite", func() -> void: _save(slot), 14))
		_box.add_child(row)


func _save_new() -> void:
	_save("save_%s" % Time.get_datetime_string_from_system().replace(":", "-"))


func _save(slot: String) -> void:
	var err := SaveSystem.save(slot)
	if err == OK:
		_list()
	else:
		_box.add_child(UiKit.label("Can't save now (in combat).", 15, "gilt"))


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot) == OK:
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not game_over and event.is_action_pressed(&"combat_cancel") and root != null:
		get_viewport().set_input_as_handled()
		root.call("close_screen")
