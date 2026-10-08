extends TestCase
## Loading cards (Improvement Ideas G5; docs/ui/loading_cards.md, ui/screens/loading_card.gd): every region has an
## establishing picture the game can load (its own or the default), the tips are there and short, a card shows the
## place's name and a tip and closes, and with motion off (tests, captures) no card is shown at all.


func test_every_region_has_a_picture() -> void:
	var regions := {}
	for loc: Variant in (Compendium.shared().tables["locations"] as Dictionary).values():
		regions[str((loc as Dictionary).get("region", ""))] = true
	for region: String in regions:
		var path := LoadingCard.picture_for(region)
		assert_true(ResourceLoader.exists(path) and load(path) is Texture2D, "%s: %s" % [region, path])


func test_the_tips_are_there_and_short() -> void:
	var tips := LoadingCard.tips()
	assert_true(tips.size() >= 10)
	for t: Variant in tips:
		assert_true(str(t).length() <= 140, "short enough for one or two lines: %s" % t)


func test_no_card_with_motion_off() -> void:
	assert_true(LoadingCard.show_for(self, {"name": "Vallaki", "region": "vallaki"}) == null, "tests and captures see the place")


func test_a_card_shows_the_place_and_a_tip_and_closes() -> void:
	var card := LoadingCard.new()
	card.location = {"name": "The Village of Barovia", "region": "village_of_barovia"}
	card.tip = "Q and E turn the camera."
	add_child(card)
	await get_tree().process_frame
	assert_eq((card.find_child("Title", true, false) as Label).text, "The Village of Barovia")
	assert_eq((card.find_child("Tip", true, false) as Label).text, "Q and E turn the camera.")
	var closed := [false]
	card.closed.connect(func() -> void: closed[0] = true)
	card.close()
	assert_true(closed[0], "closed")
	await get_tree().process_frame
	assert_true(not is_instance_valid(card), "and gone")
