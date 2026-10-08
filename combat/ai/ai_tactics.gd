class_name AiTactics
extends RefCounted
## How the enemy AI fights at the playthrough's difficulty (combat/difficulty.gd, F1). AiBrain asks it while it
## scores attacks and before it plans a turn; at Balanced ("standard") it changes nothing.
##   kind (Story):        spreads its blows: a foe already struck this round is worth less, and no killing-blow bonus.
##   sharp (Tactician):   focus fire on the hurt, on a foe its side is already on, on concentrating casters and healers.
##   ruthless (Honour):   sharp, and a cruel foe (evil, Intelligence 6 or more) strikes a hero at 0 Hit Points when
##                        that's its best move (each hit is a failed Death Saving Throw, two from within 5 ft).
## With the mode's kit, an armed foe drinks its Potion of Healing when Bloodied (a Bonus Action); badly hurt and in
## reach of a foe, it Disengages and steps away first. With morale, when its side breaks (half of it down, or its
## leader fallen) a foe that isn't mindless, fearless or a boss flees, and leaves the fight once well away. In every
## mode, a Bloodied humanoid that speaks a language surrenders instead when its side breaks (F13, story/captives.gd).

const POTION := "potion_of_healing"
## How far from every standing foe a fleeing creature must get to leave the fight (ft).
const ESCAPE_FT := 30

var _enc: WeakRef
## Attacks the AI made this round on each target: target id -> count.
var _struck: Dictionary = {}
var _struck_round: int = -1
## Each side as it first fought: side -> {ids: [...], leader: id or ""}.
var _sides: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func mode() -> String:
	return enc().difficulty.tactics


# --- Choosing targets ---------------------------------------------------------------------------------------------

## Notes an AI attack on `t` this round (for spreading or focusing blows).
func note_strike(t: Combatant) -> void:
	var e := enc()
	if _struck_round != e.round_no:
		_struck_round = e.round_no
		_struck.clear()
	_struck[t.id] = int(_struck.get(t.id, 0)) + 1


func struck(t: Combatant) -> int:
	return int(_struck.get(t.id, 0)) if _struck_round == enc().round_no else 0


## How much of the killing-blow bonus counts (none when the AI spreads its blows).
func finish_scale() -> float:
	return 0.0 if mode() == "kind" else 1.0


## Extra score for an attack on `t` worth `expected` damage.
func target_adjust(t: Combatant, expected: float) -> float:
	match mode():
		"kind":
			return -0.5 * expected * struck(t)
		"sharp", "ruthless":
			var hurt := 1.0 - float(t.creature.hp) / maxf(1.0, float(t.creature.max_hp()))
			var bonus := 0.5 * expected * hurt + 0.5 * struck(t)
			if t.creature.concentration != null:
				bonus += 2.0
			if healer(t):
				bonus += 1.5
			return bonus
	return 0.0


## A party member who can bring others back up: a cleric, druid, bard or paladin.
static func healer(t: Combatant) -> bool:
	var ch := t.creature as Character if t.creature is Character else null
	if ch == null:
		return false
	for cls: String in ["cleric", "druid", "bard", "paladin"]:
		if ch.class_level_of(cls) > 0:
			return true
	return false


## A foe that strikes the fallen at Honour: evil, with Intelligence 6 or more.
static func cruel(c: Combatant) -> bool:
	if not c.creature is Monster:
		return false
	var m := c.creature as Monster
	return "evil" in str(m.data.get("alignment", "")) and m.ability_score(&"int") >= 6


## Honour's strike at a hero on 0 Hit Points, as an attack plan to weigh against the others: {kind: attack, target,
## cell, option, score, why, finish: true} or {}.
func fallen_plan(c: Combatant, options: Array[Dictionary], reach: Dictionary, threats: Array[Dictionary], oa_fear: float) -> Dictionary:
	var e := enc()
	if mode() != "ruthless" or not cruel(c):
		return {}
	var best := {}
	var best_s := 0.0
	for t in e.hostiles_of(c):
		if not t.is_alive() or t.creature.hp > 0 or not t.creature.uses_death_saves or not e.can_see(c, t):
			continue
		for o in options:
			var p := o["profile"] as WeaponProfile
			var melee := bool(o["melee"])
			var max_d := p.reach if melee else (p.long_range if p.long_range > 0 else p.normal_range)
			for cell: Vector2i in _cells_in_reach(c, t, max_d, reach):
				var keep := c.cell
				c.cell = cell
				var chance := float(e.hit_chance(c, t, o)["chance"])
				var close := e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells) <= 5
				c.cell = keep
				var fails := 2 if close else 1
				var value := 9.0 if t.creature.death_failures + fails >= 3 else 4.0 * fails
				var s := chance * value + e.ai.boss.target_bonus(c, t)
				if cell != c.cell and oa_fear > 0.0:
					s -= oa_fear * e.ai._oa_risk(c, CombatGrid.path_to(reach, cell), threats)
				if s > best_s:
					best_s = s
					best = {"kind": "attack", "target": t, "cell": cell, "option": str(o["id"]), "score": s,
						"finish": true, "why": "finishing %s with %s" % [t.name(), p.name]}
	return best


func _cells_in_reach(c: Combatant, t: Combatant, max_d: int, reach: Dictionary) -> Array[Vector2i]:
	var e := enc()
	var out: Array[Vector2i] = []
	if e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells) <= max_d:
		out.append(c.cell)
	if c.movement_left <= 0:
		return out
	for cell: Vector2i in reach:
		if cell != c.cell and not bool((reach[cell] as Dictionary)["occupied"]) \
				and e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells) <= max_d:
			out.append(cell)
	return out


# --- Potions ------------------------------------------------------------------------------------------------------

## Potions of Healing `c` still carries.
static func potions(c: Combatant) -> int:
	return int(c.get_meta("potions", 0))


## A Bloodied foe with a potion drinks it as its Bonus Action. Badly hurt (under a third of its Hit Points) and in
## reach of a foe, it first Disengages and steps away, which ends its turn: the result to return then. Null when the
## turn goes on as usual (having drunk or not).
func potion_turn(c: Combatant) -> Variant:
	var e := enc()
	if potions(c) <= 0 or not c.bonus_available or not c.can_act() or not c.creature.is_bloodied():
		return null
	var near := e.ai._nearest_enemy(c)
	var pressed := near != null and not near.is_down() and e.distance(c, near) <= near.reach_ft()
	if pressed and c.creature.hp * 3 < c.creature.max_hp() and c.action_available and c.speed() > 0 and e.can_disengage(c):
		e.ai.last_plan = {"kind": "retreat", "why": "badly hurt: stepping back to drink"}
		e.disengage(c)
		var moved := e.ai._flee(c, near, false)
		return e.then(moved, func() -> CombatResult:
			if c.can_act() and c.bonus_available:
				drink(c)
			return CombatResult.new())
	drink(c)
	return null


## Drinks one Potion of Healing (a Bonus Action): 2d4 + 2 Hit Points, from the item's data.
func drink(c: Combatant) -> void:
	var e := enc()
	if potions(c) <= 0:
		return
	c.set_meta("potions", potions(c) - 1)
	c.bonus_available = false
	var item := Compendium.shared().item_data(POTION)
	var dice := "2d4+2"
	for fx: Variant in item.get("effects", []):
		if str((fx as Dictionary).get("effect", "")) == "heal":
			dice = str(((fx as Dictionary).get("params", {}) as Dictionary).get("dice", dice))
	if c.creature.has_flag("cant_regain_hp"):
		e.log.add("info", "%s drinks a %s, but can't regain Hit Points right now" % [c.name(), item.get("name", "potion")], c.id)
		return
	var rolled := e.heal_roll(dice, c, str(item.get("name", "")))
	var healed := c.creature.heal(int(rolled["total"]), str(item.get("name", "")))
	e.log.add("heal", "%s drinks a %s and regains %d Hit Points" % [c.name(), item.get("name", "potion"), healed], c.id, [str(rolled["text"])])
	e.events.append({"type": "heal", "id": c.id, "amount": healed})


## What the fallen foes still carried when the fight ended, for the spoils: [{id, qty}] (potions, and scrolls as
## "spell_scroll__<spell>").
static func leftovers(e: Encounter) -> Array[Dictionary]:
	var n := 0
	var out: Array[Dictionary] = []
	for c in e.combatants:
		if c.side == &"enemy" and c.creature.dead and not e.legendary.departed.has(c.id):
			n += potions(c)
			if AiSpells.scroll_of(c) != "":
				out.append({"id": "spell_scroll__%s" % AiSpells.scroll_of(c), "qty": 1})
	if n > 0:
		out.push_front({"id": POTION, "qty": n})
	return out


# --- Morale -------------------------------------------------------------------------------------------------------

## Whether `c`'s side has broken: half of those who started the fight are down or gone, or its leader (the one
## clearly highest Challenge Rating) has fallen.
func broken(c: Combatant) -> bool:
	var e := enc()
	var side := _side(c.side)
	var ids := side["ids"] as Array
	if ids.size() < 2:
		return false
	var down := 0
	for id: Variant in ids:
		var o := e.get_c(str(id))
		if o == null or o.is_down() or o.creature.has_flag("surrendered"):
			down += 1
	if down * 2 >= ids.size():
		return true
	var leader := e.get_c(str(side["leader"]))
	return leader != null and leader != c and (leader.is_down() or leader.creature.has_flag("surrendered"))


func _side(side: StringName) -> Dictionary:
	if _sides.has(side):
		return _sides[side] as Dictionary
	var ids: Array = []
	var leader := ""
	var top := -1.0
	var tie := false
	for o in enc().combatants:
		if o.side != side or o.creature.has_flag("spell_object") or not o.creature is Monster:
			continue
		ids.append(o.id)
		var cr := float((o.creature as Monster).data.get("cr", 0))
		if cr > top:
			top = cr
			leader = o.id
			tie = false
		elif is_equal_approx(cr, top):
			tie = true
	var entry := {"ids": ids, "leader": "" if tie or ids.size() < 2 else leader}
	_sides[side] = entry
	return entry


# --- Surrender (F13) ---------------------------------------------------------------------------------------------

## Whether `c` would give up when its side breaks: a humanoid foe that speaks a language, not a boss and not one of
## Strahd's own (story/captives.gd deals with it after the fight). In every difficulty mode.
static func can_surrender(c: Combatant) -> bool:
	if not c.creature is Monster or c.creature.creature_type != &"humanoid" or str(c.ai_profile) in ["mindless", "strahd"]:
		return false
	var m := c.creature as Monster
	if Difficulty.is_boss(m) or bool(m.data.get("never_surrenders", false)):
		return false
	for lang: Variant in m.data.get("languages", []):
		if not "can't speak" in str(lang) and not "understands" in str(lang).to_lower():
			return true
	return false


## A broken side's Bloodied talker throws down its weapons: it stops fighting and can't move ("Surrendered"), and the
## fight ends once every foe is down, fled or surrendered. The party can still strike it (the companions notice).
func surrender_turn(c: Combatant) -> CombatResult:
	var e := enc()
	e.ai.last_plan = {"kind": "surrender", "why": "its side broke"}
	surrender(e, c)
	return CombatResult.new()


static func surrender(e: Encounter, c: Combatant) -> void:
	if c.creature.has_flag("surrendered"):
		return
	var fx := Effect.new("Surrendered", &"feature", "surrendered").with_modifier("flag", {"value": "surrendered"})
	fx = fx.with_modifier("flag", {"value": "no_actions"}).with_modifier("speed_set", {"value": 0})
	fx.ends = Effect.Ends.NEVER
	c.creature.add_effect(fx)
	c.set_meta("surrendered_round", e.round_no)
	if c.creature.concentration != null:
		c.creature.concentration.end("surrendered")
	e.log.add("info", "%s throws down its weapons and surrenders" % c.name(), c.id)
	e.events.append({"type": "condition", "id": c.id})
	e._check_over()


## Never flees a broken fight: mindless things, swarms, the unfrightenable, and bosses.
static func fearless(c: Combatant) -> bool:
	if str(c.ai_profile) in ["mindless", "swarm", "strahd"] or c.creature.is_condition_immune(&"frightened"):
		return true
	return c.creature is Monster and Difficulty.is_boss(c.creature as Monster)


## A broken side's turn: away from the nearest foe at a Dash; out of every foe's sight or far enough away, it leaves
## the fight. Null when it can't flee (nothing to flee from, or no Speed).
func flee_turn(c: Combatant) -> Variant:
	var e := enc()
	var near := e.ai._nearest_enemy(c)
	if near == null or c.speed() <= 0:
		return null
	e.ai.last_plan = {"kind": "flee", "why": "its side broke"}
	var r := e.ai._flee(c, near, true)
	return e.then(r, func() -> CombatResult:
		if c.is_alive() and c.creature.hp > 0 and _clear_of_foes(c):
			e.legendary.leave(c, "fled")
		return CombatResult.new())


func _clear_of_foes(c: Combatant) -> bool:
	var e := enc()
	for h in e.hostiles_of(c):
		if h.is_down():
			continue
		if e.distance(c, h) < ESCAPE_FT and e.can_see(h, c):
			return false
	return true
