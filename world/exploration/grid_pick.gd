class_name GridPick
extends RefCounted
## Which grid square is under the mouse: a ray from the camera through the screen point, tested against each floor
## height from the highest down (a raised dais is picked before the floor behind it).


static func cell_under(camera: Camera3D, grid: CombatGrid, screen: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
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
