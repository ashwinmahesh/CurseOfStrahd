extends TestCase
## Skill checks on things in a location (world/exploration/location_checks.gd): the right-click menu offers each one with
## who'd roll, their bonus and the chance, and the hover name says which skills a thing still has to offer; a try walks up,
## rolls on the big d20 and says how it went; a success can reveal a hiding place, a trap or something elsewhere, disarm a
## trap, undo a lock, open a door from the far side, carry the party across to another square, teach a codex entry or
## bring a chest into view with its flag; a failure can hurt whoever tried and passes the next try to someone else; and
## Heroic Inspiration can still be spent on a failed roll.

const LOC := {
	"id": "test_checks", "name": "Test Checks", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#############",
		"#.....#.....#",
		"#.....#.....#",
		"#...........#",
		"#######.....#",
		"#############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"doors": [{"id": "bolted", "cell": [6, 3], "locked": true, "lock_dc": 0, "label": "the bolted door"}],
	"props": [
		{"id": "runes", "cell": [1, 1], "kind": "examine", "label": "Runes on the wall", "checks": [
			{"id": "read_runes", "skill": "arcana", "dc": 1, "label": "Read the runes",
				"success": {"text": "The runes point to a niche.", "reveal": ["hidden_cache", "plate", "test_elsewhere:far_cache"],
					"codex": {"id": "test_rune_lore", "title": "The Runes", "text": "A warding script."}}},
			{"id": "touch_runes", "skill": "arcana", "dc": 40, "label": "Draw on the runes",
				"success": {"text": "Never."}, "failure": {"text": "A spark bites.", "damage": "1d4", "damage_type": "lightning"}},
			{"id": "wake_runes", "skill": "arcana", "dc": 40, "label": "Wake the runes", "once": true,
				"success": {"text": "Never."}, "failure": {"text": "Something answers."}}]},
		{"id": "hidden_cache", "cell": [2, 1], "kind": "search", "search_dc": 40, "label": "A niche", "item": "potion_of_healing_greater"},
		{"id": "crack", "cell": [5, 1], "kind": "decor", "label": "A crack in the wall", "checks": [
			{"id": "squeeze", "skill": "acrobatics", "dc": 1, "label": "Squeeze through", "alone": true,
				"success": {"text": "Through.", "move": [8, 2]}}]},
		{"id": "bolt", "cell": [7, 1], "kind": "decor", "label": "The door's bolt", "checks": [
			{"id": "draw_bolt", "skill": "athletics", "dc": 1, "label": "Draw the stiff bolt",
				"success": {"text": "It grinds back.", "open": ["bolted"]}}]},
		{"id": "marks", "cell": [4, 3], "kind": "decor", "label": "Scuffed floor", "checks": [
			{"id": "jam_plate", "skill": "nature", "dc": 1, "label": "Wedge the plate",
				"success": {"text": "Wedged.", "disarm": ["plate"]}},
			{"id": "call_out", "skill": "performance", "dc": 1, "label": "Sing to the dark",
				"success": {"text": "Something answers.", "flag": "test_checks_song"}}]},
		{"id": "crypt", "cell": [9, 1], "kind": "examine", "label": "A small sarcophagus", "dialogue": "test/checks:crypt",
			"checks": [{"id": "crypt_joke", "skill": "performance", "dc": 15, "label": "Tell the crypt a joke",
				"success": {"text": "Something laughs."}}]}],
	"containers": [
		{"id": "coffer", "cell": [3, 1], "label": "Coffer", "lock_dc": 30, "gold": 4, "checks": [
			{"id": "feel_lock", "skill": "sleight_of_hand", "dc": 1, "label": "Feel for the catch",
				"success": {"text": "Click.", "unlock": ["coffer"]}}]},
		{"id": "song_box", "cell": [1, 3], "label": "Music box", "gold": 2, "when": "flag.test_checks_song"}],
	"encounters": [{"id": "rune_guard", "trigger": "check:wake_runes:failure", "monsters": [{"monster": "crawling_claw", "cell": [4, 2]}]}],
	"traps": [{"id": "plate", "cells": [[5, 3]], "detect_dc": 40, "disarm_dc": 40, "label": "a pressure plate", "damage": "1d6",
		"save": {"ability": "dex", "dc": 12}}],
}

const ELSEWHERE := {
	"id": "test_elsewhere", "name": "Elsewhere", "region": "test", "summary": "A fixture.",
	"map": {"rows": ["#####", "#...#", "#####"], "light": "dim"}, "spawns": {"default": [1, 1]},
	"props": [{"id": "far_cache", "cell": [3, 1], "kind": "search", "search_dc": 40, "label": "A far cache", "item": "antitoxin"}],
}

var root: Node
var said: Array[String] = []
var rolls: Array[String] = []


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_checks"] = LOC.duplicate(true)
	Compendium.shared().tables["locations"]["test_elsewhere"] = ELSEWHERE.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_checks"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	said.clear()
	rolls.clear()
	var v := _view()
	v.narration.connect(func(text: String) -> void: said.append(text))
	v.toast.connect(func(text: String) -> void: said.append(text))
	v.big_roll.connect(func(_t: D20Test, who: String, label: String) -> void: rolls.append("%s|%s" % [who, label]))


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	# The fixtures aren't real content (test_set_dressing checks every location's props for art).
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_checks")
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_elsewhere")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _try(cell: Vector2i, check_id: String) -> void:
	var v := _view()
	LocationChecks.act(v, v.thing_at(cell), "check:" + check_id)


func _action(cell: Vector2i, id: String) -> Dictionary:
	for a: Variant in _view().actions_at(cell)["actions"]:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func _states(key: String, loc: String = "test_checks") -> Dictionary:
	return GameState.story.loc_state(loc)[key] as Dictionary


func test_the_menu_offers_each_check_with_who_and_the_chance() -> void:
	var line := _action(Vector2i(1, 1), "check:read_runes")
	assert_false(line.is_empty(), "the check is on the menu: %s" % [_view().actions_at(Vector2i(1, 1))])
	var who := WorldChecks.roller(GameState.story, "test_checks", LOC["props"][0]["checks"][0] as Dictionary)
	assert_true(str(line["label"]).begins_with("Read the runes (Arcana DC 1: %s %s" % [who.name.get_slice(" ", 0), who.skill_bonus(&"arcana").signed()]),
		"who rolls and their bonus, signed: %s" % line["label"])
	assert_true(str(line["label"]).ends_with("100%)"), str(line["label"]))
	assert_true("(Arcana)" in str(_view().thing_at(Vector2i(1, 1))["label"]), "the hover name says what it offers")
	assert_true("(Sleight Of Hand)" in str(_view().thing_at(Vector2i(3, 1))["label"]), "a chest's too: %s" % _view().thing_at(Vector2i(3, 1))["label"])
	var plates := ThingLabels.new()
	plates.view = _view()
	assert_eq(str(plates.call("_name", _view().thing_at(Vector2i(1, 1)))[0]), "Runes on the wall · Arcana", "and its name plate")
	plates.free()


## Wiki finding 79: a thing with a conversation (the castle's Speak with Dead talks) still gives its "Right-click it to
## try" tip, once the conversation is over and the HUD is back.
func test_a_thing_with_a_conversation_still_tips_its_check() -> void:
	DialogueFile.register(DialogueFile.parse("~ crypt\nNarrator: A small sarcophagus, carved with bells.\n-> END\n", "test/checks"))
	var v := _view()
	LocationInteraction.interact(v, v.thing_at(Vector2i(9, 1)))
	await _frames(2)
	var d := root.get("dialogue") as DialogueUI
	assert_true(d != null, "the conversation opens")
	assert_false(said.has("Right-click it to try Performance"), "no tip under the conversation")
	for i in 20:
		if root.get("dialogue") == null:
			break
		if bool(d.get("_waiting_continue")):
			d.call("_advance")
		await _frames(1)
	await _frames(2)
	assert_true(root.get("dialogue") == null, "the talk is over")
	assert_true(said.has("Right-click it to try Performance"), "the tip once it's over: %s" % [said])


func test_walking_up_and_trying_reveals_teaches_and_hints() -> void:
	var v := _view()
	v.act(Vector2i(1, 1), "check:read_runes")
	for i in 400:
		if not WorldChecks.open(GameState.story, "test_checks", LOC["props"][0]["checks"][0] as Dictionary):
			break
		await get_tree().process_frame
	assert_eq(rolls.size(), 1, "it rolled on the big d20: %s" % [rolls])
	assert_true(rolls[0].ends_with("|Arcana"))
	assert_true(said.has("The runes point to a niche."), str(said))
	assert_true(bool(_states("found").get("hidden_cache", false)), "the niche is found")
	assert_false(v.thing_at(Vector2i(2, 1)).is_empty(), "and on the board")
	var roller := rolls[0].get_slice("|", 0)
	var taker: Character = null
	for ch in GameState.story.party:
		if ch.name == roller:
			taker = ch
	assert_true(taker != null and taker.carries("potion_of_healing_greater"), "and what's in it goes to whoever read the runes (%s)" % roller)
	assert_true(bool(_states("props").get("hidden_cache", false)), "taken: the niche is empty now")
	assert_true((root.get("notices") as ItemNotices).shown().size() >= 1, "and the find is announced on the side")
	assert_true(said.any(func(s: String) -> bool: return s.begins_with("Now you know where to look: A far cache (Elsewhere)")), str(said))
	assert_eq(str(_states("traps").get("plate", "")), "found", "the plate is found and marked")
	assert_true(v.trap_marks.has("plate"))
	assert_true(bool(_states("found", "test_elsewhere").get("far_cache", false)), "a place hint: the far cache is known")
	assert_true("test_rune_lore" in GameState.story.codex)
	assert_eq(JournalScreen._codex_entry("test_rune_lore")["title"], "The Runes", "the codex finds the entry")
	assert_true(_action(Vector2i(1, 1), "check:read_runes").is_empty(), "a success is done")
	assert_false("(Arcana)" in str(v.thing_at(Vector2i(1, 1))["label"]) and _action(Vector2i(1, 1), "check:touch_runes").is_empty())


func test_a_failure_hurts_and_passes_the_try_on() -> void:
	var v := _view()
	var check := LOC["props"][0]["checks"][1] as Dictionary
	var first := WorldChecks.roller(GameState.story, "test_checks", check)
	var hp := first.hp
	_try(Vector2i(1, 1), "touch_runes")
	assert_true(first.hp < hp, "the spark bites whoever touched it")
	assert_true(said.has("A spark bites."), str(said))
	var line := _action(Vector2i(1, 1), "check:touch_runes")
	assert_false(str(line["label"]).contains(" %s " % first.name.get_slice(" ", 0)), "the next try is someone else's: %s" % line["label"])
	for i in 3:
		_try(Vector2i(1, 1), "touch_runes")
	line = _action(Vector2i(1, 1), "check:touch_runes")
	assert_false(bool(line.get("enabled", true)), "everyone has tried")
	assert_eq(str(line["why"]), "Everyone able has tried")
	var before := rolls.size()
	_try(Vector2i(1, 1), "touch_runes")
	assert_eq(rolls.size(), before, "and nobody rolls again")
	assert_true(v != null)


func test_a_squeeze_carries_the_party_across() -> void:
	_try(Vector2i(5, 1), "squeeze")
	var v := _view()
	assert_eq(v.leader().cell, Vector2i(8, 2), "the leader is through")
	for m in v.members:
		assert_true(m.cell.x >= 7, "everyone's on the far side: %s" % m.cell)
	assert_eq(GameState.story.positions[0], Vector2i(8, 2), "and it's kept")


func test_drawing_the_bolt_opens_the_door() -> void:
	_try(Vector2i(7, 1), "draw_bolt")
	assert_eq(str(_states("doors").get("bolted", "")), LocationView.DOOR_OPEN)
	assert_false(_view().grid.has_flag(Vector2i(6, 3), CombatGrid.WALL), "the way is open")


func test_a_trap_wedged_and_a_lock_felt_open() -> void:
	_try(Vector2i(4, 3), "jam_plate")
	assert_eq(str(_states("traps").get("plate", "")), "disarmed")
	_try(Vector2i(3, 1), "feel_lock")
	assert_false(_view()._locked(LOC["containers"][0] as Dictionary), "the coffer's catch gives")


func test_a_flag_brings_a_chest_into_view() -> void:
	var v := _view()
	assert_true(v.thing_at(Vector2i(1, 3)).is_empty(), "no music box yet")
	_try(Vector2i(4, 3), "call_out")
	assert_true(bool(GameState.story.get_flag("test_checks_song")))
	assert_false(v.thing_at(Vector2i(1, 3)).is_empty(), "the music box is there now")


func test_heroic_inspiration_rerolls_a_failure() -> void:
	var v := _view()
	var check := LOC["props"][0]["checks"][1] as Dictionary
	var first := WorldChecks.roller(GameState.story, "test_checks", check)
	first.heroic_inspiration = true
	_try(Vector2i(1, 1), "touch_runes")
	var aid := _action(Vector2i(1, 1), "check_aid:heroic_inspiration")
	assert_false(aid.is_empty(), "the menu offers the reroll: %s" % [v.actions_at(Vector2i(1, 1))["actions"]])
	# The new roll meets the DC (the runes give way after all).
	((v.get_meta(LocationChecks.FAILED) as Dictionary)["test"] as D20Test).target = -20
	v.act(Vector2i(1, 1), "check_aid:heroic_inspiration")
	assert_false(first.heroic_inspiration, "it's spent")
	assert_true(WorldChecks.done(GameState.story, "test_checks", check), "and the check succeeds")
	assert_true(said.has("Never."), str(said))
	assert_true(_action(Vector2i(1, 1), "check_aid:heroic_inspiration").is_empty())


## In the real village: the raven's success points at the lych-gate post, and the holy water hidden there is found.
func test_the_village_raven_points_to_the_lych_gate() -> void:
	root.call("enter_location", "village_of_barovia", "")
	await _frames(2)
	var v := _view()
	var spec := {}
	for p: Variant in v.loc["props"]:
		if str((p as Dictionary)["id"]) == "churchyard_raven":
			spec = p as Dictionary
	assert_false(spec.is_empty(), "the raven is in the churchyard")
	assert_false(v.thing_at(LocationView._cell(spec["cell"])).is_empty(), "and on the board")
	assert_false(_action(LocationView._cell(spec["cell"]), "check:raven_coax").is_empty(), "with its check on the menu")
	var check := WorldChecks.find(spec, "raven_coax")
	LocationChecks._resolve(v, spec, check, v.leader().creature as Character, true)
	assert_true(bool(_states("found", "village_of_barovia").get("lychgate_holy_water", false)), "the crack in the post is found")
	assert_false(v.thing_at(Vector2i(26, 8)).is_empty(), "and its hiding place is on the board")


## Every check placed in the game's data gives what the party can use: real items, no common magic items, and magic
## no rarer than the region's level allows (docs/story/found_magic_items.md); its DC is a 2024 DMG one.
func test_placed_checks_give_playable_things_that_fit_their_region() -> void:
	var comp := Compendium.shared()
	var max_rank := {1: 2, 2: 2, 3: 2, 4: 2, 5: 3, 6: 3, 7: 3, 8: 3, 9: 4, 10: 4}   # 2 uncommon, 3 rare, 4 very rare
	var ranks := {"common": 1, "uncommon": 2, "rare": 3, "very_rare": 4, "legendary": 5, "artifact": 6}
	var n := 0
	var skills := {}
	for loc: Dictionary in comp.all("locations"):
		if str(loc["id"]).begins_with("test_"):
			continue
		for c in WorldChecks.all_in(loc):
			var check := c["check"] as Dictionary
			var where := "%s %s" % [loc["id"], check["id"]]
			n += 1
			skills[str(check["skill"])] = true
			assert_between(float(check["dc"]), 5.0, 30.0, where)
			for result: String in ["success", "failure"]:
				for e: Variant in (check.get(result, {}) as Dictionary).get("items", []):
					var item := comp.item_data(str((e as Dictionary)["id"]))
					assert_false(item.is_empty(), "%s: no item %s" % [where, e])
					if not MagicItems.is_magic(item):
						continue
					assert_true(Compendium.playable(item), "%s: %s isn't playable yet" % [where, e])
					var rank := int(ranks.get(MagicItems.rarity(item), 0))
					assert_true(rank >= 2, "%s: %s is a common item" % [where, e])
					assert_true(rank <= int(max_rank.get(Treasure.level_for(str(loc["id"])), 4)), "%s: %s is too rare here" % [where, e])
	assert_true(n >= 40, "the checks are placed (%d)" % n)
	for s: String in ["nature", "arcana", "acrobatics", "animal_handling", "history", "religion", "medicine", "survival", "athletics", "performance"]:
		assert_true(skills.has(s), "%s has a use in the world" % s)


## In the abbey garden: unpicking the scarecrows' binding (a side flag) keeps their fight from starting.
func test_unbinding_the_abbey_scarecrows_stops_their_fight() -> void:
	root.call("enter_location", "abbey_of_st_markovia_garden", "")
	await _frames(2)
	var v := _view()
	var spec := {}
	for p: Variant in v.loc["props"]:
		if str((p as Dictionary)["id"]) == "stitched_sentry":
			spec = p as Dictionary
	LocationChecks._resolve(v, spec, WorldChecks.find(spec, "scarecrows_unbind"), v.leader().creature as Character, true)
	assert_true(bool(GameState.story.get_flag("abbey_scarecrows_unbound")))
	assert_false(v._trigger_encounter("enter_area:scarecrow_row"), "the scarecrows stay on their poles")
	assert_false(v.in_combat)


func test_a_failure_can_set_off_a_fight() -> void:
	var v := _view()
	_try(Vector2i(1, 1), "wake_runes")
	assert_true(WorldChecks.spent(GameState.story, "test_checks", WorldChecks.find(LOC["props"][0] as Dictionary, "wake_runes")), "one try")
	await _frames(2)
	assert_true(v.in_combat, "the runes' guardian comes for whoever woke them")


## A save from before checks handed their finds over: the check passed and its niche was found, but nobody took what was
## in it. On arriving, it goes to the leader.
func test_an_older_save_gets_its_find_on_arriving() -> void:
	WorldChecks.records(GameState.story, "test_checks")["read_runes"] = "done"
	_states("found")["hidden_cache"] = true
	root.call("enter_location", "test_checks", "")
	await _frames(2)
	var leader := _view().leader().creature as Character
	assert_true(leader.carries("potion_of_healing_greater"), "the niche's potion comes with the party now")
	assert_true(bool(_states("props").get("hidden_cache", false)))
	root.call("enter_location", "test_checks", "")
	await _frames(2)
	assert_eq(leader.inventory.filter(func(e: Dictionary) -> bool: return str(e["id"]) == "potion_of_healing_greater").size(), 1, "and only once")


## The owner's report (2026-10-12): at the Wizard of Wines, passing the well's Athletics check hands over the rope tied off
## below its lip, and says so.
func test_the_wizard_of_wines_well_hands_over_its_rope() -> void:
	root.call("enter_location", "wizard_of_wines", "")
	await _frames(2)
	var v := _view()
	var spec := {}
	for p: Variant in v.loc["props"]:
		if str((p as Dictionary)["id"]) == "yard_well":
			spec = p as Dictionary
	var climber := v.leader().creature as Character
	LocationChecks._resolve(v, spec, WorldChecks.find(spec, "winery_well_climb"), climber, true)
	assert_true(climber.carries("rope_of_climbing"), "the climber comes up with the Rope of Climbing")
	var notices := root.get("notices") as ItemNotices
	assert_true(notices.shown().any(func(p: PanelContainer) -> bool:
		return p.find_children("ItemName", "Label", true, false).any(func(l: Node) -> bool: return (l as Label).text == "Rope of Climbing")),
		"and a notice says so")
