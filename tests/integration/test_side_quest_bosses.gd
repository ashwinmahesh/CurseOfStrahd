extends TestCase
## The side quests' bosses (docs/story/side_quests.md), played to the end by the test autopilot on their own maps at the
## level the quest expects: every fight finishes, every boss uses its turns without error, and the party can win but
## pays for it (hard, per the owner's standing rule).

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Boots `location` at `hour` with the four pregens at `level`, starts `encounter` and plays it with the autopilot.
## `at`: where the four stand when it starts (the saved positions a load uses); unset, the location's default spawn.
func _play(location: String, hour: int, level: int, encounter: String, seed_value: int, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	for g in guests:
		GameState.story.add_guest(g)
	for d in open_doors:
		(GameState.story.loc_state(location)["doors"] as Dictionary)[d] = LocationView.DOOR_OPEN
	GameState.story.location = location
	if at.size() == GameState.story.party.size():
		GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(seed_value)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	assert_true(v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(2)
	var e := v.combat_view.e
	var res := PartyAutopilot.new(e).run(30)
	for c in e.combatants:
		assert_true(c.creature.hp >= 0 and c.creature.hp <= c.creature.max_hp(), "%s HP in range" % c.name())
	root.queue_free()
	root = null
	await _frames(2)
	return res


func _series(location: String, hour: int, level: int, encounter: String, seeds: Array, flags: Array[String] = [],
		guests: Array[String] = [], open_doors: Array[String] = [], at: Array[Vector2i] = []) -> void:
	var wins := 0
	var downs := 0
	var rounds := 0
	for s: int in seeds:
		var res := await _play(location, hour, level, encounter, s, flags, guests, open_doors, at)
		assert_ne(str(res["outcome"]), "timeout", "%s seed %d finished" % [encounter, s])
		if str(res["outcome"]) == "victory":
			wins += 1
		downs += int(res["downs"])
		rounds += int(res["rounds"])
	print("        %s at level %d: %d/%d won, %.1f rounds, %.1f party members dropped per fight" % [
		encounter, level, wins, seeds.size(), rounds / float(seeds.size()), downs / float(seeds.size())])
	assert_true(wins >= 1, "%s can be won at level %d (%d/%d)" % [encounter, level, wins, seeds.size()])


func test_old_greytooth_at_level_6() -> void:
	await _series("lake_zarovich", 19, 6, "greytooth_hunt", [1, 2, 3, 4])


func test_the_drowned_of_pescari_at_level_8() -> void:
	await _series("lake_zarovich", 23, 8, "drowned_landing", [1, 2, 3])


func test_the_bone_marshal_and_his_column_at_level_6() -> void:
	await _series("into_the_mists_road", 23, 6, "bone_marshal", [1, 2, 3])


func test_the_bone_marshal_duel_at_level_8() -> void:
	await _series("into_the_mists_road", 23, 8, "bone_marshal", [1, 2, 3], ["riders_stood_down"])


func test_the_rag_queen_at_level_9() -> void:
	await _series("berez", 14, 9, "rag_queen", [1, 2, 3], ["lysaga_guests"])


func test_the_vine_mother_at_level_6() -> void:
	await _series("wizard_of_wines", 1, 6, "vine_mother", [1, 2, 3, 4], ["winery_reclaimed"])


func test_granny_ash_at_level_6() -> void:
	await _series("old_bonegrinder_track", 23, 6, "granny_ash", [1, 2, 3, 4], ["morgantha_slain"])


func test_the_counts_huntsman_at_level_8() -> void:
	await _series("svalich_crossroads", 23, 8, "the_hunt", [1, 2, 3, 4])


func test_the_counts_huntsman_with_his_hounds_called_at_level_8() -> void:
	await _series("svalich_crossroads", 23, 8, "the_hunt", [1, 2, 3], ["hounds_called"])


func test_the_squires_vigil_at_level_8() -> void:
	await _series("argynvostholt", 2, 8, "squires_vigil", [1, 2, 3, 4], ["godfrey_met", "courtyard_phantoms_defeated"])


func test_the_penitent_at_level_10() -> void:
	await _series("tsolenka_pass", 20, 10, "the_penitent", [1, 2, 3, 4])


## Lupu fights beside the party, and the study door is open: the fight starts at the bricks.
func test_the_tenant_at_level_2() -> void:
	await _series("burgomaster_mansion", 22, 2, "hound_tenant", [1, 2, 3, 4], [], ["lupu"], ["study_door"])


func test_the_tinkers_wagon_at_level_5() -> void:
	await _series("svalich_crossroads", 12, 5, "tinkers_wagon", [1, 2, 3, 4])


func test_the_raven_trap_at_level_6() -> void:
	await _series("lake_zarovich_trail", 22, 6, "raven_trap", [1, 2, 3, 4], ["fowlers_ready"])


## The sim starts at the road gate; in play the party is already by the pens, inside the open gate.
func test_the_grandsire_at_level_8() -> void:
	await _series("krezk", 23, 8, "grandsire", [1, 2, 3, 4], ["krezk_gate_open", "den_children_freed"], [], ["krezk_gate"])


## The sim boots at the catacombs' gate stair; in play the party is at her crypt, inside the open gate.
func test_corvina_at_level_10() -> void:
	await _series("castle_ravenloft_catacombs", 23, 10, "corvina", [1, 2, 3, 4], [], [], ["cat_e3_gate"])


func test_corvina_named_at_level_10() -> void:
	await _series("castle_ravenloft_catacombs", 23, 10, "corvina", [1, 2, 3], ["corvina_named"], [], ["cat_e3_gate"])


func test_ilarions_wolves_at_level_1() -> void:
	await _series("into_the_mists_road", 9, 1, "ilarion_wolves", [1, 2, 3, 4], ["mists_wolves_resolved"])



## The four at the mouth of Sarkhaza's cavern, where her conversation starts.
const HOARD_MOUTH: Array[Vector2i] = [Vector2i(12, 10), Vector2i(13, 10), Vector2i(12, 9), Vector2i(13, 9)]


## The count's keepers at the gate on Ghakis, met coming up the path.
func test_the_keepers_of_ghakis_at_level_10() -> void:
	await _series("ghakis_shoulder", 12, 10, "ghakis_keepers", [1, 2, 3, 4], [], [], [],
		[Vector2i(8, 14), Vector2i(9, 14), Vector2i(8, 15), Vector2i(9, 15)])


## The vent gallery, through the hot door.
func test_the_vent_fire_at_level_10() -> void:
	await _series("ghakis_lair", 12, 10, "vent_fire", [1, 2, 3, 4], [], [], ["ghakis_hot_door"],
		[Vector2i(17, 17), Vector2i(18, 17), Vector2i(18, 18), Vector2i(19, 17)])


## Sarkhaza as she is: chained, with her lair, nothing done to her first. The hardest way in.
func test_sarkhaza_at_level_10() -> void:
	await _series("ghakis_lair", 12, 10, "sarkhaza", [1, 2, 3, 4], [], [], [], HOARD_MOUTH)


## All three of the keepers' tricks: the salted carcass, the chain hauled in and the vents drowned.
func test_sarkhaza_with_the_keepers_tricks_at_level_10() -> void:
	await _series("ghakis_lair", 12, 10, "sarkhaza", [1, 2, 3, 4], ["wyrm_salted", "wyrm_chain_drawn", "ghakis_sluice_open"], [], [], HOARD_MOUTH)


## Let off her chain she's at her strongest, even a level later.
func test_sarkhaza_unchained_at_level_11() -> void:
	await _series("ghakis_lair", 12, 11, "sarkhaza", [1, 2, 3, 4, 5, 6, 7, 8], ["wyrm_unchained"], [], [], HOARD_MOUTH)
