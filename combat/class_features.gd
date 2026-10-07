class_name ClassFeatures
extends RefCounted
## The Phase 4 classes in a fight (2024 PHB, levels 1-7 and their subclasses to level 6-7): Barbarian (Rage,
## Reckless Attack, Instinctive Pounce; Berserker, Wild Heart, World Tree, Zealot), Monk (Martial Arts, Focus:
## Flurry of Blows, Patient Defense, Step of the Wind, Uncanny Metabolism, Deflect Attacks, Stunning Strike; Open
## Hand, Shadow, Elements, Mercy), Paladin (Lay On Hands, Channel Divinity, Aura of Protection and the Oath auras;
## Devotion, Glory, Ancients, Vengeance), Bard (Bardic Inspiration, Font of Inspiration, Countercharm; Lore, Valor,
## Glamour, Dance), Druid (Wild Shape, Wild Companion, Wild Resurgence, Elemental Fury; Land, Moon, Sea, Stars),
## Sorcerer (Innate Sorcery, Font of Magic, Sorcery Incarnate; Draconic, Wild Magic, Aberrant, Clockwork), Ranger
## (Hunter, Beast Master, Gloom Stalker, Fey Wanderer) and Warlock (invocations; Fiend, Archfey, Celestial, Great Old
## One). FeatureActions lists these actions and dispatches them here ("feat:cf:<id>"); the attack pipeline, the turn
## hooks and the reactions call the hooks below.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## A metadata name built from creature ids ("zombie#2"): only letters, digits and underscores are allowed.
static func meta_key(s: String) -> String:
	var out := ""
	for ch in s:
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" else "_"
	return out


static func has(c: Combatant, id: String) -> bool:
	return CombatFeatures.has_feature(c, id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c.creature is Character else null


static func level_of(c: Combatant, class_id: String) -> int:
	var ch := _ch(c)
	return ch.class_level_of(class_id) if ch != null else 0


## A choice the character made, by its key (Hunter's Prey, Elemental Fury...): the picks.
static func picks(c: Combatant, key: String) -> Array[String]:
	var out: Array[String] = []
	var ch := _ch(c)
	if ch == null:
		return out
	out.append_array(ch.picks_for(key))
	for cd in ch.choice_defs:
		if cd.key == key or cd.key.ends_with(key):
			for p: Variant in cd.picks:
				if not str(p) in out:
					out.append(str(p))
	return out


## Picks of a kind of choice (invocation, beast_form, metamagic).
static func picks_of_kind(c: Combatant, kind: String) -> Array[String]:
	var out: Array[String] = []
	var ch := _ch(c)
	if ch == null:
		return out
	for cd in ch.choice_defs:
		if cd.kind == kind:
			for p: Variant in cd.picks:
				out.append(str(p))
	return out


static func knows_invocation(c: Combatant, id: String) -> bool:
	return id in picks_of_kind(c, "invocation")


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:cf:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String, n: int = 1) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) >= n else "None left"


## A once-per-rest use the class data has no resource for: created on first need and spent through the character.
func _uses(c: Combatant, id: String, label: String, maximum: int, recharge: String) -> int:
	var ch := _ch(c)
	if ch == null:
		return 0
	if not ch.resources.has(id) or ch.resource_max(id) != maximum:
		ch.set_resource(id, label, maximum, recharge, label)
	return ch.resource_left(id)


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


func _once(c: Combatant, key: String) -> bool:
	var k := meta_key("once_%s" % key)
	if str(c.get_meta(k, "")) == _turn_key():
		return false
	c.set_meta(k, _turn_key())
	return true


func _timed(c: Combatant, name: String, source: String, ends: Effect.Ends, owner: Combatant) -> Effect:
	var fx := Effect.new(name, &"feature", source)
	fx.caster_id = c.id
	fx.ends = ends
	fx.turn_owner_id = owner.id
	if ends == Effect.Ends.END_OF_TURN:
		fx.skip_turn_ends = enc().own_turn_skip(owner)
	return fx


func _minutes(c: Combatant, name: String, source: String, minutes: int) -> Effect:
	var fx := Effect.new(name, &"feature", source)
	fx.caster_id = c.id
	fx.lasting({"kind": "minutes", "amount": minutes})
	fx.turn_owner_id = c.id
	return fx


static func martial_die(c: Combatant) -> int:
	var ch := _ch(c)
	if ch == null or ch.class_level_of("monk") <= 0:
		return 0
	var v: Variant = ch.class_column("monk", "martial_arts")
	var text := str(v) if v != null else "1d6"
	return int(text.get_slice("d", 1)) if text.contains("d") else 6


static func bardic_die(c: Combatant) -> int:
	var ch := _ch(c)
	if ch == null or ch.class_level_of("bard") <= 0:
		return 0
	var v: Variant = ch.class_column("bard", "bardic_die")
	var text := str(v) if v != null else "d6"
	return int(text.substr(1)) if text.begins_with("d") else 6


static func rage_bonus(c: Combatant) -> int:
	var ch := _ch(c)
	if ch == null or ch.class_level_of("barbarian") <= 0:
		return 0
	var v: Variant = ch.class_column("barbarian", "rage_damage")
	return int(str(v).replace("+", "")) if v != null else 2


static func raging(c: Combatant) -> bool:
	return c.creature.has_flag("raging")


func _spell_dc(c: Combatant, class_id: String) -> int:
	var ch := _ch(c)
	if ch == null or ch.spellcasting_entry(class_id).is_empty():
		return 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis")
	return ch.spell_save_dc(class_id).total()


func _save(t: Combatant, ab: StringName, dc: int, label: String, cond: String = "") -> bool:
	var e := enc()
	var keys: Array[String] = []
	if cond != "":
		keys.append("save_vs:%s" % cond)
	var sv := t.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()], keys)
	e.log.add("info", "%s %s the %s save" % [t.name(), "succeeds on" if sv.success else "fails", label], t.id, [sv.describe()])
	return sv.success


func _heal(c: Combatant, t: Combatant, amount: int, label: String) -> int:
	var e := enc()
	var got := t.creature.heal(amount, label)
	if got > 0 and t.creature.hp > 0:
		t.creature.remove_condition(&"unconscious", "0 Hit Points")
	e.log.add("heal", "%s: %s regains %d Hit Points" % [label, t.name(), got], c.id)
	e.events.append({"type": "heal", "id": t.id, "amount": got})
	return got


func _temp(t: Combatant, amount: int, label: String) -> void:
	var e := enc()
	if amount > 0 and t.creature.add_temp_hp(amount, label):
		e.log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [t.name(), amount, label], t.id)


# --- The hotbar -------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var tw := e._turn_check(c)
	_barbarian(c, ch, out, aw, bw, tw)
	_monk(c, ch, out, aw, bw)
	_paladin(c, ch, out, aw, bw)
	_bard(c, ch, out, aw, bw, tw)
	_druid(c, ch, out, aw, bw, tw)
	_sorcerer(c, ch, out, aw, bw, tw)
	_ranger(c, ch, out, aw, bw)
	_warlock(c, ch, out, aw, bw)
	_riding(c, out, tw)


## Mounting and dismounting (2024 Mounted Combat): half your Speed either way.
func _riding(c: Combatant, out: Array[Dictionary], tw: String) -> void:
	var e := enc()
	if e.mount_of(c) != null:
		out.append(_entry("dismount", "Dismount", "half your Speed", "movement", _first(tw, "" if c.movement_left >= c.speed() / 2 else "Needs half your Speed"), "none",
			"Get down from %s into a space within 5 ft of it." % e.mount_of(c).name()))
		return
	for o in e.allies_of(c):
		if o != c and e.distance(c, o) <= 5 and Creature.SIZES.find(o.creature.size) > Creature.SIZES.find(c.creature.size) and e.rider_of(o) == null:
			out.append(_entry("mount:" + o.id, "Mount %s" % o.name(), "half your Speed", "movement", _first(tw, e.mount_why(c, o)), "none",
				"Climb onto %s: you share its space and it carries you as a controlled mount (it can then only Dash, Disengage or Dodge)." % o.name()))


func _barbarian(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String, tw: String) -> void:
	if not has(c, "rage"):
		return
	if not raging(c):
		var rw := _first(bw, _res_why(c, "rage"))
		if rw == "" and str(ch.armor_situation().get("armor", "")) == "heavy":
			rw = "Not in Heavy armor"
		if ch.subclasses.get("barbarian", "") == "path_of_the_wild_heart" and has(c, "rage_of_the_wilds"):
			for animal: String in ["bear", "eagle", "wolf"]:
				out.append(_entry("rage:" + animal, "Rage (%s)" % animal.capitalize(), "+%d damage · resist B/P/S" % rage_bonus(c), "bonus", rw, "none",
					{"bear": "Rage of the Bear: Resistance to every damage type but Force, Necrotic, Psychic and Radiant.",
					"eagle": "Rage of the Eagle: Dash and Disengage as part of entering the Rage, and as a Bonus Action while raging.",
					"wolf": "Rage of the Wolf: allies have Advantage on melee attacks against enemies within 5 ft of you."}[animal]))
		else:
			out.append(_entry("rage", "Rage", "+%d damage · resist B/P/S" % rage_bonus(c), "bonus", rw, "none",
				"Bonus Action: Resistance to Bludgeoning, Piercing and Slashing, +%d damage on Strength attacks, Advantage on Strength checks and saves. No spells or Concentration." % rage_bonus(c)))
	else:
		out.append(_entry("extend_rage", "Keep Raging", "Bonus Action", "bonus", bw, "none", "Bonus Action: keep your Rage going through the end of your next turn."))
		if c.has_meta("rage_animal") and str(c.get_meta("rage_animal")) == "eagle":
			out.append(_entry("eagle_dash", "Eagle: Dash and Disengage", "Bonus Action", "bonus", bw, "none", "Rage of the Eagle: Dash and Disengage as one Bonus Action."))
		if has(c, "warrior_of_the_gods") and ch.resource_left("warrior_of_the_gods") > 0:
			pass
	if has(c, "reckless_attack") and not c.took_attack_action and not c.creature.has_flag("reckless"):
		out.append(_entry("reckless_attack", "Reckless Attack", "Advantage on Strength attacks", "free", tw, "none",
			"On your first attack this turn: Advantage on attack rolls with Strength until the start of your next turn, but attacks against you have Advantage too."))
	if has(c, "zealous_presence"):
		var zw := bw
		if zw == "" and _uses(c, "zealous_presence", "Zealous Presence", 1, "long") <= 0 and ch.resource_left("rage") <= 0:
			zw = "Used (or spend a Rage)"
		out.append(_entry("zealous_presence", "Zealous Presence", "allies: Advantage", "bonus", zw, "none",
			"Bonus Action: up to ten allies within 60 ft gain Advantage on attack rolls and saves until the start of your next turn."))
	if has(c, "warrior_of_the_gods") and ch.resource_left("warrior_of_the_gods") > 0:
		out.append(_entry("warrior_of_the_gods", "Warrior of the Gods", "%d d12 left" % ch.resource_left("warrior_of_the_gods"), "bonus", bw, "none",
			"Bonus Action: roll d12s from the pool (as many as you need) and regain that many Hit Points."))


func _monk(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String) -> void:
	if not has(c, "martial_arts"):
		return
	var die := martial_die(c)
	var fw := _res_why(c, "focus_points")
	if _monk_unarmored(ch):
		out.append(_entry("martial_arts_strike", "Martial Arts: Unarmed Strike", "1d%d" % die, "bonus", bw, "enemy", "Bonus Action: one Unarmed Strike.", 5))
	if has(c, "flurry_of_blows"):
		var n := 3 if has(c, "heightened_focus") else 2
		out.append(_entry("flurry_of_blows", "Flurry of Blows", "%d strikes · 1 Focus" % n, "bonus", _first(bw, fw), "enemy", "Bonus Action, 1 Focus Point: %d Unarmed Strikes." % n, 5))
	if has(c, "patient_defense"):
		out.append(_entry("patient_defense", "Patient Defense", "Disengage", "bonus", bw, "none", "Bonus Action: Disengage."))
		out.append(_entry("patient_defense_focus", "Patient Defense (Focus)", "Disengage + Dodge · 1 Focus", "bonus", _first(bw, fw), "none", "Bonus Action, 1 Focus Point: Disengage and Dodge."))
	if has(c, "step_of_the_wind"):
		# Fleet Step (Open Hand 11): after another Bonus Action, Step of the Wind right away.
		var fleet := has(c, "fleet_step") and str(c.get_meta("fleet_step", "")) == _turn_key()
		var sbw := "" if fleet else bw
		out.append(_entry("step_of_the_wind", "Step of the Wind", "Dash" + (" (Fleet Step)" if fleet else ""), "bonus", sbw, "none", "Bonus Action: Dash."))
		out.append(_entry("step_of_the_wind_focus", "Step of the Wind (Focus)", "Dash + Disengage · 1 Focus", "bonus", _first(bw, fw), "none", "Bonus Action, 1 Focus Point: Disengage and Dash, and your jumps double."))
	match ch.subclasses.get("monk", ""):
		"warrior_of_the_open_hand":
			if has(c, "wholeness_of_body"):
				var uw := "" if _uses(c, "wholeness_of_body", "Wholeness of Body", maxi(1, c.creature.ability_mod(&"wis")), "long") > 0 else "None left"
				out.append(_entry("wholeness_of_body", "Wholeness of Body", "1d%d + %d" % [die, c.creature.ability_mod(&"wis")], "bonus", _first(bw, uw), "none", "Bonus Action: regain a Martial Arts die + Wisdom Hit Points."))
		"warrior_of_shadow":
			if has(c, "improved_shadow_step"):
				out.append(_entry("improved_shadow_step", "Shadow Step (anywhere)", "60 ft + strike · 1 Focus", "bonus", _first(bw, fw), "point",
					"Bonus Action, 1 Focus Point: teleport up to 60 ft from and to anywhere, then make an Unarmed Strike.", 60))
			if has(c, "shadow_arts"):
				out.append(_entry("shadow_arts", "Shadow Arts: Darkness", "1 Focus", "action", _first(aw, fw), "point", "Magic action, 1 Focus Point: cast Darkness without a slot; you can see through it.", 60))
			if has(c, "shadow_step"):
				var sw := bw
				if sw == "" and not enc().light_at(c.cell) in ["dim", "dark", "magic_dark"]:
					sw = "Start in Dim Light or Darkness"
				out.append(_entry("shadow_step", "Shadow Step", "teleport 60 ft", "bonus", sw, "point", "Bonus Action: teleport from Dim Light or Darkness to another such space within 60 ft; Advantage on your next melee attack this turn.", 60))
		"warrior_of_the_elements":
			if has(c, "elemental_attunement") and not c.creature.has_flag("elemental_attunement"):
				out.append(_entry("elemental_attunement", "Elemental Attunement", "10 min · 1 Focus", "free", _first(enc()._turn_check(c), fw), "none",
					"1 Focus Point: for 10 minutes your reach grows by 10 ft and your strikes can deal elemental damage and push or pull 10 ft."))
			if has(c, "elemental_burst"):
				out.append(_entry("elemental_burst", "Elemental Burst", "%dd%d · 2 Focus" % [3, die], "action", _first(aw, _res_why(c, "focus_points", 2)), "point",
					"Magic action, 2 Focus Points: a 20-ft-radius Sphere within 120 ft, Dex save for three Martial Arts dice of an element, half on a success.", 120))
		"warrior_of_mercy":
			if has(c, "flurry_of_healing_and_harm"):
				var fhw := _first(bw, fw)
				if fhw == "" and _uses(c, "flurry_of_healing_and_harm", "Flurry of Healing and Harm", maxi(1, c.creature.ability_mod(&"wis")), "long") <= 0:
					fhw = "None left"
				out.append(_entry("flurry_of_healing", "Flurry of Healing", "heal %d creatures · 1 Focus" % (3 if has(c, "heightened_focus") else 2), "bonus", fhw, "ally",
					"Bonus Action, 1 Focus Point: Flurry of Blows with Hand of Healing in place of each strike (free).", 5))
			if has(c, "hand_of_healing"):
				out.append(_entry("hand_of_healing", "Hand of Healing", "1d%d + %d · 1 Focus" % [die, c.creature.ability_mod(&"wis")], "action", _first(aw, fw), "ally",
					"Magic action, 1 Focus Point: a creature you touch regains a Martial Arts die + Wisdom Hit Points.", 5))


static func _monk_unarmored(ch: Character) -> bool:
	return ch.equipped("armor").is_empty() and not str(ch.equipped("off_hand").get("category", "")) == "shield"


func _paladin(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String) -> void:
	if has(c, "lay_on_hands"):
		var lw := _first(bw, _res_why(c, "lay_on_hands"))
		var loh := _entry("lay_on_hands", "Lay On Hands", "%d in the pool" % ch.resource_left("lay_on_hands"), "bonus", lw, "ally",
			"Bonus Action: touch a creature and restore Hit Points from the pool, as many as you choose (right-click for an amount; a plain click heals what it needs); or spend 5 to end Poisoned.", 5)
		loh["choices"] = lay_on_hands_choices(ch.resource_left("lay_on_hands"))
		loh["choice_label"] = "How much"
		out.append(loh)
	var cw := _res_why(c, "paladin_channel_divinity")
	match ch.subclasses.get("paladin", ""):
		"oath_of_devotion":
			if has(c, "sacred_weapon") and not c.creature.has_flag("sacred_weapon"):
				out.append(_entry("sacred_weapon", "Sacred Weapon", "+%d to hit · 10 min" % maxi(1, c.creature.ability_mod(&"cha")), "free", _first(enc()._turn_check(c), cw), "none",
					"When you take the Attack action, Channel Divinity: for 10 minutes add your Charisma modifier to attack rolls with melee weapons, which deal Radiant if you like and shed light."))
		"oath_of_the_ancients":
			if has(c, "natures_wrath"):
				out.append(_entry("natures_wrath", "Nature's Wrath", "Str save · 15 ft", "action", _first(aw, cw), "none",
					"Magic action, Channel Divinity: creatures of your choice within 15 ft make a Strength save or are Restrained for 1 minute (repeating the save each turn)."))
		"oath_of_vengeance":
			if has(c, "vow_of_enmity"):
				out.append(_entry("vow_of_enmity", "Vow of Enmity", "Advantage vs one foe", "free", _first(enc()._turn_check(c), cw), "enemy",
					"When you take the Attack action, Channel Divinity: Advantage on attack rolls against a creature within 30 ft for 1 minute.", 30))
				# The vowed foe dropped before the minute was up: the vow moves to another creature, no action needed.
				if vow_can_move(c):
					out.append(_entry("vow_move", "Move Vow of Enmity", "free · the vowed foe is down", "free", "", "enemy",
						"Your vowed foe dropped to 0 Hit Points: move the vow to another creature within 30 ft for the rest of its minute (no action).", 30))
		"oath_of_glory":
			pass
	if has(c, "abjure_foes"):
		out.append(_entry("abjure_foes", "Abjure Foes", "Wis save · 60 ft", "action", _first(aw, cw), "none",
			"Magic action, Channel Divinity: up to %d creatures within 60 ft make a Wisdom save or are Frightened for 1 minute (or until damaged), able only to move, act or take a Bonus Action each turn." % maxi(1, c.creature.ability_mod(&"cha"))))
	match ch.subclasses.get("paladin", ""):
		"oath_of_glory":
			if has(c, "peerless_athlete"):
				out.append(_entry("peerless_athlete", "Peerless Athlete", "1 hour", "bonus", _first(bw, cw), "none",
					"Bonus Action, Channel Divinity: Advantage on Athletics and Acrobatics checks and longer jumps for 1 hour."))


func _bard(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String, tw: String) -> void:
	if not has(c, "bardic_inspiration"):
		return
	var die := bardic_die(c)
	var iw := _res_why(c, "bardic_inspiration")
	out.append(_entry("bardic_inspiration", "Bardic Inspiration", "d%d" % die, "bonus", _first(bw, iw), "ally",
		"Bonus Action: a creature within 60 ft (not you) gains a d%d it can add to a D20 Test it fails within the next hour." % die, 60))
	if has(c, "font_of_inspiration") and ch.resource_left("bardic_inspiration") < ch.resource_max("bardic_inspiration"):
		var slot := _lowest_slot(ch)
		out.append(_entry("font_of_inspiration", "Font of Inspiration", "a level %d slot → 1 use" % slot, "free", _first(tw, "" if slot > 0 else "No spell slots"), "none",
			"Expend a spell slot (no action required) to regain a use of Bardic Inspiration."))
	match ch.subclasses.get("bard", ""):
		"college_of_glamour":
			if has(c, "mantle_of_majesty"):
				var active := c.creature.has_flag("mantle_of_majesty")
				var mw := bw
				if mw == "" and not active and _uses(c, "mantle_of_majesty", "Mantle of Majesty", 1, "long") <= 0 and _lowest_slot(ch) < 3:
					mw = "Used (or a level 3 slot)"
				out.append(_entry("mantle_of_majesty", "Mantle of Majesty: Command" if active else "Mantle of Majesty", "Command, no slot", "bonus", mw, "enemy",
					"Bonus Action: cast Command without a slot; for 1 minute you can do so again each turn.", 60))
			if has(c, "mantle_of_inspiration"):
				out.append(_entry("mantle_of_inspiration", "Mantle of Inspiration", "temp HP to allies", "bonus", _first(bw, iw), "none",
					"Bonus Action, Bardic Inspiration: up to Charisma-modifier creatures within 60 ft gain twice the die in Temporary Hit Points and can move without provoking."))
		"college_of_dance":
			if c.has_meta("agile_strike") and str(c.get_meta("agile_strike")) == _turn_key():
				out.append(_entry("agile_strike", "Agile Strikes", "Unarmed Strike", "free", tw, "enemy", "Expending Bardic Inspiration lets you make one Unarmed Strike.", 5))


static func _lowest_slot(ch: Character) -> int:
	for l in range(1, 10):
		if ch.slots_left(l) > 0:
			return l
	return 0


func _druid(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String, tw: String) -> void:
	if has(c, "wild_shape"):
		var shaped := enc().shapes.is_shaped(c)
		if not shaped:
			var ww := _first(bw, _res_why(c, "wild_shape"))
			for f in wild_forms(c):
				out.append(_entry("wild_shape:" + str(f["id"]), "Wild Shape: %s" % f.get("name", ""), "CR %s" % str(f.get("cr", 0)), "bonus", ww, "none",
					"Bonus Action: become a %s for up to %d hours, keeping your mind and gaining %d Temporary Hit Points." % [f.get("name", ""), maxi(1, level_of(c, "druid") / 2), _wild_temp(c)]))
		if has(c, "wild_companion"):
			var cw := aw
			if cw == "" and ch.resource_left("wild_shape") <= 0 and _lowest_slot(ch) == 0:
				cw = "No Wild Shape use or spell slot"
			out.append(_entry("wild_companion", "Wild Companion", "a Fey familiar", "action", cw, "place",
				"Magic action: spend a Wild Shape use (or a spell slot) to cast Find Familiar; the familiar is Fey and vanishes at your next Long Rest.", 10))
		if has(c, "wild_resurgence"):
			if ch.resource_left("wild_shape") <= 0 and _lowest_slot(ch) > 0:
				out.append(_entry("wild_resurgence", "Wild Resurgence", "a slot → Wild Shape", "free", tw, "none", "Once on each of your turns, spend a spell slot to regain a Wild Shape use."))
			if ch.resource_left("wild_shape") > 0 and _uses(c, "wild_resurgence_slot", "Wild Resurgence", 1, "long") > 0:
				out.append(_entry("wild_resurgence_slot", "Wild Resurgence: level 1 slot", "spend Wild Shape", "free", tw, "none", "Once per Long Rest, spend a Wild Shape use to regain a level 1 spell slot."))
	if has(c, "moonlight_step"):
		var mw := bw
		if mw == "" and ch.resource_left("moonlight_step") <= 0 and _uses(c, "moonlight_step", "Moonlight Step", maxi(1, c.creature.ability_mod(&"wis")), "long") <= 0:
			mw = "None left (restore one with a level 2+ slot)"
		out.append(_entry("moonlight_step", "Moonlight Step", "teleport 30 ft", "bonus", mw, "point",
			"Bonus Action: teleport up to 30 ft in a flash of moonlight; Advantage on your next attack this turn.", 30))
	# Starry Form (Circle of the Stars) and Lands' Aid / Wrath of the Sea spend Wild Shape uses too.
	match ch.subclasses.get("druid", ""):
		"circle_of_the_land":
			if has(c, "lands_aid"):
				out.append(_entry("lands_aid", "Land's Aid", "2d6 Necrotic · heal 2d6", "action", _first(aw, _res_why(c, "wild_shape")), "point",
					"Magic action, a Wild Shape use: a 10-ft-radius Sphere within 60 ft: creatures of your choice make a Con save (2d6 Necrotic, half on a success); one creature there regains 2d6 Hit Points.", 60))
		"circle_of_the_sea":
			if has(c, "wrath_of_the_sea"):
				if not c.creature.has_flag("wrath_of_the_sea"):
					out.append(_entry("wrath_of_the_sea", "Wrath of the Sea", "10 min", "bonus", _first(bw, _res_why(c, "wild_shape")), "none",
						"Bonus Action, a Wild Shape use: an Emanation of ocean spray (5 ft) for 10 minutes; a creature in it makes a Con save or takes Cold damage and is pushed."))
				else:
					out.append(_entry("wrath_strike", "Wrath of the Sea: lash", "%dd6 Cold" % maxi(1, c.creature.ability_mod(&"wis")), "bonus", bw, "enemy",
						"Bonus Action: a creature in the spray makes a Constitution save or takes Wisdom-modifier d6 Cold damage and is pushed 15 ft.", 10 if has(c, "aquatic_affinity") else 5))
		"circle_of_the_stars":
			if has(c, "starry_form") and not c.creature.has_flag("starry_form"):
				for form: String in ["archer", "chalice", "dragon"]:
					out.append(_entry("starry_form:" + form, "Starry Form: %s" % form.capitalize(), "10 min", "bonus", _first(bw, _res_why(c, "wild_shape")), "none",
						{"archer": "Bonus Action: a ranged spell attack (60 ft) for 1d8 + Wisdom Radiant now and as a Bonus Action each turn.",
						"chalice": "When you cast a healing spell with a slot, you or a creature within 30 ft regains 1d8 + Wisdom more.",
						"dragon": "Intelligence and Wisdom checks and Constitution saves to keep Concentration treat a 9 or lower as a 10."}[form]))
			if c.creature.has_flag("starry_archer"):
				out.append(_entry("starry_arrow", "Luminous Arrow", "1d8 + %d Radiant" % c.creature.ability_mod(&"wis"), "bonus", bw, "enemy", "Bonus Action: a ranged spell attack.", 60))


## The Beasts this druid can become now: known forms (or the bestiary's) up to its Challenge Rating limit.
func wild_forms(c: Combatant) -> Array[Dictionary]:
	var ch := _ch(c)
	var lvl := ch.class_level_of("druid")
	var max_cr := float(ch.class_column("druid", "max_form_cr")) if ch.class_column("druid", "max_form_cr") != null else 0.25
	if has(c, "circle_forms"):
		max_cr = maxf(1.0, floorf(lvl / 3.0))
	var known := picks_of_kind(c, "beast_form")
	var out: Array[Dictionary] = []
	for f in ShapeChange.beast_forms(max_cr):
		if known.is_empty() or str(f["id"]) in known:
			if float(f.get("cr", 0)) <= max_cr and not ((f.get("speed", {}) as Dictionary).has("fly") and not bool(ch.class_column("druid", "forms_fly"))):
				out.append(f)
	return out


func _wild_temp(c: Combatant) -> int:
	var lvl := level_of(c, "druid")
	return lvl * 3 if has(c, "circle_forms") else lvl


func _sorcerer(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String, tw: String) -> void:
	if has(c, "innate_sorcery") and not c.creature.has_flag("innate_sorcery"):
		var iw := _res_why(c, "innate_sorcery")
		if iw != "" and has(c, "sorcery_incarnate") and ch.resource_left("sorcery_points") >= 2:
			iw = ""
		out.append(_entry("innate_sorcery", "Innate Sorcery", "1 min", "bonus", _first(bw, iw), "none",
			"Bonus Action: for 1 minute your Sorcerer spells' save DC is 1 higher and you have Advantage on their attack rolls."))
	if has(c, "font_of_magic"):
		var pts := ch.resource_left("sorcery_points")
		for lvl in range(1, 6):
			var cost := int({1: 2, 2: 3, 3: 5, 4: 6, 5: 7}[lvl])
			if lvl > _max_slot_level(ch):
				break
			out.append(_entry("create_slot:%d" % lvl, "Create a level %d slot" % lvl, "%d Sorcery Points" % cost, "bonus", _first(bw, "" if pts >= cost else "Not enough Sorcery Points"), "none",
				"Bonus Action: turn Sorcery Points into a spell slot (it vanishes on a Long Rest)."))
		var low := _lowest_slot(ch)
		if low > 0:
			out.append(_entry("slot_to_points:%d" % low, "Level %d slot → %d points" % [low, low], "Font of Magic", "free", tw, "none", "Expend a spell slot to gain Sorcery Points equal to its level."))
	match ch.subclasses.get("sorcerer", ""):
		"wild_magic_sorcery":
			if has(c, "tides_of_chaos") and not "tides_of_chaos" in c.armed:
				out.append(_entry("tides_of_chaos", "Tides of Chaos", "Advantage on a D20 Test", "free", _first(tw, "" if _uses(c, "tides_of_chaos", "Tides of Chaos", 1, "long") > 0 else "Used"), "none",
					"Advantage on your next D20 Test; your next Sorcerer spell with a slot then surges."))
		"clockwork_sorcery":
			if has(c, "bastion_of_law"):
				out.append(_entry("bastion_of_law", "Bastion of Law", "ward of d8s", "action", _first(aw, _res_why(c, "sorcery_points")), "ally",
					"Magic action: spend 1-5 Sorcery Points to give a creature within 30 ft a ward of that many d8s that soak damage.", 30))


static func _max_slot_level(ch: Character) -> int:
	var best := 0
	for l in range(1, 10):
		if ch.spell_slots()[l - 1] > 0:
			best = l
	return best


func _ranger(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String) -> void:
	if ch.class_level_of("ranger") <= 0:
		return
	if has(c, "tireless"):
		out.append(_entry("tireless", "Tireless", "1d8 + %d temp HP" % c.creature.ability_mod(&"wis"), "action",
			_first(aw, "" if _uses(c, "tireless", "Tireless", maxi(1, c.creature.ability_mod(&"wis")), "long") > 0 else "None left"), "none", "Magic action: gain 1d8 + Wisdom Temporary Hit Points."))
	if ch.subclasses.get("ranger", "") == "beast_master" and has(c, "primal_companion"):
		var beast := _companion(c)
		if beast == null:
			for kind: String in ["land", "sea", "sky"]:
				out.append(_entry("primal_companion:" + kind, "Primal Companion: Beast of the %s" % kind.capitalize(), "summon", "action", aw, "place",
					"Magic action: call your primal beast to a space within 5 ft (it returns on a Long Rest, or by spending a slot).", 10))
		else:
			out.append(_entry("command_beast", "Command: Beast's Strike", beast.name(), "bonus", bw, "enemy",
				"Bonus Action: your beast makes its Beast's Strike against a creature (it otherwise only Dodges).", 120))


func _familiar(c: Combatant) -> Combatant:
	var e := enc()
	for sid: Variant in e.spells.summoned.get(c.id, []):
		var s := e.get_c(str(sid))
		if s != null and s.is_alive() and s.creature is Monster and bool((s.creature as Monster).data.get("chain", false)):
			return s
	return null


func e_attack_why(c: Combatant) -> String:
	return enc().features_attack_why(c)


func _companion(c: Combatant) -> Combatant:
	var e := enc()
	for sid: Variant in e.spells.summoned.get(c.id, []):
		var s := e.get_c(str(sid))
		if s != null and s.is_alive() and s.creature is Monster and bool((s.creature as Monster).data.get("primal_companion", false)):
			return s
	return null


func _warlock(c: Combatant, ch: Character, out: Array[Dictionary], aw: String, bw: String) -> void:
	if ch.class_level_of("warlock") <= 0:
		return
	if has(c, "awakened_mind"):
		var cw := ""
		if has(c, "clairvoyant_combatant") and _uses(c, "clairvoyant_combatant", "Clairvoyant Combatant", 1, "short") <= 0 and int(ch.pact_magic()["left"]) <= 0:
			cw = " (no Clairvoyant Combatant left)"
		out.append(_entry("awakened_mind", "Awakened Mind", "telepathic link" + ("; Wis save" if has(c, "clairvoyant_combatant") and cw == "" else ""), "bonus", bw, "creature",
			"Bonus Action: link minds with a creature within 30 ft.%s" % (" Clairvoyant Combatant: it makes a Wisdom save or has Disadvantage on attacks against you while you have Advantage against it." if has(c, "clairvoyant_combatant") else ""), 30))
	var fam := _familiar(c)
	if fam != null and (knows_invocation(c, "pact_of_the_chain") or has(c, "necromancy_familiar")):
		var fw := e_attack_why(c)
		out.append(_entry("familiar_strike", "Familiar Strike", "%s attacks" % fam.name(), "attack", _first(fw, "" if enc().spells.can_react(fam) else "The familiar's Reaction is used"), "enemy",
			"Give up one of your attacks: your familiar makes one attack with its Reaction.", 120))
		if knows_invocation(c, "investment_of_the_chain_master"):
			out.append(_entry("command_familiar", "Command Familiar", "%s attacks" % fam.name(), "bonus", bw, "enemy",
				"Bonus Action (Investment of the Chain Master): your familiar takes the Attack action.", 120))
	if knows_invocation(c, "gaze_of_two_minds"):
		out.append(_entry("gaze_of_two_minds", "Gaze of Two Minds", "cast from an ally's space", "bonus", bw, "ally",
			"Bonus Action: touch a willing creature; until the end of your next turn you can cast spells as though you were in its space.", 5))
	if knows_invocation(c, "pact_of_the_blade") and not c.has_meta("pact_weapon"):
		out.append(_entry("pact_of_the_blade", "Pact of the Blade", "bond your weapon", "bonus", bw, "none",
			"Bonus Action: bond with the weapon in your hand: it's your pact weapon, you use Charisma for its attacks and it can deal Necrotic, Psychic or Radiant damage."))
	match ch.subclasses.get("warlock", ""):
		"celestial_patron":
			if has(c, "healing_light"):
				out.append(_entry("healing_light", "Healing Light", "%d d6 left" % ch.resource_left("healing_light"), "bonus", _first(bw, _res_why(c, "healing_light")), "ally",
					"Bonus Action: spend up to Charisma-modifier dice from the pool to heal a creature within 60 ft.", 60))


# --- Using them -------------------------------------------------------------------------------------------

func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var head := id.get_slice(":", 0)
	var arg := id.get_slice(":", 1) if id.contains(":") else ""
	var r := CombatResult.new()
	var restriction := e.feature_actions.movement_restriction(c, id)
	if restriction != "":
		return CombatResult.fail(restriction)
	match head:
		"rage":
			return _start_rage(c, arg)
		"mount":
			return e.mount(c, e.get_c(id.substr(6)))
		"dismount":
			return e.dismount(c)
		"extend_rage":
			c.bonus_available = false
			c.set_meta("rage_kept", _turn_key())
			e.log.add("info", "%s keeps raging" % c.name(), c.id)
		"eagle_dash":
			c.bonus_available = false
			c.disengaged = true
			c.movement_left += c.speed()
			e.log.add("info", "%s Dashes and Disengages (Rage of the Eagle)" % c.name(), c.id)
		"reckless_attack":
			var fx := _timed(c, "Reckless Attack", "reckless_attack", Effect.Ends.START_OF_TURN, c).with_modifier("flag", {"value": "reckless"}).with_modifier("attacked_with", {"value": "advantage"})
			c.creature.add_effect(fx)
			e.log.add("info", "%s attacks recklessly" % c.name(), c.id)
		"warrior_of_the_gods":
			c.bonus_available = false
			var missing := c.creature.max_hp() - c.creature.hp
			var n := clampi(ceili(missing / 6.5), 1, ch.resource_left("warrior_of_the_gods"))
			ch.spend_resource("warrior_of_the_gods", n)
			var rolled := e.heal_roll("%dd12" % n, c, "Warrior of the Gods")
			_heal(c, c, int(rolled["total"]), "Warrior of the Gods")
		"martial_arts_strike":
			return _unarmed(c, t, "Martial Arts", true)
		"flurry_of_blows":
			ch.spend_resource("focus_points")
			c.bonus_available = false
			c.set_meta("flurry_turn", _turn_key())
			var n2 := 3 if has(c, "heightened_focus") else 2
			e.log.add("info", "%s unleashes a Flurry of Blows" % c.name(), c.id)
			for i in n2:
				if t == null or not t.is_alive() or t.is_down():
					break
				var sub := _unarmed(c, t, "Flurry of Blows", false)
				if e.pending != null:
					return sub
			c.remove_meta("flurry_turn")
		"patient_defense", "patient_defense_focus":
			c.bonus_available = false
			c.disengaged = true
			if head == "patient_defense_focus":
				ch.spend_resource("focus_points")
				var dg := _timed(c, "Dodging", "dodge", Effect.Ends.START_OF_TURN, c).with_modifier("attacked_with", {"value": "disadvantage"}).with_modifier("advantage", {"on": "save:dex"})
				dg.ends_when_incapacitated = true
				c.creature.add_effect(dg)
				if has(c, "heightened_focus"):
					var rolled2 := e._roll_damage_dice("2d%d" % martial_die(c), false, 0, "Patient Defense")
					_temp(c, int(rolled2["total"]), "Patient Defense")
			e.log.add("info", "%s takes Patient Defense" % c.name(), c.id)
		"step_of_the_wind", "step_of_the_wind_focus":
			c.bonus_available = false
			c.remove_meta("fleet_step")
			c.movement_left += c.speed()
			if head == "step_of_the_wind_focus":
				ch.spend_resource("focus_points")
				c.disengaged = true
			e.log.add("info", "%s moves like the wind (Step of the Wind)" % c.name(), c.id)
		"wholeness_of_body":
			c.bonus_available = false
			ch.spend_resource("wholeness_of_body")
			_heal(c, c, maxi(e.dice.roll_one(martial_die(c), "Wholeness of Body"), e.heal_floor(c)) + c.creature.ability_mod(&"wis"), "Wholeness of Body")
		"shadow_arts":
			ch.spend_resource("focus_points")
			c.action_available = false
			c.magic_action_used = true
			return e.spells.cast_free(c, "darkness", [], point if point != Vector2.INF else Vector2(cell) + Vector2(0.5, 0.5), {})
		"shadow_step":
			if cell.x < 0 or e.occupant_at(cell) != null or not e.light_at(cell) in ["dim", "dark", "magic_dark"]:
				return CombatResult.fail("Choose an empty square in Dim Light or Darkness")
			if e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > 60:
				return CombatResult.fail("At most 60 ft")
			c.bonus_available = false
			e.spells._teleport(c, cell, r)
			e.add_mark({"kind": "advantage_next_attack", "attacker": c.id, "source": "Shadow Step", "expires_owner": c.id, "expires_phase": "end", "consume": true})
		"elemental_attunement":
			ch.spend_resource("focus_points")
			var fx2 := _minutes(c, "Elemental Attunement", "elemental_attunement", 10).with_modifier("flag", {"value": "elemental_attunement"}).with_modifier("reach", {"value": 10})
			# Stride of the Elements (Elements 11): fly and swim at your Speed while attuned.
			if has(c, "stride_of_the_elements"):
				fx2.modifiers.append(Modifier.of("speed_set", {"kind": "fly", "value": c.creature.speed().total()}, "Stride of the Elements", &"feature"))
				fx2.modifiers.append(Modifier.of("speed_set", {"kind": "swim", "value": c.creature.speed().total()}, "Stride of the Elements", &"feature"))
			c.creature.add_effect(fx2)
			e.log.add("info", "%s attunes to the elements" % c.name(), c.id)
		"elemental_burst":
			return _elemental_burst(c, point if point != Vector2.INF else Vector2(cell) + Vector2(0.5, 0.5))
		"hand_of_healing":
			if t == null or e.distance(c, t) > 5:
				return CombatResult.fail("Touch a creature within 5 ft")
			ch.spend_resource("focus_points")
			e.spend_action(c)
			c.magic_action_used = true
			_heal(c, t, maxi(e.dice.roll_one(martial_die(c), "Hand of Healing"), e.heal_floor(t)) + c.creature.ability_mod(&"wis"), "Hand of Healing")
			if has(c, "physicians_touch"):
				for cond: StringName in [&"poisoned", &"blinded", &"deafened", &"paralyzed", &"stunned"]:
					if t.creature.has_condition(cond):
						e.spells.cure(t, cond)
						e.log.add("heal", "%s is no longer %s (Physician's Touch)" % [t.name(), str(cond).capitalize()], t.id)
						break
		"lay_on_hands":
			return _lay_on_hands(c, t, arg)
		"sacred_weapon":
			ch.spend_resource("paladin_channel_divinity")
			var sw := _minutes(c, "Sacred Weapon", "sacred_weapon", 10).with_modifier("flag", {"value": "sacred_weapon"})
			sw.modifiers.append(Modifier.of("attack", {"value": maxi(1, c.creature.ability_mod(&"cha")), "when": {"weapon": "melee"}}, "Sacred Weapon", &"feature"))
			c.creature.add_effect(sw)
			e.log.add("info", "%s's weapon blazes with holy light (Sacred Weapon)" % c.name(), c.id)
		"natures_wrath":
			ch.spend_resource("paladin_channel_divinity")
			e.spend_action(c)
			c.magic_action_used = true
			var dc := _spell_dc(c, "paladin")
			for o in e.hostiles_of(c):
				if o.is_down() or e.distance(c, o) > 15:
					continue
				if not _save(o, &"str", dc, "Nature's Wrath", "restrained"):
					var nw := _minutes(c, "Restrained (Nature's Wrath)", "natures_wrath", 1).with_condition(&"restrained")
					nw.turn_owner_id = o.id
					nw.repeat_save = {"ability": "str", "dc": dc, "when": "end"}
					o.creature.add_effect(nw)
		"vow_of_enmity":
			if t == null or e.distance(c, t) > 30:
				return CombatResult.fail("Choose a creature within 30 ft")
			ch.spend_resource("paladin_channel_divinity")
			for old: Effect in c.creature.effects.duplicate():
				if old.source_id == "vow_of_enmity":
					c.creature.remove_effect(old)
			var vow := _minutes(c, "Vow of Enmity", "vow_of_enmity", 1)
			var cid := c.id
			vow.on_end = func() -> void: end_vow(cid)
			c.creature.add_effect(vow)
			_vow_on(c, t)
			e.log.add("info", "%s swears a Vow of Enmity against %s" % [c.name(), t.name()], c.id)
		"vow_move":
			if not vow_can_move(c):
				return CombatResult.fail("The vowed foe is still standing")
			if t == null or e.distance(c, t) > 30:
				return CombatResult.fail("Choose a creature within 30 ft")
			_vow_on(c, t)
			e.log.add("info", "%s turns the Vow of Enmity on %s" % [c.name(), t.name()], c.id)
		"peerless_athlete":
			ch.spend_resource("paladin_channel_divinity")
			c.bonus_available = false
			var pa := _minutes(c, "Peerless Athlete", "peerless_athlete", 60).with_modifier("advantage", {"on": "check:athletics"}).with_modifier("advantage", {"on": "check:acrobatics"})
			c.creature.add_effect(pa)
		"bardic_inspiration":
			if t == null or t == c or e.distance(c, t) > 60:
				return CombatResult.fail("Choose another creature within 60 ft")
			ch.spend_resource("bardic_inspiration")
			c.bonus_available = false
			give_inspiration(c, t)
			if has(c, "dazzling_footwork"):
				c.set_meta("agile_strike", _turn_key())
		"font_of_inspiration":
			var slot := _lowest_slot(ch)
			ch.expend_slot(slot)
			_refund(ch, "bardic_inspiration")
			e.log.add("info", "%s turns a level %d slot into Bardic Inspiration" % [c.name(), slot], c.id)
		"mantle_of_inspiration":
			ch.spend_resource("bardic_inspiration")
			c.bonus_available = false
			var die := bardic_die(c)
			var roll := e.dice.roll_one(die, "Mantle of Inspiration")
			var n3 := maxi(1, c.creature.ability_mod(&"cha"))
			for a in e.allies_of(c):
				if n3 <= 0:
					break
				if a.is_alive() and e.distance(c, a) <= 60:
					_temp(a, roll * 2, "Mantle of Inspiration")
					n3 -= 1
		"wild_shape":
			return _wild_shape(c, arg)
		"revert_shape":
			c.bonus_available = false
			e.shapes.revert(c, "it chose to")
		"wild_companion":
			if ch.resource_left("wild_shape") > 0:
				ch.spend_resource("wild_shape")
			else:
				ch.expend_slot(_lowest_slot(ch))
			e.spend_action(c)
			c.magic_action_used = true
			return e.spells.cast_free(c, "find_familiar", [], point if point != Vector2.INF else Vector2(cell) + Vector2(0.5, 0.5), {"cell": cell})
		"wild_resurgence":
			ch.expend_slot(_lowest_slot(ch))
			_refund(ch, "wild_shape")
			c.set_meta("once_wild_resurgence", _turn_key())
			e.log.add("info", "%s trades a spell slot for Wild Shape" % c.name(), c.id)
		"wild_resurgence_slot":
			ch.spend_resource("wild_shape")
			ch.spend_resource("wild_resurgence_slot")
			if ch.slots_used[0] > 0:
				ch.slots_used[0] -= 1
			e.log.add("info", "%s trades Wild Shape for a level 1 slot" % c.name(), c.id)
		"lands_aid":
			return _lands_aid(c, point if point != Vector2.INF else Vector2(cell) + Vector2(0.5, 0.5))
		"wrath_of_the_sea":
			ch.spend_resource("wild_shape")
			c.bonus_available = false
			var wfx := _minutes(c, "Wrath of the Sea", "wrath_of_the_sea", 10).with_modifier("flag", {"value": "wrath_of_the_sea"})
			# Stormborn (Sea 10): fly at your Speed and resist Cold, Lightning and Thunder.
			if has(c, "stormborn"):
				wfx.modifiers.append(Modifier.of("speed_set", {"kind": "fly", "value": c.creature.speed().total()}, "Stormborn", &"feature"))
				for ty: String in ["cold", "lightning", "thunder"]:
					wfx.modifiers.append(Modifier.of("resistance", {"value": ty}, "Stormborn", &"feature"))
			c.creature.add_effect(wfx)
			e.log.add("info", "Ocean spray swirls around %s" % c.name(), c.id)
			var near := _nearest_foe(c, 10 if has(c, "aquatic_affinity") else 5)
			if near != null:
				_wrath_lash(c, near)
		"wrath_strike":
			if t == null:
				return CombatResult.fail("Choose a creature in the spray")
			c.bonus_available = false
			_wrath_lash(c, t)
		"starry_form":
			ch.spend_resource("wild_shape")
			c.bonus_available = false
			var sf := _minutes(c, "Starry Form: %s" % arg.capitalize(), "starry_form", 10).with_modifier("flag", {"value": "starry_form"}).with_modifier("flag", {"value": "starry_" + arg})
			if has(c, "full_of_stars"):
				for ty: String in ["bludgeoning", "piercing", "slashing"]:
					sf.modifiers.append(Modifier.of("resistance", {"value": ty}, "Full of Stars", &"feature"))
			c.creature.add_effect(sf)
			e.events.append({"type": "condition", "id": c.id})
			e.log.add("info", "%s takes on a starry form: the %s" % [c.name(), arg.capitalize()], c.id)
			if arg == "archer":
				c.bonus_available = true
				var tgt := _nearest_foe(c, 60)
				var res := CombatResult.new()
				if tgt != null:
					res = _luminous_arrow(c, tgt)
				c.bonus_available = false
				return res
		"starry_arrow":
			c.bonus_available = false
			return _luminous_arrow(c, t)
		"zealous_presence":
			if ch.resource_left("zealous_presence") > 0:
				ch.spend_resource("zealous_presence")
			else:
				ch.spend_resource("rage")
			c.bonus_available = false
			var n := 0
			for a in e.allies_of(c):
				if a == c or n >= 10 or e.distance(c, a) > 60 or not a.is_alive():
					continue
				n += 1
				var zp := _timed(c, "Zealous Presence", "zealous_presence", Effect.Ends.START_OF_TURN, c).with_modifier("advantage", {"on": "attack"}).with_modifier("advantage", {"on": "save:all"})
				a.creature.add_effect(zp)
			e.log.add("info", "%s lets out a divine battle cry (Zealous Presence)" % c.name(), c.id)
		"abjure_foes":
			ch.spend_resource("paladin_channel_divinity")
			e.spend_action(c)
			c.magic_action_used = true
			var left := maxi(1, c.creature.ability_mod(&"cha"))
			var dc := _spell_dc(c, "paladin")
			for o in e.hostiles_of(c):
				if left <= 0:
					break
				if o.is_down() or e.distance(c, o) > 60 or not e.can_see(c, o):
					continue
				left -= 1
				if not _save(o, &"wis", dc, "Abjure Foes", "frightened"):
					var af := _minutes(c, "Frightened (Abjure Foes)", "abjure_foes", 1).with_condition(&"frightened").with_modifier("flag", {"value": "dazed"})
					af.turn_owner_id = o.id
					af.ends_on_damage = true
					o.creature.add_effect(af)
					e.events.append({"type": "condition", "id": o.id})
		"moonlight_step":
			if cell.x < 0 or e.occupant_at(cell) != null or e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > 30:
				return CombatResult.fail("Choose an empty square within 30 ft")
			ch.spend_resource("moonlight_step")
			c.bonus_available = false
			e.spells._teleport(c, cell, r)
			e.add_mark({"kind": "advantage_next_attack", "attacker": c.id, "source": "Moonlight Step", "expires_owner": c.id, "expires_phase": "end", "consume": true})
		"improved_shadow_step":
			if cell.x < 0 or e.occupant_at(cell) != null or e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > 60:
				return CombatResult.fail("Choose an empty square within 60 ft")
			ch.spend_resource("focus_points")
			c.bonus_available = false
			e.spells._teleport(c, cell, r)
			e.add_mark({"kind": "advantage_next_attack", "attacker": c.id, "source": "Shadow Step", "expires_owner": c.id, "expires_phase": "end", "consume": true})
			var foe := _nearest_foe(c, 5)
			if foe != null:
				return _unarmed(c, foe, "Improved Shadow Step", false)
		"flurry_of_healing":
			if t == null or e.distance(c, t) > 5:
				return CombatResult.fail("Touch a creature within 5 ft")
			ch.spend_resource("focus_points")
			ch.spend_resource("flurry_of_healing_and_harm")
			c.bonus_available = false
			for i in (3 if has(c, "heightened_focus") else 2):
				_heal(c, t, maxi(e.dice.roll_one(martial_die(c), "Hand of Healing"), e.heal_floor(t)) + c.creature.ability_mod(&"wis"), "Flurry of Healing")
		"tides_of_chaos":
			ch.spend_resource("tides_of_chaos")
			c.armed.append("tides_of_chaos")
			c.set_meta("tides_used", true)
			e.log.add("info", "%s calls on the Tides of Chaos" % c.name(), c.id)
		"agile_strike":
			c.remove_meta("agile_strike")
			var keep := c.bonus_available
			var res := _unarmed(c, t, "Agile Strikes", false)
			c.bonus_available = keep
			return res
		"mantle_of_majesty":
			if t == null:
				return CombatResult.fail("Choose a creature")
			if not c.creature.has_flag("mantle_of_majesty"):
				if ch.resource_left("mantle_of_majesty") > 0:
					ch.spend_resource("mantle_of_majesty")
				else:
					ch.expend_slot(maxi(3, _lowest_slot(ch)))
				c.creature.add_effect(_minutes(c, "Mantle of Majesty", "mantle_of_majesty", 1).with_modifier("flag", {"value": "mantle_of_majesty"}))
			c.bonus_available = false
			var word := "grovel" if Creature.SIZES.find(t.creature.size) <= Creature.SIZES.find(&"large") else "halt"
			return e.spells.cast_free(c, "command", [t], Vector2.INF, {"choice": word, "word": word, "no_concentration": true})
		"innate_sorcery":
			if ch.resource_left("innate_sorcery") > 0:
				ch.spend_resource("innate_sorcery")
			else:
				ch.spend_resource("sorcery_points", 2)
			c.bonus_available = false
			var inn := _minutes(c, "Innate Sorcery", "innate_sorcery", 1).with_modifier("flag", {"value": "innate_sorcery"})
			inn.modifiers.append(Modifier.of("spell_dc", {"value": 1}, "Innate Sorcery", &"feature"))
			inn.modifiers.append(Modifier.of("advantage", {"on": "attack:spell"}, "Innate Sorcery", &"feature"))
			c.creature.add_effect(inn)
			e.log.add("info", "Raw magic surges through %s (Innate Sorcery)" % c.name(), c.id)
		"create_slot":
			var lvl := int(arg)
			var cost := int({1: 2, 2: 3, 3: 5, 4: 6, 5: 7}[lvl])
			ch.spend_resource("sorcery_points", cost)
			c.bonus_available = false
			if ch.slots_used[lvl - 1] > 0:
				ch.slots_used[lvl - 1] -= 1
			e.log.add("info", "%s shapes a level %d spell slot from Sorcery Points" % [c.name(), lvl], c.id)
		"slot_to_points":
			var lvl2 := int(arg)
			ch.expend_slot(lvl2)
			for i in lvl2:
				_refund(ch, "sorcery_points")
			e.log.add("info", "%s melts a level %d slot into Sorcery Points" % [c.name(), lvl2], c.id)
		"bastion_of_law":
			if t == null or e.distance(c, t) > 30:
				return CombatResult.fail("Choose a creature within 30 ft")
			var pts := mini(5, ch.resource_left("sorcery_points"))
			ch.spend_resource("sorcery_points", pts)
			e.spend_action(c)
			c.magic_action_used = true
			t.set_meta("bastion_dice", pts)
			e.log.add("info", "%s wards %s with %d d8s (Bastion of Law)" % [c.name(), t.name(), pts], c.id)
		"tireless":
			ch.spend_resource("tireless")
			e.spend_action(c)
			c.magic_action_used = true
			_temp(c, e.dice.roll_one(8, "Tireless") + c.creature.ability_mod(&"wis"), "Tireless")
		"primal_companion":
			e.spend_action(c)
			c.magic_action_used = true
			return _call_companion(c, arg, cell)
		"command_beast":
			var beast := _companion(c)
			if beast == null or t == null:
				return CombatResult.fail("Choose a target for your beast")
			c.bonus_available = false
			beast.set_meta("commanded", _turn_key())
			var opt := e.option_by_id(beast, "monster:beasts_strike")
			if e.attack_legal(beast, t, opt) != "":
				return CombatResult.fail(e.attack_legal(beast, t, opt))
			e.log.add("info", "%s commands %s to strike" % [c.name(), beast.name()], c.id)
			var res := e._resolve_attack(beast, t, opt, {})
			# Bestial Fury (Beast Master 11): the Beast's Strike twice.
			if has(c, "bestial_fury") and e.pending == null and t.is_alive() and not t.is_down():
				return e._resolve_attack(beast, t, opt, {})
			return res
		"pact_of_the_blade":
			var wid := str(ch.equipped("main_hand").get("id", ""))
			if wid == "":
				return CombatResult.fail("Hold the weapon to bond with")
			c.bonus_available = false
			c.set_meta("pact_weapon", wid)
			var pact := Effect.new("Pact Weapon", &"feature", "pact_of_the_blade")
			pact.ends = Effect.Ends.LONG_REST
			pact.stack_key = "feature:pact_weapon"
			pact.modifiers.append(Modifier.of("weapon_override", {"items": [wid], "ability": "cha"}, "Pact of the Blade", &"feature"))
			if knows_invocation(c, "thirsting_blade"):
				pact.modifiers.append(Modifier.of("attacks_per_action", {"value": 3 if knows_invocation(c, "devouring_blade") else 2}, "Thirsting Blade", &"feature"))
			c.creature.add_effect(pact)
			e.log.add("info", "%s bonds with a pact weapon" % c.name(), c.id)
		"familiar_strike", "command_familiar":
			var famc := _familiar(c)
			if famc == null or t == null:
				return CombatResult.fail("Choose a target for your familiar")
			var best := {}
			for o in e.attack_options(famc):
				if e.attack_legal(famc, t, o) == "":
					best = o
					break
			if best.is_empty():
				return CombatResult.fail("Your familiar can't reach %s" % t.name())
			if head == "familiar_strike":
				e.use_one_attack(c)
				famc.reaction_available = false
			else:
				c.bonus_available = false
			e.log.add("info", "%s's familiar strikes at %s" % [c.name(), t.name()], c.id)
			return e._resolve_attack(famc, t, best, {"chain": true, "reaction": head == "familiar_strike"})
		"awakened_mind":
			if t == null or t == c or e.distance(c, t) > 30 or not e.can_see(c, t):
				return CombatResult.fail("Choose a creature you can see within 30 ft")
			c.bonus_available = false
			c.set_meta("mind_link", t.id)
			e.log.add("info", "%s links minds with %s (Awakened Mind)" % [c.name(), t.name()], c.id)
			if has(c, "clairvoyant_combatant") and c.hostile_to(t):
				var paid := false
				if ch.resource_left("clairvoyant_combatant") > 0:
					ch.spend_resource("clairvoyant_combatant")
					paid = true
				elif int(ch.pact_magic()["left"]) > 0:
					ch.pact_slots_used = int(ch.pact_magic()["used"]) + 1
					paid = true
				if paid and not _save(t, &"wis", _spell_dc(c, "warlock"), "Clairvoyant Combatant"):
					c.set_meta("clairvoyant_vs", t.id)
					e.log.add("info", "%s reads %s's every move (Clairvoyant Combatant)" % [c.name(), t.name()], c.id)
		"gaze_of_two_minds":
			if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 5:
				return CombatResult.fail("Touch a willing ally")
			c.bonus_available = false
			c.set_meta("gaze_link", [t.id, e.round_no + 1, c.id])
			e.log.add("info", "%s sees through %s's eyes (Gaze of Two Minds)" % [c.name(), t.name()], c.id)
		"healing_light":
			if t == null or e.distance(c, t) > 60:
				return CombatResult.fail("Choose a creature within 60 ft")
			c.bonus_available = false
			var missing := t.creature.max_hp() - t.creature.hp
			var n4 := clampi(ceili(missing / 3.5), 1, mini(maxi(1, c.creature.ability_mod(&"cha")), ch.resource_left("healing_light")))
			ch.spend_resource("healing_light", n4)
			var rolled3 := e.heal_roll("%dd6" % n4, t, "Healing Light")
			_heal(c, t, int(rolled3["total"]), "Healing Light")
		_:
			return CombatResult.fail("Not available")
	if has(c, "fleet_step") and not c.bonus_available and not head.begins_with("step_of_the_wind"):
		c.set_meta("fleet_step", _turn_key())
	e._check_over()
	return r


static func _refund(ch: Character, res: String) -> void:
	if ch.resources.has(res):
		var d := ch.resources[res] as Dictionary
		d["used"] = maxi(0, int(d["used"]) - 1)


func _nearest_foe(c: Combatant, within: int) -> Combatant:
	var e := enc()
	var best: Combatant = null
	var bd := 1 << 30
	for o in e.hostiles_of(c):
		var d := e.distance(c, o)
		if not o.is_down() and d <= within and d < bd:
			bd = d
			best = o
	return best


# --- Barbarian ---------------------------------------------------------------------------------------------

func _start_rage(c: Combatant, animal: String) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	ch.spend_resource("rage")
	c.bonus_available = false
	var fx := Effect.new("Rage", &"feature", "rage")
	fx.caster_id = c.id
	fx.ends = Effect.Ends.NEVER
	fx.ends_when_incapacitated = true
	fx.stack_key = "feature:rage"
	for ty: String in ["bludgeoning", "piercing", "slashing"]:
		fx.modifiers.append(Modifier.of("resistance", {"value": ty}, "Rage", &"feature"))
	fx.modifiers.append(Modifier.of("advantage", {"on": "check:str"}, "Rage", &"feature"))
	fx.modifiers.append(Modifier.of("advantage", {"on": "save:str"}, "Rage", &"feature"))
	fx.modifiers.append(Modifier.of("flag", {"value": "raging"}, "Rage", &"feature"))
	fx.modifiers.append(Modifier.of("flag", {"value": "cant_cast"}, "Rage", &"feature"))
	if animal == "bear":
		for ty2: String in ["acid", "cold", "fire", "lightning", "poison", "thunder"]:
			fx.modifiers.append(Modifier.of("resistance", {"value": ty2}, "Rage of the Bear", &"feature"))
	if has(c, "mindless_rage"):
		for cond: String in ["charmed", "frightened"]:
			fx.modifiers.append(Modifier.of("condition_immunity", {"value": cond}, "Mindless Rage", &"feature"))
			e.spells.cure(c, StringName(cond))
	c.creature.add_effect(fx)
	c.set_meta("rage_effect", true)
	if animal != "":
		c.set_meta("rage_animal", animal)
	c.set_meta("rage_kept", _turn_key())
	c.remove_meta("fanatical_used")
	if c.creature.concentration != null:
		c.creature.concentration.end("raging")
	e.events.append({"type": "condition", "id": c.id})
	e.log.add("info", "%s flies into a Rage%s" % [c.name(), (" (%s)" % animal.capitalize()) if animal != "" else ""], c.id)
	if animal == "eagle":
		if e.can_disengage(c):
			c.disengaged = true
		if not c.creature.has_flag("cannot_dash"):
			c.movement_left += c.speed()
	if has(c, "instinctive_pounce"):
		c.movement_left += c.speed() / 2
	if has(c, "vitality_of_the_tree"):
		_temp(c, level_of(c, "barbarian"), "Vitality Surge")
	return CombatResult.new()


func end_rage(c: Combatant, why: String) -> void:
	c.remove_meta("rage_effect")
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "rage":
			c.creature.remove_effect(fx)
	c.remove_meta("rage_animal")
	enc().events.append({"type": "condition", "id": c.id})
	enc().log.add("info", "%s's Rage ends (%s)" % [c.name(), why], c.id)


## An attack roll against an enemy, or a save it forced: the Rage carries on.
func kept_rage(c: Combatant) -> void:
	if raging(c):
		c.set_meta("rage_kept", _turn_key())


# --- Monk ------------------------------------------------------------------------------------------------

func _unarmed(c: Combatant, t: Combatant, label: String, spend_bonus: bool) -> CombatResult:
	var e := enc()
	if t == null:
		return CombatResult.fail("Choose a target")
	var opt := e.option_by_id(c, "weapon:unarmed_strike")
	if opt.is_empty():
		return CombatResult.fail("No Unarmed Strike")
	var why := e.attack_legal(c, t, opt)
	if why != "":
		return CombatResult.fail(why)
	if spend_bonus:
		c.bonus_available = false
	e.log.add("info", "%s strikes (%s)" % [c.name(), label], c.id)
	return e._resolve_attack(c, t, opt, {})


func _elemental_burst(c: Combatant, point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if (point - e.center_of(c)).length() * 5 > 120:
		return CombatResult.fail("At most 120 ft")
	ch.spend_resource("focus_points", 2)
	e.spend_action(c)
	c.magic_action_used = true
	var cells := e.grid.area_cells("sphere", 20, point)
	e.events.append({"type": "spell", "caster": c.id, "spell": "elemental_burst", "cells": cells, "targets": []})
	var die := martial_die(c)
	var rolled := e._roll_damage_dice("3d%d" % die, false, 0, "Elemental Burst")
	var dc := 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis")
	for o in e.spells.creatures_in(cells):
		var ok := _save(o, &"dex", dc, "Elemental Burst")
		var amt := int(rolled["total"]) / 2 if ok else int(rolled["total"])
		if amt > 0:
			e.deal_damage(c, o, [{"amount": amt, "type": "fire"}], false, "Elemental Burst", [str(rolled["text"])])
	return CombatResult.new()


# --- Paladin -----------------------------------------------------------------------------------------------

## The amounts offered for Lay On Hands (any number from the pool, 2024): 1 to 5, then steps of 5, the whole pool,
## and 5 points to end Poisoned.
static func lay_on_hands_choices(pool: int) -> Array:
	var out: Array = []
	var amounts: Array[int] = []
	for n in range(1, mini(5, pool) + 1):
		amounts.append(n)
	for n2 in range(10, pool + 1, 5):
		amounts.append(n2)
	if pool > 0 and not pool in amounts:
		amounts.append(pool)
	for n3 in amounts:
		out.append({"label": "Heal %d" % n3, "value": str(n3)})
	if pool >= 5:
		out.append({"label": "End Poisoned (5)", "value": "poison"})
	return out


## Lay On Hands: `amount` "" heals what the target needs (up to the pool), a number heals that many, "poison" spends
## 5 to end Poisoned.
func _lay_on_hands(c: Combatant, t: Combatant, amount: String = "") -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if t == null or e.distance(c, t) > 5:
		return CombatResult.fail("Touch a creature within 5 ft")
	var pool := ch.resource_left("lay_on_hands")
	if amount == "poison":
		if pool < 5:
			return CombatResult.fail("Needs 5 points in the pool")
		if not t.creature.has_condition(&"poisoned"):
			return CombatResult.fail("%s isn't Poisoned" % t.name())
		c.bonus_available = false
		ch.spend_resource("lay_on_hands", 5)
		e.spells.cure(t, &"poisoned")
		e.log.add("heal", "%s purges the poison from %s (Lay On Hands)" % [c.name(), t.name()], c.id)
		return CombatResult.new()
	if amount.is_valid_int():
		var want := clampi(int(amount), 1, pool)
		if want > pool or pool <= 0:
			return CombatResult.fail("Only %d left in the pool" % pool)
		c.bonus_available = false
		ch.spend_resource("lay_on_hands", want)
		_heal(c, t, want, "Lay On Hands")
		return CombatResult.new()
	c.bonus_available = false
	if t.creature.has_condition(&"poisoned") and pool >= 5 and t.creature.hp >= t.creature.max_hp() / 2:
		ch.spend_resource("lay_on_hands", 5)
		e.spells.cure(t, &"poisoned")
		e.log.add("heal", "%s purges the poison from %s (Lay On Hands)" % [c.name(), t.name()], c.id)
		return CombatResult.new()
	var need := mini(pool, t.creature.max_hp() - t.creature.hp)
	if need <= 0:
		return CombatResult.fail("%s is unhurt" % t.name())
	ch.spend_resource("lay_on_hands", need)
	_heal(c, t, need, "Lay On Hands")
	return CombatResult.new()


# --- Bard ----------------------------------------------------------------------------------------------

func give_inspiration(c: Combatant, t: Combatant) -> void:
	var e := enc()
	var die := bardic_die(c)
	var fx := Effect.new("Bardic Inspiration (d%d)" % die, &"feature", "bardic_inspiration")
	fx.caster_id = c.id
	fx.lasting({"kind": "hours", "amount": 1})
	fx.turn_owner_id = c.id
	fx.stack_key = "feature:bardic_inspiration"
	fx.modifiers.append(Modifier.of("inspiration_die", {"dice": "1d%d" % die}, "Bardic Inspiration", &"feature"))
	if has(c, "combat_inspiration"):
		fx.data = {"valor": true, "die": die}
	t.creature.add_effect(fx)
	e.log.add("info", "%s inspires %s (d%d)" % [c.name(), t.name(), die], c.id)
	e.events.append({"type": "condition", "id": t.id})


# --- Druid ----------------------------------------------------------------------------------------------

func _wild_shape(c: Combatant, form_id: String) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var form := {}
	for f in wild_forms(c):
		if str(f["id"]) == form_id:
			form = f
	if form.is_empty():
		return CombatResult.fail("You don't know that form")
	ch.spend_resource("wild_shape")
	c.bonus_available = false
	var opts := {"temp_hp": _wild_temp(c), "keep_mind": true, "label": "Wild Shape"}
	if has(c, "circle_forms"):
		opts["ac_floor"] = 13 + c.creature.ability_mod(&"wis")
	if c.creature.concentration == null:
		pass
	var m := e.shapes.transform(c, form, opts)
	if has(c, "improved_circle_forms"):
		m.add_effect(Effect.new("Improved Circle Forms", &"feature", "improved_circle_forms").with_modifier("save", {"ability": "con", "value": maxi(0, ch.ability_mod(&"wis"))}))
	return CombatResult.new()


func _lands_aid(c: Combatant, point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if (point - e.center_of(c)).length() * 5 > 60:
		return CombatResult.fail("At most 60 ft")
	ch.spend_resource("wild_shape")
	e.spend_action(c)
	c.magic_action_used = true
	var cells := e.grid.area_cells("sphere", 10, point)
	e.events.append({"type": "spell", "caster": c.id, "spell": "lands_aid", "cells": cells, "targets": []})
	var dc := _spell_dc(c, "druid")
	var rolled := e._roll_damage_dice("2d6", false, 0, "Land's Aid")
	var friend: Combatant = null
	for o in e.spells.creatures_in(cells):
		if c.hostile_to(o):
			var ok := _save(o, &"con", dc, "Land's Aid")
			var amt := int(rolled["total"]) / 2 if ok else int(rolled["total"])
			e.deal_damage(c, o, [{"amount": amt, "type": "necrotic"}], false, "Land's Aid", [str(rolled["text"])])
		elif friend == null or o.creature.hp < friend.creature.hp:
			friend = o
	if friend != null:
		_heal(c, friend, int(e.heal_roll("2d6", friend, "Land's Aid healing")["total"]), "Land's Aid")
	return CombatResult.new()


func _wrath_lash(c: Combatant, t: Combatant) -> void:
	var e := enc()
	var reach := 10 if has(c, "aquatic_affinity") else 5
	if e.distance(c, t) > reach:
		return
	if not _save(t, &"con", _spell_dc(c, "druid"), "Wrath of the Sea"):
		var rolled := e._roll_damage_dice("%dd6" % maxi(1, c.creature.ability_mod(&"wis")), false, 0, "Wrath of the Sea")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "cold"}], false, "Wrath of the Sea", [str(rolled["text"])])
		if t.is_alive() and Creature.SIZES.find(t.creature.size) <= Creature.SIZES.find(&"large"):
			e.forced_move(t, e.center_of(c), 15)


func _luminous_arrow(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or e.distance(c, t) > 60:
		return CombatResult.fail("Choose a creature within 60 ft")
	var ctx := {"c": c, "s": {"id": "luminous_arrow", "name": "Luminous Arrow", "level": 0, "attack": "ranged", "range": {"kind": "feet", "feet": 60},
		"damage": [{"dice": "2d8" if has(c, "twinkling_constellations") else "1d8", "type": "radiant"}]},
		"slot": 0, "nums": e.spells.numbers(c, {"class_id": "druid"}), "conc": null, "opts": {}, "choice": ""}
	var r := CombatResult.new()
	var before := t.creature.hp
	e.spells.spell_attack(ctx, t, r)
	if t.creature.hp < before and t.is_alive():
		e.deal_damage(c, t, [{"amount": maxi(0, c.creature.ability_mod(&"wis")), "type": "radiant"}], false, "Luminous Arrow")
	return r


# --- Ranger --------------------------------------------------------------------------------------------

## The Beast Master's primal companion (Beast of the Land, Sea or Sky): AC 13 + Wis, HP 5 + 5 × Ranger level,
## Beast's Strike 1d8 + 2 + Wis using the ranger's spell attack; it acts after the ranger and only Dodges unless
## commanded with a Bonus Action.
func _call_companion(c: Combatant, kind: String, cell: Vector2i) -> CombatResult:
	var e := enc()
	var lvl := level_of(c, "ranger")
	var wis := c.creature.ability_mod(&"wis")
	var atk := (e.spells.numbers(c, {"class_id": "ranger"})["attack"] as Breakdown).total()
	var speed := {"walk": 40, "climb": 40}
	var dtype := "piercing"
	var traits: Array = []
	match kind:
		"sea":
			speed = {"walk": 5, "swim": 60}
		"sky":
			speed = {"walk": 10, "fly": 60}
			dtype = "slashing"
			traits.append({"id": "flyby", "name": "Flyby", "action": "passive", "modifiers": [{"stat": "flag", "value": "flyby"}], "summary": "No Opportunity Attacks when it flies out of reach."})
	var hp := (4 if kind == "sky" else 5) + (4 if kind == "sky" else 5) * lvl
	var data := {"id": "primal_beast", "name": "Beast of the %s" % kind.capitalize(), "size": "medium" if kind != "sky" else "small", "type": "beast",
		"ac": 13 + wis, "hp": {"average": hp, "dice": str(hp)}, "speed": speed,
		"abilities": {"str": 14 if kind != "sky" else 6, "dex": 14 if kind != "sky" else 16, "con": 15 if kind != "sky" else 13, "int": 8, "wis": 14, "cha": 11},
		"senses": {"darkvision": 60}, "cr": 0, "xp": 0, "proficiency_bonus": c.creature.proficiency_bonus(), "initiative": 2, "summon": true,
		"primal_companion": true, "traits": traits,
		"actions": [{"id": "beasts_strike", "name": "Beast's Strike", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": [{"dice": "1d8+%d" % (2 + wis), "type": "force" if has(c, "exceptional_training") else dtype}], "summary": "Melee attack with your spell attack modifier."}],
		"ai_profile": "brute", "summary": "Your primal companion.", "text": "Primal Companion."}
	var m := Monster.from_data(data, e.dice)
	var spot := cell
	if spot.x < 0 or not e.spells._room_for(spot, CombatGrid.size_cells_for(m.size)) or e.grid.distance_ft(c.cell, c.size_cells, spot, 1) > 10:
		spot = e.spells._free_cell_near(c.cell, CombatGrid.size_cells_for(m.size))
	var sc := e.add(m, &"guest" if c.side == &"party" else c.side, spot)
	sc.controller = c.controller
	sc.set_meta("summoner", c.id)
	sc.set_meta("vanishes", true)
	if not e.spells.summoned.has(c.id):
		e.spells.summoned[c.id] = []
	(e.spells.summoned[c.id] as Array).append(sc.id)
	if e.state == Encounter.State.ACTIVE:
		e.insert_after(c, sc)
	e.events.append({"type": "summon_creature", "id": sc.id, "cell": spot, "caster": c.id})
	e.log.add("info", "%s answers %s's call" % [m.name, c.name()], c.id)
	return CombatResult.new()


## A primal companion can only attack when its ranger commanded it this round (it Dodges otherwise).
func companion_why(c: Combatant) -> String:
	if not c.creature is Monster or not bool((c.creature as Monster).data.get("primal_companion", false)):
		return ""
	if str(c.get_meta("commanded", "")) == "":
		return "Your beast only attacks when you command it (Bonus Action)"
	return ""


# --- Attack hooks ---------------------------------------------------------------------------------------

## Advantage and Disadvantage from these classes on an attack roll.
## Whether `c`'s Vow of Enmity is running and its foe has dropped (so it can move for free).
func vow_can_move(c: Combatant) -> bool:
	if not c.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "vow_of_enmity"):
		return false
	var old := enc().get_c(str(c.get_meta("vow_of_enmity", "")))
	return old == null or not old.is_alive() or old.creature.hp <= 0


func _vow_on(c: Combatant, t: Combatant) -> void:
	var e := enc()
	c.set_meta("vow_of_enmity", t.id)
	for o in e.combatants:
		for fx: Effect in o.creature.effects.duplicate():
			if fx.source_id == "vow_of_enmity:mark" and fx.caster_id == c.id:
				o.creature.remove_effect(fx)
	var badge := Effect.new("Vowed by %s (Vow of Enmity)" % c.name(), &"feature", "vow_of_enmity:mark")
	badge.caster_id = c.id
	badge.ends = Effect.Ends.NEVER
	badge.data["mark_by"] = c.id
	badge.data["mark_of"] = "vow_of_enmity"
	t.creature.add_effect(badge)
	e.events.append({"type": "condition", "id": t.id})


## The minute is up (or the effect was removed): the vow and its tag on the foe end.
func end_vow(cid: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(cid)
	if c != null:
		c.remove_meta("vow_of_enmity")
	for o in e.combatants:
		for fx: Effect in o.creature.effects.duplicate():
			if fx.source_id == "vow_of_enmity:mark" and fx.caster_id == cid:
				o.creature.remove_effect(fx)


func attack_situation(c: Combatant, target: Combatant, option: Dictionary, adv: Array[String], dis: Array[String]) -> void:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var brutal := c.armed.any(func(a: String) -> bool: return a.begins_with("brutal:"))
	if c.creature.has_flag("reckless") and p.ability == &"str" and str(option.get("kind", "")) != "spell" and not brutal:
		adv.append("Reckless Attack")
	if str(c.get_meta("vow_of_enmity", "")) == target.id and c.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "vow_of_enmity"):
		adv.append("Vow of Enmity")
	if str(c.get_meta("clairvoyant_vs", "")) == target.id:
		adv.append("Clairvoyant Combatant")
	if str(target.get_meta("clairvoyant_vs", "")) == c.id:
		dis.append("Clairvoyant Combatant")
	# Rage of the Wolf: allies attacking an enemy within 5 ft of the raging barbarian.
	if bool(option.get("melee", false)):
		for b in e.allies_of(c):
			if b != c and raging(b) and str(b.get_meta("rage_animal", "")) == "wolf" and e.distance(b, target) <= 5 and b.hostile_to(target):
				adv.append("Rage of the Wolf")
				break
	# Hunter: Escape the Horde (Opportunity Attacks against you), Multiattack Defense.
	if has(target, "multiattack_defense") and str(target.get_meta(meta_key("hit_by_%s" % c.id), "")) == _turn_key():
		dis.append("Multiattack Defense")
	if bool(option.get("opportunity", false)) and has(target, "escape_the_horde"):
		dis.append("Escape the Horde")
	if has(c, "precise_hunter") and c.creature.modifiers_for(&"extra_damage").any(func(m: Modifier) -> bool: return str(m.data.get("vs", "")) == target.id and m.source_name == "Hunter's Mark"):
		adv.append("Precise Hunter")


## Extra damage dice on a weapon or Unarmed Strike hit from these classes.
func hit_dice(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var melee := bool(option.get("melee", false))
	var str_attack := p.ability == &"str"
	# Brutal Strike (Barbarian 9): Advantage given up for 1d10 and a blow.
	for a: String in c.armed.duplicate():
		if a.begins_with("brutal:") and str_attack and _once(c, "brutal_strike"):
			c.armed.erase(a)
			st["brutal"] = a.substr(7)
			out.append({"dice": "2d10" if level_of(c, "barbarian") >= 17 else "1d10", "type": str(p.damage_type), "label": "Brutal Strike"})
			break
	# Berserker's Frenzy: the first Strength hit of the turn while raging and reckless.
	if has(c, "frenzy") and raging(c) and c.creature.has_flag("reckless") and str_attack and e.current() == c and _once(c, "frenzy"):
		out.append({"dice": "%dd6" % rage_bonus(c), "type": str(p.damage_type), "label": "Frenzy"})
	# Zealot's Divine Fury: the first creature hit each turn while raging.
	if has(c, "divine_fury") and raging(c) and _once(c, "divine_fury"):
		out.append({"dice": "1d6+%d" % (level_of(c, "barbarian") / 2), "type": "radiant", "label": "Divine Fury"})
	# Hunter's Prey: Colossus Slayer.
	if "colossus_slayer" in picks(c, "hunters_prey") and target.creature.hp < target.creature.max_hp() and _once(c, "colossus_slayer"):
		out.append({"dice": "1d8", "type": str(p.damage_type), "label": "Colossus Slayer"})
	# Gloom Stalker: Dreadful Strike (Wis-modifier uses per Long Rest, once per turn).
	if has(c, "dread_ambusher") and _uses(c, "dreadful_strike", "Dreadful Strike", maxi(1, c.creature.ability_mod(&"wis")), "long") > 0 and _once(c, "dreadful_strike"):
		(_ch(c)).spend_resource("dreadful_strike")
		out.append({"dice": "2d8" if has(c, "stalkers_flurry") else "2d6", "type": "psychic", "label": "Dreadful Strike"})
	# Winter Walker: Polar Strikes only on weapon attacks, once per target per turn.
	if has(c, "frigid_explorer") and p.item_id != "unarmed_strike" and str(option.get("kind", "")) in ["weapon", "thrown"] and _once(c, "polar_strikes:%s" % target.id):
		out.append({"dice": "1d6" if level_of(c, "ranger") >= 11 else "1d4", "type": "cold", "label": "Polar Strikes"})
	# Fey Wanderer: Dreadful Strikes (once per turn per creature).
	if has(c, "dreadful_strikes") and _once(c, "dreadful_strikes:%s" % target.id):
		out.append({"dice": "1d6" if level_of(c, "ranger") >= 11 else "1d4", "type": "psychic", "label": "Dreadful Strikes"})
	# Druid: Elemental Fury's Primal Strike (once per turn on a weapon or Beast-form hit).
	if "primal_strike" in picks(c, "elemental_fury") and _once(c, "primal_strike"):
		out.append({"dice": "2d8" if has(c, "improved_elemental_fury") else "1d8", "type": "cold", "label": "Primal Strike"})
	# Paladin 11: Radiant Strikes.
	if has(c, "radiant_strikes") and melee:
		out.append({"dice": "1d8", "type": "radiant", "label": "Radiant Strikes"})
	# Monk: Warrior of Mercy's Hand of Harm (1 Focus, once per turn on an Unarmed Strike).
	var free_harm := has(c, "flurry_of_healing_and_harm") and str(c.get_meta("flurry_turn", "")) == _turn_key() and "hand_of_harm" in c.armed \
		and _uses(c, "flurry_of_healing_and_harm", "Flurry of Healing and Harm", maxi(1, c.creature.ability_mod(&"wis")), "long") > 0
	if "hand_of_harm" in c.armed and p.item_id == "unarmed_strike" and (free_harm or _ch(c).resource_left("focus_points") > 0) and _once(c, "hand_of_harm"):
		c.armed.erase("hand_of_harm")
		if free_harm:
			_ch(c).spend_resource("flurry_of_healing_and_harm")
		else:
			_ch(c).spend_resource("focus_points")
		out.append({"dice": "1d%d+%d" % [martial_die(c), c.creature.ability_mod(&"wis")], "type": "necrotic", "label": "Hand of Harm"})
	# Warlock: Lifedrinker, Eldritch Smite on the pact weapon.
	if c.has_meta("pact_weapon") and p.item_id == str(c.get_meta("pact_weapon")):
		if knows_invocation(c, "lifedrinker") and _once(c, "lifedrinker"):
			out.append({"dice": "1d6", "type": "necrotic", "label": "Lifedrinker"})
		var pact := _ch(c).pact_magic()
		if "eldritch_smite" in c.armed and knows_invocation(c, "eldritch_smite") and int(pact["left"]) > 0 and _once(c, "eldritch_smite"):
			c.armed.erase("eldritch_smite")
			var lvl := int(pact["level"])
			_ch(c).pact_slots_used = int(pact["used"]) + 1
			out.append({"dice": "%dd8" % (1 + lvl), "type": "force", "label": "Eldritch Smite"})
			st["eldritch_smite"] = true
	# Bestial Fury: the beast's first hit each turn on its ranger's Hunter's Mark target adds the mark's damage.
	if c.creature is Monster and bool((c.creature as Monster).data.get("primal_companion", false)):
		var ranger := enc().get_c(str(c.get_meta("summoner", "")))
		if ranger != null and has(ranger, "bestial_fury") and _once(c, "bestial_fury"):
			for m in ranger.creature.modifiers_for(&"extra_damage"):
				if str(m.data.get("vs", "")) == target.id and m.source_name == "Hunter's Mark":
					out.append({"dice": m.text("dice", "1d6"), "type": "force", "label": "Bestial Fury"})
	# Monk: Elemental Attunement strikes deal elemental damage instead (an extra die of it here).
	return out


## Flat bonuses: Rage Damage on Strength attacks.
func flat_bonus(c: Combatant, _target: Combatant, option: Dictionary, notes: Array[String]) -> int:
	var p := option["profile"] as WeaponProfile
	if raging(c) and p.ability == &"str" and str(option.get("kind", "")) != "spell":
		notes.append("Rage +%d" % rage_bonus(c))
		return rage_bonus(c)
	return 0


## Riders these classes arm for their next hit (Stunning Strike, Hand of Harm, Eldritch Smite).
func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ch := _ch(c)
	if ch == null:
		return out
	if has(c, "brutal_strike") and c.creature.has_flag("reckless"):
		for b: String in ["forceful", "hamstring"] + (["staggering", "sundering"] if has(c, "improved_brutal_strike") else []):
			out.append({"id": "brutal:" + b, "label": "Brutal Strike: %s Blow" % b.capitalize(), "sub": "give up Advantage: +%s" % ("2d10" if level_of(c, "barbarian") >= 17 else "1d10"), "why": ""})
	if has(c, "stunning_strike"):
		out.append({"id": "stunning_strike", "label": "Stunning Strike", "sub": "1 Focus: Con save or Stunned", "why": "" if ch.resource_left("focus_points") > 0 else "No Focus Points"})
	if has(c, "hand_of_harm"):
		out.append({"id": "hand_of_harm", "label": "Hand of Harm", "sub": "1 Focus: +1d%d + Wis Necrotic" % martial_die(c), "why": "" if ch.resource_left("focus_points") > 0 else "No Focus Points"})
	if knows_invocation(c, "eldritch_smite") and c.has_meta("pact_weapon"):
		out.append({"id": "eldritch_smite", "label": "Eldritch Smite", "sub": "a Pact slot: Force damage and Prone", "why": "" if int(ch.pact_magic()["left"]) > 0 else "No Pact Magic slots"})
	if has(c, "open_hand_technique"):
		for tech: String in ["addle", "push", "topple"]:
			out.append({"id": "open_hand:" + tech, "label": "Open Hand: %s" % tech.capitalize(), "sub": "on Flurry of Blows hits", "why": ""})
	return out


## After a weapon or Unarmed Strike hit.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var p := option["profile"] as WeaponProfile
	var alive := target.is_alive() and not target.is_down()
	kept_rage(c)
	target.set_meta(meta_key("hit_by_%s" % c.id), _turn_key())
	var monkish := p.item_id == "unarmed_strike" or (level_of(c, "monk") > 0 and p.melee and not "heavy" in p.properties and not "two_handed" in p.properties)
	# Stunning Strike (Monk 5).
	if "stunning_strike" in c.armed and alive and monkish and _ch(c).resource_left("focus_points") > 0 and _once(c, "stunning_strike"):
		c.armed.erase("stunning_strike")
		_ch(c).spend_resource("focus_points")
		var dc := 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis")
		if not _save(target, &"con", dc, "Stunning Strike", "stunned"):
			var fx := _timed(c, "Stunned (Stunning Strike)", "stunning_strike", Effect.Ends.START_OF_TURN, c).with_condition(&"stunned")
			target.creature.add_effect(fx)
			e.features.end_turning_from(target)
		else:
			var half := _timed(c, "Staggered (Stunning Strike)", "stunning_strike", Effect.Ends.START_OF_TURN, c).with_modifier("speed_percent", {"value": 50})
			target.creature.add_effect(half)
			e.add_mark({"kind": "advantage_against", "target": target.id, "source": "Stunning Strike", "expires_owner": c.id, "expires_phase": "start", "consume": true})
		e.events.append({"type": "condition", "id": target.id})
		e.feature_recipes.on_feature_target(c, target, "stunning_strike")
	# Open Hand Technique on Flurry of Blows hits.
	if str(c.get_meta("flurry_turn", "")) == _turn_key() and alive and has(c, "open_hand_technique"):
		var tech := ""
		for a: String in c.armed:
			if a.begins_with("open_hand:"):
				tech = a.substr(10)
		if tech == "":
			tech = "topple"
		var dc2 := 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis")
		match tech:
			"addle":
				var ad := _timed(c, "Addled", "open_hand_technique", Effect.Ends.START_OF_TURN, target).with_modifier("flag", {"value": "no_reactions"})
				target.creature.add_effect(ad)
			"push":
				if not _save(target, &"str", dc2, "Open Hand Technique"):
					e.forced_move(target, e.center_of(c), 15)
			"topple":
				if not _save(target, &"dex", dc2, "Open Hand Technique", "prone"):
					target.creature.add_condition(&"prone", "Open Hand Technique")
	# Elemental Attunement: push or pull 10 ft (Strength save).
	if c.creature.has_flag("elemental_attunement") and p.item_id == "unarmed_strike" and alive and Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"large"):
		if not _save(target, &"str", 8 + c.creature.proficiency_bonus() + c.creature.ability_mod(&"wis"), "Elemental Attunement"):
			e.forced_move(target, e.center_of(c), 10)
	# Battering Roots (World Tree 10): a Heavy or Versatile hit on your turn can also Topple (Con save or Prone).
	if has(c, "battering_roots") and alive and e.current() == c and ("heavy" in p.properties or "versatile" in p.properties) and p.mastery != "topple" \
			and Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"large") and _once(c, "battering_roots"):
		if not _save(target, &"con", 8 + c.creature.ability_mod(p.ability) + c.creature.proficiency_bonus(), "Battering Roots (Topple)", "prone"):
			target.creature.add_condition(&"prone", "Battering Roots")
	match str(st.get("brutal", "")):
		"forceful":
			if alive:
				e.forced_move(target, e.center_of(c), 15)
			c.free_move_ft = maxi(c.free_move_ft, c.speed() / 2)
		"hamstring":
			if alive:
				for fx0: Effect in target.creature.effects.duplicate():
					if fx0.source_id == "hamstring_blow":
						target.creature.remove_effect(fx0)
				target.creature.add_effect(_timed(c, "Hamstring Blow", "hamstring_blow", Effect.Ends.START_OF_TURN, c).with_modifier("speed", {"value": -15}))
		"staggering":
			if alive:
				target.creature.add_effect(_timed(c, "Staggering Blow", "staggering_blow", Effect.Ends.START_OF_TURN, c).with_modifier("disadvantage", {"on": "save:all"}).with_modifier("flag", {"value": "no_opportunity_attacks"}))
		"sundering":
			if alive:
				e.add_mark({"kind": "attack_bonus_against", "target": target.id, "bonus": 5, "not_by": c.id, "source": "Sundering Blow", "expires_owner": c.id, "expires_phase": "start"})
	# Relentless Avenger (Vengeance 7): an Opportunity Attack hit stops the target and lets the paladin move.
	if bool(option.get("opportunity", false)) and has(c, "relentless_avenger"):
		if alive:
			var stop := _timed(c, "Speed 0 (Relentless Avenger)", "relentless_avenger", Effect.Ends.END_OF_TURN, e.current() if e.current() != null else target).with_modifier("speed_set", {"value": 0})
			target.creature.add_effect(stop)
	# Eldritch Smite: knock a Huge or smaller creature Prone.
	if bool(st.get("eldritch_smite", false)) and alive and Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"huge"):
		target.creature.add_condition(&"prone", "Eldritch Smite")
		e.log.add("condition", "%s is knocked Prone (Eldritch Smite)" % target.name(), target.id)
	# Stalker's Flurry (Gloom Stalker 11): with Dreadful Strike, a Sudden Strike at another foe beside the target, or
	# Mass Fear around it.
	if has(c, "stalkers_flurry") and str(c.get_meta(meta_key("once_dreadful_strike"), "")) == _turn_key() and not c.has_meta("flurried_" + _turn_key().replace(":", "_")):
		c.set_meta("flurried_" + _turn_key().replace(":", "_"), true)
		var other: Combatant = null
		for o in e.hostiles_of(c):
			if o != target and not o.is_down() and e.distance(o, target) <= 5 and e.attack_legal(c, o, option) == "":
				other = o
				break
		if other != null:
			e.log.add("info", "%s strikes again at %s (Sudden Strike)" % [c.name(), other.name()], c.id)
			e.cleave_queue.append({"c": c, "target": other, "option": option})
		else:
			var dc := _spell_dc(c, "ranger")
			for o2 in e.hostiles_of(c):
				if not o2.is_down() and e.distance(o2, target) <= 10 or o2 == target:
					if o2.is_alive() and not _save(o2, &"wis", dc, "Mass Fear", "frightened"):
						o2.creature.add_effect(_timed(c, "Frightened (Mass Fear)", "mass_fear", Effect.Ends.START_OF_TURN, c).with_condition(&"frightened"))
	# Superior Hunter's Prey (Hunter 11): Hunter's Mark's extra damage also hits another creature within 30 ft.
	if has(c, "superior_hunters_prey") and _once(c, "superior_hunters_prey"):
		for m in c.creature.modifiers_for(&"extra_damage"):
			if str(m.data.get("vs", "")) == target.id and m.source_name == "Hunter's Mark":
				var other2: Combatant = null
				for o3 in e.hostiles_of(c):
					if o3 != target and not o3.is_down() and e.distance(o3, target) <= 30 and e.can_see(c, o3):
						other2 = o3
						break
				if other2 != null:
					var hm := e._roll_damage_dice(m.text("dice", "1d6"), false, 0, "Superior Hunter's Prey")
					e.deal_damage(c, other2, [{"amount": int(hm["total"]), "type": m.text("type", "force")}], false, "Superior Hunter's Prey", [str(hm["text"])])
				break
	# Hunter's Prey: Horde Breaker (once per turn, another creature within 5 ft of the target).
	if "horde_breaker" in picks(c, "hunters_prey") and _once(c, "horde_breaker"):
		for o in e.hostiles_of(c):
			if o != target and not o.is_down() and e.distance(o, target) <= 5 and e.attack_legal(c, o, option) == "":
				e.log.add("info", "%s turns on %s too (Horde Breaker)" % [c.name(), o.name()], c.id)
				e.cleave_queue.append({"c": c, "target": o, "option": option})
				break


## Gift of the Protectors (Pact of the Tome): a creature in the party drops to 1 Hit Point instead of 0, once per
## Long Rest each. True if it held.
func gift_of_the_protectors(t: Combatant) -> bool:
	var e := enc()
	if not t.creature is Character:
		return false
	for w in e.combatants:
		if w.is_alive() and w.allied_with(t) and knows_invocation(w, "gift_of_the_protectors") and knows_invocation(w, "pact_of_the_tome"):
			var key := "gift_of_the_protectors"
			if _uses(t, key, "Gift of the Protectors", 1, "long") <= 0:
				return false
			_ch(t).spend_resource(key)
			e.log.add("info", "%s's name in the Book of Shadows holds: 1 Hit Point" % t.name(), t.id)
			return true
	return false


## Where `c` casts spells from: its own space, or a willing ally's through Gaze of Two Minds (until the end of the
## caster's next turn).
func cast_origin(c: Combatant) -> Combatant:
	var e := enc()
	if not c.has_meta("gaze_link"):
		return c
	var link := c.get_meta("gaze_link") as Array
	var other := e.get_c(str(link[0]))
	if other == null or not other.is_alive() or e.round_no > int(link[1]):
		c.remove_meta("gaze_link")
		return c
	return other


## Relentless Rage (Barbarian 11): dropping to 0 while raging, a Constitution save (DC 10, +5 each use) leaves you at
## twice your Barbarian level. True if it held.
func relentless_rage(c: Combatant) -> bool:
	# Dropping to 0 already ended the Rage effect (Incapacitated), so the Rage counts if it was on a moment ago.
	if not has(c, "relentless_rage") or not (raging(c) or c.has_meta("rage_effect")):
		return false
	var e := enc()
	var dc := 10 + 5 * int(c.get_meta("relentless_uses", 0))
	c.set_meta("relentless_uses", int(c.get_meta("relentless_uses", 0)) + 1)
	var sv := c.creature.roll_save(e.dice, &"con", dc, [], [], "Relentless Rage (%s)" % c.name())
	if not sv.success:
		return false
	c.creature.hp = 2 * level_of(c, "barbarian")
	c.creature.remove_condition(&"unconscious", "0 Hit Points")
	# Still raging: put the Rage back without spending a use.
	if not raging(c):
		_refund(_ch(c), "rage")
		var keep := c.bonus_available
		_start_rage(c, str(c.get_meta("rage_animal", "")))
		c.bonus_available = keep
	e.log.add("info", "%s refuses to fall: Relentless Rage" % c.name(), c.id, [sv.describe()])
	return true


## A creature dropped to 0 Hit Points by `by`: Dark One's Blessing (Fiend Patron) for a warlock or a nearby ally.
func on_drop(by: Combatant, target: Combatant) -> void:
	var e := enc()
	# A vowed foe down: the paladin may move the vow (shown on the hotbar and the right-click menu).
	for v in e.living():
		if str(v.get_meta("vow_of_enmity", "")) == target.id and vow_can_move(v):
			e.log.add("info", "%s's Vow of Enmity can move to another foe within 30 ft (free)" % v.name(), v.id)
	if by == null or not by.hostile_to(target):
		return
	for w in e.living():
		if not has(w, "dark_ones_blessing") or w.creature.hp <= 0:
			continue
		if w == by or (w.allied_with(by) and e.distance(w, target) <= 10):
			_temp(w, maxi(1, w.creature.ability_mod(&"cha") + level_of(w, "warlock")), "Dark One's Blessing")


# --- Reactions ----------------------------------------------------------------------------------------------

## Against an attack's damage: Deflect Attacks (Monk 3), Cutting Words (College of Lore), Combat Inspiration.
func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var p := ((st["option"] as Dictionary)["profile"]) as WeaponProfile
	var react := func(x: Combatant) -> bool: return e.spells.can_react(x)
	if has(target, "deflect_attacks") and (str(p.damage_type) in ["bludgeoning", "piercing", "slashing"] or has(target, "deflect_energy")):
		var lvl := level_of(target, "monk")
		var amt := "1d10 + %d" % (target.creature.ability_mod(&"dex") + lvl)
		out.append({"kind": "deflect_attacks", "reactor": target, "trigger": c.id, "title": "Reaction: Deflect Attacks?",
			"text": "%s hits %s for %d. Deflect it: reduce the damage by %s." % [c.name(), target.name(), total.call(), amt],
			"still": func() -> bool: return react.call(target) and int(total.call()) > 0,
			"use": func() -> void:
				target.reaction_available = false
				var roll := e.dice.roll_one(10, "Deflect Attacks") + target.creature.ability_mod(&"dex") + lvl
				cut.call(roll, "Deflect Attacks")
				# All of it deflected: spend 1 Focus to send it back at a creature within 5 ft (or 60 ft for a ranged attack).
				if int(total.call()) <= 0 and _ch(target).resource_left("focus_points") > 0 and c.is_alive():
					_ch(target).spend_resource("focus_points")
					var dc := 8 + target.creature.proficiency_bonus() + target.creature.ability_mod(&"dex")
					if not _save(c, &"dex", dc, "Deflect Attacks"):
						var rr := e._roll_damage_dice("2d%d" % martial_die(target), false, 0, "Deflect Attacks")
						e.deal_damage(target, c, [{"amount": int(rr["total"]) + target.creature.ability_mod(&"dex"), "type": str(p.damage_type)}], false, "Deflect Attacks", [str(rr["text"])])})
	# Beguiling Defenses (Archfey 10): halve the damage and turn it back on the attacker (Wisdom save).
	if has(target, "beguiling_defenses") and e.can_see(target, c) and (_uses(target, "beguiling_defenses", "Beguiling Defenses", 1, "long") > 0 or int(_ch(target).pact_magic()["left"]) > 0):
		out.append({"kind": "beguiling_defenses", "reactor": target, "trigger": c.id, "title": "Reaction: Beguiling Defenses?",
			"text": "%s hits %s for %d. Halve it and make %s save or take the same Psychic damage?" % [c.name(), target.name(), total.call(), c.name()],
			"cost": "Reaction (once per Long Rest, or a Pact Magic slot)",
			"still": func() -> bool: return react.call(target) and int(total.call()) > 0,
			"use": func() -> void:
				target.reaction_available = false
				var tch := _ch(target)
				if tch.resource_left("beguiling_defenses") > 0:
					tch.spend_resource("beguiling_defenses")
				else:
					tch.pact_slots_used = int(tch.pact_magic()["used"]) + 1
				var half := int(total.call()) - int(total.call()) / 2
				cut.call(half, "Beguiling Defenses")
				if not _save(c, &"wis", _spell_dc(target, "warlock"), "Beguiling Defenses"):
					e.deal_damage(target, c, [{"amount": int(total.call()), "type": "psychic"}], false, "Beguiling Defenses")})
	for b in e.allies_of(target):
		if has(b, "cutting_words") and _ch(b).resource_left("bardic_inspiration") > 0 and e.distance(b, c) <= 60 and e.can_see(b, c):
			var bard := b
			out.append({"kind": "cutting_words", "reactor": bard, "trigger": c.id, "title": "Reaction: Cutting Words?",
				"text": "%s hits %s for %d. %s can spend Bardic Inspiration to cut the damage by a d%d." % [c.name(), target.name(), total.call(), bard.name(), bardic_die(bard)],
				"cost": "Reaction and a use of Bardic Inspiration",
				"still": func() -> bool: return react.call(bard) and int(total.call()) > 0,
				"use": func() -> void:
					bard.reaction_available = false
					_ch(bard).spend_resource("bardic_inspiration")
					cut.call(e.dice.roll_one(bardic_die(bard), "Cutting Words"), "Cutting Words (%s)" % bard.name())})
			break


## A failed save (D20Responses): Countercharm (Bard 7) from the bard or a bard within 30 ft, against being Charmed or
## Frightened (a reroll with Advantage), and the Zealot's Fanatical Focus (once per Rage, a reroll with the Rage
## Damage bonus).
func failed_save_offers(t: Combatant, test: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	if "save_vs:charmed" in keys or "save_vs:frightened" in keys:
		for b in e.living():
			if not has(b, "countercharm") or not (b == t or b.allied_with(t)) or e.distance(b, t) > 30:
				continue
			var bard := b
			out.append({"kind": "countercharm", "reactor": b, "trigger": t.id, "title": "Reaction: Countercharm?",
				"text": func() -> String: return "%s. %s's Countercharm has the save rolled again with Advantage." % [D20Responses.line(t, test), bard.name()],
				"cost": "Reaction",
				"still": func() -> bool: return not test.success and e.spells.can_react(bard),
				"helps": func() -> bool: return D20Responses.could_reach(test),
				"use": func() -> void:
					bard.reaction_available = false
					test.reroll(e.dice, "Countercharm (%s)" % bard.name(), true, t.creature.has_flag("luck"))
					e.log.add("reaction", "%s's Countercharm steadies %s" % [bard.name(), t.name()], bard.id, [test.describe()])})
	# Zealot's Fanatical Focus: once per Rage, reroll a failed save with the Rage Damage bonus.
	if has(t, "fanatical_focus"):
		out.append({"kind": "fanatical_focus", "reactor": t, "title": "Fanatical Focus?",
			"text": func() -> String: return "%s. Reroll the save with +%d and use the new roll?" % [D20Responses.line(t, test), rage_bonus(t)],
			"cost": "Fanatical Focus (once per Rage)", "spends_reaction": false,
			"still": func() -> bool: return not test.success and raging(t) and not t.has_meta("fanatical_used"),
			"helps": func() -> bool: return D20Responses.could_reach(test, 20, rage_bonus(t)),
			"use": func() -> void:
				t.set_meta("fanatical_used", true)
				test.reroll(e.dice, "Fanatical Focus", false, t.creature.has_flag("luck"))
				test.add_bonus(rage_bonus(t), "Fanatical Focus")
				e.log.add("info", "%s's fury carries it through (Fanatical Focus)" % t.name(), t.id, [test.describe()])})


# --- Auras ------------------------------------------------------------------------------------------------

## Aura of Protection (Paladin 6) and the Oath auras (Devotion, Glory, Ancients at 7): allies within 10 ft (30 ft
## with Aura Expansion) of a conscious paladin. Re-applied whenever creatures move.
func refresh_auras() -> void:
	var e := enc()
	if e == null:
		return
	var paladins: Array[Combatant] = []
	for p in e.combatants:
		if p.is_alive() and p.creature.hp > 0 and not p.creature.has_condition(&"incapacitated") and has(p, "aura_of_protection"):
			paladins.append(p)
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if fx.stack_key.begins_with("aura:"):
				var src := e.get_c(fx.stack_key.substr(5))
				if src == null or not src in paladins or not _in_aura(src, t):
					t.creature.remove_effect(fx)
	for p in paladins:
		for t in e.living():
			if not _in_aura(p, t):
				continue
			var key := "aura:%s" % p.id
			if t.creature.effects.any(func(x: Effect) -> bool: return x.stack_key == key):
				continue
			var fx := Effect.new("Aura of Protection (%s)" % p.name(), &"feature", "aura_of_protection")
			fx.stack_key = key
			fx.ends = Effect.Ends.NEVER
			fx.modifiers.append(Modifier.of("save", {"ability": "all", "value": maxi(1, p.creature.ability_mod(&"cha"))}, "Aura of Protection", &"feature"))
			if has(p, "aura_of_courage"):
				fx.modifiers.append(Modifier.of("condition_immunity", {"value": "frightened"}, "Aura of Courage", &"feature"))
			if has(p, "aura_of_devotion"):
				fx.modifiers.append(Modifier.of("condition_immunity", {"value": "charmed"}, "Aura of Devotion", &"feature"))
			if has(p, "aura_of_warding"):
				for ty: String in ["necrotic", "psychic", "radiant"]:
					fx.modifiers.append(Modifier.of("resistance", {"value": ty}, "Aura of Warding", &"feature"))
			if has(p, "aura_of_alacrity") and t != p:
				fx.modifiers.append(Modifier.of("speed", {"value": 10}, "Aura of Alacrity", &"feature"))
			# Aura of Elemental Shielding (Oath of the Noble Genies 7): the element the paladin holds now.
			if has(p, "aura_of_elemental_shielding"):
				fx.modifiers.append(Modifier.of("resistance", {"value": enc().faerun.genie_element(p)}, "Aura of Elemental Shielding", &"feature"))
			t.creature.add_effect(fx)


func _in_aura(p: Combatant, t: Combatant) -> bool:
	if not (t == p or p.allied_with(t)):
		return false
	return enc().distance(p, t) <= (30 if has(p, "aura_expansion") else 10)


# --- Turns --------------------------------------------------------------------------------------------

## Initiative was just rolled: Tandem Footwork (College of Dance 6) spends Bardic Inspiration to add the die to the
## bard's and nearby allies' Initiative.
func initiative_rolled() -> void:
	var e := enc()
	for b in e.combatants:
		if not has(b, "tandem_footwork") or _ch(b).resource_left("bardic_inspiration") <= 0 or str(b.reaction_rules.get("tandem_footwork", "auto")) == "never":
			continue
		_ch(b).spend_resource("bardic_inspiration")
		var roll := e.dice.roll_one(bardic_die(b), "Tandem Footwork")
		for a in e.combatants:
			if a == b or (a.allied_with(b) and e.distance(a, b) <= 30):
				a.initiative += roll
		e.log.add("info", "%s leads the dance: +%d Initiative to nearby allies (Tandem Footwork)" % [b.name(), roll], b.id)


## When a fight starts: the always-on benefits are in place before anyone acts.
func prepare(c: Combatant) -> void:
	var ch := _ch(c)
	if ch != null:
		_standing_effects(c, ch)
	# Cosmic Omen: the omen read at the last Long Rest (an even d6 is Weal, odd is Woe), drawn once per fight here.
	if has(c, "cosmic_omen") and not c.has_meta("omen"):
		c.set_meta("omen", "weal" if enc().dice.roll_one(6, "Cosmic Omen") % 2 == 0 else "woe")
		enc().log.add("info", "%s reads the stars: %s" % [c.name(), str(c.get_meta("omen")).capitalize()], c.id)


func turn_start(c: Combatant) -> void:
	var e := enc()
	# Mounted combat: a controlled mount moves on its rider's turn (its Speed refreshes then) and spends its own turn
	# only on Dash, Disengage or Dodge.
	var steed := e.controlled_mount(c)
	if steed != null:
		steed.movement_left = steed.speed()
	if e.rider_of(c) != null and c.allied_with(e.rider_of(c)):
		c.movement_left = 0
		e.log.add("info", "%s carries %s (a controlled mount moves on its rider's turn)" % [c.name(), e.rider_of(c).name()], c.id)
	# Branches of the Tree (World Tree 6): a creature starting its turn within 30 ft of a raging barbarian makes a
	# Strength save or is pulled beside it with Speed 0 for the turn.
	for b in e.hostiles_of(c):
		if raging(b) and has(b, "branches_of_the_tree") and e.spells.can_react(b) and e.distance(b, c) <= 30 and e.distance(b, c) > 5 \
				and e.can_see(b, c) and str(b.reaction_rules.get("branches_of_the_tree", "auto")) != "never":
			b.reaction_available = false
			var dc := 8 + b.creature.proficiency_bonus() + b.creature.ability_mod(&"str")
			if not _save(c, &"str", dc, "Branches of the Tree"):
				var spot := e.spells._free_cell_near(b.cell, c.size_cells)
				if e.grid.distance_ft(b.cell, b.size_cells, spot, c.size_cells) <= 5:
					e.spells._teleport(c, spot, CombatResult.new())
				var root := _timed(b, "Rooted (Branches of the Tree)", "branches_of_the_tree", Effect.Ends.END_OF_TURN, c).with_modifier("speed_set", {"value": 0})
				c.creature.add_effect(root)
				c.movement_left = 0
			break
	# Primal companion: a fresh order each round.
	if c.creature is Monster and c.has_meta("commanded"):
		c.remove_meta("commanded")
	var ch := _ch(c)
	if ch == null:
		return
	_standing_effects(c, ch)
	if raging(c) and (c.creature.has_condition(&"incapacitated") or str(ch.armor_situation().get("armor", "")) == "heavy"):
		end_rage(c, "incapacitated or in Heavy armor")
	# World Tree: Vitality Surge's life-giving branches to another creature within 10 ft.
	if raging(c) and has(c, "vitality_of_the_tree"):
		var best: Combatant = null
		for a in e.allies_of(c):
			if a != c and a.is_alive() and e.distance(c, a) <= 10 and (best == null or a.creature.hp < best.creature.hp):
				best = a
		if best != null:
			var rolled := e._roll_damage_dice("%dd6" % rage_bonus(c), false, 0, "Life-Giving Force")
			_temp(best, int(rolled["total"]), "Life-Giving Force")
	# Uncanny Metabolism (Monk 2): the first turn of a fight, regain Focus and heal.
	if has(c, "uncanny_metabolism") and not c.has_meta("metabolised") and ch.resource_left("uncanny_metabolism") > 0 \
			and (ch.resource_left("focus_points") < ch.resource_max("focus_points") or c.creature.hp < c.creature.max_hp()):
		c.set_meta("metabolised", true)
		ch.spend_resource("uncanny_metabolism")
		if ch.resources.has("focus_points"):
			(ch.resources["focus_points"] as Dictionary)["used"] = 0
		_heal(c, c, maxi(e.dice.roll_one(martial_die(c), "Uncanny Metabolism"), e.heal_floor(c)) + level_of(c, "monk"), "Uncanny Metabolism")
		e.feature_recipes.offer_slot_recovery(c, "uncanny_metabolism")
	# Guarded Mind (Psi Warrior 10): start the turn Charmed or Frightened, spend a Psionic Energy Die to end it.
	if has(c, "guarded_mind") and (c.creature.has_condition(&"charmed") or c.creature.has_condition(&"frightened")) and ch.resource_left("psionic_energy") > 0:
		ch.spend_resource("psionic_energy")
		e.spells.cure(c, &"charmed")
		e.spells.cure(c, &"frightened")
		e.log.add("info", "%s clears its mind (Guarded Mind)" % c.name(), c.id)
	# Gloom Stalker: +10 ft on the first turn.
	if has(c, "dread_ambusher") and not c.has_meta("ambushed"):
		c.set_meta("ambushed", true)
		c.movement_left += 10


## Always-on benefits these features give in a fight, kept as one effect (rebuilt each turn): Dazzling Footwork's
## and Empowered Strikes' Unarmed Strikes, Roving, Aspect of the Wilds, Umbral Sight, Devil's Sight, Beguiling Twist.
func _standing_effects(c: Combatant, ch: Character) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.stack_key == "feature:class_standing":
			c.creature.remove_effect(fx)
	var fx2 := Effect.new("Class features", &"feature", "class_standing")
	fx2.stack_key = "feature:class_standing"
	fx2.ends = Effect.Ends.NEVER
	var unarmored := ch.equipped("armor").is_empty() and str(ch.equipped("off_hand").get("category", "")) != "shield"
	if has(c, "dazzling_footwork") and unarmored:
		fx2.modifiers.append(Modifier.of("weapon_override", {"items": ["unarmed_strike"], "die": "1d%d" % bardic_die(c), "ability": "dex"}, "Agile Strikes", &"feature"))
	if has(c, "empowered_strikes"):
		fx2.modifiers.append(Modifier.of("weapon_override", {"items": ["unarmed_strike"], "damage_type": "force"}, "Empowered Strikes", &"feature"))
	if has(c, "roving") and str(ch.armor_situation().get("armor", "")) != "heavy":
		fx2.modifiers.append(Modifier.of("speed", {"value": 10}, "Roving", &"feature"))
		fx2.modifiers.append(Modifier.of("speed_set", {"kind": "climb", "value": ch.speed().total() + 10}, "Roving", &"feature"))
		fx2.modifiers.append(Modifier.of("speed_set", {"kind": "swim", "value": ch.speed().total() + 10}, "Roving", &"feature"))
	var aspect := picks(c, "aspect_of_the_wilds")
	if "panther" in aspect:
		fx2.modifiers.append(Modifier.of("speed_set", {"kind": "climb", "value": ch.speed().total()}, "Aspect of the Panther", &"feature"))
	if "salmon" in aspect:
		fx2.modifiers.append(Modifier.of("speed_set", {"kind": "swim", "value": ch.speed().total()}, "Aspect of the Salmon", &"feature"))
	if "owl" in aspect:
		fx2.modifiers.append(Modifier.of("darkvision", {"value": maxi(60, c.creature.darkvision() + 60)}, "Aspect of the Owl", &"feature"))
	if has(c, "umbral_sight"):
		fx2.modifiers.append(Modifier.of("flag", {"value": "umbral_sight"}, "Umbral Sight", &"feature"))
		fx2.modifiers.append(Modifier.of("darkvision", {"value": maxi(60, c.creature.darkvision() + 60)}, "Umbral Sight", &"feature"))
	if knows_invocation(c, "devils_sight"):
		fx2.modifiers.append(Modifier.of("flag", {"value": "devils_sight"}, "Devil's Sight", &"feature"))
	if has(c, "extra_attack") and ch.subclasses.get("bard", "") == "college_of_valor":
		fx2.modifiers.append(Modifier.of("attacks_per_action", {"value": 2}, "Extra Attack", &"feature"))
	# Acrobatic Movement (Monk 9): walls and water on your turn, unarmored.
	if has(c, "acrobatic_movement") and unarmored:
		fx2.modifiers.append(Modifier.of("flag", {"value": "spider_climb"}, "Acrobatic Movement", &"feature"))
	# Battering Roots (World Tree 10): +10 ft reach with Heavy or Versatile melee weapons.
	if has(c, "battering_roots"):
		var main := ch.equipped("main_hand")
		var props := Gear.weapon_props(main)
		if not main.is_empty() and ("heavy" in props or "versatile" in props) and not Gear.is_ranged_weapon(main):
			fx2.modifiers.append(Modifier.of("reach", {"value": 10}, "Battering Roots", &"feature"))
	if has(c, "beguiling_twist"):
		fx2.modifiers.append(Modifier.of("advantage", {"on": "save_vs:charmed"}, "Beguiling Twist", &"feature"))
		fx2.modifiers.append(Modifier.of("advantage", {"on": "save_vs:frightened"}, "Beguiling Twist", &"feature"))
	if not fx2.modifiers.is_empty():
		c.creature.add_effect(fx2)


func turn_end(c: Combatant) -> void:
	# Inspiring Movement (College of Dance 6): an enemy ends its turn beside the bard: a Bardic Inspiration lets the
	# bard slip away half its Speed without provoking.
	var e := enc()
	for b in e.hostiles_of(c):
		if has(b, "inspiring_movement") and e.distance(b, c) <= 5 and e.spells.can_react(b) and _ch(b).resource_left("bardic_inspiration") > 0 \
				and str(b.reaction_rules.get("inspiring_movement", "auto")) != "never":
			b.reaction_available = false
			_ch(b).spend_resource("bardic_inspiration")
			var was := b.disengaged
			b.disengaged = true
			e.log.add("reaction", "%s dances away (Inspiring Movement)" % b.name(), b.id)
			e.flee(b, c, b.speed() / 2, CombatResult.new())
			b.disengaged = was
			break
	if raging(c) and not has(c, "persistent_rage") and str(c.get_meta("rage_kept", "")) != _turn_key():
		end_rage(c, "no attack, forced save or Bonus Action to keep it")
	if has(c, "self_restoration"):
		for cond: StringName in [&"charmed", &"frightened", &"poisoned"]:
			if c.creature.has_condition(cond):
				enc().spells.cure(c, cond)
				enc().log.add("info", "%s shakes off being %s (Self-Restoration)" % [c.name(), str(cond).capitalize()], c.id)
				break


# --- Spells ----------------------------------------------------------------------------------------------

## Spells an invocation lets a warlock cast without a slot at will.
const AT_WILL_INVOCATIONS := {"mage_armor": "armor_of_shadows", "levitate": "ascendant_step", "false_life": "fiendish_vigor",
	"disguise_self": "mask_of_many_faces", "alter_self": "master_of_myriad_forms", "silent_image": "misty_visions",
	"invisibility": "one_with_shadows", "jump": "otherworldly_leap", "arcane_eye": "visions_of_distant_realms", "speak_with_dead": "whispers_of_the_grave"}


static func at_will(c: Combatant, spell_id: String) -> bool:
	return AT_WILL_INVOCATIONS.has(spell_id) and knows_invocation(c, str(AT_WILL_INVOCATIONS[spell_id]))


## After a damaging Warlock cantrip hits (Repelling Blast, Grasp of Hadar, Lance of Lethargy).
func cantrip_hit(ctx: Dictionary, t: Combatant) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	if int(s.get("level", 0)) != 0 or not "warlock" in (s.get("classes", []) as Array) or not t.is_alive():
		return
	var e := enc()
	if knows_invocation(c, "repelling_blast") and Creature.SIZES.find(t.creature.size) <= Creature.SIZES.find(&"large"):
		e.forced_move(t, e.center_of(c), 10)
	if knows_invocation(c, "grasp_of_hadar") and _once(c, "grasp_of_hadar"):
		e.forced_move(t, e.center_of(c), 10, true)
	if knows_invocation(c, "lance_of_lethargy") and _once(c, "lance_of_lethargy"):
		var fx := _timed(c, "Lance of Lethargy", "lance_of_lethargy", Effect.Ends.START_OF_TURN, c).with_modifier("speed", {"value": -10})
		t.creature.add_effect(fx)


# --- More reactions and riders ------------------------------------------------------------------------------

## A hit about to land: Cutting Words against the attack roll (College of Lore), Combat Inspiration's AC (College of
## Valor) for a creature holding a Valor bard's die.
func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	if bool(st.get("critical", false)):
		return
	for b in e.allies_of(target):
		if has(b, "cutting_words") and _ch(b).resource_left("bardic_inspiration") > 0 and e.distance(b, c) <= 60 and e.can_see(b, c) \
				and t.total - bardic_die(b) < ac:
			var bard := b
			out.append({"kind": "cutting_words", "reactor": bard, "trigger": c.id, "title": "Reaction: Cutting Words?",
				"text": "%s hits %s (%d vs AC %d). %s can spend Bardic Inspiration to subtract a d%d from the roll." % [c.name(), target.name(), t.total, ac, bard.name(), bardic_die(bard)],
				"cost": "Reaction and a use of Bardic Inspiration",
				"still": func() -> bool: return e.spells.can_react(bard),
				"use": func() -> void:
					bard.reaction_available = false
					_ch(bard).spend_resource("bardic_inspiration")
					var cut := e.dice.roll_one(bardic_die(bard), "Cutting Words")
					t.add_bonus(-cut, "Cutting Words")
					e.log.add("reaction", "%s's Cutting Words: −%d (now %d)" % [bard.name(), cut, t.total], bard.id),
				"stop": func() -> CombatResult:
					if t.total < ac:
						return miss.call() as CombatResult
					return e._after_hit(st)})
			break
	for fx: Effect in target.creature.effects:
		if fx.source_id == "bardic_inspiration" and bool(fx.data.get("valor", false)) and e.spells.can_react(target):
			var die := int(fx.data.get("die", 6))
			if t.total - die >= ac:
				break
			var holder := target
			var fxi := fx
			out.append({"kind": "combat_inspiration", "reactor": holder, "trigger": c.id, "title": "Reaction: Combat Inspiration?",
				"text": "%s hits %s (%d vs AC %d). Roll the Bardic Inspiration die (d%d) and add it to AC?" % [c.name(), target.name(), t.total, ac, die],
				"still": func() -> bool: return e.spells.can_react(holder) and fxi in holder.creature.effects,
				"use": func() -> void:
					holder.reaction_available = false
					holder.creature.remove_effect(fxi)
					st["ac"] = ac + e.dice.roll_one(die, "Combat Inspiration")
					e.log.add("reaction", "%s raises AC to %d (Combat Inspiration)" % [holder.name(), int(st["ac"])], holder.id),
				"stop": func() -> CombatResult:
					if t.total < int(st["ac"]):
						return miss.call() as CombatResult
					return e._after_hit(st)})
			break


## A creature just took damage from `source`: Misty Escape (Archfey 6) is a reaction offer queued with the others.
func damage_reaction(source: Combatant, target: Combatant) -> Dictionary:
	if has(target, "misty_escape") and enc().spells.can_react(target) and target.creature.hp > 0 \
			and (_uses(target, "steps_of_the_fey", "Steps of the Fey", maxi(1, target.creature.ability_mod(&"cha")), "long") > 0 or _ch(target).slots_left(2) > 0):
		return {"kind": "misty_escape", "reactor": target.id, "trigger": source.id}
	return {}


func misty_escape(c: Combatant, from: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	c.reaction_available = false
	if ch.resource_left("steps_of_the_fey") > 0:
		ch.spend_resource("steps_of_the_fey")
	else:
		ch.expend_slot(2)
	var best := c.cell
	var bd := -1
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var cell := c.cell + Vector2i(dx, dy)
			if e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > 30 or not e.spells._room_for(cell, c.size_cells):
				continue
			var d := e.grid.distance_ft(from.cell, from.size_cells, cell, c.size_cells)
			if d > bd:
				bd = d
				best = cell
	var r := CombatResult.new()
	e.log.add("reaction", "%s vanishes in a silvery mist (Misty Escape)" % c.name(), c.id)
	var start := c.cell
	e.spells._teleport(c, best, r)
	fey_step_rider(c, start)
	return r


## Steps of the Fey's extra when the warlock teleports with Misty Step: Taunting Step if enemies stood beside where it
## left (Wisdom save or Disadvantage on attacks against anyone else), otherwise Refreshing Step (1d10 Temporary Hit
## Points).
func fey_step_rider(c: Combatant, from: Vector2i) -> void:
	if not has(c, "steps_of_the_fey"):
		return
	var e := enc()
	var dc := _spell_dc(c, "warlock")
	var taunted := false
	for o in e.hostiles_of(c):
		if not o.is_down() and e.grid.distance_ft(from, c.size_cells, o.cell, o.size_cells) <= 5:
			taunted = true
			if not _save(o, &"wis", dc, "Taunting Step"):
				e.add_mark({"kind": "disadvantage_next_attack", "attacker": o.id, "source": "Taunting Step", "expires_owner": c.id, "expires_phase": "start", "consume": false})
	if not taunted:
		_temp(c, e.dice.roll_one(10, "Refreshing Step"), "Refreshing Step")


## Restore Balance (Clockwork Sorcery 3): a sorcerer within 60 ft who sees the roller cancels an ally's Disadvantage or
## a foe's Advantage on a roll about to be made. Rolled straight it takes the first die (Charisma-modifier uses per
## Long Rest). The roll is settled before anyone could be asked, so it's never asked: it's used when it changes the
## result, unless turned Off (deviations.md).
func balance_offers(c: Combatant, t: D20Test, out: Array) -> void:
	var e := enc()
	if t.target <= 0 or not (t.advantage or t.disadvantage) or t.rolls.size() < 2:
		return
	for s in e.living():
		if not has(s, "restore_balance") or e.distance(s, c) > 60 or (s != c and not e.can_see(s, c)):
			continue
		var friendly := s == c or s.allied_with(c)
		if (friendly and not t.disadvantage) or (not friendly and not t.advantage):
			continue
		var sorc := s
		var helps := func() -> bool: return t.would_succeed_with(t.rolls[0]) != t.success and (t.disadvantage if friendly else t.advantage)
		out.append({"kind": "restore_balance", "reactor": s, "trigger": c.id, "ask": false, "title": "Reaction: Restore Balance?",
			"text": "%s is about to roll with %s." % [c.name(), "Disadvantage" if friendly else "Advantage"], "cost": "Reaction and a use of Restore Balance",
			"still": func() -> bool: return helps.call() and e.spells.can_react(sorc) \
				and _uses(sorc, "restore_balance", "Restore Balance", maxi(1, sorc.creature.ability_mod(&"cha")), "long") > 0,
			"use": func() -> void:
				_ch(sorc).spend_resource("restore_balance")
				sorc.reaction_available = false
				var first := t.rolls[0]
				t.rolls = [first]
				t.advantage = false
				t.disadvantage = false
				t.set_natural(first, "Restore Balance (%s)" % sorc.name())
				e.log.add("reaction", "%s restores balance to %s's roll" % [sorc.name(), c.name()], sorc.id, [t.describe()])})


## After a D20 Test (D20Responses): Cosmic Omen (Stars 6: Woe takes a d6 from a foe's roll that only just succeeded,
## Weal adds one to an ally's that only just failed; a roll about to be made, so never asked), Dark One's Own Luck
## (Fiend 6: 1d10 on its own check or save) and Bend Luck (Wild Magic 6: a Reaction and a Sorcery Point for 1d4 on
## another creature's roll, added for an ally, taken away from a foe).
func d20_offers(c: Combatant, t: D20Test, out: Array) -> void:
	var e := enc()
	if t.target <= 0:
		return
	for s in e.hostiles_of(c):
		if not has(s, "cosmic_omen") or str(s.get_meta("omen", "weal")) != "woe" or e.distance(s, c) > 30 or not e.can_see(s, c):
			continue
		var woe := s
		out.append({"kind": "cosmic_omen", "reactor": s, "trigger": c.id, "ask": false, "title": "Reaction: Cosmic Omen (Woe)?",
			"text": "%s is about to roll." % c.name(), "cost": "Reaction and a use of Cosmic Omen",
			"still": func() -> bool: return t.success and not t.critical and t.total - t.target < 6 and e.spells.can_react(woe) \
				and _uses(woe, "cosmic_omen", "Cosmic Omen", maxi(1, woe.creature.ability_mod(&"wis")), "long") > 0,
			"use": func() -> void:
				_ch(woe).spend_resource("cosmic_omen")
				woe.reaction_available = false
				t.add_bonus(-e.dice.roll_one(6, "Cosmic Omen (Woe)"), "Cosmic Omen (%s)" % woe.name())
				e.log.add("reaction", "%s reads woe in the stars for %s" % [woe.name(), c.name()], woe.id, [t.describe()])})
	var ch := _ch(c)
	if ch != null and has(c, "dark_ones_own_luck") and t.kind != D20Test.Kind.ATTACK_ROLL:
		out.append({"kind": "dark_ones_own_luck", "reactor": c, "title": "Dark One's Own Luck?",
			"text": func() -> String: return "%s. Add 1d10 to the roll?" % D20Responses.line(c, t),
			"cost": func() -> String: return "A use of Dark One's Own Luck (%d left)" % ch.resource_left("dark_ones_own_luck"), "spends_reaction": false,
			"still": func() -> bool: return not t.success and t.target - t.total <= 10 \
				and _uses(c, "dark_ones_own_luck", "Dark One's Own Luck", maxi(1, c.creature.ability_mod(&"cha")), "long") > 0,
			"use": func() -> void:
				ch.spend_resource("dark_ones_own_luck")
				t.add_bonus(e.dice.roll_one(10, "Dark One's Own Luck"), "Dark One's Own Luck")
				e.log.add("info", "%s calls on the Dark One's luck" % c.name(), c.id, [t.describe()])})
	for s in e.combatants:
		if s == c or not s.is_alive() or not has(s, "bend_luck") or _ch(s) == null or not e.can_see(s, c):
			continue
		var sorc := s
		var friendly := s.allied_with(c)
		out.append({"kind": "bend_luck", "reactor": s, "trigger": c.id, "sync": "auto" if friendly else "explicit",
			"title": "Reaction: Bend Luck?",
			"text": func() -> String: return "%s. %s can bend luck: 1d4 %s the roll." % [D20Responses.line(c, t), sorc.name(), "added to" if friendly else "taken from"],
			"cost": "Reaction and 1 Sorcery Point",
			"still": func() -> bool: return e.spells.can_react(sorc) and _ch(sorc).resource_left("sorcery_points") > 0 \
				and ((friendly and not t.success and t.target - t.total <= 4) or (not friendly and t.success and not t.critical and t.total - t.target <= 3)),
			"use": func() -> void:
				_ch(sorc).spend_resource("sorcery_points")
				sorc.reaction_available = false
				var v := e.dice.roll_one(4, "Bend Luck")
				t.add_bonus(v if friendly else -v, "Bend Luck (%s)" % sorc.name())
				e.log.add("reaction", "%s bends %s's luck" % [sorc.name(), c.name()], sorc.id, [t.describe()])})
	for s in e.allies_of(c):
		if not has(s, "cosmic_omen") or str(s.get_meta("omen", "weal")) != "weal" or e.distance(s, c) > 30 or not e.can_see(s, c):
			continue
		var weal := s
		out.append({"kind": "cosmic_omen", "reactor": s, "trigger": c.id, "ask": false, "title": "Reaction: Cosmic Omen (Weal)?",
			"text": "%s is about to roll." % c.name(), "cost": "Reaction and a use of Cosmic Omen",
			"still": func() -> bool: return not t.success and t.target - t.total <= 6 and e.spells.can_react(weal) \
				and _uses(weal, "cosmic_omen", "Cosmic Omen", maxi(1, weal.creature.ability_mod(&"wis")), "long") > 0,
			"use": func() -> void:
				_ch(weal).spend_resource("cosmic_omen")
				weal.reaction_available = false
				t.add_bonus(e.dice.roll_one(6, "Cosmic Omen (Weal)"), "Cosmic Omen (%s)" % weal.name())
				e.log.add("reaction", "%s reads weal in the stars for %s" % [weal.name(), c.name()], weal.id, [t.describe()])})


## After a spell with a slot: Beguiling Magic (Glamour 3), Wild Magic Surge (Wild Magic 3), Inspiring Smite (Glory 3),
## Smite of Protection (Devotion 7).
func after_cast(c: Combatant, s: Dictionary, slot: int) -> void:
	var e := enc()
	if slot <= 0 or not c.creature is Character:
		return
	var school := str(s.get("school", ""))
	if has(c, "beguiling_magic") and school in ["enchantment", "illusion"] and _uses(c, "beguiling_magic", "Beguiling Magic", 1, "long") > 0:
		var foe := _nearest_foe(c, 60)
		if foe != null:
			_ch(c).spend_resource("beguiling_magic")
			if not _save(foe, &"wis", _spell_dc(c, "bard"), "Beguiling Magic", "charmed"):
				var fx := _minutes(c, "Charmed (Beguiling Magic)", "beguiling_magic", 1).with_condition(&"charmed")
				fx.turn_owner_id = foe.id
				fx.repeat_save = {"ability": "wis", "dc": _spell_dc(c, "bard"), "when": "end"}
				foe.creature.add_effect(fx)
	if has(c, "wild_magic_surge") and "sorcerer" in (s.get("classes", []) as Array) and _once(c, "wild_surge"):
		var roll := e.dice.roll_one(20, "Wild Magic Surge")
		if roll == 20 or bool(c.get_meta("tides_used", false)):
			c.remove_meta("tides_used")
			_surge(c)
	if str(s.get("id", "")) == "divine_smite":
		if has(c, "inspiring_smite") and _ch(c).resource_left("paladin_channel_divinity") > 0 and str(c.reaction_rules.get("inspiring_smite", "auto")) != "never":
			_ch(c).spend_resource("paladin_channel_divinity")
			var pool := int(e._roll_damage_dice("2d8", false, 0, "Inspiring Smite")["total"]) + level_of(c, "paladin")
			var friends: Array[Combatant] = []
			for a in e.allies_of(c):
				if a.is_alive() and e.distance(c, a) <= 30:
					friends.append(a)
			for a in friends:
				_temp(a, pool / maxi(1, friends.size()), "Inspiring Smite")
		if has(c, "smite_of_protection"):
			for a in e.allies_of(c):
				if _in_aura(c, a):
					var cv := _timed(c, "Half Cover (Smite of Protection)", "smite_of_protection", Effect.Ends.START_OF_TURN, c).with_modifier("ac", {"value": 2}).with_modifier("save", {"ability": "dex", "value": 2})
					a.creature.add_effect(cv)


## A Wild Magic Surge (2024 table, condensed to its combat results): rolled on a d8.
func _surge(c: Combatant) -> void:
	var e := enc()
	var roll := e.dice.roll_one(8, "Wild Magic Surge table")
	e.log.add("spell", "Wild Magic surges around %s!" % c.name(), c.id)
	match roll:
		1:
			for o in e.living():
				if o != c and e.distance(c, o) <= 30:
					e.deal_damage(c, o, [{"amount": e.dice.roll_one(10, "Surge") + e.dice.roll_one(10, "Surge"), "type": "force"}], false, "Wild Magic Surge")
		2:
			_temp(c, e.dice.roll_one(10, "Surge") * 2, "Wild Magic Surge")
		3:
			var fx := _minutes(c, "Invisible (Wild Magic Surge)", "wild_magic_surge", 1).with_condition(&"invisible")
			fx.ends_on.append("attack_roll")
			fx.ends_on.append("cast_spell")
			c.creature.add_effect(fx)
		4:
			_heal(c, c, int(e.heal_roll("2d10", c, "Surge")["total"]), "Wild Magic Surge")
		5:
			var foe := _nearest_foe(c, 60)
			if foe != null:
				e.deal_damage(c, foe, [{"amount": int(e._roll_damage_dice("4d10", false, 0, "Surge")["total"]), "type": "lightning"}], false, "Wild Magic Surge")
		6:
			c.creature.add_effect(_minutes(c, "Resistance (Wild Magic Surge)", "wild_magic_surge", 1).with_modifier("resistance", {"value": "all"}))
		7:
			e.spells._teleport(c, e.spells._free_cell_near(c.cell + Vector2i(e.dice.roll_one(7, "Surge") - 4, e.dice.roll_one(7, "Surge") - 4), c.size_cells), CombatResult.new())
		_:
			for o in e.living():
				if o != c and e.distance(c, o) <= 30 and not o.creature.dead:
					o.creature.add_condition(&"prone", "Wild Magic Surge")
	if _ch(c).resources.has("tides_of_chaos"):
		_refund(_ch(c), "tides_of_chaos")
