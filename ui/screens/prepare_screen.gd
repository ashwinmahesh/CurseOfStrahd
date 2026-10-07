class_name PrepareScreen
extends CanvasLayer
## Changing prepared spells after a Long Rest (2024 PHB): Clerics, Druids and Wizards (from the spellbook) may change
## any number, Paladins and Rangers one spell, and a Wizard one cantrip too (a High Elf their lineage's); Bards, Sorcerers and Warlocks change one
## when they gain a level (LevelUpController). Weapon Mastery too: Barbarians and Fighters swap one kind, Paladins,
## Rangers and Rogues any; a Druid one Wild Shape form. One choice box per caster, the same widget character creation uses;
## each change rebuilds the character at once. The limits count from the list the rest ended with (`earlier`), so
## closing and reopening the screen doesn't give a second swap.

var root: Node
var st: StoryState
var _box: VBoxContainer
## Which rest just ended: "long_rest" or "short_rest" (see preparable()).
var rest_kind := "long_rest"
## snapshot() of the party's picks when the rest ended; taken at open() when the opener leaves it empty.
var earlier: Dictionary = {}


func _init() -> void:
	name = "PrepareScreen"
	layer = 32


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Prepare Spells", Vector2(1300, 820))
	# The intro runs the frame's full width, so it starts below the crest hanging under the title.
	var clear := Control.new()
	clear.custom_minimum_size = Vector2(0, 8)
	frame.add_child(clear)
	frame.add_child(UiKit.label("After a Long Rest, choose which spells each caster has ready: Clerics, Druids and Wizards can change any of theirs, Paladins and Rangers one, and Wizards and High Elves one cantrip too. Barbarians and Fighters swap one Weapon Mastery; Paladins, Rangers and Rogues any. Druids swap one Wild Shape form. Always-prepared spells (a domain's, an oath's) don't count. Hover a spell for what it does.", 15, "parchment", 1220))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_box))
	frame.add_child(pane)
	frame.add_child(UiParts.primary_button("Done", func() -> void: queue_free()))
	if earlier.is_empty():
		earlier = PrepareScreen.snapshot(st, rest_kind)
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
		# The class lists a Long Rest lets you change: prepared spells (Cleric, Druid, Paladin, Ranger, Wizard), then
		# cantrips (Wizard), then other spells a Long Rest lets you swap (a High Elf's cantrip).
		var lists: Array[Choice] = []
		for e in ch.spellcasting:
			for list: String in ["prepared", "cantrips"]:
				var c := ch.choice("%s.%s" % [e["class_id"], list])
				if c != null:
					lists.append(c)
		for rc2 in ch.choice_defs:
			if rc2.kind in ["spell", "cantrip"] and not rc2 in lists:
				lists.append(rc2)
		for c in lists:
			if c.replaceable == "long_rest":
				out.append({"ch": ch, "choice": c})
	return out


## Every preparable() choice's picks right now, keyed "<character id>/<choice key>": the list a swap limit counts from.
static func snapshot(state: StoryState, rest: String = "long_rest") -> Dictionary:
	var out := {}
	for entry in PrepareScreen.preparable(state, rest):
		var c := entry["choice"] as Choice
		out["%s/%s" % [(entry["ch"] as Character).id, c.key]] = c.picks.duplicate()
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
		var from: Array[String] = []
		from.assign(earlier.get("%s/%s" % [ch.id, c.key], c.picks) as Array)
		ChoiceOptions.open_swap(c, from, rest_kind)
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


## The swap chance closes with the screen, so the characters' own choices go back to free picks.
func _exit_tree() -> void:
	if st == null:
		return
	for entry in PrepareScreen.preparable(st, rest_kind):
		ChoiceOptions.close_swap(entry["choice"] as Choice)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
