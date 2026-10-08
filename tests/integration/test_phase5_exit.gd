extends TestCase
## The Phase 5 exit (plan §10, ADR 0011): every Tarokka outcome place outside Castle Ravenloft exists and its treasure
## can be obtained, and every ally outside the castle can join. For each place the reading is set so a treasure lies
## there, then the spot hands it over the way the game does: the chest opened, the fight's spoils, or the conversation
## played by DialoguePathBot up to `tarokka give`. Each ally's conversation is played up to `join`. The regions'
## critical paths are played end to end by StoryBot below. Slow: `make test ONLY=phase5_exit`.

## Story state a spot or ally scene expects before it can happen (flags set earlier in its region's story), by place
## or ally npc. Written from the region docs' critical paths.
const SETUP := {
	"berez_baba_lysagas_hut": {"lysaga_dead": true},
	"old_bonegrinder": {"offalia_slain": true},
	"davian_martikov": {"winery_reclaimed": true},
	"emil_toranescu": {"emil_key_found": true},
	"arabelle": {"arabelle_rescued": true, "bluto_fate": "saved"},
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


## Treasure places outside the castle: place -> region.
static func treasure_places() -> Dictionary:
	var out := {}
	for slot in Tarokka.TREASURES:
		var table := Compendium.shared().get_entry("tarokka", "outcomes").get(slot, {}) as Dictionary
		for card: String in table:
			var o := table[card] as Dictionary
			if str(o["region"]) != "castle_ravenloft":
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


## The treasure places in two halves by location, so make test can run them side by side (they took two minutes in
## one test). Between them they visit every location that holds one.
func test_every_treasure_place_in_the_first_half_of_their_locations_gives_its_treasure() -> void:
	await _treasures(0)


func test_every_treasure_place_in_the_second_half_of_their_locations_gives_its_treasure() -> void:
	await _treasures(1)


## Plays every treasure place in half `half` (0 or 1) of the locations that hold one, sorted by id; the first half also
## fails for a place with no spot at all.
func _treasures(half: int) -> void:
	var places := treasure_places()
	var failures: Array[String] = []
	var by_location := {}
	for place: String in places:
		var s := spot_of(place)
		if s.is_empty():
			if half == 0:
				failures.append("%s (%s): no treasure spot in any location" % [place, places[place]])
			continue
		if not by_location.has(s["location"]):
			by_location[s["location"]] = []
		(by_location[s["location"]] as Array).append(place)
	var locs: Array = by_location.keys()
	locs.sort()
	var mine: Array = locs.slice(0, (locs.size() + 1) / 2) if half == 0 else locs.slice((locs.size() + 1) / 2)
	var tried := 0
	for loc: String in mine:
		await _start(loc)
		for place: String in by_location[loc]:
			tried += 1
			var why := await _obtain(loc, place)
			if why != "":
				failures.append("%s at %s: %s" % [place, loc, why])
	for f in failures:
		print("    ", f)
	assert_true(not mine.is_empty(), "locations to visit")
	assert_true(failures.is_empty(), "%d of %d treasure places fail (listed above)" % [failures.size(), tried])
	print("  treasure places, half %d: %d of %d, all obtainable" % [half + 1, tried, places.size()] if failures.is_empty() else "")


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


func test_every_ally_outside_the_castle_can_join() -> void:
	var allies := Compendium.shared().get_entry("tarokka", "outcomes").get("ally", {}) as Dictionary
	var failures: Array[String] = []
	var checked := 0
	for card: String in allies:
		var o := allies[card] as Dictionary
		var npc := str(o.get("npc", ""))
		if npc == "" or str(o["region"]) == "castle_ravenloft":
			continue
		checked += 1
		var starts := _join_scenes(npc)
		if starts.is_empty():
			failures.append("%s (%s): no conversation that people or things in a location start reaches `join %s`" % [npc, card, npc])
			continue
		var joined := false
		var notes: Array[String] = []
		for ref: Dictionary in starts:
			await _start(str(ref["location"]))
			var st := GameState.story
			st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": card, "enemy": ""}
			_apply_setup(npc)
			var bot := DialoguePathBot.new()
			var goal := func(s: Dictionary) -> bool: return str(s.get("t", "")) == "join" and str(s.get("npc", "")) == npc
			var done := func() -> bool: return npc in st.guest_ids
			if bot.play(st, str(ref["dialogue"]), goal, done):
				joined = true
				break
			notes.append("%s: %s" % [ref["dialogue"], " / ".join(bot.trace.slice(maxi(0, bot.trace.size() - 4)))])
		if not joined:
			failures.append("%s (%s) never joins: %s" % [npc, card, "; ".join(notes)])
	for f in failures:
		print("    ", f)
	assert_true(failures.is_empty(), "%d of %d allies can't join (listed above)" % [failures.size(), checked])


## Every conversation start in a location (an NPC's or a prop's) from which `join <npc>` can be reached:
## [{location, dialogue}].
func _join_scenes(npc: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var bot := DialoguePathBot.new()
	var goal := func(s: Dictionary) -> bool: return str(s.get("t", "")) == "join" and str(s.get("npc", "")) == npc
	var locs := Compendium.shared().table("locations")
	for id: String in locs:
		var loc := locs[id] as Dictionary
		for k: String in ["npcs", "props"]:
			for e: Variant in loc.get(k, []):
				var ref := str((e as Dictionary).get("dialogue", ""))
				if ref != "" and ref.contains(":") and bot.reaches(ref, goal):
					out.append({"location": id, "dialogue": ref})
	return out


# --- The regions' critical paths, played through the real game (StoryBot and the fight autopilot) -------------------

func _bot(prefer: Array[String], avoid: Array[String]) -> StoryBot:
	var bot := StoryBot.new(self, root)
	bot.prefer.assign(prefer)
	bot.avoid.assign(avoid)
	return bot


func _ok(cond: bool, msg: String, bot: StoryBot) -> bool:
	assert_true(cond, msg)
	if not cond:
		print("  --- story bot trace ---")
		for line: String in bot.trace.slice(maxi(0, bot.trace.size() - 80)):
			print("    ", line)
	return cond


func _fights(bot: StoryBot) -> void:
	for f in bot.fights:
		print("    %s: %s, %s in %d rounds, %d down" % [f["where"], ", ".join(f["foes"] as Array), f["outcome"], int(f["rounds"]), int(f["downs"])])


## Region 5 (docs/regions/old_bonegrinder.md): split the coven, deal with Bella, free the children.
func test_old_bonegrinder_the_children_go_home() -> void:
	await _start("old_bonegrinder_hill", 5)
	var st := GameState.story
	st.gold = 400.0
	st.set_flag("bonegrinder_rumor", true)
	var bot := _bot(["Fly with us. We're going in.", "Step away from the oven, Offalia. Now.",
		"Deal. Stay out of it, and the mill is yours.", "Then we'll take them from you.",
		"A deal's a deal. The mill and the bags are yours.", "Tell her the truth: yes, she did.", "Take them home to the village."],
		["Keep them", "Take mine", "We'll buy them back", "Strike her down", "We're leaving", "Wait. Not like this",
		"No deals with hags", "Leave her to her baking", "Our deal ends here"])
	await bot.settle()
	GoldenSaves.keep("old_bonegrinder", "test_phase5_exit")
	for npc: String in ["ilinca_vrana"]:
		if not st.guest_ids.has(npc):
			await bot.talk(npc)
	if not _ok(await bot.go_to("old_bonegrinder"), "into the mill", bot):
		return
	await bot.settle()
	if not bool(st.get_flag("offalia_slain", false)):
		await bot.talk("offalia_wormwiggle")
		await bot.settle()
	if not bool(st.get_flag("bella_pact", false)):
		await bot.talk("bella_sunbane")
		await bot.settle()
	if not _ok(await bot.go_to("old_bonegrinder_loft"), "up to the loft", bot):
		return
	await bot.settle()
	if not bool(st.get_flag("morgantha_slain", false)):
		await bot.talk("morgantha")
		await bot.settle()
	for npc: String in ["ilka_sarnov", "bella_sunbane"]:
		if not bool(st.get_flag("children_rescued", false)) or npc == "bella_sunbane":
			await bot.talk(npc)
			await bot.settle()
	_fights(bot)
	_ok(bool(st.get_flag("children_rescued", false)), "the children are free", bot)
	assert_eq(str(st.get_flag("bonegrinder_fate", "")), "bella", "Bella keeps the mill by her pact")
	assert_eq(st.milestones, 1, "one milestone")


## Region 6 (docs/regions/wizard_of_wines.md): retake the winery, return its stone, break Yester Hill.
func test_wizard_of_wines_saved_and_yester_hill_broken() -> void:
	await _start("wizard_of_wines", 6)
	var st := GameState.story
	st.gold = 400.0
	var bot := _bot(["Take us to your father.", "We'll clear your house.", "Turn the third hoop and pull.", "Then we'll take it back.",
		"The druids are out of your house.", "Your stone, from the founder's cask.", "To Vallaki.", "We're taking the stone.",
		"Go. Crawl off this hill", "The stone from Yester Hill.", "Yester Hill is finished."],
		["End it", "Call it our fee", "Deception", "Leave it standing"])
	await bot.settle()
	GoldenSaves.keep("wizard_of_wines", "test_phase5_exit")
	await bot.talk("davian_martikov")
	await bot.settle()
	if not _ok(await bot.go_to("wizard_of_wines_cellar"), "down to the cellar", bot):
		return
	await bot.settle()
	await bot.use(Vector2i(4, 2))
	await bot.settle()
	if not _ok(await bot.go_to("wizard_of_wines_press_house"), "the press house", bot):
		return
	await bot.settle()
	if not _ok(await bot.go_to("wizard_of_wines"), "back to the camp", bot):
		return
	await bot.talk("davian_martikov")
	await bot.settle()
	if not _ok(await bot.go_to("yester_hill_gulthias_tree"), "up Yester Hill", bot):
		return
	await bot.settle()
	# A lost summit is played again from its first round with other dice (StoryBot.fight): it's a close fight for the
	# autopilot's party.
	await bot.talk("ruxandra")
	await bot.settle()
	await bot.use(Vector2i(21, 10))
	await bot.settle()
	if not _ok(await bot.go_to("wizard_of_wines"), "home to the winery", bot):
		return
	await bot.talk("davian_martikov")
	await bot.settle()
	_fights(bot)
	_ok(bool(st.get_flag("wizard_of_wines_milestone_reached", false)), "the region's milestone", bot)
	assert_eq(int(st.get_flag("winery_stones_returned", 0)), 2, "two stones home")
	assert_true(bool(st.get_flag("keepers_allied", false)), "the Keepers of the Feather are allies")
	assert_eq(st.quest_stage("wizard_of_wines"), "saved")


## Region 8 (docs/regions/argynvostholt.md): kindle the dragon's fire, climb the dark tower, light the beacon.
func test_argynvostholt_the_beacon_is_lit() -> void:
	await _start("argynvostholt", 7)
	var st := GameState.story
	st.gold = 400.0
	var bot := _bot(["Madam Eva's cards named you, Sir Godfrey.", "something new to remember", "Why can't your knights rest?",
		"What did you ask of him", "Why is the beacon dark?", "What oath", "Speak the Order's oath", "Kindle a light",
		"He told you to let them go", "Light the beacon", "Ride with us, Sir Godfrey"],
		["We swear it", "Stand aside", "go through you", "trial of arms", "Lower the flame", "Rest, Sir Godfrey", "Not yet", "Leave him be"])
	if not _ok(await bot.go_to("argynvostholt_hall"), "into the hall", bot):
		return
	await bot.settle()
	GoldenSaves.keep("argynvostholt", "test_phase5_exit")
	await bot.talk("argynvost")
	await bot.settle()
	if not _ok(await bot.go_to("argynvostholt_mausoleum"), "the mausoleum", bot):
		return
	await bot.settle()
	if not bool(st.get_flag("mausoleum_opened", false)):
		await bot.talk("phantom_warden")
		await bot.settle()
	await bot.use(Vector2i(7, 5))
	await bot.settle()
	if not _ok(await bot.go_to("argynvostholt_beacon"), "the beacon tower", bot):
		return
	await bot.walk_to(Vector2i(10, 8))
	await bot.settle()
	await bot.use(Vector2i(11, 13))
	await bot.settle()
	await bot.use(Vector2i(6, 15))
	await bot.settle()
	_fights(bot)
	_ok(str(st.get_flag("order_fate", "")) == "rest", "the knights rest: %s" % st.get_flag("order_fate", ""), bot)
	assert_true(bool(st.get_flag("argynvost_beacon_lit", false)), "the beacon burns")
	assert_eq(st.milestones, 1, "one milestone")


## Region 7 (docs/regions/krezk.md): through the gate on the Abbot's word, the dress, and the Abbot's repentance.
func test_krezk_and_the_abbot_repents() -> void:
	await _start("krezk", 6)
	var st := GameState.story
	st.gold = 400.0
	var bot := _bot(["The Abbot of St. Markovia sent us", "Is there anywhere up here", "What's that paper", "May we read it",
		"Clovin says you have work", "Go on.", "We'll find her a dress.", "The Abbot asked us for a wedding dress",
		"Tell her the truth", "We've brought a dress", "Read him Markovia's letter."],
		["Attack", "Kill", "Steal", "Intimidation", "No. We won't help", "No. We can't take this", "We're leaving", "Stop this",
		"It's your abbey"])
	await bot.settle()
	GoldenSaves.keep("krezk", "test_phase5_exit")
	if not _ok(await bot.go_to("abbey_of_st_markovia"), "up to the abbey", bot):
		return
	await bot.settle()
	if not _ok(await bot.go_to("abbey_of_st_markovia_shrine"), "the shrine", bot):
		return
	await bot.settle()
	if not bool(st.get_flag("abbot_vouched", false)):
		await bot.talk("abbot")
		await bot.settle()
	if not _ok(await bot.go_to("krezk"), "back to Krezk", bot):
		return
	await bot.talk("krezk_guard")
	await bot.settle()
	if not _ok(await bot.go_to("krezk_burgomaster_house"), "the burgomaster's house", bot):
		return
	await bot.talk("anna_krezkova")
	await bot.settle()
	if not _ok(await bot.go_to("abbey_of_st_markovia_shrine"), "the shrine with the dress", bot):
		return
	await bot.talk("abbot")
	await bot.settle()
	_fights(bot)
	_ok(str(st.get_flag("abbot_fate", "")) == "repentant", "the Abbot repents: %s" % st.get_flag("abbot_fate", ""), bot)
	assert_eq(str(st.get_flag("vasilka_fate", "")), "laid_to_rest")
	assert_eq(str(st.get_flag("ilya_fate", "")), "healed")
	assert_true(bool(st.get_flag("krezk_milestone_reached", false)), "the region's milestone")


## Region 9b (docs/regions/berez.md): the witch's supper, the gem, the Mad Mage restored, through the Tsolenka gate.
func test_berez_baratok_and_the_tsolenka_gate() -> void:
	await _start("berez", 8)
	var st := GameState.story
	st.gold = 400.0
	var bot := _bot(["glad of a fire", "Enough games", "Take the green stone", "Take the jar, gently", "Unstack the stones",
		"Uncork the witch's jar", "(Cast Greater Restoration on him.)", "Show him the spellbook", "Read him the last page",
		"Madam Eva's cards named you. Will you come?", "Will you help us against him?", "held by dead men", "Cold hearth, shut door.",
		"Stand aside", "Haul on the winch", "Dig around the plinth"],
		["Come down, witch", "Light the grave-lamp", "Your nurse did", "We never said we'd leave you alive"])
	await bot.settle()
	GoldenSaves.keep("berez", "test_phase5_exit")
	if not bool(st.get_flag("lysaga_guests", false)):
		await bot.talk("baba_lysaga")
		await bot.settle()
	if not _ok(await bot.go_to("berez_baba_lysagas_hut"), "into the witch's hut", bot):
		return
	await bot.settle()
	if not bool(st.get_flag("lysaga_dead", false)):
		await bot.talk("baba_lysaga")
		await bot.settle()
	if not bool(st.get_flag("berez_milestone_reached", false)):
		await bot.talk("baba_lysaga")
		await bot.settle()
	await bot.use(Vector2i(5, 9))
	await bot.settle()
	await bot.use(Vector2i(3, 1))
	await bot.settle()
	_ok(bool(st.get_flag("berez_milestone_reached", false)), "the witch is dealt with: the milestone", bot)
	assert_true(bool(st.get_flag("winery_gem_berez_found", false)) or st.quest_stage("the_third_stone") == "found", "the winery's gem")
	if not _ok(await bot.go_to("mount_baratok_hut"), "up Mount Baratok", bot):
		return
	await bot.talk("mad_mage")
	await bot.settle()
	if not _ok(await bot.go_to("tsolenka_pass_guard_tower"), "the Tsolenka guard tower", bot):
		return
	await bot.settle()
	await bot.talk("tsolenka_sergeant")
	await bot.settle()
	await bot.use(Vector2i(3, 2))
	await bot.settle()
	_fights(bot)
	_ok(bool(st.get_flag("tsolenka_gate_open", false)), "the Tsolenka gate is open", bot)


## Region 9a (docs/regions/van_richtens_tower.md): Zuleika's key, Emil freed, the pack's challenge.
func test_werewolf_den_emil_leads_the_pack() -> void:
	await _start("werewolf_den", 7)
	var st := GameState.story
	st.gold = 400.0
	st.set_flag("werewolf_rumor", true)
	var bot := _bot(["We'll free Emil.", "We have the key to your chains.", "Howl, then.", "We stand with Emil.",
		"What do you want from strangers?", "It's over. You're going home."],
		["We won't do your killing", "Settle it between", "Take him back", "Neither of you", "Then we'll take them", "We're leaving",
		"Draw steel", "Let him go"])
	await bot.settle()
	GoldenSaves.keep("werewolf_den", "test_phase5_exit")
	if not bool(st.get_flag("zuleika_asked", false)):
		await bot.talk("zuleika_toranescu")
		await bot.settle()
	if not _ok(await bot.go_to("werewolf_den_caves"), "into the caves", bot):
		return
	await bot.settle()
	await bot.talk("emil_toranescu")
	await bot.settle()
	if str(st.get_flag("wolf_pack_leader", "")) == "":
		await bot.talk("kiril_stoyanovich")
		await bot.settle()
	await bot.talk("zuleika_toranescu")
	await bot.settle()
	_fights(bot)
	_ok(str(st.get_flag("wolf_pack_leader", "")) == "emil", "Emil leads: %s" % st.get_flag("wolf_pack_leader", ""), bot)
	assert_true(bool(st.get_flag("den_children_freed", false)), "the children go home")
	assert_eq(st.milestones, 1, "one milestone")


## Region 10 (docs/regions/amber_temple.md): through the doors, the library's word, the vaults, Vosk refused.
func test_amber_temple_the_pact_is_learned_and_no_gift_taken() -> void:
	await _start("amber_temple_entrance", 9)
	var st := GameState.story
	st.gold = 400.0
	st.set_flag("tsolenka_gate_open", true)
	var bot := _bot(["We don't know any word.", "The colossus at the doors asked us for a word.", "Speak the wardens' word.",
		"What are you offering?", "We'll take nothing from you.", "No one", "Seal it."],
		["Draw steel", "Attack", "Strike", "Smash", "Lie down in the amber", "I accept", "Keep at it", "bleeding hand"])
	await bot.settle()
	GoldenSaves.keep("amber_temple", "test_phase5_exit")
	await bot.use(Vector2i(19, 8))
	await bot.settle()
	if not _ok(await bot.go_to("amber_temple_faceless_god"), "the hall of the faceless god", bot):
		return
	await bot.use(Vector2i(19, 10))
	await bot.settle()
	if not _ok(await bot.go_to("amber_temple_library"), "the library", bot):
		return
	await bot.settle()
	await bot.talk("exethanter")
	await bot.settle()
	if not _ok(await bot.go_to("amber_temple_vault"), "the vaults", bot):
		return
	await bot.use(Vector2i(21, 8))
	await bot.settle()
	await bot.use(Vector2i(21, 2))
	await bot.settle()
	await bot.walk_to(Vector2i(19, 20))
	await bot.settle()
	if not bool(st.get_flag("amber_milestone_given", false)):
		await bot.use(Vector2i(19, 26))
		await bot.settle()
	_fights(bot)
	_ok(bool(st.get_flag("amber_milestone_given", false)), "the temple's milestone", bot)
	assert_true(st.quest_stage("the_amber_temple") in ["pact_learned", "temple_sealed"], "the pact learned: %s" % st.quest_stage("the_amber_temple"))
	for ch in st.party:
		assert_true(ch.dark_gifts().is_empty(), "%s took no gift" % ch.name)
