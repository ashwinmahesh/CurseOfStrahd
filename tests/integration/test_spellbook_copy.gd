extends TestCase
## Found spellbooks (owner, 2026-10-07): anyone can read the spells in one, and a Wizard can copy them into their own
## book under the 2024 rules (a level they can prepare, 2 hours and 50 gp of inks per spell level, outside fights),
## then prepare them like any other (Character.copy_spell; the inventory card's "Spells in this book").

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func test_a_wizard_copies_what_they_can_prepare() -> void:
	var rat := Pregens.build("ratatoille", 1)
	assert_eq(rat.spellbook_class(), "wizard")
	assert_eq(rat.copy_spell_problem("unseen_servant"), "")
	assert_eq(rat.copy_spell_problem("darkness"), "Level 2: too high to prepare yet")
	assert_eq(rat.copy_spell_problem("magic_missile"), "Already in the spellbook")
	assert_eq(rat.copy_spell_problem("cure_wounds"), "Not a Wizard spell")
	assert_eq(rat.copy_spell_problem("fire_bolt"), "Cantrips aren't copied into a spellbook")
	assert_true(rat.copy_spell("unseen_servant"))
	assert_true("unseen_servant" in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "it's in the book")
	assert_eq(rat.copy_spell_problem("unseen_servant"), "Already in the spellbook")
	assert_false(rat.copy_spell("darkness"), "a level 2 spell waits for level 3")
	var back := Character.from_dict(rat.to_dict())
	assert_true("unseen_servant" in (back.spellcasting_entry("wizard")["spellbook"] as Array), "and it stays there after a save")


func test_a_copied_spell_can_be_prepared() -> void:
	var rat := Pregens.build("ratatoille", 3)
	assert_true(rat.copy_spell("darkness"))
	var prep: Choice = null
	for c in rat.choice_defs:
		if c.key == "wizard.prepared":
			prep = c
	assert_true(prep != null)
	ChoiceOptions.populate(prep, rat)
	var opt := prep.option("darkness")
	assert_true(opt != null and opt.legal, "Darkness can be prepared once it's in the book")


func test_only_a_wizard_copies() -> void:
	var liriel := Pregens.build("liriel_dawnsong", 3)
	assert_eq(liriel.spellbook_class(), "")
	assert_eq(liriel.copy_spell_problem("unseen_servant"), "Only a Wizard can copy spells into a spellbook")
	assert_false(liriel.copy_spell("unseen_servant"))


func test_the_dursts_book_shows_its_spells_and_a_wizard_copies_from_the_inventory() -> void:
	Compendium.shared().tables["locations"]["test_study"] = {"id": "test_study", "name": "Test Study", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "ratatoille", "liriel_dawnsong"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 120.0
	st.location = "test_study"
	var godrick := st.party[0]
	var rat := st.party[1]
	godrick.add_item("durst_spellbook", 1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root.call("open_screen", "inventory", 0)
	await get_tree().process_frame
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "durst_spellbook"
	inv.call("_draw")
	var card := inv.get("_card") as Container
	var texts: Array[String] = []
	var copy_disguise: Button = null
	var after_disguise := false
	for c in card.get_children():
		for l in c.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
			if (l as Label).text.begins_with("Disguise Self"):
				after_disguise = true
		if c is Label:
			texts.append((c as Label).text)
		if after_disguise and c is HFlowContainer:
			for b in c.find_children("*", "Button", true, false):
				if (b as Button).text.begins_with("Ratatoille copies it"):
					copy_disguise = b as Button
			after_disguise = false
	var joined := "\n".join(texts)
	assert_true(joined.contains("Spells in this book"), "the card lists the book's spells")
	assert_true(joined.contains("Disguise Self") and joined.contains("Darkness"), "by name")
	assert_true(copy_disguise != null, "Ratatoille can copy Disguise Self")
	assert_false(copy_disguise.disabled, copy_disguise.tooltip_text)
	var t0 := st.total_minutes()
	copy_disguise.pressed.emit()
	await get_tree().process_frame
	assert_true("disguise_self" in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "copied into his book")
	assert_eq(int(st.gold), 70, "50 gp of inks for a level 1 spell")
	assert_eq(st.total_minutes() - t0, 120, "two hours at the desk")
	root.call("close_screen")


func test_an_older_save_gets_the_dursts_book_back() -> void:
	# Before 2026-10-07 the footlocker held a plain spellbook; a save that looted it now carries the Dursts' book.
	var st := StoryState.new()
	var godrick := Pregens.build("godrick_pendlebrook", 1)
	var rat := Pregens.build("ratatoille", 1)
	st.party.append(godrick)
	st.party.append(rat)
	godrick.add_item("spellbook", 1)
	st.loc_state("death_house_dungeon_1")
	(st.location_states["death_house_dungeon_1"]["looted"] as Dictionary)["durst_footlocker"] = true
	var back := StoryState.from_dict(st.to_dict())
	assert_true(back.party[0].carries("durst_spellbook"), "Godrick's plain book was the Dursts'")
	assert_false(back.party[0].carries("spellbook"))
	assert_true(back.party[1].carries("spellbook"), "Ratatoille's own spellbook stays his")
	var fresh := StoryState.from_dict(StoryState.new().to_dict())
	assert_false(fresh.party_has_item("durst_spellbook"), "a save that never opened the footlocker is left alone")
