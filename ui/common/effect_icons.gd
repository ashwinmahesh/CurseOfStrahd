class_name EffectIcons
extends RefCounted
## What's working on a hero right now, as small icons with the name on hover (owner request, 2026-10-08): the spell
## they're concentrating on, ringed in moonlight; abilities they've switched on (Rage, Bladesong, Vow of Enmity, Sacred
## Weapon, Innate Sorcery...: art/icons.json "features", a rune tile for the rest); spells on them (Bless, Haste, Mage
## Armor, a Hex or Hunter's Mark on them) and items' powers, in those spells' and items' own icons; and a beast's shape.
## One icon per source. Conditions keep their tags, so an effect that only gives a condition (Hold Person's Paralyzed)
## shows there instead. The party frames show them exploring (ExploreHud) and in fights (CombatHud).

## Effects that aren't abilities: the difficulty mode's bonus and the class features' standing effect.
const SKIP: Array[String] = ["difficulty", "class_standing"]
const RING := "moonlight"


## [{key, name, when, icon: Texture2D, concentration: bool}], the concentration first.
static func entries(cr: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	var conc := cr.concentration
	if conc != null and not conc.ended:
		var sid := conc.source_id.get_slice(":", 0)
		var spell := not Compendium.shared().spell_data(sid).is_empty()
		out.append({"key": "conc:" + sid, "name": conc.name, "concentration": true,
			"when": "Concentration" + ("" if conc.rounds_left < 0 else " · " + _rounds(conc.rounds_left)),
			"icon": Icons.spell(sid) if spell else Icons.feature(sid)})
		seen["spell:" + sid] = true
		seen["feature:" + sid] = true
	if cr is Monster and (cr as Monster).data.has("shape_of"):
		out.append({"key": "shape", "name": "In the shape of %s" % _a((cr as Monster).data.get("name", "a beast")),
			"when": "", "icon": Icons.feature("shape_change"), "concentration": false})
	for fx: Effect in cr.effects:
		var sid := fx.source_id.get_slice(":", 0)
		var key := "%s:%s" % [fx.source_kind, sid]
		if sid in SKIP or seen.has(key) or (fx.modifiers.is_empty() and not fx.conditions.is_empty()):
			continue
		seen[key] = true
		var icon: Texture2D = null
		match fx.source_kind:
			&"spell":
				icon = Icons.spell(sid)
			&"item":
				icon = Icons.item(sid)
		if icon == null:
			icon = Icons.feature(sid)
		out.append({"key": key, "name": fx.name, "when": _when(fx), "icon": icon, "concentration": false})
	return out


## The icons in a wrapping row, `side` pixels each, or null when nothing is on the creature.
static func row(cr: Creature, side: float = 22.0) -> Control:
	var list := entries(cr)
	if list.is_empty():
		return null
	var flow := HFlowContainer.new()
	flow.name = "EffectIcons"
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in list:
		flow.add_child(icon(e, side))
	return flow


## One icon; resting the pointer on it names it, with how long it has left.
static func icon(e: Dictionary, side: float) -> Control:
	var tex := e["icon"] as Texture2D
	var conc := bool(e["concentration"])
	var d := UiParts.drawn(Vector2(side, side), func(c: Control) -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		if tex != null:
			c.draw_texture_rect(tex, r.grow(-2.0 if conc else 0.0), false)
		if conc:
			c.draw_arc(r.get_center(), side / 2.0 - 0.5, 0.0, TAU, 32, Look.color(RING), 1.6, true))
	d.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	d.name = str(e["key"]).validate_node_name()
	var title := str(e["name"])
	var when := str(e["when"])
	return UiParts.tipped(d, func() -> Control: return UiParts.rules_tip(title, when, ""), title)


static func _when(fx: Effect) -> String:
	match fx.ends:
		Effect.Ends.ROUNDS:
			return _rounds(fx.rounds_left)
		Effect.Ends.MINUTES:
			return "%d minute%s left" % [fx.minutes_left, "" if fx.minutes_left == 1 else "s"] if fx.minutes_left > 0 else ""
		Effect.Ends.START_OF_TURN, Effect.Ends.END_OF_TURN:
			return "Until their next turn"
		Effect.Ends.SHORT_REST:
			return "Until a rest"
		Effect.Ends.LONG_REST:
			return "Until a Long Rest"
	return ""


static func _rounds(n: int) -> String:
	if n >= Effect.ROUNDS_PER_MINUTE and n % Effect.ROUNDS_PER_MINUTE == 0:
		var m := n / Effect.ROUNDS_PER_MINUTE
		return "%d minute%s left" % [m, "" if m == 1 else "s"]
	return "%d round%s left" % [n, "" if n == 1 else "s"]


static func _a(name_text: String) -> String:
	return ("an " if name_text.left(1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + name_text
