extends TestCase
## The Phase 6 exit (plan §10, ADR 0014): the campaign can be completed from start to finish with at least three
## distinct endings reachable. Here: every Tarokka place inside Castle Ravenloft gives its treasure, Pidlwick II (the
## castle's ally) can join, every enemy room holds the final battle the reading sends Strahd to, and each of three
## endings is reached by play, ending on the ending screen. The regions before the castle are covered by the Phase 3,
## 4 and 5 exit tests; the campaign run below chains the castle onto them. Slow: `make test ONLY=phase6_exit`.

## Story state a castle spot or scene expects before it can happen, by place or room (from the part docs'
## critical paths: opening the great nest rouses the ravens unless they were fed first).
const SETUP := {
	"castle_ravenloft_ravens_roost": {"roost_ravens_calm": true},
}

var root: Node


func before_each() -> void:
	Engine.time_scale = 8.0


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false   # a place's cutscene pauses the game; the next playthrough must not start paused
	if root != null:
		root.queue_free()
		root = null


func _start(location: String, level: int = 11) -> void:
	if root != null:
		root.queue_free()
		root = null
		await get_tree().process_frame
	GameState.reset()
	var st := GameState.story
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 5000.0
	st.minute_of_day = 10 * 60
	st.location = location
	st.playthrough_seed = 7
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Treasure places inside the castle: place -> region.
static func castle_places() -> Dictionary:
	var out := {}
	for slot in Tarokka.TREASURES:
		var table := Compendium.shared().get_entry("tarokka", "outcomes").get(slot, {}) as Dictionary
		for card: String in table:
			var o := table[card] as Dictionary
			if str(o["region"]) == "castle_ravenloft":
				out[str(o["place"])] = str(o["region"])
	return out


## The location holding a place's spot, and the spot: {location, spot}, or {}.
static func spot_of(place: String) -> Dictionary:
	var locs := Compendium.shared().table("locations")
	for id: String in locs:
		var spots := Tarokka.spots(locs[id] as Dictionary)
		if spots.has(place):
			return {"location": id, "spot": spots[place]}
	return {}


## A reading that puts the Tome at `place` (the other cards anywhere else).
static func reading_with_tome_at(place: String) -> Dictionary:
	var table := Compendium.shared().get_entry("tarokka", "outcomes").get("tome", {}) as Dictionary
	for card: String in table:
		if str((table[card] as Dictionary)["place"]) == place:
			return {"tome": card, "symbol": "", "sword": "", "ally": "", "enemy": ""}
	return {}


func _apply_setup(key: String) -> void:
	for f: String in (SETUP.get(key, {}) as Dictionary):
		GameState.story.set_flag(f, SETUP[key][f])


func test_every_treasure_place_in_the_castle_gives_its_treasure() -> void:
	var places := castle_places()
	assert_eq(places.size(), 15, "the castle holds 15 of the 40 common cards' places")
	var failures: Array[String] = []
	var by_location := {}
	for place: String in places:
		var s := spot_of(place)
		if s.is_empty():
			failures.append("%s: no treasure spot in any location" % place)
			continue
		if not by_location.has(s["location"]):
			by_location[s["location"]] = []
		(by_location[s["location"]] as Array).append(place)
	for loc: String in by_location:
		await _start(loc)
		for place: String in by_location[loc]:
			var why := await _obtain(loc, place)
			if why != "":
				failures.append("%s at %s: %s" % [place, loc, why])
	for f in failures:
		print("    ", f)
	assert_true(failures.is_empty(), "%d of %d castle treasure places fail (listed above)" % [failures.size(), places.size()])


## Plays one spot with the Tome hidden there. "" when the Tome reached the party, else why not.
func _obtain(loc: String, place: String) -> String:
	var st := GameState.story
	st.tarokka = reading_with_tome_at(place)
	st.flags.erase("treasure_found_tome")
	_apply_setup(place)
	var spot := spot_of(place)["spot"] as Dictionary
	var v := _view()
	var got: Array = []
	var catch := func(_id: String, items: Array, _gold: float) -> void: got.append_array(items)
	v.loot_opened.connect(catch)
	if spot.has("container"):
		var spec := {}
		for ct: Variant in v.loc.get("containers", []):
			if str((ct as Dictionary)["id"]) == str(spot["container"]):
				spec = ct
		(st.loc_state(loc)["doors"] as Dictionary)[str(spot["container"])] = "unlocked"
		(st.loc_state(loc)["looted"] as Dictionary).erase(str(spot["container"]))
		v._use_container(spec)
	elif spot.has("encounter"):
		var enc := {}
		for e: Variant in v.loc.get("encounters", []):
			if str((e as Dictionary)["id"]) == str(spot["encounter"]):
				enc = e
		v._spoils(str(spot["encounter"]), enc)
	elif spot.has("dialogue"):
		var bot := DialoguePathBot.new()
		var goal := func(s: Dictionary) -> bool: return str(s.get("t", "")) == "tarokka_give" and str(s.get("place", "")) == place
		var done := func() -> bool: return bool(st.get_flag("treasure_found_tome", false))
		if not bot.play(st, str(spot["dialogue"]), goal, done):
			v.loot_opened.disconnect(catch)
			return "the conversation never gives it (%s)" % " / ".join(bot.trace.slice(maxi(0, bot.trace.size() - 6)))
	await get_tree().process_frame
	await get_tree().process_frame
	v.loot_opened.disconnect(catch)
	if spot.has("dialogue"):
		return "" if st.party_has_item("tome_of_strahd") else "the flag is set but nobody holds the Tome"
	for it: Variant in got:
		if str((it as Dictionary)["id"]) == "tome_of_strahd":
			return ""
	return "the %s didn't yield the Tome" % ("chest" if spot.has("container") else "fight")


func test_pidlwick_ii_can_join() -> void:
	var allies := Compendium.shared().get_entry("tarokka", "outcomes").get("ally", {}) as Dictionary
	var card := ""
	for c: String in allies:
		if str((allies[c] as Dictionary).get("npc", "")) == "pidlwick_ii":
			card = c
	assert_ne(card, "", "a high card names Pidlwick II")
	var bot := DialoguePathBot.new()
	var goal := func(s: Dictionary) -> bool: return str(s.get("t", "")) == "join" and str(s.get("npc", "")) == "pidlwick_ii"
	var starts: Array[Dictionary] = []
	var locs := Compendium.shared().table("locations")
	for id: String in locs:
		for k: String in ["npcs", "props"]:
			for e: Variant in (locs[id] as Dictionary).get(k, []):
				var ref := str((e as Dictionary).get("dialogue", ""))
				if ref != "" and ref.contains(":") and bot.reaches(ref, goal):
					starts.append({"location": id, "dialogue": ref})
	assert_false(starts.is_empty(), "some conversation in the castle reaches `join pidlwick_ii`")
	var joined := false
	for ref: Dictionary in starts:
		await _start(str(ref["location"]))
		var st := GameState.story
		st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": card, "enemy": ""}
		var done := func() -> bool: return "pidlwick_ii" in st.guest_ids
		if DialoguePathBot.new().play(st, str(ref["dialogue"]), goal, done):
			joined = true
			break
	assert_true(joined, "Pidlwick II joins the party")


# --- The final battle: the reading's enemy room holds it --------------------------------------------------------------

## Every final battle encounter: room -> {location, id, trigger}.
static func final_battles() -> Dictionary:
	var out := {}
	var locs := Compendium.shared().table("locations")
	for id: String in locs:
		for e: Variant in (locs[id] as Dictionary).get("encounters", []):
			var spec := e as Dictionary
			if str(spec.get("final_battle", "")) != "":
				out[str(spec["final_battle"])] = {"location": id, "id": str(spec["id"]), "trigger": str(spec["trigger"])}
	return out


## The high cards and the room each sends Strahd to: card -> room.
static func enemy_cards() -> Dictionary:
	var out := {}
	var table := Compendium.shared().get_entry("tarokka", "outcomes").get("enemy", {}) as Dictionary
	for card: String in table:
		out[card] = str((table[card] as Dictionary)["room"])
	return out


## Sets the reading's enemy card and Madam Eva's foretelling; the roaming card gets its seed's room.
func _foretell(card: String) -> void:
	var st := GameState.story
	st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": card}
	if card == "mists":
		st.tarokka["enemy_roam"] = Tarokka.roam_pick(st.playthrough_seed)
	st.set_quest_stage("strahds_lair", "foretold")


func _bot(prefer: Array[String], avoid: Array[String] = []) -> StoryBot:
	var bot := StoryBot.new(self, root)
	bot.prefer.assign(prefer)
	bot.avoid.assign(avoid)
	return bot


func _strahd_in_fight() -> bool:
	var v := _view()
	if v == null or not v.in_combat or v.combat_view == null:
		return false
	for c in v.combat_view.e.combatants:
		if c.creature is Monster and str((c.creature as Monster).data.get("id", "")) == "strahd_von_zarovich":
			return true
	return false


func test_every_enemy_room_holds_the_final_battle() -> void:
	var finals := final_battles()
	var cards := enemy_cards()
	var failures: Array[String] = []
	for card: String in cards:
		var room := str(cards[card])
		if card == "mists":
			room = Tarokka.roam_pick(7)
		if not finals.has(room):
			failures.append("%s (%s): no final battle encounter" % [card, room])
			continue
		var fb := finals[room] as Dictionary
		await _start(str(fb["location"]))
		_foretell(card)
		var v := _view()
		if not v._trigger_encounter(str(fb["trigger"])):
			failures.append("%s: entering %s doesn't start the parley or the fight" % [card, room])
			continue
		var bot := _bot(["We came to end you."])
		for i in 60:
			if root.get("dialogue") != null or v.in_combat:
				break
			await bot.frames(1)
		if root.get("dialogue") != null:
			await bot.converse()
		for i in 60:
			if v.in_combat:
				break
			await bot.frames(1)
		if not _strahd_in_fight():
			failures.append("%s: after the parley there is no fight with Strahd in %s" % [card, room])
	for f in failures:
		print("    ", f)
	assert_true(failures.is_empty(), "%d of %d enemy cards fail (listed above)" % [failures.size(), cards.size()])


func test_strahd_waits_only_in_the_reading_room() -> void:
	var finals := final_battles()
	var study := finals["castle_ravenloft_study"] as Dictionary
	await _start(str(study["location"]))
	_foretell("beast")   # the audience hall, in the same wing
	assert_false(_view()._trigger_encounter(str(study["trigger"])), "no final battle in the study when he waits in the audience hall")
	GameState.story.set_quest_stage("strahds_lair", "")
	_foretell("seer")
	GameState.story.flags["strahd_destroyed"] = true
	assert_false(_view()._trigger_encounter(str(study["trigger"])), "none once he is destroyed")


# --- Three endings, reached by play ------------------------------------------------------------------------------------

## Starts in the overlook with Strahd waiting there, triggers the final battle and answers the parley with `answer`.
func _parley(answer: String, with_ireena: bool) -> StoryBot:
	var fb := final_battles()["castle_ravenloft_overlook"] as Dictionary
	await _start(str(fb["location"]))
	_foretell("executioner")
	if with_ireena:
		GameState.story.add_guest("ireena")
	var bot := _bot([answer], ["We came to end you."])
	assert_true(_view()._trigger_encounter(str(fb["trigger"])), "the parley begins")
	await bot.settle(600)
	return bot


func _ended(bot: StoryBot) -> String:
	for i in 120:
		if root.get("ending") != null:
			break
		await bot.frames(1)
	var screen := root.get("ending") as EndingScreen
	if screen == null:
		return ""
	screen.to_title = false
	return Endings.reached(GameState.story)


func test_ending_strahd_triumphant_when_the_party_yields() -> void:
	var bot := await _parley("We yield.", false)
	assert_eq(await _ended(bot), "strahd_triumphant", "kneeling to him ends the game in his favour")


func test_ending_ireena_given_up_at_the_parley() -> void:
	var bot := await _parley("Take her, then. Let us go.", true)
	assert_eq(await _ended(bot), "ireena_given_up", "handing Ireena over ends the game with the bride")


func test_ending_strahd_triumphant_when_the_party_falls() -> void:
	var fb := final_battles()["castle_ravenloft_overlook"] as Dictionary
	await _start(str(fb["location"]), 2)
	_foretell("executioner")
	var bot := _bot(["We came to end you."])
	assert_true(_view()._trigger_encounter(str(fb["trigger"])), "the parley begins")
	await bot.settle(3000)
	assert_true(bot.defeated, "a level 2 party falls to Strahd")
	assert_eq(await _ended(bot), "strahd_triumphant", "a wipe in the final battle is an ending, not a load screen")


## The dawn, by the book's weapon: Strahd beaten while the Sunsword's sunlight is on him can't turn to mist, and is
## destroyed where he falls (the vampire's Misty Escape fails in sunlight).
func test_ending_strahd_destroyed_by_the_sunsword() -> void:
	var fb := final_battles()["castle_ravenloft_chapel"] as Dictionary
	await _start(str(fb["location"]))
	var st := GameState.story
	_foretell("artifact")
	var ilse := st.party[0]
	ilse.add_item("sunsword")
	ilse.attune("sunsword")
	ilse.equip("sunsword", "main_hand")
	var bot := _bot(["We came to end you."], ["We yield.", "Take her, then."])
	# Through the porch doors into the nave, where he waits.
	await bot.walk_to(Vector2i(9, 12))
	if not await bot.settle(6000):
		_trace(bot)
	_fights(bot)
	assert_false(bot.defeated, "the party wins the final battle")
	var ending := await _ended(bot)
	if bool(st.get_flag("strahd_in_coffin", false)):
		print("    (he fell outside the blade's light and fled as mist; the coffin test covers that path)")
		return
	assert_true(bool(st.get_flag("strahd_destroyed", false)), "in sunlight he can't escape as mist")
	assert_eq(ending, "strahd_destroyed", "dawn over Barovia")


## The dawn, the long way: without sunlight on him Strahd flees as mist to his coffin; the party follows him down
## through the catacombs, beats his keepers and drives the stake home.
func test_ending_strahd_destroyed_in_his_coffin() -> void:
	var fb := final_battles()["castle_ravenloft_chapel"] as Dictionary
	await _start(str(fb["location"]))
	var st := GameState.story
	_foretell("artifact")
	# No sunlight on him this time: the Holy Symbol stays dark, and the hunters fight beside the party.
	var hedda := st.party[2]
	hedda.add_item("holy_symbol_of_ravenkind")
	hedda.attune("holy_symbol_of_ravenkind")
	for npc: String in ["ezmerelda", "rictavio"]:
		st.add_guest(npc)
	st.set_flag("heart_of_sorrow_shattered", true)
	_view().place_guests()
	var bot := _bot(["We came to end you.", "Drive the stake through his heart"], ["We yield.", "Take her, then."])
	# Through the porch doors into the nave, where he waits.
	await bot.walk_to(Vector2i(9, 12))
	if not await bot.settle(6000):
		_trace(bot)
	_fights(bot)
	assert_false(bot.defeated, "the party wins the final battle")
	assert_true(bool(st.get_flag("strahd_in_coffin", false)), "beaten, he flees as mist to his coffin")
	assert_false(bool(st.get_flag("strahd_destroyed", false)), "and he isn't destroyed yet")
	if bot.defeated or not bool(st.get_flag("strahd_in_coffin", false)):
		return
	if not await bot.go_to("castle_ravenloft_catacombs_strahd"):
		_trace(bot)
		assert_true(false, "down to his tomb")
		return
	await bot.settle()
	await bot.walk_to(Vector2i(11, 9))
	await bot.settle(6000)
	await bot.use(Vector2i(11, 12))
	await bot.settle(2000)
	_fights(bot)
	assert_true(bool(st.get_flag("strahd_destroyed", false)), "the stake ends him")
	assert_eq(st.quest_stage("strahds_lair"), "destroyed")
	assert_eq(await _ended(bot), "strahd_destroyed", "dawn over Barovia")
	if Endings.reached(st) != "strahd_destroyed":
		_trace(bot)


func _fights(bot: StoryBot) -> void:
	for f in bot.fights:
		print("    %s: %s, %s in %d rounds, %d down" % [f["where"], ", ".join(f["foes"] as Array), f["outcome"], int(f["rounds"]), int(f["downs"])])


func _trace(bot: StoryBot) -> void:
	print("  --- story bot trace ---")
	for line: String in bot.trace.slice(maxi(0, bot.trace.size() - 60)):
		print("    ", line)


## The castle end to end, the way a party arrives: on the road with the treasures found, Strahd's invitation comes
## and the black carriage takes them to his gate; they dine with him, climb to the Court of the Count where the cards
## said he would wait, refuse his price and destroy him. The road there from a new game is the Phase 3, 4 and 5 exits'.
func test_from_the_road_to_the_dawn() -> void:
	await _start("svalich_crossroads")
	var st := GameState.story
	_foretell("beast")   # the audience hall
	st.day = 9
	for f: String in ["burgomaster_buried", "strahd_watcher_seen", "strahd_letter_read"]:
		st.set_flag(f, true)
	var ilse := st.party[0]
	ilse.add_item("sunsword")
	ilse.attune("sunsword")
	ilse.equip("sunsword", "main_hand")
	st.party[2].add_item("holy_symbol_of_ravenkind")
	st.party[2].attune("holy_symbol_of_ravenkind")
	ilse.add_item("tome_of_strahd")
	var bot := _bot(["Get in.", "Thank him for his hospitality.", "We'll find our own way.", "We came to end you.", "Keep it."],
		["Not tonight.", "Tear up the letter.", "Draw on him.", "We yield.", "Take her, then.", "Then we go through you"])
	await bot.settle()
	# Any outdoor arrival at level 9 or more brings the letter, and the carriage with it (the game's arrival hook).
	# (The first letter comes first if it hasn't yet; the invitation at the next arrival.)
	for i in 3:
		if st.location.begins_with("castle_ravenloft"):
			break
		root.call("_strahd", "arrive", {"location": st.location, "outdoors": true})
		await bot.settle()
	if not _ok(st.location == "castle_ravenloft_gates", "the carriage set the party down at the castle gate (at %s)" % st.location, bot):
		return
	assert_eq(str(st.get_flag("strahd_invitation", "")), "accepted")
	GoldenSaves.keep("castle_ravenloft_gates", "test_phase6_exit")
	if not _ok(await bot.go_to("castle_ravenloft_main_floor"), "in through the great doors", bot):
		return
	_view().refresh_npcs()
	await bot.talk("strahd")
	await bot.settle()
	assert_eq(str(st.get_flag("castle_dinner", "")), "dined", "dinner with the devil")
	if not _ok(await bot.go_to("castle_ravenloft_court"), "up the grand stairs to the Court of the Count", bot):
		return
	await bot.settle()
	await bot.walk_to(Vector2i(21, 4))
	await bot.settle(6000)
	_fights(bot)
	_ok(not bot.defeated, "the party wins the final battle", bot)
	if bool(st.get_flag("strahd_in_coffin", false)) and not bool(st.get_flag("strahd_destroyed", false)):
		# He fell outside the blade's light and fled as mist: down through the castle to his coffin.
		print("    he fled as mist to his coffin; the party follows")
		if not _ok(await bot.go_to("castle_ravenloft_catacombs_strahd"), "down to his tomb", bot):
			return
		await bot.settle()
		await bot.walk_to(Vector2i(11, 9))
		await bot.settle(6000)
		await bot.use(Vector2i(11, 12))
		await bot.settle(2000)
		_fights(bot)
	var ending := await _ended(bot)
	GoldenSaves.keep("the_end", "test_phase6_exit", {"finished": {"ending": ending,
		"title": str(Endings.get_ending(ending).get("title", ending))}})
	_ok(bool(st.get_flag("strahd_destroyed", false)), "Strahd destroyed", bot)
	assert_eq(st.quest_stage("strahds_lair"), "destroyed")
	assert_eq(ending, "strahd_destroyed", "dawn over Barovia")


func _ok(cond: bool, msg: String, bot: StoryBot) -> bool:
	assert_true(cond, msg)
	if not cond:
		_trace(bot)
	return cond
