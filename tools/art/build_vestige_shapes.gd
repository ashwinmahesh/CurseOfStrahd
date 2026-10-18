extends SceneTree
## The shapes held in the Amber Temple's blocks of amber: make vestige_shapes (Amber Temple Look Plan §3.2). Each entry
## of art/amber_shapes.json composes a few game-icons.net silhouettes (art/sourced/game_icons, CC BY 3.0, the artists
## credited on the Credits screen) into one white-on-transparent picture, art/textures/amber/shapes/<id>.png, which
## AmberGlow draws dark inside the block (the shader tints it); layers on the `orbit` plane go in <id>_orbit.png and
## turn slowly. A layer's `mode: "cut"` is a hole in what the plane's other layers draw (a mouth in a face). Free art
## only: no generation, no download. Shapes whose entry left the file are removed.
## Run: godot --headless --path . --script res://tools/art/build_vestige_shapes.gd

const DATA := "res://art/amber_shapes.json"
const PACK := "res://art/sourced/game_icons/icons/ffffff/transparent/1x1/"
const OUT := "res://art/textures/amber/shapes/"
## Godot imports each picture with mipmaps: the shader reads a coarse one to soften the shape, as if seen through the glass.
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\nmipmaps/generate=true\n"


func _init() -> void:
	var data := JSON.parse_string(FileAccess.get_file_as_string(DATA)) as Dictionary
	var size := int(data.get("size", 256))
	var shapes := data["shapes"] as Dictionary
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var problems: Array[String] = []
	var wanted := {}
	var written := 0
	for id: String in shapes:
		var entry := shapes[id] as Dictionary
		for plane: String in ["main", "orbit"]:
			var layers := _layers(entry, plane)
			if layers.is_empty():
				continue
			var file := "%s.png" % id if plane == "main" else "%s_orbit.png" % id
			wanted[file] = true
			var img := _compose(layers, size, problems, id)
			if img == null:
				continue
			img.save_png(OUT + file)
			if not FileAccess.file_exists(OUT + file + ".import"):
				FileAccess.open(OUT + file + ".import", FileAccess.WRITE).store_string(IMPORT)
			written += 1
	for f in DirAccess.get_files_at(OUT):
		if f.ends_with(".png") and not wanted.has(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f + ".import"))
	for p in problems:
		printerr("vestige_shapes: " + p)
	print("vestige_shapes: %d pictures written to %s" % [written, OUT])
	quit(1 if not problems.is_empty() else 0)


## The entry's layers on one plane ("main" unless a layer says `plane`).
static func _layers(entry: Dictionary, plane: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for l: Variant in entry.get("layers", []):
		if str((l as Dictionary).get("plane", "main")) == plane:
			out.append(l as Dictionary)
	return out


## The plane's layers as one picture: what they add, less what the `cut` ones take away.
static func _compose(layers: Array[Dictionary], size: int, problems: Array[String], id: String) -> Image:
	var added := ""
	var cut := ""
	for layer in layers:
		var path := PACK + str(layer["icon"]) + ".svg"
		if not FileAccess.file_exists(path):
			problems.append("%s: no silhouette %s" % [id, layer["icon"]])
			return null
		var source := FileAccess.get_file_as_string(path)
		var body := source.substr(source.find(">") + 1)
		body = body.substr(0, body.rfind("</svg>")).replace("<path d=\"M0 0h512v512H0z\"/>", "")
		var at := layer.get("at", [0.5, 0.5]) as Array
		var scale := float(layer.get("size", 1.0)) * float(size) / 512.0
		var flip := -1.0 if bool(layer.get("flip", false)) else 1.0
		var g := "<g transform=\"translate(%.2f %.2f) rotate(%.2f) scale(%.4f %.4f) translate(-256 -256)\">%s</g>" % [
			float(at[0]) * size, float(at[1]) * size, float(layer.get("rot", 0.0)), scale * flip, scale, body]
		if str(layer.get("mode", "add")) == "cut":
			cut += g
		else:
			added += g
	var img := _raster(added, size)
	if img == null:
		problems.append("%s: did not rasterize" % id)
		return null
	if cut != "":
		var hole := _raster(cut, size)
		if hole == null:
			problems.append("%s: its cut did not rasterize" % id)
			return null
		for y in size:
			for x in size:
				var c := img.get_pixel(x, y)
				c.a *= 1.0 - hole.get_pixel(x, y).a
				img.set_pixel(x, y, c)
	return img


static func _raster(body: String, size: int) -> Image:
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 %d %d\" width=\"%d\" height=\"%d\">%s</svg>" % [
		size, size, size, size, body]
	var img := Image.new()
	return img if img.load_svg_from_string(svg, 1.0) == OK else null
