extends TestCase
## The side quests' fights in the real game (docs/story/side_quests.md): each starts on its own map from the location's
## data, every foe stands on open ground, and a guest who joined for it (Teodor) fights on the party's side.

var root: Node


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(location: String, hour: int, level: int, flags: Array[String] = [], guests: Array[String] = []) -> LocationView:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "wren_featherfoot"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f in flags:
		GameState.story.set_flag(f, true)
	for g in guests:
		GameState.story.add_guest(g)
	GameState.story.location = location
	GameState.story.minute_of_day = hour * 60
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	return root.get("view") as LocationView


## Starts `encounter` and checks its board: foes on open squares, every named foe present.
func _fight(v: LocationView, encounter: String, named: Array[String]) -> Encounter:
	assert_true(v.start_encounter(encounter), "%s starts" % encounter)
	await _frames(3)
	var e := v.combat_view.e
	var names: Array[String] = []
	for c in e.combatants:
		assert_false(e.grid.is_solid(c.cell), "%s isn't in a wall (%s)" % [c.name(), c.cell])
		names.append(c.name())
	for n in named:
		assert_true(names.has(n), "%s is in the fight: %s" % [n, names])
	return e


func _end(v: LocationView) -> void:
	v.combat_view.finished.emit("victory")
	await _frames(4)


func test_the_coachman_comes_for_ileanas_door_and_teodor_stands_with_the_party() -> void:
	var v := await _boot("village_of_barovia", 22, 3, ["teodor_vigil", "teodor_met"], ["teodor"])
	var e := await _fight(v, "teodor_errand", ["The Coachman"])
	var teodor: Combatant = null
	var coachman: Combatant = null
	for c in e.combatants:
		if c.name() == "Teodor":
			teodor = c
		elif c.name() == "The Coachman":
			coachman = c
	assert_true(teodor != null, "Teodor is on the board")
	if teodor != null and coachman != null:
		assert_ne(teodor.side, coachman.side, "on the other side from the coachman")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("teodor_errand_beaten", false)), "the win is remembered")
	assert_eq(GameState.story.quest_stage("polite_caller"), "held")


func test_the_woodpile_stands_up_in_grigores_yard() -> void:
	var v := await _boot("village_of_barovia", 19, 3, ["seedwood_known"])
	await _fight(v, "woodpile_wakes", ["The Woodpile"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("cut_after_noon"), "stood_up")


func test_the_late_wood_burns_by_day() -> void:
	var v := await _boot("village_of_barovia", 11, 4, ["seedwood_known", "bildrath_wood_taken"])
	await _fight(v, "woodpile_burns", [])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("late_wood_burned", false)))


func test_the_carriage_escort_at_the_crossroads_with_and_without_steaua() -> void:
	var v := await _boot("svalich_crossroads", 0, 4, ["mare_saved", "carriage_came"])
	var e := await _fight(v, "carriage_escort", ["The Lead Horse", "The Footman"])
	assert_false(e.combatants.any(func(c: Combatant) -> bool: return c.name() == "Steaua"), "saved, she isn't there")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("carriage_beaten", false)))
	root.queue_free()
	root = null
	v = await _boot("svalich_crossroads", 0, 4, ["mare_lost", "carriage_came"])
	await _fight(v, "carriage_escort", ["The Lead Horse", "Steaua"])
	await _end(v)


func test_stellas_shadow_stands_up_in_her_bedroom() -> void:
	var v := await _boot("vallaki_wachter_house", 14, 5, ["stella_bound_known", "stella_met"])
	await _fight(v, "stella_shadow", ["The Master's Gaze"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("cat_in_the_window"), "freed")


func test_ana_and_the_girls_in_the_street_and_in_their_graves() -> void:
	var v := await _boot("vallaki", 22, 5, ["roses_vigil", "ana_met"])
	await _fight(v, "roses_street", ["Ana", "Irina"])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("roses_spawn_destroyed", false)))
	root.queue_free()
	root = null
	v = await _boot("vallaki", 11, 5, ["ana_grave_known"])
	await _fight(v, "roses_graves", ["Ana", "Irina", "Daria"])
	await _end(v)


func test_the_abbey_comes_for_sorin_at_the_pool() -> void:
	var v := await _boot("krezk_pool_of_the_white_sun", 1, 7, ["sorin_vigil", "sorin_seen", "sorin_known", "krezk_gate_open"])
	await _fight(v, "sorin_pursuers", ["A Bride Before Vasilka", "Belview Brute"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("lighter_than_it_should_be"), "pursued")


func test_the_bride_rises_out_of_the_well() -> void:
	var v := await _boot("village_of_barovia", 16, 3, ["bride_bones_raised"])
	await _fight(v, "well_bride", ["Zinaida"])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("bride_beaten", false)))


func test_the_lights_come_up_out_of_the_gorge() -> void:
	var v := await _boot("tser_falls", 22, 4, ["wisps_lured"])
	var e := await _fight(v, "falls_wisps", [])
	assert_eq(e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy").size(), 4, "four will-o'-wisps")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("wisps_beaten", false)))


func test_dobres_lads_at_the_lamp_and_the_rider_at_the_gate() -> void:
	var v := await _boot("vallaki", 21, 5, ["ribbons_list_known"])
	await _fight(v, "ribbons_street", ["Watchman Dobre", "Dobre's lad"])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("dobre_beaten", false)))
	root.queue_free()
	root = null
	v = await _boot("vallaki", 21, 5, ["ribbons_list_known"])
	await _fight(v, "ribbons_gate", ["Watchman Dobre", "The Rider on the Black Horse"])
	await _end(v)


func test_old_greytooth_comes_down_to_the_landing() -> void:
	var v := await _boot("lake_zarovich", 19, 7, [])
	var e := await _fight(v, "greytooth_hunt", ["Old Greytooth", "Szoldar"])
	var boss: Combatant = null
	for c in e.combatants:
		if c.name() == "Old Greytooth":
			boss = c
	assert_true(boss != null and boss.creature.max_hp() >= 150, "the boss at full size")
	await _end(v)
	assert_eq(GameState.story.quest_stage("hunters_at_the_inn"), "hunted")


func test_the_drowned_come_up_the_landing() -> void:
	var v := await _boot("lake_zarovich", 23, 8, ["arabelle_rescued"])
	await _fight(v, "drowned_landing", ["The Bellringer of Pescari", "The Lake's Undertow"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("bell_under_the_lake"), "risen")


func test_the_last_muster_at_the_gates() -> void:
	var v := await _boot("into_the_mists_road", 23, 6, ["muster_met"])
	await _fight(v, "bone_marshal", ["The Bone Marshal", "Rider of the Last Muster"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("last_muster"), "released")


func test_the_rag_queen_steps_off_her_post() -> void:
	var v := await _boot("berez", 14, 9, ["dragos_freed", "lysaga_guests"])
	await _fight(v, "rag_queen", ["The Rag Queen", "A Straw Groom"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("one_horned_billy"), "burned")


func test_the_seventh_row_stands_up() -> void:
	for level: int in [5, 6, 7, 8]:
		var v := await _boot("wizard_of_wines", 1, level, ["winery_reclaimed"])
		await _fight(v, "vine_mother", ["The Vine Mother", "Vine Blight 1"])
		await _end(v)
		assert_eq(GameState.story.quest_stage("the_black_row"), "cut_out")
		assert_true(bool(GameState.story.get_flag("vine_mother_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_granny_ash_comes_out_of_the_trees_with_her_dogs() -> void:
	for level: int in [5, 6, 7, 8]:
		var v := await _boot("old_bonegrinder_track", 23, level, ["morgantha_slain"])
		await _fight(v, "granny_ash", ["Granny Ash", "Granny's Dog"])
		await _end(v)
		assert_eq(GameState.story.quest_stage("the_fourth_sister"), "granny_slain")
		assert_true(bool(GameState.story.get_flag("granny_ash_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_the_huntsman_and_his_hounds_come_up_the_east_road() -> void:
	for level: int in [7, 8, 9, 10]:
		for called: bool in [false, true]:
			var flags: Array[String] = []
			if called:
				flags.append("hounds_called")
			var v := await _boot("svalich_crossroads", 23, level, flags)
			await _fight(v, "the_hunt", ["The Count's Huntsman", "Hound of the Hunt"])
			await _end(v)
			assert_eq(GameState.story.quest_stage("the_counts_huntsman"), "stood")
			assert_true(bool(GameState.story.get_flag("huntsman_slain", false)))
			root.queue_free()
			root = null
			await _frames(2)


func test_the_men_at_arms_come_for_the_squires_vigil() -> void:
	for level: int in [7, 8, 9]:
		var v := await _boot("argynvostholt", 2, level, ["godfrey_met", "courtyard_phantoms_defeated"])
		await _fight(v, "squires_vigil", ["The Gate Warden", "Man-at-Arms"])
		await _end(v)
		assert_true(bool(GameState.story.get_flag("squires_vigil_won", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_the_penitent_stands_up_out_of_the_gorge_wall() -> void:
	for level: int in [8, 9, 10, 11]:
		var v := await _boot("tsolenka_pass", 20, level)
		await _fight(v, "the_penitent", ["The Penitent", "A Pilgrim's Shadow"])
		await _end(v)
		assert_true(bool(GameState.story.get_flag("penitent_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_the_tenant_comes_up_the_little_stair_and_lupu_stands_with_the_party() -> void:
	for level: int in [1, 2, 3]:
		var v := await _boot("burgomaster_mansion", 22, level, [], ["lupu"])
		var e := await _fight(v, "hound_tenant", ["The Tenant", "A Siege-Winter Servant"])
		var lupu: Combatant = null
		var tenant: Combatant = null
		for c in e.combatants:
			if c.name() == "Lupu":
				lupu = c
			elif c.name() == "The Tenant":
				tenant = c
		assert_true(lupu != null, "Lupu is on the board")
		if lupu != null and tenant != null:
			assert_ne(lupu.side, tenant.side, "on the other side from the Tenant")
		await _end(v)
		assert_true(bool(GameState.story.get_flag("tenant_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_the_tinkers_wagon_stands_up_off_its_wheels() -> void:
	for level: int in [4, 5, 6]:
		var v := await _boot("svalich_crossroads", 12, level)
		await _fight(v, "tinkers_wagon", ["The Tinker's Wagon", "A Trinket"])
		await _end(v)
		assert_true(bool(GameState.story.get_flag("wagon_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_the_fowlers_drop_out_of_the_dead_pine() -> void:
	for level: int in [5, 6, 7]:
		for ready: bool in [false, true]:
			var flags: Array[String] = []
			if ready:
				flags.append("fowlers_ready")
			var v := await _boot("lake_zarovich_trail", 22, level, flags)
			await _fight(v, "raven_trap", ["The Count's Fowler"])
			await _end(v)
			assert_true(bool(GameState.story.get_flag("fowlers_slain", false)))
			root.queue_free()
			root = null
			await _frames(2)


func test_the_grandsire_comes_over_krezks_wall() -> void:
	for level: int in [7, 8, 9]:
		var v := await _boot("krezk", 23, level, ["krezk_gate_open", "den_children_freed"])
		await _fight(v, "grandsire", ["The Grandsire", "An Old Wolf of the Pack"])
		await _end(v)
		assert_true(bool(GameState.story.get_flag("grandsire_slain", false)))
		root.queue_free()
		root = null
		await _frames(2)


func test_corvina_stands_up_out_of_the_unnamed_crypt() -> void:
	for level: int in [9, 10]:
		for named: bool in [false, true]:
			var flags: Array[String] = []
			if named:
				flags.append("corvina_named")
			var v := await _boot("castle_ravenloft_catacombs", 23, level, flags)
			await _fight(v, "corvina", ["Corvina, the Doorkeeper", "A Door-Warden"])
			await _end(v)
			assert_true(bool(GameState.story.get_flag("corvina_slain", false)))
			root.queue_free()
			root = null
			await _frames(2)


func test_the_counts_wolves_come_out_of_the_fog_for_ilarion() -> void:
	for level: int in [1, 2, 3]:
		var v := await _boot("into_the_mists_road", 9, level, ["mists_wolves_resolved"])
		var named: Array[String] = ["Wolf 1"]
		if level >= 3:
			named = ["The Grey Leader"]
		await _fight(v, "ilarion_wolves", named)
		await _end(v)
		assert_true(bool(GameState.story.get_flag("ilarion_wolves_beaten", false)))
		root.queue_free()
		root = null
		await _frames(2)


## Sarkhaza rises off her gold as big as she should be (the draconic spirit's sprite at her own height), and her death
## moves The Warm Snow on.
func test_sarkhaza_rises_on_her_hoard() -> void:
	var v := await _boot("ghakis_lair", 12, 10, [])
	GameState.story.set_quest_stage("the_warm_snow", "chained")
	var e := await _fight(v, "sarkhaza", ["Sarkhaza"])
	for c in e.combatants:
		if c.name() == "Sarkhaza":
			assert_eq(c.size_cells, 3, "Huge")
			assert_eq(CombatToken.height_of(c), 3.4, "drawn at her own height, not the spirit's")
	await _end(v)
	assert_true(bool(GameState.story.get_flag("sarkhaza_slain", false)))
	assert_eq(GameState.story.quest_stage("the_warm_snow"), "slain")


## Khazan stands up out of his chair on its step with the Visitors round him, his undercroft acting for him.
func test_khazan_stands_up_out_of_his_chair() -> void:
	var v := await _boot("khazan_undercroft", 12, 10, ["khazan_stair_open", "khazan_withdrawn"])   # out of his chair, so it's free
	var e := await _fight(v, "khazan_named", ["Khazan", "A Visitor"])
	assert_true(e.lair, "his undercroft acts on initiative 20")
	await _end(v)


## The Eye Below rises out of its broken amber with a dreamed eye beside it, its lair awake.
func test_the_eye_below_rises_out_of_the_amber() -> void:
	var v := await _boot("amber_deep", 12, 10, ["deep_stair_open", "eye_met"])
	LocationNpcs.hide_npcs_of(v, "amber_temple/the_amber_debt:eye")   # as its conversation does when it ends in the fight
	var e := await _fight(v, "the_eye_below", ["The Eye Below", "Dream-Gazer"])
	assert_true(e.lair)
	await _end(v)
	assert_true(bool(GameState.story.get_flag("eye_below_slain", false)))
	assert_eq(GameState.story.quest_stage("the_amber_debt"), "slain")

## The Ash Effigy stands up on Yester Hill's burned crown with Mother Ruxandra beside it, when she was spared.
func test_the_ash_effigy_stands_up_with_ruxandra() -> void:
	var v := await _boot("yester_hill_gulthias_tree", 12, 8, ["yester_hill_resolved", "gulthias_tree_burned"])
	GameState.story.set_flag("yester_druids_fate", "spared")
	var e := await _fight(v, "ash_effigy", ["The Ash Effigy", "Mother Ruxandra", "An Ember"])
	await _end(v)
	assert_true(bool(GameState.story.get_flag("ash_effigy_slain", false)))
	assert_eq(GameState.story.quest_stage("the_druid_who_came_back"), "burned")

## The Dursts climb out of the family crypts for Veta, with their robed ones.
func test_the_dursts_come_for_veta() -> void:
	var v := await _boot("death_house_dungeon_1", 22, 3, ["nursemaid_bones_taken"])
	GameState.story.set_quest_stage("the_nursemaids_grave", "carried")
	await _fight(v, "nursemaid_keepers", ["Gustav Durst", "Elisabeth Durst", "A Robed One"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_nursemaids_grave"), "laid")

## The Lantern Girl at the end of the fishers' jetty, the size of a child, with the drowned lights.
func test_the_lantern_girl_on_the_jetty() -> void:
	var v := await _boot("lake_zarovich", 22, 5, [])
	GameState.story.set_quest_stage("one_lantern_too_many", "asked")
	LocationNpcs.hide_npcs_of(v, "vallaki/one_lantern_too_many:girl")
	var e := await _fight(v, "lantern_girl", ["The Lantern Girl", "A Drowned Light"])
	for c in e.combatants:
		if c.name() == "The Lantern Girl":
			assert_eq(CombatToken.height_of(c), 0.9, "child-sized, on the wisp's sprite")
	await _end(v)
	assert_eq(GameState.story.quest_stage("one_lantern_too_many"), "fought")

## The pack's hunters come out of the pines at Agafia's door.
func test_the_pack_hunters_come_up_the_oats() -> void:
	var v := await _boot("woodcutters_hollow", 23, 3, [])
	GameState.story.set_quest_stage("the_oat_thief", "asked")
	await _fight(v, "oat_hunters", ["A Pack Hunter", "Wolf 1"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_oat_thief"), "defended")


## The falconer and his stone birds come down on the roc's shelf.
func test_the_falconer_comes_for_the_last_egg() -> void:
	var v := await _boot("tsolenka_pass", 12, 9, ["roc_driven_off"])
	GameState.story.set_quest_stage("the_last_egg", "asked")
	await _fight(v, "last_egg", ["The Falconer", "The Falconer's Hand", "A Stone Bird"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_last_egg"), "defended")


## The count's canvas leans out of its frame in Haralamb's studio, Large, with its copies.
func test_the_counts_likeness_comes_off_the_wall() -> void:
	var v := await _boot("vallaki_painters_studio", 20, 9, ["painter_studio_open"])
	GameState.story.set_quest_stage("the_counts_portraitist", "asked")
	var e := await _fight(v, "counts_likeness", ["The Count's Likeness", "A Copy"])
	for c in e.combatants:
		if c.name() == "The Count's Likeness":
			assert_eq(c.size_cells, 2, "Large")
			assert_eq(CombatToken.height_of(c), 2.2)
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_counts_portraitist"), "burned")


## Querreth comes down off the keep onto the south tower roof, Large, with the ones who asked before.
func test_querreth_comes_for_escher() -> void:
	var v := await _boot("castle_ravenloft_spires_roofs", 22, 10, ["escher_met"])
	GameState.story.set_quest_stage("escher_petition", "asked")
	var e := await _fight(v, "querreth", ["Querreth", "One Who Asked"])
	for c in e.combatants:
		if c.name() == "Querreth":
			assert_eq(c.size_cells, 2, "Large")
			assert_eq(CombatToken.height_of(c), 2.6)
	await _end(v)
	assert_eq(GameState.story.quest_stage("escher_petition"), "held")


## The tithe-keeper gets up off the dragon's silver in Argynvostholt's undercroft, with the escort's empty harness.
func test_the_gilded_knight_gets_up_off_the_tithe() -> void:
	var v := await _boot("argynvostholt_undercroft", 20, 9, ["tithe_told"])
	GameState.story.set_quest_stage("the_silver_hoard", "asked")
	LocationNpcs.hide_npcs_of(v, "argynvostholt/the_silver_hoard:keeper")
	await _fight(v, "gilded_knight", ["The Gilded Knight", "An Escort's Harness"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_silver_hoard"), "fought")
	assert_true(GameState.story.get_flag("gilded_knight_slain", false))


## The blights come out of the trees at the old den, toward the cub crying in the trap.
func test_the_blights_come_for_the_cub() -> void:
	var v := await _boot("tser_woods_den", 14, 3, ["bear_path_known"])
	GameState.story.set_quest_stage("the_dancing_bear", "asked")
	LocationNpcs.hide_npcs_of(v, "svalich_road/the_dancing_bear:den")
	await _fight(v, "den_blights", ["Vine Blight 1", "Needle Blight 1", "Twig Blight 1"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_dancing_bear"), "defended")


## The hill's watch gets up out of the druids' cairn on Yester Hill's barrow slope, Silverjaw at its head.
func test_the_hills_watch_gets_up() -> void:
	var v := await _boot("yester_hill", 22, 7, ["yester_hill_resolved"])
	GameState.story.set_quest_stage("the_barrow_on_yester_hill", "asked")
	await _fight(v, "hill_watch", ["Silverjaw", "A Barrow-Warden", "The Hill's Watch"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_barrow_on_yester_hill"), "fought")


## The mage's forgotten storm comes down off the ring of glass on Mount Baratok, Huge, with a squall.
func test_the_forgotten_storm_comes_down() -> void:
	var v := await _boot("mount_baratok", 19, 8, [])
	GameState.story.set_quest_stage("the_forgotten_storm", "asked")
	var e := await _fight(v, "forgotten_storm", ["The Forgotten Storm", "A Squall"])
	for c in e.combatants:
		if c.name() == "The Forgotten Storm":
			assert_eq(c.size_cells, 3, "Huge")
			assert_eq(CombatToken.height_of(c), 3.2)
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_forgotten_storm"), "broken")
	assert_true(GameState.story.get_flag("storm_dispersed", false))


## Kiril's hunters come down the Krezk road for Lark at the waystone, and her brother who's gone soft.
func test_the_pack_comes_for_the_waystone() -> void:
	var v := await _boot("krezk_road_waystone", 23, 6, ["waystone_lark_met"])
	GameState.story.set_quest_stage("the_waystone", "asked")
	LocationNpcs.hide_npcs_of(v, "krezk/the_waystone:lark")
	await _fight(v, "waystone_wolves", ["A Pack Hunter", "Wolf"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_waystone"), "defended")
	assert_true(GameState.story.get_flag("waystone_wolves_beaten", false))


## The guide gets up at his camp on the goat path, with his shadows and the ones he led up before.
func test_the_guide_gets_up_from_his_fire() -> void:
	var v := await _boot("amber_road_camp", 20, 10, ["amber_camp_met"])
	GameState.story.set_quest_stage("the_guide_to_the_temple", "asked")
	LocationNpcs.hide_npcs_of(v, "tsolenka_pass/the_guide:camp")
	await _fight(v, "amber_guide", ["The Guide", "One of His Shadows", "One He Led Up"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_guide_to_the_temple"), "fought")
	assert_true(GameState.story.get_flag("amber_guide_beaten", false))


## The Baron's boatmen come up the shingle of the Reed Isle with clubs and a lantern, and the reeds move behind them.
func test_the_boatmen_come_for_the_smoke() -> void:
	var v := await _boot("zarovich_reed_island", 22, 5, ["reed_isle_met"])
	GameState.story.set_quest_stage("the_barons_island", "asked")
	LocationNpcs.hide_npcs_of(v, "lake_zarovich/the_barons_island:ostap")
	await _fight(v, "reed_isle_boatmen", ["The Boatmaster", "A Boatman", "Something in the Reeds"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_barons_island"), "defended")
	assert_true(GameState.story.get_flag("reed_isle_boatmen_beaten", false))


## What's lived under the Grey Goose's trapdoor for twenty winters comes up into the lamplight.
func test_the_cellar_of_the_grey_goose() -> void:
	var v := await _boot("svalich_roadhouse", 23, 2, ["roadhouse_innkeeper_met"])
	GameState.story.set_quest_stage("the_roadhouse_lantern", "asked")
	LocationNpcs.hide_npcs_of(v, "svalich_road/the_roadhouse_lantern:innkeeper")
	await _fight(v, "roadhouse_cellar", ["The Innkeeper's Wife", "A Son of the House", "Giant Rat 1"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_roadhouse_lantern"), "opened")
	assert_true(GameState.story.get_flag("roadhouse_cellar_beaten", false))


## The spiders come down their threads when Tsura is cut out of the web in the gully off the falls path.
func test_the_spiders_of_the_webbed_gully() -> void:
	var v := await _boot("ivlis_spider_gully", 12, 3, [])
	GameState.story.set_quest_stage("the_spiders_gully", "asked")
	await _fight(v, "gully_spiders", ["Giant Spider 1", "A Swarm of Spiderlings"])
	await _end(v)
	assert_eq(GameState.story.quest_stage("the_spiders_gully"), "cut_down")
	assert_true(GameState.story.get_flag("gully_spiders_beaten", false))
