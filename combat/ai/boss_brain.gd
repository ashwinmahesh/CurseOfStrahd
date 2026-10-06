class_name BossBrain
extends RefCounted
## The boss's choices (ADR 0014): which legendary action to take at the end of another creature's turn, which lair
## action on initiative count 20, and the `strahd` profile's own turn. AiBrain asks it first on a `strahd` turn; when it
## returns null the usual plan (move, then the best attack, with `target_bonus` added to each target's score) runs.
##   strahd: strikes the weakest foe or the one carrying a treasure of the reading, bites whoever he holds, charms a
##           strong foe when no one is charmed by him, calls the Children of the Night once, uses legendary moves to
##           get out of reach when hurt, and below a quarter of his Hit Points takes mist form to regenerate at a
##           distance until he is back over half.
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
		if shaped and (healed or L.form(c) != mist):
			if L.change_form(c, L.base_form(c)).ok:
				ai.last_plan = {"kind": "shape", "why": "back to his true form"}
				if not c.action_available:
					return _close_in(c)
		elif shaped:
			ai.last_plan = {"kind": "keep_away", "why": "regenerating as mist"}
			return _keep_away(c)
		elif low and mist != "" and L.regenerates_now(c) and L.change_why(c, mist) == "":
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


func _foes_seen(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if not h.is_down() and e.can_see(c, h):
			out.append(h)
	return out


## Charm (a save action whose failure Charms): on the foe with the most Hit Points in range, when no one is charmed
## by him and he hasn't tried in the last two rounds. {action, target} or {}.
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
			if best == null or t.creature.hp > best.creature.hp:
				best = t
		if best != null:
			return {"action": act, "target": best}
	return {}


## After a special action: walk up to the best target, if there's movement left.
func _close_in(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act() or c.movement_left <= 0:
		return CombatResult.new()
	var target := _best_target(c)
	if target == null or e.distance(c, target) <= 5:
		return CombatResult.new()
	return e.ai._approach(c, {"target": target, "dash": false})


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

## The legendary option `c` takes now (the end of another creature's turn): {option, target, cell} or {} to wait.
## Hurt and within a foe's reach: a move out of reach. Otherwise the strike worth most per action spent (the bigger
## one only when it is worth it). With nothing in reach and actions to spare: a move toward the best target.
func legendary_plan(c: Combatant) -> Dictionary:
	var e := enc()
	var L := e.legendary
	var left := L.left(c)
	var hurt := c.creature.hp * 2 < c.creature.max_hp()
	var move_opt := {}
	for o: Variant in L.options(c):
		var od := o as Dictionary
		if bool(od.get("move", false)) and Legendary.cost(od) <= left and (move_opt.is_empty() or Legendary.cost(od) < Legendary.cost(move_opt)):
			move_opt = od
	var threatened := _threatened(c)
	if hurt and threatened and not move_opt.is_empty():
		var away := _safe_cell(c)
		if away != c.cell:
			return {"option": str(move_opt["id"]), "cell": away}
	var best := {}
	var best_v := 0.0
	for o2: Variant in L.options(c):
		var od2 := o2 as Dictionary
		if not od2.has("action") or Legendary.cost(od2) > left:
			continue
		var act := (c.creature as Monster).action(str(od2["action"]))
		if act.is_empty() or e.monster_actions.why_not(c, act) != "":
			continue
		for t in e.hostiles_of(c):
			if t.is_down() or L.use_why(c, od2, t, Vector2i(-1, -1)) != "":
				continue
			var v := _expected(c, act, t) + target_bonus(c, t)
			# A life-drinking bite is his favourite: taken whenever it can land, whatever it costs.
			v = v + 100.0 if action_bonus(c, act) > 0.0 else v / float(Legendary.cost(od2))
			if v > best_v:
				best_v = v
				best = {"option": str(od2["id"]), "target": t}
	if not best.is_empty():
		return best
	if not move_opt.is_empty() and not threatened and left > Legendary.cost(move_opt):
		var target := _best_target(c)
		if target != null and e.distance(c, target) > 5:
			var cell := _cell_beside(c, target)
			if cell != c.cell:
				return {"option": str(move_opt["id"]), "cell": cell}
	return {}


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


## The square within its Speed farthest beyond every foe's reach (its own square when nothing is better).
func _safe_cell(c: Combatant) -> Vector2i:
	var e := enc()
	var reach := e.reachable_for(c, c.speed())
	var best := c.cell
	var best_s := _safety(c, c.cell)
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var s := _safety(c, cell) - int((reach[cell] as Dictionary)["cost"]) * 0.01
		if s > best_s + 0.01:
			best_s = s
			best = cell
	return best


func _safety(c: Combatant, cell: Vector2i) -> float:
	var e := enc()
	var nearest := 9999.0
	for h in e.hostiles_of(c):
		if h.is_down():
			continue
		var gap := float(e.grid.distance_ft(cell, c.size_cells, h.cell, h.size_cells) - h.reach_ft())
		nearest = minf(nearest, gap)
	return minf(nearest, 30.0)


## A free square next to `t` that `c` can reach within its Speed, the closest to walk to (its own square if none).
func _cell_beside(c: Combatant, t: Combatant) -> Vector2i:
	var e := enc()
	var reach := e.reachable_for(c, c.speed())
	var best := c.cell
	var best_cost := 1 << 30
	for cell: Vector2i in reach:
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]) or e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells) > 5:
			continue
		if int(info["cost"]) < best_cost:
			best_cost = int(info["cost"])
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
