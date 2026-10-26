class_name InventoryScreen
extends CanvasLayer
## The inventory (docs/ui/inventory.md inv_01, plan §5.6 "Inventory"), one character at a time:
## - the paper doll (U11): every slot in the shape of a person, where it's worn (owner 2026-10-09), the two weapon sets
##   with a quick swap, the quiver and the spellcasting focus, four quick slots for consumables (the fight's hotbar
##   shows them on its Common tab), the load and attunements;
## - the backpack as a list with filters (Potions and Quest items have tabs of their own), the New, Junk and Attuned
##   marks, a Rarity filter (any of the six, with the rest), sorting and a search box (U3), a box in the colour of an
##   item's rarity round its picture, and the party stash under it: things go in from anywhere and come out only at a
##   safe place (Q7, owner 2026-10-07);
## - the item card: what the item does for this character compared with what's equipped, and its actions (equip, use,
##   give, split the stack, send to the stash, mark as junk, drop). Quest items can't be dropped, stashed or sold.
## Everything drags: a pack item onto a doll slot, a weapon set or a quick slot; anything onto another character's chip
## (it goes to them), the stash or back into the pack. Right-click a tile for its actions. "New" is what arrived since
## the character's page was last opened (Character.add_item marks it; closing this screen clears it for every page shown).
## The bag is always a list (owner 2026-10-09: "keep the inventory as list always").

const FILTERS := ["All", "Weapons", "Armor", "Potions", "Scrolls", "Consumables", "Magic", "Gear", "Quest"]
const SORTS := ["name", "weight", "value", "newest"]
## Item categories each filter keeps. Magic is any magic item, whatever its category, and Quest any quest item (is_quest),
## whatever it is otherwise; Gear is everything else that isn't a quest item. Potions and Scrolls (the Spell Scrolls,
## is_spell_scroll, of every level) are not Consumables.
const FILTER_CATEGORIES := {"Weapons": ["weapon", "ammunition"], "Armor": ["armor", "shield", "clothing"],
	"Potions": ["potion"], "Consumables": ["consumable", "scroll"]}
## The paper doll: where each slot's tile sits on the figure (its middle, in the doll's own pixels), every worn slot of
## the 2024 DMG (one of each, two rings: "ring2" is the second), the hands, the quiver ("ammo") and the focus.
const DOLL_SIZE := Vector2(372, 432)
const DOLL_AT := {"head": Vector2(186, 40), "eyes": Vector2(112, 40), "neck": Vector2(186, 106), "cloak": Vector2(102, 122),
	"robe": Vector2(270, 122), "armor": Vector2(186, 178), "wrists": Vector2(102, 188), "hands": Vector2(270, 188),
	"main_hand": Vector2(34, 250), "belt": Vector2(186, 252), "off_hand": Vector2(338, 250), "ring": Vector2(102, 262),
	"ring2": Vector2(270, 262), "ammo": Vector2(102, 332), "focus": Vector2(270, 332), "feet": Vector2(186, 398)}
## Ioun Stones orbit beside the head; weapon set II hangs under the hands, with the swap under it.
const IOUN_AT := Vector2(260, 40)
const SET2_AT := {"main_hand": Vector2(34, 318), "off_hand": Vector2(338, 318)}
const SWAP_AT := Vector2(34, 392)
## Slots kept to hand that aren't worn or wielded (Gear.carry_slot).
const CARRY_SLOTS: Array[String] = ["ammo", "focus"]
## Consumables kept to hand for fights (plan §5.6 "Quick slots").
const QUICK_SLOTS := 4
## The Attuned filter's value of `marks` (the New and Junk marks are keys on the entry itself).
const MARK_ATTUNED := "attuned"
## The rarities of magic items, from the least to the most, for the Rarity filter (MagicItems.rarity's values).
const RARITIES: Array[String] = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]
## The picture's side in a pack row, inside its rarity box.
const ROW_ICON := 30.0
const QUICK_CATEGORIES: Array[String] = ["potion", "consumable", "scroll"]
const DOLL_TILE := Vector2(54, 58)
const STASH_TILE := Vector2(50, 56)

var root: Node
var st: StoryState
var index := 0
var filter := "All"
var sort_by := "name"
## The picked item's id (the card shows it); `_picked` is its own entry when there are several of the same kind.
var selected := ""
## What the search box holds (matched against an item's name, kind and rarity).
var search := ""
## "new" or "junk" shows only items with that mark, "attuned" (MARK_ATTUNED) only what the character is attuned to;
## "" shows everything the filter keeps.
var marks := ""
## The Rarity filter: only magic items of these rarities (any of them) show; empty shows every item. It combines with
## the tab, the mark and the search.
var rarities: Array[String] = []
var _frame: VBoxContainer
var _card: VBoxContainer
## The pack's rows.
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
## The Wizard whose copy of the picked Spell Scroll waits for a second press to confirm ("" for none).
var _scroll_confirm := ""
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
	_frame = UiKit.screen_frame(self, "Inventory", Vector2(1500, 850))
	_draw()


## The pad's LT/RT (PadNav): the previous or next of the party.
func pad_character(step: int) -> void:
	index = posmod(index + step, st.party.size())
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
	_frame.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)   # a tall card (a ring's) shows a 6 px scroll bar: 16 pushed the frame 3 px past its border
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(row)
	row.add_child(_doll(ch))
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

## The paper doll (owner 2026-10-09: the equipped items "in the place where they would be equipped, in the shape of a
## person"): each slot's tile where it's worn, on a figure drawn behind them. The head at the top with the eyes beside
## it and any Ioun Stones orbiting it, the neck under it, a cloak and a robe at the shoulders, armor on the chest,
## bracers and gloves on the forearms, a weapon in each hand with weapon set II stowed under it, a ring by each hand,
## the belt at the waist, the quiver and the spellcasting focus at the hips, and boots at the feet. Under it the quick
## slots and the load.
func _doll(ch: Character) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(DOLL_SIZE.x, 0)
	col.add_theme_constant_override("separation", 6)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	who.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 52.0, ch.hp <= 0, ch.dead))
	var n := UiKit.title(ch.name)
	n.add_theme_font_size_override("font_size", 20)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(n)
	var ac := UiParts.shield(ch.ac_value(), func() -> Control: return UiParts.breakdown_tip(ch.armor_class(), "Armor Class"))
	ac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(ac)
	if not MagicItems.attunement_off:   # Settings, Game, Attunement: unlimited drops the count
		var att := VBoxContainer.new()
		att.add_theme_constant_override("separation", 2)
		att.alignment = BoxContainer.ALIGNMENT_CENTER
		att.add_child(UiParts.caption("Attuned", 10))
		att.add_child(UiParts.pips(Character.MAX_ATTUNED, ch.attuned.size(), "lilac"))
		att.tooltip_text = "Attuned to %d of %d magic items: %s" % [ch.attuned.size(), Character.MAX_ATTUNED,
			", ".join(ch.attuned.map(func(a: String) -> String: return Compendium.shared().display_name("items", a))) if not ch.attuned.is_empty() else "none"]
		att.mouse_filter = Control.MOUSE_FILTER_PASS
		who.add_child(att)
	col.add_child(who)
	var doll := Control.new()
	doll.name = "PaperDoll"
	doll.custom_minimum_size = DOLL_SIZE
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var figure := UiParts.Drawn.new()
	figure.name = "Figure"
	figure.painter = InventoryScreen._paint_figure
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.set_meta("pad_skip", true)
	figure.size = DOLL_SIZE
	doll.add_child(figure)
	for at: String in DOLL_AT:
		var slot := "ring" if at == "ring2" else at
		_place(doll, _slot_tile(ch, slot, 1 if at == "ring2" else 0), DOLL_AT[at] as Vector2)
	# Ioun Stones orbit the head, any number of them: the first two beside it, and how many more.
	var ioun := _worn(ch, "ioun")
	for i in mini(ioun.size(), 2):
		_place(doll, _slot_tile(ch, "ioun", i), IOUN_AT + Vector2(i * (DOLL_TILE.x + 4), 0))
	if ioun.size() > 2:
		var more := UiParts.caption("+%d more" % (ioun.size() - 2), 11, "lilac")
		more.position = IOUN_AT + Vector2(-DOLL_TILE.x / 2.0, DOLL_TILE.y / 2.0 + 2)
		doll.add_child(more)
	# Weapon set II, stowed under the hands, and the swap between the sets.
	for slot2: String in SET2_AT:
		_place(doll, _set2_tile(ch, slot2), SET2_AT[slot2] as Vector2)
	var swap := UiParts.small_button("↻ Swap", func() -> void:
		ch.swap_weapon_sets()
		_say("%s swaps weapons." % ch.name.get_slice(" ", 0))
		_draw())
	swap.tooltip_text = "Take weapon set II in hand: what's in hand now becomes set II (outside fights)"
	doll.add_child(swap)
	swap.position = SWAP_AT - swap.get_combined_minimum_size() / 2.0
	col.add_child(doll)
	col.add_child(UiParts.section("Quick slots", UiKit.label("On the fight's Common tab", 12, "parchment")))
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 6)
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in QUICK_SLOTS:
		quick.add_child(_quick_tile(ch, i))
	col.add_child(quick)
	var cap := ch.carrying_capacity().total()
	var carried := ch.carried_weight()
	var over := carried > cap
	col.add_child(UiParts.bar(carried, cap, 0.0, "%.1f / %d lb%s" % [carried, cap, " · Overloaded" if over else ""],
		"vampire_red" if over else "gilt_dark", func() -> Control: return UiParts.breakdown_tip(ch.carrying_capacity(),
			"Carrying capacity", "%d lb" % cap, "Overloaded: Speed drops." if over else ""), DOLL_SIZE.x))
	return col


## Puts tile `t` on the doll with its middle at `at`.
func _place(doll: Control, t: Control, at: Vector2) -> void:
	doll.add_child(t)
	t.size = DOLL_TILE
	t.position = at - DOLL_TILE / 2.0


## The figure behind the doll's tiles: a dark silhouette rimmed in old gold, head, shoulders, arms reaching down to
## the hands' tiles, and legs down to the boots'.
static func _paint_figure(c: Control) -> void:
	c.draw_set_transform(Vector2(-8, 0))   # drawn for a doll 388 wide, centred on the 372 it is
	var rim := Look.color("gilt_dark")
	var ink := Look.color("ui_oxblood").darkened(0.12)   # solid: see-through limbs would darken where they overlap
	c.draw_circle(Vector2(194, 196), 160.0, Color(Look.color("gilt"), 0.05))
	for pass_: Array in [[rim, 2.5], [ink, 0.0]]:
		var col := pass_[0] as Color
		var g := float(pass_[1])
		c.draw_circle(Vector2(194, 42), 31.0 + g, col)
		c.draw_rect(Rect2(Vector2(181 - g, 68), Vector2(26 + 2 * g, 30)), col)
		var torso := PackedVector2Array([Vector2(150, 94), Vector2(238, 94), Vector2(258, 110), Vector2(246, 162),
			Vector2(226, 250), Vector2(234, 294), Vector2(154, 294), Vector2(162, 250), Vector2(142, 162), Vector2(130, 110)])
		if g > 0.0:
			var grown := Geometry2D.offset_polygon(torso, g)
			if not grown.is_empty():
				torso = grown[0]
		c.draw_colored_polygon(torso, col)
		for limb: Array in [[Vector2(138, 110), Vector2(100, 188), Vector2(56, 246), 21.0],
				[Vector2(250, 110), Vector2(288, 188), Vector2(332, 246), 21.0],
				[Vector2(176, 286), Vector2(172, 344), Vector2(170, 398), 27.0],
				[Vector2(212, 286), Vector2(216, 344), Vector2(218, 398), 27.0]]:
			var w := float(limb[3]) + 2.0 * g
			var pts: Array[Vector2] = [limb[0] as Vector2, limb[1] as Vector2, limb[2] as Vector2]
			for i in 2:
				c.draw_line(pts[i], pts[i + 1], col, w, true)
			for q in pts:
				c.draw_circle(q, w / 2.0, col)


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
		"ammo":
			return "Ammunition"
		"focus":
			return "Spellcasting focus"
	return str(MagicItems.SLOT_NAMES.get(slot, slot.capitalize()))


## A doll tile's caption: the slot's name, short enough for the tile.
static func slot_caption(slot: String) -> String:
	return {"ammo": "Ammo", "focus": "Focus"}.get(slot, slot_name(slot)) as String


## A doll slot: the item worn there (the `nth` of several), or its name when empty. Takes what fits from the pack or
## the stash; drag it out to take it off.
func _slot_tile(ch: Character, slot: String, nth: int) -> ItemTile:
	var t := ItemTile.make(DOLL_TILE)
	t.caption = slot_caption(slot)
	var worn := _worn(ch, slot)
	var e: Dictionary = worn[nth] if nth < worn.size() else {}
	if not e.is_empty():
		_fill_tile(t, ch, e, {"from": "slot", "slot": slot})
		if slot in MagicItems.WORN_SLOTS and not ch.item_active(e):
			t.marks.append("inactive")
	else:
		var how := str({"ammo": "Drag arrows, bolts or other ammunition here to keep them in the quiver.",
			"focus": "Drag a spellcasting focus or a component pouch here: the one this hero casts with."}.get(slot,
			"Drag something that goes here from the pack."))
		t.tip = func() -> Control: return UiParts.rules_tip(slot_name(slot), "Empty", how)
	t.accepts = func(d: Dictionary) -> bool: return fits_slot(d, slot)
	t.dropped = func(d: Dictionary) -> void: _drop_on_slot(d, slot, e)
	return t


## Weapon set II: a weapon (or shield, wand or rod) to hold when the sets are swapped. It stays in the pack meanwhile.
func _set2_tile(ch: Character, slot: String) -> ItemTile:
	var t := ItemTile.make(DOLL_TILE)
	t.caption = "II main" if slot == "main_hand" else "II off"
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
	t.rarity = InventoryScreen.rarity_of(shown)
	if InventoryScreen.is_quest(data):
		t.marks.append("quest")
	elif t.rarity != "":
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


# --- Rows: the pack and the stash as a list (owner, 2026-10-09: the bag is a list) -------------------------

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


## A pack row's content: icon (in a box of its rarity's colour, for a magic item), name and count, its marks (new, junk,
## equipped, quest, attuned, rarity, charges) and weight.
func _pack_line(ch: Character, e: Dictionary, data: Dictionary) -> Control:
	var id := str(e["id"])
	var junk := InventoryScreen.is_junk(e)
	var shown := MagicItems.shown_data(data, e)
	var rarity := InventoryScreen.rarity_of(shown)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	UiParts.add_framed_icon(line, "item", str(shown.get("id", id)), InventoryScreen.rarity_box(rarity), ROW_ICON)
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
		line.add_child(UiParts.pill({"ammo": "Readied", "focus": "Focus"}.get(str(e["slot"]), "Equipped") as String, "moonlight"))
	if id in ch.quick_slots:
		line.add_child(UiParts.pill("Quick", "bile"))
	if InventoryScreen.is_quest(data):
		line.add_child(UiParts.pill("Quest", "flame"))
	if InventoryScreen.is_attuned(ch, e):
		line.add_child(UiParts.pill("Attuned", "lilac"))
	elif ch.idle_for_attunement(e):
		var idle := UiParts.pill("Not attuned", "flame")
		idle.tooltip_text = "Worn, but it does nothing until %s attunes to it." % ch.name.get_slice(" ", 0)
		line.add_child(idle)
	if rarity != "":
		line.add_child(UiParts.pill(InventoryScreen.rarity_name(rarity), ItemTile.rarity_colour(rarity)))
	if MagicItems.has_charges(data):
		line.add_child(UiParts.pill("%d/%d" % [int(e.get("charges", 0)), MagicItems.max_charges(data, e)], "moonlight"))
	var wt := UiKit.label("%s lb" % str(data.get("weight_lb", 0)), 13, "parchment")
	wt.custom_minimum_size = Vector2(52, 0)
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(wt)
	return line


## A stash row: the item and its count, and Take at a safe place; dragged out of the stash only there.
func _stash_row(se: Dictionary, i: int, at_safe: bool, tip: Callable) -> Control:
	var sid := str(se["id"])
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var data := Compendium.shared().item_data(sid)
	UiParts.add_framed_icon(line, "item", sid, InventoryScreen.rarity_box(InventoryScreen.rarity_of(MagicItems.shown_data(data, se))), 24.0)
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
	pack.custom_minimum_size = Vector2(550, 0)   # the doll beside it is 372 wide
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
	inner.add_child(_rarity_row(ch))
	var sorts := HBoxContainer.new()
	sorts.add_theme_constant_override("separation", 4)
	var sort_cap := UiParts.caption("Sort", 11)
	# Room for the lit chip's glow, which covered the caption's last letter (UI QA UI-13).
	sort_cap.custom_minimum_size.x = sort_cap.get_minimum_size().x + 6.0
	sorts.add_child(sort_cap)
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
	var flow := VBoxContainer.new()
	flow.add_theme_constant_override("separation", 4)
	if st.stash.is_empty():
		flow.add_child(UiKit.label("Empty. Drag things here from anywhere, or choose Send to the stash.", 13, "bone", 520))
	for i in st.stash.size():
		var se := st.stash[i]
		var data := Compendium.shared().item_data(str(se["id"]))
		var shown := MagicItems.shown_data(data, se).duplicate()
		shown["name"] = MagicItems.display_name(data, se) + (" ×%d" % int(se["qty"]) if int(se["qty"]) > 1 else "")
		var tip := LootWindow._item_tip(shown)
		if not at_safe:
			var bare := tip
			tip = func() -> Control:
				var c := bare.call() as VBoxContainer
				c.add_child(UiParts.wrapped("In the stash: take it out at an inn or a home.", 13, "flame", UiParts.TIP_WIDTH))
				return c
		flow.add_child(_stash_row(se, i, at_safe, tip))
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


## A field power's button and menu label: "Cast Find Familiar" for a scroll, "Drink", else "Use: <power>".
static func power_label(opt: Dictionary) -> String:
	var label := str(opt["label"])
	return label if label == "Drink" or label.begins_with("Cast ") else "Use: %s" % label


static func slot_takes(slot: String, data: Dictionary) -> bool:
	match slot:
		"armor":
			return Gear.is_armor(data)
		"main_hand":
			return Gear.is_weapon(data) or MagicItems.is_held(data)
		"off_hand":
			return Gear.is_shield(data) or (Gear.is_weapon(data) and "light" in Gear.weapon_props(data)) or MagicItems.is_held(data)
		"ammo", "focus":
			return Gear.carry_slot(data) == slot
	return MagicItems.worn_slot(data) == slot


func fits_set2(d: Dictionary, slot: String) -> bool:
	return str(d.get("from", "")) in ["pack", "slot"] and slot in ["main_hand", "off_hand"] \
		and InventoryScreen.slot_takes(slot, Compendium.shared().item_data(str(d.get("id", ""))))


func fits_quick(d: Dictionary) -> bool:
	return str(d.get("from", "")) in ["pack", "quick"] \
		and str(Compendium.shared().item_data(str(d.get("id", ""))).get("category", "")) in QUICK_CATEGORIES


## What wearing `item_id` costs `ch` when it is armor they have no training with (2024 Armor Training), else "": said the
## moment it goes on, since every spell goes dark with it (owner report 2026-10-18: Liriel in Plate Armor +1).
static func untrained_warning(ch: Character, item_id: String) -> String:
	var data := Compendium.shared().item_data(item_id)
	if not Gear.is_armor(data) or ch.trained_for(data):
		return ""
	return "%s has no training with %s armor: Disadvantage on Strength and Dexterity rolls, and no spells while %s is on." % [
		ch.name.get_slice(" ", 0), str((data["armor"] as Dictionary).get("kind", "")), Compendium.shared().display_name("items", item_id)]


## Puts `item_id` in hand (`slot`), taking off what was there; a two-handed weapon empties the other hand. Armor its
## wearer has no training with says so in the note (untrained_warning).
func _equip(ch: Character, item_id: String, slot: String) -> bool:
	var data := Compendium.shared().item_data(item_id)
	var held := ch.equipped(slot)
	if not held.is_empty() and str(held["id"]) != item_id and ch.take_off_blocker(str(held["id"])) != "":
		_say(ch.take_off_blocker(str(held["id"])), "flame")
		return false
	if slot == "main_hand" and "two_handed" in Gear.weapon_props(data):
		ch.unequip("off_hand")
	if slot == "off_hand" and "two_handed" in Gear.weapon_props(ch.equipped("main_hand")):
		ch.unequip("main_hand")
	if slot in Character.EQUIP_SLOTS:
		ch.unequip(slot)
	var worn := ch.equip(item_id, slot)
	if worn and slot == "armor":
		_warn_untrained(ch, item_id)
	return worn


## Says untrained_warning in the note, when there is one.
func _warn_untrained(ch: Character, item_id: String) -> void:
	var warning := InventoryScreen.untrained_warning(ch, item_id)
	if warning != "":
		_say(warning, "flame")


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
	if not _equip(ch, id, slot):
		_say("%s can't go there." % name_, "flame")
	elif slot != "armor" or InventoryScreen.untrained_warning(ch, id) == "":   # untrained armor said so in _equip
		_say("%s: %s." % [slot_name(slot), name_])
	_draw()


## Back into the pack: taken off, out of set II or a quick slot, or out of the stash.
func _drop_on_pack(d: Dictionary) -> void:
	var ch := _ch()
	match str(d["from"]):
		"slot":
			if ch.take_off_blocker(str(d["id"])) != "":
				_say(ch.take_off_blocker(str(d["id"])), "flame")
			else:
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
	elif _ch().part_blocker(str(d["id"])) != "":
		_say(_ch().part_blocker(str(d["id"])), "flame")
	else:
		var e := d["entry"] as Dictionary
		_move(_ch(), e, other, int(e.get("qty", 1)))
	_draw()


func _drop_on_stash(d: Dictionary) -> void:
	var e := d["entry"] as Dictionary
	if _ch().part_blocker(str(e["id"])) != "":
		_say(_ch().part_blocker(str(e["id"])), "flame")
	else:
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
	_scroll_confirm = ""
	for t in _tiles:
		if is_instance_valid(t):
			t.set("lit", is_same((t.get("payload") as Dictionary).get("entry"), e))
			t.queue_redraw()
	_draw_card()


## Double-click: wear or hold it (into the first slot that takes it), take it off if worn. Never uses it up: a scroll's
## Cast or a potion's Drink is only on the right-click menu and the item card.
func _activate(e: Dictionary) -> void:
	_pick(e)
	for act in actions_for(e):
		if not bool(act.get("use", false)):
			(act["call"] as Callable).call()
			return


## What a right-click offers for entry `e`, first the likeliest: [{label, call}], plus `use` (it uses the item: Cast,
## Drink) and `disabled` with a `tooltip` saying why.
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
	# A cursed item its holder is attuned to stays with them, and cursed armor stays on (Character.part_blocker).
	var stuck := ch.part_blocker(id)
	if slot != "":
		var stays_on := ch.take_off_blocker(id)
		out.append({"label": "Stow" if slot == "ioun" else "Take off", "disabled": stays_on != "", "tooltip": stays_on,
			"call": redraw.call(func() -> void: ch.unequip_item(id))})
	else:
		for s: String in ["armor", "main_hand", "off_hand"] + MagicItems.WORN_SLOTS + CARRY_SLOTS:
			if InventoryScreen.slot_takes(s, data):
				var verb := "Wear" if s == "armor" or s in MagicItems.WORN_SLOTS else ("Hold" if MagicItems.is_held(data) and not Gear.is_weapon(data) else "Equip")
				var label := "%s (%s)" % [verb, slot_name(s).to_lower()]
				if s in CARRY_SLOTS:
					label = "Ready in the quiver" if s == "ammo" else "Carry as the focus"
				elif s == "ioun":
					label = "Toss into orbit"   # a Magic action in a fight (the hotbar's Items tab); free here
				out.append({"label": label, "call": redraw.call(func() -> void: _equip(ch, id, s))})
		for s2: String in ["main_hand", "off_hand"]:
			if InventoryScreen.slot_takes(s2, data) and MagicItems.worn_slot(data) == "":
				out.append({"label": "Set II (%s)" % slot_name(s2).to_lower(), "call": redraw.call(func() -> void: _set_weapon_2(ch, id, s2))})
	# Using it here and now: a scroll's Cast, a potion's Drink, a wand's power (story/field_items.gd); one that can't be
	# used now shows greyed with why.
	for opt in FieldItems.options(st.party, ch, id, Dice.roller, st):
		if opt.has("store") or not (opt.get("choices", []) as Array).is_empty():
			continue   # a pick to make first: the item card's buttons
		var pid := str(opt["power_id"])
		if not bool(opt.get("revive", false)):   # one that brings back the dead is aimed at them (_guest_uses)
			out.append({"label": InventoryScreen.power_label(opt), "use": true, "disabled": not bool(opt["legal"]), "tooltip": str(opt["reason"]),
				"call": func() -> void:
					_pick(e)
					_use_power(pid, {})})
		for gu in _guest_uses(data, opt):
			var gwhy := str(gu.get("why", ""))
			out.append({"label": str(gu["label"]), "use": true, "disabled": not bool(opt["legal"]) or gwhy != "",
				"tooltip": gwhy if gwhy != "" else str(opt["reason"]),
				"call": func() -> void:
					_pick(e)
					_use_on_guest(pid, gu)})
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
				"disabled": stuck != "", "tooltip": stuck, "call": redraw.call(func() -> void: _move(ch, e, other, n))})
	if not quest:
		out.append({"label": "Send to the stash%s" % (" (all %d)" % n if n > 1 else ""), "disabled": stuck != "", "tooltip": stuck,
			"call": redraw.call(func() -> void: _to_stash(ch, e, n))})
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
		out.append({"label": "Drop one", "disabled": stuck != "", "tooltip": stuck, "call": redraw.call(drop)})
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
		if bool(acts[i].get("disabled", false)):
			m.set_item_disabled(i, true)
			m.set_item_tooltip(i, str(acts[i].get("tooltip", "")))
	m.id_pressed.connect(func(i: int) -> void:
		Audio.sfx("click")
		(acts[i]["call"] as Callable).call())
	m.popup_hide.connect(m.queue_free)
	add_child(m)
	m.popup(Rect2i(Vector2i(at), Vector2i(10, 10)))


# --- Search, filters and marks (U3) ---------------------------------------------------------------------

## Whether the filter tab, the New, Junk or Attuned mark, the Rarity filter and the search box all keep this entry.
## `data` is what it shows as (a disguised item is found by what it passes for).
func _passes(e: Dictionary, data: Dictionary) -> bool:
	return InventoryScreen.in_filter(filter, data) and _has_mark(e) and _has_rarity(data) \
		and InventoryScreen.matches(search, data, e)


## Whether the Rarity filter keeps an item shown as `data`: no filter keeps everything, else the item has to be magic
## and of one of the chosen rarities.
func _has_rarity(data: Dictionary) -> bool:
	return rarities.is_empty() or InventoryScreen.rarity_of(data) in rarities


## Whether entry `e` has the mark `marks` asks for: New or Junk on the entry, or Attuned for the character shown.
func _has_mark(e: Dictionary) -> bool:
	match marks:
		"":
			return true
		MARK_ATTUNED:
			return InventoryScreen.is_attuned(_ch(), e)
	return bool(e.get(marks, false))


static func in_filter(name_: String, data: Dictionary) -> bool:
	var cat := str(data.get("category", ""))
	match name_:
		"Magic":
			return not (data.get("magic", {}) as Dictionary).is_empty()
		"Quest":
			return is_quest(data)
		"Scrolls":
			return is_spell_scroll(data)
		"Consumables":
			return cat in (FILTER_CATEGORIES["Consumables"] as Array) and not is_spell_scroll(data)
		"Gear":
			if is_quest(data):
				return false
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


## Whether an item is a Spell Scroll of any level: the bare Spell Scroll, a scroll that only says its level ("Spell Scroll
## (Level 1)", found in the story's loot before it picks a spell) or one holding a particular spell
## ("spell_scroll__fireball", found or bought). A Scroll of Protection is a scroll but no Spell Scroll.
static func is_spell_scroll(data: Dictionary) -> bool:
	if str(data.get("category", "")) != "scroll":
		return false
	return data.has("scroll_spell") or str(data.get("template_id", "")) == "spell_scroll" or str(data.get("id", "")).begins_with("spell_scroll")


## A magic item's rarity as it shows ("common" to "artifact"); "" for anything that isn't magic.
static func rarity_of(shown: Dictionary) -> String:
	return "" if (shown.get("magic", {}) as Dictionary).is_empty() else MagicItems.rarity(shown)


## The colour of the box round a picture (UiParts.framed_icon): its rarity's, clear for an item with none.
static func rarity_box(rarity: String) -> Color:
	return ItemTile.rarity_edge(rarity) if rarity != "" else Color.TRANSPARENT


## "Very Rare" for "very_rare", as the tags and the item card say it.
static func rarity_name(rarity: String) -> String:
	return rarity.replace("_", " ").capitalize()


## Whether `ch` is attuned to entry `e`'s item, for the Attuned filter and tag: it needs attunement and they are
## attuned to it, or it works for them all the same (Character.item_active), so with the attunement limit lifted the
## filter lists every worn magic item that would have needed attuning.
static func is_attuned(ch: Character, e: Dictionary) -> bool:
	# The item's own word (asks_attunement), since with the Unlimited option no item needs it any more.
	if int(e.get("qty", 0)) <= 0 or not MagicItems.asks_attunement(Compendium.shared().item_data(str(e["id"]))):
		return false
	if MagicItems.attunement_off:
		return ch.item_active(e)
	return str(e["id"]) in ch.attuned or ch.item_active(e)


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


## The search box, and the New, Junk and Attuned marks as toggles with how many of each the pack holds.
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
	box.custom_minimum_size = Vector2(150, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_font_size_override("font_size", 15)
	box.add_theme_color_override("clear_button_color", Look.color("gilt"))
	box.add_theme_color_override("clear_button_color_pressed", Look.color("gilt_light"))
	# Only the grid redraws as the text changes, so the box keeps its focus and caret.
	box.text_changed.connect(func(t: String) -> void:
		search = t
		_fill_list())
	row.add_child(box)
	var counts := {"new": 0, "junk": 0, MARK_ATTUNED: 0}
	for e in ch.inventory:
		if int(e["qty"]) > 0:
			for k: String in ["new", "junk"]:
				if bool(e.get(k, false)):
					counts[k] = int(counts[k]) + 1
			if InventoryScreen.is_attuned(ch, e):
				counts[MARK_ATTUNED] = int(counts[MARK_ATTUNED]) + 1
	for m: Array in [["new", "New", "Arrived since you last looked"], ["junk", "Junk", "Marked to sell: a merchant's Sell all junk takes them"],
			[MARK_ATTUNED, "Attuned", "The magic items %s is attuned to" % ch.name.get_slice(" ", 0)]]:
		var key := str(m[0])
		var b := UiParts.small_button("%s %d" % [m[1], int(counts[key])], func() -> void:
			marks = "" if marks == key else key
			_draw())
		b.tooltip_text = str(m[2])
		if marks == key:
			UiParts.light_up(b)
		row.add_child(b)
	return row


## The Rarity filter: a chip for each rarity, in its colour, that keeps only magic items of the chosen ones (any
## number; none chosen keeps everything). A rarity nothing in the pack has is greyed out. Tooltips give the counts.
func _rarity_row(ch: Character) -> Control:
	var row := HBoxContainer.new()
	row.name = "RarityRow"
	row.add_theme_constant_override("separation", 4)
	var cap := UiParts.caption("Rarity", 11)
	# Room for a lit chip's glow, as the Sort caption has.
	cap.custom_minimum_size.x = cap.get_minimum_size().x + 6.0
	row.add_child(cap)
	var counts := {}
	for r in RARITIES:
		counts[r] = 0
	for e in ch.inventory:
		if int(e["qty"]) > 0:
			var r := InventoryScreen.rarity_of(MagicItems.shown_data(Compendium.shared().item_data(str(e["id"])), e))
			if counts.has(r):
				counts[r] = int(counts[r]) + 1
	for r in RARITIES:
		var on := r in rarities
		var chip := UiParts.small_button(InventoryScreen.rarity_name(r), func() -> void:
			if r in rarities:
				rarities.erase(r)
			else:
				rarities.append(r)
			_draw())
		chip.name = "Rarity_%s" % r
		# Close-set chips: six of them have to fit the pack's width beside the caption.
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := chip.get_theme_stylebox(state) as StyleBoxFlat
			sb.content_margin_left = 7
			sb.content_margin_right = 7
		chip.add_theme_font_size_override("font_size", 12)
		if on:
			UiParts.light_up(chip)
		chip.add_theme_color_override("font_color", Look.color(ItemTile.rarity_colour(r)))
		chip.add_theme_color_override("font_disabled_color", Color(Look.color(ItemTile.rarity_colour(r)), 0.35))
		var n := int(counts[r])
		chip.disabled = n == 0 and not on
		chip.tooltip_text = "%d %s item%s in %s's pack%s" % [n, InventoryScreen.rarity_name(r).to_lower(), "" if n == 1 else "s",
			ch.name.get_slice(" ", 0), ". Press again to clear it." if on else ""]
		row.add_child(chip)
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
		elif marks == MARK_ATTUNED:
			why = "Nothing attuned here. Pick a magic item that needs it and choose Attune."
		elif not rarities.is_empty():
			why = "No %s items here in %s's pack." % [" or ".join(rarities.map(func(r: String) -> String: return InventoryScreen.rarity_name(r).to_lower())),
				ch.name.get_slice(" ", 0)]
		_list_foot.add_child(UiKit.label(why, 15, "bone", 540))
	for r in rows:
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
	var scroll_spell := Character.scroll_spell_of(data)
	if scroll_spell != "" and "wizard" in (Compendium.shared().spell_data(scroll_spell).get("classes", []) as Array):
		_scroll_copy_card(data)
	# Magic items: rarity and attunement (three items at most; attuning and ending it are instant: owner house rule
	# 2026-10-07, docs/contracts/magic_items.md).
	var magic := shown.get("magic", {}) as Dictionary
	if not magic.is_empty():
		var needs: Variant = false if MagicItems.attunement_off else magic.get("attunement", false)
		var req := ""
		if needs is String:
			req = " (requires attunement %s)" % needs
		elif needs is bool and bool(needs):
			req = " (requires attunement)"
		_card.add_child(UiKit.label("%s magic item%s" % [str(magic.get("rarity", "")).replace("_", " ").capitalize(), req], 14, "moonlight", 420))
		if ch.idle_for_attunement(_entry(selected)):
			_card.add_child(UiKit.label("~ Not attuned: worn, but it does nothing until you attune to it", 14, "gilt", 420))
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
		var unequip := UiKit.button("Unequip", func() -> void:
			ch.unequip_item(selected)
			_draw(), 14)
		if ch.take_off_blocker(selected) != "":
			unequip.disabled = true
			unequip.tooltip_text = ch.take_off_blocker(selected)
		acts.add_child(unequip)
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
			_warn_untrained(ch, selected)
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
	for opt in FieldItems.options(st.party, ch, selected, Dice.roller, st):
		var label := InventoryScreen.power_label(opt)
		var choices := opt.get("choices", []) as Array
		var pid := str(opt["power_id"])
		if disguised:
			opt["text"] = str(shown.get("summary", ""))
		if opt.has("store"):
			_store_picker(acts, opt)
		elif choices.is_empty():
			var tip := str(opt["reason"]) if not bool(opt["legal"]) else str(opt.get("text", ""))
			# One that brings back the dead is aimed at them: a button for each fallen hero (_guest_uses) instead, or this
			# one, greyed, saying why while nobody is dead.
			if not bool(opt.get("revive", false)) or not bool(opt["legal"]):
				var ub := UiKit.button(label, func() -> void: _use_power(pid, {}), 14)
				ub.disabled = not bool(opt["legal"])
				ub.tooltip_text = tip
				acts.add_child(ub)
			for gu in _guest_uses(data, opt):
				var gwhy := str(gu.get("why", ""))
				var gb := UiKit.button(str(gu["label"]), func() -> void: _use_on_guest(pid, gu), 14)
				gb.disabled = not bool(opt["legal"]) or gwhy != ""
				gb.tooltip_text = gwhy if gwhy != "" else tip
				acts.add_child(gb)
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
		var to := UiParts.small_button(other.name.get_slice(" ", 0), func() -> void: _give(other))
		to.disabled = ch.part_blocker(selected) != ""
		to.tooltip_text = ch.part_blocker(selected)
		give.add_child(to)
	_card.add_child(give)
	var quest := InventoryScreen.is_quest(data)
	var stuck := ch.part_blocker(selected)
	var drop := UiParts.small_button("Drop one", func() -> void:
		if slot != "" and n <= 1:
			ch.unequip_item(selected)
		ch.remove_one(selected, entry)
		_forget_gone(ch, selected)
		if not _carries(ch, entry):
			selected = ""
			_picked = {}
		_draw())
	drop.disabled = quest or stuck != ""
	if quest:
		drop.tooltip_text = "Can't drop: needed for a quest"
	elif stuck != "":
		drop.tooltip_text = stuck
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.add_child(drop)
	# Into the party stash from anywhere (owner, 2026-10-07); it comes out again at a safe place.
	var stash := UiParts.small_button("Send to the stash", func() -> void:
		_to_stash(ch, entry, _amount if n > 1 else 1)
		_draw())
	stash.disabled = quest or stuck != ""
	stash.tooltip_text = "Can't: needed for a quest" if quest else stuck if stuck != "" else ("Into the party stash; take it out here or at any safe place" if _stash_open()
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


## A Spell Scroll of a Wizard spell (Ashwin, 2026-10-18; FieldItems.copy_scroll): a Copy button for each Wizard in the
## party, with the hours, the inks and the Arcana check on it, and a second press to confirm, because the scroll is
## used up whether the check succeeds or fails. Outside fights and conversations, as copying from a book is.
func _scroll_copy_card(data: Dictionary) -> void:
	_card.add_child(UiParts.section("Copy into a spellbook"))
	var terms := FieldItems.scroll_copy_terms(str(data["id"]))
	var spell_name := Compendium.shared().display_name("spells", str(terms["spell"]))
	var wizards: Array[Character] = []
	for m in st.party:
		if m.spellbook_class() != "":
			wizards.append(m)
	if wizards.is_empty():
		_card.add_child(UiKit.label("Nobody in the party keeps a spellbook. A Wizard could copy %s from this scroll into theirs." % spell_name, 13, "parchment", 420))
		return
	_card.add_child(UiKit.label("%d h and %d gp of inks, then an Arcana check, DC %d. Pass or fail, the scroll is used up." % [
		int(terms["minutes"]) / 60, int(terms["gp"]), int(terms["dc"])], 13, "parchment", 420))
	var calm := ModeController.mode == ModeController.Mode.EXPLORATION
	var holder := _ch()
	var entry := _entry(selected)
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 6)
	for w in wizards:
		var why := FieldItems.copy_scroll_problem(st, w, str(data["id"]))
		if why == "" and not calm:
			why = "Not during a fight or a conversation"
		var first := w.name.get_slice(" ", 0)
		var bonus := w.skill_bonus(&"arcana").total()
		if why == "" and _scroll_confirm == w.id:
			var go := UiParts.small_button("Copy it: %s rolls Arcana (%+d) against DC %d" % [first, bonus, int(terms["dc"])], func() -> void:
				var res := FieldItems.copy_scroll(st, holder, str(data["id"]), w, Dice.roller, entry)
				_scroll_confirm = ""
				_say(str(res["text"]), "bile" if bool(res.get("copied", false)) else "flame")
				_draw())
			go.tooltip_text = "Spends %d gp and %d hours; on a success %s goes into %s's spellbook." % [int(terms["gp"]), int(terms["minutes"]) / 60, spell_name, first]
			go.set_meta("pad_first", true)
			acts.add_child(go)
			go.call_deferred("grab_focus")
			var back := UiParts.small_button("Keep the scroll", func() -> void:
				_scroll_confirm = ""
				_draw())
			acts.add_child(back)
			continue
		var label := "In %s's book" % first if why == "Already in the spellbook" else "%s copies it (%d h, %d gp, Arcana DC %d)" % [first,
			int(terms["minutes"]) / 60, int(terms["gp"]), int(terms["dc"])]
		var b := UiParts.small_button(label, func() -> void:
			_scroll_confirm = w.id
			_draw())
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else "%s has %+d to Arcana. Press again to confirm." % [first, bonus]
		acts.add_child(b)
	_card.add_child(acts)


## Things come out of the stash only where it's safe to rest (an inn, a home); they go in from anywhere.
func _stash_open() -> bool:
	# Leomund's Secret Chest: the stash comes when called, anywhere, while the spell lasts (60 days).
	return str(Compendium.shared().get_entry("locations", st.location).get("rest", "")) == "safe" or st.spell_active("leomunds_secret_chest")


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
	if e.is_empty() or _ch().part_blocker(selected) != "":
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


## Ring of Spell Storing: pick who casts which spell into the ring, then the level to store it at. The levels are a row of
## buttons that follows the spell: one for each level the ring has room for and the caster has a slot to cast it at (a
## Pact Magic caster's go down from its pact level, FieldItems.store_options), and pressing one stores the spell. The
## pickers are dropdowns, so B backs out of one on the pad and the screen's own Escape leaves the rest.
func _store_picker(acts: Control, opt: Dictionary) -> void:
	var choices := opt["store"] as Array
	if choices.is_empty() or not bool(opt["legal"]):
		acts.add_child(UiKit.label(str(opt["reason"]), 13, "bone", 420))
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = 420   # a row of its own, whatever buttons come before it
	acts.add_child(box)
	var casters: Array[String] = []
	var spells := {}   # caster id -> [{spell, name, base, options}], the lowest spells first
	for c: Dictionary in choices:
		var cid := str(c["caster"])
		if not spells.has(cid):
			casters.append(cid)
			spells[cid] = []
		var entry := {}
		for s: Dictionary in spells[cid]:
			if str(s["spell"]) == str(c["spell"]):
				entry = s
		if entry.is_empty():
			entry = {"spell": str(c["spell"]), "base": int(c["base"]), "options": [],
				"name": str(Compendium.shared().spell_data(str(c["spell"])).get("name", c["spell"]))}
			(spells[cid] as Array).append(entry)
		(entry["options"] as Array).append(c)
	for cid: String in casters:
		(spells[cid] as Array).sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return [int(x["base"]), str(x["name"])] < [int(y["base"]), str(y["name"])])
	var who := OptionButton.new()
	for cid: String in casters:
		who.add_item(_party_name(cid), casters.find(cid))
	UiParts.compact(who)
	who.tooltip_text = "Who casts the spell into the ring"
	var what := OptionButton.new()
	UiParts.compact(what)
	what.fit_to_longest_item = false
	what.clip_text = true
	what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	what.custom_minimum_size.x = 230
	what.tooltip_text = "The spell to store"
	var pickers := HFlowContainer.new()
	pickers.add_theme_constant_override("h_separation", 6)
	pickers.add_child(who)
	pickers.add_child(what)
	box.add_child(pickers)
	var levels := HFlowContainer.new()
	levels.add_theme_constant_override("h_separation", 6)
	box.add_child(levels)
	var note := UiKit.label("", 13, "bone", 420)
	box.add_child(note)
	var pid := str(opt["power_id"])
	var show_levels := func() -> void:
		for old in levels.get_children():
			levels.remove_child(old)
			old.queue_free()
		var list := spells[casters[maxi(who.selected, 0)]] as Array
		if what.selected < 0 or what.selected >= list.size():
			return
		var pick := list[what.selected] as Dictionary
		var down := false
		for c: Dictionary in pick["options"]:
			var lvl := int(c["level"])
			var slot := int(c["slot"])
			var b := UiParts.small_button("Level %d" % lvl, func() -> void:
				_use_power(pid, {"caster": str(c["caster"]), "spell": str(c["spell"]), "level": lvl}))
			b.tooltip_text = "Store %s at level %d: it takes %d of the ring's levels%s." % [pick["name"], lvl, lvl,
				", and spends a level %d Pact Magic slot" % slot if slot > lvl else ""]
			down = down or slot > lvl
			levels.add_child(b)
		note.text = "A Pact Magic slot is spent whatever the level."
		note.visible = down
	var show_spells := func() -> void:
		what.clear()
		for s: Dictionary in spells[casters[maxi(who.selected, 0)]]:
			what.add_item("%s (level %d)" % [s["name"], int(s["base"])])
		what.select(0)
		show_levels.call()
	who.item_selected.connect(func(_i: int) -> void: show_spells.call())
	what.item_selected.connect(func(_i: int) -> void: show_levels.call())
	who.select(0)
	show_spells.call()


## A party member's first name from their id, for a picker.
func _party_name(id: String) -> String:
	for m in st.party:
		if m.id == id:
			return m.name.get_slice(" ", 0)
	return id


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


## A field power for a story ally travelling with the party (owner, 2026-10-12): a potion given to them to drink, or a
## power aimed at a creature used on them. [{label, guest, potion}] for each living guest; [] for anything else.
func _guest_uses(data: Dictionary, opt: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if opt.has("store") or not (opt.get("choices", []) as Array).is_empty():
		return out
	# A power that brings back the dead (a Spell Scroll of Revivify, the Rod of Resurrection): one for each fallen party
	# member, with why it can't reach one who has been dead too long (Ashwin, 2026-10-15).
	if bool(opt.get("revive", false)):
		for m in st.party:
			if m.dead:
				out.append({"label": "%s on %s" % [InventoryScreen.power_label(opt), m.name.get_slice(" ", 0)], "guest": m, "potion": false,
					"why": FieldCasting.revive_why(st, str(opt.get("spell_id", "")), m)})
		return out
	var potion := str(data.get("category", "")) == "potion"
	if not potion and str(opt.get("targeting", "")) != "ally":
		return out
	for g in st.guests:
		if g.dead:
			continue
		var who := g.name.get_slice(" ", 0)
		out.append({"label": "Give to %s to drink" % who if potion else "%s on %s" % [InventoryScreen.power_label(opt), who],
			"guest": g, "potion": potion})
	return out


## Gives the selected potion to a story ally to drink, or uses the power on them (story/field_items.gd).
func _use_on_guest(power_id: String, gu: Dictionary) -> void:
	var ch := _ch()
	var g := gu["guest"] as Creature
	var res := FieldItems.give_potion(st, ch, selected, power_id, g, Dice.roller) if bool(gu["potion"]) \
		else FieldItems.use(st, ch, selected, power_id, g, Dice.roller, {})
	if _entry(selected).is_empty():
		selected = ""
	if root.has_method("_refresh"):
		root.call("_refresh")
	_draw()
	_card.add_child(UiKit.label(str(res.get("text", "")) if bool(res.get("ok", false)) else "Can't: %s" % res.get("text", ""), 15,
		"bile" if bool(res.get("ok", false)) else "flame", 420))


## Uses a magic item's power outside a fight (story/field_items.gd) and shows what happened.
func _use_power(power_id: String, opts: Dictionary) -> void:
	var ch := _ch()
	# Daern's Instant Fortress: the plot the live map has room for (FortressSite.plot_in).
	if selected == FortressSite.ITEM and root != null and root.get("view") != null and not (root.get("view") as LocationView).in_combat \
			and not (root.get("view") as LocationView).members.is_empty():
		opts["plot"] = LocationFortress.plot_in(root.get("view") as LocationView)
	var res := FieldItems.use(st, ch, selected, power_id, ch, Dice.roller, opts)
	if bool(res.get("ok", false)) and str(res.get("effect", "")) == "long_rest":
		# The same night as any other Long Rest's: its morning (the rest screen keeps the companions' words and the
		# change of prepared spells for the hour), the Narrator's night and dream, a word to hear, and perhaps Strahd,
		# who waits for this screen to close. A visit of his that may come to blows comes before the morning (`held`):
		# the rest goes on once he's gone (game root).
		if not bool(res.get("held", false)):
			_prepared_before = PrepareScreen.snapshot(st)
			st.morning["prepared"] = _prepared_before
			var words := RestScreen.night_words(root, st)
			var hint := RestScreen.talk_hint(st)
			res["text"] = " ".join([str(res["text"]), words, hint]).strip_edges().replace("  ", " ")
		if root != null and root.has_method("visit_after_rest"):
			root.call_deferred("visit_after_rest", int(res.get("minutes", LongRest.HOURS * 60)))
	# What it does to the place the party is in (a Wand of Secrets' pointing, a Wand of Magic Detection's Detect Magic).
	if bool(res.get("ok", false)) and str(res.get("effect", "")) != "" and root != null and root.get("view") != null:
		(root.get("view") as LocationView).apply_spell_effect(str(res["effect"]))
	if _entry(selected).is_empty():
		selected = ""
	if root.has_method("_refresh"):
		root.call("_refresh")
	# A reading that has pictures (a `read:` cutscene in story/cutscenes.gd): they come over the screen, the first time only,
	# and what the reading said is narrated when they close.
	if bool(res.get("ok", false)) and str(res.get("cutscene", "")) != "" and root.has_method("play_item_cutscene") \
			and bool(root.call("play_item_cutscene", str(res["cutscene"]), str(res.get("text", "")))):
		return
	# A reading that is a conversation (the Tome of Strahd, every time): the screen closes, it plays, and what the
	# reading said is narrated when it ends.
	if bool(res.get("ok", false)) and str(res.get("dialogue", "")) != "" and root.has_method("play_item_conversation") \
			and bool(root.call("play_item_conversation", str(res["dialogue"]), str(res.get("text", "")))):
		return
	_draw()
	_card.add_child(UiKit.label(str(res.get("text", "")) if bool(res.get("ok", false)) else "Can't: %s" % res.get("text", ""), 15,
		"bile" if bool(res.get("ok", false)) else "flame", 420))
