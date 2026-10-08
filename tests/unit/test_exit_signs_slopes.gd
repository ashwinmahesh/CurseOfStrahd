extends TestCase
## Exit signs on sloped ground (lane 3; ui/exploration/exit_signs.gd): a way out's square and the chevrons leading to
## it lie flat on the slope's plane under them, so from any angle they project to a shape that draws. With each point
## at its own height, a chevron on rugged ground folds over itself from some angles (the build saw it once, 655bad83).


func _project(cam: Camera3D, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for w: Vector3 in pts:
		out.append(cam.unproject_position(w))
	return out


func test_chevrons_on_rugged_ground_draw_from_every_angle() -> void:
	var rows: Array = []
	for z in 7:
		rows.append(".......")
	# Rugged, twisted ground: steep and cliff steps every way, so a square's top bends across its diagonals.
	var elevation: Array = ["0247420", "2469642", "4692964", "7926297", "4692964", "2469642", "0247420"]
	var b := ArenaBoard.build(CombatGrid.from_rows(rows, elevation), "forest")
	add_child(b)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var folded_before := 0
	var drawn := 0
	for z in range(1, 6):
		for x in range(1, 6):
			var centre := Vector2(x + 0.5, z + 0.5)
			var aim := Vector3(centre.x, b.ground_y(centre), centre.y)
			for yaw_i in 16:
				for pitch: float in [0.3, 0.6, 1.0]:
					var yaw := yaw_i * PI / 8.0 + 0.1
					cam.position = aim + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 12.0
					cam.look_at(aim)
					for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						var pts := ExitSigns.chevron_points(centre, d)
						var flat := _project(cam, ExitSigns.lay_on_ground(b, pts, 0.0))
						if absf(ExitSigns.area(flat)) >= 1.0:
							drawn += 1
							assert_false(Geometry2D.triangulate_polygon(flat).is_empty(),
								"a chevron at %s pointing %s, seen from yaw %d pitch %.2f, draws" % [centre, d, yaw_i, pitch])
						var own: Array = []
						for p: Vector2 in pts:
							own.append(Vector3(p.x, b.ground_y(p) + 0.04, p.y))
						if Geometry2D.triangulate_polygon(_project(cam, own)).is_empty():
							folded_before += 1
	assert_true(drawn > 1000, "chevrons seen from every side (%d)" % drawn)
	assert_true(folded_before > 0, "each point at its own height folds from some angle (%d times)" % folded_before)
	print("  rugged ground: %d chevron views drawn flat; %d folded with each point at its own height" % [drawn, folded_before])
