class_name Encounter
extends RefCounted
## A fight on the grid (plan §5.3, ADR 0007): initiative and turns under the 2024 action economy, movement with
## Opportunity Attacks, attacks with every Advantage source and cover, reactions that pause for the player's
## choice, the standard actions, and the combat log. Pure logic with no nodes: the scene animates `events`, the
## HUD reads state and the log, and AiBrain drives enemies and neutrals. Spells live in SpellCaster and class
## features in CombatFeatures.

enum State { SETUP, ACTIVE, OVER }

## Default per-reaction rule for player-controlled creatures without one set: "ask", "auto" or "never".
var default_player_reaction: String = "ask"

var grid: CombatGrid
var dice: DiceRoller
var combatants: Array[Combatant] = []
var order: Array[Combatant] = []
var turn_index: int = -1
var round_no: int = 0
var state: State = State.SETUP
var outcome: String = ""
var log := CombatLog.new()
## For the scene: {type: move|attack|damage|heal|condition|death|turn|round|spell|reaction|over, ...}
var events: Array[Dictionary] = []
## Short-lived combat marks (Help, Vex, Sap, Guiding Bolt, Steady Aim, Shocking Grasp):
## {kind, target, attacker, side, source, expires_owner, expires_phase, consume}
var marks: Array[Dictionary] = []
## Grappled creature id -> grappler id, and the escape DC.
var grapples: Dictionary = {}
var pending: ReactionRequest = null
## Creature ids the party has learned about with the Study action (stat-block details shown in tooltips).
var studied: Dictionary = {}
var spells: SpellCaster
var features: CombatFeatures
var ai: AiBrain
var _cover_cache: Dictionary = {}
## Savage Attacker is once per turn, any creature's turn: creature id -> the turn it was used on.
var _savage_turn: Dictionary = {}
## The map's light: bright, dim or dark (lanterns, moonlight, a lightless cellar); sunlit maps are in sunlight.
var ambient_light: String = "bright"
var sunlit: bool = false
## Reactions waiting to be offered after the current attack or spell finishes (Hellish Rebuke): {kind, reactor, trigger}.
var reaction_queue: Array[Dictionary] = []
## Shown when the fight starts.
var title: String = ""
var intro: String = ""


func _init(grid_: CombatGrid, dice_: DiceRoller) -> void:
	grid = grid_
	dice = dice_
	spells = SpellCaster.new(self)
	features = CombatFeatures.new(self)
	ai = AiBrain.new(self)


# --- Setup ----------------------------------------------------------------------------------------

func add(creature: Creature, side: StringName, cell: Vector2i) -> Combatant:
	var c := Combatant.new(creature, side, cell)
	var base := c.id
	var n := 2
	while get_c(c.id) != null:
		c.id = "%s_%d" % [base, n]
		n += 1
	creature.id = c.id
	combatants.append(c)
	return c


func get_c(id: String) -> Combatant:
	for c in combatants:
		if c.id == id:
			return c
	return null


func current() -> Combatant:
	return order[turn_index] if turn_index >= 0 and turn_index < order.size() else null


## Rolls Initiative (2024: a Dexterity check; surprised creatures roll with Disadvantage; identical monsters share
## one roll) and starts round 1. Ties: higher Dexterity first, then the party.
func start(surprised_ids: Array = []) -> void:
	var group_rolls := {}
	for c in combatants:
		c.surprised = c.id in surprised_ids
		var group := ""
		if c.creature is Monster:
			group = str((c.creature as Monster).data.get("id", ""))
		if group != "" and group_rolls.has(group):
			c.initiative = int(group_rolls[group])
			c.initiative_group = group
			continue
		var dis: Array[String] = []
		if c.surprised:
			dis.append("Surprised")
		var bonus := c.creature.initiative_bonus()
		var t := c.creature.roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, 0, c.creature.initiative_keys(), [], dis,
			"Initiative (%s)" % c.name())
		c.initiative_test = t
		c.initiative = t.total
		if group != "":
			group_rolls[group] = t.total
			c.initiative_group = group
		log.add("roll", "%s rolls Initiative: %d" % [c.name(), t.total], c.id, [t.describe(), bonus.describe()])
	order = combatants.duplicate()
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		var da := a.creature.ability_score(&"dex")
		var db := b.creature.ability_score(&"dex")
		if da != db:
			return da > db
		return a.side == &"party" and b.side != &"party")
	state = State.ACTIVE
	round_no = 1
	log.round_no = 1
	log.add("turn", "Round 1", "")
	events.append({"type": "round", "round": 1})
	turn_index = 0
	_begin_turn()


# --- Queries --------------------------------------------------------------------------------------

func living() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c in combatants:
		if c.is_alive():
			out.append(c)
	return out


func hostiles_of(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in combatants:
		if o != c and o.is_alive() and c.hostile_to(o):
			out.append(o)
	return out


func allies_of(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in combatants:
		if o != c and o.is_alive() and c.allied_with(o):
			out.append(o)
	return out


func occupant_at(cell: Vector2i) -> Combatant:
	for c in combatants:
		if c.is_alive() and cell in c.footprint():
			return c
	return null


func distance(a: Combatant, b: Combatant) -> int:
	return grid.distance_ft(a.cell, a.size_cells, b.cell, b.size_cells)


## Squares other creatures stand in, with their names, for cover (creatures give Half Cover).
func creature_cells(exclude: Array = []) -> Dictionary:
	var out := {}
	for c in combatants:
		if c.is_alive() and not c in exclude and not c.is_down():
			for cell in c.footprint():
				out[cell] = c.name()
	return out


func cover(attacker: Combatant, target: Combatant) -> Dictionary:
	var key := [_layout_hash(), attacker.cell, attacker.size_cells, target.cell, target.size_cells, attacker.id, target.id].hash()
	if _cover_cache.has(key):
		return _cover_cache[key] as Dictionary
	if _cover_cache.size() > 20000:
		_cover_cache.clear()
	var result := grid.cover_between(attacker.cell, attacker.size_cells, target.cell, target.size_cells,
		creature_cells([attacker, target]))
	_cover_cache[key] = result
	return result


## Where everyone stands and who is up: cover from creatures depends on it.
func _layout_hash() -> int:
	var parts: Array = []
	for c in combatants:
		if c.is_alive() and not c.is_down():
			parts.append(c.cell)
			parts.append(c.size_cells)
	return parts.hash()


## Whether `a` can see `b`: line of sight through walls, Heavily Obscured squares (Fog Cloud, Darkness), light
## (Darkvision in the dark; nothing but Blindsight or Truesight in magical Darkness), and `b` being Invisible,
## hidden or on the Ethereal Plane (See Invisibility and Truesight see the Invisible; Faerie Fire and Starry Wisp
## take its benefit away; Mind Spike's caster always knows where its target is).
func can_see(a: Combatant, b: Combatant) -> bool:
	var dist := distance(a, b)
	var blind := a.creature.sense_range("blindsight")
	var truesight := a.creature.sense_range("truesight")
	var by_sense := (blind > 0 and dist <= blind) or (truesight > 0 and dist <= truesight)
	if b.creature.has_flag("ethereal"):
		return truesight > 0 and dist <= truesight and grid.can_see(a.cell, a.size_cells, b.cell, b.size_cells)
	if not grid.can_see(a.cell, a.size_cells, b.cell, b.size_cells):
		return false
	if b.creature.has_flag("tracked_by:%s" % a.id):
		return true
	if blind > 0 and dist <= blind:
		return true
	if a.creature.has_flag("cant_see"):
		return false
	var outlined := b.creature.has_flag("no_invisible")
	if b.hidden and not outlined:
		return false
	if b.creature.has_condition(&"invisible") and not outlined:
		var sees_invisible := a.creature.has_flag("see_invisibility") or (truesight > 0 and dist <= truesight)
		if not sees_invisible:
			return false
	if spells.zones.line_obscured(a.cell, a.size_cells, b.cell, b.size_cells) and not by_sense:
		return false
	match light_at(b.cell):
		"magic_dark":
			return by_sense
		"dark":
			return by_sense or (a.creature.darkvision() >= dist and a.creature.darkvision() > 0) or outlined
	return true


## The light on a square: "bright", "dim", "dark", or "magic_dark" (Darkness), from the map's light and spells.
func light_at(cell: Vector2i) -> String:
	if spells.zones.magical_darkness(cell):
		return "magic_dark"
	var sl := spells.zones.spell_light(cell)
	var lvl := str(sl["level"])
	if lvl == "bright" or ambient_light == "bright":
		return "bright"
	if lvl == "dim" or ambient_light == "dim":
		return "dim"
	return "dark"


## Whether sunlight falls on a creature (Daylight, or a sunlit map): Sunlight Sensitivity and Hypersensitivity.
func in_sunlight(c: Combatant) -> bool:
	if sunlit:
		return true
	for cell in c.footprint():
		if bool(spells.zones.spell_light(cell)["sunlight"]) and not spells.zones.magical_darkness(cell):
			return true
	return false


## Charmed (2024): a Charmed creature can't attack its charmer or target it with damaging abilities or magic.
## "" if `c` may target `t`.
func charm_blocks(c: Combatant, t: Combatant) -> String:
	if not c.creature.has_condition(&"charmed"):
		return ""
	for fx: Effect in c.creature.effects:
		if StringName("charmed") in fx.conditions and fx.caster_id == t.id:
			return "%s is Charmed by %s and can't attack it" % [c.name(), t.name()]
	if c.has_meta("charmed_by") and str(c.get_meta("charmed_by")) == t.id:
		return "%s is Charmed by %s and can't attack it" % [c.name(), t.name()]
	return ""


## Mirror Image: when an attack hits a creature with duplicates (and the attacker relies on sight), roll a d6 per
## duplicate; any 3 or higher means a duplicate is hit instead and destroyed. True if a duplicate took the hit.
func mirror_image_takes(t: Combatant, attacker: Combatant, _total: int) -> bool:
	if not t.creature.has_flag("mirror_image"):
		return false
	if attacker.creature.has_flag("cant_see") or attacker.creature.sense_range("blindsight") >= distance(attacker, t) \
			or attacker.creature.sense_range("truesight") >= distance(attacker, t):
		return false
	for fx: Effect in t.creature.effects:
		if fx.source_id != "mirror_image":
			continue
		var n := int(fx.data.get("duplicates", 0))
		if n <= 0:
			return false
		var rolls := dice.roll(6, n, "Mirror Image")
		var redirected := false
		for v in rolls:
			if v >= 3:
				redirected = true
		if redirected:
			fx.data["duplicates"] = n - 1
			log.add("miss", "The attack strikes one of %s's duplicates (%d left)" % [t.name(), n - 1], t.id, ["Mirror Image d6: %s" % str(rolls)])
			if n - 1 <= 0:
				t.creature.remove_effect(fx)
		return redirected
	return false


## Puts a newly summoned creature into the turn order right after its summoner.
func insert_after(c: Combatant, sc: Combatant) -> void:
	var i := order.find(c)
	sc.initiative = c.initiative
	if i < 0:
		order.append(sc)
		return
	order.insert(i + 1, sc)
	if turn_index > i:
		turn_index += 1


## Squares `c` can reach with its movement (or `budget` feet). A Prone creature crawls (double cost) unless
## `standing` says it will stand up first.
func reachable_for(c: Combatant, budget: int = -1, standing: bool = false) -> Dictionary:
	var feet := c.movement_left if budget < 0 else budget
	if c.creature.has_condition(&"prone") and not standing:
		feet = feet / 2   # crawling: every foot costs 1 extra
	var occ := _occupancy_for(c)
	return grid.reachable(c.cell, c.size_cells, feet, _has_fn(occ["blocked"] as Dictionary),
		_has_fn(occ["slowed"] as Dictionary), _has_fn(occ["occupied"] as Dictionary), move_mode(c))


## How `c` moves: flying (a fly speed at least its walking speed, Fly, Gaseous Form) or climbing (Spider Climb).
func move_mode(c: Combatant) -> int:
	var mode := 0
	if c.creature.speed("fly").total() > 0 and c.creature.speed("fly").total() >= c.creature.speed().total():
		mode |= CombatGrid.MOVE_FLY
	if c.creature.has_flag("spider_climb") or c.creature.speed("climb").total() > 0:
		mode |= CombatGrid.MOVE_CLIMB
	return mode


## How other creatures' squares affect `c`'s movement: {blocked, slowed, occupied}, each a set of cells.
## 2024: you can pass through an ally, an Incapacitated creature, a Tiny creature or one two sizes different
## (Halfling Nimbleness: any larger creature); another creature's space is Difficult Terrain unless it's Tiny or
## your ally; you can't end your move in an occupied space.
func _occupancy_for(c: Combatant) -> Dictionary:
	var blocked := {}
	var slowed := {}
	var occupied := {}
	var my_size := Creature.SIZES.find(c.creature.size)
	for o in combatants:
		if o == c or not o.is_alive():
			continue
		var o_size := Creature.SIZES.find(o.creature.size)
		var passable := c.allied_with(o) or o.creature.has_flag("no_actions") or o.creature.size == &"tiny" \
			or absi(o_size - my_size) >= 2 or (c.creature.has_flag("halfling_nimbleness") and o_size > my_size)
		var slows := not c.allied_with(o) and o.creature.size != &"tiny"
		for cell in o.footprint():
			occupied[cell] = true
			if not passable:
				blocked[cell] = true
			if slows:
				slowed[cell] = true
	for cell: Vector2i in spells.zones.difficult_cells(c):
		slowed[cell] = true
	if c.creature.has_flag("pass_through_creatures"):
		blocked = {}
	return {"blocked": blocked, "slowed": slowed, "occupied": occupied}


static func _has_fn(set: Dictionary) -> Callable:
	return func(cell: Vector2i) -> bool: return set.has(cell)


# --- Turns ----------------------------------------------------------------------------------------

func _begin_turn() -> void:
	var c := current()
	if c == null:
		return
	for o in combatants:
		o.cast_slot_spell_this_turn = false
		o.creature.on_turn_start(c.id)
	_expire_marks(c.id, "start")
	c.reset_turn()
	if c.creature.has_flag("hasted"):
		c.haste_action = true
	log.add("turn", "%s's turn" % c.name(), c.id)
	events.append({"type": "turn", "id": c.id, "round": round_no})
	spells.turn_start(c)
	if c.creature.has_flag("no_action_or_bonus"):
		c.action_available = false
		c.bonus_available = false
		log.add("info", "%s can't take an action or a Bonus Action this turn" % c.name(), c.id)
	if needs_death_save(c) and not c.is_player_controlled():
		death_save(c)


## Ends the current creature's turn: end-of-turn effects and repeated saves, then the next creature (and round).
func end_turn() -> CombatResult:
	if pending != null:
		return CombatResult.fail("Answer the reaction prompt first")
	if state != State.ACTIVE:
		return CombatResult.fail("Combat is over")
	var c := current()
	if needs_death_save(c):
		death_save(c)
		if state != State.ACTIVE:
			return CombatResult.new()
	for o in combatants:
		o.creature.on_turn_end(c.id)
	_expire_marks(c.id, "end")
	spells.turn_end(c)
	spells.zones.prune()
	_check_over()
	if state != State.ACTIVE:
		return CombatResult.new()
	for i in order.size():
		turn_index += 1
		if turn_index >= order.size():
			turn_index = 0
			round_no += 1
			log.round_no = round_no
			log.add("turn", "Round %d" % round_no, "")
			events.append({"type": "round", "round": round_no})
		if current().is_alive():
			break
	_begin_turn()
	return CombatResult.new()


func is_over() -> bool:
	return state == State.OVER


func _check_over() -> void:
	if state != State.ACTIVE:
		return
	var party_up := false
	var enemies_up := false
	for c in combatants:
		if not c.is_alive() or c.creature.hp <= 0:
			continue
		if c.side in [&"party", &"guest"]:
			party_up = true
		elif c.side == &"enemy":
			enemies_up = true
	if not enemies_up:
		state = State.OVER
		outcome = "victory"
	elif not party_up:
		state = State.OVER
		outcome = "defeat"
	if state == State.OVER:
		log.add("info", "Victory!" if outcome == "victory" else "The party has fallen.", "")
		events.append({"type": "over", "outcome": outcome})


## True if something takes this creature's turn out of its controller's hands (Command, Fear, Turn Undead, Crown of
## Madness, Calm Emotions): the AI plays it as the effect demands, even for a party member.
func compelled(c: Combatant) -> bool:
	for f: String in ["command_grovel", "command_halt", "command_flee", "command_approach", "command_drop", "fear_flee", "crowned"]:
		if c.creature.has_flag(f):
			return true
	return features.fleeing_from(c) != null


## Plays the current creature's turn with the AI if it isn't player-controlled.
func run_ai_turn() -> CombatResult:
	var c := current()
	if c == null or (c.is_player_controlled() and not compelled(c)):
		return CombatResult.fail("Not an AI turn")
	if not c.can_act() and features.fleeing_from(c) == null:
		return end_turn()
	return then(ai.play_turn(c), func() -> CombatResult:
		if state == State.ACTIVE and current() == c:
			return end_turn()
		return CombatResult.new())


# --- Marks ----------------------------------------------------------------------------------------

func add_mark(mark: Dictionary) -> void:
	marks.append(mark)


func _expire_marks(owner_id: String, phase: String) -> void:
	var keep: Array[Dictionary] = []
	for m in marks:
		if str(m.get("expires_owner", "")) == owner_id and str(m.get("expires_phase", "")) == phase:
			if int(m.get("skip", 0)) <= 0:
				continue
			m["skip"] = int(m["skip"]) - 1
		keep.append(m)
	marks = keep


## For "until the end of your next turn": 1 if it's `owner`'s turn now (so the current turn's end doesn't count).
func own_turn_skip(owner: Combatant) -> int:
	return 1 if current() == owner else 0


func has_mark(kind: String, target_id: String) -> bool:
	for m in marks:
		if str(m["kind"]) == kind and str(m.get("target", "")) == target_id:
			return true
	return false


# --- Movement -------------------------------------------------------------------------------------

## Moves the current creature to `dest` along the cheapest legal path. Leaving a hostile creature's reach
## provokes an Opportunity Attack unless the mover took Disengage; a player-controlled reactor is asked first.
## A Prone mover stands up first if it has the movement for it (half its Speed).
func move(c: Combatant, dest: Vector2i) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if c.creature.hp <= 0:
		return CombatResult.fail("%s is down" % c.name())
	if c.speed() <= 0:
		return CombatResult.fail("Speed 0")
	if c.creature.has_condition(&"prone") and c.movement_left >= c.speed() / 2:
		stand_up(c)
	var reach := reachable_for(c)
	if not reach.has(dest):
		return CombatResult.fail("Can't reach that square with %d ft of movement" % c.movement_left)
	if bool((reach[dest] as Dictionary)["occupied"]):
		return CombatResult.fail("You can't end your move in an occupied space")
	var path := CombatGrid.path_to(reach, dest)
	var r := CombatResult.new()
	return _walk(c, path, 1, r, {})


func _walk(c: Combatant, path: Array[Vector2i], i: int, r: CombatResult, handled: Dictionary) -> CombatResult:
	while i < path.size():
		var to := path[i]
		if not c.disengaged and not c.creature.has_flag("flyby"):
			for p in _provokers(c, c.cell, to):
				var key := "%s@%d" % [p.id, i]
				if handled.has(key):
					continue
				handled[key] = true
				var decision := _reaction_decision(p, "opportunity_attack")
				var idx := i
				var resume := func() -> CombatResult:
					if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
						return r
					return _walk(c, path, idx, r, handled)
				if decision == "ask":
					var req := ReactionRequest.new("opportunity_attack", p.id, c.id)
					req.title = "Opportunity Attack?"
					req.text = "%s is leaving %s's reach. %s can spend a Reaction to make one melee attack now." % [c.name(), p.name(), p.name()]
					req.continuation = func(use: bool) -> CombatResult:
						if use:
							return then(_opportunity_attack(p, c), resume)
						return resume.call() as CombatResult
					pending = req
					r.pending = req
					return r
				elif decision == "auto":
					var sub := _opportunity_attack(p, c)
					if pending != null:
						return then(sub, resume)
					if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
						return r
		var occ := _occupancy_for(c)
		var step := grid.step_cost(c.cell, to, c.size_cells, _has_fn(occ["blocked"] as Dictionary), _has_fn(occ["slowed"] as Dictionary), move_mode(c))
		if c.creature.has_condition(&"prone"):
			step *= 2
		if step < 0 or step > c.movement_left:
			break
		var from := c.cell
		c.movement_left -= step
		c.moved = true
		c.cell = to
		c.facing = Vector2(to - from).normalized()
		events.append({"type": "move", "id": c.id, "from": from, "to": to})
		_after_step(c, from)
		if c.is_down() or state != State.ACTIVE:
			return r
		i += 1
		# Readied attacks trigger when the mover comes into reach.
		for p in _readied_triggers(c, from, to):
			var rkey := "ready:%s" % p.id
			if handled.has(rkey):
				continue
			handled[rkey] = true
			var rdecision := _reaction_decision(p, "readied_attack")
			var next_i := i
			var resume2 := func() -> CombatResult:
				if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
					return r
				return _walk(c, path, next_i, r, handled)
			if rdecision == "ask":
				var rreq := ReactionRequest.new("readied_attack", p.id, c.id)
				rreq.title = "Readied attack?"
				rreq.text = "%s comes within reach of %s, who readied an attack. Use the Reaction to attack now?" % [c.name(), p.name()]
				rreq.continuation = func(use: bool) -> CombatResult:
					if use:
						return then(_readied_attack(p, c), resume2)
					p.readied = {}
					return resume2.call() as CombatResult
				pending = rreq
				r.pending = rreq
				return r
			elif rdecision == "auto":
				var sub2 := _readied_attack(p, c)
				if pending != null:
					return then(sub2, resume2)
				if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
					return r
	if c.hidden:
		_check_still_hidden(c)
	return r


## Creatures with a readied attack whose reach (or range) `mover` has just entered.
func _readied_triggers(mover: Combatant, from: Vector2i, to: Vector2i) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for p in hostiles_of(mover):
		if p.readied.is_empty() or not spells.can_react(p) or not can_see(p, mover):
			continue
		var option := option_by_id(p, str(p.readied.get("option", "")))
		if option.is_empty():
			continue
		var prof := option["profile"] as WeaponProfile
		var reach := prof.reach if bool(option["melee"]) else prof.normal_range
		var before := grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if after <= reach and before > reach:
			out.append(p)
	return out


func _readied_attack(p: Combatant, target: Combatant) -> CombatResult:
	var option := option_by_id(p, str(p.readied.get("option", "")))
	p.readied = {}
	if option.is_empty() or attack_legal(p, target, option) != "":
		return CombatResult.new()
	p.reaction_available = false
	log.add("reaction", "%s's readied attack goes off against %s" % [p.name(), target.name()], p.id)
	return _resolve_attack(p, target, option, {"reaction": true})


## Ready (2024), attacks only: choose an attack to make with your Reaction when a hostile creature you can see
## comes within its reach (or normal range), before the start of your next turn. (Readied spells: deviations.md.)
func ready_attack(c: Combatant, option_id: String) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("Choose an attack to ready")
	spend_action(c)
	c.readied = {"option": option_id}
	log.add("info", "%s readies an attack (%s) for the first enemy to come within reach" % [c.name(), option["label"]], c.id)
	return CombatResult.new()


## A Death Saving Throw for a dying character on its turn (2024: 10+ succeeds, three successes stabilize, three
## failures kill, a 20 brings it back with 1 HP). The player rolls it from the HUD; if not, it's rolled at the end
## of the turn. AI-controlled dying creatures roll at the start of their turn.
func death_save(c: Combatant) -> CombatResult:
	if current() != c or c.death_save_rolled:
		return CombatResult.fail("Not now")
	if c.creature.dead or c.creature.hp > 0 or c.creature.stable or not c.creature.uses_death_saves:
		return CombatResult.fail("%s isn't dying" % c.name())
	c.death_save_rolled = true
	var t := c.creature.roll_death_save(dice)
	if t == null:
		return CombatResult.fail("No Death Saving Throw needed")
	var status := "dies" if c.creature.dead else ("is Stable" if c.creature.stable else ("regains 1 Hit Point" if c.creature.hp > 0 else "%d ✓ %d ✗" % [c.creature.death_successes, c.creature.death_failures]))
	log.add("roll", "%s makes a Death Saving Throw: %s" % [c.name(), status], c.id, [t.describe()])
	events.append({"type": "death_save", "id": c.id, "success": t.success})
	if c.creature.dead:
		events.append({"type": "death", "id": c.id})
		_check_over()
	elif c.creature.hp > 0:
		events.append({"type": "heal", "id": c.id, "amount": c.creature.hp})
	return CombatResult.new()


func needs_death_save(c: Combatant) -> bool:
	return c.is_alive() and c.creature.hp <= 0 and c.creature.uses_death_saves and not c.creature.stable and not c.death_save_rolled


## Stabilizing a dying creature within 5 ft (2024): the Help action with a DC 10 Wisdom (Medicine) check, or a
## Utilize action spending a use of a Healer's Kit (no check).
func stabilize(c: Combatant, target: Combatant, use_kit: bool) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if target == null or target.creature.hp > 0 or target.creature.dead or target.creature.stable:
		return CombatResult.fail("Choose a dying creature")
	if distance(c, target) > 5:
		return CombatResult.fail("Must be within 5 ft")
	if use_kit and not has_kit(c):
		return CombatResult.fail("No Healer's Kit")
	spend_action(c)
	if use_kit:
		log.add("heal", "%s uses a Healer's Kit: %s is Stable" % [c.name(), target.name()], c.id)
		target.creature.stabilize()
		return CombatResult.new()
	var t := c.creature.roll_check(dice, &"medicine", 10)
	if t.success:
		target.creature.stabilize()
		log.add("heal", "%s stabilizes %s" % [c.name(), target.name()], c.id, [t.describe()])
	else:
		log.add("info", "%s can't stop %s's bleeding" % [c.name(), target.name()], c.id, [t.describe()])
	return CombatResult.new()


## Drinking a potion or eating a Goodberry (2024: a Bonus Action), or giving it to a creature within 5 ft.
func use_item(c: Combatant, item_id: String, target: Combatant) -> CombatResult:
	var why := _bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if item_count(c, item_id) <= 0:
		return CombatResult.fail("None left")
	if target == null or distance(c, target) > 5:
		return CombatResult.fail("Must be within 5 ft")
	var item := Compendium.shared().item_data(item_id)
	c.bonus_available = false
	_spend_item(c, item_id)
	for fx: Variant in item.get("effects", []):
		var d := fx as Dictionary
		if str(d.get("effect", "")) != "heal":
			continue
		var p := d.get("params", {}) as Dictionary
		if target.creature.has_flag("cant_regain_hp"):
			log.add("info", "%s can't regain Hit Points right now" % target.name(), target.id)
			continue
		var amount := int(p.get("flat", 0))
		var text := ""
		if p.has("dice"):
			var rolled := _roll_damage_dice(str(p["dice"]), false, 0, str(item.get("name", "")))
			amount += int(rolled["total"])
			text = str(rolled["text"])
		var healed := target.creature.heal(amount, str(item.get("name", "")))
		log.add("heal", "%s uses %s: %s regains %d Hit Points" % [c.name(), item.get("name", item_id), target.name(), healed], c.id, [text])
		events.append({"type": "heal", "id": target.id, "amount": healed})
	return CombatResult.new()


func has_kit(c: Combatant) -> bool:
	if not c.creature is Character:
		return false
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == "healers_kit" and int(e["qty"]) > 0:
			return true
	return false


## Hostile creatures that can see the mover and have it in reach at `from` but not at `to`.
func _provokers(mover: Combatant, from: Vector2i, to: Vector2i) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for p in hostiles_of(mover):
		if not spells.can_react(p) or not can_see(p, mover):
			continue
		var reach := p.reach_ft()
		var before := grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if before <= reach and after > reach:
			out.append(p)
	return out


func _opportunity_attack(p: Combatant, target: Combatant) -> CombatResult:
	var option := best_melee_option(p, target)
	if option.is_empty():
		return CombatResult.new()
	p.reaction_available = false
	log.add("reaction", "%s makes an Opportunity Attack against %s" % [p.name(), target.name()], p.id)
	return _resolve_attack(p, target, option, {"reaction": true})


## Runs `next` after `result`, or after the player answers the prompt `result` paused on (chaining again if the
## answer pauses too). Lets a move, an AI turn or a spell carry on after a reaction prompt.
func then(result: CombatResult, next: Callable) -> CombatResult:
	if pending == null:
		return next.call() as CombatResult
	var req := pending
	var inner := req.continuation
	req.continuation = func(use: bool) -> CombatResult:
		var rr := inner.call(use) as CombatResult
		return then(rr, next)
	result.pending = req
	return result


## What a creature does with a Reaction opportunity: AI creatures always take Opportunity Attacks; players
## follow their per-reaction rule (plan §5.3), default "ask".
func _reaction_decision(reactor: Combatant, kind: String) -> String:
	if not reactor.is_player_controlled():
		return "auto" if ai.wants_reaction(reactor, kind) else "never"
	return str(reactor.reaction_rules.get(kind, default_player_reaction))


## Answers the pending reaction prompt and continues whatever was paused.
func answer_reaction(use: bool) -> CombatResult:
	if pending == null:
		return CombatResult.fail("No reaction is waiting")
	var req := pending
	pending = null
	var verbs := ["spends Heroic Inspiration", "keeps Heroic Inspiration"] if req.kind == "heroic_inspiration" else ["uses its Reaction", "holds its Reaction"]
	log.add("reaction", "%s %s" % [get_c(req.reactor_id).name(), verbs[0] if use else verbs[1]], req.reactor_id)
	var res := req.continuation.call(use) as CombatResult
	req.continuation = Callable()
	res.pending = pending
	return res


func _after_step(c: Combatant, from: Vector2i) -> void:
	spells.on_enter_cell(c, from)


func _check_still_hidden(c: Combatant) -> void:
	for e in hostiles_of(c):
		if not e.can_act():
			continue
		var cov := grid.cover_between(e.cell, e.size_cells, c.cell, c.size_cells)
		if int(cov["cover"]) < CombatGrid.Cover.THREE_QUARTERS:
			reveal(c, "%s spots %s" % [e.name(), c.name()])
			return


func reveal(c: Combatant, why: String) -> void:
	if not c.hidden:
		return
	c.hidden = false
	c.creature.remove_condition(&"invisible", "Hidden")
	log.add("info", "%s is no longer hidden (%s)" % [c.name(), why], c.id)


func stand_up(c: Combatant) -> CombatResult:
	if not c.creature.has_condition(&"prone"):
		return CombatResult.fail("Not Prone")
	var cost := c.speed() / 2
	if c.speed() <= 0 or c.movement_left < cost:
		return CombatResult.fail("Standing up costs %d ft" % cost)
	c.movement_left -= cost
	c.creature.remove_condition(&"prone")
	c.stood_up = true
	log.add("move", "%s stands up (%d ft)" % [c.name(), cost], c.id)
	events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


func drop_prone(c: Combatant) -> CombatResult:
	if c.speed() <= 0:
		return CombatResult.fail("Speed 0")
	c.creature.add_condition(&"prone", "Dropped prone")
	log.add("move", "%s drops Prone" % c.name(), c.id)
	return CombatResult.new()


## Moves a creature without using its movement (Push, Shove, Thunderwave, Thorn Whip): no Opportunity Attacks.
## It goes in a straight line away from (or, with `toward`, toward) the grid point `origin`, square by square, and
## stops at walls and other creatures. Areas it's moved into still affect it. Returns the squares moved.
func forced_move(target: Combatant, origin: Vector2, feet: int, toward: bool = false) -> int:
	var dir := center_of(target) - origin
	if toward:
		dir = -dir
	if dir.length() < 0.01:
		return 0
	dir = dir.normalized()
	var start := target.cell
	var moved := 0
	for k in range(1, feet / CombatGrid.FEET + 1):
		var nxt := start + Vector2i(roundi(dir.x * k), roundi(dir.y * k))
		if nxt == target.cell:
			continue
		var ok := true
		for cell in CombatGrid.footprint(nxt, target.size_cells):
			var o := occupant_at(cell)
			if not grid.in_bounds(cell) or grid.is_solid(cell) or (o != null and o != target):
				ok = false
		if not ok:
			break
		events.append({"type": "move", "id": target.id, "from": target.cell, "to": nxt, "forced": true})
		var was := target.cell
		target.cell = nxt
		moved += 1
		_after_step(target, was)
	return moved


## The middle of a creature's space, in grid units.
func center_of(c: Combatant) -> Vector2:
	return Vector2(c.cell.x + c.size_cells / 2.0, c.cell.y + c.size_cells / 2.0)


# --- Economy helpers ------------------------------------------------------------------------------

## "" if `c` may act now (it's its turn, nothing is waiting, combat is on).
func _turn_check(c: Combatant) -> String:
	if state != State.ACTIVE:
		return "Combat is over"
	if pending != null:
		return "Answer the reaction prompt first"
	if current() != c:
		return "It isn't %s's turn" % c.name()
	return ""


func _action_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act (%s)" % [c.name(), "down" if c.creature.hp <= 0 else "Incapacitated"]
	if not c.action_available:
		return "Action already used"
	if c.creature.has_flag("slowed") and not c.bonus_available and not c.surged:
		return "Slowed: an action or a Bonus Action, not both"
	return ""


func spend_action(c: Combatant) -> void:
	if c.extra_actions > 0:
		c.extra_actions -= 1
		c.attacks_left = 0
	else:
		c.action_available = false


func _bonus_check(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if not c.bonus_available:
		return "Bonus Action already used"
	if c.creature.has_flag("slowed") and not c.action_available:
		return "Slowed: an action or a Bonus Action, not both"
	return ""


# --- Actions from effects ---------------------------------------------------------------------------

## Breaking free of a spell that allows it (Web, Entangle): an action and the named ability check against the
## spell's save DC.
func escape_effect(c: Combatant, effect_id: int) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var fx: Effect = null
	for x: Effect in c.creature.effects:
		if x.id == effect_id:
			fx = x
	if fx == null or fx.escape.is_empty():
		return CombatResult.fail("Nothing to break free of")
	spend_action(c)
	var skill := StringName(str(fx.escape["skill"]))
	var t := c.creature.roll_check(dice, skill, int(fx.escape["dc"]))
	if t.success:
		c.creature.remove_effect(fx)
		log.add("info", "%s breaks free of %s" % [c.name(), fx.name], c.id, [t.describe()])
		events.append({"type": "condition", "id": c.id})
	else:
		log.add("info", "%s struggles against %s" % [c.name(), fx.name], c.id, [t.describe()])
	return CombatResult.new()


## The effect keeping `c` magically asleep or entranced (Sleep, Hypnotic Pattern), or null.
func sleeper(c: Combatant) -> Effect:
	for fx: Effect in c.creature.effects:
		if bool(fx.data.get("wakeable", false)):
			return fx
	return null


## Shaking a creature within 5 ft out of magical sleep or a trance: an action.
func wake(c: Combatant, t: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if t == null or distance(c, t) > 5:
		return CombatResult.fail("Choose a creature within 5 ft")
	var fx := sleeper(t)
	if fx == null:
		return CombatResult.fail("%s isn't magically asleep" % t.name())
	spend_action(c)
	t.creature.remove_effect(fx)
	log.add("info", "%s shakes %s awake" % [c.name(), t.name()], c.id)
	events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Haste's extra action (2024): one weapon attack (only one, whatever Extra Attack says), Dash, Disengage, Hide or
## Utilize.
func haste_action_use(c: Combatant, what: String, target: Combatant, option_id: String) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.haste_action or not c.creature.has_flag("hasted"):
		return CombatResult.fail("No Haste action left")
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	match what:
		"dash":
			c.haste_action = false
			c.movement_left += c.speed()
			log.add("info", "%s Dashes with Haste (+%d ft)" % [c.name(), c.speed()], c.id)
		"disengage":
			c.haste_action = false
			c.disengaged = true
			log.add("info", "%s Disengages with Haste" % c.name(), c.id)
		"hide":
			var spot := hide_blocker(c)
			if spot != "":
				return CombatResult.fail(spot)
			c.haste_action = false
			var t := c.creature.roll_check(dice, &"stealth", 15)
			if t.success:
				c.hidden = true
				c.stealth_total = t.total
				c.creature.add_condition(&"invisible", "Hidden")
			log.add("info", "%s %s (Haste, Stealth %d)" % [c.name(), "hides" if t.success else "fails to hide", t.total], c.id, [t.describe()])
		"attack":
			var option := option_by_id(c, option_id)
			if option.is_empty():
				return CombatResult.fail("No such attack")
			var check := attack_legal(c, target, option)
			if check != "":
				return CombatResult.fail(check)
			var sanct := spells.sanctuary_blocks(c, target)
			if sanct != "":
				return CombatResult.fail(sanct)
			c.haste_action = false
			log.add("info", "%s attacks with Haste's extra action" % c.name(), c.id)
			return _resolve_attack(c, target, option, {})
	return CombatResult.new()


# --- Attacks --------------------------------------------------------------------------------------

## Every attack `c` can make: {id, label, kind: weapon|thrown|unarmed|monster, profile: WeaponProfile,
## action_id, melee: bool, range: [normal, long], reach}.
func attack_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.creature is Character:
		for p in (c.creature as Character).attacks():
			out.append({"id": ("thrown:" if p.thrown else "weapon:") + p.item_id, "label": p.name,
				"kind": "thrown" if p.thrown else ("unarmed" if p.item_id == "unarmed_strike" else "weapon"),
				"profile": p, "melee": p.melee, "range": [p.normal_range, p.long_range], "reach": p.reach})
	elif c.creature is Monster:
		var m := c.creature as Monster
		for a: Variant in m.data.get("actions", []):
			var act := a as Dictionary
			if not act.has("attack"):
				continue
			var p := m.attack_profile(str(act["id"]))
			out.append({"id": "monster:" + str(act["id"]), "label": str(act["name"]), "kind": "monster",
				"profile": p, "action_id": str(act["id"]), "melee": p.melee, "range": [p.normal_range, p.long_range],
				"reach": p.reach})
	return out


func option_by_id(c: Combatant, option_id: String) -> Dictionary:
	for o in attack_options(c):
		if str(o["id"]) == option_id:
			return o
	return {}


## The melee attack a creature would use for an Opportunity Attack (best average damage).
func best_melee_option(c: Combatant, _target: Combatant) -> Dictionary:
	var best := {}
	var best_avg := -1.0
	for o in attack_options(c):
		if not bool(o["melee"]):
			continue
		var avg := (o["profile"] as WeaponProfile).average_damage()
		if avg > best_avg:
			best_avg = avg
			best = o
	return best


## How many attacks one Attack action gives (Extra Attack; the highest source wins, 2024 multiclass rule).
func attacks_per_action(c: Combatant) -> int:
	if c.creature.has_flag("slowed"):
		return 1
	var best := 1
	var ctx := c.creature.formula_context()
	for m in c.creature.modifiers_for(&"attacks_per_action"):
		best = maxi(best, c.creature.mod_value(m, ctx))
	return best


## Makes one attack as part of the Attack action (starting it if needed). Characters use weapon options; monsters
## use their stat-block attacks (monster_action handles Multiattack).
func attack(c: Combatant, target: Combatant, option_id: String, opts: Dictionary = {}) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var option := option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("No such attack")
	var check := attack_legal(c, target, option)
	if check != "":
		return CombatResult.fail(check)
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.fail("No attacks left this turn")
	var sanct := spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
		c.attacks_left = attacks_per_action(c) - 1
		if c.creature is Monster:
			c.attacks_left = 0
	else:
		return CombatResult.fail("No attacks left this turn")
	var p := option["profile"] as WeaponProfile
	if "light" in p.properties and c.light_attack_weapon == "":
		c.light_attack_weapon = p.item_id
	return _resolve_attack(c, target, option, opts)


## The Light property's extra attack (a Bonus Action, or part of the Attack action with Nick), with a different
## Light weapon, without the ability modifier to damage unless it's negative.
func offhand_attack(c: Combatant, target: Combatant, option_id: String) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := option_by_id(c, option_id)
	if option.is_empty():
		return CombatResult.fail("No such attack")
	var p := option["profile"] as WeaponProfile
	if c.light_attack_weapon == "" or not c.took_attack_action:
		return CombatResult.fail("First attack with a Light weapon in the Attack action")
	if not "light" in p.properties or p.item_id == c.light_attack_weapon:
		return CombatResult.fail("Needs a different Light weapon")
	var nick := false
	var first_mastery := ""
	for o in attack_options(c):
		var op := o["profile"] as WeaponProfile
		if op.item_id == c.light_attack_weapon:
			first_mastery = op.mastery
	if c.nick_used:
		return CombatResult.fail("Already made the Light property's extra attack this turn")
	if p.mastery == "nick" or first_mastery == "nick":
		nick = true
	if not nick and not c.bonus_available:
		return CombatResult.fail("Bonus Action already used")
	var check := attack_legal(c, target, option)
	if check != "":
		return CombatResult.fail(check)
	var sanct := spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	c.nick_used = true
	if not nick:
		c.bonus_available = false
	return _resolve_attack(c, target, option, {"offhand": true})


## "" if `c` can attack `target` with `option` from where it stands, otherwise why not.
func attack_legal(c: Combatant, target: Combatant, option: Dictionary) -> String:
	if target == null or not target.is_alive():
		return "No target"
	if target == c:
		return "Can't attack yourself"
	var dist := distance(c, target)
	var p := option["profile"] as WeaponProfile
	if bool(option["melee"]):
		if dist > p.reach:
			return "Out of reach (%d ft, reach %d ft)" % [dist, p.reach]
	else:
		var long := p.long_range if p.long_range > 0 else p.normal_range
		if long > 0 and dist > long:
			return "Out of range (%d ft, range %d/%d)" % [dist, p.normal_range, long]
	if int(cover(c, target)["cover"]) == CombatGrid.Cover.TOTAL:
		return "No clear line: Total Cover"
	if target.creature.has_flag("ethereal"):
		return "%s is on the Ethereal Plane" % target.name()
	var charm := charm_blocks(c, target)
	if charm != "":
		return charm
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and item_count(c, p.item_id) <= 0:
		return "No %s left" % p.name.replace(" (thrown)", "")
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and not bool(option["melee"]):
		var w := (c.creature as Character).compendium.item_data(p.item_id)
		var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
		if ammo != "" and not _has_ammo(c, ammo):
			return "No ammunition"
	return ""


## False if `option` is a ranged weapon whose ammunition has run out.
func has_ammo_for(c: Combatant, option: Dictionary) -> bool:
	if not c.creature is Character or bool(option["melee"]) or str(option["kind"]) != "weapon":
		return true
	var w := (c.creature as Character).compendium.item_data((option["profile"] as WeaponProfile).item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	return ammo == "" or _has_ammo(c, ammo)


## How many of an item a character carries.
func item_count(c: Combatant, item_id: String) -> int:
	var n := 0
	if c.creature is Character:
		for e in (c.creature as Character).inventory:
			if str(e["id"]) == item_id:
				n += int(e["qty"])
	return n


## A thrown weapon leaves the hand (it lands near the target; picking it up again is for after the fight).
func _spend_item(c: Combatant, item_id: String) -> void:
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == item_id and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			return


func _has_ammo(c: Combatant, ammo: String) -> bool:
	var ids := {"arrow": "arrow", "bolt": "crossbow_bolt", "bullet": "sling_bullet", "needle": "blowgun_needle"}
	var want := str(ids.get(ammo, ammo))
	for e in (c.creature as Character).inventory:
		if str(e["id"]) == want and int(e["qty"]) > 0:
			return true
	return false


## Every Advantage and Disadvantage source for this attack, plus cover:
## {advantage: [...], disadvantage: [...], cover: int, cover_bonus: int, cover_by: String}
func attack_situation(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	var adv: Array[String] = []
	var dis: Array[String] = []
	var p := option["profile"] as WeaponProfile
	var dist := distance(c, target)
	var melee := bool(option["melee"])
	for m in target.creature.modifiers_for(&"attacked_with"):
		if m.source_name == "Dodging" and (not can_see(target, c) or target.speed() <= 0):
			continue
		if bool(m.data.get("if_seen", false)) and not can_see(c, target):
			continue
		var skip := false
		for sense: Variant in m.data.get("unless_sense", []):
			if c.creature.sense_range(str(sense)) >= dist:
				skip = true
		if skip:
			continue
		if m.text("value") == "advantage":
			adv.append("%s (target)" % m.source_name)
		elif m.text("value") == "disadvantage":
			dis.append("%s (target)" % m.source_name)
	if target.creature.has_condition(&"prone"):
		if dist <= 5:
			adv.append("target Prone within 5 ft")
		else:
			dis.append("target Prone beyond 5 ft")
	if not melee:
		if p.normal_range > 0 and dist > p.normal_range:
			dis.append("long range")
		for h in hostiles_of(c):
			if h.can_act() and distance(c, h) <= 5 and can_see(h, c):
				dis.append("ranged attack with %s within 5 ft" % h.name())
				break
	if "heavy" in p.properties:
		var need := &"str" if melee else &"dex"
		if c.creature.ability_score(need) < 13:
			dis.append("Heavy weapon with %s under 13" % Creature.ABILITY_NAMES[need])
	if c.creature.has_flag("pack_tactics"):
		for a in allies_of(c):
			if a.can_act() and distance(a, target) <= 5:
				adv.append("Pack Tactics")
				break
	for m in target.creature.modifiers_for(&"attacked_with_by_type"):
		if str(c.creature.creature_type) in (m.data.get("types", []) as Array):
			dis.append("%s (target)" % m.source_name)
	if c.creature.has_flag("cursed_attacks:%s" % target.id):
		dis.append("Bestow Curse")
	if grapples.has(c.id) and str(grapples[c.id]) != target.id:
		dis.append("Grappled (attacking someone other than the grappler)")
	if c.hidden or not can_see(target, c):
		adv.append("target can't see you")
	if not can_see(c, target):
		dis.append("you can't see the target")
	if in_sunlight(c) and c.creature.has_flag("sunlight_sensitivity"):
		dis.append("Sunlight Sensitivity")
	for m in marks:
		if not _mark_applies(m, c, target):
			continue
		if str(m["kind"]) in ["advantage_against", "advantage_next_attack"]:
			adv.append(str(m["source"]))
		elif str(m["kind"]) == "disadvantage_next_attack":
			dis.append(str(m["source"]))
	var cov := cover(c, target)
	var degree := int(cov["cover"])
	return {"advantage": adv, "disadvantage": dis, "cover": degree, "cover_bonus": CombatGrid.COVER_BONUS[degree],
		"cover_by": str(cov["by"])}


## Dice the target's effects add to attack rolls against it (Blade Ward: −1d4).
func attacked_dice(target: Combatant) -> Array:
	var out: Array = []
	for m in target.creature.modifiers_for(&"attacked_penalty_die"):
		out.append({"dice": m.text("dice", "1d4"), "sign": -1, "source": m.source_name})
	return out


## Whether a mark changes `c`'s attack on `target`: Vex (only its attacker), Help (an ally of the helper, not the
## helper), Guiding Bolt (anyone), Steady Aim and Sap (the marked attacker's next attack).
func _mark_applies(m: Dictionary, c: Combatant, target: Combatant) -> bool:
	match str(m["kind"]):
		"advantage_against":
			if str(m["target"]) != target.id:
				return false
			if m.has("attacker"):
				return str(m["attacker"]) == c.id
			if m.has("helper"):
				var helper := get_c(str(m["helper"]))
				return helper != null and helper != c and c.allied_with(helper)
			return true
		"advantage_next_attack", "disadvantage_next_attack":
			return str(m["attacker"]) == c.id
	return false


func _consume_marks(c: Combatant, target: Combatant) -> void:
	var keep: Array[Dictionary] = []
	for m in marks:
		if bool(m.get("consume", false)) and _mark_applies(m, c, target):
			continue
		keep.append(m)
	marks = keep


## Chance to hit with the d20 needed, for tooltips and the AI: {chance, needs, advantage, disadvantage}.
func hit_chance(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	var p := option["profile"] as WeaponProfile
	var sit := attack_situation(c, target, option)
	var ac := target.creature.ac_value() + int(sit["cover_bonus"])
	var bonus := p.attack.total()
	var needs := clampi(ac - bonus, 2, 20)
	var crit := mini(p.crit_range, 20)
	needs = mini(needs, crit)
	var single := (21 - needs) / 20.0
	var adv := (sit["advantage"] as Array).size() > 0
	var dis := (sit["disadvantage"] as Array).size() > 0
	var chance := single
	if adv and not dis:
		chance = 1.0 - pow(1.0 - single, 2)
	elif dis and not adv:
		chance = single * single
	return {"chance": chance, "needs": needs, "advantage": adv and not dis, "disadvantage": dis and not adv,
		"situation": sit, "ac": ac}


## The attack itself: roll, Shield, damage (Critical Hits, Sneak Attack, Great Weapon Fighting, Savage Attacker),
## Uncanny Dodge, defenses, Undead Fortitude, mastery properties and on-hit effects. Pauses for player reactions.
func _resolve_attack(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary) -> CombatResult:
	var r := CombatResult.new()
	var p := option["profile"] as WeaponProfile
	var sit := attack_situation(c, target, option)
	_consume_marks(c, target)
	spells.end_sanctuary(c, "attacked")
	spells.trigger_ends(c, "attack_roll")
	if c.hidden:
		reveal(c, "attacked")
	var ac := target.creature.ac_value() + int(sit["cover_bonus"])
	var keys: Array[String] = ["attack", "attack:melee" if bool(option["melee"]) else "attack:ranged"]
	var label := "%s → %s (%s)" % [c.name(), target.name(), p.name]
	var t := c.creature.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], label, p.crit_range, attacked_dice(target))
	target.creature.consume_attacked()
	if not option.get("melee", true) and c.creature is Character:
		if str(option.get("kind", "")) == "thrown":
			_spend_item(c, p.item_id)
		else:
			_spend_ammo(c, p)
	# Heroic Inspiration (2024): reroll a die right after rolling it. Offered on a miss, as a prompt like a reaction.
	if not t.success and c.creature is Character and (c.creature as Character).heroic_inspiration and c.is_player_controlled():
		var first := t
		var decision := _reaction_decision(c, "heroic_inspiration")
		var reroll := func() -> D20Test:
			(c.creature as Character).heroic_inspiration = false
			var t2 := c.creature.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, sit["advantage"] as Array[String],
				sit["disadvantage"] as Array[String], label + " (Heroic Inspiration reroll)", p.crit_range)
			log.add("roll", "%s spends Heroic Inspiration to reroll: %d" % [c.name(), t2.total], c.id, [first.describe(), t2.describe()])
			return t2
		if decision == "ask":
			var req := ReactionRequest.new("heroic_inspiration", c.id, target.id)
			req.title = "Heroic Inspiration?"
			req.text = "%s misses %s: %d vs AC %d. Spend Heroic Inspiration to reroll the d20 and use the new roll?" % [c.name(), target.name(), t.total, ac]
			req.cost = "Heroic Inspiration (regained on a Long Rest)"
			req.continuation = func(use: bool) -> CombatResult:
				return _attack_outcome(c, target, option, opts, (reroll.call() as D20Test) if use else first, sit, ac, r)
			pending = req
			r.pending = req
			return r
		elif decision == "auto":
			t = reroll.call() as D20Test
	return _attack_outcome(c, target, option, opts, t, sit, ac, r)


func _attack_outcome(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary, t: D20Test,
		sit: Dictionary, ac: int, r: CombatResult) -> CombatResult:
	var p := option["profile"] as WeaponProfile
	var details: Array[String] = [t.describe(), p.attack.describe()]
	if int(sit["cover"]) > 0:
		details.append("%s: target AC +%d (%s)" % [CombatGrid.COVER_NAMES[int(sit["cover"])], int(sit["cover_bonus"]), sit["cover_by"]])
	for s: String in t.advantage_sources:
		details.append("Advantage: " + s)
	for s: String in t.disadvantage_sources:
		details.append("Disadvantage: " + s)
	var critical := t.critical
	if t.success and not critical and distance(c, target) <= 5 and target.creature.has_flag("auto_crit_within_5ft"):
		critical = true
		details.append("Automatic Critical Hit: the target can't defend itself within 5 ft")
	var success := t.success
	if success and mirror_image_takes(target, c, t.total):
		success = false
		critical = false
	events.append({"type": "attack", "attacker": c.id, "target": target.id, "hit": success, "critical": critical})
	if not success:
		var e := log.add("miss", "%s misses %s (%d vs AC %d)" % [c.name(), target.name(), t.total, ac], c.id, details)
		r.lines.append(e)
		_on_miss(c, target, option, r)
		return r
	# Shield: a hit that +5 AC would turn into a miss.
	var shield_ok := not critical and t.total < ac + 5 and spells.can_cast_reaction(target, "shield")
	if shield_ok:
		var decision := _reaction_decision(target, "shield")
		if decision == "ask":
			var req := ReactionRequest.new("shield", target.id, c.id)
			req.title = "Reaction: Shield?"
			req.text = "%s hits %s: %d vs AC %d. Shield gives +5 AC until the start of %s's next turn (AC %d), so this attack misses." % [c.name(), target.name(), t.total, ac, target.name(), ac + 5]
			req.cost = "Reaction and a level 1 spell slot"
			req.continuation = func(use: bool) -> CombatResult:
				if use:
					spells.cast_shield(target)
					var e2 := log.add("miss", "%s's Shield turns the attack aside (%d vs AC %d)" % [target.name(), t.total, ac + 5], target.id, details)
					r.lines.append(e2)
					return r
				return _after_hit(c, target, option, opts, t, critical, details, r)
			pending = req
			r.pending = req
			return r
		elif decision == "auto":
			spells.cast_shield(target)
			r.lines.append(log.add("miss", "%s's Shield turns the attack aside (%d vs AC %d)" % [target.name(), t.total, ac + 5], target.id, details))
			return r
	return _after_hit(c, target, option, opts, t, critical, details, r)


func _after_hit(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary, t: D20Test, critical: bool,
		details: Array[String], r: CombatResult) -> CombatResult:
	var p := option["profile"] as WeaponProfile
	r.hit = true
	r.critical = critical
	var parts := {}
	var dmg_text: Array[String] = []
	var dice_list: Array[Dictionary] = [{"dice": p.damage_dice, "type": str(p.damage_type), "label": p.name, "weapon": true}]
	if c.creature is Monster:
		dice_list.append_array((c.creature as Monster).extra_damage_dice(str(option.get("action_id", ""))))
	var sneak := features.sneak_attack_dice(c, target, option, t)
	if sneak != "":
		dice_list.append({"dice": sneak, "type": str(p.damage_type), "label": "Sneak Attack"})
	for extra: Variant in opts.get("extra_dice", []):
		dice_list.append(extra as Dictionary)
	# Extra damage on weapon and Unarmed Strike hits from spells (Crusader's Mantle, Enlarge) and features.
	for m in c.creature.modifiers_for(&"damage_penalty_die"):
		dice_list.append({"dice": m.text("dice", "1d8"), "type": str(p.damage_type), "label": m.source_name, "penalty": true})
	for m in c.creature.modifiers_for(&"extra_damage"):
		var when := m.text("on", "weapon")
		if when == "weapon" and not (p.item_id != "" or c.creature is Monster):
			continue
		if m.data.has("vs") and str(m.data["vs"]) != target.id:
			continue
		dice_list.append({"dice": m.text("dice", "1d4"), "type": m.text("type", str(p.damage_type)), "label": m.source_name,
			"penalty": bool(m.data.get("penalty", false))})
	var turn_key := "%d:%d" % [round_no, turn_index]
	var savage := c.creature.has_flag("savage_attacker") and str(_savage_turn.get(c.id, "")) != turn_key and c.creature is Character
	for entry in dice_list:
		var rolled := _roll_damage_dice(str(entry["dice"]), critical, p.die_minimum if bool(entry.get("weapon", false)) else 0,
			"%s damage" % entry["label"])
		if savage and bool(entry.get("weapon", false)) and p.item_id != "unarmed_strike":
			_savage_turn[c.id] = turn_key
			var again := _roll_damage_dice(str(entry["dice"]), critical, p.die_minimum, "Savage Attacker reroll")
			if int(again["total"]) > int(rolled["total"]):
				rolled = again
				dmg_text.append("Savage Attacker: rerolled and kept %d" % int(again["total"]))
		var ty := str(entry["type"])
		if bool(entry.get("penalty", false)):
			parts[str(p.damage_type)] = int(parts.get(str(p.damage_type), 0)) - int(rolled["total"])
			dmg_text.append("%s −%s: %s" % [entry["label"], entry["dice"], rolled["text"]])
			continue
		parts[ty] = int(parts.get(ty, 0)) + int(rolled["total"])
		dmg_text.append("%s %s%s: %s" % [entry["label"], entry["dice"], " ×2 (Critical Hit)" if critical else "", rolled["text"]])
	var bonus := p.damage_bonus.total()
	if bool(opts.get("offhand", false)) and bonus > 0:
		bonus = 0
		dmg_text.append("Off-hand attack: no ability modifier to damage")
	var primary := str(p.damage_type)
	parts[primary] = maxi(0, int(parts.get(primary, 0)) + bonus)
	if bonus != 0:
		dmg_text.append(p.damage_bonus.describe())
	var total := 0
	for k: String in parts:
		total += int(parts[k])
	# Uncanny Dodge (Rogue 5): halve an attack's damage.
	if total > 0 and spells.can_react(target) and target.creature.has_flag("uncanny_dodge") and can_see(target, c):
		var decision := _reaction_decision(target, "uncanny_dodge")
		if decision == "ask":
			var req := ReactionRequest.new("uncanny_dodge", target.id, c.id)
			req.title = "Reaction: Uncanny Dodge?"
			req.text = "%s hits %s for %d damage. Uncanny Dodge halves it (%d)." % [c.name(), target.name(), total, total / 2]
			req.continuation = func(use: bool) -> CombatResult:
				if use:
					target.reaction_available = false
					for k: String in parts:
						parts[k] = int(parts[k]) / 2
					dmg_text.append("Uncanny Dodge: damage halved")
				return _apply_hit(c, target, option, critical, parts, details, dmg_text, r)
			pending = req
			r.pending = req
			return r
		elif decision == "auto":
			target.reaction_available = false
			for k: String in parts:
				parts[k] = int(parts[k]) / 2
			dmg_text.append("Uncanny Dodge: damage halved")
	return _apply_hit(c, target, option, critical, parts, details, dmg_text, r)


func _apply_hit(c: Combatant, target: Combatant, option: Dictionary, critical: bool, parts: Dictionary,
		details: Array[String], dmg_text: Array[String], r: CombatResult) -> CombatResult:
	var arr: Array = []
	for k: String in parts:
		arr.append({"amount": int(parts[k]), "type": k})
	var all_details := details.duplicate()
	all_details.append_array(dmg_text)
	var dr := deal_damage(c, target, arr, critical, (option["profile"] as WeaponProfile).name, all_details, true)
	r.damage = dr.final
	if target.is_down():
		r.killed.append(target.id)
	_on_hit_effects(c, target, option, dr, r)
	return run_reaction_queue(r)


## Rolls damage dice (doubled on a Critical Hit; dice below `minimum` count as `minimum`).
## {total, text}
func _roll_damage_dice(expr: String, critical: bool, minimum: int, reason: String) -> Dictionary:
	var parsed := DiceRoller.parse_expr(expr)
	var count := int(parsed["count"]) * (2 if critical else 1)
	var total := int(parsed["modifier"])
	var shown: Array[String] = []
	if count > 0:
		for roll in dice.roll(int(parsed["sides"]), count, reason):
			var v := roll
			if minimum > 0 and v < minimum:
				v = minimum
				shown.append("%d→%d" % [roll, v])
			else:
				shown.append(str(v))
			total += v
	var text := "[%s]" % ", ".join(shown) if not shown.is_empty() else ""
	if int(parsed["modifier"]) != 0:
		text += " %+d" % int(parsed["modifier"])
	return {"total": total, "text": "%s = %d" % [text.strip_edges(), total]}


## Deals damage through the target's defenses with the Concentration save, Undead Fortitude, effects that end on
## damage, death and the log. Returns the DamageResult.
func deal_damage(source: Combatant, target: Combatant, parts: Array, critical: bool, label: String,
		details: Array = [], log_it: bool = true) -> DamageResult:
	var was_up := not target.is_down()
	if source != null and target.creature.has_flag("cursed_necrotic:%s" % source.id):
		var extra := _roll_damage_dice("1d8", false, 0, "Bestow Curse")
		parts = parts.duplicate()
		parts.append({"amount": int(extra["total"]), "type": "necrotic"})
		details = details.duplicate()
		details.append("Bestow Curse 1d8: %s" % extra["text"])
	parts = _reduce_by_dice(target, parts, details)
	var dr := target.creature.take_damage_parts(parts, critical, dice, label)
	if source != null and dr.final > 0:
		spells.trigger_ends(source, "deal_damage")
	if dr.final > 0:
		for e: Effect in target.creature.effects.duplicate():
			if e.ends_on_damage:
				target.creature.remove_effect(e)
				log.add("info", "%s ends on %s (took damage)" % [e.name, target.name()], target.id)
	# Undead Fortitude (2025 zombie): a Con save (DC 5 + damage) to drop to 1 HP instead, unless Radiant or a crit.
	if target.creature.dead and target.creature.has_flag("undead_fortitude") and not critical:
		var radiant := false
		for p: Variant in parts:
			if str((p as Dictionary)["type"]) == "radiant" and int((p as Dictionary)["amount"]) > 0:
				radiant = true
		if not radiant:
			var dc := 5 + dr.final
			var save := target.creature.roll_save(dice, &"con", dc, [], [], "Undead Fortitude (%s)" % target.name())
			if save.success:
				target.creature.dead = false
				target.creature.hp = 1
				log.add("info", "%s keeps standing: Undead Fortitude" % target.name(), target.id, [save.describe()])
	var text := dr.describe(target.name())
	if log_it:
		var headline := text
		if source != null and source != target:
			headline = "%s hits %s for %d %s damage" % [source.name(), target.name(), dr.final, " + ".join(_types_of(parts))]
		var all_details: Array = details.duplicate()
		all_details.append(text)
		log.add("hit", headline, source.id if source != null else "", all_details)
	events.append({"type": "damage", "id": target.id, "amount": dr.final, "critical": critical})
	if dr.concentration_broken:
		log.add("info", "%s loses Concentration" % target.name(), target.id, [dr.concentration_save.describe()])
	if target.creature.dead and was_up:
		target.set_meta("died_round", round_no)
		log.add("death", "%s dies" % target.name(), target.id)
		events.append({"type": "death", "id": target.id})
		if target.has_meta("vanishes"):
			events.append({"type": "vanish", "id": target.id})
	elif dr.dropped_to_zero and not target.creature.dead:
		log.add("death", "%s falls unconscious" % target.name(), target.id)
		events.append({"type": "down", "id": target.id})
	if grapples.values().has(target.id) and target.creature.has_flag("no_actions"):
		_release_grapples_by(target)
	if target.is_down() or target.creature.has_flag("no_actions"):
		features.end_turning_from(target)
	if source != null and source != target and dr.final > 0:
		spells.end_sanctuary(source, "dealt damage")
	spells.on_damaged(source, target, dr.final, parts)
	if dr.final > 0 and source != null and source != target and target.is_alive():
		_queue_damage_reactions(source, target)
	spells.zones.prune()
	_check_over()
	return dr


## The Resistance cantrip: damage of the chosen type is reduced by 1d4, once per turn.
func _reduce_by_dice(target: Combatant, parts: Array, details: Array) -> Array:
	var mods := target.creature.modifiers_for(&"damage_reduction_die")
	if mods.is_empty():
		return parts
	var turn_key := "%d:%d" % [round_no, turn_index]
	var out: Array = []
	for p: Variant in parts:
		out.append((p as Dictionary).duplicate())
	for m in mods:
		if bool(m.data.get("once_per_turn", true)) and str(target.get_meta("dr_die_turn", "")) == turn_key:
			break
		for p: Variant in out:
			var d := p as Dictionary
			if str(d["type"]) == m.text("type") and int(d["amount"]) > 0:
				var cut := int(dice.roll_expr(m.text("dice", "1d4"), m.source_name)["total"])
				d["amount"] = maxi(0, int(d["amount"]) - cut)
				target.set_meta("dr_die_turn", turn_key)
				details.append("%s: −%d" % [m.source_name, cut])
				break
	return out


## Reactions to being damaged (Hellish Rebuke) wait until the attack or spell that caused them has finished.
func _queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	if not target.creature is Character or not spells.can_cast_reaction(target, "hellish_rebuke"):
		return
	if distance(target, source) > 60 or not can_see(target, source) or target.creature.hp <= 0:
		return
	for q in reaction_queue:
		if str(q["reactor"]) == target.id:
			return
	reaction_queue.append({"kind": "hellish_rebuke", "reactor": target.id, "trigger": source.id})


## Offers the queued reactions one by one (asking the player, or the AI deciding), then returns `r`.
func run_reaction_queue(r: CombatResult) -> CombatResult:
	while not reaction_queue.is_empty():
		var q := reaction_queue.pop_front() as Dictionary
		var reactor := get_c(str(q["reactor"]))
		var trigger := get_c(str(q["trigger"]))
		if reactor == null or trigger == null or not trigger.is_alive() or not spells.can_cast_reaction(reactor, str(q["kind"])):
			continue
		var decision := _reaction_decision(reactor, str(q["kind"]))
		if decision == "never":
			continue
		var fire := func() -> CombatResult: return spells.cast_reaction_spell(reactor, str(q["kind"]), trigger)
		if decision == "auto":
			var sub := fire.call() as CombatResult
			if pending != null:
				return then(sub, func() -> CombatResult: return run_reaction_queue(r))
			continue
		var req := ReactionRequest.new(str(q["kind"]), reactor.id, trigger.id)
		var s := Compendium.shared().spell_data(str(q["kind"]))
		req.title = "Reaction: %s?" % s.get("name", q["kind"])
		req.text = "%s hurt %s. %s can answer with %s: %s" % [trigger.name(), reactor.name(), reactor.name(), s.get("name", ""), s.get("summary", "")]
		req.cost = "Reaction and a level %d spell slot" % int(s.get("level", 1))
		req.continuation = func(use: bool) -> CombatResult:
			if use:
				return then(fire.call() as CombatResult, func() -> CombatResult: return run_reaction_queue(r))
			return run_reaction_queue(r)
		pending = req
		r.pending = req
		return r
	return r


static func _types_of(parts: Array) -> Array[String]:
	var out: Array[String] = []
	for p: Variant in parts:
		var d := p as Dictionary
		if int(d["amount"]) > 0:
			out.append(str(d["type"]).capitalize())
	return out


func _on_miss(c: Combatant, target: Combatant, option: Dictionary, r: CombatResult) -> void:
	var p := option["profile"] as WeaponProfile
	if p.mastery == "graze":
		var mod := c.creature.ability_mod(p.ability)
		if mod > 0:
			r.lines.append(log.add("hit", "Graze: %s still deals %d %s damage" % [c.name(), mod, str(p.damage_type).capitalize()], c.id))
			deal_damage(c, target, [{"amount": mod, "type": str(p.damage_type)}], false, "Graze", [], false)


## Mastery properties and stat-block riders after a hit.
func _on_hit_effects(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, r: CombatResult) -> void:
	var p := option["profile"] as WeaponProfile
	if target.is_alive() and not target.is_down():
		match p.mastery:
			"vex":
				if dr.final > 0:
					add_mark({"kind": "advantage_against", "target": target.id, "attacker": c.id, "source": "Vex",
						"expires_owner": c.id, "expires_phase": "end", "skip": own_turn_skip(c), "consume": true})
			"sap":
				add_mark({"kind": "disadvantage_next_attack", "attacker": target.id, "source": "Sapped by %s" % c.name(),
					"expires_owner": c.id, "expires_phase": "start", "consume": true})
			"slow":
				if dr.final > 0 and not target.creature.effects.any(func(e: Effect) -> bool: return e.name == "Slowed (mastery)"):
					var e := Effect.new("Slowed (mastery)", &"effect", "slow").with_modifier("speed", {"value": -10})
					e.ends = Effect.Ends.START_OF_TURN
					e.turn_owner_id = c.id
					target.creature.add_effect(e)
			"topple":
				var dc := 8 + c.creature.ability_mod(p.ability) + c.creature.proficiency_bonus()
				var s := target.creature.roll_save(dice, &"con", dc, [], [], "Topple (%s)" % target.name())
				if not s.success:
					target.creature.add_condition(&"prone", "Topple")
					log.add("condition", "Topple: %s falls Prone" % target.name(), target.id, [s.describe()])
				else:
					log.add("info", "Topple: %s keeps its feet" % target.name(), target.id, [s.describe()])
			"push":
				if Creature.SIZES.find(target.creature.size) <= Creature.SIZES.find(&"large"):
					var moved := forced_move(target, center_of(c), 10)
					if moved > 0:
						log.add("info", "Push: %s is shoved %d ft" % [target.name(), moved * 5], target.id)
	# Stat-block riders (a wolf's bite knocks Prone; size limits are in the action text).
	if c.creature is Monster and target.is_alive():
		var act := (c.creature as Monster).action(str(option.get("action_id", "")))
		for cond: Variant in act.get("conditions", []):
			if act.has("save"):
				var sv := act["save"] as Dictionary
				var s2 := target.creature.roll_save(dice, StringName(str(sv["ability"])), int(sv["dc"]), [], [], "%s (%s)" % [act.get("name", ""), target.name()])
				if s2.success:
					continue
			if str(cond) == "prone" and Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size):
				continue
			if target.creature.add_condition(StringName(str(cond)), str(act.get("name", ""))):
				log.add("condition", "%s has the %s condition" % [target.name(), str(cond).capitalize()], target.id)
				events.append({"type": "condition", "id": target.id})


func _spend_ammo(c: Combatant, p: WeaponProfile) -> void:
	var ch := c.creature as Character
	var w := ch.compendium.item_data(p.item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	if ammo == "":
		return
	var ids := {"arrow": "arrow", "bolt": "crossbow_bolt", "bullet": "sling_bullet", "needle": "blowgun_needle"}
	for e in ch.inventory:
		if str(e["id"]) == str(ids.get(ammo, ammo)) and int(e["qty"]) > 0:
			e["qty"] = int(e["qty"]) - 1
			return


## A monster's stat-block action. Multiattack spends the action and queues its attacks; the AI then calls
## monster_attack for each.
func monster_attack(c: Combatant, target: Combatant, action_id: String) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	var option := option_by_id(c, "monster:" + action_id)
	if option.is_empty():
		return CombatResult.fail("No such action")
	var check := attack_legal(c, target, option)
	if check != "":
		return CombatResult.fail(check)
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.fail("No attacks left")
	var sanct := spells.sanctuary_blocks(c, target)
	if sanct != "":
		return CombatResult.fail(sanct)
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
	return _resolve_attack(c, target, option, {})


## Starts a Multiattack: spends the action and allows its listed attacks.
func begin_multiattack(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Monster or not c.action_available:
		return out
	var m := c.creature as Monster
	var multi := m.action("multiattack")
	if multi.is_empty():
		return out
	spend_action(c)
	c.took_attack_action = true
	var count := 0
	for entry: Variant in multi.get("multiattack", []):
		var e := entry as Dictionary
		count += int(e["count"])
		out.append(e)
	c.attacks_left = count
	return out


# --- Standard actions -----------------------------------------------------------------------------

func dash(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var why := _bonus_check(c) if use_bonus else _action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	if use_bonus:
		c.bonus_available = false
	else:
		spend_action(c)
	c.movement_left += c.speed()
	log.add("info", "%s takes the Dash action (+%d ft)" % [c.name(), c.speed()], c.id)
	return CombatResult.new()


func disengage(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var why := _bonus_check(c) if use_bonus else _action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	if use_bonus:
		c.bonus_available = false
	else:
		spend_action(c)
	c.disengaged = true
	log.add("info", "%s takes the Disengage action: no Opportunity Attacks this turn" % c.name(), c.id)
	return CombatResult.new()


## Dodge (2024): until the start of your next turn, attacks against you have Disadvantage if you can see the
## attacker and you have Advantage on Dexterity saves; lost if Incapacitated or Speed 0.
func dodge(c: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	spend_action(c)
	var e := Effect.new("Dodging", &"effect", "dodge").with_modifier("attacked_with", {"value": "disadvantage"}).with_modifier("advantage", {"on": "save:dex"})
	e.ends = Effect.Ends.START_OF_TURN
	e.turn_owner_id = c.id
	e.ends_when_incapacitated = true
	c.creature.add_effect(e)
	log.add("info", "%s takes the Dodge action" % c.name(), c.id)
	return CombatResult.new()


## Help (2024): distract an enemy within 5 ft; the next attack roll by one of your allies against it has
## Advantage, until the start of your next turn.
func help_attack(c: Combatant, enemy: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if enemy == null or not c.hostile_to(enemy) or distance(c, enemy) > 5:
		return CombatResult.fail("Choose an enemy within 5 ft")
	spend_action(c)
	add_mark({"kind": "advantage_against", "target": enemy.id, "helper": c.id, "source": "Help (%s)" % c.name(),
		"expires_owner": c.id, "expires_phase": "start", "consume": true})
	log.add("info", "%s distracts %s: the next ally attack against it has Advantage" % [c.name(), enemy.name()], c.id)
	return CombatResult.new()


## Hide (2024): DC 15 Dexterity (Stealth) while Heavily Obscured or behind Three-Quarters/Total Cover and out of
## every enemy's line of sight; success gives the Invisible condition while hidden.
func hide(c: Combatant, use_bonus: bool = false) -> CombatResult:
	var why := _bonus_check(c) if use_bonus else _action_check(c)
	if why == "" and use_bonus and not CombatFeatures.has_feature(c, "cunning_action"):
		why = "Needs Cunning Action"
	if why != "":
		return CombatResult.fail(why)
	var spotter := hide_blocker(c)
	if spotter != "":
		return CombatResult.fail(spotter)
	if use_bonus:
		c.bonus_available = false
	else:
		spend_action(c)
	var t := c.creature.roll_check(dice, &"stealth", 15)
	if t.success:
		c.hidden = true
		c.stealth_total = t.total
		c.creature.add_condition(&"invisible", "Hidden")
		log.add("info", "%s hides (Stealth %d)" % [c.name(), t.total], c.id, [t.describe()])
	else:
		log.add("info", "%s fails to hide (Stealth %d vs DC 15)" % [c.name(), t.total], c.id, [t.describe()])
	return CombatResult.new()


## Why `c` can't hide here ("" if it can): every enemy that can act must have no clear view of it (Three-Quarters
## or Total Cover). Naturally Stealthy (halfling): a creature at least one size larger is enough cover.
func hide_blocker(c: Combatant) -> String:
	var larger := {}
	if c.creature.has_flag("naturally_stealthy"):
		for o in living():
			if o != c and not o.is_down() and Creature.SIZES.find(o.creature.size) > Creature.SIZES.find(c.creature.size):
				for cell in o.footprint():
					larger[cell] = o.name()
	for e in hostiles_of(c):
		if not e.can_act():
			continue
		var cov := grid.cover_between(e.cell, e.size_cells, c.cell, c.size_cells)
		if int(cov["cover"]) >= CombatGrid.Cover.THREE_QUARTERS:
			continue
		if not larger.is_empty():
			var by_larger := grid.cover_between(e.cell, e.size_cells, c.cell, c.size_cells, larger)
			if int(by_larger["cover"]) >= CombatGrid.Cover.HALF and str(by_larger["by"]) not in ["", "walls"]:
				continue
		return "%s can see you: you need Three-Quarters or Total Cover from every enemy" % e.name()
	return ""


## Search (2024): a Wisdom (Perception) check to find hidden creatures (DC = their Stealth total).
func search(c: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	spend_action(c)
	var t := c.creature.roll_check(dice, &"perception", 0)
	var found: Array[String] = []
	for h in hostiles_of(c):
		if h.hidden and t.total >= h.stealth_total:
			reveal(h, "%s finds them" % c.name())
			found.append(h.name())
	log.add("info", "%s searches (Perception %d)%s" % [c.name(), t.total, ": finds " + ", ".join(found) if not found.is_empty() else ""], c.id, [t.describe()])
	return CombatResult.new()


## Study (2024): an Intelligence check to recall what a creature is (Arcana, History, Nature or Religion by its
## type). DC 10 + its CR (the DM's call made concrete; deviations.md). Success reveals its defenses and traits.
func study(c: Combatant, target: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if target == null or not target.creature is Monster:
		return CombatResult.fail("Choose a creature to study")
	spend_action(c)
	var m := target.creature as Monster
	var skill := _knowledge_skill(str(m.data.get("type", "")))
	var dc := 10 + floori(m.cr)
	var t := c.creature.roll_check(dice, skill, dc)
	if t.success:
		studied[str(m.data.get("id", ""))] = true
		var info: Array[String] = []
		for k: String in ["resistances", "vulnerabilities", "immunities", "condition_immunities"]:
			var v := m.data.get(k, []) as Array
			if not v.is_empty():
				info.append("%s: %s" % [k.replace("_", " ").capitalize(), ", ".join(v)])
		for tr: Variant in m.data.get("traits", []):
			info.append("%s: %s" % [(tr as Dictionary).get("name", ""), (tr as Dictionary).get("summary", "")])
		log.add("info", "%s recalls what a %s is (%s %d)" % [c.name(), m.name, str(skill).capitalize(), t.total], c.id, [t.describe()] + info)
	else:
		log.add("info", "%s can't place the %s (%s %d vs DC %d)" % [c.name(), m.name, str(skill).capitalize(), t.total, dc], c.id, [t.describe()])
	return CombatResult.new()


static func _knowledge_skill(creature_type: String) -> StringName:
	match creature_type:
		"beast", "dragon", "ooze", "plant":
			return &"nature"
		"celestial", "fiend", "undead":
			return &"religion"
		"giant", "humanoid":
			return &"history"
	return &"arcana"


## Grapple or Shove with an Unarmed Strike as one attack of the Attack action (2024): the target makes a Strength
## or Dexterity save (its choice: the better one) against 8 + Str modifier + PB; it can be at most one size larger.
func unarmed_special(c: Combatant, target: Combatant, mode: String) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	if target == null or distance(c, target) > 5:
		return CombatResult.fail("Target must be within 5 ft")
	if Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size) + 1:
		return CombatResult.fail("Target is more than one size larger")
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
		c.attacks_left = attacks_per_action(c) - 1
	else:
		return CombatResult.fail("No attacks left this turn")
	var dc := 8 + c.creature.ability_mod(&"str") + c.creature.proficiency_bonus()
	var ab := &"str" if target.creature.save_bonus(&"str").total() >= target.creature.save_bonus(&"dex").total() else &"dex"
	var s := target.creature.roll_save(dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], mode.capitalize(), target.name()])
	var r := CombatResult.new()
	if s.success:
		log.add("info", "%s resists %s's %s" % [target.name(), c.name(), mode], c.id, [s.describe()])
		return r
	match mode:
		"grapple":
			target.creature.add_condition(&"grappled", c.name())
			grapples[target.id] = c.id
			log.add("condition", "%s grapples %s (escape DC %d)" % [c.name(), target.name(), dc], c.id, [s.describe()])
		"shove_prone":
			target.creature.add_condition(&"prone", "Shove")
			log.add("condition", "%s shoves %s Prone" % [c.name(), target.name()], c.id, [s.describe()])
		_:
			var moved := forced_move(target, center_of(c), 5)
			log.add("info", "%s shoves %s %d ft" % [c.name(), target.name(), moved * 5], c.id, [s.describe()])
	return r


## Escaping a grapple (2024): an action and a Strength (Athletics) or Dexterity (Acrobatics) check against the
## escape DC.
func escape_grapple(c: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not grapples.has(c.id):
		return CombatResult.fail("Not grappled")
	spend_action(c)
	var grappler := get_c(str(grapples[c.id]))
	var dc := 8 + grappler.creature.ability_mod(&"str") + grappler.creature.proficiency_bonus() if grappler != null else 10
	var skill := &"athletics" if c.creature.skill_bonus(&"athletics").total() >= c.creature.skill_bonus(&"acrobatics").total() else &"acrobatics"
	var t := c.creature.roll_check(dice, skill, dc)
	if t.success:
		grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		log.add("info", "%s breaks free" % c.name(), c.id, [t.describe()])
	else:
		log.add("info", "%s struggles but stays Grappled" % c.name(), c.id, [t.describe()])
	return CombatResult.new()


func _release_grapples_by(grappler: Combatant) -> void:
	for k: String in grapples.keys():
		if str(grapples[k]) == grappler.id:
			grapples.erase(k)
			var t := get_c(k)
			if t != null:
				t.creature.remove_condition(&"grappled")


## Drains scene events (moves, attacks, damage, turns) for animation.
func drain_events() -> Array[Dictionary]:
	spells.zones.prune()
	var out := events.duplicate()
	events.clear()
	return out
