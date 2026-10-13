extends FightSeriesCase
## The story's boss fights scaled up for 2024-rules heroes (owner, 2026-10-13: the book's fights were written for weaker
## characters). Over seeds 1-8 the four pregens on the sharp autopilot (smiting, opening with Spirit Guardians and
## throwing Fireball, as the owner plays), standing where walking up to the one who starts the fight leaves them, win
## about 5 in 8 on Balanced at every level (his target), give or take one. The side quests' bosses are held in
## test_side_quest_bosses.gd.


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


## Izek at 110 HP with four sergeants of the watch.
func test_izeks_duel_at_level_5() -> void:
	await _held("vallaki", 5, "izek_duel", IZEK_SQUARE, 4, 6)


## Izek runs wild at the festival at 225 HP: two sergeants, the captain and two guards try to hold him and
## turn on the party.
func test_izeks_festival_rampage_at_level_5() -> void:
	await _held("vallaki", 5, "festival_izek_rampage", IZEK_SQUARE, 4, 6)


## The Baron's loyalists at the festival: Izek, five sergeants, the captain and four guards (with three more
## sergeants and no more guards, 3).
func test_the_festival_loyalists_at_level_5() -> void:
	await _held("vallaki", 5, "festival_loyalists", FESTIVAL_GROUND, 4, 6)


## Izek at 145 HP in his room with his dolls, three sergeants of the watch and a guard coming in behind the party.
func test_izek_in_his_room_at_level_5() -> void:
	await _held("vallaki_burgomaster_mansion", 5, "izek_confrontation", IZEKS_DOOR, 4, 6)


## The coven's last stand: Morgantha at 180 HP, both daughters at their book 112 HP, and three swarms of rats from
## the grain bins.
func test_the_covens_last_stand_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 4, 6, ["offalia_in_last_stand", "bella_in_last_stand"])


## Morgantha and one daughter, the other split off from the coven: the mill's dogs come up with them (four and
## four swarms of rats with Offalia; six and three swarms with Bella).
func test_morgantha_and_offalia_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 4, 6, ["offalia_in_last_stand"])


func test_morgantha_and_bella_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 4, 6, ["bella_in_last_stand"])


## The Abbot's wrath: the deva at 250 HP, two flesh golems, three Belview brutes and two mongrelfolk.
func test_the_abbots_wrath_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "abbot_wrath", CHANCEL, 4, 6)


## Vasilka (160 HP) rises from her bier with a second flesh golem, nine Belview brutes and three mongrelfolk: 4 of 8,
## the harder side (with seven, 6).
func test_vasilka_defends_the_abbot_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "bride_defends", CHANCEL, 4, 6)


## Vladimir at the beacon with three dead knights (revenants at their full 127 HP), a man-at-arms and two wights,
## the lantern room's dark already met on the way up.
func test_vladimir_at_the_beacon_at_level_8() -> void:
	await _held("argynvostholt_beacon", 8, "beacon_stand", LANTERN_LANDING, 4, 6, ["lamp_dark_cleared"])


## Vladimir's duel in the hall, his three seconds behind him and a fourth at 80 HP.
func test_vladimirs_duel_at_level_8() -> void:
	await _held("argynvostholt_hall", 8, "vladimir_duel", VLADIMIRS_HALL, 4, 6)


## Kiril's challenge once the den's guards are dealt with: four werewolves, three dire wolves and three wolves.
func test_kirils_challenge_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 4, 6, ["den_guards_cleared"])


## Zuleika vouched for the party, so the guards stand with Kiril: five werewolves and five dire wolves.
func test_kirils_challenge_with_the_guards_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 4, 6, ["zuleika_vouched"])


## The whole den turns on the party: Kiril, Emil, Zuleika, three werewolves, two dire wolves and a wolf.
func test_the_dens_reckoning_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "den_reckoning", KIRILS_CAVE, 4, 6, ["den_guards_cleared"])


## Baba Lysaga and her creeping hut (110 HP in this fight) at the stump, past her scarecrow field.
func test_lysaga_and_her_hut_at_level_9() -> void:
	cleared_fights.assign(["berez_scarecrows"])
	await _held("berez", 9, "lysaga_and_hut", LYSAGAS_STUMP, 4, 6, ["berez_scarecrows_burned"])


## Her hut without her, at 195 HP, and three swarms of insects out of its eaves: she was lured to the grave and
## slain there, so her scarecrows never stood up.
func test_the_masterless_hut_at_level_9() -> void:
	await _held("berez", 9, "creeping_hut_masterless", BELOW_THE_STUMP, 4, 6, ["lysaga_lured", "lysaga_slain_at_monument"])


## Rahadin at 300 HP on the stair when the party brings Gertruda out, with two suits of the count's armour and a
## third, battered.
func test_rahadin_on_the_stair_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_STAIR, 4, 6, [], ["gertruda"])


## Rahadin in the hall, two suits of the count's armour with him and a third, battered (90 HP).
func test_rahadin_in_the_hall_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_HALL, 4, 6)


## Rahadin in his chamber with three suits of the count's armour.
func test_rahadin_in_his_chamber_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_rahadin_chamber_fight", RAHADINS_CHAMBER, 4, 6)


## Ludmilla and Volenta, two of Strahd's spawn and two suits of the count's armour.
func test_two_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 4, 6, ["court_anastrasya_story"])


## All three brides and two suits of the count's armour.
func test_all_three_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 4, 6)


## Vladimir and five oathbreakers (revenants, the fifth at 80 HP) at Strahd's tomb, the tomb's keepers already
## met.
func test_vladimir_at_strahds_tomb_at_level_10() -> void:
	cleared_fights.assign(["cat_tomb_keepers"])
	await _held("castle_ravenloft_catacombs_strahd", 10, "cat_oathbreakers", STRAHDS_TOMB, 4, 6, ["cat_keepers_defeated"])


## Old Bonegrinder's bakery counter; Marina's grave on its island; Lysaga's kitchen; Exethanter's shelves; Vosk's vault.
const BAKERY_COUNTER: Array[Vector2i] = [Vector2i(15, 11), Vector2i(14, 12), Vector2i(13, 13), Vector2i(12, 14)]
const MARINAS_GRAVE: Array[Vector2i] = [Vector2i(8, 14), Vector2i(9, 14), Vector2i(8, 15), Vector2i(9, 15)]
const LYSAGAS_KITCHEN: Array[Vector2i] = [Vector2i(11, 5), Vector2i(10, 6), Vector2i(9, 7), Vector2i(8, 8)]
const EXETHANTERS_SHELVES: Array[Vector2i] = [Vector2i(23, 5), Vector2i(22, 6), Vector2i(21, 7), Vector2i(20, 8)]
const VOSKS_VAULT: Array[Vector2i] = [Vector2i(19, 21), Vector2i(19, 20), Vector2i(19, 19), Vector2i(19, 18)]


## A hag split off from the coven is still about 4 or 5 fights in 8 (owner, 2026-10-13: "should be maybe 4/8 even if
## split up"): each comes with the night's mares. Offalia in the bakery at 300 HP with five nightmares.
func test_offalia_in_the_bakery_at_level_6() -> void:
	await _held("old_bonegrinder", 6, "bakery_offalia", BAKERY_COUNTER, 4, 6)


## Bella turned on by the coven, at 250 HP with three nightmares and three of the mill's dogs: 4 of 8.
func test_bella_betrayed_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "bella_betrayed", LOFT, 4, 6)


## Bella on the track at 300 HP with three nightmares; Offalia at 300 with four.
func test_bella_on_the_road_at_level_6() -> void:
	await _held("old_bonegrinder_track", 6, "bella_on_the_road", [], 4, 6)


func test_offalia_on_the_road_at_level_6() -> void:
	await _held("old_bonegrinder_track", 6, "offalia_on_the_road", [], 4, 6)


## Morgantha alone, both daughters gone: 300 HP, three swarms of rats and four nightmares.
func test_morgantha_alone_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 4, 6)


## Baba Lysaga at Marina's grave at 180 HP, her book spells in hand (Fireball, Lightning Bolt, Finger of Death), two
## swarms of insects and four scarecrows.
func test_lysaga_at_the_grave_at_level_9() -> void:
	await _held("berez", 9, "lysaga_at_monument", MARINAS_GRAVE, 4, 6)


## Baba Lysaga in her kitchen (the critical path's fight) at 400 HP, her book spells in hand, six swarms of insects out
## of the jars and four of her scarecrows.
func test_lysaga_in_her_kitchen_at_level_9() -> void:
	await _held("berez_baba_lysagas_hut", 9, "lysaga_in_hut", LYSAGAS_KITCHEN, 4, 6)


## Exethanter among his shelves with six of the wardens' skulls.
func test_exethanter_at_level_10() -> void:
	await _held("amber_temple_library", 10, "exethanter_wrath", EXETHANTERS_SHELVES, 4, 6)


## Vosk unmasked at 135 HP with two bound skulls. Named and weakened first, he's the easier fight he was (8 of 8).
func test_vosk_unmasked_at_level_10() -> void:
	await _held("amber_temple_vault", 10, "vosk_unmasked", VOSKS_VAULT, 4, 6)


func test_vosk_named_and_weakened_at_level_10() -> void:
	await _held("amber_temple_vault", 10, "vosk_unmasked", VOSKS_VAULT, 5, 8, ["vosk_named", "vosk_weakened"])


## Strahd woken in his coffin by day, for a party carrying the Sunsword, the tomb's keepers already met: 350 HP, two
## swarms of bats and one of his spawn.
func test_strahd_woken_by_day_with_the_sunsword() -> void:
	cleared_fights.assign(["cat_tomb_keepers"])
	prepare = func(st: StoryState) -> void:
		st.set_flag("cat_keepers_defeated", true)
		var bearer := st.party[0]
		bearer.add_item("sunsword")
		bearer.attune("sunsword")
		bearer.equip("sunsword", "main_hand")
	await _held("castle_ravenloft_catacombs_strahd", 10, "cat_daylight_waking", STRAHDS_TOMB, 4, 6)
	prepare = Callable()
	cleared_fights.clear()

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
## (owner, 2026-10-13): won 5 in 8 by the sharp party, give or take one. He keeps out of the blade's light where he can,
## so his spawn stand with him.
func _final(location: String, encounter: String, card: String, at: Array[Vector2i]) -> void:
	prepare = func(st: StoryState) -> void:
		st.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": card}
		st.set_quest_stage("strahds_lair", "foretold")
		var bearer := st.party[0]
		bearer.add_item("sunsword")
		bearer.attune("sunsword")
		bearer.equip("sunsword", "main_hand")
	await _held(location, 10, encounter, at, 4, 6)
	prepare = Callable()


## Strahd at 375 Hit Points on his nightmare, two swarms of bats and two of his spawn.
func test_strahd_in_the_horsemans_crypt_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs", "cat_horseman_final", "horseman", HORSEMANS_CRYPT)


## Strahd at 350 in his own tomb with the two spawn who keep it.
func test_strahd_in_his_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_strahd", "cat_darklord_final", "darklord", DARKLORDS_TOMB)


## Strahd at 400 among his parents' tombs, three specters and two of his spawn with him (at 350 with three spawn, 3).
func test_strahd_at_the_royal_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_tombs", "cat_royal_final", "ghost", ROYAL_TOMB)


## Strahd at 350 at Sergei's tomb, three wolves, two swarms of bats and three of his spawn.
func test_strahd_at_sergeis_tomb_with_the_sunsword() -> void:
	await _final("castle_ravenloft_catacombs_tombs", "cat_sergei_final", "broken_one", SERGEIS_TOMB)


## Strahd at 350 in the chapel, the two thralls in the pews and four more of his spawn: 4 of 8, the harder side (with
## three more, 1 to 6 as his Hit Points go from 350 to 450: the chapel swings hardest).
func test_strahd_in_the_chapel_with_the_sunsword() -> void:
	await _final("castle_ravenloft_chapel", "crg_chapel_final_battle", "artifact", CHAPEL_NAVE)


## Strahd at 350 on his throne, three wolves of the dais and four of his spawn.
func test_strahd_in_the_audience_hall_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court", "court_final_audience_hall", "beast", AUDIENCE_HALL)


## Strahd at 350 in his study, two swarms of bats and five of his spawn.
func test_strahd_in_his_study_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court", "court_final_study", "seer", STRAHDS_STUDY)


## Strahd at 400 in the treasury, the helmed horror and three of his spawn (at 350, 6).
func test_strahd_in_the_treasury_with_the_sunsword() -> void:
	await _final("castle_ravenloft_court_treasury", "court_final_treasury", "tempter", TREASURY)


## Strahd at 350 in the donjon, ten skeletons and four of his spawn.
func test_strahd_in_the_donjon_with_the_sunsword() -> void:
	await _final("castle_ravenloft_larders_dungeon", "larders_donjon", "donjon", DONJON)


## Strahd at 350 on the overlook, three swarms of bats and one of his spawn.
func test_strahd_on_the_overlook_with_the_sunsword() -> void:
	await _final("castle_ravenloft_overlook", "crg_overlook_final_battle", "executioner", OVERLOOK)


## Strahd at 350 by the Heart of Sorrow, the helmed horror and two of his spawn.
func test_strahd_by_the_heart_of_sorrow_with_the_sunsword() -> void:
	await _final("castle_ravenloft_spires_heart", "heart_of_sorrow_final", "marionette", HEART_OF_SORROW)
