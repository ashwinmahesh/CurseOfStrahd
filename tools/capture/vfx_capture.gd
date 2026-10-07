extends Node
## Before-and-after shots of the spell effects (docs/art/spell_effects.md): the same moment of a fight in the Village
## of Barovia at night, played once with the effects off (what combat showed before) and once with them on, as frame
## sequences that tools/capture/vfx_sheet.py joins into side-by-side GIFs and stills.
## make capture SCENE=res://tools/capture/vfx_capture.tscn NAME=vfx/vfx FRAMES=30 [VFX_ONLY=fire_bolt,fireball]
## [VFX_SIDES=after] [VFX_LOOK=classic]

const PARTY: Array[String] = ["silvain_aster", "hedda_ironvow", "kip_smudgewick", "godrick_pendlebrook"]
const LOCATION := "village_of_barovia"
const ENCOUNTER := "night_streets_dead"
## Frames recorded per clip, and every how many frames one is kept (60 fps / 2 = 30 fps clips).
const CLIP_FRAMES := 130
const EVERY := 2

## Each stage: who casts, where the targets stand (cells along the camera's right, forward), and the events played.
## The events name "caster" and "t0", "t1"... and are filled in with the staged creatures' ids.
const STAGES := {
	"fire_bolt": {"caster": "Silvain", "targets": [[3, 0]],
		"events": [{"type": "spell", "spell": "fire_bolt", "caster": "caster", "targets": ["t0"]},
			{"type": "attack", "attacker": "caster", "target": "t0", "hit": true}, {"type": "damage", "id": "t0", "amount": 9}]},
	"fireball": {"caster": "Silvain", "targets": [[4, 0], [5, 1], [4, -1], [5, -1]], "area_at": [5, 0],
		"events": [{"type": "spell", "spell": "fireball", "caster": "caster", "targets": []},
			{"type": "damage", "id": "t0", "amount": 27}, {"type": "damage", "id": "t1", "amount": 27},
			{"type": "damage", "id": "t2", "amount": 13}, {"type": "damage", "id": "t3", "amount": 27}]},
	"cure_wounds": {"caster": "Hedda", "targets": [[1, 0]], "ally": "Godrick",
		"events": [{"type": "spell", "spell": "cure_wounds", "caster": "caster", "targets": ["t0"]}, {"type": "heal", "id": "t0", "amount": 14}]},
	"eldritch_blast": {"caster": "Kip", "targets": [[3, 0]],
		"events": [{"type": "spell", "spell": "eldritch_blast", "caster": "caster", "targets": ["t0", "t0"]},
			{"type": "attack", "attacker": "caster", "target": "t0", "hit": true}, {"type": "damage", "id": "t0", "amount": 8},
			{"type": "attack", "attacker": "caster", "target": "t0", "hit": true}, {"type": "damage", "id": "t0", "amount": 6}]},
	"divine_smite": {"caster": "Godrick", "targets": [[1, 0]],
		"events": [{"type": "attack", "attacker": "caster", "target": "t0", "hit": true},
			{"type": "smite", "caster": "caster", "spell": "divine_smite", "target": "t0"}, {"type": "damage", "id": "t0", "amount": 23}]},
}

## VFX_SET=gallery: one cast of each family (after only), to check them all. "cast" builds the events from the spell
## (its area's squares, an attack and damage per target, healing); "ability" plays a class feature's or a monster's
## action by its key; "attack" a blow with that action id; "teleport_to" moves the caster after the cast.
const GALLERY := {
	"magic_missile": {"caster": "Silvain", "targets": [[3, 0]], "cast": "magic_missile"},
	"scorching_ray": {"caster": "Silvain", "targets": [[3, 0], [3, 1]], "cast": "scorching_ray"},
	"chain_lightning": {"caster": "Silvain", "targets": [[3, 0], [4, 1], [3, -1]], "cast": "chain_lightning"},
	"ray_of_frost": {"caster": "Silvain", "targets": [[3, 0]], "cast": "ray_of_frost"},
	"burning_hands": {"caster": "Silvain", "targets": [[2, 0], [3, 0]], "cast": "burning_hands"},
	"cone_of_cold": {"caster": "Silvain", "targets": [[3, 0], [4, 1]], "cast": "cone_of_cold"},
	"lightning_bolt": {"caster": "Silvain", "targets": [[3, 0], [5, 0]], "cast": "lightning_bolt"},
	"thunderwave": {"caster": "Silvain", "targets": [[1, 0], [1, 1]], "cast": "thunderwave"},
	"spirit_guardians": {"caster": "Hedda", "targets": [[2, 0]], "cast": "spirit_guardians"},
	"flame_strike": {"caster": "Hedda", "targets": [[4, 0]], "cast": "flame_strike"},
	"call_lightning": {"caster": "Silvain", "targets": [[4, 0]], "cast": "call_lightning"},
	"ice_storm": {"caster": "Silvain", "targets": [[4, 0], [5, 1]], "cast": "ice_storm"},
	"cloudkill": {"caster": "Silvain", "targets": [[4, 0]], "cast": "cloudkill"},
	"wall_of_fire": {"caster": "Silvain", "targets": [[4, 0]], "cast": "wall_of_fire"},
	"entangle": {"caster": "Hedda", "targets": [[4, 0], [4, 1]], "cast": "entangle"},
	"bless": {"caster": "Hedda", "targets": [[1, 0]], "ally": "Godrick", "cast": "bless"},
	"hex": {"caster": "Kip", "targets": [[3, 0]], "cast": "hex"},
	"vicious_mockery": {"caster": "Kip", "targets": [[3, 0]], "cast": "vicious_mockery"},
	"shield_of_faith": {"caster": "Hedda", "targets": [[1, 0]], "ally": "Godrick", "cast": "shield_of_faith"},
	"shocking_grasp": {"caster": "Silvain", "targets": [[1, 0]], "cast": "shocking_grasp"},
	"vampiric_touch": {"caster": "Kip", "targets": [[1, 0]], "cast": "vampiric_touch"},
	"summon_undead": {"caster": "Silvain", "targets": [[2, 0]], "ally": "Godrick", "cast": "summon_undead", "summoned": true},
	"misty_step": {"caster": "Kip", "targets": [[3, 0]], "cast": "misty_step", "teleport_to": [2, 1]},
	"polymorph": {"caster": "Silvain", "targets": [[3, 0]], "cast": "polymorph"},
	"detect_magic": {"caster": "Silvain", "targets": [[3, 0]], "cast": "detect_magic"},
	"second_wind": {"caster": "Godrick", "targets": [[3, 0]], "ability": "feature:second_wind", "self": true},
	"turn_undead": {"caster": "Hedda", "targets": [[2, 0], [3, 1]], "ability": "spell:turn_undead"},
	"zombie_slam": {"caster": "Zombie", "targets": [[1, 0]], "ally": "Godrick", "attack": "monster:slam"},
	"ghost_visage": {"caster": "Zombie", "targets": [[3, 0], [4, 1]], "ally": "Godrick", "ability": "monster:ghost.horrific_visage"},
	"vampire_bite": {"caster": "Zombie", "targets": [[1, 0]], "ally": "Godrick", "ability": "monster:vampire_spawn.bite"},
	"longsword": {"caster": "Godrick", "targets": [[1, 0]], "attack": "weapon:longsword"},
	"arrow": {"caster": "Silvain", "targets": [[4, 0]], "attack": "weapon:longbow@arrow"},
}

## VFX_SET=zones: spells whose area stays on the board, before and after (the spell is cast, then its zone sits there),
## and the area spells Ashwin asked about.
const ZONES := {
	"darkness": {"caster": "Silvain", "targets": [[4, 0]], "cast": "darkness", "zone": true},
	"wall_of_fire": {"caster": "Silvain", "targets": [[4, 0]], "cast": "wall_of_fire", "zone": true},
	"web": {"caster": "Silvain", "targets": [[4, 0]], "cast": "web", "zone": true},
	"grease": {"caster": "Silvain", "targets": [[3, 0]], "cast": "grease", "zone": true},
	"spike_growth": {"caster": "Hedda", "targets": [[4, 0]], "cast": "spike_growth", "zone": true},
	"entangle": {"caster": "Hedda", "targets": [[4, 0]], "cast": "entangle", "zone": true},
	"evards_black_tentacles": {"caster": "Silvain", "targets": [[4, 0]], "cast": "evards_black_tentacles", "zone": true},
	"cloudkill": {"caster": "Silvain", "targets": [[4, 0]], "cast": "cloudkill", "zone": true},
	"fog_cloud": {"caster": "Silvain", "targets": [[4, 0]], "cast": "fog_cloud", "zone": true},
	"spirit_guardians": {"caster": "Hedda", "targets": [[2, 0]], "cast": "spirit_guardians", "zone": true},
	"moonbeam": {"caster": "Hedda", "targets": [[3, 0]], "cast": "moonbeam", "zone": true},
	"hypnotic_pattern": {"caster": "Kip", "targets": [[4, 0], [5, 1]], "cast": "hypnotic_pattern"},
	"lightning_bolt": {"caster": "Silvain", "targets": [[3, 0], [5, 0]], "cast": "lightning_bolt"},
	"cone_of_cold": {"caster": "Silvain", "targets": [[3, 0], [4, 1]], "cast": "cone_of_cold"},
	"thunderwave": {"caster": "Silvain", "targets": [[1, 0], [1, 1]], "cast": "thunderwave"},
}

var root: Node
var cv: CombatView
## The zone the stage being recorded put on the board (taken off again after each side).
var _zone: FieldObject = null
var _only: Array[String] = []
var _sides: Array[bool] = [false, true]


func _ready() -> void:
	for s in OS.get_environment("VFX_ONLY").split(",", false):
		_only.append(s.strip_edges())
	if OS.get_environment("VFX_SIDES") == "after":
		_sides = [true]
	if OS.get_environment("VFX_LOOK") != "":
		Look.set_style(OS.get_environment("VFX_LOOK"), false)
	GameState.reset()
	for id in PARTY:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = LOCATION
	Dice.reseed(3)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func capture_shots(tool: Node, out: String) -> void:
	root.call("enter_location", LOCATION, "default")
	await tool.call("wait_frames", 40)
	(root.get("hud") as ExploreHud).close_narration()
	var view := root.get("view") as LocationView
	view.start_encounter(ENCOUNTER)
	cv = view.combat_view
	cv.input_locked = true
	# Wait for a party member's turn, so nothing else moves while the stages play.
	for i in 2400:
		await tool.call("wait_frames", 1)
		if cv.mode == CombatView.Mode.IDLE:
			break
	await tool.call("wait_frames", 60)
	var meta := {}
	var set_name := OS.get_environment("VFX_SET")
	var stages: Dictionary = GALLERY if set_name == "gallery" else (ZONES if set_name == "zones" else STAGES)
	if stages == GALLERY:
		_sides = [true]
	for key: String in stages:
		if not _only.is_empty() and not key in _only:
			continue
		var st := (stages[key] as Dictionary).duplicate(true)
		var ids := _stage(st)
		if not st.has("events"):
			st["events"] = _auto_events(st, ids)
		if not (ids.get("area", []) as Array).is_empty() and stages != STAGES:
			_frame_area(ids)
		await tool.call("wait_frames", 30)
		meta[key] = _frame_box(ids)
		for on in _sides:
			SpellFx.enabled = on
			await _record(st, ids, "%s_%s_%s" % [out, key, "after" if on else "before"])
	SpellFx.enabled = true
	var f := FileAccess.open(out + "_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()


## Places the stage's caster in the open and its targets along the camera's right; frames the camera on them.
## Returns the event names' ids: {"caster": id, "t0": id, ...}.
func _stage(st: Dictionary) -> Dictionary:
	var e := cv.e
	var caster := _find(str(st["caster"]))
	var cam := cv.rig.camera
	var right3 := cam.global_transform.basis.x
	var fwd3 := -cam.global_transform.basis.z
	var right := Vector2i(roundi(right3.x), roundi(right3.z))
	var fwd := Vector2i(roundi(fwd3.x), roundi(fwd3.z))
	if right == Vector2i.ZERO:
		right = Vector2i(1, 0)
	if fwd == Vector2i.ZERO or fwd == right or fwd == -right:
		fwd = Vector2i(-right.y, right.x)
	var spot := _open_spot(e, right, (st["targets"] as Array).map(func(t: Variant) -> Vector2i:
		return Vector2i(int((t as Array)[0]), int((t as Array)[1]))), fwd)
	_put(caster, spot)
	var ids := {"caster": caster.id}
	var foes := e.combatants.filter(func(c: Combatant) -> bool: return c.side == &"enemy" and c.is_alive())
	var i := 0
	for t: Variant in st["targets"]:
		var off := Vector2i(int((t as Array)[0]), int((t as Array)[1]))
		var who: Combatant = _find(str(st["ally"])) if st.has("ally") else foes[i % foes.size()] as Combatant
		_put(who, spot + right * off.x + fwd * off.y)
		ids["t%d" % i] = who.id
		i += 1
	if st.has("area_at"):
		var a := st["area_at"] as Array
		var at := spot + right * int(a[0]) + fwd * int(a[1])
		ids["area"] = e.spells.area_for(caster, Compendium.shared().spell_data("fireball"), Vector2(at.x + 0.5, at.y + 0.5), Vector2.ZERO, 3)
	var mid := Vector3.ZERO
	var n := 0
	for k: String in ids:
		if k == "area":
			continue
		mid += (cv.tokens[ids[k]] as Node3D).global_position
		n += 1
	mid /= float(n)
	cv.rig.follow = null
	cv.rig.global_position = mid + Vector3(0, 0.3, 0)
	cv.rig.distance = 11.0 if st.has("area_at") else 8.5
	cv.overlay.clear_all()
	for id: String in cv.tokens:
		(cv.tokens[id] as CombatToken).set_active(false)
	return ids


## The events a gallery stage plays, from its "cast", "ability" or "attack" (ids still by name: "caster", "t0"...).
func _auto_events(st: Dictionary, ids: Dictionary) -> Array:
	var ev: Array = []
	var ts: Array = []
	for i in (st["targets"] as Array).size():
		ts.append("t%d" % i)
	if st.has("cast"):
		var sid := str(st["cast"])
		var sd := Compendium.shared().spell_data(sid)
		var caster := cv.e.get_c(str(ids["caster"]))
		if sd.has("area"):
			var t0 := cv.e.get_c(str(ids["t0"]))
			var at := cv.e.center_of(t0)
			var dir := (at - cv.e.center_of(caster)).normalized()
			ids["area"] = cv.e.spells.area_for(caster, sd, at, dir, maxi(1, int(sd.get("level", 1))))
		ev.append({"type": "spell", "spell": sid, "caster": "caster", "targets": ts})
		for t: String in ts:
			if sd.has("attack"):
				ev.append({"type": "attack", "attacker": "caster", "target": t, "hit": true})
			if sd.has("damage"):
				ev.append({"type": "damage", "id": t, "amount": 9})
			elif "healing" in (sd.get("tags", []) as Array):
				ev.append({"type": "heal", "id": t, "amount": 9})
		if st.has("teleport_to"):
			var to := caster.cell + Vector2i(int((st["teleport_to"] as Array)[0]), int((st["teleport_to"] as Array)[1]))
			ev.append({"type": "teleport", "id": "caster", "from": caster.cell, "to": to})
	elif st.has("ability"):
		var spec := str(st["ability"])
		var src := spec.get_slice(":", 0)
		var key := spec.substr(src.length() + 1)
		var on: Array = ["caster"] if bool(st.get("self", false)) else ts
		if src == "spell":
			ev.append({"type": "spell", "spell": key, "caster": "caster", "targets": on})
		else:
			ev.append({"type": "ability", "source": src, "by": "caster", "key": key, "targets": on, "cells": []})
		for t: String in on:
			ev.append({"type": "heal" if bool(st.get("self", false)) else "damage", "id": t, "amount": 8})
	elif st.has("attack"):
		ev.append({"type": "attack", "attacker": "caster", "target": "t0", "hit": true, "action": str(st["attack"])})
		ev.append({"type": "damage", "id": "t0", "amount": 7})
	return ev


## A spot for the caster with room for every target offset (cells free and standing ground), in the most open part
## of the map (no walls or houses between the camera and the stage).
func _open_spot(e: Encounter, right: Vector2i, offsets: Array, fwd: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -1
	for y in range(2, e.grid.depth - 2):
		for x in range(2, e.grid.width - 2):
			var c := Vector2i(x, y)
			var ok := _free(e, c)
			for off: Variant in offsets:
				var o := off as Vector2i
				ok = ok and _free(e, c + right * o.x + fwd * o.y)
			if not ok:
				continue
			var mid := c + right * 2
			var score := 0
			for dy in range(-5, 6):
				for dx in range(-5, 6):
					var n := mid + Vector2i(dx, dy)
					if e.grid.in_bounds(n) and not e.grid.is_solid(n) and e.grid.height(n) == 0:
						score += 1
			if score > best_score:
				best_score = score
				best = c
	return best


func _free(e: Encounter, c: Vector2i) -> bool:
	return e.grid.in_bounds(c) and not e.grid.is_solid(c) and e.occupant_at(c) == null and e.grid.height(c) == 0


func _put(c: Combatant, cell: Vector2i) -> void:
	c.cell = cell
	var t := cv.tokens[c.id] as CombatToken
	t.position = cv.board.cell_center(cell, c.size_cells)


func _find(name_part: String) -> Combatant:
	for c in cv.e.combatants:
		if c.name().contains(name_part):
			return c
	return null


## Plays the stage's events (ids filled in) and keeps every EVERY-th frame as a JPEG.
func _record(st: Dictionary, ids: Dictionary, prefix: String) -> void:
	var events: Array = []
	for ev: Variant in st["events"]:
		var d := (ev as Dictionary).duplicate(true)
		for k: String in ["caster", "attacker", "target", "id", "by"]:
			if d.has(k):
				d[k] = ids[str(d[k])]
		if d.has("targets"):
			d["targets"] = (d["targets"] as Array).map(func(x: Variant) -> String: return str(ids[str(x)]))
		if str(d["type"]) == "spell":
			d["cells"] = ids.get("area", [])
		events.append(d)
	if bool(st.get("zone", false)):
		# The spell's lingering area, as the rules would leave it: the view draws it on the "object" event.
		var sd := Compendium.shared().spell_data(str(st["cast"]))
		_zone = FieldObject.new(FieldObject.Kind.ZONE, str(st["cast"]), str(sd.get("name", "")))
		_zone.caster_id = str(ids["caster"])
		_zone.cells.assign(ids.get("area", []) as Array)
		_zone.rules = (sd.get("zone", {}) as Dictionary).duplicate(true)
		_zone.rounds_left = 1000
		_zone.follows_caster = str((sd.get("area", {}) as Dictionary).get("shape", "")) == "emanation"
		cv.e.spells.zones.objects.append(_zone)
		events.append({"type": "object", "id": _zone.id, "kind": "zone", "cell": Vector2i.ZERO})
	cv.e.events.append_array(events)
	cv.call("_play_events")
	if bool(st.get("summoned", false)) and SpellFx.enabled:
		# What a summoning's creature arriving looks like (the real event makes a new token).
		get_tree().create_timer(0.5).timeout.connect(func() -> void: cv.fx.summoned(cv.tokens[ids["t0"]] as CombatToken))
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var frames := CLIP_FRAMES * (2 if _zone != null else 1)
	for i in frames:
		await get_tree().process_frame
		if i % EVERY == 0:
			get_viewport().get_texture().get_image().save_jpg("%s_%03d.jpg" % [prefix, i / EVERY], 0.92)
	if _zone != null:
		_zone.ended = true
		cv.e.spells.zones.objects.erase(_zone)
		cv.field.sync(cv.e.spells.zones.objects)
		_zone = null
	await get_tree().create_timer(1.5).timeout


## Centres the camera between the caster and the spell's squares, pulled back far enough to take the area in.
func _frame_area(ids: Dictionary) -> void:
	var ex := FxAreas.extent(ids["area"] as Array, cv.board)
	var caster := (cv.tokens[ids["caster"]] as Node3D).global_position
	var mid := (ex["mid"] as Vector3).lerp(caster, 0.3)
	cv.rig.global_position = mid + Vector3(0, 0.3, 0)
	cv.rig.distance = clampf(8.0 + float(ex["radius"]) * 1.2 + caster.distance_to(ex["mid"] as Vector3) * 0.4, 8.5, 16.0)


## The part of the screen the stage happens in (pixels: x, y, w, h), for cropping.
func _frame_box(ids: Dictionary) -> Array:
	var cam := cv.rig.camera
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k: String in ids:
		if k == "area":
			continue
		var t := cv.tokens[ids[k]] as Node3D
		for y: float in [0.0, 1.8]:
			var p := cam.unproject_position(t.global_position + Vector3(0, y, 0))
			lo = lo.min(p)
			hi = hi.max(p)
	# The spell's squares too, so a cloud or a wall sits inside the frame.
	for c: Variant in ids.get("area", []) as Array:
		var q := cam.unproject_position(cv.board.cell_center(c as Vector2i) + Vector3(0, 0.5, 0))
		lo = lo.min(q)
		hi = hi.max(q)
	return [lo.x, lo.y, hi.x - lo.x, hi.y - lo.y]
