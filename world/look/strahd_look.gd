class_name StrahdLook
extends CampaignLook
## Curse of Strahd's scenery for the engine's world code (CampaignLook): Castle Ravenloft's walls and towers (CastleBuilder),
## the Amber Temple's amber (AmberGlow, AmberColossus), the faceless god (FacelessGod) and the study's table model of the castle.


func plan(board: ArenaBoard) -> bool:
	return CastleBuilder.plan(board)


func walk_at(board: ArenaBoard, c: Vector2i) -> bool:
	return CastleBuilder.walk_at(board, c)


func claims(board: ArenaBoard, c: Vector2i) -> bool:
	return CastleBuilder.claims(board, c)


func frames(board: ArenaBoard, c: Vector2i) -> bool:
	return CastleBuilder.frames(board, c)


func cut(b: Dictionary, camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	CastleBuilder.cut(b, camera_pos, focus, delta)


func plinth_steps(board: ArenaBoard, rect: Rect2i) -> void:
	FacelessGod.steps(board, rect)


func dress_god(board: ArenaBoard, root: Node3D, piece: Node3D, cell: Vector2i) -> void:
	FacelessGod.dress(board, root, piece, cell)


func place_special(art: String, board: ArenaBoard, root: Node3D, cell: Vector2i, spec: Dictionary, look: Dictionary) -> Dictionary:
	match art:
		"amber_case":
			# Built in code and lit from inside in the Modern finish; Classic keeps the lying box it was frozen with.
			if Look.modern():
				return {"handled": true, "node": AmberGlow.place(board, root, cell, look)}
			return {"art": str(look.get("classic", "amber_sarcophagus"))}
		"castle_model":
			# The table model of Castle Ravenloft in Exethanter's study, built from the castle kit in the Modern finish.
			if Look.modern():
				return {"handled": true, "node": CastleModel.place(board, root, cell)}
			return {"art": str(look.get("classic", "table"))}
		"sentinel_dais":
			# The low dais the Amber Sentinel stands on, in the Modern finish; Classic keeps the bare snow.
			if Look.modern():
				return {"handled": true, "node": AmberColossus.dais(board, root, cell, spec, str(look.get("case", "")) == "cracked")}
			return {"handled": true, "node": root}
	return {}


func dress_door(art: String, leaf: Node3D, width: float, height: float) -> void:
	if art == "amber_doors" and Look.modern():
		AmberGlow.dress_door(leaf, width, height)   # the honey-glow doors' panes are amber, pulsing, lighting both sides


func dress_place(view: LocationView) -> void:
	AmberGlow.dress_place(view)


func refresh(view: LocationView) -> void:
	AmberGlow.refresh(view)
