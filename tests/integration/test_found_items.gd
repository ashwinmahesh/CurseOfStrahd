extends TestCase
## Hidden finds (docs/story/found_magic_items.md): Search rolls Investigation as well when a hidden compartment is near,
## each character gets one look at a find holding an item, a find's `when` keeps it out of reach until it holds (an
## NPC's tip), Detect Magic senses a hidden magic item without saying where, and every find placed in the game's data
## is a playable item of a rarity that fits where it is.

const LOC := {
	"id": "test_nooks", "name": "Test Nooks", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#.......#",
		"#.......#",
		"#.......#",
		"#########"], "light": "dim"},
	"spawns": {"default": [2, 3]},
	"props": [
		{"id": "deep_niche", "cell": [3, 1], "kind": "search", "search_dc": 40, "label": "A deep niche", "item": "wand_of_magic_missiles"},
		{"id": "false_drawer", "cell": [2, 1], "kind": "search", "search_dc": 1, "skill": "investigation", "label": "A false drawer", "item": "driftglobe"},
		{"id": "tipped_stash", "cell": [4, 1], "kind": "search", "search_dc": 1, "label": "A stash", "item": "orb_of_direction", "when": "flag.test_nooks_tip"}]
}

var root: Node
var said: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_nooks"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_nooks"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	said.clear()
	var v := _view()
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.toast.connect(func(text: String) -> void: said.append(text))
	v.check_rolled.connect(func(text: String) -> void: said.append(text))


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_nooks")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _found() -> Dictionary:
	return GameState.story.loc_state("test_nooks")["found"] as Dictionary


func test_search_rolls_investigation_for_a_compartment_nearby() -> void:
	var v := _view()
	v.search()
	assert_true(bool(_found().get("false_drawer", false)), "the Investigation roll finds the drawer (DC 1)")
	assert_true(said.any(func(s: String) -> bool: return "hidden compartments" in s), "the Investigation roll is shown: %s" % [said])
	assert_false(v.thing_at(Vector2i(2, 1)).is_empty(), "the drawer is on the board")
	v.interact(v.thing_at(Vector2i(2, 1)))
	assert_true((v.leader().creature as Character).carries("driftglobe"), "and its item is taken")


func test_each_character_gets_one_look_at_a_find() -> void:
	var v := _view()
	var first := v.leader().creature as Character
	v.search()
	assert_false(bool(_found().get("deep_niche", false)), "DC 40 is out of reach")
	assert_eq(LocationTraps.hidden_within(v, v.leader().cell, 15, first).filter(func(p: Dictionary) -> bool: return p["id"] == "deep_niche").size(), 0,
		"whoever missed it has missed it for good")
	v.set_leader(1)
	var second := v.leader().creature as Character
	assert_true(second != first)
	assert_eq(LocationTraps.hidden_within(v, v.leader().cell, 15, second).filter(func(p: Dictionary) -> bool: return p["id"] == "deep_niche").size(), 1,
		"someone else can still try")
	assert_eq(LocationTraps.hidden_within(v, v.leader().cell, 15).filter(func(p: Dictionary) -> bool: return p["id"] == "deep_niche").size(), 1,
		"still hidden for the party as a whole")


func test_a_tip_puts_a_find_within_reach() -> void:
	var v := _view()
	v.search()
	assert_false(bool(_found().get("tipped_stash", false)), "nobody has said where it is yet")
	GameState.story.set_flag("test_nooks_tip")
	v.search()
	assert_true(bool(_found().get("tipped_stash", false)), "found once someone has told you")


func test_detect_magic_senses_a_hidden_magic_item() -> void:
	var v := _view()
	v.apply_spell_effect("detect_magic")
	assert_true(said.any(func(s: String) -> bool: return "something hidden from sight" in s), str(said))


## Every hidden find, tip and gift in the game's data is a real, playable item; the magic ones come from the 2024 DMG
## (or the story's own), are no rarer than very rare, and fit the level of the region they're in.
func test_placed_finds_are_playable_and_fit_their_region() -> void:
	var comp := Compendium.shared()
	var max_rank := {1: 2, 2: 2, 3: 2, 4: 2, 5: 3, 6: 3, 7: 3, 8: 3, 9: 4, 10: 4}   # 2 uncommon, 3 rare, 4 very rare
	var ranks := {"common": 1, "uncommon": 2, "rare": 3, "very_rare": 4, "legendary": 5, "artifact": 6}
	var n := 0
	for loc: Dictionary in comp.all("locations"):
		if str(loc["id"]).begins_with("test_"):
			continue
		for p: Variant in loc.get("props", []):
			var prop := p as Dictionary
			if str(prop["kind"]) != "search" or not prop.has("item"):
				continue
			var item := comp.item_data(str(prop["item"]))
			assert_false(item.is_empty(), "%s %s: no item %s" % [loc["id"], prop["id"], prop["item"]])
			assert_true(str(prop.get("skill", "perception")) in ["perception", "investigation"], "%s %s" % [loc["id"], prop["id"]])
			if not MagicItems.is_magic(item):
				continue
			n += 1
			assert_true(Compendium.playable(item), "%s %s: %s isn't playable yet" % [loc["id"], prop["id"], prop["item"]])
			var book := str((item.get("source", {}) as Dictionary).get("book", ""))
			assert_true(book in ["DMG2024", "CoS", ""], "%s %s: %s is from %s" % [loc["id"], prop["id"], prop["item"], book])
			var level := Treasure.level_for(str(loc["id"]))
			var rank := int(ranks.get(MagicItems.rarity(item), 0))
			assert_true(rank <= int(max_rank.get(level, 4)), "%s %s: %s is too rare for level %d" % [loc["id"], prop["id"], prop["item"], level])
	assert_true(n >= 8, "the hidden magic finds are placed (%d)" % n)
