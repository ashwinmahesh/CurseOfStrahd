extends TestCase
## The book's other merchants on the shop screen (F14): Vadoma, the Vistani trader whose curios change every few days;
## Arik's wine at the Blood of the Vine, scarce until the Wizard of Wines is saved; Davian Martikov's cellar once
## the wine flows; Henrik's coffins and woodwork once his shop is free of Strahd's spawn, the first coffin for nothing.


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 3))
	st.gold = 5000.0
	st.playthrough_seed = 7
	return st


func _ids(st: StoryState, npc: String) -> Array[String]:
	var out: Array[String] = []
	for w in st.shop_wares(npc):
		out.append(str(w["id"]))
	return out


func _price(st: StoryState, npc: String, id: String) -> float:
	for w in st.shop_wares(npc):
		if str(w["id"]) == id:
			return float(w["price"])
	return -1.0


func _opens_shop(st: StoryState, npc: String, ref: String) -> bool:
	var r := DialogueRunner.new(st, DiceRoller.new(1), null)
	r.npc_id = npc
	if not r.start(ref):
		return false
	for i in 10:
		var beat := r.next()
		if str(beat["kind"]) == "shop":
			return true
		if str(beat["kind"]) in ["end", "options"]:
			return false
	return false


func test_vadomas_curios_change_every_few_days() -> void:
	var st := _party()
	var pool: Array = ((Compendium.shared().get_entry("npcs", "vadoma")["shop"] as Dictionary)["rotating"] as Dictionary)["pool"]
	for id: Variant in pool:
		assert_false(Compendium.shared().item_data(str(id)).is_empty(), "%s is a real item" % id)
	var first := _ids(st, "vadoma")
	assert_eq(first.size(), 5, "a potion of healing and four curios: %s" % str(first))
	assert_true("potion_of_healing" in first)
	for w in st.shop_wares("vadoma"):
		var cost := float(Compendium.shared().item_data(str(w["id"])).get("cost_gp", 0))
		assert_eq(float(w["price"]), snappedf(cost * 1.25, 0.01), "%s at the book's price and a quarter" % w["id"])
	var seen := {}
	for d in 9:
		st.advance_minutes(24 * 60)
		for id in _ids(st, "vadoma"):
			seen[id] = true
	assert_true(seen.size() >= 9, "three more stretches, other curios: %d kinds" % seen.size())
	assert_eq(Trade.haggle_dc("vadoma"), 17)
	assert_true(_opens_shop(_party(), "vadoma", "vallaki/vadoma:start") == false, "first she talks (the menu)")
	assert_true(_opens_shop(_party(), "vadoma", "vallaki/vadoma:wares"))
	var enemy := _party()
	enemy.set_flag("tser_pool_brawl_won")
	var r := DialogueRunner.new(enemy, DiceRoller.new(1), null)
	r.npc_id = "vadoma"
	r.start("vallaki/vadoma:start")
	var kinds: Array[String] = []
	for i in 4:
		kinds.append(str(r.next()["kind"]))
	assert_true("end" in kinds and not "options" in kinds, "after Tser Pool she won't trade: %s" % str(kinds))


func test_arik_sells_his_last_bottles_until_the_wine_flows() -> void:
	var st := _party()
	assert_eq(_ids(st, "arik"), ["wine_purple_grapemash"] as Array[String])
	assert_eq(_price(st, "arik", "wine_purple_grapemash"), 1.0, "a gold piece a bottle, as his cup")
	assert_eq(st.shop_buy("arik", "wine_purple_grapemash", st.party[0]), "")
	assert_eq(st.shop_buy("arik", "wine_purple_grapemash", st.party[0]), "")
	assert_eq(_ids(st, "arik"), [] as Array[String], "the shortage: two bottles, then none")
	st.set_flag("winery_wine_flows")
	assert_eq(_ids(st, "arik"), ["wine_purple_grapemash", "wine_red_dragon_crush"] as Array[String], "the carts come again")
	assert_true(_opens_shop(st, "arik", "village_of_barovia/arik:bottles"))


func test_davians_cellar_opens_when_the_wine_flows() -> void:
	var st := _party()
	var closed := str((Compendium.shared().get_entry("npcs", "davian_martikov")["shop"] as Dictionary)["closed"])
	assert_true(StoryConditions.check(closed, st), "closed while the druids hold the winery")
	st.set_flag("winery_wine_flows")
	assert_false(StoryConditions.check(closed, st))
	assert_eq(_price(st, "davian_martikov", "wine_champagne_du_le_stomp"), 10.0, "at cost, from the vintner")
	assert_true(_opens_shop(st, "davian_martikov", "wizard_of_wines/davian:buy_wine"))


func test_henrik_gives_one_coffin_then_sells_them() -> void:
	var st := _party()
	var closed := str((Compendium.shared().get_entry("npcs", "henrik")["shop"] as Dictionary)["closed"])
	assert_true(StoryConditions.check(closed, st), "closed while the spawn sleep in his storeroom")
	st.set_flag("coffin_spawn_destroyed")
	assert_false(StoryConditions.check(closed, st))
	assert_eq(_price(st, "henrik", "coffin"), 0.0, "the first one is a gift")
	assert_eq(st.shop_buy("henrik", "coffin", st.party[0]), "")
	assert_eq(st.gold, 5000.0)
	assert_true(bool(st.get_flag("henrik_free_coffin")))
	assert_eq(_price(st, "henrik", "coffin"), 10.0, "then they cost")
	assert_true(_opens_shop(st, "henrik", "vallaki/henrik:freed_wares"))
