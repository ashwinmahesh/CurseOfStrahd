extends TestCase
## Storyline QA (2026-10-12): the Wiki lane's findings at Van Richten's Tower, the werewolf den, Mount Baratok and Berez
## ("QA - Wiki Walkthrough Findings" in the vault, #54-#62), each played the way a party meets it.


## Finding 54: a lie to Ezmerelda about her teacher left The Hunter's Tower with nowhere to go.
func test_a_lie_to_ezmerelda_keeps_the_secret() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "van_richtens_tower", 12)
	st.set_quest_stage("the_hunters_tower", "heard")
	st.set_quest_stage("the_hunters_tower", "inside")
	st.set_flag("van_richten_identity_known")
	SideQuestPlay.play(st, "van_richtens_tower/ezmerelda:where", ["We were wrong"])
	assert_eq(st.quest_stage("the_hunters_tower"), "kept")


## Finding 55: with Ezmerelda along, the tower's door ended her quest at Inside with nobody on the shore to tell.
func test_ezmerelda_walks_into_the_tower_with_the_party() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 6, "van_richtens_tower", 12)
	st.set_quest_stage("the_hunters_tower", "heard")
	assert_true(st.add_guest("ezmerelda"))
	SideQuestPlay.play(st, "van_richtens_tower/tower:open")
	assert_eq(st.quest_stage("the_hunters_tower"), "with_her")
	var ally := SideQuestPlay.party(["ilse_varga"], 6, "van_richtens_tower", 12)
	ally.tarokka = {"ally": "mists"}   # Ezmerelda, away at the abbey
	SideQuestPlay.play(ally, "van_richtens_tower/tower:open")
	assert_eq(ally.quest_stage("the_hunters_tower"), "", "named by the cards and away: no quest to strand")


## Finding 56: Mordenkainen travelling with the party couldn't hear the storm was gone, or take his letters.
func test_mordenkainen_along_hears_the_storm_and_reads_the_letters() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "mount_baratok", 20)
	st.set_flag("mordenkainen_restored")
	st.set_quest_stage("the_forgotten_storm", "asked")
	st.set_quest_stage("the_forgotten_storm", "broken")
	st.set_flag("storm_dispersed")
	assert_true(st.add_guest("mordenkainen"))
	SideQuestPlay.play(st, "mount_baratok/the_forgotten_storm:glass")
	assert_eq(st.quest_stage("the_forgotten_storm"), "done")
	SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:joined")
	assert_eq(st.quest_stage("the_mages_lost_pages"), "asked")
	st.set_flag("corvina_letter_1")
	st.set_flag("corvina_letter_2")
	var beats := SideQuestPlay.play(st, "mount_baratok/the_mages_lost_pages:letter_3", ["You promised"])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_mages_lost_pages"), "named")
	assert_true(SideQuestPlay.text(beats).contains("standing in the snow"))


## Finding 59: turning on Lysaga after a bargain, outside her hut, could never happen.
func test_lysaga_can_be_betrayed_outside() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 9, "berez", 12)
	st.set_flag("lysaga_guests")
	st.set_flag("lysaga_bargained")
	assert_eq(SideQuestPlay.standing(st, "berez", "baba_lysaga"), "berez/lysaga:bargained_after")
	var beats := SideQuestPlay.play(st, "berez/lysaga:bargained_after", ["We never said"])
	assert_eq(SideQuestPlay.combat_of(beats), "lysaga_and_hut")


## Finding 60: Kiril dead in the reckoning didn't count for Strahd's attention.
func test_the_reckoning_counts_for_strahd() -> void:
	var st := SideQuestPlay.party(["ilse_varga"], 7, "werewolf_den_caves", 12)
	var before := StrahdPresence.attention(st)
	st.set_flag("den_broken")
	assert_eq(StrahdPresence.attention(st), before + 1, "a point of his attention, as for Kiril defeated")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "strahd/attention:grievance"))
	assert_true(said.contains("My wolves have a new leader"), said)


## Finding 61: children freed after all were still "left" in Thistle's talk.
func test_freed_children_arent_left() -> void:
	var st := SideQuestPlay.party(["thistle"], 7, "werewolf_den_caves", 22)
	st.set_flag("den_children_left")
	st.set_flag("den_children_freed")
	var said := SideQuestPlay.text(SideQuestPlay.play(st, "camp/thistle:doubt"))
	assert_false(said.contains("We left the pups"), said)


## Wiki finding 138: Khazan says "You said mine at my door" only to a party that said his name there; one that came in
## by the poses, the scaffold or with Van Richten is told it didn't.
func test_khazan_knows_whether_you_said_his_name_at_the_door() -> void:
	var door := SideQuestPlay.party(["ilse_varga"], 10, "van_richtens_tower", 12)
	door.set_flag("khazan_known")
	SideQuestPlay.play(door, "van_richtens_tower/tower:door", ["Say the name"])
	assert_true(bool(door.get_flag("khazan_said_at_door", false)), "saying the name at the door is remembered")
	for said: bool in [true, false]:
		var st := SideQuestPlay.party(["ilse_varga"], 10, "khazan_undercroft", 12)
		if said:
			st.set_flag("khazan_said_at_door")
		var text := SideQuestPlay.text(SideQuestPlay.play(st, "van_richtens_tower/the_name_over_the_door:khazan", ["Who are you?"]))
		assert_eq(text.contains("You said mine at my door"), said, "the greeting knows (said %s)" % said)
		assert_eq(text.contains("you said it at the door"), said, "and so does who he is (said %s)" % said)
		assert_eq(text.contains("You never said mine at my door"), not said, "told they didn't (said %s)" % said)
