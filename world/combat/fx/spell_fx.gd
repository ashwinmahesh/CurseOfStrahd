class_name SpellFx
extends Node3D
## The 3D effect a spell or ability plays when it's used in a fight (docs/art/spell_effects.md). The combat view
## (world/combat/combat_view.gd) owns one and calls it as it plays the encounter's events: `cast` once a caster's
## gesture lands (a spell, a class feature, a monster's save action), `volley` on each attack roll a missile makes,
## `smite` when a smite spell rides a hit, `on_hit` when a blow lands, `summoned` and `jumped` for creatures that
## appear or teleport. Each effect's sound is picked the same way, by family and flavour (CombatSfx).
##
## Spells and abilities that look alike share a family (bolt, beam, burst, heal, smite...); art/vfx/effects.json picks
## each one's family and flavour, and the flavour's palette colours tint it. The families are built from FxKit's parts
## in FxMissiles, FxAreas and FxBodies. Only shows things: the encounter decides everything.

const DATA := "res://art/vfx/effects.json"
## Families that fly from the caster to each target, one per attack roll when the spell or action makes them.
const MISSILES: Array[String] = ["bolt", "beam", "ray", "touch", "drain", "shot"]
## Every family with an effect.
const FAMILIES: Array[String] = ["bolt", "beam", "ray", "touch", "drain", "shot", "burst", "cone", "line", "nova", "strike",
	"cloud", "wall", "ground", "aura", "heal", "buff", "debuff", "psychic", "ward", "smite", "summon", "teleport", "transform",
	"glimmer", "slash", "pattern"]
## Damage types that take a magical look on a monster's attack (a Fire Ray is a bolt of fire; a Claw is a slash).
const MAGIC_TYPES: Array[String] = ["fire", "cold", "lightning", "thunder", "acid", "poison", "necrotic", "radiant", "force", "psychic"]

## Captures turn the effects off for their "before" shots (tools/capture/vfx_capture.gd).
static var enabled := true
static var _data: Dictionary = {}
static var _icon_picks: Dictionary = {}

var rng := RandomNumberGenerator.new()
## The missile whose flights wait for its attack rolls: {"cue", "caster"}, until the caster's next action.
var _volley: Dictionary = {}
## The last cue cast, for the creatures it summons and the jumps it makes.
var last_cue: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary
	return _data


# --- How things look ----------------------------------------------------------------------------------

## How a spell looks: {key, family, flavour, colours (name -> Color), size, count...}, or {} for nothing new.
static func spell_cue(spell_id: String) -> Dictionary:
	var s := Compendium.shared().spell_data(spell_id)
	if s.is_empty():
		# A feature shown as a spell event (Turn Undead, Breath Weapon, Elemental Burst): its look is a feature's.
		var fpick := _spec((data().get("features", {}) as Dictionary).get(spell_id, ""))
		return {} if fpick.is_empty() else _finish(fpick, spell_id)
	var spec := _spec((data().get("spells", {}) as Dictionary).get(spell_id, ""))
	if str(spec.get("family", "")) == "":
		spec["family"] = derive_family(s)
	if str(spec.get("flavour", "")) == "":
		spec["flavour"] = flavour_for_spell(spell_id, s)
	return _finish(spec, spell_id)


## How a class feature (`source` "feature", `key` its id) or a monster's action (`source` "monster", key
## "<monster>.<action>") looks.
static func ability_cue(source: String, key: String, by: Combatant) -> Dictionary:
	var table := "features" if source == "feature" else "monsters"
	var spec := _spec((data().get(table, {}) as Dictionary).get(key, ""))
	var act := _monster_action(by, key.get_slice(".", 1)) if source == "monster" else {}
	if str(spec.get("family", "")) == "" and not act.is_empty():
		spec["family"] = _derive_action_family(act)
	if str(spec.get("flavour", "")) == "":
		spec["flavour"] = _damage_flavour(act.get("damage", []) as Array, "arcane")
	return _finish(spec, key)


## How an attack looks (`action`: the attack event's, "monster:claw", "weapon:longbow@arrow"): a monster's own pick,
## else a bolt or shot for a ranged attack and a touch or slash for a melee one, in its damage type's colours.
static func attack_cue(attacker: Combatant, action: String) -> Dictionary:
	if action.begins_with("monster:"):
		var aid := action.substr(8)
		var key := MonsterActions.action_key(attacker, {"id": aid})
		var spec := _spec((data().get("monsters", {}) as Dictionary).get(key, ""))
		var act := _monster_action(attacker, aid)
		if act.is_empty() and spec.is_empty():
			return {}
		var types := act.get("damage", []) as Array
		var magic := not types.is_empty() and str((types[0] as Dictionary).get("type", "")) in MAGIC_TYPES
		var kind := str(act.get("kind", ""))
		var ranged := kind == "ranged" or (kind == "melee_or_ranged" and magic)
		if str(spec.get("family", "")) == "":
			spec["family"] = ("bolt" if magic else "shot") if ranged else ("touch" if magic else "slash")
		if str(spec.get("flavour", "")) == "":
			spec["flavour"] = _damage_flavour(types, "steel")
		return _finish(spec, key)
	if action.begins_with("weapon:") or action.begins_with("thrown:"):
		var weapons := data().get("weapons", {}) as Dictionary
		var item := Compendium.shared().item_data(action.get_slice(":", 1).get_slice("@", 0))
		var ranged := action.begins_with("thrown:") or str((item.get("weapon", {}) as Dictionary).get("kind", "")).ends_with("ranged")
		var pick: Variant = weapons.get("ranged" if ranged else "melee", "")
		if str(pick) == "":
			return {}
		return _finish(_spec(pick), action)
	return {}


static func _finish(spec: Dictionary, key: String) -> Dictionary:
	spec["key"] = key
	if not has_family(str(spec.get("family", ""))):
		return {}
	if str(spec.get("flavour", "")) == "":
		spec["flavour"] = "arcane"
	spec["colours"] = colours(str(spec["flavour"]))
	return spec


## A pick from the data as {family, flavour, size, count, ...}: "<family>", "<family>@<flavour>" or an object.
static func _spec(pick: Variant) -> Dictionary:
	if pick is Dictionary:
		return (pick as Dictionary).duplicate()
	var text := str(pick)
	if text == "":
		return {}
	return {"family": text.get_slice("@", 0), "flavour": text.get_slice("@", 1) if text.contains("@") else ""}


static func _monster_action(c: Combatant, action_id: String) -> Dictionary:
	if c == null or not c.creature is Monster:
		return {}
	var block := (c.creature as Monster).data
	for section: String in ["actions", "bonus_actions", "reactions", "lair_actions"]:
		var list: Variant = block.get(section, [])
		for a: Variant in (list as Array if list is Array else []):
			if str((a as Dictionary).get("id", "")) == action_id:
				return a as Dictionary
	return {}


## A stat-block save action's family: its area's shape (a breath's cone or line, a burst round it), else a psychic
## assault or a curse.
static func _derive_action_family(act: Dictionary) -> String:
	match str((act.get("area", {}) as Dictionary).get("shape", "")):
		"cone":
			return "cone"
		"line":
			return "line"
		"emanation", "sphere", "cube", "cylinder":
			return "nova"
	var types := act.get("damage", []) as Array
	if not types.is_empty() and str((types[0] as Dictionary).get("type", "")) == "psychic":
		return "psychic"
	return "debuff" if act.has("save") or not types.is_empty() else ""


static func _damage_flavour(parts: Array, fallback: String) -> String:
	for part: Variant in parts:
		var f := str((data()["damage_flavours"] as Dictionary).get(str((part as Dictionary).get("type", "")), ""))
		if f != "":
			return f
	return fallback


## The family a spell with no pick gets, from its data: the shape of its area, its attack roll, what it does
## (tools/vfx/assign_families.py has the fuller version that writes the picks).
static func derive_family(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	if bool(s.get("on_hit_spell", false)):
		return "smite"
	var tags := s.get("tags", []) as Array
	if "healing" in tags and (s.has("heal") or str(s.get("summary", "")).to_lower().contains("regain")):
		return "heal"
	if "summon" in tags:
		return "summon"
	var self_range := str((s.get("range", {}) as Dictionary).get("kind", "")) == "self"
	match str((s.get("area", {}) as Dictionary).get("shape", "")):
		"cone":
			return "cone"
		"line":
			return "line"
		"wall":
			return "wall"
		"emanation":
			return "nova" if str((s.get("duration", {}) as Dictionary).get("kind", "")) == "instantaneous" else "aura"
		"sphere", "cube", "cylinder":
			if self_range:
				return "nova"
			return "burst" if s.has("damage") else "cloud"
	match str(s.get("attack", "")):
		"ranged":
			return "bolt"
		"melee":
			return "touch"
	if "debuff" in tags:
		return "debuff"
	if "defense" in tags:
		return "ward"
	if "buff" in tags:
		return "buff"
	return "glimmer"


## The flavour of a spell with none picked: its icon's tint when that's a flavour, else its damage type's, else arcane.
static func flavour_for_spell(spell_id: String, s: Dictionary) -> String:
	var flavours := data()["flavours"] as Dictionary
	if _icon_picks.is_empty():
		var cat := JSON.parse_string(FileAccess.get_file_as_string("res://art/icons.json")) as Dictionary
		_icon_picks = cat.get("spells", {}) as Dictionary
	var icon := str(_icon_picks.get(Icons.spell_key(spell_id), ""))
	if icon.contains("@") and flavours.has(icon.get_slice("@", 1)):
		return icon.get_slice("@", 1)
	return _damage_flavour(s.get("damage", []) as Array, "arcane")


static func colours(flavour: String) -> Dictionary:
	var f := (data()["flavours"] as Dictionary).get(flavour, (data()["flavours"] as Dictionary)["arcane"]) as Dictionary
	var out := {}
	for k: String in f:
		out[k] = Look.color(str(f[k]))
	return out


## A flavour's palette colour names (for materials that take a name, like Look.cel).
static func colour_names(flavour: String) -> Dictionary:
	return ((data()["flavours"] as Dictionary).get(flavour, (data()["flavours"] as Dictionary)["arcane"]) as Dictionary).duplicate()


static func has_family(family: String) -> bool:
	return family in FAMILIES


## Flavours whose particles burn (ragged flame puffs) rather than glow.
static func fiery(flavour: String) -> bool:
	return flavour in ["fire", "radiant", "necrotic", "acid", "poison", "nature", "earth", "blood"]


func _init() -> void:
	name = "SpellFx"
	rng.randomize()


# --- What the view calls ------------------------------------------------------------------------------

## `cue` is used by `caster` on `targets` over `cells` (Vector2i), its gesture already landed. `attacks`: it rolls to
## hit, so a missile family waits for the attack events (`volley`). Returns when the view should go on (the missiles
## have landed, the blast is at its height).
func cast(cue: Dictionary, caster: CombatToken, targets: Array[CombatToken], cells: Array, board: ArenaBoard, attacks: bool) -> void:
	last_cue = cue
	CombatSfx.cast(cue)
	var family := str(cue["family"])
	var others: Array[CombatToken] = []
	for t in targets:
		if t != caster:
			others.append(t)
	if family in MISSILES and attacks:
		_volley = {"cue": cue, "caster": caster.combatant.id}
		return
	match family:
		"bolt", "beam", "ray", "touch", "drain", "shot":
			await _missiles(family, cue, caster, others)
		"burst":
			# A spell with no area of its own that bursts round its target (Detonate) blows up where the targets stand.
			await FxAreas.burst(self, cue, caster, cells if not cells.is_empty() else _cells_at(others), board)
		"cone":
			await FxAreas.cone(self, cue, caster, cells if not cells.is_empty() else _cells_at(others), board)
		"line":
			await FxAreas.line(self, cue, caster, cells if not cells.is_empty() else _cells_at(others), board)
		"nova":
			await FxAreas.nova(self, cue, caster, cells, board)
		"aura":
			await FxAreas.aura(self, cue, caster, cells, board)
		"strike":
			await FxAreas.strike(self, cue, caster, others, cells, board)
		"cloud":
			await FxAreas.cloud(self, cue, caster, cells, board)
		"pattern":
			await FxAreas.pattern(self, cue, caster, cells, board)
		"wall":
			await FxAreas.wall(self, cue, caster, cells, board)
		"ground":
			await FxAreas.ground(self, cue, caster, cells, board)
		"summon":
			if not cells.is_empty():
				var ex := FxAreas.extent(cells, board)
				FxBodies.summon(self, cue, ex["mid"] as Vector3, clampf(float(ex["radius"]) / 1.5, 0.7, 2.0))
			else:
				FxBodies.glimmer(self, cue, caster)
			await wait(0.3)
		"teleport":
			FxBodies.glimmer(self, cue, caster)
			for t in others:
				FxBodies.blink(self, cue, t.global_position, false)
			await wait(0.15)
		"smite":
			for t in others:
				FxBodies.smite(self, cue, caster, t)
			await wait(0.2)
		"slash":
			for t in others:
				FxBodies.slash(self, cue, caster, t, false)
			await wait(0.15)
		"glimmer":
			FxBodies.glimmer(self, cue, caster)
			await wait(0.1)
		_:
			# Effects on creatures: on the targets, or on the caster for a spell on itself.
			var on: Array[CombatToken] = targets.duplicate()
			if on.is_empty():
				on.append(caster)
			for t in on:
				match family:
					"heal":
						FxBodies.heal(self, cue, t)
					"buff":
						FxBodies.buff(self, cue, t)
					"debuff":
						FxBodies.debuff(self, cue, caster, t)
					"psychic":
						FxBodies.psychic(self, cue, caster, t)
					"ward":
						FxBodies.ward(self, cue, t)
					"transform":
						FxBodies.transform(self, cue, t)
				await wait(0.06)
			await wait(0.3 if family in ["heal", "buff", "debuff", "psychic"] else 0.15)


## A missile family flies to each target (Magic Missile's darts: `count` of them at a lone target); a chain jumps on
## from target to target (Chain Lightning).
func _missiles(family: String, cue: Dictionary, caster: CombatToken, others: Array[CombatToken]) -> void:
	if others.is_empty():
		FxBodies.glimmer(self, cue, caster)
		return
	var shots: Array[CombatToken] = []
	var count := int(cue.get("count", 1))
	for t in others:
		for i in (count if others.size() == 1 else 1):
			shots.append(t)
	var last: Signal
	var from := caster
	for t in shots:
		var to := SpellFx.chest(t) + _spread(count)
		var start := SpellFx.hand(from, to) if from == caster else SpellFx.chest(from)
		last = FxMissiles.fly(self, family, cue, start, to, true)
		if bool(cue.get("chain", false)):
			await last
			from = t
		else:
			await wait(0.09)
	await last


func _spread(count: int) -> Vector3:
	if count <= 1:
		return Vector3.ZERO
	return Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.15, 0.15))


func _cells_at(tokens: Array[CombatToken]) -> Array:
	var out: Array = []
	for t in tokens:
		out.append(t.combatant.cell)
	return out


## The volley's caster rolls an attack at `target` (`action`: the attack event's): true when a missile flew for it
## (and has landed), so the view skips its lunge.
func volley(attacker: CombatToken, target: CombatToken, hit: bool, action: String = "") -> bool:
	if _volley.is_empty() or str(_volley["caster"]) != attacker.combatant.id or target == null:
		return false
	var cue := _volley["cue"] as Dictionary
	if action != "" and action != "spell:" + str(cue["key"]):
		return false
	await missile(cue, attacker, target, hit)
	return true


## One missile of `cue`'s family from `attacker` at `target` (a monster's Fire Ray, an arrow).
func missile(cue: Dictionary, attacker: CombatToken, target: CombatToken, hit: bool) -> void:
	var to := SpellFx.chest(target)
	await FxMissiles.fly(self, str(cue["family"]), cue, SpellFx.hand(attacker, to), to, hit)


## The volley is over (the caster's turn or next action began).
func end_volley() -> void:
	_volley = {}


## A smite spell (`spell_id`) rides `caster`'s hit on `target`.
func smite(spell_id: String, caster: CombatToken, target: CombatToken) -> void:
	var cue := spell_cue(spell_id)
	if cue.is_empty() or target == null:
		return
	FxBodies.smite(self, cue, caster, target)
	CombatSfx.impact(cue)
	await wait(0.18)


## A blow from `attacker` lands on `target` (a slash or touch cue from `attack_cue`).
func on_hit(cue: Dictionary, attacker: CombatToken, target: CombatToken, critical: bool) -> void:
	if str(cue["family"]) == "slash":
		FxBodies.slash(self, cue, attacker, target, critical)
	else:
		FxMissiles.impact(self, cue, SpellFx.chest(target), 0.7)


## A creature appeared (summoned, conjured, called): a circle opens under it in the last cast's colours.
func summoned(t: CombatToken) -> void:
	var cue := last_cue if not last_cue.is_empty() else _finish({"family": "summon", "flavour": "arcane"}, "summon")
	FxBodies.summon(self, cue, t.global_position, clampf(float(t.combatant.size_cells), 1.0, 3.0))


## A creature jumps through space from `from` to `to` (world points on the floor).
func jumped(from: Vector3, to: Vector3) -> void:
	var cue := last_cue if str(last_cue.get("family", "")) == "teleport" else _finish({"family": "teleport", "flavour": "arcane"}, "teleport")
	FxBodies.blink(self, cue, from, false)
	FxBodies.blink(self, cue, to, true)
	CombatSfx.arrive(cue)


# --- Helpers the families share -----------------------------------------------------------------------

static func height_of(t: CombatToken) -> float:
	var aid := t.art_override if t.art_override != "" else CombatToken.art_id(t.combatant)
	return CombatToken.height_for(aid) * maxf(1.0, t.scale.y)


## The caster's casting hand, a little toward `toward`.
static func hand(t: CombatToken, toward: Vector3) -> Vector3:
	var flat := Vector3(toward.x - t.global_position.x, 0, toward.z - t.global_position.z)
	var d := flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	return t.global_position + Vector3(0, height_of(t) * 0.6, 0) + d * 0.3


static func chest(t: CombatToken) -> Vector3:
	return t.global_position + Vector3(0, height_of(t) * 0.55, 0)


## The combat speed setting: effects play faster in fast combat.
func pace() -> float:
	return GameSettings.combat_pace()


## A timer's signal `seconds` (at the combat speed) from now.
func wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds * pace(), false).timeout


## Adds a one-shot emitter at `at` (under `parent`, else here) and fires it.
func emit(p: GPUParticles3D, at: Vector3, parent: Node3D = null) -> GPUParticles3D:
	(parent if parent != null else self).add_child(p)
	p.global_position = at
	FxKit.fire(p)
	return p


## Fades `mi`'s material in over `fade_in`, holds, fades out over `fade_out` (seconds, at the combat speed), then
## frees it.
func pulse(mi: GeometryInstance3D, fade_in: float, hold: float, fade_out: float) -> void:
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("fade", 0.0)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 0.0, 1.0, maxf(0.01, fade_in * pace()))
	tw.tween_interval(hold * pace())
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), 1.0, 0.0, fade_out * pace())
	tw.tween_callback(mi.queue_free)


## A lone camera-facing quad of light (a missile's core and halo).
func quad(parent: Node3D, size: float, shape: int, colour: Color, core: Color, energy: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := FxKit.glow_material(shape, core, energy)
	m.set_shader_parameter("tint", colour)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A short shake of the camera for something big, by its view offset so the rig is untouched.
func shake(strength: float, seconds: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := 7
	for i in steps:
		var k := 1.0 - float(i) / float(steps)
		tw.tween_property(cam, "h_offset", rng.randf_range(-1.0, 1.0) * strength * k, seconds / float(steps))
		tw.parallel().tween_property(cam, "v_offset", rng.randf_range(-1.0, 1.0) * strength * k, seconds / float(steps))
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)
