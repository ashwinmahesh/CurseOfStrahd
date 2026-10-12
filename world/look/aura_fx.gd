class_name AuraFx
extends Node3D
## Strahd's aura round his figure on the board (owner 2026-10-09), built by CombatToken in fights and while exploring
## alike (both show creatures as CombatTokens): smoke and shadow curl up round him with a crimson edge
## (shaders/fx/aura_halo.gdshader) and he stands in a pool of shadow whose edge creeps (aura_floor.gdshader). It surges
## when he acts: an attack, a spell, a blow taken. A fire-like flicker was tried and the owner preferred this
## (2026-10-09: "I like the old auras better"). A paladin's Aura of Protection had a warm glow and its area on the floor
## too; the owner had them taken off (2026-10-12: "Remove the paladin aura visual"); the aura's save bonus is unchanged.
##
## It draws just before the sprites, after the palette pass (render priority), so the figure covers the aura's middle.

const HALO_SHADER := preload("res://shaders/fx/aura_halo.gdshader")
const FLOOR_SHADER := preload("res://shaders/fx/aura_floor.gdshader")

enum Style { DARK }

## Art ids that wear the dark aura (Strahd's own sprite; his mist form and his spawn don't).
const DARK_ART: Array[String] = ["strahd"]
## How the halo quad is sized against the figure's height: (width, height) per style. Strahd's torn cape is wide.
const HALO_SIZE := {Style.DARK: Vector2(1.9, 1.38)}
## The shadow pool's radius under Strahd, in squares per square of his size.
const POOL_RADIUS := 1.1
## A surge's decay per second (from 1: about three quarters of a second).
const SURGE_FALL := 1.4

var style: int = Style.DARK
var halo: MeshInstance3D
## The part on the ground (CombatToken tilts it along a slope with its ring).
var floor_area: MeshInstance3D
var _halo_mat: ShaderMaterial
var _floor_mat: ShaderMaterial
var _surge := 0.0
var _active := true
var _fade := 1.0
## Cosmetic randomness (each aura curls in its own way), never the dice.
static var _rng := RandomNumberGenerator.new()


## The aura `c` wears as `art` (its sprite id): DARK for Strahd's own sprite, -1 for everyone else (a paladin's Aura of
## Protection draws nothing, owner 2026-10-12).
static func style_for(_c: Combatant, art: String) -> int:
	return Style.DARK if art in DARK_ART else -1


## An aura for a figure `height` world units tall taking `size_cells` squares.
static func create(style_: int, height: float, size_cells: int) -> AuraFx:
	var a := AuraFx.new()
	a.name = "Aura"
	a.style = style_
	var seed := _rng.randf()
	var hs := HALO_SIZE[style_] as Vector2
	a._halo_mat = a._material(HALO_SHADER, seed)
	a.halo = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(hs.x * height * maxf(1.0, size_cells * 0.75), hs.y * height)
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)
	a.halo.mesh = quad
	a.halo.material_override = a._halo_mat
	a.halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(a.halo)
	a._floor_mat = a._material(FLOOR_SHADER, seed)
	a.floor_area = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var half := POOL_RADIUS * size_cells
	plane.size = Vector2(half * 2.0, half * 2.0)
	a.floor_area.mesh = plane
	# Under the base ring (0.03), which stays readable over it.
	a.floor_area.position.y = 0.02
	a.floor_area.material_override = a._floor_mat
	a.floor_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(a.floor_area)
	a._show()
	return a


func _material(shader: Shader, seed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = DirectionalSprite.RENDER_PRIORITY - 1
	m.set_shader_parameter("style", style)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("noise_tex", FxKit.noise())
	m.set_shader_parameter("shadow_col", Look.color("void"))
	m.set_shader_parameter("edge_col", Look.color("vampire_red"))
	m.set_shader_parameter("glow_col", Look.color("candle"))
	return m


## Swells the aura for a moment (he strikes, casts or is struck): `amount` 1 for a full surge.
func surge(amount: float = 1.0) -> void:
	_surge = maxf(_surge, clampf(amount, 0.0, 1.0))
	_param("surge", _surge)


## Whether the aura is up (its owner standing and conscious) and how far the figure has faded in.
func set_state(active: bool, fade: float) -> void:
	if active == _active and is_equal_approx(fade, _fade):
		return
	_active = active
	_fade = fade
	_show()


func _show() -> void:
	halo.visible = _active and _fade > 0.0
	floor_area.visible = halo.visible
	_param("fade", _fade)


func _param(param: StringName, value: float) -> void:
	_halo_mat.set_shader_parameter(param, value)
	_floor_mat.set_shader_parameter(param, value)


func _process(delta: float) -> void:
	if _surge > 0.0:
		_surge = maxf(0.0, _surge - delta * SURGE_FALL)
		_param("surge", _surge)
