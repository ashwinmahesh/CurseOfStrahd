class_name ServicesScreen
extends CanvasLayer
## Services a person sells (F14, story/services.gd): a temple's spells and an inn's rooms. The services are on the
## left, each with its price and a button for the chosen hero (a room is for the whole party); the chosen hero's state
## is on the right: Hit Points, what ails them, a curse, how long ago they died. The purse counts to its new sum like
## the shop's.

signal closed

var root: Node
var st: StoryState
var npc_id := ""
var index := 0
var _frame: VBoxContainer
var _note := ""
var _mobile_review: CanvasLayer
## Opened from the world rather than a conversation: a room bought goes straight to the rest screen.
var rest_after := false


func _init() -> void:
	name = "ServicesScreen"
	layer = 31


func open_for(root_: Node, state: StoryState, npc: String) -> void:
	root = root_
	st = state
	npc_id = npc
	# Start on whoever needs the church most: the dead first.
	for i in st.party.size():
		if st.party[i].dead:
			index = i
			break
	var title := "%s: %s" % [Compendium.shared().display_name("npcs", npc), "rooms" if rooms_only() else "services"]
	_frame = MobilePage.build(self, title, _close) if MobileDevice.enabled() else UiKit.screen_frame(self, title, Vector2(1400, 820))
	if MobileDevice.enabled():
		(_frame.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_draw()


func rooms_only() -> bool:
	for line in Services.offered(st, npc_id):
		if str(line["for"]) != "party":
			return false
	return true


func _draw() -> void:
	if MobileDevice.enabled():
		_mobile_draw()
		return
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	var top := UiParts.party_chips(st.party, index, func(i: int) -> void:
		index = i
		_note = ""
		_draw())
	top.add_child(UiParts.gap())
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 6)
	purse.add_child(UiParts.caption("Purse", 12))
	var sum := UiParts.figure("", 22, "gilt_light")
	UiMotion.roll(sum, ShopScreen.PURSE_KEY, st.gold, func(v: float) -> String: return "%s gp" % ShopScreen._money(snappedf(v, 0.01)))
	purse.add_child(sum)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(purse)
	var done := UiKit.button("Done", _close, 16)
	done.custom_minimum_size = Vector2(0, 46)
	top.add_child(done)
	_frame.add_child(top)
	if _note != "":
		_frame.add_child(UiParts.row(UiKit.label(_note, 15, "bile", 1300)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(cols)
	var ch := st.party[index]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for line in Services.offered(st, npc_id):
		list.add_child(_service_row(line, ch))
	cols.add_child(_side("Rooms" if rooms_only() else "Services", list, 2.0))
	cols.add_child(_side(ch.name.get_slice(" ", 0), _hero_card(ch), 1.0))


func _service_row(line: Dictionary, ch: Character) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var party := str(line["for"]) == "party"
	if line.has("spell"):
		UiParts.add_icon(row, "spell", str(line["spell"]))
	else:
		UiParts.add_icon(row, "item", "bedroll")
	var n := UiKit.label(str(line["name"]), 16, "vellum")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	if float(line["material"]) > 0.0:
		row.add_child(UiParts.pill("+ %s diamond" % coins(float(line["material"])), "moonlight", 12))
	var price := "%s each" % coins(float(line["each"])) if party else coins(float(line["price"]))
	var fig := UiParts.figure(price, 16, "gilt_light")
	fig.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(fig)
	var label := "Take it (%s)" % coins(float(line["price"])) if party else "For %s" % ch.name.get_slice(" ", 0)
	var id := str(line["id"])
	var b := UiParts.small_button(label, func() -> void: buy(id))
	var why := Services.why_not(st, line, ch)
	b.disabled = why != ""
	b.tooltip_text = why
	row.add_child(b)
	col.add_child(row)
	var text := str(line["text"])
	if bool(line.get("scroll", false)):
		text += " %s reads it from one of the church's scrolls." % Compendium.shared().display_name("npcs", npc_id)
	col.add_child(UiKit.label(text, 13, "parchment", 820))
	return UiParts.row(col)


## The chosen hero as the services see them.
func _hero_card(ch: Character) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 72.0, ch.hp <= 0, ch.dead))
	var facts := VBoxContainer.new()
	facts.add_child(UiKit.label(ch.name, 17, "vellum"))
	facts.add_child(UiKit.label(ch.class_summary(), 13, "parchment"))
	head.add_child(facts)
	box.add_child(head)
	if ch.dead:
		var gone := Services.dead_for(st, ch)
		var days := gone / (24 * 60)
		var when := "today" if days == 0 else ("a day ago" if days == 1 else "%d days ago" % days)
		box.add_child(UiParts.pill("Dead: died %s" % when, "rose", 13))
		var left := ceili((Services.RAISE_LIMIT - gone) / (24.0 * 60.0))
		box.add_child(UiKit.label("Raise Dead can still bring %s back for %d more day%s." % [ch.name.get_slice(" ", 0), left, "" if left == 1 else "s"]
			if gone <= Services.RAISE_LIMIT else "Dead too long for Raise Dead.", 13, "parchment", 380))
		return box
	box.add_child(UiParts.hp_bar(ch, 380.0, 24.0))
	var ails := HFlowContainer.new()
	ails.add_theme_constant_override("h_separation", 6)
	ails.add_theme_constant_override("v_separation", 6)
	for c in ch.active_conditions():
		ails.add_child(UiParts.pill(str(c).capitalize(), "rose" if c in Services.RESTORABLE else "moonlight", 12))
	if not Services.curses(ch).is_empty() or not Services.cursed_items(ch).is_empty():
		ails.add_child(UiParts.pill("Cursed", "rose", 12))
	for fx in ch.effects:
		if fx.source_id == "raise_dead":
			ails.add_child(UiParts.pill("Back from the dead: %d on D20 Tests, %d more days" % [Services.ORDEAL_PENALTY,
				ceili(fx.minutes_left / (24.0 * 60.0))], "moonlight", 12))
	if ails.get_child_count() == 0:
		ails.add_child(UiKit.label("Nothing ails %s." % ch.name.get_slice(" ", 0), 13, "parchment"))
	box.add_child(ails)
	return box


func _side(title: String, content: Control, stretch: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = stretch
	col.add_child(UiParts.section(title))
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(content))
	col.add_child(pane)
	return col


## Buys service `id` for the chosen hero (or the party) and says what happened. A room booked goes straight to the
## rest screen, where the Long Rest gives its comforts.
func buy(id: String) -> void:
	for line in Services.offered(st, npc_id):
		if str(line["id"]) != id:
			continue
		var said := Services.buy(st, npc_id, line, st.party[index], Dice.roller)
		if said == "":
			return
		Audio.sfx("coins")
		_note = said
		if root != null and root.has_method("_refresh"):
			root.call("_refresh")
		if str(line["for"]) == "party" and rest_after and root != null and root.has_method("open_screen"):
			_close()
			root.call("open_screen", "rest", 0)
			return
		_draw()
		return


## A price in whole gold pieces (Trade.whole_gp): "2 gp", "0 gp".
static func coins(gp: float) -> String:
	return "%d gp" % int(Trade.whole_gp(gp))


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _mobile_draw() -> void:
	MobileUi.clear(_frame)
	var names: Array[String] = []
	for ch in st.party:
		names.append(ch.name)
	_frame.add_child(MobileUi.tabs(names, st.party[index].name, func(value: String) -> void:
		index = names.find(value)
		_note = ""
		_mobile_draw()))
	_frame.add_child(MobileUi.text("Party purse: " + coins(st.gold), "gilt_light"))
	if _note != "":
		_frame.add_child(MobileUi.text(_note, "bile"))
	var recipient := st.party[index]
	_frame.add_child(MobileUi.text("%s · %d / %d HP" % [recipient.name, recipient.hp, recipient.max_hp()]))
	if recipient.dead:
		_frame.add_child(MobileUi.text("Dead", "rose"))
	for line in Services.offered(st, npc_id):
		var title := HBoxContainer.new()
		UiParts.add_icon(title, "spell" if line.has("spell") else "item", str(line.get("spell", "bedroll")), 28)
		title.add_child(MobileUi.text(str(line["name"]) + " · " + coins(Services.cost(line)), "gilt_light"))
		_frame.add_child(title)
		_frame.add_child(MobileUi.text(str(line["text"])))
		var why := Services.why_not(st, line, st.party[index])
		if why != "":
			_frame.add_child(MobileUi.text(why, "rose"))
		var choose := MobileUi.button("Review purchase", func() -> void: _mobile_confirm(line))
		choose.disabled = why != ""
		_frame.add_child(choose)


func _mobile_confirm(line: Dictionary) -> void:
	_mobile_cancel()
	var recipient := st.party[index]
	_mobile_review = CanvasLayer.new()
	_mobile_review.layer = layer + 1
	add_child(_mobile_review)
	var body := MobilePage.build(_mobile_review, str(line["name"]), _mobile_cancel)
	(body.get_parent() as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiParts.add_icon(body, "spell" if line.has("spell") else "item", str(line.get("spell", "bedroll")), 36)
	body.add_child(MobileUi.text("For the party" if str(line["for"]) == "party" else "For " + recipient.name))
	body.add_child(MobileUi.text(str(line["text"])))
	body.add_child(MobileUi.button("Buy for " + coins(Services.cost(line)), func() -> void:
		if _mobile_review == null:
			return
		_mobile_cancel()
		if index < st.party.size() and st.party[index] == recipient:
			buy(str(line["id"]))))


func _mobile_cancel() -> void:
	if is_instance_valid(_mobile_review):
		_mobile_review.hide()
		_mobile_review.queue_free()
	_mobile_review = null
	UiFeel.touch.cancel()
