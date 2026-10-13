extends FightSeriesCase
## The story's boss fights scaled up for 2024-rules heroes (owner, 2026-10-13: the book's fights were written for weaker
## characters). Over seeds 1-8 the four pregens on autopilot, standing where walking up to the one who starts the fight
## leaves them, win about 3 in 8 at levels 3-5 and 2 in 8 from level 6 (his targets). The side quests' bosses are held
## in test_side_quest_bosses.gd.


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


## Izek at his book 112 HP with four sergeants of the watch.
func test_izeks_duel_at_level_5() -> void:
	await _held("vallaki", 5, "izek_duel", IZEK_SQUARE, 2, 4)


## Izek runs wild at the festival: two sergeants, the captain and two guards try to hold him and turn on the party.
func test_izeks_festival_rampage_at_level_5() -> void:
	await _held("vallaki", 5, "festival_izek_rampage", IZEK_SQUARE, 2, 4)


## The Baron's loyalists at the festival: Izek, three sergeants, the captain and two guards (3 in 8 with four sergeants
## too, but then the phase 4 playthrough's Wachter path could lose it).
func test_the_festival_loyalists_at_level_5() -> void:
	await _held("vallaki", 5, "festival_loyalists", FESTIVAL_GROUND, 2, 4)


## Izek in his room with his dolls, three sergeants of the watch and a guard coming in behind the party: 2 of 8, the
## harder side of the owner's 3 (without the guard, 4).
func test_izek_in_his_room_at_level_5() -> void:
	await _held("vallaki_burgomaster_mansion", 5, "izek_confrontation", IZEKS_DOOR, 2, 4)


## The coven's last stand: Morgantha and both daughters at their book 112 HP, and three swarms of rats from the grain
## bins: 1 of 8, the harder side of the owner's 2 (with two swarms, 4).
func test_the_covens_last_stand_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["offalia_in_last_stand", "bella_in_last_stand"])


## Morgantha and one daughter, the other split off from the coven: the mill's dogs (four, and a swarm of rats, with
## Offalia; five with Bella) come up with them.
func test_morgantha_and_offalia_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["offalia_in_last_stand"])


func test_morgantha_and_bella_at_level_6() -> void:
	await _held("old_bonegrinder_loft", 6, "coven_last_stand", LOFT, 1, 3, ["bella_in_last_stand"])


## The Abbot's wrath: the deva at its full 229 HP (the 2025 Monster Manual's), a Belview brute and two mongrelfolk.
func test_the_abbots_wrath_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "abbot_wrath", CHANCEL, 1, 3)


## Vasilka rises from her bier with five Belview brutes and three mongrelfolk.
func test_vasilka_defends_the_abbot_at_level_7() -> void:
	await _held("abbey_of_st_markovia_shrine", 7, "bride_defends", CHANCEL, 1, 3)


## Vladimir at the beacon with three dead knights (revenants at their full 127 HP) and a man-at-arms, the lantern
## room's dark already met on the way up.
func test_vladimir_at_the_beacon_at_level_8() -> void:
	await _held("argynvostholt_beacon", 8, "beacon_stand", LANTERN_LANDING, 1, 3, ["lamp_dark_cleared"])


## Vladimir's duel in the hall, his three seconds behind him.
func test_vladimirs_duel_at_level_8() -> void:
	await _held("argynvostholt_hall", 8, "vladimir_duel", VLADIMIRS_HALL, 1, 3)


## Kiril's challenge once the den's guards are dealt with: three werewolves, three dire wolves and a wolf.
func test_kirils_challenge_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 1, 3, ["den_guards_cleared"])


## Zuleika vouched for the party, so the guards stand with Kiril: four werewolves and a dire wolf.
func test_kirils_challenge_with_the_guards_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "pack_challenge", KIRILS_CAVE, 1, 3, ["zuleika_vouched"])


## The whole den turns on the party: Kiril, Emil, Zuleika, two werewolves, a dire wolf and a wolf. 1 of 8, the harder
## side of the owner's 2 (with no wolf, 5).
func test_the_dens_reckoning_at_level_8() -> void:
	await _held("werewolf_den_caves", 8, "den_reckoning", KIRILS_CAVE, 1, 3, ["den_guards_cleared"])


## Baba Lysaga and her creeping hut at the stump, past her scarecrow field.
func test_lysaga_and_her_hut_at_level_9() -> void:
	cleared_fights.assign(["berez_scarecrows"])
	await _held("berez", 9, "lysaga_and_hut", LYSAGAS_STUMP, 1, 3, ["berez_scarecrows_burned"])


## Her hut without her, at its book 263 HP, and three swarms of insects out of its eaves: she was lured to the grave
## and slain there, so her scarecrows never stood up.
func test_the_masterless_hut_at_level_9() -> void:
	await _held("berez", 9, "creeping_hut_masterless", BELOW_THE_STUMP, 1, 3, ["lysaga_lured", "lysaga_slain_at_monument"])


## Rahadin on the stair when the party brings Gertruda out, with two suits of the count's armour and a third, battered.
func test_rahadin_on_the_stair_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_STAIR, 1, 3, [], ["gertruda"])


## Rahadin in the hall, two suits of the count's armour with him: 1 of 8, the harder side of the owner's 2 (with one
## suit and a battered one, 4).
func test_rahadin_in_the_hall_at_level_10() -> void:
	await _held("castle_ravenloft_court", 10, "court_rahadin_fight", RAHADINS_HALL, 1, 3)


## Rahadin in his chamber with three suits of the count's armour: 1 of 8, the harder side (with two, 3).
func test_rahadin_in_his_chamber_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_rahadin_chamber_fight", RAHADINS_CHAMBER, 1, 3)


## Ludmilla and Volenta, two of Strahd's spawn and two suits of the count's armour.
func test_two_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 1, 3, ["court_anastrasya_story"])


## All three brides and two suits of the count's armour: 1 of 8, the harder side (with one suit, 6).
func test_all_three_brides_at_level_10() -> void:
	await _held("castle_ravenloft_court_weeping", 10, "court_brides_fight", BRIDES_GALLERY, 1, 3)


## Vladimir and four oathbreakers (revenants) at Strahd's tomb, the tomb's keepers already met: 1 of 8, the harder side
## (with three, 3).
func test_vladimir_at_strahds_tomb_at_level_10() -> void:
	cleared_fights.assign(["cat_tomb_keepers"])
	await _held("castle_ravenloft_catacombs_strahd", 10, "cat_oathbreakers", STRAHDS_TOMB, 1, 3, ["cat_keepers_defeated"])
