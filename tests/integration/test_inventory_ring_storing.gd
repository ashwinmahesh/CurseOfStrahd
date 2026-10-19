extends TestCase
## The Ring of Spell Storing's card on the inventory screen (owner, 2026-10-19): who casts, which spell, then the level to
## store it at, one button for each level the ring has room for and the caster has a slot to cast it at. A level 11
## warlock (three 5th-level pact slots) can cast down into the ring; a wizard stays with the slots it has.

const RING := "ring_of_spell_storing"

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["ring_inn"] = {"id": "ring_inn", "name": "Ring Inn", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for pair: Array in [["kip_smudgewick", 11], ["silvain_aster", 5]]:
		var ch := Pregens.build(str(pair[0]), int(pair[1]))
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "ring_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("ring_inn")
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The ring on hero `i`, holding `stored` levels of spells, and their inventory open on it.
func _open(i: int, stored: Array = []) -> InventoryScreen:
	var ch := GameState.story.party[i]
	ch.add_item(RING)
	var held := []
	for lvl: int in stored:
		held.append({"spell": "magic_missile", "level": lvl, "dc": 15, "attack": 7, "ability": "int"})
	ch.entry_of(RING)["stored"] = held
	root.call("open_screen", "inventory", i)
	await _frames(2)
	var inv := root.get("screen") as InventoryScreen
	inv.selected = RING
	inv.call("_draw")
	await _frames(1)
	return inv


func _pickers(inv: InventoryScreen) -> Array[OptionButton]:
	var out: Array[OptionButton] = []
	for n in (inv.get("_card") as Node).find_children("*", "OptionButton", true, false):
		out.append(n as OptionButton)
	return out


func _level_buttons(inv: InventoryScreen) -> Array[Button]:
	var out: Array[Button] = []
	for n in (inv.get("_card") as Node).find_children("*", "Button", true, false):
		if (n as Button).text.begins_with("Level ") and not n.is_queued_for_deletion():
			out.append(n as Button)
	return out


func _levels(inv: InventoryScreen) -> Array:
	return _level_buttons(inv).map(func(b: Button) -> String: return b.text)


## Picks the spell whose entry in the spell picker starts with `name`.
func _choose_spell(inv: InventoryScreen, name: String) -> bool:
	var what := _pickers(inv)[1]
	for i in what.item_count:
		if what.get_item_text(i).begins_with(name):
			what.select(i)
			what.item_selected.emit(i)
			return true
	return false


func _card_text(inv: InventoryScreen) -> String:
	var out: Array[String] = []
	for n in (inv.get("_card") as Node).find_children("*", "Label", true, false):
		if (n as Label).is_visible_in_tree():
			out.append((n as Label).text)
	return "\n".join(out)


func test_a_warlock_picks_the_level_to_store_a_spell_at() -> void:
	var kip := GameState.story.party[0]
	var inv := await _open(0, [3])   # three of five levels taken: two left
	assert_eq(_pickers(inv).size(), 2, "who casts, and which spell")
	var first_level := 1
	# The spells are listed lowest first, and the levels are the room that's left, down from nothing above the room.
	assert_eq(_levels(inv), ["Level 1", "Level 2"], "two levels of room")
	assert_true(_card_text(inv).contains("Pact Magic slot is spent"), _card_text(inv))
	var buttons := _level_buttons(inv)
	buttons[0].pressed.emit()   # level 1
	await _frames(2)
	var ring := kip.entry_of(RING)
	assert_eq((ring["stored"] as Array).size(), 2, "a spell went in")
	assert_eq(int(((ring["stored"] as Array)[1] as Dictionary)["level"]), first_level, "at the level chosen")
	assert_eq(int(kip.pact_magic()["left"]), 2, "one pact slot spent")
	assert_true(_card_text(inv).contains("Pact Magic slot"), "and it says so:\n%s" % _card_text(inv))


func test_the_levels_follow_the_spell() -> void:
	var inv := await _open(0)
	assert_eq(_levels(inv), ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5"], "a level 1 spell, an empty ring")
	var what := _pickers(inv)[1]
	var third := -1
	for i in what.item_count:
		if what.get_item_text(i).ends_with("(level 3)") and third < 0:
			third = i
	assert_true(third >= 0, "Kip has a level 3 spell")
	what.select(third)
	what.item_selected.emit(third)
	await _frames(1)
	assert_eq(_levels(inv), ["Level 3", "Level 4", "Level 5"], "never below the spell's own level")


func test_a_wizard_is_offered_only_the_slots_it_has() -> void:
	var inv := await _open(1)
	var wiz := GameState.story.party[1]
	var who := _pickers(inv)[0]
	assert_eq(who.item_count, 2, "both casters can cast into it")
	assert_eq(who.get_item_text(1), "Silvain")
	who.select(1)
	who.item_selected.emit(1)
	await _frames(1)
	var levels := _levels(inv)
	assert_false(levels.is_empty())
	for text: String in levels:
		assert_true(wiz.slots_left(int(text.trim_prefix("Level "))) > 0, text)
	assert_false(_card_text(inv).contains("Pact Magic slot is spent"), "a wizard spends the slot of the level it picks")
	var spend := _level_buttons(inv)[0]
	var lvl := int(spend.text.trim_prefix("Level "))
	var before := wiz.slots_left(lvl)
	spend.pressed.emit()
	await _frames(2)
	assert_eq(wiz.slots_left(lvl), before - 1)


func test_a_full_ring_says_why_and_offers_no_pickers() -> void:
	var inv := await _open(0, [5])
	assert_true(_pickers(inv).is_empty())
	assert_true(_level_buttons(inv).is_empty())
	assert_true(_card_text(inv).contains("Nobody can cast a spell that fits"), _card_text(inv))


func test_a_warlock_with_the_pact_slots_spent_is_not_offered() -> void:
	var kip := GameState.story.party[0]
	kip.pact_slots_used = int(kip.pact_magic()["count"])
	var inv := await _open(0)
	var who := _pickers(inv)[0]
	assert_eq(who.item_count, 1, "only the wizard can cast it in now")
	assert_eq(who.get_item_text(0), "Silvain", "no pact slot, no level to store at for Kip")
