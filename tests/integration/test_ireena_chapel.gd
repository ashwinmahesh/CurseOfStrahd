extends TestCase
## Ireena in the castle chapel (Story Allies Presence Plan, package I5; narrative/castle_ravenloft/chapel_ireena.dialogue,
## the `ireena` entry of data/locations/castle_ravenloft_chapel.json). While Strahd holds her (ireena_held_by_strahd, set
## by strahd/ireena:taken) she stands at the altar, entranced. The ways that stop him at her window wake her here (the
## Holy Symbol, a cleric's faith, a warding prayer, "remember who you are") and so does the Sunsword; woken, she is a
## guest again and the flag is cleared. Two missteps and the trance holds for now. She is not there when she travels with
## the party, when she was never taken, or while the reading has Strahd waiting in this chapel for the final battle.

const CHAPEL := "castle_ravenloft_chapel"
const START := "castle_ravenloft/chapel_ireena:start"
const HOLY_SYMBOL := "holy_symbol_of_ravenkind"


func after_each() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


## The four pregens at level 10 (the castle's band), leaving out `without`.
func _party(without: String = "") -> StoryState:
	var st := StoryState.new()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		if id != without:
			st.party.append(Pregens.build(id, 10))
	return st


## A party that carries nobody who can pray for her: Hedda is the cleric.
func _no_cleric() -> StoryState:
	return _party("hedda_ironvow")


func _held(st: StoryState) -> StoryState:
	st.set_flag("ireena_held_by_strahd", true)
	st.set_flag("strahd_window", "taken")
	return st


## The chapel's entry for `npc` that stands now (the first whose `when` holds, as LocationView picks), or {}.
static func _standing(st: StoryState, npc: String) -> Dictionary:
	for e: Variant in Compendium.shared().get_entry("locations", CHAPEL).get("npcs", []):
		var entry := e as Dictionary
		if str(entry.get("npc", "")) == npc and StoryConditions.check(str(entry.get("when", "")), st):
			return entry
	return {}


## The reading puts Strahd in the chapel: the enemy card the artifact's holder waits there for (test_phase6_exit).
static func _strahd_waits_in_the_chapel(st: StoryState) -> void:
	st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": "artifact"}
	st.set_quest_stage("strahds_lair", "foretold")


## Plays `ref` with dice `seed_value`, taking at each menu the first option whose text starts with one of `picks`, in
## the order they are listed (the same pick may be taken again). With no pick that fits it stops at that menu. Returns
## every beat; the last is the end beat when the conversation got there.
func _drive(st: StoryState, ref: String, picks: Array[String] = [], seed_value: int = 1) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(seed_value))
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
			for p: String in picks:
				for j in opts.size():
					if pick < 0 and str((opts[j] as Dictionary)["text"]).begins_with(p):
						pick = j
				if pick >= 0:
					break
			if pick < 0:
				break
			b = r.choose(pick)
		else:
			b = r.next()
	return beats


static func _said(beats: Array[Dictionary], words: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) == "line" and str(b.get("text", "")).contains(words):
			return true
	return false


static func _spoke(beats: Array[Dictionary], speaker_id: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) == "line" and str(b.get("speaker_id", "")) == speaker_id:
			return true
	return false


static func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				out.append(str((o as Dictionary)["text"]))
	return out


static func _clock(st: StoryState) -> int:
	return st.day * 1440 + st.minute_of_day


## She was woken (`how` names the way, for the message): Strahd no longer holds her and she walks with the party again.
func _woken(st: StoryState, how: String) -> void:
	assert_false(bool(st.get_flag("ireena_held_by_strahd", false)), how + ": Strahd no longer holds her")
	assert_true("ireena" in st.guest_ids, how + ": she walks with the party again")


# --- Where she stands --------------------------------------------------------------------------------------------------

func test_ireena_stands_at_the_altar_only_while_strahd_holds_her() -> void:
	var st := _party()
	assert_true(_standing(st, "ireena").is_empty(), "never taken: the chapel is empty")
	_held(st)
	var e := _standing(st, "ireena")
	assert_false(e.is_empty(), "held: she is at the altar")
	assert_eq(str(e.get("dialogue", "")), START, "talking to her opens the chapel scene")
	assert_true(int(e.get("approach", 0)) > 0, "and it opens by itself on first sight")
	st.add_guest("ireena")
	assert_true(_standing(st, "ireena").is_empty(), "travelling with the party she is not in the chapel")
	var rescued := _held(_party())
	rescued.set_flag("ireena_held_by_strahd", false)
	assert_true(_standing(rescued, "ireena").is_empty(), "woken: gone from the chapel")


func test_she_is_not_there_while_the_final_battle_waits_in_the_chapel() -> void:
	var st := _held(_party())
	_strahd_waits_in_the_chapel(st)
	assert_true(_standing(st, "ireena").is_empty(), "the parley says she is upstairs, so she is not at the altar behind him")
	st.set_flag("strahd_in_coffin", true)
	assert_false(_standing(st, "ireena").is_empty(), "he fell and went to his coffin: she is still there")
	var other := _held(_party())
	other.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": "beast"}
	other.set_quest_stage("strahds_lair", "foretold")
	assert_false(_standing(other, "ireena").is_empty(), "Strahd waits in another room: she is at the altar")


func test_her_square_is_open_floor_in_the_chancel() -> void:
	var loc := Compendium.shared().get_entry("locations", CHAPEL)
	var e := _standing(_held(_party()), "ireena")
	var cell := e["cell"] as Array
	var x := int(cell[0])
	var y := int(cell[1])
	var row := str((loc["map"] as Dictionary)["rows"][y])
	assert_true(row[x] in ".+_", "she stands on floor, not a wall or a pew (%s)" % row[x])
	assert_between(y, 1, 3, "in the chancel, at the altar")
	for list: String in ["props", "containers"]:
		for p: Variant in loc.get(list, []):
			assert_ne((p as Dictionary).get("cell", []), cell, "no %s stands on her square" % list)
	assert_true(bool(e.get("steps_aside", false)), "if a fight ever starts here she keeps off the board")


func test_the_entry_in_a_chapel_view() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		GameState.story.party.append(Pregens.build(id, 10))
	_held(GameState.story)
	var v := LocationView.create(CHAPEL, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(v)
	await get_tree().process_frame
	assert_true(v._npc_shown.any(func(s: Dictionary) -> bool: return str((s["spec"] as Dictionary)["npc"]) == "ireena"), "she is on the board")
	GameState.story.add_guest("ireena")
	v.refresh_npcs()
	assert_false(v._npc_shown.any(func(s: Dictionary) -> bool: return str((s["spec"] as Dictionary)["npc"]) == "ireena"), "and off it once she joins")


# --- The ways she wakes ------------------------------------------------------------------------------------------------

func test_the_holy_symbol_wakes_her_and_only_while_it_is_carried() -> void:
	var st := _held(_no_cleric())
	var plain := _drive(st, START)
	assert_false(_menu(plain).has("Raise the Holy Symbol of Ravenkind."), "no symbol, no such way")
	assert_true(_menu(plain).has("Leave her."), "leaving her is always there")
	st.party[0].add_item(HOLY_SYMBOL)
	var beats := _drive(st, START, ["Raise the Holy Symbol"])
	assert_true(_said(beats, "leans back from Ireena"), "the flames lean away from her")
	_woken(st, "the Holy Symbol")


func test_a_clerics_faith_wakes_her() -> void:
	var st := _held(_party())
	var beats := _drive(st, START, ["Stand before her and call on your god"])
	assert_true(_said(beats, "hold your faith up"), "a small honest light")
	_woken(st, "a cleric's faith")
	var without := _held(_no_cleric())
	assert_false(_menu(_drive(without, START)).has("Stand before her and call on your god."), "no cleric, no such way")


func test_the_sunsword_wakes_her() -> void:
	var st := _held(_no_cleric())
	assert_false(_menu(_drive(st, START)).has("Draw the Sunsword."), "not without the sword")
	st.party[0].add_item("sunsword")
	var beats := _drive(st, START, ["Draw the Sunsword"])
	assert_true(_said(beats, "loses every shadow"), "the chapel loses every shadow")
	_woken(st, "the Sunsword")


## A warding prayer and the plea are checks: some seed passes each (and a miss only brings the menu back).
func test_a_warding_prayer_and_the_plea_wake_her() -> void:
	for pick: Array in [["Speak a warding prayer", "old warding words"], ["Ireena. Remember", "I know my name"]]:
		var woke_by_it := false
		for seed_value in 40:
			var st := _held(_party())
			var beats := _drive(st, START, [pick[0] as String, "Leave her"], seed_value)
			if bool(st.get_flag("ireena_held_by_strahd", false)):
				continue
			woke_by_it = true
			assert_true(_said(beats, pick[1] as String), "%s: woken by its own scene" % pick[0])
			_woken(st, pick[0] as String)
			break
		assert_true(woke_by_it, "%s wakes her for some roll" % pick[0])


# --- The two pictures --------------------------------------------------------------------------------------------------

static func _pictures(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "cutscene":
			out.append(str(b.get("id", "")))
	return out


func test_the_first_sight_and_the_waking_each_have_a_picture() -> void:
	var st := _held(_party())
	var beats := _drive(st, START, ["Stand before her and call on your god"])
	assert_eq(_pictures(beats), ["ireena_altar", "ireena_woken", ""] as Array[String], "the altar, her waking, then the picture goes")
	for b in beats:
		if str(b.get("kind", "")) == "cutscene" and str(b.get("id", "")) != "":
			assert_true(ResourceLoader.exists(str(b.get("image", ""))), "%s has its picture" % b["id"])
	var again := _drive(st, START, ["Leave her"])
	assert_eq(_pictures(again), [] as Array[String], "she is gone from the chapel; a later visit has no first picture")
	var held := _held(_party())
	_drive(held, START, ["Leave her"])
	assert_eq(_pictures(_drive(held, START, ["Leave her"])), [] as Array[String], "a second visit to a held Ireena shows no altar picture")


# --- When it goes wrong ------------------------------------------------------------------------------------------------

func test_one_misstep_costs_time_and_brings_the_menu_back() -> void:
	var st := _held(_party())
	var before := _clock(st)
	var beats := _drive(st, "castle_ravenloft/chapel_ireena:ward_failed")
	assert_true(_said(beats, "small, obedient step"), "a step toward the altar")
	assert_true(_menu(beats).has("Leave her."), "the menu comes back")
	assert_eq(int(st.get_flag("ireena_chapel_pull", 0)), 1)
	assert_eq(_clock(st) - before, 10, "ten minutes lost")
	assert_true(bool(st.get_flag("ireena_held_by_strahd", false)), "still held")


func test_two_missteps_let_the_trance_hold_and_the_visit_ends() -> void:
	var st := _held(_party())
	st.set_flag("ireena_chapel_pull", 1)
	var before := _clock(st)
	var beats := _drive(st, "castle_ravenloft/chapel_ireena:woke_failed")
	assert_eq(str(beats[-1].get("kind", "")), "end", "the conversation ends")
	assert_true(_said(beats, "Our visitor likes the room quiet"), "she turns back to the altar")
	assert_eq(_clock(st) - before, 40, "forty minutes lost")
	assert_eq(int(st.get_flag("ireena_chapel_pull", 0)), 0, "the next visit starts fresh")
	assert_true(bool(st.get_flag("ireena_held_by_strahd", false)), "she is still his")
	assert_false("ireena" in st.guest_ids)
	# Nothing is taken from the party, and the way back stays open.
	assert_true(_standing(st, "ireena").size() > 0, "she is there on another visit")


func test_leaving_her_changes_nothing_and_a_second_visit_opens_differently() -> void:
	var st := _held(_party())
	var first := _drive(st, START, ["Leave her"])
	assert_true(_said(first, "Candles burn all around the altar"), "the first sight")
	assert_true(bool(st.get_flag("ireena_chapel_seen", false)))
	assert_true(bool(st.get_flag("ireena_held_by_strahd", false)), "still held")
	assert_false("ireena" in st.guest_ids)
	var second := _drive(st, START, ["Leave her"])
	assert_false(_said(second, "Candles burn all around the altar"), "not the first sight again")
	assert_true(_said(second, "burned lower"), "the candles are lower")


# --- The rest of the castle after she is out -------------------------------------------------------------------------

func test_ismark_is_glad_when_he_has_come_up_with_the_party() -> void:
	var with_ismark := _held(_party())
	with_ismark.add_guest("ismark")
	assert_true(_spoke(_drive(with_ismark, "castle_ravenloft/chapel_ireena:woken"), "ismark"), "her brother says his piece")
	var alone := _held(_party())
	assert_false(_spoke(_drive(alone, "castle_ravenloft/chapel_ireena:woken"), "ismark"), "and only when he is there")


func test_with_her_out_the_parley_treats_her_as_a_guest_not_as_his_prisoner() -> void:
	var st := _held(_party())
	_drive(st, START, ["Stand before her and call on your god"])
	var beats := _drive(st, "strahd/final:parley", ["We came to end you"])
	assert_true(_said(beats, "You came home"), "he greets her as she stands there")
	assert_false(_said(beats, "dressing for dinner"), "and does not say she is upstairs")
	assert_true(_menu(beats).has("Take her, then. Let us go."), "she can still be given up, as one who travels")
