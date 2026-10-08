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
## The log's card, hidden until there's something in it (an empty bordered box sat under the party; UI QA UI-16).
var _log_card: PanelContainer
var _short_done := false   ## Arcane Recovery comes after a finished Short Rest
var _long_done := false    ## after a Long Rest, casters may change their prepared spells
var _prepared_before: Dictionary = {}  ## PrepareScreen.snapshot() as the Long Rest ended: what its swap limits count from
var _study: Dictionary = {}  ## character id -> the magic item they study through the Short Rest (identifies it)


func _init() -> void:
	name = "RestScreen"
	layer = 30


func open(root_: Node, state: StoryState, _index: int) -> void:
	root = root_
	st = state
	var frame := UiKit.screen_frame(self, "Rest", Vector2(1160, 760))
	var loc := Compendium.shared().get_entry("locations", st.location)
	var rule := str(loc.get("rest", "risky"))
	# Story difficulty: a Long Rest in a risky place is never interrupted (combat/difficulty.gd).
	if rule == "risky" and Difficulty.of_options(st.options).safe_rests:
		rule = "safe"
	if rule == "no":
		frame.add_child(UiParts.row(UiKit.label("You can't rest here: %s" % loc.get("rest_text", "this place won't let you."), 17, "gilt", 1040)))
		return
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 12)
	kinds.add_child(_rest_card("Short Rest", "1 hour", "Spend Hit Point Dice to heal; some features come back.",
		UiKit.button("Finish the Short Rest (1 hour)", _finish_short, 16, "rest"), ""))
	kinds.add_child(_rest_card("Long Rest", "8 hours", "All Hit Points, Hit Point Dice, spell slots and features come back.",
		UiKit.button("Take a Long Rest (8 hours)", _long_rest.bind(rule), 16, "rest"),
		"Dangerous here: it may be interrupted" if rule == "risky" else "Safe here"))
	frame.add_child(kinds)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	var scroll := UiParts.fill_scroll(_box)
	frame.add_child(scroll)
	_log = UiKit.label("", 15, "gilt_light", 1040)
	_log_card = UiParts.card("ui_black", "gilt_dark", 0.85, 10)
	_log_card.custom_minimum_size = Vector2(0, 64)
	_log_card.add_child(_log)
	frame.add_child(_log_card)
	_draw()


func _rest_card(title: String, length: String, text: String, button: Button, risk: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiParts.section(title))
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 8)
	facts.add_child(UiParts.pill(length, "moonlight", 13))
	if risk != "":
		facts.add_child(UiParts.pill(risk, "rose" if risk.begins_with("Dangerous") else "bile", 13))
	col.add_child(facts)
	col.add_child(UiKit.label(text, 14, "vellum", 480))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(button)
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.55, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	return card


func _draw() -> void:
	_log_card.visible = _log.text != ""
	for c in _box.get_children():
		c.queue_free()
	if _long_done and not PrepareScreen.preparable(st).is_empty():
		var prep := UiKit.button("Change prepared spells", func() -> void:
			var ps := PrepareScreen.new()
			ps.earlier = _prepared_before
			add_child(ps)
			ps.open(root, st, 0), 15, "spells")
		UiParts.light_up(prep)
		prep.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(prep)
	elif _short_done and not PrepareScreen.preparable(st, "short_rest").is_empty():
		var swap := UiKit.button("Change what the rest lets you change", func() -> void:
			var ps2 := PrepareScreen.new()
			ps2.rest_kind = "short_rest"
			add_child(ps2)
			ps2.open(root, st, 0), 15)
		UiParts.light_up(swap)
		swap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(swap)
	_camp_talks()
	# One click for the usual Short Rest chore: everyone hurt spends dice until a roll would mostly go to waste.
	var anyone := false
	for ch in st.party:
		anyone = anyone or not _heal_plan(ch).is_empty()
	if anyone:
		var heal := UiKit.button("Heal up with Hit Point Dice", heal_up, 15, "rest")
		heal.tooltip_text = "Each hurt character spends Hit Point Dice, largest first, until they're close to full or out of dice."
		heal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(heal)
	for ch in st.party:
		_arcane_recovery_row(ch)
		_slot_exchange_row(ch)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiParts.framed_portrait(CombatToken.art_for(ch), 52.0, ch.hp <= 0, ch.dead))
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation", 2)
		who.custom_minimum_size = Vector2(300, 0)
		who.add_child(UiKit.label(ch.name, 16, "vellum"))
		who.add_child(UiParts.hp_bar(ch, 280.0, 18.0))
		row.add_child(who)
		var hd := ch.hit_dice()
		for die: String in hd:
			var e := hd[die] as Dictionary
			var dice := VBoxContainer.new()
			dice.add_theme_constant_override("separation", 2)
			dice.add_child(UiParts.caption("Hit Point Dice d%s" % die, 10))
			dice.add_child(UiParts.pips(int(e["total"]), int(e["total"]) - int(e["spent"]), "gilt_light"))
			dice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dice)
		row.add_child(UiParts.gap())
		for die: String in hd:
			var e2 := hd[die] as Dictionary
			var b := UiParts.small_button("Spend a d%s" % die, func() -> void: _spend(ch, int(die)))
			b.disabled = int(e2["spent"]) >= int(e2["total"]) or ch.hp >= ch.max_hp() or ch.dead
			b.tooltip_text = "Roll it and add your Constitution modifier (minimum 1)."
			row.add_child(b)
		_box.add_child(UiParts.row(row))
		_study_row(ch)
		_rest_cast_row(ch)


## Spells the hero casts on itself as each Long Rest ends, if the player wants (story/rest_casts.gd): Mage Armor.
func _rest_cast_row(ch: Character) -> void:
	var choices := RestCasts.choices(st.party, ch, Dice.roller)
	if choices.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiParts.caption("%s, as each Long Rest ends:" % ch.name.get_slice(" ", 0), 12))
	for choice in choices:
		var id := str(choice["id"])
		var check := CheckButton.new()
		check.text = "Cast %s (%s)" % [choice["name"], "free" if bool(choice["free"]) else "uses a spell slot"]
		check.button_pressed = bool(choice["on"])
		check.tooltip_text = "On: %s casts it on themself when the rest is over%s." % [ch.name.get_slice(" ", 0),
			"" if bool(choice["free"]) else ", with the lowest spell slot left"]
		check.toggled.connect(func(on: bool) -> void: RestCasts.set_wanted(ch, id, on))
		row.add_child(check)
	_box.add_child(UiParts.row(row))


## 2024: a character can spend a Short Rest handling one magic item and learns what it is (Identify without the spell).
func _study_row(ch: Character) -> void:
	var items: Array[String] = []
	for e in ch.inventory:
		var iid := str(e["id"])
		if int(e.get("qty", 0)) > 0 and MagicItems.can_identify(Compendium.shared().item_data(iid), e) and not iid in items:
			items.append(iid)
	if items.is_empty() or ch.dead:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiParts.caption("%s studies during the Short Rest:" % ch.name.get_slice(" ", 0), 12))
	var pick := OptionButton.new()
	pick.add_item("Nothing", 0)
	for i in items.size():
		var e2 := ch.entry_of(items[i])
		pick.add_item(MagicItems.display_name(Compendium.shared().item_data(items[i]), e2), i + 1)
		if str(_study.get(ch.id, "")) == items[i]:
			pick.select(i + 1)
	pick.tooltip_text = "Learn what the item is and how it works by the end of the rest (a curse stays hidden)."
	pick.item_selected.connect(func(idx: int) -> void:
		if idx <= 0:
			_study.erase(ch.id)
		else:
			_study[ch.id] = items[idx - 1])
	row.add_child(pick)
	_box.add_child(UiParts.row(row))


## Identifies what each character studied through the Short Rest: "" or a line for the log.
func _finish_study(rested: Array[Character]) -> String:
	var lines: Array[String] = []
	for ch in rested:
		var iid := str(_study.get(ch.id, ""))
		var e := ch.entry_of(iid)
		if iid == "" or e.is_empty():
			continue
		var data := Compendium.shared().item_data(iid)
		var seemed := MagicItems.display_name(data, e)
		var real := ch.identify(iid)
		lines.append("%s learns the %s is %s." % [ch.name.get_slice(" ", 0), seemed, "just what it seemed" if real == seemed else "really a %s" % real])
	_study.clear()
	return " ".join(lines)


## Heal up (docs/plans/ui_polish.md): every hurt character spends Hit Point Dice, largest first, while what they're
## missing is at least an average roll of that die (so little of a roll is wasted), then the screen reports it.
func heal_up() -> void:
	var lines: Array[String] = []
	for ch in st.party:
		var spent := 0
		var healed := 0
		var guard := 0
		while guard < 40:
			guard += 1
			var plan := _heal_plan(ch)
			if plan.is_empty():
				break
			healed += ch.spend_hit_die(Dice.roller, int(plan[0]))
			spent += 1
		if spent > 0:
			lines.append("%s spends %d %s and regains %d Hit Points." % [ch.name.get_slice(" ", 0), spent,
				"die" if spent == 1 else "dice", healed])
	_log.text = " ".join(lines) if not lines.is_empty() else "Nobody needs it."
	Audio.sfx("page")
	_draw()


## The dice `ch` would spend next for Heal up: [die] or [] when they're near enough full, out of dice, down or dead.
func _heal_plan(ch: Character) -> Array:
	if ch.dead or ch.hp <= 0 or ch.hp >= ch.max_hp():
		return []
	var missing := ch.max_hp() - ch.hp
	var hd := ch.hit_dice()
	var sizes: Array[int] = []
	for die: String in hd:
		var e := hd[die] as Dictionary
		if int(e["spent"]) < int(e["total"]):
			sizes.append(int(die))
	sizes.sort()
	sizes.reverse()
	for die in sizes:
		# An average roll of the die (what the character's sheet would show), at least 1.
		if float(missing) >= maxf(1.0, die / 2.0 + 0.5 + ch.ability_mod(&"con")):
			return [die]
	return []


func _spend(ch: Character, die: int) -> void:
	var healed := ch.spend_hit_die(Dice.roller, die)
	_log.text = "%s spends a d%d and regains %d Hit Points." % [ch.name, die, healed]
	_draw()


func _finish_short() -> void:
	Audio.sfx("rest")
	var denied: Array[String] = []
	var rested: Array[Character] = []
	for ch in st.party:
		if ch.dead:
			continue
		if ch.mists_deny_short_rest(Dice.roller, st.miles_since_long_rest):
			denied.append(ch.name)
			continue
		ch.finish_short_rest()
		rested.append(ch)
	for g in st.guests:
		if not g.dead:
			g.finish_short_rest()
	st.advance_minutes(60)
	_log.text = "An hour passes. Short-rest features are back."
	if not denied.is_empty():
		_log.text += " The Mists give %s no rest (Mist Walker)." % ", ".join(denied)
	var studied := _finish_study(rested)
	if studied != "":
		_log.text += " " + studied
	_narrate("rest:short")
	_short_done = true
	_draw()


func _long_rest(rule: String) -> void:
	Audio.sfx("rest")
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
		st.miles_since_long_rest = 0.0
		for ch in st.party:
			if not ch.dead:
				ch.finish_long_rest()
		for g in st.guests:
			if not g.dead:
				g.finish_long_rest()
		_log.text = "Eight hours pass. Everyone wakes rested, if not refreshed."
		var room := Services.after_long_rest(st)   # a room booked at the inn (F14)
		if room != "":
			_log.text += " " + room
		for line in RestCasts.after_long_rest(st.party, Dice.roller):
			_log.text += "\n" + line
		_narrate("rest:long")
		var region := str(Compendium.shared().get_entry("locations", st.location).get("region", ""))
		_narrate("dream:" + region)
		_long_done = true
		_prepared_before = PrepareScreen.snapshot(st)
		if root.has_method("strahd_after_rest"):
			root.call_deferred("strahd_after_rest", 8 * 60)   # Strahd may come in the night (ADR 0014)
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
		_log_card.visible = true


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
	row.add_child(UiParts.gap())
	var any := false
	for lvl in range(1, mini(5, budget) + 1):
		if ch.slots_used[lvl - 1] <= 0:
			continue
		any = true
		var l := lvl
		row.add_child(UiParts.small_button("Recover a level %d slot" % l, func() -> void:
			ch.slots_used[l - 1] -= 1
			var left := budget - l
			ch.set_meta("arcane_budget", left)
			_log.text = "%s recovers a level %d spell slot." % [ch.name, l]
			if left <= 0 or not _has_recoverable(ch, left):
				ch.spend_resource("arcane_recovery")
				ch.remove_meta("arcane_budget")
			_draw()))
	if not any:
		row.queue_free()
		return
	row.add_child(UiParts.small_button("Done", func() -> void:
		if ch.has_meta("arcane_budget"):
			ch.spend_resource("arcane_recovery")
			ch.remove_meta("arcane_budget")
		_draw()))
	_box.add_child(UiParts.row(row, Callable(), true))


static func _has_recoverable(ch: Character, budget: int) -> bool:
	for lvl in range(1, mini(5, budget) + 1):
		if ch.slots_used[lvl - 1] > 0:
			return true
	return false


## After a Long Rest, a companion with something on their mind asks for a word (CampTalk, narrative/camp/): a
## button per talk; choosing one closes the rest and starts the conversation.
func _camp_talks() -> void:
	if not _long_done or root == null or not root.has_method("start_dialogue"):
		return
	for talk in CampTalk.available(st):
		var ref := str(talk["ref"])
		var b := UiKit.button(str(talk["label"]), func() -> void:
			CampTalk.mark(st, ref)
			queue_free()
			root.call("start_dialogue", ref, ""), 15)
		UiParts.light_up(b)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(b)


func _slot_exchange_row(ch: Character) -> void:
	for option in ch.slot_conversion_options():
		var pick := option
		var button := UiParts.small_button("%s · %s: level %d slot → %d %s" % [ch.name, pick["label"], pick["slot"], pick["slot"], str(pick["resource"]).replace("_", " ")], func() -> void:
			if ch.convert_slot_to_resource(str(pick["feature"]), int(pick["slot"])):
				_draw())
		_box.add_child(button)
	if not _short_done:
		return
	for option in ch.slot_recovery_options():
		var pick := option
		var button := UiParts.small_button("%s · %s: %d %s → level %d slot" % [ch.name, pick["label"], pick["cost"], str(pick["resource"]).replace("_", " "), pick["slot"]], func() -> void:
			if ch.recover_slot_with_resource(str(pick["feature"]), int(pick["slot"])):
				_draw())
		_box.add_child(button)

func _exit_tree() -> void:
	if st != null:
		for ch in st.party:
			ch.close_slot_recovery()
