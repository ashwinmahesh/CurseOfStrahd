class_name ExploreGrid
extends Node
## The battle grid while exploring (Natural Maps plan N1): BattleGrid's lines round the party's leader, and over the whole
## map in the tactical view, while the Show the grid key is held, or all the time with the Battle grid setting at Always.
## A fight has its own, gathered round whoever's turn it is (CombatView); this one is quiet while a fight is on.

var view: LocationView
var lines: BattleGrid


static func create(v: LocationView) -> ExploreGrid:
	var g := ExploreGrid.new()
	g.name = "ExploreGrid"
	g.view = v
	return g


func _ready() -> void:
	lines = BattleGrid.create(view.board)
	lines.rig = view.rig
	lines.pad_action = &"explore_grid"   # (the controller's names trigger, held)
	add_child(lines)


func _process(_delta: float) -> void:
	var leader := view.leader() if not view.members.is_empty() else null
	lines.set_active(not view.in_combat)
	lines.set_auto(BattleGrid.auto_exploring())
	if leader != null and view.tokens.has(leader.id):
		var tok := view.tokens[leader.id] as Node3D
		if lines.follow != tok:
			lines.gather(tok)
