extends TestCase
## Magic items for sale (Ashwin, 2026-10-14): every magic item the story doesn't need is sold by a merchant somewhere,
## at its price in Sane Magical Prices, the guide he picked (data/treasure/magic_prices.json, written into each item's
## cost_gp by tools/data/magic_prices.py), and a merchant shows an item once the party's milestone level reaches its
## rarity's (data/treasure/levels.json shop_levels). Story items, artifacts, cursed or disguised items and what the guide
## won't price are never sold. A merchant's magic stock (`magic` in their shop) is priced the guide's way whatever they
## mark their other goods up by, and an item made on a weapon or armor lets the party pick which.

const TABLE := "res://data/treasure/magic_prices.json"


func after_each() -> void:
	(Compendium.shared().tables["npcs"] as Dictionary).erase("test_magic_seller")


func _table() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TABLE)) as Dictionary


## A party whose milestone level is `level`.
func _party(level: int) -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", level))
	st.start_level = level
	st.gold = 1000000.0
	st.playthrough_seed = 7
	return st


## Every merchant: npc id -> its shop.
func _shops() -> Dictionary:
	var out := {}
	for id: String in Compendium.shared().table("npcs"):
		var npc := Compendium.shared().get_entry("npcs", id)
		if npc.has("shop"):
			out[id] = npc["shop"]
	return out


## Every item id a shop can ever sell: its lines, its rotating pools and its magic stock.
func _names(shop: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for w: Variant in shop.get("sells", []):
		out.append(str((w as Dictionary)["id"]))
	var rot := shop.get("rotating", {}) as Dictionary
	for g: Variant in rot.get("groups", [rot]):
		for id: Variant in (g as Dictionary).get("pool", []):
			out.append(str(id))
	for id: Variant in shop.get("magic", []):
		out.append(str(id))
	return out


## The item a sold id is, or is built on: "flame_tongue__rapier" is a Flame Tongue.
func _item_of(id: String) -> String:
	return id.get_slice(MagicItems.SEP, 0)


func test_every_magic_item_the_story_doesnt_need_is_for_sale() -> void:
	var excluded := _table()["excluded"] as Dictionary
	var sold := {}       # item -> merchants
	var scroll_levels := {}
	for npc: String in _shops():
		for id in _names(_shops()[npc] as Dictionary):
			if not sold.has(_item_of(id)):
				sold[_item_of(id)] = []
			(sold[_item_of(id)] as Array).append(npc)
			var data := Compendium.shared().item_data(id)
			if data.has("scroll_spell"):
				scroll_levels[int(Compendium.shared().spell_data(str(data["scroll_spell"])).get("level", 0))] = true
	var count := 0
	for item: Dictionary in Compendium.shared().all("magic_items"):
		var id := str(item["id"])
		if not Compendium.playable(item) or excluded.has(id) or id == "spell_scroll":
			continue
		count += 1
		assert_true(sold.has(id), "%s is for sale somewhere" % id)
		# Someone who never joins the party sells it, so taking a merchant along (Kasimir, Davian, Van Richten) loses nothing.
		var stays := (sold.get(id, []) as Array).filter(func(n: String) -> bool:
			return not bool(Compendium.shared().get_entry("npcs", n).get("guest", false)))
		assert_false(stays.is_empty(), "%s is sold by someone who stays put, not only %s" % [id, sold.get(id, [])])
	assert_true(count > 450, "the playable magic items: %d" % count)
	for lvl in 10:
		assert_true(scroll_levels.has(lvl), "a level %d Spell Scroll is for sale somewhere" % lvl)


func test_no_story_item_artifact_cursed_or_unpriced_item_is_sold() -> void:
	var excluded := _table()["excluded"] as Dictionary
	for id: String in ["sunsword", "holy_symbol_of_ravenkind", "tome_of_strahd", "wave", "blackrazor", "berserker_axe",
			"potion_of_poison", "deck_of_many_things", "luck_blade"]:
		assert_true(excluded.has(id), "%s stays off the shelves" % id)
	for npc: String in _shops():
		for id in _names(_shops()[npc] as Dictionary):
			var data := Compendium.shared().item_data(id)
			assert_false(excluded.has(_item_of(id)), "%s sells %s (%s)" % [npc, id, excluded.get(_item_of(id), "")])
			assert_false(MagicItems.is_cursed(data), "%s sells cursed %s" % [npc, id])
			assert_false(data.has("disguise"), "%s sells %s, which passes for something else" % [npc, id])
			assert_true(Compendium.playable(data) or data.is_empty(), "%s sells %s, which isn't in play" % [npc, id])
			assert_false(data.is_empty(), "%s sells %s, which is a real item" % [npc, id])


## The table's own arithmetic, done again here: the guide's row (times a count), its median for the rarity, or the
## 2024 DMG's price for a common item the guide has nothing like.
func _expected(item: Dictionary, how: Dictionary, guide: Dictionary) -> float:
	if how.has("gp"):
		return float(how["gp"])
	if how.has("guide") or how.has("like"):
		var names: Variant = how.get("guide", how.get("like"))
		var total := 0.0
		for n: Variant in (names if names is Array else [names]):
			assert_true(guide.has(str(n)), "the guide has a row %s" % n)
			total += float((guide.get(str(n), {}) as Dictionary).get("gp", 0))
		return total * float(how.get("times", 1))
	var rarity := MagicItems.rarity(item)
	var cons := MagicItems.is_consumable(item)
	if str(how.get("rule", "")) == "book":
		return MagicItems.price_for(rarity, cons)
	var prices: Array[float] = []
	for row: Variant in guide.values():
		var r := row as Dictionary
		if str(r["rarity"]) == rarity and (str(r["list"]) == "consumable") == cons:
			prices.append(float(r["gp"]))
	prices.sort()
	var mid := prices.size() / 2
	return prices[mid] if prices.size() % 2 == 1 else (prices[mid - 1] + prices[mid]) / 2.0


func test_prices_are_the_guides() -> void:
	var t := _table()
	var guide := t["guide"] as Dictionary
	assert_eq(guide.size(), 307, "the guide's priced rows (the Robe of Useful Items prices by its contents)")
	assert_eq(float((guide["Holy Avenger"] as Dictionary)["gp"]), 165000.0)
	assert_eq(float((guide["Potion of Healing"] as Dictionary)["gp"]), 50.0)
	for id: String in t["items"]:
		var item := Compendium.shared().item_data(id)
		assert_false(item.is_empty(), id)
		assert_eq(float(item.get("cost_gp", -1)), snappedf(_expected(item, t["items"][id] as Dictionary, guide), 0.01), "%s's price" % id)
	for lvl in 10:
		assert_eq(MagicItems.SCROLL_PRICE[lvl], float((t["scrolls"] as Array)[lvl]), "a level %d scroll" % lvl)
	assert_eq(float(Compendium.shared().item_data("spell_scroll__fireball")["cost_gp"]), 200.0, "level 3")
	assert_eq(float(Compendium.shared().item_data("spell_scroll__meteor_swarm")["cost_gp"]), 10240.0, "level 9")
	# Spot checks against the PDF: an item the guide lists, one made on a base (its cost added), one by count.
	assert_eq(float(Compendium.shared().item_data("alchemy_jug")["cost_gp"]), 6000.0)
	assert_eq(float(Compendium.shared().item_data("flame_tongue__rapier")["cost_gp"]), 5000.0 + 25.0, "a Flame Tongue Rapier")
	assert_eq(float(Compendium.shared().item_data("restorative_ointment")["cost_gp"]), 420.0, "3.5 doses at 120 gp")
	assert_eq(float(Compendium.shared().item_data("weapon_plus_1__longsword")["cost_gp"]), 1015.0)
	# Every playable item that's for sale is priced by the table.
	var excluded := t["excluded"] as Dictionary
	for item: Dictionary in Compendium.shared().all("magic_items"):
		var id := str(item["id"])
		if Compendium.playable(item) and not excluded.has(id) and id != "spell_scroll":
			assert_true((t["items"] as Dictionary).has(id), "%s has a price in the table" % id)


func test_magic_stock_waits_for_the_partys_level() -> void:
	var seen := {1: {}, 5: {}, 9: {}, 10: {}}
	for level: int in seen:
		var st := _party(level)
		st.set_flag("keepers_allied")
		for npc: String in _shops():
			for line in Trade.magic_stock(st, npc):
				(seen[level] as Dictionary)[MagicItems.rarity(Compendium.shared().item_data(str(line["id"])))] = true
	assert_false((seen[1] as Dictionary).has("rare"), "nothing rare at level 1: %s" % [(seen[1] as Dictionary).keys()])
	assert_false((seen[1] as Dictionary).has("legendary"))
	assert_true((seen[1] as Dictionary).has("uncommon"), "uncommon magic from the start")
	assert_true((seen[5] as Dictionary).has("rare") and not (seen[5] as Dictionary).has("very_rare"), "rare from level 5")
	assert_true((seen[9] as Dictionary).has("very_rare") and not (seen[9] as Dictionary).has("legendary"), "very rare from 9")
	assert_true((seen[10] as Dictionary).has("legendary"), "legendary from 10")
	# The levels come from data/treasure/levels.json.
	assert_eq(Trade.magic_level("rare"), 5)
	assert_eq(Trade.magic_level("uncommon"), 1)


func test_magic_is_priced_by_the_guide_whatever_the_markup() -> void:
	Compendium.shared().tables["npcs"]["test_magic_seller"] = {"id": "test_magic_seller", "name": "Test Seller",
		"shop": {"sells": [{"id": "rope", "qty": -1}], "magic": ["bag_of_holding", "potion_of_climbing", "ammunition_plus_1",
			"flame_tongue", "javelin_of_lightning", "ring_of_protection"], "markup": 3.0}}
	var st := _party(1)
	var wares := st.shop_wares("test_magic_seller")
	var by := {}
	for w in wares:
		by[str(w["id"])] = w
	assert_eq(float((by["rope"] as Dictionary)["price"]), Trade.whole_gp(1.0 * 3.0), "mundane goods at the markup")
	assert_eq(float((by["bag_of_holding"] as Dictionary)["price"]), 4000.0, "the guide's Bag of Holding, not three times it")
	assert_eq(int((by["bag_of_holding"] as Dictionary)["qty"]), 1, "one of anything lasting")
	assert_eq(int((by["potion_of_climbing"] as Dictionary)["qty"]), 3, "three of a potion")
	assert_false(by.has("ring_of_protection"), "a rare ring waits for level 5")
	assert_true(by.has("javelin_of_lightning__javelin"), "an item with one base is sold as that item")
	assert_true(by.has("ammunition_plus_1"), "ammunition with a choice of arrows, bolts, bullets and needles")
	assert_eq(str((by["ammunition_plus_1"] as Dictionary)["bases"][0]["name"]).contains("×20"), true, "by the bundle")
	assert_false(by.has("flame_tongue"), "rare")
	var names: Array[String] = []
	for w in wares:
		names.append(str(w["id"]))
	assert_true(names.find("rope") < names.find("bag_of_holding"), "the merchant's own goods first: %s" % str(names))


func test_a_made_to_order_ware_sells_the_base_the_party_picks() -> void:
	Compendium.shared().tables["npcs"]["test_magic_seller"] = {"id": "test_magic_seller", "name": "Test Seller",
		"shop": {"sells": [], "magic": ["flame_tongue"]}}
	var st := _party(5)
	var ch := st.party[0]
	var w := st.shop_wares("test_magic_seller")[0]
	assert_eq(str(w["id"]), "flame_tongue")
	var bases := (w["bases"] as Array).map(func(o: Dictionary) -> String: return str(o["id"]))
	assert_true("flame_tongue__rapier" in bases and "flame_tongue__longsword" in bases, str(bases))
	assert_false("flame_tongue__longbow" in bases, "melee weapons only")
	var cheapest := 1e9
	for o: Dictionary in w["bases"]:
		cheapest = minf(cheapest, float(o["price"]))
	assert_eq(float(w["price"]), cheapest, "the row shows the lowest price")
	var before := st.gold
	assert_eq(st.shop_buy("test_magic_seller", "flame_tongue__rapier", ch), "")
	assert_eq(st.gold, before - 5025.0, "the guide's 5,000 gp and the rapier's 25")
	assert_true(ch.inventory.any(func(e: Dictionary) -> bool: return str(e["id"]) == "flame_tongue__rapier"), "a Flame Tongue Rapier")
	assert_true(st.shop_wares("test_magic_seller").is_empty(), "the one Flame Tongue is gone, whichever blade it was")
	assert_eq(st.shop_buy("test_magic_seller", "flame_tongue__longsword", ch), "Not for sale")


func test_the_merchants_open_as_the_story_lets_them() -> void:
	var st := _party(11)
	assert_false(st.shop_wares("urwin_martikov").any(func(w: Dictionary) -> bool: return str(w["id"]) == "feather_token_bird"),
		"the Keepers' feathers wait for the Keepers")
	st.set_flag("keepers_allied")
	assert_true(st.shop_wares("urwin_martikov").any(func(w: Dictionary) -> bool: return str(w["id"]) == "feather_token_bird"))
	var xaver := Compendium.shared().get_entry("npcs", "library_xaver")["shop"] as Dictionary
	assert_true(StoryConditions.check(str(xaver["closed"]), st), "Xaver keeps to his bookcase while the Index lives")
	assert_true(bool(xaver.get("hide_closed", false)))
	st.set_flag("index_destroyed")
	assert_false(StoryConditions.check(str(xaver["closed"]), st), "Khazan's stores once it's gone")
	assert_eq(st.shop_offer("library_xaver", "rope"), -1.0, "he has no use for coin's worth of rope")
	assert_eq(str(Compendium.shared().display_name("npcs", "vallaki_cloth_merchant")), "Master Costel")
	var costel := st.shop_wares("vallaki_cloth_merchant").map(func(w: Dictionary) -> String: return str(w["id"]))
	assert_true("cloak_of_elvenkind" in costel and "robe_of_the_archmagi" in costel, "Costel's cloaks and robes")


## A merchant who buys magic items pays no more than the guide's price for the magic stock, so the party can't buy low
## and sell high (at the best terms anywhere: friendly and haggled).
func test_nothing_bought_sells_back_for_more() -> void:
	var st := _party(11)
	st.set_flag("keepers_allied")
	for npc: String in _shops():
		st.attitudes[npc] = "friendly"
		var h := (_shops()[npc] as Dictionary).get("haggle", {}) as Dictionary
		st.set_flag(str(h.get("won", "_haggle_won/" + npc)), true)
	for seller: String in _shops():
		var magic := (_shops()[seller] as Dictionary).get("magic", []) as Array
		for w in st.shop_wares(seller):
			if not _item_of(str(w["id"])) in magic and not str(w["id"]) in magic:
				continue
			var picks: Array = w["bases"] if w.has("bases") else [w]
			for p: Variant in picks:
				for buyer: String in ["vadoma", "rictavio", "urwin_martikov", "stanimir", "father_lucian", "kasha_varo"]:
					var offer := st.shop_offer(buyer, str((p as Dictionary)["id"]))
					assert_true(offer <= float((p as Dictionary)["price"]), "%s sells %s for %s gp, %s pays %s" % [seller,
						(p as Dictionary)["id"], (p as Dictionary)["price"], buyer, offer])
