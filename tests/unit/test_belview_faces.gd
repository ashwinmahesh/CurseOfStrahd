extends TestCase
## Owner report (2026-10-13): every Belview wore the same dog portrait in conversation. Each named Belview now has a
## face showing its own "improvement" (they still share the one sprite); the kitchen crowd and the Belviews you fight
## keep the family face. Their lines all say "Belview:" in one voice, so a line shows the face of the Belview you're
## talking to (DialogueRunner._face_of) while the voice stays the family's.

const OWN_FACES := ["belview_well", "belview_sweeper", "belview_hauler", "belview_feathers", "belview_gate",
	"belview_mother", "sorin_krezkov", "waystone_lark", "belview_caged_1", "belview_caged_2", "belview_caged_3"]
const DIALOGUE := "~ a\nBelview: Clean for the Abbot.\nClovin Belview: Mind the ice.\n-> END\n"


func before_each() -> void:
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/belview_faces"))


func _lines(npc_id: String) -> Array[Dictionary]:
	var r := DialogueRunner.new(StoryState.new(), DiceRoller.new(2))
	r.npc_id = npc_id
	r.start("test/belview_faces:a")
	var out: Array[Dictionary] = [r.next(), r.next()]
	return out


func test_each_belview_has_its_own_face() -> void:
	var seen := {}
	for id: String in OWN_FACES:
		var npc := Compendium.shared().get_entry("npcs", id)
		var portrait := str(npc["portrait"])
		assert_eq(portrait, id, "%s wears its own portrait" % id)
		assert_eq(str(npc["sprite"]), "belview", "%s still walks as the family sprite" % id)
		assert_true(ArtPaths.exists("art/portraits/%s.png" % portrait), "%s's portrait exists" % id)
		assert_false(seen.has(portrait), "%s's face is its own" % id)
		seen[portrait] = true
	assert_eq(str(Compendium.shared().get_entry("npcs", "belview")["portrait"]), "belview", "the family face stays")


func test_a_belview_line_shows_who_you_are_talking_to() -> void:
	var lines := _lines("belview_sweeper")
	assert_eq(str(lines[0]["portrait"]), "belview_sweeper", "the sweeper's face")
	assert_eq(str(lines[0]["speaker_id"]), "belview", "the family's voice, so the line's clip still plays")
	assert_eq(str(lines[0]["name"]), "Belview")
	assert_eq(str(lines[1]["portrait"]), "clovin_belview", "someone else in the scene keeps their own face")


func test_without_a_namesake_the_speaker_keeps_their_face() -> void:
	assert_eq(str(_lines("")[0]["portrait"]), "belview", "no one spoken to: the family face")
	assert_eq(str(_lines("clovin_belview")[0]["portrait"]), "belview", "talking to Clovin, a plain Belview's line")


func test_the_girl_at_the_well_and_the_kitchen() -> void:
	var by_dialogue := {}
	for loc_id: String in ["abbey_of_st_markovia", "abbey_of_st_markovia_wards"]:
		for n: Variant in Compendium.shared().get_entry("locations", loc_id).get("npcs", []) as Array:
			var d := n as Dictionary
			by_dialogue[str(d.get("dialogue", ""))] = str(d.get("npc", ""))
	assert_eq(str(by_dialogue.get("abbey_of_st_markovia/belviews:courtyard", "")), "belview_well")
	assert_eq(str(by_dialogue.get("abbey_of_st_markovia/belviews:kitchen", "")), "belview", "the kitchen crowd")
