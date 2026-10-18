class_name QuestRegions
extends RefCounted
## The regions a quest is filed under in the journal (Ashwin, 2026-10-18: "sort side quests in the journal by region"): the
## quest's own `region` (data/quests), a heading for each, in the order the campaign reaches them, so the Other tab reads
## the same way every time. The companions' own quests are a heading of their own, last. A region the list doesn't know yet
## still gets a heading (its id in words), after the known ones and in id order.

## The story's order: from the mists to the castle, the villages and the road before the mountains.
const ORDER: Array[String] = [
	"into_the_mists", "death_house", "village_of_barovia", "svalich_road", "old_bonegrinder", "vallaki", "wizard_of_wines",
	"yester_hill", "lake_zarovich", "van_richtens_tower", "werewolf_den", "krezk", "abbey_of_st_markovia", "argynvostholt",
	"berez", "mount_baratok", "tsolenka_pass", "mount_ghakis", "amber_temple", "castle_ravenloft", "companions"]

const NAMES := {
	"into_the_mists": "Into the Mists", "death_house": "Death House", "village_of_barovia": "The Village of Barovia",
	"svalich_road": "The Old Svalich Road", "old_bonegrinder": "Old Bonegrinder", "vallaki": "Vallaki",
	"wizard_of_wines": "The Wizard of Wines", "yester_hill": "Yester Hill", "lake_zarovich": "Lake Zarovich",
	"van_richtens_tower": "Van Richten's Tower", "werewolf_den": "The Werewolf Den", "krezk": "Krezk",
	"abbey_of_st_markovia": "The Abbey of St. Markovia", "argynvostholt": "Argynvostholt", "berez": "Berez",
	"mount_baratok": "Mount Baratok", "tsolenka_pass": "The Tsolenka Pass", "mount_ghakis": "Mount Ghakis",
	"amber_temple": "The Amber Temple", "castle_ravenloft": "Castle Ravenloft", "companions": "Companions",
}

## The heading for a quest with no region at all.
const NONE := "elsewhere"


## The region a quest is filed under (NONE when its data names none).
static func of(quest_id: String) -> String:
	var region := str(Compendium.shared().get_entry("quests", quest_id).get("region", ""))
	return region if region != "" else NONE


## A region's heading.
static func title(region: String) -> String:
	if NAMES.has(region):
		return str(NAMES[region])
	return "Elsewhere" if region == NONE else region.replace("_", " ").capitalize()


## Where a region sorts: its place in ORDER, the unknown ones after it, the quests with no region last.
static func rank(region: String) -> int:
	var i := ORDER.find(region)
	if i >= 0:
		return i
	return ORDER.size() + 1 if region == NONE else ORDER.size()


## Whether `a` comes before `b`: by rank, and the regions ORDER doesn't know by id.
static func before(a: String, b: String) -> bool:
	var ra := rank(a)
	var rb := rank(b)
	return ra < rb if ra != rb else a < b
