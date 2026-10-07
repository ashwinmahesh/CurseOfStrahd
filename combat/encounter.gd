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
var reactions: Reactions
var feature_actions: FeatureActions
var monster_actions: MonsterActions
var ai: AiBrain
var shapes: ShapeChange
## A place where even allies can't pass through each other (a location's or fight's `allies_block`).
var allies_block := false
var class_features: ClassFeatures
## Ravenloft: The Horrors Within options (combat/ravenloft_features.gd).
var ravenloft: RavenloftFeatures
## Magic items: the Items tab, item powers and the hooks below (combat/combat_items.gd, ADR 0012).
var items: CombatItems
var _cover_cache: Dictionary = {}
## Savage Attacker is once per turn, any creature's turn: creature id -> the turn it was used on.
var _savage_turn: Dictionary = {}
## The map's light: bright, dim or dark (lanterns, moonlight, a lightless cellar); sunlit maps are in sunlight.
var ambient_light: String = "bright"
var sunlit: bool = false
## Reactions waiting to be offered after the current attack or spell finishes (Hellish Rebuke): {kind, reactor, trigger}.
var reaction_queue: Array[Dictionary] = []
## Free extra attacks waiting to be made once the current attack finishes (Cleave): {c, target, option}.
var cleave_queue: Array[Dictionary] = []
## Shown when the fight starts.
var title: String = ""
var intro: String = ""
## Where the fight is (ADR 0014): its location (a Misty Escape's resting place), whether its boss takes lair actions on
## initiative count 20, and whether it's outdoors (Children of the Night call wolves there).
var location_id: String = ""
## Places inside that location (its Tarokka treasure places, the final battle's room): a resting place can be one.
var places: Array[String] = []
var lair: bool = false
var outdoors: bool = false
## Legendary and lair actions, Regeneration, shapes, Misty Escape, withdrawing (combat/legendary.gd).
var legendary: Legendary


func _init(grid_: CombatGrid, dice_: DiceRoller) -> void:
	grid = grid_
	dice = dice_
	spells = SpellCaster.new(self)
	features = CombatFeatures.new(self)
	reactions = Reactions.new(self)
	feature_actions = FeatureActions.new(self)
	monster_actions = MonsterActions.new(self)
	ai = AiBrain.new(self)
	shapes = ShapeChange.new(self)
	class_features = ClassFeatures.new(self)
	ravenloft = RavenloftFeatures.new(self)
	items = CombatItems.new(self)
	legendary = Legendary.new(self)


# --- Setup ----------------------------------------------------------------------------------------

func add(creature: Creature, side: StringName, cell: Vector2i) -> Combatant:
	var c := Combatant.new(creature, side, cell)
	var base := c.id
	var n := 2
	while get_c(c.id) != null:
		c.id = "%s_%d" % [base, n]
		n += 1
	creature.id = c.id
	creature.d20_before = feature_actions.before_d20
	creature.d20_after = feature_actions.after_d20
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
	surprised_ids = items.surprise_filter(surprised_ids)
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
		var t := c.creature.roll_d20(dice, D20Test.Kind.ABILITY_CHECK, bonus, 0, c.creature.initiative_keys(), items.initiative_advantage(c), dis,
			"Initiative (%s)" % c.name())
		# Ambush (Battle Master): a Superiority Die on Initiative.
		if features.knows_maneuver(c, "ambush") and (c.creature as Character).resource_left("superiority_dice") > 0:
			(c.creature as Character).spend_resource("superiority_dice")
			t.add_bonus(dice.roll_one(features.superiority_die(c), "Ambush"), "Ambush")
		var item_init := items.initiative_bonus(c)
		if item_init > 0:
			t.add_bonus(item_init, "Sword of Kas")
		c.initiative_test = t
		c.initiative = t.total
		if group != "":
			group_rolls[group] = t.total
			c.initiative_group = group
		log.add("roll", "%s rolls Initiative: %d" % [c.name(), t.total], c.id, [t.describe(), bonus.describe()])
	class_features.initiative_rolled()
	ravenloft.initiative_rolled()
	order = combatants.duplicate()
	order.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		var da := a.creature.ability_score(&"dex")
		var db := b.creature.ability_score(&"dex")
		if da != db:
			return da > db
		return a.side == &"party" and b.side != &"party")
	# Portent (Diviner): the two (Greater Portent: three) foreseen d20s for this fight.
	for c in combatants:
		if CombatFeatures.has_feature(c, "portent") and c.creature is Character:
			var n := 3 if CombatFeatures.has_feature(c, "greater_portent") else 2
			c.set_meta("portent_rolls", dice.roll(20, n, "Portent"))
			log.add("info", "%s foresees: %s (Portent)" % [c.name(), str(c.get_meta("portent_rolls"))], c.id)
	# Thief's Reflexes (Thief 17): a second turn in the first round, at Initiative − 10.
	for c: Combatant in combatants.duplicate():
		if CombatFeatures.has_feature(c, "thiefs_reflexes"):
			var at := order.size()
			for i in order.size():
				if order[i].initiative < c.initiative - 10:
					at = i
					break
			order.insert(at, c)
			c.set_meta("reflex_turn", true)
	state = State.ACTIVE
	for cc in combatants:
		class_features.prepare(cc)
	items.combat_started()
	spells.zones.refresh_auras()
	round_no = 1
	log.round_no = 1
	log.add("turn", "Round 1", "")
	events.append({"type": "round", "round": 1})
	legendary.combat_started()
	turn_index = 0
	_lair_then_begin()


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
		var sees_invisible := a.creature.has_flag("see_invisibility") or (truesight > 0 and dist <= truesight) or items.reveals_invisible(a, b)
		if not sees_invisible:
			return false
	# Devil's Sight (invocation): normal sight in Darkness, magical or not, within 120 ft.
	var devil := (a.creature.has_flag("devils_sight") and dist <= 120) or ravenloft.sees_through_darkness(a)
	if spells.zones.line_obscured(a.cell, a.size_cells, b.cell, b.size_cells, devil) and not by_sense:
		return false
	# Umbral Sight (Gloom Stalker): unseen in Darkness by creatures that rely on Darkvision.
	var umbral := b.creature.has_flag("umbral_sight") and light_at(b.cell) == "dark"
	match light_at(b.cell):
		"magic_dark":
			return by_sense or devil
		"dark":
			return by_sense or devil or (a.creature.darkvision() >= dist and a.creature.darkvision() > 0 and not umbral) or outlined
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


## Whether this fight is at `place`: its location, or a place inside it.
func at_place(place: String) -> bool:
	return place != "" and (place == location_id or place in places)


## Whether a creature stands in running water (a deep-water square it isn't flying over, or the `in_running_water`
## flag): a vampire's Regeneration, shape changes and Misty Escape fail there.
func in_running_water(c: Combatant) -> bool:
	if c.creature.has_flag("in_running_water"):
		return true
	if move_mode(c) & CombatGrid.MOVE_FLY:
		return false
	for cell in c.footprint():
		if grid.has_flag(cell, CombatGrid.WATER):
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
	var blocked := occ["blocked"] as Dictionary
	# Frightened: no square closer to a source of fear the creature can see (a stricter, per-square reading of
	# "can't willingly move closer", see deviations.md).
	for src in fear_sources(c):
		var now := grid.distance_ft(c.cell, c.size_cells, src.cell, src.size_cells)
		for x in grid.width:
			for y in grid.depth:
				var cell := Vector2i(x, y)
				if grid.distance_ft(cell, c.size_cells, src.cell, src.size_cells) < now:
					blocked[cell] = true
	# Forcecage: no stepping out of a cage, or into one; Antilife Shell keeps most creatures out.
	for cell3: Vector2i in spells.specials.high.cage_blocks(c):
		blocked[cell3] = true
	for cell4: Vector2i in spells.specials.mid.shell_blocks(c):
		blocked[cell4] = true
	# Compelled Duel: no square more than 30 ft from the duellist.
	var anchor := spells.specials.duel_anchor(c)
	if anchor != null:
		for x2 in grid.width:
			for y2 in grid.depth:
				var cell2 := Vector2i(x2, y2)
				if grid.distance_ft(cell2, c.size_cells, anchor.cell, anchor.size_cells) > 30:
					blocked[cell2] = true
	return grid.reachable(c.cell, c.size_cells, feet, _has_fn(blocked),
		_value_fn(occ["slowed"] as Dictionary), _has_fn(occ["occupied"] as Dictionary), move_mode(c))


## How `c` moves: flying (a fly speed at least its walking speed, Fly, Gaseous Form) or climbing (Spider Climb).
func move_mode(c: Combatant) -> int:
	var mode := 0
	if c.creature.speed("fly").total() > 0 and c.creature.speed("fly").total() >= c.creature.speed().total():
		mode |= CombatGrid.MOVE_FLY
	if c.creature.has_flag("spider_climb") or c.creature.speed("climb").total() > 0 or CombatFeatures.has_feature(c, "second_story_work"):
		mode |= CombatGrid.MOVE_CLIMB
	if c.creature.has_flag("incorporeal_movement"):
		mode |= CombatGrid.MOVE_INCORPOREAL
	if c.creature.has_flag("freedom_of_movement") or c.creature.has_flag("ignore_difficult_terrain"):
		mode |= CombatGrid.MOVE_UNHINDERED
	return mode


## The creatures `c` is Frightened of and can see.
func fear_sources(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if not c.creature.has_condition(&"frightened"):
		return out
	for fx in c.creature.effects:
		if not &"frightened" in fx.conditions or fx.caster_id == "":
			continue
		var src := get_c(fx.caster_id)
		if src != null and src != c and src.is_alive() and not src in out and can_see(c, src):
			out.append(src)
	return out


## How other creatures' squares affect `c`'s movement: {blocked, slowed, occupied}, each a set of cells.
## 2024: you can pass through an ally, an Incapacitated creature, a Tiny creature or one two sizes different
## (Halfling Nimbleness: any larger creature); another creature's space, an ally's too, is Difficult Terrain unless
## it's Tiny; you can't end your move in an occupied space. `allies_block` (a place's flag) makes allies block too.
func _occupancy_for(c: Combatant) -> Dictionary:
	var blocked := {}
	var slowed := {}
	var occupied := {}
	var my_size := Creature.SIZES.find(c.creature.size)
	var partner := mount_of(c) if mount_of(c) != null else rider_of(c)
	for o in combatants:
		if o == c or not o.is_alive() or o == partner:
			continue
		var o_size := Creature.SIZES.find(o.creature.size)
		# Swarms, and elementals made of air, fire or water, can move into (and stay in) other creatures' spaces.
		var swarmy := o.creature.has_flag("swarm") or c.creature.has_flag("swarm") or c.creature.has_flag("enters_spaces")
		if swarmy:
			continue
		var passable := (c.allied_with(o) and not allies_block) or o.creature.has_flag("no_actions") or o.creature.size == &"tiny" \
			or absi(o_size - my_size) >= 2 or (c.creature.has_flag("halfling_nimbleness") and o_size > my_size)
		# 2024: any other creature's space is Difficult Terrain, an ally's included (a Tiny one excepted).
		var slows := o.creature.size != &"tiny"
		for cell in o.footprint():
			occupied[cell] = true
			if not passable:
				blocked[cell] = true
			if slows:
				slowed[cell] = true
	var terrain := spells.zones.difficult_cells(c)
	for cell: Vector2i in terrain:
		slowed[cell] = terrain[cell] if terrain[cell] is int else true
	if c.creature.has_flag("pass_through_creatures"):
		blocked = {}
	# Wall of Force and Wall of Stone: no one walks through.
	for wcell: Vector2i in spells.specials.mid.blocked_cells():
		blocked[wcell] = true
	return {"blocked": blocked, "slowed": slowed, "occupied": occupied}


static func _has_fn(set: Dictionary) -> Callable:
	return func(cell: Vector2i) -> bool: return set.has(cell)


## The value stored for a square (true, or a movement multiplier), or false.
static func _value_fn(set: Dictionary) -> Callable:
	return func(cell: Vector2i) -> Variant: return set.get(cell, false)


# --- Turns ----------------------------------------------------------------------------------------

func _begin_turn() -> void:
	var c := current()
	if c == null:
		return
	for o in combatants:
		o.cast_slot_spell_this_turn = false
		o.creature.on_turn_start(c.id)
	_expire_marks(c.id, "start")
	if c.readied.has("conc"):
		var held := c.readied["conc"] as Concentration
		if held != null and not held.ended:
			held.end("the readied spell wasn't released")
			log.add("info", "%s lets the readied spell go" % c.name(), c.id)
	c.reset_turn()
	if c.creature.has_flag("hasted"):
		c.haste_action = true
	log.add("turn", "%s's turn" % c.name(), c.id)
	events.append({"type": "turn", "id": c.id, "round": round_no})
	# Legendary actions come back; Regeneration (before anything else starts this turn); a foe whose time is up leaves.
	legendary.turn_start(c)
	if not c.is_alive():
		return
	spells.turn_start(c)
	feature_actions.turn_start(c)
	class_features.turn_start(c)
	ravenloft.turn_start(c)
	monster_actions.turn_start(c)
	items.turn_start(c)
	if c.creature.has_flag("dazed"):
		c.bonus_available = false
		log.add("info", "%s is Dazed: it can move or act this turn, not both" % c.name(), c.id)
	if c.has_meta("disarmed"):
		c.remove_meta("disarmed")
		log.add("info", "%s picks up what it dropped" % c.name(), c.id)
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
	c.armed.clear()
	feature_actions.turn_end(c)
	class_features.turn_end(c)
	ravenloft.turn_end(c)
	monster_actions.turn_end(c)
	items.turn_end(c)
	spells.turn_end(c)
	spells.zones.prune()
	_check_over()
	if state != State.ACTIVE:
		return CombatResult.new()
	# Legendary actions at the end of another creature's turn (not while time is stopped).
	var stopped := c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0
	var lr := legendary.after_turn(c) if not stopped else CombatResult.new()
	if pending != null:
		return then(lr, func() -> CombatResult: return _next_turn(c))
	return _next_turn(c)


## After `c`'s turn (and any legendary actions): the next creature, a new round, the lair's turn.
func _next_turn(c: Combatant) -> CombatResult:
	_check_over()
	if state != State.ACTIVE:
		return CombatResult.new()
	# Time Stop: the caster's next turn comes straight away.
	if c.has_meta("time_stop") and int(c.get_meta("time_stop")) > 0 and c.is_alive() and c.can_act():
		c.set_meta("time_stop", int(c.get_meta("time_stop")) - 1)
		log.add("turn", "Time is still stopped: another turn for %s" % c.name(), c.id)
		_begin_turn()
		return CombatResult.new()
	c.remove_meta("time_stop")
	_advance_index()
	if state != State.ACTIVE:
		return CombatResult.new()
	_lair_then_begin()
	return CombatResult.new()


## Moves `turn_index` to the next living creature, starting a new round past the end of the order (a lair that hasn't
## acted yet this round acts first; called creatures arrive as the new round begins).
func _advance_index() -> void:
	for i in order.size():
		turn_index += 1
		if turn_index >= order.size():
			legendary.round_ending()
			if state != State.ACTIVE:
				return
			turn_index = 0
			round_no += 1
			_drop_reflex_turns()
			log.round_no = round_no
			log.add("turn", "Round %d" % round_no, "")
			events.append({"type": "round", "round": round_no})
			legendary.round_started()
		if current().is_alive():
			break


## The lair acts on initiative count 20 (losing ties) before the first creature below 20; then the turn begins.
func _lair_then_begin() -> void:
	if legendary.lair_due():
		legendary.lair_turn()
		_check_over()
		if state != State.ACTIVE:
			return
		if not current().is_alive():
			_advance_index()
			if state != State.ACTIVE:
				return
	_begin_turn()


## After round 1, Thief's Reflexes' extra turns leave the order.
func _drop_reflex_turns() -> void:
	for c in combatants:
		if c.has_meta("reflex_turn"):
			c.remove_meta("reflex_turn")
			var first := order.find(c)
			var second := order.find(c, first + 1)
			if second >= 0:
				order.remove_at(second)


func is_over() -> bool:
	return state == State.OVER


func _check_over() -> void:
	if state != State.ACTIVE:
		return
	var party_up := false
	var enemies_up := false
	for c in combatants:
		if not c.is_alive() or c.creature.hp <= 0 or c.creature.has_flag("spell_object"):
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
		# An Antimagic Field doesn't outlast the fight: magic items wake up again.
		for c in combatants:
			for who: Creature in [c.creature, shapes.original(c)]:
				if who is Character:
					(who as Character).magic_suppressed = false
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
	# Riding: the controlled mount carries its rider, spending its own movement.
	var steed := controlled_mount(c)
	if steed != null:
		var sreach := reachable_for(steed)
		if not sreach.has(dest):
			return CombatResult.fail("Your mount can't reach that square with %d ft of movement" % steed.movement_left)
		if bool((sreach[dest] as Dictionary)["occupied"]):
			return CombatResult.fail("Your mount can't end its move in an occupied space")
		c.moved = true
		return _walk(steed, CombatGrid.path_to(sreach, dest), 1, CombatResult.new(), {})
	# Freedom of Movement: 5 ft of movement slips any grapple.
	if c.creature.has_flag("freedom_of_movement") and grapples.has(c.id) and c.movement_left >= 5:
		grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		c.remove_meta("escape_dc")
		monster_actions.release_engulf(c)
		c.movement_left -= 5
		log.add("info", "%s slips free (Freedom of Movement)" % c.name(), c.id)
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


## Moves `c` (not on its own turn) up to `feet` toward the reachable square that best follows `dir` (Confusion,
## Compulsion). The movement can provoke Opportunity Attacks.
func march(c: Combatant, dir: Vector2, feet: int, r: CombatResult) -> CombatResult:
	var origin := center_of(c)
	return _move_best(c, feet, r, func(cell: Vector2i) -> float: return (Vector2(cell) + Vector2(0.5, 0.5) - origin).dot(dir.normalized()))


## Moves `c` up to `feet` as far from `away` as it can get (Dissonant Whispers).
func flee(c: Combatant, away: Combatant, feet: int, r: CombatResult) -> CombatResult:
	return _move_best(c, feet, r, func(cell: Vector2i) -> float: return float(grid.distance_ft(away.cell, away.size_cells, cell, c.size_cells)))


func _move_best(c: Combatant, feet: int, r: CombatResult, score: Callable) -> CombatResult:
	var keep := c.movement_left
	c.movement_left = feet
	var reach := reachable_for(c)
	var best := c.cell
	var best_s := float(score.call(c.cell))
	for cell: Vector2i in reach:
		if bool((reach[cell] as Dictionary)["occupied"]):
			continue
		var sc := float(score.call(cell))
		if sc > best_s + 0.01:
			best_s = sc
			best = cell
	if best == c.cell:
		c.movement_left = keep
		return r
	var res := _walk(c, CombatGrid.path_to(reach, best), 1, r, {})
	c.movement_left = keep
	return res


func _walk(c: Combatant, path: Array[Vector2i], i: int, r: CombatResult, handled: Dictionary) -> CombatResult:
	while i < path.size():
		var to := path[i]
		if not c.creature.has_flag("flyby") and not c.creature.has_flag("agile"):
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
		var step := grid.step_cost(c.cell, to, c.size_cells, _has_fn(occ["blocked"] as Dictionary), _value_fn(occ["slowed"] as Dictionary), move_mode(c))
		if c.creature.has_condition(&"prone"):
			step *= 2
		if c.has_meta("jumping"):
			step = 0
		if step < 0 or step > c.movement_left:
			break
		var from := c.cell
		c.movement_left -= step
		c.moved = true
		c.cell = to
		c.facing = Vector2(to - from).normalized()
		events.append({"type": "move", "id": c.id, "from": from, "to": to})
		var carried := rider_of(c)
		if carried != null:
			var rfrom := carried.cell
			carried.cell = to
			events.append({"type": "move", "id": carried.id, "from": rfrom, "to": to, "mounted": true})
		_after_step(c, from)
		if c.is_down() or state != State.ACTIVE:
			return r
		i += 1
		# Polearm Master's Reactive Strike: entering the reach of a polearm-wielder.
		for pm in hostiles_of(c):
			var pkey := "pole:%s" % pm.id
			if handled.has(pkey) or not features.has_feat(pm, "polearm_master") or not spells.can_react(pm) or not can_see(pm, c):
				continue
			var pole := _polearm_option(pm)
			if pole.is_empty():
				continue
			var preach := (pole["profile"] as WeaponProfile).reach
			if grid.distance_ft(pm.cell, pm.size_cells, to, c.size_cells) <= preach and grid.distance_ft(pm.cell, pm.size_cells, from, c.size_cells) > preach:
				handled[pkey] = true
				var pdec := _reaction_decision(pm, "reactive_strike")
				if pdec == "auto":
					pm.reaction_available = false
					log.add("reaction", "%s strikes as %s closes in (Polearm Master)" % [pm.name(), c.name()], pm.id)
					var psub := _resolve_attack(pm, c, pole, {"reaction": true})
					if pending != null:
						var ii := i
						return then(psub, func() -> CombatResult:
							if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
								return r
							return _walk(c, path, ii, r, handled))
					if c.is_down() or state != State.ACTIVE:
						return r
				elif pdec == "ask":
					var preq := ReactionRequest.new("reactive_strike", pm.id, c.id)
					preq.title = "Reaction: Reactive Strike?"
					preq.text = "%s enters %s's reach. Strike with the polearm?" % [c.name(), pm.name()]
					var jj := i
					preq.continuation = func(use: bool) -> CombatResult:
						var cont := func() -> CombatResult:
							if c.is_down() or c.speed() <= 0 or state != State.ACTIVE:
								return r
							return _walk(c, path, jj, r, handled)
						if use:
							pm.reaction_available = false
							return then(_resolve_attack(pm, c, pole, {"reaction": true}), cont)
						return cont.call() as CombatResult
					pending = preq
					r.pending = preq
					return r
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
		if p.readied.is_empty() or not p.reaction_available or not p.can_act() or p.creature.has_flag("no_reactions") or not can_see(p, mover):
			continue
		var reach := 0
		if p.readied.has("spell"):
			reach = spells.range_ft(Compendium.shared().spell_data(str(p.readied["spell"])), p)
		else:
			var option := option_by_id(p, str(p.readied.get("option", "")))
			if option.is_empty():
				continue
			var prof := option["profile"] as WeaponProfile
			reach = prof.reach if bool(option["melee"]) else prof.normal_range
		var before := grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if after <= reach and before > reach:
			out.append(p)
	return out


func _readied_attack(p: Combatant, target: Combatant) -> CombatResult:
	if p.readied.has("spell"):
		var held := p.readied.duplicate()
		p.readied = {}
		return spells.release_readied(p, held, target)
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


## Ready (2024) with a spell: cast it now (the slot is spent), hold its energy with Concentration, and release it
## with your Reaction when an enemy comes within the spell's range before the start of your next turn. If
## Concentration breaks first, the spell is lost.
func ready_spell(c: Combatant, spell_id: String, slot: int) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var entry := {}
	for x in spells.castable(c):
		if str(x["id"]) == spell_id:
			entry = x
	if entry.is_empty():
		return CombatResult.fail("Unknown spell")
	var s := Compendium.shared().spell_data(spell_id)
	if str((s.get("casting_time", {}) as Dictionary).get("unit", "")) != "action":
		return CombatResult.fail("Only a spell with a casting time of an action can be readied")
	if not bool(entry["legal"]) and str(entry["reason"]) != "Action already used":
		return CombatResult.fail(str(entry["reason"]))
	var ch := c.creature as Character
	var level := int(s.get("level", 0))
	if level > 0:
		slot = maxi(slot, level)
		if ch.slots_left(slot) <= 0:
			return CombatResult.fail("No level %d slots left" % slot)
		ch.expend_slot(slot)
		c.cast_slot_spell_this_turn = true
	spend_action(c)
	c.magic_action_used = true
	var conc := c.creature.begin_concentration("readied:" + spell_id, "a readied %s" % s["name"])
	c.readied = {"spell": spell_id, "slot": slot, "conc": conc}
	log.add("spell", "%s readies %s for the first enemy to come within %d ft" % [c.name(), s["name"], spells.range_ft(s, c)], c.id)
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


## Drinking a potion or eating a Goodberry (2024: a Bonus Action), or giving it to a creature within 5 ft. Potions are
## item powers now (CombatItems); Goodberries and other heal-only consumables keep this path.
func use_item(c: Combatant, item_id: String, target: Combatant) -> CombatResult:
	var item := Compendium.shared().item_data(item_id)
	if str(item.get("category", "")) == "potion" and not items.find_power(c, item_id, "drink").is_empty():
		return items.use(c, item_id, "drink", [target if target != null else c])
	var why := _bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if item_count(c, item_id) <= 0:
		return CombatResult.fail("None left")
	if target == null or distance(c, target) > 5:
		return CombatResult.fail("Must be within 5 ft")
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
		if not spells.can_react(p) or not can_see(p, mover) or p.creature.has_flag("no_opportunity_attacks"):
			continue
		# Disengage stops Opportunity Attacks, except a Sentinel's against a creature within 5 ft of it.
		if mover.disengaged and not (features.has_feat(p, "sentinel") and grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells) <= 5):
			continue
		var reach := p.reach_ft()
		var before := grid.distance_ft(p.cell, p.size_cells, from, mover.size_cells)
		var after := grid.distance_ft(p.cell, p.size_cells, to, mover.size_cells)
		if before <= reach and after > reach:
			out.append(p)
	return out


## The weapon a Polearm Master reacts with: a Quarterstaff, a Spear, or a Heavy weapon with Reach.
func _polearm_option(p: Combatant) -> Dictionary:
	for o in attack_options(p):
		var pr := o["profile"] as WeaponProfile
		if bool(o["melee"]) and (pr.item_id in ["quarterstaff", "spear"] or ("heavy" in pr.properties and "reach" in pr.properties)):
			return o
	return {}


func _opportunity_attack(p: Combatant, target: Combatant) -> CombatResult:
	var option := best_melee_option(p, target)
	# War Caster's Reactive Spell: a one-action spell at the creature instead (when it has no melee attack, or the
	# player's rule for it is "auto").
	if features.has_feat(p, "war_caster") and (option.is_empty() or str(p.reaction_rules.get("reactive_spell", "never")) == "auto"):
		for sp in spells.castable(p):
			var data := Compendium.shared().spell_data(str(sp["id"]))
			if int(sp["level"]) == 0 and str(sp["casting"]) == "action" and (data.has("attack") or data.has("save")) and not data.has("area") \
					and spells.range_ft(data, p) >= distance(p, target):
				p.reaction_available = false
				log.add("reaction", "%s answers with %s (War Caster)" % [p.name(), data["name"]], p.id)
				return spells.cast_free(p, str(sp["id"]), [target], Vector2.INF, {})
	if option.is_empty():
		return CombatResult.new()
	p.reaction_available = false
	log.add("reaction", "%s makes an Opportunity Attack against %s" % [p.name(), target.name()], p.id)
	var oa := option.duplicate()
	oa["opportunity"] = true
	return _resolve_attack(p, target, oa, {"reaction": true, "opportunity": true})


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
	spells.specials.mid.shell_moved(c)
	monster_actions.entered_space(c)
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
	var cost := 5 if c.creature.has_flag("hop_up") else c.speed() / 2
	if c.speed() <= 0 or c.movement_left < cost:
		return CombatResult.fail("Standing up costs %d ft" % cost)
	c.movement_left -= cost
	c.creature.remove_condition(&"prone")
	c.stood_up = true
	log.add("move", "%s stands up (%d ft)" % [c.name(), cost], c.id)
	events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## Moving with feature movement that doesn't provoke Opportunity Attacks (Tactical Shift, Cunning Strike's
## Withdraw, Remarkable Athlete, Maneuvering Attack): up to `c.free_move_ft`, not using the creature's movement.
func free_move(c: Combatant, dest: Vector2i) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if c.free_move_ft <= 0:
		return CombatResult.fail("No free movement")
	var reach := reachable_for(c, c.free_move_ft)
	if not reach.has(dest) or bool((reach[dest] as Dictionary)["occupied"]):
		return CombatResult.fail("Can't get there with %d ft" % c.free_move_ft)
	var path := CombatGrid.path_to(reach, dest)
	var keep_move := c.movement_left
	var keep_dis := c.disengaged
	c.movement_left = c.free_move_ft
	c.disengaged = true
	var r := _walk(c, path, 1, CombatResult.new(), {})
	c.free_move_ft = 0
	c.movement_left = keep_move
	c.disengaged = keep_dis
	return r


## Jump (the spell): once on each of its turns, a leap of up to 30 ft for 10 ft of movement, over creatures and
## Difficult Terrain (not through walls). Leaving an enemy's reach still provokes Opportunity Attacks.
func jump(c: Combatant, dest: Vector2i) -> CombatResult:
	var why := _turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.creature.has_flag("jump"):
		return CombatResult.fail("No Jump")
	if int(c.get_meta("jumped_round", -1)) == round_no:
		return CombatResult.fail("Already jumped this turn")
	if c.movement_left < 10:
		return CombatResult.fail("Needs 10 ft of movement")
	if grid.distance_ft(c.cell, c.size_cells, dest, c.size_cells) > 30:
		return CombatResult.fail("At most 30 ft")
	for cell in CombatGrid.footprint(dest, c.size_cells):
		if grid.is_solid(cell) or (occupant_at(cell) != null and occupant_at(cell) != c):
			return CombatResult.fail("Can't land there")
	var path: Array[Vector2i] = [c.cell]
	var from := center_of(c)
	var to := Vector2(dest.x + c.size_cells / 2.0, dest.y + c.size_cells / 2.0)
	var steps := maxi(absi(dest.x - c.cell.x), absi(dest.y - c.cell.y))
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var cell := Vector2i(floori(p.x - c.size_cells / 2.0 + 0.5), floori(p.y - c.size_cells / 2.0 + 0.5))
		if grid.has_flag(cell, CombatGrid.WALL):
			return CombatResult.fail("A wall is in the way")
		if cell != path[path.size() - 1]:
			path.append(cell)
	if path[path.size() - 1] != dest:
		path.append(dest)
	c.movement_left -= 10
	c.set_meta("jumped_round", round_no)
	c.set_meta("jumping", true)
	log.add("move", "%s leaps %d ft (Jump)" % [c.name(), grid.distance_ft(c.cell, c.size_cells, dest, c.size_cells)], c.id)
	var r := _walk(c, path, 1, CombatResult.new(), {})
	c.remove_meta("jumping")
	return r


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
	# Dwarven Plate: a Reaction cuts a shove across the ground by up to 10 ft.
	feet = items.forced_move_feet(target, feet)
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
		var partner := mount_of(target) if mount_of(target) != null else rider_of(target)
		for cell in CombatGrid.footprint(nxt, target.size_cells):
			var o := occupant_at(cell)
			if not grid.in_bounds(cell) or grid.is_solid(cell) or (o != null and o != target and o != partner):
				ok = false
		if not ok:
			break
		events.append({"type": "move", "id": target.id, "from": target.cell, "to": nxt, "forced": true})
		var was := target.cell
		target.cell = nxt
		moved += 1
		_after_step(target, was)
	if moved > 0:
		_forced_mount_check(target)
	return moved


# --- Mounted combat (2024 PHB) ------------------------------------------------------------------------------

func mount_of(c: Combatant) -> Combatant:
	if not c.has_meta("mounted_on"):
		return null
	var m := get_c(str(c.get_meta("mounted_on")))
	return m if m != null and m.is_alive() else null


func rider_of(c: Combatant) -> Combatant:
	if not c.has_meta("ridden_by"):
		return null
	var r := get_c(str(c.get_meta("ridden_by")))
	return r if r != null and r.is_alive() else null


## A willing creature at least one size larger, within 5 ft, not already carrying someone.
func mount_why(rider: Combatant, steed: Combatant) -> String:
	if steed == null or steed == rider:
		return "Choose a mount"
	if mount_of(rider) != null:
		return "Already mounted"
	if rider_of(steed) != null or mount_of(steed) != null:
		return "%s already carries someone" % steed.name()
	if not rider.allied_with(steed) or steed.is_down():
		return "%s isn't willing" % steed.name()
	if Creature.SIZES.find(steed.creature.size) <= Creature.SIZES.find(rider.creature.size):
		return "%s must be at least one size larger" % steed.name()
	if distance(rider, steed) > 5:
		return "Move within 5 ft first"
	if rider.movement_left < rider.speed() / 2:
		return "Needs half your Speed"
	return ""


## Mounting costs half your Speed; you then share the mount's space and ride it.
func mount(rider: Combatant, steed: Combatant) -> CombatResult:
	var why := _turn_check(rider)
	if why == "":
		why = mount_why(rider, steed)
	if why != "":
		return CombatResult.fail(why)
	rider.movement_left -= rider.speed() / 2
	var from := rider.cell
	rider.cell = steed.cell
	rider.set_meta("mounted_on", steed.id)
	steed.set_meta("ridden_by", rider.id)
	events.append({"type": "move", "id": rider.id, "from": from, "to": rider.cell, "mounted": true})
	log.add("move", "%s mounts %s" % [rider.name(), steed.name()], rider.id)
	return CombatResult.new()


## Dismounting costs half your Speed (none when thrown); you land in a free space within 5 ft of the mount.
func dismount(rider: Combatant, prone: bool = false, voluntary: bool = true) -> CombatResult:
	var steed := get_c(str(rider.get_meta("mounted_on", "")))
	if steed == null:
		return CombatResult.fail("Not mounted")
	if voluntary:
		var why := _turn_check(rider)
		if why == "" and rider.movement_left < rider.speed() / 2:
			why = "Needs half your Speed"
		if why != "":
			return CombatResult.fail(why)
		rider.movement_left -= rider.speed() / 2
	rider.remove_meta("mounted_on")
	steed.remove_meta("ridden_by")
	var from := rider.cell
	var spot := spells._free_cell_near(steed.cell, rider.size_cells)
	rider.cell = spot
	events.append({"type": "move", "id": rider.id, "from": from, "to": spot, "forced": not voluntary})
	if prone:
		rider.creature.add_condition(&"prone", "Thrown from the mount")
		events.append({"type": "condition", "id": rider.id})
	log.add("move", "%s %s %s" % [rider.name(), "is thrown from" if prone else "dismounts", steed.name()], rider.id)
	return CombatResult.new()


## A controlled mount (Find Steed's, or any willing ally a creature rides): it moves when its rider moves.
func controlled_mount(rider: Combatant) -> Combatant:
	var m := mount_of(rider)
	return m if m != null and m.allied_with(rider) else null


## The mount was moved against its will: the rider makes a DC 10 Dexterity save or falls off Prone; a rider moved
## alone leaves its mount.
func _forced_mount_check(target: Combatant) -> void:
	var r := rider_of(target)
	if r != null:
		var sv := r.creature.roll_save(dice, &"dex", 10, [], [], "Dexterity save to stay mounted (%s)" % r.name())
		if sv.success:
			var from := r.cell
			r.cell = target.cell
			events.append({"type": "move", "id": r.id, "from": from, "to": r.cell, "forced": true, "mounted": true})
		else:
			log.add("info", "%s loses the saddle" % r.name(), r.id, [sv.describe()])
			dismount(r, true, false)
	elif mount_of(target) != null and target.cell != mount_of(target).cell:
		var m := mount_of(target)
		target.remove_meta("mounted_on")
		m.remove_meta("ridden_by")
		log.add("info", "%s is knocked from %s" % [target.name(), m.name()], target.id)


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
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.bonus_available and not c.surged:
		return "An action or a Bonus Action this turn, not both"
	return ""


## "" if `c` could make one attack of the Attack action now (starting it if it hasn't).
func features_attack_why(c: Combatant) -> String:
	var why := _turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "Can't act"
	if c.attacks_left <= 0 and not c.action_available:
		return "Action already used"
	return ""


## Uses one attack of the Attack action (starting it if needed): Breath Weapon, Commander's Strike, War Magic.
func use_one_attack(c: Combatant) -> void:
	if c.attacks_left > 0:
		c.attacks_left -= 1
	elif c.action_available:
		spend_action(c)
		c.took_attack_action = true
		c.attacks_left = attacks_per_action(c) - 1


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
	if (c.creature.has_flag("slowed") or c.creature.has_flag("action_or_bonus")) and not c.action_available:
		return "An action or a Bonus Action this turn, not both"
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


## Putting out the flames on yourself (Burning, 2024 rules glossary): an action, and you fall Prone.
func douse(c: Combatant) -> CombatResult:
	var why := _action_check(c)
	if why != "":
		return CombatResult.fail(why)
	var burning: Array[Effect] = []
	for x: Effect in c.creature.effects:
		if bool(x.data.get("douse", false)):
			burning.append(x)
	if burning.is_empty():
		return CombatResult.fail("Not burning")
	spend_action(c)
	for fx in burning:
		c.creature.remove_effect(fx)
	c.creature.add_condition(&"prone", "Rolled on the ground")
	log.add("info", "%s drops and rolls, putting out the flames" % c.name(), c.id)
	events.append({"type": "condition", "id": c.id})
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
			out.append({"id": ("thrown:" if p.thrown else "weapon:") + p.item_id + ("@" + p.ammo_id if p.ammo_id != "" else ""), "label": p.name,
				"kind": "thrown" if p.thrown else ("unarmed" if p.item_id == "unarmed_strike" else "weapon"),
				"profile": p, "melee": p.melee, "range": [p.normal_range, p.long_range], "reach": p.reach})
		if CombatFeatures.has_feature(c, "psychic_blades"):
			for thrown: bool in [false, true]:
				var pb := _psychic_blade(c, thrown, c.light_attack_weapon == "psychic_blade")
				out.append({"id": ("blade:thrown" if thrown else "blade:melee"), "label": pb.name, "kind": "blade",
					"profile": pb, "melee": not thrown, "range": [pb.normal_range, pb.long_range], "reach": pb.reach})
		out.append_array(ravenloft.attack_options(c))
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


## Soulknife's Psychic Blade: a Simple Melee weapon with Finesse and Thrown (60/120 ft), 1d6 Psychic + the
## ability modifier, Vex mastery; the second blade (a Bonus Action after attacking with the first) deals 1d4.
func _psychic_blade(c: Combatant, thrown: bool, second: bool) -> WeaponProfile:
	var item := {"id": "psychic_blade", "name": "Psychic Blade", "weapon": {"kind": "simple_melee", "damage": "1d4" if second else "1d6",
		"damage_type": "psychic", "properties": ["finesse", "thrown", "light"], "range": [60, 120], "mastery": "vex"}}
	var p := WeaponProfile.build(c.creature, item, thrown)
	p.mastery = "vex"
	p.proficient = true
	p._compute(c.creature)
	return p


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
	if rider_of(c) != null and c.allied_with(rider_of(c)):
		return CombatResult.fail("A controlled mount can only Dash, Disengage or Dodge")
	var beast_why := class_features.companion_why(c)
	if beast_why != "":
		return CombatResult.fail(beast_why)
	if c.creature is Monster and bool((c.creature as Monster).data.get("familiar", false)) and not bool(opts.get("chain", false)):
		return CombatResult.fail("A familiar doesn't attack on its own (Pact of the Chain: its warlock gives up an attack for it)")
	var lp := option["profile"] as WeaponProfile
	if "loading" in lp.properties and not features.has_feat(c, "crossbow_expert") and c.attacks_left > 0 \
			and str(c.get_meta("loading_fired", "")) == "%d:%d" % [round_no, turn_index]:
		return CombatResult.fail("Loading: one shot with it per action")
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
	# Loading: one shot per action, whatever the number of attacks (Crossbow Expert ignores it).
	if "loading" in p.properties and not features.has_feat(c, "crossbow_expert"):
		c.set_meta("loading_fired", "%d:%d" % [round_no, turn_index])
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
	# Dual Wielder: the extra attack can use any melee weapon that isn't Two-Handed. Psychic Blades: a second blade.
	var dual := features.has_feat(c, "dual_wielder") and bool(option["melee"]) and not "two_handed" in p.properties
	var blade := c.light_attack_weapon == "psychic_blade" and p.item_id == "psychic_blade"
	if not blade and ((not "light" in p.properties and not dual) or p.item_id == c.light_attack_weapon):
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
	if spells.specials.sphere_blocks(c, target):
		return "A sphere of force is in the way"
	if spells.specials.high.box_between(c, target) or spells.specials.mid.wall_between(c, target):
		return "A wall is in the way"
	if bool(option["melee"]) and spells.specials.mid.shell_blocks_reach(c, target):
		return "The Antilife Shell keeps you out of reach"
	var item_block := items.attack_blocked(c, target, option)
	if item_block != "":
		return item_block
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
	if c.creature.has_flag("cant_attack"):
		return "%s can't attack in this form" % c.name()
	if bool(option["melee"]) and c.creature.has_flag("levitating") != target.creature.has_flag("levitating") \
			and (option["profile"] as WeaponProfile).reach < 20:
		return "Out of reach: one of you is floating 20 ft up (Levitate)"
	var charm := charm_blocks(c, target)
	if charm != "":
		return charm
	# A stat-block attack only some targets qualify for (a vampire's Bite: grappled, incapacitated or restrained).
	if c.creature is Monster and option.has("action_id"):
		var needs := ((c.creature as Monster).action(str(option["action_id"])).get("targets", {}) as Dictionary).get("requires", []) as Array
		if not needs.is_empty() and not needs.any(func(n: Variant) -> bool: return Legendary.meets(c, target, str(n))):
			return "%s must be %s" % [target.name(), " or ".join(needs.filter(func(n: Variant) -> bool: return str(n) != "willing").map(func(n: Variant) -> String: return str(n).capitalize()))]
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and item_count(c, p.item_id) <= 0:
		return "No %s left" % p.name.replace(" (thrown)", "")
	if c.creature is Character and option["kind"] in ["thrown", "weapon"] and not bool(option["melee"]):
		var w := (c.creature as Character).compendium.item_data(p.item_id)
		var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
		if ammo != "" and not _has_ammo(c, ammo, p.ammo_id):
			return "No ammunition"
	return ""


## False if `option` is a ranged weapon whose ammunition has run out.
func has_ammo_for(c: Combatant, option: Dictionary) -> bool:
	if not c.creature is Character or bool(option["melee"]) or str(option["kind"]) != "weapon":
		return true
	var w := (c.creature as Character).compendium.item_data((option["profile"] as WeaponProfile).item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	return ammo == "" or _has_ammo(c, ammo, (option["profile"] as WeaponProfile).ammo_id)


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


## Whether `c` carries ammunition of `ammo`'s kind (`specific`: that magic ammunition, "" = ordinary).
func _has_ammo(c: Combatant, ammo: String, specific: String = "") -> bool:
	var want := specific if specific != "" else str(Gear.AMMO_IDS.get(ammo, ammo))
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
	var duel := spells.specials.duel_disadvantage(c, target)
	if duel != "":
		dis.append(duel)
	class_features.attack_situation(c, target, option, adv, dis)
	for m in target.creature.modifiers_for(&"attacked_with"):
		if m.source_name == "Dodging" and (not can_see(target, c) or target.speed() <= 0):
			continue
		# Spellguard Shield: only spell attacks.
		if bool(m.data.get("spell_only", false)) and str(option.get("kind", "")) != "spell":
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
		var sharp := features.has_feat(c, "sharpshooter") and not str(option.get("kind", "")) in ["spell", "thrown"]
		if p.normal_range > 0 and dist > p.normal_range and not sharp:
			dis.append("long range")
		var melee_ok := sharp or (features.has_feat(c, "crossbow_expert") and p.item_id.contains("crossbow")) \
			or (str(option.get("kind", "")) == "spell" and features.has_feat(c, "spell_sniper"))
		for h in hostiles_of(c):
			if melee_ok:
				break
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
	if CombatFeatures.has_feature(c, "assassinate") and round_no == 1 and not target.has_acted:
		adv.append("Assassinate (it hasn't acted yet)")
	if features.has_feat(c, "grappler") and str(grapples.get(target.id, "")) == c.id:
		adv.append("Grappler")
	var dup := spells.zones.object_of(c.id, "invoke_duplicity")
	if dup != null and distance(c, target) <= 5 and grid.distance_ft(dup.cell, 1, target.cell, target.size_cells) <= 5:
		adv.append("Invoke Duplicity")
	for ally in allies_of(c):
		var dup2 := spells.zones.object_of(ally.id, "invoke_duplicity")
		if dup2 != null and CombatFeatures.has_feature(ally, "improved_duplicity") and grid.distance_ft(dup2.cell, 1, target.cell, target.size_cells) <= 5:
			adv.append("Improved Duplicity")
	if grapples.has(c.id) and str(grapples[c.id]) != target.id:
		dis.append("Grappled (attacking someone other than the grappler)")
	if c.hidden or not can_see(target, c):
		adv.append("target can't see you")
	if not can_see(c, target):
		dis.append("you can't see the target")
	if in_sunlight(c) and monster_actions.sunlight(c) != "":
		dis.append("Sunlight")
	if c.has_meta("attack_disadvantage"):
		dis.append("a severed part")
	for m in marks:
		if not _mark_applies(m, c, target):
			continue
		if str(m["kind"]) in ["advantage_against", "advantage_next_attack"]:
			adv.append(str(m["source"]))
		elif str(m["kind"]) in ["disadvantage_next_attack", "disadvantage_against"]:
			dis.append(str(m["source"]))
	# Goading Attack: Disadvantage on attacks against anyone but the Battle Master who goaded it.
	for m2 in c.creature.modifiers_for(&"flag"):
		var v := m2.text("value")
		if v.begins_with("goaded_by:") and v.substr(10) != target.id:
			dis.append("Goaded")
	# Elusive (Rogue 18): no Advantage against it while it isn't Incapacitated.
	if target.creature.has_flag("elusive") and target.can_act():
		adv.clear()
	var cov := cover(c, target)
	var degree := int(cov["cover"])
	var by := str(cov["by"])
	# Bulwark of Force: at least Half Cover.
	if target.creature.has_flag("half_cover") and degree < CombatGrid.Cover.HALF:
		degree = CombatGrid.Cover.HALF
		by = "Bulwark of Force"
	# Sharpshooter (weapons) and Spell Sniper (spell attacks) ignore Half and Three-Quarters Cover.
	var ranged_kind := str(option.get("kind", ""))
	if degree in [CombatGrid.Cover.HALF, CombatGrid.Cover.THREE_QUARTERS] and not melee and \
			((features.has_feat(c, "sharpshooter") and ranged_kind != "spell") or (features.has_feat(c, "spell_sniper") and ranged_kind == "spell")):
		degree = CombatGrid.Cover.NONE
		by = ""
	return {"advantage": adv, "disadvantage": dis, "cover": degree, "cover_bonus": CombatGrid.COVER_BONUS[degree],
		"cover_by": by}


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
		"disadvantage_against":
			var guard := get_c(str(m.get("guard", "")))
			return str(m["target"]) == target.id and guard != null and distance(guard, target) <= 5
		"advantage_against":
			if str(m["target"]) != target.id:
				return false
			if m.has("not_attacker") and str(m["not_attacker"]) == c.id:
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


## The attack itself, in stages that can pause for reactions (combat/reactions.gd): offers before the roll
## (Warding Flare, Protection, Lucky), the roll, ways to turn the attacker's miss into a hit (Heroic Inspiration,
## Precision Attack, Guided Strike), reactions that turn a hit into a miss (Shield, Defensive Duelist, Illusory
## Self), damage (Critical Hits, Sneak Attack and Cunning Strike, Great Weapon Fighting, Savage Attacker, riders the
## attacker armed), reactions against the damage (Uncanny Dodge, Parry, Interception...), defenses, Undead
## Fortitude, mastery properties and on-hit effects, then reactions to the damage (Hellish Rebuke) and Riposte.
func _resolve_attack(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary) -> CombatResult:
	var r := CombatResult.new()
	# Wind Wall: ordinary missiles shot across it are deflected upward and miss.
	if not bool(option["melee"]) and str(option.get("kind", "")) in ["weapon", "thrown", "monster"] and spells.zones.deflects_between(c, target):
		if c.creature is Character and str(option.get("kind", "")) == "weapon":
			_spend_ammo(c, option["profile"] as WeaponProfile)
		events.append({"type": "attack", "attacker": c.id, "target": target.id, "hit": false, "critical": false})
		r.lines.append(log.add("miss", "The Wind Wall deflects %s's shot at %s" % [c.name(), target.name()], c.id))
		return r
	var sit := attack_situation(c, target, option)
	_consume_marks(c, target)
	spells.specials.duel_check_attack(c, target)
	if c.hostile_to(target):
		class_features.kept_rage(c)
	spells.end_sanctuary(c, "attacked")
	spells.trigger_ends(c, "attack_roll")
	monster_actions.end_vanish(c)
	if c.hidden and not features.has_feat(c, "skulker"):
		reveal(c, "attacked")
	if bool(opts.get("reaction", false)) and features.has_feat(target, "speedy") and not bool(opts.get("readied", false)):
		(sit["disadvantage"] as Array[String]).append("Agile Movement")
	var st := {"c": c, "target": target, "option": option, "opts": opts, "sit": sit, "r": r,
		"ac": target.creature.ac_value() + int(sit["cover_bonus"])}
	var before := reactions.before_roll(st)
	before.append_array(items.before_roll(st))
	return reactions.offer(before, func() -> CombatResult: return _roll_attack(st), r)


func _roll_attack(st: Dictionary) -> CombatResult:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var sit := st["sit"] as Dictionary
	var r := st["r"] as CombatResult
	var p := option["profile"] as WeaponProfile
	var ac := int(st["ac"])
	var keys: Array[String] = ["attack", "attack:melee" if bool(option["melee"]) else "attack:ranged", "attack:%s" % p.ability]
	var label := "%s → %s (%s)" % [c.name(), target.name(), p.name]
	var t := c.creature.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, sit["advantage"] as Array[String],
		sit["disadvantage"] as Array[String], label, p.crit_range, attacked_dice(target))
	target.creature.consume_attacked()
	# Sundering Blow: the next attack by someone else against the creature gets +5.
	for m: Dictionary in marks.duplicate():
		if str(m["kind"]) == "attack_bonus_against" and str(m.get("target", "")) == target.id and str(m.get("not_by", "")) != c.id:
			t.add_bonus(int(m.get("bonus", 5)), str(m.get("source", "")))
			marks.erase(m)
			break
	if not option.get("melee", true) and c.creature is Character and not bool((st["opts"] as Dictionary).get("free_ammo", false)):
		if str(option.get("kind", "")) == "thrown":
			_spend_item(c, p.item_id)
		elif str(option.get("kind", "")) != "blade":
			_spend_ammo(c, p)
	st["t"] = t
	if t.success:
		return _attack_outcome(st)
	# Heroic Inspiration (2024): reroll a die right after rolling it.
	var chain: Array = []
	if c.creature is Character and (c.creature as Character).heroic_inspiration and c.is_player_controlled():
		chain.append({"kind": "heroic_inspiration", "reactor": c, "trigger": target.id, "title": "Heroic Inspiration?",
			"text": "%s misses %s: %d vs AC %d. Spend Heroic Inspiration to reroll the d20 and use the new roll?" % [c.name(), target.name(), t.total, ac],
			"cost": "Heroic Inspiration (regained on a Long Rest)",
			"use": func() -> void:
				(c.creature as Character).heroic_inspiration = false
				var t2 := c.creature.roll_d20(dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, sit["advantage"] as Array[String],
					sit["disadvantage"] as Array[String], label + " (Heroic Inspiration reroll)", p.crit_range)
				log.add("roll", "%s spends Heroic Inspiration to reroll: %d" % [c.name(), t2.total], c.id, [(st["t"] as D20Test).describe(), t2.describe()])
				st["t"] = t2})
	chain.append_array(reactions.after_miss_attacker(st))
	return reactions.offer(chain, func() -> CombatResult: return _attack_outcome(st), r)


func _attack_outcome(st: Dictionary) -> CombatResult:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var sit := st["sit"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
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
	critical = items.crit_allowed(c, target, critical, details)
	var success := t.success
	if success and mirror_image_takes(target, c, t.total):
		success = false
		critical = false
	st["critical"] = critical
	st["details"] = details
	if not success:
		return _attack_missed(st)
	var miss := func() -> CombatResult:
		r.lines.append(log.add("miss", "%s's attack on %s is turned aside (%d vs AC %d)" % [c.name(), target.name(), t.total, int(st["ac"])], target.id, details))
		events.append({"type": "attack", "attacker": c.id, "target": target.id, "hit": false, "critical": false, "edge": attack_edge(st["t"] as D20Test)})
		features.after_miss(c, target, option, r)
		return r
	var hit_offers := reactions.after_hit_target(st, miss)
	hit_offers.append_array(monster_actions.parry_offer(st, miss))
	return reactions.offer(hit_offers, func() -> CombatResult:
		events.append({"type": "attack", "attacker": c.id, "target": target.id, "hit": true, "critical": critical, "edge": attack_edge(st["t"] as D20Test)})
		return _after_hit(st), r)


## "advantage", "disadvantage" or "" for an attack roll, with the reasons (the view shows it over the attacker).
static func attack_edge(t: D20Test) -> Dictionary:
	if t == null:
		return {}
	if t.advantage:
		return {"kind": "advantage", "why": t.advantage_sources.duplicate()}
	if t.disadvantage:
		return {"kind": "disadvantage", "why": t.disadvantage_sources.duplicate()}
	return {}


func _attack_missed(st: Dictionary) -> CombatResult:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	events.append({"type": "attack", "attacker": c.id, "target": target.id, "hit": false, "critical": false, "edge": attack_edge(st["t"] as D20Test)})
	r.lines.append(log.add("miss", "%s misses %s (%d vs AC %d)" % [c.name(), target.name(), t.total, int(st["ac"])], c.id, st["details"] as Array))
	_on_miss(c, target, option, r)
	features.after_miss(c, target, option, r)
	items.after_miss(c, target, option, r)
	return reactions.offer(reactions.after_miss_target(st), func() -> CombatResult:
		if st.has("riposte"):
			var rp := st["riposte"] as Dictionary
			var by := rp["by"] as Combatant
			return _resolve_attack(by, c, rp["option"] as Dictionary, {"reaction": true,
				"extra_dice": [{"dice": "1d%d" % int(rp["die"]), "type": str(((rp["option"] as Dictionary)["profile"] as WeaponProfile).damage_type), "label": "Riposte"}]})
		return r, r)


func _after_hit(st: Dictionary) -> CombatResult:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var opts := st["opts"] as Dictionary
	var r := st["r"] as CombatResult
	var t := st["t"] as D20Test
	var critical := bool(st["critical"])
	var p := option["profile"] as WeaponProfile
	r.hit = true
	r.critical = critical
	if c.hidden and features.has_feat(c, "skulker"):
		reveal(c, "hit with an attack")
	var parts := {}
	var dmg_text: Array[String] = []
	var dice_list: Array[Dictionary] = [{"dice": p.damage_dice, "type": str(p.damage_type), "label": p.name, "weapon": true}]
	if c.creature is Monster:
		dice_list.append_array((c.creature as Monster).extra_damage_dice(str(option.get("action_id", ""))))
	var sneak := features.sneak_attack_dice(c, target, option, t)
	if sneak != "":
		sneak = features.cunning_strike_cost(c, sneak, st)
		if sneak != "":
			dice_list.append({"dice": sneak, "type": str(p.damage_type), "label": "Sneak Attack"})
		st["sneak"] = true
	for extra: Variant in opts.get("extra_dice", []):
		dice_list.append(extra as Dictionary)
	dice_list.append_array(features.hit_damage_dice(c, target, option, st))
	dice_list.append_array(items.hit_damage_dice(c, target, option, st))
	# A charge (giant elk, goat, boars, rhinoceros): extra or bigger damage after a straight run at the target.
	var charge := monster_actions.charge_of(c, target, option)
	if not charge.is_empty():
		c.set_meta("charged_vs", target.id)
		if bool(charge.get("replace", false)):
			st["replace_weapon_damage"] = true
		for cd: Variant in charge.get("damage", []):
			dice_list.append({"dice": str((cd as Dictionary)["dice"]), "type": str((cd as Dictionary)["type"]), "label": "Charge"})
	# Lightning Arrow: the bolt's damage instead of the weapon's.
	var replaced := bool(st.get("replace_weapon_damage", false))
	if replaced:
		dice_list.assign(dice_list.filter(func(x: Dictionary) -> bool: return not bool(x.get("weapon", false)) and str(x.get("label", "")) != "Sneak Attack"))
	# Extra damage on weapon and Unarmed Strike hits from spells (Crusader's Mantle, Enlarge) and features.
	for m in c.creature.modifiers_for(&"damage_penalty_die"):
		dice_list.append({"dice": m.text("dice", "1d8"), "type": str(p.damage_type), "label": m.source_name, "penalty": true})
	for m in c.creature.modifiers_for(&"extra_damage"):
		if m.data.has("vs") and str(m.data["vs"]) != target.id:
			continue
		var xt := spells.extra_damage_type(c, target, m, str(p.damage_type))
		if xt == "":
			continue
		dice_list.append({"dice": m.text("dice", "1d4"), "type": xt, "label": m.source_name,
			"penalty": bool(m.data.get("penalty", false))})
	var turn_key := "%d:%d" % [round_no, turn_index]
	var savage := c.creature.has_flag("savage_attacker") and str(_savage_turn.get(c.id, "")) != turn_key and c.creature is Character
	for entry in dice_list:
		var rolled := _roll_damage_dice(str(entry["dice"]), critical, p.die_minimum if bool(entry.get("weapon", false)) else 0,
			"%s damage" % entry["label"], features.damage_reroll_rule(c, p, entry))
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
	var bonus := 0 if replaced else p.damage_bonus.total() + features.flat_damage_bonus(c, target, option, st, dmg_text)
	if bool(opts.get("offhand", false)) and bonus > 0 and not c.creature.has_flag("two_weapon_fighting") \
			and not (features.has_feat(c, "crossbow_expert") and p.item_id == "hand_crossbow"):
		bonus = 0
		dmg_text.append("Light extra attack: no ability modifier to damage")
	if bool(opts.get("no_mod", false)) and bonus > 0:
		bonus = maxi(0, bonus - p.damage_bonus.total())
		dmg_text.append("No ability modifier to this damage")
	var primary := str(p.damage_type)
	if not replaced:
		parts[primary] = maxi(0, int(parts.get(primary, 0)) + bonus)
	if bonus != 0:
		dmg_text.append(p.damage_bonus.describe())
	var details := st["details"] as Array[String]
	var r2 := reactions.offer(reactions.against_damage(st, parts, dmg_text), func() -> CombatResult:
		return _apply_hit(st, parts, details, dmg_text), r)
	return r2


func _apply_hit(st: Dictionary, parts: Dictionary, details: Array[String], dmg_text: Array[String]) -> CombatResult:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var option := st["option"] as Dictionary
	var r := st["r"] as CombatResult
	var critical := bool(st["critical"])
	var arr: Array = []
	for k: String in parts:
		arr.append({"amount": int(parts[k]), "type": k, "weapon": true, "melee": bool(option["melee"]),
			"item": (option["profile"] as WeaponProfile).item_id, "ranged_weapon": str(option.get("kind", "")) in ["weapon", "thrown"] and not bool(option["melee"])})
	var all_details := details.duplicate()
	all_details.append_array(dmg_text)
	# Rampage (giant hyena) answers a hit on a creature that was already Bloodied.
	if c.creature is Monster and target.creature.is_bloodied():
		c.set_meta("hit_bloodied", "%d:%d" % [round_no, turn_index])
	var dr := deal_damage(c, target, arr, critical, (option["profile"] as WeaponProfile).name, all_details, true)
	r.damage = dr.final
	if target.is_down():
		r.killed.append(target.id)
	_on_hit_effects(c, target, option, dr, r)
	if bool(option["melee"]):
		retaliate(c, target)
		spells.specials.high.holy_aura_hit(c, target)
	features.after_hit(c, target, option, dr, st, r)
	items.after_hit(c, target, option, dr, st, r)
	_queue_sentinels(c, target)
	return run_reaction_queue(r)


## A melee hit on a creature wrapped in Armor of Agathys or Fire Shield: the attacker takes the spell's damage
## (`retaliate` modifiers: `value` or `dice`, `type`, `within` feet).
func retaliate(attacker: Combatant, target: Combatant) -> void:
	if attacker == null or not attacker.is_alive():
		return
	for m in target.creature.modifiers_for(&"retaliate"):
		if distance(attacker, target) > int(m.data.get("within", 5)):
			continue
		var amount := m.number("value") if m.data.has("value") else 0
		var text := "%d" % amount
		if m.data.has("dice"):
			var rolled := _roll_damage_dice(m.text("dice"), false, 0, m.source_name)
			amount += int(rolled["total"])
			text = str(rolled["text"])
		if amount > 0:
			deal_damage(target, attacker, [{"amount": amount, "type": m.text("type", "cold"), "spell": true}], false, m.source_name,
				["%s strikes back: %s" % [m.source_name, text]])


## Rolls damage dice (doubled on a Critical Hit; dice below `minimum` count as `minimum`).
## {total, text}
func _roll_damage_dice(expr: String, critical: bool, minimum: int, reason: String, reroll: Dictionary = {}) -> Dictionary:
	var parsed := DiceRoller.parse_expr(expr)
	var count := int(parsed["count"]) * (2 if critical else 1)
	var total := int(parsed["modifier"])
	var shown: Array[String] = []
	var rerolls_left := int(reroll.get("count", 0))
	if count > 0:
		for roll0 in dice.roll(int(parsed["sides"]), count, reason):
			var roll := roll0
			# Tavern Brawler, Piercer: reroll low damage dice (Piercer once per turn).
			if rerolls_left > 0 and roll <= int(reroll.get("at_most", 1)):
				rerolls_left -= 1
				roll = dice.roll_one(int(parsed["sides"]), "%s reroll" % reroll.get("source", ""))
				shown.append("%d↻" % roll0)
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
	target = monster_actions.redirect_shared(target)
	# Time Stop ends when the caster affects anyone else.
	if source != null and source != target:
		spells.specials.high.time_stop_broken(source, "it affected another creature")
	# Otiluke's Resilient Sphere: nothing passes through the globe either way.
	if source != null and spells.specials.sphere_blocks(source, target):
		log.add("info", "The sphere of force around %s turns the damage aside" % (target.name() if target.creature.has_flag("sphered") else source.name()), target.id)
		return DamageResult.new()
	parts = monster_actions.absorb(target, parts)
	var was_up := not target.is_down()
	if source != null and target.creature.has_flag("cursed_necrotic:%s" % source.id):
		var extra := _roll_damage_dice("1d8", false, 0, "Bestow Curse")
		parts = parts.duplicate()
		parts.append({"amount": int(extra["total"]), "type": "necrotic"})
		details = details.duplicate()
		details.append("Bestow Curse 1d8: %s" % extra["text"])
	parts = _reduce_by_dice(target, parts, details)
	parts = _bastion(target, parts, details)
	feature_actions.adjust_incoming(source, target, parts)
	items.adjust_incoming(source, target, parts, label)
	# Mage Slayer: creatures it damages have Disadvantage on the Concentration save.
	var slayer: Effect = null
	if source != null and features.has_feat(source, "mage_slayer") and target.creature.concentration != null:
		slayer = Effect.new("Mage Slayer", &"feature", "mage_slayer").with_modifier("disadvantage", {"on": "concentration"})
		target.creature.add_effect(slayer)
	var dr := target.creature.take_damage_parts(parts, critical, dice, label)
	if slayer != null:
		target.creature.remove_effect(slayer)
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
	# A shape (Polymorph, Wild Shape) that runs out: the real creature comes back with what's left.
	shapes.after_damage(target)
	# Gift of the Protectors: a party member drops to 1 instead of 0 once per Long Rest.
	if was_up and dr.dropped_to_zero and not target.creature.dead and class_features.gift_of_the_protectors(target):
		target.creature.hp = 1
		target.creature.remove_condition(&"unconscious", "0 Hit Points")
		dr.dropped_to_zero = false
	# Death Ward: the first drop to 0 Hit Points (or death outright from damage) leaves it at 1 instead.
	if was_up and (dr.dropped_to_zero or target.creature.dead) and target.creature.has_flag("death_ward"):
		for fxw: Effect in target.creature.effects.duplicate():
			if fxw.modifiers.any(func(m: Modifier) -> bool: return m.stat == &"flag" and m.text("value") == "death_ward"):
				target.creature.remove_effect(fxw)
		target.creature.dead = false
		target.creature.hp = 1
		target.creature.remove_condition(&"unconscious", "0 Hit Points")
		target.creature.death_failures = 0
		dr.dropped_to_zero = false
		dr.died = false
		dr.instant_death = false
		log.add("info", "Death Ward holds: %s stays up with 1 Hit Point" % target.name(), target.id)
	# Armor of Agathys ends once its Temporary Hit Points are gone.
	if target.creature.temp_hp <= 0:
		for fxa: Effect in target.creature.effects.duplicate():
			if bool(fxa.data.get("ends_without_temp_hp", false)):
				target.creature.remove_effect(fxa)
				log.add("info", "%s ends: no Temporary Hit Points left" % fxa.name, target.id)
	# Bosses (ADR 0014): Regeneration stopped by Radiant, a foe withdrawing at its threshold, Misty Escape at 0.
	var departed := legendary.after_damage(target, parts, dr, was_up)
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
	if was_up and target.is_down():
		class_features.on_drop(source, target)
		if rider_of(target) != null:
			dismount(rider_of(target), true, false)
		if mount_of(target) != null:
			var mt := mount_of(target)
			target.remove_meta("mounted_on")
			mt.remove_meta("ridden_by")
	if departed:
		pass
	elif target.creature.dead and was_up:
		monster_actions.death_burst(target)
		target.set_meta("died_round", round_no)
		log.add("death", "%s dies" % target.name(), target.id)
		events.append({"type": "death", "id": target.id})
		ravenloft.on_death(source, target)
		if target.has_meta("vanishes"):
			events.append({"type": "vanish", "id": target.id})
	elif dr.dropped_to_zero and not target.creature.dead and monster_actions.lycanthrope(target):
		pass
	elif dr.dropped_to_zero and not target.creature.dead and (feature_actions.on_zero(target) or ravenloft.on_zero(target, dr.final)):
		events.append({"type": "heal", "id": target.id, "amount": 1})
	elif dr.dropped_to_zero and not target.creature.dead:
		log.add("death", "%s falls unconscious" % target.name(), target.id)
		events.append({"type": "down", "id": target.id})
	if grapples.values().has(target.id) and (target.creature.has_flag("no_actions") or target.is_down()):
		_release_grapples_by(target)
	if target.is_down() or target.creature.has_flag("no_actions"):
		features.end_turning_from(target)
	if source != null and source != target and dr.final > 0:
		spells.end_sanctuary(source, "dealt damage")
	spells.on_damaged(source, target, dr.final, parts)
	items.on_damaged(source, target, dr.final, parts)
	if dr.final > 0:
		spells.specials.duel_check_damage(source, target)
	# Thought Shield (Great Old One 10): Psychic damage dealt to the warlock hits its source too.
	if source != null and source != target and dr.final > 0 and CombatFeatures.has_feature(target, "thought_shield") and not target.has_meta("reflecting"):
		var psy := 0
		for p: Variant in parts:
			if str((p as Dictionary)["type"]) == "psychic":
				psy += int((p as Dictionary)["amount"])
		if psy > 0:
			target.set_meta("reflecting", true)
			deal_damage(target, source, [{"amount": mini(psy, dr.final), "type": "psychic"}], false, "Thought Shield")
			target.remove_meta("reflecting")
	if dr.final > 0 and target.is_alive():
		monster_actions.loathsome_limbs(target, parts)
		monster_actions.damage_traits(target, parts)
	if target.is_down():
		monster_actions.body_dropped(target)
		spells.specials.mid.hand_destroyed(target)
	if dr.final > 0 and source != null and source != target and target.is_alive():
		_queue_damage_reactions(source, target)
	spells.zones.prune()
	_check_over()
	return dr


## Bastion of Law (Clockwork Sorcery): the ward's d8s soak damage, rolled one at a time until it's gone.
func _bastion(target: Combatant, parts: Array, details: Array) -> Array:
	var left := int(target.get_meta("bastion_dice", 0))
	if left <= 0:
		return parts
	var out: Array = []
	for p: Variant in parts:
		out.append((p as Dictionary).duplicate())
	for p2: Variant in out:
		var d := p2 as Dictionary
		while int(d["amount"]) > 0 and left > 0:
			var cut := dice.roll_one(8, "Bastion of Law")
			left -= 1
			d["amount"] = maxi(0, int(d["amount"]) - cut)
			details.append("Bastion of Law: −%d" % cut)
	if left <= 0:
		target.remove_meta("bastion_dice")
	else:
		target.set_meta("bastion_dice", left)
	return out


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


## Reactions to being damaged (Hellish Rebuke, Storm's Thunder) wait until the attack or spell that caused them has
## finished.
func _queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	ravenloft.queue_damage_reactions(source, target)
	# Berserk Lashing (Clay Construct Spirit): a Slam at a random creature within 5 ft whenever it takes damage.
	if target.creature is Monster and monster_actions.has_trait(target, "berserk_lashing") and spells.can_react(target) and target.creature.hp > 0:
		reaction_queue.append({"kind": "berserk_lashing", "reactor": target.id, "trigger": source.id})
		return
	if not target.creature is Character or target.creature.hp <= 0 or distance(target, source) > 60 or not can_see(target, source):
		return
	# Retaliation (Berserker 10): a melee attack back at a creature within 5 ft that hurt you.
	if CombatFeatures.has_feature(target, "retaliation") and spells.can_react(target) and distance(target, source) <= 5 and not best_melee_option(target, source).is_empty():
		reaction_queue.append({"kind": "retaliation", "reactor": target.id, "trigger": source.id})
		return
	var cfr := class_features.damage_reaction(source, target)
	if not cfr.is_empty():
		reaction_queue.append(cfr)
		return
	if target.creature.has_flag("fount_of_moonlight") and spells.can_react(target):
		reaction_queue.append({"kind": "fount_of_moonlight", "reactor": target.id, "trigger": source.id})
		return
	for q in reaction_queue:
		if str(q["reactor"]) == target.id:
			return
	if spells.can_cast_reaction(target, "hellish_rebuke"):
		reaction_queue.append({"kind": "hellish_rebuke", "reactor": target.id, "trigger": source.id})
	elif CombatFeatures.has_feature(target, "storms_thunder") and (target.creature as Character).resource_left("giant_ancestry") > 0 and spells.can_react(target):
		reaction_queue.append({"kind": "storms_thunder", "reactor": target.id, "trigger": source.id})


## Sentinel's Guardian: a creature within 5 ft of a Sentinel hits someone else: an Opportunity Attack against it.
func _queue_sentinels(attacker: Combatant, target: Combatant) -> void:
	for p in hostiles_of(attacker):
		if p == target or not features.has_feat(p, "sentinel") or not spells.can_react(p) or distance(p, attacker) > 5:
			continue
		reaction_queue.append({"kind": "sentinel", "reactor": p.id, "trigger": attacker.id})


func _queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	if str(q["kind"]).begins_with("rh_"):
		return ravenloft.queued_ok(q, reactor)
	match str(q["kind"]):
		"hellish_rebuke":
			return spells.can_cast_reaction(reactor, "hellish_rebuke")
		"storms_thunder":
			return spells.can_react(reactor) and (reactor.creature as Character).resource_left("giant_ancestry") > 0
		"sentinel":
			return spells.can_react(reactor) and not best_melee_option(reactor, null).is_empty()
		"berserk_lashing":
			return spells.can_react(reactor) and reactor.creature.hp > 0
		"fount_of_moonlight":
			return spells.can_react(reactor) and reactor.creature.has_flag("fount_of_moonlight")
		"misty_escape":
			return spells.can_react(reactor) and reactor.creature.hp > 0
		"retaliation":
			return spells.can_react(reactor) and reactor.creature.hp > 0 and get_c(str(q["trigger"])) != null and distance(reactor, get_c(str(q["trigger"]))) <= 5
	return false


func _fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	if str(q["kind"]).begins_with("rh_"):
		return ravenloft.fire_queued(q, reactor, trigger)
	match str(q["kind"]):
		"hellish_rebuke":
			return spells.cast_reaction_spell(reactor, "hellish_rebuke", trigger)
		"storms_thunder":
			reactor.reaction_available = false
			(reactor.creature as Character).spend_resource("giant_ancestry")
			var rolled := _roll_damage_dice("1d8", false, 0, "Storm's Thunder")
			deal_damage(reactor, trigger, [{"amount": int(rolled["total"]), "type": "thunder"}], false, "Storm's Thunder", [str(rolled["text"])])
			return CombatResult.new()
		"sentinel":
			if distance(reactor, trigger) > reactor.reach_ft():
				return CombatResult.new()
			return _opportunity_attack(reactor, trigger)
		"misty_escape":
			return class_features.misty_escape(reactor, trigger)
		"retaliation":
			return _opportunity_attack(reactor, trigger)
		"fount_of_moonlight":
			reactor.reaction_available = false
			var dc := (spells.numbers(reactor, spells._entry_any(reactor, "fount_of_moonlight"))["dc"] as Breakdown).total()
			var sv := trigger.creature.roll_save(dice, &"con", dc, [], [], "Constitution save vs Fount of Moonlight (%s)" % trigger.name())
			if sv.success:
				log.add("info", "%s shrugs off the flare of moonlight" % trigger.name(), trigger.id, [sv.describe()])
			else:
				var fx := Effect.new("Blinded (Fount of Moonlight)", &"spell", "fount_of_moonlight").with_condition(&"blinded")
				fx.caster_id = reactor.id
				fx.ends = Effect.Ends.END_OF_TURN
				fx.turn_owner_id = reactor.id
				fx.skip_turn_ends = own_turn_skip(reactor)
				trigger.creature.add_effect(fx)
				log.add("condition", "%s is Blinded by moonlight" % trigger.name(), trigger.id, [sv.describe()])
				events.append({"type": "condition", "id": trigger.id})
			return CombatResult.new()
		"berserk_lashing":
			var near: Array[Combatant] = []
			for o in living():
				if o != reactor and not o.is_down() and distance(reactor, o) <= 5:
					near.append(o)
			reactor.reaction_available = false
			if near.is_empty():
				log.add("info", "%s lashes out at no one" % reactor.name(), reactor.id)
				return CombatResult.new()
			var victim := near[dice.roll_one(near.size(), "Berserk Lashing target") - 1]
			log.add("info", "%s lashes out in a frenzy at %s (Berserk Lashing)" % [reactor.name(), victim.name()], reactor.id)
			return _resolve_attack(reactor, victim, option_by_id(reactor, "monster:slam"), {"reaction": true})
	return CombatResult.new()


const _QUEUED_TEXT := {
	"hellish_rebuke": ["Reaction: Hellish Rebuke?", "%s hurt %s. Answer with Hellish Rebuke: a Dex save or Fire damage.", "Reaction and a spell slot"],
	"storms_thunder": ["Reaction: Storm's Thunder?", "%s hurt %s. Answer with 1d8 Thunder damage.", "Reaction and a use of Giant Ancestry"],
	"sentinel": ["Reaction: Sentinel?", "%s attacks someone beside %s. Make an Opportunity Attack against it?", "Reaction"],
	"retaliation": ["Reaction: Retaliation?", "%s hurt %s. Strike back with a melee attack?", "Reaction"],
	"misty_escape": ["Reaction: Misty Escape?", "%s hurt %s. Vanish with Misty Step (Steps of the Fey or a slot)?", "Reaction and a use of Steps of the Fey"],
	"fount_of_moonlight": ["Reaction: Fount of Moonlight?", "%s hurt %s. Flare moonlight at it: a Constitution save or Blinded?", "Reaction"],
	"berserk_lashing": ["Reaction: Berserk Lashing?", "%s hurt %s. Lash out with a Slam at a random creature within 5 ft?", "Reaction"],
}


## Offers the queued reactions one by one (asking the player, or the AI deciding), then the queued Cleave attacks,
## then returns `r`.
func run_reaction_queue(r: CombatResult) -> CombatResult:
	while not reaction_queue.is_empty():
		var q := reaction_queue.pop_front() as Dictionary
		var reactor := get_c(str(q["reactor"]))
		var trigger := get_c(str(q["trigger"]))
		if reactor == null or trigger == null or not trigger.is_alive() or not _queued_ok(q, reactor):
			continue
		var kind := str(q["kind"])
		var decision := _reaction_decision(reactor, kind)
		if decision == "never":
			continue
		var fire := func() -> CombatResult: return _fire_queued(q, reactor, trigger)
		if decision == "auto":
			var sub := fire.call() as CombatResult
			if pending != null:
				return then(sub, func() -> CombatResult: return run_reaction_queue(r))
			continue
		var words := ravenloft.queued_text(kind) if kind.begins_with("rh_") else _QUEUED_TEXT[kind] as Array
		var req := ReactionRequest.new(kind, reactor.id, trigger.id)
		req.title = str(words[0])
		req.text = str(words[1]) % [trigger.name(), reactor.name()]
		req.cost = str(words[2])
		req.continuation = func(use: bool) -> CombatResult:
			if use:
				return then(fire.call() as CombatResult, func() -> CombatResult: return run_reaction_queue(r))
			return run_reaction_queue(r)
		pending = req
		r.pending = req
		return r
	while not cleave_queue.is_empty():
		var cq := cleave_queue.pop_front() as Dictionary
		var cc := cq["c"] as Combatant
		var ct := cq["target"] as Combatant
		if ct.is_alive() and not ct.is_down() and cc.can_act():
			var sub2 := _resolve_attack(cc, ct, cq["option"] as Dictionary, {"cleave": true, "no_mod": true})
			if pending != null:
				return then(sub2, func() -> CombatResult: return run_reaction_queue(r))
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
		if act.has("on_hit"):
			monster_actions.apply_riders(c, target, act["on_hit"] as Array, {str(p.damage_type): dr.final}, str(act.get("name", "")))
		if str(c.get_meta("charged_vs", "")) == target.id and act.has("charge"):
			monster_actions.apply_riders(c, target, (act["charge"] as Dictionary).get("on_hit", []) as Array, {}, "%s (charge)" % act.get("name", ""))
		# Celestial Spirit (Defender): a creature within 10 ft gains Temporary Hit Points.
		if act.has("ally_temp_hp"):
			var ath := act["ally_temp_hp"] as Dictionary
			var best: Combatant = null
			for a2 in allies_of(c):
				if a2 != c and a2.is_alive() and distance(c, a2) <= int(ath.get("range", 10)) and (best == null or a2.creature.temp_hp < best.creature.temp_hp):
					best = a2
			if best == null:
				best = c
			var amt := int(_roll_damage_dice(str(ath.get("dice", "1d10")), false, 0, "Radiant Mace")["total"])
			if best.creature.add_temp_hp(amt, str(act.get("name", ""))):
				log.add("heal", "%s gains %d Temporary Hit Points (%s)" % [best.name(), amt, act.get("name", "")], best.id)


func _spend_ammo(c: Combatant, p: WeaponProfile) -> void:
	var ch := c.creature as Character
	var w := ch.compendium.item_data(p.item_id)
	var ammo := str((w.get("weapon", {}) as Dictionary).get("ammunition", ""))
	if ammo == "":
		return
	var want := p.ammo_id if p.ammo_id != "" else str(Gear.AMMO_IDS.get(ammo, ammo))
	for e in ch.inventory:
		if str(e["id"]) == want and int(e["qty"]) > 0:
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
	var extra := c.speed() + (10 if features.has_feat(c, "charger") else 0)
	c.movement_left += extra
	log.add("info", "%s takes the Dash action (+%d ft)" % [c.name(), extra], c.id)
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
	var t := c.creature.roll_check(dice, &"perception", 0, [], [], "", ["search"])
	var found: Array[String] = []
	# Cloak of Elvenkind: Perception to find its wearer has Disadvantage (a second roll, the lower kept, for them).
	var t_hard: D20Test = null
	for h0 in hostiles_of(c):
		if h0.hidden and h0.creature.has_flag("hard_to_perceive") and t_hard == null:
			t_hard = c.creature.roll_check(dice, &"perception", 0, [], ["Cloak of Elvenkind"])
	for h in hostiles_of(c):
		var total := t.total if not (h.creature.has_flag("hard_to_perceive") and t_hard != null) else mini(t.total, t_hard.total)
		if h.hidden and total >= h.stealth_total:
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
	var t := c.creature.roll_check(dice, skill, dc, [], [], "", ["study"])
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
	if c.has_meta("escape_dc"):
		dc = int(c.get_meta("escape_dc"))
	var skill := &"athletics" if c.creature.skill_bonus(&"athletics").total() >= c.creature.skill_bonus(&"acrobatics").total() else &"acrobatics"
	var t := c.creature.roll_check(dice, skill, dc)
	if t.success:
		grapples.erase(c.id)
		c.creature.remove_condition(&"grappled")
		c.remove_meta("escape_dc")
		monster_actions.release_engulf(c)
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
				if t.has_meta("escape_dc"):
					t.remove_meta("escape_dc")
				monster_actions.release_engulf(t)


## Drains scene events (moves, attacks, damage, turns) for animation.
func drain_events() -> Array[Dictionary]:
	spells.zones.prune()
	var out := events.duplicate()
	events.clear()
	return out
