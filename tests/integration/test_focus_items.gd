extends TestCase
## Magic items that are a spellcasting focus (owner reports, 2026-10-18: "holy symbol of ravenkind still cant be
## equipped as a spellcasting focus"; the Arcane Grimoire is a focus for Wizards, not a spellbook): through the real
## inventory screen, each goes in the doll's Focus slot for the classes whose focus it is, from a drag or the item's
## menu, and the doll then holds it.

const RAVEN := "holy_symbol_of_ravenkind"
const GRIMOIRE := "arcane_grimoire_plus_2"

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["focus_inn"] = {"id": "focus_inn", "name": "Focus Inn", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in ["hedda_ironvow", "godrick_pendlebrook", "ratatoille"]:   # a Cleric, a Paladin, a Wizard
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "focus_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("focus_inn")
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open(i: int) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	return root.get("screen") as InventoryScreen


func _empty_focus_tile(inv: InventoryScreen) -> ItemTile:
	for n in inv.find_children("*", "ItemTile", true, false):
		var t := n as ItemTile
		if not t.is_queued_for_deletion() and t.payload.is_empty() and t.caption == "Focus":
			return t
	return null


func _card_text(inv: InventoryScreen) -> String:
	var out: Array[String] = []
	for l in (inv.get("_card") as Node).find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return "\n".join(out)


func _pack_row(inv: InventoryScreen, id: String) -> ItemTile.Row:
	for n in inv.find_children("*", "", true, false):
		if n is ItemTile.Row and not n.is_queued_for_deletion():
			var r := n as ItemTile.Row
			if str(r.payload.get("from", "")) == "pack" and str(r.payload.get("id", "")) == id:
				return r
	return null


## The party member's focus slot emptied, as if they had put their own focus away.
func _empty_the_focus(ch: Character) -> void:
	for e in ch.inventory:
		if str(e.get("slot", "")) == "focus":
			e["slot"] = ""


func test_the_holy_symbol_of_ravenkind_can_be_dragged_onto_a_clerics_and_a_paladins_focus_slot() -> void:
	for i: int in [0, 1]:
		var ch: Character = GameState.story.party[i]
		_empty_the_focus(ch)
		ch.add_item(RAVEN)
		var inv := await _open(i)
		var tile := _empty_focus_tile(inv)
		var row := _pack_row(inv, RAVEN)
		assert_true(tile != null and row != null, "%s: the empty Focus slot and the symbol in the pack are on screen" % ch.name)
		if tile == null or row == null:
			continue
		assert_true(tile._can_drop_data(Vector2.ZERO, row.payload), "%s: the Focus slot takes the Holy Symbol of Ravenkind" % ch.name)
		tile._drop_data(Vector2.ZERO, row.payload)
		await _frames(1)
		assert_eq(str(ch.entry_of(RAVEN).get("slot", "")), "focus", "%s: it is their focus" % ch.name)
		assert_eq(ch.focus_item("holy"), RAVEN, "%s: and the sheet records it as their holy focus" % ch.name)


func test_the_pack_menu_offers_the_holy_symbol_as_the_focus() -> void:
	var ch: Character = GameState.story.party[0]
	_empty_the_focus(ch)
	ch.add_item(RAVEN)
	var inv := await _open(0)
	var labels := inv.actions_for(ch.entry_of(RAVEN)).map(func(a: Dictionary) -> String: return str(a["label"]))
	assert_true("Carry as the focus" in labels, str(labels))


func test_the_arcane_grimoire_goes_in_a_wizards_focus_slot_and_is_no_spellbook() -> void:
	var rat: Character = GameState.story.party[2]
	_empty_the_focus(rat)
	rat.add_item(GRIMOIRE)
	var inv := await _open(2)
	var tile := _empty_focus_tile(inv)
	var row := _pack_row(inv, GRIMOIRE)
	assert_true(tile != null and row != null, "the empty Focus slot and the grimoire in the pack are on screen")
	if tile == null or row == null:
		return
	assert_true(tile._can_drop_data(Vector2.ZERO, row.payload), "the Focus slot takes the Arcane Grimoire")
	tile._drop_data(Vector2.ZERO, row.payload)
	await _frames(1)
	assert_eq(str(rat.entry_of(GRIMOIRE).get("slot", "")), "focus", "it is his focus")
	assert_eq(rat.focus_item("arcane"), GRIMOIRE, "and the sheet records it as his arcane focus")
	# Its card: a Wizard's focus, with no list of spells and nothing to copy into a spellbook.
	inv.selected = GRIMOIRE
	inv.call("_draw")
	var text := _card_text(inv)
	assert_false(text.contains("Spells in this book"), "the grimoire holds no spells:\n%s" % text)
	for b in (inv.get("_card") as Node).find_children("*", "Button", true, false):
		var label := (b as Button).text
		assert_false(label.contains("copies") or label.contains("Copy"), "no button copies from it: %s" % label)


func test_the_pack_menu_offers_the_grimoire_as_the_focus_and_a_hand_item() -> void:
	var rat: Character = GameState.story.party[2]
	_empty_the_focus(rat)
	rat.add_item(GRIMOIRE)
	var inv := await _open(2)
	var labels := inv.actions_for(rat.entry_of(GRIMOIRE)).map(func(a: Dictionary) -> String: return str(a["label"]))
	assert_true("Carry as the focus" in labels, str(labels))
	assert_true("Hold (main hand)" in labels, str(labels))


func test_the_rest_screen_offers_arcane_recovery_one_more_slot_level_with_a_grimoire() -> void:
	var rat: Character = GameState.story.party[2]
	rat.slots_used[0] = 2
	rat.slots_used[1] = 1
	rat.add_item(GRIMOIRE)
	assert_true(rat.attune(GRIMOIRE))
	root.call("open_screen", "rest", 2)
	await _frames(1)
	var rest := root.get("screen") as RestScreen
	rest.call("_finish_short")
	await _frames(1)
	var labels: Array[String] = []
	for l in rest.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Arcane Recovery ("):
			labels.append((l as Label).text)
	assert_eq(labels.size(), 1, str(labels))
	if not labels.is_empty():
		assert_true(labels[0].contains("(4 slot levels left to recover)"), "half of level 5 is 3, and the grimoire adds one: %s" % labels[0])
