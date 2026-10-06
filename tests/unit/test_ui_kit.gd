extends TestCase
## The menus' look (owner feedback after Phase 3): crimson, black and gilt colours that stay out of the world's
## palette strip, an icon for every exploring button and right-click action, and the theme stock controls fall back to.


func test_ui_colours_stay_out_of_the_world_palette() -> void:
	assert_eq(Look.palette_size(), (Look.PALETTE_TEX as Texture2D).get_width(), "the strip is the world palette only")
	for c: String in ["ui_black", "ui_oxblood", "ui_wine", "gilt_dark", "gilt", "gilt_light"]:
		assert_true(Look.color(c).a > 0.0, c)


func test_every_button_and_action_has_its_icon() -> void:
	for b: Array in ExploreHud.BUTTONS:
		assert_true(UiKit.icon(str(b[3])) != null, "icon for %s" % b[0])
	for id: String in ContextMenu.ICONS:
		assert_true(UiKit.icon(str(ContextMenu.ICONS[id])) != null, "icon for the %s action" % id)


func test_stock_controls_get_the_theme() -> void:
	UiKit.install_theme()
	var tab := ThemeDB.get_default_theme().get_stylebox("tab_selected", "TabContainer") as StyleBoxFlat
	assert_true(tab != null and tab.bg_color.is_equal_approx(Color(Look.color("ui_wine"), 1.0)), "tabs are crimson")
	var tip := ThemeDB.get_default_theme().get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	assert_true(tip != null and tip.border_color.is_equal_approx(Look.color("gilt")), "tooltips have a gilt edge")
	var frame := CanvasLayer.new()
	add_child(frame)
	UiKit.screen_frame(frame, "Test")
	var titles := frame.find_children("*", "Label", true, false).filter(func(n: Node) -> bool: return (n as Label).text == "Test")
	assert_eq(titles.size(), 1, "the title sits on its plaque")
	frame.queue_free()
