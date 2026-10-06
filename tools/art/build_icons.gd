extends SceneTree
## Spell and item icons: make icons. Each key in art/icons.json names a game-icons.net silhouette
## (art/sourced/game_icons, CC BY 3.0, credited on the Credits screen); this frames it as a menu tile in the UI
## colours and writes art/icons/<spells|items>/<key>.png. Spells are gold on a crimson glow, items pale bone on
## black, both in the same gilt frame. Tiles whose key left the catalog are removed.
## Run: godot --headless --path . --script res://tools/art/build_icons.gd

const CATALOG := "res://art/icons.json"
const PACK := "res://art/sourced/game_icons/icons/ffffff/transparent/1x1/"
const OUT := "res://art/icons/"
const SIZE := 128
const KINDS: Array[String] = ["spells", "items"]

static var _colours: Dictionary = {}

## Godot imports each tile with mipmaps so it stays smooth when a list draws it small.
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\nmipmaps/generate=true\n"


func _init() -> void:
	var catalog := JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) as Dictionary
	var missing: Array[String] = []
	var written := 0
	for kind in KINDS:
		var keys := catalog.get(kind, {}) as Dictionary
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + kind))
		for key: String in keys:
			var glyph_path := PACK + str(keys[key]) + ".svg"
			if not FileAccess.file_exists(glyph_path):
				missing.append("%s/%s: %s" % [kind, key, keys[key]])
				continue
			var img := Image.new()
			var svg := tile(kind, FileAccess.get_file_as_string(glyph_path))
			if img.load_svg_from_string(svg, SIZE / 512.0) != OK:
				missing.append("%s/%s: %s did not rasterize" % [kind, key, keys[key]])
				continue
			var png := OUT + "%s/%s.png" % [kind, key]
			img.save_png(png)
			if not FileAccess.file_exists(png + ".import"):
				FileAccess.open(png + ".import", FileAccess.WRITE).store_string(IMPORT)
			written += 1
		for f in DirAccess.get_files_at(OUT + kind):
			if f.ends_with(".png") and not keys.has(f.get_basename()):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + kind.path_join(f)))
				DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + kind.path_join(f + ".import")))
	for m in missing:
		printerr("icons: no silhouette for " + m)
	print("icons: %d tiles written to %s" % [written, OUT])
	quit(1 if not missing.is_empty() else 0)


## The tile as one SVG: background, the glyph with its outline (and a glow for spells), then the gilt frame.
static func tile(kind: String, source: String) -> String:
	var body := source.substr(source.find(">") + 1)
	body = body.substr(0, body.rfind("</svg>"))
	var spell := kind == "spells"
	var bg: Array[String] = ["ui_oxblood", "ui_black", "ui_black"]
	var face: Array[String] = ["ivory", "parchment", "bone"]
	if spell:
		bg = ["blood", "blood_deep", "ui_black"]
		face = ["gilt_light", "gilt", "gilt_dark"]
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\" width=\"512\" height=\"512\"><defs>"
	s += "<radialGradient id=\"bg\" cx=\"50%%\" cy=\"45%%\" r=\"62%%\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.6\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></radialGradient>" % [c(bg[0]), c(bg[1]), c(bg[2])]
	s += "<linearGradient id=\"face\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.5\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [c(face[0]), c(face[1]), c(face[2])]
	s += "<linearGradient id=\"rim\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.45\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [c("gilt_light"), c("gilt"), c("gilt_dark")]
	s += "</defs>"
	s += "<rect x=\"6\" y=\"6\" width=\"500\" height=\"500\" rx=\"44\" fill=\"url(#bg)\"/>"
	s += "<g transform=\"translate(76 76) scale(0.703125)\">"
	if spell:
		s += _paint(body, "fill=\"none\" stroke=\"%s\" stroke-opacity=\"0.30\" stroke-width=\"72\" stroke-linejoin=\"round\"" % c("vampire_red"))
		s += _paint(body, "fill=\"none\" stroke=\"%s\" stroke-opacity=\"0.45\" stroke-width=\"44\" stroke-linejoin=\"round\"" % c("crimson"))
	else:
		s += "<g transform=\"translate(10 14)\">" + _paint(body, "fill=\"%s\" fill-opacity=\"0.7\" stroke=\"%s\" stroke-opacity=\"0.7\" stroke-width=\"24\" stroke-linejoin=\"round\"" % [c("void"), c("void")]) + "</g>"
	s += _paint(body, "fill=\"%s\" stroke=\"%s\" stroke-width=\"26\" stroke-linejoin=\"round\"" % [c("ui_black"), c("ui_black")])
	s += _paint(body, "fill=\"url(#face)\"")
	s += "</g>"
	s += "<rect x=\"16\" y=\"16\" width=\"480\" height=\"480\" rx=\"36\" fill=\"none\" stroke=\"url(#rim)\" stroke-width=\"20\"/>"
	s += "<rect x=\"42\" y=\"42\" width=\"428\" height=\"428\" rx=\"16\" fill=\"none\" stroke=\"%s\" stroke-width=\"5\"/>" % c("gilt_dark")
	for corner: Vector2 in [Vector2(42, 42), Vector2(470, 42), Vector2(42, 470), Vector2(470, 470)]:
		s += "<path d=\"M%d %dl14 14l-14 14l-14 -14z\" fill=\"%s\" stroke=\"%s\" stroke-width=\"4\"/>" % [corner.x, corner.y - 14, c("gilt_light"), c("ui_black")]
	return s + "</svg>"


## The silhouette's paths with their white fill swapped for `paint`.
static func _paint(body: String, paint: String) -> String:
	return body.replace("fill=\"#fff\"", paint)


## A palette colour as hex (art/palette, the same lists Look reads; Look itself needs the class cache).
static func c(name: String) -> String:
	if _colours.is_empty():
		for f: String in ["res://art/palette/palette.json", "res://art/palette/ui_palette.json"]:
			_colours.merge(JSON.parse_string(FileAccess.get_file_as_string(f)) as Dictionary)
	assert(_colours.has(name), "Unknown palette colour: %s" % name)
	return str(_colours[name])
