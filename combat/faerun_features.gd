class_name FaerunFeatures
extends FaerunCommon
## Options from Heroes of Faerûn and Arcana Unleashed in a fight that need their own code (the rest are data recipes:
## FeatureRecipes, TriggeredFeatures). The origin feats: Arcane Artist, Arcane Overload, Arcane Undertaker, Portal
## Jumper, Cult of the Dragon Initiate, Emerald Enclave Fledgling, Harper Agent, Lords' Alliance Agent, Purple Dragon
## Rook, Spellfire Spark, Tyro of the Gauntlet and Zhentarim Ruffian; the general feats Abjuration, Divination,
## Evocation and Necromancy Adept, Cold Caster, Dragonscarred, Fairy Trickster, Harper Teamwork, Lordly Resolve,
## Order's Resilience, Purple Dragon Commandant, Spell Subterfuge, Spellfire Adept, Street Justice and Zhentarim Tactics.
## FeatureActions lists the actions here ("feat:fr:<id>"); the encounter, the attack pipeline, the spell caster and
## the damage path call the hooks below, each next to the matching RavenloftFeatures hook.
## A benefit with `"policy": "auto"` in its data acts on its own unless its owner turns it Off in the class tab
## (Reactions.configurable_policies).
##
## The code is split by kind, a helper each that extends FaerunCommon like this class: FaerunOriginFeats,
## FaerunGeneralFeats, FaerunSpells, FaerunSubclasses, FaerunWizardSchools, FaerunFamiliars and FaerunBoons
## (combat/faerun_*.gd). This class keeps the hotbar and forwards the hooks the rest of the game calls.

## The options' code by kind, a helper each (combat/faerun_*.gd); the functions at the end forward to them.
var origin: FaerunOriginFeats
var general: FaerunGeneralFeats
var spell_code: FaerunSpells
var subclasses: FaerunSubclasses
var schools: FaerunWizardSchools
var familiars: FaerunFamiliars
var boons: FaerunBoons

## Combatants whose side rolls Initiative with Advantage this fight (Family First), by side.
var _family_first: Dictionary = {}

## Every non-class-specific PHB language, Draconic first (Dragon's Tongue).
const DRAGON_TONGUE := ["draconic", "common_sign_language", "dwarvish", "elvish", "giant", "gnomish", "goblin",
	"halfling", "orc", "abyssal", "celestial", "deep_speech", "infernal", "primordial", "sylvan", "undercommon"]


func _init(encounter: Encounter) -> void:
	super(encounter)
	origin = FaerunOriginFeats.new(encounter)
	general = FaerunGeneralFeats.new(encounter)
	spell_code = FaerunSpells.new(encounter)
	subclasses = FaerunSubclasses.new(encounter)
	schools = FaerunWizardSchools.new(encounter)
	familiars = FaerunFamiliars.new(encounter)
	boons = FaerunBoons.new(encounter)


# --- Hotbar actions -----------------------------------------------------------------------------------------

## A character in a shape from Boon of Fluid Forms: ending it is a Magic action.
func shaped_list(c: Combatant, out: Array[Dictionary]) -> void:
	var e := enc()
	if e.shapes.is_shaped(c) and str((e.shapes.originals[c.id] as Dictionary).get("label", "")) == "Fluid Forms":
		out.append(_entry("fluid_forms_end", "Return to Your Form", "end Fluid Shape", "action",
			_first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else ""), "none",
			"Magic action: you return to your own form (Boon of Fluid Forms)."))


func list(c: Combatant, out: Array[Dictionary], aw: String, _bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var tw := e._turn_check(c)
	subclasses._subclass_list(c, ch, out, tw)
	boons._boon_list(c, ch, out, tw)
	if feat(c, "arcane_artist") and str(c.get_meta("arcane_artist_window", "")) == _turn_key():
		out.append(_entry("arcane_artist", "Arcane Artist: inspire", "Heroic Inspiration · 30 ft", "free",
			_first(tw, _res_why(c, "arcane_artist")), "ally",
			"You just cast an Illusion spell: give Heroic Inspiration to an ally within 30 ft who can see you. Once per Long Rest.", 30))
	if feat(c, "arcane_overload") and ch.resource_left("arcane_overload") > 0:
		var armed := str(c.get_meta("arcane_overload_armed", "")) == _turn_key()
		out.append(_entry("arcane_overload", "Arcane Overload" + (" (armed)" if armed else ""), "+%d to an Evocation spell" % ch.proficiency_bonus(),
			"free", _first(tw, "Already armed" if armed else ""), "none",
			"Arm it: the next Evocation spell you cast this turn adds your Proficiency Bonus to one of its damage rolls, spending the use. Once per Long Rest."))
	if feat(c, "portal_jumper"):
		var pw := _first(tw, _res_why(c, "portal_step"))
		if pw == "" and str(c.get_meta("portal_step_turn", "")) == _turn_key():
			pw = "Once per turn"
		if pw == "" and c.movement_left < 15:
			pw = "Needs 15 ft of movement"
		out.append(_entry("portal_step", "Portal Step", "teleport 15 ft", "free", pw, "point",
			"Spend 15 ft of movement to teleport to an empty space you can see within 15 ft. Once per turn; Proficiency Bonus times per Long Rest.", 15))
	if feat(c, "cult_of_the_dragon_initiate"):
		out.append(_entry("dragons_terror", "Dragon's Terror", "Wis DC %d · 30 ft" % origin._terror_dc(c), "action",
			_first(aw, "Only one Magic action this turn" if c.magic_action_used else ""), "enemy",
			"Magic action: a creature you can see within 30 ft makes a Wisdom save or is Frightened of you until the end of your next turn. Once it succeeds or the fear ends, it's immune for the rest of the fight.", 30))
	if feat(c, "dragonscarred") and str(c.get_meta("dragonscarred_turn", "")) == _turn_key():
		out.append(_entry("dragons_terror_bonus", "Dragon's Terror (Bonus Action)", "Wis DC %d · 30 ft" % origin._terror_dc(c), "bonus",
			_first(e._bonus_check(c), ""), "enemy",
			"Dragonscarred: you dealt damage this turn, so Dragon's Terror takes a Bonus Action.", 30))
	if feat(c, "spell_subterfuge") and str(c.get_meta("shrouding_window", "")) == _turn_key():
		out.append(_entry("shrouding_spells", "Shrouding Spells", "Dash and Hide", "bonus",
			_first(e._bonus_check(c), _res_why(c, "shrouding_spells")), "none",
			"Bonus Action after your spell: Dash and Hide together.", 0))
	if feat(c, "fairy_trickster") and ch.resource_left("flustering_strike") > 0:
		var fs_armed := str(c.get_meta("flustering_armed", "")) == _turn_key()
		out.append(_entry("flustering_strike", "Flustering Strike" + (" (armed)" if fs_armed else ""), "Wis DC %d" % origin._feat_dc(c, "fairy_trickster"),
			"free", _first(tw, "Already armed" if fs_armed else ""), "none",
			"Arm it: your next hit this turn forces a Wisdom save or the target has Disadvantage on saving throws until the end of your next turn."))
	if feat(c, "purple_dragon_commandant"):
		out.append(_entry("commandant_rally", "Rallying Command", "2d6 + %d Temporary HP" % origin._increased_mod(c, "purple_dragon_commandant"), "bonus",
			_first(e._bonus_check(c), _res_why(c, "commandant_rally")), "ally",
			"Bonus Action: an ally you can see within 30 ft gains 2d6 + %d Temporary Hit Points." % origin._increased_mod(c, "purple_dragon_commandant"), 30))
	if feat(c, "lordly_resolve"):
		var lr := _entry("lordly_resolve", "Lordly Resolve", "up to 3 allies · 1 min", "bonus",
			_first(e._bonus_check(c), _res_why(c, "lordly_resolve")), "multi",
			"Bonus Action: up to three creatures within 60 ft who can see you stand up (spending a Reaction) and can't be Charmed, Frightened or possessed for 1 minute.", 60)
		lr["count"] = 3
		out.append(lr)
	familiars._familiar_list(c, out)
	if feat(c, "elemental_familiar"):
		var element := familiars._feat_pick(c, "elemental_familiar", "elemental_familiar_resistance")
		out.append(_entry("elemental_familiar", "Elemental Familiar", "%s burst · Dex DC %d" % [element.capitalize(), familiars._familiar_dc(c)],
			"bonus", familiars._burst_why(c), "none",
			"Bonus Action: your familiar within 120 ft spends its Reaction. Each other creature within 5 ft of it makes a Dexterity save or takes 2d4 %s damage, and a Medium or smaller one falls Prone." % element.capitalize()))
	if feat(c, "emerald_enclave_fledgling") and str(c.get_meta("tag_team_window", "")) == _turn_key():
		out.append(_entry("tag_team", "Tag Team", "swap with an ally", "free", tw, "ally",
			"As part of your Help: trade places with a willing ally within 5 ft who isn't Incapacitated. Neither of you provokes Opportunity Attacks.", 5))


## A multi-target action hands its picks in `targets`; the hotbar's single pick comes as `t`.
var targets_in: Array = []
## The right-click choice an action was performed with (Boon of Fluid Forms' shape), or "".
var choice_in := ""


func _targets_of(t: Combatant) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for x: Variant in targets_in:
		if x is Combatant and not out.has(x as Combatant):
			out.append(x as Combatant)
	if out.is_empty() and t != null:
		out.append(t)
	return out


func perform(c: Combatant, id: String, t: Combatant, cell: Vector2i, _point: Vector2) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	match id:
		"arcane_artist":
			if str(c.get_meta("arcane_artist_window", "")) != _turn_key() or ch.resource_left("arcane_artist") <= 0:
				return CombatResult.fail("Cast an Illusion spell first")
			if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 30 or not e.can_see(t, c):
				return CombatResult.fail("Choose an ally within 30 ft who can see you")
			if _ch(t) == null or _ch(t).heroic_inspiration:
				return CombatResult.fail("%s already has Heroic Inspiration" % t.name())
			ch.spend_resource("arcane_artist")
			c.remove_meta("arcane_artist_window")
			_inspire(c, t, "Arcane Artist")
		"arcane_overload":
			if ch.resource_left("arcane_overload") <= 0:
				return CombatResult.fail("None left")
			c.set_meta("arcane_overload_armed", _turn_key())
			_log("info", "%s gathers power for an Evocation spell (Arcane Overload)" % c.name(), c)
		"portal_step":
			if ch.resource_left("portal_step") <= 0 or c.movement_left < 15 or str(c.get_meta("portal_step_turn", "")) == _turn_key():
				return CombatResult.fail("Not now")
			if cell.x < 0 or not e.grid.in_bounds(cell) or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose an empty space you can see within 15 ft")
			var r := e.feature_actions._teleport(c, cell, 15)
			if not r.ok:
				return r
			ch.spend_resource("portal_step")
			c.movement_left -= 15
			c.set_meta("portal_step_turn", _turn_key())
			return r
		"dragons_terror":
			return origin._dragons_terror(c, t)
		"dragons_terror_bonus":
			if str(c.get_meta("dragonscarred_turn", "")) != _turn_key():
				return CombatResult.fail("Deal damage this turn first")
			return origin._dragons_terror(c, t, true)
		"shrouding_spells":
			return general._shrouding_spells(c)
		"flustering_strike":
			if ch.resource_left("flustering_strike") <= 0:
				return CombatResult.fail("None left")
			c.set_meta("flustering_armed", _turn_key())
			_log("info", "%s readies a Flustering Strike" % c.name(), c)
		"commandant_rally":
			return general._commandant_rally(c, t)
		"lordly_resolve":
			return general._lordly_resolve(c, _targets_of(t))
		"tag_team":
			return origin._tag_team(c, t)
		"elemental_familiar":
			return familiars._elemental_burst(c)
		"radiance_arm":
			c.set_meta("radiance_armed", not bool(c.get_meta("radiance_armed", false)))
			_log("info", "%s %s Exquisite Radiance" % [c.name(), "readies" if bool(c.get_meta("radiance_armed", false)) else "holds back"], c)
		"fluid_forms":
			return boons._fluid_form(c, choice_in)
		"fluid_forms_end":
			var why := _first(e._action_check(c), "Only one Magic action this turn" if c.magic_action_used else "")
			if why != "":
				return CombatResult.fail(why)
			e.spend_action(c)
			c.magic_action_used = true
			e.shapes.revert(c, "it lets the shape go")
		"bright_sun":
			return boons._bright_sun(c)
		"familiar_away", "familiar_back", "familiar_dismiss":
			return familiars._familiar_command(c, id, cell)
		_:
			return subclasses._subclass_perform(c, id, t, cell)
	return CombatResult.new()


# --- Spells ------------------------------------------------------------------------------------------------

## Negative Energy Flood's Humanoid dead waiting to rise: {caster, cell, slot}.
var _rising: Array[Dictionary] = []


# --- Elminster's Effulgent Spheres ---------------------------------------------------------------------------

const ELEMENTS := ["acid", "cold", "fire", "lightning", "thunder"]


# --- Find Familiar's own commands (2024 PHB) ---------------------------------------------------------------------------

## Off the grid while the familiar waits in its pocket dimension.
const POCKET_CELL := Vector2i(-1000, -1000)


# --- Origin feats (FaerunOriginFeats) -------------------------------------------------------------

func effect_added(cr: Creature, fx: Effect) -> void:
	origin.effect_added(cr, fx)


func help_reach(c: Combatant, enemy: Combatant) -> int:
	return origin.help_reach(c, enemy)


func after_help(c: Combatant, enemy: Combatant) -> void:
	origin.after_help(c, enemy)


func after_stabilize(c: Combatant) -> void:
	origin.after_stabilize(c)


func after_cast(c: Combatant, s: Dictionary, slot: int, free: bool = false, ctx: Dictionary = {}) -> void:
	origin.after_cast(c, s, slot, free, ctx)


func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	return origin.spell_damage_bonus(ctx, bonus)


func after_hit(c: Combatant, target: Combatant, critical: bool, st: Dictionary = {}) -> void:
	origin.after_hit(c, target, critical, st)


func after_damage(source: Combatant, target: Combatant, amount: int, parts: Array = []) -> void:
	origin.after_damage(source, target, amount, parts)


func adjust_incoming(_source: Combatant, target: Combatant, parts: Array) -> void:
	origin.adjust_incoming(_source, target, parts)


func exploit_opening(c: Combatant, opts: Dictionary) -> bool:
	return origin.exploit_opening(c, opts)


func before_initiative() -> void:
	origin.before_initiative()


func initiative_advantage(c: Combatant) -> Array[String]:
	return origin.initiative_advantage(c)


func initiative_rolled() -> void:
	origin.initiative_rolled()


func blocks_forced_move(target: Combatant) -> bool:
	return origin.blocks_forced_move(target)


func after_ready(c: Combatant) -> void:
	origin.after_ready(c)


# --- General feats (FaerunGeneralFeats) -----------------------------------------------------------

func sneaky_casting(c: Combatant) -> bool:
	return general.sneaky_casting(c)


func turn_end(c: Combatant) -> void:
	general.turn_end(c)


func turn_start(c: Combatant) -> void:
	general.turn_start(c)


func after_save_ended(c: Combatant, fx: Effect) -> void:
	general.after_save_ended(c, fx)


func after_disengage(c: Combatant) -> void:
	general.after_disengage(c)


func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	return general.before_d20(c, kind, keys)


func hit_dice(c: Combatant, _target: Combatant, option: Dictionary = {}) -> Array[Dictionary]:
	return general.hit_dice(c, _target, option)


func attack_advantage(c: Combatant, target: Combatant) -> Array[String]:
	return general.attack_advantage(c, target)


func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	general.queue_damage_reactions(source, target)


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	return general.queued_ok(q, reactor)


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	return general.fire_queued(q, reactor, trigger)


func queued_text(kind: String) -> Array:
	return general.queued_text(kind)


# --- Spells (FaerunSpells) ------------------------------------------------------------------------

func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	return spell_code.resolve_spell(ctx, tgt, cells, r)


func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	spell_code.after_d20(c, t, keys)


func sustained_why(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	return spell_code.sustained_why(c, a, d, t, point)


func sustained(c: Combatant, a: Dictionary, d: Dictionary, ctx: Dictionary, targets: Array, point: Vector2, _dir: Vector2, r: CombatResult) -> CombatResult:
	return spell_code.sustained(c, a, d, ctx, targets, point, _dir, r)


func e_spheres_cast(ctx: Dictionary, _r: CombatResult) -> void:
	spell_code.e_spheres_cast(ctx, _r)


func against_damage(st: Dictionary, parts: Dictionary, total: Callable, cut: Callable, out: Array, responded: Array) -> void:
	spell_code.against_damage(st, parts, total, cut, out, responded)


func synchronous_damage(source: Combatant, target: Combatant, parts: Array, details: Array, resolved: Array) -> Array:
	return spell_code.synchronous_damage(source, target, parts, details, resolved)


func reflects_spell(c: Combatant, t: Combatant, ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> void:
	spell_code.reflects_spell(c, t, ctx, victims, r)


func transfixed_by(t: Combatant) -> Combatant:
	return spell_code.transfixed_by(t)


# --- Subclasses (FaerunSubclasses) ----------------------------------------------------------------

func genie_element(p: Combatant) -> String:
	return subclasses.genie_element(p)


func before_action(c: Combatant) -> void:
	subclasses.before_action(c)


func after_action(c: Combatant, action: Dictionary, targets: Array = []) -> void:
	subclasses.after_action(c, action, targets)


func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	return subclasses.spell_healing(ctx, t)


func zone_failed_save(o: FieldObject, t: Combatant) -> void:
	subclasses.zone_failed_save(o, t)


func before_resolve(ctx: Dictionary) -> void:
	subclasses.before_resolve(ctx)


# --- Wizard schools (FaerunWizardSchools) ---------------------------------------------------------

func after_hit_target(st: Dictionary, miss: Callable, out: Array) -> void:
	schools.after_hit_target(st, miss, out)


func after_summon(ctx: Dictionary, m: Creature) -> void:
	schools.after_summon(ctx, m)


func on_death(source: Combatant, dead: Combatant) -> void:
	schools.on_death(source, dead)


func shape_shifter_keeps_mind(c: Combatant) -> bool:
	return schools.shape_shifter_keeps_mind(c)


# --- Familiars (FaerunFamiliars) ------------------------------------------------------------------

func familiar_of(c: Combatant) -> Combatant:
	return familiars.familiar_of(c)


func healing_floor(t: Combatant) -> int:
	return familiars.healing_floor(t)


func pocket_familiar(c: Combatant) -> void:
	familiars.pocket_familiar(c)


# --- Epic boons (FaerunBoons) ---------------------------------------------------------------------

func maximized(c: Combatant, ty: String) -> bool:
	return boons.maximized(c, ty)


static func fluid_forms() -> Array[Dictionary]:
	return FaerunBoons.fluid_forms()


static func shape_temp_bonus(cr: Creature) -> int:
	return FaerunBoons.shape_temp_bonus(cr)


func waives_components(c: Combatant, spell_id: String) -> bool:
	return boons.waives_components(c, spell_id)
