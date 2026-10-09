extends TestCase
## The radial menu's two schemes (Combat HUD plan, owner pick 2026-10-09): the bar's eight wedges, with Tactical in
## Move's place, and the wheels' actions, a wedge each, a greyed one not taken.


func test_the_bar_wheel_has_the_tactical_view() -> void:
	var r := RadialMenu.new()
	assert_true("Tactical" in RadialMenu.CHOICES)
	assert_false("Move" in RadialMenu.CHOICES, "B already cancels a move")
	var got: Array[String] = []
	r.picked.connect(func(ch: String) -> void: got.append(ch))
	r.open()
	r.selected = RadialMenu.CHOICES.find("Tactical")
	r.confirm()
	assert_eq(got, ["Tactical"] as Array[String])
	r.free()


func test_a_wheel_of_actions_picks_by_index_and_skips_a_greyed_one() -> void:
	var r := RadialMenu.new()
	var got: Array[int] = []
	r.picked_item.connect(func(i: int) -> void: got.append(i))
	var items: Array[Dictionary] = [{"label": "Greatsword", "enabled": true}, {"label": "Dash", "enabled": false},
		{"label": "Tactical view", "enabled": true}]
	r.open_items(items, "All")
	r.aim(Vector2(0, -1))   # straight up: the first wedge
	assert_eq(r.selected, 0)
	r.confirm()
	r.open_items(items, "All")
	r.selected = 1
	r.confirm()
	assert_eq(got, [0] as Array[int], "the greyed Dash isn't taken")
	r.open_items(items.duplicate() + items.duplicate() + items.duplicate() + items.duplicate(), "All")
	assert_eq(r.items.size(), RadialMenu.PAGE, "a page at a time")
	r.free()
