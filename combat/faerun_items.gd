class_name FaerunItems
extends RefCounted
## Heroes of Faerûn and Arcana Unleashed magic items whose rules need code (ADR 0012): Mage Breaker, Namer's Needle,
## the Keyholes daggers' shapes and second try, Dispelling and Goading Ammunition, Tramontane Armor's grip and
## Grave Reaper's lantern. ItemSpecials hands over `fr_` custom powers and the weapon specials named here.

var _specials: WeakRef

## The shapes each Keyholes dagger can take (besides its own): weapon item ids, or "simple_melee" for them all.
const KEYHOLE_FORMS := {
	"three_keyholes_dagger": ["handaxe", "mace"],
	"ten_keyholes_dagger": ["simple_melee"],
	"many_keyholes_dagger": ["simple_melee", "battleaxe", "longsword", "rapier", "scimitar", "warhammer"],
}


func _init(specials: ItemSpecials) -> void:
	_specials = weakref(specials)


func sp() -> ItemSpecials:
	return _specials.get_ref() as ItemSpecials


func items() -> CombatItems:
	return sp().items()


func enc() -> Encounter:
	return sp().enc()


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


static func _specials_of(it: Dictionary) -> Array:
	return ((it["data"] as Dictionary).get("weapon_rules", {}) as Dictionary).get("special", []) as Array


## The weapons a Keyholes dagger can become.
static func keyhole_forms(item_id: String) -> Array[String]:
	var out: Array[String] = []
	for f: Variant in KEYHOLE_FORMS.get(item_id, []):
		if str(f) == "simple_melee":
			for w in Compendium.shared().items_where("weapon"):
				if str((w.get("weapon", {}) as Dictionary).get("kind", "")) == "simple_melee" and not str(w["id"]) in out:
					out.append(str(w["id"]))
		elif not str(f) in out:
			out.append(str(f))
	return out


# --- Custom powers -----------------------------------------------------------------------------------------------------

func why(c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	var e := enc()
	# Powers that only work while another of the item's powers is on (the Nightingale's songs).
	if power.has("while_on") and not items().toggled(c, str(p["item_id"]), str(power["while_on"])):
		return "Only while its %s is on" % str(power["while_on"]).replace("_", " ")
	match str(power.get("custom", "")):
		"fr_reshape":
			if e.current() != c:
				return "On your turn, as you attack"
			if c.attacks_left <= 0 and not c.action_available:
				return "Take the Attack action to reshape it"
		"fr_tramontane_pull":
			if not items().toggled(c, str(p["item_id"]), "grip"):
				return "Wake the armor's grip first"
		"fr_martial_throw":
			if e.current() != c:
				return "On your turn, as you attack"
		"fr_orb_sorcery":
			var ch := CombatItems.ch_of(c)
			if ch == null or ch.resource_max("sorcery_points") <= 0:
				return "Only a Sorcerer can draw on it"
			if ch.resource_left("sorcery_points") >= ch.resource_max("sorcery_points"):
				return "No Sorcery Points spent"
	return ""


func use(c: Combatant, p: Dictionary, targets: Array, _point: Vector2, _dir: Vector2, _level: int, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	match str(power.get("custom", "")):
		"fr_reshape":
			return _reshape(c, p, str(opts.get("choice", "")))
		"fr_speak_name":
			c.set_meta("needle_named_crit", true)
			_log("info", "%s readies the true name on the Namer's Needle" % c.name(), c)
			return CombatResult.new()
		"fr_tramontane_pull":
			return _tramontane_pull(c, p, targets)
	return use_more(c, p, targets, _point, _dir, opts)


## After a power's use: Grave Reaper's lantern holds five fragments.
func after_power(c: Combatant, p: Dictionary) -> void:
	if str((p["power"] as Dictionary).get("after", "")) == "fr_lantern_capacity":
		c.set_meta("lantern_capacity", 5)


## The Keyholes daggers: another weapon's statistics until the start of the wielder's next turn, attacking and
## dealing damage with Strength or Dexterity, whichever is better.
func _reshape(c: Combatant, p: Dictionary, form: String) -> CombatResult:
	var iid := str(p["item_id"])
	var tpl := (p["data"] as Dictionary).get("template", {}) as Dictionary
	var base := str(tpl.get("default", "dagger"))
	if form == "" or form == base:
		form = base
	elif not form in keyhole_forms(iid.get_slice("__", 0)):
		return CombatResult.fail("It can't become that")
	for fx: Effect in c.creature.effects.duplicate():
		if fx.stack_key == "keyhole:%s" % iid:
			c.creature.remove_effect(fx)
	var name := Compendium.shared().display_name("items", form)
	var fx2 := Effect.new("%s (%s)" % [(p["data"] as Dictionary).get("name", ""), name], &"item", iid)
	fx2.stack_key = "keyhole:%s" % iid
	fx2.modifiers.append(Modifier.of("weapon_form", {"items": [iid], "form": form, "either_ability": true}, str((p["data"] as Dictionary).get("name", "")), &"item"))
	fx2.ends = Effect.Ends.START_OF_TURN
	fx2.turn_owner_id = c.id
	c.creature.add_effect(fx2)
	_log("info", "%s's dagger reshapes into a %s" % [c.name(), name], c)
	return CombatResult.new()


## Tramontane Armor: chosen creatures within 20 ft make a Strength save (DC 15) or are Grappled (escape DC 15) and
## pulled up to 20 ft toward the wearer.
func _tramontane_pull(c: Combatant, _p: Dictionary, targets: Array) -> CombatResult:
	var e := enc()
	var chosen: Array[Combatant] = []
	for x: Variant in targets:
		if x is Combatant and x != c and (x as Combatant).is_alive() and e.distance(c, x as Combatant) <= 20 and not chosen.has(x as Combatant):
			chosen.append(x as Combatant)
	if chosen.is_empty():
		return CombatResult.fail("Choose creatures within 20 ft")
	items()._pay(c, "bonus")
	for t in chosen:
		var sv := t.creature.roll_save(e.dice, &"str", 15, [], [], "Strength save vs Tramontane Armor (%s)" % t.name(), ["save_vs:grappled"])
		if sv.success:
			_log("info", "%s resists the armor's pull" % t.name(), t, [sv.describe()])
			continue
		if t.creature.add_condition(&"grappled", "Tramontane Armor"):
			e.grapples[t.id] = c.id
			t.set_meta("escape_dc", 15)
		e.forced_move(t, e.center_of(c), 20, true)
		_log("condition", "%s is seized and dragged toward %s (Tramontane Armor)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


# --- Weapon specials ---------------------------------------------------------------------------------------------------

## Before the hit's damage: Mage Breaker marks a concentrating target so its Concentration save has Disadvantage.
func hit_dice(_c: Combatant, target: Combatant, _option: Dictionary, _st: Dictionary, it: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if "mage_breaker" in _specials_of(it) and target.creature.concentration != null:
		target.set_meta("mage_broken", true)
	return out


func after_hit(c: Combatant, target: Combatant, option: Dictionary, dr: DamageResult, st: Dictionary, r: CombatResult, it: Dictionary) -> void:
	var e := enc()
	var label := str((it["data"] as Dictionary).get("name", ""))
	after_hit_more(c, target, option, st, r, it)
	for s: Variant in _specials_of(it):
		match str(s):
			"mage_breaker":
				target.remove_meta("mage_broken")
			"namers_needle":
				_needle(c, target, r)
			"dispelling":
				if dr.final > 0 and target.is_alive():
					var ended: Array[String] = []
					for fx: Effect in target.creature.effects.duplicate():
						if fx.source_kind == &"spell" and fx.spell_level <= 3:
							target.creature.remove_effect(fx)
							if fx.concentration != null and fx.concentration.source_id == fx.source_id:
								fx.concentration.end("dispelled")
							if not fx.name in ended:
								ended.append(fx.name)
					e.spells.zones.prune()
					r.lines.append(e.log.add("spell", "%s: %s" % [label, "ends " + ", ".join(ended) + " on " + target.name() if not ended.is_empty() else "no spell on %s to end" % target.name()], c.id))
			"goading":
				if dr.final > 0 and target.is_alive():
					var sv := target.creature.roll_save(e.dice, &"cha", 13, [], [], "Charisma save vs %s (%s)" % [label, target.name()])
					if sv.success:
						r.lines.append(e.log.add("info", "%s shrugs off the goad" % target.name(), target.id, [sv.describe()]))
					else:
						var fx2 := Effect.new(label, &"item", str(it["id"])).with_modifier("flag", {"value": "no_reactions"})
						fx2.ends = Effect.Ends.START_OF_TURN
						fx2.turn_owner_id = target.id
						target.creature.add_effect(fx2)
						r.lines.append(e.log.add("condition", "%s is goaded: no Reactions until its next turn" % target.name(), target.id, [sv.describe()]))


## Namer's Needle: a hit makes a creature that has a language save (Wisdom DC 15) or speak its name; one that saves
## is immune for the day.
func _needle(c: Combatant, target: Combatant, r: CombatResult) -> void:
	var e := enc()
	if not target.is_alive() or c.id in (target.get_meta("named_to", []) as Array) or c.id in (target.get_meta("needle_immune", []) as Array):
		return
	var langs := (target.creature as Monster).data.get("languages", []) as Array if target.creature is Monster else ["common"]
	if langs.is_empty():
		return
	var sv := target.creature.roll_save(e.dice, &"wis", 15, [], [], "Wisdom save vs Namer's Needle (%s)" % target.name())
	if sv.success:
		var imm := (target.get_meta("needle_immune", []) as Array).duplicate()
		imm.append(c.id)
		target.set_meta("needle_immune", imm)
		r.lines.append(e.log.add("info", "%s keeps its name to itself" % target.name(), target.id, [sv.describe()]))
		return
	var named := (target.get_meta("named_to", []) as Array).duplicate()
	named.append(c.id)
	target.set_meta("named_to", named)
	r.lines.append(e.log.add("info", "%s blurts out its true name (Namer's Needle)" % target.name(), target.id, [sv.describe()]))


## Namer's Needle: once a day, speaking a named creature's name turns a hit with the needle into a Critical Hit.
func makes_crit(c: Combatant, target: Combatant, option: Dictionary, details: Array[String]) -> bool:
	if not bool(c.get_meta("needle_named_crit", false)) or not c.id in (target.get_meta("named_to", []) as Array):
		return false
	var p := option.get("profile") as WeaponProfile
	if p == null or not p.item_id.begins_with("namers_needle"):
		return false
	c.remove_meta("needle_named_crit")
	details.append("Namer's Needle: %s's true name turns the hit into a Critical Hit" % target.name())
	return true


## Many Keyholes Dagger: once a day, a missed attack with it can be rolled again, keeping the new roll.
func after_miss_offers(st: Dictionary) -> Array:
	var out: Array = []
	var c := st["c"] as Combatant
	var t := st["t"] as D20Test
	var option := st["option"] as Dictionary
	var prof := option.get("profile") as WeaponProfile
	if prof == null or not prof.item_id.begins_with("many_keyholes_dagger") or CombatItems.ch_of(c) == null:
		return out
	var p := items().find_power(c, prof.item_id, "second_try")
	if p.is_empty() or CombatItems.uses_spent(p) >= CombatItems.use_count(p):
		return out
	var e := enc()
	out.append({"kind": "keyhole_reroll", "reactor": c, "title": "Second Try?",
		"text": "%d vs AC %d: a miss. Roll the attack again with the Many Keyholes Dagger and keep the new roll?" % [t.total, int(st["ac"])],
		"cost": "Once per day",
		"still": func() -> bool: return not t.success,
		"use": func() -> void:
			CombatItems.spend_use(p)
			var n := e.dice.d20("Many Keyholes Dagger reroll")
			t.set_natural(n, "Many Keyholes Dagger")
			e.log.add("info", "%s tries again with the Many Keyholes Dagger: %d" % [c.name(), n], c.id)})
	return out


# --- Staffs, rods, wands and orbs (batch 9b) ----------------------------------------------------------------------------

## Custom powers of the staffs, rods, wands and orbs.
func use_more(c: Combatant, p: Dictionary, targets: Array, point: Vector2, dir: Vector2, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	var e := enc()
	var label := str((p["data"] as Dictionary).get("name", ""))
	match str(power.get("custom", "")):
		"fr_martial_throw":
			var fx := Effect.new("%s (thrown)" % label, &"item", str(p["item_id"]))
			fx.stack_key = "martial_throw:%s" % p["item_id"]
			fx.modifiers.append(Modifier.of("weapon_form", {"items": [str(p["item_id"])], "add_properties": ["thrown"], "range": [20, 60]}, label, &"item"))
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			fx.skip_turn_ends = e.own_turn_skip(c)
			c.creature.add_effect(fx)
			_log("info", "%s's quarterstaff can be thrown and flies back (%s)" % [c.name(), label], c)
			return CombatResult.new()
		"fr_diamond_stun":
			c.set_meta("diamond_stun", str(p["item_id"]))
			_log("info", "%s readies a stunning blow with the %s" % [c.name(), label], c)
			return CombatResult.new()
		"fr_pulverize":
			var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
			if t == null or t == c or str(t.creature.creature_type) != "humanoid" or not e.can_see(c, t):
				return CombatResult.fail("Choose a Humanoid you can see")
			items()._pay(c, "magic")
			var sv := t.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, t.name()])
			var rolled := e._roll_damage_dice("10d8", false, 0, label)
			var amount := int(rolled["total"]) / (2 if sv.success else 1)
			e.deal_damage(c, t, [{"amount": amount, "type": "necrotic"}], false, label, [sv.describe(), str(rolled["text"])])
			if not sv.success and t.is_alive():
				t.creature.add_condition(&"prone", label)
				e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"fr_slumber_aura":
			items()._pay(c, "magic")
			for t in e.combatants:
				if t == c or not t.is_alive() or t.is_down() or not c.hostile_to(t) or e.distance(c, t) > 30:
					continue
				if str(t.creature.creature_type) in ["undead", "construct"] or t.creature.condition_immunity_source(&"exhaustion") != "":
					_log("info", "%s doesn't sleep" % t.name(), t)
					continue
				var sv2 := t.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, t.name()])
				if sv2.success:
					_log("info", "%s fights off the drowsiness" % t.name(), t, [sv2.describe()])
					continue
				var nap := Effect.new(label, &"item", str(p["item_id"]))
				nap.conditions.append(&"unconscious")
				nap.lasting({"kind": "hours", "amount": 1})
				nap.ends_on_damage = true
				nap.data["wakeable"] = true
				t.creature.add_effect(nap)
				_log("condition", "%s falls into a deep sleep (%s)" % [t.name(), label], t, [sv2.describe()])
				e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"fr_teeth":
			return _teeth(c, p, point, dir, int(str(opts.get("choice", "1"))))
		"fr_orb_sorcery":
			var ch := CombatItems.ch_of(c)
			var spent := ch.resource_max("sorcery_points") - ch.resource_left("sorcery_points")
			if spent <= 0:
				return CombatResult.fail("No Sorcery Points spent")
			items()._pay(c, "magic")
			ch.restore_resource("sorcery_points", mini(2, spent))
			_log("info", "%s draws %d Sorcery Points back from the orb" % [c.name(), mini(2, spent)], c)
			return CombatResult.new()
	return use_wondrous(c, p, targets, point, opts)


## Wand of Teeth: 1 to 3 charges for a 30-ft Cone; Dex DC 15, 1d8 Piercing per charge and Poisoned until the
## wielder's next turn starts, half damage only on a success.
func _teeth(c: Combatant, p: Dictionary, point: Vector2, dir: Vector2, n: int) -> CombatResult:
	var e := enc()
	var ch := CombatItems.ch_of(c)
	var iid := str(p["item_id"])
	n = clampi(n, 1, 3)
	if ch.charges_left(iid) < n:
		return CombatResult.fail("Not enough charges")
	var aim := dir if dir != Vector2.ZERO else ((point - e.center_of(c)) if point != Vector2.INF else Vector2.ZERO)
	if aim.length() < 0.01:
		return CombatResult.fail("Choose a direction")
	var cells := e.grid.area_cells("cone", 30, e.center_of(c), aim.normalized())
	items()._pay(c, "magic")
	ch.spend_charges(iid, n)
	var label := str((p["data"] as Dictionary).get("name", ""))
	e.events.append({"type": "ability", "source": "feature", "by": c.id, "key": "wand_of_teeth", "targets": [], "cells": cells})
	var rolled := e._roll_damage_dice("%dd8" % n, false, 0, label)
	for t in e.combatants:
		if t == c or not t.is_alive() or not t.footprint().any(func(cell: Vector2i) -> bool: return cell in cells):
			continue
		var sv := t.creature.roll_save(e.dice, &"dex", 15, [], [], "Dexterity save vs %s (%s)" % [label, t.name()])
		var amount := int(rolled["total"]) / (2 if sv.success else 1)
		e.deal_damage(c, t, [{"amount": amount, "type": "piercing"}], false, label, [sv.describe(), str(rolled["text"])])
		if not sv.success and t.is_alive():
			var fx := Effect.new(label, &"item", iid).with_condition(&"poisoned")
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			t.creature.add_effect(fx)
	if ch.charges_left(iid) <= 0:
		items().last_charge(c, iid, p["data"] as Dictionary)
	return CombatResult.new()


## Before an attack roll: a Staff of Skulls' holder can spend its Reaction to give an attack by a creature it sees
## within 30 ft Disadvantage; the Martialist's Quarterstaff's wielder can spend a charge for Advantage and a shove.
func before_roll(st: Dictionary, out: Array) -> void:
	var e := enc()
	var c := st["c"] as Combatant
	var sit := st["sit"] as Dictionary
	var option := st["option"] as Dictionary
	var prof := option.get("profile") as WeaponProfile
	if prof != null and prof.item_id.begins_with("martialists_quarterstaff") and bool(option.get("melee", true)) and CombatItems.ch_of(c) != null \
			and CombatItems.ch_of(c).charges_left(prof.item_id) > 0:
		var iid := prof.item_id
		out.append({"kind": "martialist_strike", "reactor": c, "title": "Martialist's Strike?",
			"text": "Spend a charge of the Martialist's Quarterstaff for Advantage, and a hit knocks the target Prone unless it makes a DC 13 Strength save?",
			"cost": "1 charge", "still": func() -> bool: return true,
			"use": func() -> void:
				CombatItems.ch_of(c).spend_charges(iid, 1)
				(sit["advantage"] as Array[String]).append("Martialist's Quarterstaff")
				st["martialist_prone"] = true})
	for h in e.combatants:
		if h == c or not h.is_alive() or not h.hostile_to(c) or not e.spells.can_react(h) or e.distance(h, c) > 30 or not e.can_see(h, c):
			continue
		var staff := ""
		for id: String in ["chattering_staff_of_skulls", "pulverizing_staff_of_skulls"]:
			if items().has_active(h, id):
				staff = id
		if staff == "":
			continue
		out.append({"kind": "staff_of_skulls", "reactor": h, "title": "Staff of Skulls?",
			"text": "%s attacks. Spend your Reaction so the staff's skulls shriek and the attack has Disadvantage?" % c.name(),
			"cost": "Your Reaction", "still": func() -> bool: return h.reaction_available,
			"use": func() -> void:
				h.reaction_available = false
				(sit["disadvantage"] as Array[String]).append("Staff of Skulls")
				e.log.add("reaction", "%s's staff of skulls shrieks at %s" % [h.name(), c.name()], h.id)})
		break


## Diamond Staff's stunning blow and the Martialist's Quarterstaff's shove, after a hit.
func after_hit_more(c: Combatant, target: Combatant, option: Dictionary, st: Dictionary, r: CombatResult, it: Dictionary) -> void:
	var e := enc()
	var iid := str(it["id"])
	var label := str((it["data"] as Dictionary).get("name", ""))
	if bool(st.get("martialist_prone", false)) and iid.begins_with("martialists_quarterstaff") and target.is_alive():
		st.erase("martialist_prone")
		var sv := target.creature.roll_save(e.dice, &"str", 13, [], [], "Strength save vs %s (%s)" % [label, target.name()])
		if not sv.success and target.creature.add_condition(&"prone", label):
			r.lines.append(e.log.add("condition", "%s is knocked Prone (%s)" % [target.name(), label], target.id, [sv.describe()]))
	if str(c.get_meta("diamond_stun", "")) == iid and bool(option.get("melee", true)) and target.is_alive():
		c.remove_meta("diamond_stun")
		var ch := CombatItems.ch_of(c)
		if ch == null or ch.charges_left(iid) < 2:
			return
		ch.spend_charges(iid, 2)
		var sv2 := target.creature.roll_save(e.dice, &"con", 17, [], [], "Constitution save vs %s (%s)" % [label, target.name()], ["save_vs:stunned"])
		if not sv2.success:
			var fx := Effect.new(label, &"item", iid).with_condition(&"stunned")
			fx.caster_id = c.id
			fx.ends = Effect.Ends.END_OF_TURN
			fx.turn_owner_id = c.id
			fx.skip_turn_ends = e.own_turn_skip(c)
			target.creature.add_effect(fx)
			r.lines.append(e.log.add("condition", "%s is Stunned (%s)" % [target.name(), label], target.id, [sv2.describe()]))
		if ch.charges_left(iid) <= 0:
			items().last_charge(c, iid, it["data"] as Dictionary)


## Dissuader: when a creature moves within 5 ft of its holder, the holder can spend its Reaction (once a day) to
## make chosen creatures within 30 ft save (Strength DC 15) or be pushed up to 30 ft away.
func after_step(mover: Combatant, from: Vector2i) -> void:
	var e := enc()
	for h in e.combatants:
		if h == mover or not h.is_alive() or not h.hostile_to(mover) or e.distance(h, mover) > 5:
			continue
		if e.grid.distance_ft(from, mover.size_cells, h.cell, h.size_cells) <= 5:
			continue
		var p := {}
		for it in items().active(h):
			if str(it["id"]).begins_with("dissuader"):
				p = items().find_power(h, str(it["id"]), "repel")
		if p.is_empty() or CombatItems.uses_spent(p) >= CombatItems.use_count(p) or not e.spells.can_react(h) \
				or str(h.reaction_rules.get("dissuader_repel", "auto")) == "never":
			continue
		CombatItems.spend_use(p)
		h.reaction_available = false
		_log("reaction", "%s's Dissuader thrums: back!" % h.name(), h)
		for t in e.combatants:
			if t == h or not t.is_alive() or not h.hostile_to(t) or e.distance(h, t) > 30:
				continue
			var sv := t.creature.roll_save(e.dice, &"str", 15, [], [], "Strength save vs Dissuader (%s)" % t.name())
			if not sv.success:
				e.forced_move(t, e.center_of(h), 30)
				_log("info", "%s is thrown back (Dissuader)" % t.name(), t, [sv.describe()])
		return


# --- Wondrous items (batch 9c) ------------------------------------------------------------------------------------------

## Custom powers of the wondrous items.
func use_wondrous(c: Combatant, p: Dictionary, targets: Array, point: Vector2, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	var e := enc()
	var iid := str(p["item_id"])
	var entry := p["entry"] as Dictionary
	var label := str((p["data"] as Dictionary).get("name", ""))
	match str(power.get("custom", "")):
		"fr_blood_ready":
			c.set_meta("blood_amulet", iid)
			_log("info", "%s's blood amulet thirsts" % c.name(), c)
			return CombatResult.new()
		"fr_rune_ready":
			if str(entry.get("pick", "")) == "":
				return CombatResult.fail("Choose the rune's element after a Long Rest")
			c.set_meta("prismatic_rune", iid)
			_log("info", "%s's prismatic rune glows %s" % [c.name(), str(entry["pick"])], c)
			return CombatResult.new()
		"fr_dream_use":
			if not entry.has("dream"):
				return CombatResult.fail("No dream recorded")
			c.set_meta("portent_next", int(entry["dream"]))
			entry.erase("dream")
			_log("info", "%s calls on the dream woven into the tapestry" % c.name(), c)
			return CombatResult.new()
		"fr_manacle":
			var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
			if t == null or t == c or e.distance(c, t) > 5:
				return CombatResult.fail("Choose a creature within 5 ft")
			if not (t.creature.has_condition(&"grappled") or t.creature.has_condition(&"incapacitated")):
				return CombatResult.fail("It must be Grappled or Incapacitated")
			if Creature.SIZES.find(t.creature.size) > Creature.SIZES.find(&"large"):
				return CombatResult.fail("Too big for the chain")
			items()._pay(c, "magic")
			var sv := t.creature.roll_save(e.dice, &"dex", 15, [], [], "Dexterity save vs %s (%s)" % [label, t.name()], ["save_vs:restrained"])
			if sv.success:
				_log("info", "%s slips the chain" % t.name(), t, [sv.describe()])
				return CombatResult.new()
			var fx := Effect.new("Chained (%s)" % label, &"item", iid).with_condition(&"restrained")
			fx.caster_id = c.id
			fx.lasting({"kind": "hours", "amount": 8})
			t.creature.add_effect(fx)
			CombatItems.spend_use(p)
			_log("condition", "%s is chained (%s)" % [t.name(), label], t, [sv.describe()])
			e.events.append({"type": "condition", "id": t.id})
			return CombatResult.new()
		"fr_manacle_release":
			for t2 in e.combatants:
				for fx2: Effect in t2.creature.effects.duplicate():
					if fx2.source_id == iid and fx2.caster_id == c.id:
						t2.creature.remove_effect(fx2)
						_log("info", "%s releases %s from the chain" % [c.name(), t2.name()], c)
			return CombatResult.new()
		"fr_puppet":
			var to := Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else Vector2i(-1, -1)
			if to.x < 0 or e.grid.distance_ft(c.cell, c.size_cells, to, 1) > 30 or not e.can_see_space(c, to):
				return CombatResult.fail("Choose a space you can see within 30 ft")
			items()._pay(c, "bonus")
			for fx3: Effect in c.creature.effects.duplicate():
				if fx3.stack_key == "puppet:%s" % iid:
					c.creature.remove_effect(fx3)
			var doll := Effect.new(label, &"item", iid)
			doll.stack_key = "puppet:%s" % iid
			doll.data["puppet_cell"] = [to.x, to.y]
			doll.lasting({"kind": "minutes", "amount": 1})
			doll.turn_owner_id = c.id
			c.creature.add_effect(doll)
			_log("info", "%s's puppet hovers at %s" % [c.name(), to], c)
			return CombatResult.new()
	return use_artifact(c, p, targets)


## Spell-Slinger's Puppet: while the doll hovers within 30 ft, its holder speaks through it (Verbal components even
## when it can't speak itself, as long as the doll's square isn't silenced).
func puppet_voice(c: Combatant) -> bool:
	var e := enc()
	for fx: Effect in c.creature.effects:
		if not fx.data.has("puppet_cell"):
			continue
		var at := fx.data["puppet_cell"] as Array
		var cell := Vector2i(int(at[0]), int(at[1]))
		if e.grid.distance_ft(c.cell, c.size_cells, cell, 1) <= 30 and not e.spells.zones.silenced(cell):
			return true
	return false


## Blood Amulet: the next damage its wearer deals (once readied) spends a charge for 2d10 Necrotic and a Constitution
## save (DC 15) against a level of Exhaustion.
func on_damaged(source: Combatant, target: Combatant, amount: int, _parts: Array) -> void:
	if source == null or amount <= 0 or source == target or not source.has_meta("blood_amulet") or not target.is_alive():
		return
	var e := enc()
	var iid := str(source.get_meta("blood_amulet"))
	source.remove_meta("blood_amulet")
	var ch := CombatItems.ch_of(source)
	if ch == null or ch.charges_left(iid) <= 0:
		return
	ch.spend_charges(iid, 1)
	var rolled := e._roll_damage_dice("2d10", false, 0, "Blood Amulet")
	e.deal_damage(source, target, [{"amount": int(rolled["total"]), "type": "necrotic"}], false, "Blood Amulet", [str(rolled["text"])])
	if target.is_alive():
		var sv := target.creature.roll_save(e.dice, &"con", 15, [], [], "Constitution save vs Blood Amulet (%s)" % target.name())
		if not sv.success:
			target.creature.exhaustion += 1
			_log("condition", "%s's blood runs thin: a level of Exhaustion (Blood Amulet)" % target.name(), target, [sv.describe()])


## Boon Companion's Bands: one wearer's area spell spares the other wearer (an automatic success, no damage on a
## half), once a day between them.
func banded(ctx: Dictionary, t: Combatant) -> bool:
	if bool(ctx.get("item", false)):
		return false
	var c := ctx["c"] as Combatant
	if t == c or not c.allied_with(t) or not (ctx["s"] as Dictionary).has("area"):
		return false
	var mine := items().find_power(c, "boon_companions_bands", "spare")
	var theirs := items().find_power(t, "boon_companions_bands", "spare")
	if mine.is_empty() or theirs.is_empty() or not items().has_active(c, "boon_companions_bands") or not items().has_active(t, "boon_companions_bands"):
		return false
	if CombatItems.uses_spent(mine) >= CombatItems.use_count(mine) or CombatItems.uses_spent(theirs) >= CombatItems.use_count(theirs):
		return false
	CombatItems.spend_use(mine)
	CombatItems.spend_use(theirs)
	_log("info", "%s's band shields %s from the spell (Boon Companion's Bands)" % [c.name(), t.name()], t)
	return true


## After a spell attack hits: a Spell Duelist's Trophy casts Dispel Magic on the creature hit by a melee spell attack,
## once a day.
func after_spell_hit(ctx: Dictionary, t: Combatant, melee: bool, r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	if not melee or not t.is_alive() or bool(ctx.get("item", false)):
		return
	var p := items().find_power(c, "spell_duelists_trophy", "duel_dispel")
	if p.is_empty() or not items().has_active(c, "spell_duelists_trophy") or CombatItems.uses_spent(p) >= CombatItems.use_count(p) \
			or str(c.reaction_rules.get("spell_duelists_trophy", "auto")) == "never":
		return
	if not t.creature.effects.any(func(fx: Effect) -> bool: return fx.source_kind == &"spell") and t.creature.concentration == null:
		return
	CombatItems.spend_use(p)
	_log("spell", "%s's trophy unravels the magic on %s (Spell Duelist's Trophy)" % [c.name(), t.name()], c)
	var sub := {"c": c, "s": Compendium.shared().spell_data("dispel_magic"), "slot": 3, "nums": ctx["nums"]}
	enc().spells._dispel(sub, t, r)


## A Prismatic Rune readied: the spell's damage turns to the rune's element, for a charge.
func prismatic(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	if not c.has_meta("prismatic_rune") or not (ctx["s"] as Dictionary).has("damage"):
		return
	var iid := str(c.get_meta("prismatic_rune"))
	c.remove_meta("prismatic_rune")
	var ch := CombatItems.ch_of(c)
	var p := items().find_power(c, iid, "ready")
	if ch == null or p.is_empty() or ch.charges_left(iid) <= 0:
		return
	ch.spend_charges(iid, 1)
	var ty := str((p["entry"] as Dictionary).get("pick", ""))
	if ty != "":
		ctx["transmute_to"] = ty
		_log("info", "The prismatic rune turns %s's spell to %s" % [c.name(), ty], c)


## After a D20 Test: the Lucky Foot rerolls a natural 1 on a save or check (and is used up); the Ring of Dedicated
## Focus adds Hit Dice to a failed Concentration save; the Scholar's Anchoring Bangle floors a Study check at 10 and,
## once a day, saves a Concentration; the Thespian's Playbill adds Charisma to Study.
func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	var e := enc()
	var ch := CombatItems.ch_of(c)
	if ch == null or t.kind == D20Test.Kind.ATTACK_ROLL:
		return
	if "study" in keys:
		if items().has_active(c, "thespians_playbill"):
			t.add_bonus(maxi(1, c.creature.ability_mod(&"cha")), "Thespian's Playbill")
		var skill_key := keys.filter(func(k: String) -> bool: return k.begins_with("check:") and Abilities.SKILLS.has(StringName(k.substr(6))))
		var proficient := skill_key.any(func(k: String) -> bool: return ch.skill_rank(StringName(k.substr(6))) >= 1)
		if items().has_active(c, "scholars_anchoring_bangle") and proficient and t.kept < 10:
			t.floor_natural(10, "Scholar's Anchoring Bangle")
	if t.success or t.target <= 0:
		return
	if t.kept == 1 and not t.auto_failed:
		for it in items().carried(c):
			if str(it["id"]) == "lucky_foot":
				ch.remove_one("lucky_foot")
				var n := e.dice.d20("Lucky Foot")
				t.set_natural(n, "Lucky Foot")
				_log("info", "%s rubs the Lucky Foot and tries again: %d" % [c.name(), n], c)
				break
		if t.success:
			return
	if t.kind == D20Test.Kind.SAVING_THROW and "concentration" in keys:
		if items().has_active(c, "ring_of_dedicated_focus") and str(c.reaction_rules.get("ring_of_dedicated_focus", "auto")) != "never":
			for i in 2:
				if t.success:
					break
				var hd := _spend_hit_die(ch, "Ring of Dedicated Focus")
				if hd <= 0:
					break
				t.add_bonus(hd, "Ring of Dedicated Focus")
		var p := items().find_power(c, "scholars_anchoring_bangle", "anchor")
		if not t.success and not p.is_empty() and items().has_active(c, "scholars_anchoring_bangle") and e.spells.can_react(c) \
				and CombatItems.uses_spent(p) < CombatItems.use_count(p) and str(c.reaction_rules.get("scholars_anchoring_bangle", "auto")) != "never":
			CombatItems.spend_use(p)
			c.reaction_available = false
			t.add_bonus(maxi(0, t.target - t.total), "Scholar's Anchoring Bangle")
			_log("reaction", "%s's bangle anchors the spell in place" % c.name(), c)


## Rolls the biggest unspent Hit Die (spending it), or 0 when none are left.
func _spend_hit_die(ch: Character, label: String) -> int:
	var pool := ch.hit_dice()
	var best := 0
	for die: String in pool:
		var entry := pool[die] as Dictionary
		if int(entry["spent"]) < int(entry["total"]) and int(die) > best:
			best = int(die)
	if best == 0:
		return 0
	ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
	return enc().dice.roll_one(best, label)


## Thief's Thimble: it soaks up damage from traps its wearer springs (30 Hit Points, then it breaks).
static func thimble(cr: Creature, amount: int) -> int:
	var ch := cr as Character if cr is Character else null
	if ch == null or amount <= 0:
		return amount
	for entry in ch.inventory:
		if str(entry["id"]) != "thiefs_thimble" or not ch.item_active(entry):
			continue
		var left := int(entry.get("thimble_hp", 30))
		var soaked := mini(left, amount)
		entry["thimble_hp"] = left - soaked
		if left - soaked <= 0:
			ch.unequip_item("thiefs_thimble")
			ch.remove_one("thiefs_thimble")
		return amount - soaked
	return amount


## Field powers (outside a fight, from the inventory): choosing a pick after a Long Rest (Arcanist's Bestiary's skill,
## the Prismatic Rune's element), and recording a dream with the Dream Weaver.
static func field_use(ch: Character, p: Dictionary, dice: DiceRoller, opts: Dictionary) -> Dictionary:
	var power := p["power"] as Dictionary
	var entry := p["entry"] as Dictionary
	var label := str((p["data"] as Dictionary).get("name", ""))
	match str(power.get("custom", "")):
		"fr_set_pick":
			var pick := str(opts.get("choice", ""))
			if not pick in ((power.get("choice", {}) as Dictionary).get("from", []) as Array):
				return {"ok": false, "text": "Choose one", "lines": []}
			entry["pick"] = pick
			ch.items_changed()
			return {"ok": true, "text": "%s's %s: %s." % [ch.name.get_slice(" ", 0), label, pick.replace("_", " ").capitalize()], "lines": []}
		"fr_duplicate":
			var pick := str(opts.get("choice", ""))
			if not pick in duplicable(ch):
				return {"ok": false, "text": "Choose a nonmagical item you carry", "lines": []}
			ch.add_item(pick)
			return {"ok": true, "text": "The %s hums and sets a perfect copy of the %s beside the original." % [label, Compendium.shared().display_name("items", pick)], "lines": []}
		"fr_dream_record":
			var n := dice.d20("%s (%s)" % [label, ch.name])
			entry["dream"] = n
			return {"ok": true, "text": "%s studies the tapestry through the night and dreams of a %d." % [ch.name.get_slice(" ", 0), n], "lines": []}
	return {"ok": false, "text": "Not built yet", "lines": []}


# --- Artifacts (batch 9d) -----------------------------------------------------------------------------------------------

## Custom powers of the artifacts.
func use_artifact(c: Combatant, p: Dictionary, targets: Array) -> CombatResult:
	var power := p["power"] as Dictionary
	var e := enc()
	var label := str((p["data"] as Dictionary).get("name", ""))
	match str(power.get("custom", "")):
		"fr_crystal_rays":
			var rays: Array[Combatant] = []
			for x: Variant in targets:
				if x is Combatant and (x as Combatant).is_alive() and e.distance(c, x as Combatant) <= 60 and rays.size() < 6:
					rays.append(x as Combatant)
			if rays.is_empty():
				return CombatResult.fail("Choose up to six creatures within 60 ft")
			items()._pay(c, "magic")
			for t in rays:
				if not t.is_alive():
					continue
				if t == c or c.allied_with(t):
					var hr := e.heal_roll("2d6+2", t, label)
					var got := t.creature.heal(int(hr["total"]), label)
					_log("heal", "A ray of the %s mends %s: +%d Hit Points" % [label, t.name(), got], t, [str(hr["text"])])
					e.events.append({"type": "heal", "id": t.id, "amount": got})
				else:
					var sv := t.creature.roll_save(e.dice, &"dex", 18, [], [], "Dexterity save vs %s (%s)" % [label, t.name()])
					var rolled := e._roll_damage_dice("6d6+6", false, 0, label)
					var amount := int(rolled["total"]) / (2 if sv.success else 1)
					e.deal_damage(c, t, [{"amount": amount, "type": "radiant"}], false, label, [sv.describe(), str(rolled["text"])])
			return CombatResult.new()
		"fr_wrecker":
			return _wrecker_start(c, p)
		"fr_wrecker_stop":
			return _wrecker_stop(c)
		"fr_crystal_aura_end":
			var o := e.spells.zones.object_of(c.id, "%s__cold_aura" % MagicItems.recipe_owner(str(p["item_id"])))
			if o == null:
				return CombatResult.fail("The cold aura isn't up")
			items()._pay(c, "magic")
			o.ended = true
			e.spells.zones.prune()
			_log("info", "%s lets the crystal's cold aura fade" % c.name(), c)
			return CombatResult.new()
	return CombatResult.fail("Not built yet")


## Nonmagical items the Universal Pantograph could copy for `ch`.
static func duplicable(ch: Character) -> Array:
	var out: Array = []
	for entry in ch.inventory:
		var d := Compendium.shared().item_data(str(entry["id"]))
		if int(entry.get("qty", 0)) > 0 and not d.is_empty() and not MagicItems.is_magic(d) and not str(entry["id"]) in out:
			out.append(str(entry["id"]))
	return out


## Workshop Wrecker: for 1 minute a whirlwind of tools batters every other creature in the room as it starts and at
## the start of its user's turns. How hard depends on the room: the fight's map in feet (15/30/50/100 ft: Dex DC
## 18/17/15/14 against 6d6 + 5/4d6 + 4/2d6 + 2/1d6 + 1 Bludgeoning); a bigger room takes no real harm, and outdoors
## the whirlwind blows away.
const WRECKER_TIERS := [[15, 18, "6d6+5"], [30, 17, "4d6+4"], [50, 15, "2d6+2"], [100, 14, "1d6+1"]]


func _wrecker_start(c: Combatant, p: Dictionary) -> CombatResult:
	items()._pay(c, "magic")
	var fx := Effect.new(str((p["data"] as Dictionary).get("name", "")), &"item", str(p["item_id"]))
	fx.stack_key = "workshop_wrecker:%s" % p["item_id"]
	fx.data["wrecker"] = true
	fx.lasting({"kind": "minutes", "amount": 1})
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)
	CombatItems.spend_use(p)
	_log("info", "%s sets the Workshop Wrecker spinning" % c.name(), c)
	_wreck(c)
	return CombatResult.new()


func _wreck(c: Combatant) -> void:
	var e := enc()
	if e.outdoors:
		_log("info", "The whirlwind of tools tears off into the open sky", c)
		for fx: Effect in c.creature.effects.duplicate():
			if bool(fx.data.get("wrecker", false)):
				c.creature.remove_effect(fx)
		return
	var size := maxi(e.grid.width, e.grid.depth) * CombatGrid.FEET
	var tier: Array = []
	for t: Variant in WRECKER_TIERS:
		if size <= int((t as Array)[0]):
			tier = t as Array
			break
	if tier.is_empty():
		_log("info", "The room is too big for the Workshop Wrecker to do real harm", c)
		return
	var rolled := e._roll_damage_dice(str(tier[2]), false, 0, "Workshop Wrecker")
	for o in e.combatants:
		if o == c or not o.is_alive():
			continue
		var sv := o.creature.roll_save(e.dice, &"dex", int(tier[1]), [], [], "Dexterity save vs Workshop Wrecker (%s)" % o.name())
		if sv.success:
			_log("info", "%s ducks the flying tools" % o.name(), o, [sv.describe()])
			continue
		e.deal_damage(c, o, [{"amount": int(rolled["total"]), "type": "bludgeoning"}], false, "Workshop Wrecker", [sv.describe(), str(rolled["text"])])


func _wrecker_stop(c: Combatant) -> CombatResult:
	for fx: Effect in c.creature.effects.duplicate():
		if bool(fx.data.get("wrecker", false)):
			c.creature.remove_effect(fx)
			_log("info", "%s stops the Workshop Wrecker" % c.name(), c)
			return CombatResult.new()
	return CombatResult.fail("It isn't spinning")


## At the start of its user's turn the Workshop Wrecker strikes again.
func turn_start(c: Combatant) -> void:
	if c.creature.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("wrecker", false))):
		_wreck(c)
