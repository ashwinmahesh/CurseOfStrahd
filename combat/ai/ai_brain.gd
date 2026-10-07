class_name AiBrain
extends RefCounted
## Turns for enemies and neutrals (plan §5.3, enemy AI v1). The player controls every party member and guest;
## this only drives creatures the party doesn't.
##
## Each turn: obey anything that takes the turn away (Turn Undead, Command), then score every attack the creature
## could make this turn — each visible, standing enemy, from each square it could reach — by expected damage
## (hit chance with every Advantage source, cover and Pack Tactics included), a bonus for finishing a foe, and a
## penalty for the Opportunity Attacks the path would provoke. The best plan is a move then an attack; with no
## attack in reach it Dashes toward its best target. Behavior profiles (monster data "ai_profile") weigh this:
##   pack_hunter: wolves. Loves Pack Tactics and wounded prey, avoids Opportunity Attacks.
##   brute:       goes for the biggest hit, shrugs off Opportunity Attacks.
##   mindless:    zombies. Shambles at the nearest enemy, ignores everything else.
##   cowardly:    flees when Bloodied.
## Steps that can pause for a player's reaction (an Opportunity Attack while moving, Shield, Uncanny Dodge) are
## chained with Encounter.then(), so the turn carries on after the player answers.
## The playthrough's difficulty changes how it fights (combat/ai/ai_tactics.gd): spread or focused blows, potions,
## fleeing a broken fight, and at Honour cruel foes striking the fallen.

const PROFILES := {
	"pack_hunter": {"oa_fear": 1.0, "finish": 1.5, "nearest": false, "flee_bloodied": false},
	"brute": {"oa_fear": 0.3, "finish": 1.0, "nearest": false, "flee_bloodied": false},
	"mindless": {"oa_fear": 0.0, "finish": 0.0, "nearest": true, "flee_bloodied": false},
	"cowardly": {"oa_fear": 1.5, "finish": 1.0, "nearest": false, "flee_bloodied": true},
	## Bats, ravens, shadows, specters, scouts, vampire spawn: strike, then pull back.
	"skirmisher": {"oa_fear": 1.2, "finish": 1.2, "nearest": false, "flee_bloodied": false, "retreat": true},
	## Swarms: pour into the nearest foe's space.
	"swarm": {"oa_fear": 0.0, "finish": 0.5, "nearest": true, "flee_bloodied": false},
	## Night hag: spells from range, flees through the Ethereal Plane when badly hurt.
	"spellcaster": {"oa_fear": 1.5, "finish": 1.0, "nearest": false, "flee_bloodied": false, "caster": true},
	## Priests: heal and bless allies, then fight.
	"support": {"oa_fear": 1.0, "finish": 1.0, "nearest": false, "flee_bloodied": false, "support": true},
	## Strahd (ADR 0014): BossBrain plays his shapes, Charm and Children of the Night, and picks his targets.
	"strahd": {"oa_fear": 0.8, "finish": 1.5, "nearest": false, "flee_bloodied": false},
}

var _enc: WeakRef
## The last plan made, for tests and the debug overlay: {kind, target, cell, option, score, why}.
var last_plan: Dictionary = {}
## Legendary and lair choices, and the strahd profile (combat/ai/boss_brain.gd).
var boss: BossBrain
## How it fights at the playthrough's difficulty (combat/ai/ai_tactics.gd), and its casters' spells at Tactician
## and Honour (combat/ai/ai_spells.gd).
var tactics: AiTactics
var spells: AiSpells
## The fallen hero this turn's plan strikes (Honour), whom the attack steps keep at although they're down.
var _finishing: Combatant = null


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	boss = BossBrain.new(encounter)
	tactics = AiTactics.new(encounter)
	spells = AiSpells.new(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func profile(c: Combatant) -> Dictionary:
	return PROFILES.get(str(c.ai_profile), PROFILES["brute"]) as Dictionary


## AI creatures take every Opportunity Attack they're offered, except a coward that's Bloodied.
func wants_reaction(reactor: Combatant, kind: String) -> bool:
	if kind == "opportunity_attack":
		return not (bool(profile(reactor)["flee_bloodied"]) and reactor.creature.is_bloodied())
	return true


# --- The turn -------------------------------------------------------------------------------------

func play_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var fear := e.features.fleeing_from(c)
	if fear != null:
		var by_spell := c.creature.has_flag("fear_flee")
		last_plan = {"kind": "flee", "why": "Fear" if by_spell else "Turned"}
		return _flee(c, fear, by_spell)
	if c.creature.has_flag("ethereal"):
		last_plan = {"kind": "wait", "why": "on the Ethereal Plane"}
		return CombatResult.new()
	# Transfix: it walks straight to the caster and does nothing else.
	var lure := e.faerun.transfixed_by(c)
	if lure != null:
		last_plan = {"kind": "approach", "why": "Transfix"}
		if e.distance(c, lure) <= 5:
			return CombatResult.new()
		return _approach(c, {"target": lure, "dash": false})
	if c.creature.has_flag("indifferent"):
		e.log.add("info", "%s doesn't care to fight (Calm Emotions)" % c.name(), c.id)
		last_plan = {"kind": "wait", "why": "Calm Emotions"}
		return CombatResult.new()
	if c.creature.has_flag("crowned") and c.can_act():
		var crowned := _crown_turn(c)
		if crowned != null:
			return crowned
	if c.has_meta("berserk") and c.can_act():
		return _berserk_turn(c)
	if c.creature.has_flag("command_drop"):
		e.log.add("info", "%s drops what it holds and ends its turn (Command: Drop)" % c.name(), c.id)
		c.set_meta("dropped_weapon", true)
		last_plan = {"kind": "wait", "why": "Command: Drop"}
		return CombatResult.new()
	if c.creature.has_flag("command_approach"):
		var caster2 := _commander(c)
		if caster2 != null:
			last_plan = {"kind": "approach", "why": "Command: Approach"}
			return _approach(c, {"target": caster2, "dash": false})
	if c.creature.has_flag("command_grovel"):
		c.creature.add_condition(&"prone", "Command")
		e.log.add("condition", "%s grovels and falls Prone (Command)" % c.name(), c.id)
		e.events.append({"type": "condition", "id": c.id})
		last_plan = {"kind": "wait", "why": "Command: Grovel"}
		return CombatResult.new()
	if c.creature.has_flag("command_halt"):
		e.log.add("info", "%s stands still (Command: Halt)" % c.name(), c.id)
		last_plan = {"kind": "wait", "why": "Command: Halt"}
		return CombatResult.new()
	if c.creature.has_flag("command_flee"):
		var caster := _commander(c)
		if caster != null:
			last_plan = {"kind": "flee", "why": "Command: Flee"}
			return _flee(c, caster, true)
	if not c.can_act():
		return CombatResult.new()
	_finishing = null
	# The difficulty's kit and morale: a Bloodied foe drinks its potion; a broken side flees (combat/ai/ai_tactics.gd).
	if c.side == &"enemy":
		var drank: Variant = tactics.potion_turn(c)
		if drank != null:
			return drank as CombatResult
		if e.difficulty.morale and not AiTactics.fearless(c) and tactics.broken(c):
			var fled: Variant = tactics.flee_turn(c)
			if fled != null:
				return fled as CombatResult
	if str(c.ai_profile) == "strahd":
		var bt: Variant = boss.play_turn(c)
		if bt != null:
			return bt as CombatResult
	var prof := profile(c)
	var ma := e.monster_actions
	# Bonus Actions that come first: Shape-Shift into fighting form, Divine Aid for a fallen ally, Fey Step.
	if c.creature is Monster:
		if not e.hostiles_of(c).is_empty():
			ma.bonus_action(c, "shift")
		if bool(prof.get("support", false)):
			var aid := ma.bonus_action(c, "support")
			if aid.is_paused():
				return aid
		ma.bonus_action(c, "fey_step")
		ma.bonus_action(c, "vow")
		var control := ma.bonus_action(c, "control")
		if control.is_paused():
			return control
		var spell_plan := _spell_plan(c, prof)
		if not spell_plan.is_empty():
			last_plan = spell_plan
			var sr := ma.cast(c, str(spell_plan["spell"]), spell_plan["targets"] as Array, spell_plan.get("point", Vector2.INF) as Vector2)
			if sr.ok or sr.is_paused():
				return e.then(sr, func() -> CombatResult: return _after_main(c))
		var spell_act := _recharge_spell_plan(c)
		if not spell_act.is_empty():
			last_plan = spell_act
			var act0 := spell_act["action"] as Dictionary
			ma.spend(c, act0)
			var sr0 := ma.cast(c, str(spell_act["spell"]), [], spell_act["point"] as Vector2)
			if sr0.ok or sr0.is_paused():
				return e.then(sr0, func() -> CombatResult: return _after_main(c))
		var save_plan := _save_action_plan(c)
		if not save_plan.is_empty():
			last_plan = save_plan
			var use_it := func() -> CombatResult:
				if not c.can_act() or e.state != Encounter.State.ACTIVE:
					return CombatResult.new()
				var act := save_plan["action"] as Dictionary
				var tg := save_plan["target"] as Combatant
				if ma.save_victims(c, act, tg).is_empty() or (bool((act.get("targets", {}) as Dictionary).get("in_space", false)) and not tg in ma.save_targets(c, act)):
					return CombatResult.new()
				e.spend_action(c)
				var r0 := CombatResult.new()
				ma.save_action(c, act, tg, r0)
				return e.then(r0, func() -> CombatResult: return _after_main(c))
			if save_plan.has("move_to"):
				return e.then(e.move(c, save_plan["move_to"] as Vector2i), use_it)
			return use_it.call() as CombatResult
	if bool(prof["flee_bloodied"]) and c.creature.is_bloodied():
		var near := _nearest_enemy(c)
		if near != null:
			last_plan = {"kind": "flee", "why": "Bloodied coward"}
			return _flee(c, near, true)
	# Weighing every square and target asks the same creatures thousands of questions: one read (Creature.begin_read).
	Creature.begin_read()
	var plan := plan_turn(c)
	# Tactician and Honour: the best spell of a caster's whole list, or its scroll, when it beats the weapon plan.
	var cast_plan := {}
	if e.difficulty.tactics in ["sharp", "ruthless"] and c.action_available and AiSpells.casts(c):
		cast_plan = spells.plan(c, action_worth(c, plan))
	Creature.end_read()
	if not cast_plan.is_empty():
		last_plan = cast_plan
		var cr := spells.cast(c, cast_plan)
		if cr.ok or cr.is_paused():
			return e.then(cr, func() -> CombatResult: return _after_main(c))
	last_plan = plan
	match str(plan["kind"]):
		"attack":
			if bool(plan.get("finish", false)):
				_finishing = plan["target"] as Combatant
			return e.then(_move_then_attack(c, plan), func() -> CombatResult: return _after_main(c))
		"approach":
			if c.creature is Monster:
				e.monster_actions.bonus_action(c, "dash")
			return _approach(c, plan)
		"search":
			return e.search(c)
	e.log.add("info", "%s waits" % c.name(), c.id)
	return CombatResult.new()


## After the main action: skirmishers pull back (Deathless Agility's Disengage, or Shadow Stealth to hide).
func _after_main(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act():
		return CombatResult.new()
	var prof := profile(c)
	if c.creature is Monster:
		e.monster_actions.bonus_action(c, "hide")
		e.monster_actions.bonus_action(c, "swoop")
		e.monster_actions.bonus_action(c, "consume_life")
		e.monster_actions.bonus_action(c, "trample")
		e.monster_actions.bonus_action(c, "bonus_save")
		var rampage := e.monster_actions.bonus_action(c, "rampage")
		if rampage.is_paused():
			return rampage
		e.monster_actions.bonus_action(c, "vanish")
	if bool(prof.get("retreat", false)) and c.movement_left > 0:
		var near := _nearest_enemy(c)
		if near != null and e.distance(c, near) <= 5:
			if c.creature is Monster:
				e.monster_actions.bonus_action(c, "retreat")
			if c.disengaged or c.creature.has_flag("flyby"):
				return _flee(c, near, false)
	return CombatResult.new()


## A spell worth casting this turn (spellcaster profile): flee through the Ethereal Plane when badly hurt; Phantasmal
## Killer on the toughest foe while it has uses; otherwise Magic Missile at the weakest foe in range.
func _spell_plan(c: Combatant, prof: Dictionary) -> Dictionary:
	var e := enc()
	if not bool(prof.get("caster", false)) or not c.action_available:
		return {}
	var known := {}
	for sp in e.monster_actions.spells_now(c):
		known[str(sp["id"])] = sp
	var foes: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h):
			foes.append(h)
	if c.creature.hp * 4 < c.creature.max_hp() and (known.has("etherealness") or known.has("plane_shift")):
		return {"kind": "cast", "spell": "etherealness" if known.has("etherealness") else "plane_shift", "targets": [c], "why": "escape"}
	if foes.is_empty():
		return {}
	if known.has("phantasmal_killer"):
		var tough: Combatant = null
		for f in foes:
			if e.distance(c, f) <= 120 and (tough == null or f.creature.hp > tough.creature.hp):
				tough = f
		if tough != null:
			return {"kind": "cast", "spell": "phantasmal_killer", "targets": [tough], "why": "Phantasmal Killer on %s" % tough.name()}
	if known.has("magic_missile"):
		var weak: Combatant = null
		for f2 in foes:
			if e.distance(c, f2) <= 120 and (weak == null or f2.creature.hp < weak.creature.hp):
				weak = f2
		var melee_near := false
		for f3 in foes:
			if e.distance(c, f3) <= 5:
				melee_near = true
		if weak != null and not melee_near:
			return {"kind": "cast", "spell": "magic_missile", "targets": [weak], "why": "Magic Missile at %s" % weak.name()}
	return {}


## An action that casts a spell on a Recharge (a vine blight's Entangling Plants), aimed at the nearest pair of foes
## when two stand close enough to share the area.
func _recharge_spell_plan(c: Combatant) -> Dictionary:
	var e := enc()
	if not c.action_available:
		return {}
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		var act := a as Dictionary
		if not act.has("cast") or not act.has("recharge") or e.monster_actions.why_not(c, act) != "":
			continue
		var spell_id := str((act["cast"] as Array)[0])
		var s := Compendium.shared().spell_data(spell_id)
		var reach := int((s.get("range", {}) as Dictionary).get("feet", 60))
		var foes := e.hostiles_of(c).filter(func(h: Combatant) -> bool: return not h.is_down() and e.distance(c, h) <= reach)
		for f: Combatant in foes:
			var near := foes.filter(func(g: Combatant) -> bool: return e.distance(f, g) <= 15)
			if near.size() >= 2 or foes.size() == 1:
				return {"kind": "cast", "action": act, "spell": spell_id, "point": e.center_of(f), "why": "%s at %s" % [act.get("name", ""), f.name()]}
	return {}


## A saving-throw action worth using as the action (a recharged Cacophony on a foe in the swarm's space).
func _save_action_plan(c: Combatant) -> Dictionary:
	var e := enc()
	if not c.action_available:
		return {}
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		var act := a as Dictionary
		var spread := (act.get("area", {}) as Dictionary).has("shape")
		if str(act.get("kind", "")) != "save" or not (act.has("recharge") or spread) or e.monster_actions.why_not(c, act) != "":
			continue
		var targets := e.monster_actions.save_targets(c, act)
		# An area action that isn't recharging (a ghost's Horrific Visage) is worth it when it catches two foes.
		if spread and not act.has("recharge"):
			var best_t: Combatant = null
			for t0 in targets:
				var foes := e.monster_actions.save_victims(c, act, t0).filter(func(v: Combatant) -> bool: return c.hostile_to(v))
				if foes.size() >= 2:
					best_t = t0
			if best_t != null:
				return {"kind": "save_action", "action": act, "target": best_t, "why": "%s at %s" % [act.get("name", ""), best_t.name()]}
			continue
		# An elemental that can flow into a creature's space moves onto a foe first for Whelm or Whirlwind.
		if targets.is_empty() and bool((act.get("targets", {}) as Dictionary).get("in_space", false)) and c.creature.has_flag("enters_spaces"):
			var reach := e.reachable_for(c)
			for h in e.hostiles_of(c):
				if not h.is_down() and reach.has(h.cell):
					return {"kind": "save_action", "action": act, "target": h, "move_to": h.cell, "why": "%s on %s" % [act.get("name", ""), h.name()]}
		if not targets.is_empty():
			return {"kind": "save_action", "action": act, "target": targets[0], "why": "%s on %s" % [act.get("name", ""), targets[0].name()]}
	return {}


func _effect_of(c: Combatant, source_id: String) -> Effect:
	for fx: Effect in c.creature.effects:
		if fx.source_id == source_id:
			return fx
	return null


## Crown of Madness: before moving, the creature uses its action to make a melee attack against a creature the
## caster picks (here: the nearest creature other than itself and the caster that it can reach).
func _crown_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var caster := e.get_c(str(c.get_meta("crowned_by", "")))
	var best: Combatant = null
	var opt := {}
	for o in e.living():
		if o == c or o == caster or o.is_down():
			continue
		var mo := e.best_melee_option(c, o)
		if mo.is_empty() or e.distance(c, o) > (mo["profile"] as WeaponProfile).reach:
			continue
		if best == null or (caster != null and caster.hostile_to(o) and not caster.hostile_to(best)):
			best = o
			opt = mo
	if best == null:
		return null
	e.log.add("info", "%s lashes out at %s (Crown of Madness)" % [c.name(), best.name()], c.id)
	last_plan = {"kind": "attack", "why": "Crown of Madness"}
	if c.creature is Monster:
		return e.monster_attack(c, best, str(opt.get("action_id", "")))
	return e.attack(c, best, str(opt["id"]))


## Berserk (flesh golem): it goes for the nearest creature it can see, friend or foe, with its full Multiattack.
func _berserk_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var near: Combatant = null
	for o in e.living():
		if o == c or o.is_down() or not e.can_see(c, o):
			continue
		if near == null or e.distance(c, o) < e.distance(c, near):
			near = o
	last_plan = {"kind": "attack", "why": "Berserk"}
	if near == null:
		return CombatResult.new()
	e.log.add("info", "%s rages at %s (Berserk)" % [c.name(), near.name()], c.id)
	var strike := func() -> CombatResult:
		if not c.can_act() or e.state != Encounter.State.ACTIVE or e.best_melee_option(c, near).is_empty():
			return CombatResult.new()
		var mo := e.best_melee_option(c, near)
		if e.distance(c, near) > (mo["profile"] as WeaponProfile).reach:
			return CombatResult.new()
		var queue: Array[String] = []
		for entry in e.begin_multiattack(c):
			for i in int(entry["count"]):
				queue.append(str(entry["action"]))
		if queue.is_empty():
			return e.monster_attack(c, near, str(mo.get("action_id", "")))
		return _multi_step(c, near, queue)
	var mo0 := e.best_melee_option(c, near)
	if not mo0.is_empty() and e.distance(c, near) <= (mo0["profile"] as WeaponProfile).reach:
		return strike.call() as CombatResult
	return e.then(_approach(c, {"target": near}), strike)


func _commander(c: Combatant) -> Combatant:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "command":
			return enc().get_c(fx.caster_id)
	return null


func _nearest_enemy(c: Combatant) -> Combatant:
	var best: Combatant = null
	var best_d := 1 << 30
	for h in enc().hostiles_of(c):
		var d := enc().distance(c, h)
		if d < best_d:
			best_d = d
			best = h
	return best


## Picks this turn's plan: {kind: attack|approach|search|wait, target, cell, option, score, why}.
func plan_turn(c: Combatant) -> Dictionary:
	var e := enc()
	var prof := profile(c)
	var reach := e.reachable_for(c)
	var options := _usable_options(c)
	var threats := _threats(c)
	var best := {"kind": "wait", "score": -1e9, "why": "nothing to do"}
	var visible: Array[Combatant] = []
	var heard: Array[Combatant] = []     ## out of sight but not Hidden: a fight is loud, so their squares are known
	var hidden_any := false
	for t in e.hostiles_of(c):
		if t.is_down():
			continue
		if not e.can_see(c, t):
			hidden_any = hidden_any or t.hidden
			if not t.hidden:
				heard.append(t)
			continue
		visible.append(t)
	for t in visible:
		for o in options:
			var p := o["profile"] as WeaponProfile
			var cells := _attack_cells(c, t, o, reach)
			for cell: Vector2i in cells:
				var cost := 0 if cell == c.cell else int((reach[cell] as Dictionary)["cost"])
				var score := _score(c, t, o, cell, cost, reach, prof, threats)
				if score > float(best["score"]):
					best = {"kind": "attack", "target": t, "cell": cell, "option": str(o["id"]), "score": score,
						"why": "%s at %s with %s" % [t.name(), cell, p.name]}
	# Honour: a cruel foe may strike a hero on 0 Hit Points instead (combat/ai/ai_tactics.gd).
	var fallen := tactics.fallen_plan(c, options, reach, threats, float(prof["oa_fear"]))
	if not fallen.is_empty() and float(fallen["score"]) > float(best["score"]):
		best = fallen
	if str(best["kind"]) == "attack":
		return best
	if not visible.is_empty():
		return _approach_plan(c, visible, prof)
	if not heard.is_empty():
		return _approach_plan(c, heard, prof)
	if hidden_any and c.action_available:
		return {"kind": "search", "score": 0.0, "why": "enemies are hidden"}
	return best


## Attacks worth considering: the best melee and the best ranged attack by average damage (monsters use their
## stat-block attacks, characters their weapons).
func _usable_options(c: Combatant) -> Array[Dictionary]:
	var best_melee := {}
	var best_ranged := {}
	for o in enc().attack_options(c):
		if c.creature is Monster and enc().monster_actions.why_not(c, (c.creature as Monster).action(str(o.get("action_id", "")))) != "":
			continue
		var avg := _avg(c, o)
		if bool(o["melee"]):
			if best_melee.is_empty() or avg > _avg(c, best_melee):
				best_melee = o
		elif enc().has_ammo_for(c, o):
			if best_ranged.is_empty() or avg > _avg(c, best_ranged):
				best_ranged = o
	var out: Array[Dictionary] = []
	if not best_melee.is_empty():
		out.append(best_melee)
	if not best_ranged.is_empty():
		out.append(best_ranged)
	return out


## Squares this creature could attack `t` from with `o` this turn: where it stands, or any free reachable square
## in reach (melee) or in range with a line to the target (ranged; only a few nearby squares are tried).
func _attack_cells(c: Combatant, t: Combatant, o: Dictionary, reach: Dictionary) -> Array[Vector2i]:
	var e := enc()
	var p := o["profile"] as WeaponProfile
	var out: Array[Vector2i] = []
	var melee := bool(o["melee"])
	var max_d := p.reach if melee else (p.long_range if p.long_range > 0 else p.normal_range)
	if e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells) <= max_d:
		out.append(c.cell)
	if not c.can_act() or c.movement_left <= 0:
		return out
	var ranged_tries := 0
	for cell: Vector2i in reach:
		if cell == c.cell or bool((reach[cell] as Dictionary)["occupied"]):
			continue
		if e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells) > max_d:
			continue
		if not melee:
			ranged_tries += 1
			if ranged_tries > 12:
				continue
		out.append(cell)
	return out


## Expected value of attacking `t` with `o` from `cell` after a move costing `cost` feet.
func _score(c: Combatant, t: Combatant, o: Dictionary, cell: Vector2i, cost: int, reach: Dictionary,
		prof: Dictionary, threats: Array[Dictionary]) -> float:
	var e := enc()
	var p := o["profile"] as WeaponProfile
	if bool(prof["nearest"]):
		return 100.0 - cost - e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells) * 0.1
	var keep := c.cell
	c.cell = cell
	var hc := e.hit_chance(c, t, o)
	c.cell = keep
	if int((hc["situation"] as Dictionary)["cover"]) == CombatGrid.Cover.TOTAL:
		return -1e9
	var avg := _avg(c, o)
	var expected := float(hc["chance"]) * avg
	# An Echo Knight's echo is only an image (its knight calls another with a Bonus Action): worth little.
	var echo := EchoKnight.is_echo(t)
	if echo:
		expected *= 0.3
	var score := expected
	# Finishing a foe ends its turns for good.
	var hp_left := t.creature.hp + t.creature.temp_hp
	if avg >= hp_left and not echo:
		score += float(prof["finish"]) * 3.0 * float(hc["chance"]) * tactics.finish_scale()
	# Concentrating casters are worth breaking.
	if t.creature.concentration != null:
		score += 1.0
	score += boss.target_bonus(c, t)
	# The difficulty: spread blows (Story), or gang up on the hurt, healers and casters (Tactician and Honour).
	if not echo:
		score += tactics.target_adjust(t, expected)
	# Opportunity Attacks along the way.
	if cell != c.cell and float(prof["oa_fear"]) > 0.0:
		score -= float(prof["oa_fear"]) * _oa_risk(c, CombatGrid.path_to(reach, cell), threats)
	score -= cost * 0.01
	return score


## What a weapon plan is worth for the whole action: its score for each attack the action makes (Multiattack, Extra
## Attack). Nothing when it can't attack this turn.
func action_worth(c: Combatant, weapon: Dictionary) -> float:
	if str(weapon.get("kind", "")) != "attack":
		return 0.0
	var n := maxi(1, enc().attacks_per_action(c))
	if c.creature is Monster:
		var multi := (c.creature as Monster).action("multiattack")
		var count := 0
		for entry: Variant in multi.get("multiattack", []):
			count += int((entry as Dictionary).get("count", 1))
		n = maxi(n, count)
	return float(weapon["score"]) * n


## Average damage of an attack option, counting a monster's extra dice and a little for its riders.
func _avg(c: Combatant, o: Dictionary) -> float:
	if c.creature is Monster and o.has("action_id"):
		var act := (c.creature as Monster).action(str(o["action_id"]))
		return (c.creature as Monster).average_damage(str(o["action_id"])) + (4.0 if act.has("on_hit") else 0.0)
	return (o["profile"] as WeaponProfile).average_damage()


## Hostiles that could make an Opportunity Attack on `c` this turn: [{p, reach, expected}] (expected damage).
func _threats(c: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	if c.disengaged:
		return out
	for p in e.hostiles_of(c):
		if not p.reaction_available or not p.can_act() or e.has_mark("no_reactions", p.id) or not e.can_see(p, c):
			continue
		var opt := e.best_melee_option(p, c)
		if opt.is_empty():
			continue
		var hc := e.hit_chance(p, c, opt)
		out.append({"p": p, "reach": p.reach_ft(), "expected": float(hc["chance"]) * (opt["profile"] as WeaponProfile).average_damage()})
	return out


## Expected damage from Opportunity Attacks along a path (each hostile reacts once).
func _oa_risk(c: Combatant, path: Array[Vector2i], threats: Array[Dictionary]) -> float:
	var g := enc().grid
	var risk := 0.0
	for t in threats:
		var p := t["p"] as Combatant
		var reach := int(t["reach"])
		for i in range(1, path.size()):
			var before := g.distance_ft(p.cell, p.size_cells, path[i - 1], c.size_cells) <= reach
			var after := g.distance_ft(p.cell, p.size_cells, path[i], c.size_cells) <= reach
			if before and not after:
				risk += float(t["expected"])
				break
	return risk


## No attack this turn: Dash toward the most attractive target and end as close to it as possible.
func _approach_plan(c: Combatant, visible: Array[Combatant], prof: Dictionary) -> Dictionary:
	var e := enc()
	var target: Combatant = null
	var best := 1e9
	for t in visible:
		var d := float(e.distance(c, t))
		if not bool(prof["nearest"]):
			d -= 10.0 * (1.0 - float(t.creature.hp) / maxf(1.0, float(t.creature.max_hp())))
		if d < best:
			best = d
			target = t
	return {"kind": "approach", "target": target, "score": 0.0, "dash": c.action_available,
		"why": "closing on %s" % target.name()}


func _approach(c: Combatant, plan: Dictionary) -> CombatResult:
	var e := enc()
	var target := plan["target"] as Combatant
	# Dash only when the best square needs it: no wasted action when nothing gets closer (a shut door between them).
	var dash_ok := bool(plan.get("dash", false)) and c.action_available and c.speed() > 0
	var reach := e.reachable_for(c, c.movement_left + (c.speed() if dash_ok else 0))
	# Walking distance to the target (around walls), not the straight line: a creature on the far side of a wall
	# heads for the door rather than pressing its face to the stones.
	var walk := e.grid.reachable(target.cell, 1, 4000, func(_x: Vector2i) -> bool: return false,
		func(_x: Vector2i) -> bool: return false, func(_x: Vector2i) -> bool: return false)
	var dist := func(cell: Vector2i) -> int:
		var straight := e.grid.distance_ft(cell, c.size_cells, target.cell, target.size_cells)
		if straight <= 5 or not walk.has(cell):
			return straight if walk.has(cell) or straight <= 5 else straight + 1000
		return int((walk[cell] as Dictionary)["cost"])
	var best_cell := c.cell
	var best_d := int(dist.call(c.cell))
	var best_cost := 0
	var prof := profile(c)
	var threats := _threats(c) if float(prof["oa_fear"]) > 0.0 else ([] as Array[Dictionary])
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]):
			continue
		var d := int(dist.call(cell))
		var cost := int(info["cost"])
		if not threats.is_empty() and _oa_risk(c, CombatGrid.path_to(reach, cell), threats) > 0.0:
			d += 15
		if d < best_d or (d == best_d and cost < best_cost):
			best_d = d
			best_cell = cell
			best_cost = cost
	if best_cell == c.cell:
		return CombatResult.new()
	if dash_ok and best_cost > c.movement_left:
		e.dash(c)
	return e.move(c, best_cell)


func _move_then_attack(c: Combatant, plan: Dictionary) -> CombatResult:
	var e := enc()
	var dest: Vector2i = plan["cell"]
	var target := plan["target"] as Combatant
	var option_id := str(plan["option"])
	var after := func() -> CombatResult:
		return _attack_step(c, target, option_id)
	if dest != c.cell:
		var r := e.move(c, dest)
		if r.ok:
			return e.then(r, after)
	elif c.creature.has_condition(&"prone") and c.movement_left >= c.speed() / 2 and c.speed() > 0:
		e.stand_up(c)
	return after.call() as CombatResult


## One attack, then the next if the creature has more (Extra Attack, Multiattack), picking a new target if the
## first one fell.
func _attack_step(c: Combatant, target: Combatant, option_id: String) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or not c.can_act() or e.current() != c:
		return CombatResult.new()
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.new()
	var option := e.option_by_id(c, option_id)
	var t := target
	if t == null or (t.is_down() and t != _finishing) or option.is_empty() or e.attack_legal(c, t, option) != "":
		var alt := _best_in_reach(c)
		if alt.is_empty():
			return CombatResult.new()
		t = alt["target"] as Combatant
		option_id = str(alt["option"])
		option = e.option_by_id(c, option_id)
	var multi := c.creature is Monster and not (c.creature as Monster).action("multiattack").is_empty()
	if multi and c.action_available:
		var queue: Array[String] = []
		for entry in e.begin_multiattack(c):
			for i in int(entry["count"]):
				var choices: Array[String] = [str(entry["action"])]
				for alt: Variant in entry.get("or", []):
					choices.append(str(alt))
				queue.append("|".join(choices))
		return _multi_step(c, t, queue)
	var r: CombatResult
	tactics.note_strike(t)
	if c.creature is Monster:
		r = e.monster_attack(c, t, str(option.get("action_id", "")))
	else:
		r = e.attack(c, t, option_id)
	if not r.ok:
		e.log.add("info", "%s can't attack: %s" % [c.name(), r.reason], c.id)
		return r
	if c.attacks_left > 0:
		return e.then(r, func() -> CombatResult: return _attack_step(c, t, option_id))
	return r


func _multi_step(c: Combatant, target: Combatant, queue: Array[String]) -> CombatResult:
	var e := enc()
	if queue.is_empty() or e.state != Encounter.State.ACTIVE or not c.can_act():
		return CombatResult.new()
	var choices := (queue.pop_front() as String).split("|")
	var m := c.creature as Monster
	# A save action in the Multiattack (the Spawn's Bite, Engulf) goes first when it has a target.
	for cid in choices:
		var act := m.action(cid)
		if str(act.get("kind", "")) == "save" and e.monster_actions.why_not(c, act) == "":
			var st := e.monster_actions.save_targets(c, act)
			if not st.is_empty():
				var r0 := CombatResult.new()
				e.monster_actions.save_action(c, act, st[0], r0)
				return e.then(r0, func() -> CombatResult: return _multi_step(c, target, queue))
	# Otherwise the best attack among the choices that can reach the target (or another foe): a ranged attack
	# when the foe is out of reach, the bigger damage when both work.
	var best_id := ""
	var t: Combatant = null
	var best_avg := -1.0
	for cid2 in choices:
		var act2 := m.action(cid2)
		if not act2.has("attack") or e.monster_actions.why_not(c, act2) != "":
			continue
		var option := e.option_by_id(c, "monster:" + cid2)
		var tt := target
		if tt == null or (tt.is_down() and tt != _finishing) or option.is_empty() or e.attack_legal(c, tt, option) != "":
			tt = null
			for h in e.hostiles_of(c):
				if not h.is_down() and not option.is_empty() and e.attack_legal(c, h, option) == "":
					tt = h
					break
		if tt == null:
			continue
		var avg := m.average_damage(cid2) + boss.action_bonus(c, act2)
		if avg > best_avg:
			best_avg = avg
			best_id = cid2
			t = tt
	if t == null:
		return _multi_step(c, target, queue)
	tactics.note_strike(t)
	var r := e.monster_attack(c, t, best_id)
	return e.then(r, func() -> CombatResult: return _multi_step(c, t, queue))


## The best attack from where the creature stands: {target, option} or {}.
func _best_in_reach(c: Combatant) -> Dictionary:
	var e := enc()
	var best := {}
	var best_score := -1e9
	for t in e.hostiles_of(c):
		if t.is_down() or not e.can_see(c, t):
			continue
		for o in _usable_options(c):
			if e.attack_legal(c, t, o) != "":
				continue
			var hc := e.hit_chance(c, t, o)
			var s := float(hc["chance"]) * (o["profile"] as WeaponProfile).average_damage()
			if s > best_score:
				best_score = s
				best = {"target": t, "option": str(o["id"])}
	return best


## Moves as far from `from` as it can (Turned creatures can't Dash; Command: Flee and cowards can).
func _flee(c: Combatant, from: Combatant, may_dash: bool) -> CombatResult:
	var e := enc()
	if c.speed() <= 0:
		return CombatResult.new()
	if may_dash and c.can_act() and c.action_available:
		e.dash(c)
	var reach := e.reachable_for(c)
	var best_cell := c.cell
	var best_d := e.grid.distance_ft(c.cell, c.size_cells, from.cell, from.size_cells)
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var d := e.grid.distance_ft(cell, c.size_cells, from.cell, from.size_cells)
		if d > best_d:
			best_d = d
			best_cell = cell
	e.log.add("info", "%s flees from %s" % [c.name(), from.name()], c.id)
	if best_cell == c.cell:
		return CombatResult.new()
	return e.move(c, best_cell)
