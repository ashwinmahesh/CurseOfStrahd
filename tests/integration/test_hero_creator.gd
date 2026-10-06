extends TestCase
## Hero mode of the creation screen (docs/ui/character_creation.md): one custom character who takes a pregen's
## place, with the paper-doll Appearance step.


func _hero_screen(replacing: String = "ilse_varga") -> CreationScreen:
	var cs := CreationScreen.new()
	add_child(cs)
	var others: Array[String] = []
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		if id != replacing:
			others.append(id)
	cs.open_hero(replacing, others)
	return cs


func _fill(b: CharacterBuilder, name: String) -> void:
	b.set_class("fighter")
	b.set_background("soldier")
	b.set_species("human")
	var missing := TestChars.auto_pick(func() -> Array[Choice]: return b.pending_choices(),
		func(key: String, chosen: Array) -> void: b.choose(key, chosen))
	assert_true(missing.is_empty(), str(missing))
	b.set_name(name)


func test_one_custom_hero_comes_out_of_hero_mode() -> void:
	var cs := _hero_screen()
	assert_eq(cs.builders.size(), 1, "one character")
	assert_true(cs.hero_mode, "hero mode")
	var app := cs.b().build["appearance"] as Dictionary
	assert_true(bool(app["custom"]), "the look is the paper doll")
	_fill(cs.b(), "Vasha Dunmere")
	assert_true(cs.b().errors().is_empty(), str(cs.b().errors()))
	cs.confirmed[0] = true
	var made: Array[Character] = []
	cs.finished.connect(func(party: Array[Character]) -> void: made.assign(party))
	cs.call("_finish")
	assert_eq(made.size(), 1, "the hero alone comes back")
	assert_true(HeroLook.is_custom(made[0]), "marked custom")
	assert_eq(str((made[0].build["appearance"] as Dictionary)["art"]), str(app["portrait"]), "art id is the portrait")
	cs.queue_free()


func test_a_class_pick_suits_the_outfit_until_the_player_picks_one() -> void:
	var cs := _hero_screen()
	cs.b().set_class("wizard")
	cs.call("_suit_outfit")
	assert_eq(str((cs.b().build["appearance"] as Dictionary)["outfit"]), "scholar", "a wizard starts in robes")
	cs.set("_outfit_chosen", true)
	cs.b().set_class("fighter")
	cs.call("_suit_outfit")
	assert_eq(str((cs.b().build["appearance"] as Dictionary)["outfit"]), "scholar", "the player's pick stays")
	cs.queue_free()


func test_the_hero_cannot_use_a_companions_name() -> void:
	var cs := _hero_screen("tamsin_tealeaf")
	_fill(cs.b(), "Hedda Ironvow")
	assert_false(cs.b().errors().is_empty(), "a companion's name blocks")
	cs.queue_free()


func test_the_appearance_step_draws_and_sends_picks_back() -> void:
	var cs := _hero_screen()
	cs.step = CharacterBuilder.Step.APPEARANCE
	for t: String in AppearancePanel.TABS:
		cs.set("_appearance_tab", t)
		cs.call("_draw")
	var panel := AppearancePanel.create(HeroLook.default_appearance("female"), "human", "fighter")
	add_child(panel)
	var got: Array[Dictionary] = []
	panel.changed.connect(func(a: Dictionary) -> void: got.append(a))
	panel.call("_pick", "gender", "male")
	assert_eq(got.size(), 1, "a pick is sent back")
	assert_eq(str(got[0]["gender"]), "male")
	assert_eq(str(got[0]["voice"]), "hero_male", "the default voice follows the gender")
	panel.call("_pick", "portrait", "hero_07")
	assert_eq(str(got[1]["art"]), "hero_07", "the portrait is the art id")
	panel.queue_free()
	cs.queue_free()
