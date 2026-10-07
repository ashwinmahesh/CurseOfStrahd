extends TestCase
## The companions' personal quests end in Castle Ravenloft (docs/story/personal_quests.md, castle hooks 1 to 4;
## narrative/castle_ravenloft/personal_*.dialogue). Each payoff is played to its end with DialoguePathBot from the map
## entry that opens it, and lands on its quest's last stage; the entries stand only with their companion.

const MAIN := "castle_ravenloft_main_floor"
const COURT := "castle_ravenloft_court"
const CHAPEL := "castle_ravenloft_chapel"
const ROLL_CALL := "castle_ravenloft/personal_kestrel:roll_call"


## The four pregens at level 10 (the castle's band), leaving out `without`.
func _party(without: String = "") -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		if id != without:
			st.party.append(Pregens.build(id, 10))
	return st


## Ilse's company followed to Jory Fenn, who was forgiven and gave her the captain's roll.
func _kestrel() -> StoryState:
	var st := _party()
	st.set_quest_stage("kestrel_company", "the_deserter")
	st.set_flag("kestrel_roll_kept", true)
	st.set_flag("kestrel_jory_forgiven", true)
	return st


## A location's `key` entries (npcs, props, encounters) whose `field` is `value`.
static func _entries(loc: String, key: String, field: String, value: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in Compendium.shared().get_entry("locations", loc).get(key, []):
		if str((e as Dictionary).get(field, "")) == value:
			out.append(e as Dictionary)
	return out


## The entry `npc` stands at now (the first whose `when` holds, as LocationView picks), or {}.
static func _standing(st: StoryState, loc: String, npc: String) -> Dictionary:
	for e in _entries(loc, "npcs", "npc", npc):
		if StoryConditions.check(str(e.get("when", "")), st):
			return e
	return {}


static func _prop_shown(st: StoryState, loc: String, id: String) -> bool:
	var found := _entries(loc, "props", "id", id)
	return not found.is_empty() and StoryConditions.check(str(found[0].get("when", "")), st)


static func _prop_dialogue(loc: String, id: String) -> String:
	return str(_entries(loc, "props", "id", id)[0].get("dialogue", ""))


## Plays `ref` with DialoguePathBot toward `quest q stage`; "" once the quest stands there, else the bot's trace.
func _play(st: StoryState, ref: String, q: String, stage: String) -> String:
	var bot := DialoguePathBot.new()
	var goal := func(s: Dictionary) -> bool:
		return str(s.get("t", "")) == "quest" and str(s.get("id", "")) == q and str(s.get("stage", "")) == stage
	var done := func() -> bool: return st.quest_stage(q) == stage
	if bot.play(st, ref, goal, done):
		return ""
	return "%s never reached %s %s: %s" % [ref, q, stage, " / ".join(bot.trace)]


## What winning a fight hands the story, as LocationView does: the variant start_encounter picks (the first whose
## condition holds, else the last) sets its flag and moves its quest. Returns that variant.
func _win(st: StoryState, loc: String, id: String) -> Dictionary:
	var spec := {}
	for e in _entries(loc, "encounters", "id", id):
		if spec.is_empty() or not StoryConditions.check(StoryConditions.encounter_when(spec), st):
			spec = e
	assert_false(spec.is_empty(), "%s has a fight %s" % [loc, id])
	if spec.has("flag"):
		st.set_flag(str(spec["flag"]))
	if spec.has("quest"):
		var q := spec["quest"] as Dictionary
		st.set_quest_stage(str(q["id"]), str(q["stage"]))
	return spec


## Plays `ref`, taking at each menu the first option whose text starts with one of `picks` (with none, it stops at
## the first menu). Returns every beat; the last is the end beat (with its `combat`) when it got there.
func _drive(st: StoryState, ref: String, picks: Array[String] = []) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 300:
		beats.append(b)
		var kind := str(b.get("kind", ""))
		if kind == "end":
			break
		if kind == "options":
			var pick := -1
			var opts := b["options"] as Array
			for j in opts.size():
				for p: String in picks:
					if pick < 0 and str((opts[j] as Dictionary)["text"]).begins_with(p):
						pick = j
			if pick < 0:
				break
			b = r.choose(pick)
		else:
			b = r.next()
	return beats


static func _spoke(beats: Array[Dictionary], speaker_id: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) == "line" and str(b.get("speaker_id", "")) == speaker_id:
			return true
	return false


static func _said(beats: Array[Dictionary], words: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) == "line" and str(b.get("text", "")).contains(words):
			return true
	return false


static func _combat(beats: Array[Dictionary]) -> String:
	if beats.is_empty() or str(beats[-1].get("kind", "")) != "end":
		return ""
	return str(beats[-1].get("combat", ""))


# --- 1. Count Off: the roll call at Kestrel Company's table ----------------------------------------------------

func test_merrow_keeps_the_head_of_the_table_once_strahd_has_gone() -> void:
	var st := _party()
	st.set_quest_stage("kestrel_company", "the_deserter")
	assert_eq(str(_standing(st, MAIN, "kestrel_merrow").get("dialogue", "")), ROLL_CALL, "uninvited: at the head of the table")
	assert_eq(int(_standing(st, MAIN, "kestrel_merrow").get("approach", 0)), 10, "and he speaks first")
	st.set_flag("strahd_invitation", "accepted")
	assert_eq(str(_standing(st, MAIN, "kestrel_merrow").get("dialogue", "")), "castle_ravenloft/personal_kestrel:at_dinner",
		"while the dinner waits he stands at Strahd's shoulder")
	st.set_flag("castle_dinner", "affront")
	assert_true(_standing(st, MAIN, "kestrel_merrow").is_empty(), "not there while Strahd's fight at the table is on")
	st.set_flag("crg_dinner_fight_over", true)
	assert_eq(str(_standing(st, MAIN, "kestrel_merrow").get("dialogue", "")), ROLL_CALL, "after the fight, the roll call")
	st.flags.erase("crg_dinner_fight_over")
	st.set_flag("castle_dinner", "dined")
	assert_eq(str(_standing(st, MAIN, "kestrel_merrow").get("dialogue", "")), ROLL_CALL, "after the dinner, the roll call")
	assert_true(_prop_shown(st, MAIN, "crg_kestrel_coats"), "the coats are on the chairs")
	var early := _party()
	early.set_quest_stage("kestrel_company", "the_count")
	assert_true(_standing(early, MAIN, "kestrel_merrow").is_empty(), "not before Jory told where the company went")
	var without := _party("ilse_varga")
	without.set_quest_stage("kestrel_company", "the_deserter")
	assert_true(_standing(without, MAIN, "kestrel_merrow").is_empty(), "no Ilse, no captain")
	assert_false(_prop_shown(without, MAIN, "crg_kestrel_coats"), "and no coats")


func test_the_roll_call_ends_in_count_off() -> void:
	var st := _kestrel()
	var why := _play(st, ROLL_CALL, "kestrel_company", "count_off")
	if why != "":
		# Ilse's Persuasion DC 18 failed (spent for good): Merrow called the whole wall out, and it's the fight.
		assert_true(bool(st.get_flag("kestrel_merrow_called", false)), "only a failed call leads away from the count: " + why)
		var spec := _win(st, MAIN, "crg_kestrel_table")
		assert_eq((spec["monsters"] as Array).size(), 5, "a failed call costs the bigger fight: Merrow and four")
	else:
		assert_true(bool(st.get_flag("kestrel_merrow_counted", false)), "Merrow stood and was counted")
		assert_true(bool(st.get_flag("kestrel_count_done", false)), "and Ilse wrote the last number")
	assert_eq(st.quest_stage("kestrel_company"), "count_off")
	assert_true(_standing(st, MAIN, "kestrel_merrow").is_empty(), "the captain's chair is empty")


func test_merrow_settled_by_steel_and_the_coats_close_the_count() -> void:
	var st := _kestrel()
	var beats := _drive(st, ROLL_CALL, ["Then answer for them"])
	assert_true(_said(beats, "Jory carried in his drum") or _said(beats, "cracked book"), "Ilse reads the roll from the captain's book")
	assert_true(_said(beats, "a drum starts up"), "Jory's drum sounds at the gate")
	assert_eq(_combat(beats), "crg_kestrel_table")
	var spec := _win(st, MAIN, "crg_kestrel_table")
	assert_eq((spec["monsters"] as Array).size(), 1, "Jory's drum held the company in its ranks: Merrow fights alone")
	assert_eq(st.quest_stage("kestrel_company"), "count_off", "winning the fight is the count off")
	assert_true(_prop_shown(st, MAIN, "crg_kestrel_coats"), "the coats are still on the chairs")
	var bot := DialoguePathBot.new()
	var goal := func(s: Dictionary) -> bool: return str(s.get("t", "")) == "set" and str(s.get("flag", "")) == "kestrel_count_done"
	var done := func() -> bool: return bool(st.get_flag("kestrel_count_done", false))
	assert_true(bot.play(st, _prop_dialogue(MAIN, "crg_kestrel_coats"), goal, done), "the coats close the count: " + " / ".join(bot.trace))
	# Without Jory's drum two of the company come out of the walls with him.
	var unforgiven := _party()
	unforgiven.set_quest_stage("kestrel_company", "the_deserter")
	assert_eq(_combat(_drive(unforgiven, ROLL_CALL, ["Then answer for them"])), "crg_kestrel_table")
	assert_eq((_win(unforgiven, MAIN, "crg_kestrel_table")["monsters"] as Array).size(), 3, "Merrow and two")


func test_the_cellar_stair_holds_the_rest_of_the_company() -> void:
	var st := _kestrel()
	var fights := _entries(MAIN, "encounters", "id", "crg_kestrel_cellar")
	assert_eq(str(fights[0]["trigger"]), "enter_area:crg_servery", "up the servants' stair from the cellars")
	assert_true(fights.any(func(e: Dictionary) -> bool: return StoryConditions.check(StoryConditions.encounter_when(e), st)), "waiting there")
	var spec := _win(st, MAIN, "crg_kestrel_cellar")
	assert_eq(str(((spec["monsters"] as Array)[0] as Dictionary)["name"]), "Corporal Vell", "Vell leads them, if the road never laid him to rest")
	assert_true(bool(st.get_flag("kestrel_vell_rests", false)))
	assert_eq(st.quest_stage("kestrel_company"), "vell_rests")
	st.set_quest_stage("kestrel_company", "count_off")
	assert_false(fights.any(func(e: Dictionary) -> bool: return StoryConditions.check(StoryConditions.encounter_when(e), st)), "not once the company is counted")
	var without := _party("ilse_varga")
	without.set_quest_stage("kestrel_company", "the_deserter")
	assert_false(fights.any(func(e: Dictionary) -> bool: return StoryConditions.check(StoryConditions.encounter_when(e), without)), "no Ilse, no company")


# --- 2. The Woman in the Locket: Tatyana's portrait in the study -----------------------------------------------

func test_the_kept_locket_goes_to_strahd_or_into_the_fire() -> void:
	for stage: String in ["burned", "given_to_strahd"]:
		var st := _party()
		st.set_quest_stage("the_locket", "kept")
		st.set_flag("locket_fate", "kept")
		assert_true(_prop_shown(st, COURT, "court_locket_candles"), "the candles under her portrait")
		var why := _play(st, _prop_dialogue(COURT, "court_locket_candles"), "the_locket", stage)
		assert_eq(why, "")
		assert_eq(st.quest_stage("the_locket"), stage)
		assert_false(_prop_shown(st, COURT, "court_locket_candles"), "settled for good")
	# Never decided at the pool: he still has it, and Strahd still asks.
	var undecided := _party()
	undecided.set_quest_stage("the_locket", "the_coach")
	assert_eq(_play(undecided, _prop_dialogue(COURT, "court_locket_candles"), "the_locket", "burned"), "")
	# With Strahd in his coffin nobody asks, and nothing is decided.
	var alone := _party()
	alone.set_quest_stage("the_locket", "kept")
	alone.set_flag("locket_fate", "kept")
	alone.set_flag("strahd_in_coffin", true)
	assert_false(_spoke(_drive(alone, _prop_dialogue(COURT, "court_locket_candles")), "strahd"), "he isn't there")
	assert_eq(alone.quest_stage("the_locket"), "kept")
	var without := _party("tamsin_tealeaf")
	without.set_flag("locket_fate", "kept")
	assert_false(_prop_shown(without, COURT, "court_locket_candles"), "no Tamsin, no candles")


func test_a_locket_given_away_is_a_payoff_not_a_stage() -> void:
	var ref := _prop_dialogue(COURT, "court_locket_candles")
	var pool := _party()
	pool.set_quest_stage("the_locket", "given_to_sergei")
	pool.set_flag("locket_fate", "pool")
	assert_true(_spoke(_drive(pool, ref), "strahd"), "Strahd remarks that his brother has it")
	assert_eq(pool.quest_stage("the_locket"), "given_to_sergei")
	assert_false(_prop_shown(pool, COURT, "court_locket_candles"), "once")
	var pool_alone := _party()
	pool_alone.set_quest_stage("the_locket", "given_to_sergei")
	pool_alone.set_flag("locket_fate", "pool")
	pool_alone.set_flag("strahd_in_coffin", true)
	var beats := _drive(pool_alone, ref)
	assert_false(_spoke(beats, "strahd"), "not when he isn't there")
	assert_true(beats.size() > 2, "a short beat instead")
	for in_coffin: bool in [false, true]:
		var st := _party()
		st.set_quest_stage("the_locket", "given_to_ireena")
		st.set_flag("locket_fate", "ireena")
		st.set_flag("strahd_in_coffin", in_coffin)
		assert_true(st.add_guest("ireena"))
		var b := _drive(st, ref)
		assert_true(_spoke(b, "ireena"), "Ireena shows the locket")
		assert_eq(_spoke(b, "strahd"), not in_coffin, "to him when he's there, to the portrait when he isn't")
		assert_eq(st.quest_stage("the_locket"), "given_to_ireena")


# --- 3. Cold Prayers: dawn at the chapel altar -------------------------------------------------------------

func test_hedda_prays_dawn_into_the_chapel() -> void:
	var st := _party()
	st.set_quest_stage("cold_prayers", "warmth")
	assert_true(_prop_shown(st, CHAPEL, "crg_chapel_dawn_step"), "the altar step, with the raven's warmth")
	assert_eq(_play(st, _prop_dialogue(CHAPEL, "crg_chapel_dawn_step"), "cold_prayers", "dawn"), "")
	assert_eq(st.quest_stage("cold_prayers"), "dawn")
	assert_false(_prop_shown(st, CHAPEL, "crg_chapel_dawn_step"), "once")
	# After the artifact card's battle here (Strahd fled to his coffin) the prayer still comes, and he feels it.
	var after := _party()
	after.set_quest_stage("cold_prayers", "warmth")
	after.set_flag("strahd_in_coffin", true)
	assert_true(_said(_drive(after, _prop_dialogue(CHAPEL, "crg_chapel_dawn_step"), ["(Kneel"]), "coffin"))
	assert_eq(after.quest_stage("cold_prayers"), "dawn")
	# The step is in the chancel, past the nave whose entry starts that battle: it can't run during the fight.
	var step := _entries(CHAPEL, "props", "id", "crg_chapel_dawn_step")[0]
	var chancel := _entries(CHAPEL, "areas", "id", "crg_chapel_chancel")[0]
	assert_true(LocationView._in_area(chancel, Vector2i(int((step["cell"] as Array)[0]), int((step["cell"] as Array)[1]))), "in the chancel")
	var early := _party()
	early.set_quest_stage("cold_prayers", "the_keepers")
	assert_false(_prop_shown(early, CHAPEL, "crg_chapel_dawn_step"), "not before the Holy Symbol warmed")
	var without := _party("hedda_ironvow")
	without.set_quest_stage("cold_prayers", "warmth")
	assert_false(_prop_shown(without, CHAPEL, "crg_chapel_dawn_step"), "no Hedda, no prayer")


# --- 4. Aurel's Last Chapter: the lit window ----------------------------------------------------------------

static func _card_for_room(room: String) -> String:
	var table := Compendium.shared().get_entry("tarokka", "outcomes").get("enemy", {}) as Dictionary
	for card: String in table:
		if str((table[card] as Dictionary).get("room", "")) == room:
			return card
	return ""


func test_aurel_wakes_by_the_fire_behind_the_lit_window() -> void:
	var st := _party()
	st.set_quest_stage("aurels_last_chapter", "still_reading")
	st.party[3].add_item("tome_of_strahd")
	var aurel := _standing(st, COURT, "aurel_mirescu")
	assert_false(aurel.is_empty(), "Aurel reads by the study fire")
	assert_true(int(aurel.get("approach", 0)) > 0, "and Silvain sees him on walking in")
	assert_true(_prop_shown(st, COURT, "court_study_window_lit"), "behind the lit window")
	assert_false(_prop_shown(st, COURT, "court_study_window"))
	var start := DialogueFile.load_key("castle_ravenloft/personal_aurel").nodes["start"] as Array
	assert_true(start.any(func(s: Dictionary) -> bool: return str(s.get("text", "")).contains("He miscounted the floors")), "Silvain's line about the floors")
	# While Strahd waits in the study for the final battle (the seer), Aurel isn't there; after it, he is.
	st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": _card_for_room("castle_ravenloft_study")}
	st.set_quest_stage("strahds_lair", "foretold")
	assert_true(_standing(st, COURT, "aurel_mirescu").is_empty(), "not during the seer's final battle")
	st.set_quest_stage("strahds_lair", "confronted")
	assert_false(_standing(st, COURT, "aurel_mirescu").is_empty(), "back after it")
	assert_eq(_play(st, str(aurel["dialogue"]), "aurels_last_chapter", "the_last_page"), "")
	assert_eq(st.quest_stage("aurels_last_chapter"), "the_last_page")
	assert_true(_standing(st, COURT, "aurel_mirescu").is_empty(), "he has gone home to sleep")
	assert_false(_prop_shown(st, COURT, "court_study_window_lit"), "and the lamp in the window is out")
	assert_true(_prop_shown(st, COURT, "court_study_window"))
	# Closing the Tome in his hands wakes him with no roll.
	var tome := _party()
	tome.set_quest_stage("aurels_last_chapter", "still_reading")
	tome.party[3].add_item("tome_of_strahd")
	_drive(tome, str(aurel["dialogue"]), ["(Put the Tome"])
	assert_eq(tome.quest_stage("aurels_last_chapter"), "the_last_page", "the Tome closed in his hands")
	# Without the Tome, and with no roll at all, sitting out the chapter costs three hours.
	var patient := _party()
	patient.set_quest_stage("aurels_last_chapter", "the_margins")
	var before := patient.total_minutes()
	_drive(patient, str(aurel["dialogue"]), ["(Sit with him"])
	assert_eq(patient.quest_stage("aurels_last_chapter"), "the_last_page")
	assert_true(patient.total_minutes() - before >= 180, "hours pass")
	var without := _party("silvain_aster")
	without.set_quest_stage("aurels_last_chapter", "still_reading")
	assert_true(_standing(without, COURT, "aurel_mirescu").is_empty(), "no Silvain, no Aurel")
	assert_false(_prop_shown(without, COURT, "court_study_window_lit"), "and an ordinary window")
