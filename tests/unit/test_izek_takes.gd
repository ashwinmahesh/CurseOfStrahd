extends TestCase
## Izek comes for Ireena (Story Allies Presence Plan, package Z1; narrative/allies/izek_takes.dialogue, data/visits/izek.json,
## docs/story/izek_takes.md). While Izek is alive and does not know she is his sister, and she shelters at the Blue Water Inn
## or St. Andral's, one ally visit plays on three nights in Vallaki, each two days after the last: he stands under her window,
## he carries her to his room in the Baron's mansion, and if nobody has freed her she gets out alone. While she is "held" the
## refuges do not place her (nor Ismark), Strahd's three visits to her skip her, and the mansion places her in Izek's room.

const VISIT := "izek_takes_ireena"
const NIGHT := "allies/izek_takes:night"
const ROOM := "allies/izek_takes:room"
const ROOM_DAY := "allies/izek_takes:ireena_room"
const MANSION := "vallaki_burgomaster_mansion"
const INN := "vallaki_blue_water_inn"
const CHURCH := "vallaki_st_andrals"
const AT_INN := "vallaki/ireena:at_inn"
const AT_CHURCH := "vallaki/ireena:at_church"
const IN_THE_ROOM := "allies/izek_takes:ireena_room"
const NIGHT_HOUR := 22
const DAY_HOUR := 12
## What the conversations may change besides the story's own flags (data/flags/allies_izek.json and Ireena's trust).
const SIDE_FLAGS: Array[String] = ["izek_watching", "izek_took_ireena", "izek_holds_ireena", "izek_hold_ended", "izek_room_met", "ireena_trust"]


func _party(location: String = "vallaki", hour: int = NIGHT_HOUR) -> StoryState:
	return SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], 5, location, hour)


## Ireena left at `refuge` ("inn" or "st_andrals") after Izek had seen her.
func _left(st: StoryState, refuge: String = "inn") -> StoryState:
	st.set_flag("ireena_met")
	st.set_flag("izek_saw_ireena")
	st.set_flag("ireena_sanctuary", refuge)
	return st


## Izek has her in his room.
func _held(st: StoryState, refuge: String = "inn") -> StoryState:
	_left(st, refuge)
	st.set_flag("izek_watching")
	st.set_flag("izek_took_ireena")
	st.set_flag("izek_holds_ireena")
	return st


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _menu(beats):
		if t.contains(words):
			return true
	return false


func _ends(beats: Array[Dictionary]) -> bool:
	return not beats.is_empty() and str(beats[-1].get("kind", "")) == "end"


## The flags that differ between two copies of the story's flags (the visits' own memory aside).
static func _changed(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in after:
		if str(k) == "_strahd":
			continue
		if not before.has(k) or before[k] != after[k]:
			out.append(str(k))
	return out


## The visit's id that would play at `on` now ("" when none), without marking it.
static func _next(st: StoryState, location: String = "vallaki", on: String = "arrive") -> String:
	return str(StrahdPresence.find(st, on, {"location": location, "night": true}).get("id", ""))


func _later(st: StoryState, days: int) -> void:
	st.day += days


# --- When it comes -------------------------------------------------------------------------------------------------------

func test_three_nights_two_days_apart_the_omen_the_taking_the_escape() -> void:
	StrahdPresence.use({})
	var st := _left(_party())
	assert_true(StrahdPresence.due(st, "arrive", {"location": "vallaki", "night": false}).is_empty(), "never by day")
	var omen := StrahdPresence.due(st, "arrive", {"location": "vallaki", "night": true})
	assert_eq(str(omen.get("id", "")), VISIT)
	assert_true(StrahdPresence.is_ally(omen), "an ally's visit")
	assert_eq(str(StrahdPresence.begin(st, omen).get("dialogue", "")), NIGHT)
	assert_false(StrahdPresence.may_fight(omen), "words only: the party plays the rescue in the mansion")
	SideQuestPlay.play(st, NIGHT)
	assert_true(bool(st.get_flag("izek_watching", false)), "the first night: he is watching")
	assert_false(bool(st.get_flag("izek_took_ireena", false)), "nothing taken yet")
	_later(st, 1)
	assert_eq(_next(st), "", "a day later: too soon")
	_later(st, 1)
	assert_eq(_next(st), VISIT, "two days after the omen: the taking")
	assert_false(StrahdPresence.due(st, "rest", {"location": INN, "night": true}).is_empty(), "a night's rest at the inn brings it too")
	SideQuestPlay.play(st, NIGHT)
	assert_true(bool(st.get_flag("izek_took_ireena", false)))
	assert_true(bool(st.get_flag("izek_holds_ireena", false)), "she is in his room")
	_later(st, 1)
	assert_eq(_next(st), "", "he holds her for two days before she gets out")
	_later(st, 1)
	assert_eq(_next(st), VISIT, "two days after the taking: she is out")
	StrahdPresence.due(st, "arrive", {"location": "vallaki", "night": true})
	st.set_flag("ireena_trust", 3)
	SideQuestPlay.play(st, NIGHT)
	assert_false(bool(st.get_flag("izek_holds_ireena", false)), "free")
	assert_eq(str(st.get_flag("izek_hold_ended", "")), "escaped")
	assert_eq(int(st.get_flag("ireena_trust", 0)), 1, "the cost: two trust")
	_later(st, 5)
	assert_eq(_next(st), "", "three is all of it: he does not take her twice")


func test_it_waits_for_what_it_reads() -> void:
	StrahdPresence.use({})
	assert_eq(_next(_party()), "", "he has not seen her")
	var seen := _left(_party())
	assert_eq(_next(seen), VISIT, "seen, left at the inn")
	assert_eq(_next(_left(_party(), "st_andrals")), VISIT, "or at the church")
	assert_eq(_next(_left(_party(), "krezk")), "", "not in Vallaki")
	assert_eq(_next(_left(_party(), "with_party")), "", "travelling with the party")
	var guest := _left(_party())
	assert_true(guest.add_guest("ireena"))
	assert_eq(_next(guest), "", "a guest is not left anywhere")
	for flag: String in ["izek_dead", "izek_told_truth", "ireena_held_by_strahd"]:
		var st := _left(_party())
		st.set_flag(flag)
		assert_eq(_next(st), "", flag + ": no")
	var festival := _left(_party())
	festival.set_flag("festival_begun")
	assert_eq(_next(festival), "", "not while the festival goes on")
	festival.set_flag("festival_over")
	assert_eq(_next(festival), VISIT, "the festival is over")
	assert_eq(_next(_left(_party()), "vallaki_vistani_camp"), "", "only the square, the inn and the church")
	assert_eq(_next(_left(_party()), "vallaki_st_andrals"), VISIT, "the church is holy ground, and the visit names it")
	assert_eq(_next(_left(_party()), "vallaki", "travel"), "", "arriving or resting, not on the road")


func test_after_a_festival_the_baron_won_he_takes_her_the_first_night() -> void:
	StrahdPresence.use({})
	var st := _left(_party())
	st.set_flag("festival_begun")
	st.set_flag("festival_over")
	st.set_flag("vallaki_backed", "baron")
	st.set_flag("izek_spurned")
	assert_eq(_next(st), VISIT)
	SideQuestPlay.play(st, NIGHT, [], 1)
	assert_true(bool(st.get_flag("izek_holds_ireena", false)), "no omen first: the claim was refused, he does not wait")
	assert_false(bool(st.get_flag("izek_watching", false)))


func test_she_gets_out_even_in_the_middle_of_a_festival_and_it_ends_the_wait_for_good() -> void:
	StrahdPresence.use({})
	var st := _held(_party())
	st.set_flag("festival_begun")
	assert_eq(_next(st), VISIT, "held and the festival on: the escape still comes when it is due")
	var done := _held(_party())
	done.set_flag("izek_holds_ireena", false)
	assert_eq(_next(done), "", "freed by the party: nothing more")
	var dead := _held(_party())
	dead.set_flag("izek_dead")
	assert_eq(_next(dead), "", "Izek died: she is free without a word")


# --- Who brings the news -------------------------------------------------------------------------------------------------

func test_the_news_is_brought_by_the_innkeeper_the_priest_or_the_watch_and_says_which_refuge() -> void:
	var cases := [
		[INN, "inn", "Izek has been out there since dusk", "across from the inn"],
		[CHURCH, "st_andrals", "A threshold only keeps out the dead", "churchyard gate"],
		["vallaki", "inn", "strictly official", "across from the inn"],
		["vallaki", "st_andrals", "strictly official", "churchyard gate"],
	]
	for c: Array in cases:
		var st := _left(_party(str(c[0])), str(c[1]))
		var beats := SideQuestPlay.play(st, NIGHT)
		assert_true(_says(beats, str(c[2])), "omen at %s for %s: the right speaker" % [c[0], c[1]])
		assert_true(_says(beats, str(c[3])), "omen at %s for %s: the right place" % [c[0], c[1]])
		assert_true(_ends(beats))
	var taken := [
		[INN, "inn", "Third watch."],
		[CHURCH, "st_andrals", "I was at prayers"],
		["vallaki", "inn", "Captain Izek carried"],
	]
	for c: Array in taken:
		var st := _left(_party(str(c[0])), str(c[1]))
		st.set_flag("izek_watching")
		var beats := SideQuestPlay.play(st, NIGHT)
		assert_true(_says(beats, str(c[2])), "taking at %s" % c[0])
		assert_true(_says(beats, "the Baron's mansion"), "and the news says where she is")
		assert_true(_says(beats, "off the great hall"), "which room")
	var escapes := [[INN, "She came back at first light"], [CHURCH, "She returned at dawn"], ["vallaki", "broke the Captain's nose"]]
	for c: Array in escapes:
		var st := _held(_party(str(c[0])))
		assert_true(_says(SideQuestPlay.play(st, NIGHT), str(c[1])), "escape at %s" % c[0])


func test_ismark_is_in_the_news_only_when_he_was_guarding_her() -> void:
	var guarding := _left(_party(INN))
	guarding.set_flag("izek_watching")
	guarding.set_flag("ismark_guards_ireena")
	assert_true(_says(SideQuestPlay.play(guarding, NIGHT), "shouting himself hoarse"), "turned back at the mansion gate")
	var alone := _left(_party(INN))
	alone.set_flag("izek_watching")
	assert_false(_says(SideQuestPlay.play(alone, NIGHT), "shouting himself hoarse"))


func test_each_stage_changes_only_its_own_flags() -> void:
	var omen := _left(_party(INN))
	var before := omen.flags.duplicate(true)
	SideQuestPlay.play(omen, NIGHT)
	assert_eq(_changed(before, omen.flags), ["izek_watching"] as Array[String])
	var taking := _left(_party(INN))
	taking.set_flag("izek_watching")
	before = taking.flags.duplicate(true)
	SideQuestPlay.play(taking, NIGHT)
	var moved := _changed(before, taking.flags)
	moved.sort()
	assert_eq(moved, ["izek_holds_ireena", "izek_took_ireena"] as Array[String], "the taking: she is held, once")
	var escape := _held(_party(INN))
	escape.set_flag("ireena_trust", 2)
	before = escape.flags.duplicate(true)
	SideQuestPlay.play(escape, NIGHT)
	var out := _changed(before, escape.flags)
	out.sort()
	assert_eq(out, ["ireena_trust", "izek_hold_ended", "izek_holds_ireena"] as Array[String], "the escape: her trust and his hold")
	assert_eq(int(escape.get_flag("ireena_trust", 0)), 0)


func test_the_story_bot_leaves_each_stage_by_its_exit() -> void:
	for place: String in [INN, CHURCH, "vallaki"]:
		var states: Array[StoryState] = [_left(_party(place)), _left(_party(place)), _held(_party(place))]
		states[1].set_flag("izek_watching")
		for st in states:
			var r := DialogueRunner.new(st, DiceRoller.new(5))
			assert_true(r.start(NIGHT))
			var b := r.next()
			for i in 20:
				if str(b["kind"]) == "options":
					break
				b = r.next()
			assert_eq(str(b["kind"]), "options", place + ": asks")
			var opts := b["options"] as Array
			assert_true(AllyVisitAnswer.exit_option(r, opts) >= 0, place + ": the bot has a way out")


# --- Where everyone stands -----------------------------------------------------------------------------------------------

func test_ireena_is_in_her_refuge_until_he_takes_her_and_then_in_his_room() -> void:
	var inn := _left(_party(), "inn")
	assert_eq(SideQuestPlay.standing(inn, INN, "ireena"), AT_INN)
	assert_eq(SideQuestPlay.standing(inn, MANSION, "ireena"), "")
	var church := _left(_party(), "st_andrals")
	assert_eq(SideQuestPlay.standing(church, CHURCH, "ireena"), AT_CHURCH)
	for refuge: Array in [["inn", INN], ["st_andrals", CHURCH]]:
		var st := _held(_party(), str(refuge[0]))
		assert_eq(SideQuestPlay.standing(st, str(refuge[1]), "ireena"), "", "%s: gone from her refuge" % refuge[0])
		assert_eq(SideQuestPlay.standing(st, MANSION, "ireena"), IN_THE_ROOM, "%s: in his room" % refuge[0])
		st.set_flag("ismark_guards_ireena")
		assert_eq(SideQuestPlay.standing(st, str(refuge[1]), "ismark"), "", "%s: and Ismark is out at the gate" % refuge[0])
	var by_day := _held(_party(MANSION, DAY_HOUR))
	assert_eq(SideQuestPlay.standing(by_day, MANSION, "ireena"), IN_THE_ROOM, "by day she is alone in it")
	assert_eq(SideQuestPlay.standing(by_day, MANSION, "izek"), "", "Izek is out on the Baron's business")
	var by_night := _held(_party(MANSION))
	assert_eq(SideQuestPlay.standing(by_night, MANSION, "izek"), ROOM, "by night he is there")
	assert_eq(SideQuestPlay.standing(by_night, MANSION, "ireena"), IN_THE_ROOM)
	var guests := _held(_party())
	assert_true(guests.add_guest("ireena"))
	assert_eq(SideQuestPlay.standing(guests, MANSION, "ireena"), "", "travelling with the party she is nowhere else")


func test_she_is_back_in_her_refuge_when_it_is_over_however_it_ended() -> void:
	for how: String in ["rescued", "threatened", "escaped", "fought"]:
		var st := _held(_party(MANSION))
		st.set_flag("izek_holds_ireena", false)
		st.set_flag("izek_hold_ended", how)
		assert_eq(SideQuestPlay.standing(st, INN, "ireena"), AT_INN, how + ": back at the inn")
		assert_eq(SideQuestPlay.standing(st, MANSION, "ireena"), "", how + ": out of his room")
	# Izek died or was told the truth somewhere else while she was held: she is free without a word.
	for flag: String in ["izek_dead", "izek_told_truth"]:
		var st := _held(_party(MANSION))
		st.set_flag(flag)
		assert_eq(SideQuestPlay.standing(st, INN, "ireena"), AT_INN, flag + ": back at the inn")
		assert_eq(SideQuestPlay.standing(st, MANSION, "ireena"), "", flag + ": not in the room")


func test_izek_in_his_room_by_night_is_the_old_scene_until_the_taking_and_the_aftermath_after_it() -> void:
	var before := _left(_party(MANSION))
	assert_eq(SideQuestPlay.standing(before, MANSION, "izek"), "vallaki/izek:at_home", "before: as it always was")
	var after := _held(_party(MANSION))
	after.set_flag("izek_holds_ireena", false)
	assert_eq(SideQuestPlay.standing(after, MANSION, "izek"), "allies/izek_takes:after_hold", "once she is gone again")
	after.set_flag("izek_told_truth")
	assert_eq(SideQuestPlay.standing(after, MANSION, "izek"), "", "told the truth he has left the Baron's service")
	var dead := _held(_party(MANSION))
	dead.set_flag("izek_holds_ireena", false)
	dead.set_flag("izek_dead")
	assert_eq(SideQuestPlay.standing(dead, MANSION, "izek"), "")


func test_the_squares_are_open_floor_and_the_first_sight_comes_by_itself() -> void:
	var loc := Compendium.shared().get_entry("locations", MANSION)
	var rows := loc["map"]["rows"] as Array
	var taken: Array = []
	for list: String in ["props", "containers"]:
		for p: Variant in loc.get(list, []):
			taken.append((p as Dictionary)["cell"])
	var seen := {}
	for n: Variant in loc["npcs"]:
		var e := n as Dictionary
		var d := str(e["dialogue"])
		if not d.begins_with("allies/izek_takes"):
			continue
		var cell := e["cell"] as Array
		assert_eq(str((rows[int(cell[1])] as String)[int(cell[0])]), ".", d + ": on open floor")
		assert_false(cell in taken, d + ": not on a prop")
		seen[str(e["npc"]) + ":" + d] = e
	assert_true(seen.has("izek:" + ROOM) and int((seen["izek:" + ROOM] as Dictionary).get("approach", 0)) > 0, "Izek speaks first at night")
	assert_true(seen.has("ireena:" + IN_THE_ROOM), "Ireena has her place")
	assert_ne((seen["izek:" + ROOM] as Dictionary)["cell"], (seen["ireena:" + IN_THE_ROOM] as Dictionary)["cell"], "not on each other")


func test_strahds_three_visits_to_her_wait_while_she_is_held() -> void:
	StrahdPresence.use({})
	for c: Array in [["ireena_at_the_inn", "inn", INN], ["ireena_at_the_church", "st_andrals", CHURCH]]:
		var vis := StrahdPresence.visit(str(c[0]))
		assert_false(vis.is_empty(), str(c[0]) + " exists")
		var free := _left(_party(str(c[2])), str(c[1]))
		free.set_flag("strahd_watcher_seen")
		free.day = 6
		assert_true(StrahdPresence.fires(vis, free, "arrive", str(c[2]), "vallaki", true, false), str(c[0]) + ": he comes when she is in her refuge")
		var held := _held(_party(str(c[2])), str(c[1]))
		held.set_flag("strahd_watcher_seen")
		held.day = 6
		assert_false(StrahdPresence.fires(vis, held, "arrive", str(c[2]), "vallaki", true, false), str(c[0]) + ": not while Izek has her")
		held.set_flag("izek_dead")
		assert_true(StrahdPresence.fires(vis, held, "arrive", str(c[2]), "vallaki", true, false), str(c[0]) + ": back when she is free")
	var krezk := StrahdPresence.visit("ireena_in_krezk")
	var in_krezk := _party("krezk")
	in_krezk.set_flag("strahd_watcher_seen")
	in_krezk.set_flag("ireena_in_krezk")
	in_krezk.day = 6
	assert_true(StrahdPresence.fires(krezk, in_krezk, "arrive", "krezk", "krezk", true, false), "Krezk is unchanged")


# --- Izek's room, by night -----------------------------------------------------------------------------------------------

func test_the_room_by_night_has_both_of_them_and_every_menu_an_exit() -> void:
	var st := _held(_party(MANSION))
	var first := SideQuestPlay.play(st, ROOM)
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(_says(first, "narrow cot"), "what the party sees")
	assert_true(_says(first, "You're in my room."), "his first words, as at_home has them")
	assert_true(_says(first, "stop speaking over my head"), "and hers")
	assert_true(_ends(first), "'We'll go' leaves")
	assert_true(bool(st.get_flag("izek_room_met", false)))
	assert_true(bool(st.get_flag("izek_holds_ireena", false)), "leaving frees no one")
	assert_true(_has_option(first, "Ireena, are you hurt"))
	assert_true(_has_option(first, "Draw steel"))
	assert_true(_has_option(first, "Let her walk out"))
	assert_false(_has_option(first, "we know who the red-haired woman is"), "the truth is offered only when the party has worked it out")
	var again := SideQuestPlay.play(st, ROOM, ["Ireena, are you hurt"])
	assert_true(_says(again, "You're back."), "a shorter welcome the second time")
	assert_true(_says(again, "monstrously polite"), "she answers about the dolls")
	assert_true(_ends(again))
	st.set_flag("izek_sister_truth")
	assert_true(_has_option(SideQuestPlay.play(st, ROOM), "we know who the red-haired woman is"))
	st.set_flag("izek_told_truth")
	assert_false(_has_option(SideQuestPlay.play(st, ROOM), "we know who the red-haired woman is"), "not once he has been told")


func test_a_threat_that_works_lets_her_go_and_leaves_a_grudge() -> void:
	var st := _held(_party(MANSION))
	st.set_flag("ireena_trust", 1)
	var before := st.flags.duplicate(true)
	var beats := SideQuestPlay.play(st, "allies/izek_takes:room_threat_ok", ["Let us take you back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "Take her, then."), "he gives way")
	assert_true(_says(beats, "I'm good at waiting."), "and keeps his grudge")
	assert_true(_says(beats, "Thank you. I'll say it once and plainly"), "she says it once")
	assert_true(_ends(beats))
	var moved := _changed(before, st.flags)
	moved.sort()
	assert_eq(moved, ["ireena_trust", "izek_hold_ended", "izek_holds_ireena"] as Array[String], "only side flags")
	assert_eq(str(st.get_flag("izek_hold_ended", "")), "threatened")
	assert_eq(int(st.get_flag("ireena_trust", 0)), 2, "they came for her: one trust")
	assert_eq(st.attitude("izek"), "hostile")
	assert_eq(SideQuestPlay.standing(st, INN, "ireena"), AT_INN, "back in her refuge")
	var along := _held(_party(MANSION))
	SideQuestPlay.play(along, "allies/izek_takes:room_threat_ok", ["Come with us again"])
	assert_true("ireena" in along.guest_ids, "or she walks with the party again (the existing rejoin)")
	assert_eq(str(along.get_flag("ireena_sanctuary", "")), "with_party")


func test_a_threat_that_fails_and_drawing_steel_both_start_the_fight_with_her_already_out() -> void:
	for node: String in ["allies/izek_takes:room_threat_fail", ROOM]:
		var st := _held(_party(MANSION))
		var picks: Array[String] = []
		if node == ROOM:
			picks.append("Draw steel")
		var beats := SideQuestPlay.play(st, node, picks)
		assert_eq(SideQuestPlay.combat_of(beats), "izek_confrontation", node + ": the fight that at_home starts")
		assert_true(_says(beats, "I'll be on the stairs"), node + ": she slips out first")
		assert_false(bool(st.get_flag("izek_holds_ireena", false)), node + ": she is not in the room for the fight")
		assert_eq(str(st.get_flag("izek_hold_ended", "")), "fought")
		assert_eq(SideQuestPlay.standing(st, INN, "ireena"), AT_INN, node + ": and is at her refuge afterwards")
		var enc := SideQuestPlay.encounter(st, MANSION, "izek_confrontation")
		assert_false(enc.is_empty(), node + ": the encounter stands")
		assert_false(SideQuestPlay.has_foe(enc, "ireena"), node + ": and she is not in it")


func test_the_truth_with_her_in_the_room_frees_her_and_tells_him() -> void:
	var st := _held(_party(MANSION))
	st.set_flag("izek_sister_truth")
	var before := st.flags.duplicate(true)
	var beats := SideQuestPlay.play(st, ROOM, ["we know who the red-haired woman is", "Let Ireena tell him", "Let us take you back"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(_says(beats, "I don't remember anything before Kolyan's house"), "she tells him herself")
	assert_true(_says(beats, "My sister had red hair."), "the existing lines")
	assert_true(_says(beats, "I don't know what to call you."), "and hers")
	assert_false(_says(beats, "we need not speak of that room again"), "after this she needs no thanks for the way out")
	assert_true(bool(st.get_flag("izek_told_truth", false)), "the same flag the old scene sets")
	assert_eq(st.quest_stage("izek_obsession"), "truth_told")
	assert_eq(str(st.get_flag("izek_hold_ended", "")), "truth")
	assert_false(bool(st.get_flag("izek_holds_ireena", false)))
	assert_eq(int(st.get_flag("ireena_trust", 0)), 1)
	var moved := _changed(before, st.flags)
	moved.sort()
	assert_eq(moved, ["ireena_trust", "izek_hold_ended", "izek_holds_ireena", "izek_room_met", "izek_told_truth"] as Array[String], "side flags and the old scene's own izek_told_truth, nothing else of the story's")
	assert_true(_ends(beats))
	var missed := _held(_party(MANSION))
	missed.set_flag("izek_sister_truth")
	var fail := SideQuestPlay.play(missed, "allies/izek_takes:room_truth_fail", ["Let Ireena tell him", "Let us take you back"])
	assert_eq(SideQuestPlay.missing(fail), "")
	assert_true(_says(fail, "Liar."), "a failed plea: his old answer")
	assert_true(_says(fail, "let me speak to him myself"), "and she asks to speak")
	assert_true(bool(missed.get_flag("izek_told_truth", false)), "which works: she is not a check that can fail")
	assert_eq(missed.attitude("izek"), "hostile")


# --- Ireena in the room --------------------------------------------------------------------------------------------------

func test_by_day_she_is_alone_and_the_party_can_walk_her_out() -> void:
	var st := _held(_party(MANSION, DAY_HOUR))
	var first := SideQuestPlay.play(st, ROOM_DAY, ["Come on. We're getting you out", "Let us take you back"])
	assert_eq(SideQuestPlay.missing(first), "")
	assert_true(_says(first, "He went out at first light"), "his room by day")
	assert_true(_says(first, "pin my scarf straight"), "the walk out")
	assert_true(_says(first, "I'll say it once and plainly"))
	assert_eq(str(st.get_flag("izek_hold_ended", "")), "rescued")
	assert_false(bool(st.get_flag("izek_holds_ireena", false)))
	assert_eq(int(st.get_flag("ireena_trust", 0)), 1)
	assert_eq(st.attitude("izek"), "hostile", "he will know at dusk")
	assert_eq(SideQuestPlay.standing(st, INN, "ireena"), AT_INN)
	var wait := _held(_party(MANSION, DAY_HOUR))
	var stay := SideQuestPlay.play(wait, ROOM_DAY, ["Stay here a little longer"])
	assert_true(_ends(stay))
	assert_true(bool(wait.get_flag("izek_holds_ireena", false)), "asked to wait, she waits")
	var back := SideQuestPlay.play(wait, ROOM_DAY, ["Did he hurt you"])
	assert_true(_says(back, "Dusk comes early"), "the second visit is shorter")
	assert_true(_says(back, "monstrously polite"))
	var out := SideQuestPlay.play(_held(_party(MANSION, DAY_HOUR)), ROOM_DAY, ["Come on", "Come with us again"])
	assert_true(_says(out, "Good. I was going mad sitting still."), "she rejoins by the old node")


func test_by_night_she_sends_the_party_to_talk_to_him() -> void:
	var st := _held(_party(MANSION))
	var beats := SideQuestPlay.play(st, ROOM_DAY)
	assert_true(_says(beats, "Speak to him, and keep your voice flat."))
	assert_true(_ends(beats))
	assert_true(bool(st.get_flag("izek_holds_ireena", false)), "nothing changes")


func test_izek_afterwards_opens_by_how_it_ended_and_goes_into_the_old_menu() -> void:
	var escaped := _held(_party(MANSION))
	escaped.set_flag("izek_holds_ireena", false)
	escaped.set_flag("izek_hold_ended", "escaped")
	var a := SideQuestPlay.play(escaped, "allies/izek_takes:after_hold")
	assert_eq(SideQuestPlay.missing(a), "")
	assert_true(_says(a, "tin splint"), "his nose")
	assert_true(_says(a, "I don't know why."))
	assert_true(_ends(a), "'We'll go' leaves")
	var freed := _held(_party(MANSION))
	freed.set_flag("izek_holds_ireena", false)
	freed.set_flag("izek_hold_ended", "rescued")
	var b := SideQuestPlay.play(freed, "allies/izek_takes:after_hold")
	assert_true(_says(b, "I counted the box twice"))
	assert_false(_says(b, "tin splint"))
	assert_true(_has_option(b, "Stay away from Ireena"))
	assert_true(_has_option(b, "Draw steel"))
	assert_false(_has_option(b, "we know who the red-haired woman is"), "the truth only when it is known")
	freed.set_flag("izek_sister_truth")
	assert_true(_has_option(SideQuestPlay.play(freed, "allies/izek_takes:after_hold"), "we know who the red-haired woman is"))
	var fight := SideQuestPlay.play(freed, "allies/izek_takes:after_hold", ["Draw steel"])
	assert_eq(SideQuestPlay.combat_of(fight), "izek_confrontation", "steel is the old fight")


func test_every_conversation_of_the_file_ends() -> void:
	var refs: Array[String] = ["night", "room", "ireena_room", "after_hold", "freed", "alone_again", "watched", "omen", "taken", "escape"]
	for node: String in refs:
		var states: Array[StoryState] = [_held(_party(MANSION)), _held(_party(MANSION, DAY_HOUR)), _left(_party(INN))]
		for st in states:
			var beats := SideQuestPlay.play(st, "allies/izek_takes:" + node)
			assert_eq(SideQuestPlay.missing(beats), "", node)
			assert_true(_ends(beats), node + ": reaches its end")
