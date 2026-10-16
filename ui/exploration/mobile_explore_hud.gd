class_name MobileExploreHud
extends Control
## Quiet exploration: minimap and Menu on phones, with two small shortcuts on regular tablets.

var hud: ExploreHud
var shortcuts: HBoxContainer
var menu_button: Button
var party_button: Button
var inventory_button: Button
var location := ""
var state_text := ""
var messages: Array[String] = []
var narration := ""
var sheet: CanvasLayer
var kind := ""


func setup(owner_: ExploreHud) -> void:
	hud = owner_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.minimap = Minimap.new()
	add_child(hud.minimap)
	shortcuts = HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	add_child(shortcuts)
	menu_button = MobileUi.button("Menu", menu)
	party_button = MobileUi.button("Party", party)
	inventory_button = MobileUi.button("Inventory", func() -> void: hud.command.emit("inventory"))
	for button: Button in [party_button, inventory_button, menu_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 96
		shortcuts.add_child(button)
	get_viewport().size_changed.connect(reflow)
	reflow()


func reflow() -> void:
	var safe := MobileDevice.safe_rect().grow(-4)
	var diameter := 128.0 if MobileDevice.compact() else 188.0
	var map_size := Vector2.ONE * (Minimap.RADIUS + Minimap.RIM) * 2.0
	hud.minimap.size = map_size
	hud.minimap.scale = Vector2.ONE * diameter / map_size.x
	hud.minimap.position = Vector2(safe.end.x - diameter - 8, safe.position.y + 8)
	party_button.visible = not MobileDevice.compact()
	inventory_button.visible = not MobileDevice.compact()
	shortcuts.size = shortcuts.get_combined_minimum_size()
	shortcuts.position = safe.end - shortcuts.size


func refresh(where: String, sneaking: bool, solo: bool, planning: bool) -> void:
	if where != "":
		location = where
	state_text = "Day %d · %02d:%02d · %d gp%s%s%s" % [hud.st.day, hud.st.minute_of_day / 60, hud.st.minute_of_day % 60, hud.st.gold,
		" · Sneaking" if sneaking else "", " · Split party" if solo else "", " · Turn-based" if planning else ""]


func open_page(title: String, page_kind: String = "") -> VBoxContainer:
	close()
	kind = page_kind
	sheet = CanvasLayer.new()
	sheet.layer = 40
	sheet.set_meta(&"pad_scope", true)
	add_child(sheet)
	var body := MobilePage.build(sheet, title, close)
	(body.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return body


func menu() -> void:
	var target := UiFeel.touch.world_target()
	var body := open_page(location if location != "" else "Explore", "menu")
	body.add_child(MobileUi.text(state_text))
	body.add_child(MobileUi.text(hud._objective(), "gilt_light"))
	var view := hud.minimap.view
	if is_instance_valid(view) and view.planning:
		body.add_child(MobileUi.text("Exploration round %d" % view.plan_round, "gilt_light"))
		for member: Combatant in view.members + view.guest_members:
			body.add_child(MobileUi.text("%s · %d ft remaining" % [member.name(), LocationPlan.left_ft(view, member)]))
	var choices := GridContainer.new()
	choices.columns = 2 if MobileDevice.safe_rect().size.x >= 480 else 1
	if not MobileDevice.compact():
		choices.columns = 3
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("h_separation", 10)
	choices.add_theme_constant_override("v_separation", 8)
	body.add_child(choices)
	choices.add_child(MobileUi.button("Party", party))
	for spec: Array in ExploreHud.BUTTONS:
		var command := str(spec[2])
		if command in ["menu", "party"]:
			continue
		choices.add_child(MobileUi.button(str(spec[0]), func() -> void:
			close()
			hud.command.emit(command)))
	choices.add_child(MobileUi.button("Messages and narration", history))
	choices.add_child(MobileUi.button("Camera", func() -> void:
		close()
		if target != null and UiFeel.mobile_controls != null:
			UiFeel.mobile_controls._camera(target)))
	choices.add_child(MobileUi.button("More controls", func() -> void:
		close()
		if target != null and UiFeel.mobile_controls != null:
			UiFeel.mobile_controls._more(target)))
	choices.add_child(MobileUi.button("End exploration round", func() -> void:
		close()
		hud.command.emit("plan_round")))
	if is_instance_valid(view) and view.planning:
		var strike := MobileUi.button("Attack nearby foe", func() -> void:
			close()
			hud.command.emit("strike"))
		strike.disabled = LocationStealth.nearest_waiting(view) == ""
		choices.add_child(strike)
	choices.add_child(MobileUi.button("Save and settings", func() -> void:
		close()
		hud.command.emit("menu")))


func close() -> void:
	if sheet != null:
		sheet.hide()
		sheet.queue_free()
		sheet = null
	kind = ""
	if UiFeel.touch != null:
		UiFeel.touch.cancel()


func information() -> void:
	var body := open_page(location)
	body.add_child(MobileUi.text(state_text))
	body.add_child(MobileUi.text(hud._objective(), "gilt_light"))
	body.add_child(MobileUi.button("Journal", func() -> void:
		close()
		hud.command.emit("journal")))
	body.add_child(MobileUi.button("Map", func() -> void:
		close()
		hud.command.emit("map")))
	body.add_child(MobileUi.text("Tap the ground to move or an object to interact. Drag to pan, pinch to zoom, or use Menu → Camera. Menu → More controls → Context shows an object's other actions."))


func party() -> void:
	var body := open_page("Party")
	for i in hud.st.party.size():
		var c := hud.st.party[i]
		body.add_child(MobileUi.text("%s · HP %d/%d" % [c.name, c.hp, c.max_hp()], "gilt_light"))
		body.add_child(MobileUi.button("Lead with " + c.name, func() -> void:
			close()
			hud.leader_picked.emit(i)))
		body.add_child(MobileUi.button("Character sheet", func() -> void:
			close()
			hud.sheet_requested.emit(i)))
	for c in hud.st.guests:
		body.add_child(MobileUi.text("%s · Guest · HP %d/%d" % [c.name, c.hp, c.max_hp()]))
	body.add_child(MobileUi.button("Manage party", func() -> void:
		close()
		hud.command.emit("party")))


func message(value: String) -> void:
	if value == "":
		return
	if messages.is_empty() or messages.back() != value:
		messages.append(value)
		if messages.size() > 100:
			messages.pop_front()


func history() -> void:
	var body := open_page("Narration and messages", "messages")
	var recent := messages.duplicate()
	recent.reverse()
	for message_: String in recent:
		body.add_child(MobileUi.text(message_))
	body.add_child(MobileUi.button("Dismiss notification", func() -> void:
		narration = ""
		VoiceOver.stop()
		close()))
