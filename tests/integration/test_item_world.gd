extends TestCase
## Magic items that work on the place the party is in (ADR 0012): a Chime of Opening and a Mystery Key on the lock's
## right-click menu, Gloves of Thievery on lockpicking, and a Wand of Secrets pointing out a hidden door.

const LOC := {
	"id": "test_item_vault", "name": "Item Vault", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#.......#",
		"#.......#",
		"####.####",
		"#.......#",
		"#########"], "light": "dim"},
	"spawns": {"default": [2, 1]},
	"doors": [{"id": "panel", "cell": [4, 3], "secret_dc": 25, "label": "a hidden panel"}],
	"containers": [{"id": "strongbox", "cell": [7, 1], "label": "Strongbox", "locked": true, "lock_dc": 30, "gold": 3}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_item_vault"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_item_vault"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_item_vault")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _walk_until_idle() -> void:
	for i in 400:
		if (_view().get("_queue") as Array).is_empty():
			return
		await get_tree().process_frame


func _lock_state() -> String:
	return str((GameState.story.loc_state("test_item_vault")["doors"] as Dictionary).get("strongbox", ""))


func _action(id: String) -> Dictionary:
	for a: Variant in _view().actions_at(Vector2i(7, 1))["actions"]:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func test_a_chime_of_opening_opens_a_lock_and_counts_its_uses() -> void:
	var ch := GameState.story.party[0]
	assert_true(_action("chime").is_empty(), "nobody has a chime yet")
	ch.add_item("chime_of_opening")
	var left := ch.charges_left("chime_of_opening")
	assert_eq(left, 10)
	assert_true(str(_action("chime").get("label", "")).contains("10 uses left"), str(_action("chime")))
	_view().act(Vector2i(7, 1), "chime")
	await _walk_until_idle()
	await _frames(2)
	assert_eq(_lock_state(), "unlocked", "one strike and the lock gives")
	assert_eq(ch.charges_left("chime_of_opening"), 9)


func test_the_last_strike_cracks_the_chime() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("chime_of_opening")
	ch.spend_charges("chime_of_opening", 9)
	_view().act(Vector2i(7, 1), "chime")
	await _walk_until_idle()
	await _frames(2)
	assert_eq(_lock_state(), "unlocked")
	assert_false(ch.carries("chime_of_opening"), "cracked after its tenth use")


func test_a_mystery_key_gets_one_try_per_lock() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("mystery_key")
	assert_true(bool(_action("mystery_key").get("enabled", true)))
	_view().act(Vector2i(7, 1), "mystery_key")
	await _walk_until_idle()
	await _frames(2)
	if _lock_state() == "unlocked":
		assert_false(ch.carries("mystery_key"), "once it opens a lock, the key is gone")
	else:
		assert_true(ch.carries("mystery_key"))
		assert_false(bool(_action("mystery_key").get("enabled", true)), "it won't turn in this lock again")


func test_gloves_of_thievery_add_five_to_picking_a_lock() -> void:
	var ch := GameState.story.party[1]
	var adv: Array[String] = []
	var before := LocationView._pick_bonus(ch, adv).total()
	ch.add_item("gloves_of_thievery")
	assert_true(ch.wear("gloves_of_thievery"))
	var after := LocationView._pick_bonus(ch, adv)
	assert_eq(after.total(), before + 5)
	assert_true(after.describe().contains("Gloves of Thievery"), after.describe())


func test_a_wand_of_secrets_points_out_the_hidden_door() -> void:
	var v := _view()
	var st := GameState.story
	assert_true(HiddenAreas.hidden_cells(v).has(Vector2i(2, 4)), "the room behind the panel starts hidden")
	var ch := st.party[3]
	ch.add_item("wand_of_secrets")
	var before := ch.charges_left("wand_of_secrets")
	var res := FieldItems.use(st, ch, "wand_of_secrets", "secrets", null, Dice.roller)
	assert_true(bool(res["ok"]), str(res.get("text", "")))
	assert_eq(str(res["effect"]), "secrets")
	assert_eq(ch.charges_left("wand_of_secrets"), before - 1)
	var said: Array[String] = []
	v.narration.connect(func(t: String) -> void: said.append(t))
	v.apply_spell_effect(str(res["effect"]))
	assert_true(bool((st.loc_state("test_item_vault")["found"] as Dictionary).get("panel", false)), str(said))
	assert_true(HiddenAreas.hidden_cells(v).is_empty(), "the room behind it comes into view")
	assert_true(said.any(func(t: String) -> bool: return t.contains("a hidden panel")), str(said))
	v.apply_spell_effect("secrets")
	assert_true(said.back().contains("stays still"), "nothing else within 30 feet")
