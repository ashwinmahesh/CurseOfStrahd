class_name GuestTalk
extends RefCounted
## What the party can do with a story ally who travels with them (ADR 0010; owner, 2026-10-17: "we should make NPCs
## interactable if they're with the party"): talk to them, hand them things, send them home. The ways in are the
## guest's figure in the world (a click, the right-click menu), their card on the exploring HUD and their card on the
## Party screen; they all come here for what there is to say and give. The data is the npc's (data/npcs/<id>.json):
##   "guest_talk": "castle_ravenloft/spires_pidlwick:companion"
##       the conversation they open (the node should keep an exit and offer what the guest is for while they travel)
##   "gifts": [{"id": "key", "item": "pidlwicks_key", "label": "The brass wind-up key",
##              "when": "flag.pidlwick_key_found and not flag.pidlwick_wound",
##              "ref": "castle_ravenloft/spires_pidlwick:key_back", "note": "..."}]
##       what the party can hand them while `when` holds (a story condition, docs/contracts/dialogue.md); `item` is
##       the thing's id (its name and icon label the choice), `ref` the conversation handing it over starts.
## A guest with no `guest_talk` says one of their road lines instead (Banter.guest_next). Potions and healing for a
## guest still go from the Inventory (FieldItems.give_potion).


## The conversation clicking the guest opens, or "" when they have none of their own.
static func ref_for(npc_id: String) -> String:
	return str(Compendium.shared().get_entry("npcs", npc_id).get("guest_talk", ""))


## What the party can hand `npc_id` now: [{id, label, item, ref, note}], in the order the data lists them.
static func gifts(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Variant in Compendium.shared().get_entry("npcs", npc_id).get("gifts", []):
		var d := g as Dictionary
		if not StoryConditions.check(str(d.get("when", "")), st):
			continue
		var item := str(d.get("item", ""))
		var label := str(d.get("label", ""))
		if label == "" and item != "":
			label = Compendium.shared().display_name("items", item)
		out.append({"id": str(d.get("id", item)), "label": label, "item": item, "ref": str(d.get("ref", "")),
			"note": str(d.get("note", ""))})
	return out


## The guest's name as the menus show it.
static func name_of(npc_id: String) -> String:
	return str(Compendium.shared().get_entry("npcs", npc_id).get("name", npc_id))


## The right-click and card menu for a guest travelling with the party: [{id, label, enabled, why}] where an id is
## "guest_talk:<npc>", "guest_give:<npc>" or "guest_home:<npc>" (the game root answers them).
static func actions(st: StoryState, npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"id": "guest_talk:" + npc_id, "label": "Talk"})
	var gifts_now := gifts(st, npc_id)
	out.append({"id": "guest_give:" + npc_id, "label": "Give...", "enabled": not gifts_now.is_empty(),
		"why": "" if not gifts_now.is_empty() else "Nothing the party carries is for %s right now (potions go from the Inventory)" % name_of(npc_id).get_slice(" ", 0)})
	var stays := st.guest_stays(npc_id)
	out.append({"id": "guest_home:" + npc_id, "label": "Send home", "enabled": stays == "", "why": stays})
	return out
