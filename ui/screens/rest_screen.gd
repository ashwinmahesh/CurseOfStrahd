class_name RestScreen
extends CanvasLayer
## Short and Long Rests (plan §5.2, docs/ui/party_management.md pm_03). Short Rest: one hour; each character spends
## Hit Point Dice one at a time (roll + Con, minimum 1) and short-rest features come back. Long Rest: eight hours;
## everything comes back, with the location's interruption risk. A location can forbid resting ("rest": no) or make
## it risky. Rests need nobody hostile around (the screen can't open in combat).

var root: Node
var st: StoryState
var _box: VBoxContainer
var _log: Label
var _short_done := false   ## Arcane Recovery comes after a finished Short Rest
var _long_done := false    ## after a Long Rest, casters may change their prepared spells


func _init() -> void:
	name = "RestScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Rest", Vector2(1100, 700))
	var loc := Compendium.shared().get_entry("locations", st.location)
	var rule := str(loc.get("rest", "risky"))
	if rule == "no":
		frame.add_child(UiKit.label("You can't rest here: %s" % loc.get("rest_text", "this place won't let you."), 17, "gilt", 1000))
		return
	frame.add_child(UiKit.label("Short Rest: 1 hour. Spend Hit Point Dice to heal; some features come back." + 
		"\nLong Rest: 8 hours. All Hit Points, Hit Point Dice, spell slots and features come back%s." % (
		"; this place is dangerous, and a rest may be interrupted" if rule == "risky" else ""), 15, "parchment", 1040))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	frame.add_child(UiKit.scroll(_box, Vector2(1040, 420)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.button("Finish the Short Rest (1 hour)", _finish_short))
	row.add_child(UiKit.button("Take a Long Rest (8 hours)", _long_rest.bind(rule)))
	frame.add_child(row)
	_log = UiKit.label("", 15, "gilt_light", 1040)
	frame.add_child(_log)
	_draw()


func _draw() -> void:
	for c in _box.get_children():
		c.queue_free()
	if _long_done and not PrepareScreen.preparable(st).is_empty():
		_box.add_child(UiKit.button("Change prepared spells", func() -> void:
			var ps := PrepareScreen.new()
			add_child(ps)
			ps.open(root, st, 0), 15))
	for ch in st.party:
		_arcane_recovery_row(ch)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiKit.portrait(CombatToken.art_for(ch), 56))
		var hd := ch.hit_dice()
		var dice_text: Array[String] = []
		for die: String in hd:
			var e := hd[die] as Dictionary
			dice_text.append("d%s: %d of %d" % [die, int(e["total"]) - int(e["spent"]), int(e["total"])])
		var l := UiKit.label("%s · HP %d/%d · Hit Point Dice %s" % [ch.name, ch.hp, ch.max_hp(), ", ".join(dice_text)], 15)
		l.custom_minimum_size = Vector2(620, 0)
		row.add_child(l)
		for die: String in hd:
			var e2 := hd[die] as Dictionary
			var b := UiKit.button("Spend a d%s" % die, func() -> void: _spend(ch, int(die)), 14)
			b.disabled = int(e2["spent"]) >= int(e2["total"]) or ch.hp >= ch.max_hp() or ch.dead
			row.add_child(b)
		_box.add_child(row)


func _spend(ch: Character, die: int) -> void:
	var healed := ch.spend_hit_die(Dice.roller, die)
	_log.text = "%s spends a d%d and regains %d Hit Points." % [ch.name, die, healed]
	_draw()


func _finish_short() -> void:
	for ch in st.party:
		if not ch.dead:
			ch.finish_short_rest()
	for g in st.guests:
		if not g.dead:
			g.finish_short_rest()
	st.advance_minutes(60)
	_log.text = "An hour passes. Short-rest features are back."
	_narrate("rest:short")
	_short_done = true
	_draw()


func _long_rest(rule: String) -> void:
	var interrupted := false
	if rule == "risky":
		interrupted = Dice.roller.roll_one(6, "Long Rest interruption") == 1
	if interrupted:
		st.advance_minutes(60)
		for ch in st.party:
			if not ch.dead:
				ch.finish_short_rest()
		_log.text = "Something moves in the dark, and nobody sleeps again. (Interrupted: a Short Rest's benefits only.)"
	else:
		st.advance_minutes(8 * 60)
		for ch in st.party:
			if not ch.dead:
				ch.finish_long_rest()
		for g in st.guests:
			if not g.dead:
				g.finish_long_rest()
		_log.text = "Eight hours pass. Everyone wakes rested, if not refreshed."
		_narrate("rest:long")
		var region := str(Compendium.shared().get_entry("locations", st.location).get("region", ""))
		_narrate("dream:" + region)
		_long_done = true
	_draw()
	root.call("_refresh")


func _narrate(key: String) -> void:
	if root == null or not root.has_method("narrate_key"):
		return
	# The place's own line first (rest:long:<location>, then rest:long:<region>), then the general one.
	var loc := Compendium.shared().get_entry("locations", st.location)
	var text := ""
	if not key.begins_with("dream:"):
		for k: String in ["%s:%s" % [key, st.location], "%s:%s" % [key, loc.get("region", "")]]:
			if text == "":
				text = str(root.call("narrate_key", k))
	if text == "":
		text = str(root.call("narrate_key", key))
	if text != "":
		_log.text += "\n" + text


## Arcane Recovery (Wizard 1, 2024): once per Long Rest, after a Short Rest, recover expended slots whose levels add up
## to at most half the Wizard level (rounded up), none of level 6 or higher. One button per slot level to recover.
func _arcane_recovery_row(ch: Character) -> void:
	var wiz := ch.class_level_of("wizard")
	if wiz <= 0 or not _short_done or ch.resource_left("arcane_recovery") <= 0 or ch.dead:
		return
	var budget := int(ch.get_meta("arcane_budget", (wiz + 1) / 2))
	if not _has_recoverable(ch, budget):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiKit.label("%s · Arcane Recovery (%d slot level%s left to recover):" % [ch.name.get_slice(" ", 0), budget, "" if budget == 1 else "s"], 15, "moonlight"))
	var any := false
	for lvl in range(1, mini(5, budget) + 1):
		if ch.slots_used[lvl - 1] <= 0:
			continue
		any = true
		var l := lvl
		row.add_child(UiKit.button("Recover a level %d slot" % l, func() -> void:
			ch.slots_used[l - 1] -= 1
			var left := budget - l
			ch.set_meta("arcane_budget", left)
			_log.text = "%s recovers a level %d spell slot." % [ch.name, l]
			if left <= 0 or not _has_recoverable(ch, left):
				ch.spend_resource("arcane_recovery")
				ch.remove_meta("arcane_budget")
			_draw(), 13))
	if not any:
		row.queue_free()
		return
	row.add_child(UiKit.button("Done", func() -> void:
		if ch.has_meta("arcane_budget"):
			ch.spend_resource("arcane_recovery")
			ch.remove_meta("arcane_budget")
		_draw(), 13))
	_box.add_child(row)


static func _has_recoverable(ch: Character, budget: int) -> bool:
	for lvl in range(1, mini(5, budget) + 1):
		if ch.slots_used[lvl - 1] > 0:
			return true
	return false
