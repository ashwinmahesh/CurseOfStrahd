extends Node
## Figures the story has lying down (owner, 2026-10-13: "Vasilka lies under a sheet, very still" but stood beside her
## table): each place built as in the game with the story where that figure is shown, the party a few squares off and
## the camera on the figure; for a fight that opens with a foe getting up, a strip of its first second and a half.
## Not part of the game.
##   make capture SCENE=res://tools/capture/lying_capture.tscn NAME=lying/after FRAMES=10
## LYING_SHOTS=vasilka_table,ruxandra picks the shots (default every one).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
## Each shot: the place, the story flags set, where the party stands, the square the camera looks at, and optionally
## the hour, the camera's distance, a brighter light for a dark place (`lit`), every fight there already fought
## (`calm`, so standing there starts none), and a fight to start there (shot as it opens).
const SHOTS := {
	"vasilka_table": {"loc": "abbey_of_st_markovia_wards", "party": [20, 9], "look": [23, 10], "dist": 4.5},
	"vasilka_table_wide": {"loc": "abbey_of_st_markovia_wards", "party": [20, 9], "look": [23, 10]},
	"vasilka_never_woke": {"loc": "abbey_of_st_markovia_wards", "party": [20, 9], "look": [23, 10], "dist": 4.5,
		"flags": {"vasilka_fate": "never_woke", "abbot_fate": "slain"}},
	"vasilka_covered": {"loc": "abbey_of_st_markovia_wards", "party": [20, 9], "look": [23, 10], "dist": 4.5,
		"flags": {"vasilka_fate": "never_woke", "abbot_fate": "slain", "vasilka_face_covered": true}},
	"vasilka_bier_fight": {"loc": "abbey_of_st_markovia_shrine", "party": [13, 8], "look": [16, 3], "dist": 9.0,
		"flags": {"abbot_dress_asked": true, "wedding_dress_delivered": true}, "fight": "bride_defends"},
	"vasilka_at_rest": {"loc": "abbey_of_st_markovia_shrine", "party": [13, 8], "look": [16, 2],
		"flags": {"wedding_dress_delivered": true, "vasilka_fate": "laid_to_rest", "abbot_fate": "repentant"}},
	"vasilka_destroyed": {"loc": "abbey_of_st_markovia_shrine", "party": [13, 8], "look": [16, 3],
		"flags": {"wedding_dress_delivered": true, "bride_defeated": true}},
	"lysaga_stump": {"loc": "berez", "party": [27, 20], "look": [31, 19], "flags": {"lysaga_slain_at_stump": true},
		"calm": true},
	"lysaga_monument": {"loc": "berez", "party": [9, 15], "look": [6, 14], "flags": {"lysaga_slain_at_monument": true},
		"calm": true},
	"lysaga_hut": {"loc": "berez_baba_lysagas_hut", "look": [10, 6], "flags": {"lysaga_slain_in_hut": true}},
	"ruxandra": {"loc": "yester_hill_gulthias_tree", "party": [12, 13], "look": [15, 10], "flags": {"yester_hill_resolved": true}},
	"sarkhaza": {"loc": "ghakis_lair", "party": [22, 11], "look": [22, 7], "dist": 14.0},
	"sarkhaza_fight": {"loc": "ghakis_lair", "party": [22, 11], "look": [22, 7], "dist": 14.0, "fight": "sarkhaza",
		"flags": {"wyrm_met": true}},
	"toma": {"loc": "old_bonegrinder_loft", "party": [11, 9], "look": [15, 7]},
	"lupu": {"loc": "village_of_barovia", "party": [10, 6], "look": [7, 7], "hour": 12},
	"den_guards": {"loc": "werewolf_den_caves", "party": [19, 16], "look": [19, 22], "dist": 10.0, "lit": true},
	"ghouls_fight": {"loc": "death_house_dungeon_1", "party": [11, 11], "look": [8, 14], "dist": 8.0, "lit": true,
		"fight": "passage_ghouls"},
	"guardroom_fight": {"loc": "castle_ravenloft_larders", "party": [19, 9], "look": [20, 17], "dist": 10.0, "lit": true,
		"fight": "larders_guardroom"},
}
## Frames between the shots of a fight's opening strip, and how many.
const EVERY := 3
const STRIP := 20
const THUMB := Vector2i(640, 360)
const COLUMNS := 5

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var wanted := OS.get_environment("LYING_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not wanted.is_empty() and not id in wanted:
			continue
		await _take(tool, out, id, SHOTS[id] as Dictionary)


func _take(tool: Node, out: String, id: String, shot: Dictionary) -> void:
	if view != null:
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)
	GameState.reset()
	var st := GameState.story
	for pid in PARTY:
		var ch := Pregens.build(pid, 5)
		ch.finish_long_rest()
		st.party.append(ch)
	st.minute_of_day = int(shot.get("hour", 12)) * 60
	var flags := shot.get("flags", {}) as Dictionary
	for f: String in flags:
		st.set_flag(f, flags[f])
	var loc := str(shot["loc"])
	if bool(shot.get("calm", false)):
		var fought := st.loc_state(loc)["encounters"] as Dictionary
		for en: Variant in (Compendium.shared().get_entry("locations", loc).get("encounters", []) as Array):
			fought[str((en as Dictionary)["id"])] = true
	var spawn := "default"
	if shot.has("party"):
		var at := Vector2i(int((shot["party"] as Array)[0]), int((shot["party"] as Array)[1]))
		st.location = loc
		st.positions.clear()
		for i in st.party.size():
			st.positions.append(at + [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)][i % 4])
		spawn = ""
	view = LocationView.create(loc, st, Narrator.new(), Dice.roller, spawn)
	view.input_locked = true
	add_child(view)
	if bool(shot.get("lit", false)):
		(view.get("_env") as Environment).ambient_light_energy = 2.2
		var lamp := OmniLight3D.new()
		lamp.light_color = Look.color("bone")
		lamp.omni_range = 14.0
		lamp.light_energy = 2.0
		view.rig.add_child(lamp)
		lamp.position = Vector3(0, 4, 0)
	await tool.call("wait_frames", 20)
	var look := Vector2i(int((shot["look"] as Array)[0]), int((shot["look"] as Array)[1]))
	_aim(look, shot)
	await tool.call("wait_frames", 12)
	tool.call("_shot", "%s_%s.png" % [out, id])
	if not shot.has("fight"):
		return
	# A fight a conversation starts has its speaker step aside first, as the game does (Sarkhaza's map figure).
	FightSeriesCase.step_aside(view, str(shot["fight"]))
	if not view.start_encounter(str(shot["fight"])):
		push_warning("lying_capture: no fight %s at %s" % [shot["fight"], loc])
		return
	var strip: Array[Image] = []
	for i in STRIP:
		await tool.call("wait_frames", 1)
		_aim(look, shot)
		await tool.call("wait_frames", EVERY - 1)
		var img := get_viewport().get_texture().get_image()
		if i in [0, 3, STRIP - 1]:
			img.save_png("%s_%s_fight_%02d.png" % [out, id, i])
		strip.append(img)
	_sheet(strip, "%s_%s_fight_strip.jpg" % [out, id])


## The camera on square `look`, at the shot's distance and turn.
func _aim(look: Vector2i, shot: Dictionary) -> void:
	var rig := view.rig
	rig.follow = null
	rig.zoom_min = 3.0
	rig.distance = float(shot.get("dist", 7.0))
	rig.global_position = view.board.cell_center(look)
	rig.snap_to_target()


func _sheet(shots: Array[Image], path: String) -> void:
	var rows := ceili(float(shots.size()) / COLUMNS)
	var sheet := Image.create(THUMB.x * COLUMNS, THUMB.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var t := shots[i].duplicate() as Image
		t.convert(Image.FORMAT_RGB8)
		t.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % COLUMNS) * THUMB.x, (i / COLUMNS) * THUMB.y))
	sheet.save_jpg(path, 0.85)
	print("capture: ", path)
