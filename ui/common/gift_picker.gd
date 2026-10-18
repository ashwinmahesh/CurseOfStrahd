class_name GiftPicker
extends CanvasLayer
## "Give Pidlwick II something": what the party carries that a story ally travelling with them can be handed right now
## (GuestTalk.gifts: the brass key for Pidlwick, each with the line it starts). Picking one starts that conversation,
## where the guest answers and the story moves on. The mouse, 1-9, Enter and the pad's A pick; Esc and the pad's B
## back out. It sits over the place until it's answered.

## The gift picked (an index into `gifts`), or -1 for none.
signal answered(index: int)

const LAYER := 34
const WIDTH := 640.0

var guest_name := ""
var gifts: Array[Dictionary] = []
var choices: Array[Button] = []
var back_button: Button
var _done := false


## Shows the picker over `host`; `then(index)` runs once it's answered.
static func ask(host: Node, guest_name_: String, gifts_: Array[Dictionary], then: Callable) -> GiftPicker:
	var p := GiftPicker.new()
	p.guest_name = guest_name_
	p.gifts = gifts_
	p.answered.connect(then, CONNECT_ONE_SHOT)
	host.add_child(p)
	return p


func _init() -> void:
	name = "GiftPicker"
	layer = LAYER


func _ready() -> void:
	var box := UiKit.screen_frame(self, "Give %s something" % guest_name.get_slice(" ", 0), Vector2(WIDTH, 200.0 + 58.0 * gifts.size()))
	_rename_escape()
	box.add_child(UiKit.label("What will you hand %s?" % guest_name, 19, "vellum", WIDTH - 72.0))
	for i in gifts.size():
		var g := gifts[i]
		var idx := i
		var b := UiKit.button("%d. %s" % [i + 1, str(g["label"])], func() -> void: _answer(idx), 17)
		b.name = "Gift%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if str(g.get("item", "")) != "":
			UiParts.icon_on_button(b, "item", str(g["item"]), 26)
		if str(g.get("note", "")) != "":
			b.tooltip_text = str(g["note"])
		if i == 0:
			b.set_meta(&"pad_first", true)
		box.add_child(b)
		choices.append(b)
	back_button = UiKit.button("Never mind", func() -> void: _answer(-1), 17)
	back_button.name = "Back"
	back_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(back_button)
	if not choices.is_empty():
		choices[0].grab_focus.call_deferred()


func _rename_escape() -> void:
	for l: Node in find_children("*", "Label", true, false):
		if (l as Label).text in ["Esc: close", PadGlyphs.words("Esc: close", "{b}: close")]:
			PadGlyphs.hint(l, "Esc: never mind", "{b}: never mind")


## Answers once, then the picker goes.
func _answer(index: int) -> void:
	if _done:
		return
	_done = true
	answered.emit(index)
	UiMotion.dismiss(self)


func open() -> bool:
	return not _done


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_answer(-1)
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9 \
			and int(k.physical_keycode - KEY_1) < choices.size():
		get_viewport().set_input_as_handled()
		_answer(int(k.physical_keycode - KEY_1))
		return
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
