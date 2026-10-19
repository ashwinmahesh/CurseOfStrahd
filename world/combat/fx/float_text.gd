class_name FloatText
extends RefCounted
## A number or word rising over a creature and fading: the damage, healing and miss marks of a fight (CombatView) and
## the damage a trap or a fall does outside one (LocationHurt). One look for both, so a hit reads the same wherever it lands.

## How long a mark stays over a creature (seconds), how far it rises (world units) and how long its fade takes at the end.
const TIME := 2.4
const RISE := 0.6
const FADE := 0.7


## `text` rising over `t` in the palette colour `colour` (damage a little bigger: `size`), under `parent` (the node the
## token stands in). Null, and nothing shown, over a creature nobody sees: a number over an Invisible foe would show where
## it stands.
static func rise(parent: Node3D, t: CombatToken, text: String, colour: String, size: int = 52) -> Label3D:
	if t.unseen:
		return null
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Look.color(colour)
	l.outline_modulate = Look.color("void")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 11
	parent.add_child(l)
	l.global_position = t.global_position + Vector3(0, CombatToken.height_of(t.combatant) + 0.2, 0)
	var tw := parent.create_tween()
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, RISE, 0), TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, FADE).set_delay(TIME - FADE)
	tw.tween_callback(l.queue_free)
	return l
