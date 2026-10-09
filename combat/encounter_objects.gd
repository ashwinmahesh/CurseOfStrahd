class_name EncounterObjects
extends RefCounted
## The battlefield's breakable things and fire (F5; 2024 rules glossary: Breaking Objects, the Burning condition; 2024
## PHB: Oil; the Web spell; the 2025 giant spider's Web), owned by the Encounter as `objects`:
## - BattleObjects (combat/battle_object.gd): doors, furniture, crates, gravestones, a chandelier's chain, a spider's
##   web. A weapon attack or a spell that can target an object (Fire Bolt, Eldritch Blast) rolls against its Armor
##   Class; a spell's area deals its damage to the objects in it (they fail every save); at 0 Hit Points one breaks and
##   its squares change (a door's doorway opens, furniture leaves rubble), and a chandelier falls on whoever is below.
## - Fire: a flammable object set alight burns (1d4 Fire at the start of each round); Oil thrown at a creature or an
##   object soaks it (its next Fire damage is 5 more), and Oil poured on a square burns once lit (5 Fire to a creature
##   entering it or ending its turn there); webs exposed to fire burn away. Burning things shed light.
## - What creatures do with them (ObjectActions, `actions`): open and shut doors, shove a crate, push a bookcase over,
##   throw a chair; and fire that spreads and barrels of lamp oil that burst (ObjectFire, `fire`).
## Only creatures on the floor (altitude 0) are hit by what lands or burns on it: a falling chandelier, a shoved or
## toppled thing, burning oil and coals (deviations.md).
## Commands come through the square menu and the hotbar (`square_entries`, `item_entries`, `perform`). The scene draws
## all of it (world/combat/object_view.gd); BattleScenery (world/combat/battle_scenery.gd) places the objects.

## Oil (2024 PHB): the thrown flask's range, the extra Fire it adds, how long a soaked target stays oily (1 minute),
## and how long a lit puddle burns (to the end of the turn 2 rounds after it was lit), dealing 5 Fire.
const OIL_RANGE := 20
const OIL_FIRE := 5
const OIL_DRIES := 10
const OIL_BURNS := 2
## The Web spell (2024): a cube of web exposed to fire burns away in 1 round, 2d4 Fire to a creature starting a turn
## in it. The Burning condition: 1d4 Fire.
const WEB_FIRE := "2d4"
const BURN_DICE := "1d4"
var _enc: WeakRef
var list: Array[BattleObject] = []
## Oil on the ground and squares on fire: [{cell: Vector2i, oil, lit, web, until_round, until_index, damage, on, hit}].
## `on`: when it burns a creature ("enter", "end": oil; "start": a burning web); `hit`: creature id -> the turn it last
## burned it (once per turn).
var squares: Array[Dictionary] = []
## Set once the battlefield's objects are placed (BattleScenery), so a fight picked up from a save isn't placed again.
var placed: bool = false
var _next := 1
var _fires: Array[Vector2i] = []
var _fires_dirty := true
## Doors, shoving, toppling and throwing (combat/object_actions.gd); fire spreading and bursting (combat/object_fire.gd).
var actions: ObjectActions
var fire: ObjectFire


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	actions = ObjectActions.new(encounter)
	fire = ObjectFire.new(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


## data/objects/kinds.json.
static func kinds() -> Dictionary:
	return Compendium.shared().get_entry("objects", "kinds")


# --- Placing and finding ----------------------------------------------------------------------------

## A new object of `kind_id` on `cells`, its grid flag set on them. `extra` sets its fields (name, door_id, prop_id,
## art, holds...).
func add(kind_id: String, cells: Array[Vector2i], extra: Dictionary = {}) -> BattleObject:
	var o := BattleObject.make(kind_id, kinds())
	o.id = "thing_%d" % _next
	_next += 1
	o.cells.assign(cells)
	for k: String in extra:
		o.set(k, extra[k])
	list.append(o)
	if o.cells.size() == 1:
		o.home = o.cells[0]
	fill_squares(o)
	return o


## `o`'s grid flag on its squares (a door standing open has none).
func fill_squares(o: BattleObject) -> void:
	if o.blocks == 0 or o.open:
		return
	for cell in o.cells:
		enc().grid.set_flag(cell, o.blocks, true)
	enc()._cover_cache.clear()


## `o` leaves its squares (shoved, toppled, flung, burst): their grid flag goes.
func clear_squares(o: BattleObject) -> void:
	if o.blocks == 0:
		return
	for cell in o.cells:
		enc().grid.set_flag(cell, o.blocks, false)
	enc()._cover_cache.clear()


## The fires to light by have changed (something burning moved, broke or went out).
func fires_changed() -> void:
	_fires_dirty = true


## `o` was shoved onto a new square: a burning one lights the oil there, and fire there sets a flammable one alight.
func moved(o: BattleObject) -> void:
	_fires_dirty = true
	if o.burning:
		expose_to_fire(o.cells, null)
		return
	for cell in o.cells:
		if bool(square_at(cell).get("lit", false)):
			ignite(o)
			return


## `o` is broken outright (flung, landed on someone): its squares open, and its wreckage lies there (or at `wreck`),
## rubble (Difficult Terrain) if its kind leaves rubble. The view shows it broken once the events have played.
func smash(o: BattleObject, how: String) -> void:
	var e := enc()
	if o.destroyed:
		return
	clear_squares(o)
	o.destroyed = true
	o.hp = 0
	if o.burning:
		o.burning = false
		_fires_dirty = true
	if o.leaves == "rubble" and o.blocks != 0:
		for cell in (o.wreck if not o.wreck.is_empty() else o.cells):
			e.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
		e._cover_cache.clear()
	e.log.add("info", "%s breaks to pieces (%s)" % [o.title(), how], "")


## The creature standing on the floor of `cell` (not one flying or floating over it), or null.
func on_floor(cell: Vector2i) -> Combatant:
	for c in enc().combatants:
		if c.is_alive() and c.altitude <= 0 and not c.has_meta("left_fight") and cell in c.footprint():
			return c
	return null


func get_object(oid: String) -> BattleObject:
	for o in list:
		if o.id == oid:
			return o
	return null


## The squares an object is on now (a web is wherever the creature it holds stands).
func cells_of(o: BattleObject) -> Array[Vector2i]:
	if o.holds != "":
		var t := enc().get_c(o.holds)
		if t != null:
			return t.footprint()
	return o.cells


## The standing objects on `cell`: what stands there (furniture, a door), a web round whoever is there, what hangs over it.
func objects_at(cell: Vector2i) -> Array[BattleObject]:
	var out: Array[BattleObject] = []
	for o in list:
		if not o.destroyed and cell in cells_of(o):
			out.append(o)
	return out


## The object that fills `cell` (a shut door, furniture, a crate), or null.
func blocking_at(cell: Vector2i) -> BattleObject:
	for o in objects_at(cell):
		if o.blocks != 0 and not o.open:
			return o
	return null


## Distance from `c` to the nearest square of `o`.
func distance_ft(c: Combatant, o: BattleObject) -> int:
	var best := 1 << 30
	for cell in cells_of(o):
		best = mini(best, enc().grid.distance_ft(c.cell, c.size_cells, cell, 1))
	return best


## The cover `o` has from `c` (CombatGrid.Cover): the best line to any of its squares; other creatures give Half.
func cover(c: Combatant, o: BattleObject) -> int:
	var e := enc()
	var best: int = CombatGrid.Cover.TOTAL
	var held: Combatant = e.get_c(o.holds) if o.holds != "" else null
	var others := e.creature_cells([c, held] if held != null else [c])
	for cell in cells_of(o):
		best = mini(best, int(e.grid.cover_between(c.cell, c.size_cells, cell, 1, others)["cover"]))
	return best


# --- Damage and breaking ------------------------------------------------------------------------------

## Deals `parts` ([{amount, type}]) to `o`: Immunity (Poison and Psychic for every object), Resistance and
## Vulnerability by type, Siege Monster's double, and oil's 5 more Fire. At 0 Hit Points it breaks. Returns the damage.
func damage(o: BattleObject, parts: Array, by: Combatant, label: String, details: Array = []) -> int:
	var e := enc()
	if o.destroyed:
		return 0
	var total := 0
	var lit := false
	var notes: Array = details.duplicate()
	for p: Variant in parts:
		var part := p as Dictionary
		var ty := str(part["type"])
		var amount := int(part["amount"])
		if amount <= 0:
			continue
		if ty in o.immune:
			notes.append("%s: immune to %s" % [o.title(), ty.capitalize()])
			continue
		if ty in o.vulnerable:
			amount *= 2
			notes.append("Vulnerable to %s: doubled" % ty.capitalize())
		elif ty in o.resist:
			amount /= 2
			notes.append("Resistant to %s: halved" % ty.capitalize())
		if ty == "fire":
			lit = true
		total += amount
	# A barrel of lamp oil that fire reaches bursts (ObjectFire).
	if lit and total > 0 and not o.bursts.is_empty():
		e.log.add("hit", "%s takes %d Fire (%s)" % [o.title(), total, label], by.id if by != null else "", notes)
		fire.burst(o, by)
		return total
	if lit and o.oil_rounds > 0:
		o.oil_rounds = 0
		total += OIL_FIRE
		notes.append("The oil on it burns: +%d Fire" % OIL_FIRE)
	if total > 0 and by != null and by.creature.has_flag("siege_monster"):
		total *= 2
		notes.append("Siege Monster: double damage to objects")
	if total <= 0:
		e.log.add("info", "%s takes no damage from %s" % [o.title(), label], by.id if by != null else "", notes)
		return 0
	o.hp = maxi(0, o.hp - total)
	e.log.add("hit", "%s takes %d damage (%s): %d/%d left" % [o.title(), total, label, o.hp, o.hp_max], by.id if by != null else "", notes)
	e.events.append({"type": "object_damage", "id": o.id, "amount": total})
	if o.hp <= 0:
		_break(o)
	return total


## A flammable object that nobody wears or carries catches fire (the Burning condition).
func ignite(o: BattleObject) -> void:
	if o.destroyed or not o.flammable or o.burning:
		return
	if not o.bursts.is_empty():
		fire.burst(o, null)
		return
	o.burning = true
	_fires_dirty = true
	enc().log.add("info", "%s catches fire" % o.title(), "")
	enc().events.append({"type": "object_burning", "id": o.id})


## At 0 Hit Points: its squares open (a doorway, floor, or Difficult Terrain rubble), a chandelier falls, a web lets go.
func _break(o: BattleObject) -> void:
	var e := enc()
	o.destroyed = true
	o.hp = 0
	if o.burning:
		o.burning = false
		_fires_dirty = true
	if o.hangs:
		_fall(o)
		return
	if o.holds != "":
		_release(o)
	for cell in o.cells:
		if o.blocks != 0:
			e.grid.set_flag(cell, o.blocks, false)
		if o.leaves == "rubble" and o.blocks != 0:
			e.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
		# A barrel of lamp oil broken open spills its oil there, waiting for a spark.
		if bool(o.bursts.get("oil", false)) and square_at(cell).is_empty():
			squares.append({"cell": cell, "oil": true, "lit": false, "hit": {}})
			e.events.append({"type": "object_fire", "cell": cell, "poured": true})
	e._cover_cache.clear()
	var how := {"doorway": "the way through is open", "rubble": "leaving rubble (Difficult Terrain)"}.get(o.leaves, "") as String
	e.log.add("info", "%s breaks%s" % [o.title(), (", " + how) if how != "" and o.holds == "" else ""], "")
	e.events.append({"type": "object_broken", "id": o.id})


## A chandelier's chain breaks: everyone under it makes the save (data `fall`) or takes the damage and falls Prone
## (half the damage on a success); its squares are left strewn with wreckage (Difficult Terrain). A lit one sets oil
## on its squares alight.
func _fall(o: BattleObject) -> void:
	var e := enc()
	var f := o.fall
	e.log.add("info", "%s comes crashing down" % o.title(), "")
	e.events.append({"type": "object_fall", "id": o.id})
	var rolled := e._roll_damage_dice(str(f.get("damage", "2d6")), false, 0, "Falling %s" % o.name)
	var ab := StringName(str(f.get("save", "dex")))
	for t in e.living():
		if not t.footprint().any(func(cell: Vector2i) -> bool: return cell in o.cells) or t.creature.has_flag("ethereal") or t.altitude > 0:
			continue
		var sv := t.creature.roll_save(e.dice, ab, int(f.get("dc", 12)), [], [], "%s save vs the falling %s (%s)" % [Creature.ABILITY_NAMES[ab], o.name, t.name()])
		var amount := int(rolled["total"]) if not sv.success else int(rolled["total"]) / 2
		e.deal_damage(null, t, [{"amount": amount, "type": str(f.get("type", "bludgeoning"))}], false, "The falling %s" % o.name,
			[sv.describe(), str(rolled["text"])])
		if not sv.success and bool(f.get("prone", false)) and t.is_alive() and not t.is_down() and t.creature.add_condition(&"prone", o.name):
			e.events.append({"type": "condition", "id": t.id})
	for cell in o.cells:
		e.grid.set_flag(cell, CombatGrid.DIFFICULT, true)
	e._cover_cache.clear()
	if bool(f.get("lit", false)):
		expose_to_fire(o.cells, null)


# --- Weapon attacks -----------------------------------------------------------------------------------

## "" if `c` could attack `o` with `option` from where it stands (not counting what's left of its turn).
func attack_why(c: Combatant, o: BattleObject, option: Dictionary) -> String:
	var e := enc()
	if o == null or o.destroyed:
		return "Nothing to attack there"
	if option.is_empty():
		return "No such attack"
	var p := option["profile"] as WeaponProfile
	var melee := bool(option["melee"])
	if str(option.get("improvised", "")) == "o:" + o.id:
		return "Can't throw it at itself"
	if o.hangs and melee:
		return "%s hangs out of reach: a ranged attack or a spell" % o.title()
	if o.holds == c.id and not melee and str(option.get("kind", "")) == "thrown":
		return "Can't throw at the web holding you"
	var dist := distance_ft(c, o)
	if melee and dist > p.reach:
		return "Out of reach (%d ft, reach %d ft)" % [dist, p.reach]
	if not melee:
		var long := p.long_range if p.long_range > 0 else p.normal_range
		if long > 0 and dist > long:
			return "Out of range (%d ft, range %d/%d)" % [dist, p.normal_range, long]
	if cover(c, o) == CombatGrid.Cover.TOTAL:
		return "No clear line: Total Cover"
	if c.creature.has_flag("cant_attack"):
		return "%s can't attack in this form" % c.name()
	if c.creature is Monster and option.has("action_id"):
		var gone := e.ground.weapon_gone(c, (c.creature as Monster).action(str(option["action_id"])))
		if gone != "":
			return gone
	if option.has("improvised"):
		var tw := actions.throw_why(c, option)
		if tw != "":
			return tw
	elif c.creature is Character and str(option.get("kind", "")) in ["thrown", "weapon"] and e.item_count(c, p.item_id) <= 0:
		return "No %s left" % p.name.replace(" (thrown)", "")
	if not e.has_ammo_for(c, option):
		return "No ammunition"
	return ""


## One attack of the Attack action against an object (`option_id` from attack_options): a weapon, an Unarmed Strike or
## a stat-block attack against its Armor Class, cover included. A hit deals the weapon's damage dice and bonus (a
## Critical Hit doubles the dice; an Adamantine weapon's hit on an object is always a Critical Hit, and a Sword of
## Sharpness deals its dice's maximum). Riders that need a creature (Sneak Attack, maneuvers, Weapon Mastery, a magic
## weapon's extra dice) don't apply. A thrown weapon lands by the object; ammunition is used up.
func attack(c: Combatant, oid: String, option_id: String) -> CombatResult:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return CombatResult.fail(why)
	if not c.can_act():
		return CombatResult.fail("%s can't act" % c.name())
	var o := get_object(oid)
	var option := e.option_by_id(c, option_id)
	why = attack_why(c, o, option)
	if why != "":
		return CombatResult.fail(why)
	if c.attacks_left <= 0 and not c.action_available:
		return CombatResult.fail("No attacks left this turn")
	var p := option["profile"] as WeaponProfile
	if "loading" in p.properties and not e.features.has_feat(c, "crossbow_expert") and c.attacks_left > 0 \
			and str(c.get_meta("loading_fired", "")) == "%d:%d" % [e.round_no, e.turn_index]:
		return CombatResult.fail("Loading: one shot with it per action")
	if c.attacks_left > 0:
		c.attacks_left -= 1
	else:
		e.spend_action(c)
		c.took_attack_action = true
		c.attacks_left = e.attacks_per_action(c) - 1 if c.creature is Character else 0
	# A weapon of the second set: that set is taken in hand first.
	option = e.weapons.take_in_hand(c, option)
	p = option["profile"] as WeaponProfile
	if "light" in p.properties and c.light_attack_weapon == "":
		c.light_attack_weapon = p.item_id
	if "loading" in p.properties and not e.features.has_feat(c, "crossbow_expert"):
		c.set_meta("loading_fired", "%d:%d" % [e.round_no, e.turn_index])
	return _strike(c, o, option)


func _strike(c: Combatant, o: BattleObject, option: Dictionary) -> CombatResult:
	var e := enc()
	var r := CombatResult.new()
	var p := option["profile"] as WeaponProfile
	var melee := bool(option["melee"])
	e.spells.end_sanctuary(c, "attacked")
	e.spells.trigger_ends(c, "attack_roll")
	if c.hidden and not e.features.has_feat(c, "skulker"):
		e.reveal(c, "attacked")
	var adv: Array[String] = []
	var dis: Array[String] = []
	_situation(c, o, melee, p, str(option.get("kind", "")), adv, dis)
	var cov := cover(c, o)
	var ac := o.ac + CombatGrid.COVER_BONUS[cov]
	var keys: Array[String] = ["attack", "attack:melee" if melee else "attack:ranged", "attack:%s" % p.ability]
	var t := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, p.attack, ac, keys, adv, dis, "%s → %s (%s)" % [c.name(), o.the(), p.name], p.crit_range)
	var height := height_edge(c, o, option)
	if height != 0:
		t.add_bonus(height, "High ground" if height > 0 else "Low ground")
	# The weapon leaves the hand, or the shot is spent.
	if not melee and c.creature is Character:
		if option.has("improvised"):
			actions.thrown(c, option, null, cells_of(o)[0])
		elif str(option.get("kind", "")) == "thrown":
			e.weapons.throw_item(c, p.item_id, null, cells_of(o)[0])
		elif str(option.get("kind", "")) == "weapon":
			e.weapons._spend_ammo(c, p)
	var details: Array[String] = [t.describe(), p.attack.describe()]
	if cov > 0:
		details.append("%s: AC +%d" % [CombatGrid.COVER_NAMES[cov], CombatGrid.COVER_BONUS[cov]])
	var crit := t.success and (t.critical or _crits_objects(c, option))
	if t.success and crit and not t.critical:
		details.append("Adamantine: a hit on an object is a Critical Hit")
	e.events.append({"type": "object_attack", "by": c.id, "id": o.id, "hit": t.success, "critical": crit, "action": str(option.get("id", ""))})
	if not t.success:
		r.lines.append(e.log.add("miss", "%s misses %s (%d vs AC %d)" % [c.name(), o.the(), t.total, ac], c.id, details))
		return r
	r.hit = true
	r.critical = crit
	var rolled := e._max_damage_dice(p.damage_dice, crit) if _maximizes(c, option) else e._roll_damage_dice(p.damage_dice, crit, p.die_minimum, "%s damage" % p.name)
	var amount := maxi(0, int(rolled["total"]) + p.damage_bonus.total())
	details.append("%s %s%s: %s%s" % [p.name, p.damage_dice, " ×2 (Critical Hit)" if crit else "", rolled["text"],
		" (Sword of Sharpness: every die at its maximum)" if _maximizes(c, option) else ""])
	if p.damage_bonus.total() != 0:
		details.append(p.damage_bonus.describe())
	r.damage = damage(o, [{"amount": amount, "type": str(p.damage_type)}], c, p.name, details)
	return r


## Advantage and Disadvantage on an attack at an object: what the attacker's own state gives (the roll adds those),
## plus long range, a ranged attack with a foe within 5 ft, a Heavy weapon without the score, and an object it can't see.
func _situation(c: Combatant, o: BattleObject, melee: bool, p: WeaponProfile, kind: String, adv: Array[String], dis: Array[String]) -> void:
	var e := enc()
	var dist := distance_ft(c, o)
	if not melee:
		var sharp := e.features.has_feat(c, "sharpshooter") and not kind in ["spell", "thrown"]
		if p != null and p.normal_range > 0 and dist > p.normal_range and not sharp:
			dis.append("long range")
		var close_ok := sharp or (p != null and e.features.has_feat(c, "crossbow_expert") and p.item_id.contains("crossbow")) \
			or (kind == "spell" and e.features.has_feat(c, "spell_sniper"))
		if not close_ok:
			for h in e.hostiles_of(c):
				if h.can_act() and e.distance(c, h) <= 5 and e.can_see(h, c):
					dis.append("ranged attack with %s within 5 ft" % h.name())
					break
	if p != null and "heavy" in p.properties:
		var need := &"str" if melee else &"dex"
		if c.creature.ability_score(need) < 13:
			dis.append("Heavy weapon with %s under 13" % Creature.ABILITY_NAMES[need])
	if not cells_of(o).any(func(cell: Vector2i) -> bool: return e.can_see_space(c, cell)):
		dis.append("you can't see it")


## High ground (the owner's house rule, EncounterSight.height_edge) for a ranged attack at an object: the floor under
## it counts (a chandelier is aimed at from the floor below without a penalty).
func height_edge(c: Combatant, o: BattleObject, option: Dictionary) -> int:
	var e := enc()
	if bool(option.get("melee", true)):
		return 0
	var from: Vector2i = option.get("origin_cell", c.cell)
	var up := 0 if option.has("origin_cell") else c.altitude
	var low := 1 << 20
	for cell in cells_of(o):
		low = mini(low, e.grid.height(cell))
	var rise := e.grid.height(from) + up - low
	if rise > CombatGrid.FEET:
		return EncounterSight.HIGH_GROUND
	if rise < -CombatGrid.FEET:
		return -EncounterSight.HIGH_GROUND
	return 0


## Adamantine Weapon (2024 DMG): its hit on an object is a Critical Hit.
func _crits_objects(c: Combatant, option: Dictionary) -> bool:
	for it in enc().items.attack_items(c, option):
		if bool(((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("crits_objects", false)):
			return true
	return false


## Sword of Sharpness (2024 DMG): against an object, its weapon damage dice are at their maximum.
func _maximizes(c: Combatant, option: Dictionary) -> bool:
	for it in enc().items.attack_items(c, option):
		if "sharpness" in (((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("special", []) as Array):
			return true
	return false


# --- Spells -------------------------------------------------------------------------------------------

## Whether a spell can be aimed at an object (its targets say "object" or "creature_or_object") and harms it.
static func hits_objects(s: Dictionary) -> bool:
	var tk := str((s.get("targets", {}) as Dictionary).get("kind", ""))
	return tk in ["object", "creature_or_object"] and (s.has("attack") or s.has("damage")) and not bool(s.get("on_hit_spell", false))


static func _fire_spell(s: Dictionary) -> bool:
	for d: Variant in s.get("damage", []):
		if str((d as Dictionary).get("type", "")) == "fire":
			return true
	return false


## SpellTargeting._check_targets for a spell aimed at `ref` (opts.object): an object's id, or "square:x_y" for oil on
## the ground (a fire spell lights it). "" if it can be targeted.
func spell_target_why(c: Combatant, s: Dictionary, ref: String, rng: int) -> String:
	var e := enc()
	var sq := square_ref(ref)
	if sq.x >= 0:
		var patch := square_at(sq)
		if patch.is_empty() or not bool(patch.get("oil", false)) or bool(patch.get("lit", false)):
			return "No unlit oil there"
		if not _fire_spell(s) or not (hits_objects(s) or s.has("attack")):
			return "Only fire lights the oil"
		if e.grid.distance_ft(c.cell, c.size_cells, sq, 1) > rng:
			return "Out of range (%d ft)" % rng
		if int(e.grid.cover_between(c.cell, c.size_cells, sq, 1)["cover"]) == CombatGrid.Cover.TOTAL:
			return "No line of effect"
		return ""
	if not hits_objects(s):
		return "%s can't be aimed at an object" % s.get("name", "That spell")
	var o := get_object(ref)
	if o == null or o.destroyed:
		return "Nothing to aim at there"
	if o.hangs and str(s.get("attack", "")) == "melee":
		return "%s hangs out of reach" % o.title()
	if distance_ft(c, o) > rng:
		return "%s is out of range (%d ft)" % [o.title(), rng]
	if cover(c, o) == CombatGrid.Cover.TOTAL:
		return "No line of effect to %s" % o.the()
	return ""


## SpellCasting._resolve for a spell cast at an object or at oil (opts.object). True when it did (nothing else runs).
## An attack roll against the object's Armor Class for each shot (Eldritch Blast's beams), the damage on a hit (a
## Critical Hit doubles the dice), and a flammable object hit by a spell that says so catches fire; a fire spell aimed
## at oil on the ground lights it (the floor can't dodge).
func resolve_spell(ctx: Dictionary, r: CombatResult) -> bool:
	var ref := str((ctx.get("opts", {}) as Dictionary).get("object", ""))
	if ref == "":
		return false
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var sq := square_ref(ref)
	if sq.x >= 0:
		r.lines.append(e.log.add("spell", "%s's %s strikes the oil" % [c.name(), s["name"]], c.id))
		e.events.append({"type": "object_throw", "by": c.id, "cell": sq, "item": ""})
		expose_to_fire([sq], c)
		return true
	var o := get_object(ref)
	if o == null or o.destroyed:
		r.lines.append(e.log.add("info", "%s finds nothing left to strike" % s["name"], c.id))
		return true
	var shots := 1
	var dmg := s.get("damage", []) as Array
	if not dmg.is_empty() and str((dmg[0] as Dictionary).get("per", "")) == "beam":
		shots = e.spells.specials.beams(c)
	for i in shots:
		if o.destroyed:
			break
		if s.has("attack"):
			_spell_shot(ctx, o, r)
		else:
			var rolled := e.spells.damage._roll_spell_damage(ctx, null, false)
			r.damage += damage(o, [{"amount": int(rolled["total"]), "type": e.spells._damage_type(ctx)}], c, str(s["name"]), [str(rolled["text"])])
	if bool(s.get("ignites_objects", false)) and r.hit:
		ignite(o)
	return true


func _spell_shot(ctx: Dictionary, o: BattleObject, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var melee := str(s["attack"]) == "melee"
	var adv: Array[String] = []
	var dis: Array[String] = []
	_situation(c, o, melee, null, "spell", adv, dis)
	var cov := cover(c, o)
	var ac := o.ac + CombatGrid.COVER_BONUS[cov]
	var atk := (ctx["nums"] as Dictionary)["attack"] as Breakdown
	var keys: Array[String] = ["attack", "attack:melee" if melee else "attack:ranged", "attack:spell"]
	var t := c.creature.roll_d20(e.dice, D20Test.Kind.ATTACK_ROLL, atk, ac, keys, adv, dis, "%s → %s (%s)" % [c.name(), o.the(), s["name"]],
		int(s.get("crit_range", 20)))
	var height := height_edge(c, o, {"melee": melee})
	if height != 0:
		t.add_bonus(height, "High ground" if height > 0 else "Low ground")
	e.events.append({"type": "object_attack", "by": c.id, "id": o.id, "hit": t.success, "critical": t.critical and t.success, "action": "spell:" + str(s["id"])})
	if not t.success:
		r.lines.append(e.log.add("miss", "%s's %s misses %s (%d vs AC %d)" % [c.name(), s["name"], o.the(), t.total, ac], c.id, [t.describe(), atk.describe()]))
		return
	r.hit = true
	r.critical = r.critical or t.critical
	var rolled := e.spells.damage._roll_spell_damage(ctx, null, t.critical)
	r.damage += damage(o, [{"amount": int(rolled["total"]), "type": e.spells._damage_type(ctx)}], c, str(s["name"]), [t.describe(), str(rolled["text"])])


## A spell's area resolved (SpellSaves._save_spell, SpellAttacks._secondary): the objects in it take its damage rolled
## for the creatures, in full (objects fail every save), when it's of a type that harms things (`area_types`; a door
## is caught when a square beside it is); flammable ones catch fire when the spell says so (`ignite_them`); fire
## lights the oil and burns the webs in it.
func area_spell(ctx: Dictionary, cells: Array, shared: Dictionary, multi: Array, ignite_them: bool) -> void:
	if cells.is_empty() or (shared.is_empty() and multi.is_empty()):
		return
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var parts: Array = []
	if not multi.is_empty():
		for pr: Variant in multi:
			parts.append({"amount": int((pr as Dictionary)["total"]), "type": str((pr as Dictionary)["type"]), "text": str((pr as Dictionary)["text"])})
	else:
		parts.append({"amount": int(shared["total"]), "type": e.spells._damage_type(ctx), "text": str(shared.get("text", ""))})
	var types := kinds().get("area_types", []) as Array
	var harmful := parts.filter(func(p: Dictionary) -> bool: return str(p["type"]) in types)
	var texts: Array = harmful.map(func(p: Dictionary) -> String: return str(p["text"]))
	for o: BattleObject in list.duplicate():
		if o.destroyed or not _in_area(o, cells):
			continue
		if not harmful.is_empty():
			damage(o, harmful, c, str(s["name"]), texts)
		if ignite_them:
			ignite(o)
	if parts.any(func(p: Dictionary) -> bool: return str(p["type"]) == "fire" and int(p["amount"]) > 0):
		expose_to_fire(cells, c)


## Whether an area's squares reach `o`: one of its squares, or (a door, which the area can't fill) a square beside it.
func _in_area(o: BattleObject, cells: Array) -> bool:
	for cell in cells_of(o):
		if cell in cells:
			return true
		if o.blocks == CombatGrid.WALL:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if cell + d in cells:
					return true
	return false


# --- Fire on the ground: oil and webs -----------------------------------------------------------------

## "square:x_y" -> the square, else (-1, -1).
static func square_ref(ref: String) -> Vector2i:
	if not ref.begins_with("square:"):
		return Vector2i(-1, -1)
	var xy := ref.substr(7).split("_")
	return Vector2i(int(xy[0]), int(xy[1])) if xy.size() == 2 else Vector2i(-1, -1)


static func square_key(cell: Vector2i) -> String:
	return "square:%d_%d" % [cell.x, cell.y]


func square_at(cell: Vector2i) -> Dictionary:
	for sq in squares:
		if sq["cell"] == cell:
			return sq
	return {}


## Fire reaches `cells` (a fire spell's area, burning oil, a lit chandelier falling): the oil there lights, and the
## webs there burn.
func expose_to_fire(cells: Array, by: Combatant) -> void:
	for sq: Dictionary in squares.duplicate():
		if bool(sq.get("oil", false)) and not bool(sq.get("lit", false)) and sq["cell"] in cells:
			_light(sq)
	_burn_webs(cells)
	for o: BattleObject in list.duplicate():
		if not o.bursts.is_empty() and not o.destroyed and cells_of(o).any(func(cell: Vector2i) -> bool: return cell in cells):
			fire.burst(o, by)


## Lit oil (2024 Oil): it burns until the end of the turn 2 rounds after it was lit, 5 Fire to a creature that enters
## the square or ends its turn there, once a turn.
func _light(sq: Dictionary, what: String = "The oil on the floor catches fire") -> void:
	var e := enc()
	sq["lit"] = true
	sq["until_round"] = e.round_no + OIL_BURNS
	sq["until_index"] = e.turn_index
	sq["damage"] = str(OIL_FIRE)
	sq["on"] = ["enter", "end"]
	sq["hit"] = {}
	_fires_dirty = true
	e.log.add("info", what, "")
	e.events.append({"type": "object_fire", "cell": sq["cell"]})


## Fire on the open floor of `cell` that burns like lit oil (a burst barrel's oil, a brazier's coals), logged as `what`.
func burning_square(cell: Vector2i, what: String) -> void:
	var sq := square_at(cell)
	if sq.is_empty():
		sq = {"cell": cell, "oil": true, "lit": false, "hit": {}}
		squares.append(sq)
	if not bool(sq.get("lit", false)):
		_light(sq, what)


## The Web spell (2024): webs are flammable; a 5-ft cube of them exposed to fire burns away in 1 round, 2d4 Fire to a
## creature that starts its turn in the fire. The burning squares stop holding anyone at once (deviations.md).
func _burn_webs(cells: Array) -> void:
	var e := enc()
	var any := false
	for z in e.spells.zones.live():
		if z.spell_id != "web":
			continue
		var burnt: Array[Vector2i] = []
		for cell in z.cells:
			if cell in cells:
				burnt.append(cell)
		if burnt.is_empty():
			continue
		for cell in burnt:
			z.cells.erase(cell)
			if square_at(cell).is_empty():
				squares.append({"cell": cell, "web": true, "lit": true, "until_round": e.round_no + 1, "until_index": e.turn_index,
					"damage": WEB_FIRE, "on": ["start"], "hit": {}})
		for t in e.living():
			if not t.footprint().any(func(cell: Vector2i) -> bool: return cell in burnt):
				continue
			for fx: Effect in t.creature.effects.duplicate():
				if fx.source_id == "web" and fx.caster_id == z.caster_id:
					t.creature.remove_effect(fx)
					e.log.add("info", "%s is free: the web around it burns away" % t.name(), t.id)
		if z.cells.is_empty():
			z.ended = true
		e.events.append({"type": "object", "id": z.id, "kind": "zone", "cell": z.cell})
		e.log.add("info", "The web catches fire", z.caster_id)
		_fires_dirty = true
		any = true
	if any:
		e.spells.zones.prune()
		e.spells.zones.refresh_auras()


## A creature standing in a burning square takes its fire when the square says (once a turn).
func _burn(c: Combatant, sq: Dictionary, label: String) -> void:
	var e := enc()
	var key := "%d:%d" % [e.round_no, e.turn_index]
	var hit := sq.get("hit", {}) as Dictionary
	if str(hit.get(c.id, "")) == key or not c.is_alive():
		return
	hit[c.id] = key
	sq["hit"] = hit
	var expr := str(sq.get("damage", "5"))
	var amount := int(expr)
	var text := expr
	if expr.contains("d"):
		var rolled := e._roll_damage_dice(expr, false, 0, label)
		amount = int(rolled["total"])
		text = str(rolled["text"])
	e.deal_damage(null, c, [{"amount": amount, "type": "fire"}], false, label, ["%s: %s Fire" % [label, text]])


## Whether `c` is in burning square `sq`: on its floor (burning oil and coals), or anywhere in it (a burning web).
func _stands_in(c: Combatant, sq: Dictionary) -> bool:
	return sq["cell"] in c.footprint() and (bool(sq.get("web", false)) or c.altitude <= 0)


## EncounterTurns, the start of `c`'s turn: a burning web burns whoever starts its turn in it; webs whose prey is gone go.
func turn_start(c: Combatant) -> void:
	_tidy()
	for sq: Dictionary in squares.duplicate():
		if bool(sq.get("lit", false)) and "start" in (sq.get("on", []) as Array) and _stands_in(c, sq):
			_burn(c, sq, "The burning web")


## EncounterTurns, the end of `c`'s turn: burning oil burns whoever ends its turn in it; fires that have burned out go out.
func turn_end(c: Combatant) -> void:
	var e := enc()
	for sq: Dictionary in squares.duplicate():
		if bool(sq.get("lit", false)) and "end" in (sq.get("on", []) as Array) and _stands_in(c, sq):
			_burn(c, sq, "Burning oil")
	for sq: Dictionary in squares.duplicate():
		if not bool(sq.get("lit", false)):
			continue
		var ur := int(sq.get("until_round", 0))
		if e.round_no > ur or (e.round_no == ur and e.turn_index >= int(sq.get("until_index", 0))):
			squares.erase(sq)
			_fires_dirty = true
			e.log.add("info", "The fire on the floor burns out", "")
			e.events.append({"type": "object_fire", "cell": sq["cell"], "out": true})


## EncounterMovement, each step (walking or pushed): entering burning oil burns; a creature on fire lights oil it steps in.
func on_moved(c: Combatant, from: Vector2i) -> void:
	var was := CombatGrid.footprint(from, c.size_cells)
	var on_fire := c.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("douse", false)))
	for sq: Dictionary in squares.duplicate():
		if not _stands_in(c, sq) or sq["cell"] in was:
			continue
		if bool(sq.get("lit", false)) and "enter" in (sq.get("on", []) as Array):
			_burn(c, sq, "Burning oil")
		elif on_fire and bool(sq.get("oil", false)) and not bool(sq.get("lit", false)):
			_light(sq)


## EncounterTurns, a new round: each burning object takes 1d4 Fire (the Burning condition at the start of its turn;
## an object has no turn, so it burns as the round begins), and the oil on objects dries.
func round_started() -> void:
	var e := enc()
	fire.spread()
	for o: BattleObject in list.duplicate():
		if o.oil_rounds > 0:
			o.oil_rounds -= 1
		if o.burning and not o.destroyed:
			var rolled := e._roll_damage_dice(BURN_DICE, false, 0, "Burning (%s)" % o.name)
			damage(o, [{"amount": int(rolled["total"]), "type": "fire"}], null, "burning", [str(rolled["text"])])


## Light from burning objects and squares on `cell`: "bright", "dim" or "" (EncounterSight.light_at).
func light_at(cell: Vector2i) -> String:
	if _fires_dirty:
		_fires.clear()
		for o in list:
			if o.burning and not o.destroyed:
				_fires.append_array(cells_of(o))
		for sq in squares:
			if bool(sq.get("lit", false)):
				_fires.append(sq["cell"] as Vector2i)
		_fires_dirty = false
	if _fires.is_empty():
		return ""
	var light := kinds().get("fire_light", {"bright": 10, "dim": 10}) as Dictionary
	var best := ""
	for f in _fires:
		var d := enc().grid.distance_ft(f, 1, cell, 1)
		if d <= int(light["bright"]):
			return "bright"
		if d <= int(light["bright"]) + int(light["dim"]):
			best = "dim"
	return best


# --- Oil (2024 PHB) -----------------------------------------------------------------------------------

## Whether `c` carries `item_id` loose or in an adventuring pack.
func carries(c: Combatant, item_id: String) -> bool:
	return count(c, item_id) > 0


## How many `item_id` `c` carries, loose and in its packs.
func count(c: Combatant, item_id: String) -> int:
	if not c.creature is Character:
		return 0
	var n := 0
	for en in (c.creature as Character).inventory:
		if int(en.get("qty", 0)) <= 0:
			continue
		if str(en["id"]) == item_id:
			n += int(en["qty"])
			continue
		for x: Variant in Compendium.shared().item_data(str(en["id"])).get("contents", []):
			if str((x as Dictionary).get("id", "")) == item_id:
				n += int((x as Dictionary).get("qty", 1)) * int(en["qty"])
	return n


## Uses up one `item_id`: a loose one, else a pack holding one is opened (its contents become loose things).
func _use_up(c: Combatant, item_id: String) -> bool:
	var ch := c.creature as Character
	if ch == null:
		return false
	if ch.entry_of(item_id).is_empty():
		for en: Dictionary in ch.inventory.duplicate():
			var data := Compendium.shared().item_data(str(en["id"]))
			if int(en.get("qty", 0)) > 0 and (data.get("contents", []) as Array).any(func(x: Variant) -> bool: return str((x as Dictionary).get("id", "")) == item_id):
				ch.remove_one(str(en["id"]), en)
				for x: Variant in data["contents"]:
					ch.add_item(str((x as Dictionary)["id"]), int((x as Dictionary).get("qty", 1)))
				enc().log.add("info", "%s opens the %s" % [c.name(), str(data.get("name", en["id"])).to_lower()], c.id)
				break
	if ch.entry_of(item_id).is_empty():
		return false
	ch.remove_one(item_id)
	return true


## The Oil save's DC: 8 + the thrower's Dexterity modifier and Proficiency Bonus.
func oil_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"dex") + c.creature.proficiency_bonus()


## "" if `c` can throw Oil now (one attack of the Attack action), else why not.
func throw_why(c: Combatant) -> String:
	var e := enc()
	var why := e.features_attack_why(c)
	if why != "":
		return why
	if not carries(c, "oil"):
		return "No Oil"
	return ""


## Throwing a flask of Oil (2024 PHB), in place of one attack of the Attack action, at a creature or an object within
## 20 ft: a creature makes a Dexterity save (DC 8 + Dexterity modifier + Proficiency Bonus) or is covered in oil for a
## minute; an object is covered (it fails). The next Fire damage a covered target takes is 5 more.
func throw_oil(c: Combatant, t: Combatant, o: BattleObject) -> CombatResult:
	var e := enc()
	var why := throw_why(c)
	if why == "" and t == null and o == null:
		why = "Choose a creature or an object"
	if why == "" and t != null and (e.distance(c, t) > OIL_RANGE or t == c):
		why = "Out of range (%d ft)" % OIL_RANGE if t != c else "Choose someone else"
	if why == "" and t != null and int(e.cover(c, t)["cover"]) == CombatGrid.Cover.TOTAL:
		why = "No clear line"
	if why == "" and o != null:
		if o.destroyed:
			why = "Nothing there"
		elif distance_ft(c, o) > OIL_RANGE:
			why = "Out of range (%d ft)" % OIL_RANGE
		elif cover(c, o) == CombatGrid.Cover.TOTAL:
			why = "No clear line"
	if why != "":
		return CombatResult.fail(why)
	e.use_one_attack(c)
	_use_up(c, "oil")
	var r := CombatResult.new()
	if o != null:
		e.events.append({"type": "object_throw", "by": c.id, "cell": cells_of(o)[0], "item": "oil"})
		o.oil_rounds = OIL_DRIES
		r.lines.append(e.log.add("info", "%s throws a flask of oil: %s is covered in it" % [c.name(), o.the()], c.id))
		return r
	e.events.append({"type": "object_throw", "by": c.id, "cell": t.cell, "item": "oil"})
	var sv := t.creature.roll_save(e.dice, &"dex", oil_dc(c), [], [], "Dexterity save vs Oil (%s)" % t.name())
	if sv.success:
		r.lines.append(e.log.add("info", "%s throws a flask of oil at %s, who dodges it" % [c.name(), t.name()], c.id, [sv.describe()]))
		return r
	var fx := Effect.new("Covered in oil", &"item", "oil")
	fx.caster_id = c.id
	fx.stack_key = "item:oil:covered"
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = t.id
	fx.data["oiled"] = true
	t.creature.add_effect(fx)
	e.events.append({"type": "condition", "id": t.id})
	r.hit = true
	r.lines.append(e.log.add("condition", "%s is covered in oil: its next Fire damage is %d more" % [t.name(), OIL_FIRE], t.id, [sv.describe()]))
	return r


## What pouring or lighting costs `c` now: "action" (Utilize), or "bonus" for a Thief's Fast Hands; "" for neither.
func _utilize_cost(c: Combatant) -> String:
	var e := enc()
	if e._action_check(c) == "":
		return "action"
	if CombatFeatures.has_feature(c, "fast_hands") and e._bonus_check(c) == "":
		return "bonus"
	return ""


## "" if `c` could pour Oil on `cell` now: level ground within 5 ft, with no oil on it yet.
func pour_why(c: Combatant, cell: Vector2i) -> String:
	var e := enc()
	var why := e._turn_check(c)
	if why != "":
		return why
	if not c.can_act():
		return "Can't act"
	if not carries(c, "oil"):
		return "No Oil"
	if _utilize_cost(c) == "":
		return "Action already used"
	if not e.grid.in_bounds(cell) or (e.grid.flags(cell) & (CombatGrid.WALL | CombatGrid.LOW | CombatGrid.VOID | CombatGrid.WATER)) != 0:
		return "Only on open ground"
	if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > 5:
		return "Within 5 ft"
	if not square_at(cell).is_empty():
		return "There's oil there already"
	return ""


## Pouring a flask of Oil (2024 PHB, the Utilize action) over a 5-ft square of ground within 5 ft. It burns once lit.
func pour_oil(c: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var why := pour_why(c, cell)
	if why != "":
		return CombatResult.fail(why)
	if _utilize_cost(c) == "action":
		e.spend_action(c)
	else:
		c.bonus_available = false
	_use_up(c, "oil")
	squares.append({"cell": cell, "oil": true, "lit": false, "hit": {}})
	e.events.append({"type": "object_fire", "cell": cell, "poured": true})
	e.log.add("info", "%s pours a flask of oil over the floor" % c.name(), c.id)
	return CombatResult.new()


## "" if `c` could light the oil on `cell` with a Tinderbox now (a Bonus Action within 5 ft, 2024 Tinderbox).
func light_why(c: Combatant, cell: Vector2i) -> String:
	var e := enc()
	var why := e._bonus_check(c)
	if why != "":
		return why
	if not carries(c, "tinderbox"):
		return "No Tinderbox"
	var sq := square_at(cell)
	if sq.is_empty() or not bool(sq.get("oil", false)) or bool(sq.get("lit", false)):
		return "No unlit oil there"
	if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) > 5:
		return "Within 5 ft"
	return ""


func light_oil(c: Combatant, cell: Vector2i) -> CombatResult:
	var why := light_why(c, cell)
	if why != "":
		return CombatResult.fail(why)
	c.bonus_available = false
	enc().log.add("info", "%s strikes a light from a tinderbox" % c.name(), c.id)
	_light(square_at(cell))
	return CombatResult.new()


# --- Hooks on creatures -------------------------------------------------------------------------------

## EncounterDamage.deal_damage, before the damage lands: a creature covered in oil takes 5 more Fire with the first
## Fire damage it takes, and the oil burns away. Returns the parts to deal.
func adjust_incoming(target: Combatant, parts: Array) -> Array:
	if not parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) == "fire" and int((p as Dictionary).get("amount", 0)) > 0):
		return parts
	for fx: Effect in target.creature.effects.duplicate():
		if bool(fx.data.get("oiled", false)):
			target.creature.remove_effect(fx)
			enc().log.add("info", "The oil on %s burns: %d more Fire" % [target.name(), OIL_FIRE], target.id)
			var out := parts.duplicate()
			out.append({"amount": OIL_FIRE, "type": "fire"})
			return out
	return parts


## EncounterDamage.deal_damage, after: Fire that reaches a creature standing in oil or in a web exposes the square.
func on_damaged(target: Combatant, parts: Array) -> void:
	if not parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) == "fire" and int((p as Dictionary).get("amount", 0)) > 0):
		return
	if squares.is_empty() and not enc().spells.zones.live().any(func(z: FieldObject) -> bool: return z.spell_id == "web"):
		return
	expose_to_fire(target.footprint(), null)


## A giant spider's Web (2025 MM): the restraining effect lasts until the web holding the creature is destroyed (the
## kind's AC and Hit Points). MonsterActions calls this when a stat block's rider names an `object`.
func hold(t: Combatant, kind_id: String, fx: Effect) -> BattleObject:
	var o := add(kind_id, t.footprint(), {"holds": t.id, "hold_source": fx.source_id})
	enc().log.add("info", "%s is held fast: the web (AC %d, %d Hit Points) must be broken" % [t.name(), o.ac, o.hp], t.id)
	return o


## A web broken: the creature it held is free.
func _release(o: BattleObject) -> void:
	var e := enc()
	var t := e.get_c(o.holds)
	if t == null:
		return
	for fx: Effect in t.creature.effects.duplicate():
		if fx.source_id == o.hold_source:
			t.creature.remove_effect(fx)
	e.log.add("info", "%s is free of the web" % t.name(), t.id)
	e.events.append({"type": "condition", "id": t.id})


## Webs whose creature died or got free some other way go quietly.
func _tidy() -> void:
	var e := enc()
	for o in list:
		if o.destroyed or o.holds == "":
			continue
		var t := e.get_c(o.holds)
		if t == null or not t.is_alive() or not t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_id == o.hold_source):
			o.destroyed = true
			o.hp = 0


# --- The hotbar and the square menu -------------------------------------------------------------------

func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String) -> Dictionary:
	return {"id": id, "tab": ActionCatalog.ITEMS, "label": label, "sub": sub, "cost": cost, "legal": why == "", "reason": why,
		"targeting": targeting, "count": 1, "repeat": false, "range": 0, "spell_id": "", "slot": 0, "option_id": "",
		"kind": "object", "help": help}


## The Items tab's Oil (2024 PHB): throwing a flask, pouring one, and lighting a puddle with a Tinderbox.
func item_entries(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not c.creature is Character:
		return out
	var e := enc()
	if carries(c, "oil"):
		var n := count(c, "oil")
		var t := _entry("oil:throw", "Throw Oil", "%d · DC %d Dex" % [n, oil_dc(c)], "attack" if c.attacks_left > 0 else "action", throw_why(c),
			"creature", "One attack of the Attack action: a creature within 20 ft makes a Dexterity save or is covered in oil for a minute (an object just is); its next Fire damage is 5 more. Right-click an object's square to throw at it.")
		t["range"] = OIL_RANGE
		t["item_id"] = "oil"
		out.append(t)
		var cost := _utilize_cost(c)
		var why := e._turn_check(c)
		if why == "" and cost == "":
			why = "Action already used"
		var p := _entry("oil:pour", "Pour Oil", "5-ft square", cost if cost != "" else "action", why, "place",
			"Utilize: pour the flask over a square of open ground within 5 ft. Lit, it burns until the end of the turn 2 rounds later: 5 Fire to a creature entering it or ending its turn there.")
		p["range"] = 5
		p["item_id"] = "oil"
		out.append(p)
	if carries(c, "tinderbox") and squares.any(func(sq: Dictionary) -> bool: return bool(sq.get("oil", false)) and not bool(sq.get("lit", false)) \
			and e.grid.distance_ft(c.cell, c.size_cells, sq["cell"] as Vector2i, 1) <= 5):
		var l := _entry("oil:light", "Light the Oil", "Tinderbox", "bonus", e._bonus_check(c), "place", "A Bonus Action with a Tinderbox: set alight oil within 5 ft.")
		l["range"] = 5
		l["item_id"] = "tinderbox"
		out.append(l)
	return out


## The square menu's lines for `cell` (ActionCatalog.square_actions): attacking what stands or hangs there (each
## weapon that can, and each spell that can be aimed at an object), throwing Oil at it, lighting oil on the floor.
func square_entries(c: Combatant, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := enc()
	if e._turn_check(c) != "":
		return out
	out.append_array(actions.square_entries(c, cell))
	for o in objects_at(cell):
		if o.open:
			continue
		var seen := {}
		var first_why := ""
		for opt in e.attack_options(c):
			if str(opt["kind"]) == "blade" or str(opt.get("improvised", "")) == "o:" + o.id:
				continue
			var label := "Attack %s: %s" % [o.the(), str(opt["label"])]
			if seen.has(label):
				continue
			seen[label] = true
			var why := attack_why(c, o, opt)
			if why == "" and c.attacks_left <= 0 and not c.action_available:
				why = "No attacks left this turn"
			if why != "":
				if first_why == "":
					first_why = why
				continue
			out.append(_line("object:%s:attack:%s" % [o.id, opt["id"]], label, "", "attack"))
		if seen.size() > 0 and not out.any(func(x: Dictionary) -> bool: return str(x["id"]).begins_with("act:object:%s:attack:" % o.id)):
			out.append(_line("object:%s:attack:" % o.id, "Attack %s" % o.the(), first_why, "attack"))
		for sp in e.spells.castable(c):
			var s := Compendium.shared().spell_data(str(sp["id"]))
			if not hits_objects(s) or int(s.get("level", 0)) > 0:
				continue
			var why2 := str(sp["reason"]) if not bool(sp["legal"]) else spell_target_why(c, s, o.id, e.spells.range_ft(s, c))
			if why2 == "":
				out.append(_line("object:%s:spell:%s" % [o.id, sp["id"]], "%s at %s" % [s["name"], o.the()], "", str(sp["casting"])))
		if carries(c, "oil"):
			var why3 := throw_why(c)
			if why3 == "" and distance_ft(c, o) > OIL_RANGE:
				why3 = "Out of range (%d ft)" % OIL_RANGE
			out.append(_line("object:%s:oil" % o.id, "Throw Oil at %s" % o.the(), why3, "attack"))
	var sq := square_at(cell)
	if not sq.is_empty() and bool(sq.get("oil", false)) and not bool(sq.get("lit", false)):
		for sp2 in e.spells.castable(c):
			var s2 := Compendium.shared().spell_data(str(sp2["id"]))
			if int(s2.get("level", 0)) > 0 or not _fire_spell(s2) or not hits_objects(s2) or not bool(sp2["legal"]):
				continue
			if spell_target_why(c, s2, square_key(cell), e.spells.range_ft(s2, c)) == "":
				out.append(_line("%s:spell:%s" % [square_key(cell), sp2["id"]], "%s at the oil" % s2["name"], "", str(sp2["casting"])))
		if carries(c, "tinderbox"):
			out.append(_line("%s:light" % square_key(cell), "Light the oil (Tinderbox)", light_why(c, cell), "bonus"))
	return out


func _line(id: String, label: String, why: String, cost: String) -> Dictionary:
	var a := _entry(id, label, "", {"bonus_action": "bonus", "reaction": "reaction", "attack": "attack", "bonus": "bonus"}.get(cost, "action") as String,
		why, "none", "")
	a["tab"] = ActionCatalog.COMMON
	return {"id": "act:%s" % id, "label": label, "enabled": why == "", "why": why, "action": a}


## The hotbar's chosen action aimed at `cell` (a click on an object's square while choosing a target): the same action
## against the object there (a weapon attack, a spell that can target objects, a thrown flask of Oil), or at oil on
## the floor (a fire spell). {} if it can't be.
func redirect(c: Combatant, action: Dictionary, cell: Vector2i) -> Dictionary:
	var e := enc()
	var kind := str(action.get("kind", ""))
	var spell := Compendium.shared().spell_data(str(action.get("spell_id", ""))) if kind == "spell" else {}
	var objs := objects_at(cell)
	if not objs.is_empty():
		var o := objs[0]
		var id := ""
		var why := ""
		if kind == "attack":
			id = "object:%s:attack:%s" % [o.id, action["option_id"]]
			why = attack_why(c, o, e.option_by_id(c, str(action["option_id"])))
		elif kind == "spell" and hits_objects(spell):
			id = "object:%s:spell:%s" % [o.id, action["spell_id"]]
			why = str(action["reason"]) if not bool(action["legal"]) else spell_target_why(c, spell, o.id, e.spells.range_ft(spell, c))
		elif str(action.get("id", "")) == "oil:throw":
			id = "object:%s:oil" % o.id
			why = throw_why(c)
		if id == "":
			return {}
		var line := _line(id, "%s: %s" % [o.title(), action["label"]], why, str(action["cost"]))
		var a := line["action"] as Dictionary
		a["object"] = o.id
		return a
	var sq := square_at(cell)
	if kind == "spell" and not sq.is_empty() and bool(sq.get("oil", false)) and not bool(sq.get("lit", false)) and _fire_spell(spell):
		var line2 := _line("%s:spell:%s" % [square_key(cell), action["spell_id"]], "%s at the oil" % spell["name"],
			spell_target_why(c, spell, square_key(cell), e.spells.range_ft(spell, c)), str(action["cost"]))
		return line2["action"] as Dictionary
	return {}


## Carries out an Oil entry or a square menu line (ActionCatalog._perform, kind "object").
func perform(c: Combatant, action: Dictionary, targets: Array, point: Vector2) -> CombatResult:
	var e := enc()
	var id := str(action["id"])
	var cell := Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else Vector2i(-1, -1)
	if cell.x < 0 and not targets.is_empty() and targets[0] is Combatant:
		cell = (targets[0] as Combatant).cell   # a square chosen by clicking whoever stands on it
	var handled := actions.perform(c, id)
	if handled != null:
		return handled
	match id:
		"oil:throw":
			var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
			return throw_oil(c, t, null)
		"oil:pour":
			return pour_oil(c, cell)
		"oil:light":
			return light_oil(c, cell)
	if id.begins_with("square:"):
		var ref := id.get_slice(":", 0) + ":" + id.get_slice(":", 1)
		var at := square_ref(ref)
		var what := id.substr(ref.length() + 1)
		if what == "light":
			return light_oil(c, at)
		if what.begins_with("spell:"):
			return e.spells.cast(c, what.substr(6), 0, [], Vector2.INF, Vector2.ZERO, {"object": ref})
		return CombatResult.fail("Not available")
	if not id.begins_with("object:"):
		return CombatResult.fail("Not available")
	var oid := id.get_slice(":", 1)
	var rest := id.substr(("object:%s:" % oid).length())
	if rest.begins_with("attack:"):
		if rest == "attack:":
			return CombatResult.fail(str(action.get("reason", "Not available")))
		return attack(c, oid, rest.substr(7))
	if rest.begins_with("spell:"):
		return e.spells.cast(c, rest.substr(6), 0, [], Vector2.INF, Vector2.ZERO, {"object": oid})
	if rest == "oil":
		return throw_oil(c, null, get_object(oid))
	return CombatResult.fail("Not available")


## Hover lines for a square: what stands, hangs or burns there.
func describe_at(cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for o in objects_at(cell):
		if o.blocks != 0 and not o.open:
			continue
		out.append("%s · %s" % [o.title(), " · ".join(o.describe())])
	var sq := square_at(cell)
	if not sq.is_empty():
		if bool(sq.get("lit", false)):
			out.append("On fire: %s Fire to a creature %s" % [str(sq.get("damage", "5")),
				"starting its turn here" if "start" in (sq.get("on", []) as Array) else "entering or ending its turn here"])
		elif bool(sq.get("oil", false)):
			out.append("Oil on the floor: it burns once lit")
	return out


## The hover card for a square something fills (a door, a crate): {title, lines}, or {} for none.
func tooltip(cell: Vector2i) -> Dictionary:
	var o := blocking_at(cell)
	if o == null:
		return {}
	var lines: Array = []
	lines.append_array(o.describe())
	var can: Array[String] = []
	if o.is_door():
		can.append("open it")
	elif o.moves == "shove":
		can.append("shove it")
	elif o.moves == "topple":
		can.append("push it over")
	can.append("attack it")
	lines.append("Right-click: %s" % " or ".join(can))
	return {"title": o.title(), "lines": lines}


# --- Saving a fight -----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var objs: Array = []
	for o in list:
		objs.append(o.to_dict())
	var sqs: Array = []
	for sq in squares:
		var d := sq.duplicate(true)
		d["cell"] = [(sq["cell"] as Vector2i).x, (sq["cell"] as Vector2i).y]
		sqs.append(d)
	return {"objects": objs, "squares": sqs, "placed": placed, "next": _next}


func from_dict(d: Dictionary) -> void:
	list.clear()
	for x: Variant in d.get("objects", []):
		list.append(BattleObject.from_dict(x as Dictionary))
	squares.clear()
	for x2: Variant in d.get("squares", []):
		var sq := (x2 as Dictionary).duplicate(true)
		var a := sq["cell"] as Array
		sq["cell"] = Vector2i(int(a[0]), int(a[1]))
		squares.append(sq)
	placed = bool(d.get("placed", not list.is_empty()))
	_next = int(d.get("next", list.size() + 1))
	_fires_dirty = true
