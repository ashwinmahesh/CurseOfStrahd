extends TestCase
## Ireena's errands (Story Allies Presence Plan, package I2; narrative/allies/ireena_errands.dialogue, docs/story/side_quests.md).
## What she asks of the party once the check-in is had: a sprig for her father's grave (Flowers for Father, `flowers_for_kolyan`),
## three sword lessons (no quest), What He Wants With Me (`what_he_wants`: the Tome read with her, Marina's statue told to her,
## then the way to Krezk) and Strahd's three letters to her. Everything is opened from the check-in's menu by one option, only
## side flags and the two side quests move, and no conversation is left open.

const HUB := "allies/ireena:checkin"
const GRAVE := "allies/ireena_errands:grave"
const BYE := "Keep safe until we get back."
const MOVE_ON := "Let's keep moving."
const TALK := "There is something we wanted to speak with you about."
const SIDE_FLAGS := "res://data/flags/allies_ireena.json"
const ERRANDS := "res://narrative/allies/ireena_errands.dialogue"
const FLOWERS_ASK := "You have something in your hand."
const REPORT_ASK := "We went by the churchyard"
const HERS := "You look as though you have something to ask us."
const LESSON_AGAIN := "Have you got a moment for another sword lesson?"
const TOME_ASK := "We have the book he wrote."
const STATUE_ASK := "We found a white stone statue"
const LETTER_ASK := "What is that letter in your hand?"
const TAKE_BLADE := "Take a practice blade."
const WANTS_AGREE := "If we find his book"
const KREZK_YES := "We'll take you to the pool in Krezk."
const KREZK_LATER := "Not yet. The road to Krezk"


func after_each() -> void:
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


static func _ids(a: String, b: String, c: String, d: String) -> Array[String]:
	var out: Array[String] = [a, b, c, d]
	return out


## A party with a Fighter (Ilse), a rogue, a cleric and a wizard at level 8.
func _fighters() -> StoryState:
	return _party(_ids("ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"), 8)


## A party with nobody who can teach a blade: a rogue, a cleric and two wizards.
func _no_teacher(level: int = 8) -> StoryState:
	return _party(_ids("tamsin_tealeaf", "hedda_ironvow", "silvain_aster", "ratatoille"), level)


func _party(ids: Array[String], level: int) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(Pregens.build(id, level))
	return st


## Ireena where `place` says (the inn, the church, Krezk, the mansion once declined, or on the road), already checked on once
## there, so that the first-visit trust of the check-in is spent and only the errands' own trust shows.
func _at(st: StoryState, place: String) -> StoryState:
	match place:
		"inn":
			st.set_flag("ireena_sanctuary", "inn")
		"church":
			st.set_flag("ireena_sanctuary", "st_andrals")
		"krezk":
			st.set_flag("ireena_in_krezk")
		"mansion":
			st.set_flag("ireena_escort", "declined")
		"road":
			st.add_guest("ireena")
	st.set_flag("ireena_visits_" + place, 1)
	return st


func _play(st: StoryState, ref: String, script: Array[String] = [], seed_value: int = 1) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(seed_value))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var at := 0
	for i in 600:
		beats.append(b)
		var kind := str(b.get("kind", ""))
		if kind == "end":
			break
		if kind == "options":
			if at >= script.size():
				break
			var pick := -1
			var opts := b["options"] as Array
			for j in opts.size():
				var o := opts[j] as Dictionary
				if pick < 0 and bool(o.get("enabled", true)) and str(o["text"]).begins_with(script[at]):
					pick = j
			if pick < 0:
				fail("'%s' is not offered (menu: %s)" % [script[at], str(_texts(b))])
				break
			at += 1
			b = r.choose(pick)
		else:
			b = r.next()
	return beats


static func _texts(options_beat: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for o: Variant in options_beat["options"] as Array:
		out.append(str((o as Dictionary)["text"]))
	return out


static func _menus(beats: Array[Dictionary]) -> Array:
	var out: Array = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			out.append(_texts(b))
	return out


## Whether any spoken or narrated line has `words`.
static func _said(beats: Array[Dictionary], words: String) -> bool:
	for b in beats:
		if str(b.get("kind", "")) != "options" and str(b.get("text", "")).contains(words):
			return true
	return false


## Whether a menu (a list of option texts) has an option that begins `prefix`.
static func _offers(menu: Array, prefix: String) -> bool:
	return menu.any(func(t: String) -> bool: return t.begins_with(prefix))


static func _ended(beats: Array[Dictionary]) -> bool:
	return not beats.is_empty() and str(beats[-1].get("kind", "")) == "end"


## The first menu of a check-in that says goodbye at once.
func _first_menu(st: StoryState) -> Array:
	return _menus(_play(st, HUB, [_bye(st)]))[0] as Array


func _bye(st: StoryState) -> String:
	return MOVE_ON if "ireena" in st.guest_ids else BYE


## A check-in that takes `picks` and then says goodbye.
func _visit(st: StoryState, picks: Array[String], seed_value: int = 1) -> Array[Dictionary]:
	var script: Array[String] = []
	script.append_array(picks)
	script.append(_bye(st))
	return _play(st, HUB, script, seed_value)


func _picks(a: String = "", b: String = "", c: String = "") -> Array[String]:
	var out: Array[String] = []
	for s: String in [a, b, c]:
		if s != "":
			out.append(s)
	return out


func _stage(st: StoryState, quest: String) -> String:
	return st.quest_stage(quest)


func _trust(st: StoryState) -> int:
	return int(st.get_flag("ireena_trust", 0))


func _lessons(st: StoryState) -> int:
	return int(st.get_flag("ireena_lessons", 0))


## The first seed in 1..80 for which a fresh state from `builder`, played through `picks`, ends with `want` lessons landed.
func _seed_for_lessons(builder: Callable, picks: Array[String], want: int) -> int:
	for s in range(1, 81):
		var st := builder.call() as StoryState
		_visit(st, picks, s)
		if _lessons(st) == want:
			return s
	fail("no seed in 1..80 leaves %d lessons for %s" % [want, str(picks)])
	return 1


func _inspired(st: StoryState) -> bool:
	for c in st.party:
		if c.heroic_inspiration:
			return true
	return false


# --- The one option into all of it -----------------------------------------------------------------------------------------

func test_the_check_in_offers_the_talk_only_when_there_is_something_to_talk_about() -> void:
	var st := _at(_no_teacher(), "inn")
	assert_false(_first_menu(st).has(TALK), "nothing to say: no option")
	st.set_flag("burgomaster_buried")
	assert_true(_first_menu(st).has(TALK), "her sprig is on offer once her father is buried")
	var road := _at(_no_teacher(), "road")
	road.set_flag("burgomaster_buried")
	assert_false(_first_menu(road).has(TALK), "with the party on the road she has no grave to send them to")
	var mansion := _at(_no_teacher(), "mansion")
	mansion.set_flag("burgomaster_buried")
	assert_false(_first_menu(mansion).has(TALK), "and in her own mansion she can go herself")


func test_the_sprig_is_offered_at_each_refuge_and_the_visit_ends() -> void:
	for place: String in ["inn", "church", "krezk"]:
		var st := _at(_no_teacher(), place)
		st.set_flag("burgomaster_buried")
		var beats := _visit(st, _picks(TALK, FLOWERS_ASK, "Give us the rosemary"))
		assert_eq(_stage(st, "flowers_for_kolyan"), "given", place + ": she gives the sprig")
		assert_true(_ended(beats), place + ": the visit ends")
		assert_false(_first_menu(st).has(TALK), place + ": nothing else to say while the sprig is out")


# --- Flowers for Father ------------------------------------------------------------------------------------------------------

func test_she_asks_for_the_sprig_and_the_party_can_put_it_off() -> void:
	var st := _at(_no_teacher(), "church")
	st.set_flag("burgomaster_buried")
	var beats := _visit(st, _picks(TALK, FLOWERS_ASK, "Keep it for now."))
	assert_true(_said(beats, "pressed this sprig of rosemary"), "she shows the sprig")
	assert_true(_said(beats, "Say it plainly"), "and wants it said plainly")
	assert_eq(_stage(st, "flowers_for_kolyan"), "", "put off: the quest has not begun")
	assert_true(_ended(beats))
	assert_true(_first_menu(st).has(TALK), "and the ask is still there next time")
	var took := _visit(st, _picks(TALK, FLOWERS_ASK, "Give us the rosemary"))
	assert_true(_said(took, "kitchen smoke"), "the sprig changes hands")
	assert_eq(_stage(st, "flowers_for_kolyan"), "given")


func test_the_grave_takes_the_sprig_and_otherwise_is_his_old_grave() -> void:
	var st := _at(_no_teacher(), "inn")
	st.set_flag("burgomaster_buried")
	var plain := _play(st, GRAVE)
	assert_true(_said(plain, "Fresh earth, a board with his name burned into it"), "no sprig: the grave as it always was")
	assert_eq(_stage(st, "flowers_for_kolyan"), "", "and nothing moves")
	st.set_quest_stage("flowers_for_kolyan", "given")
	var laid := _play(st, GRAVE)
	assert_true(_said(laid, "set the dry rosemary"), "with the sprig: it is laid")
	assert_true(_ended(laid))
	assert_eq(_stage(st, "flowers_for_kolyan"), "laid")
	assert_true(_said(laid, "dry weeds"), "Ismark stayed behind: he is there")
	assert_true(bool(st.get_flag("ireena_ismark_at_grave", false)), "and she can be told so")
	assert_false(_said(laid, "gruff, impatient voice"), "no Kolyan unless he was once spoken to")
	var again := _play(st, GRAVE)
	assert_true(_said(again, "Fresh earth, a board with his name burned into it"), "laid once: his old grave again")


func test_ismark_is_at_the_grave_only_if_he_stayed() -> void:
	for flag: String in ["ismark_guards_ireena", "ismark_in_krezk", "ismark_joins_escort"]:
		var st := _at(_no_teacher(), "inn")
		st.set_quest_stage("flowers_for_kolyan", "given")
		st.set_flag(flag)
		var beats := _play(st, GRAVE)
		assert_false(_said(beats, "dry weeds"), flag + ": he is with her, not at the grave")
		assert_false(bool(st.get_flag("ireena_ismark_at_grave", false)), flag + ": so he is not there to report")
		assert_eq(_stage(st, "flowers_for_kolyan"), "laid", flag + ": the sprig is laid all the same")
	var guest := _at(_no_teacher(), "inn")
	guest.set_quest_stage("flowers_for_kolyan", "given")
	guest.add_guest("ismark")
	assert_false(_said(_play(guest, GRAVE), "dry weeds"), "travelling with the party, he isn't at the grave either")


func test_kolyan_has_a_word_if_he_was_once_spoken_to_at_his_grave() -> void:
	var st := _at(_no_teacher(), "inn")
	st.set_quest_stage("flowers_for_kolyan", "given")
	st.set_flag("kolyan_spoke")
	var beats := _play(st, GRAVE)
	assert_true(_said(beats, "gruff, impatient voice"), "the Narrator recalls the voice")
	assert_true(_said(beats, "see that my girl eats a hot meal"), "and Kolyan says his piece")
	assert_true(_ended(beats))


func test_a_raised_kolyan_takes_the_grave_off_the_errand() -> void:
	var st := _at(_no_teacher(), "inn")
	st.set_quest_stage("flowers_for_kolyan", "given")
	st.set_flag("kolyan_raised")
	var beats := _play(st, GRAVE)
	assert_eq(_stage(st, "flowers_for_kolyan"), "given", "the old grave plays: the sprig isn't laid")
	assert_false(_said(beats, "set the dry rosemary"))
	var talk := _visit(st, _picks(TALK))
	assert_true(_said(talk, "walking about again"), "she keeps the sprig")
	assert_eq(_stage(st, "flowers_for_kolyan"), "alive")
	assert_true(_ended(talk))
	assert_false(_first_menu(st).has(TALK), "and that is the end of it")
	var fresh := _at(_no_teacher(), "inn")
	fresh.set_flag("burgomaster_buried")
	fresh.set_flag("kolyan_raised")
	assert_false(_first_menu(fresh).has(TALK), "if he was raised first, she never sends a sprig")


func test_the_report_has_three_answers_and_each_ends_in_her_story() -> void:
	var cases: Array[Array] = [
		["Raw earth", "tidy lawn", false],
		["It looked peaceful", "terrible liars", false],
		["Ismark was there", "arguing with the crows", true],
	]
	for c in cases:
		var st := _at(_no_teacher(), "church")
		st.set_quest_stage("flowers_for_kolyan", "laid")
		st.set_flag("ireena_ismark_at_grave", c[2] as bool)
		var beats := _visit(st, _picks(TALK, REPORT_ASK, c[0] as String))
		assert_true(_said(beats, c[1] as String), "%s: her reaction" % c[0])
		assert_true(_said(beats, "thunder off the mountain"), "%s: and the story she has never told" % c[0])
		assert_eq(_stage(st, "flowers_for_kolyan"), "done", "%s: the quest is done" % c[0])
		assert_eq(_trust(st), 1, "%s: she trusts them a little more" % c[0])
		assert_true(_inspired(st), "%s: Heroic Inspiration for the party" % c[0])
		assert_true(_ended(beats))
	var no_ismark := _at(_no_teacher(), "church")
	no_ismark.set_quest_stage("flowers_for_kolyan", "laid")
	var menu := _menus(_play(no_ismark, HUB, _picks(TALK, REPORT_ASK)))[2] as Array
	assert_false(menu.any(func(t: String) -> bool: return t.begins_with("Ismark was there")), "no Ismark answer when he wasn't there")
	assert_eq(menu.size(), 2, "just the truth and the kind lie")


func test_the_errand_does_not_come_back_once_it_is_done() -> void:
	var st := _at(_no_teacher(), "inn")
	st.set_flag("burgomaster_buried")
	_visit(st, _picks(TALK, FLOWERS_ASK, "Give us the rosemary"))
	_play(st, GRAVE)
	_visit(st, _picks(TALK, REPORT_ASK, "Raw earth"))
	assert_eq(_stage(st, "flowers_for_kolyan"), "done")
	var after := _first_menu(st)
	assert_false(after.has(TALK), "nothing more from the errand")


# --- The lessons -------------------------------------------------------------------------------------------------------------

func test_lessons_start_with_the_second_check_in_and_need_someone_to_teach() -> void:
	var st := _at(_fighters(), "church")
	assert_false(_first_menu(st).has(TALK), "the first check-in is only hello")
	assert_true(_first_menu(st).has(TALK), "the second brings her ask")
	for who: String in ["godrick_pendlebrook", "thistle"]:
		var other := _at(_party(_ids("tamsin_tealeaf", "hedda_ironvow", who, "silvain_aster"), 8), "church")
		other.set_flag("ireena_checkins", 1)
		assert_true(_first_menu(other).has(TALK), "%s can teach her" % who)
	var none := _at(_no_teacher(), "church")
	none.set_flag("ireena_checkins", 3)
	assert_false(_first_menu(none).has(TALK), "a rogue, a cleric and two wizards cannot")
	none.add_guest("ezmerelda")
	assert_true(_first_menu(none).has(TALK), "but Ezmerelda can, if she is along")
	var road := _at(_fighters(), "road")
	road.set_flag("ireena_checkins", 1)
	assert_true(_first_menu(road).has(TALK), "and Ireena asks on the road as well")


func test_her_first_ask_can_be_put_off_and_then_the_party_offers_the_lesson_itself() -> void:
	var st := _at(_fighters(), "church")
	st.set_flag("ireena_checkins", 1)
	var beats := _visit(st, _picks(TALK, HERS, "Not right now."))
	assert_true(_said(beats, "You keep me out of the fighting"), "she asks")
	assert_true(bool(st.get_flag("ireena_lesson_asked", false)), "the ask is made, taken or not")
	assert_eq(_lessons(st), 0)
	assert_true(_ended(beats))
	var asks := _menus(_play(st, HUB, _picks(TALK)))
	assert_true((asks[1] as Array).has(LESSON_AGAIN), "next visit the party's own offer is there")
	assert_false((asks[1] as Array).has(HERS), "and she doesn't ask the first time twice")


func test_a_lesson_that_lands_counts_and_one_that_doesnt_waits_for_the_next_check_in() -> void:
	var builder := func() -> StoryState:
		var st := _at(_no_teacher(1), "church")
		st.add_guest("ezmerelda")
		st.set_flag("ireena_checkins", 1)
		return st
	var picks := _picks(TALK, HERS, TAKE_BLADE)
	var fail_seed := _seed_for_lessons(builder, picks, 0)
	var pass_seed := _seed_for_lessons(builder, picks, 1)
	var st := builder.call() as StoryState
	var minutes := st.total_minutes()
	var beats := _visit(st, picks, fail_seed)
	assert_eq(_lessons(st), 0, "a lesson that failed doesn't count")
	assert_true(bool(st.get_flag("ireena_lesson_tried", false)), "but it was tried")
	assert_true(_said(beats, "Loosen your thumb"), "Ezmerelda has a word")
	assert_true(_said(beats, "balanced by a blind smith"), "and Ireena takes it dryly")
	assert_true(st.total_minutes() >= minutes + 30, "the lesson takes half an hour")
	assert_eq(_trust(st), 0, "a lesson that didn't land adds no trust")
	assert_true(_ended(beats))
	var one_visit := _menus(_play(builder.call() as StoryState, HUB, picks, fail_seed))
	assert_false((one_visit[one_visit.size() - 1] as Array).has(TALK), "after a lesson that didn't land the menu has nothing more: no second lesson in the same check-in")
	assert_true(_first_menu(st).has(TALK), "but the next check-in offers it again")
	var landed := builder.call() as StoryState
	var landed_beats := _visit(landed, picks, pass_seed)
	assert_eq(_lessons(landed), 1, "a lesson that landed counts")
	assert_eq(_trust(landed), 1, "and adds one to her trust")
	assert_true(_said(landed_beats, "It pulls less at the wrist"), "grip and footing")


func test_the_three_lessons_in_order_and_the_third_chosen() -> void:
	var scenes := {1: "widen her stance", 2: "watch your chest", 3: "hundred times"}
	for n: int in [1, 2, 3]:
		var builder := func() -> StoryState:
			var st := _at(_fighters(), "inn")
			st.set_flag("ireena_lesson_asked")
			st.set_flag("ireena_lessons", n - 1)
			st.set_flag("ireena_checkins", 1)
			return st
		var picks := _picks(TALK, LESSON_AGAIN, "One cut, over and over" if n == 3 else "")
		var seed_value := _seed_for_lessons(builder, picks, n)
		var st := builder.call() as StoryState
		var beats := _visit(st, picks, seed_value)
		assert_eq(_said(beats, "Show me the next part"), n > 1, "lesson %d: she asks for the next part once there has been one" % n)
		assert_eq(_lessons(st), n, "lesson %d lands" % n)
		assert_true(_said(beats, scenes[n] as String), "lesson %d: its scene (%s)" % [n, scenes[n]])
		assert_eq(_trust(st), 1, "lesson %d: a little trust" % n)
		assert_true(_ended(beats))
	var third := _at(_fighters(), "inn")
	third.set_flag("ireena_lesson_asked")
	third.set_flag("ireena_lessons", 2)
	third.set_flag("ireena_checkins", 1)
	var menus := _menus(_play(third, HUB, _picks(TALK, LESSON_AGAIN)))
	var choices := menus[menus.size() - 1] as Array
	assert_true(choices.has("One cut, over and over, until your arm knows it.") and choices.has("How to take a fall and come back up with your blade.")
		and choices.has("Save the last lesson for another day."), "the third lesson is chosen: drill, fall, or another day (%s)" % str(choices))


func test_the_fall_the_last_word_and_putting_the_last_lesson_off() -> void:
	var builder := func() -> StoryState:
		var st := _at(_fighters(), "inn")
		st.set_flag("ireena_lesson_asked")
		st.set_flag("ireena_lessons", 2)
		st.set_flag("ireena_checkins", 1)
		st.add_guest("ezmerelda")
		return st
	var picks := _picks(TALK, LESSON_AGAIN, "How to take a fall")
	var seed_value := _seed_for_lessons(builder, picks, 3)
	var fall := builder.call() as StoryState
	var fell := _visit(fall, picks, seed_value)
	assert_true(_said(fell, "ground is actually there"), "the fall: the quiet line")
	assert_true(_said(fell, "sack of turnips"), "with Ezmerelda's aside")
	assert_true(_said(fell, "proper bout"), "and her word after the last lesson")
	assert_eq(_lessons(fall), 3)
	assert_false(_first_menu(fall).has(TALK), "after three there are no more")
	var later := builder.call() as StoryState
	var put_off := _visit(later, _picks(TALK, LESSON_AGAIN, "Save the last lesson"))
	assert_eq(_lessons(later), 2, "another day: nothing counted")
	assert_false(bool(later.get_flag("ireena_lesson_tried", false)), "and nothing tried")
	assert_true(_ended(put_off))


func test_a_failed_lesson_can_be_tried_again_even_the_one_that_reads_her_tells() -> void:
	var builder := func() -> StoryState:
		var st := _at(_no_teacher(1), "krezk")
		st.add_guest("ezmerelda")
		st.set_flag("ireena_lesson_asked")
		st.set_flag("ireena_lessons", 1)
		st.set_flag("ireena_checkins", 1)
		return st
	var picks := _picks(TALK, LESSON_AGAIN)
	var fail_seed := _seed_for_lessons(builder, picks, 1)
	var st := builder.call() as StoryState
	var beats := _visit(st, picks, fail_seed)
	assert_eq(_lessons(st), 1, "the second lesson did not land")
	assert_true(_said(beats, "send a herald ahead of the blow"), "she says so")
	assert_true(_first_menu(st).has(TALK), "the next check-in offers it again: a roll in the scene, not an option, so nothing is spent")
	assert_true((_menus(_play(st, HUB, _picks(TALK)))[1] as Array).has(LESSON_AGAIN), "with the same offer")


# --- What He Wants With Me ---------------------------------------------------------------------------------------------------

func _wants(place: String = "inn") -> StoryState:
	var st := _at(_no_teacher(), place)
	st.set_flag("ireena_heard_dreams")
	st.set_flag("ireena_checkins", 1)
	return st


## A state with her ask accepted: the locket made her wonder, the Tome is carried, and the party has been to Berez.
func _asked(place: String = "inn") -> StoryState:
	var st := _wants(place)
	st.set_flag("tamsin_locket_recognized")
	st.party[0].add_item("tome_of_strahd")
	st.visited["berez"] = true
	_visit(st, _picks(TALK, HERS, WANTS_AGREE))
	return st


func test_she_asks_only_once_the_dream_is_told_and_something_has_made_her_wonder() -> void:
	var st := _at(_no_teacher(), "inn")
	st.set_flag("ireena_checkins", 1)
	st.set_flag("tamsin_locket_recognized")
	assert_false(_first_menu(st).has(TALK), "a locket and no dream told")
	assert_false(_first_menu(_wants()).has(TALK), "a dream and nothing to wonder about")
	var triggers: Array[String] = ["tamsin_locket_recognized", "abbot_saw_ireena", "ireena_saw_marina", "ireena_falls_memory",
		"ireena_pool_vision", "item:tome_of_strahd", "visited:berez"]
	for t in triggers:
		var one := _wants()
		if t.begins_with("item:"):
			one.party[0].add_item(t.trim_prefix("item:"))
		elif t.begins_with("visited:"):
			one.visited[t.trim_prefix("visited:")] = true
		else:
			one.set_flag(t)
		assert_true(_first_menu(one).has(TALK), "%s: the ask is open" % t)


func test_the_ask_has_two_voices_and_the_party_can_put_it_off() -> void:
	var plain := _wants()
	plain.set_flag("tamsin_locket_recognized")
	var beats := _visit(plain, _picks(TALK, HERS, WANTS_AGREE))
	assert_true(_said(beats, "woman who was dead before I was born"), "without the pool")
	assert_true(_said(beats, "dream of the dark water"), "she refers back to her dream")
	assert_eq(_stage(plain, "what_he_wants"), "asked")
	assert_true(_ended(beats))
	var pool := _wants()
	pool.set_flag("ireena_pool_vision")
	var pool_beats := _visit(pool, _picks(TALK, HERS, WANTS_AGREE))
	assert_true(_said(pool_beats, "pieces of a house I never lived in"), "after the pool")
	assert_eq(_stage(pool, "what_he_wants"), "asked")
	var later := _wants()
	later.set_flag("tamsin_locket_recognized")
	_visit(later, _picks(TALK, HERS, "Leave that for now."))
	assert_eq(_stage(later, "what_he_wants"), "", "put off: the quest has not begun")
	assert_true(bool(later.get_flag("ireena_wants_later", false)))
	assert_true(_first_menu(later).has(TALK), "and the ask comes back")


func test_a_put_off_ask_lets_the_first_lesson_through() -> void:
	var st := _at(_fighters(), "inn")
	st.set_flag("ireena_heard_dreams")
	st.set_flag("tamsin_locket_recognized")
	st.set_flag("ireena_checkins", 1)
	var first := _visit(st, _picks(TALK, HERS, "Leave that for now."))
	assert_true(_said(first, "dream of the dark water"), "the book and the faces come first")
	var second := _visit(st, _picks(TALK, HERS, "Not right now."))
	assert_true(_said(second, "You keep me out of the fighting"), "the party put it off, so this time it is the lesson")
	assert_false(bool(st.get_flag("ireena_wants_later", false)), "and the wish comes first again after")
	var third := _visit(st, _picks(TALK, HERS, WANTS_AGREE))
	assert_true(_said(third, "dead before I was born"), "the third time: the book again")


func test_the_book_read_to_her_and_the_statue_told_in_either_order() -> void:
	for first: String in ["book", "statue"]:
		var st := _asked()
		var minutes := st.total_minutes()
		var one: Array[Dictionary]
		var two: Array[Dictionary]
		if first == "book":
			one = _visit(st, _picks(TALK, TOME_ASK))
			assert_eq(_stage(st, "what_he_wants"), "tome_read", "book first: the journal moves")
			assert_true(st.total_minutes() >= minutes + 180, "reading takes hours")
			assert_true(_said(one, "He writes like a bailiff"), "the book")
			assert_true(_said(one, "water at the bottom of the dream"), "the fall")
			assert_true(_said(one, "small, greedy liar"), "her verdict")
			assert_false(bool(st.get_flag("ireena_knows_tatyana", false)), "not yet")
			two = _visit(st, _picks(TALK, STATUE_ASK))
		else:
			one = _visit(st, _picks(TALK, STATUE_ASK))
			assert_eq(_stage(st, "what_he_wants"), "statue_told", "statue first: the journal moves")
			assert_true(_said(one, "a monument that breathes"), "the statue")
			assert_false(bool(st.get_flag("ireena_knows_tatyana", false)), "not yet")
			two = _visit(st, _picks(TALK, TOME_ASK))
		assert_eq(_stage(st, "what_he_wants"), "knows", first + " first: and the second one finishes it")
		assert_true(bool(st.get_flag("ireena_knows_tatyana", false)), first + " first: she knows")
		assert_true(_said(two, "I am neither of them"), first + " first: her plain word")
		assert_eq(_trust(st), 1, first + " first: trust rose once")
		assert_true(_ended(one) and _ended(two), first + " first: both end")
		assert_false(bool(st.get_flag("ireena_pool_choice", false)), "the pool's choice is still the pool's")
		assert_false(_first_menu(st).has(TALK), first + " first: nothing left to bring her")


func test_the_scenes_wait_for_the_quest_the_book_and_the_trip() -> void:
	var st := _wants()
	st.set_flag("tamsin_locket_recognized")
	st.party[0].add_item("tome_of_strahd")
	st.visited["berez"] = true
	var before := _menus(_play(st, HUB, _picks(TALK)))[1] as Array
	assert_false(_offers(before, TOME_ASK) or _offers(before, STATUE_ASK), "before she has asked, nothing to read or tell")
	_visit(st, _picks(TALK, HERS, WANTS_AGREE))
	var after := _menus(_play(st, HUB, _picks(TALK)))[1] as Array
	assert_true(_offers(after, TOME_ASK) and _offers(after, STATUE_ASK), "after she has asked, both are on offer (%s)" % str(after))
	var poor := _wants()
	poor.set_flag("tamsin_locket_recognized")
	_visit(poor, _picks(TALK, HERS, WANTS_AGREE))
	assert_false(_first_menu(poor).has(TALK), "no book carried and no trip to Berez: nothing to bring her")


func test_the_vault_adds_the_girl_on_the_bier() -> void:
	var st := _asked()
	st.visited["berez_marinas_monument"] = true
	var beats := _visit(st, _picks(TALK, STATUE_ASK))
	assert_true(_said(beats, "a monument that breathes"))
	assert_true(_said(beats, "a white stone bier under a lace veil"), "the party tells her about the vault")
	assert_true(_said(beats, "the next body on a slab"), "and what she makes of it")
	var plain := _asked()
	assert_false(_said(_visit(plain, _picks(TALK, STATUE_ASK)), "lace veil"), "without the vault there is no bier")


func test_a_statue_she_saw_herself_needs_no_telling() -> void:
	var st := _wants()
	st.set_flag("ireena_saw_marina")
	st.party[0].add_item("tome_of_strahd")
	_visit(st, _picks(TALK, HERS, WANTS_AGREE))
	assert_eq(_stage(st, "what_he_wants"), "statue_told", "she asked after seeing it: that half is done")
	var menu := _menus(_play(st, HUB, _picks(TALK)))[1] as Array
	assert_false(_offers(menu, STATUE_ASK), "no telling her what she saw")
	_visit(st, _picks(TALK, TOME_ASK))
	assert_eq(_stage(st, "what_he_wants"), "knows", "the book finishes it")
	var late := _wants("road")
	late.set_flag("tamsin_locket_recognized")
	late.party[0].add_item("tome_of_strahd")
	_visit(late, _picks(TALK, HERS, WANTS_AGREE))
	_visit(late, _picks(TALK, TOME_ASK))
	assert_eq(_stage(late, "what_he_wants"), "tome_read")
	late.set_flag("ireena_saw_marina")
	var done := _visit(late, _picks(TALK))
	assert_eq(_stage(late, "what_he_wants"), "knows", "she sees the statue after the book: she says it herself")
	assert_true(_said(done, "I am neither of them"))
	assert_true(_ended(done))


func test_when_the_pool_is_known_she_asks_to_be_taken_to_krezk() -> void:
	for place: String in ["inn", "church", "krezk", "mansion"]:
		var st := _asked(place)
		st.set_quest_stage("the_pool_of_the_white_sun", "rumored")
		_visit(st, _picks(TALK, TOME_ASK))
		_visit(st, _picks(TALK, STATUE_ASK, KREZK_LATER))
		assert_false("ireena" in st.guest_ids, place + ": 'not yet' leaves her where she is")
		var again := _asked(place)
		again.set_quest_stage("the_pool_of_the_white_sun", "rumored")
		_visit(again, _picks(TALK, TOME_ASK))
		var script := _picks(TALK, STATUE_ASK, KREZK_YES)
		if place == "mansion":
			script.append("Someone should stay")
		var beats := _play(again, HUB, script)
		assert_true(_said(beats, "pool in Krezk where the water turns white"), place + ": she asks")
		assert_true("ireena" in again.guest_ids, place + ": and joins, through the existing rejoin")
		assert_true(_ended(beats), place + ": the conversation ends")
		assert_false(bool(again.get_flag("ireena_pool_choice", false)), place + ": the pool's choice is untouched")
	var no_rumour := _asked()
	_visit(no_rumour, _picks(TALK, STATUE_ASK))
	assert_false(_said(_visit(no_rumour, _picks(TALK, TOME_ASK)), "pool in Krezk"), "no rumour of the pool, no ask")


# --- His letters -------------------------------------------------------------------------------------------------------------

func test_the_letters_come_one_at_a_time_in_the_story_s_order() -> void:
	var st := _at(_no_teacher(), "inn")
	assert_false(_first_menu(st).has(TALK), "none before his call")
	st.set_flag("strahd_window", "faith")
	assert_true(_first_menu(st).has(TALK))
	var one := _visit(st, _picks(TALK, LETTER_ASK, "Burn it."))
	assert_true(_said(one, "I've read it already"), "she shows the first")
	assert_true(_said(one, "did not come to the door"), "his words")
	assert_true(_said(one, "scrub bucket"), "and burns it")
	assert_true(bool(st.get_flag("ireena_heard_letter1", false)))
	assert_true(_ended(one))
	assert_false(_first_menu(st).has(TALK), "the second waits for the festival")
	st.set_flag("vallaki_backed", "neither")
	var two := _visit(st, _picks(TALK, LETTER_ASK, "Keep it."))
	assert_true(_said(two, "thoughts on the festival"), "the second")
	assert_true(_said(two, "somewhere dry"), "and she keeps it")
	assert_false(_first_menu(st).has(TALK), "the third waits for the dinner")
	st.set_flag("strahd_invitation", "declined")
	assert_true(_first_menu(st).has(TALK), "the invitation brings the third")


func test_no_letter_for_a_party_she_travels_with_or_for_a_woman_he_holds() -> void:
	var road := _at(_no_teacher(), "road")
	road.set_flag("strahd_window", "faith")
	assert_false(_first_menu(road).has(TALK), "on the road there is nobody to bring one to her")
	var held := _at(_no_teacher(), "inn")
	held.set_flag("strahd_window", "taken")
	held.set_flag("ireena_held_by_strahd")
	assert_false(_first_menu(held).has(TALK), "and none to a woman he holds")


func _third_letter_state() -> StoryState:
	var st := _at(_no_teacher(), "church")
	st.set_flag("strahd_window", "church")
	st.set_flag("ireena_heard_letter1")
	st.set_flag("vallaki_backed", "baron")
	st.set_flag("ireena_heard_letter2")
	st.set_flag("strahd_invitation", "accepted")
	return st


func test_the_third_letter_says_burned_and_an_insight_roll_finds_the_one_she_kept() -> void:
	var picks := _picks(TALK, LETTER_ASK, "You didn't burn that one.")
	var seen := -1
	var missed := -1
	for s in range(1, 81):
		var st := _third_letter_state()
		_visit(st, picks, s)
		var shared := bool(st.get_flag("ireena_secret_shared", false))
		if shared and seen < 0:
			seen = s
		if not shared and missed < 0:
			missed = s
		if seen > 0 and missed > 0:
			break
	assert_true(seen > 0 and missed > 0, "both outcomes turn up in the seeds (%d, %d)" % [seen, missed])
	var kept := _third_letter_state()
	var beats := _visit(kept, picks, seen)
	assert_true(_said(beats, "It's inside my cuff"), "she admits it")
	assert_true(_said(beats, "lift the window latch"), "she reads one line of it")
	assert_true(_said(beats, "Lay hold of me and pull me back"), "and asks them to stop HER")
	assert_true(bool(kept.get_flag("ireena_kept_letter", false)), "kept, as the game knows")
	assert_true(bool(kept.get_flag("ireena_secret_shared", false)))
	assert_eq(_trust(kept), 1, "and she trusts them with it")
	assert_true(_ended(beats))
	assert_false(_first_menu(kept).has(TALK), "told once")
	var lost := _third_letter_state()
	var lost_beats := _visit(lost, picks, missed)
	assert_true(_said(lost_beats, "Ash, I told you"), "missed: she holds her ground")
	assert_true(bool(lost.get_flag("ireena_kept_letter", false)), "still kept, whoever noticed (the finale reads it)")
	assert_false(bool(lost.get_flag("ireena_secret_shared", false)))
	assert_eq(_trust(lost), 0)
	assert_true(_ended(lost_beats))
	assert_false(_first_menu(lost).has(TALK), "and the letter is not told twice")
	for answer: String in ["Good. Better in the fire", "What did the third letter say"]:
		var other := _third_letter_state()
		var a := _visit(other, _picks(TALK, LETTER_ASK, answer))
		assert_true(bool(other.get_flag("ireena_kept_letter", false)), answer + ": the letter is told")
		assert_false(bool(other.get_flag("ireena_secret_shared", false)), answer + ": and the secret stays hers")
		assert_true(_ended(a), answer + ": it ends")
	var menus := _menus(_play(_third_letter_state(), HUB, _picks(TALK, LETTER_ASK)))
	assert_eq((menus[menus.size() - 1] as Array).size(), 3, "three ways to answer: the roll is not the only one")


# --- What it touches, and what it never says ---------------------------------------------------------------------------------

func test_the_errands_move_only_side_flags_and_their_two_quests() -> void:
	var registry: Dictionary = {}
	for f: Variant in ((JSON.parse_string(FileAccess.get_file_as_string(SIDE_FLAGS)) as Dictionary)["flags"] as Array):
		registry[str((f as Dictionary)["id"])] = true
	var st := _at(_fighters(), "inn")
	st.set_flag("pre_existing_story_flag")
	for k: String in ["burgomaster_buried", "ireena_heard_dreams", "tamsin_locket_recognized", "strahd_window", "vallaki_backed", "strahd_invitation"]:
		st.set_flag(k)
	st.party[0].add_item("tome_of_strahd")
	st.visited["berez"] = true
	st.set_quest_stage("the_pool_of_the_white_sun", "rumored")
	st.set_flag("ireena_checkins", 1)
	var before := st.flags.duplicate(true)
	_visit(st, _picks(TALK, FLOWERS_ASK, "Give us the rosemary"))
	_play(st, GRAVE)
	_visit(st, _picks(TALK, REPORT_ASK, "Raw earth"))
	_visit(st, _picks(TALK, HERS, WANTS_AGREE))
	_visit(st, _picks(TALK, TOME_ASK))
	_visit(st, _picks(TALK, STATUE_ASK, KREZK_LATER))
	_visit(st, _picks(TALK, LETTER_ASK, "Burn it."))
	_visit(st, _picks(TALK, LETTER_ASK, "Keep it."))
	_visit(st, _picks(TALK, LETTER_ASK, "Good. Better in the fire"))
	for i in 5:
		if _lessons(st) >= 3:
			break
		if not bool(st.get_flag("ireena_lesson_asked", false)):
			_visit(st, _picks(TALK, HERS, TAKE_BLADE))
		else:
			_visit(st, _picks(TALK, LESSON_AGAIN, "One cut, over and over" if _lessons(st) == 2 else ""))
	for k: String in st.flags.keys():
		if k.begins_with("_"):
			continue   # the engine's own marks (a roll spent, an inspiration given)
		if not before.has(k):
			assert_true(registry.has(k), "%s is a registered side flag" % k)
		elif not registry.has(k):
			assert_eq(st.flags[k], before[k], "%s, a story flag, is untouched" % k)
	assert_eq(st.quest_stage("the_pool_of_the_white_sun"), "rumored", "the pool's quest is the pool's")
	assert_false(bool(st.get_flag("ireena_pool_choice", false)))
	assert_eq(st.quest_stage("flowers_for_kolyan"), "done")
	assert_eq(st.quest_stage("what_he_wants"), "knows")


func test_her_words_here_are_hers_and_the_errands_file_is_clean() -> void:
	var file := FileAccess.get_file_as_string(ERRANDS)
	assert_false(file.contains("{name}"), "no line that couldn't be voiced")
	var spoken := 0
	for line in file.split("\n"):
		if line.begins_with("Ireena"):
			spoken += 1
			assert_true(line.begins_with("Ireena:") or line.begins_with("Ireena ["), "a malformed line: " + line)
			assert_false(line.to_lower().contains("strahd"), "she never says his name: " + line)
		elif line.begins_with("Strahd"):
			spoken += 1
			assert_true(line.begins_with("Strahd:"), "his lines take no mood: " + line)
		elif line.begins_with("Narrator") or line.begins_with("Ismark") or line.begins_with("Kolyan") or line.begins_with("interject"):
			spoken += 1
		assert_false(line.contains("—"), "plain punctuation: " + line)
	assert_true(spoken > 80, "the errands' lines are there (%d)" % spoken)
	var village := FileAccess.get_file_as_string("res://data/locations/village_of_barovia.json")
	assert_true(village.contains("\"dialogue\": \"allies/ireena_errands:grave\""), "the grave prop is the door to the sprig")
	assert_false(village.contains("\"dialogue\": \"village_of_barovia/kolyan:grave\""), "and plays his old grave when there is no sprig")
	for q: String in ["flowers_for_kolyan", "what_he_wants"]:
		assert_false(Compendium.shared().get_entry("quests", q).is_empty(), q + " is a quest")
	var hub := FileAccess.get_file_as_string("res://narrative/allies/ireena.dialogue")
	assert_true(hub.contains("allies/ireena_errands:prepare") and hub.contains("allies/ireena_errands:asks"), "the check-in hands over to the errands")
