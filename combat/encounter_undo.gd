class_name EncounterUndo
extends RefCounted
## Taking back a move (Encounter): a player-controlled creature's move on its own turn (move, free_move, jump) can be
## undone while nothing came of it: no die was rolled, no reaction was offered (even one declined or passed up),
## nothing was queued, no other creature, zone, spell object, mark or grapple changed, nothing was logged but the move's
## own lines, and nothing new was seen (the mover wasn't spotted, and no foe the party couldn't see before is in sight).
## Undos stack: the last move comes back first, back to the last thing that wasn't a move. Anything else (an attack, a
## spell, an item, Dash, a feature, a reaction, the turn ending) ends them: the fight as it stood after the last move is
## kept with the stack, and any difference at undo time means something else happened. Not saved (fights save at the
## start of a round); the AI never uses it.

## Combatant variables an undo leaves alone: the player's settings and choices, which no move changes (reaction rules,
## riders armed for the next hit), so changing them after a move doesn't stop it being taken back.
const KEEP: Array[String] = ["reaction_rules", "armed"]
## Effects that follow from where creatures stand (an Aura of Protection, an area's effect on whoever is inside, a
## caster beside its object): a move may change them on anyone, and they're worked out again after an undo.
const DERIVED: Array[String] = ["aura:", "zone:", "near:"]


## A move as it began: what it can change on the creatures it moves, and the fight around them.
class Record:
	extends RefCounted
	## The walk's `handled` (EncounterMovement._walk): `willing`, and a key for each reaction a step set off.
	var handled: Dictionary = {"willing": true}
	## Null when the move can't be taken back (the AI's, or not on the mover's own turn).
	var mover: Combatant = null
	## The mover, and the mount carrying it or the rider it carries; `saved` holds each as it was.
	var who: Array[Combatant] = []
	var saved: Array[Dictionary] = []
	## The fight before the move (EncounterUndo._state), the foes the party could see, and the log's length.
	var before: Dictionary = {}
	var seen: Dictionary = {}
	var log_size: int = 0


var _enc: WeakRef
## Moves that can still be taken back, the last at the end.
var _stack: Array[Record] = []
## The fight right after the last move recorded or taken back.
var _after: Dictionary = {}
## Why the last move couldn't be taken back, and on which turn ("round:turn:mover"), for the banner.
var _blocked: String = ""
var _blocked_on: String = ""


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


# --- Commands ---------------------------------------------------------------------------------------

## Whether `c` can take back its last move now.
func can_undo_move(c: Combatant) -> bool:
	return not _stack.is_empty() and _stack[_stack.size() - 1].mover == c and _player_turn(c) and _state() == _after


## Puts the mover (and its mount or rider) back as it was before its last move: square, movement, standing or Prone,
## everything the move changed. The token goes back (a `move` event with `undo`).
func undo_move(c: Combatant) -> CombatResult:
	var e := enc()
	if not can_undo_move(c):
		if _blocked != "" and _blocked_on == _turn_key(c):
			return CombatResult.fail("That move can't be taken back: %s" % _blocked)
		return CombatResult.fail("No move to take back")
	var rec := _stack.pop_back() as Record
	var moves: Array[Dictionary] = []
	var changed: Array[Dictionary] = []
	for i in rec.who.size():
		var m := rec.who[i]
		var from := m.cell
		var conditions := m.creature.conditions.duplicate(true)
		_put_back(m, rec.saved[i])
		if m.cell != from:
			var ev := {"type": "move", "id": m.id, "from": from, "to": m.cell, "undo": true}
			# A rider rides along (the view doesn't wait for its token), so it goes first.
			if e.mount_of(m) != null:
				ev["mounted"] = true
				moves.push_front(ev)
			else:
				moves.append(ev)
		if m.creature.conditions != conditions:
			changed.append({"type": "condition", "id": m.id})
	e.events.append_array(moves)
	e.events.append_array(changed)
	e.spells.zones.refresh_auras()
	e.log.add("move", "%s takes back the move" % c.name(), c.id)
	_after = _state()
	return CombatResult.new()


# --- Recording (EncounterMovement's move, free_move and jump) ---------------------------------------------------

## Called as a move begins: the record whose `handled` the walk fills in, for after_move.
func before_move(c: Combatant) -> Record:
	var rec := Record.new()
	if not _player_turn(c):
		return rec
	rec.mover = c
	rec.who = _riding(c)
	for m in rec.who:
		rec.saved.append(_save(m))
	rec.before = _state()
	rec.seen = _seen()
	rec.log_size = enc().log.entries.size()
	return rec


## Called as the move ends, with its result `r` (passed back): the move goes on the stack if nothing came of it;
## otherwise the stack ends there. A move that changed nothing leaves the stack as it was.
func after_move(rec: Record, r: CombatResult) -> CombatResult:
	if rec.mover == null:
		return r
	var now := _state()
	if now == rec.before and enc().log.entries.size() == rec.log_size:
		return r
	var why := _came_of(rec, r, now)
	if why != "":
		_stack.clear()
		_after = {}
		_blocked = why
		_blocked_on = _turn_key(rec.mover)
		return r
	# Something else happened since the moves on the stack: they can't be taken back past it.
	if not _stack.is_empty() and rec.before != _after:
		_stack.clear()
	_stack.append(rec)
	_after = now
	_blocked = ""
	return r


## What came of the move besides itself, as the reason it can't be taken back; "" when nothing did.
func _came_of(rec: Record, r: CombatResult, now: Dictionary) -> String:
	var e := enc()
	if r.pending != null or e.pending != null or rec.handled.size() > 1:
		return "it gave someone a chance to react"
	var fight_was := rec.before["fight"] as Dictionary
	var fight_now := now["fight"] as Dictionary
	if fight_was["dice"] != fight_now["dice"]:
		return "dice were rolled"
	var was := rec.before["who"] as Dictionary
	var is_now := now["who"] as Dictionary
	var ids: Array[String] = []
	for m in rec.who:
		ids.append(m.id)
		if ((was[m.id] as Dictionary)["vars"] as Dictionary)["hidden"] != ((is_now[m.id] as Dictionary)["vars"] as Dictionary)["hidden"]:
			return "%s was spotted" % m.name()
	for q in e.living():
		if not q.is_player_controlled() and not rec.seen.has(q.id) and _in_sight(q):
			return "it brought something new into sight"
	if fight_was != fight_now or was.size() != is_now.size():
		return "something else happened along the way"
	for id: String in was:
		if not is_now.has(id):
			return "something else happened along the way"
		var a := was[id] as Dictionary
		var b := is_now[id] as Dictionary
		if not id in ids:
			if a != b:
				return "something else happened along the way"
			continue
		# The movers themselves: their variables, metas and conditions may change (an undo puts them back); their
		# Hit Points, resources, Concentration and effects may not.
		var ca := a["creature"] as Dictionary
		var cb := b["creature"] as Dictionary
		if ca["state"] != cb["state"] or ca["effects"] != cb["effects"]:
			return "something else happened along the way"
	for i in range(rec.log_size, e.log.entries.size()):
		var line := e.log.entries[i]
		if str(line["kind"]) != "move" or not str(line["actor"]) in ids:
			return "something else happened along the way"
	return ""


# --- What a move changes, and the fight around it ----------------------------------------------------------------

## Only a player-controlled creature's own moves on its own turn (not one the AI plays for it under Command or fear).
func _player_turn(c: Combatant) -> bool:
	var e := enc()
	return c.is_player_controlled() and c == e.current() and e.state == Encounter.State.ACTIVE and e.pending == null \
		and not e.compelled(c)


func _turn_key(c: Combatant) -> String:
	var e := enc()
	return "%d:%d:%s" % [e.round_no, e.turn_index, c.id]


## The mover and whoever moves with it: the mount carrying it, or the rider it carries.
func _riding(c: Combatant) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = [c]
	var partner := e.mount_of(c) if e.mount_of(c) != null else e.rider_of(c)
	if partner != null:
		out.append(partner)
	return out


## The whole fight, to compare: every combatant (_combatant) and the fight's own state (dice, the reaction prompt and
## queues, marks, grapples, what was studied, zones and spell objects, the turn order and turn).
func _state() -> Dictionary:
	var e := enc()
	var who := {}
	for c in e.combatants:
		who[c.id] = _combatant(c)
	var order: Array[String] = []
	for o in e.order:
		order.append(o.id)
	return {"who": who, "fight": {"state": e.state, "round": e.round_no, "turn": e.turn_index, "order": order,
		"dice": e.dice.get_state(), "pending": e.pending != null, "queued": [e.reaction_queue.duplicate(true),
		e.cleave_queue.duplicate(true)], "marks": e.marks.duplicate(true), "grapples": e.grapples.duplicate(true),
		"studied": e.studied.duplicate(true), "spells": e.spells.to_dict()}}


## A combatant to compare: its variables and metas, and its creature's state (what a save keeps, spell slots, Heroic
## Inspiration and the pack), conditions, and effects but the ones where it stands gives it (DERIVED), each with what
## it holds.
static func _combatant(c: Combatant) -> Dictionary:
	var cr := c.creature
	var st := cr.state_to_dict()
	st.erase("conditions")
	st.erase("effects")
	if cr is Character:
		var ch := cr as Character
		st["spent"] = [ch.slots_used.duplicate(), ch.pact_slots_used, ch.heroic_inspiration, ch.inventory.duplicate(true)]
	var fx: Array = []
	for f in cr.effects:
		if not _derived(f):
			fx.append([f, f.to_dict()])
	return {"vars": _vars(c), "metas": _metas(c),
		"creature": {"state": st, "conditions": cr.conditions.duplicate(true), "effects": fx}}


## What an undo puts back on a creature: its variables, metas, conditions and effects.
static func _save(c: Combatant) -> Dictionary:
	return {"vars": _vars(c), "metas": _metas(c), "conditions": c.creature.conditions.duplicate(true),
		"effects": c.creature.effects.duplicate()}


static func _put_back(c: Combatant, s: Dictionary) -> void:
	var vars := s["vars"] as Dictionary
	for key: String in vars:
		c.set(key, _copy(vars[key]))
	var metas := s["metas"] as Dictionary
	for k: StringName in c.get_meta_list():
		if not metas.has(k):
			c.remove_meta(k)
	for k2: StringName in metas:
		c.set_meta(k2, _copy(metas[k2]))
	c.creature.conditions = (s["conditions"] as Dictionary).duplicate(true)
	c.creature.effects.assign(s["effects"] as Array)


## Every script variable of the combatant but KEEP, read generically: a field added later (an altitude) is covered too.
static func _vars(c: Combatant) -> Dictionary:
	var out := {}
	for p: Dictionary in c.get_property_list():
		var key := str(p["name"])
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not key in KEEP:
			out[key] = _copy(c.get(key))
	return out


## Feature and turn state kept on the combatant (jumped_round, mounted_on...).
static func _metas(c: Combatant) -> Dictionary:
	var out := {}
	for k: StringName in c.get_meta_list():
		out[k] = _copy(c.get_meta(k))
	return out


static func _copy(v: Variant) -> Variant:
	if v is Array:
		return (v as Array).duplicate(true)
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return v


static func _derived(f: Effect) -> bool:
	for prefix in DERIVED:
		if f.stack_key.begins_with(prefix):
			return true
	return false


## The foes (creatures the player doesn't control) some player-controlled creature can see: id -> true.
func _seen() -> Dictionary:
	var out := {}
	for q in enc().living():
		if not q.is_player_controlled() and _in_sight(q):
			out[q.id] = true
	return out


func _in_sight(q: Combatant) -> bool:
	var e := enc()
	for p in e.living():
		if p.is_player_controlled() and e.can_see(p, q):
			return true
	return false
