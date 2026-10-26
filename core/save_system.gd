extends Node
## Writes GameState to one JSON file per slot. Saves are allowed anywhere outside combat
## (plan §10 Phase 3); the mode check lives here so every caller gets it.
## Beside each save (Q9, docs/ui/saves.md): a thumbnail of the game as it was (<slot>.webp), and the player's own note
## on it (the save's "note").
## Loading a game saved a while ago opens with the Narrator's recap (Q3, ui/exploration/recap.gd). An Honour run keeps one
## save (F1's one-save rule, below).

var save_dir := "user://saves/"
## The game's own save slot: the one it was last loaded from or saved to. Quicksave (F5) writes here; a new game
## starts with none, and its first quicksave makes one.
var current_slot := ""
## The slot the campaign's ending was last written to (save_finished), "" until one is: a slot of its own, never the
## game's (the ending screen says where its save went).
var finished_slot := ""
## The game's safety net (docs/plans/ui_polish.md): written on arriving somewhere new, after a rest and after a won
## fight, never during one. Like the round-start save it is never the game's own slot: it remembers that slot, and
## loading it goes back to it, so F5 still saves where it did. The newest is AUTOSAVE; the AUTOSAVES - 1 before it
## are autosave_2, autosave_3 ... (Q9), each moved one along by the next autosave.
const AUTOSAVE := "autosave"
const AUTOSAVES := 5
const ROUND_START := "round_start"
## Thumbnails (Q9): the middle 16:9 of the screen at this size, as WebP.
const THUMB := Vector2i(320, 180)
## The autosave on arriving somewhere is written before the place is on screen: its picture waits this long.
const THUMB_DELAY := 0.8
## "Previously in Barovia" (Q3): a game saved at least this many minutes ago opens with the Narrator's recap.
const RECAP_AFTER := 30.0
## Names the game spells differently now (owner, 2026-10-12: the Wizard is "Ratatouille"). A save an older build wrote
## has the old spelling in every string that shows the name (his build, the run's stats, a fight's log), and upgrade
## respells them all whatever the save's version. Ids are lowercase (ratatoille) and stay, and so does the player's
## note. tools/data/respell.py made the same change across the game's own text.
const RESPELLED := {"Ratatoille": "Ratatouille"}   # respell: keep

## The world as the pause menu opened over it (hold_view), for the thumbnail of a save made from its pages.
var _held: Image = null
var _held_by: WeakRef = null
## The game just loaded was saved a while ago: the story game shows the recap when it arrives (take_recap).
var _recap_due := false


func _ready() -> void:
	get_tree().scene_changed.connect(func() -> void:
		var scene := get_tree().current_scene
		if _recap_due and scene != null:
			(func() -> void: Recap.show_on(scene)).call_deferred())


func can_save() -> bool:
	return ModeController.mode != ModeController.Mode.COMBAT


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func thumb_path(slot: String, dir: String = "") -> String:
	return (save_dir if dir == "" else dir).path_join(slot + ".webp")


## `note`: the player's own note on this save; null keeps the one the slot had.
func save(slot: String, note: Variant = null) -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	return _save(slot, note, false)


## Writes the game to `slot`, the game's own from now on; its picture now, or (`later`) once the place is showing.
func _save(slot: String, note: Variant, later: bool, picture: bool = true) -> Error:
	var data := GameState.to_dict()
	var keep := str(note) if note != null else str(_read(slot_path(slot)).get("note", ""))
	if keep != "":
		data["note"] = keep
	var err := _write(slot, data)
	if err != OK:
		return err
	if not picture:
		pass
	elif later:
		_thumb_later(slot)
	else:
		_write_thumb(slot, _view())
	current_slot = slot
	EventBus.game_saved.emit(slot)
	return OK


## Quicksave (F5, the pause menu): over the game's current slot, or a new slot the first time.
func quick_save() -> Error:
	return save(current_slot if current_slot != "" else new_slot_name())


## A slot name no save has yet, from the time: save_<date>T<time>, with _2, _3 after it for a second save that second.
func new_slot_name() -> String:
	var base := "save_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	var slot := base
	var n := 2
	while has_slot(slot):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


## The fight's round-start save (plan §10 Phase 3): allowed in combat, written only by the game at the start of
## a round, when GameState.combat_snapshot holds the fight. It has no thumbnail (a picture every round would cost a
## frame each round).
func save_round(slot: String = ROUND_START) -> Error:
	if honour():
		# One save, kept at the start of each round (Ashwin, 2026-10-09, QA D-3): leaving a fight comes back to the round
		# it was in, never further back. A picture only as the fight starts.
		return _save(honour_slot(), null, true, int((GameState.combat_snapshot.get("data", {}) as Dictionary).get("round", 1)) <= 1)
	return _write_beside(slot)


## The autosave (AUTOSAVE): anywhere a save is allowed, without making it the game's slot. The ones before it move one
## along (autosave_2 ...), and the oldest goes.
func autosave() -> Error:
	if not can_save():
		return ERR_UNAVAILABLE
	if honour():
		return _save(honour_slot(), null, true)
	delete_slot(autosave_slot(AUTOSAVES))
	for n in range(AUTOSAVES - 1, 0, -1):
		_move(autosave_slot(n), autosave_slot(n + 1))
	var err := _write_beside(AUTOSAVE)
	if err == OK:
		_thumb_later(AUTOSAVE)
	return err


## The n-th newest autosave's slot (1 is AUTOSAVE).
static func autosave_slot(n: int) -> String:
	return AUTOSAVE if n <= 1 else "%s_%d" % [AUTOSAVE, n]


static func is_autosave(slot: String) -> bool:
	return slot == AUTOSAVE or (slot.begins_with(AUTOSAVE + "_") and slot.trim_prefix(AUTOSAVE + "_").is_valid_int())


## A save the game writes beside the player's (an autosave, the round start): never the game's own slot.
static func is_beside(slot: String) -> bool:
	return slot == ROUND_START or is_autosave(slot)


## A save that isn't the game's own slot (the round start, the autosave): it notes the game's slot as `home_slot`.
func _write_beside(slot: String) -> Error:
	var data := GameState.to_dict()
	data["home_slot"] = current_slot
	return _write(slot, data)


func _write(slot: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


## The campaign's end (ADR 0014): the game as it ends is written to a slot of its own, marked finished with the ending
## reached, and every save the player made stays as it was (Ashwin, 2026-10-24: reaching an ending had written over his
## own save, and the game before it was gone). The game's own slot is neither written nor changed, so Continue still
## loads it; the finished save carries its note, so the two read as one run. Finished saves list last and show the ending
## instead of the place. An Honour run is the one exception: its one save is the run, and its ending seals it.
func save_finished(ending_id: String, title: String) -> Error:
	var sealed := honour()
	var slot := honour_slot() if sealed else new_slot_name()
	var data := GameState.to_dict()
	data["finished"] = {"ending": ending_id, "title": title}
	var own := slot if sealed else current_slot
	var note := str(_read(slot_path(own)).get("note", "")) if own != "" and not is_beside(own) else ""
	if note != "":
		data["note"] = note
	var err := _write(slot, data)
	if err != OK:
		return err
	finished_slot = slot
	if sealed:
		current_slot = slot
	EventBus.game_saved.emit(slot)
	return OK


func load_slot(slot: String) -> Error:
	return load_from(save_dir, slot)


## Loads the save `slot` in `dir`. One in the saves folder becomes the game's own slot (or, for the autosave and the
## round start, goes back to the one they were written for, so a quicksave after loading one still goes to the
## game's own). One from anywhere else (a backup) is a game without a slot until its first save.
func load_from(dir: String, slot: String) -> Error:
	var path := dir.path_join(slot + ".json")
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return ERR_PARSE_ERROR
	var dict := data as Dictionary
	if int(dict.get("version", 0)) > GameState.SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	dict = upgrade(dict)
	# The Unlimited attunement option is the player's (settings.cfg, never the save): the rules library follows it
	# before the party is built, even when nothing has read the settings yet this run.
	MagicItems.attunement_off = GameSettings.unlimited_attunement()
	GameState.from_dict(dict)
	# A fight's round start is a retry, not a return: no recap.
	_recap_due = slot != ROUND_START and minutes_since(str(dict.get("saved_at", ""))) >= RECAP_AFTER
	if dir.simplify_path() != save_dir.simplify_path():
		current_slot = ""
	elif is_beside(slot):
		current_slot = str(dict.get("home_slot", current_slot))
	else:
		current_slot = slot
	EventBus.game_loaded.emit(slot)
	return OK


## Saves from older builds (P4). A change to what a save holds bumps GameState.SAVE_VERSION and adds a step here that
## takes a save of the version before it to the new one, so an old save is mended in one place before GameState reads
## it. Every save in tests/saves (made by older builds) goes through this in every test run
## (tests/integration/test_golden_saves.gd), so a missing or wrong step fails there first. Version 1 was Phase 0's;
## 2 has been the format since Phase 3. Mends that apply to every save whatever its version (a pregen's current look,
## the Dursts' book) stay in StoryState.from_dict; a name spelled differently now (RESPELLED) is mended here, so the
## saves lists show it too. What only the saves lists read (the player's "note", a finished
## game's "finished", a beside save's "home_slot") is no part of the game and needs no step: a save without one has none.
## A field added with a default needs no version either (the bestiary, the run's record, XP levelling's `story.xp`,
## `story.xp_reserve` and `story.options.levelling`): StoryState.from_dict reads what's there, and pin_levelling names the
## older saves' milestone levelling.
static func upgrade(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	swap_withdrawn_items(out)
	swap_regifted_items(out)
	top_up_charges(out)
	pin_levelling(out)
	var v := int(out.get("version", 1))
	while v < GameState.SAVE_VERSION:
		match v:
			1:
				pass   # Phase 0 saves held no story: the game starts them on the mists road as a new game does
		v += 1
		out["version"] = v
	for k: Variant in out.keys():
		if k != "note":
			out[k] = _respelled(out[k])
	return out


## A save that never picked how heroes grow (every save before XP levelling) levels by milestones, as it always did
## (story/xp.gd). Runs on every save whatever its version, as the other mends do, so no SAVE_VERSION step is needed.
static func pin_levelling(save: Dictionary) -> void:
	var story: Variant = save.get("story")
	if not story is Dictionary:
		return   # Phase 0's saves held no story
	var options: Variant = (story as Dictionary).get("options")
	if not options is Dictionary:
		options = {}
		(story as Dictionary)["options"] = options
	if not (options as Dictionary).has(Xp.OPTION):
		(options as Dictionary)[Xp.OPTION] = Xp.MILESTONE


## `v` with each old spelling in RESPELLED replaced, a dictionary or array in place (upgrade's own copy).
static func _respelled(v: Variant) -> Variant:
	if v is String:
		var s := v as String
		for old: String in RESPELLED:
			s = s.replace(old, str(RESPELLED[old]))
		return s
	if v is Dictionary:
		var d := v as Dictionary
		for k: Variant in d.keys():
			d[k] = _respelled(d[k])
	elif v is Array:
		var a := v as Array
		for i in a.size():
			a[i] = _respelled(a[i])
	return v


## Whether a recap is due (Q3), once: the first call after such a load says so, and the next says no.
func take_recap() -> bool:
	var due := _recap_due
	_recap_due = false
	return due


## Real minutes since a save's `saved_at` (the computer's clock, as saves write it); a save without one is long ago.
static func minutes_since(saved_at: String) -> float:
	if saved_at == "":
		return INF
	var now := Time.get_unix_time_from_datetime_string(Time.get_datetime_string_from_system())
	return float(now - Time.get_unix_time_from_datetime_string(saved_at)) / 60.0


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Every save in `dir` (the saves folder, or a backup's), newest first (finished games last), as describe() gives them.
func list_slots(dir: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var from := save_dir if dir == "" else dir
	for f in _files(from):
		if not f.ends_with(".json"):
			continue
		var s := describe(f.get_basename(), from)
		if not s.is_empty():
			out.append(s)
	# Unfinished games first (Continue picks the newest of them), finished ones after, and saves a newer build wrote
	# (which this one can't load) last of all, so Continue never lands on one and does nothing (QA FN-16).
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["newer"]) != bool(b["newer"]):
			return not bool(a["newer"])
		if (str(a["finished"]) == "") != (str(b["finished"]) == ""):
			return str(a["finished"]) == ""
		return str(a["saved_at"]) > str(b["saved_at"]))
	return out


## What a save says about itself for the lists, or {} when `slot` isn't a save: {slot, dir, saved_at, location (its
## name), location_id, level (the party's highest), day, party, finished: the ending's title or "", kind: "autosave", "round" (a fight's round start) or "" for a save
## the player made, note: the player's own, thumb: its picture's path or "", mode: the difficulty's name, "" for
## Balanced, newer: written by a newer build, so this one can't load it}. Other files kept beside the saves (achievements.json, N8) aren't saves: every save says its version.
func describe(slot: String, dir: String = "") -> Dictionary:
	var from := save_dir if dir == "" else dir
	var raw := _read(from.path_join(slot + ".json"))
	if not raw.has("version"):
		return {}
	var d := upgrade(raw)
	var story := d.get("story", {}) as Dictionary
	var names: Array[String] = []
	var level := 0
	for m: Variant in story.get("party", []):
		var build := (m as Dictionary).get("build", {}) as Dictionary
		names.append(str(build.get("name", "?")))
		level = maxi(level, (build.get("levels", []) as Array).size())
	var loc := Compendium.shared().get_entry("locations", str(story.get("location", "")))
	var ended := str((d.get("finished", {}) as Dictionary).get("title", ""))
	var place := str(loc.get("name", story.get("location", ""))) if ended == "" else "The End: %s" % ended
	var thumb := thumb_path(slot, from)
	var mode := str((story.get("options", {}) as Dictionary).get("difficulty", Difficulty.DEFAULT))
	return {"slot": slot, "dir": from, "saved_at": str(d.get("saved_at", "")), "location": place,
		"location_id": str(story.get("location", "")), "level": level,
		"day": int(story.get("day", 1)), "party": ", ".join(names), "finished": ended,
		"kind": "autosave" if is_autosave(slot) else ("round" if slot == ROUND_START else ""),
		"note": str(d.get("note", "")), "thumb": thumb if FileAccess.file_exists(thumb) else "",
		"mode": Difficulty.named(mode).name if mode != Difficulty.DEFAULT else "",
		"newer": int(raw.get("version", 0)) > GameState.SAVE_VERSION}


## A save file as a dictionary ({} when it's missing or not JSON).
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data as Dictionary if data is Dictionary else {}


## The player deletes a save (the saves page): it and its picture go, and the game's own slot with it, so the next save
## makes a new one. False if there was no such save.
func delete_save(slot: String) -> bool:
	if not has_slot(slot):
		return false
	delete_slot(slot)
	if slot == current_slot:
		current_slot = ""
	return true


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if FileAccess.file_exists(thumb_path(slot)):
		DirAccess.remove_absolute(thumb_path(slot))


## Moves a save (and its picture) to another slot's name, over whatever was there.
func _move(from: String, to: String) -> void:
	if not has_slot(from):
		return
	delete_slot(to)
	DirAccess.rename_absolute(slot_path(from), slot_path(to))
	if FileAccess.file_exists(thumb_path(from)):
		DirAccess.rename_absolute(thumb_path(from), thumb_path(to))


# --- Honour's one save (F1) -----------------------------------------------------------------------

## Whether this playthrough is an Honour run (combat/difficulty.gd's one_save): it keeps one save, its own slot, which
## the game keeps up to date. The autosaves and the start of each fight write to it instead of saves beside it (so a
## fight left mid-way comes back to its start, never past it), and Save Game and F5 write over it. Saves of other games
## load as ever.
func honour() -> bool:
	return Difficulty.of_options(GameState.story.options).one_save


## The Honour run's one slot: the game's own, made the first time the game saves.
func honour_slot() -> String:
	if current_slot == "" or is_beside(current_slot):
		current_slot = new_slot_name()
	return current_slot


## A wipe ends an Honour run (lane 22's pick, docs/plans/difficulty.md): the game and its save carry on in Tactician,
## for good. Called as the party falls, before anything else can load or save.
func end_honour() -> void:
	GameState.story.options["difficulty"] = "tactician"
	if current_slot == "" or not has_slot(current_slot):
		return
	var data := _read(slot_path(current_slot))
	var story := data.get("story", {}) as Dictionary
	var options := story.get("options", {}) as Dictionary
	options["difficulty"] = "tactician"
	story["options"] = options
	data["story"] = story
	_write(current_slot, data)


# --- Chapters (Q12) -------------------------------------------------------------------------------

## Jump-in saves (Q12): the start of each chapter, the party at that chapter's level and gear. They are the golden
## saves P4 keeps (tests/saves, made by the auto-player the playthrough tests use, so the same saves the tests load);
## each chapter's newest save version is offered. Loaded, a chapter is a game with no slot of its own, like a backup.
const CHAPTERS_DIR := "res://tests/saves/"
## Story order, from data/progression/chapters.json: {id, title, place} (the travel map's place the chapter starts at). A
## chapter without a save isn't offered.
const CHAPTERS_FILE := "res://data/progression/chapters.json"


## The chapters there are saves for, in story order, as describe() gives them, with {chapter, title, number, place}.
func chapters() -> Array[Dictionary]:
	var newest := {}   ## chapter -> [save version, file name without .json]
	for f in _files(CHAPTERS_DIR):
		if not (f.begins_with("v") and f.ends_with(".json")):
			continue
		var stem := f.get_basename()
		var version := stem.get_slice("_", 0).trim_prefix("v")
		if not version.is_valid_int() or int(version) > GameState.SAVE_VERSION:
			continue
		var chapter := stem.substr(stem.find("_") + 1)
		if not newest.has(chapter) or int((newest[chapter] as Array)[0]) < int(version):
			newest[chapter] = [int(version), stem]
	var out: Array[Dictionary] = []
	var listed := (JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS_FILE)) as Dictionary)["chapters"] as Array
	for i in listed.size():
		var c := listed[i] as Dictionary
		var id := str(c["id"])
		if not newest.has(id):
			continue
		var s := describe(str((newest[id] as Array)[1]), CHAPTERS_DIR)
		if s.is_empty():
			continue
		s["chapter"] = id
		s["title"] = str(c["title"])
		s["number"] = i + 1
		s["place"] = str(c["place"])
		out.append(s)
	return out


## Begins a chapter (Q12): its save, with the party it was made with (the tests' party) swapped for the roster's
## heroes at the chapter's level. The first four of the roster travel, as the title's New game picks them, and the
## rest wait at camp; the magic items the chapter's party had found go to the new travellers' packs, one member's to
## one member, and their coin to the party's purse. Like a backup, the game has no slot until its first save.
func begin_chapter(c: Dictionary) -> Error:
	var err := load_from(str(c["dir"]), str(c["slot"]))
	if err != OK:
		return err
	var st := GameState.story
	var old: Array[Character] = st.party.duplicate()
	old.append_array(st.bench)
	st.party.clear()
	st.bench.clear()
	for id in Pregens.roster_ids():
		var ch := Pregens.build(id, maxi(1, int(c.get("level", 1))))
		if ch == null:
			continue
		ch.finish_long_rest()
		if st.party.size() < StoryState.PARTY_CAP:
			st.party.append(ch)
		else:
			st.bench.append(ch)
	st.leader = 0
	if st.party.is_empty():
		return OK
	const COIN := {"cp": 0.01, "sp": 0.1, "ep": 0.5, "gp": 1.0, "pp": 10.0}
	for i in old.size():
		var to := st.party[i % st.party.size()]
		for e: Dictionary in old[i].inventory:
			if MagicItems.is_magic(Compendium.shared().item_data(str(e["id"]))):
				to.add_item(str(e["id"]), int(e["qty"]), Character.entry_state(e))
		for coin: String in old[i].currency:
			st.gold += float(old[i].currency[coin]) * float(COIN.get(coin, 0.0))
	return OK


## Who travels when a chapter begins (begin_chapter): the first four of the roster, by name.
static func chapter_party() -> Array[String]:
	var out: Array[String] = []
	for id: String in Pregens.roster_ids().slice(0, StoryState.PARTY_CAP):
		out.append(str(Compendium.shared().get_entry("pregens", id).get("name", id)))
	return out


# --- Thumbnails -----------------------------------------------------------------------------------

## The pause menu holds the frame it opens over, so a save made from its pages shows the world, not the menu. The
## picture is good while `by` (the menu) is open; outside a fight only, since nothing can be saved in one.
func hold_view(by: Node) -> void:
	_held = _grab() if can_save() else null
	_held_by = weakref(by)


## The picture for a save made now: the held one while its menu is open, else the screen as it is.
func _view() -> Image:
	var by := _held_by.get_ref() as Node if _held_by != null else null
	if _held != null and by != null and by.is_inside_tree():
		return _held
	_held = null
	return _grab()


## The screen's last frame as a thumbnail, or null (no screen: headless runs and tests).
func _grab() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex != null else null
	return thumbnail_of(img) if img != null and not img.is_empty() else null


## The middle 16:9 of `img`, at THUMB.
static func thumbnail_of(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cw := mini(w, roundi(h * 16.0 / 9.0))
	var ch := mini(h, roundi(w * 9.0 / 16.0))
	var out := img.get_region(Rect2i(int((w - cw) / 2.0), int((h - ch) / 2.0), cw, ch))
	out.convert(Image.FORMAT_RGB8)
	out.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	return out


func _write_thumb(slot: String, img: Image) -> void:
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	img.save_webp(thumb_path(slot), true, 0.8)


## A save written as the game arrives somewhere has its picture taken once the place is showing, if it's still the
## same save then.
func _thumb_later(slot: String) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var at := str(_read(slot_path(slot)).get("saved_at", ""))
	get_tree().create_timer(THUMB_DELAY).timeout.connect(func() -> void:
		if has_slot(slot) and str(_read(slot_path(slot)).get("saved_at", "")) == at:
			_write_thumb(slot, _grab()))


## The files in `dir`, none if it doesn't exist (a new player has no saves folder yet).
static func _files(dir: String) -> PackedStringArray:
	return DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()


# --- Items taken out of the game --------------------------------------------------------------------------------

## Magic items taken out of the game (hidden, playable false) -> what a save's copies become, in turn: useful items of
## the same rarity (and the same price by the 2024 DMG's table; Sane Magical Prices prices each its own way since
## 2026-10-14). The Amulet of Proof against Detection and Location did nothing here and turned up far
## too often (owner, 2026-10-12); the four items that cast Detect Thoughts left with the spell (Ashwin, 2026-10-13); the
## Rings of Mind Shielding and Water Walking did nothing here either (magic item audit, 2026-10-17).
## Each one a save holds, carried, stashed or waiting in a chest, becomes the next one on its list.
const WITHDRAWN := {"amulet_of_proof_against_detection_and_location":
	["periapt_of_wound_closure", "cloak_of_protection", "stone_of_good_luck"],
	"helm_of_telepathy": ["circlet_of_blasting", "headband_of_intellect"],
	"medallion_of_thoughts": ["eyes_of_minute_seeing", "brooch_of_shielding"],
	"potion_of_mind_reading": ["potion_of_healing_superior", "potion_of_heroism"],
	"crystal_ball_of_mind_reading": ["crystal_ball_of_true_seeing", "crystal_ball_of_telepathy"],
	# Rings that did nothing in the game (magic item audit, 2026-10-17).
	"ring_of_mind_shielding": ["ring_of_warmth", "ring_of_jumping"],
	"ring_of_water_walking": ["ring_of_warmth", "ring_of_jumping"]}
## What an item entry holds of its own (MagicItems.init_state's charges and the like): the old item's goes with it, so
## its replacement starts fresh when it's next picked up.
const ITEM_STATE := ["charges", "max_charges", "gems", "beads", "patches", "stored", "artifact_properties", "made"]


## Swaps every withdrawn item in `save` (in place) for its replacements, whatever the save's version: an item entry
## takes the new id, off its slot and without the old item's charges, a replacement that stacks (a potion) joins a
## stack of its kind in the same list, and an attunement to the old one ends. A save without one is unchanged.
static func swap_withdrawn_items(save: Dictionary) -> void:
	_swap_in(save, {})


static func _swap_in(v: Variant, seen: Dictionary) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		var old := str(d.get("id", ""))
		if WITHDRAWN.has(old):
			var subs := WITHDRAWN[old] as Array
			var n := int(seen.get(old, 0))
			seen[old] = n + 1
			d["id"] = str(subs[n % subs.size()])
			if d.has("slot"):
				d["slot"] = ""
			for k: String in ITEM_STATE:
				d.erase(k)
		if d.get("attuned", null) is Array:
			d["attuned"] = (d["attuned"] as Array).filter(func(a: Variant) -> bool: return not WITHDRAWN.has(str(a)))
		for k: Variant in d.keys():
			_swap_in(d[k], seen)
	elif v is Array:
		var a := v as Array
		var swapped: Array[int] = []
		for i in a.size():
			if a[i] is Dictionary and WITHDRAWN.has(str((a[i] as Dictionary).get("id", ""))):
				swapped.append(i)
			_swap_in(a[i], seen)
		for k in range(swapped.size() - 1, -1, -1):
			_join_stack(a, swapped[k])


## A replacement at `i` in `a` that stacks joins another entry of its kind there: the earlier of the two keeps both.
static func _join_stack(a: Array, i: int) -> void:
	var d := a[i] as Dictionary
	if not d.has("qty") or not bool(Compendium.shared().item_data(str(d["id"])).get("stackable", false)):
		return
	for j in a.size():
		if j != i and a[j] is Dictionary and str((a[j] as Dictionary).get("id", "")) == str(d["id"]) and (a[j] as Dictionary).has("qty"):
			var keep := a[mini(i, j)] as Dictionary
			var drop := a[maxi(i, j)] as Dictionary
			keep["qty"] = int(keep["qty"]) + int(drop["qty"])
			if bool(drop.get("new", false)):
				keep["new"] = true
			a.remove_at(maxi(i, j))
			return


# --- Gifts and items that changed -----------------------------------------------------------------------------------

## Story gifts that became other items after saves already held them. In a save whose `given` flag is set but not its
## `mark` (the scene sets it now as it hands the new item over), the first copy of `old` the party carries, or else has
## stashed, becomes `new`; then `mark` is set, so it happens once and a copy found later stays as it is. Mother's eighth
## gift was Boots of Levitation and is Winged Boots now (owner, 2026-10-13).
const REGIFTED := [{"given": "mother_flown", "old": "boots_of_levitation", "new": "winged_boots", "mark": "mother_boots_given"}]

## Items that gained charges after saves already held them: a copy made before then has none, so it gets the item's
## starting count. Winged Boots moved to the 2024 rules' 4 charges (2026-10-13).
const CHARGED_LATER := ["winged_boots"]


## Swaps each changed gift in `save` (in place) for the new item, once per save (REGIFTED). The new item keeps the old
## one's place: its slot and its attunement.
static func swap_regifted_items(save: Dictionary) -> void:
	var story := save.get("story", {}) as Dictionary
	var flags := story.get("flags", {}) as Dictionary
	for g: Dictionary in REGIFTED:
		if bool(flags.get(str(g["given"]), false)) and not bool(flags.get(str(g["mark"]), false)):
			_regift(story, str(g["old"]), str(g["new"]))
			flags[str(g["mark"])] = true


static func _regift(story: Dictionary, old: String, new: String) -> void:
	var holders: Array = []
	holders.append_array(story.get("party", []) as Array)
	holders.append_array(story.get("bench", []) as Array)
	for h: Variant in holders:
		var ch := h as Dictionary
		for e: Variant in ch.get("inventory", []):
			if str((e as Dictionary).get("id", "")) == old:
				_become(e as Dictionary, new)
				if ch.get("attuned", null) is Array:
					ch["attuned"] = (ch["attuned"] as Array).map(func(a: Variant) -> String: return new if str(a) == old else str(a))
				return
	for e: Variant in story.get("stash", []):
		if str((e as Dictionary).get("id", "")) == old:
			_become(e as Dictionary, new)
			return


## An item entry turned into `id`: the old item's spent uses go, the new one's charges come, and it shows as new.
static func _become(entry: Dictionary, id: String) -> void:
	entry["id"] = id
	for k: String in ["uses", "budget_used", "cooldowns", "charges", "max_charges"]:
		entry.erase(k)
	_charge(entry)
	entry["new"] = true


## Gives every made copy of a CHARGED_LATER item in `save` (in place) that has no charges its starting count.
static func top_up_charges(save: Dictionary) -> void:
	_top_up_in(save)


static func _top_up_in(v: Variant) -> void:
	if v is Dictionary:
		var d := v as Dictionary
		if str(d.get("id", "")) in CHARGED_LATER and d.has("made") and not d.has("charges"):
			_charge(d)
		for k: Variant in d.keys():
			_top_up_in(d[k])
	elif v is Array:
		for x: Variant in v as Array:
			_top_up_in(x)


## An item entry's starting charges, if its item has any (MagicItems.init_state).
static func _charge(entry: Dictionary) -> void:
	var data := Compendium.shared().item_data(str(entry["id"]))
	if not MagicItems.has_charges(data):
		return
	var fresh := MagicItems.init_state(data, DiceRoller.new(hash(str(entry["id"]))))
	for k: String in ["charges", "max_charges"]:
		if fresh.has(k):
			entry[k] = fresh[k]
