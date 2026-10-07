class_name InventoryScreen
extends CanvasLayer
## Inventory v1 (docs/ui/inventory.md inv_01, plan §5.6): one per character, the paper doll (armor, main hand, off
## hand; more slots arrive with magic items in Phase 4), the backpack with filters and sorting, the item card with
## what the item does for this character and a comparison with what's equipped, carrying capacity with its
## breakdown, and actions: equip, unequip, use (a Potion of Healing), give to another character, drop. Quest items
## can't be dropped. The party's coins are shown with the purse.
## Search and junk (U3): a search box, the Magic filter, New and Junk marks with their own filters, sorting by newest,
## and marking items as junk for a merchant's Sell all junk (ShopScreen). "New" is what arrived since the character's
## page was last opened (Character.add_item marks it; closing this screen clears it for every page that was shown).

const FILTERS := ["All", "Weapons", "Armor", "Consumables", "Magic", "Gear"]
const SORTS := ["name", "weight", "value", "newest"]
## Item categories each filter keeps (Magic is any magic item, whatever its category; Gear is everything else).
const FILTER_CATEGORIES := {"Weapons": ["weapon", "ammunition"], "Armor": ["armor", "shield", "clothing"],
	"Consumables": ["potion", "consumable", "scroll"]}

var root: Node
var st: StoryState
var index := 0
var filter := "All"
var sort_by := "name"
var selected := ""
## What the search box holds (matched against an item's name, kind and rarity).
var search := ""
## "new" or "junk" shows only items with that mark; "" shows everything the filter keeps.
var marks := ""
var _frame: VBoxContainer
var _card: VBoxContainer
var _list: VBoxContainer
var _list_foot: Control
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


func _ch() -> Character:
	return st.party[index]


func _draw() -> void:
	while _frame.get_child_count() > 0:
		var c := _frame.get_child(0)
		_frame.remove_child(c)
		c.queue_free()
	var ch := _ch()
	var strip := UiParts.party_chips(st.party, index, func(i: int) -> void:
		index = i
		selected = ""
		_draw())
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
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(row)
	# Paper doll
	var doll := VBoxContainer.new()
	doll.custom_minimum_size = Vector2(330, 0)
	doll.add_theme_constant_override("separation", 8)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	who.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 120.0, ch.hp <= 0, ch.dead))
	who.add_child(UiParts.shield(ch.ac_value(), func() -> Control: return UiParts.breakdown_tip(ch.armor_class(), "Armor Class")))
	doll.add_child(who)
	var n := UiKit.title(ch.name)
	n.add_theme_font_size_override("font_size", 24)
	doll.add_child(n)
	doll.add_child(UiParts.section("Equipped"))
	for slot in Character.EQUIP_SLOTS:
		doll.add_child(_slot_row(ch, slot))
	# Worn magic items (2024 DMG: one cloak, one pair of boots..., two rings, any number of Ioun Stones).
	var worn: Array[Dictionary] = []
	for e0 in ch.inventory:
		if str(e0.get("slot", "")) in MagicItems.WORN_SLOTS and int(e0.get("qty", 0)) > 0:
			worn.append(e0)
	if not worn.is_empty():
		doll.add_child(UiParts.section("Worn"))
		for e1 in worn:
			doll.add_child(_worn_row(ch, e1))
	doll.add_child(UiParts.section("Load"))
	var cap := ch.carrying_capacity().total()
	var carried := ch.carried_weight()
	var over := carried > cap
	doll.add_child(UiParts.bar(carried, cap, 0.0, "%.1f / %d lb" % [carried, cap], "vampire_red" if over else "gilt_dark",
		func() -> Control: return UiParts.breakdown_tip(ch.carrying_capacity(), "Carrying capacity", "%d lb" % cap,
			"Overloaded: Speed drops." if over else ""), 330.0))
	if over:
		doll.add_child(UiKit.label("Overloaded", 14, "vampire_red"))
	row.add_child(doll)
	# Backpack
	_viewed[ch.id] = true
	var pack := VBoxContainer.new()
	pack.custom_minimum_size = Vector2(580, 0)
	pack.add_theme_constant_override("separation", 0)
	pack.add_child(UiParts.tab_strip(Array(FILTERS, TYPE_STRING, "", null), filter, func(f: String) -> void:
		filter = f
		_draw(), {}, 14))
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	inner.add_child(sorts)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	inner.add_child(UiParts.fill_scroll(_list))
	_list_foot = VBoxContainer.new()
	inner.add_child(_list_foot)
	_fill_list()
	pack.add_child(pane)
	# The party stash (plan §5.6; owner, 2026-10-07): things go in from anywhere, and come out only at a safe place
	# (an inn, a home).
	var at_safe := _stash_open()
	var where := UiParts.caption("Take out here" if at_safe else "Take out at an inn or a home", 11, "bile" if at_safe else "parchment")
	pack.add_child(UiParts.section("Party stash", where))
	var sl := VBoxContainer.new()
	sl.add_theme_constant_override("separation", 4)
	if st.stash.is_empty():
		sl.add_child(UiKit.label("Empty. Select an item and choose Send to the stash.", 13, "bone"))
	for se in st.stash:
		var sid := str(se["id"])
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 8)
		UiParts.add_icon(srow, "item", sid, 24.0)
		var sn := UiKit.label("%s ×%d" % [Compendium.shared().display_name("items", sid), int(se["qty"])], 14, "vellum" if at_safe else "bone")
		sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(sn)
		var take := UiParts.small_button("Take", func() -> void:
			st.stash_take(sid, _ch())
			_draw())
		take.disabled = not at_safe
		take.tooltip_text = "To %s's pack" % ch.name.get_slice(" ", 0) if at_safe else "Only at a safe place: an inn or a home"
		srow.add_child(take)
		sl.add_child(UiParts.row(srow))
	var stash_scroll := UiKit.scroll(sl, Vector2(560, 130))
	pack.add_child(stash_scroll)
	row.add_child(pack)
	# Item card
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 8)
	var card_pane := UiParts.pane(14)
	card_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_pane.add_child(UiParts.fill_scroll(_card))
	row.add_child(card_pane)
	_draw_card()


## An equipment slot as a row you can click to see the item: the slot's name, the item and its one key number.
func _slot_row(ch: Character, slot: String) -> Control:
	var item := ch.equipped(slot)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	if not item.is_empty():
		UiParts.add_icon(line, "item", str(item["id"]))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.caption(slot.replace("_", " "), 10))
	col.add_child(UiKit.label(str(item.get("name", "Empty")), 15, "vellum" if not item.is_empty() else "bone"))
	line.add_child(col)
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
	if item.is_empty():
		return UiParts.row(line)
	var id := str(item["id"])
	# Taking it off straight from the equipped list (owner report 2026-10-07: "no way to unequip armor").
	var off := UiParts.small_button("Take off", func() -> void:
		ch.unequip(slot)
		_draw())
	off.tooltip_text = "Unequip it: back to the pack"
	line.add_child(off)
	return UiParts.click_row(line, func() -> void:
		selected = id
		_draw(), id == selected)


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
	# Only the list redraws as the text changes, so the box keeps its focus and caret.
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


## The backpack rows the filter, marks and search keep, sorted; with Junk shown, what the junk adds up to.
func _fill_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
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
			why = "Nothing marked as junk. Pick an item and choose Mark as junk."
		elif marks == "new":
			why = "Nothing new since you last looked."
		_list.add_child(UiKit.label(why, 15, "bone", 520))
	for r in rows:
		_list.add_child(_pack_row(ch, r["e"] as Dictionary, r["d"] as Dictionary))
	if marks == "junk" and not rows.is_empty():
		var weight := 0.0
		var value := 0.0
		for r in rows:
			var q := int((r["e"] as Dictionary)["qty"])
			weight += float((r["d"] as Dictionary).get("weight_lb", 0)) * q
			value += float((r["d"] as Dictionary).get("cost_gp", 0)) * q
		_list_foot.add_child(UiKit.label("%d junk, %s lb, worth %s gp new. A merchant's Sell all junk sells it for less." % [rows.size(),
			_num(weight), _num(value)], 13, "parchment", 520))


## One backpack row: icon, name and count, its marks (equipped, quest, magic, charges, new, junk) and weight.
func _pack_row(ch: Character, e: Dictionary, data: Dictionary) -> Control:
	var slot := str(e.get("slot", ""))
	var id := str(e["id"])
	var junk := InventoryScreen.is_junk(e)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	UiParts.add_icon(line, "item", str(MagicItems.shown_data(data, e).get("id", id)))
	var nm := UiKit.label(MagicItems.display_name(data, e) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else ""), 15,
		"gilt_light" if id == selected else ("bone" if junk else "vellum"))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(nm)
	if bool(e.get("new", false)):
		line.add_child(UiParts.pill("New", "gilt_light"))
	if junk:
		line.add_child(UiParts.pill("Junk", "bone"))
	if slot != "":
		line.add_child(UiParts.pill("Equipped", "moonlight"))
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
	return UiParts.click_row(line, func() -> void:
		selected = id
		_draw(), id == selected)


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
	if selected == "":
		_card.add_child(UiKit.label("Pick an item to see what it does for %s." % _ch().name.get_slice(" ", 0), 15, "bone", 420))
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
			ch.unequip(slot)
			_draw(), 14))
	elif Gear.is_weapon(data):
		acts.add_child(UiKit.button("Equip (main hand)", func() -> void:
			ch.equip(selected, "main_hand")
			_draw(), 14))
		if "light" in Gear.weapon_props(data):
			acts.add_child(UiKit.button("Equip (off hand)", func() -> void:
				ch.equip(selected, "off_hand")
				_draw(), 14))
	elif Gear.is_armor(data):
		acts.add_child(UiKit.button("Wear", func() -> void:
			ch.equip(selected, "armor")
			_draw(), 14))
	elif Gear.is_shield(data):
		acts.add_child(UiKit.button("Equip (off hand)", func() -> void:
			ch.equip(selected, "off_hand")
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
	acts.add_theme_constant_override("h_separation", 6)
	acts.add_theme_constant_override("v_separation", 6)
	_card.add_child(acts)
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
		if slot != "":
			ch.unequip(slot)
		_remove_one(ch, selected)
		_draw())
	drop.disabled = quest
	if quest:
		drop.tooltip_text = "Can't drop: needed for a quest"
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.add_child(drop)
	# Into the party stash from anywhere (owner, 2026-10-07); it comes out again at a safe place.
	var stash := UiParts.small_button("Send to the stash", func() -> void:
		st.stash_put(selected, ch)
		if _entry(selected).is_empty():
			selected = ""
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


func _entry(item_id: String) -> Dictionary:
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


func _give(other: Character) -> void:
	var ch := _ch()
	var e := _entry(selected)
	if e.is_empty():
		return
	if str(e.get("slot", "")) != "":
		ch.unequip(str(e["slot"]))
	var state := ch.remove_one(selected)
	if _entry(selected).is_empty():
		selected = ""
	other.add_item(str(e["id"]), 1, state)
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


## A worn magic item as a row you can click: where it's worn, the item, and whether it's working.
func _worn_row(ch: Character, e: Dictionary) -> Control:
	var data := Compendium.shared().item_data(str(e["id"]))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	UiParts.add_icon(line, "item", str(MagicItems.shown_data(data, e).get("id", e["id"])))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UiParts.caption(str(MagicItems.SLOT_NAMES.get(str(e["slot"]), e["slot"])), 10))
	col.add_child(UiKit.label(MagicItems.display_name(data, e), 15, "vellum"))
	line.add_child(col)
	if not ch.item_active(e):
		line.add_child(UiParts.pill("Needs attunement", "flame"))
	var id := str(e["id"])
	return UiParts.click_row(line, func() -> void:
		selected = id
		_draw(), id == selected)


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
