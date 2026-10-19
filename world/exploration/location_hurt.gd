class_name LocationHurt
extends Node
## A party member hurt outside a fight (owner todo 2026-10-17): a trap going off (LocationTraps), a pit's fall (PitFall) or
## a climb, swim or ritual that failed and hurt (LocationChecks). Once the big d20 for it has been seen, and no cutscene or
## screen holds the game, the figure flashes and flinches, the trap's own effect plays on it (TrapFx, the fights' effects),
## the damage floats over their head as it does in a fight (FloatText), and the party panel shows the new Hit Points
## (LocationView.party_hurt). The Hit Points changed when the damage was dealt; this only shows it, and a beat that comes
## after the view has gone goes with it. Waiting is on timers that run while the game is paused, so nothing hangs behind
## a pause.

## Captures turn the beat off for their "before" shots (tools/capture/trap_fx_capture.gd): the figure flashes and that is
## all, as a trap's damage showed before the work of 2026-10-17.
static var enabled := true

## How often the wait for the roll (or a pause) looks again, and the longest it waits.
const STEP := 0.1
const MOST := 20.0
## How long the effect's SpellFx stays up (its parts free themselves; it only holds them).
const LINGER := 6.0

var view: LocationView
## Who was hurt (null: the party panel just needs to catch up), how much (negative: no damage was rolled) and the look
## (TrapFx.cue; empty: none).
var victim: Combatant
var amount := -1
var cue: Dictionary = {}
var _waited := 0.0


## Shows `victim` hurt for `amount` (damage after Resistance, DamageResult.final; negative: none rolled) in `cue`'s look.
static func show(view_: LocationView, victim_: Combatant, amount_: int, cue_: Dictionary) -> void:
	if view_ == null or not view_.is_inside_tree():
		return
	var h := LocationHurt.new()
	h.name = "Hurt"
	h.view = view_
	h.victim = victim_
	h.amount = amount_
	h.cue = cue_
	view_.add_child(h)


## Whether a beat is still waiting to play in `view_` (the party standing up waits for it).
static func pending(view_: LocationView) -> bool:
	for c in view_.get_children():
		if c is LocationHurt:
			return true
	return false


## The party member whose creature is `who` here, or null.
static func member(view_: LocationView, who: Creature) -> Combatant:
	for m in view_.members + view_.guest_members:
		if m.creature == who:
			return m
	return null


func _ready() -> void:
	_wait()


## Looks again shortly while the big roll is up or the game is paused, then plays.
func _wait() -> void:
	if _waited < MOST and (DiceRoll.showing() != null or get_tree().paused):
		_waited += STEP
		get_tree().create_timer(STEP, true).timeout.connect(_wait)
		return
	_play()


func _play() -> void:
	# A fight that began meanwhile shows its own Hit Points on its own HUD.
	if not view.in_combat:
		var tok := (view.tokens.get(victim.id) as CombatToken) if victim != null else null
		if tok != null and is_instance_valid(tok) and tok.is_inside_tree():
			tok.flash(Look.color("vampire_red"))
			if enabled:
				tok.hurt()
				_mark(tok)
				_effect(tok)
			tok.refresh()
		if enabled:
			view.party_hurt.emit(victim)
	queue_free()


## The damage rising over their head, as in a fight.
func _mark(tok: CombatToken) -> void:
	if amount < 0:
		return
	FloatText.rise(view, tok, ("-%d" % amount) if amount > 0 else "Unhurt", "vampire_red" if amount > 0 else "parchment", 64)


## The trap's effect on them, and the sound of a blow for physical harm.
func _effect(tok: CombatToken) -> void:
	if cue.is_empty() or not SpellFx.enabled:
		return
	var fx := SpellFx.new()
	view.add_child(fx)
	TrapFx.play(fx, cue, tok, view)
	var blow := TrapFx.blow(StringName(str(cue.get("type", ""))))
	if blow != "" and amount > 0:
		CombatSfx.hit(blow, amount, victim, false)
	var tw := fx.create_tween()
	tw.tween_interval(LINGER)
	tw.tween_callback(fx.queue_free)
