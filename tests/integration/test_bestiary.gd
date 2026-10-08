extends TestCase
## The bestiary (Improvement Ideas U8, story/bestiary.gd and the journal's Bestiary tab): a fight writes down the
## creatures met and felled and what a Study placed, a creature studied once shows its defenses from the start of
## later fights, it's kept in the save, and the journal's page shows more as the party learns more.

var st: StoryState


func before_each() -> void:
	st = StoryState.new()
	st.day = 3
	st.location = "village_of_barovia"


func _fight(foes: Array[String]) -> Encounter:
	var e := TestCombat.open_field()
	TestCombat.hero(e, "hedda_ironvow", Vector2i(1, 1))
	var x := 5
	for id in foes:
		TestCombat.foe(e, id, Vector2i(x, 3))
		x += 2
	return e


func test_a_fight_writes_down_what_was_met_felled_and_studied() -> void:
	var e := _fight(["zombie", "zombie", "wolf"])
	Bestiary.before_fight(st, e)
	assert_eq(Bestiary.met(st), ["zombie", "wolf"] as Array[String], "met in the order they stood")
	assert_eq(Bestiary.level(st, "zombie"), 1)
	# One zombie falls; the wolf is studied and gets away.
	for c in e.combatants:
		if Bestiary.monster_id(c) == "zombie":
			c.creature.take_damage(c.creature.hp, &"slashing")
			break
	e.studied["wolf"] = true
	Bestiary.after_fight(st, e)
	assert_eq(int((st.bestiary["zombie"] as Dictionary)["defeated"]), 1)
	assert_eq(Bestiary.level(st, "zombie"), 2, "felled: how tough it is")
	assert_eq(Bestiary.level(st, "wolf"), 3, "studied: its defenses")
	assert_eq(int((st.bestiary["wolf"] as Dictionary)["met"]), 3, "the day it was met")
	assert_eq(str((st.bestiary["wolf"] as Dictionary)["where"]), "village_of_barovia")
	assert_false(st.bestiary.has("hedda_ironvow"), "the party's own aren't in it")


func test_a_studied_creature_stays_known() -> void:
	st.bestiary["vampire_spawn"] = {"n": 0, "met": 1, "where": "", "defeated": 0, "studied": true}
	var e := _fight(["vampire_spawn"])
	Bestiary.before_fight(st, e)
	assert_true(e.studied.has("vampire_spawn"), "its defenses show from the first round")
	var target: Combatant = null
	for c in e.combatants:
		if c.side == &"enemy":
			target = c
	var info := ActionCatalog.new(e)._known_defenses(target)
	assert_true(info.contains("necrotic"), "the attack preview names its resistance: %s" % info)


func test_the_bestiary_is_saved() -> void:
	var e := _fight(["wolf"])
	Bestiary.before_fight(st, e)
	e.studied["wolf"] = true
	Bestiary.after_fight(st, e)
	var back := StoryState.from_dict(JSON.parse_string(JSON.stringify(st.to_dict())) as Dictionary)
	assert_eq(Bestiary.level(back, "wolf"), 3, "loads back as it was")


func test_the_journal_page_grows_with_what_is_known() -> void:
	st.bestiary["zombie"] = {"n": 0, "met": 1, "where": "village_of_barovia", "defeated": 0}
	var met := _text(BestiaryPage.entry(st, "zombie"))
	assert_true(met.contains("Zombie") and met.contains("Village of Barovia"), "met: who and where")
	assert_true(met.contains("Fell one to learn"), "says how to learn more")
	assert_false(met.contains("Armor Class"), "toughness not known yet")
	st.bestiary["zombie"]["defeated"] = 2
	var felled := _text(BestiaryPage.entry(st, "zombie"))
	assert_true(felled.contains("Armor Class") and felled.contains("Hit Points"), "felled: how tough it is")
	assert_true(felled.contains("Study one in a fight"), "defenses still unknown")
	st.bestiary["zombie"]["studied"] = true
	var studied := _text(BestiaryPage.entry(st, "zombie"))
	assert_true(studied.contains("Challenge 1/4") and studied.contains("Poison"), "studied: its challenge and immunity")
	var empty := BestiaryPage.build(StoryState.new(), "", func(_id: String) -> void: pass)
	assert_true(_text(empty).contains("No creatures yet"))


func test_the_journal_has_a_bestiary_tab() -> void:
	st.bestiary["wolf"] = {"n": 0, "met": 1, "where": "", "defeated": 1}
	st.bestiary["zombie"] = {"n": 1, "met": 2, "where": "", "defeated": 0}
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	j.tab = "Bestiary"
	j.call("_draw")
	await get_tree().process_frame
	assert_true(_text(j).contains("Wolf"), "the first creature shows")
	(j.find_child("zombie", true, false) as Control).find_children("*", "BaseButton", true, false)[0].emit_signal("pressed")
	await get_tree().process_frame
	assert_eq(j.beast, "zombie", "a click on the list picks it")
	assert_true(_text(j.find_child("Entry", true, false)).contains("Zombie"))
	j.queue_free()


## Every Label's and RichTextLabel's text under `n`.
func _text(n: Node) -> String:
	var parts: Array[String] = []
	for c in n.find_children("*", "Label", true, false):
		parts.append((c as Label).text)
	for c in n.find_children("*", "RichTextLabel", true, false):
		parts.append((c as RichTextLabel).get_parsed_text())
	if n is Label:
		parts.append((n as Label).text)
	var out := "\n".join(parts)
	if not n.is_inside_tree():
		n.free()
	return out
