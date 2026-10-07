class_name InventoryScreen
extends CanvasLayer
## The inventory (docs/ui/inventory.md inv_01, plan §5.6 "Inventory"), one character at a time:
## - the paper doll (U11): every worn slot round the portrait in gothic-arch tiles, the two weapon sets with a quick
##   swap, four quick slots for consumables (the fight's hotbar shows them on its Common tab), the load and attunements;
## - the backpack as an icon grid with filters, the New and Junk marks, sorting and a search box (U3), and the party
##   stash under it: things go in from anywhere and come out only at a safe place (Q7, owner 2026-10-07);
## - the item card: what the item does for this character compared with what's equipped, and its actions (equip, use,
##   give, split the stack, send to the stash, mark as junk, drop). Quest items can't be dropped, stashed or sold.
## Everything drags: a pack item onto a doll slot, a weapon set or a quick slot; anything onto another character's chip
## (it goes to them), the stash or back into the pack. Right-click a tile for its actions. "New" is what arrived since
## the character's page was last opened (Character.add_item marks it; closing this screen clears it for every page shown).
## Two views (owner, 2026-10-07), kept in the player's settings: the paper doll with the icon grid, or the list (the
## equipped and worn items as rows beside the portrait, the pack and stash as rows), with the same drags, right-click
## menus, weapon sets and quick slots.

const FILTERS := ["All", "Weapons", "Armor", "Consumables", "Magic", "Gear"]
const SORTS := ["name", "weight", "value", "newest"]
## Item categories each filter keeps (Magic is any magic item, whatever its category; Gear is everything else).
const FILTER_CATEGORIES := {"Weapons": ["weapon", "ammunition"], "Armor": ["armor", "shield", "clothing"],
	"Consumables": ["potion", "consumable", "scroll"]}
## The paper doll: worn slots down each side of the portrait (2024 DMG: one of each, two rings), armor among them.
const DOLL_LEFT: Array[String] = ["head", "eyes", "neck", "cloak", "armor", "robe"]
const DOLL_RIGHT: Array[String] = ["wrists", "hands", "belt", "ring", "ring", "feet"]
## Consumables kept to hand for fights (plan §5.6 "Quick slots").
const QUICK_SLOTS := 4
const QUICK_CATEGORIES: Array[String] = ["potion", "consumable", "scroll"]
const TILE := Vector2(64, 72)
const DOLL_TILE := Vector2(54, 58)
const STASH_TILE := Vector2(50, 56)
const VIEWS := {"doll": "Paper doll", "list": "List"}

var root: Node
var st: StoryState
var index := 0
var filter := "All"
var sort_by := "name"
## The picked item's id (the card shows it); `_picked` is its own entry when there are several of the same kind.
var selected := ""
## What the search box holds (matched against an item's name, kind and rarity).
var search := ""
## "new" or "junk" shows only items with that mark; "" shows everything the filter keeps.
var marks := ""
## "doll" or "list" (GameSettings "inventory_view").
var view := "doll"
var _frame: VBoxContainer
var _card: VBoxContainer
## The pack's tiles (doll view) or rows (list view).
var _grid: Container
var _list_foot: Control
## Every tile showing an inventory entry, so picking one only relights them instead of rebuilding the screen (a drag
## starting from a tile would end if the tile were rebuilt under it).
var _tiles: Array[Control] = []
var _picked: Dictionary = {}
## How many of a stack the card's Give, Stash and Drop move, and Split off splits off.
var _amount := 1
## A line the card shows after a drag (what happened, or why not).
var _note := ""
var _note_colour := "bile"
## The characters whose page was shown: their New marks clear when the screen closes.
var _viewed := {}
## PrepareScreen.snapshot() as an item's Long Rest ended (Daern's Instant Fortress, Rod of Security): while this screen
## stays open it offers the chance to change prepared spells the rest screen gives, counted from that list.
var _prepared_before: Dictionary = {}


func _init() -> void:
	name = "InventoryScreen"
	layer = 30


func open(root_: Node, state: StoryState, index_: int) -> void:
	root = root_
	st = state
	index = clampi(index_, 0, st.party.size() - 1)
	view = str(GameSettings.value("inventory_view", "doll"))
	if not VIEWS.has(view):
		view = "doll"
	_frame = UiKit.screen_frame(self, "Inventory", Vector2(1500, 850))
	_draw()


## Switches between the paper doll and the list, and remembers the choice.
func set_view(v: String) -> void:
	if not VIEWS.has(v):
		return
	view = v
	GameSettings.set_value("inventory_view", v)
	_draw()


func _ch() -> Character:
	return st.party[index]


func _draw() -> void:
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	_tiles.clear()
	var ch := _ch()
	_viewed[ch.id] = true
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	for i in st.party.size():
		strip.add_child(_chip(i))
	strip.add_child(UiParts.gap())
	if not _prepared_before.is_empty():
		var prep := UiKit.button("Change prepared spells", _open_prepare, 15, "spells")
		UiParts.light_up(prep)
		prep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.add_child(prep)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 6)
	purse.add_child(UiParts.caption("Purse", 12))
	purse.add_child(UiParts.figure("%d gp" % int(st.gold), 22, "gilt_light"))
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(purse)
	# The view switch: the paper doll or the list.
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 4)
	views.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	views.add_child(UiParts.caption("View", 11))
	for v: String in VIEWS:
		var vb := UiParts.small_button(str(VIEWS[v]), func() -> void: set_view(v))
		vb.tooltip_text = "Worn slots round the portrait, the pack as icons" if v == "doll" else "Equipped and worn items as rows, the pack as a list"
		if v == view:
			UiParts.light_up(vb)
		views.add_child(vb)
	strip.add_child(views)
	_frame.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(row)
	row.add_child(_doll(ch) if view == "doll" else _list_column(ch))
	row.add_child(_pack(ch))
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 8)
	var card_pane := UiParts.pane(14)
	card_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_pane.add_child(UiParts.fill_scroll(_card))
	row.add_child(card_pane)
	_draw_card()


## A party member's chip (their portrait and first name); drop an item on another's chip to give it to them.
func _chip(i: int) -> Control:
	var m := st.party[i]
	var b := ItemTile.DropButton.new()
	b.text = m.name.get_slice(" ", 0)
	b.add_theme_font_size_override("font_size", 16)
	UiKit.button_look(b)
	var path := "res://art/portraits/%s.png" % CombatToken.art_for(m)
	if ResourceLoader.exists(path):
		b.icon = load(path) as Texture2D
	b.expand_icon = true
	b.custom_minimum_size = Vector2(132, 46)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for k: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, Look.color("pewter") if m.hp <= 0 else Color.WHITE)
	if i == index:
		UiParts.light_up(b)
	b.pressed.connect(func() -> void: Audio.sfx("click"))
	b.pressed.connect(func() -> void:
		index = i
		selected = ""
		_picked = {}
		_note = ""
		_draw())
	b.tooltip_text = "%s · %s · %d / %d HP%s" % [m.name, m.class_summary(), m.hp, m.max_hp(),
		"" if i == index else "\nDrop an item here to give it to %s" % m.name.get_slice(" ", 0)]
	b.accepts = func(d: Dictionary) -> bool: return i != index and str(d.get("from", "")) in ["pack", "slot", "stash"] \
		and (str(d["from"]) != "stash" or _stash_open())
	b.dropped = func(d: Dictionary) -> void: _drop_on_member(d, i)
	return b


# --- The paper doll ---------------------------------------------------------------------------------

func _doll(ch: Character) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(336, 0)
	col.add_theme_constant_override("separation", 6)
	var n := UiKit.title(ch.name)
	n.add_theme_font_size_override("font_size", 24)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(336, 0)
	col.add_child(n)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	for s in DOLL_LEFT:
		left.add_child(_slot_tile(ch, s, 0))
	body.add_child(left)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 150.0, ch.hp <= 0, ch.dead))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(UiParts.shield(ch.ac_value(), func() -> Control: return UiParts.breakdown_tip(ch.armor_class(), "Armor Class")))
	var att := VBoxContainer.new()
	att.add_theme_constant_override("separation", 2)
	att.alignment = BoxContainer.ALIGNMENT_CENTER
	att.add_child(UiParts.caption("Attuned", 10))
	att.add_child(UiParts.pips(Character.MAX_ATTUNED, ch.attuned.size(), "lilac"))
	att.tooltip_text = "Attuned to %d of %d magic items: %s" % [ch.attuned.size(), Character.MAX_ATTUNED,
		", ".join(ch.attuned.map(func(a: String) -> String: return Compendium.shared().display_name("items", a))) if not ch.attuned.is_empty() else "none"]
	att.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(att)
	mid.add_child(stats)
	body.add_child(mid)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	var rings := 0
	for s in DOLL_RIGHT:
		right.add_child(_slot_tile(ch, s, rings if s == "ring" else 0))
		if s == "ring":
			rings += 1
	body.add_child(right)
	col.add_child(body)
	# Ioun Stones orbit the head, any number of them.
	var ioun := _worn(ch, "ioun")
	if not ioun.is_empty():
		var orbit := HBoxContainer.new()
		orbit.add_theme_constant_override("separation", 4)
		orbit.add_child(UiParts.caption("Orbiting", 10))
		for i in ioun.size():
			orbit.add_child(_slot_tile(ch, "ioun", i))
		col.add_child(orbit)
	# The two weapon sets, the one in hand first, with the swap between them.
	var swap := UiParts.small_button("↻ Swap", func() -> void:
		ch.swap_weapon_sets()
		_say("%s swaps weapons." % ch.name.get_slice(" ", 0))
		_draw())
	swap.tooltip_text = "Hold the other set: what's in hand now becomes set II (outside fights; in one, a character can attack with any weapon they carry)"
	col.add_child(UiParts.section("Weapons", swap))
	var sets := HBoxContainer.new()
	sets.add_theme_constant_override("separation", 6)
	sets.add_child(_set_label("I", "In hand"))
	sets.add_child(_slot_tile(ch, "main_hand", 0))
	sets.add_child(_slot_tile(ch, "off_hand", 0))
	sets.add_child(UiParts.gap())
	sets.add_child(_set_label("II", "Stowed"))
	sets.add_child(_set2_tile(ch, "main_hand"))
	sets.add_child(_set2_tile(ch, "off_hand"))
	col.add_child(sets)
	col.add_child(UiParts.section("Quick slots"))
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	for i in QUICK_SLOTS:
		quick.add_child(_quick_tile(ch, i))
	var qnote := UiKit.label("On the fight's Common tab", 12, "parchment", 70)
	qnote.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quick.add_child(qnote)
	col.add_child(quick)
	var cap := ch.carrying_capacity().total()
	var carried := ch.carried_weight()
	var over := carried > cap
	col.add_child(UiParts.bar(carried, cap, 0.0, "%.1f / %d lb%s" % [carried, cap, " · Overloaded" if over else ""],
		"vampire_red" if over else "gilt_dark", func() -> Control: return UiParts.breakdown_tip(ch.carrying_capacity(),
			"Carrying capacity", "%d lb" % cap, "Overloaded: Speed drops." if over else ""), 336.0))
	return col


## A weapon set's numeral in engraved capitals over a word.
func _set_label(numeral: String, word: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var big := UiParts.figure(numeral, 20, "gilt_light")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var small := UiParts.caption(word, 9)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(small)
	return v


## The entries worn in `slot` (two rings, any number of Ioun Stones).
func _worn(ch: Character, slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in ch.inventory:
		if str(e.get("slot", "")) == slot and int(e.get("qty", 0)) > 0:
			out.append(e)
	return out


static func slot_name(slot: String) -> String:
	match slot:
		"armor":
			return "Armor"
		"main_hand":
			return "Main hand"
		"off_hand":
			return "Off hand"
	return str(MagicItems.SLOT_NAMES.get(slot, slot.capitalize()))


## A doll slot: the item worn there (the `nth` of several), or its name when empty. Takes what fits from the pack or
## the stash; drag it out to take it off.
func _slot_tile(ch: Character, slot: String, nth: int) -> ItemTile:
	var t := ItemTile.make(DOLL_TILE)
	t.caption = slot_name(slot)
	var worn := _worn(ch, slot)
	var e: Dictionary = worn[nth] if nth < worn.size() else {}
	if not e.is_empty():
		_fill_tile(t, ch, e, {"from": "slot", "slot": slot})
		if slot in MagicItems.WORN_SLOTS and not ch.item_active(e):
			t.marks.append("inactive")
	else:
		t.tip = func() -> Control: return UiParts.rules_tip(slot_name(slot), "Empty", "Drag something that goes here from the pack.")
	t.accepts = func(d: Dictionary) -> bool: return fits_slot(d, slot)
	t.dropped = func(d: Dictionary) -> void: _drop_on_slot(d, slot, e)
	return t


## Weapon set II: a weapon (or shield, wand or rod) to hold when the sets are swapped. It stays in the pack meanwhile.
func _set2_tile(ch: Character, slot: String) -> ItemTile:
	var t := ItemTile.make(DOLL_TILE)
	t.caption = slot_name(slot)
	var id := str(ch.weapon_set_2.get(slot, ""))
	if id != "" and not ch.entry_of(id).is_empty():
		var data := Compendium.shared().item_data(id)
		t.icon = UiParts.icon_texture("item", id)
		t.marks.append("set2")
		t.payload = {"from": "set2", "ch": index, "id": id, "slot": slot}
		t.tip = LootWindow._item_tip(data)
		t.picked.connect(func() -> void: _pick(ch.entry_of(id)))
		var out_of_set := func() -> void:
			ch.weapon_set_2.erase(slot)
			_draw()
		t.menu_requested.connect(func(at: Vector2) -> void: _open_menu([{"label": "Out of set II", "call": out_of_set}], at))
	else:
		t.tip = func() -> Control: return UiParts.rules_tip("Set II · %s" % slot_name(slot), "Empty",
			"Drag a weapon here to hold it when you swap sets: a bow behind the sword and shield.")
	t.accepts = func(d: Dictionary) -> bool: return fits_set2(d, slot)
	t.dropped = func(d: Dictionary) -> void:
		_set_weapon_2(_ch(), str(d["id"]), slot)
		_draw()
	return t


## A quick slot: a consumable the fight's hotbar shows on its Common tab, with how many the character carries.
func _quick_tile(ch: Character, i: int) -> ItemTile:
	var t := ItemTile.make(DOLL_TILE)
	t.caption = "Quick"
	var id := ch.quick_slots[i] if i < ch.quick_slots.size() else ""
	if id != "":
		var carried := 0
		for e in ch.inventory:
			if str(e["id"]) == id:
				carried += int(e["qty"])
		t.icon = UiParts.icon_texture("item", id)
		t.qty = carried
		t.dim = carried == 0
		t.marks.append("quick")
		t.payload = {"from": "quick", "ch": index, "id": id, "index": i}
		var data := Compendium.shared().item_data(id)
		t.tip = func() -> Control: return UiParts.rules_tip(str(data.get("name", id)), "Quick slot %d" % (i + 1),
			str(data.get("summary", "")), [["Carried", str(carried)]], "On the Common tab of %s's hotbar in fights." % ch.name.get_slice(" ", 0))
		if carried > 0:
			t.picked.connect(func() -> void: _pick(ch.entry_of(id)))
		var off_quick := func() -> void:
			ch.quick_slots.erase(id)
			_draw()
		t.menu_requested.connect(func(at: Vector2) -> void: _open_menu([{"label": "Off the quick slots", "call": off_quick}], at))
	else:
		t.tip = func() -> Control: return UiParts.rules_tip("Quick slot %d" % (i + 1), "Empty",
			"Drag a potion, scroll or other consumable here to keep it to hand: fights show it on the hotbar's Common tab.")
	t.accepts = func(d: Dictionary) -> bool: return fits_quick(d)
	t.dropped = func(d: Dictionary) -> void:
		_set_quick(_ch(), str(d["id"]), i)
		_draw()
	return t


## A tile showing inventory entry `e`: its icon, count and marks, and what a drag from it carries.
func _fill_tile(t: ItemTile, ch: Character, e: Dictionary, from: Dictionary) -> void:
	var data := Compendium.shared().item_data(str(e["id"]))
	var shown := MagicItems.shown_data(data, e)
	t.icon = UiParts.icon_texture("item", str(shown.get("id", e["id"])))
	t.qty = int(e["qty"])
	t.payload = {"from": "pack", "ch": index, "id": str(e["id"]), "entry": e}
	t.payload.merge(from, true)
	for k: String in ["new", "junk"]:
		if bool(e.get(k, false)):
			t.marks.append(k)
	if str(e.get("slot", "")) != "" and str(from.get("from", "pack")) == "pack":
		t.marks.append("equipped")
	if InventoryScreen.is_quest(data):
		t.marks.append("quest")
	elif not (shown.get("magic", {}) as Dictionary).is_empty():
		t.marks.append("magic")
	if str(e["id"]) in ch.quick_slots and str(from.get("from", "pack")) == "pack":
		t.marks.append("quick")
	var tip_data := shown.duplicate()
	tip_data["name"] = MagicItems.display_name(data, e) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else "")
	t.tip = LootWindow._item_tip(tip_data)
	t.lit = is_same(e, _picked) or (_picked.is_empty() and str(e["id"]) == selected)
	t.picked.connect(func() -> void: _pick(e))
	t.activated.connect(func() -> void: _activate(e))
	t.menu_requested.connect(func(at: Vector2) -> void: _open_menu(actions_for(e), at))
	_tiles.append(t)


# --- The list view (owner, 2026-10-07: the old list beside the paper doll, with the same drags and menus) -------------

## The left column of the list view: the portrait and Armor Class, the equipped and worn items as rows, weapon set II,
## the quick slots and the load. It scrolls when a character wears a lot.
func _list_column(ch: Character) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	who.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 120.0, ch.hp <= 0, ch.dead))
	who.add_child(UiParts.shield(ch.ac_value(), func() -> Control: return UiParts.breakdown_tip(ch.armor_class(), "Armor Class")))
	var att := VBoxContainer.new()
	att.alignment = BoxContainer.ALIGNMENT_CENTER
	att.add_child(UiParts.caption("Attuned", 10))
	att.add_child(UiParts.pips(Character.MAX_ATTUNED, ch.attuned.size(), "lilac"))
	who.add_child(att)
	col.add_child(who)
	var n := UiKit.title(ch.name)
	n.add_theme_font_size_override("font_size", 24)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(300, 0)
	col.add_child(n)
	var swap := UiParts.small_button("↻ Swap", func() -> void:
		ch.swap_weapon_sets()
		_say("%s swaps weapons." % ch.name.get_slice(" ", 0))
		_draw())
	swap.tooltip_text = "Hold weapon set II: what's in hand now becomes set II (outside fights)"
	col.add_child(UiParts.section("Equipped", swap))
	for slot in Character.EQUIP_SLOTS:
		col.add_child(_slot_line(ch, slot))
	col.add_child(UiParts.section("Set II"))
	for slot2: String in ["main_hand", "off_hand"]:
		col.add_child(_set2_line(ch, slot2))
	# Worn magic items (2024 DMG: one cloak, one pair of boots..., two rings, any number of Ioun Stones). The section
	# takes any worn item dropped on it, into its own slot.
	col.add_child(UiParts.section("Worn"))
	var worn := ItemTile.Zone.new()
	worn.name = "WornZone"
	worn.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	worn.accepts = func(d: Dictionary) -> bool: return str(d.get("from", "")) in ["pack", "stash"] \
		and MagicItems.worn_slot(Compendium.shared().item_data(str(d.get("id", "")))) != "" \
		and (str(d["from"]) != "stash" or _stash_open())
	worn.dropped = func(d: Dictionary) -> void:
		_drop_on_slot(d, MagicItems.worn_slot(Compendium.shared().item_data(str(d["id"]))), {})
	var worn_list := VBoxContainer.new()
	worn_list.add_theme_constant_override("separation", 4)
	for e in ch.inventory:
		if str(e.get("slot", "")) in MagicItems.WORN_SLOTS and int(e.get("qty", 0)) > 0:
			worn_list.add_child(_worn_line(ch, e))
	if worn_list.get_child_count() == 0:
		worn_list.add_child(UiKit.label("Nothing worn. Drag a cloak, ring or boots here.", 13, "bone", 300))
	worn.add_child(worn_list)
	col.add_child(worn)
	col.add_child(UiParts.section("Quick slots"))
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	for i in QUICK_SLOTS:
		quick.add_child(_quick_tile(ch, i))
	col.add_child(quick)
	var cap := ch.carrying_capacity().total()
	var carried := ch.carried_weight()
	var over := carried > cap
	col.add_child(UiParts.bar(carried, cap, 0.0, "%.1f / %d lb%s" % [carried, cap, " · Overloaded" if over else ""],
		"vampire_red" if over else "gilt_dark", func() -> Control: return UiParts.breakdown_tip(ch.carrying_capacity(),
			"Carrying capacity", "%d lb" % cap, "Overloaded: Speed drops." if over else ""), 300.0))
	var scroll := UiParts.fill_scroll(col)
	scroll.custom_minimum_size = Vector2(336, 0)
	scroll.size_flags_horizontal = Control.SIZE_FILL
	return scroll


## A list row for inventory entry `e` around `content`: what a drag from it carries, its tooltip, picking, the
## right-click menu and double-click, as on a tile.
func _row(ch: Character, e: Dictionary, from: Dictionary, content: Control) -> ItemTile.Row:
	var r := ItemTile.Row.new()
	var data := Compendium.shared().item_data(str(e["id"]))
	var shown := MagicItems.shown_data(data, e)
	r.icon = UiParts.icon_texture("item", str(shown.get("id", e["id"])))
	r.payload = {"from": "pack", "ch": index, "id": str(e["id"]), "entry": e}
	r.payload.merge(from, true)
	var tip_data := shown.duplicate()
	tip_data["name"] = MagicItems.display_name(data, e) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else "")
	r.tip = LootWindow._item_tip(tip_data)
	r.lit = is_same(e, _picked) or (_picked.is_empty() and str(e["id"]) == selected)
	r.picked.connect(func() -> void: _pick(e))
	r.activated.connect(func() -> void: _activate(e))
	r.menu_requested.connect(func(at: Vector2) -> void: _open_menu(actions_for(e), at))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(content)
	_tiles.append(r)
	return r


## A pack row's content: icon, name and count, its marks (new, junk, equipped, quest, magic, charges) and weight.
func _pack_line(ch: Character, e: Dictionary, data: Dictionary) -> Control:
	var id := str(e["id"])
	var junk := InventoryScreen.is_junk(e)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	UiParts.add_icon(line, "item", str(MagicItems.shown_data(data, e).get("id", id)))
	var nm := UiKit.label(MagicItems.display_name(data, e) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else ""), 15,
		"bone" if junk else "vellum")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(nm)
	if bool(e.get("new", false)):
		line.add_child(UiParts.pill("New", "gilt_light"))
	if junk:
		line.add_child(UiParts.pill("Junk", "bone"))
	if str(e.get("slot", "")) != "":
		line.add_child(UiParts.pill("Equipped", "moonlight"))
	if id in ch.quick_slots:
		line.add_child(UiParts.pill("Quick", "bile"))
	if InventoryScreen.is_quest(data):
		line.add_child(UiParts.pill("Quest", "flame"))
	if not (data.get("magic", {}) as Dictionary).is_empty():
		line.add_child(UiParts.pill("Attuned" if id in ch.attuned else "Magic", "lilac"))
	if MagicItems.has_charges(data):
		line.add_child(UiParts.pill("%d/%d" % [int(e.get("charges", 0)), MagicItems.max_charges(data, e)], "moonlight"))
	var wt := UiKit.label("%s lb" % str(data.get("weight_lb", 0)), 13, "parchment")
	wt.custom_minimum_size = Vector2(52, 0)
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(wt)
	return line


## An equipped slot as a row: its name, the item and its one key number, and Take off (owner report 2026-10-07: "no way
## to unequip armor"). Takes what fits dropped on it; drag it to the pack to take it off.
func _slot_line(ch: Character, slot: String) -> Control:
	var item := ch.equipped(slot)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	if not item.is_empty():
		UiParts.add_icon(line, "item", str(item["id"]))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.caption(slot.replace("_", " "), 10))
	var nm := UiKit.label(str(item.get("name", "Empty")), 15, "vellum" if not item.is_empty() else "bone")
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	line.add_child(col)
	var e := {}
	for x in ch.inventory:
		if str(x.get("slot", "")) == slot and int(x.get("qty", 0)) > 0:
			e = x
	var r: Control
	if not item.is_empty():
		var stat := ""
		if Gear.is_shield(item):
			stat = "+%d AC" % int((item["armor"] as Dictionary).get("base_ac", 2))
		elif Gear.is_armor(item):
			stat = "AC %d" % int((item["armor"] as Dictionary).get("base_ac", 10))
		elif Gear.is_weapon(item):
			var p := WeaponProfile.build(ch, item)
			stat = "%s · %s" % [p.attack.signed(), p.damage_dice + ("%+d" % p.damage_bonus.total() if p.damage_bonus.total() != 0 else "")]
		line.add_child(UiParts.figure(stat, 15, "gilt_light"))
		var off := UiParts.small_button("Take off", func() -> void:
			ch.unequip(slot)
			_draw())
		off.tooltip_text = "Unequip it: back to the pack"
		line.add_child(off)
		r = _row(ch, e, {"from": "slot", "slot": slot}, line)
		off.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		var empty := ItemTile.Row.new()
		empty.tip = func() -> Control: return UiParts.rules_tip(slot_name(slot), "Empty", "Drag something that goes here from the pack.")
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.add_child(line)
		r = empty
	r.set("accepts", func(d: Dictionary) -> bool: return fits_slot(d, slot))
	r.set("dropped", func(d: Dictionary) -> void: _drop_on_slot(d, slot, e))
	return r


## Weapon set II's main or off hand as a row: what's held when the sets are swapped.
func _set2_line(ch: Character, slot: String) -> Control:
	var id := str(ch.weapon_set_2.get(slot, ""))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var has := id != "" and not ch.entry_of(id).is_empty()
	if has:
		UiParts.add_icon(line, "item", id, 28.0)
	line.add_child(UiParts.caption(slot_name(slot), 10))
	var nm := UiKit.label(Compendium.shared().display_name("items", id) if has else "Empty", 14, "vellum" if has else "bone")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(nm)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ItemTile.Row.new()
	r.add_child(line)
	if has:
		r.icon = UiParts.icon_texture("item", id)
		r.payload = {"from": "set2", "ch": index, "id": id, "slot": slot}
		r.tip = LootWindow._item_tip(Compendium.shared().item_data(id))
		r.picked.connect(func() -> void: _pick(ch.entry_of(id)))
		var out_of_set := func() -> void:
			ch.weapon_set_2.erase(slot)
			_draw()
		r.menu_requested.connect(func(at: Vector2) -> void: _open_menu([{"label": "Out of set II", "call": out_of_set}], at))
	else:
		r.tip = func() -> Control: return UiParts.rules_tip("Set II · %s" % slot_name(slot), "Empty",
			"Drag a weapon here to hold it when you swap sets: a bow behind the sword and shield.")
	r.accepts = func(d: Dictionary) -> bool: return fits_set2(d, slot)
	r.dropped = func(d: Dictionary) -> void:
		_set_weapon_2(_ch(), str(d["id"]), slot)
		_draw()
	return r


## A worn magic item as a row: where it's worn, the item, and whether it's working.
func _worn_line(ch: Character, e: Dictionary) -> Control:
	var data := Compendium.shared().item_data(str(e["id"]))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	UiParts.add_icon(line, "item", str(MagicItems.shown_data(data, e).get("id", e["id"])))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.caption(str(MagicItems.SLOT_NAMES.get(str(e["slot"]), e["slot"])), 10))
	var nm := UiKit.label(MagicItems.display_name(data, e), 15, "vellum")
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	line.add_child(col)
	if not ch.item_active(e):
		line.add_child(UiParts.pill("Needs attunement", "flame"))
	return _row(ch, e, {"from": "slot", "slot": str(e["slot"])}, line)


## A stash row: the item and its count, and Take at a safe place; dragged out of the stash only there.
func _stash_row(se: Dictionary, i: int, at_safe: bool, tip: Callable) -> Control:
	var sid := str(se["id"])
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	UiParts.add_icon(line, "item", sid, 24.0)
	var data := Compendium.shared().item_data(sid)
	var sn := UiKit.label("%s ×%d" % [MagicItems.display_name(data, se), int(se["qty"])], 14, "vellum" if at_safe else "bone")
	sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(sn)
	var take := func() -> void:
		_take_from_stash(se, _ch())
		_draw()
	var tb := UiParts.small_button("Take", take)
	tb.disabled = not at_safe
	tb.tooltip_text = "To %s's pack" % _ch().name.get_slice(" ", 0) if at_safe else "Only at a safe place: an inn or a home"
	line.add_child(tb)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := ItemTile.Row.new()
	r.add_child(line)
	r.icon = UiParts.icon_texture("item", sid)
	r.tip = tip
	if at_safe:
		r.payload = {"from": "stash", "index": i, "id": sid, "entry": se}
		r.activated.connect(take)
		r.menu_requested.connect(func(at: Vector2) -> void: _open_menu([{"label": "Take out", "call": take}], at))
	return r


# --- The pack and the stash ---------------------------------------------------------------------------

func _pack(ch: Character) -> Control:
	var pack := VBoxContainer.new()
	pack.custom_minimum_size = Vector2(590, 0)
	pack.add_theme_constant_override("separation", 0)
	pack.add_child(UiParts.tab_strip(Array(FILTERS, TYPE_STRING, "", null), filter, func(f: String) -> void:
		filter = f
		_draw(), {}, 14))
	var pane := ItemTile.Zone.new()
	pane.name = "PackZone"
	pane.add_theme_stylebox_override("panel", _panel_style("ui_oxblood", "gilt", 0.35, 10, 2))
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.accepts = func(d: Dictionary) -> bool: return str(d.get("from", "")) in ["slot", "set2", "quick"] \
		or (str(d.get("from", "")) == "stash" and _stash_open())
	pane.dropped = func(d: Dictionary) -> void: _drop_on_pack(d)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	pane.add_child(inner)
	inner.add_child(_search_row(ch))
	var sorts := HBoxContainer.new()
	sorts.add_theme_constant_override("separation", 4)
	sorts.add_child(UiParts.caption("Sort", 11))
	for s: String in SORTS:
		var sb := UiParts.small_button(s.capitalize(), func() -> void:
			sort_by = s
			_draw())
		if s == sort_by:
			UiParts.light_up(sb)
		sorts.add_child(sb)
	sorts.add_child(UiParts.gap())
	sorts.add_child(UiParts.caption("Drag onto a slot, a chip or the stash", 10, "parchment"))
	inner.add_child(sorts)
	if view == "doll":
		var grid := GridContainer.new()
		grid.columns = 8
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_grid = grid
	else:
		_grid = VBoxContainer.new()
		_grid.add_theme_constant_override("separation", 4)
	inner.add_child(UiParts.fill_scroll(_grid))
	_list_foot = VBoxContainer.new()
	inner.add_child(_list_foot)
	_fill_list()
	pack.add_child(pane)
	pack.add_child(_stash(ch))
	return pack


## The party stash (plan §5.6; owner, 2026-10-07): things go in from anywhere, and come out only at a safe place (an
## inn, a home).
func _stash(ch: Character) -> Control:
	var at_safe := _stash_open()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var where := UiParts.caption("Take things out here" if at_safe else "Take things out at an inn or a home", 11, "bile" if at_safe else "parchment")
	box.add_child(UiParts.section("Party stash", where))
	var zone := ItemTile.Zone.new()
	zone.name = "StashZone"
	zone.add_theme_stylebox_override("panel", _panel_style("ui_black", "gilt_dark", 0.7, 6, 1))
	zone.custom_minimum_size = Vector2(0, 2 * STASH_TILE.y + 18)
	zone.accepts = func(d: Dictionary) -> bool: return str(d.get("from", "")) in ["pack", "slot"] \
		and not InventoryScreen.is_quest(Compendium.shared().item_data(str(d.get("id", ""))))
	zone.dropped = func(d: Dictionary) -> void: _drop_on_stash(d)
	var flow: Container = HFlowContainer.new()
	if view == "list":
		flow = VBoxContainer.new()
		flow.add_theme_constant_override("separation", 4)
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	if st.stash.is_empty():
		flow.add_child(UiKit.label("Empty. Drag things here from anywhere, or choose Send to the stash.", 13, "bone", 520))
	for i in st.stash.size():
		var se := st.stash[i]
		var sid := str(se["id"])
		var t := ItemTile.make(STASH_TILE)
		var data := Compendium.shared().item_data(sid)
		t.icon = UiParts.icon_texture("item", str(MagicItems.shown_data(data, se).get("id", sid)))
		t.qty = int(se["qty"])
		t.dim = not at_safe
		if InventoryScreen.is_junk(se):
			t.marks.append("junk")
		var shown := MagicItems.shown_data(data, se).duplicate()
		shown["name"] = MagicItems.display_name(data, se) + (" ×%d" % int(se["qty"]) if int(se["qty"]) > 1 else "")
		var tip := LootWindow._item_tip(shown)
		if view == "list":
			flow.add_child(_stash_row(se, i, at_safe, tip))
			t.free()
			continue
		if at_safe:
			t.tip = tip
			t.payload = {"from": "stash", "index": i, "id": sid, "entry": se}
			var take := func() -> void:
				_take_from_stash(se, _ch())
				_draw()
			var label := "Take out (all %d)" % int(se["qty"]) if int(se["qty"]) > 1 else "Take out"
			t.activated.connect(take)
			t.menu_requested.connect(func(at: Vector2) -> void: _open_menu([{"label": label, "call": take}], at))
		else:
			t.tip = func() -> Control:
				var c := tip.call() as VBoxContainer
				c.add_child(UiParts.wrapped("In the stash: take it out at an inn or a home.", 13, "flame", UiParts.TIP_WIDTH))
				return c
		flow.add_child(t)
	var scroll := UiParts.fill_scroll(flow)
	zone.add_child(scroll)
	box.add_child(zone)
	return box


## The look of UiParts.card and pane for the drop areas (they are drop targets, so they can't be those panels).
static func _panel_style(bg: String, border: String, alpha: float, margin: int, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(Look.color(bg), alpha)
	s.border_color = Color(Look.color(border), 0.9)
	s.set_border_width_all(width)
	s.set_corner_radius_all(7)
	s.corner_detail = 1
	s.set_content_margin_all(margin)
	return s


# --- What fits where, and what a drop does ----------------------------------------------------------------

## Whether a drag `d` can go into doll slot `slot`: armor in the armor slot, a weapon or a wand, rod or staff in hand
## (the off hand takes a Shield or a Light weapon), a worn magic item in its own slot. From the stash only at a safe place.
func fits_slot(d: Dictionary, slot: String) -> bool:
	var from := str(d.get("from", ""))
	if not from in ["pack", "stash", "set2"] or (from == "stash" and not _stash_open()):
		return false
	if from == "pack" and str((d.get("entry", {}) as Dictionary).get("slot", "")) == slot:
		return false
	return InventoryScreen.slot_takes(slot, Compendium.shared().item_data(str(d.get("id", ""))))


static func slot_takes(slot: String, data: Dictionary) -> bool:
	match slot:
		"armor":
			return Gear.is_armor(data)
		"main_hand":
			return Gear.is_weapon(data) or MagicItems.is_held(data)
		"off_hand":
			return Gear.is_shield(data) or (Gear.is_weapon(data) and "light" in Gear.weapon_props(data)) or MagicItems.is_held(data)
	return MagicItems.worn_slot(data) == slot


func fits_set2(d: Dictionary, slot: String) -> bool:
	return str(d.get("from", "")) in ["pack", "slot"] and slot in ["main_hand", "off_hand"] \
		and InventoryScreen.slot_takes(slot, Compendium.shared().item_data(str(d.get("id", ""))))


func fits_quick(d: Dictionary) -> bool:
	return str(d.get("from", "")) in ["pack", "quick"] \
		and str(Compendium.shared().item_data(str(d.get("id", ""))).get("category", "")) in QUICK_CATEGORIES


## Puts `item_id` in hand (`slot`), taking off what was there; a two-handed weapon empties the other hand.
func _equip(ch: Character, item_id: String, slot: String) -> bool:
	var data := Compendium.shared().item_data(item_id)
	if slot == "main_hand" and "two_handed" in Gear.weapon_props(data):
		ch.unequip("off_hand")
	if slot == "off_hand" and "two_handed" in Gear.weapon_props(ch.equipped("main_hand")):
		ch.unequip("main_hand")
	if slot in Character.EQUIP_SLOTS:
		ch.unequip(slot)
	return ch.equip(item_id, slot)


func _drop_on_slot(d: Dictionary, slot: String, occupant: Dictionary) -> void:
	var ch := _ch()
	var id := str(d["id"])
	match str(d["from"]):
		"stash":
			if not _take_from_stash(d["entry"] as Dictionary, ch, 1):
				return
		"set2":
			ch.weapon_set_2.erase(str(d["slot"]))
	if not occupant.is_empty() and slot in MagicItems.WORN_SLOTS:
		ch.unequip_item(str(occupant["id"]))
	var name_ := Compendium.shared().display_name("items", id)
	if _equip(ch, id, slot):
		_say("%s: %s." % [slot_name(slot), name_])
	else:
		_say("%s can't go there." % name_, "flame")
	_draw()


## Back into the pack: taken off, out of set II or a quick slot, or out of the stash.
func _drop_on_pack(d: Dictionary) -> void:
	var ch := _ch()
	match str(d["from"]):
		"slot":
			ch.unequip_item(str(d["id"]))
			_say("Took off the %s." % Compendium.shared().display_name("items", str(d["id"])))
		"set2":
			ch.weapon_set_2.erase(str(d["slot"]))
		"quick":
			ch.quick_slots.erase(str(d["id"]))
		"stash":
			_take_from_stash(d["entry"] as Dictionary, ch)
	_draw()


## Onto another character's chip: the whole stack goes to them (from the stash too, at a safe place).
func _drop_on_member(d: Dictionary, to: int) -> void:
	var other := st.party[to]
	if str(d["from"]) == "stash":
		_take_from_stash(d["entry"] as Dictionary, other)
	else:
		var e := d["entry"] as Dictionary
		_move(_ch(), e, other, int(e.get("qty", 1)))
	_draw()


func _drop_on_stash(d: Dictionary) -> void:
	var e := d["entry"] as Dictionary
	_to_stash(_ch(), e, int(e.get("qty", 1)))
	_draw()


## Moves `n` of entry `e` from `from` to `to`, each with its own state; says so, and whether it overloads them.
func _move(from: Character, e: Dictionary, to: Character, n: int) -> void:
	var id := str(e["id"])
	var moved := 0
	for i in n:
		if not _carries(from, e):
			break
		var state := from.remove_one(id, e)
		state.erase("new")
		to.add_item(id, 1, state)
		moved += 1
	_forget_gone(from, id)
	if is_same(e, _picked) and not _carries(from, e):
		_picked = {}
		selected = ""
	var what := Compendium.shared().display_name("items", id) + (" ×%d" % moved if moved > 1 else "")
	if to.carried_weight() > to.carrying_capacity().total():
		_say("%s now carries %s, and is overloaded." % [to.name.get_slice(" ", 0), what], "flame")
	else:
		_say("%s now carries %s." % [to.name.get_slice(" ", 0), what])


func _to_stash(ch: Character, e: Dictionary, n: int) -> void:
	var id := str(e["id"])
	var moved := 0
	for i in n:
		if not _carries(ch, e) or not st.stash_put(id, ch, e):
			break
		moved += 1
	_forget_gone(ch, id)
	if is_same(e, _picked) and not _carries(ch, e):
		_picked = {}
		selected = ""
	_say("%s%s to the stash." % [Compendium.shared().display_name("items", id), " ×%d" % moved if moved > 1 else ""])


## Takes `n` (all when -1) of stash entry `se` to `ch`'s pack, at a safe place only. False when nothing came out.
func _take_from_stash(se: Dictionary, ch: Character, n: int = -1) -> bool:
	if not _stash_open():
		_say("The stash opens only at a safe place: an inn or a home.", "flame")
		return false
	var id := str(se["id"])
	var count := int(se.get("qty", 1)) if n < 0 else n
	var took := 0
	for i in count:
		if not st.stash.any(func(x: Dictionary) -> bool: return is_same(x, se)) or not st.stash_take(id, ch, se):
			break
		took += 1
	if took > 0:
		_say("%s takes %s%s." % [ch.name.get_slice(" ", 0), Compendium.shared().display_name("items", id), " ×%d" % took if took > 1 else ""])
	return took > 0


func _carries(ch: Character, e: Dictionary) -> bool:
	return int(e.get("qty", 0)) > 0 and ch.inventory.any(func(x: Dictionary) -> bool: return is_same(x, e))


## An item no longer carried leaves the quick slots and set II.
func _forget_gone(ch: Character, item_id: String) -> void:
	if ch.entry_of(item_id).is_empty():
		ch.quick_slots.erase(item_id)
		for slot: String in ch.weapon_set_2.keys():
			if str(ch.weapon_set_2[slot]) == item_id:
				ch.weapon_set_2.erase(slot)


## Set II takes `item_id` in `slot`; a two-handed weapon there leaves no room for the other hand.
func _set_weapon_2(ch: Character, item_id: String, slot: String) -> void:
	ch.weapon_set_2[slot] = item_id
	var other := "off_hand" if slot == "main_hand" else "main_hand"
	if "two_handed" in Gear.weapon_props(Compendium.shared().item_data(item_id)) or \
			"two_handed" in Gear.weapon_props(Compendium.shared().item_data(str(ch.weapon_set_2.get(other, "")))):
		ch.weapon_set_2.erase(other)
	_say("Set II · %s: %s." % [slot_name(slot), Compendium.shared().display_name("items", item_id)])


func _set_quick(ch: Character, item_id: String, at: int) -> void:
	ch.quick_slots.erase(item_id)
	ch.quick_slots.insert(mini(at, ch.quick_slots.size()), item_id)
	while ch.quick_slots.size() > QUICK_SLOTS:
		ch.quick_slots.pop_back()
	_say("%s is kept to hand." % Compendium.shared().display_name("items", item_id))


func _say(text: String, colour: String = "bile") -> void:
	_note = text
	_note_colour = colour


# --- Picking, the right-click menu, double-click ---------------------------------------------------------

## Picks an entry: its card shows and the tiles relight; nothing is rebuilt, so a drag can start from the tile.
func _pick(e: Dictionary) -> void:
	if e.is_empty():
		return
	_picked = e
	selected = str(e["id"])
	_amount = 1
	_note = ""
	for t in _tiles:
		if is_instance_valid(t):
			t.set("lit", is_same((t.get("payload") as Dictionary).get("entry"), e))
			t.queue_redraw()
	_draw_card()


## Double-click: wear or hold it (into the first slot that takes it), take it off if worn.
func _activate(e: Dictionary) -> void:
	_pick(e)
	var acts := actions_for(e)
	if not acts.is_empty():
		(acts[0]["call"] as Callable).call()


## What a right-click offers for entry `e`, first the likeliest: [{label, call}].
func actions_for(e: Dictionary) -> Array[Dictionary]:
	var ch := _ch()
	var id := str(e["id"])
	var data := Compendium.shared().item_data(id)
	var out: Array[Dictionary] = []
	var slot := str(e.get("slot", ""))
	var redraw := func(f: Callable) -> Callable:
		return func() -> void:
			_pick(e)
			f.call()
			_draw()
	if slot != "":
		out.append({"label": "Take off", "call": redraw.call(func() -> void: ch.unequip_item(id))})
	else:
		for s: String in ["armor", "main_hand", "off_hand"] + MagicItems.WORN_SLOTS:
			if InventoryScreen.slot_takes(s, data):
				var verb := "Wear" if s == "armor" or s in MagicItems.WORN_SLOTS else ("Hold" if MagicItems.is_held(data) and not Gear.is_weapon(data) else "Equip")
				out.append({"label": "%s (%s)" % [verb, slot_name(s).to_lower()], "call": redraw.call(func() -> void: _equip(ch, id, s))})
		for s2: String in ["main_hand", "off_hand"]:
			if InventoryScreen.slot_takes(s2, data) and MagicItems.worn_slot(data) == "":
				out.append({"label": "Set II (%s)" % slot_name(s2).to_lower(), "call": redraw.call(func() -> void: _set_weapon_2(ch, id, s2))})
	if str(data.get("category", "")) in QUICK_CATEGORIES:
		if id in ch.quick_slots:
			out.append({"label": "Off the quick slots", "call": redraw.call(func() -> void: ch.quick_slots.erase(id))})
		else:
			out.append({"label": "Keep to hand (quick slot)", "call": redraw.call(func() -> void: _set_quick(ch, id, QUICK_SLOTS))})
	var quest := InventoryScreen.is_quest(data)
	var n := int(e.get("qty", 1))
	for i in st.party.size():
		if i != index:
			var other := st.party[i]
			out.append({"label": "Give to %s%s" % [other.name.get_slice(" ", 0), " (all %d)" % n if n > 1 else ""],
				"call": redraw.call(func() -> void: _move(ch, e, other, n))})
	if not quest:
		out.append({"label": "Send to the stash%s" % (" (all %d)" % n if n > 1 else ""), "call": redraw.call(func() -> void: _to_stash(ch, e, n))})
		var junk := InventoryScreen.is_junk(e)
		out.append({"label": "Not junk" if junk else "Mark as junk", "call": redraw.call(func() -> void: InventoryScreen.set_junk(ch, id, not junk))})
	if n > 1:
		out.append({"label": "Split the stack in two", "call": redraw.call(func() -> void: split(ch, e, n / 2))})
	if not quest:
		var drop := func() -> void:
			if str(e.get("slot", "")) != "" and n <= 1:
				ch.unequip_item(id)
			ch.remove_one(id, e)
			_forget_gone(ch, id)
		out.append({"label": "Drop one", "call": redraw.call(drop)})
	return out


## Splits `n` off stack `e` into a stack of its own in the same pack (to drag it somewhere on its own).
static func split(ch: Character, e: Dictionary, n: int) -> Dictionary:
	if n <= 0 or n >= int(e.get("qty", 1)):
		return {}
	e["qty"] = int(e["qty"]) - n
	var part := Character.entry_state(e)
	part["id"] = str(e["id"])
	part["qty"] = n
	part["slot"] = ""
	ch.inventory.insert(ch.inventory.find(e) + 1, part)
	return part


func _open_menu(acts: Array[Dictionary], at: Vector2) -> void:
	if acts.is_empty():
		return
	var m := PopupMenu.new()
	for i in acts.size():
		m.add_item(str(acts[i]["label"]), i)
	m.id_pressed.connect(func(i: int) -> void:
		Audio.sfx("click")
		(acts[i]["call"] as Callable).call())
	m.popup_hide.connect(m.queue_free)
	add_child(m)
	m.popup(Rect2i(Vector2i(at), Vector2i(10, 10)))


# --- Search, filters and marks (U3) ---------------------------------------------------------------------

## Whether the filter tab, the New or Junk mark and the search box all keep this entry. `data` is what it shows as (a
## disguised item is found by what it passes for).
func _passes(e: Dictionary, data: Dictionary) -> bool:
	return InventoryScreen.in_filter(filter, data) and (marks == "" or bool(e.get(marks, false))) \
		and InventoryScreen.matches(search, data, e)


static func in_filter(name_: String, data: Dictionary) -> bool:
	var cat := str(data.get("category", ""))
	match name_:
		"Magic":
			return not (data.get("magic", {}) as Dictionary).is_empty()
		"Gear":
			for cats: Variant in FILTER_CATEGORIES.values():
				if cat in (cats as Array):
					return false
			return true
		"All":
			return true
	return cat in (FILTER_CATEGORIES.get(name_, []) as Array)


## The search box: every word typed must appear in the item's name, its kind or its rarity ("rare ring", "potion").
static func matches(text: String, data: Dictionary, e: Dictionary = {}) -> bool:
	if text.strip_edges() == "":
		return true
	var hay := " ".join([MagicItems.display_name(data, e), str(data.get("category", "")),
		str((data.get("magic", {}) as Dictionary).get("rarity", "")).replace("_", " "),
		"magic" if not (data.get("magic", {}) as Dictionary).is_empty() else ""]).to_lower()
	for word in text.to_lower().split(" ", false):
		if not hay.contains(word):
			return false
	return true


## Quest items (a key, St. Andral's bones) and the three treasures (`quest_locked`) can't be dropped, stashed, sold or
## marked as junk.
static func is_quest(data: Dictionary) -> bool:
	return bool(data.get("quest", false)) or bool(data.get("quest_locked", false)) or str(data.get("category", "")) == "quest"


## Junk (U3): a player's mark on an entry, kept when it changes hands; a merchant's Sell all junk sells it.
static func can_be_junk(data: Dictionary) -> bool:
	return not is_quest(data)


static func is_junk(e: Dictionary) -> bool:
	return bool(e.get("junk", false))


## Marks (or unmarks) every carried `item_id` of `ch` as junk.
static func set_junk(ch: Character, item_id: String, on: bool) -> void:
	for e in ch.inventory:
		if str(e["id"]) == item_id:
			if on:
				e["junk"] = true
			else:
				e.erase("junk")


## The search box, and the New and Junk marks as toggles with how many of each the pack holds.
func _search_row(ch: Character) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# A gilt magnifying glass before the box.
	row.add_child(UiParts.drawn(Vector2(24, 30), func(c: Control) -> void:
		var at := Vector2(10, c.size.y / 2.0 - 2.0)
		c.draw_arc(at, 7.0, 0.0, TAU, 24, Look.color("gilt"), 2.0, true)
		c.draw_line(at + Vector2(5, 5), at + Vector2(12, 12), Look.color("gilt"), 3.0, true)
		UiParts.diamond(c, at, 2.5, Look.color("gilt_light"), true)))
	var box := LineEdit.new()
	box.placeholder_text = "Search the pack"
	box.text = search
	box.clear_button_enabled = true
	box.custom_minimum_size = Vector2(250, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_font_size_override("font_size", 15)
	box.add_theme_color_override("clear_button_color", Look.color("gilt"))
	box.add_theme_color_override("clear_button_color_pressed", Look.color("gilt_light"))
	# Only the grid redraws as the text changes, so the box keeps its focus and caret.
	box.text_changed.connect(func(t: String) -> void:
		search = t
		_fill_list())
	row.add_child(box)
	var counts := {"new": 0, "junk": 0}
	for e in ch.inventory:
		if int(e["qty"]) > 0:
			for k: String in counts:
				if bool(e.get(k, false)):
					counts[k] = int(counts[k]) + 1
	for m: Array in [["new", "New", "Arrived since you last looked"], ["junk", "Junk", "Marked to sell: a merchant's Sell all junk takes them"]]:
		var key := str(m[0])
		var b := UiParts.small_button("%s %d" % [m[1], int(counts[key])], func() -> void:
			marks = "" if marks == key else key
			_draw())
		b.tooltip_text = str(m[2])
		if marks == key:
			UiParts.light_up(b)
		row.add_child(b)
	return row


## The backpack's tiles the filter, marks and search keep, sorted; with Junk shown, what the junk adds up to.
func _fill_list() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		_tiles.erase(c)
		c.queue_free()
	for c in _list_foot.get_children():
		c.queue_free()
	var ch := _ch()
	var rows: Array[Dictionary] = []
	for i in ch.inventory.size():
		var e := ch.inventory[i]
		if int(e["qty"]) <= 0:
			continue
		var data := Compendium.shared().item_data(str(e["id"]))
		if not _passes(e, MagicItems.shown_data(data, e)):
			continue
		rows.append({"e": e, "d": data, "i": i})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := a["d"] as Dictionary
		var db := b["d"] as Dictionary
		match sort_by:
			"weight":
				return float(da.get("weight_lb", 0)) > float(db.get("weight_lb", 0))
			"value":
				return float(da.get("cost_gp", 0)) > float(db.get("cost_gp", 0))
			"newest":
				# What's new first, then the latest to arrive.
				var na := bool((a["e"] as Dictionary).get("new", false))
				var nb := bool((b["e"] as Dictionary).get("new", false))
				return na if na != nb else int(a["i"]) > int(b["i"])
		return MagicItems.display_name(da, a["e"] as Dictionary) < MagicItems.display_name(db, b["e"] as Dictionary))
	if rows.is_empty():
		var why := "Nothing here yet."
		if search.strip_edges() != "":
			why = "Nothing in %s's pack matches \"%s\"." % [ch.name.get_slice(" ", 0), search.strip_edges()]
		elif marks == "junk":
			why = "Nothing marked as junk. Right-click an item and choose Mark as junk."
		elif marks == "new":
			why = "Nothing new since you last looked."
		_list_foot.add_child(UiKit.label(why, 15, "bone", 540))
	for r in rows:
		if view == "doll":
			var t := ItemTile.make(TILE)
			_fill_tile(t, ch, r["e"] as Dictionary, {"from": "pack"})
			_grid.add_child(t)
		else:
			_grid.add_child(_row(ch, r["e"] as Dictionary, {"from": "pack"}, _pack_line(ch, r["e"] as Dictionary, r["d"] as Dictionary)))
	if marks == "junk" and not rows.is_empty():
		var weight := 0.0
		var value := 0.0
		for r in rows:
			var q := int((r["e"] as Dictionary)["qty"])
			weight += float((r["d"] as Dictionary).get("weight_lb", 0)) * q
			value += float((r["d"] as Dictionary).get("cost_gp", 0)) * q
		_list_foot.add_child(UiKit.label("%d junk, %s lb, worth %s gp new. A merchant's Sell all junk sells it for less." % [rows.size(),
			_num(weight), _num(value)], 13, "parchment", 540))


## What the pack shows now, as item ids in order (for tests and captures).
func shown_ids() -> Array[String]:
	var out: Array[String] = []
	if _grid == null:
		return out
	for c in _grid.get_children():
		if (c is ItemTile or c is ItemTile.Row) and not c.is_queued_for_deletion():
			out.append(str((c.get("payload") as Dictionary).get("id", "")))
	return out


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Closing the screen: what was shown on each page is no longer new.
func _exit_tree() -> void:
	if st == null:
		return
	for m in st.party:
		if _viewed.has(m.id):
			for e in m.inventory:
				e.erase("new")


func _draw_card() -> void:
	for c in _card.get_children():
		c.queue_free()
	if _note != "":
		_card.add_child(UiParts.row(UiKit.label(_note, 14, _note_colour, 400)))
	if selected == "" or _entry(selected).is_empty():
		_card.add_child(UiKit.label("Pick an item to see what it does for %s. Drag it onto a slot to wear it, onto a chip to give it, or into the stash; right-click for more." % _ch().name.get_slice(" ", 0), 15, "bone", 420))
		return
	var ch := _ch()
	var data := Compendium.shared().item_data(selected)
	# A disguised item (a Potion of Poison) shows what it passes for until it's identified.
	var shown := MagicItems.shown_data(data, _entry(selected))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	UiParts.add_icon(head, "item", str(shown.get("id", selected)), 48.0)
	var t := UiKit.title(MagicItems.display_name(data, _entry(selected)))
	t.add_theme_font_size_override("font_size", 26)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(360, 0)
	head.add_child(t)
	_card.add_child(head)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 6)
	for f: Array in [["Kind", str(shown.get("category", "")).capitalize()], ["Weight", "%s lb" % str(shown.get("weight_lb", 0))],
			["Value", "%s gp" % str(shown.get("cost_gp", 0))]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.add_child(UiParts.caption(str(f[0]), 10))
		box.add_child(UiParts.figure(str(f[1]), 16))
		var tile := UiParts.card("ui_black", "gilt_dark", 0.8, 5)
		tile.custom_minimum_size = Vector2(110, 0)
		tile.add_child(box)
		facts.add_child(tile)
	_card.add_child(facts)
	if Gear.is_weapon(data):
		var p := WeaponProfile.build(ch, data)
		_card.add_child(UiKit.label("For %s: %s" % [ch.name.get_slice(" ", 0), p.describe()], 15, "vellum", 420))
		if not ch.weapon_proficient(data):
			_card.add_child(UiKit.label("~ Not proficient: no Proficiency Bonus on attacks", 14, "gilt", 420))
		var w := data.get("weapon", {}) as Dictionary
		if str(w.get("mastery", "")) != "":
			var usable := str(w["mastery"]) in ch.weapon_masteries or selected in ch.weapon_masteries
			_card.add_child(UiKit.label("Mastery %s: %s%s" % [str(w["mastery"]).capitalize(), ActionCatalog.MASTERY_TEXT.get(str(w["mastery"]), ""),
				"" if usable else " (not one of your masteries)"], 14, "moonlight" if usable else "bone", 420))
		var main := ch.equipped("main_hand")
		if Gear.is_weapon(main) and str(main["id"]) != selected:
			var mp := WeaponProfile.build(ch, main)
			var diff := p.average_damage() - mp.average_damage()
			_card.add_child(UiKit.label("Compared with your %s: %s average damage (%.1f vs %.1f)" % [main["name"], ("▲ %.1f more" % diff) if diff > 0 else ("▼ %.1f less" % -diff) if diff < 0 else "the same", p.average_damage(), mp.average_damage()], 14, "vellum", 420))
	elif Gear.is_armor(data):
		var arm := data["armor"] as Dictionary
		# Light armor has no Dexterity cap: its data says `"dex_cap": null` (owner report 2026-10-07: reading null as a
		# number stopped the card short of its Actions, so leather armor showed no Unequip).
		var dex_cap := 99 if arm.get("dex_cap") == null else int(arm["dex_cap"])
		_card.add_child(UiKit.label("%s armor: AC %d%s%s" % [str(arm["kind"]).capitalize(), int(arm.get("base_ac", 10)),
			"" if dex_cap == 0 else " + Dex" + (" (max %d)" % dex_cap if dex_cap < 10 else ""),
			", Stealth Disadvantage" if bool(arm.get("stealth_disadvantage", false)) else ""], 15, "vellum", 420))
		if not ch.trained_for(data):
			_card.add_child(UiKit.label("~ No training: Disadvantage on Strength and Dexterity rolls, and no spellcasting", 14, "gilt", 420))
		if int(arm.get("strength", 0)) > ch.ability_score(&"str"):
			_card.add_child(UiKit.label("~ Needs Strength %d: Speed -10 ft" % int(arm["strength"]), 14, "gilt", 420))
	_card.add_child(UiParts.section("Description"))
	_card.add_child(UiKit.label(str(shown.get("text", shown.get("summary", ""))), 14, "vellum", 420))
	if not (data.get("spells", []) as Array).is_empty():
		_spellbook_card(data.get("spells", []) as Array)
	# Magic items: rarity and attunement (three items at most; attuning and ending it are instant: owner house rule
	# 2026-10-07, docs/contracts/magic_items.md).
	var magic := shown.get("magic", {}) as Dictionary
	if not magic.is_empty():
		var needs: Variant = magic.get("attunement", false)
		var req := ""
		if needs is String:
			req = " (requires attunement %s)" % needs
		elif needs is bool and bool(needs):
			req = " (requires attunement)"
		_card.add_child(UiKit.label("%s magic item%s" % [str(magic.get("rarity", "")).replace("_", " ").capitalize(), req], 14, "moonlight", 420))
		if req != "":
			if selected in ch.attuned:
				var end_why := ch.end_attunement_blocker(selected)
				var end := UiKit.button("End attunement", func() -> void:
					ch.end_attunement(selected)
					_draw(), 14)
				end.disabled = end_why != ""
				end.tooltip_text = end_why
				_card.add_child(end)
			else:
				var why := ch.attune_blocker(selected)
				var att := UiKit.button("Attune", func() -> void:
					ch.attune(selected)
					_draw(), 14)
				att.disabled = why != ""
				att.tooltip_text = why
				_card.add_child(att)
			_card.add_child(UiKit.label("Attuned: %d of %d" % [ch.attuned.size(), Character.MAX_ATTUNED], 13, "parchment"))
		_identify_row(ch, data)
		_magic_card(ch, data)
	# Actions
	_card.add_child(UiParts.section("Actions"))
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("separation", 6)
	var entry := _entry(selected)
	var slot := str(entry.get("slot", ""))
	if slot != "":
		acts.add_child(UiKit.button("Unequip", func() -> void:
			ch.unequip_item(selected)
			_draw(), 14))
	elif Gear.is_weapon(data):
		acts.add_child(UiKit.button("Equip (main hand)", func() -> void:
			_equip(ch, selected, "main_hand")
			_draw(), 14))
		if "light" in Gear.weapon_props(data):
			acts.add_child(UiKit.button("Equip (off hand)", func() -> void:
				_equip(ch, selected, "off_hand")
				_draw(), 14))
	elif Gear.is_armor(data):
		acts.add_child(UiKit.button("Wear", func() -> void:
			ch.equip(selected, "armor")
			_draw(), 14))
	elif Gear.is_shield(data):
		acts.add_child(UiKit.button("Equip (off hand)", func() -> void:
			_equip(ch, selected, "off_hand")
			_draw(), 14))
	elif MagicItems.worn_slot(data) != "":
		acts.add_child(UiKit.button("Wear (%s)" % MagicItems.SLOT_NAMES.get(MagicItems.worn_slot(data), ""), func() -> void:
			ch.wear(selected)
			_draw(), 14))
	elif MagicItems.is_held(data):
		acts.add_child(UiKit.button("Hold (main hand)", func() -> void:
			ch.equip(selected, "main_hand")
			_draw(), 14))
		acts.add_child(UiKit.button("Hold (off hand)", func() -> void:
			ch.equip(selected, "off_hand")
			_draw(), 14))
	# Using it outside a fight: a potion's drink, a wand's Detect Magic, a manual's study (story/field_items.gd).
	var disguised := MagicItems.is_disguised(data, entry)
	for opt in FieldItems.options(st.party, ch, selected, Dice.roller):
		var label := "Use: %s" % str(opt["label"]) if str(opt["label"]) != "Drink" else "Drink"
		var choices := opt.get("choices", []) as Array
		var pid := str(opt["power_id"])
		if disguised:
			opt["text"] = str(shown.get("summary", ""))
		if opt.has("store"):
			_store_picker(acts, opt)
		elif choices.is_empty():
			var ub := UiKit.button(label, func() -> void: _use_power(pid, {}), 14)
			ub.disabled = not bool(opt["legal"])
			ub.tooltip_text = str(opt["reason"]) if not bool(opt["legal"]) else str(opt.get("text", ""))
			acts.add_child(ub)
		else:
			for chv: Variant in choices:
				var cv := str(chv)
				var cb := UiKit.button("%s: %s" % [label, cv.replace("_", " ").capitalize()], func() -> void: _use_power(pid, {"choice": cv}), 13)
				cb.disabled = not bool(opt["legal"])
				cb.tooltip_text = str(opt["reason"]) if not bool(opt["legal"]) else str(opt.get("text", ""))
				acts.add_child(cb)
	# Weapon set II and the quick slots (U11).
	if slot == "" and MagicItems.worn_slot(data) == "":
		for s2: String in ["main_hand", "off_hand"]:
			if InventoryScreen.slot_takes(s2, data) and str(ch.weapon_set_2.get(s2, "")) != selected:
				var b2 := UiParts.small_button("Set II (%s)" % slot_name(s2).to_lower(), func() -> void:
					_set_weapon_2(ch, selected, s2)
					_draw())
				b2.tooltip_text = "Hold it when you swap weapon sets (↻ on the doll)"
				acts.add_child(b2)
	if str(data.get("category", "")) in QUICK_CATEGORIES:
		var kept := selected in ch.quick_slots
		var qb := UiParts.small_button("Off the quick slots" if kept else "Keep to hand", func() -> void:
			if kept:
				ch.quick_slots.erase(selected)
			else:
				_set_quick(ch, selected, QUICK_SLOTS)
			_draw())
		qb.tooltip_text = "On the Common tab of %s's hotbar in fights" % ch.name.get_slice(" ", 0)
		qb.disabled = not kept and ch.quick_slots.size() >= QUICK_SLOTS
		if qb.disabled:
			qb.tooltip_text = "The four quick slots are full: drag one off first"
		acts.add_child(qb)
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	_card.add_child(acts)
	# A stack: how many the buttons below move, and splitting some off to drag on their own.
	var n := int(entry.get("qty", 1))
	if n > 1:
		_amount = clampi(_amount, 1, n)
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 6)
		step.add_child(UiParts.caption("How many", 11))
		var less := UiParts.small_button("◀", func() -> void:
			_amount = maxi(1, _amount - 1)
			_draw_card())
		less.disabled = _amount <= 1
		step.add_child(less)
		var count := UiParts.figure("%d of %d" % [_amount, n], 16, "gilt_light")
		count.custom_minimum_size = Vector2(64, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.add_child(count)
		var more := UiParts.small_button("▶", func() -> void:
			_amount = mini(n, _amount + 1)
			_draw_card())
		more.disabled = _amount >= n
		step.add_child(more)
		step.add_child(UiParts.small_button("All", func() -> void:
			_amount = n
			_draw_card()))
		var cut := UiParts.small_button("Split off", func() -> void:
			var part := InventoryScreen.split(ch, entry, _amount)
			_say("Split %d off into a stack of its own." % _amount)
			_picked = part
			_draw())
		cut.disabled = _amount >= n
		cut.tooltip_text = "A stack of its own in the pack, to drag somewhere by itself"
		step.add_child(cut)
		_card.add_child(step)
	var give := HBoxContainer.new()
	give.add_theme_constant_override("separation", 6)
	give.add_child(UiParts.caption("Give to", 11))
	for i in st.party.size():
		if i == index:
			continue
		var other := st.party[i]
		give.add_child(UiParts.small_button(other.name.get_slice(" ", 0), func() -> void: _give(other)))
	_card.add_child(give)
	var quest := InventoryScreen.is_quest(data)
	var drop := UiParts.small_button("Drop one", func() -> void:
		if slot != "" and n <= 1:
			ch.unequip_item(selected)
		ch.remove_one(selected, entry)
		_forget_gone(ch, selected)
		if not _carries(ch, entry):
			selected = ""
			_picked = {}
		_draw())
	drop.disabled = quest
	if quest:
		drop.tooltip_text = "Can't drop: needed for a quest"
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.add_child(drop)
	# Into the party stash from anywhere (owner, 2026-10-07); it comes out again at a safe place.
	var stash := UiParts.small_button("Send to the stash", func() -> void:
		_to_stash(ch, entry, _amount if n > 1 else 1)
		_draw())
	stash.disabled = quest
	stash.tooltip_text = "Can't: needed for a quest" if quest else ("Into the party stash; take it out here or at any safe place" if _stash_open()
		else "Into the party stash; take it out at an inn or a home")
	bottom.add_child(stash)
	var junk := InventoryScreen.is_junk(entry)
	var jb := UiParts.small_button("Not junk" if junk else "Mark as junk", func() -> void:
		InventoryScreen.set_junk(ch, selected, not junk)
		_draw())
	jb.disabled = not InventoryScreen.can_be_junk(data)
	jb.tooltip_text = "Can't: needed for a quest" if jb.disabled else ("Keep it out of Sell all junk" if junk
		else "A merchant's Sell all junk sells it with the rest")
	bottom.add_child(jb)
	_card.add_child(bottom)


## A found spellbook (item `spells`): the list for anyone to read, and a Copy button for each Wizard in the party
## (Character.copy_spell, 2024 rules: a level they can prepare, 2 hours and 50 gp of inks per spell level, outside
## fights and conversations). A copied spell is prepared from the spellbook like the rest.
func _spellbook_card(book: Array) -> void:
	_card.add_child(UiParts.section("Spells in this book"))
	var wizards: Array[Character] = []
	for m in st.party:
		if m.spellbook_class() != "":
			wizards.append(m)
	if wizards.is_empty():
		_card.add_child(UiKit.label("Nobody in the party keeps a spellbook. A Wizard could copy these into theirs.", 13, "parchment", 420))
	var calm := ModeController.mode == ModeController.Mode.EXPLORATION
	var last_level := -1
	# By spell level, alphabetical within (SpellGroups), a small heading over each level.
	for sp: Variant in SpellGroups.sorted(book, func(x: Variant) -> String: return str(x)):
		var sid := str(sp)
		var s := Compendium.shared().spell_data(sid)
		var lv := int(s.get("level", 0))
		if lv != last_level:
			last_level = lv
			_card.add_child(UiParts.caption(SpellGroups.heading(lv).to_upper(), 11, "gilt"))
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		UiParts.add_icon(head, "spell", sid, 24.0)
		var name := UiKit.label(str(s.get("name", sid)), 14, "vellum", 380)
		name.tooltip_text = str(s.get("summary", ""))
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		head.add_child(name)
		_card.add_child(head)
		if wizards.is_empty():
			continue
		var acts := HFlowContainer.new()
		acts.add_theme_constant_override("h_separation", 6)
		var cost := lv * Character.COPY_GP_PER_LEVEL
		var minutes := lv * Character.COPY_MINUTES_PER_LEVEL
		for w in wizards:
			var why := w.copy_spell_problem(sid)
			if why == "" and st.gold < cost:
				why = "Needs %d gp of inks; the party has %d" % [cost, int(st.gold)]
			if why == "" and not calm:
				why = "Not during a fight or a conversation"
			var label := "In %s's book" % w.name.get_slice(" ", 0) if why == "Already in the spellbook" else "%s copies it (%d h, %d gp)" % [w.name.get_slice(" ", 0), minutes / 60, cost]
			var b := UiParts.small_button(label, func() -> void:
				if w.copy_spell(sid):
					st.gold -= cost
					st.advance_minutes(minutes)
				_draw())
			b.disabled = why != ""
			b.tooltip_text = why if why != "" else "Into %s's spellbook; prepare it from there after a Long Rest." % w.name.get_slice(" ", 0)
			acts.add_child(b)
		_card.add_child(acts)


## Things come out of the stash only where it's safe to rest (an inn, a home); they go in from anywhere.
func _stash_open() -> bool:
	return str(Compendium.shared().get_entry("locations", st.location).get("rest", "")) == "safe"


## The picked entry when it's this item and still carried, else the first carried one.
func _entry(item_id: String) -> Dictionary:
	if not _picked.is_empty() and str(_picked.get("id", "")) == item_id and _carries(_ch(), _picked):
		return _picked
	for e in _ch().inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			return e
	return {}


func _remove_one(ch: Character, item_id: String) -> void:
	for e: Dictionary in ch.inventory.duplicate():
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			if int(e["qty"]) <= 0:
				ch.inventory.erase(e)
				selected = ""
			return


## Gives the picked item to `other` (as many as the card's How many says, for a stack).
func _give(other: Character) -> void:
	var e := _entry(selected)
	if e.is_empty():
		return
	_move(_ch(), e, other, clampi(_amount, 1, int(e.get("qty", 1))))
	_draw()


## Out of combat, drinking takes no action; the potion's healing rolls with the game's dice.
func _drink() -> void:
	var ch := _ch()
	var data := Compendium.shared().item_data(selected)
	var heal := ((data["effects"] as Array)[0] as Dictionary)["params"] as Dictionary
	var rolled := Dice.roller.roll_expr(str(heal["dice"]), "%s drinks %s" % [ch.name, data["name"]])
	var healed := ch.heal(int(rolled["total"]), str(data["name"]))
	_remove_one(ch, selected)
	if root.has_method("_refresh"):
		root.call("_refresh")
	_draw()
	# Owner report (2026-10-07): "it restored 1 Hit Point". Show the roll and the cap, so a near-full drinker's 1 makes sense.
	var full := " (now at full)" if ch.hp >= ch.max_hp() and healed < int(rolled["total"]) else ""
	_card.add_child(UiKit.label("%s drinks it: rolled %d (%s), regains %d Hit Points%s." % [ch.name, int(rolled["total"]),
		str(heal["dice"]), healed, full], 15, "bile"))


## The rest of a magic item's card: charges, where it must be worn or held, a known curse, what a container holds.
func _magic_card(ch: Character, data: Dictionary) -> void:
	var e := _entry(selected)
	if MagicItems.has_charges(data):
		var spec := MagicItems.charges(data)
		var regain := str(spec.get("regain", ""))
		_card.add_child(UiKit.label("Charges: %d of %d%s" % [int(e.get("charges", 0)), MagicItems.max_charges(data, e),
			(" · regains %s at %s" % [regain, spec.get("when", "dawn")]) if regain != "" else ""], 14, "moonlight", 420))
	if MagicItems.worn_slot(data) != "":
		_card.add_child(UiKit.label("Worn: %s%s" % [MagicItems.SLOT_NAMES.get(MagicItems.worn_slot(data), ""),
			" (working)" if ch.item_active(e) else ""], 13, "parchment", 420))
	elif MagicItems.is_held(data) and not Gear.is_weapon(data):
		_card.add_child(UiKit.label("Works while held in a hand%s" % (" (held)" if ch.item_active(e) else ""), 13, "parchment", 420))
	if MagicItems.is_cursed(data) and selected in ch.attuned and str((data.get("magic", {}) as Dictionary).get("curse", "")) != "":
		_card.add_child(UiKit.label("Cursed: %s" % (data["magic"] as Dictionary)["curse"], 14, "vampire_red", 420))
	for prop: Variant in e.get("artifact_properties", []):
		_card.add_child(UiKit.label("• %s" % (prop as Dictionary).get("text", ""), 13, "lilac", 420))
	if (e.get("gems", {}) as Dictionary).size() > 0:
		var g := e["gems"] as Dictionary
		_card.add_child(UiKit.label("Gems: %s" % ", ".join((g.keys() as Array).map(func(k: Variant) -> String: return "%d %s" % [int(g[k]), str(k).replace("_", " ")])), 13, "lilac", 420))
	if (e.get("beads", []) as Array).size() > 0:
		_card.add_child(UiKit.label("Beads: %s" % ", ".join((e["beads"] as Array).map(func(b: Variant) -> String: return str(b).replace("_", " "))), 13, "lilac", 420))
	if (e.get("patches", []) as Array).size() > 0:
		_card.add_child(UiKit.label("%d patches left" % (e["patches"] as Array).size(), 13, "lilac", 420))
	if (e.get("stored", []) as Array).size() > 0:
		_card.add_child(UiKit.label("Stored: %s" % ", ".join((e["stored"] as Array).map(func(s: Variant) -> String: return Compendium.shared().spell_data(str((s as Dictionary)["spell"])).get("name", "?"))), 13, "lilac", 420))
	# Containers: what's inside, and putting things in.
	if data.has("container"):
		_card.add_child(UiParts.section("Inside"))
		var inside := ch.contents_of(selected)
		if inside.is_empty():
			_card.add_child(UiKit.label("Empty.", 13, "bone"))
		for i in inside.size():
			var it := inside[i] as Dictionary
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			UiParts.add_icon(r, "item", str(it["id"]), 24.0)
			var lbl := UiKit.label(Compendium.shared().display_name("items", str(it["id"])), 14, "vellum")
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(lbl)
			var idx := i
			r.add_child(UiParts.small_button("Take out", func() -> void:
				ch.take_out(selected, idx)
				_draw()))
			_card.add_child(UiParts.row(r))
	else:
		for c0 in ch.inventory:
			var cd := Compendium.shared().item_data(str(c0["id"]))
			if not cd.has("container") or str(c0["id"]) == selected:
				continue
			var cid := str(c0["id"])
			_card.add_child(UiParts.small_button("Put in the %s" % cd.get("name", cid), func() -> void:
				var res := ch.put_in(cid, selected)
				if _entry(selected).is_empty():
					selected = ""
				_draw()
				_show_put_in(res)))


## What happened when something went into a container ("" when it simply went in).
func _show_put_in(res: String) -> void:
	match res:
		"":
			pass
		"rift":
			_card.add_child(UiKit.label("The two extradimensional spaces tear each other open: both are destroyed with everything inside.", 15, "vampire_red", 420))
		"devoured":
			_card.add_child(UiKit.label("Something inside the bag eats it.", 15, "vampire_red", 420))
		_:
			_card.add_child(UiKit.label(res, 14, "flame", 420))


## Ring of Spell Storing: pick who casts which spell into the ring, then store it.
func _store_picker(acts: Control, opt: Dictionary) -> void:
	var pick := OptionButton.new()
	var choices := opt["store"] as Array
	for i in choices.size():
		pick.add_item(str((choices[i] as Dictionary)["label"]), i)
	pick.disabled = choices.is_empty() or not bool(opt["legal"])
	pick.tooltip_text = str(opt["reason"]) if not bool(opt["legal"]) else str(opt.get("text", ""))
	acts.add_child(pick)
	var pid := str(opt["power_id"])
	var b := UiKit.button("Cast it into the ring", func() -> void:
		if pick.selected < 0:
			return
		var c := choices[pick.selected] as Dictionary
		_use_power(pid, {"caster": str(c["caster"]), "spell": str(c["spell"]), "level": int(c["level"])}), 14)
	b.disabled = pick.disabled
	b.tooltip_text = pick.tooltip_text
	acts.add_child(b)


## Identify: a party caster with the spell casts it as a Ritual (no slot); otherwise a Short Rest spent studying the item
## (the Rest screen) does the same. Offered for every magic item not yet identified, so it gives nothing away.
func _identify_row(ch: Character, data: Dictionary) -> void:
	var e := _entry(selected)
	if not MagicItems.can_identify(data, e):
		return
	var caster := _identify_caster()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var b := UiKit.button("Identify (%s casts it as a Ritual: 11 minutes)" % caster.name.get_slice(" ", 0) if caster != null else "Identify", func() -> void:
		var res := FieldCasting.cast_utility(st, caster, "identify", true)
		var msg := _identified(ch, data) if bool(res["ok"]) else "Can't: %s" % res["text"]
		_draw()
		_card.add_child(UiKit.label(msg, 15, "bile" if bool(res["ok"]) else "flame", 420)), 14)
	b.disabled = caster == null
	b.tooltip_text = "Nobody in the party has Identify ready. Studying it through a Short Rest (Rest screen) works too." if caster == null else \
		"Learn what it is, how it works and its charges. A curse stays hidden until someone attunes to it."
	row.add_child(b)
	_card.add_child(row)


## Marks the selected item identified and says what it turned out to be.
func _identified(ch: Character, data: Dictionary) -> String:
	var seemed := MagicItems.display_name(data, _entry(selected))
	var name_ := ch.identify(selected)
	return "It's exactly what it seems: %s." % name_ if name_ == seemed else "It isn't a %s at all: it's a %s!" % [seemed, name_]


## A living party member who can cast Identify now (prepared, or as a Ritual), or null.
func _identify_caster() -> Character:
	for m in st.party:
		for o in FieldCasting.utility_options(st.party, m, Dice.roller):
			if str(o["id"]) == "identify" and bool(o["legal"]) and bool(o["ritual"]):
				return m
	return null


## Changing prepared spells (and a Wizard's cantrip) after an item's Long Rest, as the rest screen offers.
func _open_prepare() -> void:
	var ps := PrepareScreen.new()
	ps.earlier = _prepared_before
	add_child(ps)
	ps.open(root, st, 0)


## Uses a magic item's power outside a fight (story/field_items.gd) and shows what happened.
func _use_power(power_id: String, opts: Dictionary) -> void:
	var ch := _ch()
	var res := FieldItems.use(st, ch, selected, power_id, ch, Dice.roller, opts)
	if bool(res.get("ok", false)) and str(res.get("effect", "")) == "long_rest":
		_prepared_before = PrepareScreen.snapshot(st)
	# What it does to the place the party is in (a Wand of Secrets' pointing, a Wand of Magic Detection's Detect Magic).
	if bool(res.get("ok", false)) and str(res.get("effect", "")) != "" and root != null and root.get("view") != null:
		(root.get("view") as LocationView).apply_spell_effect(str(res["effect"]))
	if _entry(selected).is_empty():
		selected = ""
	if root.has_method("_refresh"):
		root.call("_refresh")
	_draw()
	_card.add_child(UiKit.label(str(res.get("text", "")) if bool(res.get("ok", false)) else "Can't: %s" % res.get("text", ""), 15,
		"bile" if bool(res.get("ok", false)) else "flame", 420))
