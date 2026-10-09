extends TestCase
## Detect Evil and Good and Detect Poison and Disease while exploring (LocationMagic): what each senses within 30 ft
## at the moment of casting, from a cleric's slot or a Rod of Alertness, the same either way.

const LOC := {
	"id": "test_senses", "name": "Test Senses", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#....#.....#",
		"#....#.....#",
		"#....#.....#",
		"#....#.....#",
		"############"], "light": "dim"},
	"areas": [{"id": "crypt", "name": "Crypt", "cells": [[6, 1], [10, 4]]}],
	"spawns": {"default": [2, 3]},
	"npcs": [{"npc": "abbot", "cell": [3, 2]}],
	"containers": [{"id": "shelf", "cell": [1, 4], "label": "the shelf", "items": [{"id": "potion_of_poison", "qty": 1}]}],
	"traps": [{"id": "needle", "cells": [[4, 4]], "label": "a poisoned needle", "detect_dc": 30, "save": {"ability": "con", "dc": 11},
		"damage": "1d4", "damage_type": "poison"}],
	"encounters": [
		{"id": "crypt", "trigger": "enter_area:crypt", "monsters": [{"monster": "zombie", "cell": [7, 2]}, {"monster": "giant_spider", "cell": [6, 4]}]},
		{"id": "later", "trigger": "flag:test_senses_hag", "monsters": [{"monster": "night_hag", "cell": [4, 1]}]}]
}

var root: Node
var said: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_senses"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_senses"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 3:
		await get_tree().process_frame
	said.clear()
	_view().narration.connect(func(text: String) -> void: said.append(text))


func after_each() -> void:
	Compendium.shared().tables["locations"].erase("test_senses")


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_detect_evil_and_good_names_who_it_sees_and_counts_the_rest() -> void:
	_view().apply_spell_effect("detect_evil_and_good")
	assert_eq(said.size(), 1)
	var text := said[0]
	assert_true("The Abbot (Celestial)" in text, "the Abbot is a deva: %s" % text)
	assert_true("an Undead out of sight" in text, "the zombie waiting behind the wall: %s" % text)
	assert_false("Fiend" in text, "the hag arrives later, on a flag: %s" % text)
	assert_false("spider" in text.to_lower(), "a Monstrosity isn't sensed: %s" % text)


func test_detect_poison_finds_the_poisons_and_venom_near_and_the_disguised_potion() -> void:
	var ilse := GameState.story.party[0]
	ilse.add_item("potion_of_poison")
	assert_true(MagicItems.is_disguised(Compendium.shared().item_data("potion_of_poison"), ilse.entry_of("potion_of_poison")))
	_view().apply_spell_effect("detect_poison_and_disease")
	var text := said[0]
	assert_true("Potion of Poison in the shelf" in text, text)
	assert_true("Ilse's Potion of Healing: a Potion of Poison" in text, text)
	assert_true(bool(ilse.entry_of("potion_of_poison").get("identified", false)), "found out")
	assert_true("a venomous Giant Spider out of sight" in text, text)
	assert_false("Zombie" in text, text)
	assert_true("a poison trap: a poisoned needle" in text, text)
	assert_eq(str((GameState.story.loc_state("test_senses")["traps"] as Dictionary).get("needle", "")), "found")


func test_the_rod_of_alertness_casts_them_from_the_inventory() -> void:
	var ilse := GameState.story.party[0]
	ilse.add_item("rod_of_alertness")
	assert_true(ilse.attune("rod_of_alertness"))
	var res := FieldItems.use(GameState.story, ilse, "rod_of_alertness", "detect_evil_and_good", ilse, DiceRoller.new(1))
	assert_true(bool(res["ok"]), str(res))
	_view().apply_spell_effect(str(res.get("effect", "")))
	assert_true("The Abbot (Celestial)" in said[0], str(said))
