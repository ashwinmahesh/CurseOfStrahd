extends TestCase
## Ezmerelda's Hunter's Ledger and her hub (Story Allies Presence Plan, package M2; narrative/allies/ezmerelda.dialogue,
## data/quests/hunters_ledger.json, docs/story/side_quests.md). The hub opens from where she stands (one menu option each in
## her tower, abbey and yard conversations) and from clicking her as a guest. The ledger names at most three of thirteen
## killers at a time and pays for the ones the story recorded; four topics play once each, three at a time at most.

const HUB := "allies/ezmerelda:talk"
const TOWER := "van_richtens_tower"
const INN := "vallaki_blue_water_inn"
const ABBEY := "abbey_of_st_markovia"
const QUEST := "hunters_ledger"
const FILE := "allies/ezmerelda"
const WORK := "paying work"
const LEDGER := "work is in the ledger"
const BYE := "We should get moving."

## id -> [the flag the story sets when it is dead, the region of the fight, the level it is named from].
const NAMES := {
	"falls": ["falls_werewolf_slain", "svalich_road", 3],
	"wagon": ["wagon_slain", "svalich_road", 4],
	"fowlers": ["fowlers_slain", "lake_zarovich", 5],
	"vine": ["vine_mother_slain", "wizard_of_wines", 5],
	"morgantha": ["morgantha_slain", "old_bonegrinder", 5],
	"wint": ["yester_hill_resolved", "yester_hill", 6],
	"huntsman": ["huntsman_slain", "svalich_road", 7],
	"grandsire": ["grandsire_slain", "krezk", 7],
	"kiril": ["kiril_defeated", "werewolf_den", 7],
	"khazan": ["khazan_destroyed", "van_richtens_tower", 7],
	"lysaga": ["lysaga_dead", "berez", 8],
	"sarkhaza": ["sarkhaza_slain", "mount_ghakis", 11],
	"eye": ["eye_below_slain", "amber_temple", 9],
}
const RARITY_FROM := {"common": 1, "uncommon": 1, "rare": 5, "very_rare": 9, "legendary": 11}

## What each name pays (Ashwin, 2026-10-19): the six easier names in gold, the seven hardest in one lasting magic item
## nobody else in the story hands out (tests/unit/test_loot_distinct.gd keeps each kind to one place).
const GOLD := {"falls": 1000, "wagon": 1250, "fowlers": 1500, "vine": 1750, "morgantha": 2000, "wint": 2500}
const ITEMS := {
	"huntsman": "armor_plus_1__ring_mail", "grandsire": "weapon_plus_2__battleaxe", "kiril": "weapon_plus_2__spear",
	"khazan": "sun_blade__longsword", "lysaga": "weapon_plus_2__greataxe", "sarkhaza": "armor_plus_2__scale_mail",
	"eye": "weapon_plus_3__maul",
}


func _party(level: int = 8, location: String = TOWER) -> StoryState:
	var st := SideQuestPlay.party(["ilse_varga", "hedda_ironvow"], level, location, 12)
	st.set_flag("ezmerelda_met")
	return st


func _says(beats: Array[Dictionary], words: String) -> bool:
	return SideQuestPlay.text(beats).contains(words)


## Every enabled option text of every menu in the beats.
func _menu(beats: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for b in beats:
		if str(b.get("kind", "")) == "options":
			for o: Variant in b["options"] as Array:
				if bool((o as Dictionary).get("enabled", true)):
					out.append(str((o as Dictionary)["text"]))
	return out


func _has_option(beats: Array[Dictionary], words: String) -> bool:
	for t in _menu(beats):
		if t.contains(words):
			return true
	return false


func _ended(beats: Array[Dictionary]) -> bool:
	return str(beats[-1].get("kind", "")) == "end"


func _count(st: StoryState, id: String) -> int:
	var n := 0
	for ch in st.party:
		for e: Dictionary in ch.inventory:
			if str(e["id"]) == id:
				n += int(e["qty"])
	for e: Dictionary in st.stash:
		if str(e["id"]) == id:
			n += int(e["qty"])
	return n


## The text of the option of node `node` that leads to `target`.
func _option_for(node: String, target: String) -> String:
	for s: Dictionary in DialogueFile.load_key(FILE).nodes[node]:
		if str(s["t"]) == "option" and str(s["ok"]) == target:
			return str(s["text"])
	return ""


func _kill(st: StoryState, id: String) -> void:
	st.set_flag(str((NAMES[id] as Array)[0]))


## The ledger's menu as the party meets it (the first menu of the ledger, after `LEDGER`).
func _ledger_menu(st: StoryState) -> Array[String]:
	var beats := SideQuestPlay.play(st, HUB, [LEDGER])
	var menus: Array[String] = []
	var seen := 0
	for b in beats:
		if str(b.get("kind", "")) == "options":
			seen += 1
			if seen == 2:
				for o: Variant in b["options"] as Array:
					menus.append(str((o as Dictionary)["text"]))
	return menus


## Which names the ledger offers: id -> "ask" or "claim".
func _offers(st: StoryState) -> Dictionary:
	var out := {}
	var menu := _ledger_menu(st)
	for id: String in NAMES:
		if menu.has(_option_for("ledger_menu", "brief_" + id)):
			out[id] = "ask"
		if menu.has(_option_for("ledger_menu", "claim_" + id)):
			out[id] = "claim"
	return out


# --- The doors -------------------------------------------------------------------------------------------------------------

func test_the_hub_is_her_guest_talk_and_every_node_it_names_exists() -> void:
	var npc := Compendium.shared().get_entry("npcs", "ezmerelda")
	assert_eq(str(npc.get("guest_talk", "")), HUB, "clicking her while she travels")
	var f := DialogueFile.load_key(FILE)
	assert_true(f != null and f.errors.is_empty(), "the file reads: %s" % [f.errors if f != null else []])
	assert_true(f.nodes.has("talk") and f.nodes.has("ledger") and f.nodes.has("menu"))
	for id: String in NAMES:
		for n: String in ["brief_" + id, "claim_" + id]:
			assert_true(f.nodes.has(n), "node %s" % n)
	var abbey := DialogueFile.load_key("abbey_of_st_markovia/ezmerelda")
	assert_true(abbey.nodes.has("ledger_door"), "the abbey's door")
	assert_true(DialogueFile.load_key("van_richtens_tower/ezmerelda").nodes.has("ledger_door"), "the tower's door")
	var hunt := DialogueFile.load_key("allies/ezmerelda_hunt")
	assert_true(hunt != null and hunt.nodes.has("yard_menu"))
	# Joining from the hub: the Tarokka's ally goes through the abbey's join (it moves find_the_ally), the rest through M1's.
	assert_true(_option_for("menu", "abbey_of_st_markovia/ezmerelda:join") != "" and _option_for("menu", "allies/ezmerelda_hunt:join") != "")


func test_the_tower_the_abbey_and_the_yard_each_open_the_hub_and_start_the_quest() -> void:
	var tower := _party(8, TOWER)
	tower.set_flag("ezmerelda_met_at_tower")
	var t := SideQuestPlay.play(tower, "van_richtens_tower/ezmerelda:start", [WORK])
	assert_eq(SideQuestPlay.missing(t), "")
	assert_true(_says(t, "oilcloth"), "she shows the book")
	assert_eq(tower.quest_stage(QUEST), "heard")
	assert_true(_ended(t), "and the talk ends")
	var abbey := _party(7, ABBEY)
	var a := SideQuestPlay.play(abbey, "abbey_of_st_markovia/ezmerelda:start", [WORK])
	assert_eq(SideQuestPlay.missing(a), "")
	assert_true(_says(a, "oilcloth"))
	assert_eq(abbey.quest_stage(QUEST), "heard")
	assert_true(_ended(a))
	var inn := _party(8, INN)
	inn.set_flag("ezmerelda_left_tower")
	inn.set_flag("ezmerelda_met_at_tower")
	var y := SideQuestPlay.play(inn, "allies/ezmerelda_hunt:yard", [WORK])
	assert_eq(SideQuestPlay.missing(y), "")
	assert_true(_says(y, "oilcloth"))
	assert_eq(inn.quest_stage(QUEST), "heard")
	assert_true(_ended(y))
	var road := _party(8, "svalich_crossroads")
	assert_true(road.add_guest("ezmerelda"))
	var r := SideQuestPlay.play(road, HUB)
	assert_true(_says(r, "oilcloth"), "a click on the road opens it too")
	assert_eq(road.quest_stage(QUEST), "heard", "and starts the quest")
	assert_true(_ended(r))


func test_she_does_not_offer_work_to_a_party_she_has_turned_against() -> void:
	var st := _party(8, TOWER)
	st.set_flag("ezmerelda_met_at_tower")
	st.set_flag("ezmerelda_trust", -2)   # her wagon robbed
	var beats := SideQuestPlay.play(st, "van_richtens_tower/ezmerelda:start")
	assert_false(_has_option(beats, WORK), "no paying work yet")
	assert_eq(st.quest_stage(QUEST), "")
	st.set_flag("ezmerelda_trust", 0)
	assert_true(_has_option(SideQuestPlay.play(st, "van_richtens_tower/ezmerelda:start"), WORK), "it comes back with a little trust")


func test_the_first_talk_shows_the_book_and_later_ones_open_cold_or_warm_by_trust() -> void:
	var st := _party()
	var first := SideQuestPlay.play(st, HUB)
	assert_true(_says(first, "Three names at a time"), "the ledger explained")
	assert_false(_says(first, "Hands where I can see them"), "no greeting the first time")
	var cold := SideQuestPlay.play(st, HUB)
	assert_true(_says(cold, "Hands where I can see them"))
	assert_false(_says(cold, "oilcloth"), "the book is shown once")
	st.set_flag("ezmerelda_trust", 2)
	assert_true(_says(SideQuestPlay.play(st, HUB), "Still breathing"), "warm at trust 2")
	assert_true(_ended(cold))


# --- The topics ------------------------------------------------------------------------------------------------------------

func test_the_hub_offers_at_most_three_topics_and_each_plays_once() -> void:
	var st := _party(8)
	SideQuestPlay.play(st, HUB)   # the first talk shows the book
	var beats := SideQuestPlay.play(st, HUB)
	var shown := 0
	for target: String in ["view_a", "rudolph", "leg", "vistani"]:
		if _has_option(beats, _option_for("menu", target)):
			shown += 1
	assert_eq(shown, 3, "four topics are waiting and three are offered: the newest first")
	assert_true(_has_option(beats, _option_for("menu", "view_a")), "where we are heading")
	assert_false(_has_option(beats, _option_for("menu", "vistani")), "the oldest waits")
	# hear them all; each plays once, then the fourth appears
	var rudolph := SideQuestPlay.play(st, HUB, [_option_for("menu", "rudolph")])
	assert_eq(SideQuestPlay.missing(rudolph), "")
	assert_true(bool(st.get_flag("ezmerelda_heard_rudolph", false)))
	assert_true(_ended(rudolph))
	var again := SideQuestPlay.play(st, HUB)
	assert_false(_has_option(again, _option_for("menu", "rudolph")), "heard once")
	assert_true(_has_option(again, _option_for("menu", "vistani")), "the fourth takes its place")
	for target: String in ["view_a", "leg", "vistani"]:
		assert_eq(SideQuestPlay.missing(SideQuestPlay.play(st, HUB, [_option_for("menu", target)])), "", "topic %s" % target)
	var last := SideQuestPlay.play(st, HUB)
	for target: String in ["view_a", "rudolph", "leg", "vistani"]:
		assert_false(_has_option(last, _option_for("menu", target)), "%s is spent" % target)
	assert_true(_has_option(last, LEDGER), "the ledger stays")
	assert_true(_ended(last))


func test_where_we_are_heading_follows_the_partys_level() -> void:
	var view := _option_for("menu", "view_a")
	for pair: Array in [[6, ""], [7, "butcher's hand"], [8, "butcher's hand"], [9, "Tsolenka Pass"], [10, "Paper plans die"], [11, "Paper plans die"]]:
		var st := _party(int(pair[0]))
		SideQuestPlay.play(st, HUB)
		if pair[1] == "":
			assert_false(_has_option(SideQuestPlay.play(st, HUB), view), "level %d has no view" % int(pair[0]))
			continue
		var beats := SideQuestPlay.play(st, HUB, [view])
		assert_eq(SideQuestPlay.missing(beats), "", "level %d" % int(pair[0]))
		assert_true(_says(beats, str(pair[1])), "level %d: %s" % [int(pair[0]), pair[1]])
		assert_true(_ended(beats))


func test_what_she_says_of_rudolph_and_her_leg_follows_the_story() -> void:
	var rudolph := _option_for("menu", "rudolph")
	var leg := _option_for("menu", "leg")
	var seeking := _party()
	SideQuestPlay.play(seeking, HUB)
	assert_true(_says(SideQuestPlay.play(seeking, HUB, [rudolph]), "keyed to my name alone"), "she does not know where he is")
	var waiting := _party()
	waiting.set_flag("ezmerelda_left_tower")
	SideQuestPlay.play(waiting, HUB)
	assert_true(_says(SideQuestPlay.play(waiting, HUB, [rudolph]), "painted wagon and an inn door"), "she knows and has not knocked")
	var back := _party()
	back.set_flag("ezmerelda_left_tower")
	back.set_flag("ezmerelda_back_at_camp")
	SideQuestPlay.play(back, HUB)
	assert_true(_says(SideQuestPlay.play(back, HUB, [rudolph]), "keyed to my name alone"), "back at camp, she is looking again")
	var reunited := _party()
	reunited.set_flag("van_richten_reunited")
	SideQuestPlay.play(reunited, HUB)
	assert_true(_says(SideQuestPlay.play(reunited, HUB, [rudolph]), "My knuckles still ache"), "after the reunion")
	var alive := _party()
	SideQuestPlay.play(alive, HUB)
	assert_true(_says(SideQuestPlay.play(alive, HUB, [leg]), "A big black wolf named Kiril"), "he is not dead")
	var dead := _party()
	dead.set_flag("kiril_defeated")
	SideQuestPlay.play(dead, HUB)
	assert_true(_says(SideQuestPlay.play(dead, HUB, [leg]), "With the wolf dead"), "he is dead")


# --- The ledger ------------------------------------------------------------------------------------------------------------

func test_with_nothing_killed_she_names_the_local_hunts_first_and_then_the_hardest_the_level_reaches() -> void:
	var st := _party(8, TOWER)
	var offers := _offers(st)
	assert_eq(offers.size(), 3, "three names: %s" % [offers])
	assert_eq(offers.get("khazan", ""), "ask", "the one under the tower she sits beside")
	assert_eq(offers.get("lysaga", ""), "ask", "then the hardest the party reaches (level 8)")
	assert_eq(offers.get("kiril", ""), "ask")
	assert_false(offers.has("sarkhaza") or offers.has("eye"), "the level 9 and 11 hunts wait for their levels")
	var inn := _offers(_party(9, INN))
	assert_true(inn.has("eye") and inn.has("lysaga") and inn.has("khazan") and inn.size() == 3, "where nothing is local, the hardest come first: %s" % [inn])
	assert_false(inn.has("sarkhaza"), "an ancient red waits for level 11")
	var cap := _offers(_party(11, INN))
	assert_true(cap.has("sarkhaza") and cap.has("eye") and cap.has("lysaga") and cap.size() == 3, "the hardest of all first: %s" % [cap])
	var crossroads := _offers(_party(9, "svalich_crossroads"))
	assert_true(crossroads.has("falls") and crossroads.has("wagon") and crossroads.has("huntsman"), "at the crossroads, the crossroads' hunts: %s" % [crossroads])
	var young := _offers(_party(4, "svalich_crossroads"))
	assert_true(young.has("wagon") and young.has("falls"), "a young party there is shown what its level reaches: %s" % [young])
	assert_false(young.has("huntsman"), "but not the Huntsman, which is for level 7")
	assert_eq(_offers(_party(2, INN)).size(), 0, "and a party below every name gets nothing")
	assert_true(_says(SideQuestPlay.play(_party(2, INN), HUB, [LEDGER]), "Nothing in reach"), "she says so")


func test_names_the_party_has_killed_come_first_as_claims_and_never_more_than_three_show() -> void:
	var st := _party(8, TOWER)
	_kill(st, "falls")
	var offers := _offers(st)
	assert_eq(offers.get("falls", ""), "claim", "a recorded kill is a claim")
	assert_eq(offers.size(), 3, "with two hunts beside it")
	for id: String in NAMES:
		_kill(st, id)
	var all := _offers(st)
	assert_eq(all.size(), 3, "all thirteen dead, three at a time: %s" % [all])
	for id: Variant in all:
		assert_eq(all[id], "claim")
	assert_true(_says(SideQuestPlay.play(st, HUB, [LEDGER]), "settle up"), "she can smell the work on them")


func test_a_hunt_that_can_no_longer_be_won_is_never_offered() -> void:
	# Each name is closed where its region is the party's own and its level is reached, so it would otherwise come first.
	var cases := [
		["morgantha", "old_bonegrinder", "bonegrinder_fate", "bargain"],
		["morgantha", "old_bonegrinder", "bonegrinder_fate", "bella"],
		["kiril", "werewolf_den", "wolf_pack_leader", "kiril"],
		["lysaga", "berez", "lysaga_fate", "bargained"],
		["lysaga", "berez", "lysaga_fate", "broken"],
	]
	for c: Array in cases:
		var open := _party(10, str(c[1]))
		assert_true(_offers(open).has(str(c[0])), "%s is offered while it can be won" % c[0])
		var shut := _party(10, str(c[1]))
		shut.set_flag(str(c[2]), str(c[3]))
		assert_false(_offers(shut).has(str(c[0])), "%s is closed once %s is %s" % [c[0], c[2], c[3]])
	var runt := _party(10, "krezk")
	assert_true(_offers(runt).has("grandsire"))
	runt.set_quest_stage("the_packs_runt", "rumored")
	runt.set_quest_stage("the_packs_runt", "given")
	assert_false(_offers(runt).has("grandsire"), "the Grandsire is closed once Petru is given up")
	assert_eq(_offers(runt).size(), 3, "and the ledger still has three others")


func test_a_briefing_is_words_only() -> void:
	var st := _party(9, TOWER)
	var menu := _ledger_menu(st)
	assert_eq(menu.size(), 4, "three names and the way back")
	for t: String in menu.slice(0, 3):
		var beats := SideQuestPlay.play(st, HUB, [LEDGER, t])
		assert_eq(SideQuestPlay.missing(beats), "", t)
		assert_eq(SideQuestPlay.combat_of(beats), "", "no fight starts: %s" % t)
		assert_true(_ended(beats), "and the talk closes")


func test_a_claim_strikes_the_name_once_pays_gold_at_any_level_and_moves_the_quest() -> void:
	for level: int in [6, 9]:
		var st := _party(level, "svalich_crossroads")
		_kill(st, "falls")
		var before := st.gold
		var beats := SideQuestPlay.play(st, HUB, [LEDGER, _option_for("ledger_menu", "claim_falls")])
		assert_eq(SideQuestPlay.missing(beats), "")
		assert_true(bool(st.get_flag("ledger_paid_falls", false)))
		assert_eq(int(st.get_flag("ezmerelda_ledger_paid", 0)), 1)
		assert_eq(st.gold - before, 1000.0, "a thousand gold at level %d, however high the party is" % level)
		for potion: String in ["potion_of_healing", "potion_of_healing_greater", "potion_of_healing_superior", "crossbow_bolt"]:
			assert_eq(_count(st, potion), 0, "no hunter's goods any more: %s" % potion)
		assert_eq(st.quest_stage(QUEST), "paying")
		assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 1, "the first payment warms her")
		assert_true(_ended(beats))
		assert_false(_offers(st).get("falls", "") == "claim", "a name is paid once")
		var again := st.gold
		SideQuestPlay.play(st, HUB, [LEDGER])
		assert_eq(st.gold, again, "and not paid twice")


func test_the_six_easier_names_pay_gold_that_grows_and_the_seven_hardest_pay_one_fresh_magic_item_each() -> void:
	var f := DialogueFile.load_key(FILE)
	var comp := Compendium.shared()
	var order: Array[String] = []
	for id: String in NAMES:
		order.append(id)
	var last_gold := 0
	var kinds := {}
	for id: String in order:
		var min_level := int((NAMES[id] as Array)[2])
		var golds: Array[int] = []
		var gives: Array[Dictionary] = []
		for s: Dictionary in f.nodes["claim_" + id]:
			match str(s["t"]):
				"gold":
					golds.append(int(s["amount"]))
				"give":
					gives.append(s)
		if GOLD.has(id):
			assert_eq(golds, [int(GOLD[id])] as Array[int], "%s pays %d gp" % [id, int(GOLD[id])])
			assert_true(int(GOLD[id]) >= 1000, "%s: significant gold" % id)
			assert_true(int(GOLD[id]) >= last_gold, "%s pays at least what the name before it did" % id)
			last_gold = int(GOLD[id])
			assert_eq(gives.size(), 0, "%s pays in gold alone" % id)
			continue
		assert_true(ITEMS.has(id), "%s has a reward" % id)
		assert_eq(golds.size(), 0, "%s pays in an item, not coin" % id)
		assert_eq(gives.size(), 1, "%s pays one item" % id)
		var item := str(gives[0]["item"])
		assert_eq(item, str(ITEMS[id]))
		assert_eq(int(gives[0]["qty"]), 1)
		var data := comp.item_data(item)
		assert_false(data.is_empty(), "%s is an item" % item)
		assert_eq(str((data.get("source", {}) as Dictionary).get("book", "")), "DMG2024", "%s is a 2024 DMG item" % item)
		var rarity := str((data.get("magic", {}) as Dictionary).get("rarity", "common"))
		assert_true(int(RARITY_FROM.get(rarity, 99)) <= min_level and rarity in ["rare", "very_rare"],
			"%s (%s) is rare enough for %s, named from level %d, and not too rare" % [item, rarity, id, min_level])
		var kind := Treasure.kind_of(item)
		assert_true(kind != "", "%s is a lasting item" % item)
		assert_false(kinds.has(kind), "%s: a second %s among the ledger's payments" % [id, kind])
		kinds[kind] = id
	assert_eq(kinds.size(), 7, "seven items, seven kinds")
	assert_true(not kinds.has(Treasure.kind_of("weapon_plus_1__light_crossbow")) and not kinds.has(Treasure.kind_of("mage_breaker__dagger")),
		"and none of them is the milestone gifts' kind")


func test_each_name_hands_over_its_gold_or_its_item_when_claimed() -> void:
	for id: String in NAMES:
		var st := _party(10, TOWER)
		_kill(st, id)
		var before := st.gold
		var beats := SideQuestPlay.play(st, HUB, [LEDGER, _option_for("ledger_menu", "claim_" + id)])
		assert_eq(SideQuestPlay.missing(beats), "", id)
		assert_true(bool(st.get_flag("ledger_paid_" + id, false)), "%s is paid" % id)
		if GOLD.has(id):
			assert_eq(st.gold - before, float(GOLD[id]), "%s: the gold" % id)
			assert_true(_says(beats, "Gained %d gp" % int(GOLD[id])), "%s: the party is told" % id)
		else:
			assert_eq(st.gold, before, "%s: no coin" % id)
			assert_eq(_count(st, str(ITEMS[id])), 1, "%s: %s" % [id, ITEMS[id]])
			assert_true(_says(beats, " receives "), "%s: the party is told what it received" % id)


func test_the_whole_ledger_can_be_struck_out_and_every_talk_closes() -> void:
	var st := _party(10, TOWER)
	for id: String in NAMES:
		_kill(st, id)
	var order: Array[String] = []
	for round_no in 6:
		var offers := _offers(st)
		if offers.is_empty():
			break
		var picks: Array[String] = [LEDGER]
		for id: Variant in offers:
			picks.append(_option_for("ledger_menu", "claim_" + str(id)))
			order.append(str(id))
		var beats := SideQuestPlay.play(st, HUB, picks)
		assert_eq(SideQuestPlay.missing(beats), "", "round %d" % round_no)
		assert_true(_ended(beats), "round %d closes" % round_no)
		assert_eq(SideQuestPlay.combat_of(beats), "")
	assert_eq(order.size(), 13, "thirteen names, each once: %s" % [order])
	assert_eq(int(st.get_flag("ezmerelda_ledger_paid", 0)), 13)
	assert_eq(st.quest_stage(QUEST), "ledger_struck", "the quest is done")
	assert_true(bool(st.get_flag("ezmerelda_ledger_gift_a", false)) and bool(st.get_flag("ezmerelda_ledger_gift_b", false)))
	assert_eq(_count(st, "weapon_plus_1__light_crossbow"), 1, "the fourth name's crossbow, once")
	assert_eq(_count(st, "mage_breaker__dagger"), 1, "the eighth name's dagger, once")
	assert_eq(int(st.get_flag("ezmerelda_trust", 0)), 1, "only the first payment warms her")
	var after := SideQuestPlay.play(st, HUB)
	assert_false(_has_option(after, LEDGER), "the book is closed")
	assert_true(_ended(after))


func test_the_quest_moves_on_at_seven_names_and_the_gifts_come_at_four_and_eight() -> void:
	var st := _party(10, TOWER)
	var stages: Array[String] = []
	var order := ["falls", "wagon", "fowlers", "vine", "morgantha", "wint", "huntsman", "grandsire", "kiril", "khazan", "lysaga", "sarkhaza", "eye"]
	for i in order.size():
		var id: String = order[i]
		_kill(st, id)
		var beats := SideQuestPlay.play(st, HUB, [LEDGER, _option_for("ledger_menu", "claim_" + id)])
		assert_eq(SideQuestPlay.missing(beats), "", id)
		assert_true(_ended(beats))
		stages.append(st.quest_stage(QUEST))
		if i == 2:
			assert_eq(_count(st, "weapon_plus_1__light_crossbow"), 0, "no gift before the fourth")
		if i == 3:
			assert_eq(_count(st, "weapon_plus_1__light_crossbow"), 1, "the fourth")
			assert_true(_says(beats, "no longer lucky beginners"))
		if i == 6:
			assert_eq(_count(st, "mage_breaker__dagger"), 0, "no dagger before the eighth")
		if i == 7:
			assert_eq(_count(st, "mage_breaker__dagger"), 1, "the eighth")
	assert_eq(stages[0], "paying")
	assert_eq(stages[5], "paying")
	assert_eq(stages[6], "half_struck", "the seventh")
	assert_eq(stages[11], "half_struck")
	assert_eq(stages[12], "ledger_struck", "the thirteenth")


func test_it_reads_the_stories_flags_and_writes_only_its_own() -> void:
	var f := DialogueFile.load_key(FILE)
	var own := {}
	for fl: Variant in (JSON.parse_string(FileAccess.get_file_as_string("res://data/flags/allies_ezmerelda.json")) as Dictionary)["flags"]:
		own[str((fl as Dictionary)["id"])] = true
	var written := {}
	for node: String in f.nodes:
		for s: Dictionary in f.nodes[node]:
			if str(s["t"]) == "set":
				written[str(s["flag"])] = node
	for flag: String in written:
		# ezmerelda_trust is her own counter (the tower and the yard move it too); everything else is registered with the allies.
		assert_true(own.has(flag) or flag == "ezmerelda_trust", "%s is a side flag (set in %s)" % [flag, written[flag]])
	for id: String in NAMES:
		var kill := str((NAMES[id] as Array)[0])
		assert_false(written.has(kill), "the story's %s is only read" % kill)
