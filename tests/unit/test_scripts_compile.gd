extends TestCase
## Every script in the project compiles, with the autoloads there as in the game (make lint compiles rules/, combat/
## and story/ without them). A parse error anywhere also breaks every script that uses it, so make check runs this for
## any script change, whatever tests it picks.

const SKIP := ["res://.godot", "res://addons"]


static func scripts(dir: String = "res://") -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		var path := dir.path_join(d)
		if path in SKIP or d.begins_with("."):
			continue
		out.append_array(scripts(path))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func test_every_script_compiles() -> void:
	var broken: Array[String] = []
	var all := scripts()
	for path in all:
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			broken.append(path)
	assert_true(all.size() > 300, "found the scripts (%d)" % all.size())
	assert_eq(broken, [] as Array[String], "scripts that don't compile")
