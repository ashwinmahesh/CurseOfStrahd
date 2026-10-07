extends TestCase
## Companion approval in the story (F3, docs/story/approval.md): the six's personal quests close their best ending at
## Strained and open more at Close; the approval camp talks come when they should, in the right order; romances move
## from spark to together; and the campaign gives every companion things to like and dislike.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]


func _party(level: int = 6) -> StoryState:
	var st := StoryState.new()
	for id in SIX:
		var ch := Pregens.build(id, level)
		ch.heroic_inspiration = false
		st.party.append(ch)
	return st


func _score(st: StoryState, id: String, score: int) -> void:
	Approval.change(st, id, score - Approval.score(st, id))


## Plays a conversation, picking at each menu the first option whose text contains the next of `picks` (or the last
## option once `picks` runs out). Returns every beat.
func _play(st: StoryState, ref: String, picks: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(3))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	var p := 0
	for i in 400:
		out.append(b)
		match str(b["kind"]):
			"end":
				break
			"options":
				var opts := b["options"] as Array
				var at := opts.size() - 1
				if p < picks.size():
					for j in opts.size():
						if str((opts[j] as Dictionary)["text"]).contains(picks[p]):
							at = j
							break
					p += 1
				b = r.choose(at)
			_:
				b = r.next()
	return out


func _texts(beats: Array[Dictionary]) -> String:
	var all := ""
	for b in beats:
		all += str(b.get("text", "")) + "\n"
		for o: Variant in b.get("options", []):
			all += "[option] " + str((o as Dictionary)["text"]) + "\n"
	return all


func _camp_refs(st: StoryState) -> Array[String]:
	var out: Array[String] = []
	for t in CampTalk.available(st):
		out.append(str(t["ref"]))
	return out


func _member(st: StoryState, id: String) -> Character:
	return st.find_member("name:" + id)


# --- The personal quests' endings ----------------------------------------------------------------------------------

func test_godrick_wont_kneel_while_strained_and_names_his_fellowship_when_close() -> void:
	var st := _party()
	st.set_quest_stage("the_ladle", "kept_faith")
	st.set_flag("godfrey_remembers", true)
	_score(st, "godrick_pendlebrook", -30)
	var beats := _play(st, "companions/ladle:knighting")
	assert_eq(st.quest_stage("the_ladle"), "kept_faith", "no knighting while Strained")
	assert_true(_texts(beats).contains("Not today, my lord"), "he says why")
	_score(st, "godrick_pendlebrook", 30)
	beats = _play(st, "companions/ladle:knighting")
	assert_eq(st.quest_stage("the_ladle"), "knighted")
	assert_true(_member(st, "godrick_pendlebrook").carries("weapon_plus_2"), "Close: the sword answers the fellowship")
	assert_false(st.party_has_item("weapon_plus_1"))
	assert_true(_member(st, "kip_smudgewick").heroic_inspiration, "the whole fellowship is inspired")


func test_liriel_cannot_sing_while_strained_and_leaves_the_dawn_behind_when_close() -> void:
	var st := _party()
	st.set_quest_stage("carry_the_dawn", "faith_kept")
	_score(st, "liriel_dawnsong", -40)
	var beats := _play(st, "companions/dawn:chapel")
	assert_false(_texts(beats).contains("(Let her.)"), "no hymn while Strained")
	assert_eq(st.quest_stage("carry_the_dawn"), "faith_kept")
	_score(st, "liriel_dawnsong", 40)
	_play(st, "companions/dawn:chapel", ["Let her"] as Array[String])
	assert_eq(st.quest_stage("carry_the_dawn"), "the_dawn")
	assert_true(st.party_has_item("amulet_of_the_devout_plus_1"), "her sunburst kept a little of the morning")


func test_thistle_keeps_the_party_from_fen_while_strained_and_wears_his_cloak_when_close() -> void:
	var st := _party()
	st.set_quest_stage("fens_trail", "found_him")
	st.set_flag("fen_met", true)
	_score(st, "thistle", -30)
	var beats := _play(st, "companions/fen:menu", ["Remove Curse"] as Array[String])
	assert_true(_texts(beats).contains("Not you lot"), "she steps between")
	assert_ne(str(st.get_flag("fen_fate", "")), "cured")
	_score(st, "thistle", 30)
	_play(st, "companions/fen:menu", ["Remove Curse"] as Array[String])
	assert_eq(str(st.get_flag("fen_fate", "")), "cured")
	assert_true(_member(st, "thistle").carries("cloak_of_elvenkind"), "Fen's cloak goes round her shoulders")


func test_ratatoille_lays_no_table_while_strained_and_a_feast_when_close() -> void:
	var st := _party()
	st.set_quest_stage("a_seat_at_the_table", "the_wizard_found")
	for ref: String in ["camp/ratatoille:talk_refectory", "camp/ratatoille:talk_recipes"]:
		CampTalk.mark(st, ref)
	var df := DialogueFile.load_key("camp/ratatoille")
	_score(st, "ratatoille", -30)
	assert_false(StoryConditions.check(CampTalk.opening_condition(df, "talk_table"), st), "no table while Strained")
	_score(st, "ratatoille", 30)
	CampTalk.mark(st, "camp/ratatoille:talk_warm")
	CampTalk.mark(st, "camp/ratatoille:talk_close")
	assert_true("camp/ratatoille:talk_table" in _camp_refs(st))
	_play(st, "camp/ratatoille:talk_table")
	assert_eq(st.quest_stage("a_seat_at_the_table"), "his_own_table")
	for ch in st.party:
		assert_true(ch.heroic_inspiration, ch.name + " ate the feast")


func test_wren_wont_take_the_partys_way_at_rahadin_while_strained() -> void:
	var st := _party()
	st.set_quest_stage("the_last_lesson", "let_her_rest")
	_score(st, "wren_featherfoot", -30)
	var beats := _play(st, "companions/lesson:rahadin", ["Pull Wren back"] as Array[String])
	assert_false(_texts(beats).contains("Tell him what Sorrel thought"), "no pity while Strained")
	assert_ne(st.quest_stage("the_last_lesson"), "learned")
	_score(st, "wren_featherfoot", 30)
	beats = _play(st, "companions/lesson:rahadin", ["what Sorrel thought"] as Array[String])
	assert_eq(st.quest_stage("the_last_lesson"), "learned")
	assert_true(_texts(beats).contains("You don't get finished on your own"), "Close: the lesson out loud")
	assert_true(_member(st, "wren_featherfoot").heroic_inspiration)


func test_kip_settles_alone_while_strained_and_carves_a_charm_when_close() -> void:
	var st := _party()
	st.set_quest_stage("the_fine_print", "the_small_print")
	st.set_flag("kip_strahd_signed", true)
	for ref: String in ["camp/kip:talk_quillon", "camp/kip:talk_reading"]:
		CampTalk.mark(st, ref)
	var df := DialogueFile.load_key("camp/kip")
	_score(st, "kip_smudgewick", -30)
	assert_false(StoryConditions.check(CampTalk.opening_condition(df, "talk_settle"), st), "not with the party watching while Strained")
	_score(st, "kip_smudgewick", 0)
	assert_true(StoryConditions.check(CampTalk.opening_condition(df, "talk_settle"), st), "Neutral is enough to settle")
	_score(st, "kip_smudgewick", 30)
	_play(st, "camp/kip:talk_settle")
	assert_eq(st.quest_stage("the_fine_print"), "free")
	assert_true(st.party_has_item("stone_of_good_luck"), "the first pit off a free tree")


# --- The camp talks --------------------------------------------------------------------------------------------------

func test_approval_camp_talks_come_in_order() -> void:
	var st := _party(3)
	st.set_quest_stage("the_ladle", "the_errand")
	var refs := _camp_refs(st)
	assert_true("camp/godrick:talk_ladle" in refs, "Neutral: the quest's talk")
	_score(st, "godrick_pendlebrook", -12)
	assert_true("camp/godrick:talk_doubt" in _camp_refs(st), "Doubtful comes before the quest")
	_play(st, "camp/godrick:talk_doubt", ["do better"] as Array[String])
	assert_eq(str(Approval.tier(st, "godrick_pendlebrook")["id"]), "neutral", "hearing him out mends a little")
	_score(st, "godrick_pendlebrook", -30)
	assert_true("camp/godrick:talk_strained" in _camp_refs(st))
	_play(st, "camp/godrick:talk_strained", ["Tell us when"] as Array[String])
	assert_true(Approval.score(st, "godrick_pendlebrook") > -25, "asking to be told when you're wrong lifts it out of Strained")
	CampTalk.mark(st, "camp/godrick:talk_ladle")
	_score(st, "godrick_pendlebrook", 12)
	assert_true("camp/godrick:talk_warm" in _camp_refs(st), "Warm, from level 3")
	_score(st, "godrick_pendlebrook", 30)
	assert_false("camp/godrick:talk_close" in _camp_refs(st), "Close waits for level 5 (the warm talk first)")


func test_every_approval_talk_plays_through() -> void:
	var st := _party(9)
	for id in SIX:
		for tier: String in ["strained", "doubt", "warm", "close", "devoted"]:
			var score := {"strained": -30, "doubt": -12, "warm": 12, "close": 30, "devoted": 60}[tier] as int
			_score(st, id, score)
			var file := id.get_slice("_", 0)
			var beats := _play(st, "camp/%s:talk_%s" % [file, tier])
			assert_true(beats.size() > 3, "%s %s plays" % [id, tier])
			assert_eq(str(beats[beats.size() - 1]["kind"]), "end")


# --- Romances ------------------------------------------------------------------------------------------------------

func test_a_romance_goes_from_spark_to_together() -> void:
	var st := _party(7)
	for id: String in ["thistle", "wren_featherfoot"]:
		_score(st, id, 12)
	assert_true("camp/romance_thistle_wren:talk_spark" in _camp_refs(st))
	_play(st, "camp/romance_thistle_wren:talk_spark", ["race more often"] as Array[String])
	CampTalk.mark(st, "camp/romance_thistle_wren:talk_spark")
	assert_eq(str(st.get_flag("romance_thistle_wren", "")), "spark")
	_score(st, "godrick_pendlebrook", 12)
	assert_false("camp/romance_godrick_thistle:talk_spark" in _camp_refs(st), "Thistle walks one road at a time")
	assert_eq(Approval.romance_line(st, "thistle"), "Sweet on Wren")
	_play(st, "camp/romance_thistle_wren:talk_courting", ["Just tell her"] as Array[String])
	assert_eq(str(st.get_flag("romance_thistle_wren", "")), "courting")
	assert_false("camp/romance_thistle_wren:talk_together" in _camp_refs(st), "together waits for Close")
	for id: String in ["thistle", "wren_featherfoot"]:
		_score(st, id, 30)
	assert_true("camp/romance_thistle_wren:talk_together" in _camp_refs(st))
	_play(st, "camp/romance_thistle_wren:talk_together")
	assert_eq(Approval.romance_line(st, "wren_featherfoot"), "Together with Thistle")


func test_steering_them_apart_ends_it_and_frees_thistle() -> void:
	var st := _party(5)
	for id: String in ["thistle", "wren_featherfoot", "godrick_pendlebrook"]:
		_score(st, id, 12)
	_play(st, "camp/romance_thistle_wren:talk_spark", ["keep it down"] as Array[String])
	CampTalk.mark(st, "camp/romance_thistle_wren:talk_spark")
	assert_eq(str(st.get_flag("romance_thistle_wren", "")), "over")
	assert_eq(Approval.romance_line(st, "thistle"), "")
	assert_true("camp/romance_godrick_thistle:talk_spark" in _camp_refs(st), "Godrick's road is open again")


func test_the_romances_need_both_of_them() -> void:
	var st := StoryState.new()
	st.party.append(Pregens.build("liriel_dawnsong", 5))
	_score(st, "liriel_dawnsong", 40)
	assert_false("camp/romance_liriel_ratatoille:talk_spark" in _camp_refs(st), "no Ratatoille, no supper")


# --- Coverage over the campaign -------------------------------------------------------------------------------------

func test_the_campaign_gives_each_companion_things_to_like_and_dislike() -> void:
	var liked := {}
	var disliked := {}
	var inspired := {}
	var stack: Array[String] = [""]
	while not stack.is_empty():
		var sub := stack.pop_back() as String
		var d := DirAccess.open(DialogueFile.ROOT + sub)
		for folder in d.get_directories():
			stack.append(sub + folder + "/")
		for f in d.get_files():
			if not f.ends_with(".dialogue"):
				continue
			var df := DialogueFile.load_key((sub + f).get_basename())
			assert_true(df.errors.is_empty(), "%s parses: %s" % [f, df.errors])
			for node: String in df.order:
				for s: Dictionary in df.nodes[node]:
					if str(s["t"]) == "approve":
						for c: Variant in s["changes"]:
							var pair := c as Array
							var tally := liked if int(pair[1]) > 0 else disliked
							tally[str(pair[0])] = int(tally.get(str(pair[0]), 0)) + 1
					elif str(s["t"]) == "inspire":
						inspired[str(s["selector"])] = true
	for id in SIX:
		assert_true(int(liked.get(id, 0)) >= 40, "%s has plenty to like (%d)" % [id, int(liked.get(id, 0))])
		assert_true(int(disliked.get(id, 0)) >= 10, "%s has things to dislike (%d)" % [id, int(disliked.get(id, 0))])
		assert_true(inspired.has("name:" + id), "%s can earn Heroic Inspiration in character" % id)
	assert_true(inspired.has("class:cleric") and inspired.has("class:wizard"), "custom heroes can too, by class")
