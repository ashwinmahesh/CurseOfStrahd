extends TestCase
## Golden saves (P4): every save kept in tests/saves still loads in today's game. Older builds wrote them: the
## playthrough tests keep one at the start of each chapter when `make golden-saves` runs them (GoldenSaves), and the
## owner's own saves from earlier builds sit beside them. So a change that breaks an old save fails here before a
## player meets it, the way the borrowed portraits did (owner report 2026-10-07). Each goes through SaveSystem's upgrade
## step like any load; then the people, places and things it names must still exist, a pregen must wear its own look,
## the game must start where it was saved, and it must save and load again unchanged.

const DIR := GoldenSaves.DIR

var root: Node


func after_each() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()
	SaveSystem.current_slot = ""


## Every golden save's file name.
static func saves() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


static func read(f: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
	return data as Dictionary if data is Dictionary else {}


## Loads `f` the way the Load list does: copied into this run's save folder, then SaveSystem.load_slot.
func _load(f: String) -> bool:
	var slot := "golden_" + f.get_basename()
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var out := FileAccess.open(SaveSystem.slot_path(slot), FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(DIR + f))
	out.close()
	var err := SaveSystem.load_slot(slot)
	SaveSystem.delete_slot(slot)
	assert_eq(err, OK, "%s loads" % f)
	return err == OK


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A new game the way the title screen starts one: three of the six travelling with a hero the player made, the other
## three at camp. Under make golden-saves it is kept as the first chapter's save.
func test_a_new_game_with_a_hero_of_your_own_starts_on_the_mists_road() -> void:
	GameState.reset()
	var st := GameState.story
	for id in Pregens.roster_ids():
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		if st.party.size() < StoryState.PARTY_CAP - 1:
			st.party.append(ch)
		else:
			st.bench.append(ch)
	var b := CharacterBuilder.new(null, {"appearance": HeroLook.default_appearance("female", "ranger")})
	b.set_class("ranger")
	b.set_background("guide")
	b.set_species("half_elf" if not Compendium.shared().get_entry("species", "half_elf").is_empty() else "human")
	b.set_name("Vesna Dragos")
	TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
		func(key: String, chosen: Array) -> void: b.choose(key, chosen))
	var hero := b.build_character()
	assert_true(hero != null, "the hero is made: %s" % [b.errors()])
	if hero == null:
		return
	hero.finish_long_rest()
	st.party.append(hero)
	st.gold = 10.0
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(10)
	assert_eq((root.get("view") as LocationView).loc_id, "into_the_mists_road", "the road out of the mists")
	assert_eq(st.party.size(), StoryState.PARTY_CAP)
	GoldenSaves.keep("new_game", "test_golden_saves")


func test_the_chapters_have_golden_saves() -> void:
	if GoldenSaves.commit() != "":
		return   # make golden-saves is making them in other processes right now
	var chapters := saves().filter(func(f: String) -> bool: return read(f).has("golden"))
	assert_true(chapters.size() >= 10, "a save from the start of each chapter (found %d)" % chapters.size())
	for f: String in saves():
		assert_false(read(f).is_empty(), "%s is a save" % f)


func test_the_upgrade_step_takes_any_older_version_to_this_one() -> void:
	var old := {"version": 1, "party": [], "flags": {"kept": true}}
	var up := SaveSystem.upgrade(old)
	assert_eq(int(up["version"]), GameState.SAVE_VERSION, "brought up to date")
	assert_eq(up["flags"], {"kept": true}, "what it held is kept")
	assert_eq(int(old["version"]), 1, "the save read from disk is left as it was")
	assert_eq(int(SaveSystem.upgrade({})["version"]), GameState.SAVE_VERSION, "a save with no version is the first")
	# A save from a newer build than this one is refused rather than guessed at.
	DirAccess.make_dir_recursive_absolute(SaveSystem.save_dir)
	var f := FileAccess.open(SaveSystem.slot_path("golden_future"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": GameState.SAVE_VERSION + 1}))
	f.close()
	assert_eq(SaveSystem.load_slot("golden_future"), ERR_FILE_UNRECOGNIZED, "a newer save is refused")
	SaveSystem.delete_slot("golden_future")


func test_every_golden_save_upgrades_to_this_version() -> void:
	for f in saves():
		var data := SaveSystem.upgrade(read(f))
		assert_eq(int(data.get("version", 0)), GameState.SAVE_VERSION, "%s upgraded" % f)
		assert_true(data.has("story"), "%s keeps its story" % f)


func test_every_golden_save_names_things_that_exist() -> void:
	var comp := Compendium.shared()
	for f in saves():
		if not _load(f):
			continue
		var st := GameState.story
		assert_false(comp.get_entry("locations", st.location).is_empty(), "%s: the place %s exists" % [f, st.location])
		assert_false(st.party.is_empty(), "%s: a party" % f)
		for ch in st.roster():
			var who := "%s: %s" % [f, ch.name]
			for e: Dictionary in ch.inventory:
				assert_false(comp.item_data(str(e["id"])).is_empty(), "%s carries %s, which exists" % [who, e["id"]])
			if HeroLook.is_custom(ch):
				assert_true(HeroLook.has_pieces(ch.build.get("appearance", {}) as Dictionary), "%s's pieces are drawn" % who)
				continue
			var art := CombatToken.art_for(ch)
			assert_true(ResourceLoader.exists("res://art/sprites/%s/walk.tres" % art), "%s walks as %s, which is drawn" % [who, art])
			var face := DialogueRunner.portrait_of(ch)
			assert_true(ResourceLoader.exists("res://art/portraits/%s.png" % face), "%s's portrait %s is drawn" % [who, face])
			var pregen := comp.get_entry("pregens", ch.id)
			if not pregen.is_empty():
				var own := str(((pregen.get("build", {}) as Dictionary).get("appearance", {}) as Dictionary).get("art", ch.id))
				assert_eq(art, own, "%s wears their own look" % who)
		for e: Dictionary in st.stash:
			assert_false(comp.item_data(str(e["id"])).is_empty(), "%s: the stash's %s exists" % [f, e["id"]])
		for q: String in st.quests:
			assert_false(comp.get_entry("quests", q).is_empty(), "%s: the quest %s exists" % [f, q])
		for npc: String in st.guest_ids:
			assert_false(comp.get_entry("npcs", npc).is_empty(), "%s: the guest %s exists" % [f, npc])


func test_every_golden_save_saves_and_loads_unchanged() -> void:
	for f in saves():
		if not _load(f):
			continue
		var first := _comparable(GameState.to_dict())
		assert_eq(SaveSystem.save("golden_again"), OK, "%s saves again" % f)
		GameState.reset()
		assert_eq(SaveSystem.load_slot("golden_again"), OK, "%s loads again" % f)
		assert_eq(str(_comparable(GameState.to_dict())), str(first), "%s: the second save matches the first" % f)
		SaveSystem.delete_slot("golden_again")


## A save without what every save changes (when it was written, the dice).
static func _comparable(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	out.erase("saved_at")
	out.erase("dice")
	return out


func test_every_golden_save_starts_the_game_where_it_was_saved() -> void:
	Engine.time_scale = 8.0
	for f in saves():
		if not _load(f):
			continue
		var st := GameState.story
		var where := st.location
		var fighting := not GameState.combat_snapshot.is_empty()
		var ended := Endings.reached(st) != ""
		root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
		add_child(root)
		await _frames(10)
		var view := root.get("view") as LocationView
		assert_true(view != null and view.loc_id == where, "%s: back at %s" % [f, where])
		if ended:
			assert_true(root.get("ending") != null, "%s: a finished game shows its ending" % f)
		elif fighting:
			assert_true(view != null and view.in_combat, "%s: back in the fight" % f)
		else:
			for screen: String in ["sheet", "inventory", "journal", "party"]:
				root.call("open_screen", screen, 0)
				await _frames(1)
				assert_true(root.get("screen") != null, "%s: the %s opens" % [f, screen])
				root.call("close_screen")
				await _frames(1)
		root.queue_free()
		root = null
		get_tree().paused = false
		await _frames(1)
