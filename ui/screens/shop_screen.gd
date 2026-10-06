class_name ShopScreen
extends CanvasLayer
## Trading with a merchant (plan §5.6, ADR 0010): their wares with prices and stock on the left, the chosen
## character's pack with what the merchant would pay on the right, the purse between. Prices and stock live in
## StoryState; this screen only shows them and sends buy and sell.

signal closed

var root: Node
var st: StoryState
var npc_id := ""
var index := 0
var _frame: VBoxContainer
var _note := ""


func _init() -> void:
	name = "ShopScreen"
	layer = 31


func open_for(root_: Node, state: StoryState, npc: String) -> void:
	root = root_
	st = state
	npc_id = npc
	var title := "Trade with %s" % Compendium.shared().display_name("npcs", npc)
	_frame = UiKit.screen_frame(self, title, Vector2(1400, 820))
	_draw()


func _draw() -> void:
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	for i in st.party.size():
		top.add_child(UiKit.button(("▸ " if i == index else "") + st.party[i].name, func() -> void:
			index = i
			_draw(), 14))
	top.add_child(UiKit.label("   Purse: %s gp" % _money(st.gold), 18, "gilt_light"))
	top.add_child(UiKit.button("Done", _close, 15))
	_frame.add_child(top)
	if _note != "":
		_frame.add_child(UiKit.label(_note, 15, "bile"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	_frame.add_child(cols)
	# Their wares
	var wares := VBoxContainer.new()
	wares.add_child(UiKit.header("For sale"))
	var ch := st.party[index]
	var any := false
	for w in st.shop_wares(npc_id):
		any = true
		var row := HBoxContainer.new()
		var stock := "" if int(w["qty"]) < 0 else "  (%d left)" % int(w["qty"])
		var l := UiKit.label("%s · %s gp%s" % [w["name"], _money(float(w["price"])), stock], 15, "vellum", 420)
		l.tooltip_text = str(Compendium.shared().item_data(str(w["id"])).get("summary", ""))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var id := str(w["id"])
		var b := UiKit.button("Buy for %s" % ch.name.get_slice(" ", 0), func() -> void: _buy(id), 13)
		b.disabled = st.gold < float(w["price"])
		if b.disabled:
			b.tooltip_text = "Not enough gold"
		row.add_child(b)
		wares.add_child(row)
	if not any:
		wares.add_child(UiKit.label("Nothing left to sell you.", 15, "parchment"))
	cols.add_child(UiKit.scroll(wares, Vector2(660, 620)))
	# Our pack
	var pack := VBoxContainer.new()
	pack.add_child(UiKit.header("%s's pack" % ch.name.get_slice(" ", 0)))
	for e in ch.inventory:
		if int(e["qty"]) <= 0:
			continue
		var id := str(e["id"])
		var data := Compendium.shared().item_data(id)
		var offer := st.shop_offer(npc_id, id)
		var row := HBoxContainer.new()
		row.add_child(UiKit.label("%s%s%s" % [data.get("name", id), " ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else "",
			" (equipped)" if str(e.get("slot", "")) != "" else ""], 15, "vellum", 380))
		var b := UiKit.button("Sell for %s gp" % _money(offer) if offer >= 0.0 else "Won't buy", func() -> void: _sell(id), 13)
		b.disabled = offer < 0.0
		row.add_child(b)
		pack.add_child(row)
	cols.add_child(UiKit.scroll(pack, Vector2(620, 620)))


func _buy(item_id: String) -> void:
	var why := st.shop_buy(npc_id, item_id, st.party[index])
	if why == "":
		Audio.sfx("coins")
	_note = why if why != "" else "%s buys %s." % [st.party[index].name.get_slice(" ", 0), Compendium.shared().display_name("items", item_id)]
	_draw()


func _sell(item_id: String) -> void:
	var name_ := Compendium.shared().display_name("items", item_id)
	var why := st.shop_sell(npc_id, item_id, st.party[index])
	if why == "":
		Audio.sfx("coins")
	_note = why if why != "" else "Sold %s." % name_
	_draw()


static func _money(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.2f" % v


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"combat_cancel"):
		get_viewport().set_input_as_handled()
		_close()
