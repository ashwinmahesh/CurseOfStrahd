extends TestCase
## A party member down outside a fight (owner asks, 2026-10-07): right-clicking them offers Stabilize (DC 10 Medicine
## by the best of the others), a Healer's Kit and the healing potions the others carry; and anyone healed outside a
## fight gets up and stops showing "Prone · Dying".

const LOC := {
	"id": "test_ward", "name": "Test Ward", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_ward"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_ward"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Drops party member `i` to 0 Hit Points the way a fight does (Unconscious, dying).
func _down(i: int) -> Character:
	var ch := GameState.story.party[i]
	ch.take_damage(ch.hp, &"slashing")
	assert_eq(ch.hp, 0)
	assert_true(ch.has_condition(&"unconscious"), "down and unconscious")
	return ch


func _ids(cell: Vector2i) -> Array:
	return (_view().actions_at(cell)["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))


func test_a_downed_member_can_be_stabilized_from_the_menu() -> void:
	var v := _view()
	var ch := _down(1)
	var cell := v.members[1].cell
	assert_true("stabilize" in _ids(cell), str(_ids(cell)))
	for i in 20:
		if ch.stable:
			break
		root.call("world_action", cell, "stabilize")
		await _frames(1)
	assert_true(ch.stable, "a DC 10 Medicine check succeeds sooner or later")
	var stab := (v.actions_at(cell)["actions"] as Array).filter(func(a: Dictionary) -> bool: return str(a["id"]) == "stabilize")
	assert_false(bool(stab[0].get("enabled", true)), "and then there's nothing more to stabilize")


func test_a_healers_kit_stabilizes_without_a_check() -> void:
	var v := _view()
	var ch := _down(1)
	GameState.story.party[2].add_item("healers_kit")
	root.call("world_action", v.members[1].cell, "kit")
	await _frames(1)
	assert_true(ch.stable)


func test_a_potion_brings_them_back_on_their_feet() -> void:
	var v := _view()
	var ch := _down(1)
	var giver := GameState.story.party[0]
	giver.add_item("potion_of_healing")
	var cell := v.members[1].cell
	assert_true("potion:potion_of_healing" in _ids(cell), str(_ids(cell)))
	root.call("world_action", cell, "potion:potion_of_healing")
	await _frames(2)
	assert_true(ch.hp > 0, "the potion heals")
	assert_false(ch.has_condition(&"unconscious"))
	assert_false(ch.has_condition(&"prone"), "outside a fight they get up")
	assert_eq(giver.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "potion_of_healing").size(), 0, "the potion is used up")
	var chips := str((v.tokens[v.members[1].id] as CombatToken).get("_status").text)
	assert_false(chips.contains("Dying") or chips.contains("Prone"), "the token shows them well again: '%s'" % chips)


func test_any_healing_outside_a_fight_clears_prone_and_dying() -> void:
	var v := _view()
	var ch := _down(3)
	ch.heal(5, "Healing Word")
	root.call("_refresh")   # the game refreshes when a screen closes or a rest ends
	await _frames(1)
	assert_false(ch.has_condition(&"prone"), "back on their feet")
	assert_false(ch.has_condition(&"unconscious"))
	assert_eq(ch.death_failures, 0)
	var chips := str((v.tokens[v.members[3].id] as CombatToken).get("_status").text)
	assert_false(chips.contains("Dying") or chips.contains("Prone"), "no stale 'Prone · Dying': '%s'" % chips)


func test_nothing_to_tend_on_a_member_who_is_up() -> void:
	var ids := _ids(_view().members[0].cell)
	assert_false("stabilize" in ids or "kit" in ids, str(ids))
