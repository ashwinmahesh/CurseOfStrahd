extends TestCase
## Guests leaving the party (Ashwin, 2026-10-12): "I cant have him leave the party to go back?" and "I just loaded a
## save and Adrian ... was no longer there". A guest can be sent home from the Party screen unless something keeps
## them; one who falls in a fight is carried home to heal (or patched up if they can't leave) instead of walking on
## dead; and a save holding a fallen guest mends on load.


func test_who_can_be_sent_home() -> void:
	var st := _with(["adrian_martikov", "ireena"])
	assert_eq(st.guest_stays("adrian_martikov"), "", "Adrian can go home")
	assert_ne(st.guest_stays("ireena"), "", "Ireena says why she stays")
	assert_false(st.send_guest_home("ireena"))
	assert_true(st.send_guest_home("adrian_martikov"))
	assert_false("adrian_martikov" in st.guest_ids)
	assert_eq(SideQuestPlay.standing(st, "wizard_of_wines", "adrian_martikov"), "wizard_of_wines/adrian:start",
		"back at the winery, where he can be asked along again")
	var ally := _with(["sir_godfrey_gwilym"])
	ally.tarokka = {"ally": "ghost"}
	assert_ne(ally.guest_stays("sir_godfrey_gwilym"), "", "Madam Eva's ally sees it through")


func test_a_fallen_guest_goes_home_to_heal() -> void:
	var st := _with(["adrian_martikov", "ireena"])
	for g in st.guests:
		g.hp = 0
		g.dead = true
	var home := st.see_to_fallen_guests()
	assert_eq(home, ["Adrian Martikov"] as Array[String], "Adrian is carried home")
	assert_false("adrian_martikov" in st.guest_ids)
	assert_true("ireena" in st.guest_ids, "Ireena stays")
	var ireena := st.guests[st.guest_ids.find("ireena")]
	assert_false(ireena.dead)
	assert_eq(ireena.hp, 1, "patched up")


## His save: Adrian dead in the guests after the winery fight. Loading it outside a fight sends him home; a save made
## mid-fight keeps the fight as it was.
func test_a_save_with_a_fallen_guest_mends_on_load() -> void:
	var st := _with(["adrian_martikov"])
	st.guests[0].hp = 0
	st.guests[0].dead = true
	var data := {"story": JSON.parse_string(JSON.stringify(st.to_dict()))}
	GameState.from_dict(data)
	assert_false("adrian_martikov" in GameState.story.guest_ids, "sent home on load")
	data["combat"] = {"encounter": "winery_occupation", "location": "wizard_of_wines_winery", "data": {}}
	GameState.from_dict(data)
	assert_true("adrian_martikov" in GameState.story.guest_ids, "a mid-fight save keeps its fight as it was")
	GameState.reset()


func test_send_home_on_the_party_screen() -> void:
	var st := _with(["adrian_martikov", "ireena"])
	var p := PartyScreen.new()
	add_child(p)
	p.open(self, st, 0)
	assert_true(p.find_child("SendHome_ireena", true, false) == null, "Ireena has no Send home")
	var b := p.find_child("SendHome_adrian_martikov", true, false) as Button
	assert_true(b != null, "Adrian has one")
	b.pressed.emit()
	assert_false("adrian_martikov" in st.guest_ids)
	assert_true(p.find_child("SendHome_adrian_martikov", true, false) == null, "and his card is gone")
	p.free()


func _with(ids: Array[String]) -> StoryState:
	var st := SideQuestPlay.party(["ilse_varga"], 5, "wizard_of_wines", 12)
	st.set_flag("adrian_met")
	for id in ids:
		assert_true(st.add_guest(id), id)
	return st
