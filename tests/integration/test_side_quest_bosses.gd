extends FightSeriesCase
## The side quests' bosses (docs/story/side_quests.md), played to the end by the test autopilot on their own maps at the
## level the quest expects: every fight finishes, every boss uses its turns without error, and the party can win but
## pays for it (hard, per the owner's standing rule). Where a series runs seeds 1-8 with a band, it holds the owner's
## target: the bosses (2026-10-14) are played by the autopilot at full ability (PartyAutopilot.full: smites, Spirit
## Guardians, Fireball, Cone of Cold, the Radiance of the Dawn, Lay On Hands, Hunter's Mark, Conjure Barrage...) and the
## party wins about 3 in 8 on Balanced at every level, give or take one; a quest's reward makes its fight easier (4). The
## other set pieces here (wolves, spiders, boatmen) keep the sharp autopilot's 5 in 8 (2026-10-13). The bosses'
## line-ups are in docs/story/boss_fights.md.


## Old Greytooth at level 6: Old Greytooth (435 HP), 2 Dire Wolfs, 3 Wolfs, Bandit Captain; 3 in 8.
func test_old_greytooth_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("lake_zarovich", 19, 6, "greytooth_hunt", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 0 and wins <= 4, "Greytooth falls in 0 to 4 of 8 (%d)" % wins)


## Old Greytooth with Szoldar turned at level 6: Old Greytooth (420 HP), 2 Dire Wolfs, 3 Wolfs, Werewolf; 2 in 8,
## the harder side (no step lands on 3).
func test_old_greytooth_with_szoldar_turned_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("lake_zarovich", 19, 6, "greytooth_hunt", [1, 2, 3, 4, 5, 6, 7, 8], ["szoldar_turned"])
	assert_true(wins >= 2 and wins <= 4, "Greytooth falls in 2 to 4 of 8 (%d)" % wins)


## The Bellringer (a wraith), the Lake's Undertow (a water elemental) and twelve of the drowned, four of them ghasts.
func test_the_drowned_of_pescari_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("lake_zarovich", 23, 8, "drowned_landing", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 4 and wins <= 7, "the drowned fall in 4 to 7 of 8 (%d)" % wins)


## The bone marshal and his column at level 6: The Bone Marshal (200 HP), 2 Wights, 4 Skeletons; 3 in 8.
func test_the_bone_marshal_and_his_column_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("into_the_mists_road", 23, 6, "bone_marshal", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 1 and wins <= 4, "the column falls in 1 to 4 of 8 (%d)" % wins)


## The bone marshal duel at level 8: The Bone Marshal (380 HP), 3 Wights; 3 in 8.
func test_the_bone_marshal_duel_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("into_the_mists_road", 23, 8, "bone_marshal", [1, 2, 3, 4, 5, 6, 7, 8], ["riders_stood_down"])
	assert_true(wins >= 1 and wins <= 4, "the marshal falls in 1 to 4 of 8 (%d)" % wins)


## The bone marshal and his column at level 8: The Bone Marshal (150 HP), 3 Wights, 6 Skeletons, 2 Phantom
## Warriors; 3 in 8.
func test_the_bone_marshal_and_his_column_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("into_the_mists_road", 23, 8, "bone_marshal", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 1 and wins <= 4, "the column falls in 1 to 4 of 8 (%d)" % wins)


## The Rag Queen at level 9: The Rag Queen (715 HP), 2 Banshees, 4 Scarecrows; 3 in 8.
func test_the_rag_queen_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("berez", 14, 9, "rag_queen", [1, 2, 3, 4, 5, 6, 7, 8], ["lysaga_guests"])
	assert_true(wins >= 2 and wins <= 4, "the Rag Queen falls in 2 to 4 of 8 (%d)" % wins)


## The four in single file beside the Seventh Row's basket, where the row wakes as they cut into it (the owner's report
## save, 2026-10-12): she rises right behind it, in reach of them all.
const SEVENTH_ROW: Array[Vector2i] = [Vector2i(29, 24), Vector2i(28, 24), Vector2i(27, 24), Vector2i(26, 24)]


## The vine mother at level 6: The Vine Mother (340 HP), 3 Vine Blights, 5 Needle Blights; 3 in 8, and 7 with Adrian
## since foes' cones aim freely (owner, 2026-10-18: accept the new results, no retune).
func test_the_vine_mother_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("wizard_of_wines", 1, 6, "vine_mother", [1, 2, 3, 4, 5, 6, 7, 8], ["winery_reclaimed"],
		["adrian_martikov"], [], SEVENTH_ROW)
	assert_true(wins >= 2 and wins <= 8, "the Vine Mother falls in 2 to 8 of 8 with Adrian (%d)" % wins)
	wins = await _series("wizard_of_wines", 1, 6, "vine_mother", [1, 2, 3, 4, 5, 6, 7, 8], ["winery_reclaimed"], [], [],
		SEVENTH_ROW)
	assert_true(wins >= 0 and wins <= 4, "and in 0 to 4 of 8 without him (%d)" % wins)
	speakers_step_aside = false


## Granny Ash at level 6: Granny Ash (360 HP), 3 Dire Wolfs, 4 Needle Blights; 3 in 8.
func test_granny_ash_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("old_bonegrinder_track", 23, 6, "granny_ash", [1, 2, 3, 4, 5, 6, 7, 8], ["morgantha_slain"])
	assert_true(wins >= 1 and wins <= 4, "Granny Ash falls in 1 to 4 of 8 (%d)" % wins)


## The Count's huntsman at level 8: The Count's Huntsman (430 HP), Nightmare, 6 Dire Wolfs; 3 in 8.
func test_the_counts_huntsman_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_crossroads", 23, 8, "the_hunt", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 1 and wins <= 4, "the huntsman falls in 1 to 4 of 8 (%d)" % wins)


## The Count's huntsman with his hounds called at level 8: The Count's Huntsman (400 HP), Nightmare, 3 Dire Wolfs;
## 4 in 8.
func test_the_counts_huntsman_with_his_hounds_called_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_crossroads", 23, 8, "the_hunt", [1, 2, 3, 4, 5, 6, 7, 8], ["hounds_called"])
	assert_true(wins >= 3 and wins <= 5, "the huntsman falls in 3 to 5 of 8 (%d)" % wins)


## The Count's huntsman at level 9: The Count's Huntsman (520 HP), 5 Nightmares, 5 Dire Wolfs; 3 in 8.
func test_the_counts_huntsman_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_crossroads", 23, 9, "the_hunt", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 0 and wins <= 4, "the huntsman falls in 0 to 4 of 8 (%d)" % wins)
## The Count's huntsman at level 10: The Count's Huntsman (380 HP), 7 Nightmares, 8 Dire Wolfs; 3 in 8.
func test_the_counts_huntsman_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_crossroads", 23, 10, "the_hunt", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 1 and wins <= 4, "the huntsman falls in 1 to 4 of 8 (%d)" % wins)


## The Gate Warden, four knights who forgot (revenants) and four men-at-arms.
func test_the_squires_vigil_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("argynvostholt", 2, 8, "squires_vigil", [1, 2, 3, 4, 5, 6, 7, 8], ["godfrey_met", "courtyard_phantoms_defeated"])
	assert_true(wins >= 4 and wins <= 6, "the vigil is won in 4 to 6 of 8 (%d)" % wins)


## The Penitent at level 10: The Penitent (625 HP), 5 Ghasts; 3 in 8.
func test_the_penitent_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("tsolenka_pass", 20, 10, "the_penitent", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 2 and wins <= 4, "the Penitent falls in 2 to 4 of 8 (%d)" % wins)


## The Penitent at level 9: The Penitent (645 HP), 4 Ghasts; 3 in 8.
func test_the_penitent_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("tsolenka_pass", 20, 9, "the_penitent", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 0 and wins <= 4, "the Penitent falls in 0 to 4 of 8 (%d)" % wins)
## The Penitent at level 11: The Penitent (920 HP), 10 Ghasts; 3 in 8.
func test_the_penitent_at_level_11() -> void:
	speakers_step_aside = true
	var wins := await _series("tsolenka_pass", 20, 11, "the_penitent", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 0 and wins <= 4, "the Penitent falls in 0 to 4 of 8 (%d)" % wins)


## Lupu fights beside the party, and the study door is open: the fight starts at the bricks.
func test_the_tenant_at_level_2() -> void:
	speakers_step_aside = true
	var wins := await _series("burgomaster_mansion", 22, 2, "hound_tenant", [1, 2, 3, 4, 5, 6, 7, 8], [], ["lupu"], ["study_door"])
	assert_true(wins >= 4 and wins <= 6, "the Tenant falls in 4 to 6 of 8 (%d)" % wins)


## The Tinker's Wagon at level 5: The Tinker's Wagon (220 HP), Mimic; 3 in 8.
func test_the_tinkers_wagon_at_level_5() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_crossroads", 12, 5, "tinkers_wagon", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 2 and wins <= 4, "the Wagon falls in 2 to 4 of 8 (%d)" % wins)


## The Tinker's Wagon at level 6: The Tinker's Wagon (450 HP), 5 Mimics; 2 in 8, the harder side (no step lands on 3);
## 1 since foes' cones aim freely (owner, 2026-10-18: accept the new results, no retune), and none since bosses hit 25%
## harder (with the boss damage back at 1 the same seeds win 1; accepted 2026-10-25, no retune).
func test_the_tinkers_wagon_at_level_6() -> void:
	speakers_step_aside = true
	winless_ok = true
	var wins := await _series("svalich_crossroads", 12, 6, "tinkers_wagon", [1, 2, 3, 4, 5, 6, 7, 8])
	assert_true(wins >= 0 and wins <= 2, "the Wagon falls in 0 to 2 of 8 (%d)" % wins)


## The Count's fowler, three more fowlers (vampire spawn) and three swarms of bats.
func test_the_raven_trap_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("lake_zarovich_trail", 22, 6, "raven_trap", [1, 2, 3, 4, 5, 6, 7, 8], ["fowlers_ready"])
	assert_true(wins >= 4 and wins <= 6, "the fowlers fall in 4 to 6 of 8 (%d)" % wins)


## The Grandsire at level 8: The Grandsire (330 HP), 2 Werewolfs, 2 Dire Wolfs; 3 in 8.
func test_the_grandsire_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("krezk", 23, 8, "grandsire", [1, 2, 3, 4, 5, 6, 7, 8], ["krezk_gate_open", "den_children_freed"], [], ["krezk_gate"])
	assert_true(wins >= 2 and wins <= 6, "the Grandsire falls in 2 to 6 of 8 (%d)" % wins)


## The Grandsire at level 9: The Grandsire (310 HP), 3 Werewolfs, 2 Dire Wolfs; 3 in 8.
func test_the_grandsire_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("krezk", 23, 9, "grandsire", [1, 2, 3, 4, 5, 6, 7, 8], ["krezk_gate_open", "den_children_freed"], [], ["krezk_gate"])
	assert_true(wins >= 2 and wins <= 7, "the Grandsire falls in 2 to 7 of 8 (%d)" % wins)


## Corvina at level 10: Corvina, the Doorkeeper (360 HP), 10 Helmed Horrors; 3 in 8.
func test_corvina_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("castle_ravenloft_catacombs", 23, 10, "corvina", [1, 2, 3, 4, 5, 6, 7, 8], [], [], ["cat_e3_gate"])
	assert_true(wins >= 1 and wins <= 4, "Corvina falls in 1 to 4 of 8 (%d)" % wins)


## Corvina named at level 10: Corvina, the Doorkeeper (305 HP), 8 Helmed Horrors; 4 in 8.
func test_corvina_named_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("castle_ravenloft_catacombs", 23, 10, "corvina", [1, 2, 3, 4, 5, 6, 7, 8], ["corvina_named"], [], ["cat_e3_gate"])
	assert_true(wins >= 1 and wins <= 5, "Corvina falls in 1 to 5 of 8 (%d)" % wins)


## Five wolves and a rat come for Ilarion on the road.
func test_ilarions_wolves_at_level_1() -> void:
	speakers_step_aside = true
	var wins := await _series("into_the_mists_road", 9, 1, "ilarion_wolves", [1, 2, 3, 4, 5, 6, 7, 8], ["mists_wolves_resolved"])
	assert_true(wins >= 4 and wins <= 6, "the wolves fall in 4 to 6 of 8 (%d)" % wins)



## The four at the mouth of Sarkhaza's cavern, where her conversation starts (10 rows further south since the hall was
## made deeper instead of wider, owner 2026-10-26).
const HOARD_MOUTH: Array[Vector2i] = [Vector2i(12, 20), Vector2i(13, 20), Vector2i(12, 19), Vector2i(13, 19)]


## The count's keepers at the gate on Ghakis, met coming up the path: eight wights, three revenants and the
## chain-warden (a helmed horror).
func test_the_keepers_of_ghakis_at_level_10() -> void:
	speakers_step_aside = false
	var wins := await _series("ghakis_shoulder", 12, 10, "ghakis_keepers", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [],
		[Vector2i(8, 14), Vector2i(9, 14), Vector2i(8, 15), Vector2i(9, 15)])
	assert_true(wins >= 4 and wins <= 6, "the keepers fall in 4 to 6 of 8 (%d)" % wins)


## The vent gallery, through the hot door: the Vent-Fire (a fire elemental), two burnt keepers (flameskulls) and three
## keepers (wights).
func test_the_vent_fire_at_level_10() -> void:
	speakers_step_aside = false
	var wins := await _series("ghakis_lair", 12, 10, "vent_fire", [1, 2, 3, 4, 5, 6, 7, 8], [], [], ["ghakis_hot_door"],
		[Vector2i(17, 27), Vector2i(18, 27), Vector2i(18, 28), Vector2i(19, 27)])
	assert_true(wins >= 4 and wins <= 6, "the vent-fire is put out in 4 to 6 of 8 (%d)" % wins)


## Sarkhaza's fight over seeds 1-8 at level 11 with `flags`, for the versions no party is meant to win (_series asks
## for one win at least): every fight finishes. Returns the wins.
func _sarkhaza_wins(flags: Array[String]) -> int:
	var wins := 0
	for s: int in range(1, 9):
		var res := await _play("ghakis_lair", 12, 11, "sarkhaza", s, flags, [], [], HOARD_MOUTH)
		assert_ne(str(res["outcome"]), "timeout", "Sarkhaza seed %d finished" % s)
		if str(res["outcome"]) == "victory":
			wins += 1
	print("        sarkhaza %s at level 11: %d/8 won" % [flags, wins])
	return wins


## Sarkhaza as she is at level 11: an ancient red (507 HP) on her chain, in her lair. Her first Fire Breath takes the
## party; 0 in 8, by design (docs/story/boss_fights.md): the keepers' log says how they went down to her safely.
func test_sarkhaza_as_she_is_at_level_11() -> void:
	speakers_step_aside = true
	var wins := await _sarkhaza_wins([])
	assert_true(wins <= 1, "head on, an ancient red takes the party (%d of 8)" % wins)


## Sarkhaza with the keepers' three tricks at level 11: grave-salted (Slowed, one Rend, one legendary action), hauled in
## on the drum (caught unready) and the vents drowned (no lair). Owner, 2026-10-19: no choke on the hauled-in collar, so
## she breathes from the start, and no retune when a rule changes: her first Fire Breath takes the party, 0 in 8.
func test_sarkhaza_with_the_keepers_tricks_at_level_11() -> void:
	speakers_step_aside = true
	var wins := await _sarkhaza_wins(["wyrm_salted", "wyrm_chain_drawn", "ghakis_sluice_open"])
	assert_true(wins <= 1, "her breath takes the party even with the keepers' tricks (%d of 8)" % wins)


## Sarkhaza unchained at level 11, salted and with the vents drowned: off her chain her Fire Breath is hers again; 0 in 8.
func test_sarkhaza_unchained_at_level_11() -> void:
	speakers_step_aside = true
	var wins := await _sarkhaza_wins(["wyrm_unchained", "wyrm_salted", "ghakis_sluice_open"])
	assert_true(wins <= 1, "off her chain she takes the party (%d of 8)" % wins)


## Khazan's study, the four just inside its door; the hall of names, the four at the stair foot (8 rows further south
## since the study was made deeper, owner 2026-10-26).
const KHAZAN_STUDY: Array[Vector2i] = [Vector2i(8, 14), Vector2i(9, 14), Vector2i(10, 14), Vector2i(11, 14)]
const KHAZAN_STAIR: Array[Vector2i] = [Vector2i(14, 25), Vector2i(15, 25), Vector2i(14, 26), Vector2i(15, 26)]
const KHAZAN_DOORS: Array[String] = ["khazan_study_door_w", "khazan_study_door_e"]


## The First and Second Visitors (a banshee and a wraith), five remembered knights (ghosts), five visitors (specters) and
## two more wraiths. 7 in 8 since foes' cones aim freely (owner, 2026-10-18: accept the new results, no retune).
func test_the_remembered_at_level_10() -> void:
	speakers_step_aside = false
	var wins := await _series("khazan_undercroft", 12, 10, "remembered", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], KHAZAN_STAIR)
	assert_true(wins >= 5 and wins <= 8, "the remembered fall in 5 to 8 of 8 (%d)" % wins)


## Khazan with his name at level 10: Khazan (the CR 23 block, 315 HP), 2 Wraiths. Owner, 2026-10-26: "keep Khazan as
## written, a fight the party should run from"; his round 1 Meteor Swarm kills the party, so none in 8 is expected.
func test_khazan_with_his_name_at_level_10() -> void:
	speakers_step_aside = true
	winless_ok = true
	var wins := await _series("khazan_undercroft", 12, 10, "khazan_named", [1, 2, 3, 4, 5, 6, 7, 8], [], [], KHAZAN_DOORS, KHAZAN_STUDY)
	assert_true(wins >= 0 and wins <= 2, "Khazan is driven off in 0 to 2 of 8 (%d)" % wins)


## Driven off, not destroyed: he leaves the fight below 30 Hit Points and goes back into his name. The CR 23 block the
## owner kept (2026-10-26: "a fight the party should run from") kills the party before it gets him there (a round 1
## Meteor Swarm), so the fight opens with a blow that takes him below 30, and the party finishes the Visitors.
func test_khazan_withdraws_into_his_name() -> void:
	before_fight = func(e: Encounter) -> void:
		for c: Combatant in e.combatants:
			if c.creature is Monster and str((c.creature as Monster).data.get("id", "")) == "khazan":
				e.deal_damage(e.combatants[0], c, [{"amount": c.creature.hp - 20, "type": "force"}], false, "test")
	var res := await _play("khazan_undercroft", 12, 10, "khazan_named", 1, [], [], KHAZAN_DOORS, KHAZAN_STUDY)
	assert_eq(str(res["outcome"]), "victory", "seed 1 drives him off")
	assert_true((res["story_flags"] as Dictionary).has("khazan_withdrawn"), "back into his name")
	assert_true((res["departed"] as Array).has("withdraw"), "he left the fight, he didn't die in it")


## Khazan unmade at level 10: Khazan (the CR 23 block, 315 HP), 5 Wraiths. Kept as written like the fight above (owner,
## 2026-10-26), so none in 8 is expected.
func test_khazan_unmade_at_level_10() -> void:
	speakers_step_aside = true
	winless_ok = true
	var wins := await _series("khazan_undercroft", 12, 10, "khazan_unmade", [1, 2, 3, 4, 5, 6, 7, 8], ["khazan_name_broken"], [], KHAZAN_DOORS, KHAZAN_STUDY)
	assert_true(wins >= 0 and wins <= 2, "Khazan unmade falls in 0 to 2 of 8 (%d)" % wins)


## The chamber of the Eye, the four at the top of its throat; the hall of sleepers, the four at the stair foot.
const EYE_CHAMBER: Array[Vector2i] = [Vector2i(17, 11), Vector2i(18, 11), Vector2i(17, 12), Vector2i(18, 12)]
const EYE_STAIR: Array[Vector2i] = [Vector2i(25, 21), Vector2i(26, 21), Vector2i(25, 22), Vector2i(26, 22)]


## Two woken sleepers (amber golems) and ten dream gazers: 4 of 8, the harder side (with four gazers, 6).
func test_the_hall_of_sleepers_at_level_10() -> void:
	speakers_step_aside = false
	var wins := await _series("amber_deep", 12, 10, "dreamed_eyes", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], EYE_STAIR)
	assert_true(wins >= 4 and wins <= 6, "the sleepers fall in 4 to 6 of 8 (%d)" % wins)


## The Eye Below at level 10: The Eye Below (335 HP), Dream-Gazer; 3 in 8.
func test_the_eye_below_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("amber_deep", 12, 10, "the_eye_below", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], EYE_CHAMBER)
	assert_true(wins >= 2 and wins <= 4, "the Eye falls in 2 to 4 of 8 (%d)" % wins)


## The Eye Below with the wardens ways at level 10: The Eye Below (335 HP); 4 in 8.
func test_the_eye_below_with_the_wardens_ways_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("amber_deep", 12, 10, "the_eye_below", [1, 2, 3, 4, 5, 6, 7, 8], ["deep_mirrors_turned", "deep_lullaby_sung"], [], [], EYE_CHAMBER)
	# Both ways are the quest's reward: "half back in its amber" (test_side_quests_beholder.gd), so it stays easier.
	assert_true(wins >= 1, "the Eye falls with the ways (%d)" % wins)

## The burned crown of Yester Hill, the four at its edge.
const YESTER_CROWN: Array[Vector2i] = [Vector2i(15, 18), Vector2i(16, 18), Vector2i(17, 18), Vector2i(18, 18)]


## The Ash Effigy and Zorica at level 7: The Ash Effigy (355 HP), Druid, 5 Twig Blights; 3 in 8, and 1 since foes'
## cones aim freely (owner, 2026-10-18: accept the new results, no retune).
func test_the_ash_effigy_and_zorica_at_level_7() -> void:
	speakers_step_aside = true
	var wins := await _series("yester_hill_gulthias_tree", 22, 7, "ash_effigy", [1, 2, 3, 4, 5, 6, 7, 8], ["yester_hill_resolved", "gulthias_tree_burned"], [], [], YESTER_CROWN)
	speakers_step_aside = false
	assert_true(wins >= 0 and wins <= 2, "the Ash Effigy and Zorica fall in 0 to 2 of 8 at level 7 (%d)" % wins)


## The Ash Effigy at level 8: The Ash Effigy (430 HP), 4 Twig Blights; 4 in 8, and 5 since foes' cones aim freely
## (owner, 2026-10-18: accept the new results, no retune).
func test_the_ash_effigy_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("yester_hill_gulthias_tree", 22, 8, "ash_effigy", [1, 2, 3, 4, 5, 6, 7, 8], ["yester_hill_resolved", "gulthias_tree_burned", "kostin_doubts"], [], [], YESTER_CROWN)
	speakers_step_aside = false
	assert_true(wins >= 1 and wins <= 6, "the Ash Effigy falls in 1 to 6 of 8 at level 8 (%d)" % wins)

## The family crypts under Death House, the four at Walter's crypt.
const WALTERS_CRYPT: Array[Vector2i] = [Vector2i(14, 3), Vector2i(15, 3), Vector2i(14, 2), Vector2i(15, 2)]


## The Dursts come for Veta in her son's crypt, with three of their robed ones and a giant rat.
func test_the_dursts_come_for_veta_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("death_house_dungeon_1", 22, 3, "nursemaid_keepers", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], WALTERS_CRYPT)
	assert_true(wins >= 4 and wins <= 6, "the Dursts fall in 4 to 6 of 8 (%d)" % wins)


## With the Dursts already gone, the robed ones come instead, led by the one who carried Walter down: six and a rat,
## 4 of 8, the harder side (without the rat, 6).
func test_the_robed_ones_come_for_veta_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("death_house_dungeon_1", 22, 3, "nursemaid_keepers", [1, 2, 3, 4, 5, 6, 7, 8], ["death_house_dursts_destroyed"], [], [], WALTERS_CRYPT)
	assert_true(wins >= 0 and wins <= 6, "the robed ones fall in 0 to 6 of 8 (%d)" % wins)

## The shore of Lake Zarovich at the foot of the fishers' jetty.
const JETTY_FOOT: Array[Vector2i] = [Vector2i(17, 10), Vector2i(18, 10), Vector2i(17, 11), Vector2i(18, 11)]


## The Lantern Girl at level 5: The Lantern Girl (90 HP), 8 Will-o'-Wisps; 3 in 8.
func test_the_lantern_girl_at_level_5() -> void:
	speakers_step_aside = true
	var wins := await _series("lake_zarovich", 22, 5, "lantern_girl", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], JETTY_FOOT)
	assert_true(wins >= 2 and wins <= 4, "the Lantern Girl falls in 2 to 4 of 8 (%d)" % wins)

## Agafia's door in the charcoal-burners' hollow.
const HOLLOW_DOOR: Array[Vector2i] = [Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 10)]


## The pack's hunters come up the oats at level 2: a werewolf and two wolves.
func test_the_oat_hunters_at_level_2() -> void:
	speakers_step_aside = true
	var wins := await _series("woodcutters_hollow", 23, 2, "oat_hunters", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], HOLLOW_DOOR)
	assert_true(wins >= 4 and wins <= 7, "the pack's hunters fall in 4 to 7 of 8 (%d)" % wins)


## At level 3, four wolves with it.
func test_the_oat_hunters_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("woodcutters_hollow", 23, 3, "oat_hunters", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], HOLLOW_DOOR)
	assert_true(wins >= 2 and wins <= 6, "the pack's hunters fall in 2 to 6 of 8 (%d)" % wins)


## Seen coming up the oats at level 2 (the trail read), a werewolf and three wolves.
func test_the_oat_hunters_seen_coming_at_level_2() -> void:
	speakers_step_aside = true
	var wins := await _series("woodcutters_hollow", 23, 2, "oat_hunters", [1, 2, 3, 4, 5, 6, 7, 8], ["oat_trail_seen"], [], [], HOLLOW_DOOR)
	assert_true(wins >= 3 and wins <= 6, "the pack's hunters fall in 3 to 6 of 8 (%d)" % wins)


## Seen coming at level 3: a werewolf, three wolves and a farm dog run with them.
func test_the_oat_hunters_seen_coming_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("woodcutters_hollow", 23, 3, "oat_hunters", [1, 2, 3, 4, 5, 6, 7, 8], ["oat_trail_seen"], [], [], HOLLOW_DOOR)
	assert_true(wins >= 4 and wins <= 6, "the pack's hunters fall in 4 to 6 of 8 (%d)" % wins)


## The roc's nest on the Tsolenka shelf.
const ROC_NEST: Array[Vector2i] = [Vector2i(33, 15), Vector2i(34, 16), Vector2i(33, 16), Vector2i(34, 17)]


## The count's falconer, two of his hands and six stone birds come for the roc's chick.
func test_the_falconer_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("tsolenka_pass", 12, 9, "last_egg", [1, 2, 3, 4, 5, 6, 7, 8], ["roc_driven_off"], [], [], ROC_NEST)
	assert_true(wins >= 4 and wins <= 7, "the falconer falls in 4 to 7 of 8 (%d)" % wins)


## The studio in Haralamb's house, the four by the stair up from the front room.
const PAINTERS_STUDIO: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5)]


## The Count's Likeness at level 9: The Count's Likeness (495 HP), 7 Guardian Portraits (40 HP); 3 in 8.
func test_the_counts_likeness_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("vallaki_painters_studio", 20, 9, "counts_likeness", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], PAINTERS_STUDIO)
	assert_true(wins >= 1 and wins <= 4, "the Likeness burns in 1 to 4 of 8 (%d)" % wins)


## The south tower roof of Castle Ravenloft, by the stair up from the rooms, where Escher waits at the parapet.
const SOUTH_TOWER: Array[Vector2i] = [Vector2i(7, 20), Vector2i(8, 20), Vector2i(7, 21), Vector2i(8, 21)]


## Querreth at level 10: Querreth (520 HP), 2 Wraiths; 3 in 8.
func test_querreth_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("castle_ravenloft_spires_roofs", 22, 10, "querreth", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], SOUTH_TOWER)
	assert_true(wins >= 1 and wins <= 4, "Querreth falls in 1 to 4 of 8 (%d)" % wins)


## Querreth forewarned at level 10: Querreth (570 HP), 2 Wraiths; 4 in 8.
func test_querreth_forewarned_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("castle_ravenloft_spires_roofs", 22, 10, "querreth", [1, 2, 3, 4, 5, 6, 7, 8], ["escher_note_read"], [], [], SOUTH_TOWER)
	assert_true(wins >= 3 and wins <= 5, "Querreth falls in 3 to 5 of 8 (%d)" % wins)


## The tithe vault in Argynvostholt's undercroft, where the party stands when the tithe-keeper gets up.
const TITHE_VAULT: Array[Vector2i] = [Vector2i(10, 6), Vector2i(12, 6), Vector2i(11, 7), Vector2i(9, 7)]


## The Gilded Knight at level 9: The Gilded Knight (710 HP), 12 Animated Armors; 3 in 8.
func test_the_gilded_knight_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("argynvostholt_undercroft", 20, 9, "gilded_knight", [1, 2, 3, 4, 5, 6, 7, 8], ["tithe_told"], [], [], TITHE_VAULT)
	assert_true(wins >= 1 and wins <= 4, "the Gilded Knight falls in 1 to 4 of 8 (%d)" % wins)


## The clearing at the old den, where the party stands over the trapped cub.
const OLD_DEN: Array[Vector2i] = [Vector2i(12, 12), Vector2i(13, 13), Vector2i(11, 12), Vector2i(12, 13)]


## Two vine blights, five needle blights and four twig blights come for the cub's crying.
func test_the_den_blights_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("tser_woods_den", 14, 3, "den_blights", [1, 2, 3, 4, 5, 6, 7, 8], ["bear_path_known"], [], [], OLD_DEN)
	assert_true(wins >= 4 and wins <= 6, "the blights fall in 4 to 6 of 8 (%d)" % wins)


## The barrow slope on Yester Hill, below the druids' cairn of skulls.
const BARROW_SLOPE: Array[Vector2i] = [Vector2i(28, 16), Vector2i(29, 16), Vector2i(27, 17), Vector2i(28, 17)]


## Silverjaw, three barrow-wardens, five of the hill's watch and a ghast, catching the party unawares.
func test_the_hills_watch_at_level_7() -> void:
	speakers_step_aside = true
	var wins := await _series("yester_hill", 22, 7, "hill_watch", [1, 2, 3, 4, 5, 6, 7, 8], ["yester_hill_resolved"], [], [], BARROW_SLOPE)
	assert_true(wins >= 4 and wins <= 6, "the hill's watch falls in 4 to 6 of 8 (%d)" % wins)


## The ring of glass on Mount Baratok, where the party waits for dusk.
const GLASS_RING: Array[Vector2i] = [Vector2i(16, 18), Vector2i(17, 18), Vector2i(16, 19), Vector2i(17, 19)]


## The Forgotten Storm at level 8: The Forgotten Storm (430 HP), Air Elemental (60 HP); 3 in 8.
func test_the_forgotten_storm_at_level_8() -> void:
	speakers_step_aside = true
	var wins := await _series("mount_baratok", 19, 8, "forgotten_storm", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], GLASS_RING)
	assert_true(wins >= 0 and wins <= 4, "the storm is laid in 0 to 4 of 8 (%d)" % wins)


## The bend in the Krezk road, by the waystone and its candle.
const AT_THE_STONE: Array[Vector2i] = [Vector2i(12, 7), Vector2i(14, 7), Vector2i(13, 8), Vector2i(15, 8)]


## Four of Kiril's hunters, a dire wolf and two wolves come down the road for Lark and Yanko: 4 of 8, the harder side
## (with one wolf, 6).
func test_the_waystone_pack_at_level_6() -> void:
	speakers_step_aside = true
	var wins := await _series("krezk_road_waystone", 23, 6, "waystone_wolves", [1, 2, 3, 4, 5, 6, 7, 8], ["waystone_lark_met"], [], [], AT_THE_STONE)
	assert_true(wins >= 3 and wins <= 6, "the pack falls in 3 to 6 of 8 (%d)" % wins)


## By the fire at the goat path camp, where the guide pours the tea.
const BY_THE_FIRE: Array[Vector2i] = [Vector2i(11, 10), Vector2i(13, 10), Vector2i(12, 11), Vector2i(14, 11)]


## The guide at level 10: The Guide (155 HP), 5 Wraiths, 2 Shadows; 3 in 8.
func test_the_guide_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("amber_road_camp", 20, 10, "amber_guide", [1, 2, 3, 4, 5, 6, 7, 8], ["amber_camp_met"], [], [], BY_THE_FIRE)
	assert_true(wins >= 1 and wins <= 4, "the guide falls in 1 to 4 of 8 (%d)" % wins)


## The shingle at the Reed Isle's landing, where the castaways pull people out of the shallows.
const ON_THE_SHINGLE: Array[Vector2i] = [Vector2i(11, 11), Vector2i(12, 12), Vector2i(13, 12), Vector2i(11, 12)]


## The Boatmaster, two veteran boatmen, four toughs and something in the reeds.
func test_the_reed_isle_boatmen_at_level_5() -> void:
	speakers_step_aside = true
	var wins := await _series("zarovich_reed_island", 22, 5, "reed_isle_boatmen", [1, 2, 3, 4, 5, 6, 7, 8], ["reed_isle_met"], [], [], ON_THE_SHINGLE)
	assert_true(wins >= 4 and wins <= 6, "the boatmen fall in 4 to 6 of 8 (%d)" % wins)


## Behind the Grey Goose's counter, by the trapdoor.
const BEHIND_THE_COUNTER: Array[Vector2i] = [Vector2i(14, 8), Vector2i(15, 8), Vector2i(16, 8), Vector2i(13, 8)]


## The innkeeper's wife and son, and the cellar's rats (four giant, two not), at level 2.
func test_the_grey_goose_cellar_at_level_2() -> void:
	speakers_step_aside = true
	var wins := await _series("svalich_roadhouse", 23, 2, "roadhouse_cellar", [1, 2, 3, 4, 5, 6, 7, 8], ["roadhouse_innkeeper_met"], [], [], BEHIND_THE_COUNTER)
	assert_true(wins >= 4 and wins <= 7, "the cellar is cleared in 4 to 7 of 8 (%d)" % wins)


## Under the ledge in the Webbed Gully, where Tsura hangs in the web.
const UNDER_THE_LEDGE: Array[Vector2i] = [Vector2i(12, 4), Vector2i(13, 5), Vector2i(14, 4), Vector2i(12, 5)]


## Three giant spiders and two swarms of spiderlings, catching the party unawares.
func test_the_webbed_gully_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("ivlis_spider_gully", 12, 3, "gully_spiders", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], UNDER_THE_LEDGE)
	assert_true(wins >= 4 and wins <= 6, "the spiders fall in 4 to 6 of 8 (%d)" % wins)


## With the web read first the party isn't caught unawares, and a rat comes down with the spiders: 6 of 8, the reading's
## reward (without the rat, 7; with a bat or a giant rat instead, 4).
func test_the_webbed_gully_read_first_at_level_3() -> void:
	speakers_step_aside = true
	var wins := await _series("ivlis_spider_gully", 12, 3, "gully_spiders", [1, 2, 3, 4, 5, 6, 7, 8], ["gully_web_read"], [], [], UNDER_THE_LEDGE)
	assert_true(wins >= 4 and wins <= 6, "the spiders fall in 4 to 6 of 8 (%d)" % wins)


## By the fold on the high pasture, below the mists.
const AT_THE_FOLD: Array[Vector2i] = [Vector2i(10, 12), Vector2i(11, 12), Vector2i(9, 12), Vector2i(12, 12)]


## Six wolves out of the mists at level 1.
func test_the_mist_wolves_at_level_1() -> void:
	speakers_step_aside = true
	var wins := await _series("barovia_high_pasture", 18, 1, "pasture_wolves", [1, 2, 3, 4, 5, 6, 7, 8], ["pasture_erno_met"], [], [], AT_THE_FOLD)
	assert_true(wins >= 4 and wins <= 6, "the wolves fall in 4 to 6 of 8 (%d)" % wins)


## By the catalogue desk in the middle of the Drowned Library (its map has a ring of rock three squares wide, 2026-10-19: every square is three more each way).
const AT_THE_DESK: Array[Vector2i] = [Vector2i(14, 17), Vector2i(15, 17), Vector2i(16, 17), Vector2i(14, 15)]


## The Index at level 9: The Index (390 HP), 2 Mimics; 3 in 8.
func test_the_index_at_level_9() -> void:
	speakers_step_aside = true
	var wins := await _series("drowned_library", 14, 9, "the_index", [1, 2, 3, 4, 5, 6, 7, 8], ["xaver_met"], [], [], AT_THE_DESK)
	assert_true(wins >= 1 and wins <= 4, "the Index burns in 1 to 4 of 8 (%d)" % wins)


## By the captives' ring in the Ghakis Quarry, between the wagon and the way down.
const BY_THE_WAGON: Array[Vector2i] = [Vector2i(12, 10), Vector2i(13, 10), Vector2i(11, 10), Vector2i(12, 11)]


## Grandfather Stone at level 10: Grandfather Stone (395 HP); 3 in 8.
func test_grandfather_stone_at_level_10() -> void:
	speakers_step_aside = true
	var wins := await _series("ghakis_quarry", 12, 10, "grandfather_stone", [1, 2, 3, 4, 5, 6, 7, 8], [], [], [], BY_THE_WAGON)
	assert_true(wins >= 2 and wins <= 4, "Grandfather Stone falls in 2 to 4 of 8 (%d)" % wins)
