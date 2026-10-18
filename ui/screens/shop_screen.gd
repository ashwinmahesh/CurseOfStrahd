class_name ShopScreen
extends CanvasLayer
## Trading with a merchant (plan §5.6, ADR 0010): their wares with prices and stock on the left, the chosen
## character's pack with what the merchant would pay on the right, the purse between. Prices and stock live in
## StoryState; this screen only shows them and sends buy and sell. Sell all junk (U3) sells everything the party has
## marked as junk (InventoryScreen) that this merchant buys, from every pack at once. Under the purse, the terms at
## this counter (Trade: the merchant's attitude and a haggle won) and the Haggle button, which rolls the chosen
## character's Persuasion in the open. The purse counts up or down to its new sum (UiMotion.roll).
## The pack side has the inventory's filter tabs (InventoryScreen.FILTERS, Potions and Quest items among them; LB/RB on
## a pad) and Only what <merchant> buys, which leaves out what this merchant won't take; both are kept for the rest of
## the play session. A magic item's picture has a box in the colour of its rarity there and on the wares side, as in
## the inventory.
## The wares side has tabs of its own (WARE_FILTERS, only the kinds this merchant has; LB/RB step whichever side the
## focus is on), so a merchant with a hundred magic items (Ashwin, 2026-10-14: every one the story doesn't need is for
## sale somewhere) is a few short lists. A magic item's name is in its rarity's colour with the rarity beside it. One
## made on a weapon or armor the party picks ("Flame Tongue", StoryState.shop_wares `bases`) shows its lowest price and
## Choose, which opens a row for each weapon or armor it can be, at that one's price.

signal closed

var root: Node
var st: StoryState
var npc_id := ""
var index := 0
var _frame: VBoxContainer
var _note := ""
var _note_colour := "bile"
## The pack's rows as item ids, in order (sell_ids()).
var _sell_ids: Array[String] = []

## The pack side's filter tab and whether it shows only what the merchant buys (owner's ask, 2026-10-13; on by
## default). Static, so the choice holds at every counter, for every character, until the game is closed; not saved.
static var sell_filter := "All"
static var only_buys := true

## The wares side's tab (static, as the pack side's: kept for the play session) and the made-to-order ware whose bases
## are open ("" = none).
static var ware_filter := "All"
var _open_bases := ""
## Which side's tabs LB/RB step when nothing has focus ("PackSide" or "WaresSide"; pad_tab).
var _tab_side := "PackSide"
## The wares side's tabs and the item categories each keeps; Potions and Scrolls (the Spell Scrolls, of every level) are
## tabs of their own, as in the inventory, Consumables also takes anything used up (a bead, a dust, a Scroll of
## Protection), Wondrous any other magic item, Gear the rest. "All" and the tabs this merchant has wares in are shown.
const WARE_FILTERS: Array[String] = ["All", "Weapons", "Armor", "Potions", "Scrolls", "Consumables", "Wands", "Wondrous", "Gear"]
const WARE_CATEGORIES := {"Weapons": ["weapon", "ammunition"], "Armor": ["armor", "shield", "clothing"],
	"Potions": ["potion"], "Consumables": ["scroll", "consumable"], "Wands": ["wand", "rod", "staff", "focus"]}
## The wares side lists what this tab keeps, as item ids in order (ware_ids()).
var _ware_ids: Array[String] = []

## The UiMotion.roll key the purse counts from (the services screen shares it).
const PURSE_KEY := "party_purse"
const ATTITUDE_COLOURS := {"friendly": "bile", "indifferent": "moonlight", "hostile": "rose"}
## Words a merchant's name can start with that _who() keeps with the name after them.
const TITLES := ["Father", "Sir", "Madam", "Lady", "Lord", "Mother", "Brother", "Sister", "Baron", "Baroness"]


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
	# Their wares: the tab's, each with its price and Buy (or Choose, for one made on the party's pick of base).
	var wares := VBoxContainer.new()
	wares.add_theme_constant_override("separation", 5)
	var ch := st.party[index]
	var all_wares := st.shop_wares(npc_id)
	var tabs := ware_tabs(all_wares)
	if not ware_filter in tabs:
		ware_filter = "All"
	_ware_ids.clear()
	for w in all_wares:
		if not ware_in_filter(ware_filter, w):
			continue
		var id := str(w["id"])
		_ware_ids.append(id)
		wares.add_child(_ware_row(w, ch))
		if w.has("bases") and _open_bases == id:
			for o: Dictionary in w["bases"]:
				wares.add_child(_base_row(o, ch))
	if all_wares.is_empty():
		wares.add_child(UiKit.label("Nothing left to sell you.", 15, "bone"))
	cols.add_child(_wares_side(wares, tabs))
	# Our pack: what the filter tab keeps, and with Only what they buy on, only what this merchant takes.
	var pack := VBoxContainer.new()
	pack.add_theme_constant_override("separation", 5)
	_sell_ids.clear()
	var hidden := 0
	for e in ch.inventory:
		if int(e["qty"]) <= 0:
			continue
		var id := str(e["id"])
		var data := Compendium.shared().item_data(id)
		if not InventoryScreen.in_filter(sell_filter, MagicItems.shown_data(data, e)):
			continue
		var offer := st.shop_offer(npc_id, id)
		if only_buys and offer < 0.0:
			hidden += 1
			continue
		_sell_ids.append(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var rarity := InventoryScreen.rarity_of(MagicItems.shown_data(data, e))
		UiParts.add_framed_icon(row, "item", id, InventoryScreen.rarity_box(rarity), InventoryScreen.ROW_ICON)
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
	if _sell_ids.is_empty():
		pack.add_child(UiKit.label(_nothing_to_sell(ch, hidden > 0), 15, "bone"))
	cols.add_child(_sell_side(ch, pack, hidden))


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
		_who()
	row.add_child(b)
	return UiParts.row(row)


## The chosen character haggles (Trade.haggle); the roll and its result go in the note. Someone can cast Guidance on
## them first (GuidanceOffer): asked over the shop (GuidancePrompt), or cast on a caster's Automatic rule.
func haggle() -> void:
	var ch := st.party[index]
	if ch.hp <= 0 or Trade.why_no_haggle(st, npc_id) != "":
		return
	var offer := GuidanceOffer.offer(st, ch, &"persuasion", Trade.haggle_dc(npc_id))
	if GuidanceOffer.asks(offer):
		GuidancePrompt.ask(self, offer, func(i: int, rule: String) -> void: _haggle(ch, GuidanceOffer.answer(offer, i, rule)))
		return
	_haggle(ch, GuidanceOffer.automatic(offer))


func _haggle(ch: Character, extra: Array) -> void:
	var test := Trade.haggle(st, npc_id, ch, Dice.roller, extra)
	if test == null:
		return
	_note_colour = "bile" if test.success else "rose"
	var who := Compendium.shared().display_name("npcs", npc_id).get_slice(" ", 0)
	_note = "%s haggles: %s. %s" % [ch.name.get_slice(" ", 0), test.describe(),
		("%s gives you the good-customer price." % who) if test.success else ("%s won't budge." % who)]
	_draw()
	_note_colour = "bile"


## One ware: its icon, its name (a magic item's in its rarity's colour, the rarity beside it), how many are left, its
## price and Buy; a made-to-order one shows its lowest price and Choose (or Close once its bases are open).
func _ware_row(w: Dictionary, ch: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var id := str(w["id"])
	var made := w.has("bases")
	var rarity := str(w.get("rarity", ""))
	UiParts.add_framed_icon(row, "item", id, InventoryScreen.rarity_box(rarity), InventoryScreen.ROW_ICON)
	var n := UiKit.label(str(w["name"]), 15, ItemTile.rarity_colour(rarity, "vellum") if rarity != "" else "vellum")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(n)
	if rarity != "":
		row.add_child(UiParts.pill(rarity.replace("_", " ").capitalize(), ItemTile.rarity_colour(rarity, "vellum"), 11))
	if int(w["qty"]) >= 0:
		row.add_child(UiKit.label("%d left" % int(w["qty"]), 12, "bone"))
	var price := UiParts.figure(("from %s gp" if made else "%s gp") % _money(float(w["price"])), 16, "gilt_light")
	price.custom_minimum_size = Vector2(72, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var b: Button
	if made:
		var open := _open_bases == id
		b = UiParts.small_button("Close" if open else "Choose", func() -> void: toggle_bases(id))
		b.tooltip_text = "Hide the choices" if open else "Pick the %s it's made on" % _base_kind(w)
		if open:
			UiParts.light_up(b)
	else:
		b = UiParts.small_button("Buy for %s" % ch.name.get_slice(" ", 0), func() -> void: _buy(id))
		b.disabled = st.gold < float(w["price"])
		if b.disabled:
			b.tooltip_text = "Not enough gold"
	row.add_child(b)
	return UiParts.row(row, LootWindow._item_tip(Compendium.shared().item_data(id)), made and _open_bases == id)


## One base of an open made-to-order ware ("Flame Tongue Rapier"), set in under it, with its own price and Buy.
func _base_row(o: Dictionary, ch: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(28, 0)
	row.add_child(indent)
	var id := str(o["id"])
	var n := UiKit.label(str(o["name"]), 14, "vellum")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(n)
	var price := UiParts.figure("%s gp" % _money(float(o["price"])), 15, "gilt_light")
	price.custom_minimum_size = Vector2(72, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var b := UiParts.small_button("Buy for %s" % ch.name.get_slice(" ", 0), func() -> void: _buy(id))
	b.disabled = st.gold < float(o["price"])
	if b.disabled:
		b.tooltip_text = "Not enough gold"
	row.add_child(b)
	return UiParts.row(row, LootWindow._item_tip(Compendium.shared().item_data(id)), false, 5)


## "weapon", "armor" or "ammunition": what a made-to-order ware's bases are, for Choose's tip.
static func _base_kind(w: Dictionary) -> String:
	var on := str((Compendium.shared().item_data(str(w["id"])).get("template", {}) as Dictionary).get("on", "weapon"))
	return "ammunition" if on == "ammunition" else ("armor" if on == "armor" else "weapon")


## A made-to-order ware's bases, open or closed (one open at a time).
func toggle_bases(id: String) -> void:
	_open_bases = "" if _open_bases == id else id
	_draw()


## The wares side's tab a ware is under (WARE_CATEGORIES); an item made on a base goes by what it was made as (a Staff
## of Fire is a staff, though it's built on a quarterstaff).
static func ware_kind(w: Dictionary) -> String:
	var comp := Compendium.shared()
	var data := comp.item_data(str(w["id"]))
	var cat := str(data.get("category", ""))
	if data.has("template_id"):
		cat = str(comp.get_entry("magic_items", str(data["template_id"])).get("category", cat))
	if InventoryScreen.is_spell_scroll(data):
		return "Scrolls"
	for f: String in WARE_CATEGORIES:
		if cat in (WARE_CATEGORIES[f] as Array):
			return f
	if MagicItems.is_consumable(data):
		return "Consumables"
	return "Wondrous" if MagicItems.is_magic(data) else "Gear"


static func ware_in_filter(f: String, w: Dictionary) -> bool:
	return f == "All" or ware_kind(w) == f


## "All" and the tabs `wares` has something under, in WARE_FILTERS' order.
static func ware_tabs(wares: Array[Dictionary]) -> Array[String]:
	var kinds := {}
	for w in wares:
		kinds[ware_kind(w)] = true
	var out: Array[String] = []
	for f in WARE_FILTERS:
		if f == "All" or kinds.has(f):
			out.append(f)
	return out


## A tab on the wares side (WARE_FILTERS).
func pick_ware_filter(f: String) -> void:
	ware_filter = f
	_draw()


## What the wares side lists now, as item ids in order (for tests and captures).
func ware_ids() -> Array[String]:
	return _ware_ids.duplicate()


## LB/RB on a pad (PadNav): the tabs on the side the focus is in, else the side they last stepped (the pack's at
## first, as before the wares had tabs), so a redraw that drops the focus keeps them on the same side.
func pad_tab(step: int) -> void:
	var f := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	for side: String in ["WaresSide", "PackSide"]:
		var col := find_child(side, true, false) as Control
		if f != null and col != null and col.is_ancestor_of(f):
			_tab_side = side
	var tabs := ware_tabs(st.shop_wares(npc_id))
	if _tab_side == "WaresSide" and tabs.size() > 1:
		pick_ware_filter(tabs[posmod(tabs.find(ware_filter) + step, tabs.size())])
		return
	pick_filter(str(InventoryScreen.FILTERS[posmod(InventoryScreen.FILTERS.find(sell_filter) + step, InventoryScreen.FILTERS.size())]))


## The wares side: For sale, the tabs this merchant has wares under joined to the pane, and the rows.
func _wares_side(list: VBoxContainer, tabs: Array[String]) -> Control:
	var col := VBoxContainer.new()
	col.name = "WaresSide"
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.section("For sale"))
	var tabbed := VBoxContainer.new()
	tabbed.add_theme_constant_override("separation", 0)
	tabbed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if tabs.size() > 1:
		var strip := UiParts.tab_strip(tabs, ware_filter, pick_ware_filter, {}, 13)
		strip.name = "WareTabs"
		tabbed.add_child(strip)
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(UiParts.fill_scroll(list))
	tabbed.add_child(pane)
	col.add_child(tabbed)
	return col


## The pack side: its title with Sell all junk, the inventory's filter tabs joined to the pane, and Only what
## <merchant> buys over the rows.
func _sell_side(ch: Character, list: VBoxContainer, hidden: int) -> Control:
	var col := VBoxContainer.new()
	col.name = "PackSide"
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.section("%s's pack" % ch.name.get_slice(" ", 0), _junk_button()))
	var tabbed := VBoxContainer.new()
	tabbed.add_theme_constant_override("separation", 0)
	tabbed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var strip := UiParts.tab_strip(Array(InventoryScreen.FILTERS, TYPE_STRING, "", null), sell_filter, pick_filter, {}, 14)
	strip.name = "PackTabs"
	tabbed.add_child(strip)
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.add_child(_buys_row(hidden))
	inner.add_child(UiParts.fill_scroll(list))
	pane.add_child(inner)
	tabbed.add_child(pane)
	col.add_child(tabbed)
	return col


## Only what <merchant> buys, lit while it's on, and how many things in this tab it leaves out.
func _buys_row(hidden: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var who := _who()
	var b := UiParts.small_button("Only what %s buys" % who, func() -> void: set_only_buys(not only_buys))
	b.name = "OnlyBuys"
	if only_buys:
		UiParts.light_up(b)
		b.tooltip_text = "On: what %s won't buy is hidden. Press to show the whole pack." % who
	else:
		b.tooltip_text = "Off: the whole pack shows. Press to hide what %s won't buy." % who
	row.add_child(b)
	row.add_child(UiParts.gap())
	if only_buys and hidden > 0:
		row.add_child(UiParts.caption("Hiding %d they won't buy" % hidden, 11))
	return row


## What the pack side says when it lists nothing: "No weapons in Kip's pack that Gunther buys."
func _nothing_to_sell(ch: Character, any_hidden: bool) -> String:
	var what := "Nothing" if sell_filter == "All" else "No %s" % ("magic items" if sell_filter == "Magic" else sell_filter.to_lower())
	return "%s in %s's pack%s." % [what, ch.name.get_slice(" ", 0), (" that %s buys" % _who()) if any_hidden else ""]


## A filter tab on the pack side (InventoryScreen.FILTERS).
func pick_filter(f: String) -> void:
	sell_filter = f
	_draw()


## Only what <merchant> buys, on or off.
func set_only_buys(on: bool) -> void:
	only_buys = on
	_draw()


## What the pack side lists now, as item ids in order (for tests and captures).
func sell_ids() -> Array[String]:
	return _sell_ids.duplicate()


## The merchant as this screen names them: the first name, or the title with it (Father Lucian, Sir Godfrey).
func _who() -> String:
	var full := Compendium.shared().display_name("npcs", npc_id)
	var first := full.get_slice(" ", 0)
	return "%s %s" % [first, full.get_slice(" ", 1)] if first in TITLES and full.get_slice_count(" ") > 1 else first


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
	var who := _who()
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
