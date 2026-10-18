extends TestCase
## The inventory's categories and marks (owner, 2026-10-17): Potions and Quest items have tabs of their own, a magic
## item's row is edged in the colour of its rarity, and an Attuned filter sits beside New and Junk. The shop's pack side
## shares the tabs, the rows' edges and the wares' Potions tab.

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


func test_magic_rows_have_a_border_in_their_rarity_colour() -> void:
	var comp := Compendium.shared()
	var ids := {"common": "potion_of_healing", "uncommon": "cloak_of_protection", "rare": "ring_of_protection",
		"very_rare": "potion_of_speed", "legendary": "potion_of_giant_strength_storm", "artifact": "orb_of_damara"}
	var ch := GameState.story.party[0]
	for r: String in ids:
		assert_eq(MagicItems.rarity(comp.item_data(str(ids[r]))), r, "%s is %s" % [ids[r], r])
		ch.add_item(str(ids[r]))
	ch.add_item("rope")
	var inv := await _open(0)
	var seen: Array[Color] = []
	for r: String in ids:
		var row := _row(inv, str(ids[r]))
		assert_true(row != null, "a row for the %s item (the pack lists %s)" % [r, inv.shown_ids()])
		if row == null:
			continue
		assert_eq(row.rarity, r, "the row knows its rarity")
		assert_eq(_border(row), ItemTile.rarity_edge(r), "the %s row's border" % r)
		assert_eq((row.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left, 2, "a heavier border than a plain row")
		seen.append(_border(row))
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			assert_ne(seen[i], seen[j], "%s and %s have different borders" % [RARITIES[i], RARITIES[j]])
	var rope := _row(inv, "rope")
	assert_eq(rope.rarity, "", "a plain item has no rarity")
	assert_eq((rope.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left, 1, "and keeps its fine gilt border")
	for r in RARITIES:
		assert_ne(_border(rope), ItemTile.rarity_edge(r), "the plain border is none of the rarities'")
	# The picked row keeps its rarity colour, and a heavier edge.
	inv.call("_pick", ch.entry_of("ring_of_protection"))
	await _frames(1)
	var lit := _row(inv, "ring_of_protection")
	assert_eq(_border(lit), ItemTile.rarity_edge("rare"), "the picked row is still blue")
	assert_eq((lit.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left, 3, "only thicker")


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


func test_the_shop_shares_the_tabs_and_edges() -> void:
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
	# A row's edge: the rarity's colour, heavier than a plain row's.
	var edged := UiParts.row(Control.new(), Callable(), false, 7, ItemTile.rarity_edge("very_rare"))
	assert_eq(_border(edged), ItemTile.rarity_edge("very_rare"))
	assert_eq((edged.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left, 2)
	var plain := UiParts.row(Control.new())
	assert_eq((plain.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left, 1)
	edged.free()
	plain.free()
	shop.queue_free()
