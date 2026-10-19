class_name ExploreGrid
extends Node
## The battle grid while exploring (Natural Maps plan N1): the "Always" choice of the Battle grid setting
## (GameSettings.battle_grid) shows BattleGrid's lines round the party's leader, and over the whole map in the tactical
## view. A fight has its own, gathered round whoever's turn it is (CombatView); by default nothing shows out of one.

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
	add_child(lines)


func _process(_delta: float) -> void:
	var leader := view.leader() if not view.members.is_empty() else null
	var on := BattleGrid.wanted_exploring() and not view.in_combat and leader != null and view.tokens.has(leader.id)
	if on != lines.is_wanted():
		lines.set_wanted(on)
	if on:
		var tok := view.tokens[leader.id] as Node3D
		if lines.follow != tok:
			lines.gather(tok)
