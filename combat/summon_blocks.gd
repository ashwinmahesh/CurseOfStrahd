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
		"summon_fey":
			return fey_spirit(slot, option if option != "" else "fuming", atk, dc)
		"summon_undead":
			return undead_spirit(slot, option if option != "" else "skeletal", atk, dc)
		"find_familiar":
			return owl()
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
