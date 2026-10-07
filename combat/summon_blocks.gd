class_name SummonBlocks
extends RefCounted
## Stat blocks for creatures spells call up (2024 PHB): the Fey Spirit (Summon Fey) and the Undead Spirit (Summon
## Undead), whose numbers grow with the slot level and use the caster's spell attack and save DC; the familiar from
## Find Familiar (an owl: it can't attack); and the Skeleton or Zombie from Animate Dead. They're Monster data in the
## data/monsters format, built here because their numbers depend on the casting.


## Monster data for `spell_id` cast at `slot` with `option` (the mood or form) and the caster's numbers
## ({dc: Breakdown, attack: Breakdown}), or {} if the spell summons nothing.
static func for_spell(spell_id: String, slot: int, option: String, nums: Dictionary) -> Dictionary:
	var atk := (nums["attack"] as Breakdown).total() if nums.has("attack") else 5
	var dc := (nums["dc"] as Breakdown).total() if nums.has("dc") else 13
	match spell_id:
		"summon_dinosaur":
			return dinosaur_spirit(slot, option if option != "" else "ankylosaur", atk, dc)
		"summon_plant":
			return plant_spirit(slot, option if option != "" else "tree", atk)
		"summon_fey":
			return fey_spirit(slot, option if option != "" else "fuming", atk, dc)
		"summon_undead":
			return undead_spirit(slot, option if option != "" else "skeletal", atk, dc)
		"find_familiar":
			# Necromancy Familiar's Zombie form.
			if option == "zombie":
				var z := Compendium.shared().monster_data("zombie").duplicate(true)
				z["familiar"] = true
				return z
			return chain_form(option, dc) if option in CHAIN_FORMS else owl()
		"find_steed":
			return otherworldly_steed(slot, option if option != "" else "celestial", atk, dc)
		"summon_beast":
			return bestial_spirit(slot, option if option != "" else "land", atk)
		"giant_insect":
			return giant_insect(slot, option if option != "" else "spider", atk, dc)
		"summon_aberration":
			return aberrant_spirit(slot, option if option != "" else "slaad", atk, dc)
		"summon_construct":
			return construct_spirit(slot, option if option != "" else "stone", atk, dc)
		"summon_elemental":
			return elemental_spirit(slot, option if option != "" else "fire", atk)
		"summon_celestial":
			return celestial_spirit(slot, option if option != "" else "avenger", atk)
		"summon_dragon":
			return draconic_spirit(slot, option if option != "" else "fire", atk, dc)
		"summon_fiend":
			return fiendish_spirit(slot, option if option != "" else "devil", atk, dc)
		"animate_objects":
			return animated_object(slot, option if option != "" else "small", atk, int(nums.get("mod", 3)))
		"animate_dead":
			var z := Compendium.shared().monster_data(option if option != "" else "zombie")
			if z.is_empty():
				z = Compendium.shared().monster_data("zombie")
			var d := z.duplicate(true)
			d["ai_profile"] = "mindless"
			return d
	return {}


static func _attacks(slot: int) -> int:
	return maxi(1, slot / 2)


## Fey Spirit (Small Fey): AC 12 + level, HP 30 + 10 per level above 3, Speed 30 and Fly 30, immune to Charmed.
## Fey Blade 2d6 + 3 + level Force (attacks = half the level); Fey Step: a Bonus Action teleport of 30 ft with the
## mood's rider (Fuming: Advantage on its next attack this turn; Mirthful: a creature within 10 ft makes a Wisdom
## save or is Charmed; Tricksy: magical Darkness in a 5 ft Cube within 5 ft until the end of its next turn).
static func fey_spirit(slot: int, mood: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(3, slot)
	return {
		"id": "fey_spirit", "name": "Fey Spirit (%s)" % mood.capitalize(), "size": "small", "type": "fey",
		"ac": 12 + lvl, "hp": {"average": 30 + 10 * (lvl - 3), "dice": str(30 + 10 * (lvl - 3))},
		"speed": {"walk": 30, "fly": 30}, "abilities": {"str": 13, "dex": 16, "con": 14, "int": 14, "wis": 11, "cha": 16},
		"senses": {"darkvision": 60}, "condition_immunities": ["charmed"], "cr": 0, "xp": 0, "proficiency_bonus": 2,
		"initiative": 3, "summon": true, "mood": mood,
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": "fey_blade", "count": _attacks(lvl)}],
				"summary": "Fey Blade attacks equal to half the spell's level."},
			{"id": "fey_blade", "name": "Fey Blade", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
				"damage": [{"dice": "2d6+%d" % (3 + lvl), "type": "force"}], "summary": "Melee spell attack."},
		],
		"bonus_actions": [
			{"id": "fey_step", "name": "Fey Step", "teleport": 30, "mood": mood, "save_dc": dc,
				"summary": "Teleports up to 30 ft, then: %s." % {"fuming": "Advantage on its next attack this turn",
					"mirthful": "a creature within 10 ft makes a Wisdom save or is Charmed", "tricksy": "magical Darkness in a 5 ft Cube beside it"}.get(mood, "")},
		],
		"ai_profile": "brute", "summary": "A spirit of the Feywild bound to the caster's will.", "text": "Summon Fey.",
	}


## Undead Spirit (Medium Undead): AC 11 + level, HP 30 + 10 per level above 3 (Skeletal 20 + 10), Speed 30
## (Ghostly also Fly 40), immune to Necrotic and Poison and to Exhaustion, Frightened, Paralyzed and Poisoned.
## Ghostly: Deathly Touch 1d8 + 3 + level Necrotic and Frightened until the end of the target's next turn.
## Putrid: Festering Aura (Con save or Poisoned for creatures starting a turn within 5 ft) and Rotting Claw
## 1d6 + 3 + level Slashing (a Poisoned target makes a Con save or is Paralyzed until the end of its next turn).
## Skeletal: Grave Bolt, a 150 ft ranged spell attack for 2d4 + 3 + level Necrotic.
static func undead_spirit(slot: int, form: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(3, slot)
	var hp := (20 if form == "skeletal" else 30) + 10 * (lvl - 3)
	var speed := {"walk": 30}
	var actions: Array = []
	var traits: Array = []
	var attack_id := ""
	match form:
		"ghostly":
			speed["fly"] = 40
			attack_id = "deathly_touch"
			actions.append({"id": "deathly_touch", "name": "Deathly Touch", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
				"damage": [{"dice": "1d8+%d" % (3 + lvl), "type": "necrotic"}], "conditions": ["frightened"],
				"condition_until": "target_turn_end", "summary": "Necrotic damage; the target is Frightened until the end of its next turn."})
			traits.append({"id": "incorporeal_passage", "name": "Incorporeal Passage", "action": "passive",
				"modifiers": [{"stat": "flag", "value": "pass_through_creatures"}], "summary": "Moves through creatures and objects."})
		"putrid":
			attack_id = "rotting_claw"
			actions.append({"id": "rotting_claw", "name": "Rotting Claw", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
				"damage": [{"dice": "1d6+%d" % (3 + lvl), "type": "slashing"}], "if_poisoned": {"save": {"ability": "con", "dc": dc},
					"condition": "paralyzed", "until": "target_turn_end"},
				"summary": "Slashing damage; a Poisoned target makes a Con save or is Paralyzed until the end of its next turn."})
			traits.append({"id": "festering_aura", "name": "Festering Aura", "action": "passive",
				"aura": {"radius": 5, "trigger": "start_turn", "save": {"ability": "con", "dc": dc}, "condition": "poisoned",
					"until": "target_turn_start", "affects": "enemies"},
				"summary": "A creature that starts its turn within 5 ft makes a Con save or is Poisoned until the start of its next turn."})
		_:
			attack_id = "grave_bolt"
			actions.append({"id": "grave_bolt", "name": "Grave Bolt", "kind": "ranged", "attack": {"bonus": atk, "range": [150]},
				"damage": [{"dice": "2d4+%d" % (3 + lvl), "type": "necrotic"}], "summary": "Ranged spell attack."})
	actions.push_front({"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": attack_id, "count": _attacks(lvl)}],
		"summary": "Attacks equal to half the spell's level."})
	return {
		"id": "undead_spirit", "name": "Undead Spirit (%s)" % form.capitalize(), "size": "medium", "type": "undead",
		"ac": 11 + lvl, "hp": {"average": hp, "dice": str(hp)}, "speed": speed,
		"abilities": {"str": 12, "dex": 16, "con": 15, "int": 4, "wis": 10, "cha": 9}, "senses": {"darkvision": 60},
		"immunities": ["necrotic", "poison"], "condition_immunities": ["exhaustion", "frightened", "paralyzed", "poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 3, "summon": true, "traits": traits, "actions": actions,
		"ai_profile": "brute", "summary": "A restless dead spirit bound to the caster's will.", "text": "Summon Undead.",
	}


## Otherworldly Steed (Find Steed; Large, the chosen type): AC 10 + level, HP 5 + 10 × level, Speed 60 (Fly 60 from
## level 4), Otherworldly Slam 1d8 + level of the type's damage, and one Bonus Action a Long Rest by type: Fell Glare
## (Fiend: Wis save or Frightened until the end of the caster's next turn), Fey Step (Fey: teleport 60 ft), Healing
## Touch (Celestial: 2d8 + level to a creature within 5 ft).
static func otherworldly_steed(slot: int, kind: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(2, slot)
	var dtype := {"celestial": "radiant", "fey": "psychic", "fiend": "necrotic"}.get(kind, "radiant") as String
	var speed := {"walk": 60}
	if lvl >= 4:
		speed["fly"] = 60
	var bonus: Array = []
	match kind:
		"fiend":
			bonus.append({"id": "fell_glare", "name": "Fell Glare", "do": "save", "uses": {"count": 1, "per": "long"},
				"save": {"ability": "wis", "dc": dc}, "targets": {"range": 60}, "on_fail": [{"do": "condition", "condition": "frightened", "until": "summoner_turn_end"}],
				"summary": "A creature within 60 ft makes a Wisdom save or is Frightened until the end of your next turn."})
		"fey":
			bonus.append({"id": "fey_step", "name": "Fey Step", "do": "teleport", "teleport": 60, "uses": {"count": 1, "per": "long"},
				"summary": "Teleports, with its rider, to a space within 60 ft."})
		_:
			bonus.append({"id": "healing_touch", "name": "Healing Touch", "do": "heal", "heal": "2d8+%d" % lvl, "range": 5, "uses": {"count": 1, "per": "long"},
				"summary": "A creature within 5 ft regains 2d8 + %d Hit Points." % lvl})
	return {
		"id": "otherworldly_steed", "name": "Otherworldly Steed (%s)" % kind.capitalize(), "size": "large", "type": kind,
		"ac": 10 + lvl, "hp": {"average": 5 + 10 * lvl, "dice": str(5 + 10 * lvl)}, "speed": speed,
		"abilities": {"str": 18, "dex": 12, "con": 14, "int": 6, "wis": 12, "cha": 8}, "passive_perception": 11,
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 1, "summon": true, "steed": true,
		"traits": [{"id": "life_bond", "name": "Life Bond", "action": "passive", "summary": "Regains what its rider regains from a spell of level 1+ while within 5 ft."}],
		"actions": [{"id": "otherworldly_slam", "name": "Otherworldly Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": [{"dice": "1d8+%d" % lvl, "type": dtype}], "summary": "Melee spell attack."}],
		"bonus_actions": bonus, "ai_profile": "brute", "summary": "A loyal spirit steed.", "text": "Find Steed.",
	}


## Bestial Spirit (Summon Beast; Small Beast): AC 11 + level, HP 20 (Air) or 30 + 5 per level above 2; Air flies 60
## with Flyby, Land climbs 30, Water swims 30; Land and Water have Pack Tactics. Rend 1d8 + 4 + level Piercing,
## attacks equal to half the level.
static func bestial_spirit(slot: int, env: String, atk: int) -> Dictionary:
	var lvl := maxi(2, slot)
	var speed := {"walk": 30}
	var traits: Array = []
	match env:
		"air":
			speed["fly"] = 60
			traits.append({"id": "flyby", "name": "Flyby", "action": "passive", "modifiers": [{"stat": "flag", "value": "flyby"}],
				"summary": "Doesn't provoke Opportunity Attacks when it flies out of reach."})
		"water":
			speed["swim"] = 30
		_:
			speed["climb"] = 30
	if env != "air":
		traits.append({"id": "pack_tactics", "name": "Pack Tactics", "action": "passive", "modifiers": [{"stat": "flag", "value": "pack_tactics"}],
			"summary": "Advantage on an attack roll if an ally is within 5 ft of the target."})
	return {
		"id": "bestial_spirit", "name": "Bestial Spirit (%s)" % env.capitalize(), "size": "small", "type": "beast",
		"ac": 11 + lvl, "hp": {"average": (20 if env == "air" else 30) + 5 * (lvl - 2), "dice": str((20 if env == "air" else 30) + 5 * (lvl - 2))},
		"speed": speed, "abilities": {"str": 18, "dex": 11, "con": 16, "int": 4, "wis": 14, "cha": 5}, "senses": {"darkvision": 60},
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 0, "summon": true, "traits": traits,
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": "rend", "count": _attacks(lvl)}], "summary": "Rend attacks equal to half the spell's level."},
			{"id": "rend", "name": "Rend", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "1d8+%d" % (4 + lvl), "type": "piercing"}], "summary": "Melee spell attack."},
		],
		"ai_profile": "brute", "summary": "A spirit beast bound to the caster's will.", "text": "Summon Beast.",
	}


## Giant Insect (Large Beast): AC 11 + level, HP 30 + 10 per level above 4, Speed 40, Climb 40 (Wasp Fly 40), Spider
## Climb. Poison Jab (reach 10 ft) 1d6 + 3 + level Piercing + 1d4 Poison, attacks equal to half the level; the
## spider's Web Bolt (60 ft) 1d10 + 3 + level Bludgeoning and Speed 0 until the start of its next turn; the
## centipede's Venomous Spew (Bonus Action): a creature within 10 ft makes a Con save or is Poisoned.
static func giant_insect(slot: int, kind: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(4, slot)
	var speed := {"walk": 40, "climb": 40}
	if kind == "wasp":
		speed["fly"] = 40
	var actions: Array = [
		{"id": "poison_jab", "name": "Poison Jab", "kind": "melee", "attack": {"bonus": atk, "reach": 10},
			"damage": [{"dice": "1d6+%d" % (3 + lvl), "type": "piercing"}, {"dice": "1d4", "type": "poison"}], "summary": "Melee spell attack."},
	]
	var multi: Array = [{"action": "poison_jab", "count": _attacks(lvl)}]
	if kind == "spider":
		actions.append({"id": "web_bolt", "name": "Web Bolt", "kind": "ranged", "attack": {"bonus": atk, "range": [60]},
			"damage": [{"dice": "1d10+%d" % (3 + lvl), "type": "bludgeoning"}],
			"on_hit": [{"do": "condition", "condition": "", "until": "source_turn_start", "modifiers": [{"stat": "speed_set", "value": 0}]}],
			"summary": "Ranged spell attack; the target's Speed is 0 until the start of the insect's next turn."})
		multi = [{"action": "poison_jab", "count": _attacks(lvl), "or": ["web_bolt"]}]
	actions.push_front({"id": "multiattack", "name": "Multiattack", "multiattack": multi, "summary": "Attacks equal to half the spell's level."})
	var bonus: Array = []
	if kind == "centipede":
		bonus.append({"id": "venomous_spew", "name": "Venomous Spew", "do": "save", "save": {"ability": "con", "dc": dc}, "targets": {"range": 10},
			"on_fail": [{"do": "condition", "condition": "poisoned", "until": "source_turn_start"}],
			"summary": "A creature within 10 ft makes a Constitution save or is Poisoned until the start of the insect's next turn."})
	return {
		"id": "giant_insect", "name": "Giant %s" % kind.capitalize(), "size": "large", "type": "beast",
		"ac": 11 + lvl, "hp": {"average": 30 + 10 * (lvl - 4), "dice": str(30 + 10 * (lvl - 4))}, "speed": speed,
		"abilities": {"str": 17, "dex": 13, "con": 15, "int": 4, "wis": 14, "cha": 3}, "senses": {"darkvision": 60},
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 1, "summon": true,
		"traits": [{"id": "spider_climb", "name": "Spider Climb", "action": "passive", "modifiers": [{"stat": "flag", "value": "spider_climb"}],
			"summary": "Climbs difficult surfaces, ceilings included, without a check."}],
		"actions": actions, "bonus_actions": bonus, "ai_profile": "brute", "summary": "A summoned giant insect.", "text": "Giant Insect.",
	}


## Aberrant Spirit (Medium Aberration): AC 11 + level, HP 40 + 10 per level above 4, immune to Psychic. Beholderkin:
## Fly 30 and Eye Ray (150 ft) 1d8 + 3 + level Psychic. Mind Flayer: Psychic Slam 1d8 + 3 + level Psychic and a
## Whispering Aura (Wis save or 2d6 Psychic to chosen creatures within 5 ft at the start of its turn). Slaad: Claw
## 1d10 + 3 + level Slashing (no healing until the start of its next turn) and Regeneration 5.
static func aberrant_spirit(slot: int, kind: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(4, slot)
	var speed := {"walk": 30}
	var traits: Array = []
	var attack_id := ""
	var actions: Array = []
	match kind:
		"beholderkin":
			speed["fly"] = 30
			attack_id = "eye_ray"
			actions.append({"id": "eye_ray", "name": "Eye Ray", "kind": "ranged", "attack": {"bonus": atk, "range": [150]},
				"damage": [{"dice": "1d8+%d" % (3 + lvl), "type": "psychic"}], "summary": "Ranged spell attack."})
		"mind_flayer":
			attack_id = "psychic_slam"
			actions.append({"id": "psychic_slam", "name": "Psychic Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
				"damage": [{"dice": "1d8+%d" % (3 + lvl), "type": "psychic"}], "summary": "Melee spell attack."})
			traits.append({"id": "whispering_aura", "name": "Whispering Aura", "action": "passive", "aura": {"radius": 5, "trigger": "own_turn_start",
				"save": {"ability": "wis", "dc": dc}, "damage": {"dice": "2d6", "type": "psychic"}, "affects": "enemies"},
				"summary": "At the start of its turn, enemies within 5 ft make a Wisdom save or take 2d6 Psychic damage."})
		_:
			attack_id = "claw"
			actions.append({"id": "claw", "name": "Claw", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
				"damage": [{"dice": "1d10+%d" % (3 + lvl), "type": "slashing"}],
				"on_hit": [{"do": "condition", "condition": "", "until": "source_turn_start", "modifiers": [{"stat": "flag", "value": "cant_regain_hp"}]}],
				"summary": "Melee spell attack; the target can't regain Hit Points until the start of the spirit's next turn."})
			traits.append({"id": "regeneration", "name": "Regeneration", "action": "passive", "regenerate": 5,
				"summary": "Regains 5 Hit Points at the start of its turn if it has at least 1."})
	actions.push_front({"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": attack_id, "count": _attacks(lvl)}],
		"summary": "Attacks equal to half the spell's level."})
	return {
		"id": "aberrant_spirit", "name": "Aberrant Spirit (%s)" % kind.capitalize().replace("_", " "), "size": "medium", "type": "aberration",
		"ac": 11 + lvl, "hp": {"average": 40 + 10 * (lvl - 4), "dice": str(40 + 10 * (lvl - 4))}, "speed": speed,
		"abilities": {"str": 16, "dex": 10, "con": 15, "int": 16, "wis": 10, "cha": 6}, "senses": {"darkvision": 60},
		"immunities": ["psychic"], "cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 0, "summon": true, "traits": traits,
		"actions": actions, "ai_profile": "brute", "summary": "A spirit from the Far Realm bound to the caster's will.", "text": "Summon Aberration.",
	}


## Construct Spirit (Medium Construct): AC 13 + level, HP 40 + 15 per level above 4, resists Poison, can't be Charmed,
## Exhausted, Frightened, Paralyzed or Poisoned. Slam 1d8 + 4 + level Bludgeoning. Clay: Berserk Lashing (a Reaction
## Slam at a random creature within 5 ft when it takes damage). Metal: Heated Body (1d10 Fire to a creature that hits
## it in melee). Stone: Stony Lethargy (a creature starting its turn within 10 ft makes a Wis save or has half Speed
## and no Opportunity Attacks until the start of its next turn).
static func construct_spirit(slot: int, kind: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(4, slot)
	var traits: Array = []
	match kind:
		"clay":
			traits.append({"id": "berserk_lashing", "name": "Berserk Lashing", "action": "passive",
				"summary": "Reaction when it takes damage: a Slam against a random creature within 5 ft."})
		"metal":
			traits.append({"id": "heated_body", "name": "Heated Body", "action": "passive",
				"modifiers": [{"stat": "retaliate", "dice": "1d10", "type": "fire", "within": 5}],
				"summary": "A creature that hits it with a melee attack takes 1d10 Fire damage."})
		_:
			traits.append({"id": "stony_lethargy", "name": "Stony Lethargy", "action": "passive", "aura": {"radius": 10, "trigger": "start_turn",
				"save": {"ability": "wis", "dc": dc}, "condition": "", "until": "target_turn_start", "affects": "enemies",
				"modifiers": [{"stat": "speed_percent", "value": 50}, {"stat": "flag", "value": "no_opportunity_attacks"}]},
				"summary": "A creature starting its turn within 10 ft makes a Wisdom save or has half Speed and no Opportunity Attacks."})
	return {
		"id": "construct_spirit", "name": "Construct Spirit (%s)" % kind.capitalize(), "size": "medium", "type": "construct",
		"ac": 13 + lvl, "hp": {"average": 40 + 15 * (lvl - 4), "dice": str(40 + 15 * (lvl - 4))}, "speed": {"walk": 30},
		"abilities": {"str": 18, "dex": 10, "con": 18, "int": 14, "wis": 11, "cha": 5}, "senses": {"darkvision": 60},
		"resistances": ["poison"], "condition_immunities": ["charmed", "exhaustion", "frightened", "paralyzed", "poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 0, "summon": true, "traits": traits,
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": "slam", "count": _attacks(lvl)}], "summary": "Slam attacks equal to half the spell's level."},
			{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "1d8+%d" % (4 + lvl), "type": "bludgeoning"}], "summary": "Melee spell attack."},
		],
		"ai_profile": "brute", "summary": "A golem-like spirit bound to the caster's will.", "text": "Summon Construct.",
	}


## Elemental Spirit (Medium Elemental): AC 11 + level, HP 50 + 10 per level above 4, Speed 40 (Earth Burrow 40, Air Fly
## 40, Water Swim 40), immune to Poison (Fire also to Fire) and to Exhaustion, Paralyzed, Petrified and Poisoned;
## resists Acid (Water), Lightning and Thunder (Air), Piercing and Slashing (Earth). Slam 1d10 + 4 + level of the
## element's type.
static func elemental_spirit(slot: int, kind: String, atk: int) -> Dictionary:
	var lvl := maxi(4, slot)
	var speed := {"walk": 40}
	var res: Array = []
	var imm: Array = ["poison"]
	var dtype := "fire"
	match kind:
		"air":
			speed["fly"] = 40
			res = ["lightning", "thunder"]
			dtype = "lightning"
		"earth":
			speed["burrow"] = 40
			res = ["piercing", "slashing"]
			dtype = "bludgeoning"
		"water":
			speed["swim"] = 40
			res = ["acid"]
			dtype = "cold"
		_:
			imm.append("fire")
	return {
		"id": "elemental_spirit", "name": "Elemental Spirit (%s)" % kind.capitalize(), "size": "medium", "type": "elemental",
		"ac": 11 + lvl, "hp": {"average": 50 + 10 * (lvl - 4), "dice": str(50 + 10 * (lvl - 4))}, "speed": speed,
		"abilities": {"str": 18, "dex": 15, "con": 17, "int": 4, "wis": 10, "cha": 16}, "senses": {"darkvision": 60},
		"resistances": res, "immunities": imm, "condition_immunities": ["exhaustion", "paralyzed", "petrified", "poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 2, "summon": true,
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": "slam", "count": _attacks(lvl)}], "summary": "Slam attacks equal to half the spell's level."},
			{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "1d10+%d" % (4 + lvl), "type": dtype}], "summary": "Melee spell attack."},
		],
		"ai_profile": "brute", "summary": "A spirit of the elements bound to the caster's will.", "text": "Summon Elemental.",
	}


## Celestial Spirit (Summon Celestial; Large Celestial): AC 11 + level (Defender +2), HP 40 + 10 per level above 5,
## Speed 30, Fly 40, resists Radiant, can't be Charmed or Frightened. Avenger: Radiant Bow (150/600 ft) 2d6 + 2 + level
## Radiant. Defender: Radiant Mace 1d10 + 3 + level Radiant, and a creature within 10 ft gains 1d10 Temporary Hit Points.
## Attacks equal to half the level; Healing Touch once a day: 2d8 + level.
static func celestial_spirit(slot: int, kind: String, atk: int) -> Dictionary:
	var lvl := maxi(5, slot)
	var attack: Dictionary
	if kind == "defender":
		attack = {"id": "radiant_mace", "name": "Radiant Mace", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": [{"dice": "1d10+%d" % (3 + lvl), "type": "radiant"}], "ally_temp_hp": {"dice": "1d10", "range": 10}, "summary": "Radiant damage; an ally within 10 ft gains 1d10 Temporary Hit Points."}
	else:
		attack = {"id": "radiant_bow", "name": "Radiant Bow", "kind": "ranged", "attack": {"bonus": atk, "range": [150, 600]},
			"damage": [{"dice": "2d6+%d" % (2 + lvl), "type": "radiant"}], "summary": "Radiant damage."}
	return {
		"id": "celestial_spirit", "name": "Celestial Spirit (%s)" % kind.capitalize(), "size": "large", "type": "celestial",
		"ac": 11 + lvl + (2 if kind == "defender" else 0), "hp": {"average": 40 + 10 * (lvl - 5), "dice": str(40 + 10 * (lvl - 5))},
		"speed": {"walk": 30, "fly": 40}, "abilities": {"str": 16, "dex": 14, "con": 16, "int": 10, "wis": 14, "cha": 16},
		"senses": {"darkvision": 60}, "resistances": ["radiant"], "condition_immunities": ["charmed", "frightened"],
		"cr": 0, "xp": 0, "proficiency_bonus": 3, "initiative": 2, "summon": true,
		"actions": [{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": str(attack["id"]), "count": _attacks(lvl)}], "summary": "Attacks equal to half the spell's level."}, attack,
			{"id": "healing_touch", "name": "Healing Touch", "do": "heal", "heal": "2d8+%d" % lvl, "range": 5, "uses": {"count": 1, "per": "long"},
				"summary": "A creature within 5 ft regains 2d8 + %d Hit Points (once a day)." % lvl}],
		"traits": [], "ai_profile": "brute", "summary": "A celestial spirit.", "text": "Summon Celestial.",
	}


## Draconic Spirit (Summon Dragon; Large Dragon): AC 14 + level, HP 50 + 10 per level above 5, Speed 30, Fly 60, Swim
## 30, resists its element, immune to Charmed, Frightened and Poisoned. Rend 1d6 + 4 + level Piercing (attacks equal to
## half the level) and a Breath Weapon in their place: a 30-ft Cone, Dex save, 2d6 of its element.
static func draconic_spirit(slot: int, element: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(5, slot)
	return {
		"id": "draconic_spirit", "name": "Draconic Spirit (%s)" % element.capitalize(), "size": "large", "type": "dragon",
		"ac": 14 + lvl, "hp": {"average": 50 + 10 * (lvl - 5), "dice": str(50 + 10 * (lvl - 5))},
		"speed": {"walk": 30, "fly": 60, "swim": 30}, "abilities": {"str": 19, "dex": 14, "con": 17, "int": 10, "wis": 14, "cha": 14},
		"senses": {"blindsight": 30, "darkvision": 60}, "resistances": [element], "condition_immunities": ["charmed", "frightened", "poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 3, "initiative": 2, "summon": true,
		"actions": [
			{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": "rend", "count": _attacks(lvl), "or": ["breath"]}], "summary": "Rend attacks equal to half the spell's level; Breath Weapon can replace one."},
			{"id": "rend", "name": "Rend", "kind": "melee", "attack": {"bonus": atk, "reach": 10}, "damage": [{"dice": "1d6+%d" % (4 + lvl), "type": "piercing"}], "summary": "Piercing damage."},
			{"id": "breath", "name": "Breath Weapon", "kind": "save", "save": {"ability": "dex", "dc": dc, "success": "half"}, "targets": {"range": 30, "count": 99},
				"damage": [{"dice": "2d6", "type": element}], "summary": "A 30-ft Cone: Dex save, 2d6 %s, half on a success." % element.capitalize()},
		],
		"ai_profile": "brute", "summary": "A draconic spirit.", "text": "Summon Dragon.",
	}


## Fiendish Spirit (Summon Fiend; Large Fiend): AC 12 + level, HP 50 (Demon), 40 (Devil) or 60 (Yugoloth) + 15 per level
## above 6, Speed 40 (Devil: Fly 60), resists Fire, immune to Poison. Demon: Bite 1d12 + 3 + level Necrotic and Death
## Throes (a 10-ft burst of 2d10 + level Fire when it dies). Devil: Fiery Strike (melee or 150 ft) 2d6 + 3 + level Fire,
## Magic Resistance. Yugoloth: Claws 1d8 + 3 + level Slashing, then a 30-ft teleport.
static func fiendish_spirit(slot: int, kind: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(6, slot)
	var hp := {"demon": 50, "devil": 40, "yugoloth": 60}.get(kind, 50) as int
	var speed := {"walk": 40}
	var attack: Dictionary
	var traits: Array = []
	match kind:
		"demon":
			attack = {"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "1d12+%d" % (3 + lvl), "type": "necrotic"}], "summary": "Necrotic damage."}
			traits.append({"id": "death_throes", "name": "Death Throes", "action": "passive", "death_burst": {"radius": 10, "save": {"ability": "dex", "dc": dc}, "damage": {"dice": "2d10+%d" % lvl, "type": "fire"}},
				"summary": "When it dies it explodes: creatures within 10 ft make a Dex save, 2d10 + level Fire, half on a success."})
		"yugoloth":
			attack = {"id": "claws", "name": "Claws", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "1d8+%d" % (3 + lvl), "type": "slashing"}], "summary": "Slashing damage; it can then teleport 30 ft."}
		_:
			speed["fly"] = 60
			attack = {"id": "fiery_strike", "name": "Fiery Strike", "kind": "melee", "attack": {"bonus": atk, "reach": 5, "range": [150]}, "damage": [{"dice": "2d6+%d" % (3 + lvl), "type": "fire"}], "summary": "Fire damage, in melee or at range."}
			traits.append({"id": "magic_resistance", "name": "Magic Resistance", "action": "passive", "modifiers": [{"stat": "advantage", "on": "save_vs:spell"}], "summary": "Advantage on saves against spells."})
			traits.append({"id": "devils_sight", "name": "Devil's Sight", "action": "passive", "modifiers": [{"stat": "flag", "value": "devils_sight"}], "summary": "Sees through magical Darkness."})
	return {
		"id": "fiendish_spirit", "name": "Fiendish Spirit (%s)" % kind.capitalize(), "size": "large", "type": "fiend",
		"ac": 12 + lvl, "hp": {"average": hp + 15 * (lvl - 6), "dice": str(hp + 15 * (lvl - 6))}, "speed": speed,
		"abilities": {"str": 13, "dex": 16, "con": 15, "int": 10, "wis": 10, "cha": 16}, "senses": {"darkvision": 60},
		"resistances": ["fire"], "immunities": ["poison"], "condition_immunities": ["poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 3, "initiative": 3, "summon": true, "traits": traits,
		"actions": [{"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": str(attack["id"]), "count": _attacks(lvl)}], "summary": "Attacks equal to half the spell's level."}, attack],
		"ai_profile": "brute", "summary": "A fiendish spirit.", "text": "Summon Fiend.",
	}


## Animated Object (Animate Objects): AC 15, HP 10 (Medium or smaller), 20 (Large) or 40 (Huge), Speed 30, Slam with
## the caster's spell attack: 1d4 + 3 (Medium or smaller), 2d6 + 3 (Large) or 2d12 + 3 (Huge) Force plus the caster's
## spellcasting modifier, the die growing with the slot. Numbers not yet checked against the book (deviations).
static func animated_object(slot: int, size: String, atk: int, mod: int) -> Dictionary:
	var up := maxi(0, slot - 5)
	var hp := {"large": 20, "huge": 40}.get(size, 10) as int
	var dice := {"large": "%dd6" % (2 + up), "huge": "%dd12" % (2 + up)}.get(size, "%dd4" % (1 + up)) as String
	return {
		"id": "animated_object", "name": "Animated Object", "size": size if size in ["large", "huge"] else "small", "type": "construct",
		"ac": 15, "hp": {"average": hp, "dice": str(hp)}, "speed": {"walk": 30},
		"abilities": {"str": 16, "dex": 10, "con": 10, "int": 3, "wis": 3, "cha": 1}, "senses": {"blindsight": 30},
		"immunities": ["poison", "psychic"], "condition_immunities": ["charmed", "exhaustion", "frightened", "paralyzed", "poisoned"],
		"cr": 0, "xp": 0, "proficiency_bonus": 3, "initiative": 0, "summon": true,
		"actions": [{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5}, "damage": [{"dice": "%s+%d" % [dice, 3 + mod], "type": "force"}], "summary": "Force damage."}],
		"ai_profile": "brute", "summary": "An animated object.", "text": "Animate Objects.",
	}


## Pact of the Chain's special familiar forms (2024 PHB): Imp, Pseudodragon, Quasit, Skeleton, Slaad Tadpole, Sphinx
## of Wonder, Sprite, Venomous Snake. Their numbers follow the 2025 Monster Manual as best we have them (not yet
## checked against the book: deviations.md); the familiar's save DCs use the warlock's.
const CHAIN_FORMS := ["imp", "pseudodragon", "quasit", "skeleton", "slaad_tadpole", "sphinx_of_wonder", "sprite", "venomous_snake"]


static func chain_form(form: String, dc: int) -> Dictionary:
	var base := {"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 2, "summon": true, "familiar": true, "chain": true,
		"ai_profile": "skirmisher", "text": "Pact of the Chain familiar."}
	var d := {}
	match form:
		"imp":
			d = {"id": "imp_familiar", "name": "Imp (familiar)", "size": "tiny", "type": "fiend", "ac": 13, "hp": {"average": 21, "dice": "21"},
				"speed": {"walk": 20, "fly": 40}, "abilities": {"str": 6, "dex": 17, "con": 13, "int": 11, "wis": 12, "cha": 14},
				"resistances": ["cold"], "immunities": ["fire", "poison"], "condition_immunities": ["poisoned"], "senses": {"darkvision": 120},
				"traits": [{"id": "magic_resistance", "name": "Magic Resistance", "action": "passive", "modifiers": [{"stat": "advantage", "on": "save_vs:spell"}], "summary": "Advantage on saves against spells."}],
				"actions": [{"id": "sting", "name": "Sting", "kind": "melee", "attack": {"bonus": 5, "reach": 5},
					"damage": [{"dice": "1d6+3", "type": "piercing"}, {"dice": "2d6", "type": "poison"}], "summary": "Piercing and Poison damage."}],
				"summary": "A devilish imp familiar."}
		"pseudodragon":
			d = {"id": "pseudodragon_familiar", "name": "Pseudodragon (familiar)", "size": "tiny", "type": "dragon", "ac": 14, "hp": {"average": 10, "dice": "10"},
				"speed": {"walk": 15, "fly": 60}, "abilities": {"str": 6, "dex": 15, "con": 13, "int": 10, "wis": 12, "cha": 10}, "senses": {"blindsight": 10, "darkvision": 60},
				"traits": [{"id": "magic_resistance", "name": "Magic Resistance", "action": "passive", "modifiers": [{"stat": "advantage", "on": "save_vs:spell"}], "summary": "Advantage on saves against spells."}],
				"actions": [{"id": "sting", "name": "Sting", "kind": "melee", "attack": {"bonus": 4, "reach": 5}, "damage": [{"dice": "1d4+2", "type": "piercing"}],
					"on_hit": [{"do": "condition", "condition": "poisoned", "save": {"ability": "con", "dc": dc}, "until": "minute"}], "summary": "Piercing damage; a Con save or Poisoned."}],
				"summary": "A tiny dragon familiar."}
		"quasit":
			d = {"id": "quasit_familiar", "name": "Quasit (familiar)", "size": "tiny", "type": "fiend", "ac": 13, "hp": {"average": 25, "dice": "25"},
				"speed": {"walk": 40}, "abilities": {"str": 5, "dex": 17, "con": 10, "int": 7, "wis": 10, "cha": 10},
				"resistances": ["cold", "fire", "lightning"], "immunities": ["poison"], "condition_immunities": ["poisoned"], "senses": {"darkvision": 120},
				"traits": [{"id": "magic_resistance", "name": "Magic Resistance", "action": "passive", "modifiers": [{"stat": "advantage", "on": "save_vs:spell"}], "summary": "Advantage on saves against spells."}],
				"actions": [{"id": "rend", "name": "Rend", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4+3", "type": "slashing"}],
					"on_hit": [{"do": "condition", "condition": "poisoned", "save": {"ability": "con", "dc": dc}, "until": "minute"}], "summary": "Slashing damage; a Con save or Poisoned."}],
				"summary": "A demonic quasit familiar."}
		"skeleton":
			d = {"id": "skeleton_familiar", "name": "Skeleton (familiar)", "size": "medium", "type": "undead", "ac": 14, "hp": {"average": 13, "dice": "13"},
				"speed": {"walk": 30}, "abilities": {"str": 10, "dex": 16, "con": 15, "int": 6, "wis": 8, "cha": 5},
				"vulnerabilities": ["bludgeoning"], "immunities": ["poison"], "condition_immunities": ["exhaustion", "poisoned"], "senses": {"darkvision": 60},
				"actions": [{"id": "shortsword", "name": "Shortsword", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d6+3", "type": "piercing"}], "summary": "Piercing damage."},
					{"id": "shortbow", "name": "Shortbow", "kind": "ranged", "attack": {"bonus": 5, "range": [80, 320]}, "damage": [{"dice": "1d6+3", "type": "piercing"}], "summary": "Piercing damage."}],
				"summary": "A skeleton familiar."}
		"slaad_tadpole":
			d = {"id": "slaad_tadpole_familiar", "name": "Slaad Tadpole (familiar)", "size": "tiny", "type": "aberration", "ac": 12, "hp": {"average": 7, "dice": "7"},
				"speed": {"walk": 30, "burrow": 10}, "abilities": {"str": 7, "dex": 15, "con": 10, "int": 3, "wis": 5, "cha": 3},
				"resistances": ["acid", "cold", "fire", "lightning", "thunder"], "senses": {"darkvision": 60},
				"actions": [{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 4, "reach": 5}, "damage": [{"dice": "1d6+2", "type": "piercing"}], "summary": "Piercing damage."}],
				"summary": "A slaad tadpole familiar."}
		"sphinx_of_wonder":
			d = {"id": "sphinx_familiar", "name": "Sphinx of Wonder (familiar)", "size": "tiny", "type": "celestial", "ac": 13, "hp": {"average": 24, "dice": "24"},
				"speed": {"walk": 20, "fly": 40}, "abilities": {"str": 6, "dex": 17, "con": 13, "int": 15, "wis": 12, "cha": 11},
				"resistances": ["necrotic", "psychic", "radiant"], "senses": {"darkvision": 60},
				"traits": [{"id": "magic_resistance", "name": "Magic Resistance", "action": "passive", "modifiers": [{"stat": "advantage", "on": "save_vs:spell"}], "summary": "Advantage on saves against spells."}],
				"actions": [{"id": "rend", "name": "Rend", "kind": "melee", "attack": {"bonus": 5, "reach": 5}, "damage": [{"dice": "1d4+3", "type": "slashing"}, {"dice": "2d6", "type": "radiant"}], "summary": "Slashing and Radiant damage."}],
				"summary": "A sphinx of wonder familiar."}
		"sprite":
			d = {"id": "sprite_familiar", "name": "Sprite (familiar)", "size": "tiny", "type": "fey", "ac": 15, "hp": {"average": 10, "dice": "10"},
				"speed": {"walk": 10, "fly": 40}, "abilities": {"str": 3, "dex": 18, "con": 10, "int": 14, "wis": 13, "cha": 11},
				"actions": [{"id": "needle_sword", "name": "Needle Sword", "kind": "melee", "attack": {"bonus": 6, "reach": 5}, "damage": [{"dice": "1d4+4", "type": "piercing"}], "summary": "Piercing damage."},
					{"id": "enchanting_bow", "name": "Enchanting Bow", "kind": "ranged", "attack": {"bonus": 6, "range": [40, 160]}, "damage": [{"dice": "1", "type": "piercing"}],
						"on_hit": [{"do": "condition", "condition": "charmed", "until": "source_turn_start"}], "summary": "1 Piercing; the target is Charmed until the sprite's next turn."}],
				"summary": "A sprite familiar."}
		_:
			d = {"id": "venomous_snake_familiar", "name": "Venomous Snake (familiar)", "size": "tiny", "type": "beast", "ac": 12, "hp": {"average": 6, "dice": "6"},
				"speed": {"walk": 30, "swim": 30}, "abilities": {"str": 2, "dex": 15, "con": 11, "int": 1, "wis": 10, "cha": 3}, "senses": {"blindsight": 10},
				"actions": [{"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": 4, "reach": 5}, "damage": [{"dice": "1d4+2", "type": "piercing"}, {"dice": "1d8", "type": "poison"}], "summary": "Piercing and Poison damage."}],
				"summary": "A venomous snake familiar."}
	d.merge(base)
	return d


## The familiar's default form (an owl). 2024: a familiar can't attack but can take other actions.
static func owl() -> Dictionary:
	return {
		"id": "owl_familiar", "name": "Owl (familiar)", "size": "tiny", "type": "celestial",
		"ac": 11, "hp": {"average": 1, "dice": "1"}, "speed": {"walk": 5, "fly": 60},
		"abilities": {"str": 3, "dex": 13, "con": 8, "int": 2, "wis": 12, "cha": 7}, "skills": {"perception": 5, "stealth": 5},
		"senses": {"darkvision": 120}, "cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 1, "summon": true,
		"familiar": true,
		"traits": [{"id": "flyby", "name": "Flyby", "action": "passive", "modifiers": [{"stat": "flag", "value": "flyby"}],
			"summary": "Doesn't provoke Opportunity Attacks when it flies out of reach."}],
		"actions": [], "ai_profile": "brute", "summary": "A familiar: it can Help, but never attacks.", "text": "Find Familiar.",
	}


## Source-scaled spirits use the same monster attacks, grapples, and player controls as other summons.
static func dinosaur_spirit(slot: int, form: String, atk: int, dc: int) -> Dictionary:
	var lvl := maxi(6, slot)
	var hp := 60 + 10 * (lvl - 6)
	var actions: Array = [{"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 10},
		"damage": [{"dice": "1d10+%d" % (5 + lvl), "type": "bludgeoning"}], "summary": "Strike with the spirit’s weight."}]
	var primary := "slam"
	var alternatives: Array = []
	if form == "tyrannosaur":
		primary = "bite"
		alternatives = ["slam"]
		actions.append({"id": "bite", "name": "Bite", "kind": "melee", "attack": {"bonus": atk, "reach": 10},
			"damage": [{"dice": "2d10+%d" % (5 + lvl), "type": "piercing"}],
			"on_hit": [{"do": "grapple", "escape_dc": dc, "restrain": true, "max_size": "large", "limit": 99}], "summary": "Large or smaller targets are Grappled and Restrained until they escape."})
	elif form == "triceratops":
		primary = "gore"
		alternatives = ["slam"]
		actions.append({"id": "gore", "name": "Gore", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": [{"dice": "1d10+%d" % (5 + lvl), "type": "piercing"}],
			"charge": {"feet": 20, "damage": [{"dice": "1d10", "type": "piercing"}],
				"on_hit": [{"do": "condition", "condition": "prone", "max_size": "huge"}]}, "summary": "A straight 20-foot charge adds 1d10 damage and knocks Huge or smaller targets Prone."})
	actions.push_front({"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": primary, "count": _attacks(lvl), "or": alternatives}], "summary": "Choose attacks equal to half the spell level."})
	var traits: Array = [{"id": "tough", "name": "Tough", "action": "passive", "summary": "Add half the spell level to Strength and Constitution saves.",
		"modifiers": [{"stat": "save", "ability": "str", "value": lvl / 2}, {"stat": "save", "ability": "con", "value": lvl / 2}]}]
	if form == "ankylosaur":
		traits.append({"id": "siege_monster", "name": "Siege Monster", "action": "passive", "summary": "Double damage against objects and structures.", "modifiers": [{"stat": "flag", "value": "siege_monster"}]})
	return {"id": "dinosaur_spirit", "name": "Dinosaur Spirit (%s)" % form.capitalize(), "size": "huge", "type": "beast", "ac": 11 + lvl + (2 if form == "ankylosaur" else 0),
		"hp": {"average": hp, "dice": str(hp)}, "speed": {"walk": 40}, "abilities": {"str": 21, "dex": 11, "con": 15, "int": 4, "wis": 12, "cha": 9},
		"cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 0, "summon": true, "actions": actions, "traits": traits,
		"ai_profile": "brute", "summary": "A summoned dinosaur spirit.", "text": "Summon Dinosaur."}


static func plant_spirit(slot: int, form: String, atk: int) -> Dictionary:
	var lvl := maxi(5, slot)
	var hp := 50 + 10 * (lvl - 5)
	var speed := {"walk": 40}
	if form == "vine":
		speed["climb"] = 40
	var actions: Array = []
	var primary := "slam"
	var alternatives: Array = []
	var traits: Array = []
	if form == "fungus":
		primary = "spore_spray"
		alternatives = ["spore_spray_melee"]
		for melee: bool in [false, true]:
			actions.append({"id": "spore_spray_melee" if melee else "spore_spray", "name": "Spore Spray (%s)" % ("melee" if melee else "ranged"),
				"kind": "melee" if melee else "ranged", "attack": {"bonus": atk, "reach": 5, "range": [30]},
				"damage": [{"dice": "1d4+%d" % lvl, "type": "poison"}, {"dice": "3d4", "type": "poison", "when": {"target_condition": "poisoned"}}],
				"on_hit": [{"do": "condition", "condition": "poisoned", "unless_condition": "poisoned", "until": "target_turn_end"}], "summary": "Poison the target until its next turn ends, or deal an extra 3d4 Poison if already Poisoned."})
	else:
		actions.append({"id": "slam", "name": "Slam", "kind": "melee", "attack": {"bonus": atk, "reach": 5},
			"damage": [{"dice": "1d10+%d" % (3 + lvl), "type": "bludgeoning"}], "summary": "A heavy plant limb strikes the target."})
	if form == "tree":
		traits.append({"id": "siege_monster", "name": "Siege Monster", "action": "passive", "summary": "Double damage against objects and structures.", "modifiers": [{"stat": "flag", "value": "siege_monster"}]})
	actions.push_front({"id": "multiattack", "name": "Multiattack", "multiattack": [{"action": primary, "count": _attacks(lvl), "or": alternatives}], "summary": "Choose attacks equal to half the spell level."})
	return {"id": "plant_spirit", "name": "Plant Spirit (%s)" % form.capitalize(), "size": "large", "type": "plant", "ac": 11 + lvl + (2 if form == "tree" else 0),
		"hp": {"average": hp, "dice": str(hp)}, "speed": speed, "abilities": {"str": 17, "dex": 13, "con": 14, "int": 10, "wis": 13, "cha": 10},
		"vulnerabilities": ["fire" if form == "tree" else "slashing"], "cr": 0, "xp": 0, "proficiency_bonus": 2, "initiative": 1, "summon": true,
		"actions": actions, "traits": traits, "ai_profile": "brute", "summary": "A summoned plant spirit.", "text": "Summon Plant."}
