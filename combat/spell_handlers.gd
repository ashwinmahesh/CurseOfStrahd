class_name SpellHandlers
extends RefCounted
## Spells whose fight rules are code here beyond the data recipe (SpellCaster.SPECIAL): Magic Missile, Sleep, Command,
## Sanctuary, Spare the Dying, Misty Step's teleport, Revivify, Arcane Vigor, Dispel Magic, True Strike, and Booming
## Blade and Green-Flame Blade.

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func _comp() -> Compendium:
	return Compendium.shared()


## Magic Missile: darts that always hit, 1d4 + 1 Force each, split as the caster chooses. A target that can cast
## Shield may do so when targeted, and then takes no damage from the darts.
func _magic_missile(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var e := enc()
	var darts := spells.target_count(ctx["s"] as Dictionary, int(ctx["slot"]))
	var seen := {}
	for t in tgt:
		if seen.has(t.id):
			continue
		seen[t.id] = true
		if spells.can_cast_reaction(t, "shield") and not t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "shield"):
			var decision := e._reaction_decision(t, "shield")
			if decision == "auto":
				spells.cast_shield(t)
	for i in darts:
		var t := tgt[i % tgt.size()]
		if not t.is_alive():
			continue
		if t.creature.effects.any(func(x: Effect) -> bool: return x.source_id == "shield"):
			r.lines.append(e.log.add("miss", "Shield blocks a dart", t.id))
			continue
		var rolled := e._roll_damage_dice("1d4+1", false, 0, "Magic Missile dart")
		var bonus := spells.damage._damage_bonus(ctx)
		# One damage roll's bonuses ride the first dart (Empowered Evocation; Evocation Adept, Arcane Overload).
		var first := bonus.total() + e.faerun.spell_damage_bonus(ctx, bonus) if i == 0 else 0
		spells.deal_spell_damage(ctx, t, [{"amount": int(rolled["total"]) + first, "type": "force"}], false, "Magic Missile",
			["Dart %d: %s" % [i + 1, rolled["text"]]])


## Sleep (2024): creatures of your choice in the Sphere make a Wisdom save or are Incapacitated until the end of
## their next turn, then repeat the save; a second failure means Unconscious for the duration. Ends on damage or
## when someone shakes them awake. Creatures that don't sleep or are immune to Exhaustion are unaffected. `pausable`:
## each save stops for the choices after its roll (Heroic Inspiration...), the caller carrying on with Encounter.then.
func _sleep(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult, pausable: bool = false) -> CombatResult:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var e := enc()
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var conc := ctx["conc"] as Concentration
	var one := func(raw: Variant) -> CombatResult:
		var t := raw as Combatant
		if t == c or c.allied_with(t):
			return r
		if t.creature.is_condition_immune(&"exhaustion") or t.creature.has_flag("trance") or t.creature.creature_type in [&"undead", &"construct"]:
			r.lines.append(e.log.add("info", "%s doesn't sleep: unaffected" % t.name(), t.id))
			return r
		var roll := func() -> D20Test:
			return t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Sleep (%s)" % t.name(), SpellCaster.spell_save_keys(c.id))
		var after := func(test: D20Test) -> CombatResult:
			if test.success:
				r.lines.append(e.log.add("info", "%s shrugs off Sleep" % t.name(), t.id, [test.describe()]))
				return r
			var fx := Effect.new("Drowsy (Sleep)", &"spell", "sleep").with_condition(&"incapacitated")
			fx.caster_id = c.id
			fx.ends_on_damage = true
			fx.repeat_save = {"ability": "wis", "dc": dc, "then": "sleep_unconscious", "when": "end"}
			fx.stack_key = "sleep:%s" % t.id
			fx.data = {"wakeable": true}
			conc.attach(t.creature, fx)
			r.lines.append(e.log.add("condition", "%s is Incapacitated by Sleep" % t.name(), t.id, [test.describe()]))
			return r
		if pausable:
			return e.d20.then_after(t, roll, after, r)
		return after.call(roll.call() as D20Test) as CombatResult
	var sleepers := spells.creatures_in(cells)
	if not pausable:
		for t in sleepers:
			one.call(t)
		return r
	return e.each(sleepers, one, func() -> CombatResult: return r)


## Command (2024): one word; on a failed Wisdom save the target obeys on its next turn. Approach: moves toward you
## by the shortest route and ends its turn within 5 ft. Drop: drops what it holds and ends its turn. Flee: spends
## its turn moving away. Grovel: falls Prone and ends its turn. Halt: doesn't move or act. `pausable` as for Sleep.
func _command(ctx: Dictionary, t: Combatant, word: String, r: CombatResult, pausable: bool = false) -> CombatResult:
	var c := ctx["c"] as Combatant
	var e := enc()
	if not word in SpellCaster.COMMAND_WORDS:
		word = "grovel"
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	if t.creature.is_condition_immune(&"charmed"):
		r.lines.append(e.log.add("info", "%s can't be commanded (immune to Charmed)" % t.name(), t.id))
		return r
	var roll := func() -> D20Test:
		return t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Command (%s)" % t.name(), SpellCaster.spell_save_keys(c.id))
	var after := func(test: D20Test) -> CombatResult:
		if test.success:
			r.lines.append(e.log.add("info", "%s ignores the command" % t.name(), t.id, [test.describe()]))
			return r
		var fx := Effect.new("Commanded: %s" % word.capitalize(), &"spell", "command").with_modifier("flag", {"value": "command_" + word})
		fx.caster_id = c.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = t.id
		fx.stack_key = "spell:command"
		t.creature.add_effect(fx)
		r.lines.append(e.log.add("condition", "%s obeys: %s" % [t.name(), word.capitalize()], t.id, [test.describe()]))
		return r
	if pausable:
		return e.d20.then_after(t, roll, after, r)
	return after.call(roll.call() as D20Test) as CombatResult


## Suggestion and Mass Suggestion (2024): a creature that can hear and understand you makes a Wisdom save or is
## Charmed and carries out the suggestion until anyone on your side hurts it, its caster's Concentration ends, or it's
## done. In a fight the game offers four, the way Command offers its words (docs/rules/deviations.md): Stand aside
## (it stops fighting and makes no Opportunity Attacks), Go home (it walks off and leaves the fight), Sit (it drops
## what it holds and sits, Prone) and Come with me (it follows its caster and does nothing else). `pausable` as for
## Sleep.
const SUGGESTIONS := {"stand_aside": ["indifferent", "no_opportunity_attacks"], "go_home": ["suggest_leave", "no_opportunity_attacks"],
	"sit": ["suggest_sit", "no_opportunity_attacks"], "follow": ["suggest_follow", "no_opportunity_attacks"]}
const SUGGESTION_NAMES := {"stand_aside": "Stand aside", "go_home": "Go home", "sit": "Put that down and sit", "follow": "Come with me"}


func _suggestion(ctx: Dictionary, t: Combatant, kind: String, r: CombatResult, pausable: bool = false) -> CombatResult:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	if not kind in SUGGESTIONS:
		kind = "stand_aside"
	if t == c or c.allied_with(t):
		return r
	if not understands(t.creature):
		r.lines.append(e.log.add("info", "%s can't understand the suggestion" % t.name(), t.id))
		return r
	if t.creature.is_condition_immune(&"charmed"):
		r.lines.append(e.log.add("info", "%s can't be charmed" % t.name(), t.id))
		return r
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var roll := func() -> D20Test:
		return t.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs %s (%s)" % [s["name"], t.name()], SpellCaster.spell_save_keys(c.id))
	var after := func(test: D20Test) -> CombatResult:
		if test.success:
			r.lines.append(e.log.add("info", "%s ignores the suggestion" % t.name(), t.id, [test.describe()]))
			return r
		var fx := Effect.new("%s: %s" % [s["name"], SUGGESTION_NAMES[kind]], &"spell", str(s["id"])).with_condition(&"charmed")
		for flag: String in SUGGESTIONS[kind]:
			fx = fx.with_modifier("flag", {"value": flag})
		fx.caster_id = c.id
		fx.ends_on.append("damaged_by_caster_side")
		fx.stack_key = "spell:suggestion:%s" % t.id
		var conc := ctx.get("conc", null) as Concentration
		if conc != null:
			conc.attach(t.creature, fx)
		else:
			t.creature.add_effect(fx)
		r.lines.append(e.log.add("condition", "%s takes the suggestion: %s" % [t.name(), SUGGESTION_NAMES[kind]], t.id, [test.describe()]))
		e.events.append({"type": "condition", "id": t.id})
		return r
	if pausable:
		return e.d20.then_after(t, roll, after, r)
	return after.call(roll.call() as D20Test) as CombatResult


## Whether `cr` can hear and understand a spoken suggestion: a creature with a language that isn't Deafened.
static func understands(cr: Creature) -> bool:
	if cr.has_condition(&"deafened"):
		return false
	if cr is Monster:
		return not ((cr as Monster).data.get("languages", []) as Array).is_empty()
	return true


func _sanctuary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var fx := Effect.new("Sanctuary", &"spell", "sanctuary").lasting({"kind": "minutes", "amount": 1})
	fx.caster_id = c.id
	fx.turn_owner_id = c.id
	fx.repeat_save = {"ability": "wis", "dc": (ctx["nums"]["dc"] as Breakdown).total(), "when": "never"}
	t.creature.add_effect(fx)
	r.lines.append(enc().log.add("condition", "%s is warded by Sanctuary" % t.name(), t.id))


## Sanctuary ends when the warded creature attacks, casts a spell or deals damage.
func end_sanctuary(t: Combatant, why: String) -> void:
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_id == "sanctuary":
			t.creature.remove_effect(fx)
			enc().log.add("info", "%s's Sanctuary ends (%s)" % [t.name(), why], t.id)


## Sanctuary check when `attacker` targets `target` with an attack roll or a damaging spell: "" if it may go ahead,
## otherwise why not. A failed save holds for the rest of the attacker's turn (it must pick someone else).
func sanctuary_blocks(attacker: Combatant, target: Combatant) -> String:
	var e := enc()
	for m in e.marks:
		if str(m["kind"]) == "sanctuary_failed" and str(m["attacker"]) == attacker.id and str(m["target"]) == target.id:
			return "Sanctuary: %s can't bring itself to target %s this turn" % [attacker.name(), target.name()]
	for fx: Effect in target.creature.effects:
		if fx.source_id == "sanctuary" and attacker.hostile_to(target):
			var dc := int(fx.repeat_save.get("dc", 13))
			var test := attacker.creature.roll_save(e.dice, &"wis", dc, [], [], "Wisdom save vs Sanctuary (%s)" % attacker.name(), SpellCaster.spell_save_keys(fx.caster_id))
			if test.success:
				e.log.add("info", "%s pushes past %s's Sanctuary" % [attacker.name(), target.name()], attacker.id, [test.describe()])
				return ""
			e.add_mark({"kind": "sanctuary_failed", "attacker": attacker.id, "target": target.id,
				"source": "Sanctuary", "expires_owner": e.current().id if e.current() != null else attacker.id, "expires_phase": "end"})
			e.log.add("info", "%s can't bring itself to attack %s (Sanctuary)" % [attacker.name(), target.name()], attacker.id, [test.describe()])
			return "Sanctuary: choose another target"
	return ""


func _spare_the_dying(_ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	if t.creature.hp > 0 or t.creature.dead:
		r.lines.append(enc().log.add("info", "%s isn't dying" % t.name(), t.id))
		return
	t.creature.stabilize()
	r.lines.append(enc().log.add("heal", "%s is Stable" % t.name(), t.id))


## Misty Step: teleport to an unoccupied square you can see within 30 ft (no Opportunity Attacks).
func _teleport(c: Combatant, cell: Vector2i, r: CombatResult) -> void:
	var spells := sp()
	var e := enc()
	# Dimensional Shackles: no teleporting while bound in them (the action or spell is spent).
	if c.creature.has_flag("no_teleport"):
		r.lines.append(e.log.add("info", "%s can't teleport: the Dimensional Shackles hold them" % c.name(), c.id))
		return
	var from := c.cell
	c.cell = cell
	c.clear_run()
	e.events.append({"type": "teleport", "id": c.id, "from": from, "to": cell})
	r.lines.append(e.log.add("move", "%s teleports %d ft" % [c.name(), e.grid.distance_ft(from, c.size_cells, cell, c.size_cells)], c.id))
	free_on_teleport(c)
	spells.zones.on_moved(c, from)


## A teleport leaves behind whatever held `c` in its place (owner ask 2026-10-12: Misty Step out of a web): a grapple,
## now out of reach, and a Restrained or Grappled from a place or a holder (a web or an area's grasp, a net, a Giant
## Spider's webbing: an effect with an escape check, an area's, or one a battle object holds). Conditions of the body or
## mind (Hold Person, a curse) stay. The AI's teleports do the same.
func free_on_teleport(c: Combatant) -> void:
	var e := enc()
	e.grappling.check_range(c)
	var held_by_object := {}
	for o in e.objects.list:
		if not o.destroyed and o.holds == c.id:
			held_by_object[o.hold_source] = o
	var freed: Array[String] = []
	for fx: Effect in c.creature.effects.duplicate():
		if not (&"restrained" in fx.conditions or &"grappled" in fx.conditions):
			continue
		if not fx.escape.is_empty() or fx.stack_key.begins_with("zone:") or held_by_object.has(fx.source_id):
			c.creature.remove_effect(fx)
			freed.append(fx.name)
	if not freed.is_empty():
		e.log.add("info", "%s slips free of %s" % [c.name(), ", ".join(freed)], c.id)
		e.events.append({"type": "condition", "id": c.id})


## Why Revivify can't bring `t` back ("" when it can): dead for more than a minute (10 rounds), or Undead or a Construct.
## The spell's targeting asks before anything is spent (SpellTargeting).
static func revivify_why(e: Encounter, t: Combatant) -> String:
	var died := int(t.get_meta("died_round", e.round_no)) if t.has_meta("died_round") else e.round_no
	if e.round_no - died > 10:
		return "%s has been dead too long for Revivify" % t.name()
	if t.creature.creature_type in [&"undead", &"construct"]:
		return "Revivify can't restore %s" % t.name()
	return ""


## Revivify: a creature that died within the last minute returns with 1 Hit Point.
func _revivify(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var why := SpellHandlers.revivify_why(e, t)
	if why != "":
		r.lines.append(e.log.add("info", why, t.id))
		return
	t.creature.dead = false
	t.creature.death_failures = 0
	t.creature.death_successes = 0
	t.creature.hp = 0
	t.creature.heal(1, str((ctx["s"] as Dictionary)["name"]))
	r.lines.append(e.log.add("heal", "%s returns to life with 1 Hit Point" % t.name(), t.id))
	e.events.append({"type": "heal", "id": t.id, "amount": 1})


## Arcane Vigor: spend up to two unspent Hit Point Dice (+1 per slot level above 2): roll them and heal the total
## plus your spellcasting ability modifier.
func _arcane_vigor(ctx: Dictionary, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var e := enc()
	if spells.caster_char(c) == null:
		return
	var ch := spells.caster_char(c)
	var want := 2 + maxi(0, int(ctx["slot"]) - 2)
	var total := 0
	var rolls: Array[String] = []
	var hd := ch.hit_dice()
	var dice: Array = hd.keys()
	dice.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) > int(b))
	for die: Variant in dice:
		var entry := hd[die] as Dictionary
		var left := int(entry["total"]) - int(entry["spent"])
		while want > 0 and left > 0:
			ch.hit_dice_spent[str(die)] = int(ch.hit_dice_spent.get(str(die), 0)) + 1
			var v := maxi(e.dice.roll_one(int(die), "Arcane Vigor (d%s)" % die), e.heal_floor(c))
			total += v
			rolls.append("d%s: %d" % [die, v])
			left -= 1
			want -= 1
	if rolls.is_empty():
		r.lines.append(e.log.add("info", "%s has no Hit Point Dice left to spend" % c.name(), c.id))
		return
	var amount := total + int((ctx["nums"] as Dictionary)["mod"])
	var healed := c.creature.heal(amount, "Arcane Vigor")
	r.lines.append(e.log.add("heal", "%s spends %d Hit Point Dice and regains %d Hit Points" % [c.name(), rolls.size(), healed], c.id, rolls))
	e.events.append({"type": "heal", "id": c.id, "amount": healed})


## Dispel Magic: ends spells of the slot level or lower on the target (higher ones need a check, DC 10 + their
## level, with the spellcasting ability), including areas it is the caster of.
func _dispel(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var spells := sp()
	var c := ctx["c"] as Combatant
	var e := enc()
	var slot := int(ctx["slot"])
	var ab := StringName(str((ctx["nums"] as Dictionary).get("ability", "int")))
	var ended: Array[String] = []
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_kind != &"spell":
			continue
		if fx.spell_level > slot:
			var test := c.creature.roll_check(e.dice, ab, 10 + fx.spell_level)
			# Spell Breaker (Abjurer 10): Proficiency Bonus on the check.
			if CombatFeatures.has_feature(c, "spell_breaker"):
				test.add_bonus(c.creature.proficiency_bonus(), "Spell Breaker")
			if not test.success:
				ctx["dispel_failed"] = true
				continue
		t.creature.remove_effect(fx)
		if fx.concentration != null and fx.concentration.source_id == fx.source_id:
			fx.concentration.end("dispelled")
		ended.append(fx.name)
	if t.creature.concentration != null:
		var cid := t.creature.concentration.source_id
		var lvl := int(_comp().spell_data(cid).get("level", 1))
		if lvl <= slot:
			t.creature.concentration.end("dispelled")
			ended.append(_comp().spell_data(cid).get("name", cid))
	spells.zones.prune()
	spells._prune_sustained()
	r.lines.append(e.log.add("spell", "Dispel Magic on %s: %s" % [t.name(), ", ".join(ended) if not ended.is_empty() else "nothing to end"], c.id))
	# Spell Breaker: a Dispel Magic that fails to end a spell gives the slot back.
	if bool(ctx.get("dispel_failed", false)) and CombatFeatures.has_feature(c, "spell_breaker") and slot > 0 and spells.caster_char(c) != null:
		var cch := spells.caster_char(c)
		if cch.slots_used[slot - 1] > 0:
			cch.slots_used[slot - 1] -= 1
			e.log.add("info", "%s keeps the spell slot (Spell Breaker)" % c.name(), c.id)


## True Strike (2024): a weapon attack using the spellcasting ability for attack and damage, Radiant or the
## weapon's type, +1d6 Radiant at level 5 (2d6 at 11, 3d6 at 17).
func _true_strike(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var e := enc()
	var best := {}
	for o in e.attack_options(c):
		if str(o["kind"]) == "weapon" and e.attack_legal(c, t, o) == "":
			best = o
			break
	if best.is_empty():
		r.lines.append(e.log.add("info", "True Strike: no weapon can reach %s" % t.name(), c.id))
		return
	var tier := Spellcasting.cantrip_tier(c.creature.character_level())
	var opt := best.duplicate()
	var p := (best["profile"] as WeaponProfile).with_ability(StringName(str((ctx["nums"] as Dictionary)["ability"])), c.creature)
	if str(ctx.get("choice", "")) == "radiant":
		p.damage_type = &"radiant"
	opt["profile"] = p
	var sub := e._resolve_attack(c, t, opt, {"extra_dice": [{"dice": "%dd6" % tier, "type": "radiant", "label": "True Strike"}] if tier > 0 else []})
	r.hit = sub.hit
	r.damage += sub.damage


## The melee weapon attack a blade cantrip makes against `t`: the first melee weapon option that can strike it
## (Psychic Blades and Unarmed Strikes aren't weapons), or {}.
func blade_option(c: Combatant, t: Combatant) -> Dictionary:
	var e := enc()
	if e.distance(c, t) > 5:
		return {}
	for o in e.attack_options(c):
		if str(o["kind"]) == "weapon" and bool(o["melee"]) and e.attack_legal(c, t, o) == "":
			return o
	return {}


## Booming Blade and Green-Flame Blade (Tasha's Cauldron): one melee attack with a weapon, using the weapon's own
## numbers; from level 5 a hit adds 1d8 of the spell's type per tier. Booming Blade then wraps the target in thunder
## until the start of the caster's next turn (booming_moved); Green-Flame Blade's fire leaps to another enemy the caster
## can see within 5 ft of the target, for the tier's d8s + the spellcasting modifier. The game picks the creature the
## fire leaps to: the enemy nearest to dropping (deviations.md).
func _blade_cantrip(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var e := enc()
	var opt := blade_option(c, t)
	if opt.is_empty():
		r.lines.append(e.log.add("info", "%s: no melee weapon can strike %s" % [s["name"], t.name()], c.id))
		return
	var tier := Spellcasting.cantrip_tier(c.creature.character_level())
	var booming := str(s["id"]) == "booming_blade"
	var kind := "thunder" if booming else "fire"
	var sub := e._resolve_attack(c, t, opt, {"extra_dice": [{"dice": "%dd8" % tier, "type": kind, "label": str(s["name"])}] if tier > 0 else []})
	r.hit = sub.hit
	r.damage += sub.damage
	if not sub.hit:
		return
	if booming:
		if t.is_down():
			return
		var fx := Effect.new("Booming energy (Booming Blade)", &"spell", "booming_blade")
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		fx.data["booming_dice"] = "%dd8" % (tier + 1)
		t.creature.add_effect(fx)
		e.events.append({"type": "condition", "id": t.id})
		r.lines.append(e.log.add("spell", "%s is wrapped in booming energy: moving before %s's next turn costs %dd8 Thunder damage" % [t.name(), c.name(), tier + 1], t.id))
		return
	var mod := int((ctx["nums"] as Dictionary)["mod"])
	var next: Combatant = null
	for o in e.hostiles_of(c):
		if o != t and not o.is_down() and e.distance(o, t) <= 5 and e.can_see(c, o) and (next == null or o.creature.hp < next.creature.hp):
			next = o
	if next == null:
		return
	var rolled := {"total": 0, "text": ""}
	if tier > 0:
		rolled = e._max_damage_dice("%dd8" % tier, false) if e.faerun.maximized(c, "fire") else e._roll_damage_dice("%dd8" % tier, false, 0, str(s["name"]))
	var amount := int(rolled["total"]) + mod
	if amount <= 0:
		return
	e.events.append({"type": "ability", "source": "feature", "by": t.id, "key": "green_flame_blade_leap", "targets": [next.id], "cells": []})
	r.lines.append(e.log.add("spell", "Green fire leaps from %s to %s" % [t.name(), next.name()], c.id))
	var details: Array = ["%s + %d (spellcasting modifier)" % [str(rolled["text"]), mod] if tier > 0 else "%d (spellcasting modifier)" % mod]
	var dr := e.deal_damage(c, next, [{"amount": amount, "type": "fire"}], false, str(s["name"]), details)
	r.damage += dr.final if dr != null else 0


## Booming Blade: a creature wrapped in its energy moved 5 ft or more of its own will (Encounter._walk), so it takes the
## Thunder damage and the spell ends. Two casters' don't add up (2024 "Combining Game Effects"): the strongest goes off
## and both end.
func booming_moved(c: Combatant) -> void:
	var e := enc()
	var best: Effect = null
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id != "booming_blade" or not fx.data.has("booming_dice"):
			continue
		if best == null or int(DiceRoller.parse_expr(str(fx.data["booming_dice"]))["count"]) > int(DiceRoller.parse_expr(str(best.data["booming_dice"]))["count"]):
			best = fx
		c.creature.remove_effect(fx)
	if best == null:
		return
	var src := e.get_c(best.caster_id)
	var dice := str(best.data["booming_dice"])
	var rolled := e._max_damage_dice(dice, false) if src != null and e.faerun.maximized(src, "thunder") else e._roll_damage_dice(dice, false, 0, "Booming Blade")
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "booming_blade_burst", "targets": [c.id], "cells": []})
	e.log.add("spell", "The booming energy around %s bursts as it moves (Booming Blade)" % c.name(), c.id)
	e.deal_damage(src, c, [{"amount": int(rolled["total"]), "type": "thunder"}], false, "Booming Blade", [str(rolled["text"])])
