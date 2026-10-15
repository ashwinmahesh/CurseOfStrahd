class_name PrepareScreen
extends CanvasLayer
## Changing prepared spells after a Long Rest (2024 PHB): Clerics, Druids and Wizards (from the spellbook) may change
## any number, Paladins and Rangers one spell, and a Wizard one cantrip too (a High Elf their lineage's); Bards, Sorcerers and Warlocks change one
## when they gain a level (LevelUpController). Weapon Mastery too: Barbarians and Fighters swap one kind, Paladins,
## Rangers and Rogues any; a Druid one Wild Shape form. One choice box per caster, the same widget character creation uses;
## each change rebuilds the character at once. The limits count from the list the rest ended with (`earlier`), so
## closing and reopening the screen doesn't give a second swap.
##
## Outside a fight (owner's house rule, deviations.md) the spells a Long Rest lets a caster change can be changed at any
## time, no rest needed: `rest_kind` ANYTIME. The Prepare Spells screen then offers only spells (prepared lists, a
## Wizard's or High Elf's cantrip, the Circle of the Land's land), any number at once, from the character sheet, the
## rest screen and the camp's bar. Weapon Mastery and the other rest-only choices wait for a rest.

## `rest_kind` for the swap any time outside a fight (see the top).
const ANYTIME := "anytime"
const INTRO_ANYTIME := "Between fights you can change what each caster has ready, no rest needed: Clerics, Druids, Wizards, Paladins and Rangers their prepared spells, Wizards and High Elves a cantrip, a Circle of the Land Druid their land. Spell slots already spent stay spent, and spells already cast keep going. Always-prepared spells (a domain's, an oath's) can't change. Hover a spell for what it does."

var root: Node
var st: StoryState
var _box: VBoxContainer
## Which rest just ended: "long_rest" or "short_rest" (see preparable()), or ANYTIME for no rest at all.
var rest_kind := "long_rest"
## ANYTIME only: the one character the screen is for (opened from their sheet), or null for the whole party.
var only: Character = null
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
	if rest_kind == ANYTIME:
		frame.add_child(UiKit.label(INTRO_ANYTIME, 15, "parchment", 1220))
	else:
		frame.add_child(UiKit.label("After a Long Rest, choose which spells each caster has ready: Clerics, Druids and Wizards can change any of theirs, Paladins and Rangers one, and Wizards and High Elves one cantrip too. Barbarians and Fighters swap one Weapon Mastery; Paladins, Rangers and Rogues any. Druids swap one Wild Shape form. Always-prepared spells (a domain's, an oath's) don't count. You can also change your spells at any time outside a fight, from the character sheet. Hover a spell for what it does.", 15, "parchment", 1220))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	var pane := UiParts.pane(14)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(_box))
	frame.add_child(pane)
	frame.add_child(UiParts.primary_button("Done", func() -> void: queue_free()))
	if rest_kind != ANYTIME and earlier.is_empty():
		earlier = PrepareScreen.snapshot(st, rest_kind)
	_draw()


## The choices this party can change after a rest: [{ch, choice}]. After a Long Rest, prepared spells and choices
## a Long Rest lets you swap (Weapon Mastery, Echoing Soul's Expertise); after either rest, those a Short Rest lets you
## swap (Whispers of the Dead). `rest` is "long_rest" or "short_rest", or ANYTIME: only the spells a Long Rest lets you
## change, with no rest needed (see the top). `who` limits the list to one character.
static func preparable(state: StoryState, rest: String = "long_rest", who: Character = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ch in state.party:
		if ch.dead or (who != null and ch != who):
			continue
		if rest == ANYTIME:
			for c in anytime_choices(ch):
				out.append({"ch": ch, "choice": c})
			continue
		for rc in ch.choice_defs:
			if rc.key.ends_with(".prepared") or rc.kind in ["spell", "cantrip", "spellbook"]:
				continue
			if rc.replaceable == "short_rest" or (rc.replaceable == "long_rest" and rest == "long_rest"):
				out.append({"ch": ch, "choice": rc})
		if rest != "long_rest":
			continue
		for c in PrepareScreen._spell_lists(ch):
			if c.replaceable == "long_rest":
				out.append({"ch": ch, "choice": c})
	return out


## The class lists a Long Rest lets you change: prepared spells (Cleric, Druid, Paladin, Ranger, Wizard), then cantrips
## (Wizard), then other spells a Long Rest lets you swap (a High Elf's cantrip). Whatever else holds spell picks comes
## after, so a caller keeps those that are `replaceable` on a Long Rest.
static func _spell_lists(ch: Character) -> Array[Choice]:
	var lists: Array[Choice] = []
	for e in ch.spellcasting:
		for list: String in ["prepared", "cantrips"]:
			var c := ch.choice("%s.%s" % [e["class_id"], list])
			if c != null:
				lists.append(c)
	for rc in ch.choice_defs:
		if rc.kind in ["spell", "cantrip"] and not rc in lists:
			lists.append(rc)
	return lists


## What `ch` can change any time outside a fight: each spell list a Long Rest lets them change (Bards, Sorcerers and
## Warlocks change theirs at a level up, so they have none), and a feature whose Long Rest choice grants spells
## (the Circle of the Land's land, a Scion of the Three's allegiance). A domain's or oath's always-prepared spells
## aren't picks, so they never appear here.
static func anytime_choices(ch: Character) -> Array[Choice]:
	var out: Array[Choice] = []
	if ch.dead:
		return out
	for c in PrepareScreen._spell_lists(ch):
		if c.replaceable == "long_rest":
			out.append(c)
	for rc in ch.choice_defs:
		if rc.kind == "option" and rc.replaceable == "long_rest" and PrepareScreen._grants_spells(rc):
			out.append(rc)
	return out


## Whether any of the choice's options grants a spell (a `spell` modifier).
static func _grants_spells(c: Choice) -> bool:
	for o in c.inline_options:
		for m: Variant in o.get("modifiers", []):
			if str((m as Dictionary).get("stat", "")) == "spell":
				return true
	return false


## Why spells can't be changed now ("" when they can): not in a fight.
static func refusal(in_fight: bool) -> String:
	return "Prepared spells can't be changed in a fight." if in_fight else ""


## Whether a fight is on in the location `root` (the game) shows.
static func fighting(root_: Node) -> bool:
	if root_ == null or not "view" in root_:
		return false
	var view: Variant = root_.get("view")
	if not is_instance_valid(view):
		return false
	return view is LocationView and (view as LocationView).in_combat


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
	var anytime := rest_kind == ANYTIME
	var why := PrepareScreen.refusal(PrepareScreen.fighting(root)) if anytime else ""
	var list := PrepareScreen.preparable(st, rest_kind, only) if why == "" else ([] as Array[Dictionary])
	if why != "":
		_box.add_child(UiKit.label(why, 15, "rose"))
	elif list.is_empty():
		var nobody := "Nobody in the party prepares spells after a rest."
		if anytime:
			nobody = "%s prepares no spells." % only.name.get_slice(" ", 0) if only != null else "Nobody in the party prepares spells."
		_box.add_child(UiKit.label(nobody, 15, "parchment"))
	for entry in list:
		var ch := entry["ch"] as Character
		var c := entry["choice"] as Choice
		if anytime:
			ChoiceOptions.close_swap(c)   # no rest to count from: any number can change
		else:
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
	for entry in PrepareScreen.preparable(st, rest_kind, only):
		ChoiceOptions.close_swap(entry["choice"] as Choice)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
