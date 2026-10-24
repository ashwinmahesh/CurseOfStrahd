class_name CombatToken
extends Node3D
## A creature on the combat field: its 8-direction sprite (art/sprites/<id>/walk.tres and attack.tres from the Gemini
## pipeline, docs/art/animation.md) or a
## placeholder capsule, a base ring in its side's colour (party gold, enemies red, guests moonlight blue), a thin
## health bar (exact for the party, only Bloodied for enemies, per the combat view spec), its name and its
## conditions. It only shows state; the encounter decides everything.

## Per-creature facts: sprite height, own light and art aliases (art/creature_looks.json; tools/art/new_creatures.py adds heights).
const LOOKS := "res://art/creature_looks.json"

## Sprite height in world units (1 unit = 5 ft) by creature, so a halfling stands half a human's height. A creature
## is drawn as big as its size's squares ask (DrawnCreatures.BANDS, test_creature_sizes: a Large one at least 1.3, a
## Huge one 1.95, a Gargantuan one 3.2; owner 2026-10-14, after a Huge snake stood no taller than a man).
static var HEIGHTS: Dictionary = _look_table("heights")

## Figures that are their own light, by art id: how much of their colours they show whatever the scene's lights
## (DirectionalSprite.glow). The Lantern Girl is made of the light she held up.
static var OWN_LIGHT: Dictionary = _look_table("own_light")

## Stat blocks that wear another creature's sprite: a named villain's block and the person drawn for them, or a
## familiar and the animal it looks like.
static var ART_ALIASES: Dictionary = _look_table("art_aliases")


## One table of art/creature_looks.json (heights, own_light, art_aliases): the per-creature facts live in data, so the combat
## code names no creature (docs/plans/engine_split.md).
static func _look_table(key: String) -> Dictionary:
	var all := JSON.parse_string(FileAccess.get_file_as_string(LOOKS)) as Dictionary
	return all[key] as Dictionary

## The art each character on the field wears, by creature id: an Echo Knight's echo (`look_of` in its stat block) is
## drawn as a ghostly copy of its knight.
static var _looks: Dictionary = {}

var combatant: Combatant
var art_override := ""
## How many squares across the creature was when its figure was built: the figure is drawn at that size's height, and
## Enlarge/Reduce grows or shrinks it from there (size_scale).
var built_cells := 1
## Riding a mount (CombatView sets it from Encounter.mount_of) and sneaking (exploration's sneak mode): with the
## fuller animation set they show the riding or crouched pose.
var mounted := false
var sneaking := false
var sprite: DirectionalSprite
## An Invisible foe the hero the player looks through can't see (EncounterSight.hidden_from_party): the whole figure, ring and bar are off the
## map until it's seen again (CombatView._refresh_all).
var unseen := false
## Strahd's dark aura or a paladin's Aura of Protection on the floor (AuraFx), or null.
var aura: AuraFx
## The figure lying on the ground (Prone, or at 0 Hit Points): the front view laid flat.
var _lying: Sprite3D
## A beast lying on its belly (lie_down) sinks this share of its height into the ground, legs under it; a sheet turned
## down to the chest leaves this share of the lying view's frame showing above its hem, the head and neck.
const BELLY_SINK := 0.38
const KEEP_ABOVE_HEM := 0.27
## A drawn picture of a figure lying down (lie_down's `picture`: Sarkhaza on her gold) spans this many squares a square
## of its footprint, its tail and wings past the edge.
const PICTURE_SPAN := 1.25
## A figure lying on furniture is drawn no longer than the furniture and this much more, down to MIN_FIT of its size.
const FURNITURE_OVERHANG := 0.15
const MIN_FIT := 0.8
## The lying view: the front view laid face up, head toward +x; under a sheet its head is tipped up this much.
const LYING_BASIS := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
const PILLOW_DEG := 25.0
## Lying down apart from any condition, until get_up(): a figure the story has lying there (lie_down, LyingFigures).
var resting := false
var _rest := {}
var _rising := false
## What the lying view and a sheet over it hang from: moved onto what the figure lies on, turned head first along it.
var _rest_pivot: Node3D
var _sheet: MeshInstance3D
## The drawn lying picture standing in for the figure while it rests (lie_down's `picture`), or null.
var _picture: Sprite3D
var body: Node3D
var _ring: MeshInstance3D
var _active_ring: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_back: MeshInstance3D
var _ground: ArenaBoard = null      ## the board with natural ground under the token (_lie_on_ground)
var _ground_looked := false
var _ground_cell := Vector2i(-99999, -99999)
var _built_at: Dictionary = {}       ## base pieces -> where they were built (before a slope tilted them)
var _label: Label3D
var _status: Label3D
var _status_y := 0.0   ## the chips' height over a standing figure; a figure lying down has them just above it
var _flash := 0.0
var _flash_color := Color.WHITE
var _base_modulate := Color.WHITE
var _active := false
var _highlight := false
## How far the creature has come into view (0 to 1): a fight's foes fade in as it starts and its survivors fade out
## as it ends (emerge, fade_away), rather than popping.
var _fade := 1.0
## A figure drawn this tall (world units) is a colossus (the Amber Sentinel, 6.0): where it hides a figure of the party's behind
## it on the screen it is drawn at GHOST of its strength, so the party can still be seen. `_tall` is its height when it is one.
const TALL := 4.5
const GHOST := 0.55
var _tall := 0.0
var _ghost := 1.0
var _ghost_to := 1.0
var _ghost_look := 0.0


static func art_id(c: Combatant) -> String:
	var human := human_figure(c)
	return human if human != "" else art_for(c.creature)


## A lycanthrope drawn as its hybrid (a Werewolf's `art`) walks in as a person and changes into the hybrid when it shifts
## (MonsterActions._hybrid_art): its figure in its human form, "" when it isn't in human form or has none. A story ally
## already wears their own (Davian), and a named one the story showed (Zuleika) wears that NPC's.
static func human_figure(c: Combatant) -> String:
	if str(c.get_meta("form", "humanoid")) != "humanoid":
		return ""
	return true_figure(c)


## The figure of `c` in its true (human) form whatever form it is in now, "" for a creature with no figure of its own for
## it (a stat block's `human_art`).
static func true_figure(c: Combatant) -> String:
	if not c.creature is Monster or c.creature.id.begins_with("guest_") or not (c.creature as Monster).data.has("human_art"):
		return ""
	var npc := Legendary.npc_figure_of(c)
	if npc != "" and DirectionalSprite.frames_for(npc) != null:
		return npc
	var art := str((c.creature as Monster).data["human_art"])
	return art if DirectionalSprite.frames_for(art) != null else ""


## The portrait the combat HUD shows for `c`: its creature's, except a story ally whose face the story changed
## (NpcLooks: Rictavio shows Van Richten's once unmasked, while his figure on the board stays Rictavio's). A Werewolf's
## stays the werewolf's while it walks in as a person.
static func portrait_id(c: Combatant) -> String:
	if c.creature.id.begins_with("guest_"):
		var npc := Compendium.shared().get_entry("npcs", c.creature.id.trim_prefix("guest_"))
		if npc.has("looks"):
			return NpcLooks.portrait(npc, GameState.story)
	return art_for(c.creature)


## The sprite and portrait id for a monster's stat block `data`: a hero's look it borrows (`look_of`), its own `art`,
## else its id.
static func monster_art(data: Dictionary) -> String:
	var id := str(data.get("id", ""))
	if _looks.has(str(data.get("look_of", ""))):
		return str(_looks[str(data["look_of"])])
	return str(data.get("art", ART_ALIASES.get(id, id)))


## The sprite and portrait id for a creature: a story ally's own look, a monster's stat block id, a character's chosen
## look (creation's Appearance step), or its name.
static func art_for(cr: Creature) -> String:
	# A story ally (StoryState.make_guest) wears their own look, not their stat block's: Ireena fights as a noble.
	if cr.id.begins_with("guest_"):
		var npc := Compendium.shared().get_entry("npcs", cr.id.trim_prefix("guest_"))
		if str(npc.get("sprite", "")) != "":
			return str(npc["sprite"])
	if cr is Monster:
		return monster_art((cr as Monster).data)
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


## Sprite height for a combatant: its stat block's own `art_height` when it borrows a smaller creature's sprite at a
## bigger size (Sarkhaza, a Gargantuan dragon on the draconic spirit's), else its art id's (height_for).
static func height_of(c: Combatant) -> float:
	if c.creature is Monster and (c.creature as Monster).data.has("art_height"):
		return float((c.creature as Monster).data["art_height"])
	return height_for(art_id(c))


## This token's sprite height: height_of, also for a person drawn with their own stat block's art (Sarkhaza in her
## cavern before the fight); another art override (a commoner's block in a named NPC's look) takes that art's.
func _height(aid: String) -> float:
	var own := ""
	if combatant.creature is Monster:
		own = str((combatant.creature as Monster).data.get("art", ""))
	return height_of(combatant) if art_override == "" or art_override == own else height_for(aid)


## The token's scale for the squares its creature holds now: 1 at the size its figure was drawn for, 2 for a Medium
## hero grown Large, 1.5 for an ogre grown Huge, a half for one shrunk to Medium (Enlarge/Reduce).
func size_scale() -> Vector3:
	return Vector3.ONE * (float(combatant.size_cells) / float(maxi(1, built_cells)))


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
	built_cells = c.size_cells
	var aid := art_override if art_override != "" else art_id(c)
	if c.creature is Character:
		_looks[c.id] = aid
	var frames := DirectionalSprite.frames_for(aid)
	var size_units := float(c.size_cells)
	if frames != null:
		var drawn := _height(aid)
		_tall = drawn if drawn > TALL else 0.0
		sprite = DirectionalSprite.create(frames, drawn)
		sprite.play(&"idle_s")
		if OWN_LIGHT.has(aid):
			DirectionalSprite.glow(sprite, float(OWN_LIGHT[aid]))
			sprite.reflection.copy_look()
		if _is_echo() and sprite.material_override is ShaderMaterial:
			(sprite.material_override as ShaderMaterial).set_shader_parameter("ghost", 1.0)
			(sprite.material_override as ShaderMaterial).set_shader_parameter("ghost_tint", Look.color("silver"))
		add_child(sprite)
		body = sprite
		_lying = Sprite3D.new()
		_lying.texture = frames.get_frame_texture(&"idle_s", 0)
		_lying.pixel_size = sprite.pixel_size
		DirectionalSprite.setup_material(_lying)
		_lying.transform = Transform3D(LYING_BASIS, Vector3(0, 0.03, 0))
		_lying.visible = false
		_rest_pivot = Node3D.new()
		_rest_pivot.name = "Rest"
		add_child(_rest_pivot)
		_rest_pivot.add_child(_lying)
		var aura_style := AuraFx.style_for(c, aid)
		if aura_style >= 0:
			aura = AuraFx.create(aura_style, _height(aid), c.size_cells, AuraFx.reach_of(c) if aura_style == AuraFx.Style.HOLY else 0)
			add_child(aura)
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
	# A foe's ring is a little wider and a bright red of its own that no light, fog or rain dims or bleaches, so it shows
	# in a dark room and in the mist (owner, 2026-10-12: "make the red circle around enemies brighter"); the party's
	# gold and the guests' blue stay as they were, lit by the scene, so a foe still stands out from a friend.
	var foe := side_colour == "crimson"
	tm.inner_radius = (0.35 if foe else 0.36) * size_units
	tm.outer_radius = (0.45 if foe else 0.43) * size_units
	_ring.mesh = tm
	_ring.position.y = 0.03
	if foe:
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.albedo_color = Look.color("vampire_red")
		rm.disable_fog = true
		_ring.material_override = rm
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
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
	var top := _height(aid) + 0.25
	_label = _text(c.name(), Vector3(0, top, 0), 30, "vellum")
	_status = _text("", Vector3(0, top + 0.2, 0), 24, "flame")
	_status_y = top + 0.2
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


## Whether a spell or effect on `cr` cuts its Speed: a minus to it (Ray of Frost), a share of it (Slow halves it), a cap
## on it, or the Slow spell's own flag. Conditions that stop it (Grappled, Restrained) show as themselves.
static func slowed(cr: Creature) -> bool:
	for fx in cr.effects:
		for m in fx.modifiers:
			var v: Variant = m.data.get("value")
			var number := v is int or v is float
			match str(m.stat):
				"speed":
					if number and float(v) < 0.0:
						return true
				"speed_percent":
					if number and float(v) < 100.0:
						return true
				"speed_cap":
					return true
				"flag":
					if str(v) == "slowed":
						return true
	return false


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
	# Asleep (Sleep, a sleeping NPC): one chip in place of the Unconscious and Incapacitated the sleep carries.
	var asleep := cr.effects.any(func(fx: Effect) -> bool: return bool(fx.data.get("wakeable", false)) and &"unconscious" in fx.conditions)
	if asleep and cr.hp > 0:
		chips.append("Asleep")
	for cond in cr.active_conditions():
		if cond in [&"unconscious", &"incapacitated"] and (cr.hp <= 0 or asleep):
			continue
		chips.append(str(cond).capitalize())
	if cr.concentration != null:
		chips.append("◎ " + cr.concentration.name)
	if combatant.hidden:
		chips.append("Hidden")
	# F13: a foe that gave up (combat/ai/ai_tactics.gd).
	if cr.has_flag("surrendered") and not cr.dead:
		chips.append("Surrendered")
	# Slowed (owner, 2026-10-12): a spell or effect cutting its Speed (Ray of Frost, Slow...).
	if slowed(cr):
		chips.append("Slowed")
	# Hex, Hunter's Mark: who marked it.
	for fx in cr.effects:
		if fx.data.has("mark_by"):
			chips.append(fx.name)
	if cr.hp <= 0 and not cr.dead and cr.uses_death_saves:
		chips.append("Stable" if cr.stable else "Dying %d✓ %d✗" % [cr.death_successes, cr.death_failures])
	_status.text = " · ".join(chips)
	_label.text = combatant.name()
	_base_modulate = Color.WHITE
	# A hero (or an ally) who is Invisible stays on the map for its own player, see-through (owner, 2026-10-13).
	if combatant.side in [&"party", &"guest"] and EncounterSight.truly_invisible(combatant):
		_base_modulate = Color(1, 1, 1, 0.5)
	if _is_echo():
		# An Echo Knight's echo: a translucent gray image of its knight (the sprite shader washes it gray).
		_base_modulate = Color(1, 1, 1, 0.6)
	if cr.dead:
		_base_modulate = Color(0.45, 0.4, 0.45, 0.0)
		_leave_remains()
	elif cr.hp <= 0:
		_base_modulate = Color(0.6, 0.55, 0.6, 0.85)
	if sprite != null:
		var down: bool = not cr.dead and (cr.hp <= 0 or cr.has_condition(&"prone") or (resting and not str(_rest.get("pose")) in ["belly", "picture"]))
		_status.position.y = 0.75 + float(_rest.get("lift", 0.0)) if down else _status_y
		if DirectionalSprite.has_anim(sprite.sprite_frames, "down"):
			# Drawn falls and a drawn lying pose: the figure itself lies down (fall() plays the fall).
			sprite.visible = true
			_lying.visible = false
			if (down or cr.dead) and sprite.pose != "down" and not sprite.is_dying():
				sprite.pose = "down"
			elif not down and not cr.dead:
				sprite.pose = _standing_pose()
		else:
			sprite.visible = not down
			_lying.visible = down and str(_rest.get("sheet", "")) != "face"   # a sheet drawn over the face hides it
		if _picture != null:
			# A drawn lying picture stands in for the figure until it gets up (get_up shows the figure as it rises).
			_picture.visible = resting and not _rising and str(_rest.get("pose")) == "picture" and not cr.dead
			if _picture.visible:
				sprite.visible = false
				_lying.visible = false
			_picture.modulate = _faded(_base_modulate)
		if cr.dead and sprite.modulate.a > 0.01 and is_inside_tree():
			var tw := create_tween()
			tw.tween_property(sprite, "modulate", _base_modulate, 0.7)
		else:
			sprite.modulate = _faded(_base_modulate)
	_show_fade()



## Lies down apart from any condition, as a figure the story has lying there (LyingFigures.lay; owner 2026-10-13:
## the text has Vasilka lying under a sheet, very still, and she stood beside her table), until get_up(). `how`:
## `pose` "back" (the lying view: a person on their back), "belly" (a beast or a dragon: its figure low on the
## ground, legs under it) or "picture" (a drawn picture of it lying down, the texture `picture`, `width` wide, in its
## place: Sarkhaza across her gold); `lift` up onto what it lies on and `offset` (x, z) across to it; `head` (x, z) the way its
## head points (a beast without one looks the way it did); `sheet` "chest" (linen turned down under the collarbone) or
## "face" (drawn over it), spreading `half` either side and hanging `drop` over the edge of what it lies on. On furniture
## `long` long, a figure much longer is drawn a little smaller (the game's tables are short for its people).
func lie_down(how: Dictionary) -> void:
	resting = true
	_rest = how
	if sprite == null or _lying == null:
		refresh()
		return
	var lift := float(how.get("lift", 0.0))
	var offset := how.get("offset", Vector2.ZERO) as Vector2
	var head := how.get("head", Vector2(1, 0)) as Vector2
	if str(how.get("pose", "back")) == "picture":
		_show_picture(how, Vector3(offset.x, lift, offset.y))
		refresh()
		return
	if str(how.get("pose", "back")) == "belly":
		if how.has("head"):
			face(head, false)   # else the way it already looks
		var sink := BELLY_SINK * _height(art_override if art_override != "" else art_id(combatant))
		sprite.position = Vector3(offset.x, lift - sink, offset.y)
		refresh()
		return
	# The lying view is its frame laid flat, centred: the figure's soles 4% of the frame up from its bottom edge and the
	# figure 1/1.12 of the frame long (DirectionalSprite.create), its head toward +x.
	var frame := _lying.texture.get_height() * _lying.pixel_size
	var fit := clampf((float(how.get("long", 99.0)) + FURNITURE_OVERHANG) / (frame / 1.12), MIN_FIT, 1.0)
	_rest_pivot.position = Vector3(offset.x, lift, offset.y)
	_rest_pivot.rotation.y = atan2(-head.y, head.x)   # the lying view lies head first along +x
	_rest_pivot.scale = Vector3.ONE * fit
	var sheet := str(how.get("sheet", ""))
	if sheet != "":
		_sheet = SheetDrape.build(frame / 1.12, -frame * 0.46, sheet == "face", float(how.get("half", 0.34)) / fit,
			float(how.get("drop", 0.0)) / fit)
		_rest_pivot.add_child(_sheet)
		_lying.region_enabled = sheet == "chest"
		if sheet == "chest":
			# Only the head and neck show above the hem (the frame's top KEEP_ABOVE_HEM), resting on the hem as on a
			# pillow, tipped up PILLOW_DEG so the face shows from above.
			var px := Vector2(_lying.texture.get_width(), _lying.texture.get_height())
			_lying.region_rect = Rect2(Vector2.ZERO, Vector2(px.x, px.y * KEEP_ABOVE_HEM))
			_lying.offset = Vector2(0, px.y * KEEP_ABOVE_HEM / 2.0)
			_lying.position = Vector3(frame * (0.5 - KEEP_ABOVE_HEM), SheetDrape.hem_height(frame / 1.12) * 0.8, 0)
			_lying.basis = Basis(Vector3.BACK, deg_to_rad(PILLOW_DEG)) * LYING_BASIS
	refresh()


## The `picture` pose: the drawn picture of the figure lying down (a texture path), standing on the ground at `at` and
## turning to the camera as the figures do, `width` world units wide (else PICTURE_SPAN squares a square it holds).
func _show_picture(how: Dictionary, at: Vector3) -> void:
	var tex := load(str(how.get("picture", ""))) as Texture2D
	if tex == null:
		return
	if _picture == null:
		_picture = Sprite3D.new()
		_picture.name = "LyingPicture"
		_picture.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(_picture)
	_picture.texture = tex
	_picture.pixel_size = float(how.get("width", combatant.size_cells * PICTURE_SPAN)) / float(tex.get_width())
	_picture.offset = Vector2(0, tex.get_height() * 0.5)
	_picture.position = at
	DirectionalSprite.setup_material(_picture)


## Gets up from lying down (lie_down) after `delay` seconds: a person rises out of a crouch on its own square as the
## lying view goes (fall() played backwards), a beast comes up off the ground. A sheet over it is left behind.
func get_up(delay: float = 0.0) -> void:
	if not resting or _rising:
		return
	_rising = true
	var tw := create_tween()
	tw.tween_interval(delay)
	if sprite == null or _lying == null:
		tw.tween_callback(_stood)
	elif str(_rest.get("pose", "back")) == "belly":
		tw.tween_property(sprite, "position", Vector3.ZERO, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_callback(_stood)
	elif str(_rest.get("pose", "back")) == "picture":
		# The picture goes and the figure comes up off the ground in its place, as a beast's does.
		tw.tween_callback(func() -> void:
			sprite.position = Vector3(0, -BELLY_SINK * _height(art_override if art_override != "" else art_id(combatant)), 0)
			refresh())
		tw.tween_property(sprite, "position", Vector3.ZERO, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_callback(_stood)
	else:
		tw.tween_callback(func() -> void:
			_stood()
			sprite.scale = Vector3(1.12, 0.2, 1.0))
		tw.tween_property(sprite, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Up: the lying view back as fall() wants it, and the figure standing on its own square.
func _stood() -> void:
	resting = false
	_rising = false
	_rest = {}
	if _rest_pivot != null:
		if _sheet != null:
			_sheet.queue_free()
			_sheet = null
		_rest_pivot.transform = Transform3D.IDENTITY
		_lying.region_enabled = false
		_lying.offset = Vector2.ZERO
		_lying.transform = Transform3D(LYING_BASIS, Vector3(0, 0.03, 0))
	if sprite != null:
		sprite.position = Vector3.ZERO
	refresh()


func _is_echo() -> bool:
	return combatant.creature is Monster and (combatant.creature as Monster).data.has("look_of")


## The pose standing up: astride a mount, crouched when hidden or sneaking, else on foot.
func _standing_pose() -> String:
	if mounted:
		return "ride"
	if sneaking or combatant.hidden:
		return "sneak"
	return ""


## Plays the drawn fall when the sprite has one (an enemy's death; a hero's fall goes through fall()).
func fall_if_drawn() -> void:
	if sprite != null and DirectionalSprite.has_anim(sprite.sprite_frames, "die"):
		sprite.die()


## A flinch when struck (sprites with the fuller animation set).
func hurt() -> void:
	if sprite != null and combatant.is_alive() and combatant.creature.hp > 0:
		sprite.hurt()
		if aura != null:
			aura.surge(0.6)


## The fall to the ground at 0 Hit Points or death: the drawn fall when the sprite has one; otherwise the standing
## figure crumples and the body drops into place with a red flash (procedural, no drawn frames).
func fall() -> void:
	if sprite != null and sprite.die():
		return
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


## Takes the figure off the map while it's an Invisible foe nobody on the party can see, and puts it back once it's seen.
func set_unseen(on: bool) -> void:
	if on == unseen:
		return
	unseen = on
	visible = not on
	if not on:
		_label.visible = (_active or _highlight) and not combatant.creature.dead


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
	return Color(c, c.a * _fade * _ghost)


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
	_aura_state()


## The aura shows while its owner stands and is conscious (a paladin's also needs them not Incapacitated, as the rule
## does), fades with the figure, and a paladin's area shows on the floor in fights only.
func _aura_state() -> void:
	if aura == null:
		return
	var cr := combatant.creature
	var up := not cr.dead and cr.hp > 0 and not (aura.style == AuraFx.Style.HOLY and cr.has_condition(&"incapacitated"))
	aura.set_state(up, _fade, ModeController.mode == ModeController.Mode.COMBAT)


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
	if aura != null:
		aura.surge(1.0)
	if sprite == null or not sprite.visible:
		return false
	face(dir, false)
	return sprite.attack()


## Turns toward `dir` (x, z) and starts the drawn spell gesture. False when the sprite has none.
func start_cast(dir: Vector2) -> bool:
	if aura != null:
		aura.surge(1.0)
	if sprite == null or not sprite.visible:
		return false
	face(dir, false)
	return sprite.cast()


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
## On natural ground's slopes (ArenaBoard.ground_normal) the base ring, the turn ring and the health bar lie along
## the ground under the token, a little above it; on level ground they stay as built. The board is the one beside the
## token (or beside one of its parents), looked for once.
func _lie_on_ground() -> void:
	if not _ground_looked:
		_ground_looked = true
		var p := get_parent()
		while p != null and _ground == null:
			_ground = p.get_node_or_null("ArenaBoard") as ArenaBoard
			p = p.get_parent()
		if _ground != null and not _ground.has_terrain():
			_ground = null
	if _ground == null or not is_instance_valid(_ground):
		return
	var cell := Vector2i(floori(global_position.x), floori(global_position.z))
	if cell == _ground_cell:
		return
	_ground_cell = cell
	var up := _ground.ground_normal(cell)
	var tilt := Basis.IDENTITY if up.y > 0.9999 else Basis(Vector3.UP.cross(up).normalized(), Vector3.UP.angle_to(up))
	for n: MeshInstance3D in [_ring, _active_ring, _bar_back, _bar_fill, aura.floor_area if aura != null else null]:
		if n == null:
			continue
		if not _built_at.has(n):
			_built_at[n] = n.position
		n.quaternion = tilt.get_rotation_quaternion()
		n.position = tilt * (_built_at[n] as Vector3) + (Vector3(0, 0.03, 0) if tilt != Basis.IDENTITY else Vector3.ZERO)


## A colossus looks, a few times a second, at what stands behind it, and eases to or from GHOST.
func _ghost_step(delta: float) -> void:
	_ghost_look -= delta
	if _ghost_look <= 0.0:
		_ghost_look = 0.1
		_ghost_to = GHOST if hides_a_friend() else 1.0
	if not is_equal_approx(_ghost, _ghost_to):
		_ghost = move_toward(_ghost, _ghost_to, delta * 5.0)
		_set_fade(_fade)


## Whether a figure of the party's (or a guest's) stands behind this one on the screen: inside the picture of it, and
## farther from the camera.
func hides_a_friend() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or not visible or combatant == null or get_parent() == null:
		return false
	var foot := global_position
	if cam.is_position_behind(foot):
		return false
	var a := cam.unproject_position(foot)
	var b := cam.unproject_position(foot + Vector3(0.0, _tall, 0.0))
	var half := absf(b.y - a.y) * 0.24
	var picture := Rect2(Vector2(a.x - half, minf(a.y, b.y)), Vector2(half * 2.0, absf(b.y - a.y)))
	var depth := (foot - cam.global_position).dot(-cam.global_basis.z)
	for n: Node in get_parent().get_children():
		var other := n as CombatToken
		if other == null or other == self or not other.visible or other.combatant == null or other.combatant.creature.dead \
				or not other.combatant.side in [&"party", &"guest"]:
			continue
		var heart := other.global_position + Vector3(0.0, 0.5, 0.0)
		if not cam.is_position_behind(heart) and picture.has_point(cam.unproject_position(heart)) \
				and (other.global_position - cam.global_position).dot(-cam.global_basis.z) > depth:
			return true
	return false


func _bar_wanted() -> bool:
	return not combatant.creature.dead and _fade >= 1.0 and ModeController.mode == ModeController.Mode.COMBAT


func _process(delta: float) -> void:
	if _bar_back != null and _bar_back.visible != _bar_wanted():
		_show_fade()
	_aura_state()
	_lie_on_ground()
	if _tall > 0.0:
		_ghost_step(delta)
	if sprite == null:
		return
	if _flash > 0.0 and not combatant.creature.dead:
		_flash -= delta
		sprite.modulate = _faded(_flash_color if fmod(_flash, 0.1) > 0.05 else _base_modulate)
		if _flash <= 0.0:
			sprite.modulate = _faded(_base_modulate)
