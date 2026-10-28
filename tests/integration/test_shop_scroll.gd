extends TestCase
## The merchant's lists keep their scroll position when something is bought or sold (Ashwin, 2026-10-28: "when buying or
## selling at a merchant, the item list must keep its scroll position (it jumps to the top today)"). A new tab or another
## hero still starts a list at the top.

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 2):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	root = Node.new()
	add_child(root)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	ShopScreen.sell_filter = "All"
	ShopScreen.only_buys = true
	ShopScreen.ware_filter = "All"
	await get_tree().process_frame
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scroll(shop: ShopScreen, name_: String) -> ScrollContainer:
	return shop.find_child(name_, true, false) as ScrollContainer


## A shop with a pack long enough to scroll.
func _shop() -> ShopScreen:
	var ch := GameState.story.party[0]
	var n := 0
	for id: String in (Compendium.shared().tables["items"] as Dictionary).keys():
		if n >= 60:
			break
		if str(Compendium.shared().item_data(id).get("category", "")) in ["potion", "consumable", "scroll", "gear"]:
			ch.add_item(id)
			n += 1
	GameState.story.gold = 100000.0
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open_for(root, GameState.story, "father_lucian")
	ShopScreen.only_buys = false
	shop.pick_filter("All")
	return shop


func test_a_sale_keeps_the_pack_where_it_was_scrolled() -> void:
	var shop := _shop()
	await _frames(3)
	var pack := _scroll(shop, ShopScreen.PACK_SCROLL)
	assert_true(pack != null, "the pack's list is a named scroll")
	assert_true(pack.get_v_scroll_bar().max_value > pack.size.y + 200.0, "the pack is long enough to scroll")
	pack.scroll_vertical = 300
	await _frames(2)
	assert_eq(pack.scroll_vertical, 300)
	var ids := shop.sell_ids()
	var sold := ""
	for id in ids:
		if GameState.story.shop_offer("father_lucian", str(id)) >= 0.0:
			sold = str(id)
			break
	assert_true(sold != "", "something the merchant buys")
	shop.call("_sell", sold)
	await _frames(4)
	var again := _scroll(shop, ShopScreen.PACK_SCROLL)
	assert_true(again != null, "the list was drawn again")
	assert_between(again.scroll_vertical, 280, 300, "where it was, not back at the top")


func test_a_purchase_keeps_the_wares_where_they_were_scrolled() -> void:
	var shop := _shop()
	await _frames(3)
	var wares := _scroll(shop, ShopScreen.WARES_SCROLL)
	assert_true(wares != null)
	if wares.get_v_scroll_bar().max_value <= wares.size.y + 60.0:
		return   # a short list has nothing to keep
	wares.scroll_vertical = 120
	await _frames(2)
	var bought := ""
	for id in shop.ware_ids():
		bought = str(id)
		break
	shop.call("_buy", bought)
	await _frames(4)
	assert_between(_scroll(shop, ShopScreen.WARES_SCROLL).scroll_vertical, 100, 120, "the wares stay where they were")


func test_another_tab_starts_at_the_top() -> void:
	var shop := _shop()
	await _frames(3)
	_scroll(shop, ShopScreen.PACK_SCROLL).scroll_vertical = 300
	await _frames(2)
	shop.pick_filter("Potions")
	await _frames(3)
	assert_eq(_scroll(shop, ShopScreen.PACK_SCROLL).scroll_vertical, 0, "a new tab begins at the top")
