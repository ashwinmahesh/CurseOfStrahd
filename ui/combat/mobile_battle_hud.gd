class_name MobileBattleHud
extends Control
## Mobile presentation of CombatHud's existing commands. Rules and reaction selection stay in CombatHud.

var hud: CombatHud
var desktop: Control
var header: HBoxContainer
var status: Button
var battle_menu: Button
var upcoming: Button
var notice: Label
var notice_time := 0.0
var preview: Button
var preview_title := ""
var preview_lines: Array = []
var area_lines: Array = []
var sheet: CanvasLayer
var page: MobilePage
var held: Control
var held_footer: Control
var footer_parent: Node
var kind := ""


func setup(owner_: CombatHud, desktop_: Control) -> void:
	hud = owner_
	desktop = desktop_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)
	status = MobileUi.button("Battle", overview)
	status.clip_text = true
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(status)
	battle_menu = MobileUi.button("Battle Menu", menu)
	battle_menu.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(battle_menu)
	upcoming = MobileUi.button("", order)
	add_child(upcoming)
	notice = MobileUi.text("")
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.hide()
	add_child(notice)
	preview = MobileUi.button("", preview_page)
	preview.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.visible = false
	add_child(preview)
	get_viewport().size_changed.connect(reflow)
	if MobileDevice.current != null:
		MobileDevice.current.geometry_changed.connect(reflow)
	reflow()


func reflow() -> void:
	var safe := MobileDevice.safe_rect().grow(-4)
	header.position = safe.position
	header.size = Vector2(minf(370.0, safe.size.x - 180.0), 0)
	battle_menu.size = Vector2(164, 48)
	battle_menu.position = Vector2(safe.end.x - battle_menu.size.x, safe.position.y)
	upcoming.visible = not MobileDevice.compact()
	upcoming.position = Vector2(safe.end.x - 250, safe.position.y + 56)
	upcoming.size = Vector2(250, 0)
	notice.position = Vector2(safe.position.x, safe.position.y + 104)
	notice.size = Vector2(minf(460, safe.size.x), 0)
	preview.size = Vector2(minf(460, safe.size.x), 48)
	preview.position = Vector2(safe.get_center().x - preview.size.x / 2, safe.end.y - 108)


func refresh() -> void:
	var c := hud.e.current()
	if c == null:
		status.text = "Battle"
		return
	status.text = "%s · Round %d\nHP %d/%d · Move %d ft\nAction %s · Bonus %s · Reaction %s" % [
		c.name().get_slice(" ", 0), hud.e.round_no, c.creature.hp, c.creature.max_hp(), c.movement_left,
		"✓" if c.action_available else "—", "✓" if c.bonus_available else "—", "✓" if c.reaction_available else "—"]
	status.tooltip_text = c.name() + " · Party, conditions and resources"
	var next_names: Array[String] = []
	for offset in range(1, mini(4, hud.e.order.size())):
		var next := hud.e.order[posmod(hud.e.order.find(c) + offset, hud.e.order.size())]
		if hud.viewer == null or hud.e.can_see(hud.viewer, next):
			next_names.append(next.name())
	upcoming.text = "Upcoming\n" + " · ".join(next_names)


func announce(text: String, seconds: float) -> void:
	notice.text = text
	notice.visible = text != ""
	notice_time = seconds


func _process(delta: float) -> void:
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			notice.hide()


func menu() -> void:
	var target := UiFeel.touch.world_target()
	var body := open_page("Battle Menu", "menu")
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 6)
	body.add_child(choices)
	choices.add_child(MobileUi.button("Party and resources", overview))
	choices.add_child(MobileUi.button("Turn order", order))
	choices.add_child(MobileUi.button("Combat log", log_page))
	choices.add_child(MobileUi.button("Controls and help", func() -> void: hud.toggle_controls()))
	if UiFeel.mobile_controls != null:
		var controls := UiFeel.mobile_controls
		choices.add_child(MobileUi.button("Camera", func() -> void:
			close()
			controls._camera(target)))
		choices.add_child(MobileUi.button("More controls", func() -> void:
			close()
			controls._more(target)))
	choices.add_child(MobileUi.button("Pause and settings", func() -> void:
		close()
		if UiFeel.mobile_controls != null:
			UiFeel.mobile_controls._menu()))


func open_page(title: String, page_kind: String = "details", back: Callable = close) -> VBoxContainer:
	close()
	kind = page_kind
	sheet = CanvasLayer.new()
	sheet.layer = 45
	sheet.set_meta(&"pad_scope", true)
	add_child(sheet)
	var body := MobilePage.build(sheet, title, back)
	page = body.get_parent().get_parent().get_parent() as MobilePage
	page.scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return body


func close() -> void:
	if held_footer != null:
		held_footer.reparent(footer_parent)
		held_footer = null
	if held != null:
		held.visible = false
		held.reparent(desktop)
		held = null
	if sheet != null:
		sheet.hide()
		sheet.queue_free()
		sheet = null
	page = null
	kind = ""
	if UiFeel.touch != null:
		UiFeel.touch.cancel()


## Retain the exact reaction widgets and callbacks, with only layout and typography changed.
func open_panel(panel: Control, title: String, page_kind: String, back: Callable, footer: Control = null) -> void:
	var body := open_page(title, page_kind, back)
	held = panel
	panel.reparent(body)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	MobileUi.fit(panel)
	panel.show()
	if footer != null:
		held_footer = footer
		footer_parent = footer.get_parent()
		footer.reparent(page.toolbar)


func details(title: String, lines: Array) -> void:
	var body := open_page(title)
	for line: Variant in lines:
		body.add_child(MobileUi.text(str(line)))


func examine(card: Dictionary, c: Combatant) -> void:
	var body := open_page(str(card["title"]))
	body.add_child(UiParts.framed_portrait(CombatToken.portrait_id(c), 72, c.is_down(), c.creature.dead))
	for key: String in ["subtitle", "summary"]:
		if str(card.get(key, "")) != "":
			body.add_child(MobileUi.text(str(card[key])))
	for section: Dictionary in card["sections"]:
		body.add_child(MobileUi.text(str(section["heading"]), "gilt_light"))
		for line: Variant in section["lines"]:
			body.add_child(MobileUi.text(str(line)))


func set_preview(title: String, lines: Array, warnings: Array) -> void:
	preview_title = title
	preview_lines = lines.duplicate()
	preview_lines.append_array(warnings)
	preview.text = title + " · Details"
	preview.show()


func preview_page() -> void:
	var lines := preview_lines.duplicate()
	lines.append_array(area_lines)
	details(preview_title, lines)


func overview() -> void:
	var body := open_page("Party and turn", "overview")
	for c in hud.e.combatants:
		if not c.is_player_controlled():
			continue
		body.add_child(MobileUi.text("%s · HP %d/%d · AC %d" % [c.name(), c.creature.hp, c.creature.max_hp(), c.creature.ac_value()], "gilt_light"))
		body.add_child(MobileUi.text("Action: %s · Bonus: %s · Reaction: %s · Movement: %d ft" % [
			"ready" if c.action_available else "spent", "ready" if c.bonus_available else "spent",
			"ready" if c.reaction_available else "spent", c.movement_left]))
		body.add_child(MobileUi.button("Select " + c.name(), func() -> void:
			close()
			hud.inspect_requested.emit(c.id)))
		body.add_child(MobileUi.button("Character sheet", func() -> void:
			close()
			hud.sheet_requested.emit(c.id)))
	if hud.death_save_shown():
		body.add_child(MobileUi.button("Roll Death Saving Throw", func() -> void:
			close()
			hud.death_save_pressed.emit()))


func order() -> void:
	var body := open_page("Turn order", "order")
	for c in hud.e.order:
		if hud.viewer != null and not hud.e.can_see(hud.viewer, c):
			continue
		body.add_child(MobileUi.button("%s%s · Initiative %d" % ["Now: " if c == hud.e.current() else "", c.name(), c.initiative], func() -> void:
			close()
			hud.focus_requested.emit(c.id)))


func log_page() -> void:
	var body := open_page("Combat log · newest first", "log")
	var entries := hud.e.log.entries.duplicate()
	entries.reverse()
	for entry: Dictionary in entries:
		if (entry["details"] as Array).is_empty():
			body.add_child(MobileUi.text(str(entry["text"])))
		else:
			body.add_child(MobileUi.button(str(entry["text"]) + " · Details", func() -> void:
				details(str(entry["text"]), entry["details"] as Array)))
