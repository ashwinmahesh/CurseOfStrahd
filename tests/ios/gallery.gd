extends Node
## Native simulator render gallery. Representative states, not a replacement for touch gameplay journeys.
## Packaged only by ios_gallery.py into an isolated application and save container.

var shots: Array[Dictionary] = []
var directory := "user://gallery/"


func _ready() -> void:
	InputActions.ensure()
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveSystem.save_dir = "user://gallery_saves/"
	GameSettings.path = "user://gallery_settings.cfg"
	DirAccess.make_dir_recursive_absolute(directory)
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	_write_manifest(false)
	await wait_frames(30)
	var fixtures: Array[String] = ["mobile_menu", "mobile_ui", "mobile_secondary", "mobile_recovery", "mobile_controller", "mobile_caption"]
	var focused := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--gallery-fixture="):
			var selected := argument.get_slice("=", 1)
			if selected not in fixtures:
				push_error("Unknown gallery fixture: " + selected)
				return
			fixtures.assign([selected])
			focused = true
	for fixture: String in fixtures:
		var scene := (load("res://tools/capture/%s_capture.tscn" % fixture) as PackedScene).instantiate()
		add_child(scene)
		await wait_frames(4)
		await scene.call("capture_shots", self, directory + fixture)
		scene.queue_free()
		await wait_frames(4)
	if not focused:
		await _additional_pages()
	_write_manifest(true)
	print("IOS_GALLERY_COMPLETE: %d" % shots.size())
	var done := Label.new()
	done.text = "Simulator gallery ready: %d screenshots" % shots.size()
	add_child(done)
	set_process(false)


func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	var pixels := get_viewport().get_texture().get_image()
	var error := pixels.save_png(path)
	if error != OK:
		push_error("Gallery image write failed: %s (%d)" % [path, error])
		return
	shots.append({"file": path.get_file(), "width": pixels.get_width(), "height": pixels.get_height(),
		"logical_size": [MobileDevice.logical_size().x, MobileDevice.logical_size().y]})
	_write_manifest(false)
	print("IOS_GALLERY_SHOT: ", path.get_file())


func _write_manifest(complete: bool) -> void:
	var stream := FileAccess.open(directory + "manifest.json", FileAccess.WRITE)
	stream.store_string(JSON.stringify({"complete": complete, "native_ios": OS.has_feature("ios"),
		"evidence": "Representative UI states rendered in the iOS Simulator; not gameplay E2E",
		"os": OS.get_name(), "model": OS.get_model_name(), "shots": shots}, "\t"))


func _additional_pages() -> void:
	var state := StoryState.new()
	state.party.append(Pregens.build("godrick_pendlebrook", 3))
	state.location = "village_of_barovia"
	state.milestones = 10
	state.gold = 500
	var level := LevelUpScreen.new()
	add_child(level)
	level.open(self, state, 0)
	await wait_frames(12)
	_shot(directory + "additional_level_up.png")
	level.queue_free()
	await wait_frames(2)
	var rest := RestScreen.new()
	add_child(rest)
	rest.open(self, state, 0)
	await wait_frames(12)
	_shot(directory + "additional_rest.png")
	rest.queue_free()
	await wait_frames(2)
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_for(self, state, "blinsky")
	for side: String in ["Buy", "Sell", "Terms"]:
		shop.mobile_side = side
		shop._draw()
		await wait_frames(12)
		_shot(directory + "additional_shop_" + side.to_lower() + ".png")
	shop.queue_free()
	await wait_frames(2)
	var creator := CreationScreen.new()
	add_child(creator)
	creator.open_with([])
	for step in CharacterBuilder.STEP_NAMES.size():
		creator.step = step
		creator._draw()
		await wait_frames(12)
		_shot(directory + "additional_creation_%02d.png" % step)
	creator.queue_free()
	await wait_frames(2)
	var inventory := InventoryScreen.new()
	add_child(inventory)
	inventory.open(self, state, 0)
	inventory.mobile.section = "Stash"
	inventory._draw()
	await wait_frames(12)
	_shot(directory + "additional_stash.png")
	inventory.queue_free()
	await wait_frames(2)
	state.codex.append("tome_of_strahd")
	Bestiary.learn(state, "zombie")
	var journal := JournalScreen.new()
	add_child(journal)
	journal.open(self, state, 0)
	for section: String in ["Codex", "Bestiary"]:
		journal._turn_to(section)
		await wait_frames(12)
		_shot(directory + "additional_" + section.to_lower() + ".png")
		journal._mobile_read("tome_of_strahd" if section == "Codex" else "zombie")
		await wait_frames(12)
		_shot(directory + "additional_" + section.to_lower() + "_entry.png")
	journal.queue_free()
	await wait_frames(2)


func close_screen() -> void:
	pass
