class_name AiBrain
extends RefCounted
## Turns for enemies and neutrals (plan §5.3, enemy AI v1). The player controls every party member and guest;
## this only drives creatures the party doesn't.
##
## Each turn: obey anything that takes the turn away (Turn Undead, Command), then score every attack the creature
## could make this turn — each standing enemy it can see, or whose square it knows (not Hidden), from each square it
## could reach — by expected damage (hit chance with every Advantage source, cover and Pack Tactics included, an unseen
## target's Disadvantage too), a bonus for finishing a foe, and a penalty for the Opportunity Attacks the path would
## provoke. The best plan is a move then an attack; with no attack in reach it Dashes toward its best target, opening a
## shut door on the way if it has the hands and wit for it (_through_door), and a foe cut off from every enemy for two
## turns leaves the fight (AiTactics.stranded_turn). Behavior profiles (monster data "ai_profile") weigh this:
##   pack_hunter: wolves. Loves Pack Tactics and wounded prey, avoids Opportunity Attacks.
##   brute:       goes for the biggest hit, shrugs off Opportunity Attacks.
##   mindless:    zombies. Shambles at the nearest enemy, ignores everything else.
##   cowardly:    flees when Bloodied.
## Steps that can pause for a player's reaction (an Opportunity Attack while moving, Shield, Uncanny Dodge) are
## chained with Encounter.then(), so the turn carries on after the player answers.
## The playthrough's difficulty changes how it fights (combat/ai/ai_tactics.gd): spread or focused blows, potions,
## fleeing a broken fight, and at Honour cruel foes striking the fallen.
## Dangerous ground (combat/ai/ai_hazards.gd: Spirit Guardians, Hunger of Hadar, Spike Growth, burning oil, found
## traps): a creature with an Intelligence above 3 walks round the ground it knows of, attacks from outside it, leaves
## it, and goes in only when no foe can be reached any other way. The party's autopilot (tests) plays heroes so too.

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
## How it fights at the playthrough's difficulty (combat/ai/ai_tactics.gd), and its casters' spells on every mode but
## Story (combat/ai/ai_spells.gd, Difficulty.spells).
var tactics: AiTactics
var spells: AiSpells
## The dangerous ground each creature knows of (combat/ai/ai_hazards.gd).
var hazards: AiHazards
## The fallen hero this turn's plan strikes (Honour), whom the attack steps keep at although they're down.
var _finishing: Combatant = null
## Walking-cost maps by start square and map shape (_walk_from), shared by every foe closing on that square.
var _walks: Dictionary = {}
## Creature id -> the round it held back at the edge of dangerous ground with no way round it (_approach_square): the
## next round it goes in, so a foe never waits out a whole fight there.
var _held_back: Dictionary = {}
## Creature id -> {round, target, gap}: the round it last closed round dangerous ground on a target, and how far off it
## was. Round after round with the gap no smaller (a cleric who keeps her Spirit Guardians on it as it circles), it
## stops circling and strikes from in the ground.
var _rounding: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	boss = BossBrain.new(encounter)
	tactics = AiTactics.new(encounter)
	spells = AiSpells.new(encounter)
	hazards = AiHazards.new(encounter)


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

## A whole turn: begin_turn, then (when that leaves the plan to make) think and finish_turn.
func play_turn(c: Combatant) -> CombatResult:
	var r := begin_turn(c)
	if r != null:
		return r
	return finish_turn(c, think(c))


## Hex or Hunter's Mark on a creature that dropped (owner, 2026-10-12): moved with a Bonus Action, no slot, to the
## nearest foe it can see within range, the way the hotbar's Move Hex does for a hero.
func _move_mark(c: Combatant) -> void:
	var e := enc()
	for a in e.spells.sustained_actions(c):
		if str(a["do"]) != "move_mark" or not bool(a["legal"]):
			continue
		var reach := int((a["def"] as Dictionary).get("range", 90))
		var best: Combatant = null
		for h in e.hostiles_of(c):
			if h.is_down() or not e.can_see(c, h) or e.distance(c, h) > reach:
				continue
			if best == null or e.distance(c, h) < e.distance(c, best):
				best = h
		if best != null:
			e.spells.use_sustained(c, str(a["id"]), [best])


## The turn up to its plan: Fear, Commands, potions, morale, a boss's own moves, bonus actions and stat-block spells.
## Null when the plan comes next (think, then finish_turn); the combat view thinks on a worker thread (FN-14).
func begin_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var fear := e.features.fleeing_from(c)
	if fear != null:
		var by_spell := c.creature.has_flag("fear_flee")
		last_plan = {"kind": "flee", "why": "Fear" if by_spell else "Turned"}
		# Fear's "safest available route" goes round dangerous ground; Turn Undead's flight doesn't look.
		return _flee(c, fear, by_spell, by_spell)
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
		e.ground.drop_held(c, "Command: Drop")
		e.log.add("info", "%s drops what it holds and ends its turn (Command: Drop)" % c.name(), c.id)
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
			return _flee(c, caster, true, false)
	var suggested := _suggested_turn(c)
	if suggested != null:
		return suggested
	if not c.can_act():
		return CombatResult.new()
	_finishing = null
	# A weapon it dropped lying within reach: back in hand with its free object interaction.
	e.ground.ai_pick_up(c)
	_move_mark(c)
	# The difficulty's kit and morale: a Bloodied foe drinks its potion; a broken side flees (combat/ai/ai_tactics.gd).
	if c.side == &"enemy":
		# F13: a Bloodied talker whose side broke gives up, in every mode (story/captives.gd takes it from there).
		if c.creature.is_bloodied() and AiTactics.can_surrender(c) and tactics.broken(c):
			return tactics.surrender_turn(c)
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
	return null


## The turn's plan: {plan: plan_turn's, cast: when the mode's casters weigh their spells (Difficulty.spells: Balanced,
## Tactician, Honour) the best spell of a caster's whole list, or its scroll, when it beats the weapon plan, else {}}. It only reads the fight, so it may run on a worker thread while
## nothing else changes the fight (the combat view's enemy turns, FN-14).
func think(c: Combatant) -> Dictionary:
	var e := enc()
	# Weighing every square and target asks the same creatures thousands of questions: one read (Creature.begin_read).
	Creature.begin_read()
	var plan := plan_turn(c)
	var cast_plan := {}
	if e.difficulty.spells and c.action_available and AiSpells.casts(c):
		cast_plan = spells.plan(c, action_worth(c, plan))
	# Closing in: the square too (finish_turn drops it if a bonus Dash changes what's in reach).
	if str(plan["kind"]) == "approach" and cast_plan.is_empty():
		plan["square"] = _approach_square(c, plan)
	Creature.end_read()
	return {"plan": plan, "cast": cast_plan}


## The turn after its plan (think): the spell, the attack, the approach, a search, or waiting.
func finish_turn(c: Combatant, thought: Dictionary) -> CombatResult:
	var e := enc()
	var plan := thought["plan"] as Dictionary
	var cast_plan := thought["cast"] as Dictionary
	if not cast_plan.is_empty():
		last_plan = cast_plan
		var cr := spells.cast(c, cast_plan)
		if cr.ok or cr.is_paused():
			return e.then(cr, func() -> CombatResult: return _after_main(c))
	last_plan = plan
	# Cut off from every enemy turn after turn: it gives up the fight (combat/ai/ai_tactics.gd).
	var stranded: Variant = tactics.stranded_turn(c, plan)
	if stranded != null:
		return stranded as CombatResult
	match str(plan["kind"]):
		"attack":
			if bool(plan.get("finish", false)):
				_finishing = plan["target"] as Combatant
			return e.then(_move_then_attack(c, plan), func() -> CombatResult: return _after_main(c))
		"approach":
			var had_bonus := c.bonus_available
			if c.creature is Monster:
				e.monster_actions.bonus_action(c, "dash")
			if c.bonus_available != had_bonus:
				plan.erase("square")   # a bonus Dash: farther squares are in reach than when it thought
			return _approach(c, plan)
		"search":
			return e.search(c)
	e.log.add("info", "%s waits" % c.name(), c.id)
	return CombatResult.new()


## After the main action: out of sunlight that burns it (Strahd and his spawn), or skirmishers pull back (Deathless
## Agility's Disengage, or Shadow Stealth to hide).
func _after_main(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act():
		return CombatResult.new()
	if c.creature is Monster:
		e.monster_actions.bonus_action(c, "hide")
		e.monster_actions.bonus_action(c, "swoop")
		e.monster_actions.bonus_action(c, "consume_life")
		# A save Bonus Action (Trample, a bonus save) or Rampage can pause for a hero's prompt: the pull-back waits.
		for plan: String in ["trample", "bonus_save", "rampage"]:
			var r := e.monster_actions.bonus_action(c, plan)
			if r.is_paused():
				return e.then(r, func() -> CombatResult: return _pull_back(c))
		e.monster_actions.bonus_action(c, "vanish")
	# Out of sunlight that burns it, when no foe can strike it as it goes (combat/ai/boss_brain.gd).
	var out: Variant = boss.leave_sun(c)
	if out != null:
		return out as CombatResult
	return _pull_back(c)


## A skirmisher's step back after its main action (Deathless Agility's Disengage, or a flyby).
func _pull_back(c: Combatant) -> CombatResult:
	var e := enc()
	if e.state != Encounter.State.ACTIVE or e.current() != c or not c.can_act():
		return CombatResult.new()
	var prof := profile(c)
	if bool(prof.get("retreat", false)) and c.movement_left > 0:
		var near := _nearest_enemy(c)
		if near != null and e.distance(c, near) <= 5:
			if c.creature is Monster:
				e.monster_actions.bonus_action(c, "retreat")
			if c.disengaged or c.creature.has_flag("flyby"):
				return _flee(c, near, false)
	return CombatResult.new()


## A spell worth casting this turn (spellcaster profile): flee through the Ethereal Plane when badly hurt; then, where
## the mode's casters don't weigh their whole list (Story), Phantasmal Killer on the toughest foe while it has uses, or
## Magic Missile at the weakest foe in range. Where they do, AiSpells weighs those with the rest (think).
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
	if c.creature.hp * 4 < c.creature.max_hp() and (known.has("etherealness") or known.has("plane_shift")) and not c.creature.has_flag("no_teleport"):
		return {"kind": "cast", "spell": "etherealness" if known.has("etherealness") else "plane_shift", "targets": [c], "why": "escape"}
	if foes.is_empty() or (e.difficulty.spells and AiSpells.casts(c)):
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


## An action that casts a spell on a Recharge (a vine blight's Entangling Plants), placed where its area catches two
## foes or more (or the only one in range) and more foes than friends, and never a friend stronger than the caster:
## Entangle holds whoever stands in it, and a blight that roots its own tree blight in place has done the party's work
## (2026-10-13, the Yester Hill summit).
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
		var foes := e.hostiles_of(c).filter(func(h: Combatant) -> bool: return not h.is_down() and e.distance(c, h) <= reach and not companion(h))
		var mine := c.creature as Monster
		var best := Vector2.INF
		var best_n := 0
		var best_score := 0
		var aimed: Combatant = null
		for f: Combatant in foes:
			# The area's near edge on the foe or a few squares off it (a placed cube runs 20 ft east from its point), so it
			# can leave out a friend beside the foe.
			for dx: int in [0, -1, -2, -3, 1]:
				for dz: int in [0, -1, 1, -2, 2]:
					var p := e.center_of(f) + Vector2(dx, dz)
					var at := Vector2i(floori(p.x), floori(p.y))
					if not e.grid.in_bounds(at) or e.grid.distance_ft(c.cell, c.size_cells, at, 1) > reach:
						continue
					var n := 0
					var friends := 0
					var master := false
					for o in e.spells.creatures_in(e.spells.area_for(c, s, p, Vector2.RIGHT)):
						if o == c or o.is_down():
							continue
						if c.hostile_to(o):
							n += 1
						else:
							friends += 1
							var om := o.creature as Monster
							master = master or om == null or mine == null or om.cr > mine.cr
					if master or n - friends <= 0:
						continue
					if n - friends > best_score or (n - friends == best_score and n > best_n):
						best = p
						best_n = n
						best_score = n - friends
						aimed = f
		if aimed != null and (best_n >= 2 or foes.size() == 1):
			return {"kind": "cast", "action": act, "spell": spell_id, "point": best, "why": "%s at %s" % [act.get("name", ""), aimed.name()]}
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
				var foes := e.monster_actions.save_victims(c, act, t0).filter(func(v: Combatant) -> bool: return c.hostile_to(v) and not companion(v))
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
			var pick: Combatant = targets[0]
			for t1 in targets:
				if not companion(t1):
					pick = t1   # a hero before a familiar or a steed
					break
			return {"kind": "save_action", "action": act, "target": pick, "why": "%s on %s" % [act.get("name", ""), pick.name()]}
	return {}


func _effect_of(c: Combatant, source_id: String) -> Effect:
	for fx: Effect in c.creature.effects:
		if fx.source_id == source_id:
			return fx
	return null


## Crown of Madness: before moving, the creature uses its action to make a melee attack against a creature the
## caster picks: a player's caster names it when casting and keeping control (SpellTargeting.crown_attack: no one, or
## no one in reach, and it acts normally); an AI caster picks the first creature it can reach, its foes first.
func _crown_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var caster := e.get_c(str(c.get_meta("crowned_by", "")))
	var best: Combatant = null
	var opt := {}
	if caster != null and caster.is_player_controlled():
		var pick := e.spells.targeting.crown_attack(c)
		best = pick.get("target") as Combatant
		opt = pick.get("option", {}) as Dictionary
	else:
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


## A turn under Suggestion (SpellHandlers._suggestion), or null when none holds it: Go home walks away from the caster
## and leaves the fight once clear of its foes (a party member only walks away); Sit drops what it holds and sits,
## Prone, then stays sitting; Come with me walks to the caster and does nothing else. Stand aside is Calm Emotions'
## indifference, above.
func _suggested_turn(c: Combatant) -> CombatResult:
	var e := enc()
	var lead := _suggester(c)
	if c.creature.has_flag("suggest_leave"):
		var from := lead if lead != null else _nearest_enemy(c)
		if from == null or c.speed() <= 0:
			return CombatResult.new()
		last_plan = {"kind": "flee", "why": "Suggestion: Go home"}
		var r := _flee(c, from, true)
		return e.then(r, func() -> CombatResult:
			if c.is_alive() and c.creature.hp > 0 and c.side != &"party" and tactics._clear_of_foes(c):
				e.legendary.leave(c, "went home")
			return CombatResult.new())
	if c.creature.has_flag("suggest_sit"):
		last_plan = {"kind": "wait", "why": "Suggestion: Sit"}
		if not c.creature.has_condition(&"prone"):
			e.ground.drop_held(c, "Suggestion: Sit")
			c.creature.add_condition(&"prone", "Suggestion")
			e.log.add("condition", "%s puts down what it holds and sits (Suggestion)" % c.name(), c.id)
			e.events.append({"type": "condition", "id": c.id})
		else:
			e.log.add("info", "%s stays sitting (Suggestion)" % c.name(), c.id)
		return CombatResult.new()
	if c.creature.has_flag("suggest_follow") and lead != null:
		last_plan = {"kind": "approach", "why": "Suggestion: Come with me"}
		if e.distance(c, lead) <= 5:
			e.log.add("info", "%s keeps beside %s (Suggestion)" % [c.name(), lead.name()], c.id)
			return CombatResult.new()
		return _approach(c, {"target": lead, "dash": false})
	return null


## Who made the suggestion `c` is carrying out (null if none, or they've gone).
func _suggester(c: Combatant) -> Combatant:
	for fx: Effect in c.creature.effects:
		if fx.source_id in ["suggestion", "mass_suggestion"]:
			return enc().get_c(fx.caster_id)
	return null


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


## A Find Familiar familiar or a Find Steed steed: a foe goes for the heroes first.
static func companion(t: Combatant) -> bool:
	if not t.creature is Monster:
		return false
	var d := (t.creature as Monster).data
	return bool(d.get("familiar", false)) or bool(d.get("steed", false))


## Picks this turn's plan: {kind: attack|approach|search|wait, target, cell, option, score, why}. With dangerous ground
## it knows of (combat/ai/ai_hazards.gd): an attack from a square clear of it, walked to round it, comes first; while a
## foe can still be reached round it, it closes on that one (or strikes a familiar or a steed in reach) rather than go
## in; only when none can be, or it has circled that one a round already and is no nearer (_circling), does it go in,
## where the ground costs least. Such a plan carries the ground: `avoid` (the
## squares its walk goes round), or for an approach `hazards` (AiHazards.View) and `round` (a way round exists).
func plan_turn(c: Combatant) -> Dictionary:
	var e := enc()
	var prof := profile(c)
	var reach := e.reachable_for(c)
	var hz := hazards.read(c)
	var calm := reach if hz == null else e.reachable_for(c, -1, false, hz.avoid)
	# The harm it can't walk away from this turn (deep in a wide area, or held fast): that much counts as clear.
	var unavoidable := 0.0 if hz == null else _least_harm(c, hz, reach, calm)
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
	# A familiar or a steed is struck only when no hero can be reached this turn, moving first included (owner,
	# 2026-10-12: summoned steeds and familiars rank below the players).
	var pet_best := {"kind": "wait", "score": -1e9}
	# Attacks that cost it on dangerous ground, that cost taken off their score: only when no foe can be reached round it.
	var risky := {"kind": "wait", "score": -1e9}
	var risky_pet := {"kind": "wait", "score": -1e9}
	# A foe it can't see but whose square it knows (not Hidden: Invisible, in magical Darkness or a Fog Cloud, past the
	# light) can be struck there too, at Disadvantage (2024: unseen targets), which _score weighs, as a player can.
	var strikable: Array[Combatant] = []
	strikable.append_array(visible)
	for t in heard:
		if not t.creature.has_flag("ethereal"):
			strikable.append(t)
	for t in strikable:
		var pet := companion(t)
		for o in options:
			var p := o["profile"] as WeaponProfile
			var cells := _attack_cells(c, t, o, reach)
			for cell: Vector2i in cells:
				# The walk there goes round the dangerous ground when that reaches the square.
				var walk := calm if calm.has(cell) else reach
				var cost := 0 if cell == c.cell else int((walk[cell] as Dictionary)["cost"])
				var score := _score(c, t, o, cell, cost, walk, prof, threats)
				var into := pet_best if pet else best
				if hz != null:
					var harm := hz.cost(CombatGrid.path_to(walk, cell))
					if harm > unavoidable + 0.01:
						score -= harm
						into = risky_pet if pet else risky
				if score > float(into["score"]):
					into.merge({"kind": "attack", "target": t, "cell": cell, "option": str(o["id"]), "score": score,
						"why": "%s at %s with %s" % [t.name(), cell, p.name]}, true)
	# No attack clear of the dangerous ground: the foes it could reach round it, if any (else it goes in).
	var round_to: Array[Combatant] = []
	var foes: Array[Combatant] = []
	if hz != null and str(best["kind"]) != "attack":
		var near: Array[Combatant] = []
		near.append_array(visible)
		near.append_array(heard)
		for t in near:
			if not companion(t):
				foes.append(t)
		if foes.is_empty():
			foes = near
		round_to = hazards.reachable_foes(c, hz, foes, options, calm)
		if (round_to.is_empty() or _circling(c)) and str(risky["kind"]) == "attack":
			best = risky
			round_to = []
	if str(best["kind"]) != "attack" and str(pet_best["kind"]) == "attack":
		best = pet_best
	if hz != null and round_to.is_empty() and str(best["kind"]) != "attack" and str(risky_pet["kind"]) == "attack":
		best = risky_pet
	# Honour: a cruel foe may strike a hero on 0 Hit Points instead (combat/ai/ai_tactics.gd), not from dangerous ground.
	var fallen := tactics.fallen_plan(c, options, calm, threats, float(prof["oa_fear"]))
	if not fallen.is_empty() and hz != null \
			and hz.cost(CombatGrid.path_to(calm, fallen["cell"] as Vector2i)) > unavoidable + 0.01:
		fallen = {}
	if not fallen.is_empty() and float(fallen["score"]) > float(best["score"]):
		best = fallen
	if str(best["kind"]) == "attack":
		if hz != null:
			best["avoid"] = hz.avoid
		return best
	if hz != null and not foes.is_empty():
		# Closing in round the dangerous ground on a foe it can reach that way, or, with none, the way it must.
		var go0 := _approach_plan(c, round_to if not round_to.is_empty() else foes, prof)
		go0.merge({"threats": threats, "hazards": hz, "round": not round_to.is_empty()}, true)
		var gt := go0.get("target") as Combatant
		if not round_to.is_empty() and gt != null:
			_rounding[c.id] = {"round": e.round_no, "target": gt.id, "gap": e.distance(c, gt)}
		return go0
	if not visible.is_empty():
		# Towards a hero rather than a familiar or a steed, while there's one in sight.
		var heroes: Array[Combatant] = []
		for t in visible:
			if not companion(t):
				heroes.append(t)
		var go := _approach_plan(c, visible if heroes.is_empty() else heroes, prof)
		go["threats"] = threats
		return go
	if not heard.is_empty():
		var go2 := _approach_plan(c, heard, prof)
		go2["threats"] = threats
		return go2
	if hidden_any and c.action_available:
		return {"kind": "search", "score": 0.0, "why": "enemies are hidden"}
	return best


## The least harm the dangerous ground does `c` wherever it ends this turn's walk (`reach`, round the ground by `calm`
## when that gets there), staying put included: 0 unless it can't get out of the ground this turn.
func _least_harm(c: Combatant, hz: AiHazards.View, reach: Dictionary, calm: Dictionary) -> float:
	var here: Array[Vector2i] = [c.cell]
	var least := hz.cost(here)
	for cell: Vector2i in reach:
		if least <= 0.0:
			break
		if not bool((reach[cell] as Dictionary)["occupied"]):
			least = minf(least, hz.cost(CombatGrid.path_to(calm if calm.has(cell) else reach, cell)))
	return least


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
	if e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) <= max_d:
		out.append(c.cell)
	if not c.can_act() or c.movement_left <= 0:
		return out
	var ranged_tries := 0
	for cell: Vector2i in reach:
		if cell == c.cell or bool((reach[cell] as Dictionary)["occupied"]):
			continue
		if e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) > max_d:
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
		return 100.0 - cost - e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) * 0.1
	var keep := c.cell
	c.cell = cell
	# The odds as this foe weighs them: a Balanced one doesn't go round the hero for Flanking (AiTactics.seeks_flanks).
	var weighed := o
	if not tactics.seeks_flanks():
		weighed = o.duplicate()
		weighed["ignore_flanking"] = true
	var hc := e.hit_chance(c, t, weighed)
	c.cell = keep
	if int((hc["situation"] as Dictionary)["cover"]) == CombatGrid.Cover.TOTAL:
		return -1e9
	var avg := _avg(c, o)
	# Foes spread their blows (the party's autopilot keeps its odds as they are: AiTactics.spreads).
	var chance := sqrt(maxf(0.0, float(hc["chance"]))) if tactics.spreads(c) else float(hc["chance"])
	var expected := chance * avg
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
	# Spread the blows: each foe's own lean, and the walk to get there (more for a beast).
	if not echo and c.side == &"enemy":
		score += expected * tactics.taste(c, t)
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
	var sq := (plan["square"] if plan.has("square") else _approach_square(c, plan)) as Dictionary
	var best_cell: Vector2i = sq["cell"]
	if best_cell == c.cell:
		return _through_door(c, plan)
	if bool(sq["dash"]) and int(sq["cost"]) > c.movement_left:
		e.dash(c)
	var moved := e.move(c, best_cell, sq.get("avoid", {}) as Dictionary)
	if not moved.ok:
		return moved
	return e.then(moved, func() -> CombatResult: return _through_door(c, plan))


## At a shut door on its way to the plan's target (one it can open, door_opener): it opens it with its object
## interaction (ObjectActions.toggle_door: free, or Utilize once that's spent) and closes in again with the movement
## it has left. Once a turn; otherwise nothing.
func _through_door(c: Combatant, plan: Dictionary) -> CombatResult:
	var e := enc()
	var target := plan.get("target") as Combatant
	if plan.has("through_door") or target == null or not door_opener(c) or e.state != Encounter.State.ACTIVE \
			or e.current() != c or not c.can_act():
		return CombatResult.new()
	var walk := _walk_from(target.cell, {}, true)
	var far := 1 << 30
	var here := int((walk.get(c.cell, {"cost": far}) as Dictionary)["cost"])
	for o in e.objects.list:
		if not o.is_door() or o.open or o.destroyed or o.locked or e.objects.actions.door_why(c, o) != "":
			continue
		# A door that leads on: its square nearer the target, going through the doors, than where it stands.
		if int((walk.get(o.cells[0], {"cost": far}) as Dictionary)["cost"]) >= here:
			continue
		if not e.objects.actions.toggle_door(c, o.id).ok:
			return CombatResult.new()
		plan.erase("square")
		plan["through_door"] = true
		return _approach(c, plan)
	return CombatResult.new()


## Whether `c` opens a door in its way (the object interaction, 2024): a hero or guest, or a foe with hands and the wit
## for it, not a beast, ooze, plant, construct or swarm, Intelligence 3 or more.
static func door_opener(c: Combatant) -> bool:
	if c.creature is Character:
		return true
	if c.creature.has_flag("swarm") or str(c.creature.creature_type) in ["beast", "ooze", "plant", "construct"]:
		return false
	return c.creature.ability_score(&"int") >= 3


## Whether `c` closed round dangerous ground on a foe last round too and is no nearer it now (_rounding).
func _circling(c: Combatant) -> bool:
	var e := enc()
	var last := _rounding.get(c.id, {}) as Dictionary
	if last.is_empty() or int(last["round"]) != e.round_no - 1:
		return false
	var t := e.get_c(str(last["target"]))
	return t != null and not t.is_down() and e.distance(c, t) >= int(last["gap"])


## The square `c` closes on the plan's target from: {cell, cost (feet), dash: whether it may Dash for it, avoid: the
## squares its walk goes round}. It only looks (one Creature read), so think works it out with the plan. With the plan's
## dangerous ground (`hazards`, plan_turn): while there's a way round it (`round`), only squares walked to round it and
## clear of it, out of it first; otherwise the squares it costs least to stand on, holding back at its edge one round
## at most (_held_back).
func _approach_square(c: Combatant, plan: Dictionary) -> Dictionary:
	var e := enc()
	var target := plan["target"] as Combatant
	# Dash only when the best square needs it: no wasted action when nothing gets closer (a shut door between them).
	var dash_ok := bool(plan.get("dash", false)) and c.action_available and c.speed() > 0
	Creature.begin_read()
	var budget := c.movement_left + (c.speed() if dash_ok else 0)
	var reach := e.reachable_for(c, budget)
	var hz := plan.get("hazards") as AiHazards.View
	var round_it := hz != null and bool(plan.get("round", false))
	var calm := reach if hz == null else e.reachable_for(c, budget, false, hz.avoid)
	# Walking distance to the target (around walls), not the straight line: a creature on the far side of a wall
	# heads for the door rather than pressing its face to the stones, a shut one too when it opens doors (_through_door).
	var walk := _walk_from(target.cell, hz.avoid if round_it else {}, door_opener(c))
	var dist := func(cell: Vector2i) -> int:
		var straight := e.grid.distance_ft(cell, c.size_cells, target.cell, target.size_cells, c.altitude, target.altitude)
		if straight <= 5 or not walk.has(cell):
			return straight if walk.has(cell) or straight <= 5 else straight + 1000
		return int((walk[cell] as Dictionary)["cost"])
	# With no way round, the ground weighs only until it has held back once (then on in it goes).
	var weigh := round_it or (hz != null and int(_held_back.get(c.id, -9)) != e.round_no - 1)
	var best_cell := c.cell
	var here: Array[Vector2i] = [c.cell]
	var best_base := int(dist.call(c.cell))
	var nearest := best_base
	var best_d := best_base + _harm_ft(hz, round_it, here, weigh)
	var best_cost := 0
	var prof := profile(c)
	var threats: Array[Dictionary] = []
	if float(prof["oa_fear"]) > 0.0:
		# The plan's own threats when it brought them (nothing has moved since), else worked out now.
		if plan.has("threats"):
			threats.assign(plan["threats"] as Array)
		else:
			threats = _threats(c)
	for cell: Vector2i in (calm if round_it else reach):
		var info := reach[cell] as Dictionary
		if bool(info["occupied"]):
			continue
		var d := int(dist.call(cell))
		# A square already farther than the best one can't win, whatever its Opportunity Attacks or dangerous ground
		# (they only add).
		if d > best_d:
			continue
		var way := calm if calm.has(cell) else reach
		var cost := int((way[cell] as Dictionary)["cost"])
		if not threats.is_empty() and _oa_risk(c, CombatGrid.path_to(way, cell), threats) > 0.0:
			d += 15
		var base := d
		nearest = mini(nearest, base)
		if hz != null:
			d += _harm_ft(hz, round_it, CombatGrid.path_to(way, cell), weigh)
		if d < best_d or (d == best_d and cost < best_cost):
			best_d = d
			best_cell = cell
			best_cost = cost
			best_base = base
	if hz != null and not round_it and weigh and best_base > nearest:
		_held_back[c.id] = e.round_no
	Creature.end_read()
	return {"cell": best_cell, "cost": best_cost, "dash": dash_ok, "avoid": {} if hz == null else hz.avoid}


## Dangerous ground on the walk `path` and where it ends, in feet of approach (_approach_square): any at all rules a
## square out while there's a way round it; otherwise every point of expected harm weighs 2 ft (nothing unless `weigh`).
static func _harm_ft(hz: AiHazards.View, round_it: bool, path: Array[Vector2i], weigh: bool = true) -> int:
	if hz == null or not weigh:
		return 0
	var harm := hz.cost(path)
	if harm <= 0.0:
		return 0
	return (1000 if round_it else 0) + int(harm * 2.0)


## Walking costs from `cell` to every square of the map (no creature in the way: the shape of the walls, doors and
## ground, and round the `avoid` squares; `doors`: shut doors that aren't locked count as open), kept while the map is
## unchanged: several foes closing on the same hero share one search (FN-14).
func _walk_from(cell: Vector2i, avoid: Dictionary = {}, doors: bool = false) -> Dictionary:
	var g := enc().grid
	var key := "%d|%d|%s" % [hash([g.width, g.depth, g._flags, g._height]), g.raised.size(), cell]
	if not avoid.is_empty():
		key += "|%d" % avoid.hash()
	if doors:
		key += "|doors"
	if _walks.has(key):
		return _walks[key] as Dictionary
	if _walks.size() > 32:
		_walks.clear()
	if doors:
		g = tactics.open_grid(false, false)
	var walk := g.reachable(cell, 1, 4000, func(x: Vector2i) -> bool: return avoid.has(x),
		func(_x: Vector2i) -> bool: return false, func(_x: Vector2i) -> bool: return false)
	_walks[key] = walk
	return walk


func _move_then_attack(c: Combatant, plan: Dictionary) -> CombatResult:
	var e := enc()
	var dest: Vector2i = plan["cell"]
	var target := plan["target"] as Combatant
	var option_id := str(plan["option"])
	var after := func() -> CombatResult:
		return _attack_step(c, target, option_id)
	if dest != c.cell:
		var r := e.move(c, dest, plan.get("avoid", {}) as Dictionary)
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
					if tt == null or (companion(tt) and not companion(h)):
						tt = h   # a hero in reach before a familiar or a steed
					if not companion(tt):
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
		if t.is_down() or (not e.can_see(c, t) and t.hidden):
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


## Moves as far from `from` as it can (Turned creatures can't Dash; Command: Flee and cowards can). `heed`: it keeps
## out of the dangerous ground it knows of where it can (combat/ai/ai_hazards.gd), the least harm first, then the
## farthest; a flight it's made to take (Turn Undead, Command) doesn't look.
func _flee(c: Combatant, from: Combatant, may_dash: bool, heed: bool = true) -> CombatResult:
	var e := enc()
	if c.speed() <= 0:
		return CombatResult.new()
	if may_dash and c.can_act() and c.action_available:
		e.dash(c)
	var reach := e.reachable_for(c)
	var hz := hazards.read(c) if heed else null
	var calm := reach if hz == null else e.reachable_for(c, -1, false, hz.avoid)
	var best_cell := c.cell
	var best_d := e.grid.distance_ft(c.cell, c.size_cells, from.cell, from.size_cells)
	var here: Array[Vector2i] = [c.cell]
	var best_harm := 0.0 if hz == null else hz.cost(here)
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var d := e.grid.distance_ft(cell, c.size_cells, from.cell, from.size_cells)
		var harm := 0.0 if hz == null else hz.cost(CombatGrid.path_to(calm if calm.has(cell) else reach, cell))
		if harm < best_harm or (harm == best_harm and d > best_d):
			best_d = d
			best_harm = harm
			best_cell = cell
	e.log.add("info", "%s flees from %s" % [c.name(), from.name()], c.id)
	if best_cell == c.cell:
		return CombatResult.new()
	return e.move(c, best_cell, {} if hz == null else hz.avoid)
