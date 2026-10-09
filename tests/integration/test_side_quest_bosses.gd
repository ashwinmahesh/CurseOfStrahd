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
	res["story_flags"] = e.legendary.story_flags.duplicate()   # what the fight hands back (a withdrawal's flag)
	res["departed"] = e.legendary.departed.values()
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


## Khazan's study, the four just inside its door; the hall of names, the four at the stair foot.
const KHAZAN_STUDY: Array[Vector2i] = [Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6)]
const KHAZAN_STAIR: Array[Vector2i] = [Vector2i(14, 17), Vector2i(15, 17), Vector2i(14, 18), Vector2i(15, 18)]
const KHAZAN_DOORS: Array[String] = ["khazan_study_door_w", "khazan_study_door_e"]


func test_the_remembered_at_level_10() -> void:
	await _series("khazan_undercroft", 12, 10, "remembered", [1, 2, 3, 4], [], [], [], KHAZAN_STAIR)


## While his name stands over the door he's at his strongest, and the best the party can do is drive him back into it.
func test_khazan_with_his_name_at_level_10() -> void:
	await _series("khazan_undercroft", 12, 10, "khazan_named", [1, 2, 3, 4], [], [], KHAZAN_DOORS, KHAZAN_STUDY)


## Driven off, not destroyed: he leaves the fight below 60 Hit Points and goes back into his name.
func test_khazan_withdraws_into_his_name() -> void:
	var res := await _play("khazan_undercroft", 12, 10, "khazan_named", 2, [], [], KHAZAN_DOORS, KHAZAN_STUDY)
	assert_eq(str(res["outcome"]), "victory", "seed 2 drives him off")
	assert_true((res["story_flags"] as Dictionary).has("khazan_withdrawn"), "back into his name")
	assert_true((res["departed"] as Array).has("withdraw"), "he left the fight, he didn't die in it")


## With the name unmade, the next body is the last.
func test_khazan_unmade_at_level_10() -> void:
	await _series("khazan_undercroft", 12, 10, "khazan_unmade", [1, 2, 3, 4], ["khazan_name_broken"], [], KHAZAN_DOORS, KHAZAN_STUDY)


## The chamber of the Eye, the four at the top of its throat; the hall of sleepers, the four at the stair foot.
const EYE_CHAMBER: Array[Vector2i] = [Vector2i(17, 11), Vector2i(18, 11), Vector2i(17, 12), Vector2i(18, 12)]
const EYE_STAIR: Array[Vector2i] = [Vector2i(25, 21), Vector2i(26, 21), Vector2i(25, 22), Vector2i(26, 22)]


func test_the_hall_of_sleepers_at_level_10() -> void:
	await _series("amber_deep", 12, 10, "dreamed_eyes", [1, 2, 3, 4], [], [], [], EYE_STAIR)


## The Eye Below as it wakes, its dreams coming out of the walls: the hardest way in.
func test_the_eye_below_at_level_10() -> void:
	await _series("amber_deep", 12, 10, "the_eye_below", [1, 2, 3, 4], [], [], [], EYE_CHAMBER)


## Both the wardens' ways: the mirrors turned on it and the lullaby sung.
func test_the_eye_below_with_the_wardens_ways_at_level_10() -> void:
	await _series("amber_deep", 12, 10, "the_eye_below", [1, 2, 3, 4], ["deep_mirrors_turned", "deep_lullaby_sung"], [], [], EYE_CHAMBER)

## The burned crown of Yester Hill, the four at its edge.
const YESTER_CROWN: Array[Vector2i] = [Vector2i(15, 18), Vector2i(16, 18), Vector2i(17, 18), Vector2i(18, 18)]


## Zorica fights beside the Ash Effigy (nobody talked her down).
func test_the_ash_effigy_and_zorica_at_level_7() -> void:
	await _series("yester_hill_gulthias_tree", 22, 7, "ash_effigy", [1, 2, 3, 4, 5, 6], ["yester_hill_resolved", "gulthias_tree_burned"], [], [], YESTER_CROWN)


## Kostin's tree, and he stands aside: the effigy and its embers.
func test_the_ash_effigy_at_level_8() -> void:
	await _series("yester_hill_gulthias_tree", 22, 8, "ash_effigy", [1, 2, 3, 4], ["yester_hill_resolved", "gulthias_tree_burned", "kostin_doubts"], [], [], YESTER_CROWN)

## The family crypts under Death House, the four at Walter's crypt.
const WALTERS_CRYPT: Array[Vector2i] = [Vector2i(14, 3), Vector2i(15, 3), Vector2i(14, 2), Vector2i(15, 2)]


## The Dursts come for Veta in her son's crypt, with two of their robed ones.
func test_the_dursts_come_for_veta_at_level_3() -> void:
	await _series("death_house_dungeon_1", 22, 3, "nursemaid_keepers", [1, 2, 3, 4], [], [], [], WALTERS_CRYPT)


## With the Dursts already gone, the robed ones come instead, led by the one who carried Walter down.
func test_the_robed_ones_come_for_veta_at_level_3() -> void:
	await _series("death_house_dungeon_1", 22, 3, "nursemaid_keepers", [1, 2, 3, 4], ["death_house_dursts_destroyed"], [], [], WALTERS_CRYPT)

## The shore of Lake Zarovich at the foot of the fishers' jetty.
const JETTY_FOOT: Array[Vector2i] = [Vector2i(17, 10), Vector2i(18, 10), Vector2i(17, 11), Vector2i(18, 11)]


## The Lantern Girl and two drowned lights, when nobody turned back for her lantern.
func test_the_lantern_girl_at_level_5() -> void:
	await _series("lake_zarovich", 22, 5, "lantern_girl", [1, 2, 3, 4], [], [], [], JETTY_FOOT)

## Agafia's door in the charcoal-burners' hollow.
const HOLLOW_DOOR: Array[Vector2i] = [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 10)]


## The pack's hunters come up the oats at level 2: a werewolf and a wolf.
func test_the_oat_hunters_at_level_2() -> void:
	await _series("woodcutters_hollow", 23, 2, "oat_hunters", [1, 2, 3, 4], [], [], [], HOLLOW_DOOR)


## At level 3, three wolves with it.
func test_the_oat_hunters_at_level_3() -> void:
	await _series("woodcutters_hollow", 23, 3, "oat_hunters", [1, 2, 3, 4], [], [], [], HOLLOW_DOOR)


## The roc's nest on the Tsolenka shelf.
const ROC_NEST: Array[Vector2i] = [Vector2i(33, 15), Vector2i(34, 16), Vector2i(33, 16), Vector2i(34, 17)]


## The count's falconer, two of his hands and four stone birds come for the roc's chick.
func test_the_falconer_at_level_9() -> void:
	await _series("tsolenka_pass", 12, 9, "last_egg", [1, 2, 3, 4], ["roc_driven_off"], [], [], ROC_NEST)


## The studio in Haralamb's house, the four by the stair up from the front room.
const PAINTERS_STUDIO: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)]


## The count's great canvas and six copies come off the walls.
func test_the_counts_likeness_at_level_9() -> void:
	await _series("vallaki_painters_studio", 20, 9, "counts_likeness", [1, 2, 3, 4, 5, 6], [], [], [], PAINTERS_STUDIO)


## The south tower roof of Castle Ravenloft, by the stair up from the rooms, where Escher waits at the parapet.
const SOUTH_TOWER: Array[Vector2i] = [Vector2i(7, 20), Vector2i(8, 20), Vector2i(7, 21), Vector2i(8, 21)]


## Querreth and two of the ones who asked before, catching the party unawares.
func test_querreth_at_level_10() -> void:
	await _series("castle_ravenloft_spires_roofs", 22, 10, "querreth", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], SOUTH_TOWER)


## The tithe vault in Argynvostholt's undercroft, where the party stands when the tithe-keeper gets up.
const TITHE_VAULT: Array[Vector2i] = [Vector2i(10, 6), Vector2i(12, 6), Vector2i(11, 7), Vector2i(9, 7)]


## The Gilded Knight and three of the escort's empty harness, at his full strength.
func test_the_gilded_knight_at_level_9() -> void:
	await _series("argynvostholt_undercroft", 20, 9, "gilded_knight", [1, 2, 3, 4, 5, 6, 7, 8], ["tithe_told"], [], [], TITHE_VAULT)


## The clearing at the old den, where the party stands over the trapped cub.
const OLD_DEN: Array[Vector2i] = [Vector2i(12, 12), Vector2i(13, 13), Vector2i(11, 12), Vector2i(12, 13)]


## Two vine blights, five needle blights and four twig blights come for the cub's crying.
func test_the_den_blights_at_level_3() -> void:
	await _series("tser_woods_den", 14, 3, "den_blights", [1, 2, 3, 4, 5, 6, 7, 8], ["bear_path_known"], [], [], OLD_DEN)


## The barrow slope on Yester Hill, below the druids' cairn of skulls.
const BARROW_SLOPE: Array[Vector2i] = [Vector2i(28, 16), Vector2i(29, 16), Vector2i(27, 17), Vector2i(28, 17)]


## Silverjaw, three barrow-wardens and four of the hill's watch, catching the party unawares.
func test_the_hills_watch_at_level_7() -> void:
	await _series("yester_hill", 22, 7, "hill_watch", [1, 2, 3, 4, 5, 6, 7, 8], ["yester_hill_resolved"], [], [], BARROW_SLOPE)


## The ring of glass on Mount Baratok, where the party waits for dusk.
const GLASS_RING: Array[Vector2i] = [Vector2i(16, 18), Vector2i(17, 18), Vector2i(16, 19), Vector2i(17, 19)]


## The Forgotten Storm and a squall, with the evening's lightning landing on the ring.
func test_the_forgotten_storm_at_level_8() -> void:
	await _series("mount_baratok", 19, 8, "forgotten_storm", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], GLASS_RING)


## The bend in the Krezk road, by the waystone and its candle.
const AT_THE_STONE: Array[Vector2i] = [Vector2i(12, 7), Vector2i(14, 7), Vector2i(13, 8), Vector2i(15, 8)]


## Four of Kiril's hunters and a wolf come down the road for Lark and Yanko.
func test_the_waystone_pack_at_level_6() -> void:
	await _series("krezk_road_waystone", 23, 6, "waystone_wolves", [1, 2, 3, 4, 5, 6, 7, 8], ["waystone_lark_met"], [], [], AT_THE_STONE)


## By the fire at the goat path camp, where the guide pours the tea.
const BY_THE_FIRE: Array[Vector2i] = [Vector2i(11, 10), Vector2i(13, 10), Vector2i(12, 11), Vector2i(14, 11)]


## The Guide, two of his shadows and two of the ones he led up before.
func test_the_guide_at_level_10() -> void:
	await _series("amber_road_camp", 20, 10, "amber_guide", [1, 2, 3, 4, 5, 6, 7, 8], ["amber_camp_met"], [], [], BY_THE_FIRE)


## The shingle at the Reed Isle's landing, where the castaways pull people out of the shallows.
const ON_THE_SHINGLE: Array[Vector2i] = [Vector2i(11, 11), Vector2i(12, 12), Vector2i(13, 12), Vector2i(11, 12)]


## The Boatmaster, two veteran boatmen, four toughs and something in the reeds.
func test_the_reed_isle_boatmen_at_level_5() -> void:
	await _series("zarovich_reed_island", 22, 5, "reed_isle_boatmen", [1, 2, 3, 4, 5, 6, 7, 8], ["reed_isle_met"], [], [], ON_THE_SHINGLE)


## Behind the Grey Goose's counter, by the trapdoor.
const BEHIND_THE_COUNTER: Array[Vector2i] = [Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(13, 8)]


## The innkeeper's wife and son, and the cellar's rats, at level 2.
func test_the_grey_goose_cellar_at_level_2() -> void:
	await _series("svalich_roadhouse", 23, 2, "roadhouse_cellar", [1, 2, 3, 4, 5, 6, 7, 8], ["roadhouse_innkeeper_met"], [], [], BEHIND_THE_COUNTER)


## Under the ledge in the Webbed Gully, where Tsura hangs in the web.
const UNDER_THE_LEDGE: Array[Vector2i] = [Vector2i(12, 4), Vector2i(13, 5), Vector2i(14, 4), Vector2i(12, 5)]


## Three giant spiders and two swarms of spiderlings, catching the party unawares.
func test_the_webbed_gully_at_level_3() -> void:
	await _series("ivlis_spider_gully", 12, 3, "gully_spiders", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], UNDER_THE_LEDGE)


## By the catalogue desk in the middle of the Drowned Library.
const AT_THE_DESK: Array[Vector2i] = [Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14), Vector2i(11, 12)]


## The Index and two reading chairs, with the shelves coming down and the lake coming in.
func test_the_index_at_level_9() -> void:
	await _series("drowned_library", 14, 9, "the_index", [1, 2, 3, 4, 5, 6, 7, 8], ["xaver_met"], [], [], AT_THE_DESK)
