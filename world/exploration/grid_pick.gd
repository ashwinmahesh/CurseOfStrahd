class_name GridPick
extends RefCounted
## Which grid square is under the mouse: a ray from the camera through the screen point, tested against each floor
## height from the highest down (a raised dais is picked before the floor behind it).


## With the `board`, natural ground's slopes and raised props' tops are followed (ground_hit).
static func cell_under(camera: Camera3D, grid: CombatGrid, screen: Vector2, board: ArenaBoard = null) -> Vector2i:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	if board != null and board.shaped():
		var hit: Variant = ground_hit(board, origin, dir)
		return Vector2i(floori((hit as Vector3).x), floori((hit as Vector3).z)) if hit != null else Vector2i(-1, -1)
	for h: int in [4, 3, 2, 1, 0]:
		var t := (float(h) - origin.y) / dir.y
		if t < 0.0:
			continue
		var p := origin + dir * t
		var cell := Vector2i(floori(p.x), floori(p.z))
		if not grid.in_bounds(cell):
			continue
		if grid.height(cell) / CombatGrid.FEET == h or h == 0:
			return cell
	return Vector2i(-1, -1)


## Where a ray first meets the ground on the map (natural slopes, raised floors and their sides; walls are passed
## through to the ground under them), or null: marched down from just above the highest ground in steps of a tenth of
## a square, then narrowed down.
static func ground_hit(board: ArenaBoard, origin: Vector3, dir: Vector3) -> Variant:
	if dir.y > -0.0001:
		return null
	var top := float(board.grid.highest_ground()) / CombatGrid.FEET + 0.5
	var t := maxf(0.0, (top - origin.y) / dir.y)
	var end := (-0.5 - origin.y) / dir.y
	var dt := 0.1 / maxf(Vector2(dir.x, dir.z).length(), -dir.y)
	var last := t
	while t <= end:
		var p := origin + dir * t
		if board.grid.in_bounds(Vector2i(floori(p.x), floori(p.z))) and p.y <= board.ground_y(Vector2(p.x, p.z)):
			var lo := last
			var hi := t
			for i in 8:
				var mid := (lo + hi) / 2.0
				var q := origin + dir * mid
				var inside := board.grid.in_bounds(Vector2i(floori(q.x), floori(q.z)))
				if inside and q.y <= board.ground_y(Vector2(q.x, q.z)):
					hi = mid
				else:
					lo = mid
			return origin + dir * hi
		last = t
		t += dt
	return null
