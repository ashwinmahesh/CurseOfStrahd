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
	var groups: Array = ((Compendium.shared().get_entry("npcs", "vadoma")["shop"] as Dictionary)["rotating"] as Dictionary)["groups"]
	for g: Variant in groups:
		for id: Variant in (g as Dictionary)["pool"]:
			var data := Compendium.shared().item_data(str(id))
			assert_false(data.is_empty(), "%s is a real item" % id)
			assert_true(float(data.get("cost_gp", 0)) > 0.0, "%s has a price" % id)
	var arms: Array = (groups[1] as Dictionary)["pool"]
	var scrolls: Array = (groups[2] as Dictionary)["pool"]
	var seen := {}
	for d in 12:
		var ids := _ids(st, "vadoma")
		assert_eq(ids.size(), 7, "a potion of healing, three curios, a weapon or armor, two scrolls: %s" % str(ids))
		assert_eq(ids.filter(func(i: String) -> bool: return i in arms).size(), 1, "one enchanted weapon or armor")
		assert_eq(ids.filter(func(i: String) -> bool: return i in scrolls).size(), 2, "two scrolls")
		for w in st.shop_wares("vadoma"):
			var cost := float(Compendium.shared().item_data(str(w["id"])).get("cost_gp", 0))
			assert_eq(float(w["price"]), snappedf(cost * 1.25, 0.01), "%s at the book's price and a quarter" % w["id"])
			seen[str(w["id"])] = true
		st.advance_minutes(24 * 60)
	assert_true(seen.size() >= 15, "four stretches, other stock: %d kinds" % seen.size())
	var plus := Compendium.shared().item_data("weapon_plus_1__longsword")
	assert_eq(str(plus.get("name", "")), "+1 Longsword")
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


func test_every_town_sells_weapons_armor_potions_and_scrolls() -> void:
	var st := _party()
	st.set_flag("krezk_gate_open")
	var weapons := ["club", "dagger", "longsword", "greatsword", "longbow", "light_crossbow", "rapier", "warhammer"]
	var armor := ["leather_armor", "chain_shirt", "breastplate", "chain_mail", "half_plate_armor", "plate_armor", "shield"]
	for town: Array in [["village_of_barovia", ["bildrath", "donavich"]], ["vallaki", ["gunther_arasek", "father_lucian", "kasimir_velikov"]],
			["krezk", ["dmitri_krezkov", "kasha_varo"]]]:
		var sold := {}
		var scrolls := 0
		for npc: String in town[1]:
			assert_eq(str(Compendium.shared().get_entry("npcs", npc).get("region", "")), str(town[0]), "%s lives in %s" % [npc, town[0]])
			for w in st.shop_wares(npc):
				sold[str(w["id"])] = true
				if str(w["id"]).begins_with("spell_scroll__"):
					scrolls += 1
					assert_true(float(w["price"]) > 0.0, "%s has a price" % w["id"])
		for id: String in weapons + armor + ["potion_of_healing", "arrow"]:
			assert_true(sold.has(id), "%s sells %s" % [town[0], id])
		assert_true(scrolls >= 10, "%s sells spell scrolls: %d" % [town[0], scrolls])
	assert_eq(_price(st, "gunther_arasek", "longsword"), 15.0, "Gunther at the PHB's price")
	assert_eq(_price(st, "gunther_arasek", "plate_armor"), 1500.0)
	assert_eq(_price(st, "bildrath", "plate_armor"), 15000.0, "Bildrath at ten times, as ever")
	assert_eq(_price(st, "kasimir_velikov", "spell_scroll__magic_missile"), 50.0, "a level 1 scroll is common")
	assert_eq(_price(st, "father_lucian", "spell_scroll__aid"), 200.0, "a level 2 scroll is uncommon")


func test_krezks_armory_opens_with_the_gate() -> void:
	var st := _party()
	var closed := str((Compendium.shared().get_entry("npcs", "dmitri_krezkov")["shop"] as Dictionary)["closed"])
	assert_true(StoryConditions.check(closed, st), "shut while Krezk keeps its gate shut")
	st.set_flag("krezk_gate_open")
	assert_false(StoryConditions.check(closed, st))
	for pair: Array in [["dmitri_krezkov", "krezk/dmitri:armory"], ["kasha_varo", "krezk/kasha:wares"],
			["donavich", "village_of_barovia/donavich:church_wares"], ["father_lucian", "vallaki/lucian:church_wares"],
			["kasimir_velikov", "vallaki/kasimir:scrolls"]]:
		assert_true(_opens_shop(st, str(pair[0]), str(pair[1])), "%s opens the shop" % pair[1])


func test_the_keepers_stores_open_to_their_allies() -> void:
	var st := _party()
	assert_false("potion_of_healing_superior" in _ids(st, "urwin_martikov"), "not before the Keepers are allies")
	st.set_flag("keepers_allied")
	var ids := _ids(st, "urwin_martikov")
	for id: String in ["potion_of_healing_superior", "spell_scroll__revivify", "spell_scroll__death_ward", "figurine_of_wondrous_power_silver_raven"]:
		assert_true(id in ids, "the Keepers sell %s" % id)
	assert_eq(_price(st, "urwin_martikov", "potion_of_healing_superior"), 2000.0, "at cost, though Urwin marks up his bread")
	assert_eq(_price(st, "urwin_martikov", "ration"), 0.75, "the inn's goods keep the inn's markup")
	assert_true(_opens_shop(st, "urwin_martikov", "vallaki/martikovs:keepers_stores"))


func test_van_richten_sells_his_arsenal_once_unmasked() -> void:
	var st := _party()
	var shop := Compendium.shared().get_entry("npcs", "rictavio")["shop"] as Dictionary
	assert_true(StoryConditions.check(str(shop["closed"]), st), "a showman has nothing to sell")
	assert_true(bool(shop["hide_closed"]), "and no Trade in his menu gives him away")
	st.set_flag("rictavio_unmasked")
	assert_false(StoryConditions.check(str(shop["closed"]), st))
	var fresh := _party()
	fresh.set_flag("van_richten_met_at_tower")
	assert_false(StoryConditions.check(str(shop["closed"]), fresh), "or once he's found at his tower")
	for w in st.shop_wares("rictavio"):
		assert_false(Compendium.shared().item_data(str(w["id"])).is_empty(), "%s is a real item" % w["id"])
	assert_eq(str(Compendium.shared().item_data("mace_of_disruption__mace").get("name", "")), "Mace of Disruption")
	assert_eq(_price(st, "rictavio", "spell_scroll__greater_restoration"), 2000.0, "a level 5 scroll is rare")
	assert_true(_opens_shop(st, "rictavio", "vallaki/rictavio:hunter_wares"))
	assert_true(_opens_shop(st, "rictavio", "van_richtens_tower/van_richten:arsenal"))


func test_the_orders_armory_at_half_price_once_godfrey_remembers() -> void:
	var st := _party()
	var shop := Compendium.shared().get_entry("npcs", "sir_godfrey_gwilym")["shop"] as Dictionary
	assert_true(StoryConditions.check(str(shop["closed"]), st))
	st.set_flag("godfrey_remembers")
	assert_false(StoryConditions.check(str(shop["closed"]), st))
	var cost := float(Compendium.shared().item_data("weapon_plus_2__longsword").get("cost_gp", 0))
	assert_eq(_price(st, "sir_godfrey_gwilym", "weapon_plus_2__longsword"), Trade.buy_price(st, "sir_godfrey_gwilym", cost * 0.5),
		"half the price (and his attitude's)")
	assert_eq(st.shop_offer("sir_godfrey_gwilym", "longsword"), -1.0, "the dead buy nothing")
	assert_true(_opens_shop(st, "sir_godfrey_gwilym", "argynvostholt/godfrey:armory"))
