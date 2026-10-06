extends Control
## The title screen (plan §5.6 Start step): New game (the pregenerated party, ready to play or to edit, or four
## characters built from scratch), Continue (the newest save), Load, the Phase 2 combat arena, and Quit.

var _creation: CreationScreen = null
var _box: VBoxContainer


func _ready() -> void:
	InputActions.ensure()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Look.color("night_deep")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = -330
	_box.offset_right = 330
	_box.offset_top = -330
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	_title()


func _title() -> void:
	for c in _box.get_children():
		c.queue_free()
	var t := UiKit.label("Curse of Strahd", 54, "vampire_red")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	var sub := UiKit.label("The mists are rising.", 20, "parchment")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	var slots := SaveSystem.list_slots()
	var cont := UiKit.button("Continue", func() -> void: _load(str(slots[0]["slot"])), 22)
	cont.disabled = slots.is_empty()
	_box.add_child(cont)
	_box.add_child(UiKit.button("New game", _new_game, 22))
	var load := UiKit.button("Load", _show_loads, 22)
	load.disabled = slots.is_empty()
	_box.add_child(load)
	_box.add_child(UiKit.button("Combat arena (Phase 2)", func() -> void: get_tree().change_scene_to_file("res://scenes/combat/arena.tscn"), 18))
	_box.add_child(UiKit.button("Quit", func() -> void: get_tree().quit(), 18))


func _new_game() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UiKit.title("Who goes into the mists?"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var data := Compendium.shared().get_entry("pregens", id)
		var col := VBoxContainer.new()
		col.add_child(UiKit.portrait(id, 140))
		col.add_child(UiKit.label(str(data.get("name", id)), 15, "flame"))
		col.add_child(UiKit.label(str(data.get("summary", "")), 12, "parchment", 150))
		row.add_child(col)
	_box.add_child(row)
	_box.add_child(UiKit.button("Pregenerated party: play as is", _pregen_party, 18))
	_box.add_child(UiKit.button("Pregenerated party: edit them first", func() -> void: _open_creator(true), 18))
	_box.add_child(UiKit.button("Build all four from scratch", func() -> void: _open_creator(false), 18))
	var copy := UiKit.button("Copy from a save", func() -> void: pass, 18)
	copy.disabled = true
	copy.tooltip_text = "No other saves to copy from yet (Phase 4)."
	_box.add_child(copy)
	_box.add_child(UiKit.button("Back", _title, 16))


func _pregen_party() -> void:
	var party: Array[Character] = []
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		party.append(ch)
	_start(party)


func _open_creator(from_pregens: bool) -> void:
	var builds: Array[Dictionary] = []
	if from_pregens:
		for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
			var b := (Compendium.shared().get_entry("pregens", id)["build"] as Dictionary).duplicate(true)
			var app := (b.get("appearance", {}) as Dictionary).duplicate()
			app["art"] = id
			b["appearance"] = app
			builds.append(b)
	_creation = CreationScreen.new()
	_box.visible = false
	add_child(_creation)
	_creation.finished.connect(_start)
	_creation.cancelled.connect(func() -> void:
		_creation.queue_free()
		_creation = null
		_box.visible = true
		_title())
	_creation.open_with(builds)


## A fresh playthrough: the party at level 1 on the Old Svalich Road, at dusk.
func _start(party: Array[Character]) -> void:
	GameState.reset()
	var st := GameState.story
	for ch in party:
		st.party.append(ch)
	st.gold = 10.0
	st.location = ""
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _show_loads() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UiKit.title("Load"))
	for s in SaveSystem.list_slots():
		var slot := str(s["slot"])
		var b := UiKit.button("%s · %s · Day %d · %s" % [slot, s["location"], int(s["day"]), str(s["saved_at"]).replace("T", " ")], func() -> void: _load(slot), 14)
		b.tooltip_text = str(s["party"])
		_box.add_child(b)
	_box.add_child(UiKit.button("Back", _title, 16))


func _load(slot: String) -> void:
	if SaveSystem.load_slot(slot) == OK:
		get_tree().change_scene_to_file("res://scenes/game.tscn")


## The capture tool's sequence: the title, the new-game choice, and character creation partway through.
func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_1_title.png")
	_new_game()
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_2_new_game.png")
	_open_creator(true)
	await tool.call("wait_frames", 10)
	tool.call("_shot", out + "_3_creation.png")
	for step: int in [2, CharacterBuilder.Step.REVIEW]:
		_creation.step = step
		_creation.call("_draw")
		await tool.call("wait_frames", 10)
		tool.call("_shot", out + "_4_creation_step_%d.png" % step)
