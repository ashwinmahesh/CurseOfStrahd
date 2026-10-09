class_name WeaponProfile
extends RefCounted
## How one creature attacks with one weapon or an Unarmed Strike (2024 PHB "Equipment", "Unarmed Strike"):
## the attack bonus and the damage with every source named, the Critical Hit range and the mastery
## property if the wielder can use it. Character sheets list these; AttackResolver rolls them.

var item_id: String = ""
var name: String = ""
var melee: bool = true
var thrown: bool = false
var ability: StringName = &"str"
var proficient: bool = true
var attack: Breakdown
var damage_dice: String = "1d4"
var damage_bonus: Breakdown
var damage_type: StringName = &"bludgeoning"
var crit_range: int = 20
## Damage dice that roll below this count as this (Great Weapon Fighting: 3).
var die_minimum: int = 0
var die_minimum_source: String = ""
var mastery: String = ""
var properties: Array = []
## For `when` filters: melee/ranged, finesse, thrown, two_handed, one_handed_alone, light, unarmed.
var tags: Array[String] = []
## The magic ammunition this profile shoots ("" = ordinary ammunition): its own bonuses apply (`when.ammo`).
var ammo_id: String = ""
var normal_range: int = 0
var long_range: int = 0
var reach: int = 5
var two_hands: bool = false
var notes: Array[String] = []


## `off_hand`: the item in the other hand when it isn't the one held now (a character's second weapon set, read before
## it's taken in hand); null reads the off hand.
static func build(c: Creature, item: Dictionary, as_thrown: bool = false, in_main_hand: bool = true,
		ammo: Dictionary = {}, off_hand: Variant = null) -> WeaponProfile:
	var p := WeaponProfile.new()
	item = reshaped(c, item)
	var either := bool(item.get("_either_ability", false))
	var w := item.get("weapon", {}) as Dictionary
	p.item_id = str(item.get("id", ""))
	p.name = str(item.get("name", p.item_id)) + (" (thrown)" if as_thrown else "")
	if not ammo.is_empty():
		p.ammo_id = str(ammo.get("id", ""))
		p.name += " (%s)" % ammo.get("name", p.ammo_id)
	p.properties = (w.get("properties", []) as Array).duplicate()
	p.melee = not str(w.get("kind", "")).ends_with("ranged") and not as_thrown
	p.thrown = as_thrown
	p.damage_type = StringName(str(w.get("damage_type", "bludgeoning")))
	p.damage_dice = str(w.get("damage", "1d4"))
	var rng := w.get("range", []) as Array
	if rng.size() == 2:
		p.normal_range = int(rng[0])
		p.long_range = int(rng[1])
	if "reach" in p.properties:
		p.reach = 10
	# Grip: two-handed weapons always; versatile ones when the other hand is free.
	var off := {}
	var ch := c as Character
	if off_hand is Dictionary:
		off = off_hand as Dictionary
	elif ch != null:
		off = ch.equipped("off_hand")
	var off_free := off.is_empty()
	if "two_handed" in p.properties:
		p.two_hands = true
	elif "versatile" in p.properties and p.melee and off_free and in_main_hand and not c.has_flag("prefer_one_handed"):
		p.two_hands = true
		p.damage_dice = str(w.get("versatile", p.damage_dice))
		p.notes.append("Versatile: two-handed")
	# Ability: Strength for melee and thrown melee weapons, Dexterity for ranged; Finesse takes the better.
	var str_mod := c.ability_mod(&"str")
	var dex_mod := c.ability_mod(&"dex")
	var is_ranged_weapon := str(w.get("kind", "")).ends_with("ranged")
	p.ability = &"dex" if is_ranged_weapon else &"str"
	if ("finesse" in p.properties or either) and dex_mod > str_mod:
		p.ability = &"dex"
	# Martial Arts (Monk): Dexterity and the Martial Arts die for Monk weapons, unarmored and without a Shield.
	var martial := ch.martial_arts_die() if ch != null else ""
	if martial != "" and Gear.is_monk_weapon(item):
		if dex_mod > c.ability_mod(p.ability):
			p.ability = &"dex"
		if Gear.average(martial) > Gear.average(p.damage_dice):
			p.damage_dice = martial
			p.notes.append("Martial Arts die")
	# Tags for `when` filters. A thrown melee weapon makes a ranged attack but isn't a Ranged weapon (Archery).
	if p.melee:
		p.tags.append("melee")
	elif as_thrown:
		p.tags.append("ranged_attack")
	else:
		p.tags.append("ranged")
	for prop: String in ["finesse", "light"]:
		if prop in p.properties:
			p.tags.append(prop)
	if as_thrown:
		p.tags.append("thrown")
	if p.melee and p.two_hands:
		p.tags.append("two_handed")
	var other_weapon := not off_free and Gear.is_weapon(off)
	if p.melee and not p.two_hands and not other_weapon:
		p.tags.append("one_handed_alone")
	p.proficient = ch.weapon_proficient(item) if ch != null else true
	if ch != null and str(item.get("base_item", p.item_id)) in ch.weapon_masteries:
		p.mastery = str(w.get("mastery", ""))
	p._apply_overrides(c)
	p._compute(c)
	return p


## `item` as `weapon_form` modifiers reshape it: the Keyholes daggers take another weapon's statistics (`form`), with
## Strength or Dexterity, whichever is better (`either_ability`); the Martialist's Quarterstaff gains the Thrown
## property and a range (`add_properties`, `range`).
static func reshaped(c: Creature, item: Dictionary) -> Dictionary:
	var out := item
	for m in c.modifiers_for(&"weapon_form"):
		if not str(item.get("id", "")) in (m.data.get("items", []) as Array):
			continue
		out = out.duplicate(true)
		var form := Compendium.shared().item_data(m.text("form")) if m.text("form") != "" else {}
		if not form.is_empty():
			out["weapon"] = (form.get("weapon", {}) as Dictionary).duplicate(true)
			out["base_item"] = str(form["id"])
			out["name"] = "%s (as %s)" % [item.get("name", ""), form.get("name", "")]
		var w := out.get("weapon", {}) as Dictionary
		var props := (w.get("properties", []) as Array).duplicate()
		for prop: Variant in m.data.get("add_properties", []):
			if not prop in props:
				props.append(prop)
		w["properties"] = props
		if m.data.has("range"):
			w["range"] = (m.data["range"] as Array).duplicate()
		out["weapon"] = w
		if bool(m.data.get("either_ability", false)):
			out["_either_ability"] = true
	return out


## Spells that reshape a weapon or an Unarmed Strike while they last (Shillelagh, Alter Self's Natural Weapons):
## `weapon_override` modifiers with items, die, ability (the spellcasting ability at casting) and damage type.
func _apply_overrides(c: Creature) -> void:
	if proficient and item_id != "unarmed_strike" and not two_hands:
		for m in c.modifiers_for(&"weapon_ability"):
			var ab := StringName(m.text("ability"))
			if ab in Abilities.ALL and c.ability_mod(ab) > c.ability_mod(ability):
				ability = ab
				notes.append(m.source_name)
	for m in c.modifiers_for(&"weapon_override"):
		var items := m.data.get("items", []) as Array
		if not item_id in items:
			continue
		if m.data.has("die"):
			damage_dice = str(m.data["die"])
		var ab := StringName(m.text("ability", ""))
		if Creature.ABILITY_NAMES.has(ab) and c.ability_mod(ab) >= c.ability_mod(ability):
			ability = ab
		if m.data.has("damage_type"):
			damage_type = StringName(m.text("damage_type"))
		notes.append(m.source_name)


## The same weapon using another ability for attack and damage (True Strike's spellcasting ability).
func with_ability(ab: StringName, c: Creature) -> WeaponProfile:
	var p := WeaponProfile.new()
	for prop: String in ["item_id", "name", "melee", "thrown", "proficient", "damage_dice", "damage_type", "mastery",
			"properties", "normal_range", "long_range", "reach", "two_hands", "ammo_id"]:
		p.set(prop, get(prop))
	p.tags = tags.duplicate()
	p.ability = ab
	p.notes = notes.duplicate()
	p._compute(c)
	return p


## Unarmed Strike: Strength modifier + Proficiency Bonus to hit, 1 + Strength modifier Bludgeoning damage.
## Martial Arts (Monk) uses its die and the better of Strength and Dexterity while unarmored without a Shield.
static func unarmed(c: Creature) -> WeaponProfile:
	var p := WeaponProfile.new()
	p.item_id = "unarmed_strike"
	p.name = "Unarmed Strike"
	p.melee = true
	p.ability = &"str"
	p.damage_dice = "1"
	p.damage_type = &"bludgeoning"
	# Tavern Brawler: 1d4. Unarmed Fighting: 1d6, or 1d8 with no weapon or Shield in hand.
	if c.has_flag("enhanced_unarmed_strike"):
		p.damage_dice = "1d4"
	if c.has_flag("unarmed_fighting"):
		var hands_free := true
		if c is Character:
			hands_free = (c as Character).equipped("main_hand").is_empty() and (c as Character).equipped("off_hand").is_empty()
		p.damage_dice = "1d8" if hands_free else "1d6"
	p.tags.assign(["melee", "unarmed"])
	p.proficient = true
	var ch := c as Character
	var martial := ch.martial_arts_die() if ch != null else ""
	if martial != "":
		if Gear.average(martial) > Gear.average(p.damage_dice):
			p.damage_dice = martial
		if c.ability_mod(&"dex") > c.ability_mod(&"str"):
			p.ability = &"dex"
		p.notes.append("Martial Arts")
	p._apply_overrides(c)
	p._compute(c)
	return p


func _compute(c: Creature) -> void:
	var situation := c.armor_situation()
	situation["weapon_tags"] = tags
	situation["item"] = item_id
	if ammo_id != "":
		situation["ammo"] = ammo_id
	var ctx := c.formula_context()
	var mod := c.ability_mod(ability)
	attack = Breakdown.new("%s attack" % name)
	attack.add("%s modifier" % Creature.ABILITY_SHORT[ability], mod)
	if proficient:
		attack.add("Proficiency", c.proficiency_bonus())
	else:
		notes.append("Not proficient")
	for m in c.modifiers_for(&"attack"):
		if m.applies_when(situation):
			attack.add_nonzero(m.source_name, c.mod_value(m, ctx))
	for m in c.modifiers_for(&"d20"):
		attack.add_nonzero(m.source_name, c.mod_value(m, ctx))
	damage_bonus = Breakdown.new("%s damage bonus" % name)
	damage_bonus.add("%s modifier" % Creature.ABILITY_SHORT[ability], mod)
	for m in c.modifiers_for(&"damage"):
		if m.applies_when(situation):
			damage_bonus.add_nonzero(m.source_name, c.mod_value(m, ctx))
	for m in c.modifiers_for(&"crit_range"):
		if not m.applies_when(situation):
			continue
		var v := c.mod_value(m, ctx)
		if v < crit_range:
			crit_range = v
	for m in c.modifiers_for(&"damage_die_min"):
		if m.applies_when(situation):
			die_minimum = maxi(die_minimum, c.mod_value(m, ctx))
			die_minimum_source = m.source_name


func average_damage() -> float:
	var parsed := DiceRoller.parse_expr(damage_dice)
	var sides := int(parsed["sides"])
	var per_die := (sides + 1) / 2.0
	if die_minimum > 0 and sides > 0:
		var t := 0.0
		for face in range(1, sides + 1):
			t += maxi(face, die_minimum)
		per_die = t / sides
	return int(parsed["count"]) * per_die + int(parsed["modifier"]) + damage_bonus.total()


## "Longsword: +5 to hit, 1d8+3 Slashing (Sap)"
func describe() -> String:
	var dmg := damage_dice
	var bonus := damage_bonus.total()
	if dmg.is_valid_int():
		dmg = str(int(dmg) + bonus)
	elif bonus != 0:
		dmg += "%+d" % bonus
	var text := "%s: %s to hit, %s %s" % [name, attack.signed(), dmg, str(damage_type).capitalize()]
	if mastery != "":
		text += " (%s)" % mastery.capitalize()
	return text
