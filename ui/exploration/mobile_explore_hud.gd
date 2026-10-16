class_name MobileExploreHud
extends Control
## Compact exploration status with full text and party information in safe-area sheets.

var hud: ExploreHud
var header: HBoxContainer
var status: Button
var notice: Button
var location := ""
var state_text := ""
var messages: Array[String] = []
var narration := ""
var sheet: CanvasLayer
var kind := ""


func setup(owner_: ExploreHud) -> void:
	hud = owner_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	header = HBoxContainer.new()
	add_child(header)
	status = MobileUi.button("Explore", information)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(status)
	header.add_child(MobileUi.button("Party", party))
	notice = MobileUi.button("", history)
	notice.autowrap_mode = TextServer.AUTOWRAP_OFF
	notice.clip_text = true
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.hide()
	add_child(notice)
	get_viewport().size_changed.connect(reflow)
	reflow()


func reflow() -> void:
	var safe := MobileDevice.safe_rect().grow(-4)
	header.position = safe.position
	header.size = Vector2(safe.size.x, 48)
	notice.position = safe.position + Vector2(0, 54)
	notice.size = Vector2(safe.size.x, 48)


func refresh(where: String, sneaking: bool, solo: bool, planning: bool) -> void:
	if where != "":
		location = where
	status.text = location if location != "" else "Explore"
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
	body.add_child(MobileUi.text("Tap the ground to move or an object to interact. Drag to pan, pinch to zoom, or use More → Camera. More → Context shows an object's other actions."))


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


func message(value: String) -> void:
	if value == "":
		return
	if messages.is_empty() or messages.back() != value:
		messages.append(value)
		if messages.size() > 100:
			messages.pop_front()
	notice.text = value + " · Read"
	notice.show()


func history() -> void:
	var body := open_page("Narration and messages", "messages")
	var recent := messages.duplicate()
	recent.reverse()
	for message_: String in recent:
		body.add_child(MobileUi.text(message_))
	body.add_child(MobileUi.button("Dismiss notification", func() -> void:
		narration = ""
		notice.hide()
		VoiceOver.stop()
		close()))
