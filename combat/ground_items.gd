class_name GroundItems
extends RefCounted
## Things lying on the battlefield (2024 PHB): a weapon knocked from a hand by a Disarming Attack or let go of in Heat
## Metal's searing grip, whatever a creature held when it fell Unconscious (or was Commanded to drop it), and a thrown
## weapon where it came down. Each lies on its square until a creature within 5 ft picks it up, with its one free
## object interaction of the turn, else the Utilize action (a Thief's Fast Hands: a Bonus Action). A character takes it
## back in hand when that hand is free, else into its pack. A monster's weapon is a set of stat-block attacks: while
## the weapon is out of its hands those attacks can't be made, and the AI takes it back when it lies within reach.
## When the fight ends the party gathers its own things and half the ammunition it shot, and the foes' dropped
## weapons are left for the loot. Encounter.ground; the scene draws the piles (world/combat/ground_view.gd).

## How far a creature reaches for something on the ground.
const REACH := 5

var _enc: WeakRef
## What lies where: [{gid, cell: Vector2i, item_id ("" for a monster's weapon that isn't an item), name, qty, owner_id,
## slot (the hand it left), state (a weapon that doesn't stack: the inventory entry it left, its charges and the rest),
## actions (the stat-block attacks a monster makes with it)}].
var items: Array[Dictionary] = []
## Monster id -> the stat-block attacks it can't make while their weapon is out of its hands.
var lost: Dictionary = {}
## Owner id -> {ammunition item id: pieces shot} (2024: half of it is found again after the fight).
var ammo_used: Dictionary = {}
## The foes' weapons still lying there when the fight ended, for its loot: [{id, qty}].
var spoils: Array[Dictionary] = []
var _next_id := 1


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


# --- What lies where ------------------------------------------------------------------------------

## The piles on `cell`.
func at(cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in items:
		if g["cell"] == cell:
			out.append(g)
	return out


func find(gid: String) -> Dictionary:
	for g in items:
		if str(g["gid"]) == gid:
			return g
	return {}


func in_reach(c: Combatant, g: Dictionary) -> bool:
	return enc().grid.distance_ft(c.cell, c.size_cells, g["cell"] as Vector2i, 1) <= REACH


## What a pile is called: "longsword", "2 daggers", "Hammer of Thunderbolts" (magic items keep their capitals).
func noun(g: Dictionary) -> String:
	var n := str(g["name"])
	if not MagicItems.is_magic(Compendium.shared().item_data(str(g["item_id"]))):
		n = n.to_lower()
	return n if int(g["qty"]) <= 1 else "%d %ss" % [int(g["qty"]), n]


## "Ilse's longsword", "Bandit 2's scimitar".
func owned(g: Dictionary) -> String:
	var who := enc().get_c(str(g["owner_id"]))
	return "%s's %s" % [who.name(), noun(g)] if who != null else "a %s" % noun(g)


## Hover text for a square: a line for each pile lying there.
func describe_at(cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for g in at(cell):
		out.append("On the ground: %s" % owned(g))
	return out


# --- What a creature holds ------------------------------------------------------------------------

## A monster's weapons, one per item, in stat-block order: [{key, item_id, name, actions, melee}].
static func monster_weapons(m: Monster) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_key := {}
	for list_name: String in ["actions", "bonus_actions"]:
		for a: Variant in m.data.get(list_name, []):
			var act := a as Dictionary
			if not bool(act.get("weapon", false)) or not act.has("attack"):
				continue
			var iid := weapon_item(m, act)
			var key := iid if iid != "" else str(act.get("id", ""))
			if by_key.has(key):
				((by_key[key] as Dictionary)["actions"] as Array).append(str(act["id"]))
				continue
			var named := str(Compendium.shared().item_data(iid).get("name", "")) if iid != "" else ""
			var w := {"key": key, "item_id": iid, "name": named if named != "" else str(act.get("name", key)),
				"actions": [str(act["id"])], "melee": str(act.get("kind", "melee")) != "ranged"}
			by_key[key] = w
			out.append(w)
	return out


## The item a monster's weapon attack is made with: the item of its id ("scimitar"), else gear of the monster's that
## its id ends with ("silvered_shortsword"), else the item its last word names ("holy_mace": a mace) or gear holding
## that word ("necrotic_bow": its longbow); "" when nothing fits (a sword cane), and the attack's name is the weapon's.
static func weapon_item(m: Monster, act: Dictionary) -> String:
	var comp := Compendium.shared()
	var aid := str(act.get("id", ""))
	if Gear.is_weapon(comp.item_data(aid)):
		return aid
	var gear := m.data.get("gear", []) as Array
	for g: Variant in gear:
		if aid.ends_with(str(g)) and Gear.is_weapon(comp.item_data(str(g))):
			return str(g)
	var last := aid.get_slice("_", aid.count("_"))
	if Gear.is_weapon(comp.item_data(last)):
		return last
	for g2: Variant in gear:
		if str(g2).contains(last) and Gear.is_weapon(comp.item_data(str(g2))):
			return str(g2)
	return ""


## What `c` holds that it could let go of: [{item_id, name, slot, entry (a character's inventory entry), actions (a
## monster's attacks with it)}]. A character's two hands (a donned Shield stays on); a monster holds one weapon at a
## time, the first melee weapon it still has (else its first weapon), and wears the others slung.
func held(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c.creature is Character:
		var ch := c.creature as Character
		for slot: String in ["main_hand", "off_hand"]:
			for en in ch.inventory:
				if str(en.get("slot", "")) != slot or int(en.get("qty", 0)) <= 0:
					continue
				var data := Compendium.shared().item_data(str(en["id"]))
				if Gear.is_shield(data):
					continue
				out.append({"item_id": str(en["id"]), "name": str(data.get("name", en["id"])), "slot": slot, "entry": en, "actions": []})
		return out
	if c.creature is Monster and not EchoKnight.is_echo(c):
		var gone := lost.get(c.id, []) as Array
		var pick := {}
		for w in monster_weapons(c.creature as Monster):
			if (w["actions"] as Array).any(func(a: Variant) -> bool: return a in gone):
				continue
			if pick.is_empty() or (bool(w["melee"]) and not bool(pick["melee"])):
				pick = w
		if not pick.is_empty():
			out.append({"item_id": str(pick["item_id"]), "name": str(pick["name"]), "slot": "", "actions": (pick["actions"] as Array).duplicate()})
	return out


## Why a monster can't make the stat-block attack `act` now ("" if it can): its weapon lies on the ground, or someone
## took it.
func weapon_gone(c: Combatant, act: Dictionary) -> String:
	if not lost.has(c.id) or not bool(act.get("weapon", false)):
		return ""
	var id := str(act.get("id", ""))
	if not id in (lost[c.id] as Array):
		return ""
	for g in items:
		if str(g["owner_id"]) == c.id and id in (g["actions"] as Array):
			return "Disarmed: its %s lies on the ground" % noun(g)
	return "Disarmed: someone took its weapon"


## A monster with every weapon out of its hands (it can't Parry).
func empty_handed(c: Combatant) -> bool:
	return lost.has(c.id) and held(c).is_empty()


# --- Dropping -------------------------------------------------------------------------------------

## `c` lets go of `what` (one of held(c)), which lands on `cell` (its own square by default); logged with `why`.
## Returns the pile it joined.
func drop(c: Combatant, what: Dictionary, why: String, details: Array = [], cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var g := {"item_id": str(what["item_id"]), "name": str(what["name"]), "qty": 1, "owner_id": c.id,
		"slot": str(what.get("slot", "")), "state": {}, "actions": (what.get("actions", []) as Array).duplicate()}
	if what.has("entry"):
		var ch := c.creature as Character
		var en := what["entry"] as Dictionary
		en["qty"] = int(en["qty"]) - 1
		if int(en["qty"]) <= 0:
			ch.inventory.erase(en)
			# Its own entry goes with it (charges, a lifted curse: what isn't id, qty or slot).
			if not bool(Compendium.shared().item_data(str(en["id"])).get("stackable", false)):
				g["state"] = en
		else:
			en["slot"] = ""   # the rest of a stack goes back to the belt
		ch.items_changed()
	else:
		var gone := (lost.get(c.id, []) as Array).duplicate()
		for a: Variant in (g["actions"] as Array):
			if not a in gone:
				gone.append(a)
		lost[c.id] = gone
	var pile := _put(g, cell if cell.x >= 0 else c.cell)
	enc().log.add("info", "%s drops the %s (%s)" % [c.name(), noun(g), why], c.id, details)
	return pile


## Disarming Attack (2024): the target drops one object it's holding, which lands in its space (for a big target, the
## square nearest the attacker): the weapon in its main hand, else what its other hand holds; a monster, its weapon.
## A failed save against Heat Metal lets go of the heated weapon the same way. False if it held nothing.
func disarm(t: Combatant, by: Combatant, why: String, details: Array = []) -> bool:
	var what := held(t)
	if what.is_empty():
		enc().log.add("info", "%s holds nothing it could drop (%s)" % [t.name(), why], t.id, details)
		return false
	drop(t, what[0], why, details, _nearest_in(t, by) if by != null else t.cell)
	return true


## Everything `c` holds falls into its space (the Unconscious condition, Command's "Drop").
func drop_held(c: Combatant, why: String, details: Array = []) -> void:
	for what in held(c):
		drop(c, what, why, details)


## Encounter._effect_added: an effect that leaves a creature Unconscious (Sleep, a Knock Out) drops what it holds.
func effect_added(cr: Creature, fx: Effect) -> void:
	if not &"unconscious" in fx.conditions:
		return
	var c := enc().get_c(cr.id)
	if c != null and c.creature == cr:
		drop_held(c, "Unconscious")


## A thrown weapon comes down in its target's space (for a big target, the square nearest the thrower), hit or miss,
## or by `cell` (an object it was thrown at: the nearest square something can lie on). `state` is the inventory entry
## it left ({} for one of a stack), `slot` the hand it left (empty while more of a stack is still in hand).
func land(c: Combatant, item_id: String, state: Dictionary, slot: String, target: Combatant, cell: Vector2i = Vector2i(-1, -1)) -> void:
	var name := str(Compendium.shared().item_data(item_id).get("name", item_id))
	var at := cell if cell.x >= 0 else (_nearest_in(target, c) if target != null else c.cell)
	_put({"item_id": item_id, "name": name, "qty": 1, "owner_id": c.id, "slot": slot, "state": state, "actions": []}, at)


## A thrown weapon that returns to its thrower's hand (a Dwarven Thrower) leaves the ground. False if it isn't there.
func fly_back(c: Combatant, item_id: String) -> bool:
	var ch := _character_of(c)
	if ch == null:
		return false
	for i in range(items.size() - 1, -1, -1):
		var g := items[i]
		if str(g["owner_id"]) == c.id and str(g["item_id"]) == item_id:
			_restore(ch, g, 1, true, true)
			return true
	return false


## A piece of mundane ammunition shot (half of it is found after the fight; magic ammunition isn't).
func ammo_spent(c: Combatant, ammo_id: String) -> void:
	if MagicItems.is_magic(Compendium.shared().item_data(ammo_id)):
		return
	var used := ammo_used.get(c.id, {}) as Dictionary
	used[ammo_id] = int(used.get(ammo_id, 0)) + 1
	ammo_used[c.id] = used


## Puts pile `g` down on `cell` (or the nearest square something can lie on), joining a pile of the same thing from
## the same owner there. Returns the pile.
func _put(g: Dictionary, cell: Vector2i) -> Dictionary:
	var spot := _floor_near(cell)
	var iid := str(g["item_id"])
	if iid != "" and (g["state"] as Dictionary).is_empty() and bool(Compendium.shared().item_data(iid).get("stackable", false)):
		for p in items:
			if p["cell"] == spot and str(p["item_id"]) == iid and str(p["owner_id"]) == str(g["owner_id"]) and (p["state"] as Dictionary).is_empty():
				p["qty"] = int(p["qty"]) + int(g["qty"])
				return p
	g["cell"] = spot
	g["gid"] = "g%d" % _next_id
	_next_id += 1
	items.append(g)
	return g


## `cell`, or the nearest square in the map that isn't a wall, a low obstacle or deep water.
func _floor_near(cell: Vector2i) -> Vector2i:
	var grid := enc().grid
	var blocked := CombatGrid.WALL | CombatGrid.LOW | CombatGrid.VOID | CombatGrid.WATER
	for r in 4:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var sq := cell + Vector2i(dx, dz)
				if grid.in_bounds(sq) and (grid.flags(sq) & blocked) == 0 and Vector2(dx, dz).length() < best_d:
					best_d = Vector2(dx, dz).length()
					best = sq
		if best.x >= 0:
			return best
	return cell


## The square of `t`'s space nearest `from`.
func _nearest_in(t: Combatant, from: Combatant) -> Vector2i:
	var aim := enc().center_of(from)
	var best := t.cell
	var best_d := INF
	for sq in t.footprint():
		var d := (Vector2(sq) + Vector2(0.5, 0.5)).distance_to(aim)
		if d < best_d:
			best_d = d
			best = sq
	return best


# --- Picking up -----------------------------------------------------------------------------------

## "" if `c` could carry `g` off at all: a character takes anything that's an item; a monster only its own weapon.
func _carry_why(c: Combatant, g: Dictionary) -> String:
	if EchoKnight.is_echo(c) or c.creature.has_flag("spell_object"):
		return "Can't pick things up"
	if c.creature is Character:
		if str(g["item_id"]) == "" and str(g["owner_id"]) != c.id:
			return "Only its owner could use it"
		return ""
	if str(g["owner_id"]) == c.id and not (g["actions"] as Array).is_empty():
		return ""
	return "Can't carry it off"


## What picking something up costs `c` now: "free" (its object interaction this turn), "bonus" (a Thief's Fast Hands)
## or "action" (Utilize); "" when none is left.
func cost_of(c: Combatant) -> String:
	var e := enc()
	if c.free_interaction_available:
		return "free"
	if CombatFeatures.has_feature(c, "fast_hands") and e._bonus_check(c) == "":
		return "bonus"
	if e._action_check(c) == "":
		return "action"
	return ""


## "" if `c` can pick up `g` now, otherwise why not.
func pick_up_why(c: Combatant, g: Dictionary) -> String:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "%s can't act" % c.name()
	why = _carry_why(c, g)
	if why != "":
		return why
	if not in_reach(c, g):
		return "Out of reach: move within 5 ft"
	if cost_of(c) == "":
		return "No object interaction or action left"
	return ""


## Picks up pile `gid` (all of it): a character's own thing goes back to the hand it left when that's free, anything
## else to a free hand if it's a weapon or a held item, else into the pack; a monster's weapon goes back in its hand.
func pick_up(c: Combatant, gid: String) -> CombatResult:
	var e := enc()
	var g := find(gid)
	if g.is_empty():
		return CombatResult.fail("Nothing lies there now")
	var why := pick_up_why(c, g)
	if why != "":
		return CombatResult.fail(why)
	var cost := cost_of(c)
	match cost:
		"free":
			c.free_interaction_available = false
		"bonus":
			c.bonus_available = false
		"action":
			e.spend_action(c)
	var what := noun(g) if str(g["owner_id"]) == c.id else owned(g)
	var ch := c.creature as Character
	if ch != null:
		_restore(ch, g, int(g["qty"]), true, str(g["owner_id"]) == c.id)
	else:
		var keep := (lost.get(c.id, []) as Array).filter(func(a: Variant) -> bool: return not a in (g["actions"] as Array))
		if keep.is_empty():
			lost.erase(c.id)
		else:
			lost[c.id] = keep
		items.erase(g)
	e.log.add("info", "%s picks up %s%s" % [c.name(), ("the " + what) if str(g["owner_id"]) == c.id else what,
		{"bonus": " (Fast Hands)", "action": " (Utilize)"}.get(cost, "")], c.id)
	return CombatResult.new()


## An AI creature takes its own dropped weapon back with its free object interaction when it lies within reach.
func ai_pick_up(c: Combatant) -> void:
	for g: Dictionary in items.duplicate():
		if str(g["owner_id"]) == c.id and c.free_interaction_available and pick_up_why(c, g) == "":
			pick_up(c, str(g["gid"]))
			return


## What the hotbar offers `c` (Common tab): picking up each thing lying within its reach.
func entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in items:
		if in_reach(c, g) and _carry_why(c, g) == "":
			out.append(_entry(c, g))
	return out


## The square menu's lines for `cell` (ActionCatalog.square_actions): picking up each thing lying there.
func square_entries(c: Combatant, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in at(cell):
		if _carry_why(c, g) != "":
			continue
		var a := _entry(c, g)
		out.append({"id": "act:%s" % a["id"], "label": str(a["label"]), "enabled": bool(a["legal"]), "why": str(a["reason"]), "action": a})
	return out


## "Pick up the longsword", "Pick up Ilse's longsword".
func label(c: Combatant, g: Dictionary) -> String:
	return "Pick up the %s" % noun(g) if str(g["owner_id"]) == c.id else "Pick up %s" % owned(g)


func _entry(c: Combatant, g: Dictionary) -> Dictionary:
	var why := pick_up_why(c, g)
	var cost := cost_of(c)
	return {"id": "pickup:%s" % g["gid"], "tab": ActionCatalog.COMMON, "label": label(c, g),
		"sub": {"free": "free", "bonus": "Fast Hands", "action": "Utilize"}.get(cost, "") as String,
		"cost": cost if cost != "" else "action", "legal": why == "", "reason": why, "targeting": "none", "count": 1,
		"repeat": false, "range": REACH, "spell_id": "", "slot": 0, "option_id": "", "kind": "pickup",
		"item_id": str(g["item_id"]), "help": "Pick it up from within 5 ft: your free object interaction this turn, else the Utilize action. It goes back in a free hand, else into the pack."}


## Puts `n` of pile `g` into `ch`'s hands or pack (see pick_up); `own`: it was theirs (else it's marked new to them).
## The pile goes once it's empty.
func _restore(ch: Character, g: Dictionary, n: int, to_hand: bool, own: bool) -> void:
	var iid := str(g["item_id"])
	var data := Compendium.shared().item_data(iid)
	var entry := {}
	if bool(data.get("stackable", false)):
		for en in ch.inventory:
			if str(en["id"]) == iid:
				en["qty"] = int(en["qty"]) + n
				entry = en
				break
	if entry.is_empty():
		entry = {"id": iid, "qty": n, "slot": ""}
		var state := g.get("state", {}) as Dictionary
		for k: String in state:
			if not k in ["id", "qty", "slot"]:
				entry[k] = _copy(state[k])
		ch.inventory.append(entry)
	if not own:
		entry["new"] = true
	var hand := _hand_for(ch, str(g.get("slot", "")), data) if to_hand else ""
	if hand != "" and str(entry.get("slot", "")) == "":
		entry["slot"] = hand
	ch.items_changed()
	g["qty"] = int(g["qty"]) - n
	if int(g["qty"]) <= 0:
		items.erase(g)


## The hand a picked-up item goes to: the one it left (else the main hand, for a weapon or a held item) when that's
## free, and a two-handed weapon needs the other hand free too; "" for the pack.
func _hand_for(ch: Character, left: String, data: Dictionary) -> String:
	var hand := left
	if hand == "":
		if not (Gear.is_weapon(data) or MagicItems.is_held(data)):
			return ""
		hand = "main_hand"
	if not ch.equipped(hand).is_empty():
		return ""
	if "two_handed" in Gear.weapon_props(data) and not ch.equipped("off_hand" if hand == "main_hand" else "main_hand").is_empty():
		return ""
	return hand


static func _copy(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	if v is Array:
		return (v as Array).duplicate(true)
	return v


## The character behind a combatant (its true self under a Wild Shape or Polymorph); null for a monster.
func _character_of(c: Combatant) -> Character:
	if c == null:
		return null
	return enc().shapes.original(c) as Character


# --- After the fight ------------------------------------------------------------------------------

## The fight is over (EncounterTurns._check_over): the party gathers everything of its own (a weapon back to the hand
## it left when that's free) and half the mundane ammunition each member shot, rounded down; the foes' weapons that
## are items are left in `spoils` for the fight's loot.
func fight_over() -> void:
	var e := enc()
	for g: Dictionary in items.duplicate():
		var who := e.get_c(str(g["owner_id"]))
		var ch := _character_of(who)
		if ch != null and who.side in [&"party", &"guest"]:
			_restore(ch, g, int(g["qty"]), true, true)
		elif str(g["item_id"]) != "" and (who == null or who.side == &"enemy"):
			_add_spoil(str(g["item_id"]), int(g["qty"]))
	items.clear()
	lost.clear()
	for owner_id: String in ammo_used:
		var shooter := e.get_c(owner_id)
		var ch2 := _character_of(shooter)
		if ch2 == null or not shooter.side in [&"party", &"guest"]:
			continue
		var used := ammo_used[owner_id] as Dictionary
		for ammo: String in used:
			var back := int(used[ammo]) / 2
			if back <= 0:
				continue
			var name := str(Compendium.shared().item_data(ammo).get("name", ammo)).to_lower()
			_restore(ch2, {"item_id": ammo, "qty": back, "slot": "", "state": {}}, back, false, true)
			e.log.add("info", "%s gathers %d of the %d %s shot" % [shooter.name(), back, int(used[ammo]), name], owner_id)
	ammo_used.clear()


func _add_spoil(item_id: String, qty: int) -> void:
	for sp in spoils:
		if str(sp["id"]) == item_id:
			sp["qty"] = int(sp["qty"]) + qty
			return
	spoils.append({"id": item_id, "qty": qty})


# --- Saving a fight -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var piles: Array = []
	for g in items:
		var d := g.duplicate(true)
		d["cell"] = [(g["cell"] as Vector2i).x, (g["cell"] as Vector2i).y]
		piles.append(d)
	return {"items": piles, "lost": lost.duplicate(true), "ammo": ammo_used.duplicate(true), "next": _next_id}


func from_dict(d: Dictionary) -> void:
	items.clear()
	for x: Variant in d.get("items", []):
		var g := (x as Dictionary).duplicate(true)
		var a := g["cell"] as Array
		g["cell"] = Vector2i(int(a[0]), int(a[1]))
		g["qty"] = int(g["qty"])
		items.append(g)
	lost = (d.get("lost", {}) as Dictionary).duplicate(true)
	ammo_used = (d.get("ammo", {}) as Dictionary).duplicate(true)
	_next_id = int(d.get("next", items.size() + 1))
