class_name HeroLook
extends RefCounted
## The custom hero's look (docs/art/creator.md): a paper doll put together at run time from the pieces
## blender/creator_pieces.py makes. A body (gender, build and outfit) brings its walk and attack sheets with the skin
## keyed and, for every frame, where its bald head is; a head, a beard and a hairstyle are fitted over that head in
## each of the 8 directions. Skin and hair are stored as shade indices (red 0-3 under alpha 254 and 253) and tinted
## here with the chosen skin tone and hair colour, from palette ramps in art/creator/catalog.json.
##
## A custom character's `build.appearance` holds the picks (custom: true, gender, build, height, head, skin, hair,
## hair_colour, beard, outfit, portrait, voice) and `art`, its portrait id, which is also the id its sprite frames
## are known by: CombatToken.art_for registers the character here and DirectionalSprite.frames_for asks for them.

const ROOT := "res://art/creator"
const ALPHA_SKIN := 254
const ALPHA_HAIR := 253
const VIEWS: Array[String] = ["front", "front34", "side", "back34", "back"]
## Appearance keys that change the sprite (the rest, portrait and voice, don't).
const LOOK_KEYS: Array[String] = ["gender", "build", "head", "skin", "hair", "hair_colour", "beard", "outfit"]

static var _catalog: Dictionary = {}
static var _images: Dictionary = {}
static var _json: Dictionary = {}
static var _frames: Dictionary = {}
## Art id -> {appearance, species} for the custom characters met so far (CombatToken.art_for registers them).
static var _known: Dictionary = {}


# --- Catalog ----------------------------------------------------------------------------------------------------

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/catalog.json")) as Dictionary
	return _catalog


## The options of one category (genders, builds, heights, skins, heads, hair, hair_colours, beards, outfits,
## portraits, voices).
static func options(category: String) -> Array:
	return catalog().get(category, []) as Array


static func option(category: String, id: String) -> Dictionary:
	for o: Variant in options(category):
		if str((o as Dictionary)["id"]) == id:
			return o as Dictionary
	return {}


## A fresh look for `gender`, with the outfit suiting `class_id` when one does.
static func default_appearance(gender: String = "female", class_id: String = "") -> Dictionary:
	var d := ((catalog()["defaults"] as Dictionary)[gender] as Dictionary).duplicate()
	d["custom"] = true
	d["gender"] = gender
	if class_id != "":
		for o: Variant in options("outfits"):
			if class_id in ((o as Dictionary).get("suits", []) as Array):
				d["outfit"] = str((o as Dictionary)["id"])
				break
	d["art"] = str(d["portrait"])
	return d


static func is_custom(ch: Character) -> bool:
	return ch != null and bool((ch.build.get("appearance", {}) as Dictionary).get("custom", false))


## Ids of the pieces this look needs, by kind (bodies, heads, hair, beards); "none" pieces are left out.
static func pieces_for(app: Dictionary) -> Dictionary:
	var out := {"bodies": "%s_%s_%s" % [app.get("gender", "female"), app.get("build", "average"), app.get("outfit", "mercenary")],
		"heads": "%s_%s" % [app.get("gender", "female"), app.get("head", "plain")]}
	if str(app.get("hair", "none")) != "none":
		out["hair"] = str(app["hair"])
	if str(app.get("beard", "none")) != "none":
		out["beards"] = str(app["beard"])
	return out


## Whether every piece the look needs exists (the art set may still be partly drawn).
static func has_pieces(app: Dictionary) -> bool:
	var p := pieces_for(app)
	for kind: String in p:
		var path := _piece_png(kind, str(p[kind]), "walk")
		if not FileAccess.file_exists(path):
			return false
	return true


# --- Registry (art id -> look) --------------------------------------------------------------------------------

static func register(ch: Character) -> String:
	var app := ch.build.get("appearance", {}) as Dictionary
	var art := str(app.get("art", app.get("portrait", "hero_01")))
	_known[art] = {"appearance": app.duplicate(), "species": species_key(ch)}
	return art


static func known(art_id: String) -> bool:
	return _known.has(art_id)


## The sprite frames for a registered art id, or null.
static func frames_for_art(art_id: String) -> SpriteFrames:
	if not _known.has(art_id):
		return null
	return frames((_known[art_id] as Dictionary)["appearance"] as Dictionary)


static func height_for_art(art_id: String, fallback: float) -> float:
	if not _known.has(art_id):
		return fallback
	var k := _known[art_id] as Dictionary
	return height_units(k["appearance"] as Dictionary, str(k["species"]))


static func species_key(ch: Character) -> String:
	var choices := ch.build.get("choices", {}) as Dictionary
	var size := choices.get("species.size", []) as Array
	if not size.is_empty() and str(size[0]) == "small":
		return "small"
	return str(ch.build.get("species", "human"))


## Sprite height in world units: the species' usual height times the height pick.
static func height_units(app: Dictionary, species: String) -> float:
	var heights := catalog()["species_heights"] as Dictionary
	var base := float(heights.get(species, heights["default"]))
	return base * float(option("heights", str(app.get("height", "average"))).get("scale", 1.0))


# --- Composing --------------------------------------------------------------------------------------------------

## The look's walk and attack as one SpriteFrames (walk_<dir>, idle_<dir>, attack_<dir>, metadata hit_frame and
## casts), cached by the picks that change the sprite. Null when its pieces are missing.
static func frames(app: Dictionary) -> SpriteFrames:
	var sig := signature(app)
	if _frames.has(sig):
		return _frames[sig] as SpriteFrames
	if not has_pieces(app):
		return null
	var p := pieces_for(app)
	var body := _piece_json("bodies", str(p["bodies"]))
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var walk := compose_sheet(app, "walk")
	var walk_tex := _texture(walk)
	var w := body["walk"] as Dictionary
	var cell := Vector2i(int((w["cell"] as Array)[0]), int((w["cell"] as Array)[1]))
	for r in DirectionalSprite.DIRECTIONS.size():
		var d := DirectionalSprite.DIRECTIONS[r]
		var walk_anim := StringName("walk_" + d)
		sf.add_animation(walk_anim)
		sf.set_animation_speed(walk_anim, float(w["fps"]))
		sf.set_animation_loop(walk_anim, true)
		for f in int(w["frames"]):
			sf.add_frame(walk_anim, _atlas(walk_tex, Rect2(f * cell.x, r * cell.y, cell.x, cell.y)))
		var idle := StringName("idle_" + d)
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 1.0)
		sf.set_animation_loop(idle, true)
		sf.add_frame(idle, _atlas(walk_tex, Rect2(0, r * cell.y, cell.x, cell.y)))
	if body.has("attack"):
		var a := body["attack"] as Dictionary
		var atk_tex := _texture(compose_sheet(app, "attack"))
		var acell := Vector2i(int((a["cell"] as Array)[0]), int((a["cell"] as Array)[1]))
		var durations := a["durations"] as Array
		for r in DirectionalSprite.DIRECTIONS.size():
			var anim := StringName("attack_" + DirectionalSprite.DIRECTIONS[r])
			sf.add_animation(anim)
			sf.set_animation_speed(anim, float(a["fps"]))
			sf.set_animation_loop(anim, false)
			for f in int(a["frames"]):
				sf.add_frame(anim, _atlas(atk_tex, Rect2(f * acell.x, r * acell.y, acell.x, acell.y)), float(durations[f]))
		sf.set_meta("hit_frame", int(a["hit_frame"]))
		sf.set_meta("casts", bool(a["casts"]))
	_frames[sig] = sf
	return sf


static func signature(app: Dictionary) -> String:
	var parts: Array[String] = []
	for k in LOOK_KEYS:
		parts.append(str(app.get(k, "")))
	return "|".join(parts)


## One whole sheet ("walk" or "attack") of the look: the body tinted, a fitted head on every frame.
static func compose_sheet(app: Dictionary, kind: String) -> Image:
	var p := pieces_for(app)
	var body := _piece_json("bodies", str(p["bodies"]))
	var spec := body[kind] as Dictionary
	var sheet := _image(_piece_png("bodies", str(p["bodies"]), kind)).duplicate() as Image
	var cell := Vector2i(int((spec["cell"] as Array)[0]), int((spec["cell"] as Array)[1]))
	var cols := int(spec["frames"])
	var skin := ramp("skins", str(app.get("skin", "fair")))
	var hair := ramp("hair_colours", str(app.get("hair_colour", "dark_brown")))
	var boxes: Array[Rect2i] = []
	for i in (spec["skin"] as Array).size():
		var b: Variant = (spec["skin"] as Array)[i]
		if b == null:
			continue
		var bb := b as Array
		var origin := Vector2i((i % cols) * cell.x, (i / cols) * cell.y)
		boxes.append(Rect2i(origin + Vector2i(int(bb[0]), int(bb[1])), Vector2i(int(bb[2]) - int(bb[0]), int(bb[3]) - int(bb[1]))))
	tint(sheet, boxes, skin, hair)
	var stacks := {}
	var heads := spec["heads"] as Array
	for i in heads.size():
		var d := DirectionalSprite.DIRECTIONS[i / cols]
		if not stacks.has(d):
			var dv := (body["dirs"] as Dictionary)[d] as Dictionary
			stacks[d] = head_stack(app, str(dv["view"]), bool(dv["mirror"]))
		var origin := Vector2i((i % cols) * cell.x, (i / cols) * cell.y)
		_place(sheet, stacks[d] as Dictionary, heads[i] as Array, Rect2i(origin, cell))
	return sheet


## The look's frames for one direction ("walk": the cycle, "attack": the blow, "idle": the standing frame), as
## textures: what the creator's preview turns and animates without composing whole sheets.
static func preview_frames(app: Dictionary, kind: String, dir: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not has_pieces(app):
		return out
	var p := pieces_for(app)
	var body := _piece_json("bodies", str(p["bodies"]))
	var sheet_kind := "walk" if kind != "attack" else "attack"
	if not body.has(sheet_kind):
		return out
	var spec := body[sheet_kind] as Dictionary
	var cell := Vector2i(int((spec["cell"] as Array)[0]), int((spec["cell"] as Array)[1]))
	var cols := int(spec["frames"])
	var row := DirectionalSprite.DIRECTIONS.find(dir)
	var src := _image(_piece_png("bodies", str(p["bodies"]), sheet_kind))
	var dv := (body["dirs"] as Dictionary)[dir] as Dictionary
	var stack := head_stack(app, str(dv["view"]), bool(dv["mirror"]))
	var skin := ramp("skins", str(app.get("skin", "fair")))
	var hair := ramp("hair_colours", str(app.get("hair_colour", "dark_brown")))
	var count := 1 if kind == "idle" else cols
	for f in count:
		var i := row * cols + f
		var img := src.get_region(Rect2i(f * cell.x, row * cell.y, cell.x, cell.y))
		var b: Variant = (spec["skin"] as Array)[i]
		if b != null:
			var bb := b as Array
			var boxes: Array[Rect2i] = [Rect2i(int(bb[0]), int(bb[1]), int(bb[2]) - int(bb[0]), int(bb[3]) - int(bb[1]))]
			tint(img, boxes, skin, hair)
		_place(img, stack, (spec["heads"] as Array)[i] as Array, Rect2i(Vector2i.ZERO, cell))
		out.append(ImageTexture.create_from_image(img))
	return out


## Head, beard and hair for one view, tinted and lined up by the skull: {image, cx, top, skull_w} in the stack's
## pixels. Mirrored for the west-facing directions.
static func head_stack(app: Dictionary, view: String, mirror: bool) -> Dictionary:
	var p := pieces_for(app)
	var skin := ramp("skins", str(app.get("skin", "fair")))
	var hair := ramp("hair_colours", str(app.get("hair_colour", "dark_brown")))
	var layers: Array[Dictionary] = []
	for kind: String in ["heads", "beards", "hair"]:
		if not p.has(kind):
			continue
		var meta := ((_piece_json(kind, str(p[kind]))["views"] as Dictionary).get(view, {})) as Dictionary
		if meta.is_empty() or bool(meta.get("empty", false)):
			continue
		var rect := meta["rect"] as Array
		var img := _image(_piece_png(kind, str(p[kind]), "")).get_region(Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])))
		var boxes: Array[Rect2i] = [Rect2i(Vector2i.ZERO, img.get_size())]
		tint(img, boxes, skin, hair)
		layers.append({"image": img, "kind": kind, "cx": float(meta["cx"]), "top": float(meta["top"]),
			"skull_w": float(meta["skull_w"]), "cut": float(meta.get("cut", float(meta["top"]) + float(meta["skull_w"])))})
	var base := layers[0]
	# Place every layer in the head's frame. Hair sits on the skull: scaled by its width, from its top. A beard hangs
	# from the jaw: scaled by the head's height and lined up at the neck, so a longer or shorter face still wears it.
	var placed: Array[Dictionary] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for l in layers:
		var beard := str(l["kind"]) == "beards"
		var s := float(base["skull_w"]) / maxf(1.0, float(l["skull_w"]))
		if beard:
			s = (float(base["cut"]) - float(base["top"])) / maxf(1.0, float(l["cut"]) - float(l["top"]))
		var img := l["image"] as Image
		if absf(s - 1.0) > 0.03:
			img = img.duplicate() as Image
			img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_NEAREST)
		var pos := Vector2(float(base["cx"]) - float(l["cx"]) * s, float(base["top"]) - float(l["top"]) * s)
		if beard:
			pos.y = float(base["cut"]) - float(l["cut"]) * s
		placed.append({"image": img, "pos": pos})
		lo = Vector2(minf(lo.x, pos.x), minf(lo.y, pos.y))
		hi = Vector2(maxf(hi.x, pos.x + img.get_width()), maxf(hi.y, pos.y + img.get_height()))
	var size := Vector2i(ceili(hi.x - lo.x), ceili(hi.y - lo.y))
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for pl in placed:
		var img := pl["image"] as Image
		var at := Vector2i(roundi((pl["pos"] as Vector2).x - lo.x), roundi((pl["pos"] as Vector2).y - lo.y))
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	var cx := float(base["cx"]) - lo.x
	if mirror:
		out.flip_x()
		cx = size.x - cx
	return {"image": out, "cx": cx, "top": float(base["top"]) - lo.y, "skull_w": float(base["skull_w"])}


## Draws a head stack onto `dst` over the bald head at `anchor` ([centre x, skull top, skull width] in `cell`'s
## pixels), scaled to fit and clipped to the cell.
static func _place(dst: Image, stack: Dictionary, anchor: Array, cell: Rect2i) -> void:
	var img := stack["image"] as Image
	var s := float(anchor[2]) / maxf(1.0, float(stack["skull_w"]))
	if absf(s - 1.0) > 0.03:
		img = img.duplicate() as Image
		img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_NEAREST)
	var at := cell.position + Vector2i(roundi(float(anchor[0]) - float(stack["cx"]) * s), roundi(float(anchor[1]) - float(stack["top"]) * s))
	var r := Rect2i(at, img.get_size()).intersection(cell)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	dst.blend_rect(img, Rect2i(r.position - at, r.size), r.position)


## Replaces keyed pixels inside `boxes` with the ramp colour of their shade: alpha 254 from `skin`, 253 from `hair`.
static func tint(img: Image, boxes: Array[Rect2i], skin: PackedColorArray, hair: PackedColorArray) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var data := img.get_data()
	var sk := PackedByteArray()
	var hr := PackedByteArray()
	for c in skin:
		sk.append_array([c.r8, c.g8, c.b8])
	for c in hair:
		hr.append_array([c.r8, c.g8, c.b8])
	for box in boxes:
		var r := box.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		for y in range(r.position.y, r.end.y):
			var i := (y * w + r.position.x) * 4
			for x in r.size.x:
				var a := data[i + 3]
				if a == ALPHA_SKIN or a == ALPHA_HAIR:
					var ramp_bytes := sk if a == ALPHA_SKIN else hr
					var k := mini(int(data[i]), 3) * 3
					data[i] = ramp_bytes[k]
					data[i + 1] = ramp_bytes[k + 1]
					data[i + 2] = ramp_bytes[k + 2]
					data[i + 3] = 255
				i += 4
	img.set_data(w, img.get_height(), false, Image.FORMAT_RGBA8, data)


## The four colours (deep, shadow, base, light) of a skin tone or hair colour.
static func ramp(category: String, id: String) -> PackedColorArray:
	var o := option(category, id)
	if o.is_empty():
		o = options(category)[0] as Dictionary
	var out := PackedColorArray()
	for n: Variant in o["ramp"]:
		out.append(Look.color(str(n)))
	return out


# --- Files ------------------------------------------------------------------------------------------------------

static func _piece_png(kind: String, id: String, sheet: String) -> String:
	if kind == "bodies":
		return "%s/pieces/bodies/%s/%s.png" % [ROOT, id, sheet]
	return "%s/pieces/%s/%s.png" % [ROOT, kind, id]


static func _piece_json(kind: String, id: String) -> Dictionary:
	var path := "%s/pieces/bodies/%s/piece.json" % [ROOT, id] if kind == "bodies" else "%s/pieces/%s/%s.json" % [ROOT, kind, id]
	if not _json.has(path):
		_json[path] = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	return _json[path] as Dictionary


## Pieces are read as raw PNG bytes (art/creator/pieces is hidden from the importer, which would compress away the
## alpha keys).
static func _image(path: String) -> Image:
	if not _images.has(path):
		var img := Image.new()
		img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_images[path] = img
	return _images[path] as Image


static func _texture(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _atlas(tex: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	return a
