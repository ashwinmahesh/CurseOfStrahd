extends TestCase
## Sneaking over a visit (docs/rules/stealth.md, docs/design/overworld_stealth.md "Fixes that come with any option"): the
## Stealth roll is made once and kept while the party stops and starts sneaking, until it leaves the place or an hour of
## the clock has passed; a party that walks out through an exit sneaking arrives sneaking, with fresh rolls; the totals
## show on the portraits in the sight overlay's colours; and Wait and the Short Rest ask who can see the party now, not
## who it has ever seen.

## Two rooms joined by a gap at (7, 5): the west room sees the wolf in the east one only along row 5.
const MAP := {"rows": [
		"################",
		"#......#.......#",
		"#......#.......#",
		"#......#.......#",
		"#......#.......#",
		"#..............#",
		"################"], "light": "bright"}
const HALL := {
	"id": "test_stealth_hall", "name": "Stealth Hall", "region": "test", "summary": "A fixture.",
	"map": MAP,
	"areas": [{"id": "far_end", "name": "Far end", "cells": [[9, 1], [14, 5]]}],
	"spawns": {"default": [3, 5]},
	"exits": [{"id": "to_next", "cell": [1, 5], "to": "test_stealth_next", "spawn": "default", "label": "West door"}],
	"encounters": [{"id": "far_wolf", "trigger": "enter_area:far_end", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [12, 5], "facing": "west"}], "flag": "test_far_wolf_dead"}]
}
const NEXT := {
	"id": "test_stealth_next", "name": "Next Room", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"########"], "light": "bright"},
	"spawns": {"default": [3, 2]},
}
## The party arrives inside the fight's area.
const PIT := {
	"id": "test_stealth_pit", "name": "Stealth Pit", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "bright"},
	"areas": [{"id": "whole", "name": "Whole room", "cells": [[1, 1], [8, 3]]}],
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "pit_wolf", "trigger": "enter_area:whole", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [7, 2], "facing": "west"}], "flag": "test_pit_wolf_dead"}]
}
## A fight that waits only by night.
const NIGHT_HALL := {
	"id": "test_stealth_night", "name": "Night Hall", "region": "test", "summary": "A fixture.",
	"map": MAP,
	"areas": [{"id": "far_end", "name": "Far end", "cells": [[9, 1], [14, 5]]}],
	"spawns": {"default": [3, 5]},
	"encounters": [{"id": "night_wolf", "trigger": "enter_area:far_end", "waiting": true, "when": "night",
		"monsters": [{"monster": "wolf", "cell": [12, 5], "facing": "west"}], "flag": "test_night_wolf_dead"}]
}

var root: Node
var _rolls := 0   ## Stealth rolls made since _count_rolls


func before_each() -> void:
	for l: Dictionary in [HALL, NEXT, PIT, NIGHT_HALL]:
		Compendium.shared().tables["locations"][str(l["id"])] = l.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_stealth_hall"
	Dice.reseed(4)


func after_each() -> void:
	GameSettings.set_turn_based(false)
	for id: String in ["test_stealth_hall", "test_stealth_next", "test_stealth_pit", "test_stealth_night"]:
		Compendium.shared().tables["locations"].erase(id)
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _start() -> void:
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _hud() -> ExploreHud:
	return root.get("hud") as ExploreHud


func _wolf() -> Combatant:
	return _view().waiting[0]["foe"] as Combatant


## Counts the Stealth rolls the view announces from now on.
func _count_rolls() -> void:
	_rolls = 0
	_view().check_rolled.connect(func(_t: String) -> void: _rolls += 1)


## The party's totals, in party order.
func _totals() -> Array[int]:
	var out: Array[int] = []
	for m: Combatant in _view().members:
		out.append(int(_view().sneak_totals.get(m.creature, -99)))
	return out


## Everyone where the wolf can't be seen from (the west room, off row 5), or within 30 ft of it in its plain view.
func _hide_from_wolf() -> void:
	_view().members[0].cell = Vector2i(2, 1)
	_view().members[1].cell = Vector2i(3, 1)


func _in_view_of_wolf() -> void:
	_view().members[0].cell = Vector2i(8, 5)
	_view().members[1].cell = Vector2i(7, 5)


func _badges() -> Array[Node]:
	return _hud().find_children("StealthBadge", "PanelContainer", true, false)


func _badge_text(b: Node) -> String:
	return (b.get_child(0) as Label).text


# --- One roll a visit -------------------------------------------------------------------------------

func test_the_roll_is_kept_when_the_party_stops_and_starts_sneaking() -> void:
	await _start()
	var v := _view()
	_count_rolls()
	v.set_sneaking(true)
	assert_eq(_rolls, 2, "each of the two rolls Stealth as the party starts")
	var first := _totals()
	v.set_sneaking(false)
	v.set_sneaking(true)
	assert_eq(_rolls, 2, "stopping and starting again rolls nothing")
	assert_eq(_totals(), first, "the totals are the same ones: no free reroll")
	v.set_sneaking(false)
	for i in 5:
		v.set_sneaking(true)
		v.set_sneaking(false)
	assert_eq(_rolls, 2, "however often it is done")


func test_the_roll_stands_for_an_hour_of_the_clock_and_is_rolled_again_after() -> void:
	await _start()
	var v := _view()
	var st := GameState.story
	_count_rolls()
	v.set_sneaking(true)
	v.set_sneaking(false)
	st.advance_minutes(LocationStealth.ROLL_MINUTES - 1)
	v.set_sneaking(true)
	assert_eq(_rolls, 2, "59 minutes on, the roll still stands")
	v.set_sneaking(false)
	st.advance_minutes(1)
	v.set_sneaking(true)
	assert_eq(_rolls, 4, "an hour on, both roll again")
	assert_eq(int(v.sneak_rolled[v.members[0].creature]), st.total_minutes(), "stamped with the clock")
	# An hour passing while the party goes on sneaking (a Short Rest, a Wait) ends the roll too: the next look rolls.
	st.advance_minutes(LocationStealth.ROLL_MINUTES)
	LocationStealth.total_for(v, v.members[0].creature)
	assert_eq(_rolls, 5, "asked for after an hour of sneaking, one rolls again")


func test_a_member_without_a_total_rolls_when_asked() -> void:
	await _start()
	var v := _view()
	v.set_sneaking(true)
	_count_rolls()
	var cr := v.members[1].creature
	v.sneak_totals.erase(cr)
	var t := LocationStealth.total_for(v, cr)
	assert_eq(_rolls, 1, "a guest who just joined has no total: rolled on demand")
	assert_eq(LocationStealth.total_for(v, cr), t, "and kept")
	assert_eq(_rolls, 1)


func test_totals_set_without_a_time_stand() -> void:
	await _start()
	var v := _view()
	v.set_sneaking(true)
	_count_rolls()
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = 3
		v.sneak_rolled.erase(m.creature)
	GameState.story.advance_minutes(600)
	assert_eq(LocationStealth.total_for(v, v.members[0].creature), 3, "a total a test sets is the party's")
	assert_eq(_rolls, 0)


# --- Sneaking carries through exits ---------------------------------------------------------------------

## The leader steps onto the hall's west door (1, 5).
func _walk_out() -> void:
	var v := _view()
	v.leader().cell = Vector2i(2, 5)
	LocationWalk.step(v, Vector2i.LEFT)
	LocationWalk.tick(v, 1.0)
	await _frames(4)


func test_sneaking_carries_through_an_exit_with_fresh_rolls() -> void:
	await _start()
	var before := _view()
	before.set_sneaking(true)
	await _walk_out()
	var v := _view()
	assert_ne(v, before, "the party is in another place")
	assert_eq(v.loc_id, "test_stealth_next")
	assert_true(v.sneaking, "and still sneaking")
	assert_eq(_totals().size(), 2, "with totals of their own")
	for m: Combatant in v.members:
		assert_true(v.sneak_totals.has(m.creature) and v.sneak_rolled.has(m.creature), "%s rolled in this place" % m.name())
	assert_eq(v.sneak_totals.size(), 2, "one each")
	await _frames(2)
	assert_true((v.tokens[v.members[0].id] as CombatToken).sneaking, "crouched")
	for b in _badges():
		assert_true((b as Control).visible, "and the portraits wear their new totals")


func test_a_party_that_walks_out_openly_arrives_openly() -> void:
	await _start()
	await _walk_out()
	assert_eq(_view().loc_id, "test_stealth_next")
	assert_false(_view().sneaking, "walking normally")


func test_other_ways_in_start_walking_normally() -> void:
	await _start()
	_view().set_sneaking(true)
	root.call("enter_location", "test_stealth_next", "default")
	await _frames(3)
	assert_false(_view().sneaking, "a plain arrival (the travel map, a cutscene, a load) isn't sneaking")
	root.call("enter_location", "test_stealth_hall", "")
	await _frames(3)
	assert_false(_view().sneaking, "nor is rebuilding a place")


## The wolf's passive Perception (the fight's foes are gone from the view once it starts).
func _wolf_passive() -> int:
	return Monster.from_data(Compendium.shared().monster_data("wolf")).passive_score(&"perception").total()


func test_a_fight_area_the_party_arrives_in_starts_its_fight_when_they_arrive_openly() -> void:
	await _start()
	root.call("enter_location", "test_stealth_pit", "default", false)
	await _frames(4)
	var v := _view()
	assert_true(v.in_combat, "the wolf's area is stepped into on arriving: the fight starts")
	assert_false(v.sneaking, "begun by a party that wasn't sneaking")
	for c in v.combat_view.e.combatants:
		if c.side == &"enemy":
			assert_false(c.surprised, "so nobody is surprised")


## Sneaking carried through an exit is sneaking when the place looks at its areas (docs/rules/stealth.md, "Slipping past"):
## the fight starts only if the wolf notices one of them, and then it surprises no one.
func test_a_fight_area_the_party_arrives_in_sneaking_starts_its_fight_only_if_the_wolf_notices() -> void:
	await _start()
	root.call("enter_location", "test_stealth_pit", "default", true)
	await _frames(4)
	var v := _view()
	assert_true(v.sneaking, "arrived sneaking")
	var worst := 1 << 20
	for m: Combatant in v.members:
		worst = mini(worst, int(v.sneak_totals[m.creature]))
	var noticed := worst <= _wolf_passive()   # 25 ft ahead of it, in bright light
	assert_eq(v.in_combat, noticed, "the fight starts iff a Stealth total (%d) doesn't beat the wolf's %d" % [worst, _wolf_passive()])
	if v.in_combat:
		for c in v.combat_view.e.combatants:
			if c.side == &"enemy":
				assert_false(c.surprised, "a fight a foe starts surprises no one")
	else:
		assert_true(v._slipping.has("pit_wolf"), "unnoticed, they have slipped into its area")


# --- The totals on the portraits ---------------------------------------------------------------------

func test_the_portraits_wear_the_totals_in_the_sight_overlays_colours() -> void:
	await _start()
	var v := _view()
	await _frames(2)
	assert_true(LocationStealth.is_shown(v.waiting[0]), "the wolf is in plain view down row 5")
	for b in _badges():
		assert_false((b as Control).visible, "walking openly: no totals")
	var pp := LocationStealth.passive_score(_wolf())
	v.set_sneaking(true)
	v.sneak_totals[v.members[0].creature] = pp - 5
	v.sneak_totals[v.members[1].creature] = pp + 1
	await _frames(2)
	var badges := _badges()
	assert_eq(badges.size(), 2, "one for each portrait")
	assert_true((badges[0] as Control).visible and (badges[1] as Control).visible, "sneaking: shown")
	assert_eq(_badge_text(badges[0]), str(pp - 5))
	assert_eq(_badge_text(badges[1]), str(pp + 1))
	assert_eq(badges[0].get_meta(&"mood"), "notices", "even in dim light the wolf would notice the first: red")
	assert_eq(badges[1].get_meta(&"mood"), "beaten", "it can't notice the second: the plain colour")
	assert_eq((badges[0].get_child(0) as Label).get_theme_color("font_color"), Look.color("vampire_red"))
	assert_eq((badges[1].get_child(0) as Label).get_theme_color("font_color"), Look.color("vellum"))
	assert_eq((badges[0] as Control).tooltip_text, "Stealth %d: the Wolf would notice them in any light" % (pp - 5))
	assert_eq((badges[1] as Control).tooltip_text, "Stealth %d: no foe in view would notice them" % (pp + 1))
	v.sneak_totals[v.members[1].creature] = pp
	await _frames(2)
	badges = _badges()
	assert_eq(badges[1].get_meta(&"mood"), "bright", "level with its Perception: only bright light gives them away: amber")
	assert_eq((badges[1].get_child(0) as Label).get_theme_color("font_color"), Look.color("candle"))
	assert_eq((badges[1] as Control).tooltip_text, "Stealth %d: the Wolf would notice them in bright light" % pp)
	v.set_sneaking(false)
	await _frames(2)
	for b in _badges():
		assert_false((b as Control).visible, "gone when the party stops sneaking")


func test_a_foe_that_is_asleep_or_not_in_view_changes_no_colour() -> void:
	await _start()
	var v := _view()
	var pp := LocationStealth.passive_score(_wolf())
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp - 5
	await _frames(2)
	assert_eq(_badges()[0].get_meta(&"mood"), "notices")
	((v.loc["encounters"] as Array)[0] as Dictionary)["surprise"] = "enemies"   # asleep: it notices nobody
	v.sneak_totals[v.members[0].creature] = pp - 4   # a change the badges notice
	await _frames(2)
	assert_eq(_badges()[0].get_meta(&"mood"), "beaten", "a sleeper doesn't count")
	((v.loc["encounters"] as Array)[0] as Dictionary).erase("surprise")
	v.waiting[0]["token"].queue_free()
	v.waiting[0]["token"] = null   # not in view now
	v.sneak_totals[v.members[0].creature] = pp - 5
	await _frames(2)
	assert_eq(_badges()[0].get_meta(&"mood"), "beaten", "nor does a foe the party can't see")


func test_a_member_who_is_down_wears_no_total() -> void:
	await _start()
	var v := _view()
	v.set_sneaking(true)
	await _frames(2)
	assert_true((_badges()[1] as Control).visible)
	v.members[1].creature.hp = 0
	await _frames(2)
	assert_false((_badges()[1] as Control).visible, "down: they can't be noticed sneaking")
	assert_true((_badges()[0] as Control).visible)


func test_a_click_on_the_badge_still_leads() -> void:
	await _start()
	var v := _view()
	v.set_sneaking(true)
	await _frames(2)
	var led: Array[int] = []
	_hud().leader_picked.connect(func(i: int) -> void: led.append(i))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	(_badges()[1] as Control).gui_input.emit(ev)
	assert_eq(led, [1] as Array[int], "the corner of the portrait is the card's")


# --- Wait and the Short Rest ----------------------------------------------------------------------------

func test_wait_asks_who_can_see_the_party_now() -> void:
	await _start()
	var v := _view()
	var st := GameState.story
	await _frames(2)
	assert_true(LocationStealth.is_shown(v.waiting[0]), "the wolf has been seen")
	_in_view_of_wolf()
	assert_eq(LocationStealth.foes_in_sight(v), ["Wolf"] as Array[String], "in plain view of it")
	assert_true(WaitScreen.why_not(root, st).begins_with("Not with foes in sight"), "so no waiting")
	_hide_from_wolf()
	assert_eq(LocationStealth.nearest_waiting(v), "far_wolf", "it keeps its figure once seen")
	assert_eq(LocationStealth.foes_in_sight(v), [] as Array[String], "but nobody sees it now")
	assert_eq(WaitScreen.why_not(root, st), "", "so the party can wait out of its sight")
	assert_eq(RestRules.short_rest_refusals(st, LocationStealth.foes_in_sight(v)), [] as Array[String], "and rest")
	_in_view_of_wolf()
	assert_false(WaitScreen.why_not(root, st).is_empty(), "back in its view, it can't again")


func test_a_sneaking_party_the_foes_would_not_notice_may_wait_and_rest() -> void:
	await _start()
	var v := _view()
	var st := GameState.story
	await _frames(2)
	_in_view_of_wolf()
	var pp := LocationStealth.passive_score(_wolf())
	v.set_sneaking(true)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp - 5
	assert_eq(LocationStealth.foes_in_sight(v), ["Wolf"] as Array[String], "it would notice them")
	assert_false(WaitScreen.why_not(root, st).is_empty())
	assert_false(RestRules.short_rest_refusals(st, LocationStealth.foes_in_sight(v)).is_empty(), "nor a Short Rest")
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp + 1
	assert_eq(LocationStealth.foes_in_sight(v), [] as Array[String], "beaten, it notices none of them")
	assert_eq(WaitScreen.why_not(root, st), "", "so Wait is allowed, sneaking")
	assert_eq(RestRules.short_rest_refusals(st, LocationStealth.foes_in_sight(v)), [] as Array[String], "and the Short Rest")
	v.members[1].creature.hp = 0
	v.sneak_totals[v.members[0].creature] = pp - 5
	assert_false(WaitScreen.why_not(root, st).is_empty(), "one of them is enough to be noticed")
	v.sneaking = false   # (set_sneaking(false) would have the wolf notice them at once and start the fight)
	assert_false(WaitScreen.why_not(root, st).is_empty(), "walking openly in its view, the totals count for nothing")


func test_the_rest_screen_follows_the_same_rule() -> void:
	await _start()
	var v := _view()
	await _frames(2)
	_in_view_of_wolf()
	root.call("open_screen", "rest", 0)
	await _frames(2)
	var short := _short_rest_button()
	assert_true(short != null and short.disabled, "in the wolf's view: no Short Rest")
	root.call("close_screen")
	_hide_from_wolf()
	root.call("open_screen", "rest", 0)
	await _frames(2)
	short = _short_rest_button()
	assert_true(short != null and not short.disabled, "out of its view: one can be taken")
	root.call("close_screen")
	assert_true(v.waiting.size() == 1)


func _short_rest_button() -> Button:
	for b: Node in (root.get("screen") as Node).find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Finish the Short Rest"):
			return b as Button
	return null


# --- Waiting through dawn ---------------------------------------------------------------------------

func test_waiting_through_dawn_sends_a_night_fights_foes_away() -> void:
	GameState.story.location = "test_stealth_night"
	GameState.story.minute_of_day = 22 * 60
	await _start()
	var v := _view()
	var st := GameState.story
	await _frames(2)
	assert_eq(v.waiting.size(), 1, "the wolf waits by night")
	assert_true(LocationStealth.is_shown(v.waiting[0]), "in plain view")
	var figure := v.waiting[0]["token"] as Node
	_in_view_of_wolf()
	assert_false(WaitScreen.why_not(root, st).is_empty(), "the party can't wait in its view")
	_hide_from_wolf()
	assert_eq(WaitScreen.why_not(root, st), "", "but lies low out of it")
	root.call("open_screen", "wait", 0)
	await _frames(1)
	var w := root.get("screen") as WaitScreen
	w.set_hours(9)   # 22:00 to 07:00
	w.wait()
	assert_false(st.is_night(), "it is day")
	assert_true(v.waiting.is_empty(), "the wolf went with the night")
	await _frames(2)
	assert_false(is_instance_valid(figure) and not figure.is_queued_for_deletion(), "and so did its figure")
	# The fight is not won, only not on at this hour: the next night it is back.
	st.advance_minutes(15 * 60)
	LocationStealth.refresh_waiting(v)
	assert_eq(v.waiting.size(), 1, "back at the next dusk")


func test_night_streets_dead_stops_holding_at_dawn() -> void:
	var st := GameState.story
	var village := Compendium.shared().get_entry("locations", "village_of_barovia")
	var spec := {}
	for en: Variant in village["encounters"]:
		if str((en as Dictionary)["id"]) == "night_streets_dead":
			spec = en as Dictionary
	assert_true(bool(spec.get("waiting", false)), "a waiting fight")
	var when := StoryConditions.encounter_when(spec, str(village.get("region", "")))
	st.flags["ismark_met"] = true
	st.minute_of_day = 23 * 60
	assert_true(StoryConditions.check(when, st), "foes stand in the square at night")
	st.advance_minutes(8 * 60)
	assert_false(StoryConditions.check(when, st), "and are gone by day: refresh_waiting drops them")
