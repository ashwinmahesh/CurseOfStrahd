extends TestCase
## The inventory's paper doll, bag and drags (U11, plan §5.6 "Inventory"): every slot sits on the doll where it's worn,
## in the shape of a person, and takes what fits and nothing else (the quiver and the focus too); the bag is a list; a
## drag onto a chip gives the whole stack (that very item, with its own state), stacks split, the two weapon sets swap,
## quick slots reach the fight's hotbar, and set II and the quick slots are saved.

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


## The bag's rows (the bag is a list).
func _rows(inv: InventoryScreen, from: String) -> Array[ItemTile.Row]:
	var out: Array[ItemTile.Row] = []
	for n in inv.find_children("*", "", true, false):
		if n is ItemTile.Row and not n.is_queued_for_deletion() and str((n as ItemTile.Row).payload.get("from", "")) == from:
			out.append(n as ItemTile.Row)
	return out


func _pack_tile(inv: InventoryScreen, id: String) -> ItemTile.Row:
	for r in _rows(inv, "pack"):
		if str(r.payload["id"]) == id:
			return r
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
	var spent: ItemTile.Row = null
	for r in _rows(inv, "pack"):
		if str(r.payload["id"]) == "wand_of_secrets" and int((r.payload["entry"] as Dictionary).get("charges", -1)) == 1:
			spent = r
	assert_true(spent != null, "the spent wand has its own row")
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
		if t.payload.is_empty() and t.caption == "II main" and inv.fits_set2(bow.payload, "main_hand") and t._can_drop_data(Vector2.ZERO, bow.payload):
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
	assert_true(_rows(inv, "stash").is_empty(), "nothing in the stash can be dragged out on the road")
	root.call("close_screen")
	GameState.story.location = "doll_inn"
	inv = await _open(0)
	var out := _rows(inv, "stash")
	assert_eq(out.size(), 1, "at the inn it can")
	inv.call("_drop_on_pack", out[0].payload)
	assert_false(ch.entry_of("rope").is_empty(), "back in the pack")


## The doll is a person (owner 2026-10-09): the head over the neck over the armor over the belt over the boots, a
## weapon in each hand at either side, the rings by the hands; and the bag is a list, its rows dragged onto the doll.
func test_the_doll_is_shaped_like_a_person_and_the_bag_is_a_list() -> void:
	var ch := GameState.story.party[0]
	ch.add_item("cloak_of_protection")
	ch.add_item("potion_of_healing", 2)
	var inv := await _open(0)
	var at := {}
	for t in _tiles(inv, ""):
		if t.get_parent() != null and t.get_parent().name == "PaperDoll":
			at[t.caption if not at.has(t.caption) else t.caption + "2"] = t.position + t.size / 2.0
	for cap: String in ["Head", "Neck", "Armor", "Belt", "Feet", "Main hand", "Off hand", "Ring", "Ring2", "Ammo", "Focus",
			"Cloak", "Hands", "Wrists", "Eyes", "Robe", "II main", "II off"]:
		assert_true(at.has(cap), "the doll has a %s slot" % cap)
	if at.size() < 18:
		return
	assert_true((at["Head"] as Vector2).y < (at["Neck"] as Vector2).y and (at["Neck"] as Vector2).y < (at["Armor"] as Vector2).y
		and (at["Armor"] as Vector2).y < (at["Belt"] as Vector2).y and (at["Belt"] as Vector2).y < (at["Feet"] as Vector2).y,
		"head, neck, chest, waist and feet from top to bottom")
	assert_true((at["Main hand"] as Vector2).x < (at["Armor"] as Vector2).x and (at["Armor"] as Vector2).x < (at["Off hand"] as Vector2).x,
		"a hand either side of the body")
	assert_true(absf((at["Head"] as Vector2).x - (at["Feet"] as Vector2).x) < 1.0, "the head over the feet")
	var doll := inv.find_child("PaperDoll", true, false) as Control
	for t in _tiles(inv, ""):
		if t.get_parent() == doll:
			assert_true(Rect2(Vector2.ZERO, doll.size).encloses(Rect2(t.position, t.size)), "%s is on the doll" % t.caption)
	assert_eq(inv.find_children("*", "GridContainer", true, false).size(), 0, "no icon grid: the bag is a list")
	var cloak := _pack_tile(inv, "cloak_of_protection")
	var potion := _pack_tile(inv, "potion_of_healing")
	assert_true(cloak != null and potion != null, "the bag is rows")
	assert_true(inv.shown_ids().has("cloak_of_protection"))
	var cloak_slot := _empty_slot(inv, "Cloak")
	assert_true(cloak_slot != null and cloak_slot._can_drop_data(Vector2.ZERO, cloak.payload), "a cloak's row drops on the doll's cloak")
	cloak_slot._drop_data(Vector2.ZERO, cloak.payload)
	await _frames(1)
	assert_eq(str(ch.entry_of("cloak_of_protection").get("slot", "")), "cloak", "worn from the list")
	var acts := inv.actions_for(ch.entry_of("potion_of_healing"))
	var keep := acts.filter(func(a: Dictionary) -> bool: return str(a["label"]).begins_with("Keep to hand"))
	assert_eq(keep.size(), 1, "a potion's menu offers a quick slot")


## The quiver and the focus (U11): a new hero starts with the ammunition their weapons shoot in the quiver and a focus
## in the focus slot; each takes only its own kind; dropping another stack swaps it; Take off empties it; arrows shot
## come out of the quivered stack; and an old save fills them once.
func test_the_quiver_and_the_focus() -> void:
	var ranger := Pregens.build("thistle", 3)
	assert_eq(ranger.held_id("ammo"), "arrow", "Thistle starts with her arrows in the quiver")
	var caster: Character = null
	for m in GameState.story.party:
		if m.held_id("focus") != "" and caster == null:
			caster = m
	assert_true(caster != null, "a caster starts with a focus")
	var ch := GameState.story.party[0]
	for e in ch.inventory:
		if str(e.get("slot", "")) in InventoryScreen.CARRY_SLOTS:
			e["slot"] = ""   # start with both empty
	ch.add_item("crossbow_bolt", 10)
	ch.add_item("holy_symbol_amulet")
	var inv := await _open(0)
	var ammo := _empty_slot(inv, "Ammo")
	var focus := _empty_slot(inv, "Focus")
	var bolts := _pack_tile(inv, "crossbow_bolt")
	var symbol := _pack_tile(inv, "holy_symbol_amulet")
	assert_true(ammo != null and focus != null, "the quiver and the focus are on the doll, empty")
	assert_true(bolts != null and symbol != null, "the bolts and the symbol are in the bag")
	if ammo == null or focus == null or bolts == null or symbol == null:
		return
	assert_true(ammo._can_drop_data(Vector2.ZERO, bolts.payload), "bolts go in the quiver")
	assert_false(focus._can_drop_data(Vector2.ZERO, bolts.payload), "but not in the focus slot")
	assert_true(focus._can_drop_data(Vector2.ZERO, symbol.payload), "a holy symbol is a focus")
	assert_false(ammo._can_drop_data(Vector2.ZERO, symbol.payload), "and no ammunition")
	ammo._drop_data(Vector2.ZERO, bolts.payload)
	focus._drop_data(Vector2.ZERO, symbol.payload)
	await _frames(1)
	assert_eq(str(ch.entry_of("crossbow_bolt").get("slot", "")), "ammo", "the bolts are in the quiver")
	assert_eq(str(ch.entry_of("holy_symbol_amulet").get("slot", "")), "focus", "the symbol is the focus")
	var held := 0
	for e in ch.inventory:
		if str(e.get("slot", "")) == "ammo":
			held += 1
	assert_eq(held, 1, "one stack in the quiver")
	var labels := inv.actions_for(ch.entry_of("crossbow_bolt")).map(func(a: Dictionary) -> String: return str(a["label"]))
	assert_eq(str(labels[0]), "Take off")
	ch.unequip_item("crossbow_bolt")
	assert_eq(str(ch.entry_of("crossbow_bolt").get("slot", "")), "", "taken off")
	# An old save (before the quiver) fills the quiver and the focus once as it loads.
	var d := ranger.to_dict()
	d.erase("doll_seeded")
	for e: Dictionary in d["inventory"]:
		if str(e.get("slot", "")) in ["ammo", "focus"]:
			e["slot"] = ""
	var old := Character.from_dict(d)
	assert_ne(old.held_id("ammo"), "", "an old save's quiver is filled")
	assert_true(Gear.carry_slot(Compendium.shared().item_data(old.held_id("ammo"))) == "ammo", "with ammunition")
