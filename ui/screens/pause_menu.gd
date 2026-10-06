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
		row.add_child(UiKit.button("Save in a new slot", _save_new))
	row.add_child(UiKit.button("Quit to title", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
	frame.add_child(row)
	frame.add_child(UiKit.header("Saves"))
	_box = VBoxContainer.new()
	frame.add_child(UiKit.scroll(_box, Vector2(720, 420)))
	_list()


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
		_box.add_child(UiKit.label("Can't save now (in combat).", 15, "candle"))


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot) == OK:
		get_tree().change_scene_to_file("res://scenes/game.tscn")
