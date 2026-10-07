class_name FaerunFeatures
extends RefCounted
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

var _enc: WeakRef

## Combatants whose side rolls Initiative with Advantage this fight (Family First), by side.
var _family_first: Dictionary = {}

## Every non-class-specific PHB language, Draconic first (Dragon's Tongue).
const DRAGON_TONGUE := ["draconic", "common_sign_language", "dwarvish", "elvish", "giant", "gnomish", "goblin",
	"halfling", "orc", "abyssal", "celestial", "deep_speech", "infernal", "primordial", "sylvan", "undercommon"]


func _init(encounter: Encounter) -> void:
	_enc = weakref(encounter)


func enc() -> Encounter:
	return _enc.get_ref() as Encounter


func feat(c: Combatant, feat_id: String) -> bool:
	return c != null and enc().features.has_feat(c, feat_id)


static func _ch(c: Combatant) -> Character:
	return c.creature as Character if c != null and c.creature is Character else null


func _entry(id: String, label: String, sub: String, cost: String, why: String, targeting: String, help: String, rng: int = 0) -> Dictionary:
	return {"id": "feat:fr:" + id, "label": label, "sub": sub, "cost": cost, "why": why, "targeting": targeting, "help": help, "range": rng}


static func _first(a: String, b: String) -> String:
	return a if a != "" else b


func _res_why(c: Combatant, res: String) -> String:
	var ch := _ch(c)
	return "" if ch != null and ch.resource_left(res) > 0 else "None left"


## A benefit marked `"policy"`: on unless its owner turned it Off.
static func allowed(c: Combatant, id: String) -> bool:
	return str(c.reaction_rules.get(id, "auto")) != "never"


func _turn_key() -> String:
	return "%d:%d" % [enc().round_no, enc().turn_index]


## Once per turn (anyone's turn): true the first time, false after.
func _once_per_turn(c: Combatant, key: String) -> bool:
	if str(c.get_meta(key, "")) == _turn_key():
		return false
	c.set_meta(key, _turn_key())
	return true


func _log(kind: String, text: String, who: Combatant, details: Array = []) -> void:
	enc().log.add(kind, text, who.id if who != null else "", details)


## Heroic Inspiration for `t` from `giver`'s feature; false when it already has some (nothing to give).
func _inspire(giver: Combatant, t: Combatant, label: String) -> bool:
	var ch := _ch(t)
	if ch == null or ch.heroic_inspiration:
		return false
	ch.heroic_inspiration = true
	_log("info", "%s gains Heroic Inspiration (%s, from %s)" % [t.name(), label, giver.name()], t)
	return true


## Allies of `c` (not `c`) within `feet` that perceive it and lack Heroic Inspiration, nearest first.
func _uninspired_allies(c: Combatant, feet: int, perceive: Callable) -> Array[Combatant]:
	var e := enc()
	var out: Array[Combatant] = []
	for a in e.allies_of(c):
		var ch := _ch(a)
		if a == c or ch == null or ch.heroic_inspiration or not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > feet:
			continue
		if perceive.call(a):
			out.append(a)
	out.sort_custom(func(x: Combatant, y: Combatant) -> bool: return e.distance(c, x) < e.distance(c, y))
	return out


# --- Hotbar actions -----------------------------------------------------------------------------------------

func list(c: Combatant, out: Array[Dictionary], aw: String, _bw: String) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var e := enc()
	var tw := e._turn_check(c)
	_subclass_list(c, ch, out, tw)
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
		out.append(_entry("dragons_terror", "Dragon's Terror", "Wis DC %d · 30 ft" % _terror_dc(c), "action",
			_first(aw, "Only one Magic action this turn" if c.magic_action_used else ""), "enemy",
			"Magic action: a creature you can see within 30 ft makes a Wisdom save or is Frightened of you until the end of your next turn. Once it succeeds or the fear ends, it's immune for the rest of the fight.", 30))
	if feat(c, "dragonscarred") and str(c.get_meta("dragonscarred_turn", "")) == _turn_key():
		out.append(_entry("dragons_terror_bonus", "Dragon's Terror (Bonus Action)", "Wis DC %d · 30 ft" % _terror_dc(c), "bonus",
			_first(e._bonus_check(c), ""), "enemy",
			"Dragonscarred: you dealt damage this turn, so Dragon's Terror takes a Bonus Action.", 30))
	if feat(c, "spell_subterfuge") and str(c.get_meta("shrouding_window", "")) == _turn_key():
		out.append(_entry("shrouding_spells", "Shrouding Spells", "Dash and Hide", "bonus",
			_first(e._bonus_check(c), _res_why(c, "shrouding_spells")), "none",
			"Bonus Action after your spell: Dash and Hide together.", 0))
	if feat(c, "fairy_trickster") and ch.resource_left("flustering_strike") > 0:
		var fs_armed := str(c.get_meta("flustering_armed", "")) == _turn_key()
		out.append(_entry("flustering_strike", "Flustering Strike" + (" (armed)" if fs_armed else ""), "Wis DC %d" % _feat_dc(c, "fairy_trickster"),
			"free", _first(tw, "Already armed" if fs_armed else ""), "none",
			"Arm it: your next hit this turn forces a Wisdom save or the target has Disadvantage on saving throws until the end of your next turn."))
	if feat(c, "purple_dragon_commandant"):
		out.append(_entry("commandant_rally", "Rallying Command", "2d6 + %d Temporary HP" % _increased_mod(c, "purple_dragon_commandant"), "bonus",
			_first(e._bonus_check(c), _res_why(c, "commandant_rally")), "ally",
			"Bonus Action: an ally you can see within 30 ft gains 2d6 + %d Temporary Hit Points." % _increased_mod(c, "purple_dragon_commandant"), 30))
	if feat(c, "lordly_resolve"):
		var lr := _entry("lordly_resolve", "Lordly Resolve", "up to 3 allies · 1 min", "bonus",
			_first(e._bonus_check(c), _res_why(c, "lordly_resolve")), "multi",
			"Bonus Action: up to three creatures within 60 ft who can see you stand up (spending a Reaction) and can't be Charmed, Frightened or possessed for 1 minute.", 60)
		lr["count"] = 3
		out.append(lr)
	if feat(c, "emerald_enclave_fledgling") and str(c.get_meta("tag_team_window", "")) == _turn_key():
		out.append(_entry("tag_team", "Tag Team", "swap with an ally", "free", tw, "ally",
			"As part of your Help: trade places with a willing ally within 5 ft who isn't Incapacitated. Neither of you provokes Opportunity Attacks.", 5))


## A multi-target action hands its picks in `targets`; the hotbar's single pick comes as `t`.
var targets_in: Array = []


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
			return _dragons_terror(c, t)
		"dragons_terror_bonus":
			if str(c.get_meta("dragonscarred_turn", "")) != _turn_key():
				return CombatResult.fail("Deal damage this turn first")
			return _dragons_terror(c, t, true)
		"shrouding_spells":
			return _shrouding_spells(c)
		"flustering_strike":
			if ch.resource_left("flustering_strike") <= 0:
				return CombatResult.fail("None left")
			c.set_meta("flustering_armed", _turn_key())
			_log("info", "%s readies a Flustering Strike" % c.name(), c)
		"commandant_rally":
			return _commandant_rally(c, t)
		"lordly_resolve":
			return _lordly_resolve(c, _targets_of(t))
		"tag_team":
			return _tag_team(c, t)
		_:
			return _subclass_perform(c, id, t, cell)
	return CombatResult.new()


# --- Cult of the Dragon Initiate --------------------------------------------------------------------------

func _terror_dc(c: Combatant) -> int:
	return 8 + c.creature.ability_mod(&"wis") + c.creature.proficiency_bonus()


func _dragons_terror(c: Combatant, t: Combatant, bonus: bool = false) -> CombatResult:
	var e := enc()
	if t == null or t == c or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	if c.magic_action_used and not bonus:
		return CombatResult.fail("Only one Magic action this turn")
	if c.id in (t.get_meta("dragons_terror_immune", []) as Array):
		return CombatResult.fail("%s has already shaken off your Dragon's Terror" % t.name())
	var why := e._bonus_check(c) if bonus else e._action_check(c)
	if why != "":
		return CombatResult.fail(why)
	if bonus:
		c.bonus_available = false
		c.remove_meta("dragonscarred_turn")
	else:
		e.spend_action(c)
		c.magic_action_used = true
	var sv := t.creature.roll_save(e.dice, &"wis", _terror_dc(c), [], [], "Wisdom save vs Dragon's Terror (%s)" % t.name(),
		["save_vs:frightened", "save_vs:magic"])
	if sv.success:
		_log("info", "%s stands firm against %s's Dragon's Terror" % [t.name(), c.name()], t, [sv.describe()])
		_terror_immune(c, t)
		return CombatResult.new()
	var fx := Effect.new("Dragon's Terror", &"feature", "dragons_terror").with_condition(&"frightened")
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	# Bound by id, not by a closure over the combatants, so a fear still running at the end of a fight frees cleanly.
	fx.on_end = _terror_ended.bind(c.id, t.id)
	if t.creature.add_effect(fx):
		_log("condition", "%s is Frightened of %s (Dragon's Terror)" % [t.name(), c.name()], t, [sv.describe()])
		e.events.append({"type": "condition", "id": t.id})
	else:
		_terror_immune(c, t)
	return CombatResult.new()


func _terror_ended(caster_id: String, target_id: String) -> void:
	var e := enc()
	if e == null:
		return
	var c := e.get_c(caster_id)
	var t := e.get_c(target_id)
	if c != null and t != null:
		_terror_immune(c, t)


func _terror_immune(c: Combatant, t: Combatant) -> void:
	var immune := (t.get_meta("dragons_terror_immune", []) as Array).duplicate()
	if not c.id in immune:
		immune.append(c.id)
	t.set_meta("dragons_terror_immune", immune)


## Inspired by Fear: a creature just became Frightened of a holder (any feature or spell, the holder as its source).
func effect_added(cr: Creature, fx: Effect) -> void:
	if not &"frightened" in fx.conditions or fx.caster_id == "" or fx.caster_id == cr.id:
		return
	var c := enc().get_c(fx.caster_id)
	var ch := _ch(c)
	if ch == null or not feat(c, "cult_of_the_dragon_initiate") or ch.heroic_inspiration or ch.resource_left("inspired_by_fear") <= 0:
		return
	ch.spend_resource("inspired_by_fear")
	_inspire(c, c, "Inspired by Fear")


# --- Emerald Enclave Fledgling, Harper Agent, Arcane Undertaker ---------------------------------------------

## How far Help can reach its enemy: 30 ft for a Harper Agent the enemy can see or hear (Distracting Melody).
func help_reach(c: Combatant, enemy: Combatant) -> int:
	if feat(c, "harper_agent") and enemy != null and enc().spells.can_see_or_hear(enemy, c):
		return 30
	return 5


func after_help(c: Combatant, enemy: Combatant) -> void:
	if feat(c, "emerald_enclave_fledgling"):
		c.set_meta("tag_team_window", _turn_key())
	# Harper Teamwork: the distracted enemy also has Disadvantage on its next save before the helper's next turn.
	if feat(c, "harper_teamwork") and enemy != null:
		var fx := Effect.new("Harper Teamwork", &"feature", "harper_teamwork").with_modifier("disadvantage", {"on": "save:all"})
		fx.caster_id = c.id
		fx.ends = Effect.Ends.START_OF_TURN
		fx.turn_owner_id = c.id
		fx.consume_on = ["save:all"]
		enemy.creature.add_effect(fx)


func _tag_team(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("tag_team_window", "")) != _turn_key():
		return CombatResult.fail("Take the Help action first")
	if t == null or t == c or not c.allied_with(t) or e.distance(c, t) > 5 or not t.can_act():
		return CombatResult.fail("Choose a willing ally within 5 ft who isn't Incapacitated")
	if not e.space_available(t.cell, c.size_cells, [c, t]) or not e.space_available(c.cell, t.size_cells, [c, t]):
		return CombatResult.fail("You can't fit in each other's spaces")
	c.remove_meta("tag_team_window")
	var a := c.cell
	var b := t.cell
	c.cell = b
	t.cell = a
	c.clear_run()
	t.clear_run()
	e.events.append({"type": "move", "id": c.id, "from": a, "to": b, "forced": false})
	e.events.append({"type": "move", "id": t.id, "from": b, "to": a, "forced": false})
	e.spells.zones.on_moved(c, a)
	e.spells.zones.on_moved(t, b)
	_log("move", "%s and %s trade places (Tag Team)" % [c.name(), t.name()], c)
	return CombatResult.new()


## Understanding of Death: Heroic Inspiration after Help stabilizes a dying creature.
func after_stabilize(c: Combatant) -> void:
	var ch := _ch(c)
	if ch == null or not feat(c, "arcane_undertaker") or ch.heroic_inspiration or ch.resource_left("understanding_of_death") <= 0:
		return
	ch.spend_resource("understanding_of_death")
	_inspire(c, c, "Understanding of Death")


# --- Spells: Arcane Artist, Arcane Overload ----------------------------------------------------------------

func after_cast(c: Combatant, s: Dictionary, slot: int, free: bool = false, ctx: Dictionary = {}) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var school := str(s.get("school", ""))
	_subclass_after_cast(c, ch, s, slot, free, ctx)
	if feat(c, "arcane_artist") and school == "illusion" and ch.resource_left("arcane_artist") > 0:
		c.set_meta("arcane_artist_window", _turn_key())
	# The rest need a spell slot spent on a levelled spell.
	if free or slot <= 0 or int(s.get("level", 0)) <= 0:
		return
	if school == "abjuration" and feat(c, "abjuration_adept"):
		_abjuration_ward(c, slot)
	if school == "divination" and feat(c, "divination_adept") and ch.resource_left("divination_adept") < ch.resource_max("divination_adept"):
		ch.restore_resource("divination_adept", 1)
		_log("info", "%s's Divination Adept is ready again" % c.name(), c)
	if school == "necromancy" and feat(c, "necromancy_adept") and allowed(c, "necromancy_adept_benefit") and c.creature.hp < c.creature.max_hp():
		var rolled := _spend_hit_dice(ch, 2, "Necromancy Adept")
		if rolled > 0:
			var got := c.creature.heal(rolled + slot, "Necromancy Adept")
			_log("heal", "%s draws on its own life force: +%d Hit Points (Necromancy Adept)" % [c.name(), got], c)
			enc().events.append({"type": "heal", "id": c.id, "amount": got})
	if feat(c, "spell_subterfuge") and str((s.get("casting_time", {}) as Dictionary).get("unit", "")) == "action" and ch.resource_left("shrouding_spells") > 0:
		c.set_meta("shrouding_window", _turn_key())
	# Simbul's Synostodweomer: up to the slot's level in Hit Dice back as healing, while hurt.
	if c.creature.has_flag("synostodweomer") and c.creature.hp < c.creature.max_hp():
		var mod := 0
		for fx: Effect in c.creature.effects:
			if fx.source_id == "simbuls_synostodweomer":
				mod = _caster_mod(fx.caster_id, "simbuls_synostodweomer")
		var rolled := _spend_hit_dice(ch, slot, "Simbul's Synostodweomer")
		if rolled > 0:
			var got := c.creature.heal(rolled + mod, "Simbul's Synostodweomer")
			_log("heal", "%s draws healing from its own spell: +%d Hit Points (Simbul's Synostodweomer)" % [c.name(), got], c)
			enc().events.append({"type": "heal", "id": c.id, "amount": got})


## Abjuration Adept: twice the slot level in Temporary Hit Points for the most hurt of the caster and its allies
## within 30 ft that it can see.
func _abjuration_ward(c: Combatant, slot: int) -> void:
	var e := enc()
	var best := c
	for a in e.allies_of(c):
		if not a.is_alive() or a.creature.hp <= 0 or e.distance(c, a) > 30 or not e.can_see(c, a):
			continue
		if float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	if best.creature.add_temp_hp(2 * slot, "Abjuration Adept"):
		_log("heal", "%s gains %d Temporary Hit Points (Abjuration Adept)" % [best.name(), 2 * slot], best)


## Rolls up to `n` unused Hit Dice (largest first), spending them; their total, without the Constitution modifier.
func _spend_hit_dice(ch: Character, n: int, label: String) -> int:
	var total := 0
	for i in n:
		var pool := ch.hit_dice()
		var best := 0
		for die: String in pool:
			var entry := pool[die] as Dictionary
			if int(entry["spent"]) < int(entry["total"]) and int(die) > best:
				best = int(die)
		if best == 0:
			break
		ch.hit_dice_spent[str(best)] = int(ch.hit_dice_spent.get(str(best), 0)) + 1
		total += enc().dice.roll_one(best, label)
	return total


func _feat_dc(c: Combatant, feat_id: String) -> int:
	return 8 + _increased_mod(c, feat_id) + c.creature.proficiency_bonus()


## The modifier of the ability a general feat increased (the feat's own pick).
func _increased_mod(c: Combatant, feat_id: String) -> int:
	var ch := _ch(c)
	if ch == null:
		return 0
	for f in ch.feats_taken:
		if str(f["id"]) == feat_id:
			var picks := ch.picks_for("%s.abilities" % str(f["key"]))
			if not picks.is_empty():
				return c.creature.ability_mod(StringName(picks[0]))
	return 0


## Arcane Overload: once armed this turn, an Evocation spell's damage roll gains the Proficiency Bonus. Evocation
## Adept (an Evocation spell) and Spellfire Adept (a spell dealing Radiant): once per turn, up to two Hit Dice.
func spell_damage_bonus(ctx: Dictionary, bonus: Breakdown) -> int:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null:
		return 0
	var s := ctx["s"] as Dictionary
	var total := 0
	for pair: Array in [["evocation_adept", "evocation_adept_benefit", "Evocation Adept"], ["spellfire_adept", "spellfire_adept_benefit", "Spellfire Adept"]]:
		if not feat(c, str(pair[0])) or not allowed(c, str(pair[1])):
			continue
		var fits := str(s.get("school", "")) == "evocation" if str(pair[0]) == "evocation_adept" \
			else (s.get("damage", []) as Array).any(func(d: Variant) -> bool: return str((d as Dictionary).get("type", "")) == "radiant")
		if not fits or not _once_per_turn(c, str(pair[0]) + "_turn"):
			continue
		var hd := _spend_hit_dice(ch, 2, str(pair[2]))
		if hd > 0:
			bonus.add("%s (Hit Dice)" % pair[2], hd)
			total += hd
	return total + _overload(c, ch, s, bonus)


func _overload(c: Combatant, ch: Character, s: Dictionary, bonus: Breakdown) -> int:
	if str(c.get_meta("arcane_overload_armed", "")) != _turn_key():
		return 0
	if str(s.get("school", "")) != "evocation" or ch.resource_left("arcane_overload") <= 0:
		return 0
	ch.spend_resource("arcane_overload")
	c.remove_meta("arcane_overload_armed")
	var pb := ch.proficiency_bonus()
	bonus.add("Arcane Overload", pb)
	return pb


# --- Attacks and damage: Lords' Alliance Agent, Spellfire Spark, Zhentarim Ruffian -------------------------

## Inspiring Strike: once per turn, a Critical Hit on a creature inspires an ally within 30 ft who sees or hears you.
func after_hit(c: Combatant, target: Combatant, critical: bool, st: Dictionary = {}) -> void:
	if target != null and st.has("smite_ctx") and str(((st["smite_ctx"] as Dictionary)["s"] as Dictionary).get("id", "")) == "divine_smite":
		_elemental_smite(c, target)
	if target != null and str(c.get_meta("flustering_armed", "")) == _turn_key() and _ch(c).resource_left("flustering_strike") > 0:
		_flustering_strike(c, target)
	if not critical or target == null or not feat(c, "lords_alliance_agent"):
		return
	var e := enc()
	var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.spells.can_see_or_hear(a, c))
	if who.is_empty() or not _once_per_turn(c, "inspiring_strike_turn"):
		return
	_inspire(c, who[0], "Inspiring Strike")


## Reassert Honor: an enemy the holder can see hurts an ally beside it; the holder's next attack on that enemy has
## Advantage until the end of its next turn.
func after_damage(source: Combatant, target: Combatant, amount: int, parts: Array = []) -> void:
	var e := enc()
	if source == null or amount <= 0 or source == target:
		return
	# Spirit Lantern: an enemy dying in a lantern's light gives it a fragment.
	if target.creature.dead or target.creature.hp <= 0:
		_lantern_catch(target)
	# Dragonscarred: damage dealt on its own turn opens Dragon's Terror as a Bonus Action.
	if e.current() == source and feat(source, "dragonscarred"):
		source.set_meta("dragonscarred_turn", _turn_key())
	# Cold Caster: once per turn, a hit dealing Cold takes 1d4 off the target's next save before the caster's next
	# turn ends.
	var hit := str(e.hit_context.get("attacker", "")) == source.id and str(e.hit_context.get("target", "")) == target.id
	if hit and feat(source, "cold_caster") and parts.any(func(p: Variant) -> bool: return str((p as Dictionary).get("type", "")) == "cold" and int((p as Dictionary).get("amount", 0)) > 0) \
			and _once_per_turn(source, "cold_caster_turn"):
		var fx := Effect.new("Frostbite (Cold Caster)", &"feature", "cold_caster").with_modifier("penalty_die", {"dice": "1d4", "on": ["save:all"]})
		fx.caster_id = source.id
		fx.ends = Effect.Ends.END_OF_TURN
		fx.turn_owner_id = source.id
		fx.skip_turn_ends = e.own_turn_skip(source)
		fx.consume_on = ["save:all"]
		target.creature.add_effect(fx)
		_log("info", "%s is chilled: −1d4 on its next save (Cold Caster)" % target.name(), target)
	for h in e.combatants:
		if h == target or not h.is_alive() or not feat(h, "lords_alliance_agent") or not h.allied_with(target):
			continue
		if not h.hostile_to(source) or e.distance(h, target) > 5 or not e.can_see(h, source):
			continue
		e.add_mark({"kind": "advantage_against", "target": source.id, "attacker": h.id, "source": "Reassert Honor",
			"expires_owner": h.id, "expires_phase": "end", "skip": e.own_turn_skip(h), "consume": true})
		_log("info", "%s will make %s answer for that (Reassert Honor: Advantage on the next attack)" % [h.name(), source.name()], h)


## Magic Absorption (Spellfire Spark): once per turn, 1d4 off damage from a spell or a magical monster action while
## not Incapacitated.
func adjust_incoming(_source: Combatant, target: Combatant, parts: Array) -> void:
	if not feat(target, "spellfire_spark") or not target.can_act():
		return
	var spell_part: Dictionary = {}
	for p: Variant in parts:
		var part := p as Dictionary
		if (bool(part.get("spell", false)) or bool(part.get("magic", false))) and int(part["amount"]) > 0:
			spell_part = p as Dictionary
			break
	if spell_part.is_empty() or not _once_per_turn(target, "magic_absorption_turn"):
		return
	var cut := enc().dice.roll_one(4, "Magic Absorption")
	spell_part["amount"] = maxi(0, int(spell_part["amount"]) - cut)
	_log("info", "%s soaks up %d of the spell's damage (Magic Absorption)" % [target.name(), cut], target)


## Exploit Opening: an Opportunity Attack's damage dice are rolled twice, keeping the better roll.
func exploit_opening(c: Combatant, opts: Dictionary) -> bool:
	return bool(opts.get("opportunity", false)) and feat(c, "zhentarim_ruffian")


# --- Initiative: Family First, Rallying Cry ------------------------------------------------------------------

## Before anyone rolls: a Zhentarim Ruffian may spend Heroic Inspiration for its side's Advantage on Initiative.
func before_initiative() -> void:
	_family_first.clear()
	for c in enc().combatants:
		var ch := _ch(c)
		if ch == null or not ch.heroic_inspiration or not feat(c, "zhentarim_ruffian") or not allowed(c, "family_first"):
			continue
		if _family_first.has(str(c.side)):
			continue
		ch.heroic_inspiration = false
		_family_first[str(c.side)] = c.name()
		_log("info", "%s spends Heroic Inspiration: the whole side rolls Initiative with Advantage (Family First)" % c.name(), c)


func initiative_advantage(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	for side: String in _family_first:
		var holder := str(_family_first[side])
		if side == str(c.side) or (side == "party" and c.side == &"guest") or (side == "guest" and c.side == &"party"):
			out.append("Family First (%s)" % holder)
	return out


## Rallying Cry (Purple Dragon Rook): on rolling Initiative, Heroic Inspiration for up to Proficiency Bonus allies
## within 30 ft that the Rook can see. Once per Long Rest.
func initiative_rolled() -> void:
	var e := enc()
	for c in e.combatants:
		var ch := _ch(c)
		if ch == null or not feat(c, "purple_dragon_rook") or not c.can_act() or ch.resource_left("rook_rallying_cry") <= 0:
			continue
		if not allowed(c, "rook_rallying_cry"):
			continue
		var who := _uninspired_allies(c, 30, func(a: Combatant) -> bool: return e.can_see(c, a))
		if who.is_empty():
			continue
		ch.spend_resource("rook_rallying_cry")
		_log("info", "%s raises a rallying cry" % c.name(), c)
		for a: Combatant in who.slice(0, ch.proficiency_bonus()):
			_inspire(c, a, "Rallying Cry")


# --- Tyro of the Gauntlet -----------------------------------------------------------------------------------

## Stand as One: a holder within 5 ft of `target` (not itself) spends its Reaction so the push or pull fails.
func blocks_forced_move(target: Combatant) -> bool:
	var e := enc()
	if not target.can_act():
		return false
	for h in e.combatants:
		if h == target or not feat(h, "tyro_of_the_gauntlet") or not h.allied_with(target) or e.distance(h, target) > 5:
			continue
		if not e.spells.can_react(h) or not allowed(h, "stand_as_one"):
			continue
		h.reaction_available = false
		_log("reaction", "%s braces %s: no push or pull (Stand as One)" % [h.name(), target.name()], h)
		return true
	return false


## Gauntlet Vigilant: after taking the Ready action, the next attack against the holder before its next turn
## starts has Disadvantage.
func after_ready(c: Combatant) -> void:
	if not feat(c, "tyro_of_the_gauntlet"):
		return
	var fx := Effect.new("Gauntlet Vigilant", &"feature", "gauntlet_vigilant").with_modifier("attacked_with", {"value": "disadvantage"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	fx.consume_when_attacked = true
	c.creature.add_effect(fx)
	_log("info", "%s stays on guard (Gauntlet Vigilant)" % c.name(), c)


# --- General feats ------------------------------------------------------------------------------------------

func _flustering_strike(c: Combatant, t: Combatant) -> void:
	var e := enc()
	_ch(c).spend_resource("flustering_strike")
	c.remove_meta("flustering_armed")
	var sv := t.creature.roll_save(e.dice, &"wis", _feat_dc(c, "fairy_trickster"), [], [], "Wisdom save vs Flustering Strike (%s)" % t.name())
	if sv.success:
		_log("info", "%s keeps its composure (Flustering Strike)" % t.name(), t, [sv.describe()])
		return
	var fx := Effect.new("Flustered", &"feature", "flustering_strike").with_modifier("disadvantage", {"on": "save:all"})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	fx.skip_turn_ends = e.own_turn_skip(c)
	if t.creature.add_effect(fx):
		_log("condition", "%s is flustered: Disadvantage on saves (Flustering Strike)" % t.name(), t, [sv.describe()])


func _shrouding_spells(c: Combatant) -> CombatResult:
	var e := enc()
	if str(c.get_meta("shrouding_window", "")) != _turn_key() or _ch(c).resource_left("shrouding_spells") <= 0:
		return CombatResult.fail("Cast a spell with an action and a slot first")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	_ch(c).spend_resource("shrouding_spells")
	c.remove_meta("shrouding_window")
	c.bonus_available = false
	c.movement_left += c.speed()
	_log("info", "%s wraps itself in its spell's afterglow: Dash (Shrouding Spells)" % c.name(), c)
	var spotter := e.hide_blocker(c)
	if spotter != "":
		_log("info", "%s can't hide here (%s)" % [c.name(), spotter], c)
		return CombatResult.new()
	var t := c.creature.roll_check(e.dice, &"stealth", 15)
	if t.success:
		c.hidden = true
		c.stealth_total = t.total
		c.creature.add_condition(&"invisible", "Hidden")
		_log("info", "%s hides (Stealth %d)" % [c.name(), t.total], c, [t.describe()])
	else:
		_log("info", "%s fails to hide (Stealth %d vs DC 15)" % [c.name(), t.total], c, [t.describe()])
	return CombatResult.new()


## Sneaky Casting: a hidden caster stays hidden through a Verbal spell this turn; the end of its turn checks cover.
func sneaky_casting(c: Combatant) -> bool:
	if not feat(c, "spell_subterfuge"):
		return false
	c.set_meta("sneaky_cast_turn", _turn_key())
	return true


func turn_end(c: Combatant) -> void:
	if c.hidden and str(c.get_meta("sneaky_cast_turn", "")) == _turn_key():
		enc()._check_still_hidden(c)
	_transfix_turn_end(c)


func _commandant_rally(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	if t == null or not c.allied_with(t) or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose an ally you can see within 30 ft")
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("commandant_rally") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("commandant_rally")
	c.bonus_available = false
	var amount := int(e.dice.roll_expr("2d6", "Rallying Command")["total"]) + _increased_mod(c, "purple_dragon_commandant")
	if t.creature.add_temp_hp(maxi(1, amount), "Rallying Command"):
		_log("heal", "%s rallies %s: %d Temporary Hit Points" % [c.name(), t.name(), maxi(1, amount)], c)
	else:
		_log("info", "%s rallies %s, who already has as many Temporary Hit Points" % [c.name(), t.name()], c)
	return CombatResult.new()


func _lordly_resolve(c: Combatant, picked: Array[Combatant]) -> CombatResult:
	var e := enc()
	if picked.is_empty() or picked.size() > 3:
		return CombatResult.fail("Choose up to three creatures within 60 ft who can see you")
	for t in picked:
		if e.distance(c, t) > 60 or not e.can_see(t, c):
			return CombatResult.fail("%s must be within 60 ft and see you" % t.name())
	var why := e._bonus_check(c)
	if why != "":
		return CombatResult.fail(why)
	if _ch(c).resource_left("lordly_resolve") <= 0:
		return CombatResult.fail("None left")
	_ch(c).spend_resource("lordly_resolve")
	c.bonus_available = false
	_log("info", "%s steadies the line (Lordly Resolve)" % c.name(), c)
	for t in picked:
		if t.creature.has_condition(&"prone") and e.spells.can_react(t) and t.speed() > 0:
			t.reaction_available = false
			t.creature.remove_condition(&"prone")
			_log("move", "%s gets back on its feet (Lordly Resolve)" % t.name(), t)
		var fx := Effect.new("Lordly Resolve", &"feature", "lordly_resolve").with_modifier("condition_immunity", {"value": "charmed"}) \
			.with_modifier("condition_immunity", {"value": "frightened"}).with_modifier("flag", {"value": "no_possession"}) \
			.with_modifier("advantage", {"on": ["save_vs:charmed", "save_vs:frightened"]})
		fx.caster_id = c.id
		fx.lasting({"kind": "minutes", "amount": 1})
		fx.turn_owner_id = c.id
		fx.data["ends_if_caster_incapacitated"] = true
		t.creature.add_effect(fx)
	return CombatResult.new()


## Lordly Resolve ends when its giver is Incapacitated; checked as each turn starts. Negative Energy Flood's dead rise
## as their killer's turn starts.
func turn_start(c: Combatant) -> void:
	var e := enc()
	for z: Dictionary in _rising.duplicate():
		if str(z["caster"]) == c.id:
			_rising.erase(z)
			_raise_zombie(c, z)
	for t in e.combatants:
		for fx: Effect in t.creature.effects.duplicate():
			if not bool(fx.data.get("ends_if_caster_incapacitated", false)):
				continue
			var giver := e.get_c(fx.caster_id)
			if giver == null or not giver.can_act():
				t.creature.remove_effect(fx)


## Harper Teamwork: a holder's successful save ends its Frightened or Paralyzed; the same ends on an ally.
func after_save_ended(c: Combatant, fx: Effect) -> void:
	var e := enc()
	if not feat(c, "harper_teamwork"):
		return
	for cond: StringName in [&"frightened", &"paralyzed"]:
		if not cond in fx.conditions:
			continue
		for a in e.allies_of(c):
			if a == c or e.distance(c, a) > 30 or not e.can_see(c, a) or not a.creature.has_condition(cond):
				continue
			e.spells.cure(a, cond)
			_log("heal", "%s's courage frees %s: no longer %s (Harper Teamwork)" % [c.name(), a.name(), String(cond).capitalize()], c)
			e.events.append({"type": "condition", "id": a.id})
			return


## Faerie Trod Trotter: after Disengage on its own turn, no extra cost for Difficult Terrain until the turn ends.
func after_disengage(c: Combatant) -> void:
	if not feat(c, "fairy_trickster"):
		return
	var fx := Effect.new("Faerie Trod Trotter", &"feature", "faerie_trod_trotter").with_modifier("flag", {"value": "ignore_difficult_terrain"})
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)


## Divination Adept (Automatic only: a roll can't wait for a choice): Disadvantage on an enemy's save against the
## holder's own spell. Order's Resilience: Advantage on Strength saves beside an ally.
func before_d20(c: Combatant, kind: D20Test.Kind, keys: Array[String]) -> Dictionary:
	var e := enc()
	var out := {}
	if kind != D20Test.Kind.SAVING_THROW:
		return out
	for h in e.combatants:
		var hc := _ch(h)
		if hc == null or not feat(h, "divination_adept") or not ("save_vs:spell:" + h.id) in keys or not h.hostile_to(c):
			continue
		if str(h.reaction_rules.get("divination_adept_benefit", "never")) != "auto" or hc.resource_left("divination_adept") <= 0:
			continue
		if not e.spells.can_react(h) or e.distance(h, c) > 60 or not e.can_see(h, c):
			continue
		hc.spend_resource("divination_adept")
		h.reaction_available = false
		_log("reaction", "%s foresees %s faltering (Divination Adept)" % [h.name(), c.name()], h)
		out["disadvantage"] = ["Divination Adept"]
		break
	if "save:str" in keys and c.can_act():
		for h2 in e.combatants:
			if not feat(h2, "orders_resilience") or not h2.can_act() or not h2.allied_with(c):
				continue
			var partner := h2 != c and e.distance(h2, c) <= 5
			if h2 == c:
				partner = e.allies_of(c).any(func(a: Combatant) -> bool: return a != c and a.can_act() and e.distance(a, c) <= 5)
			if partner:
				out["advantage"] = ["Order's Resilience"]
				break
	return out


## Street Justice's Headlock: allies have Advantage against a creature the holder is grappling.
func attack_advantage(c: Combatant, target: Combatant) -> Array[String]:
	var out: Array[String] = []
	var e := enc()
	# Strike Fear (Scion of the Three): Advantage against a creature it Terrified.
	if target != null and target.creature.has_flag("terrified_by:%s" % c.id) and target.creature.has_condition(&"frightened"):
		out.append("Terrified")
	# `grapples` maps a grappled creature to its grappler.
	if target == null or not e.grapples.has(target.id):
		return out
	var grappler := e.get_c(str(e.grapples[target.id]))
	if grappler != null and grappler != c and feat(grappler, "street_justice") and grappler.allied_with(c):
		out.append("Headlock (%s)" % grappler.name())
	return out


## Zhentarim Tactics: a melee hit from a creature within 5 ft earns an Opportunity Attack back. Bloodthirst (Scion
## of the Three): an enemy left Bloodied draws the Scion to it.
func queue_damage_reactions(source: Combatant, target: Combatant) -> void:
	var e := enc()
	if target != null and target.is_alive() and target.creature.hp > 0 and target.creature.is_bloodied():
		for h in e.combatants:
			var hc := _ch(h)
			if hc == null or not CombatFeatures.has_feature(h, "scion_bloodthirst") or not h.hostile_to(target) or hc.resource_left("scion_bloodthirst") <= 0:
				continue
			if not e.spells.can_react(h) or e.distance(h, target) > 30 or not e.can_see(h, target):
				continue
			e.reaction_queue.append({"kind": "fr_bloodthirst", "reactor": h.id, "trigger": target.id})
	if source == null or target == null or not feat(target, "zhentarim_tactics") or not bool(e.hit_context.get("melee", false)):
		return
	if str(e.hit_context.get("attacker", "")) != source.id or e.distance(target, source) > 5 or not e.spells.can_react(target):
		return
	if e.best_melee_option(target, source).is_empty():
		return
	e.reaction_queue.append({"kind": "fr_zhentarim_tactics", "reactor": target.id, "trigger": source.id})


func queued_ok(q: Dictionary, reactor: Combatant) -> bool:
	var e := enc()
	if str(q["kind"]) == "fr_bloodthirst":
		var bt := e.get_c(str(q["trigger"]))
		return e.spells.can_react(reactor) and bt != null and bt.is_alive() and bt.creature.hp > 0 and _ch(reactor).resource_left("scion_bloodthirst") > 0
	if str(q["kind"]) == "fr_zhentarim_tactics":
		var t := e.get_c(str(q["trigger"]))
		return e.spells.can_react(reactor) and t != null and t.is_alive() and e.distance(reactor, t) <= 5
	return false


func fire_queued(q: Dictionary, reactor: Combatant, trigger: Combatant) -> CombatResult:
	if str(q["kind"]) == "fr_bloodthirst":
		return _bloodthirst(reactor, trigger)
	if str(q["kind"]) == "fr_zhentarim_tactics":
		return enc()._opportunity_attack(reactor, trigger)
	return CombatResult.new()


func queued_text(kind: String) -> Array:
	if kind == "fr_bloodthirst":
		return ["Reaction: Bloodthirst?", "%s is Bloodied. %s can teleport beside it and strike?", "Reaction and a use of Bloodthirst"]
	if kind == "fr_zhentarim_tactics":
		return ["Reaction: Zhentarim Tactics?", "%s hit %s in melee. Answer with an Opportunity Attack?", "Reaction"]
	return ["Reaction?", "%s / %s", "Reaction"]


# --- Spells ------------------------------------------------------------------------------------------------

## Negative Energy Flood's Humanoid dead waiting to rise: {caster, cell, slot}.
var _rising: Array[Dictionary] = []


## The spellcasting modifier of whoever cast `spell_id` (its effect's caster).
func _caster_mod(caster_id: String, spell_id: String) -> int:
	var e := enc()
	var caster := e.get_c(caster_id)
	if caster == null or _ch(caster) == null:
		return 0
	var entry := e.spells._entry_any(caster, spell_id)
	return int(e.spells.numbers(caster, entry).get("mod", 0))


## Spells whose rules are in code here. True when handled.
func resolve_spell(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> bool:
	match str((ctx["s"] as Dictionary)["id"]):
		"wither_and_bloom":
			_wither_and_bloom(ctx, tgt, cells, r)
			return true
		"negative_energy_flood":
			_negative_energy_flood(ctx, tgt, r)
			return true
		"elminsters_effulgent_spheres":
			e_spheres_cast(ctx, r)
			return false
		"illusory_dragon":
			_illusory_dragon(ctx, r)
			return true
		"conjure_constructs":
			_conjure_constructs(ctx, tgt, r)
			return true
		"transfix":
			for t in tgt:
				_transfix_one(ctx, t, r)
			enc().spells._grant_sustained(ctx, tgt)
			return true
	return false


func _wither_and_bloom(ctx: Dictionary, tgt: Array[Combatant], cells: Array[Vector2i], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var victims := e.spells._area_victims(c, ctx["s"] as Dictionary, cells) if tgt.is_empty() else tgt
	e.spells._save_spell(ctx, victims, r)
	# The bloom: the most hurt ally in the Sphere spends Hit Dice (one, plus one per slot level above 2).
	var best: Combatant = null
	for a in e.living():
		if not (a == c or a.allied_with(c)) or _ch(a) == null or a.creature.hp >= a.creature.max_hp():
			continue
		if not a.footprint().any(func(cl: Vector2i) -> bool: return cl in cells):
			continue
		if best == null or float(a.creature.hp) / maxf(1.0, a.creature.max_hp()) < float(best.creature.hp) / maxf(1.0, best.creature.max_hp()):
			best = a
	if best == null:
		return
	var dice := 1 + maxi(0, int(ctx["slot"]) - 2)
	var rolled := _spend_hit_dice(_ch(best), dice, "Wither and Bloom")
	if rolled <= 0:
		return
	var got := best.creature.heal(rolled + int((ctx["nums"] as Dictionary).get("mod", 0)), "Wither and Bloom")
	r.lines.append(e.log.add("heal", "%s blooms: +%d Hit Points (Wither and Bloom)" % [best.name(), got], best.id))
	e.events.append({"type": "heal", "id": best.id, "amount": got})


func _negative_energy_flood(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	for t in tgt:
		if t.creature.creature_type == &"undead":
			var thp := int(e.dice.roll_expr("3d10", "Negative Energy Flood")["total"])
			if t.creature.add_temp_hp(thp, "Negative Energy Flood"):
				r.lines.append(e.log.add("heal", "%s drinks the negative energy: %d Temporary Hit Points" % [t.name(), thp], t.id))
			continue
		var only: Array[Combatant] = [t]
		e.spells._save_spell(ctx, only, r)
		if t.creature.dead and t.creature.creature_type == &"humanoid":
			_rising.append({"caster": c.id, "cell": t.cell, "slot": int(ctx["slot"])})
			r.lines.append(e.log.add("info", "%s will rise as a Zombie at the start of %s's next turn" % [t.name(), c.name()], t.id))


func _raise_zombie(c: Combatant, z: Dictionary) -> void:
	var e := enc()
	var s := Compendium.shared().spell_data("negative_energy_flood")
	var nums := e.spells.numbers(c, e.spells._entry_any(c, "negative_energy_flood"))
	var ctx := {"c": c, "s": s, "slot": int(z["slot"]), "nums": nums, "conc": null, "opts": {}, "choice": "zombie",
		"summon_block": SummonBlocks.for_spell("animate_dead", int(z["slot"]), "zombie", nums)}
	var r := CombatResult.new()
	e.spells._summon(ctx, z["cell"] as Vector2i, r)
	e.log.add("spell", "A Zombie rises to serve %s (Negative Energy Flood)" % c.name(), c.id)


## Alustriel's Mooncloak (Automatic only): a failed save against being Frightened, Grappled or Restrained succeeds
## and the spell ends, spending the Reaction.
func after_d20(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	_unravel(c, t, keys)
	_shared_resilience(c, t)
	_noble_scion_save(c, t)
	_mooncloak(c, t, keys)


func _mooncloak(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	var e := enc()
	if t.success or t.kind != D20Test.Kind.SAVING_THROW or c.creature.concentration == null:
		return
	if c.creature.concentration.source_id != "alustriels_mooncloak" or str(c.reaction_rules.get("alustriels_mooncloak", "never")) != "auto":
		return
	if not keys.any(func(k: String) -> bool: return k in ["save_vs:frightened", "save_vs:grappled", "save_vs:restrained"]) or not e.spells.can_react(c):
		return
	c.reaction_available = false
	t.add_bonus(maxi(0, t.target - t.total), "Alustriel's Mooncloak")
	c.creature.concentration.end("its moonlight steadies %s" % c.name())
	_log("reaction", "%s spends the Mooncloak's moonlight to shrug it off" % c.name(), c)


## Why a `do: faerun` sustained action can't be used now ("" if it can); checked before its cost is paid.
func sustained_why(c: Combatant, a: Dictionary, d: Dictionary, t: Combatant, point: Vector2) -> String:
	var e := enc()
	match str(d.get("mode", str(a["spell_id"]))):
		"elminsters_effulgent_spheres":
			if t == null or e.distance(c, t) > 120 or not e.can_see(c, t):
				return "Choose a creature you can see within 120 ft"
			if _spheres(c) <= 0:
				return "No spheres left"
		"harm", "mend", "veil":
			if t == null or e.distance(c, t) > 60 or not e.can_see(c, t):
				return "Choose a creature you can see within 60 ft"
			if int(c.get_meta("lantern_fragments", 0)) <= 0:
				return "No spirit fragments"
			if str(d.get("mode", "")) == "mend" and t.creature.creature_type != &"undead":
				return "Only an Undead can be mended"
		"transfix":
			if t == null or t == c or e.distance(c, t) > 60 or not e.can_see(c, t):
				return "Choose a creature you can see within 60 ft"
			if t.id in (c.get_meta("transfix_resisted", []) as Array) or transfixed_by(t) == c:
				return "%s can't be transfixed again" % t.name()
		"dragon_breath":
			if point == Vector2.INF:
				return "Choose where the dragon breathes"
		"constructs":
			var obj := e.spells.zones.object_of(str(a["caster_id"]), str(a["spell_id"]))
			if obj == null:
				return "The spirits are gone"
			if t == null or e.grid.distance_ft(obj.cell, 1, t.cell, t.size_cells) > 5:
				return "Choose a creature within 5 ft of the spirits"
	return ""


## A sustained spell action whose rules are in code here (`do: faerun`); its cost is already paid.
func sustained(c: Combatant, a: Dictionary, d: Dictionary, ctx: Dictionary, targets: Array, point: Vector2, _dir: Vector2, r: CombatResult) -> CombatResult:
	var e := enc()
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() else null
	match str(d.get("mode", str(a["spell_id"]))):
		"elminsters_effulgent_spheres":
			_spend_sphere(c)
			var sub := ctx.duplicate()
			var s := (ctx["s"] as Dictionary).duplicate()
			s["attack"] = "ranged"
			s["damage"] = [{"dice": "3d6", "type": str(ctx.get("choice", "fire")) if str(ctx.get("choice", "")) != "" else "fire"}]
			s.erase("effects")
			sub["s"] = s
			e.log.add("spell", "%s hurls an effulgent sphere" % c.name(), c.id)
			e.spells.spell_attack(sub, t, r)
		"harm", "mend", "veil":
			c.set_meta("lantern_fragments", int(c.get_meta("lantern_fragments", 0)) - 1)
			_lantern(c, str(d.get("mode", "")), t, ctx, r)
		"transfix":
			_transfix_one(ctx, t, r)
		"dragon_breath":
			_dragon_breath(c, ctx, point, int(d.get("move", 60)), r)
		"constructs":
			_constructs_act(c, ctx, t, r)
	return CombatResult.new()


# --- Elminster's Effulgent Spheres ---------------------------------------------------------------------------

const ELEMENTS := ["acid", "cold", "fire", "lightning", "thunder"]


func e_spheres_cast(ctx: Dictionary, _r: CombatResult) -> void:
	var c := ctx["c"] as Combatant
	c.set_meta("effulgent_spheres", 6 + maxi(0, int(ctx["slot"]) - 6))


func _spheres(c: Combatant) -> int:
	if not c.creature.has_flag("effulgent_spheres"):
		return 0
	return int(c.get_meta("effulgent_spheres", 0))


func _spend_sphere(c: Combatant) -> void:
	var left := _spheres(c) - 1
	c.set_meta("effulgent_spheres", left)
	if left <= 0:
		for fx: Effect in c.creature.effects.duplicate():
			if fx.source_id == "elminsters_effulgent_spheres":
				c.creature.remove_effect(fx)
		_log("info", "%s's last effulgent sphere is spent" % c.name(), c)


func _sphere_ward(c: Combatant, ty: String) -> void:
	_spend_sphere(c)
	c.reaction_available = false
	var fx := Effect.new("Effulgent Sphere (%s)" % ty.capitalize(), &"spell", "effulgent_sphere_ward").with_modifier("resistance", {"value": ty})
	fx.caster_id = c.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = c.id
	c.creature.add_effect(fx)
	_log("reaction", "%s catches the %s on a sphere: Resistance until its next turn" % [c.name(), ty], c)


# --- Backlash and the spheres against damage -------------------------------------------------------------

## Attack damage: offers for the reaction prompt (Backlash, a sphere's ward, Elemental Rebuke, Crown of Spellfire).
func against_damage(st: Dictionary, parts: Dictionary, total: Callable, cut: Callable, out: Array, responded: Array) -> void:
	var e := enc()
	var target := st["target"] as Combatant
	var source := st["c"] as Combatant
	_subclass_against_damage(target, source, total, cut, out)
	if e.spells.can_cast_reaction(target, "backlash") and int(total.call()) > 0:
		responded.append("backlash")
		out.append({"kind": "backlash", "reactor": target, "trigger": source.id, "title": "Reaction: Backlash?",
			"text": "%s hits %s for %d. Cut it by 4d6 + your spellcasting modifier and lash back for 4d6 Force?" % [source.name(), target.name(), int(total.call())],
			"cost": "Reaction and a level 4+ spell slot",
			"still": func() -> bool: return e.spells.can_cast_reaction(target, "backlash") and int(total.call()) > 0,
			"use": func() -> void: _backlash(target, source, cut)})
	var ty := ""
	for k: String in parts:
		if k in ELEMENTS and int(parts[k]) > 0:
			ty = k
	if ty != "" and _spheres(target) > 0 and e.spells.can_react(target) and target.creature.resistance_source(StringName(ty)) == "":
		responded.append("elminsters_effulgent_spheres")
		out.append({"kind": "elminsters_effulgent_spheres", "reactor": target, "trigger": source.id, "title": "Reaction: an effulgent sphere?",
			"text": "%s deals %s damage. Spend a sphere for Resistance to it until your next turn?" % [source.name(), ty.capitalize()],
			"cost": "Reaction and a sphere",
			"still": func() -> bool: return _spheres(target) > 0 and e.spells.can_react(target),
			"use": func() -> void: _sphere_ward(target, ty)})


## Damage that can't pause (spells, hazards): Backlash and the spheres act only on Automatic.
func synchronous_damage(source: Combatant, target: Combatant, parts: Array, details: Array, resolved: Array) -> Array:
	var e := enc()
	if target == null or not target.creature is Character:
		return parts
	var out := parts
	var total := func() -> int:
		var n := 0
		for p: Variant in out:
			n += maxi(0, int((p as Dictionary)["amount"]))
		return n
	if not "elminsters_effulgent_spheres" in resolved and _spheres(target) > 0 and e.spells.can_react(target) \
			and str(target.reaction_rules.get("elminsters_effulgent_spheres", "ask")) == "auto":
		for p: Variant in out:
			var ty := str((p as Dictionary)["type"])
			if ty in ELEMENTS and int((p as Dictionary)["amount"]) > 0 and target.creature.resistance_source(StringName(ty)) == "":
				_sphere_ward(target, ty)
				break
	if not "backlash" in resolved and int(total.call()) > 0 and e.spells.can_cast_reaction(target, "backlash") \
			and str(target.reaction_rules.get("backlash", "ask")) == "auto":
		out = out.duplicate(true)
		_backlash(target, source, func(amount: int, label: String) -> void:
			var left := amount
			for p2: Variant in out:
				var d := p2 as Dictionary
				var cutn := mini(left, maxi(0, int(d["amount"])))
				d["amount"] = int(d["amount"]) - cutn
				left -= cutn
			details.append("%s: −%d" % [label, amount - left]))
	return out


func _backlash(c: Combatant, source: Combatant, cut: Callable) -> void:
	var e := enc()
	var ch := _ch(c)
	var slot := e.spells._lowest_slot(ch, 4)
	if slot == 0:
		return
	c.reaction_available = false
	ch.expend_slot(slot)
	var s := Compendium.shared().spell_data("backlash")
	var nums := e.spells.numbers(c, e.spells._entry_any(c, "backlash"))
	var extra := maxi(0, slot - 4)
	var guard := int(e.dice.roll_expr("%dd6" % (4 + extra), "Backlash")["total"]) + int(nums.get("mod", 0))
	e.log.add("spell", "%s answers with Backlash (level %d slot)" % [c.name(), slot], c.id)
	e.events.append({"type": "spell", "caster": c.id, "spell": "backlash", "cells": [], "targets": [source.id] if source != null else []})
	cut.call(guard, "Backlash")
	if source == null or not source.is_alive() or e.distance(c, source) > 60:
		return
	var ctx := {"c": c, "s": s, "slot": slot, "nums": nums, "conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var only: Array[Combatant] = [source]
	e.spells._save_spell(ctx, only, CombatResult.new())


# --- Holy Star of Mystra ----------------------------------------------------------------------------------

## After a successful save against a level 7 or lower spell aimed at the holder alone: turned back on its caster
## (Automatic only).
func reflects_spell(c: Combatant, t: Combatant, ctx: Dictionary, victims: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var s := ctx["s"] as Dictionary
	if not t.creature.has_flag("holy_star_reflect") or bool(ctx.get("turned", false)) or int(ctx.get("slot", 0)) > 7:
		return
	if victims.size() != 1 or s.has("area") or c == t or not c.is_alive() or not e.spells.can_react(t):
		return
	if str(t.reaction_rules.get("holy_star_of_mystra", "never")) != "auto":
		return
	t.reaction_available = false
	var back := ctx.duplicate()
	back["turned"] = true
	r.lines.append(e.log.add("reaction", "%s's Holy Star turns %s back on %s" % [t.name(), s.get("name", ""), c.name()], t.id))
	var only: Array[Combatant] = [c]
	e.spells._save_spell(back, only, r)


# --- Spirit Lantern ---------------------------------------------------------------------------------------

func _lantern_catch(dead: Combatant) -> void:
	var e := enc()
	for h in e.combatants:
		if not h.creature.has_flag("spirit_lantern") or not h.hostile_to(dead) or e.distance(h, dead) > 60:
			continue
		var cap := maxi(1, _caster_mod(h.id, "spirit_lantern"))
		var n := int(h.get_meta("lantern_fragments", 0))
		if n < cap:
			h.set_meta("lantern_fragments", n + 1)
			_log("info", "%s's lantern catches a fragment of %s's spirit (%d)" % [h.name(), dead.name(), n + 1], h)


func _lantern(c: Combatant, mode: String, t: Combatant, ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var mod := int((ctx["nums"] as Dictionary).get("mod", 0))
	match mode:
		"harm":
			var s := (ctx["s"] as Dictionary).duplicate()
			s["save"] = "con"
			s["save_success"] = "half"
			s["damage"] = [{"dice": "4d8+%d" % mod, "type": "necrotic"}]
			s.erase("effects")
			var sub := ctx.duplicate()
			sub["s"] = s
			var only: Array[Combatant] = [t]
			e.spells._save_spell(sub, only, r)
		"mend":
			var got := t.creature.heal(int(e.dice.roll_expr("4d8", "Spirit Lantern")["total"]) + mod, "Spirit Lantern")
			r.lines.append(e.log.add("heal", "%s mends %s with a captured spirit: +%d Hit Points" % [c.name(), t.name(), got], c.id))
			e.events.append({"type": "heal", "id": t.id, "amount": got})
		"veil":
			var fx := Effect.new("Spirit Veil", &"spell", "spirit_lantern").with_modifier("attacked_with", {"value": "disadvantage"})
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			t.creature.add_effect(fx)
			r.lines.append(e.log.add("info", "Spirits veil %s: attacks against it have Disadvantage" % t.name(), c.id))


# --- Transfix -----------------------------------------------------------------------------------------------

func transfixed_by(t: Combatant) -> Combatant:
	if not t.creature.has_flag("transfixed"):
		return null
	for fx: Effect in t.creature.effects:
		if fx.source_id == "transfix":
			return enc().get_c(fx.caster_id)
	return null


func _transfix_one(ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if t == null:
		return
	var only: Array[Combatant] = [t]
	e.spells._save_spell(ctx, only, r)
	if transfixed_by(t) != c:
		var resisted := (c.get_meta("transfix_resisted", []) as Array).duplicate()
		resisted.append(t.id)
		c.set_meta("transfix_resisted", resisted)


## Transfix: a creature ending its turn within 5 ft of its caster takes the Psychic damage.
func _transfix_turn_end(c: Combatant) -> void:
	var e := enc()
	var caster := transfixed_by(c)
	if caster == null or e.distance(c, caster) > 5:
		return
	var s := Compendium.shared().spell_data("transfix")
	var conc := caster.creature.concentration
	var slot := 7
	for fx: Effect in c.creature.effects:
		if fx.source_id == "transfix":
			slot = maxi(7, fx.spell_level)
	var rolled := e._roll_damage_dice("%dd8" % (4 + slot - 7), false, 0, "Transfix")
	var nums := e.spells.numbers(caster, e.spells._entry_any(caster, "transfix"))
	var ctx := {"c": caster, "s": s, "slot": slot, "nums": nums, "conc": conc, "opts": {}, "choice": "", "point": Vector2.INF}
	e.spells.deal_spell_damage(ctx, c, [{"amount": int(rolled["total"]), "type": "psychic", "spell": true}], false, "Transfix", [str(rolled["text"])])


# --- Illusory Dragon --------------------------------------------------------------------------------------

func _illusory_dragon(ctx: Dictionary, r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	var s := ctx["s"] as Dictionary
	var point := ctx["point"] as Vector2
	var o := FieldObject.new(FieldObject.Kind.ILLUSION, "illusory_dragon", "Illusory Dragon")
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = Vector2i(floori(point.x), floori(point.y)) if point != Vector2.INF else c.cell
	o.cells = CombatGrid.footprint(o.cell, 3)
	o.rules = {"choice": str(ctx.get("choice", "fire")), "size": 3}
	o.keep_with(ctx["conc"] as Concentration)
	e.spells.zones.add(o, r)
	e.events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(e.log.add("spell", "A Huge shadow dragon looms over the field", c.id))
	# Its appearance: every enemy that sees it saves or drops what it holds and is Frightened.
	var conc := ctx["conc"] as Concentration
	for t in e.hostiles_of(c):
		if t.is_down() or not e.can_see_space(t, o.cell, 3):
			continue
		var keys := SpellCaster.spell_save_keys(c.id)
		keys.append("save_vs:frightened")
		var sv := t.creature.roll_save(e.dice, &"wis", o.save_dc, [], [], "Wisdom save vs the Illusory Dragon (%s)" % t.name(), keys)
		if sv.success:
			e.log.add("info", "%s isn't cowed by the dragon" % t.name(), t.id, [sv.describe()])
			continue
		var fx := Effect.new("Illusory Dragon", &"spell", "illusory_dragon").with_condition(&"frightened")
		fx.caster_id = c.id
		fx.spell_level = o.slot
		fx.repeat_save = {"ability": "wis", "dc": o.save_dc, "when": "end", "if": "no_sight_of_object"}
		if conc != null:
			conc.attach(t.creature, fx)
		else:
			t.creature.add_effect(fx)
		if t.creature.has_condition(&"frightened"):
			t.set_meta("dropped_weapon", true)
			e.log.add("condition", "%s drops what it holds and cowers before the dragon" % t.name(), t.id, [sv.describe()])
			e.events.append({"type": "condition", "id": t.id})
	if s.has("sustain"):
		e.spells._grant_sustained(ctx, [])


func _dragon_breath(c: Combatant, ctx: Dictionary, point: Vector2, move_ft: int, r: CombatResult) -> void:
	var e := enc()
	var o := e.spells.zones.object_of(c.id, "illusory_dragon")
	if o == null:
		return
	# The dragon closes up to `move_ft` toward the point, then breathes at it.
	var aim := point - (Vector2(o.cell) + Vector2(1.5, 1.5))
	var steps := mini(int(move_ft / CombatGrid.FEET), maxi(0, int(aim.length()) - 6))
	if steps > 0:
		var dv := Vector2i((aim.normalized() * float(steps)).round())
		var to := o.cell + dv
		if e.grid.in_bounds(to) and e.grid.in_bounds(to + Vector2i(2, 2)):
			o.cell = to
			o.cells = CombatGrid.footprint(to, 3)
			e.spells.zones.moved_object(o, r)
	var cells := e.grid.cone_from(o.cell, 3, point, 60)
	var s := (ctx["s"] as Dictionary).duplicate()
	s["damage"] = [{"dice": "6d6", "type": str(o.rules.get("choice", "fire"))}]
	s.erase("effects")
	var sub := ctx.duplicate()
	sub["s"] = s
	e.events.append({"type": "spell", "caster": c.id, "spell": "illusory_dragon", "cells": cells, "targets": []})
	e.log.add("spell", "The shadow dragon breathes", c.id)
	var victims: Array[Combatant] = []
	for t in e.living():
		if t != c and t.footprint().any(func(x: Vector2i) -> bool: return x in cells):
			victims.append(t)
	e.spells._save_spell(sub, victims, r)


# --- Conjure Constructs -----------------------------------------------------------------------------------

func _conjure_constructs(ctx: Dictionary, tgt: Array[Combatant], r: CombatResult) -> void:
	var e := enc()
	var c := ctx["c"] as Combatant
	if tgt.is_empty():
		return
	var t := tgt[0]
	var o := FieldObject.new(FieldObject.Kind.LIGHTS, "conjure_constructs", "Construct Spirits")
	o.caster_id = c.id
	o.slot = int(ctx["slot"])
	o.save_dc = (ctx["nums"]["dc"] as Breakdown).total()
	o.cell = e.spells._free_cell_near(t.cell, 1)
	o.cells = [o.cell]
	o.rules = {}
	o.keep_with(ctx["conc"] as Concentration)
	e.spells.zones.add(o, r)
	e.events.append({"type": "summon", "caster": c.id, "cell": o.cell})
	r.lines.append(e.log.add("spell", "Construct spirits gather beside %s" % t.name(), c.id))
	_constructs_act(c, ctx, t, r)
	e.spells._grant_sustained(ctx, tgt)


func _constructs_act(c: Combatant, ctx: Dictionary, t: Combatant, r: CombatResult) -> void:
	var e := enc()
	var extra := maxi(0, int(ctx["slot"]) - 3)
	if t == c or c.allied_with(t):
		var amount := int(e.dice.roll_expr("%dd6" % (1 + extra), "Construct spirits")["total"]) + int((ctx["nums"] as Dictionary).get("mod", 0))
		if t.creature.add_temp_hp(maxi(1, amount), "Conjure Constructs"):
			r.lines.append(e.log.add("heal", "The spirits shield %s: %d Temporary Hit Points" % [t.name(), maxi(1, amount)], c.id))
		return
	var only: Array[Combatant] = [t]
	e.spells._save_spell(ctx, only, r)


# --- Faerûn subclasses: shared helpers -----------------------------------------------------------------------

## The first pick of a feature's choice (the key ends with the feature id).
static func _pick(ch: Character, feature_id: String) -> String:
	for cd in ch.choice_defs:
		if cd.key.ends_with(feature_id) and not cd.picks.is_empty():
			return cd.picks[0]
	return ""


func genie_element(p: Combatant) -> String:
	if p.has_meta("genie_element"):
		return str(p.get_meta("genie_element"))
	var ch := _ch(p)
	var pick := _pick(ch, "aura_of_elemental_shielding") if ch != null else ""
	return pick if pick != "" else "fire"


func before_action(c: Combatant) -> void:
	var ch := _ch(c)
	if ch != null:
		c.set_meta("sp_before", ch.resource_left("sorcery_points"))


func after_action(c: Combatant, action: Dictionary, targets: Array = []) -> void:
	var ch := _ch(c)
	if ch == null:
		return
	var key := ActionCatalog.ability_key(action)
	var t: Combatant = targets[0] as Combatant if not targets.is_empty() and targets[0] is Combatant else null
	match key:
		"bardic_inspiration":
			if CombatFeatures.has_feature(c, "moons_inspiration"):
				c.set_meta("eclipse_window", _turn_key())
				if t != null and CombatFeatures.has_feature(c, "eventides_splendor"):
					c.set_meta("eventide_window", _turn_key())
					c.set_meta("eclipse_ally", t.id)
		"second_wind":
			_group_recovery(c)
		"action_surge":
			_rallying_surge(c)
	# Spellfire Burst: Sorcery Points spent in a Magic action or Bonus Action on its own turn.
	var cost := str(action.get("cost", ""))
	if CombatFeatures.has_feature(c, "spellfire_burst") and cost in ["action", "bonus"] and enc().current() == c \
			and ch.resource_left("sorcery_points") < int(c.get_meta("sp_before", 0)) and str(c.get_meta("burst_used", "")) != _turn_key():
		c.set_meta("burst_window", _turn_key())


func _subclass_list(c: Combatant, ch: Character, out: Array[Dictionary], tw: String) -> void:
	var e := enc()
	if str(c.get_meta("eclipse_window", "")) == _turn_key():
		out.append(_entry("inspired_eclipse", "Inspired Eclipse", "teleport 30 ft · Invisible", "free", tw, "point",
			"You just gave Bardic Inspiration: teleport up to 30 ft to a space you can see and turn Invisible until your next turn.", 30))
	if str(c.get_meta("eventide_window", "")) == _turn_key() and c.has_meta("eclipse_ally"):
		var ally := e.get_c(str(c.get_meta("eclipse_ally")))
		if ally != null:
			out.append(_entry("eventide_step", "Eventide: move %s" % ally.name(), "Reaction · teleport 30 ft", "free",
				_first(tw, "" if e.spells.can_react(ally) else "%s has no Reaction" % ally.name()), "point",
				"The creature you inspired turns Invisible and spends its Reaction to teleport up to 30 ft to the space you pick.", 60))
	if CombatFeatures.has_feature(c, "elemental_smite") and ch.resource_left("paladin_channel_divinity") > 0:
		for g: String in ["dao", "djinni", "efreeti", "marid"]:
			var armed := str(c.get_meta("genie_smite", "")) == g
			out.append(_entry("genie_smite:" + g, "Elemental Smite: %s%s" % [g.capitalize(), " (armed)" if armed else ""],
				{"dao": "grapple and restrain", "djinni": "teleport and resist", "efreeti": "2d4 Fire to two", "marid": "Str save: push and Prone"}[g],
				"free", tw, "none", "Arm it: right after your next Divine Smite, spend Channel Divinity for this genie's gift."))
	if str(c.get_meta("djinni_step", "")) == _turn_key():
		out.append(_entry("djinni_step", "Djinni's Step", "teleport 30 ft", "free", tw, "point", "The djinni's wind carries you up to 30 ft.", 30))
	if CombatFeatures.has_feature(c, "aura_of_elemental_shielding"):
		out.append(_entry("shift_element", "Elemental Shielding: %s" % genie_element(c).capitalize(), "switch element", "free",
			_first(tw, "Only as your turn starts" if c.has_meta("element_shifted") and str(c.get_meta("element_shifted")) == _turn_key() else ""), "none",
			"Switch your aura's element (Acid, Cold, Fire, Lightning, Thunder in turn)."))
	if CombatFeatures.has_feature(c, "noble_scion"):
		if not c.creature.has_flag("noble_scion"):
			out.append(_entry("noble_scion", "Noble Scion", "fly 60 ft · 10 min", "bonus", _first(e._bonus_check(c), _res_why(c, "noble_scion")), "none",
				"Bonus Action: a genie's majesty for 10 minutes: fly 60 ft and turn failed D20 Tests in your aura into successes with your Reaction."))
		if ch.resource_left("noble_scion") <= 0 and ch.slots_left(5) > 0:
			out.append(_entry("noble_scion_restore", "Restore Noble Scion", "level 5 slot", "free", tw, "none", "Spend a level 5 spell slot to restore Noble Scion."))
	if str(c.get_meta("burst_window", "")) == _turn_key():
		var honed := CombatFeatures.has_feature(c, "honed_spellfire")
		out.append(_entry("burst_flames", "Spellfire Burst: Bolstering Flames", "1d4 + %d Temporary HP" % (c.creature.ability_mod(&"cha") + (ch.class_level_of("sorcerer") if honed else 0)), "free", tw, "creature",
			"Temporary Hit Points for you or a creature you can see within 30 ft.", 30))
		out.append(_entry("burst_fire", "Spellfire Burst: Radiant Fire", "%s Radiant" % ("1d8" if honed else "1d4"), "free", tw, "enemy",
			"Radiant damage to a creature you can see within 30 ft.", 30))
	if CombatFeatures.has_feature(c, "crown_of_spellfire"):
		if c.creature.has_flag("innate_sorcery") and not c.creature.has_flag("spellfire_crown"):
			out.append(_entry("crown_of_spellfire", "Crown of Spellfire", "fly 60 ft · spells half or none", "free", _first(tw, _res_why(c, "crown_of_spellfire")), "none",
				"Crown your Innate Sorcery with spellfire until it ends."))
		if ch.resource_left("crown_of_spellfire") <= 0 and ch.resource_left("sorcery_points") >= 5:
			out.append(_entry("crown_restore", "Restore Crown of Spellfire", "5 Sorcery Points", "free", tw, "none", "Spend 5 Sorcery Points to restore Crown of Spellfire."))
	if CombatFeatures.has_feature(c, "modify_magic") and ch.resource_left("channel_divinity") > 0:
		for m: String in ["ward", "unravel"]:
			var on := str(c.get_meta("modify_magic", "")) == m
			out.append(_entry("modify_magic:" + m, "Modify Magic: %s%s" % [m.capitalize(), " (armed)" if on else ""],
				"2d8 + %d Temporary HP" % ch.class_level_of("cleric") if m == "ward" else "−1d6 on the first save made", "free", tw, "none",
				"Arm it for your next spell: spend Channel Divinity when it takes effect."))
	if CombatFeatures.has_feature(c, "dispelling_recovery"):
		if str(c.get_meta("dispel_window", "")) == _turn_key() and ch.resource_left("dispelling_recovery") > 0:
			out.append(_entry("dispelling_recovery", "Dispelling Recovery", "Dispel Magic, no slot", "free", tw, "creature",
				"Your healing spell carries a Dispel Magic: end spells on a creature within 120 ft.", 120))
		if ch.resource_left("dispelling_recovery") <= 0 and ch.resource_left("channel_divinity") > 0:
			out.append(_entry("dispelling_restore", "Restore Dispelling Recovery", "Channel Divinity", "free", tw, "none", "Spend a use of Channel Divinity to restore Dispelling Recovery."))


func _subclass_perform(c: Combatant, id: String, t: Combatant, cell: Vector2i) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if id.begins_with("genie_smite:"):
		var g := id.get_slice(":", 1)
		if str(c.get_meta("genie_smite", "")) == g:
			c.remove_meta("genie_smite")
		else:
			c.set_meta("genie_smite", g)
		return CombatResult.new()
	if id.begins_with("modify_magic:"):
		var m := id.get_slice(":", 1)
		if str(c.get_meta("modify_magic", "")) == m:
			c.remove_meta("modify_magic")
		else:
			c.set_meta("modify_magic", m)
		return CombatResult.new()
	match id:
		"inspired_eclipse":
			if str(c.get_meta("eclipse_window", "")) != _turn_key():
				return CombatResult.fail("Give Bardic Inspiration first")
			if cell.x < 0 or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose a space you can see within 30 ft")
			var r := e.feature_actions._teleport(c, cell, 30)
			if not r.ok:
				return r
			c.remove_meta("eclipse_window")
			_eclipse_veil(c, c)
			return r
		"eventide_step":
			var ally := e.get_c(str(c.get_meta("eclipse_ally", "")))
			if ally == null or not e.spells.can_react(ally):
				return CombatResult.fail("Not available")
			if cell.x < 0 or not e.can_see_space(ally, cell):
				return CombatResult.fail("Choose a space it can see within 30 ft")
			var r2 := e.feature_actions._teleport(ally, cell, 30)
			if not r2.ok:
				return r2
			ally.reaction_available = false
			c.remove_meta("eclipse_ally")
			c.remove_meta("eventide_window")
			_eclipse_veil(c, ally)
			return r2
		"djinni_step":
			if str(c.get_meta("djinni_step", "")) != _turn_key() or cell.x < 0 or not e.can_see_space(c, cell):
				return CombatResult.fail("Choose a space you can see within 30 ft")
			var r3 := e.feature_actions._teleport(c, cell, 30)
			if r3.ok:
				c.remove_meta("djinni_step")
			return r3
		"shift_element":
			var order := ["fire", "cold", "lightning", "thunder", "acid"]
			var next := str(order[(order.find(genie_element(c)) + 1) % order.size()])
			c.set_meta("genie_element", next)
			c.set_meta("element_shifted", _turn_key())
			for x in e.combatants:
				for fx: Effect in x.creature.effects.duplicate():
					if fx.stack_key == "aura:%s" % c.id:
						x.creature.remove_effect(fx)
			e.class_features.refresh_auras()
			_log("info", "%s's aura turns to %s" % [c.name(), next], c)
		"noble_scion":
			var why := e._bonus_check(c)
			if why != "":
				return CombatResult.fail(why)
			if ch.resource_left("noble_scion") <= 0:
				return CombatResult.fail("None left")
			ch.spend_resource("noble_scion")
			c.bonus_available = false
			var fx := Effect.new("Noble Scion", &"feature", "noble_scion").with_modifier("flag", {"value": "noble_scion"}) \
				.with_modifier("speed_set", {"kind": "fly", "value": 60})
			fx.lasting({"kind": "minutes", "amount": 10})
			fx.turn_owner_id = c.id
			c.creature.add_effect(fx)
			_log("info", "%s rises with a genie's majesty (Noble Scion)" % c.name(), c)
		"noble_scion_restore":
			if not ch.expend_slot(5):
				return CombatResult.fail("No level 5 slot")
			ch.restore_resource("noble_scion", 1)
		"burst_flames", "burst_fire":
			return _spellfire_burst(c, id, t)
		"crown_of_spellfire":
			if ch.resource_left("crown_of_spellfire") <= 0 or not c.creature.has_flag("innate_sorcery"):
				return CombatResult.fail("Not now")
			ch.spend_resource("crown_of_spellfire")
			var crown := Effect.new("Crown of Spellfire", &"feature", "crown_of_spellfire").with_modifier("flag", {"value": "spellfire_crown"}) \
				.with_modifier("speed_set", {"kind": "fly", "value": 60})
			for fx2: Effect in c.creature.effects:
				if fx2.source_id == "innate_sorcery":
					crown.ends = fx2.ends
					crown.rounds_left = fx2.rounds_left
					crown.turn_owner_id = fx2.turn_owner_id
			c.creature.add_effect(crown)
			_log("info", "A crown of spellfire blazes over %s" % c.name(), c)
		"crown_restore":
			if not ch.spend_resource("sorcery_points", 5):
				return CombatResult.fail("Not enough Sorcery Points")
			ch.restore_resource("crown_of_spellfire", 1)
		"dispelling_recovery":
			return _dispelling_recovery(c, t)
		"dispelling_restore":
			if not ch.spend_resource("channel_divinity"):
				return CombatResult.fail("No Channel Divinity left")
			ch.restore_resource("dispelling_recovery", 1)
		_:
			return CombatResult.fail("Not available")
	return CombatResult.new()


# --- College of the Moon ----------------------------------------------------------------------------------

func _eclipse_veil(bard: Combatant, t: Combatant) -> void:
	var fx := Effect.new("Inspired Eclipse", &"feature", "inspired_eclipse").with_condition(&"invisible")
	fx.caster_id = bard.id
	fx.ends = Effect.Ends.START_OF_TURN
	fx.turn_owner_id = t.id
	fx.ends_on = ["attack_roll", "deal_damage", "cast_spell"]
	t.creature.add_effect(fx)
	_log("info", "%s fades into moonshadow (Invisible)" % t.name(), t)


## Lunar Vitality: once per turn, a Bardic Inspiration die (or 1d6 at level 14) more on a spell's healing, and
## +10 ft Speed for the healed creature.
func spell_healing(ctx: Dictionary, t: Combatant) -> int:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	if ch == null or not CombatFeatures.has_feature(c, "moons_inspiration") or not allowed(c, "moons_inspiration"):
		return 0
	var free := CombatFeatures.has_feature(c, "eventides_splendor")
	if not free and ch.resource_left("bardic_inspiration") <= 0:
		return 0
	if not _once_per_turn(c, "lunar_vitality_turn"):
		return 0
	var die := 6 if free else ClassFeatures.bardic_die(c)
	if not free:
		ch.spend_resource("bardic_inspiration")
	var roll := enc().dice.roll_one(die, "Lunar Vitality")
	var fx := Effect.new("Lunar Vitality", &"feature", "lunar_vitality").with_modifier("speed", {"value": 10})
	fx.ends = Effect.Ends.END_OF_TURN
	fx.turn_owner_id = t.id
	fx.skip_turn_ends = enc().own_turn_skip(t)
	t.creature.add_effect(fx)
	_log("heal", "Moonlight swells the healing: +%d (Lunar Vitality)" % roll, c)
	return roll


## Blessing of Moonlight: each failed save against the blessed Moonbeam heals the most hurt ally within 60 ft.
func zone_failed_save(o: FieldObject, t: Combatant) -> void:
	var e := enc()
	var bard := e.get_c(o.caster_id)
	if o.spell_id == "moonbeam" and bard != null and bool(bard.get_meta("bless_moonbeam", false)):
		o.rules["blessed"] = true
	if not bool(o.rules.get("blessed", false)):
		return
	if bard == null:
		return
	var best: Combatant = null
	for a: Combatant in e.allies_of(bard) + [bard]:
		if a == t or not a.is_alive() or a.creature.hp >= a.creature.max_hp() or e.distance(bard, a) > 60 or not e.can_see(bard, a):
			continue
		if best == null or a.creature.hp * best.creature.max_hp() < best.creature.hp * a.creature.max_hp():
			best = a
	if best == null:
		return
	var got := best.creature.heal(int(e.dice.roll_expr("2d4", "Blessing of Moonlight")["total"]), "Blessing of Moonlight")
	_log("heal", "Moonlight mends %s: +%d Hit Points (Blessing of Moonlight)" % [best.name(), got], bard)
	e.events.append({"type": "heal", "id": best.id, "amount": got})


# --- Banneret ---------------------------------------------------------------------------------------------

func _rally_reach(c: Combatant) -> int:
	return 60 if CombatFeatures.has_feature(c, "banneret_bolstered_rally") else 30


func _group_recovery(c: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	if not CombatFeatures.has_feature(c, "banneret_group_recovery") or ch.resource_left("banneret_group_recovery") <= 0 or not allowed(c, "banneret_group_recovery"):
		return
	var hurt: Array[Combatant] = []
	for a in e.allies_of(c):
		if a != c and a.is_alive() and a.creature.hp < a.creature.max_hp() and e.distance(c, a) <= _rally_reach(c):
			hurt.append(a)
	if hurt.is_empty():
		return
	hurt.sort_custom(func(x: Combatant, y: Combatant) -> bool: return x.creature.hp * y.creature.max_hp() < y.creature.hp * x.creature.max_hp())
	ch.spend_resource("banneret_group_recovery")
	var n := maxi(1, c.creature.ability_mod(&"cha"))
	for a: Combatant in hurt.slice(0, n):
		var got := a.creature.heal(e.dice.roll_one(4, "Group Recovery") + ch.class_level_of("fighter"), "Group Recovery")
		_log("heal", "%s rallies %s: +%d Hit Points (Group Recovery)" % [c.name(), a.name(), got], c)
		e.events.append({"type": "heal", "id": a.id, "amount": got})
		if CombatFeatures.has_feature(c, "banneret_team_tactics"):
			var fx := Effect.new("Team Tactics", &"feature", "banneret_team_tactics").with_modifier("advantage", {"on": ["attack", "save:all", "check:all"]})
			fx.caster_id = c.id
			fx.ends = Effect.Ends.START_OF_TURN
			fx.turn_owner_id = c.id
			a.creature.add_effect(fx)


func _rallying_surge(c: Combatant) -> void:
	var e := enc()
	if not CombatFeatures.has_feature(c, "banneret_rallying_surge") or not allowed(c, "banneret_rallying_surge"):
		return
	var n := maxi(1, c.creature.ability_mod(&"cha"))
	var done := 0
	for a in e.allies_of(c):
		if done >= n:
			break
		if a == c or not a.is_alive() or not a.can_act() or e.distance(c, a) > _rally_reach(c) or not e.spells.can_react(a):
			continue
		var foe: Combatant = null
		for h in e.hostiles_of(a):
			if h.is_alive() and not h.is_down() and not e.best_melee_option(a, h).is_empty() and (foe == null or e.distance(a, h) < e.distance(a, foe)):
				foe = h
		if foe == null:
			continue
		done += 1
		_log("reaction", "%s answers %s's rallying surge" % [a.name(), c.name()], a)
		e._opportunity_attack(a, foe)


func _shared_resilience(c: Combatant, t: D20Test) -> void:
	var e := enc()
	if t.success or t.kind != D20Test.Kind.SAVING_THROW or t.target <= 0:
		return
	for h in e.combatants:
		var hc := _ch(h)
		if h == c or hc == null or not CombatFeatures.has_feature(h, "banneret_shared_resilience") or not h.allied_with(c):
			continue
		if str(h.reaction_rules.get("banneret_shared_resilience", "never")) != "auto" or hc.resource_left("indomitable") <= 0:
			continue
		if not e.spells.can_react(h) or e.distance(h, c) > 60 or not e.can_see(h, c):
			continue
		hc.spend_resource("indomitable")
		h.reaction_available = false
		var again := D20Test.roll(e.dice, t.kind, t.modifier + hc.class_level_of("fighter"), t.target, 0, 0, "Shared Resilience", t.crit_range)
		t.set_natural(again.kept, "Shared Resilience")
		t.add_bonus(hc.class_level_of("fighter"), "Shared Resilience")
		_log("reaction", "%s lends %s their resolve (Shared Resilience)" % [h.name(), c.name()], h, [t.describe()])
		return


# --- Oath of the Noble Genies -------------------------------------------------------------------------------

func _elemental_smite(c: Combatant, target: Combatant) -> void:
	var e := enc()
	var ch := _ch(c)
	var g := str(c.get_meta("genie_smite", ""))
	if g == "" or ch == null or ch.resource_left("paladin_channel_divinity") <= 0:
		return
	ch.spend_resource("paladin_channel_divinity")
	c.remove_meta("genie_smite")
	var dc := e.class_features._spell_dc(c, "paladin")
	match g:
		"dao":
			if target.is_alive() and not target.creature.is_condition_immune(&"grappled"):
				target.creature.add_condition(&"grappled", c.name())
				e.grapples[target.id] = c.id
				var fx := Effect.new("Dao's Grip", &"feature", "elemental_smite").with_condition(&"restrained")
				fx.caster_id = c.id
				fx.data["while_grappled_by"] = c.id
				target.creature.add_effect(fx)
				_log("condition", "Stone grips %s: Grappled and Restrained (escape DC %d)" % [target.name(), dc], c)
		"djinni":
			var fx2 := Effect.new("Djinni's Wind", &"feature", "elemental_smite")
			for ty: String in ["bludgeoning", "piercing", "slashing"]:
				fx2.with_modifier("resistance", {"value": ty})
			for cond: String in ["grappled", "prone", "restrained"]:
				fx2.with_modifier("condition_immunity", {"value": cond})
			fx2.ends = Effect.Ends.END_OF_TURN
			fx2.turn_owner_id = c.id
			fx2.skip_turn_ends = e.own_turn_skip(c)
			c.creature.add_effect(fx2)
			c.set_meta("djinni_step", _turn_key())
			_log("info", "A djinni's wind lifts %s (resists weapons; teleport from the hotbar)" % c.name(), c)
		"efreeti":
			var hit := [target]
			var other: Combatant = null
			for h in e.hostiles_of(c):
				if h != target and h.is_alive() and e.distance(c, h) <= 30 and e.can_see(c, h) and (other == null or e.distance(c, h) < e.distance(c, other)):
					other = h
			if other != null:
				hit.append(other)
			for x: Combatant in hit:
				var rolled := e._roll_damage_dice("2d4", false, 0, "Efreeti's Fire")
				e.deal_damage(c, x, [{"amount": int(rolled["total"]), "type": "fire"}], false, "Efreeti's Fire", [str(rolled["text"])])
		"marid":
			var pushed := [target]
			for h in e.hostiles_of(c):
				if h != target and h.is_alive() and e.distance(c, h) <= 10:
					pushed.append(h)
			for x: Combatant in pushed:
				if not e.class_features._save(x, &"str", dc, "Marid's Wave"):
					e.forced_move(x, e.center_of(c), 15)
					x.creature.add_condition(&"prone", "Marid's Wave")
					_log("condition", "A wave throws %s back and down" % x.name(), x)


func _noble_scion_save(c: Combatant, t: D20Test) -> void:
	var e := enc()
	if t.success or t.target <= 0:
		return
	for p in e.combatants:
		if not p.creature.has_flag("noble_scion") or not (p == c or p.allied_with(c)) or e.distance(p, c) > (30 if CombatFeatures.has_feature(p, "aura_expansion") else 10):
			continue
		if str(p.reaction_rules.get("noble_scion", "never")) != "auto" or not e.spells.can_react(p):
			continue
		p.reaction_available = false
		t.add_bonus(maxi(0, t.target - t.total), "Noble Scion")
		_log("reaction", "%s's majesty turns the failure into a success (Noble Scion)" % p.name(), p)
		return


# --- Scion of the Three -------------------------------------------------------------------------------------

func _bloodthirst(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if ch.resource_left("scion_bloodthirst") <= 0 or not e.spells.can_react(c):
		return CombatResult.new()
	var dest := Vector2i(-1, -1)
	var best := 1 << 30
	for dx in range(-1, t.size_cells + 1):
		for dy in range(-1, t.size_cells + 1):
			var cell := t.cell + Vector2i(dx, dy)
			if not e.grid.in_bounds(cell) or e.grid.is_solid(cell) or e.occupant_at(cell) != null or not e.can_see_space(c, cell):
				continue
			var d := e.grid.distance_ft(c.cell, 1, cell, 1)
			if d < best:
				best = d
				dest = cell
	if dest.x < 0:
		return CombatResult.new()
	ch.spend_resource("scion_bloodthirst")
	var from := c.cell
	var r := CombatResult.new()
	e.spells._teleport(c, dest, r)
	_log("reaction", "%s scents blood and appears beside %s (Bloodthirst)" % [c.name(), t.name()], c)
	if CombatFeatures.has_feature(c, "aura_of_malevolence"):
		_malevolence(c, from)
	return e._opportunity_attack(c, t)


func _malevolence(c: Combatant, _from: Vector2i) -> void:
	var e := enc()
	var ch := _ch(c)
	var ty := {"bane": "psychic", "bhaal": "poison", "myrkul": "necrotic"}.get(_pick(ch, "dread_allegiance"), "psychic") as String
	var dmg := maxi(1, c.creature.ability_mod(&"int"))
	for h in e.hostiles_of(c):
		if h.is_alive() and e.distance(c, h) <= 10:
			e.deal_damage(c, h, [{"amount": dmg, "type": ty, "ignore_resistance": true, "ignore_source": "Aura of Malevolence"}], false, "Aura of Malevolence")


# --- Spellfire Sorcery --------------------------------------------------------------------------------------

func _spellfire_burst(c: Combatant, id: String, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if str(c.get_meta("burst_window", "")) != _turn_key():
		return CombatResult.fail("Spend Sorcery Points in an action first")
	if t == null or e.distance(c, t) > 30 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 30 ft")
	c.remove_meta("burst_window")
	c.set_meta("burst_used", _turn_key())
	var honed := CombatFeatures.has_feature(c, "honed_spellfire")
	if id == "burst_flames":
		var amount := e.dice.roll_one(4, "Bolstering Flames") + maxi(0, c.creature.ability_mod(&"cha")) + (ch.class_level_of("sorcerer") if honed else 0)
		if t.creature.add_temp_hp(amount, "Bolstering Flames"):
			_log("heal", "Spellfire wraps %s: %d Temporary Hit Points (Bolstering Flames)" % [t.name(), amount], c)
	else:
		var rolled := e._roll_damage_dice("1d8" if honed else "1d4", false, 0, "Radiant Fire")
		e.deal_damage(c, t, [{"amount": int(rolled["total"]), "type": "radiant", "spell": true}], false, "Radiant Fire", [str(rolled["text"])])
	return CombatResult.new()


# --- Arcana Domain ------------------------------------------------------------------------------------------

## Modify Magic, armed: a Ward for an ally the spell targets; Unravel for the first successful save against it.
func before_resolve(ctx: Dictionary) -> void:
	var c := ctx["c"] as Combatant
	var ch := _ch(c)
	# Blessing of Moonlight: decided as the Moonbeam is cast, so its first save already counts.
	if ch != null and str((ctx["s"] as Dictionary).get("id", "")) == "moonbeam" and CombatFeatures.has_feature(c, "blessing_of_moonlight") \
			and ch.resource_left("blessing_of_moonlight") > 0 and allowed(c, "blessing_of_moonlight"):
		ch.spend_resource("blessing_of_moonlight")
		c.set_meta("bless_moonbeam", true)
		enc().spells._light(ctx, c, {"bright": 0, "dim": 5})
		_log("info", "%s blesses the Moonbeam" % c.name(), c)
	var m := str(c.get_meta("modify_magic", ""))
	if ch == null or m == "" or ch.resource_left("channel_divinity") <= 0:
		return
	if m == "ward":
		for t: Combatant in ctx.get("targets", []):
			if t == c or c.allied_with(t):
				ch.spend_resource("channel_divinity")
				c.remove_meta("modify_magic")
				var amount := int(enc().dice.roll_expr("2d8", "Modify Magic")["total"]) + ch.class_level_of("cleric")
				t.creature.add_temp_hp(amount, "Modify Magic")
				_log("heal", "%s's spell shields %s: %d Temporary Hit Points (Modify Magic)" % [c.name(), t.name(), amount], c)
				return
	elif m == "unravel" and (ctx["s"] as Dictionary).has("save"):
		c.set_meta("unravel_live", true)


func _unravel(c: Combatant, t: D20Test, keys: Array[String]) -> void:
	var e := enc()
	if not t.success or t.kind != D20Test.Kind.SAVING_THROW:
		return
	for k in keys:
		if not k.begins_with("save_vs:spell:"):
			continue
		var caster := e.get_c(k.substr(14))
		var cch := _ch(caster)
		if caster == null or cch == null or not bool(caster.get_meta("unravel_live", false)) or cch.resource_left("channel_divinity") <= 0:
			continue
		if not e.can_see(caster, c):
			continue
		caster.remove_meta("unravel_live")
		caster.remove_meta("modify_magic")
		cch.spend_resource("channel_divinity")
		t.add_bonus(-e.dice.roll_one(6, "Modify Magic"), "Modify Magic")
		_log("info", "%s unravels %s's resistance (Modify Magic)" % [caster.name(), c.name()], caster, [t.describe()])
		return


func _subclass_after_cast(c: Combatant, ch: Character, s: Dictionary, slot: int, free: bool, _ctx: Dictionary) -> void:
	c.remove_meta("unravel_live")
	if str(s.get("id", "")) == "moonbeam" and bool(c.get_meta("bless_moonbeam", false)):
		var o := enc().spells.zones.object_of(c.id, "moonbeam")
		if o != null:
			o.rules["blessed"] = true
		c.remove_meta("bless_moonbeam")
	# Dispelling Recovery: a slotted spell that heals or ends a condition opens a free Dispel Magic.
	if CombatFeatures.has_feature(c, "dispelling_recovery") and not free and slot > 0:
		var heals := s.has("heal") or "healing" in (s.get("tags", []) as Array) \
			or (s.get("effects", []) as Array).any(func(x: Variant) -> bool: return str((x as Dictionary).get("effect", "")) == "end_condition")
		if heals:
			c.set_meta("dispel_window", _turn_key())


func _dispelling_recovery(c: Combatant, t: Combatant) -> CombatResult:
	var e := enc()
	var ch := _ch(c)
	if str(c.get_meta("dispel_window", "")) != _turn_key() or ch.resource_left("dispelling_recovery") <= 0:
		return CombatResult.fail("Not now")
	if t == null or e.distance(c, t) > 120 or not e.can_see(c, t):
		return CombatResult.fail("Choose a creature you can see within 120 ft")
	ch.spend_resource("dispelling_recovery")
	c.remove_meta("dispel_window")
	var s := Compendium.shared().spell_data("dispel_magic")
	var entry := e.spells._entry_any(c, "dispel_magic")
	var ctx := {"c": c, "s": s, "slot": 3, "nums": e.spells.numbers(c, entry if not entry.is_empty() else {"class_id": "cleric"}),
		"conc": null, "opts": {}, "choice": "", "point": Vector2.INF}
	var r := CombatResult.new()
	e.events.append({"type": "spell", "caster": c.id, "spell": "dispel_magic", "cells": [], "targets": [t.id]})
	e.spells._dispel(ctx, t, r)
	return r


# --- Attacks against you: Elemental Rebuke, Crown of Spellfire ----------------------------------------------

func _subclass_against_damage(target: Combatant, source: Combatant, total: Callable, cut: Callable, out: Array) -> void:
	var e := enc()
	var tc := _ch(target)
	if tc == null:
		return
	if CombatFeatures.has_feature(target, "elemental_rebuke") and tc.resource_left("elemental_rebuke") > 0 and e.spells.can_react(target) and int(total.call()) > 0:
		out.append({"kind": "elemental_rebuke", "reactor": target, "trigger": source.id, "title": "Reaction: Elemental Rebuke?",
			"text": "%s hits %s for %d. Halve it, and %s makes a Dexterity save against your elements?" % [source.name(), target.name(), int(total.call()), source.name()],
			"cost": "Reaction and a use of Elemental Rebuke",
			"still": func() -> bool: return tc.resource_left("elemental_rebuke") > 0 and e.spells.can_react(target) and int(total.call()) > 0,
			"use": func() -> void:
				tc.spend_resource("elemental_rebuke")
				target.reaction_available = false
				cut.call(int(total.call()) - int(total.call()) / 2, "Elemental Rebuke")
				var dc := e.class_features._spell_dc(target, "paladin")
				var rolled := e._roll_damage_dice("2d10+%d" % maxi(0, target.creature.ability_mod(&"cha")), false, 0, "Elemental Rebuke")
				var ok := e.class_features._save(source, &"dex", dc, "Elemental Rebuke")
				var amt := int(rolled["total"]) / 2 if ok else int(rolled["total"])
				e.deal_damage(target, source, [{"amount": amt, "type": genie_element(target)}], false, "Elemental Rebuke", [str(rolled["text"])])})
	if target.creature.has_flag("spellfire_crown") and int(total.call()) > 0 and str(target.get_meta("crown_hd_turn", "")) != _turn_key():
		out.append({"kind": "crown_of_spellfire", "reactor": target, "trigger": source.id, "title": "Crown of Spellfire?",
			"text": "%s hits %s for %d. Spend Hit Point Dice (up to %d) to burn the damage away?" % [source.name(), target.name(), int(total.call()), maxi(1, target.creature.ability_mod(&"cha"))],
			"cost": "Hit Point Dice", "spends_reaction": false,
			"still": func() -> bool: return int(total.call()) > 0,
			"use": func() -> void:
				target.set_meta("crown_hd_turn", _turn_key())
				var left := int(total.call())
				var cutn := 0
				for i in maxi(1, target.creature.ability_mod(&"cha")):
					if cutn >= left:
						break
					var r1 := _spend_hit_dice(tc, 1, "Crown of Spellfire")
					if r1 <= 0:
						break
					cutn += r1
				cut.call(mini(cutn, left), "Crown of Spellfire")})

