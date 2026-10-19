class_name BentWalls
extends RefCounted
## Test support (natural maps B1, BuildingBend): a piece hung on a bent house follows the house's wall, which stands up to
## a quarter of a square off its grid line and a few degrees off true, so the tests that hold pieces to their square, to
## a right angle and to the wall behind them give a piece beside a bent house that much slack, and no more.


## How far (squares) a piece standing at `at` may be off where the straight grid would put it: a bent wall's reach and the
## hair a piece stands off it, when a bent house is in the square or beside it; else nothing.
static func slack(board: ArenaBoard, at: Vector3) -> float:
	var cell := board.grid.cell_at(at)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var c := cell + Vector2i(dx, dz)
			if board.house_cells.has(c) and (board.buildings[int(board.house_cells[c])] as Dictionary).get("bend") != null:
				return BuildingBend.MAX_OUT + 0.06
	return 0.0


## How far (radians) such a piece may be turned off a right angle to the grid: a wall leans and bows a few degrees.
static func turn(board: ArenaBoard, at: Vector3) -> float:
	return 0.12 if slack(board, at) > 0.0 else 0.0
