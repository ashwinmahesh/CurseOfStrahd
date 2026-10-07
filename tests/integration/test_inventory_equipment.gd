extends TestCase
## Owner reports (2026-10-07): "Theres no way to unequip armor", and attunement is instant (house rule, ADR 0012).

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_hall"] = {"id": "test_hall", "name": "Test Hall", "region": "test", "summary": "",
		"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]}, "rest": "safe"}
	GameState.reset()
	for id: String in Pregens.roster_ids():
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_hall"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _buttons(inv: Node) -> Dictionary:
	var out := {}
	for n in inv.find_children("*", "Button", true, false):
		out[(n as Button).text] = n
	return out


func _open(i: int, item_id: String) -> InventoryScreen:
	root.call("open_screen", "inventory", i)
	await _frames(2)
	var inv := root.get("screen") as InventoryScreen
	inv.selected = item_id
	inv.call("_draw")
	await _frames(1)
	return inv


func test_every_kind_of_armor_can_come_off() -> void:
	var checked := 0
	for i in GameState.story.party.size():
		var ch := GameState.story.party[i]
		var armor := ch.equipped("armor")
		if armor.is_empty():
			continue
		checked += 1
		var ac_on := ch.ac_value()
		var inv := await _open(i, str(armor["id"]))
		var b := _buttons(inv)
		assert_true(b.has("Unequip"), "%s's %s card offers Unequip (it has %s)" % [ch.name, armor["name"], b.keys()])
		if b.has("Unequip"):
			(b["Unequip"] as Button).pressed.emit()
			await _frames(1)
			assert_true(ch.equipped("armor").is_empty(), "%s took off the %s" % [ch.name, armor["name"]])
			assert_ne(ch.ac_value(), ac_on, "and the AC changes")
		root.call("close_screen")
		await _frames(1)
	assert_true(checked >= 3, "light, medium and heavy armor are all in the party")


func test_the_equipped_list_has_take_off() -> void:
	var ch := GameState.story.party[0]
	var main := ch.equipped("main_hand")
	var inv := await _open(0, "")
	# The paper doll (U11): every armor and hand slot that holds something offers Take off first (its right-click menu,
	# or a double-click).
	var offs := inv.find_children("*", "ItemTile", true, false).filter(func(n: Node) -> bool:
		return str((n as ItemTile).payload.get("from", "")) == "slot" and str((n as ItemTile).payload.get("slot", "")) in Character.EQUIP_SLOTS)
	assert_true(offs.size() >= 1, "each equipped slot has Take off")
	for t: Variant in offs:
		assert_eq(str(inv.actions_for((t as ItemTile).payload["entry"] as Dictionary)[0]["label"]), "Take off")
	(inv.actions_for((offs[0] as ItemTile).payload["entry"] as Dictionary)[0]["call"] as Callable).call()
	await _frames(1)
	var still := 0
	for slot in Character.EQUIP_SLOTS:
		if not ch.equipped(slot).is_empty():
			still += 1
	assert_true(still < offs.size(), "one came off")
	root.call("close_screen")
	await _frames(1)
	assert_true(main.has("id"))


## Owner house rule (2026-10-07): attuning and ending attunement take no time; still three items at most.
func test_attunement_is_instant() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("cloak_of_protection")
	var before := GameState.story.total_minutes()
	var inv := await _open(0, "cloak_of_protection")
	var b := _buttons(inv)
	assert_true(b.has("Attune"), "an Attune button, with no hour in it: %s" % [b.keys()])
	(b["Attune"] as Button).pressed.emit()
	await _frames(1)
	assert_true("cloak_of_protection" in ch.attuned)
	assert_eq(GameState.story.total_minutes(), before, "no time passes")
	inv.call("_draw")
	await _frames(1)
	(_buttons(inv)["End attunement"] as Button).pressed.emit()
	await _frames(1)
	assert_false("cloak_of_protection" in ch.attuned)
	assert_eq(GameState.story.total_minutes(), before)
	assert_eq(Character.MAX_ATTUNED, 3, "still three at most")
