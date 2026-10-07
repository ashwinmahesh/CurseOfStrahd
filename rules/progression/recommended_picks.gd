class_name RecommendedPicks
extends RefCounted
## Recommended picks on level up (Q10, plan §5.6 "Level up"): a sensible pick for everything a level asks for, which the
## player changes as before. A companion follows their own level plan (data/pregens `level_plan`) where it still fits;
## anyone else gets their class's favourites (data/classes `recommended`: subclass, feats) and the rankings below. They
## only rank what ChoiceOptions offers, so a recommendation is always a legal pick. Pure rules: no nodes or autoloads.

## Spells worth having, best first within each level. Favourites come before the rest, the highest level first, so a
## level 5 Wizard's two new spellbook spells are Fireball and Counterspell and a Cleric's new prepared spells are Spirit
## Guardians and Revivify. Daylight and Sunbeam rank high: Barovia is full of vampires.
const SPELLS: Array[String] = [
	"eldritch_blast", "fire_bolt", "toll_the_dead", "sacred_flame", "mind_sliver", "guidance", "shillelagh", "starry_wisp",
	"sorcerous_burst", "ray_of_frost", "vicious_mockery", "produce_flame", "thorn_whip", "booming_blade", "green_flame_blade",
	"light", "mage_hand", "prestidigitation", "minor_illusion", "message", "thaumaturgy", "spare_the_dying", "true_strike",
	"druidcraft", "shocking_grasp", "chill_touch", "word_of_radiance", "elementalism", "thunderclap", "resistance", "mending",
	"shield", "healing_word", "bless", "magic_missile", "guiding_bolt", "faerie_fire", "hunters_mark", "hex", "cure_wounds",
	"command", "sleep", "find_familiar", "mage_armor", "protection_from_evil_and_good", "divine_smite", "shield_of_faith",
	"detect_magic", "thunderwave", "sanctuary", "dissonant_whispers", "tashas_hideous_laughter", "entangle", "goodberry",
	"armor_of_agathys", "chromatic_orb", "burning_hands", "ensnaring_strike", "heroism", "hellish_rebuke", "identify",
	"feather_fall", "fog_cloud", "ice_knife", "searing_smite", "wrathful_smite", "silent_image", "disguise_self",
	"charm_person", "expeditious_retreat", "longstrider", "inflict_wounds", "false_life", "bane", "divine_favor",
	"misty_step", "spiritual_weapon", "hold_person", "web", "shatter", "aid", "lesser_restoration", "moonbeam",
	"pass_without_trace", "scorching_ray", "invisibility", "mirror_image", "blur", "suggestion", "heat_metal", "spike_growth",
	"silence", "darkvision", "see_invisibility", "shining_smite", "summon_beast", "flaming_sphere", "cloud_of_daggers",
	"magic_weapon", "enhance_ability", "find_steed", "prayer_of_healing", "barkskin", "mind_spike", "warding_bond",
	"detect_thoughts", "knock", "levitate", "spider_climb", "calm_emotions", "darkness",
	"spirit_guardians", "fireball", "counterspell", "hypnotic_pattern", "haste", "revivify", "daylight", "dispel_magic",
	"mass_healing_word", "call_lightning", "conjure_animals", "fly", "slow", "remove_curse", "lightning_bolt",
	"summon_undead", "summon_fey", "crusaders_mantle", "aura_of_vitality", "blinding_smite", "protection_from_energy",
	"beacon_of_hope", "conjure_barrage", "lightning_arrow", "elemental_weapon", "vampiric_touch", "glyph_of_warding",
	"leomunds_tiny_hut", "speak_with_dead", "sending", "tongues", "clairvoyance", "sleet_storm", "stinking_cloud", "blink",
	"fear", "plant_growth", "wind_wall", "magic_circle", "bestow_curse", "major_image", "gaseous_form", "hunger_of_hadar",
	"polymorph", "banishment", "greater_invisibility", "dimension_door", "death_ward", "guardian_of_faith", "wall_of_fire",
	"aura_of_purity", "aura_of_life", "freedom_of_movement", "summon_elemental", "summon_construct", "summon_aberration",
	"conjure_minor_elementals", "conjure_woodland_beings", "fire_shield", "otilukes_resilient_sphere", "ice_storm",
	"phantasmal_killer", "confusion", "evards_black_tentacles", "stoneskin", "grasping_vine", "staggering_smite",
	"fount_of_moonlight", "charm_monster", "dominate_beast", "blight", "arcane_eye", "divination", "locate_creature",
	"wall_of_force", "hold_monster", "synaptic_static", "greater_restoration", "raise_dead", "mass_cure_wounds",
	"animate_objects", "cone_of_cold", "bigbys_hand", "steel_wind_strike", "circle_of_power", "destructive_wave",
	"banishing_smite", "dispel_evil_and_good", "summon_celestial", "summon_dragon", "flame_strike", "telekinesis",
	"insect_plague", "wall_of_stone", "dominate_person", "conjure_elemental", "cloudkill", "swift_quiver", "scrying",
	"tree_stride", "teleportation_circle", "commune", "legend_lore",
	"sunbeam", "heal", "heroes_feast", "blade_barrier", "true_seeing", "chain_lightning", "disintegrate",
	"globe_of_invulnerability", "mass_suggestion", "otilukes_freezing_sphere", "wall_of_ice", "harm", "eyebite",
	"circle_of_death", "find_the_path", "word_of_recall", "wind_walk", "conjure_fey", "summon_fiend", "wall_of_thorns"]

## Inline options, best first: Eldritch Invocations, Battle Master maneuvers, Metamagic, and class options (a Cleric's
## Divine Order and Blessed Strikes, a Druid's Primal Order and Elemental Fury, a Hunter's prey, a Circle of the Land's
## land: Barovia is temperate forest).
const OPTIONS: Array[String] = [
	"pact_of_the_tome", "agonizing_blast", "devils_sight", "repelling_blast", "eldritch_mind", "armor_of_shadows",
	"misty_visions", "mask_of_many_faces", "lessons_of_the_first_ones", "one_with_shadows", "gift_of_the_protectors",
	"otherworldly_leap", "pact_of_the_chain", "pact_of_the_blade", "thirsting_blade", "eldritch_smite", "lifedrinker",
	"fiendish_vigor", "ascendant_step", "whispers_of_the_grave", "witch_sight", "eldritch_spear",
	"precision_attack", "trip_attack", "riposte", "menacing_attack", "commanders_strike", "pushing_attack", "goading_attack",
	"disarming_attack", "parry", "rally", "evasive_footwork", "feinting_attack", "lunging_attack", "sweeping_attack",
	"distracting_strike", "maneuvering_attack", "tactical_assessment", "commanding_presence", "ambush", "bait_and_switch",
	"quickened_spell", "twinned_spell", "careful_spell", "heightened_spell", "subtle_spell", "empowered_spell",
	"extended_spell", "distant_spell", "seeking_spell", "transmuted_spell",
	"protector", "warden", "potent_spellcasting", "divine_strike", "primal_strike", "thaumaturge", "magician",
	"colossus_slayer", "horde_breaker", "multiattack_defense", "escape_the_horde", "temperate"]

## Feats after the class's own favourites (ability score increases come first while the main ability is under 20).
const FEATS: Array[String] = ["alert", "tough", "resilient", "war_caster", "lucky", "sentinel", "great_weapon_master",
	"polearm_master", "sharpshooter", "crossbow_expert", "fey_touched", "shadow_touched", "skill_expert", "mage_slayer",
	"heavy_armor_master", "inspiring_leader", "durable", "speedy", "observant", "savage_attacker", "healer", "skilled",
	"boon_of_combat_prowess", "boon_of_fate", "boon_of_irresistible_offense", "boon_of_fortitude", "boon_of_spell_recall"]

## Skills for proficiency and Expertise after the class's own list.
const SKILLS: Array[String] = ["perception", "stealth", "insight", "persuasion", "athletics", "investigation", "arcana",
	"deception", "acrobatics", "survival", "medicine", "religion", "sleight_of_hand", "history", "nature", "intimidation",
	"animal_handling", "performance"]

## Weapon Mastery after the weapons the character carries.
const WEAPONS: Array[String] = ["longsword", "greatsword", "rapier", "shortsword", "longbow", "shortbow", "handaxe",
	"javelin", "dagger", "glaive", "halberd", "warhammer", "battleaxe", "flail", "maul", "morningstar", "heavy_crossbow",
	"light_crossbow", "spear", "quarterstaff", "scimitar", "mace", "greataxe", "war_pick", "trident", "whip", "pike"]

const NEVER := 1000000.0
## Options named after an ability (a Gloom Stalker's or a Knowledge Domain's pick).
const ABILITY_WORDS := {"strength": "str", "dexterity": "dex", "constitution": "con", "intelligence": "int", "wisdom": "wis",
	"charisma": "cha"}


## The level `ch` is about to gain in `class_id`, as their own pregen level plan has it ({} if they have none, it's
## for another class, or it stops sooner): {level, class, choices: {key: picks}}.
static func plan_step(ch: Character, class_id: String) -> Dictionary:
	var pregen := ch.compendium.get_entry("pregens", ch.id)
	for s: Variant in pregen.get("level_plan", []):
		var step := s as Dictionary
		if int(step.get("level", 0)) == ch.character_level() + 1:
			return step if str(step.get("class", "")) == class_id else {}
	return {}


## Up to `c.remaining()` new picks for `c` (populated against `ch`, the character as the level would leave them),
## best first; `class_id` is the class being advanced. Empty when nothing legal is left to pick.
static func pick(c: Choice, ch: Character, class_id: String) -> Array[String]:
	var need := c.remaining()
	if need <= 0:
		return []
	if c.kind == "ability_increase":
		return _increases(c, ch, class_id, need)
	var scored: Array[Array] = []
	for i in c.options.size():
		var o := c.options[i]
		if not o.legal or o.id in c.picks:
			continue
		var s := _score(c, o, ch, class_id)
		if s >= NEVER:
			continue
		# Weak picks (a spell already known from elsewhere, a skill already had) only when nothing else is left.
		if o.warning != "":
			s += NEVER / 2.0
		scored.append([s, i, o.id])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and int(a[1]) < int(b[1])))
	var out: Array[String] = []
	for row: Array in scored.slice(0, need):
		out.append(str(row[2]))
	return out


## Lower is better. Ranks by kind; anything unranked keeps its place in the options after the ranked ones.
static func _score(c: Choice, o: ChoiceOption, ch: Character, class_id: String) -> float:
	var rec := ch.compendium.class_data(class_id).get("recommended", {}) as Dictionary
	match c.kind:
		"subclass":
			return 0.0 if o.id == str(rec.get("subclass", "")) else 100.0
		"feat", "fighting_style":
			if o.id == "ability_score_improvement":
				return 0.0 if ch.ability_score(StringName(ability_order(ch, class_id)[0])) < 20 else 60.0
			var style := _style_rank(o.id, ch)
			if style >= 0:
				return 10.0 + style
			# A feat whose ability increase has nowhere to go (Sharpshooter with Dexterity at 20) would leave a pick empty.
			var raise := ch.compendium.get_entry("feats", o.id).get("ability_increase", {}) as Dictionary
			if not raise.is_empty() and not (raise.get("from", []) as Array).any(func(a: Variant) -> bool:
					return ch.ability_score(StringName(str(a))) < int(raise.get("max", 20))):
				return NEVER
			var own := (rec.get("feats", []) as Array).find(o.id)
			if own >= 0:
				return 20.0 + own
			var any := FEATS.find(o.id)
			return 100.0 + any if any >= 0 else 1000.0
		"cantrip", "spell", "spellbook":
			var level := int(o.data.get("level", ch.compendium.spell_data(o.id).get("level", 0)))
			var fav := SPELLS.find(o.id)
			return (0.0 if fav >= 0 else 100000.0) + (9 - level) * 1000.0 + (fav if fav >= 0 else 500)
		"invocation", "maneuver", "metamagic", "option":
			if ABILITY_WORDS.has(o.id):
				return 10.0 + ability_order(ch, class_id).find(str(ABILITY_WORDS[o.id]))
			var at := OPTIONS.find(o.id)
			return at if at >= 0 else 1000.0
		"skill", "expertise":
			var own_skill := (rec.get("skills", []) as Array).find(o.id)
			if own_skill >= 0:
				return own_skill
			var skill := SKILLS.find(o.id)
			return 50.0 + skill if skill >= 0 else 1000.0
		"weapon_mastery":
			for slot: String in ["main_hand", "off_hand"]:
				if str(ch.equipped(slot).get("id", "")) == o.id:
					return 0.0
			if not ch.entry_of(o.id).is_empty():
				return 10.0
			var w := WEAPONS.find(o.id)
			return 100.0 + w if w >= 0 else 1000.0
		"beast_form":
			# The strongest forms first.
			return 100.0 - float(ch.compendium.monster_data(o.id).get("cr", 0)) * 10.0
		"language":
			return 100.0 if "rare" in o.tags else 0.0
		"spellcasting_ability":
			return ability_order(ch, class_id).find(o.id)
	return 1000.0


## A Fighting Style that suits the character's weapons, or -1 for any other option: Archery with a bow, Great Weapon
## Fighting with a two-handed weapon, Defense in armor with a Shield, Two-Weapon Fighting with two light weapons, else
## Dueling or Defense.
static func _style_rank(id: String, ch: Character) -> int:
	var main := ch.equipped("main_hand")
	var off := ch.equipped("off_hand")
	var order: Array[String] = []
	if Gear.is_weapon(main) and Gear.is_ranged_weapon(main):
		order = ["archery", "defense"]
	elif Gear.is_weapon(main) and "two_handed" in Gear.weapon_props(main):
		order = ["great_weapon_fighting", "defense"]
	elif Gear.is_weapon(off):
		order = ["two_weapon_fighting", "defense", "dueling"]
	elif Gear.is_shield(off):
		order = ["defense", "dueling", "protection"]
	else:
		order = ["defense", "dueling", "archery", "great_weapon_fighting"]
	return order.find(id)


## The abilities in the order this class wants them for this character: its main abilities (the higher first, so a
## Dexterity Fighter puts Dexterity first), then Constitution, then the rest as the class's recommended array has them.
static func ability_order(ch: Character, class_id: String) -> Array[String]:
	var data := ch.compendium.class_data(class_id)
	var mains: Array[String] = []
	for a: Variant in data.get("primary_abilities", []):
		mains.append(str(a))
	mains.sort_custom(func(a: String, b: String) -> bool: return ch.ability_score(StringName(a)) > ch.ability_score(StringName(b)))
	var out: Array[String] = mains.duplicate()
	if not "con" in out:
		out.append("con")
	var arr := (data.get("recommended", {}) as Dictionary).get("standard_array", {}) as Dictionary
	var rest: Array[String] = []
	for a: StringName in Abilities.ALL:
		if not str(a) in out:
			rest.append(str(a))
	rest.sort_custom(func(a: String, b: String) -> bool: return int(arr.get(a, 0)) > int(arr.get(b, 0)))
	out.append_array(rest)
	return out


## Ability score increases: every way to place the points among the abilities the choice allows, scored by the
## modifiers they raise, weighted by how much the class wants each ability (an odd score's +1 counts; a +1 that changes
## no modifier still leans toward the main ability).
static func _increases(c: Choice, ch: Character, class_id: String, need: int) -> Array[String]:
	var order := ability_order(ch, class_id)
	var allowed: Array[String] = []
	for a in order:
		var o := c.option(a)
		if o != null and o.legal:
			allowed.append(a)
	var best: Array[String] = []
	var best_value := -1.0
	for combo: Array in _combos(allowed, need):
		var value := 0.0
		var ok := true
		for a in allowed:
			var add := combo.count(a)
			if add == 0:
				continue
			var have := ch.ability_score(StringName(a))
			if add + c.picks.count(a) > c.per_ability or have + add > c.max_score:
				ok = false
				break
			var weight := pow(2.0, float(order.size() - order.find(a)))
			value += weight * (floori((have + add - 10) / 2.0) - floori((have - 10) / 2.0)) * 10.0 + weight * add
		if ok and value > best_value:
			best_value = value
			best.assign(combo)
	return best


## Every multiset of `n` abilities from `pool`, in pool order.
static func _combos(pool: Array[String], n: int, start: int = 0) -> Array[Array]:
	var out: Array[Array] = []
	if n == 0:
		out.append([] as Array[String])
		return out
	for i in range(start, pool.size()):
		for rest: Array in _combos(pool, n - 1, i):
			var combo: Array[String] = [pool[i]]
			for r: Variant in rest:
				combo.append(str(r))
			out.append(combo)
	return out
