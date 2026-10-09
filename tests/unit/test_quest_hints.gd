extends TestCase
## Storyline QA (2026-10-09): the journal says what to do next. Every quest in data/quests shows in the journal once
## taken, every stage that doesn't end its quest has a hint there (make validate checks the data the same way, so a new
## quest can't ship without one), and the journal keeps a hint hidden until the player presses for it.


## Every quest at every one of its stages: in the journal, with a hint while it's open, the party's Tarokka reading
## filled in, and no hint once it's over.
func test_every_stage_of_every_quest_has_a_hint() -> void:
	var files := DirAccess.get_files_at("res://data/quests")
	var quests := 0
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		quests += 1
		var qid := f.get_basename()
		var q := Compendium.shared().get_entry("quests", qid)
		assert_false(q.is_empty(), "%s is in the compendium" % qid)
		for s: Variant in q.get("stages", []):
			var stage := s as Dictionary
			var st := StoryState.new()
			Tarokka.ensure_drawn(st)
			assert_true(st.set_quest_stage(qid, str(stage["id"])))
			var entry := _entry(st, qid)
			assert_false(entry.is_empty(), "%s shows in the journal at '%s'" % [qid, stage["id"]])
			var hint := str(entry.get("hint", ""))
			if str(stage.get("ends", "")) != "":
				assert_eq(hint, "", "%s: no hint once it's over ('%s')" % [qid, stage["id"]])
				continue
			assert_true(hint.strip_edges() != "", "%s: '%s' says what to do next" % [qid, stage["id"]])
			assert_false(hint.contains("{"), "%s: '%s' hint has the reading filled in: %s" % [qid, stage["id"], hint])
	assert_true(quests >= 89, "every quest file checked (%d)" % quests)


## The Tarokka quests' hints name the place the party's own reading drew.
func test_the_reading_quests_point_where_the_cards_did() -> void:
	var st := StoryState.new()
	Tarokka.ensure_drawn(st)
	for pair: Array in [["find_the_tome", "tome"], ["find_the_holy_symbol", "symbol"], ["find_the_sunsword", "sword"],
			["find_the_ally", "ally"], ["strahds_lair", "enemy"]]:
		st.set_quest_stage(str(pair[0]), "foretold")
		var where := Tarokka.field(st, "%s.hint" % pair[1])
		assert_true(where != "", "the reading has a %s" % pair[1])
		assert_true(str(_entry(st, str(pair[0]))["hint"]).contains(where), "%s points at %s" % [pair[0], where])


## The journal shows a Hint button under an open quest, and the hint only once it's pressed; pressed again, it hides.
## A finished quest has no button.
func test_the_journal_hides_a_hint_until_asked() -> void:
	var st := StoryState.new()
	st.set_quest_stage("the_oat_thief", "rumored")
	st.set_quest_stage("the_priests_son", "doru_destroyed")
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	var b := j.find_child("Hint_the_oat_thief", true, false) as Button
	assert_true(b != null, "an open quest has a Hint button")
	assert_true(j.find_child("Hint_the_priests_son", true, false) == null, "a finished one doesn't")
	var text := b.get_parent().get_node("HintText") as Label
	var hint := str(_entry(st, "the_oat_thief")["hint"])
	assert_eq(text.text, hint)
	assert_false(text.visible, "hidden until asked")
	b.pressed.emit()
	assert_true(text.visible, "shown once the button is pressed")
	assert_eq(b.text, "Hide hint")
	j.call("_draw")
	b = j.find_child("Hint_the_oat_thief", true, false) as Button
	assert_true((b.get_parent().get_node("HintText") as Label).visible, "still shown when the page is redrawn")
	b.pressed.emit()
	assert_false((b.get_parent().get_node("HintText") as Label).visible, "and hidden again on a second press")
	assert_eq(b.text, "Hint")
	j.free()


func _entry(st: StoryState, quest_id: String) -> Dictionary:
	for q in QuestLog.journal(st):
		if str(q["id"]) == quest_id:
			return q
	return {}
