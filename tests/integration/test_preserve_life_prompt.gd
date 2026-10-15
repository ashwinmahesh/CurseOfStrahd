extends TestCase
## Preserve Life's prompt on the combat HUD (2024: one use of Channel Divinity, 5 x Cleric level Hit Points shared among
## Bloodied creatures within 30 ft, none above half): a slider for each creature, a count of what is left to share that
## goes down as points are given and stops the sliders where the pool runs out, Heal to confirm, Skip to keep the use.

const WARD := {
	"id": "test_preserve_ward", "name": "Test Ward", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"encounters": [{"id": "rat", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [8, 3]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_preserve_ward"] = WARD.duplicate(true)
	GameState.reset()
	for id: String in ["hedda_ironvow", "ilse_varga", "tamsin_tealeaf", "ratatoille"]:
		var ch := TestChars.pregen(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_preserve_ward"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func after_each() -> void:
	get_tree().paused = false
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_preserve_ward")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A fight with Hedda's turn on, Ilse and Tamsin low, and the prompt for Preserve Life open.
func _prompt() -> Dictionary:
	var view := root.get("view") as LocationView
	assert_true(view.start_encounter("rat"), "the fight starts")
	await _frames(3)
	var cv := view.combat_view
	var hedda: Combatant = null
	var ilse: Combatant = null
	var tamsin: Combatant = null
	for c in cv.e.combatants:
		match c.creature.id:
			"hedda_ironvow":
				hedda = c
			"ilse_varga":
				ilse = c
			"tamsin_tealeaf":
				tamsin = c
	cv.e.turn_index = cv.e.order.find(hedda)
	cv.e._begin_turn()
	ilse.creature.hp = 4
	tamsin.creature.hp = 6
	cv.hud.refresh()
	await _frames(1)
	var r := cv.e.features.preserve_life_prompt(hedda)
	assert_true(r.pending != null, r.reason)
	cv.hud.show_prompt(r.pending)
	await _frames(2)
	return {"cv": cv, "hedda": hedda, "ilse": ilse, "tamsin": tamsin, "req": r.pending}


func test_the_prompt_counts_what_is_left_as_points_are_given() -> void:
	var p := await _prompt()
	var cv := p["cv"] as CombatView
	var req := p["req"] as ReactionRequest
	var ilse := p["ilse"] as Combatant
	var tamsin := p["tamsin"] as Combatant
	var hud := cv.hud
	var sliders := hud.get("_prompt_sliders") as Dictionary
	var pool := hud.get("_prompt_pool") as Label
	assert_true(hud.prompt_open(), "the prompt is up")
	assert_true(pool.visible, "with a count of the pool")
	assert_eq(sliders.size(), 2, "a slider for each Bloodied creature in reach: %s" % [sliders.keys()])
	assert_true((hud.get("_prompt_text") as Label).text.contains("25 Hit Points"), "the pool is said: %s" % (hud.get("_prompt_text") as Label).text)
	var start_left := req.unspent()
	assert_true(pool.text.contains("%d of 25" % start_left) or start_left <= 0, pool.text)
	# Give Ilse nothing and Tamsin nothing, then watch the count climb back to the whole pool.
	(sliders[ilse.id] as HSlider).value = 0
	(sliders[tamsin.id] as HSlider).value = 0
	assert_eq(req.unspent(), 25)
	assert_true(pool.text.contains("Left to share: 25 of 25"), pool.text)
	assert_true((hud.get("_prompt_use") as Button).disabled, "nothing given: Heal waits")
	# Four to Ilse: 21 left. Five to Tamsin: 16 left.
	(sliders[ilse.id] as HSlider).value = 4
	assert_eq(req.unspent(), 21)
	assert_true(pool.text.contains("Left to share: 21 of 25"), pool.text)
	(sliders[tamsin.id] as HSlider).value = 5
	assert_eq(req.unspent(), 16)
	assert_true(pool.text.contains("Left to share: 16 of 25"), pool.text)
	assert_false((hud.get("_prompt_use") as Button).disabled, "something given: Heal is on")
	# A slider can't pass the creature's room (half the maximum, less what it has) or what is left of the pool: it
	# stops at the lower of the two, here the 4 she has + the 16 left.
	var room := int((req.choice(ilse.id) as Dictionary)["room"])
	assert_eq(int((sliders[ilse.id] as HSlider).max_value), room, "the slider's own end is half the maximum")
	(sliders[ilse.id] as HSlider).value = 99
	assert_eq(int((sliders[ilse.id] as HSlider).value), mini(room, 4 + 16), "stops where the pool runs out")
	assert_eq(req.unspent(), 0, "nothing left to share")
	assert_true(pool.text.contains("All 25 Hit Points shared"), pool.text)
	# Heal: the points go where they were put, and the use is spent once.
	var uses := (p["hedda"] as Combatant).creature.resource_left("channel_divinity")
	(sliders[ilse.id] as HSlider).value = 4
	hud.answer_prompt(true)
	await _frames(4)
	assert_eq(ilse.creature.hp, 8, "4 given to Ilse")
	assert_eq(tamsin.creature.hp, 11, "5 given to Tamsin")
	assert_eq((p["hedda"] as Combatant).creature.resource_left("channel_divinity"), uses - 1, "one use")
	assert_false(hud.prompt_open(), "the prompt is gone")
	cv.finished.emit("victory")
	await _frames(3)


func test_a_slider_stops_where_the_pool_runs_out() -> void:
	var p := await _prompt()
	var cv := p["cv"] as CombatView
	var req := p["req"] as ReactionRequest
	var ilse := p["ilse"] as Combatant
	var tamsin := p["tamsin"] as Combatant
	var sliders := cv.hud.get("_prompt_sliders") as Dictionary
	# Pool 25: Ilse takes 16 (all she can, here), Tamsin is then held to the 9 that are left.
	(sliders[ilse.id] as HSlider).value = 0
	(sliders[tamsin.id] as HSlider).value = 0
	var ilse_room := int((req.choice(ilse.id) as Dictionary)["room"])
	var tamsin_room := int((req.choice(tamsin.id) as Dictionary)["room"])
	(sliders[ilse.id] as HSlider).value = minf(float(ilse_room), 20.0)
	var left := req.unspent()
	(sliders[tamsin.id] as HSlider).value = float(tamsin_room)
	assert_eq(int(req.amounts[tamsin.id]), mini(tamsin_room, left), "Tamsin gets what is left, no more")
	assert_true(req.unspent() >= 0, "never below nothing")
	assert_true(req.selection_error() == "", req.selection_error())
	cv.hud.answer_prompt(false)
	await _frames(3)
	cv.finished.emit("victory")
	await _frames(3)


func test_skip_keeps_the_use_and_most_hurt_first_puts_the_default_back() -> void:
	var p := await _prompt()
	var cv := p["cv"] as CombatView
	var req := p["req"] as ReactionRequest
	var hedda := p["hedda"] as Combatant
	var ilse := p["ilse"] as Combatant
	var sliders := cv.hud.get("_prompt_sliders") as Dictionary
	var default := req.amounts.duplicate()
	(sliders[ilse.id] as HSlider).value = 0
	assert_ne(req.amounts[ilse.id], default[ilse.id], "changed")
	var again := cv.hud.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).text == "Most hurt first" and (b as Button).is_visible_in_tree())
	assert_eq(again.size(), 1, "a button for the default division")
	(again[0] as Button).pressed.emit()
	assert_eq(req.amounts, default, "back to the default")
	var uses := hedda.creature.resource_left("channel_divinity")
	cv.hud.answer_prompt(false)
	await _frames(3)
	assert_eq(hedda.creature.resource_left("channel_divinity"), uses, "Skip keeps the use")
	assert_eq(ilse.creature.hp, 4, "and heals nobody")
	assert_true(hedda.action_available, "or the action")
	cv.finished.emit("victory")
	await _frames(3)
