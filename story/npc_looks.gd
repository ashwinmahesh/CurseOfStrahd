class_name NpcLooks
extends RefCounted
## An NPC whose face changes with the story (owner, 2026-10-08: Rictavio becomes Van Richten once he admits who he
## is). Their data's `looks` lists [{when, portrait}], first holding condition wins (StoryConditions); otherwise the
## data's `portrait`. The portrait id names both their small portrait (art/portraits/<id>.png) and their dialogue bust
## (art/busts/<id>.webp). Their sprite, name and stat block stay as they are.


static func portrait(npc: Dictionary, st: StoryState) -> String:
	for look: Variant in npc.get("looks", []):
		var d := look as Dictionary
		if st != null and StoryConditions.check(str(d.get("when", "")), st):
			return str(d["portrait"])
	return str(npc.get("portrait", npc.get("id", "")))
