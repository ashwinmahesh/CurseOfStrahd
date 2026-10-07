class_name CombatToken
extends Node3D
## A creature on the combat field: its 8-direction sprite (art/sprites/<id>/walk.tres and attack.tres from the Gemini
## pipeline, docs/art/animation.md) or a
## placeholder capsule, a base ring in its side's colour (party gold, enemies red, guests moonlight blue), a thin
## health bar (exact for the party, only Bloodied for enemies, per the combat view spec), its name and its
## conditions. It only shows state; the encounter decides everything.

## Sprite height in world units (1 unit = 5 ft) by creature, so a halfling stands half a human's height.
const HEIGHTS := {"ilse_varga": 1.3, "tamsin_tealeaf": 0.75, "hedda_ironvow": 1.0, "silvain_aster": 1.25,
	"godrick_pendlebrook": 1.55, "liriel_dawnsong": 1.18, "thistle": 1.22, "ratatoille": 1.24, "wren_featherfoot": 0.74,
	"kip_smudgewick": 1.28,
	"zombie": 1.25, "wolf": 0.8, "dire_wolf": 1.35, "ismark": 1.32, "ireena": 1.2, "rose": 0.9, "thorn": 0.75,
	"donavich": 1.15, "bildrath": 1.2, "parriwimple": 1.45, "mad_mary": 1.15, "morgantha": 1.1, "strahd": 1.4,
	"ghoul": 1.15, "ghast": 1.2, "specter": 1.25, "shadow": 1.2, "cultist": 1.2, "animated_armor": 1.3,
	"animated_flying_sword": 0.8, "broom_of_animated_attack": 1.0, "grick": 0.9, "shambling_mound": 1.7,
	"swarm_of_rats": 0.45, "vampire_spawn": 1.25, "strahd_zombie": 1.25, "commoner": 1.2, "noble": 1.25,
	"villager": 1.2, "madam_eva": 1.05, "baron_vargas": 1.25, "izek": 1.4, "lady_wachter": 1.22, "father_lucian": 1.25,
	"rictavio": 1.38, "blinsky": 1.2, "urwin_martikov": 1.28, "danika_martikov": 1.2, "arrigal": 1.3,
	"victor_vallakovich": 1.15, "lydia_petrovna": 1.18, "vallaki_guard": 1.45, "vistana": 1.22, "milivoj": 1.3, "henrik": 1.22,
	"gunther_arasek": 1.3, "luvash": 1.38, "arabelle": 0.75, "bluto": 1.22, "kasimir_velikov": 1.32, "stanimir": 1.38,
	"alenka": 1.25, "mirabel": 1.22, "sorvia": 1.15, "arik": 1.25, "doru": 1.22, "gustav_durst": 1.3, "elisabeth_durst": 1.25,
	"durst_nursemaid": 1.2, "lorghoth": 1.9, "cult_shades": 1.3,
	"ezmerelda": 1.25, "sir_godfrey_gwilym": 1.42, "vladimir_horngaard": 1.4, "davian_martikov": 1.24,
	"emil_toranescu": 1.38, "mordenkainen": 1.25, "baba_lysaga": 0.95, "exethanter": 1.28, "vosk": 1.24,
	"abbot": 1.3, "vasilka": 1.22, "kiril_stoyanovich": 1.45, "zuleika_toranescu": 1.25, "ilinca_vrana": 1.1,
	"bella_sunbane": 1.2, "offalia_wormwiggle": 1.15, "ruxandra": 1.1, "adrian_martikov": 1.3,
	"stefania_martikov": 1.2, "kostin": 1.25, "dmitri_krezkov": 1.32, "anna_krezkova": 1.1, "ilya_krezkov": 0.8,
	"kasha_varo": 0.95, "krezk_guard": 1.3, "clovin_belview": 1.1, "belview": 1.15, "mirela": 0.85,
	"ilka_sarnov": 0.82, "toma_sarnov": 0.65, "order_knight": 1.32, "phantom_warden": 1.3, "tsolenka_sergeant": 1.3,
	"tsolenka_watchman": 1.28, "patrina_velikovna": 1.25, "amber_sentinel": 2.3, "argynvost_echo": 1.7,
	"sergei_von_zarovich": 1.3,
	"amber_golem": 2.0, "arcanaloth": 1.35, "baba_lysagas_creeping_hut": 3.0, "banshee": 1.25, "deva": 1.45,
	"flameskull": 0.6, "flesh_golem": 1.6, "gargoyle": 1.3, "ghost": 1.25, "giant_spider": 1.3,
	"mongrelfolk": 1.2, "mummy": 1.3, "needle_blight": 1.2, "night_hag": 1.15, "nothic": 1.0, "ogre": 2.1,
	"phantom_warrior": 1.35, "revenant": 1.3, "roc": 3.0, "scarecrow": 1.35, "swarm_of_bats": 1.0,
	"swarm_of_insects": 0.6, "swarm_of_ravens": 0.9, "tree_blight": 3.0, "twig_blight": 0.7, "vine_blight": 1.1,
	"werewolf": 1.45, "wereraven": 1.3, "wight": 1.3, "will_o_wisp": 0.5, "wraith": 1.35, "berserker": 1.3,
	"raven": 0.35,
	"air_elemental": 2.0, "ape": 1.2, "axe_beak": 1.7, "baboon": 0.6, "badger": 0.35, "bat": 0.3,
	"black_bear": 1.0, "boar": 0.8, "brown_bear": 1.4, "djinni": 2.0, "earth_elemental": 2.0, "efreeti": 2.1,
	"elephant": 2.8, "fire_elemental": 2.0, "giant_badger": 0.7, "giant_boar": 1.3,
	"giant_constrictor_snake": 1.2, "giant_elk": 2.3, "giant_fly": 1.0, "giant_goat": 1.4, "giant_hyena": 1.2,
	"giant_owl": 1.6, "giant_rat": 0.5, "giant_weasel": 0.6, "goat": 0.8, "griffon": 1.7, "jackal": 0.55,
	"lion": 1.1, "mastiff": 0.75, "nightmare": 1.7, "owl": 0.35, "panther": 0.8, "rat": 0.25, "rhinoceros": 1.5,
	"saber_toothed_tiger": 1.2, "tiger": 1.1, "water_elemental": 2.0, "weasel": 0.25,
	"mimic": 0.9}

var combatant: Combatant
var art_override := ""
var sprite: DirectionalSprite
## The figure lying on the ground (Prone, or at 0 Hit Points): the front view laid flat.
var _lying: Sprite3D
var body: Node3D
var _ring: MeshInstance3D
var _active_ring: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_back: MeshInstance3D
var _label: Label3D
var _status: Label3D
var _flash := 0.0
var _flash_color := Color.WHITE
var _base_modulate := Color.WHITE
var _active := false
var _highlight := false
## How far the creature has come into view (0 to 1): a fight's foes fade in as it starts and its survivors fade out
## as it ends (emerge, fade_away), rather than popping.
var _fade := 1.0


static func art_id(c: Combatant) -> String:
	return art_for(c.creature)


## The sprite and portrait id for a creature: a monster's stat block id, a character's chosen look (creation's
## Appearance step), or its name.
static func art_for(cr: Creature) -> String:
	if cr is Monster:
		var data := (cr as Monster).data
		return str(data.get("art", data.get("id", "")))
	if cr is Character:
		if HeroLook.is_custom(cr as Character):
			return HeroLook.register(cr as Character)
		var look := str(((cr as Character).build.get("appearance", {}) as Dictionary).get("art", ""))
		if look != "":
			return look
		# A pregen with art of its own (the six on the roster) wears it; anyone else borrows a look by class.
		for own: String in [cr.id, cr.name.to_snake_case()]:
			if own != "" and ResourceLoader.exists("res://art/sprites/%s/walk.tres" % own):
				return own
		return default_look(cr as Character)
	return cr.name.to_snake_case()


## A character who never picked a look borrows the pregen look of their class (until the art pass adds more).
static func default_look(ch: Character) -> String:
	for cls: String in ["fighter", "rogue", "cleric", "wizard"]:
		if ch.class_level_of(cls) > 0:
			return {"fighter": "ilse_varga", "rogue": "tamsin_tealeaf", "cleric": "hedda_ironvow", "wizard": "silvain_aster"}[cls] as String
	return "ilse_varga"


## Sprite height in world units for an art id: a custom hero's from its species and height pick, else HEIGHTS.
static func height_for(aid: String) -> float:
	return HeroLook.height_for_art(aid, float(HEIGHTS.get(aid, 1.2)))


## `art` overrides which sprite to use (NPCs whose stat block is generic, like a commoner).
static func create(c: Combatant, art: String = "") -> CombatToken:
	var t := CombatToken.new()
	t.combatant = c
	t.art_override = art
	t.name = "Token_" + c.id.replace("#", "_")
	t._build()
	return t


func _build() -> void:
	var c := combatant
	var aid := art_override if art_override != "" else art_id(c)
	var frames := DirectionalSprite.frames_for(aid)
	var size_units := float(c.size_cells)
	if frames != null:
		sprite = DirectionalSprite.create(frames, height_for(aid))
		sprite.play(&"idle_s")
		add_child(sprite)
		body = sprite
		_lying = Sprite3D.new()
		_lying.texture = frames.get_frame_texture(&"idle_s", 0)
		_lying.pixel_size = sprite.pixel_size
		DirectionalSprite.setup_material(_lying)
		_lying.rotation_degrees = Vector3(-90, 0, -90)
		_lying.position = Vector3(0, 0.03, 0)
		_lying.visible = false
		add_child(_lying)
	else:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28 * size_units
		cm.height = 1.1 * size_units
		mi.mesh = cm
		mi.position.y = cm.height / 2.0
		mi.material_override = Look.cel("crimson" if c.side == &"enemy" else "parchment")
		add_child(mi)
		body = mi
	var side_colour := _side_colour()
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.36 * size_units
	tm.outer_radius = 0.43 * size_units
	_ring.mesh = tm
	_ring.position.y = 0.03
	_ring.material_override = Look.cel(side_colour)
	add_child(_ring)
	_active_ring = MeshInstance3D.new()
	var tm2 := TorusMesh.new()
	tm2.inner_radius = 0.45 * size_units
	tm2.outer_radius = 0.5 * size_units
	_active_ring.mesh = tm2
	_active_ring.position.y = 0.04
	var am := Look.cel("wick")
	am.set_shader_parameter("emission", Look.color("flame") * 1.5)
	_active_ring.material_override = am
	_active_ring.visible = false
	add_child(_active_ring)
	# Health bar under the ring, facing up so it reads from the camera's pitch.
	_bar_back = _bar("ink", 0.8 * size_units, 0.0)
	_bar_fill = _bar("sickly", 0.8 * size_units, 0.005)
	var top := height_for(aid) + 0.25
	_label = _text(c.name(), Vector3(0, top, 0), 30, "vellum")
	_status = _text("", Vector3(0, top + 0.2, 0), 24, "flame")
	_label.visible = false
	refresh()


func _side_colour() -> String:
	match combatant.side:
		&"party":
			return "flame"
		&"guest":
			return "moonlight"
		&"neutral":
			return "parchment"
	return "crimson"


func _bar(colour: String, width: float, lift: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.02, 0.09)
	mi.mesh = bm
	mi.position = Vector3(0, 0.02 + lift, 0.42 * combatant.size_cells + 0.12)
	mi.material_override = Look.cel(colour)
	add_child(mi)
	return mi


func _text(text: String, pos: Vector3, size: int, colour: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Look.color(colour)
	l.outline_modulate = Look.color("void")
	l.no_depth_test = true
	l.render_priority = 10
	add_child(l)
	return l


## Re-reads the creature: health bar, conditions, down or dead.
func refresh() -> void:
	var cr := combatant.creature
	var frac := clampf(float(cr.hp) / maxf(1.0, float(cr.max_hp())), 0.0, 1.0)
	var colour := "sickly"
	if combatant.side == &"enemy":
		# Enemies show only Bloodied (spec): full, or half and red.
		frac = 0.0 if cr.dead else (0.5 if cr.is_bloodied() else 1.0)
		colour = "crimson" if cr.is_bloodied() else "sickly"
	elif frac <= 0.5:
		colour = "candle" if frac > 0.25 else "crimson"
	var w := (_bar_back.mesh as BoxMesh).size.x
	_bar_fill.scale.x = maxf(0.001, frac)
	_bar_fill.position.x = -w * (1.0 - frac) / 2.0
	_bar_fill.material_override = Look.cel(colour)
	var chips: Array[String] = []
	for cond in cr.active_conditions():
		if cond in [&"unconscious", &"incapacitated"] and cr.hp <= 0:
			continue
		chips.append(str(cond).capitalize())
	if cr.concentration != null:
		chips.append("◎ " + cr.concentration.name)
	if combatant.hidden:
		chips.append("Hidden")
	if cr.hp <= 0 and not cr.dead and cr.uses_death_saves:
		chips.append("Stable" if cr.stable else "Dying %d✓ %d✗" % [cr.death_successes, cr.death_failures])
	_status.text = " · ".join(chips)
	_label.text = combatant.name()
	_base_modulate = Color.WHITE
	if cr.dead:
		_base_modulate = Color(0.45, 0.4, 0.45, 0.0)
		_leave_remains()
	elif cr.hp <= 0:
		_base_modulate = Color(0.6, 0.55, 0.6, 0.85)
	if sprite != null:
		var down := not cr.dead and (cr.hp <= 0 or cr.has_condition(&"prone"))
		sprite.visible = not down
		_lying.visible = down
		if cr.dead and sprite.modulate.a > 0.01 and is_inside_tree():
			var tw := create_tween()
			tw.tween_property(sprite, "modulate", _base_modulate, 0.7)
		else:
			sprite.modulate = _faded(_base_modulate)
	_show_fade()



## The fall to the ground at 0 Hit Points or death: the standing figure crumples and the body drops into place with a
## red flash (procedural, no drawn frames).
func fall() -> void:
	if sprite == null or _lying == null or not is_inside_tree():
		return
	var lie_y := _lying.position.y
	sprite.visible = true
	_lying.visible = false
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector3(1.15, 0.15, 1.0), 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		sprite.scale = Vector3.ONE
		sprite.visible = false
		_lying.visible = true
		_lying.position.y = lie_y + 0.35
		_lying.modulate = Look.color("vampire_red"))
	tw.tween_property(_lying, "position:y", lie_y, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_property(_lying, "modulate", _faded(_base_modulate), 0.5)

## Names show only for the creature whose turn it is and the one under the cursor, to keep the field readable.
## A dark stain where a creature fell.
func _leave_remains() -> void:
	if has_node("Remains"):
		return
	var mi := MeshInstance3D.new()
	mi.name = "Remains"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.32 * combatant.size_cells
	cm.bottom_radius = 0.32 * combatant.size_cells
	cm.height = 0.02
	mi.mesh = cm
	mi.position.y = 0.015
	mi.scale = Vector3(1.0, 1.0, 0.6)
	mi.material_override = Look.cel("blood_deep" if combatant.creature.creature_type != &"undead" else "peat")
	add_child(mi)


func set_active(on: bool) -> void:
	_active = on and combatant.is_alive()
	_active_ring.visible = _active
	_label.visible = (_active or _highlight) and not combatant.creature.dead


func set_highlight(on: bool) -> void:
	_highlight = on
	_label.modulate = Look.color("wick") if on else Look.color("vellum")
	_label.visible = (_active or _highlight) and not combatant.creature.dead
	_show_fade()


## Fades the creature into view over `seconds` after `delay`: a fight's foes stepping out of the dark. Its ring grows
## in under it as it arrives; its health bar shows once it's there.
func emerge(delay: float, seconds: float) -> void:
	_set_fade(0.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_set_fade, 0.0, 1.0, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## Fades the creature out of view over `seconds`, then frees it (a fight's survivors as the party walks on).
func fade_away(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_fade, _fade, 0.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)


func _set_fade(f: float) -> void:
	_fade = f
	if sprite != null and _flash <= 0.0 and not combatant.creature.dead:
		sprite.modulate = _faded(_base_modulate)
	_show_fade()


## `c` as drawn at the creature's current fade.
func _faded(c: Color) -> Color:
	return Color(c, c.a * _fade)


## The ring, bar, conditions and the figure lying down follow the fade (a dead creature keeps only its remains).
func _show_fade() -> void:
	var cr := combatant.creature
	var there := not cr.dead and _fade > 0.0
	_ring.visible = there
	_ring.scale = Vector3.ONE * (1.15 if _highlight else 1.0) * lerpf(0.5, 1.0, _fade)
	_bar_back.visible = _bar_wanted()
	_bar_fill.visible = _bar_back.visible
	_status.visible = there and _fade >= 1.0
	if _lying != null:
		_lying.modulate = _faded(Color(0.6, 0.55, 0.65) if cr.hp <= 0 else Color.WHITE)
	if sprite == null and body != null:
		body.visible = there and _fade >= 0.5


## Faces a ground direction (x, z) and plays walking or idle. `step_time` (seconds per square) paces the walk cycle.
func face(dir: Vector2, walking: bool, step_time: float = 0.0) -> void:
	if sprite == null:
		return
	if dir.length() > 0.01:
		sprite.facing = Vector3(dir.x, 0, dir.y).normalized()
	sprite.moving = walking
	if walking:
		sprite.set_step_time(step_time)


## Turns toward `dir` (x, z) and starts the sprite's attack. False when there is no attack to play (no attack
## sheet, a placeholder body, or lying down), so the caller can fall back to a plain lunge.
func start_attack(dir: Vector2) -> bool:
	if sprite == null or not sprite.visible:
		return false
	face(dir, false)
	return sprite.attack()


## Whether this creature's attack animation is a spell gesture, played when it casts at something too.
func casts_with_attack() -> bool:
	return sprite != null and DirectionalSprite.attack_casts(sprite.sprite_frames)


## Waits until the started attack's blow lands (its hit frame), at most `max_wait` seconds.
func wait_for_strike(max_wait: float = 1.0) -> void:
	var waited := 0.0
	while sprite != null and is_inside_tree() and not sprite.has_struck() and waited < max_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()


func flash(colour: Color, seconds: float = 0.25) -> void:
	_flash = seconds
	_flash_color = colour


## The health bar shows in fights only: out of combat the bars under the party read as stray boards lying on the floor
## (owner report 2026-10-06).
func _bar_wanted() -> bool:
	return not combatant.creature.dead and _fade >= 1.0 and ModeController.mode == ModeController.Mode.COMBAT


func _process(delta: float) -> void:
	if _bar_back != null and _bar_back.visible != _bar_wanted():
		_show_fade()
	if sprite == null:
		return
	if _flash > 0.0 and not combatant.creature.dead:
		_flash -= delta
		sprite.modulate = _faded(_flash_color if fmod(_flash, 0.1) > 0.05 else _base_modulate)
		if _flash <= 0.0:
			sprite.modulate = _faded(_base_modulate)
