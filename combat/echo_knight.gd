class_name EchoKnight
extends RefCounted
## The Echo Knight (Explorer's Guide to Wildemount, fitted to the 2024 Fighter: docs/rules/deviations.md) in a fight.
## Manifest Echo puts the knight's echo on the board as a creature with no turns of its own (like Bigby's Hand): it
## moves, swaps places and is dismissed from its knight's hotbar ("feat:ek:<id>"), and the knight's attacks and
## Opportunity Attacks can come from its space. Such an attack runs with the knight and the echo swapped for its
## length (`strike`), so reach, range, cover, sight and Weapon Mastery all count from the echo's square, "as if you
## were there". Also Unleash Incarnation, Echo Avatar, Shadow Martyr, Reclaim Potential and Legion of One. The
## encounter, the attack pipeline, movement and the action catalog call the hooks below.

## The hotbar rider that sends every attack of the turn from the echo's space.
const RIDER := "echo:strike_from_the_echo"
## On a knight: {target, echo} for the Opportunity Attack its echo just provoked (Encounter._provokers).
const OA_META := "echo_oa"
const ALL_CONDITIONS := ["blinded", "charmed", "deafened", "exhaustion", "frightened", "grappled", "incapacitated",
	"invisible", "paralyzed", "petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"]

var _enc: WeakRef
## Knight id -> {turn, taken, unleashed}: Attack actions taken this turn, and Unleash Incarnation attacks made.
var _attack_actions: Dictionary = {}
## Echo id -> {turn, feet}: how far its knight has sent it this turn.
var _moved: Dictionary = {}


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


static func has(c: Combatant, id: String) -> bool:
	return c != null and CombatFeatures.has_feature(c, id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


static func is_echo(c: Combatant) -> bool:
	return c != null and c.has_meta("echo_of")


func knight_of(echo: Combatant) -> Combatant:
	return enc().get_c(str(echo.get_meta("echo_of", ""))) if is_echo(echo) else null


## `c`'s echoes still on the board, the first one first.
func echoes(c: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	if c == null:
		return out
	for o in enc().combatants:
		if o.is_alive() and str(o.get_meta("echo_of", "")) == c.id:
			out.append(o)
	out.sort_custom(func(a: Combatant, b: Combatant) -> bool: return int(a.get_meta("echo_n", 1)) < int(b.get_meta("echo_n", 1)))
	return out


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:ek:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


## An `ability` event for the view's effect (art/vfx/effects.json features).
func _ability(by: Combatant, key: String, targets: Array = []) -> void:
	var ids: Array = []
	for t: Variant in targets:
		ids.append((t as Combatant).id)
	enc().events.append({"type": "ability", "source": "feature", "by": by.id, "key": key, "targets": ids, "cells": []})


static func _restore_one(ch: Character, res: String) -> void:
	if ch != null and ch.resources.has(res):
		var d := ch.resources[res] as Dictionary
		d["used"] = maxi(0, int(d["used"]) - 1)


## The echo's name in a label: "Echo", or "Second Echo" beside the first (Legion of One).
static func _which(echo: Combatant) -> String:
	return "Echo" if int(echo.get_meta("echo_n", 1)) == 1 else "Second Echo"


# --- The hotbar -----------------------------------------------------------------------------------------------

## Manifest Echo; Move, Swap with and Dismiss each echo; Unleash Incarnation; Echo Avatar or its end.
func list(c: Combatant, out: Array[Dictionary], aw: String, bw: String) -> void:
	if not has(c, "manifest_echo"):
		return
	var e := enc()
	var ch := _ch(c)
	var tw := e._turn_check(c)
	var mine := echoes(c)
	var limit := 2 if has(c, "legion_of_one") else 1
	var msub := "within 15 ft"
	if mine.size() >= limit:
		msub = "replaces your echo" if limit == 1 else "replaces both echoes"
	out.append(_entry("manifest_echo", "Manifest Echo", msub, "bonus", bw, "place",
		"Bonus Action: an echo of you appears in an unoccupied space you can see within 15 ft: AC %d, 1 Hit Point, immune to every condition. It vanishes if it ends your turn more than 30 ft from you."
		% (14 + c.creature.proficiency_bonus()), 15))
	for echo in mine:
		var which := _which(echo)
		var left := move_left(echo)
		var mw := tw
		if mw == "" and left <= 0:
			mw = "It has moved 30 ft this turn"
		var mv := _entry("echo_move:" + echo.id, "Move %s" % which, "%d ft left" % left, "free", mw, "place",
			"Send the echo up to 30 ft a turn, in any direction (no action; it doesn't provoke Opportunity Attacks).", left)
		mv["from"] = echo.id
		out.append(mv)
		var sw := bw
		if sw == "" and c.movement_left < 15:
			sw = "Needs 15 ft of movement"
		if sw == "" and e.mount_of(c) != null:
			sw = "Dismount first"
		out.append(_entry("echo_swap:" + echo.id, "Swap with %s" % which, "15 ft of movement", "bonus", sw, "none",
			"Bonus Action: teleport, trading places with the echo however far apart you are, for 15 ft of your movement."))
		out.append(_entry("echo_dismiss:" + echo.id, "Dismiss %s" % which, "it fades", "bonus", bw, "none", "Bonus Action: the echo vanishes."))
	if has(c, "unleash_incarnation") and ch != null:
		var left2 := ch.resource_left("unleash_incarnation")
		var uw := tw
		if uw == "" and not c.can_act():
			uw = "Can't act"
		elif uw == "" and mine.is_empty():
			uw = "No echo"
		elif uw == "" and left2 <= 0:
			uw = "None left"
		elif uw == "" and not c.took_attack_action:
			uw = "Take the Attack action first"
		elif uw == "" and not _unleash_ready(c):
			uw = "Already used for this Attack action"
		var melee := _melee_options(c)
		if uw == "" and melee.is_empty():
			uw = "No melee attack"
		var first := melee[0] if not melee.is_empty() else {}
		var ue := _entry("unleash_incarnation", "Unleash Incarnation", "%d left · %s from the echo" % [left2, (first["profile"] as WeaponProfile).name if not first.is_empty() else "a melee attack"],
			"free", uw, "enemy", "When you take the Attack action, make one more melee attack, from your echo's space.",
			(first["profile"] as WeaponProfile).reach if not first.is_empty() else 5)
		ue["from_echo"] = true
		if melee.size() > 1:
			var picks: Array = []
			for o in melee:
				picks.append({"value": str(o["id"]), "label": (o["profile"] as WeaponProfile).name})
			ue["choices"] = picks
			ue["choice_label"] = "Weapon"
		out.append(ue)
	if has(c, "echo_avatar"):
		if in_avatar(c):
			out.append(_entry("echo_avatar_end", "End Echo Avatar", "your own senses back", "free", tw, "none",
				"Stop seeing and hearing through your echo (no action)."))
		else:
			out.append(_entry("echo_avatar", "Echo Avatar", "see through the echo · 10 min", "action", aw if aw != "" or not mine.is_empty() else "No echo", "none",
				"Magic action: for up to 10 minutes you see and hear through your echo (you are Blinded and Deafened), and it can be up to 1,000 ft from you."))


## The rider that sends this turn's attacks from the echo's space even when the knight could make them itself.
func rider_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if has(c, "manifest_echo") and not echoes(c).is_empty():
		out.append({"id": RIDER, "label": "Strike from the Echo", "sub": "this turn's attacks come from your echo's space", "why": ""})
	return out


## The knight's melee attacks, the best first (Unleash Incarnation's choices).
func _melee_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in enc().attack_options(c):
		if bool(o["melee"]):
			out.append(o)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["profile"] as WeaponProfile).average_damage() > (b["profile"] as WeaponProfile).average_damage())
	return out


## A hotbar entry aimed from somewhere other than its user ("from": an echo's id; "from_echo": any of the user's
## echoes): "" when `t` is within `rng` of it, else why not. Null when the entry is aimed from its user.
func range_why(c: Combatant, action: Dictionary, t: Combatant, rng: int) -> Variant:
	if bool(action.get("from_echo", false)):
		for echo in echoes(c):
			if enc().distance(echo, t) <= rng:
				return ""
		return "Out of your echo's reach (%d ft)" % rng
	if action.has("from"):
		var src := enc().get_c(str(action["from"]))
		if src == null:
			return "The echo is gone"
		return "" if t == src or enc().distance(src, t) <= rng else "Out of range (%d ft from the echo)" % rng
	return null


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, choice: String = "") -> CombatResult:
	var e := enc()
	var head := id.get_slice(":", 0)
	var arg := id.substr(head.length() + 1) if id.contains(":") else ""
	match head:
		"manifest_echo":
			return _manifest(c, t, cell)
		"echo_move":
			return _move_echo(c, e.get_c(arg), t, cell)
		"echo_swap":
			return _swap_with(c, e.get_c(arg))
		"echo_dismiss":
			var gone := e.get_c(arg)
			if gone == null or not gone.is_alive():
				return CombatResult.fail("The echo is gone")
			c.bonus_available = false
			_ability(gone, "echo_dismiss")
			destroy(gone, "dismissed")
			return CombatResult.new()
		"unleash_incarnation":
			return _unleash(c, t, choice)
		"echo_avatar":
			return _avatar(c)
		"echo_avatar_end":
			end_avatar(c, "%s's senses return" % c.name())
			_ability(c, "echo_avatar_end")
			return CombatResult.new()
	return CombatResult.fail("Not available")


# --- Manifest Echo ----------------------------------------------------------------------------------------------

## A free space for a creature `size` squares across within 5 ft of `t`, the one nearest `near`; (-1, -1) if none.
func free_beside(t: Combatant, near: Vector2i, size: int, except: Array = []) -> Vector2i:
	var e := enc()
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for dx in range(-size, t.size_cells + 1):
		for dz in range(-size, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dz)
			if e.grid.distance_ft(cell, size, t.cell, t.size_cells) > 5 or not e.space_available(cell, size, except):
				continue
			var d := e.grid.distance_ft(cell, size, near, size)
			if d < best_d:
				best_d = d
				best = cell
	return best


func _manifest(c: Combatant, t: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var size := c.size_cells
	var mine := echoes(c)
	var limit := 2 if has(c, "legion_of_one") else 1
	var replaced: Array = mine.duplicate() if mine.size() >= limit else []
	if t != null and t != c:
		cell = free_beside(t, c.cell, size, replaced)
	if cell.x < 0 or not e.space_available(cell, size, replaced):
		return CombatResult.fail("Choose an unoccupied space")
	if e.grid.distance_ft(c.cell, c.size_cells, cell, size) > 15:
		return CombatResult.fail("Within 15 ft of you")
	if not e.can_see_space(c, cell, size):
		return CombatResult.fail("You must see that space")
	c.bonus_available = false
	for old: Combatant in replaced:
		destroy(old, "a new echo takes its place")
	_ability(c, "manifest_echo")
	var echo := _make_echo(c, cell)
	e.log.add("info", "%s calls up an echo of itself (Manifest Echo)" % c.name(), c.id)
	return CombatResult.new() if echo != null else CombatResult.fail("No room for the echo")


## The echo's stat block: the knight's size, type, scores, senses and save bonuses; AC 14 + Proficiency Bonus and
## 1 Hit Point; immune to every condition; no actions, Reactions or Opportunity Attacks of its own. `look_of` tells
## the view to draw it as a ghostly copy of its knight.
func _make_echo(c: Combatant, cell: Vector2i) -> Combatant:
	var e := enc()
	var n := 1
	for o in echoes(c):
		if int(o.get_meta("echo_n", 1)) == 1:
			n = 2
	var pb := c.creature.proficiency_bonus()
	var abilities := {}
	for ab: StringName in Creature.ABILITY_SHORT:
		abilities[str(ab)] = c.creature.ability_score(ab)
	var senses := {}
	if c.creature.darkvision() > 0:
		senses["darkvision"] = c.creature.darkvision()
	for kind: String in ["blindsight", "truesight", "tremorsense"]:
		if c.creature.sense_range(kind) > 0:
			senses[kind] = c.creature.sense_range(kind)
	var data := {"id": "echo", "name": ("%s's Echo" if n == 1 else "%s's Second Echo") % c.name(), "size": str(c.creature.size),
		"type": str(c.creature.creature_type), "ac": 14 + pb, "ac_note": "14 + Proficiency Bonus",
		"hp": {"average": 1, "dice": "1"}, "speed": {"walk": 30, "fly": 30}, "abilities": abilities, "saves": _saves_of(c),
		"senses": senses, "condition_immunities": ALL_CONDITIONS.duplicate(), "cr": 0, "xp": 0, "proficiency_bonus": pb,
		"initiative": 0, "summon": true, "echo": true, "look_of": c.id,
		"traits": [{"id": "echo_image", "name": "Echo", "action": "passive",
			"modifiers": [{"stat": "flag", "value": "no_opportunity_attacks"}, {"stat": "flag", "value": "no_reactions"}],
			"summary": "A translucent image of its knight: it moves only when the knight sends it and acts only through the knight's attacks."}],
		"actions": [], "ai_profile": "brute", "summary": "An echo of a possible self.", "text": "Manifest Echo."}
	var m := Monster.from_data(data)
	m.name = str(data["name"])
	var echo := e.add(m, &"guest" if c.side == &"party" else c.side, cell)
	echo.controller = c.controller
	echo.set_meta("echo_of", c.id)
	echo.set_meta("echo_n", n)
	echo.set_meta("vanishes", true)
	echo.reaction_available = false
	e.events.append({"type": "summon_creature", "id": echo.id, "cell": cell, "caster": c.id})
	return echo


## The knight's saving throw bonuses as they stand, for its echoes.
static func _saves_of(c: Combatant) -> Dictionary:
	var out := {}
	for ab: StringName in Creature.ABILITY_SHORT:
		out[str(ab)] = c.creature.save_bonus(ab).total()
	return out


## The echo fades: dismissed, replaced, too far away, or its knight Incapacitated.
func destroy(echo: Combatant, why: String) -> void:
	if echo == null or not echo.is_alive():
		return
	var e := enc()
	var knight := knight_of(echo)
	echo.creature.dead = true
	e.log.add("info", "%s fades (%s)" % [echo.name(), why], echo.id)
	e.events.append({"type": "vanish", "id": echo.id})
	if knight != null:
		_lost_one(knight)


## With no echo left, Echo Avatar has nothing to see through.
func _lost_one(knight: Combatant) -> void:
	if echoes(knight).is_empty() and in_avatar(knight):
		end_avatar(knight, "its echo is gone")


func move_left(echo: Combatant) -> int:
	var rec := _moved.get(echo.id, {}) as Dictionary
	return 30 - (int(rec.get("feet", 0)) if str(rec.get("turn", "")) == _turn_key() else 0)


## On the knight's turn the echo goes up to 30 ft in any direction (it flies; no Opportunity Attacks). Choosing a
## creature sends it to the nearest space beside it.
func _move_echo(c: Combatant, echo: Combatant, t: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	if echo == null or not echo.is_alive():
		return CombatResult.fail("The echo is gone")
	var left := move_left(echo)
	var reach := e.reachable_for(echo, left)
	if t != null and t != echo:
		var best := Vector2i(-1, -1)
		var best_cost := 1 << 30
		for sq: Vector2i in reach:
			var info := reach[sq] as Dictionary
			if bool(info["occupied"]) or e.grid.distance_ft(sq, echo.size_cells, t.cell, t.size_cells) > 5:
				continue
			if int(info["cost"]) < best_cost:
				best_cost = int(info["cost"])
				best = sq
		cell = best
	if cell.x < 0 or not reach.has(cell) or cell == echo.cell:
		return CombatResult.fail("The echo can't get there with %d ft" % left)
	if bool((reach[cell] as Dictionary)["occupied"]):
		return CombatResult.fail("The echo can't end in an occupied space")
	var path := CombatGrid.path_to(reach, cell)
	_ability(c, "echo_move", [echo])
	var spent := int((reach[cell] as Dictionary)["cost"])
	for i in range(1, path.size()):
		var from := echo.cell
		echo.cell = path[i]
		e.events.append({"type": "move", "id": echo.id, "from": from, "to": path[i]})
		e._after_step(echo, from)
		if not echo.is_alive():
			break
	_moved[echo.id] = {"turn": _turn_key(), "feet": 30 - left + spent}
	return CombatResult.new()


func _swap_with(c: Combatant, echo: Combatant) -> CombatResult:
	var e := enc()
	if echo == null or not echo.is_alive():
		return CombatResult.fail("The echo is gone")
	c.bonus_available = false
	c.movement_left -= 15
	_ability(c, "echo_swap", [echo])
	var a := c.cell
	c.cell = echo.cell
	echo.cell = a
	c.clear_run()
	e.events.append({"type": "teleport", "id": c.id, "from": a, "to": c.cell})
	e.events.append({"type": "teleport", "id": echo.id, "from": c.cell, "to": a})
	e.spells.zones.on_moved(c, a)
	e.spells.zones.on_moved(echo, c.cell)
	e.log.add("move", "%s trades places with its echo" % c.name(), c.id)
	return CombatResult.new()


# --- Attacking from the echo ------------------------------------------------------------------------------------

func _swap_cells(a: Combatant, b: Combatant) -> void:
	var keep := a.cell
	a.cell = b.cell
	b.cell = keep


## Why `c` can't make `option`'s attack on `target` standing in `echo`'s space, or "".
func legal_from(c: Combatant, echo: Combatant, target: Combatant, option: Dictionary) -> String:
	_swap_cells(c, echo)
	var why := enc().attack_legal(c, target, option)
	_swap_cells(c, echo)
	return why


## Where an attack of `c`'s Attack action on `target` comes from: one of its echoes, or null for its own space. The
## echo serves when Strike from the Echo is armed or when only the echo's space reaches the target.
func attack_origin(c: Combatant, target: Combatant, option: Dictionary) -> Combatant:
	if not has(c, "manifest_echo") or target == null or option.is_empty() or str(target.get_meta("echo_of", "")) == c.id:
		return null
	var mine := echoes(c)
	if mine.is_empty():
		return null
	if not RIDER in c.armed and enc().attack_legal(c, target, option) == "":
		return null
	for echo in mine:
		if legal_from(c, echo, target, option) == "":
			return echo
	return null


## Why `c` can't make this attack, counting its echoes' spaces when it is part of the Attack action; "" if it can.
func attack_why(c: Combatant, target: Combatant, option: Dictionary, attack_action: bool) -> String:
	var own := enc().attack_legal(c, target, option)
	if not attack_action or not has(c, "manifest_echo") or target == null:
		return own
	var mine := echoes(c)
	if mine.is_empty():
		return own
	if attack_origin(c, target, option) != null:
		return ""
	if RIDER in c.armed:
		return "From your echo: %s" % legal_from(c, mine[0], target, option)
	return own


## The hit chance for the target tooltip, from the space the attack would come from ("from": the echo's name).
func hit_chance(c: Combatant, target: Combatant, option: Dictionary, attack_action: bool) -> Dictionary:
	var echo := attack_origin(c, target, option) if attack_action else null
	if echo == null:
		return enc().hit_chance(c, target, option)
	_swap_cells(c, echo)
	var hc := enc().hit_chance(c, target, option)
	_swap_cells(c, echo)
	hc["from"] = echo.name()
	return hc


## The id of the echo `c` is striking from right now, or "" (attack events name it for the view).
static func striking_from(c: Combatant) -> String:
	return str(c.get_meta("strike_from", c.id)) if c != null else ""


## Runs `fn` (an attack) as if `c` stood in `echo`'s space: the two trade squares until the attack and every
## prompt it pauses on are done. With no echo it just runs `fn`.
func strike(c: Combatant, echo: Combatant, fn: Callable) -> CombatResult:
	if echo == null:
		return fn.call() as CombatResult
	var home := c.cell
	var there := echo.cell
	_swap_cells(c, echo)
	c.set_meta("strike_from", echo.id)
	return _after_strike(fn.call() as CombatResult, c, echo, home, there)


func _after_strike(r: CombatResult, c: Combatant, echo: Combatant, home: Vector2i, there: Vector2i) -> CombatResult:
	var e := enc()
	if e.pending == null:
		# Back to their own squares (a creature shoved or teleported meanwhile stays where it went).
		if c.cell == there:
			c.cell = home
		if echo.cell == home:
			echo.cell = there
		c.remove_meta("strike_from")
		return r
	var req := e.pending
	var inner := req.continuation
	req.continuation = func(use: bool) -> CombatResult:
		return _after_strike(inner.call(use) as CombatResult, c, echo, home, there)
	r.pending = req
	return r


## Counts an Attack action `c` just took (Unleash Incarnation: one extra attack each).
func attack_action_taken(c: Combatant) -> void:
	if has(c, "unleash_incarnation"):
		var rec := _rec(c)
		rec["taken"] = int(rec["taken"]) + 1


func _rec(c: Combatant) -> Dictionary:
	var rec := _attack_actions.get(c.id, {}) as Dictionary
	if str(rec.get("turn", "")) != _turn_key():
		rec = {"turn": _turn_key(), "taken": 0, "unleashed": 0}
		_attack_actions[c.id] = rec
	return rec


func _unleash_ready(c: Combatant) -> bool:
	var rec := _rec(c)
	return int(rec["unleashed"]) < maxi(1 if c.took_attack_action else 0, int(rec["taken"]))


## Unleash Incarnation: one more melee attack, from whichever echo reaches the target.
func _unleash(c: Combatant, t: Combatant, choice: String) -> CombatResult:
	var e := enc()
	if t == null or t == c or (is_echo(t) and knight_of(t) == c):
		return CombatResult.fail("Choose a creature to attack")
	var option := e.option_by_id(c, choice) if choice != "" else {}
	if option.is_empty():
		var melee := _melee_options(c)
		option = melee[0] if not melee.is_empty() else {}
	if option.is_empty() or not bool(option["melee"]):
		return CombatResult.fail("Needs a melee attack")
	var from: Combatant = null
	var why := "Your echo can't reach %s" % t.name()
	for echo in echoes(c):
		var w := legal_from(c, echo, t, option)
		if w == "":
			from = echo
			break
		why = w
	if from == null:
		return CombatResult.fail(why)
	var sanct := e.spells.sanctuary_blocks(c, t)
	if sanct != "":
		return CombatResult.fail(sanct)
	_ch(c).spend_resource("unleash_incarnation")
	var rec := _rec(c)
	rec["unleashed"] = int(rec["unleashed"]) + 1
	_ability(from, "unleash_incarnation", [t])
	e.log.add("info", "%s's echo strikes at %s (Unleash Incarnation)" % [c.name(), t.name()], c.id)
	return strike(c, from, func() -> CombatResult: return e._resolve_attack(c, t, option, {}))


# --- Opportunity Attacks from the echo ---------------------------------------------------------------------------

## Knights whose echo `mover` is leaving (from `from` to `to`, out of the echo's 5-ft reach), added to `out`; each
## is told which echo through OA_META.
func provokers(mover: Combatant, from: Vector2i, to: Vector2i, out: Array[Combatant]) -> void:
	var e := enc()
	if is_echo(mover):
		return
	for k in e.hostiles_of(mover):
		if not has(k, "manifest_echo"):
			continue
		k.remove_meta(OA_META)
		if k in out or mover.disengaged or not e.spells.can_react(k) or not e.can_see(k, mover):
			continue
		for echo in echoes(k):
			var before := e.grid.distance_ft(echo.cell, echo.size_cells, from, mover.size_cells)
			var after := e.grid.distance_ft(echo.cell, echo.size_cells, to, mover.size_cells)
			if before <= 5 and after > 5:
				k.set_meta(OA_META, {"target": mover.id, "echo": echo.id})
				out.append(k)
				break


## The echo `p`'s Opportunity Attack on `target` comes from, or null for `p`'s own space.
func oa_origin(p: Combatant, target: Combatant) -> Combatant:
	if not p.has_meta(OA_META):
		return null
	var m := p.get_meta(OA_META) as Dictionary
	p.remove_meta(OA_META)
	if str(m.get("target", "")) != target.id:
		return null
	var echo := enc().get_c(str(m.get("echo", "")))
	return echo if echo != null and echo.is_alive() else null


## Whose reach `mover` is leaving, for the Opportunity Attack prompt.
func reach_name(p: Combatant, mover: Combatant) -> String:
	if p.has_meta(OA_META) and str((p.get_meta(OA_META) as Dictionary).get("target", "")) == mover.id:
		var echo := enc().get_c(str((p.get_meta(OA_META) as Dictionary).get("echo", "")))
		if echo != null:
			return echo.name()
	return p.name()


# --- Shadow Martyr --------------------------------------------------------------------------------------------------

func _martyr_ready(k: Combatant, attacker: Combatant, target: Combatant) -> bool:
	var e := enc()
	var ch := _ch(k)
	if ch == null or target == null or target == k or is_echo(target) or attacker == k or k.hostile_to(target):
		return false
	if ch.resource_left("shadow_martyr") <= 0 and ch.resource_left("unleash_incarnation") <= 0:
		return false
	if not e.spells.can_react(k) or not e.can_see(k, target):
		return false
	var mine := echoes(k)
	return not mine.is_empty() and free_beside(target, mine[0].cell, mine[0].size_cells).x >= 0


func _martyr_cost(k: Combatant) -> String:
	return "Reaction and Shadow Martyr" if _ch(k).resource_left("shadow_martyr") > 0 else "Reaction and a use of Unleash Incarnation"


## Offers before an attack roll (Encounter._resolve_attack, and SpellCaster._before_attack_rolls for a spell's
## rolls): each Echo Knight who could send its echo in.
func before_roll(st: Dictionary) -> Array:
	var out: Array = []
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	for k in e.living():
		if not has(k, "shadow_martyr") or not _martyr_ready(k, c, target):
			continue
		var kk := k
		out.append({"kind": "shadow_martyr", "reactor": k, "trigger": c.id, "title": "Reaction: Shadow Martyr?",
			"text": "%s attacks %s. Send your echo to take the attack in its place (AC %d, 1 Hit Point)?" % [c.name(), target.name(), echoes(k)[0].creature.ac_value()],
			"cost": _martyr_cost(k),
			"still": func() -> bool: return _martyr_ready(kk, c, st["target"] as Combatant),
			"use": func() -> void:
				var echo := _martyr(kk, st["target"] as Combatant)
				if echo == null:
					return
				st["target"] = echo
				# Before a spell's roll (SpellCaster._before_attack_rolls) the spell works the rest out itself.
				if bool(st.get("pre_roll", false)):
					return
				var sit := e.attack_situation(c, echo, st["option"] as Dictionary)
				var old := st["sit"] as Dictionary
				for key: String in ["advantage", "disadvantage"]:
					(old[key] as Array).clear()
					(old[key] as Array).append_array(sit[key] as Array)
				for key2: String in ["cover", "cover_bonus", "cover_by"]:
					old[key2] = sit[key2]
				st["ac"] = echo.creature.ac_value() + int(sit["cover_bonus"])})
	return out


## Shadow Martyr against a spell attack roll made where the game can't pause (a Chromatic Orb's leap; a spell's own
## rolls are offered first in SpellCaster._before_attack_rolls): the echo takes it only for a knight whose rule for it
## is Automatic. Returns the creature the roll is made against.
func spell_redirect(c: Combatant, t: Combatant) -> Combatant:
	var e := enc()
	for k in e.living():
		if has(k, "shadow_martyr") and _martyr_ready(k, c, t) and e._reaction_decision(k, "shadow_martyr") == "auto":
			var echo := _martyr(k, t)
			if echo != null:
				return echo
	return t


## The echo nearest `target` leaps into a free space beside it; Reaction and a use spent. Returns the echo.
func _martyr(k: Combatant, target: Combatant) -> Combatant:
	var e := enc()
	var ch := _ch(k)
	var echo: Combatant = null
	for o in echoes(k):
		if echo == null or e.distance(o, target) < e.distance(echo, target):
			echo = o
	if echo == null:
		return null
	var cell := free_beside(target, echo.cell, echo.size_cells)
	if cell.x < 0:
		return null
	k.reaction_available = false
	if ch.resource_left("shadow_martyr") > 0:
		ch.spend_resource("shadow_martyr")
	else:
		ch.spend_resource("unleash_incarnation")
	_ability(echo, "shadow_martyr", [target])
	var from := echo.cell
	echo.cell = cell
	e.events.append({"type": "teleport", "id": echo.id, "from": from, "to": cell})
	e.spells.zones.on_moved(echo, from)
	e.log.add("reaction", "%s's echo throws itself in front of %s (Shadow Martyr)" % [k.name(), target.name()], k.id)
	return echo


# --- Echo Avatar ----------------------------------------------------------------------------------------------------

func in_avatar(c: Combatant) -> bool:
	for fx: Effect in c.creature.effects:
		if fx.source_id == "echo_avatar":
			return true
	return false


## While in Echo Avatar the knight sees through its echoes instead of its own eyes (Encounter.can_see).
func echo_sees(c: Combatant, b: Combatant) -> bool:
	for echo in echoes(c):
		if echo == b or enc().can_see(echo, b):
			return true
	return false


func _avatar(c: Combatant) -> CombatResult:
	var e := enc()
	if echoes(c).is_empty():
		return CombatResult.fail("No echo")
	e.spend_action(c)
	c.magic_action_used = true
	var fx := Effect.new("Echo Avatar", &"feature", "echo_avatar").with_condition(&"blinded").with_condition(&"deafened")
	fx.caster_id = c.id
	fx.lasting({"kind": "minutes", "amount": 10})
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)
	_ability(c, "echo_avatar", echoes(c))
	e.log.add("info", "%s looks out through its echo's eyes (Echo Avatar)" % c.name(), c.id)
	e.events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


func end_avatar(c: Combatant, why: String) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == "echo_avatar":
			c.creature.remove_effect(fx)
			enc().log.add("info", "Echo Avatar ends: %s" % why, c.id)
			enc().events.append({"type": "condition", "id": c.id})


# --- Turns, damage and Initiative -----------------------------------------------------------------------------------

## The knight's turn starts: its echoes use its save bonuses as they are now; an Incapacitated knight loses them.
func turn_start(c: Combatant) -> void:
	if not has(c, "manifest_echo"):
		return
	for echo in echoes(c):
		((echo.creature as Monster).data as Dictionary)["saves"] = _saves_of(c)
	check(c)


## The knight's turn ends: an echo more than 30 ft away (1,000 ft in Echo Avatar) fades.
func turn_end(c: Combatant) -> void:
	if not has(c, "manifest_echo"):
		return
	var limit := 1000 if in_avatar(c) else 30
	for echo in echoes(c):
		if enc().distance(c, echo) > limit:
			destroy(echo, "more than %d ft from %s" % [limit, c.name()])


## An Incapacitated (or downed) knight's echoes fade.
func check(c: Combatant) -> void:
	if c != null and not c.can_act() and has(c, "manifest_echo"):
		for echo in echoes(c):
			destroy(echo, "%s is Incapacitated" % c.name())


## An effect landed on a creature (a condition that Incapacitates).
func effect_added(cr: Creature, _fx: Effect) -> void:
	if cr is Character:
		check(enc().get_c(cr.id))


func after_damage(_source: Combatant, target: Combatant) -> void:
	check(target)


## Reclaim Potential: an echo destroyed by damage gives its knight 2d6 + Con Temporary Hit Points (if it has none).
func on_death(_source: Combatant, dead: Combatant) -> void:
	if not is_echo(dead):
		return
	var e := enc()
	var k := knight_of(dead)
	if k == null:
		return
	var ch := _ch(k)
	if has(k, "reclaim_potential") and ch != null and ch.resource_left("reclaim_potential") > 0 and k.is_alive() \
			and k.creature.temp_hp <= 0 and str(k.reaction_rules.get("reclaim_potential", "auto")) != "never":
		ch.spend_resource("reclaim_potential")
		var rolled := e._roll_damage_dice("2d6", false, 0, "Reclaim Potential")
		var amount := int(rolled["total"]) + k.creature.ability_mod(&"con")
		if k.creature.add_temp_hp(amount, "Reclaim Potential"):
			_ability(k, "reclaim_potential")
			e.log.add("heal", "%s reclaims %d Temporary Hit Points from its broken echo (Reclaim Potential)" % [k.name(), amount], k.id, [str(rolled["text"])])
	_lost_one(k)


## Legion of One: a knight who rolls Initiative with no Unleash Incarnation left gets one back.
func initiative_rolled() -> void:
	var e := enc()
	for c in e.combatants:
		var ch := _ch(c)
		if has(c, "legion_of_one") and ch != null and ch.resource_left("unleash_incarnation") <= 0:
			_restore_one(ch, "unleash_incarnation")
			_ability(c, "legion_of_one")
			e.log.add("info", "%s regains a use of Unleash Incarnation (Legion of One)" % c.name(), c.id)
