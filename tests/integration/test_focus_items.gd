extends TestCase
## Magic items that are a spellcasting focus (owner report, 2026-10-18: "holy symbol of ravenkind still cant be
## equipped as a spellcasting focus"): through the real inventory screen, the Holy Symbol of Ravenkind goes in a Cleric's
## and a Paladin's Focus slot, from a drag or the item's menu, and the sheet then records it as their holy focus.

const RAVEN := "holy_symbol_of_ravenkind"

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
