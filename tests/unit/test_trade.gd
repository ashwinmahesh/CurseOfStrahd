extends TestCase
## Trading (U11's trading half, story/trade.gd): prices that follow a merchant's attitude, the Persuasion haggle and
## its limits, price changes while a flag holds (Bildrath's surcharge), wares the story remembers, and stock that
## changes with the days (the Vistani trader). Bildrath sells from the shop screen now.


func before_each() -> void:
	var npcs := Compendium.shared().tables["npcs"] as Dictionary
	npcs["test_trader"] = {"id": "test_trader", "name": "Test Trader", "summary": "",
		"shop": {"sells": [{"id": "rope", "qty": -1}, {"id": "potion_of_healing", "qty": 1, "price": 100.0,
			"if": "not flag.test_potion_sold", "sets": "test_potion_sold"}, {"id": "dream_pastry", "qty": -1, "counts": "test_pastries"}],
			"buys": ["weapon"], "markup": 2.0, "sell_rate": 0.5, "haggle": {"dc": 1},
			"price_flags": [{"if": "flag.test_rude", "buy": 1.1, "min_price": 50}]}}
	npcs["test_stubborn"] = {"id": "test_stubborn", "name": "Test Stubborn", "summary": "",
		"shop": {"sells": [{"id": "rope", "qty": -1}], "haggle": {"dc": 30, "won": "test_won", "lost": "test_lost"}}}
	npcs["test_wanderer"] = {"id": "test_wanderer", "name": "Test Wanderer", "summary": "",
		"shop": {"sells": [], "rotating": {"pool": ["rope", "torch", "oil", "candle", "shovel", "crowbar"], "count": 3, "days": 3}}}


func after_each() -> void:
	for id: String in ["test_trader", "test_stubborn", "test_wanderer"]:
		(Compendium.shared().tables["npcs"] as Dictionary).erase(id)


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	st.gold = 1000.0
	return st


func _price(st: StoryState, npc: String, id: String) -> float:
	for w in st.shop_wares(npc):
		if str(w["id"]) == id:
			return float(w["price"])
	return -1.0


func test_prices_follow_the_merchants_attitude() -> void:
	var st := _party()
	var rope := float(Compendium.shared().item_data("rope")["cost_gp"]) * 2.0
	var sword := str(st.party[0].equipped("main_hand").get("id", "greatsword"))
	var offer := st.shop_offer("test_trader", sword)
	assert_eq(_price(st, "test_trader", "rope"), rope, "indifferent: the shop's own price")
	st.attitudes["test_trader"] = "friendly"
	assert_eq(_price(st, "test_trader", "rope"), snappedf(rope * 0.9, 0.01), "friendly: 10% off")
	assert_eq(st.shop_offer("test_trader", sword), snappedf(offer * 1.1, 0.01), "friendly: 10% more for what they buy")
	assert_eq(_price(st, "test_trader", "potion_of_healing"), 90.0, "a set price follows attitude too")
	st.attitudes["test_trader"] = "hostile"
	assert_eq(_price(st, "test_trader", "rope"), snappedf(rope * 1.25, 0.01), "hostile: a quarter more")
	assert_eq(st.shop_offer("test_trader", sword), snappedf(offer * 0.75, 0.01), "hostile: a quarter less")
	assert_eq(st.shop_buy("test_trader", "rope", st.party[0]), "")
	assert_eq(st.gold, 1000.0 - snappedf(rope * 1.25, 0.01), "the purse pays the hostile price")
	assert_ne(Trade.why_no_haggle(st, "test_trader"), "", "a hostile merchant won't haggle")


func test_a_won_haggle_lasts_and_survives_a_save() -> void:
	var st := _party()
	assert_eq(Trade.haggle_state(st, "test_trader"), "")
	var test := Trade.haggle(st, "test_trader", st.party[0], DiceRoller.new(7))
	assert_true(test != null and test.success, "DC 1 can't be failed")
	assert_eq(test.target, 1)
	assert_eq(Trade.haggle_state(st, "test_trader"), "won")
	assert_eq(_price(st, "test_trader", "potion_of_healing"), 90.0, "good customers: 10% off")
	assert_ne(Trade.why_no_haggle(st, "test_trader"), "", "nothing more to haggle for")
	assert_true(Trade.haggle(st, "test_trader", st.party[0], DiceRoller.new(8)) == null)
	st.attitudes["test_trader"] = "friendly"
	assert_eq(_price(st, "test_trader", "potion_of_healing"), 81.0, "friendly and haggled multiply")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(Trade.haggle_state(copy, "test_trader"), "won", "the haggle survives a save")


func test_a_lost_haggle_is_final() -> void:
	var st := _party()
	(Compendium.shared().tables["npcs"]["test_trader"]["shop"]["haggle"] as Dictionary)["dc"] = 30
	var test := Trade.haggle(st, "test_trader", st.party[0], DiceRoller.new(3))
	assert_true(test != null and not test.success, "DC 30 can't be met at level 1")
	assert_eq(Trade.haggle_state(st, "test_trader"), "lost")
	assert_ne(Trade.why_no_haggle(st, "test_trader"), "")
	st.advance_minutes(3 * 24 * 60)
	assert_eq(Trade.haggle_state(st, "test_trader"), "lost", "days later, still no")
	assert_true(Trade.haggle(st, "test_trader", st.party[0], DiceRoller.new(4)) == null, "no second try")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(Trade.haggle_state(copy, "test_trader"), "lost", "and after a save")
	assert_eq(Trade.haggle(st, "test_stubborn", st.party[0], DiceRoller.new(3)).success, false)
	assert_true(bool(st.get_flag("test_lost")), "the shop's own flag records it")
	st.advance_minutes(24 * 60)
	assert_eq(Trade.haggle_state(st, "test_stubborn"), "lost", "a shop with a lost flag never haggles again")
	st.set_flag("test_won")
	assert_eq(Trade.haggle_state(st, "test_stubborn"), "won", "its won flag (set by dialogue) gives the discount")


func test_price_flags_wares_the_story_remembers() -> void:
	var st := _party()
	var rope := _price(st, "test_trader", "rope")
	st.set_flag("test_rude")
	assert_eq(_price(st, "test_trader", "potion_of_healing"), 110.0, "the surcharge on the dear things")
	assert_eq(_price(st, "test_trader", "rope"), rope, "cheap things as posted")
	assert_eq(st.shop_buy("test_trader", "dream_pastry", st.party[0]), "")
	assert_eq(st.shop_buy("test_trader", "dream_pastry", st.party[0]), "")
	assert_eq(int(st.get_flag("test_pastries", 0)), 2, "each piece bought counts")
	assert_eq(st.shop_buy("test_trader", "potion_of_healing", st.party[0]), "")
	assert_true(bool(st.get_flag("test_potion_sold")), "buying it sets its flag")
	assert_eq(_price(st, "test_trader", "potion_of_healing"), -1.0, "and it's gone")
	var fresh := _party()
	fresh.set_flag("test_potion_sold")
	assert_eq(_price(fresh, "test_trader", "potion_of_healing"), -1.0, "sold in dialogue: not on the shelf either")


func test_rotating_stock_changes_with_the_days() -> void:
	var st := _party()
	st.playthrough_seed = 41
	var first := st.shop_wares("test_wanderer")
	assert_eq(first.size(), 3, "three things from the pool")
	var ids: Array[String] = []
	for w in first:
		ids.append(str(w["id"]))
		assert_eq(int(w["qty"]), 1, "one of each")
	assert_eq(str(st.shop_wares("test_wanderer").map(func(w: Dictionary) -> String: return str(w["id"]))), str(ids),
		"the same picks while the stretch lasts")
	assert_eq(st.shop_buy("test_wanderer", ids[0], st.party[0]), "")
	assert_eq(st.shop_wares("test_wanderer").size(), 2, "bought: gone for this stretch")
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(copy.shop_wares("test_wanderer").size(), 2, "and after a save")
	var seen := {}
	for d in 12:
		st.advance_minutes(24 * 60)
		for w in st.shop_wares("test_wanderer"):
			seen[str(w["id"])] = true
	assert_true(seen.size() > 3, "later stretches bring other things: %s" % str(seen.keys()))
	assert_eq(Trade.stretch_of(st, "test_wanderer"), 4)


func test_bildrath_sells_from_the_shop_screen() -> void:
	var st := _party()
	assert_eq(_price(st, "bildrath", "rope"), float(Compendium.shared().item_data("rope")["cost_gp"]) * 10.0, "ten times the PHB")
	assert_eq(_price(st, "bildrath", "potion_of_healing"), 500.0)
	assert_eq(st.shop_offer("bildrath", "longsword"), snappedf(float(Compendium.shared().item_data("longsword")["cost_gp"]) * 0.1, 0.01),
		"a tenth back")
	st.set_flag("bildrath_discount")
	assert_eq(_price(st, "bildrath", "potion_of_healing"), 450.0, "the dialogue's haggle: nine times")
	assert_eq(Trade.haggle_state(st, "bildrath"), "won")
	st.flags.erase("bildrath_discount")
	st.set_flag("bildrath_surcharge")
	assert_eq(_price(st, "bildrath", "potion_of_healing"), 550.0, "the rude price on the dear things")
	assert_eq(_price(st, "bildrath", "healers_kit"), 55.0)
	assert_eq(_price(st, "bildrath", "rope"), float(Compendium.shared().item_data("rope")["cost_gp"]) * 10.0, "rope as posted")
	st.set_flag("bildrath_haggle_failed")
	assert_eq(Trade.haggle_state(st, "bildrath"), "lost")
	var r := DialogueRunner.new(st, DiceRoller.new(1), null)
	r.npc_id = "bildrath"
	assert_true(r.start("village_of_barovia/bildrath:buy"))
	var kinds: Array[String] = []
	for i in 6:
		var beat := r.next()
		kinds.append(str(beat["kind"]))
		if str(beat["kind"]) == "shop":
			break
	assert_true("shop" in kinds, "his wares open the shop screen: %s" % str(kinds))
