class_name ObjectActions
extends RefCounted
## What creatures do with the battlefield's objects (F5 piece 3, the owner's Baldur's Gate 3 picks; the rulings are in
## deviations.md), owned by EncounterObjects as `actions`:
## - Doors open and shut with the free object interaction (2024 PHB: one on a turn; past that, the Utilize action, or a
##   Thief's Fast Hands Bonus Action). A locked door stays shut; a door the story watches isn't a door object at all
##   (BattleScenery) and stays shut.
## - Shoving: one attack of the Attack action and a Strength (Athletics) check against the thing's DC push a crate, a
##   barrel or a cart 5 ft straight away. Into a creature on the floor it stops, and the creature makes a Strength or
##   Dexterity save against the shover's Shove DC or takes a knock and falls Prone; down a ledge 10 ft or more it falls
##   (1d6 per 10 ft, onto whoever stands below); over a map's open drop or into deep water it's gone.
## - Toppling: the Utilize action and a Strength (Athletics) check push a bookcase, a statue or a brazier over, across
##   the squares straight away from the pusher (one standing against a wall is pulled down the other way, the puller
##   stepping clear): each creature on the floor there makes a Dexterity save or takes the damage and falls Prone, the
##   objects there take it too, and it leaves rubble (a brazier, burning coals).
## - Throwing: a thing lying within 5 ft, or a small object standing there, thrown as one attack of the Attack action,
##   picked up with the free object interaction: a thrown weapon as itself, anything else as an improvised weapon (the
##   owner's numbers: 1d4, 20/60 ft; no Proficiency Bonus without proficiency in improvised weapons, which Tavern
##   Brawler gives). These are attack options (EncounterWeapons).
## Creatures flying or floating aren't hit by what's shoved or pushed over (a flyer is above it). The AI doesn't do any
## of this.

const REACH := 5
## Improvised weapons (the owner's numbers): the die, and a thrown one's range.
const IMPROVISED_DIE := "1d4"
const IMPROVISED_RANGE: Array[int] = [20, 60]
## The knock a shoved object gives the creature it hits, by the object's size.
const KNOCK := {"tiny": "1d4", "small": "1d4", "medium": "1d6", "large": "2d6"}
## The Dexterity save against something shoved off a ledge onto you (as a falling chandelier's).
const FALL_DC := 12

var _enc: WeakRef


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func objs() -> EncounterObjects:
	return enc().objects


# --- Doors --------------------------------------------------------------------------------------------

## "" if `c` can open door `o` (or shut it, when it stands open) now, otherwise why not.
func door_why(c: Combatant, o: BattleObject) -> String:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if o == null or o.destroyed or not o.is_door():
		return "No door there"
	if objs().distance_ft(c, o) > REACH:
		return "Out of reach: move within 5 ft"
	if not o.open and o.locked:
		return "Locked"
	if o.open:
		for cell in o.cells:
			var who := e.occupant_at(cell)
			if who != null:
				return "%s stands in the doorway" % who.name()
	if e.ground.cost_of(c) == "":
		return "No object interaction or action left"
	return ""


## Opens or shuts door `oid`: the free object interaction, else what an interaction costs now (_spend_interaction).
func toggle_door(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := door_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	var cost := _spend_interaction(c)
	set_door(o, not o.open)
	e.log.add("move", "%s %s %s%s" % [c.name(), "opens" if o.open else "shuts", o.the(), _how(cost)], c.id)
	return CombatResult.new()


## Door `o` stands open (its squares no longer a wall) or shut.
func set_door(o: BattleObject, open: bool) -> void:
	var e := enc()
	o.open = open
	for cell in o.cells:
		e.grid.set_flag(cell, CombatGrid.WALL, not open)
	e._cover_cache.clear()
	e.events.append({"type": "object_door", "id": o.id, "open": open})


## Spends what an object interaction costs `c` now (GroundItems.cost_of): "free", "bonus" (Fast Hands) or "action"
## (Utilize).
func _spend_interaction(c: Combatant) -> String:
	var e := enc()
	var cost := e.ground.cost_of(c)
	match cost:
		"free":
			c.free_interaction_available = false
		"bonus":
			c.bonus_available = false
		"action":
			e.spend_action(c)
	return cost


static func _how(cost: String) -> String:
	return {"bonus": " (Fast Hands)", "action": " (Utilize)"}.get(cost, "") as String


# --- Shoving and toppling -----------------------------------------------------------------------------

## The checks every way of handling an object shares: `c`'s turn, `c` can act, `o` is one square standing within 5 ft.
func _reach_why(c: Combatant, o: BattleObject) -> String:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	if o == null or o.destroyed or o.hangs or o.holds != "" or o.cells.size() != 1 or o.is_door():
		return "Nothing to move there"
	if objs().distance_ft(c, o) > REACH:
		return "Out of reach: move within 5 ft"
	return ""


## Straight away from `c` through `o`: the nearest of the eight directions.
func away(c: Combatant, o: BattleObject) -> Vector2i:
	var aim := (Vector2(o.cells[0]) + Vector2(0.5, 0.5)) - enc().center_of(c)
	if aim.length() < 0.01:
		return Vector2i(1, 0)
	var ang := snappedf(aim.angle(), PI / 4.0)
	return Vector2i(roundi(cos(ang)), roundi(sin(ang)))


## Where a shove from `c` sends `o`: {cell, who (the creature there), fall (feet it drops), gone ("drop" over the map's
## open drop, "water" into deep water), why (why it can't go; "" if it can)}.
func shove_to(c: Combatant, o: BattleObject) -> Dictionary:
	var e := enc()
	var g := e.grid
	var from := o.cells[0]
	var d := away(c, o)
	var to := from + d
	var out := {"cell": to, "who": null, "fall": 0, "gone": "", "why": ""}
	var corner := false
	if d.x != 0 and d.y != 0:
		for side: Vector2i in [from + Vector2i(d.x, 0), from + Vector2i(0, d.y)]:
			corner = corner or (g.flags(side) & (CombatGrid.WALL | CombatGrid.LOW | CombatGrid.VOID)) != 0
	if not g.in_bounds(to):
		out["why"] = "Nowhere to push it"
	elif corner:
		out["why"] = "It can't go round the corner"
	elif g.drop_at(to) > 0:
		out["gone"] = "drop"
	elif (g.flags(to) & (CombatGrid.VOID | CombatGrid.WATER)) == (CombatGrid.VOID | CombatGrid.WATER):
		out["gone"] = "water"
	elif g.has_flag(to, CombatGrid.WALL) or g.has_flag(to, CombatGrid.VOID):
		out["why"] = "A wall is in the way"
	elif g.has_flag(to, CombatGrid.LOW) or objs().blocking_at(to) != null:
		out["why"] = "Something is in the way"
	else:
		var rise := g.height(to) - g.height(from)
		if rise > CombatGrid.FEET:
			out["why"] = "The ground rises too high there"
		else:
			out["fall"] = -rise if rise < -CombatGrid.FEET else 0
			out["who"] = objs().on_floor(to)   # one flying over the square is above it
	return out


## "" if `c` can shove `o` now, otherwise why not.
func shove_why(c: Combatant, o: BattleObject) -> String:
	var why := _reach_why(c, o)
	if why != "":
		return why
	if o.moves != "shove":
		return "Too heavy or fixed to shove"
	if c.attacks_left <= 0 and not c.action_available:
		return "No attacks left this turn"
	return str(shove_to(c, o)["why"])


## Shoves `oid`: one attack of the Attack action and a Strength (Athletics) check against its DC move it 5 ft (push).
func shove(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := shove_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	_spend_attack(c)
	var t := c.creature.roll_check(e.dice, &"athletics", o.move_dc, [], [], "Strength (Athletics) to shove %s (%s)" % [o.the(), c.name()])
	if not t.success:
		e.log.add("info", "%s heaves at %s, but it doesn't budge" % [c.name(), o.the()], c.id, [t.describe()])
		return CombatResult.new()
	e.log.add("info", "%s shoves %s" % [c.name(), o.the()], c.id, [t.describe()])
	push(o, shove_to(c, o), c)
	return CombatResult.new()


## One attack of the Attack action (as EncounterObjects.attack spends it): the next attack, or the action that starts them.
func _spend_attack(c: Combatant) -> void:
	var e := enc()
	if c.attacks_left > 0:
		c.attacks_left -= 1
	else:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1 if c.creature is Character else 0


## `o` goes where `to` says (shove_to): into a creature it stops and knocks it; over the drop or into deep water it's
## gone; down 10 ft or more it falls (1d6 per 10 ft to it, and to whoever it lands on, who makes a Dexterity save for
## half and falls Prone on a failure; landing on someone smashes it). Fire travels with it.
func push(o: BattleObject, to: Dictionary, by: Combatant) -> void:
	var e := enc()
	var from := o.cells[0]
	var cell := to["cell"] as Vector2i
	var who := to["who"] as Combatant
	var fall := int(to["fall"])
	if who != null and fall == 0:
		_knock(o, who, by)
		return
	objs().clear_squares(o)
	o.cells.assign([cell])
	var gone := str(to["gone"])
	if gone != "":
		o.destroyed = true
		o.hp = 0
		o.burning = false
		objs().fires_changed()
		e.events.append({"type": "object_move", "id": o.id, "from": from, "to": cell, "gone": gone})
		e.log.add("info", "%s %s" % [o.title(), "goes over the edge" if gone == "drop" else "sinks out of reach"], by.id if by != null else "")
		return
	e.events.append({"type": "object_move", "id": o.id, "from": from, "to": cell, "fall": fall})
	if fall >= 10:
		var rolled := e._roll_damage_dice("%dd6" % mini(20, fall / 10), false, 0, "Falling %s" % o.name)
		e.log.add("info", "%s falls %d ft" % [o.title(), fall], "", [str(rolled["text"])])
		if who != null:
			var sv := who.creature.roll_save(e.dice, &"dex", FALL_DC, [], [], "Dexterity save vs the falling %s (%s)" % [o.name, who.name()])
			var amount := int(rolled["total"]) if not sv.success else int(rolled["total"]) / 2
			e.deal_damage(by, who, [{"amount": amount, "type": "bludgeoning"}], false, "The falling %s" % o.name, [sv.describe(), str(rolled["text"])])
			if not sv.success and who.is_alive() and not who.is_down() and who.creature.add_condition(&"prone", o.name):
				e.events.append({"type": "condition", "id": who.id})
			objs().smash(o, "smashed under it")
			return
		objs().damage(o, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], null, "the fall", [str(rolled["text"])])
	if not o.destroyed:
		objs().fill_squares(o)
		objs().moved(o)


## `o` slams into `who` and stops: a Strength or Dexterity save (whichever is better) against `by`'s Shove DC (8 +
## Strength modifier + Proficiency Bonus), or a knock by the object's size (Bludgeoning) and Prone.
func _knock(o: BattleObject, who: Combatant, by: Combatant) -> void:
	var e := enc()
	var dc := 8 + by.creature.ability_mod(&"str") + by.creature.proficiency_bonus() if by != null else 10
	var ab: StringName = &"str" if who.creature.save_bonus(&"str").total() >= who.creature.save_bonus(&"dex").total() else &"dex"
	var sv := who.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s (%s)" % [Creature.ABILITY_NAMES[ab], o.the(), who.name()])
	e.events.append({"type": "object_bump", "id": o.id, "target": who.id})
	if sv.success:
		e.log.add("info", "%s slams into %s, who stands firm" % [o.title(), who.name()], who.id, [sv.describe()])
		return
	var rolled := e._roll_damage_dice(str(KNOCK.get(o.size, "1d6")), false, 0, "Knocked by %s" % o.name)
	e.deal_damage(by, who, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], false, o.title(), [sv.describe(), str(rolled["text"])])
	if who.is_alive() and not who.is_down() and who.creature.add_condition(&"prone", o.name):
		e.events.append({"type": "condition", "id": who.id})


## Which way `o` falls when `c` pushes it over: straight away from `c`, or (a thing standing against a wall) pulled
## down toward `c`, who steps clear of it; Vector2i.ZERO when neither way is open.
func topple_dir(c: Combatant, o: BattleObject) -> Vector2i:
	var dir := away(c, o)
	for d: Vector2i in [dir, -dir]:
		if _falls_into(o.cells[0] + d):
			return d
	return Vector2i.ZERO


func _falls_into(cell: Vector2i) -> bool:
	var g := enc().grid
	return g.in_bounds(cell) and not g.has_flag(cell, CombatGrid.WALL) and not g.has_flag(cell, CombatGrid.VOID)


## The squares `o` falls across when `c` pushes it over: its kind's length that way (topple_dir), stopping at a wall.
func topple_line(c: Combatant, o: BattleObject) -> Array[Vector2i]:
	var dir := topple_dir(c, o)
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO:
		return out
	for k in range(1, int(o.topple.get("length", 2)) + 1):
		var cell := o.cells[0] + dir * k
		if not _falls_into(cell):
			break
		out.append(cell)
	return out


## "" if `c` can push `o` over now, otherwise why not.
func topple_why(c: Combatant, o: BattleObject) -> String:
	var why := _reach_why(c, o)
	if why != "":
		return why
	if o.moves != "topple":
		return "It won't topple"
	why = enc()._action_check(c)
	if why != "":
		return why
	if topple_line(c, o).is_empty():
		return "No room for it to fall"
	return ""


## Pushes `oid` over: the Utilize action and a Strength (Athletics) check against its DC (fall_over).
func topple(c: Combatant, oid: String) -> CombatResult:
	var e := enc()
	var o := objs().get_object(oid)
	var why := topple_why(c, o)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	var t := c.creature.roll_check(e.dice, &"athletics", o.move_dc, [], [], "Strength (Athletics) to topple %s (%s)" % [o.the(), c.name()])
	if not t.success:
		e.log.add("info", "%s rocks %s, but it stays standing" % [c.name(), o.the()], c.id, [t.describe()])
		return CombatResult.new()
	fall_over(o, topple_line(c, o), c, [t.describe()])
	return CombatResult.new()


## `o` falls across `line`: each creature on the floor there but `by` (who pushed it, or pulled it down and stepped
## clear) makes the Dexterity save (its kind's `topple`) or takes the damage and falls Prone; the objects there take the
## damage too; the line is left as rubble (Difficult Terrain), and a brazier's coals (or a burning thing) set it alight.
func fall_over(o: BattleObject, line: Array[Vector2i], by: Combatant, details: Array) -> void:
	var e := enc()
	var tp := o.topple
	var was_burning := o.burning
	objs().clear_squares(o)
	o.destroyed = true
	o.hp = 0
	o.burning = false
	o.wreck.assign(line)
	objs().fires_changed()
	e.events.append({"type": "object_topple", "id": o.id, "cells": line})
	e.log.add("info", ("%s pushes %s over" % [by.name(), o.the()]) if by != null else "%s topples over" % o.title(), by.id if by != null else "", details)
	var rolled := e._roll_damage_dice(str(tp.get("damage", "1d10")), false, 0, "Falling %s" % o.name)
	var ty := str(tp.get("type", "bludgeoning"))
	for v in e.living():
		if v == by or v.altitude > 0 or v.has_meta("left_fight") or not v.footprint().any(func(cell: Vector2i) -> bool: return cell in line):
			continue
		var sv := v.creature.roll_save(e.dice, &"dex", int(tp.get("dc", 12)), [], [], "Dexterity save vs the falling %s (%s)" % [o.name, v.name()])
		if sv.success:
			e.log.add("info", "%s gets clear of %s" % [v.name(), o.the()], v.id, [sv.describe()])
			continue
		e.deal_damage(by, v, [{"amount": int(rolled["total"]), "type": ty}], false, "The falling %s" % o.name, [sv.describe(), str(rolled["text"])])
		if v.is_alive() and not v.is_down() and v.creature.add_condition(&"prone", o.name):
			e.events.append({"type": "condition", "id": v.id})
	for o2: BattleObject in objs().list.duplicate():
		if o2 == o or o2.destroyed or o2.hangs or o2.holds != "" or not o2.cells.any(func(cell: Vector2i) -> bool: return cell in line):
			continue
		objs().damage(o2, [{"amount": int(rolled["total"]), "type": ty}], by, "the falling %s" % o.name, [str(rolled["text"])])
	for cell in line:
		if not e.grid.has_flag(cell, CombatGrid.LOW):
			e.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
	e._cover_cache.clear()
	if bool(tp.get("coals", false)):
		for cell in line:
			if not e.grid.has_flag(cell, CombatGrid.LOW) and objs().square_at(cell).is_empty():
				objs().burning_square(cell, "Burning coals spill across the floor")
	if was_burning or bool(tp.get("coals", false)):
		objs().expose_to_fire(line, by)


# --- Throwing: from the ground, and improvised weapons ------------------------------------------------------

## What `c` can pick up and throw (EncounterWeapons.attack_options): each thing lying within 5 ft that it could carry
## off (a thrown weapon as itself, anything else as an improvised weapon), and each small object standing within 5 ft
## that can be thrown.
func throw_options(c: Combatant) -> Array[Dictionary]:
	var e := enc()
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var comp := Compendium.shared()
	for g in e.ground.items:
		if not e.ground.in_reach(c, g) or e.ground._carry_why(c, g) != "":
			continue
		var data := comp.item_data(str(g["item_id"]))
		if "thrown" in Gear.weapon_props(data):
			out.append(_ground_weapon(c, "g:" + str(g["gid"]), data))
			continue
		var noun := str(g["name"]) if MagicItems.is_magic(data) else str(g["name"]).to_lower()
		out.append(_throw_option(c, "g:" + str(g["gid"]), noun, str((data.get("weapon", {}) as Dictionary).get("damage_type", "bludgeoning"))))
	for o in objs().list:
		if o.throwable and not o.destroyed and not o.burning and not o.hangs and o.holds == "" and o.cells.size() == 1 \
				and objs().distance_ft(c, o) <= REACH:
			out.append(_throw_option(c, "o:" + o.id, o.name, "bludgeoning"))
	return out


## A thrown weapon lying within reach (a dagger, a javelin, a handaxe), thrown as itself: its own profile, the thrower's
## proficiency with it.
func _ground_weapon(c: Combatant, ref: String, data: Dictionary) -> Dictionary:
	var p := WeaponProfile.build(c.creature, data, true)
	p.name = "%s, from the ground" % p.name
	return {"id": "improvised:" + ref, "label": p.name, "kind": "thrown", "improvised": ref, "profile": p, "melee": false,
		"range": [p.normal_range, p.long_range], "reach": REACH}


## An improvised thrown weapon's attack option ({id "improvised:<ref>", kind "thrown", improvised: ref}): 1d4 + Strength,
## 20/60 ft, the Proficiency Bonus only with proficiency in improvised weapons (Gear: the "improvised" weapon id).
func _throw_option(c: Combatant, ref: String, noun: String, damage_type: String) -> Dictionary:
	var item := {"id": "improvised", "name": noun, "weapon": {"kind": "improvised", "damage": IMPROVISED_DIE,
		"damage_type": damage_type, "properties": ["thrown"], "range": IMPROVISED_RANGE.duplicate()}}
	var p := WeaponProfile.build(c.creature, item, true)
	p.name = "%s (improvised)" % (noun.substr(0, 1).to_upper() + noun.substr(1))
	p.notes.clear()
	p._compute(c.creature)
	return {"id": "improvised:" + ref, "label": p.name, "kind": "thrown", "improvised": ref, "profile": p, "melee": false,
		"range": [p.normal_range, p.long_range], "reach": REACH}


## "" if `c` can still throw the improvised weapon `option` names: it lies (or stands) within 5 ft, and `c` has its free
## object interaction (or Fast Hands' Bonus Action) to pick it up as it throws.
func throw_why(c: Combatant, option: Dictionary) -> String:
	var e := enc()
	var ref := str(option.get("improvised", ""))
	if ref.begins_with("g:"):
		var g := e.ground.find(ref.substr(2))
		if g.is_empty() or not e.ground.in_reach(c, g):
			return "Nothing lies there to throw"
	elif ref.begins_with("o:"):
		var o := objs().get_object(ref.substr(2))
		if o == null or o.destroyed or objs().distance_ft(c, o) > REACH:
			return "Nothing stands there to throw"
	if not e.ground.cost_of(c) in ["free", "bonus"]:
		return "No free object interaction left to pick it up"
	return ""


## The improvised weapon leaves the ground as it's thrown (EncounterAttacks, EncounterObjects): the object interaction
## picks it up; a thing from the ground comes down in the target's space (or by `cell`, an object it was thrown at), and
## a small object breaks there.
func thrown(c: Combatant, option: Dictionary, target: Combatant, cell: Vector2i = Vector2i(-1, -1)) -> void:
	var e := enc()
	match e.ground.cost_of(c):
		"free":
			c.free_interaction_available = false
		"bonus":
			c.bonus_available = false
	var ref := str(option.get("improvised", ""))
	if ref.begins_with("g:"):
		e.ground.throw_pile(c, ref.substr(2), target, cell)
	elif ref.begins_with("o:"):
		var o := objs().get_object(ref.substr(2))
		if o != null and not o.destroyed:
			o.wreck.assign([cell if cell.x >= 0 else (target.cell if target != null else o.cells[0])])
			objs().smash(o, "flung")


# --- The hotbar and the square menu -------------------------------------------------------------------

## The Common tab's lines: opening or shutting each door within reach.
func entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in objs().list:
		if o.is_door() and not o.destroyed and objs().distance_ft(c, o) <= REACH:
			out.append(_door_entry(c, o))
	return out


func _door_entry(c: Combatant, o: BattleObject) -> Dictionary:
	var why := door_why(c, o)
	var cost := enc().ground.cost_of(c)
	var a := objs()._entry("door:" + o.id, "%s %s" % ["Shut" if o.open else "Open", o.the()],
		{"free": "free", "bonus": "Fast Hands", "action": "Utilize"}.get(cost, "") as String, cost if cost != "" else "action", why, "none",
		"Your free object interaction this turn, else the Utilize action.")
	a["tab"] = ActionCatalog.COMMON
	a["range"] = REACH
	return a


## The square menu's lines for what stands on `cell`: opening or shutting a door, shoving, pushing over.
func square_entries(c: Combatant, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in objs().objects_at(cell):
		if o.is_door():
			var d := _door_entry(c, o)
			out.append({"id": "act:%s" % d["id"], "label": str(d["label"]), "enabled": bool(d["legal"]), "why": str(d["reason"]), "action": d})
		elif o.moves == "shove":
			out.append(objs()._line("shove:" + o.id, "Shove %s (Athletics DC %d)" % [o.the(), o.move_dc], shove_why(c, o), "attack"))
		elif o.moves == "topple":
			out.append(objs()._line("topple:" + o.id, "Push %s over (Athletics DC %d)" % [o.the(), o.move_dc], topple_why(c, o), "action"))
	return out


## Carries out a door, shove or topple line (EncounterObjects.perform); null if `id` isn't one.
func perform(c: Combatant, id: String) -> CombatResult:
	if id.begins_with("door:"):
		return toggle_door(c, id.substr(5))
	if id.begins_with("shove:"):
		return shove(c, id.substr(6))
	if id.begins_with("topple:"):
		return topple(c, id.substr(7))
	return null
