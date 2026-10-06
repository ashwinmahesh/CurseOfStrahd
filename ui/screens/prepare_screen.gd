class_name PrepareScreen
extends CanvasLayer
## Changing prepared spells after a Long Rest (2024 PHB): Clerics, Druids, Paladins, Rangers and Wizards (from the
## spellbook) may pick a new list; Bards, Sorcerers and Warlocks change theirs when they gain a level. One choice box
## per caster, the same widget character creation uses; each change rebuilds the character at once.

var root: Node
var st: StoryState
var _box: VBoxContainer
## Which rest just ended: "long_rest" or "short_rest" (see preparable()).
var rest_kind := "long_rest"


func _init() -> void:
	name = "PrepareScreen"
	layer = 32


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Prepare Spells", Vector2(1300, 820))
	frame.add_child(UiKit.label("After a Long Rest, choose which spells each caster has ready. Always-prepared spells (a domain's, an oath's) don't count. Hover a spell for what it does.", 15, "parchment", 1220))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_box))
	frame.add_child(pane)
	frame.add_child(UiParts.primary_button("Done", func() -> void: queue_free()))
	_draw()


## The choices this party can change after a rest: [{ch, choice}]. After a Long Rest, prepared spells and choices
## a Long Rest lets you swap (Weapon Mastery, Echoing Soul's Expertise); after either rest, those a Short Rest lets you
## swap (Whispers of the Dead). `rest` is "long_rest" or "short_rest".
static func preparable(state: StoryState, rest: String = "long_rest") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch in state.party:
		if ch.dead:
			continue
		for rc in ch.choice_defs:
			if rc.key.ends_with(".prepared") or rc.kind in ["spell", "cantrip", "spellbook"]:
				continue
			if rc.replaceable == "short_rest" or (rc.replaceable == "long_rest" and rest == "long_rest"):
				out.append({"ch": ch, "choice": rc})
		if rest != "long_rest":
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
	var list := PrepareScreen.preparable(st, rest_kind)
	if list.is_empty():
		_box.add_child(UiKit.label("Nobody in the party prepares spells after a rest.", 15, "parchment"))
	for entry in list:
		var ch := entry["ch"] as Character
		var c := entry["choice"] as Choice
		ChoiceOptions.populate(c, ch)
		var what := Compendium.shared().display_name("classes", c.class_id) if c.key.ends_with(".prepared") else c.label
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 44.0))
		var sec := UiParts.section("%s · %s" % [ch.name, what])
		sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sec)
		_box.add_child(head)
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
