extends TestCase
## Each lasting magic item turns up once (Ashwin, 2026-10-17: the Amulet of the Devout was found six times;
## docs/story/magic_item_audit.md). The story places each kind of item (Treasure.kind_of: a +1 and a +3 of one item are
## one kind, a +1 Longsword and a +1 Rapier two) in one place only, across every location's finds, checks and
## containers and every dialogue's gifts; random treasure never rolls a kind the story places, one already rolled this
## playthrough, or one the party has; and things with no use in a fight come up less often.

## Kinds given in more than one line of dialogue that the story only ever reaches one of, and the files that hold them.
const ONE_OF := {
	"weapon_plus:longsword": ["argynvostholt/beacon", "companions/ladle"],   # Godrick's knighting sword, +1 or +2
	"armor_plus:plate_armor": ["argynvostholt/godfrey"],   # Godfrey's plate, after either oath (godfrey_plate_given)
	"helm_of_brilliance": ["castle_ravenloft/escher_petition"],   # Escher's helm, whether he sees the dawn or waits
	"weapon_plus:rapier": ["village_of_barovia/ismark", "village_of_barovia/burial"],   # his father's (ismark_gave_father_sword)
	"glamoured_studded_leather": ["van_richtens_tower/ezmerelda", "allies/ezmerelda_hunt"],   # her coat, once (ezmerelda_gift_given): at the tower or after the yard
}


## kind -> ["where: item", ...] for every lasting magic item the story places.
func _placements() -> Dictionary:
	var out := {}
	for loc: Dictionary in Compendium.shared().all("locations"):
		if not str(loc["id"]).begins_with("test_"):
			_walk(loc, str(loc["id"]), out)
	for path in _dialogues("res://narrative"):
		var key := path.trim_prefix("res://narrative/").trim_suffix(".dialogue")
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var l := line.strip_edges()
			if l.begins_with("give "):
				_add(out, l.get_slice(" ", 1), key)
	return out


func _walk(v: Variant, where: String, out: Dictionary) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		if d.get("item", null) is String:
			_add(out, str(d["item"]), where)
		for k: Variant in d:
			if str(k) == "items" and d[k] is Array:
				for it: Variant in d[k]:
					if it is Dictionary:
						_add(out, str((it as Dictionary).get("id", "")), where)
			elif d[k] is Dictionary or d[k] is Array:
				_walk(d[k], where, out)
	elif v is Array:
		for e: Variant in v:
			_walk(e, where, out)


func _add(out: Dictionary, id: String, where: String) -> void:
	var k := Treasure.kind_of(id)
	if k == "":
		return
	if not out.has(k):
		out[k] = []
	(out[k] as Array).append("%s: %s" % [where, id])


func _dialogues(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	for f in da.get_files():
		if f.ends_with(".dialogue"):
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_dialogues(dir.path_join(sub)))
	return out


func test_the_story_places_each_kind_of_item_once() -> void:
	var placed := _placements()
	assert_true(placed.size() > 150, "the story's lasting magic items are all counted (%d kinds)" % placed.size())
	for k: String in placed:
		var where := placed[k] as Array
		if ONE_OF.has(k):
			for w: Variant in where:
				assert_true((ONE_OF[k] as Array).has(str(w).get_slice(":", 0)), "%s turns up outside its one scene: %s" % [k, w])
			continue
		assert_eq(where.size(), 1, "%s turns up more than once: %s" % [k, where])
	assert_eq((placed["amulet_of_the_devout"] as Array).size(), 1, "one Amulet of the Devout: %s" % [placed["amulet_of_the_devout"]])
	# Treasure's own list of what the story places agrees.
	Treasure.reset()
	for k2: String in placed:
		assert_true(Treasure.placed_kinds().has(k2), "Treasure.placed_kinds has %s" % k2)


func test_kinds() -> void:
	assert_eq(Treasure.kind_of("amulet_of_the_devout_plus_1"), Treasure.kind_of("amulet_of_the_devout_plus_3"), "+1 and +3")
	assert_eq(Treasure.kind_of("belt_of_giant_strength_hill"), Treasure.kind_of("belt_of_giant_strength_storm"), "hill and storm")
	assert_ne(Treasure.kind_of("ioun_stone_strength"), Treasure.kind_of("ioun_stone_agility"), "two Ioun Stones")
	assert_eq(Treasure.kind_of("weapon_plus_1__longsword"), Treasure.kind_of("weapon_plus_2"), "+1 and +2 Longsword (its default)")
	assert_ne(Treasure.kind_of("weapon_plus_1__longsword"), Treasure.kind_of("weapon_plus_1__rapier"), "a Longsword and a Rapier")
	assert_eq(Treasure.kind_of("flame_tongue__rapier"), Treasure.kind_of("flame_tongue__longsword"), "a Flame Tongue is one")
	for repeats: String in ["potion_of_healing", "spell_scroll__fireball", "ammunition_plus_1__arrow", "dust_of_disappearance", "longsword"]:
		assert_eq(Treasure.kind_of(repeats), "", "%s can repeat" % repeats)


func test_random_treasure_never_repeats_a_kind() -> void:
	Treasure.reset()
	var placed := Treasure.placed_kinds()
	var st := StoryState.new()
	st.playthrough_seed = 3
	st.party.append(TestChars.pregen("ilse_varga", 5))
	st.party[0].add_item("cloak_of_arachnida")
	var taken := Treasure.taken_kinds(st)
	assert_true(taken.has("cloak_of_arachnida"), "what the party carries is taken")
	var rng := DiceRoller.new(11)
	var rolled := {}
	for level: int in [1, 3, 5, 7, 9, 10]:
		for i in 60:
			var it := Treasure.roll_item(rng, level, taken)
			if it.is_empty():
				continue
			var k := Treasure.kind_of(str(it["id"]))
			if k == "":
				continue
			assert_false(placed.has(k), "a roll gave %s, which the story places" % it["id"])
			assert_false(rolled.has(k), "a roll gave a second %s" % k)
			rolled[k] = true
			taken[k] = true
	assert_true(rolled.size() > 10, "random treasure still finds lasting items: %d" % rolled.size())
	# A place's chests roll against what's already been rolled into others.
	for loc: String in ["death_house_upper", "village_church", "tser_pool", "vallaki_blue_water_inn"]:
		for cid: String in Treasure.placed(st, loc):
			for it2: Variant in Treasure.placed(st, loc)[cid]:
				var k2 := Treasure.kind_of(str((it2 as Dictionary)["id"]))
				assert_false(k2 != "" and placed.has(k2), "%s rolled %s, which the story places" % [loc, (it2 as Dictionary)["id"]])


func test_things_with_no_use_in_a_fight_come_up_less() -> void:
	Treasure.reset()
	var cfg := Treasure.config()
	var weight := float(cfg["support_weight"])
	assert_true(weight < 1.0 and weight > 0.0)
	var support := cfg["support_items"] as Array
	for id: Variant in support:
		assert_false(Compendium.shared().item_data(str(id)).is_empty(), "%s is an item" % id)
	var pools := Treasure.pools()
	var bag := -1.0
	var cloak := -1.0
	for th: String in pools["uncommon"]:
		for e: Dictionary in pools["uncommon"][th]:
			if str(e["id"]) == "bag_of_holding":
				bag = float(e["weight"])
			elif str(e["id"]) == "cloak_of_protection":
				cloak = float(e["weight"])
	assert_between(bag, cloak * weight - 0.001, cloak * weight + 0.001, "a Bag of Holding comes up a quarter as often as a Cloak of Protection")
