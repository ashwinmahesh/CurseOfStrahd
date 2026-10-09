extends TestCase
## Loading cards (Improvement Ideas G5; docs/ui/loading_cards.md, ui/screens/loading_card.gd): every region has an
## establishing picture the game can load (its own or the default), the tips are there and short, a card shows the
## place's name and a tip and closes, and with motion off (tests, captures) no card is shown at all. The loading lane:
## a change of place happens behind a cover (black, or the card when it's slow or reaches a new region) that is up
## before the place is built and always lifts, Escape included; the sheets the place shows are read on threads first.


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


# --- The cover over a change of place (the loading lane) ---------------------------------------------
# These turn the interface's motion on (UiMotion), as in play, and put it back off afterwards.

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
		await get_tree().process_frame
	UiMotion._checked = true
	UiMotion.reduced = true


## A game at `where` with motion on, once its own first place is up.
func _game(where: String) -> Node:
	UiMotion._checked = true
	UiMotion.reduced = false
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = where
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _until_moved()
	_close_popups()
	return root


## A first visit's cutscene or greeting would hold the game paused: closed.
func _close_popups() -> void:
	root.call("close_screen")
	var d := root.get("dialogue") as Node
	if d != null:
		d.queue_free()
		root.set("dialogue", null)
		ModeController.force(ModeController.Mode.EXPLORATION)


## Frames until the change of place under way is done (at most a few seconds' worth).
func _until_moved() -> void:
	for i in 600:
		await get_tree().process_frame
		if not bool(root.get("moving")) and root.get("view") != null:
			return
	fail("the change of place never finished")


func _cards() -> Array[LoadingCard]:
	var out: Array[LoadingCard] = []
	for c in root.get_children():
		if c is LoadingCard and not (c as LoadingCard)._closing:
			out.append(c as LoadingCard)
	return out


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func test_the_first_place_comes_up_behind_its_card() -> void:
	await _game("village_of_barovia")
	assert_eq(str((root.get("view") as LocationView).loc_id), "village_of_barovia")
	assert_eq(root.find_children("*", "LoadingCard", false, false).size(), 1, "a new game's first place: its region's card")


func test_a_move_puts_the_cover_up_before_the_place_is_built() -> void:
	await _game("village_of_barovia")
	var old := root.get("view") as LocationView
	var fade := root.get("_place_fade") as ColorRect
	root.call("_covered", "bildraths_mercantile", Callable(root, "enter_location").bind("bildraths_mercantile", "default"))
	assert_true(bool(root.get("moving")), "under way")
	assert_true(root.get("view") == old, "nothing built yet: the old place is still there")
	assert_eq(old.process_mode, Node.PROCESS_MODE_DISABLED, "and stands still")
	assert_eq(fade.color.a, 1.0, "under black at once")
	assert_eq(fade.mouse_filter, Control.MOUSE_FILTER_STOP, "the black takes the clicks")
	await _until_moved()
	_close_popups()
	assert_eq(str((root.get("view") as LocationView).loc_id), "bildraths_mercantile", "then the new place")
	assert_eq(fade.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	await get_tree().create_timer(0.3).timeout
	assert_true(fade.color.a < 1.0, "and the black fades (%s)" % fade.color.a)


func test_a_quick_move_shows_black_and_a_slow_one_the_card() -> void:
	await _game("village_of_barovia")
	for c in _cards():
		c.close()
	var took := root.get_script().get("took_ms") as Dictionary
	took["bildraths_mercantile"] = 120.0
	root.call("_covered", "bildraths_mercantile", Callable(root, "enter_location").bind("bildraths_mercantile", "default"))
	assert_eq(_cards().size(), 0, "a quick move in the same region: black, no card")
	await _until_moved()
	took["village_of_barovia"] = 1400.0
	root.call("_covered", "village_of_barovia", Callable(root, "enter_location").bind("village_of_barovia", "default"))
	assert_eq(_cards().size(), 1, "a slow one: the card")
	assert_true(_cards()[0].covering, "covering the build")
	await _until_moved()


## Escape while the card covers a build changes nothing under it (no menu opens) and the card stays; once the place is
## ready, a key sends it away.
func test_escape_during_the_card_is_swallowed_and_the_card_still_lifts() -> void:
	await _game("village_of_barovia")
	for c in _cards():
		c.close()
	root.call("_covered", "vallaki", Callable(root, "enter_location").bind("vallaki", "default"))
	var card := _cards()[0]
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_false(card._closing, "the card stays while the place is built")
	assert_false(root.get("screen") is PauseMenu, "and no menu opened under it")
	await _until_moved()
	assert_true(card._lifted, "the place is ready: the card is lifted")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_true(card._closing, "a key now sends it away")
	assert_false(root.get("screen") is PauseMenu, "still no menu")


## A first visit's arrival picture pauses the game as it opens under the cover: the card makes way for it at once and
## the black lifts over it, paused or not (Ashwin's first walk into the village showed a black screen until a click).
func test_an_arrival_picture_takes_over_from_the_cover() -> void:
	await _game("bildraths_mercantile")
	for c in _cards():
		c.close()
	(root.get_script().get("took_ms") as Dictionary)["village_of_barovia"] = 1400.0   # slow enough for the card
	root.call("_covered", "village_of_barovia", Callable(root, "enter_location").bind("village_of_barovia", "default"))
	var card := _cards()[0]
	await _until_moved()
	assert_true(root.get("screen") is CutscenePlayer, "the village's picture opened on arrival")
	assert_true(get_tree().paused, "and paused the game")
	await get_tree().create_timer(LoadingCard.FADE_SECONDS + 0.2).timeout   # a timer that runs while paused
	assert_true(get_tree().paused, "the picture is still up")
	assert_false(is_instance_valid(card) and not card._closing, "the card made way for it")
	assert_true((root.get("_place_fade") as ColorRect).color.a < 0.05, "and the black is gone from over it (%s)" % (root.get("_place_fade") as ColorRect).color.a)
	_close_popups()


## A change that goes nowhere (a load that fails) still lifts the cover, and the old place carries on.
func test_a_change_that_goes_nowhere_still_lifts_the_cover() -> void:
	await _game("village_of_barovia")
	for c in _cards():
		c.close()
	var old := root.get("view") as LocationView
	root.call("_covered", "vallaki", func() -> void: pass)
	var card := _cards()[0]
	await _until_moved()
	assert_true(root.get("view") == old, "still here")
	assert_eq(old.process_mode, Node.PROCESS_MODE_INHERIT, "and moving again")
	assert_true(card._lifted, "the card lifts")
	assert_eq((root.get("_place_fade") as ColorRect).mouse_filter, Control.MOUSE_FILTER_IGNORE, "the black lets go")


func test_a_covering_card_waits_for_lift_then_its_hold() -> void:
	UiMotion._checked = true
	UiMotion.reduced = false
	var card := LoadingCard.cover(self, {"name": "Vallaki", "region": "vallaki"}, 0.0)
	await get_tree().process_frame
	_key(KEY_SPACE)
	await get_tree().process_frame
	assert_false(card._closing, "a key doesn't send it away while it covers a build")
	card.lift()
	assert_true(card._closing, "lifted with no hold left: it goes")
	await get_tree().create_timer(LoadingCard.FADE_SECONDS + 0.1).timeout
	assert_false(is_instance_valid(card), "and is gone")


## The sheets a place will show load on worker threads first (PlacePreload): the party's and its people's. Headless
## runs read nothing ahead (the stand-in renderer), so this checks which sheets, and that a start, wait and release
## leave no load uncollected.
func test_the_preload_reads_the_party_and_the_people() -> void:
	GameState.reset()
	var ch := Pregens.build("ilse_varga", 1)
	GameState.story.party.append(ch)
	var loc := Compendium.shared().get_entry("locations", "vallaki")
	var ids := PlacePreload.art_ids(loc, GameState.story)
	assert_true(CombatToken.art_for(ch) in ids, "the party (%s)" % [ids])
	assert_true(ids.size() >= 5, "and Vallaki's people (%s)" % [ids])
	var pre := PlacePreload.start(loc, GameState.story)
	var asked := pre.paths.duplicate()
	await pre.wait(self)
	pre.release()
	for path: String in asked:
		assert_eq(ResourceLoader.load_threaded_get_status(path), ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "%s collected" % path)


## A place's fights still to come have their foes read ahead while the party is there (PlacePreload.foe_art_ids, after
## Functional QA's hitch tour): the vineyard's blights while its ambush hasn't begun, and only the Vine Mother's once
## it has.
func test_the_foes_still_to_fight_here_are_read_ahead() -> void:
	GameState.reset()
	var st := GameState.story
	var loc := Compendium.shared().get_entry("locations", "wizard_of_wines")
	var art := func(m: String) -> String: return CombatToken.monster_art(Compendium.shared().monster_data(m))
	var arts := PlacePreload.foe_art_ids("wizard_of_wines", loc, st)
	for m: String in ["vine_blight", "needle_blight", "twig_blight", "vine_mother"]:
		assert_true(str(art.call(m)) in arts, "%s is read ahead (%s)" % [m, arts])
	(st.loc_state("wizard_of_wines")["encounters"] as Dictionary)["vineyard_ambush"] = "started"
	arts = PlacePreload.foe_art_ids("wizard_of_wines", loc, st)
	assert_false(str(art.call("twig_blight")) in arts, "the ambush has begun: its twig blights aren't (%s)" % [arts])
	assert_true(str(art.call("vine_mother")) in arts, "the Vine Mother's fight is still to come")


## Which fights still to come are read ahead (PlacePreload.could_happen): one that waits for night or a flag can come
## true while the party is here, so it's read; an entry for another party level, or a final battle the cards put in
## another room, can't, so it isn't.
func test_fights_that_could_still_happen_this_visit_are_read_ahead() -> void:
	GameState.reset()
	var st := GameState.story
	var ch := Pregens.build("ilse_varga", 1)
	st.party.append(ch)
	st.minute_of_day = 12 * 60
	assert_true(PlacePreload.could_happen({"when": "night and flag.ismark_met"}, st), "night and a flag may still come")
	assert_true(PlacePreload.could_happen({"when": ""}, st), "no condition")
	assert_false(PlacePreload.could_happen({"when": "night and level >= 7"}, st), "a level-1 party won't be level 7 here")
	assert_true(PlacePreload.could_happen({"when": "not flag.cleared and level >= 1"}, st), "its level test holds")
	assert_false(PlacePreload.could_happen({"final_battle": "castle_ravenloft_court_study"}, st), "no reading put him there")


## The interface's first-time reads happen once, under the first loading cover (FN-23): the icons read for Icons'
## cache, the figures' font and the glossary, so the first inventory and the first fight's hotbar don't read them.
func test_the_interface_warms_once_under_the_first_cover() -> void:
	var was := PlacePreload._ui_warm
	PlacePreload._ui_warm = false
	var p := PlacePreload.new()
	p._icons = [["features", "dash"]] as Array[Array]
	p._warm_ui()
	assert_true(PlacePreload._ui_warm, "done for the session")
	assert_true(Icons._cache.has(Icons.DIR + "features/dash.png"), "the Dash tile is in Icons' cache")
	assert_true(UiParts._figure_font != null, "the figures' font is read")
	PlacePreload._ui_warm = was
