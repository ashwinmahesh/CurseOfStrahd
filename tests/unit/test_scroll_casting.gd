extends TestCase
## Casting a Spell Scroll outside a fight (2024 DMG; story/field_items.gd): a reader with the spell on their class's list
## casts it from the scroll without its Material components; a spell above the levels they can cast needs a
## spellcasting ability check against 10 + its level; the scroll is used up either way. An exploring spell from a
## scroll (Find Familiar, Detect Magic) works as if cast while exploring.


func _party(ids: Array[String], level: int) -> StoryState:
	var st := StoryState.new()
	for id in ids:
		var ch := TestChars.pregen(id, level)
		ch.finish_long_rest()
		st.party.append(ch)
	return st


func _read(st: StoryState, ch: Character, scroll: String) -> Dictionary:
	for o in FieldItems.options(st.party, ch, scroll, DiceRoller.new(1)):
		if str(o["power_id"]) == "read":
			return o
	return {}


func test_a_wizard_finds_a_familiar_from_a_scroll() -> void:
	var st := _party(["silvain_aster"], 3)
	var wiz := st.party[0]
	wiz.familiar = ""
	wiz.add_item("spell_scroll__find_familiar")
	var o := _read(st, wiz, "spell_scroll__find_familiar")
	assert_false(o.is_empty(), "the scroll offers Read")
	assert_true(bool(o.get("legal", false)), str(o.get("reason", "")))
	var minutes := st.total_minutes()
	var res := FieldItems.use(st, wiz, "spell_scroll__find_familiar", "read", wiz, DiceRoller.new(2))
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(wiz.familiar, "here", "the familiar is with the wizard")
	assert_false(wiz.carries("spell_scroll__find_familiar"), "the scroll is used up")
	assert_true(st.total_minutes() - minutes >= 60, "an hour's casting")


func test_a_reader_without_the_spell_on_their_list_cannot() -> void:
	var st := _party(["ilse_varga"], 3)
	var fighter := st.party[0]
	fighter.add_item("spell_scroll__find_familiar")
	var o := _read(st, fighter, "spell_scroll__find_familiar")
	assert_false(bool(o.get("legal", true)))
	assert_eq(str(o.get("reason", "")), "Not on your class's spell list")
	var res := FieldItems.use(st, fighter, "spell_scroll__find_familiar", "read", fighter, DiceRoller.new(2))
	assert_false(bool(res["ok"]))
	assert_true(fighter.carries("spell_scroll__find_familiar"), "still has it")


func test_an_exploring_spell_from_a_scroll_is_recorded() -> void:
	var st := _party(["silvain_aster"], 3)
	var wiz := st.party[0]
	wiz.add_item("spell_scroll__detect_magic")
	var res := FieldItems.use(st, wiz, "spell_scroll__detect_magic", "read", wiz, DiceRoller.new(2))
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(str(res.get("effect", "")), "detect_magic")
	assert_true(st.active_spells.has("detect_magic"))
	assert_false(wiz.carries("spell_scroll__detect_magic"))


## A level 5 spell is beyond a level 1 wizard: the check is DC 15, and the scroll is gone whether it works or not.
func test_a_scroll_beyond_the_reader_needs_a_check_and_is_spent_either_way() -> void:
	var high := "spell_scroll__teleportation_circle"
	assert_true(Compendium.shared().has("spells", "teleportation_circle"))
	var faded := 0
	for seed_value in 20:
		var st := _party(["silvain_aster"], 1)
		var wiz := st.party[0]
		wiz.add_item(high)
		var res := FieldItems.use(st, wiz, high, "read", wiz, DiceRoller.new(seed_value))
		assert_false(wiz.carries(high), "spent either way")
		if not bool(res["ok"]):
			faded += 1
			assert_true("fades" in str(res.get("text", "")), str(res.get("text", "")))
	assert_true(faded > 0 and faded < 20, "a DC 15 Intelligence check fails sometimes (%d of 20)" % faded)
