extends "res://tools/capture/combat_hud_capture.gd"
## make capture SCENE=res://tools/capture/hotbar_mockup_capture.tscn NAME=hotbar_mockup FRAMES=10
## A mock-up of Baldur's Gate 3's PC hotbar for the owner to compare with the tabs (Combat HUD plan, idea 7, asked for
## 2026-10-09): every action in one bar of icon-only slots in long rows, Common, class, Spells and Items one after
## another with a gilt line between, category filters down the left, the name and numbers on hover. Capture only: the
## game's bar is unchanged.

const SIDE := 44.0
const COLUMNS := 18


func capture_shots(tool: Node, out: String) -> void:
	await tool.call("wait_frames", 150)
	var shots: Array = [["ilse_varga", "1_ilse"], ["godrick_pendlebrook", "2_godrick"], ["tamsin_tealeaf", "3_tamsin"]]
	for shot: Variant in shots:
		var s := shot as Array
		var c := heroes[str(s[0])] as Combatant
		if e.current() != c:
			e.turn_index = e.order.find(c)
			e._begin_turn()
		view.hud.shown = c
		view.hud.set_tab(ActionCatalog.COMMON)
		view.hud.refresh()
		var bar := _mock_bar(c)
		await tool.call("wait_frames", 8)
		# A hover on the first slot: the name and the numbers come up in the tooltip, as in Baldur's Gate 3.
		var first := bar.get_meta(&"first") as Dictionary
		var at := (bar.get_meta(&"first_button") as Control).get_global_rect().position
		view.hud.show_tooltip("%s · %s" % [first["label"], CombatHud._cost_word(str(first["cost"]))], [str(first["sub"]), str(first["help"]).get_slice(".", 0)], [],
			at + Vector2(-20, -150))
		await tool.call("wait_frames", 4)
		tool.call("_shot", "%s_%s.png" % [out, str(s[1])])
		view.hud.hide_tooltip()
		bar.queue_free()


## The mock bar in place of the tabs and the slot rows.
func _mock_bar(c: Combatant) -> Control:
	var hud := view.hud
	var tabs := hud.get("_tabs") as Control
	var scroll := hud.get("_slot_scroll") as Control
	tabs.visible = false
	scroll.visible = false
	var mid := tabs.get_parent()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mid.add_child(row)
	mid.move_child(row, tabs.get_index())
	# Category filters down the left, BG3's way: everything, then one kind at a time.
	var filters := VBoxContainer.new()
	filters.add_theme_constant_override("separation", 1)
	for f: String in ["All", "Attacks", "Class", "Spells", "Items", "Reactions"]:
		var b := Button.new()
		b.text = f
		b.custom_minimum_size = Vector2(78, 20)
		b.add_theme_font_size_override("font_size", 10)
		UiKit.button_look(b)
		UiParts.compact(b)
		if f == "All":
			UiParts.light_up(b)
		filters.add_child(b)
	row.add_child(filters)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	row.add_child(grid)
	var cat := view.catalog
	var tabs_in_order: Array[String] = [ActionCatalog.COMMON, cat.class_tab(c), ActionCatalog.SPELLS, ActionCatalog.ITEMS]
	var n := 0
	for t in tabs_in_order:
		if not t in cat.tabs_for(c):
			continue
		var slots := cat.slots(c, t)
		if slots.is_empty():
			continue
		# A section starts on a fresh column after a gilt line, like the bar's own dividers.
		if n > 0:
			grid.add_child(_divider())
			n += 1
		for a in slots:
			if n >= COLUMNS * 3:
				break
			var b := _icon_slot(a, n, c)
			grid.add_child(b)
			if n == 0:
				row.set_meta(&"first", a)
				row.set_meta(&"first_button", b)
			n += 1
	return row


func _divider() -> Control:
	var d := UiParts.drawn(Vector2(SIDE, SIDE), func(cv: Control) -> void:
		cv.draw_line(Vector2(cv.size.x / 2.0, 4), Vector2(cv.size.x / 2.0, cv.size.y - 4), Look.color("gilt"), 2.0))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## One icon-only slot: the icon, its number in the corner, the cost shape at the top right, greyed when it can't be used.
func _icon_slot(a: Dictionary, i: int, c: Combatant) -> Control:
	var usable := bool(a["legal"]) and e.current() == c
	var b := Button.new()
	b.custom_minimum_size = Vector2(SIDE, SIDE)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Look.color("ui_oxblood" if usable else "ui_black"), 0.95)
	st.border_color = Look.color("gilt_dark" if not bool(a.get("armed", false)) else "gilt_light")
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", st)
	var tex := UiParts.action_icon(a)
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(4, 4)
		ic.size = Vector2(SIDE - 8, SIDE - 8)
		ic.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.35)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	else:
		var l := Label.new()
		l.text = str(a["label"]).substr(0, 3)
		l.position = Vector2(6, 12)
		l.add_theme_font_size_override("font_size", 13)
		b.add_child(l)
	var colour := str(CombatHud.COST_COLOURS.get(str(a["cost"]), "slate"))
	var mark := UiParts.drawn(Vector2(SIDE, SIDE), func(cv: Control) -> void:
		CombatHud._cost_mark(cv, Vector2(cv.size.x - 8.0, 8.0), str(a["cost"]), Look.color(colour) if usable else Color(Look.color(colour), 0.4)))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(mark)
	if i < 10:
		var key := Label.new()
		key.text = str((i + 1) % 10)
		key.position = Vector2(3, SIDE - 17)
		key.add_theme_font_size_override("font_size", 11)
		key.add_theme_color_override("font_color", Look.color("gilt_light"))
		key.add_theme_color_override("font_outline_color", Look.color("void"))
		key.add_theme_constant_override("outline_size", 4)
		b.add_child(key)
	return b
