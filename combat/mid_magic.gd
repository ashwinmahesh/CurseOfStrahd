class_name MidMagic
extends RefCounted
## Spells of levels 5 and 6 whose fight rules need code (2024 PHB): Swift Quiver, Eyebite, Bigby's Hand's other
## hands, Telekinesis on later turns, Animate Objects, Antilife Shell, Globe of Invulnerability, Wall of Force and
## Wall of Stone, Sunbeam's sunlight, Banishing Smite's banishment and Otto's Irresistible Dance's saving action.

var _enc: WeakRef

const HANDLED := ["swift_quiver", "eyebite", "animate_objects", "antilife_shell", "globe_of_invulnerability", "wall_of_force",
	"wall_of_stone", "sunbeam"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func sp() -> SpellCaster:
	return enc().spells


func resolve(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	var s := ctx["s"] as Dictionary
	var c := ctx["c"] as Combatant
	match str(s["id"]):
		"swift_quiver":
			sp()._grant_sustained(ctx, tgt)
			volley(c, tgt[0] if not tgt.is_empty() and tgt[0] != c else _nearest_foe(c), r)
		"eyebite":
			if not tgt.is_empty():
				eye(ctx, tgt[0], r)
			sp()._grant_sustained(ctx, tgt)
		"animate_objects":
			animate_objects(ctx, r)
		"antilife_shell", "globe_of_invulnerability":
			sp()._place_zone(ctx, cells, r)
		"wall_of_force", "wall_of_stone":
			wall(ctx, cells, r)
		"sunbeam":
			sp()._generic(ctx, tgt, cells, r)
			sp()._grant_sustained(ctx, tgt)
			sp()._light(ctx, c, {"bright": 30, "dim": 30, "sunlight": true})
		_:
			return false
	return true


func _nearest_foe(c: Combatant) -> Combatant:
	var e := enc()
	var best: Combatant = null
	var bd := 1 << 30
	for o in e.hostiles_of(c):
		var d := e.distance(c, o)
		if not o.is_down() and d < bd:
			bd = d
			best = o
	return best


# --- Swift Quiver -------------------------------------------------------------------------------------

## Two attacks with a bow or crossbow the caster holds, with conjured ammunition (none of its own is used).
func volley(c: Combatant, t: Combatant, r: CombatResult) -> CombatResult:
	var e := enc()
	if t == null:
		return r
	var opt := {}
	for o in e.attack_options(c):
		var p := o["profile"] as WeaponProfile
		if not bool(o["melee"]) and str(o["kind"]) == "weapon" and ("ammunition" in p.properties or p.item_id.ends_with("bow") or p.item_id.ends_with("crossbow")):
			opt = o
	if opt.is_empty():
		e.log.add("info", "%s has no bow or crossbow for Swift Quiver" % c.name(), c.id)
		return r
	for i in 2:
		if not t.is_alive() or t.is_down():
			break
		var sub := e._resolve_attack(c, t, opt, {"free_ammo": true})
		r.damage += sub.damage
		if e.pending != null:
			return sub
	return r


# --- Eyebite ------------------------------------------------------------------------------------------

## Eyebite: a creature within 60 ft makes a Wisdom save or suffers the chosen effect; one that succeeds can't be
## targeted by this casting again. Asleep: Unconscious until damaged or shaken awake. Panicked: Frightened, and it
## spends its turns fleeing (Dash) until 60 ft away. Sickened: Poisoned, repeating the save at the end of its turns.
func eye(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var seen := ctx.get("eyebite_saved", []) as Array
	if c.has_meta("eyebite_saved"):
		seen = c.get_meta("eyebite_saved") as Array
	if t.id in seen:
		r.lines.append(e.log.add("info", "%s already resisted this Eyebite" % t.name(), t.id))
		return
	if e.distance(c, t) > 60:
		return
	if sp().specials._resists(ctx, t, &"wis"):
		seen.append(t.id)
		c.set_meta("eyebite_saved", seen)
		return
	var mode := str(ctx.get("choice", "asleep"))
	var fx := Effect.new("Eyebite (%s)" % mode.capitalize(), &"spell", "eyebite")
	fx.caster_id = c.id
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = c.id
	match mode:
		"panicked":
			fx.conditions.append(&"frightened")
			fx.modifiers.append(Modifier.of("flag", {"value": "panicked:" + c.id}, "Eyebite", &"spell"))
		"sickened":
			fx.conditions.append(&"poisoned")
			fx.repeat_save = {"ability": "wis", "dc": (ctx["nums"]["dc"] as Breakdown).total(), "when": "end"}
		_:
			fx.conditions.append(&"unconscious")
			fx.ends_on_damage = true
			fx.data["wakeable"] = true
	t.creature.add_effect(fx)
	e.features.end_turning_from(t)
	e.events.append({"type": "condition", "id": t.id})
	r.lines.append(e.log.add("condition", "%s meets the caster's gaze: %s" % [t.name(), mode.capitalize()], t.id))


## A panicked creature (Eyebite) Dashes away from the caster on its turn until it's 60 ft off.
func panic_turn(t: Combatant) -> void:
	var e := enc()
	for m in t.creature.modifiers_for(&"flag"):
		var v := m.text("value")
		if not v.begins_with("panicked:"):
			continue
		var src := e.get_c(v.substr(9))
		if src == null or e.distance(src, t) >= 60:
			return
		t.action_available = false
		t.movement_left += t.speed()
		e.log.add("info", "%s flees in panic" % t.name(), t.id)
		e.flee(t, src, t.movement_left, CombatResult.new())
		t.movement_left = 0
		return


# --- Animate Objects ----------------------------------------------------------------------------------

## Animate Objects: Small objects up to the caster's spellcasting modifier spring to life beside it, using the
## Animated Object stat block (or Large ones counting as two, Huge as three, by the cast-time choice).
func animate_objects(ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var size := str(ctx.get("choice", "small"))
	var budget := maxi(1, int((ctx["nums"] as Dictionary).get("mod", 3)))
	var cost := {"large": 2, "huge": 3}.get(size, 1) as int
	var count := maxi(1, budget / cost)
	var block := SummonBlocks.animated_object(int(ctx["slot"]), size, (ctx["nums"]["attack"] as Breakdown).total(), int((ctx["nums"] as Dictionary).get("mod", 3)))
	for i in count:
		var sub := ctx.duplicate()
		sub["summon_block"] = block
		sp()._summon(sub, Vector2i(-1, -1), r)


# --- Walls --------------------------------------------------------------------------------------------

## Wall of Force and Wall of Stone: squares no one can enter, that block attacks and spells across them (Wall of Force
## as a straight surface or a dome 20 ft across). Creatures in the way are pushed to one side.
func wall(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var area := cells
	if str(ctx.get("choice", "")) == "dome" and (ctx["point"] as Vector2) != Vector2.INF:
		area = sp()._ring(ctx["point"] as Vector2, 10)
	var o := FieldObject.new(FieldObject.Kind.ZONE, str(s["id"]), str(s["name"]))
	o.caster_id = c.id
	o.cells = area
	o.cell = area[0] if not area.is_empty() else c.cell
	o.rules = {"triggers": [], "blocks": true, "colour": "moon_blue" if str(s["id"]) == "wall_of_force" else "stone"}
	o.keep_with(ctx["conc"] as Concentration)
	sp().zones.add(o, r)
	for t in e.living():
		for f in t.footprint():
			if f in area:
				var spot := sp()._free_cell_near(t.cell, t.size_cells)
				var from := t.cell
				t.cell = spot
				e.events.append({"type": "move", "id": t.id, "from": from, "to": spot, "forced": true})
				break
	r.lines.append(e.log.add("spell", "%s rises (%d squares)" % [s["name"], area.size()], c.id))


func blocked_cells() -> Dictionary:
	var out := {}
	for o in sp().zones.live():
		if bool(o.rule("blocks", false)):
			for cell in o.cells:
				out[cell] = true
	return out


## A wall between two creatures blocks attacks and spells.
func wall_between(a: Combatant, b: Combatant) -> bool:
	var walls := blocked_cells()
	if walls.is_empty():
		return false
	var from := Vector2(a.cell) + Vector2(a.size_cells / 2.0, a.size_cells / 2.0)
	var to := Vector2(b.cell) + Vector2(b.size_cells / 2.0, b.size_cells / 2.0)
	var steps := maxi(1, ceili(from.distance_to(to) * 2.0))
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		if walls.has(Vector2i(floori(p.x), floori(p.y))):
			return true
	return false


# --- Antilife Shell, Globe of Invulnerability ------------------------------------------------------------

## Antilife Shell: squares a creature (not a Construct or Undead) can't move into.
func shell_blocks(c: Combatant) -> Dictionary:
	var out := {}
	if str(c.creature.creature_type) in ["construct", "undead"]:
		return out
	for o in sp().zones.live():
		if o.spell_id == "antilife_shell" and o.caster_id != c.id:
			if c.footprint().any(func(f: Vector2i) -> bool: return f in o.cells):
				continue
			for cell in o.cells:
				out[cell] = true
	return out


## A melee reach through the shell: blocked for creatures other than Constructs and Undead.
func shell_blocks_reach(attacker: Combatant, target: Combatant) -> bool:
	if str(attacker.creature.creature_type) in ["construct", "undead"]:
		return false
	for o in sp().zones.live():
		if o.spell_id == "antilife_shell" and o.covers(target) and not o.covers(attacker) and attacker.id != o.caster_id:
			return true
	return false


## The shell's caster moved so a blocked creature is now inside it: the spell ends.
func shell_moved(caster: Combatant) -> void:
	for o in sp().zones.live():
		if o.spell_id != "antilife_shell" or o.caster_id != caster.id:
			continue
		for t in sp().zones._inside(o):
			if t != caster and not str(t.creature.creature_type) in ["construct", "undead"] and caster.hostile_to(t):
				sp()._end_spell_of(caster, "antilife_shell", "the shell was forced onto %s" % t.name())
				return


## Globe of Invulnerability: a spell of the globe's level or lower cast from outside can't affect anything inside.
func globe_blocks(caster: Combatant, t: Combatant, spell_level: int) -> bool:
	for o in sp().zones.live():
		if o.spell_id != "globe_of_invulnerability":
			continue
		var cap := 5 + maxi(0, o.slot - 6)
		if spell_level <= cap and o.covers(t) and not o.covers(caster) and caster.id != o.caster_id:
			return true
	return false


# --- Saves taken as an action ---------------------------------------------------------------------------

## Effects whose save a creature repeats by taking an action (Otto's Irresistible Dance).
func action_saves(c: Combatant) -> Array[Effect]:
	var out: Array[Effect] = []
	for fx: Effect in c.creature.effects:
		if bool(fx.repeat_save.get("by_action", false)):
			out.append(fx)
	return out


func take_action_save(c: Combatant, fx: Effect) -> CombatResult:
	var e := enc()
	var why := e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	e.spend_action(c)
	sp()._repeat_save(c, fx, [])
	# Otto's dance: even freed, it dances its movement away until the end of its next turn.
	if not fx in c.creature.effects and fx.source_id == "ottos_irresistible_dance":
		var fx2 := Effect.new("Dancing it off", &"spell", "ottos_irresistible_dance").with_modifier("speed_set", {"value": 0})
		fx2.ends = Effect.Ends.END_OF_TURN
		fx2.turn_owner_id = c.id
		fx2.skip_turn_ends = 1
		c.creature.add_effect(fx2)
	return CombatResult.new()


## Monsters use their action to repeat such a save at the start of their turn.
func ai_turn(c: Combatant) -> void:
	if c.is_player_controlled() or not c.can_act():
		return
	var saves := action_saves(c)
	if not saves.is_empty() and c.action_available:
		take_action_save(c, saves[0])


# --- Bigby's Hand -------------------------------------------------------------------------------------

## The hand is a Large object that can be attacked: AC 20 and the caster's Hit Point maximum. It stands on the
## board as a creature with no turns of its own (it acts through the caster's Bonus Actions); at 0 Hit Points the
## spell ends.
func spawn_hand(c: Combatant, o: FieldObject) -> void:
	var e := enc()
	var hp := c.creature.max_hp()
	var m := Monster.from_data({"id": "bigbys_hand", "name": "Bigby's Hand", "size": "large", "type": "construct", "alignment": "unaligned",
		"ac": 20, "hp": {"average": hp, "dice": str(hp)}, "speed": {"walk": 0},
		"abilities": {"str": 26, "dex": 10, "con": 10, "int": 1, "wis": 1, "cha": 1},
		"immunities": ["poison", "psychic"], "condition_immunities": ["blinded", "charmed", "deafened", "exhaustion", "frightened",
			"grappled", "incapacitated", "paralyzed", "petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"],
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "summon": true,
		"traits": [{"id": "conjured_object", "name": "Conjured Object", "action": "passive",
			"modifiers": [{"stat": "flag", "value": "spell_object"}, {"stat": "flag", "value": "no_actions"}],
			"summary": "A spell's object: no turns of its own; the spell ends if it's destroyed."}],
		"actions": [], "summary": "A shimmering Large hand of force."})
	var h := e.add(m, c.side, o.cell)
	h.controller = &"ai"
	h.set_meta("hand_of", c.id)
	o.rules["hand_id"] = h.id


## The hand's body follows the hand when it moves.
func sync_hand(o: FieldObject) -> void:
	var h := enc().get_c(str(o.rules.get("hand_id", "")))
	if h != null:
		h.cell = o.cell


## The spell ended: the hand's body goes with it.
func remove_hand(o: FieldObject) -> void:
	var e := enc()
	var h := e.get_c(str(o.rules.get("hand_id", "")))
	if h == null:
		return
	e.combatants.erase(h)
	e.grapples.erase(h.id)
	for k: String in e.grapples.keys():
		if str(e.grapples[k]) == h.id:
			e.grapples.erase(k)
	e.events.append({"type": "vanish", "id": h.id})


## Destroyed: Bigby's Hand ends.
func hand_destroyed(t: Combatant) -> void:
	if not t.has_meta("hand_of"):
		return
	var e := enc()
	var caster := e.get_c(str(t.get_meta("hand_of")))
	e.log.add("info", "Bigby's Hand is shattered", t.id)
	if caster != null and caster.creature.concentration != null and caster.creature.concentration.source_id == "bigbys_hand":
		caster.creature.concentration.end("the hand was destroyed")
	if caster != null:
		sp().zones.end_spell(caster.id, "bigbys_hand")

## The hand's other uses (a Bonus Action after it moves): Forceful Hand (a Strength save or pushed 5 ft + 5 ft per
## spellcasting modifier), Grasping Hand (a Dexterity save or Grappled, escape DC the spell's), Crush (4d6 + modifier
## Bludgeoning, 2d6 more per slot level above 5, to the creature it holds) and Interposing Hand (Half Cover for the
## caster until its next turn).
func bigby(ctx: Dictionary, mode: String, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var hand := sp().zones.object_of(c.id, "bigbys_hand")
	var dc := (ctx["nums"]["dc"] as Breakdown).total()
	var mod := int((ctx["nums"] as Dictionary).get("mod", 3))
	match mode:
		"interpose":
			var cover := Effect.new("Interposing Hand", &"spell", "bigbys_hand").with_modifier("ac", {"value": 2}).with_modifier("save", {"ability": "dex", "value": 2})
			cover.ends = Effect.Ends.START_OF_TURN
			cover.turn_owner_id = c.id
			c.creature.add_effect(cover)
			r.lines.append(e.log.add("spell", "The hand shields %s (Half Cover)" % c.name(), c.id))
			return
	if t == null or hand == null or e.grid.distance_ft(hand.cell, 1, t.cell, t.size_cells) > 5:
		r.lines.append(e.log.add("info", "Nothing within reach of the hand", c.id))
		return
	if Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(&"huge"):
		return
	match mode:
		"push":
			if not sp().specials._resists_ab(ctx, t, &"str"):
				var moved := e.forced_move(t, Vector2(hand.cell) + Vector2(0.5, 0.5), 5 + 5 * mod)
				r.lines.append(e.log.add("info", "The hand shoves %s %d ft" % [t.name(), moved * 5], t.id))
		"grasp":
			if not sp().specials._resists_ab(ctx, t, &"dex"):
				var hold := Effect.new("Grappled (Bigby's Hand)", &"spell", "bigbys_hand").with_condition(&"grappled")
				hold.caster_id = c.id
				hold.escape = {"skill": "athletics", "dc": dc}
				var conc := ctx["conc"] as Concentration
				if conc != null:
					conc.attach(t.creature, hold)
				else:
					t.creature.add_effect(hold)
				hand.rules["holding"] = t.id
				r.lines.append(e.log.add("condition", "The hand closes around %s" % t.name(), t.id))
		"crush":
			if str(hand.rules.get("holding", "")) != t.id or not t.creature.has_condition(&"grappled"):
				r.lines.append(e.log.add("info", "The hand isn't holding %s" % t.name(), c.id))
				return
			var n := 4 + 2 * maxi(0, int(ctx["slot"]) - 5)
			var rolled := e._roll_damage_dice("%dd6" % n, false, 0, "Bigby's Hand crush")
			r.damage += e.deal_damage(c, t, [{"amount": int(rolled["total"]) + mod, "type": "bludgeoning", "spell": true}], false, "Bigby's Hand", [str(rolled["text"])]).final
