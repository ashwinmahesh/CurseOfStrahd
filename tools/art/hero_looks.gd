extends SceneTree
## A contact sheet of custom hero looks for checking the paper doll (docs/art/creator.md): each row is one look
## (random picks, seeded, plus each outfit at least once) standing in five directions and mid-stride and mid-blow.
##
## godot --headless --path . --script res://tools/art/hero_looks.gd -- [--out captures/hero_looks.png] [--rows 12] [--seed 3]

const DIRS: Array[String] = ["s", "se", "e", "ne", "n"]
const CELL := 160


func _init() -> void:
	var out := "res://captures/hero_looks.png"
	var rows := 12
	var seed_value := 3
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out":
				out = args[i + 1]
			"--rows":
				rows = int(args[i + 1])
			"--seed":
				seed_value = int(args[i + 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var outfits := HeroLook.options("outfits")
	var looks: Array[Dictionary] = []
	for i in rows:
		var gender := str((HeroLook.options("genders")[rng.randi_range(0, 1)] as Dictionary)["id"])
		var app := HeroLook.default_appearance(gender)
		for key: Array in [["builds", "build"], ["heights", "height"], ["skins", "skin"], ["heads", "head"], ["hair", "hair"],
				["hair_colours", "hair_colour"], ["beards", "beard"]]:
			var opts := HeroLook.options(str(key[0]))
			app[str(key[1])] = str((opts[rng.randi_range(0, opts.size() - 1)] as Dictionary)["id"])
		app["outfit"] = str((outfits[i % outfits.size()] as Dictionary)["id"])
		if gender == "female" and rng.randf() < 0.8:
			app["beard"] = "none"
		looks.append(app)
	var cols := DIRS.size() + 2
	var sheet := Image.create_empty(cols * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.08, 0.11))
	var missing := 0
	for r in looks.size():
		var app := looks[r]
		if not HeroLook.has_pieces(app):
			missing += 1
			continue
		var tiles: Array[Texture2D] = []
		for d in DIRS:
			tiles.append(HeroLook.preview_frames(app, "idle", d)[0])
		tiles.append(HeroLook.preview_frames(app, "walk", "se")[2])
		var atk := HeroLook.preview_frames(app, "attack", "se")
		tiles.append(atk[2] if atk.size() > 2 else atk[0])
		for c in tiles.size():
			var img := tiles[c].get_image()
			var s := float(CELL) / float(maxi(img.get_width(), img.get_height()))
			img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(c * CELL + (CELL - img.get_width()) / 2, r * CELL + (CELL - img.get_height()) / 2))
		print("%d: %s" % [r, HeroLook.signature(app)])
	sheet.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	print("hero looks: %s (%d rows, %d without art yet)" % [out, rows, missing])
	quit()
