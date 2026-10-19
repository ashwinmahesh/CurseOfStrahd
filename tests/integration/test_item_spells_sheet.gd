extends TestCase
## The character sheet's Spells tab lists the spells an item gives (ItemSpells) under the item's name with what it has left,
## casts them outside a fight (a "Cast on…" menu for a spell that goes on others), follows the item being worn or taken
## off, says why a spell can't be cast, and keeps to its frame.

## The staffs are built on a quarterstaff (a template with one base), so they are carried under these ids.
const STAFF := "staff_of_healing__quarterstaff"
const FIRE := "staff_of_fire__quarterstaff"

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func _staff(ch: Character) -> void:
	ch.add_item(STAFF)
	ch.equip(STAFF, "main_hand")
	assert_true(ch.attune(STAFF), "a cleric attunes to it")


func _sheet(index: int) -> CharacterSheetScreen:
	root.call("open_screen", "sheet", index)
	var sheet := root.get("screen") as CharacterSheetScreen
	sheet.show_tab("Spells")
	return sheet


func _labels(sheet: CharacterSheetScreen) -> Dictionary:
	var out := {}
	for l in sheet.find_children("*", "Label", true, false):
		out[(l as Label).text] = true
	return out


## The row of `spell` under the heading `heading` (an item's), or null.
func _row(sheet: CharacterSheetScreen, heading: String, spell: String) -> Control:
	for l in sheet.find_children("*", "Label", true, false):
		if (l as Label).text != heading:
			continue
		var section := l.get_parent()
		var box := section.get_parent()
		for i in range(section.get_index() + 1, box.get_child_count()):
			var child := box.get_child(i)
			if child.find_children("*", "Label", true, false).any(func(x: Node) -> bool: return (x as Label).text.begins_with("From the ")):
				return null   # the next item's heading: not under this one
			if child.find_children("*", "Label", true, false).any(func(x: Node) -> bool: return (x as Label).text == spell):
				return child as Control
	return null


func _menu(row: Control) -> MenuButton:
	for mb in row.find_children("*", "MenuButton", true, false):
		return mb as MenuButton
	return null


func _button(row: Control, text: String) -> Button:
	for b in row.find_children("*", "Button", true, false):
		if (b as Button).text == text and not b is MenuButton and not b is OptionButton:
			return b as Button
	return null


func test_the_staffs_spells_are_listed_under_it_and_cast_from_the_sheet() -> void:
	var hedda := GameState.story.party[2]
	var ilse := GameState.story.party[0]
	_staff(hedda)
	var charges := hedda.charges_left(STAFF)
	var sheet := _sheet(2)
	var shown := _labels(sheet)
	assert_true(shown.has("From the Staff of Healing"), "a heading for the item")
	assert_true(shown.has("%d/10 charges" % charges), "with its charges")
	var row := _row(sheet, "From the Staff of Healing", "Cure Wounds")
	assert_true(row != null, "Cure Wounds under the staff")
	if row == null:
		return
	assert_true(_labels_of(row).has("1 charge"), "what it costs, on the row")
	var menu := _menu(row)
	assert_true(menu != null, "a Cast on… menu")
	if menu == null:
		return
	ilse.hp = 1
	menu.get_popup().id_pressed.emit(0)
	assert_true(ilse.hp > 1, "Ilse healed")
	assert_eq(hedda.charges_left(STAFF), charges - 1, "a charge spent")
	assert_true(_labels(sheet).has("%d/10 charges" % (charges - 1)), "the heading shows what is left")
	assert_true(_labels(sheet).has(str(sheet.get("_cast_note"))), "what the cast did is shown")


func _labels_of(row: Control) -> Dictionary:
	var out := {}
	for l in row.find_children("*", "Label", true, false):
		out[(l as Label).text] = true
	return out


func test_taking_the_item_off_takes_its_spells_off_the_list() -> void:
	var hedda := GameState.story.party[2]
	_staff(hedda)
	var sheet := _sheet(2)
	assert_true(_labels(sheet).has("From the Staff of Healing"))
	hedda.unequip_item(STAFF)
	sheet.call("_draw")
	assert_false(_labels(sheet).has("From the Staff of Healing"), "gone with the staff")


func test_a_hero_who_casts_nothing_still_gets_the_list() -> void:
	var ilse := GameState.story.party[0]
	ilse.add_item("rod_of_alertness")
	ilse.equip("rod_of_alertness", "main_hand")
	assert_true(ilse.attune("rod_of_alertness"))
	var sheet := _sheet(0)
	var shown := _labels(sheet)
	assert_true(shown.has("From the Rod of Alertness"), "the item's heading")
	assert_false(shown.has("Ilse doesn't cast spells."), "she casts its spells")
	assert_true(_row(sheet, "From the Rod of Alertness", "Detect Magic") != null)
	assert_true(_labels_of(_row(sheet, "From the Rod of Alertness", "Detect Magic")).has("At will"))


func test_a_spell_that_cannot_be_cast_now_says_why_on_the_page() -> void:
	var hedda := GameState.story.party[2]
	_staff(hedda)
	hedda.entry_of(STAFF)["charges"] = 0
	var sheet := _sheet(2)
	var row := _row(sheet, "From the Staff of Healing", "Cure Wounds")
	assert_true(row != null)
	if row == null:
		return
	assert_true(_labels_of(row).has("Not enough charges (0 left, needs 1)"), "the reason is written, not only in a tooltip")
	var cast := _button(row, "Cast")
	assert_true(cast != null and cast.disabled, "Cast is off")
	assert_true(_menu(row) == null, "and there is no menu to pick from")


func test_a_fight_only_spell_is_listed_without_a_cast_button() -> void:
	var silvain := GameState.story.party[3]
	silvain.add_item(FIRE)
	silvain.equip(FIRE, "main_hand")
	if not silvain.attune(FIRE):
		return   # not a class the staff takes: nothing to check here
	var sheet := _sheet(3)
	var row := _row(sheet, "From the Staff of Fire", "Fireball")
	assert_true(row != null, "listed")
	if row == null:
		return
	assert_true(_button(row, "Cast") == null and _menu(row) == null, "nothing to press outside a fight")
	var facts := ""
	for l in row.find_children("*", "Label", true, false):
		facts += (l as Label).text + "|"
	assert_true(facts.contains(ItemSpells.FIGHT_ONLY), facts)


func test_the_page_keeps_to_its_frame_and_every_tooltip_builds() -> void:
	var hedda := GameState.story.party[2]
	_staff(hedda)
	hedda.add_item("rod_of_alertness")
	hedda.add_item("orb_of_dragonkind")
	assert_true(hedda.attune("orb_of_dragonkind"))
	var sheet := _sheet(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := sheet.get("_scroll") as ScrollContainer
	assert_true(scroll != null)
	if scroll == null:
		return
	var frame := scroll.get_global_rect()
	for r in scroll.find_children("*", "Control", true, false):
		var c := r as Control
		if not c.is_visible_in_tree() or c.size.x <= 0.0:
			continue
		assert_true(c.get_global_rect().end.x <= frame.end.x + 1.0, "%s (%s) stays inside the pane" % [c.name, c.get_class()])
	var tips := 0
	for node in sheet.find_children("*", "", true, false):
		if node is UiParts.Tipped and (node as UiParts.Tipped).tip.is_valid():
			var t := ((node as UiParts.Tipped).tip.call()) as Control
			assert_true(t != null, "a tooltip built nothing")
			if t != null:
				t.free()
			tips += 1
	assert_true(tips > 5, "tooltips (%d)" % tips)
