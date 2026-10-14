extends TestCase
## Inventory search and junk (U3) and the stash from anywhere (Q7, owner 2026-10-07: things go in from anywhere and
## come out only at a safe place): the search box, the New and Junk marks and filters, Sell all junk at a merchant and
## the shop's filters on the pack side, stashing from the pack and the loot window with an item's own state kept.

var root: Node


func before_each() -> void:
	for id: String in ["junk_inn", "junk_road"]:
		Compendium.shared().tables["locations"][id] = {"id": id, "name": id.capitalize(), "region": "test", "summary": "",
			"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
			"rest": "safe" if id == "junk_inn" else "wild"}
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 4):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "junk_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	# The made-up places leave the shared Compendium, so later tests in this process (test_skirmish walks every
	# location) never meet them.
	for id: String in ["junk_inn", "junk_road"]:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)
	# The shop's pack-side choices last the session (static): back to how a new game starts.
	ShopScreen.sell_filter = "All"
	ShopScreen.only_buys = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(i: int) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	return root.get("screen") as InventoryScreen


## The items the backpack grid shows now, by id.
func _listed(inv: InventoryScreen) -> Array[String]:
	return inv.shown_ids()


func _button(n: Node, text: String, exact: bool = false) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if not (b as Node).is_queued_for_deletion() and ((b as Button).text == text if exact else (b as Button).text.begins_with(text)):
			return b as Button
	return null


func test_starting_gear_is_not_new_and_finds_are() -> void:
	var ch := GameState.story.party[0]
	for e in ch.inventory:
		assert_false(bool(e.get("new", false)), "%s came with %s: not new" % [ch.name, e["id"]])
	ch.add_item("rope")
	ch.add_item("potion_of_healing", 2)
	assert_true(bool(ch.entry_of("rope").get("new", false)), "a find is new")
	var inv := await _open(0)
	inv.marks = "new"
	inv.call("_draw")
	var shown := _listed(inv)
	assert_eq(shown.size(), 2, "only the two finds under New: %s" % [shown])
	assert_true(_button(inv, "New 2") != null, "the New toggle counts them")
	root.call("close_screen")
	await _frames(2)
	assert_false(bool(ch.entry_of("rope").get("new", false)), "seen once the page was shown and closed")


func test_search_finds_by_name_kind_and_rarity() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("rope")
	ch.add_item("potion_of_healing", 2)
	ch.add_item("wand_of_secrets")
	var inv := await _open(0)
	inv.search = "potion"
	inv.call("_fill_list")
	await _frames(1)
	assert_eq(_listed(inv), ["potion_of_healing"] as Array[String], "search by name")
	inv.search = "WAND secrets"
	inv.call("_fill_list")
	await _frames(1)
	assert_eq(_listed(inv).size(), 1, "every word must match, in any case")
	inv.search = "zzz"
	inv.call("_fill_list")
	await _frames(1)
	var text := ""
	for l in (inv.get("_list_foot") as Node).find_children("*", "Label", true, false):
		if not (l as Node).is_queued_for_deletion():
			text += (l as Label).text
	assert_true(text.contains("matches"), "an empty search says so: %s" % text)
	inv.search = ""
	inv.filter = "Magic"
	inv.call("_draw")
	await _frames(1)
	for id in _listed(inv):
		assert_true(id.contains("wand") or id.contains("potion"), "the Magic filter keeps magic items only: %s" % id)


func test_mark_as_junk_and_the_junk_filter() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("flail")
	ch.add_item("st_andrals_bones")
	var inv := await _open(0)
	inv.selected = "flail"
	inv.call("_draw")
	await _frames(1)
	var mark := _button(inv.get("_card") as Node, "Mark as junk")
	assert_true(mark != null and not mark.disabled, "the card offers Mark as junk")
	mark.pressed.emit()
	await _frames(1)
	assert_true(InventoryScreen.is_junk(ch.entry_of("flail")), "marked")
	inv.marks = "junk"
	inv.call("_draw")
	await _frames(1)
	assert_eq(_listed(inv), ["flail"] as Array[String], "the Junk filter shows it alone")
	inv.selected = "st_andrals_bones"
	inv.marks = ""
	inv.call("_draw")
	await _frames(1)
	var bones := _button(inv.get("_card") as Node, "Mark as junk")
	assert_true(bones != null and bones.disabled, "a quest item can't be junk")
	assert_true(_button(inv.get("_card") as Node, "Send to the stash").disabled, "or stashed")


func test_sell_all_junk_sells_every_pack_but_not_what_is_worn() -> void:
	var a := GameState.story.party[0]
	var b := GameState.story.party[1]
	a.add_item("flail")
	b.add_item("rope")
	b.add_item("javelin", 3)
	InventoryScreen.set_junk(a, "flail", true)
	InventoryScreen.set_junk(b, "rope", true)
	InventoryScreen.set_junk(b, "javelin", true)
	# A weapon worn and a spare of the same kind, both marked: only the spare goes.
	var worn := str(a.equipped("main_hand").get("id", ""))
	assert_true(worn != "", "%s holds a weapon" % a.name)
	a.add_item(worn)
	InventoryScreen.set_junk(a, worn, true)
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open_for(root, GameState.story, "gunther_arasek")
	var expected := 0.0
	var pieces := 0
	for j in shop.junk_for_sale():
		expected += float(j["offer"]) * int(j["qty"])
		pieces += int(j["qty"])
	assert_eq(pieces, 6, "flail, rope, three javelins and the spare weapon")
	var gold := GameState.story.gold
	var sell := _button(shop, "Sell all junk")
	assert_true(sell != null and not sell.disabled, "the button is there")
	sell.pressed.emit()
	assert_true(is_equal_approx(GameState.story.gold, gold + expected), "paid %.2f, got %.2f" % [expected, GameState.story.gold - gold])
	assert_true(a.entry_of("flail").is_empty() and b.entry_of("rope").is_empty() and b.entry_of("javelin").is_empty(), "the junk is gone")
	assert_eq(str(a.equipped("main_hand").get("id", "")), worn, "the weapon in hand stays")
	shop.queue_free()


func test_stash_from_anywhere_take_out_only_at_a_safe_place() -> void:
	GameState.story.location = "junk_road"
	var ch := GameState.story.party[0]
	ch.add_item("wand_of_secrets")
	ch.entry_of("wand_of_secrets")["charges"] = 1
	var inv := await _open(0)
	assert_false(inv.call("_stash_open"), "the road isn't safe")
	inv.selected = "wand_of_secrets"
	inv.call("_draw")
	await _frames(1)
	var send := _button(inv.get("_card") as Node, "Send to the stash")
	assert_true(send != null and not send.disabled, "sending works on the road")
	send.pressed.emit()
	await _frames(1)
	assert_true(ch.entry_of("wand_of_secrets").is_empty(), "it left the pack")
	assert_true(GameState.story.party_has_item("wand_of_secrets"), "and waits in the stash")
	assert_true(_stash_tiles(inv).is_empty(), "but nothing can be dragged out of the stash here")
	root.call("close_screen")
	GameState.story.location = "junk_inn"
	inv = await _open(0)
	var out := _stash_tiles(inv)
	assert_eq(out.size(), 1, "at the inn it can")
	inv.call("_drop_on_pack", out[0].payload)
	assert_eq(int(ch.entry_of("wand_of_secrets").get("charges", -1)), 1, "with the charges it had, not a fresh wand's")


## The stash's rows that can be dragged out (only at a safe place).
func _stash_tiles(inv: InventoryScreen) -> Array[ItemTile.Row]:
	var out: Array[ItemTile.Row] = []
	for n in inv.find_children("*", "", true, false):
		if n is ItemTile.Row and not (n as Node).is_queued_for_deletion() and str((n as ItemTile.Row).payload.get("from", "")) == "stash":
			out.append(n as ItemTile.Row)
	return out


func test_loot_goes_to_the_stash_with_its_state() -> void:
	GameState.story.location = "junk_road"
	var lw := LootWindow.new()
	root.add_child(lw)
	lw.show_loot(GameState.story, "chest", [{"id": "wand_of_secrets", "qty": 1, "charges": 2, "made": true}, {"id": "rope", "qty": 1},
		{"id": "torch", "qty": 5}], 7.0, null)
	await _frames(1)
	var gold := GameState.story.gold
	lw.call("_stash", 0)
	assert_eq(lw.items.size(), 2, "the wand left the chest")
	lw.stash_all()
	assert_true(is_equal_approx(GameState.story.gold, gold + 7.0), "the coins to the purse")
	var found := {}
	for e in GameState.story.stash:
		found[str(e["id"])] = e
	assert_eq(found.keys().size(), 3, "all three in the stash: %s" % [found.keys()])
	assert_eq(int((found["torch"] as Dictionary)["qty"]), 5)
	assert_eq(int((found["wand_of_secrets"] as Dictionary).get("charges", -1)), 2, "the wand keeps its charges")


## The shop's pack side (owner, 2026-10-13): the inventory's filter tabs, and Only what <merchant> buys, on at first,
## which leaves out what that merchant won't take. Both hold for the rest of the session, at the next counter too, and
## a pad's LB/RB step the tabs.
func test_shop_pack_filters_and_only_what_they_buy() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("potion_of_healing")
	ch.add_item("rope")
	ch.add_item("flail")
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open_for(root, GameState.story, "gunther_arasek")   # arms, armor and gear; no potions
	assert_true(ShopScreen.only_buys, "on at first")
	var ids := shop.sell_ids()
	assert_true("flail" in ids and "rope" in ids, "what Gunther buys shows: %s" % str(ids))
	assert_false("potion_of_healing" in ids, "a potion he won't buy is left out")
	assert_true(_button(shop, "Won't buy", true) == null, "so no row says Won't buy")
	var only := _button(shop, "Only what Gunther buys", true)
	assert_true(only != null, "the switch names him")
	only.pressed.emit()
	assert_false(ShopScreen.only_buys)
	assert_true("potion_of_healing" in shop.sell_ids(), "switched off: the whole pack")
	assert_true(_button(shop, "Won't buy", true) != null, "with what he won't buy marked")
	_button(shop, "Weapons", true).pressed.emit()
	ids = shop.sell_ids()
	assert_true("flail" in ids and not "rope" in ids and not "potion_of_healing" in ids, "the Weapons tab: %s" % str(ids))
	for id in ids:
		assert_true(InventoryScreen.in_filter("Weapons", Compendium.shared().item_data(id)), "%s is a weapon or ammunition" % id)
	assert_true(PadNav.current.tab(shop, 1), "LB/RB find the tabs")
	assert_eq(ShopScreen.sell_filter, "Armor", "RB: the next tab")
	PadNav.current.tab(shop, 1)
	assert_eq(ShopScreen.sell_filter, "Consumables")
	assert_true("potion_of_healing" in shop.sell_ids(), "the potion, with the switch off")
	_button(shop, "Only what Gunther buys", true).pressed.emit()
	assert_true(shop.sell_ids().is_empty(), "with it on: Gunther buys no consumables")
	assert_true(_label(shop, "No consumables in %s's pack that Gunther buys." % ch.name.get_slice(" ", 0)) != null, "and the pane says so")
	shop.queue_free()
	# The next counter keeps both choices, and names a priest with his title.
	var temple := ShopScreen.new()
	root.add_child(temple)
	temple.open_for(root, GameState.story, "father_lucian")   # potions and scrolls
	assert_eq(ShopScreen.sell_filter, "Consumables", "the tab holds")
	assert_true(ShopScreen.only_buys, "and so does the switch")
	assert_true("potion_of_healing" in temple.sell_ids(), "Father Lucian buys the potion")
	assert_true(_button(temple, "Only what Father Lucian buys", true) != null)
	temple.pick_filter("Weapons")
	assert_true(temple.sell_ids().is_empty(), "he buys no weapons")
	assert_true(_label(temple, "No weapons in %s's pack that Father Lucian buys." % ch.name.get_slice(" ", 0)) != null, "and the pane says so")
	temple.queue_free()


func _label(n: Node, text: String) -> Label:
	for l in n.find_children("*", "Label", true, false):
		if not (l as Node).is_queued_for_deletion() and (l as Label).text == text:
			return l as Label
	return null
