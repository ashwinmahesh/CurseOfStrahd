extends TestCase
## Slipping past a waiting fight (docs/rules/stealth.md, docs/design/overworld_stealth.md Option A): a sneaking party that
## steps into the area of a fight waiting in plain view starts nothing unless a foe notices it; stopping to sneak inside
## the area, or stepping in without sneaking, starts it; leaving the area again unnoticed is slipping past it (a toast,
## XP in Experience mode once, the fight left to be fought); a container in the area is guarded by the same notice rule;
## a sleeper notices nobody; a fight of unseen foes only starts on the step as ever; and the hover hint warns a party that
## isn't sneaking. The arrival of a party that comes through an exit sneaking goes through the same rule.

const HALL := {
	"id": "test_slip_hall", "name": "Slip Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##################",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"#................#",
		"##################"], "light": "bright"},
	"areas": [{"id": "den", "name": "Den", "cells": [[10, 1], [15, 5]]}],
	"spawns": {"default": [2, 3]},
	"containers": [
		{"id": "guarded_chest", "cell": [10, 1], "label": "Chest", "items": [{"id": "dagger", "qty": 1}], "gold": 5},
		{"id": "plain_chest", "cell": [2, 1], "label": "Plain chest", "items": [{"id": "dagger", "qty": 1}]}],
	"encounters": [{"id": "den_wolf", "trigger": "enter_area:den", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [13, 3], "facing": "west"}], "flag": "test_den_wolf_dead"}]
}
## The party arrives inside the fight's area, far from its foe.
const FAR := {
	"id": "test_slip_far", "name": "Far Pit", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"####################",
		"#..................#",
		"#..................#",
		"#..................#",
		"####################"], "light": "bright"},
	"areas": [{"id": "whole", "name": "Whole room", "cells": [[1, 1], [18, 3]]}],
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "far_wolf", "trigger": "enter_area:whole", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [18, 2], "facing": "west"}], "flag": "test_far_wolf_dead"}]
}
## The same, with a zombie (passive Perception 8) two squares from where they arrive.
const NEAR := {
	"id": "test_slip_near", "name": "Near Pit", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "bright"},
	"areas": [{"id": "whole", "name": "Whole room", "cells": [[1, 1], [8, 3]]}],
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "near_zombie", "trigger": "enter_area:whole", "waiting": true,
		"monsters": [{"monster": "zombie", "cell": [4, 2], "facing": "west"}], "flag": "test_near_zombie_dead"}]
}

var root: Node
var _toasts: Array[String] = []
var _loots := 0


func _new_game() -> void:
	for l: Dictionary in [HALL, FAR, NEAR]:
		Compendium.shared().tables["locations"][str(l["id"])] = l.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_slip_hall"
	Dice.reseed(4)


func before_each() -> void:
	_new_game()
	_toasts.clear()
	_loots = 0


func after_each() -> void:
	GameSettings.set_turn_based(false)
	for id: String in ["test_slip_hall", "test_slip_far", "test_slip_near"]:
		Compendium.shared().tables["locations"].erase(id)
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


## The game on the fixture hall, changed by `edit` (the hall's data copy) first. Toasts and loot windows are counted.
func _start(edit: Callable = Callable()) -> void:
	if edit.is_valid():
		var hall := (Compendium.shared().tables["locations"] as Dictionary)["test_slip_hall"] as Dictionary
		edit.call(hall)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	_watch()


func _watch() -> void:
	_view().toast.connect(func(t: String) -> void: _toasts.append(t))
	_view().loot_opened.connect(func(_id: String, _items: Array, _gold: float) -> void: _loots += 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _wolf() -> Combatant:
	return _view().waiting[0]["foe"] as Combatant


func _pp() -> int:
	return LocationStealth.passive_score(_wolf())


## Sneaking, every member's total set rather than rolled.
func _sneak_with(total: int) -> void:
	var v := _view()
	v.set_sneaking(true)
	for m: Combatant in v.members + v.guest_members:
		v.sneak_totals[m.creature] = total


## The leader steps from `from` one square `dir`, as a walk does (the others trail behind).
func _step(from: Vector2i, dir: Vector2i) -> void:
	var v := _view()
	v.leader().cell = from
	LocationWalk.step(v, dir)
	LocationWalk.tick(v, 1.0)
	await _frames(1)


## Wolf foes that are surprised in the fight just started.
func _surprised_foes() -> int:
	var n := 0
	for c in _view().combat_view.e.combatants:
		if c.side == &"enemy" and c.surprised:
			n += 1
	return n


func _in_den(c: Vector2i) -> bool:
	return c.x >= 10 and c.x <= 15 and c.y >= 1 and c.y <= 5


func _toasted(prefix: String) -> bool:
	return _toasts.any(func(t: String) -> bool: return t.begins_with(prefix))


# --- Stepping in ---------------------------------------------------------------------------------------

func test_a_sneaking_party_that_steps_in_unnoticed_starts_nothing() -> void:
	await _start()
	var v := _view()
	_sneak_with(_pp() + 1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_eq(v.leader().cell, Vector2i(10, 3), "the leader is in the den's area")
	assert_false(v.in_combat, "and nothing started: the wolf never noticed them")
	assert_true(v._slipping.has("den_wolf"), "they are slipping past it")
	assert_eq(v.waiting.size(), 1, "the wolf stands where it was")
	assert_true("Unnoticed: the Wolf hasn't seen you" in _toasts, str(_toasts))
	# It keeps checking every step: one more square in, still beaten.
	await _step(Vector2i(10, 3), Vector2i.RIGHT)
	assert_false(v.in_combat, "still unseen")
	assert_eq(_toasts.filter(func(t: String) -> bool: return t.begins_with("Unnoticed")).size(), 1, "said once an entry")


func test_a_foe_that_notices_the_sneak_starts_the_fight_with_nobody_surprised() -> void:
	await _start()
	var v := _view()
	_sneak_with(1)   # ahead of the wolf, in its cone, 15 ft off
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "it sees them step in: the fight starts")
	assert_true(_toasted("Wolf spots "), str(_toasts))
	assert_false(_toasted("Unnoticed"), "and they weren't unnoticed")
	await _frames(3)
	assert_eq(_surprised_foes(), 0, "a fight a foe starts surprises no one")


func test_a_foe_hears_them_all_round_within_ten_feet_and_not_behind_it_farther_off() -> void:
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [11, 3], "facing": "east"}])
	var v := _view()
	_sneak_with(1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "it faces away, but they came within 10 ft of it: heard")
	root.queue_free()
	root = null
	await _frames(2)
	_new_game()
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [14, 3], "facing": "east"}])
	_sneak_with(1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_false(_view().in_combat, "a wolf 20 ft off facing away sees nothing, whatever their Stealth")
	assert_true(_view()._slipping.has("den_wolf"))


func test_a_party_that_is_not_sneaking_starts_the_fight_as_it_always_did() -> void:
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [14, 3], "facing": "east"}])
	var v := _view()
	assert_false(v.sneaking)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "stepping into the area starts it, though the wolf looks the other way")
	assert_false(v._slipping.has("den_wolf"))


func test_stopping_to_sneak_inside_the_area_starts_the_fight_whether_or_not_a_foe_would_notice() -> void:
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [14, 3], "facing": "east"}])
	var v := _view()
	_sneak_with(_pp() + 1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_false(v.in_combat)
	var e := LocationStealth.watch(v)
	assert_false(LocationStealth.notices(e, _wolf(), v.leader(), false, 0), "it wouldn't notice them even walking openly here")
	v.set_sneaking(false)
	assert_true(v.in_combat, "but it is the same as stepping in without sneaking: the fight starts")
	await _frames(3)
	assert_eq(_surprised_foes(), 0, "the party that stops sneaking surprises no one")


func test_stopping_to_sneak_outside_the_area_starts_nothing() -> void:
	await _start()
	var v := _view()
	_sneak_with(_pp() + 1)
	v.set_sneaking(false)
	assert_false(v.in_combat, "far from the wolf, in the west of the hall")


# --- Slipping past -----------------------------------------------------------------------------------------

## The party slips into the den and out again: the leader steps in at (10, 3) and the party walks west.
func _slip_in_and_out() -> void:
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	await _step(Vector2i(10, 3), Vector2i.LEFT)   # the follower takes the square the leader leaves: inside
	assert_true(_view()._slipping.has("den_wolf"), "still inside: the last of them hasn't left")
	await _step(Vector2i(9, 3), Vector2i.LEFT)


func test_leaving_the_area_unnoticed_is_slipping_past_the_fight() -> void:
	await _start()
	var v := _view()
	var st := GameState.story
	_sneak_with(_pp() + 1)
	await _slip_in_and_out()
	assert_false(v.in_combat)
	assert_false(v._slipping.has("den_wolf"), "no longer slipping: past")
	assert_true("Slipped past the Wolf" in _toasts, str(_toasts))
	assert_false(st.flags.has("test_den_wolf_dead"), "the fight's own flag isn't set")
	assert_false((st.loc_state("test_slip_hall")["encounters"] as Dictionary).has("den_wolf"), "nor is it marked done")
	assert_false(st.flags.has("_xp/fight/den_wolf"), "milestone levelling: nothing is paid")
	assert_eq(LocationStealth.waiting_specs(v).size(), 1, "it is still there to be fought")
	assert_eq(v.waiting.size(), 1)


func test_the_fight_slipped_past_starts_when_the_party_steps_in_openly() -> void:
	await _start()
	var v := _view()
	_sneak_with(_pp() + 1)
	await _slip_in_and_out()
	assert_false(v.in_combat)
	v.members[0].cell = Vector2i(2, 3)   # back in the west of the hall, well out of the wolf's reach
	v.members[1].cell = Vector2i(2, 2)
	v.set_sneaking(false)
	assert_false(v.in_combat, "the party is outside the den and far from the wolf")
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "walking in without sneaking starts it")


func test_a_fight_that_starts_while_slipping_is_not_slipped_past() -> void:
	await _start()
	var v := _view()
	_sneak_with(_pp() + 1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v._slipping.has("den_wolf"))
	assert_true(v.strike(), "the party opens the fight itself")
	assert_false(v._slipping.has("den_wolf"), "that is a fight, not a slip")
	await _frames(3)
	assert_false(_toasted("Slipped past"))
	assert_true(_surprised_foes() > 0, "and the sneaking party that opened it surprises the wolf, as ever")


func test_in_experience_mode_slipping_past_pays_once_like_a_fight_talked_away() -> void:
	GameState.story.options[Xp.OPTION] = Xp.EXPERIENCE
	await _start()
	var v := _view()
	var st := GameState.story
	var want := Xp.spec_xp(Xp.encounter_spec(st, "den_wolf"))
	assert_true(want > 0, "a wolf is worth something")
	var before := st.xp
	_sneak_with(_pp() + 1)
	await _slip_in_and_out()
	assert_eq(st.xp - before, want, "what winning the fight would have paid")
	assert_true(("+%d XP" % want) in _toasts, str(_toasts))
	assert_true(st.flags.has("_xp/fight/den_wolf"), "once a fight, the key a talked-away fight leaves")
	assert_false(st.flags.has("test_den_wolf_dead"))
	# Again: in and out, nothing more.
	await _slip_in_and_out()
	assert_eq(st.xp - before, want, "slipping past twice pays once")
	# And fighting it later pays nothing more.
	v.members[0].cell = Vector2i(2, 3)
	v.members[1].cell = Vector2i(2, 2)
	v.set_sneaking(false)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "the fight is still there")
	await _frames(3)
	v.combat_view.finished.emit("victory")
	await _frames(3)
	assert_eq(st.xp - before, want, "won after being slipped past: paid once")


func test_slipping_past_in_milestone_mode_only_says_so() -> void:
	await _start()
	var st := GameState.story
	var before := st.xp
	_sneak_with(_pp() + 1)
	await _slip_in_and_out()
	assert_eq(st.xp, before)
	assert_eq(_toasts.filter(func(t: String) -> bool: return t.contains("XP")).size(), 0, str(_toasts))
	assert_true("Slipped past the Wolf" in _toasts)


func test_a_party_still_in_the_area_has_not_slipped_past() -> void:
	await _start()
	var v := _view()
	_sneak_with(_pp() + 1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	v.members[1].cell = Vector2i(11, 2)   # a companion lingers in the den
	v.leader().cell = Vector2i(8, 3)
	LocationStealth.after_step(v)
	assert_true(v._slipping.has("den_wolf"), "they have not all left")
	assert_false(_toasted("Slipped past"))
	v.members[1].cell = Vector2i(8, 2)
	LocationStealth.after_step(v)
	assert_false(v._slipping.has("den_wolf"))
	assert_true(_toasted("Slipped past"))


# --- Containers ----------------------------------------------------------------------------------------

func test_a_container_in_the_area_says_it_is_guarded() -> void:
	await _start()
	var v := _view()
	await _frames(2)
	var chest := v.thing_at(Vector2i(10, 1))
	assert_true(str(chest["label"]).contains("Guarded: taking from it where they'd see starts the fight"), str(chest["label"]))
	assert_false(str(v.thing_at(Vector2i(2, 1))["label"]).contains("Guarded"), "one outside the area isn't")
	LocationStealth.clear_waiting(v, "den_wolf")
	v.waiting.clear()
	assert_false(str(v.thing_at(Vector2i(10, 1))["label"]).contains("Guarded"), "and once the foes are gone it isn't either")


func test_taking_from_a_guarded_container_unnoticed_goes_through() -> void:
	await _start()
	var v := _view()
	var chest := v.thing_at(Vector2i(10, 1))["spec"] as Dictionary
	_sneak_with(_pp() + 1)
	v.leader().cell = Vector2i(10, 2)
	LocationInteraction._use_container(v, chest)
	assert_false(v.in_combat, "no one noticed the taker")
	assert_eq(_loots, 1, "the chest opened")


func test_a_foe_that_would_notice_the_taker_starts_its_fight_and_nothing_is_taken() -> void:
	await _start()
	var v := _view()
	var chest := v.thing_at(Vector2i(10, 1))["spec"] as Dictionary
	_sneak_with(1)
	v.leader().cell = Vector2i(10, 2)
	LocationInteraction._use_container(v, chest)
	assert_true(v.in_combat, "the wolf notices them at the chest")
	assert_eq(_loots, 0, "and the take doesn't go through")
	assert_true(_toasted("Wolf spots "), str(_toasts))
	await _frames(3)
	assert_eq(_surprised_foes(), 0, "nobody is surprised")


func test_the_same_rule_holds_for_a_party_that_is_not_sneaking() -> void:
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [14, 3], "facing": "east"}])
	var v := _view()
	var chest := v.thing_at(Vector2i(10, 1))["spec"] as Dictionary
	v.leader().cell = Vector2i(10, 2)   # 20 ft behind a wolf that looks away
	LocationInteraction._use_container(v, chest)
	assert_false(v.in_combat, "nobody would notice them")
	assert_eq(_loots, 1)


func test_a_container_outside_every_area_is_taken_from_as_ever() -> void:
	await _start()
	var v := _view()
	var chest := v.thing_at(Vector2i(2, 1))["spec"] as Dictionary
	_sneak_with(1)
	v.leader().cell = Vector2i(2, 2)
	LocationInteraction._use_container(v, chest)
	assert_false(v.in_combat)
	assert_eq(_loots, 1)


# --- Sleepers and unseen foes ----------------------------------------------------------------------------

func test_a_sleeper_notices_nobody_so_a_sneaking_party_slips_in_and_an_open_one_wakes_it() -> void:
	var asleep := func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["surprise"] = "enemies"
	await _start(asleep)
	var v := _view()
	_sneak_with(1)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_false(v.in_combat, "a clumsy sneak steps in beside a sleeper: it doesn't wake")
	assert_true(v._slipping.has("den_wolf"))
	v.set_sneaking(false)
	assert_true(v.in_combat, "but a party that isn't sneaking starts the fight")
	await _frames(3)
	assert_true(_surprised_foes() > 0, "and the sleepers are surprised by the spec, as ever")


func test_a_fight_of_unseen_foes_only_still_starts_on_the_step() -> void:
	await _start(func(hall: Dictionary) -> void:
		((hall["encounters"] as Array)[0] as Dictionary)["monsters"] = [{"monster": "wolf", "cell": [13, 3], "unseen": true}])
	var v := _view()
	assert_eq(v.waiting.size(), 0, "no one in plain view")
	_sneak_with(30)
	await _step(Vector2i(9, 3), Vector2i.RIGHT)
	assert_true(v.in_combat, "nothing to slip past: stepping in starts it, however well they sneak")


# --- The hover hint ----------------------------------------------------------------------------------------

func test_hovering_a_guarded_area_warns_a_party_that_is_not_sneaking() -> void:
	await _start()
	var v := _view()
	await _frames(2)
	assert_true(LocationStealth.is_shown(v.waiting[0]), "the wolf is in view down the hall")
	var warn := "Stepping in starts the fight; sneak to pass unseen"
	assert_eq(LocationStealth.hover_warning(v, Vector2i(12, 4)), warn, "inside the den's area")
	assert_eq(LocationStealth.guarded_hint(v, Vector2i(12, 4)), warn)
	assert_eq(LocationStealth.hover_warning(v, Vector2i(5, 3)), "", "outside it, nothing")
	_sneak_with(_pp() + 1)
	assert_ne(LocationStealth.hover_warning(v, Vector2i(12, 4)), warn, "a party that sneaks isn't told to sneak")
	assert_eq(LocationStealth.guarded_hint(v, Vector2i(12, 4)), "")


func test_a_fight_the_party_has_not_seen_gives_nothing_away() -> void:
	await _start()
	var v := _view()
	await _frames(2)
	v.waiting[0]["token"].queue_free()
	v.waiting[0]["token"] = null   # not in view
	assert_false(LocationStealth.is_shown(v.waiting[0]))
	assert_eq(LocationStealth.hover_warning(v, Vector2i(12, 4)), "")


# --- Arriving ---------------------------------------------------------------------------------------------------

func test_arriving_inside_the_area_without_sneaking_starts_the_fight() -> void:
	await _start()
	root.call("enter_location", "test_slip_far", "default", false)
	await _frames(4)
	assert_true(_view().in_combat, "the spawn is inside the wolf's area")


func test_arriving_sneaking_inside_the_area_slips_in_when_nothing_notices() -> void:
	await _start()
	root.call("enter_location", "test_slip_far", "default", true)
	await _frames(4)
	var v := _view()
	assert_true(v.sneaking, "they came through the exit sneaking")
	assert_false(v.in_combat, "the wolf is 80 ft off: it notices nobody")
	assert_true(v._slipping.has("far_wolf"), "they slipped into its area on arriving")
	assert_eq(v.sneak_totals.size(), 2, "with this place's own rolls")


## Arrives sneaking at the near pit with the dice seeded `seed_`: a fresh game, the party beside a zombie (8 passive Perception).
func _arrive_near(seed_: int) -> LocationView:
	if root != null:
		root.queue_free()
		root = null
		await _frames(2)
	_new_game()
	Dice.reseed(seed_)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	root.call("enter_location", "test_slip_near", "default", true)
	await _frames(4)
	return _view()


func test_arriving_sneaking_next_to_a_foe_starts_its_fight_only_if_it_notices() -> void:
	var noticed := 0
	var slipped := 0
	for seed_ in 24:
		var v := await _arrive_near(seed_ + 1)
		var pp := Monster.from_data(Compendium.shared().monster_data("zombie")).passive_score(&"perception").total()
		var worst := 1 << 20
		for m: Combatant in v.members:
			worst = mini(worst, int(v.sneak_totals[m.creature]))
		var notices := worst <= pp
		assert_eq(v.in_combat, notices, "seed %d: a fight iff a Stealth total (%d) doesn't beat the zombie's %d" % [seed_ + 1, worst, pp])
		if v.in_combat:
			noticed += 1
		else:
			slipped += 1
			assert_true(v._slipping.has("near_zombie"), "seed %d: unnoticed, they slip in" % (seed_ + 1))
		if noticed > 0 and slipped > 0 and seed_ > 6:
			break
	assert_true(noticed > 0 and slipped > 0, "both ways were seen: %d noticed, %d slipped" % [noticed, slipped])
