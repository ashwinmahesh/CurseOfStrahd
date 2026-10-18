extends TestCase
## NPC depth, batch 4b (docs/plans/npc_depth_and_quests.md): the Wizard of Wines. The hands' wants and secrets, Sprig the
## twig blight that thinks it is a dog, and Old Silviu's Wedding Cask: a delivery whose three precautions each have a
## plain way, and a wedding that happens whatever arrives.

const FOUR: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "ratatoille", "thistle"]
const W := "wizard_of_wines/"


func _st(hour: int = 10, location: String = "wizard_of_wines", level: int = 6) -> StoryState:
	return SideQuestPlay.party(FOUR, level, location, hour)


func test_the_hands_have_wants_and_secrets() -> void:
	var st := _st()
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "hands:watch", ["most like"])).contains("boots off"))
	SideQuestPlay.play(st, W + "hands:watch_secret")
	assert_true(st.get_flag("ionel_crossbow_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "hands:watch_secret")).contains("crossbow"), "the secret reads right")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "hands:watch_miss")).length() > 10)
	SideQuestPlay.play(st, W + "hands:washer_secret")
	assert_true(st.get_flag("tereza_sweet_known", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "hands:woodsplitter", ["very cross"])).contains("mittens"), "Horia only goes red once Tereza's secret is known")
	var none := SideQuestPlay.play(_st(), W + "hands:woodsplitter", ["very cross"])
	assert_ne(SideQuestPlay.missing(none), "", "not before")
	var o := _st()
	assert_ne(SideQuestPlay.missing(SideQuestPlay.play(o, W + "hands:pruner", ["Which vines"])), "", "the names come after the want")
	SideQuestPlay.play(o, W + "hands:pruner", ["most like"])
	assert_true(o.get_flag("ovidiu_want_heard", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(o, W + "hands:pruner", ["Which vines"])).contains("Elvir"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(o, W + "hands:picker", ["Watch him eat"])).contains("grape"))


func test_sprig_sits_pats_and_tells_who_sent_it() -> void:
	var st := _st(10, "wizard_of_wines")
	assert_eq(SideQuestPlay.standing(st, "wizard_of_wines", "sprig"), W + "sprig:start")
	var text := SideQuestPlay.text(SideQuestPlay.play(st, W + "sprig:start", ["Pat it", "Throw a stick"]))
	assert_true(text.contains("different stick"))
	assert_true(st.get_flag("sprig_met", false))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "sprig:plants")).contains("watch the house"))
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "sprig:start")).contains("fresh leaf"), "a later visit")
	st.set_flag("winery_reclaimed")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(st, W + "sprig:start")).contains("Martikovs' trestle"))


func test_old_silvius_wedding_cask_every_precaution_has_a_plain_way() -> void:
	var st := _st(10, "wizard_of_wines")
	st.set_flag("winery_reclaimed")
	assert_eq(SideQuestPlay.standing(st, "wizard_of_wines", "wine_cooper"), W + "hands:cooper")
	var beats := SideQuestPlay.play(st, W + "hands:cooper", ["carry for you", "We'll take it"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("silvius_wedding_cask"), "carrying", "he only needs the cask taken")
	st = _st(10, "wizard_of_wines")
	st.gold = 10.0
	beats = SideQuestPlay.play(st, W + "silvius_cask:road", ["Buy Silviu's good straw", "butcher's scraps", "Seal the bung"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(int(st.get_flag("cask_care", 0)), 3, "three precautions, three coins' worth")
	assert_eq(roundi(st.gold), 4)
	assert_eq(st.quest_stage("silvius_wedding_cask"), "carrying")
	# With no coin and no luck: still on the road, with the cask.
	st = _st(10, "wizard_of_wines")
	st.gold = 0.0
	beats = SideQuestPlay.play(st, W + "silvius_cask:road", ["Make do", "Hope", "Trust everyone"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(int(st.get_flag("cask_care", 0)), 0)
	assert_eq(st.quest_stage("silvius_wedding_cask"), "carrying")


func test_dana_has_her_wedding_whatever_arrives() -> void:
	var paid := [[3, 60.0, "ruby-bright"], [1, 40.0, "murky"], [0, 25.0, "strip the rust"]]
	for row: Array in paid:
		var st := _st(11, "vallaki")
		assert_eq(SideQuestPlay.standing(st, "vallaki", "silvius_dana"), "", "no bride at the pump until the cask is on the road")
		st.set_quest_stage("silvius_wedding_cask", "carrying")
		st.set_flag("cask_care", int(row[0]))
		assert_eq(SideQuestPlay.standing(st, "vallaki", "silvius_dana"), W + "silvius_cask:dana")
		var gold := st.gold
		var text := SideQuestPlay.text(SideQuestPlay.play(st, W + "silvius_cask:dana"))
		assert_true(text.contains(str(row[2])) or text.contains("Master Costel"), "Costel speaks")
		assert_eq(st.quest_stage("silvius_wedding_cask"), "done")
		assert_eq(st.gold, gold + float(row[1]))
	var after := _st(10, "wizard_of_wines")
	after.set_flag("winery_reclaimed")
	after.set_quest_stage("silvius_wedding_cask", "done")
	assert_true(SideQuestPlay.text(SideQuestPlay.play(after, W + "hands:cooper", ["How did the wedding"])).contains("Costel made a speech"))
