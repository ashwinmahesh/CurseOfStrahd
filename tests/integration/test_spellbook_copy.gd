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
				if (b as Button).text.begins_with("Ratatouille copies it"):
					copy_disguise = b as Button
			after_disguise = false
	var joined := "\n".join(texts)
	assert_true(joined.contains("Spells in this book"), "the card lists the book's spells")
	assert_true(joined.contains("Disguise Self") and joined.contains("Darkness"), "by name")
	assert_true(copy_disguise != null, "Ratatouille can copy Disguise Self")
	assert_false(copy_disguise.disabled, copy_disguise.tooltip_text)
	var t0 := st.total_minutes()
	copy_disguise.pressed.emit()
	await get_tree().process_frame
	assert_true("disguise_self" in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "copied into his book")
	assert_eq(int(st.gold), 70, "50 gp of inks for a level 1 spell")
	assert_eq(st.total_minutes() - t0, 120, "two hours at the desk")
	root.call("close_screen")


## The warden's book from the Amber Temple (Ashwin, 2026-10-18: found spellbooks always hold spells a Wizard can
## learn; that chest held a blank one): at level 10 every spell in it can be copied from the inventory card.
func test_the_wardens_book_from_the_amber_temple_copies_from_the_inventory() -> void:
	Compendium.shared().tables["locations"]["test_study"] = {"id": "test_study", "name": "Test Study", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "ratatoille"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 1000.0
	st.location = "test_study"
	var rat := st.party[1]
	st.party[0].add_item("amber_warden_spellbook", 1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root.call("open_screen", "inventory", 0)
	await get_tree().process_frame
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "amber_warden_spellbook"
	inv.call("_draw")
	var card := inv.get("_card") as Container
	var copies: Array[Button] = []
	var texts: Array[String] = []
	for c in card.get_children():
		for l in c.find_children("*", "Label", true, false):
			texts.append((l as Label).text)
		for b in c.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with("Ratatouille copies it") or (b as Button).text.begins_with("In Ratatouille's book"):
				copies.append(b as Button)
	var joined := "\n".join(texts)
	assert_true(joined.contains("Spells in this book") and joined.contains("Counterspell") and joined.contains("Wall of Force"), joined)
	assert_eq(copies.size(), 9, "a copy button for each of the nine spells")
	for b in copies:
		if b.text.begins_with("Ratatouille copies it"):
			assert_false(b.disabled, "%s: %s" % [b.text, b.tooltip_text])
	var counter: Button = null
	for b2 in copies:
		if b2.text.begins_with("Ratatouille copies it") and b2.tooltip_text.contains("Into Ratatouille's spellbook"):
			counter = b2
			break
	assert_true(counter != null, "something left to copy")
	var before := (rat.spellcasting_entry("wizard")["spellbook"] as Array).size()
	counter.pressed.emit()
	await get_tree().process_frame
	assert_eq((rat.spellcasting_entry("wizard")["spellbook"] as Array).size(), before + 1, "one more spell in his book")
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
	assert_true(back.party[1].carries("spellbook"), "Ratatouille's own spellbook stays his")
	var fresh := StoryState.from_dict(StoryState.new().to_dict())
	assert_false(fresh.party_has_item("durst_spellbook"), "a save that never opened the footlocker is left alone")


# --- Spell Scrolls (Ashwin, 2026-10-18; FieldItems.copy_scroll) -------------------------------------------------

## A seed whose Arcana check for `w` against `dc` succeeds (or fails), so a test can count on the outcome.
func _seed_for(w: Character, dc: int, succeed: bool) -> int:
	for s in range(1, 400):
		if w.roll_check(DiceRoller.new(s), &"arcana", dc).success == succeed:
			return s
	return -1


func _party_with_scroll(scroll: String, level: int) -> StoryState:
	var st := StoryState.new()
	for id: String in ["godrick_pendlebrook", "ratatoille", "liriel_dawnsong"]:
		st.party.append(Pregens.build(id, level))
	st.gold = 500.0
	st.party[0].add_item(scroll, 1)
	return st


func test_a_wizard_copies_a_spell_scroll_after_an_arcana_check() -> void:
	var st := _party_with_scroll("spell_scroll__slow", 5)
	var godrick := st.party[0]
	var rat := st.party[1]
	var terms := FieldItems.scroll_copy_terms("spell_scroll__slow")
	assert_eq([int(terms["level"]), int(terms["dc"]), int(terms["gp"]), int(terms["minutes"])], [3, 13, 150, 360],
		"level 3: DC 13, 150 gp and 6 hours (the PHB's 2 hours and 50 GP a level)")
	assert_eq(FieldItems.copy_scroll_problem(st, rat, "spell_scroll__slow"), "")
	var t0 := st.total_minutes()
	var res := FieldItems.copy_scroll(st, godrick, "spell_scroll__slow", rat, DiceRoller.new(_seed_for(rat, 13, true)))
	assert_true(bool(res["ok"]) and bool(res["copied"]), str(res))
	assert_true("slow" in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "Slow is in his book")
	assert_false(godrick.carries("spell_scroll__slow"), "the scroll is used up")
	assert_eq(int(st.gold), 350, "150 gp of inks")
	assert_eq(st.total_minutes() - t0, 360, "six hours at the desk")
	assert_eq(rat.copy_scroll_problem("spell_scroll__slow"), "Already in the spellbook")


func test_a_failed_check_loses_the_scroll_and_the_inks() -> void:
	var st := _party_with_scroll("spell_scroll__lightning_bolt", 5)
	var rat := st.party[1]
	var seed_fail := _seed_for(rat, 13, false)
	assert_true(seed_fail > 0, "some roll fails DC 13")
	var res := FieldItems.copy_scroll(st, st.party[0], "spell_scroll__lightning_bolt", rat, DiceRoller.new(seed_fail))
	assert_true(bool(res["ok"]) and not bool(res["copied"]), str(res))
	assert_false("lightning_bolt" in (rat.spellcasting_entry("wizard")["spellbook"] as Array), "not copied")
	assert_false(st.party[0].carries("spell_scroll__lightning_bolt"), "the scroll crumbles all the same (2024 DMG)")
	assert_eq(int(st.gold), 350, "and the inks are spent")
	assert_true(str(res["text"]).contains("crumbles"), str(res["text"]))


func test_only_a_wizard_and_only_a_wizard_spell_they_can_prepare() -> void:
	var st := _party_with_scroll("spell_scroll__fireball", 1)
	var rat := st.party[1]
	var liriel := st.party[2]
	assert_eq(FieldItems.copy_scroll_problem(st, liriel, "spell_scroll__fireball"), "Only a Wizard can copy spells into a spellbook")
	assert_eq(FieldItems.copy_scroll_problem(st, rat, "spell_scroll__fireball"), "Level 3: too high to prepare yet")
	assert_eq(rat.copy_scroll_problem("spell_scroll__cure_wounds"), "Not a Wizard spell")
	assert_eq(rat.copy_scroll_problem("spell_scroll__fire_bolt"), "Cantrips aren't copied into a spellbook")
	assert_eq(rat.copy_scroll_problem("potion_of_healing"), "Not a scroll of one spell")
	st.gold = 10.0
	assert_eq(FieldItems.copy_scroll_problem(st, rat, "spell_scroll__alarm"), "Needs 50 gp of inks; the party has 10")
	var res := FieldItems.copy_scroll(st, st.party[0], "spell_scroll__fireball", liriel, DiceRoller.new(1))
	assert_false(bool(res["ok"]), "a Cleric can't")
	assert_true(st.party[0].carries("spell_scroll__fireball"), "and nothing is used up")
	assert_eq(int(st.gold), 10, "or spent")


func test_the_scroll_card_offers_only_the_wizard_a_copy_with_a_second_press() -> void:
	Compendium.shared().tables["locations"]["test_study"] = {"id": "test_study", "name": "Test Study", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "ratatoille", "liriel_dawnsong"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.gold = 500.0
	st.location = "test_study"
	st.party[0].add_item("spell_scroll__stinking_cloud", 1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root.call("open_screen", "inventory", 0)
	await get_tree().process_frame
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "spell_scroll__stinking_cloud"
	inv.call("_draw")
	assert_true(_card_text(inv).contains("Copy into a spellbook"), _card_text(inv))
	assert_true(_card_text(inv).contains("Pass or fail, the scroll is used up"), "the risk is shown before")
	assert_true(_card_button(inv, "Liriel copies") == null, "a Cleric isn't offered it")
	var copy := _card_button(inv, "Ratatouille copies it")
	assert_true(copy != null and not copy.disabled, "Ratatouille is")
	assert_true(copy.text.contains("6 h") and copy.text.contains("150 gp") and copy.text.contains("DC 13"), copy.text)
	assert_true(copy.focus_mode != Control.FOCUS_NONE, "reachable by keyboard and pad")
	copy.pressed.emit()
	await get_tree().process_frame
	var go := _card_button(inv, "Copy it: Ratatouille rolls Arcana")
	assert_true(go != null and bool(go.get_meta("pad_first", false)), "a second press to confirm, focused for the pad")
	assert_true(st.party[0].carries("spell_scroll__stinking_cloud"), "nothing happens on the first press")
	_card_button(inv, "Keep the scroll").pressed.emit()
	await get_tree().process_frame
	assert_true(_card_button(inv, "Copy it:") == null, "Keep the scroll backs out")
	_card_button(inv, "Ratatouille copies it").pressed.emit()
	await get_tree().process_frame
	_card_button(inv, "Copy it: Ratatouille rolls Arcana").pressed.emit()
	await get_tree().process_frame
	assert_false(st.party[0].carries("spell_scroll__stinking_cloud"), "the scroll is used")
	assert_eq(int(st.gold), 350, "the inks paid")
	assert_true(_card_text(inv).contains("Stinking Cloud"), "and the card says how it went: %s" % _card_text(inv))
	root.call("close_screen")


func test_a_party_without_a_wizard_is_told_who_could() -> void:
	Compendium.shared().tables["locations"]["test_study"] = {"id": "test_study", "name": "Test Study", "region": "test",
		"summary": "", "map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	var st := GameState.story
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong"]:
		st.party.append(Pregens.build(id, 5))
	st.location = "test_study"
	st.party[0].add_item("spell_scroll__fireball", 1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame
	root.call("open_screen", "inventory", 0)
	await get_tree().process_frame
	var inv := root.get("screen") as InventoryScreen
	inv.selected = "spell_scroll__fireball"
	inv.call("_draw")
	assert_true(_card_text(inv).contains("A Wizard could copy Fireball"), _card_text(inv))
	assert_true(_card_button(inv, "copies it") == null, "and no copy button")
	root.call("close_screen")


func _card_text(inv: InventoryScreen) -> String:
	var out: Array[String] = []
	for l in (inv.get("_card") as Node).find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


func _card_button(inv: InventoryScreen, starts: String) -> Button:
	for b in (inv.get("_card") as Node).find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(starts) or (b as Button).text.contains(starts):
			if not (b as Button).is_queued_for_deletion():
				return b as Button
	return null
