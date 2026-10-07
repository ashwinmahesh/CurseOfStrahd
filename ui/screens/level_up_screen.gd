class_name LevelUpScreen
extends CanvasLayer
## Level up (docs/ui/level_up.md, plan §5.6): choose the class to advance (multiclass prerequisites explained), Hit
## Points (roll on screen or take the fixed value), the new features (summary on the page, full text on hover), every
## choice the level grants (the same widgets as creation, picked by kind), then a before/after summary and Confirm,
## with the live sheet beside it marking what changes. Nothing changes until Confirm. Milestone levelling: available
## when the story has reached the next milestone.

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
	var frame := UiKit.screen_frame(self, "Level Up", Vector2(1500, 840))
	if not st.can_level_up(ch):
		frame.add_child(UiKit.label("%s has reached the level the story allows (%d). Milestones raise it." % [ch.name, st.target_level()], 17, "parchment", 1400))
		return
	ctl = LevelUpController.new(ch)
	var main_class := ch.class_order[0] if not ch.class_order.is_empty() else ""
	ctl.choose_class(main_class)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(row)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	var body_pane := UiParts.pane(14)
	body_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pane.add_child(UiParts.fill_scroll(_body))
	row.add_child(body_pane)
	_sheet = VBoxContainer.new()
	var side := UiParts.fill_scroll(_sheet)
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(side)
	_redraw()


func _redraw() -> void:
	for c in _body.get_children():
		c.queue_free()
	for c in _sheet.get_children():
		c.queue_free()
	_sheet.add_child(LiveSheet.build(ctl.preview(), ch))
	# Several levels waiting (back from camp, or made after the party had levelled): which one this is.
	var waiting := st.levels_waiting(ch)
	if waiting > 1:
		var more := "%d more wait" % (waiting - 1) if waiting > 2 else "1 more waits"
		_body.add_child(UiParts.row(UiKit.label("Level %d for %s; %s after it, up to the party's level %d." % [ch.character_level() + 1,
			ch.name.get_slice(" ", 0), more, st.target_level()], 15, "gilt_light", 1000)))
	# 1. Class
	_body.add_child(UiParts.section("1 · Class to advance"))
	var classes := HFlowContainer.new()
	classes.add_theme_constant_override("h_separation", 6)
	classes.add_theme_constant_override("v_separation", 6)
	for o in ctl.available_classes():
		var label := o.label
		var summary := o.summary
		var why := "" if o.legal else "Can't: " + o.reason
		var b := UiParts.tip_button(o.label, func() -> void:
			ctl.choose_class(o.id)
			_hp_note = ""
			_redraw(), func() -> Control: return UiParts.rules_tip(label, "", summary, [], why), o.id == ctl.chosen_class, 15)
		b.disabled = not o.legal
		classes.add_child(b)
	_body.add_child(classes)
	# 2. Hit Points
	var hp := ctl.hit_point_options()
	_body.add_child(UiParts.section("2 · Hit Points"))
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	var fixed := UiKit.button("Take the fixed %d + Con %s" % [int(hp["fixed"]), UiKit.signed(int(hp["con"]))], func() -> void:
		ctl.take_fixed_hit_points()
		_hp_note = "Fixed: %d + %d" % [int(hp["fixed"]), int(hp["con"])]
		_redraw(), 15)
	hp_row.add_child(fixed)
	hp_row.add_child(UiKit.button("Roll a d%d" % int(hp["die"]), func() -> void:
		var r := ctl.roll_hit_points(Dice.roller)
		_hp_note = "Rolled %d on the d%d, + Con %d (minimum 1)" % [r, int(hp["die"]), int(hp["con"])]
		_redraw(), 15, "rest"))
	hp_row.add_child(UiParts.gap())
	hp_row.add_child(UiKit.label(_hp_note if _hp_note != "" else "Fixed value unless you roll", 15, "gilt_light"))
	_body.add_child(UiParts.row(hp_row))
	# 3. Features
	_body.add_child(UiParts.section("3 · New features"))
	var feats := ctl.new_features()
	if feats.is_empty():
		_body.add_child(UiKit.label("No new features at this level; the choices below are what it brings.", 14, "bone"))
	for f in feats:
		_body.add_child(UiParts.feature_row(f, str(f.get("source", "")), 1000.0))
	# 4. Choices
	var choices := ctl.level_choices()
	if not choices.is_empty():
		_body.add_child(UiParts.section("4 · Choices"))
	for c in choices:
		var w := ChoiceWidget.create(c)
		w.picks_changed.connect(func(key: String, picks: Array) -> void:
			ctl.choose(key, picks)
			_redraw())
		_body.add_child(w)
	# 5. Summary
	_body.add_child(UiParts.section("5 · Summary"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	for r in ctl.changes():
		grid.add_child(UiKit.label(str(r["label"]), 15, "parchment"))
		grid.add_child(UiKit.label(str(r["before"]), 15, "bone"))
		grid.add_child(UiKit.label("→", 15, "gilt"))
		grid.add_child(UiKit.label(str(r["after"]), 16, "gilt_light"))
	if grid.get_child_count() > 0:
		_body.add_child(UiParts.row(grid))
	else:
		grid.free()
	for w2 in ctl.warnings():
		_body.add_child(UiKit.label("~ " + w2, 14, "gilt", 1000))
	var errs := ctl.errors()
	for e in errs:
		_body.add_child(UiKit.label("! " + e, 14, "vampire_red", 1000))
	var confirm := UiParts.primary_button("Confirm level %d" % (ch.character_level() + 1), _confirm)
	confirm.disabled = not errs.is_empty()
	_body.add_child(confirm)


func _confirm() -> void:
	Audio.sfx("level_up")
	if ctl.confirm():
		# Levels missed at camp wait (owner, 2026-10-07): the next one opens straight away, in order.
		if st.can_level_up(ch):
			root.call("open_screen", "level_up", st.party.find(ch))
		else:
			root.call("close_screen")
