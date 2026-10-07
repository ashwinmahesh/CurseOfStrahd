class_name Legendary
extends RefCounted
## Bosses in a fight (ADR 0014, docs/contracts/combat.md "Bosses"): legendary actions at the end of other creatures'
## turns, lair actions on initiative count 20, Legendary Resistance, Regeneration, Shapechanger forms, Misty Escape to
## the resting place, Children of the Night, and foes that withdraw from a fight. Any monster can use these through
## its stat block; the encounter calls the hooks below and BossBrain (combat/ai/boss_brain.gd) makes the choices.
## Pure logic: what the story must learn (flags, quest stages) waits in `story_flags` and `story_quests`.

## Stat-block trait ids these rules stand behind (tools/data/check_implemented.py looks for the literals).
const TRAITS := ["legendary_resistance", "regeneration", "shapechanger", "misty_escape", "children_of_the_night",
	"charm", "legendary_actions", "lair_actions"]
## Lair actions happen on this initiative count, losing ties.
const LAIR_COUNT := 20
## Where Regeneration, a change of shape or Misty Escape can be blocked.
const DEFAULT_BLOCKED := ["sunlight", "running_water"]

var _enc: WeakRef
## The fight's withdraw blocks: [{who, at_hp_below, after_rounds, flag}].
var withdraws: Array[Dictionary] = []
## What the fight hands back to the story when it ends: flag -> value, quest id -> stage.
var story_flags: Dictionary = {}
var story_quests: Dictionary = {}
## Creatures that left the fight without dying: id -> "mist" (Misty Escape) or "withdraw".
var departed: Dictionary = {}
## The round the lair last acted in, and the lair action it used.
var lair_round: int = 0
var last_lair: String = ""
## Creatures called by Children of the Night still on their way: [{round, monster, count, summoner}].
var incoming: Array[Dictionary] = []


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func data_of(c: Combatant) -> Dictionary:
	return MonsterActions.data_of(c)


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


## Sets the encounter's withdraw block(s) from location data (one object, or a list).
func set_withdraw(spec: Variant) -> void:
	withdraws.clear()
	if spec is Dictionary and not (spec as Dictionary).is_empty():
		withdraws.append((spec as Dictionary).duplicate())
	elif spec is Array:
		for w: Variant in spec:
			withdraws.append((w as Dictionary).duplicate())


# --- Fight hooks ------------------------------------------------------------------------------------------------

## Initiative is rolled: every legendary creature starts with its full set of legendary actions.
func combat_started() -> void:
	for c in enc().combatants:
		if per_round(c) > 0:
			c.set_meta("legendary_left", per_round(c))


## The start of `c`'s turn (before anything else starts there): legendary actions come back, a foe whose time is up
## withdraws, and Regeneration works.
func turn_start(c: Combatant) -> void:
	if not c.creature is Monster or not c.is_alive():
		return
	if per_round(c) > 0:
		c.set_meta("legendary_left", per_round(c))
	var w := withdraw_of(c)
	if not w.is_empty() and w.has("after_rounds") and enc().round_no > int(w["after_rounds"]):
		leave(c, "withdraw")
		return
	_regenerate(c)


## After damage lands on `target` (was_up: it had Hit Points before): a `stopped_by` damage type pauses Regeneration;
## a foe that may withdraw leaves at its threshold instead of dropping; Misty Escape carries a monster at 0 Hit Points
## away, or it is destroyed for good at its resting place. True if the creature left the fight (its death is skipped).
func after_damage(target: Combatant, parts: Array, dr: DamageResult, was_up: bool) -> bool:
	if not target.creature is Monster or departed.has(target.id):
		return false
	var rg := data_of(target).get("regenerates", {}) as Dictionary
	if not rg.is_empty() and dr.final > 0:
		for p: Variant in parts:
			var pd := p as Dictionary
			if str(pd["type"]) in (rg.get("stopped_by", []) as Array) and int(pd["amount"]) > 0 and target.creature.immunity_source(StringName(str(pd["type"]))) == "":
				target.set_meta("regen_stopped", str(pd["type"]))
	if not was_up:
		return false
	var w := withdraw_of(target)
	var down := target.creature.dead or target.creature.hp <= 0
	if not w.is_empty() and w.has("at_hp_below") and (down or target.creature.hp < int(w["at_hp_below"])):
		target.creature.dead = false
		target.creature.hp = maxi(1, target.creature.hp)
		leave(target, "withdraw")
		return true
	if down:
		return _misty_escape(target)
	return false


## Legendary Resistance (after a D20 Test of `c`): a failed saving throw succeeds instead while uses are left.
func after_d20(c: Combatant, t: D20Test) -> void:
	if t.kind != D20Test.Kind.SAVING_THROW or t.success or t.target <= 0 or not c.creature is Monster or c.is_player_controlled():
		return
	var n := int(data_of(c).get("legendary_resistance", 0))
	var used := int(c.get_meta("legendary_resistance_used", 0))
	if used >= n or not c.is_alive():
		return
	c.set_meta("legendary_resistance_used", used + 1)
	t.auto_failed = false
	t.success = true
	t.reroll_note = ("%s; " % t.reroll_note if t.reroll_note != "" else "") + "Legendary Resistance: succeeds instead (%d left)" % (n - used - 1)
	_log("info", "%s shrugs it off: Legendary Resistance (%d left)" % [c.name(), n - used - 1], c)


## A new round begins: creatures called earlier arrive.
func round_started() -> void:
	var e := enc()
	var still: Array[Dictionary] = []
	for inc in incoming:
		if int(inc["round"]) > e.round_no:
			still.append(inc)
			continue
		var by := e.get_c(str(inc["summoner"]))
		if by == null or not by.is_alive():
			continue
		var made := _summon(by, str(inc["monster"]), int(inc["count"]), by.cell, -1)
		if made > 0:
			_log("info", "The children of the night arrive: %d %s" % [made, _plural(str(inc["monster"]), made)], by)
	incoming = still


## The round is over and the lair hasn't acted (everyone rolled 20 or higher): its turn comes now.
func round_ending() -> void:
	var e := enc()
	if e.lair and lair_round < e.round_no and lair_master() != null:
		lair_turn()


# --- Leaving the fight ------------------------------------------------------------------------------------------

## The withdraw block that names `c`'s stat block, or {}.
func withdraw_of(c: Combatant) -> Dictionary:
	var mid := str(data_of(c).get("id", ""))
	for w in withdraws:
		if str(w.get("who", "")) == mid and mid != "":
			return w
	return {}


## `c` leaves the fight without dying ("mist": Misty Escape, "withdraw": the encounter's withdraw): it takes its mist
## (or bat) shape if it has one and is gone: no more turns, no target, no space, no loot. Sets the flag the data names.
func leave(c: Combatant, how: String) -> void:
	var e := enc()
	if departed.has(c.id):
		return
	var me := data_of(c).get("misty_escape", {}) as Dictionary
	var prefs: Array[String] = []
	if how == "mist":
		prefs.append(str(me.get("form", "mist")))
	prefs.append_array(["mist", "bat"])
	var shape_id := ""
	for want in prefs:
		if not shape(c, want).is_empty():
			shape_id = want
			break
	if shape_id != "" and form(c) != shape_id:
		_set_form(c, shape_id)
	departed[c.id] = how
	c.set_meta("left_fight", how)
	if c.creature.concentration != null:
		c.creature.concentration.end("left the fight")
	e._release_grapples_by(c)
	if e.grapples.has(c.id):
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
	c.creature.dead = true
	if how == "mist":
		if me.has("flag"):
			story_flags[str(me["flag"])] = true
		_log("info", "%s dissolves into mist and flees to its resting place" % c.name(), c)
	else:
		var w := withdraw_of(c)
		if w.has("flag"):
			story_flags[str(w["flag"])] = true
		var shown := (" as a %s" % str(shape(c, shape_id).get("name", shape_id)).to_lower()) if shape_id != "" else ""
		_log("info", "%s withdraws from the fight%s" % [c.name(), shown], c)
	e.events.append({"type": "vanish", "id": c.id, "left": how, "narration": str(me.get("narration", "")) if how == "mist" else ""})
	e._check_over()


## Misty Escape at 0 Hit Points: away as mist to its resting place, or destroyed there (or in sunlight or running
## water). True if it escaped.
func _misty_escape(c: Combatant) -> bool:
	var me := data_of(c).get("misty_escape", {}) as Dictionary
	if me.is_empty():
		return false
	var why := blocked(c, me.get("blocked_in", DEFAULT_BLOCKED) as Array)
	if enc().at_place(str(me.get("resting_place", ""))) or why != "":
		_destroyed(c, me, why if why != "" else "in its resting place")
		return false
	c.creature.dead = false
	c.creature.hp = 0
	leave(c, "mist")
	return true


func _destroyed(c: Combatant, me: Dictionary, why: String) -> void:
	if me.has("destroyed_flag"):
		story_flags[str(me["destroyed_flag"])] = true
	var q := me.get("quest", {}) as Dictionary
	if q.has("id"):
		story_quests[str(q["id"])] = str(q["stage"])
	_log("death", "%s is destroyed, %s" % [c.name(), why], c)


## The fight is over and every foe that left did so without one of them dying: nothing to loot.
func no_loot() -> bool:
	if departed.is_empty():
		return false
	for c in enc().combatants:
		if c.side == &"enemy" and c.creature.dead and not departed.has(c.id):
			return false
	return true


## The end banner when a foe's leaving ended the fight ("" for a plain victory or defeat).
func end_title() -> String:
	var e := enc()
	if e.outcome != "victory" or not no_loot():
		return ""
	var parts: Array[String] = []
	for id: String in departed:
		var c := e.get_c(id)
		if c != null and c.side == &"enemy":
			parts.append(("%s escapes as mist" if str(departed[id]) == "mist" else "%s withdraws") % c.name())
	return ", ".join(parts)


# --- Regeneration ---------------------------------------------------------------------------------------------

## Why `c` is blocked by where it stands ("sunlight", "running water"), from a `blocked_in` list, or "".
func blocked(c: Combatant, places: Array) -> String:
	var e := enc()
	if "sunlight" in places and e.in_sunlight(c):
		return "in sunlight"
	if "running_water" in places and e.in_running_water(c):
		return "in running water"
	return ""


## Whether Regeneration would work for `c` at the start of its next turn.
func regenerates_now(c: Combatant) -> bool:
	var rg := data_of(c).get("regenerates", {}) as Dictionary
	return not rg.is_empty() and not c.has_meta("regen_stopped") and blocked(c, _regen_blocks(rg)) == "" \
		and not c.creature.has_flag("cant_regain_hp")


## Where a `regenerates` block doesn't work: its `running_water` and `sunlight` switches.
static func _regen_blocks(rg: Dictionary) -> Array:
	var out: Array = []
	if bool(rg.get("running_water", false)):
		out.append("running_water")
	if bool(rg.get("sunlight", false)):
		out.append("sunlight")
	return out


func _regenerate(c: Combatant) -> void:
	var rg := data_of(c).get("regenerates", {}) as Dictionary
	if rg.is_empty():
		return
	var e := enc()
	var stopped := str(c.get_meta("regen_stopped", ""))
	if c.has_meta("regen_stopped"):
		c.remove_meta("regen_stopped")
	if c.creature.hp < 1:
		return
	var why := ("it took %s damage" % stopped.capitalize()) if stopped != "" else blocked(c, _regen_blocks(rg))
	if why == "" and c.creature.has_flag("cant_regain_hp"):
		why = "it can't regain Hit Points"
	if why != "":
		_log("info", "%s doesn't regenerate: %s" % [c.name(), why], c)
		return
	var healed := c.creature.heal(int(rg["hp"]), "Regeneration")
	if healed > 0:
		_log("heal", "%s regenerates %d Hit Points" % [c.name(), healed], c)
		e.events.append({"type": "heal", "id": c.id, "amount": healed})


# --- Shapes -----------------------------------------------------------------------------------------------------

func forms_of(c: Combatant) -> Dictionary:
	return data_of(c).get("forms", {}) as Dictionary


## The true form's name (actions' `forms` lists use it): the block's `forms.base`, else "humanoid".
func base_form(c: Combatant) -> String:
	return str(forms_of(c).get("base", "humanoid"))


## The shape `c` is in now (its base form when it hasn't changed).
func form(c: Combatant) -> String:
	return str(c.get_meta("form", base_form(c)))


func shape(c: Combatant, id: String) -> Dictionary:
	for s: Variant in forms_of(c).get("shapes", []):
		if str((s as Dictionary).get("id", "")) == id:
			return s as Dictionary
	return {}


## The action ids usable in `c`'s current shape, or null when the shape doesn't limit them (its true form).
func shape_actions(c: Combatant) -> Variant:
	var sh := shape(c, form(c))
	if sh.is_empty() or not sh.has("actions"):
		return null
	return sh["actions"]


## "" if `c` can change into `to` now on its own turn (its base form's name to change back), otherwise why not.
func change_why(c: Combatant, to: String) -> String:
	var e := enc()
	var f := forms_of(c)
	if f.is_empty():
		return "It can't change shape"
	if to == form(c):
		return "Already in that shape"
	if to != base_form(c) and shape(c, to).is_empty():
		return "No such shape"
	if e.current() != c:
		return "Not its turn"
	if not c.can_act():
		return "It can't act"
	var why := blocked(c, f.get("blocked_in", DEFAULT_BLOCKED) as Array)
	if why != "":
		return "Not %s" % why
	if str(f.get("change", "action")) == "bonus_action":
		return "" if c.bonus_available else "Bonus Action already used"
	return "" if c.action_available else "Action already used"


## Shapechanger: `c` spends what a change costs and takes shape `to` (its base form's name to change back).
func change_form(c: Combatant, to: String) -> CombatResult:
	var why := change_why(c, to)
	if why != "":
		return CombatResult.fail(why)
	if not _room_for(c, to):
		return CombatResult.fail("No room for that shape here")
	if str(forms_of(c).get("change", "action")) == "bonus_action":
		c.bonus_available = false
	else:
		enc().spend_action(c)
	_set_form(c, to)
	return CombatResult.new()


func _room_for(c: Combatant, to: String) -> bool:
	var e := enc()
	var size := StringName(str((shape(c, to) if to != base_form(c) else data_of(c)).get("size", "medium")))
	var cells := CombatGrid.size_cells_for(size)
	if cells <= c.size_cells:
		return true
	for cell in CombatGrid.footprint(c.cell, cells):
		var o := e.occupant_at(cell)
		if e.grid.is_solid(cell) or (o != null and o != c):
			return false
	return true


## Puts `c` in shape `to` (no cost): size and speeds swap, the shape's defenses and flags come as an effect, Hit Points
## stay as they are.
func _set_form(c: Combatant, to: String) -> void:
	var e := enc()
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "shape_form":
			c.creature.remove_effect(fx)
	var base := to == base_form(c) or shape(c, to).is_empty()
	var sh := {} if base else shape(c, to)
	c.set_meta("form", base_form(c) if base else to)
	_apply_body(c)
	if not base:
		var fx := Effect.new("%s form" % str(sh.get("name", to)), &"monster", "shape_form")
		fx.ends = Effect.Ends.NEVER
		fx.caster_id = c.id
		for ty: Variant in sh.get("immunities", []):
			fx.with_modifier("immunity", {"value": str(ty)})
		for ty2: Variant in sh.get("resistances", []):
			fx.with_modifier("resistance", {"value": str(ty2)})
		for ty3: Variant in sh.get("vulnerabilities", []):
			fx.with_modifier("vulnerability", {"value": str(ty3)})
		for cond: Variant in sh.get("condition_immunities", []):
			fx.with_modifier("condition_immunity", {"value": str(cond)})
		for ab: Variant in sh.get("save_advantage", []):
			fx.with_modifier("advantage", {"on": "save:%s" % ab})
		var flags := (sh.get("flags", []) as Array).duplicate()
		if sh.has("actions") and (sh["actions"] as Array).is_empty():
			flags.append_array(["cant_attack", "cant_cast"])
		for fl: Variant in flags:
			fx.with_modifier("flag", {"value": str(fl)})
		if not fx.modifiers.is_empty():
			c.creature.add_effect(fx)
	c.movement_left = mini(c.movement_left, c.speed())
	_log("condition", ("%s returns to its true form" % c.name()) if base else ("%s becomes a %s" % [c.name(), str(sh.get("name", to)).to_lower()]), c)
	e.events.append({"type": "form", "id": c.id, "form": form(c), "art": str(sh.get("art", ""))})
	e.events.append({"type": "resize", "id": c.id})
	e.events.append({"type": "condition", "id": c.id})


## Size and speeds for the shape `c` is in (also after a fight is loaded from a save).
func _apply_body(c: Combatant) -> void:
	var m := c.creature as Monster
	var sh := shape(c, form(c))
	var src := sh if not sh.is_empty() else data_of(c)
	m.size = StringName(str(src.get("size", data_of(c).get("size", "medium"))))
	c.size_cells = CombatGrid.size_cells_for(m.size)
	var speeds := {}
	var given := src.get("speed", {"walk": 30}) as Dictionary
	for k: String in given:
		if given[k] is int or given[k] is float:
			speeds[k] = int(given[k])
	m.base_speed = speeds


# --- Legendary actions ------------------------------------------------------------------------------------------

func per_round(c: Combatant) -> int:
	return int((data_of(c).get("legendary_actions", {}) as Dictionary).get("per_round", 0))


func options(c: Combatant) -> Array:
	return (data_of(c).get("legendary_actions", {}) as Dictionary).get("options", []) as Array


func option(c: Combatant, opt_id: String) -> Dictionary:
	for o: Variant in options(c):
		if str((o as Dictionary).get("id", "")) == opt_id:
			return o as Dictionary
	return {}


## Legendary actions `c` has left this round.
func left(c: Combatant) -> int:
	return int(c.get_meta("legendary_left", per_round(c)))


static func cost(opt: Dictionary) -> int:
	return maxi(1, int(opt.get("cost", 1)))


## For the initiative tracker: "◆◆◇" (left and spent), or "".
func pips(c: Combatant) -> String:
	var n := per_round(c)
	if n <= 0:
		return ""
	var have := clampi(left(c), 0, n)
	return "◆".repeat(have) + "◇".repeat(n - have)


## "" if `c` can use legendary option `opt` now on `target` (an action) or toward `cell` (a move), otherwise why not.
func use_why(c: Combatant, opt: Dictionary, target: Combatant, cell: Vector2i) -> String:
	var e := enc()
	if opt.is_empty():
		return "No such legendary action"
	if e.state != Encounter.State.ACTIVE:
		return "Combat is over"
	if e.current() == c:
		return "Only at the end of another creature's turn"
	if not c.can_act() or departed.has(c.id):
		return "%s can't act" % c.name()
	if left(c) < cost(opt):
		return "Not enough legendary actions left"
	if bool(opt.get("move", false)):
		if c.speed() <= 0:
			return "Speed 0"
		var reach := e.reachable_for(c, c.speed())
		if not reach.has(cell) or cell == c.cell or bool((reach[cell] as Dictionary)["occupied"]):
			return "Can't move there"
		return ""
	var act := (c.creature as Monster).action(str(opt.get("action", "")))
	if act.is_empty():
		return "No such action"
	var mwhy := e.monster_actions.why_not(c, act)
	if mwhy != "":
		return mwhy
	if target == null:
		return "Choose a target"
	if str(act.get("kind", "")) == "save":
		return "" if target in e.monster_actions.save_targets(c, act) else "Not a target for %s" % act.get("name", "")
	var o := e.option_by_id(c, "monster:" + str(act["id"]))
	if o.is_empty():
		return "Not an attack"
	return e.attack_legal(c, target, o)


## Uses legendary option `opt_id` (at the end of another creature's turn): an attack or save action on `target`, or a
## move to `cell` that provokes no Opportunity Attacks. May pause for a reaction.
func use(c: Combatant, opt_id: String, target: Combatant = null, cell: Vector2i = Vector2i(-1, -1)) -> CombatResult:
	var e := enc()
	var opt := option(c, opt_id)
	var why := use_why(c, opt, target, cell)
	if why != "":
		return CombatResult.fail(why)
	c.set_meta("legendary_left", left(c) - cost(opt))
	_log("info", "%s uses a legendary action: %s%s (%d left)" % [c.name(), opt.get("name", opt_id),
		(" on %s" % target.name()) if target != null else "", left(c)], c)
	e.events.append({"type": "legendary", "id": c.id, "option": opt_id, "name": str(opt.get("name", opt_id)), "left": left(c)})
	if bool(opt.get("move", false)):
		return _move(c, cell)
	var act := (c.creature as Monster).action(str(opt["action"]))
	if str(act.get("kind", "")) == "save":
		var r := CombatResult.new()
		e.monster_actions.save_action(c, act, target, r)
		return e.run_reaction_queue(r)
	return e._resolve_attack(c, target, e.option_by_id(c, "monster:" + str(act["id"])), {"legendary": true})


## A legendary move: up to its Speed, without Opportunity Attacks, outside its own turn.
func _move(c: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var reach := e.reachable_for(c, c.speed())
	var path := CombatGrid.path_to(reach, cell)
	var keep_move := c.movement_left
	var keep_dis := c.disengaged
	var keep_moved := c.moved
	c.movement_left = c.speed()
	c.disengaged = true
	var r := e._walk(c, path, 1, CombatResult.new(), {"willing": true})
	c.movement_left = keep_move
	c.disengaged = keep_dis
	c.moved = keep_moved
	return r


## The end of `ended`'s turn: each legendary creature (not `ended`) may use one option, as the AI chooses. May pause
## for a reaction; the rest follow once it's answered.
func after_turn(ended: Combatant) -> CombatResult:
	var queue: Array[Combatant] = []
	for c in enc().combatants:
		if c != ended and per_round(c) > 0 and c.is_alive() and not c.is_player_controlled():
			queue.append(c)
	return _next_legendary(queue)


func _next_legendary(queue: Array[Combatant]) -> CombatResult:
	var e := enc()
	while not queue.is_empty() and e.state == Encounter.State.ACTIVE:
		var c := queue.pop_front() as Combatant
		if not c.can_act() or left(c) <= 0 or departed.has(c.id):
			continue
		var plan := e.ai.boss.legendary_plan(c)
		if plan.is_empty():
			continue
		var r := use(c, str(plan["option"]), plan.get("target") as Combatant, plan.get("cell", Vector2i(-1, -1)) as Vector2i)
		if e.pending != null:
			return e.then(r, func() -> CombatResult: return _next_legendary(queue))
	return CombatResult.new()


# --- Lair actions -----------------------------------------------------------------------------------------------

func lair_actions(c: Combatant) -> Array:
	return data_of(c).get("lair_actions", []) as Array


## The creature whose lair this is: the first in the order with lair actions that can act (null if none).
func lair_master(need_act: bool = true) -> Combatant:
	var e := enc()
	if not e.lair:
		return null
	for c in e.order:
		if c.is_alive() and not c.is_player_controlled() and not lair_actions(c).is_empty() and (not need_act or c.can_act()):
			return c
	return null


## Whether the lair acts before the current creature's turn begins (initiative count 20, losing ties).
func lair_due() -> bool:
	var e := enc()
	if not e.lair or lair_round >= e.round_no:
		return false
	var cur := e.current()
	return cur != null and cur.initiative < LAIR_COUNT and lair_master() != null


## For the initiative tracker: where the lair's turn sits in `order` (before that index), or -1 without a lair.
func lair_slot() -> int:
	var e := enc()
	if lair_master(false) == null:
		return -1
	for i in e.order.size():
		if e.order[i].initiative < LAIR_COUNT:
			return i
	return e.order.size()


## The lair's turn: the last lair action's effects end, then the master's AI picks one (never the last one again).
func lair_turn() -> void:
	var e := enc()
	lair_round = e.round_no
	for c in e.combatants:
		for fx: Effect in c.creature.effects.duplicate():
			if fx.source_id.begins_with("lair:"):
				c.creature.remove_effect(fx)
	var m := lair_master()
	if m == null:
		return
	var plan := e.ai.boss.lair_plan(m, last_lair)
	if plan.is_empty():
		return
	var act := plan["action"] as Dictionary
	last_lair = str(act["id"])
	_log("spell", "Initiative 20, the lair acts: %s" % act.get("name", ""), m, [str(act.get("summary", ""))])
	# `targets` is for the view's effect only (emit-only): who the lair turns on.
	var aimed: Array = []
	if plan.get("target") is Combatant:
		aimed.append((plan["target"] as Combatant).id)
	for tv: Variant in plan.get("targets", []):
		aimed.append((tv as Combatant).id)
	e.events.append({"type": "lair", "id": m.id, "action": last_lair, "name": str(act.get("name", "")), "targets": aimed})
	match str(act.get("kind", "text")):
		"self":
			var fx := Effect.new(str(act.get("name", "Lair")), &"monster", "lair:%s" % last_lair)
			fx.ends = Effect.Ends.NEVER
			fx.caster_id = m.id
			for md: Variant in act.get("modifiers", []):
				fx.modifiers.append(Modifier.make((md as Dictionary).duplicate(true), str(act.get("name", "Lair")), &"monster"))
			m.creature.add_effect(fx)
			e.events.append({"type": "condition", "id": m.id})
		"attack":
			var t := plan.get("target") as Combatant
			if t != null:
				_lair_attack(m, act, t)
		"save":
			for tv: Variant in plan.get("targets", []):
				var t2 := tv as Combatant
				if t2.is_alive() and e.state == Encounter.State.ACTIVE:
					_lair_save(m, act, t2)
		"summon":
			var sm := act.get("summon", {}) as Dictionary
			_summon(m, str(sm.get("monster", "")), _count(sm), m.cell, LAIR_COUNT)
	e.spells.zones.prune()
	e._check_over()
	if e.state == Encounter.State.ACTIVE:
		e.run_reaction_queue(CombatResult.new())


## Foes a lair action could reach: hostile to the master, standing, seen by it, within `targets.range` (default 120)
## and fitting `targets` (max_size, types, not_types).
func lair_targets(m: Combatant, act: Dictionary) -> Array[Combatant]:
	var e := enc()
	var tg := act.get("targets", {}) as Dictionary
	var rng := int(tg.get("range", (act.get("attack", {}) as Dictionary).get("range", 120)))
	var out: Array[Combatant] = []
	for t in e.hostiles_of(m):
		if t.is_down() or not e.can_see(m, t) or e.distance(m, t) > rng:
			continue
		if tg.has("max_size") and Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(StringName(str(tg["max_size"]))):
			continue
		if tg.has("types") and not str(t.creature.creature_type) in (tg["types"] as Array):
			continue
		if tg.has("not_types") and str(t.creature.creature_type) in (tg["not_types"] as Array):
			continue
		out.append(t)
	return out


## An attack from the lair itself (an angry spirit at the target's side): a plain d20 + bonus against AC, damage
## doubled dice on a 20, then the riders.
func _lair_attack(m: Combatant, act: Dictionary, t: Combatant) -> void:
	var e := enc()
	var bonus := int((act.get("attack", {}) as Dictionary).get("bonus", 0))
	var nat := e.dice.d20(str(act.get("name", "Lair")))
	var ac := t.creature.ac_value()
	var crit := nat == 20
	var hit := crit or (nat != 1 and nat + bonus >= ac)
	var roll := "d20 %d + %d = %d vs AC %d" % [nat, bonus, nat + bonus, ac]
	if not hit:
		_log("miss", "%s misses %s" % [act.get("name", "The lair"), t.name()], t, [roll])
		return
	var parts: Array = []
	var details: Array[String] = [roll + (", critical hit" if crit else ", hit")]
	for d: Variant in act.get("damage", []):
		var dd := d as Dictionary
		var rolled := e._roll_damage_dice(str(dd["dice"]), crit, 0, str(act.get("name", "")))
		parts.append({"amount": int(rolled["total"]), "type": str(dd["type"])})
		details.append(str(rolled["text"]))
	if not parts.is_empty():
		e.deal_damage(m, t, parts, crit, str(act.get("name", "")), details)
	if t.is_alive() and act.has("on_hit"):
		e.monster_actions.apply_riders(m, t, act["on_hit"] as Array, MonsterActions.taken_by_type(t, parts), str(act.get("name", "")))


## A lair action's saving throw for one foe: damage (half or none on a success), riders on a failure, and its
## summon on a failure (a shadow torn from the target, acting on initiative 20).
func _lair_save(m: Combatant, act: Dictionary, t: Combatant) -> void:
	var e := enc()
	var sv := act.get("save", {}) as Dictionary
	var ab := StringName(str(sv.get("ability", "wis")))
	var label := str(act.get("name", "Lair"))
	var test := t.creature.roll_save(e.dice, ab, int(sv.get("dc", 10)), [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], label, t.name()])
	var parts: Array = []
	var texts: Array[String] = [test.describe()]
	for d: Variant in act.get("damage", []):
		var dd := d as Dictionary
		var rolled := e._roll_damage_dice(str(dd["dice"]), false, 0, label)
		var amount := int(rolled["total"])
		if test.success:
			amount = amount / 2 if str(sv.get("success", "none")) == "half" else 0
		parts.append({"amount": amount, "type": str(dd["type"])})
		texts.append(str(rolled["text"]))
	if parts.any(func(p: Dictionary) -> bool: return int(p["amount"]) > 0):
		e.deal_damage(m, t, parts, false, label, texts)
	elif test.success:
		_log("info", "%s resists %s" % [t.name(), label], t, texts)
	if test.success or not t.is_alive():
		return
	if act.has("on_fail"):
		e.monster_actions.apply_riders(m, t, act["on_fail"] as Array, MonsterActions.taken_by_type(t, parts), label)
	if act.has("summon"):
		var sm := act["summon"] as Dictionary
		var made := _summon(m, str(sm.get("monster", "")), _count(sm), t.cell, LAIR_COUNT)
		if made > 0:
			_log("condition", "%s's %s rises against it" % [t.name(), Compendium.shared().monster_data(str(sm["monster"])).get("name", "summons")], t)


# --- Calling creatures ------------------------------------------------------------------------------------------

## The first `summon` choice allowed where this fight is (outdoors or indoors), or {}.
func summon_choice(act: Dictionary) -> Dictionary:
	var e := enc()
	for ch: Variant in (act.get("summon", {}) as Dictionary).get("choices", []):
		var where := str((ch as Dictionary).get("where", "any"))
		if where == "any" or (where == "outdoors") == e.outdoors:
			return ch as Dictionary
	return {}


## "" if `c` can use its summoning action `act` now (Children of the Night), otherwise why not.
func summon_why(c: Combatant, act: Dictionary) -> String:
	var e := enc()
	if e.current() != c or not c.can_act():
		return "Not now"
	var why := e.monster_actions.why_not(c, act)
	if why != "":
		return why
	if not c.action_available:
		return "Action already used"
	if summon_choice(act).is_empty():
		return "Nothing answers here"
	var place := blocked(c, (act.get("summon", {}) as Dictionary).get("not_in", []) as Array)
	return "Not %s" % place if place != "" else ""


## Children of the Night: `c` spends its action and a use; the creatures arrive after `arrive` rounds (at the start of
## that round, beside it) or at once.
func call_children(c: Combatant, act: Dictionary) -> CombatResult:
	var e := enc()
	var why := summon_why(c, act)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	e.monster_actions.spend(c, act)
	var sm := act["summon"] as Dictionary
	var choice := summon_choice(act)
	var n := _count(choice)
	var arrive: Variant = sm.get("arrive", 0)
	var delay := int(e.dice.roll_expr(str(arrive), "%s: rounds to arrive" % act.get("name", ""))["total"]) if arrive is String else int(arrive)
	var what := _plural(str(choice["monster"]), n)
	if delay <= 0:
		var made := _summon(c, str(choice["monster"]), n, c.cell, -1)
		_log("spell", "%s calls the children of the night: %d %s answer" % [c.name(), made, what], c)
	else:
		incoming.append({"round": e.round_no + delay, "monster": str(choice["monster"]), "count": n, "summoner": c.id})
		_log("spell", "%s calls the children of the night: %d %s will come in %d round%s" % [c.name(), n, what, delay, "" if delay == 1 else "s"], c)
	e.events.append({"type": "spell", "caster": c.id, "spell": str(act.get("id", "")), "cells": [], "targets": []})
	return CombatResult.new()


## How many: `count` (a number or dice) capped at `max`.
func _count(spec: Dictionary) -> int:
	var raw: Variant = spec.get("count", 1)
	var n := int(enc().dice.roll_expr(str(raw), "How many")["total"]) if raw is String else int(raw)
	if spec.has("max"):
		n = mini(n, int(spec["max"]))
	return maxi(1, n)


## Puts `n` of monster `monster_id` on `by`'s side near `near`: after `by` in the order, or on initiative count
## `initiative` (losing ties) when it's 0 or more. Returns how many came.
func _summon(by: Combatant, monster_id: String, n: int, near: Vector2i, initiative: int) -> int:
	var e := enc()
	var data := Compendium.shared().monster_data(monster_id)
	if data.is_empty():
		_log("info", "Nothing comes (no stat block '%s')" % monster_id, by)
		return 0
	var made := 0
	for i in n:
		var cell := e.spells._free_cell_near(near, CombatGrid.size_cells_for(StringName(str(data.get("size", "medium")))))
		if cell.x < 0:
			break
		var sc := e.add(Monster.from_data(data), by.side, cell)
		sc.set_meta("summoner", by.id)
		if initiative >= 0:
			_insert_at(sc, initiative)
		else:
			e.insert_after(by, sc)
		e.events.append({"type": "summon_creature", "id": sc.id, "cell": sc.cell, "caster": by.id})
		made += 1
	return made


## Into the order on initiative count `count`, after everyone who rolled that or higher.
func _insert_at(sc: Combatant, count: int) -> void:
	var e := enc()
	sc.initiative = count
	var at := e.order.size()
	for i in e.order.size():
		if e.order[i].initiative < count:
			at = i
			break
	e.order.insert(at, sc)
	if at <= e.turn_index:
		e.turn_index += 1


static func _plural(monster_id: String, n: int) -> String:
	var name := str(Compendium.shared().monster_data(monster_id).get("name", monster_id.replace("_", " "))).to_lower()
	if n == 1:
		return name
	if name.begins_with("swarm of"):
		return name.replace("swarm of", "swarms of")
	if name.ends_with("f"):
		return name.trim_suffix("f") + "ves"
	return name + ("es" if name.ends_with("s") else "s")


# --- Targets ----------------------------------------------------------------------------------------------------

## Whether `t` is Charmed by `by` (Strahd's Charm makes a willing victim).
static func charmed_by(t: Combatant, by: Combatant) -> bool:
	if t.has_meta("charmed_by") and str(t.get_meta("charmed_by")) == by.id:
		return true
	for fx: Effect in t.creature.effects:
		if &"charmed" in fx.conditions and fx.caster_id == by.id:
			return true
	return false


## Whether `t` meets an attack's target requirement `need` for attacker `c`: a condition it has, or for `willing` and
## `charmed`, Charmed by the attacker.
static func meets(c: Combatant, t: Combatant, need: String) -> bool:
	if need in ["willing", "charmed"]:
		return charmed_by(t, c)
	return t.creature.has_condition(StringName(need))


# --- Saves ------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"withdraws": withdraws.duplicate(true), "story_flags": story_flags.duplicate(), "story_quests": story_quests.duplicate(),
		"departed": departed.duplicate(), "lair_round": lair_round, "last_lair": last_lair, "incoming": incoming.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	withdraws.clear()
	for w: Variant in d.get("withdraws", []):
		withdraws.append((w as Dictionary).duplicate())
	story_flags = (d.get("story_flags", {}) as Dictionary).duplicate()
	story_quests = (d.get("story_quests", {}) as Dictionary).duplicate()
	departed = (d.get("departed", {}) as Dictionary).duplicate()
	lair_round = int(d.get("lair_round", 0))
	last_lair = str(d.get("last_lair", ""))
	incoming.clear()
	for inc: Variant in d.get("incoming", []):
		incoming.append((inc as Dictionary).duplicate())


## After a fight is loaded: shapes get their size and speeds back (the shape's effect is saved with the creature).
func after_restore() -> void:
	for c in enc().combatants:
		if c.creature is Monster and not forms_of(c).is_empty() and c.has_meta("form"):
			_apply_body(c)
