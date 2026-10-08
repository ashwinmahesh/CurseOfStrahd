class_name D20Responses
extends RefCounted
## What can change a D20 Test once its die is rolled (2024 PHB and the book options): the roller's own features
## (Indomitable, Heroic Inspiration, Stroke of Luck, a Bardic Inspiration die...), an ally's Reaction (Bend Luck,
## Countercharm), items (Ring of Evasion, a Luck Blade) and a monster's Legendary Resistance. Each is an offer in the
## shape Reactions.offer takes ({kind, reactor, trigger, title, text, cost, still, use}), listed in the order they apply.
## A `forced` offer isn't a choice (Reliable Talent, a Dark Gift's drawback): it simply happens when its turn comes.
## An offer with `ask: false` answers a roll that's about to be made (Restore Balance, Cosmic Omen), so it is never
## asked about: it follows its rule, used when it would change the result unless turned Off (deviations.md).
##
## A roll made where the fight can pause (`then_after`: spells' saves, monsters' save actions, repeated saves, Death
## Saving Throws, attack rolls) asks the player about each offer, as attacks always have (F6). Anywhere else the roll
## can't wait, so each offer follows the creature's rule for it as it always has (`sync`): "auto" uses it unless the
## rule is "never" (the default), "explicit" only when the rule is "auto", "decision" only when
## Encounter._reaction_decision says "auto".

var _enc: WeakRef
## Rolls being made where the fight can pause: {id, offers, claimed}. The first D20 Test that creature rolls fills it.
var _open: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


# --- Rolls that can pause --------------------------------------------------------------------------

## Rolls `c`'s D20 Test with `roll` (a Callable returning it) and, once every offer that follows the roll has been
## answered, calls `after` with the test. Returns what `after` returns, or `r` paused on the first offer the player is
## asked about (the answer carries on from there, Encounter.answer_reaction).
func then_after(c: Combatant, roll: Callable, after: Callable, r: CombatResult) -> CombatResult:
	var col := collect(c)
	var test := roll.call() as D20Test
	var offers := collected(col)
	if offers.is_empty():
		return after.call(test) as CombatResult
	return enc().reactions.offer(offers, func() -> CombatResult: return after.call(test) as CombatResult, r)


## For a roll with its own steps between the roll and the offers (an attack): `collect(c)` before rolling, then
## `collected(col)` hands back the offers that follow it, to run with Reactions.offer.
func collect(c: Combatant) -> Dictionary:
	var col := {"id": c.id, "offers": [], "claimed": false}
	_open.append(col)
	return col


func collected(col: Dictionary) -> Array:
	if not _open.is_empty() and is_same(_open.back(), col):
		_open.pop_back()
	else:
		_open.erase(col)
	return col["offers"] as Array


## The hook every creature's d20_after leads to (FeatureActions.after_d20): the offers go to a roll that can pause, or
## are settled now.
func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	var offers := offers_for(c, t, keys)
	if not _open.is_empty():
		var top := _open.back() as Dictionary
		if str(top["id"]) == c.id and not bool(top["claimed"]):
			top["claimed"] = true
			(top["offers"] as Array).append_array(offers)
			return
	run_now(offers)


## Settles offers where the roll can't wait: each by its `sync` rule (see above).
func run_now(offers: Array) -> void:
	for raw: Variant in offers:
		var o := raw as Dictionary
		if o.has("still") and not (o["still"] as Callable).call():
			continue
		if bool(o.get("forced", false)) or sync_allows(o):
			(o["use"] as Callable).call()


## Whether an offer is taken where nobody can be asked: by its `sync` rule.
func sync_allows(o: Dictionary) -> bool:
	var reactor := o["reactor"] as Combatant
	var kind := str(o["kind"])
	match str(o.get("sync", "auto")):
		"explicit":
			return str(reactor.reaction_rules.get(kind, "never")) == "auto"
		"decision":
			return enc()._reaction_decision(reactor, kind) == "auto"
	return str(reactor.reaction_rules.get(kind, "auto")) != "never"


# --- The offers ------------------------------------------------------------------------------------

## Every offer that could follow `c`'s roll `t`, in the order they apply.
func offers_for(c: Combatant, t: D20Test, keys: Array[String]) -> Array:
	var e := enc()
	var out: Array = []
	if c == null:
		return out
	e.class_features.balance_offers(c, t, out)
	if c.creature is Character:
		_reliable_talent(c, t, keys, out)
	e.feature_recipes.d20_offers(c, t, keys, out)
	e.class_features.d20_offers(c, t, out)
	e.ravenloft.d20_offers(c, t, keys, out)
	e.faerun.d20_offers(c, t, keys, out)
	e.items.d20_offers(c, t, keys, out)
	e.legendary.d20_offers(c, t, out)
	if c.creature is Character:
		_own_offers(c, t, keys, out)
	e.spells.d20_offers(c, t, out)
	return out


## Reliable Talent (Rogue 7): a skill check it's proficient in treats a d20 of 9 or lower as 10.
func _reliable_talent(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	if t.kind != D20Test.Kind.ABILITY_CHECK or not CombatFeatures.has_feature(c, "reliable_talent"):
		return
	var ch := c.creature as Character
	for k in keys:
		if k.begins_with("check:") and Abilities.SKILLS.has(StringName(k.substr(6))) and ch.skill_rank(StringName(k.substr(6))) > 0:
			out.append({"kind": "reliable_talent", "reactor": c, "forced": true, "use": func() -> void: t.floor_natural(10, "Reliable Talent")})
			return


## The roller's own choices after a failure: Countercharm and Fanatical Focus (ClassFeatures), a Bardic Inspiration
## die, Tactical Mind on checks, Indomitable, Mage Slayer's Guarded Mind, Stroke of Luck and Heroic Inspiration on saves.
func _own_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	var ch := c.creature as Character
	if t.target <= 0:
		return
	if t.kind == D20Test.Kind.SAVING_THROW:
		e.class_features.failed_save_offers(c, t, keys, out)
	# A die someone gave this creature (Bardic Inspiration): added to a failed D20 Test, then gone.
	for fx: Effect in ch.effects:
		for m in fx.modifiers:
			if m.stat != &"inspiration_die":
				continue
			var die := m.text("dice", "1d6")
			var source := m.source_name
			var given := fx
			out.append({"kind": "inspiration", "reactor": c, "title": "%s?" % source,
				"text": "%s. Roll the %s die (%s) and add it to the roll?" % [line(c, t), source, die],
				"cost": "The %s die" % source, "spends_reaction": false,
				"still": func() -> bool: return not t.success and given in c.creature.effects,
				"helps": func() -> bool: return not t.natural_one and t.total + most(die) >= t.target,
				"use": func() -> void:
					var v := e.dice.roll_expr(die, source)
					t.add_bonus(int(v["total"]), source)
					c.creature.remove_effect(given)
					e.log.add("info", "%s adds %s (%d)" % [c.name(), source, int(v["total"])], c.id)})
			break
	var luck_kind := "stroke_of_luck"
	var stroke := {"kind": luck_kind, "reactor": c, "title": "Stroke of Luck?",
		"text": "%s. Turn the d20 into a 20?" % line(c, t),
		"cost": "Stroke of Luck (once per Short or Long Rest)", "spends_reaction": false,
		"still": func() -> bool: return not t.success and ch.resource_left("stroke_of_luck") > 0,
		"helps": func() -> bool: return could_reach(t),
		"use": func() -> void:
			ch.spend_resource("stroke_of_luck")
			t.set_natural(20, "Stroke of Luck")
			e.log.add("info", "%s's luck turns the roll into a 20 (Stroke of Luck)" % c.name(), c.id, [t.describe()])}
	if t.kind == D20Test.Kind.ABILITY_CHECK:
		if CombatFeatures.has_feature(c, "tactical_mind"):
			out.append({"kind": "tactical_mind", "reactor": c, "title": "Tactical Mind?",
				"text": "%s. Roll 1d10 and add it? A use of Second Wind is spent only if the check then succeeds." % line(c, t),
				"cost": "A use of Second Wind if it works (%d left)" % ch.resource_left("second_wind"), "spends_reaction": false,
				"still": func() -> bool: return not t.success and ch.resource_left("second_wind") > 0,
				"helps": func() -> bool: return t.total + 10 >= t.target,
				"use": func() -> void:
					var v := e.dice.roll_one(10, "Tactical Mind")
					t.add_bonus(v, "Tactical Mind")
					if t.success:
						ch.spend_resource("second_wind")
					e.log.add("info", "%s thinks it through: +%d (Tactical Mind%s)" % [c.name(), v, "" if t.success else ", still short: no use spent"], c.id)})
		# Stroke of Luck on a check: the game only spends it on its own when it's set to Automatic.
		if CombatFeatures.has_feature(c, "stroke_of_luck"):
			stroke["sync"] = "explicit"
			out.append(stroke)
		return
	if t.kind == D20Test.Kind.ATTACK_ROLL:
		if CombatFeatures.has_feature(c, "stroke_of_luck"):
			stroke["sync"] = "explicit"
			out.append(stroke)
		return
	if CombatFeatures.has_feature(c, "indomitable"):
		var lvl := ch.class_level_of("fighter")
		out.append({"kind": "indomitable", "reactor": c, "title": "Indomitable?",
			"text": "%s. Reroll the save with +%d and use the new roll?" % [line(c, t), lvl],
			"cost": "A use of Indomitable (%d left)" % ch.resource_left("indomitable"), "spends_reaction": false,
			"still": func() -> bool: return not t.success and ch.resource_left("indomitable") > 0,
			"helps": func() -> bool: return could_reach(t, 20, lvl),
			"use": func() -> void:
				ch.spend_resource("indomitable")
				t.reroll(e.dice, "Indomitable", false, c.creature.has_flag("luck"))
				t.add_bonus(lvl, "Indomitable")
				e.log.add("info", "%s refuses to fall: Indomitable reroll" % c.name(), c.id, [t.describe()])})
	if e.features.has_feat(c, "mage_slayer") and ("save:int" in keys or "save:wis" in keys or "save:cha" in keys):
		out.append({"kind": "guarded_mind", "reactor": c, "title": "Guarded Mind?",
			"text": "%s. Succeed on the save instead?" % line(c, t),
			"cost": "Guarded Mind (once per Short or Long Rest)", "spends_reaction": false,
			"still": func() -> bool: return not t.success and ch.resource_left("guarded_mind") > 0,
			"use": func() -> void:
				ch.spend_resource("guarded_mind")
				t.add_bonus(maxi(0, t.target - t.total), "Guarded Mind")
				e.log.add("info", "%s's Guarded Mind turns the failure into a success" % c.name(), c.id)})
	if CombatFeatures.has_feature(c, "stroke_of_luck"):
		out.append(stroke)
	out.append({"kind": "heroic_inspiration", "reactor": c, "title": "Heroic Inspiration?",
		"text": "%s. Spend Heroic Inspiration to reroll the d20 and use the new roll?" % line(c, t),
		"cost": "Heroic Inspiration (regained on a Long Rest)", "spends_reaction": false,
		"still": func() -> bool: return not t.success and ch.heroic_inspiration,
		"helps": func() -> bool: return could_reach(t),
		"use": func() -> void:
			ch.heroic_inspiration = false
			t.reroll_one(e.dice.d20("Heroic Inspiration"), "Heroic Inspiration")
			e.log.add("info", "%s spends Heroic Inspiration on the save" % c.name(), c.id, [t.describe()])})


# --- The class tab's rules for them ----------------------------------------------------------------

## The choices after a roll this creature can make, for the class abilities tab (Reactions.configurable_policies):
## {id, name, cost, modes, help, default}. Data-defined responses and Reaction spells are listed there already.
func policies(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var e := enc()
	var ch := c.creature as Character
	var ask := "Ask: the fight stops to ask when it could change the roll. Automatic: used whenever it could. Off: never. A roll that can't wait uses it unless it's Off."
	var add := func(id: String, name: String, cost: String) -> void:
		out.append({"id": id, "name": name, "cost": cost, "help": "%s. %s" % [cost, ask]})
	add.call("heroic_inspiration", "Heroic Inspiration", "Heroic Inspiration")
	if CombatFeatures.has_feature(c, "indomitable"):
		add.call("indomitable", "Indomitable", "A use of Indomitable")
	if CombatFeatures.has_feature(c, "stroke_of_luck"):
		add.call("stroke_of_luck", "Stroke of Luck", "Stroke of Luck")
	if CombatFeatures.has_feature(c, "tactical_mind"):
		add.call("tactical_mind", "Tactical Mind", "A use of Second Wind")
	if e.features.has_feat(c, "mage_slayer"):
		add.call("guarded_mind", "Guarded Mind", "Guarded Mind")
	if CombatFeatures.has_feature(c, "dark_ones_own_luck"):
		add.call("dark_ones_own_luck", "Dark One's Own Luck", "A use of Dark One's Own Luck")
	if CombatFeatures.has_feature(c, "bend_luck"):
		add.call("bend_luck", "Bend Luck", "Your Reaction and 1 Sorcery Point")
	if CombatFeatures.has_feature(c, "countercharm"):
		add.call("countercharm", "Countercharm", "Your Reaction")
	if CombatFeatures.has_feature(c, "fanatical_focus"):
		add.call("fanatical_focus", "Fanatical Focus", "Once per Rage")
	if ch.effects.any(func(fx: Effect) -> bool: return fx.modifiers.any(func(m: Modifier) -> bool: return m.stat == &"inspiration_die")):
		add.call("inspiration", "Bardic Inspiration die", "The die")
	for kind: String in ["restore_balance", "cosmic_omen"]:
		if CombatFeatures.has_feature(c, kind):
			out.append({"id": kind, "name": kind.capitalize(), "cost": "Your Reaction", "modes": ["auto", "never"], "default": "auto",
				"help": "Your Reaction. It answers a roll about to be made, so it's never asked: Automatic uses it when it would change the result. Off: never."})
	var items := e.items
	for id: String in ["ring_of_evasion", "ring_of_dedicated_focus", "scholars_anchoring_bangle"]:
		if items.has_active(c, id):
			add.call(id, str(Compendium.shared().item_data(id).get("name", id.capitalize())), "Its charge or use")
	for it in items.carried(c):
		if str(it["id"]) == "lucky_foot" or str((it["data"] as Dictionary).get("template_id", "")) == "luck_blade":
			var kind2 := "lucky_foot" if str(it["id"]) == "lucky_foot" else "luck_blade"
			add.call(kind2, str((it["data"] as Dictionary).get("name", kind2.capitalize())), "Its use")
	for id2: String in ["survivor_resolve", "symbiote_vigor", "mist_step", "knowledge_from_a_past_life"]:
		if CombatFeatures.has_feature(c, id2) or (id2 == "survivor_resolve" and e.ravenloft.feat(c, "survivor")):
			add.call(id2, {"survivor_resolve": "Steel Yourself"}.get(id2, id2.capitalize()), "A use of it")
	return out


# --- Whether asking is worth it --------------------------------------------------------------------

## Whether `t` could still succeed with the d20 showing `natural` and `bonus` more: a reroll worth asking about. An
## attack roll can always crit.
static func could_reach(t: D20Test, natural: int = 20, bonus: int = 0) -> bool:
	if t.kind == D20Test.Kind.ATTACK_ROLL and natural >= t.crit_range:
		return true
	return natural + t.modifier + t.extra + bonus >= t.target


## The most a dice expression can add ("1d6" 6, "2d4+1" 9).
static func most(expr: String) -> int:
	var p := DiceRoller.parse_expr(expr)
	return int(p["count"]) * int(p["sides"]) + int(p["modifier"])


# --- Words for the prompts -------------------------------------------------------------------------

## The roll as a prompt states it: "Thorn fails: Wisdom save vs Hold Person, 9 vs DC 14".
static func line(c: Combatant, t: D20Test) -> String:
	if t.kind == D20Test.Kind.ATTACK_ROLL:
		return "%s: %d vs AC %d, %s" % [t.label if t.label != "" else "%s's attack" % c.name(), t.total, t.target, "a hit" if t.success else "a miss"]
	var what := t.label.trim_suffix(" (%s)" % c.name()) if t.label != "" else ("a check" if t.kind == D20Test.Kind.ABILITY_CHECK else "a save")
	return "%s %s: %s, %d vs DC %d" % [c.name(), "succeeds" if t.success else "fails", what, t.total, t.target]
