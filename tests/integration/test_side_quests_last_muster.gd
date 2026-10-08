extends TestCase
## The Last Muster (docs/story/side_quests.md): the riders' rumour, the column at the Gates after dark, talking the
## riders down (History, a rite, Persuasion) or not, the Bone Marshal's duel or the whole column, and the blade and pay
## chest taken once.

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func test_zora_counts_the_riders_and_the_marshal_holds_the_gate() -> void:
	var st := SideQuestPlay.party(PARTY, 6, "tser_pool", 18)
	var beats := SideQuestPlay.play(st, "svalich_road/tser_camp:zora", ["Heard anything interesting?"])
	assert_eq(st.quest_stage("last_muster"), "rumored")
	assert_true(SideQuestPlay.text(beats).contains("Twelve"))
	st.location = "into_the_mists_road"
	assert_eq(SideQuestPlay.standing(st, "into_the_mists_road", "marshal_dragomir"), "", "nobody by day")
	st.minute_of_day = 23 * 60
	assert_eq(SideQuestPlay.standing(st, "into_the_mists_road", "marshal_dragomir"), "into_the_mists/last_muster:marshal")
	beats = SideQuestPlay.play(st, "into_the_mists/last_muster:marshal", ["Draw steel"])
	assert_eq(st.quest_stage("last_muster"), "mustered")
	assert_eq(SideQuestPlay.combat_of(beats), "bone_marshal")
	var enc := SideQuestPlay.encounter(st, "into_the_mists_road", "bone_marshal")
	assert_true(SideQuestPlay.has_foe(enc, "bone_marshal"))
	assert_true(SideQuestPlay.has_foe(enc, "Rider of the Last Muster"), "the whole column rides")
	assert_true(SideQuestPlay.xp(enc) >= 5600, "High for level 6: %d" % SideQuestPlay.xp(enc))


func test_the_riders_stand_down_and_the_marshal_asks_for_his_duel() -> void:
	var st := SideQuestPlay.party(PARTY, 8, "into_the_mists_road", 23)
	st.set_quest_stage("last_muster", "rumored")
	var stood := false
	for seed: int in [1, 2, 3, 4, 5, 6]:
		# Ratatoille leads: the History roll is his.
		var copy := SideQuestPlay.party(["ratatoille", "liriel_dawnsong", "thistle", "godrick_pendlebrook"], 8, "into_the_mists_road", 23)
		copy.quests = st.quests.duplicate(true)
		var beats := SideQuestPlay.play(copy, "into_the_mists/last_muster:marshal", ["Tell him what year it is", "Not tonight"], seed)
		if bool(copy.get_flag("riders_stood_down", false)):
			stood = true
			assert_eq(copy.quest_stage("last_muster"), "stood_down")
			assert_eq(SideQuestPlay.combat_of(beats), "", "he'll wait for tomorrow night")
			var enc := SideQuestPlay.encounter(copy, "into_the_mists_road", "bone_marshal")
			assert_false(SideQuestPlay.has_foe(enc, "Rider of the Last Muster"), "the riders sit it out")
			assert_eq((enc["monsters"] as Array).size(), 4, "the marshal and three lieutenants at level 8")
			beats = SideQuestPlay.play(copy, "into_the_mists/last_muster:marshal", ["Then on guard"])
			assert_eq(SideQuestPlay.combat_of(beats), "bone_marshal", "the duel, the next night")
			copy.set_flag("bone_marshal_beaten")
			copy.gold = 0
			SideQuestPlay.play(copy, "into_the_mists/last_muster:after")
			assert_eq(copy.quest_stage("last_muster"), "released")
			assert_eq(roundi(copy.gold), 200)
			assert_true(copy.party_has_item("weapon_plus_2") or copy.party.any(func(c: Character) -> bool: return c.carries("weapon_plus_2__longsword")))
			SideQuestPlay.play(copy, "into_the_mists/last_muster:after")
			assert_eq(roundi(copy.gold), 200, "the chest is empty the second time")
			break
	assert_true(stood, "a History roll talks the riders down")


func test_the_bone_marshal_is_a_boss() -> void:
	var b := Compendium.shared().get_entry("monsters", "bone_marshal")
	assert_eq(str((b["source"] as Dictionary)["book"]), "custom")
	assert_eq(int(b["cr"]), 8)
	assert_eq(int((b["legendary_actions"] as Dictionary)["per_round"]), 3)
	assert_eq(str(b["art"]), "phantom_warrior")
