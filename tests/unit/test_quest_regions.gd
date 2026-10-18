extends TestCase
## The journal's Other tab by region (Ashwin, 2026-10-18: "sort side quests in the journal by region"; story/quest_regions.gd):
## a heading for each region, in the order the campaign reaches them, the companions' own last, each region's quests open
## ones first and the finished ones after.


## Every quest names a region the journal knows, so none falls under "Elsewhere", and every region has its words.
func test_every_quest_has_a_region_with_a_name() -> void:
	for region: String in QuestRegions.ORDER:
		assert_true(QuestRegions.NAMES.has(region), "%s has a heading" % region)
	for q: Dictionary in Compendium.shared().all("quests"):
		var region := QuestRegions.of(str(q["id"]))
		assert_true(region in QuestRegions.ORDER, "%s: region %s is in the journal's order" % [q["id"], region])


## Known regions sort by the campaign's order, unknown ones after them by id, a quest with no region last; within a region
## the order they came in stays.
func test_regions_sort_in_the_campaigns_order() -> void:
	var quests: Array[Dictionary] = []
	for pair: Array in [["a", "companions"], ["b", "vallaki"], ["c", "zzz_unknown"], ["d", "into_the_mists"], ["e", "vallaki"],
			["f", QuestRegions.NONE], ["g", "aaa_unknown"], ["h", "castle_ravenloft"]]:
		quests.append({"id": pair[0], "region": pair[1]})
	var order := JournalScreen.by_region(quests).map(func(q: Dictionary) -> String: return str(q["id"]))
	assert_eq(order, ["d", "b", "e", "h", "a", "g", "c", "f"], "the mists, Vallaki (b before e), the castle, the companions, then the rest")
	assert_eq(QuestRegions.title("zzz_unknown"), "Zzz Unknown", "an unknown region in words")
	assert_eq(QuestRegions.title(QuestRegions.NONE), "Elsewhere")


func test_the_other_tab_has_a_heading_for_each_region() -> void:
	var st := StoryState.new()
	for id: String in ["the_ladle", "toymakers_masterpiece", "the_priests_son", "the_witch_of_berez", "the_grey_mare",
			"the_amber_debt", "the_oat_thief", "last_muster"]:
		_take(st, id, id == "the_priests_son")
		st.advance_minutes(10)
	var j := _journal(st)
	assert_eq(j.quest_tab, "Other", "with no main quest the journal opens on Other")
	var seen := _list(j)
	assert_eq(seen, ["Region_into_the_mists", "Quest_last_muster", "Region_village_of_barovia", "Quest_the_oat_thief",
		"Quest_the_priests_son", "Region_svalich_road", "Quest_the_grey_mare", "Region_vallaki", "Quest_toymakers_masterpiece",
		"Region_berez", "Quest_the_witch_of_berez", "Region_amber_temple", "Quest_the_amber_debt", "Region_companions",
		"Quest_the_ladle"], "regions in the campaign's order; the village's open quest before its finished one")
	assert_eq(j.picked, "last_muster", "the first open quest is picked")
	var heading := j.find_child("Region_village_of_barovia", true, false)
	assert_true(heading != null and _words(heading).contains("The Village of Barovia  2"), "the heading names the region and counts")
	j.free()


## The search sees a region's name; Main has no region headings.
func test_search_by_region_and_main_has_no_headings() -> void:
	var st := StoryState.new()
	_take(st, "toymakers_masterpiece", false)
	_take(st, "the_oat_thief", false)
	_take(st, "escort_ireena", false)
	var j := _journal(st)
	assert_eq(j.quest_tab, "Main")
	assert_eq(_list(j), ["Quest_escort_ireena"], "Main is not filed by region")
	j.pad_trigger(1)
	var box := j.find_child("QuestSearch", true, false) as LineEdit
	box.text = "vallaki"
	box.text_changed.emit(box.text)
	assert_eq(_list(j), ["Region_vallaki", "Quest_toymakers_masterpiece"], "Vallaki finds its quest and only it")
	j.free()


## Starts a quest at its first stage, or ends it at its first ending.
func _take(st: StoryState, id: String, finished: bool) -> void:
	var stages := Compendium.shared().get_entry("quests", id)["stages"] as Array
	var stage := stages[0] as Dictionary
	if finished:
		for s: Variant in stages:
			if str((s as Dictionary).get("ends", "")) != "":
				stage = s as Dictionary
				break
	st.set_quest_stage(id, str(stage["id"]))


func _journal(st: StoryState) -> JournalScreen:
	var j := JournalScreen.new()
	add_child(j)
	j.open(self, st, 0)
	return j


## The names of the region headings and quest rows in the list, top to bottom.
func _list(j: JournalScreen) -> Array[String]:
	var out: Array[String] = []
	_collect(j.find_child("QuestList", true, false), out)
	return out


func _collect(n: Node, out: Array[String]) -> void:
	for c in n.get_children():
		var nm := str(c.name)
		if nm.begins_with("Region_") or nm.begins_with("Quest_"):
			out.append(nm)
		_collect(c, out)


func _words(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + " "
	for c in n.get_children():
		out += _words(c)
	return out
