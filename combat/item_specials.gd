class_name ItemSpecials
extends RefCounted
## Bespoke magic item rules (ADR 0011): powers a recipe can't say (`"custom": "<id>"` on a power) and the passive
## rules of particular items that need code at a moment of the fight (a Vorpal Sword's 20, a Ring of Evasion's
## Reaction, Boots of Speed making Opportunity Attacks harder, a Sword of Wounding's wounds). CombatItems calls in.

var _items: WeakRef


func _init(items: CombatItems) -> void:
	_items = weakref(items)


func items() -> CombatItems:
	return _items.get_ref() as CombatItems


func enc() -> Encounter:
	return items().enc()


func ch_of(c: Combatant) -> Character:
	return CombatItems.ch_of(c)


## Whether `c` has an active item with this id or template (attuned and worn or held as it must be).
func has(c: Combatant, item_or_template: String) -> bool:
	return items().has_active(c, item_or_template)


# --- Powers ----------------------------------------------------------------------------------------

## "" if a custom power can be used now, else why not.
func why(_c: Combatant, p: Dictionary) -> String:
	var power := p["power"] as Dictionary
	match str(power.get("custom", "")):
		_:
			return ""


## Carries out a custom power (CombatItems has already checked charges, uses and attunement; this pays the action).
func use(c: Combatant, p: Dictionary, targets: Array, point: Vector2, dir: Vector2, level: int, opts: Dictionary) -> CombatResult:
	var power := p["power"] as Dictionary
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else c
	var id := str(power.get("custom", ""))
	match id:
		"drink_grant", "drink_field_spell", "potion_of_vitality", "potion_of_longevity", "potion_of_poison", "philter_of_love":
			return _drink(c, p, t, id)
		"end_granted_effect":
			return _end_granted(c, p)
	return _use_more(c, p, targets, point, dir, level, opts)


## Custom powers added with later batches of items (see below).
func _use_more(_c: Combatant, p: Dictionary, _targets: Array, _point: Vector2, _dir: Vector2, _level: int, _opts: Dictionary) -> CombatResult:
	return CombatResult.fail("%s: not built yet" % (p["power"] as Dictionary).get("name", "That power"))


func _pay(c: Combatant, p: Dictionary) -> void:
	items()._pay(c, CombatItems.power_cost(p["power"] as Dictionary, {}))


## Drinking a potion with a bespoke effect: the drinker is `t` (yourself, or a creature within 5 ft you give it to).
func _drink(c: Combatant, p: Dictionary, t: Combatant, id: String) -> CombatResult:
	var e := enc()
	if t != c and e.distance(c, t) > 5:
		return CombatResult.fail("Must be within 5 ft")
	_pay(c, p)
	var data := p["data"] as Dictionary
	var power := p["power"] as Dictionary
	var params := power.get("params", {}) as Dictionary
	var label := str(data.get("name", ""))
	e.log.add("info", "%s %s %s" % [c.name(), "drinks" if t == c else "gives %s" % t.name(), label], c.id)
	match id:
		"drink_field_spell":
			# The effect of an exploring spell (Detect Thoughts, Clairvoyance, Etherealness): noted on the drinker so the
			# story can read it (`spell:<id>`); in a fight it changes nothing.
			var fx := Effect.new(label, &"item", str(p["item_id"]))
			fx.lasting({"kind": "minutes", "amount": int(params.get("minutes", 10))})
			fx.modifiers.append(Modifier.of("flag", {"value": "active_spell:%s" % params.get("spell", "")}, label, &"item"))
			t.creature.add_effect(fx)
		"potion_of_vitality":
			if t.creature.exhaustion > 0:
				e.log.add("heal", "%s shakes off %d levels of Exhaustion" % [t.name(), t.creature.exhaustion], t.id)
				t.creature.exhaustion = 0
			e.spells.cure(t, &"poisoned")
			var fv := Effect.new(label, &"item", str(p["item_id"]))
			fv.lasting({"kind": "hours", "amount": 24})
			fv.modifiers.append(Modifier.of("flag", {"value": "max_hit_dice"}, label, &"item"))
			t.creature.add_effect(fv)
		"potion_of_longevity":
			var years := int(e.dice.roll_expr("1d6+6", label)["total"])
			e.log.add("info", "%s grows %d years younger (Potion of Longevity)" % [t.name(), years], t.id)
		"potion_of_poison":
			var rolled := e._roll_damage_dice("4d6", false, 0, label)
			e.deal_damage(null, t, [{"amount": int(rolled["total"]), "type": "poison"}], false, label, [str(rolled["text"])])
			if t.is_alive():
				var sv := t.creature.roll_save(e.dice, &"con", 13, [], [], "Con save (Potion of Poison)")
				if not sv.success:
					var fp := Effect.new(label, &"item", str(p["item_id"]))
					fp.lasting({"kind": "hours", "amount": 1})
					fp.conditions.append(&"poisoned")
					t.creature.add_effect(fp)
					e.log.add("condition", "%s is Poisoned (Potion of Poison)" % t.name(), t.id, [sv.describe()])
		"philter_of_love":
			# The first creature the drinker sees: the nearest other creature it can see.
			var best: Combatant = null
			for o in e.living():
				if o != t and e.can_see(t, o) and (best == null or e.distance(t, o) < e.distance(t, best)):
					best = o
			if best != null:
				var fl := Effect.new(label, &"item", str(p["item_id"]))
				fl.caster_id = best.id
				fl.lasting({"kind": "hours", "amount": 1})
				fl.conditions.append(&"charmed")
				t.creature.add_effect(fl)
				e.log.add("condition", "%s is Charmed by %s (Philter of Love)" % [t.name(), best.name()], t.id)
	e.events.append({"type": "condition", "id": t.id})
	return CombatResult.new()


## Ends the effect a potion left on the drinker (Gaseous Form ended as a Bonus Action).
func _end_granted(c: Combatant, p: Dictionary) -> CombatResult:
	_pay(c, p)
	var src := str(p["item_id"])
	for fx: Effect in c.creature.effects.duplicate():
		if fx.source_id == src or fx.source_id == "%s__drink" % src:
			c.creature.remove_effect(fx)
	enc().log.add("info", "%s ends the potion's effect" % c.name(), c.id)
	enc().events.append({"type": "condition", "id": c.id})
	return CombatResult.new()


## A toggle power just switched on (extra setup some need).
func toggled_on(_c: Combatant, _p: Dictionary, _fx: Effect) -> void:
	pass


# --- Attacks -----------------------------------------------------------------------------------------

func hit_dice(_c: Combatant, _target: Combatant, _option: Dictionary, _st: Dictionary, _it: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


func after_hit(_c: Combatant, _target: Combatant, _option: Dictionary, _dr: DamageResult, _st: Dictionary, _r: CombatResult, _it: Dictionary) -> void:
	pass


func before_roll(_st: Dictionary, _out: Array) -> void:
	pass


func against_damage(_st: Dictionary, _total: Callable, _cut: Callable, _out: Array) -> void:
	pass


func adjust_incoming(_source: Combatant, _target: Combatant, _parts: Array, _label: String) -> void:
	pass


func on_damaged(_source: Combatant, _target: Combatant, _amount: int, _parts: Array) -> void:
	pass


func after_d20(_c: Combatant, _t: D20Test, _keys: Array[String]) -> void:
	pass


# --- Turns -----------------------------------------------------------------------------------------

func initiative_advantage(_c: Combatant) -> Array[String]:
	var out: Array[String] = []
	return out


func surprise_filter(ids: Array) -> Array:
	return ids


func turn_start(_c: Combatant) -> void:
	pass


func turn_end(_c: Combatant) -> void:
	pass
