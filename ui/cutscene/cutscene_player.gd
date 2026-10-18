class_name CutscenePlayer
extends CanvasLayer
## A place's cutscene while exploring (story/cutscenes.gd `trigger`; docs/ui/cutscenes.md): the picture fills the
## screen with the narrator's words under it, spoken if they're recorded (ADR 0013). A click, Space or Enter goes on to
## the next caption, then to the next scene (its picture fading over this one, Cutscenes.scenes), and closes it after the
## last; Skip closes it at once; Esc pauses it (Resume or Skip). Conversations show their cutscenes inside the dialogue
## box's own layer instead (DialogueUI).

signal finished
## A scene's picture came up (its cutscene id): the game's music can turn for it (Audio.scene_mood, GameRoot.play_cutscene).
signal scene_shown(cutscene_id: String)

var view: CutsceneView
## The cutscene that was triggered (its first scene); `scene_id` is the picture on screen now.
var id := ""
var scene_id := ""
var scenes: Array[Dictionary] = []
var scene_index := 0
var captions: Array[String] = []
var index := 0
var done := false
var _st: StoryState


func _init() -> void:
	name = "CutscenePlayer"
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS


## Shows cutscene `id` with `lines` as its captions, one after another. False (and nothing shown) when it has no
## picture for this story now.
func play(cutscene_id: String, lines: Array[String], st: StoryState) -> bool:
	return play_scenes([{"id": cutscene_id, "lines": lines}] as Array[Dictionary], st)


## Shows `steps` (Cutscenes.scenes: {id, lines} each) one after another: the first with its captions, and past its last
## caption the next picture fades over it with its own. False (and nothing shown) when the first has no picture for
## this story now.
func play_scenes(steps: Array[Dictionary], st: StoryState) -> bool:
	if steps.is_empty() or Cutscenes.image(str(steps[0]["id"]), st) == "":
		return false
	scenes = steps
	_st = st
	id = str(steps[0]["id"])
	view = CutsceneView.new()
	add_child(view)
	view.clicked.connect(advance)
	view.skip_requested.connect(close)
	view.show_caption(true)
	_enter_scene(0)
	return true


## The next caption, then the next scene, or the end after the last.
func advance() -> void:
	if done or view.paused:
		return
	index += 1
	if index >= captions.size():
		if scene_index + 1 < scenes.size():
			_enter_scene(scene_index + 1)
		else:
			close()
		return
	_show_caption()


func _enter_scene(i: int) -> void:
	scene_index = i
	scene_id = str(scenes[i]["id"])
	captions = scenes[i]["lines"] as Array[String]
	index = 0
	view.show_image(Cutscenes.image(scene_id, _st), Cutscenes.focus(scene_id))
	scene_shown.emit(scene_id)
	_show_caption()


func close() -> void:
	if done:
		return
	done = true
	VoiceOver.stop()
	finished.emit()
	view.fade_out(queue_free)


func _show_caption() -> void:
	var text := captions[index] if index < captions.size() else ""
	view.caption("", "[i][color=#%s]%s[/color][/i]" % [Look.color("parchment").to_html(false), text.replace("[", "[lb]")])
	if text != "":
		VoiceOver.say(VoiceOver.NARRATOR, text)


func _unhandled_input(event: InputEvent) -> void:
	if done or view == null:
		return
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		view.set_paused(not view.paused)
		return
	if view.paused:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"combat_confirm") or event.is_action_pressed(&"combat_end_turn"):
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()   # nothing else reaches the world under the picture
