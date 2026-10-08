class_name ShopScreen
extends CanvasLayer
## Trading with a merchant (plan §5.6, ADR 0010): their wares with prices and stock on the left, the chosen
## character's pack with what the merchant would pay on the right, the purse between. Prices and stock live in
## StoryState; this screen only shows them and sends buy and sell. Sell all junk (U3) sells everything the party has
## marked as junk (InventoryScreen) that this merchant buys, from every pack at once. Under the purse, the terms at
## this counter (Trade: the merchant's attitude and a haggle won) and the Haggle button, which rolls the chosen
## character's Persuasion in the open. The purse counts up or down to its new sum (UiMotion.roll).

signal closed

var root: Node
var st: StoryState
var npc_id := ""
var index := 0
var _frame: VBoxContainer
var _note := ""
var _note_colour := "bile"

## The UiMotion.roll key the purse counts from (the services screen shares it).
const PURSE_KEY := "party_purse"
const ATTITUDE_COLOURS := {"friendly": "bile", "indifferent": "moonlight", "hostile": "rose"}


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
	var top := UiParts.party_chips(st.party, index, func(i: int) -> void:
		index = i
		_draw())
	top.add_child(UiParts.gap())
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 6)
	purse.add_child(UiParts.caption("Purse", 12))
	var sum := UiParts.figure("", 22, "gilt_light")
	UiMotion.roll(sum, PURSE_KEY, st.gold, func(v: float) -> String: return "%s gp" % _money(snappedf(v, 0.01)))
	purse.add_child(sum)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(purse)
	var done := UiKit.button("Done", _close, 16)
	done.custom_minimum_size = Vector2(0, 46)
	top.add_child(done)
	_frame.add_child(top)
	_frame.add_child(_terms_row())
	if _note != "":
		_frame.add_child(UiParts.row(UiKit.label(_note, 15, _note_colour)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(cols)
	# Their wares
	var wares := VBoxContainer.new()
	wares.add_theme_constant_override("separation", 5)
	var ch := st.party[index]
	var any := false
	for w in st.shop_wares(npc_id):
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var id := str(w["id"])
		UiParts.add_icon(row, "item", id)
		var n := UiKit.label(str(w["name"]), 15, "vellum")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		if int(w["qty"]) >= 0:
			row.add_child(UiKit.label("%d left" % int(w["qty"]), 12, "bone"))
		var price := UiParts.figure("%s gp" % _money(float(w["price"])), 16, "gilt_light")
		price.custom_minimum_size = Vector2(72, 0)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(price)
		var b := UiParts.small_button("Buy for %s" % ch.name.get_slice(" ", 0), func() -> void: _buy(id))
		b.disabled = st.gold < float(w["price"])
		if b.disabled:
			b.tooltip_text = "Not enough gold"
		row.add_child(b)
		wares.add_child(UiParts.row(row, LootWindow._item_tip(Compendium.shared().item_data(id))))
	if not any:
		wares.add_child(UiKit.label("Nothing left to sell you.", 15, "bone"))
	cols.add_child(_side("For sale", wares))
	# Our pack
	var pack := VBoxContainer.new()
	pack.add_theme_constant_override("separation", 5)
	for e in ch.inventory:
		if int(e["qty"]) <= 0:
			continue
		var id := str(e["id"])
		var data := Compendium.shared().item_data(id)
		var offer := st.shop_offer(npc_id, id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		UiParts.add_icon(row, "item", id)
		var n := UiKit.label("%s%s" % [data.get("name", id), " ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else ""], 15, "vellum")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		if InventoryScreen.is_junk(e):
			row.add_child(UiParts.pill("Junk", "bone"))
		if str(e.get("slot", "")) != "":
			row.add_child(UiParts.pill("Equipped", "moonlight"))
		# Ammunition goes by the bundle (StoryState.shop_lot): "Sell 20 for 1 gp", and not fewer than that.
		var lot := StoryState.shop_lot(data)
		var label := ("Sell %d for %s gp" % [lot, _money(offer)] if lot > 1 else "Sell for %s gp" % _money(offer)) if offer >= 0.0 else "Won't buy"
		var b := UiParts.small_button(label, func() -> void: _sell(id))
		var stuck := ch.part_blocker(id)   # a cursed item its holder is attuned to won't leave them
		b.disabled = offer < 0.0 or int(e["qty"]) < lot or stuck != ""
		if stuck != "":
			b.tooltip_text = stuck
		elif offer >= 0.0 and int(e["qty"]) < lot:
			b.tooltip_text = "Merchants only buy these %d at a time" % lot
		row.add_child(b)
		pack.add_child(UiParts.row(row, LootWindow._item_tip(data)))
	cols.add_child(_side("%s's pack" % ch.name.get_slice(" ", 0), pack, _junk_button()))


## The terms at this counter and the Haggle button: "Friendly · You pay ×0.9 · they pay ×1.1 ... Haggle (Persuasion
## DC 15, Kip +5)".
func _terms_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var att := st.attitude(npc_id)
	row.add_child(UiParts.pill(att.capitalize(), str(ATTITUDE_COLOURS.get(att, "moonlight")), 13))
	row.add_child(UiKit.label(Trade.terms(st, npc_id), 14, "vellum"))
	if Trade.haggle_state(st, npc_id) == "won":
		row.add_child(UiParts.pill("Good customers: 10% better", "gilt", 13))
	row.add_child(UiParts.gap())
	var ch := st.party[index]
	var b := UiParts.small_button("Haggle (Persuasion DC %d, %s %s)" % [Trade.haggle_dc(npc_id), ch.name.get_slice(" ", 0),
		ch.skill_bonus(&"persuasion").signed()], haggle, "trade")
	var why := Trade.why_no_haggle(st, npc_id)
	if why == "" and ch.hp <= 0:
		why = "%s can't speak for the party now" % ch.name.get_slice(" ", 0)
	b.disabled = why != ""
	b.tooltip_text = why if why != "" else "One Persuasion check. Win it, and %s gives the party 10%% off and pays 10%% more from now on; lose it, and that's final." % \
		Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	row.add_child(b)
	return UiParts.row(row)


## The chosen character haggles (Trade.haggle); the roll and its result go in the note.
func haggle() -> void:
	var ch := st.party[index]
	var test := Trade.haggle(st, npc_id, ch, Dice.roller)
	if test == null:
		return
	_note_colour = "bile" if test.success else "rose"
	var who := Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	_note = "%s haggles: %s. %s" % [ch.name.get_slice(" ", 0), test.describe(),
		("%s gives you the good-customer price." % who) if test.success else ("%s won't budge." % who)]
	_draw()
	_note_colour = "bile"


func _side(title: String, list: VBoxContainer, right: Control = null) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.section(title, right))
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(list))
	col.add_child(pane)
	return col


## The party's junk this merchant buys: [{ch, e (the inventory entry), offer (each sale), qty (sales: pieces, or whole
## bundles of ammunition)}]; equipped things are left out.
func junk_for_sale() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in st.party:
		for e in m.inventory:
			if not InventoryScreen.is_junk(e) or str(e.get("slot", "")) != "" or int(e["qty"]) <= 0 \
					or m.part_blocker(str(e["id"])) != "":
				continue
			var offer := st.shop_offer(npc_id, str(e["id"]))
			var sales := int(e["qty"]) / StoryState.shop_lot(Compendium.shared().item_data(str(e["id"])))
			if offer >= 0.0 and sales > 0:
				out.append({"ch": m, "e": e, "offer": offer, "qty": sales})
	return out


func _junk_button() -> Control:
	var count := 0
	var total := 0.0
	for j in junk_for_sale():
		count += int(j["qty"]) * StoryState.shop_lot(Compendium.shared().item_data(str((j["e"] as Dictionary)["id"])))
		total += float(j["offer"]) * int(j["qty"])
	var b := UiParts.small_button("Sell all junk · %d for %s gp" % [count, _money(total)] if count > 0 else "Sell all junk",
		sell_all_junk, "trade")
	b.disabled = count == 0
	var who := Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	b.tooltip_text = ("Everything the party marked as junk that %s buys, from every pack (equipped things stay)." % who) if count > 0 \
		else "Nothing marked as junk that %s buys. Mark things as junk in the inventory." % who
	return b


## Sells every piece of junk in junk_for_sale(), each from its own entry; says how many and for how much.
func sell_all_junk() -> void:
	var sold := 0
	var gained := 0.0
	for j in junk_for_sale():
		for i in int(j["qty"]):
			var before := st.gold
			if st.shop_sell(npc_id, str((j["e"] as Dictionary)["id"]), j["ch"] as Character, j["e"] as Dictionary) != "":
				break
			sold += StoryState.shop_lot(Compendium.shared().item_data(str((j["e"] as Dictionary)["id"])))
			gained += st.gold - before
	if sold > 0:
		Audio.sfx("coins")
	_note = "Sold %d piece%s of junk for %s gp." % [sold, "" if sold == 1 else "s", _money(gained)] if sold > 0 else "Nothing to sell."
	_draw()


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
