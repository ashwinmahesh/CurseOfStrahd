class_name Wards
extends RefCounted
## Spells that ward a place or a rest, cast while exploring (Ashwin's answer to the spell audit, 2026-10-12;
## docs/rules/deviations.md, Wards and rests): where each was cast is kept on its StoryState.active_spells entry
## (FieldCasting._take_effect), and Hallow's places, which last until dispelled, in a list of their own.
## - Rests: Leomund's Tiny Hut and Guards and Wards let a Long Rest start with enemies still in the building; those two,
##   Hallow, Forbiddance and Mordenkainen's Private Sanctum keep it from being interrupted; under Alarm an interruption
##   still leaves a Long Rest.
## - Strahd's visits: none that can wait comes to a hallowed, forbidden or sanctum place, or while Nondetection runs.
## - Magic Circle: cast within the hour before a fight in the same place, it stands around its caster when the fight
##   starts: Celestials, Elementals, Fey, Fiends and Undead can't step into it and attack anyone inside it at
##   Disadvantage.
## Pure story and combat logic: no nodes.

## The wards that belong to the place they're cast in.
const PLACE_BOUND: Array[String] = ["magic_circle", "leomunds_tiny_hut", "alarm", "forbiddance", "guards_and_wards",
	"mordenkainens_private_sanctum"]
## StoryState.flags: the locations made holy by Hallow (an underscore key: bookkeeping, not story).
const HALLOWED := "_hallowed"


## Records where a place-bound ward was cast (its active_spells entry), and Hallow's place for good.
static func cast_here(st: StoryState, spell_id: String) -> void:
	if spell_id == "hallow":
		var places := st.flags.get(HALLOWED, []) as Array
		if not st.location in places:
			places.append(st.location)
		st.flags[HALLOWED] = places
	elif spell_id in PLACE_BOUND and st.active_spells.has(spell_id):
		(st.active_spells[spell_id] as Dictionary)["location"] = st.location


## Whether `spell_id`'s ward is running at `location_id` (Guards and Wards: anywhere in its building).
static func active_at(st: StoryState, spell_id: String, location_id: String) -> bool:
	if spell_id == "hallow":
		return location_id in (st.flags.get(HALLOWED, []) as Array)
	if not st.spell_active(spell_id):
		return false
	var at := str((st.active_spells[spell_id] as Dictionary).get("location", ""))
	if spell_id == "guards_and_wards":
		return at in RestRules.building_of(location_id) or at == location_id
	return at == location_id


## The ward that lets a Long Rest start here with enemies still in the building (Tiny Hut, Guards and Wards), or "".
static func shelter(st: StoryState) -> String:
	for id: String in ["leomunds_tiny_hut", "guards_and_wards"]:
		if active_at(st, id, st.location):
			return Compendium.shared().display_name("spells", id)
	return ""


## The ward that keeps a rest here from being interrupted, or "".
static func keeps_rest(st: StoryState) -> String:
	for id: String in ["leomunds_tiny_hut", "guards_and_wards", "hallow", "forbiddance", "mordenkainens_private_sanctum"]:
		if active_at(st, id, st.location):
			return Compendium.shared().display_name("spells", id)
	return ""


## Whether Alarm stands over a rest here.
static func alarmed(st: StoryState) -> bool:
	return active_at(st, "alarm", st.location)


## The ward that keeps Strahd's visits (those that can wait) from finding the party at `location_id`, or "".
static func hides_from_strahd(st: StoryState, location_id: String) -> String:
	if st.spell_active("nondetection"):
		return Compendium.shared().display_name("spells", "nondetection")
	for id: String in ["hallow", "forbiddance", "mordenkainens_private_sanctum"]:
		if active_at(st, id, location_id):
			return Compendium.shared().display_name("spells", id)
	return ""


# --- Magic Circle in a fight (combat/magic_circle.gd) ---------------------------------------------

## A Magic Circle cast here within the hour stands around its caster as the fight starts (LocationFights).
static func bring_circle(e: Encounter, st: StoryState, location_id: String) -> void:
	if not active_at(st, "magic_circle", location_id):
		return
	var caster := e.get_c(str((st.active_spells["magic_circle"] as Dictionary).get("caster", "")))
	if caster != null and caster.is_alive():
		MagicCircle.place(e, caster)


## The location's antimagic areas (`antimagic` on an area: Van Richten's Tower's ring, Dungeon Expansion Plan V1).
static func antimagic_areas(loc: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Variant in loc.get("areas", []):
		var area := a as Dictionary
		var held: Variant = area.get("antimagic", false)
		if (held is bool and bool(held)) or (held is String and str(held) != ""):
			out.append(area)
	return out


## The antimagic area `cell` is in ({} if none).
static func antimagic_area_at(loc: Dictionary, cell: Vector2i) -> Dictionary:
	for area in antimagic_areas(loc):
		var c0 := area["cells"][0] as Array
		var c1 := area["cells"][1] as Array
		if cell.x >= mini(int(c0[0]), int(c1[0])) and cell.x <= maxi(int(c0[0]), int(c1[0])) \
				and cell.y >= mini(int(c0[1]), int(c1[1])) and cell.y <= maxi(int(c0[1]), int(c1[1])):
			return area
	return {}


## The notice for a caster who stands in an antimagic area now (the party's leader, where the map left them), or "" when
## nobody is held: no spell can be cast there out of a fight (FieldCasting), as none can in a fight there.
static func antimagic_notice(st: StoryState) -> String:
	if st.positions.is_empty():
		return ""
	var area := antimagic_area_at(Compendium.shared().get_entry("locations", st.location), st.positions[0])
	if area.is_empty():
		return ""
	var held: Variant = area["antimagic"]
	return str(held) if held is String else "No spell can be cast here."

