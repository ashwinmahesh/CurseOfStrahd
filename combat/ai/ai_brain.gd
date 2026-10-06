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

const PROFILES := {
	"pack_hunter": {"oa_fear": 1.0, "finish": 1.5, "nearest": false, "flee_bloodied": false},
	"brute": {"oa_fear": 0.3, "finish": 1.0, "nearest": false, "flee_bloodied": false},
	"mindless": {"oa_fear": 0.0, "finish": 0.0, "nearest": true, "flee_bloodied": false},
	"cowardly": {"oa_fear": 1.5, "finish": 1.0, "nearest": false, "flee_bloodied": true},
}

var _enc: WeakRef
## The last plan made, for tests and the debug overlay: {kind, target, cell, option, score, why}.
var last_plan: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


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
	if c.creature.has_flag("indifferent"):
		e.log.add("info", "%s doesn't care to fight (Calm Emotions)" % c.name(), c.id)
		last_plan = {"kind": "wait", "why": "Calm Emotions"}
		return CombatResult.new()
	if c.creature.has_flag("crowned") and c.can_act():
		var crowned := _crown_turn(c)
		if crowned != null:
			return crowned
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
	var prof := profile(c)
	if bool(prof["flee_bloodied"]) and c.creature.is_bloodied():
		var near := _nearest_enemy(c)
		if near != null:
			last_plan = {"kind": "flee", "why": "Bloodied coward"}
			return _flee(c, near, true)
	var plan := plan_turn(c)
	last_plan = plan
	match str(plan["kind"]):
		"attack":
			return _move_then_attack(c, plan)
		"approach":
			return _approach(c, plan)
		"search":
			return e.search(c)
	e.log.add("info", "%s waits" % c.name(), c.id)
	return CombatResult.new()


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
	var hidden_any := false
	for t in e.hostiles_of(c):
		if t.is_down():
			continue
		if not e.can_see(c, t):
			hidden_any = hidden_any or t.hidden
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
	if str(best["kind"]) == "attack":
		return best
	if not visible.is_empty():
		return _approach_plan(c, visible, prof)
	if hidden_any and c.action_available:
		return {"kind": "search", "score": 0.0, "why": "enemies are hidden"}
	return best


## Attacks worth considering: the best melee and the best ranged attack by average damage (monsters use their
## stat-block attacks, characters their weapons).
func _usable_options(c: Combatant) -> Array[Dictionary]:
	var best_melee := {}
	var best_ranged := {}
	for o in enc().attack_options(c):
		var avg := (o["profile"] as WeaponProfile).average_damage()
		if bool(o["melee"]):
			if best_melee.is_empty() or avg > (best_melee["profile"] as WeaponProfile).average_damage():
				best_melee = o
		elif enc().has_ammo_for(c, o):
			if best_ranged.is_empty() or avg > (best_ranged["profile"] as WeaponProfile).average_damage():
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
	var avg := p.average_damage()
	var expected := float(hc["chance"]) * avg
	var score := expected
	# Finishing a foe ends its turns for good.
	var hp_left := t.creature.hp + t.creature.temp_hp
	if avg >= hp_left:
		score += float(prof["finish"]) * 3.0 * float(hc["chance"])
	# Concentrating casters are worth breaking.
	if t.creature.concentration != null:
		score += 1.0
	# Opportunity Attacks along the way.
	if cell != c.cell and float(prof["oa_fear"]) > 0.0:
		score -= float(prof["oa_fear"]) * _oa_risk(c, CombatGrid.path_to(reach, cell), threats)
	score -= cost * 0.01
	return score


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
	if bool(plan.get("dash", false)) and c.action_available and c.speed() > 0:
		e.dash(c)
	var reach := e.reachable_for(c)
	var best_cell := c.cell
	var best_d := e.grid.distance_ft(c.cell, c.size_cells, target.cell, target.size_cells)
	var best_cost := 0
	var prof := profile(c)
	var threats := _threats(c) if float(prof["oa_fear"]) > 0.0 else ([] as Array[Dictionary])
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]):
			continue
		var d := e.grid.distance_ft(cell, c.size_cells, target.cell, target.size_cells)
		var cost := int(info["cost"])
		if not threats.is_empty() and _oa_risk(c, CombatGrid.path_to(reach, cell), threats) > 0.0:
			d += 15
		if d < best_d or (d == best_d and cost < best_cost):
			best_d = d
			best_cell = cell
			best_cost = cost
	if best_cell == c.cell:
		return CombatResult.new()
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
	if t == null or t.is_down() or option.is_empty() or e.attack_legal(c, t, option) != "":
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
				queue.append(str(entry["action"]))
		return _multi_step(c, t, queue)
	var r: CombatResult
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
	var action_id := queue.pop_front() as String
	var option := e.option_by_id(c, "monster:" + action_id)
	var t := target
	if t == null or t.is_down() or option.is_empty() or e.attack_legal(c, t, option) != "":
		t = null
		for h in e.hostiles_of(c):
			if not h.is_down() and not option.is_empty() and e.attack_legal(c, h, option) == "":
				t = h
				break
	if t == null:
		return _multi_step(c, target, queue)
	var r := e.monster_attack(c, t, action_id)
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
