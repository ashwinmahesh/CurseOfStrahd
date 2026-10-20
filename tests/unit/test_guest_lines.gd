extends TestCase
## Guests' lines on the road (owner 2026-10-12; story/banter.gd, narrative/banter/guest_<id>.dialogue): what a guest
## says entering a place or as their own story moves, after a won fight, and now and then on a long walk.

const PARTY: Array[String] = ["liriel_dawnsong", "godrick_pendlebrook", "wren_featherfoot", "thistle"]
const KINDS: Array[String] = ["quest_", "place_", "fight_", "idle_"]
## Everyone a scene can bring along with `join` except Lupu, a dog who joins for one fight.
const GUESTS: Array[String] = ["adrian_martikov", "arabelle", "davian_martikov", "emil_toranescu", "ezmerelda",
	"gertruda", "ilinca_vrana", "ireena", "ismark", "izek", "kasimir_velikov", "kolyan_indirovich", "mordenkainen",
	"parriwimple", "pidlwick_ii", "rictavio", "sir_godfrey_gwilym", "teodor", "victor_vallakovich"]


func _st(location: String, guests: Array[String]) -> StoryState:
	var st := SideQuestPlay.party(PARTY, 6, location, 12)
	for g in guests:
		assert_true(st.add_guest(g), "%s joins" % g)
	return st


func test_region_reads_where_the_party_is() -> void:
	var st := _st("castle_ravenloft_court", [])
	assert_true(StoryConditions.check("region:castle_ravenloft", st))
	assert_false(StoryConditions.check("region:vallaki", st))
	st.location = "vallaki_blue_water_inn"
	assert_true(StoryConditions.check("region:vallaki", st))


func test_adrian_speaks_of_his_own_story_before_the_place() -> void:
	var st := _st("wizard_of_wines", ["adrian_martikov"])
	st.set_quest_stage("the_black_row", "asked")
	var b := Banter.new()
	var lines := b.guest_next(st, "enter")
	assert_eq(lines.size(), 1)
	assert_eq(str(lines[0]["speaker_id"]), "adrian_martikov")
	assert_true(str(lines[0]["text"]).contains("I picked that row every night"), "his own story first")
	lines = b.guest_next(st, "enter")
	assert_true(not lines.is_empty() and str(lines[0]["text"]).contains("Druids in our cellar"), "then the place")
	assert_true(b.guest_next(st, "enter").is_empty(), "each plays once")


func test_only_guests_with_the_party_speak() -> void:
	var st := _st("wizard_of_wines", [])
	var b := Banter.new()
	for moment: String in ["enter", "fight", "idle"]:
		assert_true(b.guest_next(st, moment).is_empty(), "nobody to say it (%s)" % moment)
	assert_true(st.add_guest("ismark"))
	var lines := b.guest_next(st, "fight")
	assert_eq(str(lines[0]["speaker_id"]), "ismark")


func test_after_a_fight_and_on_the_road() -> void:
	var st := _st("vallaki", ["ezmerelda"])
	var b := Banter.new()
	var said := {}
	for i in 3:
		var lines := b.guest_next(st, "fight")
		assert_eq(lines.size(), 1)
		said[str(lines[0]["text"])] = true
	assert_eq(said.size(), 3, "three different words after a fight")
	assert_true(b.guest_next(st, "fight").is_empty(), "and then she's said them all")
	assert_false(b.guest_next(st, "idle").is_empty(), "something on the road")


## Rictavio keeps his secret until it's out: the showman's lines before, the hunter's after.
func test_rictavio_before_and_after_the_mask() -> void:
	var st := _st("vallaki", ["rictavio"])
	var b := Banter.new()
	assert_true(str(b.guest_next(st, "enter")[0]["text"]).begins_with("Vallaki!"))
	st.set_flag("rictavio_unmasked")
	assert_true(str(b.guest_next(st, "enter")[0]["text"]).begins_with("Not that name"))


## Every guest who can join has a file; every node says when it plays and holds one line in that guest's own voice,
## spoken words and never a stage direction alone; and each has something to say after a fight.
func test_every_guest_has_lines() -> void:
	for gid in GUESTS:
		var key := "banter/guest_" + gid
		assert_false(Compendium.shared().get_entry("npcs", gid).is_empty(), "%s is an NPC" % gid)
		var df := DialogueFile.load_key(key)
		assert_true(df != null, "%s has lines" % key)
		if df == null:
			continue
		var kinds := {}
		for node in df.order:
			var kind := node.get_slice("_", 0) + "_"
			assert_true(kind in KINDS, "%s:%s says when it plays" % [key, node])
			kinds[kind] = true
		assert_true(kinds.has("fight_"), "%s has a word after a fight" % gid)
		var text := FileAccess.get_file_as_string(DialogueFile.ROOT + key + ".dialogue")
		for line in text.split("\n"):
			if line.begins_with("interject "):
				assert_true(line.begins_with("interject guest:%s: " % gid), "%s speaks for itself: %s" % [key, line])
				assert_false(line.get_slice(": ", 1).begins_with("("), "%s: spoken words, not a stage direction" % key)
