extends TestCase
## Talking to and giving things to a story ally who travels with the party (owner, 2026-10-17: "Pidlwick is in my party,
## and I now have the key. How do I give it to him?"): what GuestTalk offers from the npc's data, and Pidlwick's key from
## the nest to his back, end to end through the conversations.


func _story(guest: String = "pidlwick_ii") -> StoryState:
	var st := StoryState.new()
	var ch := TestChars.pregen("ilse_varga", 5)
	ch.finish_long_rest()
	st.party.append(ch)
	if guest != "":
		assert_true(st.add_guest(guest))
	return st


func _count(st: StoryState, id: String) -> int:
	var n := 0
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == id:
				n += int(e.get("qty", 1))
	return n


func test_pidlwick_has_a_conversation_and_a_gift_for_the_key() -> void:
	assert_eq(GuestTalk.ref_for("pidlwick_ii"), "castle_ravenloft/spires_pidlwick:companion")
	assert_eq(GuestTalk.ref_for("ismark"), "", "most guests have no conversation of their own, only road lines")
	var st := _story()
	assert_true(GuestTalk.gifts(st, "pidlwick_ii").is_empty(), "no key found yet, nothing to give")
	st.set_flag("pidlwick_key_found")
	var gifts := GuestTalk.gifts(st, "pidlwick_ii")
	assert_eq(gifts.size(), 1)
	assert_eq(str(gifts[0]["ref"]), "castle_ravenloft/spires_pidlwick:key_back")
	assert_eq(str(gifts[0]["item"]), "pidlwicks_key")
	assert_true(Compendium.shared().has("items", "pidlwicks_key"))
	st.set_flag("pidlwick_wound")
	assert_true(GuestTalk.gifts(st, "pidlwick_ii").is_empty(), "he is wound; the key is spent")


func test_the_menu_offers_talk_give_and_send_home() -> void:
	var st := _story()
	var ids: Array[String] = []
	for a in GuestTalk.actions(st, "pidlwick_ii"):
		ids.append(str(a["id"]))
	assert_eq(ids, ["guest_talk:pidlwick_ii", "guest_give:pidlwick_ii", "guest_home:pidlwick_ii"])
	assert_false(bool(GuestTalk.actions(st, "pidlwick_ii")[1].get("enabled", true)), "Give... waits for something to give")
	st.set_flag("pidlwick_key_found")
	assert_true(bool(GuestTalk.actions(st, "pidlwick_ii")[1].get("enabled", true)))
	st.set_quest_stage("toymakers_masterpiece", "willing")
	assert_false(bool(GuestTalk.actions(st, "pidlwick_ii")[2].get("enabled", true)), "on his way to the toymaker, he can't be sent home")
	assert_ne(str(GuestTalk.actions(st, "pidlwick_ii")[2].get("why", "")), "")


func test_the_key_goes_from_the_nest_to_his_back() -> void:
	var st := _story("")
	st.set_flag("pidlwick_met")
	st.set_quest_stage("the_jesters_key", "asked")
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_roost:brass")
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("pidlwick_key_found", false)))
	assert_eq(_count(st, "pidlwicks_key"), 1, "the key is in the pack")
	assert_eq(st.quest_stage("the_jesters_key"), "found")
	# Pidlwick joins (the Tarokka's card), and the key is handed over through Give...
	assert_true(st.add_guest("pidlwick_ii"))
	var gifts := GuestTalk.gifts(st, "pidlwick_ii")
	assert_eq(gifts.size(), 1)
	beats = SideQuestPlay.play(st, str(gifts[0]["ref"]), ["Nothing. Let's go."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("pidlwick_wound", false)))
	assert_eq(st.quest_stage("the_jesters_key"), "returned")
	assert_eq(_count(st, "pidlwicks_key"), 0, "the key is handed over")
	assert_true(st.party_has_item("figurine_of_wondrous_power_ebony_fly"), "and his present is the party's")
	assert_true("pidlwick_ii" in st.guest_ids, "he stays with the party")


func test_talking_to_him_offers_the_key_too() -> void:
	var st := _story()
	st.set_flag("pidlwick_key_found")
	st.set_quest_stage("the_jesters_key", "found")
	st.gain_item("pidlwicks_key", 1, st.party[0])
	var beats := SideQuestPlay.play(st, GuestTalk.ref_for("pidlwick_ii"), ["We found your key", "Nothing. Let's go."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_true(bool(st.get_flag("pidlwick_wound", false)))
	assert_eq(_count(st, "pidlwicks_key"), 0)


func test_an_old_save_with_the_flag_but_no_item_still_works() -> void:
	var st := _story()
	st.set_flag("pidlwick_key_found")   # found before the key was an item
	st.set_quest_stage("the_jesters_key", "found")
	assert_eq(GuestTalk.gifts(st, "pidlwick_ii").size(), 1)
	var beats := SideQuestPlay.play(st, "castle_ravenloft/spires_pidlwick:key_back", ["Nothing. Let's go."])
	assert_eq(SideQuestPlay.missing(beats), "")
	assert_eq(st.quest_stage("the_jesters_key"), "returned")


func test_a_guest_says_one_of_their_own_road_lines_when_talked_to() -> void:
	var st := _story("ismark")
	assert_true(st.add_guest("adrian_martikov"))
	var banter := Banter.new(3)
	var lines := banter.guest_next(st, "fight", "adrian_martikov")
	assert_false(lines.is_empty(), "Adrian has something to say after a fight")
	for l in lines:
		assert_eq(str(l["speaker_id"]), "adrian_martikov", "only Adrian's own lines when asking for Adrian")
	var theirs := banter.guest_next(st, "fight", "ismark")
	assert_false(theirs.is_empty(), "and Ismark's still wait for Ismark")
	for l in theirs:
		assert_eq(str(l["speaker_id"]), "ismark")
