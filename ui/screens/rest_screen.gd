class_name RestScreen
extends CanvasLayer
## Short and Long Rests (plan §5.2, docs/ui/party_management.md pm_03). Short Rest: one hour; each character spends
## Hit Point Dice one at a time (roll + Con, minimum 1) and short-rest features come back. Long Rest: eight hours;
## everything comes back, with the location's interruption risk (LongRest). Rests need nobody hostile around (the
## screen can't open in combat). A Short Rest is taken anywhere else, a dungeon and a place that allows no sleep
## included, unless a fight here was begun and not won or foes are in plain view of the party (RestRules,
## LocationStealth.foes_in_sight); Hit Point Dice are spent only while one can be. A location can forbid sleeping
## ("rest": no, its `rest_text` saying why) or make it risky. A Long Rest also waits 16 hours after the last one and
## isn't taken in a dungeon or building while enemies remain in it (RestRules). Each card says why it can't be taken,
## in words, for the mouse and the pad alike, and the other stays open. Wherever the place's own rest is
## risky (the wild, the road, a town's streets, a house, a dungeon; CampSite.makes_camp, whatever the Story
## difficulty's safe rests) the Long Rest makes camp (F16, LocationCamp): the card pitches it, and while the party is
## camped it sleeps there or breaks camp. Where no square will take a fire, the party sleeps where it stands, here, and
## the log says so. A safe place (an inn, a house that takes the party in), a room booked for the night (Services), the
## tutorial and the magic items' rests keep the plain Long Rest.

var root: Node
var st: StoryState
var _box: VBoxContainer
var _log: Label
## Holds the Long Rest's card, built again when time passes (_refresh_long).
var _long_slot: VBoxContainer
var _rule := "risky"   ## the place's rest rule: safe, risky or no (after the Story difficulty's safe rests)
## Why a Short Rest can't be taken here now (RestRules.short_rest_refusals), one sentence each; [] when it can.
var _short_why: Array[String] = []
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
	# Nor while the region's truce holds: Strahd's dinner guests sleep unbothered under his roof (StoryConditions.TRUCES).
	if rule == "risky" and StoryConditions.truce_holds(str(loc.get("region", "")), st):
		rule = "safe"
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 12)
	_short_why = _short_refusals()
	var short := UiKit.button("Finish the Short Rest (1 hour)", _finish_short, 16, "rest")
	short.disabled = not _short_why.is_empty()
	short.tooltip_text = "\n".join(_short_why)
	kinds.add_child(_rest_card("Short Rest", "1 hour", "Spend Hit Point Dice to heal; some features come back.", short,
		"" if _short_why.is_empty() else "Not now", _short_why))
	_rule = rule
	_long_slot = VBoxContainer.new()
	_long_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kinds.add_child(_long_slot)
	_refresh_long()
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
	# The morning after a Long Rest (LongRest.morning_open): opened again after Strahd's night visit, or after a magic
	# item's rest from the inventory, the screen still offers the companions' words and the change of prepared spells,
	# counted from the list the night ended with.
	if LongRest.morning_open(st):
		_long_done = true
		_prepared_before = st.morning.get("prepared", {}) as Dictionary
	_draw()


## A rest's card: its name, how long it takes and how risky, what it gives, why it can't start now (each reason a line
## in words, read with the pad as with the mouse) and its button.
func _rest_card(title: String, length: String, text: String, button: Button, risk: String, why: Array[String] = []) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiParts.section(title))
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 8)
	facts.add_child(UiParts.pill(length, "moonlight", 13))
	if risk != "":
		facts.add_child(UiParts.pill(risk, "rose" if risk.begins_with("Dangerous") or not why.is_empty() else "bile", 13))
	col.add_child(facts)
	col.add_child(UiKit.label(text, 14, "vellum", 480))
	for line in why:
		col.add_child(UiKit.label(line, 14, "rose", 480))
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(button)
	var card := UiParts.card("ui_oxblood", "gilt_dark", 0.55, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(col)
	return card


## The Long Rest's card, built again when the clock moves (a Short Rest, a Long Rest): its button is off while
## RestRules refuses one here, and the card says why.
func _refresh_long() -> void:
	if _long_slot == null:
		return
	for c in _long_slot.get_children():
		c.queue_free()
	var why := RestRules.long_rest_refusals(st)
	var camp := _camp()
	var text := "All Hit Points, Hit Point Dice, spell slots and features come back."
	var label := "Take a Long Rest (8 hours)"
	var take := _long_rest.bind(_rule)
	if camp != null and not camp.slept:
		label = "Sleep by the fire (8 hours)"
		take = _sleep_at_camp
		text = "The party has made camp. " + text
	elif camp == null and _can_camp():
		label = "Make camp (8 hours)"
		take = _make_camp
		text = "Make camp here: a fire, a word with whoever wants one, then sleep. " + text
	var button := UiKit.button(label, take, 16, "rest")
	button.disabled = not why.is_empty()
	button.tooltip_text = "\n".join(why)
	var ward := Wards.keeps_rest(st)
	var risk := ("Not here" if _rule == "no" else "Not now") if not why.is_empty() else ("Safe here: %s" % ward if ward != "" else ("Dangerous here: it may be interrupted" if _rule == "risky" else "Safe here"))
	_long_slot.add_child(_rest_card("Long Rest", "8 hours", text, button, risk, why))
	if camp != null:
		var strike := UiKit.button("Break camp", _break_camp, 15)
		strike.tooltip_text = "Pack up and walk on."
		strike.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_long_slot.add_child(strike)


## Why a Short Rest can't be taken here now: a fight here begun and not won, or foes in plain view of the party.
func _short_refusals() -> Array[String]:
	var view := _view()
	var foes: Array[String] = []
	if view != null:
		foes = LocationStealth.foes_in_sight(view)
	return RestRules.short_rest_refusals(st, foes)


## The place the party is resting in, when the screen is open over the campaign itself: never the tutorial's practice
## ground or a capture's own party, where a Long Rest stays the plain one.
func _view() -> LocationView:
	if root == null or root.is_in_group("practice_ground") or st != GameState.story or not "view" in root:
		return null
	return root.get("view") as LocationView


func _camp() -> LocationCamp:
	return LocationCamp.of(_view())


## Whether a Long Rest here makes camp (F16): where the place's own rest is risky, unless a room is booked for the
## night here.
func _can_camp() -> bool:
	var view := _view()
	return view != null and not view.in_combat and Services.booked(st) == "" \
		and CampSite.makes_camp(Compendium.shared().get_entry("locations", st.location))


## Why the party sleeps on the screen when it meant to make camp.
const NO_ROOM := "No room to make camp here, so the party sleeps where it stands."


## Makes camp: the screen gives way to the camp, and the night is slept there (LocationCamp). Where no square the
## party can walk to will take a fire, the party sleeps here, where it stands, and the log says why.
func _make_camp() -> void:
	if not RestRules.long_rest_refusals(st).is_empty():
		return
	if LocationCamp.pitch(_view(), root, _rule) == null:
		_long_rest(_rule)
		_log.text = NO_ROOM + "\n" + _log.text
		_log_card.visible = true
		return
	_close()


func _sleep_at_camp() -> void:
	var camp := _camp()
	_close()
	if camp != null:
		camp.sleep()


func _break_camp() -> void:
	var camp := _camp()
	_close()
	if camp != null:
		camp.strike()


func _close() -> void:
	if root != null and root.has_method("close_screen") and root.get("screen") == self:
		root.call("close_screen")
	else:
		queue_free()


func _draw() -> void:
	_log_card.visible = _log.text != ""
	for c in _box.get_children():
		c.queue_free()
	if _long_done and not PrepareScreen.preparable(st).is_empty():
		var prep := UiKit.button("Change %s" % PrepareScreen.change_words(PrepareScreen.change_names(st)), func() -> void:
			var ps := PrepareScreen.new()
			ps.earlier = _prepared_before
			add_child(ps)
			ps.open(root, st, 0), 15, "spells")
		UiParts.light_up(prep)
		prep.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(prep)
	elif (_short_done or not RestRules.short_change(st).is_empty()) and not PrepareScreen.preparable(st, "short_rest").is_empty():
		# Stays on offer if the screen is closed and opened again, until the next rest, an hour or the party moving on.
		var swap := UiKit.button("Change %s" % PrepareScreen.change_words(PrepareScreen.change_names(st, "short_rest")), func() -> void:
			var ps2 := PrepareScreen.new()
			ps2.rest_kind = "short_rest"
			ps2.earlier = (RestRules.short_change(st).get("picks", {}) as Dictionary).duplicate(true)
			add_child(ps2)
			ps2.open(root, st, 0), 15)
		UiParts.light_up(swap)
		swap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(swap)
	if not _long_done and not PrepareScreen.preparable(st, PrepareScreen.ANYTIME).is_empty():
		# No rest needed (owner's house rule): the same spells, changed any time outside a fight.
		var any := UiKit.button("Prepare spells", func() -> void:
			var ps3 := PrepareScreen.new()
			ps3.rest_kind = PrepareScreen.ANYTIME
			add_child(ps3)
			ps3.open(root, st, 0), 15, "spells")
		any.tooltip_text = "Change which spells each caster has ready. No rest needed outside a fight."
		any.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_box.add_child(any)
	_camp_talks()
	# One click for the usual Short Rest chore: everyone hurt spends dice until a roll would mostly go to waste.
	var anyone := false
	for ch in st.party:
		anyone = anyone or not _heal_plan(ch).is_empty()
	if anyone:
		var heal := UiKit.button("Heal up with Hit Point Dice", heal_up, 15, "rest")
		heal.tooltip_text = "Each hurt character spends Hit Point Dice, largest first, until they're close to full or out of dice."
		if not _short_why.is_empty():
			heal.disabled = true
			heal.tooltip_text = "\n".join(_short_why)   # Hit Point Dice are spent in a Short Rest
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
			b.disabled = int(e2["spent"]) >= int(e2["total"]) or ch.hp >= ch.max_hp() or ch.dead or not _short_why.is_empty()
			b.tooltip_text = "Roll it and add your Constitution modifier (minimum 1)." if _short_why.is_empty() else "\n".join(_short_why)
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
	if not _short_why.is_empty():
		return
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
	if not _short_why.is_empty():
		return
	var healed := ch.spend_hit_die(Dice.roller, die)
	_log.text = "%s spends a d%d and regains %d Hit Points." % [ch.name, die, healed]
	_draw()


func _finish_short() -> void:
	# The card's button is off while one is refused; this keeps anything else that starts one to the same rules.
	_short_why = _short_refusals()
	if not _short_why.is_empty():
		_log.text = "No Short Rest now. " + " ".join(_short_why)
		_draw()
		return
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
		EncounterSetup.clear_fight_effects(ch)   # nothing from a fight outlasts a rest
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
	RestRules.note_short_rest(st, PrepareScreen.snapshot(st, "short_rest"))
	var short_line := PrepareScreen.available_line(st, "short_rest")
	if short_line != "":
		_log.text += " " + short_line
	_draw()
	_refresh_long()


func _long_rest(rule: String) -> void:
	# The card's button is off while one is refused; this keeps anything else that starts one to the same rules.
	var why := RestRules.long_rest_refusals(st)
	if not why.is_empty():
		_log.text = "No Long Rest now. " + " ".join(why)
		_draw()
		return
	Audio.sfx("rest")
	var res := LongRest.take(st, rule, Dice.roller)
	# Nothing comes at a party sleeping here that it could fight: the night is just broken (LongRest.restless).
	if str(res["how"]) == LongRest.DARK:
		res = LongRest.restless(st)
	_log.text = str(res["text"])
	if str(res["how"]) == LongRest.SLEPT:
		for line: String in res["lines"]:
			_log.text += "\n" + line
		_narrate("rest:long")
		var region := str(Compendium.shared().get_entry("locations", st.location).get("region", ""))
		_narrate("dream:" + region)
		_long_done = true
		_prepared_before = PrepareScreen.snapshot(st)
		st.morning["prepared"] = _prepared_before
		var long_line := PrepareScreen.available_line(st, "long_rest")
		if long_line != "":
			_log.text += "\n" + long_line
	if str(res["how"]) in [LongRest.SLEPT, LongRest.STRAHD] and root.has_method("visit_after_rest"):
		# Strahd may come in the night (ADR 0014): after this screen and any talk started from it. A visit that may
		# come to blows broke the rest before its benefits; it goes on once he's gone (game root).
		root.call_deferred("visit_after_rest", int(res["minutes"]))
	_short_why = _short_refusals()   # no Hit Point Dice while his visit waits (RestRules.BROKEN_NIGHT)
	_draw()
	_refresh_long()
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
## to at most half the Wizard level (rounded up; one more with an Arcane Grimoire), none of level 6 or higher. One button
## per slot level to recover.
func _arcane_recovery_row(ch: Character) -> void:
	var wiz := ch.class_level_of("wizard")
	if wiz <= 0 or not _short_done or ch.resource_left("arcane_recovery") <= 0 or ch.dead:
		return
	var budget := int(ch.get_meta("arcane_budget", ch.arcane_recovery_levels()))
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
	if not _long_done or root == null or not root.has_method("start_dialogue") or _camp() != null:
		return   # at camp, a word is had by walking up to whoever wants it
	for talk in CampTalk.available(st):
		var ref := str(talk["ref"])
		var b := UiKit.button(str(talk["label"]), func() -> void:
			CampTalk.mark(st, ref)
			_close()   # through the game's close_screen, so it doesn't keep a freed screen open
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
	# Closed with a word still waiting: the exploring screen says where to find it (it waits for the next rest otherwise).
	if _long_done and root != null and is_instance_valid(root) and root.is_inside_tree() and "hud" in root \
			and root.get("hud") is ExploreHud and _camp() == null:
		var hint := talk_hint(st)
		if hint != "":
			(root.get("hud") as ExploreHud).toast(hint)


## Where to hear a word a companion wants after a Long Rest ("Thistle wants a word: open Rest (R) to talk"), while the
## morning lasts (LongRest.morning_open); "" when nobody is waiting.
static func talk_hint(state: StoryState) -> String:
	if not LongRest.morning_open(state):
		return ""
	var talks := CampTalk.available(state)
	if talks.is_empty():
		return ""
	var who := str(talks[0]["label"]) if talks.size() == 1 else "%d companions want a word" % talks.size()
	return "%s: open Rest (%s) to talk" % [who, InputActions.key_text(&"rest")]


## What the Narrator says of the night just slept, for a rest taken somewhere other than this screen (a magic item's,
## from the inventory): the place's night (as _narrate picks it) and the region's dream, or "".
static func night_words(root_: Node, state: StoryState) -> String:
	var narrator := root_.get("narrator") as Narrator if root_ != null and "narrator" in root_ else null
	if narrator == null:
		return ""
	var loc := Compendium.shared().get_entry("locations", state.location)
	var region := str(loc.get("region", ""))
	var out: Array[String] = []
	for keys: Array in [["rest:long:" + state.location, "rest:long:" + region, "rest:long"], ["dream:" + region]]:
		for key: String in keys:
			var line := narrator.line(key, state, state.leader_character())
			if line != "":
				out.append(line)
				break
	return " ".join(out)
