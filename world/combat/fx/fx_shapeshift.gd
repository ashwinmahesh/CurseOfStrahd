class_name FxShapeshift
extends RefCounted
## A creature changing shape (docs/art/spell_effects.md): the one effect every shapeshifter shares, whatever changes
## it: Polymorph and Wild Shape, a vampire's bat, wolf and mist, a lycanthrope's hybrid. The combat view swaps the
## figure on a "form" or "shape" event (CombatView._swap_form_art), and SpellFx.shape_gather plays `gather` (and the
## change's sound, CombatSfx.shapeshift) before the swap, so the old figure is seen to change, and SpellFx.shape_settle
## plays `settle` after it, so the new one arrives in a flash. `kind`, the event's "kind", is how the change looks and
## sounds: LOOKS below, and art/audio.json "combat" "shapeshift". A kind with no look gets the default's, so a new
## shapeshifter needs only to emit the event. Only shows things: the encounter decides everything.

## Seconds, at the combat speed, that the old figure gathers before it changes, and that the new one takes to arrive.
const GATHER := 0.3
const SETTLE := 0.28

## How each kind of change looks. flavour: its palette (art/vfx/effects.json); tint: the colour the old figure flares
## in; shards: streaks flung out as the new figure lands (fur, feathers, sparks); puffs and density: its smoke; shake:
## the camera's jolt, for a body that breaks and re-forms.
const LOOKS := {
	"werewolf": {"flavour": "moon", "tint": "frost", "shards": 30, "puffs": 12, "density": 0.55, "shake": 0.05},
	"wereraven": {"flavour": "shadow", "tint": "orchid", "shards": 26, "puffs": 10, "density": 0.55, "shake": 0.02},
	"bat": {"flavour": "shadow", "tint": "plum", "shards": 16, "puffs": 8, "density": 0.5, "shake": 0.0},
	"wolf": {"flavour": "shadow", "tint": "orchid", "shards": 24, "puffs": 10, "density": 0.55, "shake": 0.03},
	"mist": {"flavour": "cold", "tint": "mist_blue", "shards": 0, "puffs": 22, "density": 0.9, "shake": 0.0},
	"wild_shape": {"flavour": "nature", "tint": "bile", "shards": 22, "puffs": 8, "density": 0.5, "shake": 0.03},
	"polymorph": {"flavour": "arcane", "tint": "lilac", "shards": 22, "puffs": 8, "density": 0.5, "shake": 0.0},
	"swarm": {"flavour": "earth", "tint": "tan", "shards": 0, "puffs": 18, "density": 0.7, "shake": 0.0},
	"disguise": {"flavour": "illusion", "tint": "lilac", "shards": 14, "puffs": 8, "density": 0.45, "shake": 0.0},
	# A person the story showed turning out to be something else (LocationFights._reveal; a stat block's `reveal`).
	"hag": {"flavour": "poison", "tint": "sickly", "shards": 18, "puffs": 14, "density": 0.6, "shake": 0.03},
	"undead": {"flavour": "necrotic", "tint": "bile", "shards": 16, "puffs": 14, "density": 0.65, "shake": 0.02},
	"fiend": {"flavour": "fire", "tint": "ember", "shards": 26, "puffs": 12, "density": 0.6, "shake": 0.05},
	"celestial": {"flavour": "radiant", "tint": "wick", "shards": 28, "puffs": 8, "density": 0.4, "shake": 0.03},
	"default": {"flavour": "arcane", "tint": "lilac", "shards": 20, "puffs": 8, "density": 0.5, "shake": 0.0},
}


static func look(kind: String) -> Dictionary:
	return LOOKS.get(kind, LOOKS["default"]) as Dictionary


## The old figure gathers itself to change: a circle closes on its feet, motes spiral up round it and it flares in the
## kind's colour for the beat the view waits before it swaps the figure.
static func gather(fx: SpellFx, t: CombatToken, kind: String) -> void:
	var l := look(kind)
	var cols := SpellFx.colours(str(l["flavour"]))
	var feet := t.global_position
	var h := SpellFx.height_of(t)
	var circle := FxKit.ring(fx, feet, 1.5, cols, 0.8, 2.2)
	var cm := circle.material_override as ShaderMaterial
	cm.set_shader_parameter("width", 0.05)
	cm.set_shader_parameter("spin", 1.4)
	FxKit.tween_param(circle, "radius", 0.75, 0.2, GATHER * fx.pace())
	fx.pulse(circle, 0.05, 0.15, 0.2)
	var spiral := FxKit.particles({"amount": 44, "lifetime": 0.6, "emit": "ring", "radius": 0.5, "inner": 0.4, "explosiveness": 0.15,
		"dir": Vector3.UP, "spread": 3.0, "speed": Vector2(h * 1.5, h * 2.0), "damping": Vector2(h, h * 1.3), "orbit": Vector2(1.4, 1.8),
		"size": 0.17, "colours": [cols["core"], cols["glow"], cols["edge"]], "material": FxKit.glow_material(FxKit.Shape.GLOW, cols["core"], 2.6)})
	fx.emit(spiral, feet + Vector3(0, 0.05, 0))
	t.flash(Look.color(str(l["tint"])), GATHER * fx.pace())


## The new figure is in place: a flash and a burst of smoke, streaks and glints from it, and it comes into view.
static func settle(fx: SpellFx, t: CombatToken, kind: String) -> void:
	var l := look(kind)
	var cols := SpellFx.colours(str(l["flavour"]))
	var at := SpellFx.chest(t)
	var big := clampf(SpellFx.height_of(t) / 1.3, 0.7, 2.0)
	FxKit.flash(fx, at, cols["light"], 4.5, 3.6 * big, 0.03, 0.5)
	if int(l["puffs"]) > 0:
		var smoke := FxKit.particles({"amount": int(l["puffs"]), "lifetime": 0.9, "emit": "sphere", "radius": 0.35 * big, "speed": Vector2(0.4, 1.2),
			"damping": Vector2(1.5, 2.5), "size": 0.9 * big, "grow": FxKit.curve(0.4, 1.0, 1.2, 0.3), "fade_in": true,
			"colours": [Color(cols["smoke"], 0.7), Color(cols["edge"], 0.35)], "material": FxKit.smoke_material(float(l["density"]))})
		fx.emit(smoke, at)
	if int(l["shards"]) > 0:
		var shards := FxKit.particles({"amount": int(l["shards"]), "lifetime": 0.45, "emit": "sphere", "radius": 0.2 * big,
			"speed": Vector2(1.8, 4.2), "damping": Vector2(2.0, 4.0), "gravity": Vector3(0, -3.0, 0), "size": Vector2(0.03, 0.18), "align": true,
			"colours": [cols["core"], cols["glow"]], "material": FxKit.glow_material(FxKit.Shape.STREAK, cols["core"], 3.0, false)})
		fx.emit(shards, at)
	var glints := FxKit.particles({"amount": 18, "lifetime": 0.7, "emit": "sphere", "radius": 0.3 * big, "speed": Vector2(0.3, 1.1),
		"damping": Vector2(0.8, 1.6), "size": 0.15, "colours": [cols["core"], cols["glow"], cols["edge"]],
		"material": FxKit.glow_material(FxKit.Shape.GLINT, cols["core"], 3.0)})
	fx.emit(glints, at)
	if float(l["shake"]) > 0.0:
		fx.shake(float(l["shake"]), 0.2)
	t.emerge(0.0, SETTLE * fx.pace())
