class_name RavenloftFeatures
extends RefCounted
## Options from Ravenloft: The Horrors Within in a fight: the College of Spirits (Spirits from Beyond, Empowered
## Channeling), Grave Domain (Circle of Mortality, Path to the Grave, Sentinel at Death's Door, Divine Reaper), Hollow
## Warden (Wrath of the Wild and what builds on it), Phantom (Wails from the Grave, soul trinkets, Ghost Walk), Shadow
## Sorcery (Eyes of the Dark, Spirits of Ill Omen, Shadow Walk, Umbral Form), Undead Patron (Form of Dread, Grave
## Touched, Necrotic Husk, Superior Dread), the Dhampir's bite, the Lupin's pounce and howl, the Reborn's past life,
## the Sharp Eye and Survivor feats and the Ravenloft Dark Gifts with their natural-1 drawbacks.
## FeatureActions lists the actions here ("feat:rh:<id>"); the encounter, the attack pipeline, the spell caster and
## the reactions call the hooks below, each next to the matching ClassFeatures hook.

var _enc: WeakRef

## Kept on a drawback's own saving throw so a natural 1 on it doesn't trigger the drawback again.
var _in_drawback: bool = false

## Natural-1 drawbacks of the Ravenloft Dark Gifts: feat id -> [save ability, label].
const NAT1_GIFTS := {
	"aberrant_anatomy": [&"con", "Aberrant Anatomy"],
	"echoing_soul": [&"con", "Echoing Soul"],
	"gathered_whispers": [&"wis", "Gathered Whispers"],
	"living_shadow": [&"wis", "Living Shadow"],
	"symbiotic_being": [&"wis", "Symbiotic Being"],
	"watchers": [&"wis", "Watchers"],
}

## The Spirits from Beyond table (College of Spirits 3).
const SPIRITS := ["", "Beloved", "Sharpshooter", "Avenger", "Renegade", "Fortune Teller", "Wayfarer", "Trickster",
	"Shade", "Arsonist", "Coward", "Brute", "Controlled Channeling"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func cf() -> ClassFeatures:
	return enc().class_features


static func has(c: Combatant, id: String) -> bool:
	return CombatFeatures.has_feature(c, id)


func feat(c: Combatant, feat_id: String) -> bool:
	return enc().features.has_feat(c, feat_id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:rh:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String, n: int = 1) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) >= n else "None left"


## The player's standing rule for an automatic choice (the same per-reaction rules the HUD sets).
static func _allowed(c: Combatant, kind: String) -> bool:
	return str(c.reaction_rules.get(kind, "auto")) != "never"


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


func _roll(expr: String, label: String, critical: bool = false) -> Dictionary:
	return enc()._roll_damage_dice(expr, critical, 0, label)


func _spell_dc(c: Combatant, class_id: String) -> int:
	return cf()._spell_dc(c, class_id)


func _save(t: Combatant, ab: StringName, dc: int, label: String, cond: String = "") -> bool:
	return cf()._save(t, ab, dc, label, cond)


func _effect(c: Combatant, name: String, source: String) -> Effect:
	var fx := Effect.new(name, &"feature", source)
	fx.caster_id = c.id
	return fx


## "Until the start of `owner`'s next turn".
func _until_start(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = owner.id
	return fx


## "Until the end of `owner`'s next turn".
func _until_end(fx: Effect, owner: Combatant) -> Effect:
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = owner.id
	fx.skip_turn_ends = enc().own_turn_skip(owner)
	return fx


func _condition(t: Combatant, fx: Effect, text: String) -> void:
	if t.creature.add_effect(fx):
		_log("condition", text, t)
		enc().events.append({"type": "condition", "id": t.id})


func _active(c: Combatant, flag: String) -> bool:
	return c != null and c.creature.has_flag(flag)


func _end_effects(c: Combatant, source_id: String) -> void:
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == source_id:
			c.creature.remove_effect(fx)


## The most distant unoccupied square from every hostile creature within `feet` of `c` (an automatic escape).
func _safe_cell(c: Combatant, feet: int) -> Vector2i:
	var e := enc()
	var best := Vector2i(-1, -1)
	var best_score := -1
	var steps := feet / 5
	for dx in range(-steps, steps + 1):
		for dy in range(-steps, steps + 1):
			var cell := c.cell + Vector2i(dx, dy)
			if not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or e.occupant_at(cell) != null:
				continue
			if e.grid.distance_ft(c.cell, c.size_cells, cell, c.size_cells) > feet:
				continue
			var nearest := 9999
			for h in e.hostiles_of(c):
				if h.is_alive() and not h.is_down():
					nearest = mini(nearest, e.grid.distance_ft(cell, c.size_cells, h.cell, h.size_cells))
			if nearest > best_score:
				best_score = nearest
				best = cell
	return best


# --- The hotbar -------------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], _aw: String, bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	if has(c, "spirits_from_beyond"):
		var die := ClassFeatures.bardic_die(c)
		out.append(_entry("spirits_from_beyond", "Spirits from Beyond", "d%d · 30 ft" % die, "bonus",
			_first(bw, _res_why(c, "bardic_inspiration")), "creature",
			"Bonus Action and a Bardic Inspiration use: roll d%d on the Spirits from Beyond table; the spirit acts on a creature you see within 30 ft." % die, 30))
	if has(c, "path_to_the_grave"):
		out.append(_entry("path_to_the_grave", "Path to the Grave", "curse · 30 ft", "bonus",
			_first(bw, _res_why(c, "channel_divinity")), "creature",
			"Bonus Action and Channel Divinity: Disadvantage on the creature's attack rolls and saves until your next turn; the first hit on it from you or an ally ends the curse for 1d8 + %d Necrotic or Radiant." % ch.class_level_of("cleric"), 30))
	if has(c, "wrath_of_the_wild") and not _active(c, "wrath_of_the_wild"):
		out.append(_entry("wrath_of_the_wild", "Wrath of the Wild", "transform 1 min", "bonus",
			_first(bw, "" if ch.resource_left("spell:hunters_mark") > 0 else "No Favored Enemy uses left"), "none",
			"Bonus Action and a Favored Enemy use: +%d AC, foes starting their turn within 10 ft make a Wisdom save or are Frightened, and you can strike back when a foe hurts you or an ally beside you." % maxi(1, c.creature.ability_mod(&"wis"))))
	if has(c, "form_of_dread") and not _active(c, "form_of_dread"):
		out.append(_entry("form_of_dread", "Form of Dread", "1 min", "bonus", _first(bw, _res_why(c, "form_of_dread")), "none",
			"Bonus Action: 1d10 + %d Temporary Hit Points, immune to Frightened, and once per turn a hit can frighten (Wisdom save)." % ch.class_level_of("warlock")))
	if has(c, "ghost_walk") and not _active(c, "ghost_walk"):
		var gw := ""
		if ch.resource_left("ghost_walk") <= 0 and ch.resource_left("soul_trinkets") <= 0:
			gw = "None left"
		out.append(_entry("ghost_walk", "Ghost Walk", "10 min", "bonus", _first(bw, gw), "none",
			"Bonus Action: fly 10 ft and hover, attacks against you have Disadvantage, and you move through creatures and objects."))
	if has(c, "shadow_walk"):
		var light := e.light_at(c.cell)
		out.append(_entry("shadow_walk", "Shadow Walk", "teleport 120 ft", "bonus",
			_first(bw, "" if light in ["dim", "dark", "magic_dark"] else "You must stand in Dim Light or Darkness"), "point",
			"Bonus Action: teleport up to 120 ft to a space in Dim Light or Darkness you can see.", 120))
	if has(c, "umbral_form") and not _active(c, "umbral_form"):
		var uw := ""
		if ch.resource_left("umbral_form") <= 0 and ch.resource_left("sorcery_points") < 6:
			uw = "None left"
		out.append(_entry("umbral_form", "Umbral Form", "1 min", "bonus", _first(bw, uw), "none",
			"Bonus Action: Resistance to all damage but Force and Radiant, move through creatures and objects, and a Charisma save keeps you up at 0 Hit Points."))
	if has(c, "howl"):
		out.append(_entry("howl", "Howl", "15 ft · Wis DC %d" % _howl_dc(c), "bonus", _first(bw, _res_why(c, "howl")), "none",
			"Bonus Action: enemies within 15 ft that hear you make a Wisdom save or have Disadvantage on attack rolls and saves until your next turn."))
	if has(c, "shadow_reach") and not _active(c, "shadow_reach"):
		out.append(_entry("shadow_reach", "Shadow Reach", "+10 ft reach", "free", _first(e._turn_check(c), _res_why(c, "shadow_reach")), "none",
			"Your shadow carries your next melee attack this turn: +10 ft reach."))


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	var r := CombatResult.new()
	match id:
		"spirits_from_beyond":
			if t == null or not e.can_see(c, t):
				return CombatResult.fail("Choose a creature you can see within 30 ft")
			ch.spend_resource("bardic_inspiration")
			c.bonus_available = false
			return _spirits(c, t)
		"path_to_the_grave":
			if t == null or t == c or not e.can_see(c, t):
				return CombatResult.fail("Choose a creature you can see within 30 ft")
			ch.spend_resource("channel_divinity")
			c.bonus_available = false
			var fx := _until_start(_effect(c, "Path to the Grave", "path_to_the_grave"), c)
			fx.with_modifier("disadvantage", {"on": "attack"}).with_modifier("disadvantage", {"on": "save:all"}) \
				.with_modifier("flag", {"value": "grave_path:%s" % c.id})
			_condition(t, fx, "%s curses %s: the Path to the Grave" % [c.name(), t.name()])
		"wrath_of_the_wild":
			ch.spend_resource("spell:hunters_mark")
			c.bonus_available = false
			var fx2 := _effect(c, "Wrath of the Wild", "wrath_of_the_wild").with_modifier("flag", {"value": "wrath_of_the_wild"}) \
				.with_modifier("ac", {"value": maxi(1, c.creature.ability_mod(&"wis"))})
			fx2.lasting({"kind": "minutes", "amount": 1})
			fx2.turn_owner_id = c.id
			c.creature.add_effect(fx2)
			_log("info", "%s takes on the Wrath of the Wild" % c.name(), c)
		"form_of_dread":
			ch.spend_resource("form_of_dread")
			c.bonus_available = false
			_form_of_dread(c)
		"ghost_walk":
			if ch.resource_left("ghost_walk") > 0:
				ch.spend_resource("ghost_walk")
			else:
				ch.spend_resource("soul_trinkets")
				_log("info", "%s destroys a soul trinket to walk as a ghost again" % c.name(), c)
			c.bonus_available = false
			var fx3 := _effect(c, "Ghost Walk", "ghost_walk").with_modifier("flag", {"value": "ghost_walk"}) \
				.with_modifier("speed_set", {"kind": "fly", "value": 10}).with_modifier("attacked_with", {"value": "disadvantage"}) \
				.with_modifier("flag", {"value": "incorporeal_movement"})
			fx3.lasting({"kind": "minutes", "amount": 10})
			fx3.turn_owner_id = c.id
			c.creature.add_effect(fx3)
			_log("info", "%s becomes a ghost (Ghost Walk)" % c.name(), c)
		"shadow_walk":
			if cell.x < 0 or not e.light_at(cell) in ["dim", "dark", "magic_dark"]:
				return CombatResult.fail("Choose a square in Dim Light or Darkness")
			var res := e.feature_actions._teleport(c, cell, 120)
			if not res.ok:
				return res
			c.bonus_available = false
			return res
		"umbral_form":
			if ch.resource_left("umbral_form") > 0:
				ch.spend_resource("umbral_form")
			else:
				ch.spend_resource("sorcery_points", 6)
				_log("info", "%s spends 6 Sorcery Points to take Umbral Form again" % c.name(), c)
			c.bonus_available = false
			var fx4 := _effect(c, "Umbral Form", "umbral_form").with_modifier("flag", {"value": "umbral_form"}) \
				.with_modifier("flag", {"value": "incorporeal_movement"})
			for ty: String in ["acid", "bludgeoning", "cold", "fire", "lightning", "necrotic", "piercing", "poison", "psychic", "slashing", "thunder"]:
				fx4.with_modifier("resistance", {"value": ty})
			fx4.lasting({"kind": "minutes", "amount": 1})
			fx4.turn_owner_id = c.id
			fx4.ends_when_incapacitated = true
			c.creature.add_effect(fx4)
			_log("info", "%s melts into shadow (Umbral Form)" % c.name(), c)
		"howl":
			ch.spend_resource("howl")
			c.bonus_available = false
			_howl(c)
		"shadow_reach":
			ch.spend_resource("shadow_reach")
			var fx5 := _effect(c, "Shadow Reach", "shadow_reach").with_modifier("reach", {"value": 10}) \
				.with_modifier("flag", {"value": "shadow_reach"})
			fx5.consume_on = ["attack"]
			fx5.ends = Effect.Ends.END_OF_TURN
			fx5.turn_owner_id = c.id
			c.creature.add_effect(fx5)
			_log("info", "%s's shadow stretches out (+10 ft reach on the next attack)" % c.name(), c)
		_:
			return CombatResult.fail("Not available")
	return r


# --- College of Spirits -------------------------------------------------------------------------------------

## Spirits from Beyond: roll the Bardic Inspiration die (twice with Mystical Connection, keeping the row that suits
## the target) and apply that spirit.
func _spirits(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var die := ClassFeatures.bardic_die(c)
	var roll := e.dice.roll_one(die, "Spirits from Beyond")
	var note := "d%d: %d" % [die, roll]
	if has(c, "mystical_connection"):
		var second := e.dice.roll_one(die, "Spirits from Beyond (Mystical Connection)")
		roll = _better_spirit(c, t, roll, second)
		note = "d%d: %d or %d (Mystical Connection)" % [die, roll, second]
	if roll == 12:
		roll = _better_spirit(c, t, 0, 0)
		note += ", Controlled Channeling picks %s" % SPIRITS[roll]
	_log("spell", "%s channels a spirit at %s: %s" % [c.name(), t.name(), SPIRITS[roll]], c, [note])
	e.events.append({"type": "spell", "caster": c.id, "spell": "spirits_from_beyond", "cells": [], "targets": [t.id]})
	var dc := _spell_dc(c, "bard")
	var cha := c.creature.ability_mod(&"cha")
	var dstr := "1d%d" % die
	match roll:
		1:
			var rolled := _roll(dstr, "Beloved")
			cf()._heal(c, t, maxi(0, int(rolled["total"]) + cha), "Spirits from Beyond (Beloved)")
		2:
			var rolled2 := _roll(dstr, "Sharpshooter")
			e.deal_damage(c, t, [{"amount": maxi(0, int(rolled2["total"]) + cha), "type": "force"}], false, "Sharpshooter spirit", [str(rolled2["text"])])
		3:
			var fx := _until_end(_effect(c, "Avenger spirit", "spirits_avenger"), c).with_modifier("retaliate", {"dice": dstr, "type": "force", "within": 15})
			_condition(t, fx, "An avenging spirit guards %s" % t.name())
		4:
			if t.allied_with(c) or t == c:
				if e.spells.can_react(t):
					var dest := _safe_cell(t, 30)
					if dest.x >= 0:
						t.reaction_available = false
						e.spells._teleport(t, dest, CombatResult.new())
			else:
				_log("info", "%s ignores the renegade spirit's offer" % t.name(), t)
		5:
			var fx2 := _until_start(_effect(c, "Fortune Teller spirit", "spirits_fortune"), c) \
				.with_modifier("advantage", {"on": "attack"}).with_modifier("advantage", {"on": "save:all"}).with_modifier("advantage", {"on": "check:all"})
			_condition(t, fx2, "%s has Advantage on D20 Tests (Fortune Teller)" % t.name())
		6:
			var rolled6 := _roll(dstr, "Wayfarer")
			var amount := int(rolled6["total"]) + _ch(c).class_level_of("bard")
			if t.creature.add_temp_hp(amount, "Wayfarer spirit"):
				var fx3 := _effect(c, "Wayfarer spirit", "spirits_wayfarer").with_modifier("speed", {"value": 10})
				fx3.data["ends_without_temp_hp"] = true
				t.creature.add_effect(fx3)
				_log("heal", "%s gains %d Temporary Hit Points and 10 ft of Speed (Wayfarer)" % [t.name(), amount], t)
		7:
			var rolled7 := _roll("2d%d" % die, "Trickster")
			var ok := _save(t, &"wis", dc, "Trickster spirit", "charmed")
			e.deal_damage(c, t, [{"amount": int(rolled7["total"]) / (2 if ok else 1), "type": "psychic"}], false, "Trickster spirit", [str(rolled7["text"])])
			if not ok and t.is_alive():
				var fx4 := _until_start(_effect(c, "Charmed (Trickster spirit)", "spirits_trickster").with_condition(&"charmed"), c)
				_condition(t, fx4, "%s is Charmed by the trickster spirit" % t.name())
		8:
			var fx5 := _effect(c, "Shade spirit", "spirits_shade").with_condition(&"invisible")
			fx5.ends = Effect.Ends.END_OF_TURN
			fx5.turn_owner_id = t.id
			fx5.skip_turn_ends = e.own_turn_skip(t)
			fx5.ends_on.append_array(["attack_roll", "deal_damage", "cast_spell"])
			fx5.data["shade_die"] = die
			fx5.data["shade_dc"] = dc
			var ref: WeakRef = weakref(t)
			var bard: WeakRef = weakref(c)
			fx5.on_end = func() -> void: _shade_burst(ref.get_ref() as Combatant, bard.get_ref() as Combatant, die, dc)
			_condition(t, fx5, "%s fades from sight (Shade)" % t.name())
		9:
			var rolled9 := _roll("4d%d" % die, "Arsonist")
			var ok9 := _save(t, &"dex", dc, "Arsonist spirit")
			e.deal_damage(c, t, [{"amount": int(rolled9["total"]) / (2 if ok9 else 1), "type": "fire"}], false, "Arsonist spirit", [str(rolled9["text"])])
		10:
			for o: Combatant in [t] + _around(t, 30, c):
				if o.is_alive() and not o.is_down() and (o == t or c.hostile_to(o)) and not _save(o, &"wis", dc, "Coward spirit", "frightened"):
					var fx6 := _until_start(_effect(c, "Frightened (Coward spirit)", "spirits_coward").with_condition(&"frightened"), c) \
						.with_modifier("speed_percent", {"value": 50}).with_modifier("flag", {"value": "action_or_bonus"})
					_condition(o, fx6, "%s cowers (Coward spirit)" % o.name())
		11:
			var rolled11 := _roll("3d%d" % die, "Brute")
			for o2 in _around(t, 30, c):
				if not c.hostile_to(o2) or not o2.is_alive():
					continue
				var ok11 := _save(o2, &"str", dc, "Brute spirit")
				e.deal_damage(c, o2, [{"amount": int(rolled11["total"]) / (2 if ok11 else 1), "type": "thunder"}], false, "Brute spirit", [str(rolled11["text"])])
				if not ok11 and o2.is_alive():
					o2.creature.add_condition(&"prone", "Brute spirit")
					_log("condition", "%s is knocked Prone" % o2.name(), o2)
	e.spells.zones.prune()
	e._check_over()
	return e.run_reaction_queue(CombatResult.new())


## Living creatures within `feet` of `t` (not `t`), for the spirits' areas.
func _around(t: Combatant, feet: int, _from: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for o in enc().living():
		if o != t and not o.is_down() and enc().distance(t, o) <= feet:
			out.append(o)
	return out


## Of two Spirits from Beyond rows (0 = any row, for Controlled Channeling), the one that suits the target: help for
## allies, harm for enemies.
func _better_spirit(c: Combatant, t: Combatant, a: int, b: int) -> int:
	var friend := t == c or t.allied_with(c)
	var rank_ally := [6, 5, 1, 3, 4, 8]
	var rank_foe := [11, 9, 10, 7, 2, 8]
	var order: Array = rank_ally if friend else rank_foe
	if a == 0:
		return int(order[0])
	for want: Variant in order:
		if int(want) == a or int(want) == b:
			return int(want)
	return maxi(a, b)


## Shade: when the invisibility ends, each creature within 5 ft of the target makes a Constitution save or takes two
## rolls of the die in Necrotic damage.
func _shade_burst(t: Combatant, bard: Combatant, die: int, dc: int) -> void:
	var e := enc()
	if e == null or t == null or e.state != Encounter.State.ACTIVE:
		return
	var rolled := _roll("2d%d" % die, "Shade")
	for o in _around(t, 5, t):
		if not _save(o, &"con", dc, "Shade spirit"):
			e.deal_damage(bard, o, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "Shade spirit", [str(rolled["text"])])


# --- Hooks: casting -------------------------------------------------------------------------------------------

## Power from Beyond (College of Spirits 6): once per turn +1d6 to one damage roll of a Bard spell. Returns the bonus
## (and notes it in `bonus`).
func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var c := ctx["c"] as Combatant
	if not has(c, "empowered_channeling") or not _bard_spell(c, ctx["s"] as Dictionary) or not cf()._once(c, "power_from_beyond"):
		return 0
	var v := enc().dice.roll_one(6, "Power from Beyond")
	bonus.add("Power from Beyond (d6)", v)
	return v


## Healing from a spell: Return to Life (Grave Domain 3) makes the dice their maximum for a creature at 0 Hit Points;
## Power from Beyond adds 1d6 once per turn to a Bard spell's healing.
func spell_healing(ctx: Dictionary, t: Combatant, dice: String, total: int) -> int:
	var c := ctx["c"] as Combatant
	var out := return_to_life(c, t, dice, total)
	if has(c, "empowered_channeling") and _bard_spell(c, ctx["s"] as Dictionary) and cf()._once(c, "power_from_beyond"):
		var v := enc().dice.roll_one(6, "Power from Beyond")
		_log("info", "Power from Beyond adds %d to the healing" % v, c)
		out += v
	return out


## Return to Life: dice that restore Hit Points to a creature at 0 count as their maximum. `rolled` is the total the
## dice showed.
func return_to_life(c: Combatant, t: Combatant, dice: String, rolled: int) -> int:
	if dice == "" or t == null or t.creature.hp > 0 or not has(c, "circle_of_mortality"):
		return rolled
	var p := DiceRoller.parse_expr(dice)
	var top := int(p["count"]) * int(p["sides"]) + int(p["modifier"])
	if top > rolled:
		_log("info", "Return to Life: the dice count as %d" % top, c)
	return maxi(rolled, top)


func _bard_spell(c: Combatant, s: Dictionary) -> bool:
	var entry := enc().spells._entry_any(c, str(s.get("id", "")))
	return str(entry.get("class_id", "")) == "bard"


## A Concentration spell these options cast without Concentration: its new duration, or {} if it keeps
## Concentration. Spirits of Ill Omen (Shadow Sorcery 6): Summon Undead, 1 minute. Second Shape (Second Skin): the free
## Alter Self keeps its hour.
func skips_concentration(c: Combatant, s: Dictionary, free: bool) -> Dictionary:
	var sid := str(s.get("id", ""))
	if sid == "summon_undead" and has(c, "spirits_of_ill_omen") and _allowed(c, "spirits_of_ill_omen"):
		return {"kind": "minutes", "amount": 1}
	if sid == "alter_self" and free and has(c, "second_shape"):
		var d := (s.get("duration", {}) as Dictionary).duplicate()
		d.erase("concentration")
		return d
	return {}


## After a spell resolves: Spiritual Manifestation (College of Spirits 6) gives allies inside Spirit Guardians Half
## Cover once per Short Rest; Spirits of Ill Omen's second casting ends the first.
func after_cast(c: Combatant, s: Dictionary, _slot: int) -> void:
	var e := enc()
	var ch := _ch(c)
	if ch == null:
		return
	var sid := str(s.get("id", ""))
	if sid == "spirit_guardians" and has(c, "empowered_channeling") and ch.resource_left("spiritual_manifestation") > 0 \
			and _allowed(c, "spiritual_manifestation"):
		var guard := e.spells.zones.object_of(c.id, "spirit_guardians")
		if guard != null:
			ch.spend_resource("spiritual_manifestation")
			var cover := FieldObject.new(FieldObject.Kind.ZONE, "spiritual_manifestation", "Spiritual Manifestation")
			cover.caster_id = c.id
			cover.follows_caster = true
			cover.cell = guard.cell
			cover.cells = guard.cells.duplicate()
			cover.rules = {"size": int(guard.rule("size", 15)), "affects": "allies", "triggers": [],
				"inside": {"modifiers": [{"stat": "flag", "value": "half_cover"}]}}
			if guard.concentration != null:
				cover.keep_with(guard.concentration)
			else:
				cover.rounds_left = guard.rounds_left
			e.spells.zones.add(cover, CombatResult.new())
			_log("info", "The spirits shield %s's allies too (Half Cover)" % c.name(), c)


## A spell range these options change, or -1: Guidance through Channeler (College of Spirits 3) reaches 60 ft.
func spell_range(c: Combatant, s: Dictionary) -> int:
	if c != null and str(s.get("id", "")) == "guidance" and has(c, "channeler"):
		return 60
	return -1


## Eyes of the Dark (Shadow Sorcery 3): the sorcerer sees through Darkness from its own spells. True when every
## magical Darkness on the field is `a`'s own.
func sees_through_darkness(a: Combatant) -> bool:
	if not has(a, "eyes_of_the_dark"):
		return false
	var any := false
	for o in enc().spells.zones.live():
		if bool(o.rule("darkness", false)):
			if o.caster_id != a.id:
				return false
			any = true
	return any


# --- Hooks: attacks ---------------------------------------------------------------------------------------------

## Vampiric Bite (Dhampir): an Unarmed Strike that bites for 1d4 + Constitution modifier Piercing.
func attack_options(c: Combatant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has(c, "vampiric_bite"):
		return out
	var p := WeaponProfile.unarmed(c.creature)
	p.name = "Vampiric Bite"
	p.damage_dice = "1d4"
	p.damage_type = &"piercing"
	var con := c.creature.ability_mod(&"con")
	var used := c.creature.ability_mod(p.ability)
	if con != used:
		p.damage_bonus.add("Constitution instead of %s" % Creature.ABILITY_SHORT[p.ability], con - used)
	out.append({"id": "bite:vampiric", "label": "Vampiric Bite", "kind": "unarmed", "profile": p, "melee": true,
		"range": [0, 0], "reach": p.reach})
	return out


## Extra damage dice on a weapon or Unarmed Strike hit: Path to the Grave's ending burst, Pull of Death.
func hit_dice(c: Combatant, target: Combatant, _option: Dictionary, st: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var e := enc()
	# Path to the Grave: the cleric (or an ally it sees) ends the curse for 1d8 + Cleric level.
	for fx: Effect in target.creature.effects.duplicate():
		if fx.source_id != "path_to_the_grave":
			continue
		var cleric := e.get_c(fx.caster_id)
		if cleric == null or not (cleric == c or (cleric.allied_with(c) and e.can_see(cleric, c))) or not _allowed(cleric, "path_to_the_grave"):
			continue
		target.creature.remove_effect(fx)
		var ty := "radiant"
		if target.creature.resistance_source(&"radiant") != "" or target.creature.immunity_source(&"radiant") != "":
			ty = "necrotic"
		out.append({"dice": "1d8+%d" % _ch(cleric).class_level_of("cleric"), "type": ty, "label": "Path to the Grave"})
		break
	# Pull of Death: once per turn +1d4 Necrotic against a Bloodied creature.
	if has(c, "circle_of_mortality") and target.creature.is_bloodied() and cf()._once(c, "pull_of_death"):
		out.append({"dice": "1d4", "type": "necrotic", "label": "Pull of Death"})
		st["pull_of_death"] = true
	return out


## Flat damage: Dread Hunter (Hollow Warden 15) against Frightened creatures while transformed.
func flat_bonus(c: Combatant, target: Combatant, _option: Dictionary, notes: Array[String]) -> int:
	if has(c, "ancient_endurance") and _active(c, "wrath_of_the_wild") and target.creature.has_condition(&"frightened"):
		var wis := maxi(0, c.creature.ability_mod(&"wis"))
		notes.append("Dread Hunter +%d" % wis)
		return wis
	return 0


## After a weapon or Unarmed Strike hit: Wails from the Grave, Vampiric Bite's empowering, Feral Pounce's shove,
## Frightful Avatar, Hungering Might, Strangling Roots, Vitality Siphon.
func after_hit(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var ch := _ch(c)
	if ch == null:
		return
	var alive := target.is_alive() and not target.is_down()
	var p := option["profile"] as WeaponProfile
	if st.has("sneak") and e.current() == c:
		_wails(c, target)
	if str(option.get("id", "")) == "bite:vampiric":
		_bite(c, target, int(r.damage))
	var attack_action := e.current() == c and c.took_attack_action and not bool((st["opts"] as Dictionary).get("reaction", false))
	if has(c, "feral_pounce") and p.item_id == "unarmed_strike" and alive and attack_action and cf()._once(c, "feral_pounce") \
			and _allowed(c, "feral_pounce"):
		_pounce(c, target)
	if _active(c, "form_of_dread") and alive and cf()._once(c, "frightful_avatar") and _allowed(c, "frightful_avatar"):
		if not _save(target, &"wis", _spell_dc(c, "warlock"), "Frightful Avatar", "frightened"):
			var fx := _until_end(_effect(c, "Frightened (Form of Dread)", "form_of_dread_fear").with_condition(&"frightened"), c)
			_condition(target, fx, "%s is Frightened of %s's dread form" % [target.name(), c.name()])
	if has(c, "hungering_might") and _active(c, "wrath_of_the_wild") and c.creature.is_bloodied() and cf()._once(c, "hungering_might"):
		var rolled := _roll("1d10", "Hungering Might")
		cf()._heal(c, c, int(rolled["total"]) + maxi(1, c.creature.ability_mod(&"wis")), "Hungering Might")
	if has(c, "rot_and_violence") and _active(c, "wrath_of_the_wild") and alive and p.item_id != "unarmed_strike":
		_strangling_roots(c, target, p, int(r.damage))


## Wails from the Grave (Phantom 3): right after Sneak Attack, a second creature within 30 ft of the first takes half
## the Sneak Attack dice as Necrotic; Death's Lament (17) hurts the first creature too. Uses Wails, then a soul trinket.
func _wails(c: Combatant, first: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	if not has(c, "wails_from_the_grave") or not _allowed(c, "wails_from_the_grave"):
		return
	var trinket := false
	if ch.resource_left("wails_from_the_grave") <= 0:
		if not has(c, "tokens_of_the_departed") or ch.resource_left("soul_trinkets") <= 0:
			return
		trinket = true
	var second: Combatant = null
	for o in e.hostiles_of(c):
		if o != first and o.is_alive() and not o.is_down() and e.distance(first, o) <= 30 and e.can_see(c, o):
			if second == null or e.distance(first, o) < e.distance(first, second):
				second = o
	if second == null:
		return
	if trinket:
		ch.spend_resource("soul_trinkets")
	else:
		ch.spend_resource("wails_from_the_grave")
	var v: Variant = ch.class_column("rogue", "sneak_attack")
	var count := int(DiceRoller.parse_expr(str(v) if v != null else "1d6")["count"])
	var dice := "%dd6" % ceili(count / 2.0)
	var rolled := _roll(dice, "Wails from the Grave")
	var why := "Death's Knell" if trinket else "Wails from the Grave"
	e.deal_damage(c, second, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, why, ["%s %s: %s" % [why, dice, rolled["text"]]])
	if has(c, "deaths_friend") and first.is_alive():
		e.deal_damage(c, first, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "Death's Lament", ["%s %s: %s" % [why, dice, rolled["text"]]])


## Vampiric Bite: on a hit against a creature that isn't a Construct or Undead, Drain (heal the damage) or
## Strengthen (the damage as a bonus to the next attack roll or ability check within 1 minute), PB times per Long Rest.
## Drain when the dhampir is hurt at least that much, otherwise Strengthen.
func _bite(c: Combatant, target: Combatant, dealt: int) -> void:
	var ch := _ch(c)
	if dealt <= 0 or target.creature.creature_type in [&"construct", &"undead"] or ch.resource_left("vampiric_bite") <= 0 \
			or not _allowed(c, "vampiric_bite"):
		return
	ch.spend_resource("vampiric_bite")
	if c.creature.max_hp() - c.creature.hp >= dealt:
		cf()._heal(c, c, dealt, "Vampiric Bite (Drain)")
		return
	var fx := _effect(c, "Vampiric Bite (Strengthen)", "vampiric_bite").with_modifier("attack", {"value": dealt}) \
		.with_modifier("check", {"skill": "all", "value": dealt})
	fx.consume_on = ["attack", "check:all"]
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)
	_log("info", "%s is strengthened by the blood: +%d to the next attack roll or ability check" % [c.name(), dealt], c)


## Feral Pounce (Lupin): an Unarmed Strike hit that dealt damage also Shoves (prone, or 5 ft away when the target is
## already prone).
func _pounce(c: Combatant, target: Combatant) -> void:
	var e := enc()
	if Creature.SIZES.find(target.creature.size) > Creature.SIZES.find(c.creature.size) + 1:
		return
	var dc := 8 + c.creature.ability_mod(&"str") + c.creature.proficiency_bonus()
	var ab := &"str" if target.creature.save_bonus(&"str").total() >= target.creature.save_bonus(&"dex").total() else &"dex"
	var sv := target.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs Feral Pounce (%s)" % [Creature.ABILITY_NAMES[ab], target.name()])
	if sv.success:
		_log("info", "%s keeps its feet against %s's pounce" % [target.name(), c.name()], c, [sv.describe()])
	elif not target.creature.has_condition(&"prone"):
		target.creature.add_condition(&"prone", "Feral Pounce")
		_log("condition", "%s's pounce knocks %s Prone" % [c.name(), target.name()], c, [sv.describe()])
	else:
		var moved := e.forced_move(target, e.center_of(c), 5)
		_log("info", "%s's pounce shoves %s %d ft" % [c.name(), target.name(), moved * 5], c, [sv.describe()])


## Strangling Roots (Hollow Warden 11): Sap or Slow on top of the weapon's own mastery (Slow if it dealt damage and
## the weapon isn't already Slow, else Sap).
func _strangling_roots(c: Combatant, target: Combatant, p: WeaponProfile, dealt: int) -> void:
	var e := enc()
	if p.mastery != "slow" and dealt > 0 and not target.creature.effects.any(func(x: Effect) -> bool: return x.name == "Slowed (mastery)"):
		var fx := Effect.new("Slowed (mastery)", &"effect", "slow").with_modifier("speed", {"value": -10})
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		target.creature.add_effect(fx)
		_log("info", "Strangling Roots: %s is Slowed" % target.name(), c)
	elif p.mastery != "sap":
		e.add_mark({"kind": "disadvantage_next_attack", "attacker": target.id, "source": "Sapped by %s (Strangling Roots)" % c.name(),
			"expires_owner": c.id, "expires_phase": "start", "consume": true})
		_log("info", "Strangling Roots: %s is Sapped" % target.name(), c)


# --- Hooks: reactions --------------------------------------------------------------------------------------------

## Whispered Warning (Gathered Whispers): a Reaction adding the Proficiency Bonus to AC against a hit.
func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	var t := st["t"] as D20Test
	var ac := int(st["ac"])
	var ch := _ch(target)
	if ch == null or bool(st["critical"]) or not has(target, "whispered_warning") or ch.resource_left("whispered_warning") <= 0 \
			or not enc().spells.can_react(target):
		return
	var pb := target.creature.proficiency_bonus()
	if t.total >= ac + pb:
		return
	out.append({"kind": "whispered_warning", "reactor": target, "trigger": c.id, "title": "Reaction: Whispered Warning?",
		"text": "%s hits %s: %d vs AC %d. The whispers warn you: +%d AC against this attack, so it misses." % [c.name(), target.name(), t.total, ac, pb],
		"cost": "Reaction and a use of Whispered Warning",
		"use": func() -> void:
			target.reaction_available = false
			ch.spend_resource("whispered_warning")
			_log("reaction", "%s heeds the whispers (+%d AC)" % [target.name(), pb], target),
		"stop": func() -> CombatResult:
			st["ac"] = ac + pb
			return miss.call() as CombatResult})


## Sentinel at Death's Door (Grave Domain 6): a Reaction halving an attack's damage against the cleric or a Bloodied
## creature it sees within 30 ft.
func against_damage(st: Dictionary, total: Callable, cut: Callable, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var target := st["target"] as Combatant
	for p in e.living():
		if not has(p, "sentinel_at_deaths_door") or p.hostile_to(target) or _ch(p).resource_left("sentinel_at_deaths_door") <= 0 \
				or not e.spells.can_react(p):
			continue
		if p != target and (not target.creature.is_bloodied() or e.distance(p, target) > 30 or not e.can_see(p, target)):
			continue
		var pp := p
		out.append({"kind": "sentinel_at_deaths_door", "reactor": p, "trigger": c.id, "title": "Reaction: Sentinel at Death's Door?",
			"text": "%s hits %s for %d damage. Halve it?" % [c.name(), target.name(), total.call()],
			"cost": "Reaction and a use of Sentinel at Death's Door",
			"still": func() -> bool: return e.spells.can_react(pp) and int(total.call()) > 0 and _ch(pp).resource_left("sentinel_at_deaths_door") > 0,
			"use": func() -> void:
				pp.reaction_available = false
				_ch(pp).spend_resource("sentinel_at_deaths_door")
				var whole := int(total.call())
				cut.call(whole - whole / 2, "Sentinel at Death's Door")
				_log("reaction", "%s stands at death's door: the damage to %s is halved" % [pp.name(), target.name()], pp)})
		break


## Reactions queued when a creature takes damage: the Hollow Warden striking back, Mist Step; the symbiote's grip
## loosens when its host is hurt.
func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var e := enc()
	if source == null or target == null or source == target:
		return
	for w in e.living():
		if not _active(w, "wrath_of_the_wild") or not w.hostile_to(source) or w.is_down() or not e.spells.can_react(w):
			continue
		if not (w == target or (w.allied_with(target) and e.distance(w, target) <= 5)):
			continue
		if e.distance(w, source) > w.reach_ft() or e.best_melee_option(w, source).is_empty():
			continue
		e.reaction_queue.append({"kind": "rh_retribution", "reactor": w.id, "trigger": source.id})
	if has(target, "mist_step") and target.creature.hp > 0 and _ch(target).resource_left("mist_step") > 0 and e.spells.can_react(target):
		e.reaction_queue.append({"kind": "rh_mist_step", "reactor": target.id, "trigger": source.id})


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	match str(q["kind"]):
		"rh_retribution":
			var t := e.get_c(str(q["trigger"]))
			return e.spells.can_react(reactor) and t != null and e.distance(reactor, t) <= reactor.reach_ft()
		"rh_mist_step":
			return e.spells.can_react(reactor) and reactor.creature.hp > 0 and _ch(reactor).resource_left("mist_step") > 0
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	var e := enc()
	match str(q["kind"]):
		"rh_retribution":
			return e._opportunity_attack(reactor, trigger)
		"rh_mist_step":
			return mist_step(reactor)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	match kind:
		"rh_retribution":
			return ["Reaction: Wrath of the Wild?", "%s hurt someone beside %s. Strike back with an Opportunity Attack?", "Reaction"]
		"rh_mist_step":
			return ["Reaction: Mist Step?", "%s hurt %s. Dissolve into mist and teleport 15 ft?", "Reaction and a use of Mist Step"]
	return ["Reaction?", "%s / %s", "Reaction"]


## Mist Step (Mist Walker): teleport up to 15 ft to the safest square, leaving any grapple or restraint behind.
func mist_step(c: Combatant) -> CombatResult:
	var e := enc()
	var dest := _safe_cell(c, 15)
	if dest.x < 0:
		return CombatResult.new()
	c.reaction_available = false
	_ch(c).spend_resource("mist_step")
	var r := CombatResult.new()
	e.spells._teleport(c, dest, r)
	if e.grapples.has(c.id):
		e.grapples.erase(c.id)
		c.creature.remove_condition(&"grappled", "Mist Step")
	if c.creature.has_condition(&"restrained"):
		for fx: Effect in c.creature.effects.duplicate():
			if &"restrained" in fx.conditions:
				c.creature.remove_effect(fx)
	_log("reaction", "%s dissolves into mist (Mist Step)" % c.name(), c)
	return r


# --- Hooks: D20 Tests --------------------------------------------------------------------------------------------

## Before a D20 Test: Life Essence (soul trinkets), Sharp Eye on Search and Study.
func before_d20(c: Combatant, _kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var out := {}
	var ch := _ch(c)
	if ch == null:
		return out
	if has(c, "tokens_of_the_departed") and ch.resource_left("soul_trinkets") > 0 and ("death_save" in keys or "save:con" in keys):
		out["advantage"] = ["Life Essence"]
	if feat(c, "sharp_eye") and ("search" in keys or "study" in keys) and ch.resource_left("sharp_eye") > 0 and _allowed(c, "sharp_eye"):
		ch.spend_resource("sharp_eye")
		c.set_meta("sharp_eye_used", true)
		out["advantage"] = (out.get("advantage", []) as Array) + ["Sharp Eye"]
	return out


## After a D20 Test (D20Responses): Sharp Eye's use back after a failed check, Survivor's Initiative reroll, Knowledge from
## a Past Life on a check, Steel Yourself, Symbiote's Vigor and Mist Step on a failed save, and the Dark Gifts' drawbacks
## on a natural 1 (which simply happen).
func d20_offers(c: Combatant, t: D20Test, keys: Array[String], out: Array) -> void:
	var e := enc()
	var ch := _ch(c)
	if ch == null or t.auto_failed:
		return
	# Sharp Eye: a failed check gives the use back.
	if c.has_meta("sharp_eye_used"):
		c.remove_meta("sharp_eye_used")
		out.append({"kind": "sharp_eye", "reactor": c, "forced": true, "use": func() -> void:
			if not t.success and t.target > 0:
				ch.restore_resource("sharp_eye")})
	# Survivor: an Initiative d20 of 9 or lower is rolled again.
	if feat(c, "survivor") and "initiative" in keys:
		out.append({"kind": "survivor", "reactor": c, "title": "Survivor?", "spends_reaction": false,
			"text": func() -> String: return "%s rolls %d for Initiative. Roll the d20 again?" % [c.name(), t.kept], "cost": "Nothing",
			"still": func() -> bool: return t.kept <= 9,
			"use": func() -> void: t.set_natural(e.dice.d20("Survivor"), "Survivor")})
	if t.target > 0:
		match t.kind:
			D20Test.Kind.ABILITY_CHECK:
				if has(c, "knowledge_from_a_past_life"):
					out.append({"kind": "knowledge_from_a_past_life", "reactor": c, "title": "Knowledge from a Past Life?",
						"text": func() -> String: return "%s. Add 1d6 from a past life?" % D20Responses.line(c, t),
						"cost": "A use of Knowledge from a Past Life", "spends_reaction": false,
						"still": func() -> bool: return not t.success and ch.resource_left("knowledge_from_a_past_life") > 0 and t.total + 6 >= t.target,
						"use": func() -> void:
							ch.spend_resource("knowledge_from_a_past_life")
							t.add_bonus(e.dice.roll_one(6, "Knowledge from a Past Life"), "Past Life")})
			D20Test.Kind.SAVING_THROW:
				if feat(c, "survivor") and ("save_vs:charmed" in keys or "save_vs:frightened" in keys):
					out.append({"kind": "survivor_resolve", "reactor": c, "title": "Reaction: Steel Yourself?",
						"text": func() -> String: return "%s. Add your Proficiency Bonus (+%d)?" % [D20Responses.line(c, t), c.creature.proficiency_bonus()],
						"cost": "Reaction and a use of Steel Yourself",
						"still": func() -> bool: return not t.success and ch.resource_left("survivor_resolve") > 0 and e.spells.can_react(c) \
							and t.total + c.creature.proficiency_bonus() >= t.target,
						"use": func() -> void:
							ch.spend_resource("survivor_resolve")
							c.reaction_available = false
							t.add_bonus(c.creature.proficiency_bonus(), "Steel Yourself")})
				if has(c, "symbiote_vigor"):
					out.append({"kind": "symbiote_vigor", "reactor": c, "title": "Symbiote's Vigor?",
						"text": func() -> String: return "%s. Spend a Hit Die (d%d) and add it?" % [D20Responses.line(c, t), _largest_free_hit_die(ch)],
						"cost": "A use of Symbiote's Vigor and a Hit Die", "spends_reaction": false,
						"still": func() -> bool:
							var d := _largest_free_hit_die(ch)
							return not t.success and ch.resource_left("symbiote_vigor") > 0 and d > 0 and t.total + d >= t.target,
						"use": func() -> void:
							var die := _largest_free_hit_die(ch)
							ch.spend_resource("symbiote_vigor")
							ch.hit_dice_spent[str(die)] = int(ch.hit_dice_spent.get(str(die), 0)) + 1
							t.add_bonus(e.dice.roll_one(die, "Symbiote's Vigor"), "Symbiote's Vigor")})
				if has(c, "mist_step") and ("save_vs:grappled" in keys or "save_vs:restrained" in keys):
					out.append({"kind": "mist_step", "reactor": c, "title": "Reaction: Mist Step?",
						"text": func() -> String: return "%s. Dissolve into mist and slip up to 15 ft away, free of grapples and bonds?" % D20Responses.line(c, t),
						"cost": "Reaction and a use of Mist Step",
						"still": func() -> bool: return not t.success and ch.resource_left("mist_step") > 0 and e.spells.can_react(c),
						"use": func() -> void: mist_step(c)})
	if not _in_drawback:
		out.append({"kind": "dark_gift_drawback", "reactor": c, "forced": true, "still": func() -> bool: return t.kept == 1,
			"use": func() -> void: _drawbacks(c)})


func _largest_free_hit_die(ch: Character) -> int:
	var best := 0
	var pool := ch.hit_dice()
	for die: String in pool:
		var entry := pool[die] as Dictionary
		if int(entry["spent"]) < int(entry["total"]):
			best = maxi(best, int(die))
	return best


## A natural 1 on a D20 Test: each Ravenloft Dark Gift with such a drawback calls for its save (DC 13 + PB).
func _drawbacks(c: Combatant) -> void:
	var e := enc()
	for gift_id: String in NAT1_GIFTS:
		if not feat(c, gift_id):
			continue
		var spec := NAT1_GIFTS[gift_id] as Array
		var ab := spec[0] as StringName
		var label := str(spec[1])
		var dc := 13 + c.creature.proficiency_bonus()
		_in_drawback = true
		var sv := c.creature.roll_save(e.dice, ab, dc, [], [], "%s save vs %s's drawback (%s)" % [Creature.ABILITY_NAMES[ab], label, c.name()])
		_in_drawback = false
		_log("info", "A natural 1 stirs %s's dark gift (%s): %s" % [c.name(), label, "resisted" if sv.success else "it takes hold"], c, [sv.describe()])
		if sv.success:
			continue
		match gift_id:
			"aberrant_anatomy":
				_condition(c, _until_end(_effect(c, "Stunned (Aberrant Anatomy)", "aberrant_anatomy").with_condition(&"stunned"), c),
					"%s's body twists against itself: Stunned" % c.name())
			"echoing_soul":
				_condition(c, _until_end(_effect(c, "Echoing Soul", "echoing_soul").with_condition(&"incapacitated") \
					.with_modifier("speed_percent", {"value": 50}), c), "%s's other souls surface: Incapacitated" % c.name())
			"gathered_whispers":
				_condition(c, _until_end(_effect(c, "Gathered Whispers", "gathered_whispers").with_condition(&"deafened") \
					.with_modifier("disadvantage", {"on": "attack"}).with_modifier("disadvantage", {"on": "check:all"}), c),
					"The whispers roar in %s's ears" % c.name())
			"living_shadow":
				_condition(c, _until_start(_effect(c, "Living Shadow", "living_shadow").with_condition(&"incapacitated"), c),
					"%s's shadow takes over" % c.name())
				c.set_meta("shadow_will", true)
			"symbiotic_being":
				var hours := e.dice.roll_one(12, "Symbiotic Being")
				var fx := _effect(c, "Charmed by the symbiote", "symbiotic_being").with_condition(&"charmed") \
					.with_modifier("flag", {"value": "symbiote_control"})
				fx.lasting({"kind": "hours", "amount": hours})
				fx.repeat_save = {"ability": "wis", "dc": dc, "when": "manual", "on_damage": true}
				_condition(c, fx, "The symbiote seizes %s for %d hours" % [c.name(), hours])
			"watchers":
				var fx2 := _effect(c, "The Watchers' attention", "watchers").with_modifier("disadvantage", {"on": "attack"}) \
					.with_modifier("disadvantage", {"on": "save:all"}).with_modifier("disadvantage", {"on": "check:all"})
				fx2.lasting({"kind": "minutes", "amount": 1})
				fx2.turn_owner_id = c.id
				fx2.repeat_save = {"ability": "wis", "dc": dc, "when": "end"}
				_condition(c, fx2, "The watchers' gaze presses on %s: Disadvantage on D20 Tests" % c.name())


## Living Shadow's Ominous Will: the turn after a failed save, a d8 on the Shadow's Will table runs it. 1: no action
## or Bonus Action, all movement spent walking one way (a d4: north, east, south, west); 2-6: no movement or Bonus
## Action, one melee attack (the Attack action) on a random creature in reach, or nothing; 7-8: Prone, turn over.
func _shadow_will(c: Combatant) -> void:
	var e := enc()
	var roll := e.dice.roll_one(8, "Shadow's Will")
	c.bonus_available = false
	if roll == 1:
		var dirs: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
		var dir := dirs[e.dice.roll_one(4, "Shadow's Will direction") - 1]
		c.action_available = false
		_log("info", "%s's shadow walks them away" % c.name(), c)
		e.march(c, dir, c.movement_left, CombatResult.new())
		c.movement_left = 0
	elif roll <= 6:
		c.movement_left = 0
		var near: Array[Combatant] = []
		for o in e.living():
			if o != c and not o.is_down() and e.distance(c, o) <= c.reach_ft():
				near.append(o)
		var opt := e.best_melee_option(c, null)
		if near.is_empty() or opt.is_empty():
			c.action_available = false
			_log("info", "%s's shadow finds no one to strike" % c.name(), c)
			return
		var victim := near[e.dice.roll_one(near.size(), "Shadow's Will target") - 1]
		_log("info", "%s's shadow lashes out at %s" % [c.name(), victim.name()], c)
		e.attack(c, victim, str(opt["id"]))
		c.attacks_left = 0
		c.action_available = false
	else:
		c.creature.add_condition(&"prone", "Living Shadow")
		c.action_available = false
		c.movement_left = 0
		_log("condition", "%s's shadow throws them Prone; their turn is over" % c.name(), c)


# --- Hooks: turns ------------------------------------------------------------------------------------------------

## Initiative was rolled: Draw of Death (Phantom 17) gives a soul trinket back to a phantom with none.
func initiative_rolled() -> void:
	for c in enc().combatants:
		var ch := _ch(c)
		if ch != null and has(c, "deaths_friend") and ch.resource_max("soul_trinkets") > 0 and ch.resource_left("soul_trinkets") <= 0:
			ch.restore_resource("soul_trinkets")
			_log("info", "%s gathers a soul trinket (Draw of Death)" % c.name(), c)


## Start of a creature's turn: the Hollow Warden's Unnerving Aura (and Rot and Violence), the symbiote's control.
func turn_start(c: Combatant) -> void:
	var e := enc()
	if not c.is_alive() or c.is_down():
		return
	for w in e.living():
		if w == c or not _active(w, "wrath_of_the_wild") or not w.hostile_to(c) or w.is_down() or e.distance(w, c) > 10:
			continue
		if c.creature.is_condition_immune(&"frightened"):
			continue
		if _save(c, &"wis", _spell_dc(w, "ranger"), "Unnerving Aura", "frightened"):
			continue
		var fx := _until_start(_effect(w, "Frightened (Unnerving Aura)", "unnerving_aura").with_condition(&"frightened"), c)
		if has(w, "rot_and_violence"):
			fx.with_modifier("flag", {"value": "cant_regain_hp"}).with_modifier("flag", {"value": "no_reactions"})
		_condition(c, fx, "%s is unnerved by %s's aura: Frightened" % [c.name(), w.name()])
		break
	if c.has_meta("shadow_will"):
		c.remove_meta("shadow_will")
		if c.can_act():
			_shadow_will(c)
	if c.creature.has_flag("symbiote_control") and c.can_act():
		e.dodge(c)
		c.movement_left = 0
		c.bonus_available = false
		_log("info", "The symbiote keeps %s on guard (Dodge)" % c.name(), c)


## End of a creature's turn: Incorporeal Movement (Ghost Walk, Umbral Form) costs 1d10 Force inside a creature or
## object.
func turn_end(c: Combatant) -> void:
	var e := enc()
	if not (_active(c, "ghost_walk") or _active(c, "umbral_form")):
		return
	for cell in c.footprint():
		var o := e.occupant_at(cell)
		if e.grid.is_solid(cell) or (o != null and o != c):
			var rolled := _roll("1d10", "Incorporeal Movement")
			e.deal_damage(null, c, [{"amount": int(rolled["total"]), "type": "force"}], false, "ending a turn inside something", [str(rolled["text"])])
			break


## A creature would drop to 0 Hit Points without dying outright: Unholy Resuscitation (Undead Patron 10), Persistent
## Hunt (Hollow Warden 15), Strength of the Grave (Umbral Form). True if it stays up.
func on_zero(c: Combatant, damage: int) -> bool:
	var ch := _ch(c)
	if ch == null:
		return false
	var e := enc()
	if _active(c, "umbral_form"):
		var sv := c.creature.roll_save(e.dice, &"cha", 5 + damage / 2, [], [], "Strength of the Grave (%s)" % c.name())
		if sv.success:
			e.feature_actions._back_up(c, 3 * ch.class_level_of("sorcerer"))
			_log("info", "%s refuses to fall: Strength of the Grave" % c.name(), c, [sv.describe()])
			return true
	if has(c, "ancient_endurance") and _active(c, "wrath_of_the_wild"):
		var slot := 0
		if ch.resource_left("persistent_hunt") <= 0:
			for l in range(4, 10):
				if ch.slots_left(l) > 0:
					slot = l
					break
		if ch.resource_left("persistent_hunt") > 0 or slot > 0:
			if slot > 0:
				ch.expend_slot(slot)
			else:
				ch.spend_resource("persistent_hunt")
			e.feature_actions._back_up(c, 30)
			_log("info", "%s rises again: Persistent Hunt (30 Hit Points)" % c.name(), c)
			return true
	if has(c, "necrotic_husk") and ch.resource_left("unholy_resuscitation") > 0 and _allowed(c, "unholy_resuscitation"):
		ch.spend_resource("unholy_resuscitation")
		var dc := _spell_dc(c, "warlock")
		var rolled := _roll("2d10+%d" % ch.class_level_of("warlock"), "Unholy Resuscitation")
		for o in e.hostiles_of(c):
			if o.is_alive() and e.distance(c, o) <= 30:
				var ok := _save(o, &"con", dc, "Unholy Resuscitation")
				e.deal_damage(c, o, [{"amount": int(rolled["total"]) / (2 if ok else 1), "type": "necrotic"}], false, "Unholy Resuscitation", [str(rolled["text"])])
		e.feature_actions._back_up(c, maxi(10, 10 * c.creature.ability_mod(&"cha")))
		c.creature.add_exhaustion(1)
		_log("info", "%s erupts with deathly energy and rises (Unholy Resuscitation)" % c.name(), c)
		return true
	return false


## A creature died: soul trinkets come back to a Phantom within 30 ft (a Reaction), Keeper of Souls (Grave Domain 17).
func on_death(_source: Combatant, dead: Combatant) -> void:
	var e := enc()
	for p in e.living():
		var ch := _ch(p)
		if ch == null or p.is_down():
			continue
		if has(p, "tokens_of_the_departed") and ch.resource_left("soul_trinkets") < ch.resource_max("soul_trinkets") \
				and e.distance(p, dead) <= 30 and e.can_see(p, dead) and e.spells.can_react(p) and _allowed(p, "soul_trinket"):
			p.reaction_available = false
			ch.restore_resource("soul_trinkets")
			_log("reaction", "%s catches a departing soul (a soul trinket)" % p.name(), p)
		if has(p, "divine_reaper") and p.hostile_to(dead) and e.distance(p, dead) <= 60 and ch.resource_left("keeper_of_souls") > 0 \
				and not p.creature.has_condition(&"incapacitated"):
			var best: Combatant = null
			for a in e.living():
				if (a == p or a.allied_with(p)) and e.distance(p, a) <= 60 and a.creature.max_hp() - a.creature.hp > 0:
					if best == null or (a.creature.max_hp() - a.creature.hp) > (best.creature.max_hp() - best.creature.hp):
						best = a
			if best != null:
				ch.spend_resource("keeper_of_souls")
				cf()._heal(p, best, 3 * ch.class_level_of("cleric"), "Keeper of Souls")


# --- Hooks: damage ------------------------------------------------------------------------------------------------

## Damage about to be dealt: Pull of Death on spells, Arcane Necrosis and Deathly Touch (Necrotic ignores
## Resistance), Grave Touched's Necrotic casting in Form of Dread, Vitality Siphon. Changes `parts` in place.
func adjust_incoming(source: Combatant, target: Combatant, parts: Array) -> void:
	if source == null or target == null or not source.creature is Character:
		return
	var spell := false
	for p: Variant in parts:
		spell = spell or bool((p as Dictionary).get("spell", false))
	# Pull of Death on a damaging spell (weapon hits add it as a die in hit_dice).
	if spell and has(source, "circle_of_mortality") and target.creature.is_bloodied() and source != target and cf()._once(source, "pull_of_death"):
		var rolled := _roll("1d4", "Pull of Death")
		parts.append({"amount": int(rolled["total"]), "type": "necrotic", "spell": true})
		_log("info", "Pull of Death: +%d Necrotic" % int(rolled["total"]), source)
	# Grave Touched: once per turn in Form of Dread, a spell's damage can become Necrotic (chosen when the target
	# resists its type and not Necrotic).
	if spell and has(source, "grave_touched") and _active(source, "form_of_dread"):
		for p2: Variant in parts:
			var d2 := p2 as Dictionary
			var ty := StringName(str(d2["type"]))
			if bool(d2.get("spell", false)) and ty != &"necrotic" and target.creature.immunity_source(&"necrotic") == "" \
					and (target.creature.resistance_source(ty) != "" or target.creature.immunity_source(ty) != "") and cf()._once(source, "grave_touched"):
				d2["type"] = "necrotic"
				_log("info", "Grave Touched: %s's spell turns Necrotic" % source.name(), source)
	for p3: Variant in parts:
		var d3 := p3 as Dictionary
		if str(d3["type"]) != "necrotic":
			continue
		if has(source, "grave_touched") and (bool(d3.get("spell", false)) or bool(d3.get("weapon", false))):
			d3["ignore_resistance"] = true
			d3["ignore_source"] = "Arcane Necrosis"
		elif has(source, "deathly_touch") and str(d3.get("spell_id", "")) == "chill_touch":
			d3["ignore_resistance"] = true
			d3["ignore_source"] = "Touch of Death"
	# Vitality Siphon (Undead Patron 14): once per turn, Necrotic damage in Form of Dread heals the warlock.
	if has(source, "superior_dread") and _active(source, "form_of_dread") and source != target:
		for p4: Variant in parts:
			if str((p4 as Dictionary)["type"]) == "necrotic" and int((p4 as Dictionary)["amount"]) > 0 and cf()._once(source, "vitality_siphon"):
				cf()._heal(source, source, maxi(1, source.creature.ability_mod(&"cha")), "Vitality Siphon")
				break


# --- Undead Patron, Lupin ------------------------------------------------------------------------------------------

func _form_of_dread(c: Combatant) -> void:
	var ch := _ch(c)
	var fx := _effect(c, "Form of Dread", "form_of_dread").with_modifier("flag", {"value": "form_of_dread"}) \
		.with_modifier("condition_immunity", {"value": "frightened"})
	if has(c, "necrotic_husk"):
		fx.with_modifier("immunity", {"value": "necrotic"})
	if has(c, "superior_dread"):
		fx.with_modifier("speed_set", {"kind": "fly", "value": c.creature.speed().total()})
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = c.id
	fx.ends_when_incapacitated = true
	c.creature.add_effect(fx)
	c.creature.remove_condition(&"frightened", "Form of Dread")
	for other: Effect in c.creature.effects.duplicate():
		if &"frightened" in other.conditions:
			c.creature.remove_effect(other)
	var rolled := _roll("1d10+%d" % ch.class_level_of("warlock"), "Facsimile of Life")
	cf()._temp(c, int(rolled["total"]), "Form of Dread")
	_log("info", "%s takes on the Form of Dread" % c.name(), c, [str(rolled["text"])])


func _howl_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"con") + c.creature.proficiency_bonus()


## Howl (Lupin): enemies within 15 ft that can hear make a Wisdom save or have Disadvantage on attack rolls and saves
## until the start of the lupin's next turn.
func _howl(c: Combatant) -> void:
	var e := enc()
	var dc := _howl_dc(c)
	_log("info", "%s howls" % c.name(), c)
	for o in e.hostiles_of(c):
		if not o.is_alive() or o.is_down() or e.distance(c, o) > 15:
			continue
		if _save(o, &"wis", dc, "Howl"):
			continue
		var fx := _until_start(_effect(c, "Howl", "howl"), c).with_modifier("disadvantage", {"on": "attack"}) \
			.with_modifier("disadvantage", {"on": "save:all"})
		_condition(o, fx, "%s quails at the howl" % o.name())
