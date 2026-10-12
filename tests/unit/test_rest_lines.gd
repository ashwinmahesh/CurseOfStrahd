extends TestCase
## What the Narrator says after a Long Rest (narrative/narrator/nights.dialogue and the region files): every place a
## Long Rest can be taken has a night of its own or its region's, and every region with such a place has its dreams.
## Death House's nights ride on the general rest:long, conditioned on the house.


func _restful_places() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for loc in Compendium.shared().all("locations"):
		if str(loc.get("rest", "risky")) != "no":
			out.append(loc)
	return out


func test_every_place_to_rest_has_a_night_line() -> void:
	var n := Narrator.new()
	for loc in _restful_places():
		var region := str(loc.get("region", ""))
		if region == "death_house":
			continue
		assert_true(n.has_trigger("rest:long:" + str(loc["id"])) or n.has_trigger("rest:long:" + region),
			"%s has a night (rest:long:%s or rest:long:%s)" % [loc["id"], loc["id"], region])


func test_every_region_to_rest_in_has_its_dreams() -> void:
	var n := Narrator.new()
	for loc in _restful_places():
		assert_true(n.has_trigger("dream:" + str(loc.get("region", ""))), "%s's region dreams" % loc["id"])

