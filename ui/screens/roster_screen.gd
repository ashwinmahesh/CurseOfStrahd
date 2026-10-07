class_name RosterScreen
extends CanvasLayer
## Who travels (owner, 2026-10-06): the party (up to StoryState.PARTY_CAP) and the rest of the roster at camp, with
## send to camp, bring along, and swap (pick someone at camp, then whose place they take). Opened from the party
## screen outside fights and conversations; the world swaps the figures as soon as the party changes. Those at camp
## don't fight or speak in the story, and catch up on levels when they rejoin.

var root: Node
var st: StoryState
var _frame: VBoxContainer
## Someone at camp, picked to take a party member's place.
var _picked: Character = null


func _init() -> void:
	name = "RosterScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	_frame = UiKit.screen_frame(self, "Who travels", Vector2(1320, 780))
	_draw()


func _draw() -> void:
	for c in _frame.get_children():
		c.queue_free()
	_frame.add_child(UiParts.section("In the party (%d of %d)" % [st.party.size(), StoryState.PARTY_CAP]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for ch in st.party:
		row.add_child(_card(ch, true))
	_frame.add_child(row)
	_frame.add_child(UiParts.section("At camp"))
	if st.bench.is_empty():
		_frame.add_child(UiKit.label("Everyone is on the road.", 15, "parchment"))
	else:
		var camp := HBoxContainer.new()
		camp.add_theme_constant_override("separation", 12)
		for ch in st.bench:
			camp.add_child(_card(ch, false))
		_frame.add_child(camp)
	var note := "Those at camp don't fight or speak in the story. They catch up on levels when they rejoin."
	if _picked != null:
		note = "Choose whose place %s takes." % _picked.name.get_slice(" ", 0)
	_frame.add_child(UiKit.label(note, 14, "gilt" if _picked != null else "parchment", 1200))
	var foot := HBoxContainer.new()
	foot.add_child(UiParts.gap())
	foot.add_child(UiParts.primary_button("Done", func() -> void: root.call("close_screen")))
	_frame.add_child(UiParts.gap())
	_frame.add_child(foot)


func _card(ch: Character, travelling: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(280, 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 84.0, ch.hp <= 0, ch.dead))
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	var n := UiKit.label(ch.name, 19, "gilt_light")
	n.add_theme_font_override("font", UiKit.display_font())
	who.add_child(n)
	who.add_child(UiKit.label(ch.class_summary(), 13, "parchment", 170))
	var lvl := ch.character_level()
	var behind := travelling == false and lvl < st.target_level()
	who.add_child(UiKit.label("Level %d%s" % [lvl, " (catches up on rejoining)" if behind else ""], 13, "vellum", 170))
	head.add_child(who)
	col.add_child(head)
	col.add_child(UiParts.hp_bar(ch, 260.0, 16.0, false))
	if travelling:
		if _picked != null:
			var swap := UiParts.small_button("%s takes this place" % _picked.name.get_slice(" ", 0), func() -> void:
				var incoming := _picked
				_picked = null
				if st.swap_members(ch, incoming):
					_changed())
			UiParts.light_up(swap)
			col.add_child(swap)
		else:
			var camp := UiParts.small_button("Send to camp", func() -> void:
				if st.send_to_camp(ch):
					_changed())
			camp.disabled = st.party.size() <= 1
			camp.tooltip_text = "" if st.party.size() > 1 else "Somebody has to stay on the road."
			col.add_child(camp)
	else:
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		if st.party.size() < StoryState.PARTY_CAP:
			buttons.add_child(UiParts.small_button("Bring along", func() -> void:
				if st.bring_along(ch):
					_changed()))
		var pick := UiParts.small_button("Swap in" if _picked != ch else "Cancel", func() -> void:
			_picked = null if _picked == ch else ch
			_draw())
		if _picked == ch:
			UiParts.light_up(pick)
		pick.disabled = ch.dead
		buttons.add_child(pick)
		col.add_child(buttons)
	var card := UiParts.card("ui_black" if travelling else "ui_oxblood", "gilt" if travelling else "gilt_dark", 0.85, 10)
	card.add_child(col)
	return card


## The party changed: the world swaps the figures, and the screen redraws.
func _changed() -> void:
	Audio.sfx("click")
	var view: Variant = root.get("view") if root != null else null
	if view != null and (view as Object).has_method("rebuild_party"):
		(view as Object).call("rebuild_party")
	_draw()
