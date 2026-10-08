extends TestCase
## The pause menu's Cheat codes page (ui/screens/cheat_codes_page.gd, owner 2026-10-08): a link beside Settings while
## there's a party, a code box that takes the code however it's typed, the item going to the selected hero or the one
## picked, as often as the Give button is pressed, a base to pick for a +1 Weapon or a Spell Scroll, and Escape back to
## the menu.

var menu: PauseMenu
var st: StoryState


func before_each() -> void:
	InputActions.ensure()   # Escape is the game's combat_cancel, as the game root sets it up
	st = StoryState.new()
	st.party.append(TestChars.pregen("ilse_varga", 1))
	st.party.append(TestChars.pregen("godrick_pendlebrook", 1))
	st.leader = 1
	menu = _menu(st)
	await _frames(2)


func after_each() -> void:
	get_tree().paused = false
	if menu != null:
		menu.queue_free()
	menu = null
	CheatCodes.reset()


## The menu's Resume and Escape call this on whatever opened it.
func close_screen() -> void:
	pass


func _menu(state: StoryState) -> PauseMenu:
	var m := PauseMenu.new()
	add_child(m)
	m.open(self, state, 0)
	return m


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open_page() -> CheatCodesPage:
	var link := menu.find_child("CheatCodes", true, false) as Button
	assert_true(link != null, "the menu has a Cheat codes link")
	if link == null:
		return null
	link.pressed.emit()
	await _frames(1)
	var pages := menu.find_children("*", "CheatCodesPage", true, false)
	assert_eq(pages.size(), 1, "the page opened")
	return pages[0] as CheatCodesPage if not pages.is_empty() else null


func _give_button(page: CheatCodesPage) -> Button:
	return page.find_child("Give", true, false) as Button


func _qty(ch: Character, id: String) -> int:
	return int(ch.entry_of(id).get("qty", 0))


func test_the_page_opens_over_the_menu_for_the_selected_hero() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	assert_false((menu.get("_frame") as Control).visible, "the arch hides while the page is up")
	assert_eq(page.recipient(), st.party[1], "the selected hero gets the item")
	assert_true(_give_button(page).disabled, "nothing to give before a code")


func test_a_code_typed_any_way_gives_its_item_again_and_again() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	var godrick := st.party[1]
	var before := _qty(godrick, "arrow")
	var ilse_before := _qty(st.party[0], "arrow")
	page.type_code("35 9a02")
	assert_eq((page.find_child("Code", true, false) as LineEdit).text, "359A02", "kept to hex digits in upper case")
	assert_eq(page.chosen(), "arrow")
	assert_false(_give_button(page).disabled)
	_give_button(page).pressed.emit()
	_give_button(page).pressed.emit()
	(page.find_child("Code", true, false) as LineEdit).text_submitted.emit("359A02")
	assert_eq(_qty(godrick, "arrow"), before + 60, "three bundles of 20")
	var said := page.find_children("*", "Label", true, false).any(func(l: Node) -> bool:
		return (l as Label).text == "Gave Arrow ×20 to Godrick, who now carries %d." % (before + 60))
	assert_true(said, "the page says what was given and how many Godrick has now")
	assert_eq(_qty(st.party[0], "arrow"), ilse_before, "only the hero picked gets them")


func test_picking_another_hero() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	var chips := page.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).text == st.party[0].name.get_slice(" ", 0))
	assert_eq(chips.size(), 1, "a chip for each hero")
	(chips[0] as Button).pressed.emit()
	await _frames(1)
	assert_eq(page.recipient(), st.party[0], "Ilse picked")
	page.type_code(CheatCodes.code_of("sunsword"))
	_give_button(page).pressed.emit()
	assert_true(st.party[0].carries("sunsword"), "Ilse has the Sunsword")
	assert_false(st.party[1].carries("sunsword"), "Godrick doesn't")


func test_an_item_built_on_a_base_asks_which() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	page.type_code(CheatCodes.code_of("weapon_plus_1"))
	var picker := page.find_child("Base", true, false) as OptionButton
	assert_true(picker.is_visible_in_tree(), "the weapon picker shows")
	assert_eq(picker.get_item_text(picker.selected), "Longsword", "the template's default first")
	assert_eq(page.chosen(), "weapon_plus_1__longsword")
	page.pick("weapon_plus_1__dagger")
	assert_eq(page.chosen(), "weapon_plus_1__dagger")
	_give_button(page).pressed.emit()
	assert_true(st.party[1].carries("weapon_plus_1__dagger"), "a +1 Dagger")
	page.type_code(CheatCodes.code_of("arrow"))
	assert_false(picker.is_visible_in_tree(), "a plain item has no picker")


func test_a_code_no_item_has() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	var unused := ""
	for i in 100:
		if CheatCodes.item_for("%06X" % i) == "":
			unused = "%06X" % i
			break
	page.type_code(unused)
	assert_true(_give_button(page).disabled, "nothing to give")
	var said := page.find_children("*", "Label", true, false).any(func(l: Node) -> bool:
		return (l as Label).text == "No item has that code.")
	assert_true(said, "the page says so")
	page.type_code(CheatCodes.code_of("crown_of_horns"))
	assert_true(_give_button(page).disabled, "an item on hold isn't given")


func test_escape_goes_back_to_the_menu() -> void:
	var page: CheatCodesPage = await _open_page()
	if page == null:
		return
	var ev := InputEventAction.new()
	ev.action = &"combat_cancel"
	ev.pressed = true
	page.call("_unhandled_input", ev)
	await _frames(1)
	assert_true((menu.get("_frame") as Control).visible, "the arch is back")
	assert_true(is_instance_valid(menu) and menu.is_inside_tree(), "the menu stays open")


func test_no_party_no_link() -> void:
	menu.queue_free()
	menu = _menu(StoryState.new())
	await _frames(1)
	assert_true(menu.find_child("CheatCodes", true, false) == null, "nobody to give to")
	var settings := menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return (b as Button).text == "◆  Settings  ◆")
	assert_eq(settings.size(), 1, "Settings is still there")
