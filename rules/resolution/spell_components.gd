class_name SpellComponents
extends RefCounted
## Hand access and class-specific focus eligibility. Ordinary components remain assumed carried;
## a focus never substitutes for a priced or consumed Material component.

static func focus_source(ch: Character, item: Dictionary, class_id: String) -> String:
	if item.is_empty() or class_id == "" or ch.class_level_of(class_id) <= 0:
		return ""
	var casting := ch.compendium.class_data(class_id).get("spellcasting", {}) as Dictionary
	var focus := str(casting.get("focus", "musical_instrument" if class_id == "bard" else ""))
	if focus != "" and str(item.get("focus", "")) == focus:
		return str(item["name"])
	if focus == "musical_instrument" and str((item.get("tool", {}) as Dictionary).get("kind", "")) == focus:
		return str(item["name"])
	if class_id == "wizard" and str(item.get("id", "")) == "spellbook":
		return str(item["name"])
	for m in ch.modifiers_for(&"spellcasting_focus"):
		if m.text("class") != class_id:
			continue
		var weapon := item.get("weapon", {}) as Dictionary
		if weapon.is_empty() or not str(weapon.get("kind", "")).ends_with(m.text("weapon_kind")):
			continue
		if bool(m.data.get("proficient", false)) and not ch.weapon_proficient(item):
			continue
		return "%s (%s)" % [item["name"], m.source_name]
	return ""

static func can_replace_material(components: Dictionary) -> bool:
	return str(components.get("m", "")) != "" and int(components.get("m_cost_gp", 0)) == 0 and not bool(components.get("m_consumed", false))

static func effective(spell: Dictionary, metamagic: Array = [], omit_material: bool = false) -> Dictionary:
	var out := (spell.get("components", {}) as Dictionary).duplicate(true)
	var subtle := "subtle" in metamagic or "psionic_sorcery" in metamagic
	if subtle or ("psychic_spells" in metamagic and str(spell.get("school", "")) in ["enchantment", "illusion"]):
		out.erase("s")
		out.erase("v")
	if omit_material or (subtle and can_replace_material(out)):
		for key: String in ["m", "m_cost_gp", "m_consumed"]:
			out.erase(key)
	return out

static func hand_reason(ch: Character, components: Dictionary, class_id: String) -> String:
	var main := ch.equipped("main_hand")
	var off := ch.equipped("off_hand")
	# A Two-Handed weapon needs both hands only for its attack, so it can be held in one while casting.
	var free_hand := main.is_empty() or off.is_empty()
	if free_hand:
		return ""
	var material := str(components.get("m", "")) != ""
	var held_focus := can_replace_material(components) and (focus_source(ch, main, class_id) != "" or focus_source(ch, off, class_id) != "")
	if material and not held_focus:
		return "Components: free a hand for the Material component"
	if bool(components.get("s", false)) and not held_focus and not ch.has_flag("war_caster_somatic_components"):
		return "Components: free a hand for the Somatic component"
	return ""

static func known_hand_reason(ch: Character, spell: Dictionary, components: Dictionary) -> String:
	var reason := ""
	for known in ch.known_spells():
		if str(known["id"]) != str(spell["id"]):
			continue
		reason = hand_reason(ch, components, str(known.get("class_id", "")))
		if reason == "":
			return ""
	return reason


## Stowing an ordinary held item uses the turn's free object interaction. A Shield can't be stowed this way.
static func plan(ch: Character, components: Dictionary, class_id: String, may_stow: bool) -> Dictionary:
	var reason := hand_reason(ch, components, class_id)
	if reason == "":
		return {"reason": "", "stow": ""}
	if may_stow:
		for slot: String in ["off_hand", "main_hand"]:
			var item := ch.equipped(slot)
			if not item.is_empty() and not Gear.is_shield(item):
				return {"reason": "", "stow": slot, "item": str(item["name"])}
	return {"reason": reason, "stow": ""}

static func known_plan(ch: Character, spell: Dictionary, components: Dictionary, may_stow: bool) -> Dictionary:
	var result := {"reason": "Spell is not known", "stow": ""}
	for known in ch.known_spells():
		if str(known["id"]) != str(spell["id"]):
			continue
		result = plan(ch, components, str(known.get("class_id", "")), may_stow)
		if str(result["reason"]) == "":
			return result
	return result
