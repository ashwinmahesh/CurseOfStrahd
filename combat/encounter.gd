class_name Encounter
extends RefCounted
## A fight on the grid (plan §5.3, ADR 0007): initiative and turns under the 2024 action economy, movement with
## Opportunity Attacks, attacks with every Advantage source and cover, reactions that pause for the player's
## choice, the standard actions, and the combat log. Pure logic with no nodes: the scene animates `events`, the
## HUD reads state and the log, and AiBrain drives enemies and neutrals. Spells live in SpellCaster and class
## features in CombatFeatures.
##
## The Encounter holds the fight's state. Its jobs live in helpers, a file each, that it makes and owns:
## EncounterTurns, EncounterSight, EncounterMovement, EncounterMounts, EncounterGrapples, EncounterWeapons,
## EncounterAttacks, EncounterDamage, EncounterReactions and EncounterActions (combat/encounter_*.gd). The forwarding
## functions at the end are the Encounter's interface, so the HUD, the AI, spells and features keep calling it.

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
var damage_responses: DamageResponses
var feature_recipes: FeatureRecipes
var monster_actions: MonsterActions
var ai: AiBrain
var shapes: ShapeChange
## A place where even allies can't pass through each other (a location's or fight's `allies_block`).
var allies_block := false
var class_features: ClassFeatures
## Ravenloft: The Horrors Within options (combat/ravenloft_features.gd).
var triggered_features: TriggeredFeatures
var ravenloft: RavenloftFeatures
## Heroes of Faerûn and Arcana Unleashed options that need their own code (combat/faerun_features.gd).
var faerun: FaerunFeatures
## The Echo Knight's echoes, and attacks from their spaces (combat/echo_knight.gd).
var echo_knight: EchoKnight
## The attack whose damage is being dealt right now: {attacker, target, melee} (Zhentarim Tactics answers a melee hit).
var hit_context: Dictionary = {}
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
## The fight's jobs, a helper each (made first in _init: the other helpers may call them while they're being made).
var turns: EncounterTurns
var sight: EncounterSight
var movement: EncounterMovement
var mounts: EncounterMounts
var grappling: EncounterGrapples
var weapons: EncounterWeapons
var attacks: EncounterAttacks
var damage: EncounterDamage
var reaction_flow: EncounterReactions
var actions: EncounterActions


func _init(grid_: CombatGrid, dice_: DiceRoller) -> void:
	grid = grid_
	dice = dice_
	turns = EncounterTurns.new(self)
	sight = EncounterSight.new(self)
	movement = EncounterMovement.new(self)
	mounts = EncounterMounts.new(self)
	grappling = EncounterGrapples.new(self)
	weapons = EncounterWeapons.new(self)
	attacks = EncounterAttacks.new(self)
	damage = EncounterDamage.new(self)
	reaction_flow = EncounterReactions.new(self)
	actions = EncounterActions.new(self)
	spells = SpellCaster.new(self)
	features = CombatFeatures.new(self)
	reactions = Reactions.new(self)
	feature_actions = FeatureActions.new(self)
	feature_recipes = FeatureRecipes.new(self)
	damage_responses = DamageResponses.new(self)
	monster_actions = MonsterActions.new(self)
	ai = AiBrain.new(self)
	shapes = ShapeChange.new(self)
	class_features = ClassFeatures.new(self)
	ravenloft = RavenloftFeatures.new(self)
	faerun = FaerunFeatures.new(self)
	echo_knight = EchoKnight.new(self)
	triggered_features = TriggeredFeatures.new(self)
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
	creature.effect_added = _effect_added
	combatants.append(c)
	return c


func _effect_added(cr: Creature, fx: Effect) -> void:
	faerun.effect_added(cr, fx)
	echo_knight.effect_added(cr, fx)


func get_c(id: String) -> Combatant:
	for c in combatants:
		if c.id == id:
			return c
	return null


func current() -> Combatant:
	return order[turn_index] if turn_index >= 0 and turn_index < order.size() else null


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


## An Echo Knight's echo is an image, not an ally (no Pack Tactics, Sneak Attack, auras or healing picks).
func allies_of(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in combatants:
		if o != c and o.is_alive() and c.allied_with(o) and not EchoKnight.is_echo(o):
			out.append(o)
	return out


func occupant_at(cell: Vector2i) -> Combatant:
	for c in combatants:
		if c.is_alive() and cell in c.footprint():
			return c
	return null


func distance(a: Combatant, b: Combatant) -> int:
	return grid.distance_ft(a.cell, a.size_cells, b.cell, b.size_cells)


## Whether this fight is at `place`: its location, or a place inside it.
func at_place(place: String) -> bool:
	return place != "" and (place == location_id or place in places)


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


func is_over() -> bool:
	return state == State.OVER


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


# --- Carrying on after a reaction prompt ----------------------------------------------------------


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


# --- For the scene --------------------------------------------------------------------------------


## Drains scene events (moves, attacks, damage, turns) for animation.
func drain_events() -> Array[Dictionary]:
	spells.zones.prune()
	var out := events.duplicate()
	events.clear()
	return out


# --- Turns (EncounterTurns) -----------------------------------------------------------------------

func start(surprised_ids: Array = []) -> void:
	turns.start(surprised_ids)


func _begin_turn() -> void:
	turns._begin_turn()


func end_turn() -> CombatResult:
	return turns.end_turn()


func _lair_then_begin() -> void:
	turns._lair_then_begin()


func _check_over() -> void:
	turns._check_over()


func compelled(c: Combatant) -> bool:
	return turns.compelled(c)


func run_ai_turn() -> CombatResult:
	return turns.run_ai_turn()


func _turn_check(c: Combatant) -> String:
	return turns._turn_check(c)


func _action_check(c: Combatant) -> String:
	return turns._action_check(c)


func features_attack_why(c: Combatant) -> String:
	return turns.features_attack_why(c)


func use_one_attack(c: Combatant) -> void:
	turns.use_one_attack(c)


func spend_action(c: Combatant) -> void:
	turns.spend_action(c)


func _bonus_check(c: Combatant) -> String:
	return turns._bonus_check(c)


# --- Sight, light and cover (EncounterSight) ------------------------------------------------------

func creature_cells(exclude: Array = []) -> Dictionary:
	return sight.creature_cells(exclude)


func cover(attacker: Combatant, target: Combatant) -> Dictionary:
	return sight.cover(attacker, target)


func can_see_space(a: Combatant, cell: Vector2i, size: int = 1) -> bool:
	return sight.can_see_space(a, cell, size)


func can_see(a: Combatant, b: Combatant) -> bool:
	return sight.can_see(a, b)


func light_at(cell: Vector2i) -> String:
	return sight.light_at(cell)


func in_sunlight(c: Combatant) -> bool:
	return sight.in_sunlight(c)


# --- Movement (EncounterMovement) -----------------------------------------------------------------

func space_available(cell: Vector2i, size: int, except: Array = []) -> bool:
	return movement.space_available(cell, size, except)


func in_running_water(c: Combatant) -> bool:
	return movement.in_running_water(c)


func reachable_for(c: Combatant, budget: int = -1, standing: bool = false) -> Dictionary:
	return movement.reachable_for(c, budget, standing)


func move_mode(c: Combatant) -> int:
	return movement.move_mode(c)


func fear_sources(c: Combatant) -> Array[Combatant]:
	return movement.fear_sources(c)


func move(c: Combatant, dest: Vector2i) -> CombatResult:
	return movement.move(c, dest)


func march(c: Combatant, dir: Vector2, feet: int, r: CombatResult) -> CombatResult:
	return movement.march(c, dir, feet, r)


func flee(c: Combatant, away: Combatant, feet: int, r: CombatResult) -> CombatResult:
	return movement.flee(c, away, feet, r)


func _walk(c: Combatant, path: Array[Vector2i], i: int, r: CombatResult, handled: Dictionary) -> CombatResult:
	return movement._walk(c, path, i, r, handled)


func _provokers(mover: Combatant, from: Vector2i, to: Vector2i) -> Array[Combatant]:
	return movement._provokers(mover, from, to)


func _after_step(c: Combatant, from: Vector2i) -> void:
	movement._after_step(c, from)


func stand_up(c: Combatant) -> CombatResult:
	return movement.stand_up(c)


func free_move(c: Combatant, dest: Vector2i) -> CombatResult:
	return movement.free_move(c, dest)


func reaction_move(c: Combatant, dest: Vector2i) -> CombatResult:
	return movement.reaction_move(c, dest)


func jump(c: Combatant, dest: Vector2i) -> CombatResult:
	return movement.jump(c, dest)


func drop_prone(c: Combatant) -> CombatResult:
	return movement.drop_prone(c)


func forced_move(target: Combatant, origin: Vector2, feet: int, toward: bool = false) -> int:
	return movement.forced_move(target, origin, feet, toward)


func center_of(c: Combatant) -> Vector2:
	return movement.center_of(c)


# --- Mounted combat (EncounterMounts) -------------------------------------------------------------

func mount_of(c: Combatant) -> Combatant:
	return mounts.mount_of(c)


func rider_of(c: Combatant) -> Combatant:
	return mounts.rider_of(c)


func mount_why(rider: Combatant, steed: Combatant) -> String:
	return mounts.mount_why(rider, steed)


func mount(rider: Combatant, steed: Combatant) -> CombatResult:
	return mounts.mount(rider, steed)


func dismount(rider: Combatant, prone: bool = false, voluntary: bool = true) -> CombatResult:
	return mounts.dismount(rider, prone, voluntary)


func controlled_mount(rider: Combatant) -> Combatant:
	return mounts.controlled_mount(rider)


# --- Grapple and Shove (EncounterGrapples) --------------------------------------------------------

func unarmed_special(c: Combatant, target: Combatant, mode: String) -> CombatResult:
	return grappling.unarmed_special(c, target, mode)


func escape_grapple(c: Combatant) -> CombatResult:
	return grappling.escape_grapple(c)


func _release_grapples_by(grappler: Combatant) -> void:
	grappling._release_grapples_by(grappler)


# --- Weapons and attack options (EncounterWeapons) ------------------------------------------------

func charm_blocks(c: Combatant, t: Combatant) -> String:
	return weapons.charm_blocks(c, t)


func attack_options(c: Combatant) -> Array[Dictionary]:
	return weapons.attack_options(c)


func option_by_id(c: Combatant, option_id: String) -> Dictionary:
	return weapons.option_by_id(c, option_id)


func best_melee_option(c: Combatant, _target: Combatant) -> Dictionary:
	return weapons.best_melee_option(c, _target)


func attacks_per_action(c: Combatant) -> int:
	return weapons.attacks_per_action(c)


func attack_legal(c: Combatant, target: Combatant, option: Dictionary) -> String:
	return weapons.attack_legal(c, target, option)


func has_ammo_for(c: Combatant, option: Dictionary) -> bool:
	return weapons.has_ammo_for(c, option)


func item_count(c: Combatant, item_id: String) -> int:
	return weapons.item_count(c, item_id)


# --- Attacks (EncounterAttacks) -------------------------------------------------------------------

func mirror_image_takes(t: Combatant, attacker: Combatant, _total: int) -> bool:
	return attacks.mirror_image_takes(t, attacker, _total)


func _opportunity_attack(p: Combatant, target: Combatant) -> CombatResult:
	return attacks._opportunity_attack(p, target)


func attack(c: Combatant, target: Combatant, option_id: String, opts: Dictionary = {}) -> CombatResult:
	return attacks.attack(c, target, option_id, opts)


func offhand_attack(c: Combatant, target: Combatant, option_id: String) -> CombatResult:
	return attacks.offhand_attack(c, target, option_id)


func attack_situation(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	return attacks.attack_situation(c, target, option)


func attacked_dice(target: Combatant) -> Array:
	return attacks.attacked_dice(target)


func _consume_marks(c: Combatant, target: Combatant) -> void:
	attacks._consume_marks(c, target)


func hit_chance(c: Combatant, target: Combatant, option: Dictionary) -> Dictionary:
	return attacks.hit_chance(c, target, option)


func _resolve_attack(c: Combatant, target: Combatant, option: Dictionary, opts: Dictionary) -> CombatResult:
	return attacks._resolve_attack(c, target, option, opts)


static func attack_edge(t: D20Test) -> Dictionary:
	return EncounterAttacks.attack_edge(t)


func _after_hit(st: Dictionary) -> CombatResult:
	return attacks._after_hit(st)


func retaliate(attacker: Combatant, target: Combatant) -> void:
	attacks.retaliate(attacker, target)


func monster_attack(c: Combatant, target: Combatant, action_id: String) -> CombatResult:
	return attacks.monster_attack(c, target, action_id)


func begin_multiattack(c: Combatant) -> Array[Dictionary]:
	return attacks.begin_multiattack(c)


# --- Damage, healing and dying (EncounterDamage) --------------------------------------------------

func death_save(c: Combatant) -> CombatResult:
	return damage.death_save(c)


func needs_death_save(c: Combatant) -> bool:
	return damage.needs_death_save(c)


func stabilize(c: Combatant, target: Combatant, use_kit: bool) -> CombatResult:
	return damage.stabilize(c, target, use_kit)


func _roll_damage_dice(expr: String, critical: bool, minimum: int, reason: String, reroll: Dictionary = {}) -> Dictionary:
	return damage._roll_damage_dice(expr, critical, minimum, reason, reroll)


func _max_damage_dice(expr: String, critical: bool) -> Dictionary:
	return damage._max_damage_dice(expr, critical)


func heal_roll(expr: String, t: Combatant, reason: String, reroll: Dictionary = {}) -> Dictionary:
	return damage.heal_roll(expr, t, reason, reroll)


func heal_floor(t: Combatant) -> int:
	return damage.heal_floor(t)


func deal_damage(source: Combatant, target: Combatant, parts: Array, critical: bool, label: String, details: Array = [], log_it: bool = true, responses_resolved: Array = []) -> DamageResult:
	return damage.deal_damage(source, target, parts, critical, label, details, log_it, responses_resolved)


# --- Reaction prompts and the reaction queue (EncounterReactions) ---------------------------------

func _reaction_decision(reactor: Combatant, kind: String) -> String:
	return reaction_flow._reaction_decision(reactor, kind)


func answer_reaction(use: bool) -> CombatResult:
	return reaction_flow.answer_reaction(use)


func run_reaction_queue(r: CombatResult) -> CombatResult:
	return reaction_flow.run_reaction_queue(r)


# --- Standard actions (EncounterActions) ----------------------------------------------------------

func ready_attack(c: Combatant, option_id: String) -> CombatResult:
	return actions.ready_attack(c, option_id)


func ready_spell(c: Combatant, spell_id: String, slot: int) -> CombatResult:
	return actions.ready_spell(c, spell_id, slot)


func use_item(c: Combatant, item_id: String, target: Combatant) -> CombatResult:
	return actions.use_item(c, item_id, target)


func has_kit(c: Combatant) -> bool:
	return actions.has_kit(c)


func _check_still_hidden(c: Combatant) -> void:
	actions._check_still_hidden(c)


func reveal(c: Combatant, why: String) -> void:
	actions.reveal(c, why)


func escape_effect(c: Combatant, effect_id: int) -> CombatResult:
	return actions.escape_effect(c, effect_id)


func douse(c: Combatant) -> CombatResult:
	return actions.douse(c)


func sleeper(c: Combatant) -> Effect:
	return actions.sleeper(c)


func wake(c: Combatant, t: Combatant) -> CombatResult:
	return actions.wake(c, t)


func haste_action_use(c: Combatant, what: String, target: Combatant, option_id: String) -> CombatResult:
	return actions.haste_action_use(c, what, target, option_id)


func dash(c: Combatant, use_bonus: bool = false) -> CombatResult:
	return actions.dash(c, use_bonus)


func disengage(c: Combatant, use_bonus: bool = false) -> CombatResult:
	return actions.disengage(c, use_bonus)


func dodge(c: Combatant) -> CombatResult:
	return actions.dodge(c)


func apply_dodge(c: Combatant) -> void:
	actions.apply_dodge(c)


func help_attack(c: Combatant, enemy: Combatant) -> CombatResult:
	return actions.help_attack(c, enemy)


func hide(c: Combatant, use_bonus: bool = false) -> CombatResult:
	return actions.hide(c, use_bonus)


func hide_blocker(c: Combatant) -> String:
	return actions.hide_blocker(c)


func search(c: Combatant) -> CombatResult:
	return actions.search(c)


func study(c: Combatant, target: Combatant) -> CombatResult:
	return actions.study(c, target)


func can_disengage(c: Combatant) -> bool:
	return actions.can_disengage(c)
