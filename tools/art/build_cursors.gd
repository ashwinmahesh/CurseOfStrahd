extends SceneTree
## Mouse cursors in the Crimson scheme (docs/plans/ui_polish.md): a gilt pointer with a black outline, and gilt
## game-icons.net silhouettes (art/sourced/game_icons, CC BY 3.0, already credited) for what the mouse is over: a
## gauntlet to use something, a speech scroll to talk, crossed swords to attack, a padlock for what's locked, boot
## prints to walk. Written to art/ui/cursors/<name>.png at SIZE px; ui/common/cursors.gd installs them.
## Run: make cursors

const PACK := "res://art/sourced/game_icons/icons/ffffff/transparent/1x1/"
const OUT := "res://art/ui/cursors/"
const SIZE := 48
## name -> silhouette ("" = the drawn pointer)
const CURSORS := {"pointer": "", "use": "delapouite/gauntlet", "talk": "skoll/talk", "attack": "lorc/crossed-swords",
	"locked": "lorc/padlock", "walk": "lorc/boot-prints", "look": "lorc/magnifying-glass"}
## The classic pointer, tip at the top left (its hotspot), in a 512 box.
const POINTER := "M44 28 L44 430 L146 334 L214 482 L290 450 L222 304 L360 304 Z"
const IMPORT := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n"

static var _colours: Dictionary = {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bad := 0
	for name: String in CURSORS:
		var glyph := str(CURSORS[name])
		var body := ""
		if glyph == "":
			body = "<path fill=\"#fff\" d=\"%s\"/>" % POINTER
		else:
			var src := FileAccess.get_file_as_string(PACK + glyph + ".svg")
			body = src.substr(src.find(">") + 1)
			body = body.substr(0, body.rfind("</svg>"))
			# The pack draws a black square behind each glyph; drop it.
			body = body.replace("<path d=\"M0 0h512v512H0z\"/>", "")
		var img := Image.new()
		if img.load_svg_from_string(_svg(body, glyph == ""), SIZE / 512.0) != OK:
			printerr("cursors: %s did not rasterize" % name)
			bad += 1
			continue
		var png := OUT + name + ".png"
		img.save_png(png)
		if not FileAccess.file_exists(png + ".import"):
			FileAccess.open(png + ".import", FileAccess.WRITE).store_string(IMPORT)
	print("cursors: %d written to %s" % [CURSORS.size() - bad, OUT])
	quit(1 if bad > 0 else 0)


## The glyph in gilt (light at the top, dark at the foot) over a thick black outline, a soft shadow under it.
static func _svg(body: String, pointer: bool) -> String:
	var s := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\" width=\"512\" height=\"512\"><defs>"
	s += "<linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"0.55\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs>" % [c("gilt_light"), c("gilt"), c("gilt_dark")]
	# Icons sit inset so the outline fits; the pointer keeps its tip in the corner.
	s += "<g transform=\"%s\">" % ("translate(8 8) scale(0.94)" if pointer else "translate(56 56) scale(0.78)")
	s += "<g transform=\"translate(14 18)\">" + _paint(body, "fill=\"%s\" fill-opacity=\"0.55\" stroke=\"%s\" stroke-opacity=\"0.55\" stroke-width=\"40\" stroke-linejoin=\"round\"" % [c("void"), c("void")]) + "</g>"
	s += _paint(body, "fill=\"%s\" stroke=\"%s\" stroke-width=\"%d\" stroke-linejoin=\"round\"" % [c("ui_black"), c("ui_black"), 34 if pointer else 44])
	s += _paint(body, "fill=\"url(#g)\"")
	return s + "</g></svg>"


static func _paint(body: String, paint: String) -> String:
	return body.replace("fill=\"#fff\"", paint)


static func c(name: String) -> String:
	if _colours.is_empty():
		for f: String in ["res://art/palette/palette.json", "res://art/palette/ui_palette.json"]:
			_colours.merge(JSON.parse_string(FileAccess.get_file_as_string(f)) as Dictionary)
	return str(_colours[name])
