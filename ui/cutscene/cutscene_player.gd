class_name CutscenePlayer
extends CanvasLayer
## A place's cutscene while exploring (story/cutscenes.gd `trigger`; docs/ui/cutscenes.md): the picture fills the
## screen with the narrator's words under it, spoken if they're recorded (ADR 0013). A click, Space or Enter goes on to
## the next caption and closes it after the last; Skip closes it at once; Esc pauses it (Resume or Skip). Conversations
## show their cutscenes inside the dialogue box's own layer instead (DialogueUI).

signal finished

var view: CutsceneView
var id := ""
var captions: Array[String] = []
var index := 0
var done := false


func _init() -> void:
	name = "CutscenePlayer"
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS


## Shows cutscene `id` with `lines` as its captions, one after another. False (and nothing shown) when it has no
## picture for this story now.
func play(cutscene_id: String, lines: Array[String], st: StoryState) -> bool:
	id = cutscene_id
	var path := Cutscenes.image(id, st)
	if path == "":
		return false
	captions = lines
	view = CutsceneView.new()
	add_child(view)
	view.clicked.connect(advance)
	view.skip_requested.connect(close)
	view.show_image(path, Cutscenes.focus(id))
	view.show_caption(true)
	index = 0
	_show_caption()
	return true


## The next caption, or the end after the last.
func advance() -> void:
	if done or view.paused:
		return
	index += 1
	if index >= captions.size():
		close()
		return
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
