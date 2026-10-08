class_name PartyAutopilot
extends RefCounted
## A stand-in player for balance simulations and soak tests: plays the pregens with simple, sensible tactics
## (healing the fallen, Turn Undead on a crowd of zombies, Sleep on a wolf pack, Steady Aim from range, a ranger's
## bow and a warlock's Eldritch Blast from range). Paladins and monks fight like fighters.
## Test-only: in the game the player controls every party member (plan pillar 2).

var e: Encounter


func _init(encounter: Encounter) -> void:
	e = encounter


func play(c: Combatant) -> CombatResult:
	if not c.can_act():
		return CombatResult.new()
	var ch := c.creature as Character
	if ch == null:
		# A guest with a stat block (Ilinca, Emil, Sir Godfrey...): it fights as its own monster AI would.
		return e.ai.play_turn(c)
	# A weapon it dropped (falling Unconscious, a Disarming Attack) lying within reach: back in hand first.
	e.ground.ai_pick_up(c)
	if ch.class_level_of("cleric") > 0:
		return _cleric(c)
	if ch.class_level_of("wizard") > 0:
		return _wizard(c)
	if ch.class_level_of("rogue") > 0:
		return _rogue(c)
	if ch.class_level_of("warlock") > 0:
		return _warlock(c)
	if ch.class_level_of("ranger") > 0:
		return _ranger(c)
	return _fighter(c)


# --- Helpers --------------------------------------------------------------------------------------

func _enemies(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for h in e.hostiles_of(c):
		# A foe who surrendered is out of the fight (lane 22's captives), though not down.
		if not h.is_down() and e.can_see(c, h) and not h.creature.has_flag("surrendered"):
			out.append(h)
	return out


func _nearest(c: Combatant, list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var bd := 1 << 30
	for t in list:
		var d := e.distance(c, t)
		if d < bd:
			bd = d
			best = t
	return best


func _weakest(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for t in list:
		if best == null or t.creature.hp < best.creature.hp:
			best = t
	return best


func _melee_turn(c: Combatant) -> CombatResult:
	var plan := e.ai.plan_turn(c)
	if str(plan["kind"]) == "attack":
		return e.ai._move_then_attack(c, plan)
	if str(plan["kind"]) == "approach":
		return e.ai._approach(c, plan)
	return CombatResult.new()


func _cast(c: Combatant, spell_id: String, slot: int, targets: Array, point: Vector2 = Vector2.INF,
		dir: Vector2 = Vector2.ZERO) -> CombatResult:
	var r := e.spells.cast(c, spell_id, slot, targets, point, dir)
	return r


# --- Classes --------------------------------------------------------------------------------------

func _fighter(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	if c.creature.hp * 2 < c.creature.max_hp() and ch.resource_left("second_wind") > 0:
		e.features.second_wind(c)
	var r := _melee_turn(c)
	return e.then(r, func() -> CombatResult:
		if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act():
			return CombatResult.new()
		# Action Surge once something is in reach.
		if not c.action_available and ch.resource_left("action_surge") > 0:
			var near := _nearest(c, _enemies(c))
			if near != null and e.distance(c, near) <= 5:
				e.features.action_surge(c)
				return e.ai._attack_step(c, near, "weapon:greatsword")
		return CombatResult.new())


func _rogue(c: Combatant) -> CombatResult:
	var foes := _enemies(c)
	if foes.is_empty():
		return _melee_turn(c)   # nothing in sight: close in
	var adjacent := false
	for f in foes:
		if e.distance(c, f) <= 5:
			adjacent = true
	var bow := e.option_by_id(c, "weapon:shortbow")
	if not adjacent and not bow.is_empty():
		var target := _weakest(foes)
		if e.attack_legal(c, target, bow) == "":
			if c.bonus_available and not c.moved:
				e.features.steady_aim(c)
			return e.attack(c, target, "weapon:shortbow")
	if adjacent and c.bonus_available:
		# Cunning Action: Disengage and shoot from a step back is too fiddly here; fight with the blade.
		pass
	return _melee_turn(c)


func _cleric(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	# 1. Pick up the fallen: Healing Word from afar, or walk over and Cure Wounds.
	for a in e.allies_of(c):
		if a.creature.hp > 0 or a.creature.dead:
			continue
		if e.distance(c, a) <= 60 and c.bonus_available and _cast(c, "healing_word", 1, [a]).ok:
			break
		if c.action_available and ch.slots_left(1) > 0 and not c.cast_slot_spell_this_turn:
			if e.distance(c, a) > 5:
				var reach := e.reachable_for(c)
				var best := c.cell
				var best_cost := 1 << 30
				for cell: Vector2i in reach:
					var info := reach[cell] as Dictionary
					if not bool(info["occupied"]) and e.grid.distance_ft(cell, 1, a.cell, a.size_cells) <= 5 and int(info["cost"]) < best_cost:
						best = cell
						best_cost = int(info["cost"])
				if best != c.cell:
					e.move(c, best)
			if e.distance(c, a) <= 5:
				var cw := _cast(c, "cure_wounds", 1, [a])
				if cw.ok:
					return cw
	# 2. Turn a crowd of zombies.
	var undead := 0
	for h in e.hostiles_of(c):
		if str(h.creature.creature_type) == "undead" and not h.is_down() and e.distance(c, h) <= 30 and e.features.fleeing_from(h) == null:
			undead += 1
	if undead >= 2 and ch.resource_left("channel_divinity") > 0 and c.action_available:
		e.features.turn_undead(c)
	# 3. Preserve Life when two allies are Bloodied.
	if c.action_available and ch.resource_left("channel_divinity") > 0 and e.features.preserve_life_room(c).size() >= 2:
		e.features.preserve_life(c)
	var foes := _enemies(c)
	# 4. Spiritual Weapon, then its Bonus Action attacks.
	if c.bonus_available and not foes.is_empty():
		var near := _nearest(c, foes)
		if e.spells.has_spiritual_weapon(c):
			var wcell := e.spells.weapon_of(c).cell
			var best: Combatant = null
			for f in foes:
				if e.grid.distance_ft(wcell, 1, f.cell, f.size_cells) <= 25:
					best = f
			if best != null:
				e.spells.spiritual_weapon_attack(c, best, e.spells._beside(c, best))
		elif ch.slots_left(2) > 0 and e.distance(c, near) <= 60 and not c.cast_slot_spell_this_turn:
			_cast(c, "spiritual_weapon", 2, [near])
	if foes.is_empty():
		return _melee_turn(c) if c.action_available else CombatResult.new()
	if not c.action_available:
		return CombatResult.new()
	# 5. A cantrip or Guiding Bolt at the best target in range.
	var target := _weakest(foes)
	if ch.slots_left(1) >= 2 and not c.cast_slot_spell_this_turn and target.creature.hp >= 12 and e.distance(c, target) <= 120:
		var gb := _cast(c, "guiding_bolt", 1, [target])
		if gb.ok:
			return gb
	var cantrips: Array[String] = ["sacred_flame", "toll_the_dead"]
	if target.creature.hp < target.creature.max_hp():
		cantrips.reverse()
	if e.distance(c, target) <= 60:
		for cantrip in cantrips:
			var r := _cast(c, cantrip, 0, [target])
			if r.ok:
				return r
	return _melee_turn(c)


func _wizard(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	var foes := _enemies(c)
	if foes.is_empty():
		return _melee_turn(c)
	# Sleep on the biggest cluster of creatures that sleep.
	if ch.slots_left(1) > 0 and not c.cast_slot_spell_this_turn:
		var best_point := Vector2.INF
		var best_n := 1
		for f in foes:
			for dx: int in [0, 1]:
				for dz: int in [0, 1]:
					var p := Vector2(f.cell.x + dx, f.cell.y + dz)
					if e.grid.distance_ft(c.cell, 1, Vector2i(floori(p.x), floori(p.y)), 1) > 60:
						continue
					var n := 0
					var hits_party := false
					for o in e.spells.creatures_in(e.grid.area_cells("sphere", 5, p)):
						if c.hostile_to(o) and not o.creature.is_condition_immune(&"exhaustion") and not o.is_down():
							n += 1
						elif not c.hostile_to(o):
							hits_party = true
					if n > best_n and not hits_party:
						best_n = n
						best_point = p
		if best_point != Vector2.INF:
			var s := _cast(c, "sleep", 1, [], best_point)
			if s.ok:
				return s
	var target := _weakest(foes)
	# Scorching Ray at something big.
	if ch.slots_left(2) > 0 and not c.cast_slot_spell_this_turn and target.creature.hp >= 14 and e.distance(c, target) <= 120:
		var sr := _cast(c, "scorching_ray", 2, [target, target, target])
		if sr.ok:
			return sr
	var r := _cast(c, "fire_bolt", 0, [target])
	if r.ok:
		return r
	return _melee_turn(c)


func _ranger(c: Combatant) -> CombatResult:
	var foes := _enemies(c)
	if foes.is_empty():
		return _melee_turn(c)
	for f in foes:
		if e.distance(c, f) <= 5:
			return _melee_turn(c)
	var target := _weakest(foes)
	for id: String in ["weapon:longbow", "weapon:shortbow"]:
		var bow := e.option_by_id(c, id)
		if not bow.is_empty() and e.attack_legal(c, target, bow) == "":
			return e.attack(c, target, id)
	return _melee_turn(c)


func _warlock(c: Combatant) -> CombatResult:
	var foes := _enemies(c)
	if foes.is_empty() or not c.action_available:
		return _melee_turn(c)
	var target := _weakest(foes)
	if e.distance(c, target) <= 120:
		# One beam per tier (levels 1, 5, 11, 17); try the most first.
		for beams: int in [4, 3, 2, 1]:
			var aim: Array = []
			for i in beams:
				aim.append(target)
			var r := _cast(c, "eldritch_blast", 0, aim)
			if r.ok:
				return r
	return _melee_turn(c)


## The autopilot's answer to a prompt: yes to everything, except Divine Smite after a hit (it keeps its paladin's slots
## for spells, as the fights it was tuned on did before smiting was asked about).
static func _takes(req: ReactionRequest) -> bool:
	return req.kind != CombatFeatures.DIVINE_SMITE


## Plays the encounter to the end (or `max_rounds`): the autopilot for the party, AiBrain for everyone else.
## Every reaction is taken automatically. Returns {outcome, rounds, downs}.
func run(max_rounds: int = 30) -> Dictionary:
	e.default_player_reaction = "auto"
	if e.state == Encounter.State.SETUP:
		e.start()
	while e.pending != null:   # choices as Initiative is rolled (Tandem Footwork, Alert's swap), before the first turn
		e.answer_reaction(true)
	var downs := 0
	var guard := 0
	while e.state == Encounter.State.ACTIVE and e.round_no <= max_rounds and guard < 2000:
		guard += 1
		var c := e.current()
		var r: CombatResult
		if c.is_player_controlled():
			r = play(c)
			while e.pending != null:
				r = e.answer_reaction(_takes(e.pending))
			if e.state == Encounter.State.ACTIVE and e.current() == c:
				e.end_turn()
		else:
			r = e.run_ai_turn()
			while e.pending != null:
				r = e.answer_reaction(_takes(e.pending))
	for c in e.combatants:
		if c.side == &"party" and e.log.texts().any(func(t: String) -> bool: return t == "%s falls unconscious" % c.name()):
			downs += 1
	return {"outcome": e.outcome if e.state == Encounter.State.OVER else "timeout", "rounds": e.round_no, "downs": downs}
