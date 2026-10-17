class_name MobileExploreHud
extends Control
## Quiet exploration: minimap, Reveal and Menu on phones, with two small shortcuts on regular tablets.

var hud: ExploreHud
var shortcuts: HBoxContainer
var reveal_button: RevealButton
var menu_button: Button
var party_button: Button
var inventory_button: Button
var location := ""
var state_text := ""
var messages: Array[String] = []
var narration := ""
var sheet: CanvasLayer
var kind := ""
var nearby_query := ""
var _nearby_view: LocationView
var _nearby_rows: VBoxContainer
var _nearby_entries: Array[Dictionary] = []


func setup(owner_: ExploreHud) -> void:
	hud = owner_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.thing_labels = ThingLabels.new()
	add_child(hud.thing_labels)
	hud.minimap = Minimap.new()
	add_child(hud.minimap)
	shortcuts = HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 6)
	add_child(shortcuts)
	reveal_button = RevealButton.new()
	reveal_button.text = "Reveal"
	reveal_button.toggle_mode = true
	reveal_button.tooltip_text = "Hold to show interactable names"
	MobileUi.fit(reveal_button)
	menu_button = MobileUi.button("Menu", menu)
	party_button = MobileUi.button("Party", party)
	inventory_button = MobileUi.button("Inventory", func() -> void: hud.command.emit("inventory"))
	for button: Button in [party_button, inventory_button, reveal_button, menu_button]:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size.x = 96
		shortcuts.add_child(button)
	get_viewport().size_changed.connect(reflow)
	reflow()


func _process(_delta: float) -> void:
	if reveal_button.held and (not is_visible_in_tree() or UiFeel.touch.world_target() == null):
		reveal_button.touch_surface_cancel()
	hud.thing_labels.mobile_held = reveal_button.held and is_visible_in_tree()


class RevealButton extends Button:
	var held := false
	var finger := -1

	func touch_surface_press(index: int, _at: Vector2) -> void:
		if finger < 0:
			finger = index
			held = true
			set_pressed_no_signal(true)
			MobileNative.feedback()

	func touch_surface_drag(index: int, at: Vector2) -> void:
		if index == finger and not get_global_rect().has_point(at):
			touch_surface_cancel()

	func touch_surface_release(index: int, _at: Vector2, _canceled: bool) -> void:
		if index == finger:
			touch_surface_cancel()

	func touch_surface_cancel() -> void:
		finger = -1
		held = false
		set_pressed_no_signal(false)


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
	choices.add_child(MobileUi.button("Nearby objects", nearby))
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
	body.add_child(MobileUi.text("Tap the ground to move or an object to interact. Drag to pan, pinch to zoom, and twist two fingers clockwise or counterclockwise to rotate. Menu → Camera also has buttons. Menu → Nearby objects lists visible interactables without precision tapping. Hold Reveal to see their names in the world. Menu → More controls → Context shows an object's other actions."))
	body.add_child(MobileUi.text(PadGlyphs.names("Controller: left stick walks; right stick turns and zooms. {@mark_prev}/{@mark_next} select nearby objects; {@use_marked} interacts; {@marked_menu} opens their options; {@search} searches. {@leader_prev}/{@leader_next} change leader. {@hud_bar} opens this exploration menu; {start} opens pause/settings. {b} goes back. Settings → Keys → Controller changes bindings.")))


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


## A list alternative to tiny/overlapping world targets and a sustained Reveal hold. Opening it does not act.
func nearby(note: String = "") -> void:
	var body := open_page("Nearby objects", "nearby")
	var page := body.get_parent().get_parent().get_parent() as MobilePage
	page.centered_width = 720
	page.centered_height = 520
	page.back_action = menu
	page.reflow()
	var done := MobileUi.button("Close", close)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.autowrap_mode = TextServer.AUTOWRAP_OFF
	page.heading.get_parent().add_child(done)
	_nearby_view = hud.minimap.view
	_nearby_entries = nearby_entries()
	var tools := HBoxContainer.new()
	page.toolbar.add_child(tools)
	var search := LineEdit.new()
	search.placeholder_text = "Search nearby objects"
	search.text = nearby_query
	search.clear_button_enabled = true
	search.custom_minimum_size.y = 48
	search.add_theme_font_size_override("font_size", UiScale.text(18))
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(value: String) -> void:
		nearby_query = value
		_fill_nearby()
		page.scroll.scroll_vertical = 0)
	tools.add_child(search)
	var refresh_button := MobileUi.button("Refresh", func() -> void: nearby())
	refresh_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	refresh_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	tools.add_child(refresh_button)
	body.add_child(MobileUi.text(note if note != "" else "Choose an object to see its actions. Nothing happens until you choose an action.", "parchment"))
	_nearby_rows = VBoxContainer.new()
	_nearby_rows.add_theme_constant_override("separation", 6)
	body.add_child(_nearby_rows)
	_fill_nearby()


func nearby_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var view := hud.minimap.view
	if not is_instance_valid(view) or view.busy or view.input_locked or view.in_combat:
		return entries
	# Reuse the desktop reveal eligibility: no hidden rooms, undiscovered secrets, offscreen targets or party.
	entries = hud.thing_labels.plates()
	for entry in entries:
		var offset := (entry["cell"] as Vector2i) - view.leader().cell
		entry["feet"] = maxi(absi(offset.x), absi(offset.y)) * 5
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["feet"]) < int(b["feet"]) if a["feet"] != b["feet"] else str(a["text"]).naturalnocasecmp_to(str(b["text"])) < 0)
	return entries


func _fill_nearby() -> void:
	MobileUi.clear(_nearby_rows)
	var words := nearby_query.strip_edges().to_lower()
	var count := 0
	for entry in _nearby_entries:
		var text := str(entry["text"])
		if words != "" and not text.to_lower().contains(words):
			continue
		var category := str({"npc": "Person", "prop": "Object"}.get(str(entry["kind"]), str(entry["kind"]).capitalize()))
		var caption := "%s\n%s · %d ft away" % [text, category, int(entry["feet"])]
		var button := MobileUi.button(caption, func() -> void: _pick_nearby(entry))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.set_meta(&"nearby_entry", entry)
		_nearby_rows.add_child(button)
		count += 1
	if count == 0:
		_nearby_rows.add_child(MobileUi.text("No matching nearby objects." if words != "" else "No visible interactables nearby. Close this list and move or pan the camera, then try again."))
		if words != "":
			_nearby_rows.add_child(MobileUi.button("Clear search", func() -> void:
				nearby_query = ""
				nearby()))


func _pick_nearby(entry: Dictionary) -> void:
	if kind != "nearby" or not is_instance_valid(_nearby_view):
		return
	if _nearby_view == hud.minimap.view:
		for fresh in nearby_entries():
			if fresh["kind"] == entry["kind"] and fresh["id"] == entry["id"] and fresh["cell"] == entry["cell"]:
				var view := _nearby_view
				close()
				hud.interactable_requested.emit(view, fresh["cell"] as Vector2i)
				return
	nearby("That object is no longer available. The list has been refreshed.")
