class_name SpellCaster
extends RefCounted
## Spells in combat (plan §5.3, docs/contracts/spells.md), driven by each spell's data recipe: casting time and the
## action economy, spell slots (one slot-spell per turn, 2024), free uses from species and feats, Concentration,
## range and line of effect, areas on the grid, cast-time choices (a damage type, a condition, a form), spell
## attacks (with what happens on a hit or a miss), saving throws (damage rolled once for every target, half on a
## success, cover for Dexterity saves, pushes resolved farthest first), healing, Temporary Hit Points, and effects
## with their own durations ("until the end of your next turn"), triggers that end them (attacking, casting,
## taking damage), repeated saves and escape checks. Lingering areas and spell objects live in SpellZones;
## actions a spell keeps granting (Witch Bolt, Spiritual Weapon, Dragon's Breath...) are "sustained" actions here.
## A few spells keep handlers of their own (Magic Missile, Sleep, Command, Sanctuary, Misty Step, Mirror Image...).
##
## The SpellCaster holds the spells' state in a fight (sustained actions, summons). Its jobs live in helpers, a file
## each, that it makes and owns: SpellCasting, SpellOptions, SpellReactions, SpellTargeting, SpellAttacks, SpellDamage,
## SpellSaves, SpellEffects, SpellHandlers, SpellPlacement, SpellSustained, SpellSummons and SpellTurns
## (combat/spell_*.gd). The forwarding functions at the end are its interface for the Encounter, features and the HUD.

## Spells whose combat rules are in code here, beyond the data recipe.
const SPECIAL := ["heat_metal", "eldritch_blast", "sorcerous_burst", "magic_missile", "shield", "sleep", "command", "sanctuary", "spiritual_weapon", "toll_the_dead",
	"spare_the_dying", "chromatic_orb", "sacred_flame", "mage_armor", "aid", "misty_step", "mirror_image", "blink",
	"haste", "dispel_magic", "revivify", "arcane_vigor", "warding_bond", "counterspell", "hellish_rebuke",
	"true_strike", "shillelagh", "enlarge_reduce", "vampiric_touch", "lesser_restoration", "protection_from_poison",
	"expeditious_retreat", "summon_fey", "summon_undead", "goodberry", "jump", "alter_self", "beacon_of_hope",
	"resistance", "blade_ward", "protection_from_evil_and_good", "crown_of_madness", "bestow_curse", "fear",
	"calm_emotions", "fly", "levitate", "gaseous_form", "spider_climb", "animate_dead", "find_familiar", "etherealness", "plane_shift", "remove_curse",
	"booming_blade", "green_flame_blade"]
## Cantrips cast as a melee weapon attack against a creature within 5 ft (Tasha's Cauldron, added by the owner): the
## spell fails without one, so the cast is refused before anything is spent.
const BLADE_CANTRIPS := ["booming_blade", "green_flame_blade"]
## Command's words (2024): all five.
const COMMAND_WORDS := ["approach", "drop", "flee", "grovel", "halt"]
## Effect kinds the engine resolves in a fight (anything else is narrative or exploration).
const COMBAT_EFFECTS := ["modifiers", "condition", "temp_hp", "heal", "damage", "push", "pull", "end_condition",
	"summon", "light", "custom", "end_concentration", "temporary_exhaustion"]

var _enc: WeakRef
var zones: SpellZones
var specials: SpellSpecials
## Actions a spell keeps granting while it lasts: {id, spell_id, label, sub, owner_id, caster_id, cost, do, slot,
## target_id, conc: WeakRef, uses_left, opts}. `do`: attack, damage, area, move_object, dash, heal_one, maintain.
var sustained: Array[Dictionary] = []
## Creature ids summoned by a caster: caster id -> [ids].
var summoned: Dictionary = {}
## The spells' jobs, a helper each (made first in _init: the other helpers may call them while they're being made).
var casting: SpellCasting
var options: SpellOptions
var reaction_spells: SpellReactions
var targeting: SpellTargeting
var attacks: SpellAttacks
var damage: SpellDamage
var saves: SpellSaves
var effects: SpellEffects
var handlers: SpellHandlers
var placement: SpellPlacement
var sustain: SpellSustained
var summons: SpellSummons
var turn_hooks: SpellTurns


## Spells that call up a creature on a chosen square (combat/summon_blocks.gd).
const SUMMON_SPELLS := ["find_familiar", "summon_celestial", "summon_dragon", "summon_fiend", "summon_fey", "summon_undead", "find_steed", "summon_beast", "giant_insect", "summon_aberration",
	"summon_construct", "summon_elemental", "summon_dinosaur", "summon_plant"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)
	casting = SpellCasting.new(encounter)
	options = SpellOptions.new(encounter)
	reaction_spells = SpellReactions.new(encounter)
	targeting = SpellTargeting.new(encounter)
	attacks = SpellAttacks.new(encounter)
	damage = SpellDamage.new(encounter)
	saves = SpellSaves.new(encounter)
	effects = SpellEffects.new(encounter)
	handlers = SpellHandlers.new(encounter)
	placement = SpellPlacement.new(encounter)
	sustain = SpellSustained.new(encounter)
	summons = SpellSummons.new(encounter)
	turn_hooks = SpellTurns.new(encounter)
	zones = SpellZones.new(encounter)
	specials = SpellSpecials.new(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func _comp() -> Compendium:
	return Compendium.shared()


# --- The caster -----------------------------------------------------------------------------------

## The character whose spells `c` casts: itself, or its true self while Shapechange holds it in another form (the
## spell keeps the caster's mind and spellcasting; slots and Concentration stay the real self's).
func caster_char(c: Combatant) -> Character:
	if c.creature is Character:
		return c.creature as Character
	var e := enc()
	if e != null and e.shapes.keeps_spells(c):
		return e.shapes.original(c) as Character
	return null


# --- Casting options and Metamagic (SpellOptions reads these) -------------------------------------


## Casting options that ride on the Metamagic menu without being Metamagic: Psychic Spells (Great Old One: Psychic
## damage, no Verbal or Somatic components for Enchantment and Illusion) and Psionic Sorcery (Aberrant: Sorcery
## Points equal to the spell's level instead of a slot).
const CLASS_CAST_OPTIONS := ["psychic_spells", "psionic_sorcery"]
## Aberrant Sorcery's Psionic Spells.
const PSIONIC_SPELLS := ["arms_of_hadar", "calm_emotions", "detect_thoughts", "dissonant_whispers", "mind_sliver", "hunger_of_hadar",
	"sending", "evards_black_tentacles", "summon_aberration", "raris_telepathic_bond", "telekinesis"]


## The Metamagic choices' ids in the class data ("careful_spell"...), read as the option names below.
const METAMAGIC_IDS := ["careful_spell", "distant_spell", "empowered_spell", "extended_spell", "heightened_spell", "quickened_spell",
	"seeking_spell", "subtle_spell", "transmuted_spell", "twinned_spell"]
## Metamagic (Sorcerer): costs in Sorcery Points, one option per spell except Empowered and Seeking.
const METAMAGIC_COST := {"careful": 1, "distant": 1, "empowered": 1, "extended": 1, "heightened": 2, "quickened": 2,
	"seeking": 1, "subtle": 1, "transmuted": 1, "twinned": 1}


# --- Saving and loading a fight -------------------------------------------------------------------


## After a fight is loaded from a save: effects that do something when they end get their hook back (Haste's
## lethargy, Melf's Acid Arrow's later damage, Enlarge/Reduce, a summoned creature vanishing).
func rehook_effects() -> void:
	var e := enc()
	for c in e.combatants:
		for fx: Effect in c.creature.effects:
			e.triggered_features.rehook(c, fx)
			var oe := fx.data.get("on_end", {}) as Dictionary
			match str(oe.get("kind", "")):
				"lethargy":
					var tl := e.get_c(str(oe["target"]))
					if tl != null:
						effects._haste_lethargy(tl, fx)
				"dismiss":
					var sid := str(oe["target"])
					fx.on_end = func() -> void: _dismiss(sid)
				"unbanish":
					var ubid := str(oe["target"])
					var ub_round := int(oe.get("round", 0))
					fx.on_end = func() -> void: specials.unbanish(ubid, ub_round)
				"burst_bead":
					var bead := str(oe.get("object", ""))
					fx.on_end = func() -> void: specials.high.burst_bead(bead)
				"fall":
					var fid := str(oe["target"])
					var ft := int(oe.get("feet", 100))
					fx.on_end = func() -> void: specials.high.fall(fid, ft)
				"undominate":
					var udid := str(oe["target"])
					fx.on_end = func() -> void: specials.undominate(udid)
				"revert_shape":
					var shid := str(oe["target"])
					fx.on_end = func() -> void: _revert_shape(shid, str(oe.get("why", "the spell ended")))
				"resize":
					var tr := e.get_c(str(oe["target"]))
					var old := StringName(str(oe["size"]))
					if tr != null:
						var weak: WeakRef = weakref(tr)
						fx.on_end = func() -> void:
							var tt := weak.get_ref() as Combatant
							if tt != null:
								tt.creature.size = old
								tt.size_cells = CombatGrid.size_cells_for(old)
				"delayed_damage":
					var td := e.get_c(str(oe["target"]))
					var caster := e.get_c(str(oe["caster"]))
					if td != null and caster != null:
						var ctx := {"c": caster, "s": _comp().spell_data(str(oe["spell"])), "slot": int(oe["slot"]), "nums": {}, "opts": {}}
						var part := oe["part"] as Dictionary
						var weak_t: WeakRef = weakref(td)
						fx.on_end = func() -> void:
							var tt2 := weak_t.get_ref() as Combatant
							if tt2 == null or not tt2.is_alive():
								return
							var rolled := roll_damage_parts(ctx, [part], false, tt2)
							e.deal_damage(e.get_c(caster.id), tt2, [{"amount": int(rolled["total"]), "type": str(rolled["type"]), "spell": true}], false, str(ctx["s"].get("name", "")), [str(rolled["text"])])


## The spell state a save keeps: lingering areas and objects, sustained actions, summons.
func to_dict() -> Dictionary:
	var objs: Array = []
	for o in zones.live():
		var conc := o.concentration
		objs.append({"kind": int(o.kind), "spell": o.spell_id, "name": o.name, "caster": o.caster_id, "cell": [o.cell.x, o.cell.y],
			"cells": o.cells.map(func(x: Vector2i) -> Array: return [x.x, x.y]), "follows": o.follows_caster, "slot": o.slot,
			"dc": o.save_dc, "rules": o.rules.duplicate(true), "spared": o.spared.duplicate(), "rounds": o.rounds_left,
			"conc": conc.source_id if conc != null else ""})
	var sus: Array = []
	for a in sustained:
		var d := a.duplicate(true)
		var cc := (a["conc"] as WeakRef).get_ref() as Concentration if a["conc"] != null else null
		d["conc"] = cc.source_id if cc != null else ""
		sus.append(d)
	return {"objects": objs, "sustained": sus, "summoned": summoned.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	var e := enc()
	for od: Variant in d.get("objects", []):
		var x := od as Dictionary
		var o := FieldObject.new(int(x["kind"]) as FieldObject.Kind, str(x["spell"]), str(x["name"]))
		o.caster_id = str(x["caster"])
		o.cell = Vector2i(int((x["cell"] as Array)[0]), int((x["cell"] as Array)[1]))
		for cl: Variant in x.get("cells", []):
			o.cells.append(Vector2i(int((cl as Array)[0]), int((cl as Array)[1])))
		o.follows_caster = bool(x.get("follows", false))
		o.slot = int(x.get("slot", 0))
		o.save_dc = int(x.get("dc", 10))
		o.rules = (x.get("rules", {}) as Dictionary).duplicate(true)
		for sp: Variant in x.get("spared", []):
			o.spared.append(str(sp))
		o.rounds_left = int(x.get("rounds", -1))
		var caster := e.get_c(o.caster_id)
		if str(x.get("conc", "")) != "" and caster != null and caster.creature.concentration != null:
			o.keep_with(caster.creature.concentration)
		zones.objects.append(o)
	for ad: Variant in d.get("sustained", []):
		var a := (ad as Dictionary).duplicate(true)
		var caster2 := e.get_c(str(a["caster_id"]))
		a["conc"] = weakref(caster2.creature.concentration) if str(a.get("conc", "")) != "" and caster2 != null and caster2.creature.concentration != null else null
		sustained.append(a)
	summoned = (d.get("summoned", {}) as Dictionary).duplicate(true)
	rehook_effects()
	zones.refresh_auras()


## JSON-safe casting numbers: a sustained spell retains its original DC/attack through a save and reload.
static func _pack_numbers(nums: Dictionary) -> Dictionary:
	var out := nums.duplicate()
	for key: String in ["attack", "dc"]:
		var b := nums.get(key) as Breakdown
		out[key] = {"value": b.total(), "source": b.describe()} if b != null else {"value": 0, "source": "At casting"}
	return out

static func _unpack_numbers(nums: Dictionary) -> Dictionary:
	var out := nums.duplicate()
	for key: String in ["attack", "dc"]:
		var b := nums[key] as Dictionary
		out[key] = Breakdown.new(key.capitalize()).add(str(b["source"]), int(b["value"]))
	return out


# --- Casting (SpellCasting) -----------------------------------------------------------------------

func cast(c: Combatant, spell_id: String, slot: int, targets: Array = [], point: Vector2 = Vector2.INF, direction: Vector2 = Vector2.ZERO, opts: Dictionary = {}) -> CombatResult:
	return casting.cast(c, spell_id, slot, targets, point, direction, opts)


func _after_cast_features(ctx: Dictionary, free: bool) -> void:
	casting._after_cast_features(ctx, free)


func cast_with_numbers(c: Combatant, spell_id: String, level: int, targets: Array, point: Vector2, nums: Dictionary, opts: Dictionary = {}) -> CombatResult:
	return casting.cast_with_numbers(c, spell_id, level, targets, point, nums, opts)


func cast_free(c: Combatant, spell_id: String, targets: Array, point: Vector2, opts: Dictionary = {}) -> CombatResult:
	return casting.cast_free(c, spell_id, targets, point, opts)


func _finish_concentration(ctx: Dictionary) -> void:
	casting._finish_concentration(ctx)


func _resolve(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult, pausable: bool = false) -> CombatResult:
	return casting._resolve(ctx, tgt, cells, r, pausable)


func _generic(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult, pausable: bool = false) -> CombatResult:
	return casting._generic(ctx, tgt, cells, r, pausable)


# --- What can be cast (SpellOptions) --------------------------------------------------------------

func castable(c: Combatant) -> Array[Dictionary]:
	return options.castable(c)


func _why_not(c: Combatant, s: Dictionary, entry: Dictionary) -> String:
	return options._why_not(c, s, entry)


func economy_block(c: Combatant, unit: String) -> String:
	return options.economy_block(c, unit)


func has_combat_rules(s: Dictionary) -> bool:
	return options.has_combat_rules(s)


func casting_gate(c: Combatant) -> bool:
	return options.casting_gate(c)


func precast(c: Combatant, spell_id: String, ritual: bool = false) -> bool:
	return options.precast(c, spell_id, ritual)


func _entry(c: Combatant, spell_id: String) -> Dictionary:
	return options._entry(c, spell_id)


func numbers(c: Combatant, entry: Dictionary) -> Dictionary:
	return options.numbers(c, entry)


func class_cast_options(c: Combatant, s: Dictionary) -> Array[String]:
	return options.class_cast_options(c, s)


func _metamagic_check(c: Combatant, s: Dictionary, meta: Array) -> String:
	return options._metamagic_check(c, s, meta)


static func metamagic_known(ch: Character) -> Array[String]:
	return SpellOptions.metamagic_known(ch)


func resource_cast_entry(c: Combatant, spell: Dictionary, feature_id: String) -> Dictionary:
	return options.resource_cast_entry(c, spell, feature_id)


# --- Reaction spells (SpellReactions) -------------------------------------------------------------

func begin_reaction_spell(c: Combatant, spell_id: String) -> bool:
	return reaction_spells.begin_reaction_spell(c, spell_id)


func after_failed_d20(roller: Combatant, test: D20Test) -> void:
	reaction_spells.after_failed_d20(roller, test)


func d20_offers(roller: Combatant, test: D20Test, out: Array) -> void:
	reaction_spells.d20_offers(roller, test, out)


func answer_incoming_roll(c: Combatant, test: D20Test, spell_id: String) -> bool:
	return reaction_spells.answer_incoming_roll(c, test, spell_id)


func incoming_roll_responses(c: Combatant) -> Array[String]:
	return reaction_spells.incoming_roll_responses(c)


func can_cast_reaction(c: Combatant, spell_id: String) -> bool:
	return reaction_spells.can_cast_reaction(c, spell_id)


func can_react(c: Combatant) -> bool:
	return reaction_spells.can_react(c)


func _lowest_slot(ch: Character, from_level: int) -> int:
	return reaction_spells._lowest_slot(ch, from_level)


func cast_shield(c: Combatant) -> bool:
	return reaction_spells.cast_shield(c)


func cast_reaction_spell(c: Combatant, spell_id: String, trigger: Combatant) -> CombatResult:
	return reaction_spells.cast_reaction_spell(c, spell_id, trigger)


func release_readied(c: Combatant, held: Dictionary, target: Combatant) -> CombatResult:
	return reaction_spells.release_readied(c, held, target)


func cast_reactive_spell(c: Combatant, spell_id: String, target: Combatant) -> CombatResult:
	return reaction_spells.cast_reactive_spell(c, spell_id, target)


# --- Range, targets and areas (SpellTargeting) ----------------------------------------------------

func range_ft(s: Dictionary, caster: Combatant = null) -> int:
	return targeting.range_ft(s, caster)


func target_count(s: Dictionary, slot: int) -> int:
	return targeting.target_count(s, slot)


func area_for(c: Combatant, s: Dictionary, point: Vector2, direction: Vector2, slot: int = 0) -> Array[Vector2i]:
	return targeting.area_for(c, s, point, direction, slot)


func creatures_in(cells: Array[Vector2i]) -> Array[Combatant]:
	return targeting.creatures_in(cells)


func _area_victims(c: Combatant, s: Dictionary, cells: Array[Vector2i], choice: String = "") -> Array[Combatant]:
	return targeting._area_victims(c, s, cells, choice)


static func choice_of(s: Dictionary, opts: Dictionary) -> String:
	return SpellTargeting.choice_of(s, opts)


func _check_targets(c: Combatant, s: Dictionary, slot: int, targets: Array, point: Vector2, opts: Dictionary) -> Dictionary:
	return targeting._check_targets(c, s, slot, targets, point, opts)


# --- Spell attacks (SpellAttacks) -----------------------------------------------------------------

func attack_shots(ctx: Dictionary, tgt: Array[Combatant]) -> Array[Combatant]:
	return attacks.attack_shots(ctx, tgt)


func _before_attack_rolls(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult, go: Callable) -> CombatResult:
	return attacks._before_attack_rolls(ctx, tgt, r, go)


func spell_attack(ctx: Dictionary, t: Combatant, r: CombatResult) -> D20Test:
	return attacks.spell_attack(ctx, t, r)


func _secondary(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	attacks._secondary(ctx, t, r)


# --- Damage and healing (SpellDamage) -------------------------------------------------------------

func _damage_type(ctx: Dictionary, part: Dictionary = {}) -> String:
	return damage._damage_type(ctx, part)


func roll_damage_parts(ctx: Dictionary, parts: Array, critical: bool, _t: Combatant, min_die: int = 0) -> Dictionary:
	return damage.roll_damage_parts(ctx, parts, critical, _t, min_die)


func extra_damage_type(c: Combatant, t: Combatant, m: Modifier, fallback: String) -> String:
	return damage.extra_damage_type(c, t, m, fallback)


func _damage_type_safe(ctx: Dictionary) -> String:
	return damage._damage_type_safe(ctx)


func deal_spell_damage(ctx: Dictionary, target: Combatant, parts: Array, critical: bool, label: String, details: Array = [], log_it: bool = true) -> DamageResult:
	return damage.deal_spell_damage(ctx, target, parts, critical, label, details, log_it)


# --- Saving throws (SpellSaves) -------------------------------------------------------------------

func _save_spell(ctx: Dictionary, victims: Array[Combatant], r: CombatResult, pausable: bool = false) -> CombatResult:
	return saves._save_spell(ctx, victims, r, pausable)


static func _conditions_in(entries: Array, choice: String) -> Array[String]:
	return SpellSaves._conditions_in(entries, choice)


func end_of_turn_saves(c: Combatant) -> void:
	saves.end_of_turn_saves(c)


func _repeat_save(c: Combatant, fx: Effect, adv: Array[String]) -> void:
	saves._repeat_save(c, fx, adv)


static func spell_save_keys(caster_id: String) -> Array[String]:
	return SpellSaves.spell_save_keys(caster_id)


# --- Effects from data (SpellEffects) -------------------------------------------------------------

static func default_on(s: Dictionary) -> String:
	return SpellEffects.default_on(s)


func apply_effect_entries(ctx: Dictionary, t: Combatant, entries: Array, when: String, r: CombatResult) -> void:
	effects.apply_effect_entries(ctx, t, entries, when, r)


func _resize(t: Combatant, step: int, fxo: Effect) -> void:
	effects._resize(t, step, fxo)


func _set_duration(fxo: Effect, ctx: Dictionary, t: Combatant, until: String) -> void:
	effects._set_duration(fxo, ctx, t, until)


func mark_badge(c: Combatant, t: Combatant, spell_id: String, spell_name: String, conc: Concentration) -> void:
	effects.mark_badge(c, t, spell_id, spell_name, conc)


func cure(t: Combatant, cond: StringName) -> void:
	effects.cure(t, cond)


func _light(ctx: Dictionary, t: Combatant, params: Dictionary) -> void:
	effects._light(ctx, t, params)


# --- Spells with handlers of their own (SpellHandlers) --------------------------------------------

func _command(ctx: Dictionary, t: Combatant, word: String, r: CombatResult) -> void:
	handlers._command(ctx, t, word, r)


func end_sanctuary(t: Combatant, why: String) -> void:
	handlers.end_sanctuary(t, why)


func sanctuary_blocks(attacker: Combatant, target: Combatant) -> String:
	return handlers.sanctuary_blocks(attacker, target)


func _teleport(c: Combatant, cell: Vector2i, r: CombatResult) -> void:
	handlers._teleport(c, cell, r)


func _dispel(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	handlers._dispel(ctx, t, r)


func blade_option(c: Combatant, t: Combatant) -> Dictionary:
	return handlers.blade_option(c, t)


func booming_moved(c: Combatant) -> void:
	handlers.booming_moved(c)


# --- Zones, walls and spell objects (SpellPlacement) ----------------------------------------------

func context_for_object(o: FieldObject) -> Dictionary:
	return placement.context_for_object(o)


func _place_zone(ctx: Dictionary, cells: Array[Vector2i], r: CombatResult) -> void:
	placement._place_zone(ctx, cells, r)


func multi_area(c: Combatant, spell_id: String, points: Array) -> Array[Vector2i]:
	return placement.multi_area(c, spell_id, points)


func _ring(center: Vector2, radius_ft: int) -> Array[Vector2i]:
	return placement._ring(center, radius_ft)


func weapon_of(c: Combatant) -> FieldObject:
	return placement.weapon_of(c)


func has_spiritual_weapon(c: Combatant) -> bool:
	return placement.has_spiritual_weapon(c)


func _beside(c: Combatant, t: Combatant) -> Vector2i:
	return placement._beside(c, t)


func spiritual_weapon_attack(c: Combatant, target: Combatant, cell: Vector2i) -> CombatResult:
	return placement.spiritual_weapon_attack(c, target, cell)


# --- Sustained actions (SpellSustained) -----------------------------------------------------------

func _entry_any(c: Combatant, spell_id: String) -> Dictionary:
	return sustain._entry_any(c, spell_id)


func _grant_sustained(ctx: Dictionary, tgt: Array[Combatant]) -> void:
	sustain._grant_sustained(ctx, tgt)


func _prune_sustained() -> void:
	sustain._prune_sustained()


func sustained_for(c: Combatant, spell_id: String = "") -> Dictionary:
	return sustain.sustained_for(c, spell_id)


func sustained_actions(c: Combatant) -> Array[Dictionary]:
	return sustain.sustained_actions(c)


func use_sustained(c: Combatant, action_id: String, targets: Array = [], point: Vector2 = Vector2.INF, direction: Vector2 = Vector2.ZERO) -> CombatResult:
	return sustain.use_sustained(c, action_id, targets, point, direction)


func _end_spell_of(c: Combatant, spell_id: String, why: String) -> void:
	sustain._end_spell_of(c, spell_id, why)


# --- Summons (SpellSummons) -----------------------------------------------------------------------

func can_splinter(c: Combatant, s: Dictionary) -> bool:
	return summons.can_splinter(c, s)


func _summon(ctx: Dictionary, cell: Vector2i, r: CombatResult) -> void:
	summons._summon(ctx, cell, r)


func _revert_shape(creature_id: String, why: String) -> void:
	summons._revert_shape(creature_id, why)


func _dismiss(creature_id: String) -> void:
	summons._dismiss(creature_id)


func _free_cell_near(cell: Vector2i, size: int = 1) -> Vector2i:
	return summons._free_cell_near(cell, size)


func _room_for(cell: Vector2i, size: int) -> bool:
	return summons._room_for(cell, size)


# --- Turn and damage hooks (SpellTurns) -----------------------------------------------------------

func turn_start(c: Combatant) -> void:
	turn_hooks.turn_start(c)


func _turn_start_effects(c: Combatant) -> void:
	turn_hooks._turn_start_effects(c)


func turn_end(c: Combatant) -> CombatResult:
	return turn_hooks.turn_end(c)


func on_damaged(source: Combatant, target: Combatant, amount: int, parts: Array) -> void:
	turn_hooks.on_damaged(source, target, amount, parts)


func trigger_ends(c: Combatant, what: String) -> void:
	turn_hooks.trigger_ends(c, what)


func on_enter_cell(c: Combatant, from: Vector2i = Vector2i(-9999, -9999)) -> void:
	turn_hooks.on_enter_cell(c, from)


func can_see_or_hear(observer: Combatant, source: Combatant) -> bool:
	return turn_hooks.can_see_or_hear(observer, source)


func check_tethers() -> void:
	turn_hooks.check_tethers()
