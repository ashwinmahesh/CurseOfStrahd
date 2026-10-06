class_name PrepareScreen
extends CanvasLayer
## Changing prepared spells after a Long Rest (2024 PHB): Clerics, Druids, Paladins, Rangers and Wizards (from the
## spellbook) may pick a new list; Bards, Sorcerers and Warlocks change theirs when they gain a level. One choice box
## per caster, the same widget character creation uses; each change rebuilds the character at once.

var root: Node
var st: StoryState
var _box: VBoxContainer


func _init() -> void:
	name = "PrepareScreen"
	layer = 32


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Prepare spells", Vector2(1300, 820))
	frame.add_child(UiKit.label("After a Long Rest, choose which spells each caster has ready. Always-prepared spells (a domain's, an oath's) don't count.", 15, "parchment", 1240))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	frame.add_child(UiKit.scroll(_box, Vector2(1260, 640)))
	frame.add_child(UiKit.button("Done", func() -> void: queue_free(), 16))
	_draw()


## The prepared-spell choices this party can change now: [{ch, choice}].
static func preparable(state: StoryState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch in state.party:
		if ch.dead:
			continue
		for e in ch.spellcasting:
			var cid := str(e["class_id"])
			var sc := Compendium.shared().class_data(cid).get("spellcasting", {}) as Dictionary
			if str(sc.get("swap_prepared", "")) != "long_rest":
				continue
			var c := ch.choice("%s.prepared" % cid)
			if c != null:
				out.append({"ch": ch, "choice": c})
	return out


func _draw() -> void:
	for c in _box.get_children():
		c.queue_free()
	var list := PrepareScreen.preparable(st)
	if list.is_empty():
		_box.add_child(UiKit.label("Nobody in the party prepares spells after a rest.", 15, "parchment"))
	for entry in list:
		var ch := entry["ch"] as Character
		var c := entry["choice"] as Choice
		ChoiceOptions.populate(c, ch)
		_box.add_child(UiKit.header("%s · %s" % [ch.name, Compendium.shared().display_name("classes", c.class_id)]))
		var w := ChoiceWidget.create(c)
		w.picks_changed.connect(func(key: String, picks: Array) -> void:
			if not ch.build.has("choices"):
				ch.build["choices"] = {}
			(ch.build["choices"] as Dictionary)[key] = picks.duplicate()
			ch.refresh()
			_draw.call_deferred())
		_box.add_child(w)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
