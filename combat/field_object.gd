class_name FieldObject
extends RefCounted
## Something a spell puts on the battlefield that isn't a creature (ADR 0007): Spiritual Weapon's spectral
## weapon, Flaming Sphere, Dancing Lights, and lingering areas such as Cloud of Daggers, Spirit Guardians, Web,
## Fog Cloud or Darkness. It has an owner, an anchor square, the squares it covers, the Concentration or duration
## that keeps it, and the spell's `zone` rules (what it does to creatures, terrain, sight, sound). SpellZones runs
## the rules; the scene draws it from `kind` and `cells`.

enum Kind { ZONE, WEAPON, SPHERE, LIGHTS, HAND, ILLUSION }

static var _next_id: int = 1

var id: String
var kind: Kind = Kind.ZONE
var spell_id: String = ""
var name: String = ""
var caster_id: String = ""
## Anchor square (the weapon or sphere's square, the area's point of origin).
var cell: Vector2i = Vector2i.ZERO
## A point of origin between squares (spheres and cylinders are centred on grid points).
var origin: Vector2 = Vector2.ZERO
var cells: Array[Vector2i] = []
## Emanations move with their caster.
var follows_caster: bool = false
var slot: int = 0
var save_dc: int = 10
## The spell's zone rules: {triggers, save, damage, half, conditions, terrain, obscured, ...} (spell schema).
var rules: Dictionary = {}
## Creatures it won't affect (Spirit Guardians' chosen creatures).
var spared: Array[String] = []
## Creature id -> turn key of the last time it was affected (most zones affect a creature once per turn).
var hit_on_turn: Dictionary = {}
## Rounds left (counted at the start of the caster's turn); -1 = as long as the Concentration lasts.
var rounds_left: int = -1
var concentration: Concentration:
	get:
		return _concentration.get_ref() as Concentration if _concentration != null else null
	set(value):
		_concentration = weakref(value) if value != null else null
var _concentration: WeakRef = null
var _needs_concentration: bool = false
var ended: bool = false


func _init(kind_: Kind = Kind.ZONE, spell_id_: String = "", name_: String = "") -> void:
	id = "obj_%d" % _next_id
	_next_id += 1
	kind = kind_
	spell_id = spell_id_
	name = name_


func keep_with(conc: Concentration) -> FieldObject:
	concentration = conc
	_needs_concentration = conc != null
	return self


## True once its Concentration has ended or its time ran out.
func expired() -> bool:
	if ended:
		return true
	if _needs_concentration and (concentration == null or concentration.ended):
		return true
	return rounds_left == 0


func covers(c: Combatant) -> bool:
	# An aura for "you and your allies" (Aura of Life, Crusader's Mantle) includes the caster's own space.
	if follows_caster and c.id == caster_id and str(rules.get("affects", "")) == "allies":
		return true
	for cell_ in c.footprint():
		if cell_ in cells:
			return true
	return false


func rule(key: String, default: Variant = null) -> Variant:
	return rules.get(key, default)


func has_trigger(trigger: String) -> bool:
	return trigger in (rules.get("triggers", []) as Array)


static func kind_name(k: Kind) -> String:
	return ["zone", "weapon", "sphere", "lights", "hand", "illusion"][k]
