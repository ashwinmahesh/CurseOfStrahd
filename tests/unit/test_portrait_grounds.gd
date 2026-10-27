extends TestCase
## Every portrait stands on the same ash-violet ground (UI QA ART-04, 2026-10-08): blender/portrait.py used to take the
## border's own colour, and 17 portraits came out on a darker or greyer square beside the rest in the turn order.


func test_every_portrait_has_the_same_ground() -> void:
	var ground := Look.color("ash_violet")
	var checked := 0
	var files: Array[String] = []
	for root: String in ["res://art/portraits/", ArtPaths.CORE + "art/portraits/"]:
		for f in DirAccess.get_files_at(root):
			files.append(root + f)
	for path in files:
		if not path.ends_with(".png"):
			continue
		var f := path.get_file()
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			continue
		var c := img.get_pixel(3, 3)
		assert_true(absf(c.r - ground.r) < 0.01 and absf(c.g - ground.g) < 0.01 and absf(c.b - ground.b) < 0.01,
			"%s stands on #%s, not ash violet" % [f, c.to_html(false)])
		checked += 1
	assert_true(checked > 300, "every portrait checked (%d)" % checked)
