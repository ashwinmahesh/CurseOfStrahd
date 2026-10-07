class_name SkirmishResults
extends CanvasLayer
## The end of a Skirmish fight (N1): who won, in how many rounds, and what each hero and foe did (FightTally:
## damage dealt and taken, kills, Critical Hits, natural 20s and 1s, falls), then Fight again, Change the setup (or
## Esc), or back to the title.

signal again
signal change_setup
signal to_title

const COLUMNS: Array[Array] = [["damage_dealt", "Dealt"], ["damage_taken", "Taken"], ["kills", "Kills"],
	["crits", "Crits"], ["hits", "Hits"], ["misses", "Misses"], ["nat20", "20s"], ["nat1", "1s"], ["downs", "Falls"]]

var tally: Dictionary = {}


func _init() -> void:
	name = "SkirmishResults"
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_for(e: Encounter, title: String) -> void:
	tally = FightTally.tally(e)
	var won := e.outcome == "victory"
	var head := e.legendary.end_title()
	if head == "":
		head = "Victory" if won else "The party has fallen"
	var frame := UiKit.screen_frame(self, head, Vector2(1160, 700))
	var sub := UiKit.label("%s · %d round%s" % [title, e.round_no, "" if e.round_no == 1 else "s"], 17, "parchment")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(sub)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.add_child(UiParts.section("The party"))
	body.add_child(_table(FightTally.side_rows(e, tally, "party"), e, true))
	body.add_child(UiParts.section("The foes"))
	body.add_child(_table(FightTally.side_rows(e, tally, "enemy"), e, false))
	var pane := UiParts.pane(12)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(body))
	frame.add_child(pane)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var go := UiParts.primary_button("Fight again", func() -> void: again.emit())
	go.name = "FightAgain"
	row.add_child(go)
	row.add_child(UiKit.button("Change the setup", func() -> void: change_setup.emit(), 17))
	row.add_child(UiKit.button("Back to the title", func() -> void: to_title.emit(), 17))
	frame.add_child(row)
	go.grab_focus.call_deferred()


func _table(rows: Array[Dictionary], e: Encounter, party: bool) -> Control:
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size() + 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	grid.add_child(UiKit.label("", 13, "parchment"))
	grid.add_child(UiKit.label("", 13, "parchment"))
	for col in COLUMNS:
		var h := UiParts.caption(str(col[1]).to_upper(), 12, "gilt")
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(h)
	for r in rows:
		var c := _combatant(e, str(r["name"]))
		var state := "standing"
		if int(r["died"]) > 0:
			state = "dead"
		elif c != null and c.creature.hp <= 0:
			state = "down"
		var nm := UiKit.label(str(r["name"]), 15, "gilt_light" if party else "vellum")
		nm.custom_minimum_size = Vector2(220, 0)
		grid.add_child(nm)
		var hp := "%d / %d HP" % [c.creature.hp, c.creature.max_hp()] if c != null and state == "standing" else state
		grid.add_child(UiKit.label(hp, 13, "parchment" if state == "standing" else "vampire_red"))
		for col in COLUMNS:
			var v := int(r[str(col[0])])
			var f := UiParts.figure(str(v), 16, "ivory" if v > 0 else "bone_dark")
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			f.custom_minimum_size = Vector2(52, 0)
			grid.add_child(f)
	return grid


## Esc goes back to the setup.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		change_setup.emit()


static func _combatant(e: Encounter, nm: String) -> Combatant:
	for c in e.combatants:
		if c.name() == nm:
			return c
	return null
