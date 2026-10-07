class_name LocationCare
extends RefCounted
## Looking after the party outside a fight (LocationView, owner ask 2026-10-07): stabilizing someone at 0 Hit Points
## (a Medicine check or a Healer's Kit), giving them a healing potion, a paladin's Lay On Hands, and the party's figures
## getting up and showing their state afterwards.


## What the others can do for `ch` at 0 Hit Points (2024 rules, as in a fight): a DC 10 Wisdom (Medicine) check by
## the best of them, a Healer's Kit (no check), or a healing potion given to them.
static func _tend_actions(view: LocationView, ch: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var medic := LocationParty._best(view, &"medicine")
	if ch.stable:
		out.append({"id": "stabilize", "label": "Stabilize", "enabled": false, "why": "Already stable"})
	elif medic == null:
		out.append({"id": "stabilize", "label": "Stabilize", "enabled": false, "why": "Nobody is on their feet"})
	else:
		out.append({"id": "stabilize", "label": "Stabilize: %s, Medicine %+d vs DC 10" % [medic.name.get_slice(" ", 0),
			medic.skill_bonus(&"medicine").total()]})
		var kit := _holder_of(view, "healers_kit")
		if kit != null:
			out.append({"id": "kit", "label": "Stabilize with %s's Healer's Kit" % kit.name.get_slice(" ", 0)})
	var seen := {}
	for m in view.st.party:
		if m.hp <= 0:
			continue
		for e: Dictionary in m.inventory:
			var id := str(e["id"])
			if seen.has(id) or int(e["qty"]) <= 0 or _potion_heal(id).is_empty():
				continue
			seen[id] = true
			out.append({"id": "potion:" + id, "label": "Give %s (%s's)" % [Compendium.shared().item_data(id).get("name", id),
				m.name.get_slice(" ", 0)]})
	return out


## A paladin's Lay On Hands outside a fight: heal `ch` by an amount picked from the pool (1-5, steps of 5, or all
## they need), or spend 5 to end Poisoned. Ids "loh:<amount>" / "loh:poison".
static func _lay_on_hands_actions(view: LocationView, ch: Character) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var healer := _lay_on_hands_healer(view)
	if healer == null or ch.dead:
		return out
	var pool := healer.resource_left("lay_on_hands")
	var hurt := ch.max_hp() - ch.hp
	var who := healer.name.get_slice(" ", 0)
	if hurt > 0:
		out.append({"id": "loh:%d" % mini(hurt, pool), "label": "Lay On Hands (%s): heal %d, all they need (pool %d)" % [who, mini(hurt, pool), pool]})
		for c: Variant in ClassFeatures.lay_on_hands_choices(pool):
			var v := str((c as Dictionary)["value"])
			if v.is_valid_int() and int(v) < mini(hurt, pool):
				out.append({"id": "loh:" + v, "label": "Lay On Hands (%s): heal %s" % [who, v]})
	if ch.has_condition(&"poisoned") and pool >= 5:
		out.append({"id": "loh:poison", "label": "Lay On Hands (%s): end Poisoned (5)" % who})
	return out


## The conscious party member with points left in a Lay On Hands pool, or null.
static func _lay_on_hands_healer(view: LocationView) -> Character:
	for m in view.st.party:
		if m.hp > 0 and not m.dead and m.resource_left("lay_on_hands") > 0:
			return m
	return null


static func _lay_on_hands_out(view: LocationView, cell: Vector2i, choice: String) -> void:
	var target: Character = null
	for m in view.members:
		if m.cell == cell:
			target = m.creature as Character
	var healer := _lay_on_hands_healer(view)
	if target == null or healer == null or target.dead:
		return
	var who := target.name.get_slice(" ", 0)
	var pool := healer.resource_left("lay_on_hands")
	if choice == "poison":
		if pool < 5:
			return
		healer.spend_resource("lay_on_hands", 5)
		target.remove_condition(&"poisoned")
		view.toast.emit("%s lays hands on %s: the poison is gone" % [healer.name.get_slice(" ", 0), who])
	else:
		var n := clampi(int(choice), 1, pool)
		healer.spend_resource("lay_on_hands", n)
		var healed := target.heal(n, "Lay On Hands")
		view.toast.emit("%s lays hands on %s: %d Hit Points (%d left in the pool)" % [healer.name.get_slice(" ", 0), who, healed, pool - n])
	refresh_party(view)
	view.party_tended.emit()


## Outside a fight, a party member with Hit Points again gets up (Prone ends: there's no turn to spend standing) and
## every party token shows its current state (owner report 2026-10-07: healed outside combat but still "Prone · Dying").
static func refresh_party(view: LocationView) -> void:
	if view.in_combat:
		return
	for m in view.members + view.guest_members:
		var cr := m.creature
		if cr.hp > 0 and not cr.dead and cr.has_condition(&"prone"):
			cr.remove_condition(&"prone")
		if view.tokens.has(m.id):
			(view.tokens[m.id] as CombatToken).refresh()


## A conscious party member carrying `item_id`, or null.
static func _holder_of(view: LocationView, item_id: String) -> Character:
	for m in view.st.party:
		if m.hp > 0 and m.inventory.any(func(e: Dictionary) -> bool: return str(e["id"]) == item_id and int(e["qty"]) > 0):
			return m
	return null


## A potion's healing ({dice, flat}), or {} if it isn't a healing potion.
static func _potion_heal(item_id: String) -> Dictionary:
	var data := Compendium.shared().item_data(item_id)
	if str(data.get("category", "")) != "potion":
		return {}
	for fx: Variant in data.get("effects", []):
		if str((fx as Dictionary).get("effect", "")) == "heal":
			return (fx as Dictionary).get("params", {}) as Dictionary
	return {}


## Stabilizes or heals the party member at `cell` (the menu's stabilize, kit and potion:<id>).
static func _tend(view: LocationView, cell: Vector2i, action_id: String) -> void:
	var target: Character = null
	for m in view.members:
		if m.cell == cell:
			target = m.creature as Character
	if target == null or target.dead or target.hp > 0:
		return
	var who := target.name.get_slice(" ", 0)
	if action_id == "stabilize":
		var medic := LocationParty._best(view, &"medicine")
		if medic == null or target.stable:
			return
		var t := medic.roll_check(view.dice, &"medicine", 10, CheckAids.before_check(medic, &"medicine"))
		view.check_rolled.emit(t.describe())
		if t.success:
			target.stabilize()
			view.toast.emit("%s stops %s's bleeding: Stable" % [medic.name.get_slice(" ", 0), who])
		else:
			view.toast.emit("%s can't stop %s's bleeding (try again)" % [medic.name.get_slice(" ", 0), who])
	elif action_id == "kit":
		var holder := _holder_of(view, "healers_kit")
		if holder == null or target.stable:
			return
		target.stabilize()
		view.toast.emit("%s binds %s's wounds with a Healer's Kit: Stable" % [holder.name.get_slice(" ", 0), who])
	else:
		var item_id := action_id.get_slice(":", 1)
		var holder := _holder_of(view, item_id)
		var heal := _potion_heal(item_id)
		if holder == null or heal.is_empty():
			return
		var name := str(Compendium.shared().item_data(item_id).get("name", item_id))
		var amount := int(heal.get("flat", 0))
		if heal.has("dice"):
			amount += int(view.dice.roll_expr(str(heal["dice"]), "%s gives %s %s" % [holder.name, target.name, name])["total"])
		var healed := target.heal(amount, name)
		holder.remove_one(item_id)
		view.toast.emit("%s gives %s a %s: rolled %d, %d Hit Points" % [holder.name.get_slice(" ", 0), who, name, amount, healed])
	refresh_party(view)
	view.party_tended.emit()
