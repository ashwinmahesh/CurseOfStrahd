extends TestCase
## The engine split (docs/plans/engine_split.md): rules/, combat/ and the story engine core are meant to move into the
## shared dnd_core repo, so they must not name this campaign. Every code line (comment-only lines are skipped) that
## names a campaign id, place or character counts as a hit; tests/fixtures/engine_campaign_baseline.json holds today's
## hits per file. A file may only lose hits: a new one fails, and a file that got cleaner must lower its entry so the
## baseline only shrinks. The campaign modules of story/ are not engine and are listed in CAMPAIGN_MODULES.
## Regenerate the baseline after cleaning up: ENGINE_NAMES_WRITE=1 make test FILES=test_engine_names.gd prints it.

const BASELINE := "res://tests/fixtures/engine_campaign_baseline.json"
const ENGINE_DIRS: Array[String] = ["res://rules", "res://combat", "res://story"]

## Files of story/ that are the campaign itself (they move to the Strahd game's module, not to dnd_core).
const CAMPAIGN_MODULES: Array[String] = [
	"res://story/tarokka.gd", "res://story/strahd_presence.gd", "res://story/oracles.gd", "res://story/endings.gd",
	"res://story/cheat_codes.gd",
]

const NAMES: Array[String] = ["strahd", "barovi", "ravenloft", "tarokka", "vallaki", "krezk", "ireena", "ezmerelda", "izek", "rahadin",
	"amber_temple", "death_house", "sunsword", "heart_of_sorrow", "argynvost", "vistan", "svalich", "yester_hill",
	"wachter", "kolyan", "ismark", "lysaga", "vasilka", "mongrelfolk", "kasimir", "van_richten", "madam_eva", "berez",
	"tsolenka", "gundarak", "wizard_of_wines", "blood_of_the_vine"]


func _files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_files("%s/%s" % [dir, sub], out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir, f])


func _hits(path: String) -> int:
	var n := 0
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code := line.strip_edges()
		if code.begins_with("#") or code.is_empty():
			continue
		code = code.to_lower()
		for word in NAMES:
			if code.contains(word):
				n += 1
				break
	return n


func _scan() -> Dictionary:
	var files: Array[String] = []
	for dir in ENGINE_DIRS:
		_files(dir, files)
	files.sort()
	var out := {}
	for f in files:
		if f in CAMPAIGN_MODULES:
			continue
		var n := _hits(f)
		if n > 0:
			out[f.trim_prefix("res://")] = n
	return out


func test_engine_files_name_no_new_campaign_ids() -> void:
	var now := _scan()
	if OS.get_environment("ENGINE_NAMES_WRITE") == "1":
		print("ENGINE_BASELINE ", JSON.stringify(now, "\t", true))
		return
	var base := JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) as Dictionary
	var total := 0
	for f: String in now:
		total += int(now[f])
		var allowed := int(base.get(f, 0))
		if int(now[f]) > allowed:
			fail("%s names the campaign on %d code line(s), %d allowed. Engine code takes ids from data or a campaign module hook (docs/plans/engine_split.md)." % [f, int(now[f]), allowed])
	assert_true(total >= 0)


func test_baseline_only_shrinks() -> void:
	if OS.get_environment("ENGINE_NAMES_WRITE") == "1":
		return
	var now := _scan()
	var base := JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) as Dictionary
	for f: String in base:
		var have := int(now.get(f, 0))
		if have < int(base[f]):
			fail("%s is down to %d name line(s) (baseline %d): lower its entry in %s, or delete it at 0." % [f, have, int(base[f]), BASELINE])


func test_campaign_modules_exist() -> void:
	for f in CAMPAIGN_MODULES:
		assert_true(FileAccess.file_exists(f), "%s is listed as a campaign module but is gone: update CAMPAIGN_MODULES" % f)
