class_name AiTactics
extends RefCounted
## How the enemy AI fights at the playthrough's difficulty (combat/difficulty.gd, F1). AiBrain asks it while it
## scores attacks and before it plans a turn; at Balanced ("standard") it changes nothing.
##   kind (Story):        spreads its blows: a foe already struck this round is worth less, and no killing-blow bonus.
##   sharp (Tactician):   focus fire on the hurt, on a foe its side is already on, on concentrating casters and healers.
##   ruthless (Honour):   sharp, and a cruel foe (evil, Intelligence 6 or more) strikes a hero at 0 Hit Points when
##                        that's its best move (each hit is a failed Death Saving Throw, two from within 5 ft).
## At Story and Balanced a foe also spreads its own blows (spread_rank): each blow of a Multiattack or Legendary Action
## goes to a foe it hasn't struck since its own turn began, unless it has a reason to go on with one (focus_reason).
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
## Blows each creature has dealt since its own turn began (its Multiattack, then the Legendary Actions it takes before
## its next turn): creature id -> {target id -> count}. Cleared when its turn begins (begin_turn).
var _dealt: Dictionary = {}
## Each side as it first fought: side -> {ids: [...], leader: id or ""}.
var _sides: Dictionary = {}

## Where a familiar, a steed or an Echo Knight's image stands in a creature's list of foes to strike: after every
## foe worth striking, however many blows those have had (spread_rank).
const IMAGE_RANK := 1000


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func mode() -> String:
	return enc().difficulty.tactics


# --- Choosing targets ---------------------------------------------------------------------------------------------

## Notes an AI attack on `t` this round (for spreading or focusing blows), and with `by`, the blow it dealt (dealt).
func note_strike(t: Combatant, by: Combatant = null) -> void:
	var e := enc()
	if _struck_round != e.round_no:
		_struck_round = e.round_no
		_struck.clear()
	_struck[t.id] = int(_struck.get(t.id, 0)) + 1
	if by != null:
		var mine := _dealt.get(by.id, {}) as Dictionary
		mine[t.id] = int(mine.get(t.id, 0)) + 1
		_dealt[by.id] = mine


func struck(t: Combatant) -> int:
	return int(_struck.get(t.id, 0)) if _struck_round == enc().round_no else 0


## `c`'s own turn begins: what it struck in its last one is behind it.
func begin_turn(c: Combatant) -> void:
	_dealt.erase(c.id)


## Blows `c` has dealt `t` since its own turn began.
func dealt(c: Combatant, t: Combatant) -> int:
	return int((_dealt.get(c.id, {}) as Dictionary).get(t.id, 0))


## Whether `c` has dealt any blow since its own turn began.
func dealt_any(c: Combatant) -> bool:
	return not (_dealt.get(c.id, {}) as Dictionary).is_empty()


## Why `c` may go on striking `t` rather than turn its blows on another foe, "" when it has no reason (a foe that
## spreads its blows, spread_rank): "finish" when a blow of `avg` could end `t` and "nearly down" under a quarter of its
## Hit Points (neither at Story: no killing-blow bonus there, finish_scale), "concentrating" on a spell, and for Strahd
## "prize": a hero carrying a treasure of the reading, the one he holds, or one he has charmed.
func focus_reason(c: Combatant, t: Combatant, avg: float) -> String:
	if EchoKnight.is_echo(t):
		return ""
	if finish_scale() > 0.0:
		var left := t.creature.hp + t.creature.temp_hp
		if avg >= float(left):
			return "finish"
		if left * 4 <= t.creature.max_hp():
			return "nearly down"
	if t.creature.concentration != null:
		return "concentrating"
	if str(c.ai_profile) == "strahd" and (BossBrain.carries_treasure(t) or str(enc().grapples.get(t.id, "")) == c.id \
			or Legendary.charmed_by(t, c)):
		return "prize"
	return ""


## Where `t` stands in the list of foes `c` strikes next with a blow of `avg`, the lowest first (owner, 2026-10-18:
## monsters with Legendary Actions went for one hero, and so did every blow of a Multiattack). A foe that spreads its
## blows (Story and Balanced, `spreads`) puts first those it hasn't struck since its own turn began: each blow already
## dealt `t` is a place down the list, unless it has a reason to go on (focus_reason: with a concentrating caster or
## Strahd's prize it only keeps its place, but a foe it can finish, or that is nearly down, goes ahead of the rest, -1).
## A familiar, a steed or an Echo Knight's image comes after every real foe. Tactician and Honour foes focus: every foe
## is 0, and the callers' own worth decides.
func spread_rank(c: Combatant, t: Combatant, avg: float) -> int:
	if not spreads(c):
		return 0
	var rank := 0
	if AiBrain.companion(t) or EchoKnight.is_echo(t):
		rank += IMAGE_RANK
	var why := focus_reason(c, t, avg)
	if why == "finish" or why == "nearly down":
		return rank - 1
	if why == "":
		rank += dealt(c, t)
	return rank


## Spreading blows (owner, 2026-10-12: every foe went for the hero with the lowest Armor Class). At Tactician and
## Honour a foe weighs its odds as they are; at Story and Balanced it weighs them gently (the square root of the
## chance), so a hard-to-hit hero isn't passed over every time.
func focuses(_c: Combatant) -> bool:
	return mode() in ["sharp", "ruthless"]


## Whether `c` weighs its odds gently: a foe (not the party's autopilot) at Story or Balanced.
func spreads(c: Combatant) -> bool:
	return c.side == &"enemy" and not focuses(c)


## A foe's own lean towards a hero, seeded by the two of them (so it holds from turn to turn, and two wolves differ):
## up to this share of the blow's worth either way. A smart foe (Intelligence 10 or more) leans less, and every foe
## much less at Tactician and Honour, where they focus.
func taste(c: Combatant, t: Combatant) -> float:
	var e := enc()
	# Seeded by the two's names and places in the fight, not their ids: a monster's id counts every monster made since
	# the game started, so the same fight would lean another way from one run to the next.
	var key := "%s %d|%s %d" % [c.name(), e.combatants.find(c), t.name(), e.combatants.find(t)]
	var x := float(posmod(hash(key), 1001)) / 1000.0 * 2.0 - 1.0
	# Story already spreads its blows by who's been struck (target_adjust), so it leans less; Tactician and Honour focus.
	var spread: float = {"kind": 0.08, "standard": 0.1}.get(mode(), 0.04)
	if c.creature.ability_score(&"int") >= 10:
		spread *= 0.75
	return x * spread


## How much of the killing-blow bonus counts (none when the AI spreads its blows).
func finish_scale() -> float:
	return 0.0 if mode() == "kind" else 1.0


## What a blow on `t` is worth to `c` for the blows after the plan's, where its target is the only thing left to choose:
## `chance` to hit for `avg` damage, `finish` the foe's profile value. The target-dependent part of AiBrain._score (the
## odds as it weighs them, an image's worth, the killing-blow bonus, a concentrating caster, the boss's lean, the
## difficulty's spreading and the foe's taste), without the walk there.
func blow_worth(c: Combatant, t: Combatant, avg: float, chance: float, finish: float) -> float:
	var echo := EchoKnight.is_echo(t)
	var expected := (sqrt(maxf(0.0, chance)) if spreads(c) else chance) * avg
	if echo:
		expected *= 0.3
	var worth := expected
	if avg >= float(t.creature.hp + t.creature.temp_hp) and not echo:
		worth += finish * 3.0 * chance * finish_scale()
	if t.creature.concentration != null:
		worth += 1.0
	worth += enc().ai.boss.target_bonus(c, t)
	if not echo:
		worth += target_adjust(t, expected)
		if c.side == &"enemy":
			worth += expected * taste(c, t)
	return worth


## Whether foes move to flank (Flanking, owner 2026-10-12): Tactician and Honour's sharp foes pick squares across from an
## ally; on Story and Balanced they fight as before the rule and take its Advantage only when it falls their way.
func seeks_flanks() -> bool:
	return mode() in ["sharp", "ruthless"]


## Extra score for an attack on `t` worth `expected` damage.
func target_adjust(t: Combatant, expected: float) -> float:
	match mode():
		"kind":
			return -0.5 * expected * struck(t)
		"standard":
			# Balanced foes spread a little too (owner, 2026-10-12); the party's autopilot doesn't.
			return -0.25 * expected * struck(t) if t.side in [&"party", &"guest"] else 0.0
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
	var crowd := e.ai.crowd_map(c)
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
				var close := e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) <= 5
				c.cell = keep
				var fails := 2 if close else 1
				var value := 9.0 if t.creature.death_failures + fails >= 3 else 4.0 * fails
				var s := chance * value + e.ai.boss.target_bonus(c, t) - AiBrain.CROWD_SCORE * float(crowd.get(cell, 0))
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
	if e.grid.distance_ft(c.cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) <= max_d:
		out.append(c.cell)
	if c.movement_left <= 0:
		return out
	for cell: Vector2i in reach:
		if cell != c.cell and not bool((reach[cell] as Dictionary)["occupied"]) \
				and e.grid.distance_ft(cell, c.size_cells, t.cell, t.size_cells, c.altitude, t.altitude) <= max_d:
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
	if potions(c) <= 0 or not c.bonus_available or not c.can_act() or not c.creature.is_bloodied() or c.turn_is_a_choice():
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

## Whether `c` would give up when its side breaks: a humanoid foe that speaks a language, not a boss, not a story
## character the fight names, and not one of Strahd's own (story/captives.gd deals with it after the fight). In every
## difficulty mode.
static func can_surrender(c: Combatant) -> bool:
	if not c.creature is Monster or c.creature.creature_type != &"humanoid" or str(c.ai_profile) in ["mindless", "strahd"]:
		return false
	var m := c.creature as Monster
	if Difficulty.is_boss(m) or bool(m.data.get("never_surrenders", false)):
		return false
	# A story character the fight names (Mother Ruxandra, Nikolai Wachter): what becomes of them is the story's.
	if not m.name.begins_with(str(m.data.get("name", m.name))):
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


## A broken side's turn: away from the nearest foe at a Dash; out of every foe's sight, far enough away, or somewhere no
## way leads from its foes (cut_off), it leaves the fight. Null when it can't flee (nothing to flee from, or no Speed).
func flee_turn(c: Combatant) -> Variant:
	var e := enc()
	var near := e.ai._nearest_enemy(c)
	if near == null or c.speed() <= 0:
		return null
	e.ai.last_plan = {"kind": "flee", "why": "its side broke"}
	var r := e.ai._flee(c, near, true)
	return e.then(r, func() -> CombatResult:
		if c.is_alive() and c.creature.hp > 0 and (_clear_of_foes(c) or cut_off(c)):
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


# --- Cut off ------------------------------------------------------------------------------------------------------

## Turns in a row each foe has ended cut off from every enemy: creature id -> {n, round}.
var _cut: Dictionary = {}
## How many of its turns in a row a foe spends cut off before it gives up the fight.
const CUT_OFF_TURNS := 2


## Whether `c` can't get at any of its enemies however long it walks: no way across the map (its own way of moving:
## walls, drops and bystanders in the way, but not creatures, nor doors and furniture, which can be opened or broken)
## ends where one of its attacks reaches a standing enemy, a ranged one with a clear line to it (stat-block spells
## count as a 60 ft reach); and no enemy can walk up beside it either (a Large dire wolf can't pass a one-square
## doorway, but the heroes behind it can come out to it).
func cut_off(c: Combatant) -> bool:
	var e := enc()
	var foes: Array[Combatant] = []
	for h in e.hostiles_of(c):
		if not h.is_down() and not h.has_meta("left_fight") and not h.creature.has_flag("surrendered"):
			foes.append(h)
	if foes.is_empty():
		return false
	var melee := 5
	var ranged := 0
	for o in e.ai._usable_options(c):
		var p := o["profile"] as WeaponProfile
		if bool(o["melee"]):
			melee = maxi(melee, p.reach)
		else:
			ranged = maxi(ranged, p.long_range if p.long_range > 0 else p.normal_range)
	if AiSpells.casts(c):
		ranged = maxi(ranged, 60)
	var g := e.grid
	var open := open_grid(true, true)
	var none := func(_x: Vector2i) -> bool: return false
	var walk := open.reachable(c.cell, c.size_cells, 4000, none, none, none, e.movement.move_mode(c))
	# Lines are looked for from at most this many squares; past that it counts as able to get at them.
	var looks := 400
	for f in foes:
		for cell: Vector2i in walk:
			var d := g.distance_ft(cell, c.size_cells, f.cell, f.size_cells, c.altitude, f.altitude)
			if d <= melee:
				return false
			if d <= ranged:
				looks -= 1
				if looks <= 0 or g.can_see(cell, c.size_cells, f.cell, f.size_cells):
					return false
	for f in foes:
		for cell: Vector2i in open.reachable(f.cell, f.size_cells, 4000, none, none, none, e.movement.move_mode(f)):
			if g.distance_ft(cell, f.size_cells, c.cell, c.size_cells, f.altitude, c.altitude) <= 5:
				return false
	return true


## A copy of the fight's grid to walk on (the fight's own is never touched, so a worker thread may make one): shut doors
## open (`locked`: the locked ones too), and with `furniture` the squares furniture and other breakable things fill.
func open_grid(locked: bool, furniture: bool) -> CombatGrid:
	var e := enc()
	var src := e.grid
	var g := CombatGrid.new()
	g.width = src.width
	g.depth = src.depth
	g._flags = src._flags.duplicate()
	g._height = src._height
	g.raised = src.raised
	g.drop_ft = src.drop_ft
	g.ceiling_ft = src.ceiling_ft
	g.has_relief = src.has_relief
	g._max_height = src._max_height
	for o in e.objects.list:
		if o.destroyed or o.hangs or o.blocks == 0 or not (o.is_door() or furniture) or (o.is_door() and o.locked and not locked):
			continue
		for cell in o.cells:
			g.set_flag(cell, CombatGrid.WALL | CombatGrid.LOW, false)
	return g


## A turn with no attack in it (`plan`, AiBrain.plan_turn): a foe cut off from every enemy (cut_off), or held off from
## them by dangerous ground that could drop it (the plan's square `held_off`: a hurt will-o'-wisp at the edge of a
## cleric's Spirit Guardians, owner 2026-10-18), for CUT_OFF_TURNS of its turns in a row leaves the fight, in every
## mode, so a fight nobody can finish ends (the last wolf of a pack on the far side of the narrows when a bystander
## stood in the gap). Strahd and legendary creatures hold their ground: their fights are the story's. Returns the
## turn's result when it leaves, else null.
func stranded_turn(c: Combatant, plan: Dictionary) -> Variant:
	var e := enc()
	var square := plan.get("square", {}) as Dictionary
	var approach := str(plan.get("kind", "")) == "approach" and not square.is_empty()
	var held := approach and bool(square.get("held_off", false))
	# Closing in (the square it thought of isn't where it stands) is no stall: only a turn going nowhere is looked at.
	var going := approach and (square["cell"] as Vector2i) != c.cell
	if str(plan.get("kind", "")) == "attack" or c.side != &"enemy" or str(c.ai_profile) == "strahd" \
			or (c.creature is Monster and (c.creature as Monster).data.has("legendary_actions")) \
			or not (held or (not going and cut_off(c))):
		_cut.erase(c.id)
		return null
	var was := _cut.get(c.id, {}) as Dictionary
	var n := int(was.get("n", 0)) + 1 if int(was.get("round", -9)) == e.round_no - 1 else 1
	_cut[c.id] = {"n": n, "round": e.round_no}
	if n < CUT_OFF_TURNS:
		return null
	_cut.erase(c.id)
	if held:
		e.ai.last_plan = {"kind": "flee", "why": "held off by dangerous ground"}
		e.log.add("info", "%s won't brave the ground between it and its foes, and slips away" % c.name(), c.id)
	else:
		e.ai.last_plan = {"kind": "flee", "why": "cut off from every enemy"}
		e.log.add("info", "%s can find no way to reach its foes" % c.name(), c.id)
	e.legendary.leave(c, "cut off")
	return CombatResult.new()
