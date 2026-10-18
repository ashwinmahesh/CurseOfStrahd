class_name PartyAutopilot
extends RefCounted
## A stand-in player for balance simulations and soak tests: plays the pregens with simple, sensible tactics
## (healing the fallen, Turn Undead on a crowd of zombies, Sleep on a wolf pack, Steady Aim from range, a ranger's
## bow and a warlock's Eldritch Blast from range). Paladins and monks fight like fighters.
## Test-only: in the game the player controls every party member (plan pillar 2).
##
## Sharp play (owner, 2026-10-13: "Yes they should", "And spellcasters should cast fireball"): the party as the owner
## plays it, so a fight tuned against it is as hard in his hands. The paladin smites a sturdy foe or on a Critical Hit
## when the blade alone won't finish it, the cleric opens with Spirit Guardians once foes close in and keeps near them,
## and a caster who knows Fireball throws it whenever it catches two foes. On by default since the fights were retuned
## against it (the owner's 5 wins in 8 on Balanced); AUTOPILOT_SHARP=0 in the environment, or `sharp` set by a test,
## plays the party plain as before.
##
## Full play (owner, 2026-10-14: "the players using their skills to their full abilities (smites, spirit guardians, AoE
## spells, other class features)"): the rest of the kit as he uses it. The cleric heals a friend before they drop and
## unleashes the Radiance of the Dawn on a crowd, the paladin lays hands on the fallen, brings out his Sacred Weapon and
## blesses the party when no foe can be reached, the ranger marks her target and calls down a barrage, and the wizard
## throws Cone of Cold with the Fireball. (Haste on the paladin was tried and left out: over eight bosses it cost the party
## six wins in all, since the wizard's Concentration breaks and the paladin loses a turn to lethargy.) It is the bosses' party: the
## boss fights (FightSeriesCase.BOSS_FIGHTS) and the story bot play it, the rest of the fights are still tuned against
## sharp play alone. `full` set by a test, or AUTOPILOT_FULL=1 in the environment, turns it on everywhere, and
## AUTOPILOT_OFF=radiance,cone,... switches single parts off to measure what each one adds (names are the `_on` calls).

## Whether the party plays sharp unless a test says otherwise (see above).
static var sharp_by_default: bool = OS.get_environment("AUTOPILOT_SHARP") != "0"
## Whether the party plays sharp now.
static var sharp: bool = sharp_by_default
## Whether the party plays at full ability unless a test says otherwise (see above).
static var full_by_default: bool = sharp_by_default and OS.get_environment("AUTOPILOT_FULL") == "1"
## Whether the party plays at full ability now.
static var full: bool = full_by_default
## Parts of full play switched off by name (AUTOPILOT_OFF), to measure what each adds.
static var off: Dictionary = _off_from_env()
## A foe with this many Hit Points is something tough: worth a Channel Divinity on its own (half as many, left).
const TOUGH_HP := 100
## A smite is worth its slot on a hit against a foe with at least this many Hit Points left (or on a Critical Hit).
const SMITE_WORTH_HP := 20

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
	if sharp:
		var crowd := _sharp_crowd(c)
		if crowd != null:
			return crowd
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
	if ch.class_level_of("paladin") > 0:
		return _paladin(c)
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


static func _off_from_env() -> Dictionary:
	var out := {}
	for part: String in OS.get_environment("AUTOPILOT_OFF").split(",", false):
		out[part.strip_edges()] = true
	return out


## Whether the part of full play called `part` is in use.
func _on(part: String) -> bool:
	return full and not off.has(part)


var _catalog_of: ActionCatalog


## `c` and everyone allied with it.
func _friends(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = [c]
	out.append_array(e.allies_of(c))
	return out


## The hotbar's action `id` on `targets`, when it can be used now (a class feature or spell as the player clicks it):
## its result, or null when it isn't available or didn't go off.
func _use(c: Combatant, id: String, targets: Array = [], opts: Dictionary = {}) -> CombatResult:
	if _catalog_of == null:
		_catalog_of = ActionCatalog.new(e)
	var action := _catalog_of.find(c, id)
	if action.is_empty() or str(action.get("why", "")) != "":
		return null
	var r := _catalog_of.perform(c, action, targets, Vector2.INF, Vector2.ZERO, 0, opts)
	return r if r.ok else null


func _melee_turn(c: Combatant) -> CombatResult:
	var plan := e.ai.plan_turn(c)
	if str(plan["kind"]) == "attack":
		return e.ai._move_then_attack(c, plan)
	if str(plan["kind"]) == "approach":
		return e.ai._approach(c, plan)
	# Foes hidden and none in sight or heard: look for them (Search), as a player would, rather than wait them out (a
	# dim nursery's shadows hid until the fight ran out of rounds).
	if str(plan["kind"]) == "search":
		return e.search(c)
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


## The paladin's turn: Lay On Hands, Sacred Weapon and Bless first (the first two cost no action), then the blade.
func _paladin(c: Combatant) -> CombatResult:
	var foes := _enemies(c)
	if not foes.is_empty():
		if _on("lay_on_hands"):
			_lay_on_hands(c)
		_sacred_weapon(c, foes)
		var blessing := _bless(c, foes)
		if blessing != null:
			return blessing
	return _fighter(c)


## Lay On Hands (a Bonus Action) on the fallen friend beside him, or on himself or a friend within reach under a third
## of their Hit Points: what it takes to stand, not the pool.
func _lay_on_hands(c: Combatant) -> void:
	var ch := c.creature as Character
	var pool := ch.resource_left("lay_on_hands")
	if not c.bonus_available or pool <= 0:
		return
	var pick: Combatant = null
	var pick_ratio := 1.0
	for a in _friends(c):
		if a.creature.dead or (a != c and e.distance(c, a) > 5):
			continue
		var ratio := -1.0 if a.creature.hp <= 0 else float(a.creature.hp) / float(a.creature.max_hp())
		if ratio < 0.34 and ratio < pick_ratio:
			pick = a
			pick_ratio = ratio
	if pick == null:
		return
	var amount := 8 if pick.creature.hp <= 0 else maxi(8, (pick.creature.max_hp() - pick.creature.hp) / 2)
	_use(c, "feat:cf:lay_on_hands", [pick], {"choice": str(mini(pool, amount))})


## Sacred Weapon (Oath of Devotion's Channel Divinity) once a foe is within a move and a blow.
func _sacred_weapon(c: Combatant, foes: Array[Combatant]) -> void:
	var ch := c.creature as Character
	if not _on("sacred_weapon") or ch.resource_left("paladin_channel_divinity") <= 0 or c.creature.has_flag("sacred_weapon"):
		return
	var near := _nearest(c, foes)
	if near != null and e.distance(c, near) <= c.movement_left + 5:
		_use(c, "feat:cf:sacred_weapon")


## Bless on up to three friends within 30 ft when no foe can be reached this turn (so the Action is free anyway).
func _bless(c: Combatant, foes: Array[Combatant]) -> CombatResult:
	var ch := c.creature as Character
	if not _on("bless") or not c.action_available or c.cast_slot_spell_this_turn or _concentrating_on_anything(c) \
			or ch.slots_left(1) <= 0 or not ch.knows_spell("bless") or e.round_no > 2:
		return null
	var near := _nearest(c, foes)
	if near == null or e.distance(c, near) <= c.movement_left + 5:
		return null
	var picks: Array = [c]
	for a in e.allies_of(c):
		if picks.size() < 3 and a.can_act() and a.creature is Character and e.distance(c, a) <= 30:
			picks.append(a)
	if picks.size() < 2:
		return null
	var r := _cast(c, "bless", 1, picks)
	return r if r.ok else null


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
	if _on("heal"):
		_mend(c)
	# Sharp: Spirit Guardians once foes close in, and the cleric stays near them while it lasts.
	if sharp:
		var guardians := _sharp_guardians(c, foes)
		if guardians != null:
			return guardians
	# Full: the Radiance of the Dawn on a crowd (or one big foe) within 30 ft.
	if _on("radiance") and c.action_available:
		var radiance := _radiance(c, foes)
		if radiance != null:
			return radiance
	# 4. Spiritual Weapon, then its Bonus Action attacks (not over Spirit Guardians: both need Concentration).
	if c.bonus_available and not foes.is_empty() and not _concentrating_on(c, "spirit_guardians"):
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


## Healing Word (a Bonus Action, 60 ft) on a friend under a third of their Hit Points, before they drop.
func _mend(c: Combatant) -> void:
	var ch := c.creature as Character
	if not c.bonus_available or c.cast_slot_spell_this_turn or ch.slots_left(1) <= 0:
		return
	var worst: Combatant = null
	var worst_ratio := 0.34
	for a in _friends(c):
		if a.creature.hp <= 0 or a.creature.dead or e.distance(c, a) > 60:
			continue
		var ratio := float(a.creature.hp) / float(a.creature.max_hp())
		if ratio < worst_ratio:
			worst = a
			worst_ratio = ratio
	if worst != null:
		_cast(c, "healing_word", 1, [worst])


## The Radiance of the Dawn (a Channel Divinity) on two foes or more within 30 ft, or one with plenty of Hit Points left.
func _radiance(c: Combatant, foes: Array[Combatant]) -> CombatResult:
	var ch := c.creature as Character
	if ch.resource_left("channel_divinity") <= 0:
		return null
	var n := 0
	var hp := 0
	for f in foes:
		if e.distance(c, f) <= 30:
			n += 1
			hp += f.creature.hp
	if n >= 2 or (n == 1 and hp >= TOUGH_HP / 2):
		return _use(c, "feat:radiance_of_the_dawn")
	return null


func _wizard(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	var foes := _enemies(c)
	if foes.is_empty():
		return _melee_turn(c)
	# Fireball on a crowd (lane 22, 2026-10-08: the Yester Hill summit's fire-vulnerable twig blights): three foes or
	# more, or two with a big one, never the wizard; allies only when Sculpt Spells keeps them out (Evoker 6). Sharp
	# play has thrown it already when it catches two.
	if ch.slots_left(3) > 0 and not c.cast_slot_spell_this_turn and ch.knows_spell("fireball"):
		var fb := _fireball_point(c, foes)
		if fb != Vector2.INF:
			var f := _cast(c, "fireball", 3, [], fb)
			if f.ok:
				return f
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


## The Fireball point catching the most foes within 150 ft: {point} or Vector2.INF when no point is worth it (`least`
## foes, or two with a big one).
func _fireball_point(c: Combatant, foes: Array[Combatant], least: int = 3) -> Vector2:
	var sculpts := CombatFeatures.has_feature(c, "sculpt_spells")
	var best := Vector2.INF
	var best_score := 0.0
	for f in foes:
		var p := e.center_of(f)
		if e.grid.distance_ft(c.cell, c.size_cells, f.cell, f.size_cells) > 150:
			continue
		var n := 0
		var big := false
		var allies := 0
		var hits_me := false
		for o in e.spells.creatures_in(e.grid.area_cells("sphere", 20, p)):
			if o == c:
				hits_me = true
			elif c.hostile_to(o) and not o.is_down():
				n += 1
				big = big or o.creature.hp >= 40
			elif not c.hostile_to(o) and not o.is_down():
				allies += 1
		if hits_me or (allies > 0 and (not sculpts or allies > 4)):
			continue
		var score := float(n) + (1.0 if big else 0.0)
		if (n >= least or (n >= 2 and big)) and score > best_score:
			best_score = score
			best = p
	return best


func _ranger(c: Combatant) -> CombatResult:
	var foes := _enemies(c)
	if foes.is_empty():
		return _melee_turn(c)
	for f in foes:
		if e.distance(c, f) <= 5:
			return _melee_turn(c)
	var target := _weakest(foes)
	if _on("hunters_mark"):
		target = _hunters_mark(c, foes, target)
	for id: String in ["weapon:longbow", "weapon:shortbow"]:
		var bow := e.option_by_id(c, id)
		if not bow.is_empty() and e.attack_legal(c, target, bow) == "":
			return e.attack(c, target, id)
	return _melee_turn(c)


## Hunter's Mark (a Bonus Action) on the foe about to be shot, again on the next when it falls; she keeps shooting the
## marked one. The foe to shoot.
func _hunters_mark(c: Combatant, foes: Array[Combatant], fallback: Combatant) -> Combatant:
	var ch := c.creature as Character
	for f in foes:
		for fx in f.creature.effects:
			if fx.source_id == "hunters_mark" and fx.caster_id == c.id:
				return f
	if c.bonus_available and not c.cast_slot_spell_this_turn and ch.slots_left(1) > 0 and ch.knows_spell("hunters_mark") \
			and (not _concentrating_on_anything(c) or _concentrating_on(c, "hunters_mark")):
		_cast(c, "hunters_mark", 1, [fallback])
	return fallback


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
## for spells, as the fights it was tuned on did before smiting was asked about) and a Counterspell against a foe's
## Counterspell (no hero could before, so the fights' win rates, tuned without it, stay where they were measured).
static func _takes(req: ReactionRequest) -> bool:
	return req.kind != CombatFeatures.DIVINE_SMITE and req.kind != "counterspell"


## Its answer this time: sharp play smites a foe worth a slot (one with SMITE_WORTH_HP left, or on a Critical Hit) that
## the hit alone likely won't fell, with the free use or the lowest slot, as the prompt offers first. A smite on a wolf
## the blade kills anyway spends the paladin's last slot for nothing (2026-10-13: such smites cost level 1 camp fights).
func _answer(req: ReactionRequest) -> bool:
	if not sharp or req.kind != CombatFeatures.DIVINE_SMITE:
		return _takes(req)
	var target := e.get_c(req.trigger_id)
	var paladin := e.get_c(req.reactor_id)
	if target == null or paladin == null:
		return false
	var crit := req.callout != ""
	# A Critical Hit doubles the weapon's dice (not its modifier): about 1.6 times its average.
	if target.creature.hp <= _melee_average(paladin) * (1.6 if crit else 1.0):
		return false
	return crit or target.creature.hp >= SMITE_WORTH_HP


## The average damage of `c`'s best melee weapon hit (0 when it has none).
func _melee_average(c: Combatant) -> float:
	var best := 0.0
	for o in e.attack_options(c):
		if bool(o.get("melee", false)) and o.get("profile") is WeaponProfile:
			best = maxf(best, (o["profile"] as WeaponProfile).average_damage())
	return best


# --- Sharp play -----------------------------------------------------------------------------------

## Area spells at a crowd, with the lowest slot that casts each: Fireball from any caster who knows it when it catches two
## foes or more (or one with a big one) and no ally Sculpt Spells can't spare; in full play also the wizard's Cone of Cold
## on three (or two with a big one) and the ranger's Conjure Barrage on two. Null when none is cast.
func _sharp_crowd(c: Combatant) -> CombatResult:
	var ch := c.creature as Character
	if not c.action_available or c.cast_slot_spell_this_turn:
		return null
	var foes := _enemies(c)
	if _on("cone") and ch.knows_spell("cone_of_cold") and ch.slots_left(5) > 0:
		var cone := _cone_dir(c, foes, "cone_of_cold", false)
		if not cone.is_empty() and (int(cone["n"]) >= 3 or (int(cone["n"]) >= 2 and bool(cone["big"]))):
			var r := _cast(c, "cone_of_cold", 5, [], Vector2.INF, cone["dir"] as Vector2)
			if r.ok:
				return r
	if _on("barrage") and ch.knows_spell("conjure_barrage"):
		var barrage := _cone_dir(c, foes, "conjure_barrage", true)
		if not barrage.is_empty() and (int(barrage["n"]) >= 3 or (int(barrage["n"]) >= 2 and bool(barrage["big"]))):
			for slot: int in [3, 4, 5]:
				if ch.slots_left(slot) > 0:
					var r2 := _cast(c, "conjure_barrage", slot, [], Vector2.INF, barrage["dir"] as Vector2)
					if r2.ok:
						return r2
					break
	if not ch.knows_spell("fireball"):
		return null
	var point := _fireball_point(c, foes, 2)
	if point == Vector2.INF:
		return null
	for slot2: int in [3, 4, 5]:
		if ch.slots_left(slot2) > 0:
			var r3 := _cast(c, "fireball", slot2, [], point)
			return r3 if r3.ok else null
	return null


## The direction from `c` along which the self-origin cone `spell_id` catches the most foes: {dir, n, big} or {} when it
## catches none (or an ally, unless the spell spares them). It aims toward a foe along the nearest of the eight grid
## directions, as the fights were tuned with before cones could point anywhere (owner, 2026-10-18): free aim is the
## player's, and the yardstick stays where it was.
func _cone_dir(c: Combatant, foes: Array[Combatant], spell_id: String, allies_safe: bool) -> Dictionary:
	var s := Compendium.shared().spell_data(spell_id)
	var origin := e.center_of(c)
	var best := {}
	var best_score := 0.0
	for f in foes:
		var dir := e.center_of(f) - origin
		if dir.length() < 0.01:
			continue
		dir = CombatGrid.grid_aim(dir)
		var n := 0
		var big := false
		var allies := 0
		for o in e.spells.creatures_in(e.spells.area_for(c, s, origin, dir)):
			if o == c or o.is_down():
				continue
			if c.hostile_to(o):
				n += 1
				big = big or o.creature.hp >= 40
			else:
				allies += 1
		if allies > 0 and not allies_safe:
			continue
		var score := float(n) + (1.0 if big else 0.0)
		if score > best_score:
			best_score = score
			best = {"dir": dir, "n": n, "big": big}
	return best


## Spirit Guardians, with the lowest slot that casts it, once a foe is within 20 ft or two within 40 ft; while it lasts
## the cleric steps up beside the nearest foe so the spirits keep biting. Null when the turn goes on as usual.
func _sharp_guardians(c: Combatant, foes: Array[Combatant]) -> CombatResult:
	var ch := c.creature as Character
	if foes.is_empty():
		return null
	if _concentrating_on(c, "spirit_guardians"):
		_close_in(c, foes)
		return null
	if not c.action_available or c.cast_slot_spell_this_turn or not ch.knows_spell("spirit_guardians"):
		return null
	var near := 0
	var closing := 0
	for f in foes:
		var d := e.distance(c, f)
		near += 1 if d <= 20 else 0
		closing += 1 if d <= 40 else 0
	if near == 0 and closing < 2:
		return null
	for slot: int in [3, 4, 5]:
		if ch.slots_left(slot) > 0:
			var r := _cast(c, "spirit_guardians", slot, [])
			if not r.ok:
				return null
			return e.then(r, func() -> CombatResult:
				if e.state == Encounter.State.ACTIVE and e.current() == c and c.can_act():
					_close_in(c, _enemies(c))
				return CombatResult.new())
	return null


## Moves `c` beside the nearest foe when none is within 10 ft (no Dash).
func _close_in(c: Combatant, foes: Array[Combatant]) -> void:
	var near := _nearest(c, foes)
	if near == null or e.distance(c, near) <= 10 or c.movement_left <= 0:
		return
	e.ai._approach(c, {"kind": "approach", "target": near, "score": 0.0, "dash": false})


func _concentrating_on_anything(c: Combatant) -> bool:
	var conc := c.creature.concentration
	return conc != null and not conc.ended


func _concentrating_on(c: Combatant, spell_id: String) -> bool:
	var conc := c.creature.concentration
	return conc != null and not conc.ended and conc.source_id == spell_id


## Plays the encounter to the end (or `max_rounds`): the autopilot for the party, AiBrain for everyone else.
## Every reaction is taken automatically. Returns {outcome, rounds, downs}.
func run(max_rounds: int = 30) -> Dictionary:
	e.default_player_reaction = "auto"
	# No hero Counterspells a foe's Counterspell (SpellCounters): none could before the chain, and the fights' win rates
	# were tuned without it. Automatic would do it (with one way to pay it never asks), so this one rule is Off.
	for h in e.combatants:
		if h.is_player_controlled():
			h.reaction_rules["counterspell"] = "never"
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
				r = e.answer_reaction(_answer(e.pending))
			if e.state == Encounter.State.ACTIVE and e.current() == c:
				e.end_turn()
		else:
			r = e.run_ai_turn()
			while e.pending != null:
				r = e.answer_reaction(_answer(e.pending))
	for c in e.combatants:
		if c.side == &"party" and e.log.texts().any(func(t: String) -> bool: return t == "%s falls unconscious" % c.name()):
			downs += 1
	return {"outcome": e.outcome if e.state == Encounter.State.OVER else "timeout", "rounds": e.round_no, "downs": downs}
