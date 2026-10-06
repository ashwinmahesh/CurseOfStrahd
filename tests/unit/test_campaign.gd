extends TestCase
## The campaign spine (ADR 0010): the Tarokka reading (seeded, five distinct cards, conditions, verses in dialogue,
## journal hints), guests joining and leaving, shops buying and selling with stock, and all of it surviving a save.

var _saved_tarokka := {}


func before_each() -> void:
	var c := Compendium.shared()
	_saved_tarokka = (c.tables.get("tarokka", {}) as Dictionary).duplicate()
	var cards: Array = []
	var outcomes := {"id": "outcomes", "tome": {}, "symbol": {}, "sword": {}, "ally": {}, "enemy": {}}
	for i in 14:
		var id := "high_%d" % i
		cards.append({"id": id, "name": "High %d" % i, "deck": "high", "summary": ""})
		(outcomes["ally"] as Dictionary)[id] = {"npc": "ismark", "region": "region_%d" % i, "verse": "Ally verse %d." % i, "hint": "Ally hint %d" % i}
		(outcomes["enemy"] as Dictionary)[id] = {"room": "castle_%d" % i, "verse": "Enemy verse %d." % i, "hint": "Enemy hint %d" % i}
	for suit: String in ["swords", "stars", "coins", "glyphs"]:
		for v in range(1, 11):
			var id := "%s_%d" % [suit, v]
			cards.append({"id": id, "name": "%s %d" % [suit.capitalize(), v], "deck": "common", "suit": suit, "value": v, "summary": ""})
			for slot: String in ["tome", "symbol", "sword"]:
				(outcomes[slot] as Dictionary)[id] = {"place": "place_%s" % id, "region": "vallaki" if suit == "coins" else "elsewhere",
					"verse": "%s verse for %s." % [slot, id], "hint": "%s hint for %s" % [slot, id]}
	c.tables["tarokka"] = {"cards": {"id": "cards", "cards": cards}, "outcomes": outcomes}
	c.tables["npcs"]["test_merchant"] = {"id": "test_merchant", "name": "Test Merchant", "summary": "",
		"shop": {"sells": [{"id": "rope", "qty": -1}, {"id": "potion_of_healing", "qty": 1, "price": 30}], "buys": ["weapon"],
			"markup": 2.0, "sell_rate": 0.5}}


func after_each() -> void:
	Compendium.shared().tables["tarokka"] = _saved_tarokka
	Compendium.shared().tables["npcs"].erase("test_merchant")


func _party() -> StoryState:
	var st := StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	st.party.append(TestChars.pregen("silvain_aster", 1))
	return st


func test_a_seed_always_draws_the_same_reading_and_seeds_differ() -> void:
	var a := Tarokka.draw(11)
	var b := Tarokka.draw(11)
	assert_eq(str(a), str(b), "same seed, same reading")
	var cards := {}
	for slot in Tarokka.SLOTS:
		cards[a[slot]] = true
	assert_eq(cards.size(), 5, "five different cards")
	for slot in Tarokka.TREASURES:
		assert_true(str(a[slot]).contains("_") and not str(a[slot]).begins_with("high"), "treasures come from the common deck")
	assert_true(str(a["ally"]).begins_with("high") and str(a["enemy"]).begins_with("high"))
	var different := 0
	for s in range(1, 20):
		if str(Tarokka.draw(s)) != str(a):
			different += 1
	assert_eq(different, 18, "other seeds give other readings")


func test_conditions_hints_and_the_reading_in_dialogue() -> void:
	var st := _party()
	st.playthrough_seed = 5
	assert_false(StoryConditions.check("tarokka.drawn", st))
	var f := DialogueFile.parse("""
~ eva
madam_eva: Sit.
tarokka draw
tarokka read sword
tarokka read ally
-> END
""", "test/eva")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/eva:eva")
	assert_eq(str(r.next()["kind"]), "line")
	var notice := r.next()
	assert_eq(str(notice["kind"]), "notice")
	assert_eq(str(notice["slot"]), "sword")
	var verse := r.next()
	assert_eq(str(verse["kind"]), "line")
	assert_eq(str(verse["text"]), "sword verse for %s." % st.tarokka["sword"])
	assert_true(StoryConditions.check("tarokka.drawn", st))
	assert_true(StoryConditions.check("tarokka.sword == %s" % st.tarokka["sword"], st))
	var region := "vallaki" if str(st.tarokka["sword"]).begins_with("coins") else "elsewhere"
	assert_true(StoryConditions.check("tarokka.sword.region == %s" % region, st))
	assert_true(StoryConditions.check("tarokka.ally.npc == ismark", st))
	assert_eq(Tarokka.fill("Seek {tarokka.sword.hint}.", st), "Seek sword hint for %s." % st.tarokka["sword"])
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	for slot in Tarokka.SLOTS:
		assert_eq(str(copy.tarokka[slot]), str(st.tarokka[slot]), "the reading is saved")
	assert_eq(copy.playthrough_seed, 5)


func test_guests_join_leave_and_survive_a_save() -> void:
	var st := _party()
	var f := DialogueFile.parse("~ go\njoin ireena\n-> END\n~ stay\nleave ireena\n-> END\n", "test/guests")
	DialogueFile.register(f)
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	r.start("test/guests:go")
	assert_eq(str(r.next()["kind"]), "notice")
	assert_true(StoryConditions.check("guest:ireena", st))
	assert_eq(st.guests.size(), 1)
	st.guests[0].hp = 3
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(copy.guest_ids, ["ireena"] as Array[String])
	assert_eq(copy.guests[0].hp, 3)
	assert_eq(copy.guests[0].name, "Ireena Kolyana")
	r.start("test/guests:stay")
	r.next()
	assert_false(StoryConditions.check("guest:ireena", st))


func test_shops_buy_sell_and_keep_their_stock() -> void:
	var st := _party()
	st.gold = 40.0
	var ilse := st.party[0]
	var wares := st.shop_wares("test_merchant")
	assert_eq(wares.size(), 2)
	assert_eq(float(wares[0]["price"]), float(Compendium.shared().item_data("rope")["cost_gp"]) * 2.0, "markup")
	assert_eq(st.shop_buy("test_merchant", "potion_of_healing", ilse), "")
	assert_eq(st.gold, 10.0)
	assert_eq(st.shop_wares("test_merchant").size(), 1, "the only potion is gone")
	assert_eq(st.shop_buy("test_merchant", "potion_of_healing", ilse), "Not for sale")
	assert_eq(st.shop_offer("test_merchant", "ration"), -1.0, "only buys weapons")
	var sword := str(ilse.equipped("main_hand").get("id", "greatsword"))
	var offer := st.shop_offer("test_merchant", sword)
	assert_true(offer > 0.0)
	assert_eq(st.shop_sell("test_merchant", sword, ilse), "")
	assert_eq(st.gold, 10.0 + offer)
	var copy := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(copy.shop_wares("test_merchant").size(), 1, "stock survives a save")


func test_guest_interjections_time_and_options() -> void:
	var st := _party()
	var f := DialogueFile.parse("~ road\ninterject guest:ireena: I know this place.\ntime +45\nif option:respec\nset can_respec\nendif\n-> END\n", "test/road")
	assert_true(f.errors.is_empty(), str(f.errors))
	DialogueFile.register(f)
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	var start := st.total_minutes()
	r.start("test/road:road")
	assert_eq(str(r.next()["kind"]), "end", "no Ireena, no line")
	assert_eq(st.total_minutes() - start, 45)
	assert_true(bool(st.get_flag("can_respec")), "respec is on by default")
	st.add_guest("ireena")
	r.start("test/road:road")
	var b := r.next()
	assert_eq(str(b["speaker_id"]), "ireena")
	assert_eq(str(b["text"]), "I know this place.")
