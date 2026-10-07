extends TestCase
## The party's continuous walk outside fights (PartyGlide): eased start and stop, a steady pace, rounded corners,
## arriving exactly on the last square, followers setting off a beat late.

const DT := 1.0 / 60.0


func _glide(points: Array[Vector3], step_time: float = 0.18) -> PartyGlide:
	var tok := CombatToken.new()
	var g := PartyGlide.new(tok)
	g.step_time = step_time
	g.points = points
	return g


## Runs the glide to the end; returns [seconds taken, top speed, farthest from the path's corner (when given)].
func _run(g: PartyGlide, corner: Vector3 = Vector3.INF) -> Array:
	var t := 0.0
	var top := 0.0
	var near := INF
	var last := g.token.position
	while not g.update(DT) and t < 10.0:
		t += DT
		top = maxf(top, (g.token.position - last).length() / DT)
		last = g.token.position
		if corner != Vector3.INF:
			near = minf(near, (g.token.position - corner).length())
	return [t, top, near]


func test_eases_in_keeps_pace_and_stops_on_the_square() -> void:
	var g := _glide([Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(4, 0, 0)])
	var first := g.token.position
	g.update(DT)
	var opening := (g.token.position - first).length() / DT
	var r := _run(g)
	assert_true(g.token.position.is_equal_approx(Vector3(4, 0, 0)), "ends exactly on the last square")
	assert_true(opening < 0.5 / 0.18, "sets off gently (%.2f)" % opening)
	assert_between(float(r[1]), 0.9 / 0.18, 1.1 / 0.18, "full pace is a square a step")
	assert_between(float(r[0]), 4 * 0.18, 4 * 0.18 + 0.4, "about four steps' time, plus easing in and out")
	g.token.free()


func test_rounds_corners_without_leaving_the_way() -> void:
	var g := _glide([Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 1), Vector3(2, 0, 2)])
	var r := _run(g, Vector3(2, 0, 0))
	assert_true(g.token.position.is_equal_approx(Vector3(2, 0, 2)), "arrives")
	assert_between(float(r[2]), 0.02, 0.45, "cuts the corner a little, not a lot (%.2f)" % float(r[2]))
	g.token.free()


func test_diagonal_steps_keep_the_same_pace() -> void:
	var g := _glide([Vector3(1, 0, 1), Vector3(2, 0, 2), Vector3(3, 0, 3), Vector3(4, 0, 4)])
	var r := _run(g)
	assert_between(float(r[1]), 0.9 / 0.18, 1.1 / 0.18, "the same speed on diagonals")
	g.token.free()


func test_a_follower_waits_its_turn() -> void:
	var g := _glide([Vector3(1, 0, 0)])
	g.wait = PartyGlide.FOLLOW_DELAY * 2
	g.update(DT)
	assert_true(g.token.position.is_equal_approx(Vector3.ZERO), "still waiting")
	var r := _run(g)
	assert_true(g.token.position.is_equal_approx(Vector3(1, 0, 0)), "then walks")
	assert_true(float(r[0]) > 0.0)
	g.token.free()


func test_turning_passes_through_the_directions_between() -> void:
	var h := PartyGlide._turn(Vector3(1, 0, 0), Vector3(-1, 0, 0), 0.3)
	assert_between(h.length(), 0.99, 1.01, "stays a unit heading")
	assert_true(h.x > 0.9, "a small step round, not a snap")


func test_a_follower_behind_closes_the_gap() -> void:
	var lead := _glide([Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)])
	var behind := _glide([Vector3(1, 0, 0), Vector3(2, 0, 0), Vector3(3, 0, 0)])
	behind.catch_up = 1.4
	var a := _run(lead)
	var b := _run(behind)
	assert_true(float(b[1]) > float(a[1]) * 1.15, "a follower with ground to make up walks faster")
	assert_true(behind.token.position.is_equal_approx(Vector3(3, 0, 0)), "and still stops on its square")
	lead.token.free()
	behind.token.free()
