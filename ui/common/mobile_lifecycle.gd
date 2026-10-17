class_name MobileLifecycle
extends Node
## iOS interruption ownership. Suspension never releases a held input into the world on return.
## Exploration checkpoints are proactive; combat records durable commands before executing them.

var interrupted := false
var was_paused := false
var voice_paused := false
var audio_mode: ProcessMode
var players: Array[Dictionary] = []
var resume_layer: CanvasLayer
var elapsed := 0.0
var last_checkpoint := 0
var checkpoint_error := OK
var pause_reason := "The game is paused. Continue when you're ready."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	if not OS.has_feature("ios") or not is_inside_tree():
		return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		suspend()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and interrupted:
		MobileDevice.current.configure()


func _process(delta: float) -> void:
	if interrupted or not OS.has_feature("ios"):
		return
	elapsed += delta
	if elapsed >= 20.0:
		elapsed = 0.0
		checkpoint()


func checkpoint() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != "res://scenes/game.tscn" or ModeController.mode != ModeController.Mode.EXPLORATION:
		return
	# Screens can hold edits whose world counterpart commits on close (for example a loot container).
	if PadNav.current != null and PadNav.current.scope_now() != null:
		return
	if GameState.story.party.is_empty() or GameState.story.location == "":
		return
	var key := hash(GameState.story.to_dict())
	if key == last_checkpoint:
		return
	checkpoint_error = SaveSystem.autosave()
	if checkpoint_error == OK:
		last_checkpoint = key


func suspend(reason: String = "The game is paused. Continue when you're ready.") -> void:
	if interrupted:
		return
	checkpoint()
	pause_reason = reason
	if PadNav.current != null:
		PadNav.current.clear_held()
	interrupted = true
	was_paused = get_tree().paused
	voice_paused = VoiceOver.is_paused()
	UiFeel.touch.cancel()
	if OS.has_feature("ios"):
		DisplayServer.virtual_keyboard_hide()
	VoiceOver.set_paused(true)
	audio_mode = Audio.process_mode
	Audio.process_mode = Node.PROCESS_MODE_DISABLED
	_pause_players(get_tree().root)
	get_tree().paused = true
	# iOS delivers suspension while SceneTree is propagating a notification, which locks children.
	# Freeze gameplay immediately, but attach the resume UI only after that traversal finishes.
	_show_resume_page.call_deferred()


func _show_resume_page() -> void:
	if not interrupted or not is_inside_tree() or is_instance_valid(resume_layer):
		return
	resume_layer = CanvasLayer.new()
	resume_layer.layer = 120
	resume_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(resume_layer)
	var body := MobilePage.build(resume_layer, "Ready when you are", resume_play)
	(body.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(MobileUi.text(pause_reason))
	if checkpoint_error != OK:
		body.add_child(MobileUi.text("The latest exploration checkpoint couldn't be saved. Free storage, then save from the menu.", "rose"))
	body.add_child(MobileUi.button("Continue", resume_play))


func _pause_players(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		players.append({"node": weakref(node), "paused": bool(node.get("stream_paused"))})
		node.set("stream_paused", true)
	for child in node.get_children():
		_pause_players(child)


func resume_play() -> void:
	if not interrupted:
		return
	interrupted = false
	UiFeel.touch.cancel()
	if is_instance_valid(resume_layer):
		resume_layer.hide()
		resume_layer.queue_free()
	resume_layer = null
	for entry in players:
		var player := (entry["node"] as WeakRef).get_ref() as Node
		if is_instance_valid(player):
			player.set("stream_paused", entry["paused"])
	players.clear()
	Audio.process_mode = audio_mode
	VoiceOver.set_paused(voice_paused)
	get_tree().paused = was_paused
	if MobileDevice.current != null:
		MobileDevice.current.configure()
