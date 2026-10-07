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
		UiParts.add_icon(line, "item", str(MagicItems.shown_data(data, e).get("id", id)))
		var nm := UiKit.label(MagicItems.display_name(data, e) + (" ×%d" % int(e["qty"]) if int(e["qty"]) > 1 else ""), 15, "gilt_light" if id == selected else "vellum")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(nm)
		if slot != "":
			line.add_child(UiParts.pill("Equipped", "moonlight"))
		if bool(data.get("quest", false)):
			line.add_child(UiParts.pill("Quest", "flame"))
		if not (data.get("magic", {}) as Dictionary).is_empty():
			line.add_child(UiParts.pill("Attuned" if id in ch.attuned else "Magic", "lilac"))
		if MagicItems.has_charges(data):
			line.add_child(UiParts.pill("%d/%d" % [int(e.get("charges", 0)), MagicItems.max_charges(data, e)], "moonlight"))
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
	# Taking it off straight from the equipped list (owner report 2026-10-07: "no way to unequip armor").
	var off := UiParts.small_button("Take off", func() -> void:
		ch.unequip(slot)
		_draw())
	off.tooltip_text = "Unequip it: back to the pack"
	line.add_child(off)
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
	for sp: Variant in book:
		var sid := str(sp)
		var s := Compendium.shared().spell_data(sid)
		var lv := int(s.get("level", 0))
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		UiParts.add_icon(head, "spell", sid, 24.0)
		var name := UiKit.label("%s (%s)" % [str(s.get("name", sid)), "cantrip" if lv == 0 else "level %d" % lv], 14, "vellum", 380)
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


## Uses a magic item's power outside a fight (story/field_items.gd) and shows what happened.
func _use_power(power_id: String, opts: Dictionary) -> void:
	var ch := _ch()
	var res := FieldItems.use(st, ch, selected, power_id, ch, Dice.roller, opts)
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
