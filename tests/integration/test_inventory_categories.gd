extends TestCase
## The inventory's categories and marks (owner, 2026-10-17): Potions and Quest items have tabs of their own, a magic
## item's picture has a box in the colour of its rarity (the row itself stays plain), an Attuned filter sits beside New
## and Junk, and a Rarity filter keeps any of the six rarities. The shop's pack side shares the tabs and the picture
## boxes, and its wares have a Potions tab.

const RARITIES: Array[String] = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 4):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	ShopScreen.sell_filter = "All"
	ShopScreen.only_buys = true
	ShopScreen.ware_filter = "All"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(i: int) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	return root.get("screen") as InventoryScreen


func _button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if not (b as Node).is_queued_for_deletion() and (b as Button).text == text:
			return b as Button
	return null


## The pack's row for item `id`, or null.
func _row(inv: InventoryScreen, id: String) -> ItemTile.Row:
	for n in inv.find_children("*", "", true, false):
		if n is ItemTile.Row and not (n as Node).is_queued_for_deletion() and str((n as ItemTile.Row).payload.get("id", "")) == id \
				and str((n as ItemTile.Row).payload.get("from", "")) == "pack":
			return n as ItemTile.Row
	return null


func _border(c: Control) -> Color:
	return (c.get_theme_stylebox("panel") as StyleBoxFlat).border_color


## Every item the compendium holds under one of the item tables (no made-to-order variants).
func _all_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for table: String in ["items", "magic_items"]:
		for id: String in (Compendium.shared().tables[table] as Dictionary).keys():
			out.append(Compendium.shared().item_data(id))
	return out


func test_every_item_is_in_one_category_and_quest_items_are_not_gear() -> void:
	assert_true("Potions" in InventoryScreen.FILTERS and "Quest" in InventoryScreen.FILTERS, "the two new tabs")
	var kinds: Array[String] = ["Weapons", "Armor", "Potions", "Consumables", "Gear"]
	var checked := 0
	for data in _all_items():
		var id := str(data.get("id", ""))
		var in_kind: Array[String] = []
		for k in kinds:
			if InventoryScreen.in_filter(k, data):
				in_kind.append(k)
		if InventoryScreen.is_quest(data):
			assert_true(InventoryScreen.in_filter("Quest", data), "%s is a quest item: on the Quest tab" % id)
			assert_false(InventoryScreen.in_filter("Gear", data), "%s is a quest item: not Gear" % id)
		else:
			assert_false(InventoryScreen.in_filter("Quest", data), "%s is no quest item" % id)
			assert_eq(in_kind.size(), 1, "%s is under exactly one tab: %s" % [id, in_kind])
		assert_true(InventoryScreen.in_filter("All", data))
		checked += 1
	assert_true(checked > 500, "the whole item list was walked: %d" % checked)
	var comp := Compendium.shared()
	assert_true(InventoryScreen.in_filter("Potions", comp.item_data("potion_of_healing")), "a potion is under Potions")
	assert_false(InventoryScreen.in_filter("Consumables", comp.item_data("potion_of_healing")), "and no longer under Consumables")
	assert_true(InventoryScreen.in_filter("Consumables", comp.item_data("spell_scroll_level_1")), "a scroll stays a consumable")
	assert_true(InventoryScreen.in_filter("Consumables", comp.item_data("antitoxin")), "so does an antitoxin")
	assert_true(InventoryScreen.in_filter("Quest", comp.item_data("st_andrals_bones")), "St. Andral's bones are a quest item")
	assert_true(InventoryScreen.in_filter("Quest", comp.item_data("sunsword")) and InventoryScreen.in_filter("Weapons", comp.item_data("sunsword")),
		"the Sunsword is both a weapon and a quest item")
	assert_true(InventoryScreen.in_filter("Gear", comp.item_data("rope")), "rope is gear")


func test_the_potions_and_quest_tabs_show_only_theirs() -> void:
	var ch := GameState.story.party[0]
	for id: String in ["potion_of_healing", "potion_of_speed", "spell_scroll_level_1", "antitoxin", "rope", "st_andrals_bones", "durst_attic_key"]:
		ch.add_item(id)
	var inv := await _open(0)
	_button(inv, "Potions").pressed.emit()
	await _frames(1)
	assert_eq(inv.filter, "Potions")
	var shown := inv.shown_ids()
	assert_true("potion_of_healing" in shown and "potion_of_speed" in shown, "both potions: %s" % [shown])
	for id in shown:
		assert_eq(str(Compendium.shared().item_data(id).get("category", "")), "potion", "%s is a potion" % id)
	_button(inv, "Consumables").pressed.emit()
	await _frames(1)
	shown = inv.shown_ids()
	assert_true("antitoxin" in shown and shown.any(func(id: String) -> bool: return id.begins_with("spell_scroll")), "a scroll and antitoxin: %s" % [shown])
	assert_false("potion_of_healing" in shown, "no potions under Consumables")
	_button(inv, "Quest").pressed.emit()
	await _frames(1)
	shown = inv.shown_ids()
	assert_true("st_andrals_bones" in shown and "durst_attic_key" in shown, "the quest items: %s" % [shown])
	for id in shown:
		assert_true(InventoryScreen.is_quest(Compendium.shared().item_data(id)), "%s is a quest item" % id)
	_button(inv, "Gear").pressed.emit()
	await _frames(1)
	shown = inv.shown_ids()
	assert_true("rope" in shown, "gear keeps the rope")
	assert_false("st_andrals_bones" in shown or "durst_attic_key" in shown, "but not the quest items")
	_button(inv, "All").pressed.emit()
	await _frames(1)
	assert_true("st_andrals_bones" in inv.shown_ids() and "potion_of_healing" in inv.shown_ids(), "All still lists everything")
	inv.filter = "Quest"
	inv.call("_draw")
	await _frames(1)
	assert_true(inv.shown_ids().size() >= 2)


## The tab strip has eight tabs now: it must fit the pack column on the inventory and on the shop's pack side.
func test_the_eight_tabs_fit_without_spilling() -> void:
	var inv := await _open(0)
	var strip := _strip_of(inv)
	assert_true(strip != null, "found the inventory's tabs")
	assert_eq(strip.get_child_count(), InventoryScreen.FILTERS.size(), "a tab for each filter")
	_assert_fits(strip, "the inventory's tabs")
	root.call("close_screen")
	await _frames(2)
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open_for(root, GameState.story, "gunther_arasek")
	await _frames(2)
	_assert_fits(shop.find_child("PackTabs", true, false) as Container, "the shop's pack tabs")
	shop.queue_free()


func _strip_of(inv: InventoryScreen) -> HBoxContainer:
	var quest := _button(inv, "Quest")
	return quest.get_parent() as HBoxContainer if quest != null else null


func _assert_fits(strip: Container, what: String) -> void:
	assert_true(strip.get_combined_minimum_size().x <= strip.size.x + 0.5,
		"%s need %.0f px and have %.0f" % [what, strip.get_combined_minimum_size().x, strip.size.x])
	var last := strip.get_child(strip.get_child_count() - 1) as Control
	assert_true(last.position.x + last.size.x <= strip.size.x + 0.5, "%s: the last tab ends inside the strip" % what)
	for c in strip.get_children():
		var b := c as Button
		assert_true(b.get_minimum_size().x <= b.size.x + 0.5, "%s: the %s tab holds its label" % [what, b.text])


## The box round a row's picture (UiParts.framed_icon), or null.
func _frame(row: Control) -> PanelContainer:
	return row.find_child("RarityFrame", true, false) as PanelContainer


func _frame_colour(row: Control) -> Color:
	return (_frame(row).get_theme_stylebox("panel") as StyleBoxFlat).border_color


func test_magic_pictures_have_a_box_in_their_rarity_colour_and_the_row_stays_plain() -> void:
	var comp := Compendium.shared()
	var ids := {"common": "potion_of_healing", "uncommon": "cloak_of_protection", "rare": "ring_of_protection",
		"very_rare": "potion_of_speed", "legendary": "potion_of_giant_strength_storm", "artifact": "orb_of_damara"}
	var ch := GameState.story.party[0]
	for r: String in ids:
		assert_eq(MagicItems.rarity(comp.item_data(str(ids[r]))), r, "%s is %s" % [ids[r], r])
		ch.add_item(str(ids[r]))
	ch.add_item("rope")
	var inv := await _open(0)
	assert_true(UiParts.has_icons(), "the game has icon art, so rows have pictures")
	var seen: Array[Color] = []
	var plain := Color(Look.color("gilt_dark"), 0.95)
	for r: String in ids:
		var row := _row(inv, str(ids[r]))
		assert_true(row != null, "a row for the %s item (the pack lists %s)" % [r, inv.shown_ids()])
		if row == null:
			continue
		assert_true(_frame(row) != null, "the %s item's picture has a frame" % r)
		assert_eq(_frame_colour(row), ItemTile.rarity_edge(r), "the %s picture's box" % r)
		seen.append(_frame_colour(row))
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.border_color, plain, "the %s row's own border is the plain gilt one" % r)
		assert_eq(style.border_width_left, 1, "and as fine as any")
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			assert_ne(seen[i], seen[j], "%s and %s have different boxes" % [RARITIES[i], RARITIES[j]])
	var rope := _row(inv, "rope")
	assert_eq(_frame_colour(rope), Color.TRANSPARENT, "a plain item's picture has no box, only the room for one")
	var sizes := {}
	for id: String in ["rope", "ring_of_protection"]:
		sizes[id] = _frame(_row(inv, id)).get_combined_minimum_size()
	assert_eq(sizes["rope"], sizes["ring_of_protection"], "so the pictures line up")
	# The picked row keeps the plain frame too: the colour never reaches round the whole item.
	inv.call("_pick", ch.entry_of("ring_of_protection"))
	await _frames(1)
	var lit := _row(inv, "ring_of_protection")
	assert_ne((lit.get_theme_stylebox("panel") as StyleBoxFlat).border_color, ItemTile.rarity_edge("rare"), "the picked row isn't blue")
	assert_eq(_frame_colour(lit), ItemTile.rarity_edge("rare"), "its picture is")
	# The doll's tiles draw the same box round the picture.
	ch.wear("ring_of_protection")
	inv.call("_draw")
	await _frames(1)
	var worn: ItemTile = null
	for n in inv.find_children("*", "ItemTile", true, false):
		if str((n as ItemTile).payload.get("id", "")) == "ring_of_protection" and str((n as ItemTile).payload.get("from", "")) == "slot":
			worn = n as ItemTile
	assert_true(worn != null and worn.rarity == "rare", "the worn ring's tile knows it is rare")
	# The stash's rows too.
	GameState.story.stash.append({"id": "potion_of_speed", "qty": 1})
	inv.call("_draw")
	await _frames(1)
	var in_stash := false
	for n in inv.find_child("StashZone", true, false).find_children("RarityFrame", "PanelContainer", true, false):
		in_stash = in_stash or (n as PanelContainer).get_theme_stylebox("panel").get("border_color") == ItemTile.rarity_edge("very_rare")
	assert_true(in_stash, "the stashed Potion of Speed has a very rare box")


## A rarity the border has no colour for would fall back to lilac: every magic item must be one of the six.
func test_every_magic_item_has_one_of_the_six_rarities() -> void:
	var odd: Array[String] = []
	var n := 0
	for data in _all_items():
		if not MagicItems.is_magic(data):
			continue
		n += 1
		if not MagicItems.rarity(data) in RARITIES:
			odd.append("%s (%s)" % [data.get("id", ""), MagicItems.rarity(data)])
	assert_true(n > 0)
	assert_true(odd.is_empty(), "magic items without a known rarity: %s" % [odd])
	for r in RARITIES:
		assert_true(ItemNotices.RARITY_COLOURS.has(r), "a colour for %s" % r)


func test_the_attuned_filter_lists_what_the_hero_is_attuned_to() -> void:
	var ch := GameState.story.party[0]
	ch.attuned.clear()
	for id: String in ["ring_of_protection", "cloak_of_protection", "ring_of_warmth", "potion_of_healing", "rope"]:
		ch.add_item(id)
	ch.wear("ring_of_protection")
	ch.wear("cloak_of_protection")
	ch.attune("ring_of_protection")
	ch.attune("cloak_of_protection")
	var inv := await _open(0)
	assert_true(_button(inv, "Attuned 2") != null, "the Attuned toggle counts the two")
	_button(inv, "Attuned 2").pressed.emit()
	await _frames(1)
	assert_eq(inv.marks, InventoryScreen.MARK_ATTUNED)
	var shown := inv.shown_ids()
	shown.sort()
	assert_eq(shown, ["cloak_of_protection", "ring_of_protection"] as Array[String],
		"only the attuned items: the ring in the pack that needs attunement (Warmth) and the potion are left out")
	assert_true(InventoryScreen.is_attuned(ch, ch.entry_of("ring_of_protection")), "attuned")
	assert_false(InventoryScreen.is_attuned(ch, ch.entry_of("ring_of_warmth")), "carried, not attuned")
	assert_false(InventoryScreen.is_attuned(ch, ch.entry_of("potion_of_healing")), "a potion needs no attunement")
	assert_false(InventoryScreen.is_attuned(ch, ch.entry_of("rope")), "nor does rope")
	# It combines with the tabs and the search.
	inv.filter = "Armor"
	inv.call("_draw")
	await _frames(1)
	assert_true(inv.shown_ids().is_empty(), "no attuned armor here")
	inv.filter = "Magic"
	inv.search = "ring"
	inv.call("_draw")
	await _frames(1)
	assert_eq(inv.shown_ids(), ["ring_of_protection"] as Array[String], "Magic, attuned and 'ring'")
	# Ending an attunement takes it out of the list; the toggle switches off by itself.
	ch.end_attunement("ring_of_protection")
	inv.search = ""
	inv.filter = "All"
	inv.call("_draw")
	await _frames(1)
	assert_eq(inv.shown_ids(), ["cloak_of_protection"] as Array[String], "one left")
	_button(inv, "Attuned 1").pressed.emit()
	await _frames(1)
	assert_eq(inv.marks, "", "pressed again: off")
	assert_true(inv.shown_ids().size() >= 5, "everything again")


func test_an_empty_attuned_list_says_why() -> void:
	GameState.story.party[1].attuned.clear()
	var inv := await _open(1)
	inv.marks = InventoryScreen.MARK_ATTUNED
	inv.call("_draw")
	await _frames(1)
	var text := ""
	for l in (inv.get("_list_foot") as Node).find_children("*", "Label", true, false):
		if not (l as Node).is_queued_for_deletion():
			text += (l as Label).text
	assert_true(text.contains("Nothing attuned"), "the empty list says so: %s" % text)
	assert_true(_button(inv, "Attuned 0") != null)


func test_the_shop_shares_the_tabs_and_picture_boxes() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("potion_of_healing")
	ch.add_item("antitoxin")
	ch.add_item("st_andrals_bones")
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open_for(root, GameState.story, "father_lucian")   # potions, scrolls and more
	ShopScreen.only_buys = false
	shop.pick_filter("Potions")
	assert_true("potion_of_healing" in shop.sell_ids() and not "antitoxin" in shop.sell_ids(), "Potions: %s" % [shop.sell_ids()])
	shop.pick_filter("Consumables")
	assert_true("antitoxin" in shop.sell_ids() and not "potion_of_healing" in shop.sell_ids(), "Consumables: %s" % [shop.sell_ids()])
	shop.pick_filter("Quest")
	assert_true("st_andrals_bones" in shop.sell_ids(), "the Quest tab lists the bones, which no merchant buys: %s" % [shop.sell_ids()])
	for id in shop.sell_ids():
		assert_true(InventoryScreen.is_quest(Compendium.shared().item_data(id)), "%s is a quest item" % id)
	# The wares side splits its potions off too.
	assert_eq(ShopScreen.ware_kind({"id": "potion_of_healing"}), "Potions")
	assert_eq(ShopScreen.ware_kind({"id": "antitoxin"}), "Consumables")
	var tabs := ShopScreen.ware_tabs(GameState.story.shop_wares("father_lucian"))
	assert_true("Potions" in tabs, "Lucian sells potions: %s" % [tabs])
	shop.pick_ware_filter("Potions")
	assert_false(shop.ware_ids().is_empty())
	for id in shop.ware_ids():
		assert_eq(ShopScreen.ware_kind({"id": id}), "Potions", "%s is a potion" % id)
	# A framed picture: the rarity's colour round it, or the same room bare.
	var framed := UiParts.framed_icon("item", "potion_of_speed", ItemTile.rarity_edge("very_rare"))
	assert_eq((framed.get_theme_stylebox("panel") as StyleBoxFlat).border_color, ItemTile.rarity_edge("very_rare"))
	var bare := UiParts.framed_icon("item", "rope", Color.TRANSPARENT)
	assert_eq(bare.get_combined_minimum_size(), framed.get_combined_minimum_size(), "bare or framed, the same room")
	framed.free()
	bare.free()
	# On the sell side and the wares side the box is on the picture; the row keeps the plain gilt border.
	shop.pick_filter("Potions")
	var frames := shop.find_child("PackSide", true, false).find_children("RarityFrame", "PanelContainer", true, false)
	assert_false(frames.is_empty(), "the pack side's potions have framed pictures")
	var common := false
	for f in frames:
		common = common or (f as PanelContainer).get_theme_stylebox("panel").get("border_color") == ItemTile.rarity_edge("common")
	assert_true(common, "the Potion of Healing is common")
	shop.queue_free()


func _rarity_chip(inv: InventoryScreen, r: String) -> Button:
	return inv.find_child("Rarity_%s" % r, true, false) as Button


func _press_chip(inv: InventoryScreen, r: String) -> void:
	var chip := _rarity_chip(inv, r)
	assert_true(chip != null and not chip.disabled, "the %s chip can be pressed" % r)
	chip.pressed.emit()
	await _frames(1)


## The rarity of each shown item, as the filter sees it.
func _rarities_shown(inv: InventoryScreen) -> Array[String]:
	var out: Array[String] = []
	for id in inv.shown_ids():
		var r := InventoryScreen.rarity_of(Compendium.shared().item_data(id))
		if not r in out:
			out.append(r)
	out.sort()
	return out


func test_the_rarity_filter_keeps_the_chosen_rarities_and_combines_with_the_rest() -> void:
	var ids := {"common": "potion_of_healing", "uncommon": "ring_of_warmth", "rare": "ring_of_protection",
		"very_rare": "potion_of_speed", "legendary": "potion_of_giant_strength_storm", "artifact": "orb_of_damara"}
	var ch := GameState.story.party[0]
	ch.attuned.clear()
	for r: String in ids:
		ch.add_item(str(ids[r]))
	ch.add_item("rope")
	ch.wear("ring_of_protection")
	ch.attune("ring_of_protection")
	var inv := await _open(0)
	for r in RARITIES:
		var chip := _rarity_chip(inv, r)
		assert_true(chip != null, "a chip for %s" % r)
		assert_false(chip.disabled, "%s: the pack has one" % r)
		assert_ne(chip.focus_mode, Control.FOCUS_NONE, "%s: the keyboard and a pad can reach it" % r)
		assert_true(chip.tooltip_text.begins_with("1 "), "%s: its tooltip counts: %s" % [r, chip.tooltip_text])
	assert_true(inv.rarities.is_empty() and "rope" in inv.shown_ids(), "no rarity chosen keeps everything, rope too")
	# One rarity: only magic items of it.
	await _press_chip(inv, "rare")
	assert_eq(inv.rarities, ["rare"] as Array[String])
	assert_eq(_rarities_shown(inv), ["rare"] as Array[String], "only rare items: %s" % [inv.shown_ids()])
	assert_true("ring_of_protection" in inv.shown_ids() and not "rope" in inv.shown_ids(), "the ring, not the rope")
	# Two together.
	await _press_chip(inv, "very_rare")
	assert_eq(_rarities_shown(inv), ["rare", "very_rare"] as Array[String], "rare and very rare: %s" % [inv.shown_ids()])
	assert_true("potion_of_speed" in inv.shown_ids() and "ring_of_protection" in inv.shown_ids())
	# With a tab.
	inv.filter = "Potions"
	inv.call("_draw")
	await _frames(1)
	assert_eq(inv.shown_ids(), ["potion_of_speed"] as Array[String], "the Potions tab and very rare or rare: only the Potion of Speed")
	# With the Attuned filter.
	inv.filter = "All"
	inv.marks = InventoryScreen.MARK_ATTUNED
	inv.call("_draw")
	await _frames(1)
	assert_eq(inv.shown_ids(), ["ring_of_protection"] as Array[String], "attuned and rare or very rare: the ring")
	# With the search.
	inv.marks = ""
	inv.search = "ring"
	inv.call("_draw")
	await _frames(1)
	assert_eq(inv.shown_ids(), ["ring_of_protection"] as Array[String], "'ring' and rare or very rare")
	inv.search = ""
	# Nothing matches: it says why.
	inv.rarities.assign(["artifact"])
	inv.filter = "Potions"
	inv.call("_draw")
	await _frames(1)
	assert_true(inv.shown_ids().is_empty())
	var text := ""
	for l in (inv.get("_list_foot") as Node).find_children("*", "Label", true, false):
		if not (l as Node).is_queued_for_deletion():
			text += (l as Label).text
	assert_true(text.contains("artifact"), "an empty list names the rarity: %s" % text)
	# Pressing a lit chip clears it; all cleared is everything again.
	inv.filter = "All"
	inv.call("_draw")
	await _frames(1)
	await _press_chip(inv, "artifact")
	assert_true(inv.rarities.is_empty(), "pressed again: off")
	assert_true("rope" in inv.shown_ids() and "orb_of_damara" in inv.shown_ids(), "everything again")


func test_a_rarity_nothing_has_is_greyed_out_and_the_six_chips_fit() -> void:
	var ch := GameState.story.party[1]
	ch.add_item("potion_of_healing")
	var inv := await _open(1)
	assert_false(_rarity_chip(inv, "common").disabled, "the hero has a common item")
	for r: String in ["uncommon", "rare", "very_rare", "legendary", "artifact"]:
		assert_true(_rarity_chip(inv, r).disabled, "%s: nothing in the pack, so greyed out" % r)
	# They fit the pack pane, beside their caption, at the narrowest the pack column goes.
	var row := inv.find_child("RarityRow", true, false) as HBoxContainer
	var zone := inv.find_child("PackZone", true, false) as Control
	assert_true(row != null and zone != null)
	assert_eq(row.get_child_count(), RARITIES.size() + 1, "the caption and six chips")
	assert_true(row.get_combined_minimum_size().x <= row.size.x + 0.5,
		"the rarity row needs %.0f px of %.0f" % [row.get_combined_minimum_size().x, row.size.x])
	for c in row.get_children():
		var r := (c as Control).get_global_rect()
		assert_true(zone.get_global_rect().grow(0.5).encloses(r), "%s sits inside the pack pane" % c.name)
	for c in row.get_children():
		if c is Button:
			assert_true((c as Button).get_minimum_size().x <= (c as Button).size.x + 0.5, "%s holds its label" % (c as Button).text)
