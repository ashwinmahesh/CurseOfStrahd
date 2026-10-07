extends TestCase
## Companion approval (F3, story/approval.gd) and Heroic Inspiration for playing in character (F15,
## story/in_character.gd): the `approve` and `inspire` statements, who sees a choice, the tiers and conditions, saving,
## and the party screen's panel.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]

const SCENE := """
~ start
Narrator: A choice.
* Free the wolves. -> freed
* Leave them. -> left

~ freed
approve thistle +3 godrick_pendlebrook +1 kip_smudgewick -2: You opened the cages
inspire name:thistle: let the wolves go
-> END

~ left
approve thistle -6: You left the wolves caged
-> END

~ loop
approve wren_featherfoot +2: You laughed at the Baron
-> END
"""


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(SCENE, "test/approval"))


func _party(ids: Array[String]) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		st.party.append(Pregens.build(id, 3))
	return st


func _run(st: StoryState, ref: String, pick: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var r := DialogueRunner.new(st, DiceRoller.new(1))
	assert_true(r.start(ref), "starts " + ref)
	var b := r.next()
	for i in 50:
		out.append(b)
		if str(b["kind"]) == "end":
			break
		b = r.choose(pick) if str(b["kind"]) == "options" else r.next()
	return out


func _notices(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b["kind"]) == "notice":
			out.append(str(b["text"]))
	return out


func test_the_six_are_the_roster_pregens() -> void:
	var roster: Array[String] = []
	for p in Compendium.shared().all("pregens"):
		if bool(p.get("roster", true)):
			roster.append(str(p["id"]))
	roster.sort()
	var six := Approval.COMPANIONS.duplicate()
	six.sort()
	assert_eq(six, roster, "Approval.COMPANIONS lists data/pregens' roster")


func test_approve_parses_pairs_and_a_reason() -> void:
	var f := DialogueFile.load_key("test/approval")
	assert_true(f.errors.is_empty(), "parses: %s" % [f.errors])
	var s := (f.nodes["freed"] as Array)[0] as Dictionary
	assert_eq(str(s["t"]), "approve")
	assert_eq(s["changes"], [["thistle", 3], ["godrick_pendlebrook", 1], ["kip_smudgewick", -2]])
	assert_eq(str(s["why"]), "You opened the cages")
	var i := (f.nodes["freed"] as Array)[1] as Dictionary
	assert_eq(str(i["t"]), "inspire")
	assert_eq(str(i["selector"]), "name:thistle")
	var bad := DialogueFile.parse("~ a\napprove thistle 3\napprove thistle +2 kip\n", "test/bad")
	assert_eq(bad.errors.size(), 2, "an unsigned change and a dangling id don't read")


func test_only_companions_travelling_see_a_choice() -> void:
	var st := _party(["thistle", "kip_smudgewick", "wren_featherfoot"])
	st.bench.append(Pregens.build("godrick_pendlebrook", 3))
	var notes := _notices(_run(st, "test/approval:start", 0))
	assert_eq(Approval.score(st, "thistle"), 3)
	assert_eq(Approval.score(st, "kip_smudgewick"), -2)
	assert_eq(Approval.score(st, "godrick_pendlebrook"), 0, "Godrick was at camp")
	assert_true("Thistle approves · Kip disapproves" in notes, "the notice names who reacted: %s" % [notes])
	assert_eq(str(Approval.memories(st, "thistle")[0]["why"]), "You opened the cages")


func test_a_custom_hero_in_a_companions_name_has_no_approval() -> void:
	var st := _party(["kip_smudgewick"])
	var b := CharacterBuilder.new(null, {"appearance": {"custom": true, "art": "hero_02", "voice": "hero_female"}})
	b.set_class("ranger")
	b.set_background("guide")
	b.set_species("human")
	b.set_name("Thistle")
	var hero := b.preview()
	hero.id = "thistle"
	st.party.append(hero)
	_run(st, "test/approval:start", 0)
	assert_eq(Approval.witnesses(st), ["kip_smudgewick"] as Array[String])
	assert_eq(Approval.score(st, "thistle"), 0, "the hero isn't Thistle")
	_no_panel_for_heroes_only()


func _no_panel_for_heroes_only() -> void:
	var st := StoryState.new()
	var b := CharacterBuilder.new(null, {"appearance": {"custom": true, "art": "hero_01", "voice": "hero_male"}})
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	b.set_name("Oskar Brann")
	st.party.append(b.preview())
	assert_true(ApprovalPanel.build(st) == null, "no panel for a company with none of the six")


func test_each_approve_counts_once_a_playthrough() -> void:
	var st := _party(["wren_featherfoot"])
	_run(st, "test/approval:loop")
	_run(st, "test/approval:loop")
	assert_eq(Approval.score(st, "wren_featherfoot"), 2, "running the node again doesn't count it again")
	assert_eq(Approval.memories(st, "wren_featherfoot").size(), 1)


func test_tiers_and_conditions() -> void:
	var st := _party(["thistle"])
	assert_eq(str(Approval.tier(st, "thistle")["id"]), "neutral", "everyone starts Neutral")
	var r := Approval.change(st, "thistle", 12, "You ate with your hands at the Baron's table")
	assert_eq(str(r["tier_after"]), "warm")
	assert_true(StoryConditions.check("approval.thistle >= warm", st))
	assert_true(StoryConditions.check("approval.thistle", st), "no operator means Warm or better")
	assert_false(StoryConditions.check("approval.thistle >= close", st))
	assert_true(StoryConditions.check("approval.thistle == 12", st), "a number compares with the score")
	Approval.change(st, "thistle", -40)
	assert_eq(str(Approval.tier(st, "thistle")["id"]), "strained")
	assert_true(StoryConditions.check("approval.thistle <= strained", st), "strained or worse")
	assert_true(StoryConditions.check("not (approval.thistle > strained)", st))
	assert_false(StoryConditions.check("approval.thistle <= estranged", st))
	Approval.change(st, "thistle", -500)
	assert_eq(Approval.score(st, "thistle"), Approval.LOWEST, "held at -100")
	assert_eq(str(Approval.tier_for(9)["id"]), "neutral")
	assert_eq(str(Approval.tier_for(-10)["id"]), "doubtful")
	assert_eq(str(Approval.tier_for(-25)["id"]), "strained")
	assert_eq(str(Approval.tier_for(50)["id"]), "devoted")


func test_crossing_into_a_tier_says_so() -> void:
	var st := _party(["thistle"])
	Approval.change(st, "thistle", 8)
	var notes := _notices(_run(st, "test/approval:start", 0))
	assert_true("Thistle approves (now Warm)" in notes, "%s" % [notes])
	var st2 := _party(["thistle"])
	notes = _notices(_run(st2, "test/approval:start", 1))
	assert_true("Thistle greatly disapproves" in notes, "%s" % [notes])


func test_memories_keep_the_newest() -> void:
	var st := _party(["kip_smudgewick"])
	for i in 12:
		Approval.change(st, "kip_smudgewick", 1, "moment %d" % i)
	var mem := Approval.memories(st, "kip_smudgewick")
	assert_eq(mem.size(), Approval.MEMORY)
	assert_eq(str(mem[0]["why"]), "moment 11", "newest first")


func test_approval_survives_a_save_and_ignores_junk() -> void:
	var st := _party(["liriel_dawnsong", "ratatoille"])
	Approval.change(st, "liriel_dawnsong", 7, "You buried the dead")
	var d := st.to_dict()
	(d["approval"] as Dictionary)["strahd"] = {"score": 99}
	(d["approval"] as Dictionary)["ratatoille"] = {"score": 1000, "memories": ["not a memory"]}
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(d)) as Dictionary)
	assert_eq(Approval.score(back, "liriel_dawnsong"), 7)
	assert_eq(str(Approval.memories(back, "liriel_dawnsong")[0]["why"]), "You buried the dead")
	assert_false(back.approval.has("strahd"), "only the six")
	assert_eq(Approval.score(back, "ratatoille"), Approval.HIGHEST)
	assert_true(Approval.memories(back, "ratatoille").is_empty())
	var old := StoryState.from_dict({"party": []})
	assert_true(old.approval.is_empty(), "a save from before approval starts everyone Neutral")


func test_inspiration_for_playing_in_character() -> void:
	var st := _party(["kip_smudgewick", "thistle"])
	for ch in st.party:
		ch.heroic_inspiration = false
	var notes := _notices(_run(st, "test/approval:start", 0))
	var thistle := st.find_member("name:thistle")
	assert_true(thistle.heroic_inspiration)
	assert_true("Thistle earns Heroic Inspiration: let the wolves go" in notes, "%s" % [notes])
	var again := InCharacter.award(st, "name:thistle", "howled back")
	assert_true(st.find_member("name:kip_smudgewick").heroic_inspiration, "she already had it, so it passes on (2024)")
	assert_true(again.contains("passes to Kip"), again)
	assert_eq(InCharacter.award(st, "name:thistle"), "", "everyone has it now")
	assert_eq(InCharacter.award(st, "class:cleric"), "", "nobody here fits")
	var liriel := _party(["liriel_dawnsong"])
	liriel.party[0].heroic_inspiration = false
	assert_true(InCharacter.award(liriel, "background:acolyte", "said the rites") != "",
		"a background picks whoever has it (so a custom hero can earn it)")


func test_the_party_screen_shows_how_they_feel() -> void:
	var st := _party(["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"])
	st.bench.append(Pregens.build("wren_featherfoot", 3))
	st.bench.append(Pregens.build("kip_smudgewick", 3))
	Approval.change(st, "thistle", 30, "You told the Baron what you thought of him")
	var panel := ApprovalPanel.build(st)
	assert_true(panel != null)
	var texts: Array[String] = []
	for l in panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	for want: String in ["Thistle", "Close", "▲ You told the Baron what you thought of him", "AT CAMP", "Kip Smudgewick"]:
		var found := false
		for t in texts:
			if t.contains(want):
				found = true
		assert_true(found, "the panel says '%s'" % want)
	panel.free()
	var pill := ApprovalPanel.tier_pill(st, st.party[2])
	assert_true(pill != null, "Thistle's card wears her tier")
	pill.free()
