extends TestCase
## Package R6b of the small-winks plan (docs/story/eggs.md, docs/plans/gemini_eggs/r6b/): camp nights and the party.
## Ilse's highest compliment, Godrick's party once the Martikovs' wine flows again (a toast from everyone at the fire),
## and a night when someone is found very close to a sleeper's throat. Each waits where the player has to look, none
## moves a main story flag, and every conversation they touch keeps its way out.

const SIX: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille", "wren_featherfoot",
	"kip_smudgewick"]
const HEROES: Array[String] = ["ilse_varga", "silvain_aster", "hedda_ironvow", "tamsin_tealeaf"]


func _st(ids: Array[String], level: int = 5) -> StoryState:
	return SideQuestPlay.party(ids, level, "vallaki_blue_water_inn", 22)


func _everyone(level: int = 5) -> StoryState:
	var ids: Array[String] = []
	ids.append_array(SIX)
	ids.append_array(HEROES)
	return _st(ids, level)


## A camp file's talks before `talk` count as had, so the next one it offers is the one under test.
func _mark_before(st: StoryState, file: String, talk: String) -> void:
	for node in DialogueFile.load_key("camp/" + file).order:
		if node == talk:
			return
		if node.begins_with("talk_"):
			CampTalk.mark(st, "camp/%s:%s" % [file, node])


func _offered(st: StoryState, file: String) -> String:
	return str(CampTalk.offered(DialogueFile.load_key("camp/" + file), st).get("ref", ""))


func _ends(beats: Array[Dictionary]) -> bool:
	return str(beats[-1]["kind"]) == "end"


# --- 27: worth killing later -----------------------------------------------------------------------------------------

func test_ilse_pays_the_party_her_highest_compliment_from_level_four() -> void:
	var low := _st(["ilse_varga", "thistle"], 3)
	_mark_before(low, "ilse", "talk_warrior")
	assert_ne(_offered(low, "ilse"), "camp/ilse:talk_warrior", "not before level 4")
	var st := _st(["ilse_varga", "thistle"], 4)
	_mark_before(st, "ilse", "talk_warrior")
	assert_eq(_offered(st, "ilse"), "camp/ilse:talk_warrior")
	var beats := SideQuestPlay.play(st, "camp/ilse:talk_warrior", ["too, Ilse"])
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	assert_true(text.contains("worth killing later") and text.contains("Try it before breakfast"), text)
	assert_true(bool(st.get_flag("eggs_ilse_compliment", false)))
	assert_true(_ends(beats))
	var asked := SideQuestPlay.play(_st(["ilse_varga"], 4), "camp/ilse:talk_warrior", ["What happened to her"])
	assert_eq(SideQuestPlay.missing(asked), "")
	assert_true(SideQuestPlay.text(asked).contains("three silver and a whetstone"))
	assert_true(_ends(asked))
	var bare := SideQuestPlay.play(_st(["ilse_varga"], 4), "camp/ilse:talk_warrior")
	assert_true(_ends(bare), "with nothing picked, the menu still ends")
	CampTalk.mark(st, "camp/ilse:talk_warrior")
	assert_ne(_offered(st, "ilse"), "camp/ilse:talk_warrior", "it is said once")


# --- 29: a cask for the camp -----------------------------------------------------------------------------------------

func test_godrick_calls_a_party_once_the_martikovs_wine_flows() -> void:
	var st := _everyone()
	_mark_before(st, "godrick", "talk_party")
	assert_ne(_offered(st, "godrick"), "camp/godrick:talk_party", "not before the wine flows")
	st.set_flag("winery_wine_flows")
	assert_eq(_offered(st, "godrick"), "camp/godrick:talk_party")
	var gone := _st(["thistle", "wren_featherfoot"])
	gone.set_flag("winery_wine_flows")
	assert_ne(_offered(gone, "godrick"), "camp/godrick:talk_party", "it is his party: he has to be there")


func test_everyone_at_the_fire_gives_a_toast_and_the_party_is_lifted() -> void:
	var st := _everyone()
	st.set_flag("winery_wine_flows")
	var before: Dictionary = {}
	for id: String in SIX:
		before[id] = Approval.score(st, id)
	var beats := SideQuestPlay.play(st, "camp/godrick:talk_party")
	assert_eq(SideQuestPlay.missing(beats), "")
	var text := SideQuestPlay.text(beats)
	for part: String in ["Sir Pellam", "wine that bites back", "gracious landlord", "wet cellar", "Morning's grace",
			"free samples", "stitching you up", "Count off", "existential dread", "forgot to padlock the wagon",
			"finest company a heavy shield"]:
		assert_true(text.contains(part), "the toast '%s' is raised: %s" % [part, text])
	assert_true(text.contains("drowsy head slips against Godrick's shoulder"), "and it ends with someone asleep against him")
	assert_true(bool(st.get_flag("eggs_party_held", false)))
	assert_true(_ends(beats))
	for id: String in SIX:
		assert_eq(Approval.score(st, id), int(before[id]) + 1, "%s enjoyed it" % id)
	assert_true(st.party.all(func(c: Character) -> bool: return c.heroic_inspiration), "everyone is lifted")
	for flag: String in st.flags.keys():
		assert_false(flag.begins_with("romance_"), "no romance starts: %s" % flag)


func test_a_small_party_toasts_only_those_present() -> void:
	var st := _st(["godrick_pendlebrook", "thistle"])
	st.set_flag("winery_wine_flows")
	var text := SideQuestPlay.text(SideQuestPlay.play(st, "camp/godrick:talk_party"))
	assert_true(text.contains("wine that bites back") and text.contains("finest company a heavy shield"), text)
	assert_false(text.contains("free samples") or text.contains("Count off") or text.contains("wet cellar"), "the absent are silent")
	assert_true(bool(st.get_flag("eggs_party_held", false)))


# --- 30: checking for a pulse ----------------------------------------------------------------------------------------

func test_one_night_at_a_wild_camp_a_companion_is_found_over_a_sleepers_throat() -> void:
	var low := _st(SIX, 3)
	for seed in 8:
		assert_false(Narrator.new(seed).line("camp:night", low).contains("checking for a fever"), "not before level 4")
	var st := _st(SIX, 4)
	var narrator := Narrator.new(7)
	var first := narrator.line("camp:night", st)
	assert_true(first.contains("checking for a fever") and first.contains("one of your company"), first)
	assert_false(first.contains("Ilse") or first.contains("Thistle") or first.contains("Kip"), "it names no one")
	for i in 6:
		assert_false(narrator.line("camp:night", st).contains("checking for a fever"), "once a playthrough")
	var indoors := _st(SIX, 4)
	for seed in 8:
		assert_false(Narrator.new(seed).line("camp:night:indoors", indoors).contains("checking for a fever"), "the wild's night only")


func test_the_winks_set_only_side_flags() -> void:
	var own: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/eggs_camp_nights.json"))
	var ids: Array = (own["flags"] as Array).map(func(f: Variant) -> String: return str((f as Dictionary)["id"]))
	assert_eq(ids, ["eggs_ilse_compliment", "eggs_party_held"])
