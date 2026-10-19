class_name BentWalls
extends RefCounted
## Test support (natural maps B1, BuildingBend): a piece hung on a bent house follows the house's wall, which stands up to
## its style's reach (a quarter of a square, half for timber) off its grid line and a few degrees off true, so the tests
## that hold pieces to their square, to a right angle and to the wall behind them give a piece beside a bent house that
## much slack, and no more.


## The bend of a house in the square at `at` or beside it, or null.
static func _bend_near(board: ArenaBoard, at: Vector3) -> BuildingBend:
	var cell := board.grid.cell_at(at)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var c := cell + Vector2i(dx, dz)
			if board.house_cells.has(c):
				var bend := (board.buildings[int(board.house_cells[c])] as Dictionary).get("bend") as BuildingBend
				if bend != null:
					return bend
	return null


## How far (squares) a piece standing at `at` may be off where the straight grid would put it: a bent wall's reach and the
## hair a piece stands off it, when a bent house is in the square or beside it; else nothing.
static func slack(board: ArenaBoard, at: Vector3) -> float:
	var bend := _bend_near(board, at)
	return 0.0 if bend == null else bend.reach + 0.06


## How far (radians) such a piece may be turned off a right angle to the grid: a wall leans and bows a few degrees, more
## where it may reach further.
static func turn(board: ArenaBoard, at: Vector3) -> float:
	var bend := _bend_near(board, at)
	return 0.0 if bend == null else 0.12 * bend.reach / BuildingBend.MAX_OUT
