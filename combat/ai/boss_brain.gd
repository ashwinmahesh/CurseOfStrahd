class_name BossBrain
extends RefCounted
## The boss's choices (ADR 0014): which legendary action to take at the end of another creature's turn, which lair
## action on initiative count 20, and the `strahd` profile's own turn. AiBrain asks it first on a `strahd` turn; when it
## returns null the usual plan (move, then the best attack, with `target_bonus` added to each target's score) runs.
##   strahd: strikes the weakest foe or the one carrying a treasure of the reading, bites whoever he holds, charms a
##           treasure's bearer or a strong foe when no one is charmed by him, calls the Children of the Night once, uses
##           legendary moves to get out of reach when hurt, and below a quarter of his Hit Points takes mist form to
##           regenerate at a distance until he is back over half.
## Any creature sunlight burns (Strahd, his spawn) keeps out of the light it can see: it holds a legendary move back to
## step out of it before its turn and walks out after its action when no foe can strike it as it goes.
## Legendary and lair choices work for any monster that has them; the strahd profile only sharpens the targets.

## The Tarokka's treasures (story/tarokka.gd TREASURE_ITEMS): Strahd wants them out of the party's hands.
const TREASURES := ["sunsword", "holy_symbol_of_ravenkind", "tome_of_strahd"]

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func _strahd(c: Combatant) -> bool:
	return str(c.ai_profile) == "strahd"


## Extra score for attacking `t` (the strahd profile): the weakest foe, a treasure carrier, and whoever he holds.
func target_bonus(c: Combatant, t: Combatant) -> float:
	if not _strahd(c):
		return 0.0
	# He knows an Echo Knight's echo for the image it is.
	if EchoKnight.is_echo(t):
		return -3.0
	var bonus := clampf((40.0 - float(t.creature.hp)) / 10.0, 0.0, 3.0)
	if carries_treasure(t):
		bonus += 4.0
	if str(enc().grapples.get(t.id, "")) == c.id:
		bonus += 2.0
	return bonus


## Extra worth of using `act` (the strahd profile): a bite that drinks the victim's life heals him too.
func action_bonus(c: Combatant, act: Dictionary) -> float:
	if not _strahd(c):
		return 0.0
	for rd: Variant in act.get("on_hit", []):
		if str((rd as Dictionary).get("do", "")) == "heal_self":
			return 10.0
	return 0.0


static func carries_treasure(t: Combatant) -> bool:
	if not t.creature is Character:
		return false
	for entry: Dictionary in (t.creature as Character).inventory:
		if str(entry.get("id", "")) in TREASURES and int(entry.get("qty", 1)) > 0:
			return true
	return false


# --- The strahd turn ----------------------------------------------------------------------------------------------

## The strahd profile's turn before the usual plan: shapes, the Children of the Night, Charm. Null to let AiBrain play
## the usual move-and-attack turn.
func play_turn(c: Combatant) -> Variant:
	var e := enc()
	var L := e.legendary
	var ai := e.ai
	if not L.forms_of(c).is_empty():
		var shaped := L.form(c) != L.base_form(c)
		var low := c.creature.hp * 4 < c.creature.max_hp()
		var healed := c.creature.hp * 2 >= c.creature.max_hp()
		var mist := "mist" if not L.shape(c, "mist").is_empty() else ""
		# He doesn't run from foes he can finish: with every hero left standing under a third of their Hit Points the
		# mist would only let a beaten party's last blades chase him round the room while he regenerates (a stall).
		var finishing := _can_finish_them(c)
		if shaped and (healed or finishing or L.form(c) != mist):
			if L.change_form(c, L.base_form(c)).ok:
				ai.last_plan = {"kind": "shape", "why": "back to his true form"}
				if not c.action_available:
					return _close_in(c)
		elif shaped:
			ai.last_plan = {"kind": "keep_away", "why": "regenerating as mist"}
			return _keep_away(c)
		elif low and not finishing and mist != "" and L.regenerates_now(c) and L.change_why(c, mist) == "":
			L.change_form(c, mist)
			ai.last_plan = {"kind": "mist", "why": "badly hurt: mist form to regenerate"}
			return _keep_away(c)
	var foes := _foes_seen(c)
	if foes.is_empty():
		return null
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		var act := a as Dictionary
		if act.has("summon") and foes.size() >= 2 and L.summon_why(c, act) == "":
			ai.last_plan = {"kind": "summon", "why": str(act.get("name", ""))}
			var r := L.call_children(c, act)
			return e.then(r, func() -> CombatResult: return _close_in(c))
	var charm := charm_plan(c)
	if not charm.is_empty():
		ai.last_plan = {"kind": "charm", "target": charm["target"], "why": "Charm on %s" % (charm["target"] as Combatant).name()}
		e.spend_action(c)
		c.set_meta("charm_round", e.round_no)
		var r2 := CombatResult.new()
		e.monster_actions.save_action(c, charm["action"] as Dictionary, charm["target"] as Combatant, r2)
		return e.then(e.run_reaction_queue(r2), func() -> CombatResult: return _close_in(c))
	return null


## Whether every foe still on its feet is under a third of its Hit Points (and there is one).
func _can_finish_them(c: Combatant) -> bool:
	var any := false
	for h in enc().hostiles_of(c):
		if h.is_down() or not h.can_act():
			continue
		any = true
		if h.creature.hp * 3 > h.creature.max_hp():
			return false
	return any


func _foes_seen(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h):
			out.append(h)
	return out


## Charm (a save action whose failure Charms): on a treasure's bearer in range, else the foe with the most Hit Points,
## when no one is charmed by him and he hasn't tried in the last two rounds. {action, target} or {}.
func charm_plan(c: Combatant) -> Dictionary:
	var e := enc()
	if not c.action_available or (c.has_meta("charm_round") and e.round_no - int(c.get_meta("charm_round")) < 3):
		return {}
	for h in e.hostiles_of(c):
		for fx: Effect in h.creature.effects:
			if &"charmed" in fx.conditions and fx.caster_id == c.id:
				return {}
	for a: Variant in MonsterActions.data_of(c).get("actions", []):
		var act := a as Dictionary
		if str(act.get("kind", "")) != "save" or e.monster_actions.why_not(c, act) != "":
			continue
		var charms := false
		for rd: Variant in act.get("on_fail", []):
			if str((rd as Dictionary).get("condition", "")) == "charmed":
				charms = true
		if not charms:
			continue
		var best: Combatant = null
		for t in e.monster_actions.save_targets(c, act):
			if not e.can_see(c, t) or t.creature.is_condition_immune(&"charmed") or t.creature.has_condition(&"charmed"):
				continue
			if best == null or _charm_rank(t) > _charm_rank(best):
				best = t
		if best != null:
			return {"action": act, "target": best}
	return {}


## Whom Charm goes for first: a hero carrying a treasure of the reading (the Sunsword's bearer can't strike him while
## charmed), then the one with the most Hit Points.
static func _charm_rank(t: Combatant) -> float:
	return (1000.0 if carries_treasure(t) else 0.0) + float(t.creature.hp)


## After a special action: walk up to the best target, if there's movement left.
func _close_in(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act() or c.movement_left <= 0:
		return CombatResult.new()
	var out: Variant = leave_sun(c)
	if out != null:
		return out as CombatResult
	var target := _best_target(c)
	if target == null or e.distance(c, target) <= 5:
		return CombatResult.new()
	# Round dangerous ground it knows of while that reaches the target (combat/ai/ai_hazards.gd).
	var hz := e.ai.hazards.read(c)
	var only: Array[Combatant] = [target]
	var round_it := hz != null \
		and not e.ai.hazards.reachable_foes(c, hz, only, e.ai._usable_options(c), e.ai.hazards.calm_reach(c)).is_empty()
	# Not into sunlight that burns it, to end its turn beside a foe standing in it.
	if not round_it and hz != null and hz.sun_burn(target.cell) > 0.0:
		return CombatResult.new()
	return e.ai._approach(c, {"target": target, "dash": false, "hazards": hz, "round": round_it})


## Its own turn, after its action: standing in sunlight that will burn it as its next turn starts (Sunlight
## Hypersensitivity) with no foe able to strike it as it goes, it walks out of the light to its best square clear of it.
## Null when it stays (a foe beside it: a legendary move takes it out later, or it bears the light).
func leave_sun(c: Combatant) -> Variant:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act() or c.movement_left <= 0 \
			or _threatened(c) or not in_burning_sun(c):
		return null
	var to := _vantage_cell(c, _best_target(c), true)
	if to == c.cell:
		return null
	e.ai.last_plan = {"kind": "leave_sun", "why": "out of the sunlight"}
	var hz := e.ai.hazards.read(c)
	return e.move(c, to, {} if hz == null else hz.avoid)


## Whether `c` stands in sunlight that will burn it as its next turn starts (Sunlight Hypersensitivity).
func in_burning_sun(c: Combatant) -> bool:
	var e := enc()
	if e.sunlit or not c.creature is Monster or e.monster_actions.sunlight(c) != "hypersensitivity":
		return false
	var hz := e.ai.hazards.read(c)
	return hz != null and hz.sun_burn(c.cell) > 0.0


## Moves as far from the foes as it can this turn.
func _keep_away(c: Combatant) -> CombatResult:
	var near := enc().ai._nearest_enemy(c)
	if near == null:
		return CombatResult.new()
	return enc().ai._flee(c, near, false)


func _best_target(c: Combatant) -> Combatant:
	var best: Combatant = null
	var best_s := -1e9
	for t in _foes_seen(c):
		var s := target_bonus(c, t) - enc().distance(c, t) * 0.05
		if s > best_s:
			best_s = s
			best = t
	return best


# --- Legendary actions --------------------------------------------------------------------------------------------

## The legendary option `c` takes now (the end of another creature's turn): {option, target, cell}, {option, spell: an
## AiSpells plan} for a spell option, or {} to wait.
## Hurt and within a foe's reach: a move out of reach. In sunlight that burns it: a move's uses kept back, and spent
## stepping out of the light at the end of the last turn before its own. Otherwise the strike or spell worth most per use
## spent (the bigger one only when it is worth it); a strike that moves first (Pounce) may close in to strike. With
## nothing to strike: a move toward the best target while it would still have the uses to strike once there. Uses come
## back at the start of its own turn, so at the end of the last turn before it, a use no strike can take goes on a move
## to a better square (more foes in its reach, fewer able to reach it, or closer to the best target) rather than going
## to waste. An option it can't take again until its next turn (`once`) waits once taken.
func legendary_plan(c: Combatant) -> Dictionary:
	var e := enc()
	var L := e.legendary
	var left := L.left(c)
	var hurt := c.creature.hp * 2 < c.creature.max_hp()
	var move_opt := {}
	for o: Variant in L.options(c):
		var od := o as Dictionary
		if bool(od.get("move", false)) and Legendary.cost(od) <= left and not L.spent_once(c, od) \
				and (move_opt.is_empty() or Legendary.cost(od) < Legendary.cost(move_opt)):
			move_opt = od
	var budget := L.move_ft(c, move_opt)
	var threatened := _threatened(c)
	if hurt and threatened and not move_opt.is_empty():
		var away := _safe_cell(c, budget)
		if away != c.cell:
			return {"option": str(move_opt["id"]), "cell": away}
	# In sunlight that will burn it as its turn starts (Strahd by the Sunsword or a Daylight): a move's uses are kept
	# back from its strikes, and at the end of the last turn before its own it steps out of the light with them.
	var sun := not move_opt.is_empty() and in_burning_sun(c)
	if sun and _turns_before_own(c) == 0:
		var out := _vantage_cell(c, _best_target(c), false, budget)
		if out != c.cell:
			return {"option": str(move_opt["id"]), "cell": out}
	var best := {}
	var best_v := 0.0
	# A foe that spreads its blows (Story and Balanced) puts a strike on a hero it hasn't struck since its own turn began
	# before one more on a hero it has, whatever the odds, unless it has a reason to go on (AiTactics.spread_rank).
	var spread := e.ai.tactics.spreads(c)
	var best_rank := 1 << 30
	for o2: Variant in L.options(c):
		var od2 := o2 as Dictionary
		if Legendary.cost(od2) > left or L.spent_once(c, od2):
			continue
		if sun and left - Legendary.cost(od2) < Legendary.cost(move_opt):
			continue
		if od2.has("spell"):
			if L.use_why(c, od2, null, Vector2i(-1, -1)) != "":
				continue
			var cast := e.ai.spells._best_use(c, str(od2["spell"]))
			var cast_v := float(cast["score"]) / float(Legendary.cost(od2)) if not cast.is_empty() else 0.0
			if cast_v > 0.0 and (best_rank > 0 or cast_v > best_v):
				best_v = cast_v
				best_rank = 0
				best = {"option": str(od2["id"]), "spell": cast}
			continue
		if not od2.has("action"):
			continue
		var act := (c.creature as Monster).action(str(od2["action"]))
		if act.is_empty() or e.monster_actions.why_not(c, act) != "":
			continue
		var pounce := bool(od2.get("move", false))
		for t in e.hostiles_of(c):
			if t.is_down():
				continue
			var cell := Vector2i(-1, -1)
			if L.use_why(c, od2, t, cell) != "":
				# A strike that moves first closes in to where it reaches its target.
				if not pounce:
					continue
				cell = _cell_in_reach(c, t, L.move_ft(c, od2), _strike_ft(c))
				if cell == c.cell or L.use_why(c, od2, t, cell) != "":
					continue
			var v := 0.0
			var rank := 0
			if spread:
				v = _spread_value(c, act, t)
				rank = _spread_rank(c, act, t)
			else:
				v = _expected(c, act, t) + target_bonus(c, t)
			# A life-drinking bite is his favourite: taken whenever it can land, whatever it costs.
			v = v + 100.0 if action_bonus(c, act) > 0.0 else v / float(Legendary.cost(od2))
			if v > 0.0 and (rank < best_rank or (rank == best_rank and v > best_v)):
				best_v = v
				best_rank = rank
				best = {"option": str(od2["id"]), "target": t}
				if cell != Vector2i(-1, -1):
					best["cell"] = cell
	if not best.is_empty():
		return best
	if move_opt.is_empty():
		return {}
	var target := _best_target(c)
	if not threatened and left - Legendary.cost(move_opt) >= _cheapest_strike(c) and target != null and e.distance(c, target) > 5:
		var cell := _cell_beside(c, target, budget)
		if cell != c.cell:
			return {"option": str(move_opt["id"]), "cell": cell}
	if _turns_before_own(c) == 0:
		var to := _vantage_cell(c, target, false, budget)
		if to != c.cell:
			return {"option": str(move_opt["id"]), "cell": to}
	return {}


## A free square within `budget` feet of `c` from which `t` stands within `strike` feet, the closest to walk to (its
## own square if none), off the dangerous ground it knows of.
func _cell_in_reach(c: Combatant, t: Combatant, budget: int, strike: int) -> Vector2i:
	var e := enc()
	var reach := e.reachable_for(c, budget)
	var hz := e.ai.hazards.read(c)
	var calm := reach if hz == null else e.reachable_for(c, budget, false, hz.avoid)
	var best := c.cell
	var best_cost := 1 << 30
	var crowd := e.ai.crowd_map(c)
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]) or e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) > strike:
			continue
		var way := calm if calm.has(cell) else reach
		if _harm(hz, CombatGrid.path_to(way, cell)) > 0.0:
			continue
		var cost := int((way[cell] as Dictionary)["cost"]) + AiBrain.CROWD_FT * int(crowd.get(cell, 0))
		if cost < best_cost:
			best_cost = cost
			best = cell
	return best


## What a strike of `act` on `t` is worth to a foe that spreads its blows: the odds as it weighs them, the killing-blow
## bonus, a concentrating caster, the foe's own lean (AiTactics.blow_worth), as AiBrain._score weighs a plan's attack.
func _spread_value(c: Combatant, act: Dictionary, t: Combatant) -> float:
	var e := enc()
	var chance := 1.0
	if str(act.get("kind", "")) != "save":
		var o := e.option_by_id(c, "monster:" + str(act["id"]))
		if o.is_empty():
			return 0.0
		chance = float(e.hit_chance(c, t, o)["chance"])
	return e.ai.tactics.blow_worth(c, t, _strike_avg(c, act), chance, float(e.ai.profile(c)["finish"]))


## Where `t` stands among the foes a strike of `act` could go to (AiTactics.spread_rank), the lowest first: 0 for an
## action that catches several foes whoever it is aimed at (a cone, a line, an aura), so no foe is spared its blow.
func _spread_rank(c: Combatant, act: Dictionary, t: Combatant) -> int:
	var e := enc()
	if act.has("area"):
		var caught := 0
		for v in e.monster_actions.save_victims(c, act, t):
			if c.hostile_to(v):
				caught += 1
		if caught > 1:
			return 0
	return e.ai.tactics.spread_rank(c, t, _strike_avg(c, act))


## What a hit of `act` is worth in damage: its average, with a little for its riders (as AiBrain._avg does).
func _strike_avg(c: Combatant, act: Dictionary) -> float:
	return (c.creature as Monster).average_damage(str(act["id"])) + (4.0 if act.has("on_hit") or act.has("on_fail") else 0.0)


## The fewest uses any of `c`'s legendary strikes costs (a huge number when it has none).
func _cheapest_strike(c: Combatant) -> int:
	var least := 1 << 30
	for o: Variant in enc().legendary.options(c):
		if (o as Dictionary).has("action"):
			least = mini(least, Legendary.cost(o as Dictionary))
	return least


## How many other creatures' turns still end before `c`'s own next turn: 0 at the end of the last of them, its last
## chance to spend legendary uses before they come back. Counts the order from the current turn round to `c`, and the
## heroes of a shared party turn who haven't ended theirs.
func _turns_before_own(c: Combatant) -> int:
	var e := enc()
	var at := e.order.find(c)
	var n := e.order.size()
	if at < 0 or e.turn_index < 0 or n == 0:
		return 0
	var cur := e.current()
	var seen := {}
	var i := (e.turn_index + 1) % n
	while i != at and i != e.turn_index:
		var o := e.order[i]
		if o.is_alive() and not o.has_meta("left_fight"):
			seen[o.id] = true
		i = (i + 1) % n
	for id: String in e.shared:
		if not id in e.shared_ended and (cur == null or id != cur.id):
			seen[id] = true
	return seen.size()


## How far `c` strikes from: the longest reach or range of its legendary strikes (a melee reach, a ranged attack's
## normal range, a save action's range), or of any of its actions when it has no legendary strike.
func _strike_ft(c: Combatant) -> int:
	var m := c.creature as Monster
	var acts: Array = []
	for o: Variant in enc().legendary.options(c):
		if (o as Dictionary).has("action"):
			acts.append(m.action(str((o as Dictionary)["action"])))
	if acts.is_empty():
		acts = m.data.get("actions", []) as Array
	var best := 5
	for a: Variant in acts:
		var ad := a as Dictionary
		var atk := ad.get("attack", {}) as Dictionary
		if str(ad.get("kind", "")) == "ranged" and atk.get("range") is Array and not (atk["range"] as Array).is_empty():
			best = maxi(best, int((atk["range"] as Array)[0]))
		elif str(ad.get("kind", "")) == "save":
			best = maxi(best, int((ad.get("targets", {}) as Dictionary).get("range", 5)))
		else:
			best = maxi(best, int(atk.get("reach", 5)))
	return best


## A square within `c`'s Speed that sets up its own turn better than where it stands: more standing foes within its
## reach and fewer able to reach it (a reach or ranged fighter steps back out of theirs), or with none in reach, closer
## to `toward`; clear of the dangerous ground it knows of first, as `_safe_cell` is. Its own square when none is better.
## Within its Speed for a legendary move, or `own_turn` within the movement it has left.
func _vantage_cell(c: Combatant, toward: Combatant, own_turn: bool = false, move_budget: int = -1) -> Vector2i:
	var e := enc()
	var budget := -1 if own_turn else (c.speed() if move_budget < 0 else move_budget)
	var reach := e.reachable_for(c, budget)
	var hz := e.ai.hazards.read(c)
	var calm := reach if hz == null else e.reachable_for(c, budget, false, hz.avoid)
	var here: Array[Vector2i] = [c.cell]
	var strike := _strike_ft(c)
	var best := c.cell
	var best_s := _vantage(c, c.cell, strike, toward) - _harm(hz, here)
	var crowd := e.ai.crowd_map(c)
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]):
			continue
		var way := calm if calm.has(cell) else reach
		var s := _vantage(c, cell, strike, toward) - int((way[cell] as Dictionary)["cost"]) * 0.001 \
			- AiBrain.CROWD_TIE * float(crowd.get(cell, 0))
		s -= _harm(hz, CombatGrid.path_to(way, cell))
		if s > best_s + 0.01:
			best_s = s
			best = cell
	return best


func _vantage(c: Combatant, cell: Vector2i, strike: int, toward: Combatant) -> float:
	var e := enc()
	var in_reach := 0
	var threats := 0
	for h in e.hostiles_of(c):
		if h.is_down():
			continue
		var gap := e.grid.distance_ft(cell, c.size_cells, h.cell, h.size_cells, c.altitude, h.altitude)
		if gap <= strike:
			in_reach += 1
		if h.can_act() and gap <= h.reach_ft():
			threats += 1
	if in_reach > 0:
		return 2.0 * in_reach - threats
	if toward == null:
		return -100.0 - threats
	var to := e.grid.distance_ft(cell, c.size_cells, toward.cell, toward.size_cells, c.altitude, toward.altitude)
	return -100.0 - to / 5.0 - threats


## Expected damage of action `act` on `t` (an attack: hit chance × average; a save action: its average).
func _expected(c: Combatant, act: Dictionary, t: Combatant) -> float:
	var e := enc()
	var m := c.creature as Monster
	if str(act.get("kind", "")) == "save":
		return m.average_damage(str(act["id"])) + (4.0 if act.has("on_fail") else 0.0)
	var o := e.option_by_id(c, "monster:" + str(act["id"]))
	if o.is_empty():
		return 0.0
	return float(e.hit_chance(c, t, o)["chance"]) * m.average_damage(str(act["id"])) + (2.0 if act.has("on_hit") else 0.0)


## Whether a standing foe has `c` within its melee reach.
func _threatened(c: Combatant) -> bool:
	var e := enc()
	for h in e.hostiles_of(c):
		if not h.is_down() and h.can_act() and e.distance(c, h) <= h.reach_ft():
			return true
	return false


## The square within its Speed farthest beyond every foe's reach (its own square when nothing is better), clear of the
## dangerous ground it knows of first (combat/ai/ai_hazards.gd).
func _safe_cell(c: Combatant, budget: int = -1) -> Vector2i:
	var e := enc()
	var ft := c.speed() if budget < 0 else budget
	var reach := e.reachable_for(c, ft)
	var hz := e.ai.hazards.read(c)
	var calm := reach if hz == null else e.reachable_for(c, ft, false, hz.avoid)
	var here: Array[Vector2i] = [c.cell]
	var best := c.cell
	var best_s := _safety(c, c.cell) - _harm(hz, here)
	var crowd := e.ai.crowd_map(c)
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var way := calm if calm.has(cell) else reach
		var s := _safety(c, cell) - int((way[cell] as Dictionary)["cost"]) * 0.01 - AiBrain.CROWD_TIE * float(crowd.get(cell, 0))
		s -= _harm(hz, CombatGrid.path_to(way, cell))
		if s > best_s + 0.01:
			best_s = s
			best = cell
	return best


## Dangerous ground on the walk `path` and where it ends (AiHazards.View.cost), weighed far above any square's safety.
static func _harm(hz: AiHazards.View, path: Array[Vector2i]) -> float:
	return 0.0 if hz == null else hz.cost(path) * 100.0


func _safety(c: Combatant, cell: Vector2i) -> float:
	var e := enc()
	var nearest := 9999.0
	for h in e.hostiles_of(c):
		if h.is_down():
			continue
		var gap := float(e.grid.distance_ft(cell, c.size_cells, h.cell, h.size_cells, c.altitude, h.altitude) - h.reach_ft())
		nearest = minf(nearest, gap)
	return minf(nearest, 30.0)


## A free square next to `t` that `c` can reach within its Speed, the closest to walk to (its own square if none), and
## none on the dangerous ground it knows of or walked to across it (combat/ai/ai_hazards.gd).
func _cell_beside(c: Combatant, t: Combatant, budget: int = -1) -> Vector2i:
	var e := enc()
	var ft := c.speed() if budget < 0 else budget
	var reach := e.reachable_for(c, ft)
	var hz := e.ai.hazards.read(c)
	var calm := reach if hz == null else e.reachable_for(c, ft, false, hz.avoid)
	var best := c.cell
	var best_cost := 1 << 30
	var crowd := e.ai.crowd_map(c)
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]) or e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) > 5:
			continue
		var way := calm if calm.has(cell) else reach
		if _harm(hz, CombatGrid.path_to(way, cell)) > 0.0:
			continue
		var cost := int((way[cell] as Dictionary)["cost"]) + AiBrain.CROWD_FT * int(crowd.get(cell, 0))
		if cost < best_cost:
			best_cost = cost
			best = cell
	return best


# --- Lair actions -------------------------------------------------------------------------------------------------

## The lair action for this round (never `last`): {action, target or targets} or {}. Each kind scores by what it would
## do now: a strike at a foe, a save for the foes in range, a summon when foes gather, a self effect, a told one last.
func lair_plan(m: Combatant, last: String) -> Dictionary:
	var e := enc()
	var L := e.legendary
	var best := {}
	var best_s := -1.0
	for a: Variant in L.lair_actions(m):
		var act := a as Dictionary
		if str(act.get("id", "")) == last:
			continue
		var plan := {"action": act}
		var s := 0.0
		var targets := L.lair_targets(m, act)
		match str(act.get("kind", "text")):
			"attack":
				if targets.is_empty():
					continue
				var t := _pick(m, targets)
				plan["target"] = t
				s = 8.0 + target_bonus(m, t)
			"save":
				if targets.is_empty():
					continue
				targets.sort_custom(func(x: Combatant, y: Combatant) -> bool: return target_bonus(m, x) > target_bonus(m, y))
				var picked: Array = targets.slice(0, maxi(1, int((act.get("targets", {}) as Dictionary).get("count", 1))))
				plan["targets"] = picked
				s = 7.0 + picked.size()
			"summon":
				if _foes_seen(m).size() < 2:
					continue
				s = 5.0
			"self":
				s = 6.0 if m.creature.hp * 2 < m.creature.max_hp() else 4.0
			_:
				s = 1.0
		if s > best_s:
			best_s = s
			best = plan
	return best


func _pick(m: Combatant, targets: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_s := -1e9
	for t in targets:
		var s := target_bonus(m, t) - float(t.creature.ac_value()) * 0.1 - float(t.creature.hp) * 0.01
		if s > best_s:
			best_s = s
			best = t
	return best
