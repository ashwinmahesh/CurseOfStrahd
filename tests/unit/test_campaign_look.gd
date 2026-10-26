extends TestCase
## The campaign look hook (world/look/campaign_look.gd, docs/plans/engine_split.md): the engine's world code asks
## CampaignLook.current(); the base claims nothing, Curse of Strahd's is world/look/strahd_look.gd.


func after_each() -> void:
	CampaignLook.use(null)


func test_the_configured_look_is_strahds() -> void:
	CampaignLook.use(null)
	assert_true(CampaignLook.current() is StrahdLook, "data/campaign.json names the Strahd look")


func test_the_base_look_builds_and_claims_nothing() -> void:
	var l := CampaignLook.new()
	assert_false(l.plan(null))
	assert_false(l.walk_at(null, Vector2i.ZERO))
	assert_false(l.claims(null, Vector2i.ZERO))
	assert_false(l.frames(null, Vector2i.ZERO))
	assert_true(l.place_special("amber_case", null, null, Vector2i.ZERO, {}, {}).is_empty(), "no special art: the catalog's own")


func test_the_strahd_look_answers_for_its_special_arts() -> void:
	var l := StrahdLook.new()
	assert_true(l.place_special("not_a_special_art", null, null, Vector2i.ZERO, {}, {}).is_empty())
	if not Look.modern():
		var r := l.place_special("amber_case", null, null, Vector2i.ZERO, {}, {"classic": "box"})
		assert_eq(str(r.get("art", "")), "box", "Classic keeps the lying box")
