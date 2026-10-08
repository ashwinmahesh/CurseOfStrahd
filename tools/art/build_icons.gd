extends SceneTree
## Spell, item and ability icons: make icons. Each key in art/icons.json names a game-icons.net silhouette
## (art/sourced/game_icons, CC BY 3.0, credited on the Credits screen), optionally "@<tint>", and this paints it as a
## framed tile in art/icons/<spells|items|features>/<key>.png (features: the abilities a hero switches on, shown on the
## party frames, ui/common/effect_icons.gd). A tint (the catalog's "tints") gives the silhouette's colours top
## to bottom, the background glow and, for spells, a halo: spells by flavour (fire, frost, necrotic...), items in
## their natural colours (steel, wood, leather...). Every tile shares the gilt frame of the menus. Tiles whose key left
## the catalog are removed.
##
## The catalog's "ui" keys are menu glyphs instead: the silhouette as a plain white shape, like the menu icons
## `make ui_art` writes, which buttons tint gilt. They go beside those in art/ui/icons (UiKit.icon), and nothing else
## there is touched.
## Run: godot --headless --path . --script res://tools/art/build_icons.gd [-- --ui | --kind=<spells|items|features>]

const CATALOG := "res://art/icons.json"
const PACK := "res://art/sourced/game_icons/icons/ffffff/transparent/1x1/"
const OUT := "res://art/icons/"
const SIZE := 128
const KINDS: Array[String] = ["spells", "items", "features"]
## The tint an entry without "@<tint>" gets.
const DEFAULT_TINT := {"spells": "arcane", "items": "cloth", "features": "arcane"}
const UI_OUT := "res://art/ui/icons/"
const UI_SIZE := 96
## Backgrounds when a tint names none: a crimson glow for spells, near black for items.
const DEFAULT_BG := {"spells": ["blood", "blood_deep", "ui_black"], "items": ["ui_oxblood", "ui_black", "ui_black"],
	"features": ["blood", "blood_deep", "ui_black"]}

static var _colours: Dictionary = {}

## Godot imports each tile with mipmaps so it stays smooth when a list draws it small.
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\nmipmaps/generate=true\n"


func _init() -> void:
	var catalog := JSON.parse_string(FileAccess.get_file_as_string(CATALOG)) as Dictionary
	var tints := catalog.get("tints", {}) as Dictionary
	var missing: Array[String] = []
	var written := 0
	# `-- --ui` writes only the menu glyphs, `-- --kind=<kind>` only that kind's tiles.
	var kinds: Array[String] = []
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kind="):
			only = a.get_slice("=", 1)
	if only != "":
		kinds.append(only)
	elif not "--ui" in OS.get_cmdline_user_args():
		kinds = KINDS
	for kind in kinds:
		var keys := catalog.get(kind, {}) as Dictionary
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + kind))
		for key: String in keys:
			var entry := str(keys[key])
			var glyph_path := PACK + entry.get_slice("@", 0) + ".svg"
			var tint_name := entry.get_slice("@", 1) if entry.contains("@") else str(DEFAULT_TINT[kind])
			if not FileAccess.file_exists(glyph_path) or not tints.has(tint_name):
				missing.append("%s/%s: %s" % [kind, key, entry])
				continue
			var img := Image.new()
			var svg := tile(kind, FileAccess.get_file_as_string(glyph_path), tints[tint_name] as Dictionary)
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
	var glyphs := catalog.get("ui", {}) as Dictionary if only == "" else {}
	for key: String in glyphs:
		var glyph_path := PACK + str(glyphs[key]) + ".svg"
		var img := Image.new()
		if not FileAccess.file_exists(glyph_path) or img.load_svg_from_string(glyph(FileAccess.get_file_as_string(glyph_path)), UI_SIZE / 512.0) != OK:
			missing.append("ui/%s: %s" % [key, glyphs[key]])
			continue
		var png := UI_OUT + key + ".png"
		img.save_png(png)
		written += 1
	for m in missing:
		printerr("icons: no silhouette or tint for " + m)
	print("icons: %d tiles written to %s" % [written, OUT])
	quit(1 if not missing.is_empty() else 0)


## The tile as one SVG: background, the glyph with its outline (a halo for spells, a drop shadow for items), then the
## gilt frame. `tint`: {"face": [top, middle, bottom], "bg": [centre, middle, edge], "glow": colour} (palette names).
static func tile(kind: String, source: String, tint: Dictionary) -> String:
	var body := source.substr(source.find(">") + 1)
	body = body.substr(0, body.rfind("</svg>"))
	var face := tint["face"] as Array
	var bg := tint.get("bg", DEFAULT_BG[kind]) as Array
	var glow := str(tint.get("glow", ""))
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\" width=\"512\" height=\"512\"><defs>"
	s += "<radialGradient id=\"bg\" cx=\"50%%\" cy=\"45%%\" r=\"62%%\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.6\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></radialGradient>" % [c(str(bg[0])), c(str(bg[1])), c(str(bg[2]))]
	s += "<linearGradient id=\"face\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.5\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [c(str(face[0])), c(str(face[1])), c(str(face[2]))]
	s += "<linearGradient id=\"rim\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.45\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>" % [c("gilt_light"), c("gilt"), c("gilt_dark")]
	s += "</defs>"
	s += "<rect x=\"6\" y=\"6\" width=\"500\" height=\"500\" rx=\"44\" fill=\"url(#bg)\"/>"
	s += "<g transform=\"translate(76 76) scale(0.703125)\">"
	if glow != "":
		s += _paint(body, "fill=\"none\" stroke=\"%s\" stroke-opacity=\"0.28\" stroke-width=\"72\" stroke-linejoin=\"round\"" % c(glow))
		s += _paint(body, "fill=\"none\" stroke=\"%s\" stroke-opacity=\"0.45\" stroke-width=\"44\" stroke-linejoin=\"round\"" % c(glow))
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


## A menu glyph: the silhouette in white on nothing, filling the square as the menu icons do.
static func glyph(source: String) -> String:
	var body := source.substr(source.find(">") + 1)
	body = body.substr(0, body.rfind("</svg>"))
	# The pack draws a black square behind each glyph; drop it.
	body = body.replace("<path d=\"M0 0h512v512H0z\"/>", "")
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\" width=\"512\" height=\"512\"><g transform=\"translate(12 12) scale(0.953125)\">%s</g></svg>" % body


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
