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
	while _frame.get_child_count() > 1:
		var c := _frame.get_child(1)
		_frame.remove_child(c)
		c.queue_free()
	var ch := _ch()
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	for i in st.party.size():
		strip.add_child(UiKit.button(("▸ " if i == index else "") + st.party[i].name, func() -> void:
			index = i
			selected = ""
			_draw(), 14))
	strip.add_child(UiKit.label("   Purse: %d gp" % int(st.gold), 16, "wick"))
	_frame.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_frame.add_child(row)
	# Paper doll
	var doll := VBoxContainer.new()
	doll.custom_minimum_size = Vector2(340, 0)
	doll.add_child(UiKit.portrait(CombatToken.art_for(ch), 140))
	doll.add_child(UiKit.header("Equipped"))
	for slot in Character.EQUIP_SLOTS:
		var item := ch.equipped(slot)
		var name_text := str(item.get("name", "—"))
		var b := UiKit.button("%s: %s" % [slot.replace("_", " ").capitalize(), name_text], func() -> void:
			if not item.is_empty():
				selected = str(item["id"])
				_draw(), 14)
		doll.add_child(b)
	doll.add_child(UiKit.stat("Armor Class", str(ch.ac_value()), ch.armor_class()))
	var cap := ch.carrying_capacity().total()
	var carried := ch.carried_weight()
	var over := carried > cap
	doll.add_child(UiKit.stat("Carrying", "%.1f / %d lb%s" % [carried, cap, " · overloaded" if over else ""], ch.carrying_capacity()))
	row.add_child(doll)
	# Backpack
	var pack := VBoxContainer.new()
	pack.custom_minimum_size = Vector2(560, 0)
	var filters := HBoxContainer.new()
	for f: String in FILTERS:
		filters.add_child(UiKit.button(("▸ " if f == filter else "") + f, func() -> void:
			filter = f
			_draw(), 13))
	pack.add_child(filters)
	var sorts := HBoxContainer.new()
	sorts.add_child(UiKit.label("Sort:", 13, "parchment"))
	for s: String in ["name", "weight", "value"]:
		sorts.add_child(UiKit.button(("▸ " if s == sort_by else "") + s.capitalize(), func() -> void:
			sort_by = s
			_draw(), 13))
	pack.add_child(sorts)
	var list := VBoxContainer.new()
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
		list.add_child(UiKit.label("Nothing here yet.", 15, "parchment"))
	for r in rows:
		var e := r["e"] as Dictionary
		var data := r["d"] as Dictionary
		var slot := str(e.get("slot", ""))
		var text := "%s%s%s · %s lb" % [data.get("name", e["id"]), " ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else "",
			" (equipped)" if slot != "" else "", str(data.get("weight_lb", 0))]
		var id := str(e["id"])
		var b := UiKit.button(("▸ " if id == selected else "") + text, func() -> void:
			selected = id
			_draw(), 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(b)
	var at_safe := _stash_open()
	pack.add_child(UiKit.scroll(list, Vector2(540, 400 if at_safe else 560)))
	if at_safe:
		# The party stash (plan §5.6): kept at safe places like an inn.
		pack.add_child(UiKit.header("Party stash"))
		var sl := VBoxContainer.new()
		if st.stash.is_empty():
			sl.add_child(UiKit.label("Empty. Select an item and choose Stash it.", 13, "parchment"))
		for se in st.stash:
			var sid := str(se["id"])
			var srow := HBoxContainer.new()
			srow.add_child(UiKit.label("%s ×%d" % [Compendium.shared().display_name("items", sid), int(se["qty"])], 14, "vellum", 380))
			srow.add_child(UiKit.button("Take", func() -> void:
				st.stash_take(sid, _ch())
				_draw(), 13))
			sl.add_child(srow)
		pack.add_child(UiKit.scroll(sl, Vector2(540, 150)))
	row.add_child(pack)
	# Item card
	_card = VBoxContainer.new()
	_card.custom_minimum_size = Vector2(520, 0)
	row.add_child(UiKit.scroll(_card, Vector2(520, 680)))
	_draw_card()


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
		_card.add_child(UiKit.label("Pick an item to see what it does for %s." % _ch().name, 15, "parchment", 500))
		return
	var ch := _ch()
	var data := Compendium.shared().item_data(selected)
	_card.add_child(UiKit.header(str(data.get("name", selected))))
	_card.add_child(UiKit.label("%s · %s lb · %s gp" % [str(data.get("category", "")).capitalize(), str(data.get("weight_lb", 0)), str(data.get("cost_gp", 0))], 14, "parchment"))
	if Gear.is_weapon(data):
		var p := WeaponProfile.build(ch, data)
		_card.add_child(UiKit.label("For %s: %s" % [ch.name.get_slice(" ", 0), p.describe()], 15, "vellum", 500))
		if not ch.weapon_proficient(data):
			_card.add_child(UiKit.label("~ Not proficient: no Proficiency Bonus on attacks", 14, "candle", 500))
		var w := data.get("weapon", {}) as Dictionary
		if str(w.get("mastery", "")) != "":
			var usable := str(w["mastery"]) in ch.weapon_masteries or selected in ch.weapon_masteries
			_card.add_child(UiKit.label("Mastery %s: %s%s" % [str(w["mastery"]).capitalize(), ActionCatalog.MASTERY_TEXT.get(str(w["mastery"]), ""),
				"" if usable else " (not one of your masteries)"], 14, "lilac" if usable else "bone", 500))
		var main := ch.equipped("main_hand")
		if Gear.is_weapon(main) and str(main["id"]) != selected:
			var mp := WeaponProfile.build(ch, main)
			var diff := p.average_damage() - mp.average_damage()
			_card.add_child(UiKit.label("Compared with your %s: %s average damage (%.1f vs %.1f)" % [main["name"], ("▲ %.1f more" % diff) if diff > 0 else ("▼ %.1f less" % -diff) if diff < 0 else "the same", p.average_damage(), mp.average_damage()], 14, "vellum", 500))
	elif Gear.is_armor(data):
		var arm := data["armor"] as Dictionary
		_card.add_child(UiKit.label("%s armor: AC %d%s%s" % [str(arm["kind"]).capitalize(), int(arm.get("base_ac", 10)),
			"" if int(arm.get("dex_cap", 99)) == 0 else " + Dex" + (" (max %d)" % int(arm["dex_cap"]) if int(arm.get("dex_cap", 99)) < 10 else ""),
			", Stealth Disadvantage" if bool(arm.get("stealth_disadvantage", false)) else ""], 15, "vellum", 500))
		if not ch.has_armor_training(str(arm["kind"])):
			_card.add_child(UiKit.label("~ No training: Disadvantage on Strength and Dexterity rolls, and no spellcasting", 14, "candle", 500))
		if int(arm.get("strength", 0)) > ch.ability_score(&"str"):
			_card.add_child(UiKit.label("~ Needs Strength %d: Speed -10 ft" % int(arm["strength"]), 14, "candle", 500))
	_card.add_child(UiKit.label(str(data.get("text", data.get("summary", ""))), 14, "vellum", 500))
	# Magic items: rarity and attunement (three items at most; attuning takes a Short Rest).
	var magic := data.get("magic", {}) as Dictionary
	if not magic.is_empty():
		var needs: Variant = magic.get("attunement", false)
		var req := ""
		if needs is String:
			req = " (requires attunement %s)" % needs
		elif needs is bool and bool(needs):
			req = " (requires attunement)"
		_card.add_child(UiKit.label("%s magic item%s" % [str(magic.get("rarity", "")).replace("_", " ").capitalize(), req], 14, "lilac", 500))
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
	var acts := HBoxContainer.new()
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
	_card.add_child(acts)
	var give := HBoxContainer.new()
	give.add_child(UiKit.label("Give to:", 14, "parchment"))
	for i in st.party.size():
		if i == index:
			continue
		var other := st.party[i]
		give.add_child(UiKit.button(other.name.get_slice(" ", 0), func() -> void: _give(other), 13))
	_card.add_child(give)
	var quest := bool(data.get("quest", false))
	var drop := UiKit.button("Drop one", func() -> void:
		if slot != "":
			ch.unequip(slot)
		_remove_one(ch, selected)
		_draw(), 13)
	drop.disabled = quest
	if quest:
		drop.tooltip_text = "Can't drop: needed for a quest"
	_card.add_child(drop)
	if _stash_open() and not quest:
		_card.add_child(UiKit.button("Stash it", func() -> void:
			st.stash_put(selected, ch)
			if _entry(selected).is_empty():
				selected = ""
			_draw(), 13))


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
