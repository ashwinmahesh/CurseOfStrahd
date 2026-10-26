extends TestCase
## What a hero or a guest is doing by the camp fire (Resume packages, Allies item 4: "some party lines during camp are missing their
## lines"). The Narrator's camp:<id> lines are keyed by the creature's id; Hedda, Ilse, Silvain and Tamsin had none and fell back to
## camp:someone, and Izek (a guest since the allies plan's Z2) had none either and fell back to camp:guest. Each has three now: two
## plain and one for the night, in narrative/narrator/camp.dialogue (docs/story/camp.md, docs/plans/gemini_allies/camp_lines/).

const NEW_HEROES: Array[String] = ["hedda_ironvow", "ilse_varga", "silvain_aster", "tamsin_tealeaf"]
## What no camp line may say: the camp is anywhere (the wild, a street, a house, a dungeon), so nothing of the sky, the weather or the
## trees (a word on its own: "starts" and a block of wood are fine).
const ANYWHERE_BANNED := "\\b(trees?|woods|forest|sky|stars?|moon|doorways?|roof|rain|snow|wind|fog|dawn)\\b"
## Narrator words that are game terms.
const GAME_WORDS: Array[String] = ["turn ", "target", "attack", "combat", "hit points", "spell slot", "roll ", "level", "cantrip", "{"]


func _lines(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in DialogueFile.load_key("narrator/camp").nodes.get(key, []):
		if str(s["t"]) == "variant":
			out.append(s)
	return out


func test_every_roster_hero_and_the_four_retired_ones_have_lines_of_their_own() -> void:
	## The roster (data/pregens `roster: true`) is the six companions; Hedda, Ilse, Silvain and Tamsin are the original four, retired
	## from it and kept for old saves (CampSite.retired), where one in the party still sat by the fire with camp:someone's line.
	assert_eq(Pregens.roster_ids().size(), 6, "the roster is six")
	for id: String in Pregens.roster_ids() + NEW_HEROES:
		assert_true(_lines("camp:" + id).size() >= 3, "%s has idle lines of their own (else they say camp:someone's)" % id)
	for id: String in NEW_HEROES:
		assert_false(id in Pregens.roster_ids(), "%s is retired from the roster" % id)


func test_each_new_set_is_two_plain_lines_and_one_for_the_night() -> void:
	for key: String in ["camp:hedda_ironvow", "camp:ilse_varga", "camp:silvain_aster", "camp:tamsin_tealeaf", "camp:guest:izek"]:
		var lines := _lines(key)
		assert_eq(lines.size(), 3, key)
		var night := 0
		for s in lines:
			if str(s["cond"]) == "night":
				night += 1
			else:
				assert_eq(str(s["cond"]), "", "%s: the plain lines have no condition" % key)
		assert_eq(night, 1, "%s: one for the night" % key)


func test_the_lines_are_short_name_their_person_and_read_right_anywhere() -> void:
	var names := {"camp:hedda_ironvow": "Hedda", "camp:ilse_varga": "Ilse", "camp:silvain_aster": "Silvain", "camp:tamsin_tealeaf": "Tamsin", "camp:guest:izek": "Izek"}
	for key: String in names:
		for s in _lines(key):
			var t := str(s["text"])
			assert_true(t.begins_with(str(names[key])), "%s starts with the name, as the others do: %s" % [key, t])
			assert_true(t.split(" ").size() < 35, "one or two sentences under 35 words: " + t)
			assert_true(t.length() == t.to_ascii_buffer().size(), "ASCII only: " + t)
			var scenery := RegEx.create_from_string(ANYWHERE_BANNED).search(t.to_lower())
			assert_true(scenery == null, "nothing of the sky, the weather or the trees: %s" % t)
			for w in GAME_WORDS:
				assert_false(t.to_lower().contains(w), "no game word '%s' in a Narrator line: %s" % [w, t])


func test_a_hero_with_lines_of_their_own_hears_them_before_anyones() -> void:
	for id: String in NEW_HEROES:
		for where: String in [CampSite.WILD, CampSite.TOWN, CampSite.INDOORS]:
			var keys := CampSite.idle_keys(id, false, where)
			assert_true(keys.has("camp:" + id), "%s: their own key is tried" % id)
			assert_true(keys.find("camp:" + id) < keys.find("camp:someone"), "%s: before anyone's" % id)
	var izek := CampSite.idle_keys("izek", true)
	assert_true(izek.find("camp:guest:izek") >= 0 and izek.find("camp:guest:izek") < izek.find("camp:guest"), "Izek's own, before any guest's")
	assert_true(_lines("camp:guest:izek").size() > 0, "and he has lines now, so camp:guest is not what he says")


func test_the_secrets_stay_secret() -> void:
	## The drafts may brush against a hero's story but never say it: no vampire's name, no lost friend's name, no confession.
	var all := ""
	for key: String in ["camp:hedda_ironvow", "camp:ilse_varga", "camp:silvain_aster", "camp:tamsin_tealeaf", "camp:guest:izek"]:
		for s in _lines(key):
			all += str(s["text"]) + "\n"
	for banned: String in ["Strahd", "vampire", "Aurel", "Kestrel", "Tatyana", "Ireena", "stole the locket", "warmth", "sister", "brother"]:
		assert_false(all.contains(banned), "the camp lines never say " + banned)
