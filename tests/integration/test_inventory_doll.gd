extends TestCase
## The inventory's paper doll, item grid and drags (U11, plan §5.6 "Inventory"): every worn slot takes what fits and
## nothing else, a drag onto a chip gives the whole stack (that very item, with its own state), stacks split, the two
## weapon sets swap, quick slots reach the fight's hotbar, and set II and the quick slots are saved.

var root: Node


func before_each() -> void:
	for id: String in ["doll_inn", "doll_road"]:
		Compendium.shared().tables["locations"][id] = {"id": id, "name": id.capitalize(), "region": "test", "summary": "",
			"map": {"rows": ["#####", "#...#", "#...#", "#####"]}, "spawns": {"default": [1, 1]},
			"rest": "safe" if id == "doll_inn" else "wild"}
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 4):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "doll_inn"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await get_tree().process_frame


func after_each() -> void:
	GameSettings.set_value("inventory_view", "doll")
	# The fixture places leave the shared Compendium with the test (Skirmish lists every location as a map).
	for id: String in ["doll_inn", "doll_road"]:
		Compendium.shared().tables["locations"].erase(id)
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


## The live tiles on screen whose drag carries `from` (and `slot`, when given).
func _tiles(inv: InventoryScreen, from: String, slot: String = "") -> Array[ItemTile]:
	var out: Array[ItemTile] = []
	for n in inv.find_children("*", "ItemTile", true, false):
		var t := n as ItemTile
		if t.is_queued_for_deletion():
			continue
		if from == "" or (str(t.payload.get("from", "")) == from and (slot == "" or str(t.payload.get("slot", "")) == slot)):
			out.append(t)
	return out


## The empty doll slot tile named `caption` (the first of two rings).
func _empty_slot(inv: InventoryScreen, caption: String) -> ItemTile:
	for t in _tiles(inv, ""):
		if t.payload.is_empty() and t.caption == caption:
			return t
	return null


func _pack_tile(inv: InventoryScreen, id: String) -> ItemTile:
	for t in _tiles(inv, "pack"):
		if str(t.payload["id"]) == id:
			return t
	return null


func test_slots_take_what_fits_and_nothing_else() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("ring_of_protection")
	ch.add_item("cloak_of_protection")
	var inv := await _open(0)
	var ring := _pack_tile(inv, "ring_of_protection")
	var ring_slot := _empty_slot(inv, "Ring")
	var cloak_slot := _empty_slot(inv, "Cloak")
	assert_true(ring != null and ring_slot != null and cloak_slot != null, "the ring, its slot and the cloak's are on screen")
	assert_true(ring_slot._can_drop_data(Vector2.ZERO, ring.payload), "a ring fits a ring slot")
	assert_false(cloak_slot._can_drop_data(Vector2.ZERO, ring.payload), "but not the cloak's")
	ring_slot._drop_data(Vector2.ZERO, ring.payload)
	await _frames(1)
	assert_eq(str(ch.entry_of("ring_of_protection").get("slot", "")), "ring", "worn")
	# Every filled slot offers Take off (owner report 2026-10-07: "no way to unequip armor").
	var worn := _tiles(inv, "slot")
	assert_true(worn.size() >= 3, "armor, a weapon and the ring are on the doll")
	for t in worn:
		var acts := inv.actions_for(t.payload["entry"] as Dictionary)
		assert_eq(str(acts[0]["label"]), "Take off", "%s offers Take off first" % t.payload["id"])
	var armor := _tiles(inv, "slot", "armor")
	if not armor.is_empty():
		var ac := ch.ac_value()
		(inv.actions_for(armor[0].payload["entry"] as Dictionary)[0]["call"] as Callable).call()
		assert_true(ch.equipped("armor").is_empty(), "the armor came off")
		assert_ne(ch.ac_value(), ac)


func test_dragging_onto_a_chip_gives_that_very_item() -> void:
	var a := GameState.story.party[0]
	var b := GameState.story.party[1]
	a.add_item("wand_of_secrets")
	a.add_item("wand_of_secrets")
	a.inventory[a.inventory.size() - 1]["charges"] = 1
	a.add_item("javelin", 6)
	var inv := await _open(0)
	var spent: ItemTile = null
	for t in _tiles(inv, "pack"):
		if str(t.payload["id"]) == "wand_of_secrets" and int((t.payload["entry"] as Dictionary).get("charges", -1)) == 1:
			spent = t
	assert_true(spent != null, "the spent wand has its own tile")
	var chip: ItemTile.DropButton = null
	for n in inv.find_children("*", "Button", true, false):
		if n is ItemTile.DropButton and (n as Button).text == b.name.get_slice(" ", 0):
			chip = n as ItemTile.DropButton
	assert_true(chip != null and chip._can_drop_data(Vector2.ZERO, spent.payload), "%s's chip takes it" % b.name)
	chip._drop_data(Vector2.ZERO, spent.payload)
	await _frames(1)
	assert_eq(int(b.entry_of("wand_of_secrets").get("charges", -1)), 1, "the spent one went, charges and all")
	assert_eq(int(a.entry_of("wand_of_secrets").get("charges", -1)), 3, "the full one stayed")
	# A split stack goes on its own.
	var stack := a.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "javelin")[0] as Dictionary
	var before := int(stack["qty"])
	var part := InventoryScreen.split(a, stack, 2)
	assert_eq(int(part["qty"]), 2)
	assert_eq(int(stack["qty"]), before - 2, "split off two")
	inv.call("_draw")
	await _frames(1)
	var b_before := 0
	for e in b.inventory:
		if str(e["id"]) == "javelin":
			b_before += int(e["qty"])
	inv.call("_drop_on_member", {"from": "pack", "ch": 0, "id": "javelin", "entry": part}, 1)
	var b_after := 0
	for e in b.inventory:
		if str(e["id"]) == "javelin":
			b_after += int(e["qty"])
	assert_eq(b_after, b_before + 2, "only the split-off two went")
	assert_eq(int(stack["qty"]), before - 2, "the rest stayed")


func test_weapon_sets_swap_and_are_saved() -> void:
	var ch := GameState.story.party[0]
	ch.weapon_set_2 = {}   # a new hero's set II comes seeded with a spare weapon (seed_weapon_sets); start it empty
	ch.add_item("longbow")
	var held := str(ch.equipped("main_hand").get("id", ""))
	var inv := await _open(0)
	var bow := _pack_tile(inv, "longbow")
	var set2 := _tiles(inv, "", "")
	var main2: ItemTile = null
	for t in set2:
		if t.payload.is_empty() and t.caption == "Main hand" and inv.fits_set2(bow.payload, "main_hand") and t._can_drop_data(Vector2.ZERO, bow.payload):
			main2 = t
	assert_true(main2 != null, "set II's main hand takes the bow")
	main2._drop_data(Vector2.ZERO, bow.payload)
	assert_eq(str(ch.weapon_set_2.get("main_hand", "")), "longbow")
	assert_eq(str(ch.equipped("main_hand").get("id", "")), held, "set I is untouched")
	var copy := Character.from_dict(ch.to_dict())
	assert_eq(str(copy.weapon_set_2.get("main_hand", "")), "longbow", "set II is saved")
	ch.swap_weapon_sets()
	assert_eq(str(ch.equipped("main_hand").get("id", "")), "longbow", "the bow in hand")
	assert_eq(str(ch.weapon_set_2.get("main_hand", "")), held, "the old weapon in set II")
	assert_true(ch.equipped("off_hand").is_empty() or not "two_handed" in Gear.weapon_props(ch.equipped("main_hand")), "hands add up")
	ch.swap_weapon_sets()
	assert_eq(str(ch.equipped("main_hand").get("id", "")), held, "and back")


func test_quick_slots_reach_the_hotbar_and_are_saved() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("potion_of_healing", 2)
	ch.add_item("rope")
	var inv := await _open(0)
	var potion := _pack_tile(inv, "potion_of_healing")
	assert_true(inv.fits_quick(potion.payload), "a potion fits a quick slot")
	assert_false(inv.fits_quick(_pack_tile(inv, "rope").payload), "rope doesn't")
	var quick: ItemTile = null
	for t in _tiles(inv, ""):
		if t.payload.is_empty() and t.caption == "Quick":
			quick = t
			break
	quick._drop_data(Vector2.ZERO, potion.payload)
	assert_eq(ch.quick_slots, ["potion_of_healing"] as Array[String])
	assert_eq(Character.from_dict(ch.to_dict()).quick_slots, ["potion_of_healing"] as Array[String], "saved")
	root.call("close_screen")
	var e := TestCombat.open_field()
	var c := e.add(ch, &"party", Vector2i(2, 2))
	TestCombat.foe(e, "zombie", Vector2i(9, 2))
	TestCombat.start_with(e, c)
	var common := ActionCatalog.new(e).actions_for(c).filter(func(a: Dictionary) -> bool:
		return str(a["tab"]) == ActionCatalog.COMMON and str(a.get("item_id", "")) == "potion_of_healing")
	assert_true(not common.is_empty(), "the potion is on the Common tab")


func test_stash_by_drag_from_anywhere_out_only_at_a_safe_place() -> void:
	GameState.story.location = "doll_road"
	var ch := GameState.story.party[0]
	ch.add_item("rope")
	var inv := await _open(0)
	var rope := _pack_tile(inv, "rope")
	inv.call("_drop_on_stash", rope.payload)
	assert_true(ch.entry_of("rope").is_empty() and GameState.story.party_has_item("rope"), "in the stash from the road")
	inv.call("_draw")
	await _frames(1)
	assert_true(_tiles(inv, "stash").is_empty(), "nothing in the stash can be dragged out on the road")
	root.call("close_screen")
	GameState.story.location = "doll_inn"
	inv = await _open(0)
	var out := _tiles(inv, "stash")
	assert_eq(out.size(), 1, "at the inn it can")
	inv.call("_drop_on_pack", out[0].payload)
	assert_false(ch.entry_of("rope").is_empty(), "back in the pack")


## The list view (owner, 2026-10-07): the old rows beside the portrait, with the same drags, menus, weapon sets and quick
## slots, and the screen remembers which view was chosen.
func test_the_list_view_drags_and_menus_too() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("cloak_of_protection")
	ch.add_item("potion_of_healing", 2)
	var inv := await _open(0)
	inv.set_view("list")
	await _frames(1)
	root.call("close_screen")
	inv = await _open(0)
	assert_eq(inv.view, "list", "it opens in the view last chosen")
	var rows: Array[ItemTile.Row] = []
	for n in inv.find_children("*", "", true, false):
		if n is ItemTile.Row and not n.is_queued_for_deletion():
			rows.append(n as ItemTile.Row)
	var cloak: ItemTile.Row = null
	var potion: ItemTile.Row = null
	for r in rows:
		if str(r.payload.get("from", "")) == "pack" and str(r.payload.get("id", "")) == "cloak_of_protection":
			cloak = r
		if str(r.payload.get("from", "")) == "pack" and str(r.payload.get("id", "")) == "potion_of_healing":
			potion = r
	assert_true(cloak != null and potion != null, "the pack is rows")
	assert_true(inv.shown_ids().has("cloak_of_protection"))
	# The Worn section takes the cloak into its own slot.
	var worn := inv.find_child("WornZone", true, false) as ItemTile.Zone
	assert_true(worn != null and worn._can_drop_data(Vector2.ZERO, cloak.payload), "the Worn section takes the cloak")
	worn._drop_data(Vector2.ZERO, cloak.payload)
	await _frames(1)
	assert_eq(str(ch.entry_of("cloak_of_protection").get("slot", "")), "cloak", "worn from the list")
	# Right-click and quick slots work on rows as on tiles.
	var acts := inv.actions_for(ch.entry_of("potion_of_healing"))
	var keep := acts.filter(func(a: Dictionary) -> bool: return str(a["label"]).begins_with("Keep to hand"))
	assert_eq(keep.size(), 1, "a potion's menu offers a quick slot")
	(keep[0]["call"] as Callable).call()
	assert_true("potion_of_healing" in ch.quick_slots)
	# The equipped rows still say Take off.
	var offs := inv.find_children("*", "Button", true, false).filter(func(b: Node) -> bool:
		return not b.is_queued_for_deletion() and (b as Button).text == "Take off")
	assert_true(offs.size() >= 1, "Take off on the equipped rows")
