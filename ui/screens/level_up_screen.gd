class_name LevelUpScreen
extends CanvasLayer
## Level up (docs/ui/level_up.md, plan §5.6): choose the class to advance (multiclass prerequisites explained), Hit
## Points (roll on screen or take the fixed value), the new features with their text, every choice the level grants
## (the same widgets as creation, picked by kind), then a before/after summary and Confirm. Nothing changes until
## Confirm. Milestone levelling: available when the story has reached the next milestone.

var root: Node
var st: StoryState
var ch: Character
var ctl: LevelUpController
var _body: VBoxContainer
var _sheet: VBoxContainer
var _hp_note := ""


func _init() -> void:
	name = "LevelUpScreen"
	layer = 30


func open(root_: Node, state: StoryState, index: int) -> void:
	root = root_
	st = state
	ch = st.party[clampi(index, 0, st.party.size() - 1)]
	var frame := UiKit.screen_frame(self, "Level up: %s" % ch.name, Vector2(1500, 840))
	if not st.can_level_up(ch):
		frame.add_child(UiKit.label("%s has reached the level the story allows (%d). Milestones raise it." % [ch.name, st.target_level()], 17, "parchment", 1400))
		return
	ctl = LevelUpController.new(ch)
	var main_class := ch.class_order[0] if not ch.class_order.is_empty() else ""
	ctl.choose_class(main_class)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	frame.add_child(row)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.scroll(_body, Vector2(1060, 740)))
	_sheet = VBoxContainer.new()
	row.add_child(UiKit.scroll(_sheet, Vector2(360, 740)))
	_redraw()


func _redraw() -> void:
	for c in _body.get_children():
		c.queue_free()
	for c in _sheet.get_children():
		c.queue_free()
	_sheet.add_child(LiveSheet.build(ctl.preview(), ch))
	# 1. Class
	_body.add_child(UiKit.header("1 · Class to advance"))
	var classes := HBoxContainer.new()
	for o in ctl.available_classes():
		var b := UiKit.button(("▸ " if o.id == ctl.chosen_class else "") + o.label, func() -> void:
			ctl.choose_class(o.id)
			_hp_note = ""
			_redraw(), 14)
		b.disabled = not o.legal
		b.tooltip_text = o.summary + ("" if o.legal else "\nCan't: " + o.reason)
		classes.add_child(b)
	_body.add_child(classes)
	# 2. Hit Points
	var hp := ctl.hit_point_options()
	_body.add_child(UiKit.header("2 · Hit Points"))
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	hp_row.add_child(UiKit.button("Take the fixed %d + Con %s" % [int(hp["fixed"]), UiKit.signed(int(hp["con"]))], func() -> void:
		ctl.take_fixed_hit_points()
		_hp_note = "Fixed: %d + %d" % [int(hp["fixed"]), int(hp["con"])]
		_redraw(), 14))
	hp_row.add_child(UiKit.button("Roll a d%d" % int(hp["die"]), func() -> void:
		var r := ctl.roll_hit_points(Dice.roller)
		_hp_note = "Rolled %d on the d%d, + Con %d (minimum 1)" % [r, int(hp["die"]), int(hp["con"])]
		_redraw(), 14))
	hp_row.add_child(UiKit.label(_hp_note if _hp_note != "" else "Fixed value unless you roll", 15, "gilt_light"))
	_body.add_child(hp_row)
	# 3. Features
	_body.add_child(UiKit.header("3 · New features"))
	for f in ctl.new_features():
		_body.add_child(UiKit.label("%s (%s)" % [f["name"], f["source"]], 16, "gilt_light"))
		_body.add_child(UiKit.label(str(f["text"]) if str(f["text"]) != "" else str(f["summary"]), 14, "vellum", 1000))
	# 4. Choices
	var choices := ctl.level_choices()
	if not choices.is_empty():
		_body.add_child(UiKit.header("4 · Choices"))
	for c in choices:
		var w := ChoiceWidget.create(c)
		w.picks_changed.connect(func(key: String, picks: Array) -> void:
			ctl.choose(key, picks)
			_redraw())
		_body.add_child(w)
	# 5. Summary
	_body.add_child(UiKit.header("5 · Summary"))
	for r in ctl.changes():
		_body.add_child(UiKit.label("%s: %s → %s" % [r["label"], r["before"], r["after"]], 15, "vellum", 1000))
	for w2 in ctl.warnings():
		_body.add_child(UiKit.label("~ " + w2, 14, "gilt", 1000))
	var errs := ctl.errors()
	for e in errs:
		_body.add_child(UiKit.label("! " + e, 14, "vampire_red", 1000))
	var confirm := UiKit.button("Confirm level %d" % (ch.character_level() + 1), _confirm, 18)
	confirm.disabled = not errs.is_empty()
	_body.add_child(confirm)


func _confirm() -> void:
	if ctl.confirm():
		root.call("close_screen")
