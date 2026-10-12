extends TestCase
## Scouting, divining and the rest of branch 3b (Ashwin's answer to the spell audit, 2026-10-12; story/oracles.gd):
## Augury, Divination, Commune, Contact Other Plane, Commune with Nature, Clairvoyance and Arcane Eye read the place the
## party stands in; Legend Lore and Scrying fill in the bestiary; Unseen Servant springs a trap; Stone Shape and
## Passwall open a way; Tenser's Floating Disk carries; Tasha's Bubbling Cauldron brews; Find the Path keeps the road
## quiet.

## A cellar: two zombies wait (they start on their own), two things are hidden, a dart trap, a locked door and a seam.
const CELLAR := {"id": "test_scout_cellar", "name": "Scout Cellar", "region": "test", "summary": "",
	"map": {"rows": ["#########", "#.......#", "#.......#", "#########"], "outdoors": false}, "spawns": {"default": [1, 1]},
	"encounters": [{"id": "dead", "trigger": "enter_area:cellar", "monsters": [{"monster": "zombie", "cell": [6, 1]},
		{"monster": "zombie", "cell": [6, 2]}]}],
	"props": [{"id": "scout_stone", "kind": "search", "search_dc": 14, "label": "a loose stone", "item": "potion_of_healing", "cell": [3, 1]},
		{"id": "scout_rug", "kind": "search", "search_dc": 12, "label": "something under the rug", "item": "potion_of_climbing", "cell": [4, 2]}],
	"traps": [{"id": "scout_darts", "cells": [[2, 1]], "label": "a dart trap", "detect_dc": 13, "disarm_dc": 13, "damage": "1d4"}],
	"doors": [{"id": "scout_locked", "cell": [7, 1], "label": "a locked door", "locked": true, "lock_dc": 15},
		{"id": "scout_seam", "cell": [7, 2], "label": "a seam in the wall", "secret_dc": 16}]}


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_scout_cellar"] = CELLAR.duplicate(true)
	var yard := CELLAR.duplicate(true)
	yard["id"] = "test_scout_yard"
	(yard["map"] as Dictionary)["outdoors"] = true
	Compendium.shared().tables["locations"]["test_scout_yard"] = yard


func after_each() -> void:
	for id: String in ["test_scout_cellar", "test_scout_yard"]:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)


func _party(cls: String, level: int, spells: Array, location: String = "test_scout_cellar") -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.custom(cls, "human", level)
	var prepared := (ch.spellcasting[0] as Dictionary)["prepared"] as Array
	for s: Variant in spells:
		if not str(s) in prepared:
			prepared.append(str(s))
	TestCombat.give_components(ch, spells, 3)
	ch.finish_long_rest()
	st.party.append(ch)
	st.location = location
	return st


func _cast(st: StoryState, spell_id: String, choice: String = "") -> String:
	var res := FieldCasting.cast_utility(st, st.party[0], spell_id, false, 0, "", choice)
	assert_true(bool(res["ok"]), "%s: %s" % [spell_id, res["text"]])
	return str(res["text"])


func _found(st: StoryState, prop: String, location: String = "test_scout_cellar") -> bool:
	return bool((st.loc_state(location)["found"] as Dictionary).get(prop, false))


func test_augury_and_commune_read_the_place() -> void:
	var st := _party("cleric", 9, ["augury", "commune"])
	assert_true(_cast(st, "augury").contains("Weal and woe"))
	var said := _cast(st, "commune")
	assert_true(said.contains("Does anything wait here? Yes") and said.contains("Is anything hidden here? Yes"), said)
	(st.loc_state("test_scout_cellar")["encounters"] as Dictionary)["dead"] = true
	assert_true(_cast(st, "augury").contains("Weal:"), "the dead are put down; something's still hidden")


func test_divination_names_what_waits_then_shows_a_find() -> void:
	var st := _party("wizard", 7, ["divination"])
	var said := _cast(st, "divination")
	assert_true(said.contains("2 Zombies"), said)
	(st.loc_state("test_scout_cellar")["encounters"] as Dictionary)["dead"] = true
	st.party[0].finish_long_rest()
	said = _cast(st, "divination")
	assert_true(_found(st, "scout_stone") or _found(st, "scout_rug"), said)


func test_commune_with_nature_needs_the_open_air() -> void:
	var st := _party("druid", 9, ["commune_with_nature"])
	assert_false(bool(FieldCasting.cast_utility(st, st.party[0], "commune_with_nature", false)["ok"]), "a cellar isn't the open air")
	st.location = "test_scout_yard"
	_cast(st, "commune_with_nature")
	assert_true(_found(st, "scout_stone", "test_scout_yard") and _found(st, "scout_rug", "test_scout_yard"), "every hidden find shows")


func test_clairvoyance_shows_the_traps() -> void:
	var st := _party("wizard", 5, ["clairvoyance"])
	var said := _cast(st, "clairvoyance")
	assert_eq(str((st.loc_state("test_scout_cellar")["traps"] as Dictionary).get("scout_darts", "")), "found", said)
	assert_true(said.contains("Zombies"), said)


func test_contact_other_plane_answers_or_hurts() -> void:
	var st := _party("wizard", 9, ["contact_other_plane"])
	var said := _cast(st, "contact_other_plane")
	assert_true(said.contains("answers") or said.contains("Psychic damage"), said)
	assert_true(st.party[0].hp >= 1, "never below 1 Hit Point outside a fight")


func test_legend_lore_fills_in_the_bestiary() -> void:
	var st := _party("wizard", 9, ["legend_lore"])
	assert_eq(Bestiary.level(st, "rahadin"), 0)
	_cast(st, "legend_lore", "rahadin")
	assert_eq(Bestiary.level(st, "rahadin"), 3, "defenses and traits")


func test_unseen_servant_springs_the_nearest_trap_and_stone_shape_opens_a_way() -> void:
	var st := _party("wizard", 7, [])
	var trap := Oracles.spring_trap(st, "test_scout_cellar", Vector2i(1, 1))
	assert_eq(str(trap.get("id", "")), "scout_darts")
	assert_eq(str((st.loc_state("test_scout_cellar")["traps"] as Dictionary)["scout_darts"]), "disarmed")
	assert_true(Oracles.spring_trap(st, "test_scout_cellar", Vector2i(1, 1)).is_empty(), "sprung once")
	var door := Oracles.open_way(st, "test_scout_cellar", Vector2i(6, 1))
	assert_eq(str(door.get("id", "")), "scout_locked")
	door = Oracles.open_way(st, "test_scout_cellar", Vector2i(6, 1))
	assert_eq(str(door.get("id", "")), "scout_seam", "then the seam, found")
	assert_true(_found(st, "scout_seam"))
	assert_true(Oracles.open_way(st, "test_scout_cellar", Vector2i(1, 1), 5).is_empty(), "nothing within 5 ft of the stair")


func test_tensers_floating_disk_carries_for_an_hour() -> void:
	var st := _party("wizard", 3, ["tensers_floating_disk"])
	var wiz := st.party[0]
	var before := wiz.carrying_capacity().total()
	_cast(st, "tensers_floating_disk")
	assert_eq(wiz.carrying_capacity().total(), before + 500)
	st.advance_minutes(61)
	assert_eq(wiz.carrying_capacity().total(), before)


func test_tashas_cauldron_brews_and_the_last_brew_goes() -> void:
	var st := _party("wizard", 11, ["tashas_bubbling_cauldron"])
	var wiz := st.party[0]
	_cast(st, "tashas_bubbling_cauldron", "potion_of_healing_greater")
	var n := wiz.ability_mod(&"int")
	assert_true(wiz.carries("potion_of_healing_greater"))
	assert_eq(wiz.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "potion_of_healing_greater").reduce(
		func(a: int, e: Dictionary) -> int: return a + int(e["qty"]), 0), maxi(1, n))
	wiz.finish_long_rest()
	_cast(st, "tashas_bubbling_cauldron", "potion_of_climbing")
	assert_false(wiz.carries("potion_of_healing_greater"), "the last brew is gone")
	assert_true(wiz.carries("potion_of_climbing"))


func test_find_the_path_keeps_the_road_quiet() -> void:
	var st := _party("cleric", 11, ["find_the_path"])
	st.location = "vallaki"
	_cast(st, "find_the_path")
	var road := {"id": "test_road", "name": "Test road", "table": ""}
	for t: Variant in Compendium.shared().table("random_encounters").keys():
		road["table"] = str(t)
		break
	for seed_value in 20:
		assert_true(Travel.roll(road, st, DiceRoller.new(seed_value)).is_empty(), "no encounter while it lasts")


func test_the_secret_chest_lasts_sixty_days() -> void:
	var st := _party("wizard", 7, ["leomunds_secret_chest"])
	_cast(st, "leomunds_secret_chest")
	assert_true(st.spell_active("leomunds_secret_chest"))
	st.advance_minutes(59 * 24 * 60)
	assert_true(st.spell_active("leomunds_secret_chest"), "still there on day 59")
