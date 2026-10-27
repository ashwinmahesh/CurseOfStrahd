extends Node
## Approved offscreen paired measurements. Mac renderer evidence, never physical iOS frame-rate claims.
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
var view: LocationView

func capture_shots(tool: Node, out: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var result: Array[Dictionary] = []
	for location: String in ["village_of_barovia", "vallaki_blue_water_inn"]:
		GameState.reset()
		for id: String in PARTY:
			GameState.story.party.append(Pregens.build(id, 3))
		GameState.story.minute_of_day = 18 * 60
		view = LocationView.create(location, GameState.story, Narrator.new(), Dice.roller, "default")
		add_child(view)
		view.atmosphere.settle()
		view.rig.snap_to_target()
		await tool.call("wait_frames", 30)
		var layer := CanvasLayer.new()
		layer.layer = 30
		add_child(layer)
		var body := MobilePage.build(layer, "Inventory performance sample", layer.queue_free)
		for id: String in ["potion_of_healing", "ring_of_protection", "rope", "torch"]:
			var row := MobileUi.button(Compendium.shared().display_name("items", id), func() -> void: pass)
			UiParts.icon_on_button(row, "item", id, 28)
			body.add_child(row)
		for disabled: bool in [false, true, false, true]:
			get_viewport().disable_3d = disabled
			await tool.call("wait_frames", 12)
			var times: Array[float] = []
			for frame in 45:
				var before := Time.get_ticks_usec()
				await tool.call("wait_frames", 1)
				times.append(float(Time.get_ticks_usec() - before) / 1000.0)
			times.sort()
			var calls := get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var record := {"location": location, "world_render_disabled": disabled, "median_ms": times[22], "p95_ms": times[42], "draw_calls": calls,
				"physical_pixels": [get_window().size.x, get_window().size.y], "world_scale": get_viewport().scaling_3d_scale,
				"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
				"native_ios": OS.has_feature("ios"), "physical_device": false}
			result.append(record)
			print("PERFORMANCE ", JSON.stringify(record))
		tool.call("_shot", "%s_%s_hidden.png" % [out, location])
		get_viewport().disable_3d = false
		layer.queue_free()
		await tool.call("wait_frames", 3)
		var inventory := InventoryScreen.new()
		add_child(inventory)
		inventory.open(self, GameState.story, 0)
		await tool.call("wait_frames", 12)
		assert(get_viewport().disable_3d == MobileDevice.enabled())
		var begin := Time.get_ticks_usec()
		await tool.call("wait_frames", 45)
		var automatic := {"location": location, "phase": "actual_inventory_page", "world_render_disabled": get_viewport().disable_3d,
			"mean_ms": float(Time.get_ticks_usec() - begin) / 45000.0,
			"draw_calls": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"physical_pixels": [get_window().size.x, get_window().size.y], "world_scale": get_viewport().scaling_3d_scale,
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"native_ios": OS.has_feature("ios"), "physical_device": false}
		result.append(automatic)
		print("PERFORMANCE ", JSON.stringify(automatic))
		tool.call("_shot", "%s_%s_inventory.png" % [out, location])
		inventory.queue_free()
		await tool.call("wait_frames", 3)
		assert(not get_viewport().disable_3d)
		tool.call("_shot", "%s_%s_world.png" % [out, location])
		var lifecycle := MobileLifecycle.new()
		add_child(lifecycle)
		lifecycle.suspend()
		await tool.call("wait_frames", 12)
		assert(get_viewport().disable_3d == MobileDevice.enabled())
		var recovery := {"location": location, "phase": "actual_recovery_page", "world_render_disabled": get_viewport().disable_3d,
			"draw_calls": get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"native_ios": OS.has_feature("ios"), "physical_device": false}
		result.append(recovery)
		print("PERFORMANCE ", JSON.stringify(recovery))
		tool.call("_shot", "%s_%s_resume.png" % [out, location])
		lifecycle.resume_play()
		await tool.call("wait_frames", 3)
		assert(not get_viewport().disable_3d)
		lifecycle.queue_free()
		view.queue_free()
		await tool.call("wait_frames", 3)
	var file := FileAccess.open(out + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
