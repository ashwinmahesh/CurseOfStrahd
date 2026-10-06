class_name InventoryScreen
extends CanvasLayer
## Inventory v1 (docs/ui/inventory.md inv_01, plan §5.6): one per character, the paper doll (armor, main hand, off
## hand; more slots arrive with magic items in Phase 4), the backpack with filters and sorting, the item card with
## what the item does for this character and a comparison with what's equipped, carrying capacity with its
## breakdown, and actions: equip, unequip, use (a Potion of Healing), give to another character, drop. Quest items
## can't be dropped. The party's coins are shown with the purse.

const FILTERS := ["All", "Weapons", "Armor", "Consumables", "Tools", "Gear"]

var root: Node
var st: StoryState
var index := 0
var filter := "All"
var sort_by := "name"
var selected := ""
var _frame: VBoxContainer
var _card: VBoxContainer


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
	var pack := VBoxContainer.new()
	pack.custom_minimum_size = Vector2(560, 0)
	pack.add_theme_constant_override("separation", 0)
	pack.add_child(UiParts.tab_strip(Array(FILTERS, TYPE_STRING, "", null), filter, func(f: String) -> void:
		filter = f
		_draw(), {}, 14))
	var pane := UiParts.pane(10)
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	pane.add_child(inner)
	var sorts := HBoxContainer.new()
	sorts.add_theme_constant_override("separation", 4)
	sorts.add_child(UiParts.caption("Sort", 11))
	for s: String in ["name", "weight", "value"]:
		var sb := UiParts.small_button(s.capitalize(), func() -> void:
			sort_by = s
			_draw())
		if s == sort_by:
			UiParts.light_up(sb)
		sorts.add_child(sb)
	inner.add_child(sorts)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var rows: Array[Dictionary] = []
	for e in ch.inventory:
		if int(e["qty"]) <= 0:
			continue
		var data := Compendium.shared().item_data(str(e["id"]))
		if not _passes(data):
			continue
		rows.append({"e": e, "d": data})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := a["d"] as Dictionary
		var db := b["d"] as Dictionary
		match sort_by:
			"weight":
				return float(da.get("weight_lb", 0)) > float(db.get("weight_lb", 0))
			"value":
				return float(da.get("cost_gp", 0)) > float(db.get("cost_gp", 0))
		return str(da.get("name", "")) < str(db.get("name", "")))
	if rows.is_empty():
		list.add_child(UiKit.label("Nothing here yet.", 15, "bone"))
	for r in rows:
		var e := r["e"] as Dictionary
		var data := r["d"] as Dictionary
		var slot := str(e.get("slot", ""))
		var id := str(e["id"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		UiParts.add_icon(line, "item", id)
		var nm := UiKit.label(str(data.get("name", id)) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else ""), 15, "gilt_light" if id == selected else "vellum")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		if slot != "":
			line.add_child(UiParts.pill("Equipped", "moonlight"))
		if bool(data.get("quest", false)):
			line.add_child(UiParts.pill("Quest", "flame"))
		if not (data.get("magic", {}) as Dictionary).is_empty():
			line.add_child(UiParts.pill("Magic", "lilac"))
		var wt := UiKit.label("%s lb" % str(data.get("weight_lb", 0)), 13, "parchment")
		wt.custom_minimum_size = Vector2(52, 0)
		wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(wt)
		list.add_child(UiParts.click_row(line, func() -> void:
			selected = id
			_draw(), id == selected))
	var scroll := UiParts.fill_scroll(list)
	inner.add_child(scroll)
	pack.add_child(pane)
	var at_safe := _stash_open()
	if at_safe:
		# The party stash (plan §5.6): kept at safe places like an inn.
		pack.add_child(UiParts.section("Party stash"))
		var sl := VBoxContainer.new()
		sl.add_theme_constant_override("separation", 4)
		if st.stash.is_empty():
			sl.add_child(UiKit.label("Empty. Select an item and choose Stash it.", 13, "bone"))
		for se in st.stash:
			var sid := str(se["id"])
			var srow := HBoxContainer.new()
			srow.add_theme_constant_override("separation", 8)
			UiParts.add_icon(srow, "item", sid, 24.0)
			var sn := UiKit.label("%s ×%d" % [Compendium.shared().display_name("items", sid), int(se["qty"])], 14, "vellum")
			sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(sn)
			srow.add_child(UiParts.small_button("Take", func() -> void:
				st.stash_take(sid, _ch())
				_draw()))
			sl.add_child(UiParts.row(srow))
		var stash_scroll := UiKit.scroll(sl, Vector2(540, 130))
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
	return UiParts.click_row(line, func() -> void:
		selected = id
		_draw(), id == selected)


func _passes(data: Dictionary) -> bool:
	var cat := str(data.get("category", ""))
	match filter:
		"Weapons":
			return cat == "weapon" or cat == "ammunition"
		"Armor":
			return cat in ["armor", "shield", "clothing"]
		"Consumables":
			return cat in ["potion", "consumable", "scroll"]
		"Tools":
			return cat in ["tool", "focus"]
		"Gear":
			return cat in ["gear", "container", "pack", "light"]
	return true


func _draw_card() -> void:
	for c in _card.get_children():
		c.queue_free()
	if selected == "":
		_card.add_child(UiKit.label("Pick an item to see what it does for %s." % _ch().name.get_slice(" ", 0), 15, "bone", 420))
		return
	var ch := _ch()
	var data := Compendium.shared().item_data(selected)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	UiParts.add_icon(head, "item", selected, 48.0)
	var t := UiKit.title(str(data.get("name", selected)))
	t.add_theme_font_size_override("font_size", 26)
	head.add_child(t)
	_card.add_child(head)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 6)
	for f: Array in [["Kind", str(data.get("category", "")).capitalize()], ["Weight", "%s lb" % str(data.get("weight_lb", 0))],
			["Value", "%s gp" % str(data.get("cost_gp", 0))]]:
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
		_card.add_child(UiKit.label("%s armor: AC %d%s%s" % [str(arm["kind"]).capitalize(), int(arm.get("base_ac", 10)),
			"" if int(arm.get("dex_cap", 99)) == 0 else " + Dex" + (" (max %d)" % int(arm["dex_cap"]) if int(arm.get("dex_cap", 99)) < 10 else ""),
			", Stealth Disadvantage" if bool(arm.get("stealth_disadvantage", false)) else ""], 15, "vellum", 420))
		if not ch.has_armor_training(str(arm["kind"])):
			_card.add_child(UiKit.label("~ No training: Disadvantage on Strength and Dexterity rolls, and no spellcasting", 14, "gilt", 420))
		if int(arm.get("strength", 0)) > ch.ability_score(&"str"):
			_card.add_child(UiKit.label("~ Needs Strength %d: Speed -10 ft" % int(arm["strength"]), 14, "gilt", 420))
	_card.add_child(UiParts.section("Description"))
	_card.add_child(UiKit.label(str(data.get("text", data.get("summary", ""))), 14, "vellum", 420))
	# Magic items: rarity and attunement (three items at most; attuning takes a Short Rest).
	var magic := data.get("magic", {}) as Dictionary
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
				_card.add_child(UiKit.button("End attunement", func() -> void:
					ch.end_attunement(selected)
					_draw(), 14))
			else:
				var why := ch.attune_blocker(selected)
				var att := UiKit.button("Attune (a Short Rest: 1 hour)", func() -> void:
					if ch.attune(selected):
						st.advance_minutes(60)
					_draw(), 14)
				att.disabled = why != ""
				att.tooltip_text = why
				_card.add_child(att)
			_card.add_child(UiKit.label("Attuned: %d of %d" % [ch.attuned.size(), Character.MAX_ATTUNED], 13, "parchment"))
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
	if (data.get("effects", []) as Array).size() > 0 and str(data.get("category", "")) == "potion":
		acts.add_child(UiKit.button("Drink", _drink, 14))
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
	var quest := bool(data.get("quest", false))
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
	if _stash_open() and not quest:
		bottom.add_child(UiParts.small_button("Stash it", func() -> void:
			st.stash_put(selected, ch)
			if _entry(selected).is_empty():
				selected = ""
			_draw()))
	_card.add_child(bottom)


## The stash is reachable where it's safe to rest (an inn, a home).
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
	_remove_one(ch, selected)
	other.add_item(str(e["id"]), 1)
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
	_card.add_child(UiKit.label("%s regains %d Hit Points." % [ch.name, healed], 15, "bile"))
