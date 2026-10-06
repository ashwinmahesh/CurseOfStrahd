class_name Combatant
extends RefCounted
## One creature in an encounter: its rules state (a Creature), its place on the grid, its side, who controls it
## (the player for every party member and guest; AI only for enemies and neutrals, plan pillar 2) and its
## turn state under the 2024 action economy.

var creature: Creature
var id: String
var side: StringName = &"enemy"        ## party, guest, enemy, neutral
var controller: StringName = &"ai"     ## player or ai
var cell: Vector2i = Vector2i.ZERO
var size_cells: int = 1
var facing: Vector2 = Vector2(0, 1)
var initiative: int = 0
var initiative_test: D20Test = null
var initiative_group: String = ""
var surprised: bool = false
var ai_profile: StringName = &"brute"
## Per-reaction choice the player set: reaction id -> "ask", "auto" or "never" (plan §5.3).
var reaction_rules: Dictionary = {}

# --- Turn state (reset at the start of each of its turns) ---
var movement_left: int = 0
var action_available: bool = true
var bonus_available: bool = true
var reaction_available: bool = true
var free_interaction_available: bool = true
## Attacks left in the current Attack action (Extra Attack), and whether the action was taken this turn.
var attacks_left: int = 0
var took_attack_action: bool = false
var disengaged: bool = false
var cast_slot_spell_this_turn: bool = false
var light_attack_weapon: String = ""     ## the Light weapon used in this turn's Attack action
var nick_used: bool = false
var extra_actions: int = 0               ## Action Surge taken before the action was used
var surged: bool = false
var magic_action_used: bool = false      ## at most one Magic action a turn (Action Surge's can't be Magic)
var haste_action: bool = false           ## Haste's extra action: one weapon attack, Dash, Disengage, Hide or Utilize
var moved: bool = false                  ## moved this turn (Steady Aim)
var turn_start_cell: Vector2i = Vector2i.ZERO  ## where the turn began (a charge's run-up)
var stood_up: bool = false
var hidden: bool = false
var stealth_total: int = 0
var death_save_rolled: bool = false
## Riders the player armed for this turn's next hit (maneuvers, Cunning Strike, Giant Ancestry, Psionic Strike):
## ids, in the order chosen. Cleared at the end of the turn.
var armed: Array[String] = []
## Movement that doesn't provoke Opportunity Attacks, granted by a feature (Tactical Shift, Cunning Strike's
## Withdraw, Remarkable Athlete): feet left, used with Encounter.free_move().
var free_move_ft: int = 0
## A bonus-action attack a feature granted this turn (Great Weapon Master's Hew): the reason, or "".
var bonus_attack: String = ""
## Whether this creature has taken a turn yet in this fight (Assassinate).
var has_acted: bool = false
## A readied attack waiting for its trigger: {option} (lasts until the start of this creature's next turn).
var readied: Dictionary = {}


func _init(creature_: Creature, side_: StringName, cell_: Vector2i) -> void:
	creature = creature_
	id = creature_.id
	side = side_
	cell = cell_
	size_cells = CombatGrid.size_cells_for(creature_.size)
	controller = &"player" if side_ in [&"party", &"guest"] else &"ai"
	var data := (creature_ as Monster).data if creature_ is Monster else {}
	ai_profile = StringName(str(data.get("ai_profile", "brute")))


func name() -> String:
	return creature.name


func is_player_controlled() -> bool:
	return controller == &"player"


func is_alive() -> bool:
	return not creature.dead


## Up and able to act: alive, above 0 HP and not Incapacitated.
func can_act() -> bool:
	return not creature.dead and creature.hp > 0 and not creature.has_flag("no_actions")


func is_down() -> bool:
	return creature.dead or creature.hp <= 0


## Enemies and the party (with guests) are hostile to each other; neutrals are hostile to no one by default.
func hostile_to(other: Combatant) -> bool:
	var a := _team(side)
	var b := _team(other.side)
	return a != b and a != &"neutral" and b != &"neutral"


static func _team(s: StringName) -> StringName:
	return &"party" if s == &"guest" else s


func allied_with(other: Combatant) -> bool:
	return _team(side) == _team(other.side)


func footprint() -> Array[Vector2i]:
	return CombatGrid.footprint(cell, size_cells)


## Speed for moving on the grid: walking, or flying when that's faster (Fly, flying monsters, Gaseous Form).
func speed() -> int:
	return maxi(creature.speed().total(), creature.speed("fly").total())


## Reach for melee attacks and Opportunity Attacks (5 ft, more with Reach weapons or stat-block reach).
func reach_ft() -> int:
	var best := 5
	if creature is Monster:
		for a: Variant in (creature as Monster).data.get("actions", []):
			best = maxi(best, int(((a as Dictionary).get("attack", {}) as Dictionary).get("reach", 5)))
	elif creature is Character:
		var main := (creature as Character).equipped("main_hand")
		if "reach" in Gear.weapon_props(main):
			best = 10
	return best


func reset_turn() -> void:
	movement_left = speed()
	turn_start_cell = cell
	action_available = true
	bonus_available = true
	reaction_available = true
	free_interaction_available = true
	attacks_left = 0
	took_attack_action = false
	disengaged = false
	cast_slot_spell_this_turn = false
	light_attack_weapon = ""
	nick_used = false
	extra_actions = 0
	surged = false
	magic_action_used = false
	haste_action = false
	free_move_ft = 0
	bonus_attack = ""
	moved = false
	stood_up = false
	death_save_rolled = false
	readied = {}


func describe_economy() -> String:
	return "Action %s · Bonus %s · Reaction %s · %d ft" % ["●" if action_available else "○",
		"▲" if bonus_available else "△", "◆" if reaction_available else "◇", movement_left]
