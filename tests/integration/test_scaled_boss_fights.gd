extends FightSeriesCase
## The story's boss fights scaled up for 2024-rules heroes (owner, 2026-10-13: the book's fights were written for weaker
## characters). Over seeds 1-8 the four pregens on the autopilot at full ability (smiting, Spirit Guardians, Fireball and
## Cone of Cold, the Radiance of the Dawn, Lay On Hands, Hunter's Mark, Conjure Barrage...: PartyAutopilot.full, as the
## owner plays), standing where walking up to the one who starts the fight leaves them, win about 3 in 8 on Balanced at
## every level (his target, 2026-10-14), give or take one; a quest's reward makes the fight 4, and where no step lands on
## 3 the harder side, 2, is kept (said in the fight's note). The side quests' bosses are held in test_side_quest_bosses.gd.
## Their current line-ups are in docs/story/boss_fights.md.


## Vallaki's square, beside Izek when he picks his fight; and on the festival ground.
const IZEK_SQUARE: Array[Vector2i] = [Vector2i(24, 13), Vector2i(25, 14), Vector2i(25, 15), Vector2i(25, 16)]
const FESTIVAL_GROUND: Array[Vector2i] = [Vector2i(24, 16), Vector2i(24, 17), Vector2i(24, 18), Vector2i(24, 19)]
## Izek's room in the Burgomaster's mansion, the four in the passage at its door.
const IZEKS_DOOR: Array[Vector2i] = [Vector2i(4, 11), Vector2i(5, 11), Vector2i(6, 11), Vector2i(7, 11)]
## Old Bonegrinder's loft, at Morgantha's elbow.
const LOFT: Array[Vector2i] = [Vector2i(9, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 9)]

## The Abbey's chancel, before the Abbot; the beacon's lantern landing; Argynvostholt's hall, before Vladimir; the den's
## inner cave, before Kiril; Berez, at Lysaga's stump and south of it.
const CHANCEL: Array[Vector2i] = [Vector2i(12, 4), Vector2i(11, 4), Vector2i(13, 4), Vector2i(12, 5)]
const LANTERN_LANDING: Array[Vector2i] = [Vector2i(4, 18), Vector2i(5, 18), Vector2i(4, 19), Vector2i(5, 19)]
const VLADIMIRS_HALL: Array[Vector2i] = [Vector2i(16, 3), Vector2i(17, 4), Vector2i(16, 4), Vector2i(15, 4)]
const KIRILS_CAVE: Array[Vector2i] = [Vector2i(19, 22), Vector2i(18, 22), Vector2i(20, 22), Vector2i(19, 23)]
const LYSAGAS_STUMP: Array[Vector2i] = [Vector2i(31, 17), Vector2i(30, 17), Vector2i(31, 18), Vector2i(30, 18)]
const BELOW_THE_STUMP: Array[Vector2i] = [Vector2i(30, 20), Vector2i(29, 20), Vector2i(31, 20), Vector2i(30, 21)]

## Castle Ravenloft: the stair where Rahadin waits for Gertruda, the hall where he meets the party, his chamber off the
## hall of brides; the brides' gallery; Strahd's tomb in the catacombs.
const RAHADINS_STAIR: Array[Vector2i] = [Vector2i(22, 21), Vector2i(21, 20), Vector2i(21, 22), Vector2i(23, 20)]
const RAHADINS_HALL: Array[Vector2i] = [Vector2i(21, 13), Vector2i(22, 14), Vector2i(22, 15), Vector2i(22, 16)]
const RAHADINS_CHAMBER: Array[Vector2i] = [Vector2i(32, 16), Vector2i(31, 15), Vector2i(31, 14), Vector2i(31, 13)]
const BRIDES_GALLERY: Array[Vector2i] = [Vector2i(8, 14), Vector2i(7, 13), Vector2i(7, 12), Vector2i(7, 11)]
const STRAHDS_TOMB: Array[Vector2i] = [Vector2i(11, 11), Vector2i(11, 10), Vector2i(11, 9), Vector2i(11, 8)]

const SEEDS: Array = [1, 2, 3, 4, 5, 6, 7, 8]


## Wins over seeds 1-8 between `low` and `high`.
func _held(location: String, level: int, encounter: String, at: Array[Vector2i], low: int, high: int,
		flags: Array[String] = [], guests: Array[String] = []) -> void:
	speakers_step_aside = true
	var wins := await _series(location, 12, level, encounter, SEEDS, flags, guests, [], at)
	assert_true(wins >= low, "%s is won at least %d times in 8 (%d)" % [encounter, low, wins])
	assert_true(wins <= high, "%s is lost at least %d times in 8 (%d)" % [encounter, 8 - high, wins])


## Izek's duel at level 5: Izek Strazni (280 HP), 6 Warrior Veterans; 3 in 8.
func test_izeks_duel_at_level_5() -> void:
	await _held("vallaki", 5, "izek_duel", IZEK_SQUARE, 2, 4)


## Izek's festival rampage at level 5: the old 5 in 8 line-up, Izek (225 HP), two sergeants, the captain and two guards. The
## Phase 4 playthrough's party (test_phase4_exit), weaker than the pregens, wins it 4 times in 8 and one sergeant more
## loses seven of eight, so for the full-ability pregens it stays 6 in 8 (kept where it passes, 2026-10-14).
func test_izeks_festival_rampage_at_level_5() -> void:
	await _held("vallaki", 5, "festival_izek_rampage", IZEK_SQUARE, 5, 7)


## The Baron's loyalists at the festival: Izek, five sergeants, the captain and four guards, the 5 in 8 line-up the Phase 4
## playthrough's party can win (test_phase4_exit): that party, weaker than the pregens, wins this fight 2 times in 8, and
## any step harder loses all eight, so for the full-ability pregens it stays 6 in 8 (kept where it passes, 2026-10-14).
func test_the_festival_loyalists_at_level_5() -> void:
	await _held("vallaki", 5, "festival_loyalists", FESTIVAL_GROUND, 5, 7)


## Izek in his room at level 5: Izek Strazni (360 HP), 3 Warrior Veterans, Town Guard; 3 in 8.
func test_izek_in_his_room_at_level_5() -> void:
	await _held("vallaki_burgomaster_mansion", 5, "izek_confrontation", IZEKS_DOOR, 2, 4)


## The coven's last stand at level 6: Night Hag (310 HP), 2 Night Hags (195 HP), 3 Swarm of Rats; 3 in 8.
func test_the_covens_last_stand_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 2, 4, ["offalia_in_last_stand", "bella_in_last_stand"])


## Morgantha and Offalia at level 6: 2 Night Hags (340 HP), 4 Dire Wolfs, 4 Swarm of Rats; 2 in 8, the harder side
## (no step lands on 3).
func test_morgantha_and_offalia_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 2, 4, ["offalia_in_last_stand"])
## Morgantha and Bella at level 6: 2 Night Hags (110 HP), 12 Dire Wolfs, 3 Swarm of Rats; 3 in 8.
func test_morgantha_and_bella_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 2, 4, ["bella_in_last_stand"])


## The Abbot's wrath at level 7: Deva (350 HP), 2 Mongrelfolks, 3 Berserkers, 2 Flesh Golems; 3 in 8.
func test_the_abbots_wrath_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "abbot_wrath", CHANCEL, 2, 4)


## Vasilka defends the abbot at level 7: Flesh Golem (400 HP), 9 Berserkers, 3 Mongrelfolks, Flesh Golem (320 HP);
## 3 in 8.
func test_vasilka_defends_the_abbot_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "bride_defends", CHANCEL, 2, 4)


## Vladimir at the beacon at level 8: Vladimir Horngaard (340 HP), 3 Revenants (220 HP), Phantom Warrior, Wight; 3
## in 8.
func test_vladimir_at_the_beacon_at_level_8() -> void:
	await _held("argynvostholt_beacon", 8, "beacon_stand", LANTERN_LANDING, 2, 4, ["lamp_dark_cleared"])


## Vladimir's duel at level 8: Vladimir Horngaard (290 HP), 3 Revenants (190 HP), Revenant (80 HP); 3 in 8.
func test_vladimirs_duel_at_level_8() -> void:
	await _held("argynvostholt_hall", 8, "vladimir_duel", VLADIMIRS_HALL, 2, 4)


## Kiril's challenge at level 8: Kiril Stoyanovich (175 HP), 4 Werewolfs (140 HP), 4 Dire Wolfs, 3 Wolfs; 3 in 8.
func test_kirils_challenge_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 2, 4, ["den_guards_cleared"])


## Kiril's challenge with the guards at level 8: Kiril Stoyanovich (145 HP), 5 Werewolfs (110 HP), 5 Dire Wolfs; 3
## in 8.
func test_kirils_challenge_with_the_guards_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 2, 4, ["zuleika_vouched"])


## The den's reckoning at level 8: Kiril Stoyanovich (185 HP), Emil Toranescu (45 HP), Werewolf (125 HP), 3
## Werewolfs (150 HP), 2 Dire Wolfs, Wolf; 3 in 8.
func test_the_dens_reckoning_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "den_reckoning", KIRILS_CAVE, 2, 4, ["den_guards_cleared"])


## Lysaga and her hut at level 9: Baba Lysaga's Creeping Hut (160 HP), Baba Lysaga (145 HP); 3 in 8.
func test_lysaga_and_her_hut_at_level_9() -> void:
	cleared_fights.assign(["berez_scarecrows"])
	await _held("berez", 9, "lysaga_and_hut", LYSAGAS_STUMP, 2, 4, ["berez_scarecrows_burned"])


## The masterless hut at level 9: Baba Lysaga's Creeping Hut (520 HP), 3 Swarm of Insects; 3 in 8.
func test_the_masterless_hut_at_level_9() -> void:
	await _held("berez", 9, "creeping_hut_masterless", BELOW_THE_STUMP, 2, 4, ["lysaga_lured", "lysaga_slain_at_monument"])


## Rahadin at 300 HP on the stair when the party brings Gertruda out, with two suits of the count's armour and a
## third, battered.
func test_rahadin_on_the_stair_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_STAIR, 2, 4, [], ["gertruda"])


## Rahadin in the hall at level 10: Rahadin (325 HP), 2 Strahd's Animated Armors (270 HP), Strahd's Animated Armor
## (215 HP); 3 in 8.
func test_rahadin_in_the_hall_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_HALL, 2, 4)


## Rahadin in his chamber at level 10: Rahadin (265 HP), 3 Strahd's Animated Armors (220 HP); 3 in 8.
func test_rahadin_in_his_chamber_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_rahadin_chamber_fight", RAHADINS_CHAMBER, 2, 4)


## Rahadin when the footlocker's lock defeats the party at level 10 (the check:rahadin_footlocker:failure version of the chamber
## fight): Rahadin (325 HP), 3 Strahd's Animated Armors (220 HP); 3 in 8.
func test_rahadin_at_the_failed_footlocker_at_level_10() -> void:
	fire_trigger = "check:rahadin_footlocker:failure"
	await _held("castle_ravenloft_court_weeping", 10, "court_rahadin_chamber_fight", RAHADINS_CHAMBER, 2, 4)
	fire_trigger = ""


## Two brides at level 10: 4 Vampire Spawns (150 HP), 2 Strahd's Animated Armors (185 HP); 2 in 8, the harder side
## (no step lands on 3).
func test_two_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 2, 4, ["court_anastrasya_story"])


## All three brides at level 10: 3 Vampire Spawns (175 HP), 2 Strahd's Animated Armors (215 HP); 2 in 8, the harder
## side (no step lands on 3).
func test_all_three_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 2, 4)


## Vladimir at Strahd's tomb at level 10: Vladimir Horngaard (275 HP), 4 Revenants (180 HP), Revenant (80 HP); 3 in 8.
func test_vladimir_at_strahds_tomb_at_level_10() -> void:
	cleared_fights.assign(["cat_tomb_keepers"])
	await _held("castle_ravenloft_catacombs_strahd", 10, "cat_oathbreakers", STRAHDS_TOMB, 2, 4, ["cat_keepers_defeated"])


## Old Bonegrinder's bakery counter; Marina's grave on its island; Lysaga's kitchen; Exethanter's shelves; Vosk's vault;
## the west end of the Tsolenka bridge.
const BAKERY_COUNTER: Array[Vector2i] = [Vector2i(15, 11), Vector2i(14, 12), Vector2i(13, 13), Vector2i(12, 14)]
const MARINAS_GRAVE: Array[Vector2i] = [Vector2i(8, 14), Vector2i(9, 14), Vector2i(8, 15), Vector2i(9, 15)]
const LYSAGAS_KITCHEN: Array[Vector2i] = [Vector2i(11, 5), Vector2i(10, 6), Vector2i(9, 7), Vector2i(8, 8)]
const EXETHANTERS_SHELVES: Array[Vector2i] = [Vector2i(23, 5), Vector2i(22, 6), Vector2i(21, 7), Vector2i(20, 8)]
const VOSKS_VAULT: Array[Vector2i] = [Vector2i(19, 21), Vector2i(19, 20), Vector2i(19, 19), Vector2i(19, 18)]
## The party on the snow ledge below the sentinel, and just inside the vault's honey door.
const SENTINEL_LEDGE: Array[Vector2i] = [Vector2i(17, 15), Vector2i(18, 15), Vector2i(19, 15), Vector2i(18, 16)]
const VAULT_DOOR: Array[Vector2i] = [Vector2i(19, 8), Vector2i(20, 8), Vector2i(21, 8), Vector2i(20, 7)]
const ROC_BRIDGE: Array[Vector2i] = [Vector2i(13, 18), Vector2i(12, 19), Vector2i(11, 20), Vector2i(10, 20)]


## Offalia in the bakery at level 6: Night Hag (285 HP), 5 Nightmares; 3 in 8.
func test_offalia_in_the_bakery_at_level_6() -> void:
	await _held("old_bonegrinder", 6, "bakery_offalia", BAKERY_COUNTER, 2, 4)


## Offalia in her oven at level 6 (the open:hag_oven version of the bakery fight): Night Hag (200 HP), 6 Nightmares; 3 in 8.
func test_offalia_in_her_oven_at_level_6() -> void:
	fire_trigger = "open:hag_oven"
	await _held("old_bonegrinder", 6, "bakery_offalia", BAKERY_COUNTER, 2, 4)
	fire_trigger = ""


## A trigger starts its own version of an encounter, not the first version of the same id whose condition holds (2026-10-15:
## the oven's Offalia and Rahadin at the failed footlocker never ran behind the dialogue versions).
func test_a_trigger_starts_its_own_version_of_a_fight() -> void:
	var oven := await _fired("old_bonegrinder", 6, "open:hag_oven", BAKERY_COUNTER)
	assert_true(bool(oven["started"]), "the oven's trigger starts a fight")
	assert_eq(int(oven["foes"]), 7, "Offalia and six nightmares, not the dialogue's five")
	assert_eq(int(oven["hp"]), 200, "Offalia at the oven has 200 HP")
	var locker := await _fired("castle_ravenloft_court_weeping", 10, "check:rahadin_footlocker:failure", RAHADINS_CHAMBER)
	assert_true(bool(locker["started"]), "the footlocker's failure starts a fight")
	assert_eq(int(locker["hp"]), 325, "Rahadin at the footlocker has 325 HP")


## The foes a trigger starts at `location` for the four pregens at `level`, standing at `at`: {started, foes, hp (the toughest)}.
func _fired(location: String, level: int, trigger: String, at: Array[Vector2i]) -> Dictionary:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, level)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = location
	GameState.story.positions = at.duplicate()
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	var v := root.get("view") as LocationView
	var out := {"started": LocationFights._trigger_encounter(v, trigger), "foes": 0, "hp": 0}
	await _frames(2)
	if bool(out["started"]):
		for c in v.combat_view.e.combatants:
			if c.side == &"enemy":
				out["foes"] = int(out["foes"]) + 1
				out["hp"] = maxi(int(out["hp"]), c.creature.max_hp())
	root.queue_free()
	root = null
	await _frames(2)
	return out


## Bella betrayed at level 6: Night Hag (300 HP), 6 Nightmares, 2 Dire Wolfs; 3 in 8.
func test_bella_betrayed_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "bella_betrayed", LOFT, 2, 4)


## Bella on the road at level 6: Night Hag (610 HP), 5 Nightmares; 2 in 8, the harder side (no step lands on 3).
func test_bella_on_the_road_at_level_6() -> void:
	await _held("old_bonegrinder_track", 6, "bella_on_the_road", [], 2, 4)
## Offalia on the road at level 6: Night Hag (300 HP), 6 Nightmares; 3 in 8.
func test_offalia_on_the_road_at_level_6() -> void:
	await _held("old_bonegrinder_track", 6, "offalia_on_the_road", [], 2, 4)


## Morgantha alone at level 6: Night Hag (300 HP), 3 Swarm of Rats, 6 Nightmares; 3 in 8.
func test_morgantha_alone_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 2, 4)


## Lysaga at the grave at level 9: Baba Lysaga (460 HP), 2 Swarm of Insects, 10 Scarecrows; 3 in 8.
func test_lysaga_at_the_grave_at_level_9() -> void:
	await _held("berez", 9, "lysaga_at_monument", MARINAS_GRAVE, 2, 4)


## Lysaga in her kitchen at level 9: Baba Lysaga (510 HP), 8 Swarm of Insects, 12 Scarecrows; 3 in 8.
func test_lysaga_in_her_kitchen_at_level_9() -> void:
	await _held("berez_baba_lysagas_hut", 9, "lysaga_in_hut", LYSAGAS_KITCHEN, 2, 4)


## The roc and its mate at level 9: Roc (285 HP), Roc (85 HP); 3 in 8.
func test_the_roc_and_its_mate_at_level_9() -> void:
	await _held("tsolenka_pass", 9, "roc_of_ghakis", ROC_BRIDGE, 2, 4)


## Exethanter at level 10: Exethanter (130 HP), 6 Flameskulls, 8 Wraiths (85 HP); 3 in 8.
func test_exethanter_at_level_10() -> void:
	await _held("amber_temple_library", 10, "exethanter_wrath", EXETHANTERS_SHELVES, 2, 4)


## Vosk unmasked at level 10: Arcanaloth (320 HP), 2 Flameskulls; 3 in 8.
func test_vosk_unmasked_at_level_10() -> void:
	await _held("amber_temple_vault", 10, "vosk_unmasked", VOSKS_VAULT, 2, 4)


## The Amber Temple's sentinel wakes at level 10: Amber Golem (395 HP), 2 Gargoyles, 6 Wraiths; 3 in 8.
func test_the_amber_sentinel_wakes_at_level_10() -> void:
	await _held("amber_temple_entrance", 10, "sentinel_wakes", SENTINEL_LEDGE, 2, 4)


## The sentinel stops a party carrying a dark gift at level 10: Amber Golem (440 HP), 6 Wraiths; 3 in 8.
func test_the_sentinel_stops_a_party_with_a_dark_gift_at_level_10() -> void:
	await _held("amber_temple_entrance", 10, "sentinel_stops_you", SENTINEL_LEDGE, 2, 4, ["amber_temple_arrived", "dark_gifts_taken=1"])


## The vault guardian at level 10: Amber Golem (660 HP), 4 Wraiths; 3 in 8.
func test_the_vault_guardian_at_level_10() -> void:
	await _held("amber_temple_vault", 10, "vault_guardian", VAULT_DOOR, 2, 4)


## Vosk named and weakened at level 10: Arcanaloth (330 HP), 2 Flameskulls; 4 in 8.
func test_vosk_named_and_weakened_at_level_10() -> void:
	await _held("amber_temple_vault", 10, "vosk_unmasked", VOSKS_VAULT, 3, 5, ["vosk_named", "vosk_weakened"])


## Strahd woken by day with the Sunsword: Strahd von Zarovich (270 HP), 2 Swarm of Bats, 7 Vampire Spawns; 3 in 8.
func test_strahd_woken_by_day_with_the_sunsword() -> void:
	cleared_fights.assign(["cat_tomb_keepers"])
	prepare = func(st: StoryState) -> void:
		st.set_flag("cat_keepers_defeated", true)
		var bearer := st.party[0]
		bearer.add_item("sunsword")
		bearer.attune("sunsword")
		bearer.equip("sunsword", "main_hand")
	await _held("castle_ravenloft_catacombs_strahd", 10, "cat_daylight_waking", STRAHDS_TOMB, 2, 4)
	prepare = Callable()
	cleared_fights.clear()

## At his table, the four where his dinner seats them; at the Heart of Sorrow, at the top of the stair.
const DINNER_TABLE: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 6), Vector2i(8, 7), Vector2i(9, 8)]
const HEART_STAIR: Array[Vector2i] = [Vector2i(8, 14), Vector2i(9, 14), Vector2i(7, 14), Vector2i(8, 13)]


## Strahd's dinner with the Sunsword: Strahd von Zarovich (605 HP), 3 Swarm of Bats, 2 Strahd's Animated Armors, 3
## Vampire Spawns; 3 in 8.
func test_strahds_dinner_with_the_sunsword() -> void:
	prepare = _sunsword
	await _held("castle_ravenloft_main_floor", 10, "crg_dinner_affront", DINNER_TABLE, 2, 4)
	prepare = Callable()


## Strahd at the broken Heart with the Sunsword: Strahd von Zarovich (455 HP), 2 Strahd's Animated Armors, 5
## Vampire Spawns; 3 in 8.
func test_strahd_at_the_broken_heart_with_the_sunsword() -> void:
	prepare = _sunsword
	await _held("castle_ravenloft_spires_heart", 10, "heart_strahd_test", HEART_STAIR, 2, 4)
	prepare = Callable()


## Strahd's visits before the castle (data/strahd/visits.json), played where the game plays them: he fights until he's
## beaten, then flees with a parting line (owner, 2026-10-13), 3 in 8 for the party at full ability without the Sunsword.
## On a night road at level 7, at 355 HP with two dire wolves.
func test_strahds_test_of_strength_at_level_7() -> void:
	await _visit("test_of_strength", "road_ambush", 7)


## At Ireena's window: the Blue Water Inn at level 5 (170 HP), the Krezkovs' house at level 7 (360 HP), a swarm of bats.
func test_strahd_at_the_inn_window_at_level_5() -> void:
	await _visit("ireena_at_the_inn", "vallaki_blue_water_inn", 5)


func test_strahd_at_the_krezk_window_at_level_7() -> void:
	await _visit("ireena_in_krezk", "krezk_burgomaster_house", 7)


func _visit(visit_id: String, location: String, level: int) -> void:
	custom_fight = ((StrahdPresence.visit(visit_id)["then"] as Array)[0] as Dictionary)["encounter"] as Dictionary
	var wins := await _series(location, 23, level, str(custom_fight["id"]), SEEDS)
	assert_true(wins >= 2 and wins <= 4, "%s is won 2 to 4 times in 8 (%d)" % [visit_id, wins])
	custom_fight = {}


static func _sunsword(st: StoryState) -> void:
	var bearer := st.party[0]
	bearer.add_item("sunsword")
	bearer.attune("sunsword")
	bearer.equip("sunsword", "main_hand")

# --- Strahd's final battles -----------------------------------------------------------------------------------------

## Where walking into each Tarokka room leaves the four, his parley about to begin.
const HORSEMANS_CRYPT: Array[Vector2i] = [Vector2i(32, 14), Vector2i(33, 14), Vector2i(34, 14), Vector2i(34, 13)]
const DARKLORDS_TOMB: Array[Vector2i] = [Vector2i(10, 7), Vector2i(11, 6), Vector2i(11, 5), Vector2i(11, 4)]
const ROYAL_TOMB: Array[Vector2i] = [Vector2i(16, 20), Vector2i(16, 19), Vector2i(16, 18), Vector2i(16, 17)]
const SERGEIS_TOMB: Array[Vector2i] = [Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(13, 3)]
const CHAPEL_NAVE: Array[Vector2i] = [Vector2i(9, 15), Vector2i(9, 16), Vector2i(9, 17), Vector2i(9, 18)]
const AUDIENCE_HALL: Array[Vector2i] = [Vector2i(21, 9), Vector2i(22, 10), Vector2i(22, 11), Vector2i(22, 12)]
const STRAHDS_STUDY: Array[Vector2i] = [Vector2i(5, 9), Vector2i(5, 10), Vector2i(5, 11), Vector2i(6, 12)]
const TREASURY: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 2), Vector2i(7, 2), Vector2i(8, 3)]
const DONJON: Array[Vector2i] = [Vector2i(26, 12), Vector2i(25, 12), Vector2i(24, 12), Vector2i(23, 12)]
const OVERLOOK: Array[Vector2i] = [Vector2i(6, 1), Vector2i(5, 2), Vector2i(4, 3), Vector2i(3, 3)]
const HEART_OF_SORROW: Array[Vector2i] = [Vector2i(8, 11), Vector2i(8, 12), Vector2i(8, 13), Vector2i(8, 14)]


## Strahd's final battle in the room the reading's `card` sends him to, at level 10, for a party carrying the Sunsword
## (owner, 2026-10-13): won 3 in 8 by the party at full ability (2026-10-14), give or take one. He keeps out of the blade's
## light where he can, so his spawn stand with him, a good many more of them than the rooms' introductions name.
func _final(location: String, encounter: String, card: String, at: Array[Vector2i]) -> void:
	prepare = func(st: StoryState) -> void:
		st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": card}
		st.set_quest_stage("strahds_lair", "foretold")
		var bearer := st.party[0]
		bearer.add_item("sunsword")
		bearer.attune("sunsword")
		bearer.equip("sunsword", "main_hand")
	await _held(location, 10, encounter, at, 2, 4)
	prepare = Callable()


## Strahd in the horseman's crypt with the Sunsword: Strahd von Zarovich (355 HP), Nightmare, 2 Swarm of Bats, 5
## Vampire Spawns; 3 in 8.
func test_strahd_in_the_horsemans_crypt_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs", "cat_horseman_final", "horseman", HORSEMANS_CRYPT)


## Strahd in his tomb with the Sunsword: Strahd von Zarovich (410 HP), 5 Vampire Spawns; 3 in 8.
func test_strahd_in_his_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_strahd", "cat_darklord_final", "darklord", DARKLORDS_TOMB)


## Strahd at the royal tomb with the Sunsword: Strahd von Zarovich (345 HP), 3 Specters, 8 Vampire Spawns; 3 in 8.
func test_strahd_at_the_royal_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_tombs", "cat_royal_final", "ghost", ROYAL_TOMB)


## Strahd at Sergei's tomb with the Sunsword: Strahd von Zarovich (455 HP), 3 Dire Wolfs, 2 Swarm of Bats, 7
## Vampire Spawns; 3 in 8.
func test_strahd_at_sergeis_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_tombs", "cat_sergei_final", "broken_one", SERGEIS_TOMB)


## Strahd in the chapel with the Sunsword: Strahd von Zarovich (455 HP), 10 Vampire Spawns; 3 in 8.
func test_strahd_in_the_chapel_with_the_sunsword() -> void:
	await _final("castle_ravenloft_chapel", "crg_chapel_final_battle", "artifact", CHAPEL_NAVE)


## Strahd in the audience hall with the Sunsword: Strahd von Zarovich (310 HP), 3 Dire Wolfs, 10 Vampire Spawns; 3
## in 8.
func test_strahd_in_the_audience_hall_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court", "court_final_audience_hall", "beast", AUDIENCE_HALL)


## Strahd in his study with the Sunsword: Strahd von Zarovich (605 HP), 2 Swarm of Bats, 6 Vampire Spawns; 3 in 8.
func test_strahd_in_his_study_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court", "court_final_study", "seer", STRAHDS_STUDY)


## Strahd in the treasury with the Sunsword: Strahd von Zarovich (660 HP), Helmed Horror, 9 Vampire Spawns; 3 in 8.
func test_strahd_in_the_treasury_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court_treasury", "court_final_treasury", "tempter", TREASURY)


## Strahd in the donjon with the Sunsword: Strahd von Zarovich (500 HP), 10 Skeletons, 10 Vampire Spawns; 3 in 8.
func test_strahd_in_the_donjon_with_the_sunsword() -> void:
	await _final("castle_ravenloft_larders_dungeon", "larders_donjon", "donjon", DONJON)


## Strahd on the overlook with the Sunsword: Strahd von Zarovich (765 HP), 3 Swarm of Bats, 4 Vampire Spawns; 3 in 8.
func test_strahd_on_the_overlook_with_the_sunsword() -> void:
	await _final("castle_ravenloft_overlook", "crg_overlook_final_battle", "executioner", OVERLOOK)


## Strahd by the Heart of Sorrow with the Sunsword: Strahd von Zarovich (590 HP), Helmed Horror, 8 Vampire Spawns;
## 3 in 8.
func test_strahd_by_the_heart_of_sorrow_with_the_sunsword() -> void:
	await _final("castle_ravenloft_spires_heart", "heart_of_sorrow_final", "marionette", HEART_OF_SORROW)
