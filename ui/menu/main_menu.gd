extends Control
## The title screen (plan §5.6 Start step): New game (the pregenerated party, ready to play or to edit, or four
## characters built from scratch), Continue (the newest save), Load, the Phase 2 combat arena, and Quit.

var _creation: CreationScreen = null
var _box: VBoxContainer


func _ready() -> void:
	InputActions.ensure()
	Audio.play_music("title")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Look.color("void")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Key art (Gemini, art/ui/title_backdrop.png), darkened toward the left where the menu sits.
	var art := TextureRect.new()
	art.texture = load("res://art/ui/title_backdrop.png") as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(Look.color("void"), 0.92))
	grad.set_color(1, Color(Look.color("void"), 0.0))
	grad.set_offset(1, 0.62)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_box = VBoxContainer.new()
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = 110
	_box.offset_right = 110 + 560
	_box.offset_top = -340
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	_title()


func _title() -> void:
	for c in _box.get_children():
		c.queue_free()
	var t := UiKit.label("Curse of Strahd", 72, "vampire_red")
	t.add_theme_font_override("font", UiKit.display_font())
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(t)
	_box.add_child(UiKit.divider(460.0))
	var sub := UiKit.label("The mists are rising.", 22, "parchment")
	sub.add_theme_font_override("font", UiKit.display_font())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(sub)
	_box.add_child(_gap(14))
	var slots := SaveSystem.list_slots()
	var cont := UiKit.button("Continue", func() -> void: _load(str(slots[0]["slot"])), 24)
	cont.disabled = slots.is_empty()
	if not slots.is_empty():
		var prime := UiParts.primary_button("Continue", func() -> void: _load(str(slots[0]["slot"])))
		prime.add_theme_font_size_override("font_size", 24)
		prime.size_flags_horizontal = Control.SIZE_FILL
		cont.free()
		cont = prime
	_box.add_child(cont)
	_box.add_child(UiKit.button("New game", _new_game, 24))
	var load := UiKit.button("Load", _show_loads, 24)
	load.disabled = slots.is_empty()
	_box.add_child(load)
	_box.add_child(UiKit.button("Combat arena (Phase 2)", func() -> void: get_tree().change_scene_to_file("res://scenes/combat/arena.tscn"), 18))
	_box.add_child(UiKit.button("Credits", _credits, 18))
	_box.add_child(UiKit.button("Quit", func() -> void: get_tree().quit(), 18))


## Who made what (art/credits.json): the SRD's attribution, the art, and every credited track and sound.
func _credits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.name = "Credits"
	add_child(layer)
	var frame := UiKit.screen_frame(layer, "Credits", Vector2(1100, 760))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	var data := JSON.parse_string(FileAccess.get_file_as_string("res://art/credits.json")) as Dictionary
	for sec: Variant in data["sections"]:
		var lines := (sec as Dictionary)["lines"] as Array
		if lines.is_empty():
			continue
		body.add_child(UiParts.section(str((sec as Dictionary)["title"])))
		for line: Variant in lines:
			body.add_child(UiKit.label(str(line), 15, "vellum", 1000))
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(body))
	frame.add_child(pane)
	frame.add_child(UiParts.primary_button("Close", func() -> void: layer.queue_free()))


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _new_game() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UiKit.title("Who goes into the mists?"))
	_box.add_child(UiParts.section("The pregenerated party"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var data := Compendium.shared().get_entry("pregens", id)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.add_child(UiParts.framed_portrait(id, 140.0))
		var n := UiKit.label(str(data.get("name", id)), 17, "gilt_light")
		n.add_theme_font_override("font", UiKit.display_font())
		col.add_child(n)
		col.add_child(UiKit.label(str(data.get("summary", "")), 12, "parchment", 140))
		row.add_child(col)
	var plate := UiParts.card("ui_black", "gilt_dark", 0.82, 12)
	plate.add_child(row)
	_box.add_child(plate)
	_box.add_child(UiParts.primary_button("Pregenerated party: play as is", _pregen_party))
	(_box.get_child(_box.get_child_count() - 1) as Button).size_flags_horizontal = Control.SIZE_FILL
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
		var b := UiKit.button("%s · Day %d" % [s["location"], int(s["day"])], func() -> void: _load(slot), 17)
		b.tooltip_text = "%s · %s\n%s" % [slot, str(s["saved_at"]).replace("T", " "), s["party"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
