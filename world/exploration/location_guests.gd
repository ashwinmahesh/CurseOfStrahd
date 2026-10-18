class_name LocationGuests
extends RefCounted
## The story allies walking with the party, clickable like anyone else in the place (LocationView; owner, 2026-10-17:
## "we should make NPCs interactable if they're with the party"). A guest's figure is a thing in the world: hovering it
## reads "Talk to Pidlwick II", a click walks up and talks (their own conversation, GuestTalk.ref_for, else one of
## their road lines), and the right-click menu offers Talk, Give... and Send home. What can be said and given is the
## npc's data (story/guest_talk.gd). The same choices come from the guest's card on the HUD and on the Party screen
## (the game root's talk_to_guest, give_to_guest and send_guest_home).


## The story guest standing on `cell` as a thing the world can use, or {} (a hero standing there takes the square, and
## familiars and steeds aren't the story's). At camp a guest with a word waiting (LocationCamp.talks) reads "Ireena wants
## a word", as a companion does, and a click starts it (talk).
static func thing(view: LocationView, cell: Vector2i) -> Dictionary:
	if view.in_combat:
		return {}
	for m: Combatant in view.members:
		if m.cell == cell:
			return {}
	for g: Combatant in view.guest_members:
		if g.cell != cell or LocationParty.is_follower(g):
			continue
		var i := view.st.guests.find(g.creature)
		if i < 0:
			continue
		var id := view.st.guest_ids[i]
		var label := "Talk to %s" % GuestTalk.name_of(id)
		var camp := LocationCamp.of(view)
		if camp != null and camp.talks.has(g.creature.id):
			label = camp.label_for(g.creature.id)
		return {"kind": "guest", "id": id, "name": GuestTalk.name_of(id), "label": label,
			"spec": {"npc": id, "cell": [cell.x, cell.y]}}
	return {}


## Guests on the same square as a hero (the line closes up on a short party): their choices go on the hero's menu.
static func here_with_member(view: LocationView, cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for g: Combatant in view.guest_members:
		if g.cell == cell and not LocationParty.is_follower(g):
			var i := view.st.guests.find(g.creature)
			if i >= 0:
				out.append(view.st.guest_ids[i])
	return out


## The right-click menu's choices for guest `npc_id`.
static func actions(view: LocationView, npc_id: String) -> Array[Dictionary]:
	return GuestTalk.actions(view.st, npc_id)


## Talk to the guest: the word they are waiting to say at camp if they have one (the camp seats a guest by their creature's
## id, `guest_<npc>`), else their conversation, else one of their road lines, else a word that there is nothing more.
static func talk(view: LocationView, npc_id: String) -> void:
	var camp := LocationCamp.of(view)
	var i := view.st.guest_ids.find(npc_id)
	if camp != null and i >= 0 and i < view.st.guests.size() and camp.talks.has(view.st.guests[i].id):
		camp.talk(view.st.guests[i].id)
		return
	var ref := GuestTalk.ref_for(npc_id)
	if ref != "":
		view.dialogue_requested.emit(ref, npc_id)
		return
	if view.banter_player != null:
		for moment: String in ["enter", "idle", "fight"]:
			var lines := view.banter_player.guest_next(view.st, moment, npc_id)
			if not lines.is_empty():
				view.banter.emit(lines)
				return
	view.toast.emit("%s has nothing more to say just now" % GuestTalk.name_of(npc_id).get_slice(" ", 0))


## A right-click choice for a guest ("guest_give:<npc>" ...): Give opens the picker (the game root shows it).
static func act(view: LocationView, action_id: String) -> void:
	var npc_id := action_id.get_slice(":", 1)
	match action_id.get_slice(":", 0):
		"guest_talk":
			talk(view, npc_id)
		"guest_give":
			view.gift_requested.emit(npc_id)
		"guest_home":
			send_home(view, npc_id)


## Sends the guest home (the Party screen's Send home): they wait where the party found them.
static func send_home(view: LocationView, npc_id: String) -> void:
	var name_ := GuestTalk.name_of(npc_id).get_slice(" ", 0)
	var why := view.st.guest_stays(npc_id)
	if why != "":
		view.toast.emit(why)
	elif view.st.send_guest_home(npc_id):
		view.place_guests()
		view.refresh_npcs()
		view.toast.emit("%s goes home" % name_)
