class_name LeadPrompt
extends CanvasLayer
## "Zuleika will take you to the Werewolf Den, Caves. Follow now, or come back later?" Asked when someone in a
## conversation offers to lead the party to another place (the dialogue statement `lead`, docs/contracts/dialogue.md).
## Following now walks the party after them and changes place; coming back later leaves the party where it stands
## (check.last is false) and the conversation goes on without the walk, for whoever wrote it to branch on. The mouse,
## 1 and 2, Enter and the pad's A follow; Esc and the pad's B come back later. It sits over the place and the hidden
## conversation.

## True: follow now. False: come back later.
signal answered(follow: bool)

## Over a conversation (20) and under the loading card (40), level with the Guidance prompt.
const LAYER := 34
const WIDTH := 640.0

var npc_name := ""
var place := ""
var follow_button: Button
var later_button: Button
var _done := false


## Shows the prompt over `host`; `then(follow)` runs once it's answered.
static func ask(host: Node, npc_name_: String, place_: String, then: Callable) -> LeadPrompt:
	var p := LeadPrompt.new()
	p.npc_name = npc_name_
	p.place = place_
	p.answered.connect(then, CONNECT_ONE_SHOT)
	host.add_child(p)
	return p


func _init() -> void:
	name = "LeadPrompt"
	layer = LAYER


func _ready() -> void:
	var box := UiKit.screen_frame(self, "Follow %s?" % npc_name.get_slice(" ", 0), Vector2(WIDTH, 330.0))
	_rename_escape()
	box.add_child(UiKit.label("%s will take you to %s." % [npc_name, place], 19, "vellum", WIDTH - 72.0))
	box.add_child(UiKit.label("Follow now, or come back later? Nothing is lost either way.", 15, "parchment", WIDTH - 72.0))
	follow_button = UiKit.button("1. Follow now", func() -> void: _answer(true), 18)
	follow_button.name = "FollowNow"
	follow_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	follow_button.set_meta(&"pad_first", true)
	box.add_child(follow_button)
	later_button = UiKit.button("2. Come back later", func() -> void: _answer(false), 18)
	later_button.name = "ComeBackLater"
	later_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(later_button)
	follow_button.grab_focus.call_deferred()


## The frame's note under its border says what Escape does here.
func _rename_escape() -> void:
	for l: Node in find_children("*", "Label", true, false):
		if (l as Label).text in ["Esc: close", PadGlyphs.words("Esc: close", "{b}: close")]:
			PadGlyphs.hint(l, "Esc: come back later", "{b}: come back later")


## Answers once, then the prompt goes.
func _answer(follow: bool) -> void:
	if _done:
		return
	_done = true
	answered.emit(follow)
	UiMotion.dismiss(self)


## Whether it's still waiting for an answer.
func open() -> bool:
	return not _done


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode in [KEY_1, KEY_2]:
		get_viewport().set_input_as_handled()
		_answer(k.physical_keycode == KEY_1)
		return
	# Nothing behind it moves while it's up.
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
